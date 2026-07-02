---
type: System
title: AI Command Queue & Touch Priority
description: What the AI-Directed layer's command queue actually does today versus the richer 4-mode, capacity-20, touch-interrupt design PHASE-4 specified for it.
status: Live
tags: [ai-directed, command-queue, touch, idle-gradient]
timestamp: 2026-07-02T00:00:00Z
---

This concept exists specifically to close the verification gap SP2a's
traceability flagged and routed to this wave: does the "Command Queue in
Daemon" system described in `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
(P4-T2-06/07/08, P4-T4-04) exist in code as specified? **Verified answer:
partially.** The action-timeout mechanism (P4-T2-07) is built and matches
the spec closely. The 4-mode command queue (P4-T2-06) and the
touch-interrupt/co-presence mechanics (P4-T2-08) described in the plan are
**not implemented** — the actual queue is a plain FIFO with no modes, no
capacity limit, and no touch-specific pause/resume/clear logic. This
concept documents the built behavior as canon and the unbuilt design as
preserved intent, per the human's DOCS WIN adjudication rules. Parent
system: [the 4-layer behavior stack](/SYSTEMS/behavior-stack.md), which
owns `AIDirectedLayer` itself.

# What Is Built: The Command Queue as It Runs Today

`AIDirectedLayer.enqueue(command:)` (`Pushling/Sources/Pushling/Behavior/AIDirectedLayer.swift`)
appends every incoming `AICommand` to a single `[AICommand]` array
(`commandQueue`) — first-in-first-out, no mode parameter, no per-command
`"queue"` field, no capacity ceiling. If nothing is currently executing,
the newly-enqueued command begins immediately; otherwise it waits its turn.
`cancel()` drops the current command and advances to the next queued one
(or standby, if the queue is empty); `cancelAll()` empties the queue
entirely and begins the 5.0s fadeout. There is exactly one caller pattern
in the codebase: `stack.enqueueAICommand(command)` from
`IPC/ActionHandlers.swift` (per-tool command construction),
`App/GameCoordinator+Loading.swift` (mutation-badge celebration and habit
execution), all constructing a single `AICommand` per call — **no call
site anywhere constructs two commands with an explicit relationship**
(interrupt-this, replace-queue, run-in-parallel), confirming the FIFO-only
behavior is the entire implementation, not an artifact of how this wave
happened to search.

## Action Timeout (Built — Matches P4-T2-07 Closely)

| Spec element (P4-T2-07) | Code (`AIDirectedLayer.swift`) | Match |
|---|---|---|
| 30s default timeout since last MCP command | `timeoutDuration: TimeInterval = 30.0` | Exact |
| Timeout fires → Layer 3 fades 5s, Layer 4 resumes | `fadeoutDuration: TimeInterval = 5.0`, `state = .fadingOut` on timeout | Exact |
| Timeout reset on each new MCP command | `enqueue()` sets `lastCommandTime` and forces `state = .executing` | Matches (reset is implicit in the state transition, not a literal timer-reset call) |
| Configurable per-command `timeout_s` (max 120s) | *(not found)* | **Not built** — `AICommand` has no per-command timeout field; the 30s/5s constants are global, not overridable |

## Idle Gradient (Built, But As a Discrete 3-Step Machine, Not a Continuous Blend)

