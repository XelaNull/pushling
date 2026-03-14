// ReflexLayer.swift — Layer 2: Reflexes
// Short-lived behavior overrides triggered by input events.
//
// Reflexes are the only way this layer gets populated. Each reflex
// has a trigger, duration, and LayerOutput properties to override.
// Multiple reflexes can be active simultaneously — per-property,
// the most recent reflex wins within this layer.
//
// Reflexes expire automatically. During the fadeout portion (last 20%),
// property overrides blend toward nil, releasing control to lower layers.
//
// Max 5 simultaneous reflexes — oldest is evicted if exceeded.
// Reflex snap-in is 0.15s via the blend controller.

import Foundation
import CoreGraphics

// MARK: - Reflex Definition

/// A pre-defined reflex type with its trigger, duration, and output.
struct ReflexDefinition {
    let name: String
    let duration: TimeInterval      // 0.5-3.0s
    let fadeoutFraction: Double     // Fraction of duration for fadeout (typically 0.2)
    let output: LayerOutput         // The properties this reflex overrides
}

// MARK: - Active Reflex

/// A reflex that is currently active and counting down.
struct ActiveReflex {
    let definition: ReflexDefinition
    let triggeredAt: TimeInterval   // Scene time when triggered
    var elapsed: TimeInterval       // Time since trigger

    /// Whether this reflex has fully expired.
    var isExpired: Bool {
        elapsed >= definition.duration
    }

    /// Blend factor for fadeout (1.0 = full override, 0.0 = fully faded).
    /// Returns 1.0 during the active portion, then fades to 0.0 during fadeout.
    var blendFactor: Double {
        let fadeoutStart = definition.duration * (1.0 - definition.fadeoutFraction)
        if elapsed < fadeoutStart {
            return 1.0
        }
        let fadeoutElapsed = elapsed - fadeoutStart
        let fadeoutDuration = definition.duration * definition.fadeoutFraction
        guard fadeoutDuration > 0 else { return 0.0 }
        return max(0.0, 1.0 - fadeoutElapsed / fadeoutDuration)
    }
}

// MARK: - Reflex Layer

final class ReflexLayer: BehaviorLayer {

    // MARK: - Constants

    /// Maximum number of simultaneous active reflexes.
    private static let maxActiveReflexes = 5

    // MARK: - Pre-Defined Reflex Types

    /// Ear perk: triggered by new events (commit, touch, sound).
    static let earPerk = ReflexDefinition(
        name: "ear_perk",
        duration: 0.8,
        fadeoutFraction: 0.2,
        output: {
            var o = LayerOutput()
            o.earLeftState = "perk"
            o.earRightState = "perk"
            return o
        }()
    )

    /// Flinch: triggered by force push commits.
    static let flinch = ReflexDefinition(
        name: "flinch",
        duration: 1.5,
        fadeoutFraction: 0.2,
        output: {
            var o = LayerOutput()
            o.bodyState = "crouch"
            o.earLeftState = "flat"
            o.earRightState = "flat"
            o.eyeLeftState = "wide"
            o.eyeRightState = "wide"
            return o
        }()
    )

    /// Look at touch: triggered by touch events.
    static let lookAtTouch = ReflexDefinition(
        name: "look_at_touch",
        duration: 1.0,
        fadeoutFraction: 0.2,
        output: {
            var o = LayerOutput()
            o.eyeLeftState = "look_at"
            o.eyeRightState = "look_at"
            o.earLeftState = "rotate_toward"
            o.earRightState = "rotate_toward"
            return o
        }()
    )

    /// Startle: triggered by sudden loud events.
    static let startle = ReflexDefinition(
        name: "startle",
        duration: 0.5,
        fadeoutFraction: 0.2,
        output: {
            var o = LayerOutput()
            o.bodyState = "jump"
            o.earLeftState = "back"
            o.earRightState = "back"
            o.eyeLeftState = "wide"
            o.eyeRightState = "wide"
            o.tailState = "poof"
            return o
        }()
    )

    // MARK: - State

    /// Currently active reflexes, ordered by trigger time (newest last).
    private var activeReflexes: [ActiveReflex] = []

    /// Whether any reflexes are currently active.
    var isActive: Bool {
        !activeReflexes.isEmpty
    }

    /// Number of currently active reflexes.
    var activeCount: Int {
        activeReflexes.count
    }

