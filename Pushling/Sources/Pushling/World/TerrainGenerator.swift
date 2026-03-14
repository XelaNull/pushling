// TerrainGenerator.swift — Procedural terrain heightmap from integer noise
// Generates deterministic rolling hills from a seed value.
// Heightmap resolution: 1 sample per 2pt horizontal.
// Height range: 0-8pt above baseline (baseline at Y=4pt from bottom).
// Terrain extends infinitely; generated on demand in 256-sample chunks.
//
// Uses a simple integer hash (no floating-point) for cross-platform determinism.
// Performance target: <0.2ms per chunk generation.

import SpriteKit

// MARK: - Terrain Chunk

/// A cached segment of terrain heightmap data.
/// Each chunk covers 256 samples = 512pt of world space.
struct TerrainChunk {
    /// The chunk index (chunkIndex * chunkWorldWidth = world-X start).
    let index: Int

    /// Height samples (256 values, each 0-8pt above baseline).
    let heights: [CGFloat]

    /// The biome type at the chunk center (for fast lookup).
    var biomeType: BiomeType = .plains

    /// World-X start position of this chunk.
    var worldXStart: CGFloat {
        CGFloat(index) * TerrainGenerator.chunkWorldWidth
    }

    /// World-X end position of this chunk.
    var worldXEnd: CGFloat {
        worldXStart + TerrainGenerator.chunkWorldWidth
    }
}

// MARK: - TerrainGenerator

/// Generates procedural terrain using seed-based integer noise.
/// Heightmap is cached in chunks and evicted when far from the camera.
final class TerrainGenerator {

    // MARK: - Constants

    /// Samples per chunk. Each sample covers 2pt horizontally.
    static let samplesPerChunk: Int = 256

    /// Points per sample (heightmap resolution).
    static let pointsPerSample: CGFloat = 2.0

    /// World-space width of one chunk.
    static let chunkWorldWidth: CGFloat = CGFloat(samplesPerChunk) * pointsPerSample

    /// Baseline Y position (bottom of terrain hills).
    static let baselineY: CGFloat = 4.0

    /// Maximum height above baseline.
    static let maxHeight: CGFloat = 8.0

    /// Maximum cached chunks (evict beyond this).
    static let maxCachedChunks: Int = 12

    /// Eviction distance: chunks > this many viewports away are removed.
    static let evictionViewports: CGFloat = 3.0

    // MARK: - Properties

    /// The world seed — deterministic per machine.
    let seed: UInt64

    /// Permutation table for integer noise (256 entries, seeded).
    private let perm: [UInt8]

    /// Cached terrain chunks, keyed by chunk index.
    private var chunkCache: [Int: TerrainChunk] = [:]

    /// Reference to biome manager for height amplitude modifiers.
    weak var biomeManager: BiomeManager?

    // MARK: - Initialization

    /// Creates a terrain generator with the given seed.
    /// - Parameter seed: Deterministic seed (from creature birth hash).
    init(seed: UInt64) {
        self.seed = seed
        self.perm = Self.buildPermutationTable(seed: seed)
    }

    // MARK: - Heightmap Access

    /// Returns the terrain height at a given world-X position.
    /// Generates the containing chunk if not cached.
    ///
    /// - Parameter worldX: The world-space X coordinate.
    /// - Returns: The Y position of the terrain surface at that point.
    func heightAt(worldX: CGFloat) -> CGFloat {
        let chunkIndex = Self.chunkIndex(for: worldX)
        let chunk = ensureChunk(at: chunkIndex)
        let sampleIndex = Self.sampleIndex(worldX: worldX, chunkIndex: chunkIndex)
        let clampedSample = max(0, min(Self.samplesPerChunk - 1, sampleIndex))
        return Self.baselineY + chunk.heights[clampedSample]
    }

    /// Returns the terrain chunk containing the given world-X.
    /// Generates if not cached.
    func chunkAt(worldX: CGFloat) -> TerrainChunk {
        let index = Self.chunkIndex(for: worldX)
        return ensureChunk(at: index)
    }

    /// Returns the chunk at a given chunk index.
    func chunkAt(index: Int) -> TerrainChunk {
        return ensureChunk(at: index)
    }

    /// Returns all currently cached chunks.
    var cachedChunks: [Int: TerrainChunk] {
        chunkCache
    }

    // MARK: - Chunk Lifecycle

    /// Ensures chunks exist for the visible range plus padding.
    /// Call each frame to pre-generate ahead of the camera.
    ///
    /// - Parameters:
    ///   - centerWorldX: Camera center in world-space.
    ///   - padding: Extra world-space units to generate beyond viewport.
    func ensureChunksForRange(centerWorldX: CGFloat, padding: CGFloat = 200) {
        let halfView = ParallaxSystem.sceneWidth / 2.0
        let minX = centerWorldX - halfView - padding
        let maxX = centerWorldX + halfView + padding

        let minChunk = Self.chunkIndex(for: minX)
        let maxChunk = Self.chunkIndex(for: maxX)

        for i in minChunk...maxChunk {
            _ = ensureChunk(at: i)
        }
    }

