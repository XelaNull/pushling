// GameCoordinator.swift — Master wiring class connecting all 16 subsystems
// The creature's nervous system. Created by AppDelegate, called by PushlingScene.

import SpriteKit
import QuartzCore

final class GameCoordinator {

    // MARK: - Core References

    let scene: PushlingScene
    let stateCoordinator: StateCoordinator
    let commandRouter: CommandRouter
    let eventBuffer: EventBuffer

    // MARK: - Creature Identity

    // internal(set) to allow GameCoordinator+Hatching.swift to write
    internal var personality: Personality = .neutral
    internal var creatureStage: GrowthStage = .critter
    internal var creatureName: String = "Pushling"
    internal var totalXP: Int = 0

    // MARK: - Subsystems

    let emotionalState: EmotionalState
    let circadianCycle: CircadianCycle
    let emergentStates: EmergentStateDetector
    let feedProcessor: HookEventProcessor
    let speechCoordinator: SpeechCoordinator
    let speechCache: SpeechCache
    let narrationOverlay: NarrationOverlay
    let surpriseScheduler: SurpriseScheduler
    let surprisePlayer: SurpriseAnimationPlayer
    let mutationSystem: MutationSystem
    let touchTracker: TouchTracker
    let gestureRecognizer: GestureRecognizer
    let creatureTouchHandler: CreatureTouchHandler
    let taughtBehaviorEngine: TaughtBehaviorEngine
    let masteryTracker: MasteryTracker
    let idleRotationGovernor: IdleRotationGovernor
    let behaviorBreeding: BehaviorBreeding
    let voiceSystem: VoiceSystem
    let voiceIntegration: VoiceIntegration
    let eatingAnimation: CommitEatingAnimation

    // MARK: - Nurture Engines

    let habitEngine: HabitEngine
    let preferenceEngine: PreferenceEngine
    let quirkEngine: QuirkEngine
    let routineEngine: RoutineEngine
    let nurtureDecayManager: NurtureDecayManager

    // MARK: - Hatching State
    // internal setter to allow GameCoordinator+Hatching.swift to write

    var isHatched: Bool = true

    /// The active hatching ceremony reference (nil after completion).
    var activeHatchingCeremony: HatchingCeremony?

    // MARK: - Throttle Timers

    private var emotionUpdateAccumulator: TimeInterval = 0
    private static let emotionUpdateInterval: TimeInterval = 0.1  // 10Hz

    var nurtureDecayAccumulator: TimeInterval = 0
    static let nurtureDecayInterval: TimeInterval = 60.0  // Check every 60s

    var habitPeriodicAccumulator: TimeInterval = 0
    static let habitPeriodicInterval: TimeInterval = 30.0

    // MARK: - Initialization

