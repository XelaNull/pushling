// AutonomousLayer.swift — Layer 4 (lowest priority): Autonomous behavior
// The creature's own mind. Wanders, idles, performs cat behaviors and taught tricks.
// Always computing even when higher layers override.
// State machine: walking -> idle -> behavior/taughtBehavior -> resting

import Foundation
import CoreGraphics

// MARK: - Autonomous State

/// The autonomous layer's internal state machine.
enum AutonomousState {
    /// Walking in the current facing direction.
    case walking
    /// Standing still, performing micro-behaviors (blink, tail sway).
    case idle
    /// Performing a specific cat behavior (from behavior selector).
    case behavior(name: String)
    /// Performing a taught behavior (from TaughtBehaviorEngine).
    case taughtBehavior(name: String)
    /// Interacting with a placed world object (AttractionScorer + ObjectInteractionEngine).
    case objectInteracting(objectID: String)
    /// Low-energy rest state (loaf, sit, sleep).
    case resting
}

// MARK: - Autonomous Layer

final class AutonomousLayer: BehaviorLayer {

    // MARK: - Dependencies

    /// Personality snapshot — set by BehaviorStack on init and personality change.
    var personality: PersonalitySnapshot = .neutral

    /// Emotional snapshot — updated by BehaviorStack each frame.
    var emotions: EmotionalSnapshot = .neutral

    /// Current growth stage — gates which behaviors are available.
    var stage: GrowthStage = .critter

    /// The behavior selector for choosing cat behaviors.
    let behaviorSelector: BehaviorSelector

    // MARK: - Taught Behavior Dependencies (set by GameCoordinator)

    var taughtEngine: TaughtBehaviorEngine?
    var taughtMastery: MasteryTracker?
    var taughtGovernor: IdleRotationGovernor?
    var taughtDefinitions: (() -> [String: ChoreographyDefinition])?
    var onTaughtBehaviorCompleted: ((String, ChoreographyDefinition,
                                     TimeInterval) -> Void)?

    // MARK: - Object Interaction Dependencies (set by GameCoordinator)

    /// Query placed world objects: returns (id, interactionType, x position).
    var objectQuery: (() -> [(id: String, type: String, x: CGFloat)])?
    var attractionScorer: AttractionScorer?
    var objectInteractionEngine: ObjectInteractionEngine?
    var onObjectInteractionCompleted: ((String, String, Double) -> Void)?

    // MARK: - Internal State

    private(set) var state: AutonomousState = .idle
    private var stateTimer: TimeInterval = 0
    private var stateDuration: TimeInterval = 3.0
    private var facing: Direction = .right
    private(set) var currentX: CGFloat = SceneConstants.sceneWidth / 2
    private var currentWalkSpeed: CGFloat = 0
    private var pendingDirectionChange: Bool = false
    private var walkCyclePhase: Double = 0
    private var blinkTimer: TimeInterval = 0
    private var nextBlinkInterval: TimeInterval = 5.0
    private var isBlinking: Bool = false
    private var blinkPhase: TimeInterval = 0
    private var tailSwayPhase: Double = 0
    private var activeBehavior: ActiveBehavior?
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Constants

    private static let blinkDuration: TimeInterval = 0.15
    private static let tailSwayBaseAmplitude: Double = 0.209
    private static let tailSwayBasePeriod: Double = 3.0

    // MARK: - Init

    init(behaviorSelector: BehaviorSelector) {
        self.behaviorSelector = behaviorSelector
        regenerateBlinkInterval()
        regenerateStateDuration()
    }

