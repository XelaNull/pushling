// MutationSystem.swift — 10 hidden mutation badges
// Each badge has a detection condition, permanent visual effect,
// and behavioral modifier. Badges are earned once and never revoked.
//
// Detection runs on every commit eat (for commit-related badges)
// and on crash recovery (for Nine Lives).
//
// Badge check is efficient: maintains unearned set, pre-filters
// before running expensive queries.

import Foundation

// MARK: - Mutation Badge

/// The 10 mutation badges.
enum MutationBadge: String, CaseIterable {
    case nocturne       // 50+ commits between midnight and 5AM
    case polyglot       // 8+ unique extensions in a 7-day window
    case marathon       // 14-day consecutive commit streak
    case archaeologist  // Commit touches files 2+ years old
    case guardian       // 20+ commits with test files
    case swarm          // 30+ commits in a single day
    case whisperer      // All commit messages >50 chars for 7 consecutive days
    case firstLight     // Any commit before 6 AM
    case nineLives      // Daemon recovered from crash 9 times
    case bilingual      // 2+ language categories each with 30%+ in 30-day window

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .nocturne:      return "Nocturne"
        case .polyglot:      return "Polyglot"
        case .marathon:      return "Marathon"
        case .archaeologist: return "Archaeologist"
        case .guardian:      return "Guardian"
        case .swarm:         return "Swarm"
        case .whisperer:     return "Whisperer"
        case .firstLight:    return "First Light"
        case .nineLives:     return "Nine Lives"
        case .bilingual:     return "Bilingual"
        }
    }

    /// Description of the visual effect when earned.
    var visualEffect: String {
        switch self {
        case .nocturne:      return "Moon glow aura at night"
        case .polyglot:      return "Color-shifting fur, heterochromatic eyes"
        case .marathon:       return "Flame trail when walking"
        case .archaeologist: return "Tiny pickaxe mark on left ear"
        case .guardian:      return "Shield flash on commit eat"
        case .swarm:         return "Buzzing particles orbit creature"
        case .whisperer:     return "Scroll mark on right side"
        case .firstLight:    return "Sunrise mark on forehead"
        case .nineLives:     return "Faint halo above head"
        case .bilingual:     return "Split-color tail"
        }
    }

    /// Description of the behavioral modifier.
    var behaviorModifier: String {
        switch self {
        case .nocturne:      return "Faster movement after dark (1.2x 10PM-6AM)"
        case .polyglot:      return "Heterochromatic eyes"
        case .marathon:       return "Permanent subtle trail, slightly faster walk"
        case .archaeologist: return "More frequent dig surprises"
        case .guardian:      return "Brief shield aura on commit eat, +5% test XP"
        case .swarm:         return "24-hour electric aura, wired expression"
        case .whisperer:     return "Quotes commit messages 2x more often"
        case .firstLight:    return "Enthusiastic morning routine, dawn glow"
        case .nineLives:     return "Dramatic resurrection on crash recovery"
        case .bilingual:     return "Alternates visual style between languages"
        }
    }
}

// MARK: - Badge Progress

/// Tracks progress toward earning a badge.
struct BadgeProgress {
    let badge: MutationBadge
    let currentValue: Int
    let targetValue: Int
    let description: String

    var percentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(targetValue)) * 100
    }

    var isComplete: Bool {
        currentValue >= targetValue
    }
}

// MARK: - Mutation System

final class MutationSystem {

    // MARK: - State

    /// Badges that have been earned (loaded from database on init).
    private(set) var earnedBadges: Set<MutationBadge> = []

    /// When each badge was earned.
    private(set) var earnedAt: [MutationBadge: Date] = [:]

    /// Unearned badges (for efficient checking).
    private var unearnedBadges: Set<MutationBadge> = []

    /// Crash recovery count (for Nine Lives check).
    private(set) var crashRecoveryCount: Int = 0

    // MARK: - Callbacks

    /// Called when a new badge is earned.
    var onBadgeEarned: ((_ badge: MutationBadge, _ isFirst: Bool) -> Void)?

    // MARK: - Initialization

    init() {
        unearnedBadges = Set(MutationBadge.allCases)
    }

