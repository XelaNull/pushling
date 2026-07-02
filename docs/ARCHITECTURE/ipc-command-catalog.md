---
type: Reference
title: Pushling IPC Command and Action Catalog
description: The 15 socket commands, their valid actions, parameters, and response shapes — the raw wire contract underneath the 9 pushling_* MCP tools.
status: Live
tags: [ipc, reference, commands]
timestamp: 2026-07-02T00:00:00Z
---

Every command the Swift daemon's `CommandRouter` accepts over the socket
(`CommandRouter.allCommands`, verified against every `*Handlers.swift`). This
is the **raw wire layer** — what actually travels between the MCP server and
the daemon. What Claude calls (9 tools, first-person framing, richer
validation) is a layer above this — see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md). The envelope,
error codes, and transport are [the wire protocol](/ARCHITECTURE/ipc-wire-protocol.md).

# Schema

15 commands total: 3 session/utility commands that are session-exempt plus 3
more utility commands also exempt, and 9 stateful commands that map roughly
1:1 to the 9 MCP tools.

## Session & Utility Commands (session-exempt)

| Command | Action | Params | Response `data` |
|---|---|---|---|
| `connect` | — | `{client?, version?}` | `{session_id, protocol_version, welcome, creature: {...}}` — see the [creature snapshot schema](/ARCHITECTURE/mcp-tool-contract.md#connect-snapshot) |
| `disconnect` | — | `{session_id, reason?: "abrupt"}` | `{farewell: true}` |
| `ping` | — | `{}` | `{uptime_s}` — **machine** uptime (`ProcessInfo.processInfo.systemUptime`), not daemon-process uptime |
| `reload` | — | `{}` | `{reloading: true}`; schedules a graceful daemon restart 200ms later |
| `screenshot` | — | `{}` | `{path: "/tmp/pushling_screenshot.png", width, height}` — captures the live SpriteKit scene, writes a PNG to disk, returns the **path**, not base64 |
| `debug_nodes` | — | `{}` | `{nodes: [...], total_count, visible_count, creature: {x, y, z_position, facing, stage}}` |

`reload`, `screenshot`, and `debug_nodes` are **not documented in the older
`docs/archive/IPC-PROTOCOL.md`** but are live, session-exempt commands
(`SocketServer.swift` session-exempt set; `CommandRouter.allCommands`). They
have no corresponding MCP tool — they're operator/debug commands, invoked
directly over the socket (e.g. `echo '{"id":"1","cmd":"screenshot"}' | nc -U /tmp/pushling.sock`).

## Stateful Commands (require a session)

| Command | Valid Actions | MCP Tool |
|---|---|---|
| `sense` | `self`, `body`, `surroundings`, `visual`, `events`, `developer`, `evolve`, `full` | `pushling_sense` |
| `move` | `goto`, `walk`, `stop`, `jump`, `turn`, `retreat`, `pace`, `approach_edge`, `center`, `follow_cursor` | `pushling_move` |
| `express` | `joy`, `curiosity`, `surprise`, `contentment`, `thinking`, `mischief`, `pride`, `embarrassment`, `determination`, `wonder`, `sleepy`, `love`, `confusion`, `excitement`, `melancholy`, `neutral` | `pushling_express` |
| `speak` | `say`, `think`, `exclaim`, `whisper`, `sing`, `dream`, `narrate` | `pushling_speak` |
| `perform` | `wave`, `spin`, `bow`, `dance`, `peek`, `meditate`, `flex`, `backflip`, `dig`, `examine`, `nap`, `celebrate`, `shiver`, `stretch`, `play_dead`, `conduct`, `glitch`, `transcend`, `sequence` | `pushling_perform` |
| `world` | `weather`, `event`, `place`, `create`, `remove`, `modify`, `time_override`, `sound`, `companion` (plus `list`, exposed via `pushling_world` list actions on other tools, not currently wired to an MCP action) | `pushling_world` |
| `recall` | `recent`, `commits`, `touches`, `conversations`, `milestones`, `dreams`, `relationship`, `failed_speech` | `pushling_recall` |
| `teach` | `compose`, `preview`, `refine`, `commit`, `list`, `remove` | `pushling_teach` |
| `nurture` | `habit`, `preference`, `quirk`, `routine`, `identity`, `suggest`, `list`, `remove`, `set`, `reinforce` | `pushling_nurture` |

`sense`'s `visual` action, `sense`'s `full` covering everything except
`visual`/`evolve`, and `nurture`'s ten actions are detailed below; per-command
prose for the remaining commands lives with their MCP tool in
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md) to avoid
duplicating one contract across two concepts.

