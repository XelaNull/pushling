// FirstWordCeremony.swift — The moment the creature speaks its own name
// One-time milestone at Critter stage, after 10+ commits eaten.
//
// The sequence: pause -> look up -> hesitation -> "...[name]?" -> resume
// Total: 5 seconds. The creature asks if it is itself. It never happens again.
//
// Conditions: Critter stage, 10+ commits, autonomous idle, energy > 30,
// contentment > 40, never triggered before.

import SpriteKit

// MARK: - First Word Ceremony

/// Manages the one-time first-word milestone animation.
/// The creature pauses, looks up, hesitates, and speaks its name as a question.
final class FirstWordCeremony {

    // MARK: - State

    enum Phase {
        case idle          // Not triggered
        case pause         // 0.0-0.5s: Stop walking, freeze
        case lookUp        // 0.5-1.3s: Head tilts up, ears forward, eyes widen
        case hesitation    // 1.3-2.3s: Mouth opens/closes, "..." appears
        case theWord       // 2.3-3.8s: Bubble with "...[name]?"
        case aftermath     // 3.8-5.0s: Blinks, resumes, slight bounce
        case complete      // Done
    }

    private(set) var currentPhase: Phase = .idle
    private var phaseTimer: TimeInterval = 0
    private var creatureName: String = "Pushling"

    /// The speech bubble shown during theWord phase.
    private var wordBubble: SpeechBubbleNode?

    /// The hesitation "..." label.
    private var hesitationLabel: SKLabelNode?

    /// Whether this ceremony has been triggered (prevents re-trigger).
    private(set) var hasTriggered = false

    // MARK: - Dependencies

    private weak var creature: CreatureNode?
    private var completion: (() -> Void)?

    // MARK: - Conditions Check

    /// Check if all conditions for the first word ceremony are met.
    /// - Parameters:
    ///   - stage: Current growth stage.
    ///   - commitsEaten: Total commits eaten since Critter evolution.
    ///   - energy: Emotional energy (0-100).
    ///   - contentment: Emotional contentment (0-100).
    ///   - isIdle: Whether creature is in autonomous idle.
    ///   - hasMilestone: Whether the first_word milestone is already earned.
    /// - Returns: True if all conditions are met.
    static func conditionsMet(
        stage: GrowthStage,
        commitsEaten: Int,
        energy: Double,
        contentment: Double,
        isIdle: Bool,
        hasMilestone: Bool
    ) -> Bool {
        return stage == .critter
            && commitsEaten >= 10
            && energy > 30
            && contentment > 40
            && isIdle
            && !hasMilestone
    }

    // MARK: - Begin

    /// Begin the first word ceremony.
    /// - Parameters:
    ///   - creature: The creature node to animate.
    ///   - name: The creature's name.
    ///   - completion: Called when the ceremony completes.
    func begin(creature: CreatureNode,
               name: String,
               completion: @escaping () -> Void) {
        guard !hasTriggered else { return }
        hasTriggered = true

        self.creature = creature
        self.creatureName = name
        self.completion = completion
        self.currentPhase = .pause
        self.phaseTimer = 0

        NSLog("[Pushling/Speech] First Word Ceremony begins — name: %@", name)
    }

    // MARK: - Per-Frame Update

    /// Update the ceremony animation. Called every frame during the ceremony.
    func update(deltaTime: TimeInterval) {
        guard currentPhase != .idle && currentPhase != .complete else { return }

        phaseTimer += deltaTime

        switch currentPhase {
        case .pause:
            updatePause()
        case .lookUp:
            updateLookUp()
        case .hesitation:
            updateHesitation()
        case .theWord:
            updateTheWord()
        case .aftermath:
            updateAftermath()
        default:
            break
        }
    }

    // MARK: - Phase Updates

    /// Phase 1: Pause (0.0-0.5s) — Stop walking, freeze everything except breathing
    private func updatePause() {
        guard let creature = creature else { return }

        // Creature stops immediately — breathing continues (always does)
        creature.setTailSwayActive(false)
        creature.setWhiskerTwitchesActive(false)

        if phaseTimer >= 0.5 {
            currentPhase = .lookUp
            phaseTimer = 0
        }
    }

    /// Phase 2: Look Up (0.5-1.3s) — Head tilts, ears forward, eyes widen
    private func updateLookUp() {
        guard let creature = creature else { return }

        // Ears snap forward
        creature.earLeftController?.setState("alert", duration: 0.15)
        creature.earRightController?.setState("alert", duration: 0.15)

        // Eyes widen
        creature.eyeLeftController?.setState("wide", duration: 0.15)
        creature.eyeRightController?.setState("wide", duration: 0.15)

        if phaseTimer >= 0.8 {
            currentPhase = .hesitation
            phaseTimer = 0
        }
    }

