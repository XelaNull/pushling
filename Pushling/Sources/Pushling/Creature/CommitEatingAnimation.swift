// CommitEatingAnimation.swift — 4-phase character-by-character eating animation
//
// Phase 1 — Arrival (3s): Text materializes at bar edge, floats to creature
// Phase 2 — Notice (1s): Creature perks ears, crouches
// Phase 3 — Feast: Character-by-character eating from creature's side, with shake
// Phase 4 — Reaction (2.5s): Swallow, XP float, speech reaction

import SpriteKit

// MARK: - Eating Phase

enum EatingPhase {
    case idle
    case arrival        // Text floating toward creature
    case notice         // Creature reacts
    case feast          // Eating characters one by one
    case reaction       // Post-eat response
    case complete
}

// MARK: - Commit Eating Animation

final class CommitEatingAnimation {

    // MARK: - State

    private(set) var phase: EatingPhase = .idle
    private var phaseTimer: TimeInterval = 0
    private var totalTimer: TimeInterval = 0

    private var commitType: CommitType = .normal
    private var commitData: CommitData?
    private var xpResult: XPResult?

    // MARK: - Text Nodes

    private var textNode: CommitTextNode?
    private var eatIndex: Int = 0
    private var eatTimer: TimeInterval = 0
    private var msPerChar: Int = 300   // Default: 300ms per character (visible eating)
    private var charsEatenSinceSwallow: Int = 0
    private var eatingFromLeft: Bool = true  // Which side to eat from

    // MARK: - Dependencies

    private weak var creature: CreatureNode?
    private weak var scene: SKScene?
    private var crumbEmitter: SKEmitterNode?
    private var xpLabel: SKLabelNode?

    // MARK: - Callbacks

    var onComplete: ((_ commitType: CommitType, _ xpResult: XPResult?) -> Void)?
    var onSpeechReaction: ((_ reaction: String) -> Void)?

    // MARK: - Init

    init() {}

    func configure(creature: CreatureNode, scene: SKScene) {
        self.creature = creature
        self.scene = scene

        let emitter = SKEmitterNode()
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.15
        emitter.particleBirthRate = 0
        emitter.particleSpeed = 25
        emitter.particleSpeedRange = 10
        emitter.emissionAngleRange = .pi / 2
        emitter.emissionAngle = .pi / 2
        emitter.particleScale = 0.4
        emitter.particleScaleRange = 0.2
        emitter.particleAlphaSpeed = -2.5
        emitter.particleColorSequence = nil
        emitter.particleColor = PushlingPalette.tide
        emitter.particleColorBlendFactor = 1.0
        emitter.name = "crumbEmitter"
        emitter.zPosition = 36
        emitter.targetNode = scene
        crumbEmitter = emitter
    }

    // MARK: - Start

    func start(commit: CommitData, commitType: CommitType, xpResult: XPResult?) {
        guard phase == .idle || phase == .complete else { return }

        self.commitData = commit
        self.commitType = commitType
        self.xpResult = xpResult
        self.phase = .arrival
        self.phaseTimer = 0
        self.totalTimer = 0
        self.eatIndex = 0
        self.eatTimer = 0
        self.charsEatenSinceSwallow = 0

        // Eating speed — slower so each char is visible
        switch commitType {
        case .largeRefactor, .hugeRefactor:
            msPerChar = 160   // Goblin mode — fast but readable
        case .test:
            msPerChar = 400   // Crunchy
        case .lazyMessage:
            msPerChar = 600   // Reluctant chewing
        default:
            // Scale with commit size: small=550ms, medium=400ms, large=250ms
            let lines = commit.totalLines
            if lines < 20 {
                msPerChar = 550
            } else if lines < 100 {
                msPerChar = 400
            } else {
                msPerChar = 250
            }
        }

        // Create text node — larger font for bigger commits
        let textNode = CommitTextNode()
        let fontSize: CGFloat
        switch commitType {
        case .hugeRefactor:
            fontSize = 18
        case .largeRefactor:
            fontSize = 16
        default:
            let lines = commit.totalLines
            if lines >= 100 {
                fontSize = 15
            } else if lines >= 20 {
                fontSize = 14
            } else {
                fontSize = 12
            }
        }
        textNode.configure(message: commit.message, sha: commit.sha, fontSize: fontSize)

        guard let creature = creature, let scene = scene else { return }

        // Convert creature position from parallax layer to scene coordinates.
        // The creature is in the foreground parallax layer (world space) but
        // the text node is added to the scene root (screen space).
        let creatureScene = creatureScenePosition()
        let creatureX = creatureScene.x

        // Spawn text on the OPPOSITE side from creature, so it floats toward it
        let spawnX: CGFloat
        if creatureX > SceneConstants.sceneWidth / 2 {
            // Creature is on the RIGHT — text spawns from LEFT, creature eats from RIGHT end
            spawnX = -10
            eatingFromLeft = false  // Eat from the right end (closest to creature)
        } else {
            // Creature is on the LEFT — text spawns from RIGHT, creature eats from LEFT end
            spawnX = SceneConstants.sceneWidth + 10
            eatingFromLeft = true  // Eat from the left end (closest to creature)
        }

        // Position at creature's height (in scene coordinates), clamped to Touch Bar.
        // Larger fonts need more headroom to stay on screen.
        let textY = min(creatureScene.y + 4, SceneConstants.sceneHeight - fontSize * 0.6 - 2)
        textNode.position = CGPoint(x: spawnX, y: textY)

        // Start all characters invisible
        for charNode in textNode.charNodes {
            charNode.alpha = 0
        }

        scene.addChild(textNode)
        self.textNode = textNode

        NSLog("[Pushling/Eating] Start: '%@' type=%@ speed=%dms/char from=%@",
              String(commit.message.prefix(20)), commitType.rawValue,
              msPerChar, eatingFromLeft ? "left" : "right")
    }

