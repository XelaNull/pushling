// DiamondIndicator.swift — Claude's presence indicator on the Touch Bar
// A ~4x4pt diamond near the creature. Per-frame update, no SKActions.
// Color: Tide. Gilt flash on subagent reconvergence only.

import SpriteKit

// MARK: - Diamond Visual State

/// Visual state of the diamond, driven by SessionManager events.
enum DiamondVisualState: Equatable {
    case hidden
    case materializing(elapsed: TimeInterval)
    case idle
    case thinking
    case active(elapsed: TimeInterval)
    case dissolving(elapsed: TimeInterval, duration: TimeInterval)
    case flickering(elapsed: TimeInterval, flickerCount: Int)
    case split(count: Int, elapsed: TimeInterval)
    case reconverging(elapsed: TimeInterval)

    static func == (lhs: DiamondVisualState, rhs: DiamondVisualState) -> Bool {
        switch (lhs, rhs) {
        case (.hidden, .hidden), (.idle, .idle), (.thinking, .thinking): return true
        default: return false
        }
    }
}

// MARK: - Diamond Indicator Node

final class DiamondIndicator: SKNode {

    // MARK: - Constants

    private static let diamondSize: CGFloat = 4.0
    private static let offsetX: CGFloat = 10.0
    private static let offsetY: CGFloat = 5.0
    private static let materializeDuration: TimeInterval = 1.0
    private static let cleanDissolveDuration: TimeInterval = 5.0
    private static let abruptDissolveDuration: TimeInterval = 2.0
    private static let flickerDuration: TimeInterval = 1.0
    private static let flickerTargetCount = 6
    private static let floatAmplitude: CGFloat = 0.5
    private static let floatPeriod: TimeInterval = 3.0
    private static let thinkingPulsePeriod: TimeInterval = 2.0
    private static let activeSparkleDuration: TimeInterval = 0.4
    private static let dissolveParticleCount = 8
    private static let subDiamondSize: CGFloat = 2.0
    private static let maxSplitCount = 5
    private static let reconvergeDuration: TimeInterval = 0.6
    private static let splitArcRadius: CGFloat = 6.0

    // MARK: - Nodes

    private var diamondNode: SKShapeNode?
    private var glowNode: SKShapeNode?
    private var dissolveParticles: [SKShapeNode] = []
    private var subDiamonds: [SKShapeNode] = []

    // MARK: - Animation State

    private(set) var visualState: DiamondVisualState = .hidden
    private var floatTime: TimeInterval = 0
    private var thinkingTime: TimeInterval = 0
    private var baseOffset: CGPoint
    private(set) var idleOpacityMultiplier: CGFloat = 1.0
    private var targetOpacityMultiplier: CGFloat = 1.0

    // MARK: - Init

    override init() {
        self.baseOffset = CGPoint(x: Self.offsetX, y: Self.offsetY)
        super.init()
        self.name = "diamond_indicator"
        self.zPosition = 15
        self.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Setup

    func setup() {
        let glow = SKShapeNode(path: Self.diamondPath(size: Self.diamondSize * 2.0))
        glow.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.15)
        glow.strokeColor = .clear
        glow.zPosition = -1
        glow.name = "diamond_glow"
        addChild(glow)
        self.glowNode = glow

        let diamond = SKShapeNode(path: Self.diamondPath(size: Self.diamondSize))
        diamond.fillColor = PushlingPalette.tide
        diamond.strokeColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.6)
        diamond.lineWidth = 0.5
        diamond.name = "diamond_main"
        addChild(diamond)
        self.diamondNode = diamond

