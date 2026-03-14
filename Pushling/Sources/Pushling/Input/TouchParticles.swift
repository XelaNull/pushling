// TouchParticles.swift — Particle emission helpers for touch interactions
// Heart particles, finger trail sparkles, and touch feedback effects.
// Extracted from CreatureTouchHandler for file size compliance.

import SpriteKit

// MARK: - Touch Particles

/// Static helpers for emitting touch-related particle effects.
enum TouchParticles {

    /// Emits a rising heart particle at the given position.
    static func emitHeart(at position: CGPoint, in parent: SKNode,
                          multiplier: Double = 1.0) {
        let heart = SKLabelNode(text: "\u{2665}")  // Heart character
        let size: CGFloat = multiplier > 1.0 ? 8 : 6
        heart.fontSize = size
        heart.fontColor = PushlingPalette.ember
        heart.position = CGPoint(x: position.x, y: position.y + 2)
        heart.zPosition = 50
        parent.addChild(heart)

        let rise = SKAction.moveBy(x: 0, y: 10, duration: 0.8)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.6)
        heart.run(SKAction.sequence([
            SKAction.group([rise, fade]),
            SKAction.removeFromParent()
        ]))
    }

    /// Emits a finger trail sparkle particle (for 25-touch milestone).
    static func emitFingerTrail(at position: CGPoint, in parent: SKNode) {
        let spark = SKShapeNode(circleOfRadius: 0.6)
        spark.fillColor = PushlingPalette.gilt
        spark.strokeColor = .clear
        spark.alpha = 0.8
        spark.position = position
        spark.zPosition = 45
        parent.addChild(spark)

        let drift = SKAction.moveBy(
            x: CGFloat.random(in: -2...2),
            y: CGFloat.random(in: 1...4),
            duration: 0.4
        )
        let fade = SKAction.fadeOut(withDuration: 0.35)
        spark.run(SKAction.sequence([
            SKAction.group([drift, fade]),
            SKAction.removeFromParent()
        ]))
    }

    /// Emits a "we had a moment" sparkle ring (paying attention rewards).
    static func emitMomentRing(at position: CGPoint, in parent: SKNode) {
        for i in 0..<8 {
            let angle = CGFloat(i) / 8.0 * 2 * .pi
            let spark = SKShapeNode(circleOfRadius: 0.6)
            spark.fillColor = PushlingPalette.gilt
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 45
            parent.addChild(spark)

            let radius: CGFloat = 10
            let move = SKAction.moveBy(
                x: cos(angle) * radius,
                y: sin(angle) * radius,
                duration: 0.3
            )
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.25)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Emits a pre-contact purr indicator (500-touch milestone).
    static func emitPreContactPurr(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<3 {
            let purr = SKShapeNode(circleOfRadius: 0.5)
            purr.fillColor = PushlingPalette.gilt.withAlphaComponent(0.6)
            purr.strokeColor = .clear
            purr.position = CGPoint(
                x: position.x + CGFloat.random(in: -3...3),
                y: position.y + CGFloat.random(in: -1...1)
            )
            purr.zPosition = 40
            parent.addChild(purr)

            let rise = SKAction.moveBy(x: 0, y: 4, duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            purr.run(SKAction.sequence([
                SKAction.group([rise, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }
}
