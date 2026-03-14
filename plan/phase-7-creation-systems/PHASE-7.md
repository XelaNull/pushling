# Phase 7: Creation Systems

## Goal

Claude can persistently expand the creature's repertoire — teaching tricks, placing custom objects, and instilling habits. The creature's world accumulates AI-directed personality that persists offline. Behavior breeding produces emergent self-taught behaviors.

## Dependencies

- Phase 4 (Embodiment — MCP tools working, IPC protocol operational, pending_events flowing)
- Phase 6 (Interactivity — object interaction via touch, gesture system, surprise scheduling foundation)
- Shared interfaces frozen in Phase 1: choreography notation, object definition format, SQLite schema (teach/nurture/objects tables)

## Cross-Phase Connections

| This Phase Produces | Consumed By Phase 8 |
|---------------------|---------------------|
| Taught behaviors at Signature mastery | P8-T1-10: surprise variants (Signature tricks play as surprises) |
| Placed objects (campfire, cardboard_box) | P8-T1-03/#34: head-in-box surprise; P8-T1-10: campfire stories |
| Preference valence (+0.8 loves rain) | P8-T1-10: preference-modified surprises (rain zoomies) |
| Nurture history log | P8-T2-04: journal entries surfaced through dreams/display/MCP |
| Object legacy shelf | P8-T2-05: dream appearances of removed objects |
| Companion system | P8-T1-03/#31: chattering at bird companion |
| Behavior breeding hybrids | P8-T2-04: journal milestone "invented a new trick" |

---

## Track 1: Teach System — pushling_teach (P7-T1)

**Agents**: mcp-tools (teach tool implementation), swift-behavior (taught behavior engine, mastery system), swift-creature (animation track execution), swift-state (SQLite tables)

**Goal**: Claude can compose, preview, refine, and commit persistent tricks that the creature performs autonomously with personality-filtered variation, improving mastery over time, replaying in dreams, and occasionally breeding into hybrids.

### Tasks

#### P7-T1-01: Choreography Notation Parser
**Agent**: mcp-tools
**Depends on**: Phase 1 frozen choreography notation interface
**Work**:
- Implement JSON schema validation for multi-track choreography definitions
- Validate required fields: `name` (string, 1-30 chars), `duration_s` (0.5-30.0), `stage_min` (one of 6 stages), `category` (string)
- Validate `tracks` object: each key must be a valid track name (see P7-T1-02), each value an array of keyframes
- Keyframe validation: `t` (float, 0.0 to duration_s), plus track-specific fields
- Validate `triggers` object (see P7-T1-10)
- Fuzzy-match invalid semantic values to nearest valid option (never hard-reject, always suggest)
- Return helpful error messages listing valid options for every invalid field
- Cap: max 50 keyframes per track, max 13 tracks per behavior

**Deliverable**: Parser that accepts choreography JSON input and returns either a validated/normalized definition or a detailed error with valid alternatives.

#### P7-T1-02: 13 Animatable Tracks
**Agent**: swift-creature
**Depends on**: Phase 2 creature composite node (body parts exist as independent SKNodes)
**Work**:
- Define semantic state vocabulary for each of the 13 tracks:

| Track | Named States (examples) | State Count |
|-------|------------------------|-------------|
| `body` | stand, crouch, sit, loaf, roll_side, roll_back, arch, stretch, curl | ~12 |
| `head` | neutral, tilt_left, tilt_right, look_up, look_down, nod, shake | ~10 |
| `ears` | neutral, perk, flat, rotate_left, rotate_right, one_forward, droop | ~10 |
| `eyes` | neutral, wide, squint, blink, wink_left, wink_right, closed, happy_squint, x_eyes | ~12 |
| `tail` | sway, poof, wag, wrap, high, low, tuck, lash, still, curl | ~12 |
| `mouth` | closed, open, smile, yawn, chew, lick, blep | ~8 |
| `whiskers` | neutral, forward, back, twitch, droop | ~6 |
| `paw_fl` | neutral, raise, wave, knead, reach, tap | ~8 |
| `paw_fr` | (same as paw_fl) | ~8 |
| `paw_bl` | neutral, raise, kick, stretch, dig | ~6 |
| `paw_br` | (same as paw_bl) | ~6 |
| `particles` | none, sparkle, hearts, stars, music_notes, dust, crumbs, bubbles, fire_wisps | ~10 |
| `aura` | none, glow, pulse, shimmer, expand, contract, rainbow | ~8 |
| `speech` | (text + style, not named states) | N/A |
| `sound` | (sound name, not named states) | N/A |
| `movement` | stay, walk_left, walk_right, run_left, run_right, jump, retreat | ~8 |

- Implement interpolation between states (smooth transitions, not hard snaps)
- Ensure omitted tracks inherit current autonomous behavior (breathing/sway continues)
- Physics layer (breathing sine-wave) overrides all track states — never interrupted

**Deliverable**: All 13 tracks respond to semantic keyframes with smooth interpolation. Omitted tracks are autonomous. Physics layer is inviolable.

#### P7-T1-03: Semantic-to-SpriteKit Translation Layer
**Agent**: swift-creature
**Depends on**: P7-T1-02
**Work**:
- Map every semantic state name to concrete SKNode transforms:
  - `"ears": "perk"` -> both ear nodes rotate +15 degrees, scale Y 1.1, 0.15s ease-out
  - `"tail": "poof"` -> tail node scale 1.3x, add fur-puff particle burst, 0.1s snap
  - `"body": "loaf"` -> body squish Y 0.85, paws tuck, 0.5s ease-in-out
- Implement interpolation curves: ease-in, ease-out, ease-in-out, linear, spring (overshoot)
- Handle concurrent track animations (ears perk while body crouches while tail poofs)
- Conflict resolution: if two tracks affect overlapping nodes, later keyframe wins
- Frame budget: translation layer must complete in <0.3ms per behavior per frame

**Deliverable**: Any semantic keyframe produces correct, visually coherent SpriteKit node transforms at <0.3ms per frame.

#### P7-T1-04: Personality Permeation Engine
**Agent**: swift-behavior
**Depends on**: P7-T1-03, Phase 2 personality system
**Work**:
- Filter every taught behavior performance through the creature's 5 personality axes:
  - **Energy** (0.0-1.0): scales animation speed (0.7x at calm, 1.3x at hyper), amplitude of movements
  - **Verbosity** (0.0-1.0): probability of speech track firing (low verbosity may suppress speech keyframes)
  - **Focus** (0.0-1.0): precision of timing (high focus = tight timing, low = loose/wandering)
  - **Discipline** (0.0-1.0): consistency of execution (high = clockwork, low = variable each time)
  - **Specialty**: no direct permeation effect (visual only, handled by creature renderer)
- Apply modifiers multiplicatively, not additively — extreme personalities produce extreme performances
- Two creatures performing the same taught behavior should look measurably different:
  - Calm-focused creature's "roll over": slow, deliberate, precise landing
  - Hyper-chaotic creature's "roll over": fast, wild, overshoots, scrambles to feet
- Unit test: same choreography JSON, two personality profiles, output keyframe timings differ by >20%

**Deliverable**: Personality axes produce measurably different performances of identical choreography. Verifiable via unit test with two personality profiles.

#### P7-T1-05: 4-Tier Mastery System
**Agent**: swift-behavior
**Depends on**: P7-T1-04, P7-T1-12 (SQLite tables for performance count tracking)
**Work**:
- Track performance count per taught behavior in `behavior_performances` table
- Implement 4 mastery tiers with distinct animation qualities:

| Tier | Performances | Timing Jitter | Visual Characteristics |
|------|-------------|---------------|----------------------|
| Learning | 0-2 | +/- 20% | Clumsy: overshoots, false starts, hesitation pauses, wobble on landings |
| Practiced | 3-9 | +/- 10% | Smoother: occasional overshoot, gaining confidence, fewer pauses |
| Mastered | 10-24 | +/- 3% | Clean: personality flair added (flourish at end, signature pause, style) |
| Signature | 25+ | +/- 1% | Embellished: spontaneous additions (extra spin, audience check, style variations) |

