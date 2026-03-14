// UnlockCeremony.swift — Visual notification + demo when milestone unlocked
// 3-second ceremony: flash (0.3s), banner (2.0s), demo (1.5s overlapping),
// dismiss (0.7s). Non-blocking — creature continues; if human performs the
// newly unlocked gesture during ceremony, extra celebration particles.

import SpriteKit

// MARK: - Unlock Ceremony

/// Plays a brief visual ceremony when a human milestone is achieved.
/// The banner slides in from the right, shows the milestone name with
/// an icon, the creature demos the gesture, and it fades out.
final class UnlockCeremony {

    // MARK: - Constants

    private static let flashDuration: TimeInterval = 0.3
    private static let bannerDuration: TimeInterval = 2.0
    private static let demoDuration: TimeInterval = 1.5
    private static let dismissDuration: TimeInterval = 0.7
    private static let bannerHeight: CGFloat = 14.0
    private static let bannerY: CGFloat = 8.0

    // MARK: - State

    /// Whether a ceremony is currently playing.
    private(set) var isPlaying = false

    /// The milestone being celebrated.
    private(set) var currentMilestone: MilestoneID?

    /// Banner node.
    private var bannerNode: SKNode?

    /// Flash overlay node.
    private var flashNode: SKShapeNode?

    /// Callback when ceremony completes.
    var onCeremonyComplete: ((MilestoneID) -> Void)?

    /// Callback to request creature demo of the unlocked gesture.
    var onDemoRequest: ((MilestoneID) -> Void)?

    // MARK: - Play

    /// Plays the unlock ceremony for the given milestone.
    func play(milestone: MilestoneID, in scene: SKScene) {
        guard !isPlaying else { return }
        isPlaying = true
        currentMilestone = milestone

        NSLog("[Pushling/Ceremony] Playing unlock: %@", milestone.rawValue)

        // 1. Screen flash
        playFlash(in: scene)

        // 2. Banner (after flash)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.flashDuration
        ) { [weak self] in
            self?.playBanner(milestone: milestone, in: scene)
        }

        // 3. Demo (overlapping with banner)
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.flashDuration + 0.5
        ) { [weak self] in
            self?.onDemoRequest?(milestone)
        }

        // 4. Dismiss
        let totalDuration = Self.flashDuration + Self.bannerDuration
        DispatchQueue.main.asyncAfter(
            deadline: .now() + totalDuration
        ) { [weak self] in
            self?.dismiss(milestone: milestone)
        }
    }

    // MARK: - Flash

    private func playFlash(in scene: SKScene) {
        let flash = SKShapeNode(
            rectOf: CGSize(width: SceneConstants.sceneWidth,
                           height: SceneConstants.sceneHeight)
        )
        flash.fillColor = SKColor.white.withAlphaComponent(0.2)
        flash.strokeColor = .clear
        flash.position = CGPoint(
            x: SceneConstants.sceneWidth / 2,
            y: SceneConstants.sceneHeight / 2
        )
        flash.zPosition = 200
        flash.name = "unlock_flash"
        scene.addChild(flash)
        flashNode = flash

        // Screen shake (0.5pt)
        let shakeSequence = SKAction.sequence([
            SKAction.moveBy(x: 0.5, y: 0, duration: 0.03),
            SKAction.moveBy(x: -1.0, y: 0, duration: 0.03),
            SKAction.moveBy(x: 0.5, y: 0, duration: 0.03)
        ])
        scene.run(shakeSequence)

        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: Self.flashDuration),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Banner

    private func playBanner(milestone: MilestoneID, in scene: SKScene) {
        let container = SKNode()
        container.name = "unlock_banner"
        container.zPosition = 210
        container.position = CGPoint(
            x: SceneConstants.sceneWidth + 100,  // Start offscreen right
            y: Self.bannerY
        )

        // Background
        let bg = SKShapeNode(
            rectOf: CGSize(width: 180, height: Self.bannerHeight),
            cornerRadius: 3
        )
        bg.fillColor = PushlingPalette.gilt.withAlphaComponent(0.85)
        bg.strokeColor = .clear
        container.addChild(bg)

        // Text
        let text = SKLabelNode(fontNamed: "Menlo-Bold")
        text.fontSize = 6
        text.fontColor = SKColor.black
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        text.text = displayName(for: milestone)
        container.addChild(text)

        scene.addChild(container)
        bannerNode = container

        // Slide in
        let slideIn = SKAction.moveTo(
            x: SceneConstants.sceneWidth / 2,
            duration: 0.3
        )
        slideIn.timingMode = .easeOut
        container.run(slideIn)
    }

    // MARK: - Dismiss

    private func dismiss(milestone: MilestoneID) {
        let fadeOut = SKAction.fadeOut(withDuration: Self.dismissDuration)
        let remove = SKAction.removeFromParent()

        bannerNode?.run(SKAction.sequence([fadeOut, remove])) { [weak self] in
            self?.isPlaying = false
            self?.currentMilestone = nil
            self?.bannerNode = nil
            self?.onCeremonyComplete?(milestone)
        }
    }

    // MARK: - Extra Celebration

    /// Call this if the human performs the newly unlocked gesture
    /// during the ceremony — extra sparkle.
    func extraCelebration(in scene: SKScene) {
        guard isPlaying else { return }

        let center = CGPoint(
            x: SceneConstants.sceneWidth / 2,
            y: SceneConstants.sceneHeight / 2
        )

        for _ in 0..<15 {
            let spark = SKShapeNode(circleOfRadius: 1.0)
            spark.fillColor = PushlingPalette.gilt
            spark.strokeColor = .clear
            spark.position = center
            spark.zPosition = 220
            scene.addChild(spark)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 8...20)
            let move = SKAction.moveBy(
                x: cos(angle) * dist,
                y: sin(angle) * dist,
                duration: 0.5
            )
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.4)
            spark.run(SKAction.sequence([
                SKAction.group([move, fade]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Display Names

    private func displayName(for milestone: MilestoneID) -> String {
        switch milestone {
        case .firstTouch:      return "WELCOME! TAP, DOUBLE-TAP, HOLD"
        case .fingerTrail:     return "FINGER TRAIL UNLOCKED"
        case .petting:         return "PETTING UNLOCKED"
        case .laserPointer:    return "LASER POINTER UNLOCKED"
        case .firstMiniGame:   return "TOYBOX UNLOCKED"
        case .bellyRub:        return "BELLY RUB UNLOCKED"
        case .preContactPurr:  return "PRE-CONTACT PURR UNLOCKED"
        case .touchMastery:    return "TOUCH MASTERY UNLOCKED"
        case .gentleWake:      return "GENTLE WAKE"
        }
    }

    // MARK: - Mark Ceremony Played

    /// Marks the ceremony as played in SQLite.
    func markPlayed(milestone: MilestoneID, db: DatabaseManager?) {
        db?.performWriteAsync({
            try db?.execute(
                "UPDATE milestones SET ceremony_played = 1 WHERE id = ?;",
                arguments: [milestone.rawValue]
            )
        })
    }
}
