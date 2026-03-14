// EmergentStates.swift — Compound emotional state detection
// Combines the 4 emotional axes into recognizable named states.
//
// Priority (highest first): Exhausted > Hangry > Blissful > Playful > Studious > Zen
// Only one emergent state is active at a time.
// Evaluated every 5 seconds (not every frame).

import Foundation

// MARK: - Emergent State

/// Named compound states that emerge from emotional axis combinations.
/// Each state modifies the autonomous layer's behavior.
enum EmergentState: String, CaseIterable {

    /// High satisfaction + contentment, mid energy.
    /// Peaceful wandering, purr particles, slow-blinks every 20s.
    case blissful

    /// High energy + contentment.
    /// Increased behavior frequency, bouncy walk, tail high.
    case playful

    /// High curiosity, mid energy.
    /// Examines surroundings longer, peers at objects, ears rotate.
    case studious

    /// Low satisfaction, mid+ energy.
    /// Agitated pacing, short walks, frequent turns, glances at camera.
    case hangry

    /// All four axes between 40-60.
    /// Loaf position, concentric circle particles, eyes half-closed.
    case zen

    /// Energy < 10.
    /// Stumbling gait, collapses into sleep curl.
    case exhausted
}

// MARK: - Emergent State Modifiers

/// Behavior modifiers applied when an emergent state is active.
/// Used by the AutonomousLayer and PersonalityFilter to adjust behavior.
struct EmergentStateModifiers {
    /// Walk speed multiplier (1.0 = normal).
    let walkSpeedMultiplier: Double

    /// Behavior cooldown multiplier (<1.0 = more frequent behaviors).
    let behaviorCooldownMultiplier: Double

    /// Idle duration multiplier.
    let idleDurationMultiplier: Double

    /// Preferred tail state override (nil = no override).
    let preferredTailState: String?

    /// Preferred eye state override (nil = no override).
    let preferredEyeState: String?

    /// Preferred aura state override (nil = no override).
    let preferredAuraState: String?

    /// Whether purr particles should be active.
    let purrParticles: Bool

    /// Slow-blink interval in seconds (0 = no slow-blinks).
    let slowBlinkInterval: TimeInterval

    /// Direction change frequency multiplier (>1.0 = more turns).
    let directionChangeMultiplier: Double

    /// Default — no modifications.
    static let none = EmergentStateModifiers(
        walkSpeedMultiplier: 1.0,
        behaviorCooldownMultiplier: 1.0,
        idleDurationMultiplier: 1.0,
        preferredTailState: nil,
        preferredEyeState: nil,
        preferredAuraState: nil,
        purrParticles: false,
        slowBlinkInterval: 0,
        directionChangeMultiplier: 1.0
    )

    /// Modifiers for each emergent state.
    static func forState(_ state: EmergentState) -> EmergentStateModifiers {
        switch state {
        case .blissful:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 0.8,
                behaviorCooldownMultiplier: 0.7,
                idleDurationMultiplier: 1.3,
                preferredTailState: "sway",
                preferredEyeState: nil,
                preferredAuraState: "warm",
                purrParticles: true,
                slowBlinkInterval: 20.0,
                directionChangeMultiplier: 0.7
            )

        case .playful:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 1.3,
                behaviorCooldownMultiplier: 0.5,
                idleDurationMultiplier: 0.5,
                preferredTailState: "high",
                preferredEyeState: nil,
                preferredAuraState: nil,
                purrParticles: false,
                slowBlinkInterval: 0,
                directionChangeMultiplier: 1.5
            )

