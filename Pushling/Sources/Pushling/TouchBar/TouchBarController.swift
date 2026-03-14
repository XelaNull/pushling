// TouchBarController.swift — Manages Touch Bar lifecycle
// Presents a system-modal NSTouchBar with an embedded SpriteKit SKView.
// Implements the TouchBarProvider protocol; all private API calls go through DFRPrivateAPI.

import AppKit
import SpriteKit

/// Identifier for our Touch Bar and its items.
private extension NSTouchBarItem.Identifier {
    static let pushlingControlStrip = NSTouchBarItem.Identifier(
        "com.pushling.controlStrip"
    )
    static let pushlingScene = NSTouchBarItem.Identifier(
        "com.pushling.scene"
    )
}

private extension NSTouchBar.CustomizationIdentifier {
    static let pushling = NSTouchBar.CustomizationIdentifier(
        "com.pushling.touchbar"
    )
}

final class TouchBarController: NSObject, TouchBarProvider, NSTouchBarDelegate {

    // MARK: - Properties

    private let dfr = DFRFoundationLoader.shared
    private var touchBar: NSTouchBar?
    private var sceneView: SKView?
    private var scene: PushlingScene?
    private var isPresented = false

    /// Whether the Touch Bar hardware is available.
    var isAvailable: Bool {
        return dfr.isLoaded
    }

    // MARK: - TouchBarProvider

    func present() {
        guard dfr.isLoaded else {
            NSLog("[Pushling] Touch Bar unavailable — skipping presentation")
            return
        }

        // Create the Touch Bar
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = .pushling
        bar.defaultItemIdentifiers = [.pushlingScene]

        self.touchBar = bar

        // Hide the system close button so we own the full strip
        dfr.setShowsCloseBoxWhenFrontMost(false)

        // Present as system modal — replaces the default Touch Bar
        bar.presentAsSystemModal(
            placement: 1,
            systemTrayItemIdentifier: .pushlingControlStrip
        )

        isPresented = true
        NSLog("[Pushling] Touch Bar presented — SpriteKit scene active")
    }

    func dismiss() {
        guard isPresented, let bar = touchBar else { return }

        // Pause the scene before dismissing
        scene?.isPaused = true

        // Dismiss the system modal Touch Bar — restores system default
        bar.dismissSystemModal()

        // Clean up
        sceneView?.presentScene(nil)
        sceneView = nil
        scene = nil
        touchBar = nil
        isPresented = false

        NSLog("[Pushling] Touch Bar dismissed — system strip restored")
    }

    func setDebugOverlay(enabled: Bool) {
        scene?.showDebugOverlay(enabled)
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        switch identifier {
        case .pushlingScene:
            return makeSceneItem()
        default:
            return nil
        }
    }

    // MARK: - Scene Item Factory

    private func makeSceneItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .pushlingScene)

        // Create the SpriteKit view
        // Touch Bar dimensions: 1085 x 30 points (2170 x 60 pixels @2x)
        let view = SKView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
        view.preferredFramesPerSecond = 60
        view.allowsTransparency = false

        // Debug features — controlled via menu toggle, not always-on
        #if DEBUG
        view.showsFPS = false
        view.showsNodeCount = false
        view.showsDrawCount = false
        #endif

        // Create and configure the scene
        let pushlingScene = PushlingScene(size: CGSize(width: 1085, height: 30))
        pushlingScene.scaleMode = .aspectFill
        pushlingScene.anchorPoint = CGPoint(x: 0, y: 0)  // Bottom-left origin
        pushlingScene.backgroundColor = SKColor.black     // OLED true black — pixels OFF

        // Present the scene
        view.presentScene(pushlingScene)

        item.view = view
        self.sceneView = view
        self.scene = pushlingScene

        return item
    }
}
