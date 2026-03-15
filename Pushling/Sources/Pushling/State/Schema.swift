// Schema.swift — Pushling SQLite schema definitions
// All table DDL for the Pushling state database.
// Tables: creature, journal, world, taught_behaviors, habits, preferences,
//         quirks, routines, world_objects, commits, surprises, milestones

import Foundation

// MARK: - Schema Constants

enum Schema {

    /// Current schema version. Bump this when adding migrations.
    static let currentVersion = 4

    // MARK: - Valid Enum Values

    static let validStages = ["spore", "drop", "critter", "beast", "sage", "apex"]

    static let validSpecialties = [
        "polyglot", "frontend", "backend", "systems", "data", "mobile",
        "devops", "scripting", "functional", "creative", "research"
    ]

    static let validWeather = ["clear", "cloudy", "rain", "storm", "snow", "fog"]

    static let validTimePeriods = [
        "deep_night", "dawn", "morning", "day", "golden_hour",
        "dusk", "evening", "late_night"
    ]

    static let validBiomes = [
        "plains", "forest", "mountain", "desert", "tundra", "swamp",
        "ocean", "cave", "city", "garden"
    ]

    static let validJournalTypes = [
        "commit", "touch", "ai_speech", "failed_speech", "ai_move",
        "ai_express", "ai_perform", "surprise", "evolve", "first_word",
        "dream", "discovery", "mutation", "hook", "session", "teach",
        "nurture", "world_change"
    ]

    static let validBehaviorCategories = [
        "playful", "affectionate", "dramatic", "calm", "silly", "functional"
    ]

    static let validFrequencies = ["always", "often", "sometimes", "rarely"]
    static let validVariations = ["strict", "moderate", "loose", "wild"]

    static let validLayers = ["far", "mid", "fore"]

    static let validInteractions = [
        "examining", "sitting_on", "hiding_behind", "pushing", "climbing",
        "sleeping_near", "eating", "playing_with", "collecting", "wearing",
        "building_with", "guarding", "sharing", "worshipping"
    ]

    static let validObjectSources = ["system", "ai_placed", "repo_landmark"]

    static let validSurpriseCategories = [
        "visual", "contextual", "cat", "milestone", "time",
        "easter_egg", "hook_aware", "collaborative"
    ]

    static let validMilestoneCategories = [
        "evolution", "mutation", "touch", "commit", "surprise", "speech"
    ]

    static let validRoutineSlots = [
        "morning", "post_meal", "bedtime", "greeting", "farewell",
        "return", "milestone", "weather_change", "boredom", "post_feast"
    ]

    // MARK: - Table DDL

    static let createSchemaVersionTable = """
        CREATE TABLE IF NOT EXISTS schema_version (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            version INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
        );
        """

