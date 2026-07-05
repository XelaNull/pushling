// SpriteBodySwapTests.swift — Structural-invariant tests for WO-27
// sub-part 2 (the sprite render swap) + its REVISE round. Five
// guarantees, per the dispatch(es):
//   (a) flag-off        — the vector path is byte-identical to before
//                          this pass (SKShapeNode body, paws/ears/
//                          head_shape all present and unhidden).
//   (b) flag-on/eligible — `body` becomes an SKSpriteNode in the SAME
//                          tree slot; ears+paws+head_shape retire; tail/
//                          eyes/mouth/whiskers stay as overlays.
//   (c) flag-on/no-data — a stage with no ClipTable frames yet (Critter)
//                          stays on the vector path even with the flag on.
//   (d) walk override    — walkSpeed above threshold selects the Walk
//                          clip regardless of bodyState, and the frame
//                          index actually advances across ticks.
//   (e) fail-closed gate — REVISE fix 3: clip-present-but-anchors-absent
//                          (a case no real stage exercises today) must
//                          still resolve to the vector path, not a
//                          half-sprite/half-vector render.
//
// PUSHLING_SPRITE_BODY is toggled via setenv/unsetenv per test (confirmed
// empirically that ProcessInfo.processInfo.environment reads live, not
// cached, on this platform) — mirrors SpriteBodyModeTests.swift's own
// "off by default" pin, just exercising the ON side here.

import XCTest
import SpriteKit
@testable import Pushling

final class SpriteBodySwapTests: XCTestCase {

    override func tearDown() {
        unsetenv("PUSHLING_SPRITE_BODY")
        super.tearDown()
    }

    // MARK: - (a) Flag off — vector path unchanged

