// GroundedGaitTests.swift — WO-44 Ph1 ("Grounded Diorama" MVP, per
// `.samantha/plans/track-b-grounded-diorama.md` at the workspace root):
// the two live human complaints this WO fixes, both proven at the pure-
// math layer since `swift test` never has a real bundled sprite resource
// (`SpriteFrameLoader`'s own file header) — the same honest-testing
// philosophy `SpriteBodySwapTests.swift`'s own header already documents
// for this exact reason.
//
//   §1 "standing on water"  — `CreatureNode.anchorPixelToLocalY` /
//       `spriteGroundOffsetY` land the baked per-frame `groundContact`
//       anchor pixel exactly on the ground line, proven against EVERY
//       frame of Beast's REAL committed Walk clip (read live from
//       `ClipTable`, not hand-copied literals) — not just spot-checked.
//   §2 "glitching/jerky"    — `CreatureNode.bakedStrideLength` /
//       `spriteFrameIndexByDistance` replace time-driven frame advance
//       with distance-driven phase, proven to (a) agree exactly with the
//       OLD time-phased `spriteFrameIndex` at the stage's own reference
//       walk speed (a generalization, not a different animation) and
//       (b) genuinely diverge at a different speed (a real behavior
//       change, not a no-op refactor) and (c) freeze when distance is
//       frozen (the actual mechanism that kills foot-slide).

import XCTest
import SpriteKit
@testable import Pushling

final class GroundedGaitTests: XCTestCase {

    // MARK: - §1 Ground-contact pixel -> local point-space

    /// Hand-derived reference point: Beast's committed PNGs are native
    /// 36x40px (confirmed via `sips -g pixelWidth -g pixelHeight`, not
    /// assumed) and `SpriteBodyMode.spriteDisplayHeight` forces every
    /// sprite-mode frame to render at 46pt tall — a DIFFERENT, larger
    /// number than `StageConfiguration.beast.size.height` (20pt), which is
    /// exactly the mismatch that makes the OLD center-based ground math
    /// wrong (see `applySpriteGroundContact`'s doc comment). At pixel
    /// Y=20 (the texture's own vertical midline), the converted local Y
    /// must be exactly 0 (the sprite's own geometric center) — the base
    /// case that anchors every other value's sign/scale.
    func testAnchorPixelToLocalYCentersAtTheTextureMidline() {
        let localY = CreatureNode.anchorPixelToLocalY(20.0, textureHeightPx: 40.0, displayHeight: 46.0)
        XCTAssertEqual(localY, 0.0, accuracy: 0.0001)
    }

    /// Pixel Y=0 (the very top row of the texture, target-pixel/top-left
    /// origin) must map to +displayHeight/2 (the sprite's topmost local Y,
    /// since SpriteKit Y grows up while pixel Y grows down).
    func testAnchorPixelToLocalYFlipsTopRowToPositiveLocalY() {
        let localY = CreatureNode.anchorPixelToLocalY(0.0, textureHeightPx: 40.0, displayHeight: 46.0)
        XCTAssertEqual(localY, 23.0, accuracy: 0.0001)
    }

    /// Beast's real Idle groundContact anchor (px 25.231 of 40, per
    /// `ClipTable.beastClips`) converted at Beast's real display height —
    /// pins the exact number the live compose point will compute, so a
    /// future accidental change to either the anchor data or
    /// `spriteDisplayHeight` breaks this test loudly instead of silently
    /// drifting the foot off the ground line again.
    func testAnchorPixelToLocalYMatchesBeastIdleAnchorRegressionPin() {
        guard let contact = ClipTable.clip(for: "stand", stage: .beast)?.anchors?[0]?.groundContact else {
            return XCTFail("Beast Idle must have a groundContact anchor at frame 0")
        }
        let displaySize = SpriteBodyMode.spriteDisplaySize(
            fromConfigSize: StageConfiguration.all[.beast]!.size
        )
        let localY = CreatureNode.anchorPixelToLocalY(
            contact.y, textureHeightPx: 40.0, displayHeight: displaySize.height
        )
        XCTAssertEqual(localY, -6.0157, accuracy: 0.001)
    }

