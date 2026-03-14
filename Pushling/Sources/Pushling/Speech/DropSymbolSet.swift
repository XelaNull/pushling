// DropSymbolSet.swift — Symbol vocabulary and selection for the Drop stage
// Drop creatures can only express single symbols, not words.
// This file defines the 17 symbols and the deterministic selection algorithm
// that maps Claude's full-intelligence text to the most appropriate glyph.
//
// The selection is DETERMINISTIC: same input + same emotion always = same symbol.
// No randomness. The creature's constraints are the poetry.

import Foundation

// MARK: - Drop Symbol

/// A single expressible symbol for the Drop stage.
struct DropSymbol {
    /// The display text (rendered as SKLabelNode).
    let glyph: String

    /// Semantic meaning for logging/journal.
    let meaning: String

    /// Primary emotional category this symbol belongs to.
    let emotion: SpeechEmotion

    /// Whether this symbol should float with rotation (musical notes).
    let rotates: Bool

    /// Hold duration override (nil = use default 1.2s for symbols).
    let holdDuration: TimeInterval?
}

// MARK: - Speech Emotion

/// Emotional categories detected from input text.
/// Used by both the Drop symbol selector and the full filtering engine.
enum SpeechEmotion: String, Codable {
    case positive     // happy, good, nice, love, great
    case negative     // bad, wrong, broken, error, sad
    case neutral      // informational, factual
    case questioning  // confusion, curiosity
    case exclaiming   // excitement, surprise, urgency
    case warning      // careful, danger, alert
    case affection    // love, care, warmth, trust
    case sleepy       // tired, rest, sleep
    case contentment  // ease, comfort, satisfaction

    /// Priority when multiple emotions are detected (higher = wins).
    var priority: Int {
        switch self {
        case .warning:     return 9
        case .exclaiming:  return 8
        case .affection:   return 7
        case .negative:    return 6
        case .questioning: return 5
        case .positive:    return 4
        case .sleepy:      return 3
        case .contentment: return 2
        case .neutral:     return 1
        }
    }
}

// MARK: - Symbol Set

/// The complete Drop symbol vocabulary (17 symbols).
enum DropSymbolSet {

    /// All available symbols, indexed by glyph.
    static let symbols: [DropSymbol] = [
        DropSymbol(glyph: "!", meaning: "alert/excitement",
                   emotion: .exclaiming, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "?", meaning: "curiosity/confusion",
                   emotion: .questioning, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "...", meaning: "thinking/processing",
                   emotion: .neutral, rotates: false, holdDuration: 1.5),
        DropSymbol(glyph: "!?", meaning: "surprise/shock",
                   emotion: .warning, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "~", meaning: "contentment/ease",
                   emotion: .contentment, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "zzz", meaning: "sleepy",
                   emotion: .sleepy, rotates: false, holdDuration: 1.8),
        DropSymbol(glyph: "!!", meaning: "extreme excitement",
                   emotion: .exclaiming, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2665}", meaning: "love/affection",
                   emotion: .affection, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2605}", meaning: "delight/milestone",
                   emotion: .positive, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{266A}", meaning: "music/singing",
                   emotion: .contentment, rotates: true, holdDuration: 1.5),
        DropSymbol(glyph: "\u{2191}", meaning: "up/growth/increase",
                   emotion: .positive, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2193}", meaning: "down/decrease/concern",
                   emotion: .negative, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2192}", meaning: "direction/go",
                   emotion: .neutral, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2190}", meaning: "back/return",
                   emotion: .neutral, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2026}", meaning: "ellipsis/trailing off",
                   emotion: .neutral, rotates: false, holdDuration: 1.5),
        DropSymbol(glyph: "\u{2764}", meaning: "strong love",
                   emotion: .affection, rotates: false, holdDuration: nil),
        DropSymbol(glyph: "\u{2728}", meaning: "sparkle/magic",
                   emotion: .positive, rotates: false, holdDuration: nil),
    ]

    /// Primary symbol lookup by emotion.
    /// Returns the single best symbol for a given detected emotion.
    /// Deterministic: same emotion always returns the same symbol.
    static func symbolForEmotion(_ emotion: SpeechEmotion) -> DropSymbol {
        switch emotion {
        case .positive:     return symbols[8]   // star
        case .negative:     return symbols[11]  // down arrow
        case .neutral:      return symbols[2]   // ...
        case .questioning:  return symbols[1]   // ?
        case .exclaiming:   return symbols[0]   // !
        case .warning:      return symbols[3]   // !?
        case .affection:    return symbols[7]   // heart
        case .sleepy:       return symbols[5]   // zzz
        case .contentment:  return symbols[4]   // ~
        }
    }

    /// Select the best symbol for a full text message.
    /// Uses the emotion detection result from the filtering engine.
    /// Deterministic: same text always yields same symbol.
    static func selectSymbol(forText text: String,
                              detectedEmotion: SpeechEmotion) -> DropSymbol {
        return symbolForEmotion(detectedEmotion)
    }
}

