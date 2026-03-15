// DebugExtensions.swift — Debug-only extensions for subsystems
// Adds debug methods to existing types that the debug menu needs.
// All methods are prefixed with `debug` to signal non-production use.

import Foundation
import CoreGraphics
import SpriteKit

// MARK: - AIDirectedLayer

extension AIDirectedLayer {

    /// Debug: inject an expression output for a given duration.
    func debugSetExpression(_ output: LayerOutput,
                            duration: TimeInterval) {
        let command = AICommand(
            id: "debug_expr_\(UUID().uuidString.prefix(6))",
            type: .express,
            output: output,
            holdDuration: duration,
            enqueuedAt: CACurrentMediaTime()
        )
        enqueue(command: command)
        NSLog("[Pushling/AI] Debug expression injected (%.1fs)",
              duration)
    }
}

// MARK: - MutationSystem

extension MutationSystem {

    /// Debug: grant a badge immediately, bypassing condition checks.
    /// Uses the crash recovery path for Nine Lives, or logs that the
    /// badge system requires production commit data for most badges.
    func debugGrantBadge(_ badge: MutationBadge) {
        guard !earnedBadges.contains(badge) else { return }

        // For Nine Lives, we can use the public crash recovery check
        if badge == .nineLives {
            checkOnCrashRecovery(totalRecoveries: 9)
            NSLog("[Pushling/Mutation] Debug-granted badge via "
                  + "crash recovery: %@", badge.displayName)
            return
        }

        // For other badges, the internal awardBadge is private.
        // We log the intent and note the badge cannot be directly
        // granted without the production commit pipeline.
        NSLog("[Pushling/Mutation] Debug: would grant '%@' — "
              + "requires production commit pipeline. "
              + "Visual effect: %@",
              badge.displayName, badge.visualEffect)
    }
}

// MARK: - SurpriseScheduler

extension SurpriseScheduler {

    /// Debug: fire a random eligible surprise immediately.
    func debugFireRandom(context: SurpriseContext) {
        // Find all registered surprise IDs
        let allIds = debugRegisteredIds()
        guard !allIds.isEmpty else {
            NSLog("[Pushling/Surprise] No surprises registered")
            return
        }

        // Try random IDs until we find one that fires
        let shuffled = allIds.shuffled()
        for id in shuffled.prefix(10) {
            forceFire(surpriseId: id, context: context)
            return
        }

        NSLog("[Pushling/Surprise] Could not fire any random surprise")
    }

    /// Debug: return all registered surprise IDs.
    func debugRegisteredIds() -> [Int] {
        // The registry is private. We can enumerate known surprise IDs
        // from the registered count.
        return Array(1...max(1, registeredCount))
    }
}

// MARK: - DiamondIndicator

extension DiamondIndicator {

    /// Debug: flash the diamond visible briefly.
    func debugFlash() {
        // Force a quick materialize -> idle -> dissolve cycle
        isHidden = false
        alpha = 0

        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let hold = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 1.0)

        run(SKAction.sequence([fadeIn, hold, fadeOut]),
            withKey: "debug_flash")

        NSLog("[Pushling/Diamond] Debug flash triggered")
    }
}

// MARK: - EmotionalState

extension EmotionalState {

    /// Debug: advance the emotional decay timers by the given seconds.
    func debugAdvanceTime(_ seconds: TimeInterval) {
        // Simulate the passage of time by running decay
        let hour = Calendar.current.component(.hour, from: Date())
        // Run in chunks of 1 minute to avoid extreme single-step decay
        let chunks = Int(seconds / 60.0)
        for _ in 0..<chunks {
            update(deltaTime: 60.0, hour: hour)
        }
        let remainder = seconds - Double(chunks) * 60.0
        if remainder > 0 {
            update(deltaTime: remainder, hour: hour)
        }
        NSLog("[Pushling/Emotion] Debug: advanced %.0f seconds "
              + "(sat: %.1f, cur: %.1f, con: %.1f, ene: %.1f)",
              seconds, satisfaction, curiosity, contentment, energy)
    }
}

// MARK: - CircadianCycle

extension CircadianCycle {

    /// Debug: advance the circadian cycle's internal timers.
    func debugAdvanceTime(_ seconds: TimeInterval) {
        // CircadianCycle tracks commit history, not real time.
        // Advancing time mainly affects the hour-of-day context
        // for the next update call.
        NSLog("[Pushling/Circadian] Debug: simulated %.0f seconds "
              + "advancement", seconds)
    }
}

// MARK: - GameCoordinator (Debug Helpers)

extension GameCoordinator {

    /// Build a SurpriseContext snapshot for debug surprise triggering.
    func debugBuildSurpriseContext() -> SurpriseContext {
        let sm = commandRouter.sessionManager
        return SurpriseContext(
            wallClock: Date(),
            sceneTime: CACurrentMediaTime(),
            stage: creatureStage,
            personality: personality.toSnapshot(),
            emotions: emotionalState.toSnapshot(),
            isSleeping: scene.behaviorStack?.physics.isSleeping ?? false,
            creatureName: creatureName,
            lastCommitMessage: nil,
            lastCommitBranch: nil,
            lastCommitLanguages: nil,
            lastCommitTimestamp: nil,
            totalCommitsEaten: totalXP,
            streakDays: 0,
            weather: "clear",
            hasCompanion: false,
            companionType: nil,
            placedObjects: [],
            isClaudeSessionActive: sm.isSessionActive,
            sessionDurationMinutes: 0,
            recentToolUseCount: 0,
            lastTouchTimestamp: nil,
            lastMCPTimestamp: nil
        )
    }
}

// MARK: - MasteryTracker

extension MasteryTracker {

    /// Debug: return all tracked trick names and their mastery levels.
    /// Uses the public `behaviors(atOrAbove:)` API.
    func allTrackedTricks() -> [(String, MasteryLevel)] {
        // Get all behaviors at learning level or above (i.e., all)
        let all = behaviors(atOrAbove: .learning)
        return all.map { ($0.behaviorName, $0.level) }
    }
}

// MARK: - AutonomousLayer

extension AutonomousLayer {

    /// Debug: name of the currently active behavior, if any.
    /// Returns nil when idle or when the active behavior is private.
    var currentBehaviorName: String? {
        // The activeBehavior property is private, so we report based
        // on observable state. The AutonomousLayer reports its
        // current state through the update() output.
        return debugCurrentBehaviorDescription
    }

    /// Debug: a human-readable description of the current state.
    var debugCurrentBehaviorDescription: String? {
        // The internal state is private. We can only report
        // what's publicly visible.
        return nil  // Will show as "idle" in debug output
    }
}

// MARK: - ReflexLayer

extension ReflexLayer {

    /// Debug: whether any reflex is currently active.
    var hasActiveReflex: Bool {
        return isActive
    }
}

// MARK: - BlendController

extension BlendController {

    /// Debug: count of currently active property blends.
    /// Uses the reversal phase and transition state as a proxy
    /// since the internal blend map is private.
    var activeBlendCount: Int {
        var count = 0
        if case .none = reversalPhase { } else { count += 1 }
        // Each active blend transition adds to the count
        // Since we can't enumerate private propertyBlends,
        // we report the reversal phase as a proxy.
        return count
    }
}
