// BodyPosePipelineTests.swift — Unit tests for the WO-6 body pose pipeline
// (docs/SYSTEMS/body-pose-pipeline.md §1-§3, §5-§6). Exercises the pure,
// SKNode-free pieces directly: the bodyState -> tuple table lookup
// (core/alias/unmapped-fallback), the per-stage amplitude scalars, and the
// §6 compose formula — mirroring PushlingSceneComposeTests.swift's pattern
// of testing extracted static helpers without a live scene.

import XCTest
@testable import Pushling

final class BodyPoseTableTests: XCTestCase {

    // MARK: - Core Lookup

    func testCoreStaticStateResolvesToItself() {
        XCTAssertEqual(BodyPoseTable.resolve("crouch", stage: .critter), "crouch")
        let tuple = BodyPoseTable.targetTuple(for: "crouch")
        XCTAssertEqual(tuple.yScale, 0.72)
        XCTAssertEqual(tuple.xScale, 1.12)
        XCTAssertEqual(tuple.yOffset, -0.6)
        XCTAssertEqual(tuple.headOffset, -0.2)
    }

    func testCoreDynamicBaselineResolvesToItself() {
        XCTAssertEqual(BodyPoseTable.resolve("pounce", stage: .critter), "pounce")
        let tuple = BodyPoseTable.targetTuple(for: "pounce")
        XCTAssertEqual(tuple.yScale, 1.10)
        XCTAssertEqual(tuple.xScale, 0.92)
        XCTAssertEqual(tuple.headOffset, 0.5)
    }

    // MARK: - Alias Map (§2b)

    func testAliasRoutesToNearestCoreTuple() {
        // "howl" -> "arch" per §2b (chin-up arched-back read).
        let resolved = BodyPoseTable.resolve("howl", stage: .critter)
        XCTAssertEqual(resolved, "arch")
        XCTAssertEqual(BodyPoseTable.targetTuple(for: resolved),
                       BodyPoseTable.targetTuple(for: "arch"))
    }

    func testDanceFrameSeriesAllRouteToBounce() {
        for i in 1...4 {
            XCTAssertEqual(BodyPoseTable.resolve("dance_frame_\(i)", stage: .critter), "bounce")
        }
    }

    func testCelebrateNamingCollisionRoutesToBounce() {
        // §2b: "celebrate" keyframe body-field literal and the perform
        // action's own bodyState="bounce" both land on the same tuple.
        XCTAssertEqual(BodyPoseTable.resolve("celebrate", stage: .critter), "bounce")
    }

    // MARK: - Unmapped Fallback (§2's "unmapped strings" rule)

    func testUnmappedFreeFormTextFallsBackToStand() {
        // A habit/quirk/routine author's arbitrary label — not in the
        // core table or the alias map.
        XCTAssertEqual(BodyPoseTable.resolve("did_a_kickflip", stage: .critter), "stand")
    }

    func testWiggleIsDeliberatelyUnaliasedAndFallsBackToStand() {
        // hunt-and-pounce.md owns wiggle's render formula, not this table
        // (§2b's alias-table note) — it must still resolve to something
        // sane rather than crash or freeze.
        XCTAssertEqual(BodyPoseTable.resolve("wiggle", stage: .critter), "stand")
    }

    // MARK: - Glitch's Sage+ Gate

    func testGlitchBelowSageFallsBackToStand() {
        XCTAssertEqual(BodyPoseTable.resolve("glitch", stage: .beast), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("glitch_static", stage: .beast), "stand",
                       "alias resolution must also respect the Sage+ gate")
    }

    func testGlitchAtSageOrAboveResolvesNormally() {
        XCTAssertEqual(BodyPoseTable.resolve("glitch", stage: .sage), "glitch")
        XCTAssertEqual(BodyPoseTable.resolve("glitch", stage: .apex), "glitch")
    }
}

final class BodyPoseControllerStageScalarTests: XCTestCase {

