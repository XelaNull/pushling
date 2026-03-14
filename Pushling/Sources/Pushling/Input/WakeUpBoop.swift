// WakeUpBoop.swift — Tap sleeping creature's nose for 3-tap progressive wake
// Tap 1: nose twitch, one eye opens halfway. Tap 2: both eyes, stretch, yawn.
// Tap 3: big yawn, fully awake. 5s timeout between taps or creature resettles.
// Sets contentment +10 and energy >= 30 (gentle wake).

import Foundation
import CoreGraphics

// MARK: - Wake Up Boop

/// Manages the gentle 3-tap wake-up sequence for a sleeping creature.
/// Each tap produces a progressive wake response. If the human waits
/// too long (>5s), the creature resettles to sleep.
final class WakeUpBoop {

    // MARK: - Constants

    private static let maxTimeBetweenTaps: TimeInterval = 5.0
    private static let tap1Duration: TimeInterval = 0.8
    private static let tap2Duration: TimeInterval = 1.5
    private static let tap3Duration: TimeInterval = 2.0
    private static let contentmentBoost: Double = 10.0
    private static let minimumEnergy: Double = 30.0

    // MARK: - State

    /// Current tap count in the wake sequence (0 = no boop started).
    private(set) var tapCount = 0

    /// Time of the last boop tap.
    private var lastTapTime: TimeInterval = 0

    /// Whether the wake sequence is complete (creature is awake).
    private(set) var isComplete = false

    /// Callback for wake events.
    var onWakeEvent: ((WakeEvent) -> Void)?

    // MARK: - Wake Events

    enum WakeEvent {
        /// Tap 1: nose twitches, one eye opens halfway, ear flick. Resettles.
        case firstBoop

        /// Tap 2: both eyes open partway, full body stretch, yawn. Eyes close.
        case secondBoop

        /// Tap 3: big yawn, eyes open, stand up, stretch, shake head. Awake!
        case thirdBoop

        /// Creature resettles to full sleep (timeout expired).
        case resettle

        /// Wake sequence complete — apply stat boosts.
        case awake(contentmentBoost: Double, minimumEnergy: Double)
    }

    // MARK: - Boop

    /// Handles a tap on the sleeping creature.
    /// - Parameters:
    ///   - isSleeping: Whether the creature is currently asleep.
    ///   - isNoseArea: Whether the tap hit the nose/head area.
    ///   - currentTime: Scene time for timeout tracking.
    /// - Returns: Whether the tap was consumed by the wake sequence.
    func handleTap(isSleeping: Bool, isNoseArea: Bool,
                   currentTime: TimeInterval) -> Bool {
        guard isSleeping else {
            reset()
            return false
        }

        guard isNoseArea else { return false }

        // Check timeout
        if tapCount > 0
            && (currentTime - lastTapTime) > Self.maxTimeBetweenTaps {
            reset()
            onWakeEvent?(.resettle)
        }

        lastTapTime = currentTime
        tapCount += 1

        switch tapCount {
        case 1:
            onWakeEvent?(.firstBoop)
            NSLog("[Pushling/Input] Wake boop: tap 1 — nose twitch")
            return true

        case 2:
            onWakeEvent?(.secondBoop)
            NSLog("[Pushling/Input] Wake boop: tap 2 — stretch and yawn")
            return true

        case 3:
            isComplete = true
            onWakeEvent?(.thirdBoop)
            onWakeEvent?(.awake(
                contentmentBoost: Self.contentmentBoost,
                minimumEnergy: Self.minimumEnergy
            ))
            NSLog("[Pushling/Input] Wake boop: tap 3 — AWAKE!")
            reset()
            return true

        default:
            return false
        }
    }

    // MARK: - Per-Frame Check

    /// Called each frame to check if the timeout has expired.
    func update(currentTime: TimeInterval, isSleeping: Bool) {
        guard isSleeping, tapCount > 0 else { return }

        if (currentTime - lastTapTime) > Self.maxTimeBetweenTaps {
            onWakeEvent?(.resettle)
            reset()
        }
    }

    // MARK: - Nose Area Hit Test

    /// Determines whether a touch point is in the "nose area" of the creature.
    /// The nose area is the top-center of the creature's hitbox.
    static func isNoseArea(touchPoint: CGPoint,
                           creatureHitbox: CGRect) -> Bool {
        // Nose = top-center third of the hitbox
        let noseRect = CGRect(
            x: creatureHitbox.midX - creatureHitbox.width * 0.3,
            y: creatureHitbox.midY,
            width: creatureHitbox.width * 0.6,
            height: creatureHitbox.height * 0.5
        )
        return noseRect.contains(touchPoint)
    }

    // MARK: - Reset

    func reset() {
        tapCount = 0
        isComplete = false
    }
}