    /// Load earned badges from database.
    func loadEarnedBadges(_ badges: [(MutationBadge, Date)],
                           crashRecoveries: Int) {
        for (badge, date) in badges {
            earnedBadges.insert(badge)
            earnedAt[badge] = date
            unearnedBadges.remove(badge)
        }
        crashRecoveryCount = crashRecoveries
        NSLog("[Pushling/Mutation] Loaded %d earned badges, %d unearned",
              earnedBadges.count, unearnedBadges.count)
    }

    // MARK: - Check on Commit

    /// Run badge checks after a commit is eaten.
    /// Called with commit data for efficient pre-filtering.
    func checkOnCommit(commitData: CommitBadgeData,
                        queryProvider: MutationQueryProvider) {
        guard !unearnedBadges.isEmpty else { return }

        for badge in unearnedBadges {
            // Pre-filter: skip expensive checks if basic conditions aren't close
            guard shouldCheck(badge: badge, commitData: commitData) else {
                continue
            }

            if checkBadgeCondition(badge: badge, commitData: commitData,
                                    queryProvider: queryProvider) {
                awardBadge(badge)
            }
        }
    }

    // MARK: - Check on Crash Recovery

    /// Run Nine Lives check after crash recovery.
    func checkOnCrashRecovery(totalRecoveries: Int) {
        crashRecoveryCount = totalRecoveries
        guard unearnedBadges.contains(.nineLives) else { return }
        if totalRecoveries >= 9 {
            awardBadge(.nineLives)
        }
    }

    // MARK: - Pre-Filter

    /// Quick pre-filter to avoid expensive queries.
    private func shouldCheck(badge: MutationBadge,
                              commitData: CommitBadgeData) -> Bool {
        switch badge {
        case .nocturne:
            // Only check if this commit is between midnight and 5AM
            let hour = Calendar.current.component(.hour, from: commitData.timestamp)
            return hour >= 0 && hour < 5

        case .polyglot:
            // Only check if commit has file extensions
            return !commitData.languages.isEmpty

        case .marathon:
            // Only check if streak is approaching 14
            return commitData.currentStreakDays >= 10

        case .archaeologist:
            // Check on any commit (can't pre-filter cheaply)
            return true

        case .guardian:
            // Only check if commit has test files
            return commitData.hasTestFiles

        case .swarm:
            // Only check if daily count is approaching 30
            return commitData.todayCommitCount >= 20

        case .whisperer:
            // Only check if message is >50 chars
            return commitData.messageLength > 50

        case .firstLight:
            // Only check if commit is before 6 AM
            let hour = Calendar.current.component(.hour, from: commitData.timestamp)
            return hour < 6

        case .nineLives:
            // Never checked on commit — checked on crash recovery
            return false

        case .bilingual:
            // Only check if commit has language data
            return !commitData.languages.isEmpty
        }
    }

    // MARK: - Badge Condition Checks

    private func checkBadgeCondition(
        badge: MutationBadge,
        commitData: CommitBadgeData,
        queryProvider: MutationQueryProvider
    ) -> Bool {
        switch badge {
        case .nocturne:
            let count = queryProvider.midnightCommitCount()
            return count >= 50

        case .polyglot:
            let count = queryProvider.uniqueExtensionsIn7Days()
            return count >= 8

        case .marathon:
            return commitData.currentStreakDays >= 14

        case .archaeologist:
            return commitData.touchesOldFiles

        case .guardian:
            let count = queryProvider.testCommitCount()
            return count >= 20

        case .swarm:
            return commitData.todayCommitCount >= 30

        case .whisperer:
            return queryProvider.longMessagesConsecutiveDays() >= 7

        case .firstLight:
            // Any single commit before 6 AM earns it
            let hour = Calendar.current.component(.hour, from: commitData.timestamp)
            return hour < 6

        case .nineLives:
            return crashRecoveryCount >= 9

        case .bilingual:
            return queryProvider.isBilingual30Days()
        }
    }

    // MARK: - Award Badge

    private func awardBadge(_ badge: MutationBadge) {
        guard !earnedBadges.contains(badge) else { return }

        let now = Date()
        earnedBadges.insert(badge)
        earnedAt[badge] = now
        unearnedBadges.remove(badge)

        let isFirst = earnedBadges.count == 1

        NSLog("[Pushling/Mutation] Badge earned: %@ (total: %d)",
              badge.displayName, earnedBadges.count)

        onBadgeEarned?(badge, isFirst)
    }

