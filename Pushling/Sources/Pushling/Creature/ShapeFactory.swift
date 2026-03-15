// ShapeFactory.swift — Geometric shape primitives for creature body parts
// Creates SKShapeNode-based pixel-art shapes for ears, eyes, tails, paws, etc.

import SpriteKit

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