        case .studious:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 0.7,
                behaviorCooldownMultiplier: 0.8,
                idleDurationMultiplier: 1.5,
                preferredTailState: "twitch_tip",
                preferredEyeState: nil,
                preferredAuraState: nil,
                purrParticles: false,
                slowBlinkInterval: 0,
                directionChangeMultiplier: 0.5
            )

        case .hangry:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 1.1,
                behaviorCooldownMultiplier: 1.5,
                idleDurationMultiplier: 0.4,
                preferredTailState: "twitch_tip",
                preferredEyeState: "squint",
                preferredAuraState: nil,
                purrParticles: false,
                slowBlinkInterval: 0,
                directionChangeMultiplier: 2.5
            )

        case .zen:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 0.0,
                behaviorCooldownMultiplier: 3.0,
                idleDurationMultiplier: 5.0,
                preferredTailState: "sway",
                preferredEyeState: "half",
                preferredAuraState: "pulse",
                purrParticles: false,
                slowBlinkInterval: 0,
                directionChangeMultiplier: 0.0
            )

        case .exhausted:
            return EmergentStateModifiers(
                walkSpeedMultiplier: 0.3,
                behaviorCooldownMultiplier: 5.0,
                idleDurationMultiplier: 0.5,
                preferredTailState: "low",
                preferredEyeState: "half",
                preferredAuraState: nil,
                purrParticles: false,
                slowBlinkInterval: 0,
                directionChangeMultiplier: 0.3
            )
        }
    }
}

// MARK: - Emergent State Detector

/// Evaluates emotional axes and determines the current emergent state.
/// Re-evaluated every 5 seconds (configurable).
final class EmergentStateDetector {

    /// Evaluation interval in seconds.
    static let evaluationInterval: TimeInterval = 5.0

    /// Current detected state (nil = no emergent state).
    private(set) var currentState: EmergentState?

    /// Modifiers for the current state.
    private(set) var currentModifiers: EmergentStateModifiers = .none

    /// Seconds since last evaluation.
    private var evaluationTimer: TimeInterval = 0

    /// Time the current state has been active.
    private(set) var stateActiveTime: TimeInterval = 0

    // MARK: - Update

    /// Called each frame. Only re-evaluates every 5 seconds.
    func update(deltaTime: TimeInterval, emotions: EmotionalSnapshot) {
        evaluationTimer += deltaTime
        stateActiveTime += deltaTime

        guard evaluationTimer >= Self.evaluationInterval else { return }
        evaluationTimer = 0

        let newState = detect(emotions: emotions)

        if newState != currentState {
            let oldName = currentState?.rawValue ?? "none"
            let newName = newState?.rawValue ?? "none"
            NSLog("[Pushling/Emotion] Emergent state: %@ -> %@",
                  oldName, newName)

            currentState = newState
            stateActiveTime = 0

            if let state = newState {
                currentModifiers = EmergentStateModifiers.forState(state)
            } else {
                currentModifiers = .none
            }
        }
    }

    // MARK: - Detection

    /// Detect the highest-priority emergent state.
    /// Priority: Exhausted > Hangry > Blissful > Playful > Studious > Zen
    private func detect(emotions: EmotionalSnapshot) -> EmergentState? {
        let sat = emotions.satisfaction
        let cur = emotions.curiosity
        let con = emotions.contentment
        let eng = emotions.energy

        // Exhausted: energy < 10
        if eng < 10 {
            return .exhausted
        }

        // Hangry: low satisfaction, mid+ energy
        if sat < 25 && eng > 40 {
            return .hangry
        }

        // Blissful: high satisfaction + contentment, mid energy
        if sat > 75 && con > 75 && eng >= 30 && eng <= 70 {
            return .blissful
        }

        // Playful: high energy + contentment
        if eng > 70 && con > 60 {
            return .playful
        }

        // Studious: high curiosity, mid energy
        if cur > 75 && eng >= 30 && eng <= 70 {
            return .studious
        }

        // Zen: all four between 40-60
        if sat >= 40 && sat <= 60
            && cur >= 40 && cur <= 60
            && con >= 40 && con <= 60
            && eng >= 40 && eng <= 60 {
            return .zen
        }

        return nil
    }

    // MARK: - Query

    /// Whether any emergent state is currently active.
    var isActive: Bool { currentState != nil }

    /// Force re-evaluation on next frame.
    func forceEvaluation() {
        evaluationTimer = Self.evaluationInterval
    }
}
