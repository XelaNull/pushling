// CatShapes+DetailShapes.swift — Additional CGPath factories for detail features
// Tail segment paths for the segmented spring-physics tail chain.
// Zoom-dependent detail shapes (toe beans, ear tufts) for close-up views.

import CoreGraphics

extension CatShapes {

    // MARK: - Tail Segments (Phase: Segmented Tail)

    /// Single tail segment — a short curved stroke for the segmented tail chain.
    /// Each segment goes from (0,0) to a tip point offset by curveFactor.
    /// - Parameters:
    ///   - length: Segment length in points
    ///   - curveFactor: Lateral curve amount (0.1 = subtle, 0.3 = dramatic)
    static func tailSegment(length: CGFloat,
                            curveFactor: CGFloat = 0.15) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(
            to: CGPoint(x: -length * curveFactor, y: length),
            control: CGPoint(x: -length * curveFactor * 1.5,
                              y: length * 0.5)
        )
        return path
    }

    /// Tip position of a tail segment (for chaining child segments).
    static func tailSegmentTip(length: CGFloat,
                                curveFactor: CGFloat) -> CGPoint {
        CGPoint(x: -length * curveFactor, y: length)
    }

    // MARK: - Zoom Detail Shapes

    /// Toe bean paths for maximum zoom detail. 4 small beans per paw.
    /// - Parameter pawSize: Paw diameter in points
    static func toeBeans(pawSize: CGFloat) -> [CGPath] {
        let beanR = pawSize * 0.07
        let hw = pawSize / 2
        let hh = pawSize * 0.55

        var beans: [CGPath] = []

        // 3 small toe beans across the top
        let toeY = hh * 0.35
        let spacing = hw * 0.45
        for i in -1...1 {
            let x = CGFloat(i) * spacing
            let bean = CGMutablePath()
            bean.addEllipse(in: CGRect(x: x - beanR, y: toeY - beanR,
                                        width: beanR * 2,
                                        height: beanR * 2.2))
            beans.append(bean)
        }

        // 1 larger central pad bean
        let padR = pawSize * 0.1
        let pad = CGMutablePath()
        pad.addEllipse(in: CGRect(x: -padR, y: -hh * 0.15 - padR,
                                   width: padR * 2, height: padR * 1.8))
        beans.append(pad)

        return beans
    }

    /// Ear tuft strokes for maximum zoom detail.
    /// Short fur lines extending from the ear tip.
    /// - Parameter earHeight: Ear height in points
    static func earTuft(earHeight: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let tuftLen = earHeight * 0.2

        for i in 0..<3 {
            let angle = CGFloat(i - 1) * 0.25
            let startY = earHeight * 0.88
            path.move(to: CGPoint(x: 0, y: startY))
            path.addLine(to: CGPoint(
                x: sin(angle) * tuftLen,
                y: startY + cos(angle) * tuftLen
            ))
        }

        return path
    }
}
