// SkySystem.swift — Real-time sky gradient driven by wall clock
// P3-T2-01: 8 time periods with 10-minute transitions between them.
// Renders as a full-width background node on the Far layer.
//
// Time periods: deep_night, dawn, morning, day, golden_hour, dusk, evening, late_night
// Sky gradient uses Void, Dusk, Ember, Tide, Bone from the 8-color P3 palette.
// Update frequency: once per second (every 60 frames) — sufficient for smooth visual.

import SpriteKit

// MARK: - Time Period

/// The 8 sky time periods mapped to wall clock hours.
enum TimePeriod: String, CaseIterable {
    case deepNight   = "deep_night"
    case dawn        = "dawn"
    case morning     = "morning"
    case day         = "day"
    case goldenHour  = "golden_hour"
    case dusk        = "dusk"
    case evening     = "evening"
    case lateNight   = "late_night"

    /// Start time in hours (fractional). The period runs from this until the next period starts.
    var startHour: Double {
        switch self {
        case .deepNight:  return 0.0    // 00:00
        case .dawn:       return 4.5    // 04:30
        case .morning:    return 6.0    // 06:00
        case .day:        return 9.0    // 09:00
        case .goldenHour: return 16.0   // 16:00
        case .dusk:       return 18.0   // 18:00
        case .evening:    return 19.5   // 19:30
        case .lateNight:  return 22.0   // 22:00
        }
    }

    /// The next time period in sequence (wraps around).
    var next: TimePeriod {
        switch self {
        case .deepNight:  return .dawn
        case .dawn:       return .morning
        case .morning:    return .day
        case .day:        return .goldenHour
        case .goldenHour: return .dusk
        case .dusk:       return .evening
        case .evening:    return .lateNight
        case .lateNight:  return .deepNight
        }
    }

    /// Sky gradient colors: (topColor, bottomColor).
    /// Uses only palette colors: Void, Dusk, Ember, Tide, Bone.
    var skyColors: (top: SKColor, bottom: SKColor) {
        switch self {
        case .deepNight:
            // Void -> deep Dusk
            return (PushlingPalette.void_, PushlingPalette.dusk.withAlphaComponent(0.3))
        case .dawn:
            // Dusk -> soft Ember horizon
            return (PushlingPalette.dusk.withAlphaComponent(0.6), PushlingPalette.ember.withAlphaComponent(0.4))
        case .morning:
            // Ember horizon -> light Tide wash
            return (PushlingPalette.ember.withAlphaComponent(0.3), PushlingPalette.tide.withAlphaComponent(0.2))
        case .day:
            // Faint Tide at top, Bone-tinted horizon
            return (PushlingPalette.tide.withAlphaComponent(0.15), PushlingPalette.bone.withAlphaComponent(0.1))
        case .goldenHour:
            // Gilt wash -> warm Ember
            return (PushlingPalette.gilt.withAlphaComponent(0.3), PushlingPalette.ember.withAlphaComponent(0.35))
        case .dusk:
            // Ember -> deep Dusk
            return (PushlingPalette.ember.withAlphaComponent(0.25), PushlingPalette.dusk.withAlphaComponent(0.6))
        case .evening:
            // Dusk -> near-Void
            return (PushlingPalette.dusk.withAlphaComponent(0.5), PushlingPalette.void_)
        case .lateNight:
            // Void with faint Dusk at horizon
            return (PushlingPalette.void_, PushlingPalette.dusk.withAlphaComponent(0.15))
        }
    }

    /// Whether stars should be visible during this period.
    var starsVisible: Bool {
        switch self {
        case .deepNight, .lateNight, .evening: return true
        case .dawn, .dusk:                     return true  // Fading in/out
        case .morning, .day, .goldenHour:      return false
        }
    }

    /// Whether the moon should be visible during this period.
    var moonVisible: Bool {
        switch self {
        case .deepNight, .lateNight, .evening: return true
        case .dawn:                            return true  // Fading out
        case .dusk:                            return true  // Appearing
        case .morning, .day, .goldenHour:      return false
        }
    }

    /// Alpha multiplier for night elements (stars, moon) based on period.
    /// 1.0 = full brightness, 0.0 = invisible.
    var nightAlpha: CGFloat {
        switch self {
        case .deepNight:  return 1.0
        case .lateNight:  return 0.9
        case .evening:    return 0.7
        case .dusk:       return 0.3
        case .dawn:       return 0.2
        case .morning:    return 0.0
        case .day:        return 0.0
        case .goldenHour: return 0.0
        }
    }
}

// MARK: - Sky Gradient Node

