---
type: System
title: Body Pose & Compose Pipeline
description: The keystone rendering contract for whole-body posing — the missing 13th part controller, the bodyState-to-transform-tuple table, the compose-not-clobber refactor to updateWorld/CreatureNode, positionY/airborne handling, velocity squash-stretch, sprite-stack propagation, and auraState consumption. Designed, not built.
status: Future
tags: [body, pose, compose, animation, rendering, jump, squash-stretch, keystone, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the **build contract** for the single highest-leverage gap in the
product: the 4-layer [behavior stack](/SYSTEMS/behavior-stack.md) resolves a
complete `ResolvedCreatureState` every frame — `bodyState`, `positionY`,
`walkSpeed`, `auraState` — and none of it reaches the creature's torso.
Every mechanism below is **designed, not built**; this concept exists so a
future code WO can implement it without doing design work. It is the
cross-link target for every other Phase-2 concept that touches whole-body
motion: [locomotion & gait](/SYSTEMS/locomotion-and-gait.md), [emotional
body language](/SYSTEMS/emotional-body-language.md) (Posture Vocabulary
rides this doc's compose point as a modifier layer, not a second controller),
and [procedural animation](/REFERENCE/procedural-animation.md) (owns the
breathing/noise-idle formulas this pipeline composes with, not duplicates).

# The Dropped Wire (code-verified ground truth)

Three facts, each verified directly against the shipped source during this
wave's authoring:

1. **`PushlingScene.applyBehaviorOutput`** (`Scene/PushlingScene.swift:810-833`)
   applies `positionX`, `facing`, and the ear/eye/tail/mouth/whisker/paw
   controller states from the resolved output — and **nothing else**.
   `state.bodyState`, `state.positionY`, `state.walkSpeed`, and
   `state.auraState` are read by nothing in this function; `CreatureNode`
   has 12 body-part controllers (`earLeft/RightController`,
   `eyeLeft/RightController`, `tailController`, `mouthController`,
   `whiskerLeft/RightController`, four `pawController`s) and no 13th for the
   torso.
2. **`PushlingScene.updateWorld`** (`Scene/PushlingScene.swift:297-378`)
   computes `creatureY = terrainY + config.size.height / 2`, clamps it to
   `[minY, maxY]`, and unconditionally overwrites `creature.position` and
   `creature.xScale`/`creature.yScale` (the **root** `CreatureNode`, not any
   child) from that terrain/depth calculation alone — every frame, with no
   input from `output.positionY` or any pose channel.
3. The scene's actual per-frame call order (`PushlingScene.swift`'s
   `update(_:)`, subsystem calls at lines 239/243/246) is
   **`updatePhysics` → `updateWorld` → `updateRender`**. `updatePhysics`
   calls `applyBehaviorOutput`; `updateRender` (line 392-395) calls
   `creatureNode?.update(deltaTime:)` — the function that runs breathing,
   drop-hop, and all 12 controllers, and it runs **after** `updateWorld`.
   This ordering is the reason `bodyNode.yScale = breathScale ×
   dropHopSquash` (`CreatureNode.updateBreathing`, line 334) already
   survives every frame — `bodyNode` is a **child** of the root
   `CreatureNode`, and nothing after `CreatureNode.update()` touches it.
   The clobber is real but narrower than "everything gets reset": only the
   **root** node's `position`/`xScale`/`yScale` are rewritten by
   `updateWorld`, which is exactly the node `CatBehaviors.perform`'s
   direct-`SKAction` path (`CatBehaviors.swift:155` `SKAction.scaleY(to:
   0.85, duration: 0.2)`, `CatBehaviors.swift:122-125` `moveBy`) animates.
   Because SpriteKit evaluates pending actions *after* the scene's own
   `update(_:)` returns, an action's delta from frame N is overwritten by
   `updateWorld`'s reset at the top of frame N+1 before it can ever
   accumulate into a visible pose — only `zRotation`, which `updateWorld`
   never touches, survives (`tail_chase`'s spin, grooming's head tilt).

**The fix has two separate compose points, not one** — a root-level one
(§4) for whole-creature vertical displacement (jump/float), and a
child-level one (§2, §5) for torso shape (crouch/curl/squash), because
`bodyNode` and the root `CreatureNode` are different transform spaces.

# 1. The BodyPoseController — the missing 13th part controller

A new `BodyPoseController` class, instantiated by `CreatureNode` alongside
its 12 siblings and gated the same way (`stage >= .drop`, matching the
`hasEars`/`hasTail` pattern in `ResolvedCreatureState.defaultState`). It
does **not** own a new node — it owns `bodyNode`'s pose contribution (a
child of the root `CreatureNode`, distinct from the root's own `xScale`/
`yScale`, which `updateWorld`/`CreatureNode.setFacing` already own for
depth-scale and facing) plus a small additive offset on `headNode` and an
alpha multiplier on the four paw nodes.

