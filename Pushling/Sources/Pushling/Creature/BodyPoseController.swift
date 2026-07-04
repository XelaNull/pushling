// BodyPoseController.swift — the missing 13th body-part controller.
// Owns bodyNode's pose contribution (torso shape), a headNode additive
// offset, and a paw-alpha multiplier — resolved from `bodyState` every
// frame. Does NOT own an SKNode itself (unlike its 12 siblings): the
// actual writes to bodyNode/headNode/paw alpha happen at the single
// compose point, `CreatureNode.updateBreathing()` — see
// docs/SYSTEMS/body-pose-pipeline.md §1 and §6. This class only computes
// `currentPose`, the value that compose point reads.
//
// Table lookup (111 bodyState strings -> tuple) lives in BodyPoseTable.swift.

import CoreGraphics
import Foundation

// MARK: - Body Pose Tuple

/// A resolved pose, authored at Critter scale — composed multiplicatively/
/// additively with breathing, drop-hop, and velocity squash-stretch at the
/// single compose point. Tuple order matches body-pose-pipeline.md §2:
/// (yScale, xScale, yOffset pt, zRotation rad, headOffset pt, pawAlpha).
struct BodyPoseTuple: Equatable {
    var yScale: CGFloat
    var xScale: CGFloat
    var yOffset: CGFloat
    var zRotation: CGFloat
    var headOffset: CGFloat
    var pawAlpha: CGFloat

    static let identity = BodyPoseTuple(
        yScale: 1.0, xScale: 1.0, yOffset: 0.0,
        zRotation: 0.0, headOffset: 0.0, pawAlpha: 1.0
    )

    /// Component-wise interpolation for the internal blend ease (§1).
    static func lerp(_ a: BodyPoseTuple, _ b: BodyPoseTuple, _ t: CGFloat) -> BodyPoseTuple {
        BodyPoseTuple(
            yScale: Pushling_lerp(a.yScale, b.yScale, t),
            xScale: Pushling_lerp(a.xScale, b.xScale, t),
            yOffset: Pushling_lerp(a.yOffset, b.yOffset, t),
            zRotation: Pushling_lerp(a.zRotation, b.zRotation, t),
            headOffset: Pushling_lerp(a.headOffset, b.headOffset, t),
            pawAlpha: Pushling_lerp(a.pawAlpha, b.pawAlpha, t)
        )
    }
}

/// Local alias so this file doesn't collide with the global `lerp(CGFloat,...)`
/// defined in Behavior/LayerTypes.swift while staying obviously the same op.
private func Pushling_lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    lerp(a, b, t)
}

// MARK: - Body Pose Controller

/// The missing 13th part controller. Instantiated by `CreatureNode`
/// alongside its 12 siblings, gated `stage >= .drop` per the WO-6 build
/// contract (see the divergence note below).
///
/// **Flagged divergence (not silently resolved):** body-pose-pipeline.md §3
/// tabulates an Egg amplitude scalar (0.3/0.3), implying this controller
/// should also run at Egg — but §1's own gate instruction, and the WO-6
/// dispatch that authorized this build, both say `stage >= .drop` (matching
/// the pattern cited from `ResolvedCreatureState.defaultState`, even though
/// that pattern actually gates ears/tail at `.critter`, not `.drop` — the
/// citation itself doesn't quite match the code it cites). Built to the
/// WO's explicit instruction: gated at Drop. `Stage.egg`'s row in
/// `BodyPoseController.stageScalars` is therefore currently unreachable —
/// left in place rather than deleted, in case the gate is revisited.
final class BodyPoseController {

    // MARK: - Public State

    private(set) var currentState = "stand"

    /// The final pose CreatureNode.updateBreathing() composes with —
    /// already stage-scaled and Egg-zRotation-gated (§3).
    private(set) var currentPose: BodyPoseTuple = .identity

    /// Current growth stage — drives the §3 per-stage amplitude scalars.
    var stage: GrowthStage {
        didSet { recomputeCurrentPose() }
    }

    // MARK: - Internal Blend State (§1)

    /// Critter-scale pose being eased from (snapshot at the last setState).
    private var easeFrom: BodyPoseTuple = .identity
    /// Critter-scale target pose for the current state (before dynamic overlay).
    private var easeTo: BodyPoseTuple = .identity
    private var easeElapsed: TimeInterval = 0
    private var easeDuration: TimeInterval = 0

