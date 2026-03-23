// FogOfWarController.swift — Stage-gated visibility fog for the Touch Bar
// Classic fog of war: OLED black where unexplored, full brightness where
// the creature is, dimmed where previously explored.
//
// Architecture: Panel-based approach for reliable OLED black rendering.
//   - Left/right solid panels (blendMode .replace, z=900): true OLED black
//   - Left/right gradient strips (z=900): soft foggy edge transition
//   - Explored dim overlay (z=898): dims explored-but-not-current areas
//
// Per-frame cost: position updates + range check = <0.1ms.
// Node budget: 5 nodes (2 panels + 2 gradients + 1 dim overlay).

import SpriteKit

// MARK: - Fog of War Controller

/// Controls visibility fog around the creature based on growth stage.
/// Early stages see only a small radius; later stages reveal more world.
/// Explored territory remains dimly visible as a "memory" overlay.
final class FogOfWarController {

    // MARK: - Constants

    /// Scene dimensions (Touch Bar).
    private static let sceneWidth: CGFloat = 1085.0
    private static let sceneHeight: CGFloat = 30.0

    /// Panel height — oversized to prevent edge gaps.
    private static let panelHeight: CGFloat = 50.0

    /// Z-positions — above everything except debug overlay (1000).
    private static let panelZ: CGFloat = 900
    private static let gradientZ: CGFloat = 900
    private static let dimZ: CGFloat = 898

    /// Minimum movement in world-X before updating explored ranges (pts).
    private static let explorationThreshold: CGFloat = 2.0

    // MARK: - Nodes

    /// Left fog panel — solid black, covers everything left of explored area.
    private let leftPanel: SKSpriteNode

    /// Right fog panel — solid black, covers everything right of explored area.
    private let rightPanel: SKSpriteNode

    /// Left gradient strip — soft fade from black to clear at fog edge.
    private let leftGradient: SKSpriteNode

    /// Right gradient strip — soft fade from clear to black at fog edge.
    private let rightGradient: SKSpriteNode

    /// Left dim panel — darkens explored area left of creature's visibility.
    private let leftDim: SKSpriteNode

    /// Right dim panel — darkens explored area right of creature's visibility.
    private let rightDim: SKSpriteNode

    // MARK: - Legacy (API compatibility)

    /// Legacy node references for external code that references activeFogNode.
    let activeFogNode: SKSpriteNode
    let exploredFogNode: SKSpriteNode

    // MARK: - State

    /// Current fog configuration (from VisualComplexity).
    private var config: FogOfWarConfig

    /// Explored territory tracker.
    let exploredRanges = ExploredRangeTracker()

    /// Last creature world-X used for exploration check.
    private var lastExploredWorldX: CGFloat = 0

    /// Current zoom level (for radius compensation).
    private var currentZoom: CGFloat = 1.0

    /// Whether the fog is fully disabled (Apex with radius >= scene width).
    private var isFogDisabled: Bool = false

    /// Whether we're currently animating a fog retreat (evolution).
    private var isAnimatingRetreat: Bool = false

    // MARK: - Init

