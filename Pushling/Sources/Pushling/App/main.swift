// main.swift — Pushling entry point
// Launches the menu-bar daemon with no dock icon, no main window.

import AppKit

// Mark as accessory (LSUIElement) — no dock icon, no app switcher entry.
// We set this programmatically since SPM executables don't have an Info.plist by default.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
