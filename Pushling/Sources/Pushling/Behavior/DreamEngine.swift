// DreamEngine.swift — Dream state machine for autonomous deep sleep
// Manages a 3-phase dream cycle: settling -> dreaming -> waking.
// During dreaming, analyzes recent journal entries to produce personality
// drift and a dream journal entry.
// Lives inside AutonomousLayer — owned and updated by AutonomousLayer+Dreaming.

import Foundation

// MARK: - Dream Phase

/// The sub-phases of a single dream cycle.
enum DreamPhase {
    case notReady
    case settling(elapsed: TimeInterval)
    case dreaming(elapsed: TimeInterval, twitchTimer: TimeInterval)
    case waking(elapsed: TimeInterval)
    case complete
}

// MARK: - Dream Output

/// Per-frame output from DreamEngine to AutonomousLayer.
struct DreamOutput {
    var eyeState: String            // "open", "closing", "closed"
    var earState: String            // "neutral", "droop", "flat"
    var tailState: String           // "sway", "wrap"
    var pawState: String            // "ground", "tuck"
    var bodyState: String           // "stand", "sleep_curl"
    var breathPeriodOverride: Double? // nil = normal; slow = ~5.0s
    var whiskerTwitch: Bool         // brief twitch during REM
    var phase: DreamPhase
}

// MARK: - Dream Engine

/// Manages the settling → dreaming → waking state machine.
/// Set `db` before first use. `checkGates` determines eligibility.
/// Call `update(deltaTime:)` each frame when the AutonomousLayer is in .dreaming.
final class DreamEngine {

    // MARK: - Dependencies

    /// Read-only database reference for journal queries and dream persistence.
    weak var db: DatabaseManager?

    // MARK: - Timing Constants

    private static let settlingDuration: TimeInterval  = 10.0
    private static let wakingDuration: TimeInterval    = 5.0
    private static let dreamingMinDuration: TimeInterval = 30.0
    private static let dreamingMaxDuration: TimeInterval = 60.0
    private static let twitchInterval: TimeInterval    = 10.0
    private static let cooldownHours: Double           = 4.0
    private static let minUnprocessedEntries: Int      = 20
    private static let maxEnergyForDream: Double       = 25.0
    private static let maxPersonalityDriftPerAxis: Double = 0.02
    private static let journalWindowHours: Double      = 24.0

    // MARK: - State

    private(set) var phase: DreamPhase = .notReady
    private var dreamingDuration: TimeInterval = 45.0
    private var computedDrift: Personality?
    private var dreamSummary: String = ""
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Journal Query Cache (avoid every-frame DB hits)

    private var cachedJournalCount: Int = 0
    private var journalCountRefreshTimer: TimeInterval = 0
    private static let journalRefreshInterval: TimeInterval = 30.0

    // MARK: - Gates

    /// Returns true if all 4 dream gates pass.
    /// Cheap gates first. The journal count gate is cached (refreshed every 30s
    /// by the AutonomousLayer's resting update, not this method itself).
    ///
    /// - Parameters:
    ///   - timePeriod: Current sky time period.
    ///   - emotionalEnergy: Current emotional energy (0-100).
    ///   - unprocessedJournalCount: Count from last DB check.
    ///   - lastDreamAt: ISO8601 string of last dream time, or nil.
    func checkGates(timePeriod: TimePeriod,
                    emotionalEnergy: Double,
                    unprocessedJournalCount: Int,
                    lastDreamAt: String?) -> Bool {
        // Gate 1: Time of day (free check)
        guard timePeriod == .lateNight || timePeriod == .deepNight else {
            return false
        }

        // Gate 2: Energy (free check)
        guard emotionalEnergy < Self.maxEnergyForDream else {
            return false
        }

        // Gate 3: Journal volume
        guard unprocessedJournalCount >= Self.minUnprocessedEntries else {
            return false
        }

        // Gate 4: Cooldown since last dream
        if let lastStr = lastDreamAt,
           let lastDate = ISO8601DateFormatter().date(from: lastStr) {
            let hoursSince = Date().timeIntervalSince(lastDate) / 3600.0
            guard hoursSince >= Self.cooldownHours else {
                return false
            }
        }
        // nil lastDreamAt means never dreamed — always passes cooldown

        return true
    }

    // MARK: - Journal Count Refresh

    /// Returns the cached journal entry count since lastDreamAt (or last 24h).
    /// Refreshes from DB on its own timer so the AutonomousLayer can pass
    /// this value into `checkGates` without a per-frame query.
    func refreshedJournalCount(lastDreamAt: String?,
                                deltaTime: TimeInterval) -> Int {
        journalCountRefreshTimer += deltaTime
        guard journalCountRefreshTimer >= Self.journalRefreshInterval else {
            return cachedJournalCount
        }
        journalCountRefreshTimer = 0
        cachedJournalCount = queryJournalCount(since: lastDreamAt)
        return cachedJournalCount
    }

