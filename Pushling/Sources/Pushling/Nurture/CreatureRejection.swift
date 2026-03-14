// CreatureRejection.swift — Personality alignment checks for nurture actions
// When a habit conflicts with personality, the creature performs reluctantly:
//   - Starts weaker (0.3 instead of 0.5)
//   - Performance is slower, lower intensity
//   - 15% chance creature visibly balks (stops, shakes head, does it anyway)
//
// With persistent reinforcement (10+), creature gradually accepts.
// Journal tracks the arc from reluctant to accepting.

import Foundation

// MARK: - Conflict Type

/// The type of personality conflict detected.
enum PersonalityConflict: String {
    case energyTooHigh    // High-energy habit on calm creature
    case energyTooLow     // Low-energy habit on hyper creature
    case disciplineMismatch // Strict routine on chaotic creature
    case verbosityMismatch  // Chatty habit on stoic creature
    case none
}

// MARK: - Rejection Result

/// The result of checking a behavior against creature personality.
struct RejectionResult {
    let conflict: PersonalityConflict
    let hasConflict: Bool
    let reluctanceLevel: Double     // 0.0 (no reluctance) to 1.0 (maximum reluctance)
    let startingStrength: Double    // 0.3 for conflicts, 0.5 normally
    let shouldBalk: Bool            // 15% chance at max reluctance

    /// Speed multiplier for reluctant performance.
    var speedMultiplier: Double {
        1.0 - reluctanceLevel * 0.3  // 0.7x at max reluctance
    }

    /// Amplitude multiplier for reluctant performance.
    var amplitudeMultiplier: Double {
        1.0 - reluctanceLevel * 0.4  // 0.6x at max reluctance
    }
}

// MARK: - CreatureRejection

/// Checks personality alignment and computes rejection parameters.
final class CreatureRejection {

    // MARK: - Random State

    private var rng = SystemRandomNumberGenerator()

    // MARK: - Conflict Detection

    /// Checks a behavior for personality conflicts.
    ///
    /// - Parameters:
    ///   - behaviorCategory: The behavior's category.
    ///   - behaviorEnergy: How energetic the behavior is (0.0-1.0).
    ///   - personality: Creature's personality.
    ///   - reinforcementCount: How many times this has been reinforced.
    /// - Returns: A RejectionResult describing any conflict.
    func checkAlignment(
        behaviorCategory: String,
        behaviorEnergy: Double,
        personality: PersonalitySnapshot,
        reinforcementCount: Int
    ) -> RejectionResult {

        let conflict = detectConflict(
            category: behaviorCategory,
            energy: behaviorEnergy,
            personality: personality
        )

        guard conflict != .none else {
            return RejectionResult(
                conflict: .none,
                hasConflict: false,
                reluctanceLevel: 0.0,
                startingStrength: 0.5,
                shouldBalk: false
            )
        }

        // Calculate reluctance (decreases with reinforcement)
        // At 0 reinforcements: 1.0 reluctance
        // At 10+ reinforcements: 0.0 reluctance (fully accepted)
        let reluctance = Swift.max(0.0, 1.0 - Double(reinforcementCount) * 0.1)

        // 15% chance of visible balk, scaled by reluctance
        let balkChance = 0.15 * reluctance
        let shouldBalk = Double.random(in: 0...1, using: &rng) < balkChance

        let startStrength = reluctance > 0.5 ? 0.3 : 0.5

        return RejectionResult(
            conflict: conflict,
            hasConflict: true,
            reluctanceLevel: reluctance,
            startingStrength: startStrength,
            shouldBalk: shouldBalk
        )
    }

    // MARK: - Specific Conflict Detection

    /// Detects the specific type of personality conflict.
    private func detectConflict(
        category: String,
        energy: Double,
        personality: PersonalitySnapshot
    ) -> PersonalityConflict {

        // Energy mismatch: high-energy behavior on calm creature
        if energy > 0.7 && personality.energy < 0.3 {
            return .energyTooHigh
        }

        // Reverse: low-energy behavior on hyper creature
        if energy < 0.3 && personality.energy > 0.7 {
            return .energyTooLow
        }

        // Discipline mismatch: strict/ritualistic on chaotic creature
        if (category == "functional" || category == "calm")
            && personality.discipline < 0.2 {
            return .disciplineMismatch
        }

        // Verbosity mismatch: chatty behavior on stoic creature
        if category == "dramatic" && personality.verbosity < 0.2 {
            return .verbosityMismatch
        }

        return .none
    }

    // MARK: - Balk Animation

    /// Returns the LayerOutput for a visible balk (head shake, reluctant start).
    /// Call before the actual behavior execution to prepend the balk.
    func balkOutput() -> LayerOutput {
        var output = LayerOutput()
        output.walkSpeed = 0
        output.bodyState = "stand"
        output.earLeftState = "flat"
        output.earRightState = "flat"
        output.tailState = "low"
        output.eyeLeftState = "squint"
        output.eyeRightState = "squint"
        // Head shake would be implied by the creature's animation system
        return output
    }

    /// Duration of the balk animation in seconds.
    static let balkDuration: TimeInterval = 0.8

    // MARK: - Journal Arc

    /// Returns a journal description based on reluctance level.
    /// Tracks the arc from reluctant to accepting.
    func journalDescription(
        habitName: String,
        creatureName: String,
        reluctanceLevel: Double,
        reinforcementCount: Int
    ) -> String {
        if reinforcementCount == 0 && reluctanceLevel > 0.8 {
            return "\(creatureName) reluctantly \(habitName). "
                + "Looked uncomfortable."
        } else if reinforcementCount < 5 && reluctanceLevel > 0.5 {
            return "\(creatureName) performed \(habitName) — "
                + "still seems unsure about it."
        } else if reinforcementCount < 10 && reluctanceLevel > 0.2 {
            return "\(creatureName) did \(habitName) — "
                + "almost seemed to enjoy it."
        } else if reinforcementCount >= 10 {
            return "\(creatureName)'s \(habitName) is part of who they are now."
        } else {
            return "\(creatureName) performed \(habitName)."
        }
    }

    // MARK: - Reluctant Performance Modifier

    /// Applies reluctance to a LayerOutput (reduces intensity).
    func applyReluctance(to output: inout LayerOutput,
                          reluctanceLevel: Double) {
        guard reluctanceLevel > 0.1 else { return }

        // Reduce walk speed
        if let speed = output.walkSpeed {
            output.walkSpeed = speed * CGFloat(1.0 - reluctanceLevel * 0.3)
        }

        // Add reluctant expression if no eyes set
        if reluctanceLevel > 0.5 {
            if output.eyeLeftState == nil {
                output.eyeLeftState = "squint"
                output.eyeRightState = "squint"
            }
            if output.earLeftState == nil {
                output.earLeftState = "back"
                output.earRightState = "back"
            }
        }
    }

    // MARK: - Acceptance Query

    /// Returns whether the creature has fully accepted a previously-conflicting habit.
    func hasAccepted(reinforcementCount: Int) -> Bool {
        return reinforcementCount >= 10
    }
}
