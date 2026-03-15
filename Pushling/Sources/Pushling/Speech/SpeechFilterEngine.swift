// SpeechFilterEngine.swift — Deterministic text reduction pipeline
// Transforms Claude's full-intelligence text into stage-appropriate output.
//
// Pipeline: Tokenize -> Detect Emotion -> Score Words -> Stage Reduce -> Reassemble
//
// DETERMINISTIC: Same input + same stage + same personality = same output. Always.
// No randomness. No NLP dependencies. ~500-word curated vocabulary lookups.
//
// Performance target: <0.1ms per filter operation.

import Foundation

// MARK: - Filter Result

/// The output of the speech filtering pipeline.
struct SpeechFilterResult {
    /// The filtered text appropriate for the creature's stage.
    let filteredText: String

    /// The original unfiltered text.
    let originalText: String

    /// Detected emotional intent.
    let emotion: SpeechEmotion

    /// Whether significant content was lost (>40% content words removed).
    let isFailedSpeech: Bool

    /// Percentage of content words lost (0-100).
    let contentLossPercent: Int

    /// For Drop stage: the symbol chosen instead of words.
    let dropSymbol: DropSymbol?
}

// MARK: - Word Tag

/// Part-of-speech tag for a word.
private enum WordTag: Int {
    case filler = 0      // the, a, an, is, was, are, etc.
    case connector = 1   // and, but, or, so, because, etc.
    case adverb = 2      // really, very, quickly, etc.
    case adjective = 3   // big, small, nice, good, etc.
    case verb = 4        // run, eat, fix, refactor, etc.
    case noun = 5        // code, bug, file, auth, etc.
    case emotionWord = 6 // happy, sad, careful, wow, etc.

    var importanceScore: Int { rawValue }
}

// MARK: - Tagged Word

/// A word with its tag and importance score.
private struct TaggedWord {
    let word: String
    let tag: WordTag
    var score: Int
    let index: Int  // Original position for reassembly
}

// MARK: - Speech Filter Engine

/// The core filtering engine. Stateless, deterministic, reentrant.
/// All methods are static — no instance state.
enum SpeechFilterEngine {

    // MARK: - Public API

    /// Filter text for a given growth stage with personality modifiers.
    /// DETERMINISTIC: same inputs always produce same output.
    static func filter(text: String,
                        stage: GrowthStage,
                        personality: PersonalitySnapshot) -> SpeechFilterResult {
        // Spore: no speech at all
        if stage == .spore {
            return SpeechFilterResult(
                filteredText: "",
                originalText: text,
                emotion: EmotionDetector.detect(from: text),
                isFailedSpeech: true,
                contentLossPercent: 100,
                dropSymbol: nil
            )
        }

        // Stage 1: Tokenize and tag
        let taggedWords = tokenize(text)
        let contentWords = taggedWords.filter {
            $0.tag.importanceScore >= WordTag.adjective.importanceScore
        }

        // Stage 2: Detect emotion
        let emotion = EmotionDetector.detect(from: text)

        // Drop: map to symbol, no word output
        if stage == .drop {
            let symbol = DropSymbolSet.selectSymbol(
                forText: text, detectedEmotion: emotion
            )
            return SpeechFilterResult(
                filteredText: symbol.glyph,
                originalText: text,
                emotion: emotion,
                isFailedSpeech: contentWords.count > 0,
                contentLossPercent: 100,
                dropSymbol: symbol
            )
        }

        // Apex: pass through with personality modifier only
        if stage == .apex {
            let modified = applyPersonalityModifiers(
                text, personality: personality
            )
            let truncated = enforceCharLimit(modified, maxChars: 120)
            return SpeechFilterResult(
                filteredText: truncated,
                originalText: text,
                emotion: emotion,
                isFailedSpeech: false,
                contentLossPercent: 0,
                dropSymbol: nil
            )
        }

        // Stage 3: Score words by importance
        let scored = scoreWords(taggedWords, text: text)

        // Stage 4: Stage reduction
        let (maxChars, maxWords) = stageLimits(stage)
        let reduced = reduceToStage(
            scored, stage: stage, maxWords: maxWords
        )

        // Stage 5: Reassemble with personality
        var assembled = reassemble(reduced, stage: stage)
        assembled = applyPersonalityModifiers(
            assembled, personality: personality
        )
        assembled = enforceCharLimit(assembled, maxChars: maxChars)

        // Calculate content loss
        let keptContentWords = reduced.filter {
            $0.tag.importanceScore >= WordTag.adjective.importanceScore
        }.count
        let totalContent = max(1, contentWords.count)
        let lossPct = max(0, min(100,
            Int(Double(totalContent - keptContentWords) / Double(totalContent) * 100)
        ))
        let isFailed = lossPct > 40

        return SpeechFilterResult(
            filteredText: assembled,
            originalText: text,
            emotion: emotion,
            isFailedSpeech: isFailed,
            contentLossPercent: lossPct,
            dropSymbol: nil
        )
    }

