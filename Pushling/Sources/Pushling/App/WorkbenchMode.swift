// WorkbenchMode.swift — Desktop animation-debugger launch mode
// Launched with: pushling --workbench [--workbench-scale=6]
//
// Opens an NSWindow presenting the REAL PushlingScene (same drawing code,
// same behavior stack — nothing forked) magnified for iteration on a
// normal Mac screen. Sidesteps the Touch Bar's broken gesture input
// (TouchBarView.swift:56) and the tiny 30pt strip entirely.
//
// Coexists with a running daemon by design: skips the socket server,
// hooks, hot-reload monitor, and menu-bar status item (see
// AppDelegate.setupWorkbench) so it never steals /tmp/pushling.sock or
// restarts the live pet out from under the human.
//
// It opens the daemon's SQLite state.db READ-ONLY in spirit: the workbench
// reads the real creature's stage/personality/emotion at launch (so it
// reflects the actual pet, not a fresh one) but writes NOTHING back. Every
// creature-state write path is suppressed in workbench mode — persistence,
// heartbeat, backup, and the commit-feed pipeline are all gated behind
// `StateCoordinator.persistenceEnabled == false` (threaded from
// setupWorkbench), and the two scene-side raw writes that sit outside that
// flag (PushlingScene's journal-entry closure, WorldManager object/companion
// CRUD) are gated directly on `WorkbenchMode.isActive`. Net invariant:
// launching --workbench beside the live daemon leaves state.db, the feed
// dir, /tmp/pushling.heartbeat, and the backups byte-for-byte untouched.
// (This closes the roadmap's flagged two-process corruption risk rather than
// merely accepting it — see the Mack audit that enumerated the write paths.)
//
// Workbench mode is detected by checking ProcessInfo arguments, mirroring
// TestMode.swift's argument-parsing pattern.

import Foundation
import CoreGraphics

enum WorkbenchMode {

    /// Default magnification when --workbench-scale is not given.
    /// Falls within the 4-8x range the depth-vision roadmap calls for;
    /// the window is still clamped to fit the screen regardless — see
    /// WorkbenchWindowController.clampedWindowSize.
    static let defaultMagnification: CGFloat = 6.0

    /// Whether --workbench was passed on the command line.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--workbench")
    }

    /// Requested magnification factor (before screen-fit clamping).
    static var magnification: CGFloat {
        let key = "--workbench-scale="
        for arg in ProcessInfo.processInfo.arguments where arg.hasPrefix(key) {
            let value = String(arg.dropFirst(key.count))
            if let parsed = Double(value), parsed > 0 {
                return CGFloat(parsed)
            }
        }
        return defaultMagnification
    }
}
