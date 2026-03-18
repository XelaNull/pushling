// GestureRecognizer.swift — Classifies raw touch events into gesture types
// Custom state machine for NSTouchBar (not UIGestureRecognizer).
// Handles tap/double-tap/triple-tap disambiguation with delayed commit,
// long press, sustained touch, drag, flick, petting, rapid taps, multi-finger.
// Priority: multi-finger > flick > rapid-tap > triple-tap > double-tap > tap > long-press > sustained > drag

import Foundation
import CoreGraphics

// MARK: - Gesture Types

/// All recognized gesture types.
enum GestureType: String {
    case tap
    case doubleTap
    case tripleTap
    case longPress
    case sustainedTouch
    case drag
    case slowDrag
    case flick
    case pettingStroke
    case multiFingerTwo
    case multiFingerThree
    case rapidTaps
    case pinchZoom
    case twoFingerDrag
}

// MARK: - Gesture Target

/// Where the gesture occurred relative to the creature and world.
enum GestureTarget {
    case creature
    case object(id: String)
    case world
    case commitText
}

// MARK: - Gesture Event

/// A fully recognized gesture dispatched to handlers.
struct GestureEvent {
    let type: GestureType
    let position: CGPoint
    let velocity: CGVector
    let touchCount: Int
    let duration: TimeInterval
    let target: GestureTarget
    let timestamp: TimeInterval
}

// MARK: - Gesture Recognizer

/// Classifies raw touch events from TouchTracker into discrete gestures.
/// Uses a delayed-commit pattern: single taps wait 300ms before committing
/// to allow double/triple-tap disambiguation.
final class GestureRecognizer: TouchTrackerDelegate {

    // MARK: - Thresholds

    private static let tapMaxDuration: TimeInterval = 0.2
    private static let tapMaxDistance: CGFloat = 5.0
    private static let doubleTapWindow: TimeInterval = 0.3
    private static let tripleTapWindow: TimeInterval = 0.45
    private static let doubleTapMaxSpacing: CGFloat = 10.0
    private static let longPressMinDuration: TimeInterval = 0.5
    private static let longPressMaxDistance: CGFloat = 5.0
    private static let sustainedMinDuration: TimeInterval = 2.0
    private static let sustainedMaxDistance: CGFloat = 8.0
    private static let dragMinDistance: CGFloat = 10.0
    private static let slowDragMaxSpeed: CGFloat = 100.0
    private static let flickMinSpeed: CGFloat = 200.0
    private static let pettingMaxSpeed: CGFloat = 100.0
    private static let pettingMinTravel: CGFloat = 15.0
    private static let rapidTapWindow: TimeInterval = 1.0
    private static let rapidTapMinCount = 3
    private static let rapidTapMaxSpread: CGFloat = 30.0

    // MARK: - State

    /// When true, all incoming touches are ignored (cinematic mode).
    var isSuppressed: Bool = false

    /// Delegate that receives recognized gestures.
    weak var delegate: GestureRecognizerDelegate?

    /// Milestone tracker for gesture gating.
    weak var milestoneTracker: MilestoneTracker?

    /// Pending tap for delayed commit (tap vs double-tap disambiguation).
    private var pendingTap: PendingTap?

    /// Timer for committing pending taps after the wait window.
    private var tapCommitTimer: Timer?

    /// Recent tap history for rapid-tap detection.
    private var recentTaps: [(position: CGPoint, time: TimeInterval)] = []

    /// Currently recognized multi-finger count.
    private var multiFingerCount = 0

    /// Two-finger gesture classification state (pinch / drag / belly rub).
    private var multiTouchState: MultiTouchState?

    /// Tracked positions for two-finger gestures, keyed by touch ID.
    private var twoFingerPositions: [ObjectIdentifier: CGPoint] = [:]

    /// Whether a two-finger gesture has been classified and dispatched.
    private var twoFingerClassified = false

    /// The target for the two-finger gesture (captured at began).
    private var twoFingerTarget: GestureTarget = .world

    /// Whether a drag gesture has been recognized for the current touch.
    private var activeDragTouchId: ObjectIdentifier?

    /// Whether a long press has already fired for the active touch.
    private var longPressFiredForTouch: ObjectIdentifier?

    /// Whether a sustained touch has already fired for the active touch.
    private var sustainedFiredForTouch: ObjectIdentifier?

