// CameraController.swift — Pan/zoom camera controls for the Touch Bar scene
// Manages user-initiated camera pan and zoom on top of creature-tracking.
// Pan: single-finger drag on empty space slides the view.
// Zoom: two-finger pinch scales parallax layers (1.0x - 2.0x).
// Auto-recenter: pan offset decays exponentially after 3s of no touch.
// Triple-tap on world: animated recenter + reset zoom.

import CoreGraphics
import Foundation

final class CameraController {

    // MARK: - Constants

    /// Maximum zoom level (2.0x = double magnification).
    private static let maxZoom: CGFloat = 2.0

    /// Minimum zoom level (1.0x = normal view).
    private static let minZoom: CGFloat = 1.0

    /// Maximum pan offset in points (prevents scrolling into void).
    private static let maxPanOffset: CGFloat = 800.0

    /// Seconds of no touch before pan offset begins decaying.
    private static let decayDelay: TimeInterval = 3.0

    /// Decay half-life in seconds (~2.3s = 63% decay per half-life).
    private static let decayHalfLife: TimeInterval = 2.3

    /// Recenter animation duration in seconds.
    private static let recenterDuration: TimeInterval = 0.4

    // MARK: - State

    /// The creature-tracking base position. Updated each frame.
    private(set) var baseWorldX: CGFloat = 542.5

    /// User pan offset (added to base). Decays after inactivity.
    private(set) var panOffset: CGFloat = 0

    /// Current zoom level (1.0 = normal, 2.0 = max zoom).
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

    // MARK: - Per-Frame Update

    /// Update the camera each frame. Tracks creature position and decays pan offset.
    ///
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - creatureWorldX: The creature's current world-X position.
    func update(deltaTime: TimeInterval, creatureWorldX: CGFloat) {
        baseWorldX = creatureWorldX
        timeSinceLastTouch += deltaTime

        // Animated recenter in progress
        if isRecentering {
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
            return
        }

        // Decay pan offset after delay (only pan, not zoom)
        if timeSinceLastTouch > Self.decayDelay && abs(panOffset) > 0.5 {
            // Exponential decay: offset *= 2^(-dt / halfLife)
            let decayFactor = pow(2.0, CGFloat(-deltaTime / Self.decayHalfLife))
            panOffset *= decayFactor

            // Snap to zero when close
            if abs(panOffset) < 0.5 {
                panOffset = 0
            }
        }
    }

    // MARK: - User Input

    /// Apply a pan delta from a touch drag.
    ///
    /// - Parameter deltaX: Screen-space drag distance in points.
    func pan(deltaX: CGFloat) {
        // Cancel any ongoing recenter
        isRecentering = false
        timeSinceLastTouch = 0

        // Pan in world space: dragging right moves the view left (camera moves right)
        // Invert so drag direction matches view movement (drag right → see content to the left)
        panOffset -= deltaX

        // Clamp pan offset
        panOffset = clamp(panOffset, min: -Self.maxPanOffset, max: Self.maxPanOffset)
    }

    /// Apply a zoom delta from a pinch gesture.
    ///
    /// - Parameters:
    ///   - delta: Zoom change (positive = zoom in, negative = zoom out).
    ///   - centerWorldX: World-X position that should stay fixed during zoom.
    func zoom(delta: CGFloat, centerWorldX: CGFloat) {
        // Cancel any ongoing recenter
        isRecentering = false
        timeSinceLastTouch = 0

        let oldZoom = zoomLevel
        zoomLevel = clamp(zoomLevel + delta, min: Self.minZoom, max: Self.maxZoom)

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
