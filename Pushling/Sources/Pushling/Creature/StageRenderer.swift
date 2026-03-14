// StageRenderer.swift — Builds geometric placeholder sprites for all 6 stages
// Uses SKShapeNode for cat-spirit silhouettes. Each stage has a distinct
// visual form with correct proportions and part visibility.
// These are placeholder shapes — will be replaced by texture atlases later.

import SpriteKit

// MARK: - Stage Renderer

/// Builds the complete body part node hierarchy for a given growth stage.
/// Returns a configured set of SKShapeNodes that form the creature's body.
enum StageRenderer {

    /// Result of building a stage — contains all nodes and their z-positions.
    struct StageNodes {
        let body: SKShapeNode
        let coreGlow: SKShapeNode?
        let head: SKNode
        let earLeft: SKShapeNode?
        let earRight: SKShapeNode?
        let eyeLeft: SKNode            // container node
        let eyeLeftShape: SKShapeNode   // actual eye shape
        let eyeRight: SKNode
        let eyeRightShape: SKShapeNode
        let mouth: SKShapeNode?
        let mouthShape: SKShapeNode?    // inner shape for animations
        let whiskerLeft: SKNode?
        let whiskerRight: SKNode?
        let tail: SKShapeNode?
        let pawFL: SKShapeNode?
        let pawFR: SKShapeNode?
        let pawBL: SKShapeNode?
        let pawBR: SKShapeNode?
        let aura: SKShapeNode?
        let particles: SKNode
    }

    // MARK: - Build Stage

    /// Build the complete node hierarchy for a growth stage.
    /// - Parameter stage: The target growth stage.
    /// - Returns: All body part nodes configured for this stage.
    static func build(stage: GrowthStage) -> StageNodes {
        guard let config = StageConfiguration.all[stage] else {
            fatalError("[Pushling] Unknown stage: \(stage)")
        }

        let w = config.size.width
        let h = config.size.height

        switch stage {
        case .spore:   return buildSpore(w: w, h: h)
        case .drop:    return buildDrop(w: w, h: h)
        case .critter: return buildCritter(w: w, h: h)
        case .beast:   return buildBeast(w: w, h: h)
        case .sage:    return buildSage(w: w, h: h)
        case .apex:    return buildApex(w: w, h: h)
        }
    }

    // MARK: - Spore (6x6) — Glowing Orb

