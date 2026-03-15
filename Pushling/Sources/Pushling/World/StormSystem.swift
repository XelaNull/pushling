// StormSystem.swift — Lightning, screen shake, and thunder
// P3-T2-07: Full 1085pt jagged lightning crack, 2pt screen shake,
// thunder delay 0.5-2.0s after flash.
//
// Storm = heavy rain (handled by RainRenderer at 1.5x spawn) + lightning + shake.
// Lightning: 8-12 segment polyline, 100ms flash then 200ms afterimage.
// Frequency: every 8-20 seconds during storm.

import SpriteKit

// MARK: - Lightning Node

/// A jagged lightning crack spanning the full Touch Bar width.
/// Rendered as an SKShapeNode polyline with random horizontal offsets.
final class LightningNode: SKShapeNode {

    /// Scene dimensions.
    private static let sceneWidth: CGFloat = 1085
    private static let sceneHeight: CGFloat = 30

    /// Segment count range for the crack.
    private static let segmentRange = 8...12

    /// Maximum horizontal offset per segment.
    private static let maxHorizontalOffset: CGFloat = 40

    /// Generate a new random lightning crack shape.
    func regenerateCrack() {
        let segmentCount = Int.random(in: Self.segmentRange)
        let path = CGMutablePath()

        // Start from a random position along the top
        let startX = CGFloat.random(in: 200...(Self.sceneWidth - 200))
        path.move(to: CGPoint(x: startX, y: Self.sceneHeight))

        var currentX = startX
        let yStep = Self.sceneHeight / CGFloat(segmentCount)

        for i in 1...segmentCount {
            let offsetX = CGFloat.random(in: -Self.maxHorizontalOffset...Self.maxHorizontalOffset)
            currentX += offsetX

            // Clamp to screen bounds
            currentX = max(10, min(Self.sceneWidth - 10, currentX))

            let y = Self.sceneHeight - yStep * CGFloat(i)
            path.addLine(to: CGPoint(x: currentX, y: max(0, y)))
        }

        self.path = path
    }

    /// Configure the visual appearance.
    func configure() {
        strokeColor = PushlingPalette.bone
        lineWidth = 1.5
        glowWidth = 2.0
        zPosition = 200  // Above everything during flash
        alpha = 0
        isAntialiased = false
    }
}

// MARK: - Storm System

/// Manages lightning strikes, screen shake, and thunder during storms.
/// Coordinates with RainRenderer for heavy rain.
final class StormSystem {

    // MARK: - Constants

    /// Lightning frequency range (seconds between strikes).
    private static let strikeCooldownRange: ClosedRange<TimeInterval> = 8...20

    /// Flash duration (seconds).
    private static let flashDuration: TimeInterval = 0.1  // 100ms

    /// Afterimage duration (seconds).
    private static let afterimageDuration: TimeInterval = 0.2  // 200ms

    /// Afterimage alpha.
    private static let afterimageAlpha: CGFloat = 0.3

    /// Screen shake magnitude (points).
    private static let shakeMagnitude: CGFloat = 2.0

    /// Screen shake duration (seconds).
    private static let shakeDuration: TimeInterval = 0.3  // 300ms

    /// Thunder delay range after lightning (seconds).
    private static let thunderDelayRange: ClosedRange<TimeInterval> = 0.5...2.0

    /// Flash overlay alpha (full-screen brightness flash).
    private static let flashOverlayAlpha: CGFloat = 0.15

    // MARK: - Nodes

    /// The lightning crack shape node (recycled, not recreated).
    private let lightningNode = LightningNode()

    /// Full-screen flash overlay (brief brightness on lightning).
    private let flashOverlay: SKSpriteNode

    /// Container for all storm elements.
    private let containerNode = SKNode()

    // MARK: - State

    /// Intensity (0.0 = inactive, 1.0 = full storm).
    var intensity: CGFloat = 0

    /// Whether the storm is active (spawning lightning).
    private var isActive = false

    /// Time until next lightning strike.
    private var timeUntilStrike: TimeInterval = 0

    /// Whether a lightning flash is currently playing.
    private var isFlashing = false

    /// Flash phase timer.
    private var flashTimer: TimeInterval = 0

    /// Flash phase: .flash, .afterimage, .none
    private var flashPhase: FlashPhase = .none

    /// Reference to scene node for screen shake.
    weak var sceneNode: SKNode?

    /// Delegate for creature reactions.
    weak var reactionDelegate: WeatherReactionDelegate?

    /// Pre-shake scene position (to restore after shake).
    private var originalScenePosition: CGPoint = .zero

    /// Shake timer.
    private var shakeTimer: TimeInterval = 0

    /// Whether currently shaking.
    private var isShaking = false

    // MARK: - Flash Phase

    private enum FlashPhase {
        case none
        case flash       // Full brightness, 100ms
        case afterimage  // Dim glow, 200ms
    }

    // MARK: - Init

