# Phase 2: Creature

**Goal**: The cat-spirit creature exists, breathes, blinks, walks, has personality, and responds to the 4-layer behavior stack. No world yet (black background), no MCP control yet, no speech yet. Just the creature being alive on a black OLED void. If you look at the Touch Bar and feel "something is alive in there" — Phase 2 is complete.

**Estimated Duration**: 2–3 weeks
**Parallel Tracks**: 3 (T1 and T2 can start simultaneously; T3 starts after T1 body parts exist)
**Vision Reference**: `PUSHLING_VISION.md` — The Pushling, Visual Form, Growth Stages, Personality System, Emotional State, Control Architecture sections

---

## Dependencies

| Dependency | From | What's Needed |
|------------|------|---------------|
| SpriteKit scene running at 60fps | P1-T1-04, P1-T1-05 | The `PushlingScene` with render loop and frame budget monitoring |
| SQLite with creature table | P1-T2-01, P1-T2-02 | `StateManager` to read/write creature state (personality, emotions, stage) |
| SQLite with journal table | P1-T2-03 | Journal writes for milestones, dreams, surprises |

Phase 2 does NOT depend on IPC or MCP — the creature runs entirely on Layer 1 (autonomous) and Layer 0 (physics). Claude inhabitation comes in Phase 4.

---

## Track 1: Creature Node & Body Parts (P2-T1)

**Agents**: swift-creature, assets-sprites
**Depends On**: P1-T1-04 (SpriteKit scene exists)
**Delivers To**: Track 2 (behavior stack animates these parts), Track 3 (personality modulates these parts)

### P2-T1-01: CreatureNode Composite Architecture

**What**: Build the creature as a composite `SKNode` tree with independently animatable body parts.

**Acceptance Criteria**:
- `CreatureNode` class extending `SKNode`, located in `Pushling/Creature/CreatureNode.swift`
- Child node hierarchy:

```
CreatureNode (root — position, facing, breathing transform)
├── aura          SKSpriteNode — ambient glow behind creature, color/alpha varies
├── body          SKSpriteNode — main body shape, receives breathing scale
│   └── core_glow SKSpriteNode — inner heart glow (Critter+), alpha pulses
├── head          SKNode — relative to body, contains face parts
│   ├── ear_left  SKSpriteNode — independent rotation/state
│   ├── ear_right SKSpriteNode — independent rotation/state
│   ├── eye_left  SKSpriteNode — blink, expression states
│   ├── eye_right SKSpriteNode — blink, expression states
│   ├── mouth     SKSpriteNode — open/closed/smile/frown/chew states
│   └── whiskers  SKNode — whisker_left + whisker_right, micro-movements
├── tail          SKSpriteNode — multi-segment or single sprite, sway/poof/wrap
├── paw_fl        SKSpriteNode — front-left, walk cycle + gestures
├── paw_fr        SKSpriteNode — front-right
├── paw_bl        SKSpriteNode — back-left
├── paw_br        SKSpriteNode — back-right
└── particles     SKNode — container for particle emitters (purr, sparkle, crumbs, etc.)
```

- Each body part node has:
  - A unique `name` for programmatic access
  - A default `zPosition` (layering order so parts render correctly)
  - An `anchorPoint` set for natural rotation (ears rotate from base, tail from body connection)
- The root `CreatureNode` is added to `PushlingScene` at the creature's world position
- Node count for full creature: ~15–20 nodes (well within the 120 budget)

**Constraints**:
- Body parts are sprite-based, NOT drawn with `SKShapeNode` (shapes don't perform as well and don't support texture atlases)
- Every part must be independently animatable — no part's animation is hardcoded to another part's timing
- The node tree must support Stage-specific reconfiguration (Spore has no ears/tail/paws; they appear at the correct stage)

---

### P2-T1-02: Pixel Art Sprite Atlas — All 6 Growth Stages

**What**: Create the pixel art sprite atlas with every body part at every growth stage.

**Acceptance Criteria**:
- Sprite atlas: `Pushling/Assets/Creatures.atlas/` (compiled by Xcode into `.atlasc`)
- Art style: 1-bit silhouette pixel art with selective color accents. "Luminous Pixel Life" — creature emerges from OLED darkness.
- Color palette: the 8-color P3 palette from the vision doc (Void, Bone, Ember, Moss, Tide, Gilt, Dusk, Ash)
- @2x resolution (Touch Bar is Retina)

**Per-stage sprites**:

| Stage | Size (pts) | Body Parts Included | Visual Notes |
|-------|-----------|---------------------|-------------|
| **Spore** | 6x6 | body only (glowing orb) | No features. Pulses with inner light. Single sprite. |
| **Drop** | 10x12 | body, eye_left, eye_right | Teardrop shape. Two cat-like eyes. Semi-translucent. Faint ear-points in body silhouette (not separate nodes). |
| **Critter** | 14x16 | body, head, ear_left, ear_right, eye_left, eye_right, mouth, tail (stub), paw_fl, paw_fr, paw_bl, paw_br, core_glow | Small kitten. Ears, stub tail, four tiny paws. Visible heart glow. Spots/stripes. Tentative walk. |
| **Beast** | 18x20 | All parts + whiskers + aura | Confident cat. Full tail, whiskers, defined musculature. Personality fur patterns. Aura. |
| **Sage** | 22x24 | All parts (enhanced) | Wise cat. Longer luminous fur tips. History marks. Orbiting wisdom particles. Third eye mark (faint). |
| **Apex** | 25x28 | All parts (transcendent) + multi-tail | Semi-ethereal. Parts dissolve to particles. Multiple tails (1–9 based on repos tracked). Crown of tiny stars. |

**Per body part, provide named frames** for each state the part supports (see P2-T1-03).

**Total texture budget**: < 1MB across all atlases (estimate: ~768KB for 3 atlases as per vision doc performance specs)

