// SpeechCoordinator.swift — Orchestrator for the entire speech system
// Wires together: filtering, bubble rendering, caching, styles, narration.
//
// This is the single entry point for all speech operations:
//   - AI-directed speech (Claude via MCP -> IPC -> daemon -> here)
//   - Autonomous speech (Layer 1 triggers)
//   - Commit reactions (after eating)
//   - Dream mumbles (during sleep)
//   - First word ceremony
//
// The coordinator manages bubble lifecycle, multi-bubble chains (Sage+),
// narration overlay, and stage/style gate enforcement.

import SpriteKit

// MARK: - Speech Request

/// A request to speak, from any source.
struct SpeechRequest {
    let text: String
    let style: SpeechStyle
    let source: UtteranceSource
    let isCommitReaction: Bool

    init(text: String,
         style: SpeechStyle = .say,
         source: UtteranceSource = .ai,
         isCommitReaction: Bool = false) {
        self.text = text
        self.style = style
        self.source = source
        self.isCommitReaction = isCommitReaction
    }
}

// MARK: - Speech Response

/// The result of processing a speech request.
struct SpeechResponse {
    let ok: Bool
    let spoken: String
    let intended: String
    let filtered: Bool
    let contentLossPercent: Int
    let loggedAsFailedSpeech: Bool
    let errorMessage: String?
}

// MARK: - Speech Coordinator

/// Manages all speech rendering and coordination for the Pushling creature.
final class SpeechCoordinator {

    // MARK: - Dependencies

    private weak var creature: CreatureNode?
    private var speechCache: SpeechCache?
    private var narrationOverlay: NarrationOverlay?
    private var firstWordCeremony: FirstWordCeremony?

    // MARK: - State

    private(set) var currentStage: GrowthStage = .spore
    private var personality: PersonalitySnapshot = .neutral
    private var creatureName: String = "Pushling"

    /// Active speech bubbles (supports multi-bubble chains at Sage+).
    private var activeBubbles: [SpeechBubbleNode] = []

    /// Maximum simultaneous bubbles by stage.
    private var maxBubbles: Int {
        switch currentStage {
        case .sage, .apex: return 3
        default: return 1
        }
    }

    /// Multi-bubble chain queue.
    private var bubbleQueue: [String] = []
    private var chainTimer: TimeInterval = 0
    private var activeChainStyle: SpeechStyle = .say
    private static let chainStagger: TimeInterval = 0.3

    /// Apex world-shaping cooldown.
    private var worldShapeCooldown: TimeInterval = 0
    private static let worldShapeCooldownDuration: TimeInterval = 300 // 5 min

    // MARK: - Initialization

    init() {
        self.firstWordCeremony = FirstWordCeremony()
    }

    /// Configure the coordinator with scene dependencies.
    func configure(creature: CreatureNode,
                    stage: GrowthStage,
                    personality: PersonalitySnapshot,
                    creatureName: String,
                    speechCache: SpeechCache?,
                    narrationOverlay: NarrationOverlay?) {
        self.creature = creature
        self.currentStage = stage
        self.personality = personality
        self.creatureName = creatureName
        self.speechCache = speechCache
        self.narrationOverlay = narrationOverlay
    }

    /// Update stage when creature evolves.
    func onStageChanged(_ newStage: GrowthStage) {
        currentStage = newStage
    }

    /// Update personality snapshot.
    func updatePersonality(_ personality: PersonalitySnapshot) {
        self.personality = personality
    }

    // MARK: - Speak (Main Entry Point)

