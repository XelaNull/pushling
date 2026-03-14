// TouchBarProvider.swift — Protocol abstracting Touch Bar presentation
// All private API access is isolated behind this protocol.
// If Apple changes the DFR API, only TouchBarController.swift needs updating.

import AppKit

/// Abstraction for Touch Bar presentation.
/// Implementations may use private DFR APIs or future public APIs.
protocol TouchBarProvider: AnyObject {
    /// Whether the Touch Bar hardware is available on this machine.
    var isAvailable: Bool { get }

    /// Present our custom Touch Bar, replacing the system strip.
    func present()

    /// Dismiss our Touch Bar and restore the system default.
    func dismiss()

    /// Enable or disable the debug FPS overlay.
    func setDebugOverlay(enabled: Bool)
}
