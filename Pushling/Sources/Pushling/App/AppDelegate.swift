// AppDelegate.swift — Pushling menu-bar daemon
// Creates an NSStatusItem, manages app lifecycle, no dock icon, no windows.

import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var touchBarController: TouchBarController?
    private var stateCoordinator: StateCoordinator?
    private var socketServer: SocketServer?
    private var debugOverlayEnabled = false

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Pushling] Starting up...")

        // 1. State: SQLite database, heartbeat, crash recovery, backups
        let coordinator = StateCoordinator()
        do {
            try coordinator.start()
            NSLog("[Pushling] State coordinator started")
        } catch {
            NSLog("[Pushling] WARNING: State coordinator failed to start: \(error)")
        }
        self.stateCoordinator = coordinator

        // 2. IPC: Unix socket server for MCP communication
        let eventBuffer = EventBuffer()
        let router = CommandRouter(eventBuffer: eventBuffer)
        let server = SocketServer(router: router)
        server.start()
        self.socketServer = server
        NSLog("[Pushling] Socket server started at /tmp/pushling.sock")

        // 3. Feed directory: create if needed for hook events
        let feedDir = NSString(string: "~/.local/share/pushling/feed").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: feedDir, withIntermediateDirectories: true)

        // 4. UI: menu bar status item
        setupStatusItem()

        // 5. Touch Bar: SpriteKit scene with creature
        setupTouchBar()

        NSLog("[Pushling] Daemon started — all systems active")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[Pushling] Shutting down...")
        touchBarController?.dismiss()
        socketServer?.stop()
        stateCoordinator?.shutdown()
        NSLog("[Pushling] Clean shutdown complete")
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
