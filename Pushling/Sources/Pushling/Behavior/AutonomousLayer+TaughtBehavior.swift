// AutonomousLayer+TaughtBehavior.swift — Taught behavior integration
// Handles selection, execution, and completion of taught behaviors
// during the autonomous layer's idle rotation.
//
// Selection flow:
//   idle -> governor gate -> weighted random -> TaughtBehaviorEngine
//   -> per-frame LayerOutput -> completion -> mastery + breeding

import Foundation

extension AutonomousLayer {

    // MARK: - Per-Frame Update

    /// Per-frame update when playing a taught behavior via TaughtBehaviorEngine.
    func updateTaughtBehavior(name: String, deltaTime: TimeInterval,
                              currentTime: TimeInterval,
                              output: inout LayerOutput) {
        guard let engine = taughtEngine else {
            transitionTo(.idle)
            return
        }

        if let engineOutput = engine.update(deltaTime: deltaTime,
                                             currentTime: currentTime) {
            output.merge(from: engineOutput)
        } else {
            // Engine returned nil — behavior finished
            let defs = taughtDefinitions?() ?? [:]
            if let definition = defs[name] {
                onTaughtBehaviorCompleted?(name, definition, currentTime)
            }
            transitionTo(.idle)
        }
    }

    // MARK: - Selection

    /// Selects a taught behavior if the governor allows it.
    /// Returns a (name, definition) pair, or nil.
    func selectTaughtBehavior()
        -> (String, ChoreographyDefinition)? {
        guard let governor = taughtGovernor,
              let definitions = taughtDefinitions?(),
              !definitions.isEmpty else {
            return nil
        }

        let sceneTime = behaviorSelector.currentSceneTime
        guard governor.canPlayTaughtBehavior(currentTime: sceneTime) else {
            return nil
        }

        // Filter eligible by stage and build weighted pool
        let eligible = definitions.filter { $0.value.stageMin <= stage }
        guard !eligible.isEmpty else { return nil }

        let weightMod = governor.taughtWeightModifier(currentTime: sceneTime)
        var totalWeight = 0.0
        var pool: [(String, ChoreographyDefinition, Double)] = []

        for (name, def) in eligible {
            let weight = def.triggers.idleWeight * weightMod
            if weight > 0 {
                pool.append((name, def, weight))
                totalWeight += weight
            }
        }
        guard totalWeight > 0 else { return nil }

        var roll = Double.random(in: 0..<totalWeight)
        for (name, def, weight) in pool {
            roll -= weight
            if roll <= 0 { return (name, def) }
        }
        return pool.first.map { ($0.0, $0.1) }
    }

    // MARK: - Start

    /// Starts a taught behavior by delegating to TaughtBehaviorEngine.
    func startTaughtBehavior(
        _ selected: (String, ChoreographyDefinition)
    ) {
        let (name, definition) = selected
        let mastery = taughtMastery?.masteryLevel(for: name) ?? .learning
        let sceneTime = behaviorSelector.currentSceneTime

        taughtEngine?.begin(definition: definition,
                             mastery: mastery,
                             personality: personality,
                             currentTime: sceneTime)

        transitionTo(.taughtBehavior(name: name))
        NSLog("[Pushling/Autonomous] Playing taught behavior '%@' "
              + "(%@)", name, mastery.displayName)
    }
}

// LayerOutput.merge(from:) is defined in LayerTypes.swift
