---
type: Research Note
title: Touch Bar 3D Rendering Feasibility (36:1 Constraint)
description: Evaluation of eight 3D rendering approaches against the Touch Bar's 2170x60 / 36:1 aspect ratio, concluding perspective 3D is unreadable at 30pt and enhanced 2.5D in SpriteKit is optimal.
status: Current
tags: [research, rendering, 3d, spritekit, touch-bar]
timestamp: 2026-07-02T00:00:00Z
---

**Research date: 2026-03-15. Conclusion reached and acted on: stay with
SpriteKit 2D, adopt targeted pseudo-3D enhancements.** This is a completed
feasibility study, preserved for its reasoning — not a currently-open
question. See **Outcome** at the end of this concept for what was actually
built versus what this research recommended.

Every viable 3D rendering approach for the Touch Bar's 2170x60 pixel OLED
strip was evaluated. The finding: **3D rendering is technically possible on
the Touch Bar** (SceneKit, Metal, and software raycasters can all render to
it — Doom proved this in 2016), but **true 3D would not look better than 2D
parallax for a virtual pet.** The 36:1 aspect ratio is the killer
constraint — at 30 points tall, perspective projection becomes an unreadable
horizontal sliver. The recommended sweet spot: **enhanced 2.5D** — stay in
SpriteKit, adopt targeted pseudo-3D techniques (sprite stacking, a
perspective ground plane, atmospheric blur, normal-mapped lighting) for a
3D *feel* without sacrificing readability.

# The Constraint: 36:1 Aspect Ratio

```
Touch Bar: 2170 x 60 pixels (1085 x 30 points @2x)
Aspect ratio: 36.17 : 1
Physical size: ~310mm x 10mm (12.2" x 0.4")
```

For comparison: standard widescreen is 16:9 (1.78:1), an ultra-wide monitor
is 21:9 (2.33:1), CinemaScope film is 2.39:1. **The Touch Bar is 36.17:1** —
15x wider relative to its height than a standard monitor.

| 3D Camera Type | Effect at 36:1 |
|---|---|
| Perspective (standard) | Scene compressed to a horizontal slit; floor and ceiling converge to nearly the same line |
| Orthographic (side view) | Works well — this is essentially what 2D side-scrolling already does; no advantage over the current approach |
| Orthographic (top-down) | Extreme horizontal letterboxing; a tiny strip of world visible |
| Perspective (low angle) | Ground plane dominates; objects appear as vertical slivers |
| Isometric | Playable but heavily compressed vertically; diamond tiles become nearly flat lines |

At 30 points tall, every pixel of vertical space is precious. A 3D cat that
is 20 points tall in side view can lose ~40% of its readable detail once
perspective foreshortening is applied at a slight camera angle.

# Option 1: SceneKit

**Feasible: yes** — `SCNView` is an `NSView` subclass, embeds in
`NSCustomTouchBarItem` exactly like `SKView`. **Performance: likely OK** —
2170x60 is only 130,200 pixels/frame (vs. 2,073,600 for 1080p); estimated
3-8ms/frame, within the 16.6ms budget but with less headroom than
SpriteKit's ~5.7ms. **Visual quality at 30pt: poor** — a low-poly 3D cat has
only ~15-18 visible vertical pixels of actual geometry; smooth 3D surfaces
look *worse* than pixel art at tiny scales (anti-aliased mush, not crisp
edges); fur/material detail is unreadable. **Deprecation risk**: as of WWDC
2025, Apple placed SceneKit in soft deprecation (maintenance-only), pushing
new 3D work to RealityKit. **Effort: high** (4-8 weeks — full creature,
terrain, camera, lighting, and touch-handling rewrites). **Verdict: not
recommended** — technically possible, visually worse, architecturally risky.

# Option 2: Metal (Raw GPU Access)

