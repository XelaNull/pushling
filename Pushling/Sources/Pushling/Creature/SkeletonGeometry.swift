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

    // MARK: - Leg Height (WO-19 sub-part 3, REVISE — body-overlap fix)

    /// The paw's existing rest Y as a fraction of stage height — mirrors
    /// `ShapeFactory.pawRestPositions`'s `groundY = -h * 0.4` exactly
    /// (unchanged, still the single source of truth for where a paw
    /// actually rests). Kept here only so `legHeight` below can DERIVE
    /// its span rather than hand-picking a second, independently-authored
    /// number that could drift out of sync with where the paw really is.
    static let groundYFraction: CGFloat = -0.40

    /// **Diagnosis (Mack/human parade catch):** the ORIGINAL `legHeight`
    /// (`beltY - groundY` = 15% of stage height) put the leg's top exactly
    /// at the shoulder/hip PIVOT — but the pivot is not where the body's
    /// visual silhouette actually ends. Numerically sampling
    /// `CatShapes.catBody`'s belly-curve Bezier (200 steps per segment,
    /// not `CGPath.boundingBox`, which only bounds by CONTROL points and
    /// over-estimates how low the curve actually reaches) gives the TRUE
    /// rendered bottom edge, expressed as a fraction of stage height (this
    /// varies per stage because `bellyDrop` — CatShapes.catBody's belly-
    /// bulge parameter — differs: 0.12/0.12/0.10/0.08 for Critter/Beast/
    /// Sage/Apex, and does not reduce to one clean stage-independent
    /// formula the way `beltY`/`groundY` do):
    ///
    /// | Stage | body-bottom Y | vs. old leg-top (`beltY`) | gap |
    /// |---|---|---|---|
    /// | Critter | -3.65 (-0.2284h) | -4.00 | 0.35pt short |
    /// | Beast   | -4.19 (-0.2094h) | -5.00 | 0.81pt short |
    /// | Sage    | -4.48 (-0.1867h) | -6.00 | 1.52pt short |
    /// | Apex    | -5.13 (-0.1831h) | -7.00 | 1.87pt short |
    ///
    /// At every stage the old leg-top landed BELOW (more negative than,
    /// i.e. short of) the body's real bottom edge — a real, growing gap,
    /// not a rendering illusion — confirming the human's "legs not
    /// connected" read exactly.
    private static let bodyBottomYFraction: [GrowthStage: CGFloat] = [
        .critter: -0.2284,
        .beast:   -0.2094,
        .sage:    -0.1867,
        .apex:    -0.1831,
    ]

    /// The body's true rendered bottom edge (see the sampled-values table
    /// above) — exposed publicly, not just an internal `legHeight` detail,
    /// so WO-12 (or a test proving the overlap invariant) can read it
    /// directly instead of re-deriving/duplicating the sampled fractions.
    static func bodyBottomY(for stage: GrowthStage) -> CGFloat {
        guard let stageHeight = StageConfiguration.all[stage]?.size.height,
              let bottomFraction = bodyBottomYFraction[stage] else { return 0 }
        return stageHeight * bottomFraction
    }

    /// How far the leg's top must reach PAST the body's bottom edge, up
    /// INTO the body mass, to read as connected rather than merely
    /// touching (a leg terminating exactly at the silhouette edge still
    /// reads as detached at 2x Retina). A ship-and-tune starting constant
    /// — flagging here, not inline in the formula, so WO-12 can retune it
    /// without re-deriving the body-bottom sampling above.
    static let bodyOverlapConstant: CGFloat = 1.5

    /// The leg's length: from the paw's existing rest Y (`groundYFraction`,
    /// UNCHANGED — the human confirmed paws already read correctly, don't
    /// move them) up to the body's real bottom edge PLUS the overlap
    /// constant — no longer tied to `beltY` at all (the shoulder/hip pivot
    /// stays exactly where sub-part 1 put it; only the RENDERED leg now
    /// extends past it into the body — see `SkeletonRigLegGeometryTests`
    /// for the "overlaps, doesn't just bridge to the pivot" proof).
    ///
    /// `legHeight = (bodyBottomY + bodyOverlapConstant) - groundY`
    ///
    /// The 15% Chibi Proportion citation (`creature-visual-design.md`,
    /// design-intent) that sized the ORIGINAL `legHeight` no longer
    /// literally applies — the new lengths land around 26-28% of stage
    /// height (Critter 4.25/16=26.6%, Beast 5.31/20=26.6%, Sage
    /// 6.62/24=27.6%, Apex 7.57/28=27.0%), past that guideline's 10-20%
    /// range. Flagging this tension explicitly for WO-12 rather than
    /// silently exceeding a cited design number: "reads as connected" won
    /// out over the abstract percentage this pass.
    static func legHeight(for stage: GrowthStage) -> CGFloat {
        guard let stageHeight = StageConfiguration.all[stage]?.size.height else { return 0 }
        let groundY = stageHeight * groundYFraction
        return (bodyBottomY(for: stage) + bodyOverlapConstant) - groundY
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