    /// Process a speech request. Returns a response for the caller.
    /// This is the primary API for all speech operations.
    func speak(_ request: SpeechRequest) -> SpeechResponse {
        // Gate: Spore cannot speak
        if currentStage == .spore {
            return SpeechResponse(
                ok: false, spoken: "", intended: request.text,
                filtered: false, contentLossPercent: 0,
                loggedAsFailedSpeech: false,
                errorMessage: "Your body is pure light. You cannot speak yet. "
                    + "Use pushling_express to communicate through color "
                    + "and pulsing."
            )
        }

        // Gate: Style availability
        if request.style.minimumStage > currentStage {
            let available = SpeechStyle.allCases
                .filter { $0.minimumStage <= currentStage }
                .map { $0.rawValue }
                .joined(separator: ", ")
            return SpeechResponse(
                ok: false, spoken: "", intended: request.text,
                filtered: false, contentLossPercent: 0,
                loggedAsFailedSpeech: false,
                errorMessage: "The '\(request.style.rawValue)' style requires "
                    + "\(request.style.minimumStage)+ stage. "
                    + "At \(currentStage), you can use: \(available)."
            )
        }

        // Gate: Dream style only during sleep
        if request.style == .dream && !(creature?.isSleeping ?? false) {
            return SpeechResponse(
                ok: false, spoken: "", intended: request.text,
                filtered: false, contentLossPercent: 0,
                loggedAsFailedSpeech: false,
                errorMessage: "Dreams happen during sleep. "
                    + "Use 'think' for contemplative moments while awake."
            )
        }

        // Gate: Empty text
        if request.text.trimmingCharacters(in: .whitespaces).isEmpty {
            return SpeechResponse(
                ok: false, spoken: "", intended: request.text,
                filtered: false, contentLossPercent: 0,
                loggedAsFailedSpeech: false,
                errorMessage: "You opened your mouth but had nothing to say. "
                    + "Provide text to speak."
            )
        }

        // Run the filtering engine
        let filterResult = SpeechFilterEngine.filter(
            text: request.text,
            stage: currentStage,
            personality: personality
        )

        // Handle narration mode separately
        if request.style == .narrate {
            narrationOverlay?.show(text: filterResult.filteredText)
        } else {
            // Render speech bubble(s)
            renderSpeech(
                text: filterResult.filteredText,
                style: request.style,
                stage: currentStage
            )
        }

        // Cache the utterance
        speechCache?.store(
            text: filterResult.filteredText,
            style: request.style,
            stage: currentStage,
            source: request.source,
            emotion: filterResult.emotion
        )

        // Notify voice integration that speech was rendered (Gap 3)
        onSpeechRendered?(
            filterResult.filteredText,
            request.style,
            currentStage,
            request.source
        )

        // Check for Apex world-shaping
        if currentStage == .apex && request.source == .ai {
            checkWorldShaping(text: filterResult.filteredText)
        }

        return SpeechResponse(
            ok: true,
            spoken: filterResult.filteredText,
            intended: request.text,
            filtered: filterResult.originalText != filterResult.filteredText,
            contentLossPercent: filterResult.contentLossPercent,
            loggedAsFailedSpeech: filterResult.isFailedSpeech,
            errorMessage: nil
        )
    }

    // MARK: - Render Speech

    /// Render a speech bubble on the creature.
    private func renderSpeech(text: String,
                                style: SpeechStyle,
                                stage: GrowthStage) {
        guard let creature = creature else { return }

        // Determine position mode
        let positionMode = positionModeForStage(stage, style: style)

        // For Sage+, handle multi-bubble chains
        if stage >= .sage && text.count > 30 {
            let chunks = splitIntoChunks(text, maxChunkChars: 30)
            if chunks.count > 1 {
                renderBubbleChain(chunks: chunks, style: style, stage: stage)
                return
            }
        }

        // Single bubble
        let bubble = SpeechBubbleNode()
        bubble.configure(
            text: text, style: style,
            stage: stage, positionMode: positionMode
        )
        creature.addChild(bubble)
        bubble.clampToSceneBounds()  // Keep bubble visible on Touch Bar
        bubble.appear()

        // Dismiss any existing bubbles
        for existing in activeBubbles {
            existing.dismiss()
        }
        activeBubbles.append(bubble)

        // Dim narration if active
        narrationOverlay?.dimForSpeech()

        // Open mouth while speaking
        creature.mouthController?.setState("open_small", duration: 0.1)
        // Close after a short delay
        let closeDelay = SKAction.wait(forDuration: 0.5)
        let closeAction = SKAction.run { [weak creature] in
            creature?.mouthController?.setState("closed", duration: 0.2)
        }
        creature.run(
            SKAction.sequence([closeDelay, closeAction]),
            withKey: "speechMouth"
        )
    }