**Feasible: theoretical** (never publicly demonstrated on the Touch Bar, but
no known technical barrier — `MTKView` is also an `NSView` subclass).
**Performance: excellent** — trivial at 2170x60, bottleneck would be
CPU-side setup. **Visual quality: depends entirely on the custom renderer**
built with it — promising directions include SDF creature rendering,
raymarched terrain, and a rim-light silhouette shader tuned for OLED black.
**Effort: very high** (8-16 weeks minimum) — no scene graph, no built-in
animation or physics; everything SpriteKit gives free must be rebuilt.
**Verdict: fascinating but impractical** as a full engine replacement — the
one exception is **SDF-based creature glow as an additive `SKShader`/
`CIFilter` pass on top of the existing SpriteKit pipeline**, which is
low-effort and worthwhile (see [OLED rendering techniques](/REFERENCE/oled-rendering-techniques.md)
for the shipped status of SDF glow).

# Option 3: RealityKit

**Feasible: problematic.** RealityKit renders through `RealityView`, a
SwiftUI view designed for AR/spatial computing, not tiny NSView-embedded
viewports. There is no direct `SCNView`-equivalent `NSView` subclass —
bridging would require `NSHostingView` wrapping a SwiftUI `RealityView`
inside an `NSTouchBarItem`: four layers of abstraction for a 60-pixel-tall
display. Non-AR macOS use of RealityKit is sparsely documented; AR-specific
overhead (environment understanding, occlusion, lighting estimation) is
irrelevant here and its disable-ability is unclear. **Effort: very high and
uncertain. Verdict: not recommended** — RealityKit is the future of Apple
3D, but built for AR/VR, not a 60-pixel-tall OLED strip.

# Option 4: Software 3D Rendering (Raycasting / Voxel Space)

**Feasible: proven** — this is what Doom on the Touch Bar demonstrated (a
full software renderer computing every pixel on the CPU). Two relevant
techniques: **raycasting** (Wolfenstein/Doom-style, one ray per screen
column) and **Voxel Space** (Comanche-style heightmap+colormap raycasting,
producing rolling perspective terrain in under 20 lines of code).
**Performance: trivially 60fps** — ~70K operations/frame for either
approach, <1ms on modern Apple Silicon. **Visual quality: mixed.**
Raycasting (corridor style) reproduces Doom's core problem: at 60px tall, a
first-person perspective compresses everything into an unreadable
horizontal sliver. Voxel Space is more promising for *terrain only* — a
Comanche-style rolling landscape from a slightly elevated camera could work,
but the creature itself would still need to be a 2D sprite composited on
top, at which point it's "3D terrain + 2D sprite" — essentially what the
existing parallax system already achieves with less complexity. **Effort:
moderate** (1-2 weeks for a basic prototype). **Verdict: interesting for
terrain, not for the creature** — the potential hybrid (Voxel Space terrain
background + SpriteKit creature/foreground) has marginal cost/benefit versus
maintaining two rendering systems.

# Option 5: Isometric 2D in SpriteKit

**Feasible: yes**, within the current engine — only art and positioning math
change, no engine swap. **Visual quality at 30pt: poor.** Isometric tiles
have a 2:1 width-to-height ratio; at 30pt tall a tile is only ~8pt tall and
~16pt wide, giving 3-4 visible rows — the diamond grid reads as a confusing
zigzag rather than depth, and the creature loses its clear silhouette.
Isometric depth illusion needs vertical space the Touch Bar does not have.
**Effort: moderate** (2-3 weeks — new art, new depth-sort system, parallax
rewrite). **Verdict: not recommended** — isometric projection fights the
aspect ratio.

# Option 6: Voxel Engine

**Feasible: yes** (software or Metal compute) — a small 64x64x16 voxel
world is computationally trivial at Touch Bar resolution (~65,100 rays,
hundreds of FPS even unoptimized). **Visual quality at 30pt: very poor** —
Minecraft-style voxels need a minimum readable block size; at 60px tall with
perspective, near blocks might be 6-10px, mid-distance 2-3px, far distance
sub-pixel aliasing noise. The extreme aspect ratio compounds this: a very
wide but very short slice of the world, like looking through a mail slot.
**Effort: high** (4-6 weeks). **Verdict: not recommended** — voxels need
resolution to read, and 60 pixels tall doesn't provide it.

