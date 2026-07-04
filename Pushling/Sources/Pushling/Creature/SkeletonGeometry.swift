// SkeletonGeometry.swift — Joint-placement formulas for the pelvis-chain rig
// (WO-19). Home for every authored constant the skeleton needs, so WO-19's
// later sub-parts (leg geometry, follow-factors) and WO-20 (gait) have one
// place to find/retune them rather than magic numbers scattered across
// CreatureNode.swift.
//
// All formulas are expressed as fractions of a stage's OWN authored
// geometry (body height, head/tail/paw rest positions) rather than fixed
// point values, so they automatically track StageRenderer's existing
// per-stage/trait-scaled numbers instead of duplicating them.
//
// Sub-part 1 placed the 7 joint nodes (`beltY`, chest pivot factor).
// Sub-part 2 added `chestFollowFactor` — the proportional appendage-follow
// fix. Sub-part 3 adds `legHeight` — the leg geometry WO-20's gait swing
// will eventually animate (`legAngle` stays 0, a vertical rest pose, in
// this pass).

import CoreGraphics

enum SkeletonGeometry {

    // MARK: - Chest Pivot (spineChestNode placement)

    /// `spineChestNode` sits this fraction of the way from pelvis (0,0) to
    /// the stage's own authored head position — halfway, by proposal.
    /// Not yet visually ratified; a starting constant per the WO-19 plan.
    static let chestPivotFactor: CGFloat = 0.5

    /// `spineChestNode`'s position, relative to `pelvisNode` (i.e. in the
    /// same coordinate frame the OLD flat-sibling `head.position` was
    /// authored in, since pelvis sits at that frame's origin).
    static func spineChestPosition(oldHeadPosition: CGPoint) -> CGPoint {
        CGPoint(x: oldHeadPosition.x * chestPivotFactor,
                y: oldHeadPosition.y * chestPivotFactor)
    }

    // MARK: - Proportional Appendage-Follow (WO-19 sub-part 2)

    /// The TOTAL fraction of `pose.zRotation` the chest/head should carry,
    /// relative to pelvis — NOT an additive extra on top of the 100%
    /// `spineChestNode` already inherits via SpriteKit parent-child
    /// propagation. Since inheritance alone already delivers 100%, reaching
    /// a total of `chestFollowFactor` requires a COMPENSATING (negative,
    /// for factor < 1.0) write: `chestCurve = pose.zRotation *
    /// (chestFollowFactor - 1.0)`. factor=1.0 -> no extra write needed
    /// (inheritance alone is already exactly right); factor=0.9 -> chest
    /// writes -0.1x, so chest/head trail the torso by 10% (a natural,
    /// slightly-lagging read); factor can never make the composed total
    /// EXCEED pelvis's own rotation, by construction (deliberately fixing
    /// the earlier additive version's over-rotation bug — see the
    /// REVISE dispatch: additive +0.3 on top of inherited 100% pushed
    /// roll_side's composed head rotation to 130% of the torso's, 24deg
    /// PAST it).
    ///
    /// A single global constant, not a per-bodyState table — Rook endorsed
    /// this as rung-b's correct minimal form. Starting value, not yet
    /// visually ratified; tune later against the parade re-run.
    static let chestFollowFactor: CGFloat = 0.9

    // MARK: - Belt Line (shoulder/hip pivot Y)

    /// Shoulder/hip pivot Y, relative to pelvis center, as a fraction of
    /// the stage's own nominal body height (`StageConfiguration.size.height`
    /// — the nominal config height, not the trait-scaled runtime height;
    /// this is a deliberate simplification, safe because the rest-position
    /// re-basing math below cancels out any imprecision in this value
    /// exactly — see the WO-19 plan's §"gate-1 is trivially satisfiable by
    /// construction" note. Only the joint's own (currently invisible, inert)
    /// resting depth is affected, not any part's world position.
    static let beltYFraction: CGFloat = -0.25

    static func beltY(stageHeight: CGFloat) -> CGFloat {
        stageHeight * beltYFraction
    }

    // MARK: - Leg Height (WO-19 sub-part 3)

    /// The paw's existing rest Y as a fraction of stage height — mirrors
    /// `ShapeFactory.pawRestPositions`'s `groundY = -h * 0.4` exactly
    /// (unchanged, still the single source of truth for where a paw
    /// actually rests). Kept here only so `legHeight` below can DERIVE
    /// its span rather than hand-picking a second, independently-authored
    /// number that could drift out of sync with where the paw really is.
    static let groundYFraction: CGFloat = -0.40

    /// The leg's length: the vertical distance from the shoulder/hip pivot
    /// (`beltY`, the higher/less-negative point) down to the paw's rest Y
    /// (`groundYFraction`, the lower/more-negative point) —
    /// `legHeight = beltY - groundY` (belt minus ground, so the result is
    /// positive; `ShapeFactory.makePaw`'s `legHeight` parameter draws the
    /// leg polygon rising from the paw's local origin toward positive Y,
    /// so it must be positive to point the right way).
    ///
    /// `= stageHeight * (beltYFraction - groundYFraction)`
    /// `= stageHeight * (-0.25 - (-0.40))`
    /// `= stageHeight * 0.15`
    ///
    /// The 15% figure is the midpoint of `creature-visual-design.md`'s
    /// Chibi Proportion guideline ("legs 10-20% of total height" —
    /// explicitly marked design-intent, not directly verifiable against
    /// current code) — a ship-and-tune starting constant, not a ratified
    /// number; flagging the citation here so WO-12 (leg/paw geometry
    /// restyling) inherits it rather than re-deriving from scratch.
    ///
    /// Because this uses the EXACT SAME `beltY`/`groundYFraction` constants
    /// (and the same nominal `StageConfiguration.size.height`, not the
    /// trait-scaled runtime height — see `beltY`'s own doc comment for why
    /// that's a safe simplification) that sub-part 1's `addBodyParts`
    /// already used to place the shoulder/hip joints and re-base each paw
    /// under them, the leg drawn at this height is GUARANTEED (not just
    /// expected) to bridge exactly from the paw to the pivot's own local
    /// origin — see `SkeletonRigLegGeometryTests` for the proof.
    static func legHeight(for stage: GrowthStage) -> CGFloat {
        guard let stageHeight = StageConfiguration.all[stage]?.size.height else { return 0 }
        return stageHeight * (beltYFraction - groundYFraction)
    }

    // MARK: - Generic Re-Base Helper

    /// The re-basing subtraction Correction 1 requires for every reparented
    /// child: `newLocalPosition = oldAbsolutePosition - jointAbsolutePosition`,
    /// so the child's effective absolute (world-at-rest) position is
    /// unchanged regardless of where the new joint node was placed.
    static func rebase(_ oldAbsolutePosition: CGPoint,
                        relativeTo jointAbsolutePosition: CGPoint) -> CGPoint {
        CGPoint(x: oldAbsolutePosition.x - jointAbsolutePosition.x,
                y: oldAbsolutePosition.y - jointAbsolutePosition.y)
    }
}