    /// Reference to touch tracker for checking active state.
    private var lastKnownTouchCount = 0

    /// Creature hitbox reference for petting detection.
    var creatureHitbox: CGRect = .zero

    // MARK: - Pending Tap

    private struct PendingTap {
        let position: CGPoint
        let target: GestureTarget
        let timestamp: TimeInterval
        var count: Int
    }

    // MARK: - TouchTrackerDelegate

    func touchTracker(_ tracker: TouchTracker, didProcess event: TouchEvent) {
        guard !isSuppressed else { return }

        lastKnownTouchCount = event.activeTouchCount

        switch event.phase {
        case .began:
            handleTouchBegan(event)
        case .moved:
            handleTouchMoved(event)
        case .ended:
            handleTouchEnded(event)
        case .cancelled:
            handleTouchCancelled(event)
        }
    }

    // MARK: - Touch Began

    private func handleTouchBegan(_ event: TouchEvent) {
        // Multi-finger detection
        if event.activeTouchCount >= 3 {
            multiFingerCount = 3
            dispatchGesture(GestureEvent(
                type: .multiFingerThree,
                position: event.state.currentPosition,
                velocity: event.state.velocity,
                touchCount: 3,
                duration: 0,
                target: targetFor(event.state),
                timestamp: event.timestamp
            ))
            cancelPendingTap()
            return
        }

        if event.activeTouchCount >= 2 {
            multiFingerCount = 2
            twoFingerClassified = false
            twoFingerTarget = targetFor(event.state)

            // Track this finger's position
            twoFingerPositions[event.state.id] = event.state.currentPosition

            // Initialize MultiTouchState when we have 2 positions
            if twoFingerPositions.count >= 2 {
                let positions = Array(twoFingerPositions.values)
                multiTouchState = MultiTouchState.begin(
                    touch1: positions[0], touch2: positions[1]
                )
            }

            cancelPendingTap()
            return
        }

        multiFingerCount = 0
        activeDragTouchId = nil
        longPressFiredForTouch = nil
        sustainedFiredForTouch = nil
    }

    // MARK: - Touch Moved

    private func handleTouchMoved(_ event: TouchEvent) {
        let state = event.state

        // Two-finger gesture classification
        if multiFingerCount == 2 {
            // Update tracked position for this finger
            twoFingerPositions[state.id] = state.currentPosition

            // Update MultiTouchState with both positions
            if twoFingerPositions.count >= 2, var mts = multiTouchState {
                let positions = Array(twoFingerPositions.values)
                mts.update(touch1: positions[0], touch2: positions[1])
                multiTouchState = mts

                // Try to classify if not yet resolved
                if !twoFingerClassified, let gestureType = mts.classify() {
                    twoFingerClassified = true
                    multiTouchState = mts  // Save classified state
                    dispatchGesture(GestureEvent(
                        type: gestureType,
                        position: mts.currentMidpoint,
                        velocity: state.velocity,
                        touchCount: 2,
                        duration: state.duration,
                        target: twoFingerTarget,
                        timestamp: event.timestamp
                    ))
                } else if twoFingerClassified,
                          let resolvedType = mts.resolvedType {
                    // Continue dispatching the classified gesture type
                    dispatchGesture(GestureEvent(
                        type: resolvedType,
                        position: mts.currentMidpoint,
                        velocity: state.velocity,
                        touchCount: 2,
                        duration: state.duration,
                        target: twoFingerTarget,
                        timestamp: event.timestamp
                    ))
                }
            }
            return
        }

        // Skip 3+ finger moves
        guard multiFingerCount == 0 else { return }

        // Check for drag threshold
        if state.totalDistance > Self.dragMinDistance
            && activeDragTouchId == nil {
            activeDragTouchId = state.id
            cancelPendingTap()
        }

        // If dragging, classify the drag type
        if activeDragTouchId == state.id {
            // Check for petting stroke (slow drag across creature)
            let paddedCreature = creatureHitbox.insetBy(dx: -4, dy: -4)
            if state.speed < Self.pettingMaxSpeed
                && paddedCreature.contains(state.currentPosition)
                && state.totalDistance > Self.pettingMinTravel
                && isUnlocked(.petting) {
                dispatchGesture(GestureEvent(
                    type: .pettingStroke,
                    position: state.currentPosition,
                    velocity: state.velocity,
                    touchCount: 1,
                    duration: state.duration,
                    target: .creature,
                    timestamp: event.timestamp
                ))
            } else if state.speed < Self.slowDragMaxSpeed {
                dispatchGesture(GestureEvent(
                    type: .slowDrag,
                    position: state.currentPosition,
                    velocity: state.velocity,
                    touchCount: 1,
                    duration: state.duration,
                    target: targetFor(state),
                    timestamp: event.timestamp
                ))
            } else {
                dispatchGesture(GestureEvent(
                    type: .drag,
                    position: state.currentPosition,
                    velocity: state.velocity,
                    touchCount: 1,
                    duration: state.duration,
                    target: targetFor(state),
                    timestamp: event.timestamp
                ))
            }
        }
    }