    /// Critter-scale pose after the ease + any dynamic overlay this frame —
    /// the input to the per-stage scalar pass that produces `currentPose`.
    private var authoredPose: BodyPoseTuple = .identity

    /// Time since the current bodyState was entered — drives the
    /// continuous dynamic-state formulas (bounce/spin/flip/float/glitch/
    /// shiver/shake). Resets only when the resolved state actually changes.
    private var dynamicStateTime: TimeInterval = 0

    /// 0.3s ease-in-out (expression change) — the default, reusing the
    /// existing "mouth/body" expression sub-timing slot
    /// (BlendController.expressionSubTiming["bodyState"]).
    static let defaultBlendDuration: TimeInterval = 0.3

    /// 0.15s reflex-interrupt cascade timing — reused, not invented, for
    /// bodyStates that arrived via a Physics/Reflex-priority path.
    static let reflexPriorityBlendDuration: TimeInterval = 0.15

    // MARK: - Init

    init(stage: GrowthStage) {
        self.stage = stage
        recomputeCurrentPose()
    }

    // MARK: - Set State

    /// Transition to a named bodyState. Mirrors the sibling controllers'
    /// `setState(_:duration:)` shape; `isReflexPriority` is additive (with a
    /// default) because the "previous frame's per-property winner" data §1
    /// describes as already computed by `BehaviorStack.resolveOutputs()`
    /// does not actually exist in shipped code today — `resolveOutputs`
    /// only returns the merged value, discarding which layer won. Rather
    /// than silently inventing a bigger refactor, `BehaviorStackOutput`
    /// gained one derived boolean (`bodyStateWonByReflexOrPhysics`,
    /// computed inline from data already in scope) and it's threaded
    /// through here — see PushlingScene.applyBehaviorOutput.
    ///
    /// - Parameter duration: unused (matches the sibling controllers' call
    ///   shape exactly) — this controller's own internal ease (0.3s/0.15s)
    ///   always governs its timing, per §1.
    func setState(_ requested: String, duration: TimeInterval = 0,
                  isReflexPriority: Bool = false) {
        let resolved = BodyPoseTable.resolve(requested, stage: stage)
        guard resolved != currentState else { return }

        easeFrom = authoredPose
        easeTo = BodyPoseTable.targetTuple(for: resolved)
        easeElapsed = 0
        easeDuration = isReflexPriority
            ? Self.reflexPriorityBlendDuration
            : Self.defaultBlendDuration
        dynamicStateTime = 0
        currentState = resolved
    }

    // MARK: - Per-Frame Update

    func update(deltaTime: TimeInterval) {
        dynamicStateTime += deltaTime

        if easeDuration > 0, easeElapsed < easeDuration {
            easeElapsed += deltaTime
            let t = CGFloat(clamp(easeElapsed / easeDuration, min: 0.0, max: 1.0))
            let eased = CGFloat(Easing.easeInOut(Double(t)))
            authoredPose = BodyPoseTuple.lerp(easeFrom, easeTo, eased)
        } else {
            authoredPose = easeTo
        }

        applyDynamicOverlay()
        recomputeCurrentPose()
    }

    // MARK: - Dynamic State Overlays (§2's 7 continuously-animated states)

