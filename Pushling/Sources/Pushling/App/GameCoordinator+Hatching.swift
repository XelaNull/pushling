// GameCoordinator+Hatching.swift — First-launch hatching ceremony wiring
// Orchestrates the 30-second birth sequence: git scan -> montage -> naming.
// Extracted from GameCoordinator.swift to stay under the 500-line limit.

import SpriteKit

// MARK: - Hatching Ceremony Wiring

extension GameCoordinator {

    /// Check hatching state and start ceremony if needed.
    /// Called from GameCoordinator.init() during the wiring phase.
    func wireHatching() {
        if !isHatched {
            startHatchingCeremony()
        } else {
            NSLog("[Pushling/Coordinator] Creature already hatched — "
                  + "stage: %@", "\(creatureStage)")
        }
    }

    /// Launches the full 30-second hatching ceremony.
    /// 1. Tells the scene to enter hatching mode (hides creature, world)
    /// 2. Creates HatchingCeremony and begins it
    /// 3. Kicks off GitHistoryScanner on a background thread
    /// 4. Feeds scan results to the ceremony as they arrive
    /// 5. On completion: saves creature to DB, configures creature node,
    ///    transitions to normal operation
    private func startHatchingCeremony() {
        NSLog("[Pushling/Coordinator] Starting hatching ceremony")

        // 1. Tell scene to enter hatching mode
        scene.enterHatchingMode()

        // 2. Get the ceremony from the scene and begin it
        guard let ceremony = scene.hatchingCeremony else {
            NSLog("[Pushling/Coordinator] ERROR: Scene failed to create "
                  + "hatching ceremony — falling back to instant hatch")
            fallbackInstantHatch()
            return
        }
        self.activeHatchingCeremony = ceremony
        ceremony.begin()

        // 3. Wire completion handler BEFORE starting scan
        ceremony.onComplete = { [weak self] name, personality, visualTraits in
            guard let self = self else { return }
            self.completeHatching(
                name: name,
                personality: personality,
                visualTraits: visualTraits
            )
        }

        // 4. Launch git scanner on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = GitHistoryScanner.scan()

            // Feed results back on the main thread (SpriteKit requirement)
            DispatchQueue.main.async {
                guard let self = self,
                      let ceremony = self.activeHatchingCeremony else {
                    return
                }

                // Don't feed if ceremony already completed
                guard !ceremony.isComplete else { return }

                if result.totalCommits > 0 {
                    ceremony.feedScanResult(result)
                } else {
                    ceremony.feedEmptyResult()
                }

                NSLog("[Pushling/Coordinator] Git scan results fed to "
                      + "ceremony — %d repos, %d commits",
                      result.repoCount, result.totalCommits)
            }
        }

        NSLog("[Pushling/Coordinator] Hatching ceremony started — "
              + "git scanner running in background")
    }
}

// MARK: - Hatching Completion

extension GameCoordinator {

    /// Called when the hatching ceremony completes. Saves creature to DB,
    /// configures the creature node, and transitions to normal operation.
    func completeHatching(name: String,
                           personality: Personality,
                           visualTraits: VisualTraits) {
        NSLog("[Pushling/Coordinator] Hatching complete — '%@' is born",
              name)

        // 1. Update in-memory state
        self.creatureName = name
        self.personality = personality
        self.creatureStage = .spore
        self.totalXP = 0
        self.isHatched = true

        // 2. Save creature to SQLite
        saveHatchedCreature(name: name, personality: personality,
                             visualTraits: visualTraits)

        // 3. Configure creature node for spore stage and position near P button
        scene.creatureNode?.configureForStage(.spore)
        scene.creatureNode?.position = CGPoint(x: 54, y: SceneConstants.groundY)

        // 4. Update behavior stack for spore stage
        if let stack = scene.behaviorStack {
            stack.personality = personality.toSnapshot()
            stack.stage = .spore
            // Start creature near the P button (left edge) where it emerged
            stack.reset(
                stage: .spore,
                position: CGPoint(x: 54, y: SceneConstants.groundY),
                facing: .right
            )
        }

        // 5. Update world for spore stage
        scene.worldManager.onStageChanged(.spore)

        // 6. Reconfigure speech coordinator with real creature data
        if let creature = scene.creatureNode {
            speechCoordinator.configure(
                creature: creature,
                stage: .spore,
                personality: personality.toSnapshot(),
                creatureName: name,
                speechCache: speechCache,
                narrationOverlay: narrationOverlay
            )
        }

        // 7. Update voice system for spore (silent tier)
        voiceSystem.initialize(stage: .spore,
                                personality: personality.toSnapshot())
        voiceIntegration.configure(stage: .spore,
                                     personality: personality.toSnapshot(),
                                     commitsEaten: 0)

        // 8. Update HUD with real data
        scene.onCreatureStageChanged(.spore)

        // 9. Tell scene to exit hatching mode
        scene.exitHatchingMode()

        // 10. Clean up ceremony reference
        self.activeHatchingCeremony = nil

        NSLog("[Pushling/Coordinator] Hatching wiring complete — "
              + "'%@' is alive at spore stage", name)
    }

    /// Persist the hatched creature to SQLite.
    private func saveHatchedCreature(name: String,
                                      personality: Personality,
                                      visualTraits: VisualTraits) {
        let db = stateCoordinator.database
        let now = ISO8601DateFormatter().string(from: Date())

        db.performWriteAsync({
            try db.execute("""
                UPDATE creature SET
                    name = ?,
                    stage = 'spore',
                    commits_eaten = 0,
                    xp = 0,
                    energy_axis = ?,
                    verbosity_axis = ?,
                    focus_axis = ?,
                    discipline_axis = ?,
                    specialty = ?,
                    base_color_hue = ?,
                    body_proportion = ?,
                    fur_pattern = ?,
                    tail_shape = ?,
                    eye_shape = ?,
                    hatched = 1,
                    created_at = ?
                WHERE id = 1
                """,
                arguments: [
                    name,
                    personality.energy,
                    personality.verbosity,
                    personality.focus,
                    personality.discipline,
                    personality.specialty.rawValue,
                    visualTraits.baseColorHue,
                    visualTraits.bodyProportion,
                    visualTraits.furPattern.rawValue,
                    visualTraits.tailShape.rawValue,
                    visualTraits.eyeShape.rawValue,
                    now
                ]
            )

            // Journal the birth
            try db.execute(
                """
                INSERT INTO journal (type, summary, timestamp)
                VALUES ('evolve', ?, ?)
                """,
                arguments: [
                    "Hatched as '\(name)' — specialty: "
                    + "\(personality.specialty.rawValue)",
                    now
                ]
            )
        }, completion: { error in
            if let error = error {
                NSLog("[Pushling/Coordinator] ERROR saving hatched "
                      + "creature: %@", "\(error)")
            } else {
                NSLog("[Pushling/Coordinator] Creature '%@' saved to DB",
                      name)
            }
        })
    }
}

// MARK: - Fallback Instant Hatch

extension GameCoordinator {

    /// Fallback if the ceremony can't be created — instantly hatch with
    /// default personality. This should never happen in normal operation.
    func fallbackInstantHatch() {
        NSLog("[Pushling/Coordinator] Fallback instant hatch")

        let name = NameGenerator.generateFromSystem()
        let personality = Personality.neutral
        let visualTraits = VisualTraits.neutral

        completeHatching(name: name,
                          personality: personality,
                          visualTraits: visualTraits)
    }
}
