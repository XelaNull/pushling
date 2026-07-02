---
type: Reference
title: SP2a Traceability — ARCHITECTURE/IPC
description: Source-to-concept mapping for Wave SP2a (WO-1 OKF migration) — proves zero fidelity loss across the six ARCHITECTURE/IPC concepts.
status: Current
tags: [okf-migration, traceability, wave-sp2a]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP2a authored six concepts:
[system-architecture](/ARCHITECTURE/system-architecture.md),
[ipc-wire-protocol](/ARCHITECTURE/ipc-wire-protocol.md),
[ipc-command-catalog](/ARCHITECTURE/ipc-command-catalog.md),
[mcp-session-lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md),
[pending-events](/ARCHITECTURE/pending-events.md), and
[mcp-tool-contract](/ARCHITECTURE/mcp-tool-contract.md).

"Deferred" below means the source section is real content that belongs in
the final bundle but is out of this wave's assigned scope — it is **not** a
fidelity loss, it is routed to the wave that owns that subject. All deferred
sections were read for context only; nothing from them was lifted as truth
into an SP2a concept.

# docs/IPC-PROTOCOL.md (primary source — entire file assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| Overview | `ipc-wire-protocol.md` intro | migrated |
| Transport Details (socket type/path/size, Startup, Shutdown, Partial Reads) | `ipc-wire-protocol.md#transport`, `#implementation-notes` | migrated |
| Request Format — envelope table | `ipc-wire-protocol.md#request-envelope` | migrated |
| Request Format — Session Commands table | `ipc-command-catalog.md#session--utility-commands-session-exempt` | migrated |
| Request Format — Tool Commands table | `ipc-command-catalog.md#stateful-commands-require-a-session` | migrated |
| Response Format — Success/Error envelopes | `ipc-wire-protocol.md#response-envelope` | migrated |
| Error Codes table | `ipc-wire-protocol.md#error-vocabulary` | migrated, corrected — `STAGE_GATE` corrected to code's `STAGE_GATED`; `SESSION_NOT_FOUND`/`CAPACITY_EXCEEDED` dropped (never emitted by code, no replacement needed — grep-verified zero hits); ~10 real codes added that the source omitted |
| Session Management — Connect (incl. example `creature` object with `speech.max_chars/max_words`) | `mcp-session-lifecycle.md#handshake`, `mcp-tool-contract.md#connect-snapshot` | migrated, corrected — example promised fields the live code doesn't send; documented actual shape instead, flagged the promise as a client-interface drift |
| Session Management — Disconnect | `mcp-session-lifecycle.md#disconnect-clean-vs-abrupt` | migrated, corrected — source described one farewell animation for all disconnects; code has clean/abrupt/evicted paths (P4-T4-03) |
| Session Management — Ping | `ipc-command-catalog.md` (`ping` row) | migrated, corrected — `uptime_s` is machine uptime, not daemon uptime |
| Pending Events — format, event types, buffer overflow | `pending-events.md` | migrated, corrected — buffer-overflow mechanism (cursor-gap detection at drain, not push-time injection) rewritten to match `EventBuffer.swift` |
| Tool Command Details — sense/move/express/speak/perform/world/recall/teach/nurture | `mcp-tool-contract.md` (per-tool sections), `ipc-command-catalog.md` | migrated, reconciled against `mcp/src/tools/*.ts` and the Swift handlers — see the Adjudications in this wave's return message for the full list of corrections (STAGE_GATE spelling, `sense visual` shape, `move` target-vs-x/direction mismatch, nurture's two calling conventions, etc.) |
| Wire Examples | `ipc-wire-protocol.md#wire-examples` | migrated |
| Implementation Notes — Swift daemon / Node client / General | `ipc-wire-protocol.md#implementation-notes` | migrated |

# docs/EMBODIMENT-REVIEW.md (assigned: §4 only)

| Source section | → Target concept#section | Status |
|---|---|---|
| §4 MCP Tools: The Motor Cortex — 9-tool table, description-language rules, response formats, pending events prose | `mcp-tool-contract.md` (per-tool sections; verbatim descriptions re-sourced from the actual `.ts` files rather than this doc's paraphrases, per the brief — this doc's phrasing was lighter than the code's, e.g. `pushling_recall` = "What do you remember?" here vs. the code's "Access memories. What do you remember?") | migrated, re-verbatimed |
| §1 Philosophy, §2 How Embodiment Works, §3 Awakening Pipeline, §7 Embodiment Test, §8 File Reference | *(not this wave)* | deferred — owned by the SP7 embodiment wave (Embodiment System / Awakening Pipeline concepts) |
| §5 Sensory Loop: Hooks | *(not this wave)* | deferred — owned by SP7 (hooks/feed concept) |
| §6 Embodiment Language Guide | *(not this wave)* | deferred — owned by SP7 |