`applyBehaviorOutput` gets one new line, in the same style as its 12
siblings:

```swift
creature.bodyPoseController?.setState(state.bodyState, duration: 0)
```

`duration: 0` matches every other controller call in `applyBehaviorOutput`
— the string itself is already crossfade-timed **upstream**:
`BlendController.blendableProperties` (`BlendController.swift:344-354`)
already lists `bodyState` and `auraState` alongside `tailState`/`mouthState`
as blended string properties, and [the behavior stack's blend
table](/SYSTEMS/behavior-stack.md#the-blend-controller) already reserves a
**0.3s "mouth/body" sub-timing** inside the 0.8s expression-change
transition — unused today because nothing downstream reads the result.
`BodyPoseController` is the first consumer of that existing, unused
timing slot; it needs no new blend-duration constant, only a numeric
tuple-to-tuple interpolation on top of the already-timed string switch
(`PropertyBlend.currentState` is a hard cut at 50% elapsed — see
[`PropertyBlend.currentState`](/SYSTEMS/behavior-stack.md#the-blend-controller)
— so `BodyPoseController.setState` receiving a new string still needs its
own internal ease, exactly as `EarController`/`WhiskerController` already
do after their own hard-cut string switches).

**Internal blend rule:** on a new target, ease every tuple component from
the current interpolated value to the target over **0.3s** using the
already-defined `Easing.easeInOut` (`LayerTypes.swift:248`) — **except**
when the new `bodyState` arrived via a reflex-priority path (`jump` via
`ReflexLayer.startle`, `crouch` via `ReflexLayer.flinch`, `flinch` via
`HookEventProcessor`'s `tool_wince`), which should use the **0.15s reflex
interrupt** cascade timing already specified for body/tail/mouth/aura
(0.10s onset + 0.05s ramp) in [the reflex interrupt
table](/SYSTEMS/behavior-stack.md#the-blend-controller) — reusing an
existing number rather than inventing a new one. `BodyPoseController` can
detect this by checking whether the *previous* frame's per-property winner
for `bodyState` was Physics/Reflex (the same per-property-priority data
`BehaviorStack.resolveOutputs()` already computes).

# 2. The `bodyState` → Transform Tuple Table

Every literal `bodyState` string actually produced anywhere in the codebase
today — grepped across all 22 files that assign it (`BehaviorChoreography`,
`PerformActionMapping`, `AbsenceAnimations`, `DreamEngine`,
`ObjectInteractionEngine`, `ReflexLayer`, `HookEventProcessor`,
`TaughtBehaviorEngine`, `RoutineEngine`, `QuirkEngine`,
`CreatureRejection`, `ExpressionMapping`, `SurpriseRegistry`,
`SessionLifecycleReactions`, `AutonomousLayer`, `GameCoordinator+*`) — is
**21 distinct strings**, four more than any single design document lists
("alert", "flinch", "jump", "lean_forward", "pounce", "shake", "sit" are
real, shipped, currently-dropped values not previously catalogued
together). Tuple order is `(yScale, xScale, yOffset pt, zRotation rad,
headOffset pt, pawAlpha)`, all values authored **at Critter scale** —
apply the [per-stage amplitude scalar](#3-per-stage-amplitude-scalars)
before the [global 0.6-1.3 silhouette clamp](#5-global-velocity-squash--stretch-pass).
`headOffset` is a *delta* added to `headNode.position.y` using the same
"subtract-previous-then-add-new" pattern `CreatureNode.updateNoiseIdle`
already uses (line 297-304), so it composes with noise-idle instead of
fighting it. `pawAlpha` multiplies the four paw controllers' node alpha
(default 1.0) — it exists as a **defense-in-depth** signal for bodyStates
whose originating layer output does *not* also set `pawStates` (e.g.
`DreamEngine`'s `sleep_curl` sets no paw states at all today — without this,
four fully-visible "ground" paws would float outside a curled silhouette).

## Static postures (hold a shape)

| bodyState | yScale | xScale | yOffset | zRotation | headOffset | pawAlpha | path-swap |
|---|---|---|---|---|---|---|---|
| `stand` | 1.00 | 1.00 | 0.0 | 0.0 | 0.0 | 1.0 | no |
| `sit` | 0.90 | 1.00 | -0.3 | 0.0 | +0.3 | 1.0 | no |
| `crouch` | 0.72 | 1.12 | -0.6 | 0.0 | -0.2 | 1.0 | no |
| `lean_forward` | 0.95 | 1.05 | 0.0 | 0.0 | +0.5 | 1.0 | no |
| `loaf` | 0.82 | 1.10 | -0.35 | 0.0 | -0.15 | 0.3 | no |
| `curl` | 0.60 | 1.15 | -0.8 | 0.0 | -0.45 | 0.35 | **yes** |
| `sleep_curl` | 0.60 | 1.15 | -0.8 | 0.0 | -0.45 | 0.20 | **yes** |
| `roll_side` | 0.65 | 1.30 | -0.5 | 1.40 | 0.0 | 0.55 | **yes** |
| `stretch` | 1.22 | 0.82 | +0.3 | 0.0 | +0.6 | 1.0 | no |
| `arch` | 1.18 | 0.83 | +0.35 | 0.0 | -0.3 | 1.0 | no |
| `alert` | 1.05 | 0.95 | +0.2 | 0.0 | +0.25 | 1.0 | no |
| `land` | 0.62 | 1.30 | -0.4 | 0.0 | -0.3 | 1.0 | no |

`land` is not sustained — `PhysicsLayer.JumpState.landingCompressionFrames
= 2` (`Behavior/PhysicsLayer.swift:29`) means it is only ever resolved for
2 frames before `activeJump` clears, so its internal ease is bypassed (snap
in, then the *next* state's normal 0.3s ease-out applies).

## Dynamic states (animated around a baseline, not a fixed pose)

| bodyState | Formula (baseline + oscillation) | Gate |
|---|---|---|
| `jump` | Brief launch-crouch dip: eases to `(0.85, 1.08, -0.15, 0, 0, 1.0)` and holds ~0.15s (matches `ReflexLayer.startle`'s 0.5s total duration) — the **airborne arc itself** is a root-level `positionY` concern, see §4, not this tuple. |
| `pounce` | Forward launch lean: eases to `(1.10, 0.92, +0.15, 0, +0.5, 1.0)` for the duration of `ObjectInteractionEngine`'s "pounce" phase. |
| `bounce` | Oscillates `yScale` between 0.90 and 1.15 at 2.2Hz (dance/celebrate perform actions, 3.0s duration); `xScale` follows the [squash-stretch reciprocal](#5-global-velocity-squash--stretch-pass) each instant rather than its own fixed value. |
| `spin` | `zRotation` sweeps 0→2π over the action's own duration (1.5s for the `spin` perform action, `PerformActionMapping.swift:29-33`) — `angularVelocity = 2π / duration`, not a fixed target. |
| `flip` | `zRotation` sweeps 0→2π over 1.2s (`backflip`'s duration, `PerformActionMapping.swift:79-85`), composed with a `positionY` apex — see §4's headroom-cap note on `backflip`'s literal `12.0`. |
| `float` | `yScale` eases to 0.95 (weightless read); `zRotation` drifts ±0.05rad at 0.2Hz; the actual lift is `positionY` (`transcend`'s `15.0` — see §4's headroom-cap note). |
| `glitch` | `alpha` jitters randomly between 0.3 and 1.0 at 8-15Hz; `zRotation` jitters ±0.3rad randomly. Gated Sage+ in source (`PerformActionMapping.swift:165` `guard stage >= .sage`) — inherit that gate here. |
| `shiver` | `yScale`/`xScale` jitter ±0.03 at 9Hz; `zRotation` jitters ±0.02rad. Cold-tremor read; 2.0s duration per `PerformActionMapping.swift:125-131`. |
| `shake` | `zRotation` oscillates ±0.15rad at 10Hz, decaying over the reflex's own duration (3.5s for `compact_daze`, `HookEventProcessor.swift:335`) — the torso carries a small residual version; the larger, primary visible motion is a literal head shake, which is `headNode`'s own concern, not this controller's. |
| `flinch` | Quick compress-and-recoil: eases to `(0.80, 1.10, -0.2, -0.08, 0.0, 1.0)` and back, over the reflex's 1.2s duration (`tool_wince`, `HookEventProcessor.swift:291`, distinct from `ReflexLayer.flinch` which sets `bodyState = "crouch"` instead — two different reflexes share the English word "flinch," only one produces the literal `"flinch"` string). |

**Unmapped strings** (`GameCoordinator+Loading.swift:724`'s
`habit.behavior`, `QuirkEngine.swift:164`'s quirk-authored `"body"` case —
both accept arbitrary data-driven text, not a fixed enum) fall back to the
`stand` tuple (identity transform) rather than crashing or freezing the
last pose — the same "unknown state = neutral" rule the rest of the stack
implicitly relies on via `ResolvedCreatureState.defaultState`.

# 3. Per-Stage Amplitude Scalars

Every tuple above is authored at Critter scale. Two independent scalars —
one for scale-type components, one for offset/rotation-type components —
apply to the **deviation from identity**, not the raw value, so `stand`'s
already-neutral tuple is untouched at every stage:

```
scaledYScale = 1.0 + (tuple.yScale - 1.0) × stageScaleScalar
scaledXScale = 1.0 + (tuple.xScale - 1.0) × stageScaleScalar
scaledOffset = tuple.offsetOrRotation × stageOffsetScalar
```

| Stage | `stageScaleScalar` | `stageOffsetScalar` | Rationale |
|---|---|---|---|
| Egg | 0.3 | 0.3 | Barely poses — pre-directed-movement per [growth stages](/REFERENCE/growth-stages.md); `zRotation` is already claimed by egg-wobble (`CreatureNode.swift:202`), so `BodyPoseController` should not fight it — gate `zRotation` output to 0 at Egg regardless of table value. |
| Drop | 0.5 | 0.6 | Explicit dossier constraint: "Drop-scale deformation halves or it reads as goo" against the 10×12pt body. |
| Critter | 1.0 | 1.0 | Baseline — table values as-authored. |
| Beast | 1.15 | 1.10 | Larger 18×20pt silhouette tolerates more deformation before losing the Solid Fill Test. |
| Sage | 0.85 | 0.85 | "Shape arc returns to roundness at Sage/Apex — power via subtraction" (grounds[1] silhouette rule); restrained rather than exaggerated. |
| Apex | 0.70 | 0.50 | Floaty/minimal reads (per Apex's alpha-oscillation, drift aesthetic); vertical offset is additionally hard-capped by the 2pt headroom rule in §4, which dominates whatever this scalar alone would produce. |

# 4. `positionY` Application + `isAirborne` Terrain-Clamp Suspension

This is a **root-level** change to `updateWorld` — `output.positionY`
represents the whole creature leaving the ground, not a torso shape change,
so it belongs in the same Y calculation as terrain height, not in
`BodyPoseController`'s child-node math above.

**Current code** (`PushlingScene.swift:330-341`):

```swift
let creatureY = terrainY + config.size.height / 2
let minY = config.size.height / 2 + 1.0
let maxY = SceneConstants.sceneHeight - config.size.height / 2 - 1.0
let clampedY = min(max(creatureY, minY), maxY)
creature.position = CGPoint(x: creatureWorldX, y: clampedY)
```

**Proposed compose-not-clobber version:**

```swift
let groundY = terrainY + config.size.height / 2
let airborneOffset = resolvedPositionY - ResolvedCreatureState.defaultState(stage: stage).positionY
let liftedY = groundY + max(0, airborneOffset)
let minY = config.size.height / 2 + 1.0
let isAirborne = airborneOffset > 0.01   // derived, no new LayerOutput field needed
let maxY = isAirborne
    ? SceneConstants.sceneHeight - 1.0            // only the true screen edge — suspend the terrain-comfort clamp
    : SceneConstants.sceneHeight - config.size.height / 2 - 1.0
let clampedY = min(max(liftedY, minY), maxY)
creature.position = CGPoint(x: creatureWorldX, y: clampedY)
```

`resolvedPositionY` must be threaded from `updatePhysics`'s
`BehaviorStackOutput` to `updateWorld` — both are already private methods
on the same `PushlingScene` instance called in the same frame
(`updatePhysics` before `updateWorld`), so a single stored property (e.g.
`lastResolvedPositionY`, set at the end of `applyBehaviorOutput`) is
sufficient; no new cross-object plumbing or IPC surface required.
`isAirborne` is **derived** by comparing against the stage's own grounded
default (`ResolvedCreatureState.defaultState(stage:).positionY`, always
`3.0` today) rather than a new explicit boolean field — every producer of a
non-default `positionY` (jump, backflip, transcend, taught `jump`) is
already, by definition, asking to leave the ground.

**Per-stage jump-apex headroom cap** (positionY is clamped to this **before**
the formula above, separate from the screen-edge clamp) — only asserting
the stages the dossier explicitly commits numbers to; the rest are an open
gap for the eventual Airborne Arc System build, not invented here:

| Stage | Apex cap | Source |
|---|---|---|
| Egg | N/A | No directed movement at this stage. |
| Drop | 2pt | Dossier: "Drop 2pt hop" — matches the *existing* perpetual Drop hop's own `2.0 × hopValue` amplitude (`CreatureNode.swift:209`), so a directed jump and the ambient hop share one visual ceiling. |
| Critter | **not yet specified** — flag for the Airborne Arc System follow-up WO. |
| Beast | 6pt | Dossier: "Beast 6pt." |
| Sage | **not yet specified** — flag for the Airborne Arc System follow-up WO. |
| Apex | 2pt (reinterpreted as a **hover-lift**, not a jump) | Dossier: "Apex reinterpreted as a 2pt hover-lift, honoring its 2pt headroom" — Apex's 25×28pt body leaves almost no room in the 30pt scene. |

This cap immediately flags three **already-shipped literal values that
exceed their own stage's real headroom** once this clamp exists:
`PerformActionMapping.swift:83`'s `backflip` sets `positionY = 12.0`
(gated `stage >= .beast`, whose cap above is 6pt — the literal value is 2x
its own cap); `PerformActionMapping.swift:176`'s `transcend` sets
`positionY = 15.0` (gated `stage >= .apex`, whose cap is 2pt — 7.5x over);
`TaughtBehaviorEngine.swift:324-325`'s taught `jump` step sets `positionY =
8.0` with no stage gate at all. **These three need either a value fix or
an explicit reinterpretation** (`transcend`'s "float" may want its own,
non-apex-height hover mechanic entirely, matching its `float` bodyState
tuple in §2) — flagging here rather than silently clamping them into
near-invisibility, since a 2pt-capped 12pt request reads as barely moving
at all, which would make `backflip` look broken rather than fixed.

# 5. Global Velocity Squash & Stretch Pass

Runs **after** the tuple lookup and stage scalar, composing multiplicatively
with everything else at the [single compose
point](#6-the-single-compose-point-full-formula) below. Reuses the
**exact formula already on record** as unbuilt design intent in
[procedural animation](/REFERENCE/procedural-animation.md#the-design-era-spring-damper-toolkit-reference-formulas):
`stretch = clamp(velocityY × 0.003, -0.15, 0.15)`. This pipeline is the
first concept to specify *where* that formula plugs in:

```
velocityStretch = clamp(currentJumpVelocityY × 0.003, -0.15, 0.15)
rawYScale = poseYScale × (1.0 + velocityStretch)
finalYScale = clamp(rawYScale, 0.6, 1.3)          // hard silhouette cap, grounds[1]
finalXScale = clamp(1.0 / sqrt(finalYScale), 0.6, 1.3)   // volume-preserving approximation
```

`currentJumpVelocityY` is `PhysicsLayer.JumpState.velocityY`
(`Behavior/PhysicsLayer.swift:18`), already computed every frame during an
active jump and presently unread outside `PhysicsLayer` itself. The
`1.0/sqrt(x)` reciprocal is the standard animation volume-preservation
approximation (as `yScale` grows, `xScale` shrinks to suggest constant
mass) — it self-limits within the caps: `finalYScale ∈ [0.6, 1.3]` maps to
`finalXScale ∈ [0.877, 1.291]`, already inside `[0.6, 1.3]`, so the second
clamp is defensive, not load-bearing. This pass is **continuous** (runs
every frame, not just during authored `bounce`/`jump` states) — it is what
makes the *ambient* squash on landing feel connected to velocity rather
than only appearing inside hand-authored tuples.

# 6. The Single Compose Point (full formula)

Everything above lands in exactly **one** place: the existing
`CreatureNode.updateBreathing()` (`CreatureNode.swift:307-339`), extended
— not a new function, so there is no ordering ambiguity with the breathing
composition already there. Runs inside `updateRender`, after `updateWorld`
has already set the root node's position/scale for this frame, so nothing
downstream can re-clobber it:

```swift
private func updateBreathing(deltaTime: TimeInterval) {
    // ... existing breathScale computation (unchanged) ...

    let pose = bodyPoseController?.currentPose ?? BodyPoseTuple.identity
    let velocityStretch = clamp(physicsVelocityY * 0.003, -0.15, 0.15)

    let rawYScale = breathScale * dropHopSquash * pose.yScale * (1.0 + velocityStretch)
    bodyNode?.yScale = clamp(rawYScale, 0.6, 1.3)
    bodyNode?.xScale = clamp(1.0 / sqrt(bodyNode!.yScale), 0.6, 1.3) * pose.xScale

    if currentStage == .drop {
        bodyNode?.position.y = dropHopOffset + pose.yOffset
    } else {
        bodyNode?.position.y = pose.yOffset   // was: untouched outside Drop; now pose-driven
    }
    bodyNode?.zRotation = (currentStage == .egg) ? bodyNode!.zRotation : pose.zRotation

    headNode?.position.y += pose.headOffset - previousPoseHeadOffset
    previousPoseHeadOffset = pose.headOffset

    [pawFLController, pawFRController, pawBLController, pawBRController]
        .forEach { $0?.node.alpha = pose.pawAlpha }
}
```

**What must never write to `bodyNode`'s transform outside this function:**
no other controller, no direct `SKAction` on `bodyNode` (the
`CatBehaviors` direct-action path's `scaleY`/`moveBy` calls, if ever
reactivated, must target `bodyPoseController.setState` instead, not
`bodyNode` directly — otherwise the exact clobber this pipeline exists to
fix reappears one level down). The **root** `CreatureNode`'s own
`xScale`/`yScale`/`position` remain `updateWorld`'s and `setFacing`'s
territory unchanged — this pipeline never touches them except via the
`positionY`/`isAirborne` change in §4, which is additive to the existing
formula, not a replacement of its ownership.

# 7. Sprite-Stack Propagation

[`SpriteStackRenderer`](/SYSTEMS/rendering-stack-2-5d.md) currently exposes
`update(breathScale:)` (`Creature/SpriteStackRenderer.swift:166`) and only
ever sets `layer.xScale = body.xScale` (facing mirror) plus a breath-driven
spread offset — it has no `zRotation` or `alpha` propagation at all. Once
`bodyNode` can squash, curl, or rotate (above), every stage with active
stack layers (3 at Critter, 5 at Beast, 7 at Sage/Apex — 0 at Egg/Drop, so
this gap is invisible until Critter) will visibly shear: the front
silhouette rotates or compresses while the shadow/highlight layers behind
it stay full-size and unrotated, "stranding" the depth effect outside the
new silhouette's edges. Proposed signature change:

```swift
func update(breathScale: CGFloat, poseYScale: CGFloat,
            poseZRotation: CGFloat, poseAlpha: CGFloat)
```

Applied per layer, in addition to the existing spread/xScale logic:
`layer.yScale = poseYScale` (matching the front body's composed value from
§6, not just the raw breath scale), `layer.zRotation = poseZRotation`,
`layer.alpha = baseLayerAlpha(index) * poseAlpha` (so Apex's alpha
oscillation, `glitch`'s flicker, and any future body fade dim the whole
depth stack together, not just the front layer). This is **not** a
rotatable-volume simulation — the stack is still flat duplicate
silhouettes — but it stops the depth layers from visibly disagreeing with
the front body's shape. Ownership of this change stays with
[the rendering stack concept](/SYSTEMS/rendering-stack-2-5d.md); noted here
only because it must ship in the **same WO** as this pipeline per the
dossier's risk list, or every crouch/roll/curl ships half-broken.

# 8. `auraState` Consumption

`auraNode` (`Creature/CreatureNode.swift:21`, populated from
`ShapeFactory`/`StageRenderer`'s `nodes.aura` — a Bone-tinted circle at
0.08 alpha, gated `stage >= .beast` per `ResolvedCreatureState.hasAura`) is
never driven by `state.auraState` anywhere in the codebase — confirmed by
grep across every consumer of `.auraState`. It is **distinct** from the
mutation-rarity "rarity_aura" nodes in `CreatureNode+Effects.swift`
(separate node name, separate `MutationSystem`-driven trigger — do not
conflate the two systems). Six literal `auraState` strings are produced
today: `subtle` (stage default), `pulse` (`meditate` perform action, also
`EmergentStates`' Content-state override), `sparkle` (`celebrate`),
`static` (`glitch`, Sage+), `transcendent` (`transcend`, Apex+), `warm`
(`EmergentStates`' Content-state preferred override,
`EmergentStates.swift:96`).

| `auraState` | Alpha | Pulse period | Color |
|---|---|---|---|
| `subtle` (default) | 0.08 (unchanged from shipped default) | none | Bone |
| `warm` | 0.14 | none (steady) | Bone, lerped 30% toward the stage accent color |
| `pulse` | 0.10 → 0.20 | 2.0s sine | Bone |
| `sparkle` | 0.10 → 0.25 | 0.6s sine (faster — matches `celebrate`'s energetic read) | Gilt |
| `static` | random 0.05-0.30 per frame (no smooth interpolation — deliberately noisy) | n/a | Ash, desaturated |
| `transcendent` | 0.20 → 0.35 | 4.0s sine (slow, matching Apex's existing 0.5Hz alpha-oscillation cadence, `CreatureNode.swift:215`) | Gilt, lerped toward Dusk |

All colors drawn from the existing 8-color Display P3 palette per
[grounds[1]](#citations)'s hard rule — no new color, only alpha/lerp
variation. This can be a single small function inside
`BodyPoseController` (it already receives `state` in `applyBehaviorOutput`
per §1) rather than a dedicated 14th controller — `auraState` has no
scale/position component, only alpha and tint, so it does not need its own
blend-timing infrastructure beyond what §1 already sets up.

# Frame Budget & Feasibility

Every operation above is transform-only arithmetic on existing nodes — no
new `SKShapeNode`s, no per-frame `CGPath` regeneration (the one exception,
`path-swap` for `curl`/`sleep_curl`/`roll_side`, is explicitly **designed,
not built**, and until it ships those three states render as scale-only
approximations of a squashed oval rather than a true curled/rolled shape —
acceptable under the Solid Fill Test per grounds[1], not the final
intended silhouette). Cost is a handful of multiplications and one `sqrt`
per frame plus the existing `SpriteStackRenderer` per-layer loop (already
budgeted); well inside the ~5.7ms design allocation and nowhere near the
16.6ms/60fps or `FrameBudgetMonitor`'s 10ms-warn/14ms-error thresholds. No
new node count — `BodyPoseController` does not add nodes, only writes to
`bodyNode`/`headNode`/the four paw nodes/`auraNode`, all of which already
exist per stage.

# What This Concept Does Not Cover

- The **full jump grammar** (anticipation-crouch timing separate from the
  `jump` tuple's brief dip, dust particles, the complete trigger-to-recovery
  choreography) — this concept owns the render mechanism (§4, §5) that the
  full Airborne Arc System consumes; the choreography beats themselves are
  not authored here.
- **Weight & momentum** (per-stage mass classes, acceleration ramps, skid
  stops) — owned by [locomotion & gait](/SYSTEMS/locomotion-and-gait.md),
  which reads this pipeline's compose point but does not duplicate it.
- **Posture Vocabulary**'s five emotion-driven parameters
  (hipHeight/spineCurve/headPitch/tailCarriage/gaitBounce) — explicitly a
  *further* multiplicative modifier layer riding this pipeline's compose
  point, owned and tabulated by
  [emotional body language](/SYSTEMS/emotional-body-language.md).

# Citations

[1] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (`applyBehaviorOutput:810-833`, `updateWorld:297-378`, `updateRender:392-395`, subsystem call order in `update(_:)`)
[2] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`updateBreathing`, `bodyNode`, part-controller list, `updateNoiseIdle`'s delta-offset pattern)
[3] `Pushling/Sources/Pushling/Behavior/PhysicsLayer.swift` (`JumpState`, `startJump`, `updateJump`, `landingCompressionFrames`)
[4] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`LayerOutput`, `ResolvedCreatureState.defaultState`, `Easing.easeInOut`)
[5] `Pushling/Sources/Pushling/Behavior/BlendController.swift` (`blendableProperties`, `PropertyBlend.currentState`, `updatePosition`)
[6] `Pushling/Sources/Pushling/IPC/PerformActionMapping.swift` (all 18 perform-action `bodyState`/`positionY`/`auraState` literals)
[7] `Pushling/Sources/Pushling/Behavior/ReflexLayer.swift` (`flinch`, `startle` reflex definitions)
[8] `Pushling/Sources/Pushling/Feed/HookEventProcessor.swift` (`tool_wince`, `compact_daze` reflexes)
[9] `Pushling/Sources/Pushling/Behavior/TaughtBehaviorEngine.swift` (`applyMovementState`'s `jump` → `positionY = 8.0`)
[10] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift` (`pounce`/`crouch`/`sit` bodyState usage)
[11] `Pushling/Sources/Pushling/Creature/SpriteStackRenderer.swift` (`update(breathScale:)`, layer count table)
[12] `Pushling/Sources/Pushling/Creature/EmergentStates.swift` (`preferredAuraState`)
[13] `Pushling/Sources/Pushling/Creature/CreatureNode+Effects.swift` (`rarity_aura` — distinct system, not this pipeline's aura)
[14] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds[0]` (body-movement findings), `.grounds[1]` (hard constraints: silhouette caps, frame budget, palette)
[15] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` lines 12-16, 162-163, 196-199, 217-240 (Body Pose & Compose Pipeline spec, risk list, grounding key facts)
