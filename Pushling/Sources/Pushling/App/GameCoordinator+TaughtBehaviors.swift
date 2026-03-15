// GameCoordinator+TaughtBehaviors.swift — Taught behavior loading, wiring, lifecycle
// Loads taught behaviors from SQLite on startup, registers with engine,
// wires mastery tracking, idle rotation governor, and behavior breeding.
//
// Extracted from GameCoordinator+Loading.swift for file size limits.

import Foundation

// MARK: - Taught Behavior System Wiring

extension GameCoordinator {

    /// The in-memory registry of taught behavior definitions keyed by name.
    /// Populated on startup from SQLite, updated when tricks are taught/removed.
    private static var _taughtDefinitions: [String: ChoreographyDefinition] = [:]

    /// All currently registered taught behavior definitions.
    var taughtDefinitions: [String: ChoreographyDefinition] {
        Self._taughtDefinitions
    }

    /// Load taught behaviors from SQLite and wire engine, mastery, governor,
    /// and breeding subsystems into the autonomous layer.
    func wireTaughtBehaviors() {
        let db = stateCoordinator.database

        // 1. Load taught behaviors from DB -> definitions + mastery records
        let rows = (try? db.query(
            """
            SELECT name, category, stage_min, duration_s,
                   tracks_json, triggers_json,
                   performance_count, last_performed_at,
                   source, parent_a, parent_b
            FROM taught_behaviors
            """
        )) ?? []

        var masteryData: [(name: String, count: Int,
                           lastPerformed: Date?, fumbles: Int)] = []
        let dateFormatter = ISO8601DateFormatter()

        for row in rows {
            guard let name = row["name"] as? String,
                  let tracksJSON = row["tracks_json"] as? String,
                  let triggersJSON = row["triggers_json"] as? String else {
                continue
            }

            let category = (row["category"] as? String) ?? "playful"
            let stageStr = (row["stage_min"] as? String) ?? "critter"
            let duration = (row["duration_s"] as? Double) ?? 3.0
            let stageMin = GrowthStage.allCases.first {
                "\($0)" == stageStr
            } ?? .critter

            guard let tracks = Self.deserializeTracks(tracksJSON) else {
                NSLog("[Pushling/Teach] Failed to parse tracks for '%@'", name)
                continue
            }
            let triggers = Self.deserializeTriggers(triggersJSON)

            let definition = ChoreographyDefinition(
                name: name, category: category,
                stageMin: stageMin,
                durationSeconds: duration,
                tracks: tracks, triggers: triggers
            )
            Self._taughtDefinitions[name] = definition

            let perfCount = (row["performance_count"] as? Int) ?? 0
            let lastPerf: Date?
            if let dateStr = row["last_performed_at"] as? String {
                lastPerf = dateFormatter.date(from: dateStr)
            } else {
                lastPerf = nil
            }
            masteryData.append((name, perfCount, lastPerf, 0))

            let source = (row["source"] as? String) ?? "taught"
            if source == "self_taught" {
                behaviorBreeding.registerHybrid(name: name)
            }
        }

        // 2. Bulk-load mastery records
        masteryTracker.loadRecords(masteryData)

        // 3. Wire autonomous layer with taught behavior dependencies
        if let stack = scene.behaviorStack {
            stack.autonomous.taughtEngine = taughtBehaviorEngine
            stack.autonomous.taughtMastery = masteryTracker
            stack.autonomous.taughtGovernor = idleRotationGovernor
            stack.autonomous.taughtDefinitions = { [weak self] in
                self?.taughtDefinitions ?? [:]
            }
            stack.autonomous.onTaughtBehaviorCompleted = {
                [weak self] name, definition, currentTime in
                self?.handleTaughtBehaviorCompleted(
                    name: name, definition: definition,
                    currentTime: currentTime
                )
            }

            // 3b. Wire object interaction (Orphans #4 + #5)
            stack.autonomous.objectQuery = { [weak self] in
                guard let self = self else { return [] }
                return self.scene.worldManager.objectRenderer.activeObjects.map {
                    (id: $0.id, type: $0.definition.interaction,
                     x: $0.definition.positionX)
                }
            }
            stack.autonomous.attractionScorer = attractionScorer
            stack.autonomous.objectInteractionEngine = objectInteractionEngine
            stack.autonomous.onObjectInteractionCompleted = {
                [weak self] objectID, interactionName, satisfaction in
                guard let self = self else { return }
                self.attractionScorer.recordInteraction(objectID: objectID)
                self.emotionalState.boostFromInteraction()
                NSLog("[Pushling/Objects] Autonomous interaction '%@' "
                      + "with '%@' complete (sat +%.0f)",
                      interactionName, objectID, satisfaction)
            }
        }

        // 4. Wire breeding success -> store hybrid in DB + register
        behaviorBreeding.onBreedingSuccess = {
            [weak self] result in
            self?.handleBreedingResult(result)
        }

        NSLog("[Pushling/Coordinator] Taught behavior system wired — "
              + "%d behaviors loaded, %d mastery records",
              Self._taughtDefinitions.count, masteryData.count)
    }

    // MARK: - Runtime Registration

    /// Registers a newly taught behavior at runtime (from teach commit).
    func registerTaughtBehavior(_ definition: ChoreographyDefinition) {
        Self._taughtDefinitions[definition.name] = definition
        NSLog("[Pushling/Teach] Registered runtime behavior: '%@'",
              definition.name)
    }

