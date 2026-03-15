// BlendController.swift — Smooth interpolation between behavior states
// Per-property blend tracking. Different body parts can be in
// different blend phases simultaneously.
//
// Timings: direction 0.43s, expression 0.8s, reflex 0.15s,
//          AI take 0.3s, AI release 5.0s.

import Foundation
import CoreGraphics

// MARK: - Direction Reversal Phase

/// The 4-phase state machine for direction reversals (0.433s total).
enum DirectionReversalPhase {
    /// Not reversing.
    case none
    /// Decelerating to zero (0.15s, ease-out).
    case decelerating(elapsed: TimeInterval)
    /// Paused at zero speed (2 frames = ~0.033s).
    case paused(framesRemaining: Int)
    /// Sprite has flipped; accelerating to target speed (0.25s, ease-in).
    case accelerating(elapsed: TimeInterval)
}

// MARK: - Property Blend

/// Tracks the blend state for a single body part property.
struct PropertyBlend {
    /// The previous state (what we're blending from).
    var fromState: String

    /// The target state (what we're blending to).
    var toState: String

    /// Elapsed time in the current blend.
    var elapsed: TimeInterval

    /// Total duration of the blend.
    var duration: TimeInterval

    /// Easing function to apply.
    var easing: (Double) -> Double

    /// Current blend factor [0.0, 1.0] — 0 = fromState, 1 = toState.
    var factor: Double {
        guard duration > 0 else { return 1.0 }
        let t = clamp(elapsed / duration, min: 0.0, max: 1.0)
        return easing(t)
    }

    /// Whether this blend is complete.
    var isComplete: Bool {
        elapsed >= duration
    }

    /// The current resolved state name.
    /// Returns toState once factor > 0.5 (for discrete state crossfade).
    var currentState: String {
        factor > 0.5 ? toState : fromState
    }
}

// MARK: - Blend Controller

final class BlendController {

    // MARK: - State

    /// Per-property blend tracking for body part states.
    private var propertyBlends: [String: PropertyBlend] = [:]

    /// Direction reversal state machine.
    private(set) var reversalPhase: DirectionReversalPhase = .none

    /// The current rendered facing direction.
    private(set) var currentFacing: Direction = .right

    /// The target facing direction (from layer resolution).
    private var targetFacing: Direction = .right

    /// Current rendered walk speed (interpolated).
    private(set) var currentWalkSpeed: CGFloat = 0

    /// Target walk speed (from layer resolution).
    private var targetWalkSpeed: CGFloat = 0

    /// Current rendered position.
    private(set) var currentPosition: CGPoint = CGPoint(
        x: SceneConstants.sceneWidth / 2, y: SceneConstants.groundY
    )

    /// Current rendered depth position (0.0 = foreground, 1.0 = background).
    private(set) var currentPositionZ: CGFloat = 0.0

    /// Active layer transition type (for determining blend timing).
    private var activeTransition: BlendTransitionType?

    /// Elapsed time in the active layer transition.
    private var transitionElapsed: TimeInterval = 0

    /// Whether the reflex layer was active last frame.
    private var wasReflexActive: Bool = false

    /// Whether the AI layer was active last frame.
    private var wasAIActive: Bool = false

    /// Personality snapshot for tempo scaling via PersonalityFilter.
    var personality: PersonalitySnapshot = .neutral

    // MARK: - Expression Change Sub-Timing

    /// Per-body-part sub-timing for expression crossfades.
    /// Ears lead (0.2s), eyes follow (0.15s), mouth (0.3s),
    /// tail (0.5s), whiskers (0.1s).
    private static let expressionSubTiming: [String: TimeInterval] = [
        "earLeftState":   0.2,
        "earRightState":  0.2,
        "eyeLeftState":   0.15,
        "eyeRightState":  0.15,
        "mouthState":     0.3,
        "tailState":      0.5,
        "whiskerState":   0.1,
        "bodyState":      0.3,
        "auraState":      0.5,
    ]

