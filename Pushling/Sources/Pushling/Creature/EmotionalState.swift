// EmotionalState.swift — 4 emotional axes that change within minutes/hours
// Unlike personality (drifts over weeks), emotions respond to events in real-time.
//
// Axes (all 0-100):
//   Satisfaction — commits boost, time decays (-1/3min)
//   Curiosity    — new repos/file types boost, repetition decreases
//   Contentment  — streaks/interactions boost, streak breaks decrease
//   Energy       — commits/dawn/touch boost, nighttime/sustained activity decrease
//
// Emotions decay toward neutral (50) over time when there's no input.
// Persisted to SQLite every 60 seconds (not every frame).

import Foundation

// MARK: - Emotional State

/// Real-time emotional state with per-frame decay and event-driven boosts.
final class EmotionalState {

    // MARK: - Axes

    /// 0-100. Increases with commits, decreases over time.
    private(set) var satisfaction: Double = 50.0

    /// 0-100. Increases with new repos/file types, decreases with repetition.
    private(set) var curiosity: Double = 50.0

    /// 0-100. Increases with streaks/interactions, decreases with streak breaks.
    private(set) var contentment: Double = 50.0

    /// 0-100. Follows circadian cycle + commit boosts.
    /// Distinct from personality Energy axis.
    private(set) var energy: Double = 50.0

    // MARK: - Decay Constants

    /// Satisfaction decays at -1 per 3 minutes = -1/180 per second.
    private static let satisfactionDecayPerSec: Double = 1.0 / 180.0

    /// Curiosity decays toward 50 at -1 per 5 minutes when idle.
    private static let curiosityDecayPerSec: Double = 1.0 / 300.0

    /// Contentment decays toward 50 at -1 per 10 minutes when idle.
    private static let contentmentDecayPerSec: Double = 1.0 / 600.0

    /// Energy nighttime decay: -0.5 per minute past 10PM = -0.5/60 per sec.
    private static let energyNightDecayPerSec: Double = 0.5 / 60.0

    /// Energy sustained activity decay: -1 per minute after 2 hours.
    private static let energySustainedDecayPerSec: Double = 1.0 / 60.0

    /// Energy dawn recovery: +1 per minute.
    private static let energyDawnRecoveryPerSec: Double = 1.0 / 60.0

    /// Idle curiosity decay: -2 per minute after 10 minutes idle.
    private static let curiosityIdleDecayPerMin: Double = 2.0

    // MARK: - Tracking

    /// Seconds since last commit (for idle-based curiosity decay).
    private var idleTimer: TimeInterval = 0

    /// Seconds of sustained coding activity (for energy decay).
    private var sustainedActivityTimer: TimeInterval = 0

    /// Whether the developer is currently active (has committed recently).
    private var isActive: Bool = false

    /// Time since last persistence to SQLite.
    private var persistTimer: TimeInterval = 0

    /// Persistence interval: save to SQLite every 60 seconds.
    private static let persistInterval: TimeInterval = 60.0

    /// Callback for persisting state.
    var onPersist: ((EmotionalSnapshot) -> Void)?

    // MARK: - Init

    init(satisfaction: Double = 50,
         curiosity: Double = 50,
         contentment: Double = 50,
         energy: Double = 50) {
        self.satisfaction = satisfaction
        self.curiosity = curiosity
        self.contentment = contentment
        self.energy = energy
    }

    // MARK: - Per-Frame Update

