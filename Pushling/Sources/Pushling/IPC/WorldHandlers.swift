// WorldHandlers.swift — pushling_world IPC handler
// Extension on CommandRouter for world-shaping: weather, events, time override,
// object create/place/remove/modify, companion management.
// Dispatches to WorldManager and its subsystems.

import Foundation
import CoreGraphics

// MARK: - World Handler

extension CommandRouter {

    func handleWorld(_ req: IPCRequest) -> IPCResult {
        guard let gc = gameCoordinator else {
            return .failure(error: "Creature systems not initialized.",
                            code: "NOT_READY")
        }

        let action = req.action ?? "weather"

        switch action {
        case "weather":
            return handleWorldWeather(req, gc: gc)
        case "event":
            return handleWorldEvent(req, gc: gc)
        case "time_override":
            return handleWorldTimeOverride(req, gc: gc)
        case "place", "create":
            return handleWorldCreate(req, gc: gc)
        case "remove":
            return handleWorldRemove(req, gc: gc)
        case "modify":
            return handleWorldModify(req, gc: gc)
        case "list":
            return handleWorldList(gc: gc)
        case "sound":
            return .failure(
                error: "Ambient sound system is not yet integrated. "
                    + "Use 'speak' for creature sounds.",
                code: "NOT_IMPLEMENTED"
            )
        case "companion":
            return handleWorldCompanion(req, gc: gc)
        default:
            return .failure(
                error: "Unknown world action '\(action)'.",
                code: "UNKNOWN_ACTION"
            )
        }
    }

    // MARK: - Weather

