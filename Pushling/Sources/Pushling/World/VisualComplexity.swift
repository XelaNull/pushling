// VisualComplexity.swift — Stage-gated world richness controller
// P3-T3-03: World visual complexity scales with creature growth stage.
//
// Spore = sparse void. Drop = first hints. Critter = day/night, trees.
// Beast = full biomes, weather, landmarks. Sage = magic, NPCs, particles.
// Apex = cosmic, stars respond, terrain glows.
//
// The controller provides per-system gate checks and configuration values.
// Systems query the controller to determine their allowed complexity level.

import SpriteKit

// MARK: - Complexity Level

/// The complexity tier corresponding to each growth stage.
/// Systems use this to decide what features to enable.
enum ComplexityLevel: Int, Comparable {
    case void = 0       // Spore — near-empty
    case emerging = 1   // Drop — ground visible, first plants
    case alive = 2      // Critter — trees, day/night, 2 biomes
    case thriving = 3   // Beast — full biomes, weather, landmarks
    case magical = 4    // Sage — particles, magic effects, NPCs
    case cosmic = 5     // Apex — stars respond, terrain glows

    static func < (lhs: ComplexityLevel, rhs: ComplexityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Map a GrowthStage to its complexity level.
    static func from(stage: GrowthStage) -> ComplexityLevel {
        switch stage {
        case .spore:   return .void
        case .drop:    return .emerging
        case .critter: return .alive
        case .beast:   return .thriving
        case .sage:    return .magical
        case .apex:    return .cosmic
        }
    }
}

// MARK: - Terrain Object Limits

/// Configuration for terrain object density at each complexity level.
struct TerrainObjectConfig {
    /// Maximum objects visible at once.
    let maxObjects: Int
    /// Allowed object types (gates which terrain objects can spawn).
    let allowedTypes: Set<TerrainObjectType>
    /// Ground line alpha (how visible the ground is).
    let groundAlpha: CGFloat
    /// Ground color — shifts from Ash to biome color as complexity increases.
    let groundColorBlendFactor: CGFloat
}

// MARK: - Star Field Config

/// Configuration for star field at each complexity level.
struct StarFieldConfig {
    /// Maximum visible stars.
    let maxStars: Int
    /// Star base alpha multiplier.
    let alphaMultiplier: CGFloat
    /// Whether stars respond to creature proximity (Apex only).
    let reactsToCreature: Bool
}

// MARK: - Weather Config

/// Configuration for weather at each complexity level.
struct WeatherConfig {
    /// Whether the weather state machine runs.
    let enabled: Bool
    /// Allowed weather states.
    let allowedStates: Set<WeatherState>
}

// MARK: - Biome Config

/// Configuration for biome system at each complexity level.
struct BiomeConfig {
    /// Number of distinct biomes that appear.
    let biomesAvailable: Int
    /// Whether biome gradient transitions render.
    let transitionsEnabled: Bool
}

// MARK: - Fog of War Config

/// Configuration for the fog of war system at each complexity level.
/// Controls visibility radius, gradient softness, and explored area behavior.
struct FogOfWarConfig {
    /// Points of clear visibility around the creature.
    let visibilityRadius: CGFloat
    /// Soft falloff width from clear to opaque.
    let edgeGradientWidth: CGFloat
    /// How visible explored-but-distant areas are (0 = invisible, 1 = fully visible).
    let exploredAlpha: CGFloat
    /// Whether explored areas stay partially visible.
    let exploredEnabled: Bool
}

// MARK: - Terrain Texture Config

/// Configuration for terrain texture detail overlays at each complexity level.
/// Controls valley shadows, hilltop highlights, contour lines, and micro-detail grass blades.
struct TerrainTextureConfig {
    /// Alpha of valley/slope shadow overlay (0 = disabled).
    let shadowAlpha: CGFloat
    /// Alpha of hilltop highlight overlay (0 = disabled).
    let highlightAlpha: CGFloat
    /// Number of contour lines (0-3).
    let contourLineCount: Int
    /// Alpha of contour line and micro-detail strokes.
    let contourAlpha: CGFloat
    /// Points between micro-detail grass blades (0 = disabled).
    let microDetailSpacing: CGFloat
    /// Whether steep slopes receive shadow even at mid-height.
    let slopeShadingEnabled: Bool
}

// MARK: - Visual Complexity Controller

/// Gates world features based on creature growth stage.
/// The scene or world manager queries this controller each time the stage changes.
/// Per-frame queries use cached values — no per-frame overhead.
final class VisualComplexityController {

    // MARK: - Current State

    /// The current complexity level (derived from creature stage).
    private(set) var level: ComplexityLevel = .void

    /// The current creature stage.
    private(set) var stage: GrowthStage = .spore

    // MARK: - Cached Configurations

