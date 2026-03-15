// ObjectInteractionEngine.swift — 14 interaction templates for creature-object interaction
// Each template is a choreographed sequence using LayerOutput properties.
// Parameterized by creature stage (Critter = clumsy, Beast = confident, Sage = contemplative)
// and personality (calm = slower, hyper = faster).
//
// Interactions are queued as autonomous behaviors through the behavior stack.

import Foundation
import CoreGraphics

// MARK: - Interaction Template

/// Defines an interaction template that produces LayerOutput over time.
struct InteractionTemplate {
    let name: String
    let category: InteractionCategory
    let durationRange: ClosedRange<TimeInterval>
    let requiresProximity: CGFloat  // How close creature must be (points)

    /// Whether the object is consumed (removed) after interaction.
    let consumesObject: Bool

    /// Satisfaction boost from completing the interaction.
    let satisfactionBoost: Double
}

/// Categories for interaction templates.
enum InteractionCategory: String {
    case toy
    case furniture
    case decorative
    case interactive
    case consumable
}

// MARK: - Active Object Interaction

/// Tracks an ongoing object interaction.
struct ActiveObjectInteraction {
    let template: InteractionTemplate
    let objectID: String
    let objectX: CGFloat
    var elapsed: TimeInterval = 0
    var phase: InteractionPhase = .approach

    var progress: Double {
        let duration = template.durationRange.lowerBound
        return Swift.min(elapsed / duration, 1.0)
    }
}

/// Phases of an object interaction.
enum InteractionPhase {
    case approach    // Walking toward the object
    case interact    // Performing the interaction
    case conclude    // Wrapping up (lick lips, look satisfied, etc.)
}

// MARK: - ObjectInteractionEngine

/// Manages creature-object interactions with 14 templates.
final class ObjectInteractionEngine {

    // MARK: - Template Registry

    /// All 14 interaction templates.
    let templates: [String: InteractionTemplate] = [
        // Toy (5)
        "batting_toy": InteractionTemplate(
            name: "batting_toy", category: .toy,
            durationRange: 5.0...8.0, requiresProximity: 10,
            consumesObject: false, satisfactionBoost: 8
        ),
        "chasing": InteractionTemplate(
            name: "chasing", category: .toy,
            durationRange: 6.0...10.0, requiresProximity: 30,
            consumesObject: false, satisfactionBoost: 12
        ),
        "carrying": InteractionTemplate(
            name: "carrying", category: .toy,
            durationRange: 4.0...6.0, requiresProximity: 5,
            consumesObject: false, satisfactionBoost: 6
        ),
        "string_play": InteractionTemplate(
            name: "string_play", category: .toy,
            durationRange: 8.0...12.0, requiresProximity: 5,
            consumesObject: false, satisfactionBoost: 10
        ),
        "pushing": InteractionTemplate(
            name: "pushing", category: .toy,
            durationRange: 4.0...6.0, requiresProximity: 3,
            consumesObject: false, satisfactionBoost: 5
        ),

        // Furniture (4)
        "sitting": InteractionTemplate(
            name: "sitting", category: .furniture,
            durationRange: 6.0...8.0, requiresProximity: 5,
            consumesObject: false, satisfactionBoost: 10
        ),
        "climbing": InteractionTemplate(
            name: "climbing", category: .furniture,
            durationRange: 4.0...6.0, requiresProximity: 3,
            consumesObject: false, satisfactionBoost: 8
        ),
        "scratching": InteractionTemplate(
            name: "scratching", category: .furniture,
            durationRange: 4.0...6.0, requiresProximity: 3,
            consumesObject: false, satisfactionBoost: 7
        ),
        "hiding": InteractionTemplate(
            name: "hiding", category: .furniture,
            durationRange: 4.0...6.0, requiresProximity: 3,
            consumesObject: false, satisfactionBoost: 6
        ),

        // Decorative (2)
        "examining": InteractionTemplate(
            name: "examining", category: .decorative,
            durationRange: 4.0...6.0, requiresProximity: 5,
            consumesObject: false, satisfactionBoost: 4
        ),
        "rubbing": InteractionTemplate(
            name: "rubbing", category: .decorative,
            durationRange: 3.0...5.0, requiresProximity: 3,
            consumesObject: false, satisfactionBoost: 5
        ),

        // Interactive (3)
        "listening": InteractionTemplate(
            name: "listening", category: .interactive,
            durationRange: 6.0...10.0, requiresProximity: 8,
            consumesObject: false, satisfactionBoost: 6
        ),
        "watching": InteractionTemplate(
            name: "watching", category: .interactive,
            durationRange: 6.0...10.0, requiresProximity: 15,
            consumesObject: false, satisfactionBoost: 5
        ),
        "reflecting": InteractionTemplate(
            name: "reflecting", category: .interactive,
            durationRange: 6.0...8.0, requiresProximity: 5,
            consumesObject: false, satisfactionBoost: 7
        ),

        // Consumable (1)
        "eating": InteractionTemplate(
            name: "eating", category: .consumable,
            durationRange: 4.0...6.0, requiresProximity: 3,
            consumesObject: true, satisfactionBoost: 15
        ),
    ]

