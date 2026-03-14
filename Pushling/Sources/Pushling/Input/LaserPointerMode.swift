// LaserPointerMode.swift — Drag finger creates Ember dot creature chases
// Unlocked at 100 total touches. Creature stalks slow drags, chases fast,
// stares when dot stops. Pounces after 0.5s stationary. Afterimage trail.

import SpriteKit

// MARK: - Laser Pointer Mode

/// Manages the laser pointer interaction: an Ember-colored dot that tracks
/// the human's finger at 60Hz with a comet-tail afterimage trail.
/// The creature responds with stalk/chase/pounce behaviors.
final class LaserPointerMode {

    // MARK: - Constants

    private static let dotRadius: CGFloat = 3.0
    private static let glowRadius: CGFloat = 5.0
    private static let trailCount = 4
    private static let trailOpacities: [CGFloat] = [0.6, 0.4, 0.2, 0.1]
    private static let pounceDelay: TimeInterval = 0.5
    private static let fadeOutDuration: TimeInterval = 0.3
    private static let stalkSpeedFraction: CGFloat = 0.8
    private static let trotSpeedFraction: CGFloat = 0.9
    private static let maxChaseSpeed: CGFloat = 100.0
    private static let slowThreshold: CGFloat = 50.0
    private static let mediumThreshold: CGFloat = 150.0

    // MARK: - State

    /// Whether laser pointer mode is currently active.
    private(set) var isActive = false

    /// The laser dot node.
    private var dotNode: SKShapeNode?

    /// Inner glow node.
    private var glowNode: SKShapeNode?

    /// Trail afterimage nodes.
    private var trailNodes: [SKShapeNode] = []

    /// Position history for trail (most recent first).
    private var positionHistory: [CGPoint] = []

    /// Time the dot has been stationary (for pounce trigger).
    private var stationaryTime: TimeInterval = 0

    /// Whether the creature has pounced (prevents re-pounce).
    private var hasPounced = false

    /// Last known dot position.
    private var lastPosition: CGPoint = .zero

    /// Last speed for creature behavior classification.
    private(set) var currentSpeed: CGFloat = 0

    /// The parent node to add laser dot visuals to.
    private weak var parentNode: SKNode?

    /// Callback when creature should respond to dot behavior.
    var onCreatureBehavior: ((LaserCreatureBehavior) -> Void)?

    // MARK: - Creature Behavior

    /// What the creature should do in response to the laser dot.
    enum LaserCreatureBehavior {
        case stalk(targetX: CGFloat)    // Slow: stalking crouch
        case trot(targetX: CGFloat)     // Medium: trotting follow
        case chase(targetX: CGFloat)    // Fast: sprint chase
        case stare(targetX: CGFloat)    // Stopped: stare and twitch
        case pounce(targetX: CGFloat)   // Pounce at stationary dot
        case sniffEnd(targetX: CGFloat) // Dot faded — sniff spot
    }

    // MARK: - Activate / Deactivate

    /// Starts laser pointer mode. Creates the dot at the given position.
    func activate(at position: CGPoint, in parent: SKNode) {
        guard !isActive else { return }
        isActive = true
        hasPounced = false
        stationaryTime = 0
        lastPosition = position
        parentNode = parent
        positionHistory = Array(repeating: position, count: Self.trailCount)

        // Create dot
        let dot = SKShapeNode(circleOfRadius: Self.dotRadius)
        dot.fillColor = PushlingPalette.ember
        dot.strokeColor = .clear
        dot.zPosition = 50
        dot.position = position
        dot.name = "laser_dot"
        parent.addChild(dot)
        dotNode = dot

        // Inner glow
        let glow = SKShapeNode(circleOfRadius: Self.glowRadius)
        glow.fillColor = PushlingPalette.ember.withAlphaComponent(0.5)
        glow.strokeColor = .clear
        glow.zPosition = 49
        glow.position = position
        glow.name = "laser_glow"
        parent.addChild(glow)
        glowNode = glow

        // Trail nodes
        trailNodes.removeAll()
        for i in 0..<Self.trailCount {
            let trail = SKShapeNode(circleOfRadius: Self.dotRadius * 0.8)
            trail.fillColor = PushlingPalette.ember
            trail.strokeColor = .clear
            trail.alpha = Self.trailOpacities[i]
            trail.zPosition = 48
            trail.position = position
            trail.name = "laser_trail_\(i)"
            parent.addChild(trail)
            trailNodes.append(trail)
        }

        NSLog("[Pushling/Input] Laser pointer activated at (%.1f, %.1f)",
              position.x, position.y)
    }

