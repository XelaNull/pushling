// PhysicsLayer.swift — Layer 1 (highest priority): Physics
// Always running. Handles breathing, gravity, and boundary enforcement.
//
// Breathing is applied as a post-process multiplier on body yScale,
// NOT through the LayerOutput — ensuring it ALWAYS applies regardless
// of what other layers do. The PhysicsLayer communicates breathing
// through a separate property read by BehaviorStack after resolution.
//
// Physics has ZERO dependencies on personality or emotional state,
// except for sleep breathing modification.

import Foundation
import CoreGraphics

// MARK: - Jump State

/// Tracks an active jump arc (parabolic trajectory).
struct JumpState {
    /// Current vertical velocity in points/second.
    var velocityY: CGFloat

    /// Gravity constant: 180 pts/s^2 downward.
    static let gravity: CGFloat = 180.0

    /// Whether the creature has landed (arc complete).
    var hasLanded: Bool = false

    /// Frames since landing (for 2-frame compression).
    var landingFrames: Int = 0

    /// Number of frames the landing compression lasts.
    static let landingCompressionFrames = 2
}

// MARK: - Physics Layer

final class PhysicsLayer: BehaviorLayer {

    // MARK: - Breathing Constants

    /// Normal breathing: 1.0 to 1.03 over 2.5s period.
    private static let breathAmplitude: Double = 0.03
    private static let breathPeriod: Double = 2.5

    /// Sleep breathing: 1.0 to 1.02 over 3.5s period.
    private static let sleepBreathAmplitude: Double = 0.02
    private static let sleepBreathPeriod: Double = 3.5

    // MARK: - State

    /// Whether the creature is currently sleeping (modifies breathing).
    var isSleeping: Bool = false

    /// Current jump state, if the creature is mid-air.
    private(set) var activeJump: JumpState?

    /// The current breathing Y-scale, computed each frame.
    /// Read by BehaviorStack and applied directly to body yScale
    /// as a post-process (bypassing LayerOutput resolution).
    private(set) var breathingScale: CGFloat = 1.0

    /// The creature's current stage (for boundary margin calculation).
    var stage: GrowthStage = .critter

    /// The current creature X position — maintained by PhysicsLayer for
    /// boundary enforcement. Set externally when creature state is loaded.
    var currentX: CGFloat = 542.5

    /// The current creature Y position.
    var currentY: CGFloat = SceneConstants.groundY

    // MARK: - BehaviorLayer

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) -> LayerOutput {
        var output = LayerOutput()

        // 1. Breathing (always, every frame)
        updateBreathing(currentTime: currentTime)

        // 2. Jump / gravity
        if var jump = activeJump {
            updateJump(&jump, deltaTime: deltaTime, output: &output)
            activeJump = jump
        }

        // 3. Boundary enforcement
        enforceBoundaries(output: &output)

        return output
    }

    // MARK: - Breathing

    /// Computes the breathing yScale for this frame.
    /// Formula: body.yScale = 1.0 + amplitude * sin(2pi * t / period)
    private func updateBreathing(currentTime: TimeInterval) {
        let amplitude: Double
        let period: Double

        if isSleeping {
            amplitude = Self.sleepBreathAmplitude
            period = Self.sleepBreathPeriod
        } else {
            amplitude = Self.breathAmplitude
            period = Self.breathPeriod
        }

        let phase = 2.0 * Double.pi * currentTime / period
        breathingScale = CGFloat(1.0 + amplitude * sin(phase))
    }

    // MARK: - Jump / Gravity

    /// Initiates a jump with the given initial upward velocity.
    func startJump(initialVelocity: CGFloat) {
        guard activeJump == nil else { return }  // Can't double-jump
        activeJump = JumpState(velocityY: initialVelocity)
    }

    /// Updates the jump parabolic arc.
    private func updateJump(_ jump: inout JumpState, deltaTime: TimeInterval,
                            output: inout LayerOutput) {
        if jump.hasLanded {
            // Landing compression: hold "land" body state for 2 frames
            jump.landingFrames += 1
            if jump.landingFrames <= JumpState.landingCompressionFrames {
                output.bodyState = "land"
            } else {
                // Landing complete — clear jump
                activeJump = nil
            }
            return
        }

        // Apply gravity: v = v - g * dt
        let dt = CGFloat(deltaTime)
        jump.velocityY -= JumpState.gravity * dt

        // Update position: y = y + v * dt
        currentY += jump.velocityY * dt

        // Check for landing
        if currentY <= SceneConstants.groundY {
            currentY = SceneConstants.groundY
            jump.velocityY = 0
            jump.hasLanded = true
            jump.landingFrames = 0
            output.bodyState = "land"
            // Dust particles would be triggered here (Phase 2 creature integration)
        }

        output.positionY = currentY
    }

    // MARK: - Boundary Enforcement

    /// Clamps the creature's X position to the valid scene range.
    /// If the creature is at a boundary, stops it and optionally signals a turn.
    private func enforceBoundaries(output: inout LayerOutput) {
        let clamped = clamp(currentX, min: SceneConstants.minX,
                            max: SceneConstants.maxX)

        if clamped != currentX {
            currentX = clamped
            output.positionX = clamped
            // Boundary hit — the creature should turn around.
            // We don't set facing here (that's the blend controller's job
            // with the 0.43s reversal), but we do kill walk speed.
            output.walkSpeed = 0
        }
    }

    // MARK: - External Position Updates

    /// Called when the creature's X position changes from movement.
    /// The physics layer tracks this for boundary enforcement.
    func updatePosition(x: CGFloat) {
        currentX = x
    }

    /// Returns true if the creature is at or near a boundary.
    func isAtBoundary() -> Bool {
        currentX <= SceneConstants.minX + 2.0
            || currentX >= SceneConstants.maxX - 2.0
    }

    /// Returns which boundary side the creature is near, if any.
    func nearBoundary() -> Direction? {
        if currentX <= SceneConstants.minX + 2.0 { return .left }
        if currentX >= SceneConstants.maxX - 2.0 { return .right }
        return nil
    }
}
