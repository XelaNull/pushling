// MemoryGame.swift — Creature shows a sequence of colored symbols, player repeats
// Duration: 60 seconds max. Sequence starts at 3, grows by 1 each round.
// Show phase: symbols light up one-by-one. Input phase: tap in same order.
// Wrong tap ends the round, score = total correct taps across all rounds.
// Max score = 50 (sum of successful round lengths).

import SpriteKit

// MARK: - Memory Game

/// The creature shows a sequence of colored symbol positions. The player must
/// tap them back in the same order. Each successful round adds one more symbol.
final class MemoryGame: MiniGame {

    // MARK: - MiniGame Protocol

    let gameType: MiniGameType = .memory
    var isComplete: Bool { elapsed >= gameDuration || gameOver }
    private(set) var score: Int = 0
    var duration: TimeInterval { elapsed }

    // MARK: - Constants

    private let gameDuration: TimeInterval = 60.0
    private let symbolCount = 6
    private let symbolRadius: CGFloat = 5.0
    private let symbolSpacing: CGFloat = 40.0
    private let showInterval: TimeInterval = 0.6
    private let showPause: TimeInterval = 0.4
    private let dimAlpha: CGFloat = 0.2
    private let litAlpha: CGFloat = 1.0
    private let inputReadyAlpha: CGFloat = 0.5
    private let hitRadius: CGFloat = 25.0
    private let initialSequenceLength = 3
    private let maxSequenceLength = 10

    /// Colors assigned to each symbol position (from palette).
    private let symbolColors: [SKColor] = [
        PushlingPalette.ember,
        PushlingPalette.moss,
        PushlingPalette.tide,
        PushlingPalette.gilt,
        PushlingPalette.dusk,
        PushlingPalette.bone
    ]

    // MARK: - Game Phase

    private enum Phase {
        case countdown      // Brief "watch!" text
        case showing        // Creature shows the sequence
        case inputReady     // Player's turn
        case roundSuccess   // Brief celebration
        case roundFail      // Brief failure flash
    }

    // MARK: - State

    private var elapsed: TimeInterval = 0
    private var gameOver = false
    private var phase: Phase = .countdown
    private var phaseTimer: TimeInterval = 0

    // Sequence data
    private var sequence: [Int] = []
    private var showIndex = 0
    private var inputIndex = 0
    private var currentRound = 0
    private var sequenceLength: Int

    // Timing for show phase
    private var showElapsed: TimeInterval = 0
    private var currentlyLitIndex: Int? = nil

    // Nodes
    private var symbolNodes: [SKShapeNode] = []
    private var glowNodes: [SKShapeNode] = []
    private weak var parentNode: SKNode?
    private var sceneSize: CGSize = .zero

    // MARK: - Init

    init() {
        sequenceLength = initialSequenceLength
    }

    // MARK: - Setup

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent
        self.sceneSize = sceneSize
        score = 0
        elapsed = 0
        gameOver = false
        currentRound = 0
        sequenceLength = initialSequenceLength
        symbolNodes = []
        glowNodes = []

        // Calculate symbol positions — centered horizontally
        let totalWidth = CGFloat(symbolCount - 1) * symbolSpacing
        let startX = (sceneSize.width - totalWidth) / 2

        for i in 0..<symbolCount {
            let x = startX + CGFloat(i) * symbolSpacing
            let y = sceneSize.height / 2

            // Glow ring (behind symbol, used for "lit" state)
            let glow = SKShapeNode(circleOfRadius: symbolRadius + 2)
            glow.fillColor = symbolColors[i].withAlphaComponent(0.0)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: x, y: y)
            glow.zPosition = 3
            glow.name = "mem_glow_\(i)"
            parent.addChild(glow)
            glowNodes.append(glow)

