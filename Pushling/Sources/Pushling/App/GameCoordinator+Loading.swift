// GameCoordinator+Loading.swift — DB loading, nurture wiring, and helpers
// Extracted from GameCoordinator.swift to keep under 500-line limit.

import Foundation
import QuartzCore

// MARK: - DB Loading Helpers

extension GameCoordinator {

    static func loadStage(from db: DatabaseManager) -> GrowthStage {
        let rows = (try? db.query(
            "SELECT stage FROM creature WHERE id = 1"
        )) ?? []
        guard let name = rows.first?["stage"] as? String else {
            return .critter
        }
        return GrowthStage.allCases.first { "\($0)" == name } ?? .critter
    }

    static func loadCreatureName(from db: DatabaseManager) -> String {
        let rows = (try? db.query(
            "SELECT name FROM creature WHERE id = 1"
        )) ?? []
        return (rows.first?["name"] as? String) ?? "Pushling"
    }

    static func loadXP(from db: DatabaseManager) -> Int {
        let rows = (try? db.query(
            "SELECT total_xp FROM creature WHERE id = 1"
        )) ?? []
        return (rows.first?["total_xp"] as? Int) ?? 0
    }

    static func loadCircadian(from db: DatabaseManager) -> CircadianCycle {
        let rows = (try? db.query(
            "SELECT circadian_histogram, circadian_days_tracked "
            + "FROM creature WHERE id = 1"
        )) ?? []
        guard let row = rows.first,
              let json = row["circadian_histogram"] as? String,
              let days = row["circadian_days_tracked"] as? Int else {
            return CircadianCycle()
        }
        return CircadianCycle(
            histogram: CircadianCycle.histogramFrom(json: json),
            daysTracked: days
        )
    }

    static func loadHatched(from db: DatabaseManager) -> Bool {
        let rows = (try? db.query(
            "SELECT hatched FROM creature WHERE id = 1"
        )) ?? []
        guard let hatched = rows.first?["hatched"] as? Int else {
            // No creature row exists — not yet hatched
            return false
        }
        return hatched != 0
    }
}

// MARK: - Mutation System Wiring (Gap 4)

extension GameCoordinator {

    /// Wire mutation system: load earned badges, set callbacks.
    func wireMutations() {
        mutationSystem.onBadgeEarned = { badge, isFirst in
            NSLog("[Pushling/Coordinator] Badge earned: %@ (first: %@)",
                  badge.displayName, isFirst ? "yes" : "no")
            // TODO: Trigger badge ceremony animation
        }

        // Load earned badges from SQLite milestones table
        let db = stateCoordinator.database
        let badgeRows = (try? db.query(
            "SELECT id, earned_at FROM milestones "
            + "WHERE category = 'mutation' AND earned_at IS NOT NULL"
        )) ?? []

        var earned: [(MutationBadge, Date)] = []
        let dateFormatter = ISO8601DateFormatter()
        for row in badgeRows {
            guard let idStr = row["id"] as? String,
                  let badge = MutationBadge(rawValue: idStr),
                  let dateStr = row["earned_at"] as? String,
                  let date = dateFormatter.date(from: dateStr) else {
                continue
            }
            earned.append((badge, date))
        }

        // No crash_recoveries column in schema yet — default to 0
        mutationSystem.loadEarnedBadges(earned, crashRecoveries: 0)

        NSLog("[Pushling/Coordinator] Mutation system wired — "
              + "%d badges loaded", earned.count)
    }
}

// MARK: - Nurture Engine Wiring (Gap 5)

extension GameCoordinator {

    /// Wire nurture engines: load persisted habits, preferences,
    /// quirks, and routines from SQLite.
    func wireNurture() {
        let db = stateCoordinator.database

        // HabitEngine, PreferenceEngine, QuirkEngine, RoutineEngine are
        // already instantiated in init — load persisted data if any.

        // Note: SQLite tables exist per Schema.swift but may be empty.
        // The engines handle empty loads gracefully.

        // Habits
        // (Full habit loading requires parsing trigger JSON — defer)
        NSLog("[Pushling/Coordinator] HabitEngine ready (%d habits)",
              habitEngine.habits.count)

        // Preferences
        loadPreferencesFromDB(db)

        // Quirks
        // (Full quirk loading requires parsing action JSON — defer)
        NSLog("[Pushling/Coordinator] QuirkEngine ready (%d quirks)",
              quirkEngine.quirks.count)

        // Routines
        // (Full routine loading requires parsing step JSON — defer)
        NSLog("[Pushling/Coordinator] RoutineEngine ready")

        NSLog("[Pushling/Coordinator] Nurture engines wired — "
              + "habits: %d, preferences: %d, quirks: %d",
              habitEngine.habits.count,
              preferenceEngine.allPreferences.count,
              quirkEngine.quirks.count)
    }

    /// Load preferences from the SQLite preferences table.
    private func loadPreferencesFromDB(_ db: DatabaseManager) {
        let rows = (try? db.query(
            "SELECT id, subject, valence, strength, "
            + "reinforcement_count, created_at FROM preferences"
        )) ?? []

        var prefs: [Preference] = []
        for row in rows {
            let id: String
            if let intId = row["id"] as? Int {
                id = "\(intId)"
            } else if let strId = row["id"] as? String {
                id = strId
            } else {
                continue
            }
            guard let subject = row["subject"] as? String else { continue }
            let valence = (row["valence"] as? Double) ?? 0.0
            let strength = (row["strength"] as? Double) ?? 0.5
            let reinforcement =
                (row["reinforcement_count"] as? Int) ?? 0

            prefs.append(Preference(
                id: id, subject: subject, valence: valence,
                strength: strength,
                reinforcementCount: reinforcement,
                createdAt: Date()
            ))
        }

        if !prefs.isEmpty {
            preferenceEngine.loadPreferences(prefs)
        }
    }
}

// MARK: - Helper Methods (extracted for file size)

extension GameCoordinator {

    /// Syncs current creature state to the touch handler.
    func syncTouchHandlerState() {
        guard let creature = scene.creatureNode else { return }
        let frame = creature.calculateAccumulatedFrame()
        creatureTouchHandler.creatureHitbox = frame
        touchTracker.creatureHitbox = frame
        gestureRecognizer.creatureHitbox = frame
        creatureTouchHandler.creatureStage = creatureStage
        creatureTouchHandler.personalityEnergy = personality.energy
        creatureTouchHandler.isSleeping =
            scene.behaviorStack?.physics.isSleeping ?? false
    }

    /// Builds a SurpriseContext snapshot for the surprise scheduler.
    func buildSurpriseContext() -> SurpriseContext {
        let sm = commandRouter.sessionManager
        return SurpriseContext(
            wallClock: Date(),
            sceneTime: CACurrentMediaTime(),
            stage: creatureStage,
            personality: personality.toSnapshot(),
            emotions: emotionalState.toSnapshot(),
            isSleeping: scene.behaviorStack?.physics.isSleeping ?? false,
            creatureName: creatureName,
            lastCommitMessage: nil,
            lastCommitBranch: nil,
            lastCommitLanguages: nil,
            lastCommitTimestamp: nil,
            totalCommitsEaten: totalXP,
            streakDays: 0,
            weather: "clear",
            hasCompanion: false,
            companionType: nil,
            placedObjects: [],
            isClaudeSessionActive: sm.isSessionActive,
            sessionDurationMinutes: 0,
            recentToolUseCount: 0,
            lastTouchTimestamp: nil,
            lastMCPTimestamp: nil
        )
    }
}
