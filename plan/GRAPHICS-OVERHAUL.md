# Graphics Overhaul Plan: From Geometry to Recognition

**Status**: PLAN (not yet implemented)
**Created**: 2026-03-15
**Goal**: Every visual element should be instantly recognizable at a glance on a 30pt-tall OLED strip

---

## The Problem

The entire visual system is built from basic geometric primitives (SKShapeNode):
- A **campfire** is a triangle colored orange
- A **ball** is a circle colored cyan
- A **tree** is a triangle colored green
- A **fish** is a flat disc colored cyan
- A **bed** is a rounded rectangle colored purple
- **Landmarks** are all gray silhouettes of basic shapes

This worked as scaffolding, but these shapes don't evoke what they represent. On a 30pt strip where every pixel matters, we need objects that read instantly as what they are.

---

## Design Principles

1. **Recognize in <200ms** — A glance at the Touch Bar should immediately register "campfire," not "orange triangle"
2. **Silhouette-first** — At this scale, silhouette is king. If the shape reads correctly in solid black, it'll read at any color
3. **Stay on-palette** — All 8 P3 colors remain. No new colors. Improvement comes from *shape*, *composition*, and *animation*
4. **Composite shapes** — Build recognizable objects from 2-4 simple shapes composed together, not single primitives
5. **Motion sells it** — A campfire with flickering particles reads better than a perfectly-drawn static campfire
6. **Node budget** — Stay under 120 total nodes. Each object gets 2-5 nodes max
7. **No texture atlas yet** — All improvements use SpriteKit shape composition. Texture swap is a future phase

---

## Phase 1: World Objects (20 Presets)

### Priority: CRITICAL — These are the most visually broken elements

Each object currently maps to a single shape. The fix: **composite multi-node constructions** that create recognizable silhouettes using 2-5 shapes each.

### Object-by-Object Redesign

#### CAMPFIRE (currently: triangle + ember glow)
**Target silhouette**: Logs crossed at base, flames rising above
- **Base**: Two small crossed rectangles (1×4pt each, rotated ±30°) in `ash` — the logs
- **Flames**: 3 teardrop/pointed-ellipse shapes stacked vertically in `ember`, decreasing size (3pt, 2pt, 1pt tall), with subtle Y-offset animation (±0.5pt sine wave at different phases) for flickering
- **Ember particles**: 2-3 tiny 0.5pt circles that float upward slowly and fade (existing glow system)
- **Glow**: Existing glow circle underneath in `ember` at low alpha
- **Nodes**: 7 (2 logs + 3 flames + 1 glow + 1 container) — worth the budget for the most iconic object

#### BALL / YARN BALL (currently: circle)
**Target silhouette**: Sphere with visible cross-hatching or yarn lines
- **Ball**: Circle remains, but add 2 curved line strokes across surface (quarter-arcs) in slightly darker shade to suggest roundness/yarn texture
- **Yarn ball variant**: Add a small trailing line (2pt) curving away from the ball — the loose yarn end
- **Animation**: Existing bob effect, plus slow rotation of the surface lines
- **Nodes**: 3-4

