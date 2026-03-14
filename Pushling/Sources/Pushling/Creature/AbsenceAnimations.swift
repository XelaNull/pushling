// AbsenceAnimations.swift — Graduated wake animations + late-night lantern
//
// Wake animations scale with absence duration:
//   <1hr:   Quick stretch (1s)
//   1-8hr:  Full yawn + stretch + knead (3s)
//   8-24hr: Big yawn, dramatic stretch, shake head, look around (4s)
//   1-3d:   Stretch + sniff + cautious walk
//   3-7d:   Cobweb particles, excited run
//   7+d:    Full cobweb emergence, zoomies, extreme happiness
//
// Late-night lantern (P2-T3-10):
//   After 10PM if developer is still coding, creature pulls out a tiny lantern.
//   Solidarity, not judgment.

import SpriteKit

// MARK: - Absence Category

/// Categorizes the duration of absence for animation selection.
enum AbsenceCategory {
    case brief          // < 1 hour
    case shortBreak     // 1-8 hours
    case overnight      // 8-24 hours
    case fewDays        // 1-3 days
    case longAbsence    // 3-7 days
    case extended       // 7+ days

    static func from(seconds: TimeInterval) -> AbsenceCategory {
        let hours = seconds / 3600.0
        switch hours {
        case ..<1:    return .brief
        case ..<8:    return .shortBreak
        case ..<24:   return .overnight
        case ..<72:   return .fewDays
        case ..<168:  return .longAbsence
        default:      return .extended
        }
    }

    /// Animation duration for this absence category.
    var animationDuration: TimeInterval {
        switch self {
        case .brief:        return 1.0
        case .shortBreak:   return 3.0
        case .overnight:    return 4.0
        case .fewDays:      return 5.0
        case .longAbsence:  return 6.0
        case .extended:     return 8.0
        }
    }

    /// Description for journal entry.
    var journalDescription: String {
        switch self {
        case .brief:        return "quick stretch"
        case .shortBreak:   return "morning wake"
        case .overnight:    return "full day away"
        case .fewDays:      return "curious return"
        case .longAbsence:  return "excited reunion"
        case .extended:     return "joyful reunion"
        }
    }
}

// MARK: - Animation Keyframe

/// A single keyframe in an absence wake animation.
struct AnimationKeyframe {
    /// Time (in seconds from animation start) when this keyframe activates.
    let time: TimeInterval

    /// The LayerOutput to apply at this keyframe.
    let output: LayerOutput

    /// Optional metadata for special effects (cobwebs, particles, etc.).
    let metadata: [String: Any]

    init(time: TimeInterval, output: LayerOutput,
         metadata: [String: Any] = [:]) {
        self.time = time
        self.output = output
        self.metadata = metadata
    }
}

// MARK: - LayerOutput Builder

/// Helper to build LayerOutput with named parameters in any order.
/// Swift memberwise initializers require declaration order; this avoids that.
private func makeOutput(
    walkSpeed: CGFloat? = nil,
    facing: Direction? = nil,
    bodyState: String? = nil,
    earLeftState: String? = nil,
    earRightState: String? = nil,
    eyeLeftState: String? = nil,
    eyeRightState: String? = nil,
    tailState: String? = nil,
    mouthState: String? = nil,
    whiskerState: String? = nil,
    auraState: String? = nil,
    pawStates: [String: String]? = nil
) -> LayerOutput {
    LayerOutput(
        facing: facing,
        walkSpeed: walkSpeed,
        bodyState: bodyState,
        earLeftState: earLeftState,
        earRightState: earRightState,
        eyeLeftState: eyeLeftState,
        eyeRightState: eyeRightState,
        tailState: tailState,
        mouthState: mouthState,
        whiskerState: whiskerState,
        auraState: auraState,
        pawStates: pawStates
    )
}

// MARK: - Absence Wake Animation

/// Generates LayerOutput sequences for wake animations based on absence.
/// Used by the AutonomousLayer on wake-up.
enum AbsenceWakeAnimation {