    /// Called every frame (or every second for efficiency). Applies decay.
    /// - Parameters:
    ///   - deltaTime: Seconds since last update.
    ///   - hour: Current hour (0-23) for circadian effects.
    func update(deltaTime: TimeInterval, hour: Int) {
        // --- Satisfaction: always decays toward 0 ---
        // -1 per 3 minutes
        satisfaction -= Self.satisfactionDecayPerSec * deltaTime
        satisfaction = clamp(satisfaction, min: 0, max: 100)

        // --- Curiosity: decays toward 50, faster when idle ---
        idleTimer += deltaTime
        let curiosityTarget: Double = 50.0
        if idleTimer > 600 {
            // Idle > 10 min: extra decay
            let idleDecay = Self.curiosityIdleDecayPerMin / 60.0 * deltaTime
            curiosity -= idleDecay
        }
        curiosity = decayToward(curiosity, target: curiosityTarget,
                                rate: Self.curiosityDecayPerSec,
                                deltaTime: deltaTime)

        // --- Contentment: slow drift toward 50 ---
        let contentmentTarget: Double = 50.0
        contentment = decayToward(contentment, target: contentmentTarget,
                                   rate: Self.contentmentDecayPerSec,
                                   deltaTime: deltaTime)

        // --- Energy: circadian cycle ---
        if hour >= 22 || hour < 5 {
            // Nighttime: energy decays
            energy -= Self.energyNightDecayPerSec * deltaTime
        } else if hour >= 6 && hour <= 10 {
            // Dawn/morning: energy recovers
            energy += Self.energyDawnRecoveryPerSec * deltaTime
        }

        // Sustained activity drain (after 2 hours of coding)
        if isActive {
            sustainedActivityTimer += deltaTime
            if sustainedActivityTimer > 7200 {  // 2 hours
                energy -= Self.energySustainedDecayPerSec * deltaTime
            }
        }

        energy = clamp(energy, min: 0, max: 100)

        // --- Persistence timer ---
        persistTimer += deltaTime
        if persistTimer >= Self.persistInterval {
            persistTimer = 0
            onPersist?(toSnapshot())
        }
    }

    // MARK: - Event Boosts

    /// Boost from a commit being eaten.
    /// - Parameter size: Commit size category.
    func boostFromCommit(size: CommitSize) {
        let satBoost: Double
        switch size {
        case .small:  satBoost = 10
        case .medium: satBoost = 20
        case .large:  satBoost = 30
        }
        satisfaction = clamp(satisfaction + satBoost, min: 0, max: 100)
        energy = clamp(energy + 5, min: 0, max: 100)

        // Reset idle timer (developer is active)
        idleTimer = 0
        isActive = true
    }

    /// Boost from discovering a new repo.
    func boostFromNewRepo() {
        curiosity = clamp(curiosity + 20, min: 0, max: 100)
    }

    /// Boost from discovering a new file type.
    func boostFromNewFileType() {
        curiosity = clamp(curiosity + 10, min: 0, max: 100)
    }

    /// Boost from human touch interaction.
    func boostFromTouch() {
        curiosity = clamp(curiosity + 5, min: 0, max: 100)
        energy = clamp(energy + 3, min: 0, max: 100)
    }

    /// Boost from a streak day.
    func boostFromStreakDay() {
        contentment = clamp(contentment + 5, min: 0, max: 100)
    }

    /// Boost from human interaction (Claude session, petting, etc.).
    func boostFromInteraction() {
        contentment = clamp(contentment + 8, min: 0, max: 100)
    }

    /// Boost from hitting a milestone.
    func boostFromMilestone() {
        contentment = clamp(contentment + 15, min: 0, max: 100)
    }

    /// Penalty from a streak break.
    func penaltyFromStreakBreak() {
        contentment = clamp(contentment - 20, min: 0, max: 100)
    }

    /// Penalty from repetitive commits (same repo, same files).
    func penaltyFromRepetitiveCommit() {
        curiosity = clamp(curiosity - 5, min: 0, max: 100)
    }

    /// Mark developer as inactive (e.g., long gap between commits).
    func markInactive() {
        isActive = false
        sustainedActivityTimer = 0
    }

    // MARK: - Snapshot

    /// Create a lightweight read-only snapshot for the behavior stack.
    func toSnapshot() -> EmotionalSnapshot {
        EmotionalSnapshot(
            satisfaction: satisfaction,
            curiosity: curiosity,
            contentment: contentment,
            energy: energy
        )
    }

    // MARK: - Load from Snapshot

