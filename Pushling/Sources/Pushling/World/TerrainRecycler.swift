// TerrainRecycler.swift — Terrain chunk and object lifecycle management
// Manages the visual representation of terrain on the foreground layer.
// As the creature walks, off-screen terrain is recycled to the leading edge.
// Target: zero net node creation during steady-state walking.
//
// Each "visual chunk" contains:
//   - An SKShapeNode ground polygon (terrain height profile)
//   - 0-N terrain object nodes placed on the surface
//
// Object pool sizes: ~20 terrain objects, ~10 ground nodes.

import SpriteKit

// MARK: - Visual Chunk

/// A rendered terrain chunk on the foreground layer.
/// Contains the ground shape and all terrain objects within it.
final class VisualChunk {
    /// The terrain chunk data backing this visual.
    var chunkIndex: Int

    /// Container node holding ground + objects.
    let containerNode: SKNode

    /// The ground polygon shape.
    var groundNode: SKShapeNode?

    /// Terrain object nodes in this chunk.
    var objectNodes: [SKNode] = []

    /// Whether this chunk is currently active (has parent).
    var isActive: Bool { containerNode.parent != nil }

    init(chunkIndex: Int) {
        self.chunkIndex = chunkIndex
        self.containerNode = SKNode()
        self.containerNode.name = "chunk_\(chunkIndex)"
    }

    /// Removes all children and resets for reuse.
    func reset() {
        groundNode?.removeFromParent()
        groundNode = nil
        for obj in objectNodes {
            obj.removeAllActions()
            obj.removeFromParent()
        }
        objectNodes.removeAll()
        containerNode.removeAllChildren()
        containerNode.removeFromParent()
    }
}

// MARK: - TerrainRecycler

/// Manages visual terrain chunks — creating, recycling, and maintaining
/// a constant node count as the camera moves through the world.
final class TerrainRecycler {

    // MARK: - Constants

    /// How far off-screen (in points) before a chunk is recycled.
    static let recycleMargin: CGFloat = 1.5 * ParallaxSystem.sceneWidth

    /// How far ahead of the viewport to pre-generate chunks.
    static let preloadMargin: CGFloat = 300

    /// Minimum spacing between terrain objects (points).
    static let minObjectSpacing: CGFloat = 20

    /// Maximum interactive objects visible at once.
    static let maxInteractiveVisible: Int = 2

    /// Noise offset for object placement (decorrelated from terrain/biome).
    private static let objectNoiseSeed: UInt64 = 0xFACE_B00C_1337_7331

    // MARK: - Properties

    /// All active visual chunks, keyed by chunk index.
    private var activeChunks: [Int: VisualChunk] = [:]

    /// Pool of recycled visual chunks ready for reuse.
    private var chunkPool: [VisualChunk] = []

    /// Pool of recycled terrain object nodes by type.
    private var objectPool: [TerrainObjectType: [SKNode]] = [:]

    /// Reference to the terrain generator.
    private let terrainGenerator: TerrainGenerator

    /// Reference to the biome manager.
    private let biomeManager: BiomeManager

    /// The foreground layer to add chunks to.
    private weak var foreLayer: SKNode?

    /// Permutation table for object placement noise.
    private let objectPerm: [UInt8]

    /// Count of currently visible interactive objects.
    private var visibleInteractiveCount: Int = 0

    // MARK: - Initialization

    init(terrainGenerator: TerrainGenerator,
         biomeManager: BiomeManager,
         foreLayer: SKNode) {
        self.terrainGenerator = terrainGenerator
        self.biomeManager = biomeManager
        self.foreLayer = foreLayer
        self.objectPerm = Self.buildObjectPerm()
    }

    // MARK: - Frame Update

    /// Main update method — call once per frame.
    /// Ensures chunks exist for the visible range and recycles off-screen chunks.
    ///
    /// - Parameter cameraWorldX: Current camera center in world-space.
    func update(cameraWorldX: CGFloat) {
        let halfView = ParallaxSystem.sceneWidth / 2.0

        // Determine which chunks should be active
        let minX = cameraWorldX - halfView - Self.preloadMargin
        let maxX = cameraWorldX + halfView + Self.preloadMargin
        let minChunk = TerrainGenerator.chunkIndex(for: minX)
        let maxChunk = TerrainGenerator.chunkIndex(for: maxX)

        // Recycle chunks that are too far away
        recycleDistantChunks(cameraWorldX: cameraWorldX)

        // Create/activate chunks that should be visible
        for i in minChunk...maxChunk {
            if activeChunks[i] == nil {
                activateChunk(at: i)
            }
        }
    }

