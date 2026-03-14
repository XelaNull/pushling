// WorldManager.swift — World system orchestrator
// Owns all world subsystems: parallax, terrain, biomes, objects, landmarks, tinting.
// Called from PushlingScene's update loop.
// Manages chunk lifecycle, eviction timing, and subsystem coordination.
//
// The WorldManager is the single integration point between the scene and the
// world rendering system. The scene calls `setup()` once and `update()` per frame.

import SpriteKit

// MARK: - World Configuration

/// Configuration for the world system, typically read from SQLite on launch.
struct WorldConfig {
    /// Terrain seed (from creature birth hash). Deterministic per machine.
    var seed: UInt64 = 0x5075_484C_494E_4700

    /// Creature's language specialty (drives world tinting).
    var specialty: String = "polyglot"

    /// Known repo landmarks to load.
    var landmarks: [LandmarkData] = []

    /// Initial creature X position in world-space.
    var initialCreatureX: CGFloat = 542.5
}

// MARK: - WorldManager

/// Orchestrates the entire world rendering system.
/// The scene owns one WorldManager and delegates world updates to it.
final class WorldManager {

    // MARK: - Subsystems

    /// 3-layer parallax scrolling system.
    let parallax = ParallaxSystem()

    /// Procedural terrain heightmap generator.
    private(set) var terrainGenerator: TerrainGenerator!

    /// 5-biome system with gradient transitions.
    private(set) var biomeManager: BiomeManager!

    /// Terrain chunk visual lifecycle and object placement.
    private(set) var terrainRecycler: TerrainRecycler!

    /// Repo landmark system on the mid layer.
    private(set) var landmarkSystem: LandmarkSystem!

    /// Diet-influenced world tinting overlay.
    let worldTinting = WorldTinting()

    // NOTE: Sky and Weather systems are Phase 3 Track 2 deliverables.
    // They will be added here once implemented.

    // MARK: - State

    /// Current world-space X position of the tracked entity (creature/camera).
    private(set) var cameraWorldX: CGFloat = 542.5

    /// Frame counter for periodic maintenance (eviction, etc.).
    private var frameCounter: Int = 0

    /// Whether the world has been set up.
    private(set) var isSetUp = false

    /// The scene this world is attached to.
    private weak var scene: SKScene?

    // MARK: - Setup

    /// Initializes and attaches all world subsystems to the scene.
    /// Call once from `PushlingScene.didMove(to:)`.
    ///
    /// - Parameters:
    ///   - scene: The PushlingScene to render into.
    ///   - config: World configuration (seed, specialty, landmarks).
    func setup(scene: SKScene, config: WorldConfig = WorldConfig()) {
        self.scene = scene
        self.cameraWorldX = config.initialCreatureX

        // 1. Attach parallax layers to scene
        parallax.attach(to: scene)

        // 2. Create biome manager (needed by terrain generator)
        biomeManager = BiomeManager(seed: config.seed)

        // 3. Create terrain generator with biome reference
        terrainGenerator = TerrainGenerator(seed: config.seed)
        terrainGenerator.biomeManager = biomeManager

        // 4. Create terrain recycler on the foreground layer
        if let foreLayer = parallax.foreLayer {
            terrainRecycler = TerrainRecycler(
                terrainGenerator: terrainGenerator,
                biomeManager: biomeManager,
                foreLayer: foreLayer
            )
        }

        // 5. Create landmark system on the mid layer
        if let midLayer = parallax.midLayer {
            landmarkSystem = LandmarkSystem(midLayer: midLayer)
            landmarkSystem.loadLandmarks(config.landmarks)
        }

        // 6. Setup world tinting
        worldTinting.attach(to: scene)
        worldTinting.applyImmediate(config.specialty)

        // 7. Initial terrain generation around starting position
        terrainGenerator.ensureChunksForRange(centerWorldX: cameraWorldX)
        terrainRecycler?.update(cameraWorldX: cameraWorldX)

        // 8. Initial parallax update
        parallax.update(cameraWorldX: cameraWorldX)

        isSetUp = true
        NSLog("[Pushling/World] World system initialized — seed %llu, "
              + "specialty %@, %d landmarks",
              config.seed, config.specialty, config.landmarks.count)
    }

