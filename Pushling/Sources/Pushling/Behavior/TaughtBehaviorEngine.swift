// TaughtBehaviorEngine.swift — Executes taught behaviors as SpriteKit animations
// Translates ChoreographyDefinition keyframes into per-frame LayerOutput.
// Called by the AutonomousLayer when a taught behavior is selected.
//
// Each frame: find active keyframes per track, interpolate, map to LayerOutput.
// Physics layer (breathing) always overrides — never interrupted.
// Omitted tracks return nil — autonomous behavior continues underneath.
//
// Frame budget: <0.3ms per behavior per frame.

import Foundation
import CoreGraphics

// MARK: - Taught Behavior Execution State

/// Tracks the execution state of a currently-playing taught behavior.
struct TaughtBehaviorExecution {
    let definition: ChoreographyDefinition
    let masteryLevel: MasteryLevel
    let personalityMods: PersonalityModifiers
    let startTime: TimeInterval
    var elapsed: TimeInterval = 0
    var isComplete: Bool = false

    /// Effective duration after personality modulation.
    var effectiveDuration: TimeInterval {
        definition.durationSeconds * personalityMods.speedMultiplier
    }

    /// Normalized progress [0.0, 1.0].
    var progress: Double {
        Swift.min(elapsed / effectiveDuration, 1.0)
    }
}

/// Personality-derived modifiers applied to all taught behavior execution.
struct PersonalityModifiers {
    /// Speed multiplier: 0.7 (calm) to 1.3 (hyper).
    let speedMultiplier: Double
    /// Amplitude multiplier: scales movement intensity.
    let amplitudeMultiplier: Double
    /// Speech probability: chance speech keyframes fire.
    let speechProbability: Double
    /// Timing jitter: +/- percentage applied to keyframe times.
    let timingJitter: Double
    /// Discipline consistency: lower = more variation each time.
    let consistencyFactor: Double

    static func from(personality: PersonalitySnapshot) -> PersonalityModifiers {
        // Energy scales speed: calm (0.0) = 0.7x, hyper (1.0) = 1.3x
        let speed = 0.7 + personality.energy * 0.6
        // Energy also scales amplitude
        let amplitude = 0.7 + personality.energy * 0.6
        // Verbosity controls speech probability
        let speech = 0.3 + personality.verbosity * 0.7
        // Focus controls timing precision (inverted: low focus = more jitter)
        let jitter = 0.03 + (1.0 - personality.focus) * 0.17
        // Discipline controls consistency
        let consistency = 0.5 + personality.discipline * 0.5

        return PersonalityModifiers(
            speedMultiplier: 1.0 / speed,  // Invert: hyper = shorter duration
            amplitudeMultiplier: amplitude,
            speechProbability: speech,
            timingJitter: jitter,
            consistencyFactor: consistency
        )
    }
}

// MARK: - TaughtBehaviorEngine

/// Executes taught choreography definitions, producing LayerOutput per frame.
/// Singleton engine — one behavior plays at a time.
final class TaughtBehaviorEngine {

    // MARK: - State

    /// The currently executing taught behavior, if any.
    private(set) var currentExecution: TaughtBehaviorExecution?

    /// Random seed for per-execution variation.
    private var rng = SystemRandomNumberGenerator()

    /// Per-execution jitter cache (computed once at start, reused).
    private var keyframeJitters: [String: [Double]] = [:]

    // MARK: - Begin Execution

    /// Starts executing a taught behavior.
    /// - Parameters:
    ///   - definition: The validated choreography to play.
    ///   - mastery: Current mastery level (affects fumbles, flair).
    ///   - personality: Creature's personality (affects speed, amplitude).
    ///   - currentTime: Scene time at start.
    func begin(definition: ChoreographyDefinition,
               mastery: MasteryLevel,
               personality: PersonalitySnapshot,
               currentTime: TimeInterval) {
        let mods = PersonalityModifiers.from(personality: personality)

        currentExecution = TaughtBehaviorExecution(
            definition: definition,
            masteryLevel: mastery,
            personalityMods: mods,
            startTime: currentTime
        )

        // Pre-compute per-keyframe timing jitter for this execution
        generateJitters(for: definition, mods: mods)

        NSLog("[Pushling/Teach] Begin executing '%@' at %@ mastery "
              + "(speed: %.2fx, amplitude: %.2fx)",
              definition.name, mastery.displayName,
              mods.speedMultiplier, mods.amplitudeMultiplier)
    }

    // MARK: - Per-Frame Update

