// SpeechCache.swift — SQLite-backed utterance history for replay and dreams
// Stores last 100 utterances with FIFO eviction.
//
// Replay scenarios:
//   - Idle replay: thought bubble at 50% opacity, max 1 per 5 min
//   - Dream replay: fragments during sleep (P5-T1-09)
//   - Sage reminiscence: narrating past failed_speech attempts
//
// The cache is written to by the daemon (through IPC), not MCP directly.

import Foundation

// MARK: - Cached Utterance

/// A single cached speech utterance.
struct CachedUtterance {
    let id: Int
    let text: String
    let style: SpeechStyle
    let stage: GrowthStage
    let timestamp: Date
    let source: UtteranceSource
    let emotion: SpeechEmotion
    let ttsCachePath: String?
}

/// Source of an utterance.
enum UtteranceSource: String, Codable {
    case ai         // Claude-directed via MCP
    case autonomous // Layer 1 autonomous speech
}

// MARK: - Speech Cache

/// Manages the speech cache in SQLite.
/// Capacity: 100 utterances, FIFO eviction.
final class SpeechCache {

    // MARK: - Configuration

    static let maxCapacity = 100

    // MARK: - Schema

    /// DDL for the speech_cache table.
    static let createTableSQL = """
        CREATE TABLE IF NOT EXISTS speech_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            style TEXT NOT NULL,
            stage TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'autonomous',
            emotion TEXT NOT NULL DEFAULT 'neutral',
            tts_cache_path TEXT
        );
        """

    static let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_speech_cache_timestamp
        ON speech_cache(timestamp);
        """

    // MARK: - Dependencies

    private weak var db: DatabaseManager?

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - Write

    /// Store a new utterance in the cache.
    /// Evicts oldest entries if capacity exceeded.
    func store(text: String,
               style: SpeechStyle,
               stage: GrowthStage,
               source: UtteranceSource,
               emotion: SpeechEmotion,
               ttsCachePath: String? = nil) {
        guard let db = db else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        do {
            try db.execute(
                """
                INSERT INTO speech_cache
                    (text, style, stage, timestamp, source, emotion, tts_cache_path)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    text, style.rawValue, "\(stage)", timestamp,
                    source.rawValue, emotion.rawValue,
                    ttsCachePath as Any
                ]
            )

            // Evict oldest if over capacity
            try db.execute(
                """
                DELETE FROM speech_cache
                WHERE id NOT IN (
                    SELECT id FROM speech_cache
                    ORDER BY timestamp DESC LIMIT \(Self.maxCapacity)
                )
                """
            )
        } catch {
            NSLog("[Pushling/SpeechCache] Failed to store: %@", "\(error)")
        }
    }

    // MARK: - Read

    /// Retrieve the last N utterances.
    func recentUtterances(count: Int = 10) -> [CachedUtterance] {
        guard let db = db else { return [] }

        do {
            let rows = try db.query(
                """
                SELECT id, text, style, stage, timestamp, source,
                       emotion, tts_cache_path
                FROM speech_cache
                ORDER BY timestamp DESC LIMIT ?
                """,
                arguments: [count]
            )
            return rows.compactMap { parseRow($0) }
        } catch {
            NSLog("[Pushling/SpeechCache] Failed to read: %@", "\(error)")
            return []
        }
    }

    /// Get a deterministic utterance for dream replay.
    /// Uses the utterance ID modulo to avoid true randomness while still
    /// providing variety. The selection rotates based on the current hour.
    func dreamUtterance() -> CachedUtterance? {
        guard let db = db else { return nil }

        do {
            let rows = try db.query(
                """
                SELECT id, text, style, stage, timestamp, source,
                       emotion, tts_cache_path
                FROM speech_cache
                ORDER BY timestamp DESC LIMIT 20
                """
            )
            let utterances = rows.compactMap { parseRow($0) }
            guard !utterances.isEmpty else { return nil }

            // Rotate selection based on current hour + minute/10
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            let minuteBlock = calendar.component(.minute, from: Date()) / 10
            let index = (hour * 6 + minuteBlock) % utterances.count
            return utterances[index]
        } catch {
            NSLog("[Pushling/SpeechCache] Dream query failed: %@", "\(error)")
            return nil
        }
    }

    /// Fragment a cached utterance for dream display.
    /// Takes 1-3 words from the middle, wraps with "...".
    /// DETERMINISTIC: same utterance always produces same fragment.
    static func dreamFragment(from utterance: CachedUtterance) -> String {
        let words = utterance.text.split(separator: " ").map { String($0) }
        guard words.count > 1 else {
            return "...\(utterance.text)..."
        }

        // Take words from the middle
        let midIndex = words.count / 2
        let wordCount = min(3, max(1, words.count / 3))
        let startIndex = max(0, midIndex - wordCount / 2)
        let endIndex = min(words.count, startIndex + wordCount)
        let fragment = words[startIndex..<endIndex].joined(separator: " ")

        return "...\(fragment)..."
    }

    /// Retrieve failed speech entries for Sage reminiscence.
    func failedSpeechEntries(limit: Int = 5) -> [[String: Any]] {
        guard let db = db else { return [] }

        do {
            return try db.query(
                """
                SELECT summary, data, timestamp
                FROM journal
                WHERE type = 'failed_speech'
                ORDER BY timestamp DESC LIMIT ?
                """,
                arguments: [limit]
            )
        } catch {
            NSLog("[Pushling/SpeechCache] Failed speech query failed: %@",
                  "\(error)")
            return []
        }
    }

    // MARK: - Parse

    private func parseRow(_ row: [String: Any]) -> CachedUtterance? {
        guard let id = row["id"] as? Int,
              let text = row["text"] as? String,
              let styleStr = row["style"] as? String,
              let stageStr = row["stage"] as? String,
              let timestampStr = row["timestamp"] as? String else {
            return nil
        }

        let style = SpeechStyle(rawValue: styleStr) ?? .say
        let stage = parseStage(stageStr)
        let source = UtteranceSource(
            rawValue: (row["source"] as? String) ?? "autonomous"
        ) ?? .autonomous
        let emotion = SpeechEmotion(
            rawValue: (row["emotion"] as? String) ?? "neutral"
        ) ?? .neutral
        let ttsCachePath = row["tts_cache_path"] as? String

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: timestampStr) ?? Date()

        return CachedUtterance(
            id: id, text: text, style: style, stage: stage,
            timestamp: timestamp, source: source,
            emotion: emotion, ttsCachePath: ttsCachePath
        )
    }

    private func parseStage(_ str: String) -> GrowthStage {
        switch str {
        case "egg":   return .egg
        case "drop":    return .drop
        case "critter": return .critter
        case "beast":   return .beast
        case "sage":    return .sage
        case "apex":    return .apex
        default:        return .critter
        }
    }
}
