---
type: System
title: Camera Control
description: The user-driven pan/zoom camera model — per-stage constraints, lock modes, decay, recenter, and Y-tracking — as designed, alongside the fixed-viewport state it currently ships in. Deepened with the designed horizontal deadzone, terrain-Y-only airborne tracking, camera dwell/edge-clamp overrides, Apex teleport-blink suspension, and the full per-mode precedence matrix.
status: Live
tags: [camera, touch, system]
timestamp: 2026-07-03T00:00:00Z
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

**Pan-vs-zoom consistent-feel rationale (unbuilt).** The archived reference
design divided the dampened drag delta by the current `zoomLevel` before
accumulating it into `panOffset` — "consistent feel at all zoom levels,"
so a given finger-drag distance moves the camera by the same *visual*
amount whether zoomed in or out, rather than the same *world-space*
amount (which would feel sluggish zoomed-in and twitchy zoomed-out). The
shipped `pan(deltaX:)` has no such division — `panOffset -= deltaX * 0.15`
is the entire calculation, with no `zoomLevel` term anywhere in the method
(grep-verified) — so pan feel is currently zoom-invariant only in the
sense that it doesn't yet vary with zoom at all, not in the design's
intended sense.

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

**AutoLock's pan-zeroing rate, code-verified**: while `constraints.autoLock`
is forced (egg/drop stages), any residual `panOffset` decays toward zero at
`pow(2, -deltaTime / 0.3)` per frame — an exponential decay with a **0.3s
half-life** — snapping to exactly 0 once `|panOffset| < 0.1`
(`CameraController.swift:270-277`). This is a distinct, faster mechanism
from the general post-touch decay above (which uses the stage's own
`decayHalfLife`, e.g. 2.3s at Beast+): autoLock's 0.3s rate only applies at
egg/drop, where pan is disallowed outright and any offset needs to snap
back quickly. The archived source's related claim — a "0.3s ease-in-out
animation to zero pan" fired specifically by *tapping the creature* to
manually lock at any stage — does not match: `lockToCreature()` only flips
`lockMode`, with no pan-zeroing or animation of its own; a manually-locked
pan offset at Critter+ still decays at that stage's own (slower)
`decayHalfLife`, not 0.3s.

# Horizontal Deadzone — Locomotion Reads as Travel (Designed, not built)

**Ground truth, code-verified**: `baseWorldX` has no deadzone today — it is
a hard, unconditional snap. `CameraController.update(deltaTime:creatureWorldX:...)`
sets `baseWorldX = creatureWorldX` every single frame
(`CameraController.swift:248`), with exactly one exception: for 5 seconds
after hatching (`smoothFollowRemaining`, `CameraController.swift:237-238`),
the camera lerps toward the creature at a fixed 1.5x-per-second catch-up
rate (`CameraController.swift:246`) instead of snapping — a one-time
onboarding softener, not a general-purpose tracking mode. This is the exact
mechanism the dossier's gap diagnosis means by "the camera re-centers on
the creature every frame" — real X locomotion renders as background
parallax scroll under a torso pinned at screen-center (`sceneWidth / 2 =
542.5`), because the camera never lets the creature's screen position
actually move.

