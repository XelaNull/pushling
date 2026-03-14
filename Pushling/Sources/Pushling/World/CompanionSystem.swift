// CompanionSystem.swift — 5 NPC companion types with simple autonomous AI
// Mouse, bird, butterfly, fish, ghost_cat — each with 3-4 behaviors.
// Max 1 companion at a time. Persists across daemon restarts.
// Creature-companion relationship modulated by preferences.
//
// Node budget: 1-2 nodes per companion.

import SpriteKit

// MARK: - Companion Type

/// The 5 NPC companion types.
enum CompanionType: String, CaseIterable {
    case mouse
    case bird
    case butterfly
    case fish
    case ghostCat = "ghost_cat"

    /// Display name.
    var displayName: String {
        switch self {
        case .mouse:     return "Mouse"
        case .bird:      return "Bird"
        case .butterfly: return "Butterfly"
        case .fish:      return "Fish"
        case .ghostCat:  return "Ghost Cat"
        }
    }

    /// Size in points.
    var size: CGSize {
        switch self {
        case .mouse:     return CGSize(width: 3, height: 2)
        case .bird:      return CGSize(width: 3, height: 3)
        case .butterfly: return CGSize(width: 2, height: 2)
        case .fish:      return CGSize(width: 3, height: 2)
        case .ghostCat:  return CGSize(width: 10, height: 12)
        }
    }

    /// Base color from palette.
    var color: SKColor {
        switch self {
        case .mouse:     return PushlingPalette.ash
        case .bird:      return PushlingPalette.bone
        case .butterfly: return PushlingPalette.dusk
        case .fish:      return PushlingPalette.tide
        case .ghostCat:  return PushlingPalette.withAlpha(PushlingPalette.bone,
                                                           alpha: 0.15)
        }
    }

    /// Available behaviors for this companion type.
    var behaviors: [CompanionBehavior] {
        switch self {
        case .mouse:
            return [.scurry, .hideObject, .peekOut, .freeze]
        case .bird:
            return [.flyOverhead, .landObject, .hop, .preen]
        case .butterfly:
            return [.randomDrift, .landFlower, .landCreature, .flutter]
        case .fish:
            return [.swim, .splash, .jump, .idle]
        case .ghostCat:
            return [.mirrorWalk, .independentWalk, .glance, .wave]
        }
    }

    /// Default Y position.
    var baseY: CGFloat {
        switch self {
        case .mouse:     return SceneConstants.groundY
        case .bird:      return 20  // Overhead
        case .butterfly: return 15
        case .fish:      return SceneConstants.groundY
        case .ghostCat:  return SceneConstants.groundY
        }
    }
}

// MARK: - Companion Behavior

/// Behaviors available to companion NPCs.
enum CompanionBehavior: String {
    // Mouse
    case scurry, hideObject, peekOut, freeze
    // Bird
    case flyOverhead, landObject, hop, preen
    // Butterfly
    case randomDrift, landFlower, landCreature, flutter
    // Fish
    case swim, splash, jump
    // Ghost cat
    case mirrorWalk, independentWalk, glance, wave
    // Shared
    case idle

    /// Duration range in seconds.
    var durationRange: ClosedRange<TimeInterval> {
        switch self {
        case .scurry:          return 2.0...4.0
        case .hideObject:      return 3.0...6.0
        case .peekOut:         return 1.0...2.0
        case .freeze:          return 2.0...5.0
        case .flyOverhead:     return 3.0...6.0
        case .landObject:      return 4.0...8.0
        case .hop:             return 1.0...2.0
        case .preen:           return 3.0...5.0
        case .randomDrift:     return 4.0...8.0
        case .landFlower:      return 3.0...6.0
        case .landCreature:    return 2.0...4.0
        case .flutter:         return 2.0...3.0
        case .swim:            return 3.0...6.0
        case .splash:          return 1.0...2.0
        case .jump:            return 1.0...2.0
        case .mirrorWalk:      return 5.0...10.0
        case .independentWalk: return 5.0...10.0
        case .glance:          return 1.0...2.0
        case .wave:            return 1.5...2.0
        case .idle:            return 3.0...8.0
        }
    }
}

// MARK: - Active Companion

/// A currently active companion NPC.
struct ActiveCompanion {
    let type: CompanionType
    let name: String
    let node: SKNode
    var currentBehavior: CompanionBehavior
    var behaviorElapsed: TimeInterval = 0
    var behaviorDuration: TimeInterval
    var positionX: CGFloat
    var positionY: CGFloat
    var facingRight: Bool = true
    var spawnedAt: Date
}

// MARK: - CompanionSystem

/// Manages a single NPC companion in the creature's world.
final class CompanionSystem {

    // MARK: - State

    /// The active companion, if any.
    private(set) var activeCompanion: ActiveCompanion?

    /// The parent node to attach companions to.
    private weak var parentNode: SKNode?

    /// Random number generator.
    private var rng = SystemRandomNumberGenerator()

    // MARK: - Setup

    /// Attaches the companion system to a scene layer.
    func attach(to layer: SKNode) {
        parentNode = layer
    }