    // MARK: - Pipeline Stages

    /// Stage 1: Tokenize and tag each word.
    private static func tokenize(_ text: String) -> [TaggedWord] {
        let words = text.split(separator: " ").map { String($0) }
        return words.enumerated().map { index, word in
            let clean = word.lowercased().trimmingCharacters(
                in: CharacterSet.punctuationCharacters
            )
            let tag = classifyWord(clean)
            return TaggedWord(
                word: word, tag: tag,
                score: tag.importanceScore, index: index
            )
        }
    }

    /// Stage 3: Score words by importance with contextual boosts.
    private static func scoreWords(_ words: [TaggedWord],
                                     text: String) -> [TaggedWord] {
        return words.map { w in
            var scored = w
            let clean = w.word.lowercased().trimmingCharacters(
                in: CharacterSet.punctuationCharacters
            )

            // Emotion words get +3
            if EmotionDetector.isEmotionWord(clean) {
                scored.score += 3
            }

            // Capitalized words (not sentence-start) get +2 as proper nouns
            if w.index > 0 && w.word.first?.isUppercase == true {
                scored.score += 2
            }

            // Technical terms get +1
            if technicalTerms.contains(clean) {
                scored.score += 1
            }

            return scored
        }
    }

    /// Stage 4: Reduce to stage-appropriate word count.
    private static func reduceToStage(_ words: [TaggedWord],
                                        stage: GrowthStage,
                                        maxWords: Int) -> [TaggedWord] {
        // Sort by score (descending), then by original index for stability
        let sorted = words.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.index < b.index
        }

        // Take top N words
        let selected = Array(sorted.prefix(maxWords))

