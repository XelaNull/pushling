// MoonPhase.swift — Moon node with real lunar phase calculation
// P3-T2-02: Small 3-4pt moon in the far layer showing correct phase shape.
// Visible at night periods. Phase rendered as a circle with shadow arc.
//
// Uses the Metonic cycle approximation — no ephemeris needed.
// Texture regenerated once per day (phase changes slowly).

import SpriteKit

// MARK: - Lunar Phase Calculator

/// Calculates the current lunar phase using a simplified synodic month model.
/// Accuracy: within ~1 day of actual phase. Good enough for a 3pt moon.
enum LunarPhase {

    /// Average length of a synodic month (new moon to new moon) in days.
    static let synodicMonth: Double = 29.53058770576

    /// A known new moon reference date: January 6, 2000 18:14 UTC.
    /// Julian Date: 2451550.26
    private static let referenceNewMoon: Double = 2451550.26

    /// Calculate the current lunar phase as a fraction (0.0 to 1.0).
    /// - 0.0 / 1.0 = New Moon
    /// - 0.25 = First Quarter
    /// - 0.5 = Full Moon
    /// - 0.75 = Last Quarter
    /// - Parameter date: The date to calculate for (defaults to now)
    /// - Returns: Phase fraction in [0.0, 1.0)
    static func phase(for date: Date = Date()) -> Double {
        let julianDate = julianDay(from: date)
        let daysSinceReference = julianDate - referenceNewMoon
        let cycles = daysSinceReference / synodicMonth
        let fraction = cycles - floor(cycles)
        return fraction
    }

    /// Convert a Date to Julian Day Number.
    private static func julianDay(from date: Date) -> Double {
        // Julian Day from Unix timestamp
        // Unix epoch (Jan 1 1970 00:00 UTC) = Julian Day 2440587.5
        let unixTime = date.timeIntervalSince1970
        return (unixTime / 86400.0) + 2440587.5
    }

    /// Illumination fraction (0.0 = new moon, 1.0 = full moon, then back to 0.0).
    /// Uses the formula: (1 - cos(2π × phase)) / 2
    static func illumination(for date: Date = Date()) -> Double {
        let p = phase(for: date)
        return (1.0 - cos(2.0 * .pi * p)) / 2.0
    }

    /// Whether the moon is waxing (getting brighter) or waning.
    static func isWaxing(for date: Date = Date()) -> Bool {
        return phase(for: date) < 0.5
    }

    /// A human-readable phase name (for debug/MCP).
    static func phaseName(for date: Date = Date()) -> String {
        let p = phase(for: date)
        switch p {
        case 0.0..<0.03, 0.97..<1.0:  return "new_moon"
        case 0.03..<0.22:              return "waxing_crescent"
        case 0.22..<0.28:              return "first_quarter"
        case 0.28..<0.47:              return "waxing_gibbous"
        case 0.47..<0.53:              return "full_moon"
        case 0.53..<0.72:              return "waning_gibbous"
        case 0.72..<0.78:              return "last_quarter"
        case 0.78..<0.97:              return "waning_crescent"
        default:                       return "new_moon"
        }
    }
}

// MARK: - Moon Phase Node

/// A 3x3pt moon node that renders the current lunar phase.
/// Positioned in the upper-right area of the far layer.
/// Phase texture is regenerated once per day.
final class MoonPhaseNode: SKNode {

    // MARK: - Constants

    /// Moon diameter in points.
    private static let moonSize: CGFloat = 3.0

    /// Texture size in pixels (rendered at 2x for Retina, but kept small).
    private static let texturePixels: Int = 8

    /// Position on the far layer (upper-right area).
    private static let basePosition = CGPoint(x: 950, y: 24)

    // MARK: - Child Nodes

    /// The sprite that displays the moon texture.
    private let moonSprite: SKSpriteNode

    // MARK: - State

    /// The date when the phase texture was last regenerated.
    private var lastTextureDate: Date?

    /// Current target alpha (from sky system).
    private var targetAlpha: CGFloat = 0

    // MARK: - Init

