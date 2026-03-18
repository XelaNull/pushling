// BehaviorStack.swift — The 4-layer behavior stack orchestrator
// Single source of truth for creature behavior. Called once per frame
// from PushlingScene.update().
//
// Update pipeline (must complete in <1ms):
//   1. Update all 4 layers (each computes its LayerOutput)
//   2. Resolve outputs (highest non-nil wins per property)
//   3. Apply blend controller transitions
//   4. Return blended state + breathing scale for creature node
//
// Layer priority (highest first):
//   1. Physics    — breathing, gravity, boundaries (always running)
//   2. Reflexes   — touch, commits, events (short-lived overrides)
//   3. AI-Directed — Claude MCP commands (intentional, 30s timeout)
//   4. Autonomous  — wander, idle, cat behaviors (always computing)

import Foundation
import CoreGraphics

// MARK: - Behavior Stack Output

/// The final output of the behavior stack each frame.
/// Contains everything needed to render the creature.
struct BehaviorStackOutput {
    /// The blended creature state (position, facing, all body part states).
    let creatureState: ResolvedCreatureState

    /// The breathing Y-scale multiplier (applied to body node yScale).
    /// This bypasses the blend controller — it's always applied directly.
    let breathingScale: CGFloat

    /// Whether the AI layer is currently active (for diamond indicator).
    let isAIActive: Bool

    /// Whether any reflexes are currently active.
    let isReflexActive: Bool
}

// MARK: - Behavior Stack

/// Orchestrates the 4-layer behavior stack and blend controller.
/// The single source of truth for all creature visual state.
final class BehaviorStack {

    // MARK: - Layers (in priority order)

    /// Layer 1 (highest): Physics — breathing, gravity, boundaries.
    let physics: PhysicsLayer

    /// Layer 2: Reflexes — short-lived overrides from input events.
    let reflexes: ReflexLayer

    /// Layer 3: AI-Directed — Claude MCP commands (skeleton until Phase 4).
    let aiDirected: AIDirectedLayer

    /// Layer 4 (lowest): Autonomous — wander, idle, cat behaviors.
    let autonomous: AutonomousLayer

    // MARK: - Blend Controller

    /// Smooths transitions between states.
    let blendController: BlendController

    // MARK: - Behavior Selector

    /// Weighted random behavior selection engine.
    let behaviorSelector: BehaviorSelector

    // MARK: - Configuration

    /// Current growth stage.
    var stage: GrowthStage = .critter {
        didSet {
            physics.stage = stage
            autonomous.stage = stage
        }
    }

    /// Current personality (set on init and personality drift).
    var personality: PersonalitySnapshot = .neutral {
        didSet {
            autonomous.personality = personality
            blendController.personality = personality
        }
    }

    /// Current emotional state (updated each frame or periodically).
    var emotions: EmotionalSnapshot = .neutral {
        didSet {
            autonomous.emotions = emotions
        }
    }

    /// Whether the behavior stack is frozen for a cinematic sequence.
    /// When frozen, autonomous state transitions stop and reflexes are
    /// suppressed. Physics (breathing) always continues.
    private(set) var isCinematicFrozen: Bool = false

    /// The default creature state (stage-dependent resting values).
    private var defaultState: ResolvedCreatureState

    /// Previous frame's resolved state (for detecting changes).
    private var previousResolvedState: ResolvedCreatureState?

    // MARK: - Init

    init(stage: GrowthStage = .critter,
         personality: PersonalitySnapshot = .neutral,
         emotions: EmotionalSnapshot = .neutral) {

        self.behaviorSelector = BehaviorSelector()
        self.physics = PhysicsLayer()
        self.reflexes = ReflexLayer()
        self.aiDirected = AIDirectedLayer()
        self.autonomous = AutonomousLayer(behaviorSelector: behaviorSelector)
        self.blendController = BlendController()

        self.stage = stage
        self.personality = personality
        self.emotions = emotions
        self.defaultState = ResolvedCreatureState.defaultState(stage: stage)

        // Propagate initial config
        physics.stage = stage
        autonomous.stage = stage
        autonomous.personality = personality
        autonomous.emotions = emotions
        blendController.personality = personality

        NSLog("[Pushling/Behavior] BehaviorStack initialized — stage: %@",
              String(describing: stage))
    }

    // MARK: - Frame Update

