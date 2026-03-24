// TouchBarMenu.swift — Slide-out menu and stats popup for the P button
//
// MenuStripView: horizontal strip that slides out from P button with [Stats]
// StatsPopupView: 280x30 overlay showing creature stats with [X] close
// MenuButton: reusable tappable button for Touch Bar (uses gesture recognizer)

import AppKit

// MARK: - Menu Strip View

/// Horizontal menu that slides out to the right of the P/M button.
/// Contains [Stats] button. Fades out over 20 seconds, then calls onFadeComplete.
final class MenuStripView: NSView {

    var onStatsTap: (() -> Void)?
    var onSoundToggle: ((_ muted: Bool) -> Void)?
    var onMCPInstall: (() -> Void)?
    /// Called when the 20s fade completes — used to restore P label.
    var onFadeComplete: (() -> Void)?
    /// Called when a button is pressed during fade — restore M button brightness.
    var onRestoreBrightness: (() -> Void)?

    private let soundButton: MenuButton
    private let statsButton: MenuButton
    private var mcpButton: MenuButton?
    private var fadeTimer: Timer?
    private var isMuted = false
    private var showMCPInstall: Bool
    /// Incremented on each show() to invalidate stale fade completions.
    private var fadeGeneration: Int = 0
    static let fadeDuration: TimeInterval = 20.0

    var expandedWidth: CGFloat = 84  // 30 + 2 + 50 + 2
    private let stripHeight: CGFloat = 30

    init(frame: NSRect, showMCPButton: Bool = false) {
        self.showMCPInstall = showMCPButton

        soundButton = MenuButton(
            frame: NSRect(x: 0, y: 0, width: 30, height: 30), label: "♪"
        )
        let statsX: CGFloat = 32
        statsButton = MenuButton(
            frame: NSRect(x: statsX, y: 0, width: 50, height: 30), label: "Stats"
        )

        super.init(frame: frame)
        wantsLayer = true
        clipsToBounds = true

        soundButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.restoreBrightness()
            self.isMuted.toggle()
            if self.isMuted {
                self.soundButton.setLabel("♪")
                self.soundButton.setTextColor(
                    NSColor(displayP3Red: 0.6, green: 0.2, blue: 0.2, alpha: 0.5))
                self.soundButton.layer?.borderColor =
                    NSColor(displayP3Red: 0.5, green: 0.15, blue: 0.15, alpha: 0.8).cgColor
            } else {
                self.soundButton.setLabel("♪")
                self.soundButton.setTextColor(
                    NSColor(white: 1.0, alpha: 0.8))
                self.soundButton.layer?.borderColor =
                    NSColor(white: 0.35, alpha: 1.0).cgColor
            }
            self.onSoundToggle?(self.isMuted)
        }
        statsButton.onTap = { [weak self] in
            self?.restoreBrightness()
            self?.onStatsTap?()
        }

        addSubview(soundButton)
        addSubview(statsButton)

