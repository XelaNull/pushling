// BodyPartController.swift — Protocol and shared types for creature body parts
// Each body part has a controller exposing named semantic states.
// Controllers know HOW to animate, not WHEN — the behavior stack decides timing.
//
// GrowthStage and Direction are defined in Behavior/LayerTypes.swift.
// PushlingPalette is defined in World/PushlingPalette.swift.

import SpriteKit

// MARK: - Stage Configuration

/// Per-stage visual and behavioral parameters.
struct StageConfiguration {
    let stage: GrowthStage
    let size: CGSize           // Points (width x height)
    let hasEars: Bool
    let hasTail: Bool
    let hasPaws: Bool
    let hasWhiskers: Bool
    let hasMouth: Bool
    let hasAura: Bool
    let hasCoreGlow: Bool
    let walkSpeed: CGFloat     // Points per second
    let runSpeed: CGFloat      // Points per second

    /// All six stage configs, indexed by stage.
    static let all: [GrowthStage: StageConfiguration] = [
        .egg: StageConfiguration(
            stage: .egg, size: CGSize(width: 9, height: 11),
            hasEars: false, hasTail: false, hasPaws: false,
            hasWhiskers: false, hasMouth: false, hasAura: false,
            hasCoreGlow: true, walkSpeed: 3, runSpeed: 0
        ),
        .drop: StageConfiguration(
            stage: .drop, size: CGSize(width: 10, height: 12),
            hasEars: false, hasTail: false, hasPaws: false,
            hasWhiskers: false, hasMouth: false, hasAura: false,
            hasCoreGlow: false, walkSpeed: 8, runSpeed: 0
        ),
        .critter: StageConfiguration(
            stage: .critter, size: CGSize(width: 14, height: 16),
            hasEars: true, hasTail: true, hasPaws: true,
            hasWhiskers: true, hasMouth: true, hasAura: false,
            hasCoreGlow: true, walkSpeed: 15, runSpeed: 30
        ),
        .beast: StageConfiguration(
            stage: .beast, size: CGSize(width: 18, height: 20),
            hasEars: true, hasTail: true, hasPaws: true,
            hasWhiskers: true, hasMouth: true, hasAura: true,
            hasCoreGlow: false, walkSpeed: 25, runSpeed: 50
        ),
        .sage: StageConfiguration(
            stage: .sage, size: CGSize(width: 22, height: 24),
            hasEars: true, hasTail: true, hasPaws: true,
            hasWhiskers: true, hasMouth: true, hasAura: true,
            hasCoreGlow: false, walkSpeed: 20, runSpeed: 40
        ),
        .apex: StageConfiguration(
            stage: .apex, size: CGSize(width: 25, height: 28),
            hasEars: true, hasTail: true, hasPaws: true,
            hasWhiskers: true, hasMouth: true, hasAura: true,
            hasCoreGlow: false, walkSpeed: 22, runSpeed: 45
        ),
    ]
}

// MARK: - Body Part Controller Protocol

/// Protocol for all body part controllers.
/// Each controller manages a single body part's visual states and transitions.
protocol BodyPartController: AnyObject {
    /// The SpriteKit node this controller manages.
    var node: SKNode { get }

    /// All valid state names for this body part.
    var validStates: [String] { get }

    /// The current state name.
    var currentState: String { get }

    /// Transition to a named state with optional duration.
    /// - Parameters:
    ///   - state: The target state name (fuzzy-matched if not exact).
    ///   - duration: Transition duration in seconds (0 = instant).
    func setState(_ state: String, duration: TimeInterval)

    /// Per-frame update for continuous animations (sway, twitch, etc.).
    /// - Parameter deltaTime: Seconds since last frame.
    func update(deltaTime: TimeInterval)
}

// MARK: - Default Implementation

extension BodyPartController {
    /// Fuzzy-match a state name against valid states using Levenshtein distance.
    /// Returns the closest match and logs a warning if not exact.
    func resolveState(_ requested: String) -> String {
        // Exact match — fast path
        if validStates.contains(requested) {
            return requested
        }

        // Fuzzy match — find closest by edit distance
        let lowered = requested.lowercased()
        var bestMatch = validStates[0]
        var bestDistance = Int.max

        for valid in validStates {
            let dist = levenshteinDistance(lowered, valid.lowercased())
            if dist < bestDistance {
                bestDistance = dist
                bestMatch = valid
            }
        }

        let partName = String(describing: type(of: self))
        NSLog("[Pushling/%@] Unknown state '%@', using '%@'",
              partName, requested, bestMatch)
        return bestMatch
    }

    /// Default update does nothing — override for continuous animations.
    func update(deltaTime: TimeInterval) {}
}

// MARK: - Levenshtein Distance

/// Compute edit distance between two strings for fuzzy state matching.
func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let a = Array(s1)
    let b = Array(s2)
    let m = a.count
    let n = b.count

    if m == 0 { return n }
    if n == 0 { return m }

    var prev = Array(0...n)
    var curr = Array(repeating: 0, count: n + 1)

    for i in 1...m {
        curr[0] = i
        for j in 1...n {
            let cost = a[i - 1] == b[j - 1] ? 0 : 1
            curr[j] = min(
                prev[j] + 1,       // deletion
                curr[j - 1] + 1,   // insertion
                prev[j - 1] + cost // substitution
            )
        }
        prev = curr
    }
    return prev[n]
}