- Mastery level affects creature's expression during performance:
  - Learning: concentrated, tongue out, uncertain eyes
  - Practiced: focused but relaxed
  - Mastered: confident, slight pride
  - Signature: effortless, might look at camera mid-trick
- Mastery progression is permanent (stored in SQLite) — does not decay

**Deliverable**: Performance count drives visually distinct mastery tiers. First attempt is charmingly clumsy. 25th is effortlessly stylish.

#### P7-T1-06: Fumble System
**Agent**: swift-behavior
**Depends on**: P7-T1-05
**Work**:
- Implement fumble behaviors for Learning and Practiced tiers:
  - **Timing slips**: keyframe fires 100-300ms late, creature rushes to catch up
  - **Overshoots**: movement goes 20-40% past target, creature corrects (e.g., over-rotates on spin, stumbles)
  - **False starts**: creature begins, stops, shakes head, tries again (25% chance at Learning)
  - **Wrong track**: briefly does wrong body part action, quickly corrects (10% at Learning)
- Fumbles should be endearing, not frustrating — the creature is trying its best
- Fumble frequency decreases linearly within each mastery tier (performance 0 has more fumbles than performance 2)
- No fumbles at Mastered or Signature tiers
- Journal logs notable fumbles: "Zepus tried to roll over but fell off the side. Looked embarrassed."

**Deliverable**: Learning-tier performances include charming fumbles that decrease with practice. Fumbles are logged in journal.

#### P7-T1-07: Compose-Preview-Refine-Commit Workflow
**Agent**: mcp-tools
**Depends on**: P7-T1-01, P7-T1-03, IPC protocol (Phase 1)
**Work**:
- Implement `pushling_teach` MCP tool with 4 sub-actions:
  - **compose**: validate choreography, return normalized definition + warnings. Does not play or store.
  - **preview**: send choreography to daemon via IPC, daemon plays it once on Touch Bar. Returns timing data and any rendering notes. Creature does NOT learn it.
  - **vocabulary**: return all valid values for all 13 tracks + all trigger types + all categories. Claude uses this to know what's available.
  - **commit**: store finalized choreography in SQLite. Triggers 3-second learning ceremony (P7-T1-09). Behavior enters idle rotation at Learning mastery.
- Workflow: Claude calls compose (validates) -> preview (watches) -> refine (adjusts) -> preview again -> commit (persists)
- Also support: **list** (all taught behaviors with mastery levels), **remove** (delete a behavior, moved to legacy), **modify** (update choreography, resets mastery to Practiced if changes are significant)
- Error messages must explain what's wrong and suggest fixes: "Track 'ear' not found. Did you mean 'ears'? Valid tracks: body, head, ears, eyes, tail, mouth, whiskers, paw_fl, paw_fr, paw_bl, paw_br, particles, aura, speech, sound, movement"

**Deliverable**: Full compose-preview-refine-commit workflow via MCP. Claude can iterate on tricks before committing.

#### P7-T1-08: Vocabulary Sub-Action
**Agent**: mcp-tools
**Depends on**: P7-T1-02
**Work**:
- Implement `pushling_teach("vocabulary")` response:
  - Return complete list of valid values for all 13 tracks
  - Return all valid trigger types with parameter schemas
  - Return all valid categories
  - Return current creature's stage and which tracks are available at that stage
  - Return examples: 3 sample choreography definitions (simple, medium, complex)
- Response format: structured JSON that Claude can reference when composing
- Include personality axis descriptions so Claude can anticipate permeation effects

**Deliverable**: Claude can call vocabulary once per session and know exactly what body-part states, triggers, and categories are available.

#### P7-T1-09: Learning Ceremony Animation
**Agent**: swift-creature
**Depends on**: P7-T1-03
**Work**:
- 3-second ceremony that plays when a new behavior is committed:
  1. **Focus** (0-0.8s): creature stops, ears perk, eyes widen, turns toward "nothing" (looking inward)
  2. **Clumsy attempt** (0.8-2.0s): plays the taught behavior at Learning tier — fumbles, overshoots, wobbles
  3. **Realization** (2.0-3.0s): eyes light up (Gilt sparkle), ears snap forward, brief particle burst, small celebratory bounce. Expression: pride mixed with uncertainty
- Ceremony is interruptible by human touch (pauses, acknowledges, resumes)
- Journal entry: "Zepus learned a new trick: [name]! It was... clumsy."
- Notification via pending_events so Claude sees the ceremony completed

**Deliverable**: 3-second learning ceremony plays on every new behavior commit. Visually communicates "the creature just learned something."

#### P7-T1-10: Trigger System
**Agent**: swift-behavior
**Depends on**: P7-T1-12
**Work**:
- Implement trigger evaluation for when taught behaviors should play autonomously:

| Trigger | Parameters | Example |
|---------|-----------|---------|
| `idle_weight` | float 0.0-1.0 | `0.3` — 30% chance when idle behavior selector runs |
| `on_touch` | bool | `true` — may play when creature is tapped |
| `on_commit_type` | string[] | `["test", "refactor"]` — plays after eating matching commit types |
| `emotional_conditions` | dict of {axis: {min?, max?}} | `{"contentment": {"min": 40}}` — only when contentment >= 40 |
| `time_conditions` | dict of {after?, before?} | `{"after": "18:00", "before": "22:00"}` — evening only |
| `cooldown_s` | int | `300` — minimum seconds between plays of this behavior |
| `contexts` | string[] | `["near_object", "raining", "claude_connected"]` — situational |

- Compound triggers: `all_of` (AND), `any_of` (OR), `none_of` (NOT)
- Trigger evaluation runs every idle behavior selection cycle (when autonomous layer picks next action)
- Priority: behaviors with more specific triggers score higher than generic idle_weight
- Cooldown tracking in memory (not persisted — resets on daemon restart)

**Deliverable**: Taught behaviors fire autonomously based on configurable triggers with compound logic and cooldowns.

