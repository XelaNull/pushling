// CommandRouter.swift — Maps IPC commands to handler functions
// Core routing logic, session management, and GameCoordinator binding.
// Handler implementations live in CommandHandlers.swift (extension).

import Foundation

/// Routes incoming IPC commands to their handler functions.
/// Manages session state and delegates event buffer operations.
/// Session lifecycle is managed by SessionManager (P4-T4).
final class CommandRouter {

    typealias Handler = (IPCRequest) -> IPCResult

    private var handlers: [String: Handler] = [:]
    let eventBuffer: EventBuffer
    let sessionManager: SessionManager
    private var activeSessions: Set<String> = []
    private let sessionsLock = NSLock()

    /// Reference to GameCoordinator for dispatching real commands.
    /// Weak to avoid retain cycle (GameCoordinator holds a strong ref to us).
    weak var gameCoordinator: GameCoordinator?

    static let allCommands = [
        "sense", "move", "express", "speak", "perform",
        "world", "recall", "teach", "nurture",
        "connect", "disconnect", "ping"
    ]

    static let validActions: [String: [String]] = [
        "sense": ["self", "body", "surroundings", "visual", "events",
                  "developer", "evolve", "full"],
        "move": ["goto", "walk", "stop", "jump", "turn", "retreat",
                 "pace", "approach_edge", "center", "follow_cursor"],
        "express": ["joy", "curiosity", "surprise", "contentment", "thinking",
                     "mischief", "pride", "embarrassment", "determination", "wonder",
                     "sleepy", "love", "confusion", "excitement", "melancholy", "neutral"],
        "speak": ["say", "think", "exclaim", "whisper", "sing", "dream", "narrate"],
        "perform": ["wave", "spin", "bow", "dance", "peek", "meditate", "flex",
                     "backflip", "dig", "examine", "nap", "celebrate", "shiver",
                     "stretch", "play_dead", "conduct", "glitch", "transcend", "sequence"],
        "world": ["weather", "event", "place", "create", "remove", "modify",
                   "time_override", "sound", "companion"],
        "recall": ["recent", "commits", "touches", "conversations", "milestones",
                    "dreams", "relationship", "failed_speech"],
        "teach": ["compose", "preview", "refine", "commit", "list", "remove"],
        "nurture": ["habit", "preference", "quirk", "routine", "identity",
                     "suggest", "list", "remove", "set", "reinforce"]
    ]

    init(eventBuffer: EventBuffer, sessionManager: SessionManager = SessionManager()) {
        self.eventBuffer = eventBuffer
        self.sessionManager = sessionManager
        registerAllHandlers()
    }

    private func registerAllHandlers() {
        handlers["connect"] = handleConnect
        handlers["disconnect"] = handleDisconnect
        handlers["ping"] = handlePing
        handlers["sense"] = handleSense
        handlers["move"] = handleMove
        handlers["express"] = handleExpress
        handlers["speak"] = handleSpeak
        handlers["perform"] = handlePerform
        handlers["world"] = handleWorld
        handlers["recall"] = handleRecall
        handlers["teach"] = handleTeach
        handlers["nurture"] = handleNurture
    }

    // MARK: - Routing

    func route(_ request: IPCRequest) -> IPCResult {
        guard let handler = handlers[request.cmd] else {
            return .failure(
                error: "Unknown command '\(request.cmd)'. Valid: \(CommandRouter.allCommands.joined(separator: ", "))",
                code: "UNKNOWN_COMMAND")
        }
        if let valid = CommandRouter.validActions[request.cmd], let action = request.action,
           !valid.contains(action) {
            return .failure(
                error: "Unknown action '\(action)' for command '\(request.cmd)'. Valid: \(valid.joined(separator: ", "))",
                code: "UNKNOWN_ACTION")
        }

        // Track commands with session manager for idle timeout (P4-T4-04)
        let sessionCmds: Set<String> = ["connect", "disconnect", "ping"]
        if !sessionCmds.contains(request.cmd) {
            sessionManager.recordCommand()
        }

        return handler(request)
    }

