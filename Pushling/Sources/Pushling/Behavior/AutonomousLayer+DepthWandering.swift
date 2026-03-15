// AutonomousLayer+DepthWandering.swift — Z-axis depth wandering behavior
// The creature naturally walks between foreground and background terrain layers.
// Z range is stage-gated (small creatures stay close, larger ones explore deeper).
// Personality and emotions influence when and how far the creature wanders in depth.

import Foundation
import CoreGraphics

extension AutonomousLayer {

    // MARK: - Stage-Gated Z Limits

    /// Maximum Z depth the creature can wander to at each growth stage.
    /// Must remain readable on the 30pt Touch Bar at minimum scale.
    static func maxDepthZ(for stage: GrowthStage) -> CGFloat {
        switch stage {
        case .spore, .drop: return 0.2   // Min scale ~0.9x, ~5-6pt creature
        case .critter:      return 0.5   // Min scale ~0.75x, ~7-8pt creature
        case .beast, .sage: return 0.65  // Min scale ~0.68x, ~8-9pt creature
        case .apex:         return 0.8   // Min scale ~0.6x, ~9pt (larger base)
        }
    }

    // MARK: - Depth Target Selection

    /// Selects a new target Z based on personality, emotions, and growth stage.
    /// Called during walk transitions with a personality-influenced probability.
    ///
    /// - Returns: A target Z value within stage-gated bounds.
    func selectTargetZ() -> CGFloat {
        let maxZ = Self.maxDepthZ(for: stage)

        // Base: return to foreground (most common)
        var targetZ: CGFloat = 0.0

        // Curiosity > 60 → 25% chance of deeper Z target
        if emotions.curiosity > 60, randomDepthChance(0.25) {
            targetZ = CGFloat(randomDepthRange(0.3, Double(maxZ)))
        }

        // Low energy → drift toward background (resting in hills)
        if emotions.energy < 30 {
            targetZ = CGFloat(randomDepthRange(0.2, Double(min(maxZ, 0.5))))
        }

        // High energy personality → wider Z swings, more frequent changes
        if personality.energy > 0.7, randomDepthChance(0.3) {
            targetZ = CGFloat(randomDepthRange(0.0, Double(maxZ)))
        }

        // High focus personality → prefer staying near current depth
        if personality.focus > 0.7, randomDepthChance(0.6) {
            targetZ = currentZ  // Stay put
        }

        return clamp(targetZ, min: 0.0, max: maxZ)
    }

    // MARK: - Smooth Depth Transition

    /// Smoothly interpolates the creature's Z position toward the target.
    /// Rate: ~0.15 Z-units/sec (full foreground-to-deep takes ~5s).
    ///
    /// - Parameter deltaTime: Time since last frame.
    func updateDepthWalk(deltaTime: TimeInterval) {
        let target = depthTargetZ
        let current = currentZ
        let diff = target - current

        guard abs(diff) > 0.005 else {
            // Close enough — snap to target
            currentZ = target
            return
        }

        // Smooth approach: 0.15 Z-units per second
        let speed: CGFloat = 0.15
        let step = speed * CGFloat(deltaTime)

        if diff > 0 {
            currentZ = min(current + step, target)
        } else {
            currentZ = max(current - step, target)
        }
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

    private func randomDepthChance(_ probability: Double) -> Bool {
        Double.random(in: 0...1) < probability
    }
}
