// Migration.swift — Pushling schema migration system
// Version-tracked, forward-only schema upgrades.
// Each migration runs in a transaction. Rollback on failure.

import Foundation
import SQLite3

// MARK: - Migration Definition

/// A single schema migration step.
struct Migration {
    let version: Int
    let description: String
    let migrate: (DatabaseManager) throws -> Void
}

// MARK: - MigrationManager

enum MigrationManager {

    /// All registered migrations, in order. Add new migrations to the end.
    private static let migrations: [Migration] = [
        Migration(version: 1,
                  description: "Create all initial tables and seed data",
                  migrate: migrateV1),
        Migration(version: 2,
                  description: "Add repos table for landmark tracking (P3-T3-10)",
                  migrate: migrateV2),
        Migration(version: 3,
                  description: "Add touch_stats, game_scores, game_unlocks tables (P6)",
                  migrate: migrateV3)
    ]

    /// Runs all pending migrations on the given database.
    /// Called automatically by DatabaseManager.open().
    ///
    /// - Throws: `DatabaseError.migrationFailed` or `DatabaseError.databaseTooNew`.
    static func runMigrations(on db: DatabaseManager) throws {
        // Ensure schema_version table exists
        try db.executeRaw(Schema.createSchemaVersionTable)

        // Get current version
        let currentVersion = try getCurrentVersion(db: db)

        // Check if database is newer than app
        if currentVersion > Schema.currentVersion {
            throw DatabaseError.databaseTooNew(
                dbVersion: currentVersion,
                appVersion: Schema.currentVersion
            )
        }

        // Nothing to do if already current
        if currentVersion == Schema.currentVersion {
            NSLog("[Pushling/Migration] Schema is current (v%d)", currentVersion)
            return
        }

        NSLog("[Pushling/Migration] Schema at v%d, need v%d — running migrations",
              currentVersion, Schema.currentVersion)

        // Run each pending migration in its own transaction
        for migration in migrations where migration.version > currentVersion {
            NSLog("[Pushling/Migration] Applying v%d: %@",
                  migration.version, migration.description)

            do {
                try db.inTransaction {
                    try migration.migrate(db)
                    try updateVersion(db: db, to: migration.version)
                }
                NSLog("[Pushling/Migration] v%d applied successfully",
                      migration.version)
            } catch {
                NSLog("[Pushling/Migration] v%d FAILED: %@",
                      migration.version, "\(error)")
                throw DatabaseError.migrationFailed(
                    version: migration.version,
                    message: "\(error)"
                )
            }
        }

        NSLog("[Pushling/Migration] All migrations complete (now v%d)",
              Schema.currentVersion)
    }

    // MARK: - Version Tracking

    private static func getCurrentVersion(db: DatabaseManager) throws -> Int {
        let rows = try db.query(
            "SELECT version FROM schema_version WHERE id = 1;"
        )
        if let row = rows.first, let version = row["version"] as? Int {
            return version
        }
        // No row yet — version 0 (fresh database)
        return 0
    }

