// NurtureDecayManager.swift — Mastery-based decay tiers for nurture data
// All nurture data (habits, preferences, quirks, routines) has strength 0.0-1.0.
// Decay rate depends on reinforcement count.
//
// Tiers:
//   Fresh (0-2 reinforcements): 0.02/day, floor 0.0 — forgotten in ~25 days
//   Established (3-9):          0.01/day, floor 0.2 — vaguely remembered
//   Rooted (10-24):             0.005/day, floor 0.4 — reliable
//   Permanent (25+):            0.001/day, floor 0.6 — core identity
//
// Decay calculated on startup and every 6 hours during runtime.

import Foundation

// MARK: - Decay Tier

/// Mastery-based decay tier.
enum DecayTier: String {
    case fresh        // 0-2 reinforcements
    case established  // 3-9
    case rooted       // 10-24
    case permanent    // 25+

    /// Daily decay rate.
    var decayRate: Double {
        switch self {
        case .fresh:       return 0.02
        case .established: return 0.01
        case .rooted:      return 0.005
        case .permanent:   return 0.001
        }
    }

    /// Minimum strength value (floor).
    var floor: Double {
        switch self {
        case .fresh:       return 0.0
        case .established: return 0.2
        case .rooted:      return 0.4
        case .permanent:   return 0.6
        }
    }

    /// Days to reach floor from strength 0.5.
    var daysToFloor: Int {
        switch self {
        case .fresh:       return 25
        case .established: return 30
        case .rooted:      return 20  // From 0.5 to 0.4
        case .permanent:   return 400 // Effectively permanent
        }
    }

    init(reinforcementCount: Int) {
        switch reinforcementCount {
        case 0...2:   self = .fresh
        case 3...9:   self = .established
        case 10...24: self = .rooted
        default:      self = .permanent
        }
    }
}

// MARK: - Decayable Item

/// Protocol for items that can decay.
protocol Decayable {
    var name: String { get }
    var strength: Double { get }
    var reinforcementCount: Int { get }
}

// MARK: - Decay Result

/// The result of applying decay to an item.
struct DecayResult {
    let name: String
    let previousStrength: Double
    let newStrength: Double
    let tier: DecayTier
    let crossedThreshold: Bool  // Crossed a meaningful boundary
    let forgotten: Bool         // Dropped below 0.2
}

// MARK: - NurtureDecayManager

/// Manages strength decay for all nurture data.
final class NurtureDecayManager {

    // MARK: - Configuration

    /// Hours between automatic decay calculations.
    private static let decayIntervalHours: Double = 6.0

    // MARK: - State

    /// When decay was last calculated.
    private var lastDecayAt: Date

    /// Callback for strength updates.
    var onStrengthUpdate: ((String, Double) -> Void)?

    /// Callback when an item is forgotten (drops below 0.2).
    var onForgotten: ((String) -> Void)?

    // MARK: - Init

    init() {
        self.lastDecayAt = Date()
    }

    // MARK: - Decay Calculation

    /// Calculates decay for a list of items over the elapsed time.
    /// Call on startup and periodically (every 6 hours).
    ///
    /// - Parameters:
    ///   - items: All decayable items (habits, prefs, quirks, routines).
    ///   - since: The reference date for elapsed time calculation.
    /// - Returns: Array of decay results for items that changed.
    func calculateDecay<T: Decayable>(
        items: [T],
        since: Date? = nil
    ) -> [DecayResult] {
        let referenceDate = since ?? lastDecayAt
        let now = Date()
        let daysSinceLastDecay = now.timeIntervalSince(referenceDate) / 86400.0

        guard daysSinceLastDecay > 0 else { return [] }

        var results: [DecayResult] = []

        for item in items {
            let tier = DecayTier(reinforcementCount: item.reinforcementCount)
            let decay = tier.decayRate * daysSinceLastDecay
            let previousStrength = item.strength
            let newStrength = Swift.max(previousStrength - decay, tier.floor)

            // Only report if strength actually changed
            guard abs(newStrength - previousStrength) > 0.001 else { continue }

            let forgotten = previousStrength >= 0.2 && newStrength < 0.2
            let crossedThreshold = strengthThreshold(previousStrength)
                != strengthThreshold(newStrength)

            let result = DecayResult(
                name: item.name,
                previousStrength: previousStrength,
                newStrength: newStrength,
                tier: tier,
                crossedThreshold: crossedThreshold,
                forgotten: forgotten
            )
            results.append(result)

            // Notify
            onStrengthUpdate?(item.name, newStrength)
            if forgotten {
                onForgotten?(item.name)
            }
        }

        lastDecayAt = now

        if !results.isEmpty {
            let forgottenCount = results.filter(\.forgotten).count
            NSLog("[Pushling/Decay] Processed %d items over %.2f days. "
                  + "%d changed, %d forgotten.",
                  items.count, daysSinceLastDecay,
                  results.count, forgottenCount)
        }

        return results
    }

    /// Returns the decay tier for a given reinforcement count.
    func tier(for reinforcementCount: Int) -> DecayTier {
        return DecayTier(reinforcementCount: reinforcementCount)
    }

    /// Projects what the strength will be in N days.
    func projectStrength(current: Double,
                          reinforcementCount: Int,
                          daysAhead: Double) -> Double {
        let tier = DecayTier(reinforcementCount: reinforcementCount)
        let projected = current - (tier.decayRate * daysAhead)
        return Swift.max(projected, tier.floor)
    }

    /// Returns the number of days until an item reaches a threshold.
    func daysUntilThreshold(current: Double,
                             reinforcementCount: Int,
                             threshold: Double) -> Double? {
        let tier = DecayTier(reinforcementCount: reinforcementCount)
        guard current > threshold && threshold >= tier.floor else { return nil }
        return (current - threshold) / tier.decayRate
    }

    // MARK: - Reinforcement

    /// Applies reinforcement to a strength value.
    /// Returns the new strength (capped at 1.0).
    static func reinforce(currentStrength: Double,
                           amount: Double = 0.15) -> Double {
        return Swift.min(currentStrength + amount, 1.0)
    }

    // MARK: - Threshold Detection

    /// Returns a categorical threshold for a strength value.
    private func strengthThreshold(_ strength: Double) -> Int {
        switch strength {
        case ..<0.2:  return 0  // Forgotten
        case ..<0.4:  return 1  // Weak
        case ..<0.6:  return 2  // Normal
        case ..<0.8:  return 3  // Strong
        default:      return 4  // Excellent
        }
    }

    // MARK: - Status

    /// Returns a summary of decay warnings for SessionStart injection.
    func decayWarnings<T: Decayable>(items: [T]) -> [String] {
        var warnings: [String] = []
        for item in items {
            if item.strength < 0.3 && item.strength >= 0.2 {
                let tier = DecayTier(reinforcementCount: item.reinforcementCount)
                let daysLeft = (item.strength - tier.floor) / tier.decayRate
                warnings.append("'\(item.name)' at \(String(format: "%.2f", item.strength)) "
                    + "strength — \(Int(daysLeft)) days until floor")
            }
        }
        return warnings
    }

    /// Whether it's time to run periodic decay.
    func shouldRunDecay() -> Bool {
        let hoursSinceLast = Date().timeIntervalSince(lastDecayAt) / 3600.0
        return hoursSinceLast >= Self.decayIntervalHours
    }

    /// Resets the last decay timestamp.
    func reset() {
        lastDecayAt = Date()
    }
}