The spec (P4-T4-04) describes a **continuous** `autonomyBlend =
clamp((timeSinceLastCommand - 10) / 20, 0, 1)` formula smoothly modulating
Layer 3/Layer 4 weighting. What's actually built inside `AIDirectedLayer`
is a **discrete three-step** standby degradation, distinct from — and not
to be confused with — the separately-built, separately-owned idle gradient
in `SessionManager` documented in
[the MCP session lifecycle concept](/ARCHITECTURE/mcp-session-lifecycle.md#idle-gradient)
(which drives the *diamond indicator's opacity*, a different subsystem
entirely, on its own 10/20/30s thresholds):

| Idle time (this layer) | Effect on `LayerOutput` |
|---|---|
| 0–10s (`warmStandbyMild`) | Last command's full output is maintained unchanged |
| 10–20s | Walk speed only linearly reduces toward a 0.3× floor; all other properties (expressions, position) hold |
| ≥ 20s (`warmStandbyModerate`) | Walk-speed override clears entirely (`nil`), ceding speed to Autonomous; other properties still hold |
| ≥ 30s (`timeoutDuration`) | Full fadeout begins (see Action Timeout, above) |

Two genuinely separate idle-gradient state machines exist in the codebase
with matching 10/20/30s thresholds but different effects (diamond opacity
vs. animation-output authority) and different owning classes
(`SessionManager` vs. `AIDirectedLayer`) — this is not documentation
duplication, it is two real, independently-implemented mechanisms that
happen to share threshold values. Neither implements the spec's single
continuous `autonomyBlend` formula.

## Touch Priority (Built — But via Layer Precedence, Not a Dedicated Handler)

The spec's "human touch always wins" (P4-T2-08) **is genuinely true in the
running system**, but the mechanism is simpler than what was designed: it
falls directly out of [the behavior stack's per-property resolution
order](/SYSTEMS/behavior-stack.md#the-four-layers) — Reflexes (Layer 2)
always outrank AI-Directed (Layer 3) for any property both layers have an
opinion on, with no touch-specific code required. `CreatureTouchHandler`
triggers ordinary named reflexes (`"ear_perk"`, `"look_at_touch"`) exactly
like any other reflex source (commits, events); it does not call
`cancelAICommands()`, does not pause or resume the AI queue, and contains
no reference to `aiDirected`/`behaviorStack.aiDirected` at all (verified by
direct search of `CreatureTouchHandler.swift`).

**Not found anywhere in the codebase** (verified: zero matches for
`TouchInterruptHandler`, `IdleGradientController`, `autonomyBlend`,
`co_presence`/`coPresence`, `queue_cleared` across all Swift and TypeScript
sources):

- The 5-second sustained-touch threshold that clears the AI command queue
  and emits a `queue_cleared` event.
- The "AI-directed behavior is paused, not cancelled" distinction for
  touches under 5 seconds (today, a touch reflex simply outranks the AI
  layer's opinion on the properties it touches for the reflex's own
  duration — nothing pauses or pockets the AI layer's state for later
  resumption; the AI layer keeps running its own state machine unaware of
  the touch the whole time).
- The 100ms-window co-presence bonus animation for simultaneous touch + MCP
  command.
- Any `CommandQueue` class, `queue` mode parameter on the wire protocol, or
  queue-capacity enforcement (the spec's 20-command cap).

# Adjudication

Per the routing note from SP2a's traceability and this wave's own
verification: **do not mint the 4-mode/capacity-20 command queue,
`TouchInterruptHandler`, or continuous `autonomyBlend` formula as
prescriptive canon** — no such code exists to make them true today, and
authoring them as System-concept fact would misrepresent shipped behavior.
This concept instead documents the FIFO queue, the built discrete idle
gradient, and the layer-precedence touch mechanism as canon (all verified
above), while preserving PHASE-4's richer design as **intended-but-unbuilt
detail** requiring its own `FEATURES/` entry — outside this wave's assigned
concept list, so not authored here. Flagged for `DECISIONS.md`/the
Orchestrator: (1) confirm whether the 4-mode queue is still wanted
product-wise (the current FIFO-plus-layer-precedence design arguably
achieves the same *experienced* result — touch wins, AI degrades gracefully
— through a simpler mechanism, which may mean the richer spec is genuinely
stale rather than merely unbuilt); (2) if still wanted, a `FEATURES/`
concept (e.g. `ai-command-queue-modes.md`) should be created with 📐
markers for: queue modes (append/interrupt/replace/parallel), 20-command
capacity, per-command `timeout_s` override, the 5s touch-clear threshold,
and the co-presence bonus.

# Citations

[1] `Pushling/Sources/Pushling/Behavior/AIDirectedLayer.swift`
[2] `Pushling/Sources/Pushling/Behavior/BehaviorStack.swift` (`enqueueAICommand`, `cancelAICommands`)
[3] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift` (call sites constructing `AICommand`)
[4] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (reflex-only touch handling, no AI-queue interaction)
[5] `Pushling/Sources/Pushling/IPC/SessionManager.swift` (the separate, session-level idle gradient)
[6] `docs/archive/plan/phase-4-embodiment/PHASE-4.md` — P4-T2-06 (Command Queue in Daemon), P4-T2-07 (Action Timeout System), P4-T2-08 (Touch-AI Interaction Priority), P4-T4-04 (Idle Timeout Gradient)
[7] `docs/archive/traceability/SP2a.md` — the original routing note for this verification
