// CatchGame.swift — Stars fall from top, tap to move creature to catch them
// Duration: 30 seconds. Spawn rate increases over time.
// Tap left/right of creature for burst movement (50pt/sec for 0.3s).
// Stars caught = score. Missed stars = dust puff, no penalty.

import SpriteKit

// MARK: - Catch Game

/// Stars fall from the top of the Touch Bar; move the creature to catch them.
/// Fully implemented mini-game with scoring, difficulty ramp, and particles.
final class CatchGame: MiniGame {

    // MARK: - MiniGame Protocol

    let gameType: MiniGameType = .catchStars
    var isComplete: Bool { elapsed >= gameDuration }
    private(set) var score: Int = 0
    var duration: TimeInterval { elapsed }

    // MARK: - Constants

    private let gameDuration: TimeInterval = 30.0
    private let starRadius: CGFloat = 1.5
    private let starFallSpeed: CGFloat = 40.0
    private let creatureMoveSpeed: CGFloat = 50.0
    private let moveBurstDuration: TimeInterval = 0.3
    private let catchHitboxPadding: CGFloat = 4.0
    private let initialSpawnInterval: TimeInterval = 2.0
    private let finalSpawnInterval: TimeInterval = 0.8
    private let starTwinklePeriod: TimeInterval = 0.5

    // MARK: - State

    private var elapsed: TimeInterval = 0
    private var spawnTimer: TimeInterval = 0
    private var creatureX: CGFloat = SceneConstants.sceneWidth / 2
    private var creatureWidth: CGFloat = 14.0
    private var moveVelocity: CGFloat = 0
    private var moveTimer: TimeInterval = 0
    private var stars: [StarNode] = []
    private weak var parentNode: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Star Node

    private class StarNode {
        let node: SKShapeNode
        var y: CGFloat
        let x: CGFloat

        init(node: SKShapeNode, x: CGFloat, y: CGFloat) {
            self.node = node
            self.x = x
            self.y = y
        }
    }

    // MARK: - Setup

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent
        self.sceneSize = sceneSize
        score = 0
        elapsed = 0
        spawnTimer = 0
        creatureX = sceneSize.width / 2
        stars = []

        // Creature indicator (simple bar at bottom)
        let indicator = SKShapeNode(
            rectOf: CGSize(width: creatureWidth, height: 4),
            cornerRadius: 1
        )
        indicator.fillColor = PushlingPalette.bone
        indicator.strokeColor = .clear
        indicator.position = CGPoint(x: creatureX, y: 2)
        indicator.name = "catch_creature"
        indicator.zPosition = 5
        parent.addChild(indicator)

