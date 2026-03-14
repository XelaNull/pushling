// PushlingScene.swift — Main SpriteKit scene for the Touch Bar
// Size: 1085 x 30 points (2170 x 60 pixels @2x Retina)
// Runs at 60fps with frame budget monitoring.
// Integrates WorldManager for terrain, parallax, biomes, and landmarks.
// Hosts the CreatureNode — the living Pushling creature.

import SpriteKit

final class PushlingScene: SKScene {

    // MARK: - Frame Budget Monitor

    private let frameBudgetMonitor = FrameBudgetMonitor()
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - World System

    /// The world rendering system — parallax, terrain, biomes, landmarks, tinting.
    let worldManager = WorldManager()

    // MARK: - Creature

    /// The Pushling creature — composite SKNode with all body parts.
    private(set) var creatureNode: CreatureNode?

    /// Creature world-X position for camera tracking.
    private var creatureWorldX: CGFloat = 542.5
    private var creatureWalkSpeed: CGFloat = 20.0  // pts/sec
    private var creatureDirection: CGFloat = 1.0   // 1.0 = right, -1.0 = left

    // MARK: - Debug Overlay

    private var debugOverlayNode: SKLabelNode?
    private var isDebugOverlayVisible = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        // Set scene background to OLED true black
        backgroundColor = .black

        // Initialize the world system
        setupWorld()

        // Setup the creature (replaces Phase 1 test node)
        setupCreature()

        setupDebugOverlay()

        NSLog("[Pushling] Scene active — \(Int(size.width))x\(Int(size.height))pt")
    }

    // MARK: - World Setup

    private func setupWorld() {
        var config = WorldConfig()
        config.specialty = "polyglot"
        config.initialCreatureX = creatureWorldX
        // Landmarks will be loaded from SQLite in future phases.
        // For now, add a few demo landmarks to prove the system works.
        worldManager.setup(scene: self, config: config)

        // Demo landmarks (will be replaced by SQLite reads)
        worldManager.addRepoLandmark(repoName: "pushling",
                                     landmarkType: .windmill)
        worldManager.addRepoLandmark(repoName: "web-app",
                                     landmarkType: .neonTower)
        worldManager.addRepoLandmark(repoName: "api-server",
                                     landmarkType: .fortress)
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime: TimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 1.0 / 60.0  // First frame: assume 60fps
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        // Start frame timing
        frameBudgetMonitor.beginFrame()

        // === Subsystem update order ===
        // 1. Physics — collision detection, force application
        updatePhysics(deltaTime: deltaTime)

        // 2. State — creature AI, emotional state, growth checks
        updateState(deltaTime: deltaTime)

        // 3. World — parallax, terrain recycling, chunk management
        updateWorld(deltaTime: deltaTime)

        // 4. Render — creature animations (breathing, blink, tail sway)
        updateRender(deltaTime: deltaTime)

        // End frame timing and check budget
        frameBudgetMonitor.endFrame()

        // Update debug overlay if visible
        if isDebugOverlayVisible {
            updateDebugOverlayText()
        }
    }

    // MARK: - Subsystem Updates

    /// Physics — collision detection, creature jump arcs, rain particles.
    private func updatePhysics(deltaTime: TimeInterval) {
        // Intentionally empty — Phase 2 Track 2
    }

    /// State — creature AI, emotions, hunger, growth.
    private func updateState(deltaTime: TimeInterval) {
        // Intentionally empty — Phase 2 Track 2
    }

    /// World — parallax scrolling, terrain generation/recycling, biomes.
    private func updateWorld(deltaTime: TimeInterval) {
        // Simulate creature walking
        simulateCreatureWalk(deltaTime: deltaTime)

        // Update world system with current camera position
        worldManager.update(deltaTime: deltaTime, trackedX: creatureWorldX)

        // Position the creature on the terrain surface
        if let creature = creatureNode {
            let terrainY = worldManager.terrainHeightAt(worldX: creatureWorldX)
            let config = StageConfiguration.all[creature.currentStage]!
            creature.position = CGPoint(
                x: creatureWorldX,
                y: terrainY + config.size.height / 2
            )
        }
    }

    /// Render — creature per-frame animations (breathing, blink, tail sway).
    private func updateRender(deltaTime: TimeInterval) {
        creatureNode?.update(deltaTime: deltaTime)
    }

    // MARK: - Creature Walking Simulation

    /// Simulates the creature walking back and forth through the world.
    /// Will be replaced by the behavior stack's autonomous walk in Track 2.
    private func simulateCreatureWalk(deltaTime: TimeInterval) {
        creatureWorldX += creatureWalkSpeed * creatureDirection
            * CGFloat(deltaTime)

        // Reverse direction at world boundaries (for demo)
        if creatureWorldX > 5000 {
            creatureDirection = -1.0
            creatureNode?.setFacing(.left)
        } else if creatureWorldX < -1000 {
            creatureDirection = 1.0
            creatureNode?.setFacing(.right)
        }
    }

    // MARK: - Creature Setup

    /// Initialize the Pushling creature and add it to the scene.
    /// Replaces the Phase 1 test node with a real composite creature.
    private func setupCreature() {
        let creature = CreatureNode()

        // Default to critter stage for visual testing
        // (will be read from SQLite in production)
        creature.configureForStage(.critter)

        creature.position = CGPoint(x: creatureWorldX, y: 15)
        creature.zPosition = 10  // Above terrain objects

        // Add to foreground layer (not scene root) so it scrolls
        if let foreLayer = worldManager.parallax.foreLayer {
            foreLayer.addChild(creature)
        } else {
            addChild(creature)
        }
        self.creatureNode = creature

        NSLog("[Pushling] Creature node active — %d nodes",
              creature.countNodes())
    }

    // MARK: - Debug Overlay

    private func setupDebugOverlay() {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 9
        label.fontColor = SKColor.green
        label.horizontalAlignmentMode = .right
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: size.width - 4, y: size.height - 2)
        label.name = "debugOverlay"
        label.zPosition = 1000  // Always on top
        label.isHidden = true
        label.text = "-- fps | --ms | 0 nodes"

        addChild(label)
        self.debugOverlayNode = label
    }

    func showDebugOverlay(_ show: Bool) {
        isDebugOverlayVisible = show
        debugOverlayNode?.isHidden = !show

        // Also toggle SpriteKit's built-in debug info on the SKView
        if let view = self.view {
            view.showsFPS = show
            view.showsNodeCount = show
        }
    }

    private func updateDebugOverlayText() {
        let stats = frameBudgetMonitor.currentStats
        let fpsStr = String(format: "%.0f", stats.fps)
        let frameTimeStr = String(format: "%.1f", stats.averageFrameTimeMs)
        let totalNodes = countAllNodes(in: self)
        let worldNodes = worldManager.worldNodeCount
        let biome = worldManager.currentBiome(at: creatureWorldX)

        debugOverlayNode?.text = "\(fpsStr)fps | \(frameTimeStr)ms | "
            + "\(totalNodes)n | w:\(worldNodes) | \(biome.rawValue)"
    }

    /// Recursively counts all nodes in the scene tree.
    private func countAllNodes(in node: SKNode) -> Int {
        return 1 + node.children.reduce(0) { $0 + countAllNodes(in: $1) }
    }
}
