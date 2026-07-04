// PerformActionMappingTests.swift — WO-19 sub-part 2 REVISE (Fix 3):
// the 6 new perform-triggerable posture actions (loaf/sphinx/sprawl/curl/
// groom/knead), added so the WO-19 parade can PROVE these postures via a
// persistent AI-Directed-layer trigger — the same path `meditate` already
// uses to hold `sit` for 5s — without waiting on WO-20's autonomous
// selection logic.

import XCTest
@testable import Pushling

final class PerformActionMappingNewPosturesTests: XCTestCase {

    func testLoafMapsToLoafBodyState() {
        guard let (output, _) = PerformActionMapping.map("loaf", variant: "default", stage: .beast) else {
            return XCTFail("loaf should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "loaf")
    }

    func testSphinxMapsToSphinxBodyState() {
        guard let (output, _) = PerformActionMapping.map("sphinx", variant: "default", stage: .beast) else {
            return XCTFail("sphinx should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "sphinx")
    }

    func testSprawlMapsToSprawlBodyStateWithKickedPaw() {
        guard let (output, _) = PerformActionMapping.map("sprawl", variant: "default", stage: .beast) else {
            return XCTFail("sprawl should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "sprawl")
        XCTAssertEqual(output.pawStates?["bl"], "kicked",
                       "sprawl must carry idle-life-and-rest.md's pawStates[\"bl\"]=\"kicked\" literal")
    }

    func testCurlMapsToCurlBodyState() {
        guard let (output, _) = PerformActionMapping.map("curl", variant: "default", stage: .beast) else {
            return XCTFail("curl should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "curl")
    }

    func testGroomMapsToGroomBodyState() {
        guard let (output, _) = PerformActionMapping.map("groom", variant: "default", stage: .beast) else {
            return XCTFail("groom should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "groom")
    }

    func testKneadMapsToKneadBodyState() {
        guard let (output, _) = PerformActionMapping.map("knead", variant: "default", stage: .beast) else {
            return XCTFail("knead should map to a LayerOutput")
        }
        XCTAssertEqual(output.bodyState, "knead")
    }

    /// No stage `guard` was added for sphinx/sprawl at this mapping layer
    /// (by design — BodyPoseTable.resolve() already owns that gate and
    /// falls back to `stand` cleanly). Confirm the mapping itself still
    /// succeeds at every stage (it's BodyPoseTable's job, not this one's,
    /// to neutralize a wrong-stage request).
    func testSphinxAndSprawlMappingSucceedsAtEveryStageDelegatingGateDownstream() {
        for stage in GrowthStage.allCases {
            XCTAssertNotNil(PerformActionMapping.map("sphinx", variant: "default", stage: stage),
                            "sphinx mapping itself is stage-agnostic at stage \(stage)")
            XCTAssertNotNil(PerformActionMapping.map("sprawl", variant: "default", stage: stage),
                            "sprawl mapping itself is stage-agnostic at stage \(stage)")
        }
    }

    /// The daemon's OWN action allowlist (CommandRouter.route() rejects an
    /// action before it ever reaches PerformActionMapping if it's missing
    /// here) — the actual regression this Fix 3 pass needed to close.
    func testAllSixNewActionsAreInCommandRouterValidActions() {
        let valid = CommandRouter.validActions["perform"] ?? []
        for action in ["loaf", "sphinx", "sprawl", "curl", "groom", "knead"] {
            XCTAssertTrue(valid.contains(action),
                          "\(action) must be in CommandRouter.validActions[\"perform\"] or " +
                          "CommandRouter.route() hard-rejects it with UNKNOWN_ACTION " +
                          "before PerformActionMapping ever sees it")
        }
    }
}
