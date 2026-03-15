// CommitEatingAnimation.swift — 4-phase character-by-character eating animation
//
// Phase 1 — Arrival (2s): Text materializes, drifts toward creature
// Phase 2 — Notice (1.5s): Predator crouch, butt wiggle, eyes track
// Phase 3 — Feast (3-6s): Character-by-character eating with crumbs
// Phase 4 — Reaction (2-3s): Swallow, XP float, type-specific response
//
// CommitTextNode lives in CommitTextNode.swift (extracted for file size).
// Crumb particles use a single recycled SKEmitterNode.

import SpriteKit

// MARK: - Eating Phase

/// The 4 phases of the commit eating animation.
enum EatingPhase {
    case idle           // Not eating
    case arrival        // Text materializing and drifting
    case notice         // Predator crouch, butt wiggle
    case feast          // Character-by-character eating
    case reaction       // Post-eat response
    case complete       // Done
}

// MARK: - Commit Eating Animation

/// Manages the full 4-phase commit eating animation sequence.
final class CommitEatingAnimation {

    // MARK: - State

    private(set) var phase: EatingPhase = .idle
    private var phaseTimer: TimeInterval = 0
    private var totalTimer: TimeInterval = 0

    /// The commit being eaten.
    private var commitType: CommitType = .normal
    private var commitData: CommitData?
    private var xpResult: XPResult?

    // MARK: - Text Nodes

    /// The commit text container.
    private var textNode: CommitTextNode?

    /// Index of the next character to eat.
    private var eatIndex: Int = 0

    /// Time accumulator for character-by-character timing.
    private var eatTimer: TimeInterval = 0

    /// Milliseconds per character for current commit.
    private var msPerChar: Int = 150

    /// Characters eaten counter (for swallow every 5th).
    private var charsEatenSinceSwallow: Int = 0

    // MARK: - Dependencies

    private weak var creature: CreatureNode?
    private weak var scene: SKScene?

    /// Crumb particle emitter (recycled, not recreated).
    private var crumbEmitter: SKEmitterNode?

    /// XP float label.
    private var xpLabel: SKLabelNode?

    // MARK: - Callbacks

    /// Called when the eating animation completes.
    var onComplete: ((_ commitType: CommitType, _ xpResult: XPResult?) -> Void)?

    /// Called when a speech reaction should be triggered.
    var onSpeechReaction: ((_ reaction: String) -> Void)?

    // MARK: - Initialization

    init() {}

    /// Configure with scene dependencies.
    func configure(creature: CreatureNode, scene: SKScene) {
        self.creature = creature
        self.scene = scene

        // Create reusable crumb emitter
        let emitter = SKEmitterNode()
        emitter.particleLifetime = 0.3
        emitter.particleLifetimeRange = 0.1
        emitter.particleBirthRate = 0  // Controlled manually
        emitter.particleSpeed = 30
        emitter.particleSpeedRange = 10
        emitter.emissionAngleRange = .pi / 2  // 90-degree spread upward
        emitter.emissionAngle = .pi / 2       // Upward
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleAlphaSpeed = -3.0
        emitter.particleColorSequence = nil
        emitter.particleColor = PushlingPalette.tide
        emitter.particleColorBlendFactor = 1.0
        emitter.name = "crumbEmitter"
        emitter.zPosition = 36
        emitter.targetNode = scene
        crumbEmitter = emitter
    }

    // MARK: - Start Eating

