# Graphics Overhaul Plan: From Geometry to Recognition + Depth

**Status**: PLAN (not yet implemented)
**Created**: 2026-03-15
**Goal**: Every visual element should be instantly recognizable AND the world should feel three-dimensional

---

## The Problems

### Problem 1: Flat Geometry
The entire visual system is built from basic geometric primitives (SKShapeNode):
- A **campfire** is a triangle colored orange
- A **ball** is a circle colored cyan
- A **tree** is a triangle colored green
- A **fish** is a flat disc colored cyan
- A **bed** is a rounded rectangle colored purple
- **Landmarks** are all gray silhouettes of basic shapes

### Problem 2: No Depth
The world is completely flat despite having 3-layer parallax infrastructure:
- Mountains are a **single 2D gray polygon** in the foreground only
- The far and mid parallax layers contain **no terrain** (despite being designed for it)
- Objects have a `layer` property stored in SQLite but it's **never used for rendering** — everything goes to foreground
- The creature moves **only in X** with no depth axis
- Nothing scales by distance — no perspective, no atmospheric depth
- The result: a flat paper diorama, not a living world

---

## Design Principles

1. **Recognize in <200ms** — A glance at the Touch Bar should register "campfire," not "orange triangle"
2. **Silhouette-first** — At this scale, silhouette is king. If it reads in solid black, it reads at any color
3. **Depth through layers** — Use the existing 3-layer parallax (far/mid/fore) to create real spatial depth
4. **Scale = distance** — Objects closer to camera are larger. Objects farther away are smaller
5. **Stay on-palette** — All 8 P3 colors remain. Depth comes from alpha blending and color shifting
6. **Composite shapes** — Build recognizable objects from 2-4 simple shapes, not single primitives
7. **Motion sells it** — A campfire with flickering flames reads better than a perfectly-drawn static one
8. **Node budget** — Stay under 120 total nodes. LOD culling keeps distant objects hidden

---

## Phase 0: Depth System (NEW)

### Priority: CRITICAL — This transforms the entire world from 2D to 2.5D

The depth system adds a Z-axis (near/far) to the creature and world. It uses three complementary techniques:

### 0A. Multi-Layer Mountain Ranges

**Current state**: Mountains are a single ash-colored polygon on the foreground layer.
**Target**: 3 overlapping mountain silhouettes across all parallax layers, creating genuine depth.

#### Mountain Layer Design

| Layer | Scroll | Height | Color | Alpha | Character |
|-------|--------|--------|-------|-------|-----------|
| **Far** (background) | 0.15x | 60% of heightmap | `ash` lerp `void` at 0.4 | 0.5 | Distant, dark, smooth peaks |
| **Mid** (middle) | 0.4x | 80% of heightmap | `ash` | 0.7 | Mid-distance, moderate detail |
| **Fore** (foreground) | 1.0x | 100% of heightmap | `ash` lerp `bone` at 0.15 | 1.0 | Close, brightest, full detail |

#### Implementation: `TerrainRecycler` Changes

For the **mountains biome** (and partially for forest/desert), generate terrain polygons on all three parallax layers:

1. **Far-layer terrain** (new):
   - Use same noise seed but with **fewer octaves** (1 instead of 3) for smoother, rounder peaks
   - Reduce height to 60% of foreground amplitude
   - Offset X by +50pt so peaks don't perfectly align (creates overlap)
   - Color: dark ash (ash blended 40% toward void) at 50% alpha
   - Attach to `ParallaxSystem.farLayer` — scrolls at 0.15x speed
   - **Lower sample resolution**: 1 sample per 8pt (vs 2pt for foreground) — softer silhouette

2. **Mid-layer terrain** (new):
   - Use same seed with **2 octaves** (moderate detail)
   - Reduce height to 80% of foreground
   - Offset X by +25pt
   - Color: pure ash at 70% alpha
   - Attach to `ParallaxSystem.midLayer` — scrolls at 0.4x speed

3. **Fore-layer terrain** (existing, enhanced):
   - Keep current 3-octave noise at full amplitude
   - Brighten slightly: ash blended 15% toward bone
   - Full alpha, full detail
   - Add **highlight stroke** on left-facing slopes (1pt bone line at 20% alpha) for directional light

