# Phase 1: Foundation

**Goal**: Establish the scaffolding for all 4 codebases. Define shared interfaces and protocols. Get a blank Touch Bar app running with a SpriteKit scene at 60fps. Prove the IPC round-trip between Swift daemon and Node.js MCP server. Lay the SQLite schema that everything downstream depends on.

**Estimated Duration**: 1–2 weeks
**Parallel Tracks**: 4 (can run simultaneously with defined sync points)
**Vision Reference**: `PUSHLING_VISION.md` — Architecture, State Persistence, IPC, MCP Integration sections

---

## Track 1: Swift App Scaffold (P1-T1)

**Agents**: swift-scaffold
**Depends On**: Nothing (can start immediately)
**Delivers To**: All other tracks (the running app is the host for everything else)

### P1-T1-01: Xcode Project & Swift Package Manager Setup

**What**: Create the Pushling Xcode project with Swift Package Manager for dependency management.

**Acceptance Criteria**:
- Xcode project at `Pushling/Pushling.xcodeproj` (or Package.swift workspace)
- macOS deployment target: 14.0+ (Sonoma)
- Build targets: `Pushling` (app), `PushlingTests` (unit tests)
- Swift 5.9+
- Directory structure matches `CLAUDE.md` architecture:
  ```
  Pushling/
  ├── App/          # AppDelegate, lifecycle
  ├── TouchBar/     # NSTouchBar setup, private API
  ├── Scene/        # SpriteKit scene
  ├── Creature/     # (empty, Phase 2)
  ├── World/        # (empty, Phase 3)
  ├── Input/        # (empty, Phase 3)
  ├── State/        # SQLite (Track 2)
  ├── IPC/          # Socket server (Track 3)
  ├── Feed/         # (empty, Phase 4)
  └── Assets/       # (empty, Phase 2)
  ```
- Clean build with zero warnings
- `.gitignore` updated for Xcode artifacts

**Constraints**:
- No CocoaPods or Carthage — SPM only
- Keep `Package.swift` minimal (add deps only when needed in later tasks)

---

### P1-T1-02: Menu Bar Daemon Setup

**What**: Configure the app as a persistent menu-bar daemon — no dock icon, no main window, just an NSStatusItem.

**Acceptance Criteria**:
- `LSUIElement = true` in Info.plist (app does not appear in Dock)
- `NSApplication` subclass or `AppDelegate` that:
  - Creates an `NSStatusItem` with a small icon (placeholder: a 16x16 pixel cat silhouette or the text "P")
  - Status item menu includes: "About Pushling", separator, "Quit Pushling"
  - App stays running after all windows are closed
- Selecting "Quit" terminates cleanly (releases Touch Bar, closes socket, flushes SQLite)
- App launches to menu bar with no visible windows

**Constraints**:
- No SwiftUI for the menu — use `NSMenu` directly (simpler, less overhead for a daemon)
- The status item is minimal; it exists mainly for quit access and future diagnostics

---

### P1-T1-03: Touch Bar Takeover via Private API

**What**: Take over the system Touch Bar using Apple's private `DFRFoundation` framework, the same technique proven by MTMR, Pock, and 5+ Touch Bar game projects.

**Acceptance Criteria**:
- Private API bridge header or Swift wrapper for:
  - `DFRSystemModalShowsCloseBoxWhenFrontMost(false)`
  - `DFRElementSetControlStripPresenceForIdentifier(identifier, true)`
  - `NSTouchBar.presentSystemModalTouchBar(_:placement:systemTrayItemIdentifier:)`
