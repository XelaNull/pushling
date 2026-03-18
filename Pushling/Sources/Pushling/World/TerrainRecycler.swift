// TerrainRecycler.swift — Terrain chunk lifecycle for fore, mid, and far layers.
// Recycles off-screen terrain to the leading edge. Zero net node creation at steady-state.

import SpriteKit

// MARK: - Visual Chunk

/// A rendered terrain chunk: ground shape + terrain objects.
final class VisualChunk {
    var chunkIndex: Int
    let containerNode: SKNode
    var groundNode: SKShapeNode?
    var objectNodes: [SKNode] = []
    var textureNodes: [SKShapeNode] = []
    var isActive: Bool { containerNode.parent != nil }

    init(chunkIndex: Int) {
        self.chunkIndex = chunkIndex
        self.containerNode = SKNode()
        self.containerNode.name = "chunk_\(chunkIndex)"
    }

    func reset() {
        groundNode?.removeFromParent()
        groundNode = nil
        for obj in objectNodes { obj.removeAllActions(); obj.removeFromParent() }
        objectNodes.removeAll()
        textureNodes.removeAll()
        containerNode.removeAllChildren()
        containerNode.removeFromParent()
    }
}

// MARK: - TerrainRecycler

/// Manages visual terrain chunks for all three parallax layers.
final class TerrainRecycler {

    // MARK: - Constants

    static let recycleMargin: CGFloat = 1.5 * ParallaxSystem.sceneWidth
    static let preloadMargin: CGFloat = 300
    static let minObjectSpacing: CGFloat = 20
    static let maxInteractiveVisible: Int = 2
    private static let objectNoiseSeed: UInt64 = 0xFACE_B00C_1337_7331

    // Background layer constants
    private static let farSeedOffset: UInt64 = 0xFA20_FACE
    private static let deepSeedOffset: UInt64 = 0xD33D_1A7E
    private static let midSeedOffset: UInt64 = 0xBEEF_0000
    private static let farSamplesPerChunk: Int = 128
    private static let deepSamplesPerChunk: Int = 192
    private static let midSamplesPerChunk: Int = 256
    private static let farPointsPerSample: CGFloat = 4.0
    private static let deepPointsPerSample: CGFloat = 3.0
    private static let midPointsPerSample: CGFloat = 2.0
    static let farChunkWidth: CGFloat = CGFloat(farSamplesPerChunk) * farPointsPerSample
    static let deepChunkWidth: CGFloat = CGFloat(deepSamplesPerChunk) * deepPointsPerSample
    static let midChunkWidth: CGFloat = CGFloat(midSamplesPerChunk) * midPointsPerSample
    private static let farXOffset: CGFloat = 50.0
    private static let deepXOffset: CGFloat = 37.0
    private static let midXOffset: CGFloat = 25.0

    // MARK: - Properties

    private var activeChunks: [Int: VisualChunk] = [:]
    private var activeChunksFar: [Int: VisualChunk] = [:]
    private var activeChunksDeep: [Int: VisualChunk] = [:]
    private var activeChunksMid: [Int: VisualChunk] = [:]
    private var chunkPool: [VisualChunk] = []
    private var objectPool: [TerrainObjectType: [SKNode]] = [:]
    private let terrainGenerator: TerrainGenerator
    private let biomeManager: BiomeManager
    private weak var foreLayer: SKNode?
    private weak var midLayer: SKNode?
    private weak var deepLayer: SKNode?
    private weak var farLayer: SKNode?
    weak var complexityController: VisualComplexityController?
    private let objectPerm: [UInt8]
    private var visibleInteractiveCount: Int = 0

    // MARK: - Initialization

    init(terrainGenerator: TerrainGenerator,
         biomeManager: BiomeManager,
         foreLayer: SKNode,
         midLayer: SKNode? = nil,
         deepLayer: SKNode? = nil,
         farLayer: SKNode? = nil) {
        self.terrainGenerator = terrainGenerator
        self.biomeManager = biomeManager
        self.foreLayer = foreLayer
        self.midLayer = midLayer
        self.deepLayer = deepLayer
        self.farLayer = farLayer
        self.objectPerm = Self.buildObjectPerm()
    }

    // MARK: - Frame Update

