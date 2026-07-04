// PushlingSceneComposeTests.swift — Unit tests for the compose-not-clobber
// positionY math (body-pose-pipeline.md §4). Exercises
// `PushlingScene.composedCreatureY` directly — a pure static helper, no
// SpriteKit scene or daemon required — so this is a durable regression
// guard on the WO-6 keystone pilot's core behavior.

import XCTest
@testable import Pushling

final class PushlingSceneComposeTests: XCTestCase {

    /// Grounded: resolvedPositionY matches the stage's own grounded
    /// default -> no lift, composed Y is exactly the terrain-derived
    /// ground Y, and isAirborne is false.
    func testGroundedRestsOnGroundYWithNoLift() {
        let result = PushlingScene.composedCreatureY(
            groundY: 15.0,
            resolvedPositionY: 3.0,
            groundedDefaultY: 3.0,
            stageHeight: 10.0,
            sceneHeight: 30.0
        )

        XCTAssertEqual(result.y, 15.0)
        XCTAssertFalse(result.isAirborne)
    }

    /// Airborne lift: a jump apex above the grounded default rides on top
    /// of groundY exactly by the offset, and isAirborne flips true —
    /// composed, not clobbered.
    func testAirborneLiftAddsOffsetOnTopOfGroundY() {
        // Beast jump apex per body-pose-pipeline.md §4's headroom table: 6pt.
        let result = PushlingScene.composedCreatureY(
            groundY: 15.0,
            resolvedPositionY: 9.0,   // groundedDefaultY (3.0) + 6.0 apex
            groundedDefaultY: 3.0,
            stageHeight: 10.0,
            sceneHeight: 30.0
        )

        XCTAssertEqual(result.y, 21.0)   // 15.0 groundY + 6.0 offset
        XCTAssertTrue(result.isAirborne)
    }

    /// Airborne clamp suspension (load-bearing §4 rule): a lift large
    /// enough to exceed the grounded terrain-comfort maxY must still rise
    /// — clamped only to the true screen edge (sceneHeight - 1.0), never
    /// pinned back down to the terrain-comfort ceiling a grounded creature
    /// would hit.
    func testAirborneSuspendsTerrainComfortClampAtScreenEdge() {
        let stageHeight: CGFloat = 10.0
        let sceneHeight: CGFloat = 30.0
        let groundedMaxY = sceneHeight - stageHeight / 2 - 1.0   // 24.0 — would apply if grounded

        let result = PushlingScene.composedCreatureY(
            groundY: 15.0,
            resolvedPositionY: 23.0,  // groundedDefaultY (3.0) + 20.0 — well past groundedMaxY
            groundedDefaultY: 3.0,
            stageHeight: stageHeight,
            sceneHeight: sceneHeight
        )

        XCTAssertTrue(result.isAirborne)
        XCTAssertGreaterThan(result.y, groundedMaxY,
                              "airborne lift must rise past the terrain-comfort clamp, not be pinned to it")
        XCTAssertEqual(result.y, sceneHeight - 1.0,
                        "airborne clamp is the true screen edge only")
    }

    /// Below-default guard: a resolvedPositionY beneath the grounded
    /// default (e.g. a stale/negative value) must never sink the creature
    /// below its terrain-derived ground Y — `max(0, airborneOffset)`
    /// floors the lift at zero.
    func testBelowDefaultPositionYNeverSinksBelowGroundY() {
        let result = PushlingScene.composedCreatureY(
            groundY: 15.0,
            resolvedPositionY: 1.0,   // below groundedDefaultY
            groundedDefaultY: 3.0,
            stageHeight: 10.0,
            sceneHeight: 30.0
        )

        XCTAssertEqual(result.y, 15.0, "a below-default offset must floor at 0 lift, not sink the creature")
        XCTAssertFalse(result.isAirborne)
    }
}
