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

    /// Target world position for rotate_toward state.
    var targetWorldPosition: CGPoint?

    /// Inner ear child node (for independent inner ear movement).
    private weak var innerEarNode: SKNode?

    /// Personality snapshot for modulation.
    var personalitySnapshot: PersonalitySnapshot = .neutral

    /// Accumulated time for personality-driven random twitches.
    private var randomTwitchAccumulator: TimeInterval = 0
    private var nextRandomTwitchAt: TimeInterval = 5.0

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
    /// - Parameters:
    ///   - earNode: The SKNode representing this ear.
    ///   - isLeft: Whether this is the left ear.
    ///   - innerEarNode: Optional inner ear child for independent movement.
    init(earNode: SKNode, isLeft: Bool, innerEarNode: SKNode? = nil) {
        self.node = earNode
        self.isLeftEar = isLeft
        self.innerEarNode = innerEarNode
        // Left ear tilts left (negative), right ear tilts right (positive)
        self.neutralRotation = isLeft
            ? -Rotations.neutral
            :  Rotations.neutral
        applyNeutral()
        scheduleRandomTwitch()
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
            // Per-frame tracking handled in update()
            break
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
        case "rotate_toward":
            updateRotateToward(deltaTime: deltaTime)
        default:
            break
        }

        // Per-state inner ear modulation
        updateInnerEar()

        // Personality-driven random micro-twitches (all states except wild)
        if currentState != "wild" && currentState != "twitch" {
            updateRandomTwitch(deltaTime: deltaTime)
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

    // MARK: - Rotate Toward (Smooth Tracking)

    /// Per-frame smooth tracking toward a world-space target.
    private func updateRotateToward(deltaTime: TimeInterval) {
        guard let target = targetWorldPosition else {
            // No target — default to slightly perked
            let goal = neutralAngle(Rotations.perk)
            let current = node.zRotation
            let lerpSpeed: CGFloat = 8.0
            node.zRotation = current + (goal - current)
                * min(CGFloat(deltaTime) * lerpSpeed, 1.0)
            return
        }

        // Compute angle from ear to target in parent's coordinate space
        guard let scene = node.scene else {
            let goal = neutralAngle(Rotations.perk)
            let current = node.zRotation
            node.zRotation = current + (goal - current)
                * min(CGFloat(deltaTime) * 8.0, 1.0)
            return
        }
        let earWorldPos = node.parent?.convert(node.position, to: scene)
            ?? node.position
        let dx = target.x - earWorldPos.x
        let dy = target.y - earWorldPos.y
        let angleToTarget = atan2(dy, dx)

        // Map world angle to ear rotation (ears point upward, so 90° = forward)
        let baseAngle = angleToTarget - .pi / 2
        let clampedAngle = clamp(baseAngle, min: -1.0, max: 1.0)
        let earAngle = isLeftEar ? -clampedAngle : clampedAngle

        // Smooth lerp toward target (8x damping for responsive tracking)
        let current = node.zRotation
        let lerpSpeed: CGFloat = 8.0
        node.zRotation = current + (earAngle - current)
            * min(CGFloat(deltaTime) * lerpSpeed, 1.0)
    }

    // MARK: - Inner Ear Movement

    /// Modulate the inner ear node based on current state.
    /// Zero extra nodes — uses the existing inner ear child.
    private func updateInnerEar() {
        guard let inner = innerEarNode else { return }

        switch currentState {
        case "perk":
            // Inner ear shifts outward slightly
            inner.zRotation = isLeftEar ? -0.05 : 0.05
            inner.yScale = 1.0
        case "flat":
            // Inner ear compresses
            inner.zRotation = 0
            inner.yScale = 0.7
        case "twitch":
            // Inner ear jiggles with slight phase offset
            let offset = CGFloat(sin(twitchTimer * .pi * 2 / 0.16 + 0.3))
                * 0.03
            inner.zRotation = offset
            inner.yScale = 1.0
        case "rotate_toward":
            // Inner ear tilts 1.2x more aggressively than outer
            inner.zRotation = node.zRotation * 0.2
            inner.yScale = 1.0
        default:
            // Neutral
            inner.zRotation = 0
            inner.yScale = 1.0
        }
    }

    // MARK: - Personality-Driven Random Twitches

    private func updateRandomTwitch(deltaTime: TimeInterval) {
        randomTwitchAccumulator += deltaTime
        if randomTwitchAccumulator >= nextRandomTwitchAt {
            // Quick micro-twitch: ±0.08 rad for 0.1s
            let twitch = (isLeftEar ? -1 : 1) * CGFloat.random(in: 0.04...0.08)
            let current = node.zRotation
            let action = SKAction.sequence([
                SKAction.rotate(toAngle: current + twitch, duration: 0.05,
                                shortestUnitArc: true),
                SKAction.rotate(toAngle: current, duration: 0.05,
                                shortestUnitArc: true)
            ])
            node.run(action, withKey: "microTwitch")
            scheduleRandomTwitch()
        }
    }

    private func scheduleRandomTwitch() {
        randomTwitchAccumulator = 0
        // High energy = more frequent twitches (2-5s), low = less (5-12s)
        let minInterval = 2.0 + (1.0 - personalitySnapshot.energy) * 3.0
        let maxInterval = 5.0 + (1.0 - personalitySnapshot.energy) * 7.0
        nextRandomTwitchAt = TimeInterval.random(in: minInterval...maxInterval)
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
