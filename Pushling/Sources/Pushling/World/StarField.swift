// StarField.swift — Twinkling star field for night sky
// P3-T2-03: 15-25 stars visible at night. Fade in at dusk, fade out at dawn.
// Twinkle = random alpha oscillation per star (0.5-2.0 Hz).
//
// Stars are 1x1pt SKSpriteNode children of a container node on the Far layer.
// Each star has an independent twinkle phase and frequency.
// New arrangement generated each night for freshness.

import SpriteKit

// MARK: - Star Data

/// Per-star twinkle parameters.
private struct StarParams {
    let baseAlpha: CGFloat        // Resting alpha (0.3-1.0)
    let twinkleFrequency: CGFloat // Hz (0.5-2.0)
    let twinkleAmplitude: CGFloat // Alpha variation (0.1-0.3)
    var phase: CGFloat            // Current phase in the oscillation
}

// MARK: - Star Field Node

/// Container node holding 15-25 twinkling stars.
/// Stars appear at night, fade with dawn/dusk transitions.
/// New random arrangement each night cycle.
final class StarFieldNode: SKNode {

    // MARK: - Constants

    /// Star count range.
    private static let minStars = 15
    private static let maxStars = 25

    /// Star visual size (1x1pt, occasionally 2x1pt for bright ones).
    private static let starSize = CGSize(width: 1, height: 1)
    private static let brightStarSize = CGSize(width: 2, height: 1)

    /// Scene boundaries for star placement.
    private static let sceneWidth: CGFloat = 1085
    private static let sceneHeight: CGFloat = 30

    /// Vertical range: stars appear in upper 2/3 of sky.
    private static let minY: CGFloat = 10
    private static let maxY: CGFloat = 28

    /// Horizontal margin to keep stars from edges.
    private static let marginX: CGFloat = 20

    /// Moon exclusion zone to prevent overlap (centered at ~950, 24).
    private static let moonCenter = CGPoint(x: 950, y: 24)
    private static let moonExclusionRadius: CGFloat = 8

    /// Probability of a star being "bright" (2x1pt).
    private static let brightProbability: Double = 0.15

    // MARK: - State

    /// The star sprite nodes.
    private var starNodes: [SKSpriteNode] = []

    /// Per-star twinkle parameters.
    private var starParams: [StarParams] = []

    /// The night cycle identifier (regenerate stars when this changes).
    private var currentNightCycleDay: Int = -1

    /// Current field alpha multiplier (from sky system).
    private var fieldAlpha: CGFloat = 0

    /// Pre-rendered 1x1 Gilt texture (shared by all stars).
    private let starTexture: SKTexture
    private let brightStarTexture: SKTexture

    // MARK: - Init

    override init() {
        // Create small gilt pixel textures
        starTexture = Self.createStarTexture(size: CGSize(width: 1, height: 1))
        brightStarTexture = Self.createStarTexture(size: CGSize(width: 2, height: 1))

        super.init()

        zPosition = -195  // In front of sky gradient, behind moon
        alpha = 0  // Start hidden

        generateStars()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Texture Creation

    /// Create a small texture of Gilt color.
    private static func createStarTexture(size: CGSize) -> SKTexture {
        let w = Int(size.width)
        let h = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) {
            pixels[i * 4] = 0xFF     // R
            pixels[i * 4 + 1] = 0xD7 // G
            pixels[i * 4 + 2] = 0x00 // B
            pixels[i * 4 + 3] = 0xFF // A
        }
        let texture = SKTexture(
            data: Data(pixels),
            size: size
        )
        texture.filteringMode = .nearest
        return texture
    }

    // MARK: - Star Generation

    /// Generate a new random arrangement of stars.
    /// Avoids the moon exclusion zone.
    private func generateStars() {
        // Remove existing stars
        for node in starNodes {
            node.removeFromParent()
        }
        starNodes.removeAll()
        starParams.removeAll()

        let count = Int.random(in: Self.minStars...Self.maxStars)

        for _ in 0..<count {
            // Generate position avoiding moon zone
            var position: CGPoint
            var attempts = 0
            repeat {
                position = CGPoint(
                    x: CGFloat.random(in: Self.marginX...(Self.sceneWidth - Self.marginX)),
                    y: CGFloat.random(in: Self.minY...Self.maxY)
                )
                attempts += 1
            } while isInMoonZone(position) && attempts < 20

            // Determine if bright star
            let isBright = Double.random(in: 0...1) < Self.brightProbability
            let texture = isBright ? brightStarTexture : starTexture
            let size = isBright ? Self.brightStarSize : Self.starSize

            let sprite = SKSpriteNode(texture: texture, size: size)
            sprite.position = position
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)

            // Randomize twinkle parameters
            let baseAlpha = CGFloat.random(in: 0.3...1.0)
            let params = StarParams(
                baseAlpha: baseAlpha,
                twinkleFrequency: CGFloat.random(in: 0.5...2.0),
                twinkleAmplitude: CGFloat.random(in: 0.1...0.3),
                phase: CGFloat.random(in: 0...(2.0 * .pi))
            )

            sprite.alpha = baseAlpha
            addChild(sprite)
            starNodes.append(sprite)
            starParams.append(params)
        }
    }

    /// Check if a position is within the moon exclusion zone.
    private func isInMoonZone(_ point: CGPoint) -> Bool {
        let dx = point.x - Self.moonCenter.x
        let dy = point.y - Self.moonCenter.y
        return sqrt(dx * dx + dy * dy) < Self.moonExclusionRadius
    }

    // MARK: - Visibility

    /// Update overall star field visibility based on time period.
    /// Called by SkySystem approximately once per second.
    func updateVisibility(alpha nightAlpha: CGFloat) {
        fieldAlpha = nightAlpha
        self.alpha = nightAlpha

        // Check if we need to regenerate stars for a new night cycle
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        if dayOfYear != currentNightCycleDay && nightAlpha > 0.1 {
            currentNightCycleDay = dayOfYear
            generateStars()
        }
    }

    // MARK: - Twinkle Update

    /// Update individual star twinkle. Called every frame (lightweight math only).
    /// Cost: ~0.01ms for 25 stars — well within budget.
    func updateTwinkle(deltaTime: TimeInterval) {
        guard fieldAlpha > 0.01 else { return }  // Skip if stars not visible

        let dt = CGFloat(deltaTime)

        for i in 0..<starNodes.count {
            // Advance phase
            starParams[i].phase += starParams[i].twinkleFrequency * 2.0 * .pi * dt

            // Wrap phase to prevent float overflow over long sessions
            if starParams[i].phase > 100.0 * .pi {
                starParams[i].phase -= 100.0 * .pi
            }

            // Calculate twinkle alpha
            let sinValue = sin(starParams[i].phase)
            let twinkleAlpha = starParams[i].baseAlpha +
                starParams[i].twinkleAmplitude * sinValue

            // Clamp to valid range
            starNodes[i].alpha = max(0.1, min(1.0, twinkleAlpha))
        }
    }

    // MARK: - Query

    /// Current star count (for debug/MCP).
    var starCount: Int { starNodes.count }
}
