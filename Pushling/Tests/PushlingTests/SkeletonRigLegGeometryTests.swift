// SkeletonRigLegGeometryTests.swift — WO-19 sub-part 3: legs now exist.
// `ShapeFactory.makePaw`'s leg branch (`:303-315`) was always dead — every
// StageRenderer call site fed `legHeight: 0` (the default). This sub-part
// feeds `SkeletonGeometry.legHeight(for:)` instead; these tests prove the
// leg geometry actually appears and is absent where it shouldn't be.
//
// REVISE (parade catch): the original `legHeight` bridged exactly to the
// shoulder/hip PIVOT, but the pivot isn't the body's visual edge — the
// human saw a real gap ("legs not connected to body"). `legHeight` now
// targets the body's true rendered bottom edge (numerically sampled, not
// `CGPath.boundingBox`) plus a 1.5pt overlap constant, so the leg
// deliberately extends PAST the pivot into the body mass. The bridge test
// below now asserts that OVERLAP relationship, not an exact touch.

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

    func testLegHeightMatchesTheNewBodyOverlapDerivedValues() {
        // Recomputed from the sampled body-bottom fractions + the 1.5pt
        // overlap constant — see SkeletonGeometry.legHeight's own doc
        // comment for the derivation. Materially longer than the original
        // beltY-bridging values (2.4/3.0/3.6/4.2) — that's the fix.
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .critter), 4.2456, accuracy: 0.001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .beast), 5.312, accuracy: 0.001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .sage), 6.6192, accuracy: 0.001)
        XCTAssertEqual(SkeletonGeometry.legHeight(for: .apex), 7.5732, accuracy: 0.001)
    }

    // MARK: - Overlaps the Body, No Float / No Overshoot Past It

    /// The REVISE sanity check: a leg anchored at the paw (`groundY`,
    /// UNCHANGED — paws already read correctly) with its body-end
    /// `legHeight` above must land `bodyOverlapConstant` (1.5pt) PAST the
    /// body's real bottom edge — not floating short of it (the original
    /// bug), not so far past it that it overshoots through the body
    /// unrecognizably. Verified against the live node tree's actual
    /// absolute position (paw's position summed up its full parent chain),
    /// not trusted by algebra alone.
    func testLegOverlapsBodyBottomByExactlyTheOverlapConstant() {
        for stage in [GrowthStage.critter, .beast, .sage, .apex] {
            let creature = CreatureNode()
            creature.configureForStage(stage)

            for pawName in ["paw_fl", "paw_fr", "paw_bl", "paw_br"] {
                guard let paw = creature.childNode(withName: "//\(pawName)") else {
                    XCTFail("\(pawName) not found at stage \(stage)")
                    continue
                }
                let pawAbsoluteY = Self.absoluteY(of: paw, upTo: creature)
                let legTopAbsoluteY = pawAbsoluteY + SkeletonGeometry.legHeight(for: stage)
                let expectedLegTop = SkeletonGeometry.bodyBottomY(for: stage)
                    + SkeletonGeometry.bodyOverlapConstant

                XCTAssertEqual(legTopAbsoluteY, expectedLegTop, accuracy: 0.001,
                               "\(pawName) at stage \(stage): leg's top must land exactly " +
                               "bodyOverlapConstant past the body's true bottom edge")
            }
        }
    }

    /// Manually sums `.position.y` up the parent chain — mirrors
    /// `SkeletonRigGate1RestIdentityTests`'s identical helper (declared
    /// `private` there, file-scoped, so re-declared here rather than
    /// exposed cross-file for one small helper).
    private static func absoluteY(of node: SKNode, upTo root: SKNode) -> CGFloat {
        var y: CGFloat = 0
        var current: SKNode? = node
        while let n = current, n !== root {
            y += n.position.y
            current = n.parent
        }
        return y
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