            // Symbol circle
            let circle = SKShapeNode(circleOfRadius: symbolRadius)
            circle.fillColor = symbolColors[i].withAlphaComponent(dimAlpha)
            circle.strokeColor = .clear
            circle.position = CGPoint(x: x, y: y)
            circle.zPosition = 5
            circle.name = "mem_sym_\(i)"
            parent.addChild(circle)
            symbolNodes.append(circle)
        }

        // Score label (right side)
        let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        scoreLabel.fontSize = 6
        scoreLabel.fontColor = PushlingPalette.gilt
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: sceneSize.width - 10,
                                       y: sceneSize.height - 2)
        scoreLabel.name = "mem_score"
        scoreLabel.text = "0"
        scoreLabel.zPosition = 10
        parent.addChild(scoreLabel)

        // Round label (left side)
        let roundLabel = SKLabelNode(fontNamed: "Menlo")
        roundLabel.fontSize = 5
        roundLabel.fontColor = PushlingPalette.bone
        roundLabel.horizontalAlignmentMode = .left
        roundLabel.verticalAlignmentMode = .top
        roundLabel.position = CGPoint(x: 10, y: sceneSize.height - 2)
        roundLabel.name = "mem_round"
        roundLabel.text = ""
        roundLabel.zPosition = 10
        parent.addChild(roundLabel)

        // Timer bar
        let timerBar = SKShapeNode(
            rectOf: CGSize(width: sceneSize.width, height: 1)
        )
        timerBar.fillColor = PushlingPalette.tide.withAlphaComponent(0.5)
        timerBar.strokeColor = .clear
        timerBar.position = CGPoint(x: sceneSize.width / 2,
                                     y: sceneSize.height - 1)
        timerBar.name = "mem_timer"
        timerBar.zPosition = 10
        parent.addChild(timerBar)

        // Status label (center, below symbols)
        let statusLabel = SKLabelNode(fontNamed: "Menlo")
        statusLabel.fontSize = 5
        statusLabel.fontColor = PushlingPalette.ash
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .bottom
        statusLabel.position = CGPoint(x: sceneSize.width / 2, y: 1)
        statusLabel.name = "mem_status"
        statusLabel.text = ""
        statusLabel.zPosition = 10
        parent.addChild(statusLabel)
    }

    func start() {
        NSLog("[Pushling/Game] Memory game started")
        beginRound()
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime
        phaseTimer += deltaTime

        // Update timer bar
        let progress = 1.0 - CGFloat(elapsed / gameDuration)
        if let timer = parentNode?.childNode(withName: "mem_timer") {
            timer.xScale = max(0, progress)
        }

        switch phase {
        case .countdown:
            if phaseTimer >= 0.8 {
                phase = .showing
                phaseTimer = 0
                showElapsed = 0
                showIndex = 0
                currentlyLitIndex = nil
                updateStatus("WATCH")
            }

        case .showing:
            updateShowPhase(deltaTime: deltaTime)

        case .inputReady:
            // Waiting for player taps — nothing to update
            break

        case .roundSuccess:
            if phaseTimer >= 0.6 {
                advanceRound()
            }

        case .roundFail:
            if phaseTimer >= 0.8 {
                // Try again with same length if time remains
                if elapsed < gameDuration - 2.0 {
                    beginRound()
                } else {
                    gameOver = true
                }
            }
        }
    }

    // MARK: - Show Phase

    private func updateShowPhase(deltaTime: TimeInterval) {
        showElapsed += deltaTime

        guard showIndex < sequence.count else {
            // Done showing — transition to input
            dimAllSymbols()
            brightenAllForInput()
            phase = .inputReady
            phaseTimer = 0
            inputIndex = 0
            updateStatus("YOUR TURN")
            return
        }

        let totalPerSymbol = showInterval + showPause
        let currentSymbolTime = showElapsed - Double(showIndex) * totalPerSymbol

        if currentSymbolTime >= 0 && currentSymbolTime < showInterval {
            // Light up current symbol
            let symbolIdx = sequence[showIndex]
            if currentlyLitIndex != symbolIdx {
                dimAllSymbols()
                lightUpSymbol(symbolIdx)
                currentlyLitIndex = symbolIdx
            }
        } else if currentSymbolTime >= showInterval {
            // Pause between symbols
            if currentlyLitIndex != nil {
                dimAllSymbols()
                currentlyLitIndex = nil
            }
            if currentSymbolTime >= totalPerSymbol {
                showIndex += 1
            }
        }
    }

    // MARK: - Input

    func handleTap(at position: CGPoint) {
        guard phase == .inputReady else { return }

        // Find which symbol was tapped
        guard let tappedIndex = hitTestSymbol(at: position) else { return }

        let expectedIndex = sequence[inputIndex]

        if tappedIndex == expectedIndex {
            // Correct tap
            flashSymbol(tappedIndex, color: PushlingPalette.moss)
            inputIndex += 1
            score += 1
            updateScoreLabel()

            if inputIndex >= sequence.count {
                // Round complete
                phase = .roundSuccess
                phaseTimer = 0
                updateStatus("NICE!")
                flashAllSymbols(color: PushlingPalette.gilt)
            }
        } else {
            // Wrong tap
            flashSymbol(tappedIndex, color: PushlingPalette.ember)
            phase = .roundFail
            phaseTimer = 0
            updateStatus("WRONG")
        }
    }

    // MARK: - Round Management

    private func beginRound() {
        currentRound += 1
        generateSequence()
        dimAllSymbols()
        phase = .countdown
        phaseTimer = 0
        showIndex = 0
        showElapsed = 0
        currentlyLitIndex = nil

        updateRoundLabel()
        updateStatus("ROUND \(currentRound)")
    }

    private func advanceRound() {
        // Increase difficulty
        if sequenceLength < maxSequenceLength {
            sequenceLength += 1
        }
        beginRound()
    }

    private func generateSequence() {
        sequence = (0..<sequenceLength).map { _ in
            Int.random(in: 0..<symbolCount)
        }
    }

    // MARK: - Symbol Visuals

    private func dimAllSymbols() {
        for i in 0..<symbolCount {
            symbolNodes[i].fillColor = symbolColors[i]
                .withAlphaComponent(dimAlpha)
            glowNodes[i].fillColor = symbolColors[i]
                .withAlphaComponent(0.0)
        }
    }

    private func brightenAllForInput() {
        for i in 0..<symbolCount {
            symbolNodes[i].fillColor = symbolColors[i]
                .withAlphaComponent(inputReadyAlpha)
        }
    }

    private func lightUpSymbol(_ index: Int) {
        guard index < symbolCount else { return }
        symbolNodes[index].fillColor = symbolColors[index]
            .withAlphaComponent(litAlpha)
        glowNodes[index].fillColor = symbolColors[index]
            .withAlphaComponent(0.3)

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        symbolNodes[index].run(pulse, withKey: "pulse")
    }

    private func flashSymbol(_ index: Int, color: SKColor) {
        guard index < symbolCount else { return }
        let original = symbolColors[index]
        symbolNodes[index].fillColor = color

        let restore = SKAction.sequence([
            SKAction.wait(forDuration: 0.2),
            SKAction.run { [weak self] in
                self?.symbolNodes[index].fillColor = original
                    .withAlphaComponent(self?.inputReadyAlpha ?? 0.5)
            }
        ])
        symbolNodes[index].run(restore, withKey: "flash")
    }

    private func flashAllSymbols(color: SKColor) {
        for i in 0..<symbolCount {
            symbolNodes[i].fillColor = color

            let restore = SKAction.sequence([
                SKAction.wait(forDuration: 0.3),
                SKAction.run { [weak self] in
                    self?.symbolNodes[i].fillColor =
                        (self?.symbolColors[i] ?? PushlingPalette.bone)
                            .withAlphaComponent(self?.dimAlpha ?? 0.2)
                }
            ])
            symbolNodes[i].run(restore, withKey: "flash_all")
        }
    }

    // MARK: - Hit Testing

    private func hitTestSymbol(at position: CGPoint) -> Int? {
        var closestIndex: Int?
        var closestDist: CGFloat = .infinity

        for i in 0..<symbolCount {
            let symPos = symbolNodes[i].position
            let dx = position.x - symPos.x
            let dy = position.y - symPos.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist < hitRadius && dist < closestDist {
                closestDist = dist
                closestIndex = i
            }
        }
        return closestIndex
    }

    // MARK: - UI Updates

    private func updateScoreLabel() {
        if let label = parentNode?.childNode(withName: "mem_score")
            as? SKLabelNode {
            label.text = "\(score)"
        }
    }

    private func updateRoundLabel() {
        if let label = parentNode?.childNode(withName: "mem_round")
            as? SKLabelNode {
            label.text = "R\(currentRound) L\(sequenceLength)"
        }
    }

    private func updateStatus(_ text: String) {
        if let label = parentNode?.childNode(withName: "mem_status")
            as? SKLabelNode {
            label.text = text
        }
    }

    // MARK: - Teardown

    func teardown() {
        symbolNodes.removeAll()
        glowNodes.removeAll()
        parentNode?.removeAllChildren()
    }
}
