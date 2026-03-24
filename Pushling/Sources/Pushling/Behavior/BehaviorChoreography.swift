// BehaviorChoreography.swift — Body part output for each cat behavior
// Separated from AutonomousLayer to keep files under 500 lines.
//
// Each behavior is a choreographed sequence using body part state names.
// Behaviors don't animate sprites directly — they produce LayerOutput
// properties that the behavior stack resolves and the blend controller
// smooths. This means behaviors can be interrupted at any point.

import Foundation
import CoreGraphics

// MARK: - Behavior Choreography

/// Produces LayerOutput properties for a specific behavior at a given progress.
/// Called by AutonomousLayer when in the .behavior state.
enum BehaviorChoreography {

    /// Applies the body part states for the given behavior and progress.
    ///
    /// - Parameters:
    ///   - behavior: The active behavior with elapsed time.
    ///   - stage: Current growth stage (for part availability gates).
    ///   - facing: Current facing direction (mutable for zoomies/spin).
    ///   - output: The LayerOutput to populate.
    /// - Returns: Updated facing direction (some behaviors flip it).
    static func apply(behavior: ActiveBehavior,
                      stage: GrowthStage,
                      facing: Direction,
                      output: inout LayerOutput) -> Direction {
        let def = behavior.definition
        let progress = behavior.elapsed / def.duration
        var facing = facing

        switch def.name {
        case "slow_blink":
            applySlow​Blink(progress: progress, output: &output)

        case "kneading":
            applyKneading(elapsed: behavior.elapsed, output: &output)

        case "grooming":
            applyGrooming(progress: progress, output: &output)

        case "loaf":
            applyLoaf(output: &output)

        case "zoomies":
            facing = applyZoomies(progress: progress, stage: stage,
                                   facing: facing, output: &output)

        case "tail_chase":
            applyTailChase(elapsed: behavior.elapsed, progress: progress,
                           output: &output)

        case "headbutt":
            applyHeadbutt(progress: progress, stage: stage, output: &output)

        case "predator_crouch":
            applyPredatorCrouch(stage: stage, output: &output)

        case "chattering":
            applyChattering(stage: stage, output: &output)

        case "tongue_blep":
            applyTongueBlep(output: &output)

        case "knocking_things_off":
            applyKnockingThingsOff(progress: progress, stage: stage,
                                    output: &output)

        case "if_i_fits_i_sits":
            applyIfIFitsISits(progress: progress, output: &output)

        case "meditation":
            applyMeditation(progress: progress, output: &output)

        default:
            output.bodyState = "stand"
        }

        return facing
    }

    // MARK: - Individual Behaviors

    /// Slow-blink: close (0.3s) -> hold (0.5s) -> open (0.3s).
    private static func applySlow​Blink(progress: Double,
                                        output: inout LayerOutput) {
        output.bodyState = "stand"
        // Close phase: 0–27%, Hold: 27–73%, Open: 73–100%
        if progress < 0.73 {
            output.eyeLeftState = "closed"
            output.eyeRightState = "closed"
        } else {
            output.eyeLeftState = "open"
            output.eyeRightState = "open"
        }
    }

    /// Kneading: alternating front paw push with half-lidded eyes.
    private static func applyKneading(elapsed: TimeInterval,
                                       output: inout LayerOutput) {
        output.bodyState = "stand"
        let kneadPhase = (elapsed * 2.0)
            .truncatingRemainder(dividingBy: 1.0)
        if kneadPhase < 0.5 {
            output.pawStates = ["fl": "knead", "fr": "ground",
                                "bl": "ground", "br": "ground"]
        } else {
            output.pawStates = ["fl": "ground", "fr": "knead",
                                "bl": "ground", "br": "ground"]
        }
        output.eyeLeftState = "half"
        output.eyeRightState = "half"
    }

    /// Grooming: lift paw -> lick face -> return.
    private static func applyGrooming(progress: Double,
                                       output: inout LayerOutput) {
        output.bodyState = "stand"
        if progress < 0.3 {
            output.pawStates = ["fl": "lift", "fr": "ground",
                                "bl": "ground", "br": "ground"]
        } else if progress < 0.8 {
            output.mouthState = "lick"
            output.pawStates = ["fl": "lift", "fr": "ground",
                                "bl": "ground", "br": "ground"]
        } else {
            output.mouthState = "closed"
            output.pawStates = ["fl": "ground", "fr": "ground",
                                "bl": "ground", "br": "ground"]
        }
    }

    /// Loaf: compact rectangle, tucked paws, wrapped tail, content eyes.
    private static func applyLoaf(output: inout LayerOutput) {
        output.bodyState = "loaf"
        output.pawStates = ["fl": "tuck", "fr": "tuck",
                            "bl": "tuck", "br": "tuck"]
        output.tailState = "wrap"
        output.eyeLeftState = "half"
        output.eyeRightState = "half"
    }

    /// Meditation: Sage+ exclusive — deep contemplation with eyes closed.
    /// Eyes flutter open at 80% progress. Represents wisdom and inner peace.
    private static func applyMeditation(progress: Double,
                                         output: inout LayerOutput) {
        output.bodyState = "loaf"
        output.pawStates = ["fl": "tuck", "fr": "tuck",
                            "bl": "tuck", "br": "tuck"]
        output.tailState = "wrap"
        output.earLeftState = "neutral"
        output.earRightState = "neutral"

        // Eyes closed for 80% of meditation, flutter open at the end
        if progress < 0.8 {
            output.eyeLeftState = "closed"
            output.eyeRightState = "closed"
        } else {
            // Flutter: alternate between closed and half-open
            let flutter = Int((progress - 0.8) * 50) % 2 == 0
            output.eyeLeftState = flutter ? "half" : "closed"
            output.eyeRightState = flutter ? "half" : "closed"
        }
    }

