// WorldManager+DepthTerrain.swift — Depth-interpolated terrain height queries
// Allows the creature to walk on background terrain at any Z depth.
// Interpolates between foreground, mid, and far layer terrain heights
// based on the creature's Z position (0.0 = foreground, 1.0 = background).

import CoreGraphics

extension WorldManager {

    // MARK: - Depth Zone Constants

    /// Z boundaries between terrain layers.
    private static let midZoneStart: CGFloat = 0.3   // Fore → Mid transition begins
    private static let farZoneStart: CGFloat = 0.7   // Mid → Far transition begins

    /// Background layer scroll factors (must match ParallaxSystem/TerrainRecycler).
    private static let midScrollFactor: CGFloat = 0.4
    private static let farScrollFactor: CGFloat = 0.15

    /// Background layer X offsets (must match TerrainRecycler).
    private static let midXOffset: CGFloat = 25.0
    private static let farXOffset: CGFloat = 50.0

    /// Background layer noise parameters (must match TerrainRecycler BGLayerConfig).
    private static let midSeedOffset: UInt64 = 0xBEEF_0000
    private static let farSeedOffset: UInt64 = 0xFA20_FACE
    private static let midOctaves: Int = 2
    private static let farOctaves: Int = 1
    private static let midAmplitude: CGFloat = 1.0
    private static let farAmplitude: CGFloat = 1.5
    private static let midSamplesPerChunk: Int = 256
    private static let farSamplesPerChunk: Int = 128
    private static let midPointsPerSample: CGFloat = 2.0
    private static let farPointsPerSample: CGFloat = 4.0

    // MARK: - Public API

    /// Returns the terrain height at a given world-X and depth Z.
    /// Interpolates between foreground, mid, and far terrain layers
    /// based on the Z position.
    ///
    /// - Parameters:
    ///   - worldX: The creature's world-space X coordinate.
    ///   - depth: The creature's Z position (0.0 = foreground, 1.0 = far background).
    /// - Returns: The Y position of the terrain surface at that depth.
    func terrainHeightAtDepth(worldX: CGFloat, depth: CGFloat) -> CGFloat {
        guard let generator = terrainGenerator else {
            return TerrainGenerator.baselineY
        }

        // Zone 1: Pure foreground (Z 0.0 - 0.3)
        if depth <= Self.midZoneStart {
            return generator.heightAt(worldX: worldX)
        }

        let foreHeight = generator.heightAt(worldX: worldX)

        // Convert worldX to mid-layer coordinate space
        let midWorldX = worldX * Self.midScrollFactor + Self.midXOffset
        let midHeight = backgroundHeightAt(
            generator: generator,
            worldX: midWorldX,
            samplesPerChunk: Self.midSamplesPerChunk,
            pointsPerSample: Self.midPointsPerSample,
            octaves: Self.midOctaves,
            amplitudeScale: Self.midAmplitude,
            seedOffset: Self.midSeedOffset
        )

        // Zone 2: Fore ↔ Mid interpolation (Z 0.3 - 0.7)
        if depth <= Self.farZoneStart {
            let t = (depth - Self.midZoneStart) / (Self.farZoneStart - Self.midZoneStart)
            return lerp(foreHeight, midHeight, CGFloat(t))
        }

        // Convert worldX to far-layer coordinate space
        let farWorldX = worldX * Self.farScrollFactor + Self.farXOffset
        let farHeight = backgroundHeightAt(
            generator: generator,
            worldX: farWorldX,
            samplesPerChunk: Self.farSamplesPerChunk,
            pointsPerSample: Self.farPointsPerSample,
            octaves: Self.farOctaves,
            amplitudeScale: Self.farAmplitude,
            seedOffset: Self.farSeedOffset
        )

        // Zone 3: Mid ↔ Far interpolation (Z 0.7 - 1.0)
        let t = (depth - Self.farZoneStart) / (1.0 - Self.farZoneStart)
        return lerp(midHeight, farHeight, CGFloat(t))
    }

    // MARK: - Background Height Point Query

    /// Computes a single terrain height for a background layer at a given world-X.
    /// Reuses the same `integerNoiseStatic` function used by TerrainGenerator
    /// for background chunk generation, ensuring visual consistency.
    private func backgroundHeightAt(
        generator: TerrainGenerator,
        worldX: CGFloat,
        samplesPerChunk: Int,
        pointsPerSample: CGFloat,
        octaves: Int,
        amplitudeScale: CGFloat,
        seedOffset: UInt64
    ) -> CGFloat {
        // Determine which sample we're at in the background layer's space
        let exactSample = worldX / pointsPerSample
        let sampleIndex = Int(floor(exactSample))
        let frac = exactSample - floor(exactSample)

        let offsetSeed = generator.seed ^ seedOffset

        // Sample current and next for linear interpolation
        let noise0 = TerrainGenerator.integerNoiseStatic(
            seed: offsetSeed, x: sampleIndex, octaves: octaves
        )
        let noise1 = TerrainGenerator.integerNoiseStatic(
            seed: offsetSeed, x: sampleIndex + 1, octaves: octaves
        )

        let h0 = CGFloat(noise0) / 255.0 * TerrainGenerator.maxHeight * amplitudeScale
        let h1 = CGFloat(noise1) / 255.0 * TerrainGenerator.maxHeight * amplitudeScale

        let interpolated = h0 * (1.0 - frac) + h1 * frac
        return TerrainGenerator.baselineY + interpolated
    }
}
