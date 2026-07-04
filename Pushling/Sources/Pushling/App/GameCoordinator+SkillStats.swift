// GameCoordinator+SkillStats.swift — Skill stat lifecycle wiring
//
// Loads stats on launch, wires commit/hook callbacks, applies daily decay,
// and persists after every stat change.
//
// Integrates with:
//   - wireFeedProcessor() callbacks (onCommitReceived, onSessionEvent)
//   - GameCoordinator init (load + daily decay)
//   - GameCoordinator+Hatching (hatch initializes from EggAccumulator)

import Foundation

// MARK: - SkillStats Storage

extension GameCoordinator {

    /// Live skill stats, loaded on launch.
    var skillStats: SkillStats {
        get { _skillStats }
        set { _skillStats = newValue }
    }
}

// MARK: - SkillStats Loading & Decay

extension GameCoordinator {

    /// Called from init after all subsystems are created.
    /// Loads stats, applies offline decay, wires callbacks.
    func loadAndWireSkillStats() {
        let db = stateCoordinator.database
        _skillStats = SkillStatEngine.load(from: db)

        // Apply daily decay for time offline
        applySkillStatDecayIfNeeded()

        // Wire commit events
        let existingCommitHandler = feedProcessor.onCommitReceived
        feedProcessor.onCommitReceived = { [weak self] commitData, multiplier in
            existingCommitHandler?(commitData, multiplier)
            self?.handleCommitForSkillStats(commitData)
        }

        // Wire hook events
        let existingSessionHandler = feedProcessor.onSessionEvent
        feedProcessor.onSessionEvent = { [weak self] type, data in
            existingSessionHandler?(type, data)
            self?.handleHookForSkillStats(type: type, data: data)
        }

        NSLog("[Pushling/SkillStats] Loaded — "
              + "debugging:%d patience:%d chaos:%d wisdom:%d snark:%d speed:%d",
              _skillStats.debugging, _skillStats.patience, _skillStats.chaos,
              _skillStats.wisdom, _skillStats.snark, _skillStats.speed)
    }

    /// Initialize stats from egg accumulator data at hatch.
    /// Called by GameCoordinator+Hatching just before the hatch ceremony plays.
    func initializeSkillStatsFromEgg() {
        guard let acc = eggAccumulator else { return }
        let floor = creatureRarity.statFloor
        _skillStats = SkillStatEngine.computeInitialStats(from: acc,
                                                          rarityFloor: floor)
        persistSkillStats()
        NSLog("[Pushling/SkillStats] Initialized from egg — "
              + "debugging:%d patience:%d chaos:%d wisdom:%d snark:%d speed:%d",
              _skillStats.debugging, _skillStats.patience, _skillStats.chaos,
              _skillStats.wisdom, _skillStats.snark, _skillStats.speed)
    }

    /// Persist skill stats to SQLite asynchronously. Gated: this is the
    /// single write chokepoint for all three call sites below —
    /// applySkillStatDecayIfNeeded() (fires at init, independent of
    /// feedProcessor), initializeSkillStatsFromEgg() (hatch), and
    /// handleCommitForSkillStats() (commit pipeline) — one guard covers
    /// all of them.
    func persistSkillStats() {
        guard persistenceEnabled else { return }
        let stats = _skillStats
        let db = stateCoordinator.database
        db.performWriteAsync({
            SkillStatEngine.save(stats, to: db)
        })
    }

    // MARK: - Commit Handler

    private func handleCommitForSkillStats(_ commitData: [String: Any]) {
        let floor = creatureRarity.statFloor
        // Inject current timestamp into commit data for hour-of-day checks
        var data = commitData
        data["timestamp"] = Date()
        SkillStatEngine.processCommitEvent(
            stats: &_skillStats,
            commit: data,
            rarityFloor: floor,
            previousCommitTime: _lastCommitTime
        )
        _lastCommitTime = Date()
        persistSkillStats()
    }

    // MARK: - Hook Handler

    private func handleHookForSkillStats(type: HookEventType, data: [String: Any]) {
        let floor = creatureRarity.statFloor
        let wasFailure = _lastToolUseWasFailure
        SkillStatEngine.processHookEvent(
            stats: &_skillStats,
            type: type,
            data: data,
            rarityFloor: floor,
            lastToolUseWasFailure: wasFailure
        )
        // Track failure state for the next tool use event
        if type == .postToolUse {
            _lastToolUseWasFailure = !((data["success"] as? Bool) ?? true)
        }
        persistSkillStats()
    }

    // MARK: - Decay

    /// Applies inactivity decay based on `last_fed_at` or `last_session_at`.
    /// Called once on launch.
    func applySkillStatDecayIfNeeded() {
        let db = stateCoordinator.database
        let rows = (try? db.query(
            "SELECT last_fed_at, last_session_at FROM creature WHERE id = 1"
        )) ?? []

        guard let row = rows.first else { return }

        let formatter = ISO8601DateFormatter()
        let lastFed = (row["last_fed_at"] as? String).flatMap {
            formatter.date(from: $0)
        }
        let lastSession = (row["last_session_at"] as? String).flatMap {
            formatter.date(from: $0)
        }

        // Use the most recent of the two timestamps
        let candidates: [Date] = [lastFed, lastSession].compactMap { $0 }
        guard let lastActivity = candidates.max() else { return }

        let days = Int(Date().timeIntervalSince(lastActivity) / 86400)
        guard days > 0 else { return }

        let floor = creatureRarity.statFloor
        SkillStatEngine.applyDailyDecay(stats: &_skillStats,
                                        daysSinceLastActivity: days,
                                        rarityFloor: floor)
        persistSkillStats()

        NSLog("[Pushling/SkillStats] Applied %d-day decay (floor: %d)",
              days, floor)
    }
}

// MARK: - Stored State (Associated Object Pattern via Static)
//
// Swift extensions cannot add stored properties. We use static UInt8 keys
// as stable address-based tokens for objc_setAssociatedObject — the canonical
// pattern recommended by the Swift compiler to avoid the UnsafeRawPointer warning
// that arises when using &stringVar as a key.

private enum SkillStatsKeys {
    static var skillStats:          UInt8 = 0
    static var lastCommitTime:      UInt8 = 0
    static var lastToolUseFailure:  UInt8 = 0
}

extension GameCoordinator {

    fileprivate var _skillStats: SkillStats {
        get {
            return (objc_getAssociatedObject(self, &SkillStatsKeys.skillStats)
                as? SkillStatsBox)?.value ?? SkillStats()
        }
        set {
            objc_setAssociatedObject(self, &SkillStatsKeys.skillStats,
                                     SkillStatsBox(newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    fileprivate var _lastCommitTime: Date? {
        get {
            return objc_getAssociatedObject(self,
                                            &SkillStatsKeys.lastCommitTime) as? Date
        }
        set {
            objc_setAssociatedObject(self, &SkillStatsKeys.lastCommitTime,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    fileprivate var _lastToolUseWasFailure: Bool {
        get {
            return (objc_getAssociatedObject(self,
                                             &SkillStatsKeys.lastToolUseFailure)
                as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &SkillStatsKeys.lastToolUseFailure,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

/// Box type to wrap SkillStats (a struct) for objc_setAssociatedObject.
private final class SkillStatsBox {
    var value: SkillStats
    init(_ value: SkillStats) { self.value = value }
}
