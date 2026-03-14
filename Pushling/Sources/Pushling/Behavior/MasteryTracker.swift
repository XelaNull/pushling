// MasteryTracker.swift — 4-tier mastery system for taught behaviors
// Tracks performance count per behavior, determines mastery level,
// and provides mastery-dependent execution parameters.
//
// Tiers: Learning (0-2) -> Practiced (3-9) -> Mastered (10-24) -> Signature (25+)
//
// Mastery progression is permanent — does not decay.
// Strength (from NurtureDecayManager) is separate from mastery.

import Foundation

// MARK: - Mastery Level

/// The 4 mastery tiers for taught behaviors.
enum MasteryLevel: Int, Comparable, CaseIterable {
    case learning = 0    // 0-2 performances
    case practiced = 1   // 3-9 performances
    case mastered = 2    // 10-24 performances
    case signature = 3   // 25+ performances

    static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable name.
    var displayName: String {
        switch self {
        case .learning:  return "Learning"
        case .practiced: return "Practiced"
        case .mastered:  return "Mastered"
        case .signature: return "Signature"
        }
    }

    /// Timing jitter percentage at this mastery level.
    var timingJitter: Double {
        switch self {
        case .learning:  return 0.20  // +/- 20%
        case .practiced: return 0.10  // +/- 10%
        case .mastered:  return 0.03  // +/- 3%
        case .signature: return 0.01  // +/- 1%
        }
    }

    /// Fumble probability at this mastery level.
    var fumbleProbability: Double {
        switch self {
        case .learning:  return 0.30  // 30% chance per keyframe
        case .practiced: return 0.15  // 15%
        case .mastered:  return 0.00  // No fumbles
        case .signature: return 0.00
        }
    }

    /// Whether this mastery level shows in dreams.
    var dreamEligible: Bool {
        self >= .mastered
    }

    /// Initialize from performance count.
    init(performanceCount: Int) {
        switch performanceCount {
        case 0...2:   self = .learning
        case 3...9:   self = .practiced
        case 10...24: self = .mastered
        default:      self = .signature
        }
    }
}

// MARK: - Mastery Record

/// Persistent mastery data for a single taught behavior.
struct MasteryRecord {
    let behaviorName: String
    var performanceCount: Int
    var lastPerformedAt: Date?
    var totalFumbles: Int

    /// Current mastery level derived from performance count.
    var level: MasteryLevel {
        MasteryLevel(performanceCount: performanceCount)
    }

    /// Whether this performance crosses a mastery tier boundary.
    func willLevelUp(afterPerformance: Bool = true) -> Bool {
        let current = MasteryLevel(performanceCount: performanceCount)
        let next = MasteryLevel(performanceCount: performanceCount + 1)
        return afterPerformance && next != current
    }
}

// MARK: - Performance Log Entry

/// A single performance of a taught behavior, logged for history.
struct PerformanceLogEntry {
    let behaviorName: String
    let performedAt: Date
    let triggerType: String   // "idle", "touch", "commit", "dream", "ai"
    let masteryAtTime: MasteryLevel
    let fumbleCount: Int
    let personalitySnapshot: PersonalitySnapshot
}

// MARK: - MasteryTracker

/// Tracks mastery progression for all taught behaviors.
/// Provides mastery-dependent parameters for the TaughtBehaviorEngine.
final class MasteryTracker {

    // MARK: - State

    /// Mastery records keyed by behavior name.
    private var records: [String: MasteryRecord] = [:]

    /// Recent performance log (last 100 entries, in-memory).
    private var recentPerformances: [PerformanceLogEntry] = []

    /// Maximum in-memory log entries.
    private static let maxLogEntries = 100

    // MARK: - Mastery Queries

    /// Returns the current mastery level for a behavior.
    func masteryLevel(for behaviorName: String) -> MasteryLevel {
        return records[behaviorName]?.level ?? .learning
    }

    /// Returns the full mastery record for a behavior.
    func record(for behaviorName: String) -> MasteryRecord? {
        return records[behaviorName]
    }