# sense — Detail Not Covered by the Tool Contract

`sense visual` does **not** capture a screenshot inline — it currently returns
a plain acknowledgement, still `ok: true`:

```json
← {"id":"...","ok":true,"data":{"note":"Visual screenshot capture is not yet implemented. Use 'sense surroundings' for world state."},"pending_events":[]}
```

The real screenshot capability lives on the separate, undocumented-until-now
`screenshot` command above, which writes a PNG file and returns its path — a
different shape than the base64-inline contract `docs/archive/IPC-PROTOCOL.md` and
`PUSHLING_VISION.md` describe. `pushling_sense(aspect: "visual")` on the MCP
side forwards to `sense`/`visual` (not to `screenshot`), so the MCP tool
inherits the "not yet implemented" response today.

`sense full` (the default aspect) aggregates `self` + `body` + `surroundings`
+ session status; it does **not** include `visual` or `evolve` data, matching
the documented behavior.

# nurture — Two Calling Conventions

`CommandRouter.validActions["nurture"]` accepts ten action strings, and both
of the following are live, equivalent ways to set a habit — this is a real
dual-path API, not one canonical form with dead aliases:

```json
// Direct form — action names the sub-type directly
{"id":"1","cmd":"nurture","action":"habit","params":{"name":"stretch_habit","behavior":"stretch","trigger":{"type":"after_event","event":"commit"}}}

// Generic form — action is "set", sub-type travels in params.type
{"id":"1","cmd":"nurture","action":"set","params":{"type":"habit","name":"stretch_habit","behavior":"stretch","trigger":{"type":"after_event","event":"commit"}}}
```

`mcp/src/tools/nurture.ts` always uses the generic form (`set`/`remove`/`list`/
`suggest`/`reinforce`, with the sub-type in `params.type`) — the direct-action
form (`habit`/`preference`/`quirk`/`routine`/`identity`) exists in the daemon
but is not currently exercised by any shipped client. `nurture`'s `get` action,
by contrast, is **MCP-side only**: `pushling_nurture(action: "get")` never
reaches the socket at all — it's answered entirely from SQLite reads plus a
`ping()` for pending events (`mcp/src/tools/nurture.ts handleListOrGet()`).

Nurture caps (enforced daemon-side, surfaced as `AT_CAP`): 20 habits, 12
preferences, 12 quirks, 10 routine slots.

# Current Implementation Note — `move`'s Target Parameter

`docs/archive/IPC-PROTOCOL.md`, `PUSHLING_VISION.md`, and `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
all describe `move`'s `goto`/`walk`/`approach_edge` actions as taking a
**named or numeric `target`** (e.g. `"center"`, `"edge_left"`, or a pixel
number), and `mcp/src/tools/move.ts` sends exactly that shape:
`{"target": "center", "speed": "walk"}`. The current
`ActionHandlers.handleMove()` implementation does not read `params["target"]`
for any action — `goto` reads a numeric `params["x"]` only, `walk` reads
`params["direction"]`, `turn` ignores any requested direction and always
flips to the opposite of current facing, `approach_edge` reads
`params["edge"]`, and `jump`'s `direction` param (up/left/right) is accepted
by the schema but not read at all (only `velocity` is used). Since the MCP
client only ever sends `target`, a call like
`pushling_move(action: "goto", target: "center")` is accepted (`ok: true`)
but the creature does not move to center — `params["x"]` is absent, so
`handleMove` falls back to the creature's current X. This is a genuine
client/daemon contract mismatch, not a doc/code drift with an obvious
"code wins" answer — the documented `target` vocabulary is the intended
design and is what `pushling_move`'s tool description promises Claude. It is
flagged for the Orchestrator/`DECISIONS.md` as a functional bug requiring a
daemon-side fix (`handleMove` should read `params["target"]`, resolving named
positions the same way `mcp/src/tools/move.ts`'s `POSITION_TARGETS` table
does, in addition to the numeric-pixel path it already supports).

# Citations

[1] `Pushling/Sources/Pushling/IPC/CommandRouter.swift` (`allCommands`, `validActions`)
[2] `Pushling/Sources/Pushling/IPC/SenseHandlers.swift`
[3] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift`
[4] `Pushling/Sources/Pushling/IPC/NurtureHandlers.swift`, `CreationHandlers.swift` (`handleNurture` dispatch)
[5] `mcp/src/tools/move.ts`, `mcp/src/tools/nurture.ts`
[6] `docs/archive/IPC-PROTOCOL.md` (superseded — see [SP2a traceability](/archive/traceability/SP2a.md))
