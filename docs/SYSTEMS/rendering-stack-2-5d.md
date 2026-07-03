---
type: System
title: Enhanced 2.5D Rendering Stack
description: The shipped pseudo-3D rendering architecture for the Touch Bar scene — silhouette-stacked creature, four-layer parallax terrain, SDF-style glow, time-of-day lighting overlay — reconciled against the original feasibility research's recommendations. Deepened with the designed-not-built SpriteStackRenderer propagation contract, the generalized fright-spread channel, and the legHeight hind-leg wiring decision.
status: Live
tags: [rendering, spritekit, 2.5d, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the authority for **how Pushling renders as a pseudo-3D scene inside
a real 2D engine (SpriteKit)** — the layer-by-layer technique stack as
shipped. It does not own the *feasibility research* that led to this
approach (eight 3D rendering options evaluated and rejected against the
Touch Bar's 36.17:1 aspect ratio — SceneKit, Metal, RealityKit, software
raycasting/voxel space, isometric, a voxel engine, sprite stacking, and Mode
7 — see [3D rendering feasibility](/RESEARCH/3d-rendering-feasibility.md)
for that reasoning and its own **Outcome** section, which already
cross-links here for what shipped). It also does not own the parallax layer
*configuration* (scroll factors, z-positions, terrain generation — see
[world terrain & parallax](/SYSTEMS/world-terrain-parallax.md)), the cat's
shape/proportion design (see
[creature visual design](/REFERENCE/creature-visual-design.md)), the spring
and noise formulas driving motion (see
[procedural animation](/REFERENCE/procedural-animation.md)), or the palette
and OLED-specific rendering practices (see [the P3 palette](/REFERENCE/palette.md)
and [OLED rendering techniques](/REFERENCE/oled-rendering-techniques.md)).
It also does not own *what* transform values `bodyNode` takes on any given
frame — that's [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)'s
`BodyPoseController` (whole-body posture) and
[emotional-body-language.md](/SYSTEMS/emotional-body-language.md)'s Arch
Grammar (startle/fright) — but it does own *how the depth-stack duplicates
follow whatever those systems produce*, and the general contract for
activating the hind-leg render both those and
[hunt-and-pounce.md](/SYSTEMS/hunt-and-pounce.md) want to use. This concept
is purely the *shipped-technique* authority — the layer stack that resulted
from the research's "stay in SpriteKit, add targeted pseudo-3D techniques"
verdict — plus the deepening below, which is designed-not-built groundwork
for that stack to survive the whole-body posing work landing elsewhere.

# The Shipped Stack, Layer by Layer

| Layer | Shipped technique | Verified against |
|---|---|---|
| **Creature volume** | Silhouette-stacking (see below) — NOT the originally researched horizontal texture-slice sprite stack | `Creature/SpriteStackRenderer.swift` |
| **Creature glow** | Flat-color body silhouette at 1.3× scale, additive blend, alpha 0.10-0.18 pulsed with the breathing cycle. Stage-gated Critter+. This is the shipped stand-in for the researched "SDF glow shader" — a plain `SKShapeNode` overlay, not a fragment shader computing true signed-distance-field falloff | `Creature/CreatureNode+Effects.swift` (`setupGlow`/`updateGlow`, Phase 4.2) |
| **Creature lighting** | A second silhouette overlay, multiply blend, alpha 0.04-0.10, tinted and offset per [sky time period](/SYSTEMS/sky-celestial.md) (Ember from the east at dawn, Bone from above at day, Ember from the west at dusk, Tide "moonlight" at night). Stage-gated Beast+. Also flashes on lightning strikes | `Creature/CreatureNode+Effects.swift` (`setupLightingOverlay`/`updateLighting`/`flashLightning`, Phase 4.1) |
| **Ground / terrain** | Four-layer depth-interpolated parallax (far/deep/mid/fore) with per-layer noise octave count, amplitude, and atmospheric color — see [world terrain & parallax](/SYSTEMS/world-terrain-parallax.md) for the full layer config | `World/ParallaxSystem.swift`, `World/WorldManager+DepthTerrain.swift`, `World/TerrainRecycler.swift` |
| **Atmospheric depth** | `PushlingPalette.atmosphericColor(_:depth:)` desaturates toward Ash and reduces alpha as `depth` approaches 1.0 (up to 50% desaturation, 40% alpha reduction) — applied to background-layer terrain fills | `World/PushlingPalette.swift:107`, `World/TerrainRecycler.swift` (`buildBGGround`) |
| **Sky / celestial** | Real-time gradient + moon + star field — see [sky & celestial system](/SYSTEMS/sky-celestial.md) | `World/SkySystem.swift` |
| **Clouds** | Dedicated parallax-scrolled layer between far and mid — see [sky & celestial system](/SYSTEMS/sky-celestial.md) | `World/CloudSystem.swift` |
| **Weather** | Particle renderers (rain/snow/storm/fog) — see [weather system](/SYSTEMS/weather.md) | `World/RainRenderer.swift` and siblings |

# Sprite-Stacking: The Shipped Variant

The original research (`docs/archive/3D-RENDERING-RESEARCH.md` §9) proposed sprite
stacking as **10-18 horizontal texture slices** rendered like a CT-scan
played back — each an independent `SKSpriteNode` with a 1pt vertical offset,
giving the creature a rounded, rotatable volumetric form. **This is not what
shipped.** `Creature/SpriteStackRenderer.swift` implements a materially
different, cheaper technique: a small number of **duplicate body-silhouette
shapes** (not texture slices) stacked at fixed vertical offsets above and
below the real body node —

| Growth stage | Layer count | Split |
|---|---|---|
| Egg, Drop | 0 | too simple for a depth effect |
| Critter | 3 | 1 shadow (below), 2 highlight (above) |
| Beast | 5 | 2 shadow, 3 highlight |
| Sage, Apex | 7 | 3 shadow, 4 highlight |

Shadow layers below the body fill with Ash at alpha 0.02 (outermost) fading
to 0.05 (innermost, closest to the body); highlight layers above fill with
Bone at alpha 0.12 (innermost) fading to 0.04 (outermost) — light is modeled
as coming from above. Base spacing between layers is 0.7pt
(`SpriteStackRenderer.baseSpacing`). Every frame, the stack's spread
modulates with the body's breathing `yScale` deviation (×12 breath-spread
factor) so the layers visibly "fan out" on the inhale — a belly-expansion
illusion cheaper than animating true volume. All layers share the body's
`bodySilhouette(width:height:stage:)` path from
[creature visual design](/REFERENCE/creature-visual-design.md) and track its
`xScale` for facing-direction flips. This is a shadow/highlight duplicate
stack, not a slice stack — the "CT-scan" volumetric read comes from the
alpha gradient across duplicates, not from stacked cross-sections of the
body.

