// CatShapes.swift — Bezier CGPath factories for cat body parts
// Replaces geometric primitives (circles, triangles) with organic cat shapes.
// All paths are centered at origin. Sizes are in Touch Bar points.
//
// Stage progression:
//   Spore  = orb (unchanged)
//   Drop   = teardrop with proto-ears
//   Critter = kitten proportions (big head, stubby body)
//   Beast  = full cat (shoulder bump, belly swell, haunch)
//   Sage   = refined cat (slimmer, elegant proportions)
//   Apex   = ethereal cat (translucent, flowing lines)

import CoreGraphics

/// Static enum providing Bezier CGPath factories for every cat body part.
/// All paths are centered at (0, 0) and sized relative to the provided dimensions.
enum CatShapes {

    // MARK: - Body

    /// Cat body with shoulder bump, belly swell, and haunch.
    /// More organic than a simple ellipse.
    /// - Parameters:
    ///   - width: Total body width in points
    ///   - height: Total body height in points
    ///   - stage: Growth stage (affects proportions)
    static func catBody(width w: CGFloat, height h: CGFloat,
                        stage: GrowthStage = .beast) -> CGPath {
        let path = CGMutablePath()
        let hw = w / 2
        let hh = h / 2

        // Proportional adjustments per stage
        let shoulderBump: CGFloat
        let bellyDrop: CGFloat
        let haunchWidth: CGFloat

        switch stage {
        case .egg, .drop:
            shoulderBump = 0.0
            bellyDrop = 0.0
            haunchWidth = 1.0
        case .critter:
            // Kitten: rotund belly, rounder
            shoulderBump = 0.05
            bellyDrop = 0.12
            haunchWidth = 0.95
        case .beast:
            // Full cat: defined shoulders, leaner body
            shoulderBump = 0.18
            bellyDrop = 0.12
            haunchWidth = 0.9
        case .sage:
            // Refined: slimmer, elegant
            shoulderBump = 0.08
            bellyDrop = 0.1
            haunchWidth = 0.85
        case .apex:
            // Ethereal: flowing, elongated
            shoulderBump = 0.06
            bellyDrop = 0.08
            haunchWidth = 0.88
        }

        // Start at front-top (chest area), go clockwise
        // Front chest
        path.move(to: CGPoint(x: hw * 0.7, y: hh * 0.6))

        // Top line: shoulder bump
        path.addCurve(
            to: CGPoint(x: hw * 0.1, y: hh),
            control1: CGPoint(x: hw * 0.5, y: hh * (0.8 + shoulderBump)),
            control2: CGPoint(x: hw * 0.3, y: hh * (1.0 + shoulderBump))
        )

        // Back spine to haunch
        path.addCurve(
            to: CGPoint(x: -hw * haunchWidth, y: hh * 0.3),
            control1: CGPoint(x: -hw * 0.2, y: hh * 0.95),
            control2: CGPoint(x: -hw * 0.7, y: hh * 0.7)
        )

        // Haunch curve down to rear
        path.addCurve(
            to: CGPoint(x: -hw * haunchWidth, y: -hh * 0.3),
            control1: CGPoint(x: -hw * (haunchWidth + 0.1), y: hh * 0.1),
            control2: CGPoint(x: -hw * (haunchWidth + 0.1), y: -hh * 0.1)
        )

        // Bottom line: belly swell
        path.addCurve(
            to: CGPoint(x: hw * 0.3, y: -hh * 0.5),
            control1: CGPoint(x: -hw * 0.5, y: -hh * (0.7 + bellyDrop)),
            control2: CGPoint(x: 0, y: -hh * (0.8 + bellyDrop))
        )

        // Front chest underside back up to start
        path.addCurve(
            to: CGPoint(x: hw * 0.7, y: hh * 0.6),
            control1: CGPoint(x: hw * 0.5, y: -hh * 0.2),
            control2: CGPoint(x: hw * 0.7, y: hh * 0.1)
        )

        path.closeSubpath()
        return path
    }

    // MARK: - Head

