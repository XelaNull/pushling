// CommitTypeDetector.swift — Classify commits into 15 eating animation types
// Determines which special eating variation to play based on commit metadata.
//
// Priority order: force_push > revert > merge > new_repo > huge_refactor >
// large_refactor > empty > first_of_day > late_night > test > docs > css >
// php > lazy > build_config > default
//
// Also handles XP calculation: base + lines + message + breadth * multipliers.

import Foundation

// MARK: - Commit Type

/// The 15 commit eating animation types, ordered by priority.
enum CommitType: String, CaseIterable {
    case forcePush     = "force_push"      // Text SLAMS in, knocks creature
    case release       = "release"          // Tagged release — celebration!
    case revert        = "revert"           // Characters come back OUT
    case merge         = "merge"            // Text from both sides
    case newRepo       = "new_repo"         // First commit from this repo
    case hugeRefactor  = "huge_refactor"    // 500+ lines, feast mode
    case largeRefactor = "large_refactor"   // 200+ lines, goblin mode
    case empty         = "empty"            // Nothing there
    case firstOfDay    = "first_of_day"     // Extra enthusiastic
    case lateNight     = "late_night"       // Sleepy eating
    case test          = "test"             // Crunchy, protein
    case docs          = "docs"             // Careful, vegetables
    case css           = "css"              // Sparkly, dessert
    case php           = "php"              // Warm, comfort food
    case lazyMessage   = "lazy_message"     // Reluctant, junk food
    case buildConfig   = "build_config"     // Methodical, important
    case normal        = "normal"           // Default eating

    /// Speech reaction for Beast+ stage.
    var speechReaction: String {
        switch self {
        case .forcePush:     return "WHOOSH!"
        case .release:       return "We shipped it!"
        case .revert:        return "...deja vu"
        case .merge:         return "from both sides!"
        case .newRepo:       return "NEW FLAVOR!"
        case .hugeRefactor:  return "I can't move..."
        case .largeRefactor: return "NOM NOM NOM!!"
        case .empty:         return "...air?"
        case .firstOfDay:    return "MORNING!"
        case .lateNight:     return "...our secret"
        case .test:          return "STRONG"
        case .docs:          return "ah..."
        case .css:           return "pretty!"
        case .php:           return "classic!"
        case .lazyMessage:   return "...fine."
        case .buildConfig:   return "important."
        case .normal:        return "yum!"
        }
    }

    /// Speech reaction for Critter stage (single word).
    var critterReaction: String {
        switch self {
        case .forcePush:     return "EEK!"
        case .release:       return "SHIPPED!"
        case .revert:        return "huh?"
        case .merge:         return "wow!"
        case .newRepo:       return "NEW!"
        case .hugeRefactor:  return "BIG!"
        case .largeRefactor: return "NOM!"
        case .empty:         return "hm?"
        case .firstOfDay:    return "YAY!"
        case .lateNight:     return "shh!"
        case .test:          return "crunch!"
        case .docs:          return "hmm!"
        case .css:           return "ooh!"
        case .php:           return "mmm!"
        case .lazyMessage:   return "meh!"
        case .buildConfig:   return "hmm!"
        case .normal:        return "yum!"
        }
    }

    /// Drop symbol for this commit type.
    var dropSymbolEmotion: SpeechEmotion {
        switch self {
        case .forcePush:     return .warning
        case .release:       return .exclaiming
        case .revert:        return .questioning
        case .merge:         return .exclaiming
        case .newRepo:       return .exclaiming
        case .hugeRefactor:  return .exclaiming
        case .largeRefactor: return .exclaiming
        case .empty:         return .questioning
        case .firstOfDay:    return .positive
        case .lateNight:     return .sleepy
        case .test:          return .positive
        case .docs:          return .neutral
        case .css:           return .positive
        case .php:           return .contentment
        case .lazyMessage:   return .neutral
        case .buildConfig:   return .neutral
        case .normal:        return .positive
        }
    }

    /// Eating speed in ms per character.
    var msPerCharacter: Int {
        switch self {
        case .hugeRefactor, .largeRefactor: return 60    // Goblin mode
        case .forcePush:                    return 40    // Slam speed
        case .release:                      return 400   // Celebratory pace
        case .docs:                         return 250   // Careful reading
        case .lateNight:                    return 225   // Sleepy
        case .buildConfig:                  return 200   // Methodical
        default:                            return 0     // Use size-based
        }
    }
}

// MARK: - Commit Data (for detection)

/// Parsed commit data for type detection.
struct CommitData {
    let message: String
    let sha: String
    let repoName: String
    let filesChanged: Int
    let linesAdded: Int
    let linesRemoved: Int
    let languages: [String]    // File extensions found
    let isMerge: Bool
    let isRevert: Bool
    let isForcePush: Bool
    let tags: [String]         // Git tags on this commit (release detection)
    let branch: String?
    let timestamp: Date