/// A node that renders a vertical 2-color gradient across the full scene width.
/// Uses a pre-rendered texture for efficiency (updated only when colors change).
final class SkyGradientNode: SKSpriteNode {

    private var currentTopColor: SKColor = .clear
    private var currentBottomColor: SKColor = .clear

    /// Scene dimensions.
    private let sceneWidth: CGFloat
    private let sceneHeight: CGFloat

    init(sceneWidth: CGFloat, sceneHeight: CGFloat) {
        self.sceneWidth = sceneWidth
        self.sceneHeight = sceneHeight

        super.init(texture: nil, color: .clear, size: CGSize(width: sceneWidth, height: sceneHeight))
        anchorPoint = CGPoint(x: 0, y: 0)
        zPosition = -200  // Behind everything on the far layer
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    /// Update the gradient colors. Only regenerates texture if colors actually changed.
    func updateGradient(topColor: SKColor, bottomColor: SKColor) {
        // Skip texture regeneration if colors haven't changed meaningfully
        guard !colorsMatch(topColor, currentTopColor) ||
              !colorsMatch(bottomColor, currentBottomColor) else {
            return
        }

        currentTopColor = topColor
        currentBottomColor = bottomColor

        // Render gradient to a texture (2px wide is sufficient — SpriteKit stretches)
        let textureWidth = 2
        let textureHeight = Int(sceneHeight)
        let bytesPerPixel = 4
        let bytesPerRow = textureWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: textureHeight * bytesPerRow)

        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        topColor.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        bottomColor.getRed(&br, green: &bg, blue: &bb, alpha: &ba)

        for y in 0..<textureHeight {
            // t = 0 at bottom (y=0), t = 1 at top (y=height-1)
            let t = CGFloat(y) / CGFloat(max(1, textureHeight - 1))
            let r = UInt8(max(0, min(255, (br + (tr - br) * t) * 255)))
            let g = UInt8(max(0, min(255, (bg + (tg - bg) * t) * 255)))
            let b = UInt8(max(0, min(255, (bb + (tb - bb) * t) * 255)))
            let a = UInt8(max(0, min(255, (ba + (ta - ba) * t) * 255)))

            for x in 0..<textureWidth {
                let offset = ((textureHeight - 1 - y) * bytesPerRow) + (x * bytesPerPixel)
                pixels[offset] = r
                pixels[offset + 1] = g
                pixels[offset + 2] = b
                pixels[offset + 3] = a
            }
        }

        let data = Data(pixels)
        let texture = SKTexture(
            data: data,
            size: CGSize(width: textureWidth, height: textureHeight)
        )
        texture.filteringMode = .linear
        self.texture = texture
    }

    /// Check if two colors are close enough to skip re-rendering.
    private func colorsMatch(_ a: SKColor, _ b: SKColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let threshold: CGFloat = 0.005
        return abs(r1 - r2) < threshold &&
               abs(g1 - g2) < threshold &&
               abs(b1 - b2) < threshold &&
               abs(a1 - a2) < threshold
    }
}

// MARK: - Sky System

/// Manages the real-time sky gradient, moon, and star field.
/// Updates once per second. Owns the sky gradient node and coordinates
/// the MoonPhaseNode and StarFieldNode.
final class SkySystem {

    // MARK: - Constants

    /// Scene dimensions (Touch Bar)
    static let sceneWidth: CGFloat = 1085
    static let sceneHeight: CGFloat = 30

    /// Duration of transitions between time periods, in seconds.
    static let transitionDuration: TimeInterval = 600  // 10 minutes

    /// Frames between sky updates (60 frames = 1 second at 60fps).
    private static let updateInterval = 60

    // MARK: - Nodes

    /// The sky gradient background node.
    let gradientNode: SkyGradientNode

    /// The moon node (owned by SkySystem, positioned on the far layer).
    let moonNode: MoonPhaseNode

    /// The star field node (owned by SkySystem, positioned on the far layer).
    let starField: StarFieldNode

    // MARK: - State

    /// Current time period (computed from wall clock).
    private(set) var currentPeriod: TimePeriod = .day

    /// Interpolation factor within current transition (0.0 = start of period, 1.0 = end).
    private(set) var transitionFactor: CGFloat = 0

    /// Frame counter for throttled updates.
    private var frameCounter = 0

    /// Optional override: if set, use this hour instead of wall clock.
    var timeOverrideHour: Double?

    /// Weather-driven sky overlay alpha (storm darkening, etc.)
    private var weatherDarkenAlpha: CGFloat = 0
    private var weatherDarkenColor: SKColor = PushlingPalette.void_

