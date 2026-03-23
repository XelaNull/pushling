// WorldManager.swift — World system orchestrator
// Owns all world subsystems: parallax, terrain, biomes, objects, landmarks, tinting,
// sky, weather, visual complexity, puddle reflections, ghost echo, hunger desaturation,
// visual events, ruin inscriptions, and fog of war.
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
    var creatureStage: GrowthStage = .egg
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

    /// Fog of war controller — stage-gated visibility around the creature.
    private(set) var fogOfWar: FogOfWarController?

    // MARK: - Sky & Weather Subsystems

    /// Real-time sky gradient, moon, and star field (P3-T2-01/02/03).
    let skySystem = SkySystem()

    /// Weather state machine and renderer coordination (P3-T2-04).
    /// Owns RainRenderer, SnowRenderer, StormSystem, FogRenderer internally.
    let weatherSystem = WeatherSystem()

    // MARK: - Sound Subsystem

    /// Programmatic ambient sound synthesis (chime, purr, meow, wind, etc.).
    let soundSystem = SoundSystem()

    // MARK: - World Object Subsystems

    /// Persistent world object renderer and manager.
    let objectRenderer = WorldObjectRenderer()

    /// Wear/repair lifecycle for world objects.
    let objectWearSystem = ObjectWearSystem()

    /// NPC companion system (max 1 companion at a time).
    let companionSystem = CompanionSystem()

    /// Database reference for object persistence.
    /// Internal access for use by WorldManager+Objects extension.
    weak var database: DatabaseManager?

    // MARK: - State

    /// Current world-space X position of the tracked entity (creature/camera).
    private(set) var cameraWorldX: CGFloat = 542.5

    /// Frame counter for periodic maintenance (eviction, etc.).
    private var frameCounter: Int = 0

    /// Last weather state we synced sounds to.
    private var lastSyncedWeather: WeatherState = .clear

    /// Last time period we synced sounds to.
    private var lastSyncedTimePeriod: TimePeriod?

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
    ///   - db: Database manager for object persistence (optional for tests).
    func setup(scene: SKScene, config: WorldConfig = WorldConfig(),
               db: DatabaseManager? = nil) {
        self.scene = scene
        self.database = db
        self.cameraWorldX = config.initialCreatureX

        // 1. Attach parallax layers to scene
        parallax.attach(to: scene)

        // 2. Create biome manager (needed by terrain generator)
        biomeManager = BiomeManager(seed: config.seed)

        // 3. Create terrain generator with biome reference
        terrainGenerator = TerrainGenerator(seed: config.seed)
        terrainGenerator.biomeManager = biomeManager

        // 4. Create terrain recycler on all parallax layers
        if let foreLayer = parallax.foreLayer {
            terrainRecycler = TerrainRecycler(
                terrainGenerator: terrainGenerator,
                biomeManager: biomeManager,
                foreLayer: foreLayer,
                midLayer: parallax.midLayer,
                deepLayer: parallax.deepLayer,
                farLayer: parallax.farLayer
            )
        }

        terrainRecycler?.complexityController = complexityController

        // 5. Create landmark system on the mid layer
        if let midLayer = parallax.midLayer {
            landmarkSystem = LandmarkSystem(midLayer: midLayer)
            landmarkSystem.loadLandmarks(config.landmarks)
        }

        // 6. Setup world tinting
        worldTinting.attach(to: scene)
        worldTinting.applyImmediate(config.specialty)

        // 7. Initialize visual complexity controller (P3-T3-03)
        //    Must precede terrain generation so initial chunks get texture detail.
        complexityController.updateStage(config.creatureStage)

        // 8. Initial terrain generation around starting position
        terrainGenerator.ensureChunksForRange(centerWorldX: cameraWorldX)
        terrainRecycler?.update(cameraWorldX: cameraWorldX)

        // 9. Initial parallax update
        parallax.update(cameraWorldX: cameraWorldX)

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

        // 15. Setup fog of war — stage-gated visibility around the creature
        let fogConfig = complexityController.fogOfWarConfig
        let fog = FogOfWarController(config: fogConfig)
        fog.addToScene(scene)
        self.fogOfWar = fog

        // 16. Setup sky system — gradient behind everything, stars + moon on far layer
        //     SkySystem owns gradientNode, starField, and moonNode.
        //     We add them to appropriate layers rather than using addToScene
        //     so each element lands on the correct parallax depth.
        scene.addChild(skySystem.gradientNode)  // Scene background (behind all layers)
        if let farLayer = parallax.farLayer {
            farLayer.addChild(skySystem.starField)
            farLayer.addChild(skySystem.moonNode)
        }

        // 17. Setup weather system — renderers on correct parallax layers
        //     WeatherSystem owns all renderers but we attach nodes to layers manually
        //     so rain/snow are foreground, fog is mid-layer, storm is scene-level.
        weatherSystem.skySystem = skySystem  // Wire sky darkening

        if let foreLayer = parallax.foreLayer {
            weatherSystem.rainRenderer.addToScene(parent: foreLayer)
            weatherSystem.snowRenderer.addToScene(parent: foreLayer)
        }
        if let midLayer = parallax.midLayer {
            weatherSystem.fogRenderer.addToScene(parent: midLayer)
        }
        weatherSystem.stormSystem.addToScene(parent: scene)  // Scene-level for full-width lightning
        weatherSystem.stormSystem.sceneNode = scene           // Screen shake reference

        // Wire terrain height callbacks so rain/snow splash at terrain surface
        weatherSystem.rainRenderer.terrainHeightAt = { [weak self] worldX in
            self?.terrainHeightAt(worldX: worldX) ?? 4.0
        }
        weatherSystem.snowRenderer.terrainHeightAt = { [weak self] worldX in
            self?.terrainHeightAt(worldX: worldX) ?? 4.0
        }

        // 18. Setup ambient sound system
        soundSystem.setup()

        // 19. Setup world object renderer on all parallax layers
        if let farLayer = parallax.farLayer,
           let midLayer = parallax.midLayer,
           let foreLayer = parallax.foreLayer {
            objectRenderer.attach(farLayer: farLayer,
                                   midLayer: midLayer,
                                   foreLayer: foreLayer)
            companionSystem.attach(to: foreLayer)
        }

        // 20. Load persisted objects from SQLite
        loadObjectsFromDB()

        // 21. Load persisted companion from SQLite
        loadCompanionFromDB()

        isSetUp = true
        NSLog("[Pushling/World] World system initialized — seed %llu, "
              + "specialty %@, %d landmarks, %d objects, companion %@, "
              + "stage %@, sky %@, weather %@",
              config.seed, config.specialty, config.landmarks.count,
              objectRenderer.activeObjects.count,
              companionSystem.hasCompanion ? "yes" : "no",
              "\(config.creatureStage)",
              skySystem.currentPeriod.rawValue,
              weatherSystem.currentState.rawValue)
    }

    // MARK: - Frame Update

    /// Main frame update — call from PushlingScene's update loop.
    /// Updates parallax, terrain recycling, and periodic maintenance.
    ///
    /// - Parameters:
    ///   - deltaTime: Time since last frame.
    ///   - trackedX: World-X position to center the camera on
    ///     (typically creature position or effective camera position).
    ///   - zoom: Current zoom level (1.0 = normal, 2.0 = max zoom).
    func update(deltaTime: TimeInterval, trackedX: CGFloat,
                zoom: CGFloat = 1.0) {
        guard isSetUp else { return }

        cameraWorldX = trackedX
        frameCounter += 1

        // Update parallax layer positions with zoom (< 0.1ms)
        parallax.update(cameraWorldX: trackedX, zoom: zoom)

        // Update terrain recycler — generate/recycle chunks (< 0.2ms)
        terrainRecycler?.update(cameraWorldX: trackedX)

        // Update sky gradient, star twinkle, moon visibility (< 0.1ms per frame,
        // full sky recalc every ~1s)
        skySystem.update(deltaTime: deltaTime)

        // Update weather state machine and active renderers (< 0.2ms)
        // WeatherSystem handles rain/snow/storm/fog renderer updates internally
        weatherSystem.update(deltaTime: deltaTime)

        // Update visual event animations
        visualEvents.update(deltaTime: deltaTime)

        // Update hunger desaturation overlay
        hungerDesaturation.update(deltaTime: deltaTime)

        // Update ruin inscription cooldown
        ruinInscriptions.update(deltaTime: deltaTime)

        // Update world objects LOD, effects, and wear visuals (< 0.1ms)
        objectRenderer.update(deltaTime: deltaTime, cameraWorldX: trackedX)

        // Update companion NPC autonomous behavior (< 0.1ms)
        let creatureY = terrainHeightAt(worldX: trackedX) + 4.0
        companionSystem.update(deltaTime: deltaTime,
                                creatureX: trackedX,
                                creatureY: creatureY)

        // Periodic maintenance (every 30 frames ~ 0.5s at 60fps)
        if frameCounter % 30 == 0 {
            terrainGenerator.evictDistantChunks(centerWorldX: trackedX)

            // Sync ambient sounds if weather or time period changed
            let currentWeather = weatherSystem.currentState
            let currentPeriod = skySystem.currentPeriod
            if currentWeather != lastSyncedWeather
                || currentPeriod != lastSyncedTimePeriod {
                lastSyncedWeather = currentWeather
                lastSyncedTimePeriod = currentPeriod
                syncWeatherSounds()
            }
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
        let oldFogConfig = complexityController.fogOfWarConfig
        complexityController.updateStage(newStage)
        puddleReflection.configureForStage(newStage)
        ghostEcho.configureForStage(newStage)
        ruinInscriptions.configureForStage(newStage)

        // Rebuild terrain texture overlays for the new complexity level
        terrainRecycler?.rebuildActiveChunkTextures()

        // Update fog of war with evolution reveal animation
        let newFogConfig = complexityController.fogOfWarConfig
        updateFogStage(from: oldFogConfig, to: newFogConfig, animated: true)

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
        let fogNodes = fogOfWar?.nodeCount ?? 0
        let objectNodes = objectRenderer.totalNodeCount
        let companionNodes = companionSystem.nodeCount
        // Sky: gradient(1) + starField(1 container) + moon(1 container) = 3
        // Weather: rain container(1) + snow container(1) + storm container(1) + fog container(1) = 4
        let skyNodes = 3
        let weatherNodes = 4
        return parallaxNodes + terrainNodes + landmarkNodes + tintNode
            + reflectionNodes + ghostNodes + hungerNode + eventNodes
            + inscriptionNodes + fogNodes + objectNodes + companionNodes
            + skyNodes + weatherNodes
    }

    // MARK: - Weather Queries

    /// Current weather state (for MCP pushling_sense / debug overlay).
    var currentWeather: WeatherState {
        return weatherSystem.currentState
    }

    /// Detailed weather description (for MCP state queries).
    var weatherDescription: [String: Any] {
        return weatherSystem.weatherDescription
    }

    /// Current sky time period (for MCP state queries).
    var currentTimePeriod: TimePeriod {
        return skySystem.currentPeriod
    }

    /// Whether the moon is full (for surprise system hooks).
    var isFullMoon: Bool {
        return skySystem.moonNode.isFullMoon
    }

    /// Moon phase name (for MCP state queries).
    var moonPhaseName: String {
        return skySystem.moonNode.phaseName
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

    // MARK: - Debug: Weather Override

    /// Force a weather state for debug/testing purposes.
    /// Delegates to the live WeatherSystem — activates/deactivates the correct
    /// renderers and transitions smoothly over 30-60s.
    func debugForceWeather(_ state: WeatherState) {
        let previous = weatherSystem.currentState
        weatherSystem.forceWeather(state, duration: 300)  // 5 min override
        NSLog("[Pushling/World] Debug weather override: %@ -> %@ (5 min)",
              previous.rawValue, state.rawValue)

        // Sync ambient sounds to new weather
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.syncWeatherSounds()
        }
    }

}