**The fix, as designed**: while `|creatureWorldX - heldBaseWorldX| <=
windowRadius` (the deadzone window, held fixed at whatever `baseWorldX` was
when the window last activated), `baseWorldX` does **not** snap — the
creature's world position moves relative to a stationary camera, so its
*screen* X visibly slides across the window before any background scrolls.
Only once the creature exits the window does the camera re-center, easing
over **0.8s** to a **lead-room** framing — not dead center, but offset
`windowRadius x 0.4` in the creature's direction of travel (`facing`),
mirroring [the vertical predictive look-ahead](#vertical-y-tracking)'s
philosophy of framing where the creature is *going*, not just where it
is — so a creature walking steadily in one direction re-triggers the exit
ease less often than a naive re-center-to-exact-position would.

**Per-stage window** (design numbers — not dossier-literal except the Beast
row, which the dossier states outright as "±90pt... ±200pt during
zoomies/sprint"; the rest interpolate against each stage's existing
`maxPanOffset` scale and [locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md)'s
per-stage travel speeds):

| Stage | Base window (±pt) | Widened window (±pt) | Widening trigger |
|---|---|---|---|
| Egg | N/A | N/A | No directed movement at this stage — same Egg canon-vs-code conflict flagged as **DECISION-pending** in `docs/DECISIONS.md` D-1 and in [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension). |
| Drop | ±15pt | — | Drop has no sprint gait; the hop-scurry covers ~3-4pt per hop ([locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md)), so this window holds several hops before a reframe, and stays inside Drop's own 20pt `maxPanOffset` ceiling. |
| Critter | ±60pt | ±150pt | `zoomies` (`CatBehaviorsExtended.swift:11-17`, `minimumStage: .critter`) or any resolved `walkSpeed` (`LayerTypes.swift:152`) above the stage's normal-walk band. |
| Beast | ±90pt | ±200pt | Dossier-literal figures — Beast's native sprint/skid gait (`baseRunSpeed` 50pt/s, [locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md)) or `zoomies`. |
| Sage | ±90pt | ±200pt | Glide-walk covers similar ground at lower cadence; no stage-specific override given in source material. |
| Apex | ±90pt | ±200pt | Drift/zoomies; for travel distances >300pt the gait engine's teleport-blink fires instead of a tracked walk ([locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md#per-stage-signature-gaits)) — see [Apex Teleport-Blink Easing Suspension](#apex-teleport-blink-easing-suspension-designed-not-built) below. |

A third, smaller widening tier exists in the source material but is owned
by its consumer, not this concept: the Play & Toys lens's play-bout
Escalate/Climax beats widen the deadzone by **+25pt** so a toy-chase dash
reads as the body crossing the frame rather than background scroll — a
temporary `+25pt` added to whichever base/widened window is already active,
not a fourth absolute tier.

**Asymmetric bounds, clear of the P button.** The window itself is biased
slightly left-tight / right-loose (left radius ~0.85x the right radius) as
a defensive margin — at these window sizes (<=200pt around a 542.5pt
screen-center) this bias alone never brings the creature within reach of
the reserved AppKit overlay strip (`ProgressButtonView` at screen
`x:2-26`, `MenuStripView` expandable to roughly `x:30-210` when open —
both [`TouchBar/TouchBarView.swift:63,71`](#citations) and
[`TouchBar/TouchBarMenu.swift`](#citations)'s per-item widths). The
overlay strip's real avoidance is [Edge-Clamp](#camera-dwell--edge-clamp-designed-not-built)
below, which *deliberately* frames the creature there for bunting — the
deadzone's own asymmetry just ensures ordinary wandering never drifts
close enough by accident to visually collide with the button before a
reframe would have fired anyway.

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

**Code-verified ordering nuance.** `PushlingScene.updateWorld` reads
`creatureFocusY` from `creatureNode?.position.y` (`PushlingScene.swift:310`)
*before* that same call recomputes and reassigns `creature.position` for
the current frame (`PushlingScene.swift:338-342`) — the camera's Y-tracking
input is therefore always one frame stale relative to this frame's terrain
query. At 60fps (~16.6ms) this is imperceptible today and not worth
correcting on its own, but it matters for the airborne fix below, which
depends on controlling exactly what value that stale read resolves to.

## Terrain-Y-Only Tracking During Airborne Frames (Designed, not built)

Once [body-pose-pipeline.md's `positionY`/`isAirborne` compose
step](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)
ships, `creature.position.y` will include the airborne lift
(`liftedY = groundY + max(0, airborneOffset)`) whenever the creature is
mid-jump. Left unmodified, the ordering nuance above means the *next*
frame's `creatureFocusY` (camera Y-tracking input) would inherit that
lifted value — and the adaptive comfort/edge half-life system exists
specifically to chase the creature's Y position, so the camera would climb
right along with the jump. The visible result is exactly what the airborne
system exists to avoid: the whole parallax world bobbing up and down with
the creature instead of the creature visibly leaving a stationary ground.

**The fix**: feed the camera the creature's **ground** Y
(`terrainY + config.size.height / 2`, computed independently of
`creature.position.y`) as `creatureFocusY`, unconditionally — not only
while `isAirborne`. `PushlingScene.updateWorld` already computes exactly
this value at `PushlingScene.swift:330-334`, just *after* the camera-update
call rather than before it; the fix is a **reordering**, not new math —
compute `terrainY` first, derive `creatureFocusY` from it directly, then
call `cameraController.update(...)`, then apply the (possibly airborne)
`liftedY` to `creature.position` last. `CameraController` itself needs no
`isAirborne` awareness at all under this design: it never sees a lifted Y
to chase in the first place, so the existing comfort-zone/edge-zone/hard-
clamp math above is untouched and still governs ordinary terrain-elevation
changes (climbs, drops) exactly as it does today.

# Camera Dwell & Edge-Clamp (Designed, not built)

Two related overrides that both **suspend** the horizontal deadzone/snap
above rather than replace it with a different tracking formula — both are
long-lived holds (seconds to the length of a whole sleep bout), not
per-frame easing curves like the deadzone's own 0.8s exit reframe.

**Camera dwell** — for [idle-life-and-rest.md's Sleep
Geography](/SYSTEMS/idle-life-and-rest.md#4-sleep-geography), New- and
Familiar-tier sleep spots are deliberately off-center (far end of the bar,
or mid-bar against a favorite object) — the entire point is a visible
trust signal that only reads if the camera stops chasing the sleeper.
**Dwell** freezes `baseWorldX` at whatever value it held the instant
`.resting`'s Sleep Geography walk-to-spot completes, suspending the normal
per-frame `baseWorldX = creatureWorldX` snap (and any deadzone reframing)
for the sleep bout's full duration. On wake, tracking does not resume with
an instant snap back to center — it reuses the **existing** post-hatch
onboarding primitive verbatim: `smoothFollowRemaining` re-armed to its
5-second window (`CameraController.swift:237-238,242-249`), so the camera
eases back to the creature at the same 1.5x-per-second catch-up rate
already shipped for hatching, rather than a new resume mechanism.

**Edge-clamp** — for [companionship-rituals.md's
Bunting](/SYSTEMS/companionship-rituals.md#4-bunting--cheek-rubbing-the-p-button)
and Devoted-tier Sleep Geography (which sleeps within 12pt of the P
button, i.e. deliberately *inside* the reserved overlay margin the deadzone's
own asymmetry avoids by accident), the creature must be framed standing
*beside* the real `ProgressButtonView` frame (`x:2-26, y:4-22`,
`TouchBar/TouchBarView.swift:63`) rather than at screen-center. This needs
a genuine *target* framing, not just a frozen one: an `isEdgeClamped` flag
(structurally the same short-circuit `isCinematicActive` already uses —
`CameraController.swift:184-198` — but driven by companionship-rituals/
Sleep-Geography instead of the cinematic sequencer) carrying an
`edgeClampTargetScreenX` (34pt — just clear of the button's 26pt right
edge, short of the menu strip's 30pt collapsed start). While active,
`baseWorldX` eases toward `creatureWorldX - (edgeClampTargetScreenX -
sceneWidth / 2)` over the same **0.4s ease-in-out** curve/duration the
shipped triple-tap [Recenter](#design-canon-pan--zoom) already uses (reused
rather than a third invented duration constant), then holds there — the
normal snap stays suspended until `clearEdgeClamp()` eases back to center
over the same 0.4s, mirroring `clearCinematicState()`'s handoff pattern.
Bunting and Devoted-tier sleep share this one target and mechanism rather
than each inventing their own framing.

**Precedence**: both dwell and edge-clamp sit below Cinematic Override (an
active cinematic sequence always wins — see below) but above the ordinary
deadzone, since both are longer-lived, intent-driven holds rather than the
deadzone's passive per-frame window check. See the [per-mode
matrix](#per-mode-camera-matrix) for the full ordering.

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

# Apex Teleport-Blink Easing Suspension (Designed, not built)

[locomotion-and-gait.md's Apex signature
gait](/SYSTEMS/locomotion-and-gait.md#per-stage-signature-gaits) reinterprets
travel beyond a ±300pt excursion as a **teleport-blink**: a 150ms alpha
fade to literal OLED void (per [the grounds' "the creature IS the light
source" rule](/SYSTEMS/locomotion-and-gait.md#citations), a void-faded
creature is genuinely invisible, not just dim) followed by a 1-frame Gilt
shimmer on reappearance at the destination. Any camera easing running
*through* that 150ms window would visibly slide the parallax world under
nothing — there is no creature on screen to justify the motion, so it
reads as a glitch rather than a teleport.

**The fix**: on teleport-blink start, the camera **freezes** — the same
suspend-the-snap mechanism [Camera Dwell](#camera-dwell--edge-clamp-designed-not-built)
uses, held for exactly the blink's 150ms. On the reappear frame (the 1-frame
Gilt shimmer), `baseWorldX` **snaps** instantly to the post-teleport
`creatureWorldX` — no ease, no lerp, a hard cut matching the hard position
cut the teleport itself performs. This is a deliberate exception to every
other transition in this concept (which all ease): a 150ms teleport is
already an instantaneous event by design, and easing the camera to catch up
would imply the creature was gradually flying to its destination, which
contradicts the "teleport" premise. Vertical Y-tracking is unaffected —
Apex's drift stays within its normal comfort-zone band outside of a blink,
and the blink itself carries no vertical component in the source material.

# Per-Mode Camera Matrix

Five governing modes, in strict precedence order (a higher row wins over
every row below it whenever both would otherwise apply):

| # | Mode | Trigger | X behavior | Y behavior | Duration / exit |
|---|---|---|---|---|---|
| 1 | **Cinematic** | `setCinematicState` (cinematic sequencer) | Direct writes to `panOffset`; `baseWorldX` still snaps to the creature underneath (uncontested — cinematic reads `effectiveWorldX` off `baseWorldX + panOffset`, so a cinematic sequence choosing a fixed `panOffset` freely composes with whatever the creature is doing) | Untouched by cinematic override today (`cameraWorldY` keeps its own normal update) | Until `clearCinematicState()` |
| 2 | **Apex teleport-blink** | Excursion >300pt at Apex | Frozen 150ms, then instant snap (no ease) | Unaffected | 150ms, hard-coded |
| 3 | **Edge-clamp** | Bunting trigger; Devoted-tier Sleep Geography | Eases to `edgeClampTargetScreenX` (34pt) over 0.4s, then holds | Untouched (P-button framing is X-only) | Until `clearEdgeClamp()`, 0.4s ease back |
| 4 | **Camera dwell** | New/Familiar-tier Sleep Geography (`.resting` reached) | Frozen at hold-start value | Untouched | Until wake; resumes via `smoothFollowRemaining` (5s) |
| 5 | **Deadzone (+ widening)** | Default once built — always active outside modes 1-4 | Held while inside the per-stage window; 0.8s lead-room ease on exit; window widens per the [widening table](#horizontal-deadzone--locomotion-reads-as-travel-designed-not-built) during zoomies/sprint/play-bout | Normal comfort/edge-zone lerp, terrain-Y-only per the [airborne fix](#terrain-y-only-tracking-during-airborne-frames-designed-not-built) | Continuous |
| — | **Today's shipped baseline** | No deadzone built yet | Hard snap every frame (`baseWorldX = creatureWorldX`) | As shipped (comfort/edge lerp, no airborne fix) | N/A — this row disappears once row 5 ships |
| — | **Mini-games** | `MiniGameManager.isGameActive` | Not a distinct camera mode — [mini-games.md](/SYSTEMS/mini-games.md#input-takeover) code-verifies only *touch input* is redirected during a game (only `.tap` reaches `handleTap`), not the behavior stack or the camera; whichever mode above (1-5) was already active keeps running unmodified underneath a game | Same | N/A |

This resolves the dossier's flagged risk directly: the deadzone (row 5) is
the passive default, always superseded by an active dwell/clamp/blink/
cinematic hold above it, so widening the deadzone can never fight the
already-shipped cinematic system — cinematic wins by construction, not by
a new arbitration rule.

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
   positioned onto the terrain surface at its computed depth. The
   [terrain-Y-only airborne fix](#terrain-y-only-tracking-during-airborne-frames-designed-not-built)
   and the [horizontal deadzone](#horizontal-deadzone--locomotion-reads-as-travel-designed-not-built)
   both land inside this one step, ahead of the terrain-surface position
   write, per the [per-mode matrix](#per-mode-camera-matrix)'s precedence.
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
[6] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (`update(_:)`, `updatePhysics`/`updateWorld`/`updateRender`, lines ~184-330; `updateWorld`'s `creatureFocusY`/`baseY` read at line 310, terrain-Y computation at lines 330-334, position write at lines 338-342)
[7] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (Camera Deadzone, Airborne Arc System, Sleep Geography, Bunting, Apex teleport-blink sections; Risks section on the camera per-mode-matrix requirement) and `.samantha/scratch/flesh-out-design-2026-07-03.json` (`.grounds[0]`/`.grounds[1]` camera baseline and hard constraints; `.proposals` Play Drive ±25pt widening detail)
[8] `Pushling/Sources/Pushling/Creature/CatBehaviorsExtended.swift:11-17` (`zoomies`, `minimumStage: .critter`)
[9] `Pushling/Sources/Pushling/TouchBar/TouchBarView.swift:63,71` (`ProgressButtonView`/`MenuStripView` overlay frames) and `Pushling/Sources/Pushling/TouchBar/TouchBarMenu.swift` (`expandedWidth`, per-item widths)
[10] [locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md) — per-stage travel speeds, zoomies-deadzone cross-reference, Apex teleport-blink and OLED-void citation
[11] [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md) — `positionY`/`isAirborne` compose math this concept's airborne-Y fix depends on
[12] [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md) — Sleep Geography tiers and its own flagged camera-dwell dependency
[13] [companionship-rituals.md](/SYSTEMS/companionship-rituals.md) — Bunting's flagged edge-clamp dependency and Reunion Runway's cinematic-release requirement
