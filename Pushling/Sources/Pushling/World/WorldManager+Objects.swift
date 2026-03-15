// WorldManager+Objects.swift — World object CRUD and companion management
// Extension on WorldManager for persistent object creation, removal, listing,
// companion spawning, and SQLite persistence.
// Extracted from WorldManager.swift to keep files under 500 lines.

import SpriteKit

// MARK: - Object Info (for IPC responses)

/// Summary information about a placed world object.
struct ObjectInfo {
    let id: Int
    let name: String
    let baseShape: String
    let positionX: CGFloat
    let layer: String
    let size: CGFloat
    let interaction: String
    let wear: Double
    let source: String
    let createdAt: String

    /// Converts to a dictionary for IPC responses.
    var asDictionary: [String: Any] {
        [
            "id": id,
            "name": name,
            "base_shape": baseShape,
            "position_x": positionX,
            "layer": layer,
            "size": size,
            "interaction": interaction,
            "wear": wear,
            "source": source,
            "created_at": createdAt
        ]
    }
}

// MARK: - Object CRUD

extension WorldManager {

    /// Creates a new world object, renders it, and persists to SQLite.
    ///
    /// - Parameter params: Dictionary from IPC with shape, position, color, etc.
    /// - Returns: The created object's info, or nil if creation failed.
    func createObject(params: [String: Any]) -> (info: ObjectInfo, error: String?)? {
        let baseShape = params["base_shape"] as? String
            ?? params["shape"] as? String ?? "sphere"
        let name = params["name"] as? String ?? baseShape
        let positionX = params["position_x"] as? Double
            ?? params["x"] as? Double ?? Double(cameraWorldX)
        let layer = params["layer"] as? String ?? "fore"
        let size = params["size"] as? Double ?? 1.0
        let primaryColor = params["color"] as? String
            ?? params["primary_color"] as? String ?? "bone"
        let secondaryColor = params["secondary_color"] as? String
        let colorPattern = params["color_pattern"] as? String ?? "solid"
        let effectsList = params["effects"] as? [String] ?? []
        let interaction = params["interaction"] as? String ?? "examining"
        let source = params["source"] as? String ?? "ai_placed"
        let isConsumable = params["consumable"] as? Bool ?? false
        let wearRate = params["wear_rate"] as? Double ?? 0.01

        // Clamp size
        let clampedSize = max(0.5, min(2.0, size))

        // Clamp position within world bounds
        let clampedX = max(Double(SceneConstants.minX),
                           min(Double(SceneConstants.maxX), positionX))

        // Physics defaults
        let weight = params["weight"] as? String ?? "medium"
        let bounciness = params["bounciness"] as? Double ?? 0.3
        let rollable = params["rollable"] as? Bool ?? false
        let pushable = params["pushable"] as? Bool ?? false
        let carryable = params["carryable"] as? Bool ?? false

        let objectID = UUID().uuidString

        let definition = WorldObjectDefinition(
            id: objectID,
            name: name,
            baseShape: baseShape,
            positionX: CGFloat(clampedX),
            layer: layer,
            size: CGFloat(clampedSize),
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            colorPattern: colorPattern,
            effects: effectsList,
            physics: ObjectPhysics(
                weight: weight, bounciness: bounciness,
                rollable: rollable, pushable: pushable,
                carryable: carryable
            ),
            interaction: interaction,
            wearRate: wearRate,
            source: source,
            isConsumable: isConsumable
        )

        // Render the object
        guard let rendered = objectRenderer.createObject(definition) else {
            return nil
        }

        // Persist to SQLite
        let formatter = ISO8601DateFormatter()
        let nowStr = formatter.string(from: rendered.createdAt)

        let colorJson = buildColorJson(primary: primaryColor,
                                        secondary: secondaryColor,
                                        pattern: colorPattern)
        let effectsJson = buildArrayJson(effectsList)
        let physicsJson = buildPhysicsJson(weight: weight,
                                            bounciness: bounciness,
                                            rollable: rollable,
                                            pushable: pushable,
                                            carryable: carryable)

        var dbId = 0
        if let db = database {
            do {
                try db.execute(
                    """
                    INSERT INTO world_objects
                        (name, base_shape, position_x, layer, size,
                         color_json, effects_json, physics_json,
                         interaction, wear, wear_rate, source, is_active, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0.0, ?, ?, 1, ?)
                    """,
                    arguments: [
                        name, baseShape, clampedX, layer, clampedSize,
                        colorJson, effectsJson, physicsJson,
                        interaction, wearRate, source, nowStr
                    ]
                )
                // Query back the auto-increment ID
                dbId = (try? db.queryScalarInt(
                    "SELECT MAX(id) FROM world_objects"
                )) ?? 0
                // Store dbID on the rendered object for consumption tracking
                objectRenderer.updateObject(id: definition.id) { $0.dbID = dbId }
            } catch {
                NSLog("[Pushling/World] Failed to persist object: %@",
                      "\(error)")
            }
        }

        let info = ObjectInfo(
            id: dbId, name: name, baseShape: baseShape,
            positionX: clampedX, layer: layer, size: clampedSize,
            interaction: interaction, wear: 0.0,
            source: source, createdAt: nowStr
        )

        NSLog("[Pushling/World] Created object '%@' (db id: %d) at x=%.1f",
              name, dbId, clampedX)

        return (info: info, error: nil)
    }

