// AppDelegate.swift — Pushling menu-bar daemon
// Creates an NSStatusItem, manages app lifecycle, no dock icon, no windows.
// Debug submenu provides testing actions for all creature subsystems.

import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    var touchBarController: TouchBarController?
    private var stateCoordinator: StateCoordinator?
    private var socketServer: SocketServer?
    var gameCoordinator: GameCoordinator?
    private var hotReloadMonitor: HotReloadMonitor?
    private var debugOverlayEnabled = false

    /// Debug action handler — created lazily when the debug menu is opened.
    var debugActions: DebugActions?

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

        // 6. GameCoordinator: wire all 16 subsystems together
        if let scene = touchBarController?.currentScene,
           let stateCoord = self.stateCoordinator {
            let game = GameCoordinator(
                scene: scene,
                stateCoordinator: stateCoord,
                commandRouter: router,
                eventBuffer: eventBuffer
            )
            scene.gameCoordinator = game
            self.gameCoordinator = game
            router.gameCoordinator = game
            NSLog("[Pushling] GameCoordinator active — all subsystems wired, "
                  + "CommandRouter dispatch live")
        } else {
            NSLog("[Pushling] WARNING: No scene available — "
                  + "GameCoordinator not created")
        }

        // 7. Auto-install hooks and MCP (first launch only)
        if !UserDefaults.standard.bool(forKey: "hooksInstalled") {
            DispatchQueue.global(qos: .utility).async {
                HookInstaller.installAll()
            }
        }

        // 8. Hot-reload monitor: watch for new binary builds
        let monitor = HotReloadMonitor()
        monitor.onNewBinaryDetected = { [weak self] in
            self?.performGracefulRestart(reason: "new binary detected")
        }
        monitor.start()
        self.hotReloadMonitor = monitor

        NSLog("[Pushling] Daemon started — all systems active")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[Pushling] Shutting down...")
        hotReloadMonitor?.stop()
        gameCoordinator?.shutdown()
        touchBarController?.dismiss()
        socketServer?.stop()
        stateCoordinator?.shutdown()
        NSLog("[Pushling] Clean shutdown complete")
    }

    /// Graceful restart: save all state, tear down subsystems, exit.
    /// LaunchAgent's KeepAlive will relaunch with the new binary.
    func performGracefulRestart(reason: String) {
        NSLog("[Pushling] Graceful restart: %@", reason)
        hotReloadMonitor?.stop()
        gameCoordinator?.shutdown()
        touchBarController?.dismiss()
        socketServer?.stop()
        stateCoordinator?.shutdown()
        NSLog("[Pushling] State saved — exiting for restart")
        exit(0)
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

        // Version header (non-clickable)
        let versionItem = NSMenuItem(title: "Pushling v\(PushlingVersion.string)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About Pushling",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let toggleTBItem = NSMenuItem(
            title: "Toggle Touch Bar",
            action: #selector(toggleTouchBar),
            keyEquivalent: "t"
        )
        toggleTBItem.target = self
        menu.addItem(toggleTBItem)

        let resetFogItem = NSMenuItem(
            title: "Reset Explored Areas",
            action: #selector(resetExploredAreas),
            keyEquivalent: ""
        )
        resetFogItem.target = self
        menu.addItem(resetFogItem)

        let resetAllItem = NSMenuItem(
            title: "Reset All Progress...",
            action: #selector(resetAllProgress),
            keyEquivalent: ""
        )
        resetAllItem.target = self
        menu.addItem(resetAllItem)

        let debugItem = NSMenuItem(
            title: "Toggle Debug Overlay",
            action: #selector(toggleDebugOverlay),
            keyEquivalent: "d"
        )
        debugItem.target = self
        menu.addItem(debugItem)

        // Debug submenu
        let debugSubmenu = buildDebugSubmenu()
        let debugSubmenuItem = NSMenuItem(
            title: "Debug",
            action: nil,
            keyEquivalent: ""
        )
        debugSubmenuItem.submenu = debugSubmenu
        menu.addItem(debugSubmenuItem)

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

    // MARK: - Debug Submenu (see AppDelegate+Debug.swift)

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

            Version \(PushlingVersion.string)
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleTouchBar() {
        touchBarController?.toggleVisibility()
    }

    @objc private func resetExploredAreas() {
        touchBarController?.currentScene?.worldManager.fogOfWar?.exploredRanges.reset()
        NSLog("[Pushling] Explored areas reset — fog of war restored")
    }

    @objc private func resetAllProgress() {
        let alert = NSAlert()
        alert.messageText = "Reset All Progress?"
        alert.informativeText = "This will delete all creature data, XP, journal entries, taught behaviors, and start fresh. This cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset Everything")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        NSLog("[Pushling] Resetting all progress...")

        // Delete the database file — app will recreate from schema on restart
        let dbPath = DatabaseManager.shared.databasePath
        gameCoordinator?.shutdown()
        touchBarController?.dismiss()
        socketServer?.stop()
        stateCoordinator?.shutdown()

        // Remove database and WAL files
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(atPath: dbPath + suffix)
        }

        // Reset UserDefaults so consent popups, hooks, and flags re-trigger
        UserDefaults.standard.removeObject(forKey: "githubConsentAsked")
        UserDefaults.standard.removeObject(forKey: "hooksInstalled")
        UserDefaults.standard.removeObject(forKey: "mcpInstalled")

        NSLog("[Pushling] Database + UserDefaults reset — restarting fresh")
        exit(0)  // LaunchAgent will relaunch with clean state
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
