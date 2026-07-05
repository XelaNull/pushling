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

import CoreGraphics
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

    /// Whether this stage's CURRENT baked model already draws its own
    /// tail in the sprite frame — i.e. the L2 `SegmentedTailController`
    /// overlay would be a pure visual duplicate ("chimera": double tail),
    /// not a legitimate part filling in for a face-neutral/limb-neutral
    /// baked body. Model ①'s Beast bake is exactly this case: a complete
    /// realistic render whose particle-fur tail is baked into the body
    /// mesh and confirmed NON-separable at bake time
    /// (`bake-manifest.json`'s `tail_separable: false` /
    /// `has_particle_fur: true` — there was never a `*tail*` object to
    /// hide out of the render in the first place).
    ///
    /// Deliberately per-STAGE, not per-model — this codebase bakes and
    /// ships exactly one live model per stage at a time (mirrors
    /// `isEligible(stage:)`'s own shape), so "the current Beast bake" and
    /// "model ①" are the same thing today. If a FUTURE Beast (or Sage/
    /// Apex) bake ships with a face-neutral/tail-neutral body and a
    /// genuinely separable tail object, flip this stage's case back to
    /// `false` to re-enable the L2 overlay — that's a data change here,
    /// not a code change at either call site (`CreatureNode.addBodyParts`
    /// / `createControllers`), which both just read this function.
    static func tailIsBakedIntoSprite(stage: GrowthStage) -> Bool {
        switch stage {
        case .beast:
            return true
        case .egg, .drop, .critter, .sage, .apex:
            return false
        }
    }

    /// FIX 2 (post-deploy, REVISED per the tight re-bake's measured bbox) —
    /// the sprite path's on-screen DISPLAY height for the FULL 36x40
    /// texture FRAME, deliberately NOT `StageConfiguration.size.height`
    /// itself. `StageConfiguration.size` still drives vector-mode geometry
    /// (paw rest positions, belt line, ear/eye offsets via `w`/`h`)
    /// exactly as before — overriding it directly would ripple into
    /// flag-off, which must stay byte-identical.
    ///
    /// This is NOT the cat's own on-screen height — the tight re-bake's
    /// frames are ~86-94% cat by WIDTH but only ~40-60% cat by HEIGHT
    /// (idle ~42%, walk ~60%, run ~40%): a realistic side-view cat is
    /// wider than tall, so ~40% of every frame's vertical extent is
    /// transparent margin (roughly 20% top + 20% bottom) that can't be
    /// cropped without cutting off the nose or tail or distorting the
    /// aspect ratio. Sizing the FRAME to the Touch Bar strip's 30pt
    /// (`TouchTracker.sceneHeight`) would size the CAT to only
    /// ~30 * 0.6 ≈ 18pt at best (worse for idle/run) — still the ~10pt-
    /// ish "distant cat" look a human flagged, just less extreme.
    /// Sizing the FRAME to `targetCatHeight / catFractionOfFrameHeight`
    /// (28 / 0.6 ≈ 46.7, using the walk clip's larger fraction as the
    /// representative baseline) instead lets the frame's transparent
    /// margin overflow past the strip's edges — SpriteKit itself clips
    /// nothing, but the Touch Bar host view's bounds do, so the overflow
    /// is invisible — while the CAT itself (vertically centered in the
    /// frame by the bake) reads ~26-28pt tall on the 30pt strip. One
    /// display box per stage, not per-clip (matching the architecture
    /// everywhere else this codebase sizes a sprite), so idle/run read
    /// slightly smaller than walk at this same box size — an accepted
    /// approximation, not a per-clip resize.
    static let spriteDisplayHeight: CGFloat = 46.0

    /// Scales `configSize` (a `StageConfiguration.size`) so its height
    /// matches `spriteDisplayHeight` (the FRAME's on-screen height, per
    /// the doc comment above — NOT the cat's own height), preserving
    /// aspect ratio so the bake's proportions aren't stretched. Pure and
    /// stage-agnostic — every sprite-eligible stage gets the same
    /// fill-the-strip treatment once it has its own baked frames, not
    /// just Beast.
    static func spriteDisplaySize(fromConfigSize configSize: CGSize) -> CGSize {
        guard configSize.height > 0 else { return configSize }
        let scale = spriteDisplayHeight / configSize.height
        return CGSize(width: configSize.width * scale, height: spriteDisplayHeight)
    }
}