    // MARK: - §1 The grounding offset itself — full walk-cycle proof

    /// THE acceptance bar, proven directly rather than eyeballed: for
    /// EVERY frame of Beast's real Walk clip (read live from `ClipTable`,
    /// all 6 frames) plus Idle's single frame, composing
    /// `PushlingScene`'s existing root-Y formula (`terrainY +
    /// stageHalfHeight`, UNCHANGED by this WO) with
    /// `spriteGroundOffsetY`'s correction and the anchor's own converted
    /// local Y must land EXACTLY on `terrainY` (the bare ground line) —
    /// not merely "within 0.5pt" (the WO's stated bar), but within
    /// floating-point noise of ZERO error, since the offset is an exact
    /// algebraic solve for that equality, not an approximation. Run at
    /// three different arbitrary `terrainY` values to confirm the result
    /// doesn't depend on where the terrain actually is.
    func testGroundContactLandsExactlyOnTheGroundLineAcrossTheFullWalkCycleAndIdle() {
        guard let walkClip = ClipTable.walkClip(for: .beast),
              let idleClip = ClipTable.clip(for: "stand", stage: .beast) else {
            return XCTFail("Beast must have Walk and Idle clip data")
        }
        let config = StageConfiguration.all[.beast]!
        let displaySize = SpriteBodyMode.spriteDisplaySize(fromConfigSize: config.size)
        let stageHalfHeight = config.size.height / 2
        // Beast's real committed PNGs are native 36x40px (sips-verified,
        // see file header) — every clip's frames share this native size
        // since they're one bake, so this is safe to hardcode once here
        // rather than needing a live SKTexture (unavailable under
        // `swift test` — see SpriteFrameLoader.swift).
        let textureHeightPx: CGFloat = 40.0

        var casesChecked = 0
        for terrainY: CGFloat in [0.0, 10.0, -4.0] {
            let rootY = terrainY + stageHalfHeight  // PushlingScene's existing formula, unchanged

            for frameIndex in 0..<walkClip.frames.count {
                guard let contact = walkClip.anchors?[frameIndex]?.groundContact else {
                    XCTFail("Walk frame \(frameIndex) must have a groundContact anchor")
                    continue
                }
                let localY = CreatureNode.anchorPixelToLocalY(
                    contact.y, textureHeightPx: textureHeightPx, displayHeight: displaySize.height
                )
                let offsetY = CreatureNode.spriteGroundOffsetY(
                    contactLocalY: localY, stageHalfHeight: stageHalfHeight
                )
                let resolvedContactWorldY = rootY + offsetY + localY
                XCTAssertEqual(resolvedContactWorldY, terrainY, accuracy: 0.001,
                    "walk frame \(frameIndex) at terrainY=\(terrainY): foot must land on the ground line")
                casesChecked += 1
            }

            guard let idleContact = idleClip.anchors?[0]?.groundContact else {
                return XCTFail("Idle frame 0 must have a groundContact anchor")
            }
            let idleLocalY = CreatureNode.anchorPixelToLocalY(
                idleContact.y, textureHeightPx: textureHeightPx, displayHeight: displaySize.height
            )
            let idleOffsetY = CreatureNode.spriteGroundOffsetY(
                contactLocalY: idleLocalY, stageHalfHeight: stageHalfHeight
            )
            XCTAssertEqual(rootY + idleOffsetY + idleLocalY, terrainY, accuracy: 0.001,
                "idle frame at terrainY=\(terrainY): foot must land on the ground line")
            casesChecked += 1
        }
        XCTAssertEqual(casesChecked, 3 * (6 + 1), "sanity: every walk frame + idle checked at every terrainY")
    }