    /// Reflex cascading snap sub-timing (0.15s total).
    /// Ears first (0.05s), eyes (0.05s), body (0.05s).
    private static let reflexSubTiming: [String: (delay: TimeInterval,
                                                   duration: TimeInterval)] = [
        "earLeftState":   (delay: 0.0,  duration: 0.05),
        "earRightState":  (delay: 0.0,  duration: 0.05),
        "eyeLeftState":   (delay: 0.05, duration: 0.05),
        "eyeRightState":  (delay: 0.05, duration: 0.05),
        "bodyState":      (delay: 0.10, duration: 0.05),
        "tailState":      (delay: 0.10, duration: 0.05),
        "mouthState":     (delay: 0.10, duration: 0.05),
        "whiskerState":   (delay: 0.05, duration: 0.05),
        "auraState":      (delay: 0.10, duration: 0.05),
    ]

    // MARK: - Update

    /// Main update method. Takes the resolved desired state and produces
    /// the smoothly interpolated actual state.
    ///
    /// - Parameters:
    ///   - desired: The fully resolved state from layer output resolution.
    ///   - isReflexActive: Whether the reflex layer currently has opinions.
    ///   - isAIActive: Whether the AI layer currently has opinions.
    ///   - deltaTime: Seconds since last frame.
    /// - Returns: The blended state to apply to the creature node.
    func update(desired: ResolvedCreatureState,
                isReflexActive: Bool,
                isAIActive: Bool,
                deltaTime: TimeInterval) -> ResolvedCreatureState {

        // Detect layer transitions
        detectLayerTransitions(isReflexActive: isReflexActive,
                               isAIActive: isAIActive)

        // Update direction reversal
        updateDirectionReversal(targetFacing: desired.facing,
                                targetSpeed: desired.walkSpeed,
                                deltaTime: deltaTime)

        // Update position
        updatePosition(desired: desired, deltaTime: deltaTime)

        // Update body part blends
        let blendedBody = updatePropertyBlends(desired: desired,
                                                deltaTime: deltaTime)

        // Compose the blended state
        var blended = blendedBody
        blended.positionX = currentPosition.x
        blended.positionY = desired.positionY  // Y is from physics, no blend needed
        blended.positionZ = currentPositionZ
        blended.facing = currentFacing

        // Walk speed comes from direction reversal state machine
        blended.walkSpeed = currentWalkSpeed

        // Track for next frame
        wasReflexActive = isReflexActive
        wasAIActive = isAIActive

        return blended
    }

    // MARK: - Layer Transition Detection

    private func detectLayerTransitions(isReflexActive: Bool,
                                         isAIActive: Bool) {
        // Reflex just started
        if isReflexActive && !wasReflexActive {
            setTransition(.reflexInterrupt)
        }
        // Reflex just ended (no special transition — lower layers take over)

        // AI just took control
        if isAIActive && !wasAIActive {
            setTransition(.aiTakeover)
        }
        // AI just released control
        if !isAIActive && wasAIActive {
            setTransition(.aiRelease)
        }
    }

    private func setTransition(_ type: BlendTransitionType) {
        // Reflex interrupts can preempt other transitions
        if type == .reflexInterrupt {
            activeTransition = type
            transitionElapsed = 0
            return
        }

        // Don't override a reflex interrupt with a lower-priority transition
        if activeTransition == .reflexInterrupt, transitionElapsed < 0.15 {
            return
        }

        activeTransition = type
        transitionElapsed = 0
    }

    // MARK: - Direction Reversal

