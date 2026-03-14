// AudioPlayer.swift — AVAudioEngine playback with effects chain
// Pipeline: PlayerNode -> TimePitch -> EQ -> Reverb -> MainMixer
// Non-blocking: never touches SpriteKit's render loop.
// Includes WAV cache for recently generated audio segments.

import AVFoundation

// MARK: - Playback Request

/// Describes how to play a piece of generated audio.
struct PlaybackRequest {
    let audio: GeneratedAudio
    let voiceParams: VoiceParameters
    let style: SpeechStyle
    let isDream: Bool
    let volume: Float

    /// Effective pitch in cents (100 cents = 1 semitone).
    var pitchCents: Float {
        var base = Float(voiceParams.pitchSemitones) * 100.0
        if isDream {
            base += Float(VoicePersonalityCalculator.DreamModifiers.pitchShift)
                * 100.0
        }
        return base
    }

    /// Effective playback rate.
    var effectiveRate: Float {
        var rate = Float(voiceParams.rateMultiplier)
        if isDream {
            rate *= Float(VoicePersonalityCalculator.DreamModifiers.rateModifier)
        }
        return max(0.25, min(4.0, rate))  // AVAudioUnitTimePitch limits
    }

    /// Reverb wet/dry percentage (0-100).
    var reverbWet: Float {
        if isDream {
            return Float(
                VoicePersonalityCalculator.DreamModifiers.reverbWet * 100.0
            )
        }
        switch style {
        case .whisper: return 20.0
        case .sing:    return 15.0
        default:       return 0.0
        }
    }
}

// MARK: - Audio Player

/// Manages AVAudioEngine pipeline for TTS playback.
/// Thread-safe: can be called from any queue. Playback scheduling
/// happens internally on the audio render thread.
final class AudioPlayer {

    // MARK: - Engine Components

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var pitchNode: AVAudioUnitTimePitch?
    private var eqNode: AVAudioUnitEQ?
    private var reverbNode: AVAudioUnitReverb?

    // MARK: - State

    /// Whether the audio engine is running.
    private(set) var isRunning: Bool = false

    /// Whether audio is currently playing.
    private(set) var isPlaying: Bool = false

    /// Playback completion callback (called on main thread).
    var onPlaybackComplete: (() -> Void)?

    // MARK: - Configuration

    /// Output audio format: mono float32 at the model's sample rate.
    private var outputFormat: AVAudioFormat?

    /// Standard format for the engine's internal processing.
    private static let processingRate: Double = 24000.0

    // MARK: - Cache

    /// Directory for cached WAV segments.
    private let cacheDirectory: String

