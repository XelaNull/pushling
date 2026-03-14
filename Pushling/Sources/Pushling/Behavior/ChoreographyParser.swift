// ChoreographyParser.swift — Validates and normalizes choreography notation JSON
// Validates 13+ tracks, keyframes per track, semantic state names.
// Returns a validated ChoreographyDefinition or a detailed error with suggestions.
//
// Frame budget: validation must complete in <1ms.

import Foundation

// MARK: - Choreography Types

/// A fully validated choreography definition ready for execution.
struct ChoreographyDefinition {
    let name: String
    let category: String
    let stageMin: GrowthStage
    let durationSeconds: TimeInterval
    let tracks: [String: [Keyframe]]
    let triggers: TriggerConfig

    /// All track names present in this choreography.
    var activeTrackNames: [String] { Array(tracks.keys) }
}

/// A single keyframe on a track at a specific time.
struct Keyframe {
    /// Time in seconds from the start of the behavior.
    let time: TimeInterval
    /// The semantic state name at this keyframe.
    let state: String
    /// Easing curve to use when interpolating TO this keyframe.
    let easing: EasingType
    /// Optional parameters (text for speech, sound name, etc.).
    let params: [String: String]

    enum EasingType: String, CaseIterable {
        case linear, easeIn, easeOut, easeInOut, spring
    }
}

/// Trigger configuration for when a taught behavior fires autonomously.
struct TriggerConfig {
    let idleWeight: Double
    let onTouch: Bool
    let onCommitTypes: [String]
    let emotionalConditions: [EmotionalTriggerCondition]
    let timeConditions: TimeTriggerCondition?
    let cooldownSeconds: TimeInterval
    let contexts: [String]
}

struct EmotionalTriggerCondition {
    let axis: String
    let min: Double?
    let max: Double?
}

struct TimeTriggerCondition {
    let after: String?
    let before: String?
}

// MARK: - Parser Errors

struct ChoreographyParseError: Error, CustomStringConvertible {
    let field: String
    let message: String
    let validOptions: [String]?

    var description: String {
        var desc = "Choreography error in '\(field)': \(message)"
        if let opts = validOptions, !opts.isEmpty {
            desc += "\n  Valid options: \(opts.joined(separator: ", "))"
        }
        return desc
    }
}

// MARK: - Parser Result

enum ChoreographyParseResult {
    case success(ChoreographyDefinition)
    case failure([ChoreographyParseError])
}

// MARK: - ChoreographyParser

enum ChoreographyParser {

    // MARK: - Valid Track Names

    static let validTrackNames: [String] = [
        "body", "head", "ears", "eyes", "tail", "mouth", "whiskers",
        "paw_fl", "paw_fr", "paw_bl", "paw_br",
        "particles", "aura", "speech", "sound", "movement"
    ]

    // MARK: - Valid States Per Track

    static let validStatesPerTrack: [String: [String]] = [
        "body": ["stand", "crouch", "sit", "loaf", "roll_side", "roll_back",
                 "arch", "stretch", "curl", "pounce", "lean_forward", "lean_back"],
        "head": ["neutral", "tilt_left", "tilt_right", "look_up", "look_down",
                 "nod", "shake", "bob", "duck", "turn_left", "turn_right"],
        "ears": ["neutral", "perk", "flat", "rotate_left", "rotate_right",
                 "one_forward", "droop", "wild", "alert", "back"],
        "eyes": ["neutral", "wide", "squint", "blink", "wink_left", "wink_right",
                 "closed", "happy_squint", "x_eyes", "half", "open", "sparkle"],
        "tail": ["sway", "poof", "wag", "wrap", "high", "low", "tuck", "lash",
                 "still", "curl", "twitch_tip", "chase"],
        "mouth": ["closed", "open", "smile", "yawn", "chew", "lick", "blep",
                  "chatter"],
        "whiskers": ["neutral", "forward", "back", "twitch", "droop", "fan"],
        "paw_fl": ["neutral", "raise", "wave", "knead", "reach", "tap",
                   "ground", "tuck", "lift", "kick"],
        "paw_fr": ["neutral", "raise", "wave", "knead", "reach", "tap",
                   "ground", "tuck", "lift", "kick"],
        "paw_bl": ["neutral", "raise", "kick", "stretch", "dig", "ground",
                   "tuck"],
        "paw_br": ["neutral", "raise", "kick", "stretch", "dig", "ground",
                   "tuck"],
        "particles": ["none", "sparkle", "hearts", "stars", "music_notes",
                      "dust", "crumbs", "bubbles", "fire_wisps"],
        "aura": ["none", "glow", "pulse", "shimmer", "expand", "contract",
                 "rainbow"],
        "movement": ["stay", "walk_left", "walk_right", "run_left", "run_right",
                     "jump", "retreat"],
    ]

    static let validCategories = [
        "playful", "affectionate", "dramatic", "calm", "silly", "functional"
    ]

