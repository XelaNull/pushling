// SoundSystem.swift — Programmatic ambient sound synthesis
// Uses AVAudioEngine with generated PCM buffers for 7 sound types:
// chime, purr, meow, wind, rain, crickets, music_box.
// Separate engine from TTS AudioPlayer — no conflicts.
// Looping sounds use seamless buffer repetition.
// Sound generators are in SoundGenerators.swift (extension).

import AVFoundation

// MARK: - Sound Types

/// The 7 ambient sound types specified in the vision doc.
enum SoundType: String, CaseIterable {
    case chime      // Gentle bell/chime — one-shot
    case purr       // Cat purring — looping
    case meow       // Cat meow — one-shot
    case wind       // Wind ambience — looping
    case rain       // Rain loop — looping
    case crickets   // Cricket chirps — looping
    case music_box  // Music box melody — one-shot (long)

    /// Whether this sound type loops continuously.
    var isLooping: Bool {
        switch self {
        case .chime, .meow, .music_box: return false
        case .purr, .wind, .rain, .crickets: return true
        }
    }
}

/// Actions for sound control.
enum SoundAction: String {
    case play
    case stop
}

// MARK: - Sound System

/// Synthesizes and plays ambient sounds programmatically via AVAudioEngine.
/// Thread-safe: all public methods can be called from any queue.
/// Uses a dedicated engine separate from the TTS AudioPlayer.
final class SoundSystem {

    // MARK: - Constants

    /// Sample rate for all generated audio.
    static let sampleRate: Double = 44100.0

    /// Master volume for ambient sounds (subtle, not loud).
    private static let masterVolume: Float = 0.15

    // MARK: - Engine

    private var engine: AVAudioEngine?
    private var mixer: AVAudioMixerNode?
    let format: AVAudioFormat

    // MARK: - Active Players

    /// One player node per active sound type.
    private var activePlayers: [SoundType: AVAudioPlayerNode] = [:]

    /// Track which sounds are currently playing.
    private var playingTypes: Set<SoundType> = []

    // MARK: - Pre-generated Buffers

    /// Cached buffers for each sound type.
    private var bufferCache: [SoundType: AVAudioPCMBuffer] = [:]

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - State

    /// Whether the sound engine is running.
    private(set) var isRunning: Bool = false

    /// Whether all sound is muted. When true, play() calls are silently ignored.
    var isMuted: Bool = false

