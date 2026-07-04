// CreatureNode.swift — Root composite SKNode for the Pushling creature
// Contains all body parts as independently animatable children.
// Manages breathing (per-frame), blink system, tail sway, whisker twitches.
// This is the creature's physical form on the Touch Bar.

import SpriteKit

final class CreatureNode: SKNode {

    // MARK: - Current State

    private(set) var currentStage: GrowthStage = .egg
    private(set) var facing: Direction = .right
    private(set) var isSleeping = false

    // MARK: - Body Part Nodes

    private var bodyNode: SKShapeNode?
    private var coreGlowNode: SKShapeNode?
    private var headNode: SKNode?
    private var auraNode: SKShapeNode?
    private var tailNode: SKShapeNode?
    private var particlesNode: SKNode?

    // MARK: - Skeleton Rig Joints (WO-19 §1 — pelvis-chain foundation)

    /// The compose-point root. Everything below reparents under this
    /// instead of being a flat root sibling — see SkeletonGeometry.swift
    /// and `addBodyParts`'s re-basing recipe. `updateBreathing()` writes
    /// the bodyState pose tuple here (moved from `bodyNode` alone).
    private var pelvisNode: SKNode?

    /// Child of `pelvisNode`. Hosts `headNode` and the front-leg shoulder
    /// pivots. Currently a pure positional joint (no rotation contribution
    /// yet — that's WO-19 sub-part 2's `chestFollowFactor`, not built here).
    private var spineChestNode: SKNode?

    /// Front-leg pivot roots, children of `spineChestNode`. Inert in this
    /// pass (WO-20 gait wires angular swing later) — placed at the belt
    /// line (`SkeletonGeometry.beltY`) directly above each front paw's old
    /// rest position.
    private var shoulderLNode: SKNode?
    private var shoulderRNode: SKNode?

    /// Rear-leg pivot roots, children of `pelvisNode` directly (not
    /// `spineChestNode`) — rear legs stay coupled to the same node the
    /// tail attaches to, matching real quadruped anatomy. Also inert.
    private var hipLNode: SKNode?
    private var hipRNode: SKNode?

    /// Tail attach point, child of `pelvisNode`. Hosts `tailNode` today;
    /// the swap-in point for the dormant `SegmentedTailController` is
    /// WO-19 sub-part 2, not this pass.
    private var tailBaseNode: SKNode?

    // MARK: - Body Part Controllers

    private(set) var earLeftController: EarController?
    private(set) var earRightController: EarController?
    private(set) var eyeLeftController: EyeController?
    private(set) var eyeRightController: EyeController?
    /// WO-19 sub-part 2 swap — `SegmentedTailController` replaces the
    /// single-node `TailController` at the (now-existing) `tailBaseNode`
    /// joint, per emotional-body-language.md's §SegmentedTailController
    /// swap-point note. `TailController.swift` is now the dormant one
    /// (zero instantiation sites), mirroring how `SegmentedTailController`
    /// itself was dormant before this pass. Every external call site only
    /// ever used `setState`/`update` (the shared `BodyPartController`
    /// protocol surface) — confirmed by grep — so this type change has no
    /// ripple beyond this file.
    private(set) var tailController: SegmentedTailController?
    private(set) var mouthController: MouthController?
    private(set) var whiskerLeftController: WhiskerController?
    private(set) var whiskerRightController: WhiskerController?
    private(set) var pawFLController: PawController?
    private(set) var pawFRController: PawController?
    private(set) var pawBLController: PawController?
    private(set) var pawBRController: PawController?

    /// The 13th part controller — owns bodyNode/headNode/paw-alpha's pose
    /// contribution. Gated `stage >= .drop` (see body-pose-pipeline.md §1
    /// and this file's `createControllers` for the divergence note on that
    /// gate). Does not own a node; `updateBreathing()` is the sole writer
    /// of the transform it computes.
    private(set) var bodyPoseController: BodyPoseController?