    /// Updates all terrain layers. Call once per frame.
    func update(cameraWorldX: CGFloat) {
        let halfView = ParallaxSystem.sceneWidth / 2.0

        // Determine which foreground chunks should be active
        let minX = cameraWorldX - halfView - Self.preloadMargin
        let maxX = cameraWorldX + halfView + Self.preloadMargin
        let minChunk = TerrainGenerator.chunkIndex(for: minX)
        let maxChunk = TerrainGenerator.chunkIndex(for: maxX)

        // Recycle chunks that are too far away
        recycleDistantChunks(cameraWorldX: cameraWorldX)

        // Create/activate foreground chunks
        for i in minChunk...maxChunk {
            if activeChunks[i] == nil {
                activateChunk(at: i)
            }
        }

        // Update background layers (far and mid)
        updateBackgroundChunks(cameraWorldX: cameraWorldX)
    }

    /// Returns the total number of active nodes (for debug overlay).
    var activeNodeCount: Int {
        var count = 0
        for chunk in activeChunks.values {
            count += 1  // container
            count += chunk.groundNode != nil ? 1 : 0
            count += chunk.objectNodes.count
            count += chunk.textureNodes.count
        }
        for chunk in activeChunksFar.values {
            count += chunk.groundNode != nil ? 1 : 0
        }
        for chunk in activeChunksDeep.values {
            count += chunk.groundNode != nil ? 1 : 0
        }
        for chunk in activeChunksMid.values {
            count += chunk.groundNode != nil ? 1 : 0
        }
        return count
    }

    // MARK: - Texture Rebuild

    /// Rebuilds terrain texture overlays on all active foreground chunks.
    /// Call when complexity level changes (stage evolution) so existing
    /// chunks update without waiting for recycle.
    func rebuildActiveChunkTextures() {
        let config = complexityController?.terrainTextureConfig
        let hasTexture = config.map {
            $0.shadowAlpha > 0 || $0.highlightAlpha > 0
                || $0.contourLineCount > 0 || $0.microDetailSpacing > 0
        } ?? false

        for (index, visual) in activeChunks {
            // Strip old texture nodes
            for node in visual.textureNodes { node.removeFromParent() }
            visual.textureNodes.removeAll()

            // Rebuild with current config
            if hasTexture, let config = config {
                let terrainChunk = terrainGenerator.chunkAt(index: index)
                let centerX = terrainChunk.worldXStart
                    + TerrainGenerator.chunkWorldWidth / 2
                let biomeColor = biomeManager.groundColor(at: centerX)
                let texNodes = buildTerrainTexture(
                    from: terrainChunk,
                    biomeColor: biomeColor,
                    config: config
                )
                for node in texNodes {
                    visual.containerNode.addChild(node)
                }
                visual.textureNodes = texNodes
            }
        }
    }

    // MARK: - Chunk Activation

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