# Option 7: Sprite Stacking (Pseudo-3D) — Recommended

The most promising "3D" technique evaluated. Renders a volumetric-looking
object as multiple 2D horizontal slices stacked with small vertical offsets
(like a CT scan played back as an animation) — entirely 2D sprites, no 3D
geometry:

```
Slice 5 (top):    ████        <- ears
Slice 4:        ████████      <- head top
Slice 3:       ██████████     <- head/eyes
Slice 2:        ████████      <- body
Slice 1:       ████████████   <- body + legs
Slice 0 (base):  ██    ██    <- paws on ground
```

**Feasible: yes, in current SpriteKit** — each slice is a plain
`SKSpriteNode`; SpriteKit handles 15-20 stacked layers per creature without
performance impact. **Visual quality at 30pt: good** — the key insight is
that sprite-stacking slices are *designed* to be readable at the target
size, unlike 3D geometry reduced down to it. At 18-20pt creature height,
15-18 stacked slices give a convincing volumetric, round, solid appearance
while keeping crisp pixel-art silhouettes. Rotation, baked-in lighting
(brighter top slices, darker bottom slices), and per-slice wobble/breathing
animation are all possible. OLED true-black transparency works perfectly
between slices. **Performance impact: minimal** — 15-20 extra nodes (well
within the 120-node budget), tiny textures (<50x20px), estimated <0.5ms
additional frame time. **Effort: low-moderate** (1-2 weeks for a basic
implementation). **Verdict: strongly recommended for the creature.**

# Option 8: Mode 7 Ground Plane

SNES-style perspective ground rendering via a per-scanline affine transform
on a flat texture (used by F-Zero, Mario Kart). **Feasible: yes, as a
SpriteKit shader** — implementable as a custom `SKShader` fragment shader
applying a perspective-division transform to a terrain-texture sprite.
**Visual quality at 30pt: moderate-good** — with the bottom 10-12pt as
ground plane, near terrain (bottom 4-5 rows) stays clear and readable,
mid-terrain compresses but stays recognizable, far terrain (top 2-3 rows)
blurs to a horizon — a convincing sense of the creature walking across
terrain that recedes into the distance. Limitation: only the ground plane
gets 3D treatment; objects above ground still need 2D depth-sorted sprites,
and Mode 7 cannot render vertical surfaces. **Performance: low** (one shader
pass, <0.3ms). **Effort: low** (3-5 days — write the shader, create a
terrain texture, swap in the shader sprite). **Verdict: recommended as a
terrain enhancement.**

# The Doom Precedent: What It Actually Proves

Adam Bell's Doom port to the Touch Bar is frequently cited as proof that "3D
works on the Touch Bar." What it actually demonstrated:

**Proved:** any `NSView` subclass can render to the Touch Bar (no rendering
restriction in the display pipeline); full 3D at 2170x60 is computationally
trivial; the hardware has no inherent rendering limitation — the constraint
is entirely software/display; sound works alongside Touch Bar rendering.

**Also proved (the part people ignore):** the game was unplayable — walls,
enemies, and items were indistinguishable at 60 pixels tall; it was a proof
of concept never released, and Bell himself acknowledged its impracticality;
first-person perspective is terrible at 36:1 (floor and ceiling converge to
nearly the same scanline); the HUD-on-the-Touch-Bar-while-playing-on-the-
main-screen configuration worked far better than playing *in* the Touch Bar.

**The lesson**: the Touch Bar can render 3D, but perspective 3D at 60 pixels
tall is visually useless for anything requiring detail recognition. Doom
worked as a tech demo because FPS games are about spatial navigation, which
can work even at low resolution via movement cues. A virtual pet requires
reading facial expressions, body language, and environmental detail — all
of which demand more vertical resolution than 3D perspective allows.

# The Aspect Ratio Problem: Why 3D Fails at 36:1

