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
| Object | `ObjectInteraction.tapObject` — 0.2s scale-bounce (1.0 -> 1.15 -> 1.0), 2-3 Gilt sparkle particles, 30s per-object cooldown before it can be "called to attention" again. |
| World (empty space) | `PushlingScene.handleTouch(at:)` — shows the HUD overlay via `HUDOverlay.handleTap`. Note: this only fires from the tap path (a clean, short touch); it does not fire from a drag, per the recent fix that stopped the HUD from appearing mid-drag. |
| Commit text | No-op in `CreatureTouchHandler` (the `.commitText` case in `handleTap`'s switch is an empty `break`) — commit-text grabbing for hand-feeding is a separate entry point (`HandFeeding.tryGrab`), not routed through the tap gesture at all. |

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
4. **`laser_pointer` milestone unlocked** — activates/updates laser pointer mode (`LaserPointerMode`) at the drag position, tracked at 60Hz with no interpolation lag. Creature behavior by drag speed: stopped (< 1pt/s) -> stare, then pounce after 0.5s stationary (`pounceDelay`); < 50pt/s -> stalk; 50-150pt/s -> trot; > 150pt/s -> chase (creature capped at 100pt/s max chase speed).
5. **`finger_trail` milestone unlocked** (fallback, no laser yet) — emits the finger-trail sparkle alone.

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
cumulative travel and direction. A completed stroke (>= 15pt travel)
increments `strokeCount`; 3 strokes within a 5s succession window trigger
`slowBlink` + `lieDown` + doubled purr-particle rate. Direction matters:
strokes against the creature's facing ("against the grain") increment a
separate counter; once that exceeds a personality-dependent cap (1 stroke
for low-energy creatures, 3 for high-energy — `personalityEnergy > 0.6`),
the stroke fires a `.rejection` event instead of counting toward the
slow-blink streak. Purr particles emit at 8/s (doubled to 16/s after the
slow-blink threshold). Before the `petting` milestone unlocks, a
petting-shaped gesture on the creature only fires the `look_at_touch`
reflex (basic head-turn acknowledgment) — see
[touch milestones](/SYSTEMS/touch-milestones.md).

# Flick

Only meaningful on a world object (`guard case .object(let id) = event.target`).
`ObjectInteraction.flickObject` computes an impulse
(`impulseVelocity.dx = velocity.dx * mass`, `impulseVelocity.dy = |velocity.dx| * 0.3` for an upward arc) using a per-object-type mass factor (ball 0.8, yarn_ball 0.6, feather 0.2, rock 1.5, flower 0.3, star_fragment 0.4; unknown types default to 1.0) and lets it fly under simple gravity/friction/edge-bounce physics (`ObjectInteraction.update`) until it settles or times out at 3s.

# Rapid Taps

Triggers `PounceGame.triggerHunt` if the taps land within 50pt of the
creature's X (`creatureProximity`): a dust puff per tap, a 0.3s beat
(`crouchDelay`), then a pounce at the last tap position, followed by a
0.3s catch window (`catchWindow`) during which a tap within 20pt of the
landing spot is a catch (20 Gilt sparkles).

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

# Three-Finger

`handleThreeFinger` is an empty method body (`// Display mode cycling
(handled by scene)`) — no display-mode controller exists anywhere in
`Scene/`. See [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md).

# Hand-Feeding (not a gesture type — a parallel touch-start path)

Distinct from the `GestureRecognizer` pipeline: a touch on a drifting
commit-text node is grabbed via `HandFeeding.tryGrab` (checked separately
by the caller, not through `GestureTarget.commitText`), which cancels the
node's autonomous drift actions. Subsequent drags reposition it; on
release, if within 15pt of the creature's position it counts as fed
(+10% XP via `HandFeeding.xpBonusMultiplier`, +5 contentment via
`contentmentBoost`), otherwise the node is released to resume its
autonomous drift.

# Citations

[1] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift`
[2] `Pushling/Sources/Pushling/Input/{PettingStroke,LaserPointerMode,ObjectInteraction,PounceGame,WakeUpBoop,HandFeeding}.swift`
[3] `Pushling/Sources/Pushling/Behavior/{ReflexLayer,BehaviorSelector,BehaviorChoreography}.swift` (reflex/behavior name registry — `purr`/`chin_tilt` absent)
[4] [touch input pipeline](/SYSTEMS/touch-input-pipeline.md), [touch milestones](/SYSTEMS/touch-milestones.md), [camera control](/SYSTEMS/camera-and-parallax.md)
