// WorkbenchWindowController.swift — hosts the desktop animation-debugger window
// An NSWindow + SKView presenting a live PushlingScene magnified for
// iteration. Same construction order as TouchBarController.makeSceneItem:
// scene created and presented into the view FIRST (so didMove(to:) sets up
// behaviorStack), THEN GameCoordinator is wired against it — GameCoordinator's
// init reads scene.behaviorStack?.reflexes and would find it nil otherwise.
//
// Increment-1 scope (WO-7): shell only. No control panel, bodyState trigger
// grid, onion-skin, or PNG capture yet — those are P2's later work orders.

import AppKit
import SpriteKit

final class WorkbenchWindowController: NSWindowController {

    /// The live scene this workbench presents — same drawing code, same
    /// behavior stack as the Touch Bar path, nothing forked.
    let scene: PushlingScene

    /// Fully-wired GameCoordinator so the scene is live (state, behavior
    /// stack, emotional state, etc. all running) rather than a static prop.
    let gameCoordinator: GameCoordinator

    /// Local command routing — not bound to the socket. Workbench mode
    /// never starts a SocketServer (it would unlink and steal the live
    /// daemon's /tmp/pushling.sock — see SocketServer.swift:70), so these
    /// exist purely to satisfy GameCoordinator's wiring contract.
    private let eventBuffer = EventBuffer()
    private let commandRouter: CommandRouter

    init(stateCoordinator: StateCoordinator) {
        let sceneSize = CGSize(
            width: SceneConstants.sceneWidth,
            height: SceneConstants.sceneHeight
        )

        let pushlingScene = PushlingScene(size: sceneSize)
        pushlingScene.scaleMode = .aspectFit
        pushlingScene.anchorPoint = CGPoint(x: 0, y: 0)
        pushlingScene.backgroundColor = SKColor.black
        self.scene = pushlingScene

        let windowSize = Self.clampedWindowSize(
            sceneSize: sceneSize,
            magnification: WorkbenchMode.magnification
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pushling Workbench"
        window.contentAspectRatio = sceneSize  // resizing preserves the strip's proportions
        window.center()

        let view = SKView(frame: NSRect(origin: .zero, size: windowSize))
        view.preferredFramesPerSecond = 60
        view.allowsTransparency = false
        view.autoresizingMask = [.width, .height]

        // Present BEFORE constructing GameCoordinator — didMove(to:) is what
        // sets scene.behaviorStack, which GameCoordinator.init reads.
        view.presentScene(pushlingScene)
        window.contentView = view

        let router = CommandRouter(eventBuffer: eventBuffer)
        self.commandRouter = router

        let game = GameCoordinator(
            scene: pushlingScene,
            stateCoordinator: stateCoordinator,
            commandRouter: router,
            eventBuffer: eventBuffer
        )
        pushlingScene.gameCoordinator = game
        router.gameCoordinator = game
        self.gameCoordinator = game

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WorkbenchWindowController does not support NSCoder")
    }

    /// Bring the workbench window to front and activate the app so it can
    /// receive keyboard/mouse focus (accessory apps don't auto-activate).
    func present() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Compute a window size at the requested magnification, clamped to fit
    /// the main screen's visible frame — at 1085x30 native, 4-8x magnifies
    /// past most laptop screen widths, so this fits-to-screen instead of
    /// spawning a window nobody can see in full.
    private static func clampedWindowSize(
        sceneSize: CGSize, magnification: CGFloat
    ) -> CGSize {
        let desired = CGSize(
            width: sceneSize.width * magnification,
            height: sceneSize.height * magnification
        )
        guard let screen = NSScreen.main, desired.width > screen.visibleFrame.width * 0.9 else {
            return desired
        }
        let fittedScale = (screen.visibleFrame.width * 0.9) / sceneSize.width
        return CGSize(
            width: sceneSize.width * fittedScale,
            height: sceneSize.height * fittedScale
        )
    }
}
