---
type: System
title: World Terrain & Parallax
description: The authoritative parallax layer configuration (four depth layers), procedural terrain generation from integer noise, the biome-blend transition mechanism, terrain object placement mechanics, and the node-recycling contract that keeps the world at zero net node growth.
status: Live
tags: [world, terrain, parallax, biomes, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **the parallax layer stack and the mechanics of
the ground the creature walks on** — layer count, scroll factors, terrain
generation, the biome-blend transition mechanism, and terrain-object
placement/recycling. It does not own the camera that reads this layer
config (see [camera control](/SYSTEMS/camera-and-parallax.md)), the sky/
clouds riding on the far layer (see
[sky & celestial system](/SYSTEMS/sky-celestial.md)), weather particle
rendering (see [weather system](/SYSTEMS/weather.md)), stage-gated world
richness (see
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)),
or the biome/terrain-object *catalog* — which biomes and object types exist,
their colors and spawn-pool weights — owned by
[biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md).
This concept covers only the generation/placement/recycling *mechanism*
those catalog entries plug into. Source: `World/ParallaxSystem.swift`,
`World/TerrainGenerator.swift`, `World/TerrainRecycler.swift`,
`World/BiomeManager.swift`, `World/TerrainObjectPool.swift`.

# Parallax Layers

