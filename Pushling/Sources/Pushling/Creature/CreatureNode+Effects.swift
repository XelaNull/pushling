// CreatureNode+Effects.swift — Visual effects for the creature
// Phase 4 enhancements: SDF glow, normal-mapped lighting overlay.
// These are lightweight overlays — 1 node each, updated per-frame.

import SpriteKit

extension CreatureNode {

    // MARK: - SDF Glow (Phase 4.2)

    /// Creates and attaches a glow node — body silhouette at 1.3x scale,
    /// additive blend, alpha 0.15, pulsing with breathing.
    /// Stage-gated: Critter+ (alive complexity).
    func setupGlow(stage: GrowthStage) {
        // Remove existing glow
        childNode(withName: "sdf_glow")?.removeFromParent()

        guard stage >= .critter else { return }
        guard let config = StageConfiguration.all[stage] else { return }

        let silhouette = CatShapes.bodySilhouette(
            width: config.size.width * 1.3,
            height: config.size.height * 1.3,
            stage: stage
        )
        let glowNode = SKShapeNode(path: silhouette)
        glowNode.fillColor = PushlingPalette.stageColor(for: stage)
        glowNode.strokeColor = .clear
        glowNode.alpha = 0.12
        glowNode.blendMode = .add
        glowNode.name = "sdf_glow"
        glowNode.zPosition = 3  // Behind body (z=10) but above aura (z=1)
        glowNode.glowWidth = stage >= .beast ? 6 : 4
        addChild(glowNode)
    }

    /// Update glow alpha to pulse with breathing.
    /// Called from the main update loop.
    func updateGlow(breathScale: CGFloat) {
        guard let glow = childNode(withName: "sdf_glow") as? SKShapeNode else { return }
        // Map breathScale (1.0 to 1.03) to glow alpha (0.10 to 0.18)
        let breathFactor = (breathScale - 1.0) / 0.03  // 0 to 1
        glow.alpha = 0.10 + breathFactor * 0.08
    }

    // MARK: - Normal-Mapped Lighting Overlay (Phase 4.1)

    /// Creates a lighting direction overlay that tints the creature based on
    /// the sky system's light direction (dawn=right, day=above, dusk=left, night=below).
    /// Stage-gated: Beast+ (thriving complexity).
    func setupLightingOverlay(stage: GrowthStage) {
        // Remove existing overlay
        childNode(withName: "light_overlay")?.removeFromParent()

        guard stage >= .beast else { return }
        guard let config = StageConfiguration.all[stage] else { return }

        let silhouette = CatShapes.bodySilhouette(
            width: config.size.width,
            height: config.size.height,
            stage: stage
        )
        let overlay = SKShapeNode(path: silhouette)
        overlay.fillColor = PushlingPalette.bone
        overlay.strokeColor = .clear
        overlay.alpha = 0.06
        overlay.blendMode = .multiply
        overlay.name = "light_overlay"
        overlay.zPosition = 15  // Above body (z=10)
        addChild(overlay)
    }

    /// Update lighting overlay tint based on time of day.
    /// - Parameter period: Current sky time period.
    func updateLighting(period: TimePeriod) {
        guard let overlay = childNode(withName: "light_overlay") as? SKShapeNode else { return }

        let tintColor: SKColor
        let tintAlpha: CGFloat

        switch period {
        case .dawn:
            // Light from the right (east)
            tintColor = PushlingPalette.ember
            tintAlpha = 0.08
            overlay.position = CGPoint(x: -0.5, y: 0)
        case .morning:
            tintColor = PushlingPalette.gilt
            tintAlpha = 0.05
            overlay.position = CGPoint(x: -0.3, y: -0.3)
        case .day:
            // Light from above
            tintColor = PushlingPalette.bone
            tintAlpha = 0.04
            overlay.position = CGPoint(x: 0, y: -0.5)
        case .goldenHour:
            tintColor = PushlingPalette.gilt
            tintAlpha = 0.1
            overlay.position = CGPoint(x: 0.5, y: 0)
        case .dusk:
            // Light from the left (west)
            tintColor = PushlingPalette.ember
            tintAlpha = 0.08
            overlay.position = CGPoint(x: 0.5, y: 0)
        case .evening:
            tintColor = PushlingPalette.dusk
            tintAlpha = 0.06
            overlay.position = CGPoint(x: 0.3, y: 0.3)
        case .lateNight, .deepNight:
            // Moonlight from above
            tintColor = PushlingPalette.tide
            tintAlpha = 0.04
            overlay.position = CGPoint(x: 0, y: -0.3)
        }

        overlay.fillColor = tintColor
        overlay.alpha = tintAlpha
    }

