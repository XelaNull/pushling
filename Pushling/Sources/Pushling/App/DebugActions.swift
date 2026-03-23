// DebugActions.swift — Debug menu action handler
// Provides all debug/testing actions for the menu bar Debug submenu.
// Communicates with PushlingScene and GameCoordinator to trigger
// animations, stage changes, speech, weather, expressions, surprises,
// games, touch input, sessions, mutations, teach, nurture, and more.

import AppKit
import SpriteKit
import QuartzCore

// MARK: - Debug Actions

/// Handles all debug menu actions. Holds weak references to the scene
/// and game coordinator, delegating visual work to PushlingScene's
/// debug methods and subsystem work through GameCoordinator.
final class DebugActions {

    // MARK: - Dependencies

    private weak var scene: PushlingScene?
    private weak var coordinator: GameCoordinator?

    // MARK: - Init

    init(scene: PushlingScene?, gameCoordinator: GameCoordinator? = nil) {
        self.scene = scene
        self.coordinator = gameCoordinator
    }

    /// Update the scene reference (e.g., after Touch Bar re-creation).
    func updateScene(_ scene: PushlingScene?) {
        self.scene = scene
    }

    /// Update the game coordinator reference.
    func updateGameCoordinator(_ coordinator: GameCoordinator?) {
        self.coordinator = coordinator
    }

    // MARK: - Feed Commits

