// SherpaOnnxBridge.swift — Swift bridge to sherpa-onnx C API for TTS
// Wraps the sherpa-onnx offline TTS C functions in a Swift-friendly API.
// Supports 3 model tiers: espeak-ng (babble), Piper VITS (emerging),
// Kokoro-82M (speaking). Each tier has different config paths.
//
// The C library is conditionally imported: if CSherpaOnnx module is not
// available, the bridge operates in stub mode (all generation returns nil).
// This allows the app to compile and run without the native library linked.
//
// Threading: All calls to the C API happen on the caller's thread.
// The VoiceSystem is responsible for dispatching to a background queue.

import Foundation

// MARK: - C API Types

/// Opaque handle to an offline TTS instance.
typealias SherpaOnnxOfflineTtsHandle = OpaquePointer

// MARK: - Configuration Structs

/// Mirror of SherpaOnnxOfflineTtsVitsModelConfig (Piper/espeak-ng).
struct SherpaVitsConfig {
    var model: String = ""
    var lexicon: String = ""
    var tokens: String = ""
    var dataDir: String = ""
    var noiseScale: Float = 0.667
    var noiseScaleW: Float = 0.8
    var lengthScale: Float = 1.0
    var dictDir: String = ""
}

/// Mirror of SherpaOnnxOfflineTtsKokoroModelConfig (Kokoro-82M).
struct SherpaKokoroConfig {
    var model: String = ""
    var voices: String = ""
    var tokens: String = ""
    var dataDir: String = ""
    var lengthScale: Float = 1.0
    var dictDir: String = ""
    var lexicon: String = ""
    var lang: String = "en"
}

/// Combined TTS config that routes to the appropriate model type.
struct SherpaTtsConfig {
    var vits: SherpaVitsConfig = SherpaVitsConfig()
    var kokoro: SherpaKokoroConfig = SherpaKokoroConfig()
    var numThreads: Int32 = 2
    var debug: Bool = false
    var provider: String = "cpu"
    var maxNumSentences: Int32 = 1
    var silenceScale: Float = 1.0
}

// MARK: - Generated Audio Result

/// Audio samples returned from TTS generation.
struct GeneratedAudio {
    /// Raw PCM float samples, normalized to [-1.0, 1.0].
    let samples: [Float]
    /// Sample rate in Hz (typically 22050 or 24000).
    let sampleRate: Int32

    /// Duration in seconds.
    var duration: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }

    /// Whether this contains any audio data.
    var isEmpty: Bool { samples.isEmpty }
}

// MARK: - Sherpa-ONNX TTS Bridge

/// Swift bridge to the sherpa-onnx offline TTS C API.
/// If the native library is not linked, all operations gracefully
/// return nil/false — the creature simply has no voice yet.
final class SherpaOnnxBridge {

    // MARK: - State

    /// Whether the native library was successfully loaded.
    private(set) var isNativeAvailable: Bool = false

    /// Whether a model is currently loaded and ready for generation.
    private(set) var isModelLoaded: Bool = false

    /// The sample rate of the currently loaded model.
    private(set) var sampleRate: Int32 = 0

    /// Number of speakers in the currently loaded model.
    private(set) var numSpeakers: Int32 = 0

    /// The active TTS tier.
    private(set) var activeTier: VoiceTier?

    // MARK: - Native Handles

    /// Opaque pointer to the sherpa-onnx TTS instance.
    private var ttsHandle: SherpaOnnxOfflineTtsHandle?

    /// Dynamic library handle for sherpa-onnx.
    private var libraryHandle: UnsafeMutableRawPointer?

    // MARK: - Function Pointers (resolved at runtime)

    private var fn_create: (
        @convention(c) (UnsafeRawPointer) -> SherpaOnnxOfflineTtsHandle?
    )?
    private var fn_destroy: (
        @convention(c) (SherpaOnnxOfflineTtsHandle) -> Void
    )?
    private var fn_generate: (
        @convention(c) (
            SherpaOnnxOfflineTtsHandle, UnsafePointer<CChar>,
            Int32, Float
        ) -> UnsafeRawPointer?
    )?
    private var fn_sampleRate: (
        @convention(c) (SherpaOnnxOfflineTtsHandle) -> Int32
    )?
    private var fn_numSpeakers: (
        @convention(c) (SherpaOnnxOfflineTtsHandle) -> Int32
    )?
    private var fn_destroyAudio: (
        @convention(c) (UnsafeRawPointer) -> Void
    )?

    // MARK: - Initialization

    init() {
        loadNativeLibrary()
    }

    deinit {
        shutdown()
        if let lib = libraryHandle {
            dlclose(lib)
        }
    }

