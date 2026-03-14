# Phase 6: Interactivity

## Goal

The human is an active participant, not an audience member. Continuous touch interactions at 60Hz, object manipulation with physics, creature invitations that create interactive moments, human progression milestones that unlock new gestures, and mini-games that make the Touch Bar a play surface.

## Dependencies

- **Phase 2** (Creature with behavior stack, personality, emotion system, body part nodes)
- **Phase 3** (World with terrain objects, weather, biomes)
- **Phase 1** (SpriteKit scene, Touch Bar private API, SQLite state, IPC)

### Soft Dependencies

- Phase 4 (MCP tools) -- needed for Claude-initiated mini-games and co-presence events, but touch system can be developed independently
- Phase 5 (Speech) -- needed for creature speech reactions to touch, but touch responses can start with visual-only reactions

## Architecture Notes

### Where Touch Lives

- **Input handling**: `Pushling/Input/` -- gesture recognition, touch tracking, coordinate mapping
- **Touch-creature bridge**: `Pushling/Input/CreatureTouchHandler.swift` -- translates gestures into creature reactions
- **Object interaction**: `Pushling/Input/ObjectInteraction.swift` -- pick up, flick, tap on world objects
- **Mini-games**: `Pushling/Input/MiniGames/` -- game logic, scoring, UI
- **Milestone system**: `Pushling/State/Milestones.swift` -- touch counting, unlock tracking

### The Touch Bar Coordinate System

The Touch Bar is 1085 x 30 points (2170 x 60 pixels @2x). All touch coordinates in this plan reference the point coordinate system.

| Dimension | Range | Notes |
|-----------|-------|-------|
| X | 0 - 1085 | Left edge to right edge |
| Y | 0 - 30 | Bottom to top |
| Touch precision | Sub-pixel (float values) | Hardware supports finer than 1pt resolution |
| Touch update rate | 60Hz (matched to display) | Via NSTouchBar API |

**Hit testing**: Creature occupies a bounding box based on stage size (6x6 to 25x28 pts). Touch events are tested against this box with a 4pt padding (generous hit area for the narrow strip).

### Performance Budget

| System | Budget | Notes |
|--------|--------|-------|
| Gesture recognition | <0.5ms | Pattern matching on touch event stream |
| Hit testing | <0.1ms | Simple bounding box checks |
| Physics (object flick) | <0.3ms | SpriteKit built-in physics, few bodies |
| Mini-game logic | <0.2ms | Score calc, state updates |
| Total input overhead | <1.5ms | Well within 16.6ms frame budget |

---

## Track 1: Continuous Touch System (P6-T1)

**Owner**: `swift-input`
**Directory**: `Pushling/Input/`
**Estimated Tasks**: 12

### P6-T1-01: Touch Tracking System

**What**: Continuous sub-pixel touch tracking at 60Hz via the NSTouchBar API.

**Technical approach**:
- Override `touchesBegan(_:with:)`, `touchesMoved(_:with:)`, `touchesEnded(_:with:)`, `touchesCancelled(_:with:)` on the `SKView` hosting the SpriteKit scene
- Each touch event provides `NSTouch` with `normalizedPosition` in the touch bar's coordinate space
- Convert normalized position to scene coordinates: `x = normalized.x * 1085`, `y = normalized.y * 30`
- Track active touches in a dictionary keyed by touch identity (supports multi-touch)

**Touch state model** (`TouchState`):
```swift
struct TouchState {
    let id: ObjectIdentifier          // Touch identity
    var startPosition: CGPoint        // Where touch began
    var currentPosition: CGPoint      // Current position (updated at 60Hz)
    var previousPosition: CGPoint     // Position last frame
    var startTime: TimeInterval       // When touch began
    var duration: TimeInterval        // Running duration
    var velocity: CGVector            // Current velocity (pts/sec)
    var totalDistance: CGFloat         // Cumulative distance traveled
    var isOnCreature: Bool            // Touch started on creature hitbox
    var isOnObject: Bool              // Touch started on a world object
    var objectId: String?             // ID of touched object, if any
}
```

**Velocity calculation**: Exponential moving average of position deltas over last 4 frames. Provides smooth velocity for gesture classification.

**Multi-touch**: Track up to 3 simultaneous touches (hardware limit on the narrow strip). Each touch is independently tracked and classified.

**Depends on**: Phase 1 (SpriteKit scene, Touch Bar API integration)

---

### P6-T1-02: Gesture Recognizer Framework

**What**: Classify raw touch events into discrete gesture types.

