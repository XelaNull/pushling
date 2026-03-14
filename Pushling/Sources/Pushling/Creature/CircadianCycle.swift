// CircadianCycle.swift — Creature learns the developer's commit schedule
// Tracks commit timestamps over 14 days to build a commit-time histogram.
// Determines wake/sleep times. Default: 9AM wake, 6PM sleepy.
//
// The creature stirs 30 minutes before typical first commit.
// Gets sleepy 30 minutes after typical last commit.
// Out-of-schedule commits cause gradual circadian adjustment.

import Foundation

// MARK: - Circadian Phase

/// The creature's current circadian phase.
enum CircadianPhase: String {
    /// Creature is asleep.
    case sleeping

    /// Creature is waking up (30 min before first commit hour).
    case waking

    /// Creature is fully awake and active.
    case awake

    /// Creature is getting sleepy (30 min after last commit hour).
    case sleepy

    /// Creature is drowsy and about to sleep.
    case drowsy
}

// MARK: - Circadian Cycle

/// Tracks and learns the developer's commit schedule.
/// After 14 days of data, the schedule is locked (or slow-rolling average).
final class CircadianCycle {

    // MARK: - Constants

    /// Number of bins in the hourly histogram (24 hours).
    static let binCount = 24

    /// Number of days before the schedule "locks."
    static let learningPeriodDays = 14

    /// Minutes before first commit to start waking.
    static let wakeLeadMinutes = 30

    /// Minutes after last commit to start getting sleepy.
    static let sleepyLagMinutes = 30

    /// Minutes of idle past sleepy threshold before sleep triggers.
    static let sleepIdleMinutes = 10

    /// Default first commit hour (9 AM).
    static let defaultFirstHour = 9

    /// Default last commit hour (6 PM = 18).
    static let defaultLastHour = 18

    /// Circadian shift per out-of-schedule commit (in minutes).
    static let adjustmentMinutesPerCommit = 15

    // MARK: - State

    /// Hourly commit count histogram (24 bins, one per hour).
    private(set) var histogram: [Int]

    /// Total number of commit-days tracked.
    private(set) var daysTracked: Int

    /// Computed first commit hour (weighted).
    private(set) var firstCommitHour: Int

    /// Computed last commit hour (weighted).
    private(set) var lastCommitHour: Int

    /// Whether we're still in the learning period.
    var isLearning: Bool {
        daysTracked < Self.learningPeriodDays
    }

    // MARK: - Init

    init() {
        histogram = Array(repeating: 0, count: Self.binCount)
        daysTracked = 0
        firstCommitHour = Self.defaultFirstHour
        lastCommitHour = Self.defaultLastHour
    }

    /// Initialize from persisted data.
    init(histogram: [Int], daysTracked: Int) {
        self.histogram = histogram.count == Self.binCount
            ? histogram
            : Array(repeating: 0, count: Self.binCount)
        self.daysTracked = daysTracked
        self.firstCommitHour = Self.defaultFirstHour
        self.lastCommitHour = Self.defaultLastHour
        recompute()
    }

    // MARK: - Record Commits

    /// Record a commit timestamp.
    func recordCommit(at date: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        guard hour >= 0 && hour < Self.binCount else { return }

        histogram[hour] += 1
        recompute()
    }

    /// Record a batch of commit timestamps (e.g., from git history scan).
    func recordCommits(_ dates: [Date]) {
        let calendar = Calendar.current
        for date in dates {
            let hour = calendar.component(.hour, from: date)
            if hour >= 0 && hour < Self.binCount {
                histogram[hour] += 1
            }
        }
        recompute()
    }

    /// Increment the day counter (call once per calendar day).
    func recordNewDay() {
        daysTracked += 1
    }

    // MARK: - Phase Detection

    /// Determine the current circadian phase.
    /// - Parameter currentDate: The current date/time.
    /// - Returns: The creature's circadian phase.
    func currentPhase(at currentDate: Date = Date()) -> CircadianPhase {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)
        let minute = calendar.component(.minute, from: currentDate)
        let totalMinutes = hour * 60 + minute

        let wakeMinutes = firstCommitHour * 60 - Self.wakeLeadMinutes
        let sleepyMinutes = lastCommitHour * 60 + Self.sleepyLagMinutes
        let drowsyMinutes = sleepyMinutes + Self.sleepIdleMinutes

        // Handle wrap-around (e.g., wake at 23:30 for midnight committer)
        let normalizedMinutes: Int
        if wakeMinutes < 0 {
            normalizedMinutes = (totalMinutes + 1440) % 1440
        } else {
            normalizedMinutes = totalMinutes
        }

        let normalizedWake = (wakeMinutes + 1440) % 1440
        let normalizedSleepy = (sleepyMinutes + 1440) % 1440
        let normalizedDrowsy = (drowsyMinutes + 1440) % 1440