    static let createCreatureTable = """
        CREATE TABLE IF NOT EXISTS creature (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            stage TEXT NOT NULL DEFAULT 'spore'
                CHECK (stage IN ('spore','drop','critter','beast','sage','apex')),
            commits_eaten INTEGER NOT NULL DEFAULT 0,
            xp INTEGER NOT NULL DEFAULT 0,
            xp_to_next_stage INTEGER NOT NULL DEFAULT 100,
            activity_factor REAL NOT NULL DEFAULT 1.0
                CHECK (activity_factor >= 0.5 AND activity_factor <= 3.0),
            energy_axis REAL NOT NULL DEFAULT 0.5
                CHECK (energy_axis >= 0.0 AND energy_axis <= 1.0),
            verbosity_axis REAL NOT NULL DEFAULT 0.5
                CHECK (verbosity_axis >= 0.0 AND verbosity_axis <= 1.0),
            focus_axis REAL NOT NULL DEFAULT 0.5
                CHECK (focus_axis >= 0.0 AND focus_axis <= 1.0),
            discipline_axis REAL NOT NULL DEFAULT 0.5
                CHECK (discipline_axis >= 0.0 AND discipline_axis <= 1.0),
            specialty TEXT NOT NULL DEFAULT 'polyglot'
                CHECK (specialty IN (
                    'polyglot','frontend','backend','systems','data','mobile',
                    'devops','scripting','functional','creative','research'
                )),
            satisfaction REAL NOT NULL DEFAULT 50.0
                CHECK (satisfaction >= 0.0 AND satisfaction <= 100.0),
            curiosity REAL NOT NULL DEFAULT 50.0
                CHECK (curiosity >= 0.0 AND curiosity <= 100.0),
            contentment REAL NOT NULL DEFAULT 50.0
                CHECK (contentment >= 0.0 AND contentment <= 100.0),
            emotional_energy REAL NOT NULL DEFAULT 50.0
                CHECK (emotional_energy >= 0.0 AND emotional_energy <= 100.0),
            streak_days INTEGER NOT NULL DEFAULT 0,
            streak_last_date TEXT,
            favorite_language TEXT,
            disliked_language TEXT,
            touch_count INTEGER NOT NULL DEFAULT 0,
            title TEXT,
            motto TEXT,
            base_color_hue REAL,
            body_proportion REAL,
            fur_pattern TEXT,
            tail_shape TEXT,
            eye_shape TEXT,
            created_at TEXT NOT NULL,
            last_fed_at TEXT,
            last_touched_at TEXT,
            last_session_at TEXT,
            hatched INTEGER NOT NULL DEFAULT 0
        );
        """

    static let createJournalTable = """
        CREATE TABLE IF NOT EXISTS journal (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL
                CHECK (type IN (
                    'commit','touch','ai_speech','failed_speech','ai_move',
                    'ai_express','ai_perform','surprise','evolve','first_word',
                    'dream','discovery','mutation','hook','session','teach',
                    'nurture','world_change'
                )),
            summary TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            data TEXT
        );
        """