    /// Cat head: wider than tall, chin taper, cheek bulge.
    /// - Parameters:
    ///   - radius: Base radius in points
    ///   - stage: Growth stage (kittens have proportionally larger heads)
    static func catHead(radius r: CGFloat,
                        stage: GrowthStage = .beast) -> CGPath {
        let path = CGMutablePath()

        // Width-to-height ratio (cats have wide faces)
        let widthScale: CGFloat
        let chinTaper: CGFloat

        let muzzleSize: CGFloat

        switch stage {
        case .egg, .drop:
            widthScale = 1.0  // Round
            chinTaper = 0.0
            muzzleSize = 0.0
        case .critter:
            widthScale = 1.15  // Slightly wide, baby roundness
            chinTaper = 0.1
            muzzleSize = 0.05
        case .beast:
            widthScale = 1.2   // Proper cat face width
            chinTaper = 0.2
            muzzleSize = 0.15
        case .sage:
            widthScale = 1.15  // Refined, slightly narrower
            chinTaper = 0.25
            muzzleSize = 0.12
        case .apex:
            widthScale = 1.1   // Ethereal, more symmetrical
            chinTaper = 0.15
            muzzleSize = 0.1
        }

        let hw = r * widthScale
        let hh = r
        let muzzleOffset = r * muzzleSize

        // Start at top center, go clockwise
        path.move(to: CGPoint(x: 0, y: hh))

        // Right cheek bulge
        path.addCurve(
            to: CGPoint(x: hw, y: 0),
            control1: CGPoint(x: hw * 0.5, y: hh * 1.05),
            control2: CGPoint(x: hw * 1.05, y: hh * 0.5)
        )

        // Right chin taper
        path.addCurve(
            to: CGPoint(x: hw * (0.3 - chinTaper * 0.3), y: -hh),
            control1: CGPoint(x: hw * 1.0, y: -hh * 0.4),
            control2: CGPoint(x: hw * 0.6, y: -hh * 0.9)
        )

        // Chin curve with muzzle protrusion
        path.addCurve(
            to: CGPoint(x: -hw * (0.3 - chinTaper * 0.3), y: -hh),
            control1: CGPoint(x: hw * 0.1 + muzzleOffset,
                              y: -hh * (1.1 + muzzleSize)),
            control2: CGPoint(x: -hw * 0.1,
                              y: -hh * (1.1 + muzzleSize * 0.5))
        )

        // Left chin taper
        path.addCurve(
            to: CGPoint(x: -hw, y: 0),
            control1: CGPoint(x: -hw * 0.6, y: -hh * 0.9),
            control2: CGPoint(x: -hw * 1.0, y: -hh * 0.4)
        )

        // Left cheek bulge back to top
        path.addCurve(
            to: CGPoint(x: 0, y: hh),
            control1: CGPoint(x: -hw * 1.05, y: hh * 0.5),
            control2: CGPoint(x: -hw * 0.5, y: hh * 1.05)
        )

        path.closeSubpath()
        return path
    }

    // MARK: - Ears

    /// Cat ear with rounded tip and inner ear detail.
    /// Returns (outerPath, innerPath) — inner is the pink triangle.
    /// - Parameters:
    ///   - width: Ear width at base
    ///   - height: Ear height from base to tip
    ///   - isLeft: Mirror for left ear
    static func catEar(width w: CGFloat, height h: CGFloat,
                       isLeft: Bool) -> (outer: CGPath, inner: CGPath) {
        let hw = w / 2
        let mirror: CGFloat = isLeft ? 1 : -1

        // Outer ear — pointed tip, convex outward bow (cat, not bat)
        let outer = CGMutablePath()
        outer.move(to: CGPoint(x: -hw, y: 0))

        // Outer edge: slight convex outward bow (not concave bat-wing)
        outer.addCurve(
            to: CGPoint(x: mirror * hw * 0.05, y: h),
            control1: CGPoint(x: -hw * 1.1, y: h * 0.35),
            control2: CGPoint(x: -hw * 0.5, y: h * 0.85)
        )

        // Pointed tip — tight control for sharp cat ear point
        outer.addQuadCurve(
            to: CGPoint(x: hw * 0.25, y: h * 0.88),
            control: CGPoint(x: hw * 0.05, y: h * 1.01)
        )

        // Inner edge — nearly straight with gentle curve
        outer.addCurve(
            to: CGPoint(x: hw, y: 0),
            control1: CGPoint(x: hw * 0.35, y: h * 0.6),
            control2: CGPoint(x: hw * 0.75, y: h * 0.15)
        )
        outer.closeSubpath()

        // Inner ear triangle (Ember pink area)
        let inner = CGMutablePath()
        let inset: CGFloat = 0.3
        inner.move(to: CGPoint(x: -hw * (1 - inset), y: h * 0.1))
        inner.addLine(to: CGPoint(x: mirror * hw * 0.05, y: h * 0.8))
        inner.addLine(to: CGPoint(x: hw * (1 - inset * 1.2), y: h * 0.1))
        inner.closeSubpath()

        return (outer, inner)
    }