    init(config: FogOfWarConfig = FogOfWarConfig(
        visibilityRadius: 40, edgeGradientWidth: 20,
        exploredAlpha: 0.0, exploredEnabled: false
    )) {
        self.config = config

        let black = SKColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Solid black panels — .replace blend for true OLED black
        leftPanel = SKSpriteNode(color: black,
            size: CGSize(width: Self.sceneWidth, height: Self.panelHeight))
        leftPanel.name = "fog_left"
        leftPanel.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        leftPanel.zPosition = Self.panelZ
        leftPanel.blendMode = .replace
        leftPanel.alpha = 1.0
        leftPanel.colorBlendFactor = 1.0

        rightPanel = SKSpriteNode(color: black,
            size: CGSize(width: Self.sceneWidth, height: Self.panelHeight))
        rightPanel.name = "fog_right"
        rightPanel.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        rightPanel.zPosition = Self.panelZ
        rightPanel.blendMode = .replace
        rightPanel.alpha = 1.0
        rightPanel.colorBlendFactor = 1.0

        // Gradient strips — soft foggy edge
        let gradWidth = config.edgeGradientWidth
        leftGradient = SKSpriteNode(
            color: .clear,
            size: CGSize(width: max(gradWidth, 1), height: Self.panelHeight))
        leftGradient.name = "fog_grad_left"
        leftGradient.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        leftGradient.zPosition = Self.gradientZ
        leftGradient.blendMode = .alpha

        rightGradient = SKSpriteNode(
            color: .clear,
            size: CGSize(width: max(gradWidth, 1), height: Self.panelHeight))
        rightGradient.name = "fog_grad_right"
        rightGradient.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        rightGradient.zPosition = Self.gradientZ
        rightGradient.blendMode = .alpha

        // Generate gradient textures
        // Left: black on left, transparent on right (fades into explored area)
        let leftGradTex = Self.createGradientTexture(
            width: max(Int(gradWidth * 2), 2), height: Int(Self.panelHeight * 2),
            blackOnLeft: true)
        leftGradient.texture = leftGradTex
        leftGradient.size = CGSize(width: max(gradWidth, 1),
                                    height: Self.panelHeight)

        // Right: transparent on left, black on right (fades into panel)
        let rightGradTex = Self.createGradientTexture(
            width: max(Int(gradWidth * 2), 2), height: Int(Self.panelHeight * 2),
            blackOnLeft: false)
        rightGradient.texture = rightGradTex
        rightGradient.size = CGSize(width: max(gradWidth, 1),
                                     height: Self.panelHeight)

        // Dim panels — darken explored area outside creature's visibility
        // Each dim panel has a gradient texture: transparent near the creature,
        // fading to a dim alpha further away (soft edge into dimmed territory).
        // Left dim: right edge at creature's left visibility edge
        leftDim = SKSpriteNode(color: .clear,
            size: CGSize(width: Self.sceneWidth, height: Self.panelHeight))
        leftDim.name = "fog_dim_left"
        leftDim.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        leftDim.zPosition = Self.dimZ
        leftDim.blendMode = .alpha
        leftDim.isHidden = true

        // Right dim: left edge at creature's right visibility edge
        rightDim = SKSpriteNode(color: .clear,
            size: CGSize(width: Self.sceneWidth, height: Self.panelHeight))
        rightDim.name = "fog_dim_right"
        rightDim.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        rightDim.zPosition = Self.dimZ
        rightDim.blendMode = .alpha
        rightDim.isHidden = true

        // Legacy nodes (hidden, for API compatibility)
        activeFogNode = SKSpriteNode(color: .clear, size: CGSize(width: 1, height: 1))
        activeFogNode.isHidden = true
        exploredFogNode = SKSpriteNode(color: .clear, size: CGSize(width: 1, height: 1))
        exploredFogNode.isHidden = true

        checkFogDisabled()
    }

    // MARK: - Gradient Texture

    /// Creates a horizontal gradient texture for fog edges.
    /// - Parameters:
    ///   - blackOnLeft: If true, black on left fading to transparent on right.
    ///                  If false, transparent on left fading to black on right.
    private static func createGradientTexture(width: Int, height: Int,
                                               blackOnLeft: Bool = true) -> SKTexture {
        let bytesPerRow = width * 4
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let pixelData = ctx.data else {
            return SKTexture()
        }

        let pixels = pixelData.bindMemory(to: UInt8.self,
                                           capacity: height * bytesPerRow)

        for y in 0..<height {
            for x in 0..<width {
                // t=0 at left, t=1 at right
                let t = CGFloat(x) / CGFloat(max(width - 1, 1))
                let tSq = t * t
                let smooth = tSq * (3.0 - 2.0 * t)
                // blackOnLeft: alpha=1 at left, alpha=0 at right
                // !blackOnLeft: alpha=0 at left, alpha=1 at right
                let fog = blackOnLeft ? (1.0 - smooth) : smooth
                let alpha = UInt8(max(0, min(255, fog * 255)))

                let offset = y * bytesPerRow + x * 4
                pixels[offset] = 0          // R
                pixels[offset + 1] = 0      // G
                pixels[offset + 2] = 0      // B
                pixels[offset + 3] = alpha  // A
            }
        }

        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        let tex = SKTexture(cgImage: cgImage)
        tex.filteringMode = .linear
        return tex
    }

