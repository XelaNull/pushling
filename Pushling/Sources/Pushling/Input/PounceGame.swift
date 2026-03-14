// PounceGame.swift — 3+ rapid taps near creature trigger hunt-and-pounce
// Each tap creates a dust puff. After 3rd tap: predator crouch, butt wiggle,
// pounce at last tap. Tap the landing spot within 0.3s for CATCH.

import SpriteKit

// MARK: - Pounce Game

/// Manages the rapid-tap pounce interaction — a quick reflex game
/// embedded in the normal touch flow (not a full mini-game).
final class PounceGame {

    // MARK: - Constants

    private static let crouchDelay: TimeInterval = 0.3
    private static let pounceDuration: TimeInterval = 0.4
    private static let catchWindow: TimeInterval = 0.3
    private static let creatureProximity: CGFloat = 50.0
    private static let dustParticleCount = 4
    private static let catchSparkleCount = 20
    private static let satisfactionReward = 5

    // MARK: - State

    enum Phase {
        case idle
        case hunting(targetX: CGFloat)
        case pouncing(targetX: CGFloat, landTime: TimeInterval)
        case catchWindow(targetX: CGFloat, deadline: TimeInterval)
    }

    private(set) var phase: Phase = .idle
    private var lastTapPosition: CGPoint = .zero

    /// Callback for creature behavior.
    var onPounceEvent: ((PounceEvent) -> Void)?

    // MARK: - Pounce Events

    enum PounceEvent {
        case huntMode(targetX: CGFloat)
        case pounce(targetX: CGFloat)
        case caught(position: CGPoint)
        case missed
        case dustPuff(position: CGPoint)
    }

    // MARK: - Trigger

    /// Called when rapid taps are detected near the creature.
    func triggerHunt(at position: CGPoint, creatureX: CGFloat,
                     in parent: SKNode, currentTime: TimeInterval) {
        guard case .idle = phase else { return }

        // Verify proximity to creature
        guard abs(position.x - creatureX) < Self.creatureProximity else { return }

        lastTapPosition = position
        phase = .hunting(targetX: position.x)

        // Create dust puff at tap location
        emitDustPuff(at: position, in: parent)

        // Trigger hunt mode after a beat
        onPounceEvent?(.huntMode(targetX: position.x))

        // Schedule pounce
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.crouchDelay
        ) { [weak self] in
            self?.executePounce(at: position, currentTime: currentTime)
        }

        NSLog("[Pushling/Input] Pounce game: hunt mode at X=%.1f", position.x)
    }

    // MARK: - Pounce Execution

    private func executePounce(at target: CGPoint,
                               currentTime: TimeInterval) {
        guard case .hunting = phase else { return }

        let landTime = currentTime + Self.pounceDuration
        phase = .pouncing(targetX: target.x, landTime: landTime)
        onPounceEvent?(.pounce(targetX: target.x))

        // After pounce lands, open catch window
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.pounceDuration
        ) { [weak self] in
            guard let self = self else { return }
            guard case .pouncing(let targetX, _) = self.phase else { return }

            let deadline = currentTime + Self.pounceDuration + Self.catchWindow
            self.phase = .catchWindow(targetX: targetX, deadline: deadline)

            // After catch window closes, handle miss
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.catchWindow
            ) { [weak self] in
                guard let self = self else { return }
                if case .catchWindow = self.phase {
                    self.phase = .idle
                    self.onPounceEvent?(.missed)
                }
            }
        }
    }

    // MARK: - Catch Attempt

    /// Called when a tap occurs during the catch window.
    /// - Returns: Whether the catch was successful.
    func attemptCatch(at tapPosition: CGPoint,
                      in parent: SKNode) -> Bool {
        guard case .catchWindow(let targetX, _) = phase else { return false }

        // Check if tap is near the pounce landing spot
        let distance = abs(tapPosition.x - targetX)
        if distance < 20 {
            // CATCH!
            phase = .idle
            emitCatchSparkles(at: tapPosition, in: parent)
            onPounceEvent?(.caught(position: tapPosition))
            NSLog("[Pushling/Input] Pounce game: CATCH!")
            return true
        }

        return false
    }

    // MARK: - Particles

    /// Creates dust puff at tap location.
    func emitDustPuff(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<Self.dustParticleCount {
            let dust = SKShapeNode(circleOfRadius: 1.0)
            dust.fillColor = PushlingPalette.ash
            dust.strokeColor = .clear
            dust.alpha = 0.6
            dust.position = CGPoint(
                x: position.x + CGFloat.random(in: -4...4),
                y: position.y + CGFloat.random(in: -2...2)
            )
            dust.zPosition = 30
            parent.addChild(dust)

            let drift = SKAction.moveBy(
                x: CGFloat.random(in: -5...5),
                y: CGFloat.random(in: 2...6),
                duration: 0.3
            )
            let fade = SKAction.fadeOut(withDuration: 0.25)
            dust.run(SKAction.sequence([
                SKAction.group([drift, fade]),
                SKAction.removeFromParent()
            ]))
        }

        onPounceEvent?(.dustPuff(position: position))
    }

    private func emitCatchSparkles(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<Self.catchSparkleCount {
            let sparkle = SKShapeNode(circleOfRadius: 0.8)
            sparkle.fillColor = PushlingPalette.gilt
            sparkle.strokeColor = .clear
            sparkle.position = position
            sparkle.zPosition = 40
            parent.addChild(sparkle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 5...15)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.4)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.3)
            sparkle.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Reset

    func reset() {
        phase = .idle
    }
}
