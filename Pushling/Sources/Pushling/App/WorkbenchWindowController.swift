// WorkbenchWindowController.swift — hosts the desktop animation-debugger window
// An NSWindow + SKView presenting a live PushlingScene magnified for
// iteration. Same construction order as TouchBarController.makeSceneItem:
// scene created and presented into the view FIRST (so didMove(to:) sets up
// behaviorStack), THEN GameCoordinator is wired against it — GameCoordinator's
// init reads scene.behaviorStack?.reflexes and would find it nil otherwise.
//
// WO-7 incr 2-3: adds the true-size mirror inset (WorkbenchTrueSizeMirror.swift),
// the trigger menu (WorkbenchTriggerMenu.swift), and golden-frame capture
// (WorkbenchGoldenFrameCapture.swift) on top of increment-1's shell. Content
// is now a vertical NSStackView [true-size inset · magnified SKView
// (aspect-constrained via Auto Layout) · trigger bar] instead of a bare SKView
// filling the window — the window-level `contentAspectRatio` lock from
// increment-1 is dropped since the window now has non-strip chrome.

import AppKit
import SpriteKit

final class WorkbenchWindowController: NSWindowController {

    /// The live scene this workbench presents — same drawing code, same
    /// behavior stack as the Touch Bar path, nothing forked. Architecture-
    /// agnostic: this presents whatever CreatureNode currently renders
    /// (today's vector rig; later sprite frames per the animation
    /// architecture master plan) — nothing here is rig-specific.
    let scene: PushlingScene

    /// The magnified, LIVE SKView — the sole view the scene is presented
    /// into. The true-size inset is a periodic TEXTURE SNAPSHOT of this
    /// same view (WorkbenchTrueSizeMirror), not a second live presentation
    /// (SpriteKit does not support one scene live in two views at once).
    let skView: SKView

    /// True-size (1085x30pt, matching the real Touch Bar exactly) preview
    /// inset — so "does it read at true size" is judgeable, per the master
    /// plan's §3.4 review-loop requirement.
    let trueSizeImageView: NSImageView

    /// Fully-wired GameCoordinator so the scene is live (state, behavior
    /// stack, emotional state, etc. all running) rather than a static prop.
    let gameCoordinator: GameCoordinator

    /// Local command routing — not bound to the socket. Workbench mode
    /// never starts a SocketServer (it would unlink and steal the live
    /// daemon's /tmp/pushling.sock — see SocketServer.swift:70), so these
    /// exist purely to satisfy GameCoordinator's wiring contract AND to
    /// give the trigger menu (WorkbenchTriggerMenu.swift) the exact same
    /// in-process `route(_:)` entry point a real socket `perform` command
    /// uses — no new IPC path, no session gate (SESSION_REQUIRED is
    /// enforced in SocketServer.processMessage, not CommandRouter itself,
    /// and the workbench never runs a SocketServer).
    let commandRouter: CommandRouter
    private let eventBuffer = EventBuffer()

    /// The label of the last behavior/bodyState the trigger menu fired —
    /// golden-frame capture (WorkbenchGoldenFrameCapture.swift) names its
    /// output file from this + the creature's current stage.
    var lastTriggeredLabel: String = "stand"

    /// Status line in the trigger bar — visual confirmation of the last
    /// action (trigger menu selection or capture result).
    let statusLabel: NSTextField

    /// Owns the 10Hz true-size mirror refresh timer.
    private var trueSizeMirror: WorkbenchTrueSizeMirror?

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

        let magnifiedSize = Self.clampedWindowSize(
            sceneSize: sceneSize,
            magnification: WorkbenchMode.magnification
        )

        // === True-size inset (1085x30pt exactly — the real Touch Bar's
        // own dimensions) ===
        let insetView = NSImageView(frame: NSRect(origin: .zero, size: sceneSize))
        insetView.imageScaling = .scaleProportionallyUpOrDown
        insetView.wantsLayer = true
        insetView.layer?.backgroundColor = NSColor.black.cgColor
        self.trueSizeImageView = insetView

        // === Magnified, LIVE SKView ===
        let view = SKView(frame: NSRect(origin: .zero, size: magnifiedSize))
        view.preferredFramesPerSecond = 60
        view.allowsTransparency = false
        self.skView = view

        // Present BEFORE constructing GameCoordinator — didMove(to:) is what
        // sets scene.behaviorStack, which GameCoordinator.init reads.
        view.presentScene(pushlingScene)

        // === Trigger bar (bottom row: trigger button, capture button, status) ===
        let triggerButton = NSButton(title: "Trigger…", target: nil, action: nil)
        let captureButton = NSButton(title: "Capture Golden Frame", target: nil, action: nil)
        let status = NSTextField(labelWithString: "Ready")
        status.textColor = .secondaryLabelColor
        self.statusLabel = status

        let buttonBar = NSStackView(views: [triggerButton, captureButton, status])
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 8
        buttonBar.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)

        // === Vertical stack: inset -> SKView -> trigger bar ===
        let mainStack = NSStackView(views: [insetView, view, buttonBar])
        mainStack.orientation = .vertical
        mainStack.spacing = 4
        mainStack.alignment = .centerX
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(mainStack)

        insetView.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // True-size inset: fixed at the scene's own exact point size.
            insetView.widthAnchor.constraint(equalToConstant: sceneSize.width),
            insetView.heightAnchor.constraint(equalToConstant: sceneSize.height),

            // Magnified SKView: aspect-constrained via Auto Layout (NOT the
            // window-level `contentAspectRatio` increment-1 used) — width
            // starts at the computed magnification, height follows the
            // scene's own aspect ratio.
            view.widthAnchor.constraint(equalToConstant: magnifiedSize.width),
            view.heightAnchor.constraint(
                equalTo: view.widthAnchor,
                multiplier: sceneSize.height / sceneSize.width
            ),
        ])

        let totalHeight = sceneSize.height + magnifiedSize.height
            + buttonBar.fittingSize.height + mainStack.spacing * 2
        let windowSize = CGSize(width: magnifiedSize.width, height: totalHeight)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pushling Workbench"
        window.center()
        contentView.frame = NSRect(origin: .zero, size: windowSize)
        window.contentView = contentView

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

        // Wire the trigger/capture buttons now that `self` exists (their
        // targets/actions live in WorkbenchTriggerMenu.swift /
        // WorkbenchGoldenFrameCapture.swift).
        triggerButton.target = self
        triggerButton.action = #selector(showTriggerMenu(_:))
        captureButton.target = self
        captureButton.action = #selector(captureGoldenFrameButtonTapped(_:))

        // Start the 10Hz true-size mirror (WorkbenchTrueSizeMirror.swift) —
        // a periodic texture snapshot of `skView`, NOT a second live scene
        // presentation.
        trueSizeMirror = WorkbenchTrueSizeMirror(
            skView: view, scene: pushlingScene,
            targetImageView: insetView, sceneSize: sceneSize
        )
        trueSizeMirror?.start()
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

    /// Compute the magnified SKView's size at the requested magnification,
    /// clamped to fit the main screen's visible frame — at 1085x30 native,
    /// 4-8x magnifies past most laptop screen widths, so this fits-to-screen
    /// instead of spawning a window nobody can see in full.
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