    static let createJournalIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_journal_type ON journal(type);",
        "CREATE INDEX IF NOT EXISTS idx_journal_timestamp ON journal(timestamp);",
        "CREATE INDEX IF NOT EXISTS idx_journal_type_timestamp ON journal(type, timestamp);"
    ]

    static let createWorldTable = """
        CREATE TABLE IF NOT EXISTS world (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            weather TEXT NOT NULL DEFAULT 'clear'
                CHECK (weather IN ('clear','cloudy','rain','storm','snow','fog')),
            weather_changed_at TEXT,
            biome TEXT NOT NULL DEFAULT 'plains',
            time_period TEXT NOT NULL DEFAULT 'day'
                CHECK (time_period IN (
                    'deep_night','dawn','morning','day','golden_hour',
                    'dusk','evening','late_night'
                )),
            time_override TEXT,
            time_override_until TEXT,
            creature_x REAL NOT NULL DEFAULT 542.5,
            creature_facing TEXT NOT NULL DEFAULT 'right'
                CHECK (creature_facing IN ('left','right')),
            camera_offset REAL NOT NULL DEFAULT 0.0,
            companion_type TEXT,
            companion_name TEXT,
            companion_spawned_at TEXT
        );
        """

    static let createTaughtBehaviorsTable = """
        CREATE TABLE IF NOT EXISTS taught_behaviors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL
                CHECK (category IN (
                    'playful','affectionate','dramatic','calm','silly','functional'
                )),
            stage_min TEXT NOT NULL DEFAULT 'spore'
                CHECK (stage_min IN ('spore','drop','critter','beast','sage','apex')),
            duration_s REAL NOT NULL,
            tracks_json TEXT NOT NULL,
            triggers_json TEXT NOT NULL,
            mastery_level INTEGER NOT NULL DEFAULT 0
                CHECK (mastery_level >= 0 AND mastery_level <= 3),
            performance_count INTEGER NOT NULL DEFAULT 0,
            strength REAL NOT NULL DEFAULT 0.5
                CHECK (strength >= 0.0 AND strength <= 1.0),
            reinforcement_count INTEGER NOT NULL DEFAULT 0,
            source TEXT NOT NULL DEFAULT 'taught'
                CHECK (source IN ('taught','self_taught')),
            parent_a TEXT,
            parent_b TEXT,
            created_at TEXT NOT NULL,
            last_performed_at TEXT,
            last_decayed_at TEXT
        );
        """

    static let createHabitsTable = """
        CREATE TABLE IF NOT EXISTS habits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            trigger_json TEXT NOT NULL,
            action_json TEXT NOT NULL,
            frequency TEXT NOT NULL DEFAULT 'sometimes'
                CHECK (frequency IN ('always','often','sometimes','rarely')),
            variation TEXT NOT NULL DEFAULT 'moderate'
                CHECK (variation IN ('strict','moderate','loose','wild')),
            strength REAL NOT NULL DEFAULT 0.5
                CHECK (strength >= 0.0 AND strength <= 1.0),
            reinforcement_count INTEGER NOT NULL DEFAULT 0,
            cooldown_s REAL NOT NULL DEFAULT 60.0,
            last_triggered_at TEXT,
            created_at TEXT NOT NULL
        );
        """

    static let createPreferencesTable = """
        CREATE TABLE IF NOT EXISTS preferences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject TEXT NOT NULL,
            valence REAL NOT NULL
                CHECK (valence >= -1.0 AND valence <= 1.0),
            strength REAL NOT NULL DEFAULT 0.5
                CHECK (strength >= 0.0 AND strength <= 1.0),
            reinforcement_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        );
        """

    static let createQuirksTable = """
        CREATE TABLE IF NOT EXISTS quirks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            behavior_target TEXT NOT NULL,
            modifier_json TEXT NOT NULL,
            probability REAL NOT NULL DEFAULT 0.5
                CHECK (probability >= 0.0 AND probability <= 1.0),
            strength REAL NOT NULL DEFAULT 0.5
                CHECK (strength >= 0.0 AND strength <= 1.0),
            reinforcement_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        );
        """

    static let createRoutinesTable = """
        CREATE TABLE IF NOT EXISTS routines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            slot TEXT NOT NULL UNIQUE
                CHECK (slot IN (
                    'morning','post_meal','bedtime','greeting','farewell',
                    'return','milestone','weather_change','boredom','post_feast'
                )),
            steps_json TEXT NOT NULL,
            strength REAL NOT NULL DEFAULT 0.5
                CHECK (strength >= 0.0 AND strength <= 1.0),
            reinforcement_count INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
        );
        """

    static let createWorldObjectsTable = """
        CREATE TABLE IF NOT EXISTS world_objects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            base_shape TEXT NOT NULL,
            position_x REAL NOT NULL,
            layer TEXT NOT NULL DEFAULT 'fore'
                CHECK (layer IN ('far','mid','fore')),
            size REAL NOT NULL DEFAULT 1.0,
            color_json TEXT,
            effects_json TEXT,
            physics_json TEXT,
            interaction TEXT NOT NULL DEFAULT 'examining'
                CHECK (interaction IN (
                    'examining','sitting_on','hiding_behind','pushing','climbing',
                    'sleeping_near','eating','playing_with','collecting','wearing',
                    'building_with','guarding','sharing','worshipping'
                )),
            wear REAL NOT NULL DEFAULT 0.0
                CHECK (wear >= 0.0 AND wear <= 1.0),
            source TEXT NOT NULL DEFAULT 'system'
                CHECK (source IN ('system','ai_placed','repo_landmark')),
            repo_name TEXT,       -- DEPRECATED: unused. Landmarks use repos table + LandmarkSystem in-memory array.
            landmark_type TEXT,   -- DEPRECATED: unused. Landmarks use repos table + LandmarkSystem in-memory array.
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            removed_at TEXT
        );
        """

    static let createCommitsTable = """
        CREATE TABLE IF NOT EXISTS commits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sha TEXT NOT NULL UNIQUE,
            message TEXT NOT NULL,
            repo_name TEXT NOT NULL,
            files_changed INTEGER NOT NULL DEFAULT 0,
            lines_added INTEGER NOT NULL DEFAULT 0,
            lines_removed INTEGER NOT NULL DEFAULT 0,
            languages TEXT,
            is_merge INTEGER NOT NULL DEFAULT 0,
            is_revert INTEGER NOT NULL DEFAULT 0,
            is_force_push INTEGER NOT NULL DEFAULT 0,
            branch TEXT,
            xp_awarded INTEGER NOT NULL DEFAULT 0,
            commit_type TEXT,
            eaten_at TEXT NOT NULL
        );
        """

    static let createCommitsIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_commits_sha ON commits(sha);",
        "CREATE INDEX IF NOT EXISTS idx_commits_eaten_at ON commits(eaten_at);",
        "CREATE INDEX IF NOT EXISTS idx_commits_repo_name ON commits(repo_name);",
        "CREATE INDEX IF NOT EXISTS idx_commits_languages ON commits(languages);"
    ]

    static let createSurprisesTable = """
        CREATE TABLE IF NOT EXISTS surprises (
            id INTEGER PRIMARY KEY,
            category TEXT NOT NULL
                CHECK (category IN (
                    'visual','contextual','cat','milestone','time',
                    'easter_egg','hook_aware','collaborative'
                )),
            last_fired_at TEXT,
            fire_count INTEGER NOT NULL DEFAULT 0,
            cooldown_until TEXT,
            enabled INTEGER NOT NULL DEFAULT 1
        );
        """

    static let createMilestonesTable = """
        CREATE TABLE IF NOT EXISTS milestones (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL
                CHECK (category IN (
                    'evolution','mutation','touch','commit','surprise','speech'
                )),
            earned_at TEXT,
            data_json TEXT,
            ceremony_played INTEGER NOT NULL DEFAULT 0
        );
        """

    static let createMilestonesIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_milestones_category ON milestones(category);",
        "CREATE INDEX IF NOT EXISTS idx_milestones_earned_at ON milestones(earned_at);"
    ]

    // MARK: - Repos Table (P3-T3-10)

    static let validLandmarkTypes = [
        "neon_tower", "fortress", "obelisk", "crystal", "smoke_stack",
        "observatory", "scroll_tower", "windmill", "monolith"
    ]

    static let createReposTable = """
        CREATE TABLE IF NOT EXISTS repos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            landmark_type TEXT NOT NULL
                CHECK (landmark_type IN (
                    'neon_tower','fortress','obelisk','crystal','smoke_stack',
                    'observatory','scroll_tower','windmill','monolith'
                )),
            dominant_language TEXT,
            world_x_position REAL NOT NULL,
            commit_count INTEGER NOT NULL DEFAULT 0,
            analyzed_at TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        """

    static let createReposIndexes = [
        "CREATE INDEX IF NOT EXISTS idx_repos_name ON repos(name);",
        "CREATE INDEX IF NOT EXISTS idx_repos_path ON repos(path);"
    ]

    // MARK: - Phase 6: Touch Stats Table (P6-T1-12)

    static let createTouchStatsTable = """
        CREATE TABLE IF NOT EXISTS touch_stats (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            total_touches INTEGER NOT NULL DEFAULT 0,
            taps INTEGER NOT NULL DEFAULT 0,
            double_taps INTEGER NOT NULL DEFAULT 0,
            triple_taps INTEGER NOT NULL DEFAULT 0,
            long_presses INTEGER NOT NULL DEFAULT 0,
            sustained_touches INTEGER NOT NULL DEFAULT 0,
            drags INTEGER NOT NULL DEFAULT 0,
            petting_strokes INTEGER NOT NULL DEFAULT 0,
            flicks INTEGER NOT NULL DEFAULT 0,
            rapid_taps INTEGER NOT NULL DEFAULT 0,
            boops INTEGER NOT NULL DEFAULT 0,
            belly_rubs INTEGER NOT NULL DEFAULT 0,
            hand_feeds INTEGER NOT NULL DEFAULT 0,
            laser_pointer_seconds REAL NOT NULL DEFAULT 0.0,
            daily_interaction_streak INTEGER NOT NULL DEFAULT 0,
            last_interaction_date TEXT
        );
        """

    // MARK: - Phase 6: Game Scores Table (P6-T3-04)

    static let createGameScoresTable = """
        CREATE TABLE IF NOT EXISTS game_scores (
            game_type TEXT PRIMARY KEY,
            high_score INTEGER NOT NULL DEFAULT 0,
            total_plays INTEGER NOT NULL DEFAULT 0,
            last_played TEXT
        );
        """

    // MARK: - Phase 6: Game Unlocks Table (P6-T3-11)

    static let createGameUnlocksTable = """
        CREATE TABLE IF NOT EXISTS game_unlocks (
            game_type TEXT PRIMARY KEY,
            unlocked INTEGER NOT NULL DEFAULT 0,
            total_plays INTEGER NOT NULL DEFAULT 0,
            first_played TEXT
        );
        """
}

