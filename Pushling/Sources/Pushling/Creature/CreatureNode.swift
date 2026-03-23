// CreatureNode.swift — Root composite SKNode for the Pushling creature
// Contains all body parts as independently animatable children.
// Manages breathing (per-frame), blink system, tail sway, whisker twitches.
// This is the creature's physical form on the Touch Bar.

import SpriteKit

final class CreatureNode: SKNode {

    // MARK: - Current State

    private(set) var currentStage: GrowthStage = .spore
    private(set) var facing: Direction = .right
    private(set) var isSleeping = false

    // MARK: - Body Part Nodes

    private var bodyNode: SKShapeNode?
    private var coreGlowNode: SKShapeNode?
    private var headNode: SKNode?
    private var auraNode: SKShapeNode?
    private var tailNode: SKShapeNode?
    private var particlesNode: SKNode?

    // MARK: - Body Part Controllers

    private(set) var earLeftController: EarController?
    private(set) var earRightController: EarController?
    private(set) var eyeLeftController: EyeController?
    private(set) var eyeRightController: EyeController?
    private(set) var tailController: TailController?
    private(set) var mouthController: MouthController?
    private(set) var whiskerLeftController: WhiskerController?
    private(set) var whiskerRightController: WhiskerController?
    private(set) var pawFLController: PawController?
    private(set) var pawFRController: PawController?
    private(set) var pawBLController: PawController?
    private(set) var pawBRController: PawController?

    // MARK: - Visual Traits (Git History → Appearance)

    /// Visual traits from git history — determines body color, eye shape, etc.
    var visualTraits: VisualTraits = .neutral

    // MARK: - Breathing State (Per-Frame — NEVER an SKAction)

    /// Accumulated time for breathing sine wave.
    private var breathingTime: TimeInterval = 0

    /// Breathing parameters.
    private let breathAmplitudeAwake: CGFloat = 0.03   // 1.0 to 1.03
    private let breathAmplitudeSleep: CGFloat = 0.02   // 1.0 to 1.02
    private let breathPeriodAwake: TimeInterval = 2.5   // seconds
    private let breathPeriodSleep: TimeInterval = 3.5   // deeper, slower

    /// Emotional override for breathing period. Set by EmotionalVisualController.
    var breathPeriodOverride: TimeInterval?

    // MARK: - Blink System

    /// Time until next blink.
    private var blinkTimer: TimeInterval = 0
    private var nextBlinkAt: TimeInterval = 0
    private var blinkCooldown: TimeInterval = 0

    /// Personality energy (0-1) modifies blink timing.
    var personalityEnergy: CGFloat = 0.5 {
        didSet {
            tailController?.personalityEnergy = personalityEnergy
        }
    }

    /// Personality focus (0-1) modifies whisker twitches.
    var personalityFocus: CGFloat = 0.5 {
        didSet {
            whiskerLeftController?.personalityFocus = personalityFocus
            whiskerRightController?.personalityFocus = personalityFocus
        }
    }

    /// Full personality snapshot for PersonalityFilter calls.
    /// Updated by GameCoordinator when personality changes.
    var personalitySnapshot: PersonalitySnapshot = .neutral {
        didSet {
            tailController?.personalitySnapshot = personalitySnapshot
        }
    }

    // MARK: - Multi-Tail (Apex)

    /// Additional tail nodes for Apex multi-tail (driven by per-frame sway).
    private var additionalTailNodes: [SKShapeNode] = []

    /// Number of tracked repos (drives Apex multi-tail count). Set by GameCoordinator.
    var repoCount: Int = 1

    // MARK: - Tail Sway

    /// Whether the tail sway is active (suppressed during certain states).
    private var isTailSwayActive = true

    // MARK: - Whisker Twitch

    /// Whether whisker micro-twitches are active.
    private var areWhiskerTwitchesActive = true

    // MARK: - Evolution Ceremony

    private(set) var isEvolving = false
    private var evolutionCeremony: EvolutionCeremony?

