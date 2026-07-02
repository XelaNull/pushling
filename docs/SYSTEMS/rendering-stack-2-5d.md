---
type: System
title: Enhanced 2.5D Rendering Stack
description: The shipped pseudo-3D rendering architecture for the Touch Bar scene — silhouette-stacked creature, four-layer parallax terrain, SDF-style glow, time-of-day lighting overlay — reconciled against the original feasibility research's recommendations.
status: Live
tags: [rendering, spritekit, 2.5d, system]
timestamp: 2026-07-02T00:00:00Z
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
This concept is purely the *shipped-technique* authority — the layer stack
that resulted from the research's "stay in SpriteKit, add targeted
pseudo-3D techniques" verdict.

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

The original research (`docs/3D-RENDERING-RESEARCH.md` §9) proposed sprite
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

# Frame Budget

The stack above (creature silhouette duplicates + glow + lighting overlay +
four-layer parallax + sky/clouds/weather) targets the ~5.7ms of the 16.6ms
(60fps) frame budget documented project-wide, with node count kept under the
120-node ceiling via the recycling pools described in
[world terrain & parallax](/SYSTEMS/world-terrain-parallax.md). Frame-time
instrumentation lives in `Scene/FrameBudgetMonitor.swift`.

# Deferred / Not Pursued

Two ideas from the design-era research remain unbuilt and are not on any
active track: (1) **texture-caching static body shapes** — converting the
per-frame-rerendered `SKShapeNode` body/head/ear shapes to `SKSpriteNode`
textures (`view.texture(from:)`) at stage-transition time to halve per-frame
shape-render cost — the codebase's only live use of `texture(from:)` today is
the debug/MCP screenshot feature (`pushling_sense("visual")`), not a
performance cache; and (2) a full **texture-atlas swap** (hand-drawn pixel
sprites replacing the procedural Bézier paths) — deferred, no art pipeline
exists for it. Both are preserved here as intent, not scheduled work.

# Citations

[1] `docs/3D-RENDERING-RESEARCH.md` §9 (Sprite Stacking), §14 (Recommended Approach: Enhanced 2.5D — stack table, Implementation Priority)
[2] `Pushling/Sources/Pushling/Creature/SpriteStackRenderer.swift`
[3] `Pushling/Sources/Pushling/Creature/CreatureNode+Effects.swift`
[4] `Pushling/Sources/Pushling/World/ParallaxSystem.swift`, `World/PushlingPalette.swift`
[5] `Pushling/Sources/Pushling/Scene/FrameBudgetMonitor.swift`
[6] `docs/RESEARCH/3d-rendering-feasibility.md` — the feasibility research and comparison matrix this stack implements