    // MARK: - State

    /// Currently active interaction, if any.
    private(set) var activeInteraction: ActiveObjectInteraction?

    /// Cooldown timestamp: no interactions within 5 minutes of last.
    private var lastInteractionTime: TimeInterval = -300

    /// Minimum seconds between object interactions.
    private static let interactionCooldown: TimeInterval = 300

    // MARK: - Starting Interactions

    /// Begins an object interaction if conditions are met.
    /// Returns true if the interaction started.
    func beginInteraction(
        templateName: String,
        objectID: String,
        objectX: CGFloat,
        creatureX: CGFloat,
        currentTime: TimeInterval
    ) -> Bool {
        // Cooldown check
        guard currentTime - lastInteractionTime >= Self.interactionCooldown else {
            return false
        }

        guard activeInteraction == nil else { return false }

        guard let template = templates[templateName] else {
            NSLog("[Pushling/Objects] Unknown interaction template: %@",
                  templateName)
            return false
        }

        activeInteraction = ActiveObjectInteraction(
            template: template,
            objectID: objectID,
            objectX: objectX
        )

        NSLog("[Pushling/Objects] Started interaction '%@' with object '%@'",
              templateName, objectID)
        return true
    }

    // MARK: - Per-Frame Update

    /// Updates the current interaction and produces LayerOutput.
    /// Returns nil if no interaction is active.
    func update(deltaTime: TimeInterval,
                creatureX: CGFloat,
                stage: GrowthStage,
                personality: PersonalitySnapshot) -> LayerOutput? {
        guard var interaction = activeInteraction else { return nil }

        interaction.elapsed += deltaTime

        // Speed modulation by personality
        let speedMod = 0.7 + personality.energy * 0.6

        // Check completion
        let adjustedDuration = interaction.template.durationRange.lowerBound / speedMod
        if interaction.elapsed >= adjustedDuration {
            completeInteraction()
            return nil
        }

        // Update phase
        let distance = abs(creatureX - interaction.objectX)
        if interaction.phase == .approach && distance <= interaction.template.requiresProximity {
            interaction.phase = .interact
        }
        if interaction.progress > 0.85 {
            interaction.phase = .conclude
        }

        activeInteraction = interaction

        // Generate output based on template and phase
        return generateOutput(interaction: interaction, stage: stage,
                              personality: personality)
    }

    /// Whether an interaction is currently active.
    var isInteracting: Bool { activeInteraction != nil }

    /// Cancel the current interaction.
    func cancelInteraction() {
        activeInteraction = nil
    }

    // MARK: - Output Generation

    /// Generates LayerOutput for the current interaction state.
    private func generateOutput(
        interaction: ActiveObjectInteraction,
        stage: GrowthStage,
        personality: PersonalitySnapshot
    ) -> LayerOutput {
        var output = LayerOutput()

        switch interaction.phase {
        case .approach:
            // Walk toward the object
            output.walkSpeed = stage.baseWalkSpeed
            output.facing = interaction.objectX > 0 ? .right : .left

        case .interact:
            // Stop walking, perform interaction
            output.walkSpeed = 0
            applyInteractionAnimation(
                template: interaction.template.name,
                progress: interaction.progress,
                stage: stage,
                output: &output
            )

        case .conclude:
            output.walkSpeed = 0
            applyConclusionAnimation(
                template: interaction.template.name,
                stage: stage,
                output: &output
            )
        }

        return output
    }

