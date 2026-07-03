---
type: Protocol
title: Pending Events (Proprioception Ring Buffer)
description: The per-session ring buffer of events piggybacked on every IPC response so Claude stays aware of the world without polling.
status: Live
tags: [ipc, events, proprioception]
timestamp: 2026-07-02T00:00:00Z
---

Every IPC response — success or error, any command — carries a
`pending_events` array: everything that happened since this session last
looked. This is how Claude perceives commits, touches, surprises, and its own
session events **passively**, without a dedicated polling tool. It is the
mechanism behind the "proprioception, not status polling" design principle
that runs through [the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md).

# Schema

```json
{
  "seq": 42,
  "type": "commit",
  "timestamp": "2026-07-02T10:30:00Z",
  "data": {"sha": "a1b2c3d", "message": "fix: resolve auth race condition", "xp": 8}
}
```

| Field | Type | Notes |
|---|---|---|
| `seq` | integer | Monotonically increasing, global across all sessions (`EventBuffer.nextSeq`) — **not** per-session. `events_dropped` meta-events are the one exception: they're synthesized with `seq: 0`. |
| `type` | string | `commit`, `touch`, `surprise`, `weather`/`weather_change`, `evolve`, `milestone`, `emotion`, `trick`, `companion`, `object`, `hook`, `session`, `events_dropped` — see the liveness split below; only two of these thirteen strings are ever actually pushed by the daemon today |
| `timestamp` | string | ISO 8601, generated at push time by a cached `ISO8601DateFormatter` |
| `data` | object | Event-type-specific payload — per-type field catalog below |

# Event Type Payloads — Live vs. Designed-Only

A genuine, code-verified discovery beyond what the archived
`docs/archive/IPC-PROTOCOL.md` documented: grepping every call site of
`EventBuffer.push(type:data:)` across `Pushling/Sources/` finds **exactly
two** — `HookEventProcessor.swift:209` (`type: "hook"`) and
`HookEventProcessor.swift:383` (`type: "commit"`). No other file references
`eventBuffer.push(...)` at all. Of the thirteen `type` strings listed
above, only `commit`, `hook`, and the drain-time-synthesized
`events_dropped` are ever actually placed in the ring buffer — the other
ten (`touch`, `surprise`, `weather`/`weather_change`, `evolve`, `milestone`,
`emotion`, `trick`, `companion`, `object`, `session`) are valid-looking
type strings that appear in this schema and in
`mcp/src/index.ts`'s `eventSummary()` rendering switch (which has
dead-code branches ready to format them), but **no code path anywhere in
the daemon ever constructs and pushes one**. A session will never see a
`touch` or `weather_change` pending event no matter how many times the
developer taps the Touch Bar or the weather changes — those are surfaced
to Claude, if at all, only via `pushling_sense`/`pushling_recall`'s
separate SQLite-backed journal reads, not via this ring buffer.

**Live (code-verified, actually pushed):**

| Type | Data Fields | Source |
|---|---|---|
| `commit` | `sha`, `message`, `xp`, `lines_added`, `lines_deleted`, `repo`, `commit_type` | `HookEventProcessor.swift:383` — every field present on every push, computed from the post-commit hook payload plus the live XP formula (see [commit feeding & XP](/SYSTEMS/commit-feeding-xp.md)) |
| `hook` | `hook_type` (the raw Claude Code hook name, e.g. `"PostToolUse"`), `data` (the inner hook-specific payload object, unmodified) | `HookEventProcessor.swift:209` — pushed for **every** Claude Code hook event, not just the ones that also trigger a visible reflex (see [the hook sensory system](/SYSTEMS/hook-sensory-system.md)) |
| `events_dropped` | `count` | Synthesized at drain time from cursor math (see Buffer Overflow below), not pushed like the other two |

**Designed-only (valid schema strings, zero live push call sites) —**
restored here as design intent from `docs/archive/IPC-PROTOCOL.md`'s
per-type field catalog, since the substance is real design content worth
keeping even though none of it is wired up:

| Type | Data Fields (as designed) |
|---|---|
| `touch` | `gesture` (tap/double_tap/long_press/swipe/drag), `position`, `duration_ms` |
| `surprise` | `surprise_id`, `category`, `description` |
| `weather`/`weather_change` | `from`, `to`, `duration_min` |
| `evolve` | `from_stage`, `to_stage`, `total_xp` |
| `milestone` | `milestone_id`, `description` |
| `emotion` | `axis`, `from`, `to`, `trigger` |
| `trick` | `trick_name`, `mastery_level`, `autonomous` |
| `companion` | `companion_type`, `action` |
| `object` | `object_id`, `interaction_type` |
| `session` | `action`, `session_id` |

