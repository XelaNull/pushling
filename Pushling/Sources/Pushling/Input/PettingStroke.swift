// PettingStroke.swift — Slow drag across creature produces fur ripple & purr
// Unlocked at 50 total touches. Tracks stroke direction, count, speed.
// 3 strokes in succession = slow-blink trust signal. Against-grain petting
// triggers rejection (personality-dependent tolerance).

import SpriteKit

// MARK: - Petting Stroke Handler

/// Manages the petting interaction: fur ripple wave, purr particles,
/// stroke counting, slow-blink trigger, and against-grain detection.
final class PettingStroke {

    // MARK: - Constants

    private static let maxSpeed: CGFloat = 100.0
    private static let minTravelForStroke: CGFloat = 15.0
    private static let strokeSuccessionWindow: TimeInterval = 5.0
    private static let slowBlinkStrokeCount = 3
    private static let rippleWidth: CGFloat = 4.0
    private static let rippleSpeedFactor: CGFloat = 1.5
    private static let purrParticlesPerSecond: Double = 8
    private static let bodyOffsetAmount: CGFloat = 1.0
    private static let againstGrainMaxStrokes = 3

    // MARK: - State

    /// Whether a petting stroke is currently in progress.
    private(set) var isActive = false

    /// Number of consecutive strokes within the succession window.
    private(set) var strokeCount = 0

    /// Time of the last completed stroke.
    private var lastStrokeTime: TimeInterval = 0

    /// Cumulative horizontal travel in the current stroke.
    private var strokeTravel: CGFloat = 0

    /// Direction of the current stroke (positive = left-to-right).
    private var strokeDirection: CGFloat = 0

    /// Number of against-grain strokes in current sequence.
    private var againstGrainCount = 0

    /// Accumulated purr emission timer.
    private var purrTimer: TimeInterval = 0

    /// Ripple highlight node.
    private var rippleNode: SKShapeNode?

    /// Active purr particle nodes.
    private var purrParticles: [SKShapeNode] = []

    /// Parent scene node for adding effects.
    private weak var parentNode: SKNode?

    /// Callback for creature responses.
    var onPettingEvent: ((PettingEvent) -> Void)?

    // MARK: - Petting Events

    /// Events dispatched during petting for creature/scene response.
    enum PettingEvent {
        case strokeStart(direction: CGFloat)
        case strokeContinue(progress: CGFloat, speed: CGFloat)
        case strokeComplete(count: Int)
        case slowBlink                      // 3 strokes = trust signal
        case lieDown                        // After slow-blink
        case againstGrain(count: Int)       // Stroking the wrong way
        case rejection                      // Too many against-grain strokes
        case purrIntensify(rate: Double)    // Purr particle rate change
    }

    // MARK: - Stroke Lifecycle

    /// Begins a petting stroke. Called when a slow drag enters the creature.
    func beginStroke(at position: CGPoint, creatureFacing: Direction,
                     in parent: SKNode, currentTime: TimeInterval) {
        parentNode = parent
        isActive = true
        strokeTravel = 0
        purrTimer = 0

        // Determine if this is with or against the grain
        // Head-to-tail = with grain. For right-facing: left-to-right is with grain.
        strokeDirection = 0

        // Check succession window
        if currentTime - lastStrokeTime > Self.strokeSuccessionWindow {
            strokeCount = 0
            againstGrainCount = 0
        }

        // Create ripple highlight
        let ripple = SKShapeNode(
            rectOf: CGSize(width: Self.rippleWidth, height: 20),
            cornerRadius: 1
        )
        ripple.fillColor = PushlingPalette.bone.withAlphaComponent(0.3)
        ripple.strokeColor = .clear
        ripple.zPosition = 25
        ripple.position = position
        ripple.name = "pet_ripple"
        parent.addChild(ripple)
        rippleNode = ripple

        onPettingEvent?(.strokeStart(direction: strokeDirection))
    }

