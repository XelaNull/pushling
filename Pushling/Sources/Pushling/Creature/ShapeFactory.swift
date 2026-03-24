// ShapeFactory.swift — Shape primitives for creature body parts
// Creates SKShapeNode-based shapes using CatShapes Bezier paths.
// Used by StageRenderer to build creature nodes.

import SpriteKit

// MARK: - Shape Factory Helpers

extension StageRenderer {

    /// Make a teardrop body shape (for Drop stage).
    static func makeTeardrop(width: CGFloat,
                              height: CGFloat,
                              color: SKColor = PushlingPalette.bone) -> SKShapeNode {
        let path = CatShapes.teardropBody(width: width, height: height)
        let shape = SKShapeNode(path: path)
        shape.fillColor = color
        shape.strokeColor = .clear
        return shape
    }

    /// Make a cat body shape using CatShapes Bezier paths.
    static func makeCatBody(width: CGFloat, height: CGFloat,
                             stage: GrowthStage = .beast,
                             color: SKColor = PushlingPalette.bone) -> SKShapeNode {
        let path = CatShapes.catBody(width: width, height: height, stage: stage)
        let body = SKShapeNode(path: path)
        body.fillColor = color
        body.strokeColor = .clear
        return body
    }

    /// Make an ear shape with rounded tips and inner ear detail.
    static func makeEar(size: CGSize, position: CGPoint,
                         name: String, isLeft: Bool,
                         color: SKColor = PushlingPalette.bone) -> SKShapeNode {
        let (outerPath, innerPath) = CatShapes.catEar(
            width: size.width, height: size.height, isLeft: isLeft)

        let ear = SKShapeNode(path: outerPath)
        ear.fillColor = color
        ear.strokeColor = .clear
        ear.position = position
        ear.name = name
        ear.zPosition = 25

        // Inner ear triangle (Ember pink)
        let inner = SKShapeNode(path: innerPath)
        inner.fillColor = PushlingPalette.softEmber
        inner.strokeColor = .clear
        inner.alpha = 0.4
        inner.name = "\(name)_inner"
        ear.addChild(inner)

        return ear
    }

    /// Make an eye container + shape with iris, slit pupil, and catch-lights.
    /// Returns (container SKNode, inner SKShapeNode).
    static func makeEye(radius: CGFloat, xOff: CGFloat, yOff: CGFloat,
                          name: String,
                          stage: GrowthStage = .beast) -> (SKNode, SKShapeNode) {
        let container = SKNode()
        container.name = name
        container.position = CGPoint(x: xOff, y: yOff)
        container.zPosition = 30

        // Almond-shaped eye (stage-dependent roundness)
        let eyePath = CatShapes.catEye(radius: radius, stage: stage)
        let shape = SKShapeNode(path: eyePath)
        shape.fillColor = PushlingPalette.bone
        shape.strokeColor = .clear
        shape.name = "\(name)_shape"
        container.addChild(shape)

        // Iris ring — 85% of eye area (cats have huge irises)
        let iris = SKShapeNode(circleOfRadius: radius * 0.85)
        iris.fillColor = PushlingPalette.tide
        iris.strokeColor = .clear
        iris.name = "\(name)_iris"
        iris.zPosition = 1
        container.addChild(iris)

        // Slit pupil (vertical oval, dilates via xScale)
        let pupilPath = CatShapes.catPupil(radius: radius * 0.35)
        let pupil = SKShapeNode(path: pupilPath)
        pupil.fillColor = PushlingPalette.void_
        pupil.strokeColor = .clear
        pupil.name = "\(name)_pupil"
        pupil.zPosition = 2
        container.addChild(pupil)

        // Primary catch-light
        let catchLight = SKShapeNode(circleOfRadius: radius * 0.12)
        catchLight.fillColor = PushlingPalette.bone
        catchLight.strokeColor = .clear
        catchLight.name = "\(name)_catchlight"
        catchLight.zPosition = 3
        catchLight.position = CGPoint(x: radius * 0.2, y: radius * 0.25)
        container.addChild(catchLight)

        // Secondary catch-light (smaller, opposite corner)
        let catchLight2 = SKShapeNode(circleOfRadius: radius * 0.07)
        catchLight2.fillColor = PushlingPalette.bone
        catchLight2.strokeColor = .clear
        catchLight2.name = "\(name)_catchlight2"
        catchLight2.zPosition = 3
        catchLight2.position = CGPoint(x: -radius * 0.15, y: -radius * 0.15)
        catchLight2.alpha = 0.5
        container.addChild(catchLight2)

        return (container, shape)
    }

    /// Make a nose node — tiny inverted triangle.
    static func makeNose(size: CGFloat,
                          position: CGPoint) -> SKShapeNode {
        let path = CatShapes.catNose(size: size)
        let nose = SKShapeNode(path: path)
        nose.fillColor = PushlingPalette.softEmber
        nose.strokeColor = .clear
        nose.position = position
        nose.name = "nose"
        nose.zPosition = 26
        return nose
    }

