// SkillStats.swift — Living developer skill stats that grow from observed behavior
//
// 6 stats derived from commit and hook events. Four decay with inactivity
// (debugging, patience, chaos, speed). Two only grow (wisdom, snark).
// Rarity floor sets the minimum each stat can decay to.
//
// SkillStatEngine is a static enum — no stored state, operates on an inout SkillStats.

import Foundation

// MARK: - SkillStats

/// The 6 developer skill stats carried by the creature.
/// Clamped to [rarityFloor, 100] for decayable stats, [rarityFloor, 100] for grow-only.
struct SkillStats {
    var debugging: Int = 10
    var patience:  Int = 10
    var chaos:     Int = 10
    var wisdom:    Int = 10
    var snark:     Int = 10
    var speed:     Int = 10
}

// MARK: - SkillStatEngine

/// Static engine for reading, writing, and evolving SkillStats.
/// All mutations are applied to an inout SkillStats and callers persist via save().
enum SkillStatEngine {

    // MARK: - SQLite Persistence

    /// Load skill stats from the creature table.
    /// Returns default stats (all 10) if the row is missing.
    static func load(from db: DatabaseManager) -> SkillStats {
        let rows = (try? db.query(
            """
            SELECT stat_debugging, stat_patience, stat_chaos,
                   stat_wisdom, stat_snark, stat_speed
            FROM creature WHERE id = 1
            """
        )) ?? []

        guard let row = rows.first else { return SkillStats() }

        return SkillStats(
            debugging: (row["stat_debugging"] as? Int) ?? 10,
            patience:  (row["stat_patience"]  as? Int) ?? 10,
            chaos:     (row["stat_chaos"]      as? Int) ?? 10,
            wisdom:    (row["stat_wisdom"]     as? Int) ?? 10,
            snark:     (row["stat_snark"]      as? Int) ?? 10,
            speed:     (row["stat_speed"]      as? Int) ?? 10
        )
    }

    /// Persist skill stats to the creature table (async-friendly: caller wraps in transaction if needed).
    static func save(_ stats: SkillStats, to db: DatabaseManager) {
        do {
            try db.execute(
                """
                UPDATE creature SET
                    stat_debugging = ?, stat_patience = ?, stat_chaos = ?,
                    stat_wisdom = ?, stat_snark = ?, stat_speed = ?
                WHERE id = 1
                """,
                arguments: [
                    stats.debugging, stats.patience, stats.chaos,
                    stats.wisdom, stats.snark, stats.speed
                ]
            )
        } catch {
            NSLog("[Pushling/SkillStats] Failed to save: %@", "\(error)")
        }
    }

    // MARK: - Commit Event Processing

