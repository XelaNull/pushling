// TeachReinforceHandlerTests.swift — WO-15: teach reinforce end-to-end
//
// Exercises CommandRouter.reinforceTaughtBehavior / performTeachReinforce
// directly against a real (temp-file) SQLite database — the same code
// paths handleTeachReinforce calls — rather than constructing a full
// GameCoordinator/SpriteKit scene, matching this suite's existing
// convention of testing pure/DB-level logic in isolation (see
// PushlingSceneComposeTests.swift).
//
// WO-15 REVISE (Mack CRITICAL): the persistence-guard tests below use
// TestPersistenceGate, a bare struct conforming to PersistenceGate,
// instead of a real StateCoordinator. A real StateCoordinator can only
// report persistenceEnabled == false via `.start(persistenceEnabled:
// false)`, and `.start()` unconditionally touches real shared-runtime I/O
// before that flag is even consulted — HeartbeatManager.checkForCrash()
// reads (and sometimes deletes) `/tmp/pushling.heartbeat`, the real
// daemon's file. A unit test must never risk that, hence the protocol
// seam.

import XCTest
@testable import Pushling

/// Bare test double for `PersistenceGate` — no heartbeat/backup I/O,
/// unlike a real `StateCoordinator`. See file header.
private struct TestPersistenceGate: PersistenceGate {
    let persistenceEnabled: Bool
    let database: DatabaseManager
}

final class TeachReinforceHandlerTests: XCTestCase {

    private var tempDBPath: String!

    override func setUpWithError() throws {
        tempDBPath = NSTemporaryDirectory()
            + "pushling-teach-reinforce-test-\(UUID().uuidString).sqlite"
        try DatabaseManager.shared.open(at: tempDBPath)
    }

    override func tearDownWithError() throws {
        DatabaseManager.shared.close()
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempDBPath = nil
    }

    /// Routing gate: "reinforce" must be a valid teach action, or
    /// CommandRouter.route() rejects it as UNKNOWN_ACTION before it ever
    /// reaches a handler (this was the WO-15 bug — the MCP already sent
    /// it, the daemon rejected every call at this gate).
    func testReinforceIsAValidTeachAction() {
        let valid = CommandRouter.validActions["teach"]
        XCTAssertNotNil(valid)
        XCTAssertTrue(
            valid?.contains("reinforce") ?? false,
            "'reinforce' must be listed in validActions[\"teach\"] or every "
                + "teach-reinforce call is rejected as UNKNOWN_ACTION"
        )
    }

    /// Seeds a taught behavior row, reinforces it, and verifies both
    /// `strength` (+0.15) and `reinforcement_count` (+1) persisted —
    /// the two columns docs/SYSTEMS/teach-system.md:174-175 describes as
    /// dead until this WO.
    func testReinforceIncrementsStrengthAndReinforcementCount() throws {
        let db = DatabaseManager.shared
        try seedTaughtBehavior(named: "wave_test", strength: 0.5, db: db)

        let newStrength = try CommandRouter.reinforceTaughtBehavior(
            name: "wave_test", db: db
        )
        XCTAssertEqual(newStrength, 0.65, accuracy: 0.0001)

        let rows = try db.query(
            "SELECT strength, reinforcement_count, last_decayed_at "
                + "FROM taught_behaviors WHERE name = ?",
            arguments: ["wave_test"]
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["strength"] as? Double ?? -1, 0.65, accuracy: 0.0001)
        XCTAssertEqual(rows.first?["reinforcement_count"] as? Int ?? -1, 1)
        XCTAssertNotNil(rows.first?["last_decayed_at"],
                         "reinforcing should stamp last_decayed_at so a "
                             + "future decay pass measures from this reinforcement")

        // A second reinforcement compounds correctly (0.65 -> 0.80) and the
        // count increments again (1 -> 2) rather than resetting.
        let secondStrength = try CommandRouter.reinforceTaughtBehavior(
            name: "wave_test", db: db
        )
        XCTAssertEqual(secondStrength, 0.80, accuracy: 0.0001)
        let rowsAfterSecond = try db.query(
            "SELECT reinforcement_count FROM taught_behaviors WHERE name = ?",
            arguments: ["wave_test"]
        )
        XCTAssertEqual(rowsAfterSecond.first?["reinforcement_count"] as? Int ?? -1, 2)
    }

