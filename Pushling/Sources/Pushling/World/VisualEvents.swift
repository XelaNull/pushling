// VisualEvents.swift — Visual spectacle event manager
// P3-T3-09: One-shot visual events for pushling_world("event").
//
// Events: shooting_star, aurora, bloom, eclipse, festival, fireflies, rainbow.
// Each is a 2-60s visual effect layered above the world.
// Only 1 event active at a time (queued if overlapping).
// Node budget: max 15 temporary nodes during an event.
//
// Event builders are in VisualEventBuilders.swift (extension).
// All colors from P3 palette.

import SpriteKit

// MARK: - Visual Event Type

/// The 7 spectacle event types.
enum VisualEventType: String, CaseIterable {
    case shootingStar = "shooting_star"
    case aurora       = "aurora"
    case bloom        = "bloom"
    case eclipse      = "eclipse"
    case festival     = "festival"
    case fireflies    = "fireflies"
    case rainbow      = "rainbow"

    /// Expected duration of this event type.
    var duration: TimeInterval {
        switch self {
        case .shootingStar: return 2
        case .aurora:       return 45
        case .bloom:        return 5
        case .eclipse:      return 20
        case .festival:     return 15
        case .fireflies:    return 45
        case .rainbow:      return 20
        }
    }
}

// MARK: - Visual Event Manager

/// Manages visual spectacle events. Queues events, runs one at a time.
/// Created by the scene and triggered via IPC commands.
final class VisualEventManager {

    // MARK: - Constants

    static let sceneWidth: CGFloat = 1085
    static let sceneHeight: CGFloat = 30

    // MARK: - Nodes

    /// Container for event nodes. Added to the scene above world layers.
    let eventContainer: SKNode

    // MARK: - State

    /// Currently active event type (nil if no event running).
    private(set) var activeEvent: VisualEventType?

    /// Event queue (if triggered while another is active).
    private var eventQueue: [VisualEventType] = []

    /// Active event nodes (removed when event completes).
    var activeNodes: [SKNode] = []

    /// Timer for the active event.
    private var eventTimer: TimeInterval = 0

    /// Firefly nodes tracked for per-frame drift (P3-T3-09).
    var fireflyNodes: [SKShapeNode] = []

    // MARK: - Init

    init() {
        eventContainer = SKNode()
        eventContainer.name = "visual_events"
        eventContainer.zPosition = 300  // Above world, below speech/HUD
    }

    // MARK: - Scene Integration

    /// Add the event container to the scene.
    func addToScene(_ scene: SKScene) {
        scene.addChild(eventContainer)
    }

    // MARK: - Trigger Event

    /// Trigger a visual event. Queues if another event is active.
    /// - Parameter type: The event type to trigger.
    /// - Returns: True if the event started immediately, false if queued.
    @discardableResult
    func triggerEvent(_ type: VisualEventType) -> Bool {
        if activeEvent != nil {
            eventQueue.append(type)
            NSLog("[Pushling/Events] Queued event: %@ (%d in queue)",
                  type.rawValue, eventQueue.count)
            return false
        }

        startEvent(type)
        return true
    }

    // MARK: - Frame Update

    /// Per-frame update. Manages event lifecycle and animations.
    func update(deltaTime: TimeInterval) {
        guard activeEvent != nil else { return }

        eventTimer -= deltaTime

        // Update per-event animations
        updateActiveEventAnimations(deltaTime: deltaTime)

        if eventTimer <= 0 {
            endCurrentEvent()
        }
    }

    // MARK: - Event Lifecycle

    func startEvent(_ type: VisualEventType) {
        activeEvent = type
        eventTimer = type.duration

        switch type {
        case .shootingStar: buildShootingStar()
        case .aurora:       buildAurora()
        case .bloom:        buildBloom()
        case .eclipse:      buildEclipse()
        case .festival:     buildFestival()
        case .fireflies:    buildFireflies()
        case .rainbow:      buildRainbow()
        }

        NSLog("[Pushling/Events] Started event: %@ (%.0fs)",
              type.rawValue, type.duration)
    }

    private func endCurrentEvent() {
        // Fade out and remove all active nodes
        for node in activeNodes {
            node.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
        activeNodes.removeAll()
        fireflyNodes.removeAll()
        activeEvent = nil

        // Start next queued event
        if let next = eventQueue.first {
            eventQueue.removeFirst()
            startEvent(next)
        }
    }

    private func updateActiveEventAnimations(deltaTime: TimeInterval) {
        guard let event = activeEvent else { return }

        switch event {
        case .fireflies:
            updateFireflies(deltaTime: deltaTime)
        default:
            break
        }
    }

    func updateFireflies(deltaTime: TimeInterval) {
        for fly in fireflyNodes where fly.alpha > 0.01 {
            let dx = CGFloat.random(in: -0.5...0.5)
            let dy = CGFloat.random(in: -0.3...0.3)
            fly.position.x += dx
            fly.position.y += dy

            let pulse = 0.5 + 0.3 * CGFloat(sin(
                Double(fly.position.x * 0.1 + fly.position.y * 0.2)
                + eventTimer * 3.0
            ))
            fly.alpha = pulse

            fly.position.x = max(10, min(Self.sceneWidth - 10, fly.position.x))
            fly.position.y = max(3, min(25, fly.position.y))
        }
    }

    // MARK: - Node Count

    /// Current event node count (for budget tracking).
    var nodeCount: Int {
        return activeNodes.count + 1  // +1 for container
    }

    // MARK: - Queries

    /// Whether any event is currently active.
    var isEventActive: Bool {
        return activeEvent != nil
    }

    /// Description of current event state (for MCP).
    var eventDescription: [String: Any] {
        var desc: [String: Any] = [
            "active": activeEvent?.rawValue ?? "none",
            "queue_size": eventQueue.count
        ]
        if let event = activeEvent {
            desc["remaining_seconds"] = Int(eventTimer)
            desc["event_duration"] = Int(event.duration)
        }
        return desc
    }
}
