// VoiceIntegration.swift — Wires VoiceSystem into SpeechCoordinator
// When a speech bubble appears, this layer also generates and plays audio.
//
// Stage-gated behavior:
//   Spore  = silent (no text, no audio)
//   Drop   = espeak-ng babble (chirps, phonemes, rhythm matches text)
//   Critter = Piper babble-to-speech (emerging words, 20-80% real)
//   Beast+ = Kokoro clear speech (the surprise moment)
//
// Personality influence on voice:
//   Energy:    high = faster rate, wider pitch variance
//              low  = slower rate, steadier pitch
//   Verbosity: high = expressive intonation
//              low  = flat, minimal variation
//   Focus:     affects articulation precision (subtle)
//   Discipline: affects cadence regularity (subtle)
//
// The first word ceremony is coordinated here: when Beast stage is
// reached for the first time, the creature whispers the developer's
// first name. The VoiceIntegration watches for this and triggers
// the audio alongside the visual ceremony.

import Foundation

// MARK: - Voice Integration

/// Bridges the SpeechCoordinator (visual bubbles) with the VoiceSystem
/// (audio TTS). When speech happens visually, this layer decides whether
/// and how to produce audio.
final class VoiceIntegration {

    // MARK: - Dependencies

    private let voiceSystem: VoiceSystem
    private weak var speechCoordinator: SpeechCoordinator?

    // MARK: - State

    /// Current growth stage (determines audio behavior).
    private(set) var currentStage: GrowthStage = .egg

    /// Current personality snapshot.
    private var personality: PersonalitySnapshot = .neutral

    /// Whether audio has been generated for the current speech.
    private var audioInFlight: Bool = false

    /// Cooldown to prevent rapid-fire audio (min 500ms between utterances).
    private var audioCooldown: TimeInterval = 0
    private static let minAudioInterval: TimeInterval = 0.5

    /// Track commits eaten for Critter speech ratio.
    private(set) var commitsEaten: Int = 0

    // MARK: - First Word Tracking

    /// Whether we're monitoring for the first word ceremony.
    private var awaitingFirstWord: Bool = false

    /// Callback when the first audible word is spoken.
    var onFirstAudibleWord: ((_ name: String) -> Void)?

    // MARK: - Initialization

    init(voiceSystem: VoiceSystem) {
        self.voiceSystem = voiceSystem
    }

    /// Wire up to the speech coordinator.
    func attach(to coordinator: SpeechCoordinator) {
        self.speechCoordinator = coordinator
    }

    // MARK: - Configuration

    /// Configure with current creature state.
    func configure(stage: GrowthStage,
                    personality: PersonalitySnapshot,
                    commitsEaten: Int) {
        self.currentStage = stage
        self.personality = personality
        self.commitsEaten = commitsEaten

        // Check if we should be watching for first word
        if stage >= .beast && !voiceSystem.hasSpokenFirstWord {
            awaitingFirstWord = true
        }
    }

    // MARK: - Speech Event Handler

    /// Called when the SpeechCoordinator processes a speech request.
    /// Determines whether to generate audio and with what parameters.
    ///
    /// - Parameters:
    ///   - text: The text being displayed in the speech bubble.
    ///   - style: The speech style (say, whisper, dream, etc.).
    ///   - stage: The creature's current growth stage.
    ///   - source: The source of the utterance (AI, autonomous).
    func onSpeech(text: String,
                   style: SpeechStyle,
                   stage: GrowthStage,
                   source: UtteranceSource) {
        // Guard: audio cooldown
        guard audioCooldown <= 0 else { return }

        // Guard: system enabled
        guard voiceSystem.isEnabled else { return }

        // Guard: not already generating
        guard !audioInFlight else { return }

        // Guard: style produces audio
        guard VoicePersonalityCalculator.styleProducesAudio(style) else {
            return
        }

        // Stage-gated behavior
        switch stage {
        case .egg:
            // Silent — no audio
            return

        case .drop:
            // Babble — the VoiceSystem handles babble generation internally
            generateAndPlay(
                text: text, style: style, isDream: style == .dream
            )

        case .critter:
            // Emerging words — probabilistic real vs babble
            generateAndPlay(
                text: text, style: style, isDream: style == .dream
            )

        case .beast, .sage, .apex:
            // Clear speech
            generateAndPlay(
                text: text, style: style, isDream: style == .dream
            )
        }
    }

    /// Generate and play audio for a speech event.
    private func generateAndPlay(text: String,
                                   style: SpeechStyle,
                                   isDream: Bool) {
        audioInFlight = true
        audioCooldown = Self.minAudioInterval

        let config = VoiceConfig(
            text: text,
            style: style,
            parameters: voiceSystem.voiceParams,
            isDream: isDream
        )

        voiceSystem.generate(config: config) { [weak self] success in
            self?.audioInFlight = false
            if success {
                NSLog("[Pushling/Voice/Integration] Audio played for: '%@'",
                      text.prefix(30) + (text.count > 30 ? "..." : ""))
            }
        }
    }

