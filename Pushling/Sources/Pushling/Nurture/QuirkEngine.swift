// QuirkEngine.swift — Behavior interceptors that modify existing animations
// Quirks fire probabilistically, modifying behaviors with small tweaks.
// 4 modification types: prepend, append, replace_element, overlay.
// Max 12 active quirks. Stack: multiple quirks can modify same behavior.
//
// Small tweaks accumulate into distinctive personality over time.

import Foundation

// MARK: - Quirk Definition

/// A persistent quirk that modifies existing behaviors.
struct QuirkDefinition {
    let id: String
    let name: String
    let description: String?
    let targetBehavior: String          // Which behavior to intercept
    let modification: QuirkModification
    let action: QuirkAction
    let probability: Double             // 0.05-0.90
    var strength: Double                // 0.0-1.0 (from decay)
    var reinforcementCount: Int
    let createdAt: Date

    /// Effective probability = probability * strength.
    var effectiveProbability: Double {
        probability * strength
    }
}

/// How the quirk modifies the behavior.
enum QuirkModification: String {
    case prepend         // Insert action before behavior starts
    case append          // Insert action after behavior ends
    case replaceElement  // Swap one element of the behavior
    case overlay         // Add action simultaneously on a different track
}

/// The action a quirk performs.
struct QuirkAction {
    let track: String               // Which track to affect
    let state: String               // Semantic state to apply
    let durationSeconds: TimeInterval  // How long the modification lasts
}

// MARK: - Quirk Application Result

/// The result of checking quirks for a behavior.
struct QuirkApplicationResult {
    /// Actions to prepend before the behavior.
    var prependActions: [QuirkAction]
    /// Actions to append after the behavior.
    var appendActions: [QuirkAction]
    /// Element replacements (track -> new state).
    var replacements: [String: String]
    /// Overlay actions (run simultaneously).
    var overlayActions: [QuirkAction]

    var isEmpty: Bool {
        prependActions.isEmpty && appendActions.isEmpty
            && replacements.isEmpty && overlayActions.isEmpty
    }
}

// MARK: - QuirkEngine

/// Manages quirks and applies them to behavior execution.
final class QuirkEngine {

    // MARK: - Configuration

    /// Maximum active quirks.
    static let maxQuirks = 12

    // MARK: - State

    /// All active quirk definitions.
    private(set) var quirks: [QuirkDefinition] = []

    /// Random number generator.
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Quirk Management

    /// Adds a new quirk. Returns false if at cap.
    @discardableResult
    func addQuirk(_ quirk: QuirkDefinition) -> Bool {
        guard quirks.count < Self.maxQuirks else {
            NSLog("[Pushling/Quirks] At cap (%d). Cannot add '%@'.",
                  Self.maxQuirks, quirk.name)
            return false
        }
        quirks.append(quirk)
        NSLog("[Pushling/Quirks] Added quirk '%@' targeting '%@'",
              quirk.name, quirk.targetBehavior)
        return true
    }

    /// Removes a quirk by name.
    func removeQuirk(named name: String) {
        quirks.removeAll { $0.name == name }
    }

    /// Reinforces a quirk.
    func reinforce(named name: String) {
        if let idx = quirks.firstIndex(where: { $0.name == name }) {
            quirks[idx].strength = Swift.min(quirks[idx].strength + 0.15, 1.0)
            quirks[idx].reinforcementCount += 1
        }
    }

    // MARK: - Application

    /// Checks all quirks that target a specific behavior and rolls for each.
    /// Returns the modifications to apply.
    ///
    /// - Parameter behaviorName: The behavior about to execute.
    /// - Returns: Accumulated modifications from all firing quirks.
    func applyQuirks(for behaviorName: String) -> QuirkApplicationResult {
        var result = QuirkApplicationResult(
            prependActions: [], appendActions: [],
            replacements: [:], overlayActions: []
        )

        // Find matching quirks (sorted by creation order)
        let matching = quirks.filter { quirk in
            quirk.targetBehavior == behaviorName && quirk.strength >= 0.2
        }

        for quirk in matching {
            // Roll for probability
            let roll = Double.random(in: 0...1, using: &rng)
            guard roll < quirk.effectiveProbability else { continue }

            // Apply based on modification type
            switch quirk.modification {
            case .prepend:
                result.prependActions.append(quirk.action)

            case .append:
                result.appendActions.append(quirk.action)

            case .replaceElement:
                result.replacements[quirk.action.track] = quirk.action.state

            case .overlay:
                result.overlayActions.append(quirk.action)
            }

            NSLog("[Pushling/Quirks] Quirk '%@' fired for '%@' (%@)",
                  quirk.name, behaviorName, quirk.modification.rawValue)
        }

        return result
    }

    /// Applies quirk modifications to a LayerOutput.
    /// Call with the output from the behavior engine.
    func applyToOutput(result: QuirkApplicationResult,
                        output: inout LayerOutput) {
        // Apply replacements
        for (track, state) in result.replacements {
            switch track {
            case "body":     output.bodyState = state
            case "eyes":
                output.eyeLeftState = state
                output.eyeRightState = state
            case "ears":
                output.earLeftState = state
                output.earRightState = state
            case "tail":     output.tailState = state
            case "mouth":    output.mouthState = state
            case "whiskers": output.whiskerState = state
            case "head":     break  // Head states are complex
            case "paw_fl":
                var paws = output.pawStates ?? [:]
                paws["fl"] = state
                output.pawStates = paws
            case "paw_fr":
                var paws = output.pawStates ?? [:]
                paws["fr"] = state
                output.pawStates = paws
            default:
                break
            }
        }

        // Apply overlays (only for tracks not already set by behavior)
        for overlay in result.overlayActions {
            switch overlay.track {
            case "tail":
                if output.tailState == nil { output.tailState = overlay.state }
            case "ears":
                if output.earLeftState == nil {
                    output.earLeftState = overlay.state
                    output.earRightState = overlay.state
                }
            case "eyes":
                if output.eyeLeftState == nil {
                    output.eyeLeftState = overlay.state
                    output.eyeRightState = overlay.state
                }
            case "mouth":
                if output.mouthState == nil { output.mouthState = overlay.state }
            case "whiskers":
                if output.whiskerState == nil { output.whiskerState = overlay.state }
            default:
                break
            }
        }
    }

    // MARK: - Queries

    /// Returns all quirks targeting a specific behavior.
    func quirksFor(behavior: String) -> [QuirkDefinition] {
        return quirks.filter { $0.targetBehavior == behavior }
    }

    /// Returns all active quirks.
    var activeQuirks: [QuirkDefinition] {
        return quirks.filter { $0.strength >= 0.2 }
    }

    /// The most distinctive quirk (highest effective probability).
    var mostDistinctive: QuirkDefinition? {
        return activeQuirks.max { $0.effectiveProbability < $1.effectiveProbability }
    }

    // MARK: - Decay Integration

    /// Updates strength for a quirk (called by decay system).
    func updateStrength(name: String, strength: Double) {
        if let idx = quirks.firstIndex(where: { $0.name == name }) {
            quirks[idx].strength = Swift.max(0.0, Swift.min(1.0, strength))
        }
    }

    // MARK: - Bulk Operations

    /// Loads quirks from SQLite data.
    func loadQuirks(_ data: [QuirkDefinition]) {
        quirks = Array(data.prefix(Self.maxQuirks))
        NSLog("[Pushling/Quirks] Loaded %d quirks", quirks.count)
    }

    /// Resets all quirk state.
    func reset() {
        quirks.removeAll()
    }
}
