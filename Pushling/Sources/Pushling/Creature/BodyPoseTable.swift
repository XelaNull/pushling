// BodyPoseTable.swift — the bodyState -> BodyPoseTuple lookup
// (body-pose-pipeline.md §2 + §2b). 22 core tuples (12 static postures +
// 10 dynamic-state baselines) plus the 89-string alias map routing every
// other literal `bodyState` produced anywhere in the codebase to its
// nearest core tuple. Anything not found in either table (a habit/quirk/
// routine author's free-form text, or a genuinely new string this table
// doesn't yet know about) falls back to `stand` (identity) — the same
// "unknown state = neutral" rule the rest of the stack relies on.

import CoreGraphics

enum BodyPoseTable {

    // MARK: - 12 Static Postures (§2)

    private static let staticTuples: [String: BodyPoseTuple] = [
        "stand":         BodyPoseTuple(yScale: 1.00, xScale: 1.00, yOffset:  0.0,  zRotation: 0.0,  headOffset:  0.0,  pawAlpha: 1.0),
        "sit":           BodyPoseTuple(yScale: 0.90, xScale: 1.00, yOffset: -0.3,  zRotation: 0.0,  headOffset:  0.3,  pawAlpha: 1.0),
        "crouch":        BodyPoseTuple(yScale: 0.72, xScale: 1.12, yOffset: -0.6,  zRotation: 0.0,  headOffset: -0.2,  pawAlpha: 1.0),
        "lean_forward":  BodyPoseTuple(yScale: 0.95, xScale: 1.05, yOffset:  0.0,  zRotation: 0.0,  headOffset:  0.5,  pawAlpha: 1.0),
        "loaf":          BodyPoseTuple(yScale: 0.82, xScale: 1.10, yOffset: -0.35, zRotation: 0.0,  headOffset: -0.15, pawAlpha: 0.3),
        "curl":          BodyPoseTuple(yScale: 0.60, xScale: 1.15, yOffset: -0.8,  zRotation: 0.0,  headOffset: -0.45, pawAlpha: 0.35),
        "sleep_curl":    BodyPoseTuple(yScale: 0.60, xScale: 1.15, yOffset: -0.8,  zRotation: 0.0,  headOffset: -0.45, pawAlpha: 0.20),
        "roll_side":     BodyPoseTuple(yScale: 0.65, xScale: 1.30, yOffset: -0.5,  zRotation: 1.40, headOffset:  0.0,  pawAlpha: 0.55),
        // WO-19 sub-part 3 REVISE (Fix 2) — deviation-from-identity retuned
        // down ~40-50% (stretch) / ~43-45% (arch): the original amplitudes
        // read as distortion ("funhouse mirror"), not an animal stretching.
        // 📐 A real cat stretch is a SHAPE change (chest drop + rear up),
        // not uniform scale — that's WO-24's multi-phase choreography, NOT
        // this pass; here we only tame the amplitude.
        "stretch":       BodyPoseTuple(yScale: 1.12, xScale: 0.90, yOffset:  0.2,  zRotation: 0.0,  headOffset:  0.6,  pawAlpha: 1.0),
        "arch":          BodyPoseTuple(yScale: 1.10, xScale: 0.90, yOffset:  0.20, zRotation: 0.0,  headOffset: -0.3,  pawAlpha: 1.0),
        "alert":         BodyPoseTuple(yScale: 1.05, xScale: 0.95, yOffset:  0.2,  zRotation: 0.0,  headOffset:  0.25, pawAlpha: 1.0),
        "land":          BodyPoseTuple(yScale: 0.62, xScale: 1.30, yOffset: -0.4,  zRotation: 0.0,  headOffset: -0.3,  pawAlpha: 1.0),

        // WO-19 sub-part 2 additions — pulled VERBATIM from
        // idle-life-and-rest.md §2's Resting Posture Ladder table (not
        // re-derived): sphinx keeps pawAlpha near 1.0 ("the one rung that
        // keeps paws visible under the chest"); sprawl's `path-swap: yes`
        // note is DEFERRED — 📐 shipped as a scale-only approximation,
        // same precedent as curl/roll_side/sleep_curl (body-pose-pipeline.md's
        // own "designed, not built" path-swap carve-out). sprawl's
        // `pawStates["bl"]="kicked"` companion literal is a PawController
        // addition, not a table row — see PawController.swift.
        "sphinx":        BodyPoseTuple(yScale: 0.78, xScale: 1.05, yOffset: -0.25, zRotation: 0.0,  headOffset:  0.1,  pawAlpha: 1.0),
        "sprawl":        BodyPoseTuple(yScale: 0.60, xScale: 1.30, yOffset: -0.7,  zRotation: 0.0,  headOffset: -0.2,  pawAlpha: 0.6),

        // WO-19 sub-part 2 additions — groom/knead promoted from §2b alias
        // rows to first-class named tuples (charter tier-1: distinct
        // addressable poses, not routed through the alias map anymore).
        // Values are UNCHANGED from their prior alias targets
        // (lean_forward / loaf respectively) — not new design numbers,
        // just a first-class name for what was already the "nearest
        // existing tuple by visual intent" call from §2b.
        "groom":         BodyPoseTuple(yScale: 0.95, xScale: 1.05, yOffset:  0.0,  zRotation: 0.0,  headOffset:  0.5,  pawAlpha: 1.0),
        "knead":         BodyPoseTuple(yScale: 0.82, xScale: 1.10, yOffset: -0.35, zRotation: 0.0,  headOffset: -0.15, pawAlpha: 0.3),
    ]