#### Visual Result
When the creature walks, three overlapping mountain ranges scroll at different speeds. The far peaks barely move, the mid peaks drift gently, and the foreground mountains scroll past. **This alone will make the world feel 3D.**

#### Node Cost: +2 terrain polygons per visible chunk (far + mid). With 3-4 visible chunks, that's +6-8 nodes.

---

### 0B. Creature Depth Movement & Perspective Scaling

**Current state**: Creature moves only in X. Fixed size per growth stage.
**Target**: Creature can walk toward/away from camera, scaling larger (near) or smaller (far).

#### Depth Axis Design

- New `positionZ` property on creature: range **0.0** (far) to **1.0** (near)
- Default resting depth: **0.5** (middle)
- Depth affects three visual properties simultaneously:

| Depth | Scale | Y-Position | Visual Effect |
|-------|-------|------------|---------------|
| 0.0 (far) | 0.7x | Y = groundY + 4pt (higher) | Small, distant, slightly transparent (alpha 0.85) |
| 0.5 (rest) | 1.0x | Y = groundY (normal) | Normal size, normal position |
| 1.0 (near) | 1.25x | Y = groundY - 1pt (lower) | Large, close, fully opaque |

#### Scale Formula
```
depthScale = 0.7 + (positionZ * 0.55)  // 0.7x at far, 1.25x at near
yOffset = (0.5 - positionZ) * 8.0       // +4pt at far, -1pt at near
alphaFade = 0.85 + (positionZ * 0.15)   // 0.85 at far, 1.0 at near
```

#### Integration with Breathing
Breathing applies yScale post-process: `finalYScale = depthScale * breathScale`
The depth scale multiplies with breathing, not replaces it. Creature still breathes at all depths.

#### Implementation: ~150 lines across 5 files

| File | Change |
|------|--------|
| `Behavior/LayerTypes.swift` | Add `positionZ: CGFloat?` to `LayerOutput` |
| `Behavior/PhysicsLayer.swift` | Add `currentZ: CGFloat` (0.5 default), pass through to output |
| `Behavior/BlendController.swift` | Interpolate `currentDepth` like `currentPosition.x` |
| `Scene/PushlingScene.swift` | In `applyBehaviorOutput()`: apply depth scale + Y offset + alpha |
| `IPC/ActionHandlers.swift` | Add `depth` parameter to move commands |

#### MCP Tool Update
```
pushling_move(action: "walk", target: "right", depth: 0.8)
pushling_move(action: "approach", depth: 1.0)  // Walk toward camera
pushling_move(action: "retreat_depth", depth: 0.0)  // Walk into distance
```

#### Autonomous Behaviors
The autonomous layer should occasionally vary depth:
- **Wandering**: Gentle depth oscillation (0.3-0.7 range, slow sine wave)
- **Curious**: Approaches camera (depth → 0.8) when noticing activity
- **Shy/Sleepy**: Retreats to distance (depth → 0.2) to curl up
- **Zoomies**: Rapid depth changes as creature runs "around" the space

---

### 0C. Object Depth (Wire the Existing Layer Property)

**Current state**: Objects have a `layer` field in `WorldObjectDefinition` ("far", "mid", "fore") but ALL objects render on the foreground layer regardless.
**Target**: Objects actually render on their assigned parallax layer with appropriate scaling.

#### Implementation

In `WorldObjectRenderer.createObject()`, instead of always attaching to `foreLayer`:

```swift
switch definition.layer {
case "far":
    node.setScale(node.xScale * 0.5)   // Half size (distant)
    node.alpha *= 0.6                    // Atmospheric fade
    farLayer?.addChild(node)
case "mid":
    node.setScale(node.xScale * 0.75)  // 3/4 size
    node.alpha *= 0.8
    midLayer?.addChild(node)
default:
    foreLayer?.addChild(node)           // Full size, full alpha
}
```

#### Object Layer Assignment Rules
- **Foreground** (interactive): campfire, ball, yarn_ball, cozy_bed, cardboard_box, scratching_post, music_box, treat, fresh_fish, milk_saucer
- **Mid-layer** (decorative): tree, fountain, bench, flag, rock (large)
- **Far-layer** (atmospheric): tree (small/distant), rock (distant), flower (distant clusters)

