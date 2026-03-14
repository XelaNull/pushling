// FogRenderer.swift — Layered fog system for atmosphere
// P3-T2-08: 2-3 horizontal alpha strips at different depths.
// Near fog: alpha 0.3, slow drift left (5pts/sec).
// Mid fog: alpha 0.2, drift right (3pts/sec).
// Far fog: alpha 0.15, near-static.
//
// Fog color: Ash. Fades in/out over 60 seconds.
// Fog obscures distant landmarks and far-layer stars.

import SpriteKit

// MARK: - Fog Layer Config

/// Configuration for a single fog strip.
fileprivate struct FogLayerConfig {
    let baseAlpha: CGFloat     // Resting alpha at full density
    let driftSpeed: CGFloat    // Horizontal drift in pts/sec (negative = left)
    let yPosition: CGFloat     // Vertical center of the strip
    let height: CGFloat        // Strip height in points
    let zPosition: CGFloat     // Depth ordering

    static let near = FogLayerConfig(
        baseAlpha: 0.3,
        driftSpeed: -5.0,  // Drift left
        yPosition: 10,
        height: 18,
        zPosition: 40      // Foreground fog — above terrain objects
    )

    static let mid = FogLayerConfig(
        baseAlpha: 0.2,
        driftSpeed: 3.0,   // Drift right
        yPosition: 14,
        height: 22,
        zPosition: -40      // Mid-layer fog
    )

    static let far = FogLayerConfig(
        baseAlpha: 0.15,
        driftSpeed: -0.5,  // Near-static
        yPosition: 18,
        height: 26,
        zPosition: -90      // Far fog — behind mid layer, above sky
    )
}

// MARK: - Fog Strip Node

/// A single fog strip: a wide repeating sprite that drifts horizontally.
/// Uses two side-by-side sprites for seamless wrapping.
final class FogStripNode: SKNode {

    /// Scene width (full Touch Bar).
    private static let sceneWidth: CGFloat = 1085

    /// Extra width beyond scene for seamless wrapping.
    private static let overlapWidth: CGFloat = 200

    /// Total strip width (scene + overlap on each side).
    private var stripWidth: CGFloat { Self.sceneWidth + Self.overlapWidth * 2 }

    /// The two sprite halves (for seamless wrapping).
    private let spriteA: SKSpriteNode
    private let spriteB: SKSpriteNode

    /// Configuration for this strip.
    private let config: FogLayerConfig

    /// Current horizontal offset for drift.
    private var driftOffset: CGFloat = 0

    fileprivate init(config: FogLayerConfig) {
        self.config = config

        let stripSize = CGSize(width: Self.sceneWidth + Self.overlapWidth, height: config.height)

        // Create two identical fog sprites for wrapping
        spriteA = SKSpriteNode(color: PushlingPalette.ash, size: stripSize)
        spriteA.anchorPoint = CGPoint(x: 0, y: 0.5)
        spriteA.alpha = config.baseAlpha

        spriteB = SKSpriteNode(color: PushlingPalette.ash, size: stripSize)
        spriteB.anchorPoint = CGPoint(x: 0, y: 0.5)
        spriteB.alpha = config.baseAlpha

        super.init()

        addChild(spriteA)
        addChild(spriteB)

        self.position = CGPoint(x: 0, y: config.yPosition)
        self.zPosition = config.zPosition

        // Start with random offset for variety
        driftOffset = CGFloat.random(in: 0...stripSize.width)
        updatePositions()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// Update drift position. Called every frame.
    func updateDrift(dt: CGFloat) {
        driftOffset += config.driftSpeed * dt

        let width = spriteA.size.width
        // Wrap offset
        if driftOffset > width {
            driftOffset -= width
        } else if driftOffset < -width {
            driftOffset += width
        }

        updatePositions()
    }

    /// Position the two sprites so they seamlessly tile.
    private func updatePositions() {
        let width = spriteA.size.width
        let startX = -FogStripNode.overlapWidth + driftOffset

        spriteA.position = CGPoint(x: startX, y: 0)
        spriteB.position = CGPoint(x: startX - width, y: 0)

        // If spriteA is too far right, spriteB covers the left gap (and vice versa)
        if spriteA.position.x > FogStripNode.sceneWidth {
            spriteA.position.x -= width * 2
        }
        if spriteB.position.x + width < -FogStripNode.overlapWidth {
            spriteB.position.x += width * 2
        }
    }

    /// Set density multiplier (affects alpha).
    func setDensity(_ density: CGFloat) {
        let alpha = config.baseAlpha * density
        spriteA.alpha = alpha
        spriteB.alpha = alpha
    }
}

// MARK: - Fog Renderer

/// Manages 3 fog layers that drift at different speeds.
/// Fog fades in/out over 60 seconds. Density is variable.
final class FogRenderer {

