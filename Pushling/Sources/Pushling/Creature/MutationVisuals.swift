// MutationVisuals.swift — Visual effects for earned mutation badges
// Each badge produces a permanent visual modification to the creature.
// Effects are additive — multiple badges stack without conflicting.
// Node budget: each badge adds 0-1 nodes (shader effects or particle reconfig).

import SpriteKit

// MARK: - Mutation Visuals Manager

final class MutationVisualsManager {

    // MARK: - State

    /// Active visual effect nodes, keyed by badge.
    private var effectNodes: [MutationBadge: SKNode] = [:]

    /// The creature node these effects are attached to.
    private weak var creature: CreatureNode?

    /// Accumulated time for animated effects.
    private var animationTime: TimeInterval = 0

    // MARK: - Configuration

    /// Attach to a creature node and apply all earned badge visuals.
    func configure(creature: CreatureNode,
                    earnedBadges: Set<MutationBadge>) {
        self.creature = creature
        // Remove any existing effects
        for (_, node) in effectNodes {
            node.removeFromParent()
        }
        effectNodes.removeAll()

        // Apply each earned badge
        for badge in earnedBadges {
            applyBadgeVisual(badge)
        }

        NSLog("[Pushling/Mutation] Applied %d badge visuals", earnedBadges.count)
    }

    /// Apply a newly earned badge visual (with shimmer ceremony).
    func onBadgeEarned(_ badge: MutationBadge, withCeremony: Bool = true) {
        applyBadgeVisual(badge)

        if withCeremony {
            playEarnCeremony(badge)
        }
    }

    // MARK: - Per-Frame Update

    /// Update animated badge effects.
    func update(deltaTime: TimeInterval) {
        animationTime += deltaTime
        updateNocturneGlow(deltaTime: deltaTime)
        updateMarathonTrail(deltaTime: deltaTime)
        updateSwarmParticles(deltaTime: deltaTime)
        updateNineLivesHalo(deltaTime: deltaTime)
        updatePolyglotHue(deltaTime: deltaTime)
        updateBilingualTail(deltaTime: deltaTime)
    }

    // MARK: - Apply Badge Visual

    private func applyBadgeVisual(_ badge: MutationBadge) {
        guard let creature = creature else { return }

        switch badge {
        case .nocturne:
            let glowNode = createNocturneGlow()
            creature.addChild(glowNode)
            effectNodes[.nocturne] = glowNode

        case .polyglot:
            // Color-shifting handled via per-frame hue update
            let markerNode = SKNode()
            markerNode.name = "polyglot_marker"
            creature.addChild(markerNode)
            effectNodes[.polyglot] = markerNode

        case .marathon:
            let trailNode = createMarathonTrail()
            creature.addChild(trailNode)
            effectNodes[.marathon] = trailNode

        case .archaeologist:
            let pickaxeNode = createPickaxeMark()
            creature.addChild(pickaxeNode)
            effectNodes[.archaeologist] = pickaxeNode

        case .guardian:
            // Shield flash is triggered per-commit, not persistent
            let shieldNode = createShieldFlash()
            shieldNode.alpha = 0
            creature.addChild(shieldNode)
            effectNodes[.guardian] = shieldNode

        case .swarm:
            let buzzNode = createSwarmParticles()
            creature.addChild(buzzNode)
            effectNodes[.swarm] = buzzNode

        case .whisperer:
            let scrollNode = createScrollMark()
            creature.addChild(scrollNode)
            effectNodes[.whisperer] = scrollNode

        case .firstLight:
            let sunNode = createSunriseMark()
            creature.addChild(sunNode)
            effectNodes[.firstLight] = sunNode

        case .nineLives:
            let haloNode = createHalo()
            creature.addChild(haloNode)
            effectNodes[.nineLives] = haloNode

        case .bilingual:
            // Split-color tail handled by tail controller modification
            let markerNode = SKNode()
            markerNode.name = "bilingual_marker"
            creature.addChild(markerNode)
            effectNodes[.bilingual] = markerNode
        }
    }

    // MARK: - Visual Constructors

    private func createNocturneGlow() -> SKShapeNode {
        let glow = SKShapeNode(circleOfRadius: 8)
        glow.name = "nocturne_glow"
        glow.fillColor = SKColor(red: 0.48, green: 0.18, blue: 0.74,
                                  alpha: 0.0)  // Dusk tint, starts invisible
        glow.strokeColor = .clear
        glow.glowWidth = 3
        glow.zPosition = -1
        glow.blendMode = .add
        return glow
    }

