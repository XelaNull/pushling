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

        // Load all nurture data from SQLite
        loadPreferencesFromDB(db)
        loadHabitsFromDB(db)
        loadQuirksFromDB(db)
        loadRoutinesFromDB(db)

        // Wire decay manager callbacks
        nurtureDecayManager.onStrengthUpdate = { [weak self] name, strength in
            self?.habitEngine.updateStrength(name: name, strength: strength)
            self?.preferenceEngine.updateStrength(subject: name, strength: strength)
            self?.quirkEngine.updateStrength(name: name, strength: strength)
        }
        nurtureDecayManager.onForgotten = { [weak self] name in
            guard let self = self else { return }
            NSLog("[Pushling/Coordinator] Nurture item forgotten: %@", name)
        }

        // Run initial decay on startup (catches offline time)
        runNurtureDecayIfNeeded()

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

// MARK: - Small Wiring Methods (extracted for file size)

extension GameCoordinator {

    func wireVoice() {
        voiceSystem.initialize(stage: creatureStage,
                                personality: personality.toSnapshot())
        voiceIntegration.configure(stage: creatureStage,
                                     personality: personality.toSnapshot(),
                                     commitsEaten: totalXP)
        voiceIntegration.attach(to: speechCoordinator)

        speechCoordinator.onSpeechRendered = {
            [weak self] text, style, stage, source in
            self?.voiceIntegration.onSpeech(
                text: text, style: style, stage: stage, source: source
            )
        }

        NSLog("[Pushling/Coordinator] Voice system wired")
    }

    func wireCommandRouter() {
        NSLog("[Pushling/Coordinator] CommandRouter handlers ready for live dispatch")
    }

    func wireEatingAnimation() {
        if let creature = scene.creatureNode {
            eatingAnimation.configure(creature: creature, scene: scene)
        }
        NSLog("[Pushling/Coordinator] Eating animation wired")
    }
}

// MARK: - Nurture DB Loading

extension GameCoordinator {

    /// Load habits from the SQLite habits table.
    func loadHabitsFromDB(_ db: DatabaseManager) {
        let rows = (try? db.query(
            "SELECT name, trigger_json, action_json, frequency, "
            + "variation, strength, reinforcement_count, cooldown_s "
            + "FROM habits"
        )) ?? []

        var habits: [HabitDefinition] = []
        for row in rows {
            guard let name = row["name"] as? String,
                  let triggerJSON = row["trigger_json"] as? String,
                  let actionJSON = row["action_json"] as? String else { continue }

            let trigger = parseTriggerJSON(triggerJSON)
            let behavior = parseActionJSON(actionJSON)
            let freq = HabitFrequency(rawValue: row["frequency"] as? String ?? "sometimes")
                ?? .sometimes
            let variation = VariationLevel(rawValue: row["variation"] as? String ?? "moderate")
                ?? .moderate
            let strength = (row["strength"] as? Double) ?? 0.5
            let reinforcement = (row["reinforcement_count"] as? Int) ?? 0
            let cooldown = (row["cooldown_s"] as? Double) ?? 60.0

            habits.append(HabitDefinition(
                id: UUID().uuidString, name: name, trigger: trigger,
                behavior: behavior, behaviorVariant: nil,
                frequency: freq, variation: variation,
                energyCost: 0.1, stageMin: .spore,
                priority: 5, strength: strength,
                reinforcementCount: reinforcement,
                personalityConflict: false, lastFiredAt: nil,
                cooldownSeconds: cooldown
            ))
        }

        if !habits.isEmpty {
            habitEngine.loadHabits(habits)
        }
    }

    /// Load quirks from the SQLite quirks table.
    func loadQuirksFromDB(_ db: DatabaseManager) {
        let rows = (try? db.query(
            "SELECT name, behavior_target, modifier_json, probability, "
            + "strength, reinforcement_count FROM quirks"
        )) ?? []

        var quirks: [QuirkDefinition] = []
        for row in rows {
            guard let name = row["name"] as? String,
                  let target = row["behavior_target"] as? String,
                  let modJSON = row["modifier_json"] as? String else { continue }

            let mod = parseModifierJSON(modJSON)
            let probability = (row["probability"] as? Double) ?? 0.5
            let strength = (row["strength"] as? Double) ?? 0.5
            let reinforcement = (row["reinforcement_count"] as? Int) ?? 0

            quirks.append(QuirkDefinition(
                id: UUID().uuidString, name: name, description: nil,
                targetBehavior: target, modification: mod.type,
                action: mod.action,
                probability: probability, strength: strength,
                reinforcementCount: reinforcement, createdAt: Date()
            ))
        }

        if !quirks.isEmpty {
            quirkEngine.loadQuirks(quirks)
        }
    }

