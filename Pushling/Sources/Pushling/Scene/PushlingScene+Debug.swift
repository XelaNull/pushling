// PushlingScene+Debug.swift — Debug action methods for the PushlingScene
// Called from DebugActions via the menu bar Debug submenu.
// Provides commit feeding, stage changes, evolution, expressions,
// speech, weather, surprises, touch simulation, games, sessions,
// behavior stack inspection, and comprehensive stats logging.

import SpriteKit
import QuartzCore

// MARK: - PushlingScene Debug Actions

extension PushlingScene {

    // MARK: - Feed Commits

    /// Simulate feeding a commit to the creature.
    func debugFeedCommit(commit: CommitData, type: CommitType) {
        guard let creature = creatureNode else { return }

        let xpResult = XPCalculator.calculate(
            commit: commit,
            streakDays: 3,
            lastCommitTime: Date().addingTimeInterval(-3600),
            rateLimitFactor: 1.0
        )

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
            NSLog("[Pushling/Debug] Queued commit XP: +%d (eating)",
                  xpResult.xp)
            return
        }

        debugEatingAnimation.configure(creature: creature, scene: self)
        debugEatingAnimation.onComplete = {
            [weak self] commitType, result in
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
            NSLog("[Pushling/Debug] Commit eaten: %@ +%dXP (%d/%d)",
                  commitType.rawValue, result?.xp ?? 0,
                  self.debugXP, self.debugXPToNext)
        }