    // MARK: - Spawning

    /// Spawns a new companion, removing any existing one.
    /// - Parameters:
    ///   - type: The companion type to spawn.
    ///   - name: Optional name (auto-generated if nil).
    ///   - nearX: World-X to spawn near.
    /// - Returns: The spawned companion's name.
    @discardableResult
    func spawn(type: CompanionType, name: String? = nil,
               nearX: CGFloat = 542.5) -> String {
        // Remove existing companion
        if activeCompanion != nil {
            despawn()
        }

        let companionName = name ?? generateName(for: type)
        let node = buildNode(for: type)
        let startX = nearX + CGFloat.random(in: -40...40, using: &rng)

        node.position = CGPoint(x: startX, y: type.baseY)
        parentNode?.addChild(node)

        let firstBehavior = type.behaviors.first ?? .idle
        activeCompanion = ActiveCompanion(
            type: type,
            name: companionName,
            node: node,
            currentBehavior: firstBehavior,
            behaviorDuration: TimeInterval.random(
                in: firstBehavior.durationRange, using: &rng
            ),
            positionX: startX,
            positionY: type.baseY,
            spawnedAt: Date()
        )

        NSLog("[Pushling/Companion] Spawned %@ '%@' at x=%.1f",
              type.displayName, companionName, startX)

        return companionName
    }

    /// Removes the current companion.
    func despawn() {
        guard let companion = activeCompanion else { return }
        companion.node.removeFromParent()
        activeCompanion = nil
        NSLog("[Pushling/Companion] Despawned '%@'", companion.name)
    }

    // MARK: - Per-Frame Update

    /// Updates the companion's autonomous behavior.
    /// - Parameters:
    ///   - deltaTime: Seconds since last frame.
    ///   - creatureX: Creature's current X position.
    ///   - creatureY: Creature's current Y position.
    func update(deltaTime: TimeInterval,
                creatureX: CGFloat,
                creatureY: CGFloat) {
        guard var companion = activeCompanion else { return }

        companion.behaviorElapsed += deltaTime

        // Check if behavior duration expired
        if companion.behaviorElapsed >= companion.behaviorDuration {
            // Select next behavior
            let nextBehavior = selectNextBehavior(
                for: companion.type,
                creatureX: creatureX
            )
            companion.currentBehavior = nextBehavior
            companion.behaviorElapsed = 0
            companion.behaviorDuration = TimeInterval.random(
                in: nextBehavior.durationRange, using: &rng
            )
        }

        // Execute current behavior
        executeBehavior(companion: &companion,
                        deltaTime: deltaTime,
                        creatureX: creatureX,
                        creatureY: creatureY)

        // Update node position
        companion.node.position = CGPoint(x: companion.positionX,
                                            y: companion.positionY)
        companion.node.xScale = companion.facingRight ? 1.0 : -1.0

        activeCompanion = companion
    }

    // MARK: - Behavior Selection

    /// Selects the next behavior based on type and creature proximity.
    private func selectNextBehavior(
        for type: CompanionType,
        creatureX: CGFloat
    ) -> CompanionBehavior {
        let behaviors = type.behaviors
        guard !behaviors.isEmpty else { return .idle }

        // Weighted random — bias toward behaviors appropriate to context
        let distance = activeCompanion.map {
            abs($0.positionX - creatureX)
        } ?? 100

        // If creature is close, prefer reactive behaviors
        if distance < 30 {
            switch type {
            case .mouse:     return Bool.random(using: &rng) ? .freeze : .scurry
            case .bird:      return .flyOverhead
            case .butterfly: return .landCreature
            case .fish:      return .splash
            case .ghostCat:  return .glance
            }
        }

        // Otherwise random from pool
        return behaviors.randomElement(using: &rng) ?? .idle
    }

    // MARK: - Behavior Execution

