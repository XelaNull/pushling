// CompositeShapeFactory+Items.swift — Composite designs 11-20 (toys, furniture, misc)
// Continuation of CompositeShapeFactory.swift (which holds builders 1-10).
// The composite lookup dispatcher is in CompositeShapeFactory+Lookup.swift.
//
// All colors from PushlingPalette. All transparency via PushlingPalette.withAlpha().
// Container nodes named "composite_\(shapeName)". Children have descriptive names.

import SpriteKit

// MARK: - Composites 11-20

extension CompositeShapeFactory {

    // MARK: - 11. Crystal

    /// 2 overlapping facet shapes + inner glow.
    static func buildCrystal(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_crystal"

        // Main facet (pentagon)
        let mainPath = CGMutablePath()
        mainPath.move(to: CGPoint(x: 0, y: 5 * s))
        mainPath.addLine(to: CGPoint(x: 2 * s, y: 2 * s))
        mainPath.addLine(to: CGPoint(x: 1.5 * s, y: 0))
        mainPath.addLine(to: CGPoint(x: -1.5 * s, y: 0))
        mainPath.addLine(to: CGPoint(x: -2 * s, y: 2 * s))
        mainPath.closeSubpath()
        let mainFacet = SKShapeNode(path: mainPath)
        mainFacet.fillColor = PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.7)
        mainFacet.strokeColor = .clear
        mainFacet.name = "facet_main"
        container.addChild(mainFacet)

