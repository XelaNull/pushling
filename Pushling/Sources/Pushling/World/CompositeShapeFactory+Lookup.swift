// CompositeShapeFactory+Lookup.swift — Preset-to-composite dispatcher
// Maps object preset names and base shapes to the appropriate composite builder.
// Called by WorldObjectRenderer.buildNode and TerrainObjectNodeFactory.

import SpriteKit

// MARK: - Composite Lookup

extension CompositeShapeFactory {

    /// Attempts to build a composite shape for the given preset name and base shape.
    /// Returns nil if no composite is available (caller falls back to single-shape).
    ///
    /// - Parameters:
    ///   - presetName: The object's preset name (e.g., "campfire", "cozy_bed").
    ///   - baseShape: The base shape string (e.g., "triangle", "dome").
    ///   - size: Scale factor (typically 0.5-2.0, default 1.0).
    /// - Returns: An SKNode container with composite children, or nil.
    static func buildCompositeShape(
        presetName: String,
        baseShape: String,
        size: CGFloat
    ) -> SKNode? {
        let name = presetName.lowercased()

        // Check preset name first (most specific).
        // Order matters: more specific names (e.g., "yarn_ball") before generic ("ball").
        if name.contains("campfire") {
            return buildCampfire(size: size)
        } else if name.contains("tree") {
            return buildTree(size: size)
        } else if name.contains("flower") {
            return buildFlower(size: size)
        } else if name.contains("mushroom") {
            return buildMushroom(size: size)
        } else if name.contains("fish") {
            return buildFish(size: size)
        } else if name.contains("cozy_bed") || name.contains("bed") {
            return buildCozyBed(size: size)
        } else if name.contains("scratching_post") || name.contains("scratch") {
            return buildScratchingPost(size: size)
        } else if name.contains("cardboard_box") {
            return buildCardboardBox(size: size)
        } else if name.contains("music_box") {
            return buildMusicBox(size: size)
        } else if name.contains("lantern") {
            return buildLantern(size: size)
        } else if name.contains("crystal") {
            return buildCrystal(size: size)
        } else if name.contains("yarn_ball") || name.contains("yarn") {
            return buildBall(size: size, includeThread: true)
        } else if name.contains("ball") {
            return buildBall(size: size, includeThread: false)
        } else if name.contains("fountain") {
            return buildFountain(size: size)
        } else if name.contains("milk") || name.contains("saucer") {
            return buildMilkSaucer(size: size)
        } else if name.contains("treat") {
            return buildTreat(size: size)
        } else if name.contains("mirror") {
            return buildLittleMirror(size: size)
        } else if name.contains("rock") {
            return buildRock(size: size)
        } else if name.contains("bench") {
            return buildBench(size: size)
        } else if name.contains("flag") {
            return buildFlag(size: size)
        } else if name.contains("candle") {
            return buildCandle(size: size)
        }

        // Fall back to base shape for broader matches
        switch baseShape {
        case "spr_bed":
            return buildCozyBed(size: size)
        case "spr_pillar":
            return buildScratchingPost(size: size)
        case "spr_music_box":
            return buildMusicBox(size: size)
        case "spr_lantern":
            return buildLantern(size: size)
        case "spr_crystal":
            return buildCrystal(size: size)
        case "spr_yarn_ball":
            return buildBall(size: size, includeThread: true)
        case "spr_fountain":
            return buildFountain(size: size)
        case "spr_mirror":
            return buildLittleMirror(size: size)
        case "spr_candle":
            return buildCandle(size: size)
        default:
            return nil
        }
    }
}