    init(scene: PushlingScene,
         stateCoordinator: StateCoordinator,
         commandRouter: CommandRouter,
         eventBuffer: EventBuffer) {

        self.scene = scene
        self.stateCoordinator = stateCoordinator
        self.commandRouter = commandRouter
        self.eventBuffer = eventBuffer

        let db = stateCoordinator.database

        // --- A. Load Personality from DB ---
        self.personality = PersonalityPersistence.load(from: db)
        self.creatureStage = Self.loadStage(from: db)
        self.creatureName = Self.loadCreatureName(from: db)
        self.totalXP = Self.loadXP(from: db)

        // --- A. Emotional State + Circadian ---
        self.emotionalState = EmotionalState.load(from: db)
        self.circadianCycle = Self.loadCircadian(from: db)
        self.emergentStates = EmergentStateDetector()

        // --- C. Feed/Hook Processor ---
        self.feedProcessor = HookEventProcessor(
            reflexLayer: scene.behaviorStack?.reflexes,
            eventBuffer: eventBuffer
        )

        // --- D. Speech ---
        self.speechCache = SpeechCache(db: db)
        self.narrationOverlay = NarrationOverlay()
        self.speechCoordinator = SpeechCoordinator()

        // --- H. Surprise System ---
        self.surpriseScheduler = SurpriseScheduler()
        self.surprisePlayer = SurpriseAnimationPlayer()

        // --- M. Mutation System ---
        self.mutationSystem = MutationSystem()

        // --- G. Input/Touch ---
        self.touchTracker = TouchTracker()
        self.gestureRecognizer = GestureRecognizer()
        self.creatureTouchHandler = CreatureTouchHandler(db: db)

        // --- J. Taught Behaviors ---
        self.taughtBehaviorEngine = TaughtBehaviorEngine()
        self.masteryTracker = MasteryTracker()
        self.idleRotationGovernor = IdleRotationGovernor()
        self.behaviorBreeding = BehaviorBreeding()

        // --- N. Voice ---
        self.voiceSystem = VoiceSystem()
        self.voiceIntegration = VoiceIntegration(voiceSystem: voiceSystem)

        // --- Commit Eating ---
        self.eatingAnimation = CommitEatingAnimation()

        // --- O. Nurture Engines ---
        self.habitEngine = HabitEngine()
        self.preferenceEngine = PreferenceEngine()
        self.quirkEngine = QuirkEngine()
        self.routineEngine = RoutineEngine()
        self.nurtureDecayManager = NurtureDecayManager()

        // --- Hatching State ---
        self.isHatched = Self.loadHatched(from: db)

        // === Wire everything together ===
        wireHatching()
        wireEmotionsAndPersonality()
        wireFeedProcessor()
        wireSpeech()
        wireSessionManager()
        wireSurprises()
        wireInput()
        wireMutations()
        wireVoice()
        wireCommandRouter()
        wireEatingAnimation()
        wireNurture()
        wireTaughtBehaviors()

        // Start subsystems
        feedProcessor.start()

        NSLog("[Pushling/Coordinator] GameCoordinator initialized — "
              + "all subsystems wired. Stage: %@, Name: %@, XP: %d, "
              + "Hatched: %@",
              "\(creatureStage)", creatureName, totalXP,
              isHatched ? "yes" : "no")
    }

    // MARK: - Per-Frame Update

    /// Called from PushlingScene.update() every frame.
    /// Skipped during hatching — the scene gates its own update loop,
    /// but guard here as well for safety.
    func update(deltaTime: TimeInterval) {
        guard isHatched else { return }

        // 1. Emotions at 10Hz (not every frame)
        emotionUpdateAccumulator += deltaTime
        if emotionUpdateAccumulator >= Self.emotionUpdateInterval {
            let hour = Calendar.current.component(.hour, from: Date())
            emotionalState.update(deltaTime: emotionUpdateAccumulator, hour: hour)
            emotionUpdateAccumulator = 0

            // Feed emotions into behavior stack
            if let stack = scene.behaviorStack {
                stack.emotions = emotionalState.toSnapshot()
            }
        }

        // 2. Emergent states (internally throttled to every 5s)
        emergentStates.update(deltaTime: deltaTime,
                               emotions: emotionalState.toSnapshot())

        // 3. Surprise scheduler (internally throttled to every 30s)
        surpriseScheduler.update(deltaTime: deltaTime,
                                  context: buildSurpriseContext())

        // 4. Surprise animation player
        surprisePlayer.update(deltaTime: deltaTime,
                                sceneTime: CACurrentMediaTime())

        // 5. Speech coordinator (bubble lifecycle)
        speechCoordinator.update(deltaTime: deltaTime)

        // 6. Touch input (gesture recognizer long-press/sustained checks)
        gestureRecognizer.update(
            currentTime: CACurrentMediaTime(),
            activeTouches: touchTracker.activeTouches
        )
        creatureTouchHandler.update(deltaTime: deltaTime,
                                      currentTime: CACurrentMediaTime())

        // 7. Voice integration (cooldown timer)
        voiceIntegration.update(deltaTime: deltaTime)

        // 8. State coordinator frame update (backup checks)
        stateCoordinator.frameUpdate()

        // 9. Update creature touch handler with current creature state
        syncTouchHandlerState()

        // 10. Nurture subsystem updates (habits, decay, routines)
        updateNurtureSubsystems(deltaTime: deltaTime)
    }

    // MARK: - Shutdown

    func shutdown() {
        feedProcessor.stop()
        voiceIntegration.shutdown()
        creatureTouchHandler.flushState()

        // Persist emotional state
        EmotionalState.save(emotionalState, to: stateCoordinator.database)
        PersonalityPersistence.save(personality, to: stateCoordinator.database)

        NSLog("[Pushling/Coordinator] GameCoordinator shut down")
    }

    // MARK: - Wiring: Hatching (Gap 1)
    // wireHatching() is in GameCoordinator+Hatching.swift

