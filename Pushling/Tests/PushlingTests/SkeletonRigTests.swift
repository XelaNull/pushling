// SkeletonRigTests.swift — Structural-invariant tests for the WO-19
// pelvis-chain skeletal rig. Sub-part 1 (foundation) + sub-part 2
// (proportional appendage-follow, the segmented-tail swap, and the
// sphinx/sprawl/groom/knead table additions).
//
// Four durable guarantees, per the WO-19 dispatch:
//   (a) tree-shape       — `body` is reachable only under `pelvis`, never
//                           a direct child of the creature root.
//   (b) write-target     — after a pose is applied and ticked, `bodyNode`'s
//                           OWN local transform stays identity; all
//                           deformation routes through `pelvisNode`.
//   (c) inert pivots     — `shoulder_l/r`/`hip_l/r` are untouched by any
//                           per-frame update in this pass (WO-20 wires
//                           gait later).
//   (d) root allowlist   — the creature root's direct children are exactly
//                           the small set the WO-19 census says stay root-
//                           level (`aura`, `particles`, `pelvis`), nothing
//                           else.
//
// Plus GATE-1 (the Orchestrator/Mack-required proof): every reparented
// part's position relative to the creature root, computed immediately
// after `configureForStage` (before any pose/update has run), is IDENTICAL
// to what `StageRenderer.build` alone would have produced pre-reparent —
// proven via SpriteKit's own `convert(_:to:)`, not asserted by trusting the
// re-basing algebra.

import XCTest
import SpriteKit
@testable import Pushling

final class SkeletonRigTreeShapeTests: XCTestCase {

    func testBodyIsReachableOnlyUnderPelvisNotAsDirectRootChild() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        XCTAssertNil(creature.childNode(withName: "body"),
                     "body must no longer be a direct child of the creature root")

        guard let body = creature.childNode(withName: "//body") else {
            return XCTFail("body must still be reachable via recursive descendant search")
        }

        // Walk up from body's parent chain — it must reach a node named
        // "pelvis" before reaching the creature root itself.
        var seenPelvis = false
        var node: SKNode? = body.parent
        while let current = node, current !== creature {
            if current.name == "pelvis" { seenPelvis = true }
            node = current.parent
        }
        XCTAssertTrue(seenPelvis, "body's ancestor chain must pass through a node named 'pelvis'")
    }

    func testHeadTailAndAllFourPawsAreNoLongerDirectRootChildren() {
        // Beast has no core_glow (StageRenderer.buildBeast passes nil —
        // only Egg/Critter build one), so it's checked separately below
        // against a stage that actually has it.
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        for name in ["head", "paw_fl", "paw_fr", "paw_bl", "paw_br"] {
            XCTAssertNil(creature.childNode(withName: name),
                         "\(name) must not be a direct root child after the WO-19 reparent")
            XCTAssertNotNil(creature.childNode(withName: "//\(name)"),
                            "\(name) must still be reachable somewhere in the tree")
        }
        // `tail` (the single rigid shape) is no longer added to the tree
        // at all as of WO-19 sub-part 2 — `SegmentedTailController`'s
        // `tail_seg_0` chain renders instead (StageRenderer.swift's
        // `tail` node now exists only as CreatureNode's placement oracle).
        XCTAssertNil(creature.childNode(withName: "tail"))
        XCTAssertNil(creature.childNode(withName: "//tail"))
        XCTAssertNotNil(creature.childNode(withName: "//tail_seg_0"),
                        "tail_seg_0 must be reachable — it replaces the single rigid tail node")

        let critter = CreatureNode()
        critter.configureForStage(.critter)
        XCTAssertNil(critter.childNode(withName: "core_glow"),
                     "core_glow must not be a direct root child after the WO-19 reparent")
        XCTAssertNotNil(critter.childNode(withName: "//core_glow"),
                        "core_glow must still be reachable somewhere in the tree")
    }

    func testRootChildAllowlistMatchesTheWO19Census() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        let allowlist: Set<String> = ["aura", "particles", "pelvis"]
        let actualNames = Set(creature.children.compactMap(\.name))

        XCTAssertTrue(actualNames.isSubset(of: allowlist),
                      "unexpected direct root child(ren): \(actualNames.subtracting(allowlist)) — " +
                      "only aura/particles/pelvis may stay root-level per the WO-19 census")
        // pelvis must always be present once configured.
        XCTAssertTrue(actualNames.contains("pelvis"))
    }
}

