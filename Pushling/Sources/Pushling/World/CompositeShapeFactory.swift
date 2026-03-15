// CompositeShapeFactory.swift — Multi-node composite designs for world objects
// Replaces single geometric primitives with recognizable 2-5 node compositions.
// Each composite is designed for the Touch Bar (1085x30pt, OLED true black).
//
// All colors from PushlingPalette. All transparency via PushlingPalette.withAlpha().
// Container nodes named "composite_\(shapeName)". Children have descriptive names.

import SpriteKit

// MARK: - CompositeShapeFactory

/// Factory for multi-node composite object shapes.
/// Each builder returns an SKNode container with 2-5 child nodes.
enum CompositeShapeFactory {

    // MARK: - 1. Campfire

    /// 2 crossed logs, 3 flame teardrops, 1 glow circle.
    static func buildCampfire(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_campfire"

        // Glow circle (behind everything)
        let glow = SKShapeNode(circleOfRadius: 4 * s)
        glow.fillColor = PushlingPalette.withAlpha(PushlingPalette.ember, alpha: 0.15)
        glow.strokeColor = .clear
        glow.name = "glow"
        glow.zPosition = -1
        container.addChild(glow)

        // Crossed logs
        for angle: CGFloat in [-0.35, 0.35] {  // ~20 degrees
            let log = SKShapeNode(rectOf: CGSize(width: 4 * s, height: 1 * s))
            log.fillColor = PushlingPalette.ash
            log.strokeColor = .clear
            log.zRotation = angle
            log.name = "log"
            container.addChild(log)
        }

        // 3 flame teardrops stacked
        let flameAlphas: [CGFloat] = [1.0, 0.8, 0.6]
        for (i, alpha) in flameAlphas.enumerated() {
            let yOff = CGFloat(i) * 1.2 * s
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: (1.5 * s) + yOff))
            path.addQuadCurve(to: CGPoint(x: 0, y: yOff),
                              control: CGPoint(x: 0.8 * s, y: (0.8 * s) + yOff))
            path.addQuadCurve(to: CGPoint(x: 0, y: (1.5 * s) + yOff),
                              control: CGPoint(x: -0.8 * s, y: (0.8 * s) + yOff))
            let flame = SKShapeNode(path: path)
            flame.fillColor = PushlingPalette.withAlpha(PushlingPalette.ember, alpha: alpha)
            flame.strokeColor = .clear
            flame.name = "flame_\(i)"
            container.addChild(flame)
        }

        return container
    }

    // MARK: - 2. Tree

    /// Trunk rect + 3 overlapping canopy circles.
    static func buildTree(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_tree"

        // Trunk
        let trunk = SKShapeNode(rectOf: CGSize(width: 1.5 * s, height: 4 * s))
        trunk.fillColor = PushlingPalette.ash
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: 2 * s)
        trunk.name = "trunk"
        container.addChild(trunk)

        // 3 overlapping canopy circles
        let canopyData: [(x: CGFloat, y: CGFloat, r: CGFloat, color: SKColor)] = [
            (-1.0, 5.5, 2.0, PushlingPalette.deepMoss),
            ( 0.5, 6.0, 2.5, PushlingPalette.moss),
            ( 1.5, 5.5, 2.0, PushlingPalette.deepMoss),
        ]
        for (i, c) in canopyData.enumerated() {
            let circle = SKShapeNode(circleOfRadius: c.r * s)
            circle.fillColor = c.color
            circle.strokeColor = .clear
            circle.position = CGPoint(x: c.x * s, y: c.y * s)
            circle.name = "canopy_\(i)"
            container.addChild(circle)
        }

        return container
    }

    // MARK: - 3. Flower

    /// Stem + 4 petal ellipses in cross pattern + center dot.
    static func buildFlower(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_flower"

        // Stem
        let stem = SKShapeNode(rectOf: CGSize(width: 0.5 * s, height: 3 * s))
        stem.fillColor = PushlingPalette.moss
        stem.strokeColor = .clear
        stem.position = CGPoint(x: 0, y: 1.5 * s)
        stem.name = "stem"
        container.addChild(stem)

        // 4 petals in cross pattern
        let petalCenter = CGPoint(x: 0, y: 3.5 * s)
        let offsets: [(dx: CGFloat, dy: CGFloat, rot: CGFloat)] = [
            (0, 1.0, 0),
            (0, -1.0, 0),
            (1.0, 0, .pi / 2),
            (-1.0, 0, .pi / 2),
        ]
        for (i, off) in offsets.enumerated() {
            let petal = SKShapeNode(ellipseOf: CGSize(width: 1 * s, height: 2 * s))
            petal.fillColor = PushlingPalette.gilt
            petal.strokeColor = .clear
            petal.position = CGPoint(x: petalCenter.x + off.dx * s,
                                     y: petalCenter.y + off.dy * s)
            petal.zRotation = off.rot
            petal.name = "petal_\(i)"
            container.addChild(petal)
        }

        // Center dot
        let center = SKShapeNode(circleOfRadius: 0.5 * s)
        center.fillColor = PushlingPalette.ember
        center.strokeColor = .clear
        center.position = petalCenter
        center.name = "center"
        container.addChild(center)

        return container
    }

    // MARK: - 4. Mushroom

    /// Stem + dome cap + 2 spot dots.
    static func buildMushroom(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_mushroom"

        // Stem
        let stem = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 2 * s))
        stem.fillColor = PushlingPalette.bone
        stem.strokeColor = .clear
        stem.position = CGPoint(x: 0, y: 1 * s)
        stem.name = "stem"
        container.addChild(stem)

        // Dome cap (half circle)
        let capPath = CGMutablePath()
        capPath.addArc(center: .zero, radius: 2 * s,
                       startAngle: 0, endAngle: .pi, clockwise: false)
        capPath.closeSubpath()
        let cap = SKShapeNode(path: capPath)
        cap.fillColor = PushlingPalette.ember
        cap.strokeColor = .clear
        cap.position = CGPoint(x: 0, y: 2 * s)
        cap.name = "cap"
        container.addChild(cap)

        // 2 spot dots on cap
        let spotOffsets: [(x: CGFloat, y: CGFloat)] = [(-0.8, 2.8), (0.6, 3.0)]
        for (i, off) in spotOffsets.enumerated() {
            let spot = SKShapeNode(circleOfRadius: 0.5 * s)
            spot.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.4)
            spot.strokeColor = .clear
            spot.position = CGPoint(x: off.x * s, y: off.y * s)
            spot.name = "spot_\(i)"
            container.addChild(spot)
        }

        return container
    }

    // MARK: - 5. Fish

    /// Ellipse body + triangle tail + dot eye.
    static func buildFish(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_fish"

        // Body ellipse
        let body = SKShapeNode(ellipseOf: CGSize(width: 3 * s, height: 1.5 * s))
        body.fillColor = PushlingPalette.tide
        body.strokeColor = .clear
        body.name = "body"
        container.addChild(body)

        // Triangle tail
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -1.5 * s, y: 0))
        tailPath.addLine(to: CGPoint(x: -3 * s, y: 0.75 * s))
        tailPath.addLine(to: CGPoint(x: -3 * s, y: -0.75 * s))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        tail.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.7)
        tail.strokeColor = .clear
        tail.name = "tail"
        container.addChild(tail)

        // Eye dot
        let eye = SKShapeNode(circleOfRadius: 0.3 * s)
        eye.fillColor = PushlingPalette.void_
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 0.8 * s, y: 0.2 * s)
        eye.name = "eye"
        container.addChild(eye)

        return container
    }

    // MARK: - 6. Cozy Bed

    /// Base rect + raised rim + pillow circle.
    static func buildCozyBed(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_cozy_bed"

        // Base
        let base = SKShapeNode(rectOf: CGSize(width: 8 * s, height: 2 * s),
                               cornerRadius: 0.5)
        base.fillColor = PushlingPalette.ash
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: 1 * s)
        base.name = "base_pad"
        container.addChild(base)

        // Raised rim
        let rimColor = PushlingPalette.lerp(from: PushlingPalette.ash,
                                             to: PushlingPalette.bone, t: 0.3)
        let rim = SKShapeNode(rectOf: CGSize(width: 8 * s, height: 1 * s),
                              cornerRadius: 0.5)
        rim.fillColor = rimColor
        rim.strokeColor = .clear
        rim.position = CGPoint(x: 0, y: 2.5 * s)
        rim.name = "rim"
        container.addChild(rim)

        // Pillow
        let pillow = SKShapeNode(circleOfRadius: 1.5 * s)
        pillow.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.7)
        pillow.strokeColor = .clear
        pillow.position = CGPoint(x: -2.5 * s, y: 1 * s)
        pillow.name = "pillow"
        container.addChild(pillow)

        return container
    }

    // MARK: - 7. Scratching Post

    /// Post + 3 scratch marks + platform + base.
    static func buildScratchingPost(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_scratching_post"

        // Base rect
        let base = SKShapeNode(rectOf: CGSize(width: 4 * s, height: 1 * s))
        base.fillColor = PushlingPalette.ash
        base.strokeColor = .clear
        base.position = CGPoint(x: 0, y: 0.5 * s)
        base.name = "post_base"
        container.addChild(base)

        // Post
        let post = SKShapeNode(rectOf: CGSize(width: 2 * s, height: 7 * s))
        post.fillColor = PushlingPalette.ash
        post.strokeColor = .clear
        post.position = CGPoint(x: 0, y: 4.5 * s)
        post.name = "post"
        container.addChild(post)

        // 3 scratch marks
        for i in 0..<3 {
            let mark = SKShapeNode(rectOf: CGSize(width: 0.3 * s, height: 1.5 * s))
            mark.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.2)
            mark.strokeColor = .clear
            mark.position = CGPoint(x: 0, y: (2.5 + CGFloat(i) * 2.0) * s)
            mark.name = "scratch_\(i)"
            container.addChild(mark)
        }

        // Platform at top
        let platColor = PushlingPalette.lerp(from: PushlingPalette.ash,
                                              to: PushlingPalette.bone, t: 0.2)
        let plat = SKShapeNode(rectOf: CGSize(width: 4 * s, height: 1 * s))
        plat.fillColor = platColor
        plat.strokeColor = .clear
        plat.position = CGPoint(x: 0, y: 8.5 * s)
        plat.name = "platform"
        container.addChild(plat)

        return container
    }

    // MARK: - 8. Cardboard Box

    /// Body rect + 2 flap triangles + shadow line.
    static func buildCardboardBox(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_cardboard_box"

        // Shadow line
        let shadow = SKShapeNode(rectOf: CGSize(width: 6 * s, height: 0.5 * s))
        shadow.fillColor = PushlingPalette.withAlpha(PushlingPalette.void_, alpha: 0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 0.25 * s)
        shadow.name = "shadow"
        container.addChild(shadow)

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: 6 * s, height: 4 * s))
        body.fillColor = PushlingPalette.ash
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 2.5 * s)
        body.name = "body"
        container.addChild(body)

        // 2 flap triangles at top
        let flapColor = PushlingPalette.lerp(from: PushlingPalette.ash,
                                              to: PushlingPalette.bone, t: 0.15)
        for side: CGFloat in [-1, 1] {
            let flapPath = CGMutablePath()
            flapPath.move(to: CGPoint(x: 0, y: 0))
            flapPath.addLine(to: CGPoint(x: side * 2 * s, y: 0))
            flapPath.addLine(to: CGPoint(x: side * 1 * s, y: 1 * s))
            flapPath.closeSubpath()
            let flap = SKShapeNode(path: flapPath)
            flap.fillColor = flapColor
            flap.strokeColor = .clear
            flap.position = CGPoint(x: side * 0.5 * s, y: 4.5 * s)
            flap.name = side < 0 ? "flap_left" : "flap_right"
            container.addChild(flap)
        }

        return container
    }

    // MARK: - 9. Music Box

    /// Box rect + lid line + floating note shape.
    static func buildMusicBox(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_music_box"

        // Box body
        let body = SKShapeNode(rectOf: CGSize(width: 4 * s, height: 3 * s),
                               cornerRadius: 0.5 * s)
        body.fillColor = PushlingPalette.dusk
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 1.5 * s)
        body.name = "body"
        container.addChild(body)

        // Lid line (angled rect at top)
        let lid = SKShapeNode(rectOf: CGSize(width: 3.5 * s, height: 0.4 * s))
        lid.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.3)
        lid.strokeColor = .clear
        lid.position = CGPoint(x: 0, y: 2.8 * s)
        lid.zRotation = 0.08
        lid.name = "lid"
        container.addChild(lid)

        // Floating note (stem + flag built from 2 tiny rects)
        let noteContainer = SKNode()
        noteContainer.name = "note"
        noteContainer.position = CGPoint(x: 1.5 * s, y: 4 * s)

        let noteStem = SKShapeNode(rectOf: CGSize(width: 0.3 * s, height: 1.5 * s))
        noteStem.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.6)
        noteStem.strokeColor = .clear
        noteStem.name = "note_stem"
        noteContainer.addChild(noteStem)

        let noteFlag = SKShapeNode(rectOf: CGSize(width: 0.8 * s, height: 0.5 * s))
        noteFlag.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.6)
        noteFlag.strokeColor = .clear
        noteFlag.position = CGPoint(x: 0.4 * s, y: 0.5 * s)
        noteFlag.name = "note_flag"
        noteContainer.addChild(noteFlag)

        container.addChild(noteContainer)

        return container
    }

    // MARK: - 10. Lantern

    /// Frame rect + light circle + handle arc + glow.
    static func buildLantern(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_lantern"

        // Glow circle (behind)
        let glow = SKShapeNode(circleOfRadius: 3 * s)
        glow.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.1)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 2 * s)
        glow.zPosition = -1
        glow.name = "glow"
        container.addChild(glow)

        // Frame
        let frame = SKShapeNode(rectOf: CGSize(width: 2 * s, height: 4 * s),
                                cornerRadius: 0.3 * s)
        frame.fillColor = PushlingPalette.ash
        frame.strokeColor = .clear
        frame.position = CGPoint(x: 0, y: 2 * s)
        frame.name = "frame"
        container.addChild(frame)

        // Light inside
        let light = SKShapeNode(circleOfRadius: 1 * s)
        light.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.5)
        light.strokeColor = .clear
        light.position = CGPoint(x: 0, y: 2 * s)
        light.name = "light"
        container.addChild(light)

        // Handle arc at top (small curved path)
        let handlePath = CGMutablePath()
        handlePath.addArc(center: CGPoint(x: 0, y: 4.2 * s),
                          radius: 0.8 * s,
                          startAngle: .pi, endAngle: 0, clockwise: false)
        let handle = SKShapeNode(path: handlePath)
        handle.fillColor = .clear
        handle.strokeColor = PushlingPalette.withAlpha(PushlingPalette.ash, alpha: 0.5)
        handle.lineWidth = 0.5
        handle.name = "handle"
        container.addChild(handle)

        return container
    }

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

        // Saucer
        let saucer = SKShapeNode(ellipseOf: CGSize(width: 5 * s, height: 1.5 * s))
        saucer.fillColor = PushlingPalette.ash
        saucer.strokeColor = .clear
        saucer.position = CGPoint(x: 0, y: 0.75 * s)
        saucer.name = "saucer"
        container.addChild(saucer)

        // Milk surface
        let milk = SKShapeNode(ellipseOf: CGSize(width: 4 * s, height: 1 * s))
        milk.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.7)
        milk.strokeColor = .clear
        milk.position = CGPoint(x: 0, y: 0.8 * s)
        milk.name = "milk"
        container.addChild(milk)

        // Rim highlight
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

        // Star/bone shape (small 5-pointed star)
        let path = CGMutablePath()
        let points = 5
        let outerR = 2.0 * s
        let innerR = 1.0 * s
        let centerY = 2 * s
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
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

        // Sparkle dot with pulse
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
            SKAction.sequence([fadeOut, fadeIn])
        ), withKey: "pulse")
        container.addChild(sparkle)

        return container
    }

    // MARK: - 16. Little Mirror

    /// Mirror ellipse + frame stroke + handle rect.
    static func buildLittleMirror(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_little_mirror"

        // Handle
        let handle = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 2 * s))
        handle.fillColor = PushlingPalette.ash
        handle.strokeColor = .clear
        handle.position = CGPoint(x: 0, y: 1 * s)
        handle.name = "handle"
        container.addChild(handle)

        // Mirror surface
        let mirror = SKShapeNode(ellipseOf: CGSize(width: 2 * s, height: 3.5 * s))
        mirror.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.8)
        mirror.strokeColor = .clear
        mirror.position = CGPoint(x: 0, y: 3.75 * s)
        mirror.name = "mirror"
        container.addChild(mirror)

        // Frame outline
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

        // Main rock (pentagon)
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

        // Secondary rock (smaller, offset)
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

        // Highlight line on top surface
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

        // 2 legs
        for xOff: CGFloat in [-2.5, 2.5] {
            let leg = SKShapeNode(rectOf: CGSize(width: 1 * s, height: 3 * s))
            leg.fillColor = PushlingPalette.ash
            leg.strokeColor = .clear
            leg.position = CGPoint(x: xOff * s, y: 1.5 * s)
            leg.name = xOff < 0 ? "leg_left" : "leg_right"
            container.addChild(leg)
        }

        // Seat
        let seat = SKShapeNode(rectOf: CGSize(width: 7 * s, height: 1.5 * s))
        seat.fillColor = PushlingPalette.ash
        seat.strokeColor = .clear
        seat.position = CGPoint(x: 0, y: 3.75 * s)
        seat.name = "seat"
        container.addChild(seat)

        // Back
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

        // Pole
        let pole = SKShapeNode(rectOf: CGSize(width: 0.5 * s, height: 8 * s))
        pole.fillColor = PushlingPalette.ash
        pole.strokeColor = .clear
        pole.position = CGPoint(x: 0, y: 4 * s)
        pole.name = "pole"
        container.addChild(pole)

        // Flag rect
        let flag = SKShapeNode(rectOf: CGSize(width: 3 * s, height: 2 * s))
        flag.fillColor = PushlingPalette.ember
        flag.strokeColor = .clear
        flag.position = CGPoint(x: 1.75 * s, y: 7 * s)
        flag.name = "flag"

        // Gentle sway (+-5 degrees over 2s)
        let swayLeft = SKAction.rotate(toAngle: 0.087, duration: 1.0)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = SKAction.rotate(toAngle: -0.087, duration: 1.0)
        swayRight.timingMode = .easeInEaseOut
        flag.run(SKAction.repeatForever(
            SKAction.sequence([swayLeft, swayRight])
        ), withKey: "sway")
        container.addChild(flag)

        return container
    }

    // MARK: - 20. Candle

    /// Rect body + teardrop flame + glow circle.
    static func buildCandle(size: CGFloat) -> SKNode {
        let s = size
        let container = SKNode()
        container.name = "composite_candle"

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: 1.5 * s, height: 3 * s))
        body.fillColor = PushlingPalette.withAlpha(PushlingPalette.bone, alpha: 0.8)
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: 1.5 * s)
        body.name = "body"
        container.addChild(body)

        // Teardrop flame
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

        // Glow
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

