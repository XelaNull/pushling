// WorldObjectRenderer.swift — Renders persistent world objects from definitions
// Creates SKNode compositions from object definitions (base shape + color + effects).
// Manages object lifecycle, LOD culling, and node budget.
//
// Object cap: 12 persistent + 3 consumables. Max 40 nodes from objects.
// LOD: >200pt from camera = hidden. 100-200pt = no effects. <100pt = full.

import SpriteKit

// MARK: - World Object Definition

/// A fully resolved object definition ready for rendering.
struct WorldObjectDefinition {
    let id: String
    let name: String
    let baseShape: String
    let positionX: CGFloat
    let layer: String              // "far", "mid", "fore"
    let size: CGFloat              // Scale factor 0.5-2.0
    let primaryColor: String       // Palette color name
    let secondaryColor: String?
    let colorPattern: String       // solid, stripe, dots, gradient, glow
    let effects: [String]          // glow, pulse, bob, spin, sway, particle
    let physics: ObjectPhysics
    let interaction: String        // One of 14 interaction templates
    let wearRate: Double           // 0.0-0.1 per interaction
    let source: String             // system, ai_placed, repo_landmark
    let isConsumable: Bool
}

/// Physics properties for an object.
struct ObjectPhysics {
    let weight: String             // light, medium, heavy
    let bounciness: Double         // 0.0-1.0
    let rollable: Bool
    let pushable: Bool
    let carryable: Bool
}

// MARK: - Rendered Object

/// A rendered object in the world with its SKNode and metadata.
struct RenderedObject {
    let id: String
    let definition: WorldObjectDefinition
    let node: SKNode
    /// Database row ID for persistence (nil for transient objects).
    var dbID: Int?
    var wear: Double = 0.0
    var repairCount: Int = 0
    var lastInteractedAt: Date?
    var createdAt: Date
    var isActive: Bool = true

    /// Node count for this object (base + effects).
    var nodeCount: Int {
        var count = 1  // Base node
        count += node.children.count
        return count
    }
}

// MARK: - WorldObjectRenderer

/// Renders and manages persistent world objects.
final class WorldObjectRenderer {

    // MARK: - Configuration

    /// Maximum persistent (non-consumable) objects.
    static let maxPersistentObjects = 12

    /// Maximum active consumables.
    static let maxConsumables = 3

    /// Minimum spacing between objects in points.
    static let minimumSpacing: CGFloat = 20.0

    /// Maximum total nodes from objects.
    static let maxObjectNodes = 40

    /// LOD distances.
    static let lodFullDistance: CGFloat = 100.0
    static let lodReducedDistance: CGFloat = 200.0

    // MARK: - State

    /// All rendered objects keyed by ID.
    private(set) var objects: [String: RenderedObject] = [:]

    /// Layer nodes keyed by layer name ("far", "mid", "fore").
    private var layerNodes: [String: SKNode] = [:]

    /// Legacy single parent (maps to "fore").
    private weak var parentNode: SKNode?

    /// Current camera world-X for LOD calculations.
    private var cameraWorldX: CGFloat = 542.5

    /// Animation time accumulator for effects.
    private var effectsTime: TimeInterval = 0

    // MARK: - Setup

    /// Attaches the renderer to all 3 parallax layers.
    func attach(farLayer: SKNode, midLayer: SKNode, foreLayer: SKNode) {
        layerNodes = ["far": farLayer, "mid": midLayer, "fore": foreLayer]
        parentNode = foreLayer
    }

    /// Legacy: attaches to a single layer (maps to "fore").
    func attach(to layer: SKNode) {
        layerNodes = ["fore": layer]
        parentNode = layer
    }

    // MARK: - Object Creation

