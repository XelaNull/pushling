// SegmentedTailController.swift — Spring-physics segmented tail controller
// Replaces TailController with a 3-4 segment chain where each segment
// follows the one ahead via spring-damper physics. When the creature turns,
// the tail trails behind naturally. When it stops, the tail settles with
// decreasing oscillation.
//
// States: sway, sway_fast, still, poof, low, high, wrap, twitch_tip, wag, chase
// Spring stiffness decreases base→tip (stiffer at base, looser at tip).
// Personality modulates spring stiffness (high energy = snappy, low = lazy flow).

import SpriteKit

final class SegmentedTailController: BodyPartController {

    // MARK: - Properties

    let node: SKNode
    let validStates = [
        "sway", "sway_fast", "still", "poof", "low", "high",
        "wrap", "twitch_tip", "wag", "chase"
    ]
    private(set) var currentState = "sway"

    /// All segments in order (base to tip).
    /// Segment[0] is a child of the creature. Segment[i] is a child of segment[i-1].
    private let segments: [SKShapeNode]

    /// Length of each segment (for tip-position calculations).
    private let segmentLengths: [CGFloat]

    /// Curve factor used in segment paths (for tip-position calculations).
    private let curveFactor: CGFloat

    /// World-space angles tracked for spring physics.
    private var worldAngles: [CGFloat]

    /// Angular velocities per segment.
    private var angularVelocities: [CGFloat]

    /// Base spring stiffness per segment (before personality modulation).
    /// Stiffer at base (120), looser at tip (60).
    private let baseSpringK: [CGFloat]

    /// Base damping per segment (before personality modulation).
    /// Higher at base (14), lower at tip (8).
    private let baseDamping: [CGFloat]

    /// Sway amplitude in radians (±12 degrees).
    var swayAmplitude: CGFloat = 0.28

    /// Sway period in seconds.
    var swayPeriod: TimeInterval = 3.0

    /// Accumulated time for sine-wave calculations.
    private var swayTime: TimeInterval = 0

    /// Personality energy axis (0-1).
    var personalityEnergy: CGFloat = 0.5

    /// Full personality snapshot for PersonalityFilter modulation.
    var personalitySnapshot: PersonalitySnapshot = .neutral

    // MARK: - Init

    /// Create a segmented tail controller.
    /// - Parameters:
    ///   - segments: Ordered segment nodes (base to tip), already in parent-child chain.
    ///   - segmentLengths: Length of each segment path.
    ///   - curveFactor: Curve factor used when building segment paths.
    init(segments: [SKShapeNode], segmentLengths: [CGFloat],
         curveFactor: CGFloat) {
        precondition(!segments.isEmpty)
        precondition(segments.count == segmentLengths.count)
        self.segments = segments
        self.segmentLengths = segmentLengths
        self.curveFactor = curveFactor
        self.node = segments[0]

        let count = segments.count
        self.worldAngles = Array(repeating: 0, count: count)
        self.angularVelocities = Array(repeating: 0, count: count)

        self.baseSpringK = (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            return 70.0 - t * 30.0
        }
        self.baseDamping = (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            return 8.0 - t * 3.0
        }
    }

    // MARK: - BodyPartController

    func setState(_ state: String, duration: TimeInterval) {
        let resolved = resolveState(state)
        currentState = resolved

        switch resolved {
        case "poof":
            segments[0].run(
                SKAction.scale(to: 1.5, duration: max(duration, 0.15)),
                withKey: "tailScale"
            )
        case "sway", "sway_fast", "wag", "low", "high", "wrap",
             "twitch_tip", "chase":
            restoreScale()
        case "still":
            break
        default:
            break
        }
    }

    func update(deltaTime: TimeInterval) {
        swayTime += deltaTime

        // Compute target world angles per segment
        let targets = computeTargets()

        // Personality-modulated spring constants
        let energyFactor = CGFloat(0.7 + personalitySnapshot.energy * 0.6)
        let dampFactor = CGFloat(0.8 + personalitySnapshot.energy * 0.4)

        // Apply spring-damper physics per segment
        for i in 0..<segments.count {
            let error = targets[i] - worldAngles[i]
            let spring = error * baseSpringK[i] * energyFactor
            let damp = angularVelocities[i] * baseDamping[i] * dampFactor
            angularVelocities[i] += (spring - damp) * CGFloat(deltaTime)
            worldAngles[i] += angularVelocities[i] * CGFloat(deltaTime)
        }

        // Convert world angles to local rotations (parent-child chain)
        segments[0].zRotation = worldAngles[0]
        for i in 1..<segments.count {
            segments[i].zRotation = worldAngles[i] - worldAngles[i - 1]
        }
    }