    // MARK: - Stage Transition

    /// Handle a growth stage change.
    func onStageChanged(to stage: GrowthStage,
                          personality: PersonalitySnapshot) {
        let oldStage = currentStage
        currentStage = stage
        self.personality = personality

        // Notify voice system of stage change
        voiceSystem.onStageChanged(to: stage, personality: personality)

        // Check for first word ceremony trigger
        if oldStage < .beast && stage >= .beast {
            triggerFirstWordCeremony()
        }

        // Pre-render common phrases for the new stage
        let creatureName = voiceSystem.developerFirstName ?? "Pushling"
        voiceSystem.prerenderCommonPhrases(
            stage: stage, creatureName: creatureName
        )

        NSLog("[Pushling/Voice/Integration] Stage changed: %@ -> %@",
              "\(oldStage)", "\(stage)")
    }

    // MARK: - First Word Ceremony

    /// Trigger the first audible word ceremony.
    /// The creature whispers the developer's first name.
    private func triggerFirstWordCeremony() {
        guard awaitingFirstWord else { return }
        awaitingFirstWord = false

        // Small delay to let the visual ceremony start first
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.voiceSystem.speakFirstWord { [weak self] success in
                if success {
                    let name = self?.voiceSystem.developerFirstName ?? ""
                    NSLog("[Pushling/Voice/Integration] FIRST AUDIBLE WORD: "
                          + "'%@' — the creature has found its voice", name)
                    self?.onFirstAudibleWord?(name)
                }
            }
        }
    }

    // MARK: - Dream Speech

    /// Generate dream mumble audio during sleep.
    func onDreamBubble(text: String) {
        guard voiceSystem.isEnabled else { return }
        voiceSystem.generateDreamAudio(text: text) { success in
            if success {
                NSLog("[Pushling/Voice/Integration] Dream audio: '%@'",
                      text.prefix(20) + "...")
            }
        }
    }

    // MARK: - Per-Frame Update

    /// Update cooldown timer. Called every frame.
    func update(deltaTime: TimeInterval) {
        if audioCooldown > 0 {
            audioCooldown -= deltaTime
        }
    }

    // MARK: - Commit Tracking

    /// Update the commit count (affects Critter speech ratio).
    func onCommitEaten() {
        commitsEaten += 1
    }

    // MARK: - Personality Influence

    /// Apply personality-driven modifications to a speech event.
    /// Called before generating audio to adjust timing and emphasis.
    func personalityModifiers(
        for style: SpeechStyle
    ) -> (rateMultiplier: Double, pitchOffset: Double) {
        var rate = 1.0
        var pitch = 0.0

        // Energy affects tempo
        if personality.energy > 0.7 {
            rate = 1.15   // Energetic: slightly faster
            pitch = 0.5   // Slightly higher pitch when excited
        } else if personality.energy < 0.3 {
            rate = 0.85   // Calm: slightly slower
            pitch = -0.3  // Slightly lower, steadier
        }

        // Verbosity affects expressiveness (pitch variation)
        if personality.verbosity > 0.7 {
            pitch += 0.3  // More expressive
        } else if personality.verbosity < 0.3 {
            pitch -= 0.2  // Flatter
        }

        // Style-specific overrides
        switch style {
        case .exclaim:
            rate *= 1.1
            pitch += 1.0
        case .whisper:
            rate *= 0.9
            pitch -= 0.5
        case .dream:
            rate *= 0.7
            pitch -= 2.0
        case .sing:
            rate *= 0.95
            pitch += 0.5
        default:
            break
        }

        return (rate, pitch)
    }

    // MARK: - Status

    /// Whether voice integration is actively producing audio.
    var isActive: Bool {
        return voiceSystem.isEnabled && currentStage >= .drop
    }

    /// Status report for diagnostics.
    func statusReport() -> String {
        var lines: [String] = ["[Voice Integration Status]"]
        lines.append("Stage: \(currentStage)")
        lines.append("Active: \(isActive)")
        lines.append("Audio in flight: \(audioInFlight)")
        lines.append("Cooldown: \(String(format: "%.2f", audioCooldown))s")
        lines.append("Commits eaten: \(commitsEaten)")
        if currentStage == .critter {
            let ratio = VoiceSystem.critterSpeechRatio(
                commitsEaten: commitsEaten
            )
            lines.append("Speech ratio: \(String(format: "%.0f", ratio * 100))%")
        }
        lines.append("Awaiting first word: \(awaitingFirstWord)")
        lines.append("")
        lines.append(voiceSystem.statusReport())
        return lines.joined(separator: "\n")
    }

    // MARK: - Shutdown

    /// Shut down the voice integration and underlying system.
    func shutdown() {
        voiceSystem.shutdown()
    }
}
