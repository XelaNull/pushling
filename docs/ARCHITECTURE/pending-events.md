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
| `type` | string | `commit`, `touch`, `surprise`, `weather`/`weather_change`, `evolve`, `milestone`, `emotion`, `trick`, `companion`, `object`, `hook`, `session`, `events_dropped` |
| `timestamp` | string | ISO 8601, generated at push time by a cached `ISO8601DateFormatter` |
| `data` | object | Event-type-specific payload |

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

This differs from the original `docs/IPC-PROTOCOL.md` description, which
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
[5] `docs/IPC-PROTOCOL.md` (superseded — see [SP2a traceability](/archive/traceability/SP2a.md))