    /// Static postures and the 3 "ease-to-target-and-hold" dynamic states
    /// (jump/pounce/flinch) need nothing beyond the generic ease above.
    /// These 7 states oscillate continuously and override specific
    /// channels of `authoredPose` every frame on top of that ease.
    private func applyDynamicOverlay() {
        let t = dynamicStateTime
        switch currentState {
        case "bounce":
            // Oscillates yScale 0.90-1.15 at 2.2Hz; xScale is deliberately
            // left at identity — it "follows the squash-stretch reciprocal
            // each instant" (§5), applied downstream at the compose point.
            let freq = 2.2
            authoredPose.yScale = 1.025 + 0.125 * CGFloat(sin(2 * Double.pi * freq * t))
            authoredPose.xScale = 1.0

        case "spin":
            // zRotation sweeps 0->2pi over 1.5s (spin perform action's own
            // duration, PerformActionMapping.swift:29-33).
            let angularVelocity = 2 * CGFloat.pi / 1.5
            authoredPose.zRotation = (angularVelocity * CGFloat(t))
                .truncatingRemainder(dividingBy: 2 * .pi)

        case "flip":
            // zRotation sweeps 0->2pi over 1.2s (backflip's duration,
            // PerformActionMapping.swift:79-85). positionY apex is §4's
            // concern, not this controller's.
            let angularVelocity = 2 * CGFloat.pi / 1.2
            authoredPose.zRotation = (angularVelocity * CGFloat(t))
                .truncatingRemainder(dividingBy: 2 * .pi)

        case "float":
            // yScale eases to 0.95 via the generic ease above; zRotation
            // drifts continuously on top of it.
            authoredPose.zRotation = 0.05 * CGFloat(sin(2 * Double.pi * 0.2 * t))

        case "glitch":
            // Sage+ gate is enforced upstream in BodyPoseTable.resolve, but
            // re-checked here defensively. zRotation only — §2's alpha
            // jitter has no channel in the §6 compose formula (no alpha
            // line at all), so it is intentionally NOT implemented here;
            // flagged in the WO report as a spec gap rather than guessed at.
            guard stage >= .sage else { break }
            authoredPose.zRotation = CGFloat.random(in: -0.3...0.3)

        case "shiver":
            // yScale/xScale jitter +/-0.03 at 9Hz, zRotation +/-0.02rad —
            // phase-offset sines rather than true RNG so this stays
            // deterministic/testable, matching CreatureNode's existing
            // noise-idle convention.
            let freq = 9.0
            authoredPose.yScale = 1.0 + 0.03 * CGFloat(sin(2 * Double.pi * freq * t))
            authoredPose.xScale = 1.0 + 0.03 * CGFloat(sin(2 * Double.pi * freq * t + .pi / 2))
            authoredPose.zRotation = 0.02 * CGFloat(sin(2 * Double.pi * freq * t + .pi))

        case "shake":
            // zRotation oscillates +/-0.15rad at 10Hz, decaying over the
            // reflex's own duration (3.5s, HookEventProcessor.swift:335's
            // compact_daze) — the torso's residual version of a mostly
            // head-owned shake.
            let freq = 10.0
            let decayWindow = 3.5
            let amplitudeFactor = max(0, 1.0 - t / decayWindow)
            authoredPose.zRotation = 0.15 * CGFloat(amplitudeFactor)
                * CGFloat(sin(2 * Double.pi * freq * t))

        default:
            break
        }
    }

    // MARK: - Per-Stage Amplitude Scalars (§3)

    private func recomputeCurrentPose() {
        currentPose = Self.applyStageScalars(authoredPose, stage: stage)
    }

    /// Pure, testable transform: scales the *deviation from identity*, not
    /// the raw value, so `stand`'s already-neutral tuple is untouched at
    /// every stage. yScale/xScale use `stageScaleScalar`; yOffset/
    /// zRotation/headOffset use `stageOffsetScalar`; pawAlpha passes
    /// through unscaled (it's a visibility multiplier, not a deformation
    /// amplitude — §3 never mentions scaling it). Egg additionally hard-
    /// gates zRotation to 0 (already claimed by egg-wobble).
    static func applyStageScalars(_ pose: BodyPoseTuple, stage: GrowthStage) -> BodyPoseTuple {
        let (scaleScalar, offsetScalar) = stageScalars(for: stage)
        var result = pose
        result.yScale = 1.0 + (pose.yScale - 1.0) * scaleScalar
        result.xScale = 1.0 + (pose.xScale - 1.0) * scaleScalar
        result.yOffset = pose.yOffset * offsetScalar
        result.headOffset = pose.headOffset * offsetScalar
        result.zRotation = (stage == .egg) ? 0 : pose.zRotation * offsetScalar
        return result
    }

    /// (stageScaleScalar, stageOffsetScalar) per body-pose-pipeline.md §3.
    static func stageScalars(for stage: GrowthStage) -> (scale: CGFloat, offset: CGFloat) {
        switch stage {
        case .egg:     return (0.3, 0.3)   // unreachable while gated stage >= .drop — see the divergence note above
        case .drop:    return (0.5, 0.6)
        case .critter: return (1.0, 1.0)
        case .beast:   return (1.15, 1.10)
        case .sage:    return (0.85, 0.85)
        case .apex:    return (0.70, 0.50)
        }
    }
}