    /// Removes an object by its database ID.
    /// - Returns: True if the object was found and removed.
    func removeObject(id: Int) -> Bool {
        // Find the matching rendered object by scanning for its db ID
        // Objects are keyed by UUID in the renderer, so we need the mapping.
        // We stored the db ID in the ObjectInfo, but the renderer uses UUIDs.
        // Approach: mark inactive in DB, remove from renderer by matching name.
        guard let db = database else { return false }

        // Look up the object's name/shape from DB
        guard let rows = try? db.query(
            "SELECT name, position_x FROM world_objects WHERE id = ? AND is_active = 1",
            arguments: [id]
        ), let row = rows.first else {
            return false
        }

        let objName = row["name"] as? String ?? ""
        let objX = row["position_x"] as? Double ?? 0

        // Find in renderer by approximate position
        if let nearest = objectRenderer.nearestObject(
            to: CGFloat(objX), maxDistance: 1.0
        ) {
            let _ = objectRenderer.removeObject(id: nearest.id)
        }

        // Mark inactive in DB
        let formatter = ISO8601DateFormatter()
        let nowStr = formatter.string(from: Date())
        do {
            try db.execute(
                "UPDATE world_objects SET is_active = 0, removed_at = ? WHERE id = ?",
                arguments: [nowStr, id]
            )
        } catch {
            NSLog("[Pushling/World] Failed to mark object removed in DB: %@",
                  "\(error)")
            return false
        }

        NSLog("[Pushling/World] Removed object '%@' (db id: %d)", objName, id)
        return true
    }

    /// Lists all active world objects.
    func listObjects() -> [ObjectInfo] {
        guard let db = database else {
            return objectRenderer.activeObjects.map { obj in
                ObjectInfo(
                    id: 0, name: obj.definition.name,
                    baseShape: obj.definition.baseShape,
                    positionX: Double(obj.definition.positionX),
                    layer: obj.definition.layer,
                    size: Double(obj.definition.size),
                    interaction: obj.definition.interaction,
                    wear: obj.wear, source: obj.definition.source,
                    createdAt: ISO8601DateFormatter().string(from: obj.createdAt)
                )
            }
        }

        guard let rows = try? db.query(
            """
            SELECT id, name, base_shape, position_x, layer, size,
                   interaction, wear, source, created_at
            FROM world_objects WHERE is_active = 1
            ORDER BY position_x
            """
        ) else {
            return []
        }

        return rows.map { row in
            ObjectInfo(
                id: row["id"] as? Int ?? 0,
                name: row["name"] as? String ?? "",
                baseShape: row["base_shape"] as? String ?? "",
                positionX: row["position_x"] as? Double ?? 0,
                layer: row["layer"] as? String ?? "fore",
                size: row["size"] as? Double ?? 1.0,
                interaction: row["interaction"] as? String ?? "examining",
                wear: row["wear"] as? Double ?? 0.0,
                source: row["source"] as? String ?? "system",
                createdAt: row["created_at"] as? String ?? ""
            )
        }
    }

