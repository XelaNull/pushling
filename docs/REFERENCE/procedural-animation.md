---
type: Reference
title: Procedural Animation
description: The breathing formula and layered noise-idle system that keep the creature perpetually alive, the segmented-tail spring-damper physics, the halflife-based camera easing, and the design-era spring-damper toolkit reconciled against what actually shipped in each body-part controller.
status: Live
tags: [animation, springs, procedural, reference]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **how the creature moves without being told to**
— the per-frame formulas driving breathing, idle micro-movement, and spring
physics. It does not own named behavior states or the priority stack that
decides *which* animation plays when (see
[the behavior stack](/SYSTEMS/behavior-stack.md)), stage-specific body
geometry (see
[creature visual design](/REFERENCE/creature-visual-design.md)), or weather-
reaction postures (see [weather system](/SYSTEMS/weather.md)). Source:
`Creature/CreatureNode.swift`, `Creature/SegmentedTailController.swift`,
`Creature/EarController.swift`, `Creature/WhiskerController.swift`,
`Scene/CameraController.swift`.

# Breathing — The Single Most Important Animation

Applied **every frame, unconditionally, never as an `SKAction`** — a design
rule stated explicitly in the source: remove breathing and the creature
looks dead. `CreatureNode.updateBreathing` is **asymmetric**, not a plain
sine wave: inhale is the first 40% of the cycle (quadratic ease-*in*,
mapping `[0, 0.4]` of the phase to `[0, 1]` via `t²`), exhale is the
remaining 60% (quadratic ease-*out*, `[0.4, 1.0] → [1, 0]` via `1 − t²`).
This produces a quick-inhale/slow-exhale rhythm the design research
describes as "organic vs. robotic sine wave" — a real cat's breathing has
exactly this asymmetry.

| State | Amplitude (yScale peak) | Period |
|---|---|---|
| Awake | 1.0 → 1.03 | 2.5s |
| Asleep | 1.0 → 1.02 | 3.5s (deeper, slower) |

An `breathPeriodOverride` hook lets the emotional-visual system substitute a
mood-specific period (e.g. faster/shakier when anxious) without touching
this formula. Breathing composes **multiplicatively** with the Drop stage's
hop-squash (`bodyNode.yScale = breathScale × dropHopSquash`) rather than
either overriding the other.

# Stage-Specific Per-Frame Overlays

Several stages apply an additional per-frame formula on top of breathing,
all computed from the same `breathingTime` accumulator so nothing needs its
own separate clock:

- **Egg wobble**: `zRotation = sin(breathingTime × 3.0) × 0.06 ×
  eggHatchProgress` — wobble intensity ramps as the egg approaches its
  hatch threshold, reaching full amplitude only right before hatching.
- **Drop hop**: `dropHopOffset = 2.0 × |sin(breathingTime × 5.0)|` applied as
  an **absolute** Y position (not additive, to prevent drift accumulation
  over a long session), paired with a squash factor
  (`0.85 + 0.15 × hopValue`) that compresses the body at the bottom of each
  hop.
- **Apex alpha oscillation**: `bodyNode.alpha = 0.88 + 0.12 ×
  sin(breathingTime × 0.5)` — the slow "flickering between realms" described
  in [creature visual design](/REFERENCE/creature-visual-design.md).
- **Sage+ wisdom-particle orbit**: the particles container's `zRotation`
  accumulates at a flat `deltaTime × 0.5` rad/sec — a simple constant
  angular velocity, not a spring or noise term.
- **Apex wise-beard sway**: each of the 3 beard strands sways at
  `0.12 × sin((breathingTime + i×0.7) × 2π/3.5)` — a per-strand phase offset
  so the three never move in unison.

# Noise Idle System

A single layered-sine system (`updateNoiseIdle`) applies subtle,
never-synchronized micro-movement to six targets — body Y, head Y, both
ears' rotation, both whisker groups' rotation:

