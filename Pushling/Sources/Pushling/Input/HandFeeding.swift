// HandFeeding.swift — Drag commit text toward creature for +10% XP bonus
// Touch on drifting commit text stops autonomous drift. Drag toward creature.
// Within 15pt of creature mouth = eating begins. +10% XP, +5 contentment.
// If finger lifts away from creature, text resumes autonomous drift.

import SpriteKit

// MARK: - Hand Feeding

/// Manages the hand-feeding interaction: drag commit text toward the creature
/// for a bonus XP reward and intimacy boost.
final class HandFeeding {

    // MARK: - Constants

    /// Distance from creature mouth that triggers eating.
    private static let eatDistance: CGFloat = 15.0

    /// XP bonus multiplier for hand-feeding.
    static let xpBonusMultiplier: Double = 1.1

    /// Contentment boost for hand-feeding.
    static let contentmentBoost: Double = 5.0

    // MARK: - State

    /// Whether a commit text node is currently being held/dragged.
    private(set) var isHolding = false

    /// The commit text node being dragged.
    private weak var heldTextNode: SKNode?

    /// Offset from touch point to text node center.
    private var holdOffset: CGPoint = .zero

    /// The SHA associated with the held commit text.
    private(set) var heldCommitSHA: String?

    /// Callback for hand-feeding events.
    var onFeedingEvent: ((FeedingEvent) -> Void)?

    // MARK: - Feeding Events

    enum FeedingEvent {
        case grabbed(sha: String)
        case dragging(position: CGPoint)
        case fed(sha: String)           // Within eating distance
        case released(position: CGPoint) // Released away from creature
    }

    // MARK: - Touch Handling

    /// Attempts to grab a drifting commit text node at the touch point.
    /// - Parameters:
    ///   - touchPoint: Where the human touched.
    ///   - commitTextNodes: Active commit text nodes in the scene.
    /// - Returns: Whether a commit text was grabbed.
    func tryGrab(at touchPoint: CGPoint,
                 commitTextNodes: [SKNode]) -> Bool {
        for node in commitTextNodes {
            let frame = node.calculateAccumulatedFrame()
            let padded = frame.insetBy(dx: -4, dy: -4)
            if padded.contains(touchPoint) {
                heldTextNode = node
                isHolding = true
                holdOffset = CGPoint(
                    x: node.position.x - touchPoint.x,
                    y: node.position.y - touchPoint.y
                )
                heldCommitSHA = node.name  // Commit nodes named by SHA

                // Stop autonomous drift by removing existing movement actions
                node.removeAllActions()

                onFeedingEvent?(.grabbed(sha: heldCommitSHA ?? "unknown"))
                NSLog("[Pushling/Input] Hand-feeding: grabbed commit text")
                return true
            }
        }
        return false
    }

    /// Moves the held commit text toward the touch position.
    func dragTo(_ touchPoint: CGPoint) {
        guard isHolding, let node = heldTextNode else { return }

        let newPos = CGPoint(
            x: touchPoint.x + holdOffset.x,
            y: touchPoint.y + holdOffset.y
        )
        node.position = newPos
        onFeedingEvent?(.dragging(position: newPos))
    }

    /// Releases the held commit text.
    /// - Parameter creaturePosition: The creature's position for distance check.
    /// - Returns: Whether the commit was fed (within eating distance).
    @discardableResult
    func release(creaturePosition: CGPoint) -> Bool {
        guard isHolding, let node = heldTextNode else { return false }

        let distance = hypot(
            node.position.x - creaturePosition.x,
            node.position.y - creaturePosition.y
        )

        isHolding = false
        let sha = heldCommitSHA ?? "unknown"

        if distance < Self.eatDistance {
            // Feed! The creature eats from hand
            onFeedingEvent?(.fed(sha: sha))
            heldTextNode = nil
            heldCommitSHA = nil
            NSLog("[Pushling/Input] Hand-feeding: commit fed! +10%% XP")
            return true
        } else {
            // Released away — resume autonomous drift
            onFeedingEvent?(.released(position: node.position))
            heldTextNode = nil
            heldCommitSHA = nil
            NSLog("[Pushling/Input] Hand-feeding: commit released, resumes drift")
            return false
        }
    }

    /// Cancels any active hand-feeding.
    func cancel() {
        isHolding = false
        heldTextNode = nil
        heldCommitSHA = nil
    }
}