    // MARK: - BehaviorLayer

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) -> LayerOutput {
        var output = LayerOutput()

        // Always update micro-behaviors (blink, tail sway)
        // even when in non-idle states — they layer underneath
        updateBlink(deltaTime: deltaTime, output: &output)
        updateTailSway(deltaTime: deltaTime, currentTime: currentTime,
                       output: &output)

        // Update the state machine
        stateTimer += deltaTime
        updateStateMachine(deltaTime: deltaTime, currentTime: currentTime,
                           output: &output)

        // Always output current position and facing — even during idle/behavior
        // so the creature doesn't snap to default position
        if output.positionX == nil {
            output.positionX = currentX
        }
        output.facing = facing

        return output
    }

    /// Sync position from external source (e.g., after physics boundary clamping)
    func syncPosition(_ x: CGFloat) {
        currentX = x
    }

    // MARK: - State Machine

    private func updateStateMachine(deltaTime: TimeInterval,
                                    currentTime: TimeInterval,
                                    output: inout LayerOutput) {
        switch state {
        case .walking:
            updateWalking(deltaTime: deltaTime, output: &output)

        case .idle:
            updateIdle(deltaTime: deltaTime, output: &output)

        case .behavior(let name):
            updateBehavior(name: name, deltaTime: deltaTime, output: &output)

        case .taughtBehavior(let name):
            updateTaughtBehavior(name: name, deltaTime: deltaTime,
                                 currentTime: currentTime, output: &output)

        case .objectInteracting(let objectID):
            updateObjectInteraction(objectID: objectID,
                                     deltaTime: deltaTime,
                                     output: &output)

        case .resting:
            updateResting(deltaTime: deltaTime, output: &output)
        }

        // Global check: energy-based resting (don't interrupt taught behaviors
        // or object interactions)
        if case .resting = state {
            if emotions.energy > 40 {
                transitionTo(.idle)
            }
        } else if case .taughtBehavior = state {
            // Let taught behaviors finish — don't interrupt for rest
        } else if case .objectInteracting = state {
            // Let object interactions finish — don't interrupt for rest
        } else if emotions.energy < 20 {
            transitionTo(.resting)
        }
    }

    // MARK: - Walking State

    private func updateWalking(deltaTime: TimeInterval,
                               output: inout LayerOutput) {
        // Walk speed via PersonalityFilter (personality + emotion + jitter)
        let baseSpeed = stage.baseWalkSpeed
        let filtered = PersonalityFilter.modulatedWalkSpeed(
            base: baseSpeed, personality: personality,
            emotionalEnergy: emotions.energy)
        currentWalkSpeed = CGFloat(PersonalityFilter.applyJitter(
            base: Double(filtered), jitterFactor: randomJitter(range: 1.0),
            personality: personality))

        // Integrate position
        currentX += currentWalkSpeed * (facing == .right ? 1 : -1) * CGFloat(deltaTime)
        output.positionX = currentX
        output.walkSpeed = currentWalkSpeed
        output.bodyState = "stand"

        // Walk cycle: diagonal gait (FL+BR, then FR+BL)
        let cycleSpeed = Double(currentWalkSpeed) / Double(max(baseSpeed, 1))
        walkCyclePhase += deltaTime * cycleSpeed * 2.0
        let phase = walkCyclePhase.truncatingRemainder(dividingBy: 1.0)
        if phase < 0.5 {
            output.pawStates = ["fl": "walk", "br": "walk", "fr": "ground", "bl": "ground"]
        } else {
            output.pawStates = ["fl": "ground", "br": "ground", "fr": "walk", "bl": "walk"]
        }

        // Ear bounce with steps (subtle)
        if stage >= .critter {
            output.earLeftState = "neutral"
            output.earRightState = "neutral"
        }

        // Whiskers back slightly during movement
        if stage >= .beast {
            output.whiskerState = "neutral"
        }

        // Check for state transition
        if stateTimer >= stateDuration {
            // Direction change probability modulated by personality focus
            let dirProb = PersonalityFilter.directionChangeProbability(
                base: 0.15, personality: personality
            )
            if randomChance(dirProb) {
                pendingDirectionChange = true
            }
            transitionTo(.idle)
        }
    }

    // MARK: - Idle State

    private func updateIdle(deltaTime: TimeInterval,
                            output: inout LayerOutput) {
        output.walkSpeed = 0
        output.bodyState = "stand"
        output.pawStates = ["fl": "ground", "fr": "ground",
                            "bl": "ground", "br": "ground"]

        if stage >= .critter {
            output.earLeftState = "neutral"
            output.earRightState = "neutral"
        }
        if stage >= .beast {
            output.whiskerState = "neutral"
        }

        // Handle pending direction change (will be blended by BlendController)
        if pendingDirectionChange {
            facing = facing.flipped
            pendingDirectionChange = false
        }

        // Check for state transition
        if stateTimer >= stateDuration {
            // Check if a placed object is attractive enough to approach
            if let objectTarget = selectObjectInteraction() {
                startObjectInteraction(objectTarget)
                return
            }

            // Check if a taught behavior should play
            if let selected = selectTaughtBehavior() {
                startTaughtBehavior(selected)
                return
            }

            // Otherwise, select a cat behavior
            taughtGovernor?.recordCatBehavior()
            let selectedBehavior = behaviorSelector.selectBehavior(
                stage: stage,
                personality: personality,
                emotions: emotions
            )

            if let behavior = selectedBehavior {
                transitionTo(.behavior(name: behavior.name))
                activeBehavior = ActiveBehavior(
                    definition: behavior,
                    elapsed: 0
                )
            } else {
                transitionTo(.walking)
            }
        }
    }

    // MARK: - Behavior State

    private func updateBehavior(name: String, deltaTime: TimeInterval,
                                output: inout LayerOutput) {
        guard var behavior = activeBehavior else {
            transitionTo(.idle)
            return
        }

        behavior.elapsed += deltaTime
        activeBehavior = behavior

        // Delegate choreography to BehaviorChoreography (separate file)
        facing = BehaviorChoreography.apply(
            behavior: behavior,
            stage: stage,
            facing: facing,
            output: &output
        )

        // Check if behavior is complete
        if behavior.elapsed >= behavior.definition.duration {
            behaviorSelector.recordBehaviorCompletion(name: name)
            activeBehavior = nil
            transitionTo(.idle)
        }
    }

    // MARK: - Resting State

    private func updateResting(deltaTime: TimeInterval,
                               output: inout LayerOutput) {
        output.walkSpeed = 0
        output.bodyState = "sleep_curl"
        output.eyeLeftState = "closed"
        output.eyeRightState = "closed"
        output.tailState = "wrap"
        if stage >= .critter {
            output.earLeftState = "droop"
            output.earRightState = "droop"
        }
        output.pawStates = ["fl": "tuck", "fr": "tuck",
                            "bl": "tuck", "br": "tuck"]
    }

    // MARK: - Blink System

    /// Autonomous blink cycle: random interval 3-7s, 0.15s animation.
    private func updateBlink(deltaTime: TimeInterval,
                             output: inout LayerOutput) {
        guard stage >= .drop else { return }  // Spores have no eyes

        if isBlinking {
            blinkPhase += deltaTime
            if blinkPhase < Self.blinkDuration / 3.0 {
                // Closing
                output.eyeLeftState = "closed"
                output.eyeRightState = "closed"
            } else if blinkPhase < Self.blinkDuration * 2.0 / 3.0 {
                // Hold closed
                output.eyeLeftState = "closed"
                output.eyeRightState = "closed"
            } else if blinkPhase < Self.blinkDuration {
                // Opening
                output.eyeLeftState = "open"
                output.eyeRightState = "open"
            } else {
                // Blink complete
                isBlinking = false
                blinkPhase = 0
                regenerateBlinkInterval()

                // 8% chance of double blink
                if randomChance(0.08) {
                    isBlinking = true
                    blinkPhase = 0
                }
            }
        } else {
            blinkTimer += deltaTime
            if blinkTimer >= nextBlinkInterval {
                // Don't blink if eyes are already closed
                if case .resting = state { return }
                isBlinking = true
                blinkPhase = 0
                blinkTimer = 0
            }
        }
    }

    // MARK: - Tail Sway

    /// Continuous tail sway using sine wave, personality-modulated.
    private func updateTailSway(deltaTime: TimeInterval,
                                currentTime: TimeInterval,
                                output: inout LayerOutput) {
        guard stage >= .critter else { return }

        // If we're in a behavior that overrides the tail, skip
        if case .behavior = state, output.tailState != nil { return }
        if case .taughtBehavior = state, output.tailState != nil { return }
        if case .resting = state { return }

        // Personality-modulated tail sway via PersonalityFilter
        let amplitude = PersonalityFilter.tailSwayAmplitude(
            base: Self.tailSwayBaseAmplitude, personality: personality)
        let period = PersonalityFilter.applyJitter(
            base: PersonalityFilter.tailSwayPeriod(
                base: Self.tailSwayBasePeriod, personality: personality),
            jitterFactor: randomJitter(range: 1.0), personality: personality)

        tailSwayPhase += deltaTime
        output.tailState = output.tailState ?? "sway"
    }

    // MARK: - State Transitions

    func transitionTo(_ newState: AutonomousState) {
        state = newState
        stateTimer = 0
        regenerateStateDuration()
    }

    /// Generates a personality-influenced duration for the current state.
    private func regenerateStateDuration() {
        switch state {
        case .walking:
            // 3-12s base, modulated by PersonalityFilter
            let base = randomRange(3.0, 12.0)
            stateDuration = PersonalityFilter.walkDuration(
                base: base, personality: personality
            )
            applyDisciplineJitter(&stateDuration)

        case .idle:
            // 2-8s base, modulated by PersonalityFilter
            let base = randomRange(2.0, 8.0)
            stateDuration = PersonalityFilter.idleDuration(
                base: base, personality: personality,
                emergent: .none
            )
            applyDisciplineJitter(&stateDuration)

        case .behavior:
            stateDuration = activeBehavior?.definition.duration ?? 3.0

        case .taughtBehavior, .objectInteracting, .resting:
            stateDuration = .infinity  // External systems control duration
        }

        // Ensure minimum sane duration
        stateDuration = max(stateDuration, 0.5)
    }

    /// Applies discipline-based jitter to a timing value via PersonalityFilter.
    private func applyDisciplineJitter(_ value: inout TimeInterval) {
        let jitterFactor = randomJitter(range: 1.0)  // raw [-1, 1]
        value = PersonalityFilter.applyJitter(
            base: value, jitterFactor: jitterFactor,
            personality: personality
        )
    }

    // MARK: - Blink Interval

    private func regenerateBlinkInterval() {
        // Personality-influenced blink interval via PersonalityFilter
        let range = PersonalityFilter.blinkInterval(personality: personality)
        nextBlinkInterval = randomRange(range.lowerBound, range.upperBound)
    }

    // MARK: - External Events

    /// Called when the creature reaches a boundary and must turn around.
    func requestDirectionChange(toward direction: Direction) {
        facing = direction
    }

    /// Force the creature into a specific state (e.g., for sleep sequence).
    func forceState(_ newState: AutonomousState) {
        transitionTo(newState)
    }

    /// Returns the current facing direction.
    var currentFacing: Direction { facing }

    // MARK: - Random Utilities

    private func randomRange(_ min: Double, _ max: Double) -> Double {
        Double.random(in: min...max, using: &rng)
    }

    private func randomChance(_ probability: Double) -> Bool {
        Double.random(in: 0...1, using: &rng) < probability
    }

    private func randomJitter(range: Double) -> Double {
        Double.random(in: -range...range, using: &rng)
    }
}

// MARK: - Active Behavior

/// Tracks a behavior that's currently being performed.
struct ActiveBehavior {
    let definition: BehaviorDefinition
    var elapsed: TimeInterval
}