    /// Whether any sound is currently playing.
    var isPlaying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !playingTypes.isEmpty
    }

    /// Which sounds are currently active.
    var activeSounds: Set<SoundType> {
        lock.lock()
        defer { lock.unlock() }
        return playingTypes
    }

    // MARK: - Initialization

    init() {
        self.format = AVAudioFormat(
            standardFormatWithSampleRate: Self.sampleRate,
            channels: 1
        )!
    }

    // MARK: - Setup

    /// Start the audio engine. Call once during app/world setup.
    /// Returns true on success.
    @discardableResult
    func setup() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return true }

        let newEngine = AVAudioEngine()
        let newMixer = AVAudioMixerNode()

        newEngine.attach(newMixer)
        newEngine.connect(newMixer, to: newEngine.mainMixerNode, format: format)
        newMixer.outputVolume = Self.masterVolume

        engine = newEngine
        mixer = newMixer

        do {
            try newEngine.start()
            isRunning = true
            NSLog("[Pushling/Sound] Engine started — sampleRate=%.0f",
                  Self.sampleRate)
            return true
        } catch {
            NSLog("[Pushling/Sound] Engine start failed: %@",
                  error.localizedDescription)
            engine = nil
            mixer = nil
            return false
        }
    }

    // MARK: - Play / Stop

    /// Play an ambient sound. If already playing (looping), does nothing.
    /// For one-shot sounds, re-triggers from the beginning.
    func play(_ type: SoundType, action: SoundAction = .play) {
        guard !isMuted || action == .stop else { return }
        switch action {
        case .play:
            startSound(type)
        case .stop:
            stopSound(type)
        }
    }

    /// Stop a specific sound type.
    func stop(_ type: SoundType) {
        stopSound(type)
    }

    /// Stop all currently playing sounds.
    func stopAll() {
        lock.lock()
        let types = Array(playingTypes)
        lock.unlock()

        for type in types {
            stopSound(type)
        }
    }

    // MARK: - Internal Play/Stop

    private func startSound(_ type: SoundType) {
        lock.lock()

        guard isRunning, let eng = engine, let mix = mixer else {
            lock.unlock()
            return
        }

        // If looping and already playing, skip
        if type.isLooping && playingTypes.contains(type) {
            lock.unlock()
            return
        }

        // If one-shot and already playing, stop the old one first
        if !type.isLooping, let existing = activePlayers[type] {
            existing.stop()
            eng.detach(existing)
            activePlayers.removeValue(forKey: type)
        }

        lock.unlock()

        // Get or generate the buffer (outside lock — synthesis can take time)
        let buffer = getOrGenerateBuffer(for: type)

        lock.lock()
        guard isRunning, let eng2 = engine else {
            lock.unlock()
            return
        }

        let player = AVAudioPlayerNode()
        eng2.attach(player)
        eng2.connect(player, to: mix, format: format)

        activePlayers[type] = player
        playingTypes.insert(type)

        if type.isLooping {
            player.scheduleBuffer(buffer, at: nil,
                                  options: .loops, completionHandler: nil)
        } else {
            player.scheduleBuffer(buffer, at: nil, options: []) {
                [weak self] in
                DispatchQueue.main.async {
                    self?.onOneShotComplete(type)
                }
            }
        }

        player.volume = volumeFor(type)
        player.play()
        lock.unlock()

        NSLog("[Pushling/Sound] Playing: %@ (looping: %@)",
              type.rawValue, type.isLooping ? "yes" : "no")
    }

    private func stopSound(_ type: SoundType) {
        lock.lock()
        guard let player = activePlayers[type], let eng = engine else {
            lock.unlock()
            return
        }
        lock.unlock()

        // Fade out over 2 seconds for looping sounds, instant for one-shots
        if type.isLooping {
            let fadeDuration = 2.0
            let steps = 40  // 40 volume steps over 2 seconds
            let interval = fadeDuration / Double(steps)
            let startVolume = player.volume

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                for step in 1...steps {
                    let fraction = Float(step) / Float(steps)
                    let vol = startVolume * (1.0 - fraction)
                    DispatchQueue.main.async { player.volume = vol }
                    Thread.sleep(forTimeInterval: interval)
                }
                // Now actually stop and detach
                DispatchQueue.main.async {
                    player.stop()
                    self?.lock.lock()
                    if let eng = self?.engine { eng.detach(player) }
                    self?.activePlayers.removeValue(forKey: type)
                    self?.playingTypes.remove(type)
                    self?.lock.unlock()
                    NSLog("[Pushling/Sound] Faded out: %@", type.rawValue)
                }
            }
        } else {
            player.stop()
            lock.lock()
            eng.detach(player)
            activePlayers.removeValue(forKey: type)
            playingTypes.remove(type)
            lock.unlock()
            NSLog("[Pushling/Sound] Stopped: %@", type.rawValue)
        }
    }

    private func onOneShotComplete(_ type: SoundType) {
        lock.lock()
        if let player = activePlayers[type], let eng = engine {
            eng.detach(player)
        }
        activePlayers.removeValue(forKey: type)
        playingTypes.remove(type)
        lock.unlock()
    }

    /// Per-type volume scaling (relative to master).
    private func volumeFor(_ type: SoundType) -> Float {
        switch type {
        case .chime:     return 0.8
        case .purr:      return 0.6
        case .meow:      return 0.7
        case .wind:      return 0.5
        case .rain:      return 0.4
        case .crickets:  return 0.3
        case .music_box: return 0.6
        }
    }

    // MARK: - Buffer Generation

    private func getOrGenerateBuffer(for type: SoundType) -> AVAudioPCMBuffer {
        lock.lock()
        if let cached = bufferCache[type] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let buffer = generateBuffer(for: type)

        lock.lock()
        bufferCache[type] = buffer
        lock.unlock()

        return buffer
    }

    /// Generate a PCM buffer for the given sound type.
    /// Dispatches to the per-type generator in SoundGenerators.swift.
    func generateBuffer(for type: SoundType) -> AVAudioPCMBuffer {
        let samples: [Float]
        switch type {
        case .chime:     samples = generateChime()
        case .purr:      samples = generatePurr()
        case .meow:      samples = generateMeow()
        case .wind:      samples = generateWind()
        case .rain:      samples = generateRain()
        case .crickets:  samples = generateCrickets()
        case .music_box: samples = generateMusicBox()
        }

        let frameCount = AVAudioFrameCount(samples.count)
        let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                       frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if let data = buffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                data[i] = samples[i]
            }
        }

        return buffer
    }

    // MARK: - Teardown

    /// Stop all sounds and tear down the audio engine.
    func teardown() {
        stopAll()

        lock.lock()
        engine?.stop()
        engine = nil
        mixer = nil
        isRunning = false
        bufferCache.removeAll()
        lock.unlock()

        NSLog("[Pushling/Sound] Engine torn down")
    }
}
