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

        // CHIMERA fix regression guard: every OTHER vector face part the
        // sprite-mode fix now hides (eyes, nose, mouth, whiskers) must
        // stay visible on the vector path too — this is purely additive
        // hiding gated on `isSpriteBodyActive`, which is false throughout
        // this whole test.
        for name in ["eye_left", "eye_right", "nose", "mouth", "whisker_left", "whisker_right"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) must still be reachable with the flag off")
                continue
            }
            XCTAssertFalse(node.isHidden, "\(name) must not be hidden with the flag off")
        }
        // Grandchildren too (the eye's own pupil, specifically named in
        // the fix's own regression list) — confirms the fix's grandchild
        // pass is ALSO correctly gated, not an unconditional hide.
        for name in ["eye_left_pupil", "eye_right_pupil"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) must still be reachable with the flag off")
                continue
            }
            XCTAssertFalse(node.isHidden, "\(name) must not be hidden with the flag off")
        }

        // Tail (L2 overlay) — Beast's baked-in-tail gate only applies when
        // `isSpriteBodyActive`, which is false here, so the segmented
        // chain must be built exactly as before.
        XCTAssertNotNil(creature.childNode(withName: "//tail_base"),
                        "tail_base must exist with the flag off")
        XCTAssertNotNil(creature.childNode(withName: "//tail_seg_0"),
                        "tail_seg_0 must exist with the flag off")
        XCTAssertNotNil(creature.tailController, "tailController must be built with the flag off")

        XCTAssertNotNil(creature.pawFLController)
        XCTAssertNotNil(creature.earLeftController)
    }

    // MARK: - (b) Flag on + eligible + has data (Beast) — sprite swap

    func testFlagOnAtBeastRetiresEveryVectorFaceAndTailPartForOneCleanCat() {
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

        // CHIMERA fix (post-deploy) — model ①'s baked frame is a COMPLETE
        // realistic render: it already draws its own eyes/nose/mouth/
        // whiskers AND its own tail, so every one of those vector parts
        // (previously kept as "L3 overlays" for a face-neutral
        // placeholder) must now ALSO be hidden, not just ears/head_shape.
        for name in ["eye_left", "eye_right", "nose", "mouth", "whisker_left", "whisker_right"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) should still exist (hidden), not removed")
                continue
            }
            XCTAssertTrue(node.isHidden, "\(name) must be hidden in sprite mode")
        }
        // Grandchildren too — hiding the `eye_left`/`eye_right` CONTAINER
        // already suppresses rendering of everything under it, but the
        // coordinator's own regression list names `pupils` specifically,
        // so pin each leaf's OWN `isHidden` flag directly rather than
        // relying on the render-cascade alone.
        for name in ["eye_left_shape", "eye_left_iris", "eye_left_pupil",
                     "eye_left_catchlight", "eye_left_catchlight2",
                     "eye_right_shape", "eye_right_iris", "eye_right_pupil",
                     "eye_right_catchlight", "eye_right_catchlight2",
                     "mouth_inner", "whisker_left_0", "whisker_left_1", "whisker_left_2",
                     "whisker_right_0", "whisker_right_1", "whisker_right_2"] {
            guard let node = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) should still exist (hidden), not removed")
                continue
            }
            XCTAssertTrue(node.isHidden, "\(name) must be hidden in sprite mode")
        }

        // Controllers are UNCHANGED by the chimera fix — this is additive
        // hiding of render nodes only, not a behavior change. (Ears/paws
        // controllers were already nil'd out by the ORIGINAL sub-part 2,
        // asserted above; that's untouched too.)
        XCTAssertNotNil(creature.eyeLeftController)
        XCTAssertNotNil(creature.eyeRightController)
        XCTAssertNotNil(creature.mouthController)
        XCTAssertNotNil(creature.whiskerLeftController)
        XCTAssertNotNil(creature.whiskerRightController)

        // Tail (L2) — model ①'s particle-fur tail is baked into the body
        // mesh and non-separable (`bake-manifest.json`'s
        // `tail_separable: false`), so `SpriteBodyMode.
        // tailIsBakedIntoSprite(stage: .beast)` is true and the WHOLE
        // segmented-tail overlay must be skipped, not merely hidden — no
        // `tail_base`/`tail_seg_0` node at all, and no `tailController`
        // spending per-frame spring-physics work on a chain that could
        // never render either way.
        XCTAssertNil(creature.childNode(withName: "//tail_base"),
                     "tail_base must not be built when the tail is baked into the sprite")
        XCTAssertNil(creature.childNode(withName: "//tail_seg_0"),
                     "tail_seg_0 must not be built when the tail is baked into the sprite")
        XCTAssertNil(creature.tailController,
                    "tailController must not be built when the tail is baked into the sprite")
    }

    /// The L3 hardcoded head-anchor override (§4) — `head` must sit at
    /// `ClipTable.overlayAnchors(for: .beast)`'s `headOffset`, not the
    /// vector-authored position a plain flag-off build would use. (The
    /// matching `tail_base` override no longer applies at Beast post-
    /// chimera-fix — `tailIsBakedIntoSprite` means `tail_base` isn't
    /// built in sprite mode at all; see
    /// `testFlagOnAtBeastRetiresEveryVectorFaceAndTailPartForOneCleanCat`'s
    /// own tail assertions for that half.)
    func testSpriteModeOverridesHeadAnchorToTheHardcodedApproximation() {
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
              let vectorHead = vectorCreature.childNode(withName: "//head") else {
            return XCTFail("head must exist on both creatures")
        }

        // Sprite mode's absolute (pelvis-relative) position should equal
        // the anchor constant; the vector build's should not (proving
        // this is an actual override, not a coincidence).
        let spriteHeadAbsolute = spriteHead.parent!.convert(spriteHead.position, to: spriteCreature)
        let vectorHeadAbsolute = vectorHead.parent!.convert(vectorHead.position, to: vectorCreature)
        XCTAssertEqual(spriteHeadAbsolute.x, anchors.headOffset.x, accuracy: 0.0001)
        XCTAssertEqual(spriteHeadAbsolute.y, anchors.headOffset.y, accuracy: 0.0001)
        XCTAssertNotEqual(vectorHeadAbsolute.x, anchors.headOffset.x)
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

    // MARK: - ALLOWLIST rewrite (post-deploy, "maybe extra ears" fix)

    /// EAR DIAGNOSIS + the allowlist mechanism itself, in one test: `head`
    /// still has real `ear_left`/`ear_right` `SKShapeNode`s attached
    /// (StageRenderer.buildBeast never stopped building them — they're
    /// vector anatomy left over from the pre-sprite render, not something
    /// baked into model ①'s frame) — so the "maybe extra ears" a human
    /// flagged were these, rendering on TOP of the baked sprite's own
    /// (single, correct) baked-in ears whenever a denylist gap left them
    /// unhidden. This test proves the allowlist rewrite closes every such
    /// gap categorically: walk the ENTIRE creature subtree, and every
    /// node that is neither the sprite body nor one of its ancestors must
    /// be hidden — not just `head`'s children, not just the ones a
    /// denylist happened to name.
    func testFlagOnAtBeastAllowlistHidesEveryNodeExceptSpriteBodyAndItsAncestors() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)

        let creature = CreatureNode()
        creature.configureForStage(.beast)

        guard let bodyNode = creature.childNode(withName: "//body"),
              let sprite = bodyNode as? SKSpriteNode else {
            return XCTFail("body must be reachable and be the sprite in this mode")
        }

        // EAR DIAGNOSIS — vector ear nodes DO exist (real anatomy left
        // over from the pre-bake vector build), and the allowlist must
        // hide them like everything else.
        for name in ["ear_left", "ear_right"] {
            guard let ear = creature.childNode(withName: "//\(name)") else {
                XCTFail("\(name) should still exist as a vector node (hidden), not removed")
                continue
            }
            XCTAssertTrue(ear.isHidden, "\(name) must be hidden by the allowlist")
        }

        // The sprite's own ancestor chain (pelvis, spine_chest) — these
        // must stay visible, or the sprite itself would never render.
        var ancestors: Set<ObjectIdentifier> = []
        var walk: SKNode? = sprite.parent
        while let node = walk, node !== creature {
            ancestors.insert(ObjectIdentifier(node))
            walk = node.parent
        }
        XCTAssertFalse(ancestors.isEmpty, "sanity: the sprite must have at least one ancestor (pelvis)")

        let spriteID = ObjectIdentifier(sprite)
        var visibleLeafCount = 0
        var hiddenCount = 0

        func walkTree(_ node: SKNode) {
            for child in node.children {
                let id = ObjectIdentifier(child)
                if id == spriteID || ancestors.contains(id) {
                    XCTAssertFalse(child.isHidden,
                        "'\(child.name ?? "?")' is the sprite or one of its ancestors — must stay visible")
                    if id == spriteID { visibleLeafCount += 1 }
                } else {
                    XCTAssertTrue(child.isHidden,
                        "'\(child.name ?? "?")' is not on the sprite-mode allowlist — must be hidden")
                    hiddenCount += 1
                }
                walkTree(child)
            }
        }
        walkTree(creature)

        XCTAssertEqual(visibleLeafCount, 1, "exactly the sprite body must be the allowlisted leaf")
        XCTAssertGreaterThan(hiddenCount, 0, "sanity: there must be OTHER creature nodes to hide")
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
