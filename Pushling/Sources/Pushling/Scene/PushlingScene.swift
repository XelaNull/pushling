// PushlingScene.swift — Main SpriteKit scene for the Touch Bar
// Size: 1085 x 30 points (2170 x 60 pixels @2x Retina)
// Runs at 60fps with frame budget monitoring.
// Integrates WorldManager for terrain, parallax, biomes, and landmarks.
// Hosts the CreatureNode — the living Pushling creature.
// P3-T3: Integrates HUD overlay, evolution progress bar, and visual polish systems.

import SpriteKit

final class PushlingScene: SKScene {

    // MARK: - Frame Budget Monitor

    private let frameBudgetMonitor = FrameBudgetMonitor()
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - World System

    /// The world rendering system — parallax, terrain, biomes, landmarks, tinting,
    /// visual complexity, puddle reflections, ghost echo, hunger desaturation,
    /// visual events, and ruin inscriptions.
    let worldManager = WorldManager()

    // MARK: - Creature

    /// The Pushling creature — composite SKNode with all body parts.
    private(set) var creatureNode: CreatureNode?

    /// The 4-layer behavior stack — single source of truth for creature state.
    private(set) var behaviorStack: BehaviorStack?

    /// Creature world-X position for camera tracking.
    private var creatureWorldX: CGFloat = 542.5
    private var creatureWalkSpeed: CGFloat = 20.0  // pts/sec
    private var creatureDirection: CGFloat = 1.0   // 1.0 = right, -1.0 = left

    // MARK: - HUD & UI (P3-T3-06, P3-T3-07)

    /// Cinematic HUD overlay — tap to show stats for 3 seconds.
    let hudOverlay = HUDOverlay()

    /// Near-evolution progress bar — 1pt bar at bottom edge.
    let evolutionProgressBar = EvolutionProgressBar()

    // MARK: - Debug Overlay

    private var debugOverlayNode: SKLabelNode?
    private var isDebugOverlayVisible = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        // P3-T3-02: OLED true black — literal #000000, pixels OFF.
        // SKColor.black is confirmed (0,0,0). allowsTransparency = false
        // ensures no accidental gray from compositing.
        backgroundColor = .black
        view.allowsTransparency = false

        // Initialize the world system
        setupWorld()

        // Setup the creature (replaces Phase 1 test node)
        setupCreature()

        // Setup HUD and evolution progress bar (P3-T3-06, P3-T3-07)
        setupHUD()

        setupDebugOverlay()