**Four** depth layers, not the three originally planned in
`docs/plan/phase-3-world/PHASE-3.md` and `PUSHLING_VISION.md` — a "deep"
layer was added between far and mid (commit `5a2ece5`, "Add deep parallax
layer") to smooth the visual jump between distant and midground terrain:

| Layer | Scroll factor | Z-position | Content role |
|---|---|---|---|
| **Far** | 0.15× creature speed | -100 | Sky gradient, moon, star field, most-distant terrain silhouette |
| **Deep** | 0.25× creature speed | -75 | Cloud layer sits here too (zPosition -75); distant hill silhouettes |
| **Mid** | 0.4× creature speed | -50 | Nearer hill silhouettes, repo landmarks |
| **Fore** | 1.0× (camera-locked) | 0 | Ground terrain, terrain objects, the creature itself |

Each layer is a plain `SKNode` container parented to the scene. Per frame,
`ParallaxSystem.update(cameraWorldX:zoom:focusY:cameraWorldY:)` sets each
layer's screen position to `halfWidth - (worldX × scrollFactor)` (horizontal)
and `-cameraWorldY × scrollFactor` (vertical, for camera Y-tracking); when
zoom is active, layer positions additionally scale and re-center around the
zoom focus point so the pinch-zoom point stays visually fixed. Scene
dimensions are the canonical Touch Bar size, `1085×30pt`
(`ParallaxSystem.sceneWidth/sceneHeight`).

`ParallaxSystem.visibleWorldRange(for:)` / `paddedVisibleRange(for:padding:)`
compute which world-X range is on-screen (or on-screen-plus-margin) for a
given layer, accounting for the layer's own scroll factor and the current
zoom level — this is the query the recycling system below uses to decide
what to load or evict.

# Terrain Generation

`TerrainGenerator` builds the foreground heightmap from **integer-only
noise** (no floating point in the hash, for deterministic cross-platform
results): a seeded 256-entry permutation table (Fisher-Yates shuffle,
doubled to 512 entries to eliminate the seam at the boundary) drives a
3-octave interpolated hash. The seed is deterministic per-machine (derived
from the creature's birth hash, per
[creature identity & birth](/REFERENCE/creature-identity-birth.md)) — same
seed always produces the same terrain.

- **Resolution:** 1 sample per 2pt horizontal (`pointsPerSample = 2.0`).
- **Chunking:** 256 samples/chunk = 512pt world-width per chunk
  (`chunkWorldWidth`); chunks are generated on demand and cached
  (`chunkCache`), capped at 12 cached chunks, evicted when more than 3
  viewports away from the camera.
- **Height range:** 0-8pt above baseline (`baselineY = 4.0`,
  `maxHeight = 8.0`), scaled per-sample by the active biome's height
  amplitude (below).
- **Slope limiting:** a smoothing pass caps the height change between
  adjacent samples at 1.0pt, so a biome boundary jump (e.g. wetlands' 0.2×
  amplitude next to mountains' 2.5×) never produces a visual cliff.

The **background layers** (far/deep/mid) reuse the same hash function with
XOR'd seed offsets for decorrelation from the foreground and from each
other, but at progressively lower detail — this is what makes them read as
softer, more distant silhouettes rather than scaled copies of the same
terrain:

| Layer | Seed offset | Octaves | Amplitude scale | Samples/chunk | Points/sample | X offset |
|---|---|---|---|---|---|---|
| Far | `0xFA20_FACE` | 1 (smoothest) | 1.5× | 128 | 4.0pt | +50pt |
| Deep | `0xD33D_1A7E` | 1 | 1.2× | 192 | 3.0pt | +37pt |
| Mid | `0xBEEF_0000` | 2 (moderate detail) | 1.0× | 256 | 2.0pt | +25pt |

The per-layer X offsets keep each layer's peaks from perfectly aligning with
the ones behind/in front of it, reinforcing the overlap illusion. Background
ground fills use `PushlingPalette.atmosphericColor(ash, depth:)` at
per-layer depth values (far = 0.85, deep = 0.65, mid = 0.4) — see
[rendering stack](/SYSTEMS/rendering-stack-2-5d.md) for how atmospheric
desaturation composes with the rest of the stack.

# Biome Transition Mechanism

Biome *type* is assigned by a second, lower-frequency noise layer
(`BiomeManager`, its own 256-entry permutation table seeded with an XOR
offset from the world seed) over **800pt regions** (`biomeRegionWidth`),
each biome persisting until the noise hash selects a different one for the
next region — the biome catalog itself (which 5 biomes, their ground tints,
height amplitudes, and object-density values) is authoritative at
[biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md); this
section covers only the mechanism that blends between them.

**Transition width is 150pt** (`transitionWidth`) — corrected up from the
50pt specified in `PHASE-3.md`/`PUSHLING_VISION.md` (commit comment: "wider
than the original 50pt", to smooth exactly the wetlands↔mountains
0.2×↔2.5× amplitude jump without a visible cliff even after slope-limiting).
Within a transition zone, `BiomeBlend` linearly interpolates ground color and
height amplitude between the two neighboring biomes; `isTransition` is true
whenever a `blendFactor` strictly between 0 and 1 is active. Biome lookup
(`biomeAt(worldX:)`, `biomeBlendAt(worldX:)`) is O(1) — a region-index
division plus two permutation-table reads.

# Terrain Object Placement Mechanism

Object *type selection* (which of the 10 types, weighted by biome) is
[biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md)'
authority; this concept owns *where* and *how many* objects land on the
terrain. Placement is driven by a third, independent noise stream
(`TerrainRecycler.objectNoise`, its own permutation table) so object
positions are decorrelated from both terrain height and biome boundaries,
with:

- **Minimum 20pt spacing** between any two objects (`minObjectSpacing`).
- **Density-gated placement threshold**: an object only spawns at a sample
  if the placement noise exceeds `256 - (density × 80)`, so denser biomes
  place noticeably more objects than sparse ones — `density` here is the
  per-biome object-density value catalogued at
  [biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md).
- During a biome-transition zone, `BiomeObjectPool.selectFromBlend` uses the
  same `blendFactor` computed above to decide whether a given placement
  draws from the primary or secondary biome's object pool.
- **Object count is additionally gated by growth stage** — see
  [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)
  for the per-stage `maxObjects` ceiling (0 at Egg, up to 14 at Beast+), and
  the interactive-object global cap (2 concurrently visible) catalogued at
  [biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md).

# Tile Recycling

`TerrainRecycler` maintains active-chunk dictionaries per layer
(`activeChunks`, `activeChunksFar/Deep/Mid`) plus a shared `chunkPool` of
reusable `VisualChunk` containers and a per-object-type `objectPool`. Each
frame: chunks fully outside `recycleMargin` (1.5 viewports) of the camera
are torn down (`reset()`, ground node removed, object nodes stripped of
actions and returned to their type's pool) and pushed back onto the shared
pool; chunks newly within the padded visible range
(`preloadMargin = 300pt` ahead of the viewport) are activated — either
popped from the pool and reconfigured, or freshly built if the pool is
empty. Background layers (far/deep/mid) follow the identical recycle/create
cycle independently, keyed by their own chunk-width math. At steady-state
continuous walking this produces **zero net node allocation** — the
`VisualChunk`/object-node instances are the only things that ever get
created, and only on first exposure to a given world region; everything
after that is a pool pop.

Terrain texture overlays (contour lines, valley shadow, hilltop highlight,
micro-detail grass strokes) are a separate, stage-gated layer rebuilt via
`rebuildActiveChunkTextures()` whenever complexity level changes — see
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)
for the per-stage `TerrainTextureConfig` values.

# Depth & Atmospheric Perspective — Reconciled History

An earlier plan document (`docs/plan/TODO-GRAPHICS-OVERHAUL.md`, "Phase 0")
proposed a creature depth axis (`positionZ`, 0.0 = far / 1.0 = near) with
per-depth scale/Y-offset/alpha and object-layer routing with atmospheric
desaturation. Reconciling that plan against the shipped code:

- **Z-axis convention is inverted from the plan.** The plan specified
  `0.0 = far, 1.0 = near`; the shipped convention in
  `Behavior/LayerTypes.swift` is the opposite — `positionZ` defaults to
  `0.0` with the comment "Foreground (full size)", and
  `World/WorldManager+DepthTerrain.swift` documents "0.0 = foreground, 1.0 =
  background." Code is canon here: **0.0 = near/foreground, 1.0 =
  far/background.**
- **Depth range is internally inconsistent between two call sites.**
  `Behavior/PhysicsLayer.swift` clamps the creature's live `currentZ` to
  `0.0...0.8` (never lets the creature travel all the way to "far"), while
  `IPC/ActionHandlers.swift` clamps the *input* `z` parameter from an IPC
  move command to the full `0.0...1.0`. This is a real internal gap the
  plan didn't anticipate — flagged here rather than silently resolved, since
  narrowing either clamp is a behavior change outside this documentation
  pass's authority.
- **Object-layer routing did ship.** `World/WorldObjectRenderer.swift`
  routes each `WorldObjectDefinition` to its assigned parallax layer
  (`layerNodes[definition.layer]`) with per-layer scale/alpha — this part of
  the plan is live, not aspirational.
- **The `atmosphericColor` helper shipped with a different signature** than
  the plan proposed: `atmosphericColor(_ color:, depth: CGFloat)` on
  `PushlingPalette` (depth-based), not the plan's
  `atmosphericColor(_ base:, layer: ParallaxLayer)` (layer-enum-based). See
  [rendering stack](/SYSTEMS/rendering-stack-2-5d.md) for its use.
- **MCP-level depth control never shipped.** The plan's
  `pushling_move(..., depth: 0.8)` with `approach`/`retreat_depth` actions
  has zero references anywhere in `mcp/src` — the daemon-side IPC handler
  accepts a `z` parameter (see the internal-consistency note above), but no
  MCP tool exposes it. This is defined-but-unwired at the MCP boundary, not
  a documentation gap — flagged for the Orchestrator's discovery backlog
  rather than authored as canon here, since minting it as a tool-contract
  entry would describe a capability Claude cannot actually invoke today.

# Citations

[1] `Pushling/Sources/Pushling/World/ParallaxSystem.swift`
[2] `Pushling/Sources/Pushling/World/TerrainGenerator.swift`, `World/TerrainRecycler.swift`
[3] `Pushling/Sources/Pushling/World/BiomeManager.swift`, `World/TerrainObjectPool.swift`
[4] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift`, `Behavior/PhysicsLayer.swift`, `IPC/ActionHandlers.swift`
[5] `Pushling/Sources/Pushling/World/WorldObjectRenderer.swift`, `World/PushlingPalette.swift`
[6] `docs/plan/phase-3-world/PHASE-3.md` (P3-T1-01 through P3-T1-06) — superseded 3-layer/50pt-transition numbers
[7] `docs/plan/TODO-GRAPHICS-OVERHAUL.md` (Phase 0A-0E) — depth-system plan, reconciled above
