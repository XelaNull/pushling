// TeachReinforceHandlers.swift — pushling_teach "reinforce" action
// Extension on CommandRouter. Strengthens a taught behavior's persistence
// against decay — mirrors handleNurtureReinforce's strength model
// (NurtureHandlers.swift:510) but writes into taught_behaviors instead of
// the habit/preference/quirk/routine tables.
//
// WO-15: docs/SYSTEMS/teach-system.md:73-74 documents "reinforce" as one of
// the teach system's 7 actions ("adds +0.15 strength, capped at 1.0,
// matching the nurture strength model"). The MCP layer (mcp/src/tools/
// teach.ts:24) already sends it; before this file existed the daemon
// rejected every call at the validActions gate (UNKNOWN_ACTION) because the
// `taught_behaviors.strength` / `reinforcement_count` / `last_decayed_at`
// columns had no write path at all.
//
// Split into its own file rather than growing CreationHandlers.swift
// (already past the 500-line guideline) or NurtureHandlers.swift (a
// different table family) — keeps this WO's diff isolated to a new file
// plus one-line touches elsewhere, which is also friendlier to parallel
// merges than expanding an existing shared file.
//
// WO-15 REVISE (Mack CRITICAL): a `--workbench` in-process trigger
// (`WorkbenchTriggerMenu`) routes teach commands in-process against a
// `persistenceEnabled == false` coordinator. The first cut of this file had
// no guard on that, so a workbench reinforce would write the real shared
// `state.db` — violating the WO-7 inert contract the same class of bug P0
// fixed for `journalLog` (`CreationHandlers.swift`'s
// `guard gc.stateCoordinator.persistenceEnabled else { return }`).

import Foundation

/// Errors surfaced by the taught-behavior reinforcement DB path.
enum TeachReinforceError: Error {
    case notFound(name: String)
}

/// The minimal persistence-gate surface `performTeachReinforce` needs —
/// just the boolean gate and the database handle, not the full
/// `StateCoordinator`. Deliberately narrow: `StateCoordinator.start()`
/// touches real shared-runtime I/O (`/tmp/pushling.heartbeat` via
/// `HeartbeatManager.checkForCrash()`, `BackupManager.backupDirectory`)
/// that must never fire from a unit test, so this protocol lets the guard
/// be exercised with a lightweight test double instead of a real
/// `StateCoordinator` instance. `StateCoordinator` conforms below with a
/// zero-behavior-change `extension` — its own file is untouched.
protocol PersistenceGate {
    var persistenceEnabled: Bool { get }
    var database: DatabaseManager { get }
}

extension StateCoordinator: PersistenceGate {}

extension CommandRouter {

    /// Handles `teach reinforce` — delegates to `performTeachReinforce`
    /// (the persistence-guarded core logic) and, only on success, journals
    /// the action. Thin by design: `journalLog` needs the full
    /// `GameCoordinator` (not just its `StateCoordinator`) for its own
    /// guard/write-queue access, so it stays here rather than in the
    /// testable core below.
    func handleTeachReinforce(
        _ req: IPCRequest, gc: GameCoordinator
    ) -> IPCResult {
        let name = req.params["name"] as? String
        let result = Self.performTeachReinforce(name: name, gate: gc.stateCoordinator)

        if result.ok, let strength = result.data["strength"] as? Double, let name = name {
            journalLog(gc, type: "teach",
                       summary: "Reinforced trick: '\(name)' -> "
                           + String(format: "%.2f", strength))
        }

        return result
    }

    /// Core reinforce logic: persistence guard, `name` validation, and the
    /// DB update. Factored out of `handleTeachReinforce` and typed against
    /// `PersistenceGate` (not the full `GameCoordinator`/`StateCoordinator`)
    /// so the WO-15 REVISE persistence guard and the original strength math
    /// are both directly testable against a real (temp-file) SQLite
    /// database, without ever constructing a `GameCoordinator`/SpriteKit
    /// scene or invoking `StateCoordinator.start()`'s real heartbeat/backup
    /// I/O.
    static func performTeachReinforce(
        name: String?, gate: PersistenceGate
    ) -> IPCResult {
        guard gate.persistenceEnabled else {
            return .failure(
                error: "Reinforcement suppressed — persistence is disabled "
                    + "(workbench mode); state.db was not written.",
                code: "PERSISTENCE_DISABLED"
            )
        }

        guard let name = name, !name.isEmpty else {
            return .failure(
                error: "Missing 'name' of the taught behavior to reinforce.",
                code: "INVALID_PARAMS"
            )
        }

        do {
            let newStrength = try reinforceTaughtBehavior(name: name, db: gate.database)
            return .success([
                "reinforced": true,
                "name": name,
                "strength": newStrength,
                "type": "teach"
            ])
        } catch TeachReinforceError.notFound {
            return .failure(
                error: "No taught behavior named '\(name)'.",
                code: "NOT_FOUND"
            )
        } catch {
            return .failure(
                error: "Failed to reinforce trick: \(error.localizedDescription)",
                code: "DB_ERROR"
            )
        }
    }

    /// Pure DB logic for reinforcing a taught behavior — the +0.15
    /// (capped at 1.0) strength bump, `reinforcement_count` increment, and
    /// `last_decayed_at` refresh. Only ever reached once
    /// `performTeachReinforce` has confirmed persistence is enabled.
    ///
    /// - Throws: `TeachReinforceError.notFound` if no row matches `name`,
    ///   or a `DatabaseError` on read/write failure.
    static func reinforceTaughtBehavior(
        name: String, db: DatabaseManager
    ) throws -> Double {
        let rows = try db.query(
            "SELECT strength FROM taught_behaviors WHERE name = ?",
            arguments: [name]
        )
        guard let row = rows.first else {
            throw TeachReinforceError.notFound(name: name)
        }

        let prevStrength = (row["strength"] as? Double) ?? 0.5
        let newStrength = Swift.min(prevStrength + 0.15, 1.0)
        let now = ISO8601DateFormatter().string(from: Date())

        try db.execute(
            """
            UPDATE taught_behaviors
            SET strength = ?,
                reinforcement_count = reinforcement_count + 1,
                last_decayed_at = ?
            WHERE name = ?
            """,
            arguments: [newStrength, now, name]
        )

        return newStrength
    }
}