    /// Critter is the authored baseline — deviation from identity is
    /// untouched (scalar 1.0/1.0).
    func testCritterStageIsUnscaled() {
        let crouch = BodyPoseTable.targetTuple(for: "crouch")
        let scaled = BodyPoseController.applyStageScalars(crouch, stage: .critter)
        XCTAssertEqual(scaled.yScale, crouch.yScale)
        XCTAssertEqual(scaled.xScale, crouch.xScale)
        XCTAssertEqual(scaled.yOffset, crouch.yOffset)
    }

    /// §3: `stand`'s already-neutral tuple must stay untouched at every
    /// stage, at every scalar — scaling the deviation from identity (zero)
    /// always yields identity back.
    func testStandIsUntouchedAtEveryStage() {
        let stand = BodyPoseTable.targetTuple(for: "stand")
        for stage in GrowthStage.allCases {
            let scaled = BodyPoseController.applyStageScalars(stand, stage: stage)
            XCTAssertEqual(scaled.yScale, 1.0, "stage \(stage)")
            XCTAssertEqual(scaled.xScale, 1.0, "stage \(stage)")
            XCTAssertEqual(scaled.yOffset, 0.0, "stage \(stage)")
            XCTAssertEqual(scaled.zRotation, 0.0, "stage \(stage)")
            XCTAssertEqual(scaled.headOffset, 0.0, "stage \(stage)")
        }
    }

    /// §3: Drop halves deformation ("or it reads as goo").
    func testDropStageHalvesScaleDeviation() {
        let crouch = BodyPoseTable.targetTuple(for: "crouch")
        let scaled = BodyPoseController.applyStageScalars(crouch, stage: .drop)
        // yScale deviation from 1.0 is -0.28 at Critter scale; Drop's 0.5
        // scalar halves that deviation to -0.14 -> 0.86.
        XCTAssertEqual(scaled.yScale, 1.0 + (crouch.yScale - 1.0) * 0.5, accuracy: 0.0001)
        XCTAssertEqual(scaled.yOffset, crouch.yOffset * 0.6, accuracy: 0.0001)
    }

    /// §3: Egg hard-gates zRotation to 0 regardless of table value — it's
    /// already claimed by egg-wobble.
    func testEggStageGatesZRotationToZeroRegardlessOfTupleValue() {
        let rollSide = BodyPoseTable.targetTuple(for: "roll_side")  // zRotation 1.40
        let scaled = BodyPoseController.applyStageScalars(rollSide, stage: .egg)
        XCTAssertEqual(scaled.zRotation, 0.0)
    }
}

final class BodyPoseComposeTests: XCTestCase {

    /// At rest (no breath deviation, no pose deviation, no velocity), the
    /// compose formula must be the exact identity — no drift.
    func testRestComposesToExactIdentity() {
        let (yScale, xScale) = CreatureNode.composedBodyScale(
            breathScale: 1.0, dropHopSquash: 1.0,
            poseYScale: 1.0, poseXScale: 1.0, velocityY: 0
        )
        XCTAssertEqual(yScale, 1.0)
        XCTAssertEqual(xScale, 1.0)
    }

    /// §5: pose composes multiplicatively with breath — a squashed pose
    /// (yScale 0.72, matching `crouch`) rides on top of a breath peak, not
    /// replacing it.
    func testPoseComposesMultiplicativelyWithBreath() {
        let (yScale, _) = CreatureNode.composedBodyScale(
            breathScale: 1.03, dropHopSquash: 1.0,
            poseYScale: 0.72, poseXScale: 1.12, velocityY: 0
        )
        XCTAssertEqual(yScale, 1.03 * 0.72, accuracy: 0.0001)
    }

    /// §5: velocity stretch is a bounded multiplier, clamped to +/-0.15,
    /// composed on top of breath/pose before the final silhouette clamp.
    func testVelocityStretchIsClampedBeforeApplying() {
        // 1000 pts/s * 0.003 = 3.0, clamps to 0.15 -> stretch factor 1.15.
        let (yScale, _) = CreatureNode.composedBodyScale(
            breathScale: 1.0, dropHopSquash: 1.0,
            poseYScale: 1.0, poseXScale: 1.0, velocityY: 1000
        )
        // rawYScale = 1.0 * 1.15 = 1.15, well inside the 0.6-1.3 silhouette clamp.
        XCTAssertEqual(yScale, 1.15, accuracy: 0.0001)
    }

