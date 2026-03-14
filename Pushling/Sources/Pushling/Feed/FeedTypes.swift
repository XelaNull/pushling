// FeedTypes.swift — Types and utilities for the Pushling feed system
//
// Defines event types, rate limiter, and batch tracker used by
// HookEventProcessor. Extracted to keep each file under 500 lines.

import Foundation

// MARK: - Hook Event Types

/// Represents a parsed hook event from the feed directory.
enum HookEventType: String, CaseIterable {
    case sessionStart    = "SessionStart"
    case sessionEnd      = "SessionEnd"
    case postToolUse     = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case subagentStart   = "SubagentStart"
    case subagentStop    = "SubagentStop"
    case postCompact     = "PostCompact"
}

/// Represents a parsed feed file of any type.
enum FeedEvent {
    case hook(type: HookEventType, data: [String: Any], timestamp: String)
    case commit(data: [String: Any])
    case unknown(rawType: String)
}

// MARK: - Commit Rate Limiter

/// Tracks commit rate for XP adjustment.
/// First 5/min: full XP. 6-20: 50%. 21+: 10%.
final class CommitRateLimiter {

    private var recentCommitTimes: [Date] = []
    private let window: TimeInterval = 60.0  // 1 minute window

    /// Returns the XP multiplier for the next commit (1.0, 0.5, or 0.1).
    func multiplierForNextCommit() -> Double {
        pruneExpired()
        let count = recentCommitTimes.count

        if count < 5 {
            return 1.0
        } else if count < 20 {
            return 0.5
        } else {
            return 0.1
        }
    }

    /// Record that a commit was processed.
    func recordCommit() {
        pruneExpired()
        recentCommitTimes.append(Date())
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-window)
        recentCommitTimes.removeAll { $0 < cutoff }
    }
}

// MARK: - Hook Batch Tracker

/// Tracks rapid hook events for batching into "watching Claude work" animation.
/// If >3 hook events arrive within 2 seconds, switch to sustained animation.
final class HookBatchTracker {

    private var recentHookTimes: [Date] = []
    private let batchWindow: TimeInterval = 2.0
    private let batchThreshold = 3

    /// Whether we're currently in batch/burst mode.
    private(set) var isInBurstMode = false

    /// Record a hook event and return whether it should be individually animated
    /// (true) or suppressed in favor of the sustained "watching" animation (false).
    func recordHook() -> Bool {
        let now = Date()
        pruneExpired(now: now)
        recentHookTimes.append(now)

        if recentHookTimes.count >= batchThreshold {
            if !isInBurstMode {
                isInBurstMode = true
                NSLog("[Pushling/Feed] Entering hook burst mode (%d hooks in %.1fs)",
                      recentHookTimes.count, batchWindow)
            }
            return false  // Suppress individual animation
        }

        isInBurstMode = false
        return true  // Animate individually
    }

    /// Call periodically to check if burst mode should end.
    func checkBurstEnd() {
        pruneExpired(now: Date())
        if recentHookTimes.count < batchThreshold {
            if isInBurstMode {
                isInBurstMode = false
                NSLog("[Pushling/Feed] Exiting hook burst mode")
            }
        }
    }

    private func pruneExpired(now: Date) {
        let cutoff = now.addingTimeInterval(-batchWindow)
        recentHookTimes.removeAll { $0 < cutoff }
    }
}

// MARK: - Commit Classifier

/// Classifies a commit by its message prefix using conventional commit patterns.
enum CommitClassifier {

    /// Classify a commit by its message, merge status, and revert status.
    static func classify(message: String, isMerge: Bool, isRevert: Bool) -> String {
        if isMerge { return "merge" }
        if isRevert { return "revert" }

        let lower = message.lowercased()

        // Conventional commit prefixes
        if lower.hasPrefix("feat")     { return "feature" }
        if lower.hasPrefix("fix")      { return "bugfix" }
        if lower.hasPrefix("refactor") { return "refactor" }
        if lower.hasPrefix("test")     { return "test" }
        if lower.hasPrefix("docs")     { return "docs" }
        if lower.hasPrefix("style")    { return "style" }
        if lower.hasPrefix("chore")    { return "chore" }
        if lower.hasPrefix("ci")       { return "ci" }
        if lower.hasPrefix("perf")     { return "perf" }
        if lower.hasPrefix("build")    { return "build" }

        // Heuristics for non-conventional commits
        if lower.contains("fix") || lower.contains("bug") { return "bugfix" }
        if lower.contains("add") || lower.contains("new") { return "feature" }
        if lower.contains("refactor") || lower.contains("clean") { return "refactor" }
        if lower.contains("test") { return "test" }
        if lower.contains("doc") || lower.contains("readme") { return "docs" }

        return "general"
    }
}
