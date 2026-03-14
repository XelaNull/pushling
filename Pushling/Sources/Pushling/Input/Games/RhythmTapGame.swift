// RhythmTapGame.swift — Notes scroll toward creature, tap on beat
// Tempo: 120 BPM (0.5s per beat). Hit zone at creature position.
// Perfect (<50ms): 3pts. Good (<100ms): 2pts. OK (<200ms): 1pt. Miss: 0.
// Pre-designed patterns in 5 difficulty levels. 30-45 seconds total.

import SpriteKit

// MARK: - Rhythm Tap Game

/// Notes scroll from right to left across the Touch Bar. Tap when a note
/// enters the hit zone at the creature's position for points.
final class RhythmTapGame: MiniGame {

    // MARK: - MiniGame Protocol

    let gameType: MiniGameType = .rhythmTap
    var isComplete: Bool { currentPatternIndex >= patterns.count && activeNotes.isEmpty }
    private(set) var score: Int = 0
    var duration: TimeInterval { elapsed }

    // MARK: - Constants

    private let bpm: Double = 120
    private var beatInterval: Double { 60.0 / bpm }
    private let noteScrollSpeed: CGFloat = 80.0
    private let hitZoneWidth: CGFloat = 3.0
    private let perfectWindow: TimeInterval = 0.05
    private let goodWindow: TimeInterval = 0.1
    private let okWindow: TimeInterval = 0.2
    private let noteRadius: CGFloat = 2.0

    // MARK: - Note Patterns

    /// Pre-designed patterns: arrays of beat offsets within each pattern.
    private let patterns: [[Double]] = [
        // Level 1: simple quarter notes
        [0, 1, 2, 3, 4, 5, 6, 7],
        // Level 2: syncopated
        [0, 0.5, 1.5, 2, 3, 3.5, 4.5, 5, 6, 7],
        // Level 3: faster phrases
        [0, 0.25, 0.5, 1, 1.5, 2, 2.5, 3, 3.25, 3.5, 4, 5, 5.5, 6, 7],
        // Level 4: complex rhythm
        [0, 0.25, 0.75, 1, 1.25, 2, 2.5, 2.75, 3, 3.5, 4, 4.25, 4.5, 5, 6, 6.5, 7, 7.5],
    ]

    // MARK: - State

    private var elapsed: TimeInterval = 0
    private var hitZoneX: CGFloat = 200
    private var currentPatternIndex = 0
    private var patternStartTime: TimeInterval = 0
    private var nextNoteIndex = 0
    private var activeNotes: [RhythmNote] = []
    private var combo = 0
    private var maxCombo = 0
    private weak var parentNode: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Rhythm Note

    private struct RhythmNote {
        let node: SKShapeNode
        let targetTime: TimeInterval   // When it should be at hit zone
        var x: CGFloat
        var wasHit: Bool = false
    }

    // MARK: - Setup

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent
        self.sceneSize = sceneSize
        score = 0
        elapsed = 0
        combo = 0
        maxCombo = 0
        currentPatternIndex = 0
        nextNoteIndex = 0
        patternStartTime = 0
        activeNotes = []
        hitZoneX = sceneSize.width * 0.2

        // Hit zone indicator
        let hitZone = SKShapeNode(
            rectOf: CGSize(width: hitZoneWidth, height: sceneSize.height)
        )
        hitZone.fillColor = PushlingPalette.gilt.withAlphaComponent(0.15)
        hitZone.strokeColor = PushlingPalette.gilt.withAlphaComponent(0.3)
        hitZone.lineWidth = 0.5
        hitZone.position = CGPoint(x: hitZoneX, y: sceneSize.height / 2)
        hitZone.zPosition = 1
        hitZone.name = "hit_zone"
        parent.addChild(hitZone)

