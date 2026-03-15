// EyeController.swift — Eye body part controller
// States: open, half, closed, wide, squint, happy, blink, slow_blink,
//         look_at, x_eyes
// One controller per eye. Blink system is managed by CreatureNode.

import SpriteKit

final class EyeController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "open", "half", "closed", "wide", "squint",
        "happy", "blink", "slow_blink", "look_at", "x_eyes"
    ]
    private(set) var currentState = "open"

    /// The shape node representing the eye (child of the eye container).
    private let shapeNode: SKShapeNode

    /// Whether this is the left eye.
    let isLeftEye: Bool

    /// Pupil node for look_at targeting.
    private var pupilNode: SKShapeNode?

    /// Original eye size for scaling states.
    private let baseWidth: CGFloat
    private let baseHeight: CGFloat

    /// Blink animation state.
    private var blinkPhase: BlinkPhase = .none
    private var blinkTimer: TimeInterval = 0

    enum BlinkPhase {
        case none, closing, hold, opening
        case slowClosing, slowHold, slowOpening
    }

    // MARK: - Init

    /// - Parameters:
    ///   - eyeNode: The SKNode container for this eye.
    ///   - shape: The SKShapeNode that draws the eye.
    ///   - isLeft: Whether this is the left eye.
    ///   - width: Base eye width in points.
    ///   - height: Base eye height in points.
    init(eyeNode: SKNode, shape: SKShapeNode, isLeft: Bool,
         width: CGFloat, height: CGFloat) {
        self.node = eyeNode
        self.shapeNode = shape
        self.isLeftEye = isLeft
        self.baseWidth = width
        self.baseHeight = height

        // Wire the pupil node from ShapeFactory (created as a child of the container)
        let pupilName = "\(eyeNode.name ?? "eye")_pupil"
        self.pupilNode = eyeNode.childNode(withName: pupilName) as? SKShapeNode
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved
        blinkPhase = .none
        blinkTimer = 0

        switch resolved {
        case "open":
            animateToOpenState(duration: duration)
        case "half":
            animateToScale(yScale: 0.5, duration: duration)
        case "closed":
            animateToScale(yScale: 0.05, duration: duration)
        case "wide":
            animateToScale(yScale: 1.3, xScale: 1.2, duration: duration)
        case "squint":
            animateToScale(yScale: 0.3, duration: duration)
        case "happy":
            applyHappyShape(duration: duration)
        case "blink":
            startBlink()
        case "slow_blink":
            startSlowBlink()
        case "look_at":
            // TODO: look_at needs real target coordinates from the caller
            // (e.g., world position of an object or touch point). Currently
            // defaults to a fixed off-center offset as a placeholder.
            shiftPupil(dx: isLeftEye ? -0.5 : 0.5)
        case "x_eyes":
            applyXEyes()
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        updateBlink(deltaTime: deltaTime)
    }

    // MARK: - Blink Animation (Per-Frame)

    private func startBlink() {
        blinkPhase = .closing
        blinkTimer = 0
    }

    private func startSlowBlink() {
        blinkPhase = .slowClosing
        blinkTimer = 0
    }

    private func updateBlink(deltaTime: TimeInterval) {
        guard blinkPhase != .none else { return }
        blinkTimer += deltaTime

        switch blinkPhase {
        case .closing:
            // Close over 0.075s
            let t = min(blinkTimer / 0.075, 1.0)
            shapeNode.yScale = CGFloat(1.0 - t * 0.95)
            if t >= 1.0 {
                blinkPhase = .hold
                blinkTimer = 0
            }

        case .hold:
            // Hold closed for 0.075s
            shapeNode.yScale = 0.05
            if blinkTimer >= 0.075 {
                blinkPhase = .opening
                blinkTimer = 0
            }

        case .opening:
            // Open over 0.075s
            let t = min(blinkTimer / 0.075, 1.0)
            shapeNode.yScale = CGFloat(0.05 + t * 0.95)
            if t >= 1.0 {
                shapeNode.yScale = 1.0
                blinkPhase = .none
                currentState = "open"
            }

        // Slow blink — the trust gesture
        case .slowClosing:
            let t = min(blinkTimer / 0.3, 1.0)
            shapeNode.yScale = CGFloat(1.0 - t * 0.95)
            if t >= 1.0 {
                blinkPhase = .slowHold
                blinkTimer = 0
            }

        case .slowHold:
            shapeNode.yScale = 0.05
            if blinkTimer >= 0.5 {
                blinkPhase = .slowOpening
                blinkTimer = 0
            }

        case .slowOpening:
            let t = min(blinkTimer / 0.3, 1.0)
            shapeNode.yScale = CGFloat(0.05 + t * 0.95)
            if t >= 1.0 {
                shapeNode.yScale = 1.0
                blinkPhase = .none
                currentState = "open"
            }

        case .none:
            break
        }
    }

    /// Whether the eye is currently mid-blink animation.
    var isBlinking: Bool {
        blinkPhase != .none
    }

    /// Whether the eye is in a closed state (sleep, slow-blink hold).
    var isClosed: Bool {
        currentState == "closed" || blinkPhase == .hold
            || blinkPhase == .slowHold
    }

    // MARK: - Visual States

    private func animateToOpenState(duration: TimeInterval) {
        animateToScale(yScale: 1.0, xScale: 1.0, duration: duration)
        shapeNode.fillColor = PushlingPalette.bone
        pupilNode?.isHidden = false
    }

    private func animateToScale(yScale: CGFloat, xScale: CGFloat = 1.0,
                                 duration: TimeInterval) {
        shapeNode.removeAction(forKey: "eyeScale")
        if duration <= 0.01 {
            shapeNode.yScale = yScale
            shapeNode.xScale = xScale
        } else {
            let scaleAction = SKAction.group([
                SKAction.scaleX(to: xScale, duration: duration),
                SKAction.scaleY(to: yScale, duration: duration),
            ])
            scaleAction.timingMode = .easeInEaseOut
            shapeNode.run(scaleAction, withKey: "eyeScale")
        }
    }

    private func applyHappyShape(duration: TimeInterval) {
        // Happy anime eyes — curved upward shape (represented by
        // squashing vertically and widening slightly)
        animateToScale(yScale: 0.4, xScale: 1.1, duration: duration)
    }

    private func applyXEyes() {
        // X eyes — hide normal shape, we'd draw Xs.
        // For placeholder: just close to a tiny slit
        shapeNode.yScale = 0.1
        shapeNode.xScale = 0.8
    }

    private func shiftPupil(dx: CGFloat) {
        pupilNode?.position.x = dx
    }

}
