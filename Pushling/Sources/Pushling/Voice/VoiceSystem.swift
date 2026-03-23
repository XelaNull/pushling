// VoiceSystem.swift — TTS voice system: generation, caching, playback
// Wires ModelManager -> SherpaOnnxBridge -> AudioPlayer.
// All generation on a dedicated serial queue. Graceful degradation:
// no models = no audio = text bubbles only (the voice hasn't emerged).

import Foundation
import AVFoundation

// MARK: - Voice Config

/// Configuration for a single TTS generation request.
struct VoiceConfig {
    let text: String
    let style: SpeechStyle
    let parameters: VoiceParameters
    let isDream: Bool

    init(text: String,
         style: SpeechStyle = .say,
         parameters: VoiceParameters = .neutral,
         isDream: Bool = false) {
        self.text = text
        self.style = style
        self.parameters = parameters
        self.isDream = isDream
    }
}

// MARK: - Cached Segment

/// A pre-rendered TTS audio segment stored on disk.
struct CachedSegment {
    let text: String
    let filePath: String
    let voiceParamsHash: String
    let stage: String
    let generatedAt: Date
}

// MARK: - Voice System

/// Manages TTS generation, caching, and playback for the Pushling creature.
/// All TTS work runs off the main thread on a dedicated serial queue.
final class VoiceSystem {

    // MARK: - Configuration

    /// Base directory for cached voice segments.
    private let cacheDirectory: String

    /// Maximum cache size in bytes (50MB).
    private static let maxCacheSize: Int = 50 * 1024 * 1024

    // MARK: - State

    /// Current TTS tier.
    private(set) var currentTier: VoiceTier?

    /// Whether TTS generation is currently in progress.
    private(set) var isGenerating = false

    /// Current voice parameters (locked at stage transition).
    private(set) var voiceParams: VoiceParameters = .neutral

    /// Whether the voice system is enabled and ready.
    private(set) var isEnabled = false

    /// Whether the first audible word ceremony has been performed.
    private(set) var hasSpokenFirstWord = false

    /// The developer's first name (from git user.name), for the ceremony.
    private(set) var developerFirstName: String?

    // MARK: - Subsystems

    private let modelManager = ModelManager()
    private let bridge = SherpaOnnxBridge()
    let audioPlayer = AudioPlayer()

    // MARK: - Threading

    private let voiceQueue = DispatchQueue(
        label: "com.pushling.voice.generation", qos: .userInitiated
    )
    private var requestQueue: [VoiceConfig] = []
    private static let maxQueueDepth = 3

    // MARK: - Babble State (Drop stage)

    /// Phoneme pool for espeak-ng babble generation.
    private static let babblePhonemes = [
        "buh", "dah", "gah", "puh", "mah", "nuh",
        "tah", "kah", "wah", "yah", "lah", "fuh",
        "sah", "hah", "ruh", "zuh", "cha", "juh",
        "ee", "oo", "ah", "oh", "ih",
    ]

    /// Generate babble text for Drop stage.
    private func generateBabbleText() -> String {
        let count = Int.random(in: 1...3)
        var phonemes: [String] = []
        for _ in 0..<count {
            phonemes.append(
                Self.babblePhonemes.randomElement() ?? "buh"
            )
        }
        // Occasionally add punctuation for rhythm
        if Bool.random() {
            phonemes[phonemes.count - 1] += "!"
        } else if Int.random(in: 0...3) == 0 {
            phonemes[phonemes.count - 1] += "..."
        }
        return phonemes.joined(separator: " ")
    }

