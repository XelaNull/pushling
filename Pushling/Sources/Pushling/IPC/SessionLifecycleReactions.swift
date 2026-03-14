// SessionLifecycleReactions.swift — Wires SessionManager events to creature + diamond
// This is the coordinator between:
//   - SessionManager (pure state, no SpriteKit)
//   - DiamondIndicator (SpriteKit node, visual state)
//   - ReflexLayer (creature body reactions)
//   - AIDirectedLayer (behavior stack integration)
//
// All visual/creature reactions to session lifecycle events are defined here.
// Reactions dispatch to the main thread for SpriteKit safety.

import Foundation
import QuartzCore

// MARK: - Session Lifecycle Reactions

/// Coordinates creature and diamond reactions to session lifecycle events.
/// Created by PushlingScene and registered as the SessionManager's event handler.
final class SessionLifecycleReactions {

    // MARK: - Dependencies

    private weak var diamond: DiamondIndicator?
    private weak var reflexLayer: ReflexLayer?
    private weak var aiDirectedLayer: AIDirectedLayer?

    /// Callback for journal logging. Invoked with session summary data.
    var onJournalEntry: ((_ type: String, _ data: [String: Any]) -> Void)?

    // MARK: - State

    /// Tracks whether we've sent the first-command reaction.
    private var hasReceivedFirstCommand = false

    /// Tracks the long-session timer (slow-blink every 30min).
    private var longSessionTimer: DispatchSourceTimer?
    private var sessionStartTime: Date?

    // MARK: - Init

    init(diamond: DiamondIndicator?,
         reflexLayer: ReflexLayer?,
         aiDirectedLayer: AIDirectedLayer?) {
        self.diamond = diamond
        self.reflexLayer = reflexLayer
        self.aiDirectedLayer = aiDirectedLayer
    }

    // MARK: - Event Handler

    /// The event handler to register with SessionManager.onSessionEvent.
    /// Must be called on main thread for SpriteKit safety, or dispatch there.
    func handleSessionEvent(_ event: SessionEvent) {
        // Ensure we're on the main thread for SpriteKit operations
        if Thread.isMainThread {
            handleEventInternal(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleEventInternal(event)
            }
        }
    }

    // MARK: - Internal Dispatch

    private func handleEventInternal(_ event: SessionEvent) {
        switch event {
        case .sessionStarted(let sessionId):
            onSessionStarted(sessionId: sessionId)

        case .sessionEnded(let sessionId, let reason, let duration):
            onSessionEnded(sessionId: sessionId, reason: reason, duration: duration)

        case .commandReceived:
            onCommandReceived()

        case .idlePhaseChanged(let phase):
            onIdlePhaseChanged(phase)

        case .subagentsStarted(let count):
            onSubagentsStarted(count: count)

        case .subagentsStopped:
            onSubagentsStopped()

        case .sessionRejected(let existingId, let startedAgo):
            onSessionRejected(existingId: existingId, startedAgo: startedAgo)
        }
    }

    // MARK: - Session Start (P4-T4-02)

    private func onSessionStarted(sessionId: String) {
        hasReceivedFirstCommand = false
        sessionStartTime = Date()

        // 1. If diamond is still dissolving from a previous session, force-reset
        diamond?.forceHide()

        // 2. Materialize the diamond
        diamond?.materialize()

        // 3. Creature reaction: ears perk, eyes brighten, tail wag
        let t = CACurrentMediaTime()
        let greetingReflex = ReflexDefinition(
            name: "session_greeting",
            duration: 2.0,
            fadeoutFraction: 0.25,
            output: {
                var o = LayerOutput()
                o.earLeftState = "perk"
                o.earRightState = "perk"
                o.eyeLeftState = "bright"
                o.eyeRightState = "bright"
                o.tailState = "wag"
                return o
            }()
        )
        reflexLayer?.trigger(greetingReflex, at: t)

        // 4. AI-directed layer enters warm standby (ready for commands)
        // (The AI layer activates on first actual command, not on connect)

        // 5. Start long-session appreciation timer (slow-blink every 30min)
        startLongSessionTimer()

        // 6. Journal entry
        onJournalEntry?("session_start", [
            "session_id": sessionId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        NSLog("[Pushling/Reactions] Session started — greeting animation triggered")
    }

    // MARK: - Session End (P4-T4-03)

    private func onSessionEnded(sessionId: String, reason: DisconnectReason,
                                 duration: TimeInterval) {
        let t = CACurrentMediaTime()
        stopLongSessionTimer()

        switch reason {
        case .clean:
            // Clean disconnect: diamond fades over 5s, creature waves goodbye
            diamond?.dissolveClean()

            // Long session (>1hr): grateful slow-blink before wave
            if duration > 3600 {
                let slowBlink = ReflexDefinition(
                    name: "grateful_blink",
                    duration: 1.5,
                    fadeoutFraction: 0.3,
                    output: {
                        var o = LayerOutput()
                        o.eyeLeftState = "slow_blink"
                        o.eyeRightState = "slow_blink"
                        o.earLeftState = "soft"
                        o.earRightState = "soft"
                        return o
                    }()
                )
                reflexLayer?.trigger(slowBlink, at: t)
            }

            // Wave goodbye
            let wave = ReflexDefinition(
                name: "session_wave",
                duration: 2.5,
                fadeoutFraction: 0.2,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "neutral"
                    o.earRightState = "tilt"
                    o.eyeLeftState = "soft"
                    o.eyeRightState = "soft"
                    o.tailState = "slow_sway"
                    o.pawStates = ["fr": "wave"]
                    return o
                }()
            )
            reflexLayer?.trigger(wave, at: t + (duration > 3600 ? 1.5 : 0))

        case .abrupt:
            // Abrupt disconnect: diamond flickers 3x rapidly, creature looks confused
            diamond?.dissolveAbrupt()

            // Confused reaction: "?"
            let confused = ReflexDefinition(
                name: "session_confused",
                duration: 3.0,
                fadeoutFraction: 0.2,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "tilt"
                    o.earRightState = "back"
                    o.eyeLeftState = "wide"
                    o.eyeRightState = "wide"
                    o.mouthState = "open_slight"
                    o.tailState = "still"
                    return o
                }()
            )
            reflexLayer?.trigger(confused, at: t)

        case .evicted:
            // Eviction: abbreviated dissolve
            diamond?.dissolveAbrupt()
        }

        // AI-directed layer fades out
        aiDirectedLayer?.sessionEnded()
        hasReceivedFirstCommand = false

        // Journal entry
        onJournalEntry?("session_end", [
            "session_id": sessionId,
            "reason": "\(reason)",
            "duration_s": Int(duration),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])

        NSLog("[Pushling/Reactions] Session ended — reason: %@, duration: %.0fs",
              "\(reason)", duration)
    }

