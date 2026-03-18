// TouchBarController.swift — Manages Touch Bar lifecycle
// Presents a system-modal NSTouchBar with an embedded SpriteKit SKView.
//
// Toggle approach: we NEVER dismiss the system modal. Instead, we swap
// between two bars:
//   - Scene bar: full SpriteKit scene with [P] overlay button
//   - Controls bar: [P] back button + brightness/volume/keyboard backlight
// This way we always own the Touch Bar and can always switch back.

import AppKit
import SpriteKit

/// Identifier for our Touch Bar items.
private extension NSTouchBarItem.Identifier {
    // Scene mode
    static let pushlingScene = NSTouchBarItem.Identifier("com.pushling.scene")
    static let pushlingControlStrip = NSTouchBarItem.Identifier("com.pushling.controlStrip")
    // Controls mode
    static let ctrlBack = NSTouchBarItem.Identifier("com.pushling.ctrl.back")
    static let ctrlBrightnessDown = NSTouchBarItem.Identifier("com.pushling.ctrl.brightnessDown")
    static let ctrlBrightnessUp = NSTouchBarItem.Identifier("com.pushling.ctrl.brightnessUp")
    static let ctrlKbdLight = NSTouchBarItem.Identifier("com.pushling.ctrl.kbdLight")
    static let ctrlVolumeDown = NSTouchBarItem.Identifier("com.pushling.ctrl.volumeDown")
    static let ctrlVolumeUp = NSTouchBarItem.Identifier("com.pushling.ctrl.volumeUp")
    static let ctrlMute = NSTouchBarItem.Identifier("com.pushling.ctrl.mute")
    static let ctrlSpace = NSTouchBarItem.Identifier("com.pushling.ctrl.space")
}

private extension NSTouchBar.CustomizationIdentifier {
    static let pushling = NSTouchBar.CustomizationIdentifier("com.pushling.touchbar")
    static let pushlingControls = NSTouchBar.CustomizationIdentifier("com.pushling.controls")
}

final class TouchBarController: NSObject, TouchBarProvider, NSTouchBarDelegate {

    // MARK: - Properties

    private let dfr = DFRFoundationLoader.shared
    private var sceneBar: NSTouchBar?
    private var controlsBar: NSTouchBar?
    private var sceneView: SKView?
    private var scene: PushlingScene?
    private var isPresented = false
    private var isShowingControls = false

    // Keep reference to old touchBar for dismiss compatibility
    var touchBar: NSTouchBar? { sceneBar }

    var isAvailable: Bool { dfr.isLoaded }
    var currentScene: PushlingScene? { scene }

    // MARK: - TouchBarProvider

    func present() {
        guard dfr.isLoaded else {
            NSLog("[Pushling] Touch Bar unavailable — skipping presentation")
            return
        }

        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = .pushling
        bar.defaultItemIdentifiers = [.pushlingScene]
        self.sceneBar = bar

        dfr.setShowsCloseBoxWhenFrontMost(false)
        bar.presentAsSystemModal(
            placement: 1,
            systemTrayItemIdentifier: .pushlingControlStrip
        )

        isPresented = true
        isShowingControls = false
        NSLog("[Pushling] Touch Bar presented — SpriteKit scene active")
    }

    func dismiss() {
        let bar = isShowingControls ? controlsBar : sceneBar
        scene?.isPaused = true
        bar?.dismissSystemModal()

        sceneView?.presentScene(nil)
        sceneView = nil
        scene = nil
        sceneBar = nil
        controlsBar = nil
        isPresented = false
        isShowingControls = false

        NSLog("[Pushling] Touch Bar dismissed — system strip restored")
    }

