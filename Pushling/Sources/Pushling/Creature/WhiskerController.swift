// WhiskerController.swift — Whisker body part controller
// States: neutral, forward, back, twitch, droop
// Controls a whisker group (left or right). Micro-twitches are per-frame.

import SpriteKit

final class WhiskerController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = ["neutral", "forward", "back", "twitch", "droop"]
    private(set) var currentState = "neutral"

    /// Whether this is the left whisker group.
    private let isLeftSide: Bool

    /// Accumulated time for twitch calculations.
    private var twitchTime: TimeInterval = 0

    /// Next scheduled micro-twitch time.
    private var nextTwitchAt: TimeInterval = 0

    /// Whether a micro-twitch is currently playing.
    private var isMicroTwitching = false
    private var microTwitchTimer: TimeInterval = 0

    /// Personality focus axis (0-1) — affects twitch frequency.
    var personalityFocus: CGFloat = 0.5

    /// Base rotation for the whisker group.
    private var baseRotation: CGFloat = 0

    // MARK: - Rotation Constants

    private struct Rotations {
        static let neutral: CGFloat =  0.05  // very slight spread
        static let forward: CGFloat = -0.15  // pointing forward
        static let back: CGFloat    =  0.35  // swept back
        static let droop: CGFloat   =  0.25  // hanging down
    }

    // MARK: - Init

    init(whiskerNode: SKNode, isLeft: Bool) {
        self.node = whiskerNode
        self.isLeftSide = isLeft
        self.baseRotation = neutralAngle(Rotations.neutral)
        scheduleNextMicroTwitch()
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        isMicroTwitching = false

        switch resolved {
        case "neutral":
            baseRotation = neutralAngle(Rotations.neutral)
            animateRotation(to: baseRotation, duration: duration)
        case "forward":
            baseRotation = neutralAngle(Rotations.forward)
            animateRotation(to: baseRotation, duration: duration)
        case "back":
            baseRotation = neutralAngle(Rotations.back)
            animateRotation(to: baseRotation, duration: duration)
        case "twitch":
            baseRotation = neutralAngle(Rotations.neutral)
            // Twitch will be driven by update()
        case "droop":
            baseRotation = neutralAngle(Rotations.droop)
            animateRotation(to: baseRotation, duration: duration)
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        twitchTime += deltaTime

        switch currentState {
        case "twitch":
            updateContinuousTwitch(deltaTime: deltaTime)
        case "neutral":
            updateMicroTwitch(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Micro-Twitch System

    /// Random micro-twitches during neutral state — subtle aliveness cue.
    private func updateMicroTwitch(deltaTime: TimeInterval) {
        if isMicroTwitching {
            microTwitchTimer += deltaTime

            // Small rotation (±3 degrees = ±0.052 rad) over 0.2s,
            // return over 0.3s
            if microTwitchTimer < 0.2 {
                let t = microTwitchTimer / 0.2
                let offset = CGFloat(sin(t * .pi)) * 0.052
                node.zRotation = baseRotation + offset
            } else if microTwitchTimer < 0.5 {
                let t = (microTwitchTimer - 0.2) / 0.3
                let offset = CGFloat(1.0 - t) * 0.02
                node.zRotation = baseRotation + offset
            } else {
                node.zRotation = baseRotation
                isMicroTwitching = false
                scheduleNextMicroTwitch()
            }
        } else if twitchTime >= nextTwitchAt {
            isMicroTwitching = true
            microTwitchTimer = 0
        }
    }

    /// Continuous twitch state — more frequent and visible.
    private func updateContinuousTwitch(deltaTime: TimeInterval) {
        let angle = sin(twitchTime * 8.0) * 0.06
            + sin(twitchTime * 13.0) * 0.03
        node.zRotation = baseRotation + CGFloat(angle)
    }

    // MARK: - Scheduling

    private func scheduleNextMicroTwitch() {
        // Interval: 5-15s base, modified by focus personality
        // High focus = more frequent (3-8s), low focus = less (8-20s)
        let focusMod = Double(personalityFocus)
        let minInterval = 5.0 - focusMod * 2.0    // 3-5s
        let maxInterval = 15.0 - focusMod * 7.0   // 8-15s
        let interval = Double.random(in: minInterval...maxInterval)
        nextTwitchAt = twitchTime + interval
    }

    // MARK: - Helpers

    private func neutralAngle(_ base: CGFloat) -> CGFloat {
        isLeftSide ? -base : base
    }

    private func animateRotation(to angle: CGFloat,
                                  duration: TimeInterval) {
        node.removeAction(forKey: "whiskerRotate")
        if duration <= 0.01 {
            node.zRotation = angle
        } else {
            let action = SKAction.rotate(toAngle: angle,
                                         duration: duration,
                                         shortestUnitArc: true)
            action.timingMode = .easeInEaseOut
            node.run(action, withKey: "whiskerRotate")
        }
    }
}
