// SoundGenerators.swift — Programmatic audio synthesis for 7 sound types
// Extension on SoundSystem. Each generator returns Float sample arrays.
// Synthesis techniques: sine waves, filtered noise, LFO modulation,
// amplitude envelopes, and frequency sweeps. No audio files needed.

import Foundation

// MARK: - Sound Generators

extension SoundSystem {

    /// Chime: sine wave with harmonics and exponential decay (0.8s).
    func generateChime() -> [Float] {
        let sr = Self.sampleRate
        let duration = 0.8
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        let fundamentals: [(freq: Double, amp: Double)] = [
            (523.25, 0.5),  // C5
            (659.25, 0.35), // E5
            (783.99, 0.25), // G5
            (1046.5, 0.15), // C6
        ]

        for i in 0..<count {
            let t = Double(i) / sr
            let decay = Float(exp(-t * 5.0))
            var sample: Float = 0

            for h in fundamentals {
                sample += Float(h.amp) * sin(Float(2.0 * .pi * h.freq * t))
            }

            out[i] = sample * decay
        }

        return out
    }

    /// Purr: low-frequency rumble with amplitude modulation (2s loop).
    func generatePurr() -> [Float] {
        let sr = Self.sampleRate
        let duration = 2.0
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        // Purr = filtered noise with 25Hz AM envelope
        var noiseState: UInt32 = 12345
        let amFreq = 25.0
        let baseFreq = 35.0

        for i in 0..<count {
            let t = Double(i) / sr

            // Simple LCG noise
            noiseState = noiseState &* 1103515245 &+ 12345
            let noise = Float(noiseState) / Float(UInt32.max) * 2.0 - 1.0

            // Low-pass via simple IIR (one-pole)
            let cutoff = Float(baseFreq * 2.0 / sr)
            let alpha = cutoff / (cutoff + 1.0)
            if i == 0 {
                out[i] = noise * alpha
            } else {
                out[i] = out[i - 1] + alpha * (noise - out[i - 1])
            }

            // Amplitude modulation: the characteristic "brr-brr-brr"
            let am = Float(0.5 + 0.5 * sin(2.0 * .pi * amFreq * t))
            out[i] *= am * 3.0

            // Subtle sine fundamental
            out[i] += 0.15 * sin(Float(2.0 * .pi * baseFreq * t))
        }

        crossFadeEnds(&out, fadeFrames: Int(sr * 0.05))
        return out
    }

    /// Meow: frequency sweep with formant shaping (0.5s).
    func generateMeow() -> [Float] {
        let sr = Self.sampleRate
        let duration = 0.5
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        for i in 0..<count {
            let t = Double(i) / sr
            let progress = t / duration

            // Frequency sweep: 350 -> 700 -> 500 Hz
            let freq: Double
            if progress < 0.4 {
                freq = 350.0 + (700.0 - 350.0) * (progress / 0.4)
            } else {
                let p2 = (progress - 0.4) / 0.6
                freq = 700.0 + (500.0 - 700.0) * p2
            }

            let phase = 2.0 * .pi * freq * t

            // Fundamental + harmonics for vocal quality
            var sample = Float(0.5 * sin(phase))
            sample += Float(0.25 * sin(phase * 2.0))
            sample += Float(0.1 * sin(phase * 3.0))
            sample += Float(0.05 * sin(phase * 5.0))

            // Envelope: attack, sustain, decay
            let env: Float
            if progress < 0.1 {
                env = Float(progress / 0.1)
            } else if progress < 0.7 {
                env = 1.0
            } else {
                env = Float((1.0 - progress) / 0.3)
            }

            out[i] = sample * env * 0.6
        }

        return out
    }

    /// Wind: filtered white noise with dual LFO on cutoff (12s loop).
    func generateWind() -> [Float] {
        let sr = Self.sampleRate
        let duration = 12.0
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        var noiseState: UInt32 = 67890
        var lpState: Float = 0

        for i in 0..<count {
            let t = Double(i) / sr

            noiseState = noiseState &* 1103515245 &+ 12345
            let noise = Float(noiseState) / Float(UInt32.max) * 2.0 - 1.0

            // Dual LFO at incommensurate periods for natural feel
            let lfo1 = 0.5 + 0.5 * sin(2.0 * .pi * t / 5.7)
            let lfo2 = 0.5 + 0.5 * sin(2.0 * .pi * t / 8.3)
            let cutoffHz = 150.0 + 500.0 * lfo1 + 200.0 * lfo2
            let alpha = Float(cutoffHz / (cutoffHz + sr))

            lpState = lpState + alpha * (noise - lpState)
            out[i] = lpState * 2.5

            let volMod = Float(0.7 + 0.3 * sin(2.0 * .pi * 0.33 * t))
            out[i] *= volMod
        }

        crossFadeEnds(&out, fadeFrames: Int(sr * 0.5))
        return out
    }