    // MARK: - BehaviorLayer

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) -> LayerOutput {
        // Update elapsed time on all active reflexes
        for i in activeReflexes.indices {
            activeReflexes[i].elapsed += deltaTime
        }

        // Remove expired reflexes
        activeReflexes.removeAll { $0.isExpired }

        // If no active reflexes, defer everything
        guard !activeReflexes.isEmpty else {
            return .empty
        }

        // Merge active reflexes: per-property, most recent (last in array) wins
        // Apply fadeout blend factor to determine if a property is "active enough"
        return mergeActiveReflexes()
    }

    // MARK: - Trigger

    /// Triggers a reflex. If max reflexes are active, the oldest is evicted.
    func trigger(_ definition: ReflexDefinition, at currentTime: TimeInterval) {
        // Remove any existing reflex of the same type (refresh it)
        activeReflexes.removeAll { $0.definition.name == definition.name }

        // Evict oldest if at capacity
        if activeReflexes.count >= Self.maxActiveReflexes {
            activeReflexes.removeFirst()
        }

        let reflex = ActiveReflex(
            definition: definition,
            triggeredAt: currentTime,
            elapsed: 0
        )
        activeReflexes.append(reflex)

        NSLog("[Pushling/Behavior] Reflex triggered: %@ (%.1fs)",
              definition.name, definition.duration)
    }

    /// Triggers a reflex by name using pre-defined types.
    func trigger(named name: String, at currentTime: TimeInterval) {
        switch name {
        case "ear_perk":       trigger(Self.earPerk, at: currentTime)
        case "flinch":         trigger(Self.flinch, at: currentTime)
        case "look_at_touch":  trigger(Self.lookAtTouch, at: currentTime)
        case "startle":        trigger(Self.startle, at: currentTime)
        default:
            NSLog("[Pushling/Behavior] Unknown reflex name: %@", name)
        }
    }

    /// Clears all active reflexes immediately.
    func clearAll() {
        activeReflexes.removeAll()
    }

    // MARK: - Merge

    /// Merges all active reflexes into a single LayerOutput.
    /// Per-property, the most recent reflex with a non-nil value wins,
    /// modulated by its fadeout blend factor.
    private func mergeActiveReflexes() -> LayerOutput {
        var merged = LayerOutput()

        // Iterate newest-first (reversed) — first non-nil wins per property
        for reflex in activeReflexes.reversed() {
            let factor = reflex.blendFactor
            guard factor > 0.05 else { continue }  // Skip nearly-faded reflexes

            let src = reflex.definition.output

            // For each property: if merged doesn't have it yet and source does,
            // take it (if blend factor is high enough to be meaningful)
            if merged.positionX == nil, let v = src.positionX {
                merged.positionX = v
            }
            if merged.positionY == nil, let v = src.positionY {
                merged.positionY = v
            }
            if merged.facing == nil, let v = src.facing {
                merged.facing = v
            }
            if merged.walkSpeed == nil, let v = src.walkSpeed {
                merged.walkSpeed = v
            }
            if merged.bodyState == nil, let v = src.bodyState {
                merged.bodyState = factor > 0.5 ? v : nil
            }
            if merged.earLeftState == nil, let v = src.earLeftState {
                merged.earLeftState = factor > 0.3 ? v : nil
            }
            if merged.earRightState == nil, let v = src.earRightState {
                merged.earRightState = factor > 0.3 ? v : nil
            }
            if merged.eyeLeftState == nil, let v = src.eyeLeftState {
                merged.eyeLeftState = factor > 0.3 ? v : nil
            }
            if merged.eyeRightState == nil, let v = src.eyeRightState {
                merged.eyeRightState = factor > 0.3 ? v : nil
            }
            if merged.tailState == nil, let v = src.tailState {
                merged.tailState = factor > 0.5 ? v : nil
            }
            if merged.mouthState == nil, let v = src.mouthState {
                merged.mouthState = factor > 0.3 ? v : nil
            }
            if merged.whiskerState == nil, let v = src.whiskerState {
                merged.whiskerState = factor > 0.3 ? v : nil
            }
            if merged.auraState == nil, let v = src.auraState {
                merged.auraState = factor > 0.5 ? v : nil
            }
            if merged.pawStates == nil, let v = src.pawStates {
                merged.pawStates = factor > 0.5 ? v : nil
            }
        }

        return merged
    }
}
