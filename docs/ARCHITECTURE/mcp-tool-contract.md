---
type: Reference
title: MCP Tool Contract — the pushling_* Family
description: The single merged authority for the 9 pushling_* embodiment tools — verbatim descriptions, parameters, stage gates, degraded-mode behavior, and how each maps onto the 15 socket commands.
status: Live
tags: [mcp, reference, embodiment-tools]
timestamp: 2026-07-02T00:00:00Z
---

This is **the** authority for the 9 `pushling_*` MCP tools — it supersedes the
tool-contract sections of `PUSHLING_VISION.md`, `docs/archive/EMBODIMENT-REVIEW.md`
§4, `docs/archive/plan/phase-4-embodiment/PHASE-4.md` Tracks 1–2, and `mcp/README.md`'s
"The 9 Tools" table. Those four sources described four overlapping, partially
inconsistent versions of the same contract; this concept folds them into one,
verified against the shipping code (`mcp/src/tools/*.ts`,
`mcp/src/index.ts`). Tool *descriptions* below are quoted **verbatim** from
the `*Schema.description` constant in each tool's source file — not
paraphrased.

Design philosophy, embodiment-language rules (first-person, sensory framing,
the do/don't list), and the SessionStart awakening text that teaches Claude
how to inhabit its body are their own authority — see the future embodiment
concepts (SP7). This concept covers the **tool contract only**: what each
tool accepts, validates, sends, and returns.

# Layering: 9 Tools, 15 Commands

Each `pushling_*` tool sends one or more of the 15 raw socket commands
catalogued in [the IPC command catalog](/ARCHITECTURE/ipc-command-catalog.md).
The mapping is mostly 1:1, with two exceptions worth calling out:

- `pushling_sense(aspect: "version")` never reaches the socket — it's
  synthesized entirely client-side (`{app, mcp, engine, platform}` static
  strings) and is **not** one of the daemon's 8 `sense` actions.
- `pushling_nurture` always sends the *generic* wire form
  (`action: "set"/"remove"/"list"/"suggest"/"reinforce"`, sub-type in
  `params.type`) even though the daemon also accepts a direct form
  (`action: "habit"/"preference"/...`) — see
  [the command catalog's nurture section](/ARCHITECTURE/ipc-command-catalog.md#nurture-two-calling-conventions).

Three socket commands have **no MCP tool at all**: `reload`, `screenshot`,
`debug_nodes`. These are operator/debug-only, invoked directly over the raw
socket, not exposed to Claude.

**Validation-error rule, code-verified as followed throughout.**
`pushling/CLAUDE.md`'s MCP Server Rules stated the principle "return helpful
error messages on invalid arguments: explain what's valid" — every
`mcp/src/tools/*.ts` handler's client-side validation branch follows it
without exception: an unknown `move` action returns `"Unknown action 'X'
for move. Valid: goto, walk, stop, ..."`; an unknown `express` expression
returns `"Unknown expression 'X'. Valid: joy, curiosity, ..."`; a missing
`move` target names the valid target vocabulary for that specific action.
No tool ever returns a bare "invalid input" without also naming the valid
alternatives.

# Connect Snapshot

The `creature` object returned on `connect` — the snapshot the MCP server
caches for use in tool responses and `SessionStart` injection. This is the
**live, code-verified shape** (`CommandRouter.buildCreatureSnapshot()`, the
`gc != nil` path — the daemon has a fallback all-zero shape with the same keys
for the rare case it's called before `gameCoordinator` exists):

```json
{
  "name": "Zepus",
  "stage": "beast",
  "xp": 312,
  "personality": {"energy": 0.3, "verbosity": 0.7, "focus": 0.6, "discipline": 0.8, "specialty": "web_backend"},
  "emotions": {"satisfaction": 72, "curiosity": 85, "contentment": 64, "energy": 55},
  "speech": {"styles": ["say", "think", "exclaim", "whisper", "sing"]},
  "tricks_known": 6,
  "streak_days": 12
}
```

**Adjudicated drift:** both `docs/archive/IPC-PROTOCOL.md`'s example and
`mcp/src/ipc.ts`'s `CreatureSnapshot` TypeScript interface promise
`speech.max_chars` and `speech.max_words` fields. The live daemon path never
sends them — `speech` carries `styles` only. Per DOCS-WIN, this concept
documents the **actual daemon output** as canon (a client can't rely on
fields the server never sends); the `CreatureSnapshot` interface in
`mcp/src/ipc.ts` is flagged as a client/daemon contract mismatch for the
Orchestrator's backlog — it should either be corrected to match the live
shape, or the daemon should be extended to actually send those two fields
(whichever the team decides is the right fix; not a doc call to make).

# pushling_sense

> "Feel yourself, your surroundings, and what's happening. Proprioception — sense your emotional state, body, environment, and recent events. Omit aspect for a full reading of everything."

**Params:** `aspect?: string` — one of `self`, `body`, `surroundings`,
`visual`, `events`, `developer`, `evolve`, `version`, `full` (default
`"full"`; `version` is client-only, see above; `full` combines
`self`+`body`+`surroundings`+`events`+`developer`+`version`, excluding
`visual` and `evolve`).

Reads primarily from SQLite (works without the daemon running); `visual` and
`evolve` require the daemon. No daemon → most aspects still answer from
SQLite; `visual` specifically returns "Cannot capture a visual — the Pushling
daemon is not running." if disconnected.

| Aspect | Notes |
|---|---|
| `self` | Emotional state (4 axes) + `emergent_state` + `mood_summary` + `circadian_phase` + `streak_days` |
| `body` | Stage, appearance, personality axes, growth/XP progress, taught-trick names |
| `surroundings` | Weather (`state`, `duration_minutes`), terrain/biome, nearby objects, nearest/visible landmarks, companion — see `mcp/src/tools/sense.ts buildSurroundings()`. **Not shipped:** a `forecast` field ("rain likely") was designed (`docs/archive/plan/phase-4-embodiment/PHASE-4.md` P4-T1-03, "a simple probability statement derived from current weather-state transition weights") but `buildSurroundings()`'s `weather` object carries only `state`/`duration_minutes` today — no forecast computation exists anywhere in `mcp/src/` or `Pushling/Sources/`. |
| `visual` | Forwards to the `sense`/`visual` socket action — currently a not-yet-implemented acknowledgement, not a screenshot (see [the command catalog](/ARCHITECTURE/ipc-command-catalog.md)). **Not shipped, intent only:** the original design (`docs/archive/plan/phase-4-embodiment/PHASE-4.md` P4-T1-06) specified a natural-language scene description composed from surroundings+body+self data, plus an inline `screenshot_base64` PNG at 2170×60 @2x (<50ms capture, <100ms added latency) — richer than either the current ack or the separate operator-only `screenshot` command's path-returning shape (see [the command catalog](/ARCHITECTURE/ipc-command-catalog.md#sense--detail-not-covered-by-the-tool-contract)). This unbuilt-feature design belongs in a `FEATURES/` intent-canon entry, not here; flagged for the Orchestrator since no `FEATURES/` concept currently covers it (grep of `FEATURES/interactivity-unbuilt.md` and `FEATURES/roadmap.md` for "visual"/"screenshot_base64" returns nothing). |
| `events` | Last 20 journal entries |
| `developer` | Commit/touch activity timing, session state |
| `evolve` | Progress toward next stage; if eligible, sends `sense`/`evolve` to trigger the ceremony |
| `version` | Client-only static version info |

# pushling_move

> "Feel your limbs. Walk, run, sneak, jump through the Touch Bar world. Breathing and tail-sway continue as you move. After 30s of stillness, your body resumes wandering on its own."

**Params:** `action` (required, one of `goto`/`walk`/`stop`/`jump`/`turn`/
`retreat`/`pace`/`approach_edge`/`center`/`follow_cursor`), `target?: string`,
`speed?: "walk"|"run"|"sneak"`.

Requires the daemon (no SQLite fallback — locomotion is a live-state write).
Degraded message: "Your body is still — the Pushling daemon is not running.
Launch Pushling.app to inhabit your creature."

Speeds: walk 30 pt/s, run 80 pt/s, sneak 12 pt/s (`mcp/src/tools/move.ts
SPEED_PTS`). See
[the command catalog's target-parameter note](/ARCHITECTURE/ipc-command-catalog.md#current-implementation-note-moves-target-parameter)
for a live client/daemon mismatch on how `target` is actually consumed
server-side.

**Response — sensory narrative, client-composed:** the daemon's own reply
(see [the response-shape table](/ARCHITECTURE/ipc-command-catalog.md#tool-command-details--response-data-shapes))
carries only mechanical fields (`position_x`, `facing`, `estimated_duration_ms`).
`mcp/src/tools/move.ts`'s `generateMoveNarrative()` (lines 101–168) then
composes a `narrative` string on top of that, and this **is** live, shipped
behavior — not aspirational: per-action base prose (`"You pad left. The
ground is steady beneath your paws."` for a walk-speed `goto`/`walk`;
`"You sprint left -- ears flat, paws pounding."` at run speed; `"You creep
left, belly low, eyes wide."` at sneak speed; distinct lines for `stop`,
`jump`, `turn`, `retreat`, `pace`, `center`, `approach_edge`,
`follow_cursor`), then **weather-modulated** for every non-`stop` action by
appending to the base line: `" Rain patters on your fur."` (rain),
`" Your paws leave prints in the snow."` (snow), `" Wind buffets you."`
(storm) — read live from `StateReader.getWorld().weather`, no daemon round
trip needed for the modulation itself. The tool's final JSON response is
`{accepted, action, position_x, facing, estimated_duration_ms, position_z?,
speed, narrative, target?, pending_events}` — the daemon's raw fields
spread in verbatim, then `speed`/`narrative`/a client-computed
`estimated_duration_ms` (which overrides the daemon's own estimate; see the
citation below) layered on top.

**Duration estimate has two independent authors.** The daemon computes its
own `estimated_duration_ms` from world-thread state
(`ActionHandlers.handleMove()`); `move.ts`'s `estimateDuration()` computes a
second, client-side estimate from `StateReader`'s cached `creature_x` and
the same speed table, and it's the **client's** number that survives into
the final response (spread order: daemon fields first, then the
client-computed `estimated_duration_ms` overwrites it) — a real, harmless
double-computation rather than a single shared source of truth.

# pushling_express

> "Emotional display. Show what you feel. Express joy, curiosity, surprise, love, mischief, and more. Intensity and duration control the animation's amplitude and how long it lasts."

**Params:** `expression` (required, one of 16: `joy`, `curiosity`, `surprise`,
`contentment`, `thinking`, `mischief`, `pride`, `embarrassment`,
`determination`, `wonder`, `sleepy`, `love`, `confusion`, `excitement`,
`melancholy`, `neutral`), `intensity?: number` (0.0–1.0, default 0.7),
`duration?: number` (0.1–30.0s, default 3.0).

Requires the daemon. Response echoes back `transition_speed_s: 0.3` and
`fade_to_autonomous_s: 0.8` — AI-directed expressions transition faster
(0.3s) than autonomous ones (0.8s), the visible "this was intentional" cue.
No stage gates — all 16 expressions are available from Egg onward.

**Response — full visual pose description, shipped verbatim from the
original design.** `mcp/src/tools/express.ts`'s `EXPRESSION_DESCRIPTIONS`
constant (lines 35–52) is a live, code-verified, word-for-word match (modulo
lowercasing the leading word) of `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
P4-T2-02's "Animation Description" column — this is **shipped**, not
unbuilt design intent:

| Expression | Animation Description |
|---|---|
| `joy` | eyes bright, ears up, tail high, bouncy step |
| `curiosity` | head tilt, ears rotate independently, eyes widen |
| `surprise` | ears snap back, eyes wide, jump-startle, fur puffs |
| `contentment` | slow-blink, kneading paws, purr particles |
| `thinking` | head slight tilt, one ear forward one back, tail still |
| `mischief` | narrow eyes, low crouch, tail tip twitching |
| `pride` | chest out, chin up, tail high and still |
| `embarrassment` | ears flat, looks away, tail wraps around body |
| `determination` | ears forward, eyes focused, stance widens |
| `wonder` | eyes huge, ears high, mouth slightly open |
| `sleepy` | heavy blinks, yawns, ears droop |
| `love` | slow-blink, headbutt toward screen, purr particles |
| `confusion` | head tilts alternating sides, ear rotates, '?' symbol |
| `excitement` | zoomies trigger, tail poofs, ears wild |
| `melancholy` | tail low, slow movement, muted colors, quiet |
| `neutral` | reset to default idle expression |

Every string above is this description table, not a separate animation
implementation — `EXPRESSION_DESCRIPTIONS[expression]` is echoed straight
into the tool's response `visual` field:
`{accepted: true, expression, visual: <the description above>, intensity,
duration_s, transition_speed_s: 0.3, fade_to_autonomous_s: 0.8,
pending_events}`. Claude reads its own expression back as prose, not a
bare animation-state enum.

# pushling_speak

> "Your voice. Stage-gated — as a Spore you are silent, as a Drop you chirp symbols (! ? ♡ ~ ... ♪ ★), as a Critter your first words emerge, and so on up to Apex with full fluency. Choose a style for the delivery."

**Params:** `text` (required), `style?` — one of `say` (default), `think`,
`exclaim`, `whisper`, `sing`, `dream`, `narrate`.

Two layers of stage gating apply, both real, at different points: the MCP
tool filters `text` to the current stage's char/word budget *before* sending
it to the daemon (`mcp/src/tools/speak.ts STAGE_LIMITS`); the daemon then
independently re-validates through `SpeechCoordinator`/`SpeechFilterEngine`,
which returns `SPEECH_GATED` on rejection (`ActionHandlers.handleSpeak()`).
The exact per-stage char/word budgets and per-style stage minimums have
known three-way inconsistencies across `mcp/src/tools/speak.ts`,
`Pushling/Sources/Pushling/Speech/SpeechFilterEngine.swift`, and
`SpeechBubbleNode.SpeechStyle.minimumStage` (e.g. Drop's char limit is 6 on
the MCP side vs. 3 daemon-side; `exclaim`'s stage minimum is `drop` per the
MCP client and the design docs but `critter` in
`SpeechBubbleNode.minimumStage`). Full resolution of the speech-filtering
pipeline is out of scope here — it belongs to the future speech-and-voice
concept (SP4), which owns `SpeechFilterEngine` end to end; this contract only
documents that `pushling_speak` performs client-side filtering, sends the
already-filtered text plus (when content was lost) the original
`intended_text`, and that a `failed_speech` journal entry results whenever
filtering drops meaningful content.

Requires the daemon. Egg stage (`state.getCreature().stage === "spore"` in
the MCP-side check — see the growth-stages concept (SP3a) for the `spore`
vs. `egg` naming history) returns a dedicated in-character refusal rather
than reaching the daemon at all — the live text (`mcp/src/tools/speak.ts:118`)
is `"You cannot speak yet. You are pure light — no mouth, no voice."`, which
differs in wording from `docs/archive/IPC-PROTOCOL.md`'s illustrative
`STAGE_GATE` example (`"Spore cannot speak. You are pure light —
communication is through brightness and pulse. Grow to Drop stage to unlock
symbol expression."`) — that archived example describes a daemon-side
`STAGE_GATE` error code that does not exist in the shipped `SocketServer`/
`CommandRouter` error vocabulary (see
[the wire protocol's error table](/ARCHITECTURE/ipc-wire-protocol.md#error-vocabulary));
the real refusal never reaches the daemon at all, so the design intent
survives in spirit (an in-character, stage-appropriate refusal) but not in
either exact wording or mechanism.

# pushling_perform

> "Express yourself through movement. Wave, spin, bow, dance, backflip — or chain up to 10 steps into a choreographed performance. These are your body's vocabulary beyond words. Stage-gated by growth."

**Params:** either `behavior?: string` + `variant?: string` (single-behavior
mode) **or** `sequence?: SequenceStep[]` + `label?: string` (sequence mode) —
never both, never neither.

18 built-in behaviors, each with a stage minimum and 2–3 named variants
(`mcp/src/tools/perform.ts VALID_BEHAVIORS`):

| Behavior | Stage min | Variants |
|---|---|---|
| `wave` | drop | big, small, both_paws |
| `spin` | drop | left, right, fast |
| `examine` | drop | sniff, paw, stare |
| `celebrate` | drop | small, big, legendary |
| `nap` | egg | light, deep, dream |
| `shiver` | egg | cold, nervous, excited |
| `bow` | critter | deep, quick, theatrical |
| `dance` | critter | waltz, jig, moonwalk |
| `peek` | critter | left, right, above |
| `dig` | critter | shallow, deep, frantic |
| `stretch` | critter | morning, lazy, dramatic |
| `meditate` | beast | brief, deep, transcendent |
| `flex` | beast | casual, dramatic |
| `backflip` | beast | single, double |
| `play_dead` | beast | dramatic, convincing |
| `conduct` | sage | gentle, vigorous, crescendo |
| `glitch` | apex | minor, major, existential |
| `transcend` | apex | brief, full |

The client-side gate above (`VALID_BEHAVIORS[...].stage_min`) is what a
Claude caller actually experiences, since it's checked before any socket
call. The daemon's own gate, in `PerformActionMapping.map()`, is looser for
`glitch` (requires `.sage`, not `.apex`) — harmless in practice today because
the stricter client gate always runs first, but worth knowing if the client
gate is ever bypassed or the daemon command is called directly.

**Sequence mode:** up to 10 steps, each `{tool: "move"|"express"|"speak"|"perform", params, delay_ms?: 0-5000, await_previous?: bool}`.
A `perform` step cannot itself contain a nested `sequence`. Stage gates on
any `perform` steps inside the sequence are checked client-side before
sending.

Requires the daemon for both modes.

# pushling_world

> "Shape the environment around you. Change weather, trigger visual events, place objects, override the sky cycle, play ambient sounds, or introduce companions. The world responds to your touch."

**Params:** `action` (required, one of `weather`/`event`/`place`/`create`/
`remove`/`modify`/`time_override`/`sound`/`companion`), `params: object`
(required, action-specific — see
[the world action table](/ARCHITECTURE/ipc-command-catalog.md), or the
per-action shapes in `mcp/src/tools/world.ts`'s schema description).

Object limits: 12 persistent + 3 consumable, minimum 20pt spacing, max 40
object nodes, max 1 companion at a time, 20 named creation presets. Requires
the daemon; degraded message: "The world is frozen — the Pushling daemon is
not running."

# pushling_recall

> "Access memories. What do you remember? Query past events — commits eaten, touches, conversations, milestones, dreams, your relationship with the human, or things you tried to say."

**Params:** `what?: string` — one of `recent` (default), `commits`,
`touches`, `conversations`, `milestones`, `dreams`, `relationship`,
`failed_speech`; `count?: number` (default 20, max 100 — dreams default to a
lower internal count).

Pure SQLite read — works with no daemon (still drains pending events via
`ping()` if the daemon happens to be connected). `relationship` is a computed
summary, not a raw journal dump: trust level derived from touch-count tiers
(stranger < 10 < acquaintance < 50 < companion < 200 < trusted friend <
bonded), favorite gesture, longest session.

# pushling_teach

> "Teach your body new tricks. Choreograph multi-track animations that become part of who you are — they persist and play autonomously during idle, in response to triggers, and in dreams. Compose, preview, refine, commit to muscle memory. Max 30."

**Params:** `action` (required, one of `compose`/`preview`/`refine`/`commit`/
`list`/`remove`/`reinforce`), plus `name?`, `category?` (playful,
affectionate, dramatic, calm, silly, functional), `duration_s?` (0.5–15.0),
`stage_min?`, `tracks?` (per-track keyframe arrays across 16 track names:
`body`, `head`, `ears`, `eyes`, `tail`, `mouth`, `whiskers`, `paw_fl/fr/bl/br`,
`particles`, `aura`, `speech`, `sound`, `movement`), `triggers?`
(`idle_weight`, `on_touch`, `emotional_conditions`).

`list` is SQLite-only (works without the daemon); `reinforce` is handled
client-side against SQLite plus a daemon `ping()`; every other action
requires the daemon. Cap: 30 taught behaviors total
(`mcp/src/tools/teach.ts MAX_TAUGHT`).

This tool was described as "stubbed with helpful coming-soon messages,
completed in Phase 7" in `docs/archive/plan/phase-4-embodiment/PHASE-4.md` — that
scope note is stale. `mcp/src/tools/teach.ts` plus
`Pushling/Sources/Pushling/IPC/CreationHandlers.swift` are fully implemented.

# pushling_nurture

> "Shape yourself. Set habits, preferences, quirks, and routines that become your behavioral signature. These persist and run autonomously with organic variation — they are who you become when nobody is directing you."

**Params:** `action` (required, one of `set`/`remove`/`list`/`suggest`/
`reinforce`/`get`), `type` (required, one of `habit`/`preference`/`quirk`/
`routine`/`identity`), `params?: object` (type-specific).

Also described as Phase-7-stubbed in the older phase plan — also stale, also
fully implemented (`mcp/src/tools/nurture.ts` +
`Pushling/Sources/Pushling/IPC/NurtureHandlers.swift`). `list` and `get` are
SQLite-only; `suggest`, `set`, `remove`, `reinforce` require the daemon.
Reinforcement adds +0.15 strength; caps are 20 habits / 12 preferences / 12
quirks / 10 routine slots; `identity` cannot be removed or reinforced (only
`set`).

# Citations

[1] `mcp/src/tools/sense.ts`, `move.ts`, `express.ts`, `speak.ts`, `perform.ts`, `world.ts`, `recall.ts`, `teach.ts`, `nurture.ts`
[2] `mcp/src/index.ts` (tool registration)
[3] `Pushling/Sources/Pushling/IPC/CommandRouter.swift` (`buildCreatureSnapshot`)
[4] `mcp/src/ipc.ts` (`CreatureSnapshot` interface)
[5] `PUSHLING_VISION.md` — MCP Integration: Claude as the Creature's Mind
[6] `docs/archive/EMBODIMENT-REVIEW.md` §4 — MCP Tools: The Motor Cortex
[7] `docs/archive/plan/phase-4-embodiment/PHASE-4.md` — Tracks 1–2 (P4-T1-03, P4-T1-06, P4-T2-02 restored above; remaining scope notes superseded)
[8] `mcp/README.md` — The 9 Tools (superseded seed table)
[9] `mcp/src/tools/move.ts` (`generateMoveNarrative`, `estimateDuration`)
[10] `mcp/src/tools/express.ts` (`EXPRESSION_DESCRIPTIONS`)
[11] `mcp/src/tools/speak.ts` (Egg-stage refusal text)
[12] `mcp/src/tools/sense.ts` (`buildSurroundings`)