    /// Load routines from the SQLite routines table.
    func loadRoutinesFromDB(_ db: DatabaseManager) {
        let rows = (try? db.query(
            "SELECT slot, steps_json, strength, reinforcement_count "
            + "FROM routines"
        )) ?? []

        var routines: [RoutineDefinition] = []
        for row in rows {
            guard let slotStr = row["slot"] as? String,
                  let slot = RoutineSlot(rawValue: slotStr),
                  let stepsJSON = row["steps_json"] as? String else { continue }

            let steps = parseStepsJSON(stepsJSON)
            guard steps.count >= 2 else { continue }
            let strength = (row["strength"] as? Double) ?? 0.5
            let reinforcement = (row["reinforcement_count"] as? Int) ?? 0

            routines.append(RoutineDefinition(
                id: UUID().uuidString, slot: slot, steps: steps,
                strength: strength, reinforcementCount: reinforcement,
                createdAt: Date()
            ))
        }

        if !routines.isEmpty {
            routineEngine.loadRoutines(routines)
        }
    }
}

// MARK: - Nurture JSON Parsing Helpers

extension GameCoordinator {

    func parseTriggerJSON(_ json: String) -> TriggerDefinition {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .afterEvent(event: "commit")
        }
        return CommandRouter.parseTrigger(dict) ?? .afterEvent(event: "commit")
    }

    func parseActionJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "stand"
        }
        return dict["behavior"] as? String ?? "stand"
    }

    func parseModifierJSON(_ json: String)
        -> (type: QuirkModification, action: QuirkAction) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (.append, QuirkAction(track: "tail", state: "flick",
                                          durationSeconds: 0.5))
        }
        let modType = QuirkModification(rawValue: dict["type"] as? String ?? "append")
            ?? .append
        let track = dict["track"] as? String ?? "tail"
        let state = dict["state"] as? String ?? "flick"
        let duration = dict["duration_s"] as? Double ?? 0.5
        return (modType, QuirkAction(track: track, state: state,
                                      durationSeconds: duration))
    }

    func parseStepsJSON(_ json: String) -> [RoutineStep] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { dict in
            guard let typeStr = dict["type"] as? String,
                  let stepType = RoutineStep.RoutineStepType(rawValue: typeStr) else {
                return nil
            }
            return RoutineStep(
                type: stepType,
                behavior: dict["behavior"] as? String,
                variant: dict["variant"] as? String,
                expression: dict["expression"] as? String,
                text: dict["text"] as? String,
                movementAction: dict["movement"] as? String,
                durationSeconds: dict["duration_s"] as? Double ?? 2.0
            )
        }
    }
}

// MARK: - Nurture Runtime Helpers

extension GameCoordinator {

    /// Per-frame nurture subsystem updates: habit triggers, decay, routines.
    func updateNurtureSubsystems(deltaTime: TimeInterval) {
        // Habit periodic trigger tick (every 30s)
        habitPeriodicAccumulator += deltaTime
        if habitPeriodicAccumulator >= Self.habitPeriodicInterval {
            habitPeriodicAccumulator = 0
            let sceneTime = CACurrentMediaTime()
            habitEngine.evaluate(event: .periodicTick,
                                 stage: creatureStage,
                                 currentTime: sceneTime)
            let cal = Calendar.current
            let now = Date()
            habitEngine.evaluate(
                event: .timeTick(hour: cal.component(.hour, from: now),
                                 minute: cal.component(.minute, from: now)),
                stage: creatureStage,
                currentTime: sceneTime
            )
        }

        // Execute queued habits
        if habitEngine.hasQueuedHabits {
            if let habit = habitEngine.nextHabitToExecute(
                currentTime: CACurrentMediaTime()
            ) {
                executeHabitBehavior(habit)
            }
        }

        // Nurture decay check (every 60s)
        nurtureDecayAccumulator += deltaTime
        if nurtureDecayAccumulator >= Self.nurtureDecayInterval {
            nurtureDecayAccumulator = 0
            runNurtureDecayIfNeeded()
        }

        // Routine update (active routine step execution)
        if routineEngine.isExecuting {
            routineEngine.update(deltaTime: deltaTime)
        }
    }

