// CommandRouter.swift — Maps IPC commands to handler functions
// Each handler is a stub returning placeholder responses in Phase 1.
// Adding a new command = one function + one registration line.

import Foundation

/// Routes incoming IPC commands to their handler functions.
/// Manages session state and delegates event buffer operations.
/// Session lifecycle is managed by SessionManager (P4-T4).
final class CommandRouter {

    typealias Handler = (IPCRequest) -> IPCResult

    private var handlers: [String: Handler] = [:]
    private let eventBuffer: EventBuffer
    let sessionManager: SessionManager
    private var activeSessions: Set<String> = []
    private let sessionsLock = NSLock()

    private static let allCommands = [
        "sense", "move", "express", "speak", "perform",
        "world", "recall", "teach", "nurture",
        "connect", "disconnect", "ping"
    ]

    private static let validActions: [String: [String]] = [
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
                     "suggest", "list", "remove"]
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
        // P4-T4-02/05: Session connect via SessionManager (single-session enforcement)
        let result = sessionManager.startSession()

        // If session was accepted, track in event buffer and legacy set
        if result.ok, let sessionId = result.data["session_id"] as? String {
            sessionsLock.lock()
            activeSessions.insert(sessionId)
            sessionsLock.unlock()
            eventBuffer.addSession(sessionId)

            // Add creature state to response
            var responseData = result.data
            responseData["creature"] = placeholderCreature
            return .success(responseData)
        }