**Constraints**:
- All sprites are @2x (double the pt dimensions in actual pixels)
- Use the P3 color space (for OLED vividity) — set in asset catalog settings
- Creature body color is tintable — the base sprite is Bone (#F5F0E8), and the `base_color_hue` from creature state applies as a `colorBlendFactor` tint
- Black (#000000) areas in sprites must be truly transparent (OLED true black = pixels off)
- At 30 pixels tall, detail is communicated through **shape and motion**, not texture. Keep sprites clean and readable.

---

### P2-T1-03: Body Part Controllers with Semantic States

**What**: Each body part has a controller that exposes named semantic states. Animations are requested by name, not by raw values.

**Acceptance Criteria**:
- Protocol: `BodyPartController` with `setState(_ state: String, duration: TimeInterval)`
- Each body part has a concrete controller with its valid states:

**Ears** (`EarController` — one per ear):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `neutral` | Upright, slight outward angle | Default idle |
| `perk` | Snap fully upright, forward-facing | New event (commit, touch, sound) |
| `flat` | Pressed against head | Fear, submission, discomfort |
| `back` | Rotated backward | Annoyance, alert |
| `twitch` | Quick 2-frame oscillation | Random idle, curiosity |
| `rotate_toward` | Point toward a world position | Tracking a sound/touch |
| `droop` | Sag downward | Sleepy, sad |
| `wild` | Rapid random orientations | Excitement, zoomies |

**Eyes** (`EyeController` — one per eye):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `open` | Normal open eye | Default |
| `half` | Half-lidded | Contentment, sleepy, skeptical |
| `closed` | Fully closed | Blink, sleep, contentment slow-blink |
| `wide` | Extra-large pupil | Surprise, wonder, fear |
| `squint` | Narrowed | Suspicion, mischief, bright light |
| `happy` | Curved "happy anime" shape | Joy, celebration |
| `blink` | Close + open over 0.15s | Autonomous blink cycle |
| `slow_blink` | Close (0.3s) + hold (0.5s) + open (0.3s) | Trust, deep contentment, affection |
| `look_at` | Pupil shifts toward target | Tracking something |
| `x_eyes` | X marks | Playing dead (comedy) |

**Tail** (`TailController`):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `sway` | Gentle sine-wave swing | Default idle |
| `sway_fast` | Faster swing | Excitement |
| `still` | No movement | Focused attention |
| `poof` | Puffed up (scale 1.5x) | Surprise, excitement |
| `low` | Hanging down | Sadness, tiredness |
| `high` | Straight up | Confidence, greeting |
| `wrap` | Curled around body | Comfort, cold, embarrassment |
| `twitch_tip` | Only tip flicks | Focused processing |
| `wag` | Dog-like rapid wag | Extreme happiness |
| `chase` | Circles — chasing own tail | Surprise/play behavior |

**Mouth** (`MouthController`):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `closed` | Default closed | Normal |
| `open` | Mouth open | Speaking, yawning |
| `smile` | Upturned corners | Happy |
| `frown` | Downturned | Sad |
| `chew` | Open-close-open oscillation | Eating commit characters |
| `yawn` | Wide open, holds, closes | Sleepy |
| `chatter` | Rapid jaw vibration | Chattering at prey (birds) |
| `blep` | Tongue protrusion (1px) | Random surprise (#42) |
| `lick` | Tongue out and back | Grooming, post-meal |

**Whiskers** (`WhiskerController`):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `neutral` | Slight spread | Default |
| `forward` | Point forward | Interest, curiosity |
| `back` | Swept back | Fear, speed |
| `twitch` | Random micro-oscillation | Idle, sensing |
| `droop` | Hang down | Sad, tired |

**Paws** (`PawController` — one per paw):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `ground` | On ground, default position | Standing |
| `walk` | Walk cycle offset | Walking |
| `run` | Run cycle offset | Running |
| `lift` | Raised paw | Waving, reaching |
| `knead` | Alternating push motion | Kneading behavior |
| `tuck` | Hidden under body | Loaf position |
| `dig` | Rapid forward motion | Digging |
| `swipe` | Quick forward strike | Batting at objects |
| `extend` | Stretched forward | Cat stretch |

**Body** (`BodyController`):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `stand` | Upright, normal | Default |
| `crouch` | Low, compressed | Predator crouch, fear |
| `stretch` | Elongated, front low | Cat stretch |
| `loaf` | Compact rectangle | Loaf position |
| `roll_side` | On side | Rolling over |
| `roll_back` | On back, belly up | Belly exposure |
| `jump` | Compressed then extended | Jump arc |
| `land` | Slight compression | Landing from jump |
| `sleep_curl` | Tight ball, tail over nose | Sleeping |

**Aura** (`AuraController`):

| State | Visual | Typical Trigger |
|-------|--------|-----------------|
| `none` | Invisible | Pre-Beast |
| `subtle` | Faint glow at 10% opacity | Beast default |
| `warm` | Stronger glow, warm hue | High contentment |
| `bright` | Full glow | Celebration, evolution |
| `pulse` | Breathing-synced pulse | Meditation, zen state |
| `electric` | Crackling edges | Swarm mutation, high energy |

**Constraints**:
- Invalid state names are fuzzy-matched to the nearest valid option (Levenshtein distance), never rejected silently
- Each controller logs a warning when fuzzy-matching: `"Unknown ear state 'perked', using 'perk'"`
- State transitions use `SKAction` with configurable duration — no instant snapping (except `blink` which is intentionally fast)
- Controllers do NOT decide when to change state — they only know HOW. The behavior stack (Track 2) decides WHEN.

---

### P2-T1-04: Breathing Animation — The Most Important Animation

**What**: Sine-wave Y-scale oscillation that NEVER stops. This is the creature's heartbeat.

**Acceptance Criteria**:
- Breathing is applied to the `body` node's `yScale` property
- Parameters:
  - Base scale: `1.0`
  - Peak scale: `1.03`
  - Period: `2.5 seconds`
  - Waveform: `sin(2π × t / 2.5)` mapped to `[1.0, 1.03]`
- Breathing runs on the **Physics layer** of the behavior stack (highest priority — never overridden)
- Breathing continues during:
  - All other animations (walk, jump, eat, sleep, evolve, zoomies)
  - All behavior stack transitions
  - All touch interactions
  - Claude MCP commands
  - Screen transitions
  - EVERYTHING

**Testing requirements** (these are not optional):
- Unit test: breathing amplitude is correct after 0s, 0.625s (peak), 1.25s (base), 1.875s (trough), 2.5s (base)
- Integration test: start a walk animation, verify breathing continues throughout
- Integration test: trigger a jump, verify breathing continues throughout
- Integration test: enter sleep state, verify breathing continues (but amplitude may be reduced — `1.0` to `1.02` during sleep)
- Manual test: stare at the Touch Bar for 60 seconds during various states. The creature must NEVER appear static.

**Constraints**:
- Breathing is NOT an `SKAction.repeatForever` sequence — it's calculated per-frame in the Physics layer update. This ensures it can never be accidentally removed by clearing actions.
- Breathing is the FIRST thing implemented. Before walk, before blink, before anything. If breathing works, the creature is alive.
- During sleep: breathing amplitude reduces to `1.0–1.02` and period extends to `3.5s` (deeper, slower breaths). This is the ONLY modification allowed.

---

### P2-T1-05: Blink System

**What**: Autonomous random blink cycle.

**Acceptance Criteria**:
- Blink interval: random between 3.0 and 7.0 seconds (uniform distribution)
- Blink animation:
  1. Both eyes: `closed` state (0.075s transition)
  2. Hold closed: 0.075s
  3. Both eyes: `open` state (0.075s transition)
  4. Total blink: ~0.15s
- Blink cycle runs on the Autonomous layer (Layer 4)
- Blinks are suppressed when eyes are already closed (sleep, slow-blink expression)
- Blinks are suppressed during the 0.15s window of a Reflex layer eye snap
- Personality influence on blink timing:
  - High Energy creatures: blink interval `2.5–5.0s` (blink more often)
  - Low Energy creatures: blink interval `4.0–9.0s` (slow, deliberate blinks)
- "Double blink" — 8% chance of two rapid blinks in succession (natural cat behavior)
- Blink timer resets after any eye state change (prevents blink immediately after an expression change)

**Constraints**:
- Blinks are subtle but crucial — they are one of the top 3 "aliveness" signals (along with breathing and tail sway)
- The blink timer is personality-seeded for variation, not a fixed random range

---

### P2-T1-06: Tail Sway

**What**: Gentle autonomous tail movement.

**Acceptance Criteria**:
- Default state: `sway` — sine-wave rotation around the tail's anchor point
- Parameters:
  - Amplitude: ±12 degrees (±0.21 radians)
  - Period: `3.0 seconds` (base, modified by personality)
  - Waveform: `sin(2π × t / period)` mapped to `[-amplitude, +amplitude]`
- Runs on the Autonomous layer
- Personality influence:
  - High Energy: amplitude ×1.3, period ×0.7 (bigger, faster sway)
  - Low Energy: amplitude ×0.7, period ×1.4 (gentle, slow sway)
  - High Discipline: very consistent period (±2% jitter)
  - Low Discipline: variable period (±15% jitter per cycle)
- Tail sway continues during walking (phase-shifted from walk cycle for natural look)
- Tail sway pauses naturally during tail state changes (poof, wrap, etc.) and resumes after

**Constraints**:
- Like breathing, tail sway is calculated per-frame, not via SKAction
- Tail sway + breathing together create the baseline "alive" impression

---

### P2-T1-07: Whisker Twitch

**What**: Random micro-movements of whiskers.

**Acceptance Criteria**:
- Random twitch interval: 5–15 seconds
- Twitch animation: small rotation (±3 degrees) over 0.2s, return to neutral over 0.3s
- Left and right whiskers twitch independently (not synchronized)
- Personality influence:
  - High Focus: twitches more often (3–8s interval), larger amplitude — sensing the world
  - Low Focus: less frequent (8–20s), smaller — relaxed whiskers
- Whiskers point forward during curiosity/investigation states
- Whiskers sweep back during running/fear states

**Constraints**:
- Whiskers are subtle but add micro-level aliveness
- Don't over-animate — whiskers should be barely noticeable most of the time

---

### P2-T1-08: Stage-Specific Creature Scaling and Form

**What**: Each growth stage has a distinct visual form with correct proportions and part visibility.

**Acceptance Criteria**:
- `StageConfiguration` struct that defines per-stage:

| Property | Spore | Drop | Critter | Beast | Sage | Apex |
|----------|-------|------|---------|-------|------|------|
| Size (pts) | 6x6 | 10x12 | 14x16 | 18x20 | 22x24 | 25x28 |
| Has ears | No | No (implied in silhouette) | Yes | Yes | Yes | Yes |
| Has tail | No | No | Yes (stub) | Yes (full) | Yes (luminous) | Yes (multiple) |
| Has paws | No | No | Yes (4 tiny) | Yes (4 defined) | Yes | Yes |
| Has whiskers | No | No | No | Yes | Yes | Yes |
| Has mouth | No | No | Yes | Yes | Yes | Yes |
| Has aura | No | No | No | Yes | Yes | Yes |
| Has core glow | No | No | Yes | No (absorbed) | No | Particle form |
| Walk speed (pts/s) | 0 (floats) | 8 (hops) | 15 (tentative) | 25 (confident) | 20 (measured) | 22 (ethereal) |
| Run speed (pts/s) | N/A | N/A | 30 (scamper) | 50 (sprint) | 40 (glide) | 45 (phase) |

- `CreatureNode` reconfigures itself when stage changes:
  - Shows/hides appropriate child nodes
  - Swaps texture atlas references
  - Adjusts anchor points and relative positions for new proportions
- Each stage has a distinct silhouette that is immediately recognizable at Touch Bar scale
- The creature is centered vertically in the 30pt bar height with ~2pt padding top and bottom at largest stages

**Constraints**:
- Stage changes happen via the evolution ceremony (P2-T1-09), not by swapping sprites mid-frame
- The `StageConfiguration` is data-driven (a dictionary/struct, not a switch statement with hardcoded values)
- Walk/run speeds are base values — personality modulates them (see Track 3)

---

### P2-T1-09: Stage Transition (Evolution) Ceremony

**What**: The 5-second spectacle when a creature evolves to a new stage.

**Acceptance Criteria**:
- Triggered when `commits_eaten` crosses a stage threshold (adjusted by `activity_factor`)
- Duration: exactly 5 seconds
- Five phases:

| Phase | Time | Duration | Animation |
|-------|------|----------|-----------|
| **Stillness** | 0.0s | 0.8s | All animation stops (except breathing — breathing NEVER stops, but amplitude drops to 1.0–1.01). Ears flatten. World holds its breath. |
| **Gathering** | 0.8s | 1.2s | Light particles stream from all edges of the Touch Bar toward the creature. 20–40 particles, converging. Creature's fur begins to glow (colorBlendFactor increases). |
| **Cocoon** | 2.0s | 1.0s | Particles coalesce into a bright orb around the creature. Creature curls into sleep_curl inside. Ground cracks appear below (Gilt-colored lines). Screen brightness peaks. |
| **Burst** | 3.0s | 0.5s | 200+ particles explode outward from center. Full-screen white flash (0.1s). Screen shake (±2pt horizontal oscillation, 3 cycles). Brief silhouette of new form visible in the flash. |
| **Reveal** | 3.5s | 1.5s | New form fades in at 1.2x scale, settles to 1.0x over 0.5s with ease-out curve. Stage name banner slides in from right (e.g., "CRITTER" in Gilt text), holds 0.8s, slides out. First action at new stage plays. |

- **First action at new stage**:
  - Spore → Drop: Eyes open for the first time. Slow look left, then right.
  - Drop → Critter: Takes its first tentative step. Wobbles. Steps again.
  - Critter → Beast: Runs a victory lap across the bar.
  - Beast → Sage: Sits down, meditates for 3 seconds. Circle particles expand.
  - Sage → Apex: Body dissolves partially to particles, reforms. Looks at own paws with wonder.

- Journal entry: `{ "type": "evolve", "data": { "from": "drop", "to": "critter", "commits_eaten": 75 } }`
- The ceremony plays exactly once per transition. If the app was quit during a ceremony, the transition is considered complete (state is saved before ceremony starts).

**Constraints**:
- Breathing continues throughout (but reduced amplitude during Stillness and Cocoon)
- The ceremony must work at all 5 transition points
- Particle systems must be recycled (pre-allocated SKEmitterNode instances from a pool)
- Total node count during ceremony peak (Burst phase): must not exceed 120 nodes. Use particle emitters, not individual sprite nodes for the 200+ burst particles.

---

### P2-T1-10: Cat-Specific Behaviors

**What**: The 12 cat behaviors baked into Layer 1 that make the creature feel like a cat.

**Acceptance Criteria**:
- Each behavior is a choreographed sequence using the body part controllers from P2-T1-03
- All behaviors run on the Autonomous layer with appropriate trigger conditions

| Behavior | Duration | Body Parts Used | Stage Min | Trigger Condition |
|----------|----------|----------------|-----------|-------------------|
| **Slow-blink** | 1.1s | eyes | Drop+ | Sustained gentle touch OR contentment > 80 |
| **Kneading** | 4–8s | paw_fl, paw_fr (alternating) | Critter+ | Pre-sleep ritual, contentment > 60 |
| **Headbutt** | 1.5s | body (lean), head (forward push) | Critter+ | Near edge of bar, high contentment |
| **Predator crouch** | 2s | body (crouch), eyes (wide), tail (twitch_tip), ears (perk) | Critter+ | Incoming commit text (Phase 4 trigger) |
| **Loaf** | 30–60s | body (loaf), paws (tuck), tail (wrap or sway_slow) | Critter+ | Extended idle, contentment > 50 |
| **Grooming** | 3–5s | paw_fl (lift to face), mouth (lick), head (tilt) | Critter+ | Post-meal idle, random |
| **Zoomies** | 2–4s | full body sprint across bar + back, tail (poof), ears (wild) | Critter+ | Random (surprise #27), energy > 70 |
| **Chattering** | 2s | mouth (chatter), eyes (wide), ears (perk), body (tense) | Critter+ | Flying particle overhead |
| **If-I-fits-I-sits** | 10–20s | body (squeeze animation), eyes (happy), tail (sway slow) | Critter+ | Near small gap between objects |
| **Knocking things off** | 3s | paw (swipe at object), eyes (look at camera), pause, push | Beast+ | Near pushable object, mischief |
| **Tail chasing** | 4–6s | body (spin), tail (chase), eyes (focused then dizzy) | Critter+ | Random surprise (#30) |
| **Tongue blep** | 15–30s | mouth (blep) — tongue stays out, creature acts normal | Drop+ | Random surprise (#42) |

- Each behavior has:
  - A **cooldown** (minimum time before it can trigger again): 2–10 minutes depending on behavior
  - A **weight** for random selection during idle: personality-influenced
  - A **priority** within the Autonomous layer (can interrupt idle walk but not other behaviors)
  - An **exit condition** (interrupted by reflex or AI-directed layer)

**Constraints**:
- Behaviors compose the body part controllers — they don't animate sprites directly
- Behaviors respect stage gates — a Critter can't knock things off, a Drop can't groom
- Zoomies must cross the ENTIRE 1085pt bar and back in 2–4 seconds — this is fast and dramatic
- Breathing continues during all behaviors (Physics layer is always active)
- Behaviors are not `SKAction` sequences — they are state machines managed by the behavior stack, so they can be interrupted gracefully at any point

---

### Track 1 Deliverable

A breathing, blinking, tail-swaying, whisker-twitching cat-spirit creature rendered at each of 6 growth stages on the Touch Bar. The creature has independently animatable body parts with semantic state controllers. All cat-specific behaviors are choreographed and ready for the behavior stack to trigger them. The evolution ceremony transforms the creature between stages with a 5-second spectacle.

---

## Track 2: Behavior Stack (P2-T2)

**Agents**: swift-behavior
**Depends On**: P2-T1-01 through P2-T1-03 (creature node with body part controllers)
**Delivers To**: Track 3 (personality feeds into behavior selection), Phase 4 (AI-directed layer activated by MCP)

### P2-T2-01: 4-Layer Behavior Stack Architecture

**What**: The core architecture that governs all creature behavior through a priority-based layer system.

**Acceptance Criteria**:
- `BehaviorStack` class in `Pushling/Creature/BehaviorStack.swift`
- Four layers, evaluated every frame in priority order:

| Priority | Layer | Class | Update Frequency |
|----------|-------|-------|-----------------|
| 1 (highest) | Physics | `PhysicsLayer` | Every frame (60fps) |
| 2 | Reflexes | `ReflexLayer` | On event + decay every frame |
| 3 | AI-Directed | `AIDirectedLayer` | On IPC command + timeout every frame |
| 4 (lowest) | Autonomous | `AutonomousLayer` | Every frame when no higher layer active |

- Each layer outputs a `LayerOutput` struct:

```swift
struct LayerOutput {
    // Each property is optional — nil means "I have no opinion, defer to lower layer"
    var position: CGPoint?      // World position
    var facing: Direction?      // .left or .right
    var walkSpeed: CGFloat?     // Points per second (0 = stopped)

    // Body part states — nil means "I don't care, lower layer decides"
    var bodyState: String?
    var earLeftState: String?
    var earRightState: String?
    var eyeLeftState: String?
    var eyeRightState: String?
    var tailState: String?
    var mouthState: String?
    var whiskerState: String?
    var pawStates: [String: String]?  // ["fl": "walk", "fr": "walk", ...]
    var auraState: String?

    // Breathing is NOT in LayerOutput — it's hardcoded in Physics, always.
}
```

- **Resolution rule**: For each property, the highest-priority layer with a non-nil value wins.
  - If Physics says `bodyState = nil` and Reflex says `bodyState = "crouch"` and Autonomous says `bodyState = "stand"`, the result is `"crouch"` (Reflex wins at priority 2).
  - If only Autonomous has an opinion, Autonomous wins.
  - If no layer has an opinion for a property, the creature's default state applies.

- The `BehaviorStack` runs in `PushlingScene.update(_:)`:
  1. Update all 4 layers (each computes its output)
  2. Resolve outputs (highest non-nil wins per property)
  3. Apply resolved output to `CreatureNode` via body part controllers
  4. Apply blend controller transitions (P2-T2-04)

**Constraints**:
- The behavior stack update must complete within 1ms (part of the 5.7ms total budget)
- Layers communicate through the `LayerOutput` struct only — no layer directly modifies the creature node
- The stack is the SINGLE source of truth for creature state — nothing else touches the creature's visual state

---

### P2-T2-02: Physics Layer — Always Running

**What**: The Physics layer handles breathing, gravity, and boundary enforcement. It NEVER stops.

**Acceptance Criteria**:
- **Breathing**: Per P2-T1-04 specification. Applied every frame. Not optional.
  - `body.yScale = 1.0 + 0.03 * sin(2π × currentTime / 2.5)`
  - During sleep: `body.yScale = 1.0 + 0.02 * sin(2π × currentTime / 3.5)`
- **Gravity**: Creature's Y position is enforced to ground level (bottom ~3pt of the scene)
  - During jumps: parabolic arc with gravity constant `g = 180 pts/s²`
  - Jump apex determined by initial velocity
  - Landing triggers a 2-frame compression (body `land` state)
  - Dust particles on landing (2–4 small particles)
- **Boundary enforcement**: Creature's X position clamped to `[0, 1085]` minus creature width margins
  - If creature reaches boundary: stops walking, may turn around
  - No wrapping — the creature cannot walk off-screen

**Physics layer output**:
- Always sets: breathing scale (applied directly, bypassing LayerOutput)
- Sets `position.y` during jumps
- Sets `position.x` clamp during boundary enforcement
- Sets `bodyState = "land"` briefly on landing

**Constraints**:
- Physics layer has ZERO dependencies on creature personality or emotional state (except sleep breathing modification)
- Physics runs before all other layers. Its outputs are applied first.
- Breathing is applied as a post-process multiplier on body yScale, not through the LayerOutput resolution — this ensures it ALWAYS applies regardless of what other layers do

---

### P2-T2-03: Autonomous Layer — The Creature's Own Mind

**What**: Default behavior when no higher-priority layer is active. The creature wanders, idles, and performs cat behaviors.

**Acceptance Criteria**:
- **Idle wander state machine**:
  1. `walking` — creature walks in its facing direction at personality-influenced speed
  2. `idle` — creature stands still, performing idle behaviors (blink, tail sway, whisker twitch)
  3. `behavior` — creature performs a cat-specific behavior (from P2-T1-10)
  4. `resting` — creature is in a low-energy rest (loaf, sit, sleep)

- **State transitions**:
  - `walking` → `idle`: After 3–12 seconds of walking (random, personality-influenced)
  - `idle` → `walking`: After 2–8 seconds of standing (random)
  - `idle` → `behavior`: Weighted random selection from available behaviors (see P2-T2-08)
  - `behavior` → `idle`: When behavior animation completes
  - Any → `resting`: When emotional energy < 20
  - `resting` → `idle`: When emotional energy > 40

- **Direction changes**:
  - Random: 15% chance per walk → idle transition of facing the opposite direction
  - Boundary: always turns around when reaching screen edge
  - The direction reversal animation takes 0.43s (per vision doc): decelerate → pause (2 frames) → flip sprite → accelerate

- **Speed variation**:
  - Base walk speed: per `StageConfiguration` (P2-T1-08)
  - Personality modulation: Energy axis scales speed ×(0.6 + Energy × 0.8) — range [0.6x at calm, 1.4x at hyper]
  - Emotional energy modulation: speed × (0.5 + emotionalEnergy/100 × 0.5) — range [0.5x at exhausted, 1.0x at full]
  - Random per-walk jitter: ±10%

- **Walk cycle animation**:
  - Paws alternate in walk pattern: FL+BR, then FR+BL (diagonal gait, natural for quadrupeds)
  - Walk cycle period matches speed (faster walk = faster paw cycle)
  - Tail sways during walk (phase-shifted by 0.4 × cycle from paw motion)
  - Ears neutral or slight bounce with each step
  - Head bobs ±0.5pt with walk cycle

**Constraints**:
- Autonomous layer is always computing (it doesn't "turn off" when higher layers are active — it just gets overridden)
- This means if the AI-directed layer releases control, autonomous behavior resumes IMMEDIATELY (within 1 frame) because it was always running underneath
- Walk cycle animation is frame-based, not SKAction-based — so it can be interrupted at any point without visual artifacts

---

### P2-T2-04: Blend Controller

**What**: Smooth interpolation between layer transitions. No jarring snaps.

**Acceptance Criteria**:
- `BlendController` class that manages transition timing between states
- Transition durations (EXACTLY matching vision doc):

| Transition | Duration | Method |
|------------|----------|--------|
| Direction reversal | 0.43s | Decelerate to 0 over 0.15s → pause 2 frames (0.033s) → flip sprite horizontally → accelerate to target speed over 0.25s |
| Expression change | 0.8s | Crossfade between expression states. Each body part transitions independently at its own sub-timing: ears (0.2s), eyes (0.15s), mouth (0.3s), tail (0.5s), whiskers (0.1s) |
| Reflex interrupt | 0.15s | Fast snap — reflexes SHOULD feel immediate. Order: ears first (0.05s), then eyes (0.05s), then body (0.05s). Cascading snap. |
| AI takes control | 0.3s | Current autonomous action decelerates. AI action begins ramping in. Walk speed interpolates linearly over 0.3s. |
| AI releases control | 5.0s | Gradual: intentional movements soften over 2s, speed normalizes over 3s, idle behaviors creep back in at t=3s, full autonomous by t=5s. Ease-in-out curve. |
| Session disconnect | 5.0s | Same as AI releases control (the diamond fades over this same 5s window) |

- Blend applies to **all** body part states simultaneously with per-part sub-timing
- Blend uses easing curves:
  - Reflex: linear (instant feel)
  - Expression change: ease-in-out (natural)
  - Direction reversal: ease-out (decelerate), ease-in (accelerate)
  - AI takeover: ease-in (gradually asserting control)
  - AI release: ease-out (gradually releasing)

- Body part state interpolation:
  - For discrete states (e.g., ear perk → ear flat): crossfade by interpolating the sprite opacity between old and new textures over the transition duration
  - For continuous values (e.g., walk speed, tail rotation): linear interpolation
  - For position: smooth interpolation via `lerp(current, target, blend_factor)`

**Constraints**:
- The blend controller introduces no more than 0.2ms per frame (it's just math — interpolation functions)
- Blends can be preempted: if a reflex fires during an AI takeover blend, the reflex snaps immediately (higher priority)
- Blend state is tracked per-property, not globally — different body parts can be in different blend phases simultaneously

---

### P2-T2-05: Layer Output Resolution

**What**: The per-property priority resolution system.

**Acceptance Criteria**:
- `LayerResolver` function that takes 4 `LayerOutput` structs and produces a single `ResolvedOutput`
- Resolution rule: for each property, iterate layers from highest priority (Physics) to lowest (Autonomous). First non-nil value wins.
- Special cases:
  - If Physics specifies `position.y` (during jump), it overrides ALL other position.y values
  - If Reflex specifies `earLeftState`, it overrides AI-Directed and Autonomous ear states
  - If no layer specifies a property, the creature's resting default applies (defined by stage and current emotional state)
- The resolved output is what gets sent to the blend controller, which then applies it to the creature node

**Constraints**:
- Resolution happens ONCE per frame, after all layers have updated
- Resolution is deterministic — same inputs always produce same outputs
- The resolver does NOT know about blend timing — it only resolves "what state should things be in RIGHT NOW." The blend controller handles "how do we get there smoothly."

---

### P2-T2-06: Reflex Layer Skeleton

**What**: Short-lived behavior overrides triggered by input events.

**Acceptance Criteria**:
- `ReflexLayer` class that manages a list of active reflexes
- Each reflex has:
  - `trigger`: the event that caused it
  - `output`: the `LayerOutput` properties it overrides
  - `duration`: how long the reflex lasts (0.5–3.0s)
  - `elapsed`: time since trigger
  - `fadeout`: final portion of duration where reflex blends out (typically last 20%)
- Pre-defined reflex types (skeleton — full implementation in Phase 4+):

| Reflex | Trigger | Duration | Output |
|--------|---------|----------|--------|
| Ear perk | New event (commit, touch, sound) | 0.8s | ears: perk |
| Flinch | Force push commit | 1.5s | body: crouch, ears: flat, eyes: wide |
| Look at touch | Touch event | 1.0s | eyes: look_at(touchPoint), ears: rotate_toward(touchPoint) |
| Startle | Sudden loud event | 0.5s | body: jump, ears: back, eyes: wide, tail: poof |

- Multiple reflexes can be active simultaneously — they are merged (per-property, most recent wins within the reflex layer)
- Reflexes expire automatically and are removed from the active list
- Reflex layer output decays: during the fadeout portion, property overrides blend toward nil (releasing control back to lower layers)

**Constraints**:
- Reflexes are the only way Layer 2 (Reflexes) gets populated — direct body part manipulation is not allowed
- The reflex list is bounded: max 5 simultaneous reflexes (oldest is evicted if exceeded)
- Reflex snap-in is 0.15s (per blend controller) — this is intentionally fast to feel responsive

---

### P2-T2-07: AI-Directed Layer Skeleton

**What**: Placeholder for Claude's MCP command queue. Not functional until Phase 4, but the skeleton must exist for the stack architecture.

**Acceptance Criteria**:
- `AIDirectedLayer` class with:
  - `commandQueue`: ordered list of active AI commands
  - `currentCommand`: the command currently being executed
  - `output`: the `LayerOutput` for the current command
  - `lastCommandTime`: timestamp of most recent command
  - `isActive`: bool (false until Phase 4)
- Timeout logic: if `currentTime - lastCommandTime > 30.0`, the layer begins its 5.0s fadeout (releasing control to Autonomous)
- Warm standby: when not active, the layer outputs all-nil (defers everything to Autonomous)
- Command acceptance:
  - `enqueue(command:)` — add a command to the queue
  - `cancel()` — cancel current command, begin fadeout
  - `cancelAll()` — clear queue, begin fadeout
- When a command completes:
  - If queue has more commands: execute next
  - If queue is empty: begin 30s timeout countdown, maintain current output until timeout, then fadeout

**Constraints**:
- This layer is inert in Phase 2 — it always outputs nil
- But its integration into the stack must be complete — when Phase 4 activates it, everything should "just work"
- The 30s timeout and 5s fadeout timings are critical for the handoff feel

---

### P2-T2-08: Behavior Selection Engine

**What**: Weighted random selection of autonomous behaviors with cooldowns and personality influence.

**Acceptance Criteria**:
- `BehaviorSelector` class that picks the next behavior during Autonomous layer idle → behavior transitions
- Available behavior pool: all cat-specific behaviors (P2-T1-10) that:
  - Meet stage requirements (current stage ≥ behavior's stage_min)
  - Are not on cooldown (time since last trigger > behavior's cooldown)
  - Meet emotional conditions (if any — e.g., kneading requires contentment > 60)
  - Meet world conditions (if any — e.g., knocking requires a nearby pushable object)

- **Weight calculation** for each eligible behavior:
  ```
  weight = base_weight
         × personality_affinity    // 0.5–2.0 based on behavior category vs personality axes
         × emotional_boost         // 1.0–1.5 based on current emotional state alignment
         × recency_penalty         // 0.3 if triggered in last hour, 0.6 if last 2 hours, 1.0 otherwise
         × novelty_bonus           // 1.5 for behaviors performed < 3 times ever
  ```

- **Personality affinity mapping**:

| Behavior Category | High Affinity Personality | Low Affinity Personality |
|-------------------|--------------------------|------------------------|
| Playful (zoomies, tail chase) | High Energy (×2.0) | Low Energy (×0.5) |
| Calm (loaf, slow-blink) | Low Energy (×2.0) | High Energy (×0.5) |
| Social (headbutt, kneading) | High Verbosity (×1.5) | Low Verbosity (×0.7) |
| Investigative (grooming, examining) | High Focus (×1.5) | Low Focus (×0.7) |
| Mischievous (knocking, pranks) | Low Discipline (×1.8) | High Discipline (×0.5) |
| Ritualistic (kneading pre-sleep) | High Discipline (×1.5) | Low Discipline (×0.7) |

- Selection: weighted random from the eligible pool
- If no behaviors are eligible (all on cooldown): stay in idle state
- Minimum time between any two behaviors: 30 seconds (global cooldown)

**Constraints**:
- The selector must feel organic — not a metronome, not a random mess
- A calm, focused, disciplined creature should behave VERY differently from a hyperactive, chaotic, scattered one
- The weights should be tunable without code changes (defined as data, not hardcoded conditionals)
- Log behavior selections at debug level for tuning: "Selected 'loaf' (weight 2.4) from pool of 8 behaviors"

---

### Track 2 Deliverable

Working 4-layer behavior stack where the creature walks, idles, turns, performs cat behaviors, and transitions smoothly between states. The blend controller produces buttery transitions with the exact timings from the vision doc. Physics (breathing, gravity) never stops. Autonomous behaviors are personality-influenced and varied. The Reflex and AI-Directed layers are structurally complete but inert, ready for Phase 4 activation.

---

## Track 3: Personality & Emotion (P2-T3)

**Agents**: swift-creature (personality aspect)
**Depends On**: P2-T1-01 (creature node exists), P2-T2-03 (autonomous layer exists for personality to modulate), P1-T2-02 (creature table for persistence)
**Delivers To**: Track 2 (personality modulates behavior selection and animation timing), Phase 4+ (emotional state shifts in response to events)

### P2-T3-01: 5 Personality Axes

**What**: Implement the 5 personality axes that define the creature's permanent character.

**Acceptance Criteria**:
- `Personality` struct:
  ```swift
  struct Personality {
      var energy: Double      // 0.0 (calm) to 1.0 (hyperactive)
      var verbosity: Double   // 0.0 (stoic) to 1.0 (chatty)
      var focus: Double       // 0.0 (scattered) to 1.0 (deliberate)
      var discipline: Double  // 0.0 (chaotic) to 1.0 (methodical)
      var specialty: LanguageCategory  // enum of 11 categories
  }
  ```

- Personality is loaded from SQLite on launch and cached in memory
- Personality axes modulate creature behavior through a `PersonalityModulator`:

| Axis | What It Modulates | Low End Effect | High End Effect |
|------|-------------------|----------------|-----------------|
| **Energy** | Walk speed, animation speed, idle duration, behavior frequency | Walk ×0.6, idle 8–15s, behaviors every 3–5min, sleep more | Walk ×1.4, idle 2–4s, behaviors every 30–90s, rarely rests |
| **Verbosity** | Future speech frequency, reaction expressiveness, blink expressiveness | Minimal reactions, single body-part responses | Full-body reactions, expressive ears/tail, dramatic |
| **Focus** | Walk pattern (straight vs wandering), attention to objects, investigation time | Random direction changes, short attention, skips objects | Straight walks, long investigation, examines everything |
| **Discipline** | Timing consistency, ritual adherence, walk pattern regularity | ±20% jitter on all timings, irregular patterns | ±3% jitter, clockwork patterns, rituals performed consistently |
| **Specialty** | Visual tint, movement style, fur pattern | N/A (category, not spectrum) — see below |

- **Specialty visual influence** (applied as subtle modifiers):

| Category | Movement Style | Visual Modifier |
|----------|---------------|-----------------|
| Systems | Angular, precise steps, deliberate turns | Metallic sheen (slight white colorBlendFactor shift on fur) |
| Web Frontend | Bouncy, reactive, sparkle on direction change | Rounded eye shape, sparkle particle on ear perk |
| Web Backend | Sturdy, reliable gait, even pacing | Warm tint, slightly larger body proportion |
| Script | Smooth, flowing, serpentine tail | Smoother walk cycle interpolation |
| JVM | Structured, formal, geometric | Geometric fur pattern overlay |
| Mobile | Quick reflexes, responsive, gesture-aware | Faster reflex snap (0.12s instead of 0.15s) |
| Data | Analytical, precise, examines longer | Data-spark trail (tiny particles behind tail) |
| Infra | Watchful, guardian stance, still moments | Slight translucency (body alpha 0.92) |
| Docs | Contemplative, gentle, soft movements | Soft glow on fur edges |
| Config | Compact, precise, clockwork | Clockwork tail movement (very regular) |
| Polyglot | Chimeric, shifts between styles | Heterochromatic eyes (different color per eye) |

- Personality drifts slowly with ongoing commits (not implemented in Phase 2 — seeded once from git history in P2-T3-02 and then static until the drift system is built in a later phase)

**Constraints**:
- Personality must be perceivable but subtle. Two creatures with different personalities should look and act differently, but neither should feel "broken" or "wrong."
- Personality is NOT emotion. Personality is who the creature IS (changes over weeks). Emotion is how the creature FEELS (changes over minutes).

---

### P2-T3-02: Git History Scanner

**What**: Analyze all git repos on the machine to compute initial personality axes and visual traits.

**Acceptance Criteria**:
- `GitHistoryScanner` class that:
  1. Discovers git repos (scans common directories: `~`, `~/Documents`, `~/Projects`, `~/Developer`, `~/code`, `~/github`, `~/repos`, `~/src`, `~/work`)
  2. For each repo, runs `git log` with format to extract:
     - Commit count per author (filter to machine's `git config user.email`)
     - Commit timestamps (for time-of-day distribution)
     - File extensions changed per commit
     - Lines added/deleted per commit
     - Commit message lengths
     - Commit frequency patterns (bursts vs steady)
  3. Aggregates across all repos

- **Personality axis computation**:

| Axis | Input | Formula |
|------|-------|---------|
| Energy | Commit frequency, burst patterns | `clamp(burst_ratio × 0.7 + commits_per_day_normalized × 0.3, 0, 1)` where `burst_ratio` = fraction of commits in bursts of 5+ within 1 hour |
| Verbosity | Commit message length | `clamp(avg_message_length / 100, 0, 1)` where 100 chars = 1.0 |
| Focus | Files per commit, repo switching | `1.0 - clamp(avg_files_per_commit / 20, 0, 1) × 0.5 - repo_switch_frequency × 0.5` |
| Discipline | Commit timing regularity | `1.0 - clamp(std_dev_commit_hour / 6.0, 0, 1)` where std_dev of commit hours; regular schedule = high discipline |
| Specialty | 30-day rolling window of file extensions | Category with highest commit-weighted extension count |

- **Visual trait computation**:

| Trait | Input | Computation |
|-------|-------|-------------|
| `base_color_hue` | Dominant language | PHP→purple(0.75), Rust→orange(0.08), Python→blue-green(0.45), JS/TS→yellow(0.15), etc. |
| `body_proportion` | Add/delete ratio | Net-adder (ratio > 1.5) = rounder (proportion > 0.6). Net-deleter (ratio < 0.7) = lean (proportion < 0.4). |
| `fur_pattern` | Number of repos | 1–3 repos = none, 4–8 = spots, 9–15 = stripes, 16+ = tabby |
| `tail_shape` | Primary language family | Systems = thin, Web = fluffy, Script = serpentine |
| `eye_shape` | Commit message style | Verbose (avg > 50 chars) = round. Terse (avg < 20 chars) = narrow. |

- Scanner runs during hatching ceremony (P2-T3-08) — takes up to 30 seconds
- Results are written to SQLite creature table
- Scanner handles: empty repos, repos with no commits by this user, permission errors, symlinks

**Constraints**:
- The scanner runs ONCE at birth (first launch with no creature). It does not re-run.
- All git operations are read-only (`git log`, `git config`)
- The scanner must not follow symlinks into system directories or node_modules
- Timeout: 30 seconds max. If scan isn't complete, use whatever data was gathered.
- Run on a background thread — never block the UI

---

### P2-T3-03: 4 Emotional Axes

**What**: Real-time emotional state that changes within minutes/hours.

**Acceptance Criteria**:
- `EmotionalState` struct:
  ```swift
  struct EmotionalState {
      var satisfaction: Double  // 0–100
      var curiosity: Double    // 0–100
      var contentment: Double  // 0–100
      var energy: Double       // 0–100 (emotional energy, distinct from personality Energy axis)
  }
  ```

- **Decay/recovery rules** (computed every frame or every second):

| Axis | Increases | Decreases | Rate |
|------|-----------|-----------|------|
| Satisfaction | Commits (+10 small, +20 medium, +30 large) | Time: -1 per 3 minutes | Clamped [0, 100] |
| Curiosity | New repo (+20), new file type (+10), touch (+5) | Repetitive commits (-5), idle > 10min (-2/min) | Clamped [0, 100] |
| Contentment | Streak day (+5), human interaction (+8), milestone (+15) | Streak break (-20), indigestion (N/A Phase 2) | Clamped [0, 100] |
| Energy | Commits (+5), dawn time (+1/min), touch (+3) | Nighttime (-0.5/min past 10PM), sustained activity > 2hr (-1/min) | Clamped [0, 100] |

- Emotional state is persisted to SQLite every 60 seconds (not every frame — too many writes)
- Emotional state is loaded from SQLite on launch (with time-based decay applied for elapsed time since last save)

**Constraints**:
- Emotional axes decay toward neutral (50) over time when there's no input — the creature naturally settles to a calm baseline
- Emotional state affects the Autonomous layer's behavior selection (via emotional conditions on behaviors)
- In Phase 2, only time-based decay is active (commit and touch triggers come in Phase 4+). Emotions will slowly drift toward baseline.

---

### P2-T3-04: Emergent States Detection

**What**: Detect recognizable compound emotional states.

**Acceptance Criteria**:
- `EmergentStateDetector` that evaluates emotional axes and returns the current emergent state (or `nil` for no special state):

| State | Condition | Visual/Behavioral Effect |
|-------|-----------|-------------------------|
| **Blissful** | satisfaction > 75 AND contentment > 75 AND energy 30–70 | Peaceful wandering, purr particles (subtle), slow-blinks every 20s |
| **Playful** | energy > 70 AND contentment > 60 | Increased behavior frequency (÷2 cooldowns), bouncy walk, tail high |
| **Studious** | curiosity > 75 AND energy 30–70 | Examines surroundings longer, peers at objects, ears rotate frequently |
| **Hangry** | satisfaction < 25 AND energy > 40 | Agitated pacing (short walks, frequent turns), occasional glance "at camera" |
| **Zen** | ALL four axes between 40–60 | Loaf position, concentric circle particles (slow expand/fade), eyes half-closed |
| **Exhausted** | energy < 10 | Stumbling gait (walk speed ×0.3, occasional pause), collapses into sleep curl |

- Only one emergent state is active at a time (highest priority match wins, order: Exhausted → Hangry → Blissful → Playful → Studious → Zen)
- Emergent state is re-evaluated every 5 seconds (not every frame — expensive and unnecessary)
- State transitions use the expression change blend (0.8s)
- When a new emergent state activates, the Autonomous layer adjusts behavior accordingly

**Constraints**:
- Emergent states are descriptive labels for the behavior stack to use — they don't directly animate anything
- The detector outputs: state name + modifier parameters that the behavior stack uses to adjust its patterns
- States must be perceivably different. A Playful creature and a Studious creature should be visually distinguishable at a glance on the Touch Bar.

---

### P2-T3-05: Circadian Cycle

**What**: The creature learns the developer's commit schedule and adjusts its sleep/wake cycle.

**Acceptance Criteria**:
- `CircadianCycle` class that:
  1. During the first 14 days, tracks commit timestamps to build a commit-time histogram (24 bins, one per hour)
  2. After 14 days, the histogram is locked (or updated with slow rolling average)
  3. Determines "typical first commit hour" and "typical last commit hour"
  4. Creature wake/sleep schedule:
     - Wakes: 30 minutes before typical first commit hour
     - Gets sleepy: 30 minutes after typical last commit hour
     - Sleep triggers: after 10 minutes idle past the sleepy threshold

- **Wake sequence** (when creature transitions from sleep to awake):
  - Eyes: closed → squint → open (over 2s)
  - Body: sleep_curl → stretch (cat stretch — front paws forward, butt up) → stand (over 3s)
  - Mouth: yawn during stretch
  - Ears: droop → neutral → perk (over 2s)
  - Tail: tucked → low → sway (over 2s)

- **Sleep sequence** (when creature transitions from awake to sleep):
  - Yawns increase: one yawn every 2 minutes in the sleepy period, then every 30s in the last 5 minutes
  - Walk speed decreases: ×0.7 in sleepy period
  - Eyes: more frequent half-lidded states
  - Eventually: walks to a comfortable spot, kneading (if Critter+), then sleep_curl
  - Eyes close, breathing shifts to sleep rhythm (1.0–1.02, 3.5s period)

- **Out-of-schedule commits**: If a commit arrives at 3AM (well outside normal schedule):
  - Creature wakes groggy: slow blink, dramatic stretch, confused look
  - Slight circadian adjustment: typical schedule shifts by 15 minutes toward the unusual hour
  - `"...our secret"` if at late-night speech capacity

- Before 14 days of data: default schedule of 9AM wake / 6PM sleepy

**Constraints**:
- The circadian cycle is subtle — it shouldn't feel like a hard on/off switch
- The creature can be woken by events (touches, commits) at any time — it just naturally gravitates toward its schedule
- Commit timestamps are stored in the journal table; the circadian analyzer queries them
- In Phase 2 (no commits yet), the creature uses the default schedule. The circadian system is architecturally complete but has no data to learn from.

---

### P2-T3-06: Personality Influence on All Animations

**What**: Every animation in the creature's repertoire is modulated by personality axes.

**Acceptance Criteria**:
- `PersonalityModulator` class that takes a base animation parameter and returns a personality-adjusted value
- Modulation rules:

| Parameter | Energy Influence | Focus Influence | Discipline Influence | Verbosity Influence |
|-----------|-----------------|-----------------|---------------------|---------------------|
| Walk speed | ×(0.6 + E×0.8) | — | — | — |
| Walk duration | ×(1.5 - E×1.0) | ×(0.8 + F×0.4) | — | — |
| Idle duration | ×(0.5 + E×0.5) inverted (hyper = less idle) | — | — | — |
| Behavior cooldown | ×(0.6 + (1-E)×0.8) (hyper = shorter cooldowns) | — | — | — |
| Direction change frequency | — | ×(0.5 + (1-F)×1.0) (scattered = more changes) | — | — |
| Timing jitter | — | — | ±(3 + (1-D)×17)% (chaotic = more jitter) | — |
| Blink interval | ×(0.7 + (1-E)×0.6) | — | — | — |
| Tail sway amplitude | ×(0.7 + E×0.6) | — | — | — |
| Tail sway period | ×(0.7 + (1-E)×0.6) | — | ×(0.9 + D×0.2) | — |
| Reaction expressiveness | — | — | — | ×(0.5 + V×1.0) |
| Ear movement frequency | — | ×(0.5 + F×1.0) | — | — |

- All modulated values are clamped to sane ranges (no negative speeds, no 0-length durations)
- The modulator is called by the behavior stack and animation controllers — it doesn't directly animate

**Constraints**:
- Modulation must be deterministic: same personality + same base value = same result. No randomness in the modulator itself (randomness is in the behavior selector and jitter timer).
- The modulation factors are defined as data (a configuration table), not hardcoded if/else chains
- Two creatures with extreme opposite personalities (all 0.0 vs all 1.0) should look and act DRAMATICALLY differently when placed side by side

---

### P2-T3-07: Name Generation

**What**: Generate a unique two-syllable name from git user.email + machine UUID.

**Acceptance Criteria**:
- First syllable (12 options): Pip, Nub, Zep, Tik, Mox, Glo, Rux, Bim, Quo, Fen, Dax, Yol
- Second syllable (12 options): -o, -i, -us, -el, -a, -ix, -on, -y, -er, -um, -is, -ot
- 144 possible names: Pipo, Pipi, Pipus, Pipel, ... Yolot
- Hash function: `SHA256(git_user_email + machine_UUID)` → take first 8 bytes → `byte[0] % 12` for first syllable, `byte[1] % 12` for second syllable
- Deterministic: same email + same machine = always the same name
- Name is generated once at birth, stored in SQLite, and renameable via MCP (`pushling_nurture("identity", { name: "..." })`) in Phase 4

**Constraints**:
- If `git config user.email` is not set, use `"unknown@pushling"` as fallback
- Machine UUID obtained from `IOPlatformExpertDevice` or `sysctl hw.uuid`
- The name generation is pure and testable — no side effects

---

### P2-T3-08: Hatching Ceremony

**What**: The 30-second first-launch experience where the creature is born from git history.

**Acceptance Criteria**:
- Triggered on first launch when no creature exists in SQLite
- Duration: ~30 seconds
- Three phases:

**Phase 1 — Git History Montage (0–20s)**:
- Touch Bar shows a rapid-scrolling montage of the developer's git history
- Content scrolls from right to left:
  - Repo names in Tide color, large text
  - Language badges (colored dots with extension labels)
  - Commit count per repo
  - Total lines of code
  - Most common commit message words
- Speed: starts slow (first 5s), accelerates, reaches peak scroll speed at 15s
- Background: void black with occasional data-spark particles
- At the end: all text converges to a point at center of the bar

**Phase 2 — Materialization (20–27s)**:
- A single pixel of light appears at the convergence point
- The pixel pulses — breathing rhythm (this is the first breath)
- The pixel grows: 1px → 2px → 4px → 6px Spore over 5 seconds
- Colors shift through the P3 palette before settling on the creature's `base_color_hue`
- Faint particle halo forms and dissolves

**Phase 3 — Naming (27–30s)**:
- The Spore pulses warmly
- Name appears above it in Gilt text: "Zepus" (or whatever the generated name is)
- Text fades after 2 seconds
- Spore continues breathing — the creature is born
- Journal entry: `{ "type": "evolve", "data": { "from": null, "to": "spore", "name": "Zepus" } }`

- During the ceremony:
  - Git history scanner (P2-T3-02) runs in parallel, feeding data to the montage display
  - Personality axes and visual traits are computed and saved to SQLite
  - The creature row is created with all initial values

**Constraints**:
- The hatching ceremony plays ONCE in the creature's lifetime. It is never replayed (though it's recorded and can be recalled as a memory at Sage+).
- If the git scan finds zero repos/commits, the montage shows a gentle "empty" sequence: "No commits yet. That's okay. Every story starts somewhere." The creature is born with default personality (all axes at 0.5, specialty = polyglot).
- The ceremony must feel magical. This is the first impression. The moment a developer sees their git history become a living creature, they should feel something.
- If the app is quit during the ceremony, the creature is still created (state saved before ceremony starts). On re-launch, the ceremony does NOT replay — the creature simply exists.

---

### P2-T3-09: Absence-Based Wake Animation

**What**: The creature's wake-up animation scales with the duration of absence, as specified in the vision's Core Loop.

**Acceptance Criteria**:
- Track `last_activity_at` timestamp in SQLite (updated on any commit, touch, or session event)
- On wake (daemon launch or creature exits sleep), calculate absence duration:

| Absence Duration | Wake Animation |
|-----------------|----------------|
| < 1 hour | Quick stretch (1s). Business as usual. |
| 1-8 hours | Full yawn + stretch + knead (3s). Normal morning. |
| 8-24 hours | Big yawn, dramatic stretch, shake head, look around (4s). A full day passed. |
| 1-3 days | Stretch + sniff air + walk the bar cautiously. Curious about what changed. |
| 3-7 days | Emerges slowly, cobweb particles shake off (visual), excited run across bar once. Overjoyed to see activity. |
| 7+ days | Full cobweb emergence: creature literally shakes off Ash-colored thread sprites, zoomies across bar, tail poofed, extreme happiness expressions. No guilt — pure joy. |

- Absence is calculated from `last_activity_at` to current time on daemon launch
- Longer absence = more excited reunion animation (vision doc: "Longer absence = more excited reunion")
- After 7+ day absence, a brief `"you're back!"` text (if Critter+) or `"!"` (if Drop)
- Journal entry: `{ "type": "reunion", "absence_hours": N }`

**Constraints**:
- The reunion animation plays ONCE on the wake-up that follows the absence. Not repeated.
- Breathing continues throughout all wake animations
- This is an Autonomous layer behavior triggered on state load

---

### P2-T3-10: Late-Night Lantern

**What**: If the developer is coding past 10PM, the creature pulls out a tiny lantern and sits beside them. Solidarity, not judgment.

**Acceptance Criteria**:
- Trigger: active commits or Claude session after 10PM local time, creature is awake
- The creature produces a tiny lantern sprite (Gilt glow, 3x4pt, bob effect) and holds it
- Creature sits in a "companion" pose — seated, tail wrapped, lantern held near body
- Lantern casts a small warm glow radius (Gilt at alpha 0.1, 15pt radius)
- If no activity for 10 minutes, creature curls to sleep WITH the lantern (lantern dims to alpha 0.05)
- Lantern is dismissed when creature wakes in the morning or when time passes 5AM
- This is a Layer 1 autonomous behavior, not Claude-directed

**Constraints**:
- Lantern is NOT a placed object — it's a cosmetic visual attached to the creature
- No new node types needed — reuse existing sprite with Gilt tint
- Lantern behavior has a 30-minute cooldown after dismissal

---

### Track 3 Deliverable

A creature with a unique personality derived from the developer's git history, emotional states that shift in real-time, and circadian awareness. The personality visibly influences how the creature moves, how often it does things, and which behaviors it favors. The hatching ceremony provides a memorable first-launch experience. The name is deterministic and unique per developer+machine. Absence-based wake animations make reunions emotionally resonant, and late-night lantern behavior creates companionship moments.

---

## Phase 2 QA Gate

All of the following must be verified before Phase 2 is considered complete:

| # | Test | Pass Criteria |
|---|------|---------------|
| 1 | **Creature renders at each stage** | All 6 stages display correctly with proper proportions and visible parts |
| 2 | **Breathing NEVER stops** | Observed continuously for 60s during: idle, walk, behavior, sleep, evolution. `yScale` oscillates between 1.0 and 1.03 (or 1.0–1.02 during sleep) |
| 3 | **Blinking works** | Eyes blink at random intervals (3–7s). No blinks during closed-eye states. Double-blink occasionally occurs. |
| 4 | **Tail sways** | Continuous sine-wave sway during idle and walk. Stops appropriately during tail state overrides. |
| 5 | **Walk cycle looks natural** | Diagonal paw gait (FL+BR, FR+BL). Head bobs. Tail sways. Speed feels natural for the stage. |
| 6 | **Direction reversal is smooth** | 0.43s transition: decelerate → pause → flip → accelerate. No snapping. |
| 7 | **Behavior stack prioritizes correctly** | Physics always runs. Reflex (when triggered) overrides Autonomous. AI-Directed (when active) overrides Autonomous but not Reflex. |
| 8 | **Blend controller timings match spec** | Measure actual transition durations: reflex snap = 0.15s ±0.02s, expression change = 0.8s ±0.05s, direction reversal = 0.43s ±0.03s |
| 9 | **Cat behaviors trigger** | At least 5 different autonomous behaviors observed in a 10-minute session |
| 10 | **Personality affects behavior** | Two creatures with different personalities (Energy 0.1 vs 0.9) walk at measurably different speeds, idle for different durations, and prefer different behaviors |
| 11 | **Emotional states shift** | Emotional axes decay toward 50 over time. Emergent states trigger when conditions are met. |
| 12 | **Emergent states are visible** | Exhausted creature stumbles and sleeps. Playful creature bounces and has frequent behaviors. Zen creature loafs. |
| 13 | **Circadian cycle works** | Creature follows default 9AM/6PM schedule. Sleep sequence plays correctly. Wake sequence plays correctly. |
| 14 | **Hatching ceremony plays** | First launch with no state: 30-second ceremony runs, git history scrolls, creature materializes, name appears |
| 15 | **Name generation is deterministic** | Same email + UUID always produces the same name |
| 16 | **Evolution ceremony plays** | Manually trigger an evolution: 5-second ceremony runs with all 5 phases |
| 17 | **Frame budget maintained** | With creature + all animations running: frame time < 5.7ms average |
| 18 | **Node count within budget** | With creature + particles: node count < 120 (< 80 typical) |
| 19 | **State persists across relaunch** | Quit and relaunch: creature stage, personality, name, emotional state are preserved |
| 20 | **No visual glitches** | No sprite clipping, no z-order issues, no texture bleeding, no flicker during transitions |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Pixel art readability at 30pt | Medium | High | Test every sprite on actual Touch Bar hardware. Prioritize silhouette clarity over detail. |
| Walk cycle jitter at personality extremes | Medium | Medium | Clamp all modulated values. Unit test at extreme personality vectors (all 0, all 1, mixed). |
| Behavior stack > 1ms per frame | Low | High | Profile with Instruments. The stack is pure math — no allocations in the hot path. |
| Breathing interrupted by SKAction conflicts | Medium | Critical | Breathing is per-frame calculation, NOT an SKAction. This is non-negotiable. |
| Hatching ceremony too slow (git scan) | Medium | Medium | 30s timeout on scan. Background thread. Montage starts immediately with whatever data is available. |
| Too many particle nodes during evolution | Low | Medium | Pre-allocate emitter pool. Cap burst particles at 200 emitter birthRate, not 200 sprite nodes. |
| Personality differences not perceivable | Medium | High | Side-by-side testing with extreme personalities. Exaggerate modulation factors if subtle. |

---

## Glossary

| Term | Definition |
|------|-----------|
| **Layer Output** | A struct with optional properties — each layer's "opinion" about what the creature should be doing |
| **Resolution** | The process of picking the highest-priority non-nil value for each property across layers |
| **Blend** | The smooth interpolation from current visual state to resolved target state |
| **Emergent State** | A compound emotional state detected from the 4 emotional axes |
| **Reflex** | A short-lived, high-priority behavior override triggered by an input event |
| **Personality Modulation** | Adjusting a base animation parameter by the creature's personality axes |
| **Circadian Cycle** | The creature's learned sleep/wake schedule based on commit timestamps |
| **Behavior Pool** | The set of eligible cat behaviors for the behavior selector to choose from |
