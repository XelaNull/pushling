// TugOfWarGame.swift — Human vs creature, rapid-tap tug of war
// Duration: 30 seconds. Marker starts at center. Player taps pull left,
// creature "pulls" right automatically. Creature subtly cheats: its pull
// force is tuned so human wins ~55% of the time (45% creature lean).
// Score: 1 = human wins (marker left of center), 0 = creature wins.

import SpriteKit

// MARK: - Tug of War Game

/// Rapid-tap tug of war across the Touch Bar. Each player tap pulls the
/// marker left. The creature pulls right automatically. The marker's
/// final position determines the winner.
final class TugOfWarGame: MiniGame {

    // MARK: - MiniGame Protocol

    let gameType: MiniGameType = .tugOfWar
    var isComplete: Bool { elapsed >= gameDuration }
    private(set) var score: Int = 0  // 1 = human win, 0 = creature win
    var duration: TimeInterval { elapsed }

    // MARK: - Constants

    private let gameDuration: TimeInterval = 30.0
    private let ropeY: CGFloat = 15.0        // Center of Touch Bar
    private let markerWidth: CGFloat = 6.0
    private let markerHeight: CGFloat = 20.0
    private let ropeHeight: CGFloat = 2.0

    // Pull mechanics
    private let humanPullForce: CGFloat = 18.0       // Pixels per tap
    private let creaturePullBase: CGFloat = 6.0       // Base pull per second
    private let creaturePullMax: CGFloat = 14.0       // Max pull per second
    private let creatureSurgeChance: Double = 0.08    // 8% per second surge
    private let creatureSurgeForce: CGFloat = 25.0    // Big pull on surge
    private let friction: CGFloat = 0.92              // Velocity decay per frame
    private let snapbackForce: CGFloat = 2.0          // Gentle pull toward center
    private let tapDecay: TimeInterval = 0.5          // Tap power decays

    // Zone markers
    private let humanWinZone: CGFloat = 0.3   // Left 30% = human winning clearly
    private let creatureWinZone: CGFloat = 0.7 // Right 30% = creature winning

    // MARK: - State

    private var elapsed: TimeInterval = 0
    private var markerX: CGFloat = 0
    private var markerVelocity: CGFloat = 0
    private var centerX: CGFloat = 0
    private var lastTapTime: TimeInterval = 0
    private var tapCount = 0
    private var tapsPerSecond: CGFloat = 0
    private var tapWindow: [TimeInterval] = []
    private var creaturePullRate: CGFloat = 0
    private var surgeTimer: TimeInterval = 0
    private var creatureSurging = false
    private var surgeDuration: TimeInterval = 0
    private weak var parentNode: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Setup

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent
        self.sceneSize = sceneSize
        score = 0
        elapsed = 0
        tapCount = 0
        tapsPerSecond = 0
        tapWindow = []
        markerVelocity = 0
        creaturePullRate = creaturePullBase
        creatureSurging = false
        centerX = sceneSize.width / 2
        markerX = centerX