        // Conditionally add MCP Install button
        if showMCPInstall {
            let mcpX: CGFloat = 84  // After stats button
            let btn = MenuButton(
                frame: NSRect(x: mcpX, y: 0, width: 50, height: 30),
                label: "MCP"
            )
            btn.setTextColor(NSColor(
                displayP3Red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
            btn.onTap = { [weak self] in
                self?.restoreBrightness()
                self?.onMCPInstall?()
                // Hide the button after install
                btn.isHidden = true
                self?.expandedWidth = 84  // Shrink back to normal
            }
            addSubview(btn)
            self.mcpButton = btn
            expandedWidth = 136  // 30 + 2 + 50 + 2 + 50 + 2
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        fadeTimer?.invalidate()
    }

    // MARK: - Show / Hide

    func show() {
        isHidden = false
        alphaValue = 1.0
        fadeGeneration += 1  // Invalidate any previous fade completion
        let target = NSRect(
            x: frame.origin.x, y: frame.origin.y,
            width: expandedWidth, height: stripHeight
        )
        // Slide out
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().frame = target
        }
        // Start slow 20s fade
        startFade()
    }

    func hide(animated: Bool = true) {
        cancelFade()
        let collapsed = NSRect(
            x: frame.origin.x, y: frame.origin.y,
            width: 0, height: stripHeight
        )
        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.animator().frame = collapsed
            }, completionHandler: {
                self.isHidden = true
                self.alphaValue = 1.0
            })
        } else {
            frame = collapsed
            isHidden = true
            alphaValue = 1.0
        }
    }

    private func startFade() {
        fadeTimer?.invalidate()
        let currentGen = fadeGeneration
        // Fade alpha from 1 to 0 over 20 seconds
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Only complete if this fade hasn't been superseded
            guard let self = self, self.fadeGeneration == currentGen else { return }
            self.isHidden = true
            self.alphaValue = 1.0
            self.frame.size.width = 0
            self.onFadeComplete?()
        })
    }

    private func cancelFade() {
        fadeGeneration += 1  // Invalidate any pending completion
        // Cancel any in-progress fade animation
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        alphaValue = 1.0
    }

    /// Cancel all animations and reset to clean state for next show().
    func cancelAllAnimations() {
        cancelFade()
        // Reset frame width so next show() can animate from 0
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        animator().frame = NSRect(
            x: frame.origin.x, y: frame.origin.y,
            width: 0, height: stripHeight)
        NSAnimationContext.endGrouping()
        frame.size.width = 0
        isHidden = true
        alphaValue = 1.0
    }

    /// Restore full brightness on button press during fade, and restart fade timer.
    func restoreBrightness() {
        cancelFade()
        onRestoreBrightness?()
        // Restart the fade from the beginning
        startFade()
    }

    /// Hide the MCP button (called async when MCP is already installed).
    func hideMCPButton() {
        mcpButton?.isHidden = true
        mcpButton = nil
        expandedWidth = 84  // Standard width without MCP button
        showMCPInstall = false
    }

    var isExpanded: Bool { !isHidden && frame.width > 0 }
}

// MARK: - Stats Page Data

/// All data needed for the 5-page stats popup.
struct StatsPageData {
    // Page 1: Who Am I?
    let creatureName: String
    let stageName: String
    let stageColor: NSColor
    let currentXP: Int
    let xpToNext: Int
    let streakDays: Int
    // Page 2: How Do I Feel?
    let satisfaction: Double
    let curiosity: Double
    let contentment: Double
    let energy: Double
    let emergentState: String?
    // Page 3: What Am I Like?
    let pEnergy: Double
    let pVerbosity: Double
    let pFocus: Double
    let pDiscipline: Double
    let specialty: String
    let specialtyHue: Double
    // Page 4: What Have I Done?
    let commitsEaten: Int
    let totalTouches: Int
    let badgesEarned: Int
    let badgesTotal: Int
    let tricksKnown: Int
    // Page 5: What Do I Look Like?
    let furPattern: String
    let eyeShape: String
    let tailShape: String
    let baseColorHue: Double
}

// MARK: - Stats Popup View

/// Multi-page stats overlay. Tap or swipe to cycle through 5 pages:
///   1: Who Am I? (name, stage, XP, streak)
///   2: How Do I Feel? (emotions with visual bars)
///   3: What Am I Like? (natural language personality)
///   4: What Have I Done? (commits, touches, badges, tricks)
///   5: What Do I Look Like? (fur, eyes, tail descriptions)
final class StatsPopupView: NSView {

    var onClose: (() -> Void)?

    private static let pageCount = 5
    private var currentPage = 0
    private var pageData: StatsPageData?
    private var hasTriggeredSwipe = false