    // MARK: - Native Library Loading

    /// Attempt to load the sherpa-onnx dynamic library.
    /// Searches: bundle frameworks, /usr/local/lib, Homebrew paths.
    private func loadNativeLibrary() {
        let searchPaths = [
            // App bundle
            Bundle.main.privateFrameworksPath.map {
                "\($0)/sherpa-onnx.framework/sherpa-onnx"
            },
            Bundle.main.privateFrameworksPath.map {
                "\($0)/libsherpa-onnx-c-api.dylib"
            },
            // Standard install locations
            Optional("/usr/local/lib/libsherpa-onnx-c-api.dylib"),
            Optional("/opt/homebrew/lib/libsherpa-onnx-c-api.dylib"),
            // Adjacent to app
            Bundle.main.bundlePath + "/../Frameworks/libsherpa-onnx-c-api.dylib",
        ].compactMap { $0 }

        for path in searchPaths {
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                libraryHandle = handle
                break
            }
        }

        // Also try without path (system library search)
        if libraryHandle == nil {
            libraryHandle = dlopen("libsherpa-onnx-c-api.dylib", RTLD_LAZY)
        }

        guard let lib = libraryHandle else {
            NSLog("[Pushling/Voice/Bridge] sherpa-onnx native library not found"
                  + " — voice system will operate in silent mode")
            isNativeAvailable = false
            return
        }

        // Resolve function pointers
        fn_create = resolveSymbol(lib, "SherpaOnnxCreateOfflineTts")
        fn_destroy = resolveSymbol(lib, "SherpaOnnxDestroyOfflineTts")
        fn_generate = resolveSymbol(lib, "SherpaOnnxOfflineTtsGenerate")
        fn_sampleRate = resolveSymbol(lib, "SherpaOnnxOfflineTtsSampleRate")
        fn_numSpeakers = resolveSymbol(lib, "SherpaOnnxOfflineTtsNumSpeakers")
        fn_destroyAudio = resolveSymbol(
            lib, "SherpaOnnxDestroyOfflineTtsGeneratedAudio"
        )

        let allResolved = fn_create != nil && fn_destroy != nil
            && fn_generate != nil && fn_sampleRate != nil
            && fn_numSpeakers != nil && fn_destroyAudio != nil

