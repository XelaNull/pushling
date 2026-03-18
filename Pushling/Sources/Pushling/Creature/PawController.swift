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
        "tuck", "dig", "swipe", "extend",
        "tap", "push", "wave", "reach", "conduct"
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

    /// Tap animation timer.
    private var tapTimer: TimeInterval = 0

    /// Push animation timer.
    private var pushTimer: TimeInterval = 0

    /// Wave animation timer.
    private var waveTimer: TimeInterval = 0

    /// Conduct animation timer.
    private var conductTimer: TimeInterval = 0

    /// Personality snapshot for walk cycle modulation.
    var personalitySnapshot: PersonalitySnapshot = .neutral

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
        tapTimer = 0
        pushTimer = 0
        waveTimer = 0
        conductTimer = 0

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
        case "tap":
            tapTimer = 0
        case "push":
            pushTimer = 0
        case "wave":
            waveTimer = 0
            animateLift(duration: 0.1)  // Raise paw first
        case "reach":
            animateReach(duration: max(duration, 0.3))
        case "conduct":
            conductTimer = 0
            animateLift(duration: 0.1)  // Raise paw first
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        switch currentState {
        case "walk":
            let tempo = CGFloat(
                PersonalityFilter.animationTempo(
                    personality: personalitySnapshot))
            updateWalkCycle(deltaTime: deltaTime, speed: tempo)
        case "run":
            let tempo = CGFloat(
                PersonalityFilter.animationTempo(
                    personality: personalitySnapshot))
            updateWalkCycle(deltaTime: deltaTime, speed: 2.0 * tempo)
        case "knead":
            updateKnead(deltaTime: deltaTime)
        case "dig":
            updateDig(deltaTime: deltaTime)
        case "swipe":
            updateSwipe(deltaTime: deltaTime)
        case "tap":
            updateTap(deltaTime: deltaTime)
        case "push":
            updatePush(deltaTime: deltaTime)
        case "wave":
            updateWave(deltaTime: deltaTime)
        case "conduct":
            updateConduct(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Walk Cycle (Per-Frame)

    /// Diagonal gait: FL+BR together, FR+BL together.
    /// Phase offset creates the alternating pattern.
    /// Personality energy modulates lift amplitude (high energy = bouncier steps).
    private func updateWalkCycle(deltaTime: TimeInterval,
                                 speed: CGFloat) {
        walkCycleTime += deltaTime * Double(speed)

        // Sine-wave vertical displacement for paw lift
        let phase = walkCycleTime * 2.0 * .pi / 0.6
            + Double(cyclePhaseOffset)

        // Personality: high energy = bouncier steps (1.5-2.5pt lift)
        let energyLift = 1.5 + personalitySnapshot.energy * 1.0
        let liftAmount = max(0, sin(phase)) * energyLift
        let forwardAmount = cos(phase) * 1.5

        node.position = CGPoint(
            x: restPosition.x + CGFloat(forwardAmount),
            y: restPosition.y + CGFloat(liftAmount)
        )

        // Subtle leg extension during lift
        if let leg = node.childNode(withName: "\(node.name ?? "")_leg") {
            leg.yScale = 1.0 + CGFloat(liftAmount) * 0.1
        }
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

    // MARK: - Tap Animation (0.25s, auto-returns)

    /// Quick down-stroke + bounce — front paws only make sense.
    private func updateTap(deltaTime: TimeInterval) {
        tapTimer += deltaTime
        let duration: TimeInterval = 0.25

        if tapTimer < duration {
            let t = tapTimer / duration
            // Quick down-stroke then bounce back
            let downStroke = CGFloat(sin(t * .pi)) * 2.5
            node.position = CGPoint(
                x: restPosition.x,
                y: restPosition.y - downStroke
            )
        } else {
            currentState = "ground"
            node.position = restPosition
        }
    }

    // MARK: - Push Animation (0.75s, auto-returns)

    /// Forward extend + hold + retract — used for knocking behaviors.
    private func updatePush(deltaTime: TimeInterval) {
        pushTimer += deltaTime
        let duration: TimeInterval = 0.75

        if pushTimer < duration {
            let t = pushTimer / duration
            let extend: CGFloat
            if t < 0.3 {
                // Extend forward (0-0.3)
                extend = CGFloat(t / 0.3) * 3.5
            } else if t < 0.7 {
                // Hold (0.3-0.7)
                extend = 3.5
            } else {
                // Retract (0.7-1.0)
                extend = CGFloat(1.0 - (t - 0.7) / 0.3) * 3.5
            }
            let dir: CGFloat = position.isFront ? 1.0 : -1.0
            node.position = CGPoint(
                x: restPosition.x + extend * dir,
                y: restPosition.y + CGFloat(sin(t * .pi)) * 0.5
            )
        } else {
            currentState = "ground"
            node.position = restPosition
        }
    }

    // MARK: - Wave Animation (Continuous)

    /// Raised paw with side-to-side sine motion.
    private func updateWave(deltaTime: TimeInterval) {
        waveTimer += deltaTime

        let liftedY = restPosition.y + 3.0
        let sideMotion = CGFloat(sin(waveTimer * 2.0 * .pi / 0.6)) * 1.5

        node.position = CGPoint(
            x: restPosition.x + sideMotion,
            y: liftedY
        )
    }

    // MARK: - Conduct Animation (Continuous)

    /// Lissajous figure-8 pattern — used for MCP conducting gesture.
    private func updateConduct(deltaTime: TimeInterval) {
        conductTimer += deltaTime

        let liftedY = restPosition.y + 2.5
        let freq = 2.0 * .pi / 1.2
        let xMotion = CGFloat(sin(conductTimer * freq)) * 2.0
        let yMotion = CGFloat(sin(conductTimer * freq * 2.0)) * 1.0

        node.position = CGPoint(
            x: restPosition.x + xMotion,
            y: liftedY + yMotion
        )
    }

    // MARK: - Reach (Hold until changed)

    private func animateReach(duration: TimeInterval) {
        let reachPos = CGPoint(
            x: restPosition.x + (position.isFront ? 5.0 : -2.5),
            y: restPosition.y + 2.0
        )
        node.removeAction(forKey: "pawMove")
        let action = SKAction.move(to: reachPos, duration: duration)
        action.timingMode = .easeOut
        node.run(action, withKey: "pawMove")
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