    // MARK: - Init

    init() {
        gradientNode = SkyGradientNode(
            sceneWidth: Self.sceneWidth,
            sceneHeight: Self.sceneHeight
        )
        moonNode = MoonPhaseNode()
        starField = StarFieldNode()

        // Force an immediate update
        updateSky()
    }

    // MARK: - Frame Update

    /// Called every frame from the scene's update loop.
    /// Only recalculates the sky every ~1 second for efficiency.
    func update(deltaTime: TimeInterval) {
        frameCounter += 1

        if frameCounter >= Self.updateInterval {
            frameCounter = 0
            updateSky()
        }

        // Star twinkle runs every frame (lightweight alpha oscillation)
        starField.updateTwinkle(deltaTime: deltaTime)
    }

    // MARK: - Sky Calculation

    /// Recalculate sky colors from current wall clock time.
    private func updateSky() {
        let hour = timeOverrideHour ?? currentHourFraction()
        let (period, factor) = computePeriodAndFactor(hour: hour)

        currentPeriod = period
        transitionFactor = factor

        // Interpolate sky colors between current period and next
        let currentColors = period.skyColors
        let nextColors = period.next.skyColors

        var topColor = PushlingPalette.lerp(from: currentColors.top, to: nextColors.top, t: factor)
        var bottomColor = PushlingPalette.lerp(from: currentColors.bottom, to: nextColors.bottom, t: factor)

        // Apply weather darkening if active
        if weatherDarkenAlpha > 0 {
            topColor = PushlingPalette.lerp(from: topColor, to: weatherDarkenColor, t: weatherDarkenAlpha)
            bottomColor = PushlingPalette.lerp(from: bottomColor, to: weatherDarkenColor, t: weatherDarkenAlpha)
        }

        gradientNode.updateGradient(topColor: topColor, bottomColor: bottomColor)

        // Update night element visibility
        let nightAlpha = interpolatedNightAlpha(period: period, factor: factor)
        moonNode.updateVisibility(alpha: nightAlpha, period: period)
        starField.updateVisibility(alpha: nightAlpha)
    }

    /// Get the current hour as a fractional value (e.g., 14.5 = 2:30 PM).
    private func currentHourFraction() -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let hour = Double(components.hour ?? 12)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        return hour + minute / 60.0 + second / 3600.0
    }

    /// Compute which time period we're in and how far through the transition to the next.
    /// - Parameter hour: Fractional hour (0.0 - 23.999)
    /// - Returns: (currentPeriod, transitionFactor 0.0-1.0)
    private func computePeriodAndFactor(hour: Double) -> (TimePeriod, CGFloat) {
        let periods = TimePeriod.allCases
        let transitionHours = Self.transitionDuration / 3600.0  // 10 min = 0.1667 hours

        for i in 0..<periods.count {
            let current = periods[i]
            let next = periods[(i + 1) % periods.count]
            let currentStart = current.startHour
            var nextStart = next.startHour

            // Handle midnight wrap
            if nextStart <= currentStart {
                nextStart += 24.0
            }

            var h = hour
            if h < currentStart && currentStart > 20 {
                h += 24.0
            }

            if h >= currentStart && h < nextStart {
                let periodDuration = nextStart - currentStart
                let elapsed = h - currentStart

                // Transition starts at (periodDuration - transitionHours) into the period
                let transitionStart = periodDuration - transitionHours
                if elapsed >= transitionStart {
                    let t = (elapsed - transitionStart) / transitionHours
                    return (current, CGFloat(min(1.0, t)))
                } else {
                    return (current, 0.0)
                }
            }
        }

        // Fallback (shouldn't reach here)
        return (.day, 0.0)
    }

    /// Interpolate night alpha between current period and next.
    private func interpolatedNightAlpha(period: TimePeriod, factor: CGFloat) -> CGFloat {
        let current = period.nightAlpha
        let next = period.next.nightAlpha
        return current + (next - current) * factor
    }

    // MARK: - Weather Integration

    /// Apply a darkening overlay from the weather system.
    /// - Parameters:
    ///   - alpha: How much to darken (0.0 = no change, 1.0 = full dark)
    ///   - color: The darkening color (e.g., near-Void for storms)
    func applyWeatherDarkening(alpha: CGFloat, color: SKColor) {
        weatherDarkenAlpha = max(0, min(1, alpha))
        weatherDarkenColor = color
    }

    /// Add all sky nodes as children of the given parent (far layer).
    func addToScene(parent: SKNode) {
        parent.addChild(gradientNode)
        parent.addChild(moonNode)
        parent.addChild(starField)
    }
}