    /// Produces the LayerOutput for the current frame of a taught behavior.
    /// Returns nil if no behavior is executing.
    ///
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - currentTime: Absolute scene time.
    /// - Returns: LayerOutput with track-driven body part states, or nil.
    func update(deltaTime: TimeInterval,
                currentTime: TimeInterval) -> LayerOutput? {
        guard var execution = currentExecution else { return nil }

        execution.elapsed += deltaTime

        // Check completion
        if execution.elapsed >= execution.effectiveDuration {
            execution.isComplete = true
            currentExecution = nil
            NSLog("[Pushling/Teach] Completed '%@'",
                  execution.definition.name)
            return nil
        }

        currentExecution = execution
        return buildOutput(for: execution)
    }

    /// Whether a behavior is currently playing.
    var isExecuting: Bool { currentExecution != nil }

    /// Cancel the current execution.
    func cancel() {
        if let exec = currentExecution {
            NSLog("[Pushling/Teach] Cancelled '%@' at %.1f%%",
                  exec.definition.name, exec.progress * 100)
        }
        currentExecution = nil
        keyframeJitters.removeAll()
    }

    // MARK: - Output Building

    /// Builds a LayerOutput by interpolating active tracks at current time.
    private func buildOutput(for execution: TaughtBehaviorExecution) -> LayerOutput {
        var output = LayerOutput()
        let adjustedTime = execution.elapsed / execution.personalityMods.speedMultiplier

        for (trackName, keyframes) in execution.definition.tracks {
            guard !keyframes.isEmpty else { continue }

            // Find the state at current time
            let state = interpolateState(
                keyframes: keyframes,
                time: adjustedTime,
                trackName: trackName,
                execution: execution
            )

            // Map semantic state to the LayerOutput property
            applyTrackState(trackName: trackName, state: state,
                           params: currentParams(keyframes: keyframes,
                                                  time: adjustedTime),
                           output: &output)
        }

        // Apply mastery-level expression overlay
        applyMasteryExpression(execution: execution, output: &output)

        return output
    }

    /// Finds the semantic state for a track at a given time by interpolating.
    /// For discrete states (body, eyes, etc.), returns the most recent keyframe.
    /// For movement, handles interpolation.
    private func interpolateState(
        keyframes: [Keyframe],
        time: TimeInterval,
        trackName: String,
        execution: TaughtBehaviorExecution
    ) -> String {
        // Apply per-keyframe jitter
        let jitters = keyframeJitters[trackName] ?? []

        // Find the two bounding keyframes
        var prevKF = keyframes[0]
        var prevIdx = 0
        for (i, kf) in keyframes.enumerated() {
            let jitteredTime = kf.time + (i < jitters.count ? jitters[i] : 0)
            if jitteredTime <= time {
                prevKF = kf
                prevIdx = i
            } else {
                break
            }
        }

        // Apply fumble system at low mastery
        if execution.masteryLevel == .learning {
            if let fumbled = applyFumble(state: prevKF.state,
                                          trackName: trackName,
                                          progress: execution.progress) {
                return fumbled
            }
        } else if execution.masteryLevel == .practiced {
            // Fewer fumbles at practiced level
            if Double.random(in: 0...1, using: &rng) < 0.15 {
                if let fumbled = applyFumble(state: prevKF.state,
                                              trackName: trackName,
                                              progress: execution.progress) {
                    return fumbled
                }
            }
        }

        // At mastered/signature, add flair
        if execution.masteryLevel == .signature, prevIdx == keyframes.count - 1 {
            return addSignatureFlair(state: prevKF.state, trackName: trackName)
        }

        return prevKF.state
    }

    /// Returns params from the most recent keyframe at a given time.
    private func currentParams(keyframes: [Keyframe],
                               time: TimeInterval) -> [String: String] {
        var params: [String: String] = [:]
        for kf in keyframes where kf.time <= time {
            for (k, v) in kf.params { params[k] = v }
        }
        return params
    }

    // MARK: - Track to LayerOutput Mapping

    /// Maps a semantic track state to the appropriate LayerOutput property.
    private func applyTrackState(trackName: String, state: String,
                                  params: [String: String],
                                  output: inout LayerOutput) {
        switch trackName {
        case "body":
            output.bodyState = state
        case "head":
            // Head states map to a combination of body lean
            // "tilt_left"/"tilt_right" are handled by the creature node
            output.bodyState = output.bodyState ?? "stand"
        case "ears":
            output.earLeftState = state
            output.earRightState = state
        case "eyes":
            output.eyeLeftState = state
            output.eyeRightState = state
        case "tail":
            output.tailState = state
        case "mouth":
            output.mouthState = state
        case "whiskers":
            output.whiskerState = state
        case "paw_fl":
            var paws = output.pawStates ?? [:]
            paws["fl"] = state
            output.pawStates = paws
        case "paw_fr":
            var paws = output.pawStates ?? [:]
            paws["fr"] = state
            output.pawStates = paws
        case "paw_bl":
            var paws = output.pawStates ?? [:]
            paws["bl"] = state
            output.pawStates = paws
        case "paw_br":
            var paws = output.pawStates ?? [:]
            paws["br"] = state
            output.pawStates = paws
        case "particles":
            // Particles are handled by the aura/particle system
            output.auraState = state == "none" ? nil : state
        case "aura":
            output.auraState = state == "none" ? nil : state
        case "movement":
            applyMovementState(state: state, output: &output)
        case "speech", "sound":
            // Speech and sound are event-driven, not per-frame
            // Handled separately by the speech coordinator
            break
        default:
            break
        }
    }

