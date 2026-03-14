// ObjectInteraction.swift — Flick, pick up, tap, and drag world objects
// Flick: physics impulse in swipe direction (mass-dependent behavior).
// Long-press: pick up, drag to reposition with weighted lag.
// Tap: bounce highlight, creature investigates.

import SpriteKit

// MARK: - Object Mass

/// Mass factor for different world object types.
enum ObjectMass {
    static func factor(for objectType: String) -> CGFloat {
        switch objectType {
        case "ball":           return 0.8
        case "yarn_ball":      return 0.6
        case "feather":        return 0.2
        case "rock":           return 1.5
        case "flower":         return 0.3
        case "star_fragment":  return 0.4
        default:               return 1.0
        }
    }

    static func restitution(for objectType: String) -> CGFloat {
        switch objectType {
        case "ball":       return 0.7
        case "yarn_ball":  return 0.5
        case "feather":    return 0.1
        case "rock":       return 0.2
        case "flower":     return 0.15
        default:           return 0.3
        }
    }
}

// MARK: - Object Interaction

/// Manages world object interactions: flick physics, pick-up/move, tap.
final class ObjectInteraction {

    // MARK: - Constants

    private static let flickMinSpeed: CGFloat = 200.0
    private static let gravity: CGFloat = 60.0       // pts/sec^2
    private static let friction: CGFloat = 0.95       // velocity decay per frame
    private static let edgeBounce: CGFloat = 0.3
    private static let pickUpLerp: CGFloat = 0.85
    private static let pickUpFloatHeight: CGFloat = 2.0
    private static let dropDuration: TimeInterval = 0.15
    private static let bounceScale: CGFloat = 1.15
    private static let bounceDuration: TimeInterval = 0.2
    private static let tapCooldown: TimeInterval = 30.0
    private static let minDropSpacing: CGFloat = 20.0
    private static let objectXMin: CGFloat = 10.0
    private static let objectXMax: CGFloat = 1075.0

    // MARK: - State

    /// Currently held object (pick-up mode).
    private(set) var heldObjectId: String?
    private var heldObjectNode: SKNode?
    private var holdOffset: CGPoint = .zero
    private var shadowNode: SKShapeNode?

    /// Objects in flight (after flick).
    private var flyingObjects: [FlyingObject] = []

    /// Per-object tap cooldowns.
    private var tapCooldowns: [String: TimeInterval] = [:]

    /// Callback for creature behavior in response to object events.
    var onObjectEvent: ((ObjectEvent) -> Void)?

    // MARK: - Object Events

    /// Events dispatched for creature responses.
    enum ObjectEvent {
        case tapped(objectId: String, position: CGPoint)
        case flicked(objectId: String, velocity: CGVector)
        case pickedUp(objectId: String)
        case dropped(objectId: String, position: CGPoint)
        case objectLanded(objectId: String, position: CGPoint)
        case creatureChase(objectId: String, targetX: CGFloat)
    }

    // MARK: - Flying Object

    private struct FlyingObject {
        let objectId: String
        let node: SKNode
        var velocity: CGVector
        var objectType: String
        var timeInFlight: TimeInterval
    }

    // MARK: - Tap

    /// Handles a tap on a world object: bounce animation + creature attention.
    func tapObject(objectId: String, node: SKNode, currentTime: TimeInterval) {
        // Check cooldown
        if let cooldownEnd = tapCooldowns[objectId],
           currentTime < cooldownEnd {
            return
        }
        tapCooldowns[objectId] = currentTime + Self.tapCooldown

        // Bounce animation
        let scaleUp = SKAction.scale(to: Self.bounceScale,
                                      duration: Self.bounceDuration * 0.4)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0,
                                        duration: Self.bounceDuration * 0.6)
        scaleDown.timingMode = .easeIn
        node.run(SKAction.sequence([scaleUp, scaleDown]))

        // Sparkle particles (2-3 small Gilt particles)
        emitTapSparkle(at: node.position, in: node.parent ?? node)

        onObjectEvent?(.tapped(objectId: objectId, position: node.position))

