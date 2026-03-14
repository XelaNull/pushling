// MilestoneTracker.swift — Track touches, check milestones, gate gestures
// In-memory counters flush to SQLite every 30 seconds and on termination.
// Milestones: first_touch(1), finger_trail(25), petting(50),
// laser_pointer(100), belly_rub(250), pre_contact_purr(500),
// touch_mastery(1000). Plus first_mini_game and pet_streak_7.

import Foundation

// MARK: - Milestone ID

/// All touch-related milestone identifiers.
enum MilestoneID: String, CaseIterable {
    case firstTouch = "first_touch"
    case fingerTrail = "finger_trail"
    case petting = "petting"
    case laserPointer = "laser_pointer"
    case firstMiniGame = "first_mini_game"
    case bellyRub = "belly_rub"
    case preContactPurr = "pre_contact_purr"
    case touchMastery = "touch_mastery"
    case gentleWake = "gentle_wake"

    /// Touch count threshold (nil means other condition).
    var touchThreshold: Int? {
        switch self {
        case .firstTouch:      return 1
        case .fingerTrail:     return 25
        case .petting:         return 50
        case .laserPointer:    return 100
        case .bellyRub:        return 250
        case .preContactPurr:  return 500
        case .touchMastery:    return 1000
        case .firstMiniGame:   return nil   // First game completion
        case .gentleWake:      return nil   // First wake boop
        }
    }
}

// MARK: - Touch Stats (In-Memory)

/// In-memory touch statistics. Flushed to SQLite periodically.
struct TouchStats {
    var totalTouches: Int = 0
    var taps: Int = 0
    var doubleTaps: Int = 0
    var tripleTaps: Int = 0
    var longPresses: Int = 0
    var sustainedTouches: Int = 0
    var drags: Int = 0
    var pettingStrokes: Int = 0
    var flicks: Int = 0
    var rapidTaps: Int = 0
    var boops: Int = 0
    var bellyRubs: Int = 0
    var handFeeds: Int = 0
    var laserPointerSeconds: Double = 0
    var dailyInteractionStreak: Int = 0
    var lastInteractionDate: String?  // ISO8601 date string
}

// MARK: - Milestone Tracker

/// Tracks all touch interactions, manages milestone unlocks, and gates
/// gesture availability. In-memory counters with periodic SQLite flush.
final class MilestoneTracker {

    // MARK: - Constants

    /// Flush interval for writing stats to SQLite.
    private static let flushInterval: TimeInterval = 30.0

    // MARK: - State

    /// Current in-memory touch statistics.
    private(set) var stats = TouchStats()

    /// Set of unlocked milestone IDs (for fast lookup).
    private(set) var unlockedMilestones: Set<String> = []

    /// Time since last SQLite flush.
    private var timeSinceFlush: TimeInterval = 0

    /// Whether stats have been modified since last flush.
    private var isDirty = false

    /// Database manager reference for persistence.
    private weak var db: DatabaseManager?

    /// Callback when a milestone is newly unlocked.
    var onMilestoneUnlocked: ((MilestoneID) -> Void)?

    // MARK: - Init

    init(db: DatabaseManager? = nil) {
        self.db = db
        loadFromDatabase()
    }

    // MARK: - Gesture Gating

    /// Returns whether a milestone-gated gesture is unlocked.
    func isUnlocked(_ milestone: MilestoneID) -> Bool {
        unlockedMilestones.contains(milestone.rawValue)
    }

    /// Returns the particle multiplier (1.0 normal, 2.0 at touch_mastery).
    var particleMultiplier: Double {
        isUnlocked(.touchMastery) ? 2.0 : 1.0
    }

    // MARK: - Record Gesture

    /// Records a gesture event. Increments appropriate counters
    /// and checks milestones immediately.
    func recordGesture(_ type: GestureType) {
        stats.totalTouches += 1
        isDirty = true

        switch type {
        case .tap:             stats.taps += 1
        case .doubleTap:       stats.doubleTaps += 1
        case .tripleTap:       stats.tripleTaps += 1
        case .longPress:       stats.longPresses += 1
        case .sustainedTouch:  stats.sustainedTouches += 1
        case .drag, .slowDrag: stats.drags += 1
        case .pettingStroke:   stats.pettingStrokes += 1
        case .flick:           stats.flicks += 1
        case .rapidTaps:       stats.rapidTaps += 1
        case .multiFingerTwo, .multiFingerThree: break  // Counted via sub-gesture
        }

        updateDailyStreak()
        checkMilestones()
    }