#### TREE (currently: triangle + moss)
**Target silhouette**: Trunk + rounded canopy (not a triangle — trees aren't triangles)
- **Trunk**: Thin rectangle (1.5×3pt) in `ash` (bark)
- **Canopy**: Overlapping 2-3 circles (3pt, 2.5pt, 2pt radius) arranged as a cloud-like cluster on top, in `moss`
- **Variant**: Slightly offset circles for organic, non-symmetric look
- **Nodes**: 4-5

#### FLOWER (currently: star_shape + ember)
**Target silhouette**: Stem + petals radiating from center
- **Stem**: Thin line (0.5×3pt) in `moss`
- **Center**: Small circle (0.8pt) in `gilt` (pollen)
- **Petals**: 4-5 tiny ellipses (1×0.5pt) radiating around center in `ember`
- **Leaf**: One tiny ellipse on stem in `moss`
- **Nodes**: 7-8 but all tiny

#### MUSHROOM (currently: dome + ember)
**Target silhouette**: Stem + rounded cap
- **Stem**: Small rectangle (1×2pt) in `bone`
- **Cap**: Semi-circle or dome (2.5pt radius) on top in `ember`
- **Spots**: 2-3 tiny circles (0.3pt) on cap in `bone` — classic toadstool
- **Nodes**: 5-6

#### COZY BED (currently: dome + dusk)
**Target silhouette**: Cushion with raised edges (pet bed shape)
- **Base cushion**: Rounded rectangle (6×2pt) in `dusk`
- **Raised rim**: Slightly larger rounded rectangle behind (7×2.5pt) in darker `dusk` (dusk lerp void 0.2)
- **Pillow**: Small circle (1.5pt) at one end in `bone`
- **Nodes**: 3

#### SCRATCHING POST (currently: pillar + bone)
**Target silhouette**: Vertical post with platform on top
- **Post**: Rectangle (1.5×6pt) in `bone` with horizontal line strokes (3-4 thin lines across) suggesting rope/scratches in `ash`
- **Platform**: Small rectangle (4×1pt) on top in `ash`
- **Base**: Rectangle (3×1pt) at bottom in `ash`
- **Nodes**: 5-6 (post + stripes + platform + base)

#### CARDBOARD BOX (currently: box + bone)
**Target silhouette**: Open-top box with flaps
- **Box body**: Rectangle (5×4pt) in `bone`
- **Flaps**: Two small triangles at top corners, slightly angled outward in `bone` (darker stroke)
- **Shadow line**: Dark stroke along bottom edge in `ash`
- **Nodes**: 4

#### FRESH FISH (currently: disc + tide)
**Target silhouette**: Fish shape with tail fin
- **Body**: Ellipse (3×1.5pt) in `tide`
- **Tail**: Small triangle (1.5×1pt) attached at back in `tide`
- **Eye**: Tiny circle (0.3pt) near front in `void`
- **Nodes**: 3

#### MILK SAUCER (currently: disc + bone)
**Target silhouette**: Shallow dish with visible liquid
- **Saucer**: Ellipse (4×1pt) in `bone`
- **Milk surface**: Slightly smaller ellipse inside (3×0.5pt) in `bone` at higher alpha
- **Rim highlight**: Thin arc stroke on top edge
- **Nodes**: 3

#### TREAT (currently: sphere + gilt)
**Target silhouette**: Small star or bone shape
- **Shape**: Replace circle with tiny bone shape (dumbbell) or star in `gilt`
- **Sparkle**: Occasional 0.3pt flash particle
- **Nodes**: 2

#### CRYSTAL (currently: diamond + dusk + glow)
**Target silhouette**: Faceted gem with internal light
- **Body**: Keep diamond shape but add internal line (vertical center stroke) in lighter `dusk` to suggest facets
- **Glow**: Keep existing, maybe add subtle color shift between `dusk` and `tide`
- **Nodes**: 3

#### LANTERN (currently: diamond + gilt + glow)
**Target silhouette**: Hanging lantern with visible light
- **Frame**: Small rectangle (2×3pt) outline in `ash` (the cage)
- **Light**: Circle (1pt) inside in `gilt` with glow
- **Handle**: Small arc on top in `ash`
- **Nodes**: 4

#### MUSIC BOX (currently: box + gilt)
**Target silhouette**: Box with visible lid/mechanism
- **Box**: Rectangle (3×2pt) in `gilt`
- **Lid**: Rectangle on top, slightly open (rotated 15°) in `gilt` (darker)
- **Note**: Tiny musical note shape (circle + stem) floating above in `bone`, with bob animation
- **Nodes**: 4

#### LITTLE MIRROR (currently: disc + bone)
**Target silhouette**: Oval mirror with handle
- **Mirror face**: Ellipse (2×3pt) in `bone` at high alpha (reflective white)
- **Frame**: Same ellipse as stroke in `ash`
- **Handle**: Small rectangle (0.5×1.5pt) below in `ash`
- **Nodes**: 3

#### FOUNTAIN (currently: dome + tide)
**Target silhouette**: Basin with water arcing upward
- **Basin**: Semi-circle (3pt radius) in `ash`
- **Water arc**: Curved path rising from center and falling to sides in `tide`
- **Droplets**: 1-2 tiny circles (0.3pt) in `tide` falling from arc peaks
- **Nodes**: 4-5

#### ROCK (currently: dome + ash)
**Target silhouette**: Irregular boulder, not a perfect dome
- **Shape**: Replace dome with irregular polygon path (5-6 points, slightly randomized) in `ash`
- **Highlight**: Small lighter patch (line segment) on top for dimensionality
- **Nodes**: 2

#### FLAG (currently: pillar + ember)
**Target silhouette**: Pole with waving flag
- **Pole**: Thin rectangle (0.5×6pt) in `ash`
- **Flag**: Small rectangle (3×2pt) attached at top in `ember`, with gentle sway animation (existing sway effect works)
- **Nodes**: 2

#### BENCH (currently: box + ash)
**Target silhouette**: Simple park bench with legs
- **Seat**: Rectangle (6×1pt) in `ash`
- **Legs**: Two thin rectangles at ends (0.5×2pt) in `ash`
- **Back**: Rectangle (6×2pt) above and behind seat in `ash` (slightly lighter)
- **Nodes**: 4

---

## Phase 2: Creature Improvements

### Priority: MEDIUM — Creature already reads well from Critter+, but early stages need work

#### SPORE Stage — Add Proto-Cat Hints
**Current**: Plain circle with faint eyes
**Improvement**:
- Add two tiny bumps at top of circle suggesting ear nubs (path modification to make circle slightly pointed at 10 and 2 o'clock)
- Make eyes slightly larger (0.7pt instead of 0.5pt) so they're visible
- Add very faint tail nub (1pt line) at bottom-back
- **Goal**: Even as a spore, the silhouette hints at "this will become a cat"

#### DROP Stage — Add Ear Points to Silhouette
**Current**: Teardrop with eyes, no cat features
**Improvement**:
- Modify teardrop path to include two small pointed bumps at the top (ear points emerging from blob)
- The "pointed top" of the teardrop becomes two points instead of one
- Increase eye size slightly (1.2pt) for expressiveness
- Add faintest suggestion of a tail curve at bottom (0.5pt line, 20% alpha)
- **Goal**: "It's a little creature... wait, is that a cat? Those look like ears..."

#### CRITTER Stage — Add Whisker Stubs
**Current**: Full cat but no whiskers until Beast
**Improvement**:
- Add 2 short whiskers per side (3pt length, very thin) — shorter than Beast's 3 per side
- Makes the kitten stage feel more complete
- Whiskers are a primary cat identifier at small scale

#### APEX Stage — Multi-Tail Implementation
**Current**: Single tail (vision says 1-9 based on repos)
**Improvement**:
- Query tracked repo count from state database
- Render N tails (1-9) fanned out from tail attach point
- Each tail at slightly different angle (spread ±0.3 rad across count)
- Each tail sways at slightly different phase for organic feel
- At max (9 tails), creature reads as mythical/kitsune-like

#### ALL STAGES — Animate Decorative Elements
**Current**: Third eye (Sage) and crown (Apex) are static
**Improvement**:
- Third eye: gentle alpha pulse (0.15-0.35, 4s period) suggesting awareness
- Crown stars: individual twinkle (staggered sine waves on alpha)
- Core glow: slight color shift between `tide` and `gilt` over long period (60s) for visual interest

---

## Phase 3: Landmarks

### Priority: LOW-MEDIUM — Landmarks are background elements but should be identifiable

#### Current Problem
All 9 landmark types are the same color (`ash`) and similar heights. From a distance, they're all just gray bumps. The *type* doesn't read visually.

#### Improvement Strategy
- **Add color accents** to each landmark type (1 palette color per type, applied to a small detail)
- **Improve silhouettes** so each type has a distinct outline

| Landmark | Current | Improved Silhouette | Color Accent |
|----------|---------|-------------------|--------------|
| Neon Tower | Vertical line | Vertical line + small rectangles (windows) stacked | `tide` glow at antenna |
| Fortress | Blocky rectangle | Crenellated top edge (castle battlements path) | `ash` (stays monochrome, silhouette is enough) |
| Obelisk | Thin point | Thin point + small base step | `bone` tip highlight |
| Crystal | Geometric gem | Multi-faceted path (more angles) | `dusk` inner glow |
| Smoke Stack | Cylinder | Cylinder + wider top rim | `ember` at smoke particles |
| Observatory | Dome | Dome + small rectangle base + tiny point (telescope) | `gilt` star on dome |
| Scroll Tower | Curved shape | Spiral/scroll curl at top of tower | `bone` scroll detail |
| Windmill | Spinning blades | Keep spinning + add small body rectangle beneath | `moss` on blades |
| Monolith | Rectangle | Slightly tapered rectangle (narrower at top) | None (stays pure `ash`) |

---

## Phase 4: Weather & Atmosphere Polish

### Priority: LOW — Already well-implemented, minor improvements

#### Rain Enhancement
- **Current**: 1×2pt cyan dots falling
- **Improvement**: Make droplets actual teardrop paths (pointed top, round bottom) instead of rectangles. At 2pt tall, the difference is subtle but contributes to "rain-ness"

#### Snow Enhancement
- **Current**: 1×1pt white dots drifting
- **Improvement**: Vary snowflake size (0.5-1.5pt) for depth. Larger flakes = closer. Add very rare larger flake (2pt) that falls slower — a "feature flake"

#### Lightning Enhancement
- **Current**: Jagged white line + screen flash
- **Already good** — lightning reads clearly. No changes needed.

#### Fog Enhancement
- **Current**: 3-layer gray rectangles drifting
- **Already good** — layered parallax fog is atmospheric. No changes needed.

#### Firefly Enhancement
- **Current**: Gilt dots that pulse
- **Improvement**: Add very brief "trail" — when a firefly moves, leave a 1-frame afterimage at previous position at 30% alpha. Creates gentle streaking effect.

---

## Phase 5: Future — Texture Atlas Swap

### Priority: DEFERRED — Architecture is ready, art assets needed

The current shape-based system is designed to be swapped with texture atlases without changing any controller logic. When ready:

1. Create pixel art sprite sheets for each growth stage (6 sheets)
2. Create object sprite sheets (20 objects × states)
3. Replace `SKShapeNode` with `SKSpriteNode` in `ShapeFactory` and `ObjectShapeFactory`
4. Keep all controller interfaces identical
5. Target: 8×8 to 16×16 pixel sprites at @2x, nearest-neighbor filtering

This is the ultimate visual upgrade but requires dedicated pixel art work.

---

## Implementation Order

| # | Phase | Scope | Impact | Est. Nodes Added |
|---|-------|-------|--------|-----------------|
| 1 | World Objects | 20 object redesigns | **HIGH** — Most visually broken | +40-60 nodes (within budget) |
| 2a | Creature Early Stages | Spore + Drop ear hints | **HIGH** — First impression | +2-4 nodes |
| 2b | Creature Apex Tails | Multi-tail system | **MEDIUM** — Endgame visual | +1-8 nodes |
| 2c | Creature Polish | Whisker stubs, animated decorations | **LOW** — Refinement | +4-6 nodes |
| 3 | Landmarks | 9 landmark silhouette improvements | **LOW-MEDIUM** — Background | +9-18 nodes |
| 4 | Weather Polish | Rain/snow/firefly tweaks | **LOW** — Already good | +0 nodes (shape changes only) |

**Total estimated node increase**: ~60-90 nodes — still well within the <120 active node budget since LOD culling hides distant objects.

---

## Key Files to Modify

| File | Changes |
|------|---------|
| `World/ObjectShapeFactory.swift` | Replace single-shape builders with composite multi-node builders |
| `IPC/WorldHandlers.swift` | Update preset map if shape names change |
| `World/WorldObjectRenderer.swift` | Adjust node budget accounting for composite objects |
| `Creature/StageRenderer.swift` | Modify Spore/Drop paths, add Critter whiskers, Apex multi-tail |
| `Creature/ShapeFactory.swift` | New ear-nub path for Spore/Drop |
| `World/LandmarkSystem.swift` | Update landmark builders with improved silhouettes and accents |
| `World/RainRenderer.swift` | Teardrop path for droplets |
| `World/SnowRenderer.swift` | Variable flake sizes |
| `World/VisualEventBuilders.swift` | Firefly trail effect |

---

## Success Criteria

- [ ] Show a screenshot of the Touch Bar to someone unfamiliar with the project
- [ ] Ask them to identify each visible object
- [ ] **Pass**: >80% correct identification without hints
- [ ] **Fail**: <60% or "I see shapes and dots"