Objects that the creature interacts with MUST stay on foreground. Decorative objects create depth by existing on background layers.

#### Proximity Adjustment
`ObjectInteractionEngine` currently uses X-distance only. For multi-layer objects, only foreground objects are interactable. Mid/far objects are purely decorative — no proximity check needed.

---

### 0D. Atmospheric Perspective

**Current state**: All objects same color intensity regardless of distance.
**Target**: Distant elements are desaturated/transparent, near elements are vivid.

#### Rules
- **Far layer**: All colors blended 30% toward `ash` (desaturation) + alpha × 0.6
- **Mid layer**: All colors blended 15% toward `ash` + alpha × 0.8
- **Fore layer**: Full saturation, full alpha
- **Creature at depth 0.0**: Blended 15% toward ash, alpha 0.85
- **Creature at depth 1.0**: Full saturation, full alpha

This requires a simple color utility:
```swift
func atmosphericColor(_ base: NSColor, layer: ParallaxLayer) -> NSColor {
    let desaturation: CGFloat = layer == .far ? 0.3 : (layer == .mid ? 0.15 : 0.0)
    return PushlingPalette.lerp(base, PushlingPalette.ash, t: desaturation)
}
```

---

### 0E. Dynamic Z-Ordering by Depth

When the creature moves in depth, its `zPosition` should change:
```swift
creature.zPosition = 10 + (currentDepth * 20)  // 10 at far, 30 at near
```

This ensures the creature renders in front of foreground objects when very close, and behind some objects when far. Combined with scaling, this completes the 3D illusion.

---

## Phase 1: World Objects (20 Presets)

### Priority: CRITICAL — These are the most visually broken elements

Each object currently maps to a single shape. The fix: **composite multi-node constructions** that create recognizable silhouettes using 2-5 shapes each.

### Object-by-Object Redesign

#### CAMPFIRE (currently: triangle + ember glow)
**Target silhouette**: Logs crossed at base, flames rising above
- **Base**: Two small crossed rectangles (1x4pt each, rotated +/-30deg) in `ash` — the logs
- **Flames**: 3 teardrop/pointed-ellipse shapes stacked vertically in `ember`, decreasing size (3pt, 2pt, 1pt tall), with subtle Y-offset animation (+/-0.5pt sine wave at different phases) for flickering
- **Ember particles**: 2-3 tiny 0.5pt circles that float upward slowly and fade (existing glow system)
- **Glow**: Existing glow circle underneath in `ember` at low alpha
- **Nodes**: 7 (2 logs + 3 flames + 1 glow + 1 container)

#### BALL / YARN BALL (currently: circle)
**Target silhouette**: Sphere with visible cross-hatching or yarn lines
- **Ball**: Circle remains, add 2 curved line strokes across surface (quarter-arcs) in slightly darker shade
- **Yarn ball variant**: Add a small trailing line (2pt) curving away — the loose yarn end
- **Animation**: Existing bob effect, plus slow rotation of surface lines
- **Nodes**: 3-4

#### TREE (currently: triangle + moss)
**Target silhouette**: Trunk + rounded canopy (NOT a triangle)
- **Trunk**: Thin rectangle (1.5x3pt) in `ash` (bark)
- **Canopy**: Overlapping 2-3 circles (3pt, 2.5pt, 2pt radius) as cloud-like cluster in `moss`
- **Variant**: Slightly offset circles for organic, non-symmetric look
- **Nodes**: 4-5

#### FLOWER (currently: star_shape + ember)
**Target silhouette**: Stem + petals radiating from center
- **Stem**: Thin line (0.5x3pt) in `moss`
- **Center**: Small circle (0.8pt) in `gilt` (pollen)
- **Petals**: 4-5 tiny ellipses (1x0.5pt) radiating around center in `ember`
- **Leaf**: One tiny ellipse on stem in `moss`
- **Nodes**: 7-8 but all tiny