    /// Main update method. Called once per frame from PushlingScene.update().
    /// Must complete in <1ms.
    ///
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - currentTime: Absolute scene time (for sine waves, timeouts).
    /// - Returns: The complete behavior output for this frame.
    func update(deltaTime: TimeInterval,
                currentTime: TimeInterval) -> BehaviorStackOutput {

        // 0. Update selector's time reference
        behaviorSelector.updateTime(currentTime)

        // 1. Update all 4 layers — each computes its output independently
        let physicsOutput = physics.update(deltaTime: deltaTime,
                                            currentTime: currentTime)
        let reflexOutput = reflexes.update(deltaTime: deltaTime,
                                            currentTime: currentTime)
        let aiOutput = aiDirected.update(deltaTime: deltaTime,
                                          currentTime: currentTime)
        let autonomousOutput = autonomous.update(deltaTime: deltaTime,
                                                  currentTime: currentTime)

        // 2. Resolve outputs — per-property, highest non-nil wins
        let resolved = resolveOutputs(
            physics: physicsOutput,
            reflexes: reflexOutput,
            ai: aiOutput,
            autonomous: autonomousOutput
        )

        // 3. Detect state changes and notify blend controller
        detectStateChanges(resolved: resolved)

        // 4. Apply blend controller
        let blended = blendController.update(
            desired: resolved,
            isReflexActive: reflexes.isActive,
            isAIActive: aiDirected.isOutputting,
            deltaTime: deltaTime
        )

        // 5. Feed blended position back to physics for boundary tracking
        physics.updatePosition(x: blended.positionX)
        physics.updatePositionZ(blended.positionZ)

        // 5b. Sync clamped position back to autonomous layer so it doesn't
        //     accumulate past boundaries
        autonomous.syncPosition(blended.positionX)

        // 6. Handle boundary hits — if physics says we hit a boundary,
        //    tell autonomous to turn around
        if let boundary = physics.nearBoundary() {
            // Turn away from the boundary
            let awayDirection = boundary == .left ? Direction.right : .left
            autonomous.requestDirectionChange(toward: awayDirection)
        }

        // Track previous state
        previousResolvedState = resolved

        return BehaviorStackOutput(
            creatureState: blended,
            breathingScale: physics.breathingScale,
            isAIActive: aiDirected.isActive,
            isReflexActive: reflexes.isActive
        )
    }

    // MARK: - Layer Output Resolution

    /// Resolves 4 layer outputs into a single desired state.
    /// Per-property, the highest-priority layer with a non-nil value wins.
    ///
    /// Priority order: Physics > Reflexes > AI-Directed > Autonomous
    private func resolveOutputs(physics: LayerOutput,
                                 reflexes: LayerOutput,
                                 ai: LayerOutput,
                                 autonomous: LayerOutput) -> ResolvedCreatureState {

        // Helper: resolve a single property through the priority chain
        func resolve<T>(_ physics: T?, _ reflexes: T?,
                        _ ai: T?, _ autonomous: T?,
                        default defaultVal: T) -> T {
            physics ?? reflexes ?? ai ?? autonomous ?? defaultVal
        }

        let defaults = defaultState

        return ResolvedCreatureState(
            positionX: resolve(
                physics.positionX, reflexes.positionX,
                ai.positionX, autonomous.positionX,
                default: defaults.positionX
            ),
            positionY: resolve(
                physics.positionY, reflexes.positionY,
                ai.positionY, autonomous.positionY,
                default: defaults.positionY
            ),
            positionZ: resolve(
                physics.positionZ, reflexes.positionZ,
                ai.positionZ, autonomous.positionZ,
                default: defaults.positionZ
            ),
            facing: resolve(
                physics.facing, reflexes.facing,
                ai.facing, autonomous.facing,
                default: defaults.facing
            ),
            walkSpeed: resolve(
                physics.walkSpeed, reflexes.walkSpeed,
                ai.walkSpeed, autonomous.walkSpeed,
                default: defaults.walkSpeed
            ),
            bodyState: resolve(
                physics.bodyState, reflexes.bodyState,
                ai.bodyState, autonomous.bodyState,
                default: defaults.bodyState
            ),
            earLeftState: resolve(
                physics.earLeftState, reflexes.earLeftState,
                ai.earLeftState, autonomous.earLeftState,
                default: defaults.earLeftState
            ),
            earRightState: resolve(
                physics.earRightState, reflexes.earRightState,
                ai.earRightState, autonomous.earRightState,
                default: defaults.earRightState
            ),
            eyeLeftState: resolve(
                physics.eyeLeftState, reflexes.eyeLeftState,
                ai.eyeLeftState, autonomous.eyeLeftState,
                default: defaults.eyeLeftState
            ),
            eyeRightState: resolve(
                physics.eyeRightState, reflexes.eyeRightState,
                ai.eyeRightState, autonomous.eyeRightState,
                default: defaults.eyeRightState
            ),
            tailState: resolve(
                physics.tailState, reflexes.tailState,
                ai.tailState, autonomous.tailState,
                default: defaults.tailState
            ),
            mouthState: resolve(
                physics.mouthState, reflexes.mouthState,
                ai.mouthState, autonomous.mouthState,
                default: defaults.mouthState
            ),
            whiskerState: resolve(
                physics.whiskerState, reflexes.whiskerState,
                ai.whiskerState, autonomous.whiskerState,
                default: defaults.whiskerState
            ),
            auraState: resolve(
                physics.auraState, reflexes.auraState,
                ai.auraState, autonomous.auraState,
                default: defaults.auraState
            ),
            pawStates: resolve(
                physics.pawStates, reflexes.pawStates,
                ai.pawStates, autonomous.pawStates,
                default: defaults.pawStates
            )
        )
    }