    /// Current jump vertical velocity, set per-frame by PushlingScene from
    /// `PhysicsLayer.JumpState.velocityY` — feeds the §5 global velocity
    /// squash-stretch pass inside `updateBreathing()`.
    var physicsVelocityY: CGFloat = 0

    /// Previous frame's `bodyPoseController.currentPose.headOffset` —
    /// subtract-then-add delta pattern on `headNode`, matching
    /// `updateNoiseIdle`'s existing convention (body-pose-pipeline.md §2).
    private var previousPoseHeadOffset: CGFloat = 0

    // MARK: - Visual Traits (Git History → Appearance)

    /// Visual traits from git history — determines body color, eye shape, etc.
    var visualTraits: VisualTraits = .neutral

    // MARK: - Noise Idle System (Organic Micro-Movements)

    /// Phase offsets for noise idle — random per body part, set once.
    /// [body, head, earL, earR, whiskerL, whiskerR]
    private let noisePhases: [CGFloat] = (0..<6).map { _ in
        CGFloat.random(in: 0..<(2.0 * .pi))
    }

    /// Noise frequencies (Hz) — irrational ratios so parts never sync.
    private let noiseFreqs: [CGFloat] = [0.3, 0.4, 0.53, 0.57, 0.83, 0.79]

    /// Noise amplitudes — position offsets in points, rotation in radians.
    private let noiseAmps: [CGFloat] = [0.12, 0.15, 0.015, 0.015, 0.02, 0.02]

    /// Previous frame's noise offsets — subtracted before applying new ones.
    /// Prevents accumulation drift.
    private var prevNoiseOffsets: [CGFloat] = [0, 0, 0, 0, 0, 0]

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

    // MARK: - Wise Beard (Apex)

    /// Beard strand nodes for Apex wise beard (driven by per-frame sway).
    private var beardStrandNodes: [SKShapeNode] = []

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

    /// Egg wobble progress (0.0-1.0, intensifies as hatch approaches).
    var eggHatchProgress: CGFloat = 0

    /// Drop hop state — set per-frame, applied in breathing
    private var dropHopOffset: CGFloat = 0
    private var dropHopSquash: CGFloat = 1.0

