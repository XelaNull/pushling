// DegradeManager.swift — Degrade rails (WO-43, Ph0 "invisible foundation"
// — plans/track-b-grounded-diorama.md at the workspace root).
//
// Observes 3 OS-level signals that should throttle the scene's render
// cadence: Reduce Motion (Accessibility), thermal pressure, and Low Power
// Mode. Exposes a single `targetFPS` (60 normal, 30 degraded) + a
// `shouldDegrade` flag for future consumers that gate non-essential motion
// (the depth/camera work in WO-45+). Nothing reads `shouldDegrade` for
// motion-gating yet — this WO only wires the FPS hook — but the flag is
// deliberately exposed now so later phases don't have to re-derive it.
//
// Polled on a throttle (matches PushlingScene's existing
// idleTimeoutAccumulator pattern), not KVO-observed — these 3 reads are
// cheap enough that a sub-second poll is unnecessary; NSWorkspace/
// ProcessInfo are queried directly, no caching beyond the throttle.

import Foundation
import AppKit

/// Observes Reduce-Motion, thermal state, and Low Power Mode, and resolves
/// them into one target frame rate + reduce-motion flag for the render
/// loop to honor.
final class DegradeManager {

    // MARK: - Constants

    /// Normal target frame rate — matches the Touch Bar scene's default.
    static let normalFPS = 60

    /// Degraded target frame rate — used when any rail has tripped.
    static let degradedFPS = 30

    // MARK: - State (sampled by `refresh()`)

    /// True if Reduce Motion is enabled in System Settings > Accessibility.
    private(set) var isReduceMotionEnabled = false

    /// True if the system thermal state is `.serious` or `.critical`.
    private(set) var isThermalPressureHigh = false

    /// True if Low Power Mode is enabled.
    private(set) var isLowPowerModeEnabled = false

    // MARK: - Public API

    /// True if ANY degrade rail has tripped. Exposed for future
    /// motion-gating consumers (WO-45+) — the reduce-motion flag the WO-43
    /// contract calls for.
    var shouldDegrade: Bool {
        Self.combinedShouldDegrade(reduceMotion: isReduceMotionEnabled,
                                    thermalSerious: isThermalPressureHigh,
                                    lowPower: isLowPowerModeEnabled)
    }

    /// The target frame rate given current degrade conditions.
    var targetFPS: Int {
        Self.resolveTargetFPS(shouldDegrade: shouldDegrade)
    }

    /// Re-samples all 3 OS signals. Call on a throttle (e.g. once/second),
    /// not every frame — see `PushlingScene`'s wiring.
    func refresh() {
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isThermalPressureHigh = Self.isThermalStateSerious(ProcessInfo.processInfo.thermalState)
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Pure Helpers (testable without faking NSWorkspace/ProcessInfo)

    /// Combines the 3 raw rail booleans into one degrade flag.
    static func combinedShouldDegrade(reduceMotion: Bool, thermalSerious: Bool,
                                       lowPower: Bool) -> Bool {
        reduceMotion || thermalSerious || lowPower
    }

    /// Resolves the target FPS from the combined degrade flag.
    static func resolveTargetFPS(shouldDegrade: Bool) -> Int {
        shouldDegrade ? degradedFPS : normalFPS
    }

    /// True for the 2 thermal states considered "under pressure."
    /// `.nominal` and `.fair` are normal operating range; `.serious` and
    /// `.critical` are the OS actively asking apps to back off.
    static func isThermalStateSerious(_ state: ProcessInfo.ThermalState) -> Bool {
        state == .serious || state == .critical
    }
}
