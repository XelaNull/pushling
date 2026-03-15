// LayerTypes.swift — Foundation types for the 4-layer behavior stack
// Pure data structures and utility functions. No side effects.
//
// The behavior stack produces a DesiredCreatureState each frame.
// The blend controller interpolates toward it. The creature node applies it.

import Foundation
import CoreGraphics

// MARK: - Direction

/// Horizontal facing direction for the creature.
enum Direction: String, Codable {
    case left
    case right

    /// The opposite direction.
    var flipped: Direction {
        self == .left ? .right : .left
    }

    /// X-scale multiplier for sprite facing (1.0 = right, -1.0 = left).
    var xScale: CGFloat {
        self == .right ? 1.0 : -1.0
    }
}

// MARK: - Growth Stage (Behavior-Relevant Subset)

/// Growth stage gates for behavior availability.
/// Mirrors Schema.validStages but as a Comparable enum for gate checks.
enum GrowthStage: Int, Comparable, CaseIterable, Codable {
    case spore = 0
    case drop = 1
    case critter = 2
    case beast = 3
    case sage = 4
    case apex = 5

    static func < (lhs: GrowthStage, rhs: GrowthStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Base walk speed in points per second for this stage.
    var baseWalkSpeed: CGFloat {
        switch self {
        case .spore:   return 0      // Spore floats, doesn't walk
        case .drop:    return 8
        case .critter: return 15
        case .beast:   return 25
        case .sage:    return 20
        case .apex:    return 22
        }
    }

    /// Base run speed in points per second for this stage.
    var baseRunSpeed: CGFloat {
        switch self {
        case .spore:   return 0
        case .drop:    return 0       // Drop can't run
        case .critter: return 30
        case .beast:   return 50
        case .sage:    return 40
        case .apex:    return 45
        }
    }
}

// MARK: - Layer Output

/// Each layer produces a LayerOutput per frame.
/// nil properties mean "I have no opinion — defer to lower layers."
/// Breathing is NOT here — it's hardcoded in Physics, always applied.
struct LayerOutput {

    // -- Position & Movement --

    /// Desired world X position (absolute).
    var positionX: CGFloat?

    /// Desired world Y position (absolute). Physics uses this for jumps.
    var positionY: CGFloat?

    /// Desired depth position (0.0 = foreground, 1.0 = background).
    var positionZ: CGFloat?

    /// Desired facing direction.
    var facing: Direction?

    /// Desired walk speed in points/second. 0 = stopped.
    var walkSpeed: CGFloat?

    // -- Body Part States (semantic names matching body part controllers) --

    var bodyState: String?
    var earLeftState: String?
    var earRightState: String?
    var eyeLeftState: String?
    var eyeRightState: String?
    var tailState: String?
    var mouthState: String?
    var whiskerState: String?
    var auraState: String?

    /// Per-paw states keyed by position: "fl", "fr", "bl", "br".
    var pawStates: [String: String]?

    /// Returns true if every property is nil (layer has no opinions).
    var isEmpty: Bool {
        positionX == nil && positionY == nil && positionZ == nil && facing == nil
            && walkSpeed == nil && bodyState == nil
            && earLeftState == nil && earRightState == nil
            && eyeLeftState == nil && eyeRightState == nil
            && tailState == nil && mouthState == nil
            && whiskerState == nil && auraState == nil
            && pawStates == nil
    }

    /// A completely empty output — the layer defers everything.
    static let empty = LayerOutput()

    /// Merges non-nil properties from another LayerOutput into this one.
    /// The source's non-nil values override any existing values.
    mutating func merge(from src: LayerOutput) {
        if let v = src.positionX { positionX = v }
        if let v = src.positionY { positionY = v }
        if let v = src.positionZ { positionZ = v }
        if let v = src.facing { facing = v }
        if let v = src.walkSpeed { walkSpeed = v }
        if let v = src.bodyState { bodyState = v }
        if let v = src.earLeftState { earLeftState = v }
        if let v = src.earRightState { earRightState = v }
        if let v = src.eyeLeftState { eyeLeftState = v }
        if let v = src.eyeRightState { eyeRightState = v }
        if let v = src.tailState { tailState = v }
        if let v = src.mouthState { mouthState = v }
        if let v = src.whiskerState { whiskerState = v }
        if let v = src.auraState { auraState = v }
        if let v = src.pawStates { pawStates = v }
    }
}

// MARK: - Resolved Creature State

/// The fully resolved desired state after all layers have been merged.
/// Every property has a concrete value (defaults applied where all layers were nil).
struct ResolvedCreatureState {
    var positionX: CGFloat
    var positionY: CGFloat
    var positionZ: CGFloat
    var facing: Direction
    var walkSpeed: CGFloat

    var bodyState: String
    var earLeftState: String
    var earRightState: String
    var eyeLeftState: String
    var eyeRightState: String
    var tailState: String
    var mouthState: String
    var whiskerState: String
    var auraState: String
    var pawStates: [String: String]