In a standard 16:9 viewport, a 3D scene uses vertical space generously
(~30% sky, ~40% mid-field, ~30% ground). At 36:1, perspective projection
compresses this to roughly 3 pixels of sky, 24 pixels of mid-field, 3 pixels
of ground — and those 24 mid-field pixels must contain the creature,
terrain, weather, and any UI. For a 20pt-tall creature, that leaves 4 pixels
for everything else.

| Technique | How It Works | Suitability |
|---|---|---|
| Side-scrolling 3D | Camera perpendicular to movement, orthographic projection | This is just 2D with extra steps — no advantage |
| Orthographic projection | No perspective scaling, parallel lines stay parallel | Eliminates depth cues — defeats the purpose of 3D |
| Low-angle camera | Camera near ground, looking slightly up | Good for showing ground plane, but the creature viewed from below is unflattering and hard to read |
| Top-down with tilt | Camera above, tilted ~15-20° | The creature becomes a top-view, losing all silhouette readability |
| **Parallax 2.5D** | Multiple 2D layers scrolling at different speeds | **Already what Pushling does — and it works** |
| Forced perspective | Artistic tricks (larger foreground, smaller background) | Can be done in 2D without a 3D engine |

**The honest answer**: the best "3D" approach for a 36:1 display is
*exactly* what the project already had at research time — multiple 2D
layers creating depth through parallax, with the creature as a large,
readable 2D sprite in the foreground. The depth illusion comes from
differential scroll speeds, not geometric projection. What *can* be added:
volumetric effects on the creature (sprite stacking), a perspective ground
plane (Mode 7), atmospheric depth (blur on distant layers), and dynamic
lighting (normal maps on sprites) — a 3D *feeling* without the pixel cost of
actual 3D geometry.

# Comparison Matrix

| Approach | Feasible? | 60fps? | Visual Quality at 30pt | Effort | Better Than 2D? | Recommended? |
|---|---|---|---|---|---|---|
| SceneKit | Yes | Yes | Poor — anti-aliased mush | High (4-8wk) | No | No |
| Metal (custom) | Probably | Yes | Depends — could be great hand-tuned | Very High (8-16wk) | Maybe, for specific effects | No (as full replacement) |
| RealityKit | Awkward | Unknown | Poor — AR overhead too | Very High + uncertain | No | No |
| Software Raycaster | Yes (Doom proved it) | Yes | Poor for FPS, moderate for terrain | Moderate (1-2wk) | No for creature, maybe terrain | No (as primary) |
| Voxel Space | Yes | Yes | Moderate terrain, poor objects | Moderate (2-3wk) | Marginal | No |
| Isometric | Yes | Yes | Poor — diamond grid fights the strip | Moderate (2-3wk) | No | No |
| Voxel Engine | Yes | Yes | Very poor — blocks need resolution | High (4-6wk) | No | No |
| **Sprite Stacking** | Yes | Yes | **Good** — volumetric, crisp edges | Low (1-2wk) | **Yes** | **Yes** |
| **Mode 7 Ground** | Yes | Yes | **Moderate-Good** | Low (3-5d) | **Yes** | **Yes** |
| **SDF Glow (Metal shader)** | Yes | Yes | **Good** | Low-Moderate (1wk) | **Yes**, additive | **Yes** (additive) |
| **Normal-mapped Sprites** | Yes | Yes | **Good** | Low (1wk) | **Yes**, additive | **Yes** (additive) |

# What Was Explicitly Rejected

Full 3D engine replacement (SceneKit, Metal, RealityKit); isometric
projection; voxel rendering; first-person perspective of any kind.

# Outcome

This research's recommendation — enhanced 2.5D within SpriteKit, not a 3D
or Mode 7 engine — is what shipped. Concretely, verified against the
current codebase:

- **Sprite stacking** shipped, but as a materially different technique than
  this research's 10-18 texture-slice "CT scan" stack: `SpriteStackRenderer.swift`
  implements a stage-gated (3/5/7-layer) `SKShapeNode` silhouette
  shadow/highlight duplication at 0.7pt spacing, not stacked texture slices.
  Full detail is owned by [the Enhanced 2.5D Rendering Stack](/SYSTEMS/rendering-stack-2-5d.md)
  (not this concept).