    private func createMarathonTrail() -> SKNode {
        let container = SKNode()
        container.name = "marathon_trail"
        // Pre-create 5 small circles that trail behind during walking
        for i in 0..<5 {
            let dot = SKShapeNode(circleOfRadius: 0.6)
            dot.fillColor = PushlingPalette.ember
            dot.strokeColor = .clear
            dot.alpha = 0
            dot.name = "trail_dot_\(i)"
            dot.zPosition = -1
            container.addChild(dot)
        }
        return container
    }

    private func createPickaxeMark() -> SKShapeNode {
        // Tiny 1px pickaxe mark on left ear area
        let mark = SKShapeNode(rectOf: CGSize(width: 1, height: 1))
        mark.name = "pickaxe_mark"
        mark.fillColor = SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.8)
        mark.strokeColor = .clear
        mark.position = CGPoint(x: -4, y: 8)  // Near left ear
        mark.zPosition = 5
        return mark
    }

    private func createShieldFlash() -> SKShapeNode {
        let shield = SKShapeNode(circleOfRadius: 10)
        shield.name = "guardian_shield"
        shield.fillColor = SKColor(red: 0.0, green: 0.7, blue: 0.85,
                                    alpha: 0.3)  // Tide color
        shield.strokeColor = SKColor(red: 0.0, green: 0.7, blue: 0.85,
                                      alpha: 0.6)
        shield.glowWidth = 2
        shield.zPosition = 10
        shield.blendMode = .add
        return shield
    }

    private func createSwarmParticles() -> SKNode {
        let container = SKNode()
        container.name = "swarm_particles"
        // 3-4 tiny orbiting dots
        for i in 0..<4 {
            let dot = SKShapeNode(circleOfRadius: 0.5)
            dot.fillColor = SKColor(red: 0.9, green: 0.8, blue: 0.2,
                                     alpha: 0.7)
            dot.strokeColor = .clear
            dot.name = "swarm_dot_\(i)"
            dot.zPosition = 6
            container.addChild(dot)
        }
        return container
    }

    private func createScrollMark() -> SKShapeNode {
        // Tiny curl pattern on right side
        let scroll = SKShapeNode(rectOf: CGSize(width: 1.5, height: 2))
        scroll.name = "scroll_mark"
        scroll.fillColor = SKColor(red: 0.85, green: 0.78, blue: 0.6,
                                    alpha: 0.7)  // Gilt-ish
        scroll.strokeColor = .clear
        scroll.position = CGPoint(x: 5, y: 0)
        scroll.zPosition = 5
        return scroll
    }

    private func createSunriseMark() -> SKShapeNode {
        // Tiny Gilt dot on forehead
        let mark = SKShapeNode(circleOfRadius: 0.5)
        mark.name = "sunrise_mark"
        mark.fillColor = SKColor(red: 0.85, green: 0.65, blue: 0.13,
                                  alpha: 0.9)  // Gilt
        mark.strokeColor = .clear
        mark.position = CGPoint(x: 0, y: 7)  // Forehead
        mark.zPosition = 5
        mark.glowWidth = 1
        return mark
    }

    private func createHalo() -> SKShapeNode {
        // Faint 1px Gilt ring above head
        let halo = SKShapeNode(circleOfRadius: 4)
        halo.name = "nine_lives_halo"
        halo.fillColor = .clear
        halo.strokeColor = SKColor(red: 0.85, green: 0.65, blue: 0.13,
                                    alpha: 0.2)  // Gilt, very faint
        halo.lineWidth = 0.75
        halo.position = CGPoint(x: 0, y: 12)
        halo.zPosition = 6
        return halo
    }

    // MARK: - Animated Effects

    private func updateNocturneGlow(deltaTime: TimeInterval) {
        guard let glow = effectNodes[.nocturne] as? SKShapeNode else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = hour >= 22 || hour < 6
        let targetAlpha: CGFloat = isNight ? 0.15 : 0.0
        let pulse = isNight
            ? 0.05 * CGFloat(sin(animationTime * 1.5))
            : 0
        glow.alpha = targetAlpha + pulse
    }

    private func updateMarathonTrail(deltaTime: TimeInterval) {
        guard let container = effectNodes[.marathon],
              let creature = creature else { return }

        // Trail dots follow behind the creature, spaced by index,
        // fading out further back. Only visible during movement.
        let isMoving = abs(creature.position.x - marathonLastX) > 0.3
        marathonLastX = creature.position.x

        for (i, child) in container.children.enumerated() {
            let offset = CGFloat(i + 1) * -2.5
            child.position = CGPoint(x: offset, y: -1)
            let targetAlpha: CGFloat = isMoving
                ? CGFloat(1.0 - Double(i) / 5.0) * 0.5
                : 0
            child.alpha += (targetAlpha - child.alpha) * CGFloat(deltaTime * 4.0)
        }
    }
    private var marathonLastX: CGFloat = 0

    private func updateSwarmParticles(deltaTime: TimeInterval) {
        guard let container = effectNodes[.swarm] else { return }
        // Orbit the dots around the creature
        for (i, child) in container.children.enumerated() {
            let angle = animationTime * 3.0 + Double(i) * (.pi / 2.0)
            let radius: CGFloat = 6
            child.position = CGPoint(
                x: CGFloat(cos(angle)) * radius,
                y: CGFloat(sin(angle)) * radius + 3
            )
        }
    }

    private func updateNineLivesHalo(deltaTime: TimeInterval) {
        guard let halo = effectNodes[.nineLives] as? SKShapeNode else { return }
        // Gentle alpha pulse
        let alpha = 0.15 + 0.05 * CGFloat(sin(animationTime * 0.8))
        halo.strokeColor = SKColor(
            red: 0.85, green: 0.65, blue: 0.13, alpha: alpha
        )
    }

    private func updatePolyglotHue(deltaTime: TimeInterval) {
        guard effectNodes[.polyglot] != nil,
              let creature = creature,
              let bodyNode = creature.childNode(withName: "body") as? SKShapeNode else {
            return
        }
        // Subtle per-frame hue rotation on the creature body color (+-10 degrees)
        let hueOffset = CGFloat(sin(animationTime * 0.2)) * (10.0 / 360.0)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        PushlingPalette.bone.getHue(&hue, saturation: &sat,
                                      brightness: &bri, alpha: &alpha)
        bodyNode.fillColor = SKColor(hue: hue + hueOffset,
                                      saturation: max(0.05, sat + 0.03),
                                      brightness: bri, alpha: alpha)
    }

    private func updateBilingualTail(deltaTime: TimeInterval) {
        guard effectNodes[.bilingual] != nil,
              let creature = creature,
              let baseSeg = creature.childNode(withName: "tail_seg_0") as? SKShapeNode else {
            return
        }
        // Alternating two-tone effect: oscillate all tail segment stroke colors
        // between Tide and Ember at a slow rate (3s cycle)
        let t = CGFloat((sin(animationTime * 2.0 / 3.0) + 1.0) / 2.0)
        let color = PushlingPalette.lerp(
            from: PushlingPalette.tide,
            to: PushlingPalette.ember,
            t: t
        )
        baseSeg.strokeColor = color
        for child in baseSeg.children {
            if let seg = child as? SKShapeNode,
               let name = seg.name, name.hasPrefix("tail_seg_") {
                seg.strokeColor = color
                // Also color nested segments
                for grandchild in seg.children {
                    if let gs = grandchild as? SKShapeNode,
                       let gn = gs.name, gn.hasPrefix("tail_seg_") {
                        gs.strokeColor = color
                    }
                }
            }
        }
    }

    // MARK: - Guardian Shield Flash

    /// Flash the guardian shield (called on commit eat).
    func flashGuardianShield() {
        guard let shield = effectNodes[.guardian] as? SKShapeNode else { return }
        shield.alpha = 0.6
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
        shield.run(fadeOut, withKey: "shield_flash")
    }

    // MARK: - Earn Ceremony

    /// Play the shimmer animation when a badge is first earned.
    private func playEarnCeremony(_ badge: MutationBadge) {
        guard let node = effectNodes[badge] else { return }

        // Shimmer: bright flash -> settle to normal
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let hold = SKAction.wait(forDuration: 1.0)
        let settle = SKAction.fadeAlpha(to: 0.3, duration: 1.0)
        let sequence = SKAction.sequence([fadeIn, hold, settle])
        node.run(sequence, withKey: "badge_earn_shimmer")

        NSLog("[Pushling/Mutation] Playing earn ceremony for %@",
              badge.displayName)
    }

    // MARK: - Query

    /// Whether a specific badge visual is active.
    func hasBadgeVisual(_ badge: MutationBadge) -> Bool {
        effectNodes[badge] != nil
    }

    /// Node count added by all badge visuals.
    var totalNodeCount: Int {
        effectNodes.values.reduce(0) { sum, node in
            sum + 1 + node.children.count
        }
    }
}