    // MARK: - Update

    func update(deltaTime: TimeInterval) {
        guard phase != .idle && phase != .complete else { return }
        phaseTimer += deltaTime
        totalTimer += deltaTime

        switch phase {
        case .arrival: updateArrival(deltaTime: deltaTime)
        case .notice:  updateNotice(deltaTime: deltaTime)
        case .feast:   updateFeast(deltaTime: deltaTime)
        case .reaction: updateReaction(deltaTime: deltaTime)
        default: break
        }
    }

    // MARK: - Phase 1: Arrival (3s)
    // Text materializes character by character at bar edge,
    // then floats toward the creature. Stops next to it.

    private func updateArrival(deltaTime: TimeInterval) {
        guard let textNode = textNode, let creature = creature else { return }

        // Stagger character fade-in (60ms apart)
        for (i, charNode) in textNode.charNodes.enumerated() {
            let staggerTime = Double(i) * 0.06
            if phaseTimer >= staggerTime {
                let fadeProgress = min(1.0, (phaseTimer - staggerTime) / 0.22)
                charNode.alpha = CGFloat(fadeProgress)
            }
        }

        // Gentle bob
        for (i, charNode) in textNode.charNodes.enumerated() {
            let bobOffset = sin(totalTimer * 1.5 + Double(i) * 0.3) * 1.0
            charNode.position.y = CGFloat(bobOffset)
        }

        // Drift toward creature (in scene coordinates)
        let creatureX = creatureScenePosition().x
        let textX = textNode.position.x
        let distance = abs(textX - creatureX)
        let direction: CGFloat = textX > creatureX ? -1 : 1

        // Speed up as it gets closer (easing)
        let driftSpeed: CGFloat
        if commitType == .forcePush {
            driftSpeed = 200  // Force push slams in fast
        } else if distance > 200 {
            driftSpeed = 80   // Far away: leisurely
        } else if distance > 50 {
            driftSpeed = 40   // Getting close: slow down
        } else {
            driftSpeed = 12   // Almost there: gentle approach
        }
        textNode.position.x += direction * driftSpeed * CGFloat(deltaTime)

        // Stop when text reaches the creature (within 40pt)
        // Text node position is its left edge, so account for text width
        let textWidth = CGFloat(textNode.charNodes.count) * textNode.activeSpacing
        let effectiveDistance: CGFloat
        if eatingFromLeft {
            // Text approaching from right, creature on left — check left edge of text
            effectiveDistance = abs(textNode.position.x - creatureX)
        } else {
            // Text approaching from left, creature on right — check right edge of text
            effectiveDistance = abs((textNode.position.x + textWidth) - creatureX)
        }
        if effectiveDistance < 40 {
            phase = .notice
            phaseTimer = 0
        }

        // Safety timeout: if still not there after 6s, snap to creature
        if phaseTimer >= 6.0 {
            let snapX = creatureScenePosition().x
            textNode.position.x = snapX + (eatingFromLeft ? 30 : -30)
            phase = .notice
            phaseTimer = 0
        }
    }

    // MARK: - Phase 2: Notice (1s)
    // Creature perks ears, eyes widen, predator crouch with butt wiggle