    /// Creates and renders a new world object.
    /// Returns nil if cap reached or spacing violated.
    func createObject(_ definition: WorldObjectDefinition) -> RenderedObject? {
        // Cap enforcement
        let persistentCount = objects.values.filter {
            $0.isActive && !$0.definition.isConsumable
        }.count
        let consumableCount = objects.values.filter {
            $0.isActive && $0.definition.isConsumable
        }.count

        if definition.isConsumable {
            guard consumableCount < Self.maxConsumables else {
                NSLog("[Pushling/Objects] Consumable cap reached (%d)",
                      Self.maxConsumables)
                return nil
            }
        } else {
            guard persistentCount < Self.maxPersistentObjects else {
                NSLog("[Pushling/Objects] Persistent object cap reached (%d)",
                      Self.maxPersistentObjects)
                return nil
            }
        }

        // Spacing check
        guard isSpacingValid(x: definition.positionX) else {
            NSLog("[Pushling/Objects] Too close to existing object at x=%.1f",
                  definition.positionX)
            return nil
        }

        // Node budget check
        let currentNodeCount = totalNodeCount
        guard currentNodeCount + 3 <= Self.maxObjectNodes else {
            NSLog("[Pushling/Objects] Node budget exceeded (%d/%d)",
                  currentNodeCount, Self.maxObjectNodes)
            return nil
        }

        // Build the node
        let node = buildNode(for: definition)
        node.position = CGPoint(x: definition.positionX,
                                 y: SceneConstants.groundY)

        // Route to correct parallax layer
        let targetLayer = layerNodes[definition.layer]
            ?? layerNodes["fore"] ?? parentNode
        targetLayer?.addChild(node)

        // Apply depth scaling and atmospheric perspective for non-fore layers
        switch definition.layer {
        case "far":
            node.setScale(definition.size * 0.5)
            applyAtmosphericDepth(to: node, depth: 0.85)
        case "mid":
            node.setScale(definition.size * 0.75)
            applyAtmosphericDepth(to: node, depth: 0.4)
        default:
            break  // "fore" uses definition.size as-is (applied in buildNode)
        }

        let rendered = RenderedObject(
            id: definition.id,
            definition: definition,
            node: node,
            createdAt: Date()
        )
        objects[definition.id] = rendered

        NSLog("[Pushling/Objects] Created '%@' (%@) at x=%.1f",
              definition.name, definition.baseShape, definition.positionX)

        return rendered
    }

    // MARK: - Node Building

    /// Builds an SKNode for an object definition.
    /// Tries composite shape first; falls back to single shape + coloring.
    /// Effects are always applied on top.
    private func buildNode(for def: WorldObjectDefinition) -> SKNode {
        let container = SKNode()
        container.name = "worldObject_\(def.id)"

        // Try composite shape first (multi-node design with built-in coloring)
        if let composite = CompositeShapeFactory.buildCompositeShape(
            presetName: def.name, baseShape: def.baseShape, size: def.size
        ) {
            composite.name = "base"  // For LOD and wear tracking
            container.addChild(composite)
        } else {
            // Fall back to single shape with generic coloring
            let baseNode = ObjectShapeFactory.buildBaseShape(def.baseShape, size: def.size)
            ObjectShapeFactory.applyColor(to: baseNode, primary: def.primaryColor,
                                           secondary: def.secondaryColor,
                                           pattern: def.colorPattern)
            container.addChild(baseNode)
        }

        // Effects (built by factory)
        for effect in def.effects {
            if let effectNode = ObjectShapeFactory.buildEffect(
                effect, size: def.size, color: def.primaryColor) {
                container.addChild(effectNode)
            }
        }

        return container
    }

    // MARK: - Per-Frame Update

    /// Updates LOD, effects animations, and wear visuals.
    func update(deltaTime: TimeInterval, cameraWorldX: CGFloat) {
        self.cameraWorldX = cameraWorldX
        effectsTime += deltaTime

        for (id, obj) in objects where obj.isActive {
            // Skip LOD for far/mid layer objects (parallax compression keeps them visible)
            let isForeground = obj.definition.layer == "fore"

            if isForeground {
                let distance = abs(obj.definition.positionX - cameraWorldX)

                // LOD culling
                if distance > Self.lodReducedDistance {
                    obj.node.isHidden = true
                    continue
                } else {
                    obj.node.isHidden = false
                }

                // Reduced LOD: hide effects and composite detail
                let fullLOD = distance <= Self.lodFullDistance
                for child in obj.node.children {
                    if child.name?.hasPrefix("effect_") == true {
                        child.isHidden = !fullLOD
                    }
                    // For composite bases, hide all but first grandchild at reduced LOD
                    if !fullLOD, child.name == "base",
                       child.children.count > 1 {
                        for (gi, grandchild) in child.children.enumerated() {
                            grandchild.isHidden = gi > 0
                        }
                    } else if fullLOD, child.name == "base" {
                        for grandchild in child.children {
                            grandchild.isHidden = false
                        }
                    }
                }

                // Animate effects
                if fullLOD {
                    animateEffects(for: obj, deltaTime: deltaTime)
                }
            } else {
                // Non-fore objects: always visible, always animate
                obj.node.isHidden = false
                animateEffects(for: obj, deltaTime: deltaTime)
            }

            // Apply wear visuals
            applyWearVisuals(objectID: id)
        }
    }

    /// Animates active effects on an object.
    private func animateEffects(for obj: RenderedObject,
                                 deltaTime: TimeInterval) {
        let effects = obj.definition.effects

        if effects.contains("bob") {
            let bobY = sin(effectsTime * .pi) * 1.0  // +/- 1pt, 2s period
            obj.node.position.y = SceneConstants.groundY + CGFloat(bobY)
        }

        if effects.contains("pulse") {
            let scale = 0.95 + 0.1 * CGFloat(sin(effectsTime * .pi * 1.33))
            obj.node.setScale(scale)
        }

        if effects.contains("spin") {
            obj.node.zRotation = CGFloat(effectsTime * .pi * 0.5)
        }

        if effects.contains("sway") {
            let angle = 0.087 * CGFloat(sin(effectsTime * .pi * 0.67))
            obj.node.zRotation = angle
        }

        // Glow pulse
        if effects.contains("glow") {
            for child in obj.node.children where child.name == "effect_glow" {
                child.alpha = CGFloat(0.1 + 0.1 * sin(effectsTime * .pi))
            }
        }
    }