# docs/plan/phase-4-embodiment/PHASE-4.md (assigned: Tracks 1–2; Track 4 additionally folded for session-lifecycle detail)

| Source section | → Target concept#section | Status |
|---|---|---|
| Architectural Context — Communication Flow, Key Constraints, The 9 Tools table | `system-architecture.md#two-channels-one-server`, `mcp-tool-contract.md` intro | migrated |
| Track 1 (P4-T1-01..09) — sense aspects, recall filters, pending events system | `mcp-tool-contract.md` (`pushling_sense`, `pushling_recall`), `pending-events.md` | migrated, corrected — sense aspect count (7 in this doc vs. 8 daemon-side + `version`/`full` client-side) reconciled against `sense.ts`/`SenseHandlers.swift` |
| Track 2 (P4-T2-01..05) — move/express/speak/perform/world specs | `mcp-tool-contract.md` (respective tool sections), `ipc-command-catalog.md` (move target-parameter note) | migrated, corrected — Drop speech limit (doc said 1 char) corrected to the two live numbers (6 MCP-side / 3 daemon-side) with the discrepancy flagged rather than silently picking one; the `move` wire-format example (`speed` as a string) exposed the real `target`/`x`/`direction` mismatch documented in the command catalog |
| Track 2 (P4-T2-06) Command Queue in Daemon — 4 queue modes, capacity 20 | *(not verified against code this wave)* | dropped-with-justification — no `CommandQueue`/queue-mode/`"queue":"interrupt"` implementation was found in `CommandRouter`/`ActionHandlers` during this wave's code checks (moves are enqueued directly via `stack.enqueueAICommand`, no separate mode-aware queue class observed); documenting this as canon would risk minting a prescriptive contract for a system that may not exist in its described form. Flagged for the Orchestrator/`DECISIONS.md` rather than migrated — the behavior-stack wave (SP3a) should verify `BehaviorStack.enqueueAICommand` against this section and either confirm/extend it into a concept or confirm it as stale intent |
| Track 2 (P4-T2-07) Action Timeout System — 30s timeout, 5s fade | *(not this wave)* | deferred — belongs with the behavior-stack concept (SP3a), which owns `AIDirectedLayer`/`BlendController` |
| Track 2 (P4-T2-08) Touch-AI Interaction Priority | *(not this wave)* | deferred — belongs with the behavior-stack / touch concepts (SP3a/SP5) |
| Track 3 (P4-T3-01..09) — hook framework, per-hook specs, daemon-side hook processing | *(not this wave)* | deferred — owned by SP7 |
| Track 4 (P4-T4-01) Diamond Indicator | `mcp-session-lifecycle.md` (referenced, not authored) | deferred for its rendering detail — owned by a future creature-visual concept (SP6a); this wave's `mcp-session-lifecycle.md` references diamond state transitions (`materialize`/`dissolveClean`/`dissolveAbrupt`) only insofar as they're driven by session events, via a cross-link the SP6a wave is expected to resolve |
| Track 4 (P4-T4-02) Session Connect Handshake | `mcp-session-lifecycle.md#handshake` | migrated |
| Track 4 (P4-T4-03) Session Disconnect Handling — clean vs. abrupt | `mcp-session-lifecycle.md#disconnect-clean-vs-abrupt` | migrated |
| Track 4 (P4-T4-04) Idle Timeout Gradient | `mcp-session-lifecycle.md#idle-gradient` | migrated, corrected — exact opacity/timing values verified against `SessionManager.swift` (both the discrete per-phase values actually applied and the separate continuous-multiplier calculation, both documented since both exist in code) |
| Track 4 (P4-T4-05) Single-Session Enforcement | `mcp-session-lifecycle.md#single-session-enforcement` | migrated |
| Track 4 (P4-T4-06) Creature Reactions to Session Events | *(not this wave)* | deferred — the animation/reaction detail (specific reflex definitions, timing of slow-blinks etc.) belongs to the creature/behavior concept (SP3a); this wave names the *events* (`sessionStarted`, `commandReceived`, etc.) that drive them |
| Track 4 (P4-T4-07) SubagentStart Diamond-Split Animation | *(not this wave)* | deferred — rendering detail, owned by SP6a; this wave's session-lifecycle concept notes only that `subagentsStarted`/`subagentsStopped` are real `SessionEvent` cases |
| Goal, Dependencies, Integration Points, QA Gate | *(plan-wrapper scaffolding)* | dropped-with-justification — historical planning artifact (agent assignments, effort estimates, phase-completion checklist) with no prescriptive content beyond what's captured above; archival of the residual `PHASE-4.md` file itself is SP8's job, not authored as canon by this wave |

