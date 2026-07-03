---
type: Reference
title: Gesture-to-Response Map
description: Every GestureType x GestureTarget pairing and what it actually triggers in CreatureTouchHandler and its subsystems, verified against code.
status: Live
tags: [touch, reference, gestures]
timestamp: 2026-07-02T00:00:00Z
---

The authoritative table of what each recognized gesture does, by target.
For how a raw touch becomes a `GestureEvent` in the first place, see
[the touch input pipeline](/SYSTEMS/touch-input-pipeline.md). For which
rows require an unlocked milestone before they activate, see
[touch milestones](/SYSTEMS/touch-milestones.md). All routing here lives
in `Input/CreatureTouchHandler.swift`'s `gestureRecognizer(_:didRecognize:)`
switch and the private `handle*` methods it dispatches to.

# Dispatch Order (every gesture, before target routing)

Before any per-type handler runs, every incoming `GestureEvent` is first
recorded for milestone/streak/invitation bookkeeping
(`milestoneTracker.recordGesture`, `petStreak.recordInteraction`,
`invitationSystem.recordActivity`), and checked for a pending daily gift.
If a mini-game is active (`miniGameManager.isGameActive`), only `.tap`
events are forwarded to the game's own input handler and **all other
gesture types are dropped** for the duration — see
[mini-games](/SYSTEMS/mini-games.md#input-takeover). If a cinematic
sequence is active, every gesture is dropped except a world `.tripleTap`,
which is treated as an escape hatch that cancels the cinematic.

# Tap

| Target | Response |
|---|---|
| Creature (sleeping) | Routed to the wake-up boop sequence instead of a normal tap, but only if the tap lands in the nose-area sub-region (top-center 60%-wide x 50%-tall of the hitbox — `WakeUpBoop.isNoseArea`). A tap elsewhere on a sleeping creature's hitbox is **not currently handled specially** — it falls through to the normal tap-cycle logic below with no explicit sleep check, which is a gap: the vision/plan describe *any* tap on a sleeping creature routing to wake-up, but the code only special-cases the nose region. |
| Creature (pounce catch-window open) | Routed to `PounceGame.attemptCatch` — a catch if within 20pt of the pounce landing X. |
| Creature (invitation offered) | Accepts the active invitation (`InvitationSystem.acceptInvitation()`) instead of the normal tap cycle. |
| Creature (normal) | Cycles through an in-memory 4-response rotation — `["purr", "chin_tilt", "headbutt", "slow_blink"]` — advancing the index each tap. **However, the rotation only affects an `NSLog` line and the milestone/particle side effects; the actual creature reflex triggered is always `"ear_perk"` regardless of which rotation entry was selected.** `"purr"` and `"chin_tilt"` are not registered reflex or behavior names anywhere in `Behavior/ReflexLayer.swift`, `BehaviorSelector.swift`, or `BehaviorChoreography.swift` (grep-verified) — only `"headbutt"` and `"slow_blink"` exist as real autonomous-behavior/choreography names, and `"ear_perk"`/`"look_at_touch"` are the only two defined reflexes. A heart particle emits and contentment +3 regardless of rotation position. |
| Object | `ObjectInteraction.tapObject` — 0.2s scale-bounce (1.0 -> 1.15 -> 1.0), 2-3 Gilt sparkle particles, 30s per-object cooldown before it can be "called to attention" again. Object-side only: the event this fires (`.tapped`) has no listener anywhere in the codebase, so the design's creature-side response (ears perk, head turn, trot over, personality-dependent investigation) never happens — see [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md#basic-gesture-responses--creature-side-gaps). |
| World (empty space) | `PushlingScene.handleTouch(at:)` — shows the HUD overlay via `HUDOverlay.handleTap`. Note: this only fires from the tap path (a clean, short touch); it does not fire from a drag, per the recent fix that stopped the HUD from appearing mid-drag. Tapping near (not on) the creature does **not** make it walk to the touch point — that "walk-to-point" design exists only inside `CatchGame.handleTap` as mini-game input, never generalized to ordinary world taps; see [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md#basic-gesture-responses--creature-side-gaps). |
| Commit text | No-op in `CreatureTouchHandler` (the `.commitText` case in `handleTap`'s switch is an empty `break`) — commit-text grabbing for hand-feeding is a separate entry point (`HandFeeding.tryGrab`), not routed through the tap gesture at all. |

## Wake-Up Boop — The 3-Tap Sequence

Fully implemented (`Input/WakeUpBoop.swift`), matching the design almost
exactly — each nose-area tap on a sleeping creature advances a 3-step
sequence, with a 5-second timeout between taps:

| Tap | Event | Duration | Response |
|---|---|---|---|
| 1st | `.firstBoop` | 0.8s | nose twitches, one eye opens halfway, ear flicks — then resettles |
| 2nd | `.secondBoop` | 1.5s | both eyes open partway, full body stretch, yawns, eyes close again |
| 3rd | `.thirdBoop` | 2.0s | big yawn, eyes fully open, stands up, stretches, shakes head — awake |

If more than 5 seconds (`maxTimeBetweenTaps`) pass between taps, the
sequence resets (`.resettle`) and the creature fully re-settles to sleep —
the human has to commit to the whole wake-up, not just poke once and walk
away. On the 3rd tap, `.awake(contentmentBoost: 10.0, minimumEnergy: 30.0)`
fires: +10 contentment, and energy is floored at 30 regardless of how low
it was pre-wake (a natural, non-boop wake preserves whatever energy the
creature had). This is the only manual wake path in the code — there is no
"slam awake" shortcut.

# Double-Tap

Only meaningful on the creature — `guard case .creature = event.target else { return }`. Triggers `BehaviorStack.startJump(initialVelocity: 80)` and +5 satisfaction. Double-tap on any other target is silently ignored (no world/object handling, unlike the design docs' "3x = bounce combo with flip" — no combo-counting code exists for double-tap; the only repeated-tap combo logic is the *tap*-rotation and the separate `rapidTaps` pounce game).

# Triple-Tap

| Target | Response |
|---|---|
| Creature | Stage-specific secret, logged only (no visible animation code beyond the `NSLog`): `egg` -> `"pulse"`, `drop` -> `"belly_expose"`, `critter` -> `"zoomies"`, `beast` -> `"map_reveal"`, `sage` -> `"prophecy"`, `apex` -> `"reality_glitch"`. |
| World | `cameraController?.recenter()` — see [camera control](/SYSTEMS/camera-and-parallax.md#design-canon-pan-zoom) (currently a no-op in the shipped fixed-viewport build, since `recenter()` itself isn't gated, but the pan/zoom it resets are pinned to 0/1.0 anyway). |
| Object, commit text | No-op. |

# Long Press

| Target | Response |
|---|---|
| Creature | `look_at_touch` reflex (thought bubble). |
| Object | `ObjectInteraction.pickUp` — object floats 2pt, scales to 1.05, gains a drop-shadow node; subsequent drags call `moveHeld` (0.85 lerp toward the finger, "weighted" feel); releasing calls `dropHeld` (clamped to X 10-1075, small bounce, shadow fades). |
| World | No-op — a long-press on empty space does nothing (the horizontal-context-menu design at [Touch Bar menu patterns](/RESEARCH/touch-bar-menu-patterns.md) would have used this target; it was never built). |

# Sustained Touch (held > 2s)

Only meaningful on the creature: +8 contentment ("chin scratch"), logged. No petting-stroke-style particle/ripple effects fire from sustained touch specifically — those belong to the drag-based `pettingStroke` gesture below.

# Drag / Slow Drag

Routing precedence in `handleDrag` (checked in this order):

1. **An object is being held** (`objectInteraction.isHolding`) — the drag moves the held object; nothing else runs.
2. **A commit is being hand-fed** (`handFeeding.isHolding`) — the drag moves the held commit text.
3. **Target is world** — pans the camera (`cameraController?.pan(deltaX:)`, dead in the current fixed-viewport build — see [camera control](/SYSTEMS/camera-and-parallax.md#current-shipped-state-fixed-viewport)) and, if the `finger_trail` milestone is unlocked, emits a finger-trail sparkle regardless of the camera pan outcome.
4. **`laser_pointer` milestone unlocked** — activates/updates laser pointer mode (`LaserPointerMode`) at the drag position, tracked at 60Hz with no interpolation lag. **Designed** creature behavior by drag speed: stopped (< 1pt/s) -> stare, then pounce after 0.5s stationary (`pounceDelay`); < 50pt/s -> stalk; 50-150pt/s -> trot; > 150pt/s -> chase (creature capped at 100pt/s max chase speed). `LaserPointerMode.updatePosition` does correctly classify speed into these six `LaserCreatureBehavior` cases and fires `onCreatureBehavior?(...)` for each — **but `onCreatureBehavior` has zero assignments anywhere in the codebase** (grep-verified), the same "declared event, zero listeners" pattern as the Object-tap and Flick chase gaps elsewhere in this doc. The creature does not actually stalk, trot, chase, stare, or pounce during laser play today — only the dot itself (visual + trail below) is live.
5. **`finger_trail` milestone unlocked** (fallback, no laser yet) — emits the finger-trail sparkle alone.

**Laser pointer — dot visual & pounce/end detail** (fully implemented,
matching the source design almost exactly): the dot is a 3pt-radius Ember
`SKShapeNode` with a 5pt inner glow at 50% opacity, plus a 4-node comet
trail at opacities 0.6/0.4/0.2/0.1, each trailing one position-history
frame behind the last. **Pounce escape**: once the dot has been stationary
> 0.5s (`pounceDelay`) the creature pounces once (`hasPounced` guards
against re-pouncing); `dotEscapePounce()` — called if the finger is still
down after the pounce — jumps the dot 30pt in a random left/right
direction (clamped to the 10-1075 play area) with a 0.1s ease-out move,
resetting the pounce guard so it can be triggered again. **End behavior**:
`deactivate()` fades the dot, glow, and all 4 trail nodes over 0.3s
(`fadeOutDuration`) and fires `.sniffEnd(targetX:)` so the creature sniffs
the last known position — matching the source's "sniffs the last
position, looks around confused" design exactly (as an `onCreatureBehavior`
event, which — per the dead-callback finding above — currently reaches no
listener; the sniff never visibly happens).

The source design's satisfaction payoff — "**+5** if the finger has
lifted when the pounce lands on the last position, dot doesn't escape" —
is design intent only: `dotEscapePounce()` vs. a lifted-finger pounce are
never distinguished by any satisfaction call anywhere in
`LaserPointerMode.swift` or its caller (`onSatisfactionChange` is fired
exactly once in the whole touch-handling path, from double-tap's jump —
see Double-Tap above). No code currently rewards a "clean" finger-lifted
pounce at all.

**Petting stroke** is a distinct `GestureType` (`pettingStroke`), not a
sub-case of drag — it's classified upstream in `GestureRecognizer` when a
slow drag's cumulative distance crosses 15pt *inside* the padded creature
hitbox, and only when `MilestoneID.petting` is already unlocked (the
recognizer itself checks the milestone before emitting the type; if not
yet unlocked, the same physical drag is classified as an ordinary
`slowDrag` targeting `.creature` instead — for which `handleDrag`'s
world-only branches don't apply, so an un-milestoned petting-shaped drag
on the creature currently produces no camera pan, no trail, and no
petting effect: a silent no-op).

# Petting Stroke

Once unlocked (`petting` milestone, 50 touches): `PettingStroke` tracks
cumulative travel and direction. A completed stroke (>= 15pt travel,
`minTravelForStroke`) increments `strokeCount`; 3 strokes within a 5s
succession window (`strokeSuccessionWindow`) fire `.slowBlink` +
`.lieDown` + doubled purr-particle rate. Direction matters: strokes
against the creature's facing ("against the grain") increment a separate
counter; once that exceeds a personality-dependent cap (1 stroke for
low-energy creatures, 3 for high-energy — `personalityEnergy > 0.6`), the
stroke fires a `.rejection` event instead of counting toward the
slow-blink streak. Purr particles emit at 8/s (doubled to 16/s after the
slow-blink threshold). Before the `petting` milestone unlocks, a
petting-shaped gesture on the creature only fires the `look_at_touch`
reflex (basic head-turn acknowledgment) — see
[touch milestones](/SYSTEMS/touch-milestones.md).

**Fur-ripple visual** (built): a 4pt-wide, 20pt-tall Bone highlight band
(`rippleWidth`, alpha 0.3) tracks the finger position for the duration of
the stroke and fades out over 0.15s on release. The design's "ripple
travels at 1.5x drag speed from entry to exit" nuance is a declared
constant (`rippleSpeedFactor = 1.5`) that is **never read anywhere in the
class** (grep-verified) — the ripple node is just pinned directly to the
current finger position every frame, with no independent travel speed of
its own. A second declared-but-unused constant, `bodyOffsetAmount = 1.0`,
was meant to drive the "creature leans 1pt into the stroke" body reaction
below.

**Not built**: body lean toward the stroke, eye half-close, and ear tilt
toward the stroke direction — none of these three body reactions exist
anywhere in `PettingStroke` or its caller. More significantly, of the six
`PettingEvent` cases `PettingStroke` fires, `CreatureTouchHandler`'s
`setupPettingCallback()` consumes **only** `.strokeComplete` (a heart-burst
particle on every completed stroke) — `.slowBlink`, `.lieDown`,
`.againstGrain`, `.rejection`, and `.purrIntensify` are all fired into a
callback that ignores them (grep-verified: the closure's body is a single
`if case .strokeComplete` check, nothing else). The 3-stroke slow-blink
trust moment and the against-grain rejection are real internal state
machine transitions, but neither currently produces any creature-visible
effect beyond the purr-rate doubling that `PettingStroke` applies to its
own particles directly (not via the event).

**Contentment reward — design intent only, not shipped.** The source
design attaches a **+15 contentment spike** to the 3-stroke slow-blink
trust moment specifically, on top of the slow-blink animation, lie-down,
and doubled purr rate — and frames head-to-tail (with-the-grain) stroking
as the max-contentment path, with against-grain strokes tolerated once
(high-energy) or not at all (low-energy) before a rejection. In the
shipped code, `PettingStroke` never computes or emits a contentment value
at all — `strokeComplete`/`slowBlink`/`lieDown` carry no numeric payload,
and `CreatureTouchHandler`'s petting callback (above) doesn't call
`onContentmentChange` from any petting event. Petting today grants **zero**
contentment through this path, regardless of stroke count or direction;
the only contentment gain anywhere in touch handling that resembles
petting is the flat +8 "chin scratch" from plain sustained touch (see
Sustained Touch above), which fires independent of stroke counting.

# Flick

Only meaningful on a world object (`guard case .object(let id) = event.target`).
`ObjectInteraction.flickObject` computes an impulse
(`impulseVelocity.dx = velocity.dx * mass`, `impulseVelocity.dy = |velocity.dx| * 0.3` for an upward arc), then lets it fly under shared gravity
(60pt/s², `friction` 0.95/frame velocity decay, `edgeBounce` 0.3 restitution
at the 10-1075pt play bounds) until it settles or times out at 3s
(`ObjectInteraction.update`). Per-object-type mass and bounce behavior:

| Object Type | Mass Factor | Ground Restitution | Flight Behavior |
|---|---|---|---|
| Ball | 0.8 | 0.7 | rolls and bounces |
| Yarn ball | 0.6 | 0.5 | rolls and bounces; **no unraveling particle trail is emitted** (`emitLaunchParticles`-equivalent only fires for `flower`/`star_fragment` — grep-verified) |
| Feather | 0.2 | 0.1 | sine-wave horizontal drift (`sin(timeInFlight * 3) * 0.5`pt/frame) plus a descent floor clamped to -20pt/s ("floats," doesn't plummet) |
| Rock | 1.5 | 0.2 | heavy landing; **the source's 0.5pt screen-shake on impact is a dead stub** — the code checks `if objectType == "rock" && abs(velocity.dy) > 5` but the branch body is just the comment `// Shake handled by scene`, with no call anywhere |
| Flower | 0.3 | 0.15 | 5 Ember petal particles scatter outward on launch (0.5s, fading) |
| Star fragment | 0.4 | 0.3 (default) | 4 Gilt sparkle-trail particles emitted on launch (0.4s, fading) |

**Creature chase response — entirely unwired.** `flickObject` also fires
`onObjectEvent?(.creatureChase(objectId:targetX:))` on every flick, but
`ObjectInteraction.onObjectEvent` has no listener anywhere in the codebase
(same root cause as the Object-tap gap above) — the personality-dependent
chase/bat/examine/fetch response never runs. Full designed behavior at
[interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md#basic-gesture-responses--creature-side-gaps).

# Rapid Taps

Triggers `PounceGame.triggerHunt` if the taps land within 50pt of the
creature's X (`creatureProximity`): a dust puff per tap, a 0.3s beat
(`crouchDelay`), then a pounce at the last tap position, followed by a
0.3s catch window (`catchWindow`) during which a tap within 20pt of the
landing spot is a catch (20 Gilt sparkles, +5 satisfaction —
`satisfactionReward`). The design's `"got it!"` speech line at Beast+ on a
catch has no corresponding code (grep for `"got it"`: zero hits) — the
catch is visual-only today.

# Two-Finger (dispatched on lift)

Only meaningful on the creature, and only once `bellyRub` (250 touches)
is unlocked: `handleBellyRub()` rolls a trap chance —
**20% for high-energy creatures (`personalityEnergy > 0.6`), 40%
otherwise** (a 70/30-average split across the personality spectrum, not a
fixed 70/30 for every creature as the vision doc's "30% trap chance"
implies). On the non-trap outcome, +15 contentment. On trap, no
contentment boost. A two-finger gesture targeting the world or an object
is a no-op — the "2-finger swipe pans the world" behavior from
`PUSHLING_VISION.md`'s Touch Interactions table is not implemented this
way; see [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md).
(At Sage+, the source design layers a temporal-vision variant onto the
same swipe — see [interactivity — unbuilt
features](/FEATURES/interactivity-unbuilt.md#live-pan--zoom).)

`handleBellyRub()` itself is pure logic — a random roll plus an `NSLog`
line and the one contentment call above. None of the design's animation
flavor exists: no roll-onto-back sequence, no paws-in-the-air pose, no
4-kick trap animation, and no `"got you"` mischief speech line on a trap
outcome (grep for `"got you"` across the codebase: zero hits) — the trap
outcome today is invisible to the human beyond the *absence* of the
contentment gain.

# Three-Finger

`handleThreeFinger` is an empty method body (`// Display mode cycling
(handled by scene)`) — no display-mode controller exists anywhere in
`Scene/`. See [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md).

# Hand-Feeding (not a gesture type — a parallel touch-start path)

Distinct from the `GestureRecognizer` pipeline: a touch on a drifting
commit-text node is grabbed via `HandFeeding.tryGrab` (checked separately
by the caller, not through `GestureTarget.commitText`), which cancels the
node's autonomous drift actions. Subsequent drags reposition it; on
release, if within 15pt of the creature's position (`eatDistance`) it
fires a `.fed(sha:)` event — declared to carry a +10% XP bonus
(`HandFeeding.xpBonusMultiplier = 1.1`) and +5 contentment
(`contentmentBoost`) — otherwise a `.released` event fires and the node
resumes its autonomous drift.

**The reward never actually applies.** `HandFeeding.onFeedingEvent` has
zero assignments anywhere in the codebase (grep-verified) — `.fed` and
`.released` are both fired into the void. The drag-and-drop mechanics
(grab, reposition, distance check) are fully live; the XP multiplier and
contentment boost the design attaches to a successful hand-feed are dead
constants, never read outside `HandFeeding.swift` itself. Neither the
"gentle from-the-hand eating animation" nor the `"+12 (+1 hand-fed)"`
XP-float display format described in `PHASE-6.md`'s P6-T1-07 has any
corresponding code (grep for `hand.fed`/`handFed` outside this file:
nothing).

# Citations

[1] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift`
[2] `Pushling/Sources/Pushling/Input/{PettingStroke,LaserPointerMode,ObjectInteraction,PounceGame,WakeUpBoop,HandFeeding}.swift`
[3] `Pushling/Sources/Pushling/Behavior/{ReflexLayer,BehaviorSelector,BehaviorChoreography}.swift` (reflex/behavior name registry — `purr`/`chin_tilt` absent)
[4] [touch input pipeline](/SYSTEMS/touch-input-pipeline.md), [touch milestones](/SYSTEMS/touch-milestones.md), [camera control](/SYSTEMS/camera-and-parallax.md), [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md)
[5] `docs/archive/plan/phase-6-interactivity/PHASE-6.md` — P6-T1-02b/03/04/05/07/08/09/10/11 (source design for the unbuilt/flavor gaps noted above)