- **Mode 7 ground plane was never built.** A repo-wide search for
  `mode ?7`, `groundPlane`, or `perspectiveGround` returns zero hits. In its
  place, the codebase shipped a depth-interpolated 4-layer parallax terrain
  system (`WorldManager+DepthTerrain.swift`,
  `Behavior/AutonomousLayer+DepthWandering.swift`) — a different mechanism
  achieving a related depth goal, owned by
  [world terrain and parallax](/SYSTEMS/world-terrain-parallax.md).
- **SDF glow shipped** as a shape-based approximation, not a literal
  fragment shader — see [OLED rendering techniques](/REFERENCE/oled-rendering-techniques.md).
- **Clouds** — not evaluated in this research at all — also shipped
  (`World/CloudSystem.swift`), adding a living-sky parallax layer this
  document didn't anticipate.

The core thesis — 3D perspective doesn't survive 36:1, additive pseudo-3D
techniques within 2D do — held. The *specific* techniques chosen at
implementation time diverged from this document's exact recommendations in
several places; those are corrections for the concepts that own creature
rendering and world terrain, not for this research note, which is preserved
as the reasoning that led to the "stay in SpriteKit" decision.

# Citations

### Apple Documentation
[1] [SceneKit | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit)
[2] [SCNView | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnview)
[3] [init(frame:options:) | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnview/1524215-init)
[4] [SCNSceneRenderer | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnscenerenderer)
[5] [RealityKit | Apple Developer Documentation](https://developer.apple.com/documentation/realitykit)
[6] [Bring your SceneKit project to RealityKit - WWDC25](https://developer.apple.com/videos/play/wwdc2025/288/)
[7] [Support for Metal on Apple devices](https://support.apple.com/en-us/102894)

### SceneKit Deprecation
[8] [WWDC 2025 - SceneKit Deprecation and RealityKit Migration](https://dev.to/arshtechpro/wwdc-2025-scenekit-deprecation-and-realitykit-migration-a-comprehensive-guide-for-ios-developers-o26)
[9] [Transitioning from SceneKit to RealityKit | Apple Developer Forums](https://developer.apple.com/forums/thread/739925)

### Doom on Touch Bar
[10] [Developer gets classic shoot 'em up game Doom running on the Touch Bar - 9to5Mac](https://9to5mac.com/2016/11/21/doom-macbook-pro-touch-bar/)
[11] [Running Doom on the MacBook Pro Touch Bar: A Quirky Tech Feat](https://www.oreateai.com/blog/running-doom-on-the-macbook-pro-touch-bar-a-quirky-tech-feat/827f6a121d66aae1bda7b42ca4acddcc)
[12] [Developer brings classic FPS Doom to Touch Bar | AppleInsider](https://appleinsider.com/articles/16/11/21/developer-brings-classic-fps-doom-to-touch-bar-on-apples-macbook-pro)
[13] [Just because you can play Doom on the Touch Bar doesn't mean you should | TechCrunch](https://techcrunch.com/2016/11/21/macbook-doom/)
[14] [Adam Bell on X (original tweet)](https://x.com/b3ll/status/800453225832849408)

### Voxel Space / Software Rendering
[15] [VoxelSpace: Terrain rendering in less than 20 lines of code](https://github.com/s-macke/VoxelSpace)
[16] [Voxel Space in the game Comanche](https://simulationcorner.net/index.php?page=comanche)
[17] [VoxelSurfing: High-Resolution Single-Threaded CPU Voxel Rendering](https://github.com/LukeSchoen/VoxelSurfing)
[18] [Voxel Displacement Renderer — Modernizing the Retro 3D Aesthetic](https://blog.danielschroeder.me/blog/voxel-displacement-modernizing-retro-3d/)
[19] [A Voxel Renderer for Learning C/C++ - Jacco's Blog](https://jacco.ompf2.com/2021/02/01/a-voxel-renderer-for-learning-c-c/)

### Sprite Stacking
[20] [SpriteStack.io](https://spritestack.io/)
[21] [This technique for making 2D pixel art look 3D | Creative Bloq](https://www.creativebloq.com/3d/video-game-design/this-technique-for-making-2d-pixel-art-look-3d-is-blowing-peoples-minds)
[22] [How to Make 2D Game Look 3D with Sprite Stacking](https://80.lv/articles/developer-shows-how-to-make-2d-game-look-3d-with-sprite-stacking)
[23] [Beginners Guide to Sprite Stacking | Medium](https://medium.com/@avsnoopy/beginners-guide-to-sprite-stacking-in-gamemaker-studio-2-and-magica-voxel-part-1-f7a1394569c0)

### Mode 7 / Perspective Ground Plane
[24] [Mode 7 - Wikipedia](https://en.wikipedia.org/wiki/Mode_7)
[25] [Kulor's Guide to Mode 7 Perspective Planes](https://forums.nesdev.org/viewtopic.php?t=24053)
[26] [Mode 7 Transform - SNESdev Wiki](https://snes.nesdev.org/wiki/Mode_7_transform)
[27] [Plane Awesome - How the SNES Mode 7 Graphics Worked](https://www.linkedin.com/pulse/plane-awesome-how-snes-mode-7-graphics-worked-sam-fairclough)
[28] [Tonc: Mode 7 Part 2](https://www.coranac.com/tonc/text/mode7ex.htm)

### Metal & GPU Rendering
[29] [Metal by Tutorials: The Rendering Pipeline | Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/3-the-rendering-pipeline)
[30] [Writing a Modern Metal App from Scratch | Metal by Example](https://metalbyexample.com/modern-metal-1/)
[31] [Custom Metal Drawing in SceneKit | Medium](https://rozengain.medium.com/custom-metal-drawing-in-scenekit-921728e590f1)

### RealityKit Non-AR
[32] [Quick RealityKit Tutorial: Programmatic non-AR Setup | Medium](https://rozengain.medium.com/quick-realitykit-tutorial-programmatic-non-ar-setup-cafaf61e9884)
[33] [Displaying 3D objects with RealityView on iOS, iPadOS and macOS](https://www.createwithswift.com/displaying-3d-objects-with-realityview-on-ios-ipados-and-macos/)

### Isometric & 2.5D Game Design
[34] [Isometric video game graphics - Wikipedia](https://en.wikipedia.org/wiki/Isometric_video_game_graphics)
[35] [Isometric Projection in Game Development | Pikuma](https://pikuma.com/blog/isometric-projection-in-games)
[36] [SpriteKit Advanced - How to build a 2.5D game | freeCodeCamp](https://www.freecodecamp.org/news/spritekit-advanced-how-to-build-a-2-5d-game-part-i-2dc76c7c65e2/)
[37] [Parallax scrolling for iOS with Swift and Sprite Kit | O'Reilly](http://radar.oreilly.com/2015/08/parallax-scrolling-for-ios-with-swift-and-sprite-kit.html)
[38] [Game developers guide to graphical projections | Medium](https://medium.com/retronator-magazine/game-developers-guide-to-graphical-projections-with-video-game-examples-part-2-multiview-8e9ad7d9e32f)

### Projection & Camera Techniques
[39] [A Layman's Guide To Projection in Videogames](https://significant-bits.com/a-laymans-guide-to-projection-in-videogames/)
[40] [Perspective in 2D Games (Cornell)](https://www.cs.cornell.edu/courses/cs3152/2020sp/lectures/15-Perspective.pdf)

### Touch Bar Hardware & Projects
[41] [loretoparisi/touchbar: NSTouchBar Cheatsheet and Swift examples](https://github.com/loretoparisi/touchbar)
[42] [touchbar GitHub Topics](https://github.com/topics/touchbar)
[43] [touch-bar-simulator | GitHub](https://github.com/sindresorhus/touch-bar-simulator)

### Primary Source
[44] `docs/archive/3D-RENDERING-RESEARCH.md` (full source document, compiled 2026-03-15)
