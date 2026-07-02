---
type: Protocol
title: MCP Session Lifecycle
description: The handshake, single-session enforcement, idle gradient, and clean-vs-abrupt disconnect paths that govern one Claude session's presence in the creature.
status: Live
tags: [ipc, session, lifecycle]
timestamp: 2026-07-02T00:00:00Z
---

Exactly one Claude session may inhabit the creature at a time. This concept
covers that state machine — `SessionManager` (pure state) and
`SessionLifecycleReactions` (the creature/diamond reactions wired to it; the
diamond's own visual states — `materialize()`, `dissolveClean()`,
`dissolveAbrupt()`, `splitInto(count:)` — are
[the Diamond Indicator](/REFERENCE/creature-visual-design.md#the-diamond-indicator)).
The wire-level `connect`/`disconnect`/`ping` commands themselves are catalogued in
[the command catalog](/ARCHITECTURE/ipc-command-catalog.md); what rides along
on every response is [pending events](/ARCHITECTURE/pending-events.md).

# Handshake

```
MCP Server → Daemon:  {"id":"...","cmd":"connect","params":{"client":"mcp","version":"1.0"}}
Daemon → MCP Server:  {"id":"...","ok":true,"data":{"session_id":"<uuid>","protocol_version":"1.0","welcome":"Embodiment awakening...","creature":{...}},"pending_events":[]}
```

The MCP server calls `connect` once, at startup (`mcp/src/index.ts startup()`),
not lazily on first tool call. `SessionManager.startSession()` generates a new
UUID, transitions to `.connected`, and the response's `creature` field is a
live snapshot built by `CommandRouter.buildCreatureSnapshot()` — see
[the connect snapshot](/ARCHITECTURE/mcp-tool-contract.md#connect-snapshot) for
its exact shape.

# Single-Session Enforcement

A second `connect` while a session is active and not stale is rejected:

```json
← {"ok":false,"error":"A session is already active (id: <uuid>, started: 45 minutes ago). Only one Claude session can inhabit the creature at a time. The existing session must end first.","code":"SESSION_EXISTS"}
```

**Stale-session auto-eviction:** if the existing session has had no command
for more than 10 minutes (`SessionManager.staleSessionThreshold = 600.0`), it
is evicted automatically (`endSessionInternal(reason: .evicted)`, driving an
abbreviated dissolve) and the new `connect` proceeds instead of being
rejected.

# Idle Gradient

While a session is connected but Claude has stopped issuing commands, the
creature drifts back toward autonomy in four discrete phases tracked by
`SessionManager.currentIdlePhase` (thresholds in
`SessionManager`: `settlingThreshold = 10.0`, `driftingThreshold = 20.0`,
`warmStandbyThreshold = 30.0` seconds since the last command):

| Phase | Time since last command | Diamond opacity (`SessionLifecycleReactions.onIdlePhaseChanged`) | AI layer active? |
|---|---|---|---|
| Attentive | 0–10s | 1.0 | Yes |
| Settling | 10–20s | 0.85 | Yes (`shouldAILayerBeActive` is true through settling) |
| Drifting | 20–30s | 0.5 | No |
| Warm standby | 30s+ | 0.3 | No |

Any new MCP command (any stateful command, not just `move`) calls
`SessionManager.recordCommand()`, which snaps the phase back to Attentive and
resets the idle clock immediately — there is no gradual "snap back," it is
instant. Note `SessionManager.updateIdleTimeout()` also computes a
**continuous** opacity multiplier (linear 1.0→0.6 across the 10–30s window,
floor 0.3 past 30s) independent of the four discrete values above; both exist
in code — the discrete per-phase values are what `SessionLifecycleReactions`
actually applies to the diamond on a phase change.

This is not a session disconnect. The session, the diamond, and the socket
connection all remain — only the AI-Directed behavior layer's influence fades
relative to the Autonomous layer. See the behavior-stack concept (SP3a) for
how that blend is expressed at the animation layer.

# Disconnect: Clean vs. Abrupt

Two distinct paths, both ending in `SessionManager.endSessionInternal()` but
with different visual treatment (P4-T4-03 in the original phase plan):

| | Clean | Abrupt | Evicted |
|---|---|---|---|
| Trigger | Explicit `disconnect` command (SessionEnd hook → MCP server → daemon) | Socket EOF/error detected by `SocketServer.disconnectClient()` → `CommandRouter.handleAbruptDisconnect()` | New `connect` supersedes a stale session |
| Diamond | `diamond.dissolveClean()` | `diamond.dissolveAbrupt()` (flicker, faster) | `diamond.dissolveAbrupt()` |
| Creature reaction | Waves goodbye; if session >1hr, a grateful slow-blink plays first | Confused reflex (`session_confused`: wide eyes, ears back, mouth open) | none scripted |
| `DisconnectReason` | `.clean` | `.abrupt` | `.evicted` |

A server-shutdown-triggered disconnect (the daemon quitting with clients still
attached) is routed as **clean**, not abrupt — `SocketServer.disconnectClient()`
treats `reason == "server shutdown"` as orderly.

The AI-Directed layer fades out on every disconnect path
(`aiDirectedLayer?.sessionEnded()`); the long-session appreciation timer
(grateful slow-blink every 30 minutes, first fire at 60 minutes) is cancelled.

# Reconnection

`SessionManager` retains `lastSessionEndTime` / `lastSessionId` after a
session ends, purely for absence-aware wake framing on the *next* `connect`
(`SessionLifecycleReactions.onSessionStarted()` reads an `absenceProvider`
closure to pick graduated wake keyframes and, for 8+ hour absences, schedule a
dream-bubble show). This reconnection bookkeeping is presence/animation
framing only — it does not affect the single-session-enforcement decision
above, which only looks at whether a session is *currently* active.

# Citations

[1] `Pushling/Sources/Pushling/IPC/SessionManager.swift`
[2] `Pushling/Sources/Pushling/IPC/SessionLifecycleReactions.swift`
[3] `Pushling/Sources/Pushling/IPC/SocketServer.swift` (`disconnectClient`)
[4] `Pushling/Sources/Pushling/IPC/CommandRouter.swift` (`handleConnect`, `handleDisconnect`, `handleAbruptDisconnect`)
[5] `mcp/src/index.ts` (`startup()` calling `connect()` then `startSession()`)