    /// Deactivates laser pointer mode with a fade-out.
    func deactivate() {
        guard isActive else { return }
        isActive = false

        let endPos = lastPosition

        // Fade out dot and trail
        let fadeAction = SKAction.sequence([
            SKAction.fadeOut(withDuration: Self.fadeOutDuration),
            SKAction.removeFromParent()
        ])

        dotNode?.run(fadeAction)
        glowNode?.run(fadeAction)
        for trail in trailNodes {
            trail.run(fadeAction)
        }

        dotNode = nil
        glowNode = nil
        trailNodes.removeAll()
        positionHistory.removeAll()

        // Tell creature to sniff the last position
        onCreatureBehavior?(.sniffEnd(targetX: endPos.x))

        NSLog("[Pushling/Input] Laser pointer deactivated")
    }

    // MARK: - Update

    /// Updates the dot position at 60Hz. Called from gesture handler
    /// when a drag is active in laser pointer mode.
    func updatePosition(_ newPosition: CGPoint, speed: CGFloat,
                        deltaTime: TimeInterval) {
        guard isActive else { return }

        currentSpeed = speed
        lastPosition = newPosition

        // Update dot and glow positions (no interpolation — direct)
        dotNode?.position = newPosition
        glowNode?.position = newPosition

        // Shift trail history
        positionHistory.insert(newPosition, at: 0)
        if positionHistory.count > Self.trailCount + 1 {
            positionHistory.removeLast()
        }

        // Update trail positions (each delayed by one frame)
        for i in 0..<trailNodes.count {
            let histIndex = min(i + 1, positionHistory.count - 1)
            trailNodes[i].position = positionHistory[histIndex]
        }

        // Determine creature behavior
        if speed < 1.0 {
            // Dot is effectively stationary
            stationaryTime += deltaTime
            if stationaryTime > Self.pounceDelay && !hasPounced {
                hasPounced = true
                onCreatureBehavior?(.pounce(targetX: newPosition.x))
            } else if !hasPounced {
                onCreatureBehavior?(.stare(targetX: newPosition.x))
            }
        } else {
            stationaryTime = 0
            hasPounced = false

            if speed < Self.slowThreshold {
                onCreatureBehavior?(.stalk(targetX: newPosition.x))
            } else if speed < Self.mediumThreshold {
                onCreatureBehavior?(.trot(targetX: newPosition.x))
            } else {
                onCreatureBehavior?(.chase(targetX: newPosition.x))
            }
        }
    }

    /// Called after a pounce lands. If finger is still there, dot "escapes".
    func dotEscapePounce() {
        guard isActive, let dot = dotNode else { return }
        let escapeDirection: CGFloat = Bool.random() ? 1.0 : -1.0
        let escapeX = clamp(
            dot.position.x + 30.0 * escapeDirection,
            min: 10.0, max: 1075.0
        )
        let escapePos = CGPoint(x: escapeX, y: dot.position.y)
        lastPosition = escapePos

        let jump = SKAction.move(to: escapePos, duration: 0.1)
        jump.timingMode = .easeOut
        dotNode?.run(jump)
        glowNode?.run(jump)

        hasPounced = false
        stationaryTime = 0
    }
}
