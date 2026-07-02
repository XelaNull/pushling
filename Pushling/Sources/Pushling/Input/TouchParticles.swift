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

    // MARK: - Heart Burst

    /// Maximum number of concurrent heart bursts.
    private static var activeBursts = 0
    private static let maxConcurrentBursts = 2

    /// Emits a burst of 5-8 hearts simultaneously at the given position.
    /// Hearts rise with horizontal scatter, shrink from 6pt to 2pt, and fade over ~2s.
    /// Capped at `maxConcurrentBursts` concurrent bursts.
    static func emitHeartBurst(at position: CGPoint, in parent: SKNode) {
        guard activeBursts < maxConcurrentBursts else { return }
        activeBursts += 1

        let count = Int.random(in: 5...8)
        // Warm pink/red palette — ember base with slight variation toward rose
        let baseColors: [SKColor] = [
            PushlingPalette.ember,
            PushlingPalette.ember.withAlphaComponent(0.9),
            SKColor(red: 1.0, green: 0.35, blue: 0.45, alpha: 1.0),  // soft rose
            SKColor(red: 0.95, green: 0.25, blue: 0.3, alpha: 1.0),  // deep pink
        ]

        for i in 0..<count {
            let heart = SKLabelNode(text: "\u{2665}")
            heart.fontSize = 6
            heart.fontColor = baseColors.randomElement()!
            heart.position = CGPoint(
                x: position.x + CGFloat.random(in: -6...6),
                y: position.y
            )
            heart.zPosition = 50
            parent.addChild(heart)

            // Each heart gets independent horizontal drift and wobble phase
            // Rise slowly — Touch Bar is only 30pt tall, don't rush off screen
            let driftX = CGFloat.random(in: -6...6)
            let riseY: CGFloat = CGFloat.random(in: 6...10)
            let duration: TimeInterval = Double.random(in: 2.5...3.5)

            // Horizontal wobble: two sequential nudges for a sine-like feel
            let wobbleA = SKAction.moveBy(x: driftX * 0.4, y: riseY * 0.4, duration: duration * 0.35)
            wobbleA.timingMode = .easeOut
            let wobbleB = SKAction.moveBy(x: -driftX * 0.2, y: riseY * 0.35, duration: duration * 0.35)
            let wobbleC = SKAction.moveBy(x: driftX * 0.3, y: riseY * 0.25, duration: duration * 0.3)
            wobbleC.timingMode = .easeIn
            let rise = SKAction.sequence([wobbleA, wobbleB, wobbleC])

            // Scale from 6pt → 2pt (shrink factor 1/3)
            let shrink = SKAction.scale(to: 1.0 / 3.0, duration: duration)
            shrink.timingMode = .easeIn

            // Fade: hold briefly then fade out
            let hold = SKAction.wait(forDuration: duration * 0.3)
            let fade = SKAction.fadeOut(withDuration: duration * 0.7)
            let fadeSeq = SKAction.sequence([hold, fade])

            // Stagger start slightly so burst doesn't look perfectly simultaneous
            let delay = SKAction.wait(forDuration: Double(i) * 0.04)

            let burst = SKAction.group([rise, shrink, fadeSeq])

            // Last heart in burst decrements the counter on completion
            if i == count - 1 {
                heart.run(SKAction.sequence([delay, burst, SKAction.removeFromParent()])) {
                    activeBursts = max(0, activeBursts - 1)
                }
            } else {
                heart.run(SKAction.sequence([delay, burst, SKAction.removeFromParent()]))
            }
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