    /// Render a multi-bubble chain for Sage+ stages.
    private func renderBubbleChain(chunks: [String],
                                      style: SpeechStyle,
                                      stage: GrowthStage) {
        bubbleQueue = chunks
        chainTimer = 0
        activeChainStyle = style
        renderNextChainBubble(style: style, stage: stage)
    }

    /// Render the next bubble in a chain.
    private func renderNextChainBubble(style: SpeechStyle,
                                         stage: GrowthStage) {
        guard !bubbleQueue.isEmpty, let creature = creature else { return }

        let text = bubbleQueue.removeFirst()
        let positionMode = positionModeForStage(stage, style: style)

        let bubble = SpeechBubbleNode()
        bubble.configure(
            text: text, style: style,
            stage: stage, positionMode: positionMode
        )

        // Stack vertically above previous bubbles
        let stackOffset = CGFloat(activeBubbles.count) * 12
        bubble.position.y += stackOffset

        creature.addChild(bubble)
        bubble.clampToSceneBounds()  // Keep bubble visible on Touch Bar
        bubble.appear()
        activeBubbles.append(bubble)

        // Dismiss oldest if over max
        while activeBubbles.count > maxBubbles {
            activeBubbles.first?.dismiss()
            activeBubbles.removeFirst()
        }
    }

    // MARK: - Position Mode

    private func positionModeForStage(
        _ stage: GrowthStage, style: SpeechStyle
    ) -> BubblePositionMode {
        if stage == .drop { return .floating }
        if stage == .critter { return .above }

        // Beast+: side positioning
        // Determine left/right based on creature position relative to edges
        if let creature = creature {
            let x = creature.position.x
            if x > SceneConstants.sceneWidth - 30 {
                return .sideLeft
            }
        }
        return .sideRight
    }

    // MARK: - Text Chunking for Multi-Bubble

    /// Split text into chunks at natural boundaries.
    private func splitIntoChunks(_ text: String,
                                   maxChunkChars: Int) -> [String] {
        let words = text.split(separator: " ").map { String($0) }
        var chunks: [String] = []
        var current: [String] = []
        var currentLength = 0

        for word in words {
            if currentLength + word.count + 1 > maxChunkChars
                && !current.isEmpty {
                chunks.append(current.joined(separator: " "))
                current = [word]
                currentLength = word.count
            } else {
                current.append(word)
                currentLength += word.count + (current.count > 1 ? 1 : 0)
            }
        }
        if !current.isEmpty {
            chunks.append(current.joined(separator: " "))
        }

        return Array(chunks.prefix(3))  // Max 3 bubbles
    }

    // MARK: - Per-Frame Update

    /// Update active bubbles. Called every frame from the scene.
    func update(deltaTime: TimeInterval) {
        // Update active bubbles
        for bubble in activeBubbles {
            bubble.update(deltaTime: deltaTime)
        }

        // Remove done bubbles
        let doneBubbles = activeBubbles.filter { $0.isDone }
        for bubble in doneBubbles {
            bubble.removeFromParent()
        }
        activeBubbles.removeAll { $0.isDone }

        // Restore narration opacity if no bubbles active
        if activeBubbles.isEmpty {
            narrationOverlay?.restoreFromDim()
        }

        // Chain bubble stagger
        if !bubbleQueue.isEmpty {
            chainTimer += deltaTime
            if chainTimer >= Self.chainStagger {
                chainTimer = 0
                renderNextChainBubble(
                    style: activeChainStyle, stage: currentStage
                )
            }
        }

        // World-shaping cooldown
        if worldShapeCooldown > 0 {
            worldShapeCooldown -= deltaTime
        }

        // Narration update
        narrationOverlay?.update(deltaTime: deltaTime)

        // First word ceremony update
        if let ceremony = firstWordCeremony,
           ceremony.currentPhase != .idle
            && ceremony.currentPhase != .complete {
            ceremony.update(deltaTime: deltaTime)
        }
    }