    /// Returns the total number of active nodes (for debug overlay).
    var activeNodeCount: Int {
        var count = 0
        for chunk in activeChunks.values {
            count += 1  // container
            count += chunk.groundNode != nil ? 1 : 0
            count += chunk.objectNodes.count
        }
        return count
    }

    // MARK: - Chunk Activation

    /// Activates a chunk at the given index — either from pool or newly created.
    private func activateChunk(at index: Int) {
        let terrainChunk = terrainGenerator.chunkAt(index: index)

        // Get or create a visual chunk
        let visual: VisualChunk
        if let recycled = chunkPool.popLast() {
            recycled.reset()
            recycled.chunkIndex = index
            visual = recycled
        } else {
            visual = VisualChunk(chunkIndex: index)
        }

        // Build ground polygon
        let groundNode = buildGroundNode(from: terrainChunk)
        visual.containerNode.addChild(groundNode)
        visual.groundNode = groundNode

        // Place terrain objects
        let objects = placeObjects(in: terrainChunk)
        for obj in objects {
            visual.containerNode.addChild(obj)
            visual.objectNodes.append(obj)
        }

        // Position container at chunk world-X start
        visual.containerNode.position = CGPoint(
            x: terrainChunk.worldXStart,
            y: 0
        )
        visual.containerNode.name = "chunk_\(index)"

        // Add to scene
        foreLayer?.addChild(visual.containerNode)
        activeChunks[index] = visual
    }

    // MARK: - Chunk Recycling

    /// Recycles chunks that have scrolled too far off-screen.
    private func recycleDistantChunks(cameraWorldX: CGFloat) {
        let margin = Self.recycleMargin
        let minKeep = cameraWorldX - margin
        let maxKeep = cameraWorldX + margin

        let keysToRecycle = activeChunks.keys.filter { index in
            let chunkStart = CGFloat(index) * TerrainGenerator.chunkWorldWidth
            let chunkEnd = chunkStart + TerrainGenerator.chunkWorldWidth
            return chunkEnd < minKeep || chunkStart > maxKeep
        }

        for key in keysToRecycle {
            guard let visual = activeChunks.removeValue(forKey: key) else { continue }

            // Return object nodes to pool
            for obj in visual.objectNodes {
                if let typeName = obj.name,
                   let type = terrainObjectType(from: typeName) {
                    obj.removeAllActions()
                    obj.removeFromParent()
                    objectPool[type, default: []].append(obj)
                }
            }

            visual.reset()
            chunkPool.append(visual)
        }

        // Recount interactive objects
        visibleInteractiveCount = activeChunks.values.reduce(0) { count, chunk in
            count + chunk.objectNodes.filter { node in
                guard let name = node.name else { return false }
                return name.contains("yarnBall") || name.contains("cardboardBox")
            }.count
        }
    }

    // MARK: - Ground Polygon