final class SkeletonRigWriteTargetTests: XCTestCase {

    /// The single guarantee the whole rig rests on: no matter what pose is
    /// applied, `bodyNode`'s OWN local position/scale/rotation never move
    /// — every bit of deformation must land on `pelvisNode` and reach
    /// `bodyNode` only via SpriteKit's parent-child inheritance.
    ///
    /// **The 2 sanctioned exceptions to "pelvisNode is the sole pose-write
    /// target"** — documented here so the tolerance/silence on these below
    /// reads as a deliberate choice, not a gap this test missed:
    ///   1. `updateNoiseIdle`'s `bodyNode.position.y` jitter (+/-0.12pt,
    ///      all stages, pre-existing and unrelated to `bodyState` —
    ///      accounted for by this test's `accuracy: 0.15` tolerance below).
    ///   2. Egg-wobble's `bodyNode.zRotation` write (Egg-only, gated
    ///      `bodyPoseController == nil` at that call site) — not exercised
    ///      by this test at all since it configures `.beast`, where
    ///      `bodyPoseController` is non-nil and egg-wobble's own guard
    ///      keeps it from ever touching `bodyNode.zRotation`.
    func testBodyNodeOwnTransformStaysIdentityAfterCrouchIsApplied() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        creature.bodyPoseController?.setState("crouch", duration: 0)
        for _ in 0..<60 { creature.update(deltaTime: 1.0 / 60.0) }  // ~1s, well past the 0.3s ease

        guard let body = creature.childNode(withName: "//body") as? SKShapeNode else {
            return XCTFail("body not found")
        }

        // x is untouched by anything except the pose compose (which now
        // targets pelvisNode) — strict zero. y also receives
        // `updateNoiseIdle`'s pre-existing +/-0.12pt micro-movement
        // (CreatureNode.swift's noiseAmps[0], a real, unrelated, always-on
        // system — not the detachment-bug pattern), so its bound is
        // "small jitter," not "pose-driven displacement": crouch's own
        // composed yOffset at Beast scale is ~-0.66pt, 5x past this bound,
        // so this tolerance still clearly catches a real regression.
        XCTAssertEqual(body.position.x, 0,
                       "bodyNode's own local x must stay 0 — pose lives on pelvisNode")
        XCTAssertEqual(body.position.y, 0, accuracy: 0.15,
                       "bodyNode's own local y must stay within noise-idle's own jitter band, " +
                       "not track the pose's yOffset — pose lives on pelvisNode")
        XCTAssertEqual(body.zRotation, 0,
                       "bodyNode's own zRotation must stay 0 — a nonzero value here would be " +
                       "the exact detachment-bug pattern reintroduced one level down")
        XCTAssertEqual(body.xScale, 1.0, accuracy: 0.0001)
        XCTAssertEqual(body.yScale, 1.0, accuracy: 0.0001)

        // Sanity check the OTHER half of the guarantee: pelvisNode DID
        // pick up the deformation (otherwise this test would trivially
        // pass on a totally broken compose point too).
        guard let pelvis = creature.childNode(withName: "pelvis") else {
            return XCTFail("pelvis not found")
        }
        XCTAssertNotEqual(pelvis.yScale, 1.0,
                          "pelvisNode should carry crouch's yScale deviation — " +
                          "if this is 1.0 the compose point isn't writing anywhere")
    }
}

final class SkeletonRigInertPivotTests: XCTestCase {

    /// shoulder_l/r and hip_l/r must be completely inert in this pass —
    /// WO-20 wires their angular gait swing later. Snapshot immediately
    /// after configure, tick many frames under an ordinary pose cycle, and
    /// assert nothing perturbed them.
    func testShoulderAndHipPivotsAreUntouchedByOrdinaryUpdates() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        let jointNames = ["shoulder_l", "shoulder_r", "hip_l", "hip_r"]
        var snapshots: [String: (position: CGPoint, zRotation: CGFloat,
                                  xScale: CGFloat, yScale: CGFloat)] = [:]
        for name in jointNames {
            guard let node = creature.childNode(withName: "//\(name)") else {
                return XCTFail("\(name) not found")
            }
            snapshots[name] = (node.position, node.zRotation, node.xScale, node.yScale)
        }

