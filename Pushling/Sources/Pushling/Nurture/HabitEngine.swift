// HabitEngine.swift — Evaluates triggers, queues habits for execution
// Habits fire through the autonomous behavior layer.
// 12 trigger types including compound (AND/OR/NOT).
// Max 20 active habits. Priority-based conflict resolution.
// Frequency modifiers: always (90%), often (70%), sometimes (40%), rarely (15%).

import Foundation

// MARK: - Habit Definition

/// A persistent habit that fires on trigger conditions.
struct HabitDefinition {
    let id: String
    let name: String
    let trigger: TriggerDefinition
    let behavior: String                // Behavior name (built-in or taught)
    let behaviorVariant: String?
    let frequency: HabitFrequency
    let variation: VariationLevel
    let energyCost: Double              // 0.0-1.0
    let stageMin: GrowthStage
    let priority: Int                   // Higher = more important
    let strength: Double                // 0.0-1.0 (from decay system)
    let reinforcementCount: Int
    let personalityConflict: Bool       // True if conflicts with personality
    var lastFiredAt: Date?
    var cooldownSeconds: TimeInterval
}

/// Frequency levels with their fire probabilities.
enum HabitFrequency: String, CaseIterable {
    case always    = "always"      // 90%
    case often     = "often"       // 70%
    case sometimes = "sometimes"   // 40%
    case rarely    = "rarely"      // 15%

    var probability: Double {
        switch self {
        case .always:    return 0.90
        case .often:     return 0.70
        case .sometimes: return 0.40
        case .rarely:    return 0.15
        }
    }
}

/// Variation levels controlling jitter.
enum VariationLevel: String, CaseIterable {
    case strict   = "strict"     // 5% jitter
    case moderate = "moderate"   // 15% jitter
    case loose    = "loose"      // 30% jitter
    case wild     = "wild"       // 50% jitter

    var jitterPercent: Double {
        switch self {
        case .strict:   return 0.05
        case .moderate: return 0.15
        case .loose:    return 0.30
        case .wild:     return 0.50
        }
    }
}

// MARK: - Trigger Definitions

/// A trigger condition that determines when a habit fires.
indirect enum TriggerDefinition {
    case afterEvent(event: String)
    case onIdle(minIdleSeconds: TimeInterval)
    case atTime(hour: Int, minute: Int, windowMinutes: Int)
    case onEmotion(axis: String, direction: String, threshold: Double)
    case onWeather(weather: String)
    case nearObject(objectType: String, distancePoints: CGFloat)
    case onWake
    case onSession(event: String)  // "start" or "end"
    case onTouch(type: String)     // "tap", "pet", "any"
    case onStreak(minDays: Int)
    case periodic(intervalMinutes: Int, jitterMinutes: Int)
    case compound(allOf: [TriggerDefinition]?, anyOf: [TriggerDefinition]?,
                  noneOf: [TriggerDefinition]?)
}

// MARK: - Trigger Event

/// An event that may satisfy habit triggers.
enum TriggerEvent {
    case commitEaten(type: String, linesChanged: Int)
    case idleTick(idleSeconds: TimeInterval)
    case timeTick(hour: Int, minute: Int)
    case emotionChanged(axis: String, value: Double)
    case weatherChanged(weather: String)
    case nearObject(objectType: String, distance: CGFloat)
    case woke
    case sessionEvent(event: String)
    case touched(type: String)
    case streakUpdate(days: Int)
    case periodicTick
}

// MARK: - Queued Habit

/// A habit that matched its trigger and is queued for execution.
struct QueuedHabit {
    let habit: HabitDefinition
    let queuedAt: TimeInterval
    let expiresAt: TimeInterval  // 30s from queued

    var isExpired: Bool { false }  // Checked by caller with current time
}

// MARK: - HabitEngine

/// Evaluates triggers and manages the habit execution queue.
final class HabitEngine {

    // MARK: - Configuration

    /// Maximum active habits.
    static let maxHabits = 20

    /// Maximum queued habits.
    private static let maxQueue = 2

