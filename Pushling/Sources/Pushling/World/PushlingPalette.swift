// PushlingPalette.swift — 8-color P3 palette for Pushling
// These are the ONLY colors used in the entire visual system.
// All colors are Display P3 for the OLED Touch Bar's wide gamut.

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
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return SKColor(
            displayP3Red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