    /// Creates a dim gradient texture with soft edge near creature, solid dim away.
    /// The gradient occupies the first `fadeWidth` pixels, then solid dim fills the rest.
    /// - Parameters:
    ///   - width: Total texture width in pixels.
    ///   - height: Texture height in pixels.
    ///   - dimAlpha: Maximum dim alpha (0.0-1.0).
    ///   - fadeWidth: Width of the soft fade zone in pixels.
    ///   - fadeOnLeft: If true, fade is on the left (for right dim panel).
    ///                 If false, fade is on the right (for left dim panel).
    private static func createDimTexture(width: Int, height: Int,
                                          dimAlpha: CGFloat,
                                          fadeWidth: Int,
                                          fadeOnLeft: Bool) -> SKTexture {
        let bytesPerRow = width * 4
        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let pixelData = ctx.data else {
            return SKTexture()
        }

        let pixels = pixelData.bindMemory(to: UInt8.self,
                                           capacity: height * bytesPerRow)
        let maxAlpha = UInt8(max(0, min(255, dimAlpha * 255)))

        for y in 0..<height {
            for x in 0..<width {
                let alpha: UInt8
                if fadeOnLeft {
                    // Fade on left: x=0 transparent, x=fadeWidth full dim
                    if x < fadeWidth {
                        let t = CGFloat(x) / CGFloat(max(fadeWidth - 1, 1))
                        let tSq = t * t
                        let smooth = tSq * (3.0 - 2.0 * t)
                        alpha = UInt8(smooth * CGFloat(maxAlpha))
                    } else {
                        alpha = maxAlpha
                    }
                } else {
                    // Fade on right: x=width transparent, x=width-fadeWidth full dim
                    let fromRight = width - 1 - x
                    if fromRight < fadeWidth {
                        let t = CGFloat(fromRight) / CGFloat(max(fadeWidth - 1, 1))
                        let tSq = t * t
                        let smooth = tSq * (3.0 - 2.0 * t)
                        alpha = UInt8(smooth * CGFloat(maxAlpha))
                    } else {
                        alpha = maxAlpha
                    }
                }

                let offset = y * bytesPerRow + x * 4
                pixels[offset] = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
                pixels[offset + 3] = alpha
            }
        }

        guard let cgImage = ctx.makeImage() else { return SKTexture() }
        let tex = SKTexture(cgImage: cgImage)
        tex.filteringMode = .linear
        return tex
    }

    // MARK: - Scene Integration

    /// Add fog nodes to the scene root.
    func addToScene(_ scene: SKScene) {
        let centerY = Self.sceneHeight / 2

        leftPanel.position = CGPoint(x: 0, y: centerY)
        rightPanel.position = CGPoint(x: Self.sceneWidth, y: centerY)
        leftGradient.position = CGPoint(x: 0, y: centerY)
        rightGradient.position = CGPoint(x: Self.sceneWidth, y: centerY)
        leftDim.position = CGPoint(x: 0, y: centerY)
        rightDim.position = CGPoint(x: Self.sceneWidth, y: centerY)

        scene.addChild(leftPanel)
        scene.addChild(rightPanel)
        scene.addChild(leftGradient)
        scene.addChild(rightGradient)
        scene.addChild(leftDim)
        scene.addChild(rightDim)
    }

    /// Remove fog nodes from scene.
    func removeFromScene() {
        leftPanel.removeFromParent()
        rightPanel.removeFromParent()
        leftGradient.removeFromParent()
        rightGradient.removeFromParent()
        leftDim.removeFromParent()
        rightDim.removeFromParent()
    }

    // MARK: - Per-Frame Update