    // MARK: - Nose

    /// Tiny inverted triangle nose.
    /// - Parameter size: Nose width/height in points
    static func catNose(size s: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let hw = s / 2
        let hh = s * 0.4

        // Inverted triangle with rounded bottom
        path.move(to: CGPoint(x: -hw, y: hh))
        path.addLine(to: CGPoint(x: hw, y: hh))
        path.addQuadCurve(
            to: CGPoint(x: -hw, y: hh),
            control: CGPoint(x: 0, y: -hh)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Eyes

    /// Almond-shaped cat eye — pointed at inner and outer corners.
    /// Stage-dependent roundness: Critter nearly round, Beast+ true almond.
    /// - Parameters:
    ///   - radius: Base eye radius in points
    ///   - stage: Growth stage (affects roundness)
    static func catEye(radius r: CGFloat,
                       stage: GrowthStage = .beast) -> CGPath {
        let path = CGMutablePath()

        // Roundness: 1.0 = circular, 0.5 = sharp almond
        let roundness: CGFloat
        switch stage {
        case .egg, .drop:
            roundness = 1.0
        case .critter:
            roundness = 0.85
        case .beast:
            roundness = 0.65
        case .sage:
            roundness = 0.6
        case .apex:
            roundness = 0.55
        }

        let hw = r
        let hh = r * roundness
        let tiltY = r * 0.08  // slight upward tilt on outer corner

        // Inner corner (positive X) to outer corner (negative X)
        path.move(to: CGPoint(x: hw, y: -tiltY))

        // Upper lid arc
        path.addCurve(
            to: CGPoint(x: -hw, y: tiltY),
            control1: CGPoint(x: hw * 0.5, y: hh),
            control2: CGPoint(x: -hw * 0.5, y: hh)
        )

        // Lower lid arc (shallower)
        path.addCurve(
            to: CGPoint(x: hw, y: -tiltY),
            control1: CGPoint(x: -hw * 0.5, y: -hh * 0.7),
            control2: CGPoint(x: hw * 0.5, y: -hh * 0.7)
        )

        path.closeSubpath()
        return path
    }

    /// Vertical slit pupil — tall oval that dilates via xScale.
    /// At xScale 0.25 = narrow slit, xScale 1.0 = full round.
    /// - Parameter radius: Pupil radius
    static func catPupil(radius r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -r, y: -r * 1.3,
                                    width: r * 2, height: r * 2.6))
        return path
    }

    // MARK: - Mouth

    /// Cat smile `:3` curve — two arcs meeting at center with nostril dip.
    /// - Parameter width: Total mouth width
    static func catMouth(width w: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let hw = w / 2

        // Left arc of the :3 smile
        path.move(to: CGPoint(x: -hw, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: -w * 0.15),
            control: CGPoint(x: -hw * 0.4, y: -w * 0.35)
        )

        // Right arc of the :3 smile
        path.addQuadCurve(
            to: CGPoint(x: hw, y: 0),
            control: CGPoint(x: hw * 0.4, y: -w * 0.35)
        )

        return path
    }

    // MARK: - Tail

    /// Tail with thick-to-thin taper and natural S-curve.
    /// Returns the path — caller creates SKShapeNode and sets lineWidth.
    /// - Parameters:
    ///   - length: Total tail length
    ///   - stage: Growth stage (affects curvature)
    static func catTail(length: CGFloat,
                        stage: GrowthStage = .beast) -> CGPath {
        let path = CGMutablePath()

        let curveFactor: CGFloat
        switch stage {
        case .egg, .drop:
            curveFactor = 0.3
        case .critter:
            curveFactor = 0.5  // Stubby, less curve
        case .beast:
            curveFactor = 0.7  // Full S-curve
        case .sage:
            curveFactor = 0.8  // Elegant sweep
        case .apex:
            curveFactor = 0.9  // Flowing, dramatic
        }

        // S-curve: base at origin, curves up and back
        path.move(to: .zero)
        path.addCurve(
            to: CGPoint(x: -length * 0.5, y: length * 0.85),
            control1: CGPoint(x: -length * 0.2 * curveFactor, y: length * 0.05),
            control2: CGPoint(x: -length * 0.7 * curveFactor, y: length * 0.35)
        )

        // Tip curl
        path.addQuadCurve(
            to: CGPoint(x: -length * 0.35, y: length * 0.95),
            control: CGPoint(x: -length * 0.55, y: length * 1.0)
        )

        return path
    }