    /// Minimum spacing between habit executions (seconds).
    private static let executionSpacing: TimeInterval = 5.0

    /// Queue expiry time (seconds).
    private static let queueExpirySeconds: TimeInterval = 30.0

    // MARK: - State

    /// All active habit definitions.
    private(set) var habits: [HabitDefinition] = []

    /// Execution queue (max 2).
    private var queue: [QueuedHabit] = []

    /// When the last habit was executed.
    private var lastExecutionTime: TimeInterval = -5.0

    /// Random number generator.
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Habit Management

    /// Adds a new habit. Returns false if at cap.
    @discardableResult
    func addHabit(_ habit: HabitDefinition) -> Bool {
        guard habits.count < Self.maxHabits else {
            NSLog("[Pushling/Habits] At cap (%d). Cannot add '%@'.",
                  Self.maxHabits, habit.name)
            return false
        }
        habits.append(habit)
        NSLog("[Pushling/Habits] Added habit '%@' (total: %d)",
              habit.name, habits.count)
        return true
    }

    /// Removes a habit by name.
    func removeHabit(named name: String) {
        habits.removeAll { $0.name == name }
    }

    /// Updates a habit's strength (from decay system).
    func updateStrength(name: String, strength: Double) {
        if let idx = habits.firstIndex(where: { $0.name == name }) {
            var h = habits[idx]
            // Recreate with updated strength (structs are value types)
            habits[idx] = HabitDefinition(
                id: h.id, name: h.name, trigger: h.trigger,
                behavior: h.behavior, behaviorVariant: h.behaviorVariant,
                frequency: h.frequency, variation: h.variation,
                energyCost: h.energyCost, stageMin: h.stageMin,
                priority: h.priority, strength: strength,
                reinforcementCount: h.reinforcementCount,
                personalityConflict: h.personalityConflict,
                lastFiredAt: h.lastFiredAt,
                cooldownSeconds: h.cooldownSeconds
            )
        }
    }

    // MARK: - Trigger Evaluation

    /// Evaluates all habits against a trigger event.
    /// Matching habits are queued for execution.
    ///
    /// - Parameters:
    ///   - event: The trigger event to evaluate.
    ///   - stage: Current creature stage.
    ///   - currentTime: Scene time for cooldown checking.
    func evaluate(event: TriggerEvent,
                  stage: GrowthStage,
                  currentTime: TimeInterval) {
        // Expire old queue entries
        queue.removeAll { currentTime > $0.expiresAt }

        var matched: [HabitDefinition] = []

        for habit in habits {
            // Stage gate
            guard stage >= habit.stageMin else { continue }

            // Strength gate (forgotten habits don't fire)
            guard habit.strength >= 0.2 else { continue }

            // Cooldown check
            if let lastFired = habit.lastFiredAt {
                let cooldownMod = habit.variation.jitterPercent
                let jitter = Double.random(in: -cooldownMod...cooldownMod,
                                           using: &rng) * habit.cooldownSeconds
                if Date().timeIntervalSince(lastFired) < habit.cooldownSeconds + jitter {
                    continue
                }
            }

            // Trigger match
            guard matches(trigger: habit.trigger, event: event) else { continue }

            // Frequency roll
            let roll = Double.random(in: 0...1, using: &rng)
            guard roll < habit.frequency.probability else { continue }

            matched.append(habit)
        }

        // Sort by priority (highest first)
        matched.sort { $0.priority > $1.priority }

        // Queue top 2 (or fewer if at cap)
        for habit in matched.prefix(Self.maxQueue - queue.count) {
            let queued = QueuedHabit(
                habit: habit,
                queuedAt: currentTime,
                expiresAt: currentTime + Self.queueExpirySeconds
            )
            queue.append(queued)
            NSLog("[Pushling/Habits] Queued '%@' (priority: %d)",
                  habit.name, habit.priority)
        }
    }

    // MARK: - Execution

