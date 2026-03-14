// VoicePersonality.swift — Pitch, speed, and character from personality axes
// Maps the 4 personality axes to TTS voice parameters.
// Voice identity is locked at each stage transition for consistency.
//
// The creature's voice is deterministic: same personality = same voice.
// Parameters are calculated once per evolution, stored in SQLite.

import Foundation

// MARK: - Voice Tier

/// The 3 TTS tiers, gated by growth stage.
enum VoiceTier: String, Codable {
    case babble    // Drop: espeak-ng chirps
    case emerging  // Critter: Piper TTS babble-to-speech
    case speaking  // Beast+: Kokoro-82M clear speech

    /// Tier for a given growth stage.
    static func forStage(_ stage: GrowthStage) -> VoiceTier? {
        switch stage {
        case .spore:   return nil         // Silent
        case .drop:    return .babble
        case .critter: return .emerging
        case .beast, .sage, .apex: return .speaking
        }
    }
}

// MARK: - Voice Parameters

/// Computed voice parameters derived from personality axes.
/// Locked at stage transitions for consistent identity within a stage.
struct VoiceParameters: Codable {
    /// Stage these parameters were calculated for.
    let stage: String

    /// Pitch shift in semitones (positive = higher).
    let pitchSemitones: Double

    /// Rate multiplier (1.0 = normal, <1 = slower, >1 = faster).
    let rateMultiplier: Double

    /// Intonation range — pitch variation during speech.
    /// 0.0 = flat monotone, 2.0 = expressive.
    let intonationRange: Double

    /// Warmth EQ boost in dB at 200-400Hz.
    let warmthBoostDB: Double

    /// Default parameters for a neutral personality.
    static let neutral = VoiceParameters(
        stage: "critter",
        pitchSemitones: 6.0,
        rateMultiplier: 1.0,
        intonationRange: 1.0,
        warmthBoostDB: 3.0
    )
}

// MARK: - Voice Personality Calculator

/// Calculates voice parameters from personality axes.
/// DETERMINISTIC: same personality + same stage = same parameters.
enum VoicePersonalityCalculator {

    /// Calculate voice parameters for a personality snapshot at a given stage.
    /// - Parameters:
    ///   - personality: The creature's personality axes.
    ///   - stage: The growth stage to calculate for.
    /// - Returns: Voice parameters for this personality+stage combination.
    static func calculate(
        personality: PersonalitySnapshot,
        stage: GrowthStage
    ) -> VoiceParameters {
        guard let tier = VoiceTier.forStage(stage) else {
            return .neutral  // Spore is silent
        }

        let pitch = calculatePitch(
            energy: personality.energy, tier: tier
        )
        let rate = calculateRate(
            energy: personality.energy, tier: tier
        )
        let intonation = calculateIntonation(
            verbosity: personality.verbosity
        )
        let warmth = calculateWarmth(stage: stage)

        return VoiceParameters(
            stage: "\(stage)",
            pitchSemitones: pitch,
            rateMultiplier: rate,
            intonationRange: intonation,
            warmthBoostDB: warmth
        )
    }

    // MARK: - Pitch

    /// Calculate pitch shift based on energy axis and tier.
    /// Low energy: lower pitch. High energy: higher pitch.
    private static func calculatePitch(
        energy: Double, tier: VoiceTier
    ) -> Double {
        let basePitch: Double
        switch tier {
        case .babble:   basePitch = 8.0  // Drop: very high
        case .emerging: basePitch = 6.0  // Critter: high
        case .speaking: basePitch = 5.5  // Beast+: moderate
        }

        // Energy modifies pitch: low = -1, high = +1.5
        let energyOffset: Double
        if energy < 0.3 {
            energyOffset = -1.0
        } else if energy > 0.7 {
            energyOffset = 1.5
        } else {
            energyOffset = (energy - 0.5) * 3.0  // Linear in middle range
        }

        return basePitch + energyOffset
    }

    // MARK: - Rate

    /// Calculate speaking rate based on energy axis.
    /// Low energy: slower (0.8x). High energy: faster (1.2x).
    private static func calculateRate(
        energy: Double, tier: VoiceTier
    ) -> Double {
        let baseRate: Double
        switch tier {
        case .babble:   baseRate = 0.5   // Drop: half speed
        case .emerging: baseRate = 0.85  // Critter: slightly slow
        case .speaking: baseRate = 1.0   // Beast+: normal
        }

        // Energy modifies rate
        let energyModifier: Double
        if energy < 0.3 {
            energyModifier = 0.8
        } else if energy > 0.7 {
            energyModifier = 1.2
        } else {
            energyModifier = 0.8 + (energy - 0.3) * (0.4 / 0.4)
        }

        return baseRate * energyModifier
    }

    // MARK: - Intonation

    /// Calculate intonation range from verbosity axis.
    /// Low verbosity: flat, minimal variation.
    /// High verbosity: expressive, wide pitch variation.
    private static func calculateIntonation(
        verbosity: Double
    ) -> Double {
        if verbosity < 0.3 {
            return 0.3  // Flat
        } else if verbosity > 0.7 {
            return 2.0  // Very expressive
        } else {
            // Linear interpolation
            return 0.3 + (verbosity - 0.3) * (1.7 / 0.4)
        }
    }

    // MARK: - Warmth

    /// Warmth EQ boost. Higher at Beast+ for clear speech.
    private static func calculateWarmth(
        stage: GrowthStage
    ) -> Double {
        switch stage {
        case .spore, .drop: return 0.0   // No EQ for chirps
        case .critter:      return 2.0
        case .beast:        return 3.0
        case .sage:         return 3.5   // Warmer, deeper
        case .apex:         return 4.0   // Maximum warmth
        }
    }

    // MARK: - Style Modifiers

    /// Apply style-specific volume and effect modifiers.
    static func volumeForStyle(_ style: SpeechStyle) -> Float {
        switch style {
        case .say:     return 0.6
        case .exclaim: return 0.8    // +3dB
        case .whisper: return 0.3    // -6dB
        case .dream:   return 0.24   // 0.4x of normal
        case .sing:    return 0.6    // Normal, pitch varies
        case .think:   return 0.0    // No audio for thoughts
        case .narrate: return 0.5    // Slightly quieter
        }
    }

    /// Whether a style produces audio at all.
    static func styleProducesAudio(_ style: SpeechStyle) -> Bool {
        return style != .think
    }

    // MARK: - Dream Audio Modifiers

    /// Dream-specific audio modifiers applied on top of normal voice.
    struct DreamModifiers {
        /// Additional pitch shift (semitones, negative = lower).
        static let pitchShift: Double = -3.0
        /// Rate modifier (slower).
        static let rateModifier: Double = 0.7
        /// Reverb wet percentage.
        static let reverbWet: Double = 0.4
    }
}