    func drainEvents(for sessionId: String) -> [[String: Any]] {
        eventBuffer.drain(sessionId: sessionId)
    }

    // MARK: - Session Handlers

    private func handleConnect(_ req: IPCRequest) -> IPCResult {
        let result = sessionManager.startSession()

        if result.ok, let sessionId = result.data["session_id"] as? String {
            sessionsLock.lock()
            activeSessions.insert(sessionId)
            sessionsLock.unlock()
            eventBuffer.addSession(sessionId)

            // Add real creature state to response
            var responseData = result.data
            responseData["creature"] = buildCreatureSnapshot()
            return .success(responseData)
        }

        return result
    }

    private func handleDisconnect(_ req: IPCRequest) -> IPCResult {
        let sid = req.params["session_id"] as? String ?? req.sessionId ?? ""
        let reason = req.params["reason"] as? String

        let disconnectReason: DisconnectReason = (reason == "abrupt") ? .abrupt : .clean

        sessionManager.endSession(sessionId: sid, reason: disconnectReason)

        sessionsLock.lock()
        activeSessions.remove(sid)
        sessionsLock.unlock()
        eventBuffer.removeSession(sid)

        return .success(["farewell": true])
    }

    /// Called when a socket connection drops unexpectedly (P4-T4-03).
    func handleAbruptDisconnect(sessionId: String) {
        sessionManager.endSession(sessionId: sessionId, reason: .abrupt)

        sessionsLock.lock()
        activeSessions.remove(sessionId)
        sessionsLock.unlock()
        eventBuffer.removeSession(sessionId)
    }

    private func handlePing(_ req: IPCRequest) -> IPCResult {
        .success(["uptime_s": Int(ProcessInfo.processInfo.systemUptime)])
    }

    // MARK: - Creature Snapshot (for connect response)

    /// Builds a real creature snapshot from live subsystem data.
    func buildCreatureSnapshot() -> [String: Any] {
        guard let gc = gameCoordinator else {
            return [
                "name": "Pushling", "stage": "spore", "xp": 0,
                "personality": ["energy": 0.5, "verbosity": 0.5,
                                "focus": 0.5, "discipline": 0.5,
                                "specialty": "unknown"] as [String: Any],
                "emotions": ["satisfaction": 50, "curiosity": 50,
                             "contentment": 50, "energy": 50] as [String: Any],
                "speech": ["max_chars": 0, "max_words": 0,
                           "styles": [] as [String]] as [String: Any],
                "tricks_known": 0, "streak_days": 0
            ]
        }

        let emo = gc.emotionalState
        let p = gc.personality
        let stage = gc.creatureStage

        // Compute available speech styles
        let availableStyles = SpeechStyle.allCases
            .filter { $0.minimumStage <= stage }
            .map { $0.rawValue }

        // Query trick count from DB
        let db = gc.stateCoordinator.database
        let trickCount = (try? db.queryScalarInt(
            "SELECT COUNT(*) FROM journal WHERE type = 'teach'"
        )) ?? 0

        // Query streak days
        let streakDays = (try? db.queryScalarInt(
            "SELECT streak_days FROM creature WHERE id = 1"
        )) ?? 0

        return [
            "name": gc.creatureName,
            "stage": "\(stage)",
            "xp": gc.totalXP,
            "personality": [
                "energy": p.energy,
                "verbosity": p.verbosity,
                "focus": p.focus,
                "discipline": p.discipline,
                "specialty": p.specialty.rawValue
            ] as [String: Any],
            "emotions": [
                "satisfaction": Int(emo.satisfaction),
                "curiosity": Int(emo.curiosity),
                "contentment": Int(emo.contentment),
                "energy": Int(emo.energy)
            ] as [String: Any],
            "speech": [
                "styles": availableStyles
            ] as [String: Any],
            "tricks_known": trickCount,
            "streak_days": streakDays
        ]
    }
}