    /// Generate the wake animation outputs for a given absence category.
    static func keyframes(
        for category: AbsenceCategory,
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        switch category {
        case .brief:        return briefWake(stage: stage)
        case .shortBreak:   return shortBreakWake(stage: stage)
        case .overnight:    return overnightWake(stage: stage)
        case .fewDays:      return fewDaysWake(stage: stage)
        case .longAbsence:  return longAbsenceWake(stage: stage)
        case .extended:     return extendedWake(stage: stage)
        }
    }

    // MARK: - Brief (<1hr) — Quick Stretch

    private static func briefWake(stage: GrowthStage) -> [AnimationKeyframe] {
        [
            AnimationKeyframe(time: 0.0, output: makeOutput(
                eyeLeftState: "open",
                eyeRightState: "open"
            )),
            AnimationKeyframe(time: 0.3, output: makeOutput(
                bodyState: "stretch",
                tailState: stage >= .critter ? "high" : nil
            )),
            AnimationKeyframe(time: 0.8, output: makeOutput(
                bodyState: "stand",
                tailState: stage >= .critter ? "sway" : nil
            )),
        ]
    }

    // MARK: - Short Break (1-8hr) — Yawn + Stretch + Knead

    private static func shortBreakWake(
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        var frames: [AnimationKeyframe] = [
            // Eyes squint open, ears droop
            AnimationKeyframe(time: 0.0, output: makeOutput(
                earLeftState: stage >= .critter ? "droop" : nil,
                earRightState: stage >= .critter ? "droop" : nil,
                eyeLeftState: "half",
                eyeRightState: "half"
            )),
            // Yawn
            AnimationKeyframe(time: 0.5, output: makeOutput(
                eyeLeftState: "closed",
                eyeRightState: "closed",
                mouthState: stage >= .critter ? "yawn" : nil
            )),
            // Stretch
            AnimationKeyframe(time: 1.2, output: makeOutput(
                bodyState: "stretch",
                earLeftState: stage >= .critter ? "neutral" : nil,
                earRightState: stage >= .critter ? "neutral" : nil,
                eyeLeftState: "open",
                eyeRightState: "open",
                mouthState: stage >= .critter ? "closed" : nil
            )),
            // Stand
            AnimationKeyframe(time: 2.0, output: makeOutput(
                bodyState: "stand",
                tailState: stage >= .critter ? "sway" : nil
            )),
        ]

        // Kneading if Critter+
        if stage >= .critter {
            frames.append(AnimationKeyframe(time: 2.2, output: makeOutput(
                pawStates: ["fl": "knead", "fr": "knead",
                            "bl": "ground", "br": "ground"]
            )))
            frames.append(AnimationKeyframe(time: 2.8, output: makeOutput(
                pawStates: ["fl": "ground", "fr": "ground",
                            "bl": "ground", "br": "ground"]
            )))
        }

        return frames
    }

    // MARK: - Overnight (8-24hr) — Big Yawn, Dramatic Stretch