    /// Evicts chunks that are too far from the camera.
    /// Call periodically (every ~30 frames) to keep memory bounded.
    ///
    /// - Parameter centerWorldX: Current camera world-X.
    func evictDistantChunks(centerWorldX: CGFloat) {
        let evictionDistance = ParallaxSystem.sceneWidth * Self.evictionViewports
        let minKeep = centerWorldX - evictionDistance
        let maxKeep = centerWorldX + evictionDistance

        let keysToRemove = chunkCache.keys.filter { index in
            let chunkStart = CGFloat(index) * Self.chunkWorldWidth
            let chunkEnd = chunkStart + Self.chunkWorldWidth
            return chunkEnd < minKeep || chunkStart > maxKeep
        }

        for key in keysToRemove {
            chunkCache.removeValue(forKey: key)
        }
    }

    // MARK: - Chunk Index Math

    /// Returns the chunk index for a world-X position.
    static func chunkIndex(for worldX: CGFloat) -> Int {
        return Int(floor(worldX / chunkWorldWidth))
    }

    /// Returns the sample index within a chunk for a world-X position.
    static func sampleIndex(worldX: CGFloat, chunkIndex: Int) -> Int {
        let localX = worldX - CGFloat(chunkIndex) * chunkWorldWidth
        return Int(localX / pointsPerSample)
    }

    // MARK: - Private: Chunk Generation

    /// Ensures a chunk exists at the given index, generating if needed.
    @discardableResult
    private func ensureChunk(at index: Int) -> TerrainChunk {
        if let cached = chunkCache[index] {
            return cached
        }

        let chunk = generateChunk(at: index)
        chunkCache[index] = chunk
        return chunk
    }

    /// Generates a new terrain chunk at the given index.
    private func generateChunk(at index: Int) -> TerrainChunk {
        var heights = [CGFloat](repeating: 0, count: Self.samplesPerChunk)

        for s in 0..<Self.samplesPerChunk {
            // World-space X for this sample
            let worldSample = index * Self.samplesPerChunk + s

            // Multi-octave integer noise for natural-looking terrain
            let noise = integerNoise(x: worldSample, octaves: 3)

            // Get biome amplitude modifier
            let worldX = CGFloat(worldSample) * Self.pointsPerSample
            let amplitude = biomeManager?.heightAmplitude(at: worldX) ?? 1.0

            // Map noise [0, 255] to height [0, maxHeight] with amplitude
            let normalizedNoise = CGFloat(noise) / 255.0
            heights[s] = normalizedNoise * Self.maxHeight * amplitude
        }

        // Determine biome at chunk center
        let centerWorldX = CGFloat(index) * Self.chunkWorldWidth
            + Self.chunkWorldWidth / 2.0
        let biome = biomeManager?.biomeAt(worldX: centerWorldX) ?? .plains

        return TerrainChunk(
            index: index,
            heights: heights,
            biomeType: biome
        )
    }

    // MARK: - Integer Noise

    /// Multi-octave integer noise.
    /// Returns a value in [0, 255].
    ///
    /// - Parameters:
    ///   - x: Integer position in sample space.
    ///   - octaves: Number of noise layers (each halves frequency, halves amplitude).
    /// - Returns: Noise value 0-255.
    private func integerNoise(x: Int, octaves: Int) -> Int {
        var total: Int = 0
        var maxValue: Int = 0
        var amplitude: Int = 128
        var frequency: Int = 1

        for _ in 0..<octaves {
            let sample = x / max(1, 16 / frequency)
            let n = hashNoise(sample)
            let nextN = hashNoise(sample + 1)

            // Integer linear interpolation
            let frac = (x * frequency) & 15  // 0-15 fractional part
            let interpolated = (n * (16 - frac) + nextN * frac) / 16

            total += interpolated * amplitude / 256
            maxValue += amplitude

            amplitude /= 2
            frequency *= 2
        }

        // Normalize to 0-255
        return max(0, min(255, total * 255 / max(1, maxValue)))
    }

    /// Single-sample integer hash noise using permutation table.
    /// Returns 0-255.
    private func hashNoise(_ x: Int) -> Int {
        // Handle negative indices by wrapping
        let wrapped = ((x % 256) + 256) % 256
        return Int(perm[wrapped])
    }

    // MARK: - Permutation Table

    /// Builds a seeded permutation table (Fisher-Yates shuffle).
    private static func buildPermutationTable(seed: UInt64) -> [UInt8] {
        var table = (0..<256).map { UInt8($0) }
        var rng = seed

        // Fisher-Yates shuffle with simple LCG
        for i in stride(from: 255, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            table.swapAt(i, j)
        }

        return table
    }
}
