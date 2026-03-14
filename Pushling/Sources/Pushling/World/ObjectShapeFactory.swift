// ObjectShapeFactory.swift — Shape building, coloring, and effects for world objects
// Extracted from WorldObjectRenderer to keep files under 500 lines.
// Creates SKShapeNode compositions from base shape names, palette colors, and effects.

import SpriteKit

// MARK: - ObjectShapeFactory

/// Factory for building SKNodes from object definitions.
enum ObjectShapeFactory {

    // MARK: - Base Shape Building

    /// Creates the base SKShapeNode for a given shape type.
    static func buildBaseShape(_ shape: String, size: CGFloat) -> SKShapeNode {
        let scale = size
        let node: SKShapeNode

        switch shape {
        // Geometric primitives
        case "sphere", "spr_ball":
            node = SKShapeNode(circleOfRadius: 3.0 * scale)
        case "cube", "box", "spr_box":
            node = SKShapeNode(rectOf: CGSize(width: 6 * scale, height: 5 * scale),
                               cornerRadius: 0.5)
        case "triangle", "pyramid":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 5 * scale))
            path.addLine(to: CGPoint(x: -3 * scale, y: 0))
            path.addLine(to: CGPoint(x: 3 * scale, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case "dome":
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 3 * scale,
                       startAngle: 0, endAngle: .pi, clockwise: false)
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case "pillar", "spr_pillar":
            node = SKShapeNode(rectOf: CGSize(width: 2 * scale, height: 8 * scale))
        case "disc":
            node = SKShapeNode(ellipseOf: CGSize(width: 6 * scale, height: 2 * scale))
        case "star_shape":
            node = buildStarShape(size: scale)
        case "diamond":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 4 * scale))
            path.addLine(to: CGPoint(x: 3 * scale, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -4 * scale))
            path.addLine(to: CGPoint(x: -3 * scale, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)

        // Iconic sprites (rendered as shapes)
        case "spr_yarn_ball":
            node = SKShapeNode(circleOfRadius: 2.5 * scale)
        case "spr_bed":
            node = SKShapeNode(rectOf: CGSize(width: 8 * scale, height: 3 * scale),
                               cornerRadius: 1.5)
        case "spr_feather":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 4 * scale))
            path.addQuadCurve(to: CGPoint(x: 0, y: -2 * scale),
                              control: CGPoint(x: 2 * scale, y: 1 * scale))
            path.addQuadCurve(to: CGPoint(x: 0, y: 4 * scale),
                              control: CGPoint(x: -1 * scale, y: 1 * scale))
            node = SKShapeNode(path: path)
        case "spr_mouse_toy":
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -2 * scale, y: -1.5 * scale,
                                       width: 4 * scale, height: 3 * scale))
            node = SKShapeNode(path: path)
        case "spr_candle", "spr_lantern":
            node = SKShapeNode(rectOf: CGSize(width: 2 * scale, height: 4 * scale),
                               cornerRadius: 0.5)
        case "spr_crystal":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 5 * scale))
            path.addLine(to: CGPoint(x: 2 * scale, y: 1 * scale))
            path.addLine(to: CGPoint(x: 1 * scale, y: 0))
            path.addLine(to: CGPoint(x: -1 * scale, y: 0))
            path.addLine(to: CGPoint(x: -2 * scale, y: 1 * scale))
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case "spr_flower":
            node = SKShapeNode(circleOfRadius: 2 * scale)
        case "spr_fountain":
            node = SKShapeNode(rectOf: CGSize(width: 5 * scale, height: 4 * scale),
                               cornerRadius: 1)
        case "spr_mirror":
            node = SKShapeNode(ellipseOf: CGSize(width: 3 * scale, height: 5 * scale))
        case "spr_music_box":
            node = SKShapeNode(rectOf: CGSize(width: 4 * scale, height: 3 * scale),
                               cornerRadius: 0.5)
        case "spr_bell":
            let path = CGMutablePath()
            path.addArc(center: CGPoint(x: 0, y: 1 * scale), radius: 2 * scale,
                       startAngle: .pi, endAngle: 0, clockwise: false)
            path.addLine(to: CGPoint(x: 3 * scale, y: 0))
            path.addLine(to: CGPoint(x: -3 * scale, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case "spr_cushion":
            node = SKShapeNode(rectOf: CGSize(width: 6 * scale, height: 2 * scale),
                               cornerRadius: 1)
        case "spr_platform":
            node = SKShapeNode(rectOf: CGSize(width: 8 * scale, height: 2 * scale))
        case "spr_basket":
            node = SKShapeNode(rectOf: CGSize(width: 5 * scale, height: 3 * scale),
                               cornerRadius: 1)
        case "spr_fish_toy":
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -2.5 * scale, y: -1 * scale,
                                       width: 5 * scale, height: 2 * scale))
            node = SKShapeNode(path: path)
        case "spr_orb":
            node = SKShapeNode(circleOfRadius: 2 * scale)
        case "spr_snow_globe":
            node = SKShapeNode(circleOfRadius: 3 * scale)
        case "spr_ribbon":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -2 * scale, y: 2 * scale))
            path.addQuadCurve(to: CGPoint(x: 2 * scale, y: -2 * scale),
                              control: CGPoint(x: 0, y: 0))
            node = SKShapeNode(path: path)
            node.lineWidth = 1.0

        default:
            node = SKShapeNode(circleOfRadius: 3.0 * scale)
        }

        node.name = "base"
        node.lineWidth = 0.5
        return node
    }

    /// Builds a 5-pointed star shape.
    private static func buildStarShape(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        let points = 5
        let outerRadius = 3.0 * size
        let innerRadius = 1.5 * size
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(x: cos(angle) * radius,
                                 y: sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return SKShapeNode(path: path)
    }

    // MARK: - Coloring

    /// Applies palette colors to a shape node.
    static func applyColor(to node: SKShapeNode,
                            primary: String,
                            secondary: String?,
                            pattern: String) {
        let primaryColor = paletteColor(named: primary)
        node.fillColor = primaryColor
        node.strokeColor = PushlingPalette.withAlpha(primaryColor, alpha: 0.6)

        switch pattern {
        case "glow":
            node.glowWidth = 2.0
        case "gradient":
            if let sec = secondary {
                node.strokeColor = paletteColor(named: sec)
            }
        default:
            break
        }
    }

    /// Resolves a palette color name to an SKColor.
    static func paletteColor(named name: String) -> SKColor {
        switch name.lowercased() {
        case "bone":  return PushlingPalette.bone
        case "ember": return PushlingPalette.ember
        case "moss":  return PushlingPalette.moss
        case "tide":  return PushlingPalette.tide
        case "gilt":  return PushlingPalette.gilt
        case "dusk":  return PushlingPalette.dusk
        case "ash":   return PushlingPalette.ash
        default:      return PushlingPalette.bone
        }
    }

    // MARK: - Effects

    /// Builds an effect child node for an object.
    static func buildEffect(_ effect: String, size: CGFloat,
                             color: String) -> SKNode? {
        switch effect {
        case "glow":
            let glow = SKShapeNode(circleOfRadius: 4 * size)
            glow.fillColor = PushlingPalette.withAlpha(
                paletteColor(named: color), alpha: 0.15)
            glow.strokeColor = .clear
            glow.name = "effect_glow"
            glow.zPosition = -1
            return glow

        case "particle":
            let emitter = SKShapeNode(circleOfRadius: 0.5)
            emitter.fillColor = paletteColor(named: color)
            emitter.strokeColor = .clear
            emitter.name = "effect_particle"
            emitter.alpha = 0.6
            return emitter

        case "pulse", "bob", "spin", "sway":
            // Handled per-frame in WorldObjectRenderer.update
            return nil

        default:
            return nil
        }
    }
}
