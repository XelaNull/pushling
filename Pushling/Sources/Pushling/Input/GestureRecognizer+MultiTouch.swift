// GestureRecognizer+MultiTouch.swift — Pinch and two-finger drag detection
// Classifies two-finger gestures into pinch-zoom, two-finger drag, or belly rub.
//
// When activeTouchCount == 2:
//   - Inter-touch distance change > 5pt = pinch zoom
//   - Both touches moving same direction > 10pt = two-finger drag
//   - Neither condition met = belly rub (existing multiFingerTwo behavior)
//
// This extension adds state tracking for multi-touch classification
// without modifying the core GestureRecognizer's single-touch logic.

import Foundation
import CoreGraphics

// MARK: - Multi-Touch State

/// Tracks state for two-finger gesture classification.
struct MultiTouchState {
    /// Initial distance between two fingers at gesture start.
    var initialDistance: CGFloat = 0

    /// Current distance between two fingers.
    var currentDistance: CGFloat = 0

    /// Initial midpoint of the two touches.
    var initialMidpoint: CGPoint = .zero

    /// Current midpoint of the two touches.
    var currentMidpoint: CGPoint = .zero

    /// Accumulated distance change since gesture start.
    var distanceChange: CGFloat {
        currentDistance - initialDistance
    }

    /// Accumulated midpoint displacement since gesture start.
    var midpointDisplacement: CGFloat {
        hypot(currentMidpoint.x - initialMidpoint.x,
              currentMidpoint.y - initialMidpoint.y)
    }

    /// Whether the gesture has been classified.
    var isClassified: Bool = false

    /// The resolved gesture type (nil until classified).
    var resolvedType: GestureType?

    // MARK: - Classification Thresholds

    /// Minimum distance change to classify as pinch.
    private static let pinchThreshold: CGFloat = 5.0

    /// Minimum midpoint displacement to classify as two-finger drag.
    private static let dragThreshold: CGFloat = 10.0

    /// Attempts to classify the gesture based on current state.
    /// Returns the classified gesture type, or nil if not yet determined.
    mutating func classify() -> GestureType? {
        guard !isClassified else { return resolvedType }

        // Pinch: inter-touch distance changed significantly
        if abs(distanceChange) > Self.pinchThreshold {
            isClassified = true
            resolvedType = .pinchZoom
            return .pinchZoom
        }

        // Two-finger drag: both fingers moving in the same direction
        if midpointDisplacement > Self.dragThreshold {
            isClassified = true
            resolvedType = .twoFingerDrag
            return .twoFingerDrag
        }

        return nil
    }

    /// Creates initial state from two touch positions.
    static func begin(touch1: CGPoint, touch2: CGPoint) -> MultiTouchState {
        let dist = hypot(touch2.x - touch1.x, touch2.y - touch1.y)
        let mid = CGPoint(x: (touch1.x + touch2.x) / 2,
                          y: (touch1.y + touch2.y) / 2)
        return MultiTouchState(
            initialDistance: dist,
            currentDistance: dist,
            initialMidpoint: mid,
            currentMidpoint: mid
        )
    }

    /// Updates state with new touch positions.
    mutating func update(touch1: CGPoint, touch2: CGPoint) {
        currentDistance = hypot(touch2.x - touch1.x, touch2.y - touch1.y)
        currentMidpoint = CGPoint(x: (touch1.x + touch2.x) / 2,
                                   y: (touch1.y + touch2.y) / 2)
    }
}