    private(set) var terrainConfig: TerrainObjectConfig = TerrainObjectConfig(
        maxObjects: 0, allowedTypes: [], groundAlpha: 0.3, groundColorBlendFactor: 0.0
    )
    private(set) var starConfig: StarFieldConfig = StarFieldConfig(
        maxStars: 3, alphaMultiplier: 0.3, reactsToCreature: false
    )
    private(set) var weatherConfig: WeatherConfig = WeatherConfig(
        enabled: false, allowedStates: [.clear]
    )
    private(set) var biomeConfig: BiomeConfig = BiomeConfig(
        biomesAvailable: 0, transitionsEnabled: false
    )
    private(set) var fogOfWarConfig: FogOfWarConfig = FogOfWarConfig(
        visibilityRadius: 40, edgeGradientWidth: 20, exploredAlpha: 0.7, exploredEnabled: true
    )
    private(set) var terrainTextureConfig: TerrainTextureConfig = TerrainTextureConfig(
        shadowAlpha: 0, highlightAlpha: 0, contourLineCount: 0,
        contourAlpha: 0, microDetailSpacing: 0, slopeShadingEnabled: false
    )

    // MARK: - Feature Gates (Convenience)

    /// Whether the day/night cycle is active.
    var dayNightEnabled: Bool { level >= .alive }

    /// Whether parallax is fully active (all 3 layers rendered).
    var fullParallaxEnabled: Bool { level >= .thriving }

    /// Whether repo landmarks are visible.
    var landmarksVisible: Bool { level >= .thriving }

    /// Whether magic ambient effects (floating motes) appear.
    var magicEffectsEnabled: Bool { level >= .magical }

    /// Whether the ghost echo can appear.
    var ghostEchoEnabled: Bool { level >= .magical }

    /// Whether terrain near creature glows faintly.
    var terrainGlowEnabled: Bool { level >= .cosmic }

    /// Whether puddle reflections render.
    var puddleReflectionsEnabled: Bool { level >= .alive }

    /// Whether ruin inscriptions can be read.
    var ruinInscriptionsEnabled: Bool { level >= .thriving }

    /// Whether visual event spectacles can be triggered.
    var visualEventsEnabled: Bool { level >= .alive }

    // MARK: - Update

    /// Update the complexity level when the creature stage changes.
    /// Call this whenever `creature.stage` changes (evolution, state restore).
    /// - Parameter newStage: The creature's current growth stage.
    func updateStage(_ newStage: GrowthStage) {
        stage = newStage
        level = ComplexityLevel.from(stage: newStage)

        // Update cached configs
        terrainConfig = Self.terrainConfigs[level]!
        starConfig = Self.starConfigs[level]!
        weatherConfig = Self.weatherConfigs[level]!
        biomeConfig = Self.biomeConfigs[level]!
        fogOfWarConfig = Self.fogOfWarConfigs[level]!
        terrainTextureConfig = Self.terrainTextureConfigs[level]!

        NSLog("[Pushling/Complexity] Stage -> %@, complexity -> %d",
              "\(newStage)", level.rawValue)
    }

    // MARK: - Configuration Tables

    /// Terrain object configuration per complexity level.
    private static let terrainConfigs: [ComplexityLevel: TerrainObjectConfig] = [
        .void: TerrainObjectConfig(
            maxObjects: 0,
            allowedTypes: [],
            groundAlpha: 0.3,
            groundColorBlendFactor: 0.0
        ),
        .emerging: TerrainObjectConfig(
            maxObjects: 4,
            allowedTypes: [.grassTuft, .flower, .rock],
            groundAlpha: 0.6,
            groundColorBlendFactor: 0.2
        ),
        .alive: TerrainObjectConfig(
            maxObjects: 10,
            allowedTypes: [.grassTuft, .flower, .tree, .mushroom, .rock,
                           .waterPuddle],
            groundAlpha: 0.8,
            groundColorBlendFactor: 0.6
        ),
        .thriving: TerrainObjectConfig(
            maxObjects: 14,
            allowedTypes: Set(TerrainObjectType.allCases),
            groundAlpha: 1.0,
            groundColorBlendFactor: 1.0
        ),
        .magical: TerrainObjectConfig(
            maxObjects: 14,
            allowedTypes: Set(TerrainObjectType.allCases),
            groundAlpha: 1.0,
            groundColorBlendFactor: 1.0
        ),
        .cosmic: TerrainObjectConfig(
            maxObjects: 14,
            allowedTypes: Set(TerrainObjectType.allCases),
            groundAlpha: 1.0,
            groundColorBlendFactor: 1.0
        ),
    ]

    /// Star field configuration per complexity level.
    private static let starConfigs: [ComplexityLevel: StarFieldConfig] = [
        .void: StarFieldConfig(
            maxStars: 3,
            alphaMultiplier: 0.3,
            reactsToCreature: false
        ),
        .emerging: StarFieldConfig(
            maxStars: 10,
            alphaMultiplier: 0.5,
            reactsToCreature: false
        ),
        .alive: StarFieldConfig(
            maxStars: 18,
            alphaMultiplier: 0.8,
            reactsToCreature: false
        ),
        .thriving: StarFieldConfig(
            maxStars: 25,
            alphaMultiplier: 1.0,
            reactsToCreature: false
        ),
        .magical: StarFieldConfig(
            maxStars: 25,
            alphaMultiplier: 1.0,
            reactsToCreature: false
        ),
        .cosmic: StarFieldConfig(
            maxStars: 25,
            alphaMultiplier: 1.0,
            reactsToCreature: true
        ),
    ]

