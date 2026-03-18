// PushlingScene.swift — Main SpriteKit scene for the Touch Bar
// Size: 1085 x 30 points (2170 x 60 pixels @2x Retina)
// Runs at 60fps with frame budget monitoring.
// Integrates WorldManager for terrain, parallax, biomes, and landmarks.
// Hosts the CreatureNode — the living Pushling creature.
// P3-T3: Integrates HUD overlay, evolution progress bar, and visual polish systems.
// P4-T4: Diamond indicator for Claude's session presence.

import SpriteKit

final class PushlingScene: SKScene {

    // MARK: - Frame Budget Monitor

    let frameBudgetMonitor = FrameBudgetMonitor()
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - World System

    /// The world rendering system — parallax, terrain, biomes, landmarks, tinting,
    /// visual complexity, puddle reflections, ghost echo, hunger desaturation,
    /// visual events, and ruin inscriptions.
    let worldManager = WorldManager()

    /// Camera controller for pan/zoom (touch-driven).
    let cameraController = CameraController()

    // MARK: - Creature

    /// The Pushling creature — composite SKNode with all body parts.
    private(set) var creatureNode: CreatureNode?

    /// The 4-layer behavior stack — single source of truth for creature state.
    private(set) var behaviorStack: BehaviorStack?

    /// Creature world-X position for camera tracking.
    private var creatureWorldX: CGFloat = SceneConstants.sceneWidth / 2
    private var creatureWalkSpeed: CGFloat = 20.0  // pts/sec
    private var creatureDirection: CGFloat = 1.0   // 1.0 = right, -1.0 = left

    /// Creature depth position (0.0 = foreground, 1.0 = background).
    /// Stored per-frame in applyBehaviorOutput, applied in updateWorld.
    private var creaturePositionZ: CGFloat = 0.0

    /// When true, depth-based creature counter-scaling is disabled.
    /// Set by the CinematicSequencer so the creature can fill the frame
    /// during dramatic zooms (e.g., evolution ceremony at 2.5x).
    var disableCreatureCounterScaling: Bool = false

    // MARK: - HUD & UI (P3-T3-06, P3-T3-07)

    /// Cinematic HUD overlay — tap to show stats for 3 seconds.
    let hudOverlay = HUDOverlay()

    /// Near-evolution progress bar — 1pt bar at bottom edge.
    let evolutionProgressBar = EvolutionProgressBar()

    // MARK: - Session Lifecycle (P4-T4)

    /// Diamond indicator — Claude's presence near the creature.
    private(set) var diamondIndicator: DiamondIndicator?

    /// Session lifecycle reaction coordinator.
    private(set) var sessionReactions: SessionLifecycleReactions?

    /// Idle timeout update throttle — check every 0.5s, not every frame.
    private var idleTimeoutAccumulator: TimeInterval = 0
    private static let idleTimeoutInterval: TimeInterval = 0.5

    // MARK: - Cinematic Sequencer

    /// The cinematic sequencer — coordinates camera, touch, behavior,
    /// and counter-scaling during dramatic events (evolution, etc.).
    let cinematicSequencer = CinematicSequencer()

    // MARK: - Hatching Ceremony

    /// Whether the scene is currently in hatching mode (first launch).
    /// During hatching, normal creature behaviors are suppressed and the
    /// HatchingCeremony drives the scene update loop instead.
    private(set) var isHatching: Bool = false

    /// The active hatching ceremony, if running.
    private(set) var hatchingCeremony: HatchingCeremony?

    // MARK: - Game Coordinator

    /// The master wiring class — connects all subsystems. Set by AppDelegate.
    weak var gameCoordinator: GameCoordinator? {
        didSet {
            // Release fallback speech coordinator now that the real one is available
            if let gc = gameCoordinator {
                _fallbackSpeechCoordinator = nil

                // Wire cinematic cancel escape hatch (triple-tap during cinematic)
                gc.creatureTouchHandler.onCinematicCancelRequest = {
                    [weak self] in
                    self?.cinematicSequencer.cancel()
                    self?.behaviorStack?.thawFromCinematic()
                }
            }
        }
    }

