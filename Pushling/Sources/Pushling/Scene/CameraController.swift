// CameraController.swift — Pan/zoom camera controls for the Touch Bar scene
// Manages user-initiated camera pan and zoom on top of creature-tracking.
// Pan: single-finger drag on empty space slides the view.
// Zoom: two-finger pinch scales parallax layers.
// Auto-recenter: pan offset decays exponentially after inactivity.
// Triple-tap on world: animated recenter + reset zoom.
// Stage-based constraints: per-stage limits on pan range, zoom, and auto-lock.
// Vertical containment: adaptive Y-tracking with predictive look-ahead.

import CoreGraphics
import Foundation

// MARK: - Camera Constraints

/// Per-stage camera constraints. Controls how far the user can pan, zoom,
/// and whether the camera auto-locks to the creature.
struct CameraConstraints {
    let maxPanOffset: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let panAllowed: Bool
    let autoLock: Bool
    let decayDelay: TimeInterval
    let decayHalfLife: TimeInterval

    static func constraints(for stage: GrowthStage) -> CameraConstraints {
        switch stage {
        case .egg:
            // Closer than default but not so close that terrain overwhelms
            return CameraConstraints(
                maxPanOffset: 0, minZoom: 1.3, maxZoom: 2.0,
                panAllowed: false, autoLock: true,
                decayDelay: 0, decayHalfLife: 0.5)
        case .drop:
            // Slightly wider view as world opens up
            return CameraConstraints(
                maxPanOffset: 20, minZoom: 1.2, maxZoom: 2.0,
                panAllowed: false, autoLock: true,
                decayDelay: 1.0, decayHalfLife: 1.0)
        case .critter:
            return CameraConstraints(
                maxPanOffset: 200, minZoom: 0.7, maxZoom: 2.5,
                panAllowed: true, autoLock: false,
                decayDelay: 2.0, decayHalfLife: 1.5)
        case .beast:
            return CameraConstraints(
                maxPanOffset: 400, minZoom: 0.5, maxZoom: 3.0,
                panAllowed: true, autoLock: false,
                decayDelay: 3.0, decayHalfLife: 2.3)
        case .sage:
            return CameraConstraints(
                maxPanOffset: 600, minZoom: 0.5, maxZoom: 3.0,
                panAllowed: true, autoLock: false,
                decayDelay: 3.0, decayHalfLife: 2.3)
        case .apex:
            return CameraConstraints(
                maxPanOffset: 800, minZoom: 0.5, maxZoom: 3.0,
                panAllowed: true, autoLock: false,
                decayDelay: 3.0, decayHalfLife: 2.3)
        }
    }
}

// MARK: - Lock Mode

/// Camera lock mode — whether the camera auto-follows the creature.
enum CameraLockMode {
    case lockedToCreature
    case unlocked
}

// MARK: - Camera Controller

final class CameraController {

    // MARK: - Constants

    /// Recenter animation duration in seconds.
    private static let recenterDuration: TimeInterval = 0.4

    /// Constraint transition duration in seconds.
    private static let constraintTransitionDuration: TimeInterval = 0.5

    // MARK: - Y-Tracking Constants

    /// Dead zone for Y-tracking — creature must move more than this to trigger chase.
    private static let yDeadZone: CGFloat = 0.5

    /// Comfort zone Y-tracking half-life (creature in safe center area).
    private static let yComfortHalfLife: TimeInterval = 0.4

    /// Edge zone Y-tracking half-life (creature near screen edge — aggressive chase).
    private static let yEdgeHalfLife: TimeInterval = 0.12

    /// Scene height in points.
    private static let sceneHeight: CGFloat = 30.0

    /// Comfort zone lower bound (points from bottom of scene).
    private static let yComfortMin: CGFloat = 6.0

    /// Comfort zone upper bound (points from bottom of scene).
    private static let yComfortMax: CGFloat = 24.0

    /// Hard clamp minimum — creature center must stay above this.
    private static let yHardClampMin: CGFloat = 3.0

    /// Hard clamp maximum — creature center must stay below this.
    private static let yHardClampMax: CGFloat = 27.0