        if allResolved {
            isNativeAvailable = true
            NSLog("[Pushling/Voice/Bridge] sherpa-onnx native library loaded")
        } else {
            isNativeAvailable = false
            NSLog("[Pushling/Voice/Bridge] sherpa-onnx symbols incomplete"
                  + " — some functions could not be resolved")
        }
    }

    /// Resolve a C function symbol from a dynamic library handle.
    private func resolveSymbol<T>(
        _ lib: UnsafeMutableRawPointer, _ name: String
    ) -> T? {
        guard let sym = dlsym(lib, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    // MARK: - Model Loading

    /// Load a TTS model with the given configuration.
    /// This must be called on a background thread — model loading can take
    /// several hundred milliseconds.
    ///
    /// - Parameters:
    ///   - config: The TTS configuration specifying model paths.
    ///   - tier: The voice tier being loaded.
    /// - Returns: true if the model loaded successfully.
    @discardableResult
    func loadModel(config: SherpaTtsConfig, tier: VoiceTier) -> Bool {
        guard isNativeAvailable else {
            NSLog("[Pushling/Voice/Bridge] Cannot load model — native library"
                  + " not available")
            return false
        }

        // Unload any existing model
        unloadModel()

        // Build the C config struct in memory and call create
        let success = withSherpaCConfig(config) { cConfigPtr in
            guard let handle = fn_create?(cConfigPtr) else {
                return false
            }
            ttsHandle = handle
            return true
        }

        guard success, let handle = ttsHandle else {
            NSLog("[Pushling/Voice/Bridge] Failed to create TTS for tier: %@",
                  tier.rawValue)
            return false
        }

        sampleRate = fn_sampleRate?(handle) ?? 0
        numSpeakers = fn_numSpeakers?(handle) ?? 0
        activeTier = tier
        isModelLoaded = true

        NSLog("[Pushling/Voice/Bridge] Model loaded: tier=%@, sampleRate=%d,"
              + " speakers=%d",
              tier.rawValue, sampleRate, numSpeakers)
        return true
    }

    /// Unload the current model, freeing memory.
    func unloadModel() {
        if let handle = ttsHandle {
            fn_destroy?(handle)
            ttsHandle = nil
        }
        isModelLoaded = false
        activeTier = nil
        sampleRate = 0
        numSpeakers = 0
    }

    // MARK: - Audio Generation

    /// Generate audio from text.
    /// This is a synchronous operation — call from a background thread.
    ///
    /// - Parameters:
    ///   - text: The text to synthesize.
    ///   - speakerId: Speaker ID for multi-speaker models (0 for single).
    ///   - speed: Speed multiplier (1.0 = normal, <1 = slower, >1 = faster).
    /// - Returns: Generated audio samples, or nil on failure.
    func generate(
        text: String, speakerId: Int32 = 0, speed: Float = 1.0
    ) -> GeneratedAudio? {
        guard isNativeAvailable, isModelLoaded,
              let handle = ttsHandle,
              let generateFn = fn_generate,
              let destroyAudioFn = fn_destroyAudio else {
            return nil
        }

        guard !text.isEmpty else { return nil }

        let audioPtr = text.withCString { cText -> UnsafeRawPointer? in
            return generateFn(handle, cText, speakerId, speed)
        }

        guard let ptr = audioPtr else {
            NSLog("[Pushling/Voice/Bridge] Generation returned nil for: %@",
                  text)
            return nil
        }

        // The returned pointer points to a SherpaOnnxGeneratedAudio struct:
        //   struct { const float *samples; int32_t n; int32_t sample_rate; }
        // Extract the fields by reading memory at known offsets.
        let samplesPtr = ptr.load(as: UnsafePointer<Float>?.self)
        let nSamples = ptr.load(
            fromByteOffset: MemoryLayout<UnsafePointer<Float>?>.stride,
            as: Int32.self
        )
        let sr = ptr.load(
            fromByteOffset: MemoryLayout<UnsafePointer<Float>?>.stride
                + MemoryLayout<Int32>.stride,
            as: Int32.self
        )

        var result: GeneratedAudio?
        if let samples = samplesPtr, nSamples > 0 {
            let buffer = Array(
                UnsafeBufferPointer(start: samples, count: Int(nSamples))
            )
            result = GeneratedAudio(samples: buffer, sampleRate: sr)
        }

        // Free the C-allocated audio
        destroyAudioFn(ptr)

        return result
    }

    // MARK: - Shutdown

    /// Shut down the bridge, unloading all models.
    func shutdown() {
        unloadModel()
        NSLog("[Pushling/Voice/Bridge] Shutdown complete")
    }

    // MARK: - Config Builder (C struct marshalling)

    /// Build the sherpa-onnx C config struct and pass to a closure.
    /// Collects all strings, converts to C strings with lifetime management,
    /// then populates the packed C struct.
    private func withSherpaCConfig(
        _ config: SherpaTtsConfig,
        body: (UnsafeRawPointer) -> Bool
    ) -> Bool {
        // Collect all string fields into an array for batch conversion.
        // Order matches COfflineTtsConfig field layout.
        let strings = [
            config.vits.model, config.vits.lexicon, config.vits.tokens,
            config.vits.dataDir, config.vits.dictDir,
            config.kokoro.model, config.kokoro.voices, config.kokoro.tokens,
            config.kokoro.dataDir, config.kokoro.dictDir,
            config.kokoro.lexicon, config.kokoro.lang,
            config.provider, "", "", ""  // empty, ruleFsts, ruleFars
        ]

        // Convert all strings to null-terminated C buffers
        let cStrings = strings.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }

        // Build packed C struct
        var c = COfflineTtsConfig()
        c.vits_model = UnsafePointer(cStrings[0])
        c.vits_lexicon = UnsafePointer(cStrings[1])
        c.vits_tokens = UnsafePointer(cStrings[2])
        c.vits_data_dir = UnsafePointer(cStrings[3])
        c.vits_noise_scale = config.vits.noiseScale
        c.vits_noise_scale_w = config.vits.noiseScaleW
        c.vits_length_scale = config.vits.lengthScale
        c.vits_dict_dir = UnsafePointer(cStrings[4])
        c.num_threads = config.numThreads
        c.debug = config.debug ? 1 : 0
        c.provider = UnsafePointer(cStrings[12])
        // Matcha (zeroed)
        let empty = UnsafePointer(cStrings[13])
        c.matcha_acoustic = empty; c.matcha_vocoder = empty
        c.matcha_lexicon = empty; c.matcha_tokens = empty
        c.matcha_data_dir = empty; c.matcha_dict_dir = empty
        // Kokoro
        c.kokoro_model = UnsafePointer(cStrings[5])
        c.kokoro_voices = UnsafePointer(cStrings[6])
        c.kokoro_tokens = UnsafePointer(cStrings[7])
        c.kokoro_data_dir = UnsafePointer(cStrings[8])
        c.kokoro_length_scale = config.kokoro.lengthScale
        c.kokoro_dict_dir = UnsafePointer(cStrings[9])
        c.kokoro_lexicon = UnsafePointer(cStrings[10])
        c.kokoro_lang = UnsafePointer(cStrings[11])
        // Kitten (zeroed)
        c.kitten_model = empty; c.kitten_voices = empty
        c.kitten_tokens = empty; c.kitten_data_dir = empty
        // Top-level
        c.rule_fsts = UnsafePointer(cStrings[14])
        c.max_num_sentences = config.maxNumSentences
        c.rule_fars = UnsafePointer(cStrings[15])
        c.silence_scale = config.silenceScale

        return withUnsafePointer(to: &c) { body(UnsafeRawPointer($0)) }
    }

    // MARK: - Tier-Specific Config Builders

    /// Build a SherpaTtsConfig for espeak-ng babble (Drop stage).
    static func espeakConfig(modelDir: String) -> SherpaTtsConfig {
        var config = SherpaTtsConfig()
        config.vits.model = "\(modelDir)/espeak-ng/model.onnx"
        config.vits.tokens = "\(modelDir)/espeak-ng/tokens.txt"
        config.vits.dataDir = "\(modelDir)/espeak-ng/espeak-ng-data"
        config.vits.noiseScale = 0.667
        config.vits.noiseScaleW = 0.8
        config.vits.lengthScale = 2.0  // Slow for creature babble
        config.numThreads = 1          // Lightweight model
        return config
    }

    /// Build a SherpaTtsConfig for Piper VITS (Critter stage).
    static func piperConfig(modelDir: String) -> SherpaTtsConfig {
        var config = SherpaTtsConfig()
        config.vits.model = "\(modelDir)/piper/en_US-amy-low.onnx"
        config.vits.tokens = "\(modelDir)/piper/tokens.txt"
        config.vits.dataDir = "\(modelDir)/piper/espeak-ng-data"
        config.vits.lexicon = ""
        config.vits.noiseScale = 0.667
        config.vits.noiseScaleW = 0.8
        config.vits.lengthScale = 1.0
        config.numThreads = 2
        return config
    }

    /// Build a SherpaTtsConfig for Kokoro-82M (Beast+ stages).
    static func kokoroConfig(modelDir: String) -> SherpaTtsConfig {
        var config = SherpaTtsConfig()
        config.kokoro.model = "\(modelDir)/kokoro/model.onnx"
        config.kokoro.voices = "\(modelDir)/kokoro/voices.bin"
        config.kokoro.tokens = "\(modelDir)/kokoro/tokens.txt"
        config.kokoro.dataDir = "\(modelDir)/kokoro/espeak-ng-data"
        config.kokoro.lengthScale = 1.0
        config.kokoro.lang = "en"
        config.numThreads = 2
        return config
    }
}

