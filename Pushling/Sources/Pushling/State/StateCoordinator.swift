// StateCoordinator.swift — Pushling state subsystem coordinator
// Orchestrates DatabaseManager, HeartbeatManager, and BackupManager.
// Provides the single entry point for app lifecycle integration.

import Foundation

// MARK: - StateCoordinator

/// Coordinates all state subsystems: database, heartbeat, and backup.
/// The app delegate creates this and calls `start()` / `shutdown()`.
///
/// Usage:
/// ```swift
/// let state = StateCoordinator()
/// try state.start()
/// // ... app runs ...
/// state.shutdown()
/// ```
final class StateCoordinator {

    /// The database manager (singleton, but accessed through coordinator).
    let database = DatabaseManager.shared

    /// Heartbeat manager for crash detection and recovery.
    private(set) var heartbeat: HeartbeatManager!

    /// Backup manager for daily SQLite snapshots.
    private(set) var backup: BackupManager!

    /// Whether a crash was detected on this launch.
    private(set) var crashRecovery: CrashRecoveryInfo?

    // MARK: - Lifecycle

    /// Initializes and starts all state subsystems.
    ///
    /// Order of operations:
    /// 1. Check heartbeat for crash (before DB is open)
    /// 2. Open database (creates/migrates schema)
    /// 3. If crash detected, log recovery journal entry
    /// 4. Start heartbeat writer
    /// 5. Run backup if needed
    ///
    /// - Parameter databasePath: Override database path (for testing).
    /// - Throws: `DatabaseError` if database cannot be opened or migrated.
    func start(databasePath: String? = nil) throws {
        NSLog("[Pushling/State] Starting state subsystem...")

        // 1. Create heartbeat manager (DB reference added after open)
        heartbeat = HeartbeatManager()

        // 2. Check for crash BEFORE opening database
        let recovery = heartbeat.checkForCrash()
        crashRecovery = recovery

        if recovery.crashDetected {
            NSLog("[Pushling/State] Crash recovery mode — "
                  + "previous PID %d, last heartbeat %@",
                  recovery.previousPID, recovery.lastHeartbeat)
        }

        // 3. Open database (creates schema on first run, migrates if needed)
        try database.open(at: databasePath)

        // 4. If crash was detected, log to journal now that DB is open
        if recovery.crashDetected {
            logCrashRecoveryToJournal(recovery: recovery)
        }

        // 5. Start heartbeat writer
        // Re-create with DB reference now that it's open
        heartbeat = HeartbeatManager(databaseManager: database)
        heartbeat.start()

        // 6. Create backup manager and check if backup is needed
        backup = BackupManager(databaseManager: database)
        backup.backupOnLaunchIfNeeded()

        NSLog("[Pushling/State] State subsystem ready")
    }

    /// Cleanly shuts down all state subsystems.
    /// Call from applicationWillTerminate or equivalent.
    func shutdown() {
        NSLog("[Pushling/State] Shutting down state subsystem...")

        // Stop heartbeat (writes clean shutdown marker)
        heartbeat?.stop()

        // Close database (checkpoints WAL)
        database.close()

        NSLog("[Pushling/State] State subsystem shut down")
    }

    // MARK: - Frame Update Hook

    /// Call from the SpriteKit scene's update() method.
    /// Checks if a daily backup is needed (dispatches to background).
    func frameUpdate() {
        backup?.backupIfNeeded()
    }

    // MARK: - Private

    /// Logs crash recovery to the journal table after DB is opened.
    private func logCrashRecoveryToJournal(recovery: CrashRecoveryInfo) {
        let now = ISO8601DateFormatter().string(from: Date())
        let dataJSON = """
            {"previous_pid":\(recovery.previousPID),\
            "last_heartbeat":"\(recovery.lastHeartbeat)",\
            "recovered_at":"\(now)"}
            """

        do {
            try database.execute("""
                INSERT INTO journal (type, summary, timestamp, data)
                VALUES (?, ?, ?, ?);
                """,
                arguments: [
                    "hook",
                    "Crash recovery: previous instance (PID "
                        + "\(recovery.previousPID)) did not shut down cleanly",
                    now,
                    dataJSON
                ]
            )
            NSLog("[Pushling/State] Crash recovery event logged to journal")
        } catch {
            NSLog("[Pushling/State] Failed to log crash recovery: %@",
                  "\(error)")
        }
    }
}

// MARK: - MutationQueryProvider Conformance

extension StateCoordinator: MutationQueryProvider {

    func midnightCommitCount() -> Int {
        (try? database.queryScalarInt(
            "SELECT COUNT(*) FROM commits "
            + "WHERE CAST(strftime('%H', timestamp) AS INTEGER) >= 0 "
            + "AND CAST(strftime('%H', timestamp) AS INTEGER) < 5"
        )) ?? 0
    }

    func uniqueExtensionsIn7Days() -> Int {
        (try? database.queryScalarInt(
            "SELECT COUNT(DISTINCT language) FROM commits "
            + "WHERE timestamp > datetime('now', '-7 days') "
            + "AND language IS NOT NULL"
        )) ?? 0
    }

    func testCommitCount() -> Int {
        (try? database.queryScalarInt(
            "SELECT COUNT(*) FROM commits WHERE has_tests = 1"
        )) ?? 0
    }

    func longMessagesConsecutiveDays() -> Int {
        // Simplified: count recent days where all messages were >50 chars
        // Full implementation would track consecutive days
        (try? database.queryScalarInt(
            "SELECT COUNT(DISTINCT date(timestamp)) FROM commits "
            + "WHERE LENGTH(message) > 50 "
            + "AND timestamp > datetime('now', '-14 days')"
        )) ?? 0
    }

    func isBilingual30Days() -> Bool {
        let rows = (try? database.query(
            "SELECT language, COUNT(*) as cnt FROM commits "
            + "WHERE timestamp > datetime('now', '-30 days') "
            + "AND language IS NOT NULL "
            + "GROUP BY language"
        )) ?? []

        let total = rows.reduce(0) { $0 + (($1["cnt"] as? Int) ?? 0) }
        guard total > 0 else { return false }

        let qualifying = rows.filter { row in
            let cnt = (row["cnt"] as? Int) ?? 0
            return Double(cnt) / Double(total) >= 0.30
        }
        return qualifying.count >= 2
    }
}
