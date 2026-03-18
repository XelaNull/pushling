# Multi-Touch & Camera Controls — Code Reference

> How touch input flows from finger-on-Touch-Bar to camera movement, creature interaction, and parallax rendering. Use this to compare expected behavior against what you actually see.

---

## Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  TouchBarView (NSView)                                              │
│  ├─ NSClickGestureRecognizer         → handleClick()                │
│  ├─ NSMagnificationGestureRecognizer → handleMagnification()        │
│  ├─ NSPanGestureRecognizer [2-finger]→ handleTwoFingerPan()         │
│  └─ NSPanGestureRecognizer [1-finger]→ handlePan()                  │
└───────────────────────────────┬─────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  TouchTracker                                                       │
│  • Normalizes coordinates (0–1 → 1085×30 scene space)               │
│  • Tracks per-touch state (position, velocity, duration, distance)  │
│  • EMA-smoothed velocity (alpha=0.4, 4-frame window)                │
│  • Hit-tests: creature hitbox (+4pt padding), world objects          │
└───────────────────────────────┬─────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  GestureRecognizer (state machine)                                  │
│  • Classifies touches into 13 gesture types                         │
│  • Tap disambiguation: 300ms delay for double/triple-tap            │
│  • Priority: multi-finger > flick > rapid-tap > triple > double     │
│              > tap > long-press > sustained > drag                  │
│  • Emits GestureEvent { type, position, velocity, target, ... }     │
└───────────────────────────────┬─────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│  CreatureTouchHandler (router)                                      │
│  • Routes gesture → creature interaction OR camera control          │
│  • Decision key: GestureTarget (.creature / .object / .world)       │
│  • Milestone-gated features (petting@50, laser@100, belly-rub@250)  │
│  • Mini-game mode suppresses non-tap gestures when active           │
└──────┬───────────────────────────────────┬──────────────────────────┘
       ▼                                   ▼
  Creature Systems                   CameraController
  (petting, jump, purr,             (pan, zoom, lock,
   laser, objects, etc.)             recenter, parallax)