    // MARK: - Wiring: Emotions & Personality (A+B)

    private func wireEmotionsAndPersonality() {
        // Set personality on behavior stack
        if let stack = scene.behaviorStack {
            stack.personality = personality.toSnapshot()
            stack.emotions = emotionalState.toSnapshot()
            stack.stage = creatureStage
        }

        // Configure creature node for correct stage (Gap 2: from DB, not hardcoded)
        scene.creatureNode?.configureForStage(creatureStage)

        // Update world visual complexity for the real stage (Gap 6)
        scene.worldManager.onStageChanged(creatureStage)

        // Emotional persistence callback
        emotionalState.onPersist = { [weak self] snapshot in
            guard let self = self else { return }
            EmotionalState.save(self.emotionalState,
                                 to: self.stateCoordinator.database)
        }

        // Update scene's satisfaction display
        scene.onSatisfactionChanged(emotionalState.satisfaction)

        NSLog("[Pushling/Coordinator] Emotions & personality wired")
    }

    // MARK: - Wiring: Feed Processor (C)

    private func wireFeedProcessor() {
        // On commit received: boost emotions, trigger eating, award XP
        feedProcessor.onCommitReceived = { [weak self] commitData, multiplier in
            guard let self = self else { return }

            let linesAdded = commitData["lines_added"] as? Int ?? 0
            let linesRemoved = commitData["lines_removed"] as? Int ?? 0
            let totalLines = linesAdded + linesRemoved
            let size = CommitSize.from(linesChanged: totalLines)

            // Boost emotions
            DispatchQueue.main.async {
                self.emotionalState.boostFromCommit(size: size)
                self.scene.onSatisfactionChanged(
                    self.emotionalState.satisfaction
                )

                // Record in circadian cycle
                self.circadianCycle.recordCommit(at: Date())

                // Trigger eating animation
                if let creature = self.scene.creatureNode {
                    self.eatingAnimation.configure(creature: creature,
                                                     scene: self.scene)
                    let sha = commitData["sha"] as? String ?? "unknown"
                    let message = commitData["message"] as? String ?? ""
                    let repo = commitData["repo_name"] as? String ?? "unknown"
                    let isMerge = commitData["is_merge"] as? Bool ?? false
                    let isRevert = commitData["is_revert"] as? Bool ?? false
                    let isForcePush = commitData["is_force_push"]
                        as? Bool ?? false
                    let data = CommitData(
                        message: message, sha: sha, repoName: repo,
                        filesChanged: commitData["files_changed"] as? Int ?? 0,
                        linesAdded: linesAdded, linesRemoved: linesRemoved,
                        languages: [], isMerge: isMerge, isRevert: isRevert,
                        isForcePush: isForcePush, branch: nil,
                        timestamp: Date()
                    )
                    let commitType = CommitTypeDetector.detect(
                        commit: data,
                        isFirstFromRepo: false,
                        lastCommitTime: nil
                    )
                    self.eatingAnimation.start(
                        commit: data, commitType: commitType, xpResult: nil
                    )
                }

                // XP award
                let baseXP = max(1, min(5, totalLines / 20)) + 1
                let finalXP = max(1, Int(Double(baseXP) * multiplier))
                self.totalXP += finalXP
                self.scene.onXPChanged(
                    currentXP: self.totalXP % 100,
                    xpToNext: 100,
                    stage: self.creatureStage
                )

                // Mutation badge check on commit (Gap 4)
                let commitMessage = commitData["message"] as? String ?? ""
                let languages = commitData["languages"] as? [String] ?? []
                let hasTestFiles = languages.contains { ext in
                    ext.contains("test") || ext.contains("spec")
                }
                let badgeData = CommitBadgeData(
                    timestamp: Date(),
                    languages: languages,
                    messageLength: commitMessage.count,
                    hasTestFiles: hasTestFiles,
                    touchesOldFiles: false,
                    currentStreakDays: 0,
                    todayCommitCount: 0
                )
                self.mutationSystem.checkOnCommit(
                    commitData: badgeData,
                    queryProvider: self.stateCoordinator
                )

                // Voice integration: track commit eaten
                self.voiceIntegration.onCommitEaten()

                // Habit trigger: commit eaten
                let commitTypeStr = commitData["commit_type"] as? String ?? "normal"
                self.habitEngine.evaluate(
                    event: .commitEaten(type: commitTypeStr,
                                        linesChanged: totalLines),
                    stage: self.creatureStage,
                    currentTime: CACurrentMediaTime()
                )

                // Routine trigger: post_meal (every commit) or
                // post_feast (200+ lines)
                if totalLines >= 200 {
                    self.routineEngine.trigger(slot: .postFeast)
                } else {
                    self.routineEngine.trigger(slot: .postMeal)
                }
            }
        }

        NSLog("[Pushling/Coordinator] Feed processor wired")
    }