    // MARK: - Lifecycle

    /// Begin a dream cycle. Must be called once when entering .dreaming state.
    func startDream() {
        dreamingDuration = TimeInterval.random(
            in: Self.dreamingMinDuration...Self.dreamingMaxDuration,
            using: &rng
        )
        computedDrift = nil
        dreamSummary = ""
        phase = .settling(elapsed: 0)
        NSLog("[Pushling/Dream] Dream started (dreamingDuration=%.1f)",
              dreamingDuration)
    }

    /// Called every frame while AutonomousLayer is in .dreaming state.
    /// Returns a DreamOutput describing how the creature should look this frame.
    /// Returns nil when the dream is complete (AutonomousLayer should transition out).
    func update(deltaTime: TimeInterval,
                currentPersonality: Personality) -> DreamOutput? {
        switch phase {
        case .notReady, .complete:
            return nil

        case .settling(let elapsed):
            let newElapsed = elapsed + deltaTime
            if newElapsed >= Self.settlingDuration {
                phase = .dreaming(elapsed: 0, twitchTimer: 0)
                // Compute personality drift now (once, at dream start)
                computedDrift = computePersonalityDrift(
                    currentPersonality: currentPersonality
                )
            } else {
                phase = .settling(elapsed: newElapsed)
            }
            let settleT = min(newElapsed / Self.settlingDuration, 1.0)
            return settlingOutput(progress: settleT)

        case .dreaming(let elapsed, let twitchTimer):
            let newElapsed = elapsed + deltaTime
            let newTwitchTimer = twitchTimer + deltaTime
            let isTwitching = newTwitchTimer.truncatingRemainder(
                dividingBy: Self.twitchInterval
            ) < 0.25

            if newElapsed >= dreamingDuration {
                phase = .waking(elapsed: 0)
            } else {
                phase = .dreaming(
                    elapsed: newElapsed,
                    twitchTimer: newTwitchTimer
                )
            }
            return dreamingOutput(twitching: isTwitching)

        case .waking(let elapsed):
            let newElapsed = elapsed + deltaTime
            if newElapsed >= Self.wakingDuration {
                phase = .complete
                persistDreamResult(personality: computedDrift)
                return nil
            } else {
                phase = .waking(elapsed: newElapsed)
            }
            let wakeT = min(newElapsed / Self.wakingDuration, 1.0)
            return wakingOutput(progress: wakeT)
        }
    }

    // MARK: - Personality Drift

    /// Analyzes recent journal entries and computes personality axis drift.
    /// Each axis can shift at most `maxPersonalityDriftPerAxis` per dream.
    func computePersonalityDrift(currentPersonality: Personality) -> Personality {
        guard let db = db else { return currentPersonality }

        let windowStart = ISO8601DateFormatter().string(
            from: Date(timeIntervalSinceNow: -Self.journalWindowHours * 3600)
        )

        let rows = (try? db.query(
            "SELECT type, summary FROM journal WHERE timestamp > ? ORDER BY timestamp DESC LIMIT 200",
            arguments: [windowStart]
        )) ?? []

        var commitCount = 0
        var touchCount = 0
        var hookErrorCount = 0
        var languageCounts: [String: Int] = [:]

        for row in rows {
            let type = (row["type"] as? String) ?? ""
            let summary = (row["summary"] as? String) ?? ""

            switch type {
            case "commit":
                commitCount += 1
                // Extract language hint from summary (simple heuristic)
                let lower = summary.lowercased()
                for lang in ["swift", "python", "typescript", "rust", "go",
                             "javascript", "java", "kotlin", "ruby", "php",
                             "lua", "haskell", "elixir"] {
                    if lower.contains(lang) {
                        languageCounts[lang, default: 0] += 1
                    }
                }
            case "touch":
                touchCount += 1
            case "hook":
                if summary.lowercased().contains("error")
                    || summary.lowercased().contains("fail") {
                    hookErrorCount += 1
                }
            default:
                break
            }
        }

        let total = max(rows.count, 1)
        var drift = currentPersonality

        // High commit density → energy drift upward
        if commitCount > 30 {
            let factor = min(Double(commitCount) / 50.0, 1.0)
            drift.energy += factor * Self.maxPersonalityDriftPerAxis
        }

        // Many touches → contentment proxy: verbosity drift up (more chatty)
        if touchCount > 20 {
            let factor = min(Double(touchCount) / 40.0, 1.0)
            drift.verbosity += factor * Self.maxPersonalityDriftPerAxis
        }

        // Error streaks → satisfaction pressure → discipline drift down
        if hookErrorCount > 5 {
            let factor = min(Double(hookErrorCount) / 15.0, 1.0)
            drift.discipline -= factor * Self.maxPersonalityDriftPerAxis
        }

        // High commit ratio relative to session → focus drift up
        let commitRatio = Double(commitCount) / Double(total)
        if commitRatio > 0.4 {
            drift.focus += (commitRatio - 0.4) * Self.maxPersonalityDriftPerAxis * 2
        }

        drift.clampAxes()

        // Build dream pattern for journal summary
        let dominantPattern = resolveDreamPattern(
            commitCount: commitCount,
            touchCount: touchCount,
            hookErrorCount: hookErrorCount,
            languageCounts: languageCounts,
            totalCount: total
        )
        dreamSummary = DreamTemplates.generate(pattern: dominantPattern)

        NSLog("[Pushling/Dream] Drift computed — energy:%.3f vb:%.3f "
              + "focus:%.3f disc:%.3f summary: %@",
              drift.energy - currentPersonality.energy,
              drift.verbosity - currentPersonality.verbosity,
              drift.focus - currentPersonality.focus,
              drift.discipline - currentPersonality.discipline,
              dreamSummary)

        return drift
    }