    /// §5/§6: the final silhouette clamp [0.6, 1.3] holds even when
    /// breath/pose/velocity would compose to something far outside it —
    /// this is the hard grounds[1] rule, never bypassable.
    func testFinalYScaleIsHardClampedTo0_6And1_3() {
        let (highYScale, _) = CreatureNode.composedBodyScale(
            breathScale: 1.03, dropHopSquash: 1.0,
            poseYScale: 1.22, poseXScale: 0.82, velocityY: 1000  // stretch (a huge jump) stacked on `stretch` pose
        )
        XCTAssertLessThanOrEqual(highYScale, 1.3)

        let (lowYScale, _) = CreatureNode.composedBodyScale(
            breathScale: 0.97, dropHopSquash: 1.0,
            poseYScale: 0.60, poseXScale: 1.15, velocityY: -1000  // curl pose during a hard fall
        )
        XCTAssertGreaterThanOrEqual(lowYScale, 0.6)
    }

    /// §5: xScale is the volume-preserving reciprocal of the *final*
    /// (already-clamped) yScale, multiplied by the pose's own xScale — but
    /// the [0.6, 1.3] silhouette cap must apply to that FULL product, not
    /// just the reciprocal-sqrt term alone (§5's ratified hard cap wins
    /// over a literal reading of §6's pseudocode, which clamped the
    /// reciprocal before multiplying — that let poses with xScale > 1
    /// escape the cap).
    func testXScaleIsReciprocalOfFinalYScaleTimesPoseXScaleClampedAsAWhole() {
        let (yScale, xScale) = CreatureNode.composedBodyScale(
            breathScale: 1.0, dropHopSquash: 1.0,
            poseYScale: 0.72, poseXScale: 1.12, velocityY: 0
        )
        let expectedXScale = min(max((1.0 / sqrt(yScale)) * 1.12, 0.6), 1.3)
        XCTAssertEqual(xScale, expectedXScale, accuracy: 0.0001)
    }

    /// Deploy-blocker regression: `roll_side` (yScale 0.65, xScale 1.30)
    /// previously composed to xScale ~1.61 — 24% over the hard silhouette
    /// cap — because the cap was applied to the reciprocal-sqrt term
    /// alone, before multiplying in pose.xScale. Any pose with xScale > 1
    /// must never push the composed xScale past 1.3.
    func testRollSideComposesWithXScaleCappedAt1_3() {
        let (_, xScale) = CreatureNode.composedBodyScale(
            breathScale: 1.0, dropHopSquash: 1.0,
            poseYScale: 0.65, poseXScale: 1.30, velocityY: 0
        )
        XCTAssertLessThanOrEqual(xScale, 1.3)
        XCTAssertEqual(xScale, 1.3, accuracy: 0.0001,
                        "roll_side's uncapped product (~1.61) should saturate the cap exactly")
    }

    /// General property: no pose with xScale > 1, at any yScale within the
    /// static-posture range this table actually authors, may ever compose
    /// past the hard cap.
    func testNoStaticPostureWithXScaleAboveOneEverExceedsTheSilhouetteCap() {
        for (name, tuple) in [
            ("crouch", BodyPoseTable.targetTuple(for: "crouch")),
            ("loaf", BodyPoseTable.targetTuple(for: "loaf")),
            ("curl", BodyPoseTable.targetTuple(for: "curl")),
            ("roll_side", BodyPoseTable.targetTuple(for: "roll_side")),
            ("land", BodyPoseTable.targetTuple(for: "land")),
        ] where tuple.xScale > 1.0 {
            let (_, xScale) = CreatureNode.composedBodyScale(
                breathScale: 1.0, dropHopSquash: 1.0,
                poseYScale: tuple.yScale, poseXScale: tuple.xScale, velocityY: 0
            )
            XCTAssertLessThanOrEqual(xScale, 1.3, "\(name) exceeded the silhouette cap")
        }
    }
}