        // Rope (horizontal line across Touch Bar)
        let rope = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width - 60, height: ropeHeight),
            cornerRadius: 1
        )
        rope.fillColor = PushlingPalette.ash
        rope.strokeColor = .clear
        rope.position = CGPoint(x: centerX, y: ropeY)
        rope.zPosition = 2
        rope.name = "tow_rope"
        parent.addChild(rope)

        // Zone indicators — left (human) and right (creature)
        let humanZone = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width * humanWinZone - 30,
                          height: 4),
            cornerRadius: 1
        )
        humanZone.fillColor = PushlingPalette.moss.withAlphaComponent(0.15)
        humanZone.strokeColor = .clear
        humanZone.position = CGPoint(
            x: 30 + (sceneSize.width * humanWinZone - 30) / 2,
            y: ropeY
        )
        humanZone.zPosition = 1
        parent.addChild(humanZone)

        let creatureZone = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width * (1 - creatureWinZone) - 30,
                          height: 4),
            cornerRadius: 1
        )
        creatureZone.fillColor = PushlingPalette.ember.withAlphaComponent(0.15)
        creatureZone.strokeColor = .clear
        creatureZone.position = CGPoint(
            x: sceneSize.width * creatureWinZone
                + (sceneSize.width * (1 - creatureWinZone) - 30) / 2,
            y: ropeY
        )
        creatureZone.zPosition = 1
        parent.addChild(creatureZone)

        // Center mark
        let centerMark = SKShapeNode(
            rectOf: CGSize(width: 1, height: 8)
        )
        centerMark.fillColor = PushlingPalette.bone.withAlphaComponent(0.3)
        centerMark.strokeColor = .clear
        centerMark.position = CGPoint(x: centerX, y: ropeY)
        centerMark.zPosition = 3
        parent.addChild(centerMark)

        // Marker (the contested point)
        let marker = SKShapeNode(
            rectOf: CGSize(width: markerWidth, height: markerHeight),
            cornerRadius: 2
        )
        marker.fillColor = PushlingPalette.gilt
        marker.strokeColor = .clear
        marker.position = CGPoint(x: markerX, y: ropeY)
        marker.zPosition = 6
        marker.name = "tow_marker"
        parent.addChild(marker)

        // Human side label (left)
        let humanLabel = SKLabelNode(fontNamed: "Menlo")
        humanLabel.fontSize = 5
        humanLabel.fontColor = PushlingPalette.moss
        humanLabel.horizontalAlignmentMode = .left
        humanLabel.verticalAlignmentMode = .center
        humanLabel.position = CGPoint(x: 10, y: ropeY + 10)
        humanLabel.text = "YOU"
        humanLabel.zPosition = 8
        parent.addChild(humanLabel)

        // Creature side label (right)
        let creatureLabel = SKLabelNode(fontNamed: "Menlo")
        creatureLabel.fontSize = 5
        creatureLabel.fontColor = PushlingPalette.ember
        creatureLabel.horizontalAlignmentMode = .right
        creatureLabel.verticalAlignmentMode = .center
        creatureLabel.position = CGPoint(x: sceneSize.width - 10,
                                          y: ropeY + 10)
        creatureLabel.text = "PET"
        creatureLabel.zPosition = 8
        parent.addChild(creatureLabel)

        // Status text (center bottom)
        let statusLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        statusLabel.fontSize = 5
        statusLabel.fontColor = PushlingPalette.bone
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .bottom
        statusLabel.position = CGPoint(x: centerX, y: 1)
        statusLabel.name = "tow_status"
        statusLabel.text = "TAP!"
        statusLabel.zPosition = 10
        parent.addChild(statusLabel)

        // Timer bar
        let timerBar = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width, height: 1)
        )
        timerBar.fillColor = PushlingPalette.tide.withAlphaComponent(0.5)
        timerBar.strokeColor = .clear
        timerBar.position = CGPoint(x: centerX, y: sceneSize.height - 1)
        timerBar.name = "tow_timer"
        timerBar.zPosition = 10
        parent.addChild(timerBar)

        // Tap counter
        let tapLabel = SKLabelNode(fontNamed: "Menlo")
        tapLabel.fontSize = 5
        tapLabel.fontColor = PushlingPalette.ash
        tapLabel.horizontalAlignmentMode = .left
        tapLabel.verticalAlignmentMode = .bottom
        tapLabel.position = CGPoint(x: 10, y: 1)
        tapLabel.name = "tow_taps"
        tapLabel.text = ""
        tapLabel.zPosition = 10
        parent.addChild(tapLabel)
    }

    func start() {
        NSLog("[Pushling/Game] Tug of War started")
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime
        let dt = CGFloat(deltaTime)

        // Update timer bar
        let progress = 1.0 - CGFloat(elapsed / gameDuration)
        if let timer = parentNode?.childNode(withName: "tow_timer") {
            timer.xScale = max(0, progress)
        }

        // Calculate taps per second from recent window
        updateTapRate()

        // Creature pull — ramps up over time with the 55/45 lean
        let timeRamp = CGFloat(min(1.0, elapsed / (gameDuration * 0.6)))
        creaturePullRate = creaturePullBase
            + (creaturePullMax - creaturePullBase) * timeRamp

        // Creature surge mechanic — occasional big pulls to add excitement
        updateCreatureSurge(deltaTime: deltaTime)

        // Apply creature pull (rightward = positive X)
        var creaturePull = creaturePullRate * dt
        if creatureSurging {
            creaturePull += creatureSurgeForce * dt
        }
        markerVelocity += creaturePull

        // Apply friction
        markerVelocity *= friction

        // Gentle snapback toward center when nobody is pulling hard
        if tapsPerSecond < 1 && !creatureSurging {
            let distFromCenter = markerX - centerX
            markerVelocity -= distFromCenter * snapbackForce * dt * 0.01
        }

        // Update position
        markerX += markerVelocity * dt

        // Clamp to bounds
        let minX: CGFloat = 35
        let maxX: CGFloat = sceneSize.width - 35
        if markerX < minX {
            markerX = minX
            markerVelocity = 0
        } else if markerX > maxX {
            markerX = maxX
            markerVelocity = 0
        }

        // Update marker node
        if let marker = parentNode?.childNode(withName: "tow_marker") {
            marker.position.x = markerX
        }

        // Update marker color based on position
        updateMarkerColor()

        // Update status text
        updateStatusText()

        // Check for game end — calculate score
        if elapsed >= gameDuration {
            score = markerX < centerX ? 1 : 0
            showEndEffect()
        }
    }

    // MARK: - Input

    func handleTap(at position: CGPoint) {
        guard elapsed < gameDuration else { return }

        tapCount += 1
        lastTapTime = elapsed
        tapWindow.append(elapsed)

        // Human pull (leftward = negative X)
        markerVelocity -= humanPullForce

        // Tap flash effect at cursor
        showTapEffect(at: position)

        // Update tap counter
        if let label = parentNode?.childNode(withName: "tow_taps")
            as? SKLabelNode {
            label.text = "\(tapCount) taps"
        }
    }

    // MARK: - Creature AI

    private func updateCreatureSurge(deltaTime: TimeInterval) {
        if creatureSurging {
            surgeDuration -= deltaTime
            if surgeDuration <= 0 {
                creatureSurging = false
            }
        } else {
            surgeTimer += deltaTime
            if surgeTimer >= 1.0 {
                surgeTimer = 0
                // Chance to surge — more likely when losing
                let positionRatio = markerX / sceneSize.width
                let surgeBoost = positionRatio < 0.4 ? 0.12 : 0.0
                if Double.random(in: 0...1) < creatureSurgeChance + surgeBoost {
                    creatureSurging = true
                    surgeDuration = Double.random(in: 0.3...0.8)
                    showCreatureSurgeEffect()
                }
            }
        }
    }

    private func updateTapRate() {
        // Keep only taps from last 2 seconds
        tapWindow = tapWindow.filter { elapsed - $0 < 2.0 }
        tapsPerSecond = CGFloat(tapWindow.count) / 2.0
    }

    // MARK: - Visual Updates

    private func updateMarkerColor() {
        guard let marker = parentNode?.childNode(withName: "tow_marker")
            as? SKShapeNode else { return }

        let ratio = markerX / sceneSize.width
        if ratio < humanWinZone {
            marker.fillColor = PushlingPalette.moss
        } else if ratio > creatureWinZone {
            marker.fillColor = PushlingPalette.ember
        } else {
            marker.fillColor = PushlingPalette.gilt
        }
    }

    private func updateStatusText() {
        guard let label = parentNode?.childNode(withName: "tow_status")
            as? SKLabelNode else { return }

        let ratio = markerX / sceneSize.width
        let remaining = gameDuration - elapsed

        if remaining < 5 {
            label.text = "FINAL PUSH!"
            label.fontColor = PushlingPalette.gilt
        } else if ratio < humanWinZone {
            label.text = "WINNING!"
            label.fontColor = PushlingPalette.moss
        } else if ratio > creatureWinZone {
            label.text = "PULL HARDER!"
            label.fontColor = PushlingPalette.ember
        } else if creatureSurging {
            label.text = "PET SURGES!"
            label.fontColor = PushlingPalette.ember
        } else {
            label.text = "TAP!"
            label.fontColor = PushlingPalette.bone
        }
    }

    private func showTapEffect(at position: CGPoint) {
        guard let parent = parentNode else { return }

        let flash = SKShapeNode(circleOfRadius: 1.5)
        flash.fillColor = PushlingPalette.moss
        flash.strokeColor = .clear
        flash.position = CGPoint(x: position.x,
                                  y: ropeY)
        flash.zPosition = 7
        parent.addChild(flash)

        let burst = SKAction.group([
            SKAction.moveBy(x: -5, y: 0, duration: 0.15),
            SKAction.scale(to: 0.3, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2)
        ])
        flash.run(SKAction.sequence([burst, SKAction.removeFromParent()]))
    }

    private func showCreatureSurgeEffect() {
        guard let parent = parentNode else { return }

        // Ember burst on the right side
        for _ in 0..<4 {
            let spark = SKShapeNode(circleOfRadius: 0.8)
            spark.fillColor = PushlingPalette.ember
            spark.strokeColor = .clear
            spark.position = CGPoint(x: sceneSize.width - 30,
                                      y: ropeY)
            spark.zPosition = 7
            parent.addChild(spark)

            let move = SKAction.moveBy(
                x: CGFloat.random(in: -8...(-2)),
                y: CGFloat.random(in: -4...4),
                duration: 0.3
            )
            let fade = SKAction.fadeOut(withDuration: 0.25)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func showEndEffect() {
        guard let parent = parentNode else { return }

        let won = score == 1
        let text = won ? "YOU WIN!" : "PET WINS!"
        let color = won ? PushlingPalette.moss : PushlingPalette.ember

        let endLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        endLabel.fontSize = 8
        endLabel.fontColor = color
        endLabel.horizontalAlignmentMode = .center
        endLabel.verticalAlignmentMode = .center
        endLabel.position = CGPoint(x: centerX, y: ropeY)
        endLabel.zPosition = 20
        endLabel.text = text
        parent.addChild(endLabel)

        // Flash effect
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.2),
            SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        ])
        endLabel.run(SKAction.repeat(flash, count: 3))

        // Victory particles
        let particleColor = won ? PushlingPalette.moss : PushlingPalette.ember
        let particleX = won ? centerX - 50 : centerX + 50

        for _ in 0..<6 {
            let p = SKShapeNode(circleOfRadius: 0.8)
            p.fillColor = particleColor
            p.strokeColor = .clear
            p.position = CGPoint(x: particleX, y: ropeY)
            p.zPosition = 18
            parent.addChild(p)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 4...10)
            let move = SKAction.moveBy(
                x: cos(angle) * dist,
                y: sin(angle) * dist,
                duration: 0.4
            )
            let fade = SKAction.fadeOut(withDuration: 0.35)
            p.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Teardown

    func teardown() {
        tapWindow.removeAll()
        parentNode?.removeAllChildren()
    }
}
