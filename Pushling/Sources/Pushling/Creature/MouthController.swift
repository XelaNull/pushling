// MouthController.swift — Mouth body part controller
// States: closed, open, smile, frown, chew, yawn, chatter, blep, lick

import SpriteKit

final class MouthController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "closed", "open", "open_small", "open_wide",
        "smile", "smirk", "frown", "pout",
        "chew", "yawn", "chatter", "blep", "lick"
    ]
    private(set) var currentState = "closed"

    /// The shape node for the mouth line/curve.
    private let shapeNode: SKShapeNode

    /// Tongue node for blep/lick (created lazily).
    private var tongueNode: SKShapeNode?

    /// Base mouth width in points.
    private let mouthWidth: CGFloat

    /// Chew animation timer.
    private var chewTimer: TimeInterval = 0

    /// Chatter animation timer (rapid jaw vibration).
    private var chatterTimer: TimeInterval = 0

    /// Yawn phase tracking.
    private var yawnPhase: YawnPhase = .none
    private var yawnTimer: TimeInterval = 0

    /// Lick animation timer.
    private var lickTimer: TimeInterval = 0

    enum YawnPhase {
        case none, opening, hold, closing
    }

    // MARK: - Init

    init(mouthNode: SKNode, shape: SKShapeNode, width: CGFloat) {
        self.node = mouthNode
        self.shapeNode = shape
        self.mouthWidth = width
        setupTongue()
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        yawnPhase = .none
        chewTimer = 0
        chatterTimer = 0
        lickTimer = 0
        tongueNode?.isHidden = true

        switch resolved {
        case "closed":
            applyClosedShape(duration: duration)
        case "open":
            applyOpenShape(duration: duration)
        case "smile":
            applySmileShape(duration: duration)
        case "frown":
            applyFrownShape(duration: duration)
        case "chew":
            chewTimer = 0
        case "yawn":
            yawnPhase = .opening
            yawnTimer = 0
        case "chatter":
            chatterTimer = 0
        case "blep":
            applyClosedShape(duration: 0)
            tongueNode?.isHidden = false
            tongueNode?.position.y = -1.0
        case "lick":
            lickTimer = 0
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        switch currentState {
        case "chew":
            updateChew(deltaTime: deltaTime)
        case "yawn":
            updateYawn(deltaTime: deltaTime)
        case "chatter":
            updateChatter(deltaTime: deltaTime)
        case "lick":
            updateLick(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Continuous Animations

    private func updateChew(deltaTime: TimeInterval) {
        chewTimer += deltaTime
        // Open-close-open oscillation — 120ms per chew cycle
        let cycle = 0.12
        let t = chewTimer.truncatingRemainder(dividingBy: cycle)
            / cycle
        let openAmount = CGFloat(sin(t * .pi)) * 0.6
        shapeNode.yScale = 1.0 + openAmount
    }

    private func updateYawn(deltaTime: TimeInterval) {
        yawnTimer += deltaTime

        switch yawnPhase {
        case .opening:
            // Wide open over 0.5s
            let t = min(yawnTimer / 0.5, 1.0)
            shapeNode.yScale = 1.0 + CGFloat(t) * 2.0
            shapeNode.xScale = 1.0 + CGFloat(t) * 0.3
            if t >= 1.0 {
                yawnPhase = .hold
                yawnTimer = 0
            }
        case .hold:
            // Hold wide open for 0.8s
            if yawnTimer >= 0.8 {
                yawnPhase = .closing
                yawnTimer = 0
            }
        case .closing:
            // Close over 0.4s
            let t = min(yawnTimer / 0.4, 1.0)
            shapeNode.yScale = 3.0 - CGFloat(t) * 2.0
            shapeNode.xScale = 1.3 - CGFloat(t) * 0.3
            if t >= 1.0 {
                yawnPhase = .none
                currentState = "closed"
                shapeNode.yScale = 1.0
                shapeNode.xScale = 1.0
            }
        case .none:
            break
        }
    }

    private func updateChatter(deltaTime: TimeInterval) {
        // Rapid jaw vibration — 30Hz oscillation
        chatterTimer += deltaTime
        let vibration = CGFloat(sin(chatterTimer * 60.0 * .pi))
        shapeNode.yScale = 1.0 + abs(vibration) * 0.4
    }

    private func updateLick(deltaTime: TimeInterval) {
        lickTimer += deltaTime
        tongueNode?.isHidden = false

        // Tongue out (0-0.3s), back in (0.3-0.6s)
        let totalDuration: TimeInterval = 0.6
        if lickTimer < totalDuration / 2 {
            let t = lickTimer / (totalDuration / 2)
            tongueNode?.position.y = CGFloat(-t) * 2.0
        } else if lickTimer < totalDuration {
            let t = (lickTimer - totalDuration / 2) / (totalDuration / 2)
            tongueNode?.position.y = CGFloat(t - 1.0) * 2.0
        } else {
            tongueNode?.isHidden = true
            currentState = "closed"
            lickTimer = 0
        }
    }

    // MARK: - Mouth Shapes

    private func applyClosedShape(duration: TimeInterval) {
        shapeNode.yScale = 1.0
        shapeNode.xScale = 1.0
        shapeNode.position.y = 0
    }

    private func applyOpenShape(duration: TimeInterval) {
        shapeNode.yScale = 1.5
        shapeNode.xScale = 1.0
        shapeNode.position.y = 0
    }

    private func applySmileShape(duration: TimeInterval) {
        // Smile — upturned corners (represented by slight Y offset up)
        shapeNode.yScale = 1.0
        shapeNode.xScale = 1.1
        shapeNode.position.y = 0.3
    }

    private func applyFrownShape(duration: TimeInterval) {
        // Frown — downturned (Y offset down)
        shapeNode.yScale = 1.0
        shapeNode.xScale = 1.0
        shapeNode.position.y = -0.3
    }

    // MARK: - Tongue Setup

    private func setupTongue() {
        let tongue = SKShapeNode(rectOf: CGSize(width: 1.0, height: 1.5),
                                  cornerRadius: 0.5)
        tongue.fillColor = PushlingPalette.softEmber
        tongue.strokeColor = .clear
        tongue.position = CGPoint(x: 0, y: -1.0)
        tongue.zPosition = 1
        tongue.isHidden = true
        tongue.name = "tongue"
        node.addChild(tongue)
        self.tongueNode = tongue
    }
}
