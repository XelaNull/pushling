// ExploredRangeTracker.swift — Tracks explored world territory as 1D ranges
// Used by FogOfWarController to determine which parts of the world the creature
// has visited. Explored areas remain partially visible even when distant.
//
// Pure data structure — no SpriteKit dependency. Sorted, non-overlapping ranges
// with O(log n) insert and coalescing of adjacent/overlapping segments.

import Foundation

// MARK: - Explored Range Tracker

/// Tracks explored territory as a sorted array of non-overlapping 1D ranges.
/// Thread-unsafe — call only from the main (scene update) thread.
final class ExploredRangeTracker {

    // MARK: - Range

    /// A contiguous explored segment in world-X space.
    struct Range {
        var minX: CGFloat
        var maxX: CGFloat

        /// Width of this explored segment.
        var width: CGFloat { maxX - minX }

        /// Whether this range contains a given point.
        func contains(_ x: CGFloat) -> Bool {
            x >= minX && x <= maxX
        }

        /// Whether this range overlaps or is adjacent to another range.
        /// Adjacent = ranges touch within a 1pt tolerance (to avoid micro-gaps).
        func overlapsOrAdjacent(_ other: Range) -> Bool {
            minX <= other.maxX + 1.0 && maxX >= other.minX - 1.0
        }

        /// Merge another range into this one (union).
        mutating func merge(with other: Range) {
            minX = Swift.min(minX, other.minX)
            maxX = Swift.max(maxX, other.maxX)
        }
    }

    // MARK: - State

    /// Sorted array of non-overlapping explored ranges (sorted by minX).
    private(set) var ranges: [Range] = []

    // MARK: - Expand

    /// Expand explored territory around a center point.
    /// Merges overlapping/adjacent ranges automatically.
    /// - Parameters:
    ///   - center: The world-X center of the new explored area.
    ///   - radius: The exploration radius around center.
    /// - Returns: True if new territory was discovered (ranges changed).
    @discardableResult
    func expand(center: CGFloat, radius: CGFloat) -> Bool {
        guard radius > 0 else { return false }

        let newRange = Range(minX: center - radius, maxX: center + radius)

        // Binary search for the insertion point
        let insertIdx = insertionIndex(for: newRange.minX)

        // Find all ranges that overlap or are adjacent to the new range
        var mergeStart = insertIdx
        var mergeEnd = insertIdx

        // Scan backward to find earlier ranges that overlap
        while mergeStart > 0 && ranges[mergeStart - 1].overlapsOrAdjacent(newRange) {
            mergeStart -= 1
        }

        // Scan forward to find later ranges that overlap
        while mergeEnd < ranges.count && ranges[mergeEnd].overlapsOrAdjacent(newRange) {
            mergeEnd += 1
        }

        if mergeStart == mergeEnd {
            // No overlapping ranges — insert the new range
            ranges.insert(newRange, at: insertIdx)
            return true
        }

        // Merge all overlapping ranges into one
        var merged = newRange
        for i in mergeStart..<mergeEnd {
            merged.merge(with: ranges[i])
        }

        // Check if anything actually changed (optimization for common case
        // where creature is wandering within already-explored territory)
        if mergeEnd - mergeStart == 1 {
            let existing = ranges[mergeStart]
            if existing.minX <= merged.minX + 0.5
                && existing.maxX >= merged.maxX - 0.5 {
                return false  // No meaningful change
            }
        }

        // Replace the overlapping range(s) with the merged result
        ranges.replaceSubrange(mergeStart..<mergeEnd, with: [merged])
        return true
    }

    // MARK: - Query

    /// Check if a world-X point has been explored.
    /// Uses binary search for O(log n) performance.
    func isExplored(at worldX: CGFloat) -> Bool {
        guard !ranges.isEmpty else { return false }

        // Binary search: find the last range whose minX <= worldX
        var lo = 0
        var hi = ranges.count - 1

        while lo <= hi {
            let mid = (lo + hi) / 2
            if ranges[mid].minX <= worldX {
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }

        // hi is now the index of the last range with minX <= worldX
        guard hi >= 0 else { return false }
        return ranges[hi].contains(worldX)
    }

    /// Total explored distance (sum of all range widths).
    var totalExploredDistance: CGFloat {
        ranges.reduce(0) { $0 + $1.width }
    }

    /// Number of distinct explored segments.
    var segmentCount: Int { ranges.count }

    // MARK: - Reset

    /// Clear all explored territory.
    func reset() {
        ranges.removeAll()
    }

    // MARK: - Serialization

    /// Serialize to a JSON string for persistence.
    func toJSON() -> String {
        let pairs = ranges.map { "[\($0.minX),\($0.maxX)]" }
        return "[\(pairs.joined(separator: ","))]"
    }

    /// Deserialize from a JSON string.
    /// Expected format: `[[minX,maxX],[minX,maxX],...]`
    static func fromJSON(_ json: String) -> ExploredRangeTracker {
        let tracker = ExploredRangeTracker()
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[Double]]
        else {
            return tracker
        }

        for pair in array {
            guard pair.count == 2 else { continue }
            tracker.ranges.append(Range(
                minX: CGFloat(pair[0]),
                maxX: CGFloat(pair[1])
            ))
        }
        return tracker
    }

    // MARK: - Private: Binary Search

    /// Find the insertion index for a range with the given minX.
    /// Returns the index where a range with this minX should be inserted
    /// to maintain sorted order.
    private func insertionIndex(for minX: CGFloat) -> Int {
        var lo = 0
        var hi = ranges.count

        while lo < hi {
            let mid = (lo + hi) / 2
            if ranges[mid].minX < minX {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo
    }
}
