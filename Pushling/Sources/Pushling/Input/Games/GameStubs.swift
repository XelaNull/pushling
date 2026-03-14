// GameStubs.swift — Stub implementations for Memory, Treasure Hunt, and Tug of War
// These stubs satisfy the MiniGame protocol and can be triggered,
// but gameplay is minimal (placeholder). Full implementation in a future pass.

import SpriteKit

// MARK: - Memory Game Stub

/// Stub for the Memory mini-game (creature shows symbol sequence, repeat via gestures).
/// Plays a brief "Coming Soon" screen and auto-completes with a participation score.
final class MemoryGameStub: MiniGame {
    let gameType: MiniGameType = .memory
    var isComplete: Bool { elapsed >= stubDuration }
    private(set) var score: Int = 3  // Participation score
    var duration: TimeInterval { elapsed }

    private var elapsed: TimeInterval = 0
    private let stubDuration: TimeInterval = 5.0
    private weak var parentNode: SKNode?

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 7
        label.fontColor = PushlingPalette.tide
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: sceneSize.width / 2,
                                  y: sceneSize.height / 2)
        label.text = "MEMORY — Coming Soon"
        label.zPosition = 10
        parent.addChild(label)
    }

    func start() {
        NSLog("[Pushling/Game] Memory stub started")
    }

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime
    }

    func handleTap(at position: CGPoint) {
        // Stub: taps add a point
        score += 1
    }

    func teardown() {
        parentNode?.removeAllChildren()
    }
}

// MARK: - Treasure Hunt Stub

/// Stub for the Treasure Hunt mini-game (hot/cold hints, find buried treasure).
final class TreasureHuntStub: MiniGame {
    let gameType: MiniGameType = .treasureHunt
    var isComplete: Bool { elapsed >= stubDuration }
    private(set) var score: Int = 5  // Participation score
    var duration: TimeInterval { elapsed }

    private var elapsed: TimeInterval = 0
    private let stubDuration: TimeInterval = 5.0
    private weak var parentNode: SKNode?

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 7
        label.fontColor = PushlingPalette.moss
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: sceneSize.width / 2,
                                  y: sceneSize.height / 2)
        label.text = "TREASURE HUNT — Coming Soon"
        label.zPosition = 10
        parent.addChild(label)
    }

    func start() {
        NSLog("[Pushling/Game] Treasure Hunt stub started")
    }

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime
    }

    func handleTap(at position: CGPoint) {
        score += 2
    }

    func teardown() {
        parentNode?.removeAllChildren()
    }
}

// MARK: - Tug of War Stub

/// Stub for the Tug of War mini-game (human vs Claude, creature in middle).
final class TugOfWarStub: MiniGame {
    let gameType: MiniGameType = .tugOfWar
    var isComplete: Bool { elapsed >= stubDuration }
    private(set) var score: Int = 1  // Win by default in stub
    var duration: TimeInterval { elapsed }

    private var elapsed: TimeInterval = 0
    private let stubDuration: TimeInterval = 5.0
    private weak var parentNode: SKNode?

    func setup(in parent: SKNode, sceneSize: CGSize) {
        parentNode = parent

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 7
        label.fontColor = PushlingPalette.ember
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: sceneSize.width / 2,
                                  y: sceneSize.height / 2)
        label.text = "TUG OF WAR — Coming Soon"
        label.zPosition = 10
        parent.addChild(label)
    }

    func start() {
        NSLog("[Pushling/Game] Tug of War stub started")
    }

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        elapsed += deltaTime
    }

    func handleTap(at position: CGPoint) {
        // Stub: each tap is a "pull"
    }

    func teardown() {
        parentNode?.removeAllChildren()
    }
}