    // MARK: - Target Computation

    /// Compute per-segment target world angles based on current state.
    /// The spring physics will track these targets with follow-through.
    private func computeTargets() -> [CGFloat] {
        switch currentState {
        case "sway":
            return swayTargets(amplitudeScale: 1.0, periodScale: 1.0)

        case "sway_fast":
            return swayTargets(amplitudeScale: 1.5, periodScale: 0.5)

        case "still":
            // Hold current — targets equal current angles (no spring force)
            return worldAngles

        case "poof":
            return poofTargets()

        case "low":
            return staticChainTargets(baseAngle: -0.6, perSegment: -0.1)

        case "high":
            return staticChainTargets(baseAngle: 0.8, perSegment: -0.05)

        case "wrap":
            return wrapTargets()

        case "twitch_tip":
            return twitchTipTargets()

        case "wag":
            return wagTargets()

        case "chase":
            return chaseTargets()

        default:
            return worldAngles
        }
    }

    // MARK: - State Target Helpers

    private func swayTargets(amplitudeScale: Double,
                              periodScale: Double) -> [CGFloat] {
        let count = segments.count
        let filteredAmp = PersonalityFilter.tailSwayAmplitude(
            base: Double(swayAmplitude) * amplitudeScale,
            personality: personalitySnapshot
        )
        let filteredPeriod = PersonalityFilter.tailSwayPeriod(
            base: swayPeriod * periodScale,
            personality: personalitySnapshot
        )

        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = CGFloat(sin(2.0 * .pi * swayTime / filteredPeriod)
                             * filteredAmp)
        // Each subsequent segment follows its predecessor (spring delay
        // creates follow-through)
        for i in 1..<count {
            targets[i] = worldAngles[i - 1]
        }
        return targets
    }

    private func poofTargets() -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = 0.3
        for i in 1..<count {
            targets[i] = targets[i - 1] + CGFloat(i) * 0.12
        }
        return targets
    }

    private func staticChainTargets(baseAngle: CGFloat,
                                     perSegment: CGFloat) -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = baseAngle
        for i in 1..<count {
            targets[i] = targets[i - 1] + perSegment
        }
        return targets
    }

    private func wrapTargets() -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = -1.2
        for i in 1..<count {
            let curl = CGFloat(i) / CGFloat(count - 1) * 0.5
            targets[i] = targets[0] - curl
        }
        return targets
    }

    private func twitchTipTargets() -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)

        // Base and mid segments: gentle sway
        let gentleSway = CGFloat(sin(2.0 * .pi * swayTime / swayPeriod))
            * 0.08
        targets[0] = 0.3 + gentleSway
        for i in 1..<(count - 1) {
            targets[i] = worldAngles[i - 1]
        }

        // Tip segment: fast oscillation overlay
        let tipFlick = CGFloat(sin(swayTime * 12.0)) * 0.15
        targets[count - 1] = worldAngles[max(0, count - 2)] + tipFlick
        return targets
    }

    private func wagTargets() -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = CGFloat(sin(2.0 * .pi * swayTime / 0.3)) * 0.35
        for i in 1..<count {
            targets[i] = worldAngles[i - 1]
        }
        return targets
    }

    private func chaseTargets() -> [CGFloat] {
        let count = segments.count
        var targets = Array(repeating: CGFloat(0), count: count)
        targets[0] = CGFloat(swayTime * 4.0)
        for i in 1..<count {
            targets[i] = worldAngles[i - 1]
        }
        return targets
    }

    // MARK: - Helpers

    private func restoreScale() {
        segments[0].removeAction(forKey: "tailScale")
        if abs(segments[0].xScale - 1.0) > 0.01
            || abs(segments[0].yScale - 1.0) > 0.01 {
            segments[0].run(
                SKAction.scale(to: 1.0, duration: 0.2),
                withKey: "tailScale"
            )
        }
    }
}
