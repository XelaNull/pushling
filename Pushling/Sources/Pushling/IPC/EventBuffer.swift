// EventBuffer.swift — Ring buffer for pending events in Pushling IPC
// Thread-safe. Events are pushed from any thread (render, feed, hooks),
// drained from the socket thread when building IPC responses.
// Each session tracks its own cursor into the global event stream.

import Foundation

// MARK: - PushlingEvent

/// A single event that occurred in the Pushling world.
struct PushlingEvent {
    let seq: Int
    let type: String
    let timestamp: String  // ISO 8601
    let data: [String: Any]

    /// Convert to dictionary for JSON serialization.
    func toDictionary() -> [String: Any] {
        return [
            "seq": seq,
            "type": type,
            "timestamp": timestamp,
            "data": data
        ]
    }
}

// MARK: - EventBuffer

/// A fixed-capacity ring buffer of events with per-session cursor tracking.
///
/// Global events are pushed by the daemon whenever something interesting happens
/// (commits, touches, surprises, weather, evolution, etc.). Each connected MCP
/// session tracks the last event it has seen. When a response is built, all events
/// since the session's cursor are included and the cursor advances.
///
/// Thread safety: All public methods are protected by a mutex. The lock is lightweight
/// because push/drain operations are fast (no allocations in the common case).
///
/// Capacity: 100 events per the protocol spec. When full, the oldest event is dropped
/// and an `events_dropped` meta-event is injected or updated.
final class EventBuffer {

    // MARK: - Constants

    static let defaultCapacity = 100

    // MARK: - Properties

    private let capacity: Int
    private var events: [PushlingEvent?]
    private var head: Int = 0       // Next write position
    private var count: Int = 0      // Number of valid events
    private var nextSeq: Int = 1    // Monotonically increasing sequence number

    /// Per-session tracking: session_id -> last_seen_seq
    /// When draining, we return events with seq > last_seen_seq.
    private var sessionCursors: [String: Int] = [:]

    /// Tracks consecutive drops for the events_dropped coalescing logic
    private var consecutiveDropCount: Int = 0

    private let lock = NSLock()

    /// Cached ISO 8601 formatter — `ISO8601DateFormatter()` is expensive to create.
    /// Reused across all push/drain calls to avoid allocation under the lock.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Init

    init(capacity: Int = EventBuffer.defaultCapacity) {
        self.capacity = capacity
        self.events = [PushlingEvent?](repeating: nil, count: capacity)
    }

    // MARK: - Session Management

    /// Register a new session. Its cursor starts at the current sequence,
    /// so it will only see events that arrive after it connects.
    func addSession(_ sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        // Cursor = current next seq minus 1, meaning "has seen everything so far"
        sessionCursors[sessionId] = nextSeq - 1
    }

    /// Remove a session's cursor tracking.
    func removeSession(_ sessionId: String) {
        lock.lock()
        defer { lock.unlock() }
        sessionCursors.removeValue(forKey: sessionId)
    }

    // MARK: - Push

    /// Push an event to all active sessions' view of the buffer.
    /// Called from any thread (render thread, feed processor, hook handler).
    ///
    /// - Parameters:
    ///   - type: Event type string (e.g., "commit", "touch", "surprise")
    ///   - data: Event-specific payload dictionary
    func push(type: String, data: [String: Any] = [:]) {
        lock.lock()
        defer { lock.unlock() }

        let event = PushlingEvent(
            seq: nextSeq,
            type: type,
            timestamp: Self.isoFormatter.string(from: Date()),
            data: data
        )

        if count == capacity {
            // Buffer full — we're about to overwrite the oldest event
            consecutiveDropCount += 1

            // Check if the event at head is already an events_dropped meta-event.
            // If not, we just increment our counter. The events_dropped event will
            // be synthesized during drain when we detect gaps in the sequence.
        }

        events[head] = event
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
        nextSeq += 1
    }

    // MARK: - Drain

    /// Return all pending events for a session since its last drain, then advance the cursor.
    /// Called from the socket thread when building an IPC response.
    ///
    /// Returns an array of event dictionaries ready for JSON serialization.
    func drain(sessionId: String) -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }

        guard let lastSeen = sessionCursors[sessionId] else {
            return []
        }

        var result: [[String: Any]] = []
        var droppedCount = 0

        // Iterate over valid events in insertion order
        if count > 0 {
            // The oldest event is at index (head - count) mod capacity
            let start = ((head - count) % capacity + capacity) % capacity

            for i in 0..<count {
                let index = (start + i) % capacity
                guard let event = events[index] else { continue }

                if event.seq > lastSeen {
                    result.append(event.toDictionary())
                }
            }

            // Detect if the session missed events (its cursor is behind the oldest event)
            if let oldestEvent = events[((head - count) % capacity + capacity) % capacity] {
                if lastSeen < oldestEvent.seq - 1 {
                    // Events were dropped between lastSeen and the oldest remaining event
                    droppedCount = oldestEvent.seq - 1 - lastSeen
                }
            }
        }

        // Inject events_dropped at the beginning if events were lost
        if droppedCount > 0 {
            let droppedEvent: [String: Any] = [
                "seq": 0,  // Meta-event, not part of normal sequence
                "type": "events_dropped",
                "timestamp": Self.isoFormatter.string(from: Date()),
                "data": ["count": droppedCount]
            ]
            result.insert(droppedEvent, at: 0)
        }

        // Advance cursor to the latest sequence
        sessionCursors[sessionId] = nextSeq - 1

        return result
    }

    // MARK: - Query

    /// The current global sequence number (next event will get this seq).
    var currentSequence: Int {
        lock.lock()
        defer { lock.unlock() }
        return nextSeq
    }

    /// Number of events currently in the buffer.
    var eventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    /// Number of active sessions being tracked.
    var sessionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sessionCursors.count
    }

    /// Get events since a given sequence number (for non-session callers).
    /// Does not modify any cursor.
    func eventsSince(seq: Int) -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }

        var result: [[String: Any]] = []

        if count > 0 {
            let start = ((head - count) % capacity + capacity) % capacity
            for i in 0..<count {
                let index = (start + i) % capacity
                guard let event = events[index] else { continue }
                if event.seq > seq {
                    result.append(event.toDictionary())
                }
            }
        }

        return result
    }
}