#### P7-T1-11: Dream Integration
**Agent**: swift-creature
**Depends on**: P7-T1-05, Phase 2 sleep system
**Work**:
- During creature sleep, mastered behaviors (tier 3+) replay at 0.5x speed
- Ghostly render filter: alpha 0.4, Dusk tint (#7B2FBE), slight blur/glow
- Dream behavior selection: weighted by mastery level (Signature behaviors dream more often)
- Maximum 1 dream-behavior per sleep cycle (don't spam)
- Behavior plays in miniature — creature twitches/moves within the sleep curl position
- Journal entry: "Zepus dreamed about [trick name]"
- Dream behaviors do not count toward mastery performance count

**Deliverable**: Mastered tricks replay during sleep with ghostly visual treatment. Creature "practices in its dreams."

#### P7-T1-12: SQLite Tables
**Agent**: swift-state
**Depends on**: Phase 1 SQLite schema framework
**Work**:
- Create migration for teach system tables:

```sql
-- Taught behavior definitions
CREATE TABLE taught_behaviors (
    id TEXT PRIMARY KEY,           -- UUID
    name TEXT NOT NULL UNIQUE,     -- "roll_over"
    category TEXT NOT NULL,        -- "playful"
    stage_min TEXT NOT NULL,       -- "critter"
    duration_s REAL NOT NULL,      -- 3.0
    choreography TEXT NOT NULL,    -- Full JSON definition
    triggers TEXT NOT NULL,        -- JSON trigger config
    mastery_level INTEGER DEFAULT 0,  -- 0=Learning, 1=Practiced, 2=Mastered, 3=Signature
    performance_count INTEGER DEFAULT 0,
    is_self_taught INTEGER DEFAULT 0, -- 1 if bred from two parents
    parent_a_id TEXT,              -- NULL unless self-taught
    parent_b_id TEXT,              -- NULL unless self-taught
    strength REAL DEFAULT 0.5,    -- Decay value (0.0-1.0)
    created_at TEXT NOT NULL,
    last_performed_at TEXT,
    last_reinforced_at TEXT
);

-- Version history for modified behaviors
CREATE TABLE behavior_versions (
    id TEXT PRIMARY KEY,
    behavior_id TEXT NOT NULL REFERENCES taught_behaviors(id),
    version INTEGER NOT NULL,
    choreography TEXT NOT NULL,    -- Snapshot of choreography at this version
    created_at TEXT NOT NULL
);

-- Individual performance log (for mastery tracking)
CREATE TABLE behavior_performances (
    id TEXT PRIMARY KEY,
    behavior_id TEXT NOT NULL REFERENCES taught_behaviors(id),
    performed_at TEXT NOT NULL,
    trigger_type TEXT,             -- "idle", "touch", "commit", "dream"
    mastery_at_time INTEGER,       -- Mastery level when performed
    fumble_count INTEGER DEFAULT 0,
    personality_snapshot TEXT       -- JSON of personality axes at time of performance
);
```

- Indexes on `taught_behaviors(name)`, `taught_behaviors(category)`, `behavior_performances(behavior_id, performed_at)`
- Enforce max 30 active taught behaviors (reject inserts past cap with helpful error)

**Deliverable**: SQLite tables for teach system with version history and performance tracking. 30-behavior cap enforced.

#### P7-T1-13: Idle Rotation Density Governor
**Agent**: swift-behavior
**Depends on**: P7-T1-10
**Work**:
- Enforce idle behavior composition: 80% pure cat behaviors (Phase 2 Layer 1), 20% taught/special
- Maximum 3 taught behavior performances per hour
- Taught behaviors never play back-to-back — at least 1 autonomous behavior between them
- If creature has 0 taught behaviors: 100% cat behaviors (no change from Phase 2)
- If creature has 30 taught behaviors: still 80/20 split — selection weighted by idle_weight triggers
- Track hourly count in memory, reset each clock-hour
- Emergency throttle: if 3 taught behaviors fire within 10 minutes, suppress for remaining 50 minutes

**Deliverable**: Taught behaviors enhance idle rotation without overwhelming it. The creature is still a cat first, performer second.

#### P7-T1-14: Behavior Breeding
**Agent**: swift-behavior
**Depends on**: P7-T1-05, P7-T1-12
**Work**:
- When two taught behaviors fire within 30 seconds of each other: 5% chance of breeding
- Breeding algorithm:
  1. Select trigger conditions from parent A (the one that fired first)
  2. Select movement tracks from parent B (the one that fired second)
  3. Merge speech/particle tracks from both (interleave by timestamp)
  4. Filter through creature personality (P7-T1-04)
  5. Auto-generate name: "[parent_a_name]-[parent_b_name]" (e.g., "roll-dance")
  6. Set `is_self_taught = 1`, store parent IDs
- Hybrid starts at Learning mastery with its own performance count
- Hybrids decay faster: 0.03/day (vs taught behaviors which follow nurture decay tiers)
- Claude can reinforce a hybrid via `pushling_teach("reinforce", {name})` — converts it to a regular taught behavior with standard decay
- Max 5 self-taught behaviors at a time (subset of the 30-behavior cap)
- Journal entry: "Zepus invented a new trick: [name]!" with parent attribution
- Claude discovers hybrids via `pushling_recall("milestones")` or `pushling_teach("list")`

**Deliverable**: Creature autonomously combines taught behaviors into self-invented hybrids. Hybrids can be reinforced by Claude to become permanent.

### Track 1 Deliverable Summary

Claude can teach tricks that persist, improve with mastery, play in idle/dreams, and occasionally breed into new behaviors. The creature is a learning, practicing, inventing performer.

---

## Track 2: Objects System — pushling_world("create") (P7-T2)

**Agents**: mcp-tools (world create/modify/remove), swift-world (object rendering, placement, LOD), swift-creature (interaction animations), swift-state (SQLite tables), assets-objects (base shape textures)

**Goal**: Claude can create persistent objects with rich autonomous creature interaction, forming a curated world that the creature inhabits and shapes through cat-like behavior.

### Tasks

#### P7-T2-01: 60 Base Shape Library
**Agent**: assets-objects
**Depends on**: Phase 1 asset pipeline, 8-color P3 palette (Phase 3)
**Work**:
- Create 20 geometric primitive textures (all palette-locked):
  - sphere, cube, box, triangle, dome, cylinder, ring, diamond, hexagon, star_shape, crescent, arch, wedge, slab, pillar, cone, pyramid, disc, frame, pedestal
- Create 40 iconic mini-sprite textures:
  - Toys: ball, yarn_ball, feather, mouse_toy, string, bell, paper_ball, laser_dot, fish_toy, ribbon
  - Furniture: bed, perch, box, basket, hammock, shelf, platform, cushion, tunnel, cave
  - Decorative: flower, crystal, candle, lantern, flag, banner, gem, orb, trophy, statue
  - Interactive: music_box, mirror, fountain, windchime, snow_globe, kaleidoscope, compass, hourglass, telescope, wheel
- All sprites: 6-12pt tall, 1-bit silhouette style with selective color accents
- Texture atlas: single atlas, <128KB total

**Deliverable**: 60 base shape textures in a single atlas, palette-locked, ready for SpriteKit rendering.

#### P7-T2-02: Object Definition Parser
**Agent**: mcp-tools
**Depends on**: Phase 1 frozen object definition format, P7-T2-01
**Work**:
- Parse 3 creation interfaces:
  1. **Preset** (one word): `{"preset": "ball"}` — resolves to full definition from preset table
  2. **Smart default** (partial): `{"base": "spr_ball", "color": {"primary": "ember"}}` — fills missing fields from base defaults
  3. **Full definition**: all fields specified explicitly
- Full definition schema:

```json
{
  "base": "spr_ball",           // Required: one of 60 base shapes
  "name": "Bouncy Ball",        // Optional: display name (auto-generated if omitted)
  "size": 1.0,                  // Optional: scale factor 0.5-2.0 (default 1.0)
  "color": {
    "primary": "ember",         // Required: one of 7 non-black palette colors
    "secondary": "gilt",        // Optional: accent color
    "pattern": "solid"          // Optional: solid, stripe, dots, gradient, glow
  },
  "effects": ["bob"],           // Optional: array of glow, pulse, bob, spin, sway, particle
  "physics": {
    "weight": "light",          // light, medium, heavy (affects pushability)
    "bounciness": 0.8,          // 0.0-1.0
    "rollable": true,
    "pushable": true,
    "carryable": true           // creature can pick it up
  },
  "placement": "near",          // near (near creature), random, center, or x-position
  "interaction": "batting_toy", // One of 14 interaction templates (P7-T2-08)
  "wear_rate": 0.01             // 0.0-0.1 per interaction (default varies by interaction type)
}
```

- Validate all fields, fuzzy-match invalid values, return helpful errors
- Generate unique ID for each object
- Smart defaults: `base` alone is sufficient — derive interaction from shape category, color from palette rotation, physics from shape properties

**Deliverable**: Parser that accepts any of 3 creation interfaces and produces a fully resolved object definition.

#### P7-T2-03: Palette-Locked Coloring System
**Agent**: swift-world
**Depends on**: P7-T2-01, Phase 3 P3 palette system
**Work**:
- 7 non-black P3 colors available for objects: Bone, Ember, Moss, Tide, Gilt, Dusk, Ash
- Pattern rendering:
  - `solid`: entire sprite tinted with primary color
  - `stripe`: alternating primary/secondary horizontal bands
  - `dots`: primary base with secondary dot pattern overlay
  - `gradient`: primary at top, secondary at bottom, blended
  - `glow`: primary with additive-blend glow halo in secondary
- Color applied via SKShader or tint — preserves silhouette detail
- All objects always look native to the world aesthetic

**Deliverable**: Objects render in palette-locked colors with 5 pattern options, always visually consistent with the world.

#### P7-T2-04: Object Effects Engine
**Agent**: swift-world
**Depends on**: P7-T2-03
**Work**:
- 6 attachment effects for objects:
  - `glow`: additive-blend halo, subtle pulse (0.8-1.0 alpha, 2s period)
  - `pulse`: scale oscillation (0.95-1.05, 1.5s period)
  - `bob`: Y-position sine wave (+/- 1pt, 2s period)
  - `spin`: continuous rotation (360 degrees per 4s)
  - `sway`: rotation oscillation (+/- 5 degrees, 3s period)
  - `particle`: attach particle emitter (sparkle, smoke, drip, flame — from existing particle system)
- Effects stack (glow + bob = glowing bobbing object)
- Performance constraint: max 2 particle-emitting objects rendering simultaneously
- Effects pause when object is off-screen (LOD optimization)

**Deliverable**: Objects support 6 stackable visual effects within performance budget.

#### P7-T2-05: Object Physics
**Agent**: swift-world
**Depends on**: P7-T2-02
**Work**:
- 3 weight categories affecting creature interaction:
  - `light` (feather, paper_ball, ribbon): pushable by walking, carryable, knockable off edge
  - `medium` (ball, yarn_ball, music_box): pushable with effort, carryable at Beast+, not easily knocked
  - `heavy` (bed, perch, fountain): not pushable, not carryable, permanent placement
- Physics properties:
  - `bounciness` (0.0-1.0): restitution coefficient when pushed/dropped
  - `rollable`: whether object rolls or slides when pushed
  - `pushable`: whether creature can push it by walking into it
  - `carryable`: whether creature can pick it up in mouth
- Interaction physics: creature's body pushes light objects on contact (SpriteKit physics body)
- Object-to-object collision: objects can bump each other
- Gravity: objects fall to ground line, bounce based on bounciness
- Frame budget: physics step for placed objects <0.2ms

**Deliverable**: Objects have physical properties that govern creature interaction and world behavior.

#### P7-T2-06: 20 Named Presets
**Agent**: mcp-tools
**Depends on**: P7-T2-02, P7-T2-08
**Work**:
- Define 20 presets with curated defaults:

| Preset | Base | Color | Physics | Interaction | Notes |
|--------|------|-------|---------|-------------|-------|
| `ball` | spr_ball | Ember, solid | light, bouncy 0.8, rollable, pushable, carryable | batting_toy | Classic cat toy |
| `yarn_ball` | spr_yarn_ball | Tide, solid | light, bouncy 0.3, rollable, pushable, carryable | string_play | Unravels when batted |
| `cozy_bed` | spr_bed | Bone, gradient | heavy | sitting | Creature curls up in it |
| `cardboard_box` | spr_box | Ash, solid | medium | hiding | If-I-fits-I-sits magnet |
| `campfire` | spr_candle | Ember, glow | heavy, particle: flame | watching | Warmth, stories, gathering point |
| `music_box` | spr_music_box | Gilt, solid | medium | listening | Plays melody, creature sways |
| `little_mirror` | spr_mirror | Tide, glow | medium | reflecting | Creature discovers reflection |
| `treat` | spr_orb | Moss, pulse | light, carryable | eating | Consumable: +15 satisfaction |
| `fresh_fish` | spr_fish_toy | Tide, solid | light, carryable | eating | Consumable: +20 satisfaction, cat goes wild |
| `scratching_post` | spr_pillar | Ash, stripe | heavy | scratching | Creature stretches and scratches |
| `feather_toy` | spr_feather | Dusk, solid | light, bouncy 0.9, carryable | chasing | Floats erratically when batted |
| `tiny_fountain` | spr_fountain | Tide, glow, particle: drip | heavy | watching | Water sounds, creature paws at water |
| `crystal` | spr_crystal | Dusk, glow | heavy | examining | Creature stares into it, sparkle reflection |
| `mouse_toy` | spr_mouse_toy | Ash, solid | light, rollable, carryable | chasing | Creature stalks and pounces |
| `flower` | spr_flower | Ember, solid | light | examining | Creature sniffs, may sneeze |
| `platform` | spr_platform | Bone, solid | heavy | climbing | Creature perches on top |
| `snow_globe` | spr_snow_globe | Tide, pulse | medium | watching | Shake effect, creature mesmerized |
| `lantern` | spr_lantern | Gilt, glow, particle: flame | medium | watching | Night companion, warm light |
| `bell` | spr_bell | Gilt, solid | light, pushable | pushing | Rings when pushed, creature startles then pushes again |
| `cushion` | spr_cushion | Dusk, solid | medium | sitting | Soft sitting spot, kneading trigger |

- Each preset creates a fully functional object with one word
- Claude calls: `pushling_world("create", {"preset": "ball"})` — done

**Deliverable**: 20 named presets, each creating a complete object with one-word invocation.

#### P7-T2-07: Smart Defaults
**Agent**: mcp-tools
**Depends on**: P7-T2-02, P7-T2-06
**Work**:
- When only `base` is provided, auto-derive everything else:
  - Color: rotate through palette based on existing object colors (avoid duplicates)
  - Physics: derive from shape (round = rollable, tall = not pushable, small = light)
  - Interaction: derive from shape category (ball-like = batting_toy, flat = sitting, tall = climbing)
  - Placement: "near" (creature can immediately investigate)
  - Wear rate: derive from interaction type (toys wear faster than furniture)
  - Name: derive from base shape ("A Little Ball", "A Cozy Bed")
- When partial fields provided: fill only missing fields from smart defaults
- Smart defaults should make 90%+ of object creation require only 1-3 fields

**Deliverable**: Single-field object creation produces sensible, complete objects. Smart defaults minimize required input.

#### P7-T2-08: 14 Interaction Templates
**Agent**: swift-creature
**Depends on**: P7-T1-03 (semantic-to-SpriteKit translation), Phase 2 creature animations
**Work**:
- Implement 14 interaction animation sequences:

**Toy (5)**:
1. `batting_toy`: creature approaches, crouches, bats with paw, object moves, creature chases, bats again. 5-8s loop.
2. `chasing`: creature stalks (predator crouch, butt wiggle), pounces, object escapes, creature chases across bar. 6-10s sequence.
3. `carrying`: creature picks up in mouth, walks proudly, sets down somewhere new. 4-6s.
4. `string_play`: creature bats, thread/yarn unravels, creature gets tangled, shakes free. 8-12s.
5. `pushing`: creature walks into object, pushes it along ground, watches it roll/slide, follows. 4-6s.

**Furniture (4)**:
6. `sitting`: creature approaches, circles once, settles down, curls up. Eyes close. 6-8s to settle, then holds.
7. `climbing`: creature approaches, crouches, jumps up, balances, sits on top, surveys domain. 4-6s.
8. `scratching`: creature approaches, stretches up, front paws rake surface, stretches, satisfied expression. 4-6s.
9. `hiding`: creature approaches, peeks inside, squeezes in, disappears (only tail visible). 4-6s.

**Decorative (2)**:
10. `examining`: creature approaches cautiously, sniffs, tilts head, paws gently, sniffs again. 4-6s.
11. `rubbing`: creature approaches, cheek-rubs against object, circles, rubs other cheek. Scent marking. 3-5s.

**Interactive (3)**:
12. `listening`: creature sits near, ears rotate toward object, eyes close, sways gently. 6-10s.
13. `watching`: creature sits or lies near, stares intently, head follows movement (if any). 6-10s.
14. `reflecting`: creature discovers reflection (mirror/water), tilts head, paws at it, does double-take. 6-8s.

**Consumable (1)**:
15. `eating`: creature approaches, sniffs, eats in 3-4 bites, licks lips, satisfaction boost. Object disappears. 4-6s.

- Each template is parameterized by creature stage (Critter is clumsier, Beast is confident, Sage is contemplative)
- Personality permeation applies (calm creature interacts slower, hyper creature interacts faster)

**Deliverable**: 14 interaction animations, each a complete creature-object interaction sequence parameterized by stage and personality.

#### P7-T2-09: Autonomous Interaction Engine
**Agent**: swift-behavior
**Depends on**: P7-T2-08, Phase 2 emotion system
**Work**:
- 7-factor attraction scoring determines when creature approaches an object:

| Factor | Weight | Description |
|--------|--------|-------------|
| Base weight | 1.0 | Interaction template base (toys > furniture > decorative) |
| Personality affinity | 0.5-2.0 | Hyper creatures prefer toys, calm prefer furniture |
| Mood modifier | 0.3-1.5 | Happy creature interacts more, sad creature less |
| Recency decay | 0.2-1.0 | Objects interacted with recently score lower (prevent fixation) |
| Novelty bonus | 1.0-3.0 | Recently placed objects get 3x bonus, decays over 24 hours to 1.0 |
| Proximity | 0.5-1.5 | Closer objects score higher (creature doesn't walk across bar for low-score object) |
| Time-of-day | 0.5-1.5 | Toys score higher during high-energy hours, furniture during low-energy |

- Scoring formula: `base * personality * mood * recency * novelty * proximity * time`
- Interaction decision runs every autonomous behavior selection cycle (same as idle rotation)
- Object interactions count as autonomous behaviors (subject to the 80/20 split from P7-T1-13)
- Maximum 1 object interaction per 5 minutes (prevent object obsession)
- Creature occasionally ignores highest-scoring object for 2nd or 3rd (personality.discipline modulates)

**Deliverable**: Creature autonomously approaches and interacts with objects based on 7-factor scoring. Interactions feel natural and unpredictable.

#### P7-T2-10: Object Wear/Repair Lifecycle
**Agent**: swift-world
**Depends on**: P7-T2-04, P7-T2-09
**Work**:
- Each interaction increments object's wear value (0.0 to 1.0)
- Visual wear stages:
  - 0.0-0.3: pristine (no visual change)
  - 0.3-0.6: worn (slight desaturation, faint crack line)
  - 0.6-0.8: weathered (visible cracks, color fading, slight offset/tilt)
  - 0.8-1.0: battered (heavy cracks, significant fade, wobble animation)
- Creature interaction changes at high wear: interacts less enthusiastically, handles more gently
- Wear does NOT destroy objects (max 1.0, stays battered forever)
- Claude can repair via `pushling_world("modify", {object: "id", repair: true})`
- Repair resets wear to 0.0, adds "patched" visual (small stitch mark, adds character)
- Repair count tracked — heavily repaired objects have multiple patch marks (charming, not ugly)
- Journal entry on repair: "Zepus's [object] was repaired. It looks patched but loved."

**Deliverable**: Objects accumulate visible wear through interaction. Claude can repair them, adding character. Creature adjusts interaction based on wear state.

#### P7-T2-11: Legacy Shelf
**Agent**: swift-state, swift-creature
**Depends on**: P7-T2-12 (implied — objects stored in SQLite)
**Work**:
- When an object is removed via `pushling_world("remove")`:
  - Object removed from rendering
  - Full definition stored in `removed_objects` SQLite table with removal timestamp
  - Location where object was placed stored
- Post-removal behaviors (1-2 days):
  - Creature occasionally walks to where the object was
  - Sniffs the ground, looks around, confused expression
  - Frequency decays over 48 hours
- Sage+ creatures may narrate: "Something was here once..." or "I miss the [object name]"
- Dream appearances: removed objects can appear in dream sequences (ghostly render, P7-T1-11 filter)
- Legacy shelf queryable via MCP: `pushling_recall("objects")` includes removed objects with removal dates
- Capacity: unlimited legacy storage (it's just SQLite rows, minimal space)

**Deliverable**: Removed objects persist in memory. Creature mourns briefly. Objects appear in dreams. Full history queryable.

#### P7-T2-12: Object Cap Enforcement
**Agent**: swift-world, mcp-tools
**Depends on**: P7-T2-02
**Work**:
- Enforce limits:
  - 12 persistent objects maximum (non-consumable)
  - 3 active consumables maximum (don't count against the 12 cap)
  - Minimum 20pt spacing between objects (reject placement if too close, suggest alternative position)
  - Maximum 2 particle-emitting objects rendering simultaneously (disable furthest particle emitter)
- LOD culling for off-screen objects:
  - Objects >200pt from camera: don't render
  - Objects 100-200pt: render without effects
  - Objects <100pt: full render with effects
- When at cap, `pushling_world("create")` returns helpful error: "12 persistent objects placed. Remove one with pushling_world('remove') to make room. Current objects: [list with IDs and names]"
- Node count tracking: each object = 1-3 nodes (base + effect + particle). Total object nodes should stay <40.

**Deliverable**: Object limits enforced with helpful errors. LOD culling prevents off-screen rendering. Node budget maintained.

#### P7-T2-13: Cat Chaos
**Agent**: swift-creature
**Depends on**: P7-T2-05, P7-T2-09
**Work**:
- Surprise #28 integration: creature deliberately knocks light, pushable objects off the edge
- Sequence:
  1. Creature walks to a light pushable object
  2. Sits beside it, looks at camera (breaking fourth wall, 1s)
  3. Raises paw
  4. Pushes object toward edge of world
  5. Object falls off edge with physics (bounce, roll)
  6. Creature watches it fall, looks back at camera. No remorse.
- Object is NOT deleted — it relocates to a random position (falls from sky, lands with bounce)
- 2-hour grace period: recently placed objects (within 2 hours) are exempt from chaos
- Only light+pushable objects eligible (not furniture, not heavy items)
- Maximum 1 chaos event per 4 hours
- Journal entry: "Zepus knocked the [object name] off the edge of the world. Looked at the camera. No remorse."
- Cross-reference: this IS surprise #28 (P8-T1-03). Phase 7 builds the mechanic; Phase 8 integrates it into the surprise scheduler.

**Deliverable**: Creature knocks light objects off edges with cat-like deliberation. Objects relocate. Grace period protects new placements.

#### P7-T2-14: Companion System
**Agent**: swift-world, swift-creature
**Depends on**: P7-T2-09 (interaction engine), Phase 2 creature behavior
**Work**:
- 5 companion NPC types via `pushling_world("companion", {type, name?})`:

| Type | Size | Sprite | Behaviors | Creature Reaction |
|------|------|--------|-----------|------------------|
| `mouse` | 3x2pt | Ash, scurrying animation | Scurry, hide behind objects, peek out, freeze | Stalk, pounce, chase (gentle if preference), catch-and-release |
| `bird` | 3x3pt | Bone, wing flap | Fly overhead, land on objects, hop, preen | Chatter (jaw vibrate), track with eyes, occasional pounce attempt |
| `butterfly` | 2x2pt | Dusk, flutter | Random drift, land on flowers/creature, flutter away | Follow with eyes, gentle chase, sit still when landed on head |
| `fish` | 3x2pt | Tide, swim animation | Swim in water puddles, splash, jump | Watch intently, paw at water, stare for minutes |
| `ghost_cat` | 10x12pt at 15% alpha | Bone, ghostly | Mirror creature behavior at distance, independent walk | Occasional glance, double-take, wave, ignore |

- Max 1 companion at a time (creating new removes previous)
- Companion has simple autonomous AI:
  - 3-4 idle behaviors specific to type
  - Awareness of creature proximity (flee/approach based on type)
  - Awareness of objects (hide behind them, land on them)
- Creature-companion relationship modulated by preferences:
  - Creature that "loves mice" (positive valence): stalks more gently, doesn't pounce as hard
  - Creature that "fears birds": avoids, hunches when bird flies overhead
- Companion named (Claude can provide name, or auto-generated)
- Companion persists across daemon restarts (stored in SQLite)
- Journal entries for companion interactions
- Node budget: companion = 1-2 nodes total

**Deliverable**: 5 NPC companion types with simple autonomous behavior and creature interaction modulated by preferences.

### Track 2 Deliverable Summary

Claude can create persistent objects with rich autonomous creature interaction. The creature's world is a curated, living space with toys, furniture, companions, and the occasional deliberate act of feline chaos.

---

## Track 3: Nurture System — pushling_nurture (P7-T3)

**Agents**: mcp-tools (nurture tool implementation), swift-behavior (habit/quirk/routine engine), swift-creature (reluctant performance), swift-state (SQLite tables)

**Goal**: Claude can persistently shape creature behavior through habits, preferences, quirks, routines, and identity — with organic variation, creature agency, and mastery-based decay.

### Tasks

#### P7-T3-01: Habit Engine
**Agent**: swift-behavior
**Depends on**: Phase 2 behavior system (Layer 1 autonomous behaviors)
**Work**:
- Implement habit evaluation loop:
  1. On each trigger event (commit, idle cycle, time tick, emotion change, etc.), evaluate all active habits
  2. For each matching habit: check frequency modifier, variation, energy cost
  3. Queue matching habits for execution
  4. Execute via Layer 2 priority (habits are above autonomous, below reflexes)
- Habit definition:

```json
{
  "name": "post_feast_stretch",
  "trigger": {"type": "after_event", "event": "commit_large"},
  "behavior": "stretch",
  "behavior_variant": "dramatic",
  "frequency": "often",          // always (90%), often (70%), sometimes (40%), rarely (15%)
  "variation": "moderate",       // strict (5% jitter), moderate (15%), loose (30%), wild (50%)
  "energy_cost": 0.1,            // 0.0-1.0 energy deducted on performance
  "stage_min": "critter"
}
```

- Habits can reference: built-in perform behaviors, taught behaviors by name, or simple expressions
- Priority: later-created habits with same trigger have higher priority (most recent nurture intent wins)
- Maximum 20 active habits

**Deliverable**: Habits fire on triggers with configurable frequency and variation. Queued execution respects behavior stack priority.

#### P7-T3-02: 12 Trigger Types
**Agent**: swift-behavior
**Depends on**: P7-T3-01
**Work**:
- Implement all 12 trigger types:

| Trigger | Parameters | Fires When |
|---------|-----------|------------|
| `after_event` | `{event: "commit"/"commit_large"/"commit_test"/"touch"/"wake"/"evolve"/"surprise"}` | After the specified event completes |
| `on_idle` | `{min_idle_s: 30}` | After N seconds of idle (no triggers, no interaction) |
| `at_time` | `{time: "09:00", window_m: 15}` | Within window around specified time |
| `on_emotion` | `{axis: "contentment", direction: "above"/"below", threshold: 70}` | When emotion axis crosses threshold |
| `on_weather` | `{weather: "rain"/"storm"/"snow"/"clear"/"fog"}` | When weather changes to specified type |
| `near_object` | `{object_type: "campfire"/"any_toy"/etc, distance_pt: 30}` | When creature is within distance of object |
| `on_wake` | `{}` | When creature wakes from sleep |
| `on_session` | `{event: "start"/"end"}` | When Claude session starts or ends |
| `on_touch` | `{type: "tap"/"pet"/"any"}` | When human touches creature |
| `on_streak` | `{min_days: 7}` | When commit streak reaches N days |
| `periodic` | `{interval_m: 30, jitter_m: 5}` | Every N minutes with jitter |
| `compound` | `{all_of: [...], any_of: [...], none_of: [...]}` | Logical combination of other triggers |

- Each trigger type has a dedicated evaluator function
- Triggers are evaluated lazily (only check relevant triggers for current event type)
- Compound triggers support nesting up to 2 levels deep

**Deliverable**: All 12 trigger types implemented and evaluatable. Compound triggers support AND/OR/NOT logic.

#### P7-T3-03: Compound Trigger Logic
**Agent**: swift-behavior
**Depends on**: P7-T3-02
**Work**:
- Implement compound trigger combinators:
  - `all_of`: all sub-triggers must be true (AND)
  - `any_of`: at least one sub-trigger must be true (OR)
  - `none_of`: no sub-triggers must be true (NOT)
- Example: "stretch after large commit, but only when it's raining and contentment is above 50"

```json
{
  "type": "compound",
  "all_of": [
    {"type": "after_event", "event": "commit_large"},
    {"type": "on_weather", "weather": "rain"},
    {"type": "on_emotion", "axis": "contentment", "direction": "above", "threshold": 50}
  ]
}
```

- Nesting: compound triggers can contain other compound triggers (max depth 2)
- Short-circuit evaluation: `all_of` stops on first false, `any_of` stops on first true
- Validation: reject circular references, reject depth >2

**Deliverable**: Compound triggers allow complex conditional behavior. Nesting supported up to depth 2.

#### P7-T3-04: Preference System
**Agent**: swift-behavior
**Depends on**: Phase 2 emotion/personality system
**Work**:
- Preferences are valence tags that modulate existing autonomous behavior:
  - Valence range: -1.0 (strong dislike) to +1.0 (strong fascination)
  - Subject: any keyword tag (weather types, object types, times of day, activities, etc.)
- Behavioral modulation by valence:

| Valence Range | Approach/Avoid | Expression Bias | Speech Coloring | Interaction Frequency |
|---------------|---------------|----------------|-----------------|----------------------|
| -1.0 to -0.6 | Active avoidance, retreat | Ears flat, discomfort | Negative words | Avoid interactions with subject |
| -0.5 to -0.1 | Mild avoidance | Slight discomfort | Neutral-negative | Reduced interaction |
| 0.0 | No effect | — | — | — |
| +0.1 to +0.5 | Mild approach | Slight interest | Neutral-positive | Slightly increased |
| +0.6 to +1.0 | Active approach, linger | Ears forward, joy | Positive words | Seek out interactions |

- Examples:
  - `{"subject": "rain", "valence": 0.8}`: creature walks to open areas in rain, happy expression, lingers
  - `{"subject": "thunder", "valence": -0.7}`: creature flinches at thunder, retreats to cover, ears flat
  - `{"subject": "morning", "valence": 0.5}`: creature is livelier in morning hours
  - `{"subject": "campfire", "valence": 0.9}`: creature gravitates toward campfire objects
- Maximum 12 active preferences
- Preference evaluation integrated into autonomous behavior selection and object interaction scoring (P7-T2-09)

**Deliverable**: Preferences modulate autonomous behavior through valence-based approach/avoid, expression bias, and interaction frequency.

#### P7-T3-05: Quirk System
**Agent**: swift-behavior
**Depends on**: Phase 2 creature animations
**Work**:
- Quirks are behavior interceptors that modify existing animations:
  - Attached to a specific animation or animation category
  - Fire probabilistically (5%-90% chance per trigger)
  - Modify the animation in a small way (add a gesture, change timing, substitute an element)
- Quirk definition:

```json
{
  "name": "left_look",
  "description": "Always looks left before walking right",
  "target_behavior": "walk_right",     // Which behavior to intercept
  "modification": "prepend",            // prepend, append, replace_element, overlay
  "action": {"track": "head", "state": "look_left", "duration_s": 0.3},
  "probability": 0.75
}
```

- Modification types:
  - `prepend`: insert action before the behavior starts
  - `append`: insert action after the behavior ends
  - `replace_element`: swap one element of the behavior (e.g., wink instead of blink)
  - `overlay`: add action simultaneously on a different track
- Examples:
  - "Winks instead of blinks (15% of the time)" — replace_element on blink cycle
  - "Sneezes near flowers (30%)" — overlay triggered near flower objects
  - "Always looks left before walking right (75%)" — prepend on walk_right
  - "Tiny tail flick after eating (60%)" — append on commit eating completion
- Maximum 12 active quirks
- Quirks stack: multiple quirks can modify the same behavior (evaluated in creation order)

**Deliverable**: Quirks intercept and modify existing animations probabilistically. Small tweaks accumulate into distinctive personality.

#### P7-T3-06: Routine System
**Agent**: swift-behavior
**Depends on**: P7-T3-01 (habit engine for execution), Phase 2 behavior sequences
**Work**:
- 10 lifecycle slots, each with a default behavior that can be replaced:

| Slot | Default Behavior | When It Fires |
|------|-----------------|---------------|
| `morning` | Stretch, yawn, walk to center | On wake (first commit after sleep, or 30min before typical first commit) |
| `post_meal` | Groom paw, lick lips | After commit eating completion |
| `bedtime` | Yawn, knead, curl up | Before sleep (10min idle past 10PM) |
| `greeting` | Ears perk, walk toward edge | When Claude session starts |
| `farewell` | Wave, watch diamond dissolve | When Claude session ends |
| `return` | Stretch, look around, happy expression | On wake from >8hr absence |
| `milestone` | Celebrate behavior | On any milestone event |
| `weather_change` | Look up, react to new weather | On weather state transition |
| `boredom` | Sigh, flop over, stare at nothing | After 30min idle with low curiosity |
| `post_feast` | Food coma flop, satisfied expression | After eating large commit (200+ lines) |

- Routine definition: ordered sequence of 2-6 actions (behaviors, expressions, movements, speech)
- Setting a new routine replaces the default (default can be restored via "reset")
- Routines fire at the appropriate lifecycle moment, pre-empting autonomous behavior
- Routine execution respects behavior stack (pauses for reflexes/touches, resumes after)

**Deliverable**: 10 lifecycle slots with customizable multi-step routines. Claude can define the creature's daily rituals.

#### P7-T3-07: Organic Variation Engine
**Agent**: swift-behavior
**Depends on**: P7-T3-01, P7-T3-05, P7-T3-06
**Work**:
- 5 variation axes ensure nothing plays identically twice:

| Axis | Effect | Range |
|------|--------|-------|
| Timing jitter | All durations varied by percentage | +/-10% (strict) to +/-50% (wild) |
| Probabilistic skipping | Even "always" habits skip occasionally | 5-10% skip rate for "always", scaled for others |
| Mood modulation | Sad creature performs happy habits half-heartedly | Speed 0.7x, amplitude 0.6x, may sigh after |
| Energy scaling | Tired creature does energetic habits at reduced intensity | Speed proportional to energy/100, minimum 0.5x |
| Personality consistency | Discipline axis modulates all variation | High discipline: less jitter, fewer skips. Low discipline: more jitter, more skips, timing chaos |

- Variation applied to: habits, quirks, routines, and taught behavior triggers
- Each performance generates a unique "variation seed" that determines all jitter values for that execution
- The result: a habit that fires 100 times produces 100 slightly different performances
- High-discipline creature (0.9): consistent, clockwork, reliable (jitter 3%, skip 2%)
- Low-discipline creature (0.1): unpredictable, variable, surprising (jitter 45%, skip 15%)

**Deliverable**: Organic variation engine makes every behavior execution unique. Personality.discipline controls consistency vs chaos.

#### P7-T3-08: Mastery-Based Decay Tiers
**Agent**: swift-state, swift-behavior
**Depends on**: P7-T3-13 (SQLite tables)
**Work**:
- All nurture data (habits, preferences, quirks, routines) has a strength value (0.0-1.0)
- New teachings start at strength 0.5
- Claude can reinforce: `pushling_nurture("reinforce", {name})` adds +0.15 strength (capped at 1.0)
- 4 decay tiers based on reinforcement count:

| Tier | Reinforcements | Decay Rate | Strength Floor | Time to Floor | Implication |
|------|---------------|-----------|----------------|---------------|-------------|
| Fresh | 0-2 | 0.02/day | 0.0 (forgets) | ~25 days | Completely forgotten if not reinforced |
| Established | 3-9 | 0.01/day | 0.2 | ~30 days to floor | Remembered vaguely, performs clumsily |
| Rooted | 10-24 | 0.005/day | 0.4 | ~80 days to floor | Still knows it, reliable execution |
| Permanent | 25+ | 0.001/day | 0.6 | ~400 days to floor | Core identity, effectively permanent |

- Strength affects performance quality:
  - 0.0-0.2: does not fire (effectively forgotten, but data remains in SQLite)
  - 0.2-0.4: fires but poorly (extra fumbles, wrong timing, confused expression)
  - 0.4-0.6: fires normally
  - 0.6-0.8: fires confidently
  - 0.8-1.0: fires with flair (bonus personality expression)
- Decay calculated on daemon startup and every 6 hours during runtime
- Journal entry when behavior crosses threshold: "Zepus seems to have forgotten [habit name]..."

**Deliverable**: Nurture data decays realistically based on reinforcement history. A developer returning from 3 weeks finds fresh habits forgotten, established ones weakened, rooted ones intact.

#### P7-T3-09: Creature Rejection
**Agent**: swift-behavior, swift-creature
**Depends on**: P7-T3-01, Phase 2 personality system
**Work**:
- Personality alignment check on new habit creation:
  - Compare habit behavior to creature personality axes
  - High-energy habit (zoomies) on calm creature (energy < 0.3): personality conflict
  - Disciplined routine on chaotic creature (discipline < 0.2): personality conflict
- Conflict detection rules:
  - Energy mismatch: habit requires energy > 0.7, creature energy axis < 0.3 (or vice versa)
  - Discipline mismatch: strict routine on creature with discipline < 0.2
  - Verbosity mismatch: chatty habit on creature with verbosity < 0.2
- On conflict:
  - Creature does NOT reject outright — Claude can force any habit
  - But conflicting habits start weaker (0.3 instead of 0.5)
  - Performance is reluctant: slower, lower intensity, occasional confused/annoyed expression
  - 15% chance creature visibly balks (stops, shakes head, then does it anyway)
- With persistent reinforcement (10+), creature gradually accepts:
  - Reluctance decreases by 10% per reinforcement
  - After 10 reinforcements: performs normally (Rooted tier)
  - Journal arc: "Zepus reluctantly stretched this morning" -> "Zepus stretched — almost seemed to enjoy it" -> "Zepus's morning stretch is part of who they are now"

**Deliverable**: Creature resists personality-mismatched habits with reluctant performance. Persistent reinforcement overcomes resistance. Journal tracks the arc.

#### P7-T3-10: Suggest Sub-Action
**Agent**: swift-behavior, mcp-tools
**Depends on**: P7-T3-01, P7-T2-09
**Work**:
- Daemon observes autonomous creature patterns and generates suggestions:
  - Track object interactions: "23 autonomous interactions with mushrooms this week"
  - Track location preferences: "spends 40% of idle time near the campfire"
  - Track time patterns: "most active during 9-11 AM and 2-4 PM"
  - Track emotional correlations: "satisfaction spikes after rain"
- `pushling_nurture("suggest")` returns 3-5 suggestions ranked by confidence:

```json
{
  "suggestions": [
    {
      "type": "preference",
      "suggestion": {"subject": "mushrooms", "valence": 0.7},
      "reason": "Zepus has interacted with mushrooms 23 times this week (3x average)",
      "confidence": 0.85
    },
    {
      "type": "habit",
      "suggestion": {"trigger": "on_wake", "behavior": "walk_to_campfire"},
      "reason": "Zepus walks to the campfire within 2 minutes of waking 80% of the time",
      "confidence": 0.72
    },
    {
      "type": "quirk",
      "suggestion": {"target_behavior": "eating", "modification": "append", "action": "stretch"},
      "reason": "Zepus stretches after eating 65% of the time already",
      "confidence": 0.65
    }
  ]
}
```

- Observation window: rolling 7 days of behavior data
- Suggestions refresh every 24 hours (cached, not computed per call)
- Minimum confidence threshold: 0.5 (don't suggest weak patterns)

**Deliverable**: Daemon observes patterns and recommends nurture actions. Claude can codify what the creature is already doing naturally.

#### P7-T3-11: Identity Management
**Agent**: mcp-tools, swift-state
**Depends on**: Phase 2 creature naming (birth name from git history)
**Work**:
- `pushling_nurture("identity", {action, ...})`:
  - `"name"`: rename creature (max 12 chars, any stage). Updates all references. Journal: "Zepus is now known as [new name]"
  - `"title"`: set title (max 30 chars, Beast+ only). Displayed on stats overlay. Example: "The Methodical"
  - `"motto"`: set motto (max 50 chars, Sage+ only). Appears in dream sequences and on long-press examine. Example: "One commit at a time"
  - `"get"`: return current name, title, motto, and birth name
- Name change triggers brief animation: creature looks at itself, confused, then accepting
- Title appears in stats HUD overlay (3-finger swipe)
- Motto appears in thought bubbles during deep idle and in dream sequences
- Identity data persists in creature SQLite table (existing, not new table needed)
- Stage gates enforced: title returns helpful error at Critter ("Titles unlock at Beast stage (200+ commits). Currently: Critter with 142 commits.")

**Deliverable**: Claude can set creature name, title, and motto with stage-appropriate gating.

#### P7-T3-12: Habit Conflict Resolution
**Agent**: swift-behavior
**Depends on**: P7-T3-01, P7-T3-02
**Work**:
- When multiple habits trigger simultaneously:
  1. Sort by priority (explicit priority field, default = creation order)
  2. Highest priority executes immediately
  3. Remaining habits queued (max 2 in queue)
  4. Queue spacing: minimum 5 seconds between habit executions
  5. Habits that can't execute within 30 seconds are dropped (journal note: "Zepus couldn't fit in [habit] today")
- Conflict categories:
  - **Movement conflict**: two habits want creature in different locations — highest priority wins
  - **Expression conflict**: two habits want different expressions — blend if compatible, priority wins if not
  - **Timing conflict**: two habits fire at same trigger moment — queue system handles
- If >3 habits triggered simultaneously (busy trigger event): only top 2 execute, rest are dropped with journal note
- No infinite loops: a habit cannot trigger another habit's trigger (cycle detection)

**Deliverable**: Multiple simultaneous habits are resolved through priority queuing. Maximum 2 queued, 5-second spacing, 30-second expiry.

#### P7-T3-13: SQLite Tables
**Agent**: swift-state
**Depends on**: Phase 1 SQLite schema framework
**Work**:
- Create migration for nurture system tables:

```sql
-- Habits: conditional behaviors
CREATE TABLE habits (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    trigger_config TEXT NOT NULL,       -- JSON trigger definition
    behavior TEXT NOT NULL,             -- Behavior name or taught behavior reference
    behavior_variant TEXT,
    frequency TEXT DEFAULT 'often',     -- always, often, sometimes, rarely
    variation TEXT DEFAULT 'moderate',  -- strict, moderate, loose, wild
    energy_cost REAL DEFAULT 0.1,
    stage_min TEXT DEFAULT 'critter',
    priority INTEGER DEFAULT 0,
    strength REAL DEFAULT 0.5,
    reinforcement_count INTEGER DEFAULT 0,
    personality_conflict INTEGER DEFAULT 0,  -- 1 if conflicts with personality
    created_at TEXT NOT NULL,
    last_fired_at TEXT,
    last_reinforced_at TEXT
);

-- Preferences: valence tags
CREATE TABLE preferences (
    id TEXT PRIMARY KEY,
    subject TEXT NOT NULL UNIQUE,       -- "rain", "mushrooms", "morning"
    valence REAL NOT NULL,              -- -1.0 to +1.0
    strength REAL DEFAULT 0.5,
    reinforcement_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_reinforced_at TEXT
);

-- Quirks: behavior interceptors
CREATE TABLE quirks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    target_behavior TEXT NOT NULL,
    modification TEXT NOT NULL,         -- prepend, append, replace_element, overlay
    action TEXT NOT NULL,               -- JSON action definition
    probability REAL DEFAULT 0.5,      -- 0.05-0.90
    strength REAL DEFAULT 0.5,
    reinforcement_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_reinforced_at TEXT
);

-- Routines: lifecycle slot overrides
CREATE TABLE routines (
    id TEXT PRIMARY KEY,
    slot TEXT NOT NULL UNIQUE,          -- morning, post_meal, bedtime, etc.
    sequence TEXT NOT NULL,             -- JSON array of actions
    strength REAL DEFAULT 0.5,
    reinforcement_count INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_reinforced_at TEXT
);
```

- Indexes on all name/subject/slot columns for fast lookup
- Enforce caps: 20 habits, 12 preferences, 12 quirks, 10 routines (one per slot)
- Decay calculation query: batch-update all strength values based on decay tier and elapsed time

**Deliverable**: SQLite tables for all 5 nurture mechanisms with cap enforcement and decay-ready schema.

#### P7-T3-14: Teaching History for SessionStart
**Agent**: hooks-session, mcp-state
**Depends on**: P7-T3-13, Phase 4 SessionStart hook
**Work**:
- Compress nurture state into SessionStart injection:
  - Active habits count and notable ones (recently fired, personality-conflicting)
  - Active preferences with strongest valences
  - Active quirks with most distinctive ones
  - Active routines (which slots customized)
  - Recent nurture suggestions
  - Decay warnings (habits approaching forgotten threshold)
- Example SessionStart injection block:

```
Nurture state:
- 14 habits (3 fired today: morning_stretch, post_meal_groom, campfire_visit)
- 11 preferences (strongest: loves rain +0.8, dislikes thunder -0.7)
- 7 quirks (most visible: looks left before walking right)
- 5 routines (morning, post_meal, bedtime, greeting, farewell customized)
- Warning: "afternoon_nap" habit strength at 0.22 — reinforce or it will be forgotten
- Suggestion: Zepus drawn to mushrooms (23 interactions this week)
```

- Kept concise: max 200 characters per section to avoid bloating SessionStart context
- Updates on each session start (reads from SQLite)

**Deliverable**: SessionStart hook injects compressed nurture state so Claude knows the creature's current behavioral landscape.

### Track 3 Deliverable Summary

Claude can persistently shape creature behavior with organic variation and creature agency. Habits, preferences, quirks, and routines accumulate over weeks to produce a visibly "nurtured" creature with distinctive personality.

---

## QA Gate

### Architecture Reviewer Focus
- Choreography parser validates in <1ms
- Semantic-to-SpriteKit translation <0.3ms per frame per behavior
- Object cap enforcement prevents node budget overrun (max 40 nodes from objects)
- No SQLite writes from MCP (all through daemon IPC)
- Behavior breeding cycle detection (no infinite breeding loops)
- Habit conflict resolution prevents deadlocks
- Decay calculation is batched, not per-frame
- Companion NPC nodes stay within budget (1-2 per companion)
- Organic variation engine does not exceed behavior stack timing constraints

### Vision Compliance Reviewer Focus
- Teach: all 13 animatable tracks match vision spec
- Teach: 4-tier mastery system matches performance counts and visual characteristics
- Teach: compose-preview-refine-commit workflow exists and works
- Teach: behavior breeding at 5% chance, max 5 hybrids, faster decay
- Objects: all 20 presets from vision doc are implemented
- Objects: 14 interaction templates match vision spec categories
- Objects: 7-factor attraction scoring includes all factors from vision doc
- Objects: cat chaos matches surprise #28 description
- Objects: legacy shelf preserves removed object memory
- Objects: 5 companion types match vision spec
- Nurture: 5 mechanisms (habits, preferences, quirks, routines, identity)
- Nurture: 12 trigger types including compound
- Nurture: organic variation engine has all 5 axes
- Nurture: 4 decay tiers with correct rates and floors
- Nurture: creature rejection with reluctant performance
- Nurture: suggest sub-action observes patterns

### Integration Tester Focus
- Teach: compose-preview-commit workflow works end-to-end
- Teach: mastery progresses through 4 tiers visibly (clumsy -> signature)
- Teach: personality permeation produces measurably different performances for different creatures
- Objects: all 20 presets create correctly with one word
- Objects: creature interacts autonomously with placed objects
- Objects: 14 interaction templates produce correct creature behaviors
- Objects: wear accumulates and repair works
- Nurture: habits fire on triggers with organic variation
- Nurture: creature rejects personality-mismatched habits
- Nurture: decay follows mastery tiers (Permanent behaviors survive 30-day absence)
- Behavior breeding produces hybrids (testable with accelerated time)
- Cross-system: objects enable surprise variants, preferences modify surprises
- 30 taught behaviors + 20 habits + 12 objects don't exceed frame budget
- All creation systems survive daemon restart (SQLite persistence verified)