**Custom recognizer** (not UIGestureRecognizer -- we're on NSTouchBar, not UIKit):
- Built as a state machine that processes the stream of touch events from P6-T1-01
- Multiple recognizers can evaluate simultaneously; highest-priority match wins

**Gesture definitions**:

| Gesture | Detection Rules | Priority |
|---------|----------------|----------|
| **Tap** | Touch duration < 200ms, total distance < 5pt | 5 |
| **Double-tap** | Two taps within 300ms, < 10pt apart | 6 |
| **Triple-tap** | Three taps within 450ms, < 10pt apart | 7 |
| **Long press** | Touch duration > 500ms, total distance < 5pt (stationary) | 4 |
| **Sustained touch** | Touch duration > 2000ms, total distance < 8pt (allows slight drift) | 3 |
| **Drag** | Touch moves > 10pt while held | 2 |
| **Slow drag** | Drag with velocity < 100pt/sec | 2 |
| **Fast drag/Flick** | Drag with velocity > 200pt/sec, touch ends mid-motion | 8 |
| **Petting stroke** | Slow drag (< 100pt/sec) across creature hitbox | 2 |
| **Multi-finger (2)** | 2 simultaneous touches detected | 9 |
| **Multi-finger (3)** | 3 simultaneous touches detected | 10 |
| **Rapid taps** | 3+ taps within 1 second, within 30pt area | 7 |

**Priority resolution**: When multiple gestures could match the same input, higher priority wins. For timed gestures (tap vs double-tap), the system waits the full window before committing (300ms wait after a tap to see if it becomes a double-tap).

**Gesture event dispatch**: Each recognized gesture produces a `GestureEvent`:
```swift
struct GestureEvent {
    let type: GestureType
    let position: CGPoint           // Primary touch point
    let velocity: CGVector          // At moment of recognition
    let touchCount: Int             // Number of fingers
    let duration: TimeInterval      // For held gestures
    let target: GestureTarget       // .creature, .object(id), .world, .commitText
}
```

**Depends on**: P6-T1-01 (raw touch tracking)

---

### P6-T1-03: Laser Pointer Mode

**What**: Dragging a finger (not on creature) creates a laser dot that the creature stalks and chases.

**Unlock requirement**: 100 total touches (human milestone, see P6-T2-03)

**Visual** (the dot):
- `SKShapeNode` circle, 3pt radius, Ember color (`#FF4D00`), full opacity
- Inner glow: Ember at 50% opacity, 5pt radius (gives a soft "laser" look)
- Tracks finger position at 60Hz (no interpolation lag -- direct position assignment)
- Faint trail: 4 afterimage nodes at decreasing opacity (0.6, 0.4, 0.2, 0.1), each delayed 1 frame, creating a comet tail effect

**Creature behavior**:

| Drag Speed | Creature Reaction |
|-----------|-------------------|
| Stopped (0 pt/sec) | Creature stops 10pt away, stares at dot. Tail tip twitches. Eyes locked on. Body lowers slightly. |
| Slow (< 50pt/sec) | Stalk mode: creature follows at 80% of drag speed. Body low, ears forward, predator crouch walk. |
| Medium (50-150pt/sec) | Trot: creature follows at 90% of drag speed. Normal walk cycle but faster. Ears up, eyes tracking. |
| Fast (> 150pt/sec) | Sprint chase: creature runs at max speed (100pt/sec). Cannot keep up with very fast drags. Ears flat back. |
| Direction change | Creature overshoots slightly, slides, reverses. 0.2s reaction delay. Cat-like inertia. |

**Pounce trigger**: If drag stops for > 0.5s, creature does predator crouch + butt wiggle (0.5s), then pounces at the dot. If finger is still there, dot "escapes" (jumps 30pt in random direction). If finger has lifted, pounce lands on last position -- satisfaction boost (+5).

**End behavior**: When drag ends (finger lifts), the dot fades over 0.3s. Creature sniffs the last position, looks around confused, resumes autonomous behavior.

**Depends on**: P6-T1-02 (drag gesture recognition), P6-T2-03 (unlock at 100 touches), Phase 2 creature movement system

---

### P6-T1-04: Petting Stroke

**What**: Slow drag across the creature produces fur ripple and contentment.

**Unlock requirement**: 50 total touches (human milestone, see P6-T2-03)

**Detection**: Slow drag (< 100pt/sec) where the touch path crosses the creature's hitbox for at least 15pt of horizontal travel.

**Visual response**:
1. **Fur ripple**: A wave of brightness travels across the creature body in the drag direction. Implemented as a 4pt-wide highlight band (Bone color at +20% brightness) that moves across the body sprite at 1.5x drag speed, from entry point to exit point.
2. **Purr particles**: Small warm particles (Gilt color, 1pt, 8 per second) emit from creature body during stroke. Rate increases with consecutive strokes.
3. **Body reaction**: Creature leans slightly into the stroke direction (1pt body offset toward drag).
4. **Eye response**: Eyes half-close (squint) during stroke.
5. **Ear response**: Ears tilt toward stroke direction.

**Stroke counting**:
- Each full pass across the creature body counts as 1 stroke
- After 3 strokes in succession (within 5 seconds):
  - Slow-blink animation (the trust signal)
  - Creature lies down (if standing)
  - Contentment spikes (+15)
  - Purr particle rate doubles
  - If TTS active: soft purr sound effect

**Stroke direction matters**:
- Head-to-tail (left-to-right if creature faces right): preferred. Maximum contentment boost.
- Tail-to-head (against the grain): creature's ears twitch. First stroke is tolerated. Third against-grain stroke: creature stands up and walks away (2-second huff). Personality dependent: high-energy creatures tolerate it; low-energy creatures refuse after 1.

**Depends on**: P6-T1-02 (slow drag gesture), Phase 2 creature body parts (fur ripple needs body sprite access)

---

### P6-T1-05: Object Flick/Launch

**What**: Swipe through a world object to launch it with physics.

**Detection**: Fast drag (> 200pt/sec) passing through or near (< 8pt) a world object.

**Physics response**:
- Object receives an impulse in the swipe direction
- Impulse magnitude: `velocity * object_mass_factor`
- Object mass factors:
  | Object Type | Mass Factor | Flight Behavior |
  |-------------|------------|-----------------|
  | Ball | 0.8 | Rolls and bounces (restitution 0.7) |
  | Yarn ball | 0.6 | Rolls with slight unraveling particle trail |
  | Feather | 0.2 | Floats with sine-wave drift, slow descent |
  | Rock | 1.5 | Short flight, heavy landing (screen shake 0.5pt) |
  | Flower | 0.3 | Petal particles scatter on launch |
  | Star fragment | 0.4 | Sparkle trail during flight |

- Gravity: 60pt/sec^2 downward (objects arc and land on terrain)
- Friction: objects come to rest after 1-3 seconds depending on mass
- Boundary: objects stop at Touch Bar edges (0 and 1085), slight bounce (restitution 0.3)

**Creature chase response**:
- If creature sees the flicked object (within 200pt and facing toward it): chases
- Chase speed: creature's run speed (60pt/sec for Beast)
- On reaching object: personality-dependent response:
  - High energy: bats it further (another physics impulse, 50% of original)
  - High focus: examines it carefully (sniff animation 1s)
  - Low energy: sits next to it, looks at human
  - High discipline: carries it back to where it was (fetch!)

**Depends on**: P6-T1-02 (flick gesture), Phase 3 world objects (object nodes with physics bodies)

---

### P6-T1-06: Object Pick Up and Move

**What**: Long-press a world object to grab it, drag to reposition.

**Detection**: Long press (> 500ms) on a world object's hitbox.

**Pick-up sequence**:
1. Object highlights (brightness +20%, subtle glow aura)
2. Object detaches from terrain (slight upward float, 2pt)
3. Object follows finger position at 60Hz, offset so the touch point maintains its relative position on the object
4. Object has slight lag (lerp at 0.85 per frame) creating a "weighted" feel

**While dragging**:
- Object casts a small shadow below it (1pt offset, 40% opacity Ash circle)
- Creature watches the object move. Head and eyes track it. Ears forward.
- If dragged near creature (< 15pt): creature reaches toward it (paw extends)

**Drop**:
- Finger lifts: object falls to terrain at drop position (0.15s drop animation with slight bounce)
- Object re-anchors to new terrain position
- Creature trots over to investigate new location (sniff, examine, 1.5s)
- Position persists in SQLite (object's coordinates updated)

**Constraints**:
- Cannot pick up repo landmarks (they're background decoration, not foreground objects)
- Cannot move objects off-screen (clamped to 10-1075 X range)
- Minimum 20pt spacing between objects enforced on drop (object slides to nearest valid position if too close to another)

**Depends on**: P6-T1-02 (long press gesture), Phase 3 world objects

---

### P6-T1-07: Hand-Feeding Commits

**What**: Instead of autonomous drift, the human drags commit text toward the creature for a bonus.

**Detection**: When commit text has materialized (Phase 5 P5-T3-01/02) and is drifting, a touch on the text stops the autonomous drift and lets the human drag it.

**Sequence**:
1. Touch on drifting commit text: text "sticks" to finger, stops autonomous movement
2. Drag text toward creature: text follows finger at 60Hz
3. When text is within 15pt of creature mouth: eating begins
4. Eating animation is the same as P5-T3-04 but with one difference: creature eats "from the hand" -- head tilts upward slightly, more gentle eating animation (no predator pounce)

**XP bonus**: +10% on top of final calculated XP. Displayed as: `+12 (+1 hand-fed)` in the XP float.

**Intimacy bonus**: +5 contentment (hand-feeding is a bonding moment).

**If human drags text away**: Text continues to follow finger. If finger lifts while text is not near creature, text resumes autonomous drift from current position.

**Depends on**: P6-T1-01 (touch tracking), Phase 5 P5-T3-01 (commit text nodes), Phase 5 P5-T3-04 (eating animation)

---

### P6-T1-08: Rapid Tap Pounce Game

**What**: 3+ rapid taps near the creature trigger a hunt-and-pounce game.

**Detection**: 3+ taps within 1 second, within 30pt horizontal area, within 50pt of creature.

**Sequence**:
1. Each tap creates a dust puff particle at tap location (3-5 Ash particles, 0.3s lifetime)
2. Creature's eyes lock onto the tap area (tracking the most recent tap position)
3. After 3rd tap: creature enters hunt mode -- drops into predator crouch, ears flat
4. After a 0.3s beat (the tension): creature pounces at the LAST tap location
5. **Catch mechanic**: if the human taps at the pounce landing spot within 0.3s of landing (timing window), it's a CATCH
   - **Catch**: sparkle burst (20 Gilt particles), satisfaction +5, creature looks proud, brief `"got it!"` at Beast+
   - **Miss**: creature lands, looks around confused, shakes head. No penalty.

**Repeat**: After a catch or miss, the game resets. Can be triggered again immediately.

**Depends on**: P6-T1-02 (rapid tap gesture), Phase 2 creature pounce animation

---

### P6-T1-09: Wake-Up Boop

**What**: Tap a sleeping creature's nose to gradually wake it.

**Detection**: Tap on the creature while creature is in sleep state. Hit test is specifically the head/nose area (top-center of creature hitbox).

**Three-tap progressive wake sequence**:

| Tap | Creature Response | Duration |
|-----|-------------------|----------|
| 1st | Nose twitches (0.1s wiggle). One eye opens halfway. Ear flicks. Then resettles. | 0.8s |
| 2nd | Both eyes open partway. Full body stretch (front paws forward, butt up). Yawns. Eyes close again. | 1.5s |
| 3rd | Big yawn. Eyes open fully. Stands up. Stretch. Shakes head. Blinks. Awake! | 2.0s |

**Timing**: Each tap must occur within 5 seconds of the previous. If 5s passes without the next tap, creature resettles to full sleep (animation resets). The human has to commit to waking it up.

**Emotional impact**: Waking via boop sets contentment +10 and energy to at least 30 (gentle wake). Compare to natural wake which preserves whatever the energy level was.

**Not forced**: This is the ONLY way to manually wake the creature. It's gentle and requires patience. There is no "slam awake" mechanic.

**Depends on**: P6-T1-02 (tap gesture), Phase 2 creature sleep state

---

### P6-T1-10: Tap-on-Object

**What**: Tapping a world object draws the creature's attention.

**Detection**: Tap gesture where target is a world object (not creature, not empty space).

**Object response**: Brief highlight animation:
- Object bounces (scale 1.0 -> 1.15 -> 1.0 over 0.2s)
- Brief sparkle (2-3 small Gilt particles)

**Creature response**:
1. Ears perk toward the tapped object (0.15s)
2. Head turns toward object (0.2s)
3. Creature trots over to object (walking speed, may take 1-3 seconds depending on distance)
4. On arrival: personality-dependent investigation:
   - High curiosity: extended examination (sniff 1s, paw at object 0.5s, circle it 1s)
   - Low curiosity: brief glance (head tilt 0.5s), resumes walking
   - If object is a toy type (ball, yarn): may start playing with it autonomously

**Cooldown**: Same object can only be "called to attention" every 30 seconds. Different objects have no cooldown.

**Depends on**: P6-T1-02 (tap gesture), Phase 3 world objects, Phase 2 creature movement

---

### P6-T1-11: Belly Rub (Unlockable)

**What**: 2-finger sustained touch on the creature triggers a belly rub with a 30% trap chance.

**Unlock requirement**: 250 total touches (human milestone, see P6-T2-03)

**Detection**: 2 simultaneous touches detected, both within creature hitbox, held for > 1 second.

**Normal response** (70% chance):
1. Creature rolls onto back (0.5s animation)
2. Belly exposed. Paws in the air. Eyes half-closed.
3. Sustained contentment particle emission (warm Gilt particles, 10/sec)
4. Purr sound if TTS active
5. Continues as long as 2-finger touch is held (up to 30 seconds)
6. On release: creature rolls back, stretches, satisfied expression

**Trap response** (30% chance):
1. Creature rolls onto back (same as above, 0.5s)
2. Appears to enjoy it for 1 second...
3. TRAP: all four paws grab (clamp onto touch area), rapid kick animation (back legs kick 4 times over 0.6s)
4. Brief struggle animation
5. Creature releases, rolls away, looks smug. Tail swishes.
6. No contentment boost (the belly rub was a ruse)
7. Speech at Beast+: `"got you"` with mischief expression

**Personality influence**: High-discipline creatures trap less often (20%). Low-discipline creatures trap more (40%). The creature is still a cat.

**Depends on**: P6-T1-02 (multi-finger sustained touch), P6-T2-03 (unlock at 250 touches), Phase 2 creature body animations

---

### P6-T1-12: Touch Milestone Tracking

**What**: Count and categorize all touch interactions for milestone progression.

**Tracking schema** (SQLite `touch_stats` table):
| Column | Type | Purpose |
|--------|------|---------|
| total_touches | INTEGER | Lifetime total touch events |
| taps | INTEGER | Single taps |
| double_taps | INTEGER | Double taps |
| triple_taps | INTEGER | Triple taps |
| long_presses | INTEGER | Long press events |
| sustained_touches | INTEGER | Sustained (>2s) touches |
| drags | INTEGER | Drag/swipe events |
| petting_strokes | INTEGER | Petting stroke completions |
| flicks | INTEGER | Object flick events |
| rapid_taps | INTEGER | Rapid tap sequences |
| boops | INTEGER | Sleeping creature nose taps |
| belly_rubs | INTEGER | Belly rub initiations |
| hand_feeds | INTEGER | Commits hand-fed |
| laser_pointer_seconds | REAL | Total time in laser pointer mode |
| daily_interaction_streak | INTEGER | Consecutive days with >= 1 touch |
| last_interaction_date | TEXT | Date of last touch |

**Counting rules**:
- Every touch event increments `total_touches` AND the specific gesture counter
- A double-tap counts as 1 double_tap (not 2 taps and 1 double_tap)
- A triple-tap counts as 1 triple_tap only
- Petting strokes count when a full stroke completes (not on start)
- Daily streak: at least 1 touch interaction in a calendar day. Resets to 0 if a day is missed.

**Depends on**: P6-T1-02 (gesture events feed into counters), Phase 1 state system

---

## Track 2: Human Progression (P6-T2)

**Owner**: `swift-input` (milestone aspect), `swift-state`
**Directory**: `Pushling/Input/Milestones.swift`, `Pushling/State/`
**Estimated Tasks**: 6

### P6-T2-01: Touch Counter in SQLite

**What**: Persist touch counts across sessions and provide efficient lookup.

**Table**: `touch_stats` (schema from P6-T1-12)

**Update frequency**: Batch write every 30 seconds (not per-touch, to avoid write amplification). In-memory counters accumulate, flushed periodically and on app termination.

**Read access**: MCP server can read touch stats via `pushling_sense("developer")` for Claude to know how interactive the human is. Read-only from MCP (as per architecture rules).

**Migration**: This table is added in schema version N (determined during Phase 1). Default values are all 0.

**Depends on**: Phase 1 state system, P6-T1-12 (provides the counts)

---

### P6-T2-02: Milestone Unlock System

**What**: Check touch counts against thresholds and trigger unlocks.

**Check frequency**: After every batch write to SQLite (every 30 seconds), AND immediately after any touch event that could cross a threshold (the in-memory counters are checked even before the batch write).

**Milestone table**:
| Milestone ID | Threshold | What Unlocks | Gesture Taught |
|-------------|-----------|-------------|----------------|
| `first_touch` | 1 total touch | Basic tutorial displays | Tap, double-tap, long-press |
| `finger_trail` | 25 total touches | Dragging leaves sparkle trail creature chases | Drag gesture |
| `petting` | 50 total touches | Petting stroke gesture enabled | Slow drag across creature |
| `laser_pointer` | 100 total touches | Laser pointer mode enabled | Drag (not on creature) |
| `belly_rub` | 250 total touches | Belly rub gesture enabled | 2-finger sustained touch |
| `pre_contact_purr` | 500 total touches | Creature purrs BEFORE touch contact (anticipation) | N/A (passive) |
| `touch_mastery` | 1000 total touches | All interactions have enhanced particle effects | N/A (passive) |

**Unlock state storage**: SQLite `milestones` table:
| Column | Type | Purpose |
|--------|------|---------|
| milestone_id | TEXT PK | e.g., "laser_pointer" |
| unlocked | BOOLEAN | Whether unlocked |
| unlocked_at | DATETIME | When unlocked |
| ceremony_played | BOOLEAN | Whether the unlock ceremony has been shown |

**Gesture gating**: Before a gesture handler executes, it checks the milestone table. If the gesture isn't unlocked, the touch is treated as a basic tap. No error shown -- the gesture simply doesn't activate. This prevents confusion: the user doesn't know belly rub exists until they unlock it.

**Depends on**: P6-T2-01 (touch counter), Phase 1 state system

---

### P6-T2-03: Milestone Unlock Details

**What**: Detailed specification of what each milestone unlocks and how it works.

**Milestone: `first_touch` (1 touch)**
- Tutorial overlay: semi-transparent instruction panel at bottom of Touch Bar
- Shows 3 gestures with icons: "Tap = Pet", "Double-tap = Play", "Hold = Examine"
- Auto-dismisses after 5 seconds or on any touch
- Only shows once (tracked in milestones table)

**Milestone: `finger_trail` (25 touches)**
- When dragging (anywhere), a sparkle trail follows the finger
- Trail: 6 small Gilt particles per second along the drag path, 0.4s lifetime, fade to transparent
- Creature notices the trail and chases it (similar to laser pointer but with less intensity)
- This is a teaser for the full laser pointer unlock at 100

**Milestone: `petting` (50 touches)**
- Enables the petting stroke mechanic (P6-T1-04)
- Before unlock: slow drags across creature produce a basic head-turn acknowledgment but no fur ripple or purr

**Milestone: `laser_pointer` (100 touches)**
- Enables full laser pointer mode (P6-T1-03)
- Before unlock: the finger_trail sparkle still works, but no Ember dot and no stalk/chase behavior

**Milestone: `belly_rub` (250 touches)**
- Enables belly rub mechanic (P6-T1-11)
- Before unlock: 2-finger touch on creature produces a standard sustained-touch response (chin scratch)

**Milestone: `pre_contact_purr` (500 touches)**
- Creature detects touch approaching (finger placed on Touch Bar, not yet on creature) within 30pt
- Creature's ears rotate toward the approaching touch
- Soft purr begins BEFORE contact
- When contact is made: purr intensifies, creature leans toward touch
- Eerie, delightful -- the creature knows you're coming

**Milestone: `touch_mastery` (1000 touches)**
- All touch interactions produce 2x particles
- Tap hearts are larger and brighter
- Petting sparkles are more vivid
- Laser pointer dot has a more dramatic trail
- Crumb particles during commit eating are enhanced
- The whole experience becomes more responsive and lush

**Depends on**: P6-T2-02 (unlock system), P6-T1-03, P6-T1-04, P6-T1-11 (individual gesture implementations)

---

### P6-T2-04: Unlock Ceremony

**What**: Visual and interactive notification when a milestone is achieved.

**The ceremony** (3 seconds):
1. **Flash** (0.3s): Brief white flash across Touch Bar at 20% opacity. Screen shake 0.5pt.
2. **Banner** (2.0s): Gilt-colored banner slides in from right edge. Contains:
   - Milestone name in 6pt Bone text: "PETTING UNLOCKED"
   - Small icon representing the gesture (a simple SpriteKit shape -- e.g., a curved line for petting)
3. **Demonstration** (1.5s, overlaps with banner): Creature performs the newly unlocked gesture once:
   - Petting: creature fur ripples autonomously
   - Laser pointer: small Ember dot appears, creature's eyes track it
   - Belly rub: creature briefly rolls onto back and rolls up
4. **Dismiss** (0.7s): Banner fades out. Creature resumes normal behavior.

**Non-blocking**: The ceremony is a reflex-priority animation. If human touches during the ceremony, the ceremony is acknowledged (creature ears turn) and continues. If human performs the newly unlocked gesture during the ceremony, extra celebration particles.

**Journal entry**:
```json
{
  "type": "milestone",
  "milestone_id": "petting",
  "timestamp": "2026-04-01T14:00:00Z",
  "total_touches_at_unlock": 52
}
```

**Depends on**: P6-T2-02 (unlock triggers the ceremony)

---

### P6-T2-05: Pet Streak Tracking

**What**: Track daily interaction streaks and reward consistency.

**Streak rules**:
- A "pet day" is any calendar day where at least 1 touch interaction occurs
- Streak increments at midnight if the current day has at least 1 touch
- Streak resets to 0 if a full calendar day passes with no touch
- Streak is stored in `touch_stats.daily_interaction_streak`

**7-day streak reward** ("creature brings daily gift"):
- After 7 consecutive days, the creature begins a daily gift behavior:
- Once per day (first touch of the day), creature trots to screen edge, reaches "offscreen", pulls back a small item
- Item is a cosmetic world object or decoration (from a curated pool of 20 items):
  - Tiny flowers, colored pebbles, shiny buttons, miniature stars, acorn, seashell, glass bead, feather, crystal shard, mushroom, leaf, pine cone, thimble, marble, compass, tiny key, pocket watch, prism, snowflake ornament, dried flower
- Item is placed in the world as a decorative object
- Creature looks at human, then at gift, then at human. Expectant.
- Tap the gift: creature beams, satisfaction +10, gift stays in world permanently

**Streak display**: Visible in the stats overlay (3-finger swipe). Flame icon + number.

**Depends on**: P6-T2-01 (touch counter), P6-T1-12 (daily tracking), Phase 3 world objects (for gift placement)

---

### P6-T2-06: "Paying Attention" Rewards

**What**: Tapping during the creature's autonomous behavior shows you noticed, rewarding both parties.

**Detection**: Human taps within 1 second of the creature performing any of these autonomous behaviors:
| Autonomous Behavior | Tap Window | Reward |
|--------------------|------------|--------|
| Zoomies | During the run | "noticed!" sparkle, +3 satisfaction |
| Catching a mouse | During the pounce | "you saw!" sparkle, +5 satisfaction |
| Sneezing | Within 0.5s of sneeze | Creature looks sheepish, +2 satisfaction |
| Finding something | During examination | Creature holds it up to show you, +3 satisfaction |
| Knocking something off | During or within 1s after | Creature looks guilty AND proud, +2 satisfaction |
| Slow-blink | During the blink | Mutual moment -- extended slow-blink, +5 contentment |
| First word ceremony | During the word | Extended emotional moment, +10 contentment |

**Visual feedback**: Brief sparkle ring around the creature (Gilt particles in a 10pt radius circle, 0.3s). Different from regular tap response -- this is a "we had a moment" indicator.

**Frequency**: Only counts once per behavior instance. Can't spam-tap a single zoomie for multiple rewards.

**Depends on**: P6-T1-02 (tap gesture), Phase 2 autonomous behavior system (need to know when behaviors are active)

---

## Track 3: Creature Invitations & Mini-Games (P6-T3)

**Owner**: `swift-creature` (invitation system), `swift-input` (mini-game input)
**Directory**: `Pushling/Input/MiniGames/`, `Pushling/Creature/Invitations.swift`
**Estimated Tasks**: 11

### P6-T3-01: Invitation System

**What**: The creature creates interactive moments 1-2 times per hour during active use.

**Scheduling**:
- Active use = at least 1 touch or commit in the last 5 minutes
- Check every 60 seconds: should an invitation fire?
- Probability per check: base 3% (gives ~1.8 invitations per hour with 60 checks)
- Cooldown: minimum 20 minutes between invitations
- No invitations during: sleep, evolution ceremony, mini-game, Claude-directed sequence
- Drought timer: if no invitation has fired in 40 minutes of active use, probability doubles to 6%

**Invitation lifecycle**:
1. **Setup** (0.5-1s): Creature performs the invitation-specific setup animation
2. **Offer** (up to 10s): Creature waits for human response. May look at camera expectantly. Repeated subtle invitation cues every 3 seconds.
3. **Human accepts** (via appropriate touch): Interaction or mini-game begins
4. **Human ignores** (10s timeout): Creature resolves the situation on its own (see P6-T3-03)

**Invitation selection**: Weighted random from available types, personality-influenced:
- High energy creatures invite more often (4% base instead of 3%)
- High curiosity creatures favor exploration invitations
- Creature's current emotion affects selection (playful -> toy, studious -> discovery)

**Depends on**: Phase 2 creature behavior system, P6-T1-02 (gesture recognition for acceptance)

---

### P6-T3-02: Invitation Types (6 Types)

**What**: Define the 6 invitation scenarios.

**1. Ball Push**
- Setup: Creature pushes a ball/toy toward screen edge, looks up at human
- Accept: Human flicks ball back (P6-T1-05 flick gesture)
- Interaction: Fetch game -- creature chases, pushes back, back-and-forth 3-5 volleys
- Reward: +5 satisfaction, +3 contentment per volley
- Resolve (ignored): Creature bats ball around alone, brief solo play, resumes idle

**2. Glowing Object**
- Setup: Strange glowing object (Dusk-colored, pulsing, 4pt) spawns near creature. Creature sniffs cautiously, backs away, looks at human.
- Accept: Human taps the glowing object
- Interaction: Object transforms -- hatches into a butterfly, opens into a flower, splits into sparkles, reveals a tiny music box. Random from 5 transformation types. Brief spectacle (2s).
- Reward: +8 curiosity, +5 satisfaction. Transformation result may persist as a temporary world object (5 min).
- Resolve (ignored): Creature cautiously approaches, paws at object, it dissolves harmlessly. Slight disappointment expression.

**3. New Word Encouragement** (Critter+ only)
- Setup: Creature says a new word hesitantly, with a `"?"` at the end. Looks at human.
- Accept: Human taps the creature (encouraging)
- Interaction: Word solidifies in creature's vocabulary (bubble text goes from 50% opacity to 100%, gains Gilt outline flash). Creature beams. Word is added to the creature's active vocabulary list.
- Reward: +5 contentment, word permanently in vocabulary
- Resolve (ignored): Word fades, creature looks briefly sad, resumes walking. Word is NOT added to vocabulary. (Not punitive -- it will try again later with a different word.)

**4. Stuck on Terrain** (Critter+ only, requires Phase 3 terrain objects)
- Setup: Creature walks to a terrain object (rock, log) and can't pass. Paws at obstacle, looks at human. Silent meow (mouth opens, no sound at stages without TTS).
- Accept: Human taps the obstacle
- Interaction: Obstacle slides aside (2pt movement with physics). Creature squeezes through, grateful expression, tail up.
- Reward: +3 contentment, +2 satisfaction
- Resolve (ignored): Creature backs up, runs around the obstacle the long way, slightly exasperated expression.

**5. Fish Offering** (Beast+ only, requires creature near water terrain)
- Setup: Creature holds up a small caught fish sprite (3pt, Tide colored), offers it toward screen edge.
- Accept: Human taps the fish
- Interaction: Fish is "accepted" (flies toward screen edge, disappears). Stored in a collection counter (`fish_accepted` in SQLite). Creature purrs with pride.
- Reward: +5 satisfaction, +3 contentment. Every 5 fish accepted: creature brings a "golden fish" worth double.
- Resolve (ignored): Creature eats the fish itself. Satisfied but slightly less so than if the gift was accepted.

**6. Commit Release**
- Setup: During commit arrival (P5-T3-02), creature crouches with butt wiggle, waiting...
- Accept: Human taps to "release" the commit text (like saying "go!")
- Interaction: Creature pounces with extra energy (1.5x normal pounce arc). The release-hunt is more dramatic than autonomous eating.
- Reward: +10% XP bonus (stacks with hand-feeding bonus if applicable), +3 satisfaction
- Resolve (if human doesn't tap within 3s): Creature pounces on its own (normal eating sequence)

**Depends on**: P6-T3-01 (scheduling system), P6-T1-02 (gesture recognition), Phase 2 creature animations, Phase 3 terrain objects

---

### P6-T3-03: Invitation Timeout & Self-Resolution

**What**: How invitations resolve when the human doesn't respond.

**Global rules**:
- Timeout: 10 seconds after invitation setup completes
- Creature resolves on its own -- never left in a broken state
- No punishment or guilt for ignoring (the creature manages fine alone)
- Self-resolution is slightly less rewarding than human participation (half the satisfaction/contentment boost)
- Brief "well, okay then" expression (0.5s) before self-resolution

**Self-resolution animations**:
| Invitation | Self-Resolution |
|-----------|-----------------|
| Ball push | Bats ball around solo, 3 swats, ball rolls away |
| Glowing object | Approaches, paws cautiously, object dissolves into harmless sparkles |
| New word | Word fades, creature shakes head slightly, tries again later |
| Stuck on terrain | Backs up, takes the long way around |
| Fish offering | Eats the fish, brief self-satisfied expression |
| Commit release | Pounces on its own (standard eating sequence) |

**Journal logging**: Self-resolutions are logged differently from accepted invitations:
```json
{
  "type": "invitation",
  "invitation_type": "ball_push",
  "accepted": false,
  "self_resolved": true,
  "timestamp": "2026-04-15T10:00:00Z"
}
```

**Depends on**: P6-T3-02 (invitation types), P6-T3-01 (scheduling)

---

### P6-T3-04: Mini-Game System Framework

**What**: Shared framework for all mini-games: lifecycle, scoring, input routing, UI.

**Mini-game lifecycle**:
```
Trigger -> Intro (1s) -> Active Play (30-60s) -> End -> Result Screen (3s) -> Return to Normal
```

**Trigger sources** (3 ways to start a game):
1. **Creature invitation**: Creature presents a game-starting gesture (see P6-T3-02 for invitations that lead to games)
2. **Claude MCP**: `pushling_perform({game: "catch"})` -- Claude initiates
3. **Human gesture**: Specific gesture mapped to each game (e.g., rapid taps near creature -> Catch begins)

**Active play state**:
- During a mini-game, the normal behavior stack is suspended
- Only Physics layer continues (breathing, gravity)
- Touch input is routed to the mini-game's input handler instead of normal gesture processing
- The world continues rendering (weather, day/night) but no autonomous creature behaviors
- Mini-game has its own SpriteKit layer (above world, below weather)

**Scoring**:
```swift
struct GameResult {
    let gameType: MiniGameType
    let score: Int
    let personalBest: Bool           // Is this a new high score?
    let duration: TimeInterval       // How long the game lasted
    let xpAwarded: Int              // XP earned
    let satisfactionBoost: Int       // Satisfaction gained
}
```

**XP awards by score tier**:
| Score Tier | XP | Satisfaction |
|-----------|-----|-------------|
| Low (< 30% of max) | 3 | +5 |
| Medium (30-70%) | 5 | +10 |
| High (> 70%) | 8 | +15 |
| Perfect | 12 | +20 |

**Personal best storage**: SQLite `game_scores` table:
| Column | Type |
|--------|------|
| game_type | TEXT |
| high_score | INTEGER |
| total_plays | INTEGER |
| last_played | DATETIME |

**Depends on**: P6-T1-02 (gesture input), Phase 1 SpriteKit scene, Phase 2 creature (for reactions)

---

### P6-T3-05: Catch Mini-Game

**What**: Stars fall from the top of the Touch Bar; move the creature to catch them.

**Setup**: Game area is the full 1085pt width. Stars fall from Y=30 (top).

**Gameplay**:
- Stars spawn at random X positions at the top, fall at 40pt/sec
- Star size: 3pt, Gilt color, twinkling (opacity oscillation 0.7-1.0, 0.5s period)
- Spawn rate: starts at 1 per 2 seconds, increases to 1 per 0.8 seconds by end
- Duration: 30 seconds

**Input**: Tap left or right of creature to move it in that direction.
- Tap left of creature: creature walks left at 50pt/sec for 0.3s (burst movement)
- Tap right: same, rightward
- Rapid taps = faster repositioning
- Edge clamping: creature stops at bar edges

**Catching**: Star enters creature's hitbox -> caught!
- Visual: star sparkles and is absorbed (0.15s)
- Sound: if TTS active, brief chime
- Score: +1 per star

**Cooperative mode** (if Claude is connected):
- Claude can also move the creature via `pushling_move`
- If human tap and Claude move happen within 0.3s and in the same direction: COMBO!
- COMBO: double points for next catch, extra sparkle, creature glows briefly
- COMBOs create a "co-presence" moment (diamond brightens)

**Missed stars**: Star hits the ground (Y=0), small puff of Ash particles, no penalty.

**End**: After 30s, remaining stars float away. Score tally.

**Depends on**: P6-T3-04 (game framework), P6-T1-02 (tap input)

---

### P6-T3-06: Memory Mini-Game

**What**: Creature shows a sequence of symbols; human repeats it via gestures.

**Gameplay**:
- Creature displays a sequence of 3-8 symbols (increasing difficulty)
- Each symbol corresponds to a gesture:
  | Symbol | Gesture to Repeat |
  |--------|------------------|
  | Circle (Gilt) | Tap |
  | Diamond (Tide) | Double-tap |
  | Star (Ember) | Long press (> 0.5s) |
  | Wave (Moss) | Swipe left-to-right |

- Creature shows symbols one at a time (0.8s each, 0.3s gap)
- After sequence shown, human has 1.5s per symbol to input the correct gesture
- Correct input: symbol flashes green (Moss), chime
- Wrong input: symbol flashes red (Ember), buzz. Sequence ends.

**Difficulty progression**:
| Round | Sequence Length | Display Speed |
|-------|----------------|--------------|
| 1 | 3 | 0.8s per symbol |
| 2 | 4 | 0.7s per symbol |
| 3 | 5 | 0.6s per symbol |
| 4+ | 6-8 | 0.5s per symbol |

**Score**: Points per correct symbol in sequence. Bonus for completing a full round. Perfect round = 2x multiplier on next round's points.

**Cooperative**: Claude can call the same symbols via MCP, contributing to the sequence input. Human handles even-numbered symbols, Claude handles odd (or vice versa).

**Duration**: Until wrong answer or all rounds cleared (max ~60 seconds).

**Depends on**: P6-T3-04 (game framework), P6-T1-02 (gesture input)

---

### P6-T3-07: Treasure Hunt Mini-Game

**What**: Find buried treasure using hot/cold hints from the creature.

**Gameplay**:
- A treasure is hidden at a random X position on the Touch Bar (unknown to human)
- The creature provides hot/cold hints based on the distance between the human's last swipe and the treasure

**Hint system**:
| Distance to Treasure | Creature Hint |
|---------------------|---------------|
| > 500pt | Creature shivers. Speech: "cold..." (if Critter+) or snowflake symbol |
| 200-500pt | Creature looks around. Speech: "hmm..." or "?" symbol |
| 100-200pt | Ears perk up. Speech: "warmer!" or "!" symbol |
| 50-100pt | Tail wags fast. Speech: "hot!" or "!!" symbol |
| < 50pt | Eyes wide, bouncing. Speech: "HERE!" or star symbol |
| < 15pt | Treasure found! |

**Input**: Swipe left or right to "explore". Each swipe moves the search position 50-100pt in swipe direction. Creature walks to the search position.

**Treasure reveal**: When found:
- Creature digs (front paw animation, 1s)
- Object emerges from ground with sparkle burst
- Treasure is a random world object (may persist if the human taps it within 3s)

**Duration**: 60 seconds max. If not found: creature digs it up itself, shows it to human, slight disappointment.

**Score**: Based on time to find: <15s = perfect, 15-30s = great, 30-45s = good, 45-60s = found.

**Cooperative**: Claude can suggest directions via `pushling_speak` ("try left!").

**Depends on**: P6-T3-04 (game framework), P6-T1-02 (swipe input)

---

### P6-T3-08: Rhythm Tap Mini-Game

**What**: Notes scroll toward the creature; tap on beat.

**Gameplay**:
- Musical notes (Gilt-colored note symbols) scroll from right to left across the Touch Bar
- A "hit zone" is marked at the creature's position (3pt wide vertical band, Gilt outline at 30% opacity)
- Notes arrive in rhythm patterns (pre-designed 4-8 note phrases)
- Tempo: 120 BPM (0.5s per beat)

**Input**: Tap when a note enters the hit zone.
- Perfect timing (< 50ms from center): "PERFECT" flash, +3 points
- Good timing (50-100ms): "GOOD" flash, +2 points
- OK timing (100-200ms): "OK" flash, +1 point
- Miss (> 200ms or no tap): note passes through, creature winces, 0 points

**Note patterns** (pre-designed, not random):
- 5 difficulty levels, each with 3 patterns
- Patterns last 8-16 beats (4-8 seconds each)
- Full game plays 4-6 patterns = 30-45 seconds

**Visual**: Notes leave a brief trail as they scroll. Hit notes explode into musical note particles. The Touch Bar "piano" effect -- the entire strip becomes a musical instrument.

**Cooperative**: Notes appear from BOTH directions -- human taps left-side notes, Claude taps right-side notes via MCP.

**Depends on**: P6-T3-04 (game framework), P6-T1-02 (tap input)

---

### P6-T3-09: Tug of War Mini-Game

**What**: Human vs Claude, creature in the middle.

**Gameplay**:
- Creature stands at center of Touch Bar (X=542)
- A rope visual extends left and right from creature
- Human's goal: pull creature to the left edge (X < 100)
- Claude's goal: pull creature to the right edge (X > 985)

**Input**:
- Human: rapid taps anywhere. Each tap = 5pt of pull force to the left
- Claude: rapid MCP calls to `pushling_perform({game: "tug"})`. Each call = 5pt pull to the right
- Net force determines creature's movement per frame

**Creature bias**: The creature subtly cheats in the human's favor (55/45 lean). Every 10 human taps, the creature "digs in" for a bonus 15pt leftward pull. This makes the human feel the creature is on their side.

**Visual**:
- Rope rendered as a thin Bone-colored line at creature's center Y
- Rope stretches/compresses based on pull direction
- Creature leans in the direction it's being pulled
- Dust particles at creature's paws (digging in)
- When near an edge: rope glows Ember (tension)

**Duration**: 30 seconds or until one side reaches their edge.

**Scoring**: Binary -- win or lose. Winner gets +15 satisfaction, +5 XP. Loser gets +5 satisfaction (it was fun). If Claude wins: creature looks sheepish. If human wins: creature celebrates.

**Solo mode** (no Claude connected): AI opponent simulated by daemon. Difficulty scales with total games played (starts easy, gets harder).

**Depends on**: P6-T3-04 (game framework), P6-T1-02 (rapid tap input), Phase 4 MCP integration (for Claude's pulls)

---

### P6-T3-10: Mini-Game Result Screen

**What**: Post-game display showing score, personal best, and rewards.

**Layout** (occupies full Touch Bar width for 3 seconds):
```
 [Game Name]  Score: 42  ★ BEST!  +8 XP  +15 ♡
```

- Left: Game name in Bone, 6pt
- Center: Score in Gilt, 8pt (large, prominent)
- "BEST!" indicator if new personal best (flashing Gilt, star particles)
- Right: XP awarded and satisfaction boost
- Background: subtle gradient darkening for readability
- Creature reaction: proud expression if score > 50%, embarrassed if < 30%, neutral otherwise

**Personal best celebration**: If new best, brief firework burst (10 Gilt particles) and creature does a victory pose (paws up, chest out).

**Dismiss**: Auto-dismiss after 3 seconds, or any tap dismisses immediately.

**Transition back**: After result screen, behavior stack resumes from Autonomous layer. Brief 0.3s settling animation as creature returns to idle.

**Depends on**: P6-T3-04 (game framework provides GameResult)

---

### P6-T3-11: Game Unlock Progression

**What**: Mini-games unlock progressively through play count.

**Unlock table**:
| Game | Unlock Condition | How Discovered |
|------|-----------------|----------------|
| Catch | Free (always available) | Creature drops a star during idle, looks expectant |
| Memory | Complete 1 game of Catch | Creature shows symbols in sequence during idle |
| Treasure Hunt | Complete 3 total mini-games | Creature starts digging during idle, looks at human |
| Rhythm Tap | Complete 5 total mini-games | Musical notes float past creature during idle |
| Tug of War | Complete 8 total mini-games AND Claude is connected | Claude initiates via MCP; creature pulls toward human |

**Discovery mechanic**: Before a game is unlocked, the creature hints at it during idle with a brief invitation-style behavior. The human doesn't know what it is yet -- it's a mystery until unlocked.

**Storage**: SQLite `game_unlocks` table:
| Column | Type |
|--------|------|
| game_type | TEXT PK |
| unlocked | BOOLEAN |
| total_plays | INTEGER |
| first_played | DATETIME |

**Depends on**: P6-T3-04 (game framework), P6-T3-01 (invitation system for discovery)

---

## Track 4: Advanced Gestures & Display Modes (P6-T4)

**Owner**: `swift-input`, `swift-scene`
**Directory**: `Pushling/Input/`, `Pushling/Scene/`
**Estimated Tasks**: 5

### P6-T4-01: Display Mode Cycling (3-Finger Swipe)

**What**: 3-finger swipe left/right cycles through 4 display modes, as specified in the vision doc's touch interaction table.

**Modes**:
| Mode | Content | Visual |
|------|---------|--------|
| **Normal** (default) | Living world, creature, weather, no HUD | Standard scene |
| **Stats** | Stat overlay: stage, XP, streak, satisfaction, curiosity, contentment, energy, mutation badges, touch count | Ash-tinted overlay panel at bottom, creature dimmed to 60% |
| **Journal** | Last 10 journal entries scrolling, brief summaries, timestamps | Scrolling text list, Bone on Void, creature walks in background |
| **Constellation** | Each milestone/achievement is a star in a procedural constellation map. Connected by Ash lines. | Full-screen star map, creature at center |

**Implementation**:
- 3-finger swipe detected by gesture recognizer (P6-T1-02)
- `DisplayModeController` manages transitions between modes
- Each mode has its own SKNode overlay that fades in/out (0.3s crossfade)
- Swipe left = next mode, swipe right = previous mode
- Any single tap returns to Normal mode
- World continues rendering behind overlays (dimmed, not paused)
- Each mode reads from SQLite (journal, milestones, creature state)

**Depends on**: P6-T1-02 (multi-finger gesture), Phase 1 state system

---

### P6-T4-02: Memory Postcards (4-Finger Swipe)

**What**: 4-finger swipe cycles through key memories as first-person postcards, as specified in the vision doc.

**Specs**:
- Each "postcard" is a snapshot view of a key life moment, told from the creature's perspective
- Source: milestone journal entries (evolve, first_word, first_mutation, achievements)
- Visual: full Touch Bar taken over by a styled card — background gradient, short first-person text, optional small icon
- Text examples:
  - "I opened my eyes for the first time. Everything was dark and warm."
  - "I said my name. '...Zepus?' I wasn't sure it was mine yet."
  - "The first storm. I hid under a mushroom and shivered."
- 4-finger swipe left/right cycles between postcards (oldest to newest)
- Single tap exits back to Normal mode
- Maximum 50 postcards stored (oldest archived beyond that)

**Implementation**:
- `PostcardController` generates postcards from filtered journal entries
- Each postcard: `SKNode` with gradient background + `SKLabelNode` text (wrapped)
- First-person narrative templates per journal entry type
- Transitions: horizontal slide (like Photos app carousel)
- Postcards are generated lazily (on swipe, not pre-computed)

**Depends on**: P6-T1-02 (4-finger gesture), Phase 1 state system, Phase 8 T2-06 (postcard content generation)

---

### P6-T4-03: Konami Code Easter Egg (#58)

**What**: A specific touch sequence unlocks surprise #58 — the Konami Code victory lap.

**Sequence**: Up, Up, Down, Down, Left, Right, Left, Right, Tap, Tap (interpreted as touch gestures on the Touch Bar).

**Touch Bar mapping**:
- Up = swipe from bottom to top of Touch Bar (Y-direction swipe)
- Down = swipe from top to bottom
- Left = swipe from right to left
- Right = swipe from left to right
- Tap = single tap on creature

**Detection**:
- `KonamiDetector` tracks the last 10 gesture inputs in a sliding window
- Each qualifying gesture must occur within 1.5 seconds of the previous
- On match: trigger surprise #58 — victory lap with 8-bit fanfare
- Sound: brief 8-bit triumphant melody via `afplay`
- Visual: creature does a lap of the full Touch Bar with rainbow particle trail, retro-pixel flash effect
- Achievement: logged in journal, counts as an easter egg surprise

**Depends on**: P6-T1-02 (gesture recognition), Phase 8 surprise system (for scheduling credit)

---

### P6-T4-04: Co-Presence Animation

**What**: When human touches the creature AND Claude issues an MCP command within 100ms of each other, a special co-presence animation plays.

**Specs** (from vision doc):
- Detection: daemon tracks `lastTouchTime` and `lastIPCCommandTime`. If `|lastTouchTime - lastIPCCommandTime| < 100ms`, trigger co-presence.
- Visual: diamond (Claude indicator) brightens to full Gilt, creature body gains a brief full-body glow (Gilt at 30% opacity, 0.5s), extra-large heart particle (2x normal size) floats up
- Duration: 1.5s total
- Rarity: naturally rare — requires genuine coincidence, making it special
- `co_presence` event appears in `pending_events` so Claude knows it happened
- Journal entry: `{ "type": "co_presence", "timestamp": "..." }`

**Depends on**: P6-T1-01 (touch tracking), Phase 4 (IPC timing), Phase 4 (diamond indicator)

---

### P6-T4-05: Automatic Campfire Spawn

**What**: In the evening, a campfire may spawn near the creature, creating a gathering point for nighttime behavior.

**Specs** (from vision doc Core Loop — Evening section):
- Trigger: time period transitions to "evening" or "late_night" AND no campfire object already exists AND creature is at Beast+ stage
- Probability: 40% chance per evening transition
- The campfire is a temporary world object (not persistent — disappears at dawn)
- Campfire visual: Ember glow, tiny flame particle emitter, warm light radius (Gilt at alpha 0.08, 20pt radius)
- Creature behavior: gravitates toward campfire, sits near it, watches flames (using `watching` interaction template)
- If Claude is connected: campfire enables "campfire stories" surprise variant (creature stares at fire, thought bubbles with memories)
- Campfire removed at dawn (fades out over 30s)

**Implementation**:
- `CampfireSpawner` checks time period transitions
- Uses the object system (P7-T2) preset for campfire, but marks it as `source: "system"` and `temporary: true`
- Does not count against the 12-object persistent cap (it's temporary)

**Depends on**: Phase 3 (sky time periods), Phase 7 (object system for campfire rendering)

---

## QA Gate

### Track 1 (Continuous Touch) Verification

- [ ] Touch tracking operates at 60Hz with sub-pixel precision (verify with position logging)
- [ ] All gesture types recognized correctly: tap, double-tap, triple-tap, long press, sustained touch, drag, flick, multi-finger
- [ ] Gesture priority resolution works (double-tap wins over two taps, etc.)
- [ ] Laser pointer Ember dot tracks finger at 60Hz with no visible lag
- [ ] Creature stalks at slow drag speed, chases at fast drag speed, pounces when dot stops
- [ ] Petting stroke produces fur ripple in drag direction at correct speed threshold
- [ ] 3 petting strokes trigger slow-blink and lie-down
- [ ] Against-grain petting produces correct rejection response (personality-dependent)
- [ ] Object flick applies physics impulse in correct direction with correct mass response
- [ ] Ball rolls and bounces, feather floats, rock thuds (verify each object type)
- [ ] Creature chases flicked objects (personality-dependent response on arrival)
- [ ] Object pick-up follows finger with slight lag, drops on release, creature investigates new position
- [ ] Hand-feeding commits works: touch stops drift, drag to creature, +10% XP bonus
- [ ] Rapid tap pounce game: 3+ taps trigger hunt, catch mechanic timing window works
- [ ] Wake-up boop: 3-tap progressive wake sequence, 5s timeout between taps
- [ ] Tap-on-object: object bounces, creature trots over to investigate
- [ ] Belly rub: 70% normal / 30% trap ratio (test over 20 attempts), personality-influenced
- [ ] Touch milestone counter increments correctly for all gesture types
- [ ] No touch input lag (gesture recognition < 10ms from touch event to handler)

### Track 2 (Human Progression) Verification

- [ ] Touch counter persists across app restarts
- [ ] Milestones unlock at exactly the correct thresholds (25, 50, 100, 250, 500, 1000)
- [ ] Gestures are gated before unlock (laser pointer doesn't work at 99 touches)
- [ ] Unlock ceremony plays with banner, demo, and journal entry
- [ ] Finger trail appears at 25 touches (sparkle follows drag)
- [ ] Pre-contact purr activates at 500 touches (creature responds to nearby finger)
- [ ] Touch mastery at 1000 touches enhances all particle effects (visible difference)
- [ ] Pet streak tracks correctly across days (streak increments at midnight)
- [ ] 7-day streak triggers daily gift behavior (creature brings item once per day)
- [ ] "Paying attention" rewards fire when tapping during correct autonomous behaviors
- [ ] Paying attention only counts once per behavior instance (no spam)

### Track 3 (Invitations & Mini-Games) Verification

- [ ] Invitations appear 1-2 per hour during active use (verify over 3-hour session)
- [ ] Minimum 20 minutes between invitations
- [ ] Drought timer doubles probability after 40 minutes without invitation
- [ ] All 6 invitation types trigger correctly with correct creature animations
- [ ] Ignored invitations self-resolve after 10 seconds without breaking creature state
- [ ] Accepted invitations produce correct interaction sequences and rewards
- [ ] Catch mini-game: stars fall, tap moves creature, catching works, cooperative COMBO works
- [ ] Memory mini-game: sequence displays correctly, gesture input maps to symbols, difficulty increases
- [ ] Treasure Hunt: hot/cold hints accurate, swipe explores, treasure found correctly
- [ ] Rhythm Tap: notes scroll at correct tempo, timing windows produce correct score tier
- [ ] Tug of War: tap frequency maps to pull force, creature biases toward human (55/45), solo mode works
- [ ] All 5 mini-games produce result screen with score, personal best tracking, XP award
- [ ] Game unlock progression: Catch free, others unlock at correct play counts
- [ ] No mini-game allows creature to enter a broken state (behavior stack resumes cleanly after every game)
- [ ] Touch always interrupts AI-directed behavior correctly (reflex priority maintained during games)

### Integration Verification

- [ ] Touch interactions and Phase 5 speech work simultaneously (tap creature -> heart AND speech reaction)
- [ ] Touch during commit eating works (hand-feeding interrupts autonomous drift)
- [ ] Mini-games and weather render simultaneously without frame drops
- [ ] MCP `pushling_sense("developer")` reports touch stats correctly
- [ ] Claude-initiated mini-games via MCP work (Tug of War cooperative mode)
- [ ] Co-presence events fire when human touch and Claude action coincide within 100ms
- [ ] Total system (touch + speech + eating + weather + world) stays within 16.6ms frame budget
- [ ] All touch interactions persist state correctly across daemon restarts