#### MUSHROOM (currently: dome + ember)
**Target silhouette**: Stem + rounded cap with spots
- **Stem**: Small rectangle (1x2pt) in `bone`
- **Cap**: Semi-circle (2.5pt radius) on top in `ember`
- **Spots**: 2-3 tiny circles (0.3pt) on cap in `bone` — classic toadstool
- **Nodes**: 5-6

#### COZY BED (currently: dome + dusk)
**Target silhouette**: Cushion with raised edges (pet bed shape)
- **Base cushion**: Rounded rectangle (6x2pt) in `dusk`
- **Raised rim**: Slightly larger rounded rectangle behind (7x2.5pt) in darker dusk
- **Pillow**: Small circle (1.5pt) at one end in `bone`
- **Nodes**: 3

#### SCRATCHING POST (currently: pillar + bone)
**Target silhouette**: Vertical post with platform on top
- **Post**: Rectangle (1.5x6pt) in `bone` with horizontal strokes (3-4 thin lines) in `ash`
- **Platform**: Small rectangle (4x1pt) on top in `ash`
- **Base**: Rectangle (3x1pt) at bottom in `ash`
- **Nodes**: 5-6

#### CARDBOARD BOX (currently: box + bone)
**Target silhouette**: Open-top box with flaps
- **Box body**: Rectangle (5x4pt) in `bone`
- **Flaps**: Two small triangles at top corners, angled outward in `bone` (darker stroke)
- **Shadow line**: Dark stroke along bottom in `ash`
- **Nodes**: 4

#### FRESH FISH (currently: disc + tide)
**Target silhouette**: Fish body with tail fin and eye
- **Body**: Ellipse (3x1.5pt) in `tide`
- **Tail**: Small triangle (1.5x1pt) at back in `tide`
- **Eye**: Tiny circle (0.3pt) near front in `void`
- **Nodes**: 3

#### MILK SAUCER (currently: disc + bone)
**Target silhouette**: Shallow dish with visible liquid
- **Saucer**: Ellipse (4x1pt) in `bone`
- **Milk surface**: Slightly smaller ellipse inside (3x0.5pt) at higher alpha
- **Rim highlight**: Thin arc stroke on top edge
- **Nodes**: 3

#### TREAT (currently: sphere + gilt)
**Target silhouette**: Small star or bone shape
- **Shape**: Tiny bone-shaped (dumbbell) or star in `gilt`
- **Sparkle**: Occasional 0.3pt flash particle
- **Nodes**: 2

#### CRYSTAL (currently: diamond + dusk + glow)
**Target silhouette**: Faceted gem with internal light
- **Body**: Keep diamond, add internal vertical stroke in lighter `dusk` for facets
- **Glow**: Keep existing, subtle color shift between `dusk` and `tide`
- **Nodes**: 3

#### LANTERN (currently: diamond + gilt + glow)
**Target silhouette**: Hanging lantern with visible light
- **Frame**: Small rectangle (2x3pt) outline in `ash` (the cage)
- **Light**: Circle (1pt) inside in `gilt` with glow
- **Handle**: Small arc on top in `ash`
- **Nodes**: 4

#### MUSIC BOX (currently: box + gilt)
**Target silhouette**: Box with open lid and floating note
- **Box**: Rectangle (3x2pt) in `gilt`
- **Lid**: Rectangle on top, rotated 15deg open, in darker `gilt`
- **Note**: Musical note shape floating above in `bone`, with bob animation
- **Nodes**: 4

#### LITTLE MIRROR (currently: disc + bone)
**Target silhouette**: Oval mirror with handle
- **Mirror face**: Ellipse (2x3pt) in `bone` at high alpha
- **Frame**: Same ellipse as stroke in `ash`
- **Handle**: Rectangle (0.5x1.5pt) below in `ash`
- **Nodes**: 3

#### FOUNTAIN (currently: dome + tide)
**Target silhouette**: Basin with water arc
- **Basin**: Semi-circle (3pt radius) in `ash`
- **Water arc**: Curved path rising from center, falling to sides in `tide`
- **Droplets**: 1-2 tiny circles (0.3pt) in `tide` falling from peaks
- **Nodes**: 4-5