    /// Callback invoked when evolution is requested. The scene intercepts
    /// this to route the evolution through the CinematicSequencer.
    ///
    /// Parameters: (fromStage, toStage, startCeremony closure).
    /// The scene calls the startCeremony closure at the right phase
    /// in the cinematic sequence to trigger EvolutionCeremony.begin().
    var onEvolutionRequested: ((GrowthStage, GrowthStage,
                                @escaping () -> Void) -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        self.name = "creature"
        scheduleNextBlink()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Stage Configuration

    /// Configure the creature for a specific growth stage.
    /// Removes old body parts and builds new ones.
    func configureForStage(_ stage: GrowthStage) {
        // Remove existing body part children
        removeAllChildren()
        clearControllers()

        currentStage = stage
        let nodes = StageRenderer.build(stage: stage, repoCount: repoCount,
                                        visualTraits: visualTraits)

        // Add all nodes to the tree
        addBodyParts(nodes)

        // Create controllers for available parts
        createControllers(from: nodes, stage: stage)

        // Set initial states
        applyDefaultStates()

        NSLog("[Pushling/Creature] Configured for stage: %@, "
              + "node count: %d", "\(stage)", countNodes())
    }

    // MARK: - Per-Frame Update (Called from PushlingScene)

    /// Main update loop — breathing, blinks, tail, whiskers.
    /// - Parameter deltaTime: Seconds since last frame.
    func update(deltaTime: TimeInterval) {
        // === BREATHING — The most important animation ===
        // Per-frame sine-wave Y-scale. Never stops. Never an SKAction.
        updateBreathing(deltaTime: deltaTime)

        // === BLINK SYSTEM ===
        updateBlinkSystem(deltaTime: deltaTime)

        // === BODY PART CONTROLLERS ===
        eyeLeftController?.update(deltaTime: deltaTime)
        eyeRightController?.update(deltaTime: deltaTime)
        earLeftController?.update(deltaTime: deltaTime)
        earRightController?.update(deltaTime: deltaTime)
        mouthController?.update(deltaTime: deltaTime)

        // === TAIL SWAY ===
        if isTailSwayActive {
            tailController?.update(deltaTime: deltaTime)

            // Animate additional Apex tails with staggered sway
            for (i, tail) in additionalTailNodes.enumerated() {
                let phase = breathingTime + Double(i + 1) * 0.4
                let angle = 0.15 * CGFloat(sin(phase * 2.0 * .pi / 3.0))
                tail.zRotation = CGFloat(i + 1) * 0.26 + angle
            }
        }

        // === WHISKER MICRO-TWITCHES ===
        if areWhiskerTwitchesActive {
            whiskerLeftController?.update(deltaTime: deltaTime)
            whiskerRightController?.update(deltaTime: deltaTime)
        }

        // === PAW CONTROLLERS ===
        pawFLController?.update(deltaTime: deltaTime)
        pawFRController?.update(deltaTime: deltaTime)
        pawBLController?.update(deltaTime: deltaTime)
        pawBRController?.update(deltaTime: deltaTime)

        // === CORE GLOW PULSE ===
        updateCoreGlow(deltaTime: deltaTime)

        // === EVOLUTION CEREMONY ===
        if isEvolving {
            evolutionCeremony?.update(deltaTime: deltaTime)
        }
    }

    // MARK: - Breathing (P2-T1-04)

    /// Per-frame breathing. Applied EVERY frame. Never stops.
    /// Formula: yScale = 1.0 + amplitude * sin(2pi * t / period)
    private func updateBreathing(deltaTime: TimeInterval) {
        breathingTime += deltaTime

        let amplitude = isSleeping
            ? breathAmplitudeSleep
            : breathAmplitudeAwake
        let period = breathPeriodOverride ?? (isSleeping
            ? breathPeriodSleep
            : breathPeriodAwake)

        let breathScale = 1.0 + amplitude
            * CGFloat(sin(2.0 * .pi * breathingTime / period))

        // Apply to body node — this is a post-process multiplier.
        // It applies regardless of what other systems do to the body.
        bodyNode?.yScale = breathScale
    }

    // MARK: - Blink System (P2-T1-05)

    private func updateBlinkSystem(deltaTime: TimeInterval) {
        guard currentStage >= .drop else { return }
        // No blinking for Spore

        blinkTimer += deltaTime

        // Don't blink if eyes are already closed or mid-blink
        if eyeLeftController?.isClosed == true { return }
        if eyeLeftController?.isBlinking == true { return }

        // Cooldown after expression change
        if blinkCooldown > 0 {
            blinkCooldown -= deltaTime
            return
        }

        if blinkTimer >= nextBlinkAt {
            triggerBlink()
            scheduleNextBlink()
        }
    }

    private func triggerBlink() {
        eyeLeftController?.setState("blink", duration: 0)
        eyeRightController?.setState("blink", duration: 0)

        // 8% chance of double blink
        if Double.random(in: 0...1) < 0.08 {
            let delay = SKAction.wait(forDuration: 0.25)
            let doubleBlink = SKAction.run { [weak self] in
                self?.eyeLeftController?.setState("blink", duration: 0)
                self?.eyeRightController?.setState("blink", duration: 0)
            }
            run(SKAction.sequence([delay, doubleBlink]),
                withKey: "doubleBlink")
        }
    }

    private func scheduleNextBlink() {
        blinkTimer = 0
        // Blink interval modulated by PersonalityFilter
        let range = PersonalityFilter.blinkInterval(
            personality: personalitySnapshot
        )
        nextBlinkAt = Double.random(in: range)
    }

    /// Reset blink timer (call after eye expression changes).
    func resetBlinkTimer() {
        blinkCooldown = 0.3  // Prevent immediate blink after expression
        blinkTimer = 0
    }

    // MARK: - Sleep State

    func setSleeping(_ sleeping: Bool) {
        isSleeping = sleeping
        if sleeping {
            eyeLeftController?.setState("closed", duration: 0.5)
            eyeRightController?.setState("closed", duration: 0.5)
        } else {
            eyeLeftController?.setState("open", duration: 0.3)
            eyeRightController?.setState("open", duration: 0.3)
        }
    }

    // MARK: - Facing Direction

    func setFacing(_ direction: Direction) {
        facing = direction
        xScale = abs(xScale) * direction.xScale
    }

    // MARK: - Core Glow Pulse

    private var coreGlowTime: TimeInterval = 0

    private func updateCoreGlow(deltaTime: TimeInterval) {
        guard let glow = coreGlowNode else { return }
        coreGlowTime += deltaTime
        // Gentle alpha pulse synced slightly offset from breathing
        let alpha = 0.2 + 0.15
            * CGFloat(sin(2.0 * .pi * coreGlowTime / 3.0))
        glow.alpha = alpha
    }

    // MARK: - Tail Sway Control

    /// Enable/disable tail sway (for states like poof, wrap, etc.).
    func setTailSwayActive(_ active: Bool) {
        isTailSwayActive = active
        if active {
            tailController?.setState("sway", duration: 0.3)
        }
    }

    // MARK: - Whisker Twitch Control

    func setWhiskerTwitchesActive(_ active: Bool) {
        areWhiskerTwitchesActive = active
    }

    // MARK: - Evolution (P2-T1-09)

    /// Begin an evolution ceremony to a new stage.
    ///
    /// If `onEvolutionRequested` is set (wired by PushlingScene), the
    /// ceremony is routed through the CinematicSequencer which controls
    /// camera zoom/pan, touch suppression, and behavior freeze. The
    /// ceremony's begin() is called at the right cinematic phase.
    ///
    /// If no callback is set, the ceremony starts immediately (fallback).
    func evolve(to newStage: GrowthStage,
                completion: (() -> Void)? = nil) {
        guard !isEvolving else { return }
        guard newStage.rawValue == currentStage.rawValue + 1 else {
            NSLog("[Pushling/Creature] Cannot evolve from %@ to %@",
                  "\(currentStage)", "\(newStage)")
            return
        }

        isEvolving = true
        let fromStage = currentStage

        let ceremony = EvolutionCeremony(
            creature: self,
            fromStage: fromStage,
            toStage: newStage
        ) { [weak self] in
            self?.isEvolving = false
            completion?()
        }
        self.evolutionCeremony = ceremony

        // Route through cinematic sequencer if available
        if let handler = onEvolutionRequested {
            handler(fromStage, newStage) { [weak ceremony] in
                ceremony?.begin()
            }
        } else {
            // Fallback: start ceremony immediately
            ceremony.begin()
        }
    }

    // MARK: - Node Count

    /// Count all descendant nodes (for budget monitoring).
    func countNodes() -> Int {
        var count = 1 // self
        func countChildren(_ node: SKNode) {
            for child in node.children {
                count += 1
                countChildren(child)
            }
        }
        countChildren(self)
        return count
    }

    // MARK: - Private Setup

    private func addBodyParts(_ nodes: StageRenderer.StageNodes) {
        // Add in z-order (back to front)
        if let aura = nodes.aura { addChild(aura); auraNode = aura }
        if let cg = nodes.coreGlow { addChild(cg); coreGlowNode = cg }

        addChild(nodes.body)
        bodyNode = nodes.body

        if let tail = nodes.tail { addChild(tail); tailNode = tail }

        // Collect additional tail nodes (Apex multi-tail, children of body)
        additionalTailNodes.removeAll()
        for child in nodes.body.children {
            if let shape = child as? SKShapeNode,
               let name = shape.name, name.hasPrefix("tail_extra_") {
                additionalTailNodes.append(shape)
            }
        }

        if let bl = nodes.pawBL { addChild(bl) }
        if let br = nodes.pawBR { addChild(br) }
        if let fl = nodes.pawFL { addChild(fl) }
        if let fr = nodes.pawFR { addChild(fr) }

        addChild(nodes.head)
        headNode = nodes.head

        addChild(nodes.particles)
        particlesNode = nodes.particles
    }

    private func createControllers(from nodes: StageRenderer.StageNodes,
                                    stage: GrowthStage) {
        let config = StageConfiguration.all[stage]!

        // Eyes — always present (even spore has faint ones)
        eyeLeftController = EyeController(
            eyeNode: nodes.eyeLeft, shape: nodes.eyeLeftShape,
            isLeft: true,
            width: nodes.eyeLeftShape.frame.width,
            height: nodes.eyeLeftShape.frame.height
        )
        eyeRightController = EyeController(
            eyeNode: nodes.eyeRight, shape: nodes.eyeRightShape,
            isLeft: false,
            width: nodes.eyeRightShape.frame.width,
            height: nodes.eyeRightShape.frame.height
        )

        // Ears
        if config.hasEars, let earL = nodes.earLeft,
           let earR = nodes.earRight {
            earLeftController = EarController(earNode: earL, isLeft: true)
            earRightController = EarController(earNode: earR, isLeft: false)
        }

        // Tail
        if config.hasTail, let tail = nodes.tail {
            let tc = TailController(tailNode: tail)
            tc.personalityEnergy = personalityEnergy
            tc.personalitySnapshot = personalitySnapshot
            tc.setState("sway", duration: 0)
            tailController = tc
        }

        // Mouth
        if config.hasMouth, let mouth = nodes.mouth,
           let mouthShape = nodes.mouthShape {
            mouthController = MouthController(
                mouthNode: mouth, shape: mouthShape,
                width: mouthShape.frame.width
            )
        }

        // Whiskers
        if config.hasWhiskers,
           let wl = nodes.whiskerLeft, let wr = nodes.whiskerRight {
            let wlc = WhiskerController(whiskerNode: wl, isLeft: true)
            wlc.personalityFocus = personalityFocus
            whiskerLeftController = wlc

            let wrc = WhiskerController(whiskerNode: wr, isLeft: false)
            wrc.personalityFocus = personalityFocus
            whiskerRightController = wrc
        }

        // Paws
        if config.hasPaws {
            let pw = StageRenderer.pawRestPositions(
                bodyWidth: config.size.width,
                bodyHeight: config.size.height
            )

            if let fl = nodes.pawFL {
                let c = PawController(pawNode: fl, position: .frontLeft,
                                       restingPoint: pw.fl)
                c.cyclePhaseOffset = 0  // FL + BR together
                pawFLController = c
            }
            if let fr = nodes.pawFR {
                let c = PawController(pawNode: fr, position: .frontRight,
                                       restingPoint: pw.fr)
                c.cyclePhaseOffset = .pi  // FR + BL together (offset)
                pawFRController = c
            }
            if let bl = nodes.pawBL {
                let c = PawController(pawNode: bl, position: .backLeft,
                                       restingPoint: pw.bl)
                c.cyclePhaseOffset = .pi  // Diagonal gait
                pawBLController = c
            }
            if let br = nodes.pawBR {
                let c = PawController(pawNode: br, position: .backRight,
                                       restingPoint: pw.br)
                c.cyclePhaseOffset = 0
                pawBRController = c
            }
        }
    }

    private func clearControllers() {
        earLeftController = nil
        earRightController = nil
        eyeLeftController = nil
        eyeRightController = nil
        tailController = nil
        mouthController = nil
        whiskerLeftController = nil
        whiskerRightController = nil
        pawFLController = nil
        pawFRController = nil
        pawBLController = nil
        pawBRController = nil
        additionalTailNodes.removeAll()
        bodyNode = nil
        coreGlowNode = nil
        headNode = nil
        auraNode = nil
        tailNode = nil
        particlesNode = nil
    }

    private func applyDefaultStates() {
        earLeftController?.setState("neutral", duration: 0)
        earRightController?.setState("neutral", duration: 0)
        eyeLeftController?.setState("open", duration: 0)
        eyeRightController?.setState("open", duration: 0)
        tailController?.setState("sway", duration: 0)
        mouthController?.setState("closed", duration: 0)
        whiskerLeftController?.setState("neutral", duration: 0)
        whiskerRightController?.setState("neutral", duration: 0)
        pawFLController?.setState("ground", duration: 0)
        pawFRController?.setState("ground", duration: 0)
        pawBLController?.setState("ground", duration: 0)
        pawBRController?.setState("ground", duration: 0)
    }
}
