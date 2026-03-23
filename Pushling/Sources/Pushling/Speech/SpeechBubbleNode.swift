// SpeechBubbleNode.swift — Visual speech bubble for the Pushling creature
// SKShapeNode (bubble+tail) + SKLabelNode (text). 7 styles. 2 nodes per bubble.
// Palette-locked: Gilt fill, Void text, Bone border. Child of creature node.

import SpriteKit

// MARK: - Speech Style

/// The 7 speech bubble styles.
enum SpeechStyle: String, Codable, CaseIterable {
    case say       // Standard bubble (default)
    case think     // Cloud-shaped, Ash fill
    case exclaim   // Spiky edges, Ember accent
    case whisper   // Small, close to creature
    case sing      // Musical note particles
    case dream     // Dusk fill, wavy text, during sleep only
    case narrate   // Top-of-bar overlay, Sage+ only

    /// Minimum growth stage required to use this style.
    var minimumStage: GrowthStage {
        switch self {
        case .say:     return .drop
        case .think:   return .drop
        case .exclaim: return .critter
        case .whisper: return .critter
        case .sing:    return .critter
        case .dream:   return .drop  // Any stage during sleep
        case .narrate: return .sage
        }
    }

    /// Whether this style produces a speech bubble (vs narration overlay).
    var usesBubble: Bool {
        self != .narrate
    }
}

// MARK: - Bubble Position Mode

/// How the bubble is positioned relative to the creature.
enum BubblePositionMode {
    case above     // Compact, directly above creature (Critter)
    case sideRight // To the right of creature (Beast+)
    case sideLeft  // To the left of creature (edge case)
    case floating  // No bubble frame, glyph floats (Drop)
}

// MARK: - Speech Bubble Node

/// A single speech bubble displayed on the Touch Bar.
/// Contains a shape (bubble + tail) and a label (text).
/// Total node count: 2 nodes.
final class SpeechBubbleNode: SKNode {

    // MARK: - Configuration

    /// The text being displayed.
    private(set) var text: String = ""

    /// The speech style.
    private(set) var style: SpeechStyle = .say

    /// Current display phase.
    private(set) var phase: BubblePhase = .idle

    // MARK: - Child Nodes

    /// The bubble shape (rounded rect + tail), or nil for Drop/narrate.
    private var bubbleShape: SKShapeNode?

    /// The text label.
    private var textLabel: SKLabelNode?

    /// Musical note particles for sing style.
    private var singParticles: [SKLabelNode]?

    // MARK: - Animation State

    private var phaseTimer: TimeInterval = 0
    private var holdDuration: TimeInterval = 1.5
    private var appearDuration: TimeInterval = 0.15
    private var disappearDuration: TimeInterval = 0.4

    /// For Drop floating: accumulated time for sine-wave drift.
    private var floatTime: TimeInterval = 0

    /// For dream style: per-character wave offsets.
    private var dreamWaveTime: TimeInterval = 0

    // MARK: - Bubble Phase

    enum BubblePhase {
        case idle       // Not visible
        case appearing  // Scale + fade in
        case holding    // Visible, counting down
        case disappearing // Fade out + drift up
        case done       // Ready for removal
    }

    // MARK: - Initialization