        // Score label
        let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 6
        scoreLabel.fontColor = PushlingPalette.gilt
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: sceneSize.width - 10, y: sceneSize.height - 2)
        scoreLabel.name = "catch_score"
        scoreLabel.text = "0"
        scoreLabel.zPosition = 10
        parent.addChild(scoreLabel)

        // Timer bar (thin line at top)
        let timerBar = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width, height: 1)
        )
        timerBar.fillColor = PushlingPalette.tide.withAlphaComponent(0.5)
        timerBar.strokeColor = .clear
        timerBar.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height - 1)
        timerBar.name = "catch_timer"
        timerBar.zPosition = 10
        parent.addChild(timerBar)
    }

    func start() {
        NSLog("[Pushling/Game] Catch game started")
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime

        // Update timer bar
        let progress = 1.0 - CGFloat(elapsed / gameDuration)
        if let timer = parentNode?.childNode(withName: "catch_timer") {
            timer.xScale = max(0, progress)
        }

        // Creature movement
        if moveTimer > 0 {
            moveTimer -= deltaTime
            creatureX += moveVelocity * CGFloat(deltaTime)
            creatureX = clamp(creatureX, min: 10, max: sceneSize.width - 10)

            if let creature = parentNode?.childNode(withName: "catch_creature") {
                creature.position.x = creatureX
            }
        }

        // Spawn stars
        let spawnInterval = lerp(
            initialSpawnInterval, finalSpawnInterval,
            min(1.0, elapsed / gameDuration)
        )
        spawnTimer += deltaTime
        if spawnTimer >= spawnInterval {
            spawnTimer = 0
            spawnStar()
        }

        // Update falling stars
        updateStars(deltaTime: deltaTime)
    }

    // MARK: - Input

    func handleTap(at position: CGPoint) {
        // Move creature toward tap
        if position.x < creatureX {
            moveVelocity = -creatureMoveSpeed
        } else {
            moveVelocity = creatureMoveSpeed
        }
        moveTimer = moveBurstDuration
    }

    // MARK: - Star Spawning

    private func spawnStar() {
        guard let parent = parentNode else { return }

        let x = CGFloat.random(in: 20...(sceneSize.width - 20))
        let y = sceneSize.height

        let star = SKShapeNode(circleOfRadius: starRadius)
        star.fillColor = PushlingPalette.gilt
        star.strokeColor = .clear
        star.position = CGPoint(x: x, y: y)
        star.zPosition = 3
        star.name = "falling_star"

        // Twinkle animation
        let twinkle = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: starTwinklePeriod / 2),
            SKAction.fadeAlpha(to: 1.0, duration: starTwinklePeriod / 2)
        ])
        star.run(SKAction.repeatForever(twinkle))

        parent.addChild(star)
        stars.append(StarNode(node: star, x: x, y: y))
    }

    // MARK: - Star Update

    private func updateStars(deltaTime: TimeInterval) {
        var caughtIndices: [Int] = []
        var missedIndices: [Int] = []

        let catchLeft = creatureX - creatureWidth / 2 - catchHitboxPadding
        let catchRight = creatureX + creatureWidth / 2 + catchHitboxPadding

        for i in stars.indices {
            stars[i].y -= starFallSpeed * CGFloat(deltaTime)
            stars[i].node.position.y = stars[i].y

            // Check catch (star hits creature hitbox at ground level)
            if stars[i].y <= 6
                && stars[i].node.position.x >= catchLeft
                && stars[i].node.position.x <= catchRight {
                caughtIndices.append(i)
                continue
            }

            // Check miss (hit ground)
            if stars[i].y <= 0 {
                missedIndices.append(i)
            }
        }

        // Process caught stars (reverse order)
        for i in caughtIndices.reversed() {
            let star = stars[i]
            score += 1
            updateScoreLabel()

            // Catch effect: absorb sparkle
            star.node.removeAllActions()
            let absorb = SKAction.group([
                SKAction.scale(to: 0.1, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15)
            ])
            star.node.run(SKAction.sequence([absorb, SKAction.removeFromParent()]))

            stars.remove(at: i)
        }

        // Process missed stars (reverse order)
        for i in missedIndices.reversed() {
            let star = stars[i]

            // Miss effect: puff
            emitMissPuff(at: CGPoint(x: star.node.position.x, y: 1))

            star.node.removeAllActions()
            star.node.removeFromParent()
            stars.remove(at: i)
        }
    }

    private func updateScoreLabel() {
        if let label = parentNode?.childNode(withName: "catch_score")
            as? SKLabelNode {
            label.text = "\(score)"
        }
    }

    private func emitMissPuff(at position: CGPoint) {
        guard let parent = parentNode else { return }

        for _ in 0..<3 {
            let puff = SKShapeNode(circleOfRadius: 0.8)
            puff.fillColor = PushlingPalette.ash
            puff.strokeColor = .clear
            puff.alpha = 0.5
            puff.position = position
            puff.zPosition = 2
            parent.addChild(puff)

            let move = SKAction.moveBy(
                x: CGFloat.random(in: -3...3),
                y: CGFloat.random(in: 1...4),
                duration: 0.3
            )
            let fade = SKAction.fadeOut(withDuration: 0.25)
            puff.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Teardown

    func teardown() {
        stars.removeAll()
        parentNode?.removeAllChildren()
    }
}
