// TerrainRecycler+Texture.swift — Terrain texture detail overlays
// Adds valley shadows, hilltop highlights, contour lines, and micro-detail
// grass blades to foreground terrain chunks.
//
// All detail is complexity-gated via TerrainTextureConfig from VisualComplexityController.
// Costs +3 nodes/chunk max (~9-15 total). ~0.7-1ms additional build time per chunk.
//
// Shadow/highlight use thin ribbon polygons that follow the terrain surface
// (not full-height fills) to avoid bright/dark blobs on OLED.

import SpriteKit

extension TerrainRecycler {

    // MARK: - Constants

    private static let grassSeedOffset: UInt64 = 0x68A5_FEED
    private static let shadowRibbonHeight: CGFloat = 2.0
    private static let highlightRibbonHeight: CGFloat = 1.5

    // MARK: - Entry Point

    /// Builds terrain texture overlay nodes for a chunk.
    /// Returns 0-3 SKShapeNodes based on complexity config.
    func buildTerrainTexture(
        from chunk: TerrainChunk,
        biomeColor: SKColor,
        config: TerrainTextureConfig
    ) -> [SKShapeNode] {
        let heights = chunk.heights
        guard !heights.isEmpty else { return [] }

        let pps = TerrainGenerator.pointsPerSample
        var nodes: [SKShapeNode] = []

        // Shadow and highlight ribbon overlays (up to 2 nodes)
        let overlays = buildShadowHighlightOverlays(
            heights: heights, pps: pps,
            config: config
        )
        nodes.append(contentsOf: overlays)

        // Contour lines and micro-detail grass (1 compound node)
        if config.contourLineCount > 0 || config.microDetailSpacing > 0 {
            if let detailNode = buildContourAndDetailPath(
                heights: heights, pps: pps,
                config: config,
                chunkIndex: chunk.index
            ) {
                nodes.append(detailNode)
            }
        }

        return nodes
    }

    // MARK: - Shadow & Highlight Ribbon Overlays

    /// Builds thin ribbon polygons along terrain surface for shadow (valleys/slopes)
    /// and highlight (peaks). Each ribbon is ~2.5-3pt tall, following the terrain contour.
    private func buildShadowHighlightOverlays(
        heights: [CGFloat],
        pps: CGFloat,
        config: TerrainTextureConfig
    ) -> [SKShapeNode] {
        guard let maxHeight = heights.max(), maxHeight > 0.5 else { return [] }

        let baseY = TerrainGenerator.baselineY
        let shadowThreshold = maxHeight * 0.4
        let highlightThreshold = maxHeight * 0.65
        var nodes: [SKShapeNode] = []

        // Shadow ribbons — valleys and steep slopes
        if config.shadowAlpha > 0 {
            let regions = findRegions(heights: heights, config: config,
                                      threshold: shadowThreshold,
                                      above: false)
            if !regions.isEmpty {
                let path = CGMutablePath()
                for region in regions {
                    addRibbon(to: path, heights: heights, pps: pps,
                              baseY: baseY, start: region.start,
                              end: region.end,
                              ribbonHeight: Self.shadowRibbonHeight)
                }
                let node = SKShapeNode(path: path)
                node.fillColor = PushlingPalette.void_
                    .withAlphaComponent(config.shadowAlpha)
                node.strokeColor = .clear
                node.lineWidth = 0
                node.name = "terrain_shadow"
                node.zPosition = -0.5
                nodes.append(node)
            }
        }

        // Highlight ribbons — hilltops
        if config.highlightAlpha > 0 {
            let regions = findRegions(heights: heights, config: config,
                                      threshold: highlightThreshold,
                                      above: true)
            if !regions.isEmpty {
                let path = CGMutablePath()
                for region in regions {
                    addRibbon(to: path, heights: heights, pps: pps,
                              baseY: baseY, start: region.start,
                              end: region.end,
                              ribbonHeight: Self.highlightRibbonHeight)
                }
                let node = SKShapeNode(path: path)
                node.fillColor = PushlingPalette.bone
                    .withAlphaComponent(config.highlightAlpha)
                node.strokeColor = .clear
                node.lineWidth = 0
                node.name = "terrain_highlight"
                node.zPosition = -0.5
                nodes.append(node)
            }
        }

        return nodes
    }

    /// Finds contiguous sample regions that qualify for shadow or highlight.
    /// - Parameters:
    ///   - above: true = find regions where height > threshold (highlights).
    ///            false = find regions where height < threshold OR steep slope (shadows).
    private func findRegions(
        heights: [CGFloat],
        config: TerrainTextureConfig,
        threshold: CGFloat,
        above: Bool
    ) -> [(start: Int, end: Int)] {
        var regions: [(start: Int, end: Int)] = []
        var regionStart: Int?

        for i in 0..<heights.count {
            let qualifies: Bool
            if above {
                qualifies = heights[i] > threshold
            } else {
                let slope: CGFloat = i > 0 ? abs(heights[i] - heights[i - 1]) : 0
                qualifies = heights[i] < threshold
                    || (config.slopeShadingEnabled && slope > 0.5)
            }

            if qualifies && regionStart == nil {
                regionStart = i
            } else if !qualifies, let start = regionStart {
                regions.append((start: start, end: i - 1))
                regionStart = nil
            }
        }
        if let start = regionStart {
            regions.append((start: start, end: heights.count - 1))
        }

        return regions
    }