    // MARK: - Constants

    /// Fog fade-in/out duration (seconds).
    private static let fadeDuration: TimeInterval = 60

    // MARK: - Fog Layers

    private let nearFog: FogStripNode
    private let midFog: FogStripNode
    private let farFog: FogStripNode

    /// Container for all fog layers.
    private let containerNode = SKNode()

    // MARK: - State

    /// Intensity (0.0 = invisible, 1.0 = full fog). Set by WeatherSystem.
    var intensity: CGFloat = 0 {
        didSet {
            targetDensity = intensity
        }
    }

    /// Current density (approaches targetDensity over fadeDuration).
    private var currentDensity: CGFloat = 0

    /// Target density (set by intensity).
    private var targetDensity: CGFloat = 0

    /// Whether fog is actively rendering.
    private var isActive = false

    /// Delegate for creature fog reactions.
    weak var reactionDelegate: WeatherReactionDelegate?

    // MARK: - Init

    init() {
        nearFog = FogStripNode(config: .near)
        midFog = FogStripNode(config: .mid)
        farFog = FogStripNode(config: .far)

        containerNode.addChild(nearFog)
        containerNode.addChild(midFog)
        containerNode.addChild(farFog)

        containerNode.alpha = 0
    }

    // MARK: - Scene Integration

    func addToScene(parent: SKNode) {
        parent.addChild(containerNode)
    }

    // MARK: - Activation

    func activate() {
        isActive = true
    }

    func deactivate() {
        isActive = false
        targetDensity = 0
    }

    // MARK: - Frame Update

    /// Update fog drift and density. Called every frame during fog weather.
    func update(deltaTime: TimeInterval) {
        let dt = CGFloat(deltaTime)

        // Approach target density
        let densitySpeed: CGFloat = 1.0 / CGFloat(Self.fadeDuration)
        if currentDensity < targetDensity {
            currentDensity = min(targetDensity, currentDensity + densitySpeed * dt)
        } else if currentDensity > targetDensity {
            currentDensity = max(targetDensity, currentDensity - densitySpeed * dt)
        }

        // Update container visibility
        containerNode.alpha = currentDensity > 0.01 ? 1.0 : 0.0

        // Update fog strip densities
        nearFog.setDensity(currentDensity)
        midFog.setDensity(currentDensity)
        farFog.setDensity(currentDensity)

        // Update drift
        nearFog.updateDrift(dt: dt)
        midFog.updateDrift(dt: dt)
        farFog.updateDrift(dt: dt)

        // Notify creature of fog density changes
        if abs(currentDensity - targetDensity) < 0.01 && currentDensity > 0 {
            reactionDelegate?.fogChanged(density: currentDensity)
        }

        // Deactivate if fully faded out
        if !isActive && currentDensity <= 0.01 {
            containerNode.alpha = 0
            currentDensity = 0
        }
    }

    // MARK: - Query

    /// Current fog density (for MCP/debug).
    var fogDensity: CGFloat { currentDensity }
}
