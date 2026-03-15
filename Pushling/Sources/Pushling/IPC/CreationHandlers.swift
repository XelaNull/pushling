// CreationHandlers.swift — pushling_world, pushling_recall, pushling_teach, pushling_nurture
// Extension on CommandRouter for world-shaping, memory, creation, and nurturing.
// Dispatches to WorldManager, DatabaseManager, ChoreographyParser, and identity DB.

import Foundation
import CoreGraphics

// MARK: - World Handler

extension CommandRouter {

    func handleWorld(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "weather"

        switch action {
        case "weather":
            return handleWorldWeather(req, gc: gc)
        case "event":
            return handleWorldEvent(req, gc: gc)
        case "time_override":
            return handleWorldTimeOverride(req, gc: gc)
        case "place", "create":
            return .failure(
                error: "Object placement system is not yet fully integrated. "
                    + "Use the debug menu to test world objects, or use "
                    + "'world weather' and 'world event' which are live.",
                code: "NOT_IMPLEMENTED"
            )
        case "remove", "modify":
            return .failure(
                error: "Object modification is not yet fully integrated. "
                    + "Placed objects support is coming in a future update.",
                code: "NOT_IMPLEMENTED"
            )
        case "sound":
            return .failure(
                error: "Ambient sound system is not yet integrated. "
                    + "Use 'speak' for creature sounds.",
                code: "NOT_IMPLEMENTED"
            )
        case "companion":
            return .failure(
                error: "Companion system is not yet integrated. "
                    + "The creature explores alone for now.",
                code: "NOT_IMPLEMENTED"
            )
        default:
            return .failure(
                error: "Unknown world action '\(action)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    private func handleWorldWeather(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager
        let previous = wm.currentWeather

        guard let typeStr = req.params["type"] as? String else {
            return .success([
                "current": wm.currentWeather.rawValue,
                "time_of_day": wm.currentTimePeriod.rawValue,
                "moon_phase": wm.moonPhaseName,
                "is_full_moon": wm.isFullMoon,
                "description": wm.weatherDescription
            ])
        }

        guard let weatherState = WeatherState(rawValue: typeStr) else {
            let valid = WeatherState.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown weather type '\(typeStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        let duration = req.params["duration"] as? Int ?? 300

        DispatchQueue.main.async {
            wm.debugForceWeather(weatherState)
        }

        journalLog(gc, type: "world_change",
                   summary: "Weather changed: \(previous.rawValue) -> \(typeStr)")

        return .success([
            "type": typeStr,
            "previous": previous.rawValue,
            "duration_s": duration,
            "note": "Weather transitioning over 30-60s."
        ])
    }

    private func handleWorldEvent(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager

        guard let typeStr = req.params["type"] as? String else {
            let valid = VisualEventType.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Missing 'type' parameter. Valid visual events: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        guard let eventType = VisualEventType(rawValue: typeStr) else {
            let valid = VisualEventType.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown visual event '\(typeStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        var started = false
        DispatchQueue.main.sync {
            started = wm.triggerVisualEvent(eventType)
        }

        if started {
            journalLog(gc, type: "world_change",
                       summary: "Visual event triggered: \(typeStr)")
            return .success([
                "event": typeStr,
                "started": true,
                "duration_s": eventType.duration
            ])
        } else {
            return .success([
                "event": typeStr,
                "started": false,
                "note": "Event was queued or stage requirement not met. "
                    + "Visual events require critter+ stage."
            ])
        }
    }

    private func handleWorldTimeOverride(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let periodStr = req.params["period"] as? String else {
            let current = gc.scene.worldManager.currentTimePeriod
            return .success([
                "current_period": current.rawValue,
                "note": "Pass 'period' to override. Valid: "
                    + TimePeriod.allCases.map(\.rawValue).joined(separator: ", ")
            ])
        }

        if periodStr == "auto" {
            DispatchQueue.main.async {
                gc.scene.worldManager.skySystem.timeOverrideHour = nil
            }
            return .success([
                "period": "auto",
                "note": "Sky time override cleared. Using wall clock."
            ])
        }

        guard let period = TimePeriod(rawValue: periodStr) else {
            let valid = TimePeriod.allCases.map(\.rawValue).joined(separator: ", ")
                + ", auto"
            return .failure(
                error: "Unknown time period '\(periodStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        DispatchQueue.main.async {
            gc.scene.worldManager.skySystem.timeOverrideHour = period.startHour + 0.5
        }

        return .success([
            "period": periodStr,
            "note": "Sky time overridden to \(periodStr). Use 'period: auto' to restore."
        ])
    }
}

// MARK: - Recall Handler

extension CommandRouter {

    func handleRecall(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        let filter = req.action ?? "recent"
        let count = req.params["count"] as? Int ?? 20
        let db = gc.stateCoordinator.database

        switch filter {
        case "recent":
            return recallQuery(db, sql:
                "SELECT type, summary, timestamp FROM journal ORDER BY timestamp DESC LIMIT ?",
                args: [count], label: "recent")

        case "commits":
            return recallQuery(db, sql:
                """
                SELECT sha, message, repo_name, files_changed,
                       lines_added, lines_removed, timestamp
                FROM commits ORDER BY timestamp DESC LIMIT ?
                """,
                args: [count], label: "commits")

        case "touches":
            return recallQuery(db, sql:
                "SELECT type, summary, timestamp FROM journal WHERE type = 'touch' ORDER BY timestamp DESC LIMIT ?",
                args: [count], label: "touches")

        case "conversations":
            return recallQuery(db, sql:
                """
                SELECT type, summary, timestamp FROM journal
                WHERE type IN ('ai_speech', 'session')
                ORDER BY timestamp DESC LIMIT ?
                """,
                args: [count], label: "conversations")

        case "milestones":
            return recallQuery(db, sql:
                """
                SELECT type, summary, timestamp FROM journal
                WHERE type IN ('evolve', 'first_word', 'discovery', 'mutation')
                ORDER BY timestamp DESC LIMIT ?
                """,
                args: [count], label: "milestones")

        case "dreams":
            return recallQuery(db, sql:
                "SELECT type, summary, timestamp FROM journal WHERE type = 'dream' ORDER BY timestamp DESC LIMIT ?",
                args: [count], label: "dreams")

        case "relationship":
            let totalCommits = (try? db.queryScalarInt(
                "SELECT COUNT(*) FROM commits"
            )) ?? 0
            let totalSessions = (try? db.queryScalarInt(
                "SELECT COUNT(*) FROM journal WHERE type = 'session'"
            )) ?? 0
            let totalSpeech = (try? db.queryScalarInt(
                "SELECT COUNT(*) FROM journal WHERE type IN ('ai_speech', 'failed_speech')"
            )) ?? 0
            let totalTouches = (try? db.queryScalarInt(
                "SELECT COUNT(*) FROM journal WHERE type = 'touch'"
            )) ?? 0
            let streakDays = (try? db.queryScalarInt(
                "SELECT streak_days FROM creature WHERE id = 1"
            )) ?? 0
            let firstJournal = try? db.queryScalarText(
                "SELECT timestamp FROM journal ORDER BY timestamp ASC LIMIT 1"
            )

            return .success([
                "total_commits_eaten": totalCommits,
                "total_sessions": totalSessions,
                "total_conversations": totalSpeech,
                "total_touches": totalTouches,
                "streak_days": streakDays,
                "first_memory": firstJournal as Any,
                "xp": gc.totalXP,
                "stage": "\(gc.creatureStage)"
            ])

        case "failed_speech":
            return recallQuery(db, sql:
                "SELECT type, summary, timestamp FROM journal WHERE type = 'failed_speech' ORDER BY timestamp DESC LIMIT ?",
                args: [count], label: "failed_speech")

        default:
            return .failure(
                error: "Unknown recall filter '\(filter)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    private func recallQuery(
        _ db: DatabaseManager,
        sql: String,
        args: [Any?],
        label: String
    ) -> IPCResult {
        do {
            let rows = try db.query(sql, arguments: args)
            return .success([
                "memories": rows,
                "count": rows.count,
                "filter": label
            ])
        } catch {
            NSLog("[Pushling/IPC] Recall query failed: %@", "\(error)")
            return .success([
                "memories": [] as [Any],
                "count": 0,
                "filter": label,
                "error": "Query failed: \(error.localizedDescription)"
            ])
        }
    }
}

// MARK: - Teach Handler

extension CommandRouter {

    func handleTeach(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "list"

        switch action {
        case "compose":
            return handleTeachCompose(req, gc: gc)
        case "list":
            return handleTeachList(gc)
        case "preview":
            return .success([
                "note": "Preview plays the choreography immediately. "
                    + "Use 'perform' with the trick name after committing."
            ])
        case "refine":
            return .success([
                "note": "To refine a trick, use 'compose' again with the same name "
                    + "and updated choreography. It will replace the previous version."
            ])
        case "commit":
            return handleTeachCommit(req, gc: gc)
        case "remove":
            return handleTeachRemove(req, gc: gc)
        default:
            return .failure(
                error: "Unknown teach action '\(action)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    private func handleTeachCompose(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let choreography = req.params["choreography"] as? [String: Any] else {
            let vocab = ChoreographyParser.vocabulary(stage: gc.creatureStage)
            return .success([
                "note": "Pass a 'choreography' object to compose a new trick. "
                    + "Here's the vocabulary reference:",
                "vocabulary": vocab
            ])
        }

        let result = ChoreographyParser.parse(choreography)

        switch result {
        case .success(let definition):
            if definition.stageMin > gc.creatureStage {
                return .failure(
                    error: "This trick requires \(definition.stageMin)+ stage. "
                        + "Currently at \(gc.creatureStage).",
                    code: "STAGE_GATED"
                )
            }

            return .success([
                "valid": true,
                "name": definition.name,
                "category": definition.category,
                "tracks": definition.activeTrackNames,
                "duration_s": definition.durationSeconds,
                "stage_min": "\(definition.stageMin)",
                "note": "Choreography validated. Use 'teach commit' with the same "
                    + "choreography to save it permanently."
            ])

        case .failure(let errors):
            let errorMessages = errors.map(\.description)
            return .failure(
                error: "Choreography validation failed:\n"
                    + errorMessages.joined(separator: "\n"),
                code: "INVALID_CHOREOGRAPHY"
            )
        }
    }

    private func handleTeachCommit(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let choreography = req.params["choreography"] as? [String: Any] else {
            return .failure(
                error: "Missing 'choreography' parameter. "
                    + "Compose first, then commit the same JSON.",
                code: "INVALID_PARAMS"
            )
        }

        let result = ChoreographyParser.parse(choreography)

        switch result {
        case .success(let definition):
            let db = gc.stateCoordinator.database
            let jsonData = try? JSONSerialization.data(withJSONObject: choreography)
            let jsonStr = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())

            do {
                try db.execute(
                    """
                    INSERT INTO journal (type, summary, timestamp, data)
                    VALUES ('teach', ?, ?, ?)
                    """,
                    arguments: [
                        "Taught trick: \(definition.name)",
                        now,
                        jsonStr
                    ]
                )
            } catch {
                return .failure(
                    error: "Failed to save trick: \(error.localizedDescription)",
                    code: "DB_ERROR"
                )
            }

            return .success([
                "committed": true,
                "name": definition.name,
                "note": "Trick '\(definition.name)' saved! "
                    + "Use 'perform \(definition.name)' to execute it. "
                    + "It will also appear in idle rotation."
            ])

        case .failure(let errors):
            let errorMessages = errors.map(\.description)
            return .failure(
                error: "Cannot commit — choreography has errors:\n"
                    + errorMessages.joined(separator: "\n"),
                code: "INVALID_CHOREOGRAPHY"
            )
        }
    }

    private func handleTeachList(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database
        do {
            let rows = try db.query(
                "SELECT summary, timestamp FROM journal WHERE type = 'teach' ORDER BY timestamp DESC"
            )
            let tricks = rows.map { row -> [String: Any] in
                [
                    "name": (row["summary"] as? String)?
                        .replacingOccurrences(of: "Taught trick: ", with: "") ?? "unknown",
                    "taught_at": row["timestamp"] ?? ""
                ]
            }
            return .success(["tricks": tricks, "count": tricks.count])
        } catch {
            return .success(["tricks": [] as [Any], "count": 0])
        }
    }

    private func handleTeachRemove(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let name = req.params["name"] as? String else {
            return .failure(
                error: "Missing 'name' parameter — which trick to remove?",
                code: "INVALID_PARAMS"
            )
        }

        let db = gc.stateCoordinator.database
        do {
            try db.execute(
                "DELETE FROM journal WHERE type = 'teach' AND summary LIKE ?",
                arguments: ["%\(name)%"]
            )
            return .success([
                "removed": true,
                "name": name
            ])
        } catch {
            return .failure(
                error: "Failed to remove trick: \(error.localizedDescription)",
                code: "DB_ERROR"
            )
        }
    }
}

// MARK: - Nurture Handler

extension CommandRouter {

    func handleNurture(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "list"

        switch action {
        case "identity":
            return handleNurtureIdentity(req, gc: gc)
        case "habit":
            return .failure(
                error: "Habit system is being developed. Habits will let you define "
                    + "automatic behaviors triggered by events (commits, idle time, etc.). "
                    + "Use 'nurture identity' to set name/title/motto now.",
                code: "NOT_IMPLEMENTED"
            )
        case "preference":
            return .failure(
                error: "Preference system is being developed. Preferences will let you "
                    + "set likes/dislikes that influence autonomous behavior. "
                    + "Use 'nurture identity' to set name/title/motto now.",
                code: "NOT_IMPLEMENTED"
            )
        case "quirk":
            return .failure(
                error: "Quirk system is being developed. Quirks will add probabilistic "
                    + "character flourishes to idle behavior. "
                    + "Use 'nurture identity' to set name/title/motto now.",
                code: "NOT_IMPLEMENTED"
            )
        case "routine":
            return .failure(
                error: "Routine system is being developed. Routines will define "
                    + "time-of-day behavior sequences. "
                    + "Use 'nurture identity' to set name/title/motto now.",
                code: "NOT_IMPLEMENTED"
            )
        case "suggest":
            return handleNurtureSuggest(gc)
        case "list":
            return handleNurtureList(gc)
        case "remove":
            return .failure(
                error: "Nurture removal is not yet implemented. "
                    + "Identity changes can be made by setting new values.",
                code: "NOT_IMPLEMENTED"
            )
        default:
            return .failure(
                error: "Unknown nurture action '\(action)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    private func handleNurtureIdentity(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let db = gc.stateCoordinator.database
        var changes: [String: String] = [:]

        if let name = req.params["name"] as? String, !name.isEmpty {
            do {
                try db.execute(
                    "UPDATE creature SET name = ? WHERE id = 1",
                    arguments: [name]
                )
                changes["name"] = name
            } catch {
                return .failure(
                    error: "Failed to update name: \(error.localizedDescription)",
                    code: "DB_ERROR"
                )
            }
        }

        if let title = req.params["title"] as? String {
            do {
                try db.execute(
                    "UPDATE creature SET title = ? WHERE id = 1",
                    arguments: [title]
                )
                changes["title"] = title
            } catch {
                return .failure(
                    error: "Failed to update title: \(error.localizedDescription)",
                    code: "DB_ERROR"
                )
            }
        }

        if let motto = req.params["motto"] as? String {
            do {
                try db.execute(
                    "UPDATE creature SET motto = ? WHERE id = 1",
                    arguments: [motto]
                )
                changes["motto"] = motto
            } catch {
                return .failure(
                    error: "Failed to update motto: \(error.localizedDescription)",
                    code: "DB_ERROR"
                )
            }
        }

        if changes.isEmpty {
            return .failure(
                error: "No identity fields provided. "
                    + "Pass 'name', 'title', and/or 'motto'.",
                code: "INVALID_PARAMS"
            )
        }

        journalLog(gc, type: "nurture",
                   summary: "Identity updated: \(changes.keys.joined(separator: ", "))")

        return .success([
            "updated": changes,
            "note": "Identity updated. The creature responds to its new identity."
        ])
    }

    private func handleNurtureSuggest(_ gc: GameCoordinator) -> IPCResult {
        var suggestions: [[String: String]] = []

        let emo = gc.emotionalState

        if emo.satisfaction < 30 {
            suggestions.append([
                "action": "Commit some code! The creature is hungry.",
                "type": "feeding"
            ])
        }
        if emo.energy < 20 {
            suggestions.append([
                "action": "Let the creature rest — use 'perform nap'.",
                "type": "rest"
            ])
        }
        if emo.curiosity > 70 {
            suggestions.append([
                "action": "Teach a new trick — the creature is eager to learn.",
                "type": "teach"
            ])
        }
        if gc.creatureName == "Pushling" {
            suggestions.append([
                "action": "Give the creature a name with 'nurture identity'.",
                "type": "identity"
            ])
        }
        suggestions.append([
            "action": "Express joy or love to build the bond.",
            "type": "expression"
        ])

        return .success(["suggestions": suggestions])
    }

    private func handleNurtureList(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database

        let nameRow = try? db.query(
            "SELECT name, title, motto FROM creature WHERE id = 1"
        )
        let identity: [String: Any] = [
            "name": nameRow?.first?["name"] as? String ?? gc.creatureName,
            "title": nameRow?.first?["title"] as Any,
            "motto": nameRow?.first?["motto"] as Any
        ]

        let nurtureEntries: [[String: Any]]
        if let rows = try? db.query(
            "SELECT summary, timestamp FROM journal WHERE type = 'nurture' ORDER BY timestamp DESC LIMIT 20"
        ) {
            nurtureEntries = rows
        } else {
            nurtureEntries = []
        }

        return .success([
            "identity": identity,
            "nurture_history": nurtureEntries,
            "habits": [] as [Any],
            "preferences": [] as [Any],
            "quirks": [] as [Any],
            "routines": [] as [Any],
            "note": "Habits, preferences, quirks, and routines are coming soon. "
                + "Identity is live."
        ])
    }
}

// MARK: - Journal Logging Helper

extension CommandRouter {

    /// Convenience to log an action to the journal table.
    func journalLog(_ gc: GameCoordinator, type: String, summary: String) {
        let db = gc.stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())

        db.performWriteAsync({
            try db.execute(
                "INSERT INTO journal (type, summary, timestamp) VALUES (?, ?, ?)",
                arguments: [type, summary, now]
            )
        })
    }
}