    private static func buildSpore(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = SKShapeNode(circleOfRadius: w / 2)
        body.fillColor = PushlingPalette.bone
        body.strokeColor = .clear
        body.alpha = 0.9
        body.name = "body"
        body.zPosition = 10

        // Spore has no features — just eyes as faint inner dots
        let head = SKNode()
        head.name = "head"
        head.zPosition = 20

        let (eyeL, eyeLShape) = makeEye(radius: 0.5, xOff: -1.0,
                                          yOff: 0, name: "eye_left")
        eyeL.alpha = 0.3  // barely visible in spore
        let (eyeR, eyeRShape) = makeEye(radius: 0.5, xOff: 1.0,
                                          yOff: 0, name: "eye_right")
        eyeR.alpha = 0.3

        head.addChild(eyeL)
        head.addChild(eyeR)

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: nil, head: head,
            earLeft: nil, earRight: nil,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeR, eyeRightShape: eyeRShape,
            mouth: nil, mouthShape: nil,
            whiskerLeft: nil, whiskerRight: nil,
            tail: nil,
            pawFL: nil, pawFR: nil, pawBL: nil, pawBR: nil,
            aura: nil, particles: particles
        )
    }

    // MARK: - Drop (10x12) — Teardrop with Eyes

    private static func buildDrop(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = makeTeardrop(width: w, height: h)
        body.name = "body"
        body.zPosition = 10

        let head = SKNode()
        head.name = "head"
        head.position = CGPoint(x: 0, y: h * 0.15)
        head.zPosition = 20

        let eyeR: CGFloat = 1.0
        let eyeSpacing: CGFloat = w * 0.2
        let (eyeL, eyeLShape) = makeEye(radius: eyeR, xOff: -eyeSpacing,
                                          yOff: 0, name: "eye_left")
        let (eyeRN, eyeRShape) = makeEye(radius: eyeR, xOff: eyeSpacing,
                                            yOff: 0, name: "eye_right")
        head.addChild(eyeL)
        head.addChild(eyeRN)

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: nil, head: head,
            earLeft: nil, earRight: nil,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeRN, eyeRightShape: eyeRShape,
            mouth: nil, mouthShape: nil,
            whiskerLeft: nil, whiskerRight: nil,
            tail: nil,
            pawFL: nil, pawFR: nil, pawBL: nil, pawBR: nil,
            aura: nil, particles: particles
        )
    }

    // MARK: - Critter (14x16) — Small Kitten

    private static func buildCritter(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.6)
        body.name = "body"
        body.zPosition = 10

        let coreGlow = SKShapeNode(circleOfRadius: w * 0.15)
        coreGlow.fillColor = PushlingPalette.tide
        coreGlow.strokeColor = .clear
        coreGlow.alpha = 0.3
        coreGlow.name = "core_glow"
        coreGlow.zPosition = 5
        coreGlow.position = CGPoint(x: 0, y: -h * 0.05)

        let head = SKNode()
        head.name = "head"
        head.position = CGPoint(x: 0, y: h * 0.25)
        head.zPosition = 20

        let headShape = SKShapeNode(circleOfRadius: w * 0.3)
        headShape.fillColor = PushlingPalette.bone
        headShape.strokeColor = .clear
        headShape.name = "head_shape"
        head.addChild(headShape)

        let earL = makeEar(size: CGSize(width: 3, height: 4),
                           position: CGPoint(x: -w * 0.2, y: w * 0.25),
                           name: "ear_left", isLeft: true)
        let earR = makeEar(size: CGSize(width: 3, height: 4),
                           position: CGPoint(x: w * 0.2, y: w * 0.25),
                           name: "ear_right", isLeft: false)
        head.addChild(earL)
        head.addChild(earR)

        let eyeSpacing: CGFloat = w * 0.12
        let (eyeL, eyeLShape) = makeEye(radius: 1.2, xOff: -eyeSpacing,
                                          yOff: -0.5, name: "eye_left")
        let (eyeRN, eyeRShape) = makeEye(radius: 1.2, xOff: eyeSpacing,
                                            yOff: -0.5, name: "eye_right")
        head.addChild(eyeL)
        head.addChild(eyeRN)

        let (mouthNode, mouthInner) = makeMouth(width: w * 0.15,
            position: CGPoint(x: 0, y: -w * 0.2))
        head.addChild(mouthNode)

        let tail = makeTail(length: 5, thickness: 1.5,
                             position: CGPoint(x: -w * 0.4, y: -h * 0.1),
                             name: "tail")

        let pawPositions = pawRestPositions(bodyWidth: w, bodyHeight: h)
        let pawFL = makePaw(size: 2, position: pawPositions.fl,
                            name: "paw_fl")
        let pawFR = makePaw(size: 2, position: pawPositions.fr,
                            name: "paw_fr")
        let pawBL = makePaw(size: 2, position: pawPositions.bl,
                            name: "paw_bl")
        let pawBR = makePaw(size: 2, position: pawPositions.br,
                            name: "paw_br")

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: coreGlow, head: head,
            earLeft: earL, earRight: earR,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeRN, eyeRightShape: eyeRShape,
            mouth: mouthNode, mouthShape: mouthInner,
            whiskerLeft: nil, whiskerRight: nil,
            tail: tail,
            pawFL: pawFL, pawFR: pawFR, pawBL: pawBL, pawBR: pawBR,
            aura: nil, particles: particles
        )
    }

    // MARK: - Beast (18x20) — Confident Cat

    private static func buildBeast(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.55)
        body.name = "body"
        body.zPosition = 10

        let head = SKNode()
        head.name = "head"
        head.position = CGPoint(x: w * 0.15, y: h * 0.25)
        head.zPosition = 20

        let headShape = SKShapeNode(circleOfRadius: w * 0.25)
        headShape.fillColor = PushlingPalette.bone
        headShape.strokeColor = .clear
        headShape.name = "head_shape"
        head.addChild(headShape)

        let earL = makeEar(size: CGSize(width: 4, height: 5),
                           position: CGPoint(x: -w * 0.18, y: w * 0.22),
                           name: "ear_left", isLeft: true)
        let earR = makeEar(size: CGSize(width: 4, height: 5),
                           position: CGPoint(x: w * 0.18, y: w * 0.22),
                           name: "ear_right", isLeft: false)
        head.addChild(earL)
        head.addChild(earR)

        let eyeSpacing: CGFloat = w * 0.1
        let (eyeL, eyeLShape) = makeEye(radius: 1.5, xOff: -eyeSpacing,
                                          yOff: -0.5, name: "eye_left")
        let (eyeRN, eyeRShape) = makeEye(radius: 1.5, xOff: eyeSpacing,
                                            yOff: -0.5, name: "eye_right")
        head.addChild(eyeL)
        head.addChild(eyeRN)

        let (mouthNode, mouthInner) = makeMouth(width: w * 0.12,
            position: CGPoint(x: 0, y: -w * 0.18))
        head.addChild(mouthNode)

        let whiskerL = makeWhiskerGroup(
            position: CGPoint(x: -w * 0.2, y: -w * 0.1),
            name: "whisker_left", isLeft: true, count: 3, length: 5)
        let whiskerR = makeWhiskerGroup(
            position: CGPoint(x: w * 0.2, y: -w * 0.1),
            name: "whisker_right", isLeft: false, count: 3, length: 5)
        head.addChild(whiskerL)
        head.addChild(whiskerR)

        let tail = makeTail(length: 8, thickness: 2.0,
                             position: CGPoint(x: -w * 0.45, y: -h * 0.05),
                             name: "tail")

        let pawPositions = pawRestPositions(bodyWidth: w, bodyHeight: h)
        let pawFL = makePaw(size: 2.5, position: pawPositions.fl,
                            name: "paw_fl")
        let pawFR = makePaw(size: 2.5, position: pawPositions.fr,
                            name: "paw_fr")
        let pawBL = makePaw(size: 2.5, position: pawPositions.bl,
                            name: "paw_bl")
        let pawBR = makePaw(size: 2.5, position: pawPositions.br,
                            name: "paw_br")

        let aura = SKShapeNode(circleOfRadius: w * 0.7)
        aura.fillColor = PushlingPalette.bone
        aura.strokeColor = .clear
        aura.alpha = 0.08
        aura.name = "aura"
        aura.zPosition = 1

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: nil, head: head,
            earLeft: earL, earRight: earR,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeRN, eyeRightShape: eyeRShape,
            mouth: mouthNode, mouthShape: mouthInner,
            whiskerLeft: whiskerL, whiskerRight: whiskerR,
            tail: tail,
            pawFL: pawFL, pawFR: pawFR, pawBL: pawBL, pawBR: pawBR,
            aura: aura, particles: particles
        )
    }

    // MARK: - Sage (22x24) — Wise Cat Spirit

    private static func buildSage(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.5)
        body.name = "body"
        body.zPosition = 10

        let head = SKNode()
        head.name = "head"
        head.position = CGPoint(x: w * 0.12, y: h * 0.28)
        head.zPosition = 20

        let headShape = SKShapeNode(circleOfRadius: w * 0.22)
        headShape.fillColor = PushlingPalette.bone
        headShape.strokeColor = .clear
        headShape.name = "head_shape"
        head.addChild(headShape)

        // Third eye mark (faint)
        let thirdEye = SKShapeNode(circleOfRadius: 1.0)
        thirdEye.fillColor = PushlingPalette.dusk
        thirdEye.strokeColor = .clear
        thirdEye.alpha = 0.25
        thirdEye.position = CGPoint(x: 0, y: w * 0.15)
        thirdEye.name = "third_eye"
        head.addChild(thirdEye)

        let earL = makeEar(size: CGSize(width: 5, height: 6),
                           position: CGPoint(x: -w * 0.16, y: w * 0.2),
                           name: "ear_left", isLeft: true)
        let earR = makeEar(size: CGSize(width: 5, height: 6),
                           position: CGPoint(x: w * 0.16, y: w * 0.2),
                           name: "ear_right", isLeft: false)
        head.addChild(earL)
        head.addChild(earR)

        let eyeSpacing: CGFloat = w * 0.09
        let (eyeL, eyeLShape) = makeEye(radius: 1.5, xOff: -eyeSpacing,
                                          yOff: -1.0, name: "eye_left")
        let (eyeRN, eyeRShape) = makeEye(radius: 1.5, xOff: eyeSpacing,
                                            yOff: -1.0, name: "eye_right")
        head.addChild(eyeL)
        head.addChild(eyeRN)

        let (mouthNode, mouthInner) = makeMouth(width: w * 0.1,
            position: CGPoint(x: 0, y: -w * 0.16))
        head.addChild(mouthNode)

        let whiskerL = makeWhiskerGroup(
            position: CGPoint(x: -w * 0.18, y: -w * 0.08),
            name: "whisker_left", isLeft: true, count: 3, length: 6)
        let whiskerR = makeWhiskerGroup(
            position: CGPoint(x: w * 0.18, y: -w * 0.08),
            name: "whisker_right", isLeft: false, count: 3, length: 6)
        head.addChild(whiskerL)
        head.addChild(whiskerR)

        let tail = makeTail(length: 10, thickness: 2.0,
                             position: CGPoint(x: -w * 0.45, y: -h * 0.03),
                             name: "tail")

        let pawPositions = pawRestPositions(bodyWidth: w, bodyHeight: h)
        let pawFL = makePaw(size: 3, position: pawPositions.fl,
                            name: "paw_fl")
        let pawFR = makePaw(size: 3, position: pawPositions.fr,
                            name: "paw_fr")
        let pawBL = makePaw(size: 3, position: pawPositions.bl,
                            name: "paw_bl")
        let pawBR = makePaw(size: 3, position: pawPositions.br,
                            name: "paw_br")

        let aura = SKShapeNode(circleOfRadius: w * 0.8)
        aura.fillColor = PushlingPalette.gilt
        aura.strokeColor = .clear
        aura.alpha = 0.06
        aura.name = "aura"
        aura.zPosition = 1

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: nil, head: head,
            earLeft: earL, earRight: earR,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeRN, eyeRightShape: eyeRShape,
            mouth: mouthNode, mouthShape: mouthInner,
            whiskerLeft: whiskerL, whiskerRight: whiskerR,
            tail: tail,
            pawFL: pawFL, pawFR: pawFR, pawBL: pawBL, pawBR: pawBR,
            aura: aura, particles: particles
        )
    }

    // MARK: - Apex (25x28) — Transcendent Spirit

    private static func buildApex(w: CGFloat, h: CGFloat) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.5)
        body.name = "body"
        body.zPosition = 10
        body.alpha = 0.85 // semi-ethereal

        let head = SKNode()
        head.name = "head"
        head.position = CGPoint(x: w * 0.12, y: h * 0.3)
        head.zPosition = 20

        let headShape = SKShapeNode(circleOfRadius: w * 0.2)
        headShape.fillColor = PushlingPalette.bone
        headShape.strokeColor = .clear
        headShape.alpha = 0.9
        headShape.name = "head_shape"
        head.addChild(headShape)

        // Crown of tiny stars
        for i in 0..<5 {
            let angle = CGFloat(i) / 5.0 * .pi + .pi * 0.2
            let starR: CGFloat = w * 0.25
            let star = SKShapeNode(circleOfRadius: 0.8)
            star.fillColor = PushlingPalette.gilt
            star.strokeColor = .clear
            star.alpha = 0.7
            star.position = CGPoint(x: cos(angle) * starR,
                                     y: sin(angle) * starR + w * 0.1)
            star.name = "crown_star_\(i)"
            head.addChild(star)
        }

        let earL = makeEar(size: CGSize(width: 5, height: 7),
                           position: CGPoint(x: -w * 0.15, y: w * 0.18),
                           name: "ear_left", isLeft: true)
        let earR = makeEar(size: CGSize(width: 5, height: 7),
                           position: CGPoint(x: w * 0.15, y: w * 0.18),
                           name: "ear_right", isLeft: false)
        head.addChild(earL)
        head.addChild(earR)

        let eyeSpacing: CGFloat = w * 0.08
        let (eyeL, eyeLShape) = makeEye(radius: 1.8, xOff: -eyeSpacing,
                                          yOff: -1.0, name: "eye_left")
        let (eyeRN, eyeRShape) = makeEye(radius: 1.8, xOff: eyeSpacing,
                                            yOff: -1.0, name: "eye_right")
        head.addChild(eyeL)
        head.addChild(eyeRN)

        let (mouthNode, mouthInner) = makeMouth(width: w * 0.1,
            position: CGPoint(x: 0, y: -w * 0.14))
        head.addChild(mouthNode)

        let whiskerL = makeWhiskerGroup(
            position: CGPoint(x: -w * 0.16, y: -w * 0.06),
            name: "whisker_left", isLeft: true, count: 3, length: 7)
        let whiskerR = makeWhiskerGroup(
            position: CGPoint(x: w * 0.16, y: -w * 0.06),
            name: "whisker_right", isLeft: false, count: 3, length: 7)
        head.addChild(whiskerL)
        head.addChild(whiskerR)

        // Primary tail — apex can have multiple but start with one
        let tail = makeTail(length: 12, thickness: 2.0,
                             position: CGPoint(x: -w * 0.45, y: 0),
                             name: "tail")
        tail.alpha = 0.85

        let pawPositions = pawRestPositions(bodyWidth: w, bodyHeight: h)
        let pawFL = makePaw(size: 3, position: pawPositions.fl,
                            name: "paw_fl")
        let pawFR = makePaw(size: 3, position: pawPositions.fr,
                            name: "paw_fr")
        let pawBL = makePaw(size: 3, position: pawPositions.bl,
                            name: "paw_bl")
        let pawBR = makePaw(size: 3, position: pawPositions.br,
                            name: "paw_br")

        let aura = SKShapeNode(circleOfRadius: w * 1.0)
        aura.fillColor = PushlingPalette.bone
        aura.strokeColor = .clear
        aura.alpha = 0.05
        aura.name = "aura"
        aura.zPosition = 1

        let particles = SKNode()
        particles.name = "particles"
        particles.zPosition = 50

        return StageNodes(
            body: body, coreGlow: nil, head: head,
            earLeft: earL, earRight: earR,
            eyeLeft: eyeL, eyeLeftShape: eyeLShape,
            eyeRight: eyeRN, eyeRightShape: eyeRShape,
            mouth: mouthNode, mouthShape: mouthInner,
            whiskerLeft: whiskerL, whiskerRight: whiskerR,
            tail: tail,
            pawFL: pawFL, pawFR: pawFR, pawBL: pawBL, pawBR: pawBR,
            aura: aura, particles: particles
        )
    }
}