    /// Default resting state for a creature at a given stage.
    static func defaultState(stage: GrowthStage, facing: Direction = .right) -> ResolvedCreatureState {
        let hasEars = stage >= .critter
        let hasTail = stage >= .critter
        let hasMouth = stage >= .critter
        let hasWhiskers = stage >= .critter
        let hasAura = stage >= .beast
        let hasPaws = stage >= .critter

        return ResolvedCreatureState(
            positionX: 542.5,   // Center of 1085pt bar
            positionY: 3.0,     // Ground level (~3pt from bottom)
            positionZ: 0.0,     // Foreground (full size)
            facing: facing,
            walkSpeed: 0,
            bodyState: "stand",
            earLeftState: hasEars ? "neutral" : "none",
            earRightState: hasEars ? "neutral" : "none",
            eyeLeftState: stage >= .drop ? "open" : "none",
            eyeRightState: stage >= .drop ? "open" : "none",
            tailState: hasTail ? "sway" : "none",
            mouthState: hasMouth ? "closed" : "none",
            whiskerState: hasWhiskers ? "neutral" : "none",
            auraState: hasAura ? "subtle" : "none",
            pawStates: hasPaws
                ? ["fl": "ground", "fr": "ground", "bl": "ground", "br": "ground"]
                : [:]
        )
    }
}

// MARK: - Blend Transition Type

/// Identifies the type of transition the blend controller should use.
enum BlendTransitionType {
    /// Direction reversal: 0.43s (decel 0.15 -> pause 0.033 -> flip -> accel 0.25)
    case directionReversal

    /// Expression change: 0.8s crossfade with per-part sub-timing
    case expressionChange

    /// Reflex interrupt: 0.15s cascading snap (ears -> eyes -> body)
    case reflexInterrupt

    /// AI takes control: 0.3s ease-in
    case aiTakeover

    /// AI releases control: 5.0s gradual ease-out
    case aiRelease

    /// Total duration for this transition type.
    var duration: TimeInterval {
        switch self {
        case .directionReversal: return 0.433
        case .expressionChange:  return 0.8
        case .reflexInterrupt:   return 0.15
        case .aiTakeover:        return 0.3
        case .aiRelease:         return 5.0
        }
    }
}

// MARK: - Easing Functions

/// Collection of easing curves for blend interpolation.
enum Easing {

    /// Linear interpolation (reflexes — instant feel).
    static func linear(_ t: Double) -> Double {
        t
    }

    /// Ease-in: slow start, fast end (AI gradually asserting control).
    static func easeIn(_ t: Double) -> Double {
        t * t
    }

    /// Ease-out: fast start, slow end (deceleration, AI releasing).
    static func easeOut(_ t: Double) -> Double {
        1.0 - (1.0 - t) * (1.0 - t)
    }

    /// Ease-in-out: smooth both ends (expression changes).
    static func easeInOut(_ t: Double) -> Double {
        if t < 0.5 {
            return 2.0 * t * t
        } else {
            return 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0
        }
    }

    /// Sine-based ease-in-out (breathing-style).
    static func sine(_ t: Double) -> Double {
        -(cos(Double.pi * t) - 1.0) / 2.0
    }
}

// MARK: - Personality Snapshot

/// Read-only snapshot of personality axes for behavior calculations.
/// Avoids coupling to the full creature state or database model.
struct PersonalitySnapshot {
    let energy: Double      // 0.0 (calm) to 1.0 (hyperactive)
    let verbosity: Double   // 0.0 (stoic) to 1.0 (chatty)
    let focus: Double       // 0.0 (scattered) to 1.0 (deliberate)
    let discipline: Double  // 0.0 (chaotic) to 1.0 (methodical)

    /// Default middle-of-the-road personality.
    static let neutral = PersonalitySnapshot(
        energy: 0.5, verbosity: 0.5, focus: 0.5, discipline: 0.5
    )
}

// MARK: - Emotional Snapshot

/// Read-only snapshot of emotional axes for behavior calculations.
struct EmotionalSnapshot {
    let satisfaction: Double  // 0-100
    let curiosity: Double     // 0-100
    let contentment: Double   // 0-100
    let energy: Double        // 0-100 (emotional energy, not personality Energy)

    /// Default neutral emotional state.
    static let neutral = EmotionalSnapshot(
        satisfaction: 50, curiosity: 50, contentment: 50, energy: 50
    )
}

// MARK: - Behavior Layer Protocol

/// Protocol that all 4 layers conform to.
/// Each layer computes its output independently every frame.
protocol BehaviorLayer: AnyObject {
    /// Update the layer's internal state and compute output for this frame.
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - currentTime: Absolute scene time (for sine waves, timeouts).
    /// - Returns: The layer's desired output. nil properties defer to lower layers.
    func update(deltaTime: TimeInterval, currentTime: TimeInterval) -> LayerOutput
}

// MARK: - Scene Constants

/// Touch Bar scene dimension constants used by behavior calculations.
enum SceneConstants {
    /// Total width of the Touch Bar scene in points.
    static let sceneWidth: CGFloat = 1085.0

    /// Total height of the Touch Bar scene in points.
    static let sceneHeight: CGFloat = 30.0

    /// Ground level Y position (bottom padding).
    static let groundY: CGFloat = 3.0

    /// Margin from screen edges where creature turns around.
    static let boundaryMargin: CGFloat = 10.0

    /// Minimum X position for the creature center.
    static let minX: CGFloat = boundaryMargin

    /// Maximum X position for the creature center.
    static let maxX: CGFloat = sceneWidth - boundaryMargin
}

// MARK: - Utility

/// Clamp a value between min and max.
func clamp<T: Comparable>(_ value: T, min minVal: T, max maxVal: T) -> T {
    Swift.min(Swift.max(value, minVal), maxVal)
}

/// Linear interpolation between two values.
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

/// Linear interpolation for Double.
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}