    /// Update fog position and explored territory.
    func update(creatureScreenX: CGFloat, creatureWorldX: CGFloat,
                deltaTime: TimeInterval) {
        guard !isFogDisabled else { return }

        let centerY = Self.sceneHeight / 2
        let visRadius = config.visibilityRadius * currentZoom
        let gradWidth = config.edgeGradientWidth * currentZoom

        // 1. Update explored ranges
        let dx = abs(creatureWorldX - lastExploredWorldX)
        if dx >= Self.explorationThreshold {
            lastExploredWorldX = creatureWorldX
            exploredRanges.expand(
                center: creatureWorldX,
                radius: config.visibilityRadius
            )
        }

        // 2. Compute explored bounds in screen space
        let exploredScreenLeft: CGFloat
        let exploredScreenRight: CGFloat

        if let firstRange = exploredRanges.ranges.first,
           let lastRange = exploredRanges.ranges.last {
            // Map explored world bounds to screen space
            let cameraX = creatureWorldX  // Camera tracks creature at spore
            exploredScreenLeft = Self.sceneWidth / 2
                + (firstRange.minX - cameraX) * currentZoom
            exploredScreenRight = Self.sceneWidth / 2
                + (lastRange.maxX - cameraX) * currentZoom
        } else {
            // No explored ranges — panels cover everything except creature
            exploredScreenLeft = creatureScreenX - visRadius
            exploredScreenRight = creatureScreenX + visRadius
        }

        // 3. Position solid panels at explored boundaries
        //    Left panel: right edge at exploredScreenLeft (covers everything left)
        //    Right panel: left edge at exploredScreenRight (covers everything right)
        leftPanel.position = CGPoint(x: exploredScreenLeft, y: centerY)
        rightPanel.position = CGPoint(x: exploredScreenRight, y: centerY)

        // 4. Gradient strips extend INWARD from the panel edges into explored area
        //    Left gradient: left edge at panel edge, fades rightward into explored
        leftGradient.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        leftGradient.position = CGPoint(x: exploredScreenLeft, y: centerY)
        leftGradient.size.width = max(gradWidth, 1)
        //    Right gradient: right edge at panel edge, extends left into explored
        //    Texture has transparent left, black right — anchorPoint (1,0.5) means
        //    right edge (black side) sits at exploredScreenRight
        rightGradient.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        rightGradient.xScale = 1.0
        rightGradient.position = CGPoint(x: exploredScreenRight, y: centerY)
        rightGradient.size.width = max(gradWidth, 1)

        // 5. Dim panels cover explored area OUTSIDE creature's visibility
        //    Creature's immediate area (creatureScreenX ± visRadius) stays full brightness
        //    Each dim panel has a soft gradient edge near the creature
        let creatureLeft = creatureScreenX - visRadius
        let creatureRight = creatureScreenX + visRadius
        let dimFadeWidth = config.edgeGradientWidth  // Reuse fog edge width for consistency

        if config.exploredEnabled {
            let dimAlpha: CGFloat = 0.35

            // Left dim: from explored left edge to creature's left visibility edge
            // Fade is on the RIGHT side (near creature)
            let leftDimWidth = creatureLeft - exploredScreenLeft
            if leftDimWidth > 1 {
                leftDim.isHidden = false
                leftDim.position = CGPoint(x: creatureLeft, y: centerY)
                leftDim.size.width = leftDimWidth
                let texW = max(Int(leftDimWidth * 2), 4)
                let fadeW = min(Int(dimFadeWidth * 2), texW)
                leftDim.texture = Self.createDimTexture(
                    width: texW, height: 4,
                    dimAlpha: dimAlpha, fadeWidth: fadeW,
                    fadeOnLeft: false)  // fade on right (creature side)
            } else {
                leftDim.isHidden = true
            }

            // Right dim: from creature's right visibility edge to explored right edge
            // Fade is on the LEFT side (near creature)
            let rightDimWidth = exploredScreenRight - creatureRight
            if rightDimWidth > 1 {
                rightDim.isHidden = false
                rightDim.position = CGPoint(x: creatureRight, y: centerY)
                rightDim.size.width = rightDimWidth
                let texW = max(Int(rightDimWidth * 2), 4)
                let fadeW = min(Int(dimFadeWidth * 2), texW)
                rightDim.texture = Self.createDimTexture(
                    width: texW, height: 4,
                    dimAlpha: dimAlpha, fadeWidth: fadeW,
                    fadeOnLeft: true)  // fade on left (creature side)
            } else {
                rightDim.isHidden = true
            }
        } else {
            leftDim.isHidden = true
            rightDim.isHidden = true
        }
    }

    // MARK: - Configuration