    /// Process a commit event and grow the appropriate stats.
    ///
    /// - Parameters:
    ///   - stats: Current stats (modified in place).
    ///   - commit: Commit data dictionary (same shape as HookEventProcessor passes to onCommitReceived).
    ///   - rarityFloor: Minimum value from RarityTier.statFloor — growth is bounded by cap(100),
    ///     but floor only matters for decay; included here for future extension.
    ///   - previousCommitTime: Time of the most recent prior commit (for quick-fix detection).
    static func processCommitEvent(stats: inout SkillStats,
                                   commit: [String: Any],
                                   rarityFloor: Int,
                                   previousCommitTime: Date? = nil) {
        let message      = commit["message"]       as? String ?? ""
        let linesAdded   = commit["lines_added"]   as? Int    ?? 0
        let linesRemoved = commit["lines_removed"] as? Int    ?? 0
        let isForcePush  = commit["is_force_push"] as? Bool   ?? false
        let isRevert     = commit["is_revert"]     as? Bool   ?? false
        let commitTime   = commit["timestamp"]     as? Date   ?? Date()
        let lower        = message.lowercased()

        // Speed: every commit moves the needle
        grow(&stats.speed, by: 1)

        // Debugging: quick commit after a tool failure suggests a debugging session.
        // Also: short time since previous commit in general (< 10 min)
        if let prev = previousCommitTime {
            let gap = commitTime.timeIntervalSince(prev)
            if gap < 600 {
                grow(&stats.debugging, by: 2)
            }
        }

        // Patience: thoughtful commit messages (> 30 chars)
        if message.count > 30 {
            grow(&stats.patience, by: 1)
        }

        // Chaos: force push — reckless energy
        if isForcePush {
            grow(&stats.chaos, by: 2)
        }

        // Chaos: merge conflict keywords in message
        if lower.contains("conflict") || lower.contains("merge conflict") {
            grow(&stats.chaos, by: 1)
        }

        // Chaos: late-night commit (hour 22-04)
        let hour = Calendar.current.component(.hour, from: commitTime)
        if hour >= 22 || hour <= 4 {
            grow(&stats.chaos, by: 1)
        }

        // Chaos: revert commit
        if isRevert || lower.hasPrefix("revert") {
            grow(&stats.chaos, by: 1)
            grow(&stats.snark, by: 1)   // reverting is a form of editorial judgment
        }

        // Wisdom: good message length signals thoughtfulness
        if message.count > 30 {
            grow(&stats.wisdom, by: 1)
        }

        // Wisdom: commit contains test work
        if lower.contains("test") || lower.hasPrefix("test") {
            grow(&stats.wisdom, by: 1)
        }

        // Snark: large deletion relative to addition (more deleted than added × 2)
        if linesRemoved > linesAdded * 2 && linesRemoved > 10 {
            grow(&stats.snark, by: 1)
        }
    }

    // MARK: - Hook Event Processing

    /// Process a hook event and grow the appropriate stats.
    ///
    /// - Parameters:
    ///   - stats: Current stats (modified in place).
    ///   - type: The hook type that fired.
    ///   - data: Event data dictionary from the feed file.
    ///   - rarityFloor: Minimum value — used here only for future guard logic.
    ///   - lastToolUseWasFailure: True if the immediately preceding PostToolUse was a failure.
    ///     A success-after-failure awards bonus debugging XP.
    static func processHookEvent(stats: inout SkillStats,
                                 type: HookEventType,
                                 data: [String: Any],
                                 rarityFloor: Int,
                                 lastToolUseWasFailure: Bool = false) {
        switch type {
        case .sessionStart:
            // Long or returning session implies patience
            break

        case .sessionEnd:
            // Calculate session length from data if present
            let durationSeconds = data["duration_s"] as? Int ?? 0
            if durationSeconds >= 1800 {  // 30+ minutes
                grow(&stats.patience, by: 1)
            }

        case .postToolUse:
            let success = data["success"] as? Bool ?? true
            if success && lastToolUseWasFailure {
                // Debugging bonus: recovered from a failure
                grow(&stats.debugging, by: 2)
            } else if !success {
                // Failure alone: +1 debugging for trying
                grow(&stats.debugging, by: 1)
            }

        case .userPromptSubmit:
            // Long prompts suggest patience on both ends
            let length = data["prompt_length"] as? Int ?? 0
            if length > 500 {
                grow(&stats.patience, by: 1)
            }

        case .subagentStart:
            // Spawning parallel agents = ambitious, slightly chaotic
            let count = data["subagent_count"] as? Int ?? 1
            if count >= 3 {
                grow(&stats.chaos, by: 1)
            }

        case .subagentStop, .postCompact:
            break
        }
    }

    // MARK: - Daily Decay

