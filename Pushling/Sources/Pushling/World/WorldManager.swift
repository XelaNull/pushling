// WorldManager.swift — World system orchestrator
// Owns all world subsystems: parallax, terrain, biomes, objects, landmarks, tinting,
// sky, weather, visual complexity, puddle reflections, ghost echo, hunger desaturation,
// visual events, and ruin inscriptions.
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

    /// Initial creature stage (for visual complexity gating).
    var creatureStage: GrowthStage = .spore
}

// MARK: - WorldManager

/// Orchestrates the entire world rendering system.
/// The scene owns one WorldManager and delegates world updates to it.
final class WorldManager {

    // MARK: - Core Subsystems

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

    // MARK: - Phase 3 Track 3 Subsystems

    /// Stage-gated visual complexity controller (P3-T3-03).
    let complexityController = VisualComplexityController()

    /// Puddle reflection system (P3-T3-04).
    let puddleReflection = PuddleReflection()

    /// Ghost echo system (P3-T3-05).
    let ghostEcho = GhostEchoNode()

    /// Hunger desaturation controller (P3-T3-08).
    let hungerDesaturation = HungerDesaturationController()

    /// Visual event spectacles manager (P3-T3-09).
    let visualEvents = VisualEventManager()

    /// Ruin inscription system (P3-T3-11).
    let ruinInscriptions = RuinInscriptionSystem()

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

        // 9. Initialize visual complexity controller (P3-T3-03)
        complexityController.updateStage(config.creatureStage)

        // 10. Setup puddle reflection on foreground layer (P3-T3-04)
        if let foreLayer = parallax.foreLayer {
            puddleReflection.addToLayer(foreLayer)
            puddleReflection.configureForStage(config.creatureStage)
        }

        // 11. Setup ghost echo on foreground layer (P3-T3-05)
        if let foreLayer = parallax.foreLayer {
            ghostEcho.addToLayer(foreLayer)
            ghostEcho.configureForStage(config.creatureStage)
        }

        // 12. Setup hunger desaturation overlay (P3-T3-08)
        hungerDesaturation.addToScene(scene)

        // 13. Setup visual event manager (P3-T3-09)
        visualEvents.addToScene(scene)

        // 14. Setup ruin inscription system (P3-T3-11)
        if let foreLayer = parallax.foreLayer {
            ruinInscriptions.addToLayer(foreLayer)
            ruinInscriptions.configureForStage(config.creatureStage)
        }

        isSetUp = true
        NSLog("[Pushling/World] World system initialized — seed %llu, "
              + "specialty %@, %d landmarks, stage %@",
              config.seed, config.specialty, config.landmarks.count,
              "\(config.creatureStage)")
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

        // Update visual event animations
        visualEvents.update(deltaTime: deltaTime)

        // Update hunger desaturation overlay
        hungerDesaturation.update(deltaTime: deltaTime)

        // Update ruin inscription cooldown
        ruinInscriptions.update(deltaTime: deltaTime)

        // Periodic maintenance (every 30 frames ~ 0.5s at 60fps)
        if frameCounter % 30 == 0 {
            terrainGenerator.evictDistantChunks(centerWorldX: trackedX)
        }
    }

    /// Update creature-dependent visual systems.
    /// Call separately from the creature update path.
    /// - Parameters:
    ///   - creatureWorldX: Creature's current world-X.
    ///   - creatureY: Creature's current Y position.
    ///   - creatureFacing: Creature's current facing direction.
    ///   - deltaTime: Time since last frame.
    func updateCreatureVisuals(creatureWorldX: CGFloat,
                                creatureY: CGFloat,
                                creatureFacing: Direction,
                                deltaTime: TimeInterval) {

        // Puddle reflection (P3-T3-04)
        if complexityController.puddleReflectionsEnabled {
            let nearestPuddle = findNearestPuddle(to: creatureWorldX)
            let terrainY = terrainHeightAt(worldX: creatureWorldX)
            puddleReflection.update(
                creatureWorldX: creatureWorldX,
                creatureY: creatureY,
                nearestPuddleX: nearestPuddle,
                puddleY: terrainY,
                deltaTime: deltaTime
            )
        }

        // Ghost echo (P3-T3-05)
        if complexityController.ghostEchoEnabled {
            ghostEcho.update(
                creatureWorldX: creatureWorldX,
                creatureY: creatureY,
                creatureFacing: creatureFacing,
                deltaTime: deltaTime
            )
        }
    }

    // MARK: - Stage Change

    /// Called when the creature's growth stage changes.
    /// Updates all stage-gated subsystems.
    func onStageChanged(_ newStage: GrowthStage) {
        complexityController.updateStage(newStage)
        puddleReflection.configureForStage(newStage)
        ghostEcho.configureForStage(newStage)
        ruinInscriptions.configureForStage(newStage)

        NSLog("[Pushling/World] Stage changed to %@ — complexity level %d",
              "\(newStage)", complexityController.level.rawValue)
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

    /// Find the nearest water puddle to a world-X position.
    /// Returns the puddle's world-X, or nil if none nearby.
    private func findNearestPuddle(to worldX: CGFloat) -> CGFloat? {
        return terrainRecycler?.nearestObjectOfType(.waterPuddle,
                                                     to: worldX,
                                                     maxDistance: 15)
    }

    /// Returns the total world node count (for debug overlay).
    var worldNodeCount: Int {
        let parallaxNodes = 3  // The three layer containers
        let terrainNodes = terrainRecycler?.activeNodeCount ?? 0
        let landmarkNodes = landmarkSystem?.landmarks.count ?? 0
        let tintNode = 1
        let reflectionNodes = puddleReflection.nodeCount
        let ghostNodes = ghostEcho.nodeCount
        let hungerNode = hungerDesaturation.nodeCount
        let eventNodes = visualEvents.nodeCount
        let inscriptionNodes = ruinInscriptions.nodeCount
        return parallaxNodes + terrainNodes + landmarkNodes + tintNode
            + reflectionNodes + ghostNodes + hungerNode + eventNodes
            + inscriptionNodes
    }

    // MARK: - Specialty Updates

    /// Updates the world tinting when the creature's specialty changes.
    /// Call from the state system when a commit shifts the specialty.
    func updateSpecialty(_ specialty: String) {
        worldTinting.updateSpecialty(specialty)
    }

    // MARK: - Satisfaction Updates (P3-T3-08)

    /// Update the hunger desaturation based on creature satisfaction.
    func updateSatisfaction(_ satisfaction: Double) {
        hungerDesaturation.updateSatisfaction(satisfaction)
    }

    // MARK: - Visual Events (P3-T3-09)

    /// Trigger a visual spectacle event.
    /// - Parameter type: The event type to trigger.
    /// - Returns: True if started immediately, false if queued.
    @discardableResult
    func triggerVisualEvent(_ type: VisualEventType) -> Bool {
        guard complexityController.visualEventsEnabled else {
            NSLog("[Pushling/World] Visual events not available at %@ stage",
                  "\(complexityController.stage)")
            return false
        }
        return visualEvents.triggerEvent(type)
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
