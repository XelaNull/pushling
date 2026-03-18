// CatBehaviors+Weather.swift — Weather reaction choreographies
// Implements WeatherReactionDelegate so the cat responds to rain, snow,
// lightning, thunder, fog, and clearing weather with body-part animations.

import SpriteKit

/// Creature reactions to weather events. Drives body-part controllers
/// and SKActions on a weakly-held CreatureNode.
final class CatWeatherReactions: WeatherReactionDelegate {

    private weak var creature: CreatureNode?

    /// Speed multiplier set by fog (1.0 = normal, 0.7 = full fog).
    private(set) var weatherSpeedMultiplier: CGFloat = 1.0

    private enum Key {
        static let rainCompress    = "weather_rainCompress"
        static let rainHead        = "weather_rainHead"
        static let snowLookUp      = "weather_snowLookUp"
        static let snowPaw         = "weather_snowPaw"
        static let lightningFlinch = "weather_lightningFlinch"
        static let thunderRecover  = "weather_thunderRecover"
        static let clearShakeOff   = "weather_clearShakeOff"
    }

    init(creature: CreatureNode) {
        self.creature = creature
    }

    // MARK: - WeatherReactionDelegate

    func weatherChanged(to newWeather: WeatherState,
                        from previousWeather: WeatherState) {
        guard let creature, !creature.isSleeping else { return }
        clearPersistentEffects(from: previousWeather)

        switch newWeather {
        case .rain, .storm: applyRainPosture()
        case .snow:         applySnowReaction()
        case .fog:          applyFogPosture(density: 1.0)
        case .clear, .cloudy: restoreNeutral()
        }
    }

    func lightningStruck() {
        guard let creature, !creature.isSleeping else { return }

        // Flinch: ears flat, eyes squint, jump 2pt, 0.15s total then recover
        setEars("flat", duration: 0.05)
        setEyes("squint", duration: 0.05)

        let up = SKAction.moveBy(x: 0, y: 2.0, duration: 0.05)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -2.0, duration: 0.10)
        down.timingMode = .easeIn
        let recover = SKAction.run { [weak self] in
            self?.setEars("neutral", duration: 0.15)
            self?.setEyes("open", duration: 0.15)
        }
        creature.run(SKAction.sequence([up, down, recover]),
                     withKey: Key.lightningFlinch)
    }

    func thunderRumbled() {
        guard let creature, !creature.isSleeping else { return }

        // Fear: ears flat, eyes wide, tail low — recover over 1.0s
        setEars("flat", duration: 0.1)
        setEyes("wide", duration: 0.1)
        creature.tailController?.setState("low", duration: 0.15)

        let recover = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.setEars("neutral", duration: 0.3)
                self?.setEyes("open", duration: 0.3)
                self?.creature?.tailController?.setState("sway", duration: 0.3)
            }
        ])
        creature.run(recover, withKey: Key.thunderRecover)
    }

    func weatherCleared(previousWeather: WeatherState) {
        guard let creature, !creature.isSleeping else { return }
        clearPersistentEffects(from: previousWeather)
        weatherSpeedMultiplier = 1.0

        // Shake-off: +-5deg rotation, 3x at 0.1s intervals, then 0deg
        let angle = CGFloat.pi / 36.0  // 5 degrees
        let oneShake = SKAction.sequence([
            SKAction.rotate(toAngle: angle, duration: 0.05),
            SKAction.rotate(toAngle: -angle, duration: 0.1),
            SKAction.rotate(toAngle: 0, duration: 0.05)
        ])
        let reset = SKAction.run { [weak self] in
            self?.restoreNeutral()
        }
        creature.run(SKAction.sequence([
            SKAction.repeat(oneShake, count: 3), reset
        ]), withKey: Key.clearShakeOff)
    }

    func fogChanged(density: CGFloat) {
        guard let creature, !creature.isSleeping else { return }
        if density > 0.01 {
            applyFogPosture(density: density)
        } else {
            setEyes("open", duration: 0.3)
            weatherSpeedMultiplier = 1.0
        }
    }

    // MARK: - Weather Postures

    private func applyRainPosture() {
        guard let creature else { return }
        setEars("flat", duration: 0.3)

        let compress = SKAction.scaleY(to: 0.95, duration: 0.3)
        compress.timingMode = .easeInEaseOut
        creature.run(compress, withKey: Key.rainCompress)

        let headLower = SKAction.moveBy(x: 0, y: -1.0, duration: 0.3)
        headLower.timingMode = .easeInEaseOut
        creature.run(headLower, withKey: Key.rainHead)
    }

    /// Snow: look up (+1pt) and bat at snowflakes with front paws.
    private func applySnowReaction() {
        guard let creature else { return }

        let lookUp = SKAction.moveBy(x: 0, y: 1.0, duration: 0.3)
        lookUp.timingMode = .easeInEaseOut
        creature.run(lookUp, withKey: Key.snowLookUp)

        creature.pawFLController?.setState("swipe", duration: 0.2)
        let pawCycle = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak creature] in
                creature?.pawFLController?.setState("ground", duration: 0.3)
            },
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak creature] in
                creature?.pawFRController?.setState("swipe", duration: 0.2)
            },
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak creature] in
                creature?.pawFRController?.setState("ground", duration: 0.3)
            }
        ])
        creature.run(pawCycle, withKey: Key.snowPaw)
    }

    /// Fog: squint eyes, reduce speed by up to 30%.
    private func applyFogPosture(density: CGFloat) {
        setEyes("squint", duration: 0.4)
        weatherSpeedMultiplier = 1.0 - min(density, 1.0) * 0.3
    }

    // MARK: - Cleanup

    private func clearPersistentEffects(from weather: WeatherState) {
        guard let creature else { return }
        switch weather {
        case .rain, .storm:
            creature.run(SKAction.scaleY(to: 1.0, duration: 0.3),
                         withKey: Key.rainCompress)
            creature.removeAction(forKey: Key.rainHead)
        case .snow:
            creature.removeAction(forKey: Key.snowLookUp)
            creature.removeAction(forKey: Key.snowPaw)
            creature.pawFLController?.setState("ground", duration: 0.2)
            creature.pawFRController?.setState("ground", duration: 0.2)
        case .fog:
            setEyes("open", duration: 0.3)
            weatherSpeedMultiplier = 1.0
        case .clear, .cloudy:
            break
        }
    }

    private func restoreNeutral() {
        setEars("neutral", duration: 0.3)
        setEyes("open", duration: 0.3)
        creature?.tailController?.setState("sway", duration: 0.3)
        weatherSpeedMultiplier = 1.0
    }

    // MARK: - Helpers

    private func setEars(_ state: String, duration: TimeInterval) {
        creature?.earLeftController?.setState(state, duration: duration)
        creature?.earRightController?.setState(state, duration: duration)
    }

    private func setEyes(_ state: String, duration: TimeInterval) {
        creature?.eyeLeftController?.setState(state, duration: duration)
        creature?.eyeRightController?.setState(state, duration: duration)
    }
}
