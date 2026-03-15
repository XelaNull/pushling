// ExpressionMapping.swift — Maps expression names to body part states
// Used by CommandHandlers.handleExpress to create LayerOutput from
// expression names like "joy", "curiosity", "sleepy", etc.

import CoreGraphics

/// Maps named expressions to concrete body-part states for the AI-directed layer.
enum ExpressionMapping {

    /// Maps an expression name and intensity to a LayerOutput.
    /// Returns nil properties for body parts that shouldn't be overridden
    /// (defers to lower layers like Autonomous).
    static func layerOutput(
        for expression: String,
        intensity: Double
    ) -> LayerOutput {
        switch expression {

        case "joy":
            return LayerOutput(
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "happy_squint",
                eyeRightState: "happy_squint",
                tailState: intensity > 0.7 ? "wag" : "high",
                mouthState: "smile"
            )

        case "curiosity":
            return LayerOutput(
                earLeftState: "forward",
                earRightState: "rotate_right",
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: "twitch_tip",
                mouthState: "open_small"
            )

        case "surprise":
            return LayerOutput(
                bodyState: intensity > 0.7 ? "arch" : nil,
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: intensity > 0.8 ? "poof" : "high",
                mouthState: "open_wide",
                whiskerState: "forward"
            )

        case "contentment":
            return LayerOutput(
                earLeftState: "neutral",
                earRightState: "neutral",
                eyeLeftState: "half",
                eyeRightState: "half",
                tailState: "sway",
                mouthState: "closed"
            )

        case "thinking":
            return LayerOutput(
                earLeftState: "rotate_left",
                earRightState: "neutral",
                eyeLeftState: "squint",
                eyeRightState: "look_up",
                tailState: "twitch_tip",
                mouthState: "closed"
            )

        case "mischief":
            return LayerOutput(
                earLeftState: "flat",
                earRightState: "perk",
                eyeLeftState: "squint",
                eyeRightState: "wide",
                tailState: "high",
                mouthState: "smirk"
            )

        case "pride":
            return LayerOutput(
                bodyState: "stretch",
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "half",
                eyeRightState: "half",
                tailState: "high",
                mouthState: "smile"
            )

        case "embarrassment":
            return LayerOutput(
                bodyState: "crouch",
                earLeftState: "flat",
                earRightState: "flat",
                eyeLeftState: "squint",
                eyeRightState: "look_down",
                tailState: "curl",
                mouthState: "closed"
            )

        case "determination":
            return LayerOutput(
                bodyState: "lean_forward",
                earLeftState: "forward",
                earRightState: "forward",
                eyeLeftState: "narrow",
                eyeRightState: "narrow",
                tailState: "stiff",
                mouthState: "closed"
            )

        case "wonder":
            return LayerOutput(
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: "sway",
                mouthState: "open_small",
                auraState: intensity > 0.7 ? "sparkle" : nil
            )

        case "sleepy":
            return LayerOutput(
                bodyState: intensity > 0.8 ? "curl" : "loaf",
                earLeftState: "flat",
                earRightState: "flat",
                eyeLeftState: "droopy",
                eyeRightState: "droopy",
                tailState: "curl",
                mouthState: intensity > 0.6 ? "yawn" : "closed"
            )

        case "love":
            return LayerOutput(
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "slow_blink",
                eyeRightState: "slow_blink",
                tailState: "sway",
                mouthState: "smile",
                auraState: "hearts"
            )

        case "confusion":
            return LayerOutput(
                earLeftState: "rotate_left",
                earRightState: "rotate_right",
                eyeLeftState: "squint",
                eyeRightState: "wide",
                tailState: "twitch_tip",
                mouthState: "open_small"
            )

        case "excitement":
            return LayerOutput(
                bodyState: intensity > 0.8 ? "bounce" : nil,
                earLeftState: "perk",
                earRightState: "perk",
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: "wag",
                mouthState: "smile",
                whiskerState: "forward"
            )

        case "melancholy":
            return LayerOutput(
                earLeftState: "flat",
                earRightState: "flat",
                eyeLeftState: "half",
                eyeRightState: "half",
                tailState: "low",
                mouthState: "pout"
            )

        case "neutral":
            // Return empty — let autonomous layer take over
            return .empty

        default:
            return .empty
        }
    }

    /// Returns a human-readable description of what the expression looks like.
    /// Used in the response to Claude so it knows what happened.
    static func description(for expression: String) -> String {
        switch expression {
        case "joy":            return "ears perked, eyes squinted happily, tail high, smiling"
        case "curiosity":      return "one ear forward, one rotated, eyes wide, tail tip twitching"
        case "surprise":       return "ears perked, eyes wide, tail poofed, mouth open"
        case "contentment":    return "ears relaxed, eyes half-closed, tail swaying gently"
        case "thinking":       return "one ear rotated, one eye squinted, tail tip twitching"
        case "mischief":       return "one ear flat one perked, asymmetric eyes, tail high"
        case "pride":          return "body stretched tall, ears perked, eyes confident, tail high"
        case "embarrassment":  return "body crouched, ears flat, eyes averted, tail curled"
        case "determination":  return "body leaning forward, ears forward, eyes narrowed"
        case "wonder":         return "ears perked, eyes wide, mouth slightly open, tail swaying"
        case "sleepy":         return "ears drooping, eyes heavy, body curling, yawning"
        case "love":           return "slow-blinking, ears perked, tail swaying, smiling"
        case "confusion":      return "ears rotating opposite ways, one eye squinted one wide"
        case "excitement":     return "ears perked, eyes wide, tail wagging, bouncing"
        case "melancholy":     return "ears flat, eyes half-closed, tail low, pouting"
        case "neutral":        return "relaxed, returning to natural state"
        default:               return "expression applied"
        }
    }
}
