// BehaviorSelector.swift — Weighted random behavior selection engine
// Picks the next behavior during Autonomous layer idle -> behavior transitions.
//
// Selection is from a pool of behaviors that:
//   - Meet stage requirements (current stage >= behavior's stage_min)
//   - Are not on cooldown (time since last > behavior's cooldown)
//   - Meet emotional conditions (if any)
//
// Weight calculation:
//   weight = base_weight
//          * personality_affinity    (0.5-2.0)
//          * emotional_boost         (1.0-1.5)
//          * recency_penalty         (0.3/0.6/1.0)
//          * novelty_bonus           (1.5 if performed < 3 times)
//
// Global cooldown: 30 seconds between any two behaviors.

import Foundation

// MARK: - Behavior Definition

/// Defines a cat behavior available for autonomous selection.
struct BehaviorDefinition {
    /// Unique name for this behavior.
    let name: String

    /// Category for personality affinity matching.
    let category: BehaviorCategory

    /// Minimum growth stage required.
    let stageMin: GrowthStage

    /// Duration range in seconds.
    let durationRange: ClosedRange<TimeInterval>

    /// Base selection weight (before personality/emotion modulation).
    let baseWeight: Double

    /// Cooldown in seconds before this behavior can trigger again.
    let cooldown: TimeInterval

    /// Emotional condition that must be met (if any).
    let emotionalCondition: EmotionalCondition?

    /// A single random duration from the range.
    var duration: TimeInterval {
        TimeInterval.random(in: durationRange)
    }
}

// MARK: - Behavior Category

/// Categories for personality affinity mapping.
enum BehaviorCategory: String, CaseIterable {
    case playful        // Zoomies, tail chase
    case calm           // Loaf, slow-blink
    case social         // Headbutt, kneading
    case investigative  // Grooming, examining
    case mischievous    // Knocking things off, pranks
    case ritualistic    // Kneading pre-sleep
}

// MARK: - Emotional Condition

/// A condition on the creature's emotional state.
struct EmotionalCondition {
    let axis: EmotionalAxis
    let comparison: Comparison
    let threshold: Double

    enum EmotionalAxis {
        case satisfaction, curiosity, contentment, energy
    }

    enum Comparison {
        case greaterThan, lessThan
    }

    func isMet(by emotions: EmotionalSnapshot) -> Bool {
        let value: Double
        switch axis {
        case .satisfaction: value = emotions.satisfaction
        case .curiosity:    value = emotions.curiosity
        case .contentment:  value = emotions.contentment
        case .energy:       value = emotions.energy
        }

        switch comparison {
        case .greaterThan: return value > threshold
        case .lessThan:    return value < threshold
        }
    }
}

// MARK: - Personality Affinity

/// Maps behavior categories to personality axes for affinity scoring.
struct PersonalityAffinity {
    let highAffinityAxis: PersonalityAxis
    let highAffinityMultiplier: Double   // Applied when axis is high (>0.5)
    let lowAffinityMultiplier: Double    // Applied when axis is low (<0.5)

    enum PersonalityAxis {
        case energy, verbosity, focus, discipline
    }

    /// Compute the affinity multiplier for a given personality.
    /// Returns a value in [lowAffinityMultiplier, highAffinityMultiplier].
    func multiplier(for personality: PersonalitySnapshot) -> Double {
        let axisValue: Double
        switch highAffinityAxis {
        case .energy:     axisValue = personality.energy
        case .verbosity:  axisValue = personality.verbosity
        case .focus:      axisValue = personality.focus
        case .discipline: axisValue = personality.discipline
        }

        // Interpolate between low and high multiplier based on axis value
        return lerp(lowAffinityMultiplier, highAffinityMultiplier, axisValue)
    }
}

// MARK: - Behavior Selector

final class BehaviorSelector {

    // MARK: - Constants