    // MARK: - Companion Management

    /// Adds a companion NPC to the world.
    /// - Parameters:
    ///   - typeStr: Companion type string (mouse, bird, butterfly, fish, ghost_cat).
    ///   - name: Optional name for the companion.
    /// - Returns: Companion info dictionary, or nil if invalid type.
    func addCompanion(typeStr: String,
                      name: String? = nil) -> [String: Any]? {
        guard let type = CompanionType(rawValue: typeStr) else {
            return nil
        }

        let companionName = companionSystem.spawn(
            type: type, name: name, nearX: cameraWorldX
        )

        // Persist to world table
        if let db = database {
            let formatter = ISO8601DateFormatter()
            let nowStr = formatter.string(from: Date())
            do {
                try db.execute(
                    """
                    UPDATE world SET companion_type = ?,
                        companion_name = ?, companion_spawned_at = ?
                    WHERE id = 1
                    """,
                    arguments: [typeStr, companionName, nowStr]
                )
            } catch {
                NSLog("[Pushling/World] Failed to persist companion: %@",
                      "\(error)")
            }
        }

        return [
            "type": typeStr,
            "name": companionName,
            "display_name": type.displayName
        ]
    }

    /// Removes the active companion.
    /// - Returns: True if a companion was removed.
    func removeCompanion() -> Bool {
        guard companionSystem.hasCompanion else { return false }

        companionSystem.despawn()

        // Clear from DB
        if let db = database {
            do {
                try db.execute(
                    """
                    UPDATE world SET companion_type = NULL,
                        companion_name = NULL, companion_spawned_at = NULL
                    WHERE id = 1
                    """
                )
            } catch {
                NSLog("[Pushling/World] Failed to clear companion in DB: %@",
                      "\(error)")
            }
        }

        return true
    }

    // MARK: - Renderer-Keyed Removal (for consumed objects)

    /// Removes an object by its renderer UUID (used when objects are consumed).
    /// Removes from renderer, marks inactive in DB, and cleans up wear system.
    func removeObjectByRendererID(_ rendererID: String) {
        // Remove from renderer
        guard let removed = objectRenderer.removeObject(id: rendererID) else {
            return
        }

        // Remove from wear system
        objectWearSystem.removeObject(id: rendererID)

        // Mark inactive in DB using stored dbID
        if let dbID = removed.dbID, let db = database {
            let formatter = ISO8601DateFormatter()
            let nowStr = formatter.string(from: Date())
            do {
                try db.execute(
                    "UPDATE world_objects SET is_active = 0, removed_at = ? WHERE id = ?",
                    arguments: [nowStr, dbID]
                )
            } catch {
                NSLog("[Pushling/World] Failed to mark consumed object in DB: %@",
                      "\(error)")
            }
        }

        NSLog("[Pushling/World] Consumed object '%@' (renderer: %@)",
              removed.definition.name, rendererID)
    }

    // MARK: - DB Loading

    /// Loads persisted world objects from the world_objects table.
    func loadObjectsFromDB() {
        guard let db = database else { return }

        guard let rows = try? db.query(
            """
            SELECT id, name, base_shape, position_x, layer, size,
                   color_json, effects_json, physics_json,
                   interaction, wear, wear_rate, source, created_at
            FROM world_objects WHERE is_active = 1
            """
        ) else { return }

        for row in rows {
            let dbID = row["id"] as? Int
            let name = row["name"] as? String ?? "object"
            let baseShape = row["base_shape"] as? String ?? "sphere"
            let posX = row["position_x"] as? Double ?? 542.5
            let layer = row["layer"] as? String ?? "fore"
            let size = row["size"] as? Double ?? 1.0
            let interaction = row["interaction"] as? String ?? "examining"
            let wear = row["wear"] as? Double ?? 0.0
            let wearRate = row["wear_rate"] as? Double ?? 0.01
            let source = row["source"] as? String ?? "system"

            // Parse JSON fields
            let colorJson = row["color_json"] as? String ?? "{}"
            let (primary, secondary, pattern) = parseColorJson(colorJson)
            let effectsJson = row["effects_json"] as? String ?? "[]"
            let effects = parseArrayJson(effectsJson)
            let physicsJson = row["physics_json"] as? String ?? "{}"
            let physics = parsePhysicsJson(physicsJson)

            let definition = WorldObjectDefinition(
                id: UUID().uuidString,
                name: name,
                baseShape: baseShape,
                positionX: CGFloat(posX),
                layer: layer,
                size: CGFloat(size),
                primaryColor: primary,
                secondaryColor: secondary,
                colorPattern: pattern,
                effects: effects,
                physics: physics,
                interaction: interaction,
                wearRate: wearRate,
                source: source,
                isConsumable: false
            )

            if let rendered = objectRenderer.createObject(definition) {
                objectRenderer.updateObject(id: rendered.id) { $0.dbID = dbID }
                if wear > 0 {
                    objectRenderer.applyWear(objectID: rendered.id,
                                              amount: wear)
                }
            }
        }

        if !rows.isEmpty {
            NSLog("[Pushling/World] Loaded %d objects from DB", rows.count)
        }
    }

