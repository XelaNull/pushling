// GhostEcho.swift — Faint shadow of creature's younger form
// P3-T3-05: At Sage+ stage, a barely-visible ghost replays the creature's past.
//
// The ghost is an alpha-0.08 silhouette of the creature at one stage below current.
// It walks 15-25pt behind the creature with a 0.3s timing delay.
// Appears for 30 seconds, then fades, with 2-5 minute cooldown between appearances.
// "Past and present coexist."
//
// Node budget: 1 node (the ghost shape). Only active at Sage+ and only intermittently.

import SpriteKit

// MARK: - Ghost Echo

/// Renders a faint echo of the creature's younger form walking alongside.
/// Available at Sage+ stage. Intermittent appearances create a discovery moment.
final class GhostEchoNode {

    // MARK: - Constants

    /// Ghost alpha — barely visible, a whisper.
    private static let ghostAlpha: CGFloat = 0.08

    /// Distance behind the creature (points).
    private static let trailingDistance: CGFloat = 20.0

    /// Timing delay for position tracking (seconds).
    private static let positionDelay: TimeInterval = 0.3

    /// Duration of each ghost appearance (seconds).
    private static let appearanceDuration: TimeInterval = 30.0

    /// Fade in/out duration (seconds).
    private static let fadeDuration: TimeInterval = 5.0

    /// Cooldown between appearances (seconds).
    private static let cooldownRange: ClosedRange<TimeInterval> = 120...300

    // MARK: - Nodes

    /// The ghost node — simplified creature silhouette.
    private let ghostNode: SKNode

    /// The ghost body shape (the visible part).
    private let ghostBody: SKShapeNode

    // MARK: - State

    /// Whether the ghost is currently visible (or fading in/out).
    private(set) var isAppearing = false

    /// Time remaining in the current appearance.
    private var appearanceTimer: TimeInterval = 0

    /// Cooldown timer until next appearance.
    private var cooldownTimer: TimeInterval = 0

    /// The stage the ghost represents (one below current creature stage).
    private var ghostStage: GrowthStage = .critter

    /// The current creature stage.
    private var currentCreatureStage: GrowthStage = .sage

    /// Position history buffer for delayed tracking.
    private var positionHistory: [(x: CGFloat, y: CGFloat, time: TimeInterval)] = []

    /// Accumulated time for position tracking.
    private var accumulatedTime: TimeInterval = 0

    /// Whether this system is enabled (Sage+ only).
    private(set) var isEnabled = false

    // MARK: - Init

    init() {
        ghostNode = SKNode()
        ghostNode.name = "ghost_echo"
        ghostNode.alpha = 0
        ghostNode.zPosition = 9  // Just below creature

        // Start with a generic small ellipse — will be reconfigured on stage change
        ghostBody = SKShapeNode(ellipseOf: CGSize(width: 14, height: 16))
        ghostBody.fillColor = PushlingPalette.ash
        ghostBody.strokeColor = .clear
        ghostBody.name = "ghost_body"
        ghostNode.addChild(ghostBody)

        // Initialize cooldown
        cooldownTimer = TimeInterval.random(in: Self.cooldownRange)
    }

    // MARK: - Scene Integration

    /// Add the ghost node to the foreground layer.
    func addToLayer(_ foreLayer: SKNode) {
        foreLayer.addChild(ghostNode)
    }

    /// Remove from scene.
    func removeFromScene() {
        ghostNode.removeFromParent()
    }

    // MARK: - Configuration

    /// Update for a new creature stage. Enables/disables based on stage gate.
    func configureForStage(_ stage: GrowthStage) {
        currentCreatureStage = stage
        isEnabled = stage >= .sage

        if isEnabled {
            // Ghost shows one stage below current (or random for Apex)
            if stage == .apex {
                // Apex: random past stage
                let pastStages: [GrowthStage] = [.spore, .drop, .critter, .beast, .sage]
                ghostStage = pastStages.randomElement() ?? .critter
            } else {
                ghostStage = GrowthStage(rawValue: stage.rawValue - 1) ?? .critter
            }
            rebuildGhostShape()
        } else {
            // Not enabled — hide immediately
            ghostNode.alpha = 0
            isAppearing = false
        }
    }

    /// Rebuild the ghost's visual shape for its stage.
    private func rebuildGhostShape() {
        guard let config = StageConfiguration.all[ghostStage] else { return }

        // Use CatShapes Bezier silhouette instead of a simple ellipse
        let path = CatShapes.bodySilhouette(
            width: config.size.width,
            height: config.size.height,
            stage: ghostStage
        )
        ghostBody.path = path
        ghostBody.fillColor = PushlingPalette.withAlpha(PushlingPalette.ash,
                                                         alpha: 1.0)
    }