    /// Builds an SKShapeNode polygon for the terrain chunk's height profile.
    private func buildGroundNode(from chunk: TerrainChunk) -> SKShapeNode {
        let path = CGMutablePath()
        let pps = TerrainGenerator.pointsPerSample

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: 0))

        // Walk along the heightmap
        for (i, height) in chunk.heights.enumerated() {
            let x = CGFloat(i) * pps
            let y = TerrainGenerator.baselineY + height
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close polygon at bottom-right
        let endX = CGFloat(chunk.heights.count) * pps
        path.addLine(to: CGPoint(x: endX, y: 0))
        path.closeSubpath()

        let groundNode = SKShapeNode(path: path)

        // Biome-blended ground color
        let centerX = chunk.worldXStart + TerrainGenerator.chunkWorldWidth / 2
        let baseColor = biomeManager.groundColor(at: centerX)

        // Ground is the biome tint at reduced alpha, blended with Ash base
        groundNode.fillColor = PushlingPalette.lerp(
            from: PushlingPalette.ash,
            to: baseColor,
            t: 0.4
        )
        groundNode.strokeColor = baseColor.withAlphaComponent(0.5)
        groundNode.lineWidth = 0.5
        groundNode.name = "ground"
        groundNode.zPosition = -1  // Below objects within fore layer

        return groundNode
    }

    // MARK: - Object Placement

    /// Places terrain objects within a chunk based on noise-driven positions.
    /// Returns the created object nodes.
    private func placeObjects(in chunk: TerrainChunk) -> [SKNode] {
        var nodes: [SKNode] = []
        let chunkWidth = TerrainGenerator.chunkWorldWidth
        let biomeBlend = biomeManager.biomeBlendAt(
            worldX: chunk.worldXStart + chunkWidth / 2
        )

        // Determine object count based on biome density
        let density = biomeBlend.primary.objectDensity
        let approxCount = Int(density * chunkWidth / 100.0)

        // Use noise to place objects at deterministic positions
        var lastObjectX: CGFloat = -Self.minObjectSpacing
        var placedCount = 0

        let sampleCount = TerrainGenerator.samplesPerChunk
        let stride = max(1, sampleCount / max(1, approxCount + 2))

        for sampleIdx in Swift.stride(from: stride / 2,
                                       to: sampleCount,
                                       by: stride) {
            // Object placement noise
            let worldSample = chunk.index * sampleCount + sampleIdx
            let placementNoise = objectNoise(worldSample)

            // Only place if noise exceeds threshold (controls density)
            let densityThreshold = 256 - Int(density * 80)
            guard placementNoise > densityThreshold else { continue }

            // Check spacing
            let localX = CGFloat(sampleIdx) * TerrainGenerator.pointsPerSample
            guard localX - lastObjectX >= Self.minObjectSpacing else { continue }

            // Select object type from biome pool
            let selectionNoise = objectNoise(worldSample + 10000)
            let blendNoise = objectNoise(worldSample + 20000)
            let objectType = BiomeObjectPool.selectFromBlend(
                blend: biomeBlend,
                noiseValue: selectionNoise,
                blendNoise: blendNoise
            )

            // Enforce interactive object cap
            if objectType.isInteractive
                && visibleInteractiveCount >= Self.maxInteractiveVisible {
                continue
            }

            // Get terrain height at this position
            let heightIdx = min(sampleIdx, chunk.heights.count - 1)
            let terrainY = TerrainGenerator.baselineY + chunk.heights[heightIdx]

            // Create or recycle node
            let node = obtainObjectNode(type: objectType, biome: biomeBlend.primary)
            node.position = CGPoint(x: localX, y: terrainY)

            nodes.append(node)
            lastObjectX = localX
            placedCount += 1

            if objectType.isInteractive {
                visibleInteractiveCount += 1
            }
        }

        return nodes
    }

    /// Gets an object node from pool or creates a new one.
    private func obtainObjectNode(
        type: TerrainObjectType,
        biome: BiomeType
    ) -> SKNode {
        if var pool = objectPool[type], let recycled = pool.popLast() {
            objectPool[type] = pool
            // Re-apply any actions that were stripped on recycling
            if type == .starFragment {
                let fadeDown = SKAction.fadeAlpha(to: 0.5, duration: 1.5)
                fadeDown.timingMode = .easeInEaseOut
                let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 1.5)
                fadeUp.timingMode = .easeInEaseOut
                recycled.run(SKAction.repeatForever(
                    SKAction.sequence([fadeDown, fadeUp])
                ), withKey: "glow")
            }
            return recycled
        }
        return TerrainObjectNodeFactory.createNode(for: type, biome: biome)
    }

    // MARK: - Object Noise

    /// Noise for object placement (decorrelated from terrain/biome).
    private func objectNoise(_ x: Int) -> Int {
        let wrapped = ((x % 256) + 256) % 256
        return Int(objectPerm[wrapped])
    }

    /// Extracts TerrainObjectType from a node name.
    private func terrainObjectType(from name: String) -> TerrainObjectType? {
        let prefix = "obj_"
        guard name.hasPrefix(prefix) else { return nil }
        let typeName = String(name.dropFirst(prefix.count))
        return TerrainObjectType(rawValue: typeName)
    }

    // MARK: - Object Queries (P3-T3-04)

    /// Finds the nearest terrain object of a specific type within a max distance.
    /// Used by puddle reflection system to find water puddles.
    /// - Parameters:
    ///   - type: The terrain object type to search for.
    ///   - worldX: The reference world-X position.
    ///   - maxDistance: Maximum search distance in points.
    /// - Returns: The world-X of the nearest matching object, or nil.
    func nearestObjectOfType(_ type: TerrainObjectType,
                              to worldX: CGFloat,
                              maxDistance: CGFloat) -> CGFloat? {
        let targetName = "obj_\(type.rawValue)"
        var closestX: CGFloat?
        var closestDist: CGFloat = maxDistance

        for chunk in activeChunks.values {
            let chunkWorldX = CGFloat(chunk.chunkIndex)
                * TerrainGenerator.chunkWorldWidth
            for objNode in chunk.objectNodes {
                guard objNode.name == targetName else { continue }
                let objWorldX = chunkWorldX + objNode.position.x
                let dist = abs(objWorldX - worldX)
                if dist < closestDist {
                    closestDist = dist
                    closestX = objWorldX
                }
            }
        }

        return closestX
    }

    // MARK: - Permutation Table

    private static func buildObjectPerm() -> [UInt8] {
        var table = (0..<256).map { UInt8($0) }
        var rng = objectNoiseSeed

        for i in Swift.stride(from: 255, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            table.swapAt(i, j)
        }

        return table
    }
}