// MARK: - Composite Lookup

extension CompositeShapeFactory {

    /// Attempts to build a composite shape for the given preset name and base shape.
    /// Returns nil if no composite is available (caller falls back to single-shape).
    ///
    /// - Parameters:
    ///   - presetName: The object's preset name (e.g., "campfire", "cozy_bed").
    ///   - baseShape: The base shape string (e.g., "triangle", "dome").
    ///   - size: Scale factor (typically 0.5-2.0, default 1.0).
    /// - Returns: An SKNode container with composite children, or nil.
    static func buildCompositeShape(
        presetName: String,
        baseShape: String,
        size: CGFloat
    ) -> SKNode? {
        let name = presetName.lowercased()

        // Check preset name first (most specific).
        // Order matters: more specific names (e.g., "yarn_ball") before generic ("ball").
        if name.contains("campfire") {
            return buildCampfire(size: size)
        } else if name.contains("tree") {
            return buildTree(size: size)
        } else if name.contains("flower") {
            return buildFlower(size: size)
        } else if name.contains("mushroom") {
            return buildMushroom(size: size)
        } else if name.contains("fish") {
            return buildFish(size: size)
        } else if name.contains("cozy_bed") || name.contains("bed") {
            return buildCozyBed(size: size)
        } else if name.contains("scratching_post") || name.contains("scratch") {
            return buildScratchingPost(size: size)
        } else if name.contains("cardboard_box") {
            return buildCardboardBox(size: size)
        } else if name.contains("music_box") {
            return buildMusicBox(size: size)
        } else if name.contains("lantern") {
            return buildLantern(size: size)
        } else if name.contains("crystal") {
            return buildCrystal(size: size)
        } else if name.contains("yarn_ball") || name.contains("yarn") {
            return buildBall(size: size, includeThread: true)
        } else if name.contains("ball") {
            return buildBall(size: size, includeThread: false)
        } else if name.contains("fountain") {
            return buildFountain(size: size)
        } else if name.contains("milk") || name.contains("saucer") {
            return buildMilkSaucer(size: size)
        } else if name.contains("treat") {
            return buildTreat(size: size)
        } else if name.contains("mirror") {
            return buildLittleMirror(size: size)
        } else if name.contains("rock") {
            return buildRock(size: size)
        } else if name.contains("bench") {
            return buildBench(size: size)
        } else if name.contains("flag") {
            return buildFlag(size: size)
        } else if name.contains("candle") {
            return buildCandle(size: size)
        }

        // Fall back to base shape for broader matches
        switch baseShape {
        case "spr_bed":
            return buildCozyBed(size: size)
        case "spr_pillar":
            return buildScratchingPost(size: size)
        case "spr_music_box":
            return buildMusicBox(size: size)
        case "spr_lantern":
            return buildLantern(size: size)
        case "spr_crystal":
            return buildCrystal(size: size)
        case "spr_yarn_ball":
            return buildBall(size: size, includeThread: true)
        case "spr_fountain":
            return buildFountain(size: size)
        case "spr_mirror":
            return buildLittleMirror(size: size)
        case "spr_candle":
            return buildCandle(size: size)
        default:
            return nil
        }
    }
}