        // Inner facet (smaller, brighter, offset slightly)
        let innerPath = CGMutablePath()
        innerPath.move(to: CGPoint(x: 0.2 * s, y: 4 * s))
        innerPath.addLine(to: CGPoint(x: 1.2 * s, y: 2 * s))
        innerPath.addLine(to: CGPoint(x: 0.8 * s, y: 0.5 * s))
        innerPath.addLine(to: CGPoint(x: -0.6 * s, y: 0.5 * s))
        innerPath.addLine(to: CGPoint(x: -1 * s, y: 2 * s))
        innerPath.closeSubpath()
        let innerFacet = SKShapeNode(path: innerPath)
        innerFacet.fillColor = PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.9)
        innerFacet.strokeColor = .clear
        innerFacet.name = "facet_inner"
        container.addChild(innerFacet)

        // Inner glow
        let glow = SKShapeNode(circleOfRadius: 1 * s)
        glow.fillColor = PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.15)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 2.5 * s)
        glow.name = "glow"
        container.addChild(glow)

        return container
    }

    // MARK: - 12. Ball / Yarn Ball

    /// Circle body + 2 cross-arc strokes + optional trailing thread.
    static func buildBall(size: CGFloat, includeThread: Bool = false) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = includeThread ? "composite_yarn_ball" : "composite_ball"

        // Body circle
        let body = SKShapeNode(circleOfRadius: 2.5 * s)
        body.fillColor = PushlingPalette.ember
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 2.5 * s)
        body.name = "body"
        container.addChild(body)

        // 2 cross-arc strokes
        for (i, rot) in [CGFloat(0.4), CGFloat(-0.5)].enumerated() {
            let arcPath = CGMutablePath()
            arcPath.addArc(center: CGPoint(x: 0, y: 2.5 * s),
                           radius: 2 * s,
                           startAngle: -.pi / 3 + rot,
                           endAngle: .pi / 3 + rot,
                           clockwise: false)
            let arc = SKShapeNode(path: arcPath)
            arc.fillColor = .clear
            arc.strokeColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.3)
            arc.lineWidth = 0.5
            arc.name = "arc_\(i)"
            container.addChild(arc)
        }

        // Trailing thread for yarn ball
        if includeThread {
            let threadPath = CGMutablePath()
            threadPath.move(to: CGPoint(x: 2 * s, y: 1 * s))
            threadPath.addQuadCurve(to: CGPoint(x: 3.5 * s, y: 0),
                                    control: CGPoint(x: 3 * s, y: 1.5 * s))
            let thread = SKShapeNode(path: threadPath)
            thread.fillColor = .clear
            thread.strokeColor = PushlingPalette.withAlpha(PushlingPalette.ember, alpha: 0.5)
            thread.lineWidth = 0.5
            thread.name = "thread"
            container.addChild(thread)
        }

        return container
    }

    // MARK: - 13. Fountain

    /// Basin semicircle + water arc + 2 water droplets.
    static func buildFountain(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_fountain"

        // Basin (dome shape)
        let basinPath = CGMutablePath()
        basinPath.addArc(center: CGPoint(x: 0, y: 1 * s), radius: 3 * s,
                         startAngle: 0, endAngle: .pi, clockwise: false)
        basinPath.closeSubpath()
        let basin = SKShapeNode(path: basinPath)
        basin.fillColor = PushlingPalette.ash
        basin.strokeColor = .clear
        basin.name = "basin"
        container.addChild(basin)

        // Water arc (curved upward from center)
        let arcPath = CGMutablePath()
        arcPath.move(to: CGPoint(x: -0.5 * s, y: 2.5 * s))
        arcPath.addQuadCurve(to: CGPoint(x: 0.5 * s, y: 2.5 * s),
                             control: CGPoint(x: 0, y: 5 * s))
        let arc = SKShapeNode(path: arcPath)
        arc.fillColor = .clear
        arc.strokeColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.5)
        arc.lineWidth = 0.8
        arc.name = "water_arc"
        container.addChild(arc)

        // 2 water droplets above basin
        for (i, xOff) in [CGFloat(-1.0), CGFloat(0.8)].enumerated() {
            let drop = SKShapeNode(circleOfRadius: 0.4 * s)
            drop.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.4)
            drop.strokeColor = .clear
            drop.position = CGPoint(x: xOff * s, y: 3.5 * s)
            drop.name = "droplet_\(i)"
            container.addChild(drop)
        }

        return container
    }

    // MARK: - 14. Milk Saucer

    /// Saucer ellipse + milk surface + rim highlight.
    static func buildMilkSaucer(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_milk_saucer"

        let saucer = SKShapeNode(ellipseOf: CGSize(width: 5 * s, height: 1.5 * s))
        saucer.fillColor = PushlingPalette.ash
        saucer.strokeColor = .clear
        saucer.position = CGPoint(x: 0, y: 0.75 * s)
        saucer.name = "saucer"
        container.addChild(saucer)

        let milk = SKShapeNode(ellipseOf: CGSize(width: 4 * s, height: 1 * s))
        milk.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.7)
        milk.strokeColor = .clear
        milk.position = CGPoint(x: 0, y: 0.8 * s)
        milk.name = "milk"
        container.addChild(milk)

        let rim = SKShapeNode(ellipseOf: CGSize(width: 5 * s, height: 1.5 * s))
        rim.fillColor = .clear
        rim.strokeColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.2)
        rim.lineWidth = 0.3
        rim.position = CGPoint(x: 0, y: 0.75 * s)
        rim.name = "rim"
        container.addChild(rim)

        return container
    }

    // MARK: - 15. Treat

    /// Star shape + sparkle dot.
    static func buildTreat(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_treat"

        let path = CGMutablePath()
        let outerR = 2.0 * s
        let innerR = 1.0 * s
        let centerY = 2 * s
        for i in 0..<10 {
            let angle = CGFloat(i) * .pi / 5.0 - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cos(angle) * r, y: sin(angle) * r + centerY)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.fillColor = PushlingPalette.bone
        star.strokeColor = .clear
        star.name = "treat_shape"
        container.addChild(star)

        let sparkle = SKShapeNode(circleOfRadius: 0.4 * s)
        sparkle.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.4)
        sparkle.strokeColor = .clear
        sparkle.position = CGPoint(x: 1.5 * s, y: 3 * s)
        sparkle.name = "sparkle"
        let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: 1.0)
        fadeOut.timingMode = .easeInEaseOut
        let fadeIn = SKAction.fadeAlpha(to: 0.6, duration: 1.0)
        fadeIn.timingMode = .easeInEaseOut
        sparkle.run(SKAction.repeatForever(
            SKAction.sequence([fadeOut, fadeIn])), withKey: "pulse")
        container.addChild(sparkle)

        return container
    }

    // MARK: - 16. Little Mirror

    /// Mirror ellipse + frame stroke + handle rect.
    static func buildLittleMirror(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_little_mirror"

        let handle = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 2 * s))
        handle.fillColor = PushlingPalette.ash
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: 1 * s)
        handle.name = "handle"
        container.addChild(handle)

        let mirror = SKShapeNode(ellipseOf: CGSize(width: 2 * s, height: 3.5 * s))
        mirror.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.8)
        mirror.strokeColor = .clear
        mirror.position = CGPoint(x: 0, y: 3.75 * s)
        mirror.name = "mirror"
        container.addChild(mirror)

        let frame = SKShapeNode(ellipseOf: CGSize(width: 2 * s, height: 3.5 * s))
        frame.fillColor = .clear
        frame.strokeColor = PushlingPalette.ash
        frame.lineWidth = 0.5
        frame.position = CGPoint(x: 0, y: 3.75 * s)
        frame.name = "frame"
        container.addChild(frame)

        return container
    }

    // MARK: - 17. Rock

    /// 2 overlapping irregular polygons + highlight line.
    static func buildRock(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_rock"

        let mainPath = CGMutablePath()
        mainPath.move(to: CGPoint(x: -2 * s, y: 0))
        mainPath.addLine(to: CGPoint(x: -2.5 * s, y: 1.5 * s))
        mainPath.addLine(to: CGPoint(x: 0, y: 3 * s))
        mainPath.addLine(to: CGPoint(x: 2.5 * s, y: 1.5 * s))
        mainPath.addLine(to: CGPoint(x: 2 * s, y: 0))
        mainPath.closeSubpath()
        let mainRock = SKShapeNode(path: mainPath)
        mainRock.fillColor = PushlingPalette.ash
        mainRock.strokeColor = .clear
        mainRock.name = "rock_main"
        container.addChild(mainRock)

        let secPath = CGMutablePath()
        secPath.move(to: CGPoint(x: 1 * s, y: 0))
        secPath.addLine(to: CGPoint(x: 0.5 * s, y: 1.5 * s))
        secPath.addLine(to: CGPoint(x: 2 * s, y: 2.2 * s))
        secPath.addLine(to: CGPoint(x: 3.2 * s, y: 1 * s))
        secPath.addLine(to: CGPoint(x: 2.8 * s, y: 0))
        secPath.closeSubpath()
        let secRock = SKShapeNode(path: secPath)
        secRock.fillColor = PushlingPalette.withAlpha(PushlingPalette.ash, alpha: 0.7)
        secRock.strokeColor = .clear
        secRock.name = "rock_secondary"
        container.addChild(secRock)

        let highlight = SKShapeNode(rectOf: CGSize(width: 2 * s, height: 0.3 * s))
        highlight.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.15)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -0.3 * s, y: 2.5 * s)
        highlight.zRotation = 0.2
        highlight.name = "highlight"
        container.addChild(highlight)

        return container
    }

    // MARK: - 18. Bench

    /// Seat rect + 2 legs + back rect.
    static func buildBench(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_bench"

        for xOff: CGFloat in [-2.5, 2.5] {
            let leg = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 3 * s))
            leg.fillColor = PushlingPalette.ash
            leg.strokeColor = .clear
            leg.position = CGPoint(x: xOff * s, y: 1.5 * s)
            leg.name = xOff < 0 ? "leg_left" : "leg_right"
            container.addChild(leg)
        }

        let seat = SKShapeNode(rectOf: CGSize(width: 7 * s, height: 1.5 * s))
        seat.fillColor = PushlingPalette.ash
        seat.strokeColor = .clear
        seat.position = CGPoint(x: 0, y: 3.75 * s)
        seat.name = "seat"
        container.addChild(seat)

        let backColor = PushlingPalette.lerp(from: PushlingPalette.ash,
                                              to: PushlingPalette.bone, t: 0.15)
        let back = SKShapeNode(rectOf: CGSize(width: 7 * s, height: 2 * s))
        back.fillColor = backColor
        back.strokeColor = .clear
        back.position = CGPoint(x: 0, y: 5.5 * s)
        back.name = "back"
        container.addChild(back)

        return container
    }

    // MARK: - 19. Flag

    /// Pole rect + flag rect with gentle sway action.
    static func buildFlag(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_flag"

        let pole = SKShapeNode(rectOf: CGSize(width: 0.5 * s, height: 8 * s))
        pole.fillColor = PushlingPalette.ash
        pole.strokeColor = .clear
        pole.position = CGPoint(x: 0, y: 4 * s)
        pole.name = "pole"
        container.addChild(pole)

        let flag = SKShapeNode(rectOf: CGSize(width: 3 * s, height: 2 * s))
        flag.fillColor = PushlingPalette.ember
        flag.strokeColor = .clear
        flag.position = CGPoint(x: 1.75 * s, y: 7 * s)
        flag.name = "flag"
        let swayLeft = SKAction.rotate(toAngle: 0.087, duration: 1.0)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SKAction.rotate(toAngle: -0.087, duration: 1.0)
        swayRight.timingMode = .easeInEaseOut
        flag.run(SKAction.repeatForever(
            SKAction.sequence([swayLeft, swayRight])), withKey: "sway")
        container.addChild(flag)

        return container
    }

    // MARK: - 20. Candle

    /// Rect body + teardrop flame + glow circle.
    static func buildCandle(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_candle"

        let body = SKShapeNode(rectOf: CGSize(width: 1.5 * s, height: 3 * s))
        body.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.8)
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 1.5 * s)
        body.name = "body"
        container.addChild(body)

        let flamePath = CGMutablePath()
        flamePath.move(to: CGPoint(x: 0, y: 4.5 * s))
        flamePath.addQuadCurve(to: CGPoint(x: 0, y: 3 * s),
                               control: CGPoint(x: 0.5 * s, y: 3.5 * s))
        flamePath.addQuadCurve(to: CGPoint(x: 0, y: 4.5 * s),
                               control: CGPoint(x: -0.5 * s, y: 3.5 * s))
        let flame = SKShapeNode(path: flamePath)
        flame.fillColor = PushlingPalette.ember
        flame.strokeColor = .clear
        flame.name = "flame"
        container.addChild(flame)

        let glow = SKShapeNode(circleOfRadius: 2 * s)
        glow.fillColor = PushlingPalette.withAlpha(PushlingPalette.ember, alpha: 0.1)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 3.5 * s)
        glow.zPosition = -1
        glow.name = "glow"
        container.addChild(glow)

        return container
    }
}
