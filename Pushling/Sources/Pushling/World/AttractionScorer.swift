// AttractionScorer.swift — 7-factor scoring for autonomous object interaction
// Determines when and which objects the creature approaches.
//
// Scoring formula: base * personality * mood * recency * novelty * proximity * time
//
// Creature interacts with highest-scoring object, with personality.discipline
// modulating how often it picks a suboptimal choice.
// Max 1 object interaction per 5 minutes.

import Foundation
import CoreGraphics

// MARK: - Attraction Score

/// A scored object with its attraction factors.
struct AttractionScore {
    let objectID: String
    let objectX: CGFloat
    let interactionName: String
    let totalScore: Double
    let factors: AttractionFactors
}

/// Individual factor values for debugging/display.
struct AttractionFactors {
    let baseWeight: Double
    let personalityAffinity: Double
    let moodModifier: Double
    let recencyDecay: Double
    let noveltyBonus: Double
    let proximityScore: Double
    let timeOfDayModifier: Double
}

// MARK: - AttractionScorer

/// Computes attraction scores for world objects to determine autonomous interaction.
final class AttractionScorer {

    // MARK: - Configuration

    /// Base weights by interaction category.
    private static let categoryBaseWeights: [String: Double] = [
        // Toys > Furniture > Interactive > Decorative
        "batting_toy": 1.2,    "chasing": 1.3,     "carrying": 1.0,
        "string_play": 1.2,   "pushing": 0.9,
        "sitting": 0.8,       "climbing": 0.9,     "scratching": 0.7,
        "hiding": 0.7,
        "examining": 0.5,     "rubbing": 0.6,
        "listening": 0.6,     "watching": 0.5,     "reflecting": 0.6,
        "eating": 1.5,        // Consumables score highest
    ]

    /// Personality affinity: which personality axes boost which categories.
    private static let personalityAffinities: [String: (axis: String, high: Double, low: Double)] = [
        "batting_toy": ("energy", 2.0, 0.5),
        "chasing":     ("energy", 2.0, 0.5),
        "carrying":    ("focus", 1.5, 0.7),
        "string_play": ("energy", 1.8, 0.6),
        "pushing":     ("discipline", 0.5, 1.8),  // Chaotic creatures push more
        "sitting":     ("energy", 0.5, 2.0),       // Calm creatures sit more
        "climbing":    ("energy", 1.5, 0.7),
        "scratching":  ("discipline", 1.3, 0.8),
        "hiding":      ("energy", 0.5, 1.5),       // Calm creatures hide
        "examining":   ("focus", 1.5, 0.7),
        "rubbing":     ("verbosity", 1.3, 0.8),    // Social creatures rub
        "listening":   ("focus", 1.5, 0.7),
        "watching":    ("focus", 1.8, 0.5),
        "reflecting":  ("focus", 1.5, 0.7),
        "eating":      ("energy", 1.3, 0.8),
    ]

    // MARK: - State

    /// Last interaction time per object (for recency decay).
    private var lastInteractionTimes: [String: Date] = [:]

    /// Object creation times (for novelty bonus).
    private var objectCreationTimes: [String: Date] = [:]

    // MARK: - Scoring

    /// Scores all objects and returns them ranked by attraction.
    ///
    /// - Parameters:
    ///   - objects: Active world objects with their definitions.
    ///   - creatureX: Creature's current world-X position.
    ///   - personality: Creature's personality snapshot.
    ///   - emotions: Creature's emotional state.
    ///   - hourOfDay: Current hour (0-23) for time-of-day modifier.
    /// - Returns: Sorted array of scores, highest first.
    func scoreObjects(
        objects: [(id: String, x: CGFloat, interaction: String)],
        creatureX: CGFloat,
        personality: PersonalitySnapshot,
        emotions: EmotionalSnapshot,
        hourOfDay: Int
    ) -> [AttractionScore] {

        var scores: [AttractionScore] = []

        for obj in objects {
            let factors = computeFactors(
                objectID: obj.id,
                objectX: obj.x,
                interaction: obj.interaction,
                creatureX: creatureX,
                personality: personality,
                emotions: emotions,
                hourOfDay: hourOfDay
            )

            let total = factors.baseWeight
                * factors.personalityAffinity
                * factors.moodModifier
                * factors.recencyDecay
                * factors.noveltyBonus
                * factors.proximityScore
                * factors.timeOfDayModifier

            scores.append(AttractionScore(
                objectID: obj.id,
                objectX: obj.x,
                interactionName: obj.interaction,
                totalScore: total,
                factors: factors
            ))
        }

        scores.sort { $0.totalScore > $1.totalScore }
        return scores
    }

