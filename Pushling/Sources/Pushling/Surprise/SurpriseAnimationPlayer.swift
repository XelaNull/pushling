// SurpriseAnimationPlayer.swift — Executes surprise animations
// Bridges the surprise system to the behavior stack.
//
// Short surprises (<10s) are injected as ReflexDefinitions.
// Long surprises (>=10s) inject a series of reflexes over time.
// Speech is routed through SpeechCoordinator.
//
// The player tracks the currently playing surprise and prevents
// overlapping surprise animations.

import Foundation
import CoreGraphics

// MARK: - Surprise Animation Player

final class SurpriseAnimationPlayer {

    // MARK: - State

    /// Whether a surprise is currently playing.
    private(set) var isPlaying = false

    /// The currently playing surprise's keyframes.
    private var currentKeyframes: [SurpriseKeyframe] = []

    /// Current keyframe index.
    private var currentKeyframeIndex = 0

    /// Time elapsed since surprise started.
    private var elapsedTime: TimeInterval = 0

    /// Total duration of current surprise.
    private var totalDuration: TimeInterval = 0

    /// Speech pending from current keyframe.
    private var pendingSpeech: (String, SpeechStyle)?

    /// The surprise ID currently playing (for logging).
    private var currentSurpriseId: Int = 0

    /// The current surprise name (for logging).
    private var currentSurpriseName: String = ""

    // MARK: - Callbacks

    /// Called to inject a reflex into the behavior stack.
    var onInjectReflex: ((_ definition: ReflexDefinition,
                          _ sceneTime: TimeInterval) -> Void)?

    /// Called to trigger speech.
    var onSpeak: ((_ text: String, _ style: SpeechStyle) -> Void)?

    /// Called when surprise animation completes.
    var onComplete: ((_ surpriseId: Int) -> Void)?

    // MARK: - Play

    /// Start playing a surprise animation.
    func play(surpriseId: Int, name: String,
              animation: SurpriseAnimation,
              sceneTime: TimeInterval) {
        guard !isPlaying else {
            NSLog("[Pushling/Surprise] Cannot play #%d — already playing #%d",
                  surpriseId, currentSurpriseId)
            return
        }

        currentKeyframes = animation.keyframes
        currentKeyframeIndex = 0
        elapsedTime = 0
        totalDuration = animation.totalDuration
        currentSurpriseId = surpriseId
        currentSurpriseName = name
        isPlaying = true

        NSLog("[Pushling/Surprise] Playing #%d '%@' (%.1fs, %d keyframes)",
              surpriseId, name, totalDuration, currentKeyframes.count)

        // Inject the first keyframe immediately
        advanceKeyframes(sceneTime: sceneTime)

        // Play initial speech if any
        if let speech = animation.speech {
            let style = animation.speechStyle ?? .say
            onSpeak?(speech, style)
        }
    }

    // MARK: - Frame Update

    /// Called every frame to advance the surprise animation.
    func update(deltaTime: TimeInterval, sceneTime: TimeInterval) {
        guard isPlaying else { return }

        elapsedTime += deltaTime

        // Check if we've reached the next keyframe
        advanceKeyframes(sceneTime: sceneTime)

        // Deliver pending speech
        if let (text, style) = pendingSpeech {
            onSpeak?(text, style)
            pendingSpeech = nil
        }

        // Check for completion
        if elapsedTime >= totalDuration {
            complete()
        }
    }

    // MARK: - Advance Keyframes

    /// Advances through keyframes that should be active at current time.
    private func advanceKeyframes(sceneTime: TimeInterval) {
        while currentKeyframeIndex < currentKeyframes.count {
            let kf = currentKeyframes[currentKeyframeIndex]

            guard elapsedTime >= kf.timestamp else { break }

            // This keyframe is now active — inject as reflex
            let reflexDuration = kf.holdDuration
            let reflex = ReflexDefinition(
                name: "surprise_\(currentSurpriseId)_kf\(currentKeyframeIndex)",
                duration: reflexDuration,
                fadeoutFraction: 0.15,
                output: kf.output
            )
            onInjectReflex?(reflex, sceneTime)

            // Queue speech from this keyframe
            if let speech = kf.speech {
                let style = kf.speechStyle ?? .say
                pendingSpeech = (speech, style)
            }

            currentKeyframeIndex += 1
        }
    }

    // MARK: - Complete

    /// Called when the surprise animation finishes.
    private func complete() {
        let id = currentSurpriseId
        NSLog("[Pushling/Surprise] Completed #%d '%@'",
              id, currentSurpriseName)

        isPlaying = false
        currentKeyframes = []
        currentKeyframeIndex = 0
        elapsedTime = 0
        totalDuration = 0
        currentSurpriseId = 0
        currentSurpriseName = ""
        pendingSpeech = nil

        onComplete?(id)
    }

    // MARK: - Cancel

    /// Force-cancel the current surprise (e.g., evolution ceremony starting).
    func cancel() {
        guard isPlaying else { return }
        NSLog("[Pushling/Surprise] Cancelled #%d '%@'",
              currentSurpriseId, currentSurpriseName)
        isPlaying = false
        currentKeyframes = []
        currentKeyframeIndex = 0
        elapsedTime = 0
        currentSurpriseId = 0
        currentSurpriseName = ""
        pendingSpeech = nil
    }

    // MARK: - Query

    /// The ID of the currently playing surprise, or nil.
    var playingSurpriseId: Int? {
        isPlaying ? currentSurpriseId : nil
    }
}
