// PersonalityFilter.swift — Modulates animation parameters by personality axes
// Pure functions with no side effects. Called by AutonomousLayer and BlendController.
//
// Every animation in the creature's repertoire passes through this filter.
// Two creatures with extreme opposite personalities should look and act
// DRAMATICALLY differently when placed side by side.
//
// Modulation is deterministic: same personality + same base value = same result.
// No randomness here — randomness is in the behavior selector and jitter timer.

import Foundation
import CoreGraphics

// MARK: - Personality Filter

/// Modulates base animation parameters using personality axes.
/// Data-driven modulation table — no hardcoded if/else chains.
enum PersonalityFilter {

    // MARK: - Walk Speed

    /// Modulate walk speed by personality energy.
    /// Energy 0.0 -> ×0.6, Energy 1.0 -> ×1.4
    static func walkSpeed(base: CGFloat,
                           personality: PersonalitySnapshot) -> CGFloat {
        let multiplier = 0.6 + personality.energy * 0.8
        return max(base * CGFloat(multiplier), 1.0)
    }

    /// Modulate walk speed by emergent state on top of personality.
    static func walkSpeed(base: CGFloat,
                           personality: PersonalitySnapshot,
                           emergent: EmergentStateModifiers) -> CGFloat {
        let personalityAdjusted = walkSpeed(base: base,
                                             personality: personality)
        return max(personalityAdjusted * CGFloat(emergent.walkSpeedMultiplier),
                   0.0)
    }

    // MARK: - Walk Duration

    /// Modulate walk duration by energy and focus.
    /// Energy: inverse (hyper = shorter walks) ×(1.5 - E×1.0) = [0.5, 1.5]
    /// Focus: focused = longer walks ×(0.8 + F×0.4) = [0.8, 1.2]
    static func walkDuration(base: TimeInterval,
                              personality: PersonalitySnapshot) -> TimeInterval {
        let energyMod = 1.5 - personality.energy * 1.0
        let focusMod = 0.8 + personality.focus * 0.4
        return max(base * energyMod * focusMod, 0.5)
    }

    // MARK: - Idle Duration

    /// Modulate idle duration. Hyper creatures idle less.
    /// Energy inverted: ×(0.5 + E×0.5) then inverted = hyper -> shorter idle
    static func idleDuration(base: TimeInterval,
                              personality: PersonalitySnapshot,
                              emergent: EmergentStateModifiers) -> TimeInterval {
        let energyMod = 1.5 - personality.energy * 1.0  // [0.5, 1.5]
        let emergentMod = emergent.idleDurationMultiplier
        return max(base * energyMod * emergentMod, 0.5)
    }

    // MARK: - Behavior Cooldown

    /// Modulate behavior cooldown. Hyper = shorter cooldowns.
    /// ×(0.6 + (1-E)×0.8) = [0.6, 1.4]
    static func behaviorCooldown(base: TimeInterval,
                                  personality: PersonalitySnapshot,
                                  emergent: EmergentStateModifiers
                                      = .none) -> TimeInterval {
        let energyMod = 0.6 + (1.0 - personality.energy) * 0.8
        let emergentMod = emergent.behaviorCooldownMultiplier
        return max(base * energyMod * emergentMod, 5.0)
    }

    // MARK: - Direction Change Frequency

    /// Modulate direction change probability.
    /// Scattered (focus 0.0) = more changes.
    /// ×(0.5 + (1-F)×1.0) = [0.5, 1.5]
    static func directionChangeProbability(
        base: Double,
        personality: PersonalitySnapshot,
        emergent: EmergentStateModifiers = .none
    ) -> Double {
        let focusMod = 0.5 + (1.0 - personality.focus) * 1.0
        let emergentMod = emergent.directionChangeMultiplier
        return clamp(base * focusMod * emergentMod, min: 0, max: 1)
    }

    // MARK: - Timing Jitter

    /// Compute the jitter range for a timing value.
    /// Chaotic (0.0) = ±20%, Disciplined (1.0) = ±3%.
    /// Returns the jitter percentage (e.g., 0.03 to 0.20).
    static func jitterRange(
        personality: PersonalitySnapshot
    ) -> Double {
        0.03 + (1.0 - personality.discipline) * 0.17
    }

    /// Apply discipline-based jitter to a timing value.
    /// Returns the jittered value (does NOT contain randomness —
    /// the caller supplies the random factor).
    static func applyJitter(base: TimeInterval,
                             jitterFactor: Double,
                             personality: PersonalitySnapshot) -> TimeInterval {
        let range = jitterRange(personality: personality)
        let jitter = 1.0 + jitterFactor * range
        return max(base * jitter, 0.1)
    }

    // MARK: - Blink Interval