    /// Applies the interaction-specific animation to the output.
    private func applyInteractionAnimation(
        template: String,
        progress: Double,
        stage: GrowthStage,
        output: inout LayerOutput
    ) {
        switch template {
        case "batting_toy":
            output.bodyState = "crouch"
            let pawPhase = (progress * 6).truncatingRemainder(dividingBy: 1.0)
            if pawPhase < 0.5 {
                output.pawStates = ["fl": "tap", "fr": "ground",
                                    "bl": "ground", "br": "ground"]
            } else {
                output.pawStates = ["fl": "ground", "fr": "tap",
                                    "bl": "ground", "br": "ground"]
            }
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
            output.tailState = "twitch_tip"

        case "chasing":
            output.bodyState = "crouch"
            if progress < 0.3 {
                // Stalk phase
                output.eyeLeftState = "wide"
                output.eyeRightState = "wide"
                output.tailState = "twitch_tip"
                if stage >= .critter { output.earLeftState = "perk" }
                if stage >= .critter { output.earRightState = "perk" }
            } else if progress < 0.5 {
                // Butt wiggle
                output.bodyState = "crouch"
                output.tailState = "wag"
            } else {
                // Pounce
                output.bodyState = "pounce"
                output.tailState = "high"
            }

        case "carrying":
            output.bodyState = "stand"
            output.mouthState = "chew"  // Carrying in mouth
            output.tailState = "high"
            if stage >= .critter {
                output.earLeftState = "perk"
                output.earRightState = "perk"
            }

        case "string_play":
            let phase = (progress * 4).truncatingRemainder(dividingBy: 1.0)
            if phase < 0.5 {
                output.pawStates = ["fl": "tap", "fr": "ground",
                                    "bl": "ground", "br": "ground"]
            } else {
                output.pawStates = ["fl": "ground", "fr": "tap",
                                    "bl": "ground", "br": "ground"]
            }
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
            output.tailState = "wag"

        case "pushing":
            output.bodyState = "lean_forward"
            output.pawStates = ["fl": "ground", "fr": "ground",
                                "bl": "ground", "br": "ground"]

        case "sitting":
            if progress < 0.3 {
                // Circling
                output.bodyState = "stand"
            } else {
                // Settled
                output.bodyState = "sit"
                output.eyeLeftState = "half"
                output.eyeRightState = "half"
                output.tailState = "wrap"
                output.pawStates = ["fl": "tuck", "fr": "tuck",
                                    "bl": "tuck", "br": "tuck"]
            }

        case "climbing":
            if progress < 0.4 {
                output.bodyState = "crouch"
            } else if progress < 0.6 {
                output.bodyState = "stretch"
                output.positionY = 8.0  // Jump up
            } else {
                output.bodyState = "sit"
                output.positionY = 10.0  // On top
                output.eyeLeftState = "half"
                output.eyeRightState = "half"
            }

        case "scratching":
            output.bodyState = "stretch"
            let scratchPhase = (progress * 8).truncatingRemainder(dividingBy: 1.0)
            if scratchPhase < 0.5 {
                output.pawStates = ["fl": "reach", "fr": "ground",
                                    "bl": "ground", "br": "ground"]
            } else {
                output.pawStates = ["fl": "ground", "fr": "reach",
                                    "bl": "ground", "br": "ground"]
            }
            output.eyeLeftState = "closed"
            output.eyeRightState = "closed"

        case "hiding":
            if progress < 0.3 {
                output.bodyState = "crouch"
                output.eyeLeftState = "wide"
            } else {
                output.bodyState = "curl"
                output.eyeLeftState = "half"
                output.eyeRightState = "half"
                output.tailState = "wrap"
            }

        case "examining":
            output.bodyState = "stand"
            if progress < 0.5 {
                output.eyeLeftState = "wide"
                output.eyeRightState = "wide"
                output.whiskerState = "forward"
            } else {
                output.mouthState = "open"  // Sniffing
                output.whiskerState = "twitch"
            }

        case "rubbing":
            output.bodyState = "lean_forward"
            output.eyeLeftState = "closed"
            output.eyeRightState = "closed"
            output.tailState = "high"

        case "listening":
            output.bodyState = "sit"
            if stage >= .critter {
                let earPhase = (progress * 3).truncatingRemainder(dividingBy: 1.0)
                if earPhase < 0.5 {
                    output.earLeftState = "rotate_left"
                    output.earRightState = "neutral"
                } else {
                    output.earLeftState = "neutral"
                    output.earRightState = "rotate_right"
                }
            }
            output.eyeLeftState = "closed"
            output.eyeRightState = "closed"

        case "watching":
            output.bodyState = "sit"
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
            if stage >= .critter {
                output.earLeftState = "perk"
                output.earRightState = "perk"
            }
            output.tailState = "still"

        case "reflecting":
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
            if progress > 0.5 {
                // Double-take
                output.pawStates = ["fl": "tap", "fr": "ground",
                                    "bl": "ground", "br": "ground"]
            }

        case "eating":
            if progress < 0.7 {
                output.mouthState = "chew"
                output.eyeLeftState = "happy_squint"
                output.eyeRightState = "happy_squint"
            } else {
                output.mouthState = "lick"
                output.eyeLeftState = "closed"
                output.eyeRightState = "closed"
            }

        default:
            output.bodyState = "stand"
        }
    }

    /// Applies the conclusion animation.
    private func applyConclusionAnimation(
        template: String,
        stage: GrowthStage,
        output: inout LayerOutput
    ) {
        // Most interactions end with a satisfied expression
        output.bodyState = "stand"
        output.eyeLeftState = "happy_squint"
        output.eyeRightState = "happy_squint"
        output.mouthState = "closed"
        if stage >= .critter {
            output.earLeftState = "neutral"
            output.earRightState = "neutral"
        }
        output.tailState = "sway"
    }

    // MARK: - Completion

    /// Completes the current interaction.
    private func completeInteraction() {
        guard let interaction = activeInteraction else { return }
        lastInteractionTime = ProcessInfo.processInfo.systemUptime
        activeInteraction = nil

        NSLog("[Pushling/Objects] Completed interaction '%@' with '%@'",
              interaction.template.name, interaction.objectID)
    }
}