    /// Maximum cache size in bytes (50MB).
    private static let maxCacheBytes: Int = 50 * 1024 * 1024

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Initialization

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.cacheDirectory = "\(home)/.local/share/pushling/voice/cache"
    }

    // MARK: - Setup

    /// Set up the AVAudioEngine with the full effects chain.
    /// Call once during voice system initialization.
    func setup(sampleRate: Double = AudioPlayer.processingRate) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // Tear down existing engine
        teardownEngine()

        let newEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()
        let eq = AVAudioUnitEQ(numberOfBands: 3)
        let reverb = AVAudioUnitReverb()

        // EQ: high-pass 100Hz (remove rumble), boost 300Hz (warmth), cut 4kHz
        eq.bands[0].filterType = .highPass; eq.bands[0].frequency = 100
        eq.bands[0].bandwidth = 1.0; eq.bands[0].bypass = false
        eq.bands[1].filterType = .parametric; eq.bands[1].frequency = 300
        eq.bands[1].bandwidth = 1.0; eq.bands[1].gain = 3.0
        eq.bands[1].bypass = false
        eq.bands[2].filterType = .parametric; eq.bands[2].frequency = 4000
        eq.bands[2].bandwidth = 1.0; eq.bands[2].gain = -2.0
        eq.bands[2].bypass = false

        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 0   // Dry default, enabled per-request
        pitch.pitch = 600      // +6 semitones default
        pitch.rate = 1.0

        // Attach nodes
        newEngine.attach(player)
        newEngine.attach(pitch)
        newEngine.attach(eq)
        newEngine.attach(reverb)

        // Create processing format
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            NSLog("[Pushling/Voice/Audio] Failed to create audio format")
            return false
        }
        outputFormat = format

        // Connect chain: player -> pitch -> eq -> reverb -> mainMixer
        newEngine.connect(player, to: pitch, format: format)
        newEngine.connect(pitch, to: eq, format: format)
        newEngine.connect(eq, to: reverb, format: format)
        newEngine.connect(reverb, to: newEngine.mainMixerNode, format: format)

        // Store references
        engine = newEngine
        playerNode = player
        pitchNode = pitch
        eqNode = eq
        reverbNode = reverb

        // Start engine
        do {
            try newEngine.start()
            isRunning = true
            NSLog("[Pushling/Voice/Audio] Engine started: sampleRate=%.0f",
                  sampleRate)
            return true
        } catch {
            NSLog("[Pushling/Voice/Audio] Engine start failed: %@",
                  error.localizedDescription)
            teardownEngine()
            return false
        }
    }

    // MARK: - Playback

    /// Play generated audio with the specified effects.
    /// Non-blocking: schedules playback and returns immediately.
    ///
    /// - Parameters:
    ///   - request: The playback request with audio and effect parameters.
    ///   - completion: Called on main thread when playback finishes.
    func play(request: PlaybackRequest,
              completion: (() -> Void)? = nil) {
        lock.lock()
        guard isRunning,
              let player = playerNode,
              let pitchUnit = pitchNode,
              let eqUnit = eqNode,
              let reverbUnit = reverbNode,
              !request.audio.isEmpty else {
            lock.unlock()
            DispatchQueue.main.async { completion?() }
            return
        }
        lock.unlock()

        // Stop any current playback
        if isPlaying {
            player.stop()
        }

        // Configure effects for this request
        configureEffects(
            request: request,
            pitch: pitchUnit,
            eq: eqUnit,
            reverb: reverbUnit
        )

        // Create audio buffer from samples
        let sampleRate = Double(request.audio.sampleRate)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            DispatchQueue.main.async { completion?() }
            return
        }

        let frameCount = AVAudioFrameCount(request.audio.samples.count)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: frameCount
        ) else {
            DispatchQueue.main.async { completion?() }
            return
        }

        buffer.frameLength = frameCount

        // Copy samples into buffer, applying volume
        if let channelData = buffer.floatChannelData?[0] {
            let volume = request.volume
            for i in 0..<Int(frameCount) {
                channelData[i] = request.audio.samples[i] * volume
            }
        }

        // Reconnect with correct format if sample rate changed
        if sampleRate != (outputFormat?.sampleRate ?? 0) {
            reconnectChain(format: format)
            outputFormat = format
        }

        // Schedule and play
        isPlaying = true
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                completion?()
                self?.onPlaybackComplete?()
            }
        }
        player.play()
    }

    /// Stop any currently playing audio immediately.
    func stop() {
        playerNode?.stop()
        isPlaying = false
    }

    // MARK: - Effects Configuration

    /// Configure the effects chain for a specific playback request.
    private func configureEffects(
        request: PlaybackRequest,
        pitch: AVAudioUnitTimePitch,
        eq: AVAudioUnitEQ,
        reverb: AVAudioUnitReverb
    ) {
        // Pitch shift (in cents: 100 cents = 1 semitone)
        pitch.pitch = request.pitchCents
        pitch.rate = request.effectiveRate

        // EQ warmth boost (band 1)
        eq.bands[1].gain = Float(request.voiceParams.warmthBoostDB)

        // Reverb wet/dry
        reverb.wetDryMix = request.reverbWet
    }

    /// Reconnect the audio chain with a new format.
    private func reconnectChain(format: AVAudioFormat) {
        guard let eng = engine,
              let player = playerNode,
              let pitch = pitchNode,
              let eq = eqNode,
              let reverb = reverbNode else { return }

        eng.disconnectNodeOutput(player)
        eng.disconnectNodeOutput(pitch)
        eng.disconnectNodeOutput(eq)
        eng.disconnectNodeOutput(reverb)

        eng.connect(player, to: pitch, format: format)
        eng.connect(pitch, to: eq, format: format)
        eng.connect(eq, to: reverb, format: format)
        eng.connect(reverb, to: eng.mainMixerNode, format: format)
    }

    // MARK: - Cache Operations

    /// Save generated audio to the cache directory.
    /// Returns the file path on success, nil on failure.
    func cacheAudio(
        _ audio: GeneratedAudio, key: String
    ) -> String? {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory) {
            try? fm.createDirectory(
                atPath: cacheDirectory,
                withIntermediateDirectories: true
            )
        }

        let filePath = "\(cacheDirectory)/\(key).wav"

        // Write WAV file
        guard writeWAV(
            samples: audio.samples,
            sampleRate: audio.sampleRate,
            to: filePath
        ) else {
            return nil
        }

        return filePath
    }

    /// Load cached audio from disk.
    func loadCachedAudio(key: String) -> GeneratedAudio? {
        let filePath = "\(cacheDirectory)/\(key).wav"
        return readWAV(from: filePath)
    }

    /// Check if a cached segment exists.
    func hasCachedAudio(key: String) -> Bool {
        let filePath = "\(cacheDirectory)/\(key).wav"
        return FileManager.default.fileExists(atPath: filePath)
    }

    /// Evict cache entries exceeding the size limit (oldest first).
    func evictCacheIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: cacheDirectory)
            .filter({ $0.hasSuffix(".wav") }) else { return }

        // Calculate total size
        var entries: [(path: String, size: Int, modified: Date)] = []
        for file in files {
            let path = "\(cacheDirectory)/\(file)"
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let size = attrs[.size] as? Int,
                  let modified = attrs[.modificationDate] as? Date else {
                continue
            }
            entries.append((path, size, modified))
        }

        let totalSize = entries.reduce(0) { $0 + $1.size }
        guard totalSize > Self.maxCacheBytes else { return }

        // Sort by modification date (oldest first) and delete
        let sorted = entries.sorted { $0.modified < $1.modified }
        var freed = 0
        let target = totalSize - Self.maxCacheBytes
        for entry in sorted {
            try? fm.removeItem(atPath: entry.path)
            freed += entry.size
            if freed >= target { break }
        }

        NSLog("[Pushling/Voice/Audio] Cache evicted %d bytes", freed)
    }

    // MARK: - WAV I/O

    /// Write PCM float samples as 16-bit mono WAV.
    private func writeWAV(
        samples: [Float], sampleRate: Int32, to path: String
    ) -> Bool {
        let n = Int32(samples.count), dataSize = n * 2, fileSize = 36 + dataSize
        var d = Data(capacity: Int(44 + dataSize))
        d.append(contentsOf: "RIFF".utf8); d.append(littleEndian: fileSize)
        d.append(contentsOf: "WAVE".utf8)
        d.append(contentsOf: "fmt ".utf8); d.append(littleEndian: Int32(16))
        d.append(littleEndian: Int16(1)); d.append(littleEndian: Int16(1))
        d.append(littleEndian: sampleRate); d.append(littleEndian: sampleRate * 2)
        d.append(littleEndian: Int16(2)); d.append(littleEndian: Int16(16))
        d.append(contentsOf: "data".utf8); d.append(littleEndian: dataSize)
        for s in samples {
            d.append(littleEndian: Int16(max(-1, min(1, s)) * 32767))
        }
        do {
            try d.write(to: URL(fileURLWithPath: path)); return true
        } catch {
            NSLog("[Pushling/Voice/Audio] WAV write failed: %@",
                  error.localizedDescription)
            return false
        }
    }

    /// Read a 16-bit mono WAV file and return float samples.
    private func readWAV(from path: String) -> GeneratedAudio? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              data.count > 44 else { return nil }
        let sr = data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: Int32.self) }
        let ds = data.withUnsafeBytes { $0.load(fromByteOffset: 40, as: Int32.self) }
        let n = Int(ds) / 2
        guard n > 0, data.count >= 44 + Int(ds) else { return nil }
        var samples = [Float](repeating: 0, count: n)
        data.withUnsafeBytes { ptr in
            let base = ptr.baseAddress!.advanced(by: 44)
            for i in 0..<n {
                let v = base.advanced(by: i * 2).assumingMemoryBound(to: Int16.self).pointee
                samples[i] = Float(v) / 32767.0
            }
        }
        return GeneratedAudio(samples: samples, sampleRate: sr)
    }

    // MARK: - Teardown

    /// Tear down the audio engine and release resources.
    func teardown() {
        lock.lock()
        defer { lock.unlock() }
        teardownEngine()
    }

    private func teardownEngine() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        pitchNode = nil
        eqNode = nil
        reverbNode = nil
        isRunning = false
        isPlaying = false
    }
}

// MARK: - Data Extension for Little-Endian Writing

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { self.append(contentsOf: $0) }
    }
}