        // Simple linear schedule (most developers have day-aligned schedules)
        if normalizedWake < normalizedSleepy {
            // Normal schedule (e.g., wake 8:30, sleepy 18:30)
            if normalizedMinutes < normalizedWake {
                return .sleeping
            } else if normalizedMinutes < normalizedWake + 30 {
                return .waking
            } else if normalizedMinutes < normalizedSleepy {
                return .awake
            } else if normalizedMinutes < normalizedDrowsy {
                return .sleepy
            } else {
                return .drowsy
            }
        } else {
            // Night-owl schedule (e.g., wake 20:00, sleepy 06:00)
            if normalizedMinutes >= normalizedWake
                && normalizedMinutes < normalizedWake + 30 {
                return .waking
            } else if normalizedMinutes >= normalizedWake + 30
                || normalizedMinutes < normalizedSleepy {
                return .awake
            } else if normalizedMinutes < normalizedDrowsy {
                return .sleepy
            } else if normalizedMinutes < normalizedWake {
                return .sleeping
            }
            return .sleeping
        }
    }

    /// Whether the creature should be sleeping right now.
    func shouldBeSleeping(at date: Date = Date()) -> Bool {
        let phase = currentPhase(at: date)
        return phase == .sleeping || phase == .drowsy
    }

    /// How many minutes until the creature should wake.
    func minutesUntilWake(from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute

        let wakeMinutes = firstCommitHour * 60 - Self.wakeLeadMinutes
        let normalizedWake = (wakeMinutes + 1440) % 1440

        if currentMinutes < normalizedWake {
            return normalizedWake - currentMinutes
        } else {
            return (1440 - currentMinutes) + normalizedWake
        }
    }

    // MARK: - Out-of-Schedule Handling

    /// Adjust the circadian schedule for an out-of-schedule commit.
    /// Shifts the schedule by 15 minutes toward the unusual hour.
    func adjustForUnusualCommit(at date: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        let phase = currentPhase(at: date)
        guard phase == .sleeping || phase == .drowsy else {
            return  // In-schedule commit — no adjustment needed
        }

        // Determine which end to adjust
        let distToFirst = circularDistance(from: hour, to: firstCommitHour)
        let distToLast = circularDistance(from: hour, to: lastCommitHour)

        if distToFirst <= distToLast {
            // Closer to the morning boundary — shift wake earlier
            firstCommitHour = (firstCommitHour - 1 + 24) % 24
        } else {
            // Closer to the evening boundary — shift sleep later
            lastCommitHour = (lastCommitHour + 1) % 24
        }

        NSLog("[Pushling/Circadian] Adjusted schedule for %02d:00 commit "
              + "-> wake: %02d:00, sleep: %02d:00",
              hour, firstCommitHour, lastCommitHour)
    }

    // MARK: - Recomputation

    /// Recompute first and last commit hours from the histogram.
    private func recompute() {
        let totalCommits = histogram.reduce(0, +)
        guard totalCommits > 0 else {
            firstCommitHour = Self.defaultFirstHour
            lastCommitHour = Self.defaultLastHour
            return
        }

        // Find the first and last hours with significant commits
        // "Significant" = at least 5% of the total
        let threshold = max(1, Int(Double(totalCommits) * 0.05))

        var first = Self.defaultFirstHour
        var last = Self.defaultLastHour

        // Scan forward from 0 to find first significant hour
        for h in 0..<Self.binCount {
            if histogram[h] >= threshold {
                first = h
                break
            }
        }

        // Scan backward from 23 to find last significant hour
        for h in stride(from: Self.binCount - 1, through: 0, by: -1) {
            if histogram[h] >= threshold {
                last = h
                break
            }
        }

        // Sanity: if first >= last, use defaults
        if first >= last {
            firstCommitHour = Self.defaultFirstHour
            lastCommitHour = Self.defaultLastHour
        } else {
            firstCommitHour = first
            lastCommitHour = last
        }
    }

    // MARK: - Helpers

    /// Circular distance between two hours on a 24-hour clock.
    private func circularDistance(from a: Int, to b: Int) -> Int {
        let forward = ((b - a) + 24) % 24
        let backward = ((a - b) + 24) % 24
        return min(forward, backward)
    }

    // MARK: - Persistence

    /// Serialize the histogram as a JSON string for SQLite storage.
    func histogramJSON() -> String {
        guard let data = try? JSONEncoder().encode(histogram),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    /// Deserialize histogram from JSON string.
    static func histogramFrom(json: String) -> [Int] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return Array(repeating: 0, count: binCount)
        }
        return arr
    }

    // MARK: - Wake / Sleep Sequence Parameters

    /// Parameters for the wake sequence animation.
    struct WakeSequence {
        /// Total duration of the wake sequence in seconds.
        let duration: TimeInterval

        /// Whether to play a yawn.
        let includeYawn: Bool

        /// Whether to include kneading before standing.
        let includeKnead: Bool

        /// Description for logging.
        let description: String
    }

    /// Get the wake sequence based on circadian phase.
    func wakeSequence(at date: Date = Date()) -> WakeSequence {
        let phase = currentPhase(at: date)
        switch phase {
        case .sleeping:
            // Woken from deep sleep — full wake sequence
            return WakeSequence(
                duration: 5.0,
                includeYawn: true,
                includeKnead: true,
                description: "deep sleep wake"
            )
        case .waking:
            // Already stirring — shorter
            return WakeSequence(
                duration: 3.0,
                includeYawn: true,
                includeKnead: false,
                description: "natural wake"
            )
        case .sleepy, .drowsy:
            // Was getting sleepy, woken by event — groggy
            return WakeSequence(
                duration: 4.0,
                includeYawn: true,
                includeKnead: false,
                description: "groggy wake"
            )
        case .awake:
            // Already awake — no wake sequence needed
            return WakeSequence(
                duration: 0,
                includeYawn: false,
                includeKnead: false,
                description: "already awake"
            )
        }
    }
}
