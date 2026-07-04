---
type: System
title: Emotional Body Language
description: How inner state becomes visible flesh — the valence×arousal Posture Vocabulary (a multiplicative modifier riding body-pose-pipeline's compose point), the Tail/Ear/Whisker Semaphore replacing random noise-idle with a mood grammar, one Arch render parameterized as fright cascade vs play sproing, and the Grooming Chain with displacement grooming.
status: Future
tags: [emotion, body-language, posture, semaphore, tail, ears, whiskers, arch, startle, grooming, system]
timestamp: 2026-07-03T00:00:00Z
---

Four mechanisms, one job: make the four
[emotional axes](/REFERENCE/personality-emotional-state.md#emotional-state-4-axes)
(satisfaction, curiosity, contentment, energy) and the five
[personality axes](/REFERENCE/personality-emotional-state.md#personality-5-axes)
readable in the body, not just reported through `pushling_sense`. Today only
one of the four mechanisms below has any shipped code behind it at all
(Appendage Semaphore, and even that is partial and mostly *random* rather
than *mood-driven* — see [§2](#2-appendage-semaphore--tail--ear--whisker-grammar)).
The other three depend on
[`BodyPoseController`](/SYSTEMS/body-pose-pipeline.md#1-the-bodyposecontroller--the-missing-13th-part-controller),
which does not exist yet — this whole concept is the **modifier layer**
that rides body-pose-pipeline's compose point once that pipeline ships, not
a competing controller and explicitly **not a fifth priority layer** on
[the behavior stack](/SYSTEMS/behavior-stack.md). Ownership boundary: this
concept is a **read-only consumer** of body-pose-pipeline's transform tuples
and compose formula — it multiplies into them, it does not redefine them.

# 1. Posture Vocabulary — Valence×Arousal to Body Shape

## The Collapse

`EmotionalState`'s four `[0,100]` axes collapse to two continuous `[-1,+1]`
signals, computed fresh every frame from the already-live
`EmotionalSnapshot` (no new persisted state). This concept originated the
formula, but
[personality-emotional-state.md](/REFERENCE/personality-emotional-state.md#valence--arousal-the-shared-mood-coordinate)
is its ratified owner going forward — it owns the axes the formula
collapses, so a second feature needing valence/arousal reads the formula
from there, not from here:

```
valence = clamp(((satisfaction - 50) + (contentment - 50)) / 100, -1, 1)
arousal = clamp(((energy - 50) + (curiosity - 50)) / 100, -1, 1)
```

`EmotionalVisualController` reads the four raw axes independently today
(see [§2](#current-shipped-baseline-what-emotionalvisualcontroller-already-does))
rather than through this collapse. This section owns everything
downstream of the coordinate — the Posture Vocabulary parameters and
composites below — not the collapse formula itself.

## The Five Parameters

All five apply **under** every discrete `bodyState`/tail/ear/whisker
choice as a continuous multiplicative offset — a dejected `loaf` and a
joyful `loaf` are the same base pose with different posture-vocabulary
deltas layered on top, per the dossier's explicit design intent.

| Parameter | Range | Formula (v = valence, a = arousal, both -1..+1) | Composes with |
|---|---|---|---|
| `hipHeight` | -1.5pt to +1.0pt | `v ≥ 0 ? v × 1.0 : v × 1.5` | Adds to §5 `yOffset` in [body-pose-pipeline's tuple table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table) |
| `spineCurve` | -8° to +5° (subtle, not the Arch Grammar's full hump) | `v ≥ 0 ? v × 5 : v × 8` | Adds to `zRotation`, distinct from [§3](#3-arch-grammar--one-render-two-affects)'s dramatic humped-spine render |
| `headPitch` | -20° to +15° | `clamp(v × 10 + a × 5, -20, 15)` | Adds to `headOffset` |
| `tailCarriage` | -35° (drag) to +45° (up-hook) | `v ≥ 0 ? v × 45 : v × 35` | Sets the **baseline** angle [§2](#2-appendage-semaphore--tail--ear--whisker-grammar)'s dynamic sway/twitch/wrap states oscillate around — Posture Vocabulary owns the slow-drifting mean, Semaphore owns the fast readable gesture on top of it |
| `gaitBounce` | 0pt to +2.0pt | `max(0, a) × 2.0`, then `× 0.3` if `v < -0.3` (a dejected creature doesn't bounce even if wired) | Modulates the walk-cycle amplitude owned by [locomotion & gait](/SYSTEMS/locomotion-and-gait.md) — this concept supplies the multiplier, not the gait mechanism |

## Signature Composites

The dossier names four; computed against the table above:

| Composite | v, a | hipHeight | spineCurve | headPitch | tailCarriage | gaitBounce | Extra behavior (cross-linked, not owned here) |
|---|---|---|---|---|---|---|---|
| **Dejection** | -0.8, -0.3 | -1.2pt | -6.4° | -9.5° | -28° (drag) | 0 (dejection floor) | Walk speed ×0.6, periodic stop-and-sigh — owned by [locomotion & gait](/SYSTEMS/locomotion-and-gait.md) / the idle micro-behavior scheduler ([behavior-stack](/SYSTEMS/behavior-stack.md)) |
| **Joy** | +0.7, +0.5 | +0.7pt | +3.5° | +9.5° | +31.5° (hook) | +1.0pt | Prance gait — locomotion & gait |
| **Anticipation** | +0.2, +0.6 | +0.2pt | +1.0° | +5.0° | +9° | +1.2pt | 600ms pre-pounce butt-wiggle (`xScale ±3% @ 4Hz`) — owned by the Pounce Grammar (locomotion & gait / play-bouts.md), cross-linked, not this concept's mechanism |
| **Contentment** | +0.6, -0.4 | +0.6pt | +3.0° | +4.0° | +27° | 0 (arousal negative) | Standing-melt loaf, eyes at 60% — the `loaf` bodyState tuple owned by [body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table); this concept only supplies the deltas layered on it |

## Per-Stage Amplitude

Reuses [body-pose-pipeline's `stageScaleScalar`/`stageOffsetScalar`
table](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars) directly
— Posture Vocabulary is a modifier on the same compose point, not a second
scale system — with two **emotion-specific** overrides on top of that
generic table:

| Stage | Override | Rationale |
|---|---|---|
| Egg | Posture Vocabulary outputs are zeroed entirely (not just scaled down) | No directed movement at this stage at all; matches body-pose-pipeline's Egg `zRotation` carve-out for egg-wobble |
| Sage | `arousal` term in every formula above is damped ×0.5 before use; `valence` term is untouched | "Serenity" — the dossier's stated Sage rule is arousal-display-damped-but-valence-always-shows, distinct from body-pose-pipeline's generic 0.85 Sage scalar (which applies to the *whole* tuple, not selectively to arousal) |
| Apex | All five parameters output 0 (no posture shift); emotion instead modulates `auraState`'s alpha/pulse-period, owned by [body-pose-pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption) | "Power via subtraction" — Apex routes emotion through light, not shape, per the dossier and body-pose-pipeline's existing per-stage table |

**Status: designed, not built.** Depends entirely on `BodyPoseController`
existing — there is no live `bodyState`/posture channel to modify today
([grounds](#citations), `EmotionalVisualController.swift` stops at
ears/tail/eyes/mouth/breath period, confirmed below).

# 2. Appendage Semaphore — Tail / Ear / Whisker Grammar

## Current Shipped Baseline (what `EmotionalVisualController` already does)

`EmotionalVisualController.update()` (`Creature/EmotionalVisualController.swift:31-124`)
already drives ear and tail state off five hard-threshold branches
(hangry/sad/curious/content/tired), each with a 5-point hysteresis margin —
fully catalogued in
[personality-emotional-state.md's Emotional Visual Feedback table](/REFERENCE/personality-emotional-state.md#emotional-visual-feedback-axis--body-language).
This is real, shipped, mood-driven appendage control — **not** the "noise"
this section replaces. The noise this section replaces is two separate,
genuinely random systems that run underneath those five branches and
between them:

1. `CreatureNode.updateNoiseIdle()` (`Creature/CreatureNode.swift:284-305`)
   adds a 6-channel layered-sine offset to `bodyNode`/`headNode` position
   and **both ears' and both whiskers' `zRotation`** every frame — organic,
   but mood-blind: the same formula runs regardless of `valence`/`arousal`.
2. `EarController.updateRandomTwitch()` (`Creature/EarController.swift:238-253`)
   and `WhiskerController.updateMicroTwitch()` (`Creature/WhiskerController.swift:96-119`)
   independently schedule micro-twitches on a random 2-15s (ears) / 5-20s
   (whiskers) timer, modulated only by the **personality** Energy/Focus
   axes, never by the **emotional** state.

The Semaphore's job is to make the five hard-threshold branches above
**continuous** (driven by the same `valence`/`arousal` collapse as
[§1](#the-collapse)) and to make the two random-twitch systems
**mood-conditional** (still occasionally random, but their frequency and
amplitude read off the current zone below, not off personality alone).

## Selection Table

Zones are non-overlapping in `(valence, arousal)` space; the last matching
row wins (checked top-to-bottom, hangry-equivalent first, matching
`EmotionalVisualController`'s existing hangry-first priority order).

| Zone | v range | a range | Tail state | Ear state (both) | Whisker state | Cross-fade |
|---|---|---|---|---|---|---|
| Hangry (unchanged from shipped) | v < -0.5 | a > -0.2 | `twitch_tip` | `back` | `back` | 0.5s (matches shipped `EmotionalVisualController.swift:46-48`) |
| Wary/Sad | v < -0.3 | a ≤ -0.2 | `low` | `droop` | `droop` | 0.5s (matches shipped `EmotionalVisualController.swift:65-70`) |
| Curious/Alert | -0.3 ≤ v < 0.5 | a > 0.5 | `sway_fast` | `perk` | `forward` | 0.3s |
| Joy/Playful | v ≥ 0.5 | a > 0.3 | `high` | `perk` | `forward` | 0.3s |
| Content/Wrapped | v ≥ 0.5 | a ≤ 0.3 | `wrap` | `neutral` | `neutral` | 0.8s |
| Baseline | -0.3 ≤ v < 0.5 | -0.2 ≤ a ≤ 0.5 | `sway` | `neutral` | `neutral` | 0.5s |
| Overstimulated | any v | a > 0.85 sustained > 2s | `thrash` **(new state — see below)** | `wild` | `back` | 0.2s |
| Startle spike | — | reflex-priority (Arch Grammar owns trigger) | `poof` | `flat` | `back` | 0.15s reflex cascade, not this table's cross-fade — see [§3](#3-arch-grammar--one-render-two-affects) |

`thrash` is a genuinely new `TailController`/`SegmentedTailController`
state not in either controller's current 10-state `validStates` list
(`sway, sway_fast, still, poof, low, high, wrap, twitch_tip, wag, chase`) —
wide fast arcs, distinct from `sway_fast`'s narrower amplitude. Everything
else in the table reuses states both controllers already implement.

Random micro-twitch conditioning (replacing the mood-blind timers above):
in the `Baseline` and `Content/Wrapped` zones, `EarController`/
`WhiskerController`'s existing random-interval twitch continues running
unmodified (this *is* the "organic idle" the dossier wants to keep). In
every other zone, the random twitch is suppressed — a wary or startled
creature's ears/whiskers are reading the semaphore grammar, not idling.

## Stage Gating — corrected against `ResolvedCreatureState.defaultState`

The dossier's proposal assumes a Drop tail-nub grammar and a Beast-debut
for whiskers. Neither matches the shipped gate
(`Behavior/LayerTypes.swift:166-172`):

```swift
let hasEars = stage >= .critter
let hasTail = stage >= .critter
let hasWhiskers = stage >= .critter
let hasAura = stage >= .beast
```

| Stage | What actually exists | Semaphore applies? |
|---|---|---|
| Egg | Nothing — `earLeftState`/`tailState`/`whiskerState` all resolve to `"none"` | No |
| Drop | `StageRenderer.buildDrop` (`Creature/StageRenderer.swift:144-164`) adds a static "proto-ear" pair and a single "proto-tail" hint at 0.2-0.3 alpha — **decorative, uncontrolled**: `earLeft`/`earRight` nodes are `nil` in the returned `StageNodes`, so no `EarController`/`TailController` is ever instantiated for them | No — the dossier's "tail-nub, up/down/tuck carriage" claim does not exist in code; Drop has no grammar at all, just a static hint shape |
| Critter | Full ear+tail+whisker controllers instantiate simultaneously (all three gate on the same `stage >= .critter` line) | Yes — full table above, debut moment |
| Beast | Aura joins (`hasAura`), not whiskers (whiskers already existed since Critter, contra the dossier) | Yes, plus aura tint synergy (owned by [body-pose-pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) |
| Sage | Same grammar, `arousal` term damped ×0.5 per [§1](#per-stage-amplitude)'s override — fewer sharp state changes, same states | Yes, refined |
| Apex | `additionalTailNodes` (see below) echo the primary; aura carries most of the signal | Yes, primary tail only drives the grammar |

## Apex Multi-Tail Echo — already shipped, but mood-blind

`CreatureNode.update()` (`Creature/CreatureNode.swift:242-246`) already
staggers each additional Apex tail with a phase-lagged sine sway:

```swift
for (i, tail) in additionalTailNodes.enumerated() {
    let phase = breathingTime + Double(i + 1) * 0.4
    let angle = 0.15 * CGFloat(sin(phase * 2.0 * .pi / 3.0))
    tail.zRotation = CGFloat(i + 1) * 0.26 + angle
}
```

**Shipped**, contrary to how the dossier frames the calligraphic echo as
new work — the phase-lag choreography exists today. What's genuinely
unbuilt: this loop runs unconditionally, regardless of the primary
`tailController.currentState` — an Apex creature that is `wrap`-ped or
`poof`-ed still shows its extra tails doing the same fixed independent
sway. Wiring `additionalTailNodes` to echo the *primary* tail's resolved
target (with the existing phase-lag preserved) is this concept's one
addition on top of already-shipped code.

## `SegmentedTailController` — built, wired nowhere

`SegmentedTailController` (`Creature/SegmentedTailController.swift`) is a
complete spring-damper chain controller — same 10-state `validStates` list
as `TailController`, per-segment stiffness/damping tapering base-to-tip
(`baseSpringK`/`baseDamping`, lines 83-90), full `computeTargets()`
implementations for every state. It is instantiated **nowhere** — a
project-wide grep for `SegmentedTailController(` returns zero call sites.
`CreatureNode.swift:577` wires the single-node `TailController` instead:

```swift
let tc = TailController(tailNode: tail)
```

[procedural-animation.md](/REFERENCE/procedural-animation.md) currently
(pre-this-wave) describes the segmented version as "Shipped" — that is
the false claim this dossier's canon-drift risk item names, and its
correction is this concept's job per the dossier's deepening note. The
Semaphore's `thrash`/`poof`/`chase` states are exactly where a real
spring chain would visibly out-perform the single-node sine version (whip
follow-through on a fast direction change); instantiating
`SegmentedTailController` in place of `TailController` at `CreatureNode.swift:577`
is a **swap, not new code** — every state the selection table above uses
already has a working `computeTargets()` case.

**Status: mixed.** The grammar-selection logic (the table above) is
designed, not built — it needs a driver function replacing
`EmotionalVisualController`'s five hard branches. The building blocks it
would call (`TailController`, `EarController`, `WhiskerController`, and
the dormant `SegmentedTailController`) are **already shipped**. This is
the cheapest mechanism in this concept: no new nodes, no new controller
classes required to reach the table above (only `thrash` needs a new
`computeTargets()` case added to both tail controllers) — only
`SegmentedTailController`'s instantiation swap is a code change beyond
"smarter driver logic."

# 3. Arch Grammar — One Render, Two Affects

## Existing Trigger Infrastructure (already shipped)

Two named reflexes already exist in `Behavior/ReflexLayer.swift` and are
exactly the fear-cascade's first two beats:

| Reflex | Duration | `LayerOutput` | Line |
|---|---|---|---|
| `startle` | 0.5s | `bodyState="jump"`, `earLeftState`/`earRightState="back"`, `eyeLeftState`/`eyeRightState="wide"`, `tailState="poof"` | `ReflexLayer.swift:111-125` |
| `flinch` | 1.5s | `bodyState="crouch"`, ears `"flat"`, eyes `"wide"` | `ReflexLayer.swift:80-93` |

Neither is triggered anywhere in the codebase today by name (`grep` for
`triggerReflex(named: "startle")` / `"flinch"` returns zero call sites —
only `"ear_perk"` and `"look_at_touch"` are actually invoked, both from
`CreatureTouchHandler.swift`). The generic trigger path both reflexes
would use already works and is exercised today by a different caller:
`SurpriseAnimationPlayer.advanceKeyframes()` (`Surprise/SurpriseAnimationPlayer.swift:114-138`)
builds an ad-hoc `ReflexDefinition` from any surprise keyframe's own
`output` and calls `onInjectReflex`, which `GameCoordinator.wireSurprises()`
(`App/GameCoordinator.swift:592-594`) forwards straight to
`BehaviorStack.triggerReflex(_:at:)` — so any surprise can already set
`bodyState`/`tailState`/`earState` via the reflex layer. The Startle Grammar
needs no new IPC or new plumbing, only (a) something calling
`triggerReflex(named: "startle")` for sudden loud events, thunder, and
gravity-flip (currently nothing does), and (b) the render mechanism below,
which needs `BodyPoseController` to exist at all (see [§1](#the-collapse)'s
status note — `bodyState="jump"`/`"crouch"` are already produced by these
reflexes and already silently dropped, same root cause as everywhere else
in this dossier).

## The Shared Arch Render

One parameterized render, driven by an `affect: puffed | playful` flag,
composing on top of body-pose-pipeline's `arch` tuple
(`yScale 1.18, xScale 0.83, yOffset +0.35, headOffset -0.3` per
[the tuple table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)):

| Phase | Puffed (fright — Startle → Halloween Arch → Recovery) | Playful (Side-Arch Sproing) |
|---|---|---|
| Trigger | `ReflexLayer.startle`/`flinch`, sudden loud hook event, thunder, gravity-flip surprise | Energy > 0.7 AND Contentment > 0.6 (personality/emotional, not this concept's valence/arousal — matches the dossier's own gate) AND a toy/companion present |
| Onset (~0.1s) | `startle`'s existing 0.5s reflex fires `bodyState="jump"` (brief launch-crouch dip, [body-pose-pipeline's `jump` dynamic tuple](/SYSTEMS/body-pose-pipeline.md#dynamic-states-animated-around-a-baseline-not-a-fixed-pose)) | No fear-crouch — starts directly into the humped launch |
| Hump (~0.6s puffed / ~continuous playful) | Silhouette narrows (`xScale` toward 0.83), midline `positionY +2-3pt`, `+8%` outline inflation (**designed, not built** — no outline-scale mechanism exists anywhere in the renderer today), sprite-stack fright-spread repurposing `SpriteStackRenderer.breathSpreadFactor = 12.0` (`Creature/SpriteStackRenderer.swift:27`, currently breath-only), tail `poof` (already-shipped `TailController` 1.5× scale, `TailController.swift:69-72`), facing snaps broadside | Same broadside hump, but loose/bouncy easing (overshoot, not rigid), positionY hop 2-4pt with 3-5pt sideways skitter, repeated 2-3× as a crab-hop — the sideways-hop-repeat has no shipped analog; needs the `isAirborne` positionY wire from [body-pose-pipeline §4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension) same as any jump |
| Ears/eyes | `flat`/`wide` (shipped reflex output, unchanged) | `perk`/wide-dilated (opposite ear state — playful, not defensive) |
| Freeze / hold (0.3-0.5s puffed only) | Dead still except tail-tip flick — no playful equivalent; play launches straight into zoomies/pounce | — |
| Recovery | Un-arch, creep forward low, whiskers-forward sniff, then [§4](#4-grooming-chain-with-displacement-grooming)'s displacement groom | Hands off to zoomies (already-shipped `walkSpeed × 1.5`, `BehaviorChoreography`'s `zoomies` case) or a pounce |

Both affects share every rendering primitive (spine-hump shear, sprite-stack
spread repurposing, tail-poof reuse) — the fork is entirely in easing
curve, ear/eye state, and what follows, not in a second render path. This
is the single build the dossier's risk list flags: build the arch render
once, parameterize it twice.

## Boldness Scaling

The dossier calls for "boldness (derived from personality Energy/Focus)"
scaling the whole cascade from an ear-flick to a full launch. That
derivation is **not this concept's to define** —
[personality-emotional-state.md](/REFERENCE/personality-emotional-state.md)'s
Phase-2 deepening (concurrent with this wave, per the dossier's deepening
list) owns the boldness formula as a first-class derived stat alongside
bond-tier. This concept consumes a `boldness: Double` input wherever it
appears and scales cascade amplitude/duration by it; it does not compute
it.

## Stage Gating

| Stage | Puffed (fright) | Playful (sproing) |
|---|---|---|
| Egg | Hard wobble-recoil only (reuses the existing egg-wobble `zRotation` formula, `CreatureNode.swift:199-203`, at higher amplitude) | N/A — no directed movement |
| Drop | Squash-flinch + rebound (existing hop mechanics, no arch) | Extra-bouncy double-hop, riding the existing `dropHopOffset`/`dropHopSquash` formula (`CreatureNode.swift:207-211`) at 2× amplitude |
| Critter | Arch debuts, modest puff | Single sproing then zoomies handoff |
| Beast | Full dramatic broadside arch, biggest puff — capped within the 30pt canvas per [body-pose-pipeline's headroom table](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension) (Beast jump-apex cap 6pt) | Full 2-3 hop crab-skitter, biggest air (same 6pt cap) |
| Sage | Mostly unflappable — one ear-swivel + slow-blink, rarely a full arch (composure) | Single dignified pounce-wiggle instead of a skitter chain |
| Apex | No physical startle — `auraState` flares/contracts instead (owned by [body-pose-pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) | Brief aura motion-echo/after-image, then zoomies |

**Status: designed, not built.** The reflex/surprise trigger plumbing is
shipped and idle; the render (spine hump, outline inflation, sideways-hop
repeat) needs `BodyPoseController` and the `isAirborne` wire, neither of
which exist yet.

# 4. Grooming Chain (with Displacement Grooming)

## Existing Shipped Beat

`CatBehaviors.grooming` (`Creature/CatBehaviors.swift:233-276`) is a
single, complete grooming beat, already wired into the Autonomous layer's
`BehaviorSelector` (`minimumStage: .critter`, `cooldownSeconds: 240`,
`weight: 0.5`): front-left paw lifts (`pawFLController.setState("lift")`),
mouth switches to `"lick"` after a 0.5s delay, and — the one whole-body
motion in this behavior that actually survives `updateWorld`'s clobber
because it's a `zRotation`-only `SKAction` on the root node — a head tilt
of `±0.1 rad` over the behavior's 3-5s duration
(`CatBehaviors.swift:256-263`). This is the isolated instance the
Grooming Chain extends into an ordered, multi-beat sequence.

## The Chain

Each beat's posture cross-links [body-pose-pipeline's tuple
table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
where a matching `bodyState` already exists; where none does, the gap is
named explicitly.

| Beat | Duration | Posture | Paw / mouth | Notes |
|---|---|---|---|---|
| 1. Paw-lick | 1.0-1.5s | `bodyState="sit"` (already-tabulated tuple: `yScale 0.90, yOffset -0.3, headOffset +0.3`) | `pawFLController.setState("lift")` (shipped state), `mouthController.setState("lick")` (shipped state), small 0.3pt lick-nod on `headNode` | Reuses today's single-beat exactly, just re-scoped as beat 1 of a chain |
| 2. Face-wipe | 1.0-2.0s | Same `sit` base, `+0.1rad` head/paw co-rotation (already-shipped mechanic, `CatBehaviors.swift:256-263`) repeated 2-3× | Paw stays raised, alternates 2-3 circular passes | The existing single head-tilt action becomes a *repeated* pass count here |
| 3. Chest | 0.8-1.5s | Head bows toward chest — new `headOffset` excursion beyond the `sit` tuple's `+0.3`, needs its own small negative delta (**designed, not built**, no existing tuple covers a chest-bow) | Small nodding licks, mouth `"lick"` held | |
| 4. Flank (comedy beat) | 1.0-2.0s | One hind leg lifts up-and-out, body tips — **the strongest reason to finally pass `legHeight > 0`** (see below) | Rear paw controller to a `"raise"` state (does **not** exist in `PawController`'s current `validStates` — nearest existing state is `"lift"`, which lifts the *front* paw toward the mouth, not a hind leg outward; a distinct `"raise"` case is new work) | Fallback if legs stay unrendered: body-tip + raised rear paw-bean via the existing `"lift"` state, no new leg geometry |

Between beats, `tailController.setState("wrap")` (already-shipped state,
content self-soothe per [§2](#selection-table)'s `Content/Wrapped` zone).

## The Leg-Render Gap

`ShapeFactory.makePaw` (`Creature/ShapeFactory.swift:279-306`) has a
complete `catLeg` code path gated on `legHeight > 0` — but `StageRenderer`
never calls it with a nonzero `legHeight` anywhere (`grep -n legHeight
StageRenderer.swift` returns nothing). This makes `PawController`'s own
`"_leg"` child-node lookup (`PawController.swift:178-180`,
`node.childNode(withName: "\(node.name ?? "")_leg")`) permanently dead —
the named child never exists, so the `if let leg = ...` guard silently
no-ops every frame. The Flank beat is this dossier's strongest argument
for finally passing `legHeight` at Beast+ — a hind-leg-up pose is the one
grooming beat that reads as broken pantomime without a real leg, whereas
every other beat above already works with paw-bean-only rendering.

## Displacement Grooming

Same chain, entered via a hard cut straight into beat 2 (face-wipe) with
"over-casual" energy, no beats 1/3/4:

| Trigger | Source | Status |
|---|---|---|
| Missed pounce | Pounce Grammar's whiff outcome | **Not yet available** — `ObjectInteractionEngine.swift:355` sets `bodyState="pounce"` on success but tracks no miss/whiff outcome today; this trigger is a forward dependency on the Pounce Grammar (locomotion & gait / play-bouts.md), not fabricated here |
| Post-startle | End of [§3](#3-arch-grammar--one-render-two-affects)'s Recovery phase | Ready the moment §3 ships — Recovery already hands off here in the phase table above |
| Post-pet re-settle | `Input/PettingStroke.swift` | Cross-link only — the re-settle trigger itself belongs to [companionship-rituals.md](/SYSTEMS/companionship-rituals.md), not duplicated here |
| Post-commit-meal | `Creature/CommitEatingAnimation.swift` | Cross-link only — trigger owned by [commit-feeding-xp.md](/SYSTEMS/commit-feeding-xp.md) |
| High-contentment idle | `valence ≥ 0.5` sustained, no displacement framing — this is the ordinary full chain, not the hard-cut variant | Uses `EmotionalState.contentment` directly, no new signal |

## Discipline Modulation

Personality's Discipline axis (`0.0` chaotic .. `1.0` methodical, per
[personality-emotional-state.md](/REFERENCE/personality-emotional-state.md#personality-5-axes))
sets chain thoroughness:

```
beatCount = round(1 + discipline × 3)   // 1 beat (chaotic) .. 4 beats (fastidious); the 5th "flank" beat requires discipline > 0.8 specifically, not just beatCount
```

A chaotic creature (`discipline ≈ 0`) runs only beat 1 (a cursory lick); a
fastidious one (`discipline ≈ 1`) runs the full four-to-five-beat chain.

## Stage Gating

| Stage | Chain |
|---|---|
| Egg | N/A |
| Drop | Simple face-nuzzle rub only, no chain |
| Critter | Beats 1-2 (paw-lick, face-wipe) |
| Beast | Full chain including the flank comedy beat |
| Sage | Brief and dignified — a few deliberate face passes, no flank beat regardless of Discipline (refinement overrides thoroughness) |
| Apex | Single serene face-wipe; the grooming paw can "levitate" via aura rather than a literal paw-lift (owned by body-pose-pipeline's `auraState`, cross-linked not duplicated) |

**Status: designed, not built** for the chain, displacement framing, and
flank beat. Beats 1-2's individual mechanics (paw-lift, mouth-lick,
head-tilt) are **already shipped** today as the single isolated
`CatBehaviors.grooming` behavior — this concept's job is sequencing them
into an ordered, triggerable, Discipline-scaled chain, not inventing new
per-beat primitives for the first two beats.

# What This Concept Does Not Cover

- **The `bodyState` transform tuples themselves** (`sit`, `loaf`, `arch`,
  `crouch`, etc.) and the single compose point they run through — owned by
  [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md); this concept only
  supplies multiplicative deltas and choreography sequencing on top.
- **Walk-cycle mechanics, weight, and momentum** that `gaitBounce` and
  the Grooming Chain's stage-scaled thoroughness ride on top of — owned by
  [locomotion & gait](/SYSTEMS/locomotion-and-gait.md).
- **Boldness derivation** — owned by
  [personality-emotional-state.md](/REFERENCE/personality-emotional-state.md)'s
  Phase-2 deepening.
- **The Pounce Grammar's whiff/miss outcome** that would feed displacement
  grooming — not yet designed anywhere; flagged as a forward dependency,
  not invented here.
- **Post-pet re-settle and post-commit-meal trigger mechanics** — owned by
  [companionship-rituals.md](/SYSTEMS/companionship-rituals.md) and
  [commit-feeding-xp.md](/SYSTEMS/commit-feeding-xp.md) respectively.

# Citations

[1] `Pushling/Sources/Pushling/Creature/EmotionalVisualController.swift` (full file — shipped ear/tail/eye/mouth/breath-period mapping, hysteresis, hangry-priority order)
[2] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`update:193-276`, `updateNoiseIdle:284-305`, egg-wobble `:199-203`, drop-hop `:207-211`, Apex multi-tail echo `:242-246`, `tc = TailController(...)` at `:577`)
[3] `Pushling/Sources/Pushling/Creature/EarController.swift` (`updateRandomTwitch:238-253`, `scheduleRandomTwitch:255-261`)
[4] `Pushling/Sources/Pushling/Creature/WhiskerController.swift` (`updateMicroTwitch:96-119`, `scheduleNextMicroTwitch:130-138`)
[5] `Pushling/Sources/Pushling/Creature/TailController.swift` (10-state `validStates`, `"poof"` scale-1.5 at `:69-72`)
[6] `Pushling/Sources/Pushling/Creature/SegmentedTailController.swift` (full file — complete, zero instantiation sites project-wide)
[7] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`ResolvedCreatureState.defaultState:166-193` — stage gates for ears/tail/whiskers/aura/paws)
[8] `Pushling/Sources/Pushling/Creature/StageRenderer.swift` (`buildDrop:122-176` — proto-ear/proto-tail decorative, uncontrolled)
[9] `Pushling/Sources/Pushling/Behavior/ReflexLayer.swift` (`startle:111-125`, `flinch:80-93`, `trigger(named:):187-195`)
[10] `Pushling/Sources/Pushling/Surprise/SurpriseAnimationPlayer.swift` (`advanceKeyframes:114-138` — generic reflex injection from arbitrary surprise `LayerOutput`)
[11] `Pushling/Sources/Pushling/App/GameCoordinator.swift` (`wireSurprises:587-604` — `onInjectReflex` → `triggerReflex`)
[12] `Pushling/Sources/Pushling/Creature/SpriteStackRenderer.swift` (`breathSpreadFactor = 12.0` at `:27`, `update(breathScale:):164-181`)
[13] `Pushling/Sources/Pushling/Creature/CatBehaviors.swift` (`grooming:233-276` — shipped single-beat groom)
[14] `Pushling/Sources/Pushling/Creature/ShapeFactory.swift` (`makePaw` `catLeg` path, `legHeight` param `:279-306`)
[15] `Pushling/Sources/Pushling/Creature/PawController.swift` (`"_leg"` dead lookup `:178-180`, `validStates`)
[16] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift` (`bodyState="pounce"` `:355`, no miss/whiff tracking found)
[17] `docs/SYSTEMS/body-pose-pipeline.md` (compose point, tuple table, per-stage scalars, `auraState` — this concept's host mechanism)
[18] `docs/REFERENCE/personality-emotional-state.md` (4 emotional axes, 5 personality axes, existing Emotional Visual Feedback table)
[19] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.proposals[4]` (Posture Vocabulary), `.proposals[1]` (Semaphore, Startle→Arch→Recovery, Side-Arch Sproing, Grooming Chain), `.grounds[0]`, `.grounds[1]`
[20] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (lines 170-171, 183, 209 — concept spec, procedural-animation.md correction note, Boing! Startle Toys appendix note)
