// HungerDesaturation.swift — World desaturation when satisfaction is low
// P3-T3-08: The world communicates hunger, not UI bars.
//
// When satisfaction < 25: world gradually desaturates.
// Flowers close. Trees go bare. Ground shifts toward Ash.
// Recovery when satisfaction > 30: re-saturate over 30 seconds.
//
// Implementation: full-scene Ash-tinted overlay at dynamic alpha.
// No CIFilter (too expensive). Simple overlay node approach.
// Performance: <0.01ms per frame (just an alpha calculation).
//
// Node budget: 1 node (the desaturation overlay). Always in tree, usually alpha 0.

import SpriteKit

// MARK: - Hunger Desaturation Controller

/// Monitors creature satisfaction and applies world desaturation when hungry.
/// Uses a full-scene overlay tinted toward Ash to simulate desaturation.
/// Terrain objects (flowers, trees) switch to wilted variants via callbacks.
final class HungerDesaturationController {

    // MARK: - Constants

    /// Satisfaction threshold below which desaturation begins.
    private static let hungerThreshold: Double = 25.0

    /// Satisfaction threshold above which recovery begins.
    private static let recoveryThreshold: Double = 30.0

    /// Maximum overlay alpha at satisfaction = 0.
    private static let maxDesaturationAlpha: CGFloat = 0.45

    /// Duration of recovery re-saturation (seconds).
    private static let recoveryDuration: TimeInterval = 30.0

    // MARK: - Nodes

    /// Full-scene desaturation overlay.
    private let overlayNode: SKShapeNode

    // MARK: - State

    /// Current desaturation intensity (0.0 = full color, 1.0 = full desat).
    private(set) var desaturationIntensity: CGFloat = 0

    /// Target desaturation intensity (driven by satisfaction).
    private var targetIntensity: CGFloat = 0

    /// Whether we're currently recovering (re-saturating).
    private var isRecovering = false

    /// Recovery progress (0.0 = just started, 1.0 = complete).
    private var recoveryProgress: CGFloat = 0

    /// Callback when desaturation state changes (for object state switching).
    /// Parameter: intensity 0.0 (healthy) to 1.0 (fully desaturated).
    var onDesaturationChanged: ((CGFloat) -> Void)?

    // MARK: - Init

    init(sceneWidth: CGFloat = 1085, sceneHeight: CGFloat = 30) {
        overlayNode = SKShapeNode(
            rectOf: CGSize(width: sceneWidth + 20, height: sceneHeight + 10)
        )
        overlayNode.fillColor = PushlingPalette.ash
        overlayNode.strokeColor = .clear
        overlayNode.alpha = 0
        overlayNode.name = "hunger_desaturation_overlay"
        overlayNode.position = CGPoint(x: sceneWidth / 2, y: sceneHeight / 2)
        overlayNode.zPosition = 200  // Above world, below creature and HUD
        overlayNode.blendMode = .alpha
    }

    // MARK: - Scene Integration

    /// Add the overlay to the scene root.
    func addToScene(_ scene: SKScene) {
        scene.addChild(overlayNode)
    }

    /// Remove from scene.
    func removeFromScene() {
        overlayNode.removeFromParent()
    }

    // MARK: - Satisfaction Update

    /// Update the desaturation based on creature satisfaction.
    /// Call whenever satisfaction changes (from state system).
    /// - Parameter satisfaction: Current satisfaction (0-100).
    func updateSatisfaction(_ satisfaction: Double) {
        if satisfaction < Self.hungerThreshold {
            // Calculate desaturation intensity
            // At sat=25: intensity=0, at sat=0: intensity=1.0
            targetIntensity = CGFloat(
                max(0, (Self.hungerThreshold - satisfaction) / Self.hungerThreshold)
            )
            isRecovering = false
            recoveryProgress = 0
        } else if satisfaction >= Self.recoveryThreshold && desaturationIntensity > 0 {
            // Begin recovery
            if !isRecovering {
                isRecovering = true
                recoveryProgress = 0
            }
            targetIntensity = 0
        } else {
            targetIntensity = 0
        }
    }

    // MARK: - Frame Update

    /// Per-frame update. Smoothly transitions desaturation.
    /// - Parameter deltaTime: Time since last frame.
    func update(deltaTime: TimeInterval) {
        let previousIntensity = desaturationIntensity

        if isRecovering {
            // Gradual recovery over recoveryDuration
            recoveryProgress += CGFloat(deltaTime / Self.recoveryDuration)
            if recoveryProgress >= 1.0 {
                recoveryProgress = 1.0
                isRecovering = false
            }
            desaturationIntensity = desaturationIntensity
                * (1.0 - recoveryProgress)
        } else {
            // Immediate tracking toward target (with slight smoothing)
            let rate: CGFloat = 2.0  // speed of desaturation onset
            if desaturationIntensity < targetIntensity {
                desaturationIntensity = min(
                    targetIntensity,
                    desaturationIntensity + CGFloat(deltaTime) * rate
                )
            } else if desaturationIntensity > targetIntensity {
                desaturationIntensity = max(
                    targetIntensity,
                    desaturationIntensity - CGFloat(deltaTime) * rate
                )
            }
        }

        // Apply overlay alpha
        let overlayAlpha = desaturationIntensity * Self.maxDesaturationAlpha
        overlayNode.alpha = overlayAlpha

        // Notify callback if intensity changed meaningfully
        if abs(desaturationIntensity - previousIntensity) > 0.01 {
            onDesaturationChanged?(desaturationIntensity)
        }
    }

    // MARK: - Object State Queries

    /// Whether flowers should display their "closed" / wilted state.
    var flowersWilted: Bool {
        desaturationIntensity > 0.3
    }

    /// Whether trees should display their "bare" / leafless state.
    var treesBare: Bool {
        desaturationIntensity > 0.5
    }

    /// Ground color blend factor — how much to shift ground toward Ash.
    /// 0.0 = normal biome color, 1.0 = fully Ash.
    var groundDesaturation: CGFloat {
        desaturationIntensity * 0.6
    }

    // MARK: - Node Count

    var nodeCount: Int { 1 }
}