// MARK: - Emotion Detection

/// Lightweight keyword-based emotion detection.
/// No NLP, no regex — just dictionary lookup and punctuation analysis.
/// DETERMINISTIC: same input always produces same output.
enum EmotionDetector {

    /// Positive keywords (lowercased).
    private static let positiveWords: Set<String> = [
        "good", "great", "nice", "awesome", "wonderful", "excellent",
        "amazing", "fantastic", "perfect", "beautiful", "love", "like",
        "happy", "glad", "well", "yay", "cool", "sweet", "best",
        "elegant", "clean", "solid", "brilliant", "superb", "neat"
    ]

    /// Negative keywords (lowercased).
    private static let negativeWords: Set<String> = [
        "bad", "wrong", "broken", "error", "fail", "bug", "issue",
        "problem", "sad", "terrible", "awful", "ugly", "mess",
        "crash", "stuck", "confused", "worried", "concern", "trouble",
        "warning", "danger", "careful", "watch", "avoid", "risky"
    ]

    /// Affection keywords (lowercased).
    private static let affectionWords: Set<String> = [
        "love", "care", "trust", "friend", "miss", "warm", "hug",
        "safe", "comfort", "gentle", "kind", "sweet", "dear",
        "precious", "cherish", "adore"
    ]

    /// Warning keywords (lowercased).
    private static let warningWords: Set<String> = [
        "careful", "danger", "warning", "alert", "watch", "caution",
        "beware", "risk", "threat", "urgent", "critical", "security",
        "vulnerability", "injection", "exploit", "unsafe"
    ]

    /// Sleepy keywords (lowercased).
    private static let sleepyWords: Set<String> = [
        "sleepy", "tired", "rest", "sleep", "yawn", "nap", "drowsy",
        "exhausted", "bedtime", "night", "zzz", "snooze"
    ]

    /// Detect the primary emotion from a text string.
    /// Returns the emotion with the highest score.
    /// DETERMINISTIC: consistent tie-breaking by emotion priority.
    static func detect(from text: String) -> SpeechEmotion {
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map { String($0) }

        // Score each emotion category
        var scores: [SpeechEmotion: Int] = [:]

        // Word-based scoring
        for word in words {
            // Strip trailing punctuation for matching
            let cleanWord = word.trimmingCharacters(
                in: CharacterSet.punctuationCharacters
            )

            if warningWords.contains(cleanWord) {
                scores[.warning, default: 0] += 3
            }
            if affectionWords.contains(cleanWord) {
                scores[.affection, default: 0] += 3
            }
            if positiveWords.contains(cleanWord) {
                scores[.positive, default: 0] += 2
            }
            if negativeWords.contains(cleanWord) {
                scores[.negative, default: 0] += 2
            }
            if sleepyWords.contains(cleanWord) {
                scores[.sleepy, default: 0] += 3
            }
        }

        // Punctuation-based scoring
        if lower.contains("!") {
            scores[.exclaiming, default: 0] += 2
        }
        if lower.contains("?") {
            scores[.questioning, default: 0] += 2
        }
        if lower.hasSuffix("...") {
            scores[.neutral, default: 0] += 1
        }
        if lower.contains("!?") || lower.contains("?!") {
            scores[.warning, default: 0] += 2
        }

        // Multiple exclamation marks boost exclaiming
        let bangCount = lower.filter { $0 == "!" }.count
        if bangCount >= 2 {
            scores[.exclaiming, default: 0] += bangCount
        }

        // Find highest scoring emotion
        // Tie-break by emotion priority (higher priority wins)
        if scores.isEmpty {
            return .neutral
        }

        let maxScore = scores.values.max() ?? 0
        let candidates = scores.filter { $0.value == maxScore }
        let winner = candidates.max { $0.key.priority < $1.key.priority }
        return winner?.key ?? .neutral
    }
}
