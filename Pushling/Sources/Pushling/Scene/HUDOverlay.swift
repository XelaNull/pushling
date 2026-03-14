// HUDOverlay.swift — Cinematic HUD with tap-to-show stats
// P3-T3-06: Default = no UI. Tap anywhere shows minimal overlay for 3s.
//
// Stats overlay: hearts, stage, XP, streak — 120pt wide, bottom-left.
// Fade in 0.2s, hold 3s, fade out 0.5s.
// Touch ripple: tiny circle at tap point, expands and fades.
//
// Node budget: ~8 nodes (overlay container + 4 labels + progress bar + 2 ripple pool).
// Nodes are always in the tree but hidden when inactive (no add/remove overhead).

import SpriteKit

// MARK: - HUD State

/// Tracks the creature stats displayed in the HUD.
struct HUDState {
    var satisfaction: Double = 50.0     // 0-100 (hearts)
    var stageName: String = "critter"
    var currentXP: Int = 0
    var xpToNext: Int = 100
    var streakDays: Int = 0
    var stageColor: SKColor = PushlingPalette.moss
}

// MARK: - HUD Overlay Controller

/// Manages the cinematic HUD overlay for the Touch Bar.
/// Default: invisible. Tap triggers 3-second stats display.
/// Owns the touch ripple pool.
final class HUDOverlay {

    // MARK: - Constants

    /// Overlay dimensions.
    private static let overlayWidth: CGFloat = 120.0
    private static let overlayHeight: CGFloat = 18.0

    /// Overlay position (bottom-left of scene).
    private static let overlayX: CGFloat = 4.0
    private static let overlayY: CGFloat = 2.0

    /// Timing.
    private static let fadeInDuration: TimeInterval = 0.2
    private static let holdDuration: TimeInterval = 3.0
    private static let fadeOutDuration: TimeInterval = 0.5

    /// Font.
    private static let fontName = "Menlo"
    private static let fontSize: CGFloat = 6.0

    /// Touch ripple.
    private static let ripplePoolSize = 3
    private static let rippleStartRadius: CGFloat = 2.0
    private static let rippleEndRadius: CGFloat = 6.0
    private static let rippleDuration: TimeInterval = 0.2

    // MARK: - Nodes

    /// Root container for the entire HUD (added to scene root, not parallax layers).
    let rootNode: SKNode

    /// Stats overlay container (the tap-to-show panel).
    private let overlayContainer: SKNode

    /// Background for the overlay (subtle darkening).
    private let overlayBackground: SKShapeNode

    /// Label nodes for stats display.
    private let heartsLabel: SKLabelNode
    private let stageLabel: SKLabelNode
    private let xpLabel: SKLabelNode
    private let streakLabel: SKLabelNode

    /// Touch ripple pool (recycled circle nodes).
    private var ripplePool: [SKShapeNode] = []
    private var nextRippleIndex = 0

    // MARK: - State

    /// Whether the overlay is currently visible.
    private(set) var isOverlayVisible = false

    /// Timer key for auto-hide.
    private let hideActionKey = "hudAutoHide"

    /// Current HUD state.
    private(set) var currentState = HUDState()

    // MARK: - Init

    init() {
        rootNode = SKNode()
        rootNode.name = "hud_root"
        rootNode.zPosition = 500  // Above everything except debug

        // --- Overlay Container ---
        overlayContainer = SKNode()
        overlayContainer.name = "hud_overlay"
        overlayContainer.position = CGPoint(x: Self.overlayX, y: Self.overlayY)
        overlayContainer.alpha = 0
        rootNode.addChild(overlayContainer)

        // Background — very subtle dark backing for readability
        overlayBackground = SKShapeNode(
            rectOf: CGSize(width: Self.overlayWidth, height: Self.overlayHeight),
            cornerRadius: 2
        )
        overlayBackground.fillColor = PushlingPalette.withAlpha(
            PushlingPalette.void_, alpha: 0.4
        )
        overlayBackground.strokeColor = .clear
        overlayBackground.position = CGPoint(
            x: Self.overlayWidth / 2,
            y: Self.overlayHeight / 2
        )
        overlayContainer.addChild(overlayBackground)

        // Hearts label (satisfaction)
        heartsLabel = Self.makeLabel(y: Self.overlayHeight - 4)
        overlayContainer.addChild(heartsLabel)

        // Stage label
        stageLabel = Self.makeLabel(y: Self.overlayHeight - 10)
        overlayContainer.addChild(stageLabel)

        // XP label
        xpLabel = Self.makeLabel(y: Self.overlayHeight - 16)
        overlayContainer.addChild(xpLabel)

        // Streak label
        streakLabel = Self.makeLabel(y: 2)
        streakLabel.position.x = Self.overlayWidth - 4
        streakLabel.horizontalAlignmentMode = .right
        overlayContainer.addChild(streakLabel)

        // --- Touch Ripple Pool ---
        for i in 0..<Self.ripplePoolSize {
            let ripple = SKShapeNode(circleOfRadius: Self.rippleStartRadius)
            ripple.strokeColor = PushlingPalette.withAlpha(PushlingPalette.bone,
                                                            alpha: 0.3)
            ripple.fillColor = .clear
            ripple.lineWidth = 0.5
            ripple.alpha = 0
            ripple.name = "hud_ripple_\(i)"
            ripple.zPosition = 490
            rootNode.addChild(ripple)
            ripplePool.append(ripple)
        }
    }

