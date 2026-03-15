// TreasureHuntGame.swift — Hot/cold treasure hunt across the Touch Bar
// Duration: 60 seconds. Treasure hidden at random X position.
// Player taps left/right of cursor to move it. Temperature indicator shows
// proximity: blue (cold) → green (warm) → red (hot). Dig when close.
// Score = 100 - distance penalty - time penalty. Multiple treasures possible.

import SpriteKit

// MARK: - Treasure Hunt Game

/// The creature hides treasure at a random position along the Touch Bar.
/// The player swipes/taps to move a cursor. A temperature indicator shows
/// proximity. Tap directly on the cursor to "dig" when close enough.
final class TreasureHuntGame: MiniGame {

    // MARK: - MiniGame Protocol

    let gameType: MiniGameType = .treasureHunt
    var isComplete: Bool { elapsed >= gameDuration }
    private(set) var score: Int = 0
    var duration: TimeInterval { elapsed }

    // MARK: - Constants

    private let gameDuration: TimeInterval = 60.0
    private let cursorWidth: CGFloat = 8.0
    private let cursorHeight: CGFloat = 18.0
    private let moveSpeed: CGFloat = 120.0
    private let moveBurstDuration: TimeInterval = 0.25
    private let digRadius: CGFloat = 30.0
    private let findRadius: CGFloat = 25.0
    private let margin: CGFloat = 50.0
    private let tempBarWidth: CGFloat = 60.0
    private let tempBarHeight: CGFloat = 3.0
    private let maxDistForHot: CGFloat = 300.0

    // Scoring
    private let baseTreasureScore = 40
    private let timeBonus = 10          // Per treasure, scaled by remaining time
    private let closenessBonus = 15     // Scaled by how close the dig was

    // MARK: - State

    private var elapsed: TimeInterval = 0
    private var cursorX: CGFloat = 0
    private var treasureX: CGFloat = 0
    private var moveVelocity: CGFloat = 0
    private var moveTimer: TimeInterval = 0
    private var treasuresFound = 0
    private var totalTreasures = 3
    private var currentTreasure = 0
    private var digging = false
    private var digTimer: TimeInterval = 0
    private var showFoundEffect = false
    private var foundEffectTimer: TimeInterval = 0
    private weak var parentNode: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Setup

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent
        self.sceneSize = sceneSize
        score = 0
        elapsed = 0
        treasuresFound = 0
        currentTreasure = 0
        digging = false
        cursorX = sceneSize.width / 2

        // Place first treasure
        placeTreasure()

        // Cursor (inverted triangle / arrow pointing down)
        let cursor = SKShapeNode(
            rectOf: CGSize(width: cursorWidth, height: cursorHeight),
            cornerRadius: 2
        )
        cursor.fillColor = PushlingPalette.bone.withAlphaComponent(0.8)
        cursor.strokeColor = .clear
        cursor.position = CGPoint(x: cursorX, y: sceneSize.height / 2)
        cursor.zPosition = 5
        cursor.name = "hunt_cursor"
        parent.addChild(cursor)

        // Temperature bar background
        let tempBg = SKShapeNode(
            rectOf: CGSize(width: tempBarWidth, height: tempBarHeight),
            cornerRadius: 1
        )
        tempBg.fillColor = PushlingPalette.ash.withAlphaComponent(0.3)
        tempBg.strokeColor = .clear
        tempBg.position = CGPoint(x: sceneSize.width / 2, y: 3)
        tempBg.zPosition = 8
        tempBg.name = "hunt_temp_bg"
        parent.addChild(tempBg)

        // Temperature bar fill
        let tempFill = SKShapeNode(
            rectOf: CGSize(width: 1, height: tempBarHeight),
            cornerRadius: 1
        )
        tempFill.fillColor = PushlingPalette.tide
        tempFill.strokeColor = .clear
        tempFill.position = CGPoint(x: sceneSize.width / 2 - tempBarWidth / 2,
                                     y: 3)
        tempFill.zPosition = 9
        tempFill.name = "hunt_temp_fill"
        parent.addChild(tempFill)

        // Temperature label
        let tempLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        tempLabel.fontSize = 6
        tempLabel.fontColor = PushlingPalette.tide
        tempLabel.horizontalAlignmentMode = .center
        tempLabel.verticalAlignmentMode = .center
        tempLabel.position = CGPoint(x: sceneSize.width / 2,
                                      y: sceneSize.height / 2)
        tempLabel.name = "hunt_temp_label"
        tempLabel.text = ""
        tempLabel.zPosition = 12
        parent.addChild(tempLabel)