    /// Weather configuration per complexity level.
    private static let weatherConfigs: [ComplexityLevel: WeatherConfig] = [
        .void: WeatherConfig(
            enabled: false,
            allowedStates: [.clear]
        ),
        .emerging: WeatherConfig(
            enabled: false,
            allowedStates: [.clear]
        ),
        .alive: WeatherConfig(
            enabled: true,
            allowedStates: [.clear, .cloudy]
        ),
        .thriving: WeatherConfig(
            enabled: true,
            allowedStates: Set(WeatherState.allCases)
        ),
        .magical: WeatherConfig(
            enabled: true,
            allowedStates: Set(WeatherState.allCases)
        ),
        .cosmic: WeatherConfig(
            enabled: true,
            allowedStates: Set(WeatherState.allCases)
        ),
    ]

    /// Biome configuration per complexity level.
    private static let biomeConfigs: [ComplexityLevel: BiomeConfig] = [
        .void: BiomeConfig(biomesAvailable: 0, transitionsEnabled: false),
        .emerging: BiomeConfig(biomesAvailable: 1, transitionsEnabled: false),
        .alive: BiomeConfig(biomesAvailable: 2, transitionsEnabled: true),
        .thriving: BiomeConfig(biomesAvailable: 5, transitionsEnabled: true),
        .magical: BiomeConfig(biomesAvailable: 5, transitionsEnabled: true),
        .cosmic: BiomeConfig(biomesAvailable: 5, transitionsEnabled: true),
    ]

    /// Fog of war configuration per complexity level.
    /// Spore: tiny peephole into OLED darkness. Apex: full visibility.
    private static let fogOfWarConfigs: [ComplexityLevel: FogOfWarConfig] = [
        .void: FogOfWarConfig(
            visibilityRadius: 40, edgeGradientWidth: 20,
            exploredAlpha: 0.7, exploredEnabled: true
        ),
        .emerging: FogOfWarConfig(
            visibilityRadius: 100, edgeGradientWidth: 40,
            exploredAlpha: 0.25, exploredEnabled: true
        ),
        .alive: FogOfWarConfig(
            visibilityRadius: 200, edgeGradientWidth: 60,
            exploredAlpha: 0.45, exploredEnabled: true
        ),
        .thriving: FogOfWarConfig(
            visibilityRadius: 400, edgeGradientWidth: 80,
            exploredAlpha: 0.65, exploredEnabled: true
        ),
        .magical: FogOfWarConfig(
            visibilityRadius: 600, edgeGradientWidth: 100,
            exploredAlpha: 0.85, exploredEnabled: true
        ),
        .cosmic: FogOfWarConfig(
            visibilityRadius: 1200, edgeGradientWidth: 0,
            exploredAlpha: 1.0, exploredEnabled: true
        ),
    ]

    /// Terrain texture detail configuration per complexity level.
    /// Spore = nothing. Drop = faint shadows. Critter = contours + sparse grass.
    /// Beast+ = full detail with slope shading.
    private static let terrainTextureConfigs: [ComplexityLevel: TerrainTextureConfig] = [
        .void: TerrainTextureConfig(
            shadowAlpha: 0, highlightAlpha: 0, contourLineCount: 0,
            contourAlpha: 0, microDetailSpacing: 0, slopeShadingEnabled: false
        ),
        .emerging: TerrainTextureConfig(
            shadowAlpha: 0.10, highlightAlpha: 0.08, contourLineCount: 0,
            contourAlpha: 0, microDetailSpacing: 0, slopeShadingEnabled: false
        ),
        .alive: TerrainTextureConfig(
            shadowAlpha: 0.15, highlightAlpha: 0.12, contourLineCount: 1,
            contourAlpha: 0.15, microDetailSpacing: 16, slopeShadingEnabled: false
        ),
        .thriving: TerrainTextureConfig(
            shadowAlpha: 0.20, highlightAlpha: 0.15, contourLineCount: 2,
            contourAlpha: 0.18, microDetailSpacing: 10, slopeShadingEnabled: true
        ),
        .magical: TerrainTextureConfig(
            shadowAlpha: 0.25, highlightAlpha: 0.18, contourLineCount: 3,
            contourAlpha: 0.22, microDetailSpacing: 8, slopeShadingEnabled: true
        ),
        .cosmic: TerrainTextureConfig(
            shadowAlpha: 0.25, highlightAlpha: 0.18, contourLineCount: 3,
            contourAlpha: 0.22, microDetailSpacing: 8, slopeShadingEnabled: true
        ),
    ]
}
