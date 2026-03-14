// TouchTracker.swift — Core touch tracking at 60Hz with sub-pixel precision
// Manages active touches, computes velocity via EMA, converts normalized
// Touch Bar coordinates to scene coordinates (1085x30 points).
// Supports up to 3 simultaneous touches (hardware limit).

import Foundation
import CoreGraphics

// MARK: - Touch State

/// Represents a single active touch being tracked at 60Hz.
struct TouchState {
    /// Unique identity for this touch (from NSTouch).
    let id: ObjectIdentifier

    /// Where the touch began in scene coordinates.
    let startPosition: CGPoint

    /// Current position in scene coordinates (updated every frame).
    var currentPosition: CGPoint

    /// Position on the previous frame (for delta/velocity).
    var previousPosition: CGPoint

    /// Scene time when this touch began.
    let startTime: TimeInterval

    /// Running duration since touch began.
    var duration: TimeInterval

    /// Current velocity in points/second (EMA-smoothed over 4 frames).
    var velocity: CGVector

    /// Cumulative distance traveled since touch began.
    var totalDistance: CGFloat

    /// Whether this touch started on the creature's hitbox.
    var isOnCreature: Bool

    /// Whether this touch started on a world object.
    var isOnObject: Bool

    /// ID of the touched world object, if any.
    var objectId: String?

    /// Speed magnitude in points/second.
    var speed: CGFloat {
        sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
    }
}

// MARK: - Touch Phase

/// The phase of a touch event for gesture processing.
enum TouchPhase {
    case began
    case moved
    case ended
    case cancelled
}

// MARK: - Touch Event

/// A processed touch event dispatched to the gesture recognizer.
struct TouchEvent {
    let phase: TouchPhase
    let state: TouchState
    let timestamp: TimeInterval
    let activeTouchCount: Int
}

// MARK: - Touch Tracker

/// Tracks all active touches at 60Hz, computing position, velocity, and
/// duration. Converts normalized Touch Bar coordinates to scene coordinates.
/// Thread-safe: called from the touch event pipeline on the main thread.
final class TouchTracker {

    // MARK: - Constants

    /// Maximum simultaneous touches the Touch Bar supports.
    private static let maxTouches = 3

    /// Touch Bar scene dimensions.
    private static let sceneWidth: CGFloat = 1085.0
    private static let sceneHeight: CGFloat = 30.0

    /// EMA smoothing factor for velocity (4-frame average -> alpha ~0.4).
    private static let velocityAlpha: CGFloat = 0.4

    // MARK: - State

    /// Currently active touches keyed by their identity.
    private(set) var activeTouches: [ObjectIdentifier: TouchState] = [:]

    /// Delegate that receives processed touch events.
    weak var delegate: TouchTrackerDelegate?

    /// Creature hitbox provider for hit-testing on touch-began.
    var creatureHitbox: CGRect = .zero

    /// World object hit-test callback: returns (isObject, objectId) for a point.
    var objectHitTest: ((CGPoint) -> (Bool, String?))? = nil

    /// Number of currently active touches.
    var activeTouchCount: Int { activeTouches.count }

    /// Whether any touches are currently active.
    var hasActiveTouches: Bool { !activeTouches.isEmpty }

    // MARK: - Coordinate Conversion