    // MARK: - State Change Detection

    /// Detects meaningful state changes to notify the blend controller
    /// of the appropriate transition type.
    private func detectStateChanges(resolved: ResolvedCreatureState) {
        guard let previous = previousResolvedState else { return }

        // Direction change
        if resolved.facing != previous.facing {
            blendController.notifyDirectionChange()
        }

        // Expression change (any body part state changed)
        let expressionChanged =
            resolved.bodyState != previous.bodyState
            || resolved.earLeftState != previous.earLeftState
            || resolved.earRightState != previous.earRightState
            || resolved.eyeLeftState != previous.eyeLeftState
            || resolved.eyeRightState != previous.eyeRightState
            || resolved.tailState != previous.tailState
            || resolved.mouthState != previous.mouthState
            || resolved.whiskerState != previous.whiskerState

        if expressionChanged {
            blendController.notifyExpressionChange()
        }
    }

    // MARK: - External API

    /// Triggers a reflex (called by input handlers, commit processors, etc.).
    /// Suppressed during cinematic freeze.
    func triggerReflex(_ definition: ReflexDefinition,
                       at currentTime: TimeInterval) {
        guard !isCinematicFrozen else { return }
        reflexes.trigger(definition, at: currentTime)
    }

    /// Triggers a named reflex. Suppressed during cinematic freeze.
    func triggerReflex(named name: String, at currentTime: TimeInterval) {
        guard !isCinematicFrozen else { return }
        reflexes.trigger(named: name, at: currentTime)
    }

    /// Enqueues an AI command (called by MCP command handler).
    func enqueueAICommand(_ command: AICommand) {
        aiDirected.enqueue(command: command)
    }

    /// Cancels all AI commands (e.g., on prolonged touch).
    func cancelAICommands() {
        aiDirected.cancelAll()
    }

    /// Notifies that the Claude session has ended.
    func aiSessionEnded() {
        aiDirected.sessionEnded()
    }

    /// Sets the creature into sleep mode (modifies breathing).
    func setSleeping(_ sleeping: Bool) {
        physics.isSleeping = sleeping
        if sleeping {
            autonomous.forceState(.resting)
        }
    }

    /// Initiates a jump with the given initial velocity.
    func startJump(initialVelocity: CGFloat) {
        physics.startJump(initialVelocity: initialVelocity)
    }

    /// Updates the default state when the creature's stage changes.
    func updateStage(_ newStage: GrowthStage) {
        stage = newStage
        defaultState = ResolvedCreatureState.defaultState(stage: newStage)
        NSLog("[Pushling/Behavior] Stage updated to %@",
              String(describing: newStage))
    }

    /// Freeze the behavior stack for a cinematic sequence.
    /// Autonomous layer stops state transitions; reflexes are suppressed.
    /// Physics (breathing) always continues.
    func freezeForCinematic() {
        isCinematicFrozen = true
        autonomous.isFrozen = true
        reflexes.clearAll()
        NSLog("[Pushling/Behavior] Frozen for cinematic")
    }

    /// Thaw the behavior stack after a cinematic sequence.
    /// Autonomous layer resumes normal state transitions.
    func thawFromCinematic() {
        isCinematicFrozen = false
        autonomous.isFrozen = false
        NSLog("[Pushling/Behavior] Thawed from cinematic")
    }

    /// Resets the behavior stack to initial state.
    func reset(stage: GrowthStage, position: CGPoint,
               facing: Direction = .right) {
        self.stage = stage
        defaultState = ResolvedCreatureState.defaultState(
            stage: stage, facing: facing
        )
        physics.currentX = position.x
        physics.currentY = position.y
        physics.currentZ = 0.0
        autonomous.syncPosition(position.x)
        blendController.reset(position: position, facing: facing)
        reflexes.clearAll()
        aiDirected.cancelAll()
        autonomous.forceState(.idle)
        previousResolvedState = nil

        NSLog("[Pushling/Behavior] BehaviorStack reset — stage: %@, pos: (%.1f, %.1f)",
              String(describing: stage), position.x, position.y)
    }
}
