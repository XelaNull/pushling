// CreatureTouchHandler.swift — Routes gestures to creature responses
// Central dispatcher: gesture -> subsystem. Milestone-gated.

import SpriteKit

/// Routes gestures to creature responses. Manages tap rotation,
/// milestone gating, and dispatches to specialized handlers.
final class CreatureTouchHandler: GestureRecognizerDelegate {

    // MARK: - Tap Rotation

    /// Cycling tap-on-creature responses.
    private static let tapResponses = ["purr", "chin_tilt", "headbutt", "slow_blink"]
    private var tapRotationIndex = 0

    // MARK: - Subsystems

    let milestoneTracker: MilestoneTracker
    let pettingStroke: PettingStroke
    let laserPointer: LaserPointerMode
    let objectInteraction: ObjectInteraction
    let handFeeding: HandFeeding
    let pounceGame: PounceGame
    let wakeUpBoop: WakeUpBoop
    let unlockCeremony: UnlockCeremony
    let petStreak: PetStreak
    let invitationSystem: InvitationSystem
    let miniGameManager: MiniGameManager

    // MARK: - Scene References

    /// The scene for adding particle nodes.
    private weak var scene: PushlingScene?

    /// The behavior stack for triggering reflexes.
    private weak var behaviorStack: BehaviorStack?

    /// Creature hitbox (updated each frame from creature node bounds).
    var creatureHitbox: CGRect = .zero

    /// Current creature facing direction.
    var creatureFacing: Direction = .right

    /// Current creature stage.
    var creatureStage: GrowthStage = .critter

    /// Whether the creature is sleeping.
    var isSleeping = false

    /// Creature world-X position.
    var creatureWorldX: CGFloat = 542.5

    /// Personality energy for petting tolerance.
    var personalityEnergy: Double = 0.5

    /// Callback for contentment changes.
    var onContentmentChange: ((Double) -> Void)?

    /// Callback for satisfaction changes.
    var onSatisfactionChange: ((Double) -> Void)?

    /// Callback for creature walk-to-point.
    var onWalkToPoint: ((CGFloat) -> Void)?

    // MARK: - Init

    init(db: DatabaseManager? = nil) {
        self.milestoneTracker = MilestoneTracker(db: db)
        self.pettingStroke = PettingStroke()
        self.laserPointer = LaserPointerMode()
        self.objectInteraction = ObjectInteraction()
        self.handFeeding = HandFeeding()
        self.pounceGame = PounceGame()
        self.wakeUpBoop = WakeUpBoop()
        self.unlockCeremony = UnlockCeremony()
        self.petStreak = PetStreak(db: db)
        self.invitationSystem = InvitationSystem()
        self.miniGameManager = MiniGameManager(db: db)

        setupMilestoneCallbacks()
    }

    /// Wires the handler to the scene and behavior stack.
    func wireToScene(_ scene: PushlingScene,
                     behaviorStack: BehaviorStack?) {
        self.scene = scene
        self.behaviorStack = behaviorStack
    }

    // MARK: - GestureRecognizerDelegate

    func gestureRecognizer(_ recognizer: GestureRecognizer,
                           didRecognize event: GestureEvent) {
        // Record all gestures for milestone tracking
        milestoneTracker.recordGesture(event.type)
        petStreak.recordInteraction()
        invitationSystem.recordActivity(at: event.timestamp)

        // Check for daily gift
        if petStreak.hasGiftStreak {
            _ = petStreak.checkDailyGift()
        }

        // Route to mini-game if active
        if miniGameManager.isGameActive {
            if event.type == .tap {
                _ = miniGameManager.handleTap(at: event.position)
            }
            return
        }

        // Route based on gesture type and target
        switch event.type {
        case .tap:
            handleTap(event)
        case .doubleTap:
            handleDoubleTap(event)
        case .tripleTap:
            handleTripleTap(event)
        case .longPress:
            handleLongPress(event)
        case .sustainedTouch:
            handleSustainedTouch(event)
        case .drag, .slowDrag:
            handleDrag(event)
        case .pettingStroke:
            handlePettingStroke(event)
        case .flick:
            handleFlick(event)
        case .rapidTaps:
            handleRapidTaps(event)
        case .multiFingerTwo:
            handleTwoFinger(event)
        case .multiFingerThree:
            handleThreeFinger(event)
        }
    }

    // MARK: - Tap

