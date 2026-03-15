// AppDelegate.swift — Pushling menu-bar daemon
// Creates an NSStatusItem, manages app lifecycle, no dock icon, no windows.
// Debug submenu provides testing actions for all creature subsystems.

import AppKit
import SpriteKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var touchBarController: TouchBarController?
    private var stateCoordinator: StateCoordinator?
    private var socketServer: SocketServer?
    private var debugOverlayEnabled = false

    /// Debug action handler — created lazily when the debug menu is opened.
    private var debugActions: DebugActions?

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

        // Version header (non-clickable)
        let versionItem = NSMenuItem(title: "Pushling v0.1.0-dev", action: nil, keyEquivalent: "")
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

    // MARK: - Debug Submenu

    private func buildDebugSubmenu() -> NSMenu {
        let menu = NSMenu(title: "Debug")

        // --- Feed Commits ---
        let feedHeader = NSMenuItem(title: "Feed Commits", action: nil, keyEquivalent: "")
        feedHeader.isEnabled = false
        menu.addItem(feedHeader)

        addMenuItem(to: menu, title: "Feed Small Commit (10 lines)",
                    action: #selector(debugFeedSmallCommit))
        addMenuItem(to: menu, title: "Feed Large Commit (200 lines)",
                    action: #selector(debugFeedLargeCommit))
        addMenuItem(to: menu, title: "Feed Test Commit",
                    action: #selector(debugFeedTestCommit))
        addMenuItem(to: menu, title: "Feed 10 Commits",
                    action: #selector(debugFeed10Commits))
        addMenuItem(to: menu, title: "Feed 50 Commits",
                    action: #selector(debugFeed50Commits))

        menu.addItem(NSMenuItem.separator())

        // --- Change Stage ---
        let stageHeader = NSMenuItem(title: "Change Stage", action: nil, keyEquivalent: "")
        stageHeader.isEnabled = false
        menu.addItem(stageHeader)

        addMenuItem(to: menu, title: "Set Stage: Spore",
                    action: #selector(debugSetSpore))
        addMenuItem(to: menu, title: "Set Stage: Drop",
                    action: #selector(debugSetDrop))
        addMenuItem(to: menu, title: "Set Stage: Critter",
                    action: #selector(debugSetCritter))
        addMenuItem(to: menu, title: "Set Stage: Beast",
                    action: #selector(debugSetBeast))
        addMenuItem(to: menu, title: "Set Stage: Sage",
                    action: #selector(debugSetSage))
        addMenuItem(to: menu, title: "Set Stage: Apex",
                    action: #selector(debugSetApex))

        menu.addItem(NSMenuItem.separator())

        // --- Evolution ---
        let evolveHeader = NSMenuItem(title: "Evolution", action: nil, keyEquivalent: "")
        evolveHeader.isEnabled = false
        menu.addItem(evolveHeader)

        addMenuItem(to: menu, title: "Evolve Now",
                    action: #selector(debugEvolveNow))

        menu.addItem(NSMenuItem.separator())

        // --- Speech ---
        let speechHeader = NSMenuItem(title: "Test Speech", action: nil, keyEquivalent: "")
        speechHeader.isEnabled = false
        menu.addItem(speechHeader)

        addMenuItem(to: menu, title: "Say Hello",
                    action: #selector(debugSayHello))
        addMenuItem(to: menu, title: "Say Long Message",
                    action: #selector(debugSayLong))
        addMenuItem(to: menu, title: "Test First Word",
                    action: #selector(debugTestFirstWord))

        menu.addItem(NSMenuItem.separator())

        // --- Weather ---
        let weatherHeader = NSMenuItem(title: "Test Weather", action: nil, keyEquivalent: "")
        weatherHeader.isEnabled = false
        menu.addItem(weatherHeader)

        addMenuItem(to: menu, title: "Set Clear",
                    action: #selector(debugWeatherClear))
        addMenuItem(to: menu, title: "Set Rain",
                    action: #selector(debugWeatherRain))
        addMenuItem(to: menu, title: "Set Storm",
                    action: #selector(debugWeatherStorm))
        addMenuItem(to: menu, title: "Set Snow",
                    action: #selector(debugWeatherSnow))

        menu.addItem(NSMenuItem.separator())

        // --- Interactions ---
        let interactionHeader = NSMenuItem(
            title: "Test Interactions", action: nil, keyEquivalent: ""
        )
        interactionHeader.isEnabled = false
        menu.addItem(interactionHeader)

        addMenuItem(to: menu, title: "Test Cat Behavior",
                    action: #selector(debugTestCatBehavior))

        menu.addItem(NSMenuItem.separator())

        // --- Info ---
        let infoHeader = NSMenuItem(title: "Info", action: nil, keyEquivalent: "")
        infoHeader.isEnabled = false
        menu.addItem(infoHeader)

        addMenuItem(to: menu, title: "Show Stats (Console)",
                    action: #selector(debugShowStats))

        return menu
    }

    /// Helper to add a menu item with a target.
    private func addMenuItem(to menu: NSMenu, title: String,
                             action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    /// Lazily creates or returns the debug actions handler.
    private func ensureDebugActions() -> DebugActions {
        if let existing = debugActions {
            existing.updateScene(touchBarController?.currentScene)
            return existing
        }
        let actions = DebugActions(scene: touchBarController?.currentScene)
        debugActions = actions
        return actions
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

    // MARK: - Debug Actions: Feed Commits

    @objc private func debugFeedSmallCommit() {
        ensureDebugActions().feedSmallCommit()
    }

    @objc private func debugFeedLargeCommit() {
        ensureDebugActions().feedLargeCommit()
    }

    @objc private func debugFeedTestCommit() {
        ensureDebugActions().feedTestCommit()
    }

    @objc private func debugFeed10Commits() {
        ensureDebugActions().feedBatchCommits(count: 10)
    }

    @objc private func debugFeed50Commits() {
        ensureDebugActions().feedBatchCommits(count: 50)
    }

    // MARK: - Debug Actions: Stage

    @objc private func debugSetSpore() {
        ensureDebugActions().setStage(.spore)
    }

    @objc private func debugSetDrop() {
        ensureDebugActions().setStage(.drop)
    }

    @objc private func debugSetCritter() {
        ensureDebugActions().setStage(.critter)
    }

    @objc private func debugSetBeast() {
        ensureDebugActions().setStage(.beast)
    }

    @objc private func debugSetSage() {
        ensureDebugActions().setStage(.sage)
    }

    @objc private func debugSetApex() {
        ensureDebugActions().setStage(.apex)
    }

    // MARK: - Debug Actions: Evolution

    @objc private func debugEvolveNow() {
        ensureDebugActions().evolveNow()
    }

    // MARK: - Debug Actions: Speech

    @objc private func debugSayHello() {
        ensureDebugActions().sayHello()
    }

    @objc private func debugSayLong() {
        ensureDebugActions().sayLongMessage()
    }

    @objc private func debugTestFirstWord() {
        ensureDebugActions().testFirstWord()
    }

    // MARK: - Debug Actions: Weather

    @objc private func debugWeatherClear() {
        ensureDebugActions().setWeather(.clear)
    }

    @objc private func debugWeatherRain() {
        ensureDebugActions().setWeather(.rain)
    }

    @objc private func debugWeatherStorm() {
        ensureDebugActions().setWeather(.storm)
    }

    @objc private func debugWeatherSnow() {
        ensureDebugActions().setWeather(.snow)
    }

    // MARK: - Debug Actions: Interactions

    @objc private func debugTestCatBehavior() {
        ensureDebugActions().testCatBehavior()
    }

    // MARK: - Debug Actions: Info

    @objc private func debugShowStats() {
        ensureDebugActions().showStats()
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
