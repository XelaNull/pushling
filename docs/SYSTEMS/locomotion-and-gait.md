---
type: System
title: Locomotion & Gait
description: How the creature moves through the world — the Personality & Stage Gait Engine (with the Childhood Echo), the Weight & Momentum Model, the Head-Leads-Turn Cascade, and Terrain Footing & Hop-Overs. Horizontal travel already works; the torso-coupled gait, per-stage momentum, and turn choreography that would read as a walking body, not a sliding prop, are designed, not built.
status: Live
tags: [locomotion, gait, momentum, turning, terrain, movement, system]
timestamp: 2026-07-03T00:00:00Z
---

This concept owns everything about *how* the creature's body travels
across the Touch Bar: stride cadence, the body-bob/lean/counterbalance that
would couple the torso to a footstep, per-stage momentum (acceleration,
skids, arrival settle), the choreography of turning around, and
terrain-aware footing (hop-overs, detours, stumbles). It does **not** own
the render mechanism that would let any of this reach the screen — that
compose point, the `bodyState` tuple table, and `positionY`/airborne
handling are [the body pose & compose pipeline](/SYSTEMS/body-pose-pipeline.md)'s;
every torso-coupling number below is designed against that pipeline's
existing compose contract, not a second one. It also does not own the
**pounce launch** or predator grammar — see
[hunt & pounce](/SYSTEMS/hunt-and-pounce.md) — though it owns the **landing
choreography and general jump-arc travel** (anticipation dip, compression,
dust, settle) for any airborne moment, pounce-originated or not. Per-stage
motion numbers here roll up into
[growth stages](/REFERENCE/growth-stages.md)'s cross-system stage-identity
table; this document is the authority for the underlying mechanics,
growth-stages is the authority for the stage-identity summary.

# What Ships Today (code-verified ground truth)

Horizontal locomotion is real, not a design fiction — the "it just stands
there" complaint is a **rendering** problem, not a movement problem:

- **Autonomous wandering** picks a destination and walks to it at
  `stage.baseWalkSpeed` (`Behavior/LayerTypes.swift:45-54` — Egg 3, Drop 8,
  Critter 15, Beast 25, Sage 20, Apex 22 pt/s; **note Sage/Apex are slower
  than Beast**, not a monotonic increase — a deliberate "dignity" curve, not
  an oversight), modulated by `PersonalityFilter.modulatedWalkSpeed` and a
  per-tick jitter (`AutonomousLayer.swift:262-269`), then further scaled by
  depth (`depthSpeedMultiplier`) and slope (`slopeSpeedMultiplier`).
- **MCP-directed movement** (`goto`/`walk`/`pace`/`retreat`/`center`/
  `approach_edge`) drives the same `walkSpeed`/`positionX` channel via
  `BlendController.updatePosition` (`BlendController.swift:299-336`).
