// IdleRotationGovernor.swift — Controls taught behavior density in idle rotation
// Enforces: 80% pure cat behaviors, 20% taught/special.
// Maximum 3 taught behavior performances per hour.
// Emergency throttle: 3 within 10 minutes = suppress for 50 minutes.
// Taught behaviors never play back-to-back.
//
// Integrates with BehaviorSelector to gate taught behavior selection.

import Foundation

// MARK: - IdleRotationGovernor

/// Gates taught behavior selection to maintain the 80/20 cat-to-taught ratio.
/// The creature is a cat first, performer second.
final class IdleRotationGovernor {

    // MARK: - Configuration

    /// Maximum taught behavior performances per clock-hour.
    private static let maxPerHour = 3

    /// Emergency throttle: if this many fire within the burst window, suppress.
    private static let burstThreshold = 3

    /// Burst detection window in seconds (10 minutes).
    private static let burstWindowSeconds: TimeInterval = 600

    /// Suppression duration after burst (50 minutes in seconds).
    private static let burstSuppressionSeconds: TimeInterval = 3000

    /// Target ratio of taught behaviors (20%).
    private static let taughtRatio = 0.20

    // MARK: - State

    /// Timestamps of taught behavior performances in the current hour.
    private var hourlyPerformances: [TimeInterval] = []

    /// The clock-hour these performances belong to.
    private var currentHourKey: Int = -1

    /// Whether we're in burst suppression mode.
    private(set) var isBurstSuppressed = false

    /// When burst suppression ends.
    private var burstSuppressionEndTime: TimeInterval = 0

    /// Whether the last autonomous behavior was a taught behavior.
    private var lastWasTaught = false

    /// Total autonomous behaviors this hour (taught + cat).
    private var totalBehaviorsThisHour: Int = 0

    /// Taught behaviors this hour.
    private var taughtBehaviorsThisHour: Int = 0

    // MARK: - Gate Check

    /// Returns whether a taught behavior is currently allowed to play.
    /// This is the main gate method — call before selecting a taught behavior.
    ///
    /// - Parameter currentTime: Scene time.
    /// - Returns: Whether a taught behavior can play right now.
    func canPlayTaughtBehavior(currentTime: TimeInterval) -> Bool {
        // Reset hourly counters if hour changed
        refreshHour(currentTime: currentTime)

        // Rule 1: Never back-to-back
        guard !lastWasTaught else {
            return false
        }

        // Rule 2: Hourly cap
        guard taughtBehaviorsThisHour < Self.maxPerHour else {
            return false
        }

        // Rule 3: Burst suppression
        if isBurstSuppressed {
            if currentTime >= burstSuppressionEndTime {
                isBurstSuppressed = false
            } else {
                return false
            }
        }

        // Rule 4: Ratio enforcement (80/20)
        if totalBehaviorsThisHour > 4 {
            let currentRatio = Double(taughtBehaviorsThisHour)
                / Double(totalBehaviorsThisHour)
            if currentRatio >= Self.taughtRatio {
                return false
            }
        }

        return true
    }

    // MARK: - Recording

    /// Records that a taught behavior was performed.
    func recordTaughtPerformance(currentTime: TimeInterval) {
        refreshHour(currentTime: currentTime)

        taughtBehaviorsThisHour += 1
        totalBehaviorsThisHour += 1
        lastWasTaught = true
        hourlyPerformances.append(currentTime)

        // Burst detection
        checkBurstThrottle(currentTime: currentTime)

        NSLog("[Pushling/Governor] Taught behavior performed "
              + "(%d/%d this hour, ratio: %.0f%%)",
              taughtBehaviorsThisHour, Self.maxPerHour,
              taughtBehaviorsThisHour > 0
                ? Double(taughtBehaviorsThisHour)
                  / Double(totalBehaviorsThisHour) * 100
                : 0)
    }

    /// Records that a regular (cat) behavior was performed.
    func recordCatBehavior() {
        totalBehaviorsThisHour += 1
        lastWasTaught = false
    }

    // MARK: - Burst Detection

    /// Checks if 3 taught behaviors fired within 10 minutes.
    private func checkBurstThrottle(currentTime: TimeInterval) {
        // Filter to performances within the burst window
        let recentPerformances = hourlyPerformances.filter {
            currentTime - $0 <= Self.burstWindowSeconds
        }

        if recentPerformances.count >= Self.burstThreshold {
            isBurstSuppressed = true
            burstSuppressionEndTime = currentTime + Self.burstSuppressionSeconds

            NSLog("[Pushling/Governor] Burst detected: %d taught behaviors "
                  + "in %.0f minutes. Suppressing for %.0f minutes.",
                  recentPerformances.count,
                  Self.burstWindowSeconds / 60,
                  Self.burstSuppressionSeconds / 60)
        }
    }

    // MARK: - Hour Management

    /// Resets counters when the clock-hour changes.
    private func refreshHour(currentTime: TimeInterval) {
        let hourKey = Int(currentTime / 3600)
        if hourKey != currentHourKey {
            currentHourKey = hourKey
            hourlyPerformances.removeAll()
            taughtBehaviorsThisHour = 0
            totalBehaviorsThisHour = 0
            // Don't reset lastWasTaught — carries across hour boundaries
        }
    }

    // MARK: - Weight Modifier

    /// Returns a weight modifier for taught behaviors in the selection pool.
    /// Used to gradually decrease taught behavior probability as we approach
    /// the hourly cap.
    ///
    /// - Parameter currentTime: Scene time.
    /// - Returns: Weight multiplier (0.0 to 1.0).
    func taughtWeightModifier(currentTime: TimeInterval) -> Double {
        refreshHour(currentTime: currentTime)

        guard canPlayTaughtBehavior(currentTime: currentTime) else {
            return 0.0
        }

        // Scale weight down as we approach the cap
        let remaining = Self.maxPerHour - taughtBehaviorsThisHour
        switch remaining {
        case 3:  return 1.0
        case 2:  return 0.7
        case 1:  return 0.4
        default: return 0.0
        }
    }

    // MARK: - Status

    /// Returns a status summary for debugging / SessionStart injection.
    var statusSummary: String {
        let remaining = Self.maxPerHour - taughtBehaviorsThisHour
        var summary = "\(taughtBehaviorsThisHour)/\(Self.maxPerHour) taught this hour"
        if isBurstSuppressed {
            summary += " (burst suppressed)"
        }
        if remaining == 0 {
            summary += " (at cap)"
        }
        return summary
    }

    /// Resets all governor state.
    func reset() {
        hourlyPerformances.removeAll()
        currentHourKey = -1
        isBurstSuppressed = false
        burstSuppressionEndTime = 0
        lastWasTaught = false
        totalBehaviorsThisHour = 0
        taughtBehaviorsThisHour = 0
    }
}