    // 4 reusable content labels
    private let label1 = NSTextField(labelWithString: "")
    private let label2 = NSTextField(labelWithString: "")
    private let label3 = NSTextField(labelWithString: "")
    private let label4 = NSTextField(labelWithString: "")
    private let contentContainer = NSView()

    // Fixed elements (persist across pages)
    private let pageIndicator = NSTextField(labelWithString: "1/5")
    private let closeButton: MenuButton

    override init(frame: NSRect) {
        closeButton = MenuButton(
            frame: NSRect(x: frame.width - 24, y: 4, width: 22, height: 22),
            label: "X"
        )

        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        layer?.cornerRadius = 4
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.3, alpha: 0.6).cgColor

        // Content container (animates on page change)
        contentContainer.frame = NSRect(x: 0, y: 0,
                                         width: frame.width, height: frame.height)
        contentContainer.wantsLayer = true
        addSubview(contentContainer)

        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
        for label in [label1, label2, label3, label4] {
            label.font = font
            label.textColor = .white
            label.backgroundColor = .clear
            label.isBezeled = false
            label.isEditable = false
            label.isSelectable = false
            label.frame = NSRect(x: 6, y: 8, width: 60, height: 14)
            contentContainer.addSubview(label)
        }

        // Page indicator "1/4"
        pageIndicator.font = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)
        pageIndicator.textColor = NSColor(white: 1.0, alpha: 0.4)
        pageIndicator.backgroundColor = .clear
        pageIndicator.isBezeled = false
        pageIndicator.isEditable = false
        pageIndicator.isSelectable = false
        pageIndicator.frame = NSRect(x: frame.width - 52, y: 8, width: 22, height: 14)
        addSubview(pageIndicator)

        closeButton.onTap = { [weak self] in self?.onClose?() }
        addSubview(closeButton)

        // Horizontal swipe gesture for page cycling
        // (vertical swipe is impractical on a 30pt tall bar)
        let swipe = NSPanGestureRecognizer(
            target: self, action: #selector(handleSwipe(_:)))
        swipe.allowedTouchTypes = [.direct]
        swipe.buttonMask = 0
        swipe.numberOfTouchesRequired = 1
        addGestureRecognizer(swipe)

        // Tap to cycle pages (fallback — works alongside swipe)
        let tap = NSClickGestureRecognizer(
            target: self, action: #selector(handleTapCycle(_:)))
        tap.allowedTouchTypes = [.direct]
        tap.buttonMask = 0
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Gesture Handlers

    @objc private func handleSwipe(_ gesture: NSPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            guard !hasTriggeredSwipe else { return }
            let translation = gesture.translation(in: self)
            // Horizontal swipe: right = next page, left = previous
            if translation.x > 20 {
                hasTriggeredSwipe = true
                setPage((currentPage + 1) % Self.pageCount, animated: true)
            } else if translation.x < -20 {
                hasTriggeredSwipe = true
                setPage((currentPage - 1 + Self.pageCount) % Self.pageCount,
                        animated: true)
            }
        case .ended, .cancelled:
            hasTriggeredSwipe = false
        default:
            break
        }
    }

    @objc private func handleTapCycle(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        // Tap anywhere on the popup (except X button) cycles to next page
        let loc = gesture.location(in: self)
        // Don't cycle if tapping near the X button (right 30pt)
        guard loc.x < frame.width - 30 else { return }
        setPage((currentPage + 1) % Self.pageCount, animated: true)
    }

    // MARK: - Page Navigation

    func setPage(_ page: Int, animated: Bool) {
        currentPage = page
        pageIndicator.stringValue = "\(page + 1)/\(Self.pageCount)"

        if animated {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.07
                contentContainer.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.updateLabelsForCurrentPage()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.08
                    self?.contentContainer.animator().alphaValue = 1
                }
            })
        } else {
            updateLabelsForCurrentPage()
        }
    }

    // MARK: - Label Updates Per Page

    private func updateLabelsForCurrentPage() {
        guard let d = pageData else { return }

        switch currentPage {
        case 0: // Who Am I?
            let name = d.creatureName.isEmpty ? "Pushling" : d.creatureName
            setLabel(label1, text: name,
                     color: d.stageColor, x: 6, width: 65)
            setLabel(label2, text: d.stageName.uppercased(),
                     color: NSColor(white: 1, alpha: 0.6), x: 74, width: 55)
            setLabel(label3, text: "XP \(d.currentXP)/\(d.xpToNext)",
                     color: NSColor(displayP3Red: 0, green: 0.831, blue: 1, alpha: 1),
                     x: 132, width: 75)
            setLabel(label4,
                     text: d.streakDays > 0 ? "Streak: \(d.streakDays)d" : "",
                     color: NSColor(displayP3Red: 1, green: 0.85, blue: 0.3, alpha: 1),
                     x: 212, width: 80)

        case 1: // How Do I Feel?
            let tint = emergentColor(d.emergentState)
            if let emergent = d.emergentState {
                // Emergent state: show name + bare bars
                setLabel(label1, text: emergent.capitalized,
                         color: tint ?? .white, x: 6, width: 75)
                setLabel(label2, text: emotionBar(d.satisfaction),
                         color: tint ?? NSColor(displayP3Red: 1, green: 0.4, blue: 0.5, alpha: 1),
                         x: 85, width: 35)
                setLabel(label3, text: emotionBar(d.curiosity),
                         color: tint ?? NSColor(displayP3Red: 0.3, green: 0.9, blue: 0.8, alpha: 1),
                         x: 125, width: 35)
                setLabel(label4, text: emotionBar(d.energy),
                         color: tint ?? NSColor(displayP3Red: 0.4, green: 1, blue: 0.5, alpha: 1),
                         x: 165, width: 35)
            } else {
                setLabel(label1, text: "Happy " + emotionBar(d.satisfaction),
                         color: NSColor(displayP3Red: 1, green: 0.4, blue: 0.5, alpha: 1),
                         x: 6, width: 78)
                setLabel(label2, text: "Curious " + emotionBar(d.curiosity),
                         color: NSColor(displayP3Red: 0.3, green: 0.9, blue: 0.8, alpha: 1),
                         x: 88, width: 80)
                setLabel(label3, text: "Cozy " + emotionBar(d.contentment),
                         color: NSColor(displayP3Red: 1, green: 0.8, blue: 0.3, alpha: 1),
                         x: 172, width: 68)
                setLabel(label4, text: "Energy " + emotionBar(d.energy),
                         color: NSColor(displayP3Red: 0.4, green: 1, blue: 0.5, alpha: 1),
                         x: 244, width: 68)
            }

        case 2: // What Am I Like?
            let desc = personalityDescription(d)
            let specColor = NSColor(
                hue: CGFloat(d.specialtyHue), saturation: 0.5,
                brightness: 1.0, alpha: 1.0)
            setLabel(label1, text: desc,
                     color: specColor, x: 6, width: 300)
            setLabel(label2, text: "", color: .clear, x: 0, width: 0)
            setLabel(label3, text: "", color: .clear, x: 0, width: 0)
            setLabel(label4, text: "", color: .clear, x: 0, width: 0)

        case 3: // What Have I Done?
            setLabel(label1, text: "Commits: \(d.commitsEaten)",
                     color: NSColor(displayP3Red: 0, green: 0.831, blue: 1, alpha: 1),
                     x: 6, width: 78)
            setLabel(label2, text: "Touches: \(d.totalTouches)",
                     color: NSColor(displayP3Red: 1, green: 0.4, blue: 0.5, alpha: 1),
                     x: 88, width: 78)
            setLabel(label3, text: "Badges: \(d.badgesEarned)/\(d.badgesTotal)",
                     color: NSColor(displayP3Red: 1, green: 0.85, blue: 0.3, alpha: 1),
                     x: 170, width: 72)
            setLabel(label4, text: "Tricks: \(d.tricksKnown)",
                     color: NSColor(displayP3Red: 0.7, green: 0.5, blue: 1, alpha: 1),
                     x: 246, width: 60)

        case 4: // What Do I Look Like?
            setLabel(label1, text: furDisplay(d.furPattern),
                     color: NSColor(white: 1, alpha: 0.7), x: 6, width: 72)
            setLabel(label2, text: eyeDisplay(d.eyeShape),
                     color: NSColor(white: 1, alpha: 0.7), x: 82, width: 80)
            setLabel(label3, text: tailDisplay(d.tailShape),
                     color: NSColor(white: 1, alpha: 0.7), x: 166, width: 72)
            let hueColor = NSColor(hue: CGFloat(d.baseColorHue),
                                    saturation: 0.5, brightness: 1, alpha: 1)
            setLabel(label4, text: "Hue",
                     color: hueColor, x: 242, width: 30)

        default:
            break
        }
    }

    // MARK: - Display Helpers

    private func emotionBar(_ value: Double) -> String {
        let filled = min(5, Int(value / 20.0))
        let empty = 5 - filled
        return String(repeating: "=", count: filled)
             + String(repeating: "-", count: empty)
    }

    private func personalityDescription(_ d: StatsPageData) -> String {
        let e = energyWord(d.pEnergy)
        let v = verbosityWord(d.pVerbosity)
        let f = focusWord(d.pFocus)
        let arch = archetypeWord(d.pDiscipline)
        return "A \(e), \(v), \(f) \(d.specialty) \(arch)"
    }

    private func energyWord(_ v: Double) -> String {
        if v < 0.2 { return "sleepy" }
        if v < 0.4 { return "calm" }
        if v < 0.6 { return "steady" }
        if v < 0.8 { return "lively" }
        return "hyper"
    }

    private func verbosityWord(_ v: Double) -> String {
        if v < 0.2 { return "silent" }
        if v < 0.4 { return "quiet" }
        if v < 0.6 { return "moderate" }
        if v < 0.8 { return "chatty" }
        return "loud"
    }

    private func focusWord(_ v: Double) -> String {
        if v < 0.2 { return "scattered" }
        if v < 0.4 { return "wandering" }
        if v < 0.6 { return "balanced" }
        if v < 0.8 { return "focused" }
        return "laser-focused"
    }

    private func archetypeWord(_ v: Double) -> String {
        if v < 0.2 { return "rebel" }
        if v < 0.4 { return "improviser" }
        if v < 0.6 { return "explorer" }
        if v < 0.8 { return "craftsman" }
        return "architect"
    }

    private func furDisplay(_ raw: String) -> String {
        switch raw {
        case "none": return "Solid fur"
        case "spots": return "Spotted fur"
        case "stripes": return "Striped fur"
        case "tabby": return "Tabby fur"
        default: return raw
        }
    }

    private func eyeDisplay(_ raw: String) -> String {
        switch raw {
        case "round": return "Round eyes"
        case "standard": return "Standard eyes"
        case "narrow": return "Narrow eyes"
        default: return raw
        }
    }

    private func tailDisplay(_ raw: String) -> String {
        switch raw {
        case "thin": return "Thin tail"
        case "fluffy": return "Fluffy tail"
        case "serpentine": return "Curly tail"
        case "standard": return "Standard tail"
        default: return raw
        }
    }

    private func setLabel(_ label: NSTextField, text: String,
                           color: NSColor, x: CGFloat, width: CGFloat) {
        label.stringValue = text
        label.textColor = color
        label.frame = NSRect(x: x, y: 8, width: width, height: 14)
    }

    private func emergentColor(_ state: String?) -> NSColor? {
        guard let state = state?.lowercased() else { return nil }
        switch state {
        case "blissful":  return NSColor(displayP3Red: 1, green: 0.9, blue: 0.5, alpha: 1)
        case "playful":   return NSColor(displayP3Red: 0.5, green: 1, blue: 0.6, alpha: 1)
        case "studious":  return NSColor(displayP3Red: 0.4, green: 0.8, blue: 1, alpha: 1)
        case "hangry":    return NSColor(displayP3Red: 1, green: 0.3, blue: 0.2, alpha: 1)
        case "zen":       return NSColor(displayP3Red: 0.7, green: 0.6, blue: 1, alpha: 1)
        case "exhausted": return NSColor(white: 0.5, alpha: 1)
        default:          return nil
        }
    }

    // MARK: - Data Update

    func update(data: StatsPageData) {
        self.pageData = data
        updateLabelsForCurrentPage()
    }
}

