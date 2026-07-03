---
type: System
title: Touch Input Pipeline
description: How a finger on the Touch Bar becomes a classified GestureEvent — TouchTracker's 60Hz coordinate/velocity tracking, GestureRecognizer's 12-gesture state machine, and the AppKit recognizers that actually feed it.
status: Live
tags: [touch, input, gestures, touchbar]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **how raw touch reaches a classified gesture** —
coordinate conversion, per-touch state, and gesture-type disambiguation. It
does not own what a gesture *does* once classified — see
[the gesture-response map](/REFERENCE/gesture-response-map.md) for the
creature/camera routing — nor per-feature detail like milestone gating (see
[touch milestones](/SYSTEMS/touch-milestones.md)) or the mini-game input
takeover (see [mini-games](/SYSTEMS/mini-games.md)). Source: `Input/TouchTracker.swift`,
`Input/GestureRecognizer.swift`, `TouchBar/TouchBarView.swift`.

# Pipeline

```
TouchBarView (AppKit, NSView)
  NSClickGestureRecognizer  -> handleClick()
  NSPanGestureRecognizer    -> handlePan()   [ONE recognizer, one-finger]
        |
        v  touchBegan/Moved/Ended/Cancelled(id:normalizedPosition:currentTime:)
TouchTracker
  - normalizedPosition (0-1, 0-1) -> scene coords (1085 x 30)
  - per-touch TouchState: position, velocity (EMA), duration, totalDistance
  - hit-tests creature (+4pt padding) and world objects at touch-began
        |
        v  TouchEvent { phase, state, timestamp, activeTouchCount }
GestureRecognizer (state machine, TouchTrackerDelegate)
  - classifies into one of 12 GestureType cases
  - delayed-commit tap/double-tap/triple-tap disambiguation
        |
        v  GestureEvent { type, position, velocity, touchCount, duration, target }
GestureRecognizerDelegate (CreatureTouchHandler)
```

Only **two** `NSGestureRecognizer`s are actually wired in
`TouchBarView.wireGestureRecognizers()` (lines ~186-200): an
`NSClickGestureRecognizer` and a single one-finger `NSPanGestureRecognizer`.
Multi-touch (2 and 3 simultaneous fingers) is detected downstream, inside
`TouchTracker`'s active-touch dictionary and `GestureRecognizer`'s
`activeTouchCount` bookkeeping — there is no `NSMagnificationGestureRecognizer`
and no second, two-finger `NSPanGestureRecognizer` instantiated anywhere in
the Swift sources (grep-verified). A stale header comment at
`TouchBarView.swift:8` still describes a magnification recognizer for pinch
zoom and a two-finger pan recognizer; neither exists in code. See
[camera-and-parallax](/SYSTEMS/camera-and-parallax.md) for why — pan/zoom are
currently disabled at the `CameraController` level regardless.

# TouchTracker: Coordinate & State Tracking