    func feedSmallCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Fix typo in README",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 1, linesAdded: 5, linesRemoved: 5,
            languages: ["md"],
            isMerge: false, isRevert: false, isForcePush: false,
            tags: [], branch: "main", timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .normal)
    }

    func feedLargeCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Refactor entire authentication module for OAuth2",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 12, linesAdded: 150, linesRemoved: 80,
            languages: ["swift", "swift", "swift"],
            isMerge: false, isRevert: false, isForcePush: false,
            tags: [], branch: "feature/auth", timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .largeRefactor)
    }

    func feedTestCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Add unit tests for XP calculator edge cases",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 3, linesAdded: 45, linesRemoved: 10,
            languages: ["swift", "test"],
            isMerge: false, isRevert: false, isForcePush: false,
            tags: [], branch: "main", timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .test)
    }

    func feedBatchCommits(count: Int) {
        guard let scene = scene else { logNoScene(); return }
        NSLog("[Pushling/Debug] Feeding %d commits...", count)
        for i in 0..<count {
            let delay = Double(i) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                [weak scene] in
                guard let scene = scene else { return }
                let commit = CommitData(
                    message: "Batch commit \(i + 1) of \(count)",
                    sha: String(UUID().uuidString.prefix(7)),
                    repoName: "pushling",
                    filesChanged: Int.random(in: 1...5),
                    linesAdded: Int.random(in: 5...50),
                    linesRemoved: Int.random(in: 0...20),
                    languages: ["swift"],
                    isMerge: false, isRevert: false, isForcePush: false,
                    tags: [], branch: "main", timestamp: Date()
                )
                scene.debugFeedCommit(commit: commit, type: .normal)
            }
        }
    }

    // MARK: - Stage Changes

    func setStage(_ stage: GrowthStage) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSetStage(stage)
    }

    // MARK: - Evolution

    func evolveNow() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugEvolve()
    }

    // MARK: - Expressions

    func express(_ expression: String) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugExpress(expression)
    }

    // MARK: - Speech

    func sayHello() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSpeak(text: "hello!", style: .say)
    }

    func sayLongMessage() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSpeak(
            text: "I have been watching you code all day and I think "
                + "this refactor is going to be really good",
            style: .say
        )
    }

    func testFirstWord() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugFirstWord()
    }

    // MARK: - Weather

    func setWeather(_ state: WeatherState) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSetWeather(state)
    }

    // MARK: - Surprises

    func triggerSurprise(id: Int?) {
        guard let coord = coordinator else { logNoCoordinator(); return }
        guard let scene = scene else { logNoScene(); return }
        scene.debugTriggerSurprise(
            id: id,
            scheduler: coord.surpriseScheduler,
            player: coord.surprisePlayer,
            context: coord.debugBuildSurpriseContext()
        )
    }

    // MARK: - Touch / Input

    func simulateTap() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSimulateTap()
    }

    func simulateDoubleTap() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSimulateDoubleTap()
    }

    func simulatePetting() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSimulatePetting()
    }

    func toggleLaserPointer() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugToggleLaser()
    }

    func showMilestoneProgress() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let handler = coord.creatureTouchHandler
        let tracker = handler.milestoneTracker
        NSLog("[Pushling/Debug] === TOUCH MILESTONE PROGRESS ===")
        for milestone in MilestoneID.allCases {
            let unlocked = tracker.isUnlocked(milestone)
            let threshold = milestone.touchThreshold
            let status = unlocked ? "EARNED" : "locked"
            if let t = threshold {
                NSLog("[Pushling/Debug]   %@: %@ (threshold: %d, "
                      + "current: %d)",
                      milestone.rawValue, status, t,
                      tracker.stats.totalTouches)
            } else {
                NSLog("[Pushling/Debug]   %@: %@ (special condition)",
                      milestone.rawValue, status)
            }
        }
        NSLog("[Pushling/Debug]   Total touches: %d",
              tracker.stats.totalTouches)
        NSLog("[Pushling/Debug] === END MILESTONES ===")
    }

    // MARK: - Mini-Games

    func startGame(_ type: MiniGameType) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugStartGame(type)
    }

    // MARK: - World Objects

    func placeObject(_ objectName: String) {
        guard let scene = scene else { logNoScene(); return }
        let wm = scene.worldManager
        let result = wm.createObject(params: [
            "name": objectName,
            "base_shape": objectName,
            "position_x": Double(wm.cameraWorldX),
            "source": "debug"
        ])
        if let info = result?.info {
            NSLog("[Pushling/Debug] Placed object '%@' at x=%.0f",
                  info.name, info.positionX)
        } else {
            NSLog("[Pushling/Debug] Failed to place object '%@'",
                  objectName)
        }
    }

    func removeAllObjects() {
        guard let scene = scene else { logNoScene(); return }
        let wm = scene.worldManager
        let objects = wm.objectRenderer.activeObjects
        var removed = 0
        for obj in objects {
            let _ = wm.objectRenderer.removeObject(id: obj.definition.id)
            removed += 1
        }
        NSLog("[Pushling/Debug] Removed %d objects", removed)
    }

    // MARK: - Companions

    func addCompanion(_ type: String) {
        guard let scene = scene else { logNoScene(); return }
        let wm = scene.worldManager
        if let info = wm.addCompanion(typeStr: type) {
            NSLog("[Pushling/Debug] Added companion: %@ (%@)",
                  info["name"] as? String ?? "?",
                  info["type"] as? String ?? "?")
        } else {
            NSLog("[Pushling/Debug] Failed to add companion '%@' "
                  + "(invalid type?)", type)
        }
    }

    func removeCompanion() {
        guard let scene = scene else { logNoScene(); return }
        let wm = scene.worldManager
        if wm.removeCompanion() {
            NSLog("[Pushling/Debug] Removed companion")
        } else {
            NSLog("[Pushling/Debug] No companion to remove")
        }
    }

    // MARK: - Mutations

    func checkAllBadges() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let mutation = coord.mutationSystem
        NSLog("[Pushling/Debug] === MUTATION BADGE STATUS ===")
        for badge in MutationBadge.allCases {
            let earned = mutation.earnedBadges.contains(badge)
            let dateStr: String
            if let date = mutation.earnedAt[badge] {
                let fmt = DateFormatter()
                fmt.dateStyle = .short
                fmt.timeStyle = .short
                dateStr = fmt.string(from: date)
            } else {
                dateStr = "—"
            }
            NSLog("[Pushling/Debug]   %@: %@ | %@ | %@",
                  badge.rawValue,
                  earned ? "EARNED" : "locked",
                  badge.visualEffect,
                  dateStr)
        }
        NSLog("[Pushling/Debug]   Total earned: %d/%d",
              mutation.earnedBadges.count,
              MutationBadge.allCases.count)
        NSLog("[Pushling/Debug] === END BADGES ===")
    }

    func grantBadge(_ badge: MutationBadge) {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let mutation = coord.mutationSystem
        if mutation.earnedBadges.contains(badge) {
            NSLog("[Pushling/Debug] Badge '%@' already earned",
                  badge.displayName)
            return
        }
        mutation.debugGrantBadge(badge)
        NSLog("[Pushling/Debug] Granted badge: %@ — %@",
              badge.displayName, badge.visualEffect)
    }

    // MARK: - Teach

    func teachRollOver() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let engine = coord.taughtBehaviorEngine

        // Build a simple "roll over" choreography definition
        let rollOver = ChoreographyDefinition(
            name: "roll_over",
            category: "trick",
            stageMin: .critter,
            durationSeconds: 2.0,
            tracks: [
                "body": [
                    Keyframe(time: 0.0, state: "crouch",
                             easing: .easeInOut, params: [:]),
                    Keyframe(time: 0.5, state: "roll_left",
                             easing: .easeInOut, params: [:]),
                    Keyframe(time: 1.0, state: "roll_right",
                             easing: .easeInOut, params: [:]),
                    Keyframe(time: 1.5, state: "stand",
                             easing: .easeOut, params: [:]),
                ],
                "tail": [
                    Keyframe(time: 0.0, state: "low",
                             easing: .linear, params: [:]),
                    Keyframe(time: 1.5, state: "wag",
                             easing: .easeOut, params: [:]),
                ],
            ],
            triggers: TriggerConfig(
                idleWeight: 1.0,
                onTouch: false,
                onCommitTypes: [],
                emotionalConditions: [],
                timeConditions: nil,
                cooldownSeconds: 30,
                contexts: ["idle", "command"]
            )
        )

        engine.begin(
            definition: rollOver,
            mastery: .learning,
            personality: coord.personality.toSnapshot(),
            currentTime: CACurrentMediaTime()
        )
        NSLog("[Pushling/Debug] Taught and started 'roll_over' trick")
    }

    func listTaughtTricks() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let engine = coord.taughtBehaviorEngine
        NSLog("[Pushling/Debug] === TAUGHT TRICKS ===")
        if let exec = engine.currentExecution {
            NSLog("[Pushling/Debug]   Currently playing: %@ (%.1f%%)",
                  exec.definition.name, exec.progress * 100)
        } else {
            NSLog("[Pushling/Debug]   No trick currently playing")
        }
        // The mastery tracker holds the learned trick catalog
        let mastery = coord.masteryTracker
        let catalog = mastery.allTrackedTricks()
        if catalog.isEmpty {
            NSLog("[Pushling/Debug]   No tricks learned yet")
        } else {
            for (name, level) in catalog {
                NSLog("[Pushling/Debug]   %@: %@", name, "\(level)")
            }
        }
        NSLog("[Pushling/Debug] === END TRICKS ===")
    }

    // MARK: - Nurture

    func addHabit(_ habit: String) {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let definition = HabitDefinition(
            id: UUID().uuidString, name: habit,
            trigger: .afterEvent(event: "commit"),
            behavior: "stand", behaviorVariant: nil,
            frequency: .sometimes, variation: .moderate,
            energyCost: 0.1, stageMin: .critter,
            priority: 5, strength: 0.7,
            reinforcementCount: 0,
            personalityConflict: false, lastFiredAt: nil,
            cooldownSeconds: 60.0
        )
        if coord.habitEngine.addHabit(definition) {
            NSLog("[Pushling/Debug] Added habit '%@' (total: %d)",
                  habit, coord.habitEngine.habits.count)
        } else {
            NSLog("[Pushling/Debug] Failed to add habit '%@' (at cap?)",
                  habit)
        }
    }

    func addPreference(_ preference: String) {
        guard let coord = coordinator else { logNoCoordinator(); return }
        coord.preferenceEngine.setPreference(
            id: UUID().uuidString, subject: preference,
            valence: 0.5, strength: 0.7
        )
        NSLog("[Pushling/Debug] Added preference '%@' (total: %d)",
              preference,
              coord.preferenceEngine.allPreferences.count)
    }

    func listActiveHabits() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        NSLog("[Pushling/Debug] === ACTIVE HABITS ===")
        let habits = coord.habitEngine.habits
        if habits.isEmpty {
            NSLog("[Pushling/Debug]   No habits registered")
        } else {
            for h in habits {
                NSLog("[Pushling/Debug]   %@ -> %@ (str: %.2f, freq: %@)",
                      h.name, h.behavior, h.strength,
                      h.frequency.rawValue)
            }
        }
        let prefs = coord.preferenceEngine.allPreferences
        if !prefs.isEmpty {
            NSLog("[Pushling/Debug] -- Preferences --")
            for p in prefs {
                NSLog("[Pushling/Debug]   %@: valence=%.2f strength=%.2f",
                      p.subject, p.valence, p.strength)
            }
        }
        let quirks = coord.quirkEngine.quirks
        if !quirks.isEmpty {
            NSLog("[Pushling/Debug] -- Quirks --")
            for q in quirks {
                NSLog("[Pushling/Debug]   %@ (str: %.2f)",
                      q.name, q.strength)
            }
        }
        NSLog("[Pushling/Debug] === END HABITS ===")
    }

    // MARK: - Session

    func simulateClaudeConnect() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let sm = coord.commandRouter.sessionManager
        let result = sm.startSession()
        NSLog("[Pushling/Debug] Claude session connect: %@",
              result.ok ? "connected" : "failed")
    }

    func simulateClaudeDisconnect() {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let sm = coord.commandRouter.sessionManager
        if let sessionId = sm.activeSessionId {
            sm.endSession(sessionId: sessionId, reason: .clean)
            NSLog("[Pushling/Debug] Claude session disconnected: %@",
                  sessionId)
        } else {
            NSLog("[Pushling/Debug] No active session to disconnect")
        }
    }

    func showDiamondIndicator() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugShowDiamond()
    }

    // MARK: - Interactions

    func testCatBehavior() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugTriggerCatBehavior()
    }

    // MARK: - Time

    func skipTime(hours: Int) {
        guard let coord = coordinator else { logNoCoordinator(); return }
        let seconds = TimeInterval(hours * 3600)
        coord.emotionalState.debugAdvanceTime(seconds)
        coord.circadianCycle.debugAdvanceTime(seconds)
        NSLog("[Pushling/Debug] Skipped %d hour(s) — emotional state "
              + "and circadian cycle advanced", hours)
    }

    func skipToMorning() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let hoursToMorning: Int
        if hour < 7 {
            hoursToMorning = 7 - hour
        } else {
            hoursToMorning = (24 - hour) + 7
        }
        skipTime(hours: hoursToMorning)
        NSLog("[Pushling/Debug] Skipped to morning (7 AM)")
    }

    func skipToNight() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let hoursToNight: Int
        if hour < 22 {
            hoursToNight = 22 - hour
        } else {
            hoursToNight = (24 - hour) + 22
        }
        skipTime(hours: hoursToNight)
        NSLog("[Pushling/Debug] Skipped to night (10 PM)")
    }

    // MARK: - Camera

    func zoomIn() {
        guard let scene = scene else { logNoScene(); return }
        let cam = scene.cameraController
        cam.zoom(delta: 0.25, centerWorldX: cam.effectiveWorldX)
        NSLog("[Pushling/Debug] Zoom in -> %.2fx", cam.zoomLevel)
    }

    func zoomOut() {
        guard let scene = scene else { logNoScene(); return }
        let cam = scene.cameraController
        cam.zoom(delta: -0.25, centerWorldX: cam.effectiveWorldX)
        NSLog("[Pushling/Debug] Zoom out -> %.2fx", cam.zoomLevel)
    }

    func zoomReset() {
        guard let scene = scene else { logNoScene(); return }
        scene.cameraController.recenter()
        NSLog("[Pushling/Debug] Camera reset (zoom, pan, Y)")
    }

    func showCameraState() {
        guard let scene = scene else { logNoScene(); return }
        let cam = scene.cameraController
        NSLog("[Pushling/Debug] === CAMERA STATE ===")
        NSLog("[Pushling/Debug]   Zoom: %.2fx (range 0.5-3.0)", cam.zoomLevel)
        NSLog("[Pushling/Debug]   Pan offset: %.1fpt", cam.panOffset)
        NSLog("[Pushling/Debug]   Camera Y: %.1fpt", cam.cameraWorldY)
        NSLog("[Pushling/Debug]   Base world X: %.1f", cam.baseWorldX)
        NSLog("[Pushling/Debug]   Effective X: %.1f", cam.effectiveWorldX)
        NSLog("[Pushling/Debug]   Lock mode: %@",
              cam.lockMode == .unlocked ? "free" : "locked")
        NSLog("[Pushling/Debug]   Has active pan: %@",
              cam.hasActivePan ? "yes" : "no")
        NSLog("[Pushling/Debug]   Has active zoom: %@",
              cam.hasActiveZoom ? "yes" : "no")
        NSLog("[Pushling/Debug] === END CAMERA ===")
    }

    // MARK: - Info

    func showStats() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugLogStats()
    }

    func showFullStats() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugLogFullStats(coordinator: coordinator)
    }

    func showWorldState() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugLogWorldState()
    }

    func showBehaviorStackState() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugLogBehaviorStack()
    }

    func exportCreatureJSON() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugExportCreatureJSON(coordinator: coordinator)
    }

    // MARK: - Private

    private func logNoScene() {
        NSLog("[Pushling/Debug] No scene available — "
              + "Touch Bar may not be active")
    }

    private func logNoCoordinator() {
        NSLog("[Pushling/Debug] No GameCoordinator available — "
              + "subsystems not initialized")
    }
}
