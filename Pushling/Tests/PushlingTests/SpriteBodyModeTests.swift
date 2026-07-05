// SpriteBodyModeTests.swift — Unit tests for WO-27 sub-part 1's sprite-
// body feature flag. Mirrors the "off unless asked" contract WorkbenchMode
// already relies on elsewhere in this test target.

import XCTest
@testable import Pushling

final class SpriteBodyModeTests: XCTestCase {

    func testIsEnabledDefaultsToFalseUnderNormalTestInvocation() {
        // `swift test` does not pass --sprite-body nor set
        // PUSHLING_SPRITE_BODY=1, so this pins the "off by default"
        // contract under the actual test-runner environment rather than
        // asserting it only in the abstract.
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains("--sprite-body"))
        if ProcessInfo.processInfo.environment["PUSHLING_SPRITE_BODY"] != "1" {
            XCTAssertFalse(SpriteBodyMode.isEnabled)
        }
    }

    func testEggAndDropAreNeverEligible() {
        XCTAssertFalse(SpriteBodyMode.isEligible(stage: .egg))
        XCTAssertFalse(SpriteBodyMode.isEligible(stage: .drop))
    }

    func testCritterBeastSageApexAreEligible() {
        XCTAssertTrue(SpriteBodyMode.isEligible(stage: .critter))
        XCTAssertTrue(SpriteBodyMode.isEligible(stage: .beast))
        XCTAssertTrue(SpriteBodyMode.isEligible(stage: .sage))
        XCTAssertTrue(SpriteBodyMode.isEligible(stage: .apex))
    }

    /// CHIMERA fix — model ①'s Beast bake has a non-separable particle-fur
    /// tail baked into the body mesh (`bake-manifest.json`'s
    /// `tail_separable: false`), so Beast is the one stage where the L2
    /// `SegmentedTailController` overlay must be suppressed entirely
    /// rather than left as a legitimate stand-in. Every other stage
    /// defaults `false` (no baked model exists yet at any of them, so
    /// there is nothing to be baked-in yet either) — this is data about
    /// the CURRENT bake per stage, not a permanent per-stage ruling; see
    /// the function's own doc comment for how a future separable-tail
    /// bake would flip a stage back to `false`.
    func testOnlyBeastHasATailBakedIntoItsCurrentSprite() {
        XCTAssertTrue(SpriteBodyMode.tailIsBakedIntoSprite(stage: .beast))
        XCTAssertFalse(SpriteBodyMode.tailIsBakedIntoSprite(stage: .egg))
        XCTAssertFalse(SpriteBodyMode.tailIsBakedIntoSprite(stage: .drop))
        XCTAssertFalse(SpriteBodyMode.tailIsBakedIntoSprite(stage: .critter))
        XCTAssertFalse(SpriteBodyMode.tailIsBakedIntoSprite(stage: .sage))
        XCTAssertFalse(SpriteBodyMode.tailIsBakedIntoSprite(stage: .apex))
    }
}
