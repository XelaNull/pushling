// XPCalculator.swift — XP formula for commit eating
//
// Formula: (base + lines + message + breadth) * streak * fallow * rate_limit
//
// Components:
//   base:    Always 1
//   lines:   min(5, totalLines / 20)
//   message: 2 if message > 20 chars AND not lazy
//   breadth: 1 if filesChanged >= 3
//   streak:  1.0 + min(1.0, streakDays / 10.0) -> 1.0x to 2.0x
//   fallow:  Based on idle time since last commit -> 1.0x to 2.0x
//   rate:    Based on commits per minute -> 1.0x to 0.1x
//
// Minimum XP: 1 (base is never reduced below 1).
// Maximum theoretical: (1+5+2+1) * 2.0 * 2.0 * 1.0 = 36 per commit.

import Foundation

// MARK: - XP Result

/// The result of an XP calculation.
struct XPResult {
    /// Total XP awarded.
    let xp: Int

    /// Breakdown for display/logging.
    let base: Int
    let linesBonus: Int
    let messageBonus: Int
    let breadthBonus: Int
    let streakMultiplier: Double
    let fallowMultiplier: Double
    let rateLimitFactor: Double

    /// Formatted display string for the XP float.
    /// Shows the multiplier if fallow > 1.0x.
    var displayString: String {
        if fallowMultiplier > 1.0 {
            return "+\(xp) (x\(String(format: "%.1f", fallowMultiplier)))"
        }
        if rateLimitFactor < 1.0 {
            return "+\(xp) (batch)"
        }
        return "+\(xp)"
    }
}

// MARK: - XP Calculator

/// Deterministic XP calculation engine.
/// All methods are static — no instance state.
enum XPCalculator {

    // MARK: - Calculate

    /// Calculate XP for a commit.
    /// - Parameters:
    ///   - commit: The parsed commit data.
    ///   - streakDays: Current consecutive day streak.
    ///   - lastCommitTime: When the last commit was eaten.
    ///   - rateLimitFactor: From CommitRateLimiter (1.0, 0.5, or 0.1).
    /// - Returns: XP result with breakdown.
    static func calculate(
        commit: CommitData,
        streakDays: Int,
        lastCommitTime: Date?,
        rateLimitFactor: Double
    ) -> XPResult {
        // Base: always 1
        let base = 1

        // Lines: min(5, totalLines / 20)
        let linesBonus = min(5, commit.totalLines / 20)

        // Message: 2 if > 20 chars and not lazy
        let messageBonus: Int
        if commit.message.count > 20
            && !CommitTypeDetector.isLazyMessage(commit.message) {
            messageBonus = 2
        } else {
            messageBonus = 0
        }

        // Breadth: 1 if 3+ files changed
        let breadthBonus = commit.filesChanged >= 3 ? 1 : 0

        // Streak multiplier: 1.0 + min(1.0, streakDays / 10.0)
        let streakMultiplier = 1.0 + min(1.0, Double(streakDays) / 10.0)

        // Fallow multiplier: based on idle time
        let fallowMultiplier = calculateFallowMultiplier(
            lastCommitTime: lastCommitTime
        )

        // Raw XP before multipliers
        let rawXP = base + linesBonus + messageBonus + breadthBonus

        // Apply multipliers
        let multipliedXP = Double(rawXP) * streakMultiplier
            * fallowMultiplier * rateLimitFactor

        // Floor with minimum of 1
        let finalXP = max(1, Int(multipliedXP.rounded()))

        return XPResult(
            xp: finalXP,
            base: base,
            linesBonus: linesBonus,
            messageBonus: messageBonus,
            breadthBonus: breadthBonus,
            streakMultiplier: streakMultiplier,
            fallowMultiplier: fallowMultiplier,
            rateLimitFactor: rateLimitFactor
        )
    }

    // MARK: - Fallow Multiplier

    /// Calculate the fallow field bonus multiplier.
    /// Longer idle times reward the return commit.
    static func calculateFallowMultiplier(
        lastCommitTime: Date?
    ) -> Double {
        guard let lastTime = lastCommitTime else {
            return 1.0  // No previous commit — no bonus
        }

        let idleMinutes = Date().timeIntervalSince(lastTime) / 60.0

        switch idleMinutes {
        case ..<30:           return 1.0     // <30 min
        case 30..<120:        return 1.25    // 30min-2hr
        case 120..<480:       return 1.5     // 2hr-8hr
        case 480..<1440:      return 1.75    // 8hr-24hr
        default:              return 2.0     // 24hr+ (cap)
        }
    }

    // MARK: - Streak Update

    /// Check if a commit extends the streak or starts a new one.
    /// - Parameters:
    ///   - currentStreak: Current streak day count.
    ///   - streakLastDate: Date string of last streak-counted commit.
    /// - Returns: Updated streak count and new date string.
    static func updateStreak(
        currentStreak: Int,
        streakLastDate: String?
    ) -> (newStreak: Int, newDate: String) {
        let today = todayString()
        let yesterday = yesterdayString()

        if streakLastDate == today {
            // Already counted today — no change
            return (currentStreak, today)
        } else if streakLastDate == yesterday {
            // Continuing the streak
            return (currentStreak + 1, today)
        } else {
            // Streak broken — start at 1
            return (1, today)
        }
    }

    // MARK: - Language Preference Drift

    /// Check if language preferences should shift (every 200 commits).
    /// - Parameter totalCommits: Total commits eaten by the creature.
    /// - Returns: True if it's time to recalculate preferences.
    static func shouldShiftLanguagePreference(
        totalCommits: Int
    ) -> Bool {
        return totalCommits > 0 && totalCommits % 200 == 0
    }

    // MARK: - Date Helpers

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func yesterdayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: Date()
        )!
        return formatter.string(from: yesterday)
    }
}
