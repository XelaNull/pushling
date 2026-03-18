// CommandRouter.swift — Maps IPC commands to handler functions
// Core routing logic, session management, and GameCoordinator binding.
// Handler implementations live in CommandHandlers.swift (extension).

import AppKit
import Foundation
import ImageIO
import SpriteKit

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
        "connect", "disconnect", "ping", "reload", "screenshot",
        "debug_nodes"
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
        handlers["reload"] = handleReload
        handlers["screenshot"] = handleScreenshot
        handlers["debug_nodes"] = handleDebugNodes
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
        let sessionCmds: Set<String> = ["connect", "disconnect", "ping", "screenshot",
                                        "debug_nodes"]
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

    private func handleReload(_ req: IPCRequest) -> IPCResult {
        // Schedule restart after 200ms to allow this response to be sent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let appDelegate = NSApp.delegate as? AppDelegate else {
                NSLog("[Pushling/IPC] Cannot reload — no AppDelegate")
                return
            }
            appDelegate.performGracefulRestart(reason: "IPC reload command")
        }
        return .success(["reloading": true])
    }

    private func handleScreenshot(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Scene not initialized.", code: "NOT_READY")
        }

        // SpriteKit capture must happen on the main thread.
        // IPC handlers run on a background queue, so dispatch + wait.
        let semaphore = DispatchSemaphore(value: 0)
        var pngData: Data?

        DispatchQueue.main.async {
            pngData = gc.scene.captureScreenshot()
            semaphore.signal()
        }

        let timeout = semaphore.wait(timeout: .now() + 2.0)
        guard timeout == .success, let data = pngData else {
            return .failure(error: "Screenshot capture timed out or failed.",
                            code: "CAPTURE_FAILED")
        }

        let path = "/tmp/pushling_screenshot.png"
        do {
            try data.write(to: URL(fileURLWithPath: path))
        } catch {
            return .failure(error: "Failed to write screenshot: \(error.localizedDescription)",
                            code: "WRITE_FAILED")
        }

        // Read image dimensions from the PNG data via CGImageSource
        var width = 0
        var height = 0
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
            width = props[kCGImagePropertyPixelWidth as String] as? Int ?? 0
            height = props[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        }

        NSLog("[Pushling/IPC] Screenshot captured: %dx%d -> %@", width, height, path)

        return .success([
            "path": path,
            "width": width,
            "height": height
        ])
    }

    private func handleDebugNodes(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Scene not initialized.", code: "NOT_READY")
        }

        // SpriteKit scene graph must be read on the main thread.
        let semaphore = DispatchSemaphore(value: 0)
        var nodes: [[String: Any]] = []
        var totalCount = 0
        var creaturePos: [String: Any] = [:]

        DispatchQueue.main.async {
            nodes = gc.scene.dumpNodeTree()
            totalCount = gc.scene.debugCountAllNodes(in: gc.scene)

            if let creature = gc.scene.creatureNode {
                creaturePos = [
                    "x": round(Double(creature.position.x) * 10) / 10,
                    "y": round(Double(creature.position.y) * 10) / 10,
                    "z_position": round(Double(creature.zPosition) * 10) / 10,
                    "facing": creature.facing.rawValue,
                    "stage": "\(creature.currentStage)"
                ]
            }

            semaphore.signal()
        }

        let timeout = semaphore.wait(timeout: .now() + 2.0)
        guard timeout == .success else {
            return .failure(error: "Node tree capture timed out.",
                            code: "TIMEOUT")
        }

        return .success([
            "nodes": nodes,
            "total_count": totalCount,
            "visible_count": nodes.count,
            "creature": creaturePos
        ])
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