        // Re-sort by original index for natural word order
        return selected.sorted { $0.index < $1.index }
    }

    /// Stage 5: Reassemble words into grammatically plausible output.
    private static func reassemble(_ words: [TaggedWord],
                                     stage: GrowthStage) -> String {
        if words.isEmpty { return "" }

        var result = words.map { w in
            let clean = w.word.trimmingCharacters(
                in: CharacterSet.punctuationCharacters
            )

            // Simplify vocabulary for Critter stage
            if stage == .critter {
                return simplifyWord(clean)
            }
            // Beast: light simplification
            if stage == .beast {
                return simplifyWordBeast(clean)
            }
            return clean
        }.joined(separator: " ")

        // Add stage-appropriate punctuation
        result = addStagePunctuation(result, stage: stage)

        return result
    }

    // MARK: - Word Classification

    /// Classify a word into a tag using curated dictionaries.
    private static func classifyWord(_ word: String) -> WordTag {
        if fillerWords.contains(word) { return .filler }
        if connectorWords.contains(word) { return .connector }
        if EmotionDetector.isEmotionWord(word) { return .emotionWord }
        if adverbWords.contains(word) { return .adverb }
        if commonVerbs.contains(word) { return .verb }
        if commonAdjectives.contains(word) { return .adjective }

        // Heuristics for unknown words
        if word.hasSuffix("ly") { return .adverb }
        if word.hasSuffix("ing") { return .verb }
        if word.hasSuffix("ed") { return .verb }
        if word.hasSuffix("tion") || word.hasSuffix("ment") { return .noun }

        // Default: treat as noun (most important)
        return .noun
    }

    // MARK: - Vocabulary Simplification

    /// Simplify a word for Critter stage (~200-word vocabulary).
    private static func simplifyWord(_ word: String) -> String {
        let lower = word.lowercased()
        if let simple = critterSimplifyMap[lower] { return simple }
        // If word is already simple (<=5 chars), keep it
        if lower.count <= 5 { return lower }
        // Truncate long words
        return String(lower.prefix(5))
    }

    /// Light simplification for Beast stage (~1000-word vocabulary).
    private static func simplifyWordBeast(_ word: String) -> String {
        let lower = word.lowercased()
        if let simple = beastSimplifyMap[lower] { return simple }
        return lower
    }

    // MARK: - Personality Modifiers

    /// Apply personality-driven modifications to filtered text.
    /// Applied after stage reduction, before char limit.
    static func applyPersonalityModifiers(
        _ text: String,
        personality: PersonalitySnapshot
    ) -> String {
        var result = text

        // Energy axis
        if personality.energy < 0.3 {
            // Low energy: lowercase, trailing ...
            result = result.lowercased()
            if !result.hasSuffix("...") && !result.hasSuffix("?") {
                result += "..."
            }
            // Remove exclamation marks
            result = result.replacingOccurrences(of: "!", with: "")
        } else if personality.energy > 0.7 {
            // High energy: occasional caps, extra !
            if !result.hasSuffix("!") && !result.hasSuffix("?") {
                result += "!"
            }
        }

        // Discipline axis
        if personality.discipline < 0.3 {
            // Informal: drop articles, use contractions
            result = result.replacingOccurrences(of: "yes", with: "ya")
            result = result.replacingOccurrences(of: "you", with: "u")
        } else if personality.discipline > 0.7 {
            // Formal: ensure period at end
            if !result.isEmpty && !result.hasSuffix(".")
                && !result.hasSuffix("!") && !result.hasSuffix("?") {
                result += "."
            }
        }

        return result
    }

    // MARK: - Stage Limits

    /// Returns (maxChars, maxWords) for a given stage.
    private static func stageLimits(
        _ stage: GrowthStage
    ) -> (maxChars: Int, maxWords: Int) {
        switch stage {
        case .spore:   return (0, 0)
        case .drop:    return (3, 0)
        case .critter: return (20, 3)
        case .beast:   return (50, 8)
        case .sage:    return (80, 20)
        case .apex:    return (120, 30)
        }
    }

    /// Enforce character limit, truncating with "..." if needed.
    private static func enforceCharLimit(
        _ text: String, maxChars: Int
    ) -> String {
        if text.count <= maxChars { return text }
        if maxChars <= 3 { return String(text.prefix(maxChars)) }
        return String(text.prefix(maxChars - 3)) + "..."
    }

    /// Add stage-appropriate punctuation.
    private static func addStagePunctuation(
        _ text: String, stage: GrowthStage
    ) -> String {
        var result = text
        let hasPunctuation = result.last == "!" || result.last == "."
            || result.last == "?" || result.last == ","

        if !hasPunctuation && !result.isEmpty {
            switch stage {
            case .critter: result += "!"  // Critter loves !
            case .beast:   break          // Beast uses periods via discipline
            case .sage:    break          // Sage uses natural punctuation
            default: break
            }
        }

        return result
    }

    // MARK: - Curated Word Dictionaries

    private static let fillerWords: Set<String> = [
        "the", "a", "an", "is", "was", "are", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will",
        "would", "could", "should", "may", "might", "shall", "can",
        "to", "of", "in", "for", "on", "with", "at", "by", "from",
        "as", "into", "through", "during", "before", "after", "above",
        "below", "between", "this", "that", "these", "those", "it",
        "its", "my", "your", "his", "her", "our", "their", "i",
        "me", "you", "he", "she", "we", "they", "not", "no"
    ]

    private static let connectorWords: Set<String> = [
        "and", "but", "or", "so", "because", "since", "while",
        "although", "however", "therefore", "also", "then", "when",
        "if", "unless", "until", "though", "yet", "nor", "both",
        "either", "neither", "whether"
    ]

    private static let adverbWords: Set<String> = [
        "really", "very", "quite", "just", "almost", "already",
        "always", "never", "often", "sometimes", "usually", "still",
        "too", "much", "more", "most", "well", "fast", "slowly",
        "quickly", "carefully", "probably", "definitely", "actually",
        "basically", "essentially", "particularly"
    ]

    private static let commonVerbs: Set<String> = [
        "run", "eat", "fix", "add", "remove", "delete", "create",
        "update", "change", "move", "make", "build", "test", "write",
        "read", "push", "pull", "merge", "revert", "commit", "deploy",
        "refactor", "debug", "check", "look", "see", "think", "know",
        "want", "need", "try", "use", "work", "find", "get", "set",
        "say", "tell", "ask", "help", "start", "stop", "keep"
    ]

    private static let commonAdjectives: Set<String> = [
        "big", "small", "new", "old", "good", "bad", "great", "nice",
        "clean", "messy", "fast", "slow", "easy", "hard", "simple",
        "complex", "long", "short", "high", "low", "hot", "cold",
        "warm", "cool", "pretty", "ugly", "elegant", "broken",
        "working", "done", "ready", "important", "careful"
    ]

    private static let technicalTerms: Set<String> = [
        "api", "auth", "bug", "cache", "ci", "cli", "css", "db",
        "dns", "docker", "dom", "git", "gpu", "html", "http",
        "json", "jwt", "npm", "orm", "php", "regex", "rest",
        "sdk", "sql", "ssh", "ssl", "tcp", "tls", "ui", "url",
        "xml", "yaml", "refactor", "deploy", "merge", "rebase",
        "webpack", "typescript", "javascript", "python", "rust",
        "swift", "react", "node", "express", "django", "rails"
    ]

    /// Critter vocabulary: complex word -> simple synonym
    private static let critterSimplifyMap: [String: String] = [
        "elegant": "nice", "beautiful": "nice", "wonderful": "nice",
        "excellent": "good", "fantastic": "good", "brilliant": "good",
        "authentication": "auth", "authorization": "auth",
        "refactoring": "fix", "refactored": "fixed", "refactor": "fix",
        "repository": "repo", "documentation": "docs",
        "configuration": "config", "implementation": "code",
        "something": "thing", "everything": "all",
        "morning": "morn", "evening": "eve",
        "yesterday": "then", "tomorrow": "soon",
        "remember": "know", "understand": "know",
        "important": "big", "interesting": "cool",
        "different": "new", "working": "ok",
        "problem": "bug", "issue": "bug",
        "function": "func", "variable": "var",
        "because": "cuz", "probably": "maybe"
    ]

    /// Beast vocabulary: minor simplifications only
    private static let beastSimplifyMap: [String: String] = [
        "authentication": "auth", "authorization": "auth",
        "configuration": "config", "documentation": "docs",
        "repository": "repo"
    ]
}

// MARK: - Emotion Detection Extension

extension EmotionDetector {
    /// Check if a word is an emotion word (for scoring boost).
    static func isEmotionWord(_ word: String) -> Bool {
        let emotionWords: Set<String> = [
            "happy", "sad", "angry", "scared", "surprised", "excited",
            "worried", "confused", "proud", "grateful", "love", "hate",
            "fear", "joy", "hope", "calm", "nervous", "bored",
            "curious", "amazed", "frustrated", "delighted", "relieved",
            "wow", "yay", "ugh", "hmm", "ooh", "ahh", "nice", "cool"
        ]
        return emotionWords.contains(word)
    }
}