    /// Records a special interaction type not covered by GestureType.
    func recordSpecial(_ type: SpecialInteraction) {
        isDirty = true
        switch type {
        case .boop:         stats.boops += 1
        case .bellyRub:     stats.bellyRubs += 1
        case .handFeed:     stats.handFeeds += 1
        case .miniGameComplete:
            checkMilestone(.firstMiniGame)
        case .gentleWake:
            checkMilestone(.gentleWake)
        }
        stats.totalTouches += 1
        checkMilestones()
    }

    /// Records laser pointer active time.
    func recordLaserPointerTime(_ seconds: Double) {
        stats.laserPointerSeconds += seconds
        isDirty = true
    }

    /// Special interaction types not covered by GestureType.
    enum SpecialInteraction {
        case boop
        case bellyRub
        case handFeed
        case miniGameComplete
        case gentleWake
    }

    // MARK: - Milestone Checking

    private func checkMilestones() {
        for milestone in MilestoneID.allCases {
            guard !isUnlocked(milestone) else { continue }
            if let threshold = milestone.touchThreshold,
               stats.totalTouches >= threshold {
                unlockMilestone(milestone)
            }
        }
    }

    private func checkMilestone(_ milestone: MilestoneID) {
        guard !isUnlocked(milestone) else { return }
        unlockMilestone(milestone)
    }

    private func unlockMilestone(_ milestone: MilestoneID) {
        unlockedMilestones.insert(milestone.rawValue)
        persistMilestoneUnlock(milestone)
        onMilestoneUnlocked?(milestone)
        NSLog("[Pushling/Milestone] UNLOCKED: %@ (total touches: %d)",
              milestone.rawValue, stats.totalTouches)
    }

    // MARK: - Daily Streak

    private func updateDailyStreak() {
        let today = todayDateString()

        if stats.lastInteractionDate == today {
            // Already counted today
            return
        }

        if let lastDate = stats.lastInteractionDate {
            let yesterday = yesterdayDateString()
            if lastDate == yesterday {
                // Continue streak
                stats.dailyInteractionStreak += 1
            } else {
                // Streak broken
                stats.dailyInteractionStreak = 1
            }
        } else {
            stats.dailyInteractionStreak = 1
        }

        stats.lastInteractionDate = today
    }

    // MARK: - Per-Frame Update

    /// Called each frame. Handles periodic SQLite flush.
    func update(deltaTime: TimeInterval) {
        timeSinceFlush += deltaTime
        if timeSinceFlush >= Self.flushInterval && isDirty {
            timeSinceFlush = 0
            flushToDatabase()
        }
    }

    // MARK: - Database Persistence

    /// Loads stats and milestone state from SQLite.
    private func loadFromDatabase() {
        guard let db = db else { return }

        // Load touch stats from creature table (touch_count)
        do {
            let rows = try db.query(
                "SELECT touch_count FROM creature WHERE id = 1;"
            )
            if let row = rows.first, let count = row["touch_count"] as? Int {
                stats.totalTouches = count
            }
        } catch {
            NSLog("[Pushling/Milestone] Failed to load touch count: %@",
                  "\(error)")
        }

        // Load unlocked milestones
        do {
            let rows = try db.query(
                "SELECT id FROM milestones WHERE earned_at IS NOT NULL AND category = 'touch';"
            )
            for row in rows {
                if let id = row["id"] as? String {
                    unlockedMilestones.insert(id)
                }
            }
        } catch {
            NSLog("[Pushling/Milestone] Failed to load milestones: %@",
                  "\(error)")
        }

        NSLog("[Pushling/Milestone] Loaded: %d touches, %d milestones unlocked",
              stats.totalTouches, unlockedMilestones.count)
    }

    /// Writes in-memory stats to SQLite.
    func flushToDatabase() {
        guard isDirty, let db = db else { return }
        isDirty = false

        db.performWriteAsync({ [stats] in
            try db.execute(
                "UPDATE creature SET touch_count = ? WHERE id = 1;",
                arguments: [stats.totalTouches]
            )
        }) { error in
            if let error = error {
                NSLog("[Pushling/Milestone] Flush failed: %@", "\(error)")
            }
        }
    }

    private func persistMilestoneUnlock(_ milestone: MilestoneID) {
        guard let db = db else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        db.performWriteAsync({
            try db.execute("""
                UPDATE milestones SET earned_at = ?, ceremony_played = 0
                WHERE id = ? AND earned_at IS NULL;
                """,
                arguments: [now, milestone.rawValue]
            )
        })
    }

    // MARK: - Date Helpers

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func yesterdayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: Date()
        )!
        return formatter.string(from: yesterday)
    }
}
