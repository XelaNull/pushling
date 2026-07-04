// GameCoordinator+DreamEngine.swift — DreamEngine wiring
// Sets up the DreamEngine on the AutonomousLayer and feeds
// the current TimePeriod into the layer each frame.

import Foundation

extension GameCoordinator {

    // MARK: - Wiring

    /// Creates a DreamEngine, injects the DB reference, and attaches it to
    /// the AutonomousLayer. Must be called after the behavior stack is set up.
    func wireDreamEngine() {
        guard let autonomous = scene.behaviorStack?.autonomous else {
            NSLog("[Pushling/Coordinator] wireDreamEngine: no autonomous layer yet — skipping")
            return
        }

        let engine = DreamEngine()
        // Withhold the DB reference in workbench mode — DreamEngine.
        // persistDreamResult (journal insert + personality-drift save) and
        // AutonomousLayer's dreamDB-gated persistence both guard on
        // `guard let db = db else { return }`, so leaving these nil
        // cleanly no-ops dream persistence with no edits inside Behavior/.
        if persistenceEnabled {
            engine.db = stateCoordinator.database
            autonomous.dreamDB = stateCoordinator.database
        }
        autonomous.dreamEngine = engine

        // Prime the initial time period so dreams don't trigger mid-day on launch
        autonomous.currentTimePeriod = scene.worldManager.currentTimePeriod

        NSLog("[Pushling/Coordinator] DreamEngine wired — "
              + "initial period: %@",
              scene.worldManager.currentTimePeriod.rawValue)
    }

    // MARK: - Per-Frame Dream Wiring

    /// Call from GameCoordinator.update() to keep the AutonomousLayer's
    /// TimePeriod synchronized with the WorldManager's sky system.
    func updateDreamTimePeriod() {
        guard let autonomous = scene.behaviorStack?.autonomous else { return }
        autonomous.currentTimePeriod = scene.worldManager.currentTimePeriod
    }
}
