// SurpriseTypes.swift — Core types for the Pushling surprise system
// All 78 surprises are organized into 8 categories.
// Each surprise has a unique ID, stage gate, trigger conditions,
// cooldown, and animation closure.

import Foundation
import CoreGraphics

// MARK: - Surprise Category

/// The 8 categories of surprises, matching Schema.validSurpriseCategories.
enum SurpriseCategory: String, CaseIterable {
    case visual        // #1-12: spontaneous visual gags
    case contextual    // #13-26: reactions to developer activity
    case cat           // #27-42: cat-specific behaviors
    case milestone     // #43-48: life event ceremonies
    case time          // #49-57: calendar/clock-based
    case easterEgg     = "easter_egg"    // #58-66: hidden triggers
    case hookAware     = "hook_aware"    // #67-72: Claude session reactions
    case collaborative // #73-78: human+AI synchronicity
}

// MARK: - Surprise Context

/// Runtime context passed to surprise eligibility checks and animations.
/// Contains the current state of the world needed for trigger evaluation.
struct SurpriseContext {
    // Time
    let wallClock: Date
    let sceneTime: TimeInterval

    // Creature
    let stage: GrowthStage
    let personality: PersonalitySnapshot
    let emotions: EmotionalSnapshot
    let isSleeping: Bool
    let creatureName: String

    // Commit data (from most recent commit, if any)
    let lastCommitMessage: String?
    let lastCommitBranch: String?
    let lastCommitLanguages: [String]?
    let lastCommitTimestamp: Date?
    let totalCommitsEaten: Int
    let streakDays: Int

    // World state
    let weather: String
    let hasCompanion: Bool
    let companionType: String?
    let placedObjects: [String]   // Names of currently placed world objects

    // Session state
    let isClaudeSessionActive: Bool
    let sessionDurationMinutes: Double
    let recentToolUseCount: Int   // PostToolUse hooks in last 2 minutes
    let lastTouchTimestamp: Date?
    let lastMCPTimestamp: Date?

    // Activity detection
    var isUserActive: Bool {
        let now = wallClock
        let commitActive = lastCommitTimestamp.map {
            now.timeIntervalSince($0) < 1800  // 30 min
        } ?? false
        let touchActive = lastTouchTimestamp.map {
            now.timeIntervalSince($0) < 900   // 15 min
        } ?? false
        return commitActive || touchActive || isClaudeSessionActive
    }
}

// MARK: - Surprise Definition

/// A registered surprise with all metadata needed for scheduling.
struct SurpriseDefinition {
    /// Unique surprise ID (1-78).
    let id: Int

    /// Human-readable name.
    let name: String

    /// Category for per-category cooldown.
    let category: SurpriseCategory

    /// Minimum growth stage required.
    let stageMin: GrowthStage

    /// Base selection weight (higher = more likely). Default 1.0.
    let weight: Double

    /// Per-surprise cooldown in seconds.
    let cooldown: TimeInterval

    /// Approximate animation duration in seconds.
    let duration: TimeInterval

    /// Whether this surprise bypasses global cooldown (milestones).
    let bypassesCooldown: Bool

    /// Whether this surprise suppresses others for 5 minutes after.
    let suppressesOthers: Bool

    /// Whether this is a one-time event (stored in milestones).
    let isOneTime: Bool

    /// Additional eligibility check beyond stage gate.
    /// Returns true if the surprise can fire in the given context.
    let isEligible: (SurpriseContext) -> Bool

    /// The animation closure. Returns a SurpriseAnimation to be played.
    /// Takes the context and returns body part states + speech + timing.
    let animation: (SurpriseContext) -> SurpriseAnimation

    init(id: Int, name: String, category: SurpriseCategory,
         stageMin: GrowthStage, weight: Double = 1.0,
         cooldown: TimeInterval = 300, duration: TimeInterval = 3.0,
         bypassesCooldown: Bool = false,
         suppressesOthers: Bool = false,
         isOneTime: Bool = false,
         isEligible: @escaping (SurpriseContext) -> Bool = { _ in true },
         animation: @escaping (SurpriseContext) -> SurpriseAnimation) {
        self.id = id
        self.name = name
        self.category = category
        self.stageMin = stageMin
        self.weight = weight
        self.cooldown = cooldown
        self.duration = duration
        self.bypassesCooldown = bypassesCooldown
        self.suppressesOthers = suppressesOthers
        self.isOneTime = isOneTime
        self.isEligible = isEligible
        self.animation = animation
    }
}

// MARK: - Surprise Animation

/// A surprise animation sequence: a series of timed keyframes
/// that control body parts, speech, and particle effects.
struct SurpriseAnimation {
    /// Ordered keyframes to execute.
    let keyframes: [SurpriseKeyframe]

    /// Total duration.
    let totalDuration: TimeInterval

    /// Optional speech text (shown as bubble).
    let speech: String?

    /// Optional speech style override.
    let speechStyle: SpeechStyle?

    /// Whether to log a journal entry.
    let logsToJournal: Bool

    /// Journal summary template.
    let journalSummary: String?

    init(keyframes: [SurpriseKeyframe],
         speech: String? = nil,
         speechStyle: SpeechStyle? = nil,
         logsToJournal: Bool = true,
         journalSummary: String? = nil) {
        self.keyframes = keyframes
        self.totalDuration = keyframes.map { $0.timestamp + $0.holdDuration }
            .max() ?? 0
        self.speech = speech
        self.speechStyle = speechStyle
        self.logsToJournal = logsToJournal
        self.journalSummary = journalSummary
    }
}

// MARK: - Surprise Keyframe

/// A single keyframe in a surprise animation sequence.
struct SurpriseKeyframe {
    /// When this keyframe activates (seconds from surprise start).
    let timestamp: TimeInterval

    /// How long to hold this state before next keyframe.
    let holdDuration: TimeInterval

    /// Body part state overrides (nil = don't change).
    let output: LayerOutput

    /// Optional speech at this keyframe.
    let speech: String?

    /// Optional speech style.
    let speechStyle: SpeechStyle?

    /// Easing for transitioning into this keyframe.
    let easing: SurpriseEasing

    init(at timestamp: TimeInterval, hold: TimeInterval = 0.5,
         output: LayerOutput = .empty,
         speech: String? = nil, speechStyle: SpeechStyle? = nil,
         easing: SurpriseEasing = .easeInOut) {
        self.timestamp = timestamp
        self.holdDuration = hold
        self.output = output
        self.speech = speech
        self.speechStyle = speechStyle
        self.easing = easing
    }
}

// MARK: - Surprise Easing

enum SurpriseEasing {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case snap       // Instant transition (for startles, jolts)
}

// MARK: - Surprise Fire Record

/// Tracks when a surprise was fired, for history and recency calculations.
struct SurpriseFireRecord {
    let surpriseId: Int
    let firedAt: Date
    let variant: String?
    let contextSummary: String?
}

// MARK: - Surprise Scheduling Result

/// Result of a surprise scheduling check.
enum SurpriseSchedulingResult {
    case fire(definition: SurpriseDefinition, variant: String?)
    case onCooldown(nextEligibleIn: TimeInterval)
    case noEligible
    case sleeping
    case inactive
    case suppressed(until: Date)
}