// MARK: - Shape Factory Helpers

extension StageRenderer {

    /// Make a teardrop body shape (for Drop stage).
    static func makeTeardrop(width: CGFloat,
                              height: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        // Rounded bottom, pointed top
        path.move(to: CGPoint(x: 0, y: height * 0.4))
        path.addQuadCurve(to: CGPoint(x: width * 0.4, y: -height * 0.2),
                          control: CGPoint(x: width * 0.45, y: height * 0.2))
        path.addQuadCurve(to: CGPoint(x: -width * 0.4, y: -height * 0.2),
                          control: CGPoint(x: 0, y: -height * 0.5))
        path.addQuadCurve(to: CGPoint(x: 0, y: height * 0.4),
                          control: CGPoint(x: -width * 0.45, y: height * 0.2))
        path.closeSubpath()

        let shape = SKShapeNode(path: path)
        shape.fillColor = PushlingPalette.bone
        shape.strokeColor = .clear
        return shape
    }

    /// Make an elliptical cat body shape.
    static func makeCatBody(width: CGFloat,
                             height: CGFloat) -> SKShapeNode {
        let body = SKShapeNode(ellipseOf: CGSize(width: width,
                                                   height: height))
        body.fillColor = PushlingPalette.bone
        body.strokeColor = .clear
        return body
    }

