// MiniGameManager.swift — Game lifecycle: start, play, score, end
// 3 triggers: creature invitation, Claude MCP call, human gesture.
// During a mini-game, normal behavior stack is suspended (Physics only).
// Touch input routed to game handler. Result screen after each game.

import SpriteKit

// MARK: - Mini-Game Type

/// All mini-game types.
enum MiniGameType: String, CaseIterable {
    case catchStars = "catch"
    case memory = "memory"
    case treasureHunt = "treasure_hunt"
    case rhythmTap = "rhythm_tap"
    case tugOfWar = "tug_of_war"

    /// Display name for the result screen.
    var displayName: String {
        switch self {
        case .catchStars:    return "CATCH"
        case .memory:        return "MEMORY"
        case .treasureHunt:  return "TREASURE HUNT"
        case .rhythmTap:     return "RHYTHM TAP"
        case .tugOfWar:      return "TUG OF WAR"
        }
    }

    /// Maximum possible score for tier calculation.
    var maxScore: Int {
        switch self {
        case .catchStars:    return 25
        case .memory:        return 50
        case .treasureHunt:  return 100
        case .rhythmTap:     return 60
        case .tugOfWar:      return 1  // Binary win/lose
        }
    }
}

// MARK: - Game Trigger Source

/// How a mini-game was started.
enum GameTriggerSource {
    case creatureInvitation
    case claudeMCP
    case humanGesture
}

// MARK: - Game Result

/// Result of a completed mini-game.
struct GameResult {
    let gameType: MiniGameType
    let score: Int
    let personalBest: Bool
    let duration: TimeInterval
    let xpAwarded: Int
    let satisfactionBoost: Int
    let triggerSource: GameTriggerSource
}

// MARK: - Game Phase

/// Current phase of the mini-game lifecycle.
enum GamePhase {
    case inactive
    case intro         // 1s intro animation
    case active        // Gameplay in progress
    case ending        // Score tally
    case resultScreen  // Showing result for 3s
}

// MARK: - Mini-Game Protocol

/// Protocol for individual mini-game implementations.
protocol MiniGame: AnyObject {
    var gameType: MiniGameType { get }
    var isComplete: Bool { get }
    var score: Int { get }
    var duration: TimeInterval { get }

    func setup(in parent: SKNode, sceneSize: CGSize)
    func start()
    func update(deltaTime: TimeInterval, currentTime: TimeInterval)
    func handleTap(at position: CGPoint)
    func teardown()
}

// MARK: - Mini-Game Manager

/// Manages the full lifecycle of mini-games: triggering, active gameplay,
/// input routing, scoring, and result display.
final class MiniGameManager {

    // MARK: - Constants

    private static let introDuration: TimeInterval = 1.0
    private static let resultScreenDuration: TimeInterval = 3.0

    // MARK: - State

    /// Current game phase.
    private(set) var phase: GamePhase = .inactive

    /// The active mini-game, if any.
    private(set) var activeGame: MiniGame?

    /// How the current game was triggered.
    private(set) var triggerSource: GameTriggerSource?

    /// The game layer node (above world, below weather).
    private var gameLayer: SKNode?

    /// High scores per game type.
    private var highScores: [String: Int] = [:]

    /// Total plays per game type.
    private var totalPlays: [String: Int] = [:]

    /// Game unlock status.
    private(set) var unlockedGames: Set<String> = ["catch"]  // Catch is free

    /// Total games completed across all types.
    private(set) var totalGamesCompleted = 0

    /// Database reference for persistence.
    private weak var db: DatabaseManager?

    /// Callback for game lifecycle events.
    var onGameEvent: ((GameLifecycleEvent) -> Void)?

    /// Whether a game is currently active (any phase except inactive).
    var isGameActive: Bool { phase != .inactive }

    // MARK: - Game Lifecycle Events

    enum GameLifecycleEvent {
        case started(type: MiniGameType, source: GameTriggerSource)
        case ended(result: GameResult)
        case resultDismissed
    }

    // MARK: - Init

    init(db: DatabaseManager? = nil) {
        self.db = db
        loadGameState()
    }

    // MARK: - Start Game

