// PreferenceEngine.swift — Valence-based preference modulation
// Preferences are tags with valence (-1.0 to +1.0) that modulate
// autonomous behavior: approach/avoid, expression bias, linger duration.
//
// Max 12 active preferences.
// Integrated into autonomous behavior selection and object interaction scoring.

import Foundation

// MARK: - Preference

/// A persistent preference that modulates creature behavior.
struct Preference {
    let id: String
    let subject: String             // "rain", "mushrooms", "morning", etc.
    var valence: Double             // -1.0 (strong dislike) to +1.0 (fascination)
    var strength: Double            // 0.0-1.0 (from decay system)
    var reinforcementCount: Int
    let createdAt: Date

    /// Effective valence = valence * strength.
    var effectiveValence: Double {
        valence * strength
    }

    /// Behavioral response for this preference.
    var response: PreferenceResponse {
        let v = effectiveValence
        switch v {
        case ...(-0.6):
            return .strongAvoid
        case ...(-0.1):
            return .mildAvoid
        case (-0.1)...0.1:
            return .neutral
        case ...0.5:
            return .mildApproach
        default:
            return .strongApproach
        }
    }
}

/// Behavioral response derived from effective valence.
enum PreferenceResponse {
    case strongAvoid       // -1.0 to -0.6: active avoidance
    case mildAvoid         // -0.5 to -0.1: slight avoidance
    case neutral           // -0.1 to +0.1: no effect
    case mildApproach      // +0.1 to +0.5: slight interest
    case strongApproach    // +0.6 to +1.0: active approach

    /// Speed modifier for autonomous movement near this subject.
    var speedModifier: Double {
        switch self {
        case .strongAvoid:    return 1.5   // Move away faster
        case .mildAvoid:      return 1.1
        case .neutral:        return 1.0
        case .mildApproach:   return 0.8   // Slow down, linger
        case .strongApproach: return 0.6   // Linger significantly
        }
    }

    /// Expression bias for when this subject is relevant.
    var expressionBias: String? {
        switch self {
        case .strongAvoid:    return "ears_flat"
        case .mildAvoid:      return "squint"
        case .neutral:        return nil
        case .mildApproach:   return "interested"
        case .strongApproach: return "joy"
        }
    }

    /// Interaction frequency modifier.
    var interactionModifier: Double {
        switch self {
        case .strongAvoid:    return 0.1   // Avoid interactions
        case .mildAvoid:      return 0.5
        case .neutral:        return 1.0
        case .mildApproach:   return 1.3
        case .strongApproach: return 2.0   // Seek out interactions
        }
    }
}

// MARK: - PreferenceEngine

/// Manages preferences and provides behavioral modulation values.
final class PreferenceEngine {

    // MARK: - Configuration

    /// Maximum active preferences.
    static let maxPreferences = 12

    // MARK: - State

    /// Active preferences keyed by subject.
    private var preferences: [String: Preference] = [:]

    // MARK: - Preference Management

    /// Adds or updates a preference.
    @discardableResult
    func setPreference(id: String, subject: String,
                       valence: Double, strength: Double = 0.5) -> Bool {
        // Update existing
        if var existing = preferences[subject] {
            existing.valence = Swift.max(-1.0, Swift.min(1.0, valence))
            existing.reinforcementCount += 1
            preferences[subject] = existing
            NSLog("[Pushling/Prefs] Updated '%@' valence to %.2f",
                  subject, valence)
            return true
        }

        // Cap check for new
        guard preferences.count < Self.maxPreferences else {
            NSLog("[Pushling/Prefs] At cap (%d). Cannot add '%@'.",
                  Self.maxPreferences, subject)
            return false
        }

        preferences[subject] = Preference(
            id: id, subject: subject,
            valence: Swift.max(-1.0, Swift.min(1.0, valence)),
            strength: strength, reinforcementCount: 0,
            createdAt: Date()
        )
        NSLog("[Pushling/Prefs] Added preference '%@' = %.2f",
              subject, valence)
        return true
    }

    /// Removes a preference.
    func removePreference(subject: String) {
        preferences.removeValue(forKey: subject)
    }

    /// Reinforces a preference (increases strength by 0.15).
    func reinforce(subject: String) {
        guard var pref = preferences[subject] else { return }
        pref.strength = Swift.min(pref.strength + 0.15, 1.0)
        pref.reinforcementCount += 1
        preferences[subject] = pref
    }

