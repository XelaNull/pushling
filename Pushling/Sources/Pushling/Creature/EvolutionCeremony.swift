// EvolutionCeremony.swift — 5-second stage transition spectacle
// Phases: Stillness (0.8s) → Gathering (1.2s) → Cocoon (1.0s)
//         → Burst (0.5s) → Reveal (1.5s)
// Breathing continues throughout (reduced amplitude during stillness/cocoon).
// Total node count during burst must stay under 120.

import SpriteKit

final class EvolutionCeremony {

    // MARK: - Phase Definitions

    enum Phase: Int, CaseIterable {
        case stillness  = 0  // 0.0 - 0.8s
        case gathering  = 1  // 0.8 - 2.0s
        case cocoon     = 2  // 2.0 - 3.0s
        case burst      = 3  // 3.0 - 3.5s
        case reveal     = 4  // 3.5 - 5.0s
        case complete   = 5
    }

    private static let phaseDurations: [Phase: TimeInterval] = [
        .stillness: 0.8,
        .gathering: 1.2,
        .cocoon:    1.0,
        .burst:     0.5,
        .reveal:    1.5,
    ]

    // MARK: - Properties

    private weak var creature: CreatureNode?
    private let fromStage: GrowthStage
    private let toStage: GrowthStage
    private let completion: () -> Void

    private var currentPhase: Phase = .stillness
    private var phaseTimer: TimeInterval = 0
    private var totalTimer: TimeInterval = 0

    /// Container for ceremony particle effects.
    private var ceremonyContainer: SKNode?

    /// Gathering particle nodes.
    private var gatherParticles: [SKShapeNode] = []

    /// Cocoon orb node.
    private var cocoonOrb: SKShapeNode?

    /// Stage name banner.
    private var stageBanner: SKLabelNode?

    /// Flash overlay.
    private var flashOverlay: SKShapeNode?

    // MARK: - Init

    init(creature: CreatureNode, fromStage: GrowthStage,
         toStage: GrowthStage, completion: @escaping () -> Void) {
        self.creature = creature
        self.fromStage = fromStage
        self.toStage = toStage
        self.completion = completion
    }

    // MARK: - Lifecycle

    func begin() {
        guard let creature = creature else { return }

        NSLog("[Pushling/Evolution] Beginning ceremony: %@ → %@",
              "\(fromStage)", "\(toStage)")

        let container = SKNode()
        container.name = "evolution_ceremony"
        container.zPosition = 100
        creature.addChild(container)
        ceremonyContainer = container

        currentPhase = .stillness
        phaseTimer = 0
        totalTimer = 0

        beginStillness()
    }

    func update(deltaTime: TimeInterval) {
        totalTimer += deltaTime
        phaseTimer += deltaTime

        let phaseDuration = Self.phaseDurations[currentPhase] ?? 0

        // Update current phase
        switch currentPhase {
        case .stillness:
            updateStillness(progress: phaseTimer / phaseDuration)
        case .gathering:
            updateGathering(progress: phaseTimer / phaseDuration)
        case .cocoon:
            updateCocoon(progress: phaseTimer / phaseDuration)
        case .burst:
            updateBurst(progress: phaseTimer / phaseDuration)
        case .reveal:
            updateReveal(progress: phaseTimer / phaseDuration)
        case .complete:
            return
        }

        // Check phase transition
        if phaseTimer >= phaseDuration && currentPhase != .complete {
            advancePhase()
        }
    }

    // MARK: - Phase Transitions

    private func advancePhase() {
        guard let nextRaw = Phase(rawValue: currentPhase.rawValue + 1)
        else { return }

        phaseTimer = 0
        currentPhase = nextRaw

        switch nextRaw {
        case .stillness:
            break  // Already started
        case .gathering:
            beginGathering()
        case .cocoon:
            beginCocoon()
        case .burst:
            beginBurst()
        case .reveal:
            beginReveal()
        case .complete:
            finishCeremony()
        }
    }

    // MARK: - Phase 1: Stillness (0.8s)

    private func beginStillness() {
        guard let creature = creature else { return }
        // All animation stops (except breathing — reduced amplitude)
        creature.earLeftController?.setState("flat", duration: 0.3)
        creature.earRightController?.setState("flat", duration: 0.3)
        creature.tailController?.setState("still", duration: 0.2)
        creature.setTailSwayActive(false)
        creature.setWhiskerTwitchesActive(false)
    }

    private func updateStillness(progress: Double) {
        // World holds its breath — creature goes very still
        // Breathing amplitude is already handled by CreatureNode
    }

    // MARK: - Phase 2: Gathering (1.2s)

    private func beginGathering() {
        guard let container = ceremonyContainer else { return }

        // Create 25 light particles streaming from edges
        let particleCount = 25
        gatherParticles.removeAll()

        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 1.0)
            particle.fillColor = PushlingPalette.gilt
            particle.strokeColor = .clear
            particle.alpha = 0.8