    /// Starts a mini-game.
    /// - Parameters:
    ///   - type: The game to play.
    ///   - source: How it was triggered.
    ///   - scene: The SpriteKit scene to add game nodes to.
    /// - Returns: Whether the game started successfully.
    @discardableResult
    func startGame(_ type: MiniGameType, source: GameTriggerSource,
                   in scene: SKScene) -> Bool {
        guard phase == .inactive else {
            NSLog("[Pushling/Game] Cannot start %@ — already in %@",
                  type.rawValue, "\(phase)")
            return false
        }

        guard isUnlocked(type) else {
            NSLog("[Pushling/Game] %@ not unlocked yet", type.rawValue)
            return false
        }

        // Create the game instance
        let game: MiniGame
        switch type {
        case .catchStars:    game = CatchGame()
        case .rhythmTap:     game = RhythmTapGame()
        case .memory:        game = MemoryGame()
        case .treasureHunt:  game = TreasureHuntGame()
        case .tugOfWar:      game = TugOfWarGame()
        }

        // Create game layer
        let layer = SKNode()
        layer.name = "game_layer"
        layer.zPosition = 80  // Above world, below weather effects
        scene.addChild(layer)
        gameLayer = layer

        activeGame = game
        triggerSource = source
        phase = .intro

        game.setup(in: layer, sceneSize: scene.size)

        onGameEvent?(.started(type: type, source: source))
        NSLog("[Pushling/Game] Starting %@ (source: %@)",
              type.rawValue, "\(source)")

        // After intro, begin active play
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.introDuration
        ) { [weak self] in
            guard self?.phase == .intro else { return }
            self?.phase = .active
            self?.activeGame?.start()
        }