// MARK: - Menu Button (Private)

/// Reusable tappable button for Touch Bar overlay menus.
/// Uses NSClickGestureRecognizer — mouseDown doesn't fire on Touch Bar.
final class MenuButton: NSView {

    var onTap: (() -> Void)?
    private var buttonTextLayer: CATextLayer!

    init(frame: NSRect, label: String) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.85).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 0.35, alpha: 1.0).cgColor

        let tl = CATextLayer()
        tl.string = label
        tl.font = NSFont.boldSystemFont(ofSize: 11)
        tl.fontSize = 11
        tl.foregroundColor = NSColor(white: 1.0, alpha: 0.8).cgColor
        tl.alignmentMode = .center
        tl.contentsScale = 2.0
        let textH: CGFloat = 14
        tl.frame = CGRect(
            x: 0, y: (frame.height - textH) / 2,
            width: frame.width, height: textH
        )
        layer?.addSublayer(tl)
        buttonTextLayer = tl

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

    func setLabel(_ text: String) {
        buttonTextLayer.string = text
    }

    func setTextColor(_ color: NSColor) {
        buttonTextLayer.foregroundColor = color.cgColor
    }

    @objc private func handleTap(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        onTap?()
    }
}

// MARK: - GitHub Consent Popup

/// Popup asking for permission to check GitHub for richer personality data.
/// Shows exactly what data will be accessed. Two buttons: Allow / No Thanks.
final class GitHubConsentPopupView: NSView {