    /// Loads persisted companion from the world table.
    func loadCompanionFromDB() {
        guard let db = database else { return }

        guard let rows = try? db.query(
            "SELECT companion_type, companion_name FROM world WHERE id = 1"
        ), let row = rows.first,
              let typeStr = row["companion_type"] as? String,
              !typeStr.isEmpty,
              let type = CompanionType(rawValue: typeStr) else {
            return
        }

        let name = row["companion_name"] as? String
        companionSystem.spawn(type: type, name: name, nearX: cameraWorldX)
        NSLog("[Pushling/World] Restored companion '%@' (%@)",
              name ?? type.displayName, typeStr)
    }

    // MARK: - JSON Helpers (private)

    func buildColorJson(primary: String, secondary: String?,
                                 pattern: String) -> String {
        var dict: [String: String] = ["primary": primary, "pattern": pattern]
        if let sec = secondary { dict["secondary"] = sec }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"primary\":\"\(primary)\",\"pattern\":\"\(pattern)\"}"
        }
        return str
    }

    func buildArrayJson(_ arr: [String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: arr),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    func buildPhysicsJson(weight: String, bounciness: Double,
                                    rollable: Bool, pushable: Bool,
                                    carryable: Bool) -> String {
        let dict: [String: Any] = [
            "weight": weight, "bounciness": bounciness,
            "rollable": rollable, "pushable": pushable,
            "carryable": carryable
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    func parseColorJson(_ json: String) -> (String, String?, String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data)
                as? [String: String] else {
            return ("bone", nil, "solid")
        }
        return (dict["primary"] ?? "bone",
                dict["secondary"],
                dict["pattern"] ?? "solid")
    }

    func parseArrayJson(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data)
                as? [String] else {
            return []
        }
        return arr
    }

    func parsePhysicsJson(_ json: String) -> ObjectPhysics {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            return ObjectPhysics(weight: "medium", bounciness: 0.3,
                                  rollable: false, pushable: false,
                                  carryable: false)
        }
        return ObjectPhysics(
            weight: dict["weight"] as? String ?? "medium",
            bounciness: dict["bounciness"] as? Double ?? 0.3,
            rollable: dict["rollable"] as? Bool ?? false,
            pushable: dict["pushable"] as? Bool ?? false,
            carryable: dict["carryable"] as? Bool ?? false
        )
    }

    // MARK: - Landmark Type Overload

    /// Adds a repo landmark with a known type (e.g., loaded from SQLite).
    func addRepoLandmark(repoName: String, landmarkType: LandmarkType) {
        let repoType: RepoType
        switch landmarkType {
        case .neonTower:    repoType = .webApp
        case .fortress:     repoType = .apiBackend
        case .obelisk:      repoType = .cliTool
        case .crystal:      repoType = .library
        case .smokeStack:   repoType = .infraDevOps
        case .observatory:  repoType = .dataML
        case .scrollTower:  repoType = .docsContent
        case .windmill:     repoType = .gameCreative
        case .monolith:     repoType = .generic
        }
        landmarkSystem?.addLandmark(repoName: repoName, repoType: repoType)
    }
}
