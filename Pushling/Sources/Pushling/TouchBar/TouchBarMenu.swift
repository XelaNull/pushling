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
    /// Called when the 20s fade completes — used to restore P label.
    var onFadeComplete: (() -> Void)?
    /// Called when a button is pressed during fade — restore M button brightness.
    var onRestoreBrightness: (() -> Void)?

    private let soundButton: MenuButton
    private let statsButton: MenuButton
    private var fadeTimer: Timer?
    private var isMuted = false
    static let fadeDuration: TimeInterval = 20.0

    private let expandedWidth: CGFloat = 84  // 30 + 2 + 50 + 2
    private let stripHeight: CGFloat = 30

    override init(frame: NSRect) {
        soundButton = MenuButton(
            frame: NSRect(x: 0, y: 0, width: 30, height: 30), label: "♪"
        )
        statsButton = MenuButton(
            frame: NSRect(x: 32, y: 0, width: 50, height: 30), label: "Stats"
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
        // Fade alpha from 1 to 0 over 20 seconds
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.isHidden = true
            self?.alphaValue = 1.0
            self?.frame.size.width = 0
            self?.onFadeComplete?()
        })
    }

    private func cancelFade() {
        // Cancel any in-progress fade animation
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        animator().alphaValue = 1.0
        NSAnimationContext.endGrouping()
        alphaValue = 1.0
    }

    /// Restore full brightness on button press during fade, and restart fade timer.
    func restoreBrightness() {
        cancelFade()
        onRestoreBrightness?()
        // Restart the fade from the beginning
        startFade()
    }

    var isExpanded: Bool { !isHidden && frame.width > 0 }
}

// MARK: - Stats Popup View

/// Overlay panel showing creature stats: stage, XP, satisfaction, streak.
/// Full Touch Bar height (30pt), 280pt wide, with [X] close button.
final class StatsPopupView: NSView {

    var onClose: (() -> Void)?

    private let stageLabel = NSTextField(labelWithString: "SPORE")
    private let xpLabel = NSTextField(labelWithString: "XP 0/100")
    private let heartsLabel = NSTextField(labelWithString: "-----")
    private let streakLabel = NSTextField(labelWithString: "")
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

        let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)

        configureLabel(stageLabel, font: font, x: 6)
        configureLabel(xpLabel, font: font, x: 70)
        xpLabel.textColor = NSColor(
            displayP3Red: 0, green: 0.831, blue: 1.0, alpha: 1.0
        )
        configureLabel(heartsLabel, font: font, x: 140)
        heartsLabel.textColor = NSColor(
            displayP3Red: 1.0, green: 0.35, blue: 0.3, alpha: 1.0
        )
        configureLabel(streakLabel, font: font, x: 200)
        streakLabel.textColor = NSColor(
            displayP3Red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0
        )

        closeButton.onTap = { [weak self] in self?.onClose?() }
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func configureLabel(_ label: NSTextField, font: NSFont, x: CGFloat) {
        label.font = font
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(x: x, y: 8, width: 60, height: 14)
        addSubview(label)
    }

    // MARK: - Data Update

    func update(stage: String, currentXP: Int, xpToNext: Int,
                satisfaction: Double, streakDays: Int,
                stageColor: NSColor) {
        stageLabel.stringValue = stage.uppercased()
        stageLabel.textColor = stageColor

        xpLabel.stringValue = "XP \(currentXP)/\(xpToNext)"

        let fullHearts = min(5, Int(satisfaction / 20.0))
        let emptyHearts = 5 - fullHearts
        heartsLabel.stringValue = String(repeating: "\u{2665}", count: fullHearts)
            + String(repeating: "\u{2661}", count: emptyHearts)

        if streakDays > 0 {
            streakLabel.stringValue = "\(streakDays)d"
        } else {
            streakLabel.stringValue = ""
        }
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
