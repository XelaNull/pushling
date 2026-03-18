// TouchBarView.swift — Custom SKView subclass for Touch Bar touch handling
// Touch Bar touches crash on NSTouch.normalizedPosition (trackpad-only API).
// However, NSGestureRecognizers work correctly and provide view-space
// coordinates via location(in:). The touchesBegan override must remain
// present (even though it will crash internally on normalizedPosition)
// because its presence enables the responder chain for gesture recognizers.
//
// Zoom: NSMagnificationGestureRecognizer for pinch (fingers spread/contract).
//       Fallback: two-finger horizontal drag via NSPanGestureRecognizer.
// Pan:  One-finger drag on empty space.
//
// AppKit catches the normalizedPosition exception silently.
// Gesture recognizers fire after the exception is caught.

import AppKit
import SpriteKit
import QuartzCore

final class TouchBarView: SKView {

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool { true }

    // MARK: - Toggle Button (AppKit overlay — above SpriteKit fog of war)

    /// Native AppKit button overlaid on the SKView. Renders above all
    /// SpriteKit content including fog of war (.replace blend panels).
    private var toggleButton: NSButton?

    // MARK: - Gesture Recognizer References

    /// Magnification gesture for pinch-to-zoom (primary zoom method).
    private var magnificationGesture: NSMagnificationGestureRecognizer?

    /// Two-finger pan gesture (fallback zoom + two-finger drag).
    private var twoFingerPanGesture: NSPanGestureRecognizer?

    /// One-finger pan gesture (camera pan, petting, drag).
    private var oneFingerPanGesture: NSPanGestureRecognizer?

    // MARK: - View Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        self.allowedTouchTypes = [.direct]

        if self.gestureRecognizers.isEmpty {
            // Click (tap) — fires on touch-up with minimal movement
            let click = NSClickGestureRecognizer(
                target: self, action: #selector(handleClick(_:))
            )
            click.allowedTouchTypes = [.direct]
            click.buttonMask = 0
            addGestureRecognizer(click)

            // Magnification (pinch) — primary zoom method.
            // Detects finger spread/contract and reports magnification delta.
            let magnify = NSMagnificationGestureRecognizer(
                target: self, action: #selector(handleMagnification(_:))
            )
            magnify.allowedTouchTypes = [.direct]
            addGestureRecognizer(magnify)
            self.magnificationGesture = magnify

            // Two-finger pan — fallback zoom (same-direction drag) and
            // two-finger camera pan
            let twoFingerPan = NSPanGestureRecognizer(
                target: self, action: #selector(handleTwoFingerPan(_:))
            )
            twoFingerPan.allowedTouchTypes = [.direct]
            twoFingerPan.buttonMask = 0
            twoFingerPan.numberOfTouchesRequired = 2
            addGestureRecognizer(twoFingerPan)
            self.twoFingerPanGesture = twoFingerPan

            // One-finger pan (drag) — camera pan and petting.
            // Must not steal touches from two-finger gestures.
            let pan = NSPanGestureRecognizer(
                target: self, action: #selector(handlePan(_:))
            )
            pan.allowedTouchTypes = [.direct]
            pan.buttonMask = 0
            pan.numberOfTouchesRequired = 1
            pan.delaysPrimaryMouseButtonEvents = false
            pan.delaysSecondaryMouseButtonEvents = false
            addGestureRecognizer(pan)
            self.oneFingerPanGesture = pan
        }