    /// Maps movement track states to position/speed output.
    private func applyMovementState(state: String,
                                     output: inout LayerOutput) {
        switch state {
        case "walk_left":
            output.walkSpeed = 15
            output.facing = .left
        case "walk_right":
            output.walkSpeed = 15
            output.facing = .right
        case "run_left":
            output.walkSpeed = 40
            output.facing = .left
        case "run_right":
            output.walkSpeed = 40
            output.facing = .right
        case "jump":
            output.positionY = 8.0  // Jump apex
        case "retreat":
            output.walkSpeed = 8
        case "stay":
            output.walkSpeed = 0
        default:
            break
        }
    }

    // MARK: - Mastery Expression Overlay

    /// Adds mastery-appropriate expression to the behavior output.
    private func applyMasteryExpression(
        execution: TaughtBehaviorExecution,
        output: inout LayerOutput
    ) {
        switch execution.masteryLevel {
        case .learning:
            // Concentrated: tongue out, uncertain eyes
            if output.mouthState == nil {
                output.mouthState = "blep"  // Tongue out = concentrating
            }
            if output.eyeLeftState == nil {
                output.eyeLeftState = "wide"
                output.eyeRightState = "wide"
            }

        case .practiced:
            // Focused but relaxed — no overlay needed
            break

        case .mastered:
            // Confident, slight pride at end
            if execution.progress > 0.85 {
                if output.eyeLeftState == nil {
                    output.eyeLeftState = "happy_squint"
                    output.eyeRightState = "happy_squint"
                }
            }

        case .signature:
            // Effortless — might look at camera mid-trick
            if execution.progress > 0.4 && execution.progress < 0.6 {
                if Double.random(in: 0...1, using: &rng) < 0.3 {
                    // "Look at camera" — slight head tilt, relaxed eyes
                    if output.eyeLeftState == nil {
                        output.eyeLeftState = "half"
                        output.eyeRightState = "half"
                    }
                }
            }
        }
    }

    // MARK: - Fumble System

    /// Returns a fumbled state for Learning/Practiced tiers, or nil for no fumble.
    private func applyFumble(state: String, trackName: String,
                              progress: Double) -> String? {
        let roll = Double.random(in: 0...1, using: &rng)

        // False start at beginning (25% chance at Learning)
        if progress < 0.1 && roll < 0.25 {
            return "neutral"  // Hesitation — reverts to neutral briefly
        }

        // Overshoot at midpoint (20% chance)
        if progress > 0.3 && progress < 0.7 && roll < 0.20 {
            return overshootState(for: state, trackName: trackName)
        }

        // Wrong track briefly (10% chance)
        if roll < 0.10 {
            let validStates = ChoreographyParser.validStatesPerTrack[trackName] ?? []
            if !validStates.isEmpty {
                return validStates.randomElement()
            }
        }

        return nil
    }

    /// Returns an "overshoot" variant of a state.
    private func overshootState(for state: String,
                                 trackName: String) -> String {
        switch trackName {
        case "eyes":
            return state == "squint" ? "wide" : "squint"
        case "ears":
            return state == "perk" ? "flat" : "perk"
        case "tail":
            return state == "high" ? "poof" : "high"
        case "body":
            return state == "crouch" ? "stretch" : "crouch"
        default:
            return state
        }
    }

    /// Returns a signature flair variant for the final keyframe.
    private func addSignatureFlair(state: String,
                                    trackName: String) -> String {
        // At Signature mastery, the creature adds a flourish
        switch trackName {
        case "tail":
            return "wag"  // Happy ending flourish
        case "ears":
            return "perk"  // Proud ears
        default:
            return state
        }
    }

    // MARK: - Jitter Generation

    /// Pre-computes timing jitter for all keyframes in all tracks.
    private func generateJitters(for definition: ChoreographyDefinition,
                                  mods: PersonalityModifiers) {
        keyframeJitters.removeAll()
        for (trackName, keyframes) in definition.tracks {
            var jitters: [Double] = []
            for _ in keyframes {
                let jitter = Double.random(in: -mods.timingJitter...mods.timingJitter,
                                           using: &rng)
                jitters.append(jitter * definition.durationSeconds)
            }
            keyframeJitters[trackName] = jitters
        }
    }
}
