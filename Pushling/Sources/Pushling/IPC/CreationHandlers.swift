// CreationHandlers.swift — pushling_recall, pushling_teach, pushling_nurture
// Extension on CommandRouter for memory, creation, and nurturing.
// World handler (pushling_world) is in WorldHandlers.swift.
// Dispatches to DatabaseManager, ChoreographyParser, and identity DB.

import Foundation
import CoreGraphics

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
            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())

            // Serialize tracks and triggers for DB storage
            let tracksJSON = Self.serializeTracks(definition.tracks)
            let triggersJSON = Self.serializeTriggers(definition.triggers)

            do {
                // Upsert into taught_behaviors table (replace if same name)
                try db.execute(
                    """
                    INSERT INTO taught_behaviors
                        (name, category, stage_min, duration_s,
                         tracks_json, triggers_json, source, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, 'taught', ?)
                    ON CONFLICT(name) DO UPDATE SET
                        category = excluded.category,
                        stage_min = excluded.stage_min,
                        duration_s = excluded.duration_s,
                        tracks_json = excluded.tracks_json,
                        triggers_json = excluded.triggers_json
                    """,
                    arguments: [
                        definition.name,
                        definition.category,
                        "\(definition.stageMin)",
                        definition.durationSeconds,
                        tracksJSON,
                        triggersJSON,
                        now
                    ]
                )

                // Journal entry
                try db.execute(
                    """
                    INSERT INTO journal (type, summary, timestamp, data)
                    VALUES ('teach', ?, ?, ?)
                    """,
                    arguments: [
                        "Taught trick: \(definition.name)",
                        now,
                        tracksJSON
                    ]
                )
            } catch {
                return .failure(
                    error: "Failed to save trick: \(error.localizedDescription)",
                    code: "DB_ERROR"
                )
            }

            // Register with engine at runtime
            gc.registerTaughtBehavior(definition)

            return .success([
                "committed": true,
                "name": definition.name,
                "mastery": "learning",
                "note": "Trick '\(definition.name)' saved! "
                    + "It will appear in idle rotation (20% chance, max 3/hour). "
                    + "Mastery starts at Learning — performing it improves execution."
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

    /// Serializes tracks to JSON string for DB storage.
    static func serializeTracks(
        _ tracks: [String: [Keyframe]]
    ) -> String {
        var dict: [String: [[String: Any]]] = [:]
        for (trackName, keyframes) in tracks {
            dict[trackName] = keyframes.map { kf in
                var kfDict: [String: Any] = [
                    "t": kf.time,
                    "state": kf.state,
                    "easing": kf.easing.rawValue
                ]
                for (k, v) in kf.params { kfDict[k] = v }
                return kfDict
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    /// Serializes triggers to JSON string for DB storage.
    static func serializeTriggers(
        _ triggers: TriggerConfig
    ) -> String {
        var dict: [String: Any] = [
            "idle_weight": triggers.idleWeight,
            "on_touch": triggers.onTouch,
            "cooldown_s": triggers.cooldownSeconds
        ]
        if !triggers.onCommitTypes.isEmpty {
            dict["on_commit_type"] = triggers.onCommitTypes
        }
        if !triggers.contexts.isEmpty {
            dict["contexts"] = triggers.contexts
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func handleTeachList(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database
        do {
            let rows = try db.query(
                """
                SELECT name, category, stage_min, duration_s,
                       mastery_level, performance_count, strength,
                       source, created_at, last_performed_at
                FROM taught_behaviors ORDER BY created_at DESC
                """
            )
            let tricks = rows.map { row -> [String: Any] in
                let count = (row["performance_count"] as? Int) ?? 0
                let mastery = MasteryLevel(performanceCount: count)
                return [
                    "name": row["name"] ?? "unknown",
                    "category": row["category"] ?? "playful",
                    "stage_min": row["stage_min"] ?? "critter",
                    "duration_s": row["duration_s"] ?? 3.0,
                    "mastery": mastery.displayName,
                    "performances": count,
                    "strength": row["strength"] ?? 0.5,
                    "source": row["source"] ?? "taught",
                    "taught_at": row["created_at"] ?? "",
                    "last_performed": row["last_performed_at"] as Any
                ]
            }
            let governor = gc.idleRotationGovernor
            return .success([
                "tricks": tricks,
                "count": tricks.count,
                "governor": governor.statusSummary
            ])
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
                "DELETE FROM taught_behaviors WHERE name = ?",
                arguments: [name]
            )
            try db.execute(
                "DELETE FROM journal WHERE type = 'teach' AND summary LIKE ?",
                arguments: ["%\(name)%"]
            )
            gc.unregisterTaughtBehavior(name: name)
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
        case "identity":   return handleNurtureIdentity(req, gc: gc)
        case "set":        return handleNurtureSet(req, gc: gc)
        case "habit":      return handleNurtureSetHabit(req, gc: gc)
        case "preference": return handleNurtureSetPreference(req, gc: gc)
        case "quirk":      return handleNurtureSetQuirk(req, gc: gc)
        case "routine":    return handleNurtureSetRoutine(req, gc: gc)
        case "suggest":    return handleNurtureSuggest(gc)
        case "list":       return handleNurtureList(gc)
        case "remove":     return handleNurtureRemove(req, gc: gc)
        case "reinforce":  return handleNurtureReinforce(req, gc: gc)
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
            suggestions.append(["action": "Commit some code! The creature is hungry.", "type": "feeding"])
        }
        if emo.energy < 20 {
            suggestions.append(["action": "Let the creature rest — use 'perform nap'.", "type": "rest"])
        }
        if emo.curiosity > 70 {
            suggestions.append(["action": "Teach a new trick — the creature is eager to learn.", "type": "teach"])
        }
        if gc.creatureName == "Pushling" {
            suggestions.append(["action": "Give the creature a name with 'nurture identity'.", "type": "identity"])
        }
        if gc.habitEngine.habits.isEmpty {
            suggestions.append(["action": "Set a habit — e.g. stretch after every commit.", "type": "habit"])
        }
        if gc.preferenceEngine.allPreferences.isEmpty {
            suggestions.append(["action": "Set a preference — does the creature love rain?", "type": "preference"])
        }
        suggestions.append(["action": "Express joy or love to build the bond.", "type": "expression"])
        return .success(["suggestions": suggestions])
    }

    private func handleNurtureList(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database
        let nameRow = try? db.query("SELECT name, title, motto FROM creature WHERE id = 1")
        let identity: [String: Any] = [
            "name": nameRow?.first?["name"] as? String ?? gc.creatureName,
            "title": nameRow?.first?["title"] as Any,
            "motto": nameRow?.first?["motto"] as Any
        ]
        let nurtureEntries: [[String: Any]]
        if let rows = try? db.query(
            "SELECT summary, timestamp FROM journal "
            + "WHERE type = 'nurture' ORDER BY timestamp DESC LIMIT 20"
        ) { nurtureEntries = rows } else { nurtureEntries = [] }

        let habitList: [[String: Any]] = gc.habitEngine.habits.map { h in
            ["name": h.name, "behavior": h.behavior,
             "frequency": h.frequency.rawValue, "strength": h.strength,
             "reinforcements": h.reinforcementCount]
        }
        let prefList: [[String: Any]] = gc.preferenceEngine.allPreferences.map { p in
            ["subject": p.subject, "valence": p.valence,
             "strength": p.strength, "reinforcements": p.reinforcementCount]
        }
        let quirkList: [[String: Any]] = gc.quirkEngine.activeQuirks.map { q in
            ["name": q.name, "target": q.targetBehavior,
             "probability": q.probability, "strength": q.strength,
             "reinforcements": q.reinforcementCount]
        }
        let routineRows = (try? db.query(
            "SELECT slot, strength, reinforcement_count FROM routines"
        )) ?? []
        let routineList: [[String: Any]] = routineRows.map { r in
            ["slot": r["slot"] as? String ?? "",
             "strength": r["strength"] as? Double ?? 0.5,
             "reinforcements": r["reinforcement_count"] as? Int ?? 0]
        }
        return .success([
            "identity": identity, "nurture_history": nurtureEntries,
            "habits": habitList, "preferences": prefList,
            "quirks": quirkList, "routines": routineList
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