        // Add the [P] toggle button as a native AppKit overlay
        if toggleButton == nil {
            let btn = NSButton(frame: NSRect(x: 2, y: 4, width: 24, height: 22))
            btn.title = "P"
            btn.bezelStyle = .recessed
            btn.isBordered = true
            btn.font = NSFont.boldSystemFont(ofSize: 11)
            btn.contentTintColor = .white
            btn.target = self
            btn.action = #selector(toggleButtonTapped)
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 4
            btn.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.85).cgColor
            addSubview(btn)
            self.toggleButton = btn
        }

        // Become first responder for touch delivery
        if let window = self.window {
            window.makeFirstResponder(self)
        }

        NSLog("[Pushling/TouchBarView] Ready — %d gesture recognizers, toggle button added",
              self.gestureRecognizers.count)
    }

    // MARK: - Touch Event Overrides
    // Override touch methods WITHOUT calling super to prevent SKView from
    // forwarding to the scene (which would crash on normalizedPosition).
    // The gesture recognizer receives touch data independently via AppKit's
    // gesture recognition pipeline.

    override func touchesBegan(with event: NSEvent) {
        // Do NOT call super — SKView.touchesBegan forwards to scene which
        // accesses NSTouch.normalizedPosition and crashes for Touch Bar touches.
    }

    override func touchesMoved(with event: NSEvent) {
        // Intentionally empty — gesture recognizers handle movement
    }

    override func touchesEnded(with event: NSEvent) {
        // Intentionally empty — gesture recognizers handle end
    }

    override func touchesCancelled(with event: NSEvent) {
        // Intentionally empty — gesture recognizers handle cancel
    }

    // MARK: - Toggle Button Handler

    @objc private func toggleButtonTapped() {
        guard let scene = self.scene as? PushlingScene else { return }
        scene.onToggleTouchBar?()
    }

    // MARK: - Click (Tap) Handler

    /// Counter for generating unique touch IDs per click.
    private var clickCounter: UInt64 = 0

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let point = gesture.location(in: self)

        guard let scene = self.scene as? PushlingScene else { return }
        scene.handleTouch(at: point)

        // Use a unique ID per click so the TouchTracker doesn't confuse
        // rapid successive taps as the same touch
        clickCounter &+= 1
        let id = ObjectIdentifier(clickCounter as AnyObject)
        let now = CACurrentMediaTime()
        let tracker = scene.gameCoordinator?.touchTracker
        tracker?.touchBegan(id: id, normalizedPosition: point, currentTime: now)
        tracker?.touchEnded(id: id, normalizedPosition: point, currentTime: now + 0.05)
    }

    // MARK: - Magnification (Pinch-to-Zoom) Handler

    /// Accumulated magnification at gesture start — used for converting
    /// incremental magnification changes to zoom deltas.
    private var magnifyStartZoom: CGFloat = 1.0

    @objc private func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
        guard let scene = self.scene as? PushlingScene else { return }
        let center = gesture.location(in: self)

        // Convert view-space center to world-space for pan adjustment
        let worldCenterX = viewToWorldX(center.x, scene: scene)

        switch gesture.state {
        case .began:
            magnifyStartZoom = scene.cameraController.zoomLevel
            scene.cameraController.recordTouch()
        case .changed:
            // magnification is cumulative: 0.0 = no change, 0.5 = 50% bigger
            // Convert to absolute zoom and compute delta from current level
            let targetZoom = magnifyStartZoom * (1.0 + gesture.magnification)
            let delta = targetZoom - scene.cameraController.zoomLevel
            scene.cameraController.zoom(delta: delta, centerWorldX: worldCenterX)
        case .ended, .cancelled:
            break
        default:
            break
        }
    }

    // MARK: - Two-Finger Pan (Fallback Zoom) Handler

    @objc private func handleTwoFingerPan(_ gesture: NSPanGestureRecognizer) {
        guard let scene = self.scene as? PushlingScene else { return }
        let center = gesture.location(in: self)

        // Convert view-space center to world-space for pan adjustment
        let worldCenterX = viewToWorldX(center.x, scene: scene)

        switch gesture.state {
        case .began:
            scene.cameraController.recordTouch()
        case .changed:
            // Two-finger drag still works as zoom: drag left = zoom out,
            // drag right = zoom in. This fires alongside magnification for
            // same-direction two-finger drags (where magnification ≈ 0).
            let translation = gesture.translation(in: self)
            // 200pt of finger travel = 1.0 zoom level change
            let zoomDelta = -translation.x / 200.0
            scene.cameraController.zoom(delta: CGFloat(zoomDelta),
                                         centerWorldX: worldCenterX)
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            break
        default:
            break
        }
    }

    // MARK: - Pan Gesture Handler

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let scene = self.scene as? PushlingScene else { return }

        let point = gesture.location(in: self)
        let id = ObjectIdentifier(gesture)
        let now = CACurrentMediaTime()
        let tracker = scene.gameCoordinator?.touchTracker

        switch gesture.state {
        case .began:
            scene.handleTouch(at: point)
            tracker?.touchBegan(id: id, normalizedPosition: point, currentTime: now)
        case .changed:
            tracker?.touchMoved(id: id, normalizedPosition: point, currentTime: now)
        case .ended:
            tracker?.touchEnded(id: id, normalizedPosition: point, currentTime: now)
            // Also notify touch handler of touch end for cleanup
            scene.gameCoordinator?.creatureTouchHandler.handleTouchEnded(
                at: point, currentTime: now
            )
        case .cancelled:
            tracker?.touchCancelled(id: id, currentTime: now)
        default:
            break
        }
    }

    // MARK: - Coordinate Conversion

    /// Converts a view-space X position to world-space X position.
    /// The parallax foreground layer maps screen positions to world positions.
    /// Screen center (542.5) = camera's effectiveWorldX.
    private func viewToWorldX(_ viewX: CGFloat, scene: PushlingScene) -> CGFloat {
        let sceneCenter = ParallaxSystem.sceneWidth / 2.0
        let zoom = scene.cameraController.zoomLevel
        // View offset from center, scaled inversely by zoom, plus camera world position
        return scene.cameraController.effectiveWorldX + (viewX - sceneCenter) / max(zoom, 0.1)
    }
}