    init() {
        lightningNode.configure()

        // Create flash overlay
        flashOverlay = SKSpriteNode(
            color: PushlingPalette.bone,
            size: CGSize(width: 1085, height: 30)
        )
        flashOverlay.anchorPoint = CGPoint(x: 0, y: 0)
        flashOverlay.position = .zero
        flashOverlay.zPosition = 199  // Just below lightning
        flashOverlay.alpha = 0
        flashOverlay.blendMode = .add

        containerNode.addChild(lightningNode)
        containerNode.addChild(flashOverlay)
        containerNode.zPosition = 100
        containerNode.alpha = 0

        // Set initial cooldown
        timeUntilStrike = TimeInterval.random(in: Self.strikeCooldownRange)
    }

    // MARK: - Scene Integration

    func addToScene(parent: SKNode) {
        parent.addChild(containerNode)
    }

    // MARK: - Activation

    func activate() {
        isActive = true
        containerNode.alpha = 1
        timeUntilStrike = TimeInterval.random(in: 2...5)  // First strike sooner
    }

    func deactivate() {
        isActive = false
        // Let current flash finish, then hide
        if !isFlashing {
            containerNode.alpha = 0
        }
    }

    // MARK: - Frame Update

    /// Update lightning timing, flash animation, and screen shake.
    func update(deltaTime: TimeInterval, weatherSystem: WeatherSystem) {
        guard isActive || isFlashing || isShaking else { return }

        // Update strike timer
        if isActive && !isFlashing {
            timeUntilStrike -= deltaTime
            if timeUntilStrike <= 0 {
                triggerLightning(weatherSystem: weatherSystem)
                timeUntilStrike = TimeInterval.random(in: Self.strikeCooldownRange)
            }
        }

        // Update flash animation
        if isFlashing {
            updateFlash(deltaTime: deltaTime)
        }

        // Update screen shake
        if isShaking {
            updateShake(deltaTime: deltaTime)
        }
    }

    // MARK: - Lightning Strike

    /// Trigger a lightning strike sequence.
    private func triggerLightning(weatherSystem: WeatherSystem) {
        // Generate new crack shape
        lightningNode.regenerateCrack()

        // Begin flash phase
        isFlashing = true
        flashPhase = .flash
        flashTimer = 0

        // Set initial brightness
        lightningNode.alpha = 1.0
        lightningNode.strokeColor = PushlingPalette.bone
        lightningNode.glowWidth = 3.0
        flashOverlay.alpha = Self.flashOverlayAlpha

        // Start screen shake
        beginShake()

        // Notify creature of lightning (visual)
        weatherSystem.reactionDelegate?.lightningStruck()

        // Schedule thunder (delayed)
        let thunderDelay = TimeInterval.random(in: Self.thunderDelayRange)
        DispatchQueue.main.asyncAfter(deadline: .now() + thunderDelay) { [weak weatherSystem] in
            weatherSystem?.reactionDelegate?.thunderRumbled()
        }

        NSLog("[Pushling] Lightning strike! Thunder in \(String(format: "%.1f", thunderDelay))s")
    }

    /// Update the flash animation phases.
    private func updateFlash(deltaTime: TimeInterval) {
        flashTimer += deltaTime

        switch flashPhase {
        case .flash:
            if flashTimer >= Self.flashDuration {
                // Transition to afterimage
                flashPhase = .afterimage
                flashTimer = 0
                lightningNode.alpha = Self.afterimageAlpha
                lightningNode.strokeColor = PushlingPalette.gilt
                lightningNode.glowWidth = 1.0
                flashOverlay.alpha = 0
            }

        case .afterimage:
            // Fade out over the afterimage duration
            let progress = CGFloat(flashTimer / Self.afterimageDuration)
            lightningNode.alpha = Self.afterimageAlpha * (1.0 - progress)

            if flashTimer >= Self.afterimageDuration {
                // Flash complete
                flashPhase = .none
                isFlashing = false
                lightningNode.alpha = 0
                flashOverlay.alpha = 0

                if !isActive {
                    containerNode.alpha = 0
                }
            }

        case .none:
            isFlashing = false
        }
    }

    // MARK: - Screen Shake

    /// Begin screen shake effect.
    private func beginShake() {
        guard let scene = sceneNode else { return }
        isShaking = true
        shakeTimer = 0
        originalScenePosition = scene.position
    }

    /// Update screen shake — random 2pt offsets decaying over duration.
    private func updateShake(deltaTime: TimeInterval) {
        guard let scene = sceneNode else {
            isShaking = false
            return
        }

        shakeTimer += deltaTime

        if shakeTimer >= Self.shakeDuration {
            // Restore original position
            scene.position = originalScenePosition
            isShaking = false
            return
        }

        // Decaying random offset
        let decay = CGFloat(1.0 - shakeTimer / Self.shakeDuration)
        let offsetX = CGFloat.random(in: -Self.shakeMagnitude...Self.shakeMagnitude) * decay
        let offsetY = CGFloat.random(in: -Self.shakeMagnitude...Self.shakeMagnitude) * decay
        scene.position = CGPoint(
            x: originalScenePosition.x + offsetX,
            y: originalScenePosition.y + offsetY
        )
    }
}