    private static func updateVersion(db: DatabaseManager, to version: Int) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try db.execute("""
            INSERT INTO schema_version (id, version, updated_at)
            VALUES (1, ?, ?)
            ON CONFLICT(id) DO UPDATE SET version = excluded.version,
                                          updated_at = excluded.updated_at;
            """,
            arguments: [version, now]
        )
    }

    // MARK: - Migration V1: Initial Schema

    private static func migrateV1(db: DatabaseManager) throws {
        // Create all tables
        try db.executeRaw(Schema.createCreatureTable)
        try db.executeRaw(Schema.createJournalTable)
        try db.executeRaw(Schema.createWorldTable)
        try db.executeRaw(Schema.createTaughtBehaviorsTable)
        try db.executeRaw(Schema.createHabitsTable)
        try db.executeRaw(Schema.createPreferencesTable)
        try db.executeRaw(Schema.createQuirksTable)
        try db.executeRaw(Schema.createRoutinesTable)
        try db.executeRaw(Schema.createWorldObjectsTable)
        try db.executeRaw(Schema.createCommitsTable)
        try db.executeRaw(Schema.createSurprisesTable)
        try db.executeRaw(Schema.createMilestonesTable)

        // Create indexes
        for indexSQL in Schema.createJournalIndexes {
            try db.executeRaw(indexSQL)
        }
        for indexSQL in Schema.createCommitsIndexes {
            try db.executeRaw(indexSQL)
        }
        for indexSQL in Schema.createMilestonesIndexes {
            try db.executeRaw(indexSQL)
        }

        // Seed singleton rows
        try seedCreature(db: db)
        try seedWorld(db: db)

        // Seed surprises (78 rows)
        try seedSurprises(db: db)

        // Seed milestones
        try seedMilestones(db: db)

        NSLog("[Pushling/Migration] v1: Created %d tables, %d surprises, %d milestones",
              12, Schema.surpriseSeedData.count, Schema.milestoneSeedData.count)
    }

    // MARK: - Seed Helpers

    private static func seedCreature(db: DatabaseManager) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let name = generateCreatureName()

        try db.execute("""
            INSERT OR IGNORE INTO creature (
                id, name, stage, commits_eaten, xp, xp_to_next_stage,
                activity_factor,
                energy_axis, verbosity_axis, focus_axis, discipline_axis,
                specialty,
                satisfaction, curiosity, contentment, emotional_energy,
                streak_days, touch_count, hatched, created_at
            ) VALUES (
                1, ?, 'spore', 0, 0, 100,
                1.0,
                0.5, 0.5, 0.5, 0.5,
                'polyglot',
                50.0, 50.0, 50.0, 50.0,
                0, 0, 0, ?
            );
            """,
            arguments: [name, now]
        )

        NSLog("[Pushling/Migration] Creature born: %@", name)
    }

    private static func seedWorld(db: DatabaseManager) throws {
        try db.execute("""
            INSERT OR IGNORE INTO world (
                id, weather, biome, time_period,
                creature_x, creature_facing, camera_offset
            ) VALUES (
                1, 'clear', 'plains', 'day',
                542.5, 'right', 0.0
            );
            """)
    }

    private static func seedSurprises(db: DatabaseManager) throws {
        for surprise in Schema.surpriseSeedData {
            try db.execute("""
                INSERT OR IGNORE INTO surprises (id, category, fire_count, enabled)
                VALUES (?, ?, 0, 1);
                """,
                arguments: [surprise.id, surprise.category]
            )
        }
    }

    private static func seedMilestones(db: DatabaseManager) throws {
        for milestone in Schema.milestoneSeedData {
            try db.execute("""
                INSERT OR IGNORE INTO milestones (id, category, ceremony_played)
                VALUES (?, ?, 0);
                """,
                arguments: [milestone.id, milestone.category]
            )
        }
    }

    // MARK: - Migration V2: Repos Table (P3-T3-10)

    private static func migrateV2(db: DatabaseManager) throws {
        // Create repos table for tracking repos and their landmark mappings
        try db.executeRaw(Schema.createReposTable)

        // Create indexes for efficient lookup
        for indexSQL in Schema.createReposIndexes {
            try db.executeRaw(indexSQL)
        }

        NSLog("[Pushling/Migration] v2: Created repos table with indexes")
    }

    // MARK: - Migration V3: Phase 6 Interactivity Tables

    private static func migrateV3(db: DatabaseManager) throws {
        // Touch stats table for tracking all interaction counts
        try db.executeRaw(Schema.createTouchStatsTable)

        // Seed the singleton row
        try db.execute("""
            INSERT OR IGNORE INTO touch_stats (id) VALUES (1);
            """)

        // Game scores table for high score tracking
        try db.executeRaw(Schema.createGameScoresTable)

        // Game unlocks table for progressive game access
        try db.executeRaw(Schema.createGameUnlocksTable)

        // Seed Catch as always-unlocked
        let now = ISO8601DateFormatter().string(from: Date())
        try db.execute("""
            INSERT OR IGNORE INTO game_unlocks (game_type, unlocked, total_plays, first_played)
            VALUES ('catch', 1, 0, ?);
            """,
            arguments: [now]
        )

        NSLog("[Pushling/Migration] v3: Created touch_stats, game_scores, game_unlocks tables")
    }

    // MARK: - Creature Name Generator

    /// Generates a two-syllable creature name.
    /// Pattern: consonant-vowel-consonant-vowel-consonant (CVCVC)
    /// Produces names like "Zepus", "Toval", "Noxim", "Rukit", "Belaf"
    private static func generateCreatureName() -> String {
        let onsets = ["B", "C", "D", "F", "G", "K", "L", "M", "N", "P",
                      "R", "S", "T", "V", "X", "Z", "Br", "Cr", "Dr",
                      "Fr", "Gr", "Pr", "Tr", "Qu"]
        let vowels = ["a", "e", "i", "o", "u"]
        let codas  = ["b", "d", "f", "g", "k", "l", "m", "n", "p",
                      "r", "s", "t", "v", "x", "z"]

        let onset1 = onsets.randomElement()!
        let vowel1 = vowels.randomElement()!
        let coda   = codas.randomElement()!
        let vowel2 = vowels.randomElement()!
        let final_ = codas.randomElement()!

        // Capitalize first letter, lowercase rest
        let raw = onset1 + vowel1 + coda + vowel2 + final_
        return raw.prefix(1).uppercased() + raw.dropFirst().lowercased()
    }
}
