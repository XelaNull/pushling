---
type: System
title: Camera Control
description: The user-driven pan/zoom camera model — per-stage constraints, lock modes, decay, recenter, and Y-tracking — as designed, alongside the fixed-viewport state it currently ships in.
status: Live
tags: [camera, touch, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for the **camera** — how the viewport's effective
world position is computed, constrained per growth stage, and animated.
It does **not** own parallax layer configuration (scroll factors, Z-depth,
per-layer positioning math) — that belongs to
[world & terrain parallax](/SYSTEMS/world-terrain-parallax.md); this
concept only establishes the camera state (`effectiveWorldX`,
`effectiveWorldY`, `zoomLevel`) that a parallax layer reads. Source:
`Scene/CameraController.swift`.

# Design Canon: Pan & Zoom

The camera is designed as a **user-controllable window** onto a world
wider than the 1085x30pt Touch Bar: the creature is tracked automatically
(`baseWorldX` snaps to the creature's world-X every frame), and the human
can pan away from that center and zoom in/out on top of it.
**Effective camera X = `baseWorldX + panOffset`.**

**Lock modes** (`CameraLockMode`): `.lockedToCreature` (pan suppressed,
forced toward zero; zoom still allowed) and `.unlocked` (pan offset
applies freely). Tapping the creature locks the camera back to it; tapping
or dragging empty world space unlocks it. Early growth stages (egg, drop)
force `autoLock = true` regardless of user input — see the constraints
table below.

**Per-stage constraints** (`CameraConstraints.constraints(for:)`):

| Stage | Max Pan Offset | Zoom Range | Pan Allowed | Auto-Lock | Decay Delay | Decay Half-Life |
|---|---|---|---|---|---|---|
| egg | 0 | 1.0-2.0 | no | yes | 0s | 0.5s |
| drop | 20pt | 1.0-2.0 | no | yes | 1.0s | 1.0s |
| critter | 200pt | 1.0-2.5 | yes | no | 2.0s | 1.5s |
| beast | 400pt | 1.0-3.0 | yes | no | 3.0s | 2.3s |
| sage | 600pt | 1.0-3.0 | yes | no | 3.0s | 2.3s |
| apex | 800pt | 1.0-3.0 | yes | no | 3.0s | 2.3s |

An evolution transition doesn't snap these values instantly — `updateConstraints(for:animated:)`
cross-fades old-to-new constraint values over a fixed 0.5s
(`constraintTransitionDuration`), simultaneously kicking off a recenter
animation (zoom eased back to 1.0, pan/Y reset) so the newly-larger
creature is fully visible right after evolving.

**Pan** (`pan(deltaX:)`, designed math): world-space offset accumulates as
raw finger-drag delta, inverted (drag right -> camera moves right -> scene
content appears to slide left), then clamped to
`±constraints.maxPanOffset`. Unlocking happens automatically on the first
user pan (unless the stage auto-locks). **Decay**: after
`decayDelay` seconds of no touch, `panOffset` decays exponentially toward
zero with the stage's `decayHalfLife`, snapping to exactly 0 once
`|panOffset| < 0.5pt` — the camera drifts gently back to the creature
rather than snapping.

**Zoom** (`zoom(delta:centerWorldX:)`, designed math): `zoomLevel` is
clamped to the stage's `[minZoom, maxZoom]`; the pinch/gesture center
point is kept visually stationary by compensating `panOffset` for the
scale change (`panOffset += (centerWorldX - effectiveWorldX) * (1 - scale)`),
so zooming feels anchored under the finger rather than around the
creature.

**Recenter** (triple-tap on empty world space, per
[the gesture-response map](/REFERENCE/gesture-response-map.md)): an
animated 0.4s ease-in-out that eases `panOffset` to 0, `zoomLevel` to 1.0,
and `cameraWorldY` to the scene-center default (15.0).

**`setZoom(_:animated:)`** is a programmatic entry point (intended for a
future "frame the creature's face" affordance —
`CameraController.faceZoomLevel(for:)` already computes the zoom level
that would fill ~70% of the Touch Bar height with the creature's face for
a given stage) — same disabled-in-current-build status as `pan`/`zoom`
below.

# Current Shipped State: Fixed Viewport

As of the most recent build (`8860e91`, 2026-07-01), **`pan(deltaX:)`,
`zoom(delta:centerWorldX:)`, and `setZoom(_:animated:)` each begin with an
unconditional early `return`**, guarded by a `// FIXED-VIEWPORT: pan
disabled for Day 1 proof-of-life` comment. All of the math described above
in Design Canon still exists in the method bodies below that `return` —
it is dead code, not deleted code, kept in place for the eventual
re-enable. This is a deliberate **transitional state**, not the intended
end state: the pan/zoom design above is the canon this system is being
built toward; the unbuilt/disabled status is tracked as an intent-canon
item at [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md).

Git history shows this is a genuine regression-by-design, not an
oversight: three commits (`4159177`, `f13b1e0`) tuned pan sensitivity down
from 0.3x to 0.02x of finger-drag distance to fix an over-sensitive
background ("background moved too fast" / "barely drifts on finger
drag"), only for the very next commit (`8860e91`) to disable pan/zoom
entirely and revert the sensitivity constant to 0.15x (now unreachable
dead code, since the `return` precedes it). The tuning work is preserved
in the method body for whenever pan/zoom ships for real — the sensitivity
constant will need re-verification against the 0.02x-tuned feel at that
point, since 0.15x was never actually shipped.

**Auto-lock and decay still run** even in the fixed-viewport state:
`update(deltaTime:creatureWorldX:...)` is never gated by the pan/zoom
disable — it still tracks `baseWorldX` to the creature, still runs the
`autoLock` pan-zeroing decay, and still runs full Y-tracking (below). Only
the two *user-input* entry points are dead-ended.

# Vertical (Y) Tracking

Independent of the pan/zoom disable, `cameraWorldY` continuously tracks
the creature's vertical position (for terrain elevation) with adaptive,
predictive smoothing — this is live in the current build:

- **Dead zone**: 0.5pt (`yDeadZone`) — sub-pixel jitter is ignored.
- **Predictive look-ahead**: the creature's Y-velocity is estimated via an
  EMA (`yVelocityAlpha = 2/(4+1) = 0.4`) and the camera targets the
  creature's position 0.2s (`yLookAhead`) in the future, not its current
  position — so the camera starts moving before the creature finishes a
  jump or terrain climb.
- **Adaptive half-life**: inside a 6-24pt "comfort zone"
  (`yComfortMin`/`yComfortMax`, screen-space points from the bottom), the
  camera lerps with a lazy 0.4s half-life (`yComfortHalfLife`); as the
  creature nears either screen edge, the half-life tightens smoothly down
  to an aggressive 0.12s (`yEdgeHalfLife`) so the camera catches up before
  the creature would clip off-screen.
- **Hard clamp backstop**: regardless of the lerp above, `cameraWorldY` is
  force-corrected if the creature's screen-space edge would fall outside
  `[yHardClampMin (3pt), yHardClampMax (27pt)]` — a final guarantee the
  creature never visually exits the 30pt bar.

# Cinematic Override

`setCinematicState(zoom:panOffset:)` / `clearCinematicState()` let a
cinematic sequencer drive `zoomLevel`/`panOffset` directly, bypassing all
of the above (decay, constraints, and — implicitly — the fixed-viewport
`return`s, since cinematic writes go straight to the backing properties,
not through `pan()`/`zoom()`). While `isCinematicActive`, the normal
per-frame `update()` short-circuits to just applying the cinematic
override values; `clearCinematicState()` hands the final cinematic values
back to the real `zoomLevel`/`panOffset` for a seamless return to normal
camera behavior. The cinematic sequencer's own trigger conditions and
sequences belong to a creature-visual concept, not this one.

# Frame Update Order

`PushlingScene.update(_:)` runs a fixed subsystem order every frame
(outside of the hatching-ceremony gate, which suppresses everything else
below it while active):

1. **Cinematic sequencer** (`cinematicSequencer.update`) — runs first,
   ahead of physics, so a cinematic's direct writes to camera/creature
   state aren't immediately overwritten by the same frame's normal update.
2. **Physics** (`updatePhysics`) — the 4-layer behavior stack resolves and
   blends its output onto the creature node. This is the step [the
   mini-game framework](/SYSTEMS/mini-games.md#input-takeover) does *not*
   suspend, despite the design calling for a physics-only mode during a
   mini-game.
3. **World** (`updateWorld`) — this concept's own state: `CameraController`
   is fed the creature's current X/height and computes `effectiveWorldX`/
   `effectiveWorldY`/`zoomLevel` for the frame (including the face-offset
   Y-tracking nudge that shifts focus upward as zoom increases — see
   [Vertical (Y) Tracking](#vertical-y-tracking) above); `WorldManager` is
   then updated with that effective camera position/zoom, which is what
   drives parallax layer repositioning and terrain chunk
   recycling/generation (see [world & terrain
   parallax](/SYSTEMS/world-terrain-parallax.md)); the creature is then
   positioned onto the terrain surface at its computed depth.
4. **Render** (`updateRender`) — `creatureNode.update` (breathing, blink,
   tail sway animations) and `emotionalVisualController.update`. **Not**
   included here despite the source design's "zoom detail tier check,
   counter-scaling applied" claim: neither `ZoomDetailController.update`
   nor any counter-scale call appears anywhere in this step (grep-verified)
   — both are real, built systems that are simply never invoked from the
   render step, consistent with their [defined-but-unwired
   status](/FEATURES/interactivity-unbuilt.md#live-pan--zoom).
5. Everything after render (evolution progress bar, debug eating/speech,
   diamond indicator, `GameCoordinator` pump, idle-timeout check) belongs
   to other concepts and isn't part of this camera/world/render core.

# Citations

[1] `Pushling/Sources/Pushling/Scene/CameraController.swift`
[2] `git log -p -- Pushling/Sources/Pushling/Scene/CameraController.swift` — commits `4159177`, `f13b1e0`, `8860e91`
[3] [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md) — 📐 status for live pan/zoom
[4] [world & terrain parallax](/SYSTEMS/world-terrain-parallax.md) — parallax layer configuration that consumes this camera's state
[5] `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` (superseded reference — described pan/zoom as already-live; several numeric claims there don't match the code's designed values either, e.g. pan dampening `deltaX * 0.003` vs code's `deltaX * 0.15`, zoom range `[0.5, 3.0]` vs code's per-stage `minZoom` always 1.0; §8 Frame Update Order is otherwise accurate and is restored above)
[6] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (`update(_:)`, `updatePhysics`/`updateWorld`/`updateRender`, lines ~184-330)
