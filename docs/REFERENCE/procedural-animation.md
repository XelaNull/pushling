---
type: Reference
title: Procedural Animation
description: The breathing formula and layered noise-idle system that keep the creature perpetually alive, the shipped single-node tail sway vs. the built-but-uninstantiated segmented spring-damper tail, the halflife-based camera easing, and the design-era spring-damper toolkit reconciled against what actually shipped in each body-part controller — plus pointers to where Phase-2's body-pose-pipeline, locomotion-and-gait, and emotional-body-language concepts now own this doc's previously-unbuilt items.
status: Live
tags: [animation, springs, procedural, reference]
timestamp: 2026-07-03T00:00:00Z
---

This is the authority for **how the creature moves without being told to**
— the per-frame formulas driving breathing, idle micro-movement, and spring
physics. It does not own named behavior states or the priority stack that
decides *which* animation plays when (see
[the behavior stack](/SYSTEMS/behavior-stack.md)), stage-specific body
geometry (see
[creature visual design](/REFERENCE/creature-visual-design.md)), or weather-
reaction postures (see [weather system](/SYSTEMS/weather.md)). It also no
longer owns the *build contracts* for the whole-body mechanisms it used to
list as an unbuilt wishlist — [the body pose & compose
pipeline](/SYSTEMS/body-pose-pipeline.md) now owns the compose point and
`bodyState` tuple table (jump/land, velocity squash-stretch), [locomotion &
gait](/SYSTEMS/locomotion-and-gait.md) now owns walk-linked torso coupling
(tail counterbalance, turning, walking noise suppression), and [emotional
body language](/SYSTEMS/emotional-body-language.md) now owns the
emotion-to-movement mapping and the tail-controller swap this doc flagged.
This doc stays the authority for the formulas that already run today, plus
the design-era formula reference nothing has superseded. Source:
`Creature/CreatureNode.swift`, `Creature/TailController.swift`,
`Creature/SegmentedTailController.swift`, `Creature/EarController.swift`,
`Creature/WhiskerController.swift`, `Scene/CameraController.swift`.

# The Single Compose Point Contract (Load-Bearing)

Every whole-body visual signal in the product — this doc's breathing, a
future pose, a future gait bob, a future velocity stretch — resolves
through **exactly one** function, `CreatureNode.updateBreathing()`
(`CreatureNode.swift:307-339` today), not a scatter of competing
`SKAction`s or parallel controllers. [The body pose & compose
pipeline](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula)
is the authority for this rule and for the extended version of the
function; this doc's job is the piece of the formula that already ships:

```
bodyNode.yScale = breathScale × dropHopSquash            [ships today, this doc]
                  × pose.yScale                            [designed — body-pose-pipeline §1-2]
                  × (1.0 + velocityStretch)                 [designed — body-pose-pipeline §5]
```