    func updateConfig(_ config: FogOfWarConfig, animated: Bool = false) {
        let oldConfig = self.config
        self.config = config
        checkFogDisabled()

        // Regenerate gradient textures if edge width changed
        if oldConfig.edgeGradientWidth != config.edgeGradientWidth {
            let gradWidth = config.edgeGradientWidth
            leftGradient.texture = Self.createGradientTexture(
                width: max(Int(gradWidth * 2), 2),
                height: Int(Self.panelHeight * 2), blackOnLeft: true)
            rightGradient.texture = Self.createGradientTexture(
                width: max(Int(gradWidth * 2), 2),
                height: Int(Self.panelHeight * 2), blackOnLeft: false)
        }

        NSLog("[Pushling/FogOfWar] Config updated — radius %.0f, "
              + "edge %.0f, explored %.2f, disabled %@",
              config.visibilityRadius, config.edgeGradientWidth,
              config.exploredAlpha,
              isFogDisabled ? "yes" : "no")

        _ = oldConfig
    }

    /// Set the current zoom level for fog radius compensation.
    func setZoomLevel(_ zoom: CGFloat) {
        currentZoom = zoom
    }

    // MARK: - Evolution Reveal Animation

    func onEvolutionReveal(from oldConfig: FogOfWarConfig,
                           to newConfig: FogOfWarConfig,
                           duration: TimeInterval,
                           completion: (() -> Void)? = nil) {
        guard !isFogDisabled else {
            self.config = newConfig
            checkFogDisabled()
            completion?()
            return
        }

        isAnimatingRetreat = true

        let animAction = SKAction.customAction(withDuration: duration) {
            [weak self] _, elapsed in
            guard let self = self else { return }
            let t = CGFloat(Easing.easeOut(Double(elapsed / CGFloat(duration))))
            let currentRadius = oldConfig.visibilityRadius
                + (newConfig.visibilityRadius - oldConfig.visibilityRadius) * t
            self.config = FogOfWarConfig(
                visibilityRadius: currentRadius,
                edgeGradientWidth: oldConfig.edgeGradientWidth
                    + (newConfig.edgeGradientWidth - oldConfig.edgeGradientWidth) * t,
                exploredAlpha: oldConfig.exploredAlpha
                    + (newConfig.exploredAlpha - oldConfig.exploredAlpha) * Double(t),
                exploredEnabled: newConfig.exploredEnabled
            )
        }

        let finalize = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.isAnimatingRetreat = false
            self.config = newConfig
            self.checkFogDisabled()
            completion?()
        }

        leftPanel.run(
            SKAction.sequence([animAction, finalize]),
            withKey: "fogRetreat"
        )
    }

    // MARK: - Ceremony Visibility

    /// Hide or show all fog panels for ceremonies (hatching, evolution).
    /// When hidden, the entire Touch Bar landscape is visible.
    func setHiddenForCeremony(_ hidden: Bool) {
        leftPanel.isHidden = hidden
        rightPanel.isHidden = hidden
        leftGradient.isHidden = hidden
        rightGradient.isHidden = hidden
        leftDim.isHidden = hidden
        rightDim.isHidden = hidden
    }

    // MARK: - Visibility Query

    /// Returns the screen-space X range currently visible around the creature.
    /// Used by CommitEatingAnimation to spawn text at the fog edge.
    func visibleScreenRange(creatureScreenX: CGFloat) -> (left: CGFloat, right: CGFloat) {
        guard !isFogDisabled else {
            return (left: 0, right: FogOfWarController.sceneWidth)
        }
        let visRadius = config.visibilityRadius * currentZoom
        return (
            left: creatureScreenX - visRadius,
            right: creatureScreenX + visRadius
        )
    }

    // MARK: - Node Count

    var nodeCount: Int {
        var count = 0
        if leftPanel.parent != nil { count += 1 }
        if rightPanel.parent != nil { count += 1 }
        if leftGradient.parent != nil { count += 1 }
        if rightGradient.parent != nil { count += 1 }
        if leftDim.parent != nil { count += 1 }
        if rightDim.parent != nil { count += 1 }
        return count
    }

    // MARK: - Private

    private func checkFogDisabled() {
        let totalCoverage = config.visibilityRadius + config.edgeGradientWidth
        isFogDisabled = totalCoverage >= Self.sceneWidth

        leftPanel.isHidden = isFogDisabled
        rightPanel.isHidden = isFogDisabled
        leftGradient.isHidden = isFogDisabled
        rightGradient.isHidden = isFogDisabled
        leftDim.isHidden = isFogDisabled
        rightDim.isHidden = isFogDisabled
    }
}