If any of these is ever wired up, the field names above are the intended
contract; `mcp/src/index.ts`'s `eventSummary()` already has matching
rendering branches waiting for `touch`, `surprise`, `evolve`,
`weather_change`, and `session` (not `milestone`/`emotion`/`trick`/
`companion`/`object`, which have no MCP-side rendering either — they'd fall
through to the generic `default: ${event.type}: ${JSON.stringify(event.data)}`
branch today).

# The Ring Buffer

`EventBuffer` (`Pushling/Sources/Pushling/IPC/EventBuffer.swift`) is a single
global, fixed-capacity ring buffer (`defaultCapacity = 100`) shared across all
sessions, plus a per-session cursor map (`sessionCursors: [String: Int]`).

- **Push** (`EventBuffer.push(type:data:)`) — called from any thread (render,
  feed processor, hook handler) whenever something interesting happens.
  Assigns the next global `seq`, appends to the ring, overwrites the oldest
  slot once the buffer is full.
- **Session registration** (`addSession(_:)`) — a new session's cursor starts
  at `nextSeq - 1`, i.e. "has seen everything up to now." A session only ever
  sees events that occur *after* it connects.
- **Drain** (`drain(sessionId:)`) — called by `SocketServer.processMessage()`
  on **every** response for a connected session (not a separate "poll"
  command — draining piggybacks on whatever command was already being sent).
  Returns every buffered event with `seq > lastSeen`, then advances the
  cursor to the current `nextSeq - 1`. Events are **consumed on read**: the
  same event is never returned twice to the same session.
- **Removal** (`removeSession(_:)`) — called on disconnect; drops the
  session's cursor entry.

# Buffer Overflow

The buffer does not track per-event drop counts inline. Instead, overflow is
detected lazily, at drain time, from the gap between a session's cursor and
the oldest surviving event's `seq`:

```swift
if lastSeen < oldestEvent.seq - 1 {
    droppedCount = oldestEvent.seq - 1 - lastSeen
}
```

If `droppedCount > 0`, a synthetic `events_dropped` event is **prepended** to
the drained array (not inserted into the ring buffer itself):

```json
{"seq": 0, "type": "events_dropped", "timestamp": "<now>", "data": {"count": 12}}
```

This differs from the original `docs/archive/IPC-PROTOCOL.md` description, which
described `events_dropped` as injected into the buffer at push time with
`count: 1`, then incremented on consecutive drops. The actual mechanism is
simpler and cursor-based: no `events_dropped` entry ever occupies a ring slot;
it's computed fresh on every drain from cursor math, and its `seq` is always
`0` — a genuine deviation from the "seq is monotonically increasing" rule
that applies to every other event type, since `0` sorts before real events by
design (it's meant to be read first).

A session that never calls anything for a long stretch and then drains will
simply see one `events_dropped` entry summarizing everything it missed,
followed by the (up to 100) most recent real events still in the buffer.

# MCP-Side Presentation

`mcp/src/ipc.ts`'s `DaemonClient` passes `pending_events` straight through on
every `IPCResponse`; `mcp/src/index.ts`'s `formatPendingEvents()` renders them
as a "What happened since you last checked" block appended to the tool's text
response (capped at 10 lines with a "...and N more" tail), with per-type
sensory flavor (`eventSummary()`): commits get "Devoured/Ate/Nibbled ... +N XP"
depending on XP tier, touches get gesture-specific prose, hooks get
tool/session-specific one-liners. `pushling_sense` and `pushling_recall`
additionally call `daemon.ping()` directly (when the daemon is connected) to
drain events even when the aspect/filter requested doesn't otherwise need a
socket round-trip.

# Citations

[1] `Pushling/Sources/Pushling/IPC/EventBuffer.swift`
[2] `Pushling/Sources/Pushling/IPC/SocketServer.swift` (`drainEvents`, `buildResponse`)
[3] `mcp/src/ipc.ts` (`PendingEvent`, `handleResponse`)
[4] `mcp/src/index.ts` (`formatPendingEvents`, `eventSummary`)
[5] `docs/archive/IPC-PROTOCOL.md` (superseded — see [SP2a traceability](/archive/traceability/SP2a.md))
[6] `Pushling/Sources/Pushling/Feed/HookEventProcessor.swift:209,383` (the only two `EventBuffer.push` call sites in the codebase)
