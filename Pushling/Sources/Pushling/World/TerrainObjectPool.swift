// TerrainObjectPool.swift — Terrain object types and biome-weighted selection
// 10 object types rendered as SKShapeNode geometric silhouettes on OLED black.
// Each biome has weighted pools: primary (70%), secondary (25%), rare (5%).
// Interactive objects (yarn balls, cardboard boxes) are globally capped at 2.
//
// Objects are 3-8pt tall, sitting on the terrain surface.

import SpriteKit

// MARK: - Terrain Object Type

/// The 10 terrain object types that populate the world.
enum TerrainObjectType: String, CaseIterable {
    case grassTuft
    case flower
    case tree
    case mushroom
    case rock
    case waterPuddle
    case starFragment
    case ruinPillar
    case yarnBall
    case cardboardBox

    /// Whether this object is interactive (creature can play with it).
    var isInteractive: Bool {
        self == .yarnBall || self == .cardboardBox
    }

    /// The height of this object in points.
    var height: CGFloat {
        switch self {
        case .grassTuft:    return 3
        case .flower:       return 4
        case .tree:         return 8
        case .mushroom:     return 4
        case .rock:         return 3
        case .waterPuddle:  return 1
        case .starFragment: return 3
        case .ruinPillar:   return 6
        case .yarnBall:     return 4
        case .cardboardBox: return 5
        }
    }

    /// The width of this object in points.
    var width: CGFloat {
        switch self {
        case .grassTuft:    return 4
        case .flower:       return 3
        case .tree:         return 6
        case .mushroom:     return 4
        case .rock:         return 5
        case .waterPuddle:  return 8
        case .starFragment: return 3
        case .ruinPillar:   return 3
        case .yarnBall:     return 4
        case .cardboardBox: return 6
        }
    }
}

// MARK: - Biome Object Pool

/// Weighted object pool for a specific biome.
struct BiomeObjectPool {

    /// Primary objects — 70% chance of selection.
    let primary: [TerrainObjectType]

    /// Secondary objects — 25% chance.
    let secondary: [TerrainObjectType]

    /// Rare objects — 5% chance.
    let rare: [TerrainObjectType]

    /// Selects an object type using weighted random based on a noise value.
    /// - Parameter noiseValue: Integer noise 0-255 for deterministic selection.
    /// - Returns: The selected object type.
    func selectObject(noiseValue: Int) -> TerrainObjectType {
        let threshold70 = 179   // 70% of 256
        let threshold95 = 243   // 95% of 256

        if noiseValue < threshold70 {
            let idx = noiseValue % max(1, primary.count)
            return primary[idx]
        } else if noiseValue < threshold95 {
            let idx = (noiseValue - threshold70) % max(1, secondary.count)
            return secondary[idx]
        } else {
            let idx = (noiseValue - threshold95) % max(1, rare.count)
            return rare[idx]
        }
    }
}

// MARK: - Pool Definitions

extension BiomeObjectPool {

    /// Returns the object pool for a given biome.
    static func pool(for biome: BiomeType) -> BiomeObjectPool {
        switch biome {
        case .plains:
            return BiomeObjectPool(
                primary:   [.grassTuft, .flower, .rock],
                secondary: [.yarnBall, .cardboardBox],
                rare:      [.starFragment, .ruinPillar]
            )
        case .forest:
            return BiomeObjectPool(
                primary:   [.tree, .mushroom, .grassTuft],
                secondary: [.flower, .rock],
                rare:      [.ruinPillar, .starFragment]
            )
        case .desert:
            return BiomeObjectPool(
                primary:   [.rock, .ruinPillar],
                secondary: [.starFragment],
                rare:      [.cardboardBox, .yarnBall]
            )
        case .wetlands:
            return BiomeObjectPool(
                primary:   [.waterPuddle, .grassTuft],
                secondary: [.mushroom, .flower],
                rare:      [.starFragment, .ruinPillar]
            )
        case .mountains:
            return BiomeObjectPool(
                primary:   [.rock, .rock],
                secondary: [.starFragment],
                rare:      [.ruinPillar, .cardboardBox]
            )
        }
    }