    /// Modulate blink interval. High energy = blinks more often.
    /// Min interval: lerp(4.0, 2.5, E)
    /// Max interval: lerp(9.0, 5.0, E)
    static func blinkInterval(
        personality: PersonalitySnapshot
    ) -> ClosedRange<TimeInterval> {
        let minInterval = lerp(4.0, 2.5, personality.energy)
        let maxInterval = lerp(9.0, 5.0, personality.energy)
        return max(minInterval, 2.0)...max(maxInterval, minInterval + 0.5)
    }

    // MARK: - Tail Sway

    /// Modulate tail sway amplitude.
    /// High energy = bigger sway. ×(0.7 + E×0.6) = [0.7, 1.3]
    static func tailSwayAmplitude(base: Double,
                                   personality: PersonalitySnapshot) -> Double {
        let mod = 0.7 + personality.energy * 0.6
        return base * mod
    }

    /// Modulate tail sway period.
    /// High energy = faster sway (shorter period). ×(0.7 + (1-E)×0.6)
    /// High discipline = more consistent. ×(0.9 + D×0.2)
    static func tailSwayPeriod(base: Double,
                                personality: PersonalitySnapshot) -> Double {
        let energyMod = 0.7 + (1.0 - personality.energy) * 0.6
        let disciplineMod = 0.9 + personality.discipline * 0.2
        return max(base * energyMod * disciplineMod, 0.5)
    }

    // MARK: - Reaction Expressiveness

    /// Modulate reaction expressiveness (how dramatic body-part responses are).
    /// High verbosity = full-body reactions.
    /// ×(0.5 + V×1.0) = [0.5, 1.5]
    static func reactionExpressiveness(
        personality: PersonalitySnapshot
    ) -> Double {
        0.5 + personality.verbosity * 1.0
    }

    // MARK: - Ear Movement Frequency

    /// Modulate ear movement frequency. High focus = more ear movement.
    /// ×(0.5 + F×1.0) = [0.5, 1.5]
    static func earMovementFrequency(base: Double,
                                      personality: PersonalitySnapshot) -> Double {
        let mod = 0.5 + personality.focus * 1.0
        return base * mod
    }

    // MARK: - Animation Tempo

    /// Overall animation tempo multiplier.
    /// Used by body part controllers for transition speeds.
    /// Calm (0.0) = 0.7x tempo, Hyper (1.0) = 1.4x tempo.
    static func animationTempo(
        personality: PersonalitySnapshot
    ) -> Double {
        0.7 + personality.energy * 0.7
    }

    // MARK: - Reflex Snap Speed

    /// Modulate reflex snap duration.
    /// Mobile specialty gets faster reflexes (0.12s instead of 0.15s).
    static func reflexSnapDuration(
        base: TimeInterval,
        specialty: LanguageCategory
    ) -> TimeInterval {
        switch specialty {
        case .mobile: return base * 0.8  // 20% faster
        default:      return base
        }
    }

    // MARK: - Specialty Modifiers

    /// Visual alpha modifier for infra specialists (slight translucency).
    static func bodyAlpha(specialty: LanguageCategory) -> CGFloat {
        switch specialty {
        case .infra: return 0.92
        default:     return 1.0
        }
    }

    /// Whether sparkle particles should appear on ear perk (frontend).
    static func hasEarPerkSparkle(specialty: LanguageCategory) -> Bool {
        specialty == .frontend
    }

    /// Whether data-spark trail particles should follow the tail (data).
    static func hasDataSparkTrail(specialty: LanguageCategory) -> Bool {
        specialty == .data
    }

    /// Whether the walk cycle should use smoother interpolation (script).
    static func hasSmoothWalkCycle(specialty: LanguageCategory) -> Bool {
        specialty == .script
    }

    /// Whether the tail should have clockwork-regular movement (config).
    static func hasClockworkTail(specialty: LanguageCategory) -> Bool {
        specialty == .config
    }

    /// Whether eyes should be heterochromatic (polyglot).
    static func hasHeterochromia(specialty: LanguageCategory) -> Bool {
        specialty == .polyglot
    }

    // MARK: - Compound Modulation

    /// Apply all personality + emergent modifiers to a walk speed.
    /// Convenience method combining personality and emotional energy.
    static func modulatedWalkSpeed(
        base: CGFloat,
        personality: PersonalitySnapshot,
        emotionalEnergy: Double,
        emergent: EmergentStateModifiers = .none
    ) -> CGFloat {
        let personalitySpeed = walkSpeed(base: base, personality: personality)
        let emotionMod = 0.5 + emotionalEnergy / 100.0 * 0.5  // [0.5, 1.0]
        let emergentMod = emergent.walkSpeedMultiplier
        return max(personalitySpeed * CGFloat(emotionMod * emergentMod), 0)
    }
}