    // MARK: - Apex World-Shaping

    /// Apex world-shaping trigger words: (pattern, effect, probability).
    private static let worldShapeTriggers: [(String, String, Double)] = [
        ("rain", "rain", 0.3), ("storm", "storm", 0.3), ("sun", "clear", 0.3),
        ("clear", "clear", 0.3), ("bright", "clear", 0.3), ("snow", "snow", 0.25),
        ("cold", "snow", 0.25), ("winter", "snow", 0.25), ("night", "night", 0.3),
        ("dark", "night", 0.3), ("stars", "night", 0.3), ("dawn", "dawn", 0.3),
        ("morning", "dawn", 0.3), ("sunrise", "dawn", 0.3), ("grow", "bloom", 0.4),
        ("bloom", "bloom", 0.4), ("flower", "bloom", 0.4), ("shake", "shake", 0.2),
        ("earthquake", "shake", 0.2), ("tremble", "shake", 0.2),
    ]

    /// Check if Apex speech triggers world-shaping. Deterministic via text hash.
    private func checkWorldShaping(text: String) {
        guard worldShapeCooldown <= 0 else { return }
        let lower = text.lowercased()
        for (pattern, effect, prob) in Self.worldShapeTriggers {
            if lower.contains(pattern) {
                let roll = Double(abs(text.hashValue) % 100) / 100.0
                if roll < prob {
                    worldShapeCooldown = Self.worldShapeCooldownDuration
                    NSLog("[Pushling/Speech] Apex world-shape: '%@' -> %@", pattern, effect)
                    onWorldShapeEffect?(effect, pattern)
                    return
                }
            }
        }
    }

    /// Callback for world-shaping effects. Set by the scene.
    var onWorldShapeEffect: ((_ effect: String, _ triggerWord: String) -> Void)?

    /// Callback when speech is rendered — bridges to VoiceIntegration (Gap 3).
    /// Parameters: (text, style rawValue, stage)
    var onSpeechRendered: ((_ text: String, _ style: SpeechStyle,
                            _ stage: GrowthStage,
                            _ source: UtteranceSource) -> Void)?

    // MARK: - First Word Ceremony

    /// Check and potentially trigger the first word ceremony.
    func checkFirstWordCeremony(
        commitsEaten: Int,
        energy: Double,
        contentment: Double,
        isIdle: Bool,
        hasMilestone: Bool
    ) {
        guard let creature = creature,
              let ceremony = firstWordCeremony,
              !ceremony.hasTriggered else { return }

        if FirstWordCeremony.conditionsMet(
            stage: currentStage,
            commitsEaten: commitsEaten,
            energy: energy,
            contentment: contentment,
            isIdle: isIdle,
            hasMilestone: hasMilestone
        ) {
            ceremony.begin(
                creature: creature,
                name: creatureName
            ) { [weak self] in
                self?.onFirstWordComplete?(
                    ceremony.journalData(commitsEaten: commitsEaten)
                )
            }
        }
    }

    /// Callback when first word ceremony completes. Set by the scene/state manager.
    var onFirstWordComplete: ((_ journalData: [String: Any]) -> Void)?

    // MARK: - Dream Speech

    /// Trigger a dream bubble during sleep.
    func showDreamBubble() {
        guard let cache = speechCache,
              let utterance = cache.dreamUtterance() else { return }

        let fragment = SpeechCache.dreamFragment(from: utterance)
        renderSpeech(text: fragment, style: .dream, stage: currentStage)
    }

    // MARK: - Autonomous Speech

    /// Trigger autonomous commit reaction speech.
    func speakCommitReaction(reaction: String) {
        let request = SpeechRequest(
            text: reaction,
            style: .say,
            source: .autonomous,
            isCommitReaction: true
        )
        let _ = speak(request)
    }
}

// SpeechStyle CaseIterable conformance is declared in SpeechBubbleNode.swift
