// PuddleReflection.swift — 1-pixel mirrored creature silhouette in water
// P3-T3-04: When near a water puddle, render a reflection below the puddle surface.
//
// The reflection is a simplified 1-pixel-tall mirrored shape of the creature,
// rendered at alpha 0.15 in the creature's primary color. Ripple when walking through.
// One of the "Wow Factor" moments — someone cared.
//
// Node budget: 2 nodes (reflection shape + ripple overlay). Only active near puddles.

import SpriteKit

// MARK: - Puddle Reflection

/// Manages puddle reflection rendering for the creature.
/// Added to the foreground layer. Activates when creature is near a water puddle.
final class PuddleReflection {

    // MARK: - Constants

    /// Distance within which the reflection appears (points).
    private static let activationDistance: CGFloat = 10.0

    /// Reflection alpha — subtle, a discovery moment.
    private static let reflectionAlpha: CGFloat = 0.15

    /// Ripple duration when walking through puddle.
    private static let rippleDuration: TimeInterval = 0.5

    /// How often the creature might pause to look at reflection (probability per check).
    private static let gazeChance: Double = 0.05

    /// Cooldown between gaze checks (seconds).
    private static let gazeCooldown: TimeInterval = 10.0

    // MARK: - Nodes

    /// The reflection node — a thin mirrored silhouette.
    private let reflectionNode: SKShapeNode

    /// Ripple effect overlay node.
    private let rippleNode: SKShapeNode

    // MARK: - State

    /// Whether the reflection is currently visible.
    private(set) var isActive = false

    /// Current target puddle world-X position (nil if no nearby puddle).
    private var puddleWorldX: CGFloat?

    /// The creature stage for sizing the reflection.
    private var creatureStage: GrowthStage = .critter

    /// Time since last gaze check.
    private var gazeCooldownTimer: TimeInterval = 0

    /// Whether currently rippling.
    private var isRippling = false

    // MARK: - Init

    init() {
        // Reflection — a small rectangle representing the mirrored creature
        reflectionNode = SKShapeNode()
        reflectionNode.strokeColor = .clear
        reflectionNode.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone,
                                                              alpha: Self.reflectionAlpha)
        reflectionNode.alpha = 0
        reflectionNode.name = "puddle_reflection"
        reflectionNode.zPosition = -1  // Below terrain surface

        // Ripple — expanding ellipse
        rippleNode = SKShapeNode(ellipseOf: CGSize(width: 6, height: 1))
        rippleNode.strokeColor = PushlingPalette.withAlpha(PushlingPalette.tide,
                                                            alpha: 0.3)
        rippleNode.fillColor = .clear
        rippleNode.lineWidth = 0.5
        rippleNode.alpha = 0
        rippleNode.name = "puddle_ripple"
        rippleNode.zPosition = -0.5
    }

    // MARK: - Scene Integration

    /// Add reflection nodes to the foreground layer.
    func addToLayer(_ foreLayer: SKNode) {
        foreLayer.addChild(reflectionNode)
        foreLayer.addChild(rippleNode)
    }

    /// Remove from scene (cleanup).
    func removeFromScene() {
        reflectionNode.removeFromParent()
        rippleNode.removeFromParent()
    }

    // MARK: - Configuration

    /// Update the reflection appearance for the current creature stage.
    func configureForStage(_ stage: GrowthStage) {
        creatureStage = stage
        guard let config = StageConfiguration.all[stage] else { return }

        // Rebuild reflection shape — simplified rectangle matching creature width
        let w = config.size.width * 0.8
        let h: CGFloat = 1.0  // 1-pixel tall reflection

        let path = CGMutablePath()
        path.addRect(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        reflectionNode.path = path
        reflectionNode.fillColor = PushlingPalette.withAlpha(
            PushlingPalette.stageColor(for: stage),
            alpha: Self.reflectionAlpha
        )
    }

    // MARK: - Frame Update

    /// Update reflection state. Call each frame from the scene update loop.
    /// - Parameters:
    ///   - creatureWorldX: Creature's current world-X position.
    ///   - creatureY: Creature's current Y position.
    ///   - nearestPuddleX: World-X of the nearest water puddle (nil if none nearby).
    ///   - puddleY: Y position of the puddle surface.
    ///   - deltaTime: Time since last frame.
    /// - Returns: True if the creature should pause to gaze at its reflection.
    @discardableResult
    func update(creatureWorldX: CGFloat,
                creatureY: CGFloat,
                nearestPuddleX: CGFloat?,
                puddleY: CGFloat,
                deltaTime: TimeInterval) -> Bool {

        gazeCooldownTimer -= deltaTime
        var shouldGaze = false

        guard let puddleX = nearestPuddleX else {
            // No puddle nearby — hide reflection
            if isActive {
                hideReflection()
            }
            return false
        }

        let distance = abs(creatureWorldX - puddleX)

        if distance < Self.activationDistance {
            if !isActive {
                showReflection()
            }

            // Position reflection below puddle surface, mirroring creature X
            reflectionNode.position = CGPoint(
                x: creatureWorldX,
                y: puddleY - 1.5
            )

            // Mirror the creature's X-scale (flip) for reflection effect
            reflectionNode.yScale = -1.0

            // Trigger ripple when very close (walking through)
            if distance < 4.0 && !isRippling {
                triggerRipple(at: CGPoint(x: creatureWorldX, y: puddleY))
            }

            // Check for gaze behavior
            if gazeCooldownTimer <= 0 && distance < 6.0 {
                gazeCooldownTimer = Self.gazeCooldown
                if Double.random(in: 0...1) < Self.gazeChance {
                    shouldGaze = true
                }
            }

        } else if isActive {
            hideReflection()
        }

        return shouldGaze
    }

    // MARK: - Show / Hide

    private func showReflection() {
        isActive = true
        reflectionNode.removeAllActions()
        reflectionNode.run(
            SKAction.fadeAlpha(to: Self.reflectionAlpha, duration: 0.3),
            withKey: "fadeIn"
        )
    }

    private func hideReflection() {
        isActive = false
        reflectionNode.run(
            SKAction.fadeAlpha(to: 0, duration: 0.3),
            withKey: "fadeOut"
        )
    }

    // MARK: - Ripple Effect

    /// Trigger a ripple at the puddle surface.
    private func triggerRipple(at position: CGPoint) {
        isRippling = true
        rippleNode.position = position
        rippleNode.setScale(1.0)
        rippleNode.alpha = 0.3

        let expand = SKAction.group([
            SKAction.scaleX(to: 2.0, duration: Self.rippleDuration),
            SKAction.scaleY(to: 1.5, duration: Self.rippleDuration),
            SKAction.fadeAlpha(to: 0, duration: Self.rippleDuration)
        ])
        expand.timingMode = .easeOut

        rippleNode.run(SKAction.sequence([
            expand,
            SKAction.run { [weak self] in
                self?.isRippling = false
            }
        ]), withKey: "ripple")
    }

    // MARK: - Node Count

    /// Nodes contributed to the scene (for budget tracking).
    var nodeCount: Int {
        return isActive ? 2 : 0
    }
}