`TouchTracker.scenePoint(from:)` converts a Touch Bar `normalizedPosition`
(0-1 on both axes) to scene points: `x = normalized.x * 1085`,
`y = normalized.y * 30` (`sceneWidth`/`sceneHeight` constants). Up to **3**
simultaneous touches are tracked (`maxTouches = 3`, the Touch Bar's hardware
limit) in a dictionary keyed by `ObjectIdentifier`. This conversion has no
zoom term because zoom is disabled — the zoom-compensated view-to-world
step a re-enabled camera would need is unbuilt design intent, not a
current gap in this conversion; see [interactivity — unbuilt
features](/FEATURES/interactivity-unbuilt.md#live-pan--zoom).

`TouchState` (per active touch): `startPosition`, `currentPosition`,
`previousPosition`, `startTime`, `duration`, `velocity` (`CGVector`,
EMA-smoothed), `totalDistance`, `isOnCreature`, `isOnObject`, `objectId`,
and a computed `speed` (vector magnitude).

**Hit-testing happens once, at touch-began**, not continuously: the
creature hitbox is inset by `-4pt` on each side (`insetBy(dx: -4, dy: -4)`)
for a generous target on the narrow strip, and a caller-supplied
`objectHitTest` closure resolves world-object hits. A touch's
`isOnCreature`/`isOnObject`/`objectId` are fixed for the touch's lifetime —
dragging a touch that began off the creature onto the creature does not
retroactively make it a creature touch.

**Velocity**: exponential moving average, `velocityAlpha = 0.4`, applied
per-axis each `touchMoved` call: `newV = alpha * instantV + (1-alpha) * oldV`.
The `TouchTracker.swift` header comment describes this as "EMA-smoothed
velocity (alpha=0.4, 4-frame window)" — the 4-frame framing is descriptive
shorthand for the EMA's effective smoothing horizon, not a literal
4-sample ring buffer; the actual implementation is a single-pole EMA with
no separate window buffer.

# GestureRecognizer: The 12 Gesture Types

`GestureType` (`Input/GestureRecognizer.swift:14-27`) has **exactly 12
cases** — no `pinchZoom`, no `twoFingerDrag`. An older reference doc
(`docs/archive/MULTITOUCH-CAMERA-REFERENCE.md`) describes 13 gesture types
including those two; that document predates or diverged from the shipped
recognizer. Code is canon here.

| Gesture | Threshold(s) | Constant(s) |
|---|---|---|
| `tap` | duration < 0.2s, distance < 5pt | `tapMaxDuration`, `tapMaxDistance` |
| `doubleTap` | 2nd tap within 0.3s of the pending tap, < 10pt spacing | `doubleTapWindow`, `doubleTapMaxSpacing` |
| `tripleTap` | 3rd tap within an additional 0.15s (`tripleTapWindow - doubleTapWindow`), same spacing | `tripleTapWindow` |
| `longPress` | held >= 0.5s, distance < 5pt (checked every frame) | `longPressMinDuration`, `longPressMaxDistance` |
| `sustainedTouch` | held >= 2.0s, distance < 8pt (checked every frame) | `sustainedMinDuration`, `sustainedMaxDistance` |
| `drag` | distance > 10pt, speed >= 100pt/s | `dragMinDistance`, `slowDragMaxSpeed` |
| `slowDrag` | distance > 10pt, speed < 100pt/s | same as above |
| `pettingStroke` | slow drag (< 100pt/s), inside the padded creature hitbox, > 15pt cumulative travel | `pettingMaxSpeed`, `pettingMinTravel` |
| `flick` | drag ending (touch lifts) with speed > 200pt/s | `flickMinSpeed` |
| `multiFingerTwo` | exactly 2 simultaneous touches, dispatched on **lift** (not on began) | — |
| `multiFingerThree` | 3 simultaneous touches, dispatched **immediately on began** | — |
| `rapidTaps` | 3+ taps within 1.0s, spread < 30pt | `rapidTapWindow`, `rapidTapMinCount`, `rapidTapMaxSpread` |

There is no separate numeric "priority" table evaluated per event — the
survey's source docs describe one (e.g. "multi-finger > flick > rapid-tap >
..."), but the actual code is a **procedural state machine**, not a
priority-ranked simultaneous-match resolver. The effective precedence
falls out of the order of checks:

1. **Touch began**: if 3+ fingers are down, `multiFingerThree` fires
   immediately and any pending tap is cancelled. If 2 fingers, the state
   just records `multiFingerCount = 2` and the target (captured once, at
   the moment the second finger touches down) and cancels any pending tap.
2. **Touch moved** (only when `multiFingerCount == 0`): once cumulative
   distance exceeds `dragMinDistance`, the touch is marked as dragging and
   every subsequent move re-classifies it as `pettingStroke` (if inside
   the creature hitbox and slow), else `slowDrag`, else `drag`.
3. **Touch ended**: multi-finger touches lifting to zero dispatch
   `multiFingerTwo` (only for the 2-finger case — 3-finger already fired on
   began). An active drag ending fast (`speed > flickMinSpeed`) becomes
   `flick`; otherwise the drag simply ends with no further event. A
   short/small touch becomes a tap candidate, routed through
   `handleTapCandidate` for delayed tap/double/triple/rapid disambiguation.
4. **Per-frame `update(currentTime:activeTouches:)`** (called from
   `GameCoordinator.swift:264`, once per frame): for any touch that is
   neither dragging nor multi-finger, checks `longPress` then
   `sustainedTouch` thresholds and fires each at most once per touch
   lifetime (`longPressFiredForTouch`/`sustainedFiredForTouch` guards).

**Tap disambiguation** is a two-stage delayed-commit timer, not a fixed
300ms wait as some source docs state: a first tap starts a
`doubleTapWindow` (0.3s) timer; if a second tap lands within
`doubleTapMaxSpacing` (10pt) before it fires, the timer resets to the
*remaining* `tripleTapWindow - doubleTapWindow` (0.15s) to allow a third
tap; a third tap within that window commits `tripleTap` immediately with
no further wait. `rapidTaps` (3+ taps in 1s within a 30pt spread) is
checked first on every tap-candidate and, if satisfied, pre-empts and
cancels the pending tap timer entirely.

# GestureTarget

```swift
enum GestureTarget {
    case creature
    case object(id: String)
    case world
    case commitText
}
```

Resolved once per touch (`targetFor(state:)`) from the `TouchState`'s
fixed `isOnCreature`/`isOnObject` flags captured at touch-began — never
re-evaluated mid-gesture. `.commitText` exists in the enum but
`GestureRecognizer.targetFor` never returns it (it only distinguishes
creature/object/world); commit-text hit-testing and the `.commitText`
target are populated elsewhere by the hand-feeding path (see
[hand-feeding in the gesture-response map](/REFERENCE/gesture-response-map.md)).

# Suppression & Wiring

`GestureRecognizer.isSuppressed` (set from `PushlingScene.swift:648`)
drops all incoming touch events without processing — used during
cinematic sequences. Milestone gating for gesture *availability* (e.g.
petting requires the `petting` milestone) is checked inside
`GestureRecognizer` itself via a weak `milestoneTracker` reference for
`pettingStroke`, and inside `CreatureTouchHandler` for laser pointer and
belly rub — see [touch milestones](/SYSTEMS/touch-milestones.md) for the
full gate table.

Wiring (`GameCoordinator.swift:674-685`): `touchTracker.delegate =
gestureRecognizer`, `gestureRecognizer.delegate = creatureTouchHandler`,
`gestureRecognizer.milestoneTracker = creatureTouchHandler.milestoneTracker`.

# Citations

[1] `Pushling/Sources/Pushling/Input/TouchTracker.swift`
[2] `Pushling/Sources/Pushling/Input/GestureRecognizer.swift`
[3] `Pushling/Sources/Pushling/TouchBar/TouchBarView.swift` (`wireGestureRecognizers`, header comment at line 8)
[4] `Pushling/Sources/Pushling/App/GameCoordinator.swift` (lines 264, 674-685)
[5] `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` (superseded reference — 13-gesture claim, deleted `GestureRecognizer+MultiTouch.swift` note)
