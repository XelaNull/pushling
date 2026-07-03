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
*parameter* prose for the remaining commands lives with their MCP tool in
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md) to avoid
duplicating one contract across two concepts. The *response* `data` shapes
for every stateful command — genuinely missing from both concepts until now
— are below, code-verified against each `*Handlers.swift` and corrected
against `docs/archive/IPC-PROTOCOL.md`'s "Tool Command Details" section,
which described several of these shapes inaccurately (wrong field names,
fields that don't exist, or fields the archived doc omitted).

# Tool Command Details — Response `data` Shapes

None of these are guesses or paraphrase — every field below is read
directly from the `.success([...])` dictionary literal in the cited
handler. Where the archived spec's claim differs from the live shape, the
drift is called out explicitly rather than silently corrected.

**`move`** (`ActionHandlers.handleMove()`) — `{accepted: true, action,
position_x: Int, facing, estimated_duration_ms}`, plus `position_z` only
when a `z` param was sent. `jump` is a special case with no
`estimated_duration_ms`: `{accepted, action: "jump", position_x, facing}`.
`pace` returns `{accepted, action: "pace", range, estimated_duration_ms}`
(no `position_x`/`facing`). `follow_cursor` is rejected client-visibly:
`{accepted: false, error: "follow_cursor is handled by the autonomous
layer..."}`. **Drift:** the archived doc's `{accepted, position, facing}`
names neither `position_x` nor `action`/`estimated_duration_ms`/`position_z`
— the real shape is richer and uses a different position field name.

**`express`** — `{expression, intensity, duration}` in the archived doc;
live shape (`mcp/src/tools/express.ts`, client-composed — the daemon itself
only echoes `{expression, intensity, duration}` unchanged) is `{accepted:
true, expression, visual: <animation description>, intensity, duration_s,
transition_speed_s: 0.3, fade_to_autonomous_s: 0.8}` — see
[the tool contract's full description table](/ARCHITECTURE/mcp-tool-contract.md#pushling_express).

**`perform`** (`ActionHandlers.handlePerform()`) — three distinct shapes
depending on how the behavior resolved, **none of which include a
`stage_ok` field** (the archived doc's `stage_ok: true` does not exist in
code — a stage-gate failure is a hard `.failure(code: "STAGE_GATED")`, not
a success response with a boolean flag):
- Taught trick: `{accepted: true, behavior, source: "taught", mastery:
  <displayName>, estimated_duration_ms}`
- Built-in cat behavior: `{accepted: true, behavior, source: "built_in",
  variant, estimated_duration_ms}`
- Mapped/legacy behavior: `{accepted: true, behavior, source: "mapped",
  variant, estimated_duration_ms}`
- Sequence (`action: "sequence"`): `{accepted: true, steps: Int, label,
  estimated_duration_ms}` — this one shape matches the archived doc exactly.

**`world`** (`WorldHandlers.swift`) — response shape varies per action, and
every one of them differs from the archived doc's flattened
`{object_id, position, type}` / `{companion_id, type, name}` guesses:
- `weather` (with a `type` param): `{type, previous, duration_s, note}` —
  field is `duration_s`, not `duration`; no `type` echo distinct from the
  request's. Without a `type` param, `weather` instead returns a status
  read: `{current, time_of_day, moon_phase, is_full_moon, description}`.
- `event`: `{event, started: true, duration_s}` on success, or `{event,
  started: false, note}` if queued/stage-gated.
- `time_override`: `{period, note}` (or `{current_period, note}` with no
  `period` param; `{period: "auto", note}` to clear).
- `place`/`create`: `{created: true, object: <ObjectInfo>, note}` where
  `ObjectInfo` (`WorldManager+Objects.swift` `asDictionary`) is `{id, name,
  base_shape, position_x, layer, size, interaction, wear, source,
  created_at}` — there is no `object_id` or `preset` field in the response
  at all; the object's SQLite integer `id` is the only identifier.
- `remove`: `{removed: true, id, note}`.
- `modify` (repair): `{repaired: true, ...}`.
- `companion` (`action: "spawn"`/`"add"`): `{spawned: true, companion:
  {type, name, display_name}, note}` — **no `companion_id` field exists**;
  a companion is looked up by type/singleton state, not an ID. `action:
  "remove"`/`"despawn"`: `{removed: true, note}`.

**`recall`** — `{memories, count, filter}` (`CreationHandlers.handleRecall()`)
— this one matches the archived doc's claim exactly, no drift.

**`teach`** (`compose` action, `CreationHandlers.handleTeachCompose()`) —
`{valid: true, name, category, tracks, duration_s, stage_min, note}` — **no
`draft_id` field**; a composed-but-uncommitted choreography isn't persisted
with an ID at all, it's re-validated from the same `choreography` params
the caller sends again to `commit`. The archived doc's `draft_id`-based
draft/commit model does not match how the shipped tool works.

**`nurture`** (`habit` set, `NurtureHandlers.handleNurtureSetHabit()`) —
`{created: true, name, behavior, frequency, strength, trigger_type, note}`,
plus `personality_conflict`/`conflict_type`/`reluctance_level` when the
creature's personality resists the habit (see
[the nurture system](/SYSTEMS/nurture-system.md) for the rejection
mechanic). **No `habit_id` field** — habits are addressed by `name`, not a
generated ID, in every subsequent nurture call.

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
[7] `Pushling/Sources/Pushling/IPC/WorldHandlers.swift` (`handleWorldWeather`, `handleWorldEvent`, `handleWorldTimeOverride`, `handleWorldCreate`, `handleWorldRemove`, `handleWorldModify`, `handleWorldCompanion`)
[8] `Pushling/Sources/Pushling/World/WorldManager+Objects.swift` (`ObjectInfo.asDictionary`, `addCompanion`)
[9] `Pushling/Sources/Pushling/IPC/CreationHandlers.swift` (`handleRecall`, `handleTeachCompose`)