    /// Converts a normalized Touch Bar position (0-1, 0-1) to scene coords.
    /// Touch Bar normalizedPosition: x = 0..1 left-to-right, y = 0..1.
    static func scenePoint(from normalizedPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: normalizedPosition.x * sceneWidth,
            y: normalizedPosition.y * sceneHeight
        )
    }

    // MARK: - Touch Lifecycle

    /// Called when a new touch begins.
    /// - Parameters:
    ///   - id: The touch's unique identity (ObjectIdentifier of NSTouch).
    ///   - normalizedPosition: Position in 0-1 normalized Touch Bar space.
    ///   - currentTime: Scene time.
    func touchBegan(id: ObjectIdentifier,
                    normalizedPosition: CGPoint,
                    currentTime: TimeInterval) {
        guard activeTouches.count < Self.maxTouches else { return }

        let scenePos = Self.scenePoint(from: normalizedPosition)

        // Hit-test creature (with 4pt padding for generous hitbox)
        let paddedCreature = creatureHitbox.insetBy(dx: -4, dy: -4)
        let isOnCreature = paddedCreature.contains(scenePos)

        // Hit-test world objects
        var isOnObject = false
        var objectId: String? = nil
        if let hitTest = objectHitTest {
            let result = hitTest(scenePos)
            isOnObject = result.0
            objectId = result.1
        }

        let state = TouchState(
            id: id,
            startPosition: scenePos,
            currentPosition: scenePos,
            previousPosition: scenePos,
            startTime: currentTime,
            duration: 0,
            velocity: .zero,
            totalDistance: 0,
            isOnCreature: isOnCreature,
            isOnObject: isOnObject,
            objectId: objectId
        )

        activeTouches[id] = state

        let event = TouchEvent(
            phase: .began,
            state: state,
            timestamp: currentTime,
            activeTouchCount: activeTouches.count
        )
        delegate?.touchTracker(self, didProcess: event)
    }

    /// Called when an existing touch moves.
    func touchMoved(id: ObjectIdentifier,
                    normalizedPosition: CGPoint,
                    currentTime: TimeInterval) {
        guard var state = activeTouches[id] else { return }

        let newPos = Self.scenePoint(from: normalizedPosition)
        let dt = currentTime - state.startTime - state.duration
        guard dt > 0 else { return }

        // Update position history
        state.previousPosition = state.currentPosition
        state.currentPosition = newPos
        state.duration = currentTime - state.startTime

        // Compute distance delta
        let dx = newPos.x - state.previousPosition.x
        let dy = newPos.y - state.previousPosition.y
        let dist = sqrt(dx * dx + dy * dy)
        state.totalDistance += dist

        // Compute instantaneous velocity
        let instantVx = dx / CGFloat(dt)
        let instantVy = dy / CGFloat(dt)

        // EMA smoothing
        let alpha = Self.velocityAlpha
        state.velocity = CGVector(
            dx: alpha * instantVx + (1 - alpha) * state.velocity.dx,
            dy: alpha * instantVy + (1 - alpha) * state.velocity.dy
        )

        activeTouches[id] = state

        let event = TouchEvent(
            phase: .moved,
            state: state,
            timestamp: currentTime,
            activeTouchCount: activeTouches.count
        )
        delegate?.touchTracker(self, didProcess: event)
    }

    /// Called when a touch ends (finger lifted).
    func touchEnded(id: ObjectIdentifier,
                    normalizedPosition: CGPoint,
                    currentTime: TimeInterval) {
        guard var state = activeTouches[id] else { return }

        let endPos = Self.scenePoint(from: normalizedPosition)
        state.currentPosition = endPos
        state.duration = currentTime - state.startTime

        activeTouches.removeValue(forKey: id)

        let event = TouchEvent(
            phase: .ended,
            state: state,
            timestamp: currentTime,
            activeTouchCount: activeTouches.count
        )
        delegate?.touchTracker(self, didProcess: event)
    }

    /// Called when a touch is cancelled (system interruption).
    func touchCancelled(id: ObjectIdentifier, currentTime: TimeInterval) {
        guard let state = activeTouches[id] else { return }

        activeTouches.removeValue(forKey: id)

        let event = TouchEvent(
            phase: .cancelled,
            state: state,
            timestamp: currentTime,
            activeTouchCount: activeTouches.count
        )
        delegate?.touchTracker(self, didProcess: event)
    }

    /// Clears all active touches (e.g., on scene transition).
    func reset() {
        activeTouches.removeAll()
    }
}

// MARK: - Delegate Protocol

/// Receives processed touch events from the TouchTracker.
protocol TouchTrackerDelegate: AnyObject {
    func touchTracker(_ tracker: TouchTracker, didProcess event: TouchEvent)
}
