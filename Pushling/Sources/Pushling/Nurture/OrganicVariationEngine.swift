// OrganicVariationEngine.swift — 5 variation axes ensuring nothing plays identically
// Applied to: habits, quirks, routines, and taught behavior triggers.
//
// Axes:
//   1. Timing jitter: durations varied by percentage
//   2. Probabilistic skipping: even "always" habits skip occasionally
//   3. Mood modulation: sad creature performs happy habits half-heartedly
//   4. Energy scaling: tired creature = reduced intensity
//   5. Personality consistency: discipline modulates all variation
//
// Each performance generates a unique variation seed.

import Foundation

// MARK: - Variation Seed

/// A per-execution seed that determines all jitter values.
struct VariationSeed {
    let timingJitter: Double       // Multiplier for durations
    let shouldSkip: Bool           // Whether this execution is skipped
    let moodSpeedMod: Double       // Speed modifier from mood
    let moodAmplitudeMod: Double   // Amplitude modifier from mood
    let energySpeedMod: Double     // Speed modifier from energy
    let personalityMod: Double     // Overall consistency modifier
}

// MARK: - OrganicVariationEngine

/// Computes per-execution variation parameters.
/// Makes every behavior execution unique while maintaining personality consistency.
final class OrganicVariationEngine {

    // MARK: - Random State

    private var rng = SystemRandomNumberGenerator()

    // MARK: - Seed Generation

    /// Generates a variation seed for a single execution.
    ///
    /// - Parameters:
    ///   - frequency: The habit's frequency level (affects skip rate).
    ///   - variation: The habit's variation level (affects jitter range).
    ///   - personality: Creature's personality snapshot.
    ///   - emotions: Creature's emotional state.
    /// - Returns: A unique variation seed for this execution.
    func generateSeed(
        frequency: HabitFrequency,
        variation: VariationLevel,
        personality: PersonalitySnapshot,
        emotions: EmotionalSnapshot
    ) -> VariationSeed {

        // === Axis 5: Personality consistency ===
        // High discipline (1.0): narrow variation. Low (0.0): wide variation.
        let disciplineFactor = personality.discipline

        // === Axis 1: Timing jitter ===
        // Base jitter from variation level, modulated by discipline
        let baseJitter = variation.jitterPercent
        let effectiveJitter = baseJitter * (1.5 - disciplineFactor)
        let timingJitter = 1.0 + Double.random(in: -effectiveJitter...effectiveJitter,
                                                using: &rng)

        // === Axis 2: Probabilistic skipping ===
        let baseSkipRate: Double
        switch frequency {
        case .always:    baseSkipRate = 0.05  // Even "always" skips 5%
        case .often:     baseSkipRate = 0.10
        case .sometimes: baseSkipRate = 0.15
        case .rarely:    baseSkipRate = 0.20
        }
        // High discipline = fewer skips
        let effectiveSkipRate = baseSkipRate * (1.5 - disciplineFactor)
        let shouldSkip = Double.random(in: 0...1, using: &rng) < effectiveSkipRate

        // === Axis 3: Mood modulation ===
        // Sad creature performs happy habits half-heartedly
        let avgMood = (emotions.satisfaction + emotions.contentment) / 200.0
        let moodSpeedMod: Double
        let moodAmplitudeMod: Double
        if avgMood < 0.3 {
            // Low mood: slower, less amplitude
            moodSpeedMod = 0.7
            moodAmplitudeMod = 0.6
        } else if avgMood > 0.7 {
            // High mood: slightly faster, full amplitude
            moodSpeedMod = 1.1
            moodAmplitudeMod = 1.0
        } else {
            moodSpeedMod = 1.0
            moodAmplitudeMod = 1.0
        }

        // === Axis 4: Energy scaling ===
        // Tired creature = reduced intensity
        let energyFraction = emotions.energy / 100.0
        let energySpeedMod = Swift.max(0.5, energyFraction)  // Min 0.5x speed

        // Overall personality modifier
        let personalityMod = 0.8 + disciplineFactor * 0.4  // [0.8, 1.2]

        return VariationSeed(
            timingJitter: timingJitter,
            shouldSkip: shouldSkip,
            moodSpeedMod: moodSpeedMod,
            moodAmplitudeMod: moodAmplitudeMod,
            energySpeedMod: energySpeedMod,
            personalityMod: personalityMod
        )
    }

    // MARK: - Application

    /// Applies a variation seed to a duration value.
    func applyTiming(_ baseDuration: TimeInterval,
                      seed: VariationSeed) -> TimeInterval {
        return baseDuration * seed.timingJitter * (1.0 / seed.energySpeedMod)
    }

    /// Applies a variation seed to a speed value.
    func applySpeed(_ baseSpeed: Double,
                     seed: VariationSeed) -> Double {
        return baseSpeed * seed.moodSpeedMod * seed.energySpeedMod * seed.personalityMod
    }

    /// Applies a variation seed to an amplitude/intensity value.
    func applyAmplitude(_ baseAmplitude: Double,
                         seed: VariationSeed) -> Double {
        return baseAmplitude * seed.moodAmplitudeMod * seed.personalityMod
    }

    /// Returns a post-behavior expression if mood modulation calls for it.
    /// (e.g., creature sighs after performing a happy habit when sad)
    func postBehaviorExpression(seed: VariationSeed) -> String? {
        if seed.moodAmplitudeMod < 0.7 {
            // Creature was performing reluctantly — sigh after
            return Double.random(in: 0...1, using: &rng) < 0.3
                ? "melancholy" : nil
        }
        return nil
    }

    // MARK: - Discipline Summary

    /// Returns human-readable description of variation behavior
    /// for a given discipline level.
    static func disciplineDescription(_ discipline: Double) -> String {
        if discipline > 0.8 {
            return "consistent, clockwork, reliable (jitter 3%, skip 2%)"
        } else if discipline > 0.5 {
            return "mostly consistent with occasional variation"
        } else if discipline > 0.2 {
            return "variable, unpredictable timing"
        } else {
            return "chaotic, surprising, wild variation (jitter 45%, skip 15%)"
        }
    }
}