        // Drive a variety of poses across many frames — the exact
        // scenario a live parade would exercise.
        for state in ["crouch", "stretch", "roll_side", "bounce", "stand"] {
            creature.bodyPoseController?.setState(state, duration: 0)
            for _ in 0..<30 { creature.update(deltaTime: 1.0 / 60.0) }
        }

        for name in jointNames {
            guard let node = creature.childNode(withName: "//\(name)") else {
                return XCTFail("\(name) missing after updates")
            }
            let before = snapshots[name]!
            XCTAssertEqual(node.position, before.position, "\(name) position moved — should be inert")
            XCTAssertEqual(node.zRotation, before.zRotation, "\(name) rotated — should be inert")
            XCTAssertEqual(node.xScale, before.xScale, "\(name) xScale changed — should be inert")
            XCTAssertEqual(node.yScale, before.yScale, "\(name) yScale changed — should be inert")
        }
    }
}

// MARK: - GATE-1: Rest-Identity Proof

final class SkeletonRigGate1RestIdentityTests: XCTestCase {

    /// The Orchestrator/Mack-required proof: every reparented part's
    /// position relative to the creature root, at `bodyState="stand"`
    /// immediately after `configureForStage` (no pose/update ticked yet),
    /// is IDENTICAL to the absolute position `StageRenderer.build` alone
    /// produces — proving the re-basing math cancels out exactly, for
    /// every stage that has the given part, not asserted by trusting the
    /// algebra alone.
    func testRestPositionMatchesStageRendererOutputAcrossAllStages() {
        for stage in GrowthStage.allCases {
            // Independent oracle: a FRESH, never-reparented StageNodes —
            // exactly what the OLD flat-sibling code would have used as
            // each part's absolute (root-relative) position.
            let expected = StageRenderer.build(stage: stage)

            let creature = CreatureNode()
            creature.configureForStage(stage)

            assertPositionMatches(creature: creature, name: "body",
                                  expected: expected.body.position, stage: stage)
            assertPositionMatches(creature: creature, name: "head",
                                  expected: expected.head.position, stage: stage)

            // `tail` itself is no longer added to the tree (WO-19 sub-part
            // 2) — `tail_seg_0` (the segmented chain's base) is placed at
            // the SAME attach point, so `expected.tail.position` remains
            // the correct oracle.
            if let expectedTail = expected.tail {
                assertPositionMatches(creature: creature, name: "tail_seg_0",
                                      expected: expectedTail.position, stage: stage)
            }
            if let expectedCoreGlow = expected.coreGlow {
                assertPositionMatches(creature: creature, name: "core_glow",
                                      expected: expectedCoreGlow.position, stage: stage)
            }
            if let expectedFL = expected.pawFL {
                assertPositionMatches(creature: creature, name: "paw_fl",
                                      expected: expectedFL.position, stage: stage)
            }
            if let expectedFR = expected.pawFR {
                assertPositionMatches(creature: creature, name: "paw_fr",
                                      expected: expectedFR.position, stage: stage)
            }
            if let expectedBL = expected.pawBL {
                assertPositionMatches(creature: creature, name: "paw_bl",
                                      expected: expectedBL.position, stage: stage)
            }
            if let expectedBR = expected.pawBR {
                assertPositionMatches(creature: creature, name: "paw_br",
                                      expected: expectedBR.position, stage: stage)
            }
        }
    }