# mcp/README.md (assigned: seed for system-architecture / mcp-tool-contract; the README itself stays as `keep-as-is` per the survey)

| Source section | → Target concept#section | Status |
|---|---|---|
| Architecture — two channels, degraded mode | `system-architecture.md#two-channels-one-server` | migrated |
| The 9 Tools table (incl. Requires-Daemon column) | `mcp-tool-contract.md` (per-tool "requires the daemon" notes) | migrated |
| Transport — stdio, stderr-only logging | `system-architecture.md` (implicit in process-topology table; stdio/stderr logging detail deferred) | migrated (partial) — stdio transport and stderr-only logging mechanics are more MCP-server-implementation detail than architecture-topology; the future mcp-server concept (SP2b) is expected to own this in full detail |
| Setup, Register with Claude Code, Development commands | *(none — operator onboarding)* | dropped-with-justification — these are README-native onboarding instructions (`npm install`, `claude mcp add`, `npm run dev`), not canon knowledge; the README stays in place per the survey's `keep-as-is` disposition and is not archived |
| File Structure tree | *(none)* | dropped-with-justification — directory listing is derivable from the repo itself; the survey separately flagged this tree as already stale (missing `nurture-validation.ts`, `sense-helpers.ts`, `teach-handlers.ts`, `world-validation.ts`) — not worth freezing into canon prose that would only go stale again |

# PUSHLING_VISION.md (assigned sections: Architecture; MCP Integration)

| Source section | → Target concept#section | Status |
|---|---|---|
| Architecture: Process Topology (diagram + table) | `system-architecture.md#process-topology` | migrated |
| Architecture: Rendering Target | `system-architecture.md#rendering-target` | migrated |
| Architecture: State Persistence | `system-architecture.md#state-persistence` | migrated |
| Architecture: IPC (JSON over Unix Domain Socket) | `system-architecture.md#ipc-unix-domain-socket`, `ipc-wire-protocol.md` | migrated |
| MCP Integration: Design Philosophy | `mcp-tool-contract.md` intro (brief cross-reference); full philosophy prose | deferred — the "Claude acts as, not upon" philosophy narrative belongs with the SP7 Embodiment System concept; this wave's contract stays behavior-and-parameter focused |
| MCP Integration: Session Start — Embodiment Awakening (all 6 stage variants, absence flavor text) | *(not this wave)* | deferred — owned by SP7's Awakening Pipeline concept |
| MCP Integration: MCP Tools — the `pushling_` family (9 tool tables) | `mcp-tool-contract.md` (all 9 tool sections) | migrated, reconciled against code (params, stage tables, error framing corrected to match `mcp/src/tools/*.ts`) |
| MCP Integration: Key Design Principles (1–6) | `mcp-tool-contract.md` (folded into per-tool prose: return-immediately, breathing-continues, graceful-handoff, touch-sovereignty, stage-gate meaning, `pending_events` piggyback) | migrated (distributed, not as a standalone numbered list) |
| MCP Integration: When AI Acts, Human Sees It (visual-distinction table, co-presence) | *(not this wave)* | deferred — this is rendering/animation detail (sparkle trails, diamond brightening) owned by SP6a; this wave's `mcp-session-lifecycle.md` and `mcp-tool-contract.md` reference the underlying session/command events only |
| All other sections (Identity/Birth, Growth Stages, Personality, Visual System, Gameplay, Speech Evolution detail, Behavior Stack, Hooks, Creation Systems, Surprises, Journal, Installation, Performance, P Button, Roadmap) | *(not this wave)* | deferred — owned by SP3a/SP3b/SP4/SP5/SP6a/SP6b/SP7 per the bundle plan; not read in depth by this wave beyond the two assigned sections |

# Citations

[1] `docs/IPC-PROTOCOL.md`
[2] `docs/EMBODIMENT-REVIEW.md`
[3] `docs/plan/phase-4-embodiment/PHASE-4.md`
[4] `mcp/README.md`
[5] `PUSHLING_VISION.md`
