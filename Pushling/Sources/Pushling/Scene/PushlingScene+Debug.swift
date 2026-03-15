// PushlingScene+Debug.swift — Debug action methods for the PushlingScene
// Called from DebugActions via the menu bar Debug submenu.
// Provides commit feeding, stage changes, evolution, speech,
// weather, cat behaviors, and stats logging.

import SpriteKit

// MARK: - PushlingScene Debug Actions

extension PushlingScene {

    // MARK: - Feed Commits

    /// Simulate feeding a commit to the creature.
    /// Creates the eating animation with proper text rendering.
    func debugFeedCommit(commit: CommitData, type: CommitType) {
        guard let creature = creatureNode else { return }

        let xpResult = XPCalculator.calculate(
            commit: commit,
            streakDays: 3,
            lastCommitTime: Date().addingTimeInterval(-3600),
            rateLimitFactor: 1.0
        )

        // If already eating, just award XP and log
        if debugEatingAnimation.isEating {
            debugXP += xpResult.xp
            if debugXP >= debugXPToNext {
                debugXP -= debugXPToNext
            }
            onXPChanged(
                currentXP: debugXP,
                xpToNext: debugXPToNext,
                stage: creature.currentStage
            )
            NSLog("[Pushling/Debug] Queued commit XP: +%d (eating in progress)",
                  xpResult.xp)
            return
        }

        // Ensure the animation is configured
        debugEatingAnimation.configure(creature: creature, scene: self)

        // Wire up completion
        debugEatingAnimation.onComplete = { [weak self] commitType, result in
            guard let self = self else { return }
            self.debugXP += result?.xp ?? 1
            if self.debugXP >= self.debugXPToNext {
                self.debugXP -= self.debugXPToNext
            }
            self.onXPChanged(
                currentXP: self.debugXP,
                xpToNext: self.debugXPToNext,
                stage: self.creatureNode?.currentStage ?? .critter
            )
            NSLog("[Pushling/Debug] Commit eaten: %@ +%dXP (total: %d/%d)",
                  commitType.rawValue, result?.xp ?? 0,
                  self.debugXP, self.debugXPToNext)
        }

        debugEatingAnimation.start(
            commit: commit,
            commitType: type,
            xpResult: xpResult
        )

        NSLog("[Pushling/Debug] Feeding commit: '%@' type=%@",
              String(commit.message.prefix(30)), type.rawValue)
    }

    // MARK: - Stage Changes

    /// Immediately set the creature to a specific growth stage.
    /// No ceremony — just reconfigure.
    func debugSetStage(_ stage: GrowthStage) {
        guard let creature = creatureNode else { return }

        creature.configureForStage(stage)
        behaviorStack?.updateStage(stage)
        onCreatureStageChanged(stage)

        // Re-configure speech coordinator for new stage
        debugSpeechCoordinator.onStageChanged(stage)

        NSLog("[Pushling/Debug] Stage set to: %@", "\(stage)")
    }

    // MARK: - Evolution

    /// Trigger the evolution ceremony to the next stage.
    func debugEvolve() {
        guard let creature = creatureNode else { return }

        let current = creature.currentStage
        guard current != .apex else {
            NSLog("[Pushling/Debug] Already at Apex — cannot evolve further")
            return
        }

        guard let next = GrowthStage(rawValue: current.rawValue + 1) else {
            return
        }

        onCreatureStageChanged(next)

        creature.evolve(to: next) { [weak self] in
            self?.behaviorStack?.updateStage(next)
            self?.onEvolutionCeremonyComplete()
            self?.debugSpeechCoordinator.onStageChanged(next)
            NSLog("[Pushling/Debug] Evolution complete: %@ -> %@",
                  "\(current)", "\(next)")
        }
    }

    // MARK: - Speech