    // MARK: - Frame Update

    /// Main frame update — call from PushlingScene's update loop.
    /// Updates parallax, terrain recycling, and periodic maintenance.
    ///
    /// - Parameters:
    ///   - deltaTime: Time since last frame.
    ///   - trackedX: World-X position to center the camera on
    ///     (typically creature position).
    func update(deltaTime: TimeInterval, trackedX: CGFloat) {
        guard isSetUp else { return }

        cameraWorldX = trackedX
        frameCounter += 1

        // Update parallax layer positions (< 0.1ms)
        parallax.update(cameraWorldX: trackedX)

        // Update terrain recycler — generate/recycle chunks (< 0.2ms)
        terrainRecycler?.update(cameraWorldX: trackedX)

        // Periodic maintenance (every 30 frames ~ 0.5s at 60fps)
        if frameCounter % 30 == 0 {
            terrainGenerator.evictDistantChunks(centerWorldX: trackedX)
        }
    }

    // MARK: - World Queries

    /// Returns the terrain height at a world-X position.
    /// Useful for placing the creature on the ground.
    func terrainHeightAt(worldX: CGFloat) -> CGFloat {
        return terrainGenerator?.heightAt(worldX: worldX) ?? 4.0
    }

    /// Returns the current biome at a world-X position.
    func currentBiome(at worldX: CGFloat) -> BiomeType {
        return biomeManager?.biomeAt(worldX: worldX) ?? .plains
    }

    /// Returns the biome blend state at a world-X position.
    func biomeBlend(at worldX: CGFloat) -> BiomeBlend {
        return biomeManager?.biomeBlendAt(worldX: worldX)
            ?? BiomeBlend(primary: .plains, secondary: nil, blendFactor: 0)
    }

    /// Returns the nearest landmark to a world-X position.
    func nearestLandmark(to worldX: CGFloat) -> LandmarkData? {
        return landmarkSystem?.nearestLandmark(to: worldX)
    }

    /// Returns the total world node count (for debug overlay).
    var worldNodeCount: Int {
        let parallaxNodes = 3  // The three layer containers
        let terrainNodes = terrainRecycler?.activeNodeCount ?? 0
        let landmarkNodes = landmarkSystem?.landmarks.count ?? 0
        let tintNode = 1
        return parallaxNodes + terrainNodes + landmarkNodes + tintNode
    }

    // MARK: - Specialty Updates

    /// Updates the world tinting when the creature's specialty changes.
    /// Call from the state system when a commit shifts the specialty.
    func updateSpecialty(_ specialty: String) {
        worldTinting.updateSpecialty(specialty)
    }

    // MARK: - Landmark Management

    /// Adds a new repo landmark to the world.
    /// Call when a new repo is tracked.
    ///
    /// - Parameters:
    ///   - repoName: The repository name.
    ///   - repoPath: Path to the repo root (for type analysis).
    func addRepoLandmark(repoName: String, repoPath: String) {
        let repoType = LandmarkSystem.analyzeRepo(at: repoPath)
        landmarkSystem?.addLandmark(repoName: repoName, repoType: repoType)

        NSLog("[Pushling/World] Added landmark for '%@' — type: %@",
              repoName, repoType.landmarkType.rawValue)
    }

    /// Adds a repo landmark with a known type (e.g., loaded from SQLite).
    func addRepoLandmark(repoName: String, landmarkType: LandmarkType) {
        // Map LandmarkType back to RepoType for the addLandmark API
        let repoType: RepoType
        switch landmarkType {
        case .neonTower:    repoType = .webApp
        case .fortress:     repoType = .apiBackend
        case .obelisk:      repoType = .cliTool
        case .crystal:      repoType = .library
        case .smokeStack:   repoType = .infraDevOps
        case .observatory:  repoType = .dataML
        case .scrollTower:  repoType = .docsContent
        case .windmill:     repoType = .gameCreative
        case .monolith:     repoType = .generic
        }
        landmarkSystem?.addLandmark(repoName: repoName, repoType: repoType)
    }
}