    private func updateNotice(deltaTime: TimeInterval) {
        guard let creature = creature, let textNode = textNode else { return }

        // Keep bobbing
        for (i, charNode) in textNode.charNodes.enumerated() {
            let bobOffset = sin(totalTimer * 1.5 + Double(i) * 0.3) * 1.0
            charNode.position.y = CGFloat(bobOffset)
        }

        // Creature reactions — predator crouch sequence
        if phaseTimer < 0.1 {
            creature.earLeftController?.setState("perk", duration: 0.1)
            creature.earRightController?.setState("perk", duration: 0.1)
            creature.eyeLeftController?.setState("wide", duration: 0.1)
            creature.eyeRightController?.setState("wide", duration: 0.1)

            // Body compress 15% — predator crouch
            if creature.currentStage >= .critter {
                let crouch = SKAction.scaleY(to: 0.85, duration: 0.15)
                crouch.timingMode = .easeOut
                creature.run(crouch, withKey: "predatorCrouch")
            }
        }

        // Face toward the text
        if eatingFromLeft {
            creature.setFacing(.right)
        } else {
            creature.setFacing(.left)
        }

        // Butt wiggle for Critter+ — ±1pt lateral oscillation at 200ms
        if phaseTimer >= 0.3 && creature.currentStage >= .critter {
            creature.tailController?.setState("sway_fast", duration: 0)
            let wigglePhase = (phaseTimer - 0.3) / 0.2
            let wiggleOffset = sin(wigglePhase * 2.0 * .pi) * 1.0
            creature.position.x = creature.position.x
                + CGFloat(wiggleOffset) * CGFloat(deltaTime) * 20
        }

        if phaseTimer >= 1.5 {
            // Spring forward — release crouch with stretch
            if creature.currentStage >= .critter {
                let spring = SKAction.sequence([
                    SKAction.scaleY(to: 1.1, duration: 0.08),
                    SKAction.scaleY(to: 1.0, duration: 0.12)
                ])
                spring.timingMode = .easeOut
                creature.run(spring, withKey: "predatorSpring")
            }

            creature.tailController?.setState("sway", duration: 0.2)
            creature.mouthController?.setState("open", duration: 0)
            phase = .feast
            phaseTimer = 0
        }
    }

    // MARK: - Phase 3: Feast
    // Eat characters one by one from the side closest to creature.
    // Each character shakes, shrinks, flashes, and disappears.

    private func updateFeast(deltaTime: TimeInterval) {
        guard let creature = creature, let textNode = textNode else { return }
        let charCount = textNode.charNodes.count
        guard charCount > 0 else {
            phase = .reaction
            phaseTimer = 0
            return
        }

        eatTimer += deltaTime

        let eatInterval = Double(msPerChar) / 1000.0

        if eatTimer >= eatInterval && eatIndex < charCount {
            // Determine which character to eat — from the side closest to creature
            let actualIndex: Int
            if eatingFromLeft {
                // Creature is to the left — eat leftmost remaining first
                actualIndex = eatIndex
            } else {
                // Creature is to the right — eat rightmost remaining first
                actualIndex = charCount - 1 - eatIndex
            }

            eatCharacter(at: actualIndex)
            eatIndex += 1
            eatTimer = 0
            charsEatenSinceSwallow += 1

            // Chewing animation
            creature.mouthController?.setState("open", duration: 0)
            let closeAction = SKAction.sequence([
                .wait(forDuration: 0.06),
                .run { [weak creature] in
                    creature?.mouthController?.setState("closed", duration: 0)
                },
                .wait(forDuration: 0.06),
                .run { [weak creature] in
                    creature?.mouthController?.setState("open", duration: 0)
                }
            ])
            creature.run(closeAction, withKey: "chewing")

            // Swallow every 5th character
            if charsEatenSinceSwallow >= 5 {
                charsEatenSinceSwallow = 0
                let swallow = SKAction.sequence([
                    .moveBy(x: 0, y: -0.5, duration: 0.075),
                    .moveBy(x: 0, y: 0.5, duration: 0.075)
                ])
                creature.run(swallow, withKey: "swallow")
            }

            // Shake remaining text toward creature
            if let textNode = self.textNode {
                let shakeDir: CGFloat = eatingFromLeft ? -1 : 1
                let shake = SKAction.sequence([
                    .moveBy(x: shakeDir * 2, y: 0, duration: 0.03),
                    .moveBy(x: shakeDir * -2, y: 0, duration: 0.03)
                ])
                textNode.run(shake, withKey: "eatShake")
            }
        }

        // Keep remaining characters bobbing gently
        for (i, charNode) in textNode.charNodes.enumerated() {
            if !charNode.isHidden {
                let bobOffset = sin(totalTimer * 1.5 + Double(i) * 0.3) * 0.5
                charNode.position.y = CGFloat(bobOffset)
            }
        }

        // All eaten?
        if eatIndex >= charCount {
            creature.mouthController?.setState("closed", duration: 0.1)
            phase = .reaction
            phaseTimer = 0
        }
    }

