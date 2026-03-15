// TailController.swift — Tail body part controller
// States: sway, sway_fast, still, poof, low, high, wrap, twitch_tip,
//         wag, chase
// Tail sway is per-frame sine-wave math (never an SKAction).

import SpriteKit

final class TailController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "sway", "sway_fast", "still", "poof", "low", "high",
        "wrap", "twitch_tip", "wag", "chase"
    ]
    private(set) var currentState = "sway"

    /// Accumulated time for sine-wave calculations.
    private var swayTime: TimeInterval = 0

    /// Tail sway parameters (modifiable by personality).
    var swayAmplitude: CGFloat = 0.21     // ±12 degrees in radians
    var swayPeriod: TimeInterval = 3.0    // seconds

    /// Personality energy axis (0-1) — affects sway speed and amplitude.
    var personalityEnergy: CGFloat = 0.5

    /// Full personality snapshot for PersonalityFilter modulation.
    var personalitySnapshot: PersonalitySnapshot = .neutral

    /// Base rotation (before sway is applied).
    private var baseRotation: CGFloat = 0

    /// Chase animation timer.
    private var chaseTimer: TimeInterval = 0

    /// Tip twitch timer.
    private var twitchTimer: TimeInterval = 0
    private var isTipTwitching = false

    // MARK: - Init

    init(tailNode: SKNode) {
        self.node = tailNode
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        isTipTwitching = false
        chaseTimer = 0

        switch resolved {
        case "sway":
            restoreScale(duration: duration)
            baseRotation = 0

        case "sway_fast":
            restoreScale(duration: duration)
            baseRotation = 0

        case "still":
            // Stop at current position, no sway
            baseRotation = node.zRotation

        case "poof":
            // Puff up — scale 1.5x
            animateScale(to: 1.5, duration: max(duration, 0.15))
            baseRotation = 0.3 // slightly raised

        case "low":
            baseRotation = -0.6 // hanging down
            animateRotation(to: baseRotation, duration: duration)
            restoreScale(duration: duration)

        case "high":
            baseRotation = 0.8 // straight up
            animateRotation(to: baseRotation, duration: duration)
            restoreScale(duration: duration)

        case "wrap":
            baseRotation = -1.2 // curled around body
            animateRotation(to: baseRotation, duration: duration)
            restoreScale(duration: duration)

        case "twitch_tip":
            isTipTwitching = true
            twitchTimer = 0
            baseRotation = 0.3 // slightly raised

        case "wag":
            restoreScale(duration: duration)
            baseRotation = 0

        case "chase":
            chaseTimer = 0

        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        swayTime += deltaTime

        switch currentState {
        case "sway":
            updateSway(deltaTime: deltaTime, fast: false)
        case "sway_fast":
            updateSway(deltaTime: deltaTime, fast: true)
        case "wag":
            updateWag(deltaTime: deltaTime)
        case "twitch_tip":
            updateTwitchTip(deltaTime: deltaTime)
        case "chase":
            updateChase(deltaTime: deltaTime)
        case "still", "poof", "low", "high", "wrap":
            break // No continuous animation
        default:
            break
        }
    }

    // MARK: - Per-Frame Sway (The Critical Animation)

    /// Gentle sine-wave rotation — per-frame math, never an SKAction.
    private func updateSway(deltaTime: TimeInterval, fast: Bool) {
        let filteredAmplitude = PersonalityFilter.tailSwayAmplitude(
            base: Double(swayAmplitude), personality: personalitySnapshot
        )
        let filteredPeriod = PersonalityFilter.tailSwayPeriod(
            base: swayPeriod, personality: personalitySnapshot
        )
        let amplitude = filteredAmplitude * (fast ? 1.5 : 1.0)
        let period = filteredPeriod * (fast ? 0.5 : 1.0)

        let angle = sin(2.0 * .pi * swayTime / period)
            * amplitude
        node.zRotation = baseRotation + CGFloat(angle)
    }

    /// Dog-like rapid wag — faster and wider.
    private func updateWag(deltaTime: TimeInterval) {
        let angle = sin(2.0 * .pi * swayTime / 0.3) * 0.35
        node.zRotation = CGFloat(angle)
    }

    /// Only the tip flicks — base stays steady.
    private func updateTwitchTip(deltaTime: TimeInterval) {
        twitchTimer += deltaTime
        let tipAngle = sin(twitchTimer * 12.0) * 0.1
        node.zRotation = baseRotation + CGFloat(tipAngle)
    }

    /// Chase — circular rotation for tail-chasing behavior.
    private func updateChase(deltaTime: TimeInterval) {
        chaseTimer += deltaTime
        let angle = chaseTimer * 4.0 // fast spin
        node.zRotation = CGFloat(angle)
    }

    // MARK: - Helpers

    private func animateRotation(to angle: CGFloat,
                                  duration: TimeInterval) {
        node.removeAction(forKey: "tailRotate")
        if duration <= 0.01 {
            node.zRotation = angle
        } else {
            let action = SKAction.rotate(toAngle: angle,
                                         duration: duration,
                                         shortestUnitArc: true)
            action.timingMode = .easeInEaseOut
            node.run(action, withKey: "tailRotate")
        }
    }

    private func animateScale(to scale: CGFloat,
                               duration: TimeInterval) {
        node.removeAction(forKey: "tailScale")
        let action = SKAction.scale(to: scale, duration: duration)
        action.timingMode = .easeOut
        node.run(action, withKey: "tailScale")
    }

    private func restoreScale(duration: TimeInterval) {
        animateScale(to: 1.0, duration: duration)
    }
}