    // MARK: - Dream Pattern Resolution

    private func resolveDreamPattern(commitCount: Int,
                                      touchCount: Int,
                                      hookErrorCount: Int,
                                      languageCounts: [String: Int],
                                      totalCount: Int) -> DreamPattern {
        // Late-night check via current time
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 5 { return .lateNightCoding }

        if hookErrorCount > 5 { return .errorStreak }

        if touchCount > 20 { return .touchHeavy }

        if commitCount > 40 {
            let top = languageCounts.max { $0.value < $1.value }
            return .manyCommits(language: top?.key ?? "code")
        }

        if languageCounts.count > 4 { return .diverseLanguages }

        if commitCount > 20 { return .streakBuilding }

        if totalCount < 5 { return .noActivity }

        if totalCount < 15 { return .quiet }

        return .generic
    }

    // MARK: - Persistence

    private func persistDreamResult(personality: Personality?) {
        guard let db = db else { return }

        let now = ISO8601DateFormatter().string(from: Date())
        let summary = dreamSummary.isEmpty
            ? DreamTemplates.generate(pattern: .generic)
            : dreamSummary

        db.performWriteAsync({
            // 1. Update last_dream_at and increment dream_count
            try db.execute(
                """
                UPDATE creature
                SET last_dream_at = ?,
                    dream_count = dream_count + 1
                WHERE id = 1
                """,
                arguments: [now]
            )

            // 2. Insert dream journal entry
            try db.execute(
                "INSERT INTO journal (type, summary, timestamp) VALUES (?, ?, ?)",
                arguments: ["dream", summary, now]
            )

            NSLog("[Pushling/Dream] Persisted dream — summary: %@", summary)
        })

        // 3. Persist personality drift (if any computed)
        if let driftedPersonality = personality {
            PersonalityPersistence.save(driftedPersonality, to: db)
        }
    }

    // MARK: - DB Queries

    private func queryJournalCount(since lastDreamAt: String?) -> Int {
        guard let db = db else { return 0 }
        let since: String
        if let last = lastDreamAt {
            since = last
        } else {
            // No prior dream — count last 24 hours
            since = ISO8601DateFormatter().string(
                from: Date(timeIntervalSinceNow: -Self.journalWindowHours * 3600)
            )
        }
        return (try? db.queryScalarInt(
            "SELECT COUNT(*) FROM journal WHERE timestamp > ?",
            arguments: [since]
        )) ?? 0
    }

    // MARK: - Frame Output Helpers

    private func settlingOutput(progress: Double) -> DreamOutput {
        // Eyes closing and body curling as progress approaches 1.0
        let eyeState = progress > 0.5 ? "closed" : "closing"
        return DreamOutput(
            eyeState: eyeState,
            earState: progress > 0.3 ? "flat" : "droop",
            tailState: progress > 0.5 ? "wrap" : "sway",
            pawState: progress > 0.5 ? "tuck" : "ground",
            bodyState: progress > 0.6 ? "sleep_curl" : "stand",
            breathPeriodOverride: lerp(2.5, 5.0, progress),
            whiskerTwitch: false,
            phase: phase
        )
    }

    private func dreamingOutput(twitching: Bool) -> DreamOutput {
        DreamOutput(
            eyeState: "closed",
            earState: twitching ? "droop" : "flat",
            tailState: "wrap",
            pawState: "tuck",
            bodyState: "sleep_curl",
            breathPeriodOverride: 5.0,
            whiskerTwitch: twitching,
            phase: phase
        )
    }

    private func wakingOutput(progress: Double) -> DreamOutput {
        let eyeState = progress > 0.6 ? "open" : "closed"
        return DreamOutput(
            eyeState: eyeState,
            earState: progress > 0.7 ? "neutral" : "flat",
            tailState: progress > 0.8 ? "sway" : "wrap",
            pawState: progress > 0.8 ? "ground" : "tuck",
            bodyState: progress > 0.7 ? "stand" : "sleep_curl",
            breathPeriodOverride: lerp(5.0, 2.5, progress),
            whiskerTwitch: false,
            phase: phase
        )
    }
}