    /// Begin the 4-phase eating animation for a commit.
    func start(commit: CommitData,
               commitType: CommitType,
               xpResult: XPResult?) {
        guard phase == .idle || phase == .complete else {
            NSLog("[Pushling/Eating] Cannot start — already eating")
            return
        }

        self.commitData = commit
        self.commitType = commitType
        self.xpResult = xpResult
        self.phase = .arrival
        self.phaseTimer = 0
        self.totalTimer = 0
        self.eatIndex = 0
        self.eatTimer = 0
        self.charsEatenSinceSwallow = 0

        // Calculate eating speed
        if commitType.msPerCharacter > 0 {
            msPerChar = commitType.msPerCharacter
        } else {
            msPerChar = CommitTypeDetector.eatingSpeed(
                totalLines: commit.totalLines
            )
        }

        // Create text node
        let textNode = CommitTextNode()
        textNode.configure(message: commit.message, sha: commit.sha)

        // Spawn at edge of bar (further from creature)
        guard let creature = creature, let scene = scene else { return }
        let creatureX = creature.position.x
        // Spawn text 120pt away from creature (not at edge of bar)
        // so it arrives within the 2s arrival phase
        let spawnX: CGFloat
        if Bool.random() {
            spawnX = creatureX + 120  // From the right
        } else {
            spawnX = creatureX - 120  // From the left
        }
        textNode.position = CGPoint(
            x: spawnX,
            y: creature.position.y + 5
        )

        scene.addChild(textNode)
        self.textNode = textNode

        NSLog("[Pushling/Eating] Start: '%@' type=%@ speed=%dms/char",
              String(commit.message.prefix(20)),
              commitType.rawValue, msPerChar)
    }

    // MARK: - Per-Frame Update

    /// Update the eating animation. Called every frame.
    func update(deltaTime: TimeInterval) {
        guard phase != .idle && phase != .complete else { return }

        phaseTimer += deltaTime
        totalTimer += deltaTime

        switch phase {
        case .arrival:
            updateArrival(deltaTime: deltaTime)
        case .notice:
            updateNotice(deltaTime: deltaTime)
        case .feast:
            updateFeast(deltaTime: deltaTime)
        case .reaction:
            updateReaction(deltaTime: deltaTime)
        default:
            break
        }
    }

    // MARK: - Phase 1: Arrival (2s)

    private func updateArrival(deltaTime: TimeInterval) {
        guard let textNode = textNode, let creature = creature else { return }

        // Stagger character appearance (60ms between each)
        for (i, charNode) in textNode.charNodes.enumerated() {
            let staggerTime = Double(i) * 0.06
            if phaseTimer >= staggerTime && charNode.alpha < 1.0 {
                let fadeProgress = min(1.0,
                    (phaseTimer - staggerTime) / 0.12
                )
                charNode.alpha = CGFloat(fadeProgress)
            }
        }

        // Bob animation
        for (i, charNode) in textNode.charNodes.enumerated() {
            let bobOffset = sin(totalTimer * 2.0 + Double(i) * 0.4) * 1.5
            charNode.position.y = CGFloat(bobOffset)
        }

        // Drift toward creature
        let creatureX = creature.position.x
        let textX = textNode.position.x
        let direction: CGFloat = textX > creatureX ? -1 : 1
        let driftSpeed: CGFloat = commitType == .forcePush ? 200 : 80
        textNode.position.x += direction * driftSpeed * CGFloat(deltaTime)

        // Transition to Notice when within 60pt
        let distance = abs(textNode.position.x - creatureX)
        if distance < 60 || phaseTimer >= 2.0 {
            phase = .notice
            phaseTimer = 0
        }
    }

    // MARK: - Phase 2: Notice (1.5s)

    private func updateNotice(deltaTime: TimeInterval) {
        guard let creature = creature, let textNode = textNode else { return }

        // Continue bob animation on text
        for (i, charNode) in textNode.charNodes.enumerated() {
            let bobOffset = sin(totalTimer * 2.0 + Double(i) * 0.4) * 1.5
            charNode.position.y = CGFloat(bobOffset)
        }

        // Continue drift
        let creatureX = creature.position.x
        let textX = textNode.position.x
        let direction: CGFloat = textX > creatureX ? -1 : 1
        textNode.position.x += direction * 10 * CGFloat(deltaTime)

        // Creature reactions
        if phaseTimer < 0.15 {
            // Ear perk
            creature.earLeftController?.setState("alert", duration: 0.15)
            creature.earRightController?.setState("alert", duration: 0.15)
        }
        if phaseTimer >= 0.1 && phaseTimer < 0.3 {
            // Eyes widen
            creature.eyeLeftController?.setState("wide", duration: 0.15)
            creature.eyeRightController?.setState("wide", duration: 0.15)
        }
        if phaseTimer >= 0.3 && phaseTimer < 0.7 {
            // Predator crouch (skip for Spore/Drop)
            if creature.currentStage >= .critter {
                // Body Y-scale compress simulated via position
            }
        }
        if phaseTimer >= 0.7 && phaseTimer < 1.2 {
            // Butt wiggle for Beast+
            if creature.currentStage >= .critter {
                let wigglePhase = (phaseTimer - 0.7) * 6 * .pi
                let wiggleOffset = sin(wigglePhase) * 1.5
                creature.tailController?.setState(
                    wiggleOffset > 0 ? "left" : "right", duration: 0
                )
            }
        }

        if phaseTimer >= 1.5 {
            // Reset tail
            creature.tailController?.setState("sway", duration: 0.2)
            phase = .feast
            phaseTimer = 0
        }
    }