```

---

## 1. Gesture Types (13 total)

### Taps
| Gesture | Condition | Delay |
|---------|-----------|-------|
| `tap` | Touch < 0.25s, moved < 8pt | 300ms (waits for double) |
| `doubleTap` | 2 taps < 0.5s apart, within 30pt | Commits on 2nd tap |
| `tripleTap` | 3 taps < 0.8s apart | Commits immediately on 3rd |
| `rapidTaps` | 3+ taps in 1s, within 30pt spread | Commits on count threshold |

### Holds
| Gesture | Condition | Checked |
|---------|-----------|---------|
| `longPress` | Held > 0.5s, moved < 5pt | Per-frame in `update()` |
| `sustainedTouch` | Held > 2.0s, moved < 8pt | Per-frame in `update()` |

### Drags
| Gesture | Condition |
|---------|-----------|
| `drag` | Moved > 10pt, speed > 100 pt/s |
| `slowDrag` | Moved > 10pt, speed < 100 pt/s |
| `pettingStroke` | Slow drag across creature hitbox, > 15pt travel |
| `flick` | Drag ending mid-motion at > 200 pt/s |

### Multi-Touch
| Gesture | Condition |
|---------|-----------|
| `multiFingerTwo` | 2 simultaneous touches |
| `multiFingerThree` | 3 simultaneous touches (dispatched immediately) |
| `pinchZoom` | Two-finger spread/contract (magnification gesture) |
| `twoFingerDrag` | Two-finger same-direction drag |

> **Hardware limit**: Touch Bar supports max 3 simultaneous touches.

---

## 2. Gesture Target Resolution

Every gesture gets a target based on where the touch began:

```swift
enum GestureTarget {
    case creature        // On creature hitbox (+4pt padding)
    case object(id: String)  // On world object
    case world           // Empty space
    case commitText      // On floating commit message
}
```

**This target determines whether the gesture goes to creature systems or camera control.**

---

## 3. Routing Rules (CreatureTouchHandler)

### Creature-Targeted Gestures
| Gesture | Action |
|---------|--------|
| `tap` on creature | Cycle responses (purr → chin tilt → headbutt → slow blink) + **lock camera to creature** |
| `doubleTap` on creature | Jump animation |
| `tripleTap` on creature | Easter egg (stage-specific) |
| `longPress` on creature | Thought bubble / examine |
| `sustainedTouch` on creature | Chin scratch |
| `multiFingerTwo` on creature | Belly rub (if milestone unlocked @ 250 touches; 70/30 contentment/trap split) |
| `pettingStroke` on creature | Petting system (if milestone unlocked @ 50 touches) |

### World-Targeted Gestures → Camera
| Gesture | Camera Action |
|---------|---------------|
| `drag` on world | `cameraController.pan(deltaX:)` + unlock camera if locked |
| `twoFingerDrag` on world | `cameraController.pan(deltaX:)` |
| `pinchZoom` | `cameraController.zoom(delta:, centerWorldX:)` |
| `tap` on world | Show HUD overlay + unlock camera if locked |
| `tripleTap` on world | `cameraController.recenter()` (animated reset) |
| `flick` on world | Object interaction (not camera) |
| `rapidTaps` on world | Pounce game trigger |

### Milestone-Gated Features
| Feature | Unlock At |
|---------|-----------|
| Finger trail | 25 touches |
| Petting stroke | 50 touches |
| Laser pointer (drag → creature stalks) | 100 touches |
| Belly rub (2-finger on creature) | 250 touches |

---

## 4. Camera Controller

### State
```swift
baseWorldX: CGFloat = 542.5     // Tracks creature's X position every frame
panOffset: CGFloat = 0           // User-initiated horizontal offset
zoomLevel: CGFloat = 1.0         // 1.0 = normal (range: 0.5–3.0)
cameraWorldY: CGFloat = 0.0     // Vertical tracking for terrain elevation
lockMode: CameraLockMode         // .free or .lockedToCreature
```

**Effective camera position** = `baseWorldX + panOffset`

### Camera Lock Modes

| Mode | Behavior | Pan | Zoom |
|------|----------|-----|------|
| `.free` | Camera follows creature but pan offset applies | Allowed | Allowed |
| `.lockedToCreature` | Camera centered exactly on creature | Suppressed (forced to 0) | Allowed |

**Lock triggers**:
- **Lock**: Tap on creature → `lockToCreature()` (0.3s ease-in-out animation to zero pan)
- **Unlock**: Tap on empty world OR drag on world → `unlockCamera()`

### Pan Behavior (Free Mode)

```
Input: drag deltaX from gesture
  → dampened = deltaX * 0.003
  → scaled = dampened / zoomLevel  (consistent feel at all zoom levels)
  → panOffset += scaled  (inverted: drag right → camera moves right → see content left)
  → clamped to ±800pt
