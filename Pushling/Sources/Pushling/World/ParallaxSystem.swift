// ParallaxSystem.swift — 3-layer parallax depth system for the Touch Bar world
// Far (0.15x), Mid (0.4x), Fore (1.0x) layers scrolling relative to camera.
// Each layer is an SKNode container; children are positioned in world-space
// and the layer's X offset creates the parallax effect.
//
// Performance target: <0.1ms per frame for parallax update.

import SpriteKit

// MARK: - Parallax Layer Definition

/// Defines one parallax depth layer.
struct ParallaxLayerConfig {
    let name: String
    let scrollFactor: CGFloat   // 0.0 = static, 1.0 = moves with camera
    let zPosition: CGFloat
}

// MARK: - ParallaxSystem

/// Manages the 3-layer parallax scrolling system.
/// The camera tracks a world-X position (typically the creature).
/// Each layer's X offset = -(worldX * scrollFactor), creating depth.
final class ParallaxSystem {

    // MARK: - Constants

    /// Scene dimensions (Touch Bar).
    static let sceneWidth: CGFloat = 1085
    static let sceneHeight: CGFloat = 30

    /// Layer configurations — 4 parallax depth layers.
    static let layerConfigs: [ParallaxLayerConfig] = [
        ParallaxLayerConfig(name: "far",  scrollFactor: 0.15, zPosition: -100),
        ParallaxLayerConfig(name: "deep", scrollFactor: 0.25, zPosition: -75),
        ParallaxLayerConfig(name: "mid",  scrollFactor: 0.4,  zPosition: -50),
        ParallaxLayerConfig(name: "fore", scrollFactor: 1.0,  zPosition: 0)
    ]

    // MARK: - Properties

    /// The three parallax layer nodes, keyed by name.
    private(set) var layers: [String: SKNode] = [:]

    /// Current camera world-X position. Set each frame from creature/test node.
    private(set) var cameraWorldX: CGFloat = 0

    /// Current zoom level (1.0 = normal, 2.0 = max zoom).
    private(set) var zoomLevel: CGFloat = 1.0

    /// The scene this system is attached to.
    private weak var scene: SKScene?

    // MARK: - Initialization

    /// Creates the parallax system and adds layer nodes to the scene.
    /// - Parameter scene: The PushlingScene to attach layers to.
    func attach(to scene: SKScene) {
        self.scene = scene

        for config in Self.layerConfigs {
            let layerNode = SKNode()
            layerNode.name = "parallax_\(config.name)"
            layerNode.zPosition = config.zPosition
            // Start centered — fore layer at 0, others offset by scroll factor
            layerNode.position = CGPoint(x: 0, y: 0)
            scene.addChild(layerNode)
            layers[config.name] = layerNode
        }
    }

    // MARK: - Layer Access

    /// Returns the far background layer (stars, mountains). 0.15x scroll.
    var farLayer: SKNode? { layers["far"] }

    /// Returns the deep layer (distant hills). 0.25x scroll.
    var deepLayer: SKNode? { layers["deep"] }

    /// Returns the mid layer (hills, landmarks). 0.4x scroll.
    var midLayer: SKNode? { layers["mid"] }

    /// Returns the foreground layer (ground, plants, creature). 1.0x scroll.
    var foreLayer: SKNode? { layers["fore"] }

    // MARK: - Update

    /// Updates all layer positions based on the camera's world-X and zoom level.
    /// Call once per frame from the scene's update loop.
    ///
    /// The camera conceptually looks at `worldX`. Each layer shifts
    /// by `-(worldX * scrollFactor)` to create parallax depth.
    /// The fore layer moves 1:1 with the camera (objects scroll past).
    /// The far layer barely moves (distant objects).
    /// Zoom scales layer positions around the scene center.
    ///
    /// - Parameters:
    ///   - worldX: The world-space X position to center on.
    ///   - zoom: Zoom level (1.0 = normal, 2.0 = double magnification).
    ///   - focusY: The Y position to keep centered when zoomed (creature Y).
    func update(cameraWorldX worldX: CGFloat, zoom: CGFloat = 1.0,
                focusY: CGFloat = 15.0, cameraWorldY: CGFloat = 0.0) {
        cameraWorldX = worldX
        zoomLevel = zoom

        // Half the scene width — camera centers on this point
        let halfWidth = Self.sceneWidth / 2.0

        for config in Self.layerConfigs {
            guard let layerNode = layers[config.name] else { continue }

            // Base position: scene center offset - (worldX * scrollFactor)
            let baseX = halfWidth - (worldX * config.scrollFactor)

            if zoom == 1.0 {
                // No zoom — simple parallax (horizontal + vertical)
                layerNode.position.x = baseX
                layerNode.position.y = -cameraWorldY * config.scrollFactor
                layerNode.setScale(1.0)
            } else {
                // Zoom: scale layer around the creature's position.
                // X: keep the camera center point stationary
                layerNode.setScale(zoom)
                layerNode.position.x = halfWidth + (baseX - halfWidth) * zoom
                // Y: vertical parallax + zoom focus
                let baseY = -cameraWorldY * config.scrollFactor
                layerNode.position.y = baseY * zoom + focusY * (1.0 - zoom)
            }
        }
    }

    // MARK: - Viewport Queries

    /// Returns the world-X range currently visible in a given layer.
    /// Useful for determining which chunks/objects to load or recycle.
    ///
    /// - Parameter layerName: "far", "mid", or "fore"
    /// - Returns: A closed range of world-X coordinates visible in the viewport.
    func visibleWorldRange(for layerName: String) -> ClosedRange<CGFloat> {
        guard let config = Self.layerConfigs.first(where: { $0.name == layerName }) else {
            return 0...Self.sceneWidth
        }

        // The layer's position.x = halfWidth - (worldX * scrollFactor)
        // A child at world position `wx` in the layer appears at screen position:
        //   screenX = layerPosition.x + wx = halfWidth - worldX*factor + wx
        // Visible when 0 <= screenX <= sceneWidth
        // So: -halfWidth + worldX*factor <= wx <= halfWidth + worldX*factor + halfWidth
        //     worldX*factor - halfWidth <= wx <= worldX*factor + halfWidth
        // Wait, let me re-derive. Layer position = halfWidth - worldX*factor.
        // Child at wx appears on screen at: (halfWidth - worldX*factor) + wx
        // Visible when 0 <= ... <= sceneWidth
        // wx >= -(halfWidth - worldX*factor) = worldX*factor - halfWidth
        // wx <= sceneWidth - (halfWidth - worldX*factor) = halfWidth + worldX*factor

        let effectiveX = cameraWorldX * config.scrollFactor
        // When zoomed in, the visible range shrinks (we see less world)
        let halfWidth = (Self.sceneWidth / 2.0) / max(zoomLevel, 0.1)
        let minX = effectiveX - halfWidth
        let maxX = effectiveX + halfWidth
        return minX...maxX
    }

    /// Returns the world-X range visible for the foreground layer (1.0x).
    /// This is the most commonly needed range (terrain, objects).
    var visibleForeRange: ClosedRange<CGFloat> {
        visibleWorldRange(for: "fore")
    }

    /// Returns a padded range for pre-loading content ahead of the viewport.
    /// Adds `padding` points on each side.
    func paddedVisibleRange(for layerName: String,
                            padding: CGFloat) -> ClosedRange<CGFloat> {
        let base = visibleWorldRange(for: layerName)
        return (base.lowerBound - padding)...(base.upperBound + padding)
    }
}
