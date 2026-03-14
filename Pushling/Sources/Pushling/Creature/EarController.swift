// EarController.swift — Ear body part controller
// States: neutral, perk, flat, back, twitch, rotate_toward, droop, wild
// Each ear is independently controlled (one EarController per ear).

import SpriteKit

final class EarController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "neutral", "perk", "flat", "back", "twitch",
        "rotate_toward", "droop", "wild"
    ]
    private(set) var currentState = "neutral"

    /// Whether this is the left ear (affects rotation direction).
    private let isLeftEar: Bool

    /// Base rotation in radians for the neutral upright position.
    private let neutralRotation: CGFloat

    /// Accumulated time for wild state oscillation.
    private var wildTimer: TimeInterval = 0

    /// Timer for twitch animation.
    private var twitchTimer: TimeInterval = 0
    private var isTwitching = false

    // MARK: - Rotation Constants Per State

    /// Ear rotations (radians) — positive = outward tilt.
    private struct Rotations {
        static let neutral: CGFloat  =  0.15  // slight outward angle
        static let perk: CGFloat     =  0.0   // fully upright
        static let flat: CGFloat     =  1.3   // pressed against head
        static let back: CGFloat     = -0.5   // rotated backward
        static let droop: CGFloat    =  0.8   // sagging downward
    }

    // MARK: - Init

    /// - Parameters:
    ///   - earNode: The SKNode representing this ear.
    ///   - isLeft: Whether this is the left ear.
    init(earNode: SKNode, isLeft: Bool) {
        self.node = earNode
        self.isLeftEar = isLeft
        // Left ear tilts left (negative), right ear tilts right (positive)
        self.neutralRotation = isLeft
            ? -Rotations.neutral
            :  Rotations.neutral
        applyNeutral()
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        isTwitching = false
        wildTimer = 0

        switch resolved {
        case "neutral":
            animateRotation(to: neutralAngle(Rotations.neutral),
                            duration: duration)
        case "perk":
            animateRotation(to: neutralAngle(Rotations.perk),
                            duration: max(duration, 0.05))
        case "flat":
            animateRotation(to: flatAngle(),
                            duration: duration)
        case "back":
            animateRotation(to: neutralAngle(Rotations.back),
                            duration: duration)
        case "twitch":
            isTwitching = true
            twitchTimer = 0
        case "rotate_toward":
            // rotate_toward needs a target — default to perk for now
            animateRotation(to: neutralAngle(Rotations.perk),
                            duration: duration)
        case "droop":
            animateRotation(to: neutralAngle(Rotations.droop),
                            duration: duration)
        case "wild":
            wildTimer = 0
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        switch currentState {
        case "twitch":
            updateTwitch(deltaTime: deltaTime)
        case "wild":
            updateWild(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Continuous Animations

    private func updateTwitch(deltaTime: TimeInterval) {
        twitchTimer += deltaTime

        // Quick 2-frame oscillation: forward 0.08s, back 0.08s
        let cycle: TimeInterval = 0.16
        if twitchTimer < cycle {
            let t = twitchTimer / cycle
            let angle = neutralAngle(Rotations.neutral)
                + CGFloat(sin(t * .pi * 2)) * 0.15
            node.zRotation = angle
        } else {
            // Done twitching — return to neutral
            isTwitching = false
            currentState = "neutral"
            animateRotation(to: neutralAngle(Rotations.neutral),
                            duration: 0.1)
        }
    }

    private func updateWild(deltaTime: TimeInterval) {
        wildTimer += deltaTime
        // Rapid random orientations — oscillate chaotically
        let angle = CGFloat(sin(wildTimer * 15.0)) * 0.6
            + CGFloat(cos(wildTimer * 11.0)) * 0.3
        node.zRotation = neutralAngle(0) + angle
    }

    // MARK: - Helpers

    /// Convert a base rotation to the correct side.
    private func neutralAngle(_ base: CGFloat) -> CGFloat {
        isLeftEar ? -base : base
    }

    /// Flat ears press inward toward the head center.
    private func flatAngle() -> CGFloat {
        isLeftEar ? Rotations.flat : -Rotations.flat
    }

    private func applyNeutral() {
        node.zRotation = neutralAngle(Rotations.neutral)
    }

    private func animateRotation(to angle: CGFloat,
                                  duration: TimeInterval) {
        node.removeAction(forKey: "earRotate")
        if duration <= 0.01 {
            node.zRotation = angle
        } else {
            let action = SKAction.rotate(toAngle: angle,
                                         duration: duration,
                                         shortestUnitArc: true)
            action.timingMode = .easeInEaseOut
            node.run(action, withKey: "earRotate")
        }
    }
}