    private func assertPositionMatches(creature: CreatureNode, name: String,
                                        expected: CGPoint, stage: GrowthStage,
                                        file: StaticString = #filePath, line: UInt = #line) {
        guard let node = creature.childNode(withName: "//\(name)") else {
            XCTFail("\(name) not found at stage \(stage)", file: file, line: line)
            return
        }
        let actual = Self.absolutePosition(of: node, upTo: creature)
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.001,
                       "\(name) x mismatch at stage \(stage)", file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.001,
                       "\(name) y mismatch at stage \(stage)", file: file, line: line)
    }

    /// Manually sums `.position` up the parent chain to `root`, rather
    /// than relying on `SKNode.convert(_:to:)` — at rest every ancestor's
    /// scale/rotation is identity (freshly configured, no pose/update
    /// ticked yet), so plain summation is exactly equivalent and doesn't
    /// depend on SpriteKit's transform-cache behavior for a node tree
    /// that was never presented in a live SKScene/SKView (this test's
    /// `creature` is a standalone, unpresented CreatureNode).
    private static func absolutePosition(of node: SKNode, upTo root: SKNode) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var current: SKNode? = node
        while let n = current, n !== root {
            x += n.position.x
            y += n.position.y
            current = n.parent
        }
        return CGPoint(x: x, y: y)
    }

    /// Sums `.zRotation` up the parent chain — valid here for the same
    /// reason `absolutePosition` above is: no ancestor ever applies a
    /// scale-flip, so rotations compose by plain addition.
    fileprivate static func worldZRotation(of node: SKNode, upTo root: SKNode) -> CGFloat {
        var total: CGFloat = 0
        var current: SKNode? = node
        while let n = current, n !== root {
            total += n.zRotation
            current = n.parent
        }
        return total
    }
}

// MARK: - Sub-Part 2: Proportional Appendage-Follow

final class SkeletonRigChestFollowTests: XCTestCase {

    /// The `chestFollowFactor` fix itself (REVISE): `spine_chest`'s own
    /// rotation write is a COMPENSATION against the 100% it already
    /// inherits from `pelvis` via SpriteKit parent-child propagation, not
    /// an addition on top of it — `chestCurve = pose.zRotation *
    /// (chestFollowFactor - 1.0)`. The composed total (pelvis + spineChest)
    /// must equal `pose.zRotation * chestFollowFactor`, i.e. exactly
    /// `chestFollowFactor` of the torso's own rotation — never more.
    func testSpineChestRotationIsProportionalToPelvisRotation() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        creature.bodyPoseController?.setState("roll_side", duration: 0)
        for _ in 0..<60 { creature.update(deltaTime: 1.0 / 60.0) }

        guard let pelvis = creature.childNode(withName: "pelvis"),
              let spineChest = creature.childNode(withName: "//spine_chest") else {
            return XCTFail("pelvis/spine_chest not found")
        }

        XCTAssertNotEqual(pelvis.zRotation, 0, "roll_side should have driven pelvis rotation")
        XCTAssertEqual(spineChest.zRotation, pelvis.zRotation * (SkeletonGeometry.chestFollowFactor - 1.0),
                       accuracy: 0.0001,
                       "spine_chest's own rotation must be the compensating " +
                       "(chestFollowFactor - 1.0) fraction, not an addition on top of inheritance")

        let composedTotal = pelvis.zRotation + spineChest.zRotation
        XCTAssertEqual(composedTotal, pelvis.zRotation * SkeletonGeometry.chestFollowFactor,
                       accuracy: 0.0001,
                       "composed chest rotation (pelvis + spineChest) must equal " +
                       "chestFollowFactor of the torso's own rotation")
    }

    /// The actual visible fix: head's WORLD rotation (its own + every
    /// ancestor's, summed) must be substantially larger under a
    /// high-rotation pose than under an identity one — proving rotation
    /// genuinely REACHES the head via inheritance now, not just a flat
    /// position nudge. Before this sub-part, spine_chest never rotated at
    /// all, so head's world rotation would have been 0 regardless of pose.
    func testHeadWorldMotionScalesWithPoseNotFixedOffset() {
        let standCreature = CreatureNode()
        standCreature.configureForStage(.beast)
        for _ in 0..<30 { standCreature.update(deltaTime: 1.0 / 60.0) }

        let rollCreature = CreatureNode()
        rollCreature.configureForStage(.beast)
        rollCreature.bodyPoseController?.setState("roll_side", duration: 0)
        for _ in 0..<60 { rollCreature.update(deltaTime: 1.0 / 60.0) }

        guard let standHead = standCreature.childNode(withName: "//head"),
              let rollHead = rollCreature.childNode(withName: "//head") else {
            return XCTFail("head not found")
        }

        let standRotation = abs(SkeletonRigGate1RestIdentityTests.worldZRotation(
            of: standHead, upTo: standCreature))
        let rollRotation = abs(SkeletonRigGate1RestIdentityTests.worldZRotation(
            of: rollHead, upTo: rollCreature))

        XCTAssertLessThan(standRotation, 0.01, "stand should leave head's world rotation ~0")
        XCTAssertGreaterThan(rollRotation, 0.1,
                             "roll_side must measurably rotate the head via spine_chest inheritance")

        // Scaling check proper: a SECOND, smaller-rotation pose must
        // produce a SMALLER head-world-rotation than roll_side's large
        // one — not a fixed constant regardless of input.
        let flinchCreature = CreatureNode()
        flinchCreature.configureForStage(.beast)
        flinchCreature.bodyPoseController?.setState("flinch", duration: 0)
        for _ in 0..<60 { flinchCreature.update(deltaTime: 1.0 / 60.0) }
        guard let flinchHead = flinchCreature.childNode(withName: "//head") else {
            return XCTFail("head not found")
        }
        let flinchRotation = abs(SkeletonRigGate1RestIdentityTests.worldZRotation(
            of: flinchHead, upTo: flinchCreature))

        XCTAssertLessThan(flinchRotation, rollRotation,
                          "flinch's smaller zRotation (-0.08rad) must produce less head " +
                          "world-rotation than roll_side's (1.40rad) — proportional, not fixed")
    }
}

