---
type: Reference
title: Biomes and Terrain Objects
description: The 5-biome catalog with gradient blending, and the 10 terrain object types with their biome-weighted spawn pools.
status: Live
tags: [world, biomes, terrain, objects]
timestamp: 2026-07-02T00:00:00Z
---

This concept catalogs *what* populates the terrain — biome types and the
objects that spawn on them. It does not describe *how* the terrain is
rendered, chunked, recycled, or scrolled at different parallax depths —
that mechanical layer is
[world terrain and parallax](/SYSTEMS/world-terrain-parallax.md).

# Biomes

Five biomes, deterministically assigned to 800pt world-space regions via a
seeded permutation-table hash (`BiomeManager`, decorrelated from the
terrain-height noise by an XOR'd seed offset):

| Biome | Ground Tint | Height Amplitude | Object Density (per 100pt) |
|---|---|---|---|
| **Plains** | Moss | 0.3 | 1.2 |
| **Forest** | Deep Moss (Moss blended 30% toward Void) | 0.7 | 1.6 |
| **Desert** | Ember | 0.5 | 0.6 |
| **Wetlands** | Tide | 0.2 | 1.0 |
| **Mountains** | Ash | 2.5 | 0.8 |

Colors are named from [the 8-color P3 palette](/REFERENCE/palette.md) — see
that concept for hex values and the `deepMoss` derived-color formula.

## Biome Blending

Adjacent biome regions blend across a **150pt gradient transition zone**
(`BiomeManager.transitionWidth`), not a fixed midpoint — a `BiomeBlend`
struct carries `primary`, an optional `secondary` biome, and a
`blendFactor` (0 = pure primary, 1 = pure secondary) that linearly
interpolates both the ground color and the height amplitude across the
zone. Outside a transition zone, `blendFactor` is 0 and only the primary
biome's ground tint and amplitude apply.

**Adjudicated:** `PUSHLING_VISION.md` describes "50-unit gradient
transitions." The shipped value is 150pt — the source comment on
`transitionWidth` explicitly notes this was deliberately widened ("wider
than the original 50pt") because a 50pt zone produced visible height-amplitude
seams between the most divergent biome pair (Wetlands at 0.2 vs. Mountains
at 2.5). Per DOCS WIN, 150pt is canon; 50pt is superseded design history,
not a drift to correct in code.

# Terrain Objects

Ten object types populate biome terrain, each an `SKShapeNode` or composite
silhouette (`CompositeShapeFactory`) sitting on the terrain surface at a
fixed height/width footprint:

| Object | Height (pt) | Width (pt) | Interactive? |
|---|---|---|---|
| Grass tuft | 3 | 4 | No |
| Flower | 4 | 3 | No |
| Tree | 8 | 6 | No |
| Mushroom | 4 | 4 | No |
| Rock | 3 | 5 | No |
| Water puddle | 1 | 8 | No |
| Star fragment | 3 | 3 | No |
| Ruin pillar | 6 | 3 | No |
| Yarn ball | 4 | 4 | **Yes** |
| Cardboard box | 5 | 6 | **Yes** |

**Interactive objects** (yarn ball, cardboard box) are globally capped at
**2 concurrently visible** (`TerrainRecycler.maxInteractiveVisible`) —
the creature can play with them; see the object-interaction system for the
scoring/behavior side of that (owned elsewhere in the bundle).

## Per-Biome Spawn Pools

Object selection at a given terrain position is deterministic noise-driven
weighted random: **70% primary pool, 25% secondary pool, 5% rare pool**
(`BiomeObjectPool.selectObject`, thresholds at noise values 179/256 and
243/256):

| Biome | Primary (70%) | Secondary (25%) | Rare (5%) |
|---|---|---|---|
| Plains | Grass tuft, Flower, Rock | Yarn ball, Cardboard box | Star fragment, Ruin pillar |
| Forest | Tree, Mushroom, Grass tuft | Flower, Rock | Ruin pillar, Star fragment |
| Desert | Rock, Ruin pillar | Star fragment | Cardboard box, Yarn ball |
| Wetlands | Water puddle, Grass tuft | Mushroom, Flower | Star fragment, Ruin pillar |
| Mountains | Rock (double-weighted — appears twice in the primary list, intentionally) | Star fragment | Ruin pillar, Cardboard box |

During a biome transition, a second noise value (`blendNoise`) decides
whether an object draws from the primary or secondary biome's pool, weighted
by the same `blendFactor` used for ground-color blending above
(`BiomeObjectPool.selectFromBlend`) — objects near a biome boundary can
belong to either neighboring biome, gradually shifting composition as the
world scrolls through the transition zone.

# Repo Skyline

Terrain objects are not the only things standing on the world — permanent
repo-derived landmarks occupy a separate mid-parallax layer. That is its own
authority: [repo landmarks](/REFERENCE/repo-landmarks.md).

# Citations

[1] `Pushling/Sources/Pushling/World/BiomeManager.swift`
[2] `Pushling/Sources/Pushling/World/TerrainObjectPool.swift`
[3] `Pushling/Sources/Pushling/World/TerrainRecycler.swift` (`maxInteractiveVisible`)
[4] `PUSHLING_VISION.md` — Visual System: World Composition (Terrain)
