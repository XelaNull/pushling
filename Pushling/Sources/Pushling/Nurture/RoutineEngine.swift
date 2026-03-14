// RoutineEngine.swift — 10 lifecycle slot routines
// Each slot has a default behavior that can be replaced by Claude.
// Routines are multi-step sequences (2-6 actions).
// Routines fire at lifecycle moments, pre-empting autonomous behavior.
//
// Slots: morning, post_meal, bedtime, greeting, farewell, return,
//        milestone, weather_change, boredom, post_feast

import Foundation

// MARK: - Routine Slot

/// The 10 lifecycle slots for routines.
enum RoutineSlot: String, CaseIterable {
    case morning         // On wake (first commit after sleep)
    case postMeal        // After commit eating
    case bedtime         // Before sleep
    case greeting        // Claude session start
    case farewell        // Claude session end
    case `return`        // Wake from >8hr absence
    case milestone       // Any milestone event
    case weatherChange   // Weather state transition
    case boredom         // 30min idle with low curiosity
    case postFeast       // After eating large commit (200+ lines)

    /// Database key matching Schema.validRoutineSlots.
    var dbKey: String { rawValue }
}

// MARK: - Routine Step

/// A single step in a routine sequence.
struct RoutineStep {
    let type: RoutineStepType
    let behavior: String?        // Behavior name (for perform steps)
    let variant: String?         // Variant (for perform steps)
    let expression: String?      // Expression name (for express steps)
    let text: String?            // Speech text (for speak steps)
    let movementAction: String?  // Movement action (for move steps)
    let durationSeconds: TimeInterval

    enum RoutineStepType: String {
        case perform
        case express
        case speak
        case move
        case wait
    }
}

// MARK: - Routine Definition

/// A customized routine for a lifecycle slot.
struct RoutineDefinition {
    let id: String
    let slot: RoutineSlot
    let steps: [RoutineStep]         // 2-6 steps
    var strength: Double              // 0.0-1.0 (from decay)
    var reinforcementCount: Int
    let createdAt: Date

    /// Total expected duration.
    var totalDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.durationSeconds }
    }
}

// MARK: - Active Routine Execution

/// Tracks an actively executing routine.
struct ActiveRoutineExecution {
    let routine: RoutineDefinition
    var currentStepIndex: Int = 0
    var stepElapsed: TimeInterval = 0
    var isPaused: Bool = false       // Paused by touch/reflex

    var isComplete: Bool {
        currentStepIndex >= routine.steps.count
    }

    var currentStep: RoutineStep? {
        guard currentStepIndex < routine.steps.count else { return nil }
        return routine.steps[currentStepIndex]
    }
}

// MARK: - RoutineEngine

/// Manages lifecycle routines and their execution.
final class RoutineEngine {

    // MARK: - Default Routines

