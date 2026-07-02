---
type: Data Model
title: Pushling State Database Schema
description: The complete SQLite schema at ~/.local/share/pushling/state.db — all 16 domain tables plus the schema_version tracking table, current as of migration v8.
status: Live
tags: [sqlite, schema, data-model, state]
timestamp: 2026-07-02T00:00:00Z
---

The daemon (`Pushling/Sources/Pushling/State/Schema.swift` +
`Migration.swift`) is the **sole writer** and sole schema owner. This
concept documents the schema as it actually exists after all 8 registered
migrations run — not any single migration's DDL in isolation. Column lists
below fold in every `ALTER TABLE` from `Migration.swift` so each table's
`# Schema` section is the *current* shape, not the v1 snapshot.

The connection layer (WAL mode, pragmas, single-writer discipline, the
`DatabaseManager` singleton) and the migration mechanism itself are
[their own authority](/OPERATIONS/persistence-and-recovery.md) — this
concept is the tables only.

**Naming note:** the growth-stage vocabulary (`stage` column, `egg` as the
first stage rather than the design doc's historical `Spore`) is authoritative
here as the literal CHECK constraint, but the *meaning* of each stage
(thresholds, unlocks, ceremony) belongs to the growth-stages concept
(SP3a) — this document only says what SQLite will accept.

# Connection Facts

- **Path:** `~/.local/share/pushling/state.db` (`DatabaseManager.defaultDatabasePath()`)
- **Mode:** WAL (`PRAGMA journal_mode=WAL`), `synchronous=NORMAL`,
  `foreign_keys=ON`, `busy_timeout=5000`
- **Current schema version:** 8 (`Schema.currentVersion`)
- **Writer discipline:** the daemon is the only writer, serialized through a
  single `DispatchQueue` (`DatabaseManager.writeQueue`); the MCP server opens
  a second, independent connection in `readonly` mode plus `PRAGMA
  query_only=ON`

# schema_version

Migration-tracking table, not a domain table — not counted among the 16
below. Single row (`id = 1`), upserted by `MigrationManager.updateVersion()`
after every successfully-applied migration.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY, `CHECK (id = 1)` |
| `version` | INTEGER | NOT NULL, DEFAULT 0 |
| `updated_at` | TEXT | NOT NULL |

# creature

The single creature row (`id = 1`). Largest table — accumulates columns
across 4 of the 8 migrations (v1 base + v5 rarity + v6 skill stats + v7
dream tracking).

### Schema
| Column | Type | Constraints / Default | Added |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY, `CHECK (id = 1)` | v1 |
| `name` | TEXT | NOT NULL | v1 |
| `stage` | TEXT | NOT NULL, DEFAULT `'egg'`, `CHECK IN ('egg','drop','critter','beast','sage','apex')` | v1 |
| `commits_eaten` | INTEGER | NOT NULL, DEFAULT 0 | v1 |
| `xp` | INTEGER | NOT NULL, DEFAULT 0 | v1 |
| `xp_to_next_stage` | INTEGER | NOT NULL, DEFAULT 100 | v1 |
| `activity_factor` | REAL | NOT NULL, DEFAULT 1.0, `CHECK 0.5–3.0` | v1 |
| `energy_axis` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` | v1 |
| `verbosity_axis` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` | v1 |
| `focus_axis` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` | v1 |
| `discipline_axis` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` | v1 |
| `specialty` | TEXT | NOT NULL, DEFAULT `'polyglot'`, `CHECK IN` 11 values (polyglot, frontend, backend, systems, data, mobile, devops, scripting, functional, creative, research) | v1 |
| `satisfaction` | REAL | NOT NULL, DEFAULT 50.0, `CHECK 0.0–100.0` | v1 |
| `curiosity` | REAL | NOT NULL, DEFAULT 50.0, `CHECK 0.0–100.0` | v1 |
| `contentment` | REAL | NOT NULL, DEFAULT 50.0, `CHECK 0.0–100.0` | v1 |
| `emotional_energy` | REAL | NOT NULL, DEFAULT 50.0, `CHECK 0.0–100.0` | v1 |
| `streak_days` | INTEGER | NOT NULL, DEFAULT 0 | v1 |
| `streak_last_date` | TEXT | nullable | v1 |
| `favorite_language` | TEXT | nullable | v1 |
| `disliked_language` | TEXT | nullable | v1 |
| `touch_count` | INTEGER | NOT NULL, DEFAULT 0 | v1 |
| `title` | TEXT | nullable | v1 |
| `motto` | TEXT | nullable | v1 |
| `base_color_hue` | REAL | nullable | v1 |
| `body_proportion` | REAL | nullable | v1 |
| `fur_pattern` | TEXT | nullable | v1 |
| `tail_shape` | TEXT | nullable | v1 |
| `eye_shape` | TEXT | nullable | v1 |
| `created_at` | TEXT | NOT NULL | v1 |
| `last_fed_at` | TEXT | nullable | v1 |
| `last_touched_at` | TEXT | nullable | v1 |
| `last_session_at` | TEXT | nullable | v1 |
| `hatched` | INTEGER | NOT NULL, DEFAULT 0 | v1 |
| `rarity` | TEXT | NOT NULL, DEFAULT `'common'`, `CHECK IN` (common, uncommon, rare, epic, legendary) | v5 |
| `shiny` | INTEGER | NOT NULL, DEFAULT 0, `CHECK IN (0,1)` | v5 |
| `stat_debugging` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `stat_patience` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `stat_chaos` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `stat_wisdom` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `stat_snark` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `stat_speed` | INTEGER | NOT NULL, DEFAULT 10 | v6 |
| `last_dream_at` | TEXT | nullable | v7 |
| `dream_count` | INTEGER | NOT NULL, DEFAULT 0 | v7 |

Seeded on first migration (`MigrationManager.seedCreature()`) with a
procedurally-generated CVCVC name (e.g. "Zepus", "Toval"), `stage = 'egg'`,
`xp = 0`, all axes/emotions at their midpoint defaults.

**Historical note:** `PHASE-1.md` (`P1-T2-02`) specified `xp_to_next_stage`
without a default, expecting it computed per-row; the shipped column carries
`DEFAULT 100` directly. Both the growth-stages concept (SP3a, which owns
threshold semantics) and this schema treat the shipped default as canon —
the design doc's version is superseded.

# journal

Append-only event log. No `id=1` singleton — grows indefinitely (no
retention/pruning policy exists in code).

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `type` | TEXT | NOT NULL, `CHECK IN` 18 values: `commit`, `touch`, `ai_speech`, `failed_speech`, `ai_move`, `ai_express`, `ai_perform`, `surprise`, `evolve`, `first_word`, `dream`, `discovery`, `mutation`, `hook`, `session`, `teach`, `nurture`, `world_change` |
| `summary` | TEXT | NOT NULL |
| `timestamp` | TEXT | NOT NULL |
| `data` | TEXT | nullable (JSON blob, entry-type-specific shape) |

**Indexes:** `idx_journal_type`, `idx_journal_timestamp`,
`idx_journal_type_timestamp` (composite).

# world

Single row (`id = 1`) — weather, biome, time-of-day, and the creature's
world position.

### Schema
| Column | Type | Constraints / Default | Added |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY, `CHECK (id = 1)` | v1 |
| `weather` | TEXT | NOT NULL, DEFAULT `'clear'`, `CHECK IN` (clear, cloudy, rain, storm, snow, fog) | v1 |
| `weather_changed_at` | TEXT | nullable | v1 |
| `biome` | TEXT | NOT NULL, DEFAULT `'plains'` (no CHECK — `validBiomes` in `Schema.swift` lists 10 values but the column itself is unconstrained) | v1 |
| `time_period` | TEXT | NOT NULL, DEFAULT `'day'`, `CHECK IN` 8 values (deep_night, dawn, morning, day, golden_hour, dusk, evening, late_night) | v1 |
| `time_override` | TEXT | nullable | v1 |
| `time_override_until` | TEXT | nullable | v1 |
| `creature_x` | REAL | NOT NULL, DEFAULT 542.5 (scene-width midpoint) | v1 |
| `creature_facing` | TEXT | NOT NULL, DEFAULT `'right'`, `CHECK IN ('left','right')` | v1 |
| `camera_offset` | REAL | NOT NULL, DEFAULT 0.0 | v1 |
| `companion_type` | TEXT | nullable | v1 |
| `companion_name` | TEXT | nullable | v1 |
| `companion_spawned_at` | TEXT | nullable | v1 |
| `explored_ranges` | TEXT | nullable (fog-of-war persistence — JSON range list) | v8 |

# taught_behaviors

Claude-taught choreography, via `pushling_teach`. Cap of 30 total is
enforced client-side (`mcp/src/tools/teach.ts MAX_TAUGHT`), not by a DB
constraint.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `name` | TEXT | NOT NULL, UNIQUE |
| `category` | TEXT | NOT NULL, `CHECK IN` (playful, affectionate, dramatic, calm, silly, functional) |
| `stage_min` | TEXT | NOT NULL, DEFAULT `'egg'`, `CHECK IN` the 6 stages |
| `duration_s` | REAL | NOT NULL |
| `tracks_json` | TEXT | NOT NULL (per-track keyframe arrays, serialized) |
| `triggers_json` | TEXT | NOT NULL |
| `mastery_level` | INTEGER | NOT NULL, DEFAULT 0, `CHECK 0–3` |
| `performance_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `strength` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `reinforcement_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `source` | TEXT | NOT NULL, DEFAULT `'taught'`, `CHECK IN ('taught','self_taught')` |
| `parent_a` | TEXT | nullable (behavior-breeding lineage) |
| `parent_b` | TEXT | nullable |
| `created_at` | TEXT | NOT NULL |
| `last_performed_at` | TEXT | nullable |
| `last_decayed_at` | TEXT | nullable |

# habits, preferences, quirks, routines

The four `pushling_nurture` tables — one row per set item. All share the
`strength REAL DEFAULT 0.5, CHECK 0.0–1.0` and `reinforcement_count INTEGER
DEFAULT 0` pattern; `identity` (a fifth nurture type mentioned in the tool
contract) has no table of its own — it's stored directly on `creature`
(`title`, `motto`, etc.), not as a separate nurture row.

### Schema — habits
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `name` | TEXT | NOT NULL |
| `trigger_json` | TEXT | NOT NULL |
| `action_json` | TEXT | NOT NULL |
| `frequency` | TEXT | NOT NULL, DEFAULT `'sometimes'`, `CHECK IN` (always, often, sometimes, rarely) |
| `variation` | TEXT | NOT NULL, DEFAULT `'moderate'`, `CHECK IN` (strict, moderate, loose, wild) |
| `strength` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `reinforcement_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `cooldown_s` | REAL | NOT NULL, DEFAULT 60.0 |
| `last_triggered_at` | TEXT | nullable |
| `created_at` | TEXT | NOT NULL |

### Schema — preferences
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `subject` | TEXT | NOT NULL |
| `valence` | REAL | NOT NULL, `CHECK -1.0–1.0` |
| `strength` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `reinforcement_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `created_at` | TEXT | NOT NULL |

### Schema — quirks
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `name` | TEXT | NOT NULL |
| `behavior_target` | TEXT | NOT NULL |
| `modifier_json` | TEXT | NOT NULL |
| `probability` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `strength` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `reinforcement_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `created_at` | TEXT | NOT NULL |

### Schema — routines
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `slot` | TEXT | NOT NULL, UNIQUE, `CHECK IN` 10 values (morning, post_meal, bedtime, greeting, farewell, return, milestone, weather_change, boredom, post_feast) |
| `steps_json` | TEXT | NOT NULL |
| `strength` | REAL | NOT NULL, DEFAULT 0.5, `CHECK 0.0–1.0` |
| `reinforcement_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `created_at` | TEXT | NOT NULL |

`routines.slot` is `UNIQUE` — only one routine per named slot can exist at a
time, unlike habits/preferences/quirks which allow unlimited rows (their
caps of 20/12/12 are enforced client-side, not by SQL).

# world_objects

Placed objects — system-spawned, AI-placed (`pushling_world("create")`), or
repo landmarks.

### Schema
| Column | Type | Constraints / Default | Added |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | v1 |
| `name` | TEXT | nullable | v1 |
| `base_shape` | TEXT | NOT NULL | v1 |
| `position_x` | REAL | NOT NULL | v1 |
| `layer` | TEXT | NOT NULL, DEFAULT `'fore'`, `CHECK IN ('far','mid','fore')` | v1 |
| `size` | REAL | NOT NULL, DEFAULT 1.0 | v1 |
| `color_json` | TEXT | nullable | v1 |
| `effects_json` | TEXT | nullable | v1 |
| `physics_json` | TEXT | nullable | v1 |
| `interaction` | TEXT | NOT NULL, DEFAULT `'examining'`, `CHECK IN` 14 values | v1 |
| `wear` | REAL | NOT NULL, DEFAULT 0.0, `CHECK 0.0–1.0` | v1 |
| `source` | TEXT | NOT NULL, DEFAULT `'system'`, `CHECK IN ('system','ai_placed','repo_landmark')` | v1 |
| `repo_name` | TEXT | nullable — **DEPRECATED, unused**; landmarks now use the `repos` table + an in-memory `LandmarkSystem` array | v1 |
| `landmark_type` | TEXT | nullable — **DEPRECATED, unused**, same reason | v1 |
| `is_active` | INTEGER | NOT NULL, DEFAULT 1 | v1 |
| `created_at` | TEXT | NOT NULL | v1 |
| `removed_at` | TEXT | nullable | v1 |
| `wear_rate` | REAL | NOT NULL, DEFAULT 0.01 (per-object wear-accumulation speed) | v4 |

The `repo_name`/`landmark_type` columns are explicitly marked `-- DEPRECATED:
unused` in `Schema.swift` itself — this is code-documented dead schema, not
a doc/code drift; retained for backward compatibility with any pre-`repos`-table
row data rather than dropped (SQLite has no cheap `DROP COLUMN` pre-3.35, and
even on newer SQLite the migration to drop it was never written).

# commits

One row per eaten commit (the creature's meal log).

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `sha` | TEXT | NOT NULL, UNIQUE |
| `message` | TEXT | NOT NULL |
| `repo_name` | TEXT | NOT NULL |
| `files_changed` | INTEGER | NOT NULL, DEFAULT 0 |
| `lines_added` | INTEGER | NOT NULL, DEFAULT 0 |
| `lines_removed` | INTEGER | NOT NULL, DEFAULT 0 |
| `languages` | TEXT | nullable (comma-joined language list) |
| `is_merge` | INTEGER | NOT NULL, DEFAULT 0 |
| `is_revert` | INTEGER | NOT NULL, DEFAULT 0 |
| `is_force_push` | INTEGER | NOT NULL, DEFAULT 0 |
| `branch` | TEXT | nullable |
| `xp_awarded` | INTEGER | NOT NULL, DEFAULT 0 |
| `commit_type` | TEXT | nullable |
| `eaten_at` | TEXT | NOT NULL |

**Indexes:** `idx_commits_sha`, `idx_commits_eaten_at`,
`idx_commits_repo_name`, `idx_commits_languages`.

**Client/schema mismatch:** `mcp/src/state.ts`'s `StateReader` queries
reference `language` (singular) and `has_tests` columns
(`uniqueExtensionsIn7Days`, `testCommitCount` in `StateCoordinator.swift`'s
`MutationQueryProvider` conformance) that do not exist on this table — the
actual columns are `languages` (plural, comma-joined) with no `has_tests`
column at all. Those queries silently return 0/empty via the `try?` +
`?? 0`/`?? []` fallback pattern rather than throwing. Flagged for
`DECISIONS.md`/the Orchestrator — this is a real, previously-undocumented
drift, not something to paper over in this schema doc.

# surprises

One seeded row per catalogued surprise (78 total, IDs 1–78, seeded once at
migration v1).

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY (explicit ID, not autoincrement — matches the seed catalog) |
| `category` | TEXT | NOT NULL, `CHECK IN` 8 values (visual, contextual, cat, milestone, time, easter_egg, hook_aware, collaborative) |
| `last_fired_at` | TEXT | nullable |
| `fire_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `cooldown_until` | TEXT | nullable |
| `enabled` | INTEGER | NOT NULL, DEFAULT 1 |

Seed ranges (`Schema.surpriseSeedData`): 1–10 visual, 11–20 contextual,
21–30 cat, 31–40 milestone, 41–50 time, 51–60 easter_egg, 61–70 hook_aware,
71–78 collaborative. The catalog's per-surprise content (name, trigger
condition, cooldown length) lives in the Surprise System's own registry in
Swift, not in this table — this table is purely fire-tracking state per ID.

# milestones

One seeded row per catalogued milestone/badge (37 total across 6
categories, seeded once at migration v1).

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | TEXT | PRIMARY KEY (a slug, e.g. `"evolve_beast"`, `"first_touch"`) |
| `category` | TEXT | NOT NULL, `CHECK IN` (evolution, mutation, touch, commit, surprise, speech) |
| `earned_at` | TEXT | nullable — NULL means not yet earned |
| `data_json` | TEXT | nullable |
| `ceremony_played` | INTEGER | NOT NULL, DEFAULT 0 |

**Indexes:** `idx_milestones_category`, `idx_milestones_earned_at`.

Breakdown of the 37 seeded IDs (`Schema.milestoneSeedData`): 10 mutation
badges, 9 touch milestones, 7 commit-count milestones, 5 evolution
milestones, 3 speech milestones, 3 surprise milestones (10 + 9 + 7 + 5 + 3 +
3 = 37), counted directly from the seed array literal during this
verification pass — no source doc in this wave's scope quoted a milestone
count to reconcile against, so this is simply the ground truth for future
concepts (e.g. a mutation-badges or milestones-catalog concept) to cite.

# repos

Tracks each repo the daemon has analyzed for its landmark rendering in the
world (Phase 3, migration v2). Superseded the deprecated
`world_objects.repo_name`/`landmark_type` columns above.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `path` | TEXT | NOT NULL, UNIQUE |
| `name` | TEXT | NOT NULL |
| `landmark_type` | TEXT | NOT NULL, `CHECK IN` 9 values (neon_tower, fortress, obelisk, crystal, smoke_stack, observatory, scroll_tower, windmill, monolith) |
| `dominant_language` | TEXT | nullable |
| `world_x_position` | REAL | NOT NULL |
| `commit_count` | INTEGER | NOT NULL, DEFAULT 0 |
| `analyzed_at` | TEXT | NOT NULL |
| `created_at` | TEXT | NOT NULL |

**Indexes:** `idx_repos_name`, `idx_repos_path`.

# touch_stats

Single row (`id = 1`), added in migration v3 (Phase 6) — cumulative touch
interaction counters.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `id` | INTEGER | PRIMARY KEY, `CHECK (id = 1)` |
| `total_touches` | INTEGER | NOT NULL, DEFAULT 0 |
| `taps` | INTEGER | NOT NULL, DEFAULT 0 |
| `double_taps` | INTEGER | NOT NULL, DEFAULT 0 |
| `triple_taps` | INTEGER | NOT NULL, DEFAULT 0 |
| `long_presses` | INTEGER | NOT NULL, DEFAULT 0 |
| `sustained_touches` | INTEGER | NOT NULL, DEFAULT 0 |
| `drags` | INTEGER | NOT NULL, DEFAULT 0 |
| `petting_strokes` | INTEGER | NOT NULL, DEFAULT 0 |
| `flicks` | INTEGER | NOT NULL, DEFAULT 0 |
| `rapid_taps` | INTEGER | NOT NULL, DEFAULT 0 |
| `boops` | INTEGER | NOT NULL, DEFAULT 0 |
| `belly_rubs` | INTEGER | NOT NULL, DEFAULT 0 |
| `hand_feeds` | INTEGER | NOT NULL, DEFAULT 0 |
| `laser_pointer_seconds` | REAL | NOT NULL, DEFAULT 0.0 |
| `daily_interaction_streak` | INTEGER | NOT NULL, DEFAULT 0 |
| `last_interaction_date` | TEXT | nullable |

# game_scores

One row per mini-game type, added in migration v3.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `game_type` | TEXT | PRIMARY KEY |
| `high_score` | INTEGER | NOT NULL, DEFAULT 0 |
| `total_plays` | INTEGER | NOT NULL, DEFAULT 0 |
| `last_played` | TEXT | nullable |

# game_unlocks

One row per mini-game type, added in migration v3. "Catch" is seeded as
always-unlocked at migration time; the other four mini-games from the
vision doc's catalog have no seed row until first unlocked.

### Schema
| Column | Type | Constraints / Default |
|---|---|---|
| `game_type` | TEXT | PRIMARY KEY |
| `unlocked` | INTEGER | NOT NULL, DEFAULT 0 |
| `total_plays` | INTEGER | NOT NULL, DEFAULT 0 |
| `first_played` | TEXT | nullable |

# Migration History

| Version | Description |
|---|---|
| 1 | Initial 12 tables + seed data (creature, journal, world, taught_behaviors, habits, preferences, quirks, routines, world_objects, commits, surprises, milestones) |
| 2 | Add `repos` table (P3-T3-10) |
| 3 | Add `touch_stats`, `game_scores`, `game_unlocks` (Phase 6) |
| 4 | Add `wear_rate` to `world_objects` |
| 5 | Add `rarity`, `shiny` to `creature` |
| 6 | Add 6 skill-stat columns to `creature` |
| 7 | Add `last_dream_at`, `dream_count` to `creature` |
| 8 | Add `explored_ranges` to `world` (fog-of-war persistence) |

Migrations are forward-only and version-tracked (see
[persistence and recovery](/OPERATIONS/persistence-and-recovery.md) for the
mechanism); each runs in its own transaction with rollback on failure.

# Citations

[1] `Pushling/Sources/Pushling/State/Schema.swift`
[2] `Pushling/Sources/Pushling/State/Migration.swift`
[3] `Pushling/Sources/Pushling/State/DatabaseManager.swift`
[4] `Pushling/Sources/Pushling/State/StateCoordinator.swift` (`MutationQueryProvider` — `commits.language`/`has_tests` mismatch)
[5] `mcp/src/state.ts` (TypeScript interfaces mirroring this schema)
[6] `docs/archive/plan/phase-1-foundation/PHASE-1.md` — P1-T2-01 through P1-T2-09 (superseded snapshot; StateManager class name and table-count claims are stale)
