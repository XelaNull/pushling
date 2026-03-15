// NurtureHandlers.swift — Set, remove, reinforce for habits/preferences/quirks/routines
// Extension on CommandRouter. Dispatches to HabitEngine, PreferenceEngine,
// QuirkEngine, RoutineEngine and persists to SQLite.

import Foundation

// MARK: - Nurture Set Dispatch

extension CommandRouter {

    /// Dispatch "set" to the correct sub-type based on params["type"].
    func handleNurtureSet(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let type = req.params["type"] as? String else {
            return .failure(
                error: "Missing 'type'. Valid: habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }
        switch type {
        case "habit":      return handleNurtureSetHabit(req, gc: gc)
        case "preference": return handleNurtureSetPreference(req, gc: gc)
        case "quirk":      return handleNurtureSetQuirk(req, gc: gc)
        case "routine":    return handleNurtureSetRoutine(req, gc: gc)
        default:
            return .failure(
                error: "Unknown nurture type '\(type)'. "
                    + "Valid: habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }
    }
}

// MARK: - Habit

extension CommandRouter {

    func handleNurtureSetHabit(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let name = req.params["name"] as? String, !name.isEmpty else {
            return .failure(error: "Missing 'name' for habit.", code: "INVALID_PARAMS")
        }
        guard let behavior = req.params["behavior"] as? String, !behavior.isEmpty else {
            return .failure(error: "Missing 'behavior' — what the creature does when "
                + "the habit fires (e.g. 'stretch', 'spin', 'wave').", code: "INVALID_PARAMS")
        }
        guard let triggerDict = req.params["trigger"] as? [String: Any] else {
            return .failure(
                error: "Missing 'trigger' object. Example: "
                    + "{\"type\": \"after_event\", \"event\": \"commit\"}. "
                    + "Trigger types: after_event, on_idle, at_time, on_emotion, "
                    + "on_weather, on_wake, on_session, on_touch, periodic.",
                code: "INVALID_PARAMS")
        }

        guard let trigger = Self.parseTrigger(triggerDict) else {
            return .failure(
                error: "Invalid trigger definition. Check 'type' field.",
                code: "INVALID_PARAMS")
        }

        let freq = HabitFrequency(rawValue: req.params["frequency"] as? String ?? "sometimes")
            ?? .sometimes
        let variation = VariationLevel(rawValue: req.params["variation"] as? String ?? "moderate")
            ?? .moderate
        let cooldown = req.params["cooldown_s"] as? Double ?? 60.0
        let variant = req.params["variant"] as? String
        let id = UUID().uuidString

        let habit = HabitDefinition(
            id: id, name: name, trigger: trigger,
            behavior: behavior, behaviorVariant: variant,
            frequency: freq, variation: variation,
            energyCost: 0.1, stageMin: gc.creatureStage,
            priority: req.params["priority"] as? Int ?? 5,
            strength: 0.5, reinforcementCount: 0,
            personalityConflict: false, lastFiredAt: nil,
            cooldownSeconds: cooldown
        )

        guard gc.habitEngine.addHabit(habit) else {
            return .failure(
                error: "At habit cap (\(HabitEngine.maxHabits)). Remove one first.",
                code: "AT_CAP")
        }

        // Persist to SQLite
        let db = gc.stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        let triggerJSON = Self.serializeTriggerJSON(triggerDict)
        var actionDict: [String: Any] = ["behavior": behavior]
        if let v = variant { actionDict["variant"] = v }
        let actionJSON = Self.dictToJSON(actionDict)

        do {
            try db.execute(
                """
                INSERT INTO habits (name, trigger_json, action_json, frequency,
                    variation, strength, cooldown_s, created_at)
                VALUES (?, ?, ?, ?, ?, 0.5, ?, ?)
                """,
                arguments: [name, triggerJSON, actionJSON,
                            freq.rawValue, variation.rawValue, cooldown, now]
            )
        } catch {
            NSLog("[Pushling/Nurture] Failed to persist habit: %@", "\(error)")
        }

        journalLog(gc, type: "nurture", summary: "Habit set: '\(name)' -> \(behavior)")

        return .success([
            "created": true, "name": name,
            "behavior": behavior, "frequency": freq.rawValue,
            "strength": 0.5, "trigger_type": triggerDict["type"] as? String ?? "unknown",
            "note": "Habit '\(name)' is now active. It will fire based on trigger conditions."
        ])
    }
}

// MARK: - Preference

extension CommandRouter {

    func handleNurtureSetPreference(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let subject = req.params["subject"] as? String, !subject.isEmpty else {
            return .failure(error: "Missing 'subject' — what the creature has "
                + "an opinion about (e.g. 'rain', 'morning', 'mushrooms').",
                code: "INVALID_PARAMS")
        }
        guard let valence = req.params["valence"] as? Double else {
            return .failure(error: "Missing 'valence' — a number from -1.0 (strong dislike) "
                + "to +1.0 (fascination). 0.0 is neutral.",
                code: "INVALID_PARAMS")
        }
        guard valence >= -1.0 && valence <= 1.0 else {
            return .failure(error: "Valence must be between -1.0 and 1.0.",
                            code: "INVALID_PARAMS")
        }

        let id = UUID().uuidString
        let added = gc.preferenceEngine.setPreference(
            id: id, subject: subject, valence: valence
        )

        guard added else {
            return .failure(
                error: "At preference cap (\(PreferenceEngine.maxPreferences)). "
                    + "Remove one first.",
                code: "AT_CAP")
        }

        // Persist to SQLite
        let db = gc.stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())

        do {
            try db.execute(
                """
                INSERT INTO preferences (subject, valence, strength, created_at)
                VALUES (?, ?, 0.5, ?)
                ON CONFLICT(subject) DO UPDATE SET valence = excluded.valence
                """,
                arguments: [subject, valence, now]
            )
        } catch {
            // preferences table may not have UNIQUE on subject — try plain insert
            do {
                try db.execute(
                    "INSERT INTO preferences (subject, valence, strength, created_at) "
                    + "VALUES (?, ?, 0.5, ?)",
                    arguments: [subject, valence, now]
                )
            } catch {
                NSLog("[Pushling/Nurture] Failed to persist preference: %@", "\(error)")
            }
        }

        let verb = valence > 0.3 ? "loves" : (valence < -0.3 ? "dislikes" : "is neutral about")
        journalLog(gc, type: "nurture",
                   summary: "Preference set: \(verb) \(subject) (\(String(format: "%+.1f", valence)))")

        return .success([
            "created": true, "subject": subject,
            "valence": valence, "strength": 0.5,
            "response": gc.preferenceEngine.response(for: subject).description,
            "note": "Preference for '\(subject)' set. It now influences autonomous behavior."
        ])
    }
}

// MARK: - Quirk

extension CommandRouter {

    func handleNurtureSetQuirk(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let name = req.params["name"] as? String, !name.isEmpty else {
            return .failure(error: "Missing 'name' for quirk.", code: "INVALID_PARAMS")
        }
        guard let target = req.params["target"] as? String, !target.isEmpty else {
            return .failure(error: "Missing 'target' — which behavior this quirk modifies "
                + "(e.g. 'walk', 'idle', 'stretch').",
                code: "INVALID_PARAMS")
        }
        guard let modifierDict = req.params["modifier"] as? [String: Any] else {
            return .failure(
                error: "Missing 'modifier' object. Example: "
                    + "{\"type\": \"append\", \"track\": \"tail\", "
                    + "\"state\": \"flick\", \"duration_s\": 0.5}. "
                    + "Types: prepend, append, replace_element, overlay.",
                code: "INVALID_PARAMS")
        }

        let modType = QuirkModification(rawValue: modifierDict["type"] as? String ?? "append")
            ?? .append
        let track = modifierDict["track"] as? String ?? "tail"
        let state = modifierDict["state"] as? String ?? "flick"
        let duration = modifierDict["duration_s"] as? Double ?? 0.5
        let probability = req.params["probability"] as? Double ?? 0.5
        let id = UUID().uuidString

        let quirk = QuirkDefinition(
            id: id, name: name,
            description: req.params["description"] as? String,
            targetBehavior: target,
            modification: modType,
            action: QuirkAction(track: track, state: state,
                                durationSeconds: duration),
            probability: Swift.max(0.05, Swift.min(0.90, probability)),
            strength: 0.5, reinforcementCount: 0,
            createdAt: Date()
        )

        guard gc.quirkEngine.addQuirk(quirk) else {
            return .failure(
                error: "At quirk cap (\(QuirkEngine.maxQuirks)). Remove one first.",
                code: "AT_CAP")
        }

        // Persist
        let db = gc.stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        let modJSON = Self.dictToJSON(modifierDict)

        do {
            try db.execute(
                """
                INSERT INTO quirks (name, behavior_target, modifier_json,
                    probability, strength, created_at)
                VALUES (?, ?, ?, ?, 0.5, ?)
                """,
                arguments: [name, target, modJSON, probability, now]
            )
        } catch {
            NSLog("[Pushling/Nurture] Failed to persist quirk: %@", "\(error)")
        }

        journalLog(gc, type: "nurture",
                   summary: "Quirk set: '\(name)' modifies \(target) (\(modType.rawValue))")

        return .success([
            "created": true, "name": name,
            "target": target, "modification": modType.rawValue,
            "probability": probability, "strength": 0.5,
            "note": "Quirk '\(name)' is now active. It will modify '\(target)' behavior "
                + "with \(Int(probability * 100))% chance."
        ])
    }
}

// MARK: - Routine

extension CommandRouter {

    func handleNurtureSetRoutine(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let slotStr = req.params["slot"] as? String else {
            let valid = RoutineSlot.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Missing 'slot'. Valid lifecycle slots: \(valid)",
                code: "INVALID_PARAMS")
        }
        guard let slot = RoutineSlot(rawValue: slotStr) else {
            let valid = RoutineSlot.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown slot '\(slotStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS")
        }
        guard let stepsArray = req.params["steps"] as? [[String: Any]] else {
            return .failure(
                error: "Missing 'steps' array. Each step: "
                    + "{\"type\": \"perform|express|speak|move|wait\", ...}. "
                    + "2-6 steps required.",
                code: "INVALID_PARAMS")
        }
        guard stepsArray.count >= 2 && stepsArray.count <= 6 else {
            return .failure(
                error: "Routines require 2-6 steps. Got \(stepsArray.count).",
                code: "INVALID_PARAMS")
        }

        var steps: [RoutineStep] = []
        for stepDict in stepsArray {
            guard let typeStr = stepDict["type"] as? String,
                  let stepType = RoutineStep.RoutineStepType(rawValue: typeStr) else {
                return .failure(
                    error: "Invalid step type. Valid: perform, express, speak, move, wait.",
                    code: "INVALID_PARAMS")
            }
            let step = RoutineStep(
                type: stepType,
                behavior: stepDict["behavior"] as? String,
                variant: stepDict["variant"] as? String,
                expression: stepDict["expression"] as? String,
                text: stepDict["text"] as? String,
                movementAction: stepDict["movement"] as? String,
                durationSeconds: stepDict["duration_s"] as? Double ?? 2.0
            )
            steps.append(step)
        }

        let id = UUID().uuidString
        let routine = RoutineDefinition(
            id: id, slot: slot, steps: steps,
            strength: 0.5, reinforcementCount: 0,
            createdAt: Date()
        )

        gc.routineEngine.setRoutine(routine)

        // Persist
        let db = gc.stateCoordinator.database
        let formatter = ISO8601DateFormatter()
        let now = formatter.string(from: Date())
        let stepsJSON = Self.dictToJSON(stepsArray)

        do {
            try db.execute(
                """
                INSERT INTO routines (slot, steps_json, strength, created_at)
                VALUES (?, ?, 0.5, ?)
                ON CONFLICT(slot) DO UPDATE SET
                    steps_json = excluded.steps_json,
                    strength = 0.5,
                    reinforcement_count = 0
                """,
                arguments: [slotStr, stepsJSON, now]
            )
        } catch {
            NSLog("[Pushling/Nurture] Failed to persist routine: %@", "\(error)")
        }

        journalLog(gc, type: "nurture",
                   summary: "Routine set: '\(slotStr)' (\(steps.count) steps)")

        return .success([
            "created": true, "slot": slotStr,
            "steps": steps.count,
            "total_duration_s": routine.totalDuration,
            "note": "Custom routine for '\(slotStr)' is now active. "
                + "It replaces the default \(slotStr) behavior."
        ])
    }
}

// MARK: - Remove

extension CommandRouter {

    func handleNurtureRemove(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let type = req.params["type"] as? String else {
            return .failure(
                error: "Missing 'type'. Specify what to remove: "
                    + "habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }

        let db = gc.stateCoordinator.database

        switch type {
        case "habit":
            guard let name = req.params["name"] as? String else {
                return .failure(error: "Missing 'name' of habit to remove.",
                                code: "INVALID_PARAMS")
            }
            gc.habitEngine.removeHabit(named: name)
            try? db.execute("DELETE FROM habits WHERE name = ?", arguments: [name])
            journalLog(gc, type: "nurture", summary: "Habit removed: '\(name)'")
            return .success(["removed": true, "type": "habit", "name": name])

        case "preference":
            guard let subject = req.params["subject"] as? String else {
                return .failure(error: "Missing 'subject' of preference to remove.",
                                code: "INVALID_PARAMS")
            }
            gc.preferenceEngine.removePreference(subject: subject)
            try? db.execute("DELETE FROM preferences WHERE subject = ?",
                            arguments: [subject])
            journalLog(gc, type: "nurture", summary: "Preference removed: '\(subject)'")
            return .success(["removed": true, "type": "preference", "subject": subject])

        case "quirk":
            guard let name = req.params["name"] as? String else {
                return .failure(error: "Missing 'name' of quirk to remove.",
                                code: "INVALID_PARAMS")
            }
            gc.quirkEngine.removeQuirk(named: name)
            try? db.execute("DELETE FROM quirks WHERE name = ?", arguments: [name])
            journalLog(gc, type: "nurture", summary: "Quirk removed: '\(name)'")
            return .success(["removed": true, "type": "quirk", "name": name])

        case "routine":
            guard let slotStr = req.params["slot"] as? String,
                  let slot = RoutineSlot(rawValue: slotStr) else {
                let valid = RoutineSlot.allCases.map(\.rawValue).joined(separator: ", ")
                return .failure(error: "Missing or invalid 'slot'. Valid: \(valid)",
                                code: "INVALID_PARAMS")
            }
            gc.routineEngine.resetToDefault(slot: slot)
            try? db.execute("DELETE FROM routines WHERE slot = ?", arguments: [slotStr])
            journalLog(gc, type: "nurture", summary: "Routine reset to default: '\(slotStr)'")
            return .success(["removed": true, "type": "routine", "slot": slotStr,
                             "note": "Slot '\(slotStr)' reverted to default behavior."])

        default:
            return .failure(
                error: "Unknown type '\(type)'. Valid: habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }
    }
}

// MARK: - Reinforce

extension CommandRouter {

    func handleNurtureReinforce(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let type = req.params["type"] as? String else {
            return .failure(
                error: "Missing 'type'. Specify what to reinforce: "
                    + "habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }

        let db = gc.stateCoordinator.database

        switch type {
        case "habit":
            guard let name = req.params["name"] as? String else {
                return .failure(error: "Missing 'name' of habit to reinforce.",
                                code: "INVALID_PARAMS")
            }
            let prev = gc.habitEngine.habits.first { $0.name == name }
            guard prev != nil else {
                return .failure(error: "No habit named '\(name)'.",
                                code: "NOT_FOUND")
            }
            let newStrength = Swift.min((prev?.strength ?? 0.5) + 0.15, 1.0)
            gc.habitEngine.updateStrength(name: name, strength: newStrength)
            try? db.execute(
                "UPDATE habits SET strength = ?, reinforcement_count = reinforcement_count + 1 "
                + "WHERE name = ?",
                arguments: [newStrength, name]
            )
            journalLog(gc, type: "nurture",
                       summary: "Habit reinforced: '\(name)' -> \(String(format: "%.2f", newStrength))")
            return .success(["reinforced": true, "name": name,
                             "strength": newStrength, "type": "habit"])

        case "preference":
            guard let subject = req.params["subject"] as? String else {
                return .failure(error: "Missing 'subject' of preference to reinforce.",
                                code: "INVALID_PARAMS")
            }
            guard gc.preferenceEngine.preference(for: subject) != nil else {
                return .failure(error: "No preference for '\(subject)'.",
                                code: "NOT_FOUND")
            }
            gc.preferenceEngine.reinforce(subject: subject)
            let newPref = gc.preferenceEngine.preference(for: subject)
            let newStrength = newPref?.strength ?? 0.5
            try? db.execute(
                "UPDATE preferences SET strength = ?, "
                + "reinforcement_count = reinforcement_count + 1 "
                + "WHERE subject = ?",
                arguments: [newStrength, subject]
            )
            return .success(["reinforced": true, "subject": subject,
                             "strength": newStrength, "type": "preference"])

        case "quirk":
            guard let name = req.params["name"] as? String else {
                return .failure(error: "Missing 'name' of quirk to reinforce.",
                                code: "INVALID_PARAMS")
            }
            guard gc.quirkEngine.quirks.contains(where: { $0.name == name }) else {
                return .failure(error: "No quirk named '\(name)'.",
                                code: "NOT_FOUND")
            }
            gc.quirkEngine.reinforce(named: name)
            let newStrength = gc.quirkEngine.quirks.first { $0.name == name }?.strength ?? 0.5
            try? db.execute(
                "UPDATE quirks SET strength = ?, "
                + "reinforcement_count = reinforcement_count + 1 "
                + "WHERE name = ?",
                arguments: [newStrength, name]
            )
            return .success(["reinforced": true, "name": name,
                             "strength": newStrength, "type": "quirk"])

        case "routine":
            guard let slotStr = req.params["slot"] as? String else {
                return .failure(error: "Missing 'slot' of routine to reinforce.",
                                code: "INVALID_PARAMS")
            }
            try? db.execute(
                "UPDATE routines SET strength = MIN(strength + 0.15, 1.0), "
                + "reinforcement_count = reinforcement_count + 1 "
                + "WHERE slot = ?",
                arguments: [slotStr]
            )
            let newStrength = (try? db.query(
                "SELECT strength FROM routines WHERE slot = ?",
                arguments: [slotStr]
            ))?.first?["strength"] as? Double ?? 0.5
            return .success(["reinforced": true, "slot": slotStr,
                             "strength": newStrength, "type": "routine"])

        default:
            return .failure(
                error: "Unknown type '\(type)'. Valid: habit, preference, quirk, routine.",
                code: "INVALID_PARAMS")
        }
    }
}

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
            return .onEmotion(axis: axis, direction: direction, threshold: threshold)

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