            // Start from random edge positions
            let angle = CGFloat(i) / CGFloat(particleCount)
                * 2.0 * .pi
            let radius: CGFloat = 40.0
            particle.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            particle.name = "gather_\(i)"
            container.addChild(particle)
            gatherParticles.append(particle)
        }
    }

    private func updateGathering(progress: Double) {
        let t = CGFloat(progress)

        // Particles converge toward center
        for (i, particle) in gatherParticles.enumerated() {
            let angle = CGFloat(i) / CGFloat(gatherParticles.count)
                * 2.0 * .pi
            let startRadius: CGFloat = 40.0
            let currentRadius = startRadius * (1.0 - t)
            particle.position = CGPoint(
                x: cos(angle + t * 2.0) * currentRadius,
                y: sin(angle + t * 2.0) * currentRadius
            )
            particle.alpha = CGFloat(0.3 + progress * 0.7)
        }

        // Creature begins to glow
        creature?.alpha = 1.0 + CGFloat(progress) * 0.3
    }

    // MARK: - Phase 3: Cocoon (1.0s)

    private func beginCocoon() {
        guard let container = ceremonyContainer else { return }

        // Remove gather particles
        for p in gatherParticles { p.removeFromParent() }
        gatherParticles.removeAll()

        // Create bright orb
        let orb = SKShapeNode(circleOfRadius: 8.0)
        orb.fillColor = PushlingPalette.gilt
        orb.strokeColor = PushlingPalette.bone
        orb.lineWidth = 1
        orb.alpha = 0.6
        orb.name = "cocoon_orb"
        orb.zPosition = 110
        container.addChild(orb)
        cocoonOrb = orb

        // Ground crack lines
        for i in 0..<3 {
            let crack = SKShapeNode()
            let path = CGMutablePath()
            let xOff = CGFloat(i - 1) * 4.0
            path.move(to: CGPoint(x: xOff, y: -8))
            path.addLine(to: CGPoint(x: xOff + CGFloat.random(in: -2...2),
                                     y: -12))
            crack.path = path
            crack.strokeColor = PushlingPalette.gilt
            crack.lineWidth = 0.5
            crack.alpha = 0
            crack.name = "crack_\(i)"
            container.addChild(crack)
        }
    }

    private func updateCocoon(progress: Double) {
        let t = CGFloat(progress)
        cocoonOrb?.setScale(1.0 + t * 0.5)
        cocoonOrb?.alpha = 0.6 + t * 0.4

        // Ground cracks fade in
        ceremonyContainer?.children
            .filter { $0.name?.hasPrefix("crack_") == true }
            .forEach { $0.alpha = t }
    }

    // MARK: - Phase 4: Burst (0.5s)

    private func beginBurst() {
        guard let container = ceremonyContainer,
              let creature = creature else { return }

        // Remove cocoon orb
        cocoonOrb?.removeFromParent()
        cocoonOrb = nil

        // Full-screen white flash using an emitter for the particle burst
        // (Use a single emitter node instead of 200 individual nodes)
        let flash = SKShapeNode(rectOf: CGSize(width: 200, height: 60))
        flash.fillColor = PushlingPalette.bone
        flash.strokeColor = .clear
        flash.alpha = 0.9
        flash.name = "flash"
        flash.zPosition = 200
        container.addChild(flash)
        flashOverlay = flash

        // Burst particles — use an SKEmitterNode for efficiency
        // (stays well under 120 node count)
        let emitter = createBurstEmitter()
        emitter.name = "burst_emitter"
        emitter.zPosition = 150
        container.addChild(emitter)

        // Screen shake
        let shakeRight = SKAction.moveBy(x: 2, y: 0, duration: 0.033)
        let shakeLeft = SKAction.moveBy(x: -4, y: 0, duration: 0.033)
        let shakeBack = SKAction.moveBy(x: 2, y: 0, duration: 0.033)
        let shake = SKAction.sequence([shakeRight, shakeLeft, shakeBack])
        creature.run(SKAction.repeat(shake, count: 3),
                     withKey: "evolutionShake")

        // Now reconfigure the creature for the new stage
        creature.configureForStage(toStage)
        // Start at larger scale for the reveal
        creature.setScale(1.2 * creature.facing.xScale)
    }

    private func updateBurst(progress: Double) {
        // Flash fades out rapidly
        flashOverlay?.alpha = CGFloat(1.0 - progress * 2.0)
    }

    // MARK: - Phase 5: Reveal (1.5s)

    private func beginReveal() {
        guard let container = ceremonyContainer,
              let creature = creature else { return }

        // Remove flash
        flashOverlay?.removeFromParent()
        flashOverlay = nil

        // Clean up cracks
        container.children
            .filter { $0.name?.hasPrefix("crack_") == true }
            .forEach { $0.removeFromParent() }

        // Scale down from 1.2x to 1.0x with ease-out
        let scaleDown = SKAction.scale(
            to: abs(creature.facing.xScale),
            duration: 0.5
        )
        scaleDown.timingMode = .easeOut
        creature.run(scaleDown, withKey: "revealScale")

        // Stage name banner
        let banner = SKLabelNode(fontNamed: "Menlo-Bold")
        banner.fontSize = 8
        banner.fontColor = PushlingPalette.gilt
        banner.text = String(describing: toStage).uppercased()
        banner.horizontalAlignmentMode = .center
        banner.verticalAlignmentMode = .center
        banner.position = CGPoint(x: 40, y: 0)
        banner.alpha = 0
        banner.name = "stage_banner"
        banner.zPosition = 120
        container.addChild(banner)
        stageBanner = banner

        // Slide in from right
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let moveIn = SKAction.moveBy(x: -30, y: 0, duration: 0.3)
        moveIn.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        banner.run(SKAction.sequence([
            SKAction.group([fadeIn, moveIn]),
            hold,
            fadeOut
        ]))

        // Re-enable creature systems
        creature.setTailSwayActive(true)
        creature.setWhiskerTwitchesActive(true)
    }

    private func updateReveal(progress: Double) {
        // Creature settling into new form — handled by SKActions
    }

    // MARK: - Finish

    private func finishCeremony() {
        // Clean up ceremony container
        ceremonyContainer?.removeAllChildren()
        ceremonyContainer?.removeFromParent()
        ceremonyContainer = nil
        gatherParticles.removeAll()

        // Play first action at new stage
        playFirstAction()

        NSLog("[Pushling/Evolution] Ceremony complete: now %@",
              "\(toStage)")
        completion()
    }

    /// Stage-specific first action after evolution.
    private func playFirstAction() {
        guard let creature = creature else { return }

        switch toStage {
        case .drop:
            // Eyes open for the first time. Slow look left, then right.
            creature.eyeLeftController?.setState("closed", duration: 0)
            creature.eyeRightController?.setState("closed", duration: 0)
            let openDelay = SKAction.wait(forDuration: 0.5)
            let openEyes = SKAction.run {
                creature.eyeLeftController?.setState("open", duration: 0.3)
                creature.eyeRightController?.setState("open", duration: 0.3)
            }
            let lookLeft = SKAction.run {
                creature.eyeLeftController?.setState("look_at", duration: 0)
                creature.eyeRightController?.setState("look_at", duration: 0)
            }
            let lookRight = SKAction.run {
                creature.setFacing(.right)
            }
            creature.run(SKAction.sequence([
                openDelay, openEyes,
                SKAction.wait(forDuration: 0.5), lookLeft,
                SKAction.wait(forDuration: 0.8), lookRight,
            ]), withKey: "firstAction")

        case .critter:
            // First tentative step, wobble, step again
            creature.pawFLController?.setState("walk", duration: 0)
            creature.pawBRController?.setState("walk", duration: 0)
            let wobble = SKAction.sequence([
                SKAction.rotate(byAngle: 0.05, duration: 0.15),
                SKAction.rotate(byAngle: -0.1, duration: 0.15),
                SKAction.rotate(byAngle: 0.05, duration: 0.15),
            ])
            creature.run(wobble, withKey: "firstAction")

        case .beast:
            // Victory lap across the bar (indicated by a quick sprint)
            creature.earLeftController?.setState("perk", duration: 0.1)
            creature.earRightController?.setState("perk", duration: 0.1)
            creature.tailController?.setState("high", duration: 0.1)

        case .sage:
            // Sit and meditate for 3 seconds
            creature.earLeftController?.setState("neutral", duration: 0.3)
            creature.earRightController?.setState("neutral", duration: 0.3)
            creature.eyeLeftController?.setState("half", duration: 0.5)
            creature.eyeRightController?.setState("half", duration: 0.5)
            creature.tailController?.setState("wrap", duration: 0.5)

        case .apex:
            // Look at own paws with wonder
            creature.eyeLeftController?.setState("wide", duration: 0.3)
            creature.eyeRightController?.setState("wide", duration: 0.3)

        case .spore:
            break // Can't evolve TO spore
        }
    }

    // MARK: - Particle Effects

    /// Create a burst emitter for the explosion phase.
    /// Uses SKEmitterNode to keep node count under 120.
    private func createBurstEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.4
        emitter.numParticlesToEmit = 100
        emitter.particleBirthRate = 500
        emitter.particleSpeed = 60
        emitter.particleSpeedRange = 30
        emitter.emissionAngleRange = 2.0 * .pi
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.3
        emitter.particleColor = PushlingPalette.gilt
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        return emitter
    }
}