    static let validContexts = [
        "near_object", "raining", "snowing", "storming", "night", "morning",
        "claude_connected", "sleeping", "alone", "near_companion"
    ]

    // MARK: - Parse

    /// Parses and validates a choreography JSON dictionary.
    /// Returns a validated definition or detailed errors with suggestions.
    static func parse(_ json: [String: Any]) -> ChoreographyParseResult {
        var errors: [ChoreographyParseError] = []

        // -- Name --
        let name: String
        if let n = json["name"] as? String, !n.isEmpty, n.count <= 30 {
            name = n.lowercased().replacingOccurrences(of: " ", with: "_")
        } else {
            errors.append(ChoreographyParseError(
                field: "name",
                message: "Required string, 1-30 characters.",
                validOptions: nil
            ))
            name = "unnamed"
        }

        // -- Category --
        let category: String
        if let c = json["category"] as? String {
            category = fuzzyMatch(c, against: validCategories) ?? c
            if !validCategories.contains(category) {
                errors.append(ChoreographyParseError(
                    field: "category",
                    message: "'\(c)' is not a valid category.",
                    validOptions: validCategories
                ))
            }
        } else {
            errors.append(ChoreographyParseError(
                field: "category",
                message: "Required. One of the valid categories.",
                validOptions: validCategories
            ))
            category = "playful"
        }

        // -- Stage Min --
        let stageMin: GrowthStage
        if let s = json["stage_min"] as? String {
            stageMin = parseStage(s) ?? .critter
            if parseStage(s) == nil {
                errors.append(ChoreographyParseError(
                    field: "stage_min",
                    message: "'\(s)' is not a valid stage.",
                    validOptions: Schema.validStages
                ))
            }
        } else {
            stageMin = .critter
        }

        // -- Duration --
        let durationSeconds: TimeInterval
        if let d = json["duration_s"] as? Double, d >= 0.5, d <= 30.0 {
            durationSeconds = d
        } else {
            errors.append(ChoreographyParseError(
                field: "duration_s",
                message: "Required number between 0.5 and 30.0 seconds.",
                validOptions: nil
            ))
            durationSeconds = 3.0
        }

        // -- Tracks --
        var tracks: [String: [Keyframe]] = [:]
        if let tracksDict = json["tracks"] as? [String: [[String: Any]]] {
            if tracksDict.count > 13 {
                errors.append(ChoreographyParseError(
                    field: "tracks",
                    message: "Maximum 13 tracks per behavior.",
                    validOptions: validTrackNames
                ))
            }

            for (trackName, keyframeArray) in tracksDict {
                let resolved = fuzzyMatch(trackName, against: validTrackNames)
                    ?? trackName
                if !validTrackNames.contains(resolved) {
                    errors.append(ChoreographyParseError(
                        field: "tracks.\(trackName)",
                        message: "'\(trackName)' is not a valid track. "
                            + "Did you mean '\(fuzzyMatch(trackName, against: validTrackNames) ?? "body")'?",
                        validOptions: validTrackNames
                    ))
                    continue
                }

                if keyframeArray.count > 50 {
                    errors.append(ChoreographyParseError(
                        field: "tracks.\(resolved)",
                        message: "Maximum 50 keyframes per track.",
                        validOptions: nil
                    ))
                }

                var keyframes: [Keyframe] = []
                for kfDict in keyframeArray.prefix(50) {
                    if let kf = parseKeyframe(kfDict, trackName: resolved,
                                              duration: durationSeconds,
                                              errors: &errors) {
                        keyframes.append(kf)
                    }
                }
                keyframes.sort { $0.time < $1.time }
                tracks[resolved] = keyframes
            }
        } else {
            errors.append(ChoreographyParseError(
                field: "tracks",
                message: "Required object mapping track names to keyframe arrays.",
                validOptions: validTrackNames
            ))
        }

        // -- Triggers --
        let triggers = parseTriggers(json["triggers"] as? [String: Any])

        if !errors.isEmpty {
            return .failure(errors)
        }

        let definition = ChoreographyDefinition(
            name: name,
            category: category,
            stageMin: stageMin,
            durationSeconds: durationSeconds,
            tracks: tracks,
            triggers: triggers
        )
        return .success(definition)
    }

    // MARK: - Keyframe Parsing