    /// Predictive look-ahead duration in seconds.
    private static let yLookAhead: TimeInterval = 0.2

    /// EMA smoothing factor for velocity estimation (4-frame window at 60fps).
    private static let yVelocityAlpha: CGFloat = 2.0 / (4.0 + 1.0)

    // MARK: - Stage Constraints

    /// Active camera constraints (driven by stage).
    private(set) var constraints: CameraConstraints = .constraints(for: .egg)

    /// Whether a constraint transition animation is in progress.
    private var isTransitioningConstraints = false
    private var constraintTransitionProgress: TimeInterval = 0
    private var oldConstraints: CameraConstraints?
    private var newConstraints: CameraConstraints?

    // MARK: - Lock Mode

    /// Current camera lock mode.
    private(set) var lockMode: CameraLockMode = .lockedToCreature

    // MARK: - X-Tracking State

    /// The creature-tracking base position. Updated each frame.
    /// Internal setter needed for hatching ceremony camera sync.
    var baseWorldX: CGFloat = 542.5

    /// User pan offset (added to base). Decays after inactivity.
    private(set) var panOffset: CGFloat = 0

    /// Current zoom level (1.0 = normal).
    private(set) var zoomLevel: CGFloat = 1.0

    /// Effective camera world-X (base + pan offset).
    var effectiveWorldX: CGFloat {
        baseWorldX + panOffset
    }

    /// Time since last touch interaction.
    private var timeSinceLastTouch: TimeInterval = 0

    /// Whether we're in the middle of an animated recenter.
    private var isRecentering: Bool = false
    private var recenterProgress: TimeInterval = 0
    private var recenterStartOffset: CGFloat = 0
    private var recenterStartZoom: CGFloat = 1.0

    /// Whether the user has actively panned (to distinguish from default state).
    var hasActivePan: Bool {
        abs(panOffset) > 1.0
    }

    /// Whether the user has zoomed.
    var hasActiveZoom: Bool {
        zoomLevel > 1.01
    }

    // MARK: - Cinematic Mode

    /// Whether the cinematic sequencer is driving camera state.
    private(set) var isCinematicActive: Bool = false

    /// Cinematic zoom override (nil = use normal zoom).
    private(set) var cinematicZoom: CGFloat?

    /// Cinematic pan offset override (nil = use normal pan).
    private(set) var cinematicPanOffset: CGFloat?

    /// Set cinematic camera overrides. When either value is non-nil,
    /// cinematic mode is active: normal decay/constraint logic is skipped,
    /// and user pan/zoom inputs are ignored.
    func setCinematicState(zoom: CGFloat?, panOffset: CGFloat?) {
        cinematicZoom = zoom ?? cinematicZoom
        cinematicPanOffset = panOffset ?? cinematicPanOffset
        isCinematicActive = (cinematicZoom != nil || cinematicPanOffset != nil)
    }

    /// Clear all cinematic overrides and return to normal camera control.
    func clearCinematicState() {
        // Apply final cinematic values to the real state for smooth handoff
        if let cz = cinematicZoom { zoomLevel = cz }
        if let cp = cinematicPanOffset { self.panOffset = cp }
        isCinematicActive = false
        cinematicZoom = nil
        cinematicPanOffset = nil
    }

    // MARK: - Y-Tracking State

    /// Camera's current world-Y position (smoothly tracks creature).
    private(set) var cameraWorldY: CGFloat = 15.0

    /// Exponential moving average of creature Y velocity (pts/sec).
    private var creatureYVelocity: CGFloat = 0

    /// Previous frame's creature Y for velocity estimation.
    private var previousCreatureY: CGFloat = 15.0

    /// Effective camera world-Y (for external consumers).
    var effectiveWorldY: CGFloat {
        cameraWorldY
    }

    // MARK: - Per-Frame Update

    /// Update the camera each frame. Tracks creature position and decays pan offset.
    ///
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - creatureWorldX: The creature's current world-X position.
    func update(deltaTime: TimeInterval, creatureWorldX: CGFloat) {
        update(deltaTime: deltaTime, creatureWorldX: creatureWorldX,
               creatureFocusY: 15.0, creatureHeight: 6.0)
    }