    /// Main update loop — breathing, blinks, tail, whiskers.
    /// - Parameter deltaTime: Seconds since last frame.
    func update(deltaTime: TimeInterval) {
        // === BODY POSE — advance the 13th controller's internal ease/
        // dynamic-overlay BEFORE breathing reads its currentPose, so the
        // compose point below always sees this frame's pose, not last
        // frame's (body-pose-pipeline.md §1/§6).
        bodyPoseController?.update(deltaTime: deltaTime)

        // === BREATHING — The most important animation ===
        // Per-frame sine-wave Y-scale. Never stops. Never an SKAction.
        updateBreathing(deltaTime: deltaTime)

        // === EGG WOBBLE ===
        // Safe today only because `bodyPoseController` is nil at Egg
        // (gated `stage >= .drop`) — `updateBreathing()`'s compose point
        // already skips writing bodyNode.zRotation at Egg for the same
        // reason. The `bodyPoseController == nil` guard makes that
        // dependency explicit so a future gate-move to `.egg` can't
        // silently let this clobber a composed pose zRotation.
        if currentStage == .egg, bodyPoseController == nil {
            let wobble = sin(breathingTime * 3.0)
                * 0.06 * eggHatchProgress
            bodyNode?.zRotation = CGFloat(wobble)
        }

        // === DROP HOP ===
        // Absolute position offset (not additive) to prevent drift
        if currentStage == .drop {
            let hopValue = abs(CGFloat(sin(breathingTime * 5.0)))
            dropHopOffset = 2.0 * hopValue
            dropHopSquash = 0.85 + 0.15 * hopValue
        }

        // === APEX ALPHA OSCILLATION ===
        if currentStage == .apex {
            let alphaPhase = sin(breathingTime * 0.5) * 0.12
            bodyNode?.alpha = CGFloat(0.88 + alphaPhase)
        }

        // === SAGE WISDOM PARTICLES ORBIT ===
        if currentStage >= .sage {
            particlesNode?.zRotation += CGFloat(deltaTime * 0.5)
        }

        // === NOISE IDLE — organic micro-movements ===
        updateNoiseIdle()

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

        // === WISE BEARD SWAY (Apex) ===
        for (i, strand) in beardStrandNodes.enumerated() {
            // Each strand sways at a different rate with gentle, flowing motion
            let phase = breathingTime + Double(i) * 0.7
            let sway = 0.12 * CGFloat(sin(phase * 2.0 * .pi / 3.5))
            strand.zRotation = sway
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
    /// Apply subtle per-frame micro-movements to body parts using layered sine waves.
    /// Each part has a different frequency and phase offset so they never move in sync.
    private func updateNoiseIdle() {
        // Amplitude scaling: 1.0 normal, 0.1 sleeping
        let scale: CGFloat = isSleeping ? 0.1 : 1.0
        let t = CGFloat(breathingTime)

        // Compute new offsets
        var offsets: [CGFloat] = []
        for i in 0..<6 {
            offsets.append(noiseAmps[i] * scale
                * CGFloat(sin(2.0 * .pi * noiseFreqs[i] * t + noisePhases[i])))
        }

        // Subtract previous offsets, add new ones (prevents accumulation)
        bodyNode?.position.y += offsets[0] - prevNoiseOffsets[0]
        headNode?.position.y += offsets[1] - prevNoiseOffsets[1]
        earLeftController?.node.zRotation += offsets[2] - prevNoiseOffsets[2]
        earRightController?.node.zRotation += offsets[3] - prevNoiseOffsets[3]
        whiskerLeftController?.node.zRotation += offsets[4] - prevNoiseOffsets[4]
        whiskerRightController?.node.zRotation += offsets[5] - prevNoiseOffsets[5]

        prevNoiseOffsets = offsets
    }

    private func updateBreathing(deltaTime: TimeInterval) {
        breathingTime += deltaTime

        let amplitude = isSleeping
            ? breathAmplitudeSleep
            : breathAmplitudeAwake
        let period = breathPeriodOverride ?? (isSleeping
            ? breathPeriodSleep
            : breathPeriodAwake)

        // Asymmetric breathing: inhale 40% (faster, ease-in), exhale 60% (slower, ease-out)
        // More organic than pure sine — like a real cat breathing
        let phase = CGFloat((breathingTime.truncatingRemainder(dividingBy: period)) / period)
        let breathValue: CGFloat
        if phase < 0.4 {
            // Inhale: map [0, 0.4] to [0, 1] with quadratic ease-in
            let t = phase / 0.4
            breathValue = t * t
        } else {
            // Exhale: map [0.4, 1.0] to [1, 0] with quadratic ease-out
            let t = (phase - 0.4) / 0.6
            breathValue = 1.0 - t * t
        }
        let breathScale = 1.0 + amplitude * breathValue

        // === BODY POSE COMPOSE — the single compose point ===
        // (body-pose-pipeline.md §5 + §6, retargeted per WO-19 §1 from
        // `bodyNode` alone to `pelvisNode` — the new rig root every part
        // reparents under, so the whole assembled creature inherits this
        // write instead of only the torso silhouette). Everything the
        // behavior stack resolves for `bodyState` lands here, composed —
        // not clobbering — with breathing/drop-hop. Nothing outside this
        // function may write pelvisNode's transform.
        let pose = bodyPoseController?.currentPose ?? BodyPoseTuple.identity
        let (finalYScale, finalXScale) = CreatureNode.composedBodyScale(
            breathScale: breathScale, dropHopSquash: dropHopSquash,
            poseYScale: pose.yScale, poseXScale: pose.xScale,
            velocityY: physicsVelocityY
        )
        pelvisNode?.yScale = finalYScale
        pelvisNode?.xScale = finalXScale

        if currentStage == .drop {
            // Apply drop hop Y offset (absolute, not additive), composed
            // with the pose's own yOffset on top.
            pelvisNode?.position.y = dropHopOffset + pose.yOffset
        } else {
            pelvisNode?.position.y = pose.yOffset
        }
        if currentStage != .egg {
            pelvisNode?.zRotation = pose.zRotation

            // === PROPORTIONAL APPENDAGE-FOLLOW (WO-19 sub-part 2, REVISE) ===
            // spineChestNode ALREADY inherits 100% of pelvis's zRotation
            // via SpriteKit's parent-child propagation — chestFollowFactor
            // is the TOTAL fraction of pose.zRotation the chest/head should
            // carry (<= 1.0), so the write here is a COMPENSATION against
            // that already-inherited 100%, not an addition on top of it
            // (an earlier version added on top, over-rotating the head
            // PAST the torso — e.g. roll_side composed to 130% — fixed
            // here per Mack's catch). This is THE fix for the "torso
            // balloons, head barely nudges" gap: the head's dominant
            // motion comes from inheritance (spine/pelvis carries it) plus
            // this small trailing compensation, and the flat `headOffset`
            // delta below becomes a small residual accent on top, not the
            // whole compensation.
            spineChestNode?.zRotation = pose.zRotation * (SkeletonGeometry.chestFollowFactor - 1.0)
        }
        // At Egg, leave pelvisNode/spineChestNode zRotation untouched here
        // (matches the file's defensive `?.` convention used everywhere
        // else in this function) — `bodyPoseController` is nil at Egg
        // (gated `stage >= .drop`) so this branch is presently unreachable
        // there anyway; egg-wobble keeps writing `bodyNode.zRotation`
        // directly (see that call site's own guard) since pelvisNode never
        // moves at Egg regardless.

        // Residual head accent — still additive (subtract-previous-add-new
        // delta pattern, matching updateNoiseIdle's convention), but now
        // riding ON TOP of spineChestNode's own chestCurve rotation above
        // instead of being the head's ENTIRE compensation, since headNode
        // is spineChestNode's child (WO-19 §1) and inherits that motion
        // for free.
        headNode?.position.y += pose.headOffset - previousPoseHeadOffset
        previousPoseHeadOffset = pose.headOffset

        [pawFLController, pawFRController, pawBLController, pawBRController]
            .forEach { $0?.node.alpha = pose.pawAlpha }
    }

    /// Pure compose math for §5's global velocity squash-stretch pass,
    /// composed multiplicatively with breathing/drop-hop/pose at the
    /// single compose point above. Extracted as a static helper — mirrors
    /// `PushlingScene.composedCreatureY`'s pattern — so it's covered by a
    /// deterministic unit test without a live SKNode tree.
    static func composedBodyScale(
        breathScale: CGFloat, dropHopSquash: CGFloat,
        poseYScale: CGFloat, poseXScale: CGFloat,
        velocityY: CGFloat
    ) -> (yScale: CGFloat, xScale: CGFloat) {
        let velocityStretch = clamp(velocityY * 0.003, min: -0.15, max: 0.15)
        let rawYScale = breathScale * dropHopSquash * poseYScale * (1.0 + velocityStretch)
        let yScale = clamp(rawYScale, min: 0.6, max: 1.3)
        // Clamp the FULL product (reciprocal-sqrt * pose.xScale), not just
        // the reciprocal-sqrt term alone — otherwise a pose with xScale > 1
        // (e.g. roll_side's 1.30) can push the composed xScale past the
        // hard [0.6, 1.3] silhouette cap (grounds[1]). This resolves the
        // canon §5-vs-§6 contradiction in favor of §5's ratified hard cap.
        let xScale = clamp((1.0 / sqrt(yScale)) * poseXScale, min: 0.6, max: 1.3)
        return (yScale, xScale)
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

    /// Builds the pelvis-chain skeleton (WO-19 §1) and reparents every
    /// stage-authored node under it, per the WO-19 plan's regression
    /// census: `aura`/`particles` stay root-level siblings (by ruling —
    /// confirmed independent of torso pose, never adjusted per-frame to
    /// track `bodyNode`'s deformation); `body`/`coreGlow`/`head`/`tail`/
    /// all 4 paws reparent under the new chain.
    ///
    /// Every reparented node is RE-BASED (Correction 1): `newLocalPosition
    /// = oldAbsolutePosition - jointAbsolutePosition`, computed generically
    /// via `SkeletonGeometry.rebase`, so each part's effective absolute
    /// (world-at-rest) position is unchanged regardless of where the new
    /// joint node sits — this is what makes the rest-identity gate provable
    /// rather than assumed, and it works uniformly across all 6 stages
    /// without touching a single number in StageRenderer.swift (every
    /// formula below reads the node's OWN already-authored `.position`,
    /// already trait-scaled, rather than duplicating stage constants here).
    private func addBodyParts(_ nodes: StageRenderer.StageNodes) {
        // Add in z-order (back to front)
        if let aura = nodes.aura { addChild(aura); auraNode = aura }

        // === Pelvis — the compose-point root (WO-19 §1) ===
        // Sits at (0,0): the SAME local origin every stage already builds
        // bodyNode at (no `buildXXX` function ever sets `body.position`)
        // — not an arbitrary choice, it's where the single rigid torso
        // node already lived.
        let pelvisAbsolute = CGPoint.zero
        let pelvis = SKNode()
        pelvis.name = "pelvis"
        pelvis.position = pelvisAbsolute
        addChild(pelvis)
        pelvisNode = pelvis

        // Body — re-based under pelvis (nets to identity here, since
        // pelvis coincides with the old root origin body was always built
        // at — shown by the subtraction, not assumed).
        let bodyOldAbsolute = nodes.body.position
        nodes.body.position = SkeletonGeometry.rebase(bodyOldAbsolute, relativeTo: pelvisAbsolute)
        pelvis.addChild(nodes.body)
        bodyNode = nodes.body

        // Core glow — same treatment (WO-19 census: was a root sibling;
        // reparenting means it now rides the torso's own pose instead of
        // sitting at a fixed root offset while the torso squashes/curls).
        if let cg = nodes.coreGlow {
            let cgOldAbsolute = cg.position
            cg.position = SkeletonGeometry.rebase(cgOldAbsolute, relativeTo: pelvisAbsolute)
            pelvis.addChild(cg)
            coreGlowNode = cg
        }

        // Collect additional tail nodes (Apex multi-tail) — these are
        // children of BODY itself, untouched by body's own reparenting.
        additionalTailNodes.removeAll()
        for child in nodes.body.children {
            if let shape = child as? SKShapeNode,
               let name = shape.name, name.hasPrefix("tail_extra_") {
                additionalTailNodes.append(shape)
            }
        }

        // === Spine Chest — child of pelvis (WO-19 §1) ===
        // Placed halfway between pelvis and the stage's own authored head
        // position (SkeletonGeometry.chestPivotFactor) — an intermediate
        // joint, not a pass-through, per Correction 1.
        let headOldAbsolute = nodes.head.position
        let spineChestAbsolute = SkeletonGeometry.spineChestPosition(oldHeadPosition: headOldAbsolute)
        let spineChest = SKNode()
        spineChest.name = "spine_chest"
        spineChest.position = SkeletonGeometry.rebase(spineChestAbsolute, relativeTo: pelvisAbsolute)
        pelvis.addChild(spineChest)
        spineChestNode = spineChest

        // Head — re-based under spineChest.
        nodes.head.position = SkeletonGeometry.rebase(headOldAbsolute, relativeTo: spineChestAbsolute)
        spineChest.addChild(nodes.head)
        headNode = nodes.head

        // Collect beard strand nodes (Apex wise beard) — children of HEAD
        // itself, untouched by head's own reparenting.
        beardStrandNodes.removeAll()
        for child in nodes.head.children {
            if let beardGroup = child as? SKNode,
               beardGroup.name == "wise_beard" {
                for strand in beardGroup.children {
                    if let shape = strand as? SKShapeNode,
                       let name = shape.name, name.hasPrefix("beard_strand_") {
                        beardStrandNodes.append(shape)
                    }
                }
            }
        }

        // === Shoulders — front-leg pivots, children of spineChest ===
        // Only built where a front paw exists (Egg/Drop have none).
        // Inert this pass — WO-20 wires angular swing later.
        let beltY = SkeletonGeometry.beltY(
            stageHeight: StageConfiguration.all[currentStage]!.size.height
        )
        if let fl = nodes.pawFL {
            let jointAbsolute = CGPoint(x: fl.position.x, y: beltY)
            let shoulderL = SKNode()
            shoulderL.name = "shoulder_l"
            shoulderL.position = SkeletonGeometry.rebase(jointAbsolute, relativeTo: spineChestAbsolute)
            spineChest.addChild(shoulderL)
            shoulderLNode = shoulderL

            fl.position = SkeletonGeometry.rebase(fl.position, relativeTo: jointAbsolute)
            shoulderL.addChild(fl)
        }
        if let fr = nodes.pawFR {
            let jointAbsolute = CGPoint(x: fr.position.x, y: beltY)
            let shoulderR = SKNode()
            shoulderR.name = "shoulder_r"
            shoulderR.position = SkeletonGeometry.rebase(jointAbsolute, relativeTo: spineChestAbsolute)
            spineChest.addChild(shoulderR)
            shoulderRNode = shoulderR

            fr.position = SkeletonGeometry.rebase(fr.position, relativeTo: jointAbsolute)
            shoulderR.addChild(fr)
        }

        // === Hips — rear-leg pivots, children of PELVIS directly (not
        // spineChest — rear legs stay coupled to the same node the tail
        // attaches to, matching real quadruped anatomy). ===
        if let bl = nodes.pawBL {
            let jointAbsolute = CGPoint(x: bl.position.x, y: beltY)
            let hipL = SKNode()
            hipL.name = "hip_l"
            hipL.position = SkeletonGeometry.rebase(jointAbsolute, relativeTo: pelvisAbsolute)
            pelvis.addChild(hipL)
            hipLNode = hipL

            bl.position = SkeletonGeometry.rebase(bl.position, relativeTo: jointAbsolute)
            hipL.addChild(bl)
        }
        if let br = nodes.pawBR {
            let jointAbsolute = CGPoint(x: br.position.x, y: beltY)
            let hipR = SKNode()
            hipR.name = "hip_r"
            hipR.position = SkeletonGeometry.rebase(jointAbsolute, relativeTo: pelvisAbsolute)
            pelvis.addChild(hipR)
            hipRNode = hipR

            br.position = SkeletonGeometry.rebase(br.position, relativeTo: jointAbsolute)
            hipR.addChild(br)
        }

        // === Tail Base — child of pelvis (WO-19 §1) ===
        // Placed exactly at the tail's own old attach point (the tail
        // doesn't move at rest; the joint is inserted AT it, not near it).
        // `nodes.tail` (the single rigid shape) is used ONLY as the
        // placement oracle here — WO-19 sub-part 2 renders the segmented
        // chain (`nodes.tailSegments`) instead, wiring the dormant
        // `SegmentedTailController` at this same joint per
        // emotional-body-language.md's swap-point note. `nodes.tail`
        // itself is never added to the tree.
        if let tail = nodes.tail, let segments = nodes.tailSegments, !segments.isEmpty {
            let tailOldAbsolute = tail.position
            let tailBase = SKNode()
            tailBase.name = "tail_base"
            tailBase.position = SkeletonGeometry.rebase(tailOldAbsolute, relativeTo: pelvisAbsolute)
            pelvis.addChild(tailBase)
            tailBaseNode = tailBase

            let base = segments[0]
            base.position = SkeletonGeometry.rebase(tailOldAbsolute, relativeTo: tailOldAbsolute)
            tailBase.addChild(base)
            tailNode = base
        }

        // === Root-level siblings, unchanged by ruling ===
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

        // Tail — SegmentedTailController (WO-19 sub-part 2 swap; see this
        // file's `tailController` doc comment). `addBodyParts` already
        // reparented `segments[0]` under `tailBaseNode` — this only wires
        // the behavior on top of that already-correct structure.
        //
        // Known approximation (Rook/Mack finding, shipped as-is this
        // pass): the spring-physics chain tracks "world angle" assuming a
        // non-rotating parent (its own header comment predates this rig).
        // `tailBaseNode` now sits inside a `pelvisNode` that DOES rotate
        // during roll_side/spin/flip, so the spring's internal angle
        // bookkeeping doesn't compound with the live parent rotation — the
        // tail still moves and still trails with follow-through, just not
        // with perfectly composed world angles during a simultaneous
        // body-roll. Not fixed this pass; revisit only if it visibly reads
        // wrong in the parade re-run.
        if config.hasTail, let segments = nodes.tailSegments,
           let lengths = nodes.tailSegmentLengths,
           let curveFactor = nodes.tailCurveFactor {
            let tc = SegmentedTailController(segments: segments,
                                              segmentLengths: lengths,
                                              curveFactor: curveFactor)
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

        // Paws — `restingPoint` reads each node's OWN current `.position`,
        // not a fresh `StageRenderer.pawRestPositions(...)` recomputation.
        // WO-19 §1's `addBodyParts` already re-based that position relative
        // to the paw's new shoulder/hip parent (runs before this function);
        // recomputing the OLD root-relative absolute here would be stale
        // and would silently reintroduce the exact "paw jumps to 2x its
        // rest offset" bug `PawController.setState("ground", ...)` (called
        // from `applyDefaultStates()` right after this) resets `.position`
        // to `restingPoint` on every "ground" transition.
        if config.hasPaws {
            if let fl = nodes.pawFL {
                let c = PawController(pawNode: fl, position: .frontLeft,
                                       restingPoint: fl.position)
                c.cyclePhaseOffset = 0  // FL + BR together
                pawFLController = c
            }
            if let fr = nodes.pawFR {
                let c = PawController(pawNode: fr, position: .frontRight,
                                       restingPoint: fr.position)
                c.cyclePhaseOffset = .pi  // FR + BL together (offset)
                pawFRController = c
            }
            if let bl = nodes.pawBL {
                let c = PawController(pawNode: bl, position: .backLeft,
                                       restingPoint: bl.position)
                c.cyclePhaseOffset = .pi  // Diagonal gait
                pawBLController = c
            }
            if let br = nodes.pawBR {
                let c = PawController(pawNode: br, position: .backRight,
                                       restingPoint: br.position)
                c.cyclePhaseOffset = 0
                pawBRController = c
            }
        }

        // Body pose — gated stage >= .drop per the WO-6 dispatch
        // (see BodyPoseController's header comment for the divergence
        // note against §3's Egg amplitude row).
        if stage >= .drop {
            bodyPoseController = BodyPoseController(stage: stage)
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
        bodyPoseController = nil
        previousPoseHeadOffset = 0
        additionalTailNodes.removeAll()
        beardStrandNodes.removeAll()
        bodyNode = nil
        coreGlowNode = nil
        headNode = nil
        auraNode = nil
        tailNode = nil
        particlesNode = nil
        pelvisNode = nil
        spineChestNode = nil
        shoulderLNode = nil
        shoulderRNode = nil
        hipLNode = nil
        hipRNode = nil
        tailBaseNode = nil
    }

    private func applyDefaultStates() {
        earLeftController?.setState("neutral", duration: 0)
        earRightController?.setState("neutral", duration: 0)
        // Sage+ has half-lidded "wise" default eyes
        let defaultEyeState = currentStage >= .sage ? "half" : "open"
        eyeLeftController?.setState(defaultEyeState, duration: 0)
        eyeRightController?.setState(defaultEyeState, duration: 0)
        tailController?.setState("sway", duration: 0)
        mouthController?.setState("closed", duration: 0)
        whiskerLeftController?.setState("neutral", duration: 0)
        whiskerRightController?.setState("neutral", duration: 0)
        pawFLController?.setState("ground", duration: 0)
        pawFRController?.setState("ground", duration: 0)
        pawBLController?.setState("ground", duration: 0)
        pawBRController?.setState("ground", duration: 0)
        bodyPoseController?.setState("stand", duration: 0)
    }
}
