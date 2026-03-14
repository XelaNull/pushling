// EvolutionProgressBar.swift — 1pt progress bar at bottom edge
// P3-T3-07: Appears when creature is within 80% of next stage threshold.
//
// Width proportional to XP progress within current stage.
// Color matches creature's path color.
// At 95%+: pulsing alpha (0.5 -> 1.0, 1Hz sinusoidal).
// At 99%+: intensified pulse (0.3 -> 1.0, 2Hz) with color shift toward Gilt.
// Disappears during evolution ceremony.
//
// Node budget: 1 node (SKShapeNode rectangle). Updated on XP change, not every frame.
// The pulse is a per-frame sine calculation, not an SKAction (for smooth control).

import SpriteKit

// MARK: - Evolution Progress Bar

/// A 1-pixel progress bar at the very bottom of the Touch Bar.
/// Appears as the creature approaches evolution threshold.
final class EvolutionProgressBar {

    // MARK: - Constants

    /// Scene width for full-width calculation.
    private static let sceneWidth: CGFloat = 1085.0

    /// Bar height — single pixel row.
    private static let barHeight: CGFloat = 1.0

    /// Threshold to begin showing the bar (80% of stage progress).
    private static let showThreshold: CGFloat = 0.80

    /// Threshold for pulse start.
    private static let pulseThreshold: CGFloat = 0.95

    /// Threshold for intense pulse.
    private static let intensePulseThreshold: CGFloat = 0.99

    // MARK: - Nodes

    /// The progress bar shape node.
    private let barNode: SKShapeNode

    // MARK: - State

    /// Current progress (0.0 to 1.0) within the stage.
    private var progress: CGFloat = 0

    /// The bar color (stage-specific).
    private var barColor: SKColor = PushlingPalette.moss

    /// Whether the bar is currently visible.
    private(set) var isVisible = false

    /// Whether the bar is hidden for evolution ceremony.
    private var isCeremonyHidden = false

    /// Accumulated time for pulse animation.
    private var pulseTime: TimeInterval = 0

    // MARK: - Init

    init() {
        barNode = SKShapeNode(
            rectOf: CGSize(width: 0, height: Self.barHeight)
        )
        barNode.fillColor = PushlingPalette.moss
        barNode.strokeColor = .clear
        barNode.position = CGPoint(x: 0, y: Self.barHeight / 2)
        barNode.alpha = 0
        barNode.name = "evolution_progress_bar"
        barNode.zPosition = 400  // Above world, below HUD
    }

    // MARK: - Scene Integration

    /// Add the bar to the scene. Call once during setup.
    func addToScene(_ scene: SKScene) {
        scene.addChild(barNode)
    }

    // MARK: - XP Update

    /// Update the progress bar with current XP state.
    /// Call when XP changes (not every frame).
    /// - Parameters:
    ///   - currentXP: XP accumulated in current stage.
    ///   - xpToNext: Total XP needed for next stage.
    ///   - stage: Current creature stage.
    func updateXP(currentXP: Int, xpToNext: Int, stage: GrowthStage) {
        guard xpToNext > 0 else {
            hideBar()
            return
        }

        progress = CGFloat(currentXP) / CGFloat(xpToNext)
        barColor = PushlingPalette.stageColor(for: stage)

        if progress >= Self.showThreshold && !isCeremonyHidden {
            showBar()
            updateBarWidth()
        } else {
            hideBar()
        }
    }

    // MARK: - Per-Frame Update

    /// Per-frame update for pulse animation.
    /// Only does work when visible and progress >= 95%.
    func update(deltaTime: TimeInterval) {
        guard isVisible && !isCeremonyHidden else { return }

        if progress >= Self.pulseThreshold {
            pulseTime += deltaTime

            let alpha: CGFloat
            let color: SKColor

            if progress >= Self.intensePulseThreshold {
                // Intense pulse: 0.3 -> 1.0, 2Hz, color shifts toward Gilt
                let sine = CGFloat(sin(2.0 * .pi * pulseTime * 2.0))
                alpha = 0.65 + 0.35 * sine

                // Blend color toward Gilt over the final 1%
                let giltBlend = (progress - Self.intensePulseThreshold)
                    / (1.0 - Self.intensePulseThreshold)
                color = PushlingPalette.lerp(from: barColor,
                                              to: PushlingPalette.gilt,
                                              t: min(1.0, giltBlend))
            } else {
                // Normal pulse: 0.5 -> 1.0, 1Hz
                let sine = CGFloat(sin(2.0 * .pi * pulseTime * 1.0))
                alpha = 0.75 + 0.25 * sine
                color = barColor
            }

            barNode.alpha = alpha
            barNode.fillColor = color

        } else {
            // No pulse — steady display
            barNode.alpha = 0.8
            barNode.fillColor = barColor
        }
    }

    // MARK: - Show / Hide

    private func showBar() {
        guard !isVisible else { return }
        isVisible = true
        pulseTime = 0
        barNode.removeAllActions()
        barNode.run(
            SKAction.fadeAlpha(to: 0.8, duration: 0.3),
            withKey: "barFadeIn"
        )
    }

    private func hideBar() {
        guard isVisible else { return }
        isVisible = false
        barNode.run(
            SKAction.fadeAlpha(to: 0, duration: 0.3),
            withKey: "barFadeOut"
        )
    }

    private func updateBarWidth() {
        // Remap progress from showThreshold..1.0 to 0..sceneWidth
        let displayProgress = (progress - Self.showThreshold)
            / (1.0 - Self.showThreshold)
        let width = max(1, displayProgress * Self.sceneWidth)

        // Rebuild the bar shape with new width
        let rect = CGRect(x: 0, y: -Self.barHeight / 2,
                          width: width, height: Self.barHeight)
        barNode.path = CGPath(rect: rect, transform: nil)
    }

    // MARK: - Evolution Ceremony

    /// Hide the bar during evolution ceremony.
    func hideForCeremony() {
        isCeremonyHidden = true
        barNode.removeAllActions()
        barNode.run(SKAction.fadeAlpha(to: 0, duration: 0.2))
        isVisible = false
    }

    /// Show the bar after evolution ceremony (resets to 0%).
    func showAfterCeremony() {
        isCeremonyHidden = false
        progress = 0
        // Bar will naturally appear again when XP reaches threshold
    }

    // MARK: - Node Count

    /// Nodes contributed to scene budget.
    var nodeCount: Int { 1 }
}