    override init() {
        moonSprite = SKSpriteNode(
            texture: nil,
            size: CGSize(width: Self.moonSize, height: Self.moonSize)
        )
        moonSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        super.init()

        position = Self.basePosition
        zPosition = -190  // In front of sky gradient, behind mid layer
        alpha = 0  // Start hidden — sky system controls visibility

        addChild(moonSprite)

        // Generate initial texture
        regenerateTexture()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    // MARK: - Visibility

    /// Update moon visibility based on time period.
    /// Called by SkySystem every second.
    func updateVisibility(alpha nightAlpha: CGFloat, period: TimePeriod) {
        targetAlpha = period.moonVisible ? nightAlpha : 0

        // Smooth approach to target alpha
        let current = self.alpha
        let diff = targetAlpha - current
        if abs(diff) > 0.01 {
            self.alpha = current + diff * 0.1  // Ease toward target
        } else {
            self.alpha = targetAlpha
        }

        // Check if texture needs regeneration (once per calendar day)
        checkTextureDate()
    }

    // MARK: - Phase Texture

    /// Check if the calendar day has changed and regenerate the moon texture.
    private func checkTextureDate() {
        let now = Date()

        if let lastDate = lastTextureDate {
            let calendar = Calendar.current
            if calendar.isDate(lastDate, inSameDayAs: now) {
                return  // Same day — no regeneration needed
            }
        }

        regenerateTexture()
    }

    /// Regenerate the moon phase texture.
    /// Renders a circle with a shadow arc based on the current phase.
    private func regenerateTexture() {
        let now = Date()
        lastTextureDate = now

        let size = Self.texturePixels
        let phase = LunarPhase.phase(for: now)
        let illumination = LunarPhase.illumination(for: now)
        let waxing = LunarPhase.isWaxing(for: now)

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let center = Double(size) / 2.0
        let radius = center - 0.5

        // Moon body color: Bone
        let bodyR: UInt8 = 245  // 0xF5
        let bodyG: UInt8 = 240  // 0xF0
        let bodyB: UInt8 = 232  // 0xE8

        // Shadow color: Ash (dark side of moon)
        let shadowR: UInt8 = 40
        let shadowG: UInt8 = 40
        let shadowB: UInt8 = 40

        for y in 0..<size {
            for x in 0..<size {
                let dx = Double(x) - center + 0.5
                let dy = Double(y) - center + 0.5
                let dist = sqrt(dx * dx + dy * dy)

                // Outside circle — transparent
                guard dist <= radius else { continue }

                // Determine if this pixel is illuminated based on phase
                // The terminator is an ellipse — its X-radius varies with phase
                let normalizedX = dx / radius  // -1 to 1

                // terminatorX: the X boundary of the shadow
                // For new moon (phase~0): whole face is dark
                // For full moon (phase~0.5): whole face is lit
                let terminatorX: Double
                if phase < 0.5 {
                    // Waxing: illuminated part grows from the right
                    terminatorX = cos(phase * 2.0 * .pi)
                } else {
                    // Waning: shadow grows from the right
                    terminatorX = cos(phase * 2.0 * .pi)
                }

                let isLit: Bool
                if waxing {
                    // Waxing: right side lights up first
                    isLit = normalizedX >= terminatorX
                } else {
                    // Waning: right side darkens first
                    isLit = normalizedX <= -terminatorX
                }

                let offset = (y * size + x) * 4
                if isLit {
                    pixels[offset] = bodyR
                    pixels[offset + 1] = bodyG
                    pixels[offset + 2] = bodyB
                    pixels[offset + 3] = 255
                } else {
                    // Shadow side — very faint, suggesting the dark part of the moon
                    let shadowAlpha: UInt8 = illumination < 0.1 ? 30 : 80
                    pixels[offset] = shadowR
                    pixels[offset + 1] = shadowG
                    pixels[offset + 2] = shadowB
                    pixels[offset + 3] = shadowAlpha
                }
            }
        }

        let data = Data(pixels)
        let texture = SKTexture(
            data: data,
            size: CGSize(width: size, height: size)
        )
        texture.filteringMode = .nearest  // Crisp pixel edges at small size
        moonSprite.texture = texture
    }

    // MARK: - Full Moon Check

    /// Returns true if the moon is approximately full (for surprise system hook).
    var isFullMoon: Bool {
        let illumination = LunarPhase.illumination()
        return illumination > 0.95
    }

    /// Current phase name (for MCP state queries).
    var phaseName: String {
        return LunarPhase.phaseName()
    }
}
