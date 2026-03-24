// StageRenderer.swift — Builds geometric pixel-art sprites for all 6 stages.
// Shape helpers are in ShapeFactory.swift.

import SpriteKit

/// Builds the complete body part node hierarchy for a given growth stage.
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
    /// - Parameters:
    ///   - stage: The target growth stage.
    ///   - repoCount: Number of tracked repos (drives Apex multi-tail count).
    /// - Returns: All body part nodes configured for this stage.
    static func build(stage: GrowthStage, repoCount: Int = 1,
                       visualTraits: VisualTraits = .neutral) -> StageNodes {
        guard let config = StageConfiguration.all[stage] else {
            fatalError("[Pushling] Unknown stage: \(stage)")
        }

        let w = config.size.width
        let h = config.size.height

        // Compute body color from visual traits — each creature has unique hue
        let bodyColor = SKColor(
            hue: CGFloat(visualTraits.baseColorHue),
            saturation: 0.25, brightness: 0.95, alpha: 1.0
        )

        // Apply body proportion scaling
        let propScale = CGFloat(visualTraits.bodyProportion)
        let wScaled = w * (0.9 + propScale * 0.2)   // 0.9x (lean) to 1.1x (round)
        let hScaled = h * (1.05 - propScale * 0.1)   // 1.05x (lean) to 0.95x (round)

        switch stage {
        case .egg:   return buildEgg(w: wScaled, h: hScaled, bodyColor: bodyColor)
        case .drop:    return buildDrop(w: wScaled, h: hScaled, bodyColor: bodyColor)
        case .critter: return buildCritter(w: wScaled, h: hScaled, bodyColor: bodyColor)
        case .beast:   return buildBeast(w: wScaled, h: hScaled, bodyColor: bodyColor)
        case .sage:    return buildSage(w: wScaled, h: hScaled, bodyColor: bodyColor)
        case .apex:    return buildApex(w: wScaled, h: hScaled, repoCount: repoCount, bodyColor: bodyColor)
        }
    }

    // MARK: - Egg (9x11) — Bouncy Oval

    private static func buildEgg(w: CGFloat, h: CGFloat,
                                   bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        // Egg shape — smooth oval, taller than wide, no features
        let body = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        body.fillColor = bodyColor
        body.strokeColor = SKColor(white: 0.7, alpha: 0.3)
        body.lineWidth = 0.5
        body.alpha = 0.95
        body.name = "body"
        body.zPosition = 10

        // Subtle inner glow — the life growing inside
        let coreGlow = SKShapeNode(
            ellipseOf: CGSize(width: w * 0.4, height: h * 0.4)
        )
        coreGlow.fillColor = bodyColor.withAlphaComponent(0.3)
        coreGlow.strokeColor = .clear
        coreGlow.name = "core_glow"
        coreGlow.zPosition = 5
        body.addChild(coreGlow)

        // No head, eyes, ears, tail — just an egg
        let head = SKNode()
        head.name = "head"
        head.zPosition = 20

        let (eyeL, eyeLShape) = makeEye(radius: 0.3, xOff: 0,
                                          yOff: 0, name: "eye_left")
        eyeL.alpha = 0  // invisible on egg
        let (eyeR, eyeRShape) = makeEye(radius: 0.3, xOff: 0,
                                          yOff: 0, name: "eye_right")
        eyeR.alpha = 0  // invisible on egg

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

    private static func buildDrop(w: CGFloat, h: CGFloat,
                                    bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        let body = makeTeardrop(width: w, height: h, color: bodyColor)
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

        // Proto-ear buds — small triangles emerging above body
        let protoEarL = makeProtoEar(
            radius: 1.5,
            position: CGPoint(x: -w * 0.25, y: h * 0.3),
            alpha: 0.3
        )
        let protoEarR = makeProtoEar(
            radius: 1.5,
            position: CGPoint(x: w * 0.25, y: h * 0.3),
            alpha: 0.3
        )
        head.addChild(protoEarL)
        head.addChild(protoEarR)

        // Proto-tail hint — faint curve at bottom-back
        let protoTail = makeProtoTail(
            length: 3.0,
            position: CGPoint(x: 0, y: -h * 0.3),
            alpha: 0.2
        )
        body.addChild(protoTail)

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

    private static func buildCritter(w: CGFloat, h: CGFloat,
                                       bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.6, color: bodyColor)
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
                           name: "ear_left", isLeft: true, color: bodyColor)
        let earR = makeEar(size: CGSize(width: 3, height: 4),
                           position: CGPoint(x: w * 0.2, y: w * 0.25),
                           name: "ear_right", isLeft: false, color: bodyColor)
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

        // Whisker stubs — short 2-whisker set (emerging, not full)
        let whiskerL = makeWhiskerGroup(
            position: CGPoint(x: -w * 0.15, y: -w * 0.12),
            name: "whisker_left", isLeft: true, count: 2, length: 2)
        let whiskerR = makeWhiskerGroup(
            position: CGPoint(x: w * 0.15, y: -w * 0.12),
            name: "whisker_right", isLeft: false, count: 2, length: 2)
        head.addChild(whiskerL)
        head.addChild(whiskerR)

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
            whiskerLeft: whiskerL, whiskerRight: whiskerR,
            tail: tail,
            pawFL: pawFL, pawFR: pawFR, pawBL: pawBL, pawBR: pawBR,
            aura: nil, particles: particles
        )
    }

    // MARK: - Beast (18x20) — Confident Cat

    private static func buildBeast(w: CGFloat, h: CGFloat,
                                     bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.55, color: bodyColor)
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
                           name: "ear_left", isLeft: true, color: bodyColor)
        let earR = makeEar(size: CGSize(width: 4, height: 5),
                           position: CGPoint(x: w * 0.18, y: w * 0.22),
                           name: "ear_right", isLeft: false, color: bodyColor)
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

    private static func buildSage(w: CGFloat, h: CGFloat,
                                    bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.5, color: bodyColor)
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

        // Third eye mark (faint) with alpha pulse
        let thirdEye = SKShapeNode(circleOfRadius: 1.0)
        thirdEye.fillColor = PushlingPalette.dusk
        thirdEye.strokeColor = .clear
        thirdEye.alpha = 0.25
        thirdEye.position = CGPoint(x: 0, y: w * 0.15)
        thirdEye.name = "third_eye"
        head.addChild(thirdEye)

        thirdEye.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: 2.0),
            SKAction.fadeAlpha(to: 0.15, duration: 2.0)
        ])))

        let earL = makeEar(size: CGSize(width: 5, height: 6),
                           position: CGPoint(x: -w * 0.16, y: w * 0.2),
                           name: "ear_left", isLeft: true, color: bodyColor)
        let earR = makeEar(size: CGSize(width: 5, height: 6),
                           position: CGPoint(x: w * 0.16, y: w * 0.2),
                           name: "ear_right", isLeft: false, color: bodyColor)
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

    private static func buildApex(w: CGFloat, h: CGFloat,
                                    repoCount: Int = 1,
                                    bodyColor: SKColor = PushlingPalette.bone) -> StageNodes {
        let body = makeCatBody(width: w, height: h * 0.5, color: bodyColor)
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

        // Crown of tiny stars with staggered alpha pulse
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

            // Each star pulses at a different rate (2-4s)
            let duration = 2.0 + Double(i) * 0.5
            star.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: duration / 2),
                SKAction.fadeAlpha(to: 0.7, duration: duration / 2)
            ])))
        }

        let earL = makeEar(size: CGSize(width: 5, height: 7),
                           position: CGPoint(x: -w * 0.15, y: w * 0.18),
                           name: "ear_left", isLeft: true, color: bodyColor)
        let earR = makeEar(size: CGSize(width: 5, height: 7),
                           position: CGPoint(x: w * 0.15, y: w * 0.18),
                           name: "ear_right", isLeft: false, color: bodyColor)
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

        // Wise beard — flowing strands from chin, the mark of a transcendent spirit
        let beard = makeWiseBeard(
            length: w * 0.35,
            position: CGPoint(x: 0, y: -w * 0.18),
            color: PushlingPalette.gilt
        )
        beard.alpha = 0.8
        head.addChild(beard)

        // Primary tail — TailController drives this one
        let tail = makeTail(length: 12, thickness: 2.0,
                             position: CGPoint(x: -w * 0.45, y: 0),
                             name: "tail")
        tail.alpha = 0.85

        // Additional tails fanned from the same attach point (repo count driven)
        let extraTailCount = min(9, max(1, repoCount)) - 1
        for i in 0..<extraTailCount {
            let lengthVariation = CGFloat.random(in: -1...1)
            let extraTail = makeTail(
                length: 12 + lengthVariation, thickness: 1.8,
                position: CGPoint(x: -w * 0.45, y: 0),
                name: "tail_extra_\(i)"
            )
            extraTail.alpha = 0.7
            // Fan upward at 15deg intervals from the primary tail
            extraTail.zRotation = CGFloat(i + 1) * 0.26
            body.addChild(extraTail)
        }

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
