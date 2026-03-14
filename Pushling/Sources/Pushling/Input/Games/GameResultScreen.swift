// GameResultScreen.swift — Post-game result display
// Shows score, personal best indicator, XP reward, and satisfaction boost.
// Auto-dismisses after 3 seconds or on any tap.

import SpriteKit

// MARK: - Game Result Screen

/// Renders the post-game result screen on the game layer.
/// Extracted from MiniGameManager for file size compliance.
enum GameResultScreen {

    /// Builds the result screen nodes and adds them to the layer.
    static func show(_ result: GameResult, in layer: SKNode,
                     sceneSize: CGSize) {
        // Clear existing game nodes
        layer.removeAllChildren()

        // Background dimming
        let bg = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width, height: sceneSize.height)
        )
        bg.fillColor = SKColor.black.withAlphaComponent(0.6)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: sceneSize.width / 2,
                               y: sceneSize.height / 2)
        layer.addChild(bg)

        // Game name (left)
        let nameLabel = SKLabelNode(fontNamed: "Menlo")
        nameLabel.fontSize = 6
        nameLabel.fontColor = PushlingPalette.bone
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 20, y: 15)
        nameLabel.text = result.gameType.displayName
        layer.addChild(nameLabel)

        // Score (center)
        let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 8
        scoreLabel.fontColor = PushlingPalette.gilt
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: sceneSize.width / 2, y: 15)
        scoreLabel.text = "Score: \(result.score)"
        layer.addChild(scoreLabel)

        // Personal best indicator
        if result.personalBest {
            let bestLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            bestLabel.fontSize = 6
            bestLabel.fontColor = PushlingPalette.gilt
            bestLabel.horizontalAlignmentMode = .center
            bestLabel.verticalAlignmentMode = .center
            bestLabel.position = CGPoint(x: sceneSize.width / 2, y: 6)
            bestLabel.text = "NEW BEST!"
            layer.addChild(bestLabel)

            // Flash animation
            let flash = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.3),
                SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            ])
            bestLabel.run(SKAction.repeatForever(flash))

            // Firework particles
            emitFireworks(at: CGPoint(x: sceneSize.width / 2, y: 15),
                          in: layer)
        }

        // XP + Satisfaction (right)
        let rewardLabel = SKLabelNode(fontNamed: "Menlo")
        rewardLabel.fontSize = 5
        rewardLabel.fontColor = PushlingPalette.tide
        rewardLabel.horizontalAlignmentMode = .right
        rewardLabel.verticalAlignmentMode = .center
        rewardLabel.position = CGPoint(x: sceneSize.width - 20, y: 15)
        rewardLabel.text = "+\(result.xpAwarded) XP  +\(result.satisfactionBoost) SAT"
        layer.addChild(rewardLabel)
    }

    /// Emits firework particles for personal best celebration.
    private static func emitFireworks(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: 0.8)
            spark.fillColor = PushlingPalette.gilt
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 15
            parent.addChild(spark)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 5...15)
            let move = SKAction.moveBy(
                x: cos(angle) * dist,
                y: sin(angle) * dist,
                duration: 0.5
            )
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.4)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }
}