    /// The 4-phase direction reversal state machine.
    /// Total: 0.433s (decel 0.15 + pause 0.033 + accel 0.25).
    private func updateDirectionReversal(targetFacing: Direction,
                                          targetSpeed: CGFloat,
                                          deltaTime: TimeInterval) {
        // Detect direction change request
        if targetFacing != currentFacing, case .none = reversalPhase {
            // Begin reversal
            reversalPhase = .decelerating(elapsed: 0)
            targetWalkSpeed = targetSpeed
            self.targetFacing = targetFacing
        }

        switch reversalPhase {
        case .none:
            // No reversal — interpolate speed directly
            let speedDiff = targetSpeed - currentWalkSpeed
            if abs(speedDiff) < 0.5 {
                currentWalkSpeed = targetSpeed
            } else {
                // Smooth speed change
                currentWalkSpeed += speedDiff * CGFloat(
                    min(deltaTime * 4.0, 1.0)
                )
            }

        case .decelerating(let elapsed):
            let newElapsed = elapsed + deltaTime
            let progress = min(newElapsed / 0.15, 1.0)
            let easedProgress = Easing.easeOut(progress)

            // Speed goes from current toward zero
            currentWalkSpeed = targetWalkSpeed * CGFloat(1.0 - easedProgress)

            if newElapsed >= 0.15 {
                reversalPhase = .paused(framesRemaining: 2)
                currentWalkSpeed = 0
            } else {
                reversalPhase = .decelerating(elapsed: newElapsed)
            }

        case .paused(let frames):
            currentWalkSpeed = 0
            if frames <= 0 {
                // Flip the sprite
                currentFacing = targetFacing
                reversalPhase = .accelerating(elapsed: 0)
            } else {
                reversalPhase = .paused(framesRemaining: frames - 1)
            }

        case .accelerating(let elapsed):
            let newElapsed = elapsed + deltaTime
            let progress = min(newElapsed / 0.25, 1.0)
            let easedProgress = Easing.easeIn(progress)

            // Speed goes from zero toward target
            currentWalkSpeed = targetWalkSpeed * CGFloat(easedProgress)

            if newElapsed >= 0.25 {
                reversalPhase = .none
                currentWalkSpeed = targetWalkSpeed
            } else {
                reversalPhase = .accelerating(elapsed: newElapsed)
            }
        }
    }

    // MARK: - Position

    private func updatePosition(desired: ResolvedCreatureState,
                                deltaTime: TimeInterval) {
        // X position: move based on current walk speed and facing
        if abs(currentWalkSpeed) > 0.1 {
            let dx = currentWalkSpeed * currentFacing.xScale * CGFloat(deltaTime)
            currentPosition.x += dx
        }

        // Override with desired position if set directly (e.g., by AI layer)
        // Use smooth interpolation, not instant snap
        let targetX = desired.positionX
        let xDiff = targetX - currentPosition.x

        // If the desired position is far from current (AI walk-to command),
        // the walk speed handles it. If it's a small correction, lerp.
        if abs(xDiff) > 1.0 && abs(currentWalkSpeed) < 0.1 {
            // Not walking but need to move — lerp toward target
            let blendSpeed = activeTransition == .aiTakeover ? 0.3 : 0.1
            currentPosition.x = lerp(currentPosition.x, targetX,
                                     CGFloat(min(deltaTime / blendSpeed, 1.0)))
        }

        // Clamp to bounds
        currentPosition.x = clamp(currentPosition.x,
                                  min: SceneConstants.minX,
                                  max: SceneConstants.maxX)

        // Y comes directly from physics (no blend needed)
        currentPosition.y = desired.positionY

        // Z position: lerp toward desired Z at same rate as X corrections
        let targetZ = desired.positionZ
        let zDiff = targetZ - currentPositionZ
        if abs(zDiff) > 0.01 {
            currentPositionZ = lerp(currentPositionZ, targetZ,
                                    CGFloat(min(deltaTime / 0.3, 1.0)))
        } else {
            currentPositionZ = targetZ
        }
    }

    // MARK: - Property Blends

    /// The body part properties that get blended, as (key, keyPath) pairs.
    private static let blendableProperties: [(String, WritableKeyPath<ResolvedCreatureState, String>)] = [
        ("bodyState",     \.bodyState),
        ("earLeftState",  \.earLeftState),
        ("earRightState", \.earRightState),
        ("eyeLeftState",  \.eyeLeftState),
        ("eyeRightState", \.eyeRightState),
        ("tailState",     \.tailState),
        ("mouthState",    \.mouthState),
        ("whiskerState",  \.whiskerState),
        ("auraState",     \.auraState),
    ]

    /// Updates per-property blends and returns the blended creature state.
    private func updatePropertyBlends(desired: ResolvedCreatureState,
                                       deltaTime: TimeInterval) -> ResolvedCreatureState {
        var result = desired
        let transitionType = activeTransition

        // Advance transition timer
        if activeTransition != nil {
            transitionElapsed += deltaTime
            if let type = activeTransition, transitionElapsed >= type.duration {
                activeTransition = nil
                transitionElapsed = 0
            }
        }

        // Blend each body part property through the same logic
        for (key, keyPath) in Self.blendableProperties {
            result[keyPath: keyPath] = blendProperty(
                key: key,
                target: desired[keyPath: keyPath],
                transitionType: transitionType,
                deltaTime: deltaTime
            )
        }

        return result
    }