    // MARK: - Paws

    /// Bean-shaped paw with optional toe pad detail.
    /// - Parameters:
    ///   - size: Paw diameter
    ///   - showToes: Whether to include toe pad circles (Beast+)
    /// - Returns: (pawPath, toePadPaths) — toePadPaths empty if showToes is false
    static func catPaw(size s: CGFloat,
                       showToes: Bool = false)
        -> (paw: CGPath, toePads: [CGPath]) {
        let path = CGMutablePath()
        let hw = s / 2
        let hh = s * 0.55  // Slightly taller than wide

        // Bean shape — rounded rectangle with slight asymmetry
        path.move(to: CGPoint(x: 0, y: hh))
        path.addCurve(
            to: CGPoint(x: hw, y: 0),
            control1: CGPoint(x: hw * 0.7, y: hh),
            control2: CGPoint(x: hw, y: hh * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -hh),
            control1: CGPoint(x: hw, y: -hh * 0.5),
            control2: CGPoint(x: hw * 0.6, y: -hh)
        )
        path.addCurve(
            to: CGPoint(x: -hw, y: 0),
            control1: CGPoint(x: -hw * 0.6, y: -hh),
            control2: CGPoint(x: -hw, y: -hh * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: hh),
            control1: CGPoint(x: -hw, y: hh * 0.5),
            control2: CGPoint(x: -hw * 0.7, y: hh)
        )
        path.closeSubpath()

        var toePads: [CGPath] = []
        if showToes {
            // 3 toe pads across the top
            let toeR = s * 0.12
            let toeY = hh * 0.3
            let toeSpacing = hw * 0.55

            for i in -1...1 {
                let toeX = CGFloat(i) * toeSpacing
                let toe = CGMutablePath()
                toe.addEllipse(in: CGRect(
                    x: toeX - toeR, y: toeY - toeR,
                    width: toeR * 2, height: toeR * 2
                ))
                toePads.append(toe)
            }

            // Central pad (larger, below toes)
            let padR = s * 0.15
            let pad = CGMutablePath()
            pad.addEllipse(in: CGRect(
                x: -padR, y: -hh * 0.2 - padR,
                width: padR * 2, height: padR * 1.8
            ))
            toePads.append(pad)
        }

        return (paw: path, toePads: toePads)
    }

    // MARK: - Legs

    /// Cat leg — organic tapered column connecting body to paw.
    /// Front legs are straighter; back legs have a slight thigh bulge.
    /// Always visible (not zoom-gated).
    /// - Parameters:
    ///   - height: Leg height in points
    ///   - width: Leg width in points
    ///   - isFront: Front legs taper straight, back legs have thigh curve
    static func catLeg(height: CGFloat, width: CGFloat,
                       isFront: Bool) -> CGPath {
        let path = CGMutablePath()
        let tw = width * 0.5   // top half-width (at body)
        let bw = width * 0.35  // bottom half-width (at paw)

        path.move(to: CGPoint(x: -tw, y: height))

        if isFront {
            // Front leg: clean inward taper
            path.addCurve(
                to: CGPoint(x: -bw, y: 0),
                control1: CGPoint(x: -tw * 0.9, y: height * 0.6),
                control2: CGPoint(x: -bw * 0.85, y: height * 0.15)
            )
        } else {
            // Back leg: slight outward thigh bulge then taper in
            path.addCurve(
                to: CGPoint(x: -bw, y: 0),
                control1: CGPoint(x: -tw * 1.25, y: height * 0.65),
                control2: CGPoint(x: -bw * 0.7, y: height * 0.12)
            )
        }

        path.addLine(to: CGPoint(x: bw, y: 0))

        if isFront {
            path.addCurve(
                to: CGPoint(x: tw, y: height),
                control1: CGPoint(x: bw * 0.85, y: height * 0.15),
                control2: CGPoint(x: tw * 0.9, y: height * 0.6)
            )
        } else {
            path.addCurve(
                to: CGPoint(x: tw, y: height),
                control1: CGPoint(x: bw * 0.7, y: height * 0.12),
                control2: CGPoint(x: tw * 1.25, y: height * 0.65)
            )
        }

        path.closeSubpath()
        return path
    }

