// WorldManager+Sound.swift — Ambient sound integration
// Extension on WorldManager for sound playback and weather-sound sync.
// The SoundSystem itself lives in Voice/SoundSystem.swift.

import Foundation

// MARK: - Ambient Sound

extension WorldManager {

    /// Play an ambient sound by type.
    /// - Parameters:
    ///   - type: The sound type to play.
    ///   - action: Play or stop (default: play).
    func playSound(_ type: SoundType, action: SoundAction = .play) {
        soundSystem.play(type, action: action)
    }

    /// Stop a specific ambient sound.
    func stopSound(_ type: SoundType) {
        soundSystem.stop(type)
    }

    /// Stop all ambient sounds.
    func stopAllSounds() {
        soundSystem.stopAll()
    }

    /// Sync ambient sounds to the current weather state.
    /// Called after weather transitions complete and periodically
    /// from the frame update loop (every ~0.5s).
    func syncWeatherSounds() {
        let weather = weatherSystem.currentState

        switch weather {
        case .rain:
            soundSystem.play(.rain)
            soundSystem.stop(.wind)
        case .storm:
            soundSystem.play(.rain)
            soundSystem.play(.wind)
        case .clear, .cloudy, .snow, .fog:
            soundSystem.stop(.rain)
            soundSystem.stop(.wind)
        }

        // Crickets at night during clear/cloudy weather
        let isNight = skySystem.currentPeriod == .lateNight
            || skySystem.currentPeriod == .deepNight
        if isNight && (weather == .clear || weather == .cloudy) {
            soundSystem.play(.crickets)
        } else {
            soundSystem.stop(.crickets)
        }
    }
}