    /// Returns all behaviors at or above a given mastery level.
    func behaviors(atOrAbove level: MasteryLevel) -> [MasteryRecord] {
        return records.values.filter { $0.level >= level }
    }

    /// Returns the performance count for a behavior.
    func performanceCount(for behaviorName: String) -> Int {
        return records[behaviorName]?.performanceCount ?? 0
    }

    // MARK: - Recording

    /// Records a performance of a taught behavior.
    /// Updates mastery progression and returns whether a level-up occurred.
    @discardableResult
    func recordPerformance(
        behaviorName: String,
        triggerType: String,
        fumbleCount: Int = 0,
        personality: PersonalitySnapshot
    ) -> Bool {
        // Get or create record
        var record = records[behaviorName] ?? MasteryRecord(
            behaviorName: behaviorName,
            performanceCount: 0,
            lastPerformedAt: nil,
            totalFumbles: 0
        )

        let willLevel = record.willLevelUp()
        let previousLevel = record.level

        record.performanceCount += 1
        record.lastPerformedAt = Date()
        record.totalFumbles += fumbleCount
        records[behaviorName] = record

        // Log performance
        let entry = PerformanceLogEntry(
            behaviorName: behaviorName,
            performedAt: Date(),
            triggerType: triggerType,
            masteryAtTime: record.level,
            fumbleCount: fumbleCount,
            personalitySnapshot: personality
        )
        recentPerformances.append(entry)
        if recentPerformances.count > Self.maxLogEntries {
            recentPerformances.removeFirst()
        }

        if willLevel {
            NSLog("[Pushling/Mastery] '%@' leveled up: %@ -> %@ "
                  + "(performances: %d)",
                  behaviorName, previousLevel.displayName,
                  record.level.displayName, record.performanceCount)
        }

        return willLevel
    }

    // MARK: - Dream Selection

    /// Selects a behavior for dream replay, weighted by mastery.
    /// Only mastered (tier 3+) behaviors are eligible.
    func selectDreamBehavior() -> String? {
        let eligible = records.values.filter { $0.level.dreamEligible }
        guard !eligible.isEmpty else { return nil }

        // Weight by mastery level: Signature = 3x, Mastered = 1x
        var weightedPool: [(String, Double)] = eligible.map { record in
            let weight = record.level == .signature ? 3.0 : 1.0
            return (record.behaviorName, weight)
        }
        weightedPool.sort { $0.1 > $1.1 }

        let totalWeight = weightedPool.reduce(0.0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<totalWeight)
        for (name, weight) in weightedPool {
            roll -= weight
            if roll <= 0 { return name }
        }
        return weightedPool.first?.0
    }

    // MARK: - Bulk Load

    /// Loads mastery records from SQLite data.
    /// Called on daemon startup.
    func loadRecords(_ data: [(name: String, count: Int,
                                lastPerformed: Date?, fumbles: Int)]) {
        records.removeAll()
        for entry in data {
            records[entry.name] = MasteryRecord(
                behaviorName: entry.name,
                performanceCount: entry.count,
                lastPerformedAt: entry.lastPerformed,
                totalFumbles: entry.fumbles
            )
        }
        NSLog("[Pushling/Mastery] Loaded %d mastery records", records.count)
    }

    /// Removes a mastery record (when behavior is deleted).
    func removeRecord(for behaviorName: String) {
        records.removeValue(forKey: behaviorName)
    }

    // MARK: - Statistics

    /// Total number of taught behaviors being tracked.
    var totalBehaviors: Int { records.count }

    /// Behaviors at each mastery tier.
    var tierCounts: [MasteryLevel: Int] {
        var counts: [MasteryLevel: Int] = [:]
        for level in MasteryLevel.allCases {
            counts[level] = records.values.filter { $0.level == level }.count
        }
        return counts
    }

    /// Recent performances for a specific behavior.
    func recentPerformances(for behaviorName: String,
                             limit: Int = 10) -> [PerformanceLogEntry] {
        return recentPerformances
            .filter { $0.behaviorName == behaviorName }
            .suffix(limit)
            .reversed()
    }
}
