// PushlingScene+DebugStats.swift — Detailed stats and export debug methods
// Extracted from PushlingScene+Debug.swift to stay under 500 lines.
// Contains: full stats, world state, behavior stack, JSON export.

import SpriteKit

// MARK: - PushlingScene Debug Stats & Export

extension PushlingScene {

    // MARK: - Stats: Full

    /// Comprehensive stats dump: emotions, personality, XP, stage,
    /// streak, tricks, habits, preferences, mutations.
    func debugLogFullStats(coordinator: GameCoordinator?) {
        debugLogStats()

        guard let coord = coordinator else {
            NSLog("[Pushling/Debug] (No coordinator — skipping "
                  + "subsystem stats)")
            return
        }

        NSLog("[Pushling/Debug] === FULL SUBSYSTEM STATE ===")

        // Emotions
        let emo = coord.emotionalState
        NSLog("[Pushling/Debug] -- Emotions --")
        NSLog("[Pushling/Debug]   Satisfaction: %.1f",
              emo.satisfaction)
        NSLog("[Pushling/Debug]   Curiosity:    %.1f", emo.curiosity)
        NSLog("[Pushling/Debug]   Contentment:  %.1f",
              emo.contentment)
        NSLog("[Pushling/Debug]   Energy:       %.1f", emo.energy)

        // Emergent state
        let emergent = coord.emergentStates
        NSLog("[Pushling/Debug]   Emergent: %@",
              emergent.currentState.map { "\($0)" } ?? "none")

        // Personality
        let pers = coord.personality
        NSLog("[Pushling/Debug] -- Personality --")
        NSLog("[Pushling/Debug]   Energy:     %.2f", pers.energy)
        NSLog("[Pushling/Debug]   Verbosity:  %.2f", pers.verbosity)
        NSLog("[Pushling/Debug]   Focus:      %.2f", pers.focus)
        NSLog("[Pushling/Debug]   Discipline: %.2f", pers.discipline)

        // Growth
        NSLog("[Pushling/Debug] -- Growth --")
        NSLog("[Pushling/Debug]   Stage: %@",
              "\(coord.creatureStage)")
        NSLog("[Pushling/Debug]   Name:  %@", coord.creatureName)
        NSLog("[Pushling/Debug]   XP:    %d", coord.totalXP)

        // Mutations
        let mut = coord.mutationSystem
        let badgeList = mut.earnedBadges.map { $0.displayName }
            .joined(separator: ", ")
        NSLog("[Pushling/Debug] -- Mutations --")
        NSLog("[Pushling/Debug]   Earned: %@ (%d/%d)",
              badgeList.isEmpty ? "none" : badgeList,
              mut.earnedBadges.count,
              MutationBadge.allCases.count)

        // Session
        let sm = coord.commandRouter.sessionManager
        NSLog("[Pushling/Debug] -- Session --")
        NSLog("[Pushling/Debug]   Active: %@",
              sm.isSessionActive ? "yes" : "no")
        if let info = sm.activeSession {
            NSLog("[Pushling/Debug]   Session ID: %@",
                  info.sessionId)
            NSLog("[Pushling/Debug]   Duration: %.0fs",
                  info.duration)
            NSLog("[Pushling/Debug]   Commands: %d",
                  info.commandCount)
        }

        // Surprises
        NSLog("[Pushling/Debug] -- Surprises --")
        NSLog("[Pushling/Debug]   Registered: %d",
              coord.surpriseScheduler.registeredCount)
        NSLog("[Pushling/Debug]   Playing: %@",
              coord.surprisePlayer.isPlaying ? "yes" : "no")

        NSLog("[Pushling/Debug] === END FULL STATE ===")
    }

    // MARK: - Stats: World State

