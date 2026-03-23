// SpriteStackRenderer.swift — Pseudo-3D depth effect via vertically stacked silhouettes
// Creates shadow layers (Ash) below and highlight layers (Bone) above the creature's body,
// producing a volumetric illusion on the Touch Bar's tiny OLED strip.
//
// Breathing modulates stack spread: as the body's yScale oscillates (1.0-1.03),
// layers expand/contract to create a belly-expansion illusion.
//
// Stage-gated layer counts:
//   Spore/Drop  = 0 layers (too simple for depth effect)
//   Critter     = 3 layers (1 shadow, 2 highlight)
//   Beast       = 5 layers (2 shadow, 3 highlight)
//   Sage/Apex   = 7 layers (3 shadow, 4 highlight)

import SpriteKit

/// Renders pseudo-3D depth on the creature by stacking body silhouette duplicates
/// at slight vertical offsets above and below the main body node.
final class SpriteStackRenderer {

    // MARK: - Configuration

    /// Vertical spacing between each stack layer in points.
    private static let baseSpacing: CGFloat = 0.7

    /// How much breathing modulates the spread (multiplier on breath deviation).
    /// At max breath (scale 1.03), spread increases by this factor * 0.03.
    private static let breathSpreadFactor: CGFloat = 12.0

    /// Alpha for the outermost shadow layer (fades inward).
    private static let shadowAlphaOuter: CGFloat = 0.02

    /// Alpha for the innermost shadow layer (closest to body).
    private static let shadowAlphaInner: CGFloat = 0.05

    /// Alpha for the innermost highlight layer (closest to body).
    private static let highlightAlphaInner: CGFloat = 0.12

    /// Alpha for the outermost highlight layer (farthest above body).
    private static let highlightAlphaOuter: CGFloat = 0.04

    // MARK: - State

    /// The stack layers, ordered bottom (shadow) to top (highlight).
    private var stackLayers: [SKShapeNode] = []

    /// Number of shadow layers (below body).
    private var shadowCount = 0

    /// Number of highlight layers (above body).
    private var highlightCount = 0

    /// Weak reference to the body node these layers surround.
    private weak var bodyNode: SKShapeNode?

    /// Cached body dimensions for silhouette regeneration.
    private var bodyWidth: CGFloat = 0
    private var bodyHeight: CGFloat = 0

    /// The current growth stage.
    private var stage: GrowthStage = .egg

    /// The resting Y position offset for each layer (no breath modulation).
    private var restOffsets: [CGFloat] = []

    // MARK: - Public Properties

    /// Current number of stack layers (shadow + highlight).
    var layerCount: Int { stackLayers.count }

    // MARK: - Init

    init() {}

    // MARK: - Configure

    /// Create stack layers as siblings of the body node in its parent.
    /// Call this after building the creature's node hierarchy.
    /// - Parameters:
    ///   - bodyNode: The creature's main body SKShapeNode.
    ///   - stage: Current growth stage (gates layer count).
    ///   - bodyWidth: Body width in points (for silhouette path).
    ///   - bodyHeight: Body height in points (for silhouette path).
    func configure(bodyNode: SKShapeNode, stage: GrowthStage,
                   bodyWidth: CGFloat, bodyHeight: CGFloat) {
        // Clean up any existing layers first
        remove()

        self.bodyNode = bodyNode
        self.stage = stage
        self.bodyWidth = bodyWidth
        self.bodyHeight = bodyHeight

        let total = Self.totalLayers(for: stage)
        guard total > 0, let parent = bodyNode.parent else { return }

        // Split: more highlights than shadows (light comes from above)
        shadowCount = total / 2
        highlightCount = total - shadowCount

        let silhouettePath = CatShapes.bodySilhouette(
            width: bodyWidth, height: bodyHeight, stage: stage
        )

        let bodyZ = bodyNode.zPosition
        restOffsets = []
        stackLayers = []

        // -- Shadow layers (below body) --
        for i in 0..<shadowCount {
            let node = SKShapeNode(path: silhouettePath)
            node.strokeColor = .clear
            node.name = "sprite_stack_shadow_\(i)"

            // Outermost shadow is farthest below, most transparent
            let t = shadowCount > 1
                ? CGFloat(i) / CGFloat(shadowCount - 1)
                : 0.5
            let alpha = Self.shadowAlphaOuter
                + (Self.shadowAlphaInner - Self.shadowAlphaOuter) * t
            node.fillColor = PushlingPalette.withAlpha(PushlingPalette.ash, alpha: alpha)

            // Stack below body: outermost first (i=0 is farthest down)
            let offset = -Self.baseSpacing * CGFloat(shadowCount - i)
            restOffsets.append(offset)

            node.position = CGPoint(x: bodyNode.position.x,
                                    y: bodyNode.position.y + offset)
            node.zPosition = bodyZ - CGFloat(shadowCount - i)

            parent.addChild(node)
            stackLayers.append(node)
        }

        // -- Highlight layers (above body) --
        for i in 0..<highlightCount {
            let node = SKShapeNode(path: silhouettePath)
            node.strokeColor = .clear
            node.name = "sprite_stack_highlight_\(i)"

            // Innermost highlight is closest to body, most opaque
            let t = highlightCount > 1
                ? CGFloat(i) / CGFloat(highlightCount - 1)
                : 0.5
            let alpha = Self.highlightAlphaInner
                + (Self.highlightAlphaOuter - Self.highlightAlphaInner) * t
            node.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: alpha)

            // Stack above body: innermost first (i=0 is closest above)
            let offset = Self.baseSpacing * CGFloat(i + 1)
            restOffsets.append(offset)

            node.position = CGPoint(x: bodyNode.position.x,
                                    y: bodyNode.position.y + offset)
            node.zPosition = bodyZ + CGFloat(i + 1)

            parent.addChild(node)
            stackLayers.append(node)
        }
    }

    // MARK: - Per-Frame Update

    /// Called every frame with the current breath yScale.
    /// Modulates stack spread to create belly expansion illusion.
    /// - Parameter breathScale: Current body yScale (1.0 to 1.03).
    func update(breathScale: CGFloat) {
        guard !stackLayers.isEmpty, let body = bodyNode else { return }

        // Breath deviation from rest (0.0 at rest, up to ~0.03 at peak)
        let deviation = breathScale - 1.0

        // Spread multiplier: layers fan out as the body "inflates"
        let spreadMultiplier = 1.0 + deviation * Self.breathSpreadFactor

        for (index, layer) in stackLayers.enumerated() {
            let restOffset = restOffsets[index]

            // Apply spread modulation to the offset
            let modulatedOffset = restOffset * spreadMultiplier

            // Track body position (layers are siblings, share coordinate space)
            layer.position = CGPoint(x: body.position.x,
                                     y: body.position.y + modulatedOffset)

            // Match body's xScale for facing direction
            layer.xScale = body.xScale
        }
    }

    // MARK: - Cleanup

    /// Remove all stack layers from the scene.
    func remove() {
        for layer in stackLayers {
            layer.removeFromParent()
        }
        stackLayers.removeAll()
        restOffsets.removeAll()
        shadowCount = 0
        highlightCount = 0
        bodyNode = nil
    }

    // MARK: - Stage Gating

    /// Returns the total number of stack layers for a given growth stage.
    /// - Parameter stage: The creature's current growth stage.
    /// - Returns: Total layer count (0, 3, 5, or 7).
    static func totalLayers(for stage: GrowthStage) -> Int {
        switch stage {
        case .egg, .drop:
            return 0
        case .critter:
            return 3
        case .beast:
            return 5
        case .sage, .apex:
            return 7
        }
    }
}
