// SpriteBodyMode.swift — WO-27 sub-part 1: the sprite-runtime feature flag.
// Mirrors WorkbenchMode.swift's ProcessInfo-gated pattern EXACTLY — same
// detection mechanism, same "off by default, coexists safely" philosophy.
//
// Enabled via: pushling --sprite-body   OR   PUSHLING_SPRITE_BODY=1
//
// Per the animation-architecture-master-plan (P0-signed WO-27 plan §1/§4):
// the sprite body (one SKSpriteNode playing baked atlas frames) replaces
// today's vector part-tree ONLY for Critter/Beast/Sage/Apex — Egg/Drop's
// existing trivial 2-3-shape vector bodies stay vector FOREVER (ratified,
// not this flag's call to make). `isEligible(stage:)` encodes that gate
// once, here, so every future call site (ClipTable, CreatureNode's
// eventual sub-part-2 render-path switch) asks this instead of repeating
// the stage check inline.
//
// Sub-part 1 (this file + ClipTable.swift + SpriteFrameLoader.swift)
// deliberately produces ZERO visible render change: `isEnabled` exists,
// is checked nowhere in CreatureNode's actual render path yet, and
// defaults to false regardless. Sub-part 2 is the wiring; this is the
// scaffolding it will wire into.

import Foundation

enum SpriteBodyMode {

    /// Whether the sprite-body render path is enabled. False by default —
    /// the live vector creature is provably unaffected unless this flag
    /// is explicitly passed, exactly matching WorkbenchMode.isActive's
    /// "off unless asked" contract.
    static var isEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--sprite-body") {
            return true
        }
        return ProcessInfo.processInfo.environment["PUSHLING_SPRITE_BODY"] == "1"
    }

    /// Whether a given growth stage is eligible for the sprite body path.
    /// Egg/Drop are NEVER eligible, regardless of `isEnabled` — their
    /// existing vector bodies (a single ellipse/teardrop, per
    /// StageRenderer.buildEgg/buildDrop) are too trivial to be worth
    /// baking and are excluded by the ratified master plan itself
    /// (§5 P4 row: "Egg/Drop keep 2-3 shapes"), not a scope decision this
    /// flag is making on its own.
    static func isEligible(stage: GrowthStage) -> Bool {
        switch stage {
        case .egg, .drop:
            return false
        case .critter, .beast, .sage, .apex:
            return true
        }
    }
}