    // MARK: - Progress Query

    /// Returns progress toward all unearned badges.
    func progress(commitData: CommitBadgeData,
                  queryProvider: MutationQueryProvider) -> [BadgeProgress] {
        return MutationBadge.allCases.map { badge in
            if earnedBadges.contains(badge) {
                return BadgeProgress(
                    badge: badge, currentValue: 1, targetValue: 1,
                    description: "Earned!"
                )
            }

            let (current, target, desc) = progressForBadge(
                badge, commitData: commitData, queryProvider: queryProvider
            )
            return BadgeProgress(
                badge: badge, currentValue: current, targetValue: target,
                description: desc
            )
        }
    }

    private func progressForBadge(
        _ badge: MutationBadge,
        commitData: CommitBadgeData,
        queryProvider: MutationQueryProvider
    ) -> (Int, Int, String) {
        switch badge {
        case .nocturne:
            let count = queryProvider.midnightCommitCount()
            return (count, 50, "\(count)/50 midnight commits")
        case .polyglot:
            let count = queryProvider.uniqueExtensionsIn7Days()
            return (count, 8, "\(count)/8 unique extensions in 7 days")
        case .marathon:
            return (commitData.currentStreakDays, 14,
                    "\(commitData.currentStreakDays)/14 day streak")
        case .archaeologist:
            return (commitData.touchesOldFiles ? 1 : 0, 1,
                    "Touch files 2+ years old")
        case .guardian:
            let count = queryProvider.testCommitCount()
            return (count, 20, "\(count)/20 test commits")
        case .swarm:
            return (commitData.todayCommitCount, 30,
                    "\(commitData.todayCommitCount)/30 commits today")
        case .whisperer:
            let days = queryProvider.longMessagesConsecutiveDays()
            return (days, 7, "\(days)/7 consecutive days of detailed messages")
        case .firstLight:
            return (0, 1, "Commit before 6 AM")
        case .nineLives:
            return (crashRecoveryCount, 9,
                    "\(crashRecoveryCount)/9 crash recoveries")
        case .bilingual:
            return (queryProvider.isBilingual30Days() ? 1 : 0, 1,
                    "2+ languages each >30% in 30 days")
        }
    }

    // MARK: - Behavioral Modifiers

    /// Returns the speed multiplier based on earned badges and time.
    func speedMultiplier(hour: Int) -> CGFloat {
        var mult: CGFloat = 1.0
        if earnedBadges.contains(.nocturne) && (hour >= 22 || hour < 6) {
            mult *= 1.2
        }
        if earnedBadges.contains(.marathon) {
            mult *= 1.05
        }
        return mult
    }

    /// Returns XP bonus multiplier for test commits.
    func testXPBonus() -> Double {
        earnedBadges.contains(.guardian) ? 1.05 : 1.0
    }

    /// Returns whether commit message quoting frequency should be doubled.
    var doubleQuoteFrequency: Bool {
        earnedBadges.contains(.whisperer)
    }
}

// MARK: - Commit Badge Data

/// Pre-computed commit data for efficient badge checking.
struct CommitBadgeData {
    let timestamp: Date
    let languages: [String]
    let messageLength: Int
    let hasTestFiles: Bool
    let touchesOldFiles: Bool
    let currentStreakDays: Int
    let todayCommitCount: Int
}

// MARK: - Mutation Query Provider Protocol

/// Protocol for database queries needed by mutation checks.
/// Implemented by StateCoordinator or DatabaseManager.
protocol MutationQueryProvider {
    /// Count of commits between midnight and 5 AM (all time).
    func midnightCommitCount() -> Int

    /// Count of unique file extensions in the last 7 days.
    func uniqueExtensionsIn7Days() -> Int

    /// Count of commits where primary files are tests.
    func testCommitCount() -> Int

    /// Consecutive days where all commit messages are >50 chars.
    func longMessagesConsecutiveDays() -> Int

    /// Whether at least 2 language categories each have 30%+
    /// of commits in a 30-day window.
    func isBilingual30Days() -> Bool
}