    // MARK: - Touch Ended

    private func handleTouchEnded(_ event: TouchEvent) {
        let state = event.state

        // Multi-finger end — reset
        if multiFingerCount > 0 {
            // Remove this finger from tracking
            twoFingerPositions.removeValue(forKey: state.id)

            if event.activeTouchCount == 0 {
                // All fingers lifted — if two-finger was never classified,
                // dispatch as belly rub (original multiFingerTwo behavior)
                if multiFingerCount == 2 && !twoFingerClassified {
                    dispatchGesture(GestureEvent(
                        type: .multiFingerTwo,
                        position: state.currentPosition,
                        velocity: state.velocity,
                        touchCount: 2,
                        duration: state.duration,
                        target: twoFingerTarget,
                        timestamp: event.timestamp
                    ))
                }
                multiFingerCount = 0
                multiTouchState = nil
                twoFingerPositions.removeAll()
                twoFingerClassified = false
            }
            return
        }

        // Flick detection: fast drag ending mid-motion
        if activeDragTouchId == state.id && state.speed > Self.flickMinSpeed {
            dispatchGesture(GestureEvent(
                type: .flick,
                position: state.currentPosition,
                velocity: state.velocity,
                touchCount: 1,
                duration: state.duration,
                target: targetFor(state),
                timestamp: event.timestamp
            ))
            activeDragTouchId = nil
            return
        }

        // If we were dragging, end the drag — no tap
        if activeDragTouchId == state.id {
            activeDragTouchId = nil
            return
        }

        // Tap-like gesture: short duration, little distance
        if state.duration < Self.tapMaxDuration
            && state.totalDistance < Self.tapMaxDistance {
            handleTapCandidate(event)
            return
        }

        // Long press that ended
        if longPressFiredForTouch == state.id {
            longPressFiredForTouch = nil
            return
        }

        // Sustained touch that ended
        if sustainedFiredForTouch == state.id {
            sustainedFiredForTouch = nil
            return
        }

        activeDragTouchId = nil
    }

    // MARK: - Touch Cancelled

    private func handleTouchCancelled(_ event: TouchEvent) {
        activeDragTouchId = nil
        multiFingerCount = 0
        multiTouchState = nil
        twoFingerPositions.removeAll()
        twoFingerClassified = false
        cancelPendingTap()
    }

    // MARK: - Tap Disambiguation

    private func handleTapCandidate(_ event: TouchEvent) {
        let pos = event.state.currentPosition
        let target = targetFor(event.state)
        let time = event.timestamp

        // Add to rapid-tap history
        recentTaps.append((position: pos, time: time))
        pruneRecentTaps(before: time - Self.rapidTapWindow)

        // Check for rapid taps (3+ taps in 1 second within 30pt)
        if checkRapidTaps(at: time) {
            dispatchGesture(GestureEvent(
                type: .rapidTaps,
                position: pos,
                velocity: event.state.velocity,
                touchCount: 1,
                duration: 0,
                target: target,
                timestamp: time
            ))
            cancelPendingTap()
            recentTaps.removeAll()
            return
        }

        // Check if this extends a pending tap to double/triple
        if var pending = pendingTap {
            let dist = hypot(pos.x - pending.position.x,
                             pos.y - pending.position.y)
            if dist < Self.doubleTapMaxSpacing {
                pending.count += 1
                if pending.count >= 3 {
                    // Triple-tap — commit immediately
                    cancelPendingTap()
                    dispatchGesture(GestureEvent(
                        type: .tripleTap,
                        position: pos,
                        velocity: event.state.velocity,
                        touchCount: 1,
                        duration: 0,
                        target: target,
                        timestamp: time
                    ))
                    return
                }
                // Double-tap candidate — wait for possible triple
                pendingTap = pending
                resetTapTimer(deadline: Self.tripleTapWindow - Self.doubleTapWindow)
                return
            }
        }

        // New tap candidate — wait for possible double-tap
        cancelPendingTap()
        pendingTap = PendingTap(
            position: pos, target: target,
            timestamp: time, count: 1
        )
        resetTapTimer(deadline: Self.doubleTapWindow)
    }