    // MARK: - Phase 3: Feast (3-6s)

    private func updateFeast(deltaTime: TimeInterval) {
        guard let creature = creature, let textNode = textNode else { return }

        eatTimer += deltaTime

        // Milliseconds to seconds
        let eatInterval = Double(msPerChar) / 1000.0

        // Check if it's time to eat the next character
        if eatTimer >= eatInterval && eatIndex < textNode.charNodes.count {
            eatCharacter(at: eatIndex)
            eatIndex += 1
            eatTimer = 0
            charsEatenSinceSwallow += 1

            // Chewing animation: jaw bobs (120ms total, 2 bobs)
            creature.mouthController?.setState("open_small", duration: 0)
            let closeDelay = SKAction.wait(forDuration: 0.06)
            let close = SKAction.run { [weak creature] in
                creature?.mouthController?.setState("closed", duration: 0)
            }
            let openDelay = SKAction.wait(forDuration: 0.06)
            let reopen = SKAction.run { [weak creature] in
                creature?.mouthController?.setState("open_small", duration: 0)
            }
            creature.run(
                SKAction.sequence([closeDelay, close, openDelay, reopen]),
                withKey: "chewing"
            )

            // Swallow every 5th character
            if charsEatenSinceSwallow >= 5 {
                charsEatenSinceSwallow = 0
                // Throat bob: slight Y dip
                let dip = SKAction.moveBy(x: 0, y: -0.5, duration: 0.075)
                let rise = SKAction.moveBy(x: 0, y: 0.5, duration: 0.075)
                creature.run(
                    SKAction.sequence([dip, rise]),
                    withKey: "swallow"
                )
            }
        }

        // Check if all characters eaten
        if eatIndex >= textNode.charNodes.count {
            creature.mouthController?.setState("closed", duration: 0.1)
            phase = .reaction
            phaseTimer = 0
        }
    }

    /// Animate eating a single character.
    private func eatCharacter(at index: Int) {
        guard let textNode = textNode,
              index < textNode.charNodes.count else { return }

        let charNode = textNode.charNodes[index]

        // Character shrinks, flashes white, emits crumbs, disappears
        let shrink = SKAction.scale(to: 0.5, duration: 0.08)
        let flashWhite = SKAction.run { [weak charNode] in
            charNode?.fontColor = PushlingPalette.bone
        }
        let disappear = SKAction.fadeOut(withDuration: 0.04)
        let hide = SKAction.run { [weak charNode] in
            charNode?.isHidden = true
        }

        charNode.run(
            SKAction.sequence([shrink, flashWhite, disappear, hide])
        )

        // Emit crumb particles
        emitCrumbs(at: charNode.convert(.zero, to: scene!))
    }