        return true
    }

    // MARK: - Per-Frame Update

    /// Called each frame during an active game.
    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard let game = activeGame else { return }

        switch phase {
        case .active:
            game.update(deltaTime: deltaTime, currentTime: currentTime)

            if game.isComplete {
                endGame()
            }

        case .resultScreen:
            // Auto-dismiss handled by timer in endGame()
            break

        default:
            break
        }
    }

    // MARK: - Input Routing

    /// Routes a tap to the active game. Returns true if consumed.
    func handleTap(at position: CGPoint) -> Bool {
        guard phase == .active, let game = activeGame else {
            // Tap during result screen dismisses it
            if phase == .resultScreen {
                dismissResult()
                return true
            }
            return false
        }

        game.handleTap(at: position)
        return true
    }

    // MARK: - End Game

    private func endGame() {
        guard let game = activeGame, let source = triggerSource else { return }

        phase = .ending

        let score = game.score
        let gameType = game.gameType
        let isPersonalBest = score > (highScores[gameType.rawValue] ?? 0)

        // Update high score
        if isPersonalBest {
            highScores[gameType.rawValue] = score
        }

        // Increment play count
        totalPlays[gameType.rawValue, default: 0] += 1
        totalGamesCompleted += 1

        // Calculate XP and satisfaction
        let tier = scoreTier(score: score, maxScore: gameType.maxScore)
        let xp = tier.xp
        let satisfaction = tier.satisfaction

        let result = GameResult(
            gameType: gameType,
            score: score,
            personalBest: isPersonalBest,
            duration: game.duration,
            xpAwarded: xp,
            satisfactionBoost: satisfaction,
            triggerSource: source
        )

        // Teardown game nodes
        game.teardown()

        // Show result screen
        phase = .resultScreen
        showResultScreen(result)

        onGameEvent?(.ended(result: result))
        saveGameState()
        checkGameUnlocks()

        NSLog("[Pushling/Game] %@ ended — score: %d, XP: %d, best: %@",
              gameType.rawValue, score, xp, isPersonalBest ? "YES" : "no")

        // Auto-dismiss result after 3 seconds
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.resultScreenDuration
        ) { [weak self] in
            self?.dismissResult()
        }
    }

    private func dismissResult() {
        guard phase == .resultScreen else { return }

        gameLayer?.removeAllChildren()
        gameLayer?.removeFromParent()
        gameLayer = nil
        activeGame = nil
        triggerSource = nil
        phase = .inactive

        onGameEvent?(.resultDismissed)
    }

    // MARK: - Result Screen

    private func showResultScreen(_ result: GameResult) {
        guard let layer = gameLayer else { return }
        let sceneSize = CGSize(width: SceneConstants.sceneWidth,
                               height: SceneConstants.sceneHeight)
        GameResultScreen.show(result, in: layer, sceneSize: sceneSize)
    }

    // MARK: - Score Tier

    private struct ScoreTier {
        let xp: Int
        let satisfaction: Int
    }

    private func scoreTier(score: Int, maxScore: Int) -> ScoreTier {
        let fraction = maxScore > 0 ? Double(score) / Double(maxScore) : 0
        if fraction >= 1.0 { return ScoreTier(xp: 12, satisfaction: 20) }
        if fraction >= 0.7 { return ScoreTier(xp: 8, satisfaction: 15) }
        if fraction >= 0.3 { return ScoreTier(xp: 5, satisfaction: 10) }
        return ScoreTier(xp: 3, satisfaction: 5)
    }

    // MARK: - Game Unlocks

    func isUnlocked(_ type: MiniGameType) -> Bool {
        unlockedGames.contains(type.rawValue)
    }

    private func checkGameUnlocks() {
        // Memory: complete 1 Catch game
        if !isUnlocked(.memory)
            && (totalPlays["catch"] ?? 0) >= 1 {
            unlockedGames.insert(MiniGameType.memory.rawValue)
            NSLog("[Pushling/Game] Unlocked: Memory")
        }

        // Treasure Hunt: 3 total games
        if !isUnlocked(.treasureHunt)
            && totalGamesCompleted >= 3 {
            unlockedGames.insert(MiniGameType.treasureHunt.rawValue)
            NSLog("[Pushling/Game] Unlocked: Treasure Hunt")
        }

        // Rhythm Tap: 5 total games
        if !isUnlocked(.rhythmTap)
            && totalGamesCompleted >= 5 {
            unlockedGames.insert(MiniGameType.rhythmTap.rawValue)
            NSLog("[Pushling/Game] Unlocked: Rhythm Tap")
        }

        // Tug of War: 8 total games (Claude check done externally)
        if !isUnlocked(.tugOfWar)
            && totalGamesCompleted >= 8 {
            unlockedGames.insert(MiniGameType.tugOfWar.rawValue)
            NSLog("[Pushling/Game] Unlocked: Tug of War")
        }
    }

    // MARK: - Persistence

    private func loadGameState() {
        guard let db = db else { return }
        do {
            let rows = try db.query(
                "SELECT game_type, high_score, total_plays FROM game_scores;"
            )
            for row in rows {
                if let type = row["game_type"] as? String {
                    highScores[type] = row["high_score"] as? Int ?? 0
                    totalPlays[type] = row["total_plays"] as? Int ?? 0
                }
            }
            totalGamesCompleted = totalPlays.values.reduce(0, +)

            let unlockRows = try db.query(
                "SELECT game_type FROM game_unlocks WHERE unlocked = 1;"
            )
            for row in unlockRows {
                if let type = row["game_type"] as? String {
                    unlockedGames.insert(type)
                }
            }
            // Catch is always unlocked
            unlockedGames.insert("catch")
        } catch {
            NSLog("[Pushling/Game] Failed to load game state: %@", "\(error)")
        }
    }

    private func saveGameState() {
        guard let db = db else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        db.performWriteAsync({ [highScores, totalPlays, unlockedGames] in
            for (type, score) in highScores {
                let plays = totalPlays[type] ?? 0
                try db.execute("""
                    INSERT INTO game_scores (game_type, high_score, total_plays, last_played)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(game_type) DO UPDATE SET
                        high_score = MAX(high_score, excluded.high_score),
                        total_plays = excluded.total_plays,
                        last_played = excluded.last_played;
                    """,
                    arguments: [type, score, plays, now]
                )
            }

            for type in unlockedGames {
                try db.execute("""
                    INSERT INTO game_unlocks (game_type, unlocked, total_plays, first_played)
                    VALUES (?, 1, 0, ?)
                    ON CONFLICT(game_type) DO UPDATE SET unlocked = 1;
                    """,
                    arguments: [type, now]
                )
            }
        })
    }
}
