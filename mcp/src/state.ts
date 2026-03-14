/**
 * State — SQLite read-only connection to the Pushling state database.
 *
 * The daemon (Swift app) is the ONLY writer. This module opens the database
 * in read-only mode with PRAGMA query_only=ON as a safety net.
 *
 * Database path: ~/.local/share/pushling/state.db
 */

import Database from "better-sqlite3";
import { homedir } from "node:os";
import { join } from "node:path";
import { existsSync } from "node:fs";

const DB_PATH = join(homedir(), ".local", "share", "pushling", "state.db");

// ─── TypeScript interfaces matching SQLite schema ────────────────────

export interface CreatureState {
  id: number;
  name: string;
  stage: "spore" | "drop" | "critter" | "beast" | "sage" | "apex";
  commits_eaten: number;
  xp: number;
  xp_to_next_stage: number;
  activity_factor: number;
  energy_axis: number;
  verbosity_axis: number;
  focus_axis: number;
  discipline_axis: number;
  specialty: string;
  satisfaction: number;
  curiosity: number;
  contentment: number;
  emotional_energy: number;
  streak_days: number;
  streak_last_date: string | null;
  favorite_language: string | null;
  disliked_language: string | null;
  touch_count: number;
  title: string | null;
  motto: string | null;
  base_color_hue: number | null;
  body_proportion: number | null;
  fur_pattern: string | null;
  tail_shape: string | null;
  eye_shape: string | null;
  created_at: string;
  last_fed_at: string | null;
  last_touched_at: string | null;
  last_session_at: string | null;
  hatched: number;
}

export interface WorldState {
  id: number;
  weather: string;
  weather_changed_at: string | null;
  biome: string;
  time_period: string;
  time_override: string | null;
  time_override_until: string | null;
  creature_x: number;
  creature_facing: string;
  camera_offset: number;
  companion_type: string | null;
  companion_name: string | null;
  companion_spawned_at: string | null;
}

export interface JournalEntry {
  id: number;
  type: string;
  summary: string;
  timestamp: string;
  data: string | null;
}

export interface TaughtBehavior {
  id: number;
  name: string;
  category: string;
  stage_min: string;
  duration_s: number;
  tracks_json: string;
  triggers_json: string;
  mastery_level: number;
  performance_count: number;
  strength: number;
  reinforcement_count: number;
  source: string;
  parent_a: string | null;
  parent_b: string | null;
  created_at: string;
  last_performed_at: string | null;
  last_decayed_at: string | null;
}

export interface Habit {
  id: number;
  name: string;
  trigger_json: string;
  action_json: string;
  frequency: string;
  variation: string;
  strength: number;
  reinforcement_count: number;
  cooldown_s: number;
  last_triggered_at: string | null;
  created_at: string;
}

export interface Preference {
  id: number;
  subject: string;
  valence: number;
  strength: number;
  reinforcement_count: number;
  created_at: string;
}

export interface Quirk {
  id: number;
  name: string;
  behavior_target: string;
  modifier_json: string;
  probability: number;
  strength: number;
  reinforcement_count: number;
  created_at: string;
}

export interface Routine {
  id: number;
  slot: string;
  steps_json: string;
  strength: number;
  reinforcement_count: number;
  created_at: string;
}

export interface WorldObject {
  id: number;
  name: string | null;
  base_shape: string;
  position_x: number;
  layer: string;
  size: number;
  color_json: string | null;
  effects_json: string | null;
  physics_json: string | null;
  interaction: string;
  wear: number;
  source: string;
  repo_name: string | null;
  landmark_type: string | null;
  is_active: number;
  created_at: string;
  removed_at: string | null;
}

export interface CommitRecord {
  id: number;
  sha: string;
  message: string;
  repo_name: string;
  files_changed: number;
  lines_added: number;
  lines_removed: number;
  languages: string | null;
  is_merge: number;
  is_revert: number;
  is_force_push: number;
  branch: string | null;
  xp_awarded: number;
  commit_type: string | null;
  eaten_at: string;
}

// ─── StateReader ─────────────────────────────────────────────────────

export class StateReader {
  private db: Database.Database | null = null;

  /**
   * Open the SQLite database in read-only mode.
   * Returns false if the database doesn't exist yet (daemon hasn't run).
   */
  open(): boolean {
    if (this.db) return true;

    if (!existsSync(DB_PATH)) {
      return false;
    }

    try {
      this.db = new Database(DB_PATH, { readonly: true });
      this.db.pragma("query_only = ON");
      this.db.pragma("journal_mode = WAL");
      return true;
    } catch (err) {
      console.error(
        `[pushling-mcp] Failed to open database at ${DB_PATH}:`,
        err
      );
      return false;
    }
  }

  /**
   * Close the database connection.
   */
  close(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }

  /**
   * Check if the database is available.
   */
  isAvailable(): boolean {
    return this.db !== null;
  }

  /**
   * Get the database path for diagnostics.
   */
  getDatabasePath(): string {
    return DB_PATH;
  }

  // ─── Query Methods ───────────────────────────────────────────────

  getCreature(): CreatureState | null {
    if (!this.db) return null;
    try {
      return (
        (this.db
          .prepare("SELECT * FROM creature WHERE id = 1")
          .get() as CreatureState) ?? null
      );
    } catch {
      return null;
    }
  }

  getWorld(): WorldState | null {
    if (!this.db) return null;
    try {
      return (
        (this.db
          .prepare("SELECT * FROM world WHERE id = 1")
          .get() as WorldState) ?? null
      );
    } catch {
      return null;
    }
  }

  getJournal(type?: string, count = 20): JournalEntry[] {
    if (!this.db) return [];
    try {
      if (type) {
        return this.db
          .prepare(
            "SELECT * FROM journal WHERE type = ? ORDER BY timestamp DESC LIMIT ?"
          )
          .all(type, count) as JournalEntry[];
      }
      return this.db
        .prepare("SELECT * FROM journal ORDER BY timestamp DESC LIMIT ?")
        .all(count) as JournalEntry[];
    } catch {
      return [];
    }
  }

  getTaughtBehaviors(): TaughtBehavior[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM taught_behaviors ORDER BY created_at DESC")
        .all() as TaughtBehavior[];
    } catch {
      return [];
    }
  }

  getHabits(): Habit[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM habits ORDER BY created_at DESC")
        .all() as Habit[];
    } catch {
      return [];
    }
  }

  getPreferences(): Preference[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM preferences ORDER BY created_at DESC")
        .all() as Preference[];
    } catch {
      return [];
    }
  }

  getQuirks(): Quirk[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM quirks ORDER BY created_at DESC")
        .all() as Quirk[];
    } catch {
      return [];
    }
  }

  getRoutines(): Routine[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM routines ORDER BY slot ASC")
        .all() as Routine[];
    } catch {
      return [];
    }
  }

  getWorldObjects(activeOnly = true): WorldObject[] {
    if (!this.db) return [];
    try {
      if (activeOnly) {
        return this.db
          .prepare(
            "SELECT * FROM world_objects WHERE is_active = 1 ORDER BY position_x ASC"
          )
          .all() as WorldObject[];
      }
      return this.db
        .prepare("SELECT * FROM world_objects ORDER BY position_x ASC")
        .all() as WorldObject[];
    } catch {
      return [];
    }
  }

  getRecentCommits(count = 20): CommitRecord[] {
    if (!this.db) return [];
    try {
      return this.db
        .prepare("SELECT * FROM commits ORDER BY eaten_at DESC LIMIT ?")
        .all(count) as CommitRecord[];
    } catch {
      return [];
    }
  }
}