    /// Minimum time between any two behaviors (global cooldown).
    static let globalCooldown: TimeInterval = 30.0

    // MARK: - Behavior Registry

    /// All available cat behaviors, defined as data.
    let behaviors: [BehaviorDefinition] = [
        BehaviorDefinition(
            name: "slow_blink",
            category: .calm,
            stageMin: .drop,
            durationRange: 1.1...1.1,
            baseWeight: 1.0,
            cooldown: 120,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 80
            )
        ),
        BehaviorDefinition(
            name: "kneading",
            category: .ritualistic,
            stageMin: .critter,
            durationRange: 4.0...8.0,
            baseWeight: 0.8,
            cooldown: 300,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 60
            )
        ),
        BehaviorDefinition(
            name: "headbutt",
            category: .social,
            stageMin: .critter,
            durationRange: 1.5...1.5,
            baseWeight: 0.7,
            cooldown: 180,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 50
            )
        ),
        BehaviorDefinition(
            name: "predator_crouch",
            category: .investigative,
            stageMin: .critter,
            durationRange: 2.0...2.0,
            baseWeight: 0.6,
            cooldown: 240,
            emotionalCondition: nil
        ),
        BehaviorDefinition(
            name: "loaf",
            category: .calm,
            stageMin: .critter,
            durationRange: 30.0...60.0,
            baseWeight: 1.2,
            cooldown: 300,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 50
            )
        ),
        BehaviorDefinition(
            name: "grooming",
            category: .investigative,
            stageMin: .critter,
            durationRange: 3.0...5.0,
            baseWeight: 1.0,
            cooldown: 180,
            emotionalCondition: nil
        ),
        BehaviorDefinition(
            name: "zoomies",
            category: .playful,
            stageMin: .critter,
            durationRange: 2.0...4.0,
            baseWeight: 0.5,
            cooldown: 600,
            emotionalCondition: EmotionalCondition(
                axis: .energy, comparison: .greaterThan, threshold: 70
            )
        ),
        BehaviorDefinition(
            name: "chattering",
            category: .investigative,
            stageMin: .critter,
            durationRange: 2.0...2.0,
            baseWeight: 0.4,
            cooldown: 300,
            emotionalCondition: nil
        ),
        BehaviorDefinition(
            name: "tail_chase",
            category: .playful,
            stageMin: .critter,
            durationRange: 4.0...6.0,
            baseWeight: 0.3,
            cooldown: 600,
            emotionalCondition: EmotionalCondition(
                axis: .energy, comparison: .greaterThan, threshold: 50
            )
        ),
        BehaviorDefinition(
            name: "tongue_blep",
            category: .calm,
            stageMin: .drop,
            durationRange: 15.0...30.0,
            baseWeight: 0.2,
            cooldown: 600,
            emotionalCondition: nil
        ),
        BehaviorDefinition(
            name: "knocking_things_off",
            category: .mischievous,
            stageMin: .beast,
            durationRange: 3.0...5.0,
            baseWeight: 0.4,
            cooldown: 600,
            emotionalCondition: EmotionalCondition(
                axis: .energy, comparison: .greaterThan, threshold: 50
            )
        ),
        BehaviorDefinition(
            name: "if_i_fits_i_sits",
            category: .calm,
            stageMin: .critter,
            durationRange: 10.0...20.0,
            baseWeight: 0.5,
            cooldown: 600,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 40
            )
        ),
        // Sage+ exclusive: deep meditation
        BehaviorDefinition(
            name: "meditation",
            category: .calm,
            stageMin: .sage,
            durationRange: 10.0...20.0,
            baseWeight: 1.2,
            cooldown: 600,
            emotionalCondition: EmotionalCondition(
                axis: .contentment, comparison: .greaterThan, threshold: 60
            )
        ),
    ]

    // MARK: - Personality Affinity Map

    /// Maps behavior categories to personality affinities (data-driven).
    private let affinityMap: [BehaviorCategory: PersonalityAffinity] = [
        .playful: PersonalityAffinity(
            highAffinityAxis: .energy,
            highAffinityMultiplier: 2.0,
            lowAffinityMultiplier: 0.5
        ),
        .calm: PersonalityAffinity(
            highAffinityAxis: .energy,
            highAffinityMultiplier: 0.5,
            lowAffinityMultiplier: 2.0
        ),
        .social: PersonalityAffinity(
            highAffinityAxis: .verbosity,
            highAffinityMultiplier: 1.5,
            lowAffinityMultiplier: 0.7
        ),
        .investigative: PersonalityAffinity(
            highAffinityAxis: .focus,
            highAffinityMultiplier: 1.5,
            lowAffinityMultiplier: 0.7
        ),
        .mischievous: PersonalityAffinity(
            highAffinityAxis: .discipline,
            highAffinityMultiplier: 0.5,
            lowAffinityMultiplier: 1.8
        ),
        .ritualistic: PersonalityAffinity(
            highAffinityAxis: .discipline,
            highAffinityMultiplier: 1.5,
            lowAffinityMultiplier: 0.7
        ),
    ]

    // MARK: - Tracking State

    /// When each behavior was last performed.
    private var lastPerformed: [String: TimeInterval] = [:]

    /// How many times each behavior has been performed total.
    private var performanceCount: [String: Int] = [:]

    /// When any behavior was last performed (global cooldown).
    private var lastAnyBehavior: TimeInterval = -30.0

    /// Current scene time (updated each frame).
    private var currentTime: TimeInterval = 0

    // MARK: - Selection

    /// Selects the next behavior based on stage, personality, and emotions.
    ///
    /// - Parameters:
    ///   - stage: Current growth stage (gates behavior availability).
    ///   - personality: Current personality axes.
    ///   - emotions: Current emotional state.
    /// - Returns: A behavior definition, or nil if none are eligible.
    func selectBehavior(stage: GrowthStage,
                        personality: PersonalitySnapshot,
                        emotions: EmotionalSnapshot) -> BehaviorDefinition? {

        // Global cooldown check
        guard currentTime - lastAnyBehavior >= Self.globalCooldown else {
            return nil
        }

        // Build eligible pool
        let eligible = behaviors.filter { behavior in
            // Stage gate
            guard stage >= behavior.stageMin else { return false }

            // Cooldown check
            if let lastTime = lastPerformed[behavior.name] {
                let cooldownMod = cooldownModifier(for: personality)
                guard currentTime - lastTime >= behavior.cooldown * cooldownMod else {
                    return false
                }
            }

            // Emotional condition
            if let condition = behavior.emotionalCondition {
                guard condition.isMet(by: emotions) else { return false }
            }

            return true
        }

        guard !eligible.isEmpty else { return nil }

        // Calculate weights
        var weightedPool: [(BehaviorDefinition, Double)] = eligible.map { behavior in
            let weight = calculateWeight(
                behavior: behavior,
                personality: personality,
                emotions: emotions
            )
            return (behavior, weight)
        }

        // Sort by weight for debug logging
        weightedPool.sort { $0.1 > $1.1 }

        // Weighted random selection
        let totalWeight = weightedPool.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else { return nil }

        var roll = Double.random(in: 0..<totalWeight)
        for (behavior, weight) in weightedPool {
            roll -= weight
            if roll <= 0 {
                NSLog("[Pushling/Behavior] Selected '%@' (weight %.2f) "
                      + "from pool of %d behaviors",
                      behavior.name, weight, eligible.count)
                return behavior
            }
        }

        // Fallback to highest weight
        return weightedPool.first?.0
    }

    // MARK: - Weight Calculation

    /// Calculates the selection weight for a behavior.
    ///
    /// weight = base_weight
    ///        * personality_affinity    (0.5-2.0)
    ///        * emotional_boost         (1.0-1.5)
    ///        * recency_penalty         (0.3/0.6/1.0)
    ///        * novelty_bonus           (1.5 if performed < 3 times)
    private func calculateWeight(behavior: BehaviorDefinition,
                                  personality: PersonalitySnapshot,
                                  emotions: EmotionalSnapshot) -> Double {
        var weight = behavior.baseWeight

        // Personality affinity
        if let affinity = affinityMap[behavior.category] {
            weight *= affinity.multiplier(for: personality)
        }

        // Emotional boost (1.0-1.5 based on alignment)
        weight *= emotionalBoost(for: behavior, emotions: emotions)

        // Recency penalty
        weight *= recencyPenalty(for: behavior.name)

        // Novelty bonus
        let count = performanceCount[behavior.name] ?? 0
        if count < 3 {
            weight *= 1.5
        }

        return max(weight, 0.01)  // Never zero
    }

    /// Emotional boost: higher when the behavior matches the current mood.
    private func emotionalBoost(for behavior: BehaviorDefinition,
                                 emotions: EmotionalSnapshot) -> Double {
        switch behavior.category {
        case .playful:
            // Boost when energy is high
            return 1.0 + (emotions.energy / 100.0) * 0.5
        case .calm:
            // Boost when contentment is high
            return 1.0 + (emotions.contentment / 100.0) * 0.5
        case .social:
            // Boost when satisfaction is high
            return 1.0 + (emotions.satisfaction / 100.0) * 0.5
        case .investigative:
            // Boost when curiosity is high
            return 1.0 + (emotions.curiosity / 100.0) * 0.5
        case .mischievous:
            // Boost when energy is high and satisfaction is low
            let energyFactor = emotions.energy / 100.0
            let satFactor = 1.0 - emotions.satisfaction / 100.0
            return 1.0 + (energyFactor * satFactor) * 0.5
        case .ritualistic:
            // Boost when contentment is moderate-high
            return 1.0 + (emotions.contentment / 100.0) * 0.3
        }
    }

    /// Recency penalty: reduces weight for recently performed behaviors.
    private func recencyPenalty(for name: String) -> Double {
        guard let lastTime = lastPerformed[name] else {
            return 1.0  // Never performed
        }

        let elapsed = currentTime - lastTime
        if elapsed < 3600 {       // < 1 hour
            return 0.3
        } else if elapsed < 7200 { // < 2 hours
            return 0.6
        }
        return 1.0
    }

    /// Personality-based cooldown modifier. Hyper creatures have shorter cooldowns.
    private func cooldownModifier(for personality: PersonalitySnapshot) -> Double {
        // Energy: hyper (1.0) = 0.6x cooldowns, calm (0.0) = 1.4x
        return 0.6 + (1.0 - personality.energy) * 0.8
    }

    // MARK: - Recording

    /// Records that a behavior was performed.
    func recordBehaviorCompletion(name: String) {
        lastPerformed[name] = currentTime
        performanceCount[name, default: 0] += 1
        lastAnyBehavior = currentTime
    }

    /// Updates the current scene time. Called each frame.
    func updateTime(_ time: TimeInterval) {
        currentTime = time
    }

    /// Current scene time for external queries (e.g., taught behavior selection).
    var currentSceneTime: TimeInterval { currentTime }

    // MARK: - Debug

    /// Returns a summary of all behavior weights for the current state.
    func debugWeights(stage: GrowthStage,
                      personality: PersonalitySnapshot,
                      emotions: EmotionalSnapshot) -> [(String, Double, Bool)] {
        behaviors.map { behavior in
            let eligible = stage >= behavior.stageMin
                && (behavior.emotionalCondition?.isMet(by: emotions) ?? true)
            let weight = calculateWeight(behavior: behavior,
                                          personality: personality,
                                          emotions: emotions)
            return (behavior.name, weight, eligible)
        }
    }
}