    override init() {
        super.init()
        self.name = "speechBubble"
        self.zPosition = 40  // Above creature parts, below weather
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Configuration

    /// Configure the bubble for display.
    /// - Parameters:
    ///   - text: The text to show.
    ///   - style: Visual style.
    ///   - stage: Current creature growth stage.
    ///   - positionMode: Where to place the bubble.
    func configure(text: String,
                    style: SpeechStyle,
                    stage: GrowthStage,
                    positionMode: BubblePositionMode) {
        // Clean up previous
        removeAllChildren()
        bubbleShape = nil
        textLabel = nil
        singParticles = nil

        self.text = text
        self.style = style
        self.phase = .idle

        // Calculate hold duration
        let wordCount = text.split(separator: " ").count
        if text.count <= 3 {
            // Symbols: readable duration
            holdDuration = 2.5
        } else {
            holdDuration = max(3.0, min(8.0, Double(wordCount) * 0.8 + 1.5))
        }

        if positionMode == .floating {
            // Drop stage: floating glyph, no bubble frame
            configureFloatingGlyph(text: text, style: style)
        } else {
            // Standard bubble
            configureBubble(
                text: text, style: style,
                stage: stage, positionMode: positionMode
            )
        }

        // Position based on mode and stage
        applyPosition(stage: stage, mode: positionMode)
    }

    // MARK: - Floating Glyph (Drop Stage)

    private func configureFloatingGlyph(text: String, style: SpeechStyle) {
        let label = SKLabelNode(fontNamed: "SFProText-Bold")
        label.fontSize = 8
        label.fontColor = style == .dream
            ? PushlingPalette.dusk : PushlingPalette.gilt
        label.text = text
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = .zero
        addChild(label)
        textLabel = label
    }

    // MARK: - Standard Bubble

    private func configureBubble(text: String,
                                   style: SpeechStyle,
                                   stage: GrowthStage,
                                   positionMode: BubblePositionMode) {
        let fontSize: CGFloat = stage >= .beast ? 7 : 6
        let maxWidth = bubbleMaxWidth(for: stage)

        // Create text label first to measure it
        let label = SKLabelNode(fontNamed: "SFProText-Regular")
        label.fontSize = fontSize
        label.text = text
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        // Apply style-specific text color
        switch style {
        case .dream:
            label.fontColor = PushlingPalette.withAlpha(
                PushlingPalette.bone, alpha: 0.7
            )
        case .whisper:
            label.fontColor = PushlingPalette.ash
        case .exclaim:
            label.fontSize = fontSize + 1
            label.fontColor = PushlingPalette.void_
        default:
            label.fontColor = PushlingPalette.void_
        }

        // Calculate bubble size based on text
        let textWidth = min(CGFloat(text.count) * fontSize * 0.55, maxWidth)
        let needsWrap = textWidth >= maxWidth && stage >= .beast
        let lineCount: CGFloat = needsWrap ? 2 : 1
        let paddingH: CGFloat = 3
        let paddingV: CGFloat = 2

        let bubbleWidth = min(textWidth + paddingH * 2, maxWidth)
        let bubbleHeight = fontSize * lineCount + paddingV * 2

        // Word wrap for Beast+
        if needsWrap {
            label.preferredMaxLayoutWidth = maxWidth - paddingH * 2
            label.numberOfLines = 2
            label.lineBreakMode = .byWordWrapping
        }

        // Create bubble shape with tail
        let shape = makeBubblePath(
            width: bubbleWidth, height: bubbleHeight,
            style: style, positionMode: positionMode
        )

        // Style-specific fill and stroke
        switch style {
        case .say, .sing:
            shape.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.85)
            shape.strokeColor = PushlingPalette.bone; shape.lineWidth = 1
        case .exclaim:
            shape.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.85)
            shape.strokeColor = PushlingPalette.ember; shape.lineWidth = 1.5
        case .think:
            shape.fillColor = PushlingPalette.withAlpha(PushlingPalette.ash, alpha: 0.60)
            shape.strokeColor = PushlingPalette.bone; shape.lineWidth = 0.5
        case .whisper:
            shape.fillColor = PushlingPalette.withAlpha(PushlingPalette.ash, alpha: 0.40)
            shape.strokeColor = .clear; shape.lineWidth = 0
        case .dream:
            shape.fillColor = PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.50)
            shape.strokeColor = .clear; shape.lineWidth = 0
        case .narrate: break
        }

        // Position label inside bubble
        label.position = CGPoint(x: 0, y: 0)

        addChild(shape)
        addChild(label)
        bubbleShape = shape
        textLabel = label

        // Sing style: add musical note particles
        if style == .sing {
            addSingParticles()
        }
    }

    // MARK: - Bubble Shape Path

    /// Create the bubble + tail as a single CGPath.
    /// Total: 1 SKShapeNode (keeps node count at 2 total).
    private func makeBubblePath(
        width: CGFloat, height: CGFloat,
        style: SpeechStyle,
        positionMode: BubblePositionMode
    ) -> SKShapeNode {
        let path = CGMutablePath()
        let cornerRadius: CGFloat = style == .think ? 5 : 3
        let halfW = width / 2
        let halfH = height / 2
        let tailWidth: CGFloat = 4
        let tailHeight: CGFloat = 5

        // Bubble rectangle (centered at origin)
        let bubbleRect = CGRect(x: -halfW, y: -halfH,
                                  width: width, height: height)

        if style == .think {
            // Cloud-shaped: use ellipse for scalloped look
            path.addEllipse(in: bubbleRect)
        } else if style == .exclaim {
            // Slightly wider corners for spiky feel
            path.addRoundedRect(in: bubbleRect, cornerWidth: 2,
                                 cornerHeight: 2)
        } else {
            path.addRoundedRect(in: bubbleRect,
                                 cornerWidth: cornerRadius,
                                 cornerHeight: cornerRadius)
        }

        // Tail triangle (only for non-think, non-dream styles)
        if style != .think && style != .dream {
            let tailBaseY = -halfH
            let tailTipY = tailBaseY - tailHeight

            // Tail position based on bubble position mode
            let tailCenterX: CGFloat
            switch positionMode {
            case .sideRight: tailCenterX = -halfW + tailWidth
            case .sideLeft:  tailCenterX = halfW - tailWidth
            default:         tailCenterX = 0  // Centered below
            }

            path.move(to: CGPoint(x: tailCenterX - tailWidth / 2,
                                    y: tailBaseY))
            path.addLine(to: CGPoint(x: tailCenterX, y: tailTipY))
            path.addLine(to: CGPoint(x: tailCenterX + tailWidth / 2,
                                      y: tailBaseY))
        }

        return SKShapeNode(path: path)
    }

    /// Position the bubble relative to the creature.
    private func applyPosition(stage: GrowthStage, mode: BubblePositionMode) {
        guard let config = StageConfiguration.all[stage] else { return }
        let h = config.size.height, w = config.size.width
        switch mode {
        case .above:    position = CGPoint(x: 0, y: h / 2 + 1)
        case .sideRight: position = CGPoint(x: w / 2 + 5, y: 0)
        case .sideLeft:  position = CGPoint(x: -(w / 2 + 5), y: 0)
        case .floating:  position = CGPoint(x: 0, y: h / 2 + 1)
        }
    }

    /// Ensure the bubble is fully visible within the Touch Bar scene (1085x30pt).
    /// Called after the bubble is added as a child of the creature.
    /// Converts to scene coordinates, clamps, and adjusts local position.
    func clampToSceneBounds() {
        guard let creature = parent, let scene = creature.scene else { return }
        let sceneWidth = scene.size.width
        let sceneHeight = scene.size.height

        // Convert bubble center to scene coordinates
        let scenePos = convert(.zero, to: scene)

        // Estimate bubble size from children
        let bubbleHalfHeight: CGFloat = 8  // Approximate max bubble half-height
        let bubbleHalfWidth: CGFloat = 40  // Approximate max bubble half-width

        // Clamp vertically: bubble must stay within [0, sceneHeight]
        let topEdge = scenePos.y + bubbleHalfHeight
        let bottomEdge = scenePos.y - bubbleHalfHeight
        if topEdge > sceneHeight {
            // Bubble goes above scene — push it down
            position.y -= (topEdge - sceneHeight + 1)
        }
        if bottomEdge < 0 {
            // Bubble goes below scene — push it up
            position.y += (-bottomEdge + 1)
        }

        // Clamp horizontally: bubble must stay within [0, sceneWidth]
        let rightEdge = scenePos.x + bubbleHalfWidth
        let leftEdge = scenePos.x - bubbleHalfWidth
        if rightEdge > sceneWidth {
            position.x -= (rightEdge - sceneWidth + 1)
        }
        if leftEdge < 0 {
            position.x += (-leftEdge + 1)
        }
    }

    private func bubbleMaxWidth(for stage: GrowthStage) -> CGFloat {
        switch stage {
        case .egg: return 0;  case .drop: return 12
        case .critter: return 40; case .beast: return 60
        case .sage: return 80;  case .apex: return 120
        }
    }

    private func addSingParticles() {
        let noteChars = ["\u{266A}", "\u{266B}", "\u{2669}"]
        var notes: [SKLabelNode] = []
        for i in 0..<3 {
            let note = SKLabelNode(text: noteChars[i])
            note.fontSize = 5; note.fontColor = PushlingPalette.gilt
            note.alpha = 0.6
            let angle = CGFloat(i) * (.pi * 2 / 3)
            note.position = CGPoint(x: cos(angle) * 12, y: sin(angle) * 6)
            addChild(note); notes.append(note)
        }
        singParticles = notes
    }

    // MARK: - Animation

    /// Begin the appear animation.
    func appear() {
        phase = .appearing
        phaseTimer = 0
        alpha = 0
        setScale(0.0)
        isHidden = false
    }

    /// Per-frame update. Called from the scene update loop.
    func update(deltaTime: TimeInterval) {
        phaseTimer += deltaTime

        switch phase {
        case .idle:
            break

        case .appearing:
            updateAppear(deltaTime: deltaTime)

        case .holding:
            updateHold(deltaTime: deltaTime)

        case .disappearing:
            updateDisappear(deltaTime: deltaTime)

        case .done:
            break
        }

        // Re-clamp every frame to handle creature movement and bubble drift
        if phase == .holding || phase == .appearing {
            clampToSceneBounds()
        }

        // Style-specific updates
        if style == .sing {
            updateSingParticles(deltaTime: deltaTime)
        }
        if style == .dream {
            updateDreamWave(deltaTime: deltaTime)
        }
        if style == .say && bubbleShape == nil {
            // Drop floating glyph
            updateFloatingGlyph(deltaTime: deltaTime)
        }
    }

    // MARK: - Phase Updates

    private func updateAppear(deltaTime: TimeInterval) {
        let t = min(1.0, phaseTimer / appearDuration)

        if t < 0.8 {
            // Scale overshoot
            let scaleT = Easing.easeOut(t / 0.8)
            setScale(CGFloat(scaleT) * 1.05)
        } else {
            // Settle
            let settleT = (t - 0.8) / 0.2
            let scale = 1.05 - 0.05 * CGFloat(settleT)
            setScale(scale)
        }

        alpha = CGFloat(min(1.0, t / 0.67))

        if t >= 1.0 {
            setScale(1.0)
            alpha = 1.0
            phase = .holding
            phaseTimer = 0
        }
    }

    private func updateHold(deltaTime: TimeInterval) {
        if phaseTimer >= holdDuration {
            phase = .disappearing
            phaseTimer = 0
        }
    }

    private func updateDisappear(deltaTime: TimeInterval) {
        let t = min(1.0, phaseTimer / disappearDuration)
        let easedT = Easing.easeIn(t)

        setScale(CGFloat(1.0 - 0.05 * easedT))
        alpha = CGFloat(1.0 - easedT)

        // Slight upward drift
        position.y += CGFloat(deltaTime) * 7.5  // 3pt over 0.4s

        if t >= 1.0 {
            phase = .done
            isHidden = true
        }
    }

    // MARK: - Style-Specific Updates

    private func updateFloatingGlyph(deltaTime: TimeInterval) {
        guard phase == .holding else { return }
        floatTime += deltaTime

        // Upward drift: 6pt over hold duration
        let driftSpeed = 6.0 / holdDuration
        position.y += CGFloat(deltaTime * driftSpeed)

        // Sine-wave horizontal drift
        let xOffset = sin(floatTime * 2.0 * .pi / 1.5) * 2.0
        textLabel?.position.x = CGFloat(xOffset)
    }

    private func updateSingParticles(deltaTime: TimeInterval) {
        guard let notes = singParticles else { return }
        floatTime += deltaTime
        for (i, note) in notes.enumerated() {
            let angle = floatTime * 2.0 + Double(i) * (.pi * 2 / 3)
            note.position = CGPoint(
                x: cos(angle) * 12,
                y: sin(angle) * 6
            )
            note.zRotation = CGFloat(sin(floatTime * 3.0 + Double(i))
                                       * 0.25)
        }
    }

    private func updateDreamWave(deltaTime: TimeInterval) {
        // Dream text wave is handled via label attributes — simplified
        // here to a gentle Y oscillation on the label itself
        dreamWaveTime += deltaTime
        textLabel?.position.y = CGFloat(
            sin(dreamWaveTime * 2.0) * 1.0
        )
    }

    // MARK: - Dismiss

    /// Immediately begin the disappear animation.
    func dismiss() {
        if phase == .holding || phase == .appearing {
            phase = .disappearing
            phaseTimer = 0
        }
    }

    /// Check if the bubble has finished its lifecycle.
    var isDone: Bool { phase == .done }
}