    private func handleWorldWeather(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager
        let previous = wm.currentWeather

        guard let typeStr = req.params["type"] as? String else {
            return .success([
                "current": wm.currentWeather.rawValue,
                "time_of_day": wm.currentTimePeriod.rawValue,
                "moon_phase": wm.moonPhaseName,
                "is_full_moon": wm.isFullMoon,
                "description": wm.weatherDescription
            ])
        }

        guard let weatherState = WeatherState(rawValue: typeStr) else {
            let valid = WeatherState.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown weather type '\(typeStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        let duration = req.params["duration"] as? Int ?? 300

        DispatchQueue.main.async {
            wm.debugForceWeather(weatherState)
        }

        journalLog(gc, type: "world_change",
                   summary: "Weather changed: \(previous.rawValue) -> \(typeStr)")

        return .success([
            "type": typeStr,
            "previous": previous.rawValue,
            "duration_s": duration,
            "note": "Weather transitioning over 30-60s."
        ])
    }

    // MARK: - Visual Events

    private func handleWorldEvent(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager

        guard let typeStr = req.params["type"] as? String else {
            let valid = VisualEventType.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Missing 'type' parameter. Valid visual events: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        guard let eventType = VisualEventType(rawValue: typeStr) else {
            let valid = VisualEventType.allCases.map(\.rawValue).joined(separator: ", ")
            return .failure(
                error: "Unknown visual event '\(typeStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        var started = false
        DispatchQueue.main.sync {
            started = wm.triggerVisualEvent(eventType)
        }

        if started {
            journalLog(gc, type: "world_change",
                       summary: "Visual event triggered: \(typeStr)")
            return .success([
                "event": typeStr,
                "started": true,
                "duration_s": eventType.duration
            ])
        } else {
            return .success([
                "event": typeStr,
                "started": false,
                "note": "Event was queued or stage requirement not met. "
                    + "Visual events require critter+ stage."
            ])
        }
    }

    // MARK: - Time Override

    private func handleWorldTimeOverride(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let periodStr = req.params["period"] as? String else {
            let current = gc.scene.worldManager.currentTimePeriod
            return .success([
                "current_period": current.rawValue,
                "note": "Pass 'period' to override. Valid: "
                    + TimePeriod.allCases.map(\.rawValue).joined(separator: ", ")
            ])
        }

        if periodStr == "auto" {
            DispatchQueue.main.async {
                gc.scene.worldManager.skySystem.timeOverrideHour = nil
            }
            return .success([
                "period": "auto",
                "note": "Sky time override cleared. Using wall clock."
            ])
        }

        guard let period = TimePeriod(rawValue: periodStr) else {
            let valid = TimePeriod.allCases.map(\.rawValue).joined(separator: ", ")
                + ", auto"
            return .failure(
                error: "Unknown time period '\(periodStr)'. Valid: \(valid)",
                code: "INVALID_PARAMS"
            )
        }

        DispatchQueue.main.async {
            gc.scene.worldManager.skySystem.timeOverrideHour = period.startHour + 0.5
        }

        return .success([
            "period": periodStr,
            "note": "Sky time overridden to \(periodStr). Use 'period: auto' to restore."
        ])
    }

    // MARK: - Object Create / Place

    private func handleWorldCreate(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager

        let shape = req.params["base_shape"] as? String
            ?? req.params["shape"] as? String ?? "sphere"

        var result: (info: ObjectInfo, error: String?)?
        DispatchQueue.main.sync {
            result = wm.createObject(params: req.params)
        }

        guard let created = result else {
            return .failure(
                error: "Object creation failed. Possible reasons: "
                    + "object cap reached (max 12 persistent, 3 consumable), "
                    + "too close to existing object (min 20pt spacing), "
                    + "or node budget exceeded (max 40 object nodes).",
                code: "OBJECT_CAP_REACHED"
            )
        }

        journalLog(gc, type: "world_change",
                   summary: "Placed object: \(created.info.name) "
                       + "(\(shape)) at x=\(Int(created.info.positionX))")

        return .success([
            "created": true,
            "object": created.info.asDictionary,
            "note": "Object '\(created.info.name)' placed at "
                + "x=\(Int(created.info.positionX)). "
                + "It is now visible on the Touch Bar."
        ])
    }

    // MARK: - Object Remove

    private func handleWorldRemove(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let objectId = req.params["id"] as? Int else {
            return .failure(
                error: "Missing 'id' parameter. Use 'world list' to see "
                    + "object IDs, then 'world remove' with the ID.",
                code: "INVALID_PARAMS"
            )
        }

        let wm = gc.scene.worldManager
        var removed = false
        DispatchQueue.main.sync {
            removed = wm.removeObject(id: objectId)
        }

        if removed {
            journalLog(gc, type: "world_change",
                       summary: "Removed object id=\(objectId)")

            return .success([
                "removed": true,
                "id": objectId,
                "note": "Object removed from the world."
            ])
        } else {
            return .failure(
                error: "Object with id \(objectId) not found or already removed.",
                code: "NOT_FOUND"
            )
        }
    }

    // MARK: - Object Modify (repair)

    private func handleWorldModify(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        guard let objectId = req.params["id"] as? Int else {
            return .failure(
                error: "Missing 'id' parameter.",
                code: "INVALID_PARAMS"
            )
        }

        let wm = gc.scene.worldManager

        if let repair = req.params["repair"] as? Bool, repair {
            let db = gc.stateCoordinator.database
            guard let rows = try? db.query(
                "SELECT position_x FROM world_objects WHERE id = ? AND is_active = 1",
                arguments: [objectId]
            ), let row = rows.first,
                  let posX = row["position_x"] as? Double else {
                return .failure(
                    error: "Object with id \(objectId) not found.",
                    code: "NOT_FOUND"
                )
            }

            DispatchQueue.main.sync {
                if let nearest = wm.objectRenderer.nearestObject(
                    to: CGFloat(posX), maxDistance: 1.0
                ) {
                    wm.objectRenderer.repairObject(objectID: nearest.id)
                    wm.objectWearSystem.repair(objectID: nearest.id)
                }
            }

            try? db.execute(
                "UPDATE world_objects SET wear = 0.0 WHERE id = ?",
                arguments: [objectId]
            )

            journalLog(gc, type: "world_change",
                       summary: "Repaired object id=\(objectId)")

            return .success([
                "repaired": true,
                "id": objectId,
                "note": "Object repaired. Wear reset to 0."
            ])
        }

        return .failure(
            error: "Pass 'repair: true' to repair an object. "
                + "Other modifications are not yet supported.",
            code: "INVALID_PARAMS"
        )
    }

    // MARK: - Object List

    private func handleWorldList(gc: GameCoordinator) -> IPCResult {
        let wm = gc.scene.worldManager
        let objects = wm.listObjects()
        let objectDicts = objects.map(\.asDictionary)

        var result: [String: Any] = [
            "objects": objectDicts,
            "count": objects.count,
            "max_persistent": WorldObjectRenderer.maxPersistentObjects,
            "max_consumables": WorldObjectRenderer.maxConsumables
        ]

        if let info = wm.companionSystem.companionInfo {
            result["companion"] = [
                "type": info.type.rawValue,
                "name": info.name
            ]
        }

        return .success(result)
    }

    // MARK: - Companion

    private func handleWorldCompanion(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let wm = gc.scene.worldManager
        let subAction = req.params["action"] as? String ?? "spawn"

        switch subAction {
        case "spawn", "add":
            guard let typeStr = req.params["type"] as? String else {
                let validTypes = CompanionType.allCases
                    .map(\.rawValue).joined(separator: ", ")
                return .failure(
                    error: "Missing 'type' parameter. "
                        + "Valid companion types: \(validTypes)",
                    code: "INVALID_PARAMS"
                )
            }

            let name = req.params["name"] as? String

            var companionInfo: [String: Any]?
            DispatchQueue.main.sync {
                companionInfo = wm.addCompanion(typeStr: typeStr, name: name)
            }

            guard let info = companionInfo else {
                let validTypes = CompanionType.allCases
                    .map(\.rawValue).joined(separator: ", ")
                return .failure(
                    error: "Unknown companion type '\(typeStr)'. "
                        + "Valid: \(validTypes)",
                    code: "INVALID_PARAMS"
                )
            }

            journalLog(gc, type: "world_change",
                       summary: "Companion spawned: \(info["name"] ?? typeStr)")

            return .success([
                "spawned": true,
                "companion": info,
                "note": "Companion '\(info["name"] ?? "")' has appeared! "
                    + "It wanders autonomously near the creature."
            ])

        case "remove", "despawn":
            var removed = false
            DispatchQueue.main.sync {
                removed = wm.removeCompanion()
            }

            if removed {
                journalLog(gc, type: "world_change",
                           summary: "Companion removed")
                return .success([
                    "removed": true,
                    "note": "Companion has departed."
                ])
            } else {
                return .failure(
                    error: "No active companion to remove.",
                    code: "NO_COMPANION"
                )
            }

        case "status":
            if let info = wm.companionSystem.companionInfo {
                return .success([
                    "has_companion": true,
                    "type": info.type.rawValue,
                    "name": info.name,
                    "display_name": info.type.displayName
                ])
            } else {
                return .success([
                    "has_companion": false,
                    "note": "No companion currently active. "
                        + "Use 'companion' action with 'type' to spawn one."
                ])
            }

        default:
            return .failure(
                error: "Unknown companion action '\(subAction)'. "
                    + "Valid: spawn, remove, status",
                code: "UNKNOWN_ACTION"
            )
        }
    }
}