    /// Phase 3: Hesitation (1.3-2.3s) — Mouth opens/closes, "..." glyph
    private func updateHesitation() {
        guard let creature = creature else { return }

        if phaseTimer < 0.3 {
            // First mouth open
            creature.mouthController?.setState("open_small", duration: 0.15)
        } else if phaseTimer < 0.5 {
            // Close
            creature.mouthController?.setState("closed", duration: 0.1)
        } else if phaseTimer < 0.7 {
            // Second open
            creature.mouthController?.setState("open_small", duration: 0.15)

            // Show "..." glyph if not yet shown
            if hesitationLabel == nil {
                let dots = SKLabelNode(fontNamed: "SFProText-Regular")
                dots.fontSize = 6
                dots.fontColor = PushlingPalette.gilt
                dots.text = "..."
                dots.alpha = 0
                dots.horizontalAlignmentMode = .center
                dots.verticalAlignmentMode = .center

                let config = StageConfiguration.all[creature.currentStage]!
                dots.position = CGPoint(
                    x: 0, y: config.size.height / 2 + 4
                )
                dots.zPosition = 40

                creature.addChild(dots)
                hesitationLabel = dots

                // Fade in and out
                let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.2)
                let hold = SKAction.wait(forDuration: 0.3)
                let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.2)
                dots.run(SKAction.sequence([fadeIn, hold, fadeOut])) {
                    [weak self] in
                    self?.hesitationLabel?.removeFromParent()
                    self?.hesitationLabel = nil
                }
            }
        }

        if phaseTimer >= 1.0 {
            creature.mouthController?.setState("closed", duration: 0.1)
            currentPhase = .theWord
            phaseTimer = 0
        }
    }

    /// Phase 4: The Word (2.3-3.8s) — "...[name]?" bubble appears
    private func updateTheWord() {
        guard let creature = creature else { return }

        if wordBubble == nil {
            // Create the speech bubble with the name
            let bubble = SpeechBubbleNode()
            let text = "...\(creatureName)?"
            bubble.configure(
                text: text,
                style: .say,
                stage: .critter,
                positionMode: .above
            )

            creature.addChild(bubble)
            bubble.appear()
            wordBubble = bubble

            // Open mouth slightly while speaking
            creature.mouthController?.setState("open_small", duration: 0.1)
        }

        // Update the bubble animation
        wordBubble?.update(deltaTime: phaseTimer < 1.5 ? 1.0 / 60.0 : 0)

        if phaseTimer >= 1.5 {
            // Start dismissing the bubble
            wordBubble?.dismiss()
            creature.mouthController?.setState("closed", duration: 0.2)

            if wordBubble?.isDone == true || phaseTimer >= 2.0 {
                wordBubble?.removeFromParent()
                wordBubble = nil
                currentPhase = .aftermath
                phaseTimer = 0
            }
        }
    }

    /// Phase 5: Aftermath (3.8-5.0s) — Blinks, resumes, slight bounce
    private func updateAftermath() {
        guard let creature = creature else { return }

        if phaseTimer < 0.2 {
            // First blink
            creature.eyeLeftController?.setState("blink", duration: 0)
            creature.eyeRightController?.setState("blink", duration: 0)
        } else if phaseTimer < 0.5 {
            creature.eyeLeftController?.setState("open", duration: 0.1)
            creature.eyeRightController?.setState("open", duration: 0.1)
        } else if phaseTimer < 0.7 {
            // Second blink
            creature.eyeLeftController?.setState("blink", duration: 0)
            creature.eyeRightController?.setState("blink", duration: 0)
        } else if phaseTimer < 1.0 {
            creature.eyeLeftController?.setState("open", duration: 0.1)
            creature.eyeRightController?.setState("open", duration: 0.1)
            creature.earLeftController?.setState("neutral", duration: 0.3)
            creature.earRightController?.setState("neutral", duration: 0.3)
        }

        if phaseTimer >= 1.2 {
            // Resume normal behavior
            creature.setTailSwayActive(true)
            creature.setWhiskerTwitchesActive(true)

            currentPhase = .complete

            NSLog("[Pushling/Speech] First Word Ceremony complete — \"%@\"",
                  creatureName)
            completion?()
        }
    }

    // MARK: - Journal Entry

    /// Generate the journal entry data for this milestone.
    func journalData(commitsEaten: Int) -> [String: Any] {
        return [
            "type": "first_word",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "word": creatureName,
            "stage": "critter",
            "commits_eaten": commitsEaten
        ]
    }
}
