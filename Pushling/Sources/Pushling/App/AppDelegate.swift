// AppDelegate.swift — Pushling menu-bar daemon
// Creates an NSStatusItem, manages app lifecycle, no dock icon, no windows.

import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var touchBarController: TouchBarController?
    private var debugOverlayEnabled = false

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupTouchBar()

        NSLog("[Pushling] Daemon started — menu bar active, Touch Bar initializing")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[Pushling] Shutting down — releasing Touch Bar")
        touchBarController?.dismiss()
    }

    /// Keep the app running even if all windows are closed (there are none).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // Placeholder icon: the letter "P" until we have a proper icon
            button.title = "P"
            button.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        }

        let menu = NSMenu()

        let aboutItem = NSMenuItem(
            title: "About Pushling",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let debugItem = NSMenuItem(
            title: "Toggle Debug Overlay",
            action: #selector(toggleDebugOverlay),
            keyEquivalent: "d"
        )
        debugItem.target = self
        menu.addItem(debugItem)

        menu.addItem(NSMenuItem.separator())

        let launchAgentItem = NSMenuItem(
            title: "Install Launch Agent",
            action: #selector(toggleLaunchAgent(_:)),
            keyEquivalent: ""
        )
        launchAgentItem.target = self
        menu.addItem(launchAgentItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Pushling",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Update launch agent menu item state on menu open
        menu.delegate = self
    }

    // MARK: - Touch Bar

    private func setupTouchBar() {
        touchBarController = TouchBarController()
        touchBarController?.present()
    }

    // MARK: - Actions

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Pushling"
        alert.informativeText = """
            A Touch Bar virtual pet that grows with your code.

            Version 0.1.0 (Phase 1 Scaffold)
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleDebugOverlay() {
        debugOverlayEnabled.toggle()
        touchBarController?.setDebugOverlay(enabled: debugOverlayEnabled)
        NSLog("[Pushling] Debug overlay: \(debugOverlayEnabled ? "ON" : "OFF")")
    }

    @objc private func toggleLaunchAgent(_ sender: NSMenuItem) {
        let manager = LaunchAgentManager()

        if manager.isInstalled {
            manager.uninstall()
            NSLog("[Pushling] Launch agent removed")
        } else {
            manager.install()
            NSLog("[Pushling] Launch agent installed")
        }
    }

    @objc private func quitApp() {
        // Clean shutdown: dismiss Touch Bar, then terminate
        touchBarController?.dismiss()
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update the launch agent menu item title based on current state
        let manager = LaunchAgentManager()
        if let launchItem = menu.items.first(where: {
            $0.action == #selector(toggleLaunchAgent(_:))
        }) {
            launchItem.title = manager.isInstalled
                ? "Remove Launch Agent"
                : "Install Launch Agent"
        }
    }
}