    // MARK: - Scene Integration

    /// Add the HUD to the scene. Call once during setup.
    func addToScene(_ scene: SKScene) {
        scene.addChild(rootNode)
    }

    // MARK: - State Updates

    /// Update the HUD with new creature state.
    func updateState(_ state: HUDState) {
        currentState = state
        refreshLabels()
    }

    /// Update satisfaction only (lightweight, for hunger system).
    func updateSatisfaction(_ satisfaction: Double) {
        currentState.satisfaction = satisfaction
        if isOverlayVisible {
            refreshLabels()
        }
    }

    // MARK: - Tap to Show

    /// Handle a tap on empty space — shows the overlay for 3 seconds.
    /// - Parameter scenePosition: The tap position in scene coordinates.
    func handleTap(at scenePosition: CGPoint) {
        // Trigger touch ripple
        spawnRipple(at: scenePosition)

        // Show overlay
        showOverlay()
    }

    /// Show the stats overlay with fade-in, auto-hide after 3s.
    func showOverlay() {
        isOverlayVisible = true
        refreshLabels()

        overlayContainer.removeAction(forKey: hideActionKey)
        overlayContainer.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: Self.fadeInDuration),
            SKAction.wait(forDuration: Self.holdDuration),
            SKAction.fadeAlpha(to: 0, duration: Self.fadeOutDuration),
            SKAction.run { [weak self] in
                self?.isOverlayVisible = false
            }
        ]), withKey: hideActionKey)
    }

    /// Immediately hide the overlay (e.g., during evolution ceremony).
    func hideOverlay() {
        isOverlayVisible = false
        overlayContainer.removeAction(forKey: hideActionKey)
        overlayContainer.alpha = 0
    }

    // MARK: - Touch Ripple

    /// Spawn a ripple effect at the given scene position.
    private func spawnRipple(at position: CGPoint) {
        let ripple = ripplePool[nextRippleIndex]
        nextRippleIndex = (nextRippleIndex + 1) % Self.ripplePoolSize

        ripple.position = position
        ripple.setScale(1.0)
        ripple.alpha = 0.3

        ripple.removeAllActions()
        ripple.run(SKAction.group([
            SKAction.scale(to: Self.rippleEndRadius / Self.rippleStartRadius,
                          duration: Self.rippleDuration),
            SKAction.fadeAlpha(to: 0, duration: Self.rippleDuration)
        ]))
    }

    // MARK: - Label Refresh

    private func refreshLabels() {
        let state = currentState

        // Hearts — satisfaction as hearts (each heart = 20 satisfaction)
        let fullHearts = Int(state.satisfaction / 20.0)
        let heartStr = String(repeating: "\u{2665}", count: fullHearts)
            + String(repeating: "\u{2661}", count: 5 - fullHearts)
        heartsLabel.text = heartStr
        heartsLabel.fontColor = PushlingPalette.withAlpha(PushlingPalette.ember,
                                                           alpha: 0.7)

        // Stage
        stageLabel.text = state.stageName.uppercased()
        stageLabel.fontColor = PushlingPalette.withAlpha(state.stageColor,
                                                          alpha: 0.7)

        // XP
        xpLabel.text = "XP \(state.currentXP)/\(state.xpToNext)"
        xpLabel.fontColor = PushlingPalette.withAlpha(PushlingPalette.tide,
                                                       alpha: 0.7)

        // Streak
        if state.streakDays > 0 {
            streakLabel.text = "\(state.streakDays)d"
            streakLabel.fontColor = PushlingPalette.withAlpha(PushlingPalette.gilt,
                                                               alpha: 0.7)
        } else {
            streakLabel.text = ""
        }
    }

    // MARK: - Factory

    private static func makeLabel(y: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: fontName)
        label.fontSize = fontSize
        label.fontColor = PushlingPalette.withAlpha(PushlingPalette.ash,
                                                     alpha: 0.7)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 4, y: y)
        return label
    }

    // MARK: - Node Count

    /// Nodes contributed to scene budget.
    /// Always present (hidden nodes are cheap), but count only visible ones.
    var nodeCount: Int {
        // rootNode + overlayContainer + background + 4 labels + 3 ripple = 10
        return 10
    }
}