    /// Total lines changed.
    var totalLines: Int { linesAdded + linesRemoved }
}

// MARK: - Commit Type Detector

/// Deterministic commit type classification.
/// Priority order ensures the most specific type wins.
enum CommitTypeDetector {

    /// Detect the commit type from parsed commit data.
    /// - Parameters:
    ///   - commit: The parsed commit data.
    ///   - isFirstFromRepo: Whether this is the first commit from this repo.
    ///   - lastCommitTime: When the last commit was eaten (for first-of-day).
    /// - Returns: The classified commit type.
    static func detect(
        commit: CommitData,
        isFirstFromRepo: Bool,
        lastCommitTime: Date?
    ) -> CommitType {
        // Priority 1: Force push
        if commit.isForcePush { return .forcePush }

        // Priority 2: Release (tagged commit)
        if !commit.tags.isEmpty { return .release }

        // Priority 3: Revert
        if commit.isRevert { return .revert }

        // Priority 3: Merge
        if commit.isMerge { return .merge }

        // Priority 4: New repo
        if isFirstFromRepo { return .newRepo }

        // Priority 5: Huge refactor (500+ lines)
        if commit.totalLines > 500 { return .hugeRefactor }

        // Priority 6: Large refactor (200+ lines)
        if commit.totalLines > 200 { return .largeRefactor }

        // Priority 7: Empty commit
        if commit.totalLines == 0 { return .empty }

        // Priority 8: First of day
        if let lastTime = lastCommitTime {
            let hoursSince = Date().timeIntervalSince(lastTime) / 3600
            if hoursSince >= 8 { return .firstOfDay }
        }

        // Priority 9: Late night (midnight-5AM)
        let hour = Calendar.current.component(.hour, from: commit.timestamp)
        if hour >= 0 && hour < 5 { return .lateNight }

        // Priority 10: Test files
        if containsTestFiles(commit.languages) { return .test }

        // Priority 11: Documentation
        if containsDocFiles(commit.languages) { return .docs }

        // Priority 12: CSS/styling
        if containsCSSFiles(commit.languages) { return .css }

        // Priority 13: PHP files
        if commit.languages.contains("php") { return .php }

        // Priority 14: Lazy message
        if isLazyMessage(commit.message) { return .lazyMessage }

        // Priority 15: Build/CI config
        if containsBuildFiles(commit.languages) { return .buildConfig }

        // Default
        return .normal
    }

    /// Determine eating speed based on commit size.
    /// Used when the commit type doesn't specify its own speed.
    static func eatingSpeed(totalLines: Int) -> Int {
        switch totalLines {
        case 0..<20:    return 200  // Small: polite nibbles
        case 20..<100:  return 150  // Medium: steady munching
        case 100..<200: return 100  // Large: enthusiastic
        default:        return 60   // Huge: goblin mode
        }
    }

    // MARK: - Detection Helpers

    private static func containsTestFiles(_ languages: [String]) -> Bool {
        return languages.contains { ext in
            ext.contains("test") || ext.contains("spec")
        }
    }

    private static func containsDocFiles(_ languages: [String]) -> Bool {
        let docExts: Set<String> = ["md", "txt", "rst", "adoc", "tex"]
        return languages.contains { docExts.contains($0.lowercased()) }
    }

    private static func containsCSSFiles(_ languages: [String]) -> Bool {
        let cssExts: Set<String> = ["css", "scss", "less", "sass"]
        return languages.contains { cssExts.contains($0.lowercased()) }
    }

    private static func containsBuildFiles(_ languages: [String]) -> Bool {
        let buildExts: Set<String> = [
            "yml", "yaml", "dockerfile", "toml", "hcl", "tf"
        ]
        return languages.contains { ext in
            let lower = ext.lowercased()
            return buildExts.contains(lower)
                || lower.contains("github")
                || lower.contains("ci")
        }
    }

    /// Detect lazy commit messages.
    private static let lazyPatterns: Set<String> = [
        "fix", "wip", "stuff", "update", "changes", "misc", "asdf",
        "test", ".", "tmp", "save"
    ]

    static func isLazyMessage(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        // Exclude version tags (v1, v2.0, v1.2.3, etc.)
        if lower.range(of: #"^v\d+"#, options: .regularExpression) != nil {
            return false
        }

        // Exclude standard release/merge messages
        if lower.hasPrefix("release") || lower.hasPrefix("merge") {
            return false
        }

        // Single word under 15 chars (after exclusions above)
        if !lower.contains(" ") && lower.count < 15 { return true }

        // Very short
        if trimmed.count < 5 { return true }

        // Exact lazy matches
        if lazyPatterns.contains(lower) { return true }

        return false
    }
}