    var onConsent: (() -> Void)?
    var onDecline: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Learn from GitHub?")
    private let messageLabel = NSTextField(
        labelWithString: "Check your repos & languages via gh CLI")
    private let allowButton: MenuButton
    private let declineButton: MenuButton

    override init(frame: NSRect) {
        allowButton = MenuButton(
            frame: NSRect(x: frame.width - 90, y: 4, width: 40, height: 22),
            label: "Allow"
        )
        declineButton = MenuButton(
            frame: NSRect(x: frame.width - 46, y: 4, width: 44, height: 22),
            label: "No thx"
        )

        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        layer?.cornerRadius = 4
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 0.3, alpha: 0.6).cgColor

        let font = NSFont.monospacedSystemFont(ofSize: 8, weight: .medium)

        titleLabel.font = NSFont.boldSystemFont(ofSize: 9)
        titleLabel.textColor = NSColor(
            displayP3Red: 0, green: 0.831, blue: 1.0, alpha: 1.0)
        titleLabel.backgroundColor = .clear
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.frame = NSRect(x: 6, y: 15, width: 150, height: 12)
        addSubview(titleLabel)

        messageLabel.font = font
        messageLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        messageLabel.backgroundColor = .clear
        messageLabel.isBezeled = false
        messageLabel.isEditable = false
        messageLabel.isSelectable = false
        messageLabel.frame = NSRect(x: 6, y: 3, width: 200, height: 12)
        addSubview(messageLabel)

        allowButton.onTap = { [weak self] in self?.onConsent?() }
        declineButton.onTap = { [weak self] in self?.onDecline?() }

        addSubview(allowButton)
        addSubview(declineButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
