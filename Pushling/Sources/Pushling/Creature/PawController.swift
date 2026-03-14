// PawController.swift — Paw body part controller
// States: ground, walk, run, lift, knead, tuck, dig, swipe, extend
// One controller per paw (front-left, front-right, back-left, back-right).

import SpriteKit

/// Identifies which paw this controller manages.
enum PawPosition: String {
    case frontLeft  = "fl"
    case frontRight = "fr"
    case backLeft   = "bl"
    case backRight  = "br"

    var isFront: Bool {
        self == .frontLeft || self == .frontRight
    }
}

final class PawController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "ground", "walk", "run", "lift", "knead",
        "tuck", "dig", "swipe", "extend"
    ]
    private(set) var currentState = "ground"

    /// Which paw this is.
    let position: PawPosition

    /// Walk/run cycle phase offset (set by CreatureNode for gait pattern).
    var cyclePhaseOffset: CGFloat = 0

    /// Walk cycle accumulator.
    private var walkCycleTime: TimeInterval = 0

    /// Knead animation timer.
    private var kneadTimer: TimeInterval = 0

    /// Dig animation timer.
    private var digTimer: TimeInterval = 0

    /// Swipe animation timer.
    private var swipeTimer: TimeInterval = 0

    /// The paw's resting position relative to body.
    private let restPosition: CGPoint

    // MARK: - Init

    init(pawNode: SKNode, position: PawPosition, restingPoint: CGPoint) {
        self.node = pawNode
        self.position = position
        self.restPosition = restingPoint
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        walkCycleTime = 0
        kneadTimer = 0
        digTimer = 0
        swipeTimer = 0

        switch resolved {
        case "ground":
            animateToRest(duration: duration)
        case "walk", "run":
            // Walk/run cycle driven by update()
            break
        case "lift":
            animateLift(duration: duration)
        case "knead":
            kneadTimer = 0
        case "tuck":
            animateTuck(duration: duration)
        case "dig":
            digTimer = 0
        case "swipe":
            swipeTimer = 0
        case "extend":
            animateExtend(duration: duration)
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        switch currentState {
        case "walk":
            updateWalkCycle(deltaTime: deltaTime, speed: 1.0)
        case "run":
            updateWalkCycle(deltaTime: deltaTime, speed: 2.0)
        case "knead":
            updateKnead(deltaTime: deltaTime)
        case "dig":
            updateDig(deltaTime: deltaTime)
        case "swipe":
            updateSwipe(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Walk Cycle (Per-Frame)

    /// Diagonal gait: FL+BR together, FR+BL together.
    /// Phase offset creates the alternating pattern.
    private func updateWalkCycle(deltaTime: TimeInterval,
                                 speed: CGFloat) {
        walkCycleTime += deltaTime * Double(speed)

        // Sine-wave vertical displacement for paw lift
        let phase = walkCycleTime * 2.0 * .pi / 0.6
            + Double(cyclePhaseOffset)
        let liftAmount = max(0, sin(phase)) * 2.0  // only up, not down
        let forwardAmount = cos(phase) * 1.5        // forward-back swing

        node.position = CGPoint(
            x: restPosition.x + CGFloat(forwardAmount),
            y: restPosition.y + CGFloat(liftAmount)
        )
    }

    // MARK: - Knead Animation

    /// Alternating push motion — front paws only.
    private func updateKnead(deltaTime: TimeInterval) {
        kneadTimer += deltaTime

        // Kneading cycle: push down over 0.3s, lift over 0.3s
        let cycle = 0.6
        let t = kneadTimer.truncatingRemainder(dividingBy: cycle)
            / cycle
        let pushAmount = CGFloat(sin(t * .pi)) * 1.5

        node.position = CGPoint(
            x: restPosition.x,
            y: restPosition.y - pushAmount
        )
    }

    // MARK: - Dig Animation

    private func updateDig(deltaTime: TimeInterval) {
        digTimer += deltaTime

        // Rapid forward scooping motion
        let cycle = 0.25
        let t = digTimer.truncatingRemainder(dividingBy: cycle)
            / cycle
        let forwardAmount = CGFloat(sin(t * .pi * 2)) * 2.0
        let liftAmount = CGFloat(max(0, sin(t * .pi))) * 1.0

        node.position = CGPoint(
            x: restPosition.x + forwardAmount,
            y: restPosition.y + liftAmount
        )
    }

    // MARK: - Swipe Animation

    private func updateSwipe(deltaTime: TimeInterval) {
        swipeTimer += deltaTime

        // Quick forward strike — 0.2s out, 0.2s return
        let totalDuration: TimeInterval = 0.4
        if swipeTimer < totalDuration {
            let t = swipeTimer / totalDuration
            let extend = CGFloat(sin(t * .pi)) * 3.0
            node.position = CGPoint(
                x: restPosition.x + extend,
                y: restPosition.y + CGFloat(sin(t * .pi)) * 0.5
            )
        } else {
            currentState = "ground"
            node.position = restPosition
        }
    }

    // MARK: - Static Poses

    private func animateToRest(duration: TimeInterval) {
        node.removeAction(forKey: "pawMove")
        if duration <= 0.01 {
            node.position = restPosition
        } else {
            let action = SKAction.move(to: restPosition,
                                       duration: duration)
            action.timingMode = .easeInEaseOut
            node.run(action, withKey: "pawMove")
        }
    }

    private func animateLift(duration: TimeInterval) {
        let liftedPos = CGPoint(x: restPosition.x,
                                 y: restPosition.y + 3.0)
        node.removeAction(forKey: "pawMove")
        let action = SKAction.move(to: liftedPos, duration: duration)
        action.timingMode = .easeOut
        node.run(action, withKey: "pawMove")
    }

    private func animateTuck(duration: TimeInterval) {
        // Paws hidden under body — move toward center
        let tuckedPos = CGPoint(x: restPosition.x * 0.3,
                                 y: restPosition.y + 1.0)
        node.removeAction(forKey: "pawMove")
        let action = SKAction.move(to: tuckedPos, duration: duration)
        action.timingMode = .easeInEaseOut
        node.run(action, withKey: "pawMove")
    }

    private func animateExtend(duration: TimeInterval) {
        // Cat stretch — paw reaches forward
        let extendedPos = CGPoint(
            x: restPosition.x + (position.isFront ? 4.0 : -2.0),
            y: restPosition.y - 0.5
        )
        node.removeAction(forKey: "pawMove")
        let action = SKAction.move(to: extendedPos, duration: duration)
        action.timingMode = .easeOut
        node.run(action, withKey: "pawMove")
    }
}
