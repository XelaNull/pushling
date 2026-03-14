// LandmarkSystem.swift — Repo landmark system for the mid-parallax layer
// 9 landmark types: neon tower, fortress, obelisk, crystal, smoke stack,
// observatory, scroll tower, windmill, monolith.
// Each is a small SKNode composition (4-8pt tall) in Ash silhouette.
// Landmarks are permanent — they persist in the mid layer as the creature walks.
//
// The windmill has animated spinning blades (1 revolution per 4s).
// The smoke stack uses a minimal particle effect (3-5 particles/sec).
//
// Repo analysis heuristics live in RepoAnalyzer.swift (extension on this class).

import SpriteKit

// MARK: - Landmark Type

/// The 9 repo landmark types, mapped from repo analysis.
enum LandmarkType: String, CaseIterable {
    case neonTower    // Web app
    case fortress     // API/backend
    case obelisk      // CLI tool
    case crystal      // Library/package
    case smokeStack   // Infra/DevOps
    case observatory  // Data/ML
    case scrollTower  // Docs/content
    case windmill     // Game/creative
    case monolith     // Generic/unknown
}

// MARK: - Repo Type Detection

/// Determines what type of repo a project is, for landmark assignment.
enum RepoType: String {
    case webApp
    case apiBackend
    case cliTool
    case library
    case infraDevOps
    case dataML
    case docsContent
    case gameCreative
    case generic

    /// Maps repo type to landmark type.
    var landmarkType: LandmarkType {
        switch self {
        case .webApp:       return .neonTower
        case .apiBackend:   return .fortress
        case .cliTool:      return .obelisk
        case .library:      return .crystal
        case .infraDevOps:  return .smokeStack
        case .dataML:       return .observatory
        case .docsContent:  return .scrollTower
        case .gameCreative: return .windmill
        case .generic:      return .monolith
        }
    }
}

// MARK: - Landmark Data

/// Persistent landmark data — stored in SQLite, rendered in the mid layer.
struct LandmarkData {
    let repoName: String
    let landmarkType: LandmarkType
    let worldX: CGFloat   // Position in world-space (mid-layer coordinates)
    let createdAt: Date
}

// MARK: - LandmarkSystem

/// Manages repo landmarks on the mid-parallax layer.
/// Landmarks are permanent structures that grow as the developer tracks more repos.
final class LandmarkSystem {

    // MARK: - Constants

    /// Minimum spacing between landmarks in world-space.
    static let minSpacing: CGFloat = 80

    /// Base Y position for landmarks (sitting on a "horizon line").
    static let baselineY: CGFloat = 6.0

    /// Landmark base color.
    static let landmarkColor = PushlingPalette.ash

    // MARK: - Properties

    /// All registered landmarks.
    private(set) var landmarks: [LandmarkData] = []

    /// Active landmark nodes, keyed by repo name.
    private var landmarkNodes: [String: SKNode] = [:]

    /// The mid layer to add landmarks to.
    private weak var midLayer: SKNode?

    /// Next available world-X for placing a new landmark.
    private var nextWorldX: CGFloat = 100

    // MARK: - Initialization

    init(midLayer: SKNode) {
        self.midLayer = midLayer
    }

    // MARK: - Landmark Registration

    /// Adds a new repo landmark to the world.
    /// Position is deterministic from repo name hash + creation order.
    func addLandmark(repoName: String, repoType: RepoType) {
        guard !landmarks.contains(where: { $0.repoName == repoName }) else { return }

        let type = repoType.landmarkType
        let worldX = nextAvailablePosition(for: repoName)

        let data = LandmarkData(
            repoName: repoName,
            landmarkType: type,
            worldX: worldX,
            createdAt: Date()
        )
        landmarks.append(data)

        let node = createLandmarkNode(type: type, repoName: repoName)
        node.position = CGPoint(x: worldX, y: Self.baselineY)
        midLayer?.addChild(node)
        landmarkNodes[repoName] = node

        nextWorldX = worldX + Self.minSpacing
    }

    /// Loads landmarks from persisted data (e.g., SQLite on launch).
    func loadLandmarks(_ data: [LandmarkData]) {
        for landmark in data {
            landmarks.append(landmark)
            let node = createLandmarkNode(
                type: landmark.landmarkType,
                repoName: landmark.repoName
            )
            node.position = CGPoint(x: landmark.worldX, y: Self.baselineY)
            midLayer?.addChild(node)
            landmarkNodes[landmark.repoName] = node

            nextWorldX = max(nextWorldX, landmark.worldX + Self.minSpacing)
        }
    }

