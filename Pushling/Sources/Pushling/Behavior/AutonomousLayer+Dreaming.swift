// AutonomousLayer+Dreaming.swift — Dream state integration
// Handles the .dreaming case in AutonomousLayer's state machine.
// Checks dream gates from within resting state, drives DreamEngine
// each frame, translates DreamOutput into LayerOutput.

import Foundation
import CoreGraphics

extension AutonomousLayer {

    // MARK: - Dreaming State Update

    /// Per-frame update when in .dreaming state.
    /// Drives DreamEngine and translates its output into LayerOutput.
    /// Transitions back to .idle when the dream cycle completes.
    func updateDreaming(deltaTime: TimeInterval, output: inout LayerOutput) {
        guard let engine = dreamEngine else {
            transitionTo(.idle)
            return
        }

        // Load full personality from DB (including specialty) for drift computation.
        // We can't use the PersonalitySnapshot here because it lacks specialty,
        // and dreams must preserve the real specialty when saving drifted values.
        let currentPersonality: Personality
        if let db = dreamDB {
            currentPersonality = PersonalityPersistence.load(from: db)
        } else {
            currentPersonality = Personality(
                energy: personality.energy,
                verbosity: personality.verbosity,
                focus: personality.focus,
                discipline: personality.discipline,
                specialty: .polyglot
            )
        }

        guard let dreamOutput = engine.update(deltaTime: deltaTime,
                                               currentPersonality: currentPersonality) else {
            // Dream complete — persist then return to idle
            NSLog("[Pushling/Autonomous] Dream cycle complete")
            // Refresh personality snapshot from DB on next tick
            // (GameCoordinator will pick it up on next personality load)
            transitionTo(.idle)
            return
        }

        applyDreamOutput(dreamOutput, to: &output)
    }

    // MARK: - Dream Gate Check (called from resting state)

    /// Evaluates all 4 dream gates. Returns true if the creature should
    /// enter a dream cycle. Only called in resting state.
    ///
    /// - Parameters:
    ///   - deltaTime: Current frame delta (passed to journal count cache).
    ///   - timePeriod: Current sky time period from WorldManager.
    func shouldBeginDream(deltaTime: TimeInterval,
                          timePeriod: TimePeriod) -> Bool {
        guard let engine = dreamEngine else { return false }

        let lastDreamAt = loadLastDreamAt()
        let journalCount = engine.refreshedJournalCount(
            lastDreamAt: lastDreamAt,
            deltaTime: deltaTime
        )

        return engine.checkGates(
            timePeriod: timePeriod,
            emotionalEnergy: emotions.energy,
            unprocessedJournalCount: journalCount,
            lastDreamAt: lastDreamAt
        )
    }

    // MARK: - Transition Into Dream

    /// Called by the resting state update to begin a dream cycle.
    func beginDreamCycle() {
        guard let engine = dreamEngine else { return }
        engine.startDream()
        transitionTo(.dreaming)
        NSLog("[Pushling/Autonomous] Entering dream state (energy=%.1f)",
              emotions.energy)
    }

    // MARK: - Output Translation

    private func applyDreamOutput(_ dream: DreamOutput,
                                   to output: inout LayerOutput) {
        output.eyeLeftState = dream.eyeState
        output.eyeRightState = dream.eyeState
        output.tailState = dream.tailState
        output.bodyState = dream.bodyState
        output.walkSpeed = 0

        if stage >= .critter {
            output.earLeftState = dream.earState
            output.earRightState = dream.earState
        }

        output.pawStates = [
            "fl": dream.pawState,
            "fr": dream.pawState,
            "bl": dream.pawState,
            "br": dream.pawState
        ]

        if stage >= .beast, dream.whiskerTwitch {
            output.whiskerState = "twitch"
        } else if stage >= .beast {
            output.whiskerState = "neutral"
        }
    }

    // MARK: - DB Helpers

    /// Loads the ISO8601 last_dream_at string from the creature table.
    /// Returns nil if the creature has never dreamed or DB is unavailable.
    func loadLastDreamAt() -> String? {
        guard let db = dreamDB else { return nil }
        let rows = (try? db.query(
            "SELECT last_dream_at FROM creature WHERE id = 1"
        )) ?? []
        return rows.first?["last_dream_at"] as? String
    }
}