    private static func overnightWake(
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        [
            // Sleeping
            AnimationKeyframe(time: 0.0, output: makeOutput(
                bodyState: "sleep_curl",
                eyeLeftState: "closed",
                eyeRightState: "closed",
                tailState: stage >= .critter ? "wrap" : nil
            )),
            // Stir
            AnimationKeyframe(time: 0.5, output: makeOutput(
                eyeLeftState: "half",
                eyeRightState: "closed"
            )),
            // Big yawn
            AnimationKeyframe(time: 1.0, output: makeOutput(
                bodyState: "stretch",
                eyeLeftState: "closed",
                eyeRightState: "closed",
                tailState: stage >= .critter ? "high" : nil,
                mouthState: stage >= .critter ? "yawn" : nil
            )),
            // Dramatic stretch
            AnimationKeyframe(time: 2.0, output: makeOutput(
                bodyState: "stretch",
                earLeftState: stage >= .critter ? "perk" : nil,
                earRightState: stage >= .critter ? "perk" : nil,
                eyeLeftState: "open",
                eyeRightState: "open",
                mouthState: stage >= .critter ? "closed" : nil,
                pawStates: stage >= .critter
                    ? ["fl": "extend", "fr": "extend",
                       "bl": "ground", "br": "ground"]
                    : nil
            )),
            // Shake head, look around
            AnimationKeyframe(time: 3.0, output: makeOutput(
                bodyState: "stand",
                earLeftState: stage >= .critter ? "twitch" : nil,
                earRightState: stage >= .critter ? "twitch" : nil,
                tailState: stage >= .critter ? "sway" : nil,
                pawStates: stage >= .critter
                    ? ["fl": "ground", "fr": "ground",
                       "bl": "ground", "br": "ground"]
                    : nil
            )),
            // Normal
            AnimationKeyframe(time: 3.5, output: makeOutput(
                earLeftState: stage >= .critter ? "neutral" : nil,
                earRightState: stage >= .critter ? "neutral" : nil
            )),
        ]
    }

    // MARK: - Few Days (1-3d) — Cautious Return

    private static func fewDaysWake(
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        var frames = overnightWake(stage: stage)

        // Cautious sniffing
        frames.append(AnimationKeyframe(time: 3.8, output: makeOutput(
            bodyState: "crouch",
            earLeftState: stage >= .critter ? "perk" : nil,
            earRightState: stage >= .critter ? "perk" : nil,
            eyeLeftState: "wide",
            eyeRightState: "wide",
            whiskerState: stage >= .beast ? "forward" : nil
        )))

        // Stand up and look around
        frames.append(AnimationKeyframe(time: 4.5, output: makeOutput(
            bodyState: "stand",
            earLeftState: stage >= .critter ? "neutral" : nil,
            earRightState: stage >= .critter ? "neutral" : nil,
            eyeLeftState: "open",
            eyeRightState: "open",
            whiskerState: stage >= .beast ? "neutral" : nil
        )))

        return frames
    }

    // MARK: - Long Absence (3-7d) — Cobwebs + Excited Run

    private static func longAbsenceWake(
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        [
            // Sleeping with cobwebs
            AnimationKeyframe(time: 0.0, output: makeOutput(
                bodyState: "sleep_curl",
                eyeLeftState: "closed",
                eyeRightState: "closed"
            ), metadata: ["cobwebs": true]),

            // Stir — shake off cobwebs
            AnimationKeyframe(time: 1.0, output: makeOutput(
                bodyState: "stretch",
                eyeLeftState: "half",
                eyeRightState: "half"
            ), metadata: ["shake_cobwebs": true]),

            // Eyes wide — recognize developer
            AnimationKeyframe(time: 2.0, output: makeOutput(
                earLeftState: stage >= .critter ? "perk" : nil,
                earRightState: stage >= .critter ? "perk" : nil,
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: stage >= .critter ? "poof" : nil
            )),

            // Excited! Tail high
            AnimationKeyframe(time: 2.5, output: makeOutput(
                bodyState: "stand",
                eyeLeftState: "happy",
                eyeRightState: "happy",
                tailState: stage >= .critter ? "high" : nil
            )),

            // Run across bar!
            AnimationKeyframe(time: 3.0, output: makeOutput(
                walkSpeed: 50,
                earLeftState: stage >= .critter ? "wild" : nil,
                earRightState: stage >= .critter ? "wild" : nil,
                eyeLeftState: "happy",
                eyeRightState: "happy",
                tailState: stage >= .critter ? "poof" : nil
            )),

            // Slow down
            AnimationKeyframe(time: 5.0, output: makeOutput(
                walkSpeed: 0,
                bodyState: "stand",
                earLeftState: stage >= .critter ? "neutral" : nil,
                earRightState: stage >= .critter ? "neutral" : nil,
                tailState: stage >= .critter ? "sway" : nil
            )),
        ]
    }