    /// Update the camera each frame with full Y-tracking support.
    ///
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - creatureWorldX: The creature's current world-X position.
    ///   - creatureFocusY: The creature's current world-Y center position.
    ///   - creatureHeight: The creature's height in points (for margin calc).
    /// Smooth follow duration remaining after hatching (seconds).
    /// When > 0, the camera lerps toward the creature instead of snapping.
    var smoothFollowRemaining: TimeInterval = 0
    private static let smoothFollowDuration: TimeInterval = 5.0

    func update(deltaTime: TimeInterval, creatureWorldX: CGFloat,
                creatureFocusY: CGFloat, creatureHeight: CGFloat) {
        if smoothFollowRemaining > 0 {
            // Lerp camera toward creature over several seconds
            smoothFollowRemaining -= deltaTime
            let t = CGFloat(deltaTime * 1.5)  // Smooth catch-up rate
            baseWorldX += (creatureWorldX - baseWorldX) * min(t, 1.0)
        } else {
            baseWorldX = creatureWorldX
        }

        // Cinematic mode: sequencer drives zoom/pan, skip decay and constraints
        if isCinematicActive {
            if let cz = cinematicZoom { zoomLevel = cz }
            if let cp = cinematicPanOffset { panOffset = cp }
            return
        }

        timeSinceLastTouch += deltaTime

        // Update constraint transition if active
        updateConstraintTransition(deltaTime: deltaTime)

        // Animated recenter in progress
        if isRecentering {
            updateRecenter(deltaTime: deltaTime)
            return
        }

        // AutoLock: force lock mode and zero out pan
        if constraints.autoLock {
            lockMode = .lockedToCreature
            if abs(panOffset) > 0.1 {
                let lockDecay = pow(2.0, CGFloat(-deltaTime / 0.3))
                panOffset *= lockDecay
                if abs(panOffset) < 0.1 { panOffset = 0 }
            }
        }

        // Decay pan offset after delay (only pan, not zoom)
        let activeDecayDelay = effectiveDecayDelay()
        let activeDecayHalfLife = effectiveDecayHalfLife()
        if timeSinceLastTouch > activeDecayDelay && abs(panOffset) > 0.5 {
            let decayFactor = pow(2.0, CGFloat(-deltaTime / activeDecayHalfLife))
            panOffset *= decayFactor

            // Snap to zero when close
            if abs(panOffset) < 0.5 {
                panOffset = 0
            }
        }

        // Y-tracking
        updateYTracking(deltaTime: deltaTime,
                        creatureFocusY: creatureFocusY,
                        creatureHeight: creatureHeight)
    }

    // MARK: - Y-Tracking

    /// Adaptive Y-tracking with predictive look-ahead and hard clamp.
    private func updateYTracking(deltaTime: TimeInterval,
                                 creatureFocusY: CGFloat,
                                 creatureHeight: CGFloat) {
        guard deltaTime > 0 else { return }

        // Estimate creature Y velocity via EMA
        let instantVelocity = (creatureFocusY - previousCreatureY) / CGFloat(deltaTime)
        creatureYVelocity = Self.yVelocityAlpha * instantVelocity
            + (1.0 - Self.yVelocityAlpha) * creatureYVelocity
        previousCreatureY = creatureFocusY

        // Predictive target: where the creature will be in 200ms
        let predictedY = creatureFocusY + creatureYVelocity * CGFloat(Self.yLookAhead)

        // Compute screen-space Y of creature relative to camera
        let screenY = creatureFocusY - cameraWorldY + Self.sceneHeight / 2.0

        // Adaptive half-life based on proximity to screen edges
        let halfLife = adaptiveYHalfLife(screenY: screenY)

        // Compute target error (dead zone applied)
        let targetY = predictedY
        let error = targetY - cameraWorldY
        if abs(error) > Self.yDeadZone {
            let lerpFactor = 1.0 - pow(2.0, CGFloat(-deltaTime / halfLife))
            cameraWorldY += error * lerpFactor
        }

        // Hard clamp backstop — creature center must be within [3pt, 27pt] of screen
        // Adjusted for zoom: effective margins shrink with zoom
        let effectiveMin = Self.yHardClampMin / zoomLevel
        let effectiveMax = Self.yHardClampMax / zoomLevel
        let halfHeight = creatureHeight / 2.0
        let screenCreatureY = creatureFocusY - cameraWorldY + Self.sceneHeight / 2.0

        if screenCreatureY - halfHeight < effectiveMin {
            cameraWorldY = creatureFocusY - halfHeight - effectiveMin + Self.sceneHeight / 2.0
        } else if screenCreatureY + halfHeight > effectiveMax {
            cameraWorldY = creatureFocusY + halfHeight - effectiveMax + Self.sceneHeight / 2.0
        }
    }