    /// Zoomies: sprint across bar and back with poof tail and wild ears.
    private static func applyZoomies(progress: Double,
                                      stage: GrowthStage,
                                      facing: Direction,
                                      output: inout LayerOutput) -> Direction {
        var facing = facing
        output.bodyState = "stand"
        output.walkSpeed = stage.baseRunSpeed > 0
            ? stage.baseRunSpeed * 1.5 : stage.baseWalkSpeed * 3
        output.tailState = "poof"
        if stage >= .critter {
            output.earLeftState = "wild"
            output.earRightState = "wild"
        }
        // Reverse direction once at halfway. Use a narrow single-frame window
        // to prevent rapid flip-flop at 60fps (the old 0.45-0.55 range caused
        // multiple flips per zoomies cycle).
        if progress > 0.49 && progress < 0.51 {
            facing = facing.flipped
        }
        output.facing = facing
        return facing
    }

    /// Tail chase: body spins with rapid direction changes.
    private static func applyTailChase(elapsed: TimeInterval,
                                        progress: Double,
                                        output: inout LayerOutput) {
        let spinPhase = (elapsed * 3.0)
            .truncatingRemainder(dividingBy: 1.0)
        output.bodyState = "stand"
        output.tailState = "chase"
        output.facing = spinPhase < 0.5 ? .left : .right
        if progress > 0.7 {
            output.eyeLeftState = "squint"
            output.eyeRightState = "squint"
        } else {
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
        }
    }

    /// Headbutt: lean forward with happy eyes.
    private static func applyHeadbutt(progress: Double,
                                       stage: GrowthStage,
                                       output: inout LayerOutput) {
        output.bodyState = progress < 0.6 ? "stand" : "stretch"
        if stage >= .critter {
            output.earLeftState = "neutral"
            output.earRightState = "neutral"
        }
        output.eyeLeftState = "happy"
        output.eyeRightState = "happy"
    }

    /// Predator crouch: low body, wide eyes, twitching tail tip.
    private static func applyPredatorCrouch(stage: GrowthStage,
                                             output: inout LayerOutput) {
        output.bodyState = "crouch"
        output.eyeLeftState = "wide"
        output.eyeRightState = "wide"
        output.tailState = "twitch_tip"
        if stage >= .critter {
            output.earLeftState = "perk"
            output.earRightState = "perk"
        }
    }

    /// Chattering: rapid jaw vibration with perked ears.
    private static func applyChattering(stage: GrowthStage,
                                         output: inout LayerOutput) {
        output.mouthState = "chatter"
        output.eyeLeftState = "wide"
        output.eyeRightState = "wide"
        if stage >= .critter {
            output.earLeftState = "perk"
            output.earRightState = "perk"
        }
    }

    /// Tongue blep: tongue stays out, everything else acts normal.
    private static func applyTongueBlep(output: inout LayerOutput) {
        output.mouthState = "blep"
    }

    /// Knocking things off: approach, bat with paw, watch it fall.
    private static func applyKnockingThingsOff(
        progress: Double,
        stage: GrowthStage,
        output: inout LayerOutput
    ) {
        if progress < 0.3 {
            // Approach and examine
            output.bodyState = "stand"
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
            if stage >= .critter {
                output.earLeftState = "perk"
                output.earRightState = "perk"
            }
        } else if progress < 0.5 {
            // Tentative paw tap
            output.bodyState = "stand"
            output.pawStates = ["fl": "tap", "fr": "ground",
                                "bl": "ground", "br": "ground"]
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
        } else if progress < 0.7 {
            // Deliberate push
            output.bodyState = "lean_forward"
            output.pawStates = ["fl": "push", "fr": "ground",
                                "bl": "ground", "br": "ground"]
            output.tailState = "twitch_tip"
        } else {
            // Watch it fall with satisfaction
            output.bodyState = "stand"
            output.eyeLeftState = "half"
            output.eyeRightState = "half"
            output.tailState = "sway"
        }
    }

    /// If I fits I sits: find a small space and squeeze into it.
    private static func applyIfIFitsISits(
        progress: Double,
        output: inout LayerOutput
    ) {
        if progress < 0.2 {
            // Examine the spot
            output.bodyState = "stand"
            output.eyeLeftState = "wide"
            output.eyeRightState = "wide"
        } else if progress < 0.4 {
            // Circle and test
            output.bodyState = "crouch"
            output.tailState = "twitch_tip"
        } else if progress < 0.6 {
            // Squeeze in
            output.bodyState = "curl"
            output.pawStates = ["fl": "tuck", "fr": "tuck",
                                "bl": "tuck", "br": "tuck"]
        } else {
            // Settled — content loaf in the spot
            output.bodyState = "loaf"
            output.pawStates = ["fl": "tuck", "fr": "tuck",
                                "bl": "tuck", "br": "tuck"]
            output.tailState = "wrap"
            output.eyeLeftState = "half"
            output.eyeRightState = "half"
        }
    }
}