    private static func parseKeyframe(
        _ dict: [String: Any],
        trackName: String,
        duration: TimeInterval,
        errors: inout [ChoreographyParseError]
    ) -> Keyframe? {
        guard let time = dict["t"] as? Double else {
            errors.append(ChoreographyParseError(
                field: "tracks.\(trackName).keyframe",
                message: "Each keyframe requires a 't' (time) field.",
                validOptions: nil
            ))
            return nil
        }

        let clampedTime = Swift.min(Swift.max(time, 0.0), duration)

        // State — for speech/sound tracks, state can be anything
        let state: String
        if trackName == "speech" || trackName == "sound" {
            state = dict["state"] as? String ?? dict["text"] as? String ?? ""
        } else {
            let rawState = dict["state"] as? String ?? "neutral"
            let validStates = validStatesPerTrack[trackName] ?? []
            if let matched = fuzzyMatch(rawState, against: validStates) {
                state = matched
            } else {
                state = rawState
                if !validStates.isEmpty && !validStates.contains(rawState) {
                    errors.append(ChoreographyParseError(
                        field: "tracks.\(trackName).state",
                        message: "'\(rawState)' is not a valid state for \(trackName).",
                        validOptions: validStates
                    ))
                }
            }
        }

        let easingStr = dict["easing"] as? String ?? "easeInOut"
        let easing = Keyframe.EasingType(rawValue: easingStr) ?? .easeInOut

        var params: [String: String] = [:]
        if let text = dict["text"] as? String { params["text"] = text }
        if let style = dict["style"] as? String { params["style"] = style }
        if let sound = dict["sound"] as? String { params["sound"] = sound }

        return Keyframe(time: clampedTime, state: state,
                        easing: easing, params: params)
    }

    // MARK: - Trigger Parsing

    private static func parseTriggers(
        _ dict: [String: Any]?
    ) -> TriggerConfig {
        guard let dict = dict else {
            return TriggerConfig(
                idleWeight: 0.2, onTouch: false, onCommitTypes: [],
                emotionalConditions: [], timeConditions: nil,
                cooldownSeconds: 300, contexts: []
            )
        }

        let idleWeight = (dict["idle_weight"] as? Double)
            .map { Swift.min(Swift.max($0, 0.0), 1.0) } ?? 0.2
        let onTouch = dict["on_touch"] as? Bool ?? false
        let onCommitTypes = dict["on_commit_type"] as? [String] ?? []
        let cooldown = dict["cooldown_s"] as? Double ?? 300.0
        let contexts = dict["contexts"] as? [String] ?? []

        var emotionalConditions: [EmotionalTriggerCondition] = []
        if let emoDict = dict["emotional_conditions"] as? [String: [String: Double]] {
            for (axis, bounds) in emoDict {
                emotionalConditions.append(EmotionalTriggerCondition(
                    axis: axis, min: bounds["min"], max: bounds["max"]
                ))
            }
        }

        var timeCondition: TimeTriggerCondition?
        if let timeDict = dict["time_conditions"] as? [String: String] {
            timeCondition = TimeTriggerCondition(
                after: timeDict["after"], before: timeDict["before"]
            )
        }

        return TriggerConfig(
            idleWeight: idleWeight, onTouch: onTouch,
            onCommitTypes: onCommitTypes,
            emotionalConditions: emotionalConditions,
            timeConditions: timeCondition,
            cooldownSeconds: cooldown, contexts: contexts
        )
    }

    // MARK: - Stage Parsing

    private static func parseStage(_ str: String) -> GrowthStage? {
        switch str.lowercased() {
        case "spore":   return .spore
        case "drop":    return .drop
        case "critter": return .critter
        case "beast":   return .beast
        case "sage":    return .sage
        case "apex":    return .apex
        default:        return nil
        }
    }

    // MARK: - Fuzzy Matching

    /// Simple fuzzy match: lowercased containment or Levenshtein distance < 3.
    static func fuzzyMatch(_ input: String,
                           against options: [String]) -> String? {
        let lower = input.lowercased()

        // Exact match
        if options.contains(lower) { return lower }

        // Prefix match
        let prefixMatches = options.filter { $0.hasPrefix(lower) }
        if prefixMatches.count == 1 { return prefixMatches[0] }

        // Containment
        let containMatches = options.filter { $0.contains(lower) || lower.contains($0) }
        if containMatches.count == 1 { return containMatches[0] }

        // Best Levenshtein
        var bestMatch: String?
        var bestDist = Int.max
        for option in options {
            let dist = levenshtein(lower, option)
            if dist < bestDist && dist <= 2 {
                bestDist = dist
                bestMatch = option
            }
        }
        return bestMatch
    }

    /// Simple Levenshtein distance for short strings.
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        return matrix[m][n]
    }

    // MARK: - Vocabulary Response

    /// Returns the full vocabulary for Claude to reference.
    static func vocabulary(stage: GrowthStage) -> [String: Any] {
        var result: [String: Any] = [:]
        result["tracks"] = validStatesPerTrack
        result["categories"] = validCategories
        result["stages"] = Schema.validStages
        result["current_stage"] = "\(stage)"
        result["easing_types"] = Keyframe.EasingType.allCases.map(\.rawValue)
        result["contexts"] = validContexts
        result["max_keyframes_per_track"] = 50
        result["max_tracks"] = 13
        result["duration_range"] = ["min": 0.5, "max": 30.0]
        return result
    }
}
