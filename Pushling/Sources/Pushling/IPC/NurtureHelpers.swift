// NurtureHelpers.swift — Trigger parsing, JSON utilities, energy estimation
// Extracted from NurtureHandlers.swift for file-size compliance.

import Foundation

// MARK: - Trigger Parsing Helpers

extension CommandRouter {

    /// Parses a trigger dictionary from IPC params into a TriggerDefinition.
    static func parseTrigger(_ dict: [String: Any]) -> TriggerDefinition? {
        guard let type = dict["type"] as? String else { return nil }

        switch type {
        case "after_event":
            let event = dict["event"] as? String ?? "commit"
            return .afterEvent(event: event)

        case "on_idle":
            let seconds = dict["min_idle_s"] as? Double ?? 120.0
            return .onIdle(minIdleSeconds: seconds)

        case "at_time":
            let hour = dict["hour"] as? Int ?? 9
            let minute = dict["minute"] as? Int ?? 0
            let window = dict["window_minutes"] as? Int ?? 30
            return .atTime(hour: hour, minute: minute, windowMinutes: window)

        case "on_emotion":
            guard let axis = dict["axis"] as? String,
                  let direction = dict["direction"] as? String,
                  let threshold = dict["threshold"] as? Double else { return nil }
            return .onEmotion(axis: axis, direction: direction,
                              threshold: threshold)

        case "on_weather":
            let weather = dict["weather"] as? String ?? "rain"
            return .onWeather(weather: weather)

        case "on_wake":
            return .onWake

        case "on_session":
            let event = dict["event"] as? String ?? "start"
            return .onSession(event: event)

        case "on_touch":
            let touchType = dict["touch_type"] as? String ?? "any"
            return .onTouch(type: touchType)

        case "periodic":
            let interval = dict["interval_minutes"] as? Int ?? 30
            let jitter = dict["jitter_minutes"] as? Int ?? 5
            return .periodic(intervalMinutes: interval, jitterMinutes: jitter)

        case "on_streak":
            let days = dict["min_days"] as? Int ?? 3
            return .onStreak(minDays: days)

        default:
            return nil
        }
    }

    /// Serializes a trigger dictionary to JSON string.
    static func serializeTriggerJSON(_ dict: [String: Any]) -> String {
        return dictToJSON(dict)
    }

    /// Generic dictionary-to-JSON helper.
    static func dictToJSON(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: value, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - Behavior Energy Estimation (CreatureRejection)

extension CommandRouter {

    /// Estimates behavior energy level (0.0-1.0) from behavior name.
    /// High-energy: spin, dash, jump, bounce, zoomie, chase
    /// Low-energy: sit, rest, loaf, sleep, meditate, watch
    static func estimateBehaviorEnergy(_ behavior: String) -> Double {
        let high = ["spin", "dash", "jump", "bounce", "zoomie", "chase",
                    "pounce", "flip", "run", "sprint", "dance", "wiggle"]
        let low = ["sit", "rest", "loaf", "sleep", "meditate", "watch",
                   "curl", "nap", "yawn", "listen", "reflect", "doze"]

        let lower = behavior.lowercased()
        for word in high where lower.contains(word) { return 0.85 }
        for word in low where lower.contains(word) { return 0.15 }
        return 0.5  // Neutral energy for unknown behaviors
    }
}

// MARK: - PreferenceResponse Description

extension PreferenceResponse: CustomStringConvertible {
    public var description: String {
        switch self {
        case .strongAvoid:    return "strong_avoid"
        case .mildAvoid:      return "mild_avoid"
        case .neutral:        return "neutral"
        case .mildApproach:   return "mild_approach"
        case .strongApproach: return "strong_approach"
        }
    }
}
