// SenseHandlers.swift — pushling_sense: Claude's perception system
// Extension on CommandRouter for all 8 sense aspects.
// Reads live state from EmotionalState, Personality, WorldManager, DB.

import Foundation
import CoreGraphics

// MARK: - Sense Handler

extension CommandRouter {

    func handleSense(_ req: IPCRequest) -> IPCResult {
        let aspect = req.action ?? "full"

        guard let gc = gameCoordinator else {
            return .failure(
                error: "Creature systems not yet initialized. Wait for daemon startup.",
                code: "NOT_READY"
            )
        }

        switch aspect {
        case "self":
            return senseSelf(gc)
        case "body":
            return senseBody(gc)
        case "surroundings":
            return senseSurroundings(gc)
        case "visual":
            return .success([
                "note": "Visual screenshot capture is not yet implemented. "
                    + "Use 'sense surroundings' for world state."
            ])
        case "events":
            return senseEvents(gc)
        case "developer":
            return senseDeveloper(gc)
        case "evolve":
            return senseEvolve(gc)
        case "full":
            return senseFull(gc)
        default:
            return .failure(
                error: "Unknown aspect '\(aspect)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    // MARK: - Sense Sub-Handlers

    private func senseSelf(_ gc: GameCoordinator) -> IPCResult {
        let emo = gc.emotionalState
        let emergent = gc.emergentStates.currentState

        var data: [String: Any] = [
            "satisfaction": round(emo.satisfaction * 10) / 10,
            "curiosity": round(emo.curiosity * 10) / 10,
            "contentment": round(emo.contentment * 10) / 10,
            "energy": round(emo.energy * 10) / 10
        ]

        if let emergent = emergent {
            data["emergent_state"] = emergent.rawValue
            data["emergent_active_for_s"] = Int(gc.emergentStates.stateActiveTime)
        }

        // Streak from DB
        let db = gc.stateCoordinator.database
        if let streak = try? db.queryScalarInt(
            "SELECT streak_days FROM creature WHERE id = 1"
        ) {
            data["streak_days"] = streak
        }

        // Last fed time
        if let lastFed = try? db.queryScalarText(
            "SELECT timestamp FROM journal WHERE type = 'commit' ORDER BY timestamp DESC LIMIT 1"
        ) {
            data["last_fed"] = lastFed
        }

        // Session state
        data["is_session_active"] = gc.commandRouter.sessionManager.isSessionActive

        return .success(["emotions": data])
    }

    private func senseBody(_ gc: GameCoordinator) -> IPCResult {
        let p = gc.personality
        let stage = gc.creatureStage

        // Query tricks from DB
        let db = gc.stateCoordinator.database
        let trickCount = (try? db.queryScalarInt(
            "SELECT COUNT(*) FROM journal WHERE type = 'teach'"
        )) ?? 0

        let trickNames: [String]
        if let rows = try? db.query(
            "SELECT summary FROM journal WHERE type = 'teach' ORDER BY timestamp DESC LIMIT 10"
        ) {
            trickNames = rows.compactMap { $0["summary"] as? String }
        } else {
            trickNames = []
        }

        // Creature position from behavior stack
        var posX: CGFloat = 542.5
        var facing = "right"
        if let creature = gc.scene.creatureNode {
            posX = creature.position.x
            facing = creature.facing.rawValue
        }

        return .success([
            "name": gc.creatureName,
            "stage": "\(stage)",
            "xp": gc.totalXP,
            "position_x": Int(posX),
            "facing": facing,
            "personality": [
                "energy": round(p.energy * 100) / 100,
                "verbosity": round(p.verbosity * 100) / 100,
                "focus": round(p.focus * 100) / 100,
                "discipline": round(p.discipline * 100) / 100,
                "specialty": p.specialty.rawValue
            ] as [String: Any],
            "tricks_known": trickCount,
            "trick_names": trickNames,
            "is_sleeping": gc.scene.creatureNode?.isSleeping ?? false,
            "current_animation": gc.scene.behaviorStack?.physics.isSleeping ?? false
                ? "sleep" : "idle"
        ])
    }

    private func senseSurroundings(_ gc: GameCoordinator) -> IPCResult {
        let wm = gc.scene.worldManager

        // Creature position for biome lookup
        let creatureX = gc.scene.creatureNode?.position.x ?? 542.5

        let biome = wm.currentBiome(at: creatureX)
        let weather = wm.currentWeather
        let timePeriod = wm.currentTimePeriod
        let moonPhase = wm.moonPhaseName

        // Nearby landmark
        var landmarkInfo: [String: Any]? = nil
        if let landmark = wm.nearestLandmark(to: creatureX) {
            landmarkInfo = [
                "name": landmark.repoName,
                "type": landmark.landmarkType.rawValue,
                "distance": Int(abs(landmark.worldX - creatureX))
            ]
        }

        return .success([
            "weather": weather.rawValue,
            "biome": biome.rawValue,
            "time_of_day": timePeriod.rawValue,
            "moon_phase": moonPhase,
            "creature_position_x": Int(creatureX),
            "scene_width": Int(SceneConstants.sceneWidth),
            "nearest_landmark": landmarkInfo as Any
        ])
    }

    private func senseEvents(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database

        do {
            let rows = try db.query(
                """
                SELECT type, summary, timestamp
                FROM journal
                ORDER BY timestamp DESC
                LIMIT 20
                """
            )
            let events = rows.map { row -> [String: Any] in
                [
                    "type": row["type"] ?? "unknown",
                    "summary": row["summary"] ?? "",
                    "timestamp": row["timestamp"] ?? ""
                ]
            }
            return .success(["recent_events": events, "count": events.count])
        } catch {
            return .success(["recent_events": [] as [Any], "count": 0])
        }
    }

    private func senseDeveloper(_ gc: GameCoordinator) -> IPCResult {
        let db = gc.stateCoordinator.database

        // Today's commit count
        let formatter = ISO8601DateFormatter()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let todayStr = formatter.string(from: startOfDay)

        let todayCommits = (try? db.queryScalarInt(
            "SELECT COUNT(*) FROM commits WHERE timestamp >= ?",
            arguments: [todayStr]
        )) ?? 0

        // Last commit time
        let lastCommitTime = try? db.queryScalarText(
            "SELECT timestamp FROM commits ORDER BY timestamp DESC LIMIT 1"
        )

        // Time since last commit
        var lastCommitAgoS: Int = -1
        if let timeStr = lastCommitTime {
            let fmt = ISO8601DateFormatter()
            if let date = fmt.date(from: timeStr) {
                lastCommitAgoS = Int(Date().timeIntervalSince(date))
            }
        }

        // Session duration
        let sessionDuration: Int
        if let session = gc.commandRouter.sessionManager.activeSession {
            sessionDuration = Int(session.duration)
        } else {
            sessionDuration = 0
        }

        return .success([
            "commits_today": todayCommits,
            "last_commit_time": lastCommitTime as Any,
            "last_commit_ago_s": lastCommitAgoS,
            "session_active": gc.commandRouter.sessionManager.isSessionActive,
            "session_duration_s": sessionDuration
        ])
    }

    private func senseEvolve(_ gc: GameCoordinator) -> IPCResult {
        let stage = gc.creatureStage
        let xp = gc.totalXP

        let thresholds: [GrowthStage: Int] = [
            .spore: 0, .drop: 100, .critter: 500,
            .beast: 2000, .sage: 8000, .apex: 20000
        ]

        // Find next stage threshold
        let allStages = GrowthStage.allCases
        let currentIdx = allStages.firstIndex(of: stage) ?? 0
        let nextIdx = currentIdx + 1

        if nextIdx >= allStages.count {
            return .success([
                "stage": "\(stage)",
                "xp": xp,
                "eligible": false,
                "at_max_stage": true,
                "message": "You have reached Apex — the highest form."
            ])
        }

        let nextStage = allStages[nextIdx]
        let threshold = thresholds[nextStage] ?? 99999
        let progress = min(Double(xp) / Double(threshold), 1.0)

        return .success([
            "stage": "\(stage)",
            "next_stage": "\(nextStage)",
            "xp": xp,
            "threshold": threshold,
            "progress": round(progress * 1000) / 10,  // e.g. 45.2%
            "eligible": xp >= threshold
        ])
    }

    private func senseFull(_ gc: GameCoordinator) -> IPCResult {
        // Combine key data from all aspects into a single response
        let emo = gc.emotionalState
        let emergent = gc.emergentStates.currentState
        let p = gc.personality
        let stage = gc.creatureStage
        let wm = gc.scene.worldManager
        let creatureX = gc.scene.creatureNode?.position.x ?? 542.5

        var emotionData: [String: Any] = [
            "satisfaction": round(emo.satisfaction * 10) / 10,
            "curiosity": round(emo.curiosity * 10) / 10,
            "contentment": round(emo.contentment * 10) / 10,
            "energy": round(emo.energy * 10) / 10
        ]
        if let emergent = emergent {
            emotionData["emergent_state"] = emergent.rawValue
        }

        return .success([
            "emotions": emotionData,
            "body": [
                "name": gc.creatureName,
                "stage": "\(stage)",
                "xp": gc.totalXP,
                "position_x": Int(creatureX),
                "facing": gc.scene.creatureNode?.facing.rawValue ?? "right",
                "is_sleeping": gc.scene.creatureNode?.isSleeping ?? false
            ] as [String: Any],
            "personality": [
                "energy": round(p.energy * 100) / 100,
                "verbosity": round(p.verbosity * 100) / 100,
                "focus": round(p.focus * 100) / 100,
                "discipline": round(p.discipline * 100) / 100,
                "specialty": p.specialty.rawValue
            ] as [String: Any],
            "surroundings": [
                "weather": wm.currentWeather.rawValue,
                "biome": wm.currentBiome(at: creatureX).rawValue,
                "time_of_day": wm.currentTimePeriod.rawValue
            ] as [String: Any],
            "session": [
                "active": sessionManager.isSessionActive,
                "duration_s": sessionManager.activeSession.map { Int($0.duration) } ?? 0
            ] as [String: Any]
        ])
    }
}