    func testFlagOffLeavesVectorPathUnchangedAtBeast() {
        XCTAssertFalse(SpriteBodyMode.isEnabled, "must be off by default in this test run")

        let creature = CreatureNode()
        creature.configureForStage(.beast)

        guard let body = creature.childNode(withName: "//body") else {
            return XCTFail("body must still be reachable")
        }
        XCTAssertTrue(body is SKShapeNode, "flag off must keep the vector SKShapeNode body")
        XCTAssertFalse(body is SKSpriteNode)

        for name in ["paw_fl", "paw_fr", "paw_bl", "paw_br", "ear_left", "ear_right"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) must still be reachable with the flag off")
                continue
            }
            XCTAssertFalse(node.isHidden, "\(name) must not be hidden with the flag off")
        }

        // REVISE fix 1 regression guard: head_shape (the head's own solid
        // silhouette, a child of `head`) must stay visible on the vector
        // path — only sprite mode hides it.
        guard let headShape = creature.childNode(withName: "//head_shape") else {
            return XCTFail("head_shape must still be reachable with the flag off")
        }
        XCTAssertFalse(headShape.isHidden, "head_shape must not be hidden with the flag off")

        XCTAssertNotNil(creature.pawFLController)
        XCTAssertNotNil(creature.earLeftController)
    }

    // MARK: - (b) Flag on + eligible + has data (Beast) — sprite swap

    func testFlagOnAtBeastSwapsBodyToSpriteAndRetiresEarsAndPaws() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)
        XCTAssertTrue(SpriteBodyMode.isEnabled)

        let creature = CreatureNode()
        creature.configureForStage(.beast)

        guard let body = creature.childNode(withName: "//body") else {
            return XCTFail("body must still be reachable in the same tree slot")
        }
        XCTAssertTrue(body is SKSpriteNode, "flag on + eligible + has data must swap body to a sprite")

        // Retired: paws never even reparented into the tree.
        for name in ["paw_fl", "paw_fr", "paw_bl", "paw_br"] {
            XCTAssertNil(creature.childNode(withName: "//\(name)"),
                        "\(name) must not be reparented into the tree in sprite mode")
        }
        XCTAssertNil(creature.pawFLController)
        XCTAssertNil(creature.pawFRController)
        XCTAssertNil(creature.pawBLController)
        XCTAssertNil(creature.pawBRController)

        // Retired: ears hidden (still nodes, since StageRenderer already
        // parented them under `head` before CreatureNode ever sees them).
        for name in ["ear_left", "ear_right"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) should still exist (hidden), not removed")
                continue
            }
            XCTAssertTrue(node.isHidden, "\(name) must be hidden in sprite mode")
        }
        XCTAssertNil(creature.earLeftController)
        XCTAssertNil(creature.earRightController)

        // REVISE fix 1 (Mack's catch) — head_shape (the head's own solid
        // silhouette) must ALSO be hidden in sprite mode: the baked frame
        // already paints the head, so a visible head_shape underneath the
        // eye/mouth/whisker overlay is a duplicate-head chimera artifact,
        // not an intentional overlay.
        guard let headShape = creature.childNode(withName: "//head_shape") else {
            return XCTFail("head_shape should still exist (hidden), not removed")
        }
        XCTAssertTrue(headShape.isHidden, "head_shape must be hidden in sprite mode")

        // Kept as overlays: tail (L2), eyes/mouth/whiskers (L3).
        XCTAssertNotNil(creature.childNode(withName: "//tail_seg_0"))
        XCTAssertNotNil(creature.tailController)
        XCTAssertNotNil(creature.eyeLeftController)
        XCTAssertNotNil(creature.eyeRightController)
        XCTAssertNotNil(creature.mouthController)
        XCTAssertNotNil(creature.whiskerLeftController)
        XCTAssertNotNil(creature.whiskerRightController)
    }

    /// The L2/L3 hardcoded anchor override (§4) — `head`/`tail_base`
    /// must sit at `ClipTable.overlayAnchors(for: .beast)`'s values, not
    /// the vector-authored position a plain flag-off build would use.
    func testSpriteModeOverridesHeadAndTailAnchorsToTheHardcodedApproximation() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)

        let spriteCreature = CreatureNode()
        spriteCreature.configureForStage(.beast)
        let vectorCreature = CreatureNode()
        unsetenv("PUSHLING_SPRITE_BODY")
        vectorCreature.configureForStage(.beast)

        guard let anchors = ClipTable.overlayAnchors(for: .beast) else {
            return XCTFail("Beast must have overlay anchors defined")
        }
        guard let spriteHead = spriteCreature.childNode(withName: "//head"),
              let spriteTailBase = spriteCreature.childNode(withName: "//tail_base"),
              let vectorHead = vectorCreature.childNode(withName: "//head"),
              let vectorTailBase = vectorCreature.childNode(withName: "//tail_base") else {
            return XCTFail("head/tail_base must exist on both creatures")
        }

        // Sprite mode's absolute (pelvis-relative) position should equal
        // the anchor constant; the vector build's should not (proving
        // this is an actual override, not a coincidence).
        let spriteHeadAbsolute = spriteHead.parent!.convert(spriteHead.position, to: spriteCreature)
        let vectorHeadAbsolute = vectorHead.parent!.convert(vectorHead.position, to: vectorCreature)
        XCTAssertEqual(spriteHeadAbsolute.x, anchors.headOffset.x, accuracy: 0.0001)
        XCTAssertEqual(spriteHeadAbsolute.y, anchors.headOffset.y, accuracy: 0.0001)
        XCTAssertNotEqual(vectorHeadAbsolute.x, anchors.headOffset.x)

        let spriteTailAbsolute = spriteTailBase.parent!.convert(spriteTailBase.position, to: spriteCreature)
        let vectorTailAbsolute = vectorTailBase.parent!.convert(vectorTailBase.position, to: vectorCreature)
        XCTAssertEqual(spriteTailAbsolute.x, anchors.tailOffset.x, accuracy: 0.0001)
        XCTAssertEqual(spriteTailAbsolute.y, anchors.tailOffset.y, accuracy: 0.0001)
        XCTAssertNotEqual(vectorTailAbsolute.x, anchors.tailOffset.x)
    }

    // MARK: - (c) Flag on but no ClipTable data (Critter) — vector fallback

    func testFlagOnAtCritterFallsBackToVectorPathSinceNoFramesExistYet() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)
        XCTAssertTrue(SpriteBodyMode.isEnabled)
        XCTAssertTrue(SpriteBodyMode.isEligible(stage: .critter), "critter IS architecturally eligible")
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .critter), "but has no scaffolding yet")

        let creature = CreatureNode()
        creature.configureForStage(.critter)

        guard let body = creature.childNode(withName: "//body") else {
            return XCTFail("body must still be reachable")
        }
        XCTAssertTrue(body is SKShapeNode, "no ClipTable data for Critter must fall back to the vector path")
        XCTAssertNotNil(creature.pawFLController, "paws must still be built on the vector fallback")
    }

    // MARK: - (d) walkSpeed override + frame advance
    //
    // These test the two extracted pure static helpers directly
    // (`CreatureNode.resolveActiveClip`/`spriteFrameIndex`) rather than
    // asserting on `SKSpriteNode.texture` identity end-to-end — under
    // `swift test`, EVERY texture lookup returns nil (no bundled
    // resources; see SpriteFrameLoader.swift's file header), so a
    // texture-identity assertion would pass or fail for the wrong reason
    // (nil == nil) regardless of whether the actual decision logic is
    // correct. The pure helpers are exactly the decision logic, so
    // testing them directly is the honest way to pin this contract.

    func testResolveActiveClipPrefersWalkOverBodyStateWhenWalkSpeedAboveThreshold() {
        let standClip = ClipTable.clip(for: "stand", stage: .beast)
        let walkClip = ClipTable.clip(for: "walk", stage: .beast)  // unreachable via bodyState alone
        let resolved = CreatureNode.resolveActiveClip(
            bodyState: "stand", stage: .beast, walkSpeed: 10
        )
        XCTAssertNotEqual(resolved?.frames, standClip?.frames,
                          "walking must not resolve to the Idle/stand clip")
        XCTAssertNotEqual(resolved?.frames, walkClip?.frames,
                          "sanity: clip(for:\"walk\") itself is the unreachable Idle fallback, not Walk")
        XCTAssertEqual(resolved?.frames, ClipTable.walkClip(for: .beast)?.frames,
                       "walking must resolve to the direct walkClip(for:) lookup")
    }

    func testResolveActiveClipUsesBodyStateMappingAtOrBelowThreshold() {
        let resolved = CreatureNode.resolveActiveClip(
            bodyState: "stand", stage: .beast, walkSpeed: 0
        )
        XCTAssertEqual(resolved?.frames, ClipTable.clip(for: "stand", stage: .beast)?.frames)
        XCTAssertEqual(resolved?.frames, ["beast_idle_00"])
    }

    func testResolveActiveClipFallsBackToBodyStateWhenStageHasNoWalkClip() {
        // Critter has no ClipTable entry at all (nil throughout) — the
        // walkSpeed branch's own `?? clip(for:stage:)` fallback must not
        // crash or silently produce a stale Beast clip.
        let resolved = CreatureNode.resolveActiveClip(
            bodyState: "stand", stage: .critter, walkSpeed: 10
        )
        XCTAssertNil(resolved)
    }

    func testSpriteFrameIndexAdvancesAndWrapsForLoopingClips() {
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 0, fps: 10, frameCount: 6, loop: true), 0)
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 0.15, fps: 10, frameCount: 6, loop: true), 1)
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 0.35, fps: 10, frameCount: 6, loop: true), 3)
        // 10fps * 0.65s = 6.5 -> index 6, wraps to 0 for a 6-frame clip.
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 0.65, fps: 10, frameCount: 6, loop: true), 0)
    }

    func testSpriteFrameIndexHoldsLastFrameForNonLoopingClips() {
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 0, fps: 8, frameCount: 1, loop: false), 0)
        // Well past the single frame's duration — must clamp, not crash
        // via an out-of-bounds index.
        XCTAssertEqual(CreatureNode.spriteFrameIndex(clipTime: 5.0, fps: 8, frameCount: 1, loop: false), 0)
    }

    /// Lightweight integration check: ticking a sprite-mode creature with
    /// `walkSpeed` set doesn't crash, and the body stays an SKSpriteNode
    /// (the two things actually observable end-to-end under `swift test`,
    /// where texture identity is not — see this section's header comment).
    func testTickingASpriteModeCreatureWithWalkSpeedSetDoesNotCrash() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)

        let creature = CreatureNode()
        creature.configureForStage(.beast)
        creature.bodyPoseController?.setState("stand", duration: 0)
        creature.walkSpeed = 10

        for _ in 0..<30 { creature.update(deltaTime: 1.0 / 60.0) }

        XCTAssertTrue(creature.childNode(withName: "//body") is SKSpriteNode)
    }

    // MARK: - (e) Fail-closed gate (REVISE fix 3)

    /// Beast today: both clip and anchors present -> active.
    func testGateIsActiveWhenFlagOnEligibleClipAndAnchorsAllPresent() {
        XCTAssertTrue(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: true, stageEligible: true, hasClip: true, hasAnchors: true
        ))
    }

    /// The exact case Mack flagged: a stage with rendered frames but no
    /// overlay-anchor approximation authored yet must NOT activate the
    /// sprite path — that would render a sprite body with head/tail still
    /// sitting at stale vector-authored offsets (half-chimera). No real
    /// stage exercises this today (Beast has both, everything else has
    /// neither) — this is exactly why the gate needed a direct unit test
    /// rather than relying on incidental stage-data coverage.
    func testGateFailsClosedWhenClipExistsButAnchorsDoNot() {
        XCTAssertFalse(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: true, stageEligible: true, hasClip: true, hasAnchors: false
        ))
    }

    /// The inverse (anchors authored ahead of frames) must also fail
    /// closed — neither piece of data alone is sufficient.
    func testGateFailsClosedWhenAnchorsExistButClipDoesNot() {
        XCTAssertFalse(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: true, stageEligible: true, hasClip: false, hasAnchors: true
        ))
    }

    func testGateFailsClosedWhenFlagOffOrStageIneligibleRegardlessOfData() {
        XCTAssertFalse(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: false, stageEligible: true, hasClip: true, hasAnchors: true
        ))
        XCTAssertFalse(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: true, stageEligible: false, hasClip: true, hasAnchors: true
        ))
    }

    /// End-to-end confirmation that Beast's REAL data satisfies the gate
    /// today (both `ClipTable.clip`/`overlayAnchors` are non-nil for
    /// Beast) — ties the pure-function unit tests above back to the
    /// actual table contents, not just abstract booleans.
    func testBeastRealDataSatisfiesTheFailClosedGate() {
        XCTAssertTrue(CreatureNode.computeIsSpriteBodyActive(
            flagEnabled: true,
            stageEligible: SpriteBodyMode.isEligible(stage: .beast),
            hasClip: ClipTable.clip(for: "stand", stage: .beast) != nil,
            hasAnchors: ClipTable.overlayAnchors(for: .beast) != nil
        ))
    }

    // MARK: - REVISE fix 2 — MutationVisualsManager's polyglot hue-shift

    /// Flag off (vector path): the existing hue-shift must still work —
    /// regression guard that the FIX 2 refactor (cast-to-SKNode-then-
    /// branch instead of a direct `as? SKShapeNode`) didn't change vector
    /// behavior. Ticking doesn't crash and the body's fillColor visibly
    /// changes from Idle across two different animationTime samples.
    func testPolyglotHueShiftStillAppliesOnTheVectorPath() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)
        let manager = MutationVisualsManager()
        manager.configure(creature: creature, earnedBadges: [.polyglot])

        guard let shapeBody = creature.childNode(withName: "//body") as? SKShapeNode else {
            return XCTFail("body must be an SKShapeNode on the vector path")
        }
        let initialFill = shapeBody.fillColor
        for _ in 0..<30 { manager.update(deltaTime: 1.0 / 60.0) }
        XCTAssertNotEqual(shapeBody.fillColor, initialFill,
                          "the per-frame hue rotation must still visibly change fillColor")
    }

    /// FIX 2 itself: in sprite mode, `body` is an SKSpriteNode — the old
    /// `as? SKShapeNode` cast silently failed and no-opped with zero
    /// signal; the fix casts to the SKNode base first, then branches, and
    /// explicitly skips SKSpriteNode bodies (sprite recolor is L4/WO-28,
    /// not a vector hue rotation). This test's actual bar is "doesn't
    /// crash and doesn't misbehave," which is the whole point — there is
    /// no SKShapeNode.fillColor to assert on for a sprite body.
    func testPolyglotHueShiftSkipsGracefullyInSpriteModeWithoutCrashing() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)

        let creature = CreatureNode()
        creature.configureForStage(.beast)
        let manager = MutationVisualsManager()
        manager.configure(creature: creature, earnedBadges: [.polyglot])

        for _ in 0..<30 { manager.update(deltaTime: 1.0 / 60.0) }

        XCTAssertTrue(creature.childNode(withName: "//body") is SKSpriteNode,
                      "sanity: still in sprite mode after ticking")
    }
}