        debugEatingAnimation.start(
            commit: commit, commitType: type, xpResult: xpResult
        )
        NSLog("[Pushling/Debug] Feeding: '%@' type=%@",
              String(commit.message.prefix(30)), type.rawValue)
    }

    // MARK: - Stage Changes

    func debugSetStage(_ stage: GrowthStage) {
        guard let creature = creatureNode else { return }
        creature.configureForStage(stage)
        behaviorStack?.updateStage(stage)
        onCreatureStageChanged(stage)
        debugSpeechCoordinator.onStageChanged(stage)
        NSLog("[Pushling/Debug] Stage set to: %@", "\(stage)")
    }

    // MARK: - Evolution

    func debugEvolve() {
        guard let creature = creatureNode else { return }
        let current = creature.currentStage
        guard current != .apex else {
            NSLog("[Pushling/Debug] Already at Apex")
            return
        }
        guard let next = GrowthStage(rawValue: current.rawValue + 1)
        else { return }

        onCreatureStageChanged(next)
        creature.evolve(to: next) { [weak self] in
            self?.behaviorStack?.updateStage(next)
            self?.onEvolutionCeremonyComplete()
            self?.debugSpeechCoordinator.onStageChanged(next)
            NSLog("[Pushling/Debug] Evolution: %@ -> %@",
                  "\(current)", "\(next)")
        }
    }

    // MARK: - Expressions

    /// Apply a named expression via the AI-directed behavior layer.
    func debugExpress(_ expression: String) {
        guard creatureNode != nil else { return }

        let output = ExpressionMapping.layerOutput(
            for: expression, intensity: 0.8
        )
        if output.isEmpty {
            NSLog("[Pushling/Debug] Unknown expression: '%@'",
                  expression)
            return
        }

        // Inject into the AI-directed layer if available
        if let aiLayer = behaviorStack?.aiDirected {
            aiLayer.debugSetExpression(output, duration: 3.0)
            NSLog("[Pushling/Debug] Expression: '%@' — %@",
                  expression,
                  ExpressionMapping.description(for: expression))
        } else {
            NSLog("[Pushling/Debug] Expression '%@' — no AI layer "
                  + "available, logging only: %@",
                  expression,
                  ExpressionMapping.description(for: expression))
        }
    }

    // MARK: - Speech

    func debugSpeak(text: String, style: SpeechStyle) {
        guard let creature = creatureNode else { return }

        let coordinator = debugSpeechCoordinator
        // Only reconfigure if using fallback (production is already wired)
        if gameCoordinator == nil {
            coordinator.configure(
                creature: creature,
                stage: creature.currentStage,
                personality: .neutral,
                creatureName: "Pushling",
                speechCache: nil,
                narrationOverlay: nil
            )
        }

        let request = SpeechRequest(
            text: text, style: style, source: .ai
        )
        let response = coordinator.speak(request)

        if response.ok {
            NSLog("[Pushling/Debug] Speech: '%@' (filtered: %@)",
                  response.spoken,
                  response.filtered ? "yes" : "no")
        } else {
            NSLog("[Pushling/Debug] Speech failed: %@",
                  response.errorMessage ?? "unknown")
        }
    }

    func debugFirstWord() {
        guard let creature = creatureNode else { return }
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

    func debugSetWeather(_ state: WeatherState) {
        worldManager.debugForceWeather(state)
        NSLog("[Pushling/Debug] Weather set to: %@", state.rawValue)
    }

    // MARK: - Surprises

    /// Trigger a surprise by ID, or a random one if nil.
    func debugTriggerSurprise(
        id: Int?,
        scheduler: SurpriseScheduler,
        player: SurpriseAnimationPlayer,
        context: SurpriseContext
    ) {
        if player.isPlaying {
            NSLog("[Pushling/Debug] Surprise already playing — "
                  + "wait for it to finish")
            return
        }

        if let surpriseId = id {
            scheduler.forceFire(
                surpriseId: surpriseId,
                context: context
            )
            NSLog("[Pushling/Debug] Force-fired surprise #%d",
                  surpriseId)
        } else {
            scheduler.debugFireRandom(context: context)
            NSLog("[Pushling/Debug] Triggered random surprise")
        }
    }

    // MARK: - Touch Simulation

    /// Simulate a tap on the creature's center.
    func debugSimulateTap() {
        guard let creature = creatureNode else { return }
        let center = creature.position
        let event = GestureEvent(
            type: .tap,
            position: center,
            velocity: .zero,
            touchCount: 1,
            duration: 0.1,
            target: .creature,
            timestamp: CACurrentMediaTime()
        )
        if let recognizer = gameCoordinator?.gestureRecognizer {
            gameCoordinator?.creatureTouchHandler
                .gestureRecognizer(recognizer, didRecognize: event)
        }
        NSLog("[Pushling/Debug] Simulated tap at (%.1f, %.1f)",
              center.x, center.y)
    }

    /// Simulate a double-tap on the creature.
    func debugSimulateDoubleTap() {
        guard let creature = creatureNode else { return }
        let center = creature.position
        let event = GestureEvent(
            type: .doubleTap,
            position: center,
            velocity: .zero,
            touchCount: 1,
            duration: 0.15,
            target: .creature,
            timestamp: CACurrentMediaTime()
        )
        if let recognizer = gameCoordinator?.gestureRecognizer {
            gameCoordinator?.creatureTouchHandler
                .gestureRecognizer(recognizer, didRecognize: event)
        }
        NSLog("[Pushling/Debug] Simulated double-tap at (%.1f, %.1f)",
              center.x, center.y)
    }

    /// Simulate a petting stroke across the creature.
    func debugSimulatePetting() {
        guard let creature = creatureNode else { return }
        let y = creature.position.y
        let startX = creature.position.x - 20
        let endX = creature.position.x + 20
        let event = GestureEvent(
            type: .pettingStroke,
            position: CGPoint(x: endX, y: y),
            velocity: CGVector(dx: 80, dy: 0),
            touchCount: 1,
            duration: 0.5,
            target: .creature,
            timestamp: CACurrentMediaTime()
        )
        if let recognizer = gameCoordinator?.gestureRecognizer {
            gameCoordinator?.creatureTouchHandler
                .gestureRecognizer(recognizer, didRecognize: event)
        }
        NSLog("[Pushling/Debug] Simulated petting stroke from "
              + "%.1f to %.1f", startX, endX)
    }

    /// Toggle an auto-moving laser pointer simulation.
    func debugToggleLaser() {
        NSLog("[Pushling/Debug] Toggle laser pointer")
        NSLog("[Pushling/Debug]   (Laser pointer auto-move requires "
              + "continuous drag events — use the actual Touch Bar "
              + "or call LaserPointerMode.activate() directly)")
    }

    // MARK: - Mini-Games

    /// Start a mini-game by type.
    func debugStartGame(_ type: MiniGameType) {
        let manager = MiniGameManager()
        let started = manager.startGame(
            type, source: .humanGesture, in: self
        )
        if started {
            NSLog("[Pushling/Debug] Started mini-game: %@",
                  type.displayName)
        } else {
            NSLog("[Pushling/Debug] Failed to start mini-game: %@ "
                  + "(may not be unlocked or already active)",
                  type.displayName)
        }
    }

    // MARK: - Session

    /// Show/pulse the diamond indicator for testing.
    func debugShowDiamond() {
        guard let diamond = diamondIndicator else {
            NSLog("[Pushling/Debug] No diamond indicator node")
            return
        }
        diamond.debugFlash()
        NSLog("[Pushling/Debug] Diamond indicator flashed")
    }

    // MARK: - Cat Behaviors

    func debugTriggerCatBehavior() {
        guard let creature = creatureNode else { return }
        let available = CatBehaviors.available(at: creature.currentStage)
        guard let behavior = available.randomElement() else {
            NSLog("[Pushling/Debug] No cat behaviors at stage %@",
                  "\(creature.currentStage)")
            return
        }
        let duration = behavior.perform(creature)
        NSLog("[Pushling/Debug] Cat behavior: '%@' (%.1fs)",
              behavior.name, duration)
    }

    // MARK: - Stats: Basic

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

    // MARK: - Stats: Full / World / Behavior / Export
    // See PushlingScene+DebugStats.swift

    // MARK: - Utility

    func debugCountAllNodes(in node: SKNode) -> Int {
        return 1 + node.children.reduce(0) {
            $0 + debugCountAllNodes(in: $1)
        }
    }
}