    /// Selects which object to interact with, with personality-based randomization.
    /// High discipline = usually picks the best. Low discipline = more random.
    func selectObject(
        from scores: [AttractionScore],
        personality: PersonalitySnapshot
    ) -> AttractionScore? {
        guard !scores.isEmpty else { return nil }

        // High discipline (1.0): 90% chance of picking best
        // Low discipline (0.0): 50% chance of picking best
        let bestChance = 0.5 + personality.discipline * 0.4

        if Double.random(in: 0...1) < bestChance {
            return scores[0]
        }

        // Pick from top 3 randomly
        let pool = Array(scores.prefix(3))
        let totalWeight = pool.reduce(0.0) { $0 + $1.totalScore }
        guard totalWeight > 0 else { return scores[0] }

        var roll = Double.random(in: 0..<totalWeight)
        for score in pool {
            roll -= score.totalScore
            if roll <= 0 { return score }
        }

        return scores[0]
    }

    // MARK: - Factor Computation

    private func computeFactors(
        objectID: String,
        objectX: CGFloat,
        interaction: String,
        creatureX: CGFloat,
        personality: PersonalitySnapshot,
        emotions: EmotionalSnapshot,
        hourOfDay: Int
    ) -> AttractionFactors {
        // 1. Base weight
        let baseWeight = Self.categoryBaseWeights[interaction] ?? 0.5

        // 2. Personality affinity
        let personalityAffinity: Double
        if let affinity = Self.personalityAffinities[interaction] {
            let axisValue: Double
            switch affinity.axis {
            case "energy":     axisValue = personality.energy
            case "focus":      axisValue = personality.focus
            case "verbosity":  axisValue = personality.verbosity
            case "discipline": axisValue = personality.discipline
            default:           axisValue = 0.5
            }
            personalityAffinity = lerp(affinity.low, affinity.high, axisValue)
        } else {
            personalityAffinity = 1.0
        }

        // 3. Mood modifier
        let moodModifier: Double
        let avgMood = (emotions.satisfaction + emotions.contentment) / 200.0
        if avgMood > 0.6 {
            moodModifier = 1.0 + (avgMood - 0.6) * 1.25  // Up to 1.5
        } else if avgMood < 0.3 {
            moodModifier = 0.3 + avgMood  // Down to 0.3
        } else {
            moodModifier = 1.0
        }

        // 4. Recency decay
        let recencyDecay: Double
        if let lastTime = lastInteractionTimes[objectID] {
            let hoursAgo = Date().timeIntervalSince(lastTime) / 3600
            if hoursAgo < 1 {
                recencyDecay = 0.2  // Just interacted — low score
            } else if hoursAgo < 4 {
                recencyDecay = 0.6
            } else {
                recencyDecay = 1.0
            }
        } else {
            recencyDecay = 1.0  // Never interacted
        }

        // 5. Novelty bonus
        let noveltyBonus: Double
        if let createdAt = objectCreationTimes[objectID] {
            let hoursOld = Date().timeIntervalSince(createdAt) / 3600
            if hoursOld < 24 {
                noveltyBonus = 3.0 - (hoursOld / 24.0 * 2.0)  // 3.0 -> 1.0 over 24h
            } else {
                noveltyBonus = 1.0
            }
        } else {
            noveltyBonus = 1.5  // Unknown age — moderate bonus
        }

        // 6. Proximity
        let distance = abs(objectX - creatureX)
        let proximityScore: Double
        if distance < 20 {
            proximityScore = 1.5
        } else if distance < 50 {
            proximityScore = 1.0
        } else if distance < 100 {
            proximityScore = 0.7
        } else {
            proximityScore = 0.5
        }

        // 7. Time of day
        let timeOfDayModifier: Double
        let isToyInteraction = ["batting_toy", "chasing", "string_play",
                                 "carrying", "pushing"].contains(interaction)
        let isFurnitureInteraction = ["sitting", "hiding"].contains(interaction)

        if isToyInteraction {
            // Toys score higher during high-energy hours (9-17)
            timeOfDayModifier = (hourOfDay >= 9 && hourOfDay <= 17) ? 1.3 : 0.7
        } else if isFurnitureInteraction {
            // Furniture scores higher during low-energy hours
            timeOfDayModifier = (hourOfDay < 9 || hourOfDay > 21) ? 1.3 : 0.8
        } else {
            timeOfDayModifier = 1.0
        }

        return AttractionFactors(
            baseWeight: baseWeight,
            personalityAffinity: personalityAffinity,
            moodModifier: moodModifier,
            recencyDecay: recencyDecay,
            noveltyBonus: noveltyBonus,
            proximityScore: proximityScore,
            timeOfDayModifier: timeOfDayModifier
        )
    }

    // MARK: - State Management

    /// Records that the creature interacted with an object.
    func recordInteraction(objectID: String) {
        lastInteractionTimes[objectID] = Date()
    }

    /// Registers an object's creation time (for novelty scoring).
    func registerObject(id: String, createdAt: Date) {
        objectCreationTimes[id] = createdAt
    }

    /// Removes tracking data for a removed object.
    func removeObject(id: String) {
        lastInteractionTimes.removeValue(forKey: id)
        objectCreationTimes.removeValue(forKey: id)
    }

    /// Resets all scoring state.
    func reset() {
        lastInteractionTimes.removeAll()
        objectCreationTimes.removeAll()
    }
}