| Target | Frequency (Hz) | Amplitude |
|---|---|---|
| Body | 0.3 | 0.12pt |
| Head | 0.4 | 0.15pt |
| Ear L | 0.53 | 0.015 rad |
| Ear R | 0.57 | 0.015 rad |
| Whisker L | 0.83 | 0.02 rad |
| Whisker R | 0.79 | 0.02 rad |

Frequencies are deliberately irrational-ratio-like (0.53/0.57, 0.79/0.83)
so no two parts ever fall into a visible synchronized pattern, and each
target gets a random phase offset assigned once at creature construction.
Every frame the system computes new offsets, **subtracts the previous
frame's offset before adding the new one** (`offsets[i] − prevNoiseOffsets[i]`)
rather than setting an absolute value — this lets noise compose additively
on top of whatever else is moving that node (breathing, a behavior-driven
rotation) without either one clobbering the other, and without long-session
drift. Amplitude scales to **0.1× while asleep** — this is the only state
scaling `updateNoiseIdle` applies (`isSleeping ? 0.1 : 1.0`). The design
research additionally proposed a **0.3× reduction while walking**, so
noise doesn't fight the deliberate paw-lift motion of the walk cycle above
— this half of the scaling was never built; `updateNoiseIdle` has no
walk-state branch. The research also proposed whiskers additionally
responding to *acceleration* (a twitch on sudden movement, layered on top
of their scheduled micro-twitch) — also unbuilt, per a grep of
`WhiskerController.swift` for any acceleration/velocity input.

# Blink System