    /// Selects an object from blended biome pools.
    /// During biome transitions, this uses the blend factor to
    /// choose from either biome's pool.
    ///
    /// - Parameters:
    ///   - blend: The biome blend state at this position.
    ///   - noiseValue: Deterministic noise 0-255 for object selection.
    ///   - blendNoise: Secondary noise 0-255 for pool blending.
    /// - Returns: The selected terrain object type.
    static func selectFromBlend(
        blend: BiomeBlend,
        noiseValue: Int,
        blendNoise: Int
    ) -> TerrainObjectType {
        let primaryPool = pool(for: blend.primary)

        guard let secondary = blend.secondary, blend.blendFactor > 0.01 else {
            return primaryPool.selectObject(noiseValue: noiseValue)
        }

        // Use blendNoise to decide which pool to draw from
        let threshold = Int(blend.blendFactor * 256.0)
        if blendNoise < threshold {
            let secondaryPool = pool(for: secondary)
            return secondaryPool.selectObject(noiseValue: noiseValue)
        } else {
            return primaryPool.selectObject(noiseValue: noiseValue)
        }
    }
}

// MARK: - Terrain Object Node Factory

/// Creates SKShapeNode geometric silhouettes for terrain objects.
/// All objects are rendered as simple shapes against OLED true black.
enum TerrainObjectNodeFactory {

    /// Creates an SKNode for the given terrain object type.
    /// The node's anchor is at the bottom-center (sits on terrain surface).
    ///
    /// - Parameters:
    ///   - type: The terrain object type to create.
    ///   - biome: The biome context (affects color tinting).
    /// - Returns: An SKNode positioned with origin at bottom-center.
    static func createNode(
        for type: TerrainObjectType,
        biome: BiomeType
    ) -> SKNode {
        switch type {
        case .grassTuft:    return makeGrassTuft(biome: biome)
        case .flower:       return makeFlower(biome: biome)
        case .tree:         return makeTree(biome: biome)
        case .mushroom:     return makeMushroom(biome: biome)
        case .rock:         return makeRock(biome: biome)
        case .waterPuddle:  return makeWaterPuddle()
        case .starFragment: return makeStarFragment()
        case .ruinPillar:   return makeRuinPillar()
        case .yarnBall:     return makeYarnBall()
        case .cardboardBox: return makeCardboardBox()
        }
    }

    // MARK: - Object Shapes

    /// Grass tuft — 2-3 thin vertical lines.
    private static func makeGrassTuft(biome: BiomeType) -> SKNode {
        let container = SKNode()
        container.name = "obj_grassTuft"
        let color = biome == .wetlands
            ? PushlingPalette.lerp(from: PushlingPalette.moss, to: PushlingPalette.tide, t: 0.3)
            : PushlingPalette.moss

        for i in -1...1 {
            let blade = SKShapeNode(rectOf: CGSize(width: 1, height: 3))
            blade.fillColor = color
            blade.strokeColor = .clear
            blade.position = CGPoint(x: CGFloat(i), y: 1.5)
            container.addChild(blade)
        }
        return container
    }

    /// Flower — thin stem with a small colored circle on top.
    private static func makeFlower(biome: BiomeType) -> SKNode {
        let container = SKNode()
        container.name = "obj_flower"

        let stem = SKShapeNode(rectOf: CGSize(width: 1, height: 3))
        stem.fillColor = PushlingPalette.moss
        stem.strokeColor = .clear
        stem.position = CGPoint(x: 0, y: 1.5)
        container.addChild(stem)

        let petal = SKShapeNode(circleOfRadius: 1)
        petal.fillColor = biome == .wetlands ? PushlingPalette.tide : PushlingPalette.gilt
        petal.strokeColor = .clear
        petal.position = CGPoint(x: 0, y: 3.5)
        container.addChild(petal)

        return container
    }

    /// Tree — vertical trunk with a triangular canopy.
    private static func makeTree(biome: BiomeType) -> SKNode {
        let container = SKNode()
        container.name = "obj_tree"

        // Trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: 1.5, height: 4))
        trunk.fillColor = PushlingPalette.ash
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: 2)
        container.addChild(trunk)