    private func handleTap(_ event: GestureEvent) {
        switch event.target {
        case .creature:
            // Check for wake-up boop first
            if isSleeping {
                let isNose = WakeUpBoop.isNoseArea(
                    touchPoint: event.position,
                    creatureHitbox: creatureHitbox
                )
                if wakeUpBoop.handleTap(isSleeping: isSleeping,
                                         isNoseArea: isNose,
                                         currentTime: event.timestamp) {
                    milestoneTracker.recordSpecial(.boop)
                    return
                }
            }

            // Check if pounce game catch window is open
            if case .catchWindow = pounceGame.phase {
                if let scene = scene {
                    _ = pounceGame.attemptCatch(at: event.position, in: scene)
                }
                return
            }

            // Check for invitation acceptance
            if invitationSystem.activeInvitation?.state == .offered {
                invitationSystem.acceptInvitation()
                return
            }

            // Normal tap-on-creature: cycle through responses
            let response = Self.tapResponses[tapRotationIndex]
            tapRotationIndex = (tapRotationIndex + 1) % Self.tapResponses.count

            // Heart particle
            emitHeartParticle(at: event.position)

            // Trigger reflex
            behaviorStack?.triggerReflex(named: "ear_perk",
                                          at: event.timestamp)

            onContentmentChange?(3.0)

            NSLog("[Pushling/Touch] Tap creature -> %@", response)

        case .object(let id):
            objectInteraction.tapObject(
                objectId: id,
                node: findObjectNode(id: id) ?? SKNode(),
                currentTime: event.timestamp
            )

        case .world:
            // Tap empty space — show HUD or walk creature to point
            scene?.handleTouch(at: event.position)

        case .commitText:
            break
        }
    }

    // MARK: - Double Tap

    private func handleDoubleTap(_ event: GestureEvent) {
        guard case .creature = event.target else { return }

        // Jump animation
        behaviorStack?.startJump(initialVelocity: 80)
        onSatisfactionChange?(5.0)

        NSLog("[Pushling/Touch] Double-tap creature -> jump")
    }

    // MARK: - Triple Tap

    private func handleTripleTap(_ event: GestureEvent) {
        guard case .creature = event.target else { return }

        // Stage-specific easter egg
        let secret: String
        switch creatureStage {
        case .spore:   secret = "pulse"
        case .drop:    secret = "belly_expose"
        case .critter: secret = "zoomies"
        case .beast:   secret = "map_reveal"
        case .sage:    secret = "prophecy"
        case .apex:    secret = "reality_glitch"
        }

        NSLog("[Pushling/Touch] Triple-tap creature -> %@", secret)
    }

    // MARK: - Long Press

    private func handleLongPress(_ event: GestureEvent) {
        switch event.target {
        case .creature:
            // Thought bubble / context-dependent
            behaviorStack?.triggerReflex(named: "look_at_touch",
                                          at: event.timestamp)

        case .object(let id):
            // Pick up object
            if let node = findObjectNode(id: id) {
                objectInteraction.pickUp(objectId: id, node: node,
                                          touchPoint: event.position)
            }

        case .world, .commitText:
            break
        }
    }

    // MARK: - Sustained Touch

    private func handleSustainedTouch(_ event: GestureEvent) {
        guard case .creature = event.target else { return }

        // Chin scratch — peak contentment
        onContentmentChange?(8.0)

        NSLog("[Pushling/Touch] Sustained touch -> chin scratch")
    }

    // MARK: - Drag

    private func handleDrag(_ event: GestureEvent) {
        // Object being held — move it
        if objectInteraction.isHolding {
            objectInteraction.moveHeld(to: event.position)
            return
        }

        // Hand-feeding active — move commit text
        if handFeeding.isHolding {
            handFeeding.dragTo(event.position)
            return
        }

        // Laser pointer mode (unlocked at 100 touches)
        if milestoneTracker.isUnlocked(.laserPointer) {
            if !laserPointer.isActive, let scene = scene {
                laserPointer.activate(at: event.position, in: scene)
            }
            if laserPointer.isActive {
                laserPointer.updatePosition(
                    event.position,
                    speed: event.velocity.magnitude,
                    deltaTime: 1.0 / 60.0
                )
            }
            return
        }

        // Finger trail (unlocked at 25 touches)
        if milestoneTracker.isUnlocked(.fingerTrail) {
            emitFingerTrailParticle(at: event.position)
        }
    }

    // MARK: - Petting Stroke

    private func handlePettingStroke(_ event: GestureEvent) {
        guard milestoneTracker.isUnlocked(.petting) else {
            // Before unlock: basic head-turn acknowledgment
            behaviorStack?.triggerReflex(named: "look_at_touch",
                                          at: event.timestamp)
            return
        }

        if !pettingStroke.isActive, let scene = scene {
            pettingStroke.beginStroke(
                at: event.position,
                creatureFacing: creatureFacing,
                in: scene,
                currentTime: event.timestamp
            )
        }

        pettingStroke.continueStroke(
            at: event.position,
            velocity: event.velocity,
            speed: event.velocity.magnitude,
            creatureFacing: creatureFacing,
            deltaTime: 1.0 / 60.0
        )
    }