    /// Commits the pending tap when the wait window expires.
    private func commitPendingTap() {
        guard let pending = pendingTap else { return }
        pendingTap = nil
        tapCommitTimer?.invalidate()
        tapCommitTimer = nil

        let type: GestureType
        switch pending.count {
        case 1: type = .tap
        case 2: type = .doubleTap
        default: type = .tripleTap
        }

        dispatchGesture(GestureEvent(
            type: type,
            position: pending.position,
            velocity: .zero,
            touchCount: 1,
            duration: 0,
            target: pending.target,
            timestamp: pending.timestamp
        ))
    }

    private func resetTapTimer(deadline: TimeInterval) {
        tapCommitTimer?.invalidate()
        tapCommitTimer = Timer.scheduledTimer(
            withTimeInterval: deadline,
            repeats: false
        ) { [weak self] _ in
            self?.commitPendingTap()
        }
    }

    private func cancelPendingTap() {
        pendingTap = nil
        tapCommitTimer?.invalidate()
        tapCommitTimer = nil
    }

    // MARK: - Rapid Tap Detection

    private func checkRapidTaps(at time: TimeInterval) -> Bool {
        let windowStart = time - Self.rapidTapWindow
        let recent = recentTaps.filter { $0.time >= windowStart }
        guard recent.count >= Self.rapidTapMinCount else { return false }

        // Check spatial spread
        let xs = recent.map { $0.position.x }
        guard let minX = xs.min(), let maxX = xs.max() else { return false }
        return (maxX - minX) < Self.rapidTapMaxSpread
    }

    private func pruneRecentTaps(before cutoff: TimeInterval) {
        recentTaps.removeAll { $0.time < cutoff }
    }

    // MARK: - Per-Frame Update

    /// Called each frame to check for long-press and sustained-touch
    /// on touches that are still held but haven't moved enough to be drags.
    func update(currentTime: TimeInterval, activeTouches: [ObjectIdentifier: TouchState]) {
        guard !isSuppressed else { return }
        guard multiFingerCount == 0 else { return }

        for (id, state) in activeTouches {
            guard activeDragTouchId != id else { continue }

            // Long press: held > 500ms, distance < 5pt
            if state.duration >= Self.longPressMinDuration
                && state.totalDistance < Self.longPressMaxDistance
                && longPressFiredForTouch != id {
                longPressFiredForTouch = id
                dispatchGesture(GestureEvent(
                    type: .longPress,
                    position: state.currentPosition,
                    velocity: .zero,
                    touchCount: 1,
                    duration: state.duration,
                    target: targetFor(state),
                    timestamp: currentTime
                ))
            }

            // Sustained touch: held > 2s, distance < 8pt
            if state.duration >= Self.sustainedMinDuration
                && state.totalDistance < Self.sustainedMaxDistance
                && sustainedFiredForTouch != id {
                sustainedFiredForTouch = id
                dispatchGesture(GestureEvent(
                    type: .sustainedTouch,
                    position: state.currentPosition,
                    velocity: .zero,
                    touchCount: 1,
                    duration: state.duration,
                    target: targetFor(state),
                    timestamp: currentTime
                ))
            }
        }
    }

    // MARK: - Helpers

    private func targetFor(_ state: TouchState) -> GestureTarget {
        if state.isOnCreature { return .creature }
        if state.isOnObject, let id = state.objectId {
            return .object(id: id)
        }
        return .world
    }

    private func isUnlocked(_ milestone: MilestoneID) -> Bool {
        milestoneTracker?.isUnlocked(milestone) ?? false
    }

    private func dispatchGesture(_ event: GestureEvent) {
        delegate?.gestureRecognizer(self, didRecognize: event)
    }
}

// MARK: - Delegate Protocol

/// Receives recognized gesture events.
protocol GestureRecognizerDelegate: AnyObject {
    func gestureRecognizer(_ recognizer: GestureRecognizer,
                           didRecognize event: GestureEvent)
}