# SpriteStackRenderer Propagation Contract (Designed, Not Built)

Today `update(breathScale:)` (`SpriteStackRenderer.swift:166-188`) does
exactly two things per layer: recompute a spread-modulated Y offset from
the shared body position, and copy `body.xScale` for the facing mirror. It
never reads `yScale`, `zRotation`, or `alpha` — that gap is invisible today
because nothing else ever changes those three properties on `bodyNode`
outside breathing's own `yScale`, which the stack already receives via the
`breathScale` parameter. [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)
proposes a `BodyPoseController` (13th part controller) that composes
`pose.yScale`/`pose.zRotation` onto `bodyNode` every frame at its
[single compose point](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula)
so the torso can squash into `crouch`, curl into `sleep_curl`, roll into
`roll_side`, and rotate for a dozen other `bodyState`s — none of which
exist in the shipped renderer yet. The moment that ships, every stage with
active stack layers (3 at Critter, 5 at Beast, 7 at Sage/Apex — 0 at
Egg/Drop, so the gap stays invisible until Critter) will visibly shear: the
front silhouette squashes or rotates while its shadow/highlight duplicates
behind it stay full-size and unrotated, stranding the depth illusion
outside the new silhouette's own edges.

Ownership of the fix stays with this concept —
[body-pose-pipeline.md §7](/SYSTEMS/body-pose-pipeline.md#7-sprite-stack-propagation)
proposes the same signature and explicitly defers ownership here. Proposed
signature:

```swift
func update(breathScale: CGFloat, poseYScale: CGFloat,
            poseZRotation: CGFloat, poseAlpha: CGFloat)
```

Applied per layer, added to the existing spread/`xScale` write:

| Property | Shipped today | Designed |
|---|---|---|
| Y offset (spread) | `restOffset * spreadMultiplier`, `spreadMultiplier` driven by `breathScale` deviation | unchanged (see the spread-channel generalization below) |
| `xScale` | `= body.xScale` (facing mirror) | unchanged |
| `yScale` | never set — defaults to `1.0` | `= poseYScale`, the front body's fully composed value from the pipeline's §6 formula, not the raw breath scale alone |
| `zRotation` | never set — defaults to `0` | `= poseZRotation` |
| `alpha` | fixed per-layer constant set once at `configure()` (shadow 0.02→0.05, highlight 0.12→0.04) | `= baseLayerAlpha(index) * poseAlpha` — multiplicative, so Apex's alpha oscillation and `glitch`'s flicker dim the whole stack together, not just the front layer |

**Program-level risk, restated here because it's this concept's to guard:**
this must ship in the **same WO** as the `BodyPoseController`, never as a
follow-up — a body-pose controller that composes `yScale`/`zRotation` onto
`bodyNode` without this propagation change ships every crouch/roll/curl
half-broken (front silhouette posed, depth duplicates frozen in `stand`).
Even once this lands, it is **not** a rotatable-volume simulation — the
stack is still flat duplicate silhouettes, per
[the shipped-variant section above](#sprite-stacking-the-shipped-variant) —
this only stops the duplicates from visibly disagreeing with the front
body's shape.

# The Spread Channel: Breath and Beyond (Designed, Not Built)

`breathSpreadFactor` (`SpriteStackRenderer.swift:27`, `= 12.0`) is wired to
exactly one input today: the deviation of `bodyNode`'s breathing `yScale`
from `1.0` (`0.0` to `~0.03` at breath peak), producing a spread multiplier
of `1.0` to `~1.36` on every layer's rest offset. Nothing about `update()`'s
spread math is breath-specific — it is a generic "how far do the layers fan
out from rest" channel that happens to be fed by one deviation input.

[emotional-body-language.md](/SYSTEMS/emotional-body-language.md)'s Arch
Grammar (startle cascade / fright puff) wants the same fan-out illusion for
a body-puff reaction, not a breath one — a startled creature "poofing up"
should read as the depth stack spreading wider, reusing this exact visual
language, without a second rendering mechanism. The clean generalization:
replace the single `breathScale` parameter with a spread-magnitude value
the *caller* composes before passing in, rather than `SpriteStackRenderer`
reaching into two unrelated systems itself:

```swift
func update(spreadDeviation: CGFloat, poseYScale: CGFloat,
            poseZRotation: CGFloat, poseAlpha: CGFloat)
```

`spreadDeviation` would be `max(breathDeviation, frightPuffDeviation)` (or a
capped sum, if both should stack) computed by `CreatureNode` — the one
place that already knows both inputs — not by `SpriteStackRenderer`, which
stays a dumb per-frame transform applier consistent with the rest of this
doc. `breathSpreadFactor` (12.0) remains the shared multiplier for both
inputs unless play-testing shows fright needs its own scalar (a
`frightSpreadFactor` constant, if so — the field name is free, the
mechanism isn't). No new node and no new pass: this is a one-parameter
rename plus a `max()`/`+` at the caller.

# The `legHeight` Wiring Decision (Designed, Not Built)

`ShapeFactory.makePaw` (`ShapeFactory.swift:276-318`) already accepts
`legHeight`/`legAngle`/`isFront` parameters and, when `legHeight > 0`, adds
a real tapered `CatShapes.catLeg` child (`CatShapes.swift:468-`, front/back
taper already differentiated — clean inward taper vs. an outward thigh
bulge then taper). **Grep-verified dead at every call site:** all five
`StageRenderer` construction points (`:235-241`, `:330-336`, `:444-450`,
`:615-621`) call `makePaw` with the parameter's default, `legHeight: 0` —
no caller anywhere passes a nonzero value. `PawController`'s
`"_leg"`-suffixed node lookup is dead code as a direct consequence: the
node it searches for never exists.

**Decision:** this concept does not make legs a permanent Beast+
structural change to the silhouette — that would be a body-proportion
redesign ([creature visual design](/REFERENCE/creature-visual-design.md)
budgets "legs 10-20%" of the reference proportions, but the shipped
paw-bean silhouette was never drawn expecting a visible upper-leg segment
above it, and re-drawing it is out of this deepening's scope). What this
concept specifies instead is the **general wiring contract**, so any
consumer can activate `legHeight` transiently without re-deriving the
plumbing:

| Parameter | Contract |
|---|---|
| Gate | Beast+ only (`stage >= .beast`) — Critter and below stay paw-bean-only forever; legs never appear below Beast |
| Default | `legHeight: 0` (no leg) remains the resting/idle default at every stage, always — legs activate only for a specific move's duration, then revert |
| Activation | The caller is a behavior/controller, never `StageRenderer` itself — it re-invokes `makePaw` with `legHeight > 0` for the **rear pair only** (`isFront: false`); front legs stay retracted-to-bean in every currently-scoped consumer, since no proposed move needs a raised or extended foreleg |
| `legAngle` | Drives the leg's `zRotation` — a caller's piston/kick animation oscillates this per-frame; it is not a static pose parameter |
| Revert | `legHeight: 0` on move end — legs are a transient prop for the move's duration, not a persistent state; a rebuild (matching `StageRenderer`'s existing "rebuild on stage change" pattern) is the cheapest correct implementation, not a toggle on a permanently-live node |
| Fallback (below Beast, or before this ships) | Rear paw-beans alone piston against the body — no legs, no new assets. This is not a placeholder to fix later; it is the permanent behavior below Beast |

**First scoped consumer:**
[hunt-and-pounce.md's Grapple & Bunny-Kick](/SYSTEMS/hunt-and-pounce.md#the-beast-hind-leg-legheight-decision)
makes the specific creative call for its own move (`legHeight: 3.0,
isFront: false` for the Kick beat's duration, oscillating `legAngle`
through the kick's 5-6Hz piston formula, reverting to `0` on Flop) — that
concept owns the choice of *when and how far* to raise the leg for *that*
move; this concept owns that the plumbing exists and behaves identically
for any future second consumer. Cite this table rather than re-deriving
the wiring contract per move.

# Frame Budget

The stack above (creature silhouette duplicates + glow + lighting overlay +
four-layer parallax + sky/clouds/weather) targets the ~5.7ms of the 16.6ms
(60fps) frame budget documented project-wide, with node count kept under the
120-node ceiling via the recycling pools described in
[world terrain & parallax](/SYSTEMS/world-terrain-parallax.md). Frame-time
instrumentation lives in `Scene/FrameBudgetMonitor.swift`.

# Deferred / Not Pursued

Three ideas from the design-era research remain unbuilt and are not on any
active track: (1) **texture-caching static body shapes** — converting the
per-frame-rerendered `SKShapeNode` body/head/ear shapes to `SKSpriteNode`
textures (`view.texture(from:)`) at stage-transition time to halve per-frame
shape-render cost — the codebase's only live use of `texture(from:)` today is
the debug/MCP screenshot feature (`pushling_sense("visual")`), not a
performance cache; (2) a full **texture-atlas swap** (hand-drawn pixel
sprites replacing the procedural Bézier paths) — deferred, no art pipeline
exists for it; and (3) **depth blur on the mid-ground and background
parallax layers** — the research recommended `CIGaussianBlur` on distant
mid-ground objects and a stronger blur plus color desaturation on the
background layer ("aerial perspective — far objects blue-shifted and
hazy"). What shipped instead, and is the entirety of the atmospheric-depth
row above, is desaturation-toward-Ash plus alpha reduction via
`PushlingPalette.atmosphericColor(_:depth:)` — the blur half of the
recommendation was never implemented; a repo-wide grep for `GaussianBlur`
or `CIFilter` returns zero hits outside this citation. All three are
preserved here as intent, not scheduled work.

# Citations

[1] `docs/archive/3D-RENDERING-RESEARCH.md` §9 (Sprite Stacking), §14 (Recommended Approach: Enhanced 2.5D — stack table, Implementation Priority)
[2] `Pushling/Sources/Pushling/Creature/SpriteStackRenderer.swift`
[3] `Pushling/Sources/Pushling/Creature/CreatureNode+Effects.swift`
[4] `Pushling/Sources/Pushling/World/ParallaxSystem.swift`, `World/PushlingPalette.swift`
[5] `Pushling/Sources/Pushling/Scene/FrameBudgetMonitor.swift`
[6] `docs/RESEARCH/3d-rendering-feasibility.md` — the feasibility research and comparison matrix this stack implements
[7] `Pushling/Sources/Pushling/Creature/ShapeFactory.swift` (`makePaw:276-318`, `legHeight`/`legAngle`/`isFront` params, unused defaults at all five `StageRenderer` call sites)
[8] `Pushling/Sources/Pushling/Creature/CatShapes.swift` (`catLeg:468-`, front/back taper differentiation)
[9] `docs/SYSTEMS/body-pose-pipeline.md` §6 (compose point), §7 (sprite-stack propagation proposal — ownership deferred to this concept)
[10] `docs/SYSTEMS/emotional-body-language.md` — Arch Grammar, the fright-spread consumer of the generalized spread channel above
[11] `docs/SYSTEMS/hunt-and-pounce.md` — Grapple & Bunny-Kick, the first scoped `legHeight` consumer