    /// Continues the stroke as the finger moves.
    func continueStroke(at position: CGPoint, velocity: CGVector,
                        speed: CGFloat, creatureFacing: Direction,
                        deltaTime: TimeInterval) {
        guard isActive else { return }

        let dx = velocity.dx * CGFloat(deltaTime)
        strokeTravel += abs(dx)

        // Track direction
        if abs(dx) > 0.5 {
            strokeDirection = dx > 0 ? 1.0 : -1.0
        }

        // Move ripple
        rippleNode?.position = position

        // Determine grain direction
        let withGrain: Bool
        if creatureFacing == .right {
            withGrain = strokeDirection > 0  // left-to-right = head-to-tail
        } else {
            withGrain = strokeDirection < 0  // right-to-left = head-to-tail
        }

        // Against-grain detection
        if !withGrain && strokeTravel > Self.minTravelForStroke {
            againstGrainCount += 1
            onPettingEvent?(.againstGrain(count: againstGrainCount))
        }

        // Emit purr particles
        purrTimer += deltaTime
        let rate = Self.purrParticlesPerSecond
            * (strokeCount >= Self.slowBlinkStrokeCount ? 2.0 : 1.0)
        let interval = 1.0 / rate
        if purrTimer >= interval {
            purrTimer = 0
            emitPurrParticle(at: position)
        }

        // Report progress
        let progress = min(1.0, strokeTravel / Self.minTravelForStroke)
        onPettingEvent?(.strokeContinue(progress: progress, speed: speed))
    }

    /// Ends the current stroke.
    func endStroke(creatureFacing: Direction, currentTime: TimeInterval,
                   personalityEnergy: Double) {
        guard isActive else { return }
        isActive = false
        lastStrokeTime = currentTime

        // Remove ripple
        rippleNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
        rippleNode = nil

        // Check if this counts as a completed stroke
        guard strokeTravel >= Self.minTravelForStroke else { return }

        // Check against-grain rejection
        let maxAgainstGrain: Int
        if personalityEnergy > 0.6 {
            maxAgainstGrain = Self.againstGrainMaxStrokes
        } else {
            maxAgainstGrain = 1
        }

        if againstGrainCount >= maxAgainstGrain {
            onPettingEvent?(.rejection)
            strokeCount = 0
            againstGrainCount = 0
            return
        }

        strokeCount += 1
        onPettingEvent?(.strokeComplete(count: strokeCount))

        // Check for slow-blink trigger
        if strokeCount >= Self.slowBlinkStrokeCount {
            onPettingEvent?(.slowBlink)
            onPettingEvent?(.lieDown)
            onPettingEvent?(.purrIntensify(rate: Self.purrParticlesPerSecond * 2))
        }
    }

    /// Cancels the current stroke without completing it.
    func cancel() {
        isActive = false
        rippleNode?.removeFromParent()
        rippleNode = nil
    }

    // MARK: - Purr Particles

    private func emitPurrParticle(at position: CGPoint) {
        guard let parent = parentNode else { return }

        let particle = SKShapeNode(circleOfRadius: 1.0)
        particle.fillColor = PushlingPalette.gilt
        particle.strokeColor = .clear
        particle.alpha = 0.8
        particle.zPosition = 30
        particle.position = CGPoint(
            x: position.x + CGFloat.random(in: -5...5),
            y: position.y + CGFloat.random(in: -2...2)
        )
        parent.addChild(particle)

        let rise = SKAction.moveBy(x: CGFloat.random(in: -3...3),
                                    y: 8, duration: 0.6)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.4)
        let group = SKAction.group([rise, fade])
        particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }

    // MARK: - Reset

    /// Resets all stroke state (on scene transition or sleep).
    func reset() {
        isActive = false
        strokeCount = 0
        againstGrainCount = 0
        rippleNode?.removeFromParent()
        rippleNode = nil
    }
}
