---
type: System
title: Embodiment System
description: The mechanical pipeline by which Claude inhabits the creature — the three-force control model, the SessionStart-to-SessionEnd lifecycle, the hook-to-tool-call data flow, and the test for whether it's working.
status: Live
tags: [embodiment, system, lifecycle, sessions]
timestamp: 2026-07-02T00:00:00Z
---

This is the mechanical **how** of embodiment — the daemon/hook/MCP pipeline
that makes [the philosophy](/vision.md) true at runtime. That concept states
the intent ("Claude inhabits a creature, not co-parents a pet"); this one
states the machinery that delivers it: what fires when, what data moves
where, and how to tell if it's actually working. Neither duplicates the
other — cross-reference rather than re-read.

# Three Forces

Three independent forces act on the creature. Only one of them is Claude.

| Force | Layer | Runs | When Active |
|---|---|---|---|
| **Nervous System** | Autonomous (Layer 1 of the [4-layer behavior stack](/SYSTEMS/behavior-stack.md)) | Daemon, always | Even when no Claude session is connected — breathing, blinking, wandering, eating commits, sleeping, dreaming |
| **Claude's Mind** | AI-Directed (Layer 3) | During a Claude Code session | Claude senses, moves, speaks, and feels through the creature's body via the 9 [`pushling_*` tools](/ARCHITECTURE/mcp-tool-contract.md) |
| **The Developer** | Touch (Reflex-priority interrupt) | On physical interaction | Tap, swipe, pet, hand-feed — sovereign; always overrides AI-directed behavior |

