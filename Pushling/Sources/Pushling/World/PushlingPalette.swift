// PushlingPalette.swift — 8-color P3 palette for Pushling
// These are the ONLY colors used in the entire visual system.
// All colors are Display P3 for the OLED Touch Bar's wide gamut.
//
// P3-T3-01: Palette enforcement. Every visible pixel uses one of these 8 colors
// (or an alpha blend of one against Void). No exceptions.

import SpriteKit

// MARK: - P3 Palette

enum PushlingPalette {

    /// OLED pixels OFF — true black background.
    static let void_ = SKColor(displayP3Red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

    /// Creature body — warm white, reserves pure white for emphasis.
    static let bone = SKColor(displayP3Red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0)

    /// Fire accents, warnings, anger flush.
    static let ember = SKColor(displayP3Red: 1.0, green: 0.302, blue: 0.0, alpha: 1.0)

    /// Terrain, health indicators, contentment glow.
    static let moss = SKColor(displayP3Red: 0.0, green: 0.910, blue: 0.345, alpha: 1.0)

    /// Water, XP indicators, commit text, curiosity sparkle.
    static let tide = SKColor(displayP3Red: 0.0, green: 0.831, blue: 1.0, alpha: 1.0)

    /// Stars, milestones, evolution flash, speech bubbles.
    static let gilt = SKColor(displayP3Red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0)

    /// Night sky, magic effects, dream sequences.
    static let dusk = SKColor(displayP3Red: 0.482, green: 0.184, blue: 0.745, alpha: 1.0)

    /// Distant terrain, ghost echoes, whisper text.
    static let ash = SKColor(displayP3Red: 0.353, green: 0.353, blue: 0.353, alpha: 1.0)

    // MARK: - Derived Palette Colors (On-Palette Only)

    /// Deep Moss — darker moss for forest canopy. Moss blended toward Void.
    static let deepMoss = lerp(from: moss, to: void_, t: 0.3)

    /// Tongue/inner mouth — Ember softened toward Bone.
    static let softEmber = lerp(from: ember, to: bone, t: 0.4)

    // MARK: - All Palette Colors (for audit/debug)

    /// All 8 palette colors with their names, for debug palette audit.
    static let allColors: [(name: String, color: SKColor)] = [
        ("void", void_), ("bone", bone), ("ember", ember), ("moss", moss),
        ("tide", tide), ("gilt", gilt), ("dusk", dusk), ("ash", ash)
    ]

    // MARK: - Color Interpolation

    /// Linearly interpolate between two SKColors.
    /// - Parameters:
    ///   - from: Starting color
    ///   - to: Ending color
    ///   - t: Interpolation factor (0.0 = from, 1.0 = to), clamped to [0, 1]
    /// - Returns: Blended color in Display P3
    static func lerp(from: SKColor, to: SKColor, t: CGFloat) -> SKColor {
        let t = max(0, min(1, t))

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        // Convert to sRGB to avoid crash on grayscale colors (e.g. SKColor.black)
        let fromRGB = from.usingColorSpace(.sRGB) ?? from
        let toRGB = to.usingColorSpace(.sRGB) ?? to
        fromRGB.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        toRGB.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return SKColor(
            displayP3Red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }

    // MARK: - Alpha Variants

    /// Returns a palette color at the given alpha.
    /// The only permitted way to create transparent palette colors.
    static func withAlpha(_ color: SKColor, alpha: CGFloat) -> SKColor {
        return color.withAlphaComponent(max(0, min(1, alpha)))
    }

    // MARK: - Desaturation

    /// Desaturates a color by blending it toward Ash (gray).
    /// - Parameters:
    ///   - color: The source palette color
    ///   - amount: 0.0 = no change, 1.0 = fully desaturated to Ash
    /// - Returns: Desaturated color (still in P3 space)
    static func desaturate(_ color: SKColor, amount: CGFloat) -> SKColor {
        return lerp(from: color, to: ash, t: amount)
    }

    // MARK: - Atmospheric Perspective

    /// Applies atmospheric perspective: desaturates and reduces alpha for distant elements.
    /// - Parameters:
    ///   - color: The base palette color
    ///   - depth: 0.0 = foreground (no change), 1.0 = max distance (50% desat, 60% alpha)
    /// - Returns: Atmospheric-adjusted color
    static func atmosphericColor(_ color: SKColor, depth: CGFloat) -> SKColor {
        let d = max(0, min(1, depth))
        let desaturated = desaturate(color, amount: d * 0.5)
        return withAlpha(desaturated, alpha: 1.0 - d * 0.4)
    }

    // MARK: - Tinting

    /// Tints a color toward another palette color.
    /// Useful for biome-specific tinting of generic colors.
    /// - Parameters:
    ///   - base: The base palette color
    ///   - tint: The tint color to blend toward
    ///   - amount: 0.0 = pure base, 1.0 = pure tint
    /// - Returns: Tinted color in P3 space
    static func tint(_ base: SKColor, toward tint: SKColor, amount: CGFloat) -> SKColor {
        return lerp(from: base, to: tint, t: amount)
    }

    // MARK: - Stage Path Color

    /// Returns the primary palette color associated with a creature stage.
    /// Used for evolution progress bars, stage-specific UI accents.
    static func stageColor(for stage: GrowthStage) -> SKColor {
        switch stage {
        case .egg:   return bone
        case .drop:    return tide
        case .critter: return moss
        case .beast:   return ember
        case .sage:    return dusk
        case .apex:    return gilt
        }
    }

    // MARK: - Debug Palette Audit

    /// In debug builds, checks if a color is on-palette (or an alpha/blend variant).
    /// Logs a warning if the color doesn't match any palette entry.
    #if DEBUG
    static func auditColor(_ color: SKColor, context: String) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let colorRGB = color.usingColorSpace(.sRGB) ?? color
        colorRGB.getRed(&r, green: &g, blue: &b, alpha: &a)

        // Check against each palette color (ignoring alpha)
        for (name, paletteColor) in allColors {
            var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            let paletteRGB = paletteColor.usingColorSpace(.sRGB) ?? paletteColor
            paletteRGB.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)

            // Allow blends between palette colors — just warn if way off
            let dist = abs(r - pr) + abs(g - pg) + abs(b - pb)
            if dist < 0.05 {
                return  // Close enough to a palette color
            }
        }

        // Check if it's a blend between any two palette colors
        // (allow any lerp between palette colors)
        for (_, c1) in allColors {
            for (_, c2) in allColors {
                for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                    let blended = lerp(from: c1, to: c2, t: CGFloat(t))
                    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
                    let blendedRGB = blended.usingColorSpace(.sRGB) ?? blended
                    blendedRGB.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
                    let dist = abs(r - br) + abs(g - bg) + abs(b - bb)
                    if dist < 0.1 {
                        return  // Valid blend
                    }
                }
            }
        }

        NSLog("[Pushling/Palette] OFF-PALETTE color in %@: "
              + "R=%.3f G=%.3f B=%.3f A=%.3f", context, r, g, b, a)
    }
    #endif
}
