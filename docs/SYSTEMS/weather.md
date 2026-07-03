---
type: System
title: Weather System
description: The six-state weather machine with weighted transitions and randomized 30-60s crossfades, the rain/snow/storm/fog particle renderers and their exact budgets, the creature's reflex-priority reactions to each weather state, and (designed, not built) the world-state consequence signals — windVector, post-rain ephemeral puddles, snow footprint/cap memory, transition lead-time hook, sunbeam eligibility — that feed environment-reactions.md and idle-life-and-rest.md.
status: Live
tags: [world, weather, particles, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **weather** — the state machine, every particle
renderer's constants, and how the creature's body reacts. It does not own
the sky gradient or clouds that weather modulates (see
[sky & celestial system](/SYSTEMS/sky-celestial.md), which reads this
system's darkening/cloud-density outputs), or stage-gating of which weather
states are even reachable (see
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)).
It also now specifies (below, all designed-not-built) the world-state
*consequence* signals other systems consume: `windVector`, the post-rain
ephemeral puddle lifecycle, snow footprint/cap memory, a transition
lead-time hook, and the sunbeam eligibility gate — the creature-facing
reaction verbs those signals feed live in
[environment-reactions.md](/SYSTEMS/environment-reactions.md) and
[idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md#6-sunbeam--warm-spot-seeking),
cross-linked rather than repeated here.
Source: `World/WeatherSystem.swift`, `World/RainRenderer.swift`,
`World/SnowRenderer.swift`, `World/StormSystem.swift`,
`World/FogRenderer.swift`, `Creature/CatBehaviors+Weather.swift`.

# The State Machine

Six states, checked for a possible transition **every 5 minutes**
(`checkInterval = 300s`) — not per-frame, not per-tick. `WeatherState`
carries its own probability weight, duration range, and the set of states it
is allowed to transition *to* (preventing jarring jumps like clear straight
to storm):

| State | Transition probability | Duration range | Valid next states | Sky darken factor |
|---|---|---|---|---|
| Clear | 55% | 5-30 min | clear, cloudy, fog | 0.0 |
| Cloudy | 18% | 5-20 min | clear, cloudy, rain, snow, fog | 0.1 |
| Rain | 12% | 5-15 min | clear, cloudy, rain, storm | 0.25 |
| Storm | 5% | 3-10 min | rain, cloudy (storms die down, never straight to clear) | 0.5 |
| Snow | 3% | 5-20 min | clear, cloudy, snow | 0.05 |
| Fog | 7% | 5-25 min | clear, cloudy, fog | 0.15 |

Weighted selection (`selectNextWeather`) rolls only among the *current*
state's `validTransitions`, weighted by each candidate's own probability —
so, for example, storm can only be reached from rain, never directly from
clear. Storm's darkening color is a Void→Dusk blend (15%) rather than the
generic Ash-at-50%-alpha every other state uses, per `skyDarkenColor`.

**Transitions crossfade over a randomized 30-60 seconds**
(`transitionDurationRange = 30...60`) — this corrects
`docs/archive/plan/phase-3-world/PHASE-3.md`'s fixed "30-second crossfade" spec;
the shipped duration is randomized within that range each time, per
`WeatherTransition.duration`. During a transition, the outgoing renderer's
intensity fades `1.0 → 0.0` and the incoming renderer's fades `0.0 → 1.0` in
lockstep with `transition.progress`; the outgoing renderer is fully
deactivated and the incoming one snapped to full intensity only once
`progress >= 1.0`. Weather state and its last-changed timestamp persist to
SQLite; on daemon restart, `restoreState(weather:changedAt:)` reconstructs
the correct remaining duration from elapsed wall-clock time rather than
resetting the clock.

An MCP-driven override (`pushling_world("weather", ...)` →
`forceWeather(_:duration:)`) sets `overrideState`, which both suppresses the
normal 5-minute check and immediately begins a transition to the forced
state; an optional duration auto-clears the override afterward.

# Particle Renderers

All four use **pre-allocated, recycled sprite pools** — no per-frame
allocation, and each is architecturally a parallel-array pattern (a struct of
plain values driving a matching array of `SKSpriteNode`s), not
`SKEmitterNode`-based, so that terrain-aware behavior (impact splashes,
accumulation) is straightforward to hand-code.

## Rain

50-droplet pool, individually spawned up to a target of 30-50 concurrently
active. Each droplet is a 3×4pt Tide teardrop texture (hand-pixeled mask, not
a rectangle) falling at 100-140pt/sec with 5-15pt/sec horizontal wind drift
(randomized direction per activation) plus ±3pt/sec jitter. On terrain
impact (compared against a real terrain-height callback, `terrainHeightAt`,
when wired by the scene — falling back to a flat `groundY = 4.0` otherwise),
3 splash particles (1×1pt, Tide @ 0.3 alpha) burst outward at randomized
upper-arc angles and fade over 100ms, with light gravity pulling them back
down. `stormSpawnRateMultiplier` lets the storm system multiply the base
spawn rate for heavier storm rain without a second droplet pool.

## Snow

30-flake pool, targeting 15-30 concurrent. Three size classes (1.0/1.5/2.0×
base) with larger flakes falling slower (0.8× the base 20-40pt/sec range) —
this is the "larger = closer, larger = slower" depth cue. Lateral drift is a
per-flake sine oscillation (0.3-0.8Hz, ±5-10pt/sec amplitude), not a
straight-line fall. **Ground accumulation** is a single overlay bar
(`accumulationNode`, Bone @ up to 0.5 alpha, `yScale` mapped to level)
building at 0.05/minute while snow is active and melting at 0.2/minute
(~5 minutes to fully clear) once it stops — the ratio is intentional: snow
builds slowly, melts faster, matching the described "melts over 5 minutes."

## Storm

Composes with rain (activates `RainRenderer` at a heavier spawn multiplier)
and adds `LightningNode`, an 8-12 segment jagged polyline spanning the full
1085pt width with random horizontal offsets (±40pt/segment) — regenerated
fresh on every strike, never reused. Strike cadence is randomized 8-20
seconds; each strike runs a 100ms full-brightness (Bone) flash plus a 200ms
Gilt-tinted afterimage fading to zero, alongside a full-screen additive
"flash overlay" sprite at 0.15 alpha for the flash duration. **Screen shake**
is a 2pt-magnitude, 300ms-decaying random offset applied directly to the
scene's `position` (not the camera), synchronized to start with the flash.
**Thunder is delayed 0.5-2.0 seconds after the flash** — light before sound,
deliberately — and the creature's fear reaction (see below) is tied to the
thunder callback, not the lightning one, "for realism."

## Fog

Three horizontal strips at different depths and speeds — near (alpha 0.3,
drifts left 5pt/sec, zPosition 40, above terrain objects), mid (alpha 0.2,
drifts *right* 3pt/sec, zPosition -40), far (alpha 0.15, near-static at
-0.5pt/sec, zPosition -90, behind the mid layer). Each strip is actually two
side-by-side sprites that reposition to tile seamlessly as they drift
(`FogStripNode`'s two-sprite wrap trick), avoiding a visible seam without a
repeating-texture shader. Density fades in/out over a full **60 seconds**
(`fadeDuration`), independent of the weather-machine's own 30-60s
crossfade — fog specifically takes the full minute to reach target density
even mid-transition, since the "reduced visibility" effect reads badly if it
snaps.

# Creature Reactions

`CatWeatherReactions` implements `WeatherReactionDelegate` and drives the
creature's body-part controllers directly (ears/eyes/tail/paws) — these are
Reflex-priority reactions in the
[4-layer behavior stack](/SYSTEMS/behavior-stack.md), overriding autonomous
wandering but yielding to human touch:

| Trigger | Reaction |
|---|---|
| Rain or storm begins | Ears flatten (0.3s), body compresses to 0.95 `yScale`, head lowers 1pt — a hunching posture held for the duration |
| Lightning flash | Instant flinch: ears flat + eyes squint (0.05s), a quick 2pt hop up-then-down (0.05s up / 0.10s down), recovering to neutral ears/eyes over 0.15s |
| Thunder rumble (delayed) | Fear: ears flat, eyes wide, tail dropped low (0.1-0.15s), held for a full second before recovering to neutral/sway over 0.3s |
| Snow begins | Body rises 1pt (looking up), front-left paw swipes at flakes, then a scheduled paw-cycle alternates FL/FR swipe-then-ground states over several seconds |
| Fog (any density) | Eyes squint; the creature's overall movement speed multiplier drops by up to 30% (`1.0 − density × 0.3`) — cautious, not blind |
| Weather clears (from rain or storm) | A 3-repetition ±5° body shake-off sequence, then a full return to neutral posture and full speed |

All persistent postures (rain compress, snow paw-cycle) are explicitly
cleared (`clearPersistentEffects`) before a new weather posture applies, so
overlapping transitions never leave stale animations running; reactions are
suppressed entirely while the creature is asleep
(`guard !creature.isSleeping`).

# World-State Consequences (Reaction-Feed Signals)

**Status: designed, not built** for every signal below — a fifth area
layered onto the shipped state machine and renderers above. This section
owns the world-state *outputs* only — the scalar, the object lifecycle, the
hook, the eligibility gate — not the body language or locomotion that
consumes them; those verbs live in
[environment-reactions.md](/SYSTEMS/environment-reactions.md) and
[idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md#6-sunbeam--warm-spot-seeking)
and are cross-linked, not repeated here.

## Wind Vector

A new `windVector: CGFloat` property on `WeatherSystem`, range `[-1, 1]`,
updated every frame inside `update(deltaTime:)`. **Confirmed absent from
the codebase today** — the only existing wind value is
`RainRenderer.windDrift` (`RainRenderer.swift:120`), a *private*,
rain-renderer-internal `CGFloat` in `[-15, 15]`pt/s that only angles falling
raindrop sprites and is re-randomized fresh on every rain activation
(`RainRenderer.swift:168, 238`) — not a world-readable signal, and
`windVector` does not reuse it.

| `currentState` | `windVector` magnitude | Pattern |
|---|---|---|
| Storm | held near ±1.0 | Sign rolled once per storm activation, steady for the state's full duration |
| Cloudy | ±0.3-0.6 | Gusty pulses, 3-8s each, 10-30s silent gaps between (returns to 0 in the gaps) |
| Rain | ±0.4-0.6 | Steady, sign rolled once per rain activation — no pulsing |
| Clear | ±0.15-0.25 | Rare breeze pulses, 3-8s, rolled at low probability (~10%) on each 5-minute `checkForWeatherChange` tick |
| Snow, Fog | ±0.0-0.1 | Near-zero — these two states don't read as windy |

Every value change (pulse start/end, state transition) eases over 0.3-0.5s
rather than snapping — one `CGFloat` lerp per frame, frame-budget-trivial.
`windVector` is read by Gust Front's ear/whisker/tail/lean/speed table
([environment-reactions.md §4](/SYSTEMS/environment-reactions.md#4-gust-front))
and the `CloudSystem`/debris/feather-object consumers noted there; this
concept owns only the scalar's production, not its consumption.

## Post-Rain Ephemeral Puddles

**Ground truth, so this doesn't get conflated with the ambient decoration
puddle:** `TerrainObjectType.waterPuddle` (`TerrainObjectPool.swift:19`,
an 8×1.5pt ellipse) is one of 10 biome-weighted terrain decorations placed
by ordinary terrain generation — it exists independent of whether it has
rained, and it's what
[`PuddleReflection`](/SYSTEMS/world-complexity-ambient-effects.md#puddle-reflections)
already reacts to via `WorldManager.findNearestPuddle`
(`WorldManager.swift:434-438`). This section specifies a **second,
weather-triggered** puddle lifecycle that reuses the exact same
`TerrainObjectType.waterPuddle` node/query path — zero changes needed to
`PuddleReflection` — but layers its own weather-driven spawn and decay
timer on top, so it stays conceptually distinct even though it shares the
type.

**Trigger:** a new `worldEffectDelegate: WeatherWorldEffectDelegate?`
property on `WeatherSystem`, separate from the existing creature-facing
`reactionDelegate` (that slot is singular and already claimed by
`CatWeatherReactions` — `Creature/CatBehaviors+Weather.swift:9`) — mirrors
the same delegate-per-concern pattern already in use. `WorldManager`
(which already owns both `weatherSystem` and `terrainRecycler`,
`WorldManager.swift:51,89`) conforms and fires puddle spawn whenever
`completeTransition()` observes `previousState == .rain || previousState ==
.storm`, **regardless of the destination state** — broader than the
existing `weatherCleared` check (`WeatherSystem.swift:333`), which only
fires when landing specifically on `.clear`; rain stopping and drifting
straight to cloudy should still leave puddles behind.

| Parameter | Value |
|---|---|
| Spawn count | 2-3 puddles |
| Size | 4-8pt wide, 1pt tall, `PushlingPalette.tide` at 0.4 alpha ellipse |
| Placement | Terrain low points: sample `TerrainGenerator.heightAt(worldX:)` (`TerrainGenerator.swift:100`) across the visible-plus-margin range at a coarse stride — the same extremum-scan technique the dusk vantage ritual uses for local maxima ([environment-reactions.md §7](/SYSTEMS/environment-reactions.md#7-golden-hour-dusk-vantage)), inverted to take minima — spaced ≥40pt apart so they don't cluster |
| Lifetime | 10-20 minutes |
| Decay | Shrinks 10% of current width per minute; despawns below 20% of spawn width |

Because these are literal `.waterPuddle`-type objects inserted into
`TerrainRecycler`'s active object list, every verb in
[environment-reactions.md §6](/SYSTEMS/environment-reactions.md#6-puddle-days--dabbing)
(splash-hop, tiptoe detour, reflection gaze, dab, wet shake) fires against
them with no additional wiring — that table is already written to be
puddle-source-agnostic for exactly this reason.

## Snow Memory — Footprint & Cap State

`SnowRenderer`'s shipped `accumulationNode` (`SnowRenderer.swift:82`,
building at 0.05/min and melting at 0.2/min — `SnowRenderer.swift:68,71`) is
a single ground-level overlay bar that accumulates but records nothing
about the creature's passage. Two new pieces of state extend it — the
shake-off and first-snow verbs that consume this state are
[environment-reactions.md §5](/SYSTEMS/environment-reactions.md#5-snow-memory)'s
territory and aren't repeated here:

| State | Spec |
|---|---|
| Footprint decay array | Active once `accumulationLevel >= 0.5`. A `[(worldX: CGFloat, stampedAt: TimeInterval)]` array on `SnowRenderer`; each creature footfall appends an entry and notches a 1×0.5pt void gap into `accumulationNode`'s fill path at that world-X. Entries — and their notches — expire and refill after 60-120s, one path rebuild per stamp/expiry (event-driven, not per-frame) |
| Creature snow-cap | One new `SKShapeNode` (bone crescent) tracking `bodyNode`'s transform, independent of the ground bar's own pacing — it grows 0.3→1pt over 2-3 minutes of continuous snowfall, much faster than the ground bar's ~20-minute full build, since snow lands on the creature directly rather than diffusely across the whole terrain strip |

## Weather-Transition Lead-Time Hook

**No existing lead-time signal.** `checkForWeatherChange()` runs once every
5 minutes (`checkInterval = 300`, `WeatherSystem.swift:145`) and, on a hit,
`selectNextWeather()` and `beginTransition(to:)`
(`WeatherSystem.swift:265, 294`) happen at the same instant — the 30-60s
crossfade (`transitionDurationRange`, line 148) begins with zero warning.
Two small, additive changes to `WeatherReactionDelegate`'s existing
call-site pattern (`WeatherSystem.swift:111-134`) give a horizon-reaction
system its runway *inside* that crossfade rather than needing a second
scheduler:

1. A new delegate method, `weatherApproaching(_ incoming: WeatherState)`,
   called once from the top of `beginTransition(to:)` — before
   `activateRenderer(for:)` runs — but **only** when `newState` is `.rain`,
   `.storm`, or `.snow` (clear/cloudy/fog transitions stay silent; this
   signal is for sensing dramatic weather, not every mood shift).
2. A new public read-only accessor, `var transitionProgress: CGFloat? {
   activeTransition?.progress }`, exposing the `WeatherTransition.progress`
   value `updateTransitionRenderers` already computes every frame
   (`WeatherSystem.swift:343`) but which is currently private — zero new
   computation, just a public window onto existing state.

With both in place, "first drops" is defined as the moment
`transitionProgress` crosses 0.4 — the front is visible and sensed from
0.0 (the `weatherApproaching` call), and the 20-40s lead time falls
naturally out of wherever 0.4 lands within that transition's randomly
rolled 30-60s duration. The full sense-beat, shelter-seeking timing (settle
≈0.35), and the per-incoming-state front visual on the far parallax layer
are [environment-reactions.md §3](/SYSTEMS/environment-reactions.md#3-weather-on-the-horizon)'s
territory.

## Sunbeam Eligibility Signal

**Naming correction against the dossier:** there is no `.sunny`
`WeatherState` case — the six states are `clear`, `cloudy`, `rain`,
`storm`, `snow`, `fog` (`WeatherSystem.swift:15-20`); `.clear` is the
correct case to key off. No new `WeatherSystem` code is needed beyond the
already-public `currentState` — the eligibility gate is simply
`currentState == .clear`, combined by the consumer with `SkySystem`'s
daytime `TimePeriod`s. The beam-x position, its 20-40s drift, and the
walk/sprawl/migration behavior are owned entirely by
[idle-life-and-rest.md §6](/SYSTEMS/idle-life-and-rest.md#6-sunbeam--warm-spot-seeking)
— this concept's only contribution is confirming the correct state to
watch and that no producer-side work is required here beyond it.

# Apex Speech-Triggered World Effects (P5-T1-12)

Apex is the only stage whose speech can reach back into the world — and
only when that speech is Claude-directed: `checkWorldShaping(text:)` is
gated `currentStage == .apex && request.source == .ai`
(`SpeechCoordinator.swift:211`), so autonomous Layer-1 speech (idle
thoughts, weather reactions, etc.) never triggers it, only text spoken via
`pushling_speak`. Matching utterances are scanned by
`SpeechCoordinator.checkWorldShaping(text:)` against a fixed keyword table
(`worldShapeTriggers`, pattern → effect name → probability), gated by a
**5-minute cooldown** (`worldShapeCooldownDuration`) so a single Apex
monologue can't fire the effect repeatedly:

| Trigger words (substring match) | Effect | Roll chance |
|---|---|---|
| rain, storm | rain / storm | 30% |
| sun, clear, bright | clear | 30% |
| snow, cold, winter | snow | 25% |
| night, dark, stars | night | 30% |
| dawn, morning, sunrise | dawn | 30% |
| grow, bloom, flower | bloom | 40% |
| shake, earthquake, tremble | shake | 20% |

The roll is deterministic per-utterance (`text.hashValue`-derived), not a
fresh random draw each check. On a hit, `onWorldShapeEffect` fires up to
`GameCoordinator.wireSpeechSystem()`, which maps the effect name through
`WeatherState(rawValue:)` and calls `debugForceWeather(_:)` — **only
`rain`/`storm`/`clear`/`snow` are valid `WeatherState` cases**, so the
`night`/`dawn`/`bloom`/`shake` effect names silently no-op (no matching
`WeatherState`, no reaction of any kind); the mechanism as shipped is
narrower than its own trigger table implies.

`debugForceWeather(_:)` calls `WeatherSystem.forceWeather(state,
duration: 300)` — a fixed **5-minute override**, after which
`overrideState` auto-clears (`DispatchQueue.main.asyncAfter`) and normal
weighted transitions resume. This is real code, not just a design claim,
but it's a fixed 5 minutes, not the "1-5 minutes" range
`docs/archive/plan/phase-5-speech/PHASE-5.md`'s P5-T1-12 describes. Two
further design elements from the same source have **no code at all**
(grep-verified: `Ember`/`glow`/`journal` return nothing in this path):
the trigger word briefly glowing Ember in the speech bubble when it fires
an effect, and a journal-log entry recording the moment (e.g. *"Zepus
said 'I wish it would rain' and the sky opened"*) — a hit today changes
the weather silently, with no in-bubble or in-journal trace that the
utterance caused it.

# Citations

[1] `Pushling/Sources/Pushling/World/WeatherSystem.swift`
[2] `Pushling/Sources/Pushling/World/RainRenderer.swift`
[3] `Pushling/Sources/Pushling/World/SnowRenderer.swift`
[4] `Pushling/Sources/Pushling/World/StormSystem.swift`
[5] `Pushling/Sources/Pushling/World/FogRenderer.swift`
[6] `Pushling/Sources/Pushling/Creature/CatBehaviors+Weather.swift`
[7] `docs/archive/plan/phase-3-world/PHASE-3.md` (P3-T2-04 through P3-T2-09) — original spec; crossfade duration corrected above
[8] `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` Phase 4 "Weather & Atmosphere Polish" — all listed items (teardrop rain, variable snow-flake sizes, firefly trail) have since shipped; see this concept and [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md) for confirmation
[9] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift` (`worldShapeTriggers`, `checkWorldShaping`, the `.apex && .ai` source gate at line 211)
[10] `Pushling/Sources/Pushling/App/GameCoordinator.swift` (`wireSpeechSystem` — `onWorldShapeEffect` wiring)
[11] `Pushling/Sources/Pushling/World/WorldManager.swift` (`debugForceWeather` fixed 5-minute override at line 542; `findNearestPuddle` at lines 432-438; `weatherSystem`/`terrainRecycler` ownership at lines 89, 51)
[12] `docs/archive/plan/phase-5-speech/PHASE-5.md` P5-T1-12 "Apex World-Shaping Speech"
[13] `Pushling/Sources/Pushling/World/TerrainObjectPool.swift` (`TerrainObjectType.waterPuddle` at line 19, its per-type weight/height at lines 38/54, biome placement weighting at line 124, `makeWaterPuddle()` at lines 247-254)
[14] `Pushling/Sources/Pushling/World/TerrainGenerator.swift:100` (`heightAt(worldX:)` — the only terrain-height query that exists; reused inverted for low-point puddle placement)
[15] `docs/SYSTEMS/environment-reactions.md` (§3 Weather on the Horizon, §4 Gust Front, §5 Snow Memory, §6 Puddle Days & Dabbing, §7 Golden Hour Dusk Vantage — the creature-verb consumers of every signal in "World-State Consequences" above)
[16] `docs/SYSTEMS/idle-life-and-rest.md` §6 (Sunbeam & Warm-Spot Seeking — the consumer of the sunbeam eligibility signal)
[17] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.proposals` (WORLD ALIVENESS & SPECTACLE lens: Weather on the Horizon, Gust Front, Snow Memory, Puddle Days; Feline Ethology lens: Sunbeam & Warm-Spot Seeking) — source pitches for the world-state consequence signals