    /// Returns the next habit to execute, if timing allows.
    /// Removes it from the queue.
    func nextHabitToExecute(currentTime: TimeInterval) -> HabitDefinition? {
        // Spacing enforcement
        guard currentTime - lastExecutionTime >= Self.executionSpacing else {
            return nil
        }

        // Remove expired
        queue.removeAll { currentTime > $0.expiresAt }

        guard let next = queue.first else { return nil }
        queue.removeFirst()
        lastExecutionTime = currentTime

        // Mark as fired
        if let idx = habits.firstIndex(where: { $0.name == next.habit.name }) {
            habits[idx].lastFiredAt = Date()
        }

        NSLog("[Pushling/Habits] Executing habit '%@'", next.habit.name)
        return next.habit
    }

    /// Whether a habit is queued for execution.
    var hasQueuedHabits: Bool { !queue.isEmpty }

    // MARK: - Trigger Matching

    /// Recursively evaluates a trigger against an event.
    private func matches(trigger: TriggerDefinition,
                          event: TriggerEvent) -> Bool {
        switch trigger {
        case .afterEvent(let eventType):
            if case .commitEaten(let type, _) = event {
                return eventType == "commit" || eventType == "commit_\(type)"
            }
            if case .touched = event, eventType == "touch" { return true }
            if case .woke = event, eventType == "wake" { return true }
            return false

        case .onIdle(let minSeconds):
            if case .idleTick(let idle) = event {
                return idle >= minSeconds
            }
            return false

        case .atTime(let hour, let minute, let window):
            if case .timeTick(let h, let m) = event {
                let eventMinutes = h * 60 + m
                let targetMinutes = hour * 60 + minute
                return abs(eventMinutes - targetMinutes) <= window
            }
            return false

        case .onEmotion(let axis, let direction, let threshold):
            if case .emotionChanged(let a, let value) = event, a == axis {
                if direction == "above" { return value >= threshold }
                if direction == "below" { return value <= threshold }
            }
            return false

        case .onWeather(let weather):
            if case .weatherChanged(let w) = event { return w == weather }
            return false

        case .nearObject(let objectType, let distance):
            if case .nearObject(let type, let dist) = event {
                return (objectType == type || objectType == "any") && dist <= distance
            }
            return false

        case .onWake:
            if case .woke = event { return true }
            return false

        case .onSession(let sessionEvent):
            if case .sessionEvent(let e) = event { return e == sessionEvent }
            return false

        case .onTouch(let touchType):
            if case .touched(let t) = event {
                return touchType == "any" || touchType == t
            }
            return false

        case .onStreak(let minDays):
            if case .streakUpdate(let days) = event { return days >= minDays }
            return false

        case .periodic:
            if case .periodicTick = event { return true }
            return false

        case .compound(let allOf, let anyOf, let noneOf):
            return matchesCompound(allOf: allOf, anyOf: anyOf,
                                    noneOf: noneOf, event: event)
        }
    }

    /// Evaluates compound trigger logic.
    private func matchesCompound(
        allOf: [TriggerDefinition]?,
        anyOf: [TriggerDefinition]?,
        noneOf: [TriggerDefinition]?,
        event: TriggerEvent
    ) -> Bool {
        // ALL: every sub-trigger must match
        if let all = allOf {
            for sub in all {
                if !matches(trigger: sub, event: event) { return false }
            }
        }

        // ANY: at least one must match
        if let any = anyOf, !any.isEmpty {
            var anyMatched = false
            for sub in any {
                if matches(trigger: sub, event: event) {
                    anyMatched = true
                    break
                }
            }
            if !anyMatched { return false }
        }

        // NONE: no sub-trigger must match
        if let none = noneOf {
            for sub in none {
                if matches(trigger: sub, event: event) { return false }
            }
        }

        return true
    }

    // MARK: - Bulk Operations

    /// Loads habits from SQLite data.
    func loadHabits(_ data: [HabitDefinition]) {
        habits = Array(data.prefix(Self.maxHabits))
        NSLog("[Pushling/Habits] Loaded %d habits", habits.count)
    }

    /// Resets all habit state.
    func reset() {
        habits.removeAll()
        queue.removeAll()
        lastExecutionTime = -5.0
    }
}
