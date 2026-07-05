// TestModeIsolationTests.swift — Proves --test-mode's inert-state isolation
// (WO-33): a StateCoordinator started with a scratch databasePath +
// persistenceEnabled: false must never mutate a stand-in "real" state.db,
// and must skip the heartbeat writer — exactly the mechanism
// AppDelegate.setupTestMode() relies on.
//
// Does not spin up a full GameCoordinator/SKView/WorkbenchWindowController:
// SpriteKit needs a real windowserver connection the `swift test` sandbox
// doesn't reliably have, and no existing test in this target does so either
// (see PushlingSceneComposeTests.swift's header — this codebase's convention
// is to test the underlying mechanism directly rather than the full wiring).
// Every GameCoordinator DB write test-mode's LifecycleSimulator triggers
// (persistXPAndStage, checkEvolution, journal inserts) routes through
// `stateCoordinator.database`, so proving isolation at that layer is
// sufficient regardless of what fires HookEventProcessor.onCommitReceived.

import XCTest
@testable import Pushling

final class TestModeIsolationTests: XCTestCase {

    // MARK: - Scratch database path isolation

    /// Mirrors exactly what setupTestMode() does — starts a
    /// StateCoordinator against a scratch path — and exactly what
    /// GameCoordinator+Loading.swift's persistXPAndStage()/checkEvolution()
    /// do on every commit: write straight to `stateCoordinator.database`.
    /// A stand-in "real" database file must be byte-for-byte untouched.
    func testScratchDatabasePathLeavesStandInRealDatabaseByteForByteUnchanged() throws {
        let tempDir = NSTemporaryDirectory()
        let uniqueSuffix = UUID().uuidString
        let fakeRealDBPath = tempDir + "pushling-wo33-fakeRealDB-\(uniqueSuffix).db"
        let scratchDBPath = tempDir + "pushling-wo33-scratchDB-\(uniqueSuffix).db"

        // Stand in for the developer's real state.db: an arbitrary sentinel
        // file at a path StateCoordinator must never open, read, or write.
        let sentinel = Data("NOT-A-REAL-DATABASE-SENTINEL".utf8)
        try sentinel.write(to: URL(fileURLWithPath: fakeRealDBPath))
        let sentinelBefore = try Data(contentsOf: URL(fileURLWithPath: fakeRealDBPath))

        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: fakeRealDBPath + suffix)
                try? FileManager.default.removeItem(atPath: scratchDBPath + suffix)
            }
        }

        // Exactly the call AppDelegate.setupTestMode() makes.
        let coordinator = StateCoordinator()
        try coordinator.start(databasePath: scratchDBPath, persistenceEnabled: false)
        defer { coordinator.shutdown() }

        // Exactly what GameCoordinator.persistXPAndStage()/checkEvolution()
        // do on every simulated commit -- write to `stateCoordinator.database`,
        // which is bound to the scratch path above.
        try coordinator.database.execute(
            "UPDATE creature SET xp = ?, stage = ? WHERE id = 1",
            arguments: [12345, "apex"]
        )
        try coordinator.database.execute(
            """
            INSERT INTO journal (type, summary, timestamp) VALUES (?, ?, ?)
            """,
            arguments: ["evolve", "Evolved to apex",
                        ISO8601DateFormatter().string(from: Date())]
        )

        // 1. The stand-in "real" database was never opened, read, or
        // written — byte-for-byte identical to before.
        let sentinelAfter = try Data(contentsOf: URL(fileURLWithPath: fakeRealDBPath))
        XCTAssertEqual(sentinelBefore, sentinelAfter,
            "a test-mode-shaped write touched the stand-in real database")

        // 2. The write actually landed — on the scratch path, proving this
        // isn't passing merely because nothing was written anywhere.
        let xp = try coordinator.database.queryScalarInt(
            "SELECT xp FROM creature WHERE id = 1")
        XCTAssertEqual(xp, 12345)
    }

    // MARK: - persistenceEnabled gates the heartbeat writer

    /// `heartbeat.start()` (the periodic writer, "writes immediately, then
    /// every 30 seconds") is gated behind `if persistenceEnabled` in
    /// StateCoordinator.start() — with persistenceEnabled: false it must
    /// never run, so `/tmp/pushling.heartbeat` is left exactly as found.
    ///
    /// `/tmp/pushling.heartbeat` is a real, machine-global, fixed path a
    /// genuine running daemon on this machine may own — this test quiesces
    /// it for its own brief synchronous duration (moving any existing file
    /// aside) rather than writing over it, and restores the original
    /// exactly in `defer`, so it never races a real daemon's own 30s writer
    /// cycle or corrupts real crash-recovery state.
    func testPersistenceDisabledSkipsHeartbeatWriter() throws {
        let heartbeatPath = HeartbeatManager.heartbeatPath
        let quiescedBackupPath = heartbeatPath + ".wo33-test-backup"
        let fm = FileManager.default
        let hadExistingHeartbeat = fm.fileExists(atPath: heartbeatPath)

        if hadExistingHeartbeat {
            try fm.moveItem(atPath: heartbeatPath, toPath: quiescedBackupPath)
        }
        defer {
            try? fm.removeItem(atPath: heartbeatPath)
            if hadExistingHeartbeat {
                try? fm.moveItem(atPath: quiescedBackupPath, toPath: heartbeatPath)
            }
        }

        let scratchDBPath = NSTemporaryDirectory()
            + "pushling-wo33-heartbeat-\(UUID().uuidString).db"
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? fm.removeItem(atPath: scratchDBPath + suffix)
            }
        }

        let coordinator = StateCoordinator()
        try coordinator.start(databasePath: scratchDBPath, persistenceEnabled: false)
        defer { coordinator.shutdown() }

        XCTAssertFalse(coordinator.persistenceEnabled)
        XCTAssertFalse(fm.fileExists(atPath: heartbeatPath),
            "persistenceEnabled: false must not create/write a heartbeat file")
    }

    // MARK: - TestModeConfig / TestTimeProvider plumbing

    /// `TestModeConfig.isActive` (the cheap gate main.swift/AppDelegate use,
    /// mirroring WorkbenchMode.isActive) must default to false so a normal
    /// `swift test` run or daemon launch never takes the test-mode path.
    func testTestModeConfigIsActiveDefaultsFalseOutsideTestModeLaunch() {
        XCTAssertFalse(TestModeConfig.isActive)
        XCTAssertFalse(TestModeConfig.fromProcessArguments().isActive)
        XCTAssertFalse(TestModeConfig.production.isActive)
    }

    /// TestTimeProvider only accelerates time when its config is active —
    /// the exact plumbing setupTestMode() wires LifecycleSimulator against.
    func testTestTimeProviderAccelerationOnlyAppliesWhenConfigActive() {
        let inactive = TestTimeProvider(config: .production)
        XCTAssertFalse(inactive.isTestMode)
        XCTAssertEqual(inactive.xpMultiplier, 1.0)
        XCTAssertEqual(inactive.simulatedDay, 0)

        let active = TestTimeProvider(config: TestModeConfig(
            isActive: true, xpMultiplier: 100, timeAcceleration: 1440,
            autoFeed: true, simulatedCommitsPerDay: 10
        ))
        XCTAssertTrue(active.isTestMode)
        XCTAssertEqual(active.xpMultiplier, 100)

        Thread.sleep(forTimeInterval: 0.05)
        let delta = active.now.timeIntervalSince(Date())
        // At 1440x acceleration, ~0.05s of real elapsed time simulates
        // ~72s ahead of wall-clock — comfortably clear of timing jitter.
        XCTAssertGreaterThan(delta, 1.0)
    }
}
