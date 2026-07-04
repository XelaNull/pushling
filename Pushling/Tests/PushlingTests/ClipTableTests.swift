// ClipTableTests.swift — Unit tests for WO-27 sub-part 1's bodyState ->
// clip lookup. Mirrors BodyPoseTableTests.swift's pattern of testing the
// pure static table through its public resolver, no live scene needed.

import XCTest
@testable import Pushling

final class ClipTableTests: XCTestCase {

    // MARK: - Reachable core -> clip mappings

    func testStandResolvesToIdleClip() {
        let clip = ClipTable.clip(for: "stand", stage: .beast)
        XCTAssertEqual(clip?.frames, ["beast_idle_00"])
        XCTAssertEqual(clip?.loop, true)
    }

    func testCrouchResolvesToJumpStartClip() {
        let clip = ClipTable.clip(for: "crouch", stage: .beast)
        XCTAssertEqual(clip?.frames, ["beast_jumpstart_00"])
        XCTAssertEqual(clip?.loop, false)
    }

    func testJumpResolvesToTheSameJumpStartClipAsCrouch() {
        let jumpClip = ClipTable.clip(for: "jump", stage: .beast)
        let crouchClip = ClipTable.clip(for: "crouch", stage: .beast)
        XCTAssertEqual(jumpClip?.frames, crouchClip?.frames)
    }

    func testUnknownBodyStateFallsBackToIdleClip() {
        let clip = ClipTable.clip(for: "totally_unrecognized_string_xyz", stage: .beast)
        XCTAssertEqual(clip?.frames, ["beast_idle_00"])
    }

    /// Anything BodyPoseTable's own alias map routes to a core state this
    /// table DOES map (e.g. "sit" -> "sit" is core but unmapped here ->
    /// Idle fallback; "examine" -> "lean_forward" -> unmapped -> Idle) —
    /// spot-checks that routing through resolve() first behaves, not just
    /// direct core-string lookups.
    func testAliasedBodyStateRoutesThroughBodyPoseTableFirst() {
        // "handstand_prep" aliases to "crouch" in BodyPoseTable's §2b map.
        let clip = ClipTable.clip(for: "handstand_prep", stage: .beast)
        XCTAssertEqual(clip?.frames, ["beast_jumpstart_00"])
    }

    // MARK: - Flagged finding: "walk" is currently unreachable as "Walk"

    /// Documents (and pins, via a real assertion, not just a comment) the
    /// finding recorded in ClipTable.swift: BodyPoseTable.resolve()
    /// already collapses "walk" to "stand" (correct for the vector path,
    /// where gait is walkSpeed/PawController-driven, not bodyState-driven).
    /// Since `clip(for:stage:)` calls `resolve()` FIRST, unchanged, "walk"
    /// as a raw bodyState currently resolves to the Idle clip, NOT Walk —
    /// this is a real, load-bearing gap for sub-part 2+ to close via a
    /// walkSpeed-driven signal alongside bodyState (master plan §4's own
    /// "distance-driven gait phase selects walk frames"), not a table bug.
    /// If this test starts failing, it means BodyPoseTable's alias map
    /// changed underneath this file and the finding needs re-checking.
    func testWalkBodyStateCurrentlyCollapsesToIdleNotWalk_flaggedGap() {
        let clip = ClipTable.clip(for: "walk", stage: .beast)
        XCTAssertEqual(clip?.frames, ["beast_idle_00"],
                        "walk currently collapses to stand->Idle via BodyPoseTable's own alias map — see ClipTable.swift's flagged finding")
    }

    // MARK: - Stage gating

    func testStagesWithNoScaffoldingReturnNil() {
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .critter))
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .sage))
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .apex))
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .egg))
        XCTAssertNil(ClipTable.clip(for: "stand", stage: .drop))
    }
}