    // MARK: - Frame Update

    /// Update the ghost echo system. Call each frame.
    /// - Parameters:
    ///   - creatureWorldX: Creature's current world-X.
    ///   - creatureY: Creature's current Y.
    ///   - creatureFacing: Creature's current facing direction.
    ///   - deltaTime: Time since last frame.
    func update(creatureWorldX: CGFloat,
                creatureY: CGFloat,
                creatureFacing: Direction,
                deltaTime: TimeInterval) {

        guard isEnabled else { return }

        accumulatedTime += deltaTime

        // Track creature position history
        positionHistory.append((x: creatureWorldX, y: creatureY,
                                time: accumulatedTime))

        // Trim old entries (keep last 2 seconds)
        let cutoff = accumulatedTime - 2.0
        positionHistory.removeAll { $0.time < cutoff }

        if isAppearing {
            // Update appearance timer
            appearanceTimer -= deltaTime

            if appearanceTimer <= 0 {
                // Begin fade out
                fadeOutGhost()
                return
            }

            // Position ghost using delayed position
            let targetTime = accumulatedTime - Self.positionDelay
            let delayedPos = interpolatedPosition(at: targetTime)

            // Trail behind the creature
            let trailOffset = creatureFacing == .right
                ? -Self.trailingDistance
                : Self.trailingDistance

            ghostNode.position = CGPoint(
                x: delayedPos.x + trailOffset,
                y: delayedPos.y
            )

            // Match creature facing
            ghostNode.xScale = abs(ghostNode.xScale)
                * creatureFacing.xScale

            // Ghost's own breathing — desynced at 3.0s period
            let ghostBreath = 1.0 + 0.02
                * CGFloat(sin(2.0 * .pi * accumulatedTime / 3.0))
            ghostBody.yScale = ghostBreath

        } else {
            // Cooldown phase
            cooldownTimer -= deltaTime
            if cooldownTimer <= 0 {
                beginAppearance()
            }
        }
    }

    // MARK: - Appearance Lifecycle

    private func beginAppearance() {
        guard isEnabled else { return }

        // For Apex, pick a random past stage each appearance
        if currentCreatureStage == .apex {
            let pastStages: [GrowthStage] = [.spore, .drop, .critter, .beast, .sage]
            ghostStage = pastStages.randomElement() ?? .critter
            rebuildGhostShape()
        }

        isAppearing = true
        appearanceTimer = Self.appearanceDuration

        // Fade in
        ghostNode.removeAllActions()
        ghostNode.run(
            SKAction.fadeAlpha(to: Self.ghostAlpha, duration: Self.fadeDuration),
            withKey: "ghostFadeIn"
        )

        NSLog("[Pushling/GhostEcho] Ghost of %@ appearing for %.0fs",
              "\(ghostStage)", Self.appearanceDuration)
    }

    private func fadeOutGhost() {
        ghostNode.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0, duration: Self.fadeDuration),
            SKAction.run { [weak self] in
                self?.isAppearing = false
                self?.cooldownTimer = TimeInterval.random(
                    in: Self.cooldownRange
                )
            }
        ]), withKey: "ghostFadeOut")
    }

    // MARK: - Position Interpolation

    /// Get the interpolated creature position at a past time.
    private func interpolatedPosition(at targetTime: TimeInterval) -> CGPoint {
        guard positionHistory.count >= 2 else {
            if let last = positionHistory.last {
                return CGPoint(x: last.x, y: last.y)
            }
            return .zero
        }

        // Find the two entries bracketing the target time
        for i in 0..<(positionHistory.count - 1) {
            let a = positionHistory[i]
            let b = positionHistory[i + 1]
            if a.time <= targetTime && b.time >= targetTime {
                let t = (targetTime - a.time) / max(0.001, b.time - a.time)
                let x = a.x + (b.x - a.x) * CGFloat(t)
                let y = a.y + (b.y - a.y) * CGFloat(t)
                return CGPoint(x: x, y: y)
            }
        }

        // If target time is before our history, use oldest entry
        if let first = positionHistory.first, targetTime < first.time {
            return CGPoint(x: first.x, y: first.y)
        }

        // If target time is after our history, use newest entry
        if let last = positionHistory.last {
            return CGPoint(x: last.x, y: last.y)
        }

        return .zero
    }

    // MARK: - Node Count

    /// Nodes contributed to the scene.
    var nodeCount: Int {
        return isAppearing ? 2 : 0  // ghostNode + ghostBody
    }
}