// MARK: - C Config Struct (packed layout matching sherpa-onnx c-api.h)

/// Packed C struct matching SherpaOnnxOfflineTtsConfig. Transient use only.
private struct COfflineTtsConfig {
    // VITS model config
    var vits_model, vits_lexicon, vits_tokens, vits_data_dir: UnsafePointer<CChar>?
    var vits_noise_scale: Float = 0, vits_noise_scale_w: Float = 0
    var vits_length_scale: Float = 0
    var vits_dict_dir: UnsafePointer<CChar>?
    // Model-level
    var num_threads: Int32 = 2, debug: Int32 = 0
    var provider: UnsafePointer<CChar>?
    // Matcha model config (unused, zeroed)
    var matcha_acoustic, matcha_vocoder, matcha_lexicon: UnsafePointer<CChar>?
    var matcha_tokens, matcha_data_dir: UnsafePointer<CChar>?
    var matcha_noise_scale: Float = 0, matcha_length_scale: Float = 0
    var matcha_dict_dir: UnsafePointer<CChar>?
    // Kokoro model config
    var kokoro_model, kokoro_voices, kokoro_tokens: UnsafePointer<CChar>?
    var kokoro_data_dir: UnsafePointer<CChar>?
    var kokoro_length_scale: Float = 0
    var kokoro_dict_dir, kokoro_lexicon, kokoro_lang: UnsafePointer<CChar>?
    // Kitten model config (unused, zeroed)
    var kitten_model, kitten_voices, kitten_tokens: UnsafePointer<CChar>?
    var kitten_data_dir: UnsafePointer<CChar>?
    var kitten_length_scale: Float = 0
    // Top-level config
    var rule_fsts: UnsafePointer<CChar>?
    var max_num_sentences: Int32 = 1
    var rule_fars: UnsafePointer<CChar>?
    var silence_scale: Float = 1.0
}