    /// Regression pin for the offset's own magnitude at Beast's real Idle
    /// anchor (the "several points off the ground" the human actually
    /// saw) — proves this WO's fix is a real, non-trivial correction, not
    /// a no-op that happens to cancel out.
    func testSpriteGroundOffsetYIsNonTrivialAtBeastsRealIdleAnchor() {
        let offset = CreatureNode.spriteGroundOffsetY(contactLocalY: -6.0157, stageHalfHeight: 10.0)
        XCTAssertEqual(offset, -3.9843, accuracy: 0.001)
        XCTAssertNotEqual(offset, 0.0, accuracy: 0.5,
            "the pre-fix placement (offset == 0, i.e. sprite center at the old ground assumption) " +
            "must differ from the corrected offset by more than the WO's own 0.5pt bar")
    }

    // MARK: - §2 Distance-phased gait — the foot-slide fix

    /// Beast's real Walk clip (6 frames @ 10fps -> 0.6s cycle) at Beast's
    /// real reference walk speed (25pt/s) must yield exactly 15.0pt of
    /// stride — the hand-derived number this WO's design doc's own
    /// "compute from walkSpeed" fallback describes.
    func testBakedStrideLengthMatchesBeastsRealWalkClipAndReferenceSpeed() {
        guard let walkClip = ClipTable.walkClip(for: .beast) else {
            return XCTFail("Beast must have a Walk clip")
        }
        guard let stride = CreatureNode.bakedStrideLength(clip: walkClip, stage: .beast) else {
            return XCTFail("Beast's real Walk clip must yield a non-nil stride length")
        }
        XCTAssertEqual(stride, 15.0, accuracy: 0.0001)
    }

    func testBakedStrideLengthIsNilForAClipWithNoFramesOrNoFps() {
        let noFrames = ClipDefinition(frames: [], fps: 10, loop: true, anchors: nil)
        XCTAssertNil(CreatureNode.bakedStrideLength(clip: noFrames, stage: .beast))
        let noFps = ClipDefinition(frames: ["a"], fps: 0, loop: true, anchors: nil)
        XCTAssertNil(CreatureNode.bakedStrideLength(clip: noFps, stage: .beast))
    }

    /// THE equivalence proof: at the stage's own reference walk speed,
    /// distance-phase and the OLD time-phase must agree EXACTLY at every
    /// sample the existing `testSpriteFrameIndexAdvancesAndWrapsForLoopingClips`
    /// pins (0, 0.15s, 0.35s, 0.65s-wraps) — confirming this fix is a
    /// genuine generalization of the old math (identical output when
    /// speed matches the bake), not a silently different animation.
    func testSpriteFrameIndexByDistanceAgreesWithTimePhaseAtTheReferenceSpeed() {
        let referenceSpeed: CGFloat = GrowthStage.beast.baseWalkSpeed  // 25 pt/s
        let strideLength: CGFloat = 15.0  // Beast Walk: 6 frames @ 10fps * 25pt/s

        for t: TimeInterval in [0, 0.15, 0.35, 0.65] {
            let timeIndex = CreatureNode.spriteFrameIndex(clipTime: t, fps: 10, frameCount: 6, loop: true)
            let distance = referenceSpeed * CGFloat(t)
            let distanceIndex = CreatureNode.spriteFrameIndexByDistance(
                distanceTravelled: distance, strideLength: strideLength, frameCount: 6, loop: true
            )
            XCTAssertEqual(distanceIndex, timeIndex,
                "at the reference speed, distance-phase must reproduce the old time-phase result at t=\(t)")
        }
    }