    /// Animate a single character being eaten — shake, shrink, flash, gone.
    private func eatCharacter(at index: Int) {
        guard let textNode = textNode,
              index >= 0, index < textNode.charNodes.count else { return }

        let charNode = textNode.charNodes[index]

        // Shake → shrink → flash white → disappear
        let shake = SKAction.sequence([
            .moveBy(x: -1, y: 0, duration: 0.02),
            .moveBy(x: 2, y: 0, duration: 0.02),
            .moveBy(x: -1, y: 0, duration: 0.02)
        ])
        let shrink = SKAction.scale(to: 0.3, duration: 0.1)
        let flash = SKAction.run { charNode.fontColor = PushlingPalette.bone }
        let fadeOut = SKAction.fadeOut(withDuration: 0.05)
        let hide = SKAction.run { charNode.isHidden = true }

        charNode.run(SKAction.sequence([shake, shrink, flash, fadeOut, hide]))

        // Crumb particles
        if let scene = scene {
            emitCrumbs(at: charNode.convert(.zero, to: scene))
        }
    }

    private func emitCrumbs(at position: CGPoint) {
        guard let emitter = crumbEmitter, let scene = scene else { return }
        emitter.position = position
        if emitter.parent == nil { scene.addChild(emitter) }

        let count = (commitType == .hugeRefactor || commitType == .largeRefactor)
            ? 10 : 3
        emitter.particleBirthRate = CGFloat(count) / 0.1
        emitter.numParticlesToEmit = count
        emitter.resetSimulation()

        switch commitType {
        case .css:  emitter.particleColor = PushlingPalette.gilt
        case .docs: emitter.particleColor = PushlingPalette.moss
        case .php:  emitter.particleColor = PushlingPalette.ember
        default:    emitter.particleColor = PushlingPalette.tide
        }
    }

    // MARK: - Phase 4: Reaction (2.5s)

    private func updateReaction(deltaTime: TimeInterval) {
        guard let creature = creature, let scene = scene else { return }

        // Final swallow at start
        if phaseTimer < 0.1 {
            let gulp = SKAction.sequence([
                .moveBy(x: 0, y: -1, duration: 0.1),
                .moveBy(x: 0, y: 1, duration: 0.1)
            ])
            creature.run(gulp, withKey: "finalSwallow")
        }

        // XP float at 0.3s
        if phaseTimer >= 0.3 && phaseTimer - deltaTime < 0.3 {
            showXPFloat(scene: scene)
            creature.eyeLeftController?.setState("open", duration: 0.2)
            creature.eyeRightController?.setState("open", duration: 0.2)
            creature.earLeftController?.setState("neutral", duration: 0.3)
            creature.earRightController?.setState("neutral", duration: 0.3)
        }

        // Speech reaction at 0.6s
        if phaseTimer >= 0.6 && phaseTimer - deltaTime < 0.6 {
            let reaction: String
            if creature.currentStage >= .beast {
                reaction = commitType.speechReaction
            } else if creature.currentStage == .critter {
                reaction = commitType.critterReaction
            } else {
                reaction = DropSymbolSet.symbolForEmotion(
                    commitType.dropSymbolEmotion).glyph
            }
            onSpeechReaction?(reaction)
        }

        // Float XP label
        if let xpLabel = xpLabel {
            xpLabel.position.y += CGFloat(deltaTime) * 4
            xpLabel.alpha -= CGFloat(deltaTime) / 3.5
            if xpLabel.alpha <= 0 {
                xpLabel.removeFromParent()
                self.xpLabel = nil
            }
        }

        if phaseTimer >= 3.5 {
            textNode?.resetAll()
            textNode?.removeFromParent()
            textNode = nil
            crumbEmitter?.removeFromParent()
            phase = .complete
            onComplete?(commitType, xpResult)
        }
    }

    private func showXPFloat(scene: SKScene) {
        guard let xpResult = xpResult, let creature = creature else { return }
        let label = SKLabelNode(fontNamed: "SFProText-Bold")
        label.fontSize = 7
        label.fontColor = PushlingPalette.gilt
        label.text = xpResult.displayString
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        let creatureH = StageConfiguration.all[creature.currentStage]?.size.height ?? 16
        let creatureScene = creatureScenePosition()
        let xpY = min(creatureScene.y + creatureH / 2 + 4,
                       SceneConstants.sceneHeight - 6)
        label.position = CGPoint(x: creatureScene.x, y: xpY)
        label.zPosition = 38
        scene.addChild(label)
        self.xpLabel = label
    }

    // MARK: - Coordinate Helpers

    /// Convert creature position from parallax layer space to scene space.
    /// The creature is a child of the parallax foreground layer, but the text
    /// node lives in the scene root — their coordinate spaces differ.
    private func creatureScenePosition() -> CGPoint {
        guard let creature = creature, let scene = scene else { return .zero }
        if let parent = creature.parent {
            return parent.convert(creature.position, to: scene)
        }
        return creature.position
    }

    // MARK: - Status

    var isEating: Bool { phase != .idle && phase != .complete }

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
