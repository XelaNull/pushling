// BiomeManager.swift — 5-biome system with 50-unit gradient transitions
// Biomes: plains, forest, desert, wetlands, mountains.
// Uses a second noise layer at 1/10th terrain frequency for biome boundaries.
// Biome transitions blend ground color, object pools, and height amplitude
// across a 50-unit gradient zone.
//
// Performance target: O(1) biome lookup from cached data.

import SpriteKit

// MARK: - Biome Type

/// The five terrain biomes in the Pushling world.
enum BiomeType: String, CaseIterable {
    case plains
    case forest
    case desert
    case wetlands
    case mountains

    /// The primary ground color tint for this biome.
    var groundTint: SKColor {
        switch self {
        case .plains:    return PushlingPalette.moss
        case .forest:    return deepMoss
        case .desert:    return PushlingPalette.ember
        case .wetlands:  return PushlingPalette.tide
        case .mountains: return PushlingPalette.ash
        }
    }

    /// Height amplitude modifier — controls how hilly the terrain is.
    var heightAmplitude: CGFloat {
        switch self {
        case .plains:    return 0.3
        case .forest:    return 0.7
        case .desert:    return 0.5
        case .wetlands:  return 0.2
        case .mountains: return 2.5
        }
    }

    /// Average object density (objects per 100pt of terrain).
    var objectDensity: CGFloat {
        switch self {
        case .plains:    return 1.2
        case .forest:    return 1.6
        case .desert:    return 0.6
        case .wetlands:  return 1.0
        case .mountains: return 0.8
        }
    }

    /// Deep Moss — a darker variant of Moss for forest canopy feel.
    private var deepMoss: SKColor {
        SKColor(displayP3Red: 0.0, green: 0.65, blue: 0.25, alpha: 1.0)
    }
}

// MARK: - Biome Blend

/// Represents a blended biome state at a specific world position.
/// During transitions, two biomes blend with an interpolation factor.
struct BiomeBlend {
    let primary: BiomeType
    let secondary: BiomeType?
    let blendFactor: CGFloat    // 0.0 = pure primary, 1.0 = pure secondary

    /// Returns the blended ground color.
    var groundColor: SKColor {
        guard let sec = secondary, blendFactor > 0.001 else {
            return primary.groundTint
        }
        return PushlingPalette.lerp(
            from: primary.groundTint,
            to: sec.groundTint,
            t: blendFactor
        )
    }

    /// Returns the blended height amplitude.
    var heightAmplitude: CGFloat {
        guard let sec = secondary, blendFactor > 0.001 else {
            return primary.heightAmplitude
        }
        return primary.heightAmplitude * (1.0 - blendFactor)
            + sec.heightAmplitude * blendFactor
    }

    /// Whether we are in a transition zone.
    var isTransition: Bool {
        secondary != nil && blendFactor > 0.001 && blendFactor < 0.999
    }
}

// MARK: - BiomeManager

/// Manages biome determination and blending across the infinite world.
/// Uses a low-frequency noise layer to assign biome types to regions,
/// with 50-unit gradient transitions between them.
final class BiomeManager {

    // MARK: - Constants

    /// Width of a biome region in world-space points (before transition).
    static let biomeRegionWidth: CGFloat = 800

    /// Width of the gradient transition zone between biomes.
    static let transitionWidth: CGFloat = 50

    /// Half the transition width — used for boundary calculations.
    private static let halfTransition: CGFloat = transitionWidth / 2.0

    // MARK: - Properties

    /// Seed for biome noise (derived from world seed).
    private let seed: UInt64

    /// Permutation table for biome noise.
    private let biomePerm: [UInt8]

    // MARK: - Initialization

    init(seed: UInt64) {
        // Use a different seed offset for biome noise to decorrelate from terrain
        self.seed = seed &+ 0xDEAD_BEEF_CAFE_1234
        self.biomePerm = Self.buildBiomePerm(seed: self.seed)
    }

    // MARK: - Biome Queries

    /// Returns the primary biome type at a given world-X position.
    /// This is the "pure" biome ignoring transitions.
    func biomeAt(worldX: CGFloat) -> BiomeType {
        let regionIndex = biomeRegionIndex(at: worldX)
        return biomeForRegion(regionIndex)
    }

    /// Returns the full biome blend state at a given world-X position,
    /// including transition blending with neighboring biomes.
    func biomeBlendAt(worldX: CGFloat) -> BiomeBlend {
        let regionWidth = Self.biomeRegionWidth
        let halfTrans = Self.halfTransition

        // Which region are we in?
        let regionIndex = biomeRegionIndex(at: worldX)
        let regionStart = CGFloat(regionIndex) * regionWidth
        let regionEnd = regionStart + regionWidth
        let localX = worldX - regionStart

        let primaryBiome = biomeForRegion(regionIndex)

        // Check if we're in the left transition zone
        if localX < halfTrans {
            let prevBiome = biomeForRegion(regionIndex - 1)
            if prevBiome != primaryBiome {
                let t = localX / Self.transitionWidth + 0.5
                return BiomeBlend(
                    primary: prevBiome,
                    secondary: primaryBiome,
                    blendFactor: t
                )
            }
        }

        // Check if we're in the right transition zone
        let distToEnd = regionEnd - worldX
        if distToEnd < halfTrans {
            let nextBiome = biomeForRegion(regionIndex + 1)
            if nextBiome != primaryBiome {
                let t = 1.0 - (distToEnd / Self.transitionWidth + 0.5)
                return BiomeBlend(
                    primary: primaryBiome,
                    secondary: nextBiome,
                    blendFactor: max(0, t)
                )
            }
        }

        // Pure biome — no transition
        return BiomeBlend(primary: primaryBiome, secondary: nil, blendFactor: 0)
    }

    /// Returns the height amplitude at a world-X position, accounting
    /// for biome blending in transition zones.
    func heightAmplitude(at worldX: CGFloat) -> CGFloat {
        return biomeBlendAt(worldX: worldX).heightAmplitude
    }

    /// Returns the blended ground color at a world-X position.
    func groundColor(at worldX: CGFloat) -> SKColor {
        return biomeBlendAt(worldX: worldX).groundColor
    }

    // MARK: - Private: Region & Noise

    /// Returns the biome region index for a world-X position.
    private func biomeRegionIndex(at worldX: CGFloat) -> Int {
        return Int(floor(worldX / Self.biomeRegionWidth))
    }

    /// Deterministically maps a region index to a BiomeType.
    /// Uses permutation-table hashing for pseudo-random but repeatable results.
    private func biomeForRegion(_ regionIndex: Int) -> BiomeType {
        let biomes = BiomeType.allCases
        let hash = biomeHash(regionIndex)
        return biomes[hash % biomes.count]
    }

    /// Integer hash for a region index using the biome permutation table.
    private func biomeHash(_ index: Int) -> Int {
        // Handle negative indices
        let wrapped = ((index % 256) + 256) % 256
        let h1 = Int(biomePerm[wrapped])
        let h2 = Int(biomePerm[(h1 + 137) % 256])
        return (h1 ^ h2) % BiomeType.allCases.count
    }

    // MARK: - Private: Permutation Table

    private static func buildBiomePerm(seed: UInt64) -> [UInt8] {
        var table = (0..<256).map { UInt8($0) }
        var rng = seed

        for i in stride(from: 255, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            table.swapAt(i, j)
        }

        return table
    }
}
