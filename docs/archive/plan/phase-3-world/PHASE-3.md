# Phase 3: World

## Goal

The procedural 2.5D parallax world exists — terrain, biomes, weather, day/night, repo landmarks, sky. The creature walks through a living world. The Touch Bar is no longer a flat stage; it is a tiny terrarium with genuine depth, dynamic atmosphere, and a growing skyline that reflects the developer's coding history.

## Dependencies

- **Phase 1 Track 1** — SpriteKit scene rendering at 60fps with camera system
- **Phase 1 Track 2** — SQLite state persistence (world seed, biome data, landmark records, weather state)
- **Phase 2 Track 1** — Creature exists as a composite SpriteKit node with walk cycle and idle behaviors
- **Phase 2 Track 2** — Behavior stack operational (creature's autonomous layer drives movement through the world)

## Architectural Context

The world is rendered in 3 parallax layers within the 1085x30pt scene. The creature walks at 1.0x speed on the foreground layer; background layers scroll at fractional speeds to create depth. Terrain is procedurally generated from integer noise, divided into 5 biomes with gradient transitions. The sky is a real-time gradient driven by wall clock. Weather is a state machine checked every 5 minutes.

All world state persists in SQLite: biome seed, terrain heightmap cache, landmark positions, weather history, day/night phase. The MCP server reads world state (read-only) via `pushling_sense("surroundings")`.

**Performance envelope**: The world system must fit within ~1.3ms of the 5.7ms total frame budget (parallax 0.1ms + terrain heightmap 0.2ms + particle systems ~1.0ms). Node count contribution: ~40-60 nodes (terrain objects, sky elements, weather particles), leaving room for the creature (~30 nodes) and HUD (~10 nodes) within the 120-node target.

---

## Tracks

### Track 1: Terrain & Parallax (P3-T1)

**Agents**: swift-world, assets-world
**Estimated effort**: 8-10 days
**Parallelizable with**: Track 2 (sky/weather) after P3-T1-01 is complete

#### P3-T1-01: 3-Layer Parallax System

**What**: Implement the parallax camera system with 3 depth layers that scroll at different speeds relative to the creature's position.

**Specs**:
| Layer | Scroll Speed | Z-Position | Content Role |
|-------|-------------|------------|-------------|
| **Far** | 0.15x creature speed | -100 | Star field, distant mountains, moon |
| **Mid** | 0.4x creature speed | -50 | Hill silhouettes, structures, repo landmarks |
| **Fore** | 1.0x (camera-locked) | 0 | Ground terrain, plants, creature, items |

**Implementation**:
- Each layer is an `SKNode` container parented to the scene
- Camera node tracks creature X position; each layer's X offset = `creature.position.x * layer.scrollFactor`
- Layers use `SKCameraNode` for viewport management
- Far and Mid layers tile/wrap seamlessly at viewport edges

**Verification**:
- [ ] Three distinct layers visible with correct depth ordering
- [ ] Walking creature left/right produces convincing parallax depth effect
- [ ] No seam gaps or popping at layer tile boundaries
- [ ] Parallax update completes in <0.1ms per frame (profile with Instruments)

---

#### P3-T1-02: Procedural Terrain Generation

**What**: Generate ground heightmap from integer noise. The terrain defines the walkable surface the creature traverses.

**Specs**:
- Integer noise function (not floating-point — deterministic across platforms)
- Heightmap resolution: 1 sample per 2 points horizontal (543 samples across full viewport)
- Height range: 0-8pt above baseline (baseline at Y=4pt from bottom)
- Seed derived from creature's birth hash (deterministic per machine)
- Terrain extends infinitely in both directions; generated on demand as creature walks

**Implementation**:
- `TerrainGenerator` class with seed-based integer noise (e.g., simple permutation table hash)
- Heightmap cached in 256-sample chunks; evict chunks >3 viewports away
- Ground rendered as an `SKShapeNode` polygon or series of 2pt-wide rectangles (whichever profiles faster)
- Ground color: Ash (`#5A5A5A`) base with biome-specific tinting

**Verification**:
- [ ] Terrain generates deterministically from seed (same seed = same terrain)
- [ ] Creature walks on terrain surface without floating or clipping
- [ ] Terrain extends seamlessly as creature walks in either direction
- [ ] Heightmap generation completes in <0.2ms per frame
- [ ] Memory: cached chunks stay under 50KB total

---

#### P3-T1-03: 5-Biome System

**What**: Divide the infinite terrain into 5 biomes with 50-unit gradient transitions between them.

**Specs**:
| Biome | Ground Color Tint | Terrain Character | Typical Objects |
|-------|------------------|-------------------|----------------|
| **Plains** | Moss-tinted | Flat, gentle rolls | Grass, flowers, rocks |
| **Forest** | Deep Moss | Moderate elevation | Trees, mushrooms, ferns |
| **Desert** | Ember-tinted | Dunes, sparse flat | Rocks, ruins, star fragments |
| **Wetlands** | Tide-tinted | Low, watery | Puddles, reeds, lily pads |
| **Mountains** | Ash/Bone | Sharp peaks, high altitude | Rocks, snow, crystal |

- Biome boundaries are determined by noise function at a lower frequency than terrain height
- 50-unit gradient transitions: at boundaries, both biomes' properties interpolate linearly
- Biome type stored per terrain chunk for fast lookup
- Biome sequence is procedural (not fixed order)

**Implementation**:
- Second noise layer at 1/10th terrain frequency determines biome type
- `BiomeBlender` interpolates ground color, object pools, heightmap amplitude across 50-unit boundaries
- Each biome has a heightmap amplitude modifier (plains: 0.3x, mountains: 2.5x, etc.)

**Verification**:
- [ ] All 5 biomes appear when walking far enough in either direction
- [ ] Transitions between biomes are gradual (50-unit gradient, no hard edges)
- [ ] Biome-specific terrain character is visually distinct
- [ ] Biome lookup is O(1) from cached chunk data

---

#### P3-T1-04: Terrain Objects — Placement & Pool

**What**: Populate the world with 8-14 visible objects at any time. Objects are the foreground details that make the world feel alive.

**Specs**:
- **10 object types**: grass tufts, flowers, trees, mushrooms, rocks, water puddles, star fragments, ruin pillars, yarn balls, cardboard boxes
- 8-14 objects visible in viewport at any time (density varies by biome)
- Objects placed procedurally by terrain noise (deterministic positions)
- Minimum 20pt spacing between objects
- Objects are foreground layer (Z = 0), sitting on terrain surface

**Implementation**:
- Object placement driven by a third noise layer (decorrelated from terrain and biome noise)
- Each object type is a pre-rendered `SKSpriteNode` from a texture atlas
- Object sizes: 3-8pt tall, appropriate to 30pt scene height
- Objects cast no shadow (unnecessary at this scale)

**Verification**:
- [ ] 8-14 objects visible at any reasonable camera position
- [ ] Objects sit correctly on terrain surface (no floating, no buried)
- [ ] No two objects closer than 20pt
- [ ] Objects appropriate to current biome (no water puddles in desert, etc.)

---

#### P3-T1-05: Biome-Specific Object Pools

**What**: Each biome favors certain terrain objects. Define weighted pools per biome.

**Specs**:
| Biome | Primary Objects (70%) | Secondary Objects (25%) | Rare Objects (5%) |
|-------|----------------------|------------------------|-------------------|
| Plains | Grass, flowers, rocks | Yarn balls, cardboard boxes | Star fragments, ruins |
| Forest | Trees, mushrooms, ferns | Flowers, rocks | Ruins, star fragments |
| Desert | Rocks, ruins | Star fragments | Cardboard boxes, yarn balls |
| Wetlands | Puddles, reeds | Mushrooms, flowers | Star fragments, ruins |
| Mountains | Rocks, crystal | Star fragments | Ruins, cardboard boxes |

- During biome transitions, object pools blend: objects from both biomes appear in the 50-unit gradient zone
- Interactive objects (yarn balls, cardboard boxes) are globally rarer (max 2 visible at once)

**Implementation**:
- `BiomeObjectPool` struct with weighted random selection per biome
- Pool blending uses same interpolation factor as biome gradient
- Global interactive-object cap enforced at placement time

**Verification**:
- [ ] Object distribution matches biome identity visually
- [ ] Transition zones contain objects from both adjacent biomes
- [ ] Never more than 2 interactive objects (yarn, boxes) visible simultaneously
- [ ] Object variety feels natural, not repetitive

---

#### P3-T1-06: Terrain Tile Recycling

**What**: As the creature walks, off-screen terrain and objects must be recycled to maintain constant node count.

**Specs**:
- Terrain chunks and objects that scroll >1.5 viewports off-screen are removed from the scene
- When new terrain enters from the leading edge, chunks and objects are generated or recycled from a pool
- Target: 0 net node creation during steady-state walking (all allocation via pool)
- Object pool sizes: ~20 terrain objects, ~10 terrain chunks

**Implementation**:
- `TerrainRecycler` manages pools of reusable `SKSpriteNode` instances
- On each frame update, check if leading edge needs new content or trailing edge has reclaimable nodes
- Recycled nodes have their texture, position, and scale reset from the terrain generator's deterministic output
- Terrain chunks are `SKNode` containers holding ground geometry + local objects

**Verification**:
- [ ] Walking continuously in one direction for 5 minutes produces no memory growth
- [ ] No visual popping — new terrain appears seamlessly at viewport edge
- [ ] Node count remains stable (±5 nodes) during continuous walking
- [ ] Reversing direction reconstructs previously-seen terrain identically (deterministic)

---

#### P3-T1-07: Repo Landmark System

**What**: Each tracked repo adds a permanent silhouette structure to the mid-background layer. These are the "skyline" that grows with the developer's coding breadth.

**Specs**:
| Repo Type | Landmark | Visual Description | Size |
|-----------|----------|-------------------|------|
| Web app (.tsx/.jsx + package.json) | Neon tower | Glowing vertical line with antenna | 4-8pt tall |
| API/backend (routes/controllers) | Fortress | Blocky castle silhouette | 5-7pt tall |
| CLI tool (bin/ or main entry) | Obelisk | Tall thin pointed shape | 6-8pt tall |
| Library/package (lib/ + published) | Crystal | Geometric faceted shape | 4-6pt tall |
| Infra/DevOps (.tf, docker, CI) | Smoke stack | Tower with particle smoke wisps | 5-7pt tall |
| Data/ML (.ipynb, models/) | Observatory | Dome shape with tiny star | 4-6pt tall |
| Docs/content (majority .md) | Scroll tower | Curved architecture | 4-6pt tall |
| Game/creative | Windmill | Spinning blades (animated!) | 5-7pt tall |
| Generic/unknown | Monolith | Simple tall rectangle | 4-6pt tall |

- Landmarks are in the **Mid layer** (0.4x scroll speed) — they parallax slowly
- Spacing: minimum 80pt between landmarks in world-space
- Landmarks are Ash (`#5A5A5A`) silhouettes — subtle, not dominant
- The windmill landmark has a rotating blade animation (1 revolution per 4s)
- Landmark positions are deterministic from repo name hash + creation order

**Implementation**:
- `LandmarkManager` reads tracked repos from SQLite, generates landmarks
- Each landmark is an `SKSpriteNode` or small `SKNode` composite (windmill needs child rotation)
- Landmarks persist in SQLite: `repo_name`, `landmark_type`, `world_x_position`, `created_at`
- New repo detected → landmark placed at next available position → journal entry logged
- Smoke stack uses a minimal `SKEmitterNode` (3-5 particles/sec, recycled)

**Verification**:
- [ ] Each tracked repo has exactly one landmark on the skyline
- [ ] Landmarks scroll at 0.4x speed (Mid layer parallax)
- [ ] Landmark type matches repo content analysis
- [ ] Windmill blades animate smoothly
- [ ] Smoke stack particles visible but minimal performance impact
- [ ] New repo creates new landmark (visible within one walk cycle)

---

#### P3-T1-08: Landmark Generation from Repo Analysis

**What**: Determine landmark type by analyzing repo directory structure and file contents.

**Specs**:
- Analysis runs once per repo on first track, results cached in SQLite
- Detection heuristics (checked in order, first match wins):
  1. Web app: has `package.json` AND (`.tsx`/`.jsx`/`.vue`/`.svelte` files)
  2. Infra/DevOps: has `.tf`/`Dockerfile`/`.github/workflows` at root level
  3. Data/ML: has `.ipynb` files OR `models/` directory
  4. API/backend: has `routes/`/`controllers/`/`app/` with server-side code
  5. CLI tool: has `bin/` directory OR single main entry (`main.go`, `main.rs`, `src/main.ts`)
  6. Library: has `lib/` AND published indicator (`.npmrc`, `Cargo.toml` with `[package]`, `setup.py`)
  7. Game/creative: has game engine files (`.unity`, `.godot`, `SpriteKit`, `SDL`)
  8. Docs: majority of files are `.md`/`.txt`/`.rst`
  9. Generic: fallback

**Implementation**:
- `RepoAnalyzer` class scans tracked repo directory (shallow — no git log needed)
- File extension counting + directory structure matching
- Results stored in `repos` table: `path`, `name`, `landmark_type`, `dominant_language`, `analyzed_at`
- Re-analysis triggered if repo structure changes significantly (>20% new file types)

**Verification**:
- [ ] Correctly classifies at least 5 known repo types in integration test
- [ ] Analysis completes in <2s even for large repos (shallow scan only)
- [ ] Fallback to "generic" for ambiguous repos (no crash, no hang)
- [ ] Re-analysis updates landmark type if repo evolves

---

#### P3-T1-09: Diet-Influenced World Tinting

**What**: The creature's language specialty subtly tints the world, making each developer's Pushling feel unique.

**Specs**:
| Specialty | World Tint | Alpha | Flavor |
|-----------|-----------|-------|--------|
| Systems (.rs, .c, .go) | Warm industrial | 0.15-0.20 | Distant chimneys, metallic shimmer on terrain |
| Web Frontend (.tsx, .css) | Neon accents | 0.15-0.25 | Geometric structures glow faintly, sparkle on objects |
| Web Backend (.php, .rb) | Warm stone | 0.15-0.20 | Sturdy architecture hues, warm ground |
| Script (.py, .sh) | Organic green | 0.15-0.20 | Flowing shapes, lush undertone |
| Data (.sql, .ipynb) | Matrix cyan | 0.15-0.25 | Number streams in far background, analytical glow |
| JVM (.java, .kt) | Structured blue | 0.15-0.20 | Geometric patterns, formal tones |
| Infra (.yaml, .tf) | Ghost white | 0.15-0.20 | Translucent overlays, guardian glow |
| Polyglot (no category >30%) | Shifting | 0.15-0.20 | Color shifts between specialties over 30s cycle |

- Tint applied as a full-scene color overlay node at very low alpha
- Updates when creature's specialty changes (checked on each commit processing)
- Transition between tints: 10-second crossfade

**Implementation**:
- `WorldTintController` reads creature specialty from state
- Overlay is a single `SKSpriteNode` (solid color, scene-sized) at high Z with blend mode `.alpha`
- Specialty determined by 30-day rolling window of committed file extensions
- Polyglot tint uses `SKAction.repeatForever` color cycling

**Verification**:
- [ ] Tint is visible but subtle (not overpowering the 8-color palette)
- [ ] Tint matches creature's current language specialty
- [ ] Polyglot tint cycles smoothly between influences
- [ ] Tint transition on specialty change is a smooth crossfade
- [ ] Zero additional nodes (single overlay sprite)

---

### Track 2: Sky & Weather (P3-T2)

**Agents**: swift-world (sky/weather subsystem)
**Estimated effort**: 7-9 days
**Parallelizable with**: Track 1 (after P3-T1-01 provides the layer system)

#### P3-T2-01: Real-Time Sky Gradient

**What**: The sky reflects the actual time of day with smooth transitions between 8 time periods.

**Specs**:
| Period | Wall Clock | Sky Colors (top → bottom) |
|--------|-----------|--------------------------|
| Deep Night | 00:00-04:30 | Void → deep Dusk |
| Dawn | 04:30-06:00 | Dusk → soft Ember horizon |
| Morning | 06:00-09:00 | Ember horizon → light Tide wash |
| Day | 09:00-16:00 | Clear — faint Tide at top, Bone-tinted horizon |
| Golden Hour | 16:00-18:00 | Gilt wash → warm Ember |
| Dusk | 18:00-19:30 | Ember → deep Dusk |
| Evening | 19:30-22:00 | Dusk → near-Void |
| Late Night | 22:00-00:00 | Void with faint Dusk at horizon |

- Transitions between periods: 10-minute linear interpolation
- Sky rendered on the **Far layer** (0.15x scroll) as a vertical gradient
- Gradient uses 2-3 color stops maximum (OLED efficiency)
- All times in local timezone

**Implementation**:
- `SkyController` calculates current period + interpolation factor from `Date()`
- Sky is an `SKShapeNode` with gradient fill, or an `SKEffectNode` with CIFilter gradient
- Alternative: pre-rendered gradient textures for each period, crossfade between them (simpler, faster)
- Update frequency: every 60 frames (1/sec) is sufficient for smooth visual

**Verification**:
- [ ] Sky matches approximate time of day at a glance
- [ ] Transitions are smooth (no color snapping at period boundaries)
- [ ] OLED optimization: deep night sky is true `#000000` (pixels off)
- [ ] Sky gradient renders in <0.05ms (far background, minimal work)

---

#### P3-T2-02: Moon with Lunar Phase

**What**: A moon appears in the night sky showing the actual current lunar phase.

**Specs**:
- Moon visible during: Deep Night, Dawn (fading), Dusk (appearing), Evening, Late Night
- Size: 3x3pt (small but recognizable)
- Color: Bone (`#F5F0E8`) with dark Ash shadow for phase
- Phase calculation: Metonic cycle approximation (simple formula, no ephemeris needed)
- Position: upper-right area of Far layer, slight drift with parallax

**Implementation**:
- `MoonNode` as an `SKSpriteNode` with dynamically drawn phase texture
- Phase rendered as a circle with shadow arc: `(1 - cos(phase_angle)) / 2` gives illumination fraction
- Texture regenerated once per day (phase changes slowly)
- Fade in/out tied to sky period transitions

**Verification**:
- [ ] Moon phase roughly matches actual lunar phase (within 1 day accuracy)
- [ ] Moon visible at night, hidden during day
- [ ] Moon is subtle — visible but not attention-grabbing
- [ ] Full moon triggers surprise #57 (hook point for surprise system)

---

#### P3-T2-03: Star Field

**What**: 15-25 twinkling stars appear at night, fading at dawn and reappearing at dusk.

**Specs**:
- Star count: 15-25 (random within range, regenerated per night cycle)
- Star size: 1x1pt (single pixel, occasionally 2x1pt for bright ones)
- Star color: Gilt (`#FFD700`) at varying alpha (0.3-1.0)
- Twinkle: sinusoidal alpha oscillation, each star at a random phase and frequency (0.5-2.0Hz)
- Stars on Far layer — barely move with parallax (0.15x)
- Fade in at Evening period, full brightness at Deep Night, fade out at Dawn

**Implementation**:
- `StarFieldNode` container on Far layer with child `SKSpriteNode` per star
- Each star has an `SKAction.repeatForever` with `customAction` for alpha oscillation
- Star positions randomized but seeded (same sky each night? or new arrangement — design choice, suggest: new each night for freshness)
- Batch fade using parent node alpha modulated by sky period

**Verification**:
- [ ] 15-25 stars visible at night
- [ ] Twinkle effect visible — stars are not static points
- [ ] Stars fade smoothly with dawn/dusk transitions
- [ ] Stars are Gilt-colored, legible against Void/Dusk sky
- [ ] No star overlaps with moon position

---

#### P3-T2-04: Weather State Machine

**What**: Weather changes every 5 minutes with weighted probabilities. Weather affects visuals, particles, and creature behavior.

**Specs**:
| State | Probability | Duration | Visual Effect |
|-------|------------|----------|---------------|
| Clear | 55% | 5-30min | No particles, full sky visibility |
| Cloudy | 18% | 5-20min | 2-3 cloud shapes drift across Far/Mid layers, sky slightly muted |
| Rain | 12% | 5-15min | Rain particles, puddle splashes, darker sky |
| Storm | 5% | 3-10min | Heavy rain + lightning + screen shake |
| Snow | 3% | 5-20min | Snow particles, gentle accumulation on terrain |
| Fog | 7% | 5-25min | Layered alpha strips at different depths, reduced visibility (see P3-T2-08) |

- State checked every 5 minutes (not every frame)
- Transitions: 30-second crossfade between weather states
- Weather state persisted in SQLite (survives daemon restart)
- Weather can be overridden by MCP `pushling_world("weather", ...)` (Phase 4 integration point)

**Implementation**:
- `WeatherStateMachine` with weighted random transition table
- Each weather state has an associated `WeatherRenderer` protocol implementation
- State transitions emit `.weatherChanged` notification for creature behavior reactions
- Current weather exposed via state query for MCP `pushling_sense("surroundings")`

**Verification**:
- [ ] Weather changes approximately every 5 minutes
- [ ] Probability distribution roughly matches spec over 100+ transitions
- [ ] Transitions between states are smooth (30s crossfade)
- [ ] Weather state survives daemon restart
- [ ] Weather state readable from SQLite (for MCP)

---

#### P3-T2-05: Rain Particles

**What**: Rain as individual droplets with terrain impact splashes.

**Specs**:
- Droplet size: 1x2pt (vertical)
- Droplet color: Tide (`#00D4FF`) at alpha 0.6
- Fall speed: 100-140pts/sec (random per droplet within range)
- Droplet count: 30-50 active at a time (covers viewport)
- Slight horizontal drift: 5-15pts/sec (wind effect)
- Splash on terrain impact: 3 particles, 1x1pt, Tide at alpha 0.3, spread outward over 100ms then fade

**Implementation**:
- Primary approach: `SKEmitterNode` configured for rain (fastest, GPU-handled)
- If `SKEmitterNode` doesn't support terrain-aware splash: use manual particle pool (40 `SKSpriteNode` droplets recycled)
- Splash particles: separate small emitter burst at impact Y position, or manual 3-node burst from pool
- Rain sound hook point (for future audio integration)

**Verification**:
- [ ] Rain droplets fall at correct speed and angle
- [ ] Splash particles appear at terrain surface on impact
- [ ] Droplet count maintains 30-50 active (no runaway spawning)
- [ ] Rain particle system uses <0.5ms per frame
- [ ] Rain visually reads as "rain" at glance (not static noise)

---

#### P3-T2-06: Snow Particles

**What**: Gentle snowfall with accumulation effect.

**Specs**:
- Snowflake size: 1x1pt
- Snowflake color: Bone (`#F5F0E8`) at alpha 0.5-0.8
- Fall speed: 20-40pts/sec (much slower than rain)
- Horizontal drift: ±10pts/sec (gentle sine-wave lateral movement)
- Count: 15-30 active flakes
- Accumulation: thin white line builds up on terrain surface over time (max 1pt height)
- Accumulation melts over 5 minutes after snow stops

**Implementation**:
- `SKEmitterNode` for snowflakes with low speed, high lifetime, lateral oscillation
- Accumulation: modify terrain ground node to add 1pt Bone-colored cap during snow
- Accumulation tracks as a float (0.0-1.0), increases at 0.05/min during snow, decreases at 0.2/min after
- Creature footprints in snow: brief dark marks at paw positions (subtle)

**Verification**:
- [ ] Snow drifts gently (visually distinct from rain)
- [ ] Snow accumulates visibly on terrain during prolonged snowfall
- [ ] Accumulation melts after snow stops
- [ ] Snow particle count stays in 15-30 range
- [ ] Snowflakes have lateral drift (not perfectly vertical)

---

#### P3-T2-07: Storm System

**What**: Lightning cracks the full width with screen shake and thunder timing.

**Specs**:
- Storm = heavy rain (60-80 droplets) + lightning + screen shake
- Lightning: full-width (1085pt) jagged crack from top to bottom
  - Color: Bone (`#F5F0E8`) at full alpha, then Gilt flash
  - Duration: 100ms flash, then 200ms afterimage at alpha 0.3
  - Crack shape: 8-12 segment polyline with random horizontal offsets (±40pt)
  - Frequency: every 8-20 seconds during storm
- Screen shake: 2pt random offset for 300ms, coincident with lightning
- Thunder: 0.5-2.0s delay after lightning (distance simulation)
  - Hook point for audio system (rumble sound)
  - Creature reaction triggers on thunder, not lightning (realism)
- Sky darkens to near-Void with Dusk undertone during storm

**Implementation**:
- `LightningNode` generates random polyline, renders via `SKShapeNode`
- Flash: node alpha 1.0 → 0.3 over 200ms → remove
- Screen shake: `SKAction.sequence` of random offset moves on camera node
- Thunder delay: `DispatchQueue.main.asyncAfter` to trigger creature reaction and audio hook
- Storm inherits all rain particle behavior but at higher density

**Verification**:
- [ ] Lightning crack spans full Touch Bar width
- [ ] Crack shape is jagged and random (never identical twice)
- [ ] Screen shake is subtle (2pt) but perceptible
- [ ] Thunder delay creates realism (light before sound)
- [ ] Storm visually distinct from regular rain (heavier, darker, dramatic)
- [ ] Lightning + shake + heavy rain stays within frame budget

---

#### P3-T2-08: Fog System

**What**: Fog as alpha layers that reduce visibility and create atmosphere.

**Specs**:
- Fog is a standalone weather modifier (can combine with other states or occur alone under "Cloudy")
- Implementation: 2-3 horizontal `SKSpriteNode` strips at different depths
  - Near fog: alpha 0.3, foreground layer, slow drift left (5pts/sec)
  - Mid fog: alpha 0.2, mid layer, drift right (3pts/sec)
  - Far fog: alpha 0.15, far layer, near-static
- Fog color: Ash (`#5A5A5A`)
- Fog obscures distant landmarks and far-layer stars
- Fog density varies: light (morning), medium (weather event), thick (rare)

**Implementation**:
- `FogController` manages 2-3 `SKSpriteNode` strips with repeating texture
- Each strip moves independently via `SKAction.moveBy` looping
- Fog density modulates all strip alphas proportionally
- Fog fades in/out over 60 seconds

**Verification**:
- [ ] Fog creates visible atmosphere without fully obscuring the world
- [ ] Multiple fog layers at different speeds create depth
- [ ] Far-layer content (stars, moon) is appropriately dimmed through fog
- [ ] Fog transitions in/out smoothly (60s fade)
- [ ] Fog nodes: exactly 2-3 (no proliferation)

---

#### P3-T2-09: Creature Weather Reactions

**What**: The creature responds to weather changes with appropriate behavior. These are Layer 2 Reflex-priority behaviors.

**Specs**:
| Weather | Creature Reaction |
|---------|-------------------|
| Rain starts | Ears flatten slightly, hunches body, walks faster seeking cover (mushroom, tree, box) |
| Rain sustained | Sits under cover if available, or walks with hunched posture. Occasional head shake. |
| Snow starts | Looks up, ears perk. Tries to catch snowflakes (head tracking falling flakes). |
| Snow sustained | Plays in snow — paw prints, occasional snow-pounce. Shivers after 5 min. |
| Storm/lightning | Ears snap flat on thunder, startles (jump-flinch), retreats to cover. Eyes wide. |
| Storm/thunder | Chatters (jaw vibrate). Looks up nervously between cracks. |
| Fog | Moves more slowly, cautious. Ears swivel — listening more than watching. |
| Clear after rain | Shakes off (full-body shake animation), investigates puddles. |
| Clear after storm | Cautious emergence, sniffs air, gradually relaxes. |

**Implementation**:
- Weather reactions registered as `Reflex` entries in the behavior stack
- Each weather state maps to a `WeatherBehavior` that modulates autonomous actions
- Reactions fire on `.weatherChanged` notification
- Cover-seeking: creature pathfinds to nearest terrain object >4pt tall within 100pt
- If no cover: creature hunches and endures (personality-dependent tolerance)

**Verification**:
- [ ] Creature visibly reacts to each weather type
- [ ] Reactions feel natural (hunching in rain, catching snow)
- [ ] Cover-seeking works — creature moves toward large terrain objects
- [ ] Reactions are Reflex-priority (override autonomous wandering but not touch)
- [ ] Weather reaction animations blend smoothly with existing creature state

---

### Track 3: Visual Polish (P3-T3)

**Agents**: assets-world, swift-scene
**Estimated effort**: 5-7 days
**Dependencies**: Track 1 (terrain and objects exist) + Track 2 (sky and weather exist)

#### P3-T3-01: 8-Color P3 Palette Implementation

**What**: Enforce the 8-color P3 palette across all world elements. Every pixel on screen uses one of these colors (or an alpha blend of one against Void).

**Specs**:
| Role | Hex | P3 Value | Usage |
|------|-----|----------|-------|
| Void | `#000000` | (0, 0, 0) | Background — OLED pixels OFF |
| Bone | `#F5F0E8` | Warm white | Creature body, moon, snow, lightning |
| Ember | `#FF4D00` | Fire orange | Fire accents, warnings, anger, laser pointer |
| Moss | `#00E860` | Vivid green | Terrain, health, contentment |
| Tide | `#00D4FF` | Bright cyan | Water, XP, commit text, rain |
| Gilt | `#FFD700` | Gold | Stars, milestones, evolution, speech bubbles |
| Dusk | `#7B2FBE` | Deep purple | Night sky, magic, dreams |
| Ash | `#5A5A5A` | Medium gray | Distant terrain, ghosts, fog, whisper text |

**Implementation**:
- `PushlingPalette` enum with static `SKColor` properties using P3 color space (`NSColorSpace.displayP3`)
- Audit all existing nodes to use palette colors (no raw hex in code)
- Add compile-time or runtime assertion that no node uses off-palette colors (debug only)
- Alpha variations of palette colors are allowed (e.g., Tide at 0.6 for rain)

**Verification**:
- [ ] All visible elements use only the 8 palette colors (or alpha blends thereof)
- [ ] Colors are P3 gamut (visibly more vivid than sRGB equivalents on OLED)
- [ ] No stray colors appear in any game state
- [ ] Palette enum is the single source of truth (no hardcoded hex elsewhere)

---

#### P3-T3-02: OLED True-Black Optimization

**What**: Background must be literal `#000000` — OLED pixels off. This is the foundation of the "luminous pixel life" aesthetic.

**Specs**:
- Scene background color: `SKColor.black` (confirmed `#000000`, not dark gray)
- No "ambient" background elements that would keep pixels lit
- Far-layer sky gradient fades TO black (not a dark color)
- Deep Night sky must be true black (verified with color picker)
- Any glow/aura effects must not bleed into void areas

**Implementation**:
- `scene.backgroundColor = .black`
- Verify SKView's `allowsTransparency` is false (we want true black, not transparent)
- Sky gradient bottom color at night = `SKColor(red: 0, green: 0, blue: 0, alpha: 1)`
- Aura/glow effects use additive blending so they don't create gray halos

**Verification**:
- [ ] Screenshot at Deep Night + Clear weather shows true `#000000` in void areas
- [ ] No gray haze around creature aura or particle effects
- [ ] OLED panel benefit visible — void areas are literally unlit
- [ ] Color picker confirms `(0,0,0)` in empty areas

---

#### P3-T3-03: Visual Earned Complexity

**What**: World richness scales with creature stage. A Spore's world is sparse; an Apex's world is rich and alive.

**Specs**:
| Stage | World Complexity |
|-------|-----------------|
| **Spore** | Near-empty void. Faint ground line (Ash at alpha 0.3). 0-3 dim stars. No terrain objects. No weather. No biomes. |
| **Drop** | Ground visible (Ash at alpha 0.6). First plants appear (2-4 objects). Dawn-like palette. 5-10 stars at night. |
| **Critter** | Trees, flowers, water. Day/night cycle activates. 6-10 objects. Biomes begin appearing (2 types). Light weather (clear/cloudy only). |
| **Beast** | Full 5 biomes. Full parallax active. All weather types. Full terrain object density (8-14). Repo landmarks visible. |
| **Sage** | Particle density increases. Magic ambient effects (floating motes). Wisdom particles near creature. Full surprise roster. |
| **Apex** | Full cosmic palette. Stars respond to creature proximity. Terrain near creature glows faintly. Semi-ethereal environmental effects. |

**Implementation**:
- `WorldComplexityController` gates features based on `creatureStage` from state
- Each system (terrain objects, weather, biomes, parallax detail, stars) has a stage-gate configuration
- Systems below their gate stage are either disabled or run at reduced parameters
- Stage transitions trigger complexity upgrades with brief visual flourish

**Verification**:
- [ ] Spore world is dramatically sparse (almost empty)
- [ ] Each stage visibly increases world richness
- [ ] No Beast-level features appear for a Critter (gates enforced)
- [ ] Complexity upgrades on stage transition are noticeable and delightful
- [ ] Performance stays within budget at Apex complexity (worst case)

---

#### P3-T3-04: Puddle Reflections

**What**: Water puddles show a 1-pixel mirrored silhouette of the creature. One of the "wow factor" moments.

**Specs**:
- Reflection: 1-pixel height mirrored version of creature silhouette below puddle surface
- Reflection color: creature's primary color at alpha 0.15
- Reflection only when creature is within 10pt of a puddle
- Reflection ripples when creature walks through puddle (sine distortion, 0.5s)
- Creature may pause, tilt head at reflection (idle behavior, 5% chance when near puddle)

**Implementation**:
- `PuddleReflection` node: thin `SKSpriteNode` or `SKShapeNode` positioned below puddle surface
- Updated each frame when creature is within puddle range: mirror creature's X position, use creature outline simplified to 1-pixel height
- Ripple: `SKAction.scaleX(by:y:duration:)` oscillation on reflection node
- Puddle-gaze idle behavior: registered in autonomous behavior pool

**Verification**:
- [ ] Reflection visible when creature walks near/over puddle
- [ ] Reflection moves with creature
- [ ] Ripple effect on walk-through
- [ ] Creature occasionally notices its reflection (tilts head)
- [ ] Reflection is subtle (alpha 0.15) — a discovery moment, not obvious

---

#### P3-T3-05: Ghost Echo

**What**: Faint shadow of the creature's younger form walks alongside it. Available at Sage+ stage.

**Specs**:
- Ghost: alpha 0.08 silhouette of creature at a previous stage (one stage below current)
- Ghost position: 15-25pt behind creature, same Y, same walk cycle but slightly offset timing
- Ghost appears intermittently: 30-second appearances, 2-5 minute cooldown
- Ghost uses Ash color at alpha 0.08 (barely visible — a whisper, not a shout)
- At Apex: ghost can be ANY previous stage, randomly selected each appearance

**Implementation**:
- `GhostEchoNode` clones creature's sprite configuration at the previous stage's size/proportions
- Ghost node added to foreground layer, follows creature with position offset + 0.3s delay
- Appearance: fade in over 5s, persist 30s, fade out over 5s
- Appearance scheduling: random interval between 2-5 minutes during active play
- Ghost animations: simplified walk cycle only (no expressions, no reactions)

**Verification**:
- [ ] Ghost is barely visible (alpha 0.08 — you have to look for it)
- [ ] Ghost shows a smaller, earlier-stage form of the creature
- [ ] Ghost walks behind the creature with slight timing offset
- [ ] Ghost appears only at Sage+ stage
- [ ] Ghost appearances are intermittent, not constant
- [ ] "Past and present coexist" — emotionally resonant, not distracting

---

#### P3-T3-06: HUD System

**What**: Cinematic default — no UI, just the living world. Stats appear contextually on tap.

**Specs**:
- **Default state**: No HUD. Pure world.
- **Tap anywhere** (not on creature): Minimal overlay fades in for 3 seconds
  - Position: bottom-left, 120pt wide
  - Content: hearts (satisfaction), stage name, XP/next threshold, streak count
  - Style: Ash text at alpha 0.7, small (7pt font equivalent)
  - Fade in: 0.2s, hold 3s, fade out: 0.5s
- **Near evolution**: 1pt progress bar at very bottom edge
  - Width: proportional to XP progress within current stage
  - Color: matches creature's primary color
  - At 95%+ progress: bar pulses (alpha oscillation 0.5-1.0, 1Hz)
- **Touch feedback**: Tiny ripple at touch point (2pt radius circle, expand to 6pt over 200ms, fade)

**Implementation**:
- `HUDController` manages overlay node with stat labels
- Overlay triggered by tap-on-empty-space gesture (filtered from creature-tap and object-tap)
- Progress bar: `SKShapeNode` rectangle at Y=0, width calculated from XP state
- Pulse animation: `SKAction.repeatForever` alpha oscillation at 95%+
- Touch ripple: recycled `SKShapeNode` circle from a pool of 3

**Verification**:
- [ ] Default screen has zero HUD elements visible
- [ ] Tap shows stats overlay for exactly 3 seconds
- [ ] Stats are readable but unobtrusive (small, low alpha, bottom-left)
- [ ] Progress bar appears near evolution threshold
- [ ] Progress bar pulses at 95%+ (visible urgency cue)
- [ ] Touch ripple is subtle and immediate

---

#### P3-T3-07: Near-Evolution Progress Bar

**What**: A 1-pixel progress bar at the bottom edge that appears as the creature approaches its next stage.

**Specs**:
- Appears when creature is within 80% of next stage threshold
- Height: 1pt (single pixel row at very bottom of Touch Bar)
- Width: `(current_xp - stage_start) / (next_stage_threshold - stage_start) * scene_width`
- Color: creature's diet-influenced primary color
- At 95%+: pulsing animation (alpha 0.5 → 1.0, 1Hz sinusoidal)
- At 99%+: pulse intensifies (0.3 → 1.0, 2Hz) and color shifts toward Gilt
- Disappears during evolution ceremony, reappears at 0% for next stage

**Implementation**:
- `EvolutionProgressBar` as `SKShapeNode` at Y=0, Z=high (above world, below HUD)
- Updated on XP change events (not every frame)
- Pulse: `SKAction` with `customAction` for sine-wave alpha modulation
- Color transition at 99%: interpolate from creature color toward Gilt over the final 1%

**Verification**:
- [ ] Bar appears at 80% progress toward next stage
- [ ] Bar width accurately reflects XP progress
- [ ] Pulse begins at 95% (visible anticipation)
- [ ] Pulse intensifies at 99% (imminent evolution)
- [ ] Bar is exactly 1pt tall (minimal, not distracting)
- [ ] Bar disappears cleanly during evolution ceremony

---

#### P3-T3-08: Hunger Desaturation

**What**: When the creature's satisfaction is low, the world itself communicates hunger — not via UI bars, but through environmental state.

**Specs** (from vision HUD Philosophy):
- When satisfaction drops below 25: world desaturates gradually
- Flowers close (if any flower objects exist, they switch to a "closed" sprite state)
- Trees go bare (tree objects switch to leafless variant)
- Ground color shifts toward Ash (desaturation by blending toward gray)
- Desaturation intensity: `max(0, (25 - satisfaction) / 25.0)` — at satisfaction 0, full desaturation
- Recovery: when satisfaction rises above 30, world re-saturates over 30 seconds

**Implementation**:
- `WorldHungerController` monitors creature satisfaction via state
- Desaturation: full-scene `SKEffectNode` with a desaturation CIFilter, or simpler: tint overlay with Ash color at dynamic alpha
- Object state changes: flower/tree objects have alternate "wilted" texture frames
- Recovery crossfade: 30-second linear interpolation back to full color

**Verification**:
- [ ] World visibly desaturates when satisfaction < 25
- [ ] Flowers close, trees lose leaves during hunger
- [ ] Recovery is gradual (30s re-saturation)
- [ ] No HUD bars used — the world IS the indicator
- [ ] Performance: desaturation filter < 0.1ms per frame

---

#### P3-T3-09: Visual Event Spectacles

**What**: Implement the visual spectacle effects for `pushling_world("event")`. These are one-shot visual events Claude can trigger.

**Specs** (7 event types from vision doc):
| Event | Visual | Duration |
|-------|--------|----------|
| `shooting_star` | Bright Gilt streak across sky (left to right), particle trail, brief flash at end | 2s |
| `aurora` | Undulating curtain of Moss/Tide/Dusk at top of screen, gentle wave animation | 30-60s |
| `bloom` | All flower/plant objects simultaneously burst with color particles, brief Moss pulse | 5s |
| `eclipse` | Moon (if night) or sun indicator dims, world darkens briefly, eerie Dusk tint | 20s |
| `festival` | Confetti particles (all palette colors), objects bob happily, Gilt sparkles everywhere | 15s |
| `fireflies` | 8-15 small Gilt dots with random drift, gentle pulse, fade in/out individually | 30-60s |
| `rainbow` | Curved arc of palette colors across top half of sky, subtle, ethereal | 20s |

- Each event is a one-shot SpriteKit animation sequence
- Events are queued — only 1 active at a time
- Events layer above world, below creature speech bubbles
- Creature reacts to events: eyes widen, watches (generic "wonder" expression)
- Events can be combined with weather/time overrides for full environmental control

**Implementation**:
- `VisualEventManager` with pre-configured `SKEmitterNode` setups per event type
- Each event: create/recycle nodes, run SKAction sequence, remove on completion
- Node budget: events use max 10-15 temporary nodes, released after event ends
- Aurora uses a procedural shader or pre-rendered gradient strip with sine-wave distortion

**Verification**:
- [ ] All 7 event types produce visible, distinct spectacles
- [ ] Events respect node budget (< 15 additional nodes)
- [ ] Creature shows wonder expression during events
- [ ] Events queue correctly (no overlapping spectacles)
- [ ] Performance: events stay within frame budget at peak complexity

---

#### P3-T3-10: Repos Table Schema

**What**: Create the SQLite table for tracking repos and their landmark associations. Referenced by P3-T1-07 and P3-T1-08 but the schema was not defined in Phase 1.

**Acceptance Criteria**:
- Table: `repos`
- Columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `path` | TEXT NOT NULL UNIQUE | Absolute path to repo root |
| `name` | TEXT NOT NULL | Repository name (directory name) |
| `landmark_type` | TEXT NOT NULL | One of 9 landmark types from vision doc |
| `dominant_language` | TEXT | Most common file extension |
| `world_x_position` | REAL NOT NULL | Landmark's X position in world-space |
| `commit_count` | INTEGER NOT NULL DEFAULT 0 | Total commits eaten from this repo |
| `analyzed_at` | TEXT NOT NULL | ISO 8601 of last analysis |
| `created_at` | TEXT NOT NULL | ISO 8601 of when repo was first tracked |

- Add this as a schema migration (append to Phase 1 migration system)
- Index on `name` for landmark lookups
- Used by: landmark system (Phase 3), `pushling_sense("surroundings")` (Phase 4), new repo surprise (Phase 8)

---

#### P3-T3-11: Ruin Inscriptions

**What**: Scattered throughout the terrain, ruin pillar objects can display journal fragments when the creature examines them. This is one of the 7 channels for surfacing creature memories.

**Specs** (from vision doc: Journal > Surfaced via > ruin inscriptions):
- Ruin pillar objects (already in terrain object pool) occasionally contain inscriptions
- When creature autonomously examines a ruin (interaction template: "examining"), there is a 30% chance it reads an inscription
- Inscription content: a short fragment from the creature's journal (oldest entries preferred — these are "ancient" memories)
- Visual: tiny text (5pt, Ash color at 60% opacity) appears on the ruin for 3 seconds
- Creature tilts head while reading, looks thoughtful after
- Available at Beast+ stage (creature needs literacy to read)
- Sage+ creatures may narrate the inscription aloud

**Implementation**:
- `RuneInscriptionSystem` queries oldest journal entries, selects fragments
- Fragment generation: first 10 words of journal summary, wrapped in quotes
- Integration with terrain object interaction system (P3-T1-04 + P7-T2-08)
- Maximum 1 inscription reading per 30 minutes (rare, special)

**Verification**:
- [ ] Ruin examinations occasionally reveal inscriptions (30% chance)
- [ ] Inscription text is from actual journal entries
- [ ] Text is tiny and atmospheric (not intrusive)
- [ ] Only appears at Beast+ stage
- [ ] Creature reacts appropriately (thoughtful expression)

---

## Integration Points

| This Phase Provides | Used By |
|---------------------|---------|
| Weather state + biome data | Phase 4: `pushling_sense("surroundings")` returns weather, terrain, biome, time |
| Repo landmark system | Phase 4: `pushling_sense("surroundings")` includes nearby landmarks |
| Weather override hook | Phase 4: `pushling_world("weather", ...)` changes weather via IPC |
| Time override hook | Phase 4: `pushling_world("time_override", ...)` changes sky temporarily |
| Sky/weather visual state | Phase 4: `pushling_sense("visual")` screenshot captures current atmosphere |
| World complexity controller | Phase 6: visual earned complexity gates interactive features |
| Terrain object system | Phase 7: `pushling_world("create"/"place")` adds objects to the world |
| Landmark manager | Phase 7: new repo discovery surprise triggers landmark creation |

## QA Gate

- [ ] Parallax creates convincing depth at 30pt height
- [ ] Terrain recycles seamlessly — no popping, no memory growth after 5 minutes of walking
- [ ] Weather transitions are smooth — no color snapping, no particle discontinuities
- [ ] Repo landmarks appear for tracked repos and scroll at correct parallax speed
- [ ] Day/night cycle matches wall clock (verify at 4 time periods minimum)
- [ ] Frame budget: <5.7ms total with full world + creature (profile with Instruments)
- [ ] Node count: <120 with typical scene content (creature + terrain + weather + sky)
- [ ] Biome transitions are gradual (50-unit gradient, no hard boundaries)
- [ ] OLED true-black verified in void areas at night
- [ ] Visual earned complexity: Spore world is sparse, Beast world is rich
- [ ] All colors use P3 palette (no off-palette colors in any state)
- [ ] Creature reacts to weather changes appropriately
- [ ] 8-color palette reads beautifully on OLED — "luminous pixel life" achieved