    /// Emit crumb particles from the eating position.
    private func emitCrumbs(at position: CGPoint) {
        guard let emitter = crumbEmitter, let scene = scene else { return }

        emitter.position = position

        if emitter.parent == nil {
            scene.addChild(emitter)
        }

        // Burst of 3-5 particles (10-15 in goblin mode)
        let count = commitType == .hugeRefactor
            || commitType == .largeRefactor ? 12 : 4
        emitter.particleBirthRate = CGFloat(count) / 0.1  // Over 0.1s
        emitter.numParticlesToEmit = count

        // Reset emitter to fire again
        emitter.resetSimulation()

        // Color based on commit type
        switch commitType {
        case .css:  emitter.particleColor = PushlingPalette.gilt
        case .docs: emitter.particleColor = PushlingPalette.moss
        case .php:  emitter.particleColor = PushlingPalette.ember
        default:    emitter.particleColor = PushlingPalette.tide
        }
    }

    // MARK: - Phase 4: Reaction (2-3s)

    private func updateReaction(deltaTime: TimeInterval) {
        guard let creature = creature, let scene = scene else { return }

        if phaseTimer < 0.2 {
            // Final swallow gulp
            if phaseTimer == 0 || (phaseTimer > 0 && phaseTimer - deltaTime <= 0) {
                let dip = SKAction.moveBy(x: 0, y: -1, duration: 0.1)
                let rise = SKAction.moveBy(x: 0, y: 1, duration: 0.1)
                creature.run(SKAction.sequence([dip, rise]),
                             withKey: "finalSwallow")
            }
        }

        if phaseTimer >= 0.2 && phaseTimer - deltaTime < 0.2 {
            // Show XP float
            showXPFloat(scene: scene)

            // Reset eyes
            creature.eyeLeftController?.setState("open", duration: 0.2)
            creature.eyeRightController?.setState("open", duration: 0.2)
            creature.earLeftController?.setState("neutral", duration: 0.3)
            creature.earRightController?.setState("neutral", duration: 0.3)
        }

        if phaseTimer >= 0.5 && phaseTimer - deltaTime < 0.5 {
            // Trigger speech reaction
            let reaction: String
            if creature.currentStage >= .beast {
                reaction = commitType.speechReaction
            } else if creature.currentStage == .critter {
                reaction = commitType.critterReaction
            } else {
                // Drop: handled via symbol
                reaction = DropSymbolSet.symbolForEmotion(
                    commitType.dropSymbolEmotion
                ).glyph
            }
            onSpeechReaction?(reaction)
        }

        // Update XP float
        if let xpLabel = xpLabel {
            xpLabel.position.y += CGFloat(deltaTime) * 8  // Rise
            xpLabel.alpha -= CGFloat(deltaTime) / 1.5     // Fade
            if xpLabel.alpha <= 0 {
                xpLabel.removeFromParent()
                self.xpLabel = nil
            }
        }

        if phaseTimer >= 2.5 {
            // Clean up
            textNode?.resetAll()
            textNode?.removeFromParent()
            textNode = nil
            crumbEmitter?.removeFromParent()

            phase = .complete
            onComplete?(commitType, xpResult)

            NSLog("[Pushling/Eating] Complete: type=%@ xp=%d",
                  commitType.rawValue, xpResult?.xp ?? 0)
        }
    }

    // MARK: - XP Float

    private func showXPFloat(scene: SKScene) {
        guard let xpResult = xpResult, let creature = creature else { return }

        let label = SKLabelNode(fontNamed: "SFProText-Bold")
        label.fontSize = 7
        label.fontColor = PushlingPalette.gilt
        label.text = xpResult.displayString
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(
            x: creature.position.x,
            y: creature.position.y
                + (StageConfiguration.all[creature.currentStage]?.size.height
                   ?? 16) / 2 + 6
        )
        label.zPosition = 38
        label.alpha = 1.0

        scene.addChild(label)
        self.xpLabel = label
    }

    // MARK: - Status

    /// Whether an eating animation is currently active.
    var isEating: Bool {
        phase != .idle && phase != .complete
    }

    /// Reset to idle state (for cleanup).
    func reset() {
        textNode?.resetAll()
        textNode?.removeFromParent()
        textNode = nil
        crumbEmitter?.removeFromParent()
        xpLabel?.removeFromParent()
        xpLabel = nil
        phase = .idle
        phaseTimer = 0
        totalTimer = 0
    }
}
