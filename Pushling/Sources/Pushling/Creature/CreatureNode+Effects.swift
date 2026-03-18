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