    // MARK: - Wear Visuals

    /// Applies visual wear to an object based on its wear level.
    /// Works for both single SKShapeNode bases and composite SKNode containers.
    private func applyWearVisuals(objectID: String) {
        guard let obj = objects[objectID] else { return }
        let wear = obj.wear

        guard let baseNode = obj.node.children.first(where: { $0.name == "base" }) else {
            return
        }

        if wear > 0.6 {
            // Weathered: desaturation + slight offset
            baseNode.alpha = 0.7
            baseNode.position.x = CGFloat.random(in: -0.3...0.3)
        } else if wear > 0.3 {
            // Worn: slight desaturation
            baseNode.alpha = 0.85
        } else {
            baseNode.alpha = 1.0
            baseNode.position.x = 0
        }
    }

    // MARK: - Object Management

    /// Removes an object from rendering (moves to legacy shelf).
    func removeObject(id: String) -> RenderedObject? {
        guard var obj = objects.removeValue(forKey: id) else { return nil }
        obj.node.removeFromParent()
        obj.isActive = false
        NSLog("[Pushling/Objects] Removed '%@'", obj.definition.name)
        return obj
    }

    /// Updates wear on an object after interaction.
    func applyWear(objectID: String, amount: Double) {
        guard var obj = objects[objectID] else { return }
        obj.wear = Swift.min(obj.wear + amount, 1.0)
        obj.lastInteractedAt = Date()
        objects[objectID] = obj
    }

    /// Repairs an object (resets wear, adds patch mark).
    func repairObject(objectID: String) {
        guard var obj = objects[objectID] else { return }
        obj.wear = 0.0
        obj.repairCount += 1
        objects[objectID] = obj
        NSLog("[Pushling/Objects] Repaired '%@' (patch count: %d)",
              obj.definition.name, obj.repairCount)
    }

    /// Sets the wear value on a rendered object (syncs from ObjectWearSystem).
    func setWear(objectID: String, value: Double) {
        guard var obj = objects[objectID] else { return }
        obj.wear = value
        objects[objectID] = obj
    }

    /// Updates a rendered object's metadata (e.g., setting dbID after DB insert).
    func updateObject(id: String, _ mutator: (inout RenderedObject) -> Void) {
        guard var obj = objects[id] else { return }
        mutator(&obj)
        objects[id] = obj
    }

    // MARK: - Atmospheric Depth

    /// Applies atmospheric perspective to a node and its SKShapeNode children.
    /// Adjusts fill/stroke colors using PushlingPalette.atmosphericColor.
    private func applyAtmosphericDepth(to node: SKNode, depth: CGFloat) {
        for child in node.children {
            if let shape = child as? SKShapeNode {
                shape.fillColor = PushlingPalette.atmosphericColor(
                    shape.fillColor, depth: depth)
                if shape.strokeColor != .clear {
                    shape.strokeColor = PushlingPalette.atmosphericColor(
                        shape.strokeColor, depth: depth)
                }
            }
            if !child.children.isEmpty {
                applyAtmosphericDepth(to: child, depth: depth)
            }
        }
    }

    // MARK: - Queries

    /// Returns the nearest object to a world-X position.
    func nearestObject(to worldX: CGFloat,
                       maxDistance: CGFloat = 30) -> RenderedObject? {
        return objects.values
            .filter { $0.isActive }
            .filter { abs($0.definition.positionX - worldX) <= maxDistance }
            .min { abs($0.definition.positionX - worldX)
                < abs($1.definition.positionX - worldX) }
    }

    /// Returns all active objects.
    var activeObjects: [RenderedObject] {
        objects.values.filter(\.isActive)
    }

    /// Total node count from all objects.
    var totalNodeCount: Int {
        objects.values.filter(\.isActive).reduce(0) { $0 + $1.nodeCount }
    }

    /// Whether spacing is valid for a new object at the given X.
    private func isSpacingValid(x: CGFloat) -> Bool {
        for obj in objects.values where obj.isActive {
            if abs(obj.definition.positionX - x) < Self.minimumSpacing {
                return false
            }
        }
        return true
    }

    /// Suggests a valid X position near the requested one.
    func suggestPosition(near requestedX: CGFloat) -> CGFloat {
        var x = requestedX
        for _ in 0..<20 {
            if isSpacingValid(x: x) { return x }
            x += Self.minimumSpacing
            if x > SceneConstants.maxX {
                x = SceneConstants.minX + CGFloat.random(in: 0...100)
            }
        }
        return x
    }
}
