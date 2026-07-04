// PerformActionMapping.swift — Maps perform action names to LayerOutput + duration
// Pure data mapping extracted from ActionHandlers.swift to keep file sizes under 500 lines.
// Each entry defines the body part states and duration for a built-in perform action.

import Foundation
import CoreGraphics

/// Maps a perform action name to a LayerOutput and duration.
/// Returns nil if the action is unknown or stage-gated.
///
/// This is a pure function with no side effects — suitable for
/// both the AI-directed layer and the sequence handler.
enum PerformActionMapping {

    static func map(
        _ action: String,
        variant: String,
        stage: GrowthStage
    ) -> (LayerOutput, TimeInterval)? {
        switch action {
        case "wave":
            var out = LayerOutput()
            out.pawStates = ["fr": "wave"]
            out.eyeLeftState = "happy_squint"
            out.eyeRightState = "happy_squint"
            out.mouthState = "smile"
            out.tailState = "sway"
            return (out, 2.0)
        case "spin":
            var out = LayerOutput()
            out.bodyState = "spin"
            out.tailState = "extended"
            return (out, 1.5)
        case "bow":
            var out = LayerOutput()
            out.bodyState = "lean_forward"
            out.earLeftState = "flat"
            out.earRightState = "flat"
            out.eyeLeftState = "closed"
            out.eyeRightState = "closed"
            return (out, 2.0)
        case "dance":
            var out = LayerOutput()
            out.bodyState = "bounce"
            out.tailState = "wag"
            out.earLeftState = "perk"
            out.earRightState = "perk"
            out.mouthState = "smile"
            return (out, 3.0)
        case "peek":
            var out = LayerOutput()
            out.bodyState = "crouch"
            out.eyeLeftState = "peek"
            out.eyeRightState = "wide"
            out.earLeftState = "perk"
            out.earRightState = "perk"
            return (out, 2.5)
        case "meditate":
            var out = LayerOutput()
            out.bodyState = "sit"
            out.eyeLeftState = "closed"
            out.eyeRightState = "closed"
            out.tailState = "sway"
            out.earLeftState = "neutral"
            out.earRightState = "neutral"
            out.auraState = "pulse"
            out.walkSpeed = 0
            return (out, 5.0)
        case "flex":
            var out = LayerOutput()
            out.bodyState = "stretch"
            out.tailState = "high"
            out.earLeftState = "perk"
            out.earRightState = "perk"
            out.eyeLeftState = "narrow"
            out.eyeRightState = "narrow"
            out.mouthState = "smirk"
            return (out, 2.0)
        case "backflip":
            guard stage >= .beast else { return nil }
            var out = LayerOutput()
            out.bodyState = "flip"
            out.positionY = 12.0
            out.tailState = "extended"
            return (out, 1.2)
        case "dig":
            var out = LayerOutput()
            out.bodyState = "crouch"
            out.pawStates = ["fl": "dig", "fr": "dig"]
            out.tailState = "high"
            out.earLeftState = "forward"
            out.earRightState = "forward"
            return (out, 3.0)
        case "examine":
            var out = LayerOutput()
            out.bodyState = "lean_forward"
            out.eyeLeftState = "wide"
            out.eyeRightState = "wide"
            out.earLeftState = "forward"
            out.earRightState = "rotate_right"
            out.tailState = "twitch_tip"
            return (out, 3.0)
        case "nap":
            var out = LayerOutput()
            out.bodyState = "curl"
            out.eyeLeftState = "closed"
            out.eyeRightState = "closed"
            out.earLeftState = "flat"
            out.earRightState = "flat"
            out.tailState = "curl"
            out.mouthState = "closed"
            out.walkSpeed = 0
            return (out, 8.0)
        case "celebrate":
            var out = LayerOutput()
            out.bodyState = "bounce"
            out.tailState = "wag"
            out.earLeftState = "perk"
            out.earRightState = "perk"
            out.eyeLeftState = "happy_squint"
            out.eyeRightState = "happy_squint"
            out.mouthState = "smile"
            out.auraState = "sparkle"
            return (out, 3.0)
        case "shiver":
            var out = LayerOutput()
            out.bodyState = "shiver"
            out.earLeftState = "flat"
            out.earRightState = "flat"
            out.tailState = "curl"
            return (out, 2.0)
        case "stretch":
            var out = LayerOutput()
            out.bodyState = "stretch"
            out.tailState = "extended"
            out.earLeftState = "neutral"
            out.earRightState = "neutral"
            out.eyeLeftState = "closed"
            out.eyeRightState = "closed"
            out.mouthState = "yawn"
            return (out, 2.5)
        case "play_dead":
            var out = LayerOutput()
            out.bodyState = "roll_side"
            out.eyeLeftState = "x"
            out.eyeRightState = "x"
            out.tailState = "limp"
            out.earLeftState = "flat"
            out.earRightState = "flat"
            out.mouthState = "open_small"
            out.walkSpeed = 0
            return (out, 4.0)
        case "conduct":
            guard stage >= .sage else { return nil }
            var out = LayerOutput()
            out.pawStates = ["fr": "conduct"]
            out.bodyState = "stand"
            out.earLeftState = "perk"
            out.earRightState = "perk"
            out.eyeLeftState = "half"
            out.eyeRightState = "half"
            out.tailState = "sway"
            return (out, 4.0)
        case "glitch":
            guard stage >= .sage else { return nil }
            var out = LayerOutput()
            out.bodyState = "glitch"
            out.auraState = "static"
            out.eyeLeftState = "glitch"
            out.eyeRightState = "glitch"
            return (out, 1.5)
        case "transcend":
            guard stage >= .apex else { return nil }
            var out = LayerOutput()
            out.bodyState = "float"
            out.positionY = 15.0
            out.auraState = "transcendent"
            out.eyeLeftState = "glow"
            out.eyeRightState = "glow"
            out.tailState = "flow"
            out.walkSpeed = 0
            return (out, 6.0)

        // WO-19 sub-part 2 REVISE (Fix 3) — perform-triggerable postures.
        // MIRRORED in mcp/src/tools/perform-behaviors.ts's VALID_BEHAVIORS
        // (WO-23) — keep the loaf/sphinx/sprawl/curl/groom/knead name list in
        // sync across both services; the daemon is the source of truth.
        // These don't need WO-20's autonomous SELECTION to be proven live;
        // a persistent AI-Directed-layer trigger is enough (the same path
        // `meditate` already uses to hold `sit` for 5s). No stage `guard`
        // here for sphinx/sprawl — BodyPoseTable.resolve() already owns
        // that gate (sphinx=.beast only, sprawl=.drop/.beast only) and
        // falls back to `stand` cleanly on a wrong-stage request; adding a
        // second gate here would duplicate, not reinforce, that ownership.
        case "loaf":
            var out = LayerOutput()
            out.bodyState = "loaf"
            out.tailState = "sway"
            out.eyeLeftState = "half"
            out.eyeRightState = "half"
            out.walkSpeed = 0
            return (out, 6.0)
        case "sphinx":
            var out = LayerOutput()
            out.bodyState = "sphinx"
            out.eyeLeftState = "half"
            out.eyeRightState = "half"
            out.tailState = "sway"
            out.walkSpeed = 0
            return (out, 6.0)
        case "sprawl":
            var out = LayerOutput()
            out.bodyState = "sprawl"
            out.pawStates = ["bl": "kicked"]
            out.eyeLeftState = "half"
            out.eyeRightState = "half"
            out.walkSpeed = 0
            return (out, 6.0)
        case "curl":
            var out = LayerOutput()
            out.bodyState = "curl"
            out.tailState = "curl"
            out.eyeLeftState = "closed"
            out.eyeRightState = "closed"
            out.walkSpeed = 0
            return (out, 6.0)
        case "groom":
            var out = LayerOutput()
            out.bodyState = "groom"
            out.pawStates = ["fl": "lift"]
            out.mouthState = "lick"
            return (out, 4.0)
        case "knead":
            var out = LayerOutput()
            out.bodyState = "knead"
            out.pawStates = ["fl": "knead", "fr": "knead"]
            out.eyeLeftState = "half"
            out.eyeRightState = "half"
            return (out, 6.0)
        default:
            return nil
        }
    }
}