    // MARK: - Wiring: Speech (D)

    private func wireSpeech() {
        // Add narration overlay to scene
        narrationOverlay.addToScene(scene)

        // Configure speech coordinator with real dependencies
        if let creature = scene.creatureNode {
            speechCoordinator.configure(
                creature: creature,
                stage: creatureStage,
                personality: personality.toSnapshot(),
                creatureName: creatureName,
                speechCache: speechCache,
                narrationOverlay: narrationOverlay
            )
        }

        // Apex world-shaping: speech triggers weather (Gap 7)
        speechCoordinator.onWorldShapeEffect = { [weak self] effect, trigger in
            guard let self = self else { return }
            NSLog("[Pushling/Coordinator] World-shape effect: '%@' "
                  + "(trigger: '%@')", effect, trigger)
            if let weather = WeatherState(rawValue: effect) {
                self.scene.worldManager.debugForceWeather(weather)
            }
        }

        // Eating animation speech reaction (Gap 7)
        eatingAnimation.onSpeechReaction = { [weak self] reaction in
            guard let self = self else { return }
            self.speechCoordinator.speakCommitReaction(reaction: reaction)
        }

        NSLog("[Pushling/Coordinator] Speech system wired")
    }

    // MARK: - Wiring: Session Manager (E)

    private func wireSessionManager() {
        scene.wireSessionManager(commandRouter.sessionManager)

        // Wire routine/habit triggers to session lifecycle events
        let sm = commandRouter.sessionManager
        let previousHandler = sm.onSessionEvent
        sm.onSessionEvent = { [weak self] event in
            previousHandler?(event)
            self?.handleSessionEventForNurture(event)
        }

        NSLog("[Pushling/Coordinator] Session manager wired to scene")
    }

    // MARK: - Wiring: Surprises (H)

    private func wireSurprises() {
        // Register all 78 surprises
        SurpriseRegistry.registerAll(into: surpriseScheduler)

        // Wire surprise player to behavior stack and speech
        surprisePlayer.onInjectReflex = { [weak self] definition, sceneTime in
            self?.scene.behaviorStack?.triggerReflex(definition, at: sceneTime)
        }
        surprisePlayer.onSpeak = { [weak self] text, style in
            let request = SpeechRequest(text: text, style: style,
                                         source: .autonomous)
            let _ = self?.speechCoordinator.speak(request)
        }

        // Wire scheduler to player
        surpriseScheduler.onSurpriseFire = {
            [weak self] definition, animation, variant in
            self?.surprisePlayer.play(
                surpriseId: definition.id,
                name: definition.name,
                animation: animation,
                sceneTime: CACurrentMediaTime()
            )
        }

        NSLog("[Pushling/Coordinator] Surprise system wired — "
              + "%d surprises registered", surpriseScheduler.registeredCount)
    }

    // MARK: - Wiring: Input/Touch (G)

    private func wireInput() {
        // Wire: TouchTracker -> GestureRecognizer -> CreatureTouchHandler
        touchTracker.delegate = gestureRecognizer
        gestureRecognizer.delegate = creatureTouchHandler

        // Wire touch handler to scene and behavior stack
        creatureTouchHandler.wireToScene(scene,
                                           behaviorStack: scene.behaviorStack)

        // Contentment changes from touch -> emotional state
        creatureTouchHandler.onContentmentChange = { [weak self] delta in
            guard let self = self else { return }
            self.emotionalState.boostFromTouch()
        }

        // Satisfaction changes from touch -> emotional state
        creatureTouchHandler.onSatisfactionChange = { [weak self] delta in
            guard let self = self else { return }
            self.emotionalState.boostFromInteraction()
        }

        NSLog("[Pushling/Coordinator] Input system wired")
    }

    // wireVoice() is in GameCoordinator+Loading.swift

}
