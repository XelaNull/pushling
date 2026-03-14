// SurpriseScheduler.swift — The surprise scheduling engine
// Produces 2-3 surprises per hour of active use.
//
// Scheduling rules:
//   - Global cooldown: 5 minutes between any two surprises
//   - Per-category cooldown: 15 minutes between same-category surprises
//   - Drought timer: 2 hours with no surprise -> probabilities double
//   - Recency penalty: surprise fired in last hour -> 50% reduced probability
//   - Milestone surprises bypass cooldowns and suppress others for 5 min
//   - No surprises while creature is sleeping
//   - No surprises during inactive periods (no recent commits/touch/session)
//
// Selection algorithm:
//   1. Filter eligible (stage gate, context, cooldowns)
//   2. Apply recency penalties
//   3. Apply drought bonus
//   4. Weighted random selection
//   5. Check for cross-system variants

import Foundation

// MARK: - Surprise Scheduler

final class SurpriseScheduler {

    // MARK: - Constants

    /// Minimum time between any two surprises.
    private static let globalCooldownSeconds: TimeInterval = 300  // 5 min

    /// Minimum time between surprises in the same category.
    private static let categoryCooldownSeconds: TimeInterval = 900 // 15 min

    /// If this many seconds pass with no surprise, double probabilities.
    private static let droughtThresholdSeconds: TimeInterval = 7200 // 2 hours

    /// After a milestone surprise, suppress normal surprises for this long.
    private static let milestoneSuppressSeconds: TimeInterval = 300 // 5 min

    /// How often the scheduler checks for surprise opportunities (seconds).
    static let checkIntervalSeconds: TimeInterval = 30

    /// Base probability per check that a surprise fires (tuned for 2-3/hour).
    /// At 30s intervals, 120 checks/hour. P=0.02 -> ~2.4 fires/hour.
    private static let baseFireProbability: Double = 0.02

    // MARK: - State

    /// All registered surprise definitions, keyed by ID.
    private var registry: [Int: SurpriseDefinition] = [:]

    /// When each surprise was last fired.
    private var lastFiredAt: [Int: Date] = [:]

    /// Fire count per surprise.
    private var fireCount: [Int: Int] = [:]

    /// When any surprise was last fired (global cooldown).
    private var lastAnySurpriseAt: Date?

    /// When each category was last fired (per-category cooldown).
    private var lastCategoryFiredAt: [SurpriseCategory: Date] = [:]

    /// Milestone suppression end time.
    private var suppressedUntil: Date?

    /// One-time surprises that have already fired.
    private var firedOneTimeSurprises: Set<Int> = []

    /// Accumulated time since last check.
    private var checkAccumulator: TimeInterval = 0

    /// Callback when a surprise should be played.
    var onSurpriseFire: ((_ definition: SurpriseDefinition,
                          _ animation: SurpriseAnimation,
                          _ variant: String?) -> Void)?

    /// Callback to log surprise to journal.
    var onSurpriseLog: ((_ surpriseId: Int, _ name: String,
                         _ category: String, _ variant: String?) -> Void)?

    // MARK: - Registration

    /// Register a surprise definition. Called during app init.
    func register(_ definition: SurpriseDefinition) {
        registry[definition.id] = definition
    }

    /// Register multiple definitions at once.
    func registerAll(_ definitions: [SurpriseDefinition]) {
        for def in definitions {
            registry[def.id] = def
        }
    }

    /// Number of registered surprises.
    var registeredCount: Int { registry.count }

    // MARK: - History Loading

    /// Load firing history from database on launch.
    func loadHistory(lastFired: [Int: Date], fireCounts: [Int: Int],
                     oneTimeFired: Set<Int>) {
        self.lastFiredAt = lastFired
        self.fireCount = fireCounts
        self.firedOneTimeSurprises = oneTimeFired
    }

    // MARK: - Frame Update

    /// Called every frame. Accumulates time and checks at intervals.
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - context: Current surprise context snapshot.
    func update(deltaTime: TimeInterval, context: SurpriseContext) {
        checkAccumulator += deltaTime

        guard checkAccumulator >= Self.checkIntervalSeconds else { return }
        checkAccumulator = 0

        let result = evaluateForFiring(context: context)

        switch result {
        case .fire(let definition, let variant):
            let animation = definition.animation(context)
            fireSurprise(definition: definition, animation: animation,
                         variant: variant, context: context)

        case .onCooldown, .noEligible, .sleeping, .inactive, .suppressed:
            // Nothing to do
            break
        }
    }

