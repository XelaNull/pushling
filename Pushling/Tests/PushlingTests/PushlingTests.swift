// PushlingTests.swift — Unit tests for Pushling scaffold

import XCTest
@testable import Pushling

final class FrameBudgetMonitorTests: XCTestCase {

    func testInitialStatsAreZero() {
        let monitor = FrameBudgetMonitor()
        let stats = monitor.currentStats
        XCTAssertEqual(stats.fps, 0)
        XCTAssertEqual(stats.averageFrameTimeMs, 0)
        XCTAssertEqual(stats.lastFrameTimeMs, 0)
        XCTAssertEqual(stats.maxFrameTimeMs, 0)
    }

    func testFrameTimingRecords() {
        let monitor = FrameBudgetMonitor()

        // Simulate a few frames
        for _ in 0..<5 {
            monitor.beginFrame()
            // Simulate minimal work
            _ = (0..<100).reduce(0, +)
            monitor.endFrame()
        }

        let stats = monitor.currentStats
        // After recording frames, we should have non-zero values
        XCTAssertGreaterThan(stats.averageFrameTimeMs, 0)
        XCTAssertGreaterThan(stats.lastFrameTimeMs, 0)
    }

    func testResetMax() {
        let monitor = FrameBudgetMonitor()

        monitor.beginFrame()
        // Burn some time
        var sum = 0
        for i in 0..<10000 { sum += i }
        _ = sum
        monitor.endFrame()

        XCTAssertGreaterThan(monitor.currentStats.maxFrameTimeMs, 0)

        monitor.resetMax()
        XCTAssertEqual(monitor.currentStats.maxFrameTimeMs, 0)
    }
}

final class LaunchAgentManagerTests: XCTestCase {

    func testPlistPath() {
        let manager = LaunchAgentManager()
        // The installed flag should be deterministic
        // (we don't test install/uninstall to avoid modifying the system)
        _ = manager.isInstalled
    }
}
