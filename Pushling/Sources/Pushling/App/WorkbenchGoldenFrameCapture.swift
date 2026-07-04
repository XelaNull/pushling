// WorkbenchGoldenFrameCapture.swift — WO-7 incr 2-3, golden-frame capture.
//
// Captures the creature's current rendered pose to a PNG on disk — the
// artifact the eventual bake pipeline's (animation-architecture-master-
// plan.md §3.4/§5 P0) golden-frame comparison is checked against.
//
// Reuses `PushlingScene.captureScreenshot()` UNCHANGED — no new capture
// code. Called DIRECTLY from the main-thread button handler, NOT routed
// through `commandRouter`/`handleScreenshot`: that handler internally does
// `DispatchQueue.main.async { ... }; semaphore.wait(...)` (a hop-to-main-
// and-block pattern that only works when the CALLER is on a background
// thread, matching the real socket server's threading model) — calling it
// from a main-thread AppKit action would dispatch-to-main-and-wait FROM
// main, deadlocking. This handler is already on main (an NSButton action),
// so it calls `captureScreenshot()` directly, no hop needed.
//
// The ONLY new write path this WO-7 increment introduces — everything
// else (state.db, feed dir, heartbeat, backups) stays untouched per
// WorkbenchMode's existing write-suppression contract.

import AppKit

extension WorkbenchWindowController {

    /// `~/.local/share/pushling/golden-frames/` — created on first
    /// capture if absent. Deliberately separate from
    /// `~/.local/share/pushling/state.db`/feed/backups — this is a new,
    /// human-triggered debug artifact directory, not creature-state
    /// persistence, so it doesn't touch anything WorkbenchMode's
    /// no-persistence contract already guards.
    private static var goldenFramesDirectory: URL {
        // Matches the daemon's existing `~/.local/share/pushling/...`
        // layout (StateCoordinator/HookEventProcessor's own convention)
        // rather than Application Support.
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/share/pushling/golden-frames", isDirectory: true)
    }

    @objc func captureGoldenFrameButtonTapped(_ sender: NSButton) {
        // Already on main (NSButton action) — call captureScreenshot()
        // directly, no queue hop. See file header for why routing through
        // CommandRouter's `screenshot` command here would deadlock.
        guard let pngData = scene.captureScreenshot() else {
            statusLabel.stringValue = "Capture failed — see Console"
            NSLog("[Pushling/Workbench] Golden-frame capture failed — captureScreenshot() returned nil")
            return
        }

        let stage: String
        if let currentStage = scene.creatureNode?.currentStage {
            stage = "\(currentStage)"
        } else {
            stage = "unknown"
        }
        let label = lastTriggeredLabel
        let fileName = "\(stage)-\(label).png"
        let directory = Self.goldenFramesDirectory

        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let fileURL = directory.appendingPathComponent(fileName)
            try pngData.write(to: fileURL)
            statusLabel.stringValue = "Captured: \(fileName)"
            NSLog("[Pushling/Workbench] Golden frame written: %@ (%d bytes)",
                  fileURL.path, pngData.count)
        } catch {
            statusLabel.stringValue = "Capture write failed — see Console"
            NSLog("[Pushling/Workbench] Golden-frame write failed: %@",
                  error.localizedDescription)
        }
    }
}
