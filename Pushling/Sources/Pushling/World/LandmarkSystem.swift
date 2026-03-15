// LandmarkSystem.swift — 9 repo landmark types on the mid-parallax layer.
// Each is an SKNode composition (4-8pt tall) with atmospheric accent details.

import SpriteKit

// MARK: - Landmark Type

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

struct LandmarkData {
    let repoName: String
    let landmarkType: LandmarkType
    let worldX: CGFloat   // Position in world-space (mid-layer coordinates)
    let createdAt: Date
}

// MARK: - LandmarkSystem

/// Manages repo landmarks on the mid-parallax layer.
final class LandmarkSystem {

    static let minSpacing: CGFloat = 80
    static let baselineY: CGFloat = 6.0
    static let landmarkColor = PushlingPalette.ash

    private(set) var landmarks: [LandmarkData] = []
    private var landmarkNodes: [String: SKNode] = [:]
    private weak var midLayer: SKNode?
    private var nextWorldX: CGFloat = 100

    // MARK: - Initialization

    init(midLayer: SKNode) {
        self.midLayer = midLayer
    }

    // MARK: - Landmark Registration

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

    // MARK: - Landmark Accent Helper

    /// Returns an atmospheric mid-layer accent color for landmark details.
    private func accent(_ color: SKColor) -> SKColor {
        PushlingPalette.atmosphericColor(color, depth: 0.4)
    }

    // MARK: - Landmark Shapes

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
        for wy in [2.0, 4.5] as [CGFloat] {
            let win = SKShapeNode(circleOfRadius: 0.4)
            win.fillColor = accent(PushlingPalette.tide)
            win.strokeColor = .clear
            win.alpha = 0.4
            win.position = CGPoint(x: 0, y: wy)
            container.addChild(win)
        }