    // MARK: - Command Received (P4-T4-04)

    private func onCommandReceived() {
        // Sparkle the diamond
        diamond?.setActive()

        // Reset idle opacity to full
        diamond?.setIdleOpacity(1.0)

        // First command: extra reaction (alert posture, tail high)
        if !hasReceivedFirstCommand {
            hasReceivedFirstCommand = true
            let t = CACurrentMediaTime()
            let alertReflex = ReflexDefinition(
                name: "first_command_alert",
                duration: 1.5,
                fadeoutFraction: 0.3,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "perk"
                    o.earRightState = "perk"
                    o.eyeLeftState = "focused"
                    o.eyeRightState = "focused"
                    o.tailState = "high"
                    o.bodyState = "alert"
                    return o
                }()
            )
            reflexLayer?.trigger(alertReflex, at: t)
        }
    }

    // MARK: - Idle Phase Changes (P4-T4-04)

    private func onIdlePhaseChanged(_ phase: IdlePhase) {
        switch phase {
        case .attentive:
            // Full brightness, creature alert
            diamond?.setIdleOpacity(1.0)
            diamond?.setThinking()

        case .settling:
            // Pulse slows, creature enters attentive idle
            diamond?.setIdleOpacity(0.85)
            diamond?.setThinking()
            let t = CACurrentMediaTime()
            let settleReflex = ReflexDefinition(
                name: "idle_settle",
                duration: 1.0,
                fadeoutFraction: 0.5,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "relaxed"
                    o.earRightState = "relaxed"
                    return o
                }()
            )
            reflexLayer?.trigger(settleReflex, at: t)

        case .drifting:
            // Diamond dims to 50%, creature resumes autonomous wandering
            diamond?.setIdleOpacity(0.5)
            diamond?.setIdle()

        case .warmStandby:
            // Diamond at 30%, AI layer times out
            diamond?.setIdleOpacity(0.3)
            diamond?.setIdle()
        }
    }

    // MARK: - Subagent Events (P4-T4-06/07)

    private func onSubagentsStarted(count: Int) {
        diamond?.splitInto(count: count)

        // Creature reaction is handled by HookEventProcessor (eyes widen)
        NSLog("[Pushling/Reactions] Subagents started: %d — diamond splitting", count)
    }

    private func onSubagentsStopped() {
        diamond?.reconverge()
        NSLog("[Pushling/Reactions] Subagents stopped — diamond reconverging")
    }

    // MARK: - Session Rejected (P4-T4-05)

    private func onSessionRejected(existingId: String, startedAgo: TimeInterval) {
        NSLog("[Pushling/Reactions] Session rejected — existing: %@ (%.0fs ago)",
              existingId, startedAgo)
    }

    // MARK: - Long Session Timer

    /// Starts a timer that triggers a grateful slow-blink every 30 minutes
    /// during long sessions.
    private func startLongSessionTimer() {
        stopLongSessionTimer()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        // First fire at 60 minutes, then every 30 minutes
        timer.schedule(deadline: .now() + 3600, repeating: 1800)
        timer.setEventHandler { [weak self] in
            self?.triggerLongSessionAppreciation()
        }
        timer.resume()
        longSessionTimer = timer
    }

    private func stopLongSessionTimer() {
        longSessionTimer?.cancel()
        longSessionTimer = nil
    }

    /// Grateful slow-blink — subtle appreciation for long sessions.
    private func triggerLongSessionAppreciation() {
        let t = CACurrentMediaTime()
        let slowBlink = ReflexDefinition(
            name: "long_session_blink",
            duration: 2.0,
            fadeoutFraction: 0.3,
            output: {
                var o = LayerOutput()
                o.eyeLeftState = "slow_blink"
                o.eyeRightState = "slow_blink"
                return o
            }()
        )
        reflexLayer?.trigger(slowBlink, at: t)
        NSLog("[Pushling/Reactions] Long session appreciation — slow blink")
    }

    // MARK: - Cleanup

    deinit {
        stopLongSessionTimer()
    }
}