    // MARK: - Extended (7+d) — Full Cobweb Emergence + Zoomies

    private static func extendedWake(
        stage: GrowthStage
    ) -> [AnimationKeyframe] {
        [
            // Deep sleep with heavy cobwebs
            AnimationKeyframe(time: 0.0, output: makeOutput(
                bodyState: "sleep_curl",
                eyeLeftState: "closed",
                eyeRightState: "closed"
            ), metadata: ["heavy_cobwebs": true]),

            // Slowly stir
            AnimationKeyframe(time: 1.5, output: makeOutput(
                eyeLeftState: "half",
                eyeRightState: "closed"
            )),

            // Shake vigorously — cobwebs fly off
            AnimationKeyframe(time: 2.0, output: makeOutput(
                bodyState: "stretch",
                mouthState: stage >= .critter ? "yawn" : nil
            ), metadata: ["shake_cobwebs_heavy": true]),

            // Recognize developer — EXTREME happiness
            AnimationKeyframe(time: 3.0, output: makeOutput(
                earLeftState: stage >= .critter ? "perk" : nil,
                earRightState: stage >= .critter ? "perk" : nil,
                eyeLeftState: "wide",
                eyeRightState: "wide",
                tailState: stage >= .critter ? "poof" : nil,
                mouthState: stage >= .critter ? "smile" : nil
            )),

            // ZOOMIES — full speed across bar
            AnimationKeyframe(time: 3.5, output: makeOutput(
                walkSpeed: 70,
                earLeftState: stage >= .critter ? "wild" : nil,
                earRightState: stage >= .critter ? "wild" : nil,
                eyeLeftState: "happy",
                eyeRightState: "happy",
                tailState: stage >= .critter ? "poof" : nil
            )),

            // Turn around and zoom back
            AnimationKeyframe(time: 5.5, output: makeOutput(
                walkSpeed: 70,
                facing: .left
            )),

            // Slow down, overjoyed
            AnimationKeyframe(time: 7.0, output: makeOutput(
                walkSpeed: 0,
                bodyState: "stand",
                earLeftState: stage >= .critter ? "neutral" : nil,
                earRightState: stage >= .critter ? "neutral" : nil,
                eyeLeftState: "happy",
                eyeRightState: "happy",
                tailState: stage >= .critter ? "wag" : nil,
                mouthState: stage >= .critter ? "smile" : nil
            )),

            // Calm down
            AnimationKeyframe(time: 7.5, output: makeOutput(
                eyeLeftState: "open",
                eyeRightState: "open",
                tailState: stage >= .critter ? "sway" : nil,
                mouthState: stage >= .critter ? "closed" : nil
            )),
        ]
    }
}

// MARK: - Late-Night Lantern

/// Manages the late-night lantern behavior (P2-T3-10).
/// After 10PM, if the developer is still coding, the creature produces
/// a tiny lantern. Solidarity, not judgment.
final class LateNightLantern {

    // MARK: - State

    private(set) var isActive = false
    private var lanternNode: SKShapeNode?
    private var glowNode: SKShapeNode?
    private var bobTime: TimeInterval = 0

    /// Cooldown after dismissal (30 minutes).
    private var cooldownUntil: Date?

    /// Whether the creature has curled to sleep with the lantern.
    private(set) var isSleepingWithLantern = false

    /// Timer for idle detection (sleep after 10 min idle).
    private var idleTimer: TimeInterval = 0

    // MARK: - Constants

    private static let activationHour = 22  // 10 PM
    private static let dismissHour = 5      // 5 AM
    private static let cooldownSeconds: TimeInterval = 30 * 60  // 30 min
    private static let sleepIdleSeconds: TimeInterval = 10 * 60  // 10 min

    // MARK: - Update

