// TestMode.swift — Accelerated time mode for lifecycle testing
// Launched with: pushling --test-mode --xp-multiplier=100
//
// In test mode:
//   - XP from commits is multiplied by the given factor
//   - 1 real minute = 1 simulated day (time acceleration)
//   - Simulated commits can be batch-fed from JSON files
//   - All frame budgets and node limits still apply
//
// Test mode is detected by checking ProcessInfo arguments, mirroring
// WorkbenchMode.swift's argument-parsing pattern.
//
// Wiring (see AppDelegate.setupTestMode): a --test-mode launch builds its
// own StateCoordinator pointed at a scratch database path (NOT the real
// ~/.local/share/pushling/state.db) with persistenceEnabled: false -- the
// exact same isolation pattern WorkbenchMode uses (see WorkbenchMode.swift)
// -- then presents through WorkbenchWindowController so a simulated life
// never touches the real state.db, feed directory, heartbeat file, or
// backup timeline. LifecycleSimulator's synthetic commit JSON is fed
// directly into that isolated GameCoordinator's
// `feedProcessor.onCommitReceived` -- the same entry point real git
// commits use -- so XP, stage transitions, and hatching all run through
// the real game logic rather than a parallel reimplementation.

import Foundation

// MARK: - Test Mode Configuration

struct TestModeConfig {
    /// Cheap check for whether --test-mode was passed -- mirrors
    /// WorkbenchMode.isActive. Use this for gating (e.g. main.swift's
    /// singleton guard); use `fromProcessArguments()` once per launch for
    /// the full parsed config (it also logs the active configuration).
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--test-mode")
    }

    /// Whether test mode is active.
    let isActive: Bool

    /// XP multiplier (default 1.0, test mode might use 100).
    let xpMultiplier: Double

    /// Time acceleration factor (1 real minute = this many simulated days).
    let timeAcceleration: Double

    /// Whether to auto-feed simulated commits.
    let autoFeed: Bool

    /// Simulated commits per day (in simulated time).
    let simulatedCommitsPerDay: Int

    /// Default production configuration.
    static let production = TestModeConfig(
        isActive: false,
        xpMultiplier: 1.0,
        timeAcceleration: 1.0,
        autoFeed: false,
        simulatedCommitsPerDay: 0
    )

    /// Parse test mode from process arguments.
    static func fromProcessArguments() -> TestModeConfig {
        let args = ProcessInfo.processInfo.arguments

        guard args.contains("--test-mode") else {
            return .production
        }

        let xpMult = parseDouble(from: args, key: "--xp-multiplier") ?? 100.0
        let timeAccel = parseDouble(from: args, key: "--time-accel") ?? 1440.0
        let autoFeed = args.contains("--auto-feed")
        let commitsPerDay = parseInt(from: args, key: "--commits-per-day") ?? 10

        NSLog("[Pushling/Test] TEST MODE ACTIVE — XP: %.0fx, Time: %.0fx, "
              + "AutoFeed: %@, Commits/day: %d",
              xpMult, timeAccel,
              autoFeed ? "yes" : "no", commitsPerDay)

        return TestModeConfig(
            isActive: true,
            xpMultiplier: xpMult,
            timeAcceleration: timeAccel,
            autoFeed: autoFeed,
            simulatedCommitsPerDay: commitsPerDay
        )
    }

    // MARK: - Argument Parsing

    private static func parseDouble(from args: [String],
                                     key: String) -> Double? {
        for arg in args {
            if arg.hasPrefix("\(key)=") {
                let value = String(arg.dropFirst(key.count + 1))
                return Double(value)
            }
        }
        return nil
    }

    private static func parseInt(from args: [String],
                                  key: String) -> Int? {
        for arg in args {
            if arg.hasPrefix("\(key)=") {
                let value = String(arg.dropFirst(key.count + 1))
                return Int(value)
            }
        }
        return nil
    }
}

// MARK: - Test Time Provider

/// Provides accelerated time for test mode.
/// In production, returns real wall clock time.
/// In test mode, 1 real minute = 1 simulated day.
final class TestTimeProvider {

    private let config: TestModeConfig

    /// Real time when test mode started.
    private let startRealTime: Date

    /// Simulated time when test mode started.
    private let startSimulatedTime: Date

    init(config: TestModeConfig = .production) {
        self.config = config
        self.startRealTime = Date()
        self.startSimulatedTime = Date()
    }

    /// Returns the current time (real or simulated).
    var now: Date {
        guard config.isActive else { return Date() }

        let realElapsed = Date().timeIntervalSince(startRealTime)
        // 1440x acceleration means 1 minute = 1 day
        let simulatedElapsed = realElapsed * config.timeAcceleration
        return startSimulatedTime.addingTimeInterval(simulatedElapsed)
    }

    /// Returns the XP multiplier.
    var xpMultiplier: Double {
        config.xpMultiplier
    }

    /// Whether test mode is active.
    var isTestMode: Bool {
        config.isActive
    }

    /// Returns the simulated day number (from test start).
    var simulatedDay: Int {
        guard config.isActive else { return 0 }
        let realElapsed = Date().timeIntervalSince(startRealTime)
        return Int(realElapsed / 60.0)  // 1 minute = 1 day
    }
}