        // Score label
        let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 6
        scoreLabel.fontColor = PushlingPalette.gilt
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: sceneSize.width - 10,
                                       y: sceneSize.height - 2)
        scoreLabel.name = "hunt_score"
        scoreLabel.text = "0"
        scoreLabel.zPosition = 10
        parent.addChild(scoreLabel)

        // Treasure counter
        let counterLabel = SKLabelNode(fontNamed: "Menlo")
        counterLabel.fontSize = 5
        counterLabel.fontColor = PushlingPalette.bone
        counterLabel.horizontalAlignmentMode = .left
        counterLabel.verticalAlignmentMode = .top
        counterLabel.position = CGPoint(x: 10, y: sceneSize.height - 2)
        counterLabel.name = "hunt_counter"
        counterLabel.text = "\(treasuresFound)/\(totalTreasures)"
        counterLabel.zPosition = 10
        parent.addChild(counterLabel)

        // Timer bar
        let timerBar = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width, height: 1)
        )
        timerBar.fillColor = PushlingPalette.tide.withAlphaComponent(0.5)
        timerBar.strokeColor = .clear
        timerBar.position = CGPoint(x: sceneSize.width / 2,
                                     y: sceneSize.height - 1)
        timerBar.name = "hunt_timer"
        timerBar.zPosition = 10
        parent.addChild(timerBar)

        // Ground dots — hint that there's terrain to explore
        for i in stride(from: margin, to: sceneSize.width - margin, by: 30) {
            let dot = SKShapeNode(circleOfRadius: 0.5)
            dot.fillColor = PushlingPalette.ash.withAlphaComponent(0.3)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: i, y: sceneSize.height / 2 - 10)
            dot.zPosition = 1
            parent.addChild(dot)
        }
    }

    func start() {
        NSLog("[Pushling/Game] Treasure Hunt started")
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime

        // Update timer bar
        let progress = 1.0 - CGFloat(elapsed / gameDuration)
        if let timer = parentNode?.childNode(withName: "hunt_timer") {
            timer.xScale = max(0, progress)
        }

        // Cursor movement
        if moveTimer > 0 {
            moveTimer -= deltaTime
            cursorX += moveVelocity * CGFloat(deltaTime)
            cursorX = clamp(cursorX, min: margin, max: sceneSize.width - margin)

            if let cursor = parentNode?.childNode(withName: "hunt_cursor") {
                cursor.position.x = cursorX
            }
        }

        // Update temperature display
        if currentTreasure < totalTreasures {
            updateTemperature()
        }

        // Found effect timer
        if showFoundEffect {
            foundEffectTimer += deltaTime
            if foundEffectTimer >= 1.0 {
                showFoundEffect = false
                foundEffectTimer = 0
                if currentTreasure < totalTreasures {
                    placeTreasure()
                    updateTemperature()
                }
            }
        }
    }

    // MARK: - Input

    func handleTap(at position: CGPoint) {
        guard !showFoundEffect else { return }
        guard currentTreasure < totalTreasures else { return }

        let distToCursor = abs(position.x - cursorX)

        // If tapping near the cursor, attempt to dig
        if distToCursor < digRadius {
            attemptDig()
            return
        }

        // Otherwise, move cursor toward tap
        if position.x < cursorX {
            moveVelocity = -moveSpeed
        } else {
            moveVelocity = moveSpeed
        }
        moveTimer = moveBurstDuration
    }

    // MARK: - Digging

    private func attemptDig() {
        let distance = abs(cursorX - treasureX)

        if distance <= findRadius {
            // Found the treasure
            treasuresFound += 1
            currentTreasure += 1

            // Calculate score for this find
            let closenessRatio = 1.0 - (distance / findRadius)
            let timeRatio = 1.0 - (elapsed / gameDuration)
            let points = baseTreasureScore
                + Int(CGFloat(closenessBonus) * closenessRatio)
                + Int(CGFloat(timeBonus) * CGFloat(timeRatio))

            score += max(1, points)
            updateScoreLabel()
            updateCounterLabel()
            showFoundAnimation()

            NSLog("[Pushling/Game] Treasure found! Distance: %.1f, Points: %d",
                  distance, points)
        } else {
            // Miss — show a "nothing here" puff
            showMissDig()
        }
    }

    // MARK: - Temperature Display

    private func updateTemperature() {
        let distance = abs(cursorX - treasureX)
        let proximity = max(0, 1.0 - distance / maxDistForHot)

        // Temperature color: tide (cold) → moss (warm) → ember (hot)
        let tempColor: SKColor
        let tempText: String

        if proximity < 0.3 {
            tempColor = PushlingPalette.tide
            tempText = "COLD"
        } else if proximity < 0.5 {
            tempColor = PushlingPalette.tide
            tempText = "COOL"
        } else if proximity < 0.7 {
            tempColor = PushlingPalette.moss
            tempText = "WARM"
        } else if proximity < 0.85 {
            tempColor = PushlingPalette.gilt
            tempText = "HOT"
        } else {
            tempColor = PushlingPalette.ember
            tempText = "BURNING!"
        }

        // Update fill bar width
        if let fill = parentNode?.childNode(withName: "hunt_temp_fill")
            as? SKShapeNode {
            let fillWidth = max(1, proximity * tempBarWidth)
            let path = CGMutablePath()
            path.addRoundedRect(
                in: CGRect(x: -fillWidth / 2, y: -tempBarHeight / 2,
                           width: fillWidth, height: tempBarHeight),
                cornerWidth: 1, cornerHeight: 1
            )
            fill.path = path
            fill.fillColor = tempColor
            fill.position.x = sceneSize.width / 2
        }

        // Update label
        if let label = parentNode?.childNode(withName: "hunt_temp_label")
            as? SKLabelNode {
            label.text = tempText
            label.fontColor = tempColor
        }

        // Cursor color follows temperature
        if let cursor = parentNode?.childNode(withName: "hunt_cursor")
            as? SKShapeNode {
            cursor.fillColor = tempColor.withAlphaComponent(0.8)
        }
    }

    // MARK: - Visual Effects

    private func showFoundAnimation() {
        guard let parent = parentNode else { return }

        showFoundEffect = true
        foundEffectTimer = 0

        // Flash the treasure location
        let treasure = SKShapeNode(circleOfRadius: 4)
        treasure.fillColor = PushlingPalette.gilt
        treasure.strokeColor = .clear
        treasure.position = CGPoint(x: treasureX, y: sceneSize.height / 2)
        treasure.zPosition = 15
        parent.addChild(treasure)

        // Treasure sparkle burst
        for _ in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 0.8)
            spark.fillColor = PushlingPalette.gilt
            spark.strokeColor = .clear
            spark.position = treasure.position
            spark.zPosition = 14
            parent.addChild(spark)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 4...12)
            let move = SKAction.moveBy(
                x: cos(angle) * dist,
                y: sin(angle) * dist,
                duration: 0.4
            )
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.35)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }

        // Treasure node fades out
        let pop = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        treasure.run(pop)

        // Show "FOUND!" text
        let foundLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        foundLabel.fontSize = 7
        foundLabel.fontColor = PushlingPalette.gilt
        foundLabel.horizontalAlignmentMode = .center
        foundLabel.verticalAlignmentMode = .center
        foundLabel.position = CGPoint(x: treasureX,
                                       y: sceneSize.height / 2 + 8)
        foundLabel.zPosition = 16
        foundLabel.text = "FOUND!"
        parent.addChild(foundLabel)

        let rise = SKAction.moveBy(x: 0, y: 4, duration: 0.6)
        rise.timingMode = .easeOut
        foundLabel.run(SKAction.sequence([
            SKAction.group([rise, SKAction.fadeOut(withDuration: 0.5)]),
            SKAction.removeFromParent()
        ]))

        // Update temperature label
        if let label = parentNode?.childNode(withName: "hunt_temp_label")
            as? SKLabelNode {
            label.text = currentTreasure >= totalTreasures ? "ALL FOUND!" : ""
        }
    }

    private func showMissDig() {
        guard let parent = parentNode else { return }

        // Small dust puff at cursor position
        for _ in 0..<3 {
            let puff = SKShapeNode(circleOfRadius: 0.8)
            puff.fillColor = PushlingPalette.ash
            puff.strokeColor = .clear
            puff.alpha = 0.5
            puff.position = CGPoint(x: cursorX,
                                     y: sceneSize.height / 2 - 4)
            puff.zPosition = 6
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

    // MARK: - Treasure Placement

    private func placeTreasure() {
        // Random position, avoiding edges and current cursor position
        var attempts = 0
        repeat {
            treasureX = CGFloat.random(
                in: margin...(sceneSize.width - margin)
            )
            attempts += 1
        } while abs(treasureX - cursorX) < 100 && attempts < 20
    }

    // MARK: - UI Updates

    private func updateScoreLabel() {
        if let label = parentNode?.childNode(withName: "hunt_score")
            as? SKLabelNode {
            label.text = "\(score)"
        }
    }

    private func updateCounterLabel() {
        if let label = parentNode?.childNode(withName: "hunt_counter")
            as? SKLabelNode {
            label.text = "\(treasuresFound)/\(totalTreasures)"
        }
    }

    // MARK: - Teardown

    func teardown() {
        parentNode?.removeAllChildren()
    }
}
