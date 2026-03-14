// PetStreak.swift — Daily interaction streak tracking
// A "pet day" = at least 1 touch in a calendar day. Streak increments at
// midnight if the day has a touch. Resets to 0 if a full day is missed.
// 7-day streak = creature brings a daily gift (cosmetic world item).

import Foundation

// MARK: - Pet Streak

/// Tracks daily interaction streaks and triggers the 7-day gift behavior.
final class PetStreak {

    // MARK: - Constants

    /// Days needed for the gift-giving behavior to activate.
    static let giftStreakThreshold = 7

    /// Pool of gift items the creature can bring.
    static let giftPool: [String] = [
        "tiny_flower", "colored_pebble", "shiny_button", "miniature_star",
        "acorn", "seashell", "glass_bead", "feather", "crystal_shard",
        "mushroom", "leaf", "pine_cone", "thimble", "marble", "compass",
        "tiny_key", "pocket_watch", "prism", "snowflake_ornament",
        "dried_flower"
    ]

    // MARK: - State

    /// Current streak count (consecutive days with interaction).
    private(set) var streakDays: Int = 0

    /// The last date a touch interaction occurred (YYYY-MM-DD).
    private(set) var lastInteractionDate: String?

    /// Whether the daily gift has been given today.
    private(set) var dailyGiftGiven = false

    /// Whether the 7-day streak has been achieved.
    var hasGiftStreak: Bool { streakDays >= Self.giftStreakThreshold }

    /// Callback when a gift should be given.
    var onGiftReady: ((String) -> Void)?

    /// Database reference for persistence.
    private weak var db: DatabaseManager?

    // MARK: - Init

    init(db: DatabaseManager? = nil) {
        self.db = db
        loadFromDatabase()
    }

    // MARK: - Record Interaction

    /// Records that a touch interaction happened today.
    /// Updates the streak accordingly.
    func recordInteraction() {
        let today = Self.todayString()

        guard lastInteractionDate != today else {
            // Already recorded today
            return
        }

        if let lastDate = lastInteractionDate {
            let yesterday = Self.yesterdayString()
            if lastDate == yesterday {
                streakDays += 1
            } else {
                // Streak broken — start fresh
                streakDays = 1
            }
        } else {
            streakDays = 1
        }

        lastInteractionDate = today
        dailyGiftGiven = false  // Reset for new day

        saveToDatabase()

        NSLog("[Pushling/Streak] Interaction recorded. Streak: %d days",
              streakDays)
    }

    // MARK: - Daily Gift

    /// Checks if a daily gift should be given (first touch of the day
    /// when streak >= 7). Returns the gift item name or nil.
    func checkDailyGift() -> String? {
        guard hasGiftStreak && !dailyGiftGiven else { return nil }

        dailyGiftGiven = true

        // Pick a random gift from the pool
        let gift = Self.giftPool.randomElement() ?? "tiny_flower"
        onGiftReady?(gift)

        NSLog("[Pushling/Streak] Daily gift: %@ (streak: %d)", gift, streakDays)
        return gift
    }

    // MARK: - Midnight Check

    /// Called periodically to check if midnight has passed.
    /// If a full day was missed, the streak resets.
    func midnightCheck() {
        guard let lastDate = lastInteractionDate else { return }

        let today = Self.todayString()
        let yesterday = Self.yesterdayString()

        // If last interaction was before yesterday, streak is broken
        if lastDate != today && lastDate != yesterday {
            let oldStreak = streakDays
            streakDays = 0
            saveToDatabase()
            NSLog("[Pushling/Streak] Streak broken (was %d days). "
                  + "Last interaction: %@", oldStreak, lastDate)
        }
    }

    // MARK: - Database

    private func loadFromDatabase() {
        guard let db = db else { return }

        do {
            let rows = try db.query(
                "SELECT streak_days, streak_last_date FROM creature WHERE id = 1;"
            )
            if let row = rows.first {
                if let days = row["streak_days"] as? Int {
                    streakDays = days
                }
                if let date = row["streak_last_date"] as? String {
                    lastInteractionDate = date
                }
            }
        } catch {
            NSLog("[Pushling/Streak] Failed to load: %@", "\(error)")
        }
    }

    private func saveToDatabase() {
        guard let db = db else { return }

        db.performWriteAsync({ [streakDays, lastInteractionDate] in
            try db.execute("""
                UPDATE creature SET streak_days = ?, streak_last_date = ?
                WHERE id = 1;
                """,
                arguments: [streakDays, lastInteractionDate as Any]
            )
        })
    }

    // MARK: - Date Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    static func yesterdayString() -> String {
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: Date()
        )!
        return dateFormatter.string(from: yesterday)
    }
}