    // MARK: - Force Fire (for milestones and external triggers)

    /// Force-fire a specific surprise by ID. Bypasses scheduling.
    func forceFire(surpriseId: Int, context: SurpriseContext,
                   variant: String? = nil) {
        guard let definition = registry[surpriseId] else {
            NSLog("[Pushling/Surprise] Cannot force-fire unknown surprise #%d",
                  surpriseId)
            return
        }

        let animation = definition.animation(context)
        fireSurprise(definition: definition, animation: animation,
                     variant: variant, context: context)
    }

    // MARK: - Evaluation

    /// Evaluates whether a surprise should fire right now.
    func evaluateForFiring(context: SurpriseContext) -> SurpriseSchedulingResult {
        // Rule: no surprises while sleeping
        guard !context.isSleeping else { return .sleeping }

        // Rule: no surprises during inactive periods
        guard context.isUserActive else { return .inactive }

        // Rule: milestone suppression
        if let suppressed = suppressedUntil, context.wallClock < suppressed {
            return .suppressed(until: suppressed)
        }

        // Rule: global cooldown
        if let lastAny = lastAnySurpriseAt {
            let elapsed = context.wallClock.timeIntervalSince(lastAny)
            if elapsed < Self.globalCooldownSeconds {
                return .onCooldown(
                    nextEligibleIn: Self.globalCooldownSeconds - elapsed
                )
            }
        }

        // Build eligible pool
        let eligible = buildEligiblePool(context: context)
        guard !eligible.isEmpty else { return .noEligible }

        // Calculate drought bonus
        let droughtMultiplier = calculateDroughtMultiplier(
            wallClock: context.wallClock
        )

        // Roll for whether ANY surprise fires this check
        let adjustedProbability = Self.baseFireProbability * droughtMultiplier
        guard Double.random(in: 0...1) < adjustedProbability else {
            return .noEligible
        }

        // Weighted random selection from eligible pool
        let selected = weightedSelect(
            from: eligible, context: context,
            droughtMultiplier: droughtMultiplier
        )

        guard let chosen = selected else { return .noEligible }

        return .fire(definition: chosen, variant: nil)
    }

    // MARK: - Eligible Pool

    /// Builds the pool of surprises eligible to fire right now.
    private func buildEligiblePool(
        context: SurpriseContext
    ) -> [SurpriseDefinition] {
        let now = context.wallClock

        return registry.values.filter { def in
            // Stage gate
            guard context.stage >= def.stageMin else { return false }

            // One-time check
            if def.isOneTime && firedOneTimeSurprises.contains(def.id) {
                return false
            }

            // Per-surprise cooldown
            if let lastFired = lastFiredAt[def.id] {
                let elapsed = now.timeIntervalSince(lastFired)
                if elapsed < def.cooldown { return false }
            }

            // Per-category cooldown
            if let lastCat = lastCategoryFiredAt[def.category] {
                let elapsed = now.timeIntervalSince(lastCat)
                if elapsed < Self.categoryCooldownSeconds { return false }
            }

            // Context eligibility
            guard def.isEligible(context) else { return false }

            return true
        }
    }

    // MARK: - Weighted Selection

    /// Weighted random selection with recency and drought modifiers.
    private func weightedSelect(
        from eligible: [SurpriseDefinition],
        context: SurpriseContext,
        droughtMultiplier: Double
    ) -> SurpriseDefinition? {
        let now = context.wallClock

        var weightedPool: [(SurpriseDefinition, Double)] = eligible.map { def in
            var weight = def.weight

            // Recency penalty: fired in last hour -> 50% weight
            if let lastFired = lastFiredAt[def.id] {
                let elapsed = now.timeIntervalSince(lastFired)
                if elapsed < 3600 {
                    weight *= 0.5
                }
            }

            // Novelty bonus: fewer than 3 total fires -> 1.5x
            let count = fireCount[def.id] ?? 0
            if count < 3 {
                weight *= 1.5
            }

            // Drought bonus already applied at the fire-probability level,
            // but also boost weights slightly for category variety
            weight *= droughtMultiplier > 1.0 ? 1.2 : 1.0

            return (def, max(weight, 0.01))
        }

        // Sort for determinism in tie-breaking
        weightedPool.sort { $0.1 > $1.1 }

        let totalWeight = weightedPool.reduce(0.0) { $0 + $1.1 }
        guard totalWeight > 0 else { return nil }

        var roll = Double.random(in: 0..<totalWeight)
        for (def, weight) in weightedPool {
            roll -= weight
            if roll <= 0 {
                return def
            }
        }

        return weightedPool.first?.0
    }

