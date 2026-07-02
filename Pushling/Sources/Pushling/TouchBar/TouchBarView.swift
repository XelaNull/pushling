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

    /// Transparent overlay that receives touch events on the Touch Bar.
    /// Gesture recognizers on SKView itself do NOT receive events on the
    /// Touch Bar — only recognizers on regular NSView subviews work.
    /// This overlay sits behind the P button and menu, covering the full bar.
    private var touchOverlay: NSView?

    // MARK: - View Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        self.allowedTouchTypes = [.direct]

        // TODO: Touch input on the scene area is broken — gesture recognizers
        // on SKView and subview overlays do not receive Touch Bar events.
        // Only the P button (ProgressButtonView) receives events. Need to
        // investigate how open-source Touch Bar SpriteKit games handle this.

        // Add the [P] progress button as a native AppKit overlay
        if toggleButton == nil {
            let btn = ProgressButtonView(frame: NSRect(x: 2, y: 4, width: 24, height: 22))
            btn.onTap = { [weak self] in self?.toggleButtonTapped() }
            addSubview(btn)
            self.toggleButton = btn
        }

        // Slide-out menu strip (initially collapsed, hidden)
        if menuStrip == nil {
            let menu = MenuStripView(frame: NSRect(x: 30, y: 0, width: 0, height: 30))
            menu.isHidden = true

            // Sound toggle — mute state owned here, not in the strip
            var isMuted = false
            menu.addItem(label: "♪", width: 30) { [weak self, weak menu] in
                guard let scene = self?.scene as? PushlingScene else { return }
                isMuted.toggle()
                scene.worldManager.soundSystem.isMuted = isMuted
                if let btn = menu?.button(label: "♪") {
                    btn.setTextColor(isMuted
                        ? NSColor(displayP3Red: 0.6, green: 0.2, blue: 0.2, alpha: 0.5)
                        : NSColor(white: 1.0, alpha: 0.8))
                    btn.layer?.borderColor = (isMuted
                        ? NSColor(displayP3Red: 0.5, green: 0.15, blue: 0.15, alpha: 0.8)
                        : NSColor(white: 0.35, alpha: 1.0)).cgColor
                }
            }
            // Order: Sound, Stats, About, Pet, Feed, Play
            // (Pet/Feed/Play placed AFTER the original 3 to test position theory)
            menu.addItem(label: "Stats", width: 50) { [weak self] in
                self?.menuStatsTapped()
            }
            menu.addItem(label: "About", width: 44) { [weak self] in
                self?.closeMenu()
                self?.showAbout()
            }
            menu.addItem(label: "Pet", width: 34) { [weak self] in
                self?.menuPetTapped()
            }
            menu.addItem(label: "Feed", width: 40) { [weak self] in
                self?.menuFeedTapped()
            }
            menu.addItem(label: "Play", width: 38) { [weak self] in
                self?.menuPlayTapped()
            }

            // MCP Install button — added conditionally, removed once installed
            let addMCPButton = {
                menu.addItem(label: "MCP", width: 50) { [weak menu] in
                    if let btn = menu?.button(label: "MCP") {
                        btn.setTextColor(NSColor(
                            displayP3Red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
                    }
                    DispatchQueue.global(qos: .utility).async {
                        HookInstaller.installMCP()
                        UserDefaults.standard.set(true, forKey: "mcpInstalled")
                        DispatchQueue.main.async {
                            menu?.hideMCPButton()
                            NSLog("[Pushling/Menu] MCP installed from Touch Bar menu")
                        }
                    }
                }
                // Tint MCP button yellow after adding it
                if let btn = menu.button(label: "MCP") {
                    btn.setTextColor(NSColor(
                        displayP3Red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
                }
            }

            addSubview(menu)
            self.menuStrip = menu

            // Check MCP status — add button only if not yet installed
            if UserDefaults.standard.bool(forKey: "mcpInstalled") {
                // Already installed — no MCP button
            } else {
                addMCPButton()
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

        NSLog("[Pushling/TouchBarView] Ready — overlay with %d gesture recognizers, toggle button added",
              touchOverlay?.gestureRecognizers.count ?? 0)
    }

    // MARK: - Touch Event Overrides
    // Override WITHOUT calling super to prevent SKView.touchesBegan from
    // accessing NSTouch.normalizedPosition (crashes on Touch Bar).
    // Actual touch handling is on the touchOverlay's gesture recognizers.

    override func touchesBegan(with event: NSEvent) {}
    override func touchesMoved(with event: NSEvent) {}
    override func touchesEnded(with event: NSEvent) {}
    override func touchesCancelled(with event: NSEvent) {}

    // MARK: - Gesture Wiring (called by TouchBarController)

    /// Wire click and pan gesture recognizers onto the given container view.
    /// Must be called AFTER the container is fully in the view hierarchy.
    /// The container is the NSTouchBarItem's view — a plain NSView that
    /// actually receives touch events (SKView itself does not on Touch Bar).
    func wireGestureRecognizers(on container: NSView) {
        let click = NSClickGestureRecognizer(
            target: self, action: #selector(handleClick(_:))
        )
        click.allowedTouchTypes = [.direct]
        click.buttonMask = 0
        container.addGestureRecognizer(click)

        let pan = NSPanGestureRecognizer(
            target: self, action: #selector(handlePan(_:))
        )
        pan.allowedTouchTypes = [.direct]
        pan.buttonMask = 0
        pan.numberOfTouchesRequired = 1
        container.addGestureRecognizer(pan)

        NSLog("[Pushling/TouchBarView] Gesture recognizers wired on container (%@) — %d recognizers",
              String(describing: type(of: container)),
              container.gestureRecognizers.count)
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

    private func menuPetTapped() {
        closeMenu()
        guard let scene = self.scene as? PushlingScene else { return }
        scene.gameCoordinator?.menuPet()
    }

    private func menuFeedTapped() {
        closeMenu()
        guard let scene = self.scene as? PushlingScene else { return }
        scene.gameCoordinator?.menuFeed()
    }

    private func menuPlayTapped() {
        closeMenu()
        guard let scene = self.scene as? PushlingScene else { return }
        scene.gameCoordinator?.menuPlay()
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
        NSLog("[Pushling/Click] state=%ld view=%@", gesture.state.rawValue,
              String(describing: type(of: gesture.view ?? self)))
        guard gesture.state == .ended else { return }
        let point = gesture.location(in: self)
        NSLog("[Pushling/Click] FIRED at (%.1f, %.1f)", point.x, point.y)

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

    // MARK: - Pan Gesture Handler

    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let scene = self.scene as? PushlingScene else { return }

        let point = gesture.location(in: self)
        let id = ObjectIdentifier(gesture)
        let now = CACurrentMediaTime()
        let tracker = scene.gameCoordinator?.touchTracker

        switch gesture.state {
        case .began:
            // Don't trigger HUD on drag start — only on clean tap (click gesture)
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

}

// MARK: - Touch Catcher View

/// Transparent overlay that always returns itself from hitTest.
/// AppKit skips fully-transparent views in hit testing; this override
/// ensures touch events reach our gesture recognizers on the Touch Bar.
private final class TouchCatcherView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // If the point is within our bounds, claim it.
        // Subviews (P button, menu) are added to TouchBarView, not here,
        // so they get priority via the normal superview hit test order.
        guard bounds.contains(convert(point, from: superview)) else { return nil }
        return self
    }
    override var acceptsFirstResponder: Bool { true }
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