with [locomotion & gait](/SYSTEMS/locomotion-and-gait.md#1-personality--stage-gait-engine)
contributing a further per-stride multiplicative term at the identical
point once the Personality & Stage Gait Engine ships. Nothing below —
Noise Idle, the Stage-Specific Overlays, the Tail formulas — gets a second
compose point of its own; any future mechanism that touches `bodyNode`'s
transform extends this one function rather than adding a rival write path.
This is the direct reason `updateWorld`'s per-frame root-node reset
(documented in
[body-pose-pipeline's "Dropped Wire" section](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth))
never clobbers breathing today — `bodyNode` is a **child** of the root
node, and `updateBreathing` runs after the reset, inside `updateRender`.

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

**Correction (verified this wave): the Asleep row is dormant, not live.**
Both branches are real, keyed on `CreatureNode.isSleeping`
(`CreatureNode.swift:310-315`), but that flag is fed exclusively from
`PushlingScene.swift:820`'s `creature.setSleeping(behaviorStack?.physics.isSleeping
?? false)` — and `physics.isSleeping` has exactly one writer,
`BehaviorStack.setSleeping()` (`Behavior/BehaviorStack.swift:364-369`),
which a project-wide grep confirms has **zero call sites**. `PhysicsLayer.isSleeping`
therefore never leaves its `false` default (`Behavior/PhysicsLayer.swift:52`),
so `CreatureNode.isSleeping` is fed `false` every frame and the Asleep row
above never fires in the running app. This is wired-but-untriggered dormant
code, not fabricated design intent — the fix is one missing caller
(something needs to invoke `BehaviorStack.setSleeping(true)` when the
Autonomous layer enters its resting/sleep state), not new logic. The
identical root cause dormant-flags the Noise Idle sleep-scaling below.

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
drift. The only state scaling `updateNoiseIdle` applies is `isSleeping ?
0.1 : 1.0` (`CreatureNode.swift:286`) — **dormant, same root cause as the
Breathing section's Asleep-row correction above**: `isSleeping` is fed
`false` every frame today, so this 0.1× damp never engages in the running
app, even while the creature is visibly resting. The design research
additionally proposed a **0.3× reduction while walking**, so noise doesn't
fight the deliberate paw-lift motion of the walk cycle above — this half of
the scaling was never built; `updateNoiseIdle` has no walk-state branch.
This is no longer an open design gap this doc owns: [locomotion &
gait](/SYSTEMS/locomotion-and-gait.md#per-stride-body-coupling-critter-baseline-before-stagepersonality-scalars)
now specifies the exact number — "noise-idle gain × 0.3 while `cadenceHz >
0`" — as part of its Personality & Stage Gait Engine, still designed, not
built. The research also proposed whiskers additionally responding to
*acceleration* (a twitch on sudden movement, layered on top of their
scheduled micro-twitch) — still unbuilt and still unowned by any Phase-2
concept, per a grep of `WhiskerController.swift` for any
acceleration/velocity input.

# Blink System

Independent of noise idle: a randomized timer (`PersonalityFilter.blinkInterval`,
personality-modulated) triggers a blink, with an 8% chance of a quick
double-blink 0.25s later. A 0.3s cooldown after any expression change
prevents a blink from interrupting a just-set eye state. No blinking occurs
before Drop (Egg's eyes are invisible).

# Tail — Two Controllers, One Shipped

**Correction (verified this wave): this section previously described
`SegmentedTailController` under a "(Shipped)" heading — that was canon
drift.** A project-wide grep for `SegmentedTailController(` returns zero
instantiation sites; `CreatureNode.swift:577` wires the single-node
`TailController` instead (`let tc = TailController(tailNode: tail)`).
[Emotional body language](/SYSTEMS/emotional-body-language.md#segmentedtailcontroller--built-wired-nowhere)
independently caught the identical bug this wave — cross-linked there, not
duplicated. The corrected split:

## `TailController` — Shipped (the tail actually running)

No spring-damper physics at all — the same category of implementation as
[Ears & Whiskers](#ears--whiskers--simpler-approximations-shipped) below,
not the force-based system further down this page. Ten named states
(`sway`, `sway_fast`, `still`, `poof`, `low`, `high`, `wrap`, `twitch_tip`,
`wag`, `chase`), each either a fixed-target `SKAction.rotate`/`.scale`
transition (`.easeInEaseOut`, matching the ears/whiskers pattern) or a
continuously-updated per-frame formula:

| State | Formula | Personality-filtered? |
|---|---|---|
| `sway` | `zRotation = baseRotation + amplitude × sin(2π × swayTime / period)` | Yes — `amplitude`/`period` run through `PersonalityFilter.tailSwayAmplitude`/`tailSwayPeriod` (`PersonalityFilter.swift:131,140`) before use |
| `sway_fast` | Same formula, `amplitude × 1.5`, `period × 0.5` | Yes, same base filter first |
| `wag` | `sin(2π × swayTime / 0.3) × 0.35` | No — a fixed 0.3s-period constant, dog-like rapid wag, distinct from `sway`'s personality-tuned rhythm |
| `twitch_tip` | `baseRotation + sin(twitchTimer × 12.0) × 0.1` | No |
| `chase` | `zRotation = chaseTimer × 4.0` (continuous spin, tail-chasing behavior) | No |
| `still`, `poof`, `low`, `high`, `wrap` | One-shot `SKAction.rotate(toAngle:duration:shortestUnitArc:)` to a fixed `baseRotation` target (`poof` additionally scales the node to 1.5×) | N/A — one-shot transitions, no continuous update |

This is a real, working tail — but it is the "simpler approximation"
category this doc's Ears & Whiskers section already documents, not the
spring-damper family below.

## `SegmentedTailController` — Built, Not Wired (Force-Based Spring-Damper Reference)

This is the system the previous version of this section described as
shipped. It exists in full in source and drives a 3-4 segment chain
(segment count depends on stage) with **classic force-based spring-damper
physics** — semi-implicit Euler integration of `angularVelocity +=
(springForce − dampingForce) × dt`, where `springForce = error × stiffness`
and `dampingForce = velocity × damping`. This is **not** the
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

Each of the same ten named states is implemented as a **target-angle
generator**, not a direct animation — `computeTargets()` returns a target
world-angle per segment every frame, and the spring physics above tracks
those targets with natural follow-through lag (later segments target the
previous segment's *current* angle, not its target, which is what would
produce whip-like trailing motion `TailController`'s single-node sine
cannot). [Emotional body language's Semaphore
section](/SYSTEMS/emotional-body-language.md#segmentedtailcontroller--built-wired-nowhere)
identifies swapping this in at `CreatureNode.swift:577` as a **swap, not
new code** — every state the shipped selection table would use already has
a working `computeTargets()` case — and names `thrash`/`poof`/`chase` as
where the whip follow-through would visibly outperform the sine version.

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
| **Walk cycle** | Diagonal gait (FL+BR, then FR+BL), slight body sway, tail counter-balance | **Diagonal gait shipped** — `CreatureNode` assigns `PawController.cyclePhaseOffset` of `0` to front-left/back-right and `.pi` to front-right/back-left, so `updateWalkCycle`'s shared sine phase produces true FL+BR / FR+BL diagonal pairing. **Tail counter-balance is designed, not built** — no walk-linked tail-rotation code exists in either `TailController` or `SegmentedTailController` — now owned by [locomotion & gait's Per-Stride Body Coupling table](/SYSTEMS/locomotion-and-gait.md#per-stride-body-coupling-critter-baseline-before-stagepersonality-scalars) (a phase-locked `gait_counterbalance` target-angle case, not new tail physics). |
| **Idle breathing** | Belly expansion, ear micro-adjustments, whisker flutter | **Shipped, via a different mechanism than proposed** — the Noise Idle System above already applies continuous ear/whisker micro-rotation and body-Y noise independent of walk state, achieving the same "never perfectly still" effect without a dedicated belly-expansion or walk-specific overlay. |
| **Turning** | Head turns first (0.1s), body follows (0.2s), tail drags behind (0.3s) — "cats lead with the head" | **Unbuilt** — `CreatureNode.setFacing` is an instant `xScale` flip with no staged head/body/tail sequencing. Now owned by [locomotion & gait's Head-Leads-Turn Cascade](/SYSTEMS/locomotion-and-gait.md#3-head-leads-turn-cascade), which rides the existing 0.433s direction-reversal envelope and 0.15s reflex-interrupt cascade rather than this row's proposed fresh 300ms/80ms pair. |
| **Sitting** | Rear lowers first, front paws adjust, tail wraps to side, settle wiggle | **Unbuilt.** The shipped `loaf` behavior (`BehaviorChoreography.applyLoaf`) sets body state, paw tuck, tail wrap, and half-lidded eyes all in the same frame — no staged settle sequence. **Still unowned** — this specific staged rear-first/front-paws/tail-wrap/settle-wiggle choreography is not covered by any Phase-2 concept surveyed this wave (`sit`/`loaf` exist only as end-state tuples in [body-pose-pipeline's transform table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table), not as a multi-beat sequence into them) — flagging as an open gap rather than fabricating an owner. |
| **Jumping** | Crouch (compress) -> spring (rear extends first) -> flight (body stretches) -> land (front paws first, rear follows, bounce) | **Unbuilt as a general locomotion jump.** The closest shipped relative is the commit-eating "predator crouch" (`CommitEatingAnimation.swift`): a 15% body-Y compress, then a spring-forward stretch-and-settle — but this is a food-pounce reaction gated to the commit-eating sequence, not a general jump/land cycle, and it has no landing phase at all. The render mechanism (`positionY`, `isAirborne`, per-stage headroom caps, the `jump`/`land` `bodyState` tuples) is now specified by [body-pose-pipeline §4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension); the full anticipation-to-recovery choreography beats are explicitly *not* authored there — [locomotion & gait](/SYSTEMS/locomotion-and-gait.md#what-this-concept-does-not-cover) owns the landing choreography and general jump-arc travel for any airborne moment. |
| **Landing** | Front paws absorb, body compresses 10%, spring back, dust particles | **Unbuilt** — no landing-specific compression or dust-particle trigger exists outside the choreography DSL's generic `dust` particle option (`ChoreographyParser.swift`), which is available to `pushling_perform` scripts but not wired to any autonomous jump/land event. Same ownership split as Jumping above: the `land` tuple (`yScale 0.62`, 2-frame hold) is [body-pose-pipeline's](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table); the dust particle and full compression choreography are [locomotion & gait's](/SYSTEMS/locomotion-and-gait.md#2-weight--momentum-model) to author (its Beast skid-stop row already tabulates "2 pooled dust motes at the paws" as the nearest existing number, reusing [body-pose-pipeline's committed particle pool](/SYSTEMS/body-pose-pipeline.md#frame-budget--feasibility) rather than a second one). |
| **Grooming** | Paw rises, head tilts into paw, tongue blep, paw lowers | **Partially shipped, simpler than proposed.** `BehaviorChoreography.applyGrooming` lifts a front paw, sets `mouthState = "lick"` for the middle 50% of the behavior's duration, then returns paw and mouth to rest — the lick motion is real, but there is no head-tilt-into-paw stage and no `tongue_blep` state combined into this sequence (`tongue_blep` is its own separate, Drop-gated behavior — see `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` BUG-4). The full multi-beat sequence (paw-lick → face-wipe → chest → flank) is now owned by [emotional body language's Grooming Chain](/SYSTEMS/emotional-body-language.md#4-grooming-chain-with-displacement-grooming), which extends this exact shipped beat rather than replacing it. |
| **Sleeping** | Breathing visible, occasional ear twitch, dream-kick (rear paw twitches), tail-tip curl tightens | **Corrected this wave: not partially shipped — wired but never triggered.** The prior version of this row claimed breathing amplitude/period already differ while asleep; per [the Breathing section's correction above](#breathing--the-single-most-important-animation), `CreatureNode.isSleeping` is permanently fed `false` (`BehaviorStack.setSleeping()` has zero callers), so that branch never fires in the running app — it is dormant code, not a partial ship. Dream-kick, sleep-specific ear twitch, and tail-tip curl-tightening remain unbuilt and unowned by any Phase-2 concept — grepped `Behavior/` and `Creature/` for `dreamKick`/`dream_kick`, sleep-context ear twitch, and tail-tip curl: zero hits. |

# The Design-Era Spring-Damper Toolkit (Reference Formulas)

`docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §7-8 proposed a general-purpose animation
toolkit, preserved here as a formula reference even though — per the
reconciliation above — only the camera uses spring/exponential physics
resembling it **among what actually runs today**; the shipped tail
(`TailController`) and ears/whiskers use simpler ad-hoc sine/easing
instead. `SegmentedTailController` implements a real force-based (not
halflife-parameterized) spring-damper in this family's spirit, but per the
[Tail section's correction above](#tail--two-controllers-one-shipped) it is
not the one instantiated. These formulas remain valid guidance for any
*future* body-part controller that needs framerate-independent spring
behavior:

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
with breathing) remains unbuilt — no matching implementation exists in
`CreatureNode.swift` or any body-part controller — but is no longer an
open design question this doc owns alone: [body-pose-pipeline
§5](/SYSTEMS/body-pose-pipeline.md#5-global-velocity-squash--stretch-pass)
reuses this exact formula and is the first concept to specify *where* it
plugs into [the single compose point](#the-single-compose-point-contract-load-bearing)
— continuously, every frame, not just inside hand-authored `bounce`/`jump`
tuples, with `currentJumpVelocityY` sourced from `PhysicsLayer.JumpState.velocityY`
(already computed every frame during an active jump, presently unread
outside `PhysicsLayer` itself).

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

## Emotion-to-Movement Mapping (Unbuilt Design Intent — Superseded Direction)

**This proposal is no longer the live design for emotion-driven movement.**
[Emotional body language's Posture Vocabulary](/SYSTEMS/emotional-body-language.md#1-posture-vocabulary--valencearousal-to-body-shape)
now owns this ground with a different, more fully-specified design: a
continuous `valence`/`arousal` collapse of the four `EmotionalState` axes
driving five body-pose parameters (`hipHeight`, `spineCurve`, `headPitch`,
`tailCarriage`, `gaitBounce`) multiplicatively on top of [body-pose-pipeline's
compose point](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula) —
not this table's five discrete named-emotion states each overriding
breath/idle/speed/spring-halflife/vertical-bias independently. Both are
Designed, not built; the table below is preserved as the original
design-era proposal for historical reference, not as competing canon to
build against.

The design research's original, most granular unbuilt proposal maps four
emergent emotional states — plus a fifth blended "Content" state — to five
physical animation parameters each, intended to compose with the
breathing/noise systems above via `breathPeriodOverride` and equivalent
hooks on amplitude, speed, and spring halflife:

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
- **Do not use Verlet integration for the tail** — `SegmentedTailController`'s
  already-built (but currently uninstantiated — see the [Tail
  section](#tail--two-controllers-one-shipped) above) force-based
  spring-damper gives better hand-tunable artistic control (independent
  stiffness/damping per segment) than a Verlet chain would, if/when it
  replaces the shipped `TailController`'s simpler sine-based sway.

# Citations

[1] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`updateBreathing:307-339`, `updateNoiseIdle:284-305`, `updateBlinkSystem`, `isSleeping:14`, `setSleeping:398-399`, tail instantiation `:577`)
[2] `Pushling/Sources/Pushling/Creature/TailController.swift` (shipped single-node sway/wag/twitch/chase — the tail actually instantiated)
[3] `Pushling/Sources/Pushling/Creature/SegmentedTailController.swift` (built force-based spring-damper chain — zero instantiation sites project-wide, confirmed by grep)
[4] `Pushling/Sources/Pushling/Creature/EarController.swift`, `Creature/WhiskerController.swift`
[5] `Pushling/Sources/Pushling/Scene/CameraController.swift` (`updateYTracking`, `adaptiveYHalfLife`, pan decay)
[6] `Pushling/Sources/Pushling/Behavior/BehaviorStack.swift` (`setSleeping:364-369` — zero call sites project-wide, confirmed by grep), `Behavior/PhysicsLayer.swift` (`isSleeping:52`, default `false`), `Scene/PushlingScene.swift:820` (`creature.setSleeping(behaviorStack?.physics.isSleeping ?? false)`)
[7] `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §7 (Animation Architecture), §8 (Procedural Animation Formulas)
[8] `docs/archive/3D-RENDERING-RESEARCH.md` §14 "Cat Visual Enhancement — Animation Refinements for Cat Feel", cross-verified against `Pushling/Sources/Pushling/Creature/PawController.swift`, `CreatureNode.swift`, `Behavior/BehaviorChoreography.swift`
[9] `Pushling/Sources/Pushling/Creature/PawController.swift` (`updateWalkCycle`, diagonal-gait phase offsets)
[10] `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift` (`applyGrooming`, `applyLoaf`)
[11] `Pushling/Sources/Pushling/Creature/PersonalityFilter.swift` (`tailSwayAmplitude:131`, `tailSwayPeriod:140`)
[12] `docs/SYSTEMS/body-pose-pipeline.md` — owns the compose point, `bodyState` tuple table, `positionY`/`isAirborne`, velocity squash-stretch
[13] `docs/SYSTEMS/locomotion-and-gait.md` — owns walk-linked torso coupling, tail counterbalance, turning cascade, walking noise suppression
[14] `docs/SYSTEMS/emotional-body-language.md` — owns the emotion-to-movement mapping (Posture Vocabulary), the Appendage Semaphore, and the `SegmentedTailController` swap-in analysis