    // MARK: - Drought

    /// Calculates drought multiplier. If >2 hours since last surprise,
    /// probability doubles.
    private func calculateDroughtMultiplier(wallClock: Date) -> Double {
        guard let lastAny = lastAnySurpriseAt else {
            // Never fired any surprise — mild drought bonus
            return 1.5
        }
        let elapsed = wallClock.timeIntervalSince(lastAny)
        if elapsed >= Self.droughtThresholdSeconds {
            return 2.0
        }
        return 1.0
    }

    // MARK: - Fire

    /// Executes the surprise firing: updates state, notifies callbacks.
    private func fireSurprise(definition: SurpriseDefinition,
                               animation: SurpriseAnimation,
                               variant: String?,
                               context: SurpriseContext) {
        let now = context.wallClock

        // Update tracking state
        lastFiredAt[definition.id] = now
        fireCount[definition.id, default: 0] += 1
        lastAnySurpriseAt = now
        lastCategoryFiredAt[definition.category] = now

        if definition.isOneTime {
            firedOneTimeSurprises.insert(definition.id)
        }

        // Milestone suppression
        if definition.suppressesOthers {
            suppressedUntil = now.addingTimeInterval(
                Self.milestoneSuppressSeconds
            )
        }

        NSLog("[Pushling/Surprise] FIRED #%d '%@' (category: %@, "
              + "fire count: %d, variant: %@)",
              definition.id, definition.name,
              definition.category.rawValue,
              fireCount[definition.id] ?? 1,
              variant ?? "base")

        // Notify animation player
        onSurpriseFire?(definition, animation, variant)

        // Log to journal
        if animation.logsToJournal {
            onSurpriseLog?(definition.id, definition.name,
                           definition.category.rawValue, variant)
        }
    }

    // MARK: - Query

    /// Returns the fire count for a specific surprise.
    func fireCountForSurprise(_ id: Int) -> Int {
        fireCount[id] ?? 0
    }

    /// Returns whether a one-time surprise has been fired.
    func hasOneTimeFired(_ id: Int) -> Bool {
        firedOneTimeSurprises.contains(id)
    }

    /// Returns the time since last surprise of any type.
    func timeSinceLastSurprise(now: Date) -> TimeInterval? {
        lastAnySurpriseAt.map { now.timeIntervalSince($0) }
    }

    /// Returns a debug snapshot of the scheduler state.
    func debugSnapshot(context: SurpriseContext) -> SurpriseDebugSnapshot {
        let eligible = buildEligiblePool(context: context)
        let drought = calculateDroughtMultiplier(wallClock: context.wallClock)
        return SurpriseDebugSnapshot(
            registeredCount: registry.count,
            eligibleCount: eligible.count,
            eligibleNames: eligible.map { $0.name },
            droughtMultiplier: drought,
            globalCooldownRemaining: lastAnySurpriseAt.map {
                max(0, Self.globalCooldownSeconds
                    - context.wallClock.timeIntervalSince($0))
            },
            isSuppressed: suppressedUntil.map {
                context.wallClock < $0
            } ?? false,
            totalFired: fireCount.values.reduce(0, +)
        )
    }
}

// MARK: - Debug Snapshot

struct SurpriseDebugSnapshot {
    let registeredCount: Int
    let eligibleCount: Int
    let eligibleNames: [String]
    let droughtMultiplier: Double
    let globalCooldownRemaining: TimeInterval?
    let isSuppressed: Bool
    let totalFired: Int
}