        self.position = baseOffset
    }

    // MARK: - State Transitions

    func materialize() {
        guard case .hidden = visualState else { return }
        visualState = .materializing(elapsed: 0)
        isHidden = false
        alpha = 0
        diamondNode?.setScale(0.01)
        glowNode?.setScale(0.01)
        floatTime = 0; thinkingTime = 0
        idleOpacityMultiplier = 1.0; targetOpacityMultiplier = 1.0
        position = baseOffset
        NSLog("[Pushling/Diamond] Materializing")
    }

    func setThinking() {
        guard !isInTransition else { return }
        visualState = .thinking; thinkingTime = 0
    }

    func setActive() {
        guard !isInTransition else { return }
        visualState = .active(elapsed: 0)
    }

    func setIdle() {
        guard !isInTransition else { return }
        visualState = .idle
    }

    func dissolveClean() {
        guard !isDissolving else { return }
        createDissolveParticles()
        visualState = .dissolving(elapsed: 0, duration: Self.cleanDissolveDuration)
        NSLog("[Pushling/Diamond] Dissolving (clean, %.1fs)", Self.cleanDissolveDuration)
    }

    func dissolveAbrupt() {
        guard !isDissolving else { return }
        visualState = .flickering(elapsed: 0, flickerCount: 0)
        NSLog("[Pushling/Diamond] Flickering (abrupt disconnect)")
    }

    func splitInto(count: Int) {
        let n = min(count, Self.maxSplitCount)
        guard n > 0 else { return }
        diamondNode?.isHidden = true; glowNode?.isHidden = true
        removeSubDiamonds()
        for i in 0..<n {
            let sub = SKShapeNode(path: Self.diamondPath(size: Self.subDiamondSize))
            sub.fillColor = PushlingPalette.tide
            sub.strokeColor = .clear
            sub.name = "sub_diamond_\(i)"
            sub.position = .zero; sub.alpha = 0
            addChild(sub)
            subDiamonds.append(sub)
        }
        visualState = .split(count: n, elapsed: 0)
        NSLog("[Pushling/Diamond] Splitting into %d sub-diamonds", n)
    }

    func reconverge() {
        guard case .split = visualState else { return }
        visualState = .reconverging(elapsed: 0)
        NSLog("[Pushling/Diamond] Reconverging")
    }

    func setIdleOpacity(_ opacity: CGFloat) {
        targetOpacityMultiplier = max(0.3, min(1.0, opacity))
    }

    func forceHide() {
        visualState = .hidden; isHidden = true; alpha = 0
        removeDissolveParticles(); removeSubDiamonds()
        diamondNode?.isHidden = false; glowNode?.isHidden = false
        diamondNode?.setScale(1.0); glowNode?.setScale(1.0)
    }

    // MARK: - Per-Frame Update

    func update(deltaTime: TimeInterval) {
        // Smooth opacity interpolation
        let diff = targetOpacityMultiplier - idleOpacityMultiplier
        if abs(diff) > 0.01 {
            idleOpacityMultiplier += diff * CGFloat(min(deltaTime * 5.0, 1.0))
        } else {
            idleOpacityMultiplier = targetOpacityMultiplier
        }

        switch visualState {
        case .hidden: return
        case .materializing(let e):  updateMaterializing(elapsed: e, dt: deltaTime)
        case .idle:                  updateIdle(dt: deltaTime)
        case .thinking:              updateThinking(dt: deltaTime)
        case .active(let e):         updateActive(elapsed: e, dt: deltaTime)
        case .dissolving(let e, let d): updateDissolving(elapsed: e, dur: d, dt: deltaTime)
        case .flickering(let e, let c): updateFlickering(elapsed: e, count: c, dt: deltaTime)
        case .split(let n, let e):   updateSplit(count: n, elapsed: e, dt: deltaTime)
        case .reconverging(let e):   updateReconverging(elapsed: e, dt: deltaTime)
        }
    }

    // MARK: - Animation Updates

    private func updateMaterializing(elapsed: TimeInterval, dt: TimeInterval) {
        let t = elapsed + dt
        let p = min(t / Self.materializeDuration, 1.0)
        let ep = CGFloat(Easing.easeOut(p))

        diamondNode?.setScale(ep); glowNode?.setScale(ep)
        alpha = ep * idleOpacityMultiplier

        // Scale overshoot for juiciness in last 30%
        if p > 0.7 {
            let overshoot: CGFloat = 1.0 + 0.1 * (1.0 - CGFloat((p - 0.7) / 0.3))
            diamondNode?.setScale(overshoot)
        }

        if t >= Self.materializeDuration {
            diamondNode?.setScale(1.0); glowNode?.setScale(1.0)
            alpha = idleOpacityMultiplier
            visualState = .idle
            NSLog("[Pushling/Diamond] Materialized")
        } else {
            visualState = .materializing(elapsed: t)
        }
    }

    private func updateIdle(dt: TimeInterval) {
        floatTime += dt
        let floatY = sin(floatTime * 2.0 * .pi / Self.floatPeriod) * Self.floatAmplitude
        position = CGPoint(x: baseOffset.x, y: baseOffset.y + CGFloat(floatY))

        let gp = 0.12 + 0.05 * sin(floatTime * 1.3)
        glowNode?.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: CGFloat(gp))
        alpha = idleOpacityMultiplier
    }

    private func updateThinking(dt: TimeInterval) {
        thinkingTime += dt; floatTime += dt
        let pulse = 0.85 + 0.15 * CGFloat(sin(thinkingTime * 2.0 * .pi / Self.thinkingPulsePeriod))
        alpha = pulse * idleOpacityMultiplier

        let floatY = sin(floatTime * 2.0 * .pi / Self.floatPeriod) * Self.floatAmplitude
        position = CGPoint(x: baseOffset.x, y: baseOffset.y + CGFloat(floatY))

        let gp = 0.15 + 0.08 * sin(thinkingTime * 1.5)
        glowNode?.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: CGFloat(gp))
    }

    private func updateActive(elapsed: TimeInterval, dt: TimeInterval) {
        let t = elapsed + dt
        let sp = t / Self.activeSparkleDuration

        if sp < 0.3 {
            let b = CGFloat(sp / 0.3)
            diamondNode?.fillColor = PushlingPalette.lerp(
                from: PushlingPalette.tide, to: PushlingPalette.bone, t: b * 0.4)
            diamondNode?.setScale(1.0 + b * 0.3)
            glowNode?.setScale((1.0 + b * 0.3) * 1.5)
        } else {
            let fb = CGFloat((sp - 0.3) / 0.7)
            let peakColor = PushlingPalette.lerp(
                from: PushlingPalette.tide, to: PushlingPalette.bone, t: 0.4)
            diamondNode?.fillColor = PushlingPalette.lerp(
                from: peakColor, to: PushlingPalette.tide, t: fb)
            diamondNode?.setScale(1.3 - fb * 0.3)
            glowNode?.setScale((1.3 - fb * 0.3) * 1.5)
        }

        alpha = idleOpacityMultiplier
        if t >= Self.activeSparkleDuration {
            diamondNode?.fillColor = PushlingPalette.tide
            diamondNode?.setScale(1.0); glowNode?.setScale(1.0)
            visualState = .thinking
        } else {
            visualState = .active(elapsed: t)
        }
    }

    private func updateDissolving(elapsed: TimeInterval, dur: TimeInterval,
                                   dt: TimeInterval) {
        let t = elapsed + dt
        let p = min(t / dur, 1.0)
        diamondNode?.isHidden = true; glowNode?.isHidden = true

        let ep = CGFloat(Easing.easeOut(p))
        for (i, particle) in dissolveParticles.enumerated() {
            let angle = CGFloat(i) / CGFloat(dissolveParticles.count) * .pi * 2.0
            let scatter = ep * 12.0
            particle.position = CGPoint(x: cos(angle) * scatter, y: sin(angle) * scatter)
            particle.alpha = (1.0 - ep) * idleOpacityMultiplier
            particle.zRotation = ep * .pi * 0.5
        }

        if t >= dur {
            removeDissolveParticles()
            diamondNode?.isHidden = false; glowNode?.isHidden = false
            visualState = .hidden; isHidden = true; alpha = 0
            NSLog("[Pushling/Diamond] Dissolve complete")
        } else {
            visualState = .dissolving(elapsed: t, duration: dur)
        }
    }

    private func updateFlickering(elapsed: TimeInterval, count: Int, dt: TimeInterval) {
        let t = elapsed + dt
        let interval = Self.flickerDuration / TimeInterval(Self.flickerTargetCount)
        let idx = Int(t / interval)

        if idx != count {
            alpha = (idx % 2 == 0) ? 0.2 : 1.0
        }
        visualState = .flickering(elapsed: t, flickerCount: idx)

        if t >= Self.flickerDuration {
            createDissolveParticles()
            visualState = .dissolving(elapsed: 0, duration: Self.abruptDissolveDuration)
            NSLog("[Pushling/Diamond] Flicker complete — fast dissolving")
        }
    }

    private func updateSplit(count: Int, elapsed: TimeInterval, dt: TimeInterval) {
        let t = elapsed + dt
        let spreadDur: TimeInterval = 0.5
        let p = min(t / spreadDur, 1.0)
        let ep = CGFloat(Easing.easeOut(p))

        for (i, sub) in subDiamonds.enumerated() {
            let frac = CGFloat(i) / max(1, CGFloat(count - 1))
            let angle: CGFloat = -.pi / 3.0 + frac * (.pi * 2.0 / 3.0)
            let tx = cos(angle + .pi / 2.0) * Self.splitArcRadius
            let ty = sin(angle + .pi / 2.0) * Self.splitArcRadius
            sub.position = CGPoint(x: tx * ep, y: ty * ep)
            let pulse = 0.7 + 0.3 * sin((t + Double(i) * 0.3) * 2.5)
            sub.alpha = CGFloat(pulse) * ep * idleOpacityMultiplier
        }
        visualState = .split(count: count, elapsed: t)
    }

    private func updateReconverging(elapsed: TimeInterval, dt: TimeInterval) {
        let t = elapsed + dt
        let p = min(t / Self.reconvergeDuration, 1.0)
        let ep = CGFloat(Easing.easeIn(p))

        for sub in subDiamonds {
            sub.position = CGPoint(
                x: sub.position.x * (1.0 - ep), y: sub.position.y * (1.0 - ep))
            sub.alpha = (1.0 - ep * 0.5) * idleOpacityMultiplier
            sub.setScale(1.0 - ep * 0.5)
        }

        if t >= Self.reconvergeDuration {
            removeSubDiamonds()
            diamondNode?.isHidden = false; glowNode?.isHidden = false
            // Gilt flash on reconvergence
            diamondNode?.fillColor = PushlingPalette.gilt
            diamondNode?.setScale(1.5)
            glowNode?.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.3)
            glowNode?.setScale(2.0)
            visualState = .active(elapsed: 0)
            NSLog("[Pushling/Diamond] Reconverged — Gilt flash")
        } else {
            visualState = .reconverging(elapsed: t)
        }
    }

    // MARK: - Particle Management

    private func createDissolveParticles() {
        removeDissolveParticles()
        for i in 0..<Self.dissolveParticleCount {
            let p = SKShapeNode(path: Self.diamondPath(size: Self.diamondSize * 0.4))
            p.fillColor = PushlingPalette.tide; p.strokeColor = .clear
            p.name = "dissolve_\(i)"; p.position = .zero; p.zPosition = 1
            addChild(p)
            dissolveParticles.append(p)
        }
    }

    private func removeDissolveParticles() {
        dissolveParticles.forEach { $0.removeFromParent() }
        dissolveParticles.removeAll()
    }

    private func removeSubDiamonds() {
        subDiamonds.forEach { $0.removeFromParent() }
        subDiamonds.removeAll()
    }

    // MARK: - Helpers

    private var isInTransition: Bool {
        switch visualState {
        case .materializing, .dissolving, .flickering, .reconverging: return true
        default: return false
        }
    }

    private var isDissolving: Bool {
        switch visualState {
        case .dissolving, .flickering: return true
        default: return false
        }
    }

    private static func diamondPath(size: CGFloat) -> CGPath {
        let h = size / 2.0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: h, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -h))
        path.addLine(to: CGPoint(x: -h, y: 0))
        path.closeSubpath()
        return path
    }

    func nodeCount() -> Int { 1 + children.count }
}