    /// Blends a single body part property toward its target state.
    /// Returns the current effective state after blending.
    private func blendProperty(key: String,
                                target: String,
                                transitionType: BlendTransitionType?,
                                deltaTime: TimeInterval) -> String {
        // Check if there's an existing blend for this property
        if var blend = propertyBlends[key] {
            if blend.toState == target {
                // Same target — advance the blend
                blend.elapsed += deltaTime
                if blend.isComplete {
                    propertyBlends.removeValue(forKey: key)
                    return target
                }
                propertyBlends[key] = blend
                return blend.currentState
            } else {
                // New target — start a new blend from current position
                let duration = blendDuration(for: key,
                                              transitionType: transitionType)
                let easing = blendEasing(for: transitionType)
                propertyBlends[key] = PropertyBlend(
                    fromState: blend.currentState,
                    toState: target,
                    elapsed: 0,
                    duration: duration,
                    easing: easing
                )
                return blend.currentState
            }
        }

        // No existing blend — check if this is a state change
        // (We need to know the previous state, which we track via blends)
        // First frame or no change — just return target
        let duration = blendDuration(for: key, transitionType: transitionType)
        if duration > 0 {
            // Start tracking even if we don't know the from-state
            // (will be immediate on first frame)
            propertyBlends[key] = PropertyBlend(
                fromState: target,
                toState: target,
                elapsed: duration, // Already complete
                duration: duration,
                easing: Easing.linear
            )
        }
        return target
    }

    /// Returns the blend duration for a property, scaled by personality tempo.
    /// Hyper creatures transition faster, calm creatures slower.
    private func blendDuration(for key: String,
                                transitionType: BlendTransitionType?) -> TimeInterval {
        let tempo = PersonalityFilter.animationTempo(personality: personality)
        let tempoScale = tempo > 0 ? 1.0 / tempo : 1.0
        let exprDuration = Self.expressionSubTiming[key] ?? 0.3

        guard let type = transitionType else {
            return exprDuration * tempoScale
        }

        switch type {
        case .reflexInterrupt:
            // Reflexes: not tempo-scaled (must be consistently fast)
            return Self.reflexSubTiming[key]?.duration ?? 0.05
        case .expressionChange:
            return exprDuration * tempoScale
        case .directionReversal:
            return 0  // Handled by its own state machine
        case .aiTakeover:
            return 0.3 * tempoScale
        case .aiRelease:
            return (exprDuration * 3.0) * tempoScale
        }
    }

    /// Returns the easing function for a transition type.
    private func blendEasing(for type: BlendTransitionType?)
        -> (Double) -> Double {
        guard let type = type else {
            return Easing.easeInOut
        }

        switch type {
        case .reflexInterrupt:   return Easing.linear
        case .expressionChange:  return Easing.easeInOut
        case .directionReversal: return Easing.easeOut
        case .aiTakeover:        return Easing.easeIn
        case .aiRelease:         return Easing.easeOut
        }
    }

    // MARK: - State Change Detection

    /// Notifies the blend controller of an expression change
    /// (triggers the 0.8s crossfade timing).
    func notifyExpressionChange() {
        if activeTransition == nil || activeTransition == .expressionChange {
            setTransition(.expressionChange)
        }
    }

    /// Notifies the blend controller of a direction change
    /// (triggers the 0.433s reversal sequence).
    func notifyDirectionChange() {
        if activeTransition == nil {
            setTransition(.directionReversal)
        }
    }

    // MARK: - Reset

    /// Resets all blend state. Used on creature initialization.
    func reset(position: CGPoint, facing: Direction) {
        propertyBlends.removeAll()
        reversalPhase = .none
        currentFacing = facing
        currentWalkSpeed = 0
        currentPosition = position
        currentPositionZ = 0.0
        activeTransition = nil
        transitionElapsed = 0
        wasReflexActive = false
        wasAIActive = false
    }
}