    /// Trigger a speech bubble with the given text and style.
    func debugSpeak(text: String, style: SpeechStyle) {
        guard let creature = creatureNode else { return }

        // Ensure coordinator is configured for current stage
        debugSpeechCoordinator.configure(
            creature: creature,
            stage: creature.currentStage,
            personality: .neutral,
            creatureName: "Pushling",
            speechCache: nil,
            narrationOverlay: nil
        )

        let request = SpeechRequest(
            text: text,
            style: style,
            source: .ai
        )
        let response = debugSpeechCoordinator.speak(request)

        if response.ok {
            NSLog("[Pushling/Debug] Speech: '%@' (filtered: %@)",
                  response.spoken, response.filtered ? "yes" : "no")
        } else {
            NSLog("[Pushling/Debug] Speech failed: %@",
                  response.errorMessage ?? "unknown")
        }
    }

    /// Trigger the first word ceremony.
    func debugFirstWord() {
        guard let creature = creatureNode else { return }

        // Force the creature to critter if not already
        if creature.currentStage < .critter {
            debugSetStage(.critter)
        }

        let ceremony = FirstWordCeremony()
        ceremony.begin(creature: creature, name: "Pushling") {
            NSLog("[Pushling/Debug] First word ceremony complete")
        }

        NSLog("[Pushling/Debug] First word ceremony triggered")
    }

    // MARK: - Weather

    /// Force a specific weather state.
    func debugSetWeather(_ state: WeatherState) {
        worldManager.debugForceWeather(state)
        NSLog("[Pushling/Debug] Weather set to: %@", state.rawValue)
    }

    // MARK: - Cat Behaviors

    /// Trigger a random cat behavior on the creature.
    func debugTriggerCatBehavior() {
        guard let creature = creatureNode else { return }

        let available = CatBehaviors.available(at: creature.currentStage)
        guard let behavior = available.randomElement() else {
            NSLog("[Pushling/Debug] No cat behaviors available at stage %@",
                  "\(creature.currentStage)")
            return
        }

        let duration = behavior.perform(creature)
        NSLog("[Pushling/Debug] Cat behavior: '%@' (%.1fs)",
              behavior.name, duration)
    }

    // MARK: - Stats

    /// Log creature stats to Console.
    func debugLogStats() {
        guard let creature = creatureNode else {
            NSLog("[Pushling/Debug] No creature node")
            return
        }

        let stage = creature.currentStage
        let facing = creature.facing
        let nodeCount = creature.countNodes()
        let totalNodes = debugCountAllNodes(in: self)
        let stats = frameBudgetMonitor.currentStats

        NSLog("[Pushling/Debug] === CREATURE STATS ===")
        NSLog("[Pushling/Debug]   Stage: %@", "\(stage)")
        NSLog("[Pushling/Debug]   Facing: %@", facing.rawValue)
        NSLog("[Pushling/Debug]   Position: (%.1f, %.1f)",
              creature.position.x, creature.position.y)
        NSLog("[Pushling/Debug]   XP: %d/%d", debugXP, debugXPToNext)
        NSLog("[Pushling/Debug]   Sleeping: %@",
              creature.isSleeping ? "yes" : "no")
        NSLog("[Pushling/Debug]   Evolving: %@",
              creature.isEvolving ? "yes" : "no")
        NSLog("[Pushling/Debug]   Creature nodes: %d", nodeCount)
        NSLog("[Pushling/Debug]   Total scene nodes: %d", totalNodes)
        NSLog("[Pushling/Debug]   FPS: %.0f | Frame: %.1fms",
              stats.fps, stats.averageFrameTimeMs)
        NSLog("[Pushling/Debug]   Behavior stack: %@",
              behaviorStack != nil ? "active" : "nil")
        NSLog("[Pushling/Debug] === END STATS ===")
    }

    /// Recursively counts all nodes (accessible from extension).
    func debugCountAllNodes(in node: SKNode) -> Int {
        return 1 + node.children.reduce(0) {
            $0 + debugCountAllNodes(in: $1)
        }
    }
}