    // MARK: - 10 Dynamic-State Baselines (§2)

    /// The "rest" tuple each dynamic state eases toward on entry (§1's
    /// generic 0.3s/0.15s ease). For the 7 continuously-animated states
    /// (see `continuousOverlayStates`), `BodyPoseController` overrides
    /// specific channels every frame on top of this baseline — see its
    /// `applyDynamicOverlay()`. `jump`/`pounce`/`flinch` need no overlay:
    /// their formula in §2 *is* "ease to this tuple and hold/return".
    private static let dynamicBaselineTuples: [String: BodyPoseTuple] = [
        "jump":   BodyPoseTuple(yScale: 0.85, xScale: 1.08, yOffset: -0.15, zRotation: 0.0,   headOffset: 0.0, pawAlpha: 1.0),
        "pounce": BodyPoseTuple(yScale: 1.10, xScale: 0.92, yOffset:  0.15, zRotation: 0.0,   headOffset: 0.5, pawAlpha: 1.0),
        "flinch": BodyPoseTuple(yScale: 0.80, xScale: 1.10, yOffset: -0.2,  zRotation: -0.08, headOffset: 0.0, pawAlpha: 1.0),
        "bounce": .identity,
        "spin":   .identity,
        "flip":   .identity,
        "float":  BodyPoseTuple(yScale: 0.95, xScale: 1.00, yOffset: 0.0, zRotation: 0.0, headOffset: 0.0, pawAlpha: 1.0),
        "glitch": .identity,
        "shiver": .identity,
        "shake":  .identity,
    ]

    /// The 7 dynamic states whose channels are continuously overridden by
    /// `BodyPoseController.applyDynamicOverlay()` rather than held at a
    /// fixed target. Exposed for tests / callers that need to know which
    /// core states are formula-driven vs. static-hold.
    static let continuousOverlayStates: Set<String> = [
        "bounce", "spin", "flip", "float", "glitch", "shiver", "shake",
    ]

    // MARK: - §2b: The Remaining 89 Strings — Alias Map