```

**Decay**: After 3 seconds of no touch, pan offset decays exponentially:
- Half-life: 2.3 seconds
- Snaps to zero when < 0.5pt
- Effect: camera gently drifts back to creature

### Zoom Behavior

**Primary input**: `NSMagnificationGestureRecognizer`
- Records `startZoom` at gesture began
- Target = `startZoom × (1.0 + magnification)`
- Clamped to [0.5, 3.0]

**Fallback input**: Two-finger same-direction drag
- 200pt of finger travel = 1.0 zoom level change
- Left = zoom out, right = zoom in

**Focus-point compensation** — pinch center stays stationary:
```swift
let scale = newZoom / oldZoom
let centerOffset = centerWorldX - effectiveWorldX
panOffset += centerOffset * (1.0 - scale)
```

### Vertical Y Tracking

Camera follows creature up terrain elevations:
- Target: `max(0, creatureFocusY - 12.0)` — creature at ~40% from bottom
- Dead zone: 2pt (absorbs micro-jitter on flat ground)
- Exponential lerp with 0.6s half-life

### Recenter (Triple-Tap on World)

Animates over 0.4s with quadratic ease-in-out:
- Pan offset → 0
- Zoom → 1.0
- Camera Y → 0

---

## 5. Creature Scaling Under Zoom

The creature is **counter-scaled** to prevent clipping the 30pt bar:

| Zoom Range | Creature Behavior |
|-----------|-------------------|
| ≤ comfortable (26pt actual height) | Scales linearly with zoom |
| > comfortable | Growth decelerates (logarithmic compression) |
| Hard cap | 28pt max (leaves 2pt margin on 30pt bar) |

```
scaleFactor = cappedZoom / worldZoom
creature.setScale(depthScale * scaleFactor)
```

---

## 6. Zoom Detail Tiers (ZoomDetailController)

Zoom triggers 4 progressive detail levels with 0.1 hysteresis to prevent flickering:

| Zoom | Tier | Visual Changes |
|------|------|----------------|
| < 0.8x | Simplified | Hide whiskers, toe pads, inner ears. Thinner strokes. |
| 0.8–1.2x | Normal | Default rendering. |
| 1.2–2.0x | Enhanced | Toe pads on all paws, fur texture, whisker detail. |
| > 2.0x | Maximum | Toe beans (4 per paw), ear tufts, nose highlight (lazy-created). |

---

## 7. Parallax Response

3-layer parallax scrolls relative to camera:

| Layer | Scroll Factor | Z | Effect |
|-------|---------------|---|--------|
| Far (stars, mountains) | 0.15x | -100 | Barely moves |
| Mid (hills, landmarks) | 0.4x | -50 | Slow parallax |
| Fore (terrain, creature) | 1.0x | 0 | Moves with camera |

**Layer positioning per frame**:
```swift
layer.position.x = halfWidth - (cameraWorldX * scrollFactor)
layer.position.y = -cameraWorldY * scrollFactor
// When zoomed:
layer.setScale(zoom)
layer.position.y = baseY * zoom + focusY * (1.0 - zoom)
```

---

## 8. Frame Update Order

Each frame in `PushlingScene`:

1. **Physics** — behavior stack output
2. **World update** — camera controller gets creature position, computes effective X/Y/zoom → parallax layers repositioned → terrain recycled
3. **Render** — creature animations, zoom detail tier check, counter-scaling applied

---

## 9. Known Edge Cases & Decision Points

### Petting vs. Slow Drag
Both require speed < 100pt/s and > 15pt travel. The **differentiator is the creature hitbox** — petting only fires if the drag is within the padded creature bounds. Dragging near the creature edge could trigger either.

### Camera Lock + Zoom
When locked to creature, pan is suppressed but zoom still works. The creature stays centered while the world magnifies around it. User might expect dragging to work while zoomed — it won't until they tap empty space to unlock.

### Multi-Touch Suppression
When 2+ fingers are detected, **all single-finger logic is suppressed** (including drag and tap processing). This persists until all fingers lift. A failed pinch attempt could "eat" a drag.

### Tap 300ms Delay
Single taps wait 300ms before committing (to disambiguate double-tap). This means creature tap responses feel ~300ms delayed. Triple-taps commit immediately on the 3rd tap (no wait).

### Pan Decay While Exploring
If you pan to explore terrain, the camera starts drifting back to the creature after 3 seconds of no touch. This is exponential with 2.3s half-life — you have roughly 5–6 seconds before noticeable drift.

### Coordinate Conversion for Hit-Testing
View-space touches → world-space via:
```
worldX = camera.effectiveWorldX + (viewX - sceneCenter) / max(zoom, 0.1)
```
At high zoom, small finger movements map to large world distances, which could cause hit-test misses on small objects.

---

## 10. Key Source Files

| File | Responsibility |
|------|---------------|
| `TouchBar/TouchBarView.swift` | NSGestureRecognizer setup, raw touch capture |
| `Input/TouchTracker.swift` | 60Hz per-touch state, coordinate conversion, velocity smoothing |
| `Input/GestureRecognizer.swift` | 13-type gesture classification state machine |
| `Input/CreatureTouchHandler.swift` | Gesture routing to creature vs camera, milestone gating |
| `Scene/CameraController.swift` | Pan/zoom/lock state machine, decay, recenter animation |
| `Scene/PushlingScene.swift` | Scene setup, frame update orchestration |
| `Creature/ZoomDetailController.swift` | Zoom-dependent detail tier transitions |
| `World/ParallaxSystem.swift` | Camera position → layer positioning/scaling |

> **Deleted**: `GestureRecognizer+MultiTouch.swift` — multi-touch logic was consolidated into `GestureRecognizer.swift`.