    /// Default behaviors for each slot (used when no custom routine is set).
    private static let defaults: [RoutineSlot: [RoutineStep]] = [
        .morning: [
            RoutineStep(type: .perform, behavior: "stretch", variant: "morning",
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 2.0),
            RoutineStep(type: .perform, behavior: "yawn", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 1.5),
            RoutineStep(type: .move, behavior: nil, variant: nil,
                       expression: nil, text: nil, movementAction: "center",
                       durationSeconds: 3.0),
        ],
        .postMeal: [
            RoutineStep(type: .perform, behavior: "grooming", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 3.0),
        ],
        .bedtime: [
            RoutineStep(type: .perform, behavior: "yawn", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 1.5),
            RoutineStep(type: .perform, behavior: "kneading", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 4.0),
            RoutineStep(type: .perform, behavior: "curl", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 2.0),
        ],
        .greeting: [
            RoutineStep(type: .express, behavior: nil, variant: nil,
                       expression: "joy", text: nil, movementAction: nil,
                       durationSeconds: 1.0),
            RoutineStep(type: .move, behavior: nil, variant: nil,
                       expression: nil, text: nil, movementAction: "edge_right",
                       durationSeconds: 2.0),
        ],
        .farewell: [
            RoutineStep(type: .perform, behavior: "wave", variant: "small",
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 2.0),
        ],
        .return: [
            RoutineStep(type: .perform, behavior: "stretch", variant: "dramatic",
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 3.0),
            RoutineStep(type: .express, behavior: nil, variant: nil,
                       expression: "joy", text: nil, movementAction: nil,
                       durationSeconds: 2.0),
        ],
        .milestone: [
            RoutineStep(type: .perform, behavior: "celebrate", variant: "big",
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 3.0),
        ],
        .weatherChange: [
            RoutineStep(type: .move, behavior: nil, variant: nil,
                       expression: nil, text: nil, movementAction: "look_up",
                       durationSeconds: 1.5),
            RoutineStep(type: .express, behavior: nil, variant: nil,
                       expression: "curiosity", text: nil, movementAction: nil,
                       durationSeconds: 2.0),
        ],
        .boredom: [
            RoutineStep(type: .express, behavior: nil, variant: nil,
                       expression: "melancholy", text: nil, movementAction: nil,
                       durationSeconds: 2.0),
            RoutineStep(type: .perform, behavior: "flop", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 3.0),
        ],
        .postFeast: [
            RoutineStep(type: .perform, behavior: "food_coma", variant: nil,
                       expression: nil, text: nil, movementAction: nil,
                       durationSeconds: 5.0),
            RoutineStep(type: .express, behavior: nil, variant: nil,
                       expression: "contentment", text: nil, movementAction: nil,
                       durationSeconds: 3.0),
        ],
    ]

    // MARK: - State

    /// Custom routines keyed by slot.
    private var customRoutines: [RoutineSlot: RoutineDefinition] = [:]

    /// Currently executing routine.
    private(set) var activeExecution: ActiveRoutineExecution?

    // MARK: - Routine Management

    /// Sets a custom routine for a slot. Replaces any existing custom routine.
    func setRoutine(_ routine: RoutineDefinition) {
        guard routine.steps.count >= 2 && routine.steps.count <= 6 else {
            NSLog("[Pushling/Routines] Routine must have 2-6 steps. Got %d.",
                  routine.steps.count)
            return
        }
        customRoutines[routine.slot] = routine
        NSLog("[Pushling/Routines] Set custom routine for '%@' (%d steps)",
              routine.slot.rawValue, routine.steps.count)
    }

    /// Resets a slot to its default routine.
    func resetToDefault(slot: RoutineSlot) {
        customRoutines.removeValue(forKey: slot)
        NSLog("[Pushling/Routines] Reset '%@' to default", slot.rawValue)
    }

    /// Returns whether a slot has a custom routine.
    func hasCustomRoutine(for slot: RoutineSlot) -> Bool {
        return customRoutines[slot] != nil
    }

    // MARK: - Triggering

    /// Triggers a routine for a lifecycle event.
    /// Returns true if a routine was started.
    @discardableResult
    func trigger(slot: RoutineSlot) -> Bool {
        guard activeExecution == nil else {
            NSLog("[Pushling/Routines] Already executing a routine. "
                  + "Ignoring trigger for '%@'.", slot.rawValue)
            return false
        }

        let routine: RoutineDefinition
        if let custom = customRoutines[slot], custom.strength >= 0.2 {
            routine = custom
        } else if let defaultSteps = Self.defaults[slot] {
            routine = RoutineDefinition(
                id: "default_\(slot.rawValue)",
                slot: slot,
                steps: defaultSteps,
                strength: 1.0,
                reinforcementCount: 0,
                createdAt: Date.distantPast
            )
        } else {
            return false
        }

        activeExecution = ActiveRoutineExecution(routine: routine)
        NSLog("[Pushling/Routines] Triggered '%@' routine (%d steps)",
              slot.rawValue, routine.steps.count)
        return true
    }

    // MARK: - Per-Frame Update

