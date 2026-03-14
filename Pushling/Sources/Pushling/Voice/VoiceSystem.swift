// VoiceSystem.swift — TTS voice system interface and tier management
// Provides the architecture for 3-tier TTS (espeak-ng, Piper, Kokoro).
// Async generation off main thread. Stage-gated tier selection.
//
// STUB: Actual TTS generation calls are marked with TODO comments.
// Full implementation requires bundling sherpa-onnx runtime + TTS models.
//
// Threading: All TTS generation runs on a dedicated serial dispatch queue.
// Never touches the main thread. Results delivered via callback.

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

    /// Whether the voice system is enabled.
    private(set) var isEnabled = false

    // MARK: - Threading

    /// Dedicated serial queue for TTS generation.
    private let voiceQueue = DispatchQueue(
        label: "com.pushling.voice.generation",
        qos: .userInitiated
    )

    /// Speech request queue (max depth: 3, drops oldest).
    private var requestQueue: [VoiceConfig] = []
    private static let maxQueueDepth = 3

    // MARK: - Audio Engine

    // TODO: Integrate AVAudioEngine pipeline
    // private var audioEngine: AVAudioEngine?
    // private var playerNode: AVAudioPlayerNode?
    // private var pitchNode: AVAudioUnitTimePitch?
    // private var eqNode: AVAudioUnitEQ?
    // private var reverbNode: AVAudioUnitReverb?

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

        // TODO: Integrate sherpa-onnx runtime
        // loadModel(tier: currentTier)
        // setupAudioEngine()

        isEnabled = false  // Disabled until TTS models are bundled

        NSLog("[Pushling/Voice] Initialized: tier=%@, pitch=%.1f, rate=%.2f"
              + " (STUBBED — waiting for sherpa-onnx)",
              currentTier?.rawValue ?? "none",
              voiceParams.pitchSemitones,
              voiceParams.rateMultiplier)
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
            // TODO: Integrate sherpa-onnx runtime
            // Unload old model, load new model
            // loadModel(tier: newTier)

            NSLog("[Pushling/Voice] Tier changed: %@ -> %@",
                  oldTier?.rawValue ?? "none",
                  newTier?.rawValue ?? "none")
        }

        // Clear cache (voice params changed)
        clearCache()
    }

    // MARK: - Generate (Async, Off Main Thread)

    /// Generate TTS audio for text. Non-blocking — returns immediately.
    /// Result is delivered via the completion callback on the main thread.
    func generate(config: VoiceConfig,
                    completion: @escaping (Bool) -> Void) {
        guard isEnabled, currentTier != nil else {
            completion(false)
            return
        }

        guard VoicePersonalityCalculator.styleProducesAudio(config.style) else {
            completion(false)
            return
        }

        // Check cache first
        let cacheKey = cacheKeyFor(text: config.text, params: voiceParams)
        if hasCachedSegment(key: cacheKey) {
            // Cache hit — play immediately
            // TODO: Play cached audio
            // playCachedSegment(key: cacheKey, style: config.style)
            DispatchQueue.main.async { completion(true) }
            return
        }

        // Queue the request
        if requestQueue.count >= Self.maxQueueDepth {
            requestQueue.removeFirst()  // Drop oldest
        }
        requestQueue.append(config)

        // Dispatch to voice queue
        isGenerating = true
        voiceQueue.async { [weak self] in
            guard let self = self else { return }

            // TODO: Integrate sherpa-onnx runtime
            // let buffer = self.sherpaOnnx.generate(
            //     text: config.text,
            //     pitch: self.voiceParams.pitchSemitones,
            //     rate: self.voiceParams.rateMultiplier
            // )

            // Simulate generation time
            // Thread.sleep(forTimeInterval: 0.15)

            // TODO: Apply audio pipeline
            // self.applyPipeline(buffer, config: config)

            // TODO: Cache the result
            // self.cacheSegment(buffer, key: cacheKey)

            // TODO: Schedule playback
            // self.schedulePlayback(buffer, config: config)

            DispatchQueue.main.async { [weak self] in
                self?.isGenerating = false
                self?.requestQueue.removeAll { $0.text == config.text }
                completion(false)  // false until TTS is integrated
            }
        }
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

    // MARK: - Cache Management

    private func cacheKeyFor(text: String,
                               params: VoiceParameters) -> String {
        let textHash = abs(text.hashValue)
        let paramsHash = abs("\(params.pitchSemitones)_\(params.rateMultiplier)"
                               .hashValue)
        return "\(params.stage)_\(textHash)_\(paramsHash)"
    }

    private func hasCachedSegment(key: String) -> Bool {
        let path = "\(cacheDirectory)/\(key).wav"
        return FileManager.default.fileExists(atPath: path)
    }

    private func clearCache() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            atPath: cacheDirectory
        ) else { return }

        for file in files where file.hasSuffix(".wav") {
            try? fm.removeItem(atPath: "\(cacheDirectory)/\(file)")
        }

        NSLog("[Pushling/Voice] Cache cleared")
    }

    // MARK: - Audio Pipeline Setup (Stubbed)

    // TODO: Integrate AVAudioEngine pipeline
    //
    // private func setupAudioEngine() {
    //     audioEngine = AVAudioEngine()
    //     playerNode = AVAudioPlayerNode()
    //     pitchNode = AVAudioUnitTimePitch()
    //     eqNode = AVAudioUnitEQ(numberOfBands: 2)
    //     reverbNode = AVAudioUnitReverb()
    //
    //     // Configure EQ: warmth boost at 200-400Hz
    //     if let eq = eqNode {
    //         eq.bands[0].filterType = .parametric
    //         eq.bands[0].frequency = 300
    //         eq.bands[0].bandwidth = 1.0
    //         eq.bands[0].gain = Float(voiceParams.warmthBoostDB)
    //         eq.bands[0].bypass = false
    //
    //         // Cut harshness at 4kHz
    //         eq.bands[1].filterType = .parametric
    //         eq.bands[1].frequency = 4000
    //         eq.bands[1].bandwidth = 1.0
    //         eq.bands[1].gain = -2.0
    //         eq.bands[1].bypass = false
    //     }
    //
    //     // Configure pitch
    //     pitchNode?.pitch = Float(voiceParams.pitchSemitones * 100)
    //     pitchNode?.rate = Float(voiceParams.rateMultiplier)
    //
    //     // Configure reverb (only for dream/whisper)
    //     reverbNode?.loadFactoryPreset(.smallRoom)
    //     reverbNode?.wetDryMix = 0  // Default off
    //
    //     // Connect nodes
    //     guard let engine = audioEngine,
    //           let player = playerNode,
    //           let pitch = pitchNode,
    //           let eq = eqNode,
    //           let reverb = reverbNode else { return }
    //
    //     engine.attach(player)
    //     engine.attach(pitch)
    //     engine.attach(eq)
    //     engine.attach(reverb)
    //
    //     engine.connect(player, to: pitch, format: nil)
    //     engine.connect(pitch, to: eq, format: nil)
    //     engine.connect(eq, to: reverb, format: nil)
    //     engine.connect(reverb, to: engine.mainMixerNode, format: nil)
    //
    //     // Use ambient category (doesn't interrupt music)
    //     try? AVAudioSession.sharedInstance().setCategory(.ambient)
    //     try? engine.start()
    // }

    // MARK: - Model Loading (Stubbed)

    // TODO: Integrate sherpa-onnx runtime
    //
    // private func loadModel(tier: VoiceTier?) {
    //     guard let tier = tier else { return }
    //     voiceQueue.async {
    //         switch tier {
    //         case .babble:
    //             // Load espeak-ng formant data (~2MB)
    //             // self.sherpaOnnx.loadEspeakModel()
    //             break
    //         case .emerging:
    //             // Load Piper TTS low-quality (~16MB)
    //             // self.sherpaOnnx.loadPiperModel()
    //             break
    //         case .speaking:
    //             // Load Kokoro-82M ONNX q8 (~80MB)
    //             // Lazy load: only when Beast stage reached
    //             // self.sherpaOnnx.loadKokoroModel()
    //             break
    //         }
    //         NSLog("[Pushling/Voice] Model loaded: %@", tier.rawValue)
    //     }
    // }

    // MARK: - Critter Babble-to-Speech Ratio

    /// Calculate the ratio of real speech to babble for Critter stage.
    /// Early Critter: 20-30% real speech. Late Critter: 80%.
    /// Formula: (commitsEaten - 75) / 124.0, clamped to 0.2-0.8
    static func critterSpeechRatio(commitsEaten: Int) -> Double {
        let ratio = Double(commitsEaten - 75) / 124.0
        return max(0.2, min(0.8, ratio))
    }
}