    /// Compute adaptive Y half-life based on screen-space position.
    /// In comfort zone (6-24pt): use 0.4s. Near edges: use 0.12s.
    /// Smoothly interpolate between the two.
    private func adaptiveYHalfLife(screenY: CGFloat) -> TimeInterval {
        // Distance from nearest edge of comfort zone
        let distFromComfort: CGFloat
        if screenY < Self.yComfortMin {
            distFromComfort = Self.yComfortMin - screenY
        } else if screenY > Self.yComfortMax {
            distFromComfort = screenY - Self.yComfortMax
        } else {
            return Self.yComfortHalfLife  // Fully in comfort zone
        }

        // Max distance from comfort to screen edge (~6pt on each side)
        let maxEdgeDist: CGFloat = Self.yComfortMin
        let edgeFraction = clamp(distFromComfort / maxEdgeDist, min: 0, max: 1)

        // Lerp between comfort and edge half-lives
        let comfort = CGFloat(Self.yComfortHalfLife)
        let edge = CGFloat(Self.yEdgeHalfLife)
        return TimeInterval(comfort + (edge - comfort) * edgeFraction)
    }

    // MARK: - Recenter Animation

    private func updateRecenter(deltaTime: TimeInterval) {
        recenterProgress += deltaTime
        let t = min(recenterProgress / Self.recenterDuration, 1.0)
        let eased = CGFloat(Easing.easeInOut(t))

        panOffset = recenterStartOffset * (1.0 - eased)
        zoomLevel = recenterStartZoom + (1.0 - recenterStartZoom) * eased

        if t >= 1.0 {
            panOffset = 0
            zoomLevel = 1.0
            isRecentering = false
        }
    }

    // MARK: - Constraint Transition

    /// Animate between old and new constraints over 0.5s.
    private func updateConstraintTransition(deltaTime: TimeInterval) {
        guard isTransitioningConstraints,
              let old = oldConstraints,
              let new = newConstraints else { return }

        constraintTransitionProgress += deltaTime
        let t = min(constraintTransitionProgress / Self.constraintTransitionDuration, 1.0)
        let eased = CGFloat(Easing.easeInOut(t))

        // Smoothly clamp pan offset if it exceeds new limits
        let activeMaxPan = old.maxPanOffset + (new.maxPanOffset - old.maxPanOffset) * eased
        panOffset = clamp(panOffset, min: -activeMaxPan, max: activeMaxPan)

        // Smoothly clamp zoom if it exceeds new limits
        let activeMinZoom = old.minZoom + (new.minZoom - old.minZoom) * eased
        let activeMaxZoom = old.maxZoom + (new.maxZoom - old.maxZoom) * eased
        zoomLevel = clamp(zoomLevel, min: activeMinZoom, max: activeMaxZoom)

        if t >= 1.0 {
            isTransitioningConstraints = false
            oldConstraints = nil
            newConstraints = nil
        }
    }

    /// Effective decay delay, interpolated during constraint transitions.
    private func effectiveDecayDelay() -> TimeInterval {
        guard isTransitioningConstraints,
              let old = oldConstraints,
              let new = newConstraints else {
            return constraints.decayDelay
        }
        let t = min(constraintTransitionProgress / Self.constraintTransitionDuration, 1.0)
        let eased = Easing.easeInOut(t)
        return old.decayDelay + (new.decayDelay - old.decayDelay) * eased
    }