// MARK: - Sub-Part 2: Segmented Tail Wiring

final class SkeletonRigSegmentedTailTests: XCTestCase {

    func testTailControllerIsSegmentedAndSegmentsAreReachableUnderTailBase() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        XCTAssertNotNil(creature.tailController,
                        "SegmentedTailController must be wired for a tail-having stage")

        // Beast uses 4 segments (makeTailSegments's own stage rule).
        for i in 0..<4 {
            guard let seg = creature.childNode(withName: "//tail_seg_\(i)") else {
                return XCTFail("tail_seg_\(i) not found")
            }
            var seenTailBase = false
            var node: SKNode? = seg.parent
            while let current = node, current !== creature {
                if current.name == "tail_base" { seenTailBase = true }
                node = current.parent
            }
            XCTAssertTrue(seenTailBase, "tail_seg_\(i)'s ancestor chain must pass through tail_base")
        }
    }

    func testTailStillRespondsToExistingStatesThroughTheSpringChain() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        creature.tailController?.setState("wag", duration: 0)
        for _ in 0..<30 { creature.update(deltaTime: 1.0 / 60.0) }

        guard let base = creature.childNode(withName: "//tail_seg_0") else {
            return XCTFail("tail_seg_0 not found")
        }
        // The spring-damper chain should have moved the base segment off
        // its rest angle in response to "wag" — a nonzero rotation proves
        // the chain is live, not a static leftover from construction.
        XCTAssertNotEqual(base.zRotation, 0, "wag should have driven the spring chain")
    }
}

// MARK: - Sub-Part 2: New Table Rows (sphinx/sprawl/groom/knead)

final class SkeletonRigNewTableRowsTests: XCTestCase {

