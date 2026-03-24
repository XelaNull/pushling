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

    /// Native AppKit progress button overlaid on the SKView. Renders above all
    /// SpriteKit content including fog of war (.replace blend panels).
    /// Shows evolution progress as a border fill.
    private var toggleButton: ProgressButtonView?

    // MARK: - Menu Overlay (AppKit — above SpriteKit fog of war)

    private var menuStrip: MenuStripView?
    private var statsPopup: StatsPopupView?
    private var isMenuOpen = false
    private var isStatsOpen = false

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

        // Add the [P] progress button as a native AppKit overlay
        if toggleButton == nil {
            let btn = ProgressButtonView(frame: NSRect(x: 2, y: 4, width: 24, height: 22))
            btn.onTap = { [weak self] in self?.toggleButtonTapped() }
            addSubview(btn)
            self.toggleButton = btn
        }

        // Slide-out menu strip (initially collapsed, hidden)
        // Show MCP button by default; async check hides it if MCP is already installed
        if menuStrip == nil {
            let menu = MenuStripView(
                frame: NSRect(x: 30, y: 0, width: 0, height: 30),
                showMCPButton: true  // Default to showing; hidden async if installed
            )
            menu.isHidden = true
            menu.onStatsTap = { [weak self] in self?.menuStatsTapped() }
            menu.onSoundToggle = { [weak self] muted in
                guard let scene = self?.scene as? PushlingScene else { return }
                scene.worldManager.soundSystem.isMuted = muted
            }
            menu.onAboutTap = { [weak self] in
                self?.closeMenu()
                self?.showAbout()
            }
            menu.onMCPInstall = { [weak menu] in
                DispatchQueue.global(qos: .utility).async {
                    HookInstaller.installMCP()
                    UserDefaults.standard.set(true, forKey: "mcpInstalled")
                    DispatchQueue.main.async {
                        menu?.hideMCPButton()
                        NSLog("[Pushling/Menu] MCP installed from Touch Bar menu")
                    }
                }
            }
            addSubview(menu)
            self.menuStrip = menu

            // Check MCP status — hide button if already installed
            if UserDefaults.standard.bool(forKey: "mcpInstalled") {
                menu.hideMCPButton()
            } else {
                // Async check via claude CLI as fallback
                DispatchQueue.global(qos: .utility).async { [weak menu] in
                    let installed = HookInstaller.isMCPInstalled()
                    if installed {
                        UserDefaults.standard.set(true, forKey: "mcpInstalled")
                        DispatchQueue.main.async {
                            menu?.hideMCPButton()
                        }
                    }
                }
            }
        }

        // Stats popup (initially hidden)
        if statsPopup == nil {
            let popup = StatsPopupView(frame: NSRect(x: 30, y: 0, width: 360, height: 30))
            popup.isHidden = true
            popup.onClose = { [weak self] in self?.closeStats() }
            addSubview(popup)
            self.statsPopup = popup
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
        if isStatsOpen {
            closeStats()
            return
        }
        if isMenuOpen {
            // Button shows "M" — pressing it shows MacBook default Touch Bar
            closeMenu()
            guard let scene = self.scene as? PushlingScene else { return }
            scene.onToggleTouchBar?()
        } else {
            // Button shows "P" — pressing it opens menu, P becomes M
            openMenu()
        }
    }

    // MARK: - Menu Handlers

    private func openMenu() {
        isMenuOpen = true
        // Cancel any lingering fade from a previous menu open
        toggleButton?.cancelFadeOut()
        menuStrip?.cancelAllAnimations()
        // Flash the P button bright before transforming
        toggleButton?.flash()
        toggleButton?.setLabel("M")
        // Step 1: Expand P button to full-height M
        toggleButton?.expand(completion: nil)
        // Step 2: After expand animation (0.4s), slide menu out + start fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard self?.isMenuOpen == true else { return }
            NSLog("[Pushling/Menu] Showing menu strip — width: %.0f, hidden: %@",
                  self?.menuStrip?.expandedWidth ?? -1,
                  self?.menuStrip?.isHidden == true ? "YES" : "NO")
            self?.menuStrip?.show()
            self?.toggleButton?.fadeOut(duration: MenuStripView.fadeDuration)
        }
        menuStrip?.onFadeComplete = { [weak self] in
            self?.closeMenu()
        }
        menuStrip?.onRestoreBrightness = { [weak self] in
            // Restore M button brightness when a menu button is pressed
            self?.toggleButton?.cancelFadeOut()
            self?.toggleButton?.fadeOut(duration: MenuStripView.fadeDuration)
        }
    }

    private var aboutPopup: NSView?

    private func showAbout() {
        // Remove existing about popup
        aboutPopup?.removeFromSuperview()

        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let popup = NSView(frame: NSRect(x: 30, y: 0, width: 300, height: 30))
        popup.wantsLayer = true
        popup.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        popup.layer?.cornerRadius = 4
        popup.layer?.borderWidth = 1.0
        popup.layer?.borderColor = NSColor(white: 0.3, alpha: 0.6).cgColor

        let label = NSTextField(labelWithString: "Pushling v\(version)  Build: \(build)")
        label.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        label.textColor = NSColor(displayP3Red: 0, green: 0.831, blue: 1, alpha: 1)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.frame = NSRect(x: 8, y: 8, width: 240, height: 14)
        popup.addSubview(label)

        let close = MenuButton(frame: NSRect(x: 276, y: 4, width: 22, height: 22), label: "X")
        close.onTap = { [weak self] in
            self?.aboutPopup?.removeFromSuperview()
            self?.aboutPopup = nil
        }
        popup.addSubview(close)

        addSubview(popup)
        aboutPopup = popup
    }

    private func closeMenu() {
        menuStrip?.cancelAllAnimations()
        toggleButton?.cancelFadeOut()
        toggleButton?.setLabel("P")
        toggleButton?.collapse()
        isMenuOpen = false
    }

    private func menuStatsTapped() {
        closeMenu()
        showStats()
    }

    private func showStats() {
        guard let scene = self.scene as? PushlingScene else { return }
        let hud = scene.hudOverlay.currentState
        let gc = scene.gameCoordinator

        // Convert SKColor to NSColor for AppKit
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let rgb = hud.stageColor.usingColorSpace(.sRGB) ?? NSColor.white
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        let stageNSColor = NSColor(displayP3Red: r, green: g, blue: b, alpha: a)

        // Gather data for all 4 pages
        let emo = gc?.emotionalState
        let pers = gc?.personality
        let traits = gc?.visualTraits ?? .neutral
        let emergent = gc?.emergentStates.currentState

        let data = StatsPageData(
            creatureName: gc?.creatureName ?? "Pushling",
            stageName: hud.stageName,
            stageColor: stageNSColor,
            currentXP: hud.currentXP,
            xpToNext: hud.xpToNext,
            streakDays: hud.streakDays,
            satisfaction: emo?.satisfaction ?? hud.satisfaction,
            curiosity: emo?.curiosity ?? 50,
            contentment: emo?.contentment ?? 50,
            energy: emo?.energy ?? 50,
            emergentState: emergent?.rawValue,
            pEnergy: pers?.energy ?? 0.5,
            pVerbosity: pers?.verbosity ?? 0.5,
            pFocus: pers?.focus ?? 0.5,
            pDiscipline: pers?.discipline ?? 0.5,
            specialty: pers?.specialty.rawValue ?? "polyglot",
            specialtyHue: traits.baseColorHue,
            commitsEaten: gc?.totalXP ?? 0,
            totalTouches: 0,  // TODO: wire touch count
            badgesEarned: 0,  // TODO: wire MutationSystem.earnedCount
            badgesTotal: 10,
            tricksKnown: gc?.masteryTracker.totalBehaviors ?? 0,
            furPattern: traits.furPattern.rawValue,
            eyeShape: traits.eyeShape.rawValue,
            tailShape: traits.tailShape.rawValue,
            baseColorHue: traits.baseColorHue
        )

        statsPopup?.update(data: data)
        statsPopup?.isHidden = false
        isStatsOpen = true
    }

    private func closeStats() {
        statsPopup?.isHidden = true
        isStatsOpen = false
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

    // MARK: - GitHub Consent Popup

    private var githubPopup: GitHubConsentPopupView?

    /// Show the GitHub consent popup on the Touch Bar.
    func showGitHubConsent(onConsent: @escaping () -> Void,
                           onDecline: @escaping () -> Void) {
        let popup = GitHubConsentPopupView(
            frame: NSRect(x: 30, y: 0, width: 330, height: 30))
        popup.onConsent = { [weak self] in
            onConsent()
            self?.githubPopup?.removeFromSuperview()
            self?.githubPopup = nil
        }
        popup.onDecline = { [weak self] in
            onDecline()
            self?.githubPopup?.removeFromSuperview()
            self?.githubPopup = nil
        }
        addSubview(popup)
        self.githubPopup = popup
    }

    // MARK: - Evolution Progress

    /// Update the P button's evolution progress fill.
    func updateEvolutionProgress(_ fraction: CGFloat) {
        toggleButton?.progress = fraction
    }

    // MARK: - Hatching Flight

    /// Move the P button to a specific screen X during the flight sequence.
    /// yOffset adds sinusoidal wobble for the crashing arc effect.
    func movePButton(toX screenX: CGFloat, yOffset: CGFloat = 0) {
        let btnWidth: CGFloat = 24
        let btnHeight: CGFloat = 22
        let x = max(0, screenX - btnWidth / 2)
        let y = max(0, min(8, 4 + yOffset))
        toggleButton?.frame = NSRect(x: x, y: y, width: btnWidth, height: btnHeight)
        toggleButton?.rebuildLayers()
    }

    /// Reset P button to its normal collapsed position.
    func resetPButtonPosition() {
        toggleButton?.frame = NSRect(x: 2, y: 4, width: 24, height: 22)
        toggleButton?.rebuildLayers()
    }

    // MARK: - Hatching Visibility

    /// Hide or show the P button (hidden during hatching ceremony).
    /// Set `instant` to true to skip the fade-in animation.
    func setPButtonHidden(_ hidden: Bool, instant: Bool = false) {
        if hidden {
            toggleButton?.isHidden = true
        } else if instant {
            toggleButton?.alphaValue = 1.0
            toggleButton?.isHidden = false
        } else {
            toggleButton?.alphaValue = 0
            toggleButton?.isHidden = false
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 1.0
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.toggleButton?.animator().alphaValue = 1.0
            }
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

// MARK: - Progress Button View

/// P button with a border that fills like a gas gauge to show evolution
/// progress. Uses CAShapeLayer strokeEnd for GPU-accelerated border tracing.
/// Tap handled via NSClickGestureRecognizer (mouseDown doesn't fire on Touch Bar).
final class ProgressButtonView: NSView {

    /// Evolution progress fraction (0.0 to 1.0).
    /// Animates smoothly like water filling a glass.
    var progress: CGFloat = 0 {
        didSet {
            let clamped = min(max(progress, 0), 1)
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = progressLayer.presentation()?.strokeEnd
                ?? progressLayer.strokeEnd
            anim.toValue = clamped
            anim.duration = 1.5
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            anim.fillMode = .forwards
            anim.isRemovedOnCompletion = false
            progressLayer.add(anim, forKey: "progressFill")
            // Update model value so future animations start from correct position
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = clamped
            CATransaction.commit()
        }
    }

    /// Called when the button is tapped.
    var onTap: (() -> Void)?

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let textLayer = CATextLayer()
    private let cornerRadius: CGFloat = 4

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.85).cgColor

        setupLayers()

        let click = NSClickGestureRecognizer(
            target: self, action: #selector(handleTap(_:))
        )
        click.allowedTouchTypes = [.direct]
        click.buttonMask = 0
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupLayers() {
        guard let root = layer else { return }
        let path = makeBorderPath()

        // Dim track — full border outline (the "empty gauge")
        trackLayer.path = path
        trackLayer.strokeColor = NSColor(white: 0.25, alpha: 1.0).cgColor
        trackLayer.fillColor = nil
        trackLayer.lineWidth = 1.0
        trackLayer.strokeEnd = 1.0
        root.addSublayer(trackLayer)

        // Bright progress — partial border (the "filled gauge")
        progressLayer.path = path
        progressLayer.strokeColor = NSColor(
            displayP3Red: 0, green: 0.831, blue: 1.0, alpha: 0.8
        ).cgColor
        progressLayer.fillColor = nil
        progressLayer.lineWidth = 1.5
        progressLayer.strokeEnd = 0
        progressLayer.lineCap = .round
        root.addSublayer(progressLayer)

        // Subtle "P" text
        textLayer.string = "P"
        textLayer.font = NSFont.boldSystemFont(ofSize: 9)
        textLayer.fontSize = 9
        textLayer.foregroundColor = NSColor(white: 1.0, alpha: 0.4).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = 2.0
        let textH: CGFloat = 12
        textLayer.frame = CGRect(
            x: 0, y: (bounds.height - textH) / 2,
            width: bounds.width, height: textH
        )
        root.addSublayer(textLayer)
    }

    /// Rounded rect path starting at bottom-center, traced clockwise.
    /// strokeEnd traces this path like a gas gauge filling up.
    private func makeBorderPath() -> CGPath {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let r = cornerRadius
        let path = CGMutablePath()

        // Start at bottom-center
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        // Bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r),
                    radius: r)
        // Right side up, top-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY),
                    radius: r)
        // Top side left, top-left corner
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r),
                    radius: r)
        // Left side down, bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.minX + r, y: rect.minY),
                    radius: r)
        // Back to bottom-center
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))

        return path
    }

    /// Change the button label (e.g. "P" ↔ "M").
    func setLabel(_ text: String) {
        textLayer.string = text
    }

    /// Flash the border bright momentarily before a transition.
    func flash() {
        let flashAnim = CABasicAnimation(keyPath: "strokeColor")
        flashAnim.fromValue = NSColor.white.cgColor
        flashAnim.toValue = progressLayer.strokeColor
        flashAnim.duration = 0.4
        flashAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        progressLayer.add(flashAnim, forKey: "flash")
        trackLayer.add(flashAnim, forKey: "flash")

        // Also flash background
        let bgFlash = CABasicAnimation(keyPath: "backgroundColor")
        bgFlash.fromValue = NSColor(white: 0.4, alpha: 0.9).cgColor
        bgFlash.toValue = layer?.backgroundColor
        bgFlash.duration = 0.4
        bgFlash.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer?.add(bgFlash, forKey: "bgFlash")
    }

    /// Fade the entire button to 0 alpha over the given duration.
    func fadeOut(duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            self.animator().alphaValue = 0
        }
    }

    /// Cancel any in-progress fade and restore full opacity.
    func cancelFadeOut() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        alphaValue = 1.0
    }

    // MARK: - Expand / Collapse Animation

    private static let collapsedFrame = NSRect(x: 2, y: 4, width: 24, height: 22)
    private static let expandedFrame = NSRect(x: 0, y: 0, width: 30, height: 30)

    /// Expand from subtle P to full-height M button with spring animation.
    func expand(completion: (() -> Void)? = nil) {
        let target = Self.expandedFrame
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().frame = target
        }, completionHandler: { [weak self] in
            self?.rebuildLayers()
            // Text gets bigger and brighter for M mode
            self?.textLayer.fontSize = 12
            self?.textLayer.foregroundColor = NSColor(white: 1.0, alpha: 0.8).cgColor
            let textH: CGFloat = 15
            self?.textLayer.frame = CGRect(
                x: 0, y: (target.height - textH) / 2,
                width: target.width, height: textH
            )
            completion?()
        })
    }

    /// Collapse back to subtle P button size.
    func collapse() {
        let target = Self.collapsedFrame
        // Shrink text first
        textLayer.fontSize = 9
        textLayer.foregroundColor = NSColor(white: 1.0, alpha: 0.4).cgColor
        let textH: CGFloat = 12
        textLayer.frame = CGRect(
            x: 0, y: (target.height - textH) / 2,
            width: target.width, height: textH
        )
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().frame = target
        }, completionHandler: { [weak self] in
            self?.rebuildLayers()
        })
    }

    /// Rebuild shape layers to match current bounds after resize.
    func rebuildLayers() {
        let path = makeBorderPath()
        let currentStroke = progressLayer.presentation()?.strokeEnd
            ?? progressLayer.strokeEnd

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.path = path
        progressLayer.path = path
        progressLayer.strokeEnd = currentStroke
        CATransaction.commit()
    }

    @objc private func handleTap(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        onTap?()
    }
}