    /// Make a mouth node + inner shape for animation.
    /// Uses the cat-smile `:3` curve from CatShapes.
    static func makeMouth(width: CGFloat,
                           position: CGPoint) -> (SKShapeNode, SKShapeNode) {
        let outer = SKShapeNode()
        outer.position = position
        outer.name = "mouth"
        outer.zPosition = 25

        // Inner shape — cat-smile `:3` curve
        let path = CatShapes.catMouth(width: width)
        let inner = SKShapeNode(path: path)
        inner.strokeColor = PushlingPalette.ash
        inner.lineWidth = 0.5
        inner.fillColor = .clear
        inner.name = "mouth_inner"
        outer.addChild(inner)

        return (outer, inner)
    }

    /// Make a whisker group with slight arc curves.
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
            let droop = -0.08 + CGFloat(abs(i - count / 2)) * 0.03

            // Use CatShapes whisker arc instead of straight line
            let whiskerPath = CatShapes.whisker(length: length, droop: droop)

            let whisker = SKShapeNode(path: whiskerPath)
            whisker.strokeColor = PushlingPalette.ash
            whisker.lineWidth = 0.5
            whisker.alpha = 0.8
            whisker.name = "\(name)_\(i)"
            // Rotate to fan direction
            whisker.zRotation = angle
            whisker.xScale = dir
            group.addChild(whisker)
        }

        return group
    }

    /// Make a single-node tail shape using CatShapes S-curve.
    /// Used for Apex extra (decorative) tails — not the primary segmented tail.
    static func makeTail(length: CGFloat, thickness: CGFloat,
                          position: CGPoint, name: String,
                          stage: GrowthStage = .beast) -> SKShapeNode {
        let path = CatShapes.catTail(length: length, stage: stage)

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

    /// Make a segmented tail chain for spring-physics animation.
    /// Returns segments in order (base to tip). Segment[0] is the root;
    /// segment[i] is a child of segment[i-1], positioned at its tip.
    /// - Parameters:
    ///   - totalLength: Overall tail length in points.
    ///   - baseThickness: Stroke width at the base segment.
    ///   - position: Attachment point (position for the base segment).
    ///   - segmentCount: Number of segments (3 for Critter, 4 for Beast+).
    ///   - stage: Growth stage (affects curve factor).
    /// - Returns: (segments, segmentLengths, curveFactor)
    static func makeTailSegments(
        totalLength: CGFloat,
        baseThickness: CGFloat,
        position: CGPoint,
        segmentCount: Int,
        stage: GrowthStage
    ) -> (segments: [SKShapeNode], lengths: [CGFloat], curveFactor: CGFloat) {

        // Length proportions: taper base→tip
        let lengthRatios: [CGFloat]
        let thicknessRatios: [CGFloat]

        if segmentCount == 3 {
            lengthRatios = [0.35, 0.35, 0.30]
            thicknessRatios = [1.0, 0.75, 0.5]
        } else {
            lengthRatios = [0.30, 0.28, 0.24, 0.18]
            thicknessRatios = [1.0, 0.8, 0.6, 0.4]
        }

        let curveFactor: CGFloat
        switch stage {
        case .critter: curveFactor = 0.15
        case .beast:   curveFactor = 0.22
        case .sage:    curveFactor = 0.26
        case .apex:    curveFactor = 0.32
        default:       curveFactor = 0.1
        }

        var segments: [SKShapeNode] = []
        var lengths: [CGFloat] = []

        for i in 0..<segmentCount {
            let segLen = totalLength * lengthRatios[i]
            let thickness = baseThickness * thicknessRatios[i]
            lengths.append(segLen)

            let path = CatShapes.tailSegment(length: segLen,
                                              curveFactor: curveFactor)
            let seg = SKShapeNode(path: path)
            seg.strokeColor = PushlingPalette.bone
            seg.lineWidth = thickness
            seg.lineCap = .round
            seg.fillColor = .clear
            seg.name = "tail_seg_\(i)"
            seg.zPosition = 8

            if i == 0 {
                seg.position = position
            } else {
                // Position at the tip of the previous segment
                let prevLen = lengths[i - 1]
                let tipPos = CatShapes.tailSegmentTip(
                    length: prevLen, curveFactor: curveFactor)
                seg.position = tipPos
                segments[i - 1].addChild(seg)
            }

            segments.append(seg)
        }

        return (segments, lengths, curveFactor)
    }

    /// Make a paw using CatShapes bean shape, with visible cat leg.
    static func makePaw(size: CGFloat, position: CGPoint,
                         name: String,
                         showToes: Bool = false,
                         legHeight: CGFloat = 0,
                         legAngle: CGFloat = 0,
                         isFront: Bool = true) -> SKShapeNode {
        let (pawPath, toePaths) = CatShapes.catPaw(
            size: size, showToes: showToes)

        let paw = SKShapeNode(path: pawPath)
        paw.fillColor = PushlingPalette.bone
        paw.strokeColor = .clear
        paw.position = position
        paw.name = name
        paw.zPosition = 12

        // Add toe pad details for Beast+
        for (i, toePath) in toePaths.enumerated() {
            let toe = SKShapeNode(path: toePath)
            toe.fillColor = PushlingPalette.softEmber
            toe.strokeColor = .clear
            toe.alpha = 0.3
            toe.name = "\(name)_toe_\(i)"
            paw.addChild(toe)
        }

        // Cat leg — always visible, connects paw to body
        if legHeight > 0 {
            let legWidth = size * 0.6  // narrower than paw for leg-like proportion
            let legPath = CatShapes.catLeg(
                height: legHeight, width: legWidth, isFront: isFront
            )
            let leg = SKShapeNode(path: legPath)
            leg.fillColor = PushlingPalette.bone
            leg.strokeColor = .clear
            leg.name = "\(name)_leg"
            leg.zPosition = -1
            leg.zRotation = legAngle
            paw.addChild(leg)
        }

        return paw
    }

    /// Calculate resting paw positions relative to body center.
    static func pawRestPositions(bodyWidth w: CGFloat,
                                  bodyHeight h: CGFloat)
        -> (fl: CGPoint, fr: CGPoint, bl: CGPoint, br: CGPoint) {
        let frontX = w * 0.18
        let backX = w * 0.38
        let groundY = -h * 0.4

        return (
            fl: CGPoint(x:  frontX, y: groundY),
            fr: CGPoint(x:  frontX + 3.0, y: groundY),
            bl: CGPoint(x: -backX, y: groundY),
            br: CGPoint(x: -backX + 3.0, y: groundY)
        )
    }

    // MARK: - Wise Beard (Apex Stage)

    /// Make a wise beard — 3 flowing strands hanging from the chin.
    /// Semi-ethereal, gently swaying, matching the Apex's transcendent aesthetic.
    /// Returns the beard group node containing individual strand children.
    static func makeWiseBeard(length: CGFloat,
                               position: CGPoint,
                               color: SKColor = PushlingPalette.bone) -> SKNode {
        let group = SKNode()
        group.position = position
        group.name = "wise_beard"
        group.zPosition = 24

        // 3 strands: center (longest), left, right
        let strands: [(spread: CGFloat, lengthScale: CGFloat, waviness: CGFloat, thick: CGFloat)] = [
            (spread: -0.6, lengthScale: 0.75, waviness: 0.35, thick: 0.8),  // left
            (spread:  0.0, lengthScale: 1.0,  waviness: 0.20, thick: 1.0),  // center (longest)
            (spread:  0.6, lengthScale: 0.75, waviness: 0.35, thick: 0.8),  // right
        ]

        for (i, s) in strands.enumerated() {
            let strandPath = CatShapes.beardStrand(
                length: length * s.lengthScale,
                spread: s.spread,
                waviness: s.waviness
            )
            let strand = SKShapeNode(path: strandPath)
            strand.strokeColor = color
            strand.lineWidth = s.thick
            strand.lineCap = .round
            strand.fillColor = .clear
            strand.alpha = 0.75
            strand.name = "beard_strand_\(i)"
            group.addChild(strand)
        }

        return group
    }

    // MARK: - Proto Features (Spore/Drop Hints)

    /// Make a proto-ear nub for Spore stage (circular).
    static func makeProtoEar(radius: CGFloat, position: CGPoint,
                              alpha: CGFloat) -> SKShapeNode {
        let ear = SKShapeNode(circleOfRadius: radius)
        ear.fillColor = PushlingPalette.bone
        ear.strokeColor = .clear
        ear.alpha = alpha
        ear.position = position
        ear.name = "proto_ear"
        ear.zPosition = 25
        return ear
    }

    /// Make a triangular proto-ear bump for Drop stage.
    static func makeProtoEarTriangle(width: CGFloat, height: CGFloat,
                                      position: CGPoint,
                                      alpha: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        let hw = width / 2
        path.move(to: CGPoint(x: -hw, y: 0))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: hw, y: 0))
        path.closeSubpath()

        let ear = SKShapeNode(path: path)
        ear.fillColor = PushlingPalette.bone
        ear.strokeColor = .clear
        ear.alpha = alpha
        ear.position = position
        ear.name = "proto_ear"
        ear.zPosition = 25
        return ear
    }

    /// Make a proto-tail hint for Drop stage.
    static func makeProtoTail(length: CGFloat, position: CGPoint,
                               alpha: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(
            to: CGPoint(x: -length * 0.5, y: -length * 0.7),
            control: CGPoint(x: -length * 0.6, y: 0)
        )
        let tail = SKShapeNode(path: path)
        tail.strokeColor = PushlingPalette.bone
        tail.lineWidth = 1.0
        tail.lineCap = .round
        tail.fillColor = .clear
        tail.alpha = alpha
        tail.position = position
        tail.name = "proto_tail"
        tail.zPosition = 8
        return tail
    }
}