    func toggleVisibility() {
        if isShowingControls {
            // Switch back to game
            controlsBar?.dismissSystemModal()
            scene?.isPaused = false

            guard let bar = sceneBar else { present(); return }
            dfr.setShowsCloseBoxWhenFrontMost(false)
            bar.presentAsSystemModal(
                placement: 1,
                systemTrayItemIdentifier: .pushlingControlStrip
            )
            isShowingControls = false
            isPresented = true
            NSLog("[Pushling] Switched to game mode")
        } else {
            // Switch to system controls
            sceneBar?.dismissSystemModal()
            scene?.isPaused = true

            // Create controls bar (fresh each time — lightweight)
            let bar = NSTouchBar()
            bar.delegate = self
            bar.customizationIdentifier = .pushlingControls
            bar.defaultItemIdentifiers = [
                .ctrlBack, .flexibleSpace,
                .ctrlBrightnessDown, .ctrlBrightnessUp,
                .fixedSpaceSmall,
                .ctrlKbdLight,
                .fixedSpaceSmall,
                .ctrlVolumeDown, .ctrlVolumeUp, .ctrlMute,
                .flexibleSpace
            ]
            self.controlsBar = bar

            dfr.setShowsCloseBoxWhenFrontMost(false)
            bar.presentAsSystemModal(
                placement: 1,
                systemTrayItemIdentifier: .pushlingControlStrip
            )
            isShowingControls = true
            NSLog("[Pushling] Switched to controls mode")
        }
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
        // Scene mode
        case .pushlingScene:
            return makeSceneItem()
        case .pushlingControlStrip:
            return makeSmallButton("P", action: #selector(controlStripTapped))

        // Controls mode
        case .ctrlBack:
            return makeSmallButton("P ◀", action: #selector(controlStripTapped))
        case .ctrlBrightnessDown:
            return makeSmallButton("☀-", action: #selector(brightnessDown))
        case .ctrlBrightnessUp:
            return makeSmallButton("☀+", action: #selector(brightnessUp))
        case .ctrlKbdLight:
            return makeSmallButton("⌨💡", action: #selector(kbdLightToggle))
        case .ctrlVolumeDown:
            return makeSmallButton("🔉", action: #selector(volumeDown))
        case .ctrlVolumeUp:
            return makeSmallButton("🔊", action: #selector(volumeUp))
        case .ctrlMute:
            return makeSmallButton("🔇", action: #selector(mute))

        default:
            return nil
        }
    }

    // MARK: - Button Factory

    private func makeSmallButton(
        _ title: String, action: Selector
    ) -> NSTouchBarItem {
        // Derive identifier from the selector name
        let id = NSTouchBarItem.Identifier("com.pushling.ctrl.\(NSStringFromSelector(action))")
        let item = NSCustomTouchBarItem(identifier: id)
        let button = NSButton(title: title, target: self, action: action)
        button.font = NSFont.systemFont(ofSize: 12)
        item.view = button
        return item
    }

    // MARK: - Control Actions

    @objc private func controlStripTapped() { toggleVisibility() }

    @objc private func brightnessDown() { postSystemKey(3) }
    @objc private func brightnessUp() { postSystemKey(2) }
    @objc private func kbdLightToggle() {
        // Toggle: send illumination up to increase, or toggle
        postSystemKey(23)  // NX_KEYTYPE_ILLUMINATION_TOGGLE
    }
    @objc private func volumeDown() { postSystemKey(1) }
    @objc private func volumeUp() { postSystemKey(0) }
    @objc private func mute() { postSystemKey(7) }

    /// Post a system-defined HID key event (brightness, volume, etc.)
    private func postSystemKey(_ keyCode: Int) {
        // Key down
        let downData = (keyCode << 16) | 0x0a00
        if let ev = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: downData, data2: -1
        ) {
            ev.cgEvent?.post(tap: .cghidEventTap)
        }
        // Key up
        let upData = (keyCode << 16) | 0x0b00
        if let ev = NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: upData, data2: -1
        ) {
            ev.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Scene Item Factory

    private func makeSceneItem() -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .pushlingScene)

        if let existingView = sceneView {
            item.view = existingView
            return item
        }

        let view = TouchBarView(frame: NSRect(x: 0, y: 0, width: 1085, height: 30))
        view.preferredFramesPerSecond = 60
        view.allowsTransparency = false
        view.allowedTouchTypes = [.direct]

        #if DEBUG
        view.showsFPS = false
        view.showsNodeCount = false
        view.showsDrawCount = false
        #endif

        let pushlingScene = PushlingScene(size: CGSize(width: 1085, height: 30))
        pushlingScene.scaleMode = .aspectFill
        pushlingScene.anchorPoint = CGPoint(x: 0, y: 0)
        pushlingScene.backgroundColor = SKColor.black

        pushlingScene.onToggleTouchBar = { [weak self] in
            self?.toggleVisibility()
        }

        view.presentScene(pushlingScene)

        item.view = view
        self.sceneView = view
        self.scene = pushlingScene

        return item
    }
}