        return result
    }

    private func handleDisconnect(_ req: IPCRequest) -> IPCResult {
        let sid = req.params["session_id"] as? String ?? req.sessionId ?? ""
        let reason = req.params["reason"] as? String

        // P4-T4-03: Determine disconnect reason
        let disconnectReason: DisconnectReason = (reason == "abrupt") ? .abrupt : .clean

        // End session via SessionManager
        sessionManager.endSession(sessionId: sid, reason: disconnectReason)

        // Clean up legacy tracking
        sessionsLock.lock()
        activeSessions.remove(sid)
        sessionsLock.unlock()
        eventBuffer.removeSession(sid)

        return .success(["farewell": true])
    }

    /// Called when a socket connection drops unexpectedly (P4-T4-03).
    /// This is invoked by SocketServer when it detects EOF on a client
    /// that has an active session.
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

    // MARK: - Tool Handlers (Phase 1 Skeletons)

    private func handleSense(_ req: IPCRequest) -> IPCResult {
        let aspect = req.action ?? "full"
        switch aspect {
        case "self":
            return .success(["emotions": placeholderEmotions])
        case "body":
            return .success(["stage": "spore", "size": ["width": 6, "height": 6],
                             "personality": placeholderPersonality, "current_animation": "breathe"])
        case "surroundings":
            return .success(["weather": "clear", "terrain": "plains",
                             "nearby_objects": [] as [Any], "time_of_day": "day", "biome": "plains"])
        case "visual":
            return .success(["screenshot": "", "note": "Not yet implemented in Phase 1."])
        case "events":
            return .success(["recent_events": [] as [Any]])
        case "developer":
            return .success(["typing_active": false, "last_commit_ago_s": -1, "session_duration_s": 0])
        case "evolve":
            return .success(["eligible": false, "current_xp": 0, "threshold": 20])
        case "full":
            return .success([
                "emotions": placeholderEmotions,
                "body": ["stage": "spore", "size": ["width": 6, "height": 6],
                         "current_animation": "breathe"] as [String: Any],
                "surroundings": ["weather": "clear", "time_of_day": "day",
                                 "biome": "plains"] as [String: Any],
                "developer": ["typing_active": false, "last_commit_ago_s": -1] as [String: Any]
            ])
        default:
            return .failure(error: "Unknown aspect '\(aspect)'.", code: "UNKNOWN_ACTION")
        }
    }

    private func handleMove(_ req: IPCRequest) -> IPCResult {
        .success(["accepted": true, "action": req.action ?? "stop", "position": 542, "facing": "right"])
    }

    private func handleExpress(_ req: IPCRequest) -> IPCResult {
        .success(["expression": req.action ?? "neutral",
                  "intensity": req.params["intensity"] as? Double ?? 0.7,
                  "duration": req.params["duration"] as? Double ?? 3.0])
    }

    private func handleSpeak(_ req: IPCRequest) -> IPCResult {
        guard let text = req.params["text"] as? String, !text.isEmpty else {
            return .failure(error: "Missing 'text' parameter.", code: "INVALID_PARAMS")
        }
        return .success(["spoken": text, "intended": text, "filtered": false,
                         "style": req.action ?? "say", "stage": "spore",
                         "max_chars": 0, "max_words": 0])
    }

    private func handlePerform(_ req: IPCRequest) -> IPCResult {
        if req.action == "sequence" {
            let seq = req.params["sequence"] as? [[String: Any]] ?? []
            return .success(["accepted": true, "steps": seq.count,
                             "label": req.params["label"] as? String ?? "unnamed",
                             "estimated_duration_ms": seq.count * 800])
        }
        return .success(["accepted": true, "behavior": req.action ?? "wave",
                         "variant": req.params["variant"] as? String ?? "default",
                         "stage_ok": true])
    }

    private func handleWorld(_ req: IPCRequest) -> IPCResult {
        switch req.action ?? "weather" {
        case "weather":
            return .success(["type": req.params["type"] as? String ?? "clear",
                             "duration": req.params["duration"] as? Int ?? 5, "previous": "clear"])
        case "place", "create":
            return .success(["object_id": UUID().uuidString, "position": 340,
                             "type": req.params["preset"] as? String
                                ?? req.params["object"] as? String ?? "unknown"])
        case "companion":
            return .success(["companion_id": UUID().uuidString,
                             "type": req.params["type"] as? String ?? "mouse",
                             "name": req.params["name"] as? String ?? "Pip"])
        default:
            return .success(["accepted": true, "action": req.action ?? "unknown"])
        }
    }

    private func handleRecall(_ req: IPCRequest) -> IPCResult {
        .success(["memories": [] as [Any], "count": req.params["count"] as? Int ?? 20,
                  "filter": req.action ?? "recent"])
    }

    private func handleTeach(_ req: IPCRequest) -> IPCResult {
        switch req.action ?? "list" {
        case "compose":
            return .success(["draft_id": UUID().uuidString,
                             "name": req.params["name"] as? String ?? "unnamed",
                             "tracks": 0,
                             "duration_s": req.params["duration_s"] as? Double ?? 1.0])
        case "preview": return .success(["playing": true])
        case "refine":  return .success(["refined": true])
        case "commit":  return .success(["committed": true])
        case "list":    return .success(["tricks": [] as [Any], "count": 0])
        case "remove":  return .success(["removed": true])
        default:        return .success(["accepted": true])
        }
    }

    private func handleNurture(_ req: IPCRequest) -> IPCResult {
        switch req.action ?? "list" {
        case "habit":
            return .success(["habit_id": UUID().uuidString,
                             "trigger": req.params["trigger"] as? String ?? "on_idle",
                             "behavior": req.params["behavior"] as? String ?? "stretch",
                             "strength": 0.5])
        case "preference":
            return .success(["preference_id": UUID().uuidString,
                             "subject": req.params["subject"] as? String ?? "",
                             "valence": req.params["valence"] as? Double ?? 0.5])
        case "quirk":
            return .success(["quirk_id": UUID().uuidString,
                             "description": req.params["description"] as? String ?? "",
                             "probability": req.params["probability"] as? Double ?? 0.15])
        case "routine":
            return .success(["slot": req.params["slot"] as? String ?? "morning",
                             "steps": req.params["steps"] as? Int ?? 0])
        case "identity":
            return .success(["name": req.params["name"] as? String ?? "Pushling",
                             "title": req.params["title"], "motto": req.params["motto"]])
        case "suggest":
            return .success(["suggestions": [] as [Any]])
        case "list":
            return .success(["habits": [] as [Any], "preferences": [] as [Any],
                             "quirks": [] as [Any], "routines": [] as [Any]])
        case "remove":
            return .success(["removed": true, "id": req.params["id"] ?? ""])
        default:
            return .success(["accepted": true])
        }
    }

    // MARK: - Placeholder Data

    private var placeholderEmotions: [String: Any] {
        ["satisfaction": 50, "curiosity": 50, "contentment": 50, "energy": 50]
    }

    private var placeholderPersonality: [String: Any] {
        ["energy": 0.5, "verbosity": 0.5, "focus": 0.5, "discipline": 0.5, "specialty": "unknown"]
    }

    private var placeholderCreature: [String: Any] {
        [
            "name": "Pushling", "stage": "spore", "xp": 0,
            "personality": placeholderPersonality,
            "emotions": placeholderEmotions,
            "speech": ["max_chars": 0, "max_words": 0, "styles": [] as [String]] as [String: Any],
            "tricks_known": 0, "streak_days": 0
        ]
    }
}