        // Score label
        let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 6
        scoreLabel.fontColor = PushlingPalette.gilt
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 10, y: sceneSize.height - 2)
        scoreLabel.name = "rhythm_score"
        scoreLabel.text = "0"
        scoreLabel.zPosition = 10
        parent.addChild(scoreLabel)

        // Combo label
        let comboLabel = SKLabelNode(fontNamed: "Menlo")
        comboLabel.fontSize = 5
        comboLabel.fontColor = PushlingPalette.tide
        comboLabel.horizontalAlignmentMode = .right
        comboLabel.verticalAlignmentMode = .top
        comboLabel.position = CGPoint(x: sceneSize.width - 10, y: sceneSize.height - 2)
        comboLabel.name = "rhythm_combo"
        comboLabel.text = ""
        comboLabel.zPosition = 10
        parent.addChild(comboLabel)
    }

    func start() {
        patternStartTime = elapsed
        nextNoteIndex = 0
        NSLog("[Pushling/Game] Rhythm Tap started")
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime

        // Spawn notes from current pattern
        spawnNotes()

        // Move active notes
        var missedIndices: [Int] = []
        for i in activeNotes.indices {
            activeNotes[i].x -= noteScrollSpeed * CGFloat(deltaTime)
            activeNotes[i].node.position.x = activeNotes[i].x

            // Check for miss (passed hit zone by more than okWindow distance)
            let missThreshold = hitZoneX - noteScrollSpeed * CGFloat(okWindow) - 10
            if activeNotes[i].x < missThreshold && !activeNotes[i].wasHit {
                missedIndices.append(i)
            }

            // Off-screen cleanup
            if activeNotes[i].x < -10 {
                missedIndices.append(i)
            }
        }

        // Handle misses
        for i in missedIndices.reversed() {
            if !activeNotes[i].wasHit {
                // Miss — creature winces
                combo = 0
                updateComboLabel()
            }
            activeNotes[i].node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            activeNotes.remove(at: i)
        }

        // Check if current pattern is done and advance
        if let pattern = currentPattern(),
           nextNoteIndex >= pattern.count && activeNotes.isEmpty {
            currentPatternIndex += 1
            nextNoteIndex = 0
            patternStartTime = elapsed + 1.0  // 1s gap between patterns
        }
    }

    // MARK: - Input

    func handleTap(at position: CGPoint) {
        // Find the closest note to the hit zone
        var bestIndex: Int?
        var bestTimeDiff: TimeInterval = .infinity

        for i in activeNotes.indices where !activeNotes[i].wasHit {
            let noteX = activeNotes[i].x
            let distFromHitZone = abs(noteX - hitZoneX)
            let timeDiff = TimeInterval(distFromHitZone / noteScrollSpeed)

            if timeDiff < okWindow && timeDiff < bestTimeDiff {
                bestTimeDiff = timeDiff
                bestIndex = i
            }
        }

        guard let hitIndex = bestIndex else { return }

        activeNotes[hitIndex].wasHit = true

        // Determine timing tier
        let points: Int
        let feedbackText: String
        let feedbackColor: SKColor

        if bestTimeDiff < perfectWindow {
            points = 3
            feedbackText = "PERFECT"
            feedbackColor = PushlingPalette.gilt
        } else if bestTimeDiff < goodWindow {
            points = 2
            feedbackText = "GOOD"
            feedbackColor = PushlingPalette.moss
        } else {
            points = 1
            feedbackText = "OK"
            feedbackColor = PushlingPalette.tide
        }

        score += points
        combo += 1
        maxCombo = max(maxCombo, combo)

        updateScoreLabel()
        updateComboLabel()

        // Hit effect
        let note = activeNotes[hitIndex].node
        note.fillColor = feedbackColor

        // Feedback text
        showFeedback(feedbackText, color: feedbackColor)

        // Note explodes
        emitNoteParticles(at: note.position, color: feedbackColor)

        note.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.15)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Note Spawning

    private func currentPattern() -> [Double]? {
        guard currentPatternIndex < patterns.count else { return nil }
        return patterns[currentPatternIndex]
    }

    private func spawnNotes() {
        guard let pattern = currentPattern() else { return }
        guard nextNoteIndex < pattern.count else { return }

        let beatOffset = pattern[nextNoteIndex]
        let targetTime = patternStartTime + beatOffset * beatInterval

        // Spawn note when it needs to be on screen
        // Note travels from right edge to hit zone
        let travelTime = TimeInterval((sceneSize.width - hitZoneX) / noteScrollSpeed)
        let spawnTime = targetTime - travelTime

        if elapsed >= spawnTime {
            spawnNote(targetTime: targetTime)
            nextNoteIndex += 1
        }
    }

    private func spawnNote(targetTime: TimeInterval) {
        guard let parent = parentNode else { return }

        let note = SKShapeNode(circleOfRadius: noteRadius)
        note.fillColor = PushlingPalette.gilt
        note.strokeColor = .clear
        note.position = CGPoint(x: sceneSize.width + 5, y: sceneSize.height / 2)
        note.zPosition = 5
        parent.addChild(note)

        activeNotes.append(RhythmNote(
            node: note,
            targetTime: targetTime,
            x: sceneSize.width + 5
        ))
    }

    // MARK: - UI Updates

    private func updateScoreLabel() {
        if let label = parentNode?.childNode(withName: "rhythm_score")
            as? SKLabelNode {
            label.text = "\(score)"
        }
    }

    private func updateComboLabel() {
        if let label = parentNode?.childNode(withName: "rhythm_combo")
            as? SKLabelNode {
            label.text = combo > 1 ? "x\(combo)" : ""
        }
    }

    private func showFeedback(_ text: String, color: SKColor) {
        guard let parent = parentNode else { return }

        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.fontSize = 5
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: hitZoneX, y: 8)
        label.zPosition = 15
        parent.addChild(label)
        label.text = text

        let rise = SKAction.moveBy(x: 0, y: 5, duration: 0.4)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.3)
        label.run(SKAction.sequence([
            SKAction.group([rise, fade]),
            SKAction.removeFromParent()
        ]))
    }

    private func emitNoteParticles(at position: CGPoint, color: SKColor) {
        guard let parent = parentNode else { return }

        for _ in 0..<6 {
            let p = SKShapeNode(circleOfRadius: 0.6)
            p.fillColor = color
            p.strokeColor = .clear
            p.position = position
            p.zPosition = 8
            parent.addChild(p)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 3...8)
            let move = SKAction.moveBy(
                x: cos(angle) * dist,
                y: sin(angle) * dist,
                duration: 0.3
            )
            let fade = SKAction.fadeOut(withDuration: 0.25)
            p.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Teardown

    func teardown() {
        activeNotes.removeAll()
        parentNode?.removeAllChildren()
    }
}