    func debugLogWorldState() {
        NSLog("[Pushling/Debug] === WORLD STATE ===")

        let weather = worldManager.weatherSystem
        NSLog("[Pushling/Debug]   Weather: %@",
              weather.currentState.rawValue)

        if let biomeM = worldManager.biomeManager {
            NSLog("[Pushling/Debug]   Biome manager: active")
            _ = biomeM
        } else {
            NSLog("[Pushling/Debug]   Biome manager: nil")
        }

        NSLog("[Pushling/Debug]   Sky system: active")
        NSLog("[Pushling/Debug]   Camera world-X: %.1f",
              worldManager.cameraWorldX)
        NSLog("[Pushling/Debug]   World set up: %@",
              worldManager.isSetUp ? "yes" : "no")
        NSLog("[Pushling/Debug]   Visual complexity: active")
        NSLog("[Pushling/Debug]   Landmarks: active")
        NSLog("[Pushling/Debug]   Objects: (system not yet wired)")
        NSLog("[Pushling/Debug]   Companions: (system not yet wired)")

        NSLog("[Pushling/Debug] === END WORLD STATE ===")
    }

    // MARK: - Stats: Behavior Stack

    func debugLogBehaviorStack() {
        guard let stack = behaviorStack else {
            NSLog("[Pushling/Debug] No behavior stack")
            return
        }

        NSLog("[Pushling/Debug] === BEHAVIOR STACK STATE ===")
        NSLog("[Pushling/Debug]   Stage: %@", "\(stack.stage)")

        let physics = stack.physics
        NSLog("[Pushling/Debug] -- Physics Layer --")
        NSLog("[Pushling/Debug]   Sleeping: %@",
              physics.isSleeping ? "yes" : "no")
        NSLog("[Pushling/Debug]   Breathing: always active")

        let reflexes = stack.reflexes
        NSLog("[Pushling/Debug] -- Reflexes Layer --")
        NSLog("[Pushling/Debug]   Active reflex: %@",
              reflexes.hasActiveReflex ? "yes" : "no")

        let ai = stack.aiDirected
        NSLog("[Pushling/Debug] -- AI-Directed Layer --")
        NSLog("[Pushling/Debug]   Active: %@",
              ai.isActive ? "yes" : "no")

        let autonomous = stack.autonomous
        NSLog("[Pushling/Debug] -- Autonomous Layer --")
        NSLog("[Pushling/Debug]   Current behavior: %@",
              autonomous.currentBehaviorName ?? "idle")

        let blend = stack.blendController
        NSLog("[Pushling/Debug] -- Blend Controller --")
        NSLog("[Pushling/Debug]   Active blends: %d",
              blend.activeBlendCount)

        NSLog("[Pushling/Debug] === END BEHAVIOR STACK ===")
    }

    // MARK: - Export

    /// Export creature state as JSON to the exports directory.
    func debugExportCreatureJSON(coordinator: GameCoordinator?) {
        guard let creature = creatureNode else {
            NSLog("[Pushling/Debug] No creature to export")
            return
        }

        var json: [String: Any] = [
            "export_time": ISO8601DateFormatter()
                .string(from: Date()),
            "stage": "\(creature.currentStage)",
            "facing": creature.facing.rawValue,
            "position_x": creature.position.x,
            "position_y": creature.position.y,
            "is_sleeping": creature.isSleeping,
            "is_evolving": creature.isEvolving,
            "debug_xp": debugXP,
            "debug_xp_to_next": debugXPToNext,
        ]

        if let coord = coordinator {
            json["name"] = coord.creatureName
            json["total_xp"] = coord.totalXP
            json["personality"] = [
                "energy": coord.personality.energy,
                "verbosity": coord.personality.verbosity,
                "focus": coord.personality.focus,
                "discipline": coord.personality.discipline,
            ]
            json["emotions"] = [
                "satisfaction": coord.emotionalState.satisfaction,
                "curiosity": coord.emotionalState.curiosity,
                "contentment": coord.emotionalState.contentment,
                "energy": coord.emotionalState.energy,
            ]
            json["earned_badges"] = coord.mutationSystem.earnedBadges
                .map { $0.rawValue }
            json["session_active"] = coord.commandRouter
                .sessionManager.isSessionActive
        }

        let exportDir = NSString(
            string: "~/.local/share/pushling/exports"
        ).expandingTildeInPath
        try? FileManager.default.createDirectory(
            atPath: exportDir,
            withIntermediateDirectories: true
        )

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let path = "\(exportDir)/creature-\(timestamp).json"

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: URL(fileURLWithPath: path))
            NSLog("[Pushling/Debug] Exported creature JSON to: %@",
                  path)
        } else {
            NSLog("[Pushling/Debug] Failed to serialize creature JSON")
        }
    }
}
