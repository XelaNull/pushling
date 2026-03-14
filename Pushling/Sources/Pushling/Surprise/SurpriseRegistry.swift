// SurpriseRegistry.swift — Registers all 78 surprises
// Each surprise has: ID, category, stage gate, eligibility, animation.
// This file ONLY contains the registration logic and static factory.
// Individual animation builders are in category-specific files.

import Foundation
import CoreGraphics

// MARK: - Surprise Registry

enum SurpriseRegistry {

    /// Register all 78 surprises into the scheduler.
    static func registerAll(into scheduler: SurpriseScheduler) {
        // Visual surprises (1-12)
        scheduler.registerAll(VisualSurprises.all)

        // Contextual surprises (13-26)
        scheduler.registerAll(ContextualSurprises.all)

        // Cat-specific surprises (27-42)
        scheduler.registerAll(CatSurprises.all)

        // Milestone surprises (43-48)
        scheduler.registerAll(MilestoneSurprises.all)

        // Time-based surprises (49-57)
        scheduler.registerAll(TimeSurprises.all)

        // Easter egg surprises (58-66)
        scheduler.registerAll(EasterEggSurprises.all)

        // Hook-aware surprises (67-72)
        scheduler.registerAll(HookSurprises.all)

        // Collaborative surprises (73-78)
        scheduler.registerAll(CollaborativeSurprises.all)

        NSLog("[Pushling/Surprise] Registered %d surprises across %d categories",
              scheduler.registeredCount, SurpriseCategory.allCases.count)
    }
}

// MARK: - Keyframe Builder

/// A mutable builder for constructing SurpriseKeyframes.
/// Uses struct-mutation pattern so parameters can be set in any order.
struct KF {
    var time: TimeInterval = 0
    var hold: TimeInterval = 0.5
    var eyes: String?
    var ears: String?
    var mouth: String?
    var tail: String?
    var whiskers: String?
    var body: String?
    var paws: [String: String]?
    var speed: CGFloat?
    var facing: Direction?
    var speech: String?
    var speechStyle: SpeechStyle?
    var easing: SurpriseEasing = .easeInOut

    /// Build the SurpriseKeyframe.
    func build() -> SurpriseKeyframe {
        var output = LayerOutput()
        output.eyeLeftState = eyes
        output.eyeRightState = eyes
        output.earLeftState = ears
        output.earRightState = ears
        output.mouthState = mouth
        output.tailState = tail
        output.whiskerState = whiskers
        output.bodyState = body
        output.pawStates = paws
        output.walkSpeed = speed
        output.facing = facing
        return SurpriseKeyframe(at: time, hold: hold, output: output,
                                speech: speech, speechStyle: speechStyle,
                                easing: easing)
    }

    /// Convenience: build a "return to normal" keyframe at a given time.
    static func normal(at time: TimeInterval) -> SurpriseKeyframe {
        var kf = KF()
        kf.time = time
        kf.hold = 0.5
        kf.eyes = "open"
        kf.ears = "neutral"
        kf.mouth = "closed"
        kf.tail = "sway"
        kf.body = "stand"
        kf.paws = ["fl": "ground", "fr": "ground",
                    "bl": "ground", "br": "ground"]
        kf.speed = 0
        return kf.build()
    }

    /// Convenience: build a speech-only keyframe.
    static func say(_ text: String, at time: TimeInterval,
                    hold: TimeInterval = 2.0,
                    style: SpeechStyle = .say) -> SurpriseKeyframe {
        var kf = KF()
        kf.time = time
        kf.hold = hold
        kf.speech = text
        kf.speechStyle = style
        return kf.build()
    }
}

// MARK: - Convenience Functions

/// Shorthand for building a KF at a specific time.
func kf(_ time: TimeInterval, _ hold: TimeInterval = 0.5,
        configure: (inout KF) -> Void) -> SurpriseKeyframe {
    var builder = KF()
    builder.time = time
    builder.hold = hold
    configure(&builder)
    return builder.build()
}