    /// THE divergence proof: at DOUBLE the reference speed, distance-phase
    /// must reach a LATER frame than time-phase does at the same
    /// wall-clock instant — proving this is a real behavior change (the
    /// leg cycle now keeps pace with actual translation) rather than the
    /// equivalence test above being a coincidental no-op.
    func testSpriteFrameIndexByDistanceDivergesFromTimePhaseAtDoubleSpeed() {
        let strideLength: CGFloat = 15.0
        let t: TimeInterval = 0.15
        let timeIndexAtT: Int = CreatureNode.spriteFrameIndex(clipTime: t, fps: 10, frameCount: 6, loop: true)
        XCTAssertEqual(timeIndexAtT, 1, "sanity: matches the existing pinned time-phase value")

        let doubleSpeedDistance: CGFloat = 50.0 * CGFloat(t)  // 2x Beast's 25pt/s reference
        let distanceIndexAtDoubleSpeed = CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: doubleSpeedDistance, strideLength: strideLength, frameCount: 6, loop: true
        )
        XCTAssertEqual(distanceIndexAtDoubleSpeed, 3)
        XCTAssertGreaterThan(distanceIndexAtDoubleSpeed, timeIndexAtT,
            "double speed must cycle the leg frames faster (further ahead at the same wall-clock instant)")
    }

    /// The actual foot-slide-killing mechanism: a FROZEN distance (the
    /// creature stopped translating) must hold the SAME frame regardless
    /// of how much wall-clock time passes — the old time-phased function
    /// would keep advancing (legs cycling in place); distance-phase
    /// deliberately can't, because nothing is feeding it new distance.
    func testSpriteFrameIndexByDistanceFreezesWhenDistanceStopsAdvancing() {
        let frozenDistance: CGFloat = 7.5  // e.g. creature translated 7.5pt, then stopped
        let strideLength: CGFloat = 15.0
        let firstCall = CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: frozenDistance, strideLength: strideLength, frameCount: 6, loop: true
        )
        let secondCall = CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: frozenDistance, strideLength: strideLength, frameCount: 6, loop: true
        )
        XCTAssertEqual(firstCall, secondCall, "identical distance must resolve to the identical frame")
        XCTAssertEqual(firstCall, 3)
    }

    func testSpriteFrameIndexByDistanceGuardsZeroStrideAndZeroFrames() {
        XCTAssertEqual(CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: 5, strideLength: 0, frameCount: 6, loop: true), 0)
        XCTAssertEqual(CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: 5, strideLength: 15, frameCount: 0, loop: true), 0)
    }

    /// Non-looping clip variant (no Beast clip is non-looping today, but
    /// the function must still hold its last frame rather than crash via
    /// an out-of-bounds index — mirrors `spriteFrameIndex`'s own
    /// equivalent guarantee for the time-phased path).
    func testSpriteFrameIndexByDistanceHoldsLastFrameForNonLoopingClips() {
        let index = CreatureNode.spriteFrameIndexByDistance(
            distanceTravelled: 1000, strideLength: 15, frameCount: 4, loop: false
        )
        XCTAssertEqual(index, 3)
    }

    // MARK: - Integration smoke test (wiring doesn't crash; texture-level
    // behavior is untestable under `swift test` — see file header)

    /// Mirrors `SpriteBodySwapTests.testTickingASpriteModeCreatureWithWalkSpeedSetDoesNotCrash`
    /// — the two new accumulators (`clipDistanceTravelled`'s increment,
    /// `applySpriteGroundContact`'s per-frame write) must not crash across
    /// many ticks with a real walking signal, and the sprite path must
    /// stay active throughout (the gate this WO's fix rides on top of).
    func testTickingASpriteModeCreatureWithWalkSpeedSetStillDoesNotCrashAfterThisWO() {
        setenv("PUSHLING_SPRITE_BODY", "1", 1)
        defer { unsetenv("PUSHLING_SPRITE_BODY") }

        let creature = CreatureNode()
        creature.configureForStage(.beast)
        creature.bodyPoseController?.setState("stand", duration: 0)
        creature.walkSpeed = 25

        for _ in 0..<120 { creature.update(deltaTime: 1.0 / 60.0) }

        XCTAssertTrue(creature.childNode(withName: "//body") is SKSpriteNode)
    }
}
