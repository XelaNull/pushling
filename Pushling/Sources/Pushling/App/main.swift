// main.swift — Pushling entry point
// Launches the menu-bar daemon with no dock icon, no main window.

import AppKit

// Prevent multiple instances — only one Pushling should run at a time.
let runningApps = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.pushling.app"
)
let otherInstances = runningApps.filter { $0 != NSRunningApplication.current }
if !otherInstances.isEmpty {
    NSLog("[Pushling] Another instance is already running (PID %d). Exiting.",
          otherInstances.first?.processIdentifier ?? 0)
    exit(0)
}

// Mark as accessory (LSUIElement) — no dock icon, no app switcher entry.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