    /// Updates the active routine and returns the LayerOutput for this frame.
    /// Returns nil if no routine is active.
    func update(deltaTime: TimeInterval) -> (output: LayerOutput,
                                               step: RoutineStep)? {
        guard var execution = activeExecution else { return nil }

        // Handle pauses (touch interrupts)
        guard !execution.isPaused else {
            activeExecution = execution
            return nil
        }

        guard let step = execution.currentStep else {
            // All steps complete
            completeRoutine()
            return nil
        }

        execution.stepElapsed += deltaTime

        // Check step completion
        if execution.stepElapsed >= step.durationSeconds {
            execution.currentStepIndex += 1
            execution.stepElapsed = 0
            activeExecution = execution

            // Check if routine is now complete
            if execution.isComplete {
                completeRoutine()
                return nil
            }

            // Return output for the new step
            if let newStep = execution.currentStep {
                let output = outputForStep(newStep)
                return (output, newStep)
            }
            return nil
        }

        activeExecution = execution

        let output = outputForStep(step)
        return (output, step)
    }

    /// Whether a routine is currently executing.
    var isExecuting: Bool { activeExecution != nil }

    /// Pause execution (for touch interrupts).
    func pause() {
        activeExecution?.isPaused = true
    }

    /// Resume execution after touch.
    func resume() {
        activeExecution?.isPaused = false
    }

    /// Cancel the current routine.
    func cancel() {
        activeExecution = nil
    }

    // MARK: - Output Generation

    /// Converts a routine step into a LayerOutput.
    private func outputForStep(_ step: RoutineStep) -> LayerOutput {
        var output = LayerOutput()

        switch step.type {
        case .perform:
            // Performance steps set body state
            output.bodyState = step.behavior ?? "stand"

        case .express:
            // Expression steps set emotional body parts
            if let expr = step.expression {
                switch expr {
                case "joy":
                    output.eyeLeftState = "happy_squint"
                    output.eyeRightState = "happy_squint"
                    output.tailState = "high"
                case "curiosity":
                    output.eyeLeftState = "wide"
                    output.eyeRightState = "wide"
                    output.earLeftState = "perk"
                case "contentment":
                    output.eyeLeftState = "half"
                    output.eyeRightState = "half"
                    output.tailState = "sway"
                case "melancholy":
                    output.tailState = "low"
                    output.earLeftState = "droop"
                    output.earRightState = "droop"
                default:
                    break
                }
            }

        case .speak:
            // Speech is handled by the speech coordinator, not LayerOutput
            output.mouthState = "open"

        case .move:
            if let action = step.movementAction {
                switch action {
                case "center":
                    output.walkSpeed = 15
                case "edge_right":
                    output.walkSpeed = 15
                    output.facing = .right
                case "edge_left":
                    output.walkSpeed = 15
                    output.facing = .left
                case "look_up":
                    output.walkSpeed = 0
                    output.earLeftState = "perk"
                    output.earRightState = "perk"
                    output.eyeLeftState = "wide"
                    output.eyeRightState = "wide"
                default:
                    break
                }
            }

        case .wait:
            // No output — just hold current state
            break
        }

        return output
    }

    // MARK: - Completion

    private func completeRoutine() {
        if let exec = activeExecution {
            NSLog("[Pushling/Routines] Completed '%@' routine",
                  exec.routine.slot.rawValue)
        }
        activeExecution = nil
    }

    // MARK: - Bulk Operations

    /// Loads custom routines from SQLite.
    func loadRoutines(_ data: [RoutineDefinition]) {
        customRoutines.removeAll()
        for routine in data {
            customRoutines[routine.slot] = routine
        }
        NSLog("[Pushling/Routines] Loaded %d custom routines",
              customRoutines.count)
    }

    /// Returns summary for SessionStart injection.
    var sessionSummary: String {
        let customSlots = customRoutines.keys.map(\.rawValue).sorted()
        if customSlots.isEmpty { return "All routines default." }
        return "Custom: \(customSlots.joined(separator: ", "))"
    }

    /// Resets all routine state.
    func reset() {
        customRoutines.removeAll()
        activeExecution = nil
    }
}