    /// Routes every other literal `bodyState` produced anywhere in the
    /// codebase to its nearest core tuple above. `wiggle` is deliberately
    /// absent — hunt-and-pounce.md owns its render formula, not this
    /// table (§2's alias-table note); it falls through to the terminal
    /// `stand` fallback below, same as any truly-unmapped string.
    private static let aliasMap: [String: String] = [
        "ascend": "float",
        "back_away": "crouch",
        "balance_block": "stand",
        "bask": "stretch",
        "belly_up": "roll_side",
        "celebrate": "bounce",
        "clap": "bounce",
        "co_glow": "stand",
        "confused": "alert",
        "construction": "stand",
        "contemplate": "sit",
        "costume_transform": "stand",
        "dance_frame_1": "bounce",
        "dance_frame_2": "bounce",
        "dance_frame_3": "bounce",
        "dance_frame_4": "bounce",
        "dim_environment": "stand",
        "dual_glow": "stand",
        "evolving": "arch",
        "examine": "lean_forward",
        "examine_self": "lean_forward",
        "face_camera": "stand",
        "fall": "land",
        "first_word_ceremony": "alert",
        "flat_press": "crouch",
        "flex": "arch",
        "flicker": "glitch",
        "float_up": "float",
        "freeze": "alert",
        "ghost_echo": "stand",
        "glitch_static": "glitch",
        "glow": "stand",
        "handstand": "flip",
        "handstand_prep": "crouch",
        "head_in_box": "curl",
        "head_tilt_left": "alert",
        "head_tilt_right": "alert",
        "hide_peek": "crouch",
        "howl": "arch",
        "huddle": "curl",
        "jolt_forward": "flinch",
        "jump_down": "land",
        "lean_back": "arch",
        "loaf_prep": "loaf",
        "look_around": "alert",
        "look_back": "alert",
        "look_up": "alert",
        "meditate": "sit",
        "mind_blown": "flinch",
        "montage_flash": "stand",
        "nod": "stand",
        "pick_up": "lean_forward",
        "place_item": "lean_forward",
        "produce_item": "lean_forward",
        "produce_scroll": "lean_forward",
        "push_forward": "lean_forward",
        "reach_behind": "lean_forward",
        "sniff": "lean_forward",
        "playing": "bounce",
        "pose": "stand",
        "reading": "sit",
        "reminisce": "sit",
        "sing": "sit",
        "sit_high": "sit",
        "replay_trick": "stand",
        "roll_back": "roll_side",
        "roll_onto_back": "roll_side",
        "run": "stand",
        "shake_head": "shake",
        "slide": "crouch",
        "sneak": "crouch",
        "sniff_down": "crouch",
        "splat": "crouch",
        "slouch": "loaf",
        "spooky_pose": "arch",
        "squeeze": "curl",
        "stagger": "shiver",
        "wobble": "shiver",
        "stand_hind_legs": "alert",
        "swagger": "arch",
        "tense": "crouch",
        "thumbs_up": "bounce",
        "tumble": "flip",
        "walk": "stand",
        "walk_rhythm": "stand",
        "walk_inverted": "stand",
    ]

    // MARK: - Resolution

    /// Resolves any bodyState string to one of the core strings above,
    /// applying defense-in-depth stage gates (§2's dynamic-states note on
    /// `glitch`; idle-life-and-rest.md §2.1's Resting Posture Ladder rung
    /// availability for `sphinx`/`sprawl` — WO-19 sub-part 2) and falling
    /// back to `stand` for anything unrecognized or gated below its stage.
    static func resolve(_ raw: String, stage: GrowthStage) -> String {
        let candidate: String
        if staticTuples[raw] != nil || dynamicBaselineTuples[raw] != nil {
            candidate = raw
        } else if let aliased = aliasMap[raw] {
            candidate = aliased
        } else {
            candidate = "stand"
        }

        if candidate == "glitch", stage < .sage {
            return "stand"
        }
        // idle-life-and-rest.md §2.1: Sphinx appears ONLY in Beast's full
        // 5-rung ladder (Critter/Sage/Apex all withhold it; Drop's 2-rung
        // ladder never lists it either). NOT a simple ">=" gate.
        if candidate == "sphinx", stage != .beast {
            return "stand"
        }
        // idle-life-and-rest.md §2.1: Sprawl is available at Drop (relaxed
        // puddle-spread) AND Beast (full ladder) — withheld at Critter
        // (tightest silhouette), Sage, and Apex (Curl-only via
        // levitation-sleep reinterpretation).
        if candidate == "sprawl", stage != .drop, stage != .beast {
            return "stand"
        }
        return candidate
    }

    /// The baseline (Critter-scale, pre-stage-scalar) target tuple for a
    /// resolved core state (always one of the 22 keys above once passed
    /// through `resolve(_:stage:)`).
    static func targetTuple(for resolvedState: String) -> BodyPoseTuple {
        staticTuples[resolvedState] ?? dynamicBaselineTuples[resolvedState] ?? .identity
    }
}