    /// Effective decay half-life, interpolated during constraint transitions.
    private func effectiveDecayHalfLife() -> TimeInterval {
        guard isTransitioningConstraints,
              let old = oldConstraints,
              let new = newConstraints else {
            return constraints.decayHalfLife
        }
        let t = min(constraintTransitionProgress / Self.constraintTransitionDuration, 1.0)
        let eased = Easing.easeInOut(t)
        return old.decayHalfLife + (new.decayHalfLife - old.decayHalfLife) * eased
    }

    // MARK: - Stage Constraint Updates

    /// Update camera constraints for a new growth stage.
    ///
    /// - Parameters:
    ///   - stage: The new growth stage.
    ///   - animated: Whether to smoothly transition (default: true).
    func updateConstraints(for stage: GrowthStage, animated: Bool = true) {
        let target = CameraConstraints.constraints(for: stage)

        if animated {
            oldConstraints = constraints
            newConstraints = target
            constraintTransitionProgress = 0
            isTransitioningConstraints = true
        } else {
            // Immediately apply — clamp current values
            panOffset = clamp(panOffset, min: -target.maxPanOffset,
                              max: target.maxPanOffset)
            zoomLevel = clamp(zoomLevel, min: target.minZoom, max: target.maxZoom)
        }

        constraints = target

        // Handle autoLock changes
        if target.autoLock {
            lockToCreature()
        }
    }

    // MARK: - Lock Mode

    /// Lock the camera to follow the creature (zero pan offset over time).
    func lockToCreature() {
        lockMode = .lockedToCreature
    }

    /// Unlock the camera so the user can pan freely.
    func unlockCamera() {
        guard !constraints.autoLock else { return }
        lockMode = .unlocked
    }

    // MARK: - User Input

    /// Apply a pan delta from a touch drag.
    ///
    /// - Parameter deltaX: Screen-space drag distance in points.
    func pan(deltaX: CGFloat) {
        // Ignore user pan during cinematic sequences
        guard !isCinematicActive else { return }
        // Reject pan if constraints disallow it
        guard constraints.panAllowed else { return }

        // Cancel any ongoing recenter
        isRecentering = false
        timeSinceLastTouch = 0

        // Unlock camera on user pan
        if lockMode == .lockedToCreature && !constraints.autoLock {
            lockMode = .unlocked
        }

        // Pan in world space with heavily reduced sensitivity (0.08x).
        // Touch Bar finger drags report large point deltas for tiny physical
        // movements. Background should barely drift, not fly.
        panOffset -= deltaX * 0.02

        // Clamp pan offset
        panOffset = clamp(panOffset, min: -constraints.maxPanOffset,
                          max: constraints.maxPanOffset)
    }

    /// Apply a zoom delta from a pinch gesture.
    ///
    /// - Parameters:
    ///   - delta: Zoom change (positive = zoom in, negative = zoom out).
    ///   - centerWorldX: World-X position that should stay fixed during zoom.
    func zoom(delta: CGFloat, centerWorldX: CGFloat) {
        // Ignore user zoom during cinematic sequences
        guard !isCinematicActive else { return }
        // Cancel any ongoing recenter
        isRecentering = false
        timeSinceLastTouch = 0

        let oldZoom = zoomLevel
        zoomLevel = clamp(zoomLevel + delta, min: constraints.minZoom,
                          max: constraints.maxZoom)

        // Adjust pan to keep the pinch center stationary
        if oldZoom != zoomLevel {
            let scale = zoomLevel / oldZoom
            let centerOffset = centerWorldX - effectiveWorldX
            panOffset += centerOffset * (1.0 - scale)
        }
    }

    /// Record a touch interaction (resets decay timer).
    func recordTouch() {
        timeSinceLastTouch = 0
    }

    /// Animated recenter to creature position + reset zoom.
    /// Called on triple-tap on empty world space.
    func recenter() {
        isRecentering = true
        recenterProgress = 0
        recenterStartOffset = panOffset
        recenterStartZoom = zoomLevel
    }
}