    /// Execute a habit behavior through the behavior stack.
    func executeHabitBehavior(_ habit: HabitDefinition) {
        NSLog("[Pushling/Coordinator] Executing habit '%@' -> %@",
              habit.name, habit.behavior)

        // Inject as an AI-directed command for the behavior stack
        if let stack = scene.behaviorStack {
            var output = LayerOutput()
            output.bodyState = habit.behavior
            let command = AICommand(
                id: "habit_\(habit.id)",
                type: .perform,
                output: output,
                holdDuration: 3.0,
                enqueuedAt: CACurrentMediaTime()
            )
            stack.enqueueAICommand(command)
        }

        // Journal
        let db = stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        db.performWriteAsync({
            try db.execute(
                "INSERT INTO journal (type, summary, timestamp) VALUES (?, ?, ?)",
                arguments: ["nurture",
                            "Habit fired: '\(habit.name)' -> \(habit.behavior)",
                            now]
            )
            try db.execute(
                "UPDATE habits SET last_triggered_at = ? WHERE name = ?",
                arguments: [now, habit.name]
            )
        })
    }

    /// Runs nurture decay if enough time has elapsed.
    func runNurtureDecayIfNeeded() {
        guard nurtureDecayManager.shouldRunDecay() else { return }

        // Decay habits
        let habitResults = nurtureDecayManager.calculateDecay(
            items: habitEngine.habits
        )
        for result in habitResults {
            habitEngine.updateStrength(name: result.name,
                                        strength: result.newStrength)
        }

        // Decay preferences
        let prefResults = nurtureDecayManager.calculateDecay(
            items: preferenceEngine.allPreferences.map {
                DecayableWrapper(name: $0.subject, strength: $0.strength,
                                  reinforcementCount: $0.reinforcementCount)
            }
        )
        for result in prefResults {
            preferenceEngine.updateStrength(subject: result.name,
                                             strength: result.newStrength)
        }

        // Decay quirks
        let quirkResults = nurtureDecayManager.calculateDecay(
            items: quirkEngine.quirks
        )
        for result in quirkResults {
            quirkEngine.updateStrength(name: result.name,
                                        strength: result.newStrength)
        }

        // Persist updated strengths to SQLite
        let db = stateCoordinator.database
        db.performWriteAsync({
            for r in habitResults {
                try db.execute("UPDATE habits SET strength = ? WHERE name = ?",
                               arguments: [r.newStrength, r.name])
            }
            for r in prefResults {
                try db.execute("UPDATE preferences SET strength = ? WHERE subject = ?",
                               arguments: [r.newStrength, r.name])
            }
            for r in quirkResults {
                try db.execute("UPDATE quirks SET strength = ? WHERE name = ?",
                               arguments: [r.newStrength, r.name])
            }
        })
    }

    /// Handles session lifecycle events for nurture (habits + routines).
    func handleSessionEventForNurture(_ event: SessionEvent) {
        let sceneTime = CACurrentMediaTime()

        switch event {
        case .sessionStarted(sessionId: _):
            // Routine: greeting slot
            routineEngine.trigger(slot: .greeting)
            // Habit trigger: session start
            habitEngine.evaluate(event: .sessionEvent(event: "start"),
                                 stage: creatureStage,
                                 currentTime: sceneTime)
            // Habit trigger: wake
            habitEngine.evaluate(event: .woke,
                                 stage: creatureStage,
                                 currentTime: sceneTime)

        case .sessionEnded(sessionId: _, reason: _, duration: _):
            // Routine: farewell slot
            routineEngine.trigger(slot: .farewell)
            // Habit trigger: session end
            habitEngine.evaluate(event: .sessionEvent(event: "end"),
                                 stage: creatureStage,
                                 currentTime: sceneTime)

        case .commandReceived, .idlePhaseChanged, .subagentsStarted,
             .subagentsStopped, .sessionRejected:
            break
        }
    }
}

// MARK: - Decayable Conformance

/// Makes HabitDefinition conform to Decayable for the decay system.
extension HabitDefinition: Decayable {}

/// Makes QuirkDefinition conform to Decayable for the decay system.
extension QuirkDefinition: Decayable {}

/// Wrapper to make Preference conform to Decayable (uses subject as name).
struct DecayableWrapper: Decayable {
    let name: String
    let strength: Double
    let reinforcementCount: Int
}