    // MARK: - Initialization

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.cacheDirectory = "\(home)/.local/share/pushling/voice"
    }

    /// Initialize the voice system.
    /// Call after the creature's stage and personality are known.
    func initialize(stage: GrowthStage,
                     personality: PersonalitySnapshot) {
        currentTier = VoiceTier.forStage(stage)
        voiceParams = VoicePersonalityCalculator.calculate(
            personality: personality, stage: stage
        )

        // Create cache directory
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory) {
            try? fm.createDirectory(
                atPath: cacheDirectory,
                withIntermediateDirectories: true
            )
        }

        // Extract developer's first name for the ceremony
        developerFirstName = extractDeveloperFirstName()

        // Scan for available models
        modelManager.ensureDirectories()
        modelManager.scanModels()

        // Attempt to load the appropriate model
        voiceQueue.async { [weak self] in
            self?.loadModelForCurrentTier()
        }
    }

    /// Load the model appropriate for the current tier. Called on voiceQueue.
    private func loadModelForCurrentTier() {
        guard let tier = currentTier,
              let bestTier = modelManager.bestAvailableTier(
                  for: stageForTier(tier)),
              let config = modelManager.sherpaConfig(for: bestTier) else {
            NSLog("[Pushling/Voice] No usable model — voice disabled")
            DispatchQueue.main.async { [weak self] in self?.isEnabled = false }
            return
        }

        let modelOK = bridge.loadModel(config: config, tier: bestTier)
        let sr = modelOK ? Double(bridge.sampleRate) : 0
        let audioOK = modelOK ? audioPlayer.setup(
            sampleRate: sr > 0 ? sr : 24000.0
        ) : false

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isEnabled = modelOK && audioOK
            self.currentTier = modelOK ? bestTier : self.currentTier
            NSLog("[Pushling/Voice] %@: tier=%@, sampleRate=%.0f",
                  self.isEnabled ? "Ready" : "Disabled",
                  bestTier.rawValue, sr)
        }
    }

    /// Map a VoiceTier back to a representative GrowthStage for model lookup.
    private func stageForTier(_ tier: VoiceTier) -> GrowthStage {
        switch tier {
        case .babble:   return .drop
        case .emerging: return .critter
        case .speaking: return .beast
        }
    }

    // MARK: - Stage Transition

    /// Handle a stage transition — recalculate voice parameters, switch tier.
    func onStageChanged(to stage: GrowthStage,
                          personality: PersonalitySnapshot) {
        let newTier = VoiceTier.forStage(stage)
        let oldTier = currentTier

        // Recalculate voice parameters (locked for this stage)
        voiceParams = VoicePersonalityCalculator.calculate(
            personality: personality, stage: stage
        )

        // Switch tier if needed
        if newTier != oldTier {
            currentTier = newTier

            // Reload model on background queue
            voiceQueue.async { [weak self] in
                guard let self = self else { return }

                // Unload old model to free memory
                self.bridge.unloadModel()

                // Load new model
                self.loadModelForCurrentTier()
            }

            NSLog("[Pushling/Voice] Tier changed: %@ -> %@",
                  oldTier?.rawValue ?? "none",
                  newTier?.rawValue ?? "none")
        }

        // Clear cache (voice params changed)
        clearCache()
    }

    // MARK: - Generate (Async, Off Main Thread)

    /// Generate TTS audio for text. Non-blocking — returns immediately.
    func generate(config: VoiceConfig,
                    completion: @escaping (Bool) -> Void) {
        guard isEnabled, currentTier != nil,
              VoicePersonalityCalculator.styleProducesAudio(config.style) else {
            completion(false); return
        }

        let cacheKey = cacheKeyFor(text: config.text, params: voiceParams)

        // Cache hit — play immediately
        if audioPlayer.hasCachedAudio(key: cacheKey) {
            voiceQueue.async { [weak self] in
                guard let self = self,
                      let cached = self.audioPlayer.loadCachedAudio(key: cacheKey)
                else { DispatchQueue.main.async { completion(false) }; return }
                self.playAudio(cached, config: config, completion: completion)
            }
            return
        }

        // Queue management (max 3, drop oldest)
        if requestQueue.count >= Self.maxQueueDepth { requestQueue.removeFirst() }
        requestQueue.append(config)

        isGenerating = true
        voiceQueue.async { [weak self] in
            guard let self = self else { return }

            // Stage-dependent text: babble, mix, or verbatim
            let text: String
            switch self.currentTier {
            case .babble:   text = self.generateBabbleText()
            case .emerging: text = self.critterSpeechMix(originalText: config.text)
            default:        text = config.text
            }

            guard let audio = self.bridge.generate(
                text: text, speakerId: 0,
                speed: Float(self.voiceParams.rateMultiplier)
            ) else {
                DispatchQueue.main.async { [weak self] in
                    self?.isGenerating = false
                    self?.requestQueue.removeAll { $0.text == config.text }
                    completion(false)
                }; return
            }

            _ = self.audioPlayer.cacheAudio(audio, key: cacheKey)
            self.playAudio(audio, config: config, completion: completion)
        }
    }

    /// Play generated audio with the appropriate effects.
    private func playAudio(
        _ audio: GeneratedAudio,
        config: VoiceConfig,
        completion: @escaping (Bool) -> Void
    ) {
        let volume = VoicePersonalityCalculator.volumeForStyle(config.style)

        let request = PlaybackRequest(
            audio: audio,
            voiceParams: voiceParams,
            style: config.style,
            isDream: config.isDream,
            volume: volume
        )

        audioPlayer.play(request: request) { [weak self] in
            self?.isGenerating = false
            self?.requestQueue.removeAll { $0.text == config.text }
            completion(true)
        }
    }

    // MARK: - Critter Speech Mix

    /// Commits eaten, set from GameCoordinator for Critter speech ratio.
    var commitsEaten: Int = 0

    /// Mix real words with babble for the Critter stage.
    /// Early Critter: mostly babble. Late Critter: mostly words.
    private func critterSpeechMix(originalText: String) -> String {
        let ratio = Self.critterSpeechRatio(commitsEaten: commitsEaten)

        let words = originalText.split(separator: " ").map { String($0) }
        guard !words.isEmpty else { return generateBabbleText() }

        var result: [String] = []
        for word in words {
            let roll = Double.random(in: 0...1)
            if roll < ratio {
                result.append(word)
            } else {
                result.append(Self.babblePhonemes.randomElement() ?? "buh")
            }
        }

        return result.joined(separator: " ")
    }

    /// Pre-render common phrases during idle time.
    func prerenderCommonPhrases(stage: GrowthStage, creatureName: String) {
        guard isEnabled else { return }

        let phrases: [String]
        switch stage {
        case .critter:
            phrases = ["morning!", "sleepy...", "yum!", "more!", creatureName]
        case .beast:
            phrases = [
                "good morning!", "sleepy...", "yum!", "that was good",
                creatureName, "MORNING!", "pretty!", "STRONG"
            ]
        case .sage:
            phrases = ["good morning.", "I remember this.", "interesting.",
                       "let me think...", creatureName, "well done.",
                       "that was elegant.", "careful here."]
        case .apex:
            phrases = ["good morning, friend.", "I see what you're doing.",
                       "beautiful work.", creatureName, "shall we begin?",
                       "this reminds me of something.", "together."]
        default:
            phrases = []
        }

        for phrase in phrases {
            let config = VoiceConfig(
                text: phrase, style: .say, parameters: voiceParams
            )
            generate(config: config) { _ in }
        }
    }

    // MARK: - First Audible Word Ceremony

    /// The developer's first name, whispered at 0.7x volume. THE moment.
    func speakFirstWord(completion: @escaping (Bool) -> Void) {
        guard isEnabled, !hasSpokenFirstWord,
              currentTier == .speaking,
              let name = developerFirstName else {
            completion(false); return
        }
        hasSpokenFirstWord = true

        voiceQueue.async { [weak self] in
            guard let self = self,
                  let audio = self.bridge.generate(
                      text: name, speakerId: 0,
                      speed: Float(self.voiceParams.rateMultiplier) * 0.8
                  ) else {
                DispatchQueue.main.async { [weak self] in
                    self?.hasSpokenFirstWord = false  // Allow retry
                    completion(false)
                }; return
            }
            // Whisper at 0.7x volume (vision spec: 0.3 base * 0.7)
            let req = PlaybackRequest(
                audio: audio, voiceParams: self.voiceParams,
                style: .whisper, isDream: false, volume: 0.21
            )
            self.audioPlayer.play(request: req) {
                NSLog("[Pushling/Voice] FIRST WORD SPOKEN: '%@'", name)
                completion(true)
            }
        }
    }

    /// Extract developer's first name from `git config user.name`.
    private func extractDeveloperFirstName() -> String? {
        let proc = Process(); let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        proc.arguments = ["config", "user.name"]
        proc.standardOutput = pipe; proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let name = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.split(separator: " ").first.map { String($0) }
    }

    // MARK: - Dream Audio

    /// Generate dream mumble audio: sleep-talk at 0.4x volume,
    /// pitch shifted down, stretched, reverbed.
    func generateDreamAudio(
        text: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard isEnabled else {
            completion(false)
            return
        }

        let config = VoiceConfig(
            text: text,
            style: .dream,
            parameters: voiceParams,
            isDream: true
        )

        generate(config: config, completion: completion)
    }

    // MARK: - Cache Management

    private func cacheKeyFor(text: String,
                               params: VoiceParameters) -> String {
        let textHash = Self.deterministicHash(text)
        let paramsStr = "\(params.pitchSemitones)_\(params.rateMultiplier)"
        let paramsHash = Self.deterministicHash(paramsStr)
        return "\(params.stage)_\(textHash)_\(paramsHash)"
    }

    /// FNV-1a hash producing a deterministic UInt64 from a string.
    /// Unlike Swift's hashValue, this is stable across process launches.
    private static func deterministicHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037  // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211  // FNV prime
        }
        return hash
    }

    private func clearCache() {
        let cachePath = "\(cacheDirectory)/cache"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: cachePath) else { return }
        for file in files where file.hasSuffix(".wav") {
            try? FileManager.default.removeItem(atPath: "\(cachePath)/\(file)")
        }
        NSLog("[Pushling/Voice] Cache cleared")
    }

    // MARK: - Status

    /// Generate a diagnostic status report.
    func statusReport() -> String {
        let tier = currentTier?.rawValue ?? "none"
        return """
        [Voice System] enabled=\(isEnabled) tier=\(tier) \
        native=\(bridge.isNativeAvailable) model=\(bridge.isModelLoaded) \
        audio=\(audioPlayer.isRunning) sr=\(bridge.sampleRate) \
        firstWord=\(hasSpokenFirstWord) name=\(developerFirstName ?? "?")
        \(modelManager.statusReport())
        """
    }

    // MARK: - Shutdown

    /// Shut down the voice system, releasing all resources.
    func shutdown() {
        isEnabled = false
        bridge.shutdown()
        audioPlayer.teardown()
        NSLog("[Pushling/Voice] System shutdown")
    }

    // MARK: - Critter Babble-to-Speech Ratio

    /// Calculate the ratio of real speech to babble for Critter stage.
    /// Early Critter: 20-30% real speech. Late Critter: 80%.
    /// Formula: (commitsEaten - 75) / 124.0, clamped to 0.2-0.8
    static func critterSpeechRatio(commitsEaten: Int) -> Double {
        let ratio = Double(commitsEaten - 75) / 124.0
        return max(0.2, min(0.8, ratio))
    }
}