    /// Called each frame to manage lantern state.
    func update(deltaTime: TimeInterval, hour: Int,
                isDeveloperActive: Bool, creatureNode: SKNode) {

        // Check if we should dismiss
        if isActive && (hour >= Self.dismissHour && hour < Self.activationHour) {
            dismiss()
            return
        }

        // Check cooldown
        if let cooldown = cooldownUntil, Date() < cooldown {
            return
        }

        // Activation check
        if !isActive && shouldActivate(hour: hour,
                                        isDeveloperActive: isDeveloperActive) {
            activate(on: creatureNode)
        }

        // Update lantern visuals
        if isActive {
            updateLantern(deltaTime: deltaTime,
                           isDeveloperActive: isDeveloperActive)
        }
    }

    // MARK: - Activation

    private func shouldActivate(hour: Int,
                                 isDeveloperActive: Bool) -> Bool {
        let isLateNight = hour >= Self.activationHour
            || hour < Self.dismissHour
        return isLateNight && isDeveloperActive
    }

    private func activate(on creatureNode: SKNode) {
        isActive = true
        idleTimer = 0
        isSleepingWithLantern = false

        let lantern = SKShapeNode(rectOf: CGSize(width: 2, height: 3),
                                    cornerRadius: 0.5)
        lantern.fillColor = PushlingPalette.gilt
        lantern.strokeColor = .clear
        lantern.alpha = 0.9
        lantern.name = "lantern"
        lantern.position = CGPoint(x: 5, y: 2)
        lantern.zPosition = 15

        let glow = SKShapeNode(circleOfRadius: 7.5)
        glow.fillColor = PushlingPalette.gilt.withAlphaComponent(0.1)
        glow.strokeColor = .clear
        glow.name = "lantern_glow"
        glow.zPosition = -1
        lantern.addChild(glow)

        creatureNode.addChild(lantern)
        self.lanternNode = lantern
        self.glowNode = glow

        NSLog("[Pushling/Lantern] Late-night lantern activated")
    }

    // MARK: - Lantern Update

    private func updateLantern(deltaTime: TimeInterval,
                                isDeveloperActive: Bool) {
        guard let lantern = lanternNode else { return }

        bobTime += deltaTime
        let bobY = 2.0 + CGFloat(sin(bobTime * 1.5)) * 0.5
        lantern.position.y = bobY

        if isDeveloperActive {
            idleTimer = 0
            if isSleepingWithLantern {
                isSleepingWithLantern = false
                lantern.alpha = 0.9
                glowNode?.alpha = 1.0
            }
        } else {
            idleTimer += deltaTime
            if idleTimer > Self.sleepIdleSeconds && !isSleepingWithLantern {
                isSleepingWithLantern = true
                lantern.alpha = 0.4
                glowNode?.fillColor = PushlingPalette.gilt
                    .withAlphaComponent(0.05)
                NSLog("[Pushling/Lantern] Sleeping with lantern")
            }
        }
    }

    // MARK: - Dismiss

    func dismiss() {
        guard isActive else { return }

        isActive = false
        isSleepingWithLantern = false
        cooldownUntil = Date().addingTimeInterval(Self.cooldownSeconds)

        lanternNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ]))
        lanternNode = nil
        glowNode = nil

        NSLog("[Pushling/Lantern] Lantern dismissed")
    }

    func forceRemove() {
        lanternNode?.removeFromParent()
        lanternNode = nil
        glowNode = nil
        isActive = false
        isSleepingWithLantern = false
    }
}

// MARK: - Absence Tracker

/// Tracks last activity time for absence-based wake animation selection.
enum AbsenceTracker {

    static func calculate(
        lastActivityStr: String?
    ) -> (category: AbsenceCategory, seconds: TimeInterval) {
        guard let str = lastActivityStr else {
            return (.brief, 0)
        }

        let formatter = ISO8601DateFormatter()
        guard let lastDate = formatter.date(from: str) else {
            return (.brief, 0)
        }

        let elapsed = Date().timeIntervalSince(lastDate)
        guard elapsed > 0 else { return (.brief, 0) }

        return (AbsenceCategory.from(seconds: elapsed), elapsed)
    }

    static func formatDuration(seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let minutes = Int(seconds / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}
