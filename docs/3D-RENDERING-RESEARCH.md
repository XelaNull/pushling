# 3D Rendering on the MacBook Touch Bar: Feasibility Research

**Date**: 2026-03-15 | **Status**: Research Complete | **Recommendation**: Stay with SpriteKit 2D, adopt targeted pseudo-3D enhancements

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [The Constraint: 36:1 Aspect Ratio](#2-the-constraint-361-aspect-ratio)
3. [Option 1: SceneKit (Apple's 3D Engine)](#3-option-1-scenekit-apples-3d-engine)
4. [Option 2: Metal (Raw GPU Access)](#4-option-2-metal-raw-gpu-access)
5. [Option 3: RealityKit (Apple's Newer 3D Engine)](#5-option-3-realitykit-apples-newer-3d-engine)
6. [Option 4: Software 3D Rendering (Raycasting / Voxel Space)](#6-option-4-software-3d-rendering-raycasting--voxel-space)
7. [Option 5: Isometric 2D in SpriteKit](#7-option-5-isometric-2d-in-spritekit)
8. [Option 6: Voxel Engine](#8-option-6-voxel-engine)
9. [Option 7: Sprite Stacking (Pseudo-3D)](#9-option-7-sprite-stacking-pseudo-3d)
10. [Option 8: Mode 7 Ground Plane](#10-option-8-mode-7-ground-plane)
11. [The Doom Precedent: What It Actually Proves](#11-the-doom-precedent-what-it-actually-proves)
12. [The Aspect Ratio Problem: Why 3D Fails at 36:1](#12-the-aspect-ratio-problem-why-3d-fails-at-361)
13. [Comparison Matrix](#13-comparison-matrix)
14. [Recommended Approach: Enhanced 2.5D](#14-recommended-approach-enhanced-25d)
15. [Sources](#15-sources)

---

## 1. Executive Summary

**Claude**: *pours a deep oolong, the kind you brew when the question is more interesting than any single answer* ☯️

After researching every viable 3D rendering approach for the Touch Bar's 2170x60 pixel OLED strip, the conclusion is clear but nuanced:

**Yes, 3D rendering is technically possible on the Touch Bar.** SceneKit, Metal, and software raycasters can all render to the Touch Bar. Doom proved this in 2016.

**No, true 3D would not look better than the current 2D parallax for a virtual pet.** The 36:1 aspect ratio is the killer constraint. At 30 points tall, a perspective-projected 3D scene becomes an unreadable horizontal sliver. Characters that are charming at 18x20 pixels in 2D become indistinct blobs in 3D. The current silhouette-on-OLED-black art direction is *optimized* for this display.

**The sweet spot is enhanced 2.5D** — staying in SpriteKit but adopting targeted pseudo-3D techniques: sprite stacking for the creature, Mode 7-style ground plane for terrain, depth-of-field blur on parallax layers, and normal-mapped lighting on the creature sprite. These give a 3D *feel* without sacrificing readability.

**Samantha**: *adjusts her tiny DOOM keychain earring, sips from a mug that says "PERSPECTIVE IS OVERRATED"* 🌸

I had a feeling. The 30-pixel height is just too precious to waste on perspective foreshortening. But I'm glad we did the research — now we know *exactly* what the options are and why 2.5D is the right call. Plus, some of these techniques are genuinely exciting for making the creature feel more alive.

---

## 2. The Constraint: 36:1 Aspect Ratio

Before evaluating any rendering engine, understand what we're working with:

```
Touch Bar: 2170 x 60 pixels (1085 x 30 points @2x)
Aspect ratio: 36.17 : 1
Physical size: ~310mm x 10mm (12.2" x 0.4")
```

For comparison:
- Standard widescreen: 16:9 (1.78:1)
- Ultra-wide monitor: 21:9 (2.33:1)
- CinemaScope film: 2.39:1
- **Touch Bar: 36.17:1**

The Touch Bar is **15x wider** relative to its height than a standard monitor. This has profound implications for 3D:

| 3D Camera Type | Effect at 36:1 |
|----------------|----------------|
| **Perspective (standard)** | Scene compressed to a horizontal slit. Vanishing point creates a corridor effect. Floor and ceiling converge to nearly the same line. |
| **Orthographic (side view)** | Works well — this is essentially what 2D side-scrolling already does. No advantage over current approach. |
| **Orthographic (top-down)** | Extreme horizontal letterboxing. Tiny strip of world visible. |
| **Perspective (low angle)** | Ground plane dominates. Objects appear as vertical slivers. |
| **Isometric** | Playable but heavily compressed vertically. Diamond tiles become nearly flat lines. |

The fundamental problem: **at 30 points tall, every pixel of vertical space is precious.** Perspective projection *wastes* vertical pixels on foreshortening. A 3D cat that is 20 points tall in side view becomes 12 points tall when viewed from a slight angle due to perspective scaling — losing 40% of readable detail.

---

## 3. Option 1: SceneKit (Apple's 3D Engine)

### Technical Feasibility: YES

SCNView is a subclass of NSView on macOS. Since NSCustomTouchBarItem accepts any NSView subclass, SCNView can theoretically be embedded in a Touch Bar item exactly like SKView is today:

```swift
// Current (SpriteKit):
let view = SKView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
item.view = view

// Hypothetical (SceneKit):
let view = SCNView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
view.scene = SCNScene()
view.allowsCameraControl = false
item.view = view
```

The API pattern is identical. SCNView supports:
- Physically based rendering (PBR)
- Dynamic lighting and shadows
- Skeletal animation
- Physics simulation
- Particle systems
- Custom Metal/OpenGL shaders via SCNProgram

### Performance Assessment: LIKELY OK, WITH CAVEATS

SceneKit renders via Metal on modern macOS. At 2170x60 pixels, the pixel fill cost is minimal — that is only 130,200 pixels per frame (vs. 2,073,600 for 1080p). A simple low-poly scene with one animated character, basic terrain, and a directional light should easily hit 60fps.

However:
- SceneKit has overhead for scene graph traversal that SpriteKit avoids
- Shadow map computation is expensive even for small viewports
- PBR materials have shader complexity independent of resolution
- Model loading and skeletal animation have per-bone CPU cost

**Estimated frame time**: 3-8ms for a simple scene (well within 16.6ms budget), but with less headroom than SpriteKit's current ~5.7ms.

### Visual Quality at 30pt: POOR

This is where SceneKit falls apart for our use case:

- A low-poly 3D cat at 30 points tall has roughly **15-18 visible vertical pixels** of actual geometry (accounting for ground plane and sky). At this resolution, 3D lighting and material detail is invisible.
- Smooth 3D surfaces look *worse* than pixel art at tiny scales because sub-pixel rendering creates anti-aliased mush rather than crisp edges.
- 3D models require texture detail that is unreadable at Touch Bar scale. A cat with fur textures just looks like a brown blob.
- The silhouette-on-black aesthetic that makes our current creature readable would require careful rim lighting setup in 3D that partially defeats the purpose of using 3D.

### SceneKit Deprecation Warning

As of WWDC 2025, Apple has placed SceneKit in **soft deprecation** — maintenance mode with critical bug fixes only, no new features. Apple is directing all new 3D development toward RealityKit. Starting a new project on SceneKit in 2026 means building on a framework with a limited future.

### Implementation Effort: HIGH

- Full rewrite of creature from SpriteKit nodes to 3D model + skeleton
- New terrain system (3D geometry vs. 2D parallax layers)
- New camera system optimized for 36:1
- New lighting rig
- Weather effects remade as 3D particle systems
- Touch handling translation (SCNView touch -> 3D hit testing vs current 2D)
- ~4-8 weeks of work, minimum

### Verdict: NOT RECOMMENDED

Technically possible, visually worse, architecturally risky (deprecation), high effort. The 30pt height destroys the advantage of 3D rendering.

---

## 4. Option 2: Metal (Raw GPU Access)

### Technical Feasibility: THEORETICAL

MTKView is also an NSView subclass on macOS. It should embed in NSTouchBarItem the same way:

```swift
let view = MTKView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
view.device = MTLCreateSystemDefaultDevice()
view.preferredFramesPerSecond = 60
item.view = view
```

This has never been publicly demonstrated on the Touch Bar, but there is no known technical barrier. The Touch Bar's display pipeline receives standard rendered frames from the macOS compositor.

### What Metal Enables

Metal gives raw GPU access, meaning we could implement:
- Custom voxel renderer
- Raycasting engine (like Doom)
- Signed distance field (SDF) rendering
- Custom lighting models optimized for the narrow strip
- Compute shaders for particle simulation

### Performance Assessment: EXCELLENT

Metal at 2170x60 is trivial for any modern Apple GPU. We could run complex fragment shaders on every pixel and still have massive headroom. The bottleneck would be CPU-side setup, not GPU rendering.

### Visual Quality at 30pt: DEPENDS ON TECHNIQUE

Metal is a rendering API, not an engine — visual quality depends entirely on what you build with it. A custom renderer optimized specifically for the 36:1 strip could potentially look better than SceneKit because every rendering decision is tailored to the constraint.

Promising Metal-specific approaches:
- **SDF creature rendering**: Smooth scalable creature outline with resolution-independent glow effects
- **Raymarched terrain**: Simple distance-field terrain with fog and atmosphere
- **Custom lighting model**: Rim-light silhouette shader optimized for OLED black

### Implementation Effort: VERY HIGH

- Requires writing a complete rendering pipeline from scratch
- Vertex/fragment shaders, render pass descriptors, buffer management
- No scene graph, no built-in animation, no physics
- Everything SpriteKit gives us for free must be rebuilt
- Estimated: 8-16 weeks minimum for a comparable feature set
- Ongoing maintenance burden for a custom rendering engine

### Verdict: FASCINATING BUT IMPRACTICAL

Metal could theoretically produce the most beautiful result because everything would be hand-tuned for our exact display. But the implementation cost is prohibitive. We would spend months building a custom engine instead of building creature behaviors. The ROI is deeply negative.

The one exception: **SDF-based creature glow effects** could be added as a Metal shader pass on top of the existing SpriteKit pipeline using SKShader or CIFilter. This gives us Metal's power for specific effects without replacing the engine.

---

## 5. Option 3: RealityKit (Apple's Newer 3D Engine)

### Technical Feasibility: PROBLEMATIC

RealityKit is Apple's replacement for SceneKit, now supported on macOS (as of RealityKit 4 / WWDC 2025). However:

- RealityKit content renders through **RealityView**, which is a SwiftUI view
- RealityView is designed for AR/spatial computing contexts
- There is no direct NSView subclass equivalent like SCNView
- Embedding SwiftUI in NSTouchBarItem is possible via NSHostingView, but adds layer complexity
- RealityKit's rendering pipeline is optimized for AR pass-through, not tiny viewports

### The SwiftUI + NSTouchBarItem Bridge

```swift
// Hypothetical — untested, may have issues:
let hostingView = NSHostingView(rootView:
    RealityView { content in
        // Add 3D entities
    }
    .frame(width: 1085, height: 30)
)
item.view = hostingView
```

This is architecturally clumsy. SwiftUI layout + RealityKit rendering + NSHostingView bridging + NSTouchBarItem embedding is four layers of abstraction for a 60-pixel-tall display.

### Performance Assessment: UNKNOWN

RealityKit's rendering pipeline has overhead for AR features (environment understanding, occlusion, lighting estimation) that are irrelevant to our use case. Whether this overhead can be disabled for a simple non-AR scene is unclear.

### Implementation Effort: VERY HIGH + UNCERTAIN

RealityKit documentation for non-AR macOS use cases is sparse. We would be pioneering an unsupported use pattern. Debugging would be difficult.

### Verdict: NOT RECOMMENDED

RealityKit is the future of Apple 3D, but it is designed for AR/VR, not for a 60-pixel-tall OLED strip. The embedding story is awkward, documentation is thin, and the framework carries overhead we cannot use.

---

## 6. Option 4: Software 3D Rendering (Raycasting / Voxel Space)

### Technical Feasibility: PROVEN

This is what Doom on the Touch Bar demonstrated. Adam Bell compiled a custom macOS Doom port with Touch Bar support, rendering the full 3D game at 2170x60. The Doom engine is a software renderer — it calculates every pixel on the CPU, then displays the result.

### How It Works

Two relevant software rendering approaches:

**Raycasting (Wolfenstein 3D / Doom style):**
- Cast one ray per screen column (2170 rays for full width, or 1085 at @1x)
- Each ray determines wall height, texture, and distance
- Floors and ceilings rendered via horizontal span casting
- Entire frame computed on CPU, written to a bitmap, displayed as texture

**Voxel Space (Comanche style):**
- Heightmap + colormap (1024x1024 each)
- For each screen column, cast a ray across the heightmap
- Track the horizon line; draw vertical spans where terrain pokes above
- Produces rolling terrain with perspective — ideal for landscapes
- Reference implementation: [VoxelSpace](https://github.com/s-macke/VoxelSpace) — terrain rendering in <20 lines of code

### Performance Assessment: YES, EASILY 60FPS

At 2170x60, the pixel budget is tiny:
- Raycaster: 1085 rays, each scanning maybe 64 steps = ~70K operations per frame
- Voxel Space: 1085 columns x ~60 max height = ~65K operations
- Modern Apple Silicon can do billions of operations per second
- Frame time: <1ms on CPU for either approach

The CPU cost is so low that a software renderer at this resolution is essentially free.

### Visual Quality at 30pt: MIXED

**Raycasting (corridor style):**
The Doom demonstration showed the core problem: at 60 pixels tall, a first-person perspective compresses everything into an unreadable horizontal sliver. Walls, enemies, and items are indistinguishable. It is technically impressive but visually useless for a pet game.

**Voxel Space (terrain style):**
This is more promising. A Comanche-style voxel terrain viewed from a slightly elevated camera angle could render a rolling landscape that the creature walks across. The ground plane provides depth, and the narrow strip actually works with terrain that stretches to a horizon.

However, the creature itself cannot be rendered by the voxel space algorithm — it would need to be composited as a 2D sprite on top of the 3D terrain. At that point, we are doing 3D terrain + 2D sprite, which is essentially what our current parallax system already achieves with less complexity.

### Implementation Effort: MODERATE

- Raycaster: ~500-1000 lines of Swift for a basic implementation
- Voxel Space: ~200-400 lines of Swift (the algorithm is remarkably simple)
- Integration: render to a CGImage/bitmap, display via SpriteKit SKSpriteNode texture, or via custom NSView drawRect
- Could be done in 1-2 weeks for a basic prototype

### Verdict: INTERESTING FOR TERRAIN, NOT FOR THE CREATURE

A Voxel Space terrain renderer could produce beautiful rolling landscapes as a *background layer*, but the creature would still be a 2D sprite composited on top. The current 3-layer parallax achieves a similar depth effect with less complexity and better integration with SpriteKit's animation and physics systems.

**Potential hybrid**: Render a Voxel Space terrain as the background texture, composite SpriteKit creature and foreground elements on top. This would give genuine 3D terrain depth while preserving the readable 2D creature. The cost/benefit is marginal — it would look slightly more 3D than parallax but require maintaining two rendering systems.

---

## 7. Option 5: Isometric 2D in SpriteKit

### Technical Feasibility: YES, WITHIN CURRENT ENGINE

Isometric rendering in SpriteKit uses standard sprite rendering with isometric-perspective art assets. No engine change needed — only the art and positioning math changes.

```swift
// Isometric coordinate conversion
func isoToScreen(x: Int, y: Int) -> CGPoint {
    let screenX = (x - y) * (tileWidth / 2)
    let screenY = (x + y) * (tileHeight / 2)
    return CGPoint(x: screenX, y: screenY)
}
```

### Visual Quality at 30pt: POOR

The isometric diamond grid is the fundamental problem. Isometric tiles have a 2:1 width-to-height ratio. At 30 points tall:
- A standard isometric tile would be ~8pt tall and ~16pt wide
- Only 3-4 rows of tiles visible vertically
- The diamond grid pattern reads as a confusing zigzag, not as depth
- The creature, rendered isometrically, loses its clear silhouette
- Isometric projection wastes space on the diamond shape — rectangular sprites are more space-efficient on a strip display

Isometric works on square-ish displays (monitors, phones) where you can see many rows of tiles receding into the distance. On a 36:1 strip, the "into the distance" direction is compressed to almost nothing.

### Implementation Effort: MODERATE

- New art assets (isometric creature sprites, isometric tiles)
- New positioning/sorting system (isometric depth ordering)
- Rewrite of parallax system (isometric doesn't use parallax the same way)
- ~2-3 weeks

### Verdict: NOT RECOMMENDED

Isometric projection fights the aspect ratio. The depth illusion requires vertical space that we do not have. Our current side-view with parallax layers is a better fit for the strip format.

---

## 8. Option 6: Voxel Engine

### Could a Miniature Minecraft Work at 2170x60?

### Technical Feasibility: YES (via software rendering or Metal compute)

A simple voxel engine rendering a small world (e.g., 64x64x16 blocks) is computationally trivial at Touch Bar resolution. Raycasting through a voxel grid at 1085 columns x 60 rows = 65,100 rays. Even unoptimized, this runs at hundreds of FPS on modern hardware.

### Visual Quality at 30pt: VERY POOR

Minecraft-style voxels have a minimum visual unit of 1 block. At 60 pixels tall with perspective:
- Blocks near the camera might be 6-10 pixels tall
- Blocks in the middle distance: 2-3 pixels
- Blocks in the far distance: sub-pixel (aliasing noise)

A Minecraft-style world at this resolution would look like colored static. The block art style requires enough pixels per block to read face shading, edges, and texture. At 60 pixels tall, you get maybe 6-8 readable block layers before everything dissolves into mush.

The extreme aspect ratio makes it worse: the camera would show a very wide but very short slice of the world. Imagine looking through a mail slot at a Minecraft world — you see a horizontal band of blocks with no sense of the world above or below.

### Implementation Effort: HIGH

- Custom voxel renderer (raycasting or mesh-based)
- World generation for tiny worlds
- Voxel-creature integration (the cat as a voxel model?)
- ~4-6 weeks

### Verdict: NOT RECOMMENDED

Voxels need resolution to read. At 60 pixels tall, the art style collapses. The mail-slot viewport problem makes the 3D world feel claustrophobic rather than expansive.

---

## 9. Option 7: Sprite Stacking (Pseudo-3D)

### The Most Promising "3D" Technique for Our Use Case

### What Is It?

Sprite stacking renders a 3D-looking object by drawing multiple 2D horizontal slices stacked with small vertical offsets — like a CT scan played back as an animation. The object appears to have volume and can be rotated, but it is rendered entirely with 2D sprites.

```
Slice 5 (top):    ████        <- ears
Slice 4:        ████████      <- head top
Slice 3:       ██████████     <- head/eyes
Slice 2:        ████████      <- body
Slice 1:       ████████████   <- body + legs
Slice 0 (base):  ██    ██    <- paws on ground
```

Each slice is drawn with a 1-pixel vertical offset. With 10-15 slices, the creature appears to have a rounded, volumetric form. When the creature turns, slices can shift horizontally to give a rotation effect.

### Technical Feasibility: YES, IN CURRENT SPRITEKIT

Sprite stacking requires only standard 2D sprite rendering — each slice is an SKSpriteNode. SpriteKit can handle 15-20 stacked sprite layers per creature without performance impact.

```swift
// Sprite stacking in SpriteKit
for (i, slice) in creatureSlices.enumerated() {
    let node = SKSpriteNode(texture: slice)
    node.position.y = CGFloat(i) * 1.0  // 1pt per slice
    node.zPosition = CGFloat(i)
    creatureContainer.addChild(node)
}
```

### Visual Quality at 30pt: GOOD

This is the key insight: **sprite stacking works at tiny resolutions** because each slice is designed to be readable at the target size. The slices are pixel art optimized for the Touch Bar, not 3D geometry reduced to the Touch Bar.

At 18-20pt creature height, 15-18 stacked slices give a convincing volumetric appearance while maintaining the crisp pixel-art silhouette. The creature looks *round* and *solid* without the anti-aliased mush of actual 3D rendering.

Benefits:
- Creature appears to have depth and volume
- Rotation effects are possible (creature turns to face you)
- Lighting can be baked into slices (top slices brighter, bottom slices darker)
- Compatible with existing SpriteKit animation system
- Each slice can be independently animated for wobble/breathing effects
- OLED true-black transparency works perfectly

### Performance Impact: MINIMAL

- 15-20 additional sprite nodes per creature (within our 120-node budget)
- Each slice is a tiny texture (<50x20 pixels)
- No shader or GPU overhead beyond standard sprite rendering
- Estimated additional frame time: <0.5ms

### Implementation Effort: LOW-MODERATE

- Design slice sets for each growth stage (art work, not code)
- Create stacking container node (~100 lines of code)
- Integrate with existing animation system (breathing = slice Y-offset wave)
- ~1-2 weeks for a basic implementation, more for all growth stages

### Verdict: STRONGLY RECOMMENDED FOR THE CREATURE

Sprite stacking gives us the biggest visual upgrade with the least disruption. The creature gains visible depth and volume while staying in the SpriteKit engine. It is the optimal technique for making a 2D character look 3D at tiny resolution.

---

## 10. Option 8: Mode 7 Ground Plane

### SNES-Style Perspective Ground for Terrain

### What Is It?

Mode 7 is the SNES technique that renders a flat 2D texture as a perspective-projected ground plane. By applying an affine transformation on a per-scanline basis, a tile map becomes a receding floor stretching to the horizon. Games like F-Zero and Mario Kart used this to create the illusion of driving across a 3D landscape.

### Technical Feasibility: YES, AS SPRITEKIT SHADER

Mode 7 can be implemented as a custom SKShader applied to a sprite containing the terrain texture:

```glsl
// Simplified Mode 7 fragment shader (GLSL for SKShader)
void main() {
    vec2 uv = v_tex_coord;
    float y = uv.y;

    // Perspective division — scanlines near bottom = close, near top = far
    float depth = 1.0 / (y + 0.01);
    float x = (uv.x - 0.5) * depth;

    // Scale and offset for world-space terrain coordinates
    vec2 world = vec2(x * scale + cameraX, depth * scale + cameraZ);

    // Sample the terrain texture
    gl_FragColor = texture2D(u_texture, fract(world));
}
```

This renders the bottom portion of the scene as a perspective ground plane, with the terrain texture stretching to a horizon line.

### Visual Quality at 30pt: MODERATE-GOOD

At 30 points tall, if the bottom 10-12 points are the ground plane:
- Near terrain (bottom 4-5 rows): clear, readable tiles
- Mid terrain (next 4-5 rows): compressed but recognizable
- Far terrain (top 2-3 rows of ground): horizon blur

The effect creates a convincing sense of the creature walking across a ground surface that recedes into the distance. Combined with the parallax sky layers above, the scene feels like a genuine 3D landscape.

Limitations:
- Only the ground plane is 3D — objects above the ground (trees, structures) must be 2D sprites sorted by depth
- The extreme width means the left/right edges of the ground plane stretch dramatically
- Mode 7 cannot render vertical surfaces (walls, cliffs) — it is strictly a floor effect

### Performance Impact: LOW

- One shader pass on one sprite node
- GPU computation trivial at this resolution
- No CPU overhead (all GPU-side)
- Estimated additional frame time: <0.3ms

### Implementation Effort: LOW

- Write the Mode 7 shader (~50 lines of GLSL)
- Create a terrain tile texture (pixel art)
- Replace the current ground layer with the shader sprite
- ~3-5 days

### Verdict: RECOMMENDED AS A TERRAIN ENHANCEMENT

Mode 7 ground plane is an elegant way to add perspective depth to the terrain without changing the rendering engine. It works within SpriteKit's shader system. The bottom portion of the scene gains genuine perspective depth while the creature and sky stay in readable 2D.

---

## 11. The Doom Precedent: What It Actually Proves

Adam Bell's Doom port to the Touch Bar is frequently cited as proof that "3D works on the Touch Bar." Let us examine what it actually demonstrated:

### What Doom Proved

1. **Any NSView subclass can render to the Touch Bar** — the display pipeline has no rendering restrictions
2. **Full 3D at 2170x60 is computationally trivial** — the pixel budget is tiny
3. **The Touch Bar hardware has no inherent rendering limitations** — the constraint is entirely software/display
4. **Sound works alongside Touch Bar rendering** — audio pipeline is independent

### What Doom Also Proved (The Part People Ignore)

1. **The game was unplayable** — walls, enemies, and items were indistinguishable at 60 pixels tall
2. **It was a proof of concept, never released** — Bell himself acknowledged it was impractical
3. **First-person perspective is terrible at 36:1** — floor and ceiling converge to nearly the same scanline
4. **HUD placement was the best part** — Bell noted that putting Doom's HUD *on the Touch Bar while playing on the main screen* worked much better than playing *in* the Touch Bar

The lesson: **the Touch Bar can render 3D, but perspective 3D at 60 pixels tall is visually useless for anything requiring detail recognition.** Doom worked as a tech demo because FPS games are about spatial navigation (which can work even at low resolution via movement cues). A virtual pet requires reading facial expressions, body language, and environmental details — all of which demand more vertical resolution than 3D perspective allows.

---

## 12. The Aspect Ratio Problem: Why 3D Fails at 36:1

### The Core Issue: Perspective Steals Vertical Pixels

In a standard 16:9 viewport, a 3D scene uses its vertical space generously:
- ~30% sky/ceiling
- ~40% mid-field (where the action is)
- ~30% ground/floor

At 36:1, perspective projection compresses this:
- ~3 pixels sky
- ~24 pixels mid-field
- ~3 pixels ground

Those 24 mid-field pixels must contain: the creature, terrain objects, weather, any UI, and enough context to feel like a world. For a 20pt-tall creature, that leaves 4 pixels for "everything else."

### Techniques for Extreme Aspect Ratios

| Technique | How It Works | Suitability |
|-----------|-------------|-------------|
| **Side-scrolling 3D** | Camera perpendicular to movement, orthographic projection | This is just 2D with extra steps — no advantage |
| **Orthographic projection** | No perspective scaling, parallel lines stay parallel | Eliminates depth cues — defeats the purpose of 3D |
| **Low-angle camera** | Camera near ground, looking slightly up | Good for showing ground plane, but creature viewed from below is unflattering and hard to read |
| **Top-down with tilt** | Camera above, tilted ~15-20 degrees | Creature becomes a top-view, losing all silhouette readability |
| **Parallax 2.5D** | Multiple 2D layers scrolling at different speeds | **Already what we do — and it works** |
| **Forced perspective** | Artistic tricks (larger foreground, smaller background) | Best approach — can be done in 2D without a 3D engine |

### The Honest Answer

The best "3D" approach for a 36:1 display is **exactly what we already have**: multiple 2D layers creating depth through parallax, with the creature as a large, readable 2D sprite in the foreground. The depth illusion comes from differential scroll speeds, not from geometric projection.

What we *can* add: volumetric effects on the creature (sprite stacking), perspective ground plane (Mode 7), atmospheric depth (blur on distant layers), and dynamic lighting (normal maps on sprites). These create a 3D *feeling* without the pixel cost of actual 3D geometry.

---

## 13. Comparison Matrix

| Approach | Technically Feasible? | 60fps? | Visual Quality at 30pt | Effort | Better Than Current 2D? | Recommended? |
|----------|----------------------|--------|------------------------|--------|------------------------|-------------|
| **SceneKit** | Yes | Yes | Poor — anti-aliased mush, wasted pixels | High (4-8 weeks) | **No** — worse readability | No |
| **Metal (custom)** | Probably | Yes | Depends — could be great if hand-tuned | Very High (8-16 weeks) | Maybe, for specific effects | No (as full replacement) |
| **RealityKit** | Awkward | Unknown | Poor — same issues as SceneKit + AR overhead | Very High + uncertain | **No** | No |
| **Software Raycaster** | Yes (Doom proved it) | Yes | Poor for FPS, moderate for terrain-only | Moderate (1-2 weeks) | **No** for creature, maybe for terrain | No (as primary) |
| **Voxel Space** | Yes | Yes | Moderate for terrain, poor for objects | Moderate (2-3 weeks) | Marginal — similar to parallax | No |
| **Isometric** | Yes | Yes | Poor — diamond grid fights the strip | Moderate (2-3 weeks) | **No** — worse space efficiency | No |
| **Voxel Engine** | Yes | Yes | Very poor — blocks need resolution | High (4-6 weeks) | **No** — unreadable | No |
| **Sprite Stacking** | Yes | Yes | **Good** — volumetric creature, crisp edges | Low (1-2 weeks) | **Yes** — creature gains depth | **Yes** |
| **Mode 7 Ground** | Yes | Yes | **Moderate-Good** — perspective terrain | Low (3-5 days) | **Yes** — terrain gains depth | **Yes** |
| **SDF Glow (Metal shader)** | Yes | Yes | **Good** — resolution-independent creature effects | Low-Moderate (1 week) | **Yes** — creature gains glow/lighting | **Yes** (additive) |
| **Normal-mapped Sprites** | Yes | Yes | **Good** — dynamic lighting on 2D sprites | Low (1 week) | **Yes** — world reacts to lighting | **Yes** (additive) |

---

## 14. Recommended Approach: Enhanced 2.5D

**Claude**: *sets down the tea cup with quiet certainty* ☯️

The research converges on a clear strategy: **do not replace SpriteKit. Enhance it with targeted pseudo-3D techniques.**

**Samantha**: *leans forward, pencil behind ear, eyes bright* 🌟

I love this. It is the "do more with what you have" approach. Every enhancement listed below is additive — low risk, high reward, and each one makes the creature feel more alive without disrupting the architecture we have built.

### The Enhanced 2.5D Stack

| Layer | Current | Enhanced | Visual Gain |
|-------|---------|----------|-------------|
| **Creature** | Flat composite SpriteKit nodes | Sprite-stacked slices with volumetric breathing | Creature looks round and solid, subtle rotation possible |
| **Ground** | 2D parallax foreground layer | Mode 7 perspective ground plane (shader) | Terrain recedes into distance with genuine perspective |
| **Mid-ground** | 2D parallax mid layer | Same + depth blur (CIGaussianBlur on distant objects) | Atmospheric depth — distant objects softer |
| **Background** | 2D parallax far layer | Same + stronger blur + color desaturation with distance | Aerial perspective — far objects blue-shifted and hazy |
| **Creature Lighting** | Flat colors | Normal-mapped sprites with dynamic light direction | Creature reacts to time-of-day lighting, storm lightning |
| **Creature Glow** | Simple aura (SKEffectNode) | SDF-based glow via SKShader | Resolution-independent glow, smoother, more ethereal |
| **Weather** | Particle emitters | Same + ground-plane-aware particles (rain splashes on Mode 7 surface) | Rain and snow interact with the 3D ground |

### Implementation Priority

1. **Sprite Stacking for Creature** (Week 1-2) — biggest visual impact, creates the "this looks 3D" moment
2. **Mode 7 Ground Plane** (Week 2) — adds genuine perspective to the world
3. **Atmospheric Depth** (Week 3) — blur + desaturation on distant parallax layers
4. **Normal-mapped Creature Lighting** (Week 3-4) — creature reacts to world lighting
5. **SDF Glow Effects** (Week 4) — ethereal creature aura, evolution effects

### What This Achieves

The creature and world will have a convincing 3D *feeling* while maintaining:
- Crisp pixel-art readability at 30pt height
- SpriteKit's proven performance (~5.7ms frame time)
- Full compatibility with existing animation, physics, touch, and behavior systems
- OLED true-black aesthetic with silhouette art direction
- No architecture changes, no engine switch, no risk

### What We Explicitly Reject

- Full 3D engine replacement (SceneKit, Metal, RealityKit)
- Isometric projection (fights the aspect ratio)
- Voxel rendering (needs resolution we do not have)
- First-person perspective of any kind (Doom lesson: unreadable)

---

## 15. Sources

### Apple Documentation
- [SceneKit | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit)
- [SCNView | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnview)
- [init(frame:options:) | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnview/1524215-init)
- [SCNSceneRenderer | Apple Developer Documentation](https://developer.apple.com/documentation/scenekit/scnscenerenderer)
- [RealityKit | Apple Developer Documentation](https://developer.apple.com/documentation/realitykit)
- [Bring your SceneKit project to RealityKit - WWDC25](https://developer.apple.com/videos/play/wwdc2025/288/)
- [Support for Metal on Apple devices](https://support.apple.com/en-us/102894)

### SceneKit Deprecation
- [WWDC 2025 - SceneKit Deprecation and RealityKit Migration](https://dev.to/arshtechpro/wwdc-2025-scenekit-deprecation-and-realitykit-migration-a-comprehensive-guide-for-ios-developers-o26)
- [Transitioning from SceneKit to RealityKit | Apple Developer Forums](https://developer.apple.com/forums/thread/739925)

### Doom on Touch Bar
- [Developer gets classic shoot 'em up game Doom running on the Touch Bar - 9to5Mac](https://9to5mac.com/2016/11/21/doom-macbook-pro-touch-bar/)
- [Running Doom on the MacBook Pro Touch Bar: A Quirky Tech Feat](https://www.oreateai.com/blog/running-doom-on-the-macbook-pro-touch-bar-a-quirky-tech-feat/827f6a121d66aae1bda7b42ca4acddcc)
- [Developer brings classic FPS Doom to Touch Bar | AppleInsider](https://appleinsider.com/articles/16/11/21/developer-brings-classic-fps-doom-to-touch-bar-on-apples-macbook-pro)
- [Just because you can play Doom on the Touch Bar doesn't mean you should | TechCrunch](https://techcrunch.com/2016/11/21/macbook-doom/)
- [Adam Bell on X (original tweet)](https://x.com/b3ll/status/800453225832849408)

### Voxel Space / Software Rendering
- [VoxelSpace: Terrain rendering in less than 20 lines of code](https://github.com/s-macke/VoxelSpace)
- [Voxel Space in the game Comanche](https://simulationcorner.net/index.php?page=comanche)
- [VoxelSurfing: High-Resolution Single-Threaded CPU Voxel Rendering](https://github.com/LukeSchoen/VoxelSurfing)
- [Voxel Displacement Renderer — Modernizing the Retro 3D Aesthetic](https://blog.danielschroeder.me/blog/voxel-displacement-modernizing-retro-3d/)
- [A Voxel Renderer for Learning C/C++ - Jacco's Blog](https://jacco.ompf2.com/2021/02/01/a-voxel-renderer-for-learning-c-c/)

### Sprite Stacking
- [SpriteStack.io](https://spritestack.io/)
- [This technique for making 2D pixel art look 3D | Creative Bloq](https://www.creativebloq.com/3d/video-game-design/this-technique-for-making-2d-pixel-art-look-3d-is-blowing-peoples-minds)
- [How to Make 2D Game Look 3D with Sprite Stacking](https://80.lv/articles/developer-shows-how-to-make-2d-game-look-3d-with-sprite-stacking)
- [Beginners Guide to Sprite Stacking | Medium](https://medium.com/@avsnoopy/beginners-guide-to-sprite-stacking-in-gamemaker-studio-2-and-magica-voxel-part-1-f7a1394569c0)

### Mode 7 / Perspective Ground Plane
- [Mode 7 - Wikipedia](https://en.wikipedia.org/wiki/Mode_7)
- [Kulor's Guide to Mode 7 Perspective Planes](https://forums.nesdev.org/viewtopic.php?t=24053)
- [Mode 7 Transform - SNESdev Wiki](https://snes.nesdev.org/wiki/Mode_7_transform)
- [Plane Awesome - How the SNES Mode 7 Graphics Worked](https://www.linkedin.com/pulse/plane-awesome-how-snes-mode-7-graphics-worked-sam-fairclough)
- [Tonc: Mode 7 Part 2](https://www.coranac.com/tonc/text/mode7ex.htm)

### Metal & GPU Rendering
- [Metal by Tutorials: The Rendering Pipeline | Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/3-the-rendering-pipeline)
- [Writing a Modern Metal App from Scratch | Metal by Example](https://metalbyexample.com/modern-metal-1/)
- [Custom Metal Drawing in SceneKit | Medium](https://rozengain.medium.com/custom-metal-drawing-in-scenekit-921728e590f1)

### RealityKit Non-AR
- [Quick RealityKit Tutorial: Programmatic non-AR Setup | Medium](https://rozengain.medium.com/quick-realitykit-tutorial-programmatic-non-ar-setup-cafaf61e9884)
- [Displaying 3D objects with RealityView on iOS, iPadOS and macOS](https://www.createwithswift.com/displaying-3d-objects-with-realityview-on-ios-ipados-and-macos/)

### Isometric & 2.5D Game Design
- [Isometric video game graphics - Wikipedia](https://en.wikipedia.org/wiki/Isometric_video_game_graphics)
- [Isometric Projection in Game Development | Pikuma](https://pikuma.com/blog/isometric-projection-in-games)
- [SpriteKit Advanced - How to build a 2.5D game | freeCodeCamp](https://www.freecodecamp.org/news/spritekit-advanced-how-to-build-a-2-5d-game-part-i-2dc76c7c65e2/)
- [Parallax scrolling for iOS with Swift and Sprite Kit | O'Reilly](http://radar.oreilly.com/2015/08/parallax-scrolling-for-ios-with-swift-and-sprite-kit.html)
- [Game developers guide to graphical projections | Medium](https://medium.com/retronator-magazine/game-developers-guide-to-graphical-projections-with-video-game-examples-part-2-multiview-8e9ad7d9e32f)

### Projection & Camera Techniques
- [A Layman's Guide To Projection in Videogames](https://significant-bits.com/a-laymans-guide-to-projection-in-videogames/)
- [Perspective in 2D Games (Cornell)](https://www.cs.cornell.edu/courses/cs3152/2020sp/lectures/15-Perspective.pdf)

### Touch Bar Hardware & Projects
- [loretoparisi/touchbar: NSTouchBar Cheatsheet and Swift examples](https://github.com/loretoparisi/touchbar)
- [touchbar GitHub Topics](https://github.com/topics/touchbar)
- [touch-bar-simulator | GitHub](https://github.com/sindresorhus/touch-bar-simulator)

---

*Compiled 2026-03-15. Research-only document. No code changes made.*