    // MARK: - Queries

    /// Returns the preference for a subject, if any.
    func preference(for subject: String) -> Preference? {
        return preferences[subject]
    }

    /// Returns the behavioral response for a subject.
    func response(for subject: String) -> PreferenceResponse {
        return preferences[subject]?.response ?? .neutral
    }

    /// Returns the effective valence for a subject.
    func effectiveValence(for subject: String) -> Double {
        return preferences[subject]?.effectiveValence ?? 0.0
    }

    /// Returns all active preferences sorted by absolute valence.
    var allPreferences: [Preference] {
        return preferences.values.sorted {
            abs($0.effectiveValence) > abs($1.effectiveValence)
        }
    }

    /// Returns preferences matching a category of subjects.
    func preferencesMatching(subjects: [String]) -> [Preference] {
        return subjects.compactMap { preferences[$0] }
    }

    // MARK: - Behavioral Modulation

    /// Returns a weight modifier for an object based on its type/name
    /// and any matching preferences.
    ///
    /// Used by AttractionScorer to bias object interaction.
    func objectAttractionModifier(objectType: String,
                                   objectName: String) -> Double {
        // Check for preference matching object type or name
        let subjects = [objectType, objectName.lowercased()]
        for subject in subjects {
            if let pref = preferences[subject] {
                return pref.response.interactionModifier
            }
        }
        return 1.0
    }

    /// Returns a movement speed modifier for the current context.
    /// Call with relevant subjects (weather, time, nearby objects).
    func movementModifier(activeSubjects: [String]) -> Double {
        var modifier = 1.0
        for subject in activeSubjects {
            if let pref = preferences[subject] {
                modifier *= pref.response.speedModifier
            }
        }
        return modifier
    }

    /// Returns expression state overrides based on active context.
    /// Returns nil if no preference applies.
    func expressionOverride(activeSubjects: [String]) -> (eyes: String, ears: String)? {
        // Find strongest relevant preference
        var strongestPref: Preference?
        var strongestAbsValence = 0.0

        for subject in activeSubjects {
            if let pref = preferences[subject] {
                let absV = abs(pref.effectiveValence)
                if absV > strongestAbsValence {
                    strongestPref = pref
                    strongestAbsValence = absV
                }
            }
        }

        guard let pref = strongestPref, strongestAbsValence > 0.3 else {
            return nil
        }

        switch pref.response {
        case .strongAvoid:
            return (eyes: "squint", ears: "flat")
        case .mildAvoid:
            return (eyes: "squint", ears: "back")
        case .strongApproach:
            return (eyes: "wide", ears: "perk")
        case .mildApproach:
            return (eyes: "open", ears: "neutral")
        case .neutral:
            return nil
        }
    }

    // MARK: - Decay Integration

    /// Updates strength for a preference (called by decay system).
    func updateStrength(subject: String, strength: Double) {
        guard var pref = preferences[subject] else { return }
        pref.strength = Swift.max(0.0, Swift.min(1.0, strength))
        preferences[subject] = pref
    }

    // MARK: - Bulk Operations

    /// Loads preferences from SQLite data.
    func loadPreferences(_ data: [Preference]) {
        preferences.removeAll()
        for pref in data.prefix(Self.maxPreferences) {
            preferences[pref.subject] = pref
        }
        NSLog("[Pushling/Prefs] Loaded %d preferences", preferences.count)
    }

    /// Resets all preference state.
    func reset() {
        preferences.removeAll()
    }

    /// Returns the strongest positive and negative preferences.
    var extremes: (loves: Preference?, hates: Preference?) {
        let sorted = allPreferences
        let loves = sorted.first { $0.effectiveValence > 0 }
        let hates = sorted.first { $0.effectiveValence < 0 }
        return (loves, hates)
    }

    /// Summary string for SessionStart injection.
    var sessionSummary: String {
        let active = allPreferences.filter { $0.strength >= 0.2 }
        guard !active.isEmpty else { return "No active preferences." }

        let top = active.prefix(3).map { pref in
            let verb = pref.effectiveValence > 0 ? "loves" : "dislikes"
            return "\(verb) \(pref.subject) (\(String(format: "%+.1f", pref.effectiveValence)))"
        }
        return top.joined(separator: ", ")
    }
}