- **`CameraController`** tracks the creature every frame, so on the fixed
  1085×30pt viewport this real X-axis travel reads as background scrolling
  around a screen-centered creature, not a body walking across the strip —
  see [camera & parallax](/SYSTEMS/camera-and-parallax.md) for the deadzone
  work that would fix the read (out of this concept's scope).
- **A per-stage mass-agnostic momentum choreography already ships**, one
  level above anything this concept adds: `BlendController`'s direction
  reversal is a **4-phase, 0.433s-total state machine** — decelerate to
  zero (0.15s, ease-out) → pause 2 frames (~0.033s) → flip `currentFacing`
  → accelerate to the new target speed (0.25s, ease-in) — fully documented
  in [the blend controller](/SYSTEMS/behavior-stack.md#the-blend-controller).
  **This timing is currently identical for every stage** — Drop and Beast
  reverse direction in exactly the same 0.433s today; the Weight & Momentum
  Model below turns this one flat number into a per-stage mass class rather
  than replacing the mechanism.
- **The visual flip itself is still instant**: `CreatureNode.setFacing`
  (`CreatureNode.swift:411-414`) is a bare `xScale = abs(xScale) *
  direction.xScale` with no easing, called every frame from
  `applyBehaviorOutput` with whatever `currentFacing` the reversal state
  machine above has already resolved. So the *timing* of a turn is
  already stage-uniform and momentum-aware; the *shape* of a turn (head
  first, body knife-edge, tail overshoot) is not — that gap is the [Head-
  Leads-Turn Cascade](#3-head-leads-turn-cascade) below.
- **The walk gait has a real diagonal phase pattern, not four independent
  legs**: `CreatureNode` assigns `PawController.cyclePhaseOffset` of `0` to
  front-left/back-right and `π` to front-right/back-left
  (`CreatureNode.swift:615-633`), so `PawController.updateWalkCycle`'s
  shared sine phase genuinely pairs FL+BR against FR+BL — confirmed
  correct by [procedural animation](/REFERENCE/procedural-animation.md#cat-feel-animation-refinements-mixed-shippedunbuilt)'s
  own code-verification.
- **A shipped bug narrows that gait to a near-static offset during real
  autonomous walking, found this wave**: `AutonomousLayer.updateWalking`
  emits `output.pawStates` **every frame**, not on state change
  (`AutonomousLayer.swift:296-303`), and `applyBehaviorOutput` calls
  `pawController.setState(s, duration: 0)` unconditionally for whatever
  string is present that frame (`PushlingScene.swift:834-837`) — there is
  no "skip if state didn't change" guard anywhere in that path
  (`BodyPartController.swift:71-90`'s protocol has none, and
  `PawController.setState`, `PawController.swift:77-88`, resets
  `walkCycleTime = 0` unconditionally on every call). Since `setState`'s
  reset runs *before* that same frame's `update(deltaTime:)` call
  (`CreatureNode.swift:264-267`, inside the `updatePhysics → updateWorld →
  updateRender` order [the body pose pipeline](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)
  already establishes), `walkCycleTime` never accumulates past a single
  frame's `deltaTime` — the sine phase is pinned to a near-zero angle every
  frame instead of sweeping through a cycle. **Net effect: the "walking"
  diagonal paw pair renders as a small constant lift (roughly 0.2-0.6pt at
  typical energy/tempo, computed from `updateWalkCycle`'s own formula) and
  a small constant forward offset — not an oscillating bob** — while
  `AutonomousLayer`'s own coarser phase toggle (`AutonomousLayer.swift:298-303`)
  alternates *which* diagonal pair holds that frozen "up" pose roughly
  every half-second. This is distinct from — and narrower than — the
  MCP-`perform`-only "run" path (`CatBehaviorsExtended.swift:33-36`), which
  calls `setState("run")` **once** and lets `update()` accumulate freely
  afterward, so the sine bob does animate correctly there. **This is a real
  fix the Personality Gait Engine below must make** (drive paw phase from a
  single shared accumulator that `setState` does not reset on a same-string
  call), not a design gap to paper over with new torso motion on top of a
  broken foundation.
- **The Drop hop** (`CreatureNode.swift:207-211`) is the one whole-body
  vertical motion in the product today: `hopValue = |sin(breathingTime ×
  5.0)|`, driving `dropHopOffset = 2.0 × hopValue` (0-2pt) and
  `dropHopSquash = 0.85 + 0.15 × hopValue`, cycling every ≈0.63s
  (`π / 5.0`). It is **ambient**, not walk-linked — it runs whether or not
  Drop is moving, and is lost entirely on evolving to Critter. Formalizing
  it as Drop's actual *gait* (cadence tied to `walkSpeed` rather than a
  free-running `breathingTime` sine) is this concept's job — see
  [signature stage gaits](#per-stage-signature-gaits) below.

**Flagged cross-wave discrepancy — Egg locomotion.**
[Growth stages](/REFERENCE/growth-stages.md) states, as ratified canon,
that Egg is "Just exists. Silent, no directed movement." [The body pose
pipeline](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)
repeats this framing ("Barely poses... pre-directed-movement"). Verifying
against `AutonomousLayer` directly this wave found **no stage gate
anywhere in `updateStateMachine`/`updateIdle`/`updateWalking` that excludes
`.egg`** from transitioning into `.walking` — `GrowthStage.baseWalkSpeed`
defines `3` for Egg (`LayerTypes.swift:47`), and `updateIdle`'s fallback
(`AutonomousLayer.swift:427-429`, `if let behavior = selectedBehavior {...}
else { transitionTo(.walking) }`) fires unconditionally whenever no
behavior is selected for the current stage — which is plausible for Egg
given its minimal behavior repertoire. **This needs a decision, not a
silent pick**: either Egg's directed-movement path is reachable today (and
"no directed movement" is aspirational, not current-code canon) or there
is a gate this wave's grep missed. Flagging for Samantha/`DECISIONS.md`
rather than asserting either way. Practically, even if reachable, Egg's
`baseWalkSpeed=3` translation renders as a **slide**, not a **roll** —
`zRotation` during Egg movement is not currently coupled to `positionX` at
all; the only `zRotation` Egg gets is the ambient wobble
(`sin(breathingTime × 3.0) × 0.06 × eggHatchProgress`,
`CreatureNode.swift:200-202`), which runs regardless of movement state and
is already claimed, matching [the body pose pipeline](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)'s
note that `BodyPoseController` must not fight it. The **Egg roll** feature
below (movement-linked rotation) is Designed, not built, independent of
how the directed-movement-gate question resolves.

# 1. Personality & Stage Gait Engine

**Designed, not built.** Couples the torso to locomotion for the first
time — today a footstep changes nothing above the paws. Reads the existing
`walkSpeed` channel (already flowing from wander, zoomies, and every MCP
movement verb) and, per frame, drives four things through [the body pose
pipeline's compose point](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula):
a body-yScale bob, a counterphase head bob (`headOffset`, additive per the
pipeline's delta-offset pattern), a forward lean (`bodyNode.zRotation`, at
Critter+ where the pipeline's per-stage `zRotation` gate is not claimed by
egg-wobble), and a tail-counterbalance target fed into `TailController` in
phase with the gait.

**Cadence is a new, decoupled clock — not `PawController`'s current one.**
`PawController.updateWalkCycle` derives its cadence purely from
`PersonalityFilter.animationTempo` (`0.7 + energy × 0.7`,
`PersonalityFilter.swift:173-177`), with **no term for actual `walkSpeed`
magnitude at all** — a creature ambling at 3pt/s and one sprinting at
50pt/s would clock the identical stride rate today (setting aside the
reset bug above, which currently masks this). The gait engine replaces
that decoupling with:

```
cadenceHz = walkSpeed / (0.4 × stageBodyWidth)
```

using the per-stage widths already in
[the body pose pipeline's own citations](/SYSTEMS/body-pose-pipeline.md)
(Egg 9pt, Drop 10pt, Critter 14pt, Beast 18pt, Sage 22pt, Apex 25pt, per
[grounds[1]](#citations)). At Critter's `baseWalkSpeed=15` this yields
≈2.68Hz (≈0.37s/stride) — close to `PawController`'s current fixed 0.6s
half-cycle constant, so the change is a *generalization*, not a jarring
retune. `PawController.updateWalkCycle`'s phase source must be swapped
from the free-running tempo-only sine to this shared gait-phase clock so
paws and torso agree — and the clock accumulator must **not** live inside
`setState` (the exact bug identified above) or the reset problem recurs
one layer up.

## Per-Stride Body Coupling (Critter baseline, before stage/personality scalars)

| Component | Formula / value | Notes |
|---|---|---|
| Body `yScale` | 1.00 → 1.04 → 1.00, in phase with paw lift | Additional multiplicative term at [the compose point](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula), stacking with breath/pose/velocity-stretch. |
| Body vertical bob | 0.4pt | Sub-pixel range the Bezier renderer already sells well ([grounds[1]](#citations)'s "vector advantage" note). |
| Head bob | 0.3pt, counterphase to body | Rides `headOffset`'s existing delta-add pattern — composes with noise-idle rather than fighting it. |
| Forward lean | 2° at walk, 6-8° at sprint | `bodyNode.zRotation`; requires [sprite-stack `zRotation` propagation](/SYSTEMS/body-pose-pipeline.md#7-sprite-stack-propagation) to ship in the same WO or Critter+'s 3-7 depth layers shear against the leaning front silhouette. |
| Lean-paired stretch | `xScale` 1.1 at sprint | Composes with [the velocity squash-stretch pass](/SYSTEMS/body-pose-pipeline.md#5-global-velocity-squash--stretch-pass) rather than a second stretch formula. |
| Tail counterbalance | Swing opposite the leading diagonal pair, gait-phase-locked | Feeds `TailController` a phase-locked target angle the same way `sway`'s target-angle generator already works, per [procedural animation's tail section](/REFERENCE/procedural-animation.md#tail--force-based-spring-damper-shipped) — a *new* target-angle case (`gait_counterbalance`), not new tail physics. |
| Idle-noise suppression | Noise-idle gain × 0.3 while `cadenceHz > 0` | Fulfills [procedural animation](/REFERENCE/procedural-animation.md#cat-feel-animation-refinements-mixed-shippedunbuilt)'s listed-unbuilt "noise reduction while walking" — prevents the ambient micro-jitter from fighting the new authored bob. |

## Personality Modulation

| Axis | Effect | Range |
|---|---|---|
| Energy | Bob amplitude scalar | 0.7× (low) to 1.5× (high) |
| Energy (high) | Adds a brief hang at bob apex | +0.05s dwell at peak `yScale` |
| Energy (low) | Dragging bob, reduced cadence | 0.7× `cadenceHz`, head carried low (`headOffset` biased -0.2pt) |
| Discipline | Stride timing regularity | Metronomic (0% jitter) at max discipline to ±12% per-stride jitter at min |
| Focus | Head lock vs. wander | High focus: head bob suppressed toward the focal target; low focus: head bob free-running |

## Distinct Gaits (stage-gated)

| Gait | Speed band | Stage gate | Character |
|---|---|---|---|
| Saunter | <10pt/s | Critter+ | Loose, minimal lean |
| Walk | Baseline | Critter+ | The per-stride table above |
| Trot | 2-beat | Critter+ | Faster cadence, reduced bob amplitude, tighter phase offset |
| Stalk | — | All (via hunt grammar) | Owned by [hunt & pounce](/SYSTEMS/hunt-and-pounce.md); this engine supplies the underlying cadence clock only |
| Sprint | Max speed | Beast+ | 6-8° lean, `xScale` 1.1 stretch, needs [the widened zoomies deadzone](/SYSTEMS/camera-and-parallax.md) to read as travel rather than scenery blur |

## Per-Stage Signature Gaits

This is where the [growth-stages](/REFERENCE/growth-stages.md) one-
feature-per-stage rhythm applies to locomotion itself. Numbers are
Designed, not built, except where marked otherwise:

| Stage | Gait identity | Key numbers |
|---|---|---|
| **Egg** | Roll (contingent — see the flagged discrepancy above) | 3pt/s translation via a wobble-pause-wobble rhythm; movement-linked `zRotation` does not exist today and would need to share the egg-wobble channel, not duplicate it. |
| **Drop** | Hop-scurry (promotion of an already-shipped ambient effect) | Cadence retuned from free-running `breathingTime × 5.0` to `walkSpeed`-derived (baseWalkSpeed=8), each hop covering ≈3-4pt of X; **shipped today**: the 2pt/0.63s hop amplitude/cadence itself (`CreatureNode.swift:207-211`) — **unbuilt**: coupling it to actual travel distance instead of a free-running clock. Bob amplitude scalar 0.5×, offset scalar 0.6× per [the pipeline's Drop row](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars) ("Drop-scale deformation halves or it reads as goo"). |
| **Critter** | 4-beat walk, 2-beat trot | Baseline table above, scalars 1.0×/1.0×. |
| **Beast** | Sprint + skid | 50pt/s max (`baseRunSpeed`), 8° lean, landing dust on skid-stop (see [Weight & Momentum](#2-weight--momentum-model)). Scalars 1.15×/1.10×. |
| **Sage** | Glide-walk | Bob amplitude ×0.4, head held level regardless of paw motion ("dignity through stillness of the head"); occasional 1pt levitation-drift (3-6s, aura +15% per [the pipeline's `auraState` table](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)). Scalars 0.85×/0.85×. |
| **Apex** | Drift / teleport-blink | 0.5-1pt airborne drift with aura ripple; distances >300pt trigger a teleport-blink (150ms alpha fade to literal OLED void — [grounds[1]](#citations)'s "the creature IS the light source" rule makes a void-faded creature genuinely invisible — reappear with a 1-frame Gilt shimmer). Camera easing must suspend during the blink or the parallax world visibly lurches — cross-link [camera & parallax](/SYSTEMS/camera-and-parallax.md). Scalars 0.70×/0.50×, further dominated by the pipeline's 2pt Apex headroom cap. |

## The Childhood Echo

At satisfaction/happiness above a peak-joy threshold (reusing the same
`EmotionalState` peak-happiness signal [the body pose pipeline's dynamic
states](/SYSTEMS/body-pose-pipeline.md#dynamic-states-animated-around-a-baseline-not-a-fixed-pose)
would consume for `bounce`/`spin`), a small per-walk-bout roll lets an
evolved creature briefly revert to a younger stage's gait before catching
itself:

| Stage | Echo unlock | Roll chance | Echo content | Recovery |
|---|---|---|---|---|
| Critter+ | Egg-wobble | — | Brief in-place wobble callback | Immediate |
| Beast+ | Drop-hop | 1% per walk bout, gated to peak-joy | Three 2pt Drop-hops, squashy, at the current stage's actual size (18×20pt Beast silhouette doing a Drop-scale hop) | Freeze + one sharp ear-flick "dignity check" |
| Sage+ | Kitten-trot (Critter gait) | 1% per walk bout, gated to peak-joy | Brief Critter-cadence trot | Freeze + ear-flick |

Fires **at most once per session** (matching the dossier's rarity intent
for exactly this kind of moment) and is journal-logged as a distinct
moment type — see [journal & dreams](/REFERENCE/journal-and-dreams.md).
The mechanism reuses each stage's own already-tabulated signature gait
above rather than authoring separate "echo" numbers — the Echo is a
*trigger*, not a new animation.

# 2. Weight & Momentum Model

**Designed, not built, as a per-stage extension of an already-shipped
mechanism** — not a new one. [The direction-reversal state machine
documented above](#what-ships-today-code-verified-ground-truth) already
gives the creature a momentum *shape* (decelerate → pause → flip →
accelerate); today that shape is a single flat 0.15s/0.033s/0.25s timing
for every stage. This concept turns the flat timing into per-stage **mass
classes** and adds two things the reversal machine does not cover at all:
a same-direction **arrival settle** (walking to a destination and
stopping, no facing change involved) and a **sprint skid-stop** (a hard
stop from high speed, with visible slide and dust).

## Per-Stage Mass Classes

| Stage | Reversal ramp (replaces the flat 0.15/0.25s) | Skid vocabulary | Arrival behavior |
|---|---|---|---|
| Egg | N/A (rolls, does not reverse-flip in the walking sense) | — | — |
| Drop | Near-zero ramp (featherweight) | None | Happy double-bounce on arrival |
| Critter | 200ms ramps | None | 15%-chance overshoot stumble (1-1.5pt past the mark, corrected) |
| Beast | 400ms ramps | Full: lean reverses to -6° on stop command, `xScale` 1.15, 4-6pt slide over 150ms, 2 pooled dust motes at the paws, settles with one 0.8pt bounce | Decelerate over the last 8pt, overshoot 1-1.5pt, two 0.5pt weight-shift correction steps before dwell |
| Sage | 600ms sine-eased ramps | Never skids | Long ease, no overshoot |
| Apex | Smooth drift (no discrete ramp read) | A hard MCP stop renders as a 10-frame, 20%-alpha afterimage/ghost instead of a skid | Drift decelerates continuously, no settle beat needed |

**Constraint this must respect, not fight:** [the AI-directed layer's
release timing](/SYSTEMS/behavior-stack.md#layer-3-ai-directed) holds walk
speed through 60% of its 5.0s fadeout (3s) before releasing to Autonomous.
Per-stage ramp constants above must sit comfortably inside that 3s window
— a Beast 400ms ramp does; nothing here should be tuned longer than a
couple of seconds without re-checking this ceiling.

**Implementation seam:** wrap `targetWalkSpeed` in a critically-damped
spring per stage at `BlendController.updatePosition`
(`BlendController.swift:299-306`) rather than authoring a fifth phase in
the existing 4-phase enum — the reversal state machine's phases (decel/
pause/flip/accel) stay exactly as shipped; only their *durations* become a
per-`GrowthStage` lookup instead of the current literals. Skid dust reuses
the pooled emitter [the body pose pipeline's frame-budget section](/SYSTEMS/body-pose-pipeline.md#frame-budget--feasibility)
already commits to for any airborne/impact effect — no second particle
pool.

# 3. Head-Leads-Turn Cascade

**Designed, not built, as choreography riding an existing timing
envelope** — not a new duration. [Procedural animation](/REFERENCE/procedural-animation.md#cat-feel-animation-refinements-mixed-shippedunbuilt)
already flags this correctly as unbuilt ("head turns first... unbuilt.
`CreatureNode.setFacing` is an instant `xScale` flip"). The fix is **not**
a fresh 300ms/80ms pair of durations as an early design pass proposed —
[the blend controller](/SYSTEMS/behavior-stack.md#the-blend-controller)
already ships two timing envelopes that fit this exactly, and reusing them
avoids a second, disagreeing set of turn-speed constants:

## Casual Turn — rides the existing 0.433s direction-reversal envelope

| Phase (existing) | Duration | New sub-beat this concept adds |
|---|---|---|
| Decelerating | 0-0.15s | Head/eye group commits `zRotation` 8° toward the new heading over the **first 60ms** of this phase — the body has not moved yet, telegraphing intent before any mass shifts. |
| Paused | 0.15-0.183s | This is the exact instant `currentFacing` already flips in code (`BlendController.swift:271-279`) — the body `xScale` animation (+1 → 0 → -1, knife-edging for ~2 frames) is centered here instead of being an instant snap. |
| Accelerating | 0.183-0.433s | Ears re-settle at +40ms into this phase, whiskers at +60ms, tail sweeps a wide 250ms arc and overshoots 5° before settling — all trailing follow-through, staggered exactly like [the expression-change blend's own per-part stagger](/SYSTEMS/behavior-stack.md#the-blend-controller) (ears lead, tail/aura lag) reused as the pattern for a different transition. |

High-energy personalities add a whole-body 5° overshoot-and-bounce-back on
top of the body-flip sub-beat. **No new debounce logic is needed**: the
reversal state machine already only starts a new reversal when
`targetFacing != currentFacing && reversalPhase == .none`
(`BlendController.swift:236-241`) — a mid-cascade re-trigger is
structurally impossible today, not merely rate-limited, so the dossier's
proposed 150ms debounce is redundant with an existing guarantee.

## Startle Turn — rides the existing 0.15s reflex-interrupt envelope

Reflex-priority turns (a sudden startle facing-flip) do not go through the
casual 0.433s reversal machine at all — they use [the reflex interrupt
cascade](/SYSTEMS/behavior-stack.md#the-blend-controller) already tabulated
at ears 0s / eyes+whiskers 0.05s / body+tail+mouth+aura 0.10s, each with a
further 0.05s ramp (0.15s total, not tempo-scaled). The startle-tier
cascade is the same head-leads-body-follows shape as the casual tier,
compressed into that already-shipped 0.15s budget rather than the
dossier's rough 80ms estimate, which undershoots the real reflex timing
already ratified in canon.

## Per-Stage Variants

| Stage | Variant |
|---|---|
| Drop | Simplified 2-stage flip (head tilt, then body) — puppyish, no tail/whisker sub-beats. |
| Critter+ | Full cascade as tabulated above. |
| Sage | Slow turn — the *entire* casual envelope stretches to 450ms (Sage's own [reversal-ramp mass class](#per-stage-mass-classes) already stretches accel/decel; this variant additionally slows the head-lead sub-beat proportionally), tail describing a full graceful S-curve rather than a sweep-and-overshoot. |
| Apex | Body alpha fades to 40% for 50ms mid-flip — "turns through itself," reusing the OLED-void stealth principle ([grounds[1]](#citations)) rather than a new visual language. |

# 4. Terrain Footing & Hop-Overs

**Designed, not built; explicitly blocked on a missing data field.**
[World & objects](/SYSTEMS/world-objects-system.md#preset-catalog--a-live-cross-process-mismatch)'s
20 presets carry no height metadata today — verified this wave against
both the MCP `VALID_PRESETS` list and the Swift `presets` dict, neither of
which encodes an object height. This concept's arbitration logic (hop vs.
detour) cannot ship until that field exists; flagging the dependency
rather than inventing a parallel height table here, since object presets
are that concept's authority, not this one's.

## Behavior Table

| Behavior | Trigger | Visual | Numbers |
|---|---|---|---|
| Hop-over | Object height ≤ per-stage threshold, low attraction score | 80ms anticipation dip (0.5pt) → 2pt-apex arc spanning object + 1pt margin → landing micro-squash (`yScale` 0.9, 50ms), no dust (casual, not a full jump-arc landing) | Reuses [this concept's own jump-arc/landing ownership](#what-this-concept-does-not-cover) at reduced scale, not a new arc formula |
| Detour | Object height above per-stage threshold | 3-4 sidestep paw cycles tracing a 3pt bulge around the object, head turned toward it in passing | Head-turn telegraphs (but must not itself trigger) object investigation |
| Stumble | 3% per walk bout baseline; 8% within 10s of waking | 60ms mid-stride toe-catch freeze, 1pt forward pitch (`zRotation` 5°), one rapid recovery step, 300ms pause, self-conscious ear-flick | Fulfills [procedural animation](/REFERENCE/procedural-animation.md)'s and the taught-behavior "walk-to-point stumble" intent at the engine level rather than per-caller |

## Per-Stage Thresholds

| Stage | Hop ceiling | Notes |
|---|---|---|
| Drop | Never hops | Always detours, or 20% of the time bonks softly (0.3pt recoil squash) and sits down facing the object, bewildered — a natural journal entry and "paying attention" tap window. |
| Critter | 3pt | Stumbles most often — "learning its legs." |
| Beast | 5pt | Hops without breaking stride cadence. |
| Sage | Never hops | Always detours with precise 2pt clearance — never touches anything, consistent with Sage's "power via subtraction" restraint elsewhere in this doc. |
| Apex | N/A | Drifts over everything per [its signature gait](#per-stage-signature-gaits); aura ripples in passing acknowledgment instead of a footing decision. |

**Arbitration rule (the one piece of real design logic here):** if an
object's attraction score is above the investigation threshold, it wins
and converts what would have been a hop-over into an approach — this
concept must not let a hop-over silently steal a moment the (unbuilt,
guard-wiring-gapped) object-investigation system was supposed to have.
That guard-wiring gap is [invitation-system](/SYSTEMS/invitation-system.md)'s
flagged prerequisite, not something this concept can independently fix;
Terrain Footing inherits the dependency rather than working around it.
Reads `WorldObjectRenderer`'s placed-object list via one path-scan at
walk-bout start plus a once-per-second lookahead — zero new nodes, cost is
negligible against [the 40-node object cap](/SYSTEMS/world-objects-system.md#object-capacity--placement).

# What This Concept Does Not Cover

- **The render mechanism** for any of the above (compose point, tuple
  application, `positionY`/airborne, sprite-stack propagation) — owned by
  [the body pose pipeline](/SYSTEMS/body-pose-pipeline.md), which this
  concept's every torso-coupling number is designed to ride, not duplicate.
- **The pounce launch and predator grammar** (stalk, butt-wiggle, launch,
  catch/whiff) — owned by [hunt & pounce](/SYSTEMS/hunt-and-pounce.md).
  This concept owns the landing/recovery half of any airborne moment
  (including a pounce's landing) and the general jump-arc travel
  (anticipation, compression, dust, settle); hunt & pounce owns the launch
  decision and grammar that gets a jump started.
- **Posture Vocabulary**'s emotion-driven modifiers
  (hipHeight/spineCurve/headPitch/tailCarriage/gaitBounce) — a further
  multiplicative layer riding the same compose point, owned by
  [emotional body language](/SYSTEMS/emotional-body-language.md); this
  concept's `gaitBounce`-adjacent numbers above are the base the modifier
  multiplies, not a duplicate of it.
- **Camera deadzone/parallax tuning** that would make any of this read as
  travel rather than background scroll — owned by
  [camera & parallax](/SYSTEMS/camera-and-parallax.md).
- **Object height metadata itself** — owned by
  [world & objects](/SYSTEMS/world-objects-system.md); Terrain Footing
  consumes it once it exists.

# Frame Budget & Feasibility

Every mechanism above is transform-only arithmetic riding an existing
per-frame update path (gait-phase trig on ~6 nodes, one spring-damper
integration per stage for momentum, a handful of keyframed sub-beats for
the turn cascade, one path-scan per walk-bout plus a once-per-second
lookahead for terrain footing) — no new `SKShapeNode`s, no per-frame
`CGPath` regeneration, no new particle pools beyond what [the body pose
pipeline](/SYSTEMS/body-pose-pipeline.md#frame-budget--feasibility)
already commits to. Well inside the ~5.7ms design allocation and nowhere
near the 16.6ms/60fps frame budget ([grounds[1]](#citations)).

# Citations

[1] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`GrowthStage.baseWalkSpeed`/`baseRunSpeed`, `Direction`)
[2] `Pushling/Sources/Pushling/Behavior/AutonomousLayer.swift` (`updateStateMachine`, `updateIdle`, `updateWalking`, `updateDwell`, walk-cycle phase toggle)
[3] `Pushling/Sources/Pushling/Behavior/BlendController.swift` (`DirectionReversalPhase`, `updateDirectionReversal`, `updatePosition`, `currentWalkSpeed`)
[4] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`setFacing`, `update`, egg wobble, Drop hop, `cyclePhaseOffset` assignment)
[5] `Pushling/Sources/Pushling/Creature/PawController.swift` (`updateWalkCycle`, `setState`'s unconditional `walkCycleTime` reset)
[6] `Pushling/Sources/Pushling/Creature/CatBehaviorsExtended.swift` (MCP-only `run` path, single `setState` call, `walkCycleTime` accumulates correctly)
[7] `Pushling/Sources/Pushling/Creature/PersonalityFilter.swift` (`animationTempo`, `modulatedWalkSpeed`, `applyJitter`)
[8] `Pushling/Sources/Pushling/Creature/BodyPartController.swift` (protocol — no state-change guard on `setState`)
[9] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds[0]` (body-movement findings), `.grounds[1]` (hard constraints: sizes, frame budget, palette, silhouette rules)
[10] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (locomotion-and-gait concept spec; Personality Gait Engine, Weight & Momentum Model, Head-Leads-Turn Cascade, Terrain Footing & Hop-Overs, Signature Stage Gaits, Gait Dialects & the Childhood Echo proposals)