    /// Unregisters a taught behavior at runtime (from teach remove).
    func unregisterTaughtBehavior(name: String) {
        Self._taughtDefinitions.removeValue(forKey: name)
        masteryTracker.removeRecord(for: name)
        behaviorBreeding.removeHybrid(name: name)
        NSLog("[Pushling/Teach] Unregistered behavior: '%@'", name)
    }

    // MARK: - Completion Handlers

    /// Called when the autonomous layer finishes playing a taught behavior.
    /// Updates mastery, persists to DB, and checks for breeding.
    private func handleTaughtBehaviorCompleted(
        name: String, definition: ChoreographyDefinition,
        currentTime: TimeInterval
    ) {
        let personalitySnap = self.personality.toSnapshot()

        // 1. Record mastery + detect level-up
        let leveledUp = masteryTracker.recordPerformance(
            behaviorName: name, triggerType: "idle",
            personality: personalitySnap
        )

        // 2. Record in governor
        idleRotationGovernor.recordTaughtPerformance(
            currentTime: currentTime
        )

        // 3. Check breeding opportunity
        behaviorBreeding.recordPerformance(
            name: name, definition: definition,
            currentTime: currentTime
        )

        // 4. Persist updated performance count + mastery to DB
        let db = stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        let mastery = masteryTracker.masteryLevel(for: name)

        db.performWriteAsync({
            try db.execute(
                """
                UPDATE taught_behaviors
                SET performance_count = performance_count + 1,
                    mastery_level = ?,
                    last_performed_at = ?
                WHERE name = ?
                """,
                arguments: [mastery.rawValue, now, name]
            )
        })

        if leveledUp {
            NSLog("[Pushling/Teach] '%@' leveled up to %@!",
                  name, mastery.displayName)
        }
    }

    /// Called when BehaviorBreeding produces a hybrid.
    private func handleBreedingResult(_ result: BreedingResult) {
        let definition = result.hybridDefinition
        Self._taughtDefinitions[result.name] = definition

        let db = stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        let tracksJSON = CommandRouter.serializeTracks(definition.tracks)
        let triggersJSON = CommandRouter.serializeTriggers(definition.triggers)

        db.performWriteAsync({
            try db.execute(
                """
                INSERT OR IGNORE INTO taught_behaviors
                    (name, category, stage_min, duration_s,
                     tracks_json, triggers_json, source,
                     parent_a, parent_b, created_at)
                VALUES (?, ?, ?, ?, ?, ?, 'self_taught', ?, ?, ?)
                """,
                arguments: [
                    result.name, definition.category,
                    "\(definition.stageMin)",
                    definition.durationSeconds,
                    tracksJSON, triggersJSON,
                    result.parentA, result.parentB, now
                ]
            )

            try db.execute(
                """
                INSERT INTO journal (type, summary, timestamp)
                VALUES ('teach', ?, ?)
                """,
                arguments: [
                    "Self-taught hybrid: \(result.name) "
                        + "(from \(result.parentA) + \(result.parentB))",
                    now
                ]
            )
        })

        NSLog("[Pushling/Teach] Hybrid bred and saved: '%@'", result.name)
    }

    // MARK: - JSON Deserialization

    /// Deserializes tracks JSON from DB into [String: [Keyframe]].
    static func deserializeTracks(
        _ json: String
    ) -> [String: [Keyframe]]? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data)
                  as? [String: [[String: Any]]] else {
            return nil
        }

        var tracks: [String: [Keyframe]] = [:]
        for (trackName, kfArray) in dict {
            var keyframes: [Keyframe] = []
            for kfDict in kfArray {
                let time = (kfDict["t"] as? Double) ?? 0
                let state = (kfDict["state"] as? String) ?? "neutral"
                let easingStr = (kfDict["easing"] as? String) ?? "easeInOut"
                let easing = Keyframe.EasingType(rawValue: easingStr)
                    ?? .easeInOut
                var params: [String: String] = [:]
                if let t = kfDict["text"] as? String { params["text"] = t }
                if let s = kfDict["style"] as? String { params["style"] = s }
                if let s = kfDict["sound"] as? String { params["sound"] = s }
                keyframes.append(Keyframe(
                    time: time, state: state,
                    easing: easing, params: params
                ))
            }
            keyframes.sort { $0.time < $1.time }
            tracks[trackName] = keyframes
        }
        return tracks
    }

    /// Deserializes triggers JSON from DB into TriggerConfig.
    static func deserializeTriggers(_ json: String) -> TriggerConfig {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data)
                  as? [String: Any] else {
            return TriggerConfig(
                idleWeight: 0.2, onTouch: false, onCommitTypes: [],
                emotionalConditions: [], timeConditions: nil,
                cooldownSeconds: 300, contexts: []
            )
        }

        return TriggerConfig(
            idleWeight: (dict["idle_weight"] as? Double) ?? 0.2,
            onTouch: (dict["on_touch"] as? Bool) ?? false,
            onCommitTypes: (dict["on_commit_type"] as? [String]) ?? [],
            emotionalConditions: [],
            timeConditions: nil,
            cooldownSeconds: (dict["cooldown_s"] as? Double) ?? 300,
            contexts: (dict["contexts"] as? [String]) ?? []
        )
    }
}