- The app presents a system-modal `NSTouchBar` that replaces the default system strip
- Touch Bar shows our custom content (even if it's just a colored rectangle at this stage)
- System Touch Bar is restored cleanly on app quit
- Works with macOS 14+ (Sonoma and later)

**Constraints**:
- Abstract all private API calls behind a `TouchBarController` protocol — if Apple changes the API in a future macOS version, only one file changes
- Document the private API symbols used (header file or comments) for future maintenance
- Handle the case where DFRFoundation is unavailable (app launches but logs a warning, doesn't crash)

**Research Reference**: `docs/TOUCHBAR-TECHNIQUES.md` — Section 3 (Software Ecosystem), Section 4 (Rendering Techniques), Section 11 (Existing Projects Catalog)

---

### P1-T1-04: SpriteKit SKView in Touch Bar

**What**: Embed a SpriteKit `SKView` inside an `NSCustomTouchBarItem`, presenting a 1085x30pt scene on the Touch Bar.

**Acceptance Criteria**:
- `NSCustomTouchBarItem` wraps an `SKView`
- `SKScene` configured:
  - Size: 1085 x 30 points
  - Scale mode: `.aspectFill`
  - Background color: `SKColor.black` (OLED true black — pixels OFF)
  - Anchor point: (0, 0) — bottom-left origin
- Scene is presented and visible on the Touch Bar
- The SKView correctly handles @2x Retina (2170 x 60 actual pixels)
- A test node is visible (e.g., a white rectangle or circle) to confirm rendering works

**Constraints**:
- The `SKScene` subclass should be in `Scene/PushlingScene.swift`
- Keep the scene class clean — it will become the host for all world/creature rendering
- No game logic in the scene yet — just the blank canvas

---

### P1-T1-05: 60fps Render Loop with Frame Budget Monitoring

**What**: Ensure the SpriteKit scene runs at a stable 60fps with frame budget instrumentation.

**Acceptance Criteria**:
- `SKView.preferredFramesPerSecond = 60`
- Frame budget monitor that:
  - Measures time spent in `update(_:)` each frame
  - Logs a warning if any frame exceeds 10ms (60% of 16.6ms budget)
  - Logs an error if any frame exceeds 14ms (approaching dropped frame)
  - Tracks rolling average over last 60 frames
- Debug overlay (toggled via status menu) showing:
  - Current FPS
  - Frame time (ms)
  - Node count
- Empty scene frame time is < 1ms (baseline measurement)
- The scene update loop calls subsystem update methods in order: Physics → State → Render (skeleton methods, no implementation yet)

**Constraints**:
- Frame monitoring must be zero-cost when disabled (compile flag or runtime toggle)
- Use `CADisplayLink` timing or SpriteKit's built-in `currentTime` parameter — don't add external timing dependencies
- Target: < 5.7ms total frame budget with all subsystems running (per vision doc performance table)

---

### P1-T1-06: LaunchAgent for Auto-Start

**What**: Create a `launchd` plist so Pushling starts automatically on login.

**Acceptance Criteria**:
- Plist file: `com.pushling.daemon.plist`
- Installs to `~/Library/LaunchAgents/`
- Configured for:
  - `RunAtLoad = true`
  - `KeepAlive = true` (restart on crash)
  - `StandardOutPath` and `StandardErrorPath` to `~/Library/Logs/Pushling/`
  - `ProcessType = Interactive` (higher scheduling priority for 60fps)
- Install/uninstall is scriptable: `pushling install-agent` / `pushling remove-agent` (or equivalent in-app toggle)
- The app detects whether the LaunchAgent is installed and shows status in the menu

**Constraints**:
- Don't auto-install on first launch — let the user opt in
- The plist must point to the actual app location (handle `/Applications/Pushling.app` and development builds)

---

### Track 1 Deliverable

A menu-bar daemon that takes over the Touch Bar and shows a blank SpriteKit scene at 60fps. The developer sees: a black Touch Bar with a debug overlay showing "60fps, 0 nodes, 0.3ms". The app starts on login, quits cleanly, and restores the system Touch Bar on exit.

---

## Track 2: State & Persistence (P1-T2)

**Agents**: swift-state
**Depends On**: P1-T1-01 (Xcode project exists)
**Delivers To**: Track 3 (IPC reads state), Track 4 (MCP server reads state), Phase 2+ (everything)

### P1-T2-01: SQLite WAL Mode Setup

**What**: Initialize SQLite with WAL mode for concurrent reader access.

**Acceptance Criteria**:
- Database file: `~/.local/share/pushling/state.db`
- Parent directories created automatically if missing
- WAL mode enabled: `PRAGMA journal_mode=WAL`
- Additional pragmas for performance and safety:
  - `PRAGMA synchronous=NORMAL` (safe with WAL, better performance)
  - `PRAGMA foreign_keys=ON`
  - `PRAGMA busy_timeout=5000` (5s retry on contention)
- Use GRDB.swift (via SPM) OR raw SQLite3 C API — agent's choice, but must:
  - Support concurrent reads from a separate process (the MCP server)
  - Handle WAL checkpointing automatically
  - Be thread-safe within the daemon
- Database connection singleton: `StateManager` class with `shared` instance
- Connection opens on app launch, closes on quit
- Logs database path on startup for debugging

**Constraints**:
- The daemon is the ONLY writer. The MCP server reads via a separate connection.
- Never use `PRAGMA journal_mode=DELETE` — WAL is required for concurrent access

---

### P1-T2-02: Schema v1 — Creature Table

**What**: Create the primary creature state table.

**Acceptance Criteria**:
- Table: `creature`
- Single row (one creature per machine). Enforced by schema or application logic.
- Columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Always 1 |
| `name` | TEXT NOT NULL | Two-syllable generated name (e.g., "Zepus") |
| `stage` | TEXT NOT NULL | One of: spore, drop, critter, beast, sage, apex |
| `commits_eaten` | INTEGER NOT NULL DEFAULT 0 | Total commits consumed |
| `xp` | INTEGER NOT NULL DEFAULT 0 | Total XP earned |
| `xp_to_next_stage` | INTEGER NOT NULL | Computed threshold for next stage |
| `activity_factor` | REAL NOT NULL DEFAULT 1.0 | Locked after week 1 (0.5–3.0) |
| `energy_axis` | REAL NOT NULL DEFAULT 0.5 | Personality: 0.0 (calm) to 1.0 (hyper) |
| `verbosity_axis` | REAL NOT NULL DEFAULT 0.5 | Personality: 0.0 (stoic) to 1.0 (chatty) |
| `focus_axis` | REAL NOT NULL DEFAULT 0.5 | Personality: 0.0 (scattered) to 1.0 (deliberate) |
| `discipline_axis` | REAL NOT NULL DEFAULT 0.5 | Personality: 0.0 (chaotic) to 1.0 (methodical) |
| `specialty` | TEXT NOT NULL DEFAULT 'polyglot' | Language specialty category |
| `satisfaction` | REAL NOT NULL DEFAULT 50.0 | Emotional axis 0–100 |
| `curiosity` | REAL NOT NULL DEFAULT 50.0 | Emotional axis 0–100 |
| `contentment` | REAL NOT NULL DEFAULT 50.0 | Emotional axis 0–100 |
| `emotional_energy` | REAL NOT NULL DEFAULT 50.0 | Emotional axis 0–100 |
| `streak_days` | INTEGER NOT NULL DEFAULT 0 | Current consecutive commit days |
| `streak_last_date` | TEXT | ISO date of last commit day |
| `favorite_language` | TEXT | Current favorite language ext |
| `disliked_language` | TEXT | Current disliked language ext |
| `touch_count` | INTEGER NOT NULL DEFAULT 0 | Lifetime touch interactions |
| `title` | TEXT | Optional title (Beast+) |
| `motto` | TEXT | Optional motto (Sage+) |
| `base_color_hue` | REAL | Derived from dominant language |
| `body_proportion` | REAL | Derived from add/delete ratio |
| `fur_pattern` | TEXT | Derived from repo count |
| `tail_shape` | TEXT | Derived from language family |
| `eye_shape` | TEXT | Derived from commit message style |
| `created_at` | TEXT NOT NULL | ISO 8601 datetime |
| `last_fed_at` | TEXT | ISO 8601 datetime of last commit eaten |
| `last_touched_at` | TEXT | ISO 8601 datetime of last human touch |
| `last_session_at` | TEXT | ISO 8601 datetime of last Claude session |
| `hatched` | INTEGER NOT NULL DEFAULT 0 | Boolean: has hatching ceremony played? |

**Constraints**:
- All personality axes are REAL in range [0.0, 1.0]
- All emotional axes are REAL in range [0.0, 100.0]
- Stage must be one of the 6 valid values
- Specialty must be one of the 11 valid categories from the vision doc

---

### P1-T2-03: Schema v1 — Journal Table

**What**: Create the event journal for creature history.

**Acceptance Criteria**:
- Table: `journal`
- Columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `type` | TEXT NOT NULL | Entry type (see below) |
| `summary` | TEXT NOT NULL | Human-readable summary |
| `timestamp` | TEXT NOT NULL | ISO 8601 datetime |
| `data` | TEXT | JSON blob with type-specific payload |

- Valid `type` values: `commit`, `touch`, `ai_speech`, `failed_speech`, `ai_move`, `ai_express`, `ai_perform`, `surprise`, `evolve`, `first_word`, `dream`, `discovery`, `mutation`, `hook`, `session`, `teach`, `nurture`, `world_change`
- Index on `type` for filtered queries
- Index on `timestamp` for chronological queries
- Composite index on `(type, timestamp)` for filtered chronological queries

**Constraints**:
- Journal is append-only during normal operation
- The `data` JSON column stores type-specific payloads (commit SHA, XP breakdown, speech text, etc.)
- No hard row limit — rely on time-based cleanup (>6 months old entries can be archived)

---

### P1-T2-04: Schema v1 — World Table

**What**: Create the world state table for weather, biome, time state.

**Acceptance Criteria**:
- Table: `world`
- Single row (like creature table).
- Columns:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Always 1 |
| `weather` | TEXT NOT NULL DEFAULT 'clear' | Current: clear, cloudy, rain, storm, snow, fog |
| `weather_changed_at` | TEXT | ISO 8601 datetime of last weather change |
| `biome` | TEXT NOT NULL DEFAULT 'plains' | Current biome at creature position |
| `time_period` | TEXT NOT NULL DEFAULT 'day' | deep_night, dawn, morning, day, golden_hour, dusk, evening, late_night |
| `time_override` | TEXT | If set, overrides wall-clock time period |
| `time_override_until` | TEXT | ISO 8601 datetime when override expires |
| `creature_x` | REAL NOT NULL DEFAULT 542.5 | Creature position (center of 1085pt bar) |
| `creature_facing` | TEXT NOT NULL DEFAULT 'right' | left or right |
| `camera_offset` | REAL NOT NULL DEFAULT 0.0 | World scroll offset |
| `companion_type` | TEXT | Active companion type (mouse, bird, etc.) or NULL |
| `companion_name` | TEXT | Companion name if set |
| `companion_spawned_at` | TEXT | ISO 8601 |

---

### P1-T2-05: Schema v1 — Taught Behaviors, Habits, Preferences, Quirks, Routines

**What**: Create all the nurture/teach system tables.

**Acceptance Criteria**:

**Table: `taught_behaviors`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `name` | TEXT NOT NULL UNIQUE | Behavior name (e.g., "roll_over") |
| `category` | TEXT NOT NULL | playful, affectionate, dramatic, calm, silly, functional |
| `stage_min` | TEXT NOT NULL DEFAULT 'spore' | Minimum stage required |
| `duration_s` | REAL NOT NULL | Total duration in seconds |
| `tracks_json` | TEXT NOT NULL | JSON: the multi-track choreography notation |
| `triggers_json` | TEXT NOT NULL | JSON: idle_weight, on_touch, emotional_conditions |
| `mastery_level` | INTEGER NOT NULL DEFAULT 0 | 0=learning, 1=practiced, 2=mastered, 3=signature |
| `performance_count` | INTEGER NOT NULL DEFAULT 0 | Times performed |
| `strength` | REAL NOT NULL DEFAULT 0.5 | 0.0–1.0, decays over time |
| `reinforcement_count` | INTEGER NOT NULL DEFAULT 0 | Times reinforced by Claude |
| `source` | TEXT NOT NULL DEFAULT 'taught' | taught, self_taught (hybrid) |
| `parent_a` | TEXT | For hybrids: name of first parent behavior |
| `parent_b` | TEXT | For hybrids: name of second parent behavior |
| `created_at` | TEXT NOT NULL | ISO 8601 |
| `last_performed_at` | TEXT | ISO 8601 |
| `last_decayed_at` | TEXT | ISO 8601 of last decay calculation |

**Table: `habits`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `name` | TEXT NOT NULL | Descriptive name |
| `trigger_json` | TEXT NOT NULL | JSON: trigger type and conditions |
| `action_json` | TEXT NOT NULL | JSON: what the creature does |
| `frequency` | TEXT NOT NULL DEFAULT 'sometimes' | always, often, sometimes, rarely |
| `variation` | TEXT NOT NULL DEFAULT 'moderate' | strict, moderate, loose, wild |
| `strength` | REAL NOT NULL DEFAULT 0.5 | 0.0–1.0 |
| `reinforcement_count` | INTEGER NOT NULL DEFAULT 0 | |
| `cooldown_s` | REAL NOT NULL DEFAULT 60.0 | Minimum seconds between triggers |
| `last_triggered_at` | TEXT | ISO 8601 |
| `created_at` | TEXT NOT NULL | ISO 8601 |

**Table: `preferences`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `subject` | TEXT NOT NULL | What the preference is about (e.g., "rain", "mushrooms") |
| `valence` | REAL NOT NULL | -1.0 (strong dislike) to +1.0 (strong fascination) |
| `strength` | REAL NOT NULL DEFAULT 0.5 | |
| `reinforcement_count` | INTEGER NOT NULL DEFAULT 0 | |
| `created_at` | TEXT NOT NULL | ISO 8601 |

**Table: `quirks`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `name` | TEXT NOT NULL | Descriptive name |
| `behavior_target` | TEXT NOT NULL | Which behavior this modifies |
| `modifier_json` | TEXT NOT NULL | JSON: what changes (e.g., "look left before") |
| `probability` | REAL NOT NULL DEFAULT 0.5 | 0.0–1.0 chance of triggering |
| `strength` | REAL NOT NULL DEFAULT 0.5 | |
| `reinforcement_count` | INTEGER NOT NULL DEFAULT 0 | |
| `created_at` | TEXT NOT NULL | ISO 8601 |

**Table: `routines`**

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `slot` | TEXT NOT NULL UNIQUE | Lifecycle slot: morning, post_meal, bedtime, greeting, farewell, return, milestone, weather_change, boredom, post_feast |
| `steps_json` | TEXT NOT NULL | JSON array of ordered actions |
| `strength` | REAL NOT NULL DEFAULT 0.5 | |
| `reinforcement_count` | INTEGER NOT NULL DEFAULT 0 | |
| `created_at` | TEXT NOT NULL | ISO 8601 |

**Constraints**:
- Max 30 taught_behaviors rows (enforce in application logic, not schema)
- Max 20 habits rows
- Max 12 preferences rows
- Max 12 quirks rows
- Max 10 routines rows (one per slot)
- All `strength` values decay per the mastery-based decay table in the vision doc

---

### P1-T2-06: Schema v1 — World Objects Table

**What**: Create the persistent objects table for Claude-placed and system-generated world items.

**Acceptance Criteria**:
- Table: `world_objects`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `name` | TEXT | Optional name |
| `base_shape` | TEXT NOT NULL | One of 60 base shapes or 20 preset names |
| `position_x` | REAL NOT NULL | World-space X position |
| `layer` | TEXT NOT NULL DEFAULT 'fore' | far, mid, fore |
| `size` | REAL NOT NULL DEFAULT 1.0 | Scale multiplier |
| `color_json` | TEXT | JSON: primary, secondary, accent (palette names) |
| `effects_json` | TEXT | JSON: glow, pulse, particles, shimmer |
| `physics_json` | TEXT | JSON: pushable, rollable, weight |
| `interaction` | TEXT NOT NULL DEFAULT 'examining' | One of 14 interaction templates |
| `wear` | REAL NOT NULL DEFAULT 0.0 | 0.0 (new) to 1.0 (worn out) |
| `source` | TEXT NOT NULL DEFAULT 'system' | system, ai_placed, repo_landmark |
| `repo_name` | TEXT | For repo landmarks: which repo |
| `landmark_type` | TEXT | For repo landmarks: neon_tower, fortress, etc. |
| `is_active` | INTEGER NOT NULL DEFAULT 1 | 0 = on legacy shelf (removed but remembered) |
| `created_at` | TEXT NOT NULL | ISO 8601 |
| `removed_at` | TEXT | ISO 8601 if moved to legacy shelf |

**Constraints**:
- Max 12 active (`is_active=1`) non-repo-landmark objects
- Max 3 active consumables (tracked by interaction type)
- Repo landmarks have no cap (they grow with repos tracked)
- Minimum 20pt spacing between active objects (enforce in application logic)

---

### P1-T2-06b: Schema v1 — Commits Table

**What**: Create the commits table for tracking processed commit feed data.

**Acceptance Criteria**:
- Table: `commits`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | |
| `sha` | TEXT NOT NULL UNIQUE | Commit SHA (short) |
| `message` | TEXT NOT NULL | First 120 chars of commit message |
| `repo_name` | TEXT NOT NULL | Repository name |
| `files_changed` | INTEGER NOT NULL DEFAULT 0 | |
| `lines_added` | INTEGER NOT NULL DEFAULT 0 | |
| `lines_removed` | INTEGER NOT NULL DEFAULT 0 | |
| `languages` | TEXT | Comma-separated file extensions |
| `is_merge` | INTEGER NOT NULL DEFAULT 0 | Boolean |
| `is_revert` | INTEGER NOT NULL DEFAULT 0 | Boolean |
| `is_force_push` | INTEGER NOT NULL DEFAULT 0 | Boolean |
| `branch` | TEXT | Branch name |
| `xp_awarded` | INTEGER NOT NULL DEFAULT 0 | XP calculated for this commit |
| `commit_type` | TEXT | Detected type: large_refactor, test, docs, css, etc. |
| `eaten_at` | TEXT NOT NULL | ISO 8601 datetime when processed |

- Index on `sha` for dedup
- Index on `eaten_at` for chronological queries
- Index on `repo_name` for per-repo filtering
- Index on `languages` for mutation badge detection (Polyglot)

**Constraints**:
- Used for `pushling_recall("commits")` queries, mutation badge detection, and language preference calculation
- Rows older than 6 months can be archived (retain summary stats)

---

### P1-T2-06c: Schema v1 — Surprises Table

**What**: Create the surprise tracking table for scheduling, cooldowns, and history.

**Acceptance Criteria**:
- Table: `surprises`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Surprise number (1-78) |
| `category` | TEXT NOT NULL | visual, contextual, cat, milestone, time, easter_egg, hook_aware, collaborative |
| `last_fired_at` | TEXT | ISO 8601 datetime |
| `fire_count` | INTEGER NOT NULL DEFAULT 0 | Total times this surprise has fired |
| `cooldown_until` | TEXT | ISO 8601 datetime (per-surprise cooldown) |
| `enabled` | INTEGER NOT NULL DEFAULT 1 | Can be disabled for one-time surprises that have fired |

- Populated with 78 rows on initial migration (one per surprise)
- Category cooldown tracked separately in application logic (15-minute per-category, 5-minute global)

**Constraints**:
- One-time surprises (e.g., commit #404, commit #42) set `enabled = 0` after firing
- Recency penalty: surprises fired in the last hour have 50% reduced probability (computed from `last_fired_at`)

---

### P1-T2-06d: Schema v1 — Milestones Table

**What**: Create the milestones table for tracking achievements, mutation badges, and one-time events.

**Acceptance Criteria**:
- Table: `milestones`

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT PRIMARY KEY | e.g., "first_word", "nocturne", "touch_laser_pointer" |
| `category` | TEXT NOT NULL | evolution, mutation, touch, commit, surprise, speech |
| `earned_at` | TEXT | ISO 8601 datetime (NULL if not yet earned) |
| `data_json` | TEXT | Type-specific payload (e.g., commit count at earning, stage at earning) |
| `ceremony_played` | INTEGER NOT NULL DEFAULT 0 | Whether the visual ceremony has been shown |

- Pre-populated rows for known milestones (10 mutation badges, 9 human touch milestones, commit count milestones, stage transitions)
- Index on `category` for filtered queries
- Index on `earned_at` for chronological display

**Constraints**:
- Touch milestones (first_touch, finger_trail, petting, laser_pointer, first_mini_game, belly_rub, pre_contact_purr, touch_mastery) gate gesture unlocks
- Mutation badges (nocturne, polyglot, marathon, etc.) apply visual and behavioral changes when earned

---

### P1-T2-07: Migration System

**What**: Version-tracked schema upgrades that run automatically on app launch.

**Acceptance Criteria**:
- Table: `schema_version` with single row tracking current version
- Migration runner that:
  - Checks current version on launch
  - Runs all pending migrations in order
  - Each migration runs in a transaction (rollback on failure)
  - Logs each migration applied
- Migration v1 creates all tables defined in P1-T2-02 through P1-T2-06d
- Future migrations are added as numbered files/functions (v2, v3, etc.)
- Downgrade is NOT supported (forward-only) — log a fatal error if database is newer than app

**Constraints**:
- Migrations must be idempotent-safe (running the same migration twice doesn't break things)
- Never drop columns in a migration — SQLite doesn't handle that well. Add new columns, deprecate old ones.

---

### P1-T2-08: Crash Recovery via Heartbeat File

**What**: Detect unclean shutdowns and recover gracefully.

**Acceptance Criteria**:
- Heartbeat file: `/tmp/pushling.heartbeat`
- Written every 30 seconds with: `{ "pid": <pid>, "timestamp": "<iso8601>", "state": "running" }`
- On launch:
  1. Check if heartbeat file exists
  2. If exists and PID is not running → previous crash detected
  3. Log crash recovery event
  4. Read SQLite for last known good state
  5. Journal entry: `{ "type": "crash_recovery", "data": { "last_heartbeat": "..." } }`
  6. Resume normal operation from persisted state
- On clean quit: delete heartbeat file, write `{ "state": "shutdown" }`

**Constraints**:
- The heartbeat write must be < 1ms (just a file write)
- Don't use the heartbeat for state — it's purely a liveness signal. All state is in SQLite.

---

### P1-T2-09: Daily Backup System

**What**: Automated daily SQLite backups.

**Acceptance Criteria**:
- Backup directory: `~/.local/share/pushling/backups/`
- One backup per day: `state-YYYY-MM-DD.db`
- Backup uses SQLite's `VACUUM INTO` (online backup, doesn't block WAL readers)
- Runs once per day on first frame update after midnight (or on launch if no backup today)
- Retains last 30 days of backups (delete older ones)
- Logs backup success/failure

**Constraints**:
- Backup must not block the render loop — run on a background thread
- If backup fails, log and retry next hour. Don't crash.

---

### Track 2 Deliverable

SQLite database at `~/.local/share/pushling/state.db` with all tables created, migration system, heartbeat-based crash recovery, and daily backups. A fresh launch creates the database with empty tables. The schema supports everything needed through Phase 8.

---

## Track 3: IPC & Protocol (P1-T3)

**Agents**: swift-ipc, mcp-ipc
**Depends On**: P1-T1-01 (Xcode project), P1-T4-01 (Node.js project for client side)
**Delivers To**: Track 4 (MCP server uses IPC client), Phase 4+ (all MCP tool calls flow through IPC)

### P1-T3-01: NDJSON Protocol Specification

**What**: Define the wire protocol for communication between the Swift daemon and the Node.js MCP server.

**Acceptance Criteria**:
- Document: `docs/IPC-PROTOCOL.md` (checked into repo)
- Protocol: Newline-Delimited JSON (NDJSON) over Unix domain socket
- Socket path: `/tmp/pushling.sock`

**Request format**:
```json
{
  "id": "<uuid>",
  "cmd": "<command_name>",
  "action": "<action>",
  "params": { ... }
}
```

**Response format**:
```json
{
  "id": "<matching_uuid>",
  "ok": true,
  "data": { ... },
  "pending_events": [
    {
      "type": "<event_type>",
      "timestamp": "<iso8601>",
      "data": { ... }
    }
  ]
}
```

**Error response format**:
```json
{
  "id": "<matching_uuid>",
  "ok": false,
  "error": "<human-readable error message>",
  "code": "<ERROR_CODE>",
  "pending_events": [ ... ]
}
```

**Commands** (all 9 MCP tools map to commands):

| Command | Action Examples | Maps To |
|---------|----------------|---------|
| `sense` | self, body, surroundings, visual, events, developer, evolve, full | `pushling_sense` |
| `move` | goto, walk, stop, jump, turn, retreat, pace, approach_edge, center, follow_cursor | `pushling_move` |
| `express` | joy, curiosity, surprise, contentment, thinking, mischief, ... (16 expressions including neutral) | `pushling_express` |
| `speak` | say, think, exclaim, whisper, sing, dream, narrate | `pushling_speak` |
| `perform` | wave, spin, bow, dance, ... OR sequence mode | `pushling_perform` |
| `world` | weather, event, place, create, remove, modify, time_override, sound, companion | `pushling_world` |
| `recall` | recent, commits, touches, conversations, milestones, dreams, relationship, failed_speech | `pushling_recall` |
| `teach` | compose, preview, refine, commit, list, remove | `pushling_teach` |
| `nurture` | habit, preference, quirk, routine, identity, suggest, list, remove | `pushling_nurture` |

**Session management**:
- `connect` — MCP server announces session. Returns session ID + full creature state.
- `disconnect` — MCP server announces session end. Triggers farewell animation.
- `ping` — heartbeat. Response includes pending_events.

**Pending events contract**:
- Every response includes `pending_events` — events since the last response to this session
- Events are buffered per-session in a ring buffer (max 100 events)
- Events include: commits eaten, touches, surprises triggered, evolution, weather changes, etc.
- If buffer overflows, oldest events are dropped and a `{ "type": "events_dropped", "count": N }` entry is inserted

**Constraints**:
- Messages are newline-terminated (`\n`). No newlines within a message (JSON must be single-line).
- Max message size: 64KB (generous for any response including screenshots)
- Socket is stream-oriented — handle partial reads/writes
- The daemon responds to commands as soon as they are *accepted*, not when animations complete

---

### P1-T3-02: Swift Unix Socket Server

**What**: The daemon-side socket server that listens for MCP connections.

**Acceptance Criteria**:
- Listens on `/tmp/pushling.sock`
- Removes stale socket file on startup (if previous instance crashed)
- Accepts multiple simultaneous connections (support 1–3 MCP sessions)
- For each connection:
  - Reads NDJSON lines
  - Parses command
  - Dispatches to command handler (skeleton — returns placeholder responses)
  - Writes NDJSON response
  - Buffers pending events per-connection
- Handles client disconnect cleanly (no crash, no resource leak)
- Handles malformed JSON gracefully (send error response, don't close connection)
- Uses GCD or Swift concurrency (async/await) for non-blocking I/O

**Constraints**:
- Socket I/O must NEVER block the SpriteKit render thread
- Use a dedicated dispatch queue for socket operations
- Log all connections, disconnections, and errors at debug level

---

### P1-T3-03: Node.js Unix Socket Client

**What**: The MCP server-side client that connects to the daemon.

**Acceptance Criteria**:
- TypeScript module: `mcp/src/ipc.ts`
- Connects to `/tmp/pushling.sock`
- Sends NDJSON commands, receives NDJSON responses
- API:
  ```typescript
  class DaemonClient {
    connect(): Promise<void>
    disconnect(): Promise<void>
    send(cmd: string, action: string, params?: object): Promise<IPCResponse>
    isConnected(): boolean
  }
  ```
- Handles:
  - Connection refused (daemon not running) — throws descriptive error
  - Connection lost mid-session — automatic reconnect with 1s, 2s, 4s backoff (3 attempts)
  - Partial message assembly (buffering until newline)
  - Response matching by `id` (correlate request to response)
- Timeout: 5 seconds per command (configurable)

**Constraints**:
- Use Node.js `net` module (not external dependencies)
- Promise-based API — each `send()` returns a Promise that resolves with the response
- Handle multiple in-flight requests (match by `id`)

---

### P1-T3-04: Session Management

**What**: Connection/disconnection handshake between MCP server and daemon.

**Acceptance Criteria**:
- On MCP server startup:
  1. Connect to socket
  2. Send `{ "cmd": "connect", "params": { "client": "mcp", "version": "1.0" } }`
  3. Receive `{ "ok": true, "data": { "session_id": "...", "creature": { ... } } }`
  4. Store session_id for all subsequent requests
- On MCP server shutdown:
  1. Send `{ "cmd": "disconnect", "params": { "session_id": "..." } }`
  2. Close socket
- Daemon tracks active sessions
- If daemon detects socket closure without disconnect, it triggers the 5-second farewell fade
- Session IDs are UUIDs

**Constraints**:
- The connect response includes the full creature state — the MCP server caches this and includes it in SessionStart hook context injection
- Multiple sessions are allowed (e.g., multiple Claude sessions) — each gets its own pending_events buffer

---

### P1-T3-05: Command Routing Skeleton

**What**: Dispatch incoming IPC commands to handler functions.

**Acceptance Criteria**:
- `CommandRouter` class/struct in `Pushling/IPC/`
- Maps `cmd` string to handler function
- Each of the 9 MCP commands + 3 session commands has a registered handler
- Handlers are skeleton implementations that return valid placeholder responses:
  - `sense` → returns placeholder creature state JSON
  - `move` → returns `{ "ok": true, "accepted": true }`
  - `express` → returns `{ "ok": true, "expression": "joy", "duration": 3.0 }`
  - (and so on for all commands)
- Unknown commands return: `{ "ok": false, "error": "Unknown command 'foo'. Valid: sense, move, express, speak, perform, world, recall, teach, nurture", "code": "UNKNOWN_COMMAND" }`
- Invalid actions return helpful errors: `{ "ok": false, "error": "Unknown action 'teleport' for command 'move'. Valid: goto, walk, stop, jump, turn, retreat, pace, approach_edge, center, follow_cursor", "code": "UNKNOWN_ACTION" }`

**Constraints**:
- The router must be easily extensible — adding a new command should require adding one function and one registration line
- Handler functions receive the full request and return a response dictionary (they don't need to know about socket I/O)

---

### P1-T3-06: Pending Events Buffer

**What**: Ring buffer that accumulates events for each connected MCP session.

**Acceptance Criteria**:
- `PendingEventsBuffer` class
- Capacity: 100 events per session
- API:
  - `push(event:)` — add event to all active sessions' buffers
  - `drain(sessionId:)` — return all pending events for a session and clear the buffer
- When buffer is full, oldest event is dropped and an `events_dropped` meta-event is injected
- Events have: `type` (string), `timestamp` (ISO 8601), `data` (dictionary)
- Events are accumulated by the daemon whenever something interesting happens:
  - Commit eaten
  - Touch interaction
  - Surprise triggered
  - Weather change
  - Evolution
  - etc.
- The `drain` method is called inside every IPC response builder — every response includes its session's pending events

**Constraints**:
- Thread-safe (events are pushed from the render thread, drained from the socket thread)
- Use a lock-free ring buffer or a simple mutex — keep it lightweight

---

### Track 3 Deliverable

Working IPC between Swift daemon and Node.js MCP server over Unix socket. Sending any of the 9 MCP commands from Node.js returns a valid placeholder response. Pending events buffer accumulates and drains correctly. Session connect/disconnect works cleanly.

---

## Track 4: MCP Server Scaffold (P1-T4)

**Agents**: mcp-scaffold
**Depends On**: P1-T3-01 (protocol spec), P1-T3-03 (IPC client)
**Delivers To**: Phase 4+ (Claude Code integration)

### P1-T4-01: Node.js Project Setup

**What**: Initialize the MCP server TypeScript project.

**Acceptance Criteria**:
- Directory: `mcp/`
- Files:
  - `package.json` — name: `pushling-mcp`, appropriate deps
  - `tsconfig.json` — strict mode, ES2022 target, Node16 module resolution
  - `src/index.ts` — entry point
- Dependencies:
  - `@modelcontextprotocol/sdk` — MCP SDK
  - `better-sqlite3` (or `sql.js`) — SQLite read-only access
  - TypeScript, `tsx` (for development)
- Scripts:
  - `build` — compile TypeScript
  - `start` — run compiled JS
  - `dev` — run with tsx for development
- `.gitignore` for `node_modules/`, `dist/`
- Clean `npm install` and `npm run build` with zero errors

**Constraints**:
- Minimal dependencies — every dependency is justified
- TypeScript strict mode enforced
- No runtime dependencies beyond MCP SDK, SQLite, and Node.js built-ins

---

### P1-T4-02: MCP Server Framework

**What**: Set up the MCP server with stdio transport and tool registration.

**Acceptance Criteria**:
- MCP server using `@modelcontextprotocol/sdk`
- Transport: stdio (standard for Claude Code MCP servers)
- Server name: `pushling-mcp`
- Server version from package.json
- All 9 tools registered with full JSON Schema for their parameters:
  - `pushling_sense` — params: `{ aspect?: string }`
  - `pushling_move` — params: `{ action: string, target?: string, speed?: string }`
  - `pushling_express` — params: `{ expression: string, intensity?: number, duration?: number }`
  - `pushling_speak` — params: `{ text: string, style?: string }`
  - `pushling_perform` — params: `{ behavior?: string, variant?: string, sequence?: array }`
  - `pushling_world` — params: `{ action: string, params: object }`
  - `pushling_recall` — params: `{ what?: string, count?: number }`
  - `pushling_teach` — params: `{ action: string, ... }`
  - `pushling_nurture` — params: `{ type: string, ... }`
- Each tool has a descriptive `description` field written from the embodiment perspective (e.g., "Feel yourself, your surroundings, and what's happening" for `pushling_sense`)
- Server starts cleanly, logs tool registration

**Constraints**:
- Tool descriptions must match the vision doc's embodiment framing — "sense" not "status", "express" not "set emotion"
- Parameter schemas must include `enum` constraints where the vision doc defines valid values (e.g., `aspect` enum for sense, `expression` enum for express)

---

### P1-T4-03: Tool Stubs with Placeholder Responses

**What**: Each tool returns a meaningful placeholder response that demonstrates the response shape.

**Acceptance Criteria**:
- All 9 tools are callable and return responses
- Each response includes the correct structure that the real implementation will fill in:

`pushling_sense("full")` returns:
```json
{
  "self": { "satisfaction": 50, "curiosity": 50, "contentment": 50, "energy": 50 },
  "body": { "stage": "spore", "name": "Unknown", "commits_eaten": 0 },
  "surroundings": { "weather": "clear", "biome": "plains", "time": "day" },
  "events": [],
  "developer": { "last_commit_ago_s": null },
  "pending_events": []
}
```

- Each tool that sends an IPC command includes `pending_events` in its response
- Tools that would fail at certain stages return helpful errors:
  - `pushling_speak` at Spore stage: `"You cannot speak yet. You are pure light — no mouth, no voice. You can only pulse and glow. At Drop stage (20 commits), you will gain eyes and symbols."`
  - `pushling_perform("conduct")` at Drop stage: `"Your body can't do that yet. 'conduct' requires Sage stage. At Drop, you can: wave, spin, examine, nap, celebrate, shiver."`

**Constraints**:
- Placeholder responses should be realistic enough that Claude Code sessions can test against them
- Error messages must be helpful and stage-aware — tell Claude what IS available, not just what isn't

---

### P1-T4-04: SQLite Read-Only Connection

**What**: MCP server reads creature state directly from SQLite (no IPC needed for reads).

**Acceptance Criteria**:
- Module: `mcp/src/state.ts`
- Opens `~/.local/share/pushling/state.db` in read-only mode
- Query functions:
  - `getCreature(): CreatureState` — full creature row
  - `getWorld(): WorldState` — full world row
  - `getJournal(type?: string, count?: number): JournalEntry[]` — filtered journal
  - `getTaughtBehaviors(): TaughtBehavior[]` — list all taught behaviors
  - `getHabits(): Habit[]`
  - `getPreferences(): Preference[]`
  - `getQuirks(): Quirk[]`
  - `getRoutines(): Routine[]`
  - `getWorldObjects(active?: boolean): WorldObject[]`
- TypeScript interfaces for all return types (matching schema exactly)
- Handles database not found (daemon hasn't run yet): returns null/empty with helpful error
- Handles WAL mode correctly (reads don't block daemon writes)

**Constraints**:
- NEVER write to the database from the MCP server. All mutations go through IPC to the daemon.
- Connection opens once on MCP server startup, stays open
- Use `PRAGMA query_only=ON` as a safety net

---

### P1-T4-05: IPC Client Integration

**What**: Wire the IPC client (from Track 3) into the MCP server startup lifecycle.

**Acceptance Criteria**:
- On MCP server startup:
  1. Open SQLite read-only connection
  2. Connect to daemon via Unix socket
  3. Send `connect` command, receive session ID
  4. Store session context (session_id, initial creature state)
- On MCP server shutdown:
  1. Send `disconnect` command
  2. Close socket
  3. Close SQLite connection
- If daemon is not running:
  - SQLite reads still work (creature state is queryable)
  - IPC commands return a clear error: `"The Pushling daemon is not running. Your creature's state is readable but it cannot act. Launch Pushling.app to bring it to life."`
- Tools that only need reads (some `sense` aspects, `recall`) work without daemon
- Tools that need daemon (all write commands) fail gracefully with the above message

**Constraints**:
- The MCP server must be useful even when the daemon is down — read operations should still work
- Connection state is tracked and exposed: tools can check `isDaemonConnected()` before attempting IPC

---

### P1-T4-06: Pending Events Integration

**What**: Every MCP tool response includes pending events from the daemon.

**Acceptance Criteria**:
- After every IPC command, the `pending_events` array from the response is included in the MCP tool's return value
- For tools that don't make an IPC call (pure reads), a `ping` command is sent to drain pending events
- The pending events are formatted as a readable section in the tool response:
  ```
  --- What happened since you last checked ---
  • 3 minutes ago: Ate commit "fix auth bug" for 7 XP
  • 8 minutes ago: Human petted you (chin scratch)
  • 12 minutes ago: Weather changed to rain
  ```
- If no pending events: section is omitted or says "Nothing notable happened."

**Constraints**:
- Don't flood Claude with events — summarize if there are more than 10 pending events
- Events older than 1 hour should be marked as "(earlier)" or summarized in aggregate

---

### Track 4 Deliverable

MCP server that registers with Claude Code via `claude mcp add pushling-mcp -- npx tsx mcp/src/index.ts`. All 9 `pushling_*` tools are callable. Tools return realistic placeholder responses. SQLite reads work even without the daemon. IPC commands route through to the daemon when it's running. Every response includes pending events.

---

## Phase 1 QA Gate

All of the following must be verified before Phase 1 is considered complete:

| # | Test | Pass Criteria |
|---|------|---------------|
| 1 | **App launches** | Pushling appears in menu bar, no dock icon, Touch Bar taken over |
| 2 | **Blank scene renders** | SpriteKit scene shows on Touch Bar — true black background, 1085x30pt |
| 3 | **60fps confirmed** | Debug overlay shows ≥58fps sustained (allowing minor variance) |
| 4 | **Frame budget** | Empty scene frame time < 1ms average over 60 frames |
| 5 | **Clean quit** | "Quit Pushling" restores system Touch Bar, no orphaned processes |
| 6 | **Database creates** | `~/.local/share/pushling/state.db` exists with all tables after first launch |
| 7 | **Schema complete** | All tables from P1-T2-02 through P1-T2-06d exist with correct columns (creature, journal, world, taught_behaviors, habits, preferences, quirks, routines, world_objects, commits, surprises, milestones) |
| 8 | **Migration runs** | Schema version 1 is recorded, migration log shows success |
| 9 | **Heartbeat file** | `/tmp/pushling.heartbeat` exists while running, removed on clean quit |
| 10 | **Backup runs** | `~/.local/share/pushling/backups/state-YYYY-MM-DD.db` created |
| 11 | **Socket listens** | `/tmp/pushling.sock` exists while daemon runs |
| 12 | **IPC round-trip** | Send `{ "cmd": "sense", "action": "full" }` via netcat, receive valid JSON response |
| 13 | **IPC error handling** | Send malformed JSON, receive error response (not a crash) |
| 14 | **MCP server registers** | `claude mcp list` shows `pushling-mcp` with 9 tools |
| 15 | **All 9 tools callable** | Each `pushling_*` tool returns a valid placeholder response from Claude Code |
| 16 | **SQLite read from MCP** | `pushling_sense("self")` returns data read from SQLite |
| 17 | **IPC from MCP** | `pushling_move("goto", "center")` routes through socket to daemon and back |
| 18 | **Pending events flow** | Push a test event on daemon side, verify it appears in MCP tool response |
| 19 | **Daemon down graceful** | MCP server with daemon not running: reads work, writes return helpful error |
| 20 | **LaunchAgent installs** | Plist installs to `~/Library/LaunchAgents/`, app starts on reboot |

---

## Cross-Track Sync Points

| Sync Point | When | Who Syncs | What's Exchanged |
|------------|------|-----------|-----------------|
| **S1** | After P1-T1-01 + P1-T4-01 | T1 ↔ T2, T3, T4 | Xcode project structure, Node project structure |
| **S2** | After P1-T2-01 | T2 → T4 | Database path and connection config |
| **S3** | After P1-T3-01 | T3 → T1, T3 → T4 | Protocol spec document — both sides implement against it |
| **S4** | After P1-T3-02 + P1-T3-03 | T1 ↔ T4 | Integration test: end-to-end IPC round-trip |
| **S5** | After all tracks | All | Full integration: MCP call → IPC → daemon → response → MCP |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Private Touch Bar API changes in macOS 14+ | Medium | High | Protocol-abstracted `TouchBarController`. Test on beta macOS. |
| SpriteKit in NSCustomTouchBarItem fails | Low | Critical | Proven by 5+ shipped projects. Have MTMR source as reference. |
| SQLite WAL concurrent access issues | Low | Medium | Extensive testing with simultaneous daemon writes + MCP reads |
| Socket permission issues across processes | Medium | Low | `/tmp/` is world-writable. Use `0666` permissions on socket. |
| MCP SDK breaking changes | Low | Medium | Pin SDK version in package.json |