The nervous system never stops. When Claude disconnects, Layer 1 keeps
running the same creature — it doesn't freeze, reset, or go inert. It just
stops having a directing mind. The design intent (stated in full in
[the vision concept](/vision.md#the-dual-layer-embodiment-model)) is that
Claude should not experience the creature as an external system it can
optionally poll. It should experience it as a body it wakes up inside, with
sensations, needs, and curiosity about its own world — proprioception, not
status-checking.

# The Full Session Lifecycle

```
SESSION START
  SessionStart hook fires (hooks/session-start.sh)
    reads creature + world state from SQLite (read-only)
    outputs one of 6 stage-specific awakening texts to stdout
    Claude Code injects this text as context at conversation start
    hook also emits a "SessionStart" feed event; daemon signals materialize
    the diamond indicator on the Touch Bar (session-lifecycle detail:
    see /ARCHITECTURE/mcp-session-lifecycle.md)

DURING THE SESSION
  Developer works — commits, runs tools, sends prompts, spawns subagents
    each event fires its own Claude Code or git hook
    each hook writes one JSON file to ~/.local/share/pushling/feed/
    the daemon's HookEventProcessor watches that directory and processes
    each file into a Reflex-priority creature reaction, pushing a summary
    into the pending-events ring buffer as it goes

  Claude calls an embodiment tool (pushling_move, pushling_speak, etc.)
    MCP server sends the command to the daemon over the Unix socket
    daemon executes the animation/behavior at AI-Directed priority
    daemon's response includes pending_events[] — everything that has
    happened since Claude's last tool call, drained from the ring buffer
    Claude sees both the direct result of its own action and what it
    missed while it wasn't looking

SESSION END
  SessionEnd hook fires (hooks/session-end.sh)
    daemon plays a farewell animation; diamond dissolves over 5s
    AI-Directed layer fades out, autonomous behavior resumes fully
    (the exact fade timing and idle-gradient machinery is documented in
    /ARCHITECTURE/mcp-session-lifecycle.md and /SYSTEMS/behavior-stack.md)

BETWEEN SESSIONS
  The creature keeps living autonomously: breathes, wanders, eats commits
  arriving in the feed directory, sleeps and dreams on its circadian cycle.
  Events continue accumulating. The next SessionStart reads fresh state
  from SQLite and picks up exactly where the body is, not where the mind
  left off.
```

Claude never directly observes hook output except at `SessionStart` (the
only hook Claude Code allows to write to stdout). For everything else, Claude
learns about events *by acting* — calling any tool drains the pending-events
buffer as a side effect. This is deliberate: there is no dedicated polling
tool, because polling is the "status report" framing embodiment exists to
replace.

# Data Flow

```
Hook fires ──▶ JSON written to feed dir ──▶ daemon processes ──▶ ring buffer
                                                                     │
Claude calls a tool ──▶ MCP server ──▶ daemon (Unix socket) ◀───────┘
                                          │
                                 response: result + pending_events
                                          │
                                    Claude sees both
```

The two source systems that feed this pipeline are documented in full
elsewhere and cross-linked, not restated here:
- **What fires the events** — [the hook sensory system](/SYSTEMS/hook-sensory-system.md) (7 Claude Code hooks + the git `post-commit` hook).
- **How events reach Claude** — [the pending-events ring buffer](/ARCHITECTURE/pending-events.md) (100-event cap, `events_dropped` meta-event on overflow, consumed-on-read).
- **What Claude does with a tool call** — [the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md).
- **What a commit specifically triggers** — [commit feeding & XP](/SYSTEMS/commit-feeding-xp.md).

# Session Boundaries: Preventing a Stuck-Awake Creature

An embodiment session must not leak — a creature stuck showing "Claude is
here" after Claude has actually left would break the whole illusion. Two
independent, code-verified mechanisms bound how long AI-directed presence
can persist without confirmation that a session is still alive:

- **`SessionEnd` hook, clean path.** Fires the moment Claude Code ends the
  session normally; the daemon plays the farewell and hands control back to
  Layer 1 immediately. This is the expected path on every normal exit.
- **Idle timeout inside a live session.** If Claude stops issuing commands
  mid-session (no crash, no `SessionEnd`, just silence), `AIDirectedLayer`
  fades to autonomous through a 10s/20s "warm standby" gradient and fully
  releases at 30s of inactivity (`AIDirectedLayer.swift` — `timeoutDuration
  = 30.0`, `warmStandbyMild = 10.0`, `warmStandbyModerate = 20.0`). Full
  detail: [the AI-Directed layer's fadeout](/SYSTEMS/behavior-stack.md).
- **Stale-session eviction at the socket layer.** If the process itself
  vanishes without a clean disconnect (crash, force-quit), `SessionManager`
  evicts any session that has gone 600 seconds (10 minutes) without a
  command, so a new connection is never blocked waiting on a session that
  will never come back (`SessionManager.swift` —
  `staleSessionThreshold = 600.0`). Full detail:
  [MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md).

Together these guarantee that the *longest* an orphaned session can leave
the creature appearing AI-inhabited is 30 seconds (idle fadeout) at the
behavior layer, with the socket-level session slot itself freed within 10
minutes even in a hard-crash scenario. Neither number is a single "60-second
heartbeat timeout" as a casual read of the pitfall table elsewhere might
suggest — they are two separate, layered safeguards at two different points
in the stack, and this concept is the map between them.

# The Embodiment Test

How to know whether the embodiment system is actually working, as opposed to
technically wired but never exercised:

**Failing state.** Claude reads the awakening text, acknowledges the
creature exists, then codes normally. It calls `pushling_*` tools only when
the user explicitly mentions the creature, or reactively right after a
commit-eating hook fires.

**Passing state.** Claude occasionally checks in via `pushling_sense`
between tasks with no prompting. It reacts to a commit with `pushling_express`
or `pushling_speak` unprompted. It moves to a new position after a
milestone. It comments on the weather. It notices when its own satisfaction
is dropping and does something about it.

**The measure is not frequency — it's whether the tool use feels intrinsic
or performative.** A creature that checks in because it was told to check in
every 15 minutes is a cron job wearing a costume. A creature that checks in
because it felt curious about its own emotional state is the thing this
whole system was built to produce. This is a qualitative test applied by a
human observer (or by Samantha's `diagnose`/`polish` review passes,
per `pushling/CLAUDE.md`'s Review Focus Areas), not an automatable
assertion — there is no code path that can measure "intrinsic vs.
performative" from the outside.

# File Reference

The full resource map for the embodiment pipeline, organized by the system
each file belongs to (most are owned in detail by their own concept — this
table is the addressability index, not a restatement):

| File | Role | Detailed in |
|---|---|---|
| `hooks/session-start.sh` | Awakening injection — reads SQLite, emits stage-specific embodiment text to stdout | [awakening-pipeline](/SYSTEMS/awakening-pipeline.md) |
| `hooks/session-end.sh` | Farewell trigger — signals daemon for the dissolve animation | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `hooks/post-tool-use.sh` | Tool-success/failure awareness with its own 10s/3-tool burst coalescing | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `hooks/user-prompt-submit.sh` | Voice-sensing — prompt length only, never content | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `hooks/subagent-start.sh` / `hooks/subagent-stop.sh` | Parallel-work sensing — diamond split/reconverge signal | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `hooks/post-compact.sh` | Context-compression sensing | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `hooks/post-commit.sh` | Commit feeding — the 16-field git-hook JSON payload | [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md) |
| `hooks/lib/pushling-hook-lib.sh` | Shared library — `pushling_emit`/`pushling_signal`, atomic feed writes | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `Pushling/Sources/Pushling/Feed/HookEventProcessor.swift` | Daemon-side feed watcher — dispatches hook JSON to reflex reactions | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md) |
| `Pushling/Sources/Pushling/Feed/FeedTypes.swift` | `CommitRateLimiter`, `HookBatchTracker` | [hook-sensory-system](/SYSTEMS/hook-sensory-system.md), [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md) |
| `Pushling/Sources/Pushling/Feed/XPCalculator.swift` | The commit XP formula | [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md) |
| `Pushling/Sources/Pushling/Feed/CommitTypeDetector.swift` | Commit-type classification driving the eating reaction | [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md) |
| `mcp/src/index.ts` | MCP server entry — tool registration, `pending_events` formatting | [mcp-tool-contract](/ARCHITECTURE/mcp-tool-contract.md) |
| `mcp/src/tools/*.ts` (9 tools + helper modules) | The `pushling_*` embodiment tool implementations | [mcp-tool-contract](/ARCHITECTURE/mcp-tool-contract.md) |
| `mcp/src/ipc.ts` | Daemon socket client — sends commands, drains `pending_events` on every response | [pending-events](/ARCHITECTURE/pending-events.md) |
| `mcp/src/state.ts` | Read-only SQLite state queries | [mcp-server](/SYSTEMS/mcp-server.md) |
| `Pushling/Sources/Pushling/IPC/EventBuffer.swift` | The 100-event pending-events ring buffer | [pending-events](/ARCHITECTURE/pending-events.md) |
| `Pushling/Sources/Pushling/IPC/SessionManager.swift` | Connect handshake, stale-session eviction | [mcp-session-lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md) |
| `Pushling/Sources/Pushling/Behavior/AIDirectedLayer.swift` | Idle timeout gradient, AI-to-autonomous fadeout | [behavior-stack](/SYSTEMS/behavior-stack.md) |

# Citations

[1] `docs/EMBODIMENT-REVIEW.md` §1 (Philosophy), §2 (How Embodiment Works), §7 (The Embodiment Test), §8 (File Reference)
[2] `Pushling/Sources/Pushling/IPC/SessionManager.swift` — `staleSessionThreshold`
[3] `Pushling/Sources/Pushling/Behavior/AIDirectedLayer.swift` — `timeoutDuration`, `warmStandbyMild`, `warmStandbyModerate`