    // MARK: - Rarity Effects

    /// Attach rarity-tier visual effects to the creature node.
    /// Call this once after the egg cracks into a Drop. Effects are ADDITIVE
    /// to any existing glow/lighting and survive stage transitions (caller is
    /// responsible for tearing down on evolution via removeRarityEffects()).
    ///
    /// Node budget: ≤5 nodes. Z-range: 3-5 (behind body at z=10).
    /// Shiny outline uses z=17 (above body, very faint).
    ///
    /// - Parameters:
    ///   - rarity: The creature's hatched rarity tier.
    ///   - shiny: Whether the creature has the shiny variant.
    ///   - stage: Current growth stage (used for sizing).
    func setupRarityEffects(rarity: RarityTier, shiny: Bool, stage: GrowthStage) {
        // Clean up any prior rarity nodes
        removeRarityEffects()

        guard let config = StageConfiguration.all[stage] else { return }
        let w = config.size.width
        let h = config.size.height

        switch rarity {
        case .common:
            break  // No visual effect for common

        case .uncommon:
            // Soft glow pulse — a gentle aura behind the body
            let aura = SKShapeNode(ellipseOf: CGSize(width: w * 1.6,
                                                      height: h * 1.6))
            aura.fillColor = PushlingPalette.withAlpha(PushlingPalette.moss, alpha: 0.18)
            aura.strokeColor = .clear
            aura.blendMode = .add
            aura.name = "rarity_aura"
            aura.zPosition = 4
            addChild(aura)

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.08, duration: 1.2),
                SKAction.fadeAlpha(to: 0.18, duration: 1.2)
            ])
            aura.run(.repeatForever(pulse), withKey: "rarityPulse")

        case .rare:
            // Shimmer — two overlapping ellipses that alternate
            let shimmer1 = SKShapeNode(ellipseOf: CGSize(width: w * 1.8,
                                                          height: h * 1.8))
            shimmer1.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide, alpha: 0.20)
            shimmer1.strokeColor = .clear
            shimmer1.blendMode = .add
            shimmer1.name = "rarity_shimmer1"
            shimmer1.zPosition = 3
            addChild(shimmer1)

            let shimmer2 = SKShapeNode(ellipseOf: CGSize(width: w * 1.5,
                                                          height: h * 1.5))
            shimmer2.fillColor = PushlingPalette.withAlpha(PushlingPalette.moss, alpha: 0.12)
            shimmer2.strokeColor = .clear
            shimmer2.blendMode = .add
            shimmer2.name = "rarity_shimmer2"
            shimmer2.zPosition = 3
            addChild(shimmer2)

            let altForward = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.06, duration: 0.7),
                SKAction.fadeAlpha(to: 0.20, duration: 0.7)
            ])
            let altReverse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.20, duration: 0.7),
                SKAction.fadeAlpha(to: 0.06, duration: 0.7)
            ])
            shimmer1.run(.repeatForever(altForward), withKey: "rarityShimmer")
            shimmer2.run(.repeatForever(altReverse), withKey: "rarityShimmer2")

        case .epic:
            // Bright aura + two small star flecks
            let aura = SKShapeNode(ellipseOf: CGSize(width: w * 2.0,
                                                      height: h * 2.0))
            aura.fillColor = PushlingPalette.withAlpha(PushlingPalette.dusk, alpha: 0.28)
            aura.strokeColor = .clear
            aura.blendMode = .add
            aura.name = "rarity_aura"
            aura.zPosition = 4
            addChild(aura)

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.12, duration: 0.9),
                SKAction.fadeAlpha(to: 0.28, duration: 0.9)
            ])
            aura.run(.repeatForever(pulse), withKey: "rarityPulse")

            // Star fleck A — container rotates, star is offset from center
            let armA = SKNode()
            armA.name = "rarity_starA"
            armA.zPosition = 5
            addChild(armA)
            let starA = SKShapeNode(circleOfRadius: 1.0)
            starA.fillColor = PushlingPalette.gilt
            starA.strokeColor = .clear
            starA.blendMode = .add
            starA.position = CGPoint(x: w * 0.8, y: 0)
            armA.addChild(starA)
            armA.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3.0)),
                     withKey: "rarityOrbitA")

            // Star fleck B — counter-orbits
            let armB = SKNode()
            armB.name = "rarity_starB"
            armB.zPosition = 5
            addChild(armB)
            let starB = SKShapeNode(circleOfRadius: 1.0)
            starB.fillColor = PushlingPalette.gilt
            starB.strokeColor = .clear
            starB.blendMode = .add
            starB.position = CGPoint(x: -(w * 0.8), y: 0)
            armB.addChild(starB)
            armB.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 4.5)),
                     withKey: "rarityOrbitB")

        case .legendary:
            // Golden glow aura
            let aura = SKShapeNode(ellipseOf: CGSize(width: w * 2.2,
                                                      height: h * 2.2))
            aura.fillColor = PushlingPalette.withAlpha(PushlingPalette.gilt, alpha: 0.30)
            aura.strokeColor = .clear
            aura.blendMode = .add
            aura.name = "rarity_aura"
            aura.zPosition = 4
            addChild(aura)

            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.15, duration: 0.8),
                SKAction.fadeAlpha(to: 0.30, duration: 0.8)
            ])
            aura.run(.repeatForever(pulse), withKey: "rarityPulse")

            // Cosmic trail — three tiny sparks orbiting on arm containers
            let radius: CGFloat = w * 0.9
            for i in 0..<3 {
                let arm = SKNode()
                arm.name = "rarity_spark\(i)"
                arm.zPosition = 5
                // Pre-rotate arm so sparks start evenly distributed
                arm.zRotation = CGFloat(Double(i) * (.pi * 2.0 / 3.0))
                addChild(arm)

                let spark = SKShapeNode(circleOfRadius: 0.8)
                spark.fillColor = (i % 2 == 0)
                    ? PushlingPalette.gilt : PushlingPalette.ember
                spark.strokeColor = .clear
                spark.blendMode = .add
                spark.position = CGPoint(x: radius, y: 0)
                arm.addChild(spark)

                let period = 2.0 + Double(i) * 0.7
                arm.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: period)),
                        withKey: "rarityOrbit\(i)")
            }
        }

        // Shiny variant — rainbow shimmer fill (stacks with any tier)
        // Uses a very faint filled ellipse cycling through palette colors.
        // SKShapeNode does not support colorize action — we cycle via run blocks.
        if shiny {
            let shimmer = SKShapeNode(ellipseOf: CGSize(width: w * 1.35,
                                                         height: h * 1.35))
            shimmer.fillColor = PushlingPalette.withAlpha(PushlingPalette.tide,
                                                           alpha: 0.22)
            shimmer.strokeColor = .clear
            shimmer.blendMode = .add
            shimmer.name = "rarity_shiny"
            shimmer.zPosition = 17  // Above body, very faint
            addChild(shimmer)

            // Cycle fill color through palette to suggest rainbow shimmer
            let paletteColors: [SKColor] = [
                PushlingPalette.tide, PushlingPalette.moss,
                PushlingPalette.gilt, PushlingPalette.dusk,
                PushlingPalette.ember
            ]
            var colorSteps: [SKAction] = []
            for color in paletteColors {
                let tinted = PushlingPalette.withAlpha(color, alpha: 0.22)
                colorSteps.append(SKAction.sequence([
                    SKAction.run { shimmer.fillColor = tinted },
                    SKAction.wait(forDuration: 0.55)
                ]))
            }
            shimmer.run(.repeatForever(.sequence(colorSteps)),
                        withKey: "rarityShinyHue")
        }
    }

    /// Remove all rarity effect nodes. Call before evolution to clean up.
    func removeRarityEffects() {
        let rarityNodeNames = [
            "rarity_aura", "rarity_shimmer1", "rarity_shimmer2",
            "rarity_starA", "rarity_starB", "rarity_shiny",
            "rarity_spark0", "rarity_spark1", "rarity_spark2"
        ]
        for name in rarityNodeNames {
            childNode(withName: name)?.removeFromParent()
        }
    }

    /// Flash momentary directional light during storm lightning.
    func flashLightning() {
        guard let overlay = childNode(withName: "light_overlay") as? SKShapeNode else { return }
        let originalColor = overlay.fillColor
        let originalAlpha = overlay.alpha

        overlay.fillColor = PushlingPalette.bone
        overlay.alpha = 0.4

        let restore = SKAction.sequence([
            SKAction.wait(forDuration: 0.05),
            SKAction.run {
                overlay.fillColor = originalColor
                overlay.alpha = originalAlpha
            }
        ])
        overlay.run(restore, withKey: "lightningFlash")
    }
}
