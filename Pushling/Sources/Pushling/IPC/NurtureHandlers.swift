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
        let force = req.params["force"] as? Bool ?? false
        let id = UUID().uuidString

        // --- Personality alignment check (Orphan #1: CreatureRejection) ---
        let category = req.params["category"] as? String ?? "playful"
        let energy = Self.estimateBehaviorEnergy(behavior)
        let rejection = gc.creatureRejection.checkAlignment(
            behaviorCategory: category,
            behaviorEnergy: energy,
            personality: gc.personality.toSnapshot(),
            reinforcementCount: 0
        )

        if rejection.hasConflict && !force {
            let conflictMsg: String
            switch rejection.conflict {
            case .energyTooHigh:
                conflictMsg = "This is a high-energy behavior, "
                    + "but the creature is quite calm."
            case .energyTooLow:
                conflictMsg = "This is a low-energy behavior, "
                    + "but the creature is very energetic."
            case .disciplineMismatch:
                conflictMsg = "This requires discipline, "
                    + "but the creature is chaotic."
            case .verbosityMismatch:
                conflictMsg = "This is a chatty behavior, "
                    + "but the creature is stoic."
            case .none:
                conflictMsg = ""
            }

            return .success([
                "created": false, "name": name,
                "personality_conflict": true,
                "conflict_type": rejection.conflict.rawValue,
                "reluctance_level": rejection.reluctanceLevel,
                "note": "\(conflictMsg) The creature resists this habit. "
                    + "Add '\"force\": true' to set it anyway — "
                    + "the creature will perform it reluctantly at first "
                    + "but may accept it after reinforcement."
            ])
        }

        let startStrength = rejection.hasConflict
            ? rejection.startingStrength : 0.5

        let habit = HabitDefinition(
            id: id, name: name, trigger: trigger,
            behavior: behavior, behaviorVariant: variant,
            frequency: freq, variation: variation,
            energyCost: 0.1, stageMin: gc.creatureStage,
            priority: req.params["priority"] as? Int ?? 5,
            strength: startStrength, reinforcementCount: 0,
            personalityConflict: rejection.hasConflict,
            lastFiredAt: nil,
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
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [name, triggerJSON, actionJSON,
                            freq.rawValue, variation.rawValue,
                            startStrength, cooldown, now]
            )
        } catch {
            NSLog("[Pushling/Nurture] Failed to persist habit: %@", "\(error)")
        }

        let conflictNote = rejection.hasConflict
            ? " (personality conflict: \(rejection.conflict.rawValue), "
              + "starting reluctantly at \(String(format: "%.1f", startStrength)))"
            : ""
        journalLog(gc, type: "nurture",
                   summary: "Habit set: '\(name)' -> \(behavior)\(conflictNote)")

        var result: [String: Any] = [
            "created": true, "name": name,
            "behavior": behavior, "frequency": freq.rawValue,
            "strength": startStrength,
            "trigger_type": triggerDict["type"] as? String ?? "unknown",
            "note": "Habit '\(name)' is now active. It will fire based "
                + "on trigger conditions."
        ]
        if rejection.hasConflict {
            result["personality_conflict"] = true
            result["conflict_type"] = rejection.conflict.rawValue
            result["reluctance_level"] = rejection.reluctanceLevel
            result["note"] = "Habit '\(name)' set despite personality conflict "
                + "(\(rejection.conflict.rawValue)). The creature will perform "
                + "reluctantly at first. Reinforce to help it accept."
        }
        return .success(result)
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

// Trigger parsing, JSON helpers, energy estimation, and PreferenceResponse
// conformance are in NurtureHelpers.swift
