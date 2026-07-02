---
type: System
title: Weather System
description: The six-state weather machine with weighted transitions and randomized 30-60s crossfades, the rain/snow/storm/fog particle renderers and their exact budgets, and the creature's reflex-priority reactions to each weather state.
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

# Apex Speech-Triggered World Effects (P5-T1-12)

Apex is the only stage whose speech can reach back into the world: every
rendered utterance is scanned by `SpeechCoordinator.checkWorldShaping(text:)`
against a fixed keyword table (`worldShapeTriggers`, pattern → effect name →
probability), gated by a **5-minute cooldown** (`worldShapeCooldownDuration`)
so a single Apex monologue can't fire the effect repeatedly:

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
narrower than its own trigger table implies. This is the wave's own new
finding, not carried from any source doc — `PUSHLING_VISION.md` and
`docs/archive/plan/phase-5-speech/PHASE-5.md` name "Apex world-shaping speech" as a
capability without this level of mechanism detail.

# Citations

[1] `Pushling/Sources/Pushling/World/WeatherSystem.swift`
[2] `Pushling/Sources/Pushling/World/RainRenderer.swift`
[3] `Pushling/Sources/Pushling/World/SnowRenderer.swift`
[4] `Pushling/Sources/Pushling/World/StormSystem.swift`
[5] `Pushling/Sources/Pushling/World/FogRenderer.swift`
[6] `Pushling/Sources/Pushling/Creature/CatBehaviors+Weather.swift`
[7] `docs/archive/plan/phase-3-world/PHASE-3.md` (P3-T2-04 through P3-T2-09) — original spec; crossfade duration corrected above
[8] `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` Phase 4 "Weather & Atmosphere Polish" — all listed items (teardrop rain, variable snow-flake sizes, firefly trail) have since shipped; see this concept and [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md) for confirmation
[9] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift` (`worldShapeTriggers`, `checkWorldShaping`)
[10] `Pushling/Sources/Pushling/App/GameCoordinator.swift` (`wireSpeechSystem` — `onWorldShapeEffect` wiring)
[11] `docs/archive/plan/phase-5-speech/PHASE-5.md` P5-T1-12 "Apex World-Shaping Speech"