    // MARK: - Toggle Button

    /// Callback when the [P] toggle button is tapped (minimize/restore Touch Bar).
    var onToggleTouchBar: (() -> Void)?

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

        NSLog("[Pushling/Scene] Scene active — \(Int(size.width))x\(Int(size.height))pt"
              + " | OLED true-black enabled")
    }

    // MARK: - World Setup

    private func setupWorld() {
        var config = WorldConfig()
        config.specialty = "polyglot"
        config.initialCreatureX = creatureWorldX
        config.creatureStage = gameCoordinator?.creatureStage ?? .spore
        worldManager.setup(scene: self, config: config,
                          db: DatabaseManager.shared)
    }

    // MARK: - HUD Setup (P3-T3-06, P3-T3-07)

    private func setupHUD() {
        // HUD overlay — cinematic default (hidden), shows on tap
        hudOverlay.addToScene(self)

        // Evolution progress bar — 1pt at bottom edge
        evolutionProgressBar.addToScene(self)

        // Set initial HUD state from coordinator (or defaults for first launch)
        let hudStage = gameCoordinator?.creatureStage ?? .spore
        let hudXP = gameCoordinator?.totalXP ?? 0
        hudOverlay.updateState(HUDState(
            satisfaction: gameCoordinator?.emotionalState.satisfaction ?? 50.0,
            stageName: "\(hudStage)",
            currentXP: hudXP % 100,
            xpToNext: 100,
            streakDays: 0,
            stageColor: PushlingPalette.stageColor(for: hudStage)
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

        // === Hatching ceremony gate ===
        // During hatching, only pump the ceremony — suppress all normal systems.
        if isHatching {
            hatchingCeremony?.update(deltaTime: deltaTime)
            frameBudgetMonitor.endFrame()
            return
        }

        // === Cinematic sequencer ===
        cinematicSequencer.update(deltaTime: deltaTime)
        syncCinematicState()

        // === Subsystem update order (normal operation) ===
        // 1. Physics — collision detection, force application
        updatePhysics(deltaTime: deltaTime)

        // 2. World — parallax, terrain recycling, chunk management, visual effects
        updateWorld(deltaTime: deltaTime)

        // 4. Render — creature animations (breathing, blink, tail sway)
        updateRender(deltaTime: deltaTime)

        // 5. UI — evolution progress bar pulse (P3-T3-07)
        evolutionProgressBar.update(deltaTime: deltaTime)

        // 5b. Debug eating animation — runs per-frame when active
        if debugEatingAnimation.isEating {
            debugEatingAnimation.update(deltaTime: deltaTime)
        }

        // 5c. Debug speech coordinator — update active bubbles
        debugSpeechCoordinator.update(deltaTime: deltaTime)

        // 6. Diamond indicator — per-frame animation (P4-T4-01)
        diamondIndicator?.update(deltaTime: deltaTime)

        // 6b. GameCoordinator — pump all wired subsystems
        gameCoordinator?.update(deltaTime: deltaTime)

        // 7. Idle timeout gradient check — throttled to every 0.5s (P4-T4-04)
        idleTimeoutAccumulator += deltaTime
        if idleTimeoutAccumulator >= Self.idleTimeoutInterval {
            idleTimeoutAccumulator = 0
            updateSessionIdleTimeout()
        }

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

    /// World — parallax scrolling, terrain generation/recycling, biomes,
    /// visual effects, creature-dependent visuals, camera pan/zoom.
    private func updateWorld(deltaTime: TimeInterval) {
        // Compute creature height for camera Y-tracking
        let creatureHeight: CGFloat
        if let creature = creatureNode,
           let config = StageConfiguration.all[creature.currentStage] {
            creatureHeight = config.size.height
        } else {
            creatureHeight = 6.0  // Fallback (spore size)
        }

        // Compute creature focus Y for camera Y-tracking
        let creatureFocusY = creatureNode?.position.y ?? 15.0

        // Update camera controller with full Y-tracking support
        cameraController.update(deltaTime: deltaTime,
                                 creatureWorldX: creatureWorldX,
                                 creatureFocusY: creatureFocusY,
                                 creatureHeight: creatureHeight)

        // Update world system with effective camera position (base + pan)
        let effectiveX = cameraController.effectiveWorldX
        worldManager.update(deltaTime: deltaTime, trackedX: effectiveX,
                            zoom: cameraController.zoomLevel)

        // Position the creature on the terrain surface
        if let creature = creatureNode {
            // Use depth-aware terrain query: creature follows terrain at its Z depth
            let z = creaturePositionZ
            let terrainY = worldManager.terrainHeightAtDepth(
                worldX: creatureWorldX, depth: z
            )
            let config = StageConfiguration.all[creature.currentStage]!
            let creatureY = terrainY + config.size.height / 2
            // Clamp Y so creature never goes off the bottom of the screen
            let clampedY = max(creatureY, config.size.height / 2 + 1.0)
            creature.position = CGPoint(
                x: creatureWorldX,
                y: clampedY
            )

            // Update creature-dependent visual systems (P3-T3-04, P3-T3-05)
            let facing: Direction = creatureDirection > 0 ? .right : .left
            worldManager.updateCreatureVisuals(
                creatureWorldX: creatureWorldX,
                creatureY: creatureY,
                creatureFacing: facing,
                deltaTime: deltaTime
            )

            // Update fog of war — track creature's screen-space position
            let zoom = cameraController.zoomLevel
            let creatureScreenX = size.width / 2
                + (creatureWorldX - cameraController.effectiveWorldX) * zoom
            worldManager.updateFogOfWar(
                creatureScreenX: creatureScreenX,
                creatureWorldX: creatureWorldX,
                zoom: zoom,
                deltaTime: deltaTime
            )

            // Apply depth perspective (Phase 0B)
            // During cinematic zoom, skip counter-scaling so the creature
            // fills the frame at the zoomed level.
            if disableCreatureCounterScaling {
                creature.xScale = creature.facing.xScale
                creature.yScale = 1.0
                creature.zPosition = 10.0
            } else {
                // positionZ: 0.0 = foreground (full size), 1.0 = background (0.5x size)
                let depthScale = 1.0 - z * 0.5

                // xScale: preserve facing sign from setFacing, apply depth scale
                creature.xScale = depthScale * creature.facing.xScale
                // yScale: root node scale — breathing is bodyNode.yScale (child), no conflict
                creature.yScale = depthScale

                // Dynamic Z-ordering: creature always stays in front of terrain
                // z=0.0 → zPosition 10 (above terrain objects)
                // z=0.8 → zPosition 0.4 (still visible above terrain at -1)
                creature.zPosition = 10.0 - z * 12.0
            }
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
        // Ignore touches during hatching ceremony or cinematic sequence
        guard !isHatching, !cinematicSequencer.isActive else { return }

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

    // MARK: - Touch Bar Touch Events

    /// Forward Touch Bar touches to the input pipeline.
    /// Touch Bar delivers NSTouchType.direct touches via these NSResponder methods.
    override func touchesBegan(with event: NSEvent) {
        guard let view = self.view else { return }
        for touch in event.touches(matching: .began, in: view) {
            let norm = touch.normalizedPosition
            let scenePoint = CGPoint(x: norm.x * size.width, y: norm.y * size.height)
            handleTouch(at: scenePoint)
            gameCoordinator?.touchTracker.touchBegan(
                id: ObjectIdentifier(touch),
                normalizedPosition: scenePoint,
                currentTime: CACurrentMediaTime()
            )
        }
    }

    override func touchesMoved(with event: NSEvent) {
        guard let view = self.view else { return }
        for touch in event.touches(matching: .moved, in: view) {
            let norm = touch.normalizedPosition
            let scenePoint = CGPoint(x: norm.x * size.width, y: norm.y * size.height)
            gameCoordinator?.touchTracker.touchMoved(
                id: ObjectIdentifier(touch),
                normalizedPosition: scenePoint,
                currentTime: CACurrentMediaTime()
            )
        }
    }

    override func touchesEnded(with event: NSEvent) {
        guard let view = self.view else { return }
        for touch in event.touches(matching: .ended, in: view) {
            let norm = touch.normalizedPosition
            let scenePoint = CGPoint(x: norm.x * size.width, y: norm.y * size.height)
            gameCoordinator?.touchTracker.touchEnded(
                id: ObjectIdentifier(touch),
                normalizedPosition: scenePoint,
                currentTime: CACurrentMediaTime()
            )
        }
    }

    override func touchesCancelled(with event: NSEvent) {
        guard let view = self.view else { return }
        for touch in event.touches(matching: .cancelled, in: view) {
            gameCoordinator?.touchTracker.touchCancelled(
                id: ObjectIdentifier(touch),
                currentTime: CACurrentMediaTime()
            )
        }
    }

    // MARK: - Creature Setup

    /// Initialize the Pushling creature and add it to the scene.
    /// Replaces the Phase 1 test node with a real composite creature.
    private func setupCreature() {
        let creature = CreatureNode()

        // Read stage from coordinator, falling back to spore for initial setup
        let initialStage = gameCoordinator?.creatureStage ?? .spore
        creature.configureForStage(initialStage)

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
            stage: initialStage,
            personality: .neutral,
            emotions: .neutral
        )
        stack.reset(
            stage: initialStage,
            position: CGPoint(x: creatureWorldX, y: SceneConstants.groundY),
            facing: .right
        )
        self.behaviorStack = stack

        // Initialize camera constraints for the starting stage (no animation)
        cameraController.updateConstraints(for: initialStage, animated: false)

        // Wire cinematic sequencer to camera
        cinematicSequencer.cameraController = cameraController

        // Wire evolution callback: route through cinematic sequencer
        creature.onEvolutionRequested = { [weak self] fromStage, toStage, startCeremony in
            self?.beginEvolutionCinematic(
                fromStage: fromStage,
                toStage: toStage,
                startCeremony: startCeremony
            )
        }

        // Cinematic cancel escape hatch is wired in gameCoordinator.didSet
        // (triple-tap on world during cinematic -> cancel sequence).

        // P4-T4-01: Diamond indicator — Claude's presence near the creature.
        // Added as child of creature so it follows automatically.
        let diamond = DiamondIndicator()
        creature.addChild(diamond)
        diamond.setup()
        self.diamondIndicator = diamond

        // P4-T4: Session lifecycle reactions coordinator
        let reactions = SessionLifecycleReactions(
            diamond: diamond,
            reflexLayer: stack.reflexes,
            aiDirectedLayer: stack.aiDirected
        )
        self.sessionReactions = reactions

        NSLog("[Pushling/Scene] Creature node active — %d nodes | Behavior stack ready"
              + " | Diamond indicator ready",
              creature.countNodes())
    }

    // MARK: - Stage Change Integration

    /// Called when the creature evolves to a new stage.
    /// Updates all dependent systems.
    func onCreatureStageChanged(_ newStage: GrowthStage) {
        // Update camera constraints for the new stage
        cameraController.updateConstraints(for: newStage)

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

    // MARK: - Cinematic Integration

    /// Begin a cinematic sequence for an evolution ceremony.
    /// Called by CreatureNode's onEvolutionRequested callback.
    private func beginEvolutionCinematic(
        fromStage: GrowthStage,
        toStage: GrowthStage,
        startCeremony: @escaping () -> Void
    ) {
        // Evolution ceremony total duration: 5.0s
        // (0.8 stillness + 1.2 gathering + 1.0 cocoon + 0.5 burst + 1.5 reveal)
        let ceremonyDuration: TimeInterval = 5.0

        // Freeze behavior stack before cinematic begins
        behaviorStack?.freezeForCinematic()

        let sequence = CinematicSequencer.evolutionSequence(
            ceremonyDuration: ceremonyDuration,
            onStartCeremony: startCeremony,
            onComplete: { [weak self] in
                self?.onCinematicEvolutionComplete(newStage: toStage)
            }
        )

        cinematicSequencer.begin(sequence)

        NSLog("[Pushling/Scene] Evolution cinematic started: %@ -> %@",
              "\(fromStage)", "\(toStage)")
    }

    /// Called when the evolution cinematic sequence finishes.
    /// Thaws behavior, triggers fog retreat, and notifies dependents.
    private func onCinematicEvolutionComplete(newStage: GrowthStage) {
        // Thaw behavior stack
        behaviorStack?.thawFromCinematic()

        // Update camera constraints for the new stage
        cameraController.updateConstraints(for: newStage)

        // Notify stage-dependent systems
        onEvolutionCeremonyComplete()

        NSLog("[Pushling/Scene] Evolution cinematic complete: now %@",
              "\(newStage)")
    }

    /// Synchronize touch suppression, behavior freeze state, and
    /// counter-scaling flags with the cinematic sequencer each frame.
    private func syncCinematicState() {
        let isActive = cinematicSequencer.isActive

        // Touch suppression: driven by sequencer
        gameCoordinator?.gestureRecognizer.isSuppressed =
            isActive && cinematicSequencer.suppressesTouch
        gameCoordinator?.creatureTouchHandler.isCinematicActive =
            isActive && cinematicSequencer.suppressesTouch

        // Counter-scaling disable
        disableCreatureCounterScaling =
            isActive && cinematicSequencer.disablesCounterScaling

        // Behavior freeze is managed via begin/complete callbacks,
        // not per-frame, to avoid repeated freeze/thaw calls.
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

    // MARK: - Hatching Ceremony Lifecycle

    /// Enter hatching mode: hide creature and normal UI, prepare for ceremony.
    /// Called by GameCoordinator when no creature is hatched.
    func enterHatchingMode() {
        isHatching = true

        // Hide creature node — it shouldn't be visible during the ceremony
        creatureNode?.isHidden = true

        // Hide HUD and progress bar — ceremony has its own visuals
        hudOverlay.rootNode.isHidden = true
        evolutionProgressBar.hideForCeremony()
        diamondIndicator?.isHidden = true

        // Create and store the ceremony
        let ceremony = HatchingCeremony(scene: self)
        self.hatchingCeremony = ceremony

        // Darken background to void (it's already black for OLED)
        // World should not scroll or render terrain during hatching
        worldManager.parallax.farLayer?.isHidden = true
        worldManager.parallax.midLayer?.isHidden = true
        worldManager.parallax.foreLayer?.isHidden = true

        NSLog("[Pushling/Scene] Entered hatching mode")
    }

    /// Exit hatching mode: show creature, restore normal UI, start systems.
    /// Called by GameCoordinator when the ceremony completes.
    func exitHatchingMode() {
        isHatching = false

        // Remove leftover ceremony nodes (spore node left by ceremony)
        // The ceremony leaves the spore node in the scene — remove it
        // since we'll use the real creature node instead.
        if let sporeNode = childNode(withName: "hatch_spore") {
            sporeNode.removeFromParent()
        }

        // Show creature node
        creatureNode?.isHidden = false

        // Restore HUD and progress bar
        hudOverlay.rootNode.isHidden = false
        evolutionProgressBar.showAfterCeremony()
        diamondIndicator?.isHidden = false

        // Restore world rendering
        worldManager.parallax.farLayer?.isHidden = false
        worldManager.parallax.midLayer?.isHidden = false
        worldManager.parallax.foreLayer?.isHidden = false

        // Clear ceremony reference
        hatchingCeremony = nil

        NSLog("[Pushling/Scene] Exited hatching mode — normal operation")
    }

    // MARK: - Session Lifecycle (P4-T4)

    /// The session manager reference — set via wireSessionManager().
    private weak var sessionManager: SessionManager?

    /// Wire the SessionManager's event handler to the scene's reaction coordinator.
    /// Call this after the scene is set up and the CommandRouter is initialized.
    func wireSessionManager(_ sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        guard let reactions = sessionReactions else {
            NSLog("[Pushling/Scene] Warning: sessionReactions not ready when wiring SessionManager")
            return
        }
        sessionManager.onSessionEvent = { [weak reactions] event in
            reactions?.handleSessionEvent(event)
        }
        NSLog("[Pushling/Scene] SessionManager wired to scene reactions")
    }

    /// Checks idle timeout gradient and updates diamond opacity.
    /// Called every 0.5s from the update loop (P4-T4-04).
    private func updateSessionIdleTimeout() {
        guard let sm = sessionManager, sm.isSessionActive else { return }
        let opacity = sm.updateIdleTimeout()
        diamondIndicator?.setIdleOpacity(opacity)
    }

    // MARK: - Behavior Output Application

    /// Applies the behavior stack output to the creature node and world.
    /// Breathing is handled by CreatureNode internally (per-frame sine wave)
    /// and is NOT overridden here — it always runs via CreatureNode.update().
    private func applyBehaviorOutput(_ output: BehaviorStackOutput) {
        guard let creature = creatureNode else { return }
        let state = output.creatureState

        // Update tracked world position, depth, and creature facing
        creatureWorldX = state.positionX
        creaturePositionZ = state.positionZ
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

    // MARK: - Toggle Button (now handled by TouchBarView as AppKit overlay)

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

        debugOverlayNode?.text = "v\(PushlingVersion.string) | \(fpsStr)fps | \(frameTimeStr)ms | "
            + "\(totalNodes)n | w:\(worldNodes) | \(biome.rawValue) | c\(complexity)"
    }

    /// Recursively counts all nodes in the scene tree.
    private func countAllNodes(in node: SKNode) -> Int {
        return 1 + node.children.reduce(0) { $0 + countAllNodes(in: $1) }
    }

    // MARK: - Screenshot Capture

    /// Captures the current scene as PNG data.
    /// Must be called on the main thread (SpriteKit rendering requirement).
    func captureScreenshot() -> Data? {
        guard let skView = self.view else {
            NSLog("[Pushling/Scene] Screenshot failed — no SKView")
            return nil
        }

        // Render the entire scene to an SKTexture
        guard let texture = skView.texture(from: self) else {
            NSLog("[Pushling/Scene] Screenshot failed — texture(from:) returned nil")
            return nil
        }

        // Convert SKTexture -> CGImage (non-optional in SpriteKit)
        let cgImage = texture.cgImage()

        // Encode CGImage as PNG using NSBitmapImageRep
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            NSLog("[Pushling/Scene] Screenshot failed — PNG encoding failed")
            return nil
        }

        return pngData
    }

    // MARK: - Debug Subsystems (stored properties for extension)

    /// Commit eating animation — lazily created, configured on first use.
    private(set) lazy var debugEatingAnimation: CommitEatingAnimation = {
        let a = CommitEatingAnimation()
        if let c = creatureNode { a.configure(creature: c, scene: self) }
        return a
    }()

    /// Speech coordinator — uses production coordinator from GameCoordinator
    /// when available, falls back to standalone instance (Gap 8).
    var debugSpeechCoordinator: SpeechCoordinator {
        if let gc = gameCoordinator {
            return gc.speechCoordinator
        }
        // Fallback for when GameCoordinator hasn't been set yet
        if _fallbackSpeechCoordinator == nil {
            let s = SpeechCoordinator()
            if let c = creatureNode {
                s.configure(creature: c, stage: c.currentStage,
                            personality: .neutral, creatureName: "Pushling",
                            speechCache: nil, narrationOverlay: nil)
            }
            _fallbackSpeechCoordinator = s
        }
        return _fallbackSpeechCoordinator!
    }
    private var _fallbackSpeechCoordinator: SpeechCoordinator?

    /// XP tracking for debug batch feeds.
    var debugXP: Int = 45
    var debugXPToNext: Int = 100
}