    /// Adds a thin ribbon subpath to the compound path.
    /// Traces terrain surface forward, then traces shifted-down surface backward.
    /// Creates a filled band that sits on the terrain surface.
    private func addRibbon(
        to path: CGMutablePath,
        heights: [CGFloat],
        pps: CGFloat,
        baseY: CGFloat,
        start: Int,
        end: Int,
        ribbonHeight: CGFloat
    ) {
        guard end >= start else { return }

        // Forward trace: along terrain surface
        let startX = CGFloat(start) * pps
        let startY = baseY + heights[start]
        path.move(to: CGPoint(x: startX, y: startY))

        if end > start {
            for i in (start + 1)...end {
                path.addLine(to: CGPoint(
                    x: CGFloat(i) * pps,
                    y: baseY + heights[i]
                ))
            }
        }

        // Backward trace: terrain surface shifted down by ribbonHeight
        for i in stride(from: end, through: start, by: -1) {
            path.addLine(to: CGPoint(
                x: CGFloat(i) * pps,
                y: baseY + heights[i] - ribbonHeight
            ))
        }

        path.closeSubpath()
    }

    // MARK: - Contour Lines & Micro-Detail

    /// Builds a compound path containing contour lines at Y thresholds
    /// and tiny vertical grass blade strokes on the terrain surface.
    /// Returns nil if no content was generated.
    private func buildContourAndDetailPath(
        heights: [CGFloat],
        pps: CGFloat,
        config: TerrainTextureConfig,
        chunkIndex: Int
    ) -> SKShapeNode? {
        guard let maxHeight = heights.max(), maxHeight > 1.0 else { return nil }

        let baseY = TerrainGenerator.baselineY
        let path = CGMutablePath()
        var hasContent = false

        // Contour lines at evenly-spaced height thresholds
        if config.contourLineCount > 0 {
            for lineIdx in 1...config.contourLineCount {
                let threshold = maxHeight * CGFloat(lineIdx)
                    / CGFloat(config.contourLineCount + 1)
                let contourY = baseY + threshold
                var inRegion = false
                var regionStartX: CGFloat = 0

                for i in 0..<heights.count {
                    let above = heights[i] >= threshold

                    if above && !inRegion {
                        // Interpolate precise crossing point
                        if i > 0 && heights[i - 1] < threshold {
                            let t = (threshold - heights[i - 1])
                                / (heights[i] - heights[i - 1])
                            regionStartX = (CGFloat(i - 1) + t) * pps
                        } else {
                            regionStartX = CGFloat(i) * pps
                        }
                        inRegion = true
                    } else if !above && inRegion {
                        // Interpolate precise exit point
                        let endX: CGFloat
                        if i > 0 && heights[i - 1] >= threshold {
                            let delta = heights[i - 1] - heights[i]
                            let t = delta > 0
                                ? (heights[i - 1] - threshold) / delta
                                : 0
                            endX = (CGFloat(i - 1) + t) * pps
                        } else {
                            endX = CGFloat(i) * pps
                        }

                        path.move(to: CGPoint(x: regionStartX, y: contourY))
                        path.addLine(to: CGPoint(x: endX, y: contourY))
                        hasContent = true
                        inRegion = false
                    }
                }

                // Close at chunk edge if still in region
                if inRegion {
                    let endX = CGFloat(heights.count - 1) * pps
                    path.move(to: CGPoint(x: regionStartX, y: contourY))
                    path.addLine(to: CGPoint(x: endX, y: contourY))
                    hasContent = true
                }
            }
        }

        // Micro-detail: tiny vertical grass blades on terrain surface
        if config.microDetailSpacing > 0 {
            let samplesPerChunk = TerrainGenerator.samplesPerChunk
            let worldOffset = chunkIndex * samplesPerChunk
            let spacing = config.microDetailSpacing
            let chunkWidth = CGFloat(heights.count) * pps
            var x: CGFloat = spacing / 2

            while x < chunkWidth {
                let sampleIdx = min(Int(x / pps), heights.count - 1)
                let terrainY = baseY + heights[sampleIdx]

                // Deterministic noise for blade placement and height
                let worldSample = worldOffset + sampleIdx
                let noise = TerrainGenerator.integerNoiseStatic(
                    seed: Self.grassSeedOffset,
                    x: worldSample,
                    octaves: 1
                )

                // Place ~60% of possible blades (noise > 100 out of 255)
                if noise > 100 {
                    let bladeHeight = 0.8
                        + CGFloat(noise) / 255.0 * 1.0  // 0.8-1.8pt
                    path.move(to: CGPoint(x: x, y: terrainY))
                    path.addLine(to: CGPoint(x: x, y: terrainY + bladeHeight))
                    hasContent = true
                }

                x += spacing
            }
        }

        guard hasContent else { return nil }

        let node = SKShapeNode(path: path)
        node.fillColor = .clear
        node.strokeColor = PushlingPalette.bone
            .withAlphaComponent(config.contourAlpha)
        node.lineWidth = 0.5
        node.name = "terrain_detail"
        node.zPosition = -0.5

        return node
    }
}