        // Build terrain texture overlays (complexity-gated)
        if let config = complexityController?.terrainTextureConfig,
           config.shadowAlpha > 0 || config.highlightAlpha > 0
               || config.contourLineCount > 0 || config.microDetailSpacing > 0 {
            let centerX = terrainChunk.worldXStart
                + TerrainGenerator.chunkWorldWidth / 2
            let biomeColor = biomeManager.groundColor(at: centerX)
            let texNodes = buildTerrainTexture(
                from: terrainChunk,
                biomeColor: biomeColor,
                config: config
            )
            for node in texNodes {
                visual.containerNode.addChild(node)
            }
            visual.textureNodes = texNodes
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

    private func buildGroundNode(from chunk: TerrainChunk) -> SKShapeNode {
        let path = CGMutablePath()
        let pps = TerrainGenerator.pointsPerSample

        // Start at bottom-left (extend well below baseline so ground fill
        // covers any visible area during camera Y-shift and zoom-out)
        path.move(to: CGPoint(x: 0, y: -60))

        // Walk along the heightmap
        for (i, height) in chunk.heights.enumerated() {
            let x = CGFloat(i) * pps
            let y = TerrainGenerator.baselineY + height
            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close polygon at bottom-right
        let endX = CGFloat(chunk.heights.count) * pps
        path.addLine(to: CGPoint(x: endX, y: -60))
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

    /// Places terrain objects within a chunk using noise-driven positions.
    /// Respects complexity-gated maxObjects limit (spore = 0 objects).
    private func placeObjects(in chunk: TerrainChunk) -> [SKNode] {
        // Gate: skip object placement if complexity says maxObjects = 0
        let maxAllowed = complexityController?.terrainConfig.maxObjects ?? 0
        guard maxAllowed > 0 else { return [] }

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

    /// Finds the nearest terrain object of a type within max distance.
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

    // MARK: - Background Terrain

    private struct BGLayerConfig {
        let scrollFactor: CGFloat
        let samples: Int
        let pps: CGFloat
        let chunkWidth: CGFloat
        let octaves: Int
        let amplitude: CGFloat
        let seedOffset: UInt64
        let xOffset: CGFloat
        let depth: CGFloat
        let prefix: String
    }

    private static let farConfig = BGLayerConfig(
        scrollFactor: 0.15, samples: farSamplesPerChunk,
        pps: farPointsPerSample, chunkWidth: farChunkWidth,
        octaves: 1, amplitude: 1.5, seedOffset: farSeedOffset,
        xOffset: farXOffset, depth: 0.85, prefix: "far"
    )

    private static let deepConfig = BGLayerConfig(
        scrollFactor: 0.25, samples: deepSamplesPerChunk,
        pps: deepPointsPerSample, chunkWidth: deepChunkWidth,
        octaves: 1, amplitude: 1.2, seedOffset: deepSeedOffset,
        xOffset: deepXOffset, depth: 0.65, prefix: "deep"
    )

    private static let midConfig = BGLayerConfig(
        scrollFactor: 0.4, samples: midSamplesPerChunk,
        pps: midPointsPerSample, chunkWidth: midChunkWidth,
        octaves: 2, amplitude: 1.0, seedOffset: midSeedOffset,
        xOffset: midXOffset, depth: 0.4, prefix: "mid"
    )

    private func updateBackgroundChunks(cameraWorldX: CGFloat) {
        if farLayer != nil {
            updateBGLayer(cameraWorldX: cameraWorldX, layer: farLayer,
                          active: &activeChunksFar, config: Self.farConfig)
        }
        if deepLayer != nil {
            updateBGLayer(cameraWorldX: cameraWorldX, layer: deepLayer,
                          active: &activeChunksDeep, config: Self.deepConfig)
        }
        if midLayer != nil {
            updateBGLayer(cameraWorldX: cameraWorldX, layer: midLayer,
                          active: &activeChunksMid, config: Self.midConfig)
        }
    }

    private func updateBGLayer(cameraWorldX: CGFloat, layer: SKNode?,
                                active: inout [Int: VisualChunk],
                                config: BGLayerConfig) {
        let effectiveX = cameraWorldX * config.scrollFactor
        let half = ParallaxSystem.sceneWidth / 2.0
        let minChunk = Int(floor((effectiveX - half - Self.preloadMargin) / config.chunkWidth))
        let maxChunk = Int(floor((effectiveX + half + Self.preloadMargin) / config.chunkWidth))

        let margin = Self.recycleMargin
        let keysToRecycle = active.keys.filter { i in
            let start = CGFloat(i) * config.chunkWidth
            return (start + config.chunkWidth) < effectiveX - margin
                || start > effectiveX + margin
        }
        for key in keysToRecycle { active.removeValue(forKey: key)?.reset() }

        for i in minChunk...maxChunk where active[i] == nil {
            guard let layer = layer else { continue }
            let heights = terrainGenerator.generateBackgroundHeights(
                chunkIndex: i, sampleCount: config.samples,
                octaves: config.octaves, amplitudeScale: config.amplitude,
                seedOffset: config.seedOffset
            )
            let ground = buildBGGround(heights: heights, pps: config.pps, depth: config.depth)
            let visual = VisualChunk(chunkIndex: i)
            visual.containerNode.addChild(ground)
            visual.groundNode = ground
            visual.containerNode.position = CGPoint(
                x: CGFloat(i) * config.chunkWidth + config.xOffset, y: 0)
            visual.containerNode.name = "\(config.prefix)_chunk_\(i)"
            layer.addChild(visual.containerNode)
            active[i] = visual
        }
    }

    private func buildBGGround(heights: [CGFloat], pps: CGFloat,
                                depth: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -60))
        for (i, h) in heights.enumerated() {
            path.addLine(to: CGPoint(x: CGFloat(i) * pps, y: TerrainGenerator.baselineY + h))
        }
        path.addLine(to: CGPoint(x: CGFloat(heights.count) * pps, y: -60))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        let base = PushlingPalette.ash
        node.fillColor = PushlingPalette.atmosphericColor(base, depth: depth)
        if depth < 0.5 {
            node.strokeColor = PushlingPalette.atmosphericColor(base, depth: depth)
                .withAlphaComponent(0.3)
            node.lineWidth = 0.5
        } else {
            node.strokeColor = .clear
            node.lineWidth = 0
        }
        node.name = "bg_ground"
        node.zPosition = -1
        return node
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
