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
    internal var visualTraits: VisualTraits = .neutral

    /// Accumulates commit data during the egg stage for progressive personality.
    var eggAccumulator: EggAccumulator?

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

    // MARK: - Orphan Subsystems (wired into existing pipelines)

    let creatureRejection: CreatureRejection
    let organicVariationEngine: OrganicVariationEngine
    let surpriseVariantSystem: SurpriseVariantSystem
    let attractionScorer: AttractionScorer
    let objectInteractionEngine: ObjectInteractionEngine
    let lateNightLantern: LateNightLantern

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
        self.visualTraits = PersonalityPersistence.loadVisualTraits(from: db)
        self.creatureStage = Self.loadStage(from: db)
        self.creatureName = Self.loadCreatureName(from: db)
        self.totalXP = Self.loadXP(from: db)

        // Initialize egg accumulator if creature is still an egg
        if creatureStage == .egg {
            self.eggAccumulator = EggAccumulator()
        }

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

        // --- P. Orphan Subsystems ---
        self.creatureRejection = CreatureRejection()
        self.organicVariationEngine = OrganicVariationEngine()
        self.surpriseVariantSystem = SurpriseVariantSystem()
        self.attractionScorer = AttractionScorer()
        self.objectInteractionEngine = ObjectInteractionEngine()
        self.lateNightLantern = LateNightLantern()

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
        wireEmotionalVisuals()
        wireNurture()
        wireTaughtBehaviors()

        // Start subsystems
        feedProcessor.start()

        NSLog("[Pushling/Coordinator] GameCoordinator initialized — "
              + "all subsystems wired. Stage: %@, Name: %@, XP: %d, "
              + "Hatched: %@",
              "\(creatureStage)", creatureName, totalXP,
              isHatched ? "yes" : "no")

        // Check if egg should hatch based on accumulated XP across restarts.
        // Each commit awards ~3-5 XP. At 15+ XP, enough commits have been
        // absorbed (across restarts) to justify hatching.
        if creatureStage == .egg && totalXP >= 15 {
            NSLog("[Pushling/Coordinator] Egg has %d XP — hatching on startup",
                  totalXP)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.hatchEggIntoDrop()
            }
        }
    }

    // MARK: - Per-Frame Update

    /// Called from PushlingScene.update() every frame.
    /// Skipped during hatching — the scene gates its own update loop,
    /// but guard here as well for safety.
    func update(deltaTime: TimeInterval) {
        guard isHatched else { return }

        // Compute shared time values once per frame to avoid redundant allocations
        let now = Date()
        let currentTime = CACurrentMediaTime()

        // 1. Emotions at 10Hz (not every frame)
        emotionUpdateAccumulator += deltaTime
        if emotionUpdateAccumulator >= Self.emotionUpdateInterval {
            let hour = Calendar.current.component(.hour, from: now)
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
                                sceneTime: currentTime)

        // 5. Speech coordinator (bubble lifecycle)
        speechCoordinator.update(deltaTime: deltaTime)

        // 6. Touch input (gesture recognizer long-press/sustained checks)
        gestureRecognizer.update(
            currentTime: currentTime,
            activeTouches: touchTracker.activeTouches
        )
        creatureTouchHandler.update(deltaTime: deltaTime,
                                      currentTime: currentTime)

        // 7. Voice integration (cooldown timer)
        voiceIntegration.update(deltaTime: deltaTime)

        // 8. State coordinator frame update (backup checks)
        stateCoordinator.frameUpdate()

        // 9. Update creature touch handler with current creature state
        syncTouchHandlerState()

        // 10. Nurture subsystem updates (habits, decay, routines)
        updateNurtureSubsystems(deltaTime: deltaTime)

        // 11. Late-night lantern (solidarity, not judgment)
        if let creature = scene.creatureNode {
            let hour = Calendar.current.component(.hour, from: now)
            let isDeveloperActive = commandRouter.sessionManager.isSessionActive
            lateNightLantern.update(deltaTime: deltaTime, hour: hour,
                                     isDeveloperActive: isDeveloperActive,
                                     creatureNode: creature)
        }
    }

    // MARK: - Shutdown

    func shutdown() {
        feedProcessor.stop()
        voiceIntegration.shutdown()
        creatureTouchHandler.flushState()

        // Persist emotional state
        EmotionalState.save(emotionalState, to: stateCoordinator.database)
        PersonalityPersistence.save(personality, to: stateCoordinator.database)

        // Persist XP and stage (synchronous — DB closes right after)
        persistXPAndStageSync()

        NSLog("[Pushling/Coordinator] GameCoordinator shut down — "
              + "XP: %d, Stage: %@", totalXP, "\(creatureStage)")
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

        // Set personality snapshot on creature node for PersonalityFilter
        scene.creatureNode?.personalitySnapshot = personality.toSnapshot()

        // Set repo count for Apex multi-tail before stage configure
        let repoCount = Self.loadRepoCount(from: stateCoordinator.database)
        scene.creatureNode?.repoCount = repoCount

        scene.creatureNode?.visualTraits = visualTraits
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

                // Build commit data
                let sha = commitData["sha"] as? String ?? "unknown"
                let message = commitData["message"] as? String ?? ""
                let repo = commitData["repo_name"] as? String ?? "unknown"
                let isMerge = commitData["is_merge"] as? Bool ?? false
                let isRevert = commitData["is_revert"] as? Bool ?? false
                let isForcePush = commitData["is_force_push"]
                    as? Bool ?? false
                let langs = (commitData["languages"] as? String)?
                    .components(separatedBy: ",")
                    .filter { !$0.isEmpty } ?? []
                let data = CommitData(
                    message: message, sha: sha, repoName: repo,
                    filesChanged: commitData["files_changed"] as? Int ?? 0,
                    linesAdded: linesAdded, linesRemoved: linesRemoved,
                    languages: langs, isMerge: isMerge, isRevert: isRevert,
                    isForcePush: isForcePush,
                    tags: commitData["tags"] as? [String] ?? [],
                    branch: nil,
                    timestamp: Date()
                )

                if self.creatureStage == .egg {
                    // Egg stage: absorb commit silently, accumulate data
                    NSLog("[Pushling/Egg] Absorbing commit %d/%d — accumulator %@",
                          (self.eggAccumulator?.commitCount ?? 0) + 1,
                          EggAccumulator.hatchThreshold,
                          self.eggAccumulator != nil ? "active" : "NIL")
                    self.eggAccumulator?.record(data)

                    // Egg glow pulse + wobble progress
                    if let creature = self.scene.creatureNode {
                        let progress = self.eggAccumulator?.hatchProgress ?? 0
                        creature.eggHatchProgress = CGFloat(progress)
                        let glow = SKAction.sequence([
                            SKAction.fadeAlpha(
                                to: CGFloat(0.6 + progress * 0.4),
                                duration: 0.5),
                            SKAction.fadeAlpha(to: 0.95, duration: 1.0)
                        ])
                        creature.run(glow, withKey: "eggAbsorb")
                    }

                    // On first commit, check if GitHub auth works and
                    // show consent popup only if it does
                    if self.eggAccumulator?.commitCount == 1 &&
                       !UserDefaults.standard.bool(
                           forKey: "githubConsentAsked") {
                        DispatchQueue.global(qos: .utility).async {
                            let authed = GitHubProfileFetcher.isAuthenticated()
                            DispatchQueue.main.async { [weak self] in
                                if authed {
                                    self?.showGitHubConsentPopup()
                                }
                                UserDefaults.standard.set(
                                    true, forKey: "githubConsentAsked")
                            }
                        }
                    }

                    // Check if ready to hatch
                    if self.eggAccumulator?.isReadyToHatch == true {
                        self.hatchEggIntoDrop()
                    }
                } else {
                    // Normal stage: character-by-character eating
                    if let creature = self.scene.creatureNode {
                        self.eatingAnimation.configure(
                            creature: creature, scene: self.scene,
                            fogController: self.scene.worldManager.fogOfWar)
                        let commitType = CommitTypeDetector.detect(
                            commit: data, isFirstFromRepo: false,
                            lastCommitTime: nil
                        )
                        self.eatingAnimation.start(
                            commit: data, commitType: commitType,
                            xpResult: nil
                        )
                    }
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

                // Persist XP to SQLite and check for evolution
                self.persistXPAndStage()
                self.checkEvolution()

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

        // Wire absence provider for wake animations
        scene.sessionReactions?.absenceProvider = { [weak self] in
            guard let self = self else {
                return (.brief, 0, .critter)
            }
            let db = self.stateCoordinator.database
            let rows = (try? db.query(
                "SELECT last_session_at FROM creature WHERE id = 1"
            )) ?? []
            let lastStr = rows.first?["last_session_at"] as? String
            let absence = AbsenceTracker.calculate(lastActivityStr: lastStr)
            return (absence.category, absence.seconds, self.creatureStage)
        }

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

        // Wire scheduler to player (with SurpriseVariantSystem — Orphan #3)
        surpriseScheduler.onSurpriseFire = {
            [weak self] definition, animation, variant in
            guard let self = self else { return }

            // Check SurpriseVariantSystem for context-aware variants
            let context = self.buildSurpriseContext()
            let taughtNames = Array(self.taughtDefinitions.keys)
            let sigBehaviors = self.masteryTracker
                .behaviors(atOrAbove: .signature)
                .map(\.behaviorName)
            let prefs = self.preferenceEngine.allPreferences
                .map { (subject: $0.subject, valence: $0.valence) }
            let companion = self.scene.worldManager.companionSystem
                .companionInfo?.type.rawValue

            let resolvedVariant = variant
                ?? self.surpriseVariantSystem.checkVariant(
                    surpriseId: definition.id,
                    context: context,
                    taughtBehaviors: taughtNames,
                    signatureBehaviors: sigBehaviors,
                    activePreferences: prefs,
                    companionType: companion
                )

            self.surprisePlayer.play(
                surpriseId: definition.id,
                name: definition.name,
                animation: animation,
                sceneTime: CACurrentMediaTime()
            )

            if let v = resolvedVariant {
                NSLog("[Pushling/Surprise] Variant applied: %@", v)
            }
        }

        NSLog("[Pushling/Coordinator] Surprise system wired — "
              + "%d surprises registered", surpriseScheduler.registeredCount)
    }

    // MARK: - GitHub Consent

    /// Show the GitHub consent popup on the Touch Bar (only if gh auth works).
    private func showGitHubConsentPopup() {
        guard let tbView = scene.view as? TouchBarView else { return }
        tbView.showGitHubConsent(
            onConsent: { [weak self] in
                GitHubProfileFetcher.fetch { profile in
                    guard let self = self, let profile = profile else { return }
                    // Feed GitHub data into egg accumulator
                    for (lang, count) in profile.languages {
                        let category = LanguageCategory.extensionMap[
                            lang.lowercased()] ?? .polyglot
                        self.eggAccumulator?.languageCounts[
                            category.rawValue, default: 0] += count
                    }
                    NSLog("[Pushling/GitHub] Profile fetched — %d repos, "
                          + "%d languages",
                          profile.repoCount, profile.languages.count)
                }
            },
            onDecline: {
                NSLog("[Pushling/GitHub] Consent declined")
            }
        )
    }

    // MARK: - Wiring: Input/Touch (G)

    private func wireInput() {
        // Wire: TouchTracker -> GestureRecognizer -> CreatureTouchHandler
        touchTracker.delegate = gestureRecognizer
        gestureRecognizer.delegate = creatureTouchHandler

        // Wire touch handler to scene and behavior stack
        creatureTouchHandler.wireToScene(scene,
                                           behaviorStack: scene.behaviorStack)

        // Wire camera controller to touch handler
        creatureTouchHandler.cameraController = scene.cameraController

        // Wire milestone tracker for gesture progression unlocks
        gestureRecognizer.milestoneTracker = creatureTouchHandler.milestoneTracker

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

        // Wire depth terrain query to autonomous layer
        if let stack = scene.behaviorStack {
            stack.autonomous.depthTerrainQuery = { [weak self] worldX, depth in
                self?.scene.worldManager.terrainHeightAtDepth(
                    worldX: worldX, depth: depth
                ) ?? TerrainGenerator.baselineY
            }
        }

        NSLog("[Pushling/Coordinator] Input system wired")
    }

    // wireVoice() is in GameCoordinator+Loading.swift

}