#### ROCK (currently: dome + ash)
**Target silhouette**: Irregular boulder
- **Shape**: Irregular polygon path (5-6 points, slightly randomized) in `ash`
- **Highlight**: Light line segment on top for dimensionality
- **Nodes**: 2

#### FLAG (currently: pillar + ember)
**Target silhouette**: Pole with waving flag
- **Pole**: Thin rectangle (0.5x6pt) in `ash`
- **Flag**: Rectangle (3x2pt) at top in `ember`, with sway animation
- **Nodes**: 2

#### BENCH (currently: box + ash)
**Target silhouette**: Park bench with legs and back
- **Seat**: Rectangle (6x1pt) in `ash`
- **Legs**: Two thin rectangles at ends (0.5x2pt) in `ash`
- **Back**: Rectangle (6x2pt) above seat in lighter `ash`
- **Nodes**: 4

---

## Phase 2: Creature Improvements

### Priority: MEDIUM — Creature reads well from Critter+, but early stages need work

#### SPORE Stage — Add Proto-Cat Hints
**Current**: Plain circle with faint eyes
- Add two tiny bumps at top suggesting ear nubs (modify circle path)
- Make eyes larger (0.7pt instead of 0.5pt)
- Add very faint tail nub (1pt line) at bottom-back
- **Goal**: Even as a spore, the silhouette whispers "cat"

#### DROP Stage — Add Ear Points to Silhouette
**Current**: Teardrop with eyes, no cat features
- Modify teardrop path: pointed top becomes two points (ear buds emerging)
- Increase eye size slightly (1.2pt)
- Add faintest tail curve suggestion (0.5pt, 20% alpha)
- **Goal**: "Wait... is that a cat? Those look like ears..."

#### CRITTER Stage — Add Whisker Stubs
**Current**: Full cat but no whiskers until Beast
- Add 2 short whiskers per side (3pt length, very thin)
- Whiskers are a primary cat identifier at small scale

#### APEX Stage — Multi-Tail (1-9 based on repos tracked)
- Query repo count from state database
- Render N tails fanned from tail attach point (+/-0.3 rad spread)
- Each tail sways at slightly different phase
- At 9 tails: kitsune-like mythical appearance

#### ALL STAGES — Animate Decorative Elements
- Third eye (Sage): alpha pulse 0.15-0.35, 4s period
- Crown stars (Apex): individual twinkle (staggered sine waves)
- Core glow: subtle color drift between `tide` and `gilt` over 60s

---

## Phase 3: Landmarks

### Priority: LOW-MEDIUM — Background elements that should be identifiable

All 9 landmark types are the same `ash` color. Add color accents and improve silhouettes:

| Landmark | Improved Silhouette | Color Accent |
|----------|-------------------|--------------|
| Neon Tower | Vertical line + stacked window rectangles | `tide` glow at antenna |
| Fortress | Crenellated top edge (castle battlements) | `ash` monochrome |
| Obelisk | Thin point + base step | `bone` tip highlight |
| Crystal | Multi-faceted path (more angles) | `dusk` inner glow |
| Smoke Stack | Cylinder + wider top rim | `ember` smoke particles |
| Observatory | Dome + base + tiny telescope point | `gilt` star on dome |
| Scroll Tower | Spiral/scroll curl at top | `bone` scroll detail |
| Windmill | Spinning blades + body rectangle | `moss` on blades |
| Monolith | Slightly tapered (narrower at top) | Pure `ash` |

---

## Phase 4: Weather & Atmosphere Polish

### Priority: LOW — Already well-implemented, minor improvements

- **Rain**: Make droplets teardrop-shaped paths instead of rectangles
- **Snow**: Vary flake sizes (0.5-1.5pt) for depth. Larger = closer. Rare 2pt "feature flake"
- **Lightning**: Already good. No changes.
- **Fog**: Already good. No changes.
- **Fireflies**: Add 1-frame afterimage trail at 30% alpha for gentle streaking

---

## Phase 5: Texture Atlas Swap (Future)

### Priority: DEFERRED — Architecture ready, art assets needed

1. Create pixel art sprite sheets for each growth stage (6 sheets)
2. Create object sprite sheets (20 objects x states)
3. Replace `SKShapeNode` with `SKSpriteNode` in factories
4. Keep all controller interfaces identical
5. Target: 8x8 to 16x16 pixel sprites at @2x, nearest-neighbor filtering