        NSLog("[Pushling/Input] Object tapped: %@", objectId)
    }

    // MARK: - Flick

    /// Launches an object with physics after a flick gesture.
    func flickObject(objectId: String, node: SKNode,
                     velocity: CGVector, objectType: String) {
        let mass = ObjectMass.factor(for: objectType)
        let impulseVelocity = CGVector(
            dx: velocity.dx * mass,
            dy: abs(velocity.dx) * 0.3  // Arc upward proportional to speed
        )

        let flying = FlyingObject(
            objectId: objectId,
            node: node,
            velocity: impulseVelocity,
            objectType: objectType,
            timeInFlight: 0
        )
        flyingObjects.append(flying)

        // Emit launch particles based on object type
        if objectType == "flower" {
            emitPetalParticles(at: node.position, in: node.parent ?? node)
        } else if objectType == "star_fragment" {
            emitSparkleTrail(at: node.position, in: node.parent ?? node)
        }

        onObjectEvent?(.flicked(objectId: objectId, velocity: impulseVelocity))
        onObjectEvent?(.creatureChase(objectId: objectId,
                                       targetX: node.position.x))

        NSLog("[Pushling/Input] Object flicked: %@ v=(%.1f, %.1f)",
              objectId, impulseVelocity.dx, impulseVelocity.dy)
    }

    // MARK: - Pick Up

    /// Picks up an object (long-press detected on it).
    func pickUp(objectId: String, node: SKNode, touchPoint: CGPoint) {
        heldObjectId = objectId
        heldObjectNode = node
        holdOffset = CGPoint(
            x: node.position.x - touchPoint.x,
            y: node.position.y - touchPoint.y
        )

        // Highlight
        node.run(SKAction.group([
            SKAction.moveBy(x: 0, y: Self.pickUpFloatHeight, duration: 0.15),
            SKAction.scale(to: 1.05, duration: 0.15)
        ]))

        // Add shadow
        if let parent = node.parent {
            let shadow = SKShapeNode(circleOfRadius: 3)
            shadow.fillColor = PushlingPalette.ash.withAlphaComponent(0.4)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: node.position.x,
                                       y: node.position.y - 1)
            shadow.zPosition = node.zPosition - 1
            shadow.name = "pickup_shadow"
            parent.addChild(shadow)
            shadowNode = shadow
        }

        onObjectEvent?(.pickedUp(objectId: objectId))
    }

    /// Moves a held object toward the finger position with weighted lag.
    func moveHeld(to touchPoint: CGPoint) {
        guard let node = heldObjectNode else { return }

        let targetX = clamp(touchPoint.x + holdOffset.x,
                            min: Self.objectXMin, max: Self.objectXMax)
        let targetY = touchPoint.y + holdOffset.y

        // Lerp for weighted feel
        let newX = lerp(node.position.x, targetX, Self.pickUpLerp)
        let newY = lerp(node.position.y, targetY, Self.pickUpLerp)
        node.position = CGPoint(x: newX, y: newY)

        // Move shadow
        shadowNode?.position = CGPoint(x: newX, y: newY - 1)
    }

    /// Drops a held object at its current position.
    func dropHeld(terrainY: CGFloat) {
        guard let node = heldObjectNode, let objectId = heldObjectId else { return }

        let dropX = clamp(node.position.x,
                          min: Self.objectXMin, max: Self.objectXMax)
        let dropPos = CGPoint(x: dropX, y: terrainY)

        // Drop animation
        let drop = SKAction.group([
            SKAction.move(to: dropPos, duration: Self.dropDuration),
            SKAction.scale(to: 1.0, duration: Self.dropDuration)
        ])
        drop.timingMode = .easeIn

        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 1.5, duration: 0.08),
            SKAction.moveBy(x: 0, y: -1.5, duration: 0.08)
        ])

        node.run(SKAction.sequence([drop, bounce]))

        // Remove shadow
        shadowNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: Self.dropDuration),
            SKAction.removeFromParent()
        ]))

        onObjectEvent?(.dropped(objectId: objectId, position: dropPos))

        heldObjectId = nil
        heldObjectNode = nil
        holdOffset = .zero
        shadowNode = nil
    }

    /// Whether an object is currently being held.
    var isHolding: Bool { heldObjectId != nil }

    // MARK: - Physics Update

    /// Updates flying object physics each frame.
    func update(deltaTime: TimeInterval) {
        var landedIndices: [Int] = []

        for i in flyingObjects.indices {
            var obj = flyingObjects[i]
            obj.timeInFlight += deltaTime

            // Apply gravity
            obj.velocity.dy -= Self.gravity * CGFloat(deltaTime)

            // Apply velocity
            obj.node.position.x += obj.velocity.dx * CGFloat(deltaTime)
            obj.node.position.y += obj.velocity.dy * CGFloat(deltaTime)

            // Edge bounce
            if obj.node.position.x <= Self.objectXMin {
                obj.node.position.x = Self.objectXMin
                obj.velocity.dx = abs(obj.velocity.dx) * Self.edgeBounce
            } else if obj.node.position.x >= Self.objectXMax {
                obj.node.position.x = Self.objectXMax
                obj.velocity.dx = -abs(obj.velocity.dx) * Self.edgeBounce
            }

            // Ground collision
            if obj.node.position.y <= SceneConstants.groundY {
                obj.node.position.y = SceneConstants.groundY
                let restitution = ObjectMass.restitution(for: obj.objectType)
                obj.velocity.dy = abs(obj.velocity.dy) * restitution

                // Screen shake for heavy objects
                if obj.objectType == "rock" && abs(obj.velocity.dy) > 5 {
                    // Shake handled by scene
                }

                // Friction
                obj.velocity.dx *= Self.friction

                // Check if settled
                if abs(obj.velocity.dx) < 2 && abs(obj.velocity.dy) < 2 {
                    landedIndices.append(i)
                }
            }

            // Feather: sine-wave drift
            if obj.objectType == "feather" {
                obj.node.position.x += sin(CGFloat(obj.timeInFlight * 3))
                    * 0.5
                obj.velocity.dy = max(obj.velocity.dy, -20)  // Slow descent
            }

            // Timeout: force landing after 3 seconds
            if obj.timeInFlight > 3.0 {
                landedIndices.append(i)
            }

            flyingObjects[i] = obj
        }

        // Process landed objects (reverse to preserve indices)
        for i in landedIndices.reversed() {
            let obj = flyingObjects[i]
            onObjectEvent?(.objectLanded(objectId: obj.objectId,
                                          position: obj.node.position))
            flyingObjects.remove(at: i)
        }
    }

    // MARK: - Particle Effects

    private func emitTapSparkle(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<3 {
            let sparkle = SKShapeNode(circleOfRadius: 0.8)
            sparkle.fillColor = PushlingPalette.gilt
            sparkle.strokeColor = .clear
            sparkle.position = position
            sparkle.zPosition = 35
            parent.addChild(sparkle)

            let dx = CGFloat.random(in: -6...6)
            let dy = CGFloat.random(in: 2...8)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.2)
            sparkle.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func emitPetalParticles(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<5 {
            let petal = SKShapeNode(circleOfRadius: 1.0)
            petal.fillColor = PushlingPalette.ember.withAlphaComponent(0.7)
            petal.strokeColor = .clear
            petal.position = position
            petal.zPosition = 35
            parent.addChild(petal)

            let dx = CGFloat.random(in: -10...10)
            let dy = CGFloat.random(in: -5...10)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            petal.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func emitSparkleTrail(at position: CGPoint, in parent: SKNode) {
        for _ in 0..<4 {
            let spark = SKShapeNode(circleOfRadius: 0.6)
            spark.fillColor = PushlingPalette.gilt
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 35
            parent.addChild(spark)

            let dx = CGFloat.random(in: -4...4)
            let dy = CGFloat.random(in: 1...6)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.4)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.3)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Reset

    func reset() {
        heldObjectId = nil
        heldObjectNode = nil
        shadowNode?.removeFromParent()
        shadowNode = nil
        flyingObjects.removeAll()
        tapCooldowns.removeAll()
    }
}
