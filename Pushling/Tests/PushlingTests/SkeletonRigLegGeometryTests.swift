// SkeletonRigLegGeometryTests.swift — WO-19 sub-part 3: legs now exist.
// `ShapeFactory.makePaw`'s leg branch (`:303-315`) was always dead — every
// StageRenderer call site fed `legHeight: 0` (the default). This sub-part
// feeds `SkeletonGeometry.legHeight(for:)` instead; these tests prove the
// leg geometry actually appears, is absent where it shouldn't be, and
// bridges exactly from paw to pivot (no float, no overshoot) rather than
// trusting the derivation by inspection alone.

import XCTest
import SpriteKit
@testable import Pushling

final class SkeletonRigLegGeometryTests: XCTestCase {

    // MARK: - Legs Exist / Absent

    func testLegsExistUnderAllFourPawsAtEveryLegCapableStage() {
        for stage in [GrowthStage.critter, .beast, .sage, .apex] {
            let creature = CreatureNode()
            creature.configureForStage(stage)

            for pawName in ["paw_fl", "paw_fr", "paw_bl", "paw_br"] {
                XCTAssertNotNil(creature.childNode(withName: "//\(pawName)_leg"),
                                "\(pawName)_leg missing at stage \(stage) — " +
                                "ShapeFactory.makePaw's leg branch didn't fire")
            }
        }
    }

    func testLegsAbsentAtEggAndDrop() {
        for stage in [GrowthStage.egg, .drop] {
            let creature = CreatureNode()
            creature.configureForStage(stage)

            for pawName in ["paw_fl", "paw_fr", "paw_bl", "paw_br"] {
                XCTAssertNil(creature.childNode(withName: "//\(pawName)"),
                            "\(pawName) itself shouldn't exist at stage \(stage) " +
                            "(hasPaws: false) — confirms legs can't exist either")
                XCTAssertNil(creature.childNode(withName: "//\(pawName)_leg"))
            }
        }
    }

    // MARK: - Per-Stage legHeight Values

    func testLegHeightMatchesTheDispatchedPerStageValues() {
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .critter), 2.4, accuracy: 0.0001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .beast), 3.0, accuracy: 0.0001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .sage), 3.6, accuracy: 0.0001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .apex), 4.2, accuracy: 0.0001)
    }

    // MARK: - Bridges Exactly, No Float / No Overshoot

    /// The sanity check the dispatch explicitly asked for: a leg anchored
    /// at the paw with its body-end `legHeight` above must land EXACTLY at
    /// the shoulder/hip pivot's own local origin — not floating short of
    /// it, not overshooting past it. Proven by construction (both
    /// sub-part 1's re-basing and this sub-part's `legHeight` derive from
    /// the SAME `beltY`/`groundYFraction` constants), verified here against
    /// the live node tree rather than trusted by algebra alone.
    func testLegBridgesExactlyFromPawToPivotWithNoFloatOrOvershoot() {
        for stage in [GrowthStage.critter, .beast, .sage, .apex] {
            let creature = CreatureNode()
            creature.configureForStage(stage)

            // Every paw is a direct child of its shoulder/hip pivot
            // (sub-part 1) — its own `.position.y` IS the paw's offset
            // from the pivot's local origin, no chain-walking needed.
            for pawName in ["paw_fl", "paw_fr", "paw_bl", "paw_br"] {
                guard let paw = creature.childNode(withName: "//\(pawName)") else {
                    XCTFail("\(pawName) not found at stage \(stage)")
                    continue
                }
                let expectedPawY = -SkeletonGeometry.legHeight(for: stage)
                XCTAssertEqual(paw.position.y, expectedPawY, accuracy: 0.001,
                               "\(pawName) at stage \(stage): paw's offset from its pivot must " +
                               "equal -legHeight exactly, so the leg (drawn 0...legHeight in the " +
                               "paw's own local space) lands precisely at the pivot's origin")
            }
        }
    }

    // MARK: - Front vs. Back Leg Shape

    /// `isFront` was never threaded before this sub-part (every call site
    /// omitted it, silently defaulting `true` for every paw including rear
    /// ones — harmless while `legHeight` was always 0, but would have
    /// rendered back legs with the front "clean inward taper" shape
    /// instead of the back "outward thigh bulge" the moment legs went
    /// live). Confirms the two paths are now genuinely distinct shapes at
    /// the same stage (same size/legHeight), not silently identical.
    func testFrontAndBackLegsAreDistinctShapesAtTheSameStage() {
        let creature = CreatureNode()
        creature.configureForStage(.beast)

        guard let frontLeg = creature.childNode(withName: "//paw_fl_leg") as? SKShapeNode,
              let backLeg = creature.childNode(withName: "//paw_bl_leg") as? SKShapeNode else {
            return XCTFail("leg nodes not found")
        }

        XCTAssertNotEqual(frontLeg.path?.boundingBox, backLeg.path?.boundingBox,
                          "front (isFront: true) and back (isFront: false) leg paths " +
                          "must differ — CatShapes.catLeg's back-leg thigh bulge vs. " +
                          "front-leg clean taper")
    }
}