---

## Implementation Order

| # | Phase | Scope | Impact | Node Cost |
|---|-------|-------|--------|-----------|
| **0A** | Multi-layer mountains | 3 terrain layers across parallax | **TRANSFORMATIVE** | +6-8 |
| **0B** | Creature depth movement | Z-axis + perspective scaling | **TRANSFORMATIVE** | +0 (scale only) |
| **0C** | Object depth layering | Wire existing layer property | **HIGH** | +0 (redistribution) |
| **0D** | Atmospheric perspective | Color desaturation by distance | **MEDIUM** | +0 (color only) |
| **0E** | Dynamic Z-ordering | Creature zPosition by depth | **MEDIUM** | +0 |
| **1** | World objects | 20 composite redesigns | **HIGH** | +40-60 |
| **2a** | Creature early stages | Spore/Drop ear hints | **HIGH** | +2-4 |
| **2b** | Creature Apex tails | Multi-tail system | **MEDIUM** | +1-8 |
| **2c** | Creature polish | Whiskers, animated decorations | **LOW** | +4-6 |
| **3** | Landmarks | 9 silhouette improvements | **LOW-MEDIUM** | +9-18 |
| **4** | Weather polish | Rain/snow/firefly tweaks | **LOW** | +0 |

**Total estimated node increase**: ~62-104 nodes. LOD culling keeps active count under 120.

---

## Key Files to Modify

### Depth System (Phase 0)
| File | Changes |
|------|---------|
| `World/TerrainRecycler.swift` | Generate far/mid terrain polygons with reduced detail |
| `World/TerrainGenerator.swift` | Add octave-count parameter for layer-specific generation |
| `World/ParallaxSystem.swift` | Expose layer references for terrain attachment |
| `World/WorldManager.swift` | Orchestrate multi-layer terrain setup |
| `Behavior/LayerTypes.swift` | Add `positionZ` to `LayerOutput` |
| `Behavior/PhysicsLayer.swift` | Add `currentZ` tracking |
| `Behavior/BlendController.swift` | Interpolate depth like X-position |
| `Behavior/AutonomousLayer.swift` | Add depth wandering behaviors |
| `Scene/PushlingScene.swift` | Apply depth scale + Y offset + alpha in `applyBehaviorOutput()` |
| `IPC/ActionHandlers.swift` | Add `depth` parameter to move commands |
| `World/WorldObjectRenderer.swift` | Route objects to correct parallax layer based on `layer` field |
| `World/PushlingPalette.swift` | Add `atmosphericColor()` helper |

### Visual Overhaul (Phases 1-4)
| File | Changes |
|------|---------|
| `World/ObjectShapeFactory.swift` | Replace single-shape builders with composite multi-node builders |
| `IPC/WorldHandlers.swift` | Update preset map if shape names change |
| `Creature/StageRenderer.swift` | Modify Spore/Drop paths, Critter whiskers, Apex multi-tail |
| `Creature/ShapeFactory.swift` | New ear-nub path for Spore/Drop |
| `World/LandmarkSystem.swift` | Improved silhouettes and color accents |
| `World/RainRenderer.swift` | Teardrop-shaped droplets |
| `World/SnowRenderer.swift` | Variable flake sizes |
| `World/VisualEventBuilders.swift` | Firefly trail effect |

---

## Success Criteria

### Object Recognition
- [ ] Show Touch Bar screenshot to someone unfamiliar with project
- [ ] Ask them to identify each visible object
- [ ] **Pass**: >80% correct identification without hints
- [ ] **Fail**: <60% or "I see shapes and dots"

### Depth Perception
- [ ] Creature walking toward camera is noticeably larger
- [ ] Creature walking away is noticeably smaller
- [ ] Mountain ranges visually overlap and scroll at different speeds
- [ ] Moving the creature across the world, the mountains create a parallax depth sensation
- [ ] Objects on mid/far layers feel "behind" foreground objects
- [ ] **Pass**: Someone says "it feels 3D" or "it has depth"
- [ ] **Fail**: Someone says "it's flat" or "everything is on the same plane"
