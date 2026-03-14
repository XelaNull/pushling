// FrameBudgetMonitor.swift — Frame timing and budget enforcement
// Measures time spent in update() each frame, warns on budget overruns.
//
// Budget thresholds (from CLAUDE.md):
//   - Target total: < 5.7ms (65% headroom at 60fps)
//   - Warning: > 10ms (60% of 16.6ms budget)
//   - Error: > 14ms (approaching dropped frame)
//   - Frame budget: 16.6ms at 60fps

import Foundation

/// Frame timing statistics for the debug overlay.
struct FrameStats {
    let fps: Double
    let averageFrameTimeMs: Double
    let lastFrameTimeMs: Double
    let maxFrameTimeMs: Double
}

/// Monitors per-frame time spent in the update loop.
/// Tracks a rolling window of frame times and logs budget overruns.
final class FrameBudgetMonitor {

    // MARK: - Constants

    /// Number of frames in the rolling average window.
    private static let windowSize = 60

    /// Warning threshold in seconds (10ms = 60% of 16.6ms budget).
    private static let warningThreshold: Double = 0.010

    /// Error threshold in seconds (14ms = approaching dropped frame).
    private static let errorThreshold: Double = 0.014

    /// Minimum interval between log messages to avoid log spam (seconds).
    private static let logThrottleInterval: Double = 2.0

    // MARK: - State

    /// Circular buffer of frame times (seconds).
    private var frameTimes: [Double]

    /// Current write position in the circular buffer.
    private var frameIndex = 0

    /// Total number of frames recorded (for average calculation before buffer is full).
    private var totalFrames = 0

    /// Timestamp when the current frame's update() began.
    private var frameStartTime: UInt64 = 0

    /// Last time we logged a warning (to throttle).
    private var lastWarningLogTime: Double = 0

    /// Last time we logged an error (to throttle).
    private var lastErrorLogTime: Double = 0

    /// The maximum frame time observed in the current window.
    private var maxFrameTime: Double = 0

    /// Mach timebase info for converting ticks to nanoseconds.
    private let timebaseInfo: mach_timebase_info_data_t

    // MARK: - Init

    init() {
        frameTimes = Array(repeating: 0, count: Self.windowSize)

        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebaseInfo = info
    }

    // MARK: - Frame Timing

    /// Call at the start of the scene's update() method.
    func beginFrame() {
        frameStartTime = mach_absolute_time()
    }

    /// Call at the end of the scene's update() method.
    /// Logs warnings/errors if budget is exceeded.
    func endFrame() {
        let endTime = mach_absolute_time()
        let elapsed = endTime - frameStartTime

        // Convert mach ticks to seconds
        let nanoseconds = elapsed * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
        let seconds = Double(nanoseconds) / 1_000_000_000.0

        // Record in circular buffer
        frameTimes[frameIndex] = seconds
        frameIndex = (frameIndex + 1) % Self.windowSize
        totalFrames += 1

        // Track max
        if seconds > maxFrameTime {
            maxFrameTime = seconds
        }

        // Check budget thresholds
        let now = ProcessInfo.processInfo.systemUptime

        if seconds > Self.errorThreshold {
            if now - lastErrorLogTime > Self.logThrottleInterval {
                let ms = seconds * 1000.0
                NSLog("[Pushling] FRAME BUDGET ERROR: %.1fms (limit: 14ms) — frame may drop", ms)
                lastErrorLogTime = now
            }
        } else if seconds > Self.warningThreshold {
            if now - lastWarningLogTime > Self.logThrottleInterval {
                let ms = seconds * 1000.0
                NSLog("[Pushling] Frame budget warning: %.1fms (limit: 10ms)", ms)
                lastWarningLogTime = now
            }
        }
    }

    // MARK: - Statistics

    /// Current frame statistics for the debug overlay.
    var currentStats: FrameStats {
        let count = min(totalFrames, Self.windowSize)
        guard count > 0 else {
            return FrameStats(fps: 0, averageFrameTimeMs: 0, lastFrameTimeMs: 0, maxFrameTimeMs: 0)
        }

        // Calculate average frame time over the window
        var sum: Double = 0
        for i in 0..<count {
            sum += frameTimes[i]
        }
        let average = sum / Double(count)

        // FPS from average frame time
        let fps = average > 0 ? 1.0 / average : 0

        // Last frame time
        let lastIndex = (frameIndex - 1 + Self.windowSize) % Self.windowSize
        let lastFrameTime = frameTimes[lastIndex]

        return FrameStats(
            fps: min(fps, 60),  // Cap at 60 since that's our target
            averageFrameTimeMs: average * 1000.0,
            lastFrameTimeMs: lastFrameTime * 1000.0,
            maxFrameTimeMs: maxFrameTime * 1000.0
        )
    }

    /// Reset the max frame time tracker (useful after known heavy operations).
    func resetMax() {
        maxFrameTime = 0
    }
}