        // Canopy — triangle
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3, y: 4))
        path.addLine(to: CGPoint(x: 3, y: 4))
        path.addLine(to: CGPoint(x: 0, y: 8))
        path.closeSubpath()

        let canopy = SKShapeNode(path: path)
        canopy.fillColor = biome == .forest
            ? PushlingPalette.deepMoss
            : PushlingPalette.moss
        canopy.strokeColor = .clear
        container.addChild(canopy)

        return container
    }

    /// Mushroom — short stem with a rounded cap.
    private static func makeMushroom(biome: BiomeType) -> SKNode {
        let container = SKNode()
        container.name = "obj_mushroom"

        let stem = SKShapeNode(rectOf: CGSize(width: 1, height: 2))
        stem.fillColor = PushlingPalette.bone
        stem.strokeColor = .clear
        stem.position = CGPoint(x: 0, y: 1)
        container.addChild(stem)

        let cap = SKShapeNode(circleOfRadius: 2)
        cap.fillColor = biome == .forest ? PushlingPalette.ember : PushlingPalette.dusk
        cap.strokeColor = .clear
        cap.position = CGPoint(x: 0, y: 3)
        container.addChild(cap)

        return container
    }

    /// Rock — small irregular polygon (approximated as pentagon).
    private static func makeRock(biome: BiomeType) -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -2, y: 0))
        path.addLine(to: CGPoint(x: -2.5, y: 1.5))
        path.addLine(to: CGPoint(x: 0, y: 3))
        path.addLine(to: CGPoint(x: 2.5, y: 1.5))
        path.addLine(to: CGPoint(x: 2, y: 0))
        path.closeSubpath()

        let rock = SKShapeNode(path: path)
        rock.name = "obj_rock"
        rock.fillColor = biome == .mountains ? PushlingPalette.bone : PushlingPalette.ash
        rock.strokeColor = .clear
        return rock
    }

    /// Water puddle — flat oval with subtle blue tint.
    private static func makeWaterPuddle() -> SKNode {
        let puddle = SKShapeNode(ellipseOf: CGSize(width: 8, height: 1.5))
        puddle.name = "obj_waterPuddle"
        puddle.fillColor = PushlingPalette.tide.withAlphaComponent(0.6)
        puddle.strokeColor = .clear
        puddle.position = CGPoint(x: 0, y: 0.75)
        return puddle
    }

    /// Star fragment — small bright angular shape.
    private static func makeStarFragment() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 3))
        path.addLine(to: CGPoint(x: 0.8, y: 1))
        path.addLine(to: CGPoint(x: -0.8, y: 2))
        path.addLine(to: CGPoint(x: 0.8, y: 2))
        path.addLine(to: CGPoint(x: -0.8, y: 1))
        path.closeSubpath()

        let star = SKShapeNode(path: path)
        star.name = "obj_starFragment"
        star.fillColor = PushlingPalette.gilt
        star.strokeColor = .clear

        // Gentle glow pulse
        let fadeDown = SKAction.fadeAlpha(to: 0.5, duration: 1.5)
        fadeDown.timingMode = .easeInEaseOut
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 1.5)
        fadeUp.timingMode = .easeInEaseOut
        star.run(SKAction.repeatForever(
            SKAction.sequence([fadeDown, fadeUp])
        ), withKey: "glow")

        return star
    }

    /// Ruin pillar — tall thin rectangle with broken top edge.
    private static func makeRuinPillar() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.5, y: 0))
        path.addLine(to: CGPoint(x: -1.5, y: 5))
        path.addLine(to: CGPoint(x: -0.5, y: 5.5))
        path.addLine(to: CGPoint(x: 0.5, y: 4.5))
        path.addLine(to: CGPoint(x: 1.5, y: 6))
        path.addLine(to: CGPoint(x: 1.5, y: 0))
        path.closeSubpath()

        let pillar = SKShapeNode(path: path)
        pillar.name = "obj_ruinPillar"
        pillar.fillColor = PushlingPalette.ash
        pillar.strokeColor = .clear
        return pillar
    }

    /// Yarn ball — small circle with a trailing thread.
    private static func makeYarnBall() -> SKNode {
        let container = SKNode()
        container.name = "obj_yarnBall"

        let ball = SKShapeNode(circleOfRadius: 2)
        ball.fillColor = PushlingPalette.ember
        ball.strokeColor = .clear
        ball.position = CGPoint(x: 0, y: 2)
        container.addChild(ball)

        // Thread tail
        let thread = SKShapeNode(rectOf: CGSize(width: 3, height: 0.5))
        thread.fillColor = PushlingPalette.ember.withAlphaComponent(0.6)
        thread.strokeColor = .clear
        thread.position = CGPoint(x: 2, y: 0.5)
        thread.zRotation = -0.3
        container.addChild(thread)

        return container
    }

    /// Cardboard box — simple rectangle with fold line.
    private static func makeCardboardBox() -> SKNode {
        let container = SKNode()
        container.name = "obj_cardboardBox"

        let box = SKShapeNode(rectOf: CGSize(width: 6, height: 5))
        box.fillColor = PushlingPalette.ash
        box.strokeColor = PushlingPalette.bone.withAlphaComponent(0.3)
        box.lineWidth = 0.5
        box.position = CGPoint(x: 0, y: 2.5)
        container.addChild(box)

        // Fold line across top
        let fold = SKShapeNode(rectOf: CGSize(width: 5, height: 0.5))
        fold.fillColor = PushlingPalette.bone.withAlphaComponent(0.2)
        fold.strokeColor = .clear
        fold.position = CGPoint(x: 0, y: 4)
        container.addChild(fold)

        return container
    }
}