    /// Restore from a persisted snapshot (e.g., on launch).
    func restore(from snapshot: EmotionalSnapshot) {
        satisfaction = snapshot.satisfaction
        curiosity = snapshot.curiosity
        contentment = snapshot.contentment
        energy = snapshot.energy
    }

    /// Apply time-based decay for elapsed time since last save.
    /// Called on launch to account for the gap between last persist and now.
    func applyElapsedDecay(seconds: TimeInterval, averageHour: Int) {
        // Satisfaction decays continuously
        satisfaction -= Self.satisfactionDecayPerSec * seconds
        satisfaction = clamp(satisfaction, min: 0, max: 100)

        // Curiosity drifts toward 50
        curiosity = decayToward(curiosity, target: 50,
                                rate: Self.curiosityDecayPerSec,
                                deltaTime: seconds)

        // Contentment drifts toward 50
        contentment = decayToward(contentment, target: 50,
                                   rate: Self.contentmentDecayPerSec,
                                   deltaTime: seconds)

        // Energy: if nighttime elapsed, decay proportionally
        if averageHour >= 22 || averageHour < 5 {
            energy -= Self.energyNightDecayPerSec * seconds
        } else {
            // During day, energy drifts toward 50
            energy = decayToward(energy, target: 50,
                                  rate: Self.energyDawnRecoveryPerSec,
                                  deltaTime: seconds)
        }
        energy = clamp(energy, min: 0, max: 100)
    }

    // MARK: - Persistence Helpers

    /// Load emotional state from the creature table.
    static func load(from db: DatabaseManager) -> EmotionalState {
        do {
            let rows = try db.query(
                """
                SELECT satisfaction, curiosity, contentment,
                       emotional_energy, last_session_at
                FROM creature WHERE id = 1
                """
            )
            guard let row = rows.first else {
                return EmotionalState()
            }

            let sat = (row["satisfaction"] as? Double) ?? 50
            let cur = (row["curiosity"] as? Double) ?? 50
            let con = (row["contentment"] as? Double) ?? 50
            let eng = (row["emotional_energy"] as? Double) ?? 50

            let state = EmotionalState(
                satisfaction: sat, curiosity: cur,
                contentment: con, energy: eng
            )

            // Apply elapsed decay since last session
            if let lastStr = row["last_session_at"] as? String {
                let formatter = ISO8601DateFormatter()
                if let lastDate = formatter.date(from: lastStr) {
                    let elapsed = Date().timeIntervalSince(lastDate)
                    if elapsed > 0 {
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: Date())
                        state.applyElapsedDecay(seconds: elapsed,
                                                 averageHour: hour)
                    }
                }
            }

            return state
        } catch {
            NSLog("[Pushling/Emotion] Failed to load: %@", "\(error)")
            return EmotionalState()
        }
    }

    /// Save emotional state to the creature table.
    static func save(_ state: EmotionalState, to db: DatabaseManager) {
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        do {
            try db.execute(
                """
                UPDATE creature SET
                    satisfaction = ?, curiosity = ?,
                    contentment = ?, emotional_energy = ?,
                    last_session_at = ?
                WHERE id = 1
                """,
                arguments: [
                    state.satisfaction, state.curiosity,
                    state.contentment, state.energy, now
                ]
            )
        } catch {
            NSLog("[Pushling/Emotion] Failed to save: %@", "\(error)")
        }
    }

    // MARK: - Private Helpers

    /// Decay a value toward a target at a given rate.
    private func decayToward(_ value: Double, target: Double,
                              rate: Double,
                              deltaTime: TimeInterval) -> Double {
        if value > target {
            return max(value - rate * deltaTime, target)
        } else if value < target {
            return min(value + rate * deltaTime, target)
        }
        return value
    }
}

// MARK: - Commit Size

/// Size category for XP and emotional boost calculations.
enum CommitSize {
    case small   // <20 lines changed
    case medium  // 20-100 lines
    case large   // 100+ lines

    static func from(linesChanged: Int) -> CommitSize {
        if linesChanged < 20 { return .small }
        if linesChanged <= 100 { return .medium }
        return .large
    }
}