    /// Executes the current behavior, updating companion position/state.
    private func executeBehavior(companion: inout ActiveCompanion,
                                  deltaTime: TimeInterval,
                                  creatureX: CGFloat,
                                  creatureY: CGFloat) {
        let progress = companion.behaviorDuration > 0
            ? companion.behaviorElapsed / companion.behaviorDuration
            : 0

        switch companion.currentBehavior {
        // Mouse behaviors
        case .scurry:
            let speed: CGFloat = 30
            let direction: CGFloat = companion.facingRight ? 1 : -1
            companion.positionX += speed * direction * CGFloat(deltaTime)
            // Boundary check
            if companion.positionX > SceneConstants.maxX || companion.positionX < SceneConstants.minX {
                companion.facingRight.toggle()
            }

        case .hideObject:
            companion.positionY = SceneConstants.groundY
            // Stay still, hidden

        case .peekOut:
            // Slight movement up
            companion.positionY = SceneConstants.groundY + 1

        case .freeze:
            break  // Don't move

        // Bird behaviors
        case .flyOverhead:
            let speed: CGFloat = 20
            companion.positionX += speed * CGFloat(deltaTime)
            companion.positionY = 22 + CGFloat(sin(companion.behaviorElapsed * 2)) * 3
            if companion.positionX > SceneConstants.maxX + 50 {
                companion.positionX = SceneConstants.minX - 50
            }

        case .landObject:
            companion.positionY = 12  // Perched
            // Subtle bob
            companion.positionY += CGFloat(sin(companion.behaviorElapsed * 3)) * 0.3

        case .hop:
            if progress < 0.5 {
                companion.positionY = SceneConstants.groundY + 3
                companion.positionX += 5 * CGFloat(deltaTime)
            } else {
                companion.positionY = SceneConstants.groundY
            }

        case .preen:
            break  // Stays in place

        // Butterfly behaviors
        case .randomDrift:
            companion.positionX += CGFloat(sin(companion.behaviorElapsed * 1.5)) * 10 * CGFloat(deltaTime)
            companion.positionY = 15 + CGFloat(sin(companion.behaviorElapsed * 2.5)) * 5

        case .landFlower:
            companion.positionY = SceneConstants.groundY + 4

        case .landCreature:
            companion.positionX = creatureX
            companion.positionY = creatureY + 8

        case .flutter:
            companion.positionY = 18 + CGFloat(sin(companion.behaviorElapsed * 5)) * 2

        // Fish behaviors
        case .swim:
            let speed: CGFloat = 8
            companion.positionX += speed * (companion.facingRight ? 1 : -1) * CGFloat(deltaTime)
            companion.positionY = SceneConstants.groundY
            if companion.positionX > SceneConstants.maxX || companion.positionX < SceneConstants.minX {
                companion.facingRight.toggle()
            }

        case .splash:
            companion.positionY = SceneConstants.groundY + CGFloat(sin(companion.behaviorElapsed * 8)) * 2

        case .jump:
            let jumpProgress = progress
            let jumpHeight: CGFloat = 6
            companion.positionY = SceneConstants.groundY + jumpHeight * CGFloat(sin(jumpProgress * .pi))

        // Ghost cat behaviors
        case .mirrorWalk:
            // Walk at creature's speed but offset
            let offset: CGFloat = companion.facingRight ? 60 : -60
            let targetX = creatureX + offset
            let speed: CGFloat = 15
            let dx = targetX - companion.positionX
            if abs(dx) > 2 {
                companion.positionX += (dx > 0 ? speed : -speed) * CGFloat(deltaTime)
                companion.facingRight = dx > 0
            }

        case .independentWalk:
            let speed: CGFloat = 12
            companion.positionX += speed * (companion.facingRight ? 1 : -1) * CGFloat(deltaTime)
            if companion.positionX > SceneConstants.maxX || companion.positionX < SceneConstants.minX {
                companion.facingRight.toggle()
            }

        case .glance:
            companion.facingRight = creatureX > companion.positionX

        case .wave:
            break  // Handled by animation, not position

        case .idle:
            break
        }
    }

    // MARK: - Node Building

    /// Builds the SKNode for a companion type.
    private func buildNode(for type: CompanionType) -> SKNode {
        let node: SKShapeNode

        switch type {
        case .mouse:
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -1.5, y: -1, width: 3, height: 2))
            node = SKShapeNode(path: path)

        case .bird:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 1.5))
            path.addLine(to: CGPoint(x: -1.5, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -0.5))
            path.addLine(to: CGPoint(x: 1.5, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)

        case .butterfly:
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -1.5, y: 0, width: 1.5, height: 1.5))
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 1.5, height: 1.5))
            node = SKShapeNode(path: path)

        case .fish:
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -1.5, y: -1, width: 3, height: 2))
            node = SKShapeNode(path: path)

        case .ghostCat:
            // Simplified cat silhouette at 15% alpha
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -5, y: -3, width: 10, height: 8))
            node = SKShapeNode(path: path)
        }

        node.fillColor = type.color
        node.strokeColor = .clear
        node.lineWidth = 0
        node.name = "companion_\(type.rawValue)"

        return node
    }

    // MARK: - Name Generation

    /// Generates a random name for a companion.
    private func generateName(for type: CompanionType) -> String {
        let prefixes: [CompanionType: [String]] = [
            .mouse:     ["Pip", "Squeak", "Nibbles", "Tiny", "Scoot"],
            .bird:      ["Chirp", "Tweet", "Flutter", "Sky", "Pip"],
            .butterfly: ["Shimmer", "Wing", "Breeze", "Petal", "Dusk"],
            .fish:      ["Splash", "Bubble", "Wave", "Fin", "Tide"],
            .ghostCat:  ["Echo", "Shadow", "Phantom", "Mist", "Wisp"],
        ]
        return prefixes[type]?.randomElement(using: &rng) ?? type.displayName
    }

    // MARK: - Queries

    /// Whether a companion is currently active.
    var hasCompanion: Bool { activeCompanion != nil }

    /// The active companion's type and name.
    var companionInfo: (type: CompanionType, name: String)? {
        guard let c = activeCompanion else { return nil }
        return (c.type, c.name)
    }

    /// Node count for the companion (for budget tracking).
    var nodeCount: Int {
        activeCompanion != nil ? 1 : 0
    }
}