    /// Returns the landmark nearest to a world-X position, if within range.
    func nearestLandmark(to worldX: CGFloat,
                         maxDistance: CGFloat = 60) -> LandmarkData? {
        return landmarks.min(by: {
            abs($0.worldX - worldX) < abs($1.worldX - worldX)
        }).flatMap {
            abs($0.worldX - worldX) <= maxDistance ? $0 : nil
        }
    }

    // MARK: - Private: Position Calculation

    private func nextAvailablePosition(for repoName: String) -> CGFloat {
        var hash: UInt64 = 5381
        for char in repoName.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        let jitter = CGFloat(hash % 40) - 20
        return nextWorldX + jitter
    }

    // MARK: - Private: Node Creation

    private func createLandmarkNode(type: LandmarkType,
                                     repoName: String) -> SKNode {
        let node: SKNode
        switch type {
        case .neonTower:    node = makeNeonTower()
        case .fortress:     node = makeFortress()
        case .obelisk:      node = makeObelisk()
        case .crystal:      node = makeCrystal()
        case .smokeStack:   node = makeSmokeStack()
        case .observatory:  node = makeObservatory()
        case .scrollTower:  node = makeScrollTower()
        case .windmill:     node = makeWindmill()
        case .monolith:     node = makeMonolith()
        }
        node.name = "landmark_\(repoName)"
        return node
    }

    // MARK: - Landmark Shapes

    /// Neon tower — glowing vertical line with antenna. 6pt tall.
    private func makeNeonTower() -> SKNode {
        let container = SKNode()

        let body = SKShapeNode(rectOf: CGSize(width: 2, height: 6))
        body.fillColor = Self.landmarkColor
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 3)
        container.addChild(body)

        let antenna = SKShapeNode(rectOf: CGSize(width: 0.5, height: 2))
        antenna.fillColor = PushlingPalette.tide.withAlphaComponent(0.7)
        antenna.strokeColor = .clear
        antenna.position = CGPoint(x: 0, y: 7)
        container.addChild(antenna)