Independent of noise idle: a randomized timer (`PersonalityFilter.blinkInterval`,
personality-modulated) triggers a blink, with an 8% chance of a quick
double-blink 0.25s later. A 0.3s cooldown after any expression change
prevents a blink from interrupting a just-set eye state. No blinking occurs
before Drop (Egg's eyes are invisible).

# Tail — Force-Based Spring-Damper (Shipped)

`SegmentedTailController` drives a 3-4 segment chain (segment count depends
on stage) with **classic force-based spring-damper physics** — semi-implicit
Euler integration of `angularVelocity += (springForce − dampingForce) × dt`,
where `springForce = error × stiffness` and `dampingForce = velocity ×
damping`. This is a real spring-damper system, but it is **not** the
halflife-parameterized formulation from the design-era research (below) —
it uses classic tunable stiffness/damping constants instead:

- Base stiffness tapers base→tip: `70.0 − t × 30.0` (t = segment index
  fraction), so the base segment is stiffer (snappier follow) and the tip is
  looser (more lag/flow).
- Base damping likewise tapers `8.0 − t × 3.0`.
- Both scale with personality: `energyFactor = 0.7 + energy × 0.6`,
  `dampFactor = 0.8 + energy × 0.4` — a high-energy creature's tail is both
  stiffer and better-damped (snappier), a low-energy one looser and
  slower-settling.

Each of the ten named tail states (`sway`, `wag`, `chase`, `wrap`, `poof`,
etc.) is implemented as a **target-angle generator**, not a direct animation
— `computeTargets()` returns a target world-angle per segment every frame,
and the spring physics above tracks those targets with natural
follow-through lag (later segments target the previous segment's *current*
angle, not its target, which is what produces the whip-like trailing
motion). `sway`'s amplitude and period are further filtered through
`PersonalityFilter` before being turned into a target.

# Ears & Whiskers — Simpler Approximations (Shipped)

`EarController` and `WhiskerController` do **not** use spring-damper physics
at all for most of their states — named-state transitions
(`neutral`/`perk`/`flat`/`back`/`droop`) are plain `SKAction.rotate` calls
with `.easeInEaseOut` timing, and the one continuously-tracked state
(`rotate_toward`, an ear following a touch point) uses a simple exponential
lerp — `current + (goal − current) × min(deltaTime × 8.0, 1.0)` — rather
than a critical-damper formula. Random micro-twitches on both parts are
hand-authored sine/timed sequences (ears: a 0.16s two-phase oscillation on
`setState("twitch")`; whiskers: a scheduled 0.5s two-phase micro-rotation
during `neutral`, interval randomized 5-20s and personality-focus-modulated).
This is a deliberate simplicity/cost tradeoff, not an oversight — see the
reconciliation note below.

# Camera — Halflife-Based Exponential Easing (Shipped)

`CameraController`'s Y-tracking and pan-decay are the one place in the
codebase that *does* use halflife-parameterized exponential decay matching
the design research's spirit, via `pow(2.0, -deltaTime / halfLife)`:
Y-tracking adaptively shortens its half-life from **0.4s** (comfort zone,
creature vertically centered) down to **0.12s** (edge zone, creature near
the screen boundary) as the creature's screen-space position approaches the
edge — a faster, snappier chase exactly when it matters most to keep the
creature in frame. Pan-offset decay after user interaction similarly uses a
per-stage half-life (0.5s at Egg up to 2.3s at Beast+) via the identical
`pow(2, -dt/halfLife)` form. This is architecturally the same *family* of
math as the design research's `criticalSpringDamper`/`fastNegExp` functions
(both are halflife-driven exponential approaches to a target) but simpler —
a pure first-order exponential decay toward the target rather than a
second-order spring with independent velocity state.

# Cat-Feel Animation Refinements (Mixed Shipped/Unbuilt)

`docs/archive/3D-RENDERING-RESEARCH.md` §14 proposed an 8-row table of
motion refinements meant to sell "cat" through movement rather than shape.
Code-verifying each row against the current animation systems found a
genuine mix — this is not a uniformly-unbuilt wishlist:

| Animation | Design intent | Status |
|---|---|---|
| **Walk cycle** | Diagonal gait (FL+BR, then FR+BL), slight body sway, tail counter-balance | **Diagonal gait shipped** — `CreatureNode` assigns `PawController.cyclePhaseOffset` of `0` to front-left/back-right and `.pi` to front-right/back-left, so `updateWalkCycle`'s shared sine phase produces true FL+BR / FR+BL diagonal pairing. **Tail counter-balance is unbuilt** — no walk-linked tail-rotation code was found in `SegmentedTailController`. |
| **Idle breathing** | Belly expansion, ear micro-adjustments, whisker flutter | **Shipped, via a different mechanism than proposed** — the Noise Idle System above already applies continuous ear/whisker micro-rotation and body-Y noise independent of walk state, achieving the same "never perfectly still" effect without a dedicated belly-expansion or walk-specific overlay. |
| **Turning** | Head turns first (0.1s), body follows (0.2s), tail drags behind (0.3s) — "cats lead with the head" | **Unbuilt.** `CreatureNode.setFacing` is an instant `xScale` flip with no staged head/body/tail sequencing. |
| **Sitting** | Rear lowers first, front paws adjust, tail wraps to side, settle wiggle | **Unbuilt.** The shipped `loaf` behavior (`BehaviorChoreography.applyLoaf`) sets body state, paw tuck, tail wrap, and half-lidded eyes all in the same frame — no staged settle sequence. |
| **Jumping** | Crouch (compress) -> spring (rear extends first) -> flight (body stretches) -> land (front paws first, rear follows, bounce) | **Unbuilt as a general locomotion jump.** The closest shipped relative is the commit-eating "predator crouch" (`CommitEatingAnimation.swift`): a 15% body-Y compress, then a spring-forward stretch-and-settle — but this is a food-pounce reaction gated to the commit-eating sequence, not a general jump/land cycle, and it has no landing phase at all. |
| **Landing** | Front paws absorb, body compresses 10%, spring back, dust particles | **Unbuilt** — no landing-specific compression or dust-particle trigger exists outside the choreography DSL's generic `dust` particle option (`ChoreographyParser.swift`), which is available to `pushling_perform` scripts but not wired to any autonomous jump/land event. |
| **Grooming** | Paw rises, head tilts into paw, tongue blep, paw lowers | **Partially shipped, simpler than proposed.** `BehaviorChoreography.applyGrooming` lifts a front paw, sets `mouthState = "lick"` for the middle 50% of the behavior's duration, then returns paw and mouth to rest — the lick motion is real, but there is no head-tilt-into-paw stage and no `tongue_blep` state combined into this sequence (`tongue_blep` is its own separate, Drop-gated behavior — see `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` BUG-4). |
| **Sleeping** | Breathing visible, occasional ear twitch, dream-kick (rear paw twitches), tail-tip curl tightens | **Partially shipped.** Breathing amplitude/period already differ while asleep (see the table above). Dream-kick, sleep-specific ear twitch, and tail-tip curl-tightening are unbuilt — grepped `Behavior/` and `Creature/` for `dreamKick`/`dream_kick`, sleep-context ear twitch, and tail-tip curl: zero hits. |

# The Design-Era Spring-Damper Toolkit (Reference Formulas)

`docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §7-8 proposed a general-purpose animation
toolkit, preserved here as a formula reference even though — per the
reconciliation above — only the tail and camera use spring/exponential
physics resembling it; ears and whiskers use simpler ad-hoc easing instead.
These formulas remain valid guidance for any *future* body-part controller
that needs framerate-independent spring behavior:

```swift
// Critical damper — snaps to target with no overshoot, halflife-parameterized
func criticalSpringDamper(
    value: inout CGFloat, velocity: inout CGFloat,
    target: CGFloat, halflife: CGFloat, dt: CGFloat
) {
    let d = (4.0 * 0.6931) / (halflife + 1e-5)
    let y = d / 2.0
    let j0 = value - target
    let j1 = velocity + j0 * y
    let eydt = fastNegExp(y * dt)
    value = eydt * (j0 + j1 * dt) + target
    velocity = eydt * (velocity - j1 * y * dt)
}

func fastNegExp(_ x: CGFloat) -> CGFloat {
    1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
}
```

| Use case | Halflife | Character |
|---|---|---|
| Ear reflexes, startle | 0.05-0.10s | Snappy |
| Expression transitions | 0.10-0.20s | Responsive |
| Walk-to-idle blending | 0.15-0.30s | Smooth |
| Mood changes | 0.30-0.50s | Gradual |

An **under-damped** variant (adds oscillatory overshoot for bounce) uses
stiffness/damping ratio parameters directly rather than a halflife:

```swift
func underDampedSpring(
    value: inout CGFloat, velocity: inout CGFloat,
    target: CGFloat, stiffness: CGFloat, damping: CGFloat, dt: CGFloat
) {
    let f = 1.0 + 2.0 * dt * damping
    let hoo = dt * stiffness
    let hhoo = dt * hoo
    let detInv = 1.0 / (f + hhoo)
    let detX = f * value + dt * velocity + hhoo * target
    let detV = velocity + hoo * (target - value)
    value = detX * detInv
    velocity = detV * detInv
}
```

| Use case | Damping ratio | Frequency |
|---|---|---|
| Happy bounce | 0.35 | 4 Hz |
| Landing squash | 0.45 | 5 Hz |
| Startle jump | 0.5 | 6 Hz |

**Follow-through** (ears/whiskers dragging behind body motion) was proposed
as `dragTarget = -bodyVelocityX × 0.008` fed through `criticalSpringDamper`
at a 0.08s halflife. **This exact mechanism did not ship** — the closest
shipped analog is `EarController`'s `rotate_toward` exponential lerp
described above, which tracks a touch-point target rather than the body's
own velocity. **Velocity-driven squash-stretch**
(`stretch = clamp(velocityY × 0.003, -0.15, 0.15)`, composed multiplicatively
with breathing) is likewise **preserved as unbuilt design intent** — no
matching implementation was found in `CreatureNode.swift` or any body-part
controller during this wave's code verification.

Three of the six spring presets the design research proposed alongside the
under-damped table above never shipped either — critically-damped, not
under-damped, use cases:

| Use case | Damping type | Halflife | Character |
|---|---|---|---|
| Sad droop | Critical | 0.4s | Sluggish |
| Tail settle | Critical | 0.15s | Snappy |
| Head tracking | Critical | 0.1-0.2s | Responsive |

These three are unbuilt for the same reason the under-damped table's three
rows *are* built (happy bounce, landing squash, startle jump map to real
emote states) — no code path in `SegmentedTailController`, `EarController`,
or `CreatureNode` was found driving a droop/settle/tracking target through
`criticalSpringDamper` at these specific halflives.

## Emotion-to-Movement Mapping (Unbuilt Design Intent)

The design research's most granular unbuilt proposal maps four emergent
emotional states — plus a fifth blended "Content" state — to five physical
animation parameters each, intended to compose with the breathing/noise
systems above via `breathPeriodOverride` and equivalent hooks on amplitude,
speed, and spring halflife:

| Emotion state | Breath period | Idle amplitude | Speed | Spring halflife | Vertical bias |
|---|---|---|---|---|---|
| Happy (high satisfaction + content) | 2.5s | 1.2x | 1.3x | 0.08s (snappy) | +2pt (up) |
| Sad (low satisfaction) | 3.8s | 0.5x | 0.6x | 0.4s (sluggish) | -1pt (droop) |
| Anxious (low energy + low satisfaction) | 1.5s | 1.0x | Variable | 0.15s | -0.5pt + tremor |
| Content (high contentment, mid energy) | 3.0s | 0.9x | 0.8x | 0.2s | 0pt |
| Excited (high energy + curiosity) | 2.0s | 1.5x | 1.5x | 0.06s | +1pt |

No matching implementation was found in `CreatureNode.swift` or any
body-part controller during this wave's code verification —
`breathPeriodOverride` provides the *hook* an emotion-driven period
override would use, but no caller currently sets it from a table shaped
like this one. This is a **different, finer-grained mapping** than the
shipped one: [personality & emotional state](/REFERENCE/personality-emotional-state.md#emotional-visual-feedback-axis--body-language)
already documents a live, code-verified breathing override keyed to the
*personality* Energy axis (period 2.0s above 70, 3.5s below 30) — that
mapping is real and shipped today, but it is a single axis with two
thresholds, not this table's five-state, five-parameter design.

# What NOT To Do

Explicit rejections from the design research, still valid guidance:

- **Do not adopt a Spine/DragonBones skeletal-animation runtime** — overkill
  for a single creature; the existing per-part `BodyPartController` protocol
  already gives sufficient control.
- **Do not use SpriteKit's built-in `SKAction.reach()` IK** — it is
  action-based, not per-frame, and cannot compose with the spring-driven
  systems above.
- **Do not use Verlet integration for the tail** — the shipped force-based
  spring-damper gives better hand-tunable artistic control (independent
  stiffness/damping per segment) than a Verlet chain would.

# Citations

[1] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`updateBreathing`, `updateNoiseIdle`, `updateBlinkSystem`)
[2] `Pushling/Sources/Pushling/Creature/SegmentedTailController.swift`
[3] `Pushling/Sources/Pushling/Creature/EarController.swift`, `Creature/WhiskerController.swift`
[4] `Pushling/Sources/Pushling/Scene/CameraController.swift` (`updateYTracking`, `adaptiveYHalfLife`, pan decay)
[5] `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §7 (Animation Architecture), §8 (Procedural Animation Formulas)
[6] `docs/archive/3D-RENDERING-RESEARCH.md` §14 "Cat Visual Enhancement — Animation Refinements for Cat Feel", cross-verified against `Pushling/Sources/Pushling/Creature/PawController.swift`, `CreatureNode.swift`, `Behavior/BehaviorChoreography.swift`
[7] `Pushling/Sources/Pushling/Creature/PawController.swift` (`updateWalkCycle`, diagonal-gait phase offsets)
[8] `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift` (`applyGrooming`, `applyLoaf`)