    /// Make a triangular ear shape.
    static func makeEar(size: CGSize, position: CGPoint,
                         name: String, isLeft: Bool) -> SKShapeNode {
        let path = CGMutablePath()
        let hw = size.width / 2
        path.move(to: CGPoint(x: -hw, y: 0))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: hw, y: 0))
        path.closeSubpath()

        let ear = SKShapeNode(path: path)
        ear.fillColor = PushlingPalette.bone
        ear.strokeColor = .clear
        ear.position = position
        ear.name = name
        ear.zPosition = 25
        // Anchor at base for natural rotation
        return ear
    }

    /// Make an eye container + shape.
    /// Returns (container SKNode, inner SKShapeNode).
    static func makeEye(radius: CGFloat, xOff: CGFloat, yOff: CGFloat,
                          name: String) -> (SKNode, SKShapeNode) {
        let container = SKNode()
        container.name = name
        container.position = CGPoint(x: xOff, y: yOff)
        container.zPosition = 30

        let shape = SKShapeNode(circleOfRadius: radius)
        shape.fillColor = PushlingPalette.bone
        shape.strokeColor = .clear
        shape.name = "\(name)_shape"
        container.addChild(shape)

        // Pupil
        let pupil = SKShapeNode(circleOfRadius: radius * 0.5)
        pupil.fillColor = PushlingPalette.void_
        pupil.strokeColor = .clear
        pupil.name = "\(name)_pupil"
        pupil.zPosition = 1
        container.addChild(pupil)

        return (container, shape)
    }

    /// Make a mouth node + inner shape for animation.
    static func makeMouth(width: CGFloat,
                           position: CGPoint) -> (SKShapeNode, SKShapeNode) {
        let outer = SKShapeNode()
        outer.position = position
        outer.name = "mouth"
        outer.zPosition = 25

        // Inner shape — a small line/arc
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: width / 2, y: 0),
                          control: CGPoint(x: 0, y: -width * 0.3))
        let inner = SKShapeNode(path: path)
        inner.strokeColor = PushlingPalette.ash
        inner.lineWidth = 0.5
        inner.fillColor = .clear
        inner.name = "mouth_inner"
        outer.addChild(inner)

        return (outer, inner)
    }

    /// Make a whisker group (3 lines radiating outward).
    static func makeWhiskerGroup(position: CGPoint, name: String,
                                   isLeft: Bool, count: Int,
                                   length: CGFloat) -> SKNode {
        let group = SKNode()
        group.position = position
        group.name = name
        group.zPosition = 22

        let dir: CGFloat = isLeft ? -1 : 1
        let spreadAngle: CGFloat = 0.3  // radians between whiskers

        for i in 0..<count {
            let angle = CGFloat(i - count / 2) * spreadAngle
            let endX = dir * cos(angle) * length
            let endY = sin(angle) * length * 0.5

            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: endX, y: endY))

            let whisker = SKShapeNode(path: path)
            whisker.strokeColor = PushlingPalette.ash
            whisker.lineWidth = 0.5
            whisker.alpha = 0.6
            whisker.name = "\(name)_\(i)"
            group.addChild(whisker)
        }

        return group
    }

    /// Make a tail shape (curved line).
    static func makeTail(length: CGFloat, thickness: CGFloat,
                          position: CGPoint,
                          name: String) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: .zero)
        // Gentle S-curve
        path.addCurve(
            to: CGPoint(x: -length * 0.6, y: length * 0.8),
            control1: CGPoint(x: -length * 0.3, y: 0),
            control2: CGPoint(x: -length * 0.7, y: length * 0.4)
        )

        let tail = SKShapeNode(path: path)
        tail.strokeColor = PushlingPalette.bone
        tail.lineWidth = thickness
        tail.lineCap = .round
        tail.fillColor = .clear
        tail.position = position
        tail.name = name
        tail.zPosition = 8
        return tail
    }

    /// Make a small circular paw.
    static func makePaw(size: CGFloat, position: CGPoint,
                         name: String) -> SKShapeNode {
        let paw = SKShapeNode(circleOfRadius: size / 2)
        paw.fillColor = PushlingPalette.bone
        paw.strokeColor = .clear
        paw.position = position
        paw.name = name
        paw.zPosition = 12
        return paw
    }

    /// Calculate resting paw positions relative to body center.
    static func pawRestPositions(bodyWidth w: CGFloat,
                                  bodyHeight h: CGFloat)
        -> (fl: CGPoint, fr: CGPoint, bl: CGPoint, br: CGPoint) {
        let frontX = w * 0.2
        let backX = w * 0.35
        let groundY = -h * 0.4

        return (
            fl: CGPoint(x:  frontX, y: groundY),
            fr: CGPoint(x:  frontX + 3.0, y: groundY),
            bl: CGPoint(x: -backX, y: groundY),
            br: CGPoint(x: -backX + 3.0, y: groundY)
        )
    }
}
