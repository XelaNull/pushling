// NarrationOverlay.swift — Sage+ top-of-bar narration mode
// Instead of a bubble, narration text appears as an environmental overlay
// at the top of the Touch Bar, scrolling for long text.
//
// Triggered by pushling_speak(text, style: "narrate").
// Only available at Sage+ stage. Tappable to dismiss.

import SpriteKit

// MARK: - Narration Overlay

/// Environmental text overlay at the top of the Touch Bar.
/// Position: top of scene, centered. Font: 5pt, Bone at 80% opacity.
/// Background: subtle dark gradient (Void to transparent).
final class NarrationOverlay: SKNode {

    // MARK: - Configuration

    private static let fontSize: CGFloat = 5
    private static let overlayHeight: CGFloat = 10
    private static let scrollSpeed: CGFloat = 30  // pt/sec
    private static let staticMaxWidth: CGFloat = 80

    // MARK: - State

    private(set) var isActive = false
    private var textLabel: SKLabelNode?
    private var backgroundNode: SKShapeNode?
    private var scrollOffset: CGFloat = 0
    private var totalTextWidth: CGFloat = 0
    private var isScrolling = false
    private var holdTimer: TimeInterval = 0
    private var holdDuration: TimeInterval = 3.0
    private var fadeProgress: CGFloat = 0
    private var isDismissing = false

    // MARK: - Initialization

    override init() {
        super.init()
        self.name = "narrationOverlay"
        self.zPosition = 45  // Above bubbles, below debug
        self.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Setup

    /// Add the narration overlay to the scene.
    func addToScene(_ scene: SKScene) {
        position = CGPoint(
            x: scene.size.width / 2,
            y: scene.size.height - Self.overlayHeight / 2
        )
        scene.addChild(self)
    }

    // MARK: - Show Narration

    /// Display narration text.
    /// - Parameter text: The narration content.
    func show(text: String) {
        // Clean up previous
        removeAllChildren()
        textLabel = nil
        backgroundNode = nil

        isActive = true
        isDismissing = false
        isHidden = false
        alpha = 1.0
        holdTimer = 0

        // Background gradient
        let bg = SKShapeNode(
            rectOf: CGSize(
                width: SceneConstants.sceneWidth,
                height: Self.overlayHeight
            ),
            cornerRadius: 0
        )
        bg.fillColor = PushlingPalette.withAlpha(
            PushlingPalette.void_, alpha: 0.6
        )
        bg.strokeColor = .clear
        bg.position = .zero
        addChild(bg)
        backgroundNode = bg

        // Text label
        let label = SKLabelNode(fontNamed: "SFProText-Regular")
        label.fontSize = Self.fontSize
        label.fontColor = PushlingPalette.withAlpha(
            PushlingPalette.bone, alpha: 0.8
        )
        label.text = text
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = .zero

        addChild(label)
        textLabel = label

        // Determine if scrolling is needed
        totalTextWidth = CGFloat(text.count) * Self.fontSize * 0.55
        if totalTextWidth > Self.staticMaxWidth {
            isScrolling = true
            scrollOffset = SceneConstants.sceneWidth / 2
            label.horizontalAlignmentMode = .left
            label.position.x = scrollOffset
            // Scroll duration = total width / speed
            holdDuration = TimeInterval(
                (totalTextWidth + SceneConstants.sceneWidth) / Self.scrollSpeed
            )
        } else {
            isScrolling = false
            // Static: calculate hold from word count
            let wordCount = text.split(separator: " ").count
            holdDuration = max(2.0, min(5.0, Double(wordCount) * 0.5 + 1.0))
        }

        NSLog("[Pushling/Speech] Narration: \"%@\" (scroll=%@, hold=%.1fs)",
              text, isScrolling ? "yes" : "no", holdDuration)
    }

    // MARK: - Update

    /// Per-frame update. Called from the scene update loop.
    func update(deltaTime: TimeInterval) {
        guard isActive else { return }

        if isDismissing {
            fadeProgress += CGFloat(deltaTime) / 0.15
            alpha = max(0, 1.0 - fadeProgress)
            if fadeProgress >= 1.0 {
                hide()
            }
            return
        }

        holdTimer += deltaTime

        if isScrolling {
            // Scroll text left
            scrollOffset -= Self.scrollSpeed * CGFloat(deltaTime)
            textLabel?.position.x = scrollOffset

            // Check if text has fully scrolled through
            if scrollOffset < -(totalTextWidth + 10) {
                beginDismiss()
            }
        } else {
            // Static text: dismiss after hold
            if holdTimer >= holdDuration {
                beginDismiss()
            }
        }
    }

    // MARK: - Dismiss

    /// Begin the fade-out dismissal.
    func beginDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        fadeProgress = 0
    }

    /// Handle a tap to immediately dismiss.
    func handleTap() {
        if isActive {
            beginDismiss()
        }
    }

    /// Dim the narration when a regular speech bubble is active.
    func dimForSpeech() {
        if isActive {
            alpha = 0.4
        }
    }

    /// Restore full opacity after speech bubble dismisses.
    func restoreFromDim() {
        if isActive && !isDismissing {
            alpha = 1.0
        }
    }

    // MARK: - Private

    private func hide() {
        isActive = false
        isHidden = true
        isDismissing = false
        removeAllChildren()
        textLabel = nil
        backgroundNode = nil
    }
}