// MARK: - Seed Data

extension Schema {

    /// 78 surprises organized by category, seeded on first migration.
    /// IDs 1-10: visual, 11-20: contextual, 21-30: cat, 31-40: milestone,
    /// 41-50: time, 51-60: easter_egg, 61-70: hook_aware, 71-78: collaborative
    static let surpriseSeedData: [(id: Int, category: String)] = {
        var data: [(Int, String)] = []
        let categoryRanges: [(String, ClosedRange<Int>)] = [
            ("visual",        1...10),
            ("contextual",   11...20),
            ("cat",          21...30),
            ("milestone",    31...40),
            ("time",         41...50),
            ("easter_egg",   51...60),
            ("hook_aware",   61...70),
            ("collaborative", 71...78)
        ]
        for (category, range) in categoryRanges {
            for id in range {
                data.append((id, category))
            }
        }
        return data
    }()

    /// Pre-populated milestones: mutation badges, touch milestones,
    /// commit milestones, and stage transitions.
    static let milestoneSeedData: [(id: String, category: String)] = [
        // 10 mutation badges
        ("nocturne",          "mutation"),
        ("polyglot",          "mutation"),
        ("marathon",          "mutation"),
        ("surgeon",           "mutation"),
        ("architect",         "mutation"),
        ("gardener",          "mutation"),
        ("phoenix",           "mutation"),
        ("librarian",         "mutation"),
        ("speedrunner",       "mutation"),
        ("hermit",            "mutation"),

        // 9 human touch milestones
        ("first_touch",       "touch"),
        ("finger_trail",      "touch"),
        ("petting",           "touch"),
        ("laser_pointer",     "touch"),
        ("first_mini_game",   "touch"),
        ("belly_rub",         "touch"),
        ("pre_contact_purr",  "touch"),
        ("touch_mastery",     "touch"),
        ("gentle_wake",       "touch"),

        // Commit count milestones
        ("commit_1",          "commit"),
        ("commit_10",         "commit"),
        ("commit_42",         "commit"),
        ("commit_100",        "commit"),
        ("commit_404",        "commit"),
        ("commit_500",        "commit"),
        ("commit_1000",       "commit"),

        // Stage transitions (evolution)
        ("evolve_drop",       "evolution"),
        ("evolve_critter",    "evolution"),
        ("evolve_beast",      "evolution"),
        ("evolve_sage",       "evolution"),
        ("evolve_apex",       "evolution"),

        // Speech milestones
        ("first_word",        "speech"),
        ("first_sentence",    "speech"),
        ("first_dream",       "speech"),

        // Surprise milestones
        ("first_surprise",    "surprise"),
        ("surprise_10",       "surprise"),
        ("surprise_50",       "surprise")
    ]
}
