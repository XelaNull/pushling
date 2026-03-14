// AutonomousLayer.swift — Layer 4 (lowest priority): Autonomous behavior
// The creature's own mind. Wanders, idles, performs cat behaviors.
//
// This layer NEVER stops computing. Even when higher layers override it,
// the autonomous state machine keeps running underneath so that when
// control returns, behavior resumes immediately (within 1 frame).
//
// State machine: walking -> idle -> behavior -> resting
// All transitions use personality-influenced random timings.

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

    // MARK: - Internal State

    /// Current state in the autonomous state machine.
    private(set) var state: AutonomousState = .idle

    /// Time spent in the current state (seconds).
    private var stateTimer: TimeInterval = 0

    /// Duration the creature will stay in the current state before transitioning.
    private var stateDuration: TimeInterval = 3.0

    /// Current facing direction (maintained independently of physics).
    private var facing: Direction = .right

    /// Current world X position — integrated from walkSpeed each frame.
    private(set) var currentX: CGFloat = 542.5

    /// Current walk speed (points/second), personality-modulated.
    private var currentWalkSpeed: CGFloat = 0

    /// Whether a direction reversal has been requested (boundary or random).
    private var pendingDirectionChange: Bool = false

    /// Time accumulator for the walk cycle animation.
    private var walkCyclePhase: Double = 0

    /// Time accumulator for blink timing.
    private var blinkTimer: TimeInterval = 0

    /// Next blink interval (randomized per cycle).
    private var nextBlinkInterval: TimeInterval = 5.0

    /// Whether we're currently mid-blink.
    private var isBlinking: Bool = false

    /// Blink phase timer (for the 0.15s blink animation).
    private var blinkPhase: TimeInterval = 0

    /// Time accumulator for tail sway.
    private var tailSwayPhase: Double = 0

    /// The currently active behavior (when in .behavior state).
    private var activeBehavior: ActiveBehavior?

    /// Random number generator with a predictable-ish seed for personality.
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Constants

    /// Blink animation total duration (close + hold + open).
    private static let blinkDuration: TimeInterval = 0.15

    /// Tail sway base amplitude in radians (12 degrees).
    private static let tailSwayBaseAmplitude: Double = 0.209

    /// Tail sway base period in seconds.
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
        updateStateMachine(deltaTime: deltaTime, output: &output)

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
                                    output: inout LayerOutput) {
        switch state {
        case .walking:
            updateWalking(deltaTime: deltaTime, output: &output)

        case .idle:
            updateIdle(deltaTime: deltaTime, output: &output)

        case .behavior(let name):
            updateBehavior(name: name, deltaTime: deltaTime, output: &output)

        case .resting:
            updateResting(deltaTime: deltaTime, output: &output)
        }

        // Global check: energy-based resting
        if case .resting = state {
            // Already resting — check if we should wake up
            if emotions.energy > 40 {
                transitionTo(.idle)
            }
        } else if emotions.energy < 20 {
            // Should rest
            transitionTo(.resting)
        }
    }

    // MARK: - Walking State

    private func updateWalking(deltaTime: TimeInterval,
                               output: inout LayerOutput) {
        // Calculate personality-modulated walk speed
        let baseSpeed = stage.baseWalkSpeed
        let energyMod = 0.6 + personality.energy * 0.8  // [0.6, 1.4]
        let emotionMod = 0.5 + emotions.energy / 100.0 * 0.5  // [0.5, 1.0]
        let jitter = 1.0 + randomJitter(range: 0.1)  // +/-10%
        currentWalkSpeed = baseSpeed * CGFloat(energyMod * emotionMod * jitter)

        // Integrate speed into position
        let direction: CGFloat = facing == .right ? 1.0 : -1.0
        currentX += currentWalkSpeed * direction * CGFloat(deltaTime)

        output.positionX = currentX
        output.walkSpeed = currentWalkSpeed
        output.bodyState = "stand"

        // Walk cycle animation for paws
        let cycleSpeed = Double(currentWalkSpeed) / Double(baseSpeed > 0 ? baseSpeed : 1)
        walkCyclePhase += deltaTime * cycleSpeed * 2.0  // 2.0 = base cycle rate

        // Diagonal gait: FL+BR, then FR+BL
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
            // 15% chance to change direction on walk -> idle
            let shouldChangeDirection = randomChance(0.15)
            if shouldChangeDirection {
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
            // Try to select a behavior
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
                // No behavior available — go back to walking
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
        if case .resting = state { return }

        // Personality modulation
        let amplitudeMod = 0.7 + personality.energy * 0.6  // [0.7, 1.3]
        let periodMod = 0.7 + (1.0 - personality.energy) * 0.6  // [0.7, 1.3]

        // Discipline affects consistency
        let jitterRange = 0.02 + (1.0 - personality.discipline) * 0.13
        let periodJitter = 1.0 + randomJitter(range: jitterRange)

        let amplitude = Self.tailSwayBaseAmplitude * amplitudeMod
        let period = Self.tailSwayBasePeriod * periodMod * periodJitter

        tailSwayPhase += deltaTime

        // During walking, phase-shift tail from walk cycle by 0.4
        var phaseOffset: Double = 0
        if case .walking = state {
            phaseOffset = walkCyclePhase * 0.4
        }

        // Calculate angle (used by TailController for actual rotation).
        // The value is stored in tailSwayPhase for external access.
        _ = amplitude * sin(2.0 * Double.pi * (tailSwayPhase + phaseOffset) / period)

        // Output the tail state — the actual sine rotation is computed
        // per-frame by the TailController based on its own parameters.
        output.tailState = output.tailState ?? "sway"
    }

    // MARK: - State Transitions

    private func transitionTo(_ newState: AutonomousState) {
        state = newState
        stateTimer = 0
        regenerateStateDuration()
    }

    /// Generates a personality-influenced duration for the current state.
    private func regenerateStateDuration() {
        switch state {
        case .walking:
            // 3-12s, personality-influenced
            let focusMod = 0.8 + personality.focus * 0.4  // [0.8, 1.2]
            let energyMod = 1.5 - personality.energy * 1.0  // [0.5, 1.5]
            let base = randomRange(3.0, 12.0)
            stateDuration = base * focusMod * energyMod
            applyDisciplineJitter(&stateDuration)

        case .idle:
            // 2-8s, personality-influenced
            // Hyper creatures = less idle time
            let energyMod = 0.5 + personality.energy * 0.5  // inverted: [0.5, 1.0]
            let base = randomRange(2.0, 8.0)
            stateDuration = base * (1.5 - energyMod)  // Hyper -> shorter idle
            applyDisciplineJitter(&stateDuration)

        case .behavior:
            // Duration comes from the behavior definition
            if let def = activeBehavior?.definition {
                stateDuration = def.duration
            } else {
                stateDuration = 3.0
            }

        case .resting:
            // Rest until energy recovers above 40
            stateDuration = .infinity
        }

        // Ensure minimum sane duration
        stateDuration = max(stateDuration, 0.5)
    }

    /// Applies discipline-based jitter to a timing value.
    private func applyDisciplineJitter(_ value: inout TimeInterval) {
        // Chaotic (0.0) = +/-20% jitter, Disciplined (1.0) = +/-3% jitter
        let jitterPercent = 0.03 + (1.0 - personality.discipline) * 0.17
        let jitter = 1.0 + randomJitter(range: jitterPercent)
        value *= jitter
    }

    // MARK: - Blink Interval

    private func regenerateBlinkInterval() {
        // Personality-influenced blink interval
        // High energy: 2.5-5.0s, Low energy: 4.0-9.0s
        let minInterval = lerp(4.0, 2.5, personality.energy)
        let maxInterval = lerp(9.0, 5.0, personality.energy)
        nextBlinkInterval = randomRange(minInterval, maxInterval)
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