    // MARK: - Flick

    private func handleFlick(_ event: GestureEvent) {
        guard case .object(let id) = event.target else { return }

        if let node = findObjectNode(id: id) {
            objectInteraction.flickObject(
                objectId: id,
                node: node,
                velocity: event.velocity,
                objectType: objectType(for: id)
            )
        }
    }

    // MARK: - Rapid Taps

    private func handleRapidTaps(_ event: GestureEvent) {
        if let scene = scene {
            pounceGame.triggerHunt(
                at: event.position,
                creatureX: creatureWorldX,
                in: scene,
                currentTime: event.timestamp
            )
        }
    }

    // MARK: - Two Finger

    private func handleTwoFinger(_ event: GestureEvent) {
        // Belly rub (on creature, unlocked at 250)
        if case .creature = event.target,
           milestoneTracker.isUnlocked(.bellyRub) {
            milestoneTracker.recordSpecial(.bellyRub)
            handleBellyRub()
            return
        }

        // 2-finger swipe: world pan (handled by scene)
    }

    // MARK: - Three Finger

    private func handleThreeFinger(_ event: GestureEvent) {
        // Display mode cycling (handled by scene)
    }

    // MARK: - Belly Rub

    private func handleBellyRub() {
        // 70% normal, 30% trap
        let trapChance = personalityEnergy > 0.6 ? 0.2 : 0.4
        let isTrap = Double.random(in: 0...1) < trapChance

        if isTrap {
            NSLog("[Pushling/Touch] Belly rub -> TRAP!")
        } else {
            onContentmentChange?(15.0)
            NSLog("[Pushling/Touch] Belly rub -> purring")
        }
    }

    // MARK: - Per-Frame Update

    /// Called each frame to update time-dependent subsystems.
    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        milestoneTracker.update(deltaTime: deltaTime)
        objectInteraction.update(deltaTime: deltaTime)
        wakeUpBoop.update(currentTime: currentTime, isSleeping: isSleeping)
        invitationSystem.update(deltaTime: deltaTime,
                                 currentTime: currentTime)

        if miniGameManager.isGameActive {
            miniGameManager.update(deltaTime: deltaTime,
                                    currentTime: currentTime)
        }
    }

    // MARK: - Touch End Handling

    /// Called when a touch ends (for finalizing drags, drops, etc).
    func handleTouchEnded(at position: CGPoint, currentTime: TimeInterval) {
        // End laser pointer
        if laserPointer.isActive {
            laserPointer.deactivate()
        }

        // End petting stroke
        if pettingStroke.isActive {
            pettingStroke.endStroke(
                creatureFacing: creatureFacing,
                currentTime: currentTime,
                personalityEnergy: personalityEnergy
            )
        }

        // Drop held object
        if objectInteraction.isHolding {
            let terrainY = SceneConstants.groundY
            objectInteraction.dropHeld(terrainY: terrainY)
        }

        // Release hand-fed commit
        if handFeeding.isHolding {
            let creaturePos = CGPoint(x: creatureWorldX, y: 15)
            if handFeeding.release(creaturePosition: creaturePos) {
                milestoneTracker.recordSpecial(.handFeed)
            }
        }
    }

    // MARK: - Particles

    private func emitHeartParticle(at position: CGPoint) {
        guard let scene = scene else { return }
        TouchParticles.emitHeart(
            at: position, in: scene,
            multiplier: milestoneTracker.particleMultiplier
        )
    }

    private func emitFingerTrailParticle(at position: CGPoint) {
        guard let scene = scene else { return }
        TouchParticles.emitFingerTrail(at: position, in: scene)
    }

    // MARK: - Milestone Callbacks

    private func setupMilestoneCallbacks() {
        milestoneTracker.onMilestoneUnlocked = { [weak self] milestone in
            guard let self = self, let scene = self.scene else { return }
            self.unlockCeremony.play(milestone: milestone, in: scene)
        }

        unlockCeremony.onCeremonyComplete = { [weak self] milestone in
            self?.unlockCeremony.markPlayed(
                milestone: milestone,
                db: nil  // DB passed via init
            )
        }
    }

    // MARK: - Helpers

    private func findObjectNode(id: String) -> SKNode? {
        scene?.childNode(withName: "//\(id)")
    }

    private func objectType(for id: String) -> String {
        // In production, look up from world object registry
        "ball"
    }

    // MARK: - Flush

    /// Called on app termination to persist all pending state.
    func flushState() {
        milestoneTracker.flushToDatabase()
    }
}

// MARK: - CGVector Extension

extension CGVector {
    /// Magnitude (speed) of this vector.
    var magnitude: CGFloat {
        sqrt(dx * dx + dy * dy)
    }
}