    /// Rain: pink noise with random high-freq droplet pings (15s loop).
    /// Long loop duration prevents audible repetition. Slow LFO modulates
    /// intensity for natural ebb and flow. Cross-fade is 0.5s for seamless loop.
    func generateRain() -> [Float] {
        let sr = Self.sampleRate
        let duration = 15.0  // Long loop — 4s was too obvious
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        var noiseState: UInt32 = 11111
        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var lpState: Float = 0

        for i in 0..<count {
            noiseState = noiseState &* 1103515245 &+ 12345
            let white = Float(noiseState) / Float(UInt32.max) * 2.0 - 1.0

            // Approximate pink noise with filtered feedback
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            let pink = (b0 + b1 + b2 + white * 0.5362) * 0.15

            // Slow LFO modulates rain intensity (natural ebb/flow)
            let t = Double(i) / sr
            let lfo = Float(0.7 + 0.3 * sin(2.0 * .pi * t / 7.3))  // 7.3s period

            let alpha: Float = 0.25
            lpState = lpState + alpha * (pink * lfo - lpState)
            out[i] = lpState
        }

        // Add random droplet pings — varied spacing
        var dropRng: UInt32 = 22222
        let avgDropInterval = Int(sr * 0.12)  // Slightly sparser

        var nextDrop = Int(sr * 0.3)  // Start after 0.3s
        while nextDrop < count {
            dropRng = dropRng &* 1103515245 &+ 12345
            let interval = avgDropInterval / 3
                + Int(dropRng % UInt32(avgDropInterval))
            nextDrop += interval

            guard nextDrop < count else { break }

            dropRng = dropRng &* 1103515245 &+ 12345
            let dropFreq = 1500.0 + Double(dropRng % 5000)  // Wider freq range
            dropRng = dropRng &* 1103515245 &+ 12345
            let dropAmp = Float(0.03 + 0.08 * Double(dropRng % 100) / 100.0)
            let dropLen = Int(sr * 0.012)  // Slightly longer drops

            for j in 0..<dropLen {
                let idx = nextDrop + j
                guard idx < count else { break }
                let dt = Double(j) / sr
                let decay = Float(exp(-dt * 400.0))  // Slower decay
                out[idx] += dropAmp * sin(Float(2.0 * .pi * dropFreq * dt))
                    * decay
            }
        }

        crossFadeEnds(&out, fadeFrames: Int(sr * 0.5))  // 0.5s crossfade
        return out
    }

    /// Crickets: periodic high-frequency chirps with random timing (10s loop).
    func generateCrickets() -> [Float] {
        let sr = Self.sampleRate
        let duration = 10.0
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        var rng: UInt32 = 33333

        let cricketVoices: [(freq: Double, burstOn: Double, burstOff: Double)] = [
            (4200.0, 0.04, 0.08),
            (3800.0, 0.035, 0.12),
            (4600.0, 0.03, 0.15),
        ]

        for voice in cricketVoices {
            var pos = 0
            rng = rng &* 1103515245 &+ 12345
            pos += Int(Double(rng % 10000) / 10000.0 * sr * 0.2)

            while pos < count {
                let burstCount = 3 + Int(rng % 3)
                for _ in 0..<burstCount {
                    let onFrames = Int(sr * voice.burstOn)
                    for j in 0..<onFrames {
                        let idx = pos + j
                        guard idx < count else { break }
                        let t = Double(j) / sr
                        let env = Float(sin(.pi * t / voice.burstOn))
                        out[idx] += 0.15 * env
                            * sin(Float(2.0 * .pi * voice.freq * t))
                    }
                    pos += onFrames

                    let offFrames = Int(sr * voice.burstOn * 0.6)
                    pos += offFrames
                }

                rng = rng &* 1103515245 &+ 12345
                let gapBase = voice.burstOff
                let gapVariation = gapBase * 0.5
                    * Double(rng % 1000) / 1000.0
                pos += Int(sr * (gapBase + gapVariation))
            }
        }

        crossFadeEnds(&out, fadeFrames: Int(sr * 0.05))
        return out
    }

    /// Music box: pentatonic scale sequence with bell-like decay (4s).
    func generateMusicBox() -> [Float] {
        let sr = Self.sampleRate
        let duration = 4.0
        let count = Int(sr * duration)
        var out = [Float](repeating: 0, count: count)

        // C major pentatonic: C5, D5, E5, G5, A5, C6
        let notes: [Double] = [
            523.25, 587.33, 659.25, 783.99, 880.00, 1046.50
        ]

        let melody: [(noteIdx: Int, startBeat: Double)] = [
            (0, 0.0), (2, 0.4), (4, 0.8), (3, 1.2),
            (2, 1.6), (0, 2.0), (1, 2.4), (3, 2.8),
            (5, 3.2), (4, 3.5),
        ]

        let noteLength = 0.35

        for note in melody {
            let freq = notes[note.noteIdx]
            let startFrame = Int(sr * note.startBeat)
            let ringFrames = Int(sr * noteLength)

            for j in 0..<ringFrames {
                let idx = startFrame + j
                guard idx < count else { break }
                let t = Double(j) / sr

                var sample = Float(0.4 * sin(2.0 * .pi * freq * t))
                sample += Float(0.2 * sin(2.0 * .pi * freq * 2.0 * t))
                sample += Float(0.1 * sin(2.0 * .pi * freq * 3.01 * t))
                sample += Float(0.05 * sin(2.0 * .pi * freq * 5.99 * t))

                let decay = Float(exp(-t * 8.0))
                out[idx] += sample * decay * 0.5
            }
        }

        return out
    }

    // MARK: - Loop Helpers

    /// Cross-fade the beginning and end of a buffer for seamless looping.
    func crossFadeEnds(_ buffer: inout [Float], fadeFrames: Int) {
        let count = buffer.count
        guard fadeFrames > 0, fadeFrames * 2 < count else { return }

        for i in 0..<fadeFrames {
            let t = Float(i) / Float(fadeFrames)
            let endIdx = count - fadeFrames + i

            let beginVal = buffer[i]
            let endVal = buffer[endIdx]
            let blended = beginVal * t + endVal * (1.0 - t)

            buffer[i] = blended
            buffer[endIdx] = blended
        }
    }
}