    /// Apply inactivity decay to the 4 decayable stats.
    /// Decay = floor(0.5 * daysSinceLastActivity) per stat, minimum = rarityFloor.
    /// Wisdom and snark never decay.
    ///
    /// - Parameters:
    ///   - stats: Current stats (modified in place).
    ///   - daysSinceLastActivity: Days elapsed since last commit or session.
    ///   - rarityFloor: Minimum value these stats can reach.
    static func applyDailyDecay(stats: inout SkillStats,
                                daysSinceLastActivity: Int,
                                rarityFloor: Int) {
        guard daysSinceLastActivity > 0 else { return }
        let decayAmount = Int(Double(daysSinceLastActivity) * 0.5)
        guard decayAmount > 0 else { return }

        stats.debugging = max(rarityFloor, stats.debugging - decayAmount)
        stats.patience  = max(rarityFloor, stats.patience  - decayAmount)
        stats.chaos     = max(rarityFloor, stats.chaos     - decayAmount)
        stats.speed     = max(rarityFloor, stats.speed     - decayAmount)
        // wisdom and snark: no decay — only grow
    }

    // MARK: - Egg-Stage Initialization

    /// Compute initial stats from accumulated egg data.
    /// Called once at hatch, before any live events are processed.
    ///
    /// - Parameters:
    ///   - accumulator: The EggAccumulator populated during the egg stage.
    ///   - rarityFloor: Sets the minimum starting value for each stat.
    /// - Returns: A SkillStats populated with initial values.
    static func computeInitialStats(from accumulator: EggAccumulator,
                                    rarityFloor: Int) -> SkillStats {
        let commitCount  = accumulator.commitCount
        let timestamps   = accumulator.commitTimestamps
        let totalAdded   = accumulator.totalLinesAdded
        let totalRemoved = accumulator.totalLinesRemoved
        let totalMsg     = accumulator.totalMessageLength
        let avgMsgLen    = commitCount > 0
            ? Double(totalMsg) / Double(commitCount) : 0.0

        // Speed: more commits during egg = faster reflexes from the start
        let speedBonus = min(5, commitCount)
        let speed = rarityFloor + speedBonus

        // Wisdom: good average message length suggests thoughtfulness
        let wisdomBonus = avgMsgLen > 30 ? 3 : 0
        let wisdom = rarityFloor + wisdomBonus

        // Debugging: clustering of commits (short intervals = quick iteration)
        let debuggingBonus: Int
        if timestamps.count >= 2 {
            let intervals = zip(timestamps, timestamps.dropFirst())
                .map { $1.timeIntervalSince($0) }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            // avg interval < 5 min = active debugger
            debuggingBonus = avgInterval < 300 ? 3 : (avgInterval < 900 ? 1 : 0)
        } else {
            debuggingBonus = 0
        }
        let debugging = rarityFloor + debuggingBonus

        // Patience: session duration proxy — spread timestamps imply longer sessions
        let patienceBonus: Int
        if let first = timestamps.first, let last = timestamps.last {
            let span = last.timeIntervalSince(first)
            // > 30 minutes of activity
            patienceBonus = span > 1800 ? 2 : 0
        } else {
            patienceBonus = 0
        }
        let patience = rarityFloor + patienceBonus

        // Chaos: late-night commits in egg data
        let lateNightCount = timestamps.filter {
            let h = Calendar.current.component(.hour, from: $0)
            return h >= 22 || h <= 4
        }.count
        let chaosBonus = min(5, lateNightCount)
        let chaos = rarityFloor + chaosBonus

        // Snark: net deletion ratio
        let snarkBonus = (totalRemoved > totalAdded * 2 && totalRemoved > 10) ? 2 : 0
        let snark = rarityFloor + snarkBonus

        return SkillStats(
            debugging: min(100, debugging),
            patience:  min(100, patience),
            chaos:     min(100, chaos),
            wisdom:    min(100, wisdom),
            snark:     min(100, snark),
            speed:     min(100, speed)
        )
    }

    // MARK: - Private Helpers

    /// Grow a stat by `amount`, capped at 100.
    private static func grow(_ stat: inout Int, by amount: Int) {
        stat = min(100, stat + amount)
    }
}
