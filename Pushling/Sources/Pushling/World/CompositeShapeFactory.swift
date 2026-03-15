// CompositeShapeFactory.swift — Multi-node composite designs for world objects (1-10)
// Replaces single geometric primitives with recognizable 2-5 node compositions.
// Each composite is designed for the Touch Bar (1085x30pt, OLED true black).
//
// Builders 1-10 live here. Builders 11-20 are in CompositeShapeFactory+Items.swift.
// The composite lookup dispatcher is in CompositeShapeFactory+Lookup.swift.
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
}