    // MARK: - Teardrop (Drop Stage Body)

    /// Teardrop body for the Drop stage.
    /// Enhanced from the original with smoother curves.
    static func teardropBody(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()

        // Rounded bottom, pointed top — smoother Bezier
        path.move(to: CGPoint(x: 0, y: height * 0.4))
        path.addCurve(
            to: CGPoint(x: width * 0.4, y: -height * 0.2),
            control1: CGPoint(x: width * 0.15, y: height * 0.4),
            control2: CGPoint(x: width * 0.42, y: height * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: -width * 0.4, y: -height * 0.2),
            control1: CGPoint(x: width * 0.35, y: -height * 0.45),
            control2: CGPoint(x: -width * 0.35, y: -height * 0.45)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: height * 0.4),
            control1: CGPoint(x: -width * 0.42, y: height * 0.1),
            control2: CGPoint(x: -width * 0.15, y: height * 0.4)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Body Silhouette (for effects)

    /// Simplified body silhouette for ghost echo, puddle reflection, SDF glow.
    /// Cheaper than the full body path — fewer control points.
    /// - Parameters:
    ///   - width: Body width
    ///   - height: Body height
    ///   - stage: Growth stage
    static func bodySilhouette(width w: CGFloat, height h: CGFloat,
                               stage: GrowthStage) -> CGPath {
        switch stage {
        case .egg:
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -w / 2, y: -h / 2,
                                        width: w, height: h))
            return path
        case .drop:
            return teardropBody(width: w, height: h)
        default:
            // Simplified cat silhouette with shoulder/haunch definition
            let path = CGMutablePath()
            let hw = w / 2
            let hh = h / 2

            path.move(to: CGPoint(x: hw * 0.6, y: hh * 0.5))
            // Shoulder bump
            path.addCurve(
                to: CGPoint(x: -hw * 0.8, y: hh * 0.3),
                control1: CGPoint(x: hw * 0.3, y: hh * 1.1),
                control2: CGPoint(x: -hw * 0.4, y: hh * 0.95)
            )
            // Haunch with inward indentation
            path.addCurve(
                to: CGPoint(x: -hw * 0.85, y: -hh * 0.4),
                control1: CGPoint(x: -hw * 1.05, y: hh * 0.1),
                control2: CGPoint(x: -hw * 1.05, y: -hh * 0.2)
            )
            // Belly
            path.addCurve(
                to: CGPoint(x: hw * 0.3, y: -hh * 0.5),
                control1: CGPoint(x: -hw * 0.4, y: -hh * 0.9),
                control2: CGPoint(x: 0, y: -hh * 0.95)
            )
            // Chest
            path.addCurve(
                to: CGPoint(x: hw * 0.6, y: hh * 0.5),
                control1: CGPoint(x: hw * 0.5, y: -hh * 0.1),
                control2: CGPoint(x: hw * 0.65, y: hh * 0.1)
            )
            path.closeSubpath()
            return path
        }
    }

    // MARK: - Whiskers

    /// Single whisker as a slight arc (not a straight line).
    /// - Parameters:
    ///   - length: Whisker length in points
    ///   - droop: Downward droop factor (0 = straight, 0.3 = noticeable)
    static func whisker(length: CGFloat, droop: CGFloat = -0.08) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(
            to: CGPoint(x: length, y: 0),
            control: CGPoint(x: length * 0.5, y: -length * droop)
        )
        return path
    }

    // MARK: - Fur Texture Sub-Paths

    /// Optional fur texture lines overlaid on the body.
    /// Zero node cost — these are sub-paths added to the body CGPath.
    /// - Parameters:
    ///   - bodyWidth: Body width to scale strokes to
    ///   - bodyHeight: Body height
    ///   - density: 0.0 (none) to 1.0 (full coverage)
    static func furTexture(bodyWidth w: CGFloat, bodyHeight h: CGFloat,
                           density: CGFloat = 0.3) -> CGPath {
        let path = CGMutablePath()
        let count = Int(density * 8)
        let hw = w / 2
        let hh = h / 2

        // Short directional strokes along the body contour
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            // Distribute along the body's top curve
            let x = hw * 0.6 - t * w * 0.8
            let y = hh * (0.3 + 0.4 * sin(t * .pi))  // Follow body curve
            let strokeLen = w * 0.06

            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - strokeLen * 0.7,
                                      y: y + strokeLen * 0.3))
        }

        return path
    }
}