        let glow = SKShapeNode(circleOfRadius: 0.5)
        glow.fillColor = PushlingPalette.tide
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 8)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])), withKey: "blink")
        container.addChild(glow)

        return container
    }

    /// Fortress — blocky castle silhouette. 6pt tall.
    private func makeFortress() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -4, y: 0))
        path.addLine(to: CGPoint(x: -4, y: 5))
        path.addLine(to: CGPoint(x: -3, y: 5))
        path.addLine(to: CGPoint(x: -3, y: 6))
        path.addLine(to: CGPoint(x: -1.5, y: 6))
        path.addLine(to: CGPoint(x: -1.5, y: 5))
        path.addLine(to: CGPoint(x: 1.5, y: 5))
        path.addLine(to: CGPoint(x: 1.5, y: 6))
        path.addLine(to: CGPoint(x: 3, y: 6))
        path.addLine(to: CGPoint(x: 3, y: 5))
        path.addLine(to: CGPoint(x: 4, y: 5))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.closeSubpath()

        let fortress = SKShapeNode(path: path)
        fortress.fillColor = Self.landmarkColor
        fortress.strokeColor = .clear
        return fortress
    }

    /// Obelisk — tall thin pointed shape. 8pt tall.
    private func makeObelisk() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.5, y: 0))
        path.addLine(to: CGPoint(x: -1, y: 6))
        path.addLine(to: CGPoint(x: 0, y: 8))
        path.addLine(to: CGPoint(x: 1, y: 6))
        path.addLine(to: CGPoint(x: 1.5, y: 0))
        path.closeSubpath()

        let obelisk = SKShapeNode(path: path)
        obelisk.fillColor = Self.landmarkColor
        obelisk.strokeColor = .clear
        return obelisk
    }

    /// Crystal — geometric faceted shape. 5pt tall.
    private func makeCrystal() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 2))
        path.addLine(to: CGPoint(x: -1, y: 5))
        path.addLine(to: CGPoint(x: 1, y: 5))
        path.addLine(to: CGPoint(x: 2, y: 2))
        path.closeSubpath()

        let crystal = SKShapeNode(path: path)
        crystal.fillColor = PushlingPalette.lerp(
            from: Self.landmarkColor, to: PushlingPalette.dusk, t: 0.3)
        crystal.strokeColor = PushlingPalette.dusk.withAlphaComponent(0.3)
        crystal.lineWidth = 0.5
        return crystal
    }

    /// Smoke stack — tower with particle smoke wisps. 6pt tall.
    private func makeSmokeStack() -> SKNode {
        let container = SKNode()

        let tower = SKShapeNode(rectOf: CGSize(width: 2.5, height: 6))
        tower.fillColor = Self.landmarkColor
        tower.strokeColor = .clear
        tower.position = CGPoint(x: 0, y: 3)
        container.addChild(tower)

        let cap = SKShapeNode(rectOf: CGSize(width: 3.5, height: 1))
        cap.fillColor = Self.landmarkColor
        cap.strokeColor = .clear
        cap.position = CGPoint(x: 0, y: 6.5)
        container.addChild(cap)

        addSmokeParticle(to: container, delay: 0)
        addSmokeParticle(to: container, delay: 1.3)
        addSmokeParticle(to: container, delay: 2.6)

        return container
    }

    private func addSmokeParticle(to container: SKNode, delay: TimeInterval) {
        let smoke = SKShapeNode(circleOfRadius: 0.5)
        smoke.fillColor = PushlingPalette.ash.withAlphaComponent(0.4)
        smoke.strokeColor = .clear
        smoke.position = CGPoint(x: 0, y: 7)
        smoke.alpha = 0

        let cycle = SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 1.5, y: 4, duration: 3.0),
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.4, duration: 0.5),
                        SKAction.fadeAlpha(to: 0, duration: 2.5)
                    ]),
                    SKAction.scale(to: 2.0, duration: 3.0)
                ]),
                SKAction.run { [weak smoke] in
                    smoke?.position = CGPoint(x: 0, y: 7)
                    smoke?.setScale(1.0)
                }
            ]))
        ])
        smoke.run(cycle, withKey: "smoke")
        container.addChild(smoke)
    }

    /// Observatory — dome shape with tiny star. 5pt tall.
    private func makeObservatory() -> SKNode {
        let container = SKNode()

        let base = SKShapeNode(rectOf: CGSize(width: 5, height: 2))
        base.fillColor = Self.landmarkColor
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: 1)
        container.addChild(base)

        let domePath = CGMutablePath()
        domePath.addArc(center: CGPoint(x: 0, y: 2), radius: 2.5,
                        startAngle: 0, endAngle: .pi, clockwise: false)
        domePath.closeSubpath()
        let dome = SKShapeNode(path: domePath)
        dome.fillColor = Self.landmarkColor
        dome.strokeColor = .clear
        container.addChild(dome)

        let star = SKShapeNode(circleOfRadius: 0.5)
        star.fillColor = PushlingPalette.gilt
        star.strokeColor = .clear
        star.position = CGPoint(x: 0, y: 5)
        star.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 1.2),
            SKAction.fadeAlpha(to: 1.0, duration: 1.2)
        ])), withKey: "twinkle")
        container.addChild(star)

        return container
    }

    /// Scroll tower — curved architecture. 5pt tall.
    private func makeScrollTower() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -2, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 4))
        path.addQuadCurve(to: CGPoint(x: 2, y: 4),
                          control: CGPoint(x: 0, y: 6))
        path.addLine(to: CGPoint(x: 2, y: 0))
        path.closeSubpath()

        let tower = SKShapeNode(path: path)
        tower.fillColor = Self.landmarkColor
        tower.strokeColor = .clear
        return tower
    }

    /// Windmill — spinning blades (1 revolution per 4s). 6pt tall.
    private func makeWindmill() -> SKNode {
        let container = SKNode()

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -1.5, y: 0))
        bodyPath.addLine(to: CGPoint(x: -1, y: 5))
        bodyPath.addLine(to: CGPoint(x: 1, y: 5))
        bodyPath.addLine(to: CGPoint(x: 1.5, y: 0))
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = Self.landmarkColor
        body.strokeColor = .clear
        container.addChild(body)

        let hub = SKNode()
        hub.position = CGPoint(x: 0, y: 5)
        container.addChild(hub)

        for i in 0..<4 {
            let arm = SKNode()
            arm.zRotation = CGFloat(i) * (.pi / 2.0)
            let blade = SKShapeNode(rectOf: CGSize(width: 0.5, height: 3))
            blade.fillColor = PushlingPalette.bone.withAlphaComponent(0.6)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: 0, y: 1.5)
            arm.addChild(blade)
            hub.addChild(arm)
        }

        hub.run(SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: 4.0)
        ), withKey: "spin")

        return container
    }

    /// Monolith — simple tall rectangle. 6pt tall.
    private func makeMonolith() -> SKNode {
        let monolith = SKShapeNode(rectOf: CGSize(width: 2, height: 6))
        monolith.fillColor = Self.landmarkColor
        monolith.strokeColor = .clear
        monolith.position = CGPoint(x: 0, y: 3)
        return monolith
    }
}
