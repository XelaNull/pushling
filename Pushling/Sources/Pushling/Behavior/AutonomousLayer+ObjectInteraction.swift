// AutonomousLayer+ObjectInteraction.swift — Autonomous object interaction
// During idle, the creature may autonomously approach and interact with
// placed world objects. Uses AttractionScorer (Orphan #4) to pick the
// most attractive object and ObjectInteractionEngine (Orphan #5) to
// choreograph the interaction.
//
// Flow: idle -> selectObjectInteraction() -> startObjectInteraction()
//       -> objectInteracting state -> updateObjectInteraction() per frame
//       -> completion callback -> idle

import Foundation
import CoreGraphics
import QuartzCore

// MARK: - Object Interaction Selection

extension AutonomousLayer {

    /// Minimum attraction score to override normal idle->walk/behavior flow.
    /// Below this threshold the creature isn't interested enough to approach.
    static let objectWanderThreshold: Double = 0.4

    /// Checks placed objects and selects the most attractive one, if any.
    /// Returns (objectID, interactionType, objectX) or nil.
    func selectObjectInteraction()
        -> (id: String, interaction: String, x: CGFloat)? {

        guard let query = objectQuery,
              let scorer = attractionScorer,
              let engine = objectInteractionEngine else {
            return nil
        }

        // Don't start if engine is on cooldown or already interacting
        guard !engine.isInteracting else { return nil }

        let objects = query()
        guard !objects.isEmpty else { return nil }

        // Map objects to scorer's expected format
        let scorable = objects.map {
            (id: $0.id, x: $0.x, interaction: $0.type)
        }

        let hourOfDay = Calendar.current.component(.hour, from: Date())
        let scores = scorer.scoreObjects(
            objects: scorable,
            creatureX: currentX,
            personality: personality,
            emotions: emotions,
            hourOfDay: hourOfDay
        )

        guard let chosen = scorer.selectObject(from: scores,
                                                personality: personality),
              chosen.totalScore >= Self.objectWanderThreshold else {
            return nil
        }

        // Return with the selected object's data
        guard let obj = objects.first(where: { $0.id == chosen.objectID })
        else { return nil }
        return (id: obj.id, interaction: chosen.interactionName, x: obj.x)
    }

    /// Begins an object interaction, transitioning to .objectInteracting.
    func startObjectInteraction(
        _ target: (id: String, interaction: String, x: CGFloat)
    ) {
        guard let engine = objectInteractionEngine else { return }

        let started = engine.beginInteraction(
            templateName: target.interaction,
            objectID: target.id,
            objectX: target.x,
            creatureX: currentX,
            currentTime: CACurrentMediaTime()
        )

        if started {
            transitionTo(.objectInteracting(objectID: target.id))
            NSLog("[Pushling/Autonomous] Approaching object '%@' for '%@'",
                  target.id, target.interaction)
        }
    }
}

// MARK: - Object Interaction Update

extension AutonomousLayer {

    /// Per-frame update for the objectInteracting state.
    /// Delegates to ObjectInteractionEngine which produces LayerOutput.
    func updateObjectInteraction(objectID: String,
                                  deltaTime: TimeInterval,
                                  output: inout LayerOutput) {
        guard let engine = objectInteractionEngine else {
            transitionTo(.idle)
            return
        }

        // Verify the object still exists (may have been removed)
        if let query = objectQuery {
            let objects = query()
            if !objects.contains(where: { $0.id == objectID }) {
                engine.cancelInteraction()
                transitionTo(.idle)
                NSLog("[Pushling/Autonomous] Object '%@' removed "
                      + "mid-interaction", objectID)
                return
            }
        }

        // Get interaction output from engine
        if let interactionOutput = engine.update(
            deltaTime: deltaTime,
            creatureX: currentX,
            stage: stage,
            personality: personality
        ) {
            // Merge interaction output into our output
            output.merge(from: interactionOutput)
        } else {
            // Interaction complete — notify and return to idle
            let templateName = engine.activeInteraction?.template.name
                ?? "unknown"
            let satisfaction = engine.activeInteraction?.template
                .satisfactionBoost ?? 5.0
            attractionScorer?.recordInteraction(objectID: objectID)
            onObjectInteractionCompleted?(objectID, templateName,
                                           satisfaction)
            transitionTo(.idle)
        }
    }
}