        NSLog("[Pushling] Scene active — \(Int(size.width))x\(Int(size.height))pt"
              + " | OLED true-black enabled")
    }

    // MARK: - World Setup

    private func setupWorld() {
        var config = WorldConfig()
        config.specialty = "polyglot"
        config.initialCreatureX = creatureWorldX
        config.creatureStage = .critter  // Will be read from SQLite in production
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

    // MARK: - HUD Setup (P3-T3-06, P3-T3-07)

    private func setupHUD() {
        // HUD overlay — cinematic default (hidden), shows on tap
        hudOverlay.addToScene(self)

        // Evolution progress bar — 1pt at bottom edge
        evolutionProgressBar.addToScene(self)

        // Set initial HUD state (demo values — will read from SQLite)
        hudOverlay.updateState(HUDState(
            satisfaction: 50.0,
            stageName: "critter",
            currentXP: 45,
            xpToNext: 100,
            streakDays: 3,
            stageColor: PushlingPalette.stageColor(for: .critter)
        ))
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

        // 3. World — parallax, terrain recycling, chunk management, visual effects
        updateWorld(deltaTime: deltaTime)

        // 4. Render — creature animations (breathing, blink, tail sway)
        updateRender(deltaTime: deltaTime)

        // 5. UI — evolution progress bar pulse (P3-T3-07)
        evolutionProgressBar.update(deltaTime: deltaTime)

        // End frame timing and check budget
        frameBudgetMonitor.endFrame()

        // Update debug overlay if visible
        if isDebugOverlayVisible {
            updateDebugOverlayText()
        }
    }

    // MARK: - Subsystem Updates

    /// Behavior stack update — runs all 4 layers, resolves output, blends.
    /// This is where the creature's behavior is computed each frame.
    private func updatePhysics(deltaTime: TimeInterval) {
        guard let stack = behaviorStack else { return }

        let output = stack.update(deltaTime: deltaTime,
                                   currentTime: lastUpdateTime)

        // Apply blended state to creature node
        applyBehaviorOutput(output)
    }

    /// State — creature AI, emotions, hunger, growth.
    private func updateState(deltaTime: TimeInterval) {
        // Emotional decay, circadian cycle, etc. — Phase 2 Track 3
    }

    /// World — parallax scrolling, terrain generation/recycling, biomes,
    /// visual effects, creature-dependent visuals.
    private func updateWorld(deltaTime: TimeInterval) {
        // Simulate creature walking
        simulateCreatureWalk(deltaTime: deltaTime)

        // Update world system with current camera position
        worldManager.update(deltaTime: deltaTime, trackedX: creatureWorldX)

        // Position the creature on the terrain surface
        if let creature = creatureNode {
            let terrainY = worldManager.terrainHeightAt(worldX: creatureWorldX)
            let config = StageConfiguration.all[creature.currentStage]!
            let creatureY = terrainY + config.size.height / 2
            creature.position = CGPoint(
                x: creatureWorldX,
                y: creatureY
            )

            // Update creature-dependent visual systems (P3-T3-04, P3-T3-05)
            let facing: Direction = creatureDirection > 0 ? .right : .left
            worldManager.updateCreatureVisuals(
                creatureWorldX: creatureWorldX,
                creatureY: creatureY,
                creatureFacing: facing,
                deltaTime: deltaTime
            )
        }
    }

    /// Render — creature per-frame animations (breathing, blink, tail sway).
    private func updateRender(deltaTime: TimeInterval) {
        creatureNode?.update(deltaTime: deltaTime)
    }

    // MARK: - Touch Handling (P3-T3-06)

    /// Handle a touch at a scene position. Called by the touch bar controller
    /// or SKView's touch event pipeline. Touch Bar uses a custom touch
    /// forwarding mechanism; this is the common entry point.
    /// - Parameter scenePoint: The touch position in scene coordinates.
    func handleTouch(at scenePoint: CGPoint) {
        // Check if touch is on the creature (within creature bounds)
        if let creature = creatureNode {
            let creatureFrame = creature.calculateAccumulatedFrame()
            if creatureFrame.contains(scenePoint) {
                // Creature touch — handled by touch input system (future phase)
                return
            }
        }

        // Empty space tap — show HUD overlay
        hudOverlay.handleTap(at: scenePoint)
    }

    /// macOS mouse event fallback (for testing in Xcode preview).
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleTouch(at: location)
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

        // Initialize the behavior stack
        let stack = BehaviorStack(
            stage: .critter,
            personality: .neutral,
            emotions: .neutral
        )
        stack.reset(
            stage: .critter,
            position: CGPoint(x: creatureWorldX, y: SceneConstants.groundY),
            facing: .right
        )
        self.behaviorStack = stack

        NSLog("[Pushling] Creature node active — %d nodes | Behavior stack ready",
              creature.countNodes())
    }

    // MARK: - Stage Change Integration

    /// Called when the creature evolves to a new stage.
    /// Updates all dependent systems.
    func onCreatureStageChanged(_ newStage: GrowthStage) {
        // Update world visual complexity (P3-T3-03)
        worldManager.onStageChanged(newStage)

        // Update HUD
        hudOverlay.updateState(HUDState(
            satisfaction: hudOverlay.currentState.satisfaction,
            stageName: "\(newStage)",
            currentXP: 0,
            xpToNext: 100,  // Will be read from state
            streakDays: hudOverlay.currentState.streakDays,
            stageColor: PushlingPalette.stageColor(for: newStage)
        ))

        // Hide evolution progress bar during ceremony, show after
        evolutionProgressBar.hideForCeremony()
    }

    /// Called after evolution ceremony completes.
    func onEvolutionCeremonyComplete() {
        evolutionProgressBar.showAfterCeremony()
    }

    // MARK: - XP Change Integration (P3-T3-07)

    /// Called when XP changes (commit eaten, etc.).
    func onXPChanged(currentXP: Int, xpToNext: Int, stage: GrowthStage) {
        evolutionProgressBar.updateXP(
            currentXP: currentXP,
            xpToNext: xpToNext,
            stage: stage
        )

        // Update HUD state
        var state = hudOverlay.currentState
        state.currentXP = currentXP
        state.xpToNext = xpToNext
        hudOverlay.updateState(state)
    }

    // MARK: - Satisfaction Change Integration (P3-T3-08)

    /// Called when creature satisfaction changes.
    func onSatisfactionChanged(_ satisfaction: Double) {
        worldManager.updateSatisfaction(satisfaction)
        hudOverlay.updateSatisfaction(satisfaction)
    }

    // MARK: - Behavior Output Application

    /// Applies the behavior stack output to the creature node and world.
    /// Breathing is handled by CreatureNode internally (per-frame sine wave)
    /// and is NOT overridden here — it always runs via CreatureNode.update().
    private func applyBehaviorOutput(_ output: BehaviorStackOutput) {
        guard let creature = creatureNode else { return }
        let state = output.creatureState

        // Update tracked world position and creature facing
        creatureWorldX = state.positionX
        creature.setFacing(state.facing)

        // Sleep state (modifies CreatureNode's internal breathing)
        creature.setSleeping(behaviorStack?.physics.isSleeping ?? false)

        // Body part states via controllers
        creature.earLeftController?.setState(state.earLeftState, duration: 0)
        creature.earRightController?.setState(state.earRightState, duration: 0)
        creature.eyeLeftController?.setState(state.eyeLeftState, duration: 0)
        creature.eyeRightController?.setState(state.eyeRightState, duration: 0)
        creature.tailController?.setState(state.tailState, duration: 0)
        creature.mouthController?.setState(state.mouthState, duration: 0)
        creature.whiskerLeftController?.setState(state.whiskerState, duration: 0)
        creature.whiskerRightController?.setState(state.whiskerState, duration: 0)

        // Paw states
        let paws = state.pawStates
        if let s = paws["fl"] { creature.pawFLController?.setState(s, duration: 0) }
        if let s = paws["fr"] { creature.pawFRController?.setState(s, duration: 0) }
        if let s = paws["bl"] { creature.pawBLController?.setState(s, duration: 0) }
        if let s = paws["br"] { creature.pawBRController?.setState(s, duration: 0) }
    }

    // MARK: - Debug Overlay

    private func setupDebugOverlay() {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 9
        label.fontColor = PushlingPalette.moss  // P3-T3-01: use palette color
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
        let complexity = worldManager.complexityController.level.rawValue

        debugOverlayNode?.text = "\(fpsStr)fps | \(frameTimeStr)ms | "
            + "\(totalNodes)n | w:\(worldNodes) | \(biome.rawValue) | c\(complexity)"
    }

    /// Recursively counts all nodes in the scene tree.
    private func countAllNodes(in node: SKNode) -> Int {
        return 1 + node.children.reduce(0) { $0 + countAllNodes(in: $1) }
    }
}