final class BodyPoseControllerBehaviorTests: XCTestCase {

    /// §1: on a genuinely new target, the controller eases rather than
    /// snapping — immediately after `setState`, the pose should not yet
    /// equal the target (the ease has barely started).
    func testSetStateEasesRatherThanSnapping() {
        let controller = BodyPoseController(stage: .critter)
        controller.setState("crouch", duration: 0, isReflexPriority: false)
        controller.update(deltaTime: 0.016)  // one frame in, ease is 0.3s total

        XCTAssertNotEqual(controller.currentPose.yScale,
                           BodyPoseTable.targetTuple(for: "crouch").yScale,
                           "one frame into a 0.3s ease should not have reached the target yet")
    }

    /// §1: given enough elapsed time, the ease completes and the pose
    /// settles exactly on the (stage-scaled) target.
    func testSetStateReachesTargetAfterEaseDuration() {
        let controller = BodyPoseController(stage: .critter)
        controller.setState("crouch", duration: 0, isReflexPriority: false)
        for _ in 0..<30 { controller.update(deltaTime: 0.016) }  // ~0.48s > 0.3s ease

        let target = BodyPoseController.applyStageScalars(
            BodyPoseTable.targetTuple(for: "crouch"), stage: .critter
        )
        XCTAssertEqual(controller.currentPose.yScale, target.yScale, accuracy: 0.001)
    }

    /// §1: a reflex-priority arrival (e.g. `ReflexLayer.startle`'s "jump")
    /// must use the faster 0.15s cascade timing, not the default 0.3s —
    /// so it should be measurably further along after one identical frame.
    func testReflexPriorityEasesFasterThanDefault() {
        let normal = BodyPoseController(stage: .critter)
        normal.setState("crouch", duration: 0, isReflexPriority: false)
        normal.update(deltaTime: 0.1)

        let reflex = BodyPoseController(stage: .critter)
        reflex.setState("crouch", duration: 0, isReflexPriority: true)
        reflex.update(deltaTime: 0.1)

        let target = BodyPoseTable.targetTuple(for: "crouch").yScale
        let normalDistance = abs(normal.currentPose.yScale - target)
        let reflexDistance = abs(reflex.currentPose.yScale - target)
        XCTAssertLessThan(reflexDistance, normalDistance,
                           "0.15s reflex timing should be closer to target than 0.3s default after the same elapsed time")
    }

    /// Calling `setState` again with the SAME resolved string (the common
    /// per-frame case from `applyBehaviorOutput`) must be a no-op — it must
    /// not restart the ease or reset a continuous dynamic state's phase.
    func testRepeatedSetStateWithSameStringDoesNotResetProgress() {
        let controller = BodyPoseController(stage: .critter)
        controller.setState("bounce", duration: 0, isReflexPriority: false)
        controller.update(deltaTime: 0.5)
        let midYScale = controller.currentPose.yScale

        // applyBehaviorOutput calls setState every frame regardless of
        // whether the string changed.
        controller.setState("bounce", duration: 0, isReflexPriority: false)
        controller.update(deltaTime: 0.001)

        XCTAssertNotEqual(controller.currentPose.yScale, midYScale,
                           "the oscillation must keep advancing, not freeze/reset on a same-string re-entry")
    }

    /// §2's continuous dynamic states must actually oscillate over time
    /// (not hold at a fixed value like the static/quasi-static states do).
    func testBounceOscillatesOverTime() {
        let controller = BodyPoseController(stage: .critter)
        controller.setState("bounce", duration: 0, isReflexPriority: false)

        var samples: Set<Int> = []
        var t: TimeInterval = 0
        while t < 1.0 {
            controller.update(deltaTime: 0.02)
            t += 0.02
            samples.insert(Int((controller.currentPose.yScale * 1000).rounded()))
        }
        XCTAssertGreaterThan(samples.count, 1, "bounce should visibly oscillate yScale over one second")
    }
}