    /// Strength caps at 1.0, matching the nurture strength model — a
    /// behavior already at 0.95 reinforced by +0.15 lands at 1.0, not 1.10.
    func testReinforceCapsStrengthAtOne() throws {
        let db = DatabaseManager.shared
        try seedTaughtBehavior(named: "spin_test", strength: 0.95, db: db)

        let newStrength = try CommandRouter.reinforceTaughtBehavior(
            name: "spin_test", db: db
        )
        XCTAssertEqual(newStrength, 1.0, accuracy: 0.0001)
    }

    /// Reinforcing a name with no matching row surfaces NOT_FOUND-shaped
    /// failure rather than silently no-op'ing or crashing.
    func testReinforceUnknownNameThrowsNotFound() throws {
        let db = DatabaseManager.shared
        XCTAssertThrowsError(
            try CommandRouter.reinforceTaughtBehavior(name: "does_not_exist", db: db)
        ) { error in
            guard case TeachReinforceError.notFound(let name) = error else {
                XCTFail("Expected TeachReinforceError.notFound, got \(error)")
                return
            }
            XCTAssertEqual(name, "does_not_exist")
        }
    }

    /// WO-15 REVISE (Mack CRITICAL): a --workbench in-process trigger runs
    /// teach commands against a persistenceEnabled == false coordinator
    /// (WorkbenchTriggerMenu) — reinforce must not write the real shared
    /// state.db in that case: no strength change, no reinforcement_count
    /// bump, and the call returns a clean suppressed failure rather than
    /// silently no-op'ing.
    func testReinforceSuppressedWhenPersistenceDisabled() throws {
        let db = DatabaseManager.shared
        try seedTaughtBehavior(named: "workbench_test", strength: 0.5, db: db)

        let gate = TestPersistenceGate(persistenceEnabled: false, database: db)
        let result = CommandRouter.performTeachReinforce(name: "workbench_test", gate: gate)

        XCTAssertFalse(result.ok, "reinforce must fail (not silently no-op) when persistence is disabled")
        XCTAssertEqual(result.code, "PERSISTENCE_DISABLED")

        let rows = try db.query(
            "SELECT strength, reinforcement_count FROM taught_behaviors WHERE name = ?",
            arguments: ["workbench_test"]
        )
        XCTAssertEqual(rows.first?["strength"] as? Double ?? -1, 0.5, accuracy: 0.0001,
                        "persistence-disabled reinforce must leave strength untouched")
        XCTAssertEqual(rows.first?["reinforcement_count"] as? Int ?? -1, 0,
                        "persistence-disabled reinforce must not increment reinforcement_count")
    }

    /// The persistenceEnabled == true path (the daemon's normal posture)
    /// still reinforces correctly through the same dispatch entry point
    /// handleTeachReinforce calls (performTeachReinforce), not just the
    /// lower-level reinforceTaughtBehavior exercised above.
    func testReinforceWorksWhenPersistenceEnabled() throws {
        let db = DatabaseManager.shared
        try seedTaughtBehavior(named: "daemon_test", strength: 0.5, db: db)

        let gate = TestPersistenceGate(persistenceEnabled: true, database: db)
        let result = CommandRouter.performTeachReinforce(name: "daemon_test", gate: gate)

        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.data["strength"] as? Double ?? -1, 0.65, accuracy: 0.0001)

        let rows = try db.query(
            "SELECT strength, reinforcement_count FROM taught_behaviors WHERE name = ?",
            arguments: ["daemon_test"]
        )
        XCTAssertEqual(rows.first?["strength"] as? Double ?? -1, 0.65, accuracy: 0.0001)
        XCTAssertEqual(rows.first?["reinforcement_count"] as? Int ?? -1, 1)
    }

    // MARK: - Helpers

    private func seedTaughtBehavior(
        named name: String, strength: Double, db: DatabaseManager
    ) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try db.execute(
            """
            INSERT INTO taught_behaviors
                (name, category, stage_min, duration_s,
                 tracks_json, triggers_json, strength,
                 reinforcement_count, source, created_at)
            VALUES (?, 'playful', 'critter', 3.0, '{}', '{}', ?, 0, 'taught', ?)
            """,
            arguments: [name, strength, now]
        )
    }
}