        return container
    }

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
        let container = SKNode()
        let fortress = SKShapeNode(path: path)
        fortress.fillColor = Self.landmarkColor
        fortress.strokeColor = .clear
        container.addChild(fortress)
        // Flag on the left tower
        let flag = SKShapeNode(rectOf: CGSize(width: 1.5, height: 1))
        flag.fillColor = accent(PushlingPalette.ember)
        flag.strokeColor = .clear
        flag.position = CGPoint(x: -3, y: 7.5)
        flag.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.1, duration: 1.0),
            SKAction.rotate(toAngle: -0.05, duration: 1.2)
        ])), withKey: "sway")
        container.addChild(flag)

        return container
    }

    private func makeObelisk() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.5, y: 0))
        path.addLine(to: CGPoint(x: -1, y: 6))
        path.addLine(to: CGPoint(x: 0, y: 8))
        path.addLine(to: CGPoint(x: 1, y: 6))
        path.addLine(to: CGPoint(x: 1.5, y: 0))
        path.closeSubpath()

        let container = SKNode()
        let obelisk = SKShapeNode(path: path)
        obelisk.fillColor = Self.landmarkColor
        obelisk.strokeColor = .clear
        container.addChild(obelisk)
        // Hieroglyph line
        let glyph = SKShapeNode(rectOf: CGSize(width: 0.3, height: 4))
        glyph.fillColor = accent(PushlingPalette.gilt)
        glyph.strokeColor = .clear
        glyph.alpha = 0.2
        glyph.position = CGPoint(x: 0, y: 3.5)
        container.addChild(glyph)

        return container
    }

    private func makeCrystal() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 2))
        path.addLine(to: CGPoint(x: -1, y: 5))
        path.addLine(to: CGPoint(x: 1, y: 5))
        path.addLine(to: CGPoint(x: 2, y: 2))
        path.closeSubpath()

        let container = SKNode()
        let crystal = SKShapeNode(path: path)
        crystal.fillColor = PushlingPalette.lerp(
            from: Self.landmarkColor, to: PushlingPalette.dusk, t: 0.3)
        crystal.strokeColor = PushlingPalette.dusk.withAlphaComponent(0.3)
        crystal.lineWidth = 0.5
        container.addChild(crystal)
        // Refraction lines
        for rx in [-0.5, 0.5] as [CGFloat] {
            let refr = SKShapeNode(rectOf: CGSize(width: 0.2, height: 2.5))
            refr.fillColor = accent(PushlingPalette.dusk)
            refr.strokeColor = .clear
            refr.alpha = 0.3
            refr.position = CGPoint(x: rx, y: 2.8)
            refr.zRotation = rx * 0.2
            container.addChild(refr)
        }
        // Twinkle
        let twinkle = SKShapeNode(circleOfRadius: 0.4)
        twinkle.fillColor = accent(PushlingPalette.dusk)
        twinkle.strokeColor = .clear
        twinkle.position = CGPoint(x: 0, y: 4.8)
        twinkle.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 0.9),
            SKAction.fadeAlpha(to: 0.6, duration: 0.9)
        ])), withKey: "twinkle")
        container.addChild(twinkle)

        return container
    }

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

        // Warning stripe on tower body
        let stripe = SKShapeNode(rectOf: CGSize(width: 2.5, height: 0.6))
        stripe.fillColor = accent(PushlingPalette.ember)
        stripe.strokeColor = .clear
        stripe.alpha = 0.3
        stripe.position = CGPoint(x: 0, y: 4)
        container.addChild(stripe)

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

        // Slit line in the dome
        let slit = SKShapeNode(rectOf: CGSize(width: 0.3, height: 2))
        slit.fillColor = accent(PushlingPalette.bone)
        slit.strokeColor = .clear
        slit.alpha = 0.3
        slit.position = CGPoint(x: 0, y: 3.2)
        container.addChild(slit)

        let star = SKShapeNode(circleOfRadius: 0.6)
        star.fillColor = PushlingPalette.gilt
        star.strokeColor = .clear
        star.position = CGPoint(x: 0, y: 5.5)
        star.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])), withKey: "twinkle")
        container.addChild(star)

        return container
    }

    private func makeScrollTower() -> SKNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -2, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 4))
        path.addQuadCurve(to: CGPoint(x: 2, y: 4),
                          control: CGPoint(x: 0, y: 6))
        path.addLine(to: CGPoint(x: 2, y: 0))
        path.closeSubpath()

        let container = SKNode()
        let tower = SKShapeNode(path: path)
        tower.fillColor = Self.landmarkColor
        tower.strokeColor = .clear
        container.addChild(tower)

        // Horizontal scroll-line markings
        for sy in [1.5, 3.0] as [CGFloat] {
            let line = SKShapeNode(rectOf: CGSize(width: 2.5, height: 0.2))
            line.fillColor = accent(PushlingPalette.bone)
            line.strokeColor = .clear
            line.alpha = 0.2
            line.position = CGPoint(x: 0, y: sy)
            container.addChild(line)
        }

        return container
    }

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

        // Window dot on body
        let win = SKShapeNode(circleOfRadius: 0.4)
        win.fillColor = accent(PushlingPalette.gilt)
        win.strokeColor = .clear
        win.alpha = 0.4
        win.position = CGPoint(x: 0, y: 3.5)
        container.addChild(win)

        // Door rect at base
        let door = SKShapeNode(rectOf: CGSize(width: 0.8, height: 1.2))
        door.fillColor = accent(PushlingPalette.gilt)
        door.strokeColor = .clear
        door.alpha = 0.4
        door.position = CGPoint(x: 0, y: 0.8)
        container.addChild(door)

        return container
    }

    private func makeMonolith() -> SKNode {
        let container = SKNode()
        let monolith = SKShapeNode(rectOf: CGSize(width: 2, height: 6))
        monolith.fillColor = Self.landmarkColor
        monolith.strokeColor = .clear
        monolith.position = CGPoint(x: 0, y: 3)
        container.addChild(monolith)

        // Crack line down the face
        let crack = SKShapeNode(rectOf: CGSize(width: 0.2, height: 3))
        crack.fillColor = accent(PushlingPalette.bone)
        crack.strokeColor = .clear
        crack.alpha = 0.2
        crack.position = CGPoint(x: 0.3, y: 3.5)
        crack.zRotation = 0.08
        container.addChild(crack)

        // Mossy base tint
        let moss = SKShapeNode(rectOf: CGSize(width: 2.4, height: 1))
        moss.fillColor = accent(PushlingPalette.moss)
        moss.strokeColor = .clear
        moss.alpha = 0.15
        moss.position = CGPoint(x: 0, y: 0.5)
        container.addChild(moss)

        return container
    }
}
