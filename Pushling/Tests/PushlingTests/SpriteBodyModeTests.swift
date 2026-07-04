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
}
