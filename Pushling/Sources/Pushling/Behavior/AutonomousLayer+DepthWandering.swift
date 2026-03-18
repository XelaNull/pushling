// AutonomousLayer+DepthWandering.swift — Purposeful depth wandering
// The creature picks a (X, Z) destination, walks there diagonally,
// dwells for a few seconds, then picks the next destination.
// Z changes proportionally to X progress — smooth slope traversal.

import Foundation
import CoreGraphics

extension AutonomousLayer {

    // MARK: - Stage-Gated Z Limits

    /// Maximum Z depth the creature can wander to at each growth stage.
    /// Must remain readable on the 30pt Touch Bar at minimum scale.
    static func maxDepthZ(for stage: GrowthStage) -> CGFloat {
        return 0.8
    }

    // MARK: - Destination Selection

    /// Picks a unified (X, Z) destination for the creature to walk toward.
    /// X: 80-400pt away in the creature's facing direction, clamped to scene bounds.
    /// Z: Random depth within stage-gated range.
    func selectDestination() -> (targetX: CGFloat, targetZ: CGFloat) {
        let maxZ = Self.maxDepthZ(for: stage)
        let targetZ = CGFloat(randomDepthRange(0.05, Double(maxZ)))

        let distance = CGFloat(randomDepthRange(80, 400))
        let direction: CGFloat = facing == .right ? 1 : -1
        var targetX = currentX + distance * direction

        // Clamp to scene boundaries with margin
        let margin: CGFloat = 40.0
        targetX = clamp(targetX, min: margin,
                        max: SceneConstants.sceneWidth - margin)

        return (targetX: targetX, targetZ: clamp(targetZ, min: 0.0, max: maxZ))
    }

    // MARK: - Slope-Based Z Step

    /// Derives Z change from X change so both axes arrive simultaneously.
    /// ratio = (targetZ - currentZ) / (targetX - currentX); returns ratio * xStep.
    func depthStepForXStep(xStep: CGFloat, targetX: CGFloat,
                           targetZ: CGFloat) -> CGFloat {
        let remainingX = targetX - currentX
        guard abs(remainingX) > 0.5 else {
            // Almost there — snap Z directly
            return targetZ - currentZ
        }
        let ratio = (targetZ - currentZ) / remainingX
        return ratio * xStep
    }

    // MARK: - Slope Speed Multiplier

    /// Steep slopes slow horizontal speed. Slope = abs(dZ) / abs(dX).
    /// Returns 0.3x minimum on steep climbs, 1.0x on flat terrain.
    static func slopeSpeedMultiplier(currentZ: CGFloat, targetZ: CGFloat,
                                     currentX: CGFloat,
                                     targetX: CGFloat) -> CGFloat {
        let dX = abs(targetX - currentX)
        guard dX > 1.0 else { return 1.0 }
        let slope = abs(targetZ - currentZ) / dX
        return max(1.0 - slope * 50.0, 0.3)
    }

    // MARK: - Walk Speed Depth Scaling

    /// Returns a walk speed multiplier based on current Z depth.
    /// Further away = slower movement (perspective effect).
    ///
    /// - Parameter z: Current Z depth (0.0-1.0).
    /// - Returns: Speed multiplier (1.0 at z=0, 0.7 at z=1.0).
    static func depthSpeedMultiplier(z: CGFloat) -> CGFloat {
        return 1.0 - z * 0.3
    }

    // MARK: - Depth Random Utilities (avoid ambiguity with base class)

    private func randomDepthRange(_ min: Double, _ max: Double) -> Double {
        Double.random(in: min...max)
    }
}