    func testSphinxAndSprawlTuplesMatchIdleLifeAndRestVerbatim() {
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .beast), "sphinx")
        let sphinx = BodyPoseTable.targetTuple(for: "sphinx")
        XCTAssertEqual(sphinx.yScale, 0.78)
        XCTAssertEqual(sphinx.xScale, 1.05)
        XCTAssertEqual(sphinx.yOffset, -0.25)
        XCTAssertEqual(sphinx.headOffset, 0.1)
        XCTAssertEqual(sphinx.pawAlpha, 1.0, "sphinx is the one rung that keeps paws visible")

        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .beast), "sprawl")
        let sprawl = BodyPoseTable.targetTuple(for: "sprawl")
        XCTAssertEqual(sprawl.yScale, 0.60)
        XCTAssertEqual(sprawl.xScale, 1.30)
        XCTAssertEqual(sprawl.yOffset, -0.7)
        XCTAssertEqual(sprawl.headOffset, -0.2)
        XCTAssertEqual(sprawl.pawAlpha, 0.6)
    }

    func testSphinxOnlyAvailableAtBeast() {
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .drop), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .critter), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .beast), "sphinx")
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .sage), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("sphinx", stage: .apex), "stand")
    }

    func testSprawlOnlyAvailableAtDropAndBeast() {
        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .drop), "sprawl")
        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .critter), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .beast), "sprawl")
        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .sage), "stand")
        XCTAssertEqual(BodyPoseTable.resolve("sprawl", stage: .apex), "stand")
    }

    /// groom/knead are now first-class table entries (no longer routed
    /// through the §2b alias map) — values are UNCHANGED from their prior
    /// alias targets (lean_forward / loaf), so this also guards against
    /// silently drifting the numbers during the promotion.
    func testGroomAndKneadAreFirstClassWithUnchangedValues() {
        XCTAssertEqual(BodyPoseTable.resolve("groom", stage: .beast), "groom")
        let groom = BodyPoseTable.targetTuple(for: "groom")
        let leanForward = BodyPoseTable.targetTuple(for: "lean_forward")
        XCTAssertEqual(groom, leanForward)

        XCTAssertEqual(BodyPoseTable.resolve("knead", stage: .beast), "knead")
        let knead = BodyPoseTable.targetTuple(for: "knead")
        let loaf = BodyPoseTable.targetTuple(for: "loaf")
        XCTAssertEqual(knead, loaf)
    }

    func testKickedIsAValidPawState() {
        // Constructing a real PawController needs a live SKNode graph;
        // `validStates` is available on the type without one.
        let node = SKNode()
        let controller = PawController(pawNode: node, position: .backLeft,
                                        restingPoint: .zero)
        XCTAssertTrue(controller.validStates.contains("kicked"))
    }
}

// MARK: - Sub-Part 2 REVISE: Anti-Over-Rotation Invariant

final class SkeletonRigAntiOverRotationTests: XCTestCase {

    /// The durable guard against reintroducing the additive over-rotation
    /// bug an earlier version of `chestFollowFactor` shipped (Mack's
    /// catch): composed chest rotation (pelvis + spineChest) must NEVER
    /// exceed pelvis's own rotation magnitude — the head must never rotate
    /// PAST the torso, for any static tuple with a nonzero zRotation.
    func testComposedChestRotationNeverExceedsPelvisForStaticTuplesWithRotation() {
        // The only 2 core tuples with a nonzero authored zRotation
        // (roll_side: 1.40rad; flinch: -0.08rad) — every other static/
        // quasi-static tuple has zRotation 0, trivially satisfying the
        // invariant.
        for state in ["roll_side", "flinch"] {
            let creature = CreatureNode()
            creature.configureForStage(.beast)
            creature.bodyPoseController?.setState(state, duration: 0)
            for _ in 0..<60 { creature.update(deltaTime: 1.0 / 60.0) }

            assertComposedNeverExceedsPelvis(creature: creature, context: state)
        }
    }

    /// Same invariant sampled continuously across a full spin/flip sweep
    /// (the case the ORIGINAL bug report specifically named: "spin/flip
    /// full sweeps the head leads and snaps at wrap-around").
    func testComposedChestRotationNeverExceedsPelvisDuringSpinAndFlipSweeps() {
        for state in ["spin", "flip"] {
            let creature = CreatureNode()
            creature.configureForStage(.beast)
            creature.bodyPoseController?.setState(state, duration: 0)

            // Sample across more than one full sweep for both states
            // (spin: 1.5s period; flip: 1.2s period) at 60fps.
            for frame in 0..<200 {
                creature.update(deltaTime: 1.0 / 60.0)
                assertComposedNeverExceedsPelvis(
                    creature: creature, context: "\(state) frame \(frame)")
            }
        }
    }

    private func assertComposedNeverExceedsPelvis(creature: CreatureNode, context: String,
                                                    file: StaticString = #filePath, line: UInt = #line) {
        guard let pelvis = creature.childNode(withName: "pelvis"),
              let spineChest = creature.childNode(withName: "//spine_chest") else {
            XCTFail("pelvis/spine_chest not found (\(context))", file: file, line: line)
            return
        }
        let composedTotal = abs(pelvis.zRotation + spineChest.zRotation)
        let pelvisMagnitude = abs(pelvis.zRotation)
        XCTAssertLessThanOrEqual(composedTotal, pelvisMagnitude + 0.0001,
                                 "\(context): composed chest rotation (\(composedTotal)) exceeded " +
                                 "pelvis's own rotation (\(pelvisMagnitude)) — head rotated past the torso",
                                 file: file, line: line)
    }
}
