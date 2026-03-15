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

    /// Permutation table for integer noise (512 entries, doubled and seeded).
    private let perm: [UInt8]

    /// The seed used for hash noise mixing.
    private let seedValue: UInt64

    /// Cached terrain chunks, keyed by chunk index.
    private var chunkCache: [Int: TerrainChunk] = [:]

    /// Reference to biome manager for height amplitude modifiers.
    weak var biomeManager: BiomeManager?

    // MARK: - Initialization

    /// Creates a terrain generator with the given seed.
    /// - Parameter seed: Deterministic seed (from creature birth hash).
    init(seed: UInt64) {
        self.seed = seed
        self.seedValue = seed
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

        // Interpolate between this sample and the next for smooth sub-sample terrain
        let currentHeight = chunk.heights[clampedSample]

        // Get next sample (may be in the next chunk)
        let nextHeight: CGFloat
        if clampedSample < Self.samplesPerChunk - 1 {
            nextHeight = chunk.heights[clampedSample + 1]
        } else {
            // Cross chunk boundary — get first sample of next chunk
            let nextChunk = ensureChunk(at: chunkIndex + 1)
            nextHeight = nextChunk.heights[0]
        }

        // Sub-sample fractional interpolation
        let exactSample = (worldX - CGFloat(chunkIndex) * Self.chunkWorldWidth) / Self.pointsPerSample
        let frac = exactSample - floor(exactSample)
        let interpolated = currentHeight * (1.0 - frac) + nextHeight * frac

        return Self.baselineY + interpolated
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

        // Smooth pass: limit max height change between adjacent samples.
        // This prevents sharp cliffs at biome transitions (e.g., wetlands 0.2
        // amplitude suddenly jumping to mountains 2.5 amplitude).
        // Max slope: 1.0pt per sample (= 0.5pt per world-point).
        let maxSlopePerSample: CGFloat = 1.0
        for s in 1..<Self.samplesPerChunk {
            let diff = heights[s] - heights[s - 1]
            if diff > maxSlopePerSample {
                heights[s] = heights[s - 1] + maxSlopePerSample
            } else if diff < -maxSlopePerSample {
                heights[s] = heights[s - 1] - maxSlopePerSample
            }
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

    // MARK: - Background Terrain Generation

    /// Generates height samples for a background terrain chunk.
    /// Uses a different seed offset for decorrelation from the foreground.
    ///
    /// - Parameters:
    ///   - chunkIndex: The chunk index in background-layer sample space.
    ///   - sampleCount: Number of height samples to generate.
    ///   - octaves: Noise octaves (far: 1 for smooth, mid: 2 for moderate detail).
    ///   - amplitudeScale: Height multiplier (far: 1.5 for taller peaks, mid: 1.0).
    ///   - seedOffset: XOR offset for decorrelation (far: 0xFAR0_FACE, mid: 0xBEEF_MID0).
    /// - Returns: Array of height values (0 to maxHeight * amplitudeScale).
    func generateBackgroundHeights(chunkIndex: Int,
                                    sampleCount: Int,
                                    octaves: Int,
                                    amplitudeScale: CGFloat,
                                    seedOffset: UInt64) -> [CGFloat] {
        var heights = [CGFloat](repeating: 0, count: sampleCount)
        let offsetSeed = seed ^ seedOffset

        for s in 0..<sampleCount {
            let worldSample = chunkIndex * sampleCount + s
            let noise = Self.integerNoiseStatic(
                seed: offsetSeed, x: worldSample, octaves: octaves
            )
            let normalizedNoise = CGFloat(noise) / 255.0
            heights[s] = normalizedNoise * Self.maxHeight * amplitudeScale
        }

        return heights
    }

    // MARK: - Integer Noise

    /// Static multi-octave integer noise using a seed directly.
    /// Used by background terrain generation with different seed offsets.
    /// - Returns: Noise value 0-255.
    static func integerNoiseStatic(seed: UInt64, x: Int, octaves: Int) -> Int {
        var total: Int = 0
        var maxValue: Int = 0
        var amplitude: Int = 128
        var frequency: Int = 1

        for _ in 0..<octaves {
            let sample = x / max(1, 16 / frequency)
            let n = hashNoiseStatic(seed: seed, x: sample)
            let nextN = hashNoiseStatic(seed: seed, x: sample + 1)

            let frac = (x * frequency) & 15
            let interpolated = (n * (16 - frac) + nextN * frac) / 16

            total += interpolated * amplitude / 256
            maxValue += amplitude

            amplitude /= 2
            frequency *= 2
        }

        return max(0, min(255, total * 255 / max(1, maxValue)))
    }

    /// Static hash noise for a given seed and position. Returns 0-255.
    private static func hashNoiseStatic(seed: UInt64, x: Int) -> Int {
        var h = UInt64(bitPattern: Int64(x)) &* 6364136223846793005
        h = h ^ seed
        h = h &* 2862933555777941757 &+ 3037000493
        h = h ^ (h >> 27)
        h = h &* 2685821657736338717
        return Int((h >> 56) & 0xFF)
    }

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

    /// Single-sample integer hash noise. Returns 0-255.
    /// Uses a combination of seed XOR and bit mixing to avoid periodic boundaries.
    /// Two adjacent inputs (x and x+1) produce smoothly-unrelated values that
    /// the interpolation step blends — no seams at any boundary.
    private func hashNoise(_ x: Int) -> Int {
        // Mix the input with the seed to get a unique hash per seed
        var h = UInt64(bitPattern: Int64(x)) &* 6364136223846793005
        h = h ^ seedValue
        h = h &* 2862933555777941757 &+ 3037000493
        h = h ^ (h >> 27)
        h = h &* 2685821657736338717
        return Int((h >> 56) & 0xFF)  // Top 8 bits → 0-255
    }

    // MARK: - Permutation Table

    /// Builds a seeded permutation table (Fisher-Yates shuffle), DOUBLED to 512.
    /// Doubling ensures perm[255] and perm[256] are continuous (perm[256] == perm[0]).
    private static func buildPermutationTable(seed: UInt64) -> [UInt8] {
        var table = (0..<256).map { UInt8($0) }
        var rng = seed

        // Fisher-Yates shuffle with simple LCG
        for i in stride(from: 255, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            table.swapAt(i, j)
        }

        // Double the table: perm[256+i] == perm[i]
        // This eliminates the seam at the 256 boundary
        table.append(contentsOf: table)

        return table
    }
}
