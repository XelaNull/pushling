---
type: Runbook
title: Pushling Persistence, Crash Recovery, and Hot-Reload
description: The heartbeat liveness file, crash-detection-on-launch flow, daily VACUUM INTO backups, and the HotReloadMonitor directory-watch mechanism that together let creature state survive restarts, crashes, and rebuilds.
status: Live
tags: [persistence, crash-recovery, backup, hot-reload, runbook]
timestamp: 2026-07-02T00:00:00Z
---

Everything here is orchestrated by `StateCoordinator` (`start()` /
`shutdown()` / `frameUpdate()`), the single entry point the app delegate
calls into. The schema those durability guarantees protect is
[its own concept](/DATA_MODELS/state-database-schema.md); the deploy
scripts that interact with `HotReloadMonitor`'s restart expectations are
[build, run, and deploy](/OPERATIONS/build-run-deploy.md).

# Startup Order

`StateCoordinator.start()` runs, in this exact order:

1. Create a `HeartbeatManager` and call `checkForCrash()` — **before** the
   database is opened, so a crash can be detected even if the database
   itself is what's corrupted.
2. Open the database (`DatabaseManager.open()` — creates the schema on
   first run, or runs any pending migrations).
3. If a crash was detected, log a `hook`-type journal entry now that the DB
   is open (`StateCoordinator.logCrashRecoveryToJournal`).
4. Re-create the `HeartbeatManager` with a live database reference and
   `start()` it (writes immediately, then every 30s).
5. Create a `BackupManager` and call `backupOnLaunchIfNeeded()`.

`shutdown()` reverses the durability-relevant steps: stop the heartbeat
(writes a `"shutdown"` marker), then close the database (which checkpoints
the WAL file before closing).

# Heartbeat & Crash Detection

**File:** `/tmp/pushling.heartbeat` (note: `/tmp`, not under
`~/.local/share/pushling/` like the rest of state — it's ephemeral
liveness data, not durable state). **Cadence:** written immediately on
`start()`, then every **30 seconds** (`HeartbeatManager.heartbeatInterval`),
atomically (`.atomic` write option).

**Payload:**
```json
{"pid": 12345, "timestamp": "2026-07-02T00:00:00Z", "state": "running"}
```
`state` is `"running"` while the timer is active, and rewritten to
`"shutdown"` (same PID, fresh timestamp) by `stop()` on a clean quit.

**`checkForCrash()` decision tree** (called once, before the DB opens):

| Heartbeat file state | Verdict | Action |
|---|---|---|
| Doesn't exist | Clean start (first launch ever, or file already cleaned up) | No-op |
| Exists, unreadable/malformed | Treat as crash | Delete file, report `crashDetected: true` |
| Exists, `state == "shutdown"` | Previous quit was clean | Delete file, report `crashDetected: false` |
| Exists, `state == "running"`, PID still alive (`kill(pid, 0) == 0`) | Another instance is already running — a **duplicate launch**, not a crash | Report `crashDetected: false`, leave file alone; caller is responsible for handling the duplicate-launch case |
| Exists, `state == "running"`, PID not alive | **Crash detected** | Delete file, report `crashDetected: true` (journal entry logged after DB opens, in step 3 above) |

The "duplicate launch" row is a real, distinct outcome from "crash" —
`HeartbeatManager` itself does not kill or refuse the second launch; it
only reports the finding. Given `run.sh`'s documented double-launch case
(see [build, run, and deploy](/OPERATIONS/build-run-deploy.md)), this path
is not merely theoretical.

The crash-recovery journal entry (`type: "hook"`, both on the
`HeartbeatManager`-owned write path and the `StateCoordinator`-owned one —
they're duplicate implementations of the same INSERT, one guarded by
`db.isOpen` for the early-launch case where the DB isn't open yet) records
the previous PID, the last heartbeat timestamp, and the recovery timestamp
as a JSON blob in `journal.data`.

# Daily Backups

**Directory:** `~/.local/share/pushling/backups/`. **Mechanism:** SQLite's
`VACUUM INTO '<path>'` — an online backup that doesn't block WAL readers
(the MCP server can keep reading while a backup runs). **File naming:**
`state-YYYY-MM-DD.db`. **Retention:** the 30 most recent files matching
that pattern are kept (`BackupManager.maxBackupDays = 30`); older ones are
deleted on every successful backup.

**Trigger:** `backupOnLaunchIfNeeded()` at startup (forces a backup if
today's file doesn't already exist), plus `frameUpdate()` calling
`backupIfNeeded()` on every SpriteKit scene update — cheap because it
short-circuits immediately (`isBackingUp` guard, then a same-day check)
unless a backup is actually due. All backup I/O runs on a dedicated
`qos: .background` `DispatchQueue`, never the render thread.

**Failure handling:** a failed `VACUUM INTO` (directory creation failure or
SQLite error) schedules a retry in exactly 1 hour
(`BackupManager.scheduleRetry`), replacing any previously-scheduled retry
timer. There is no exponential backoff or retry-count cap on backups
specifically — it will keep retrying hourly until one succeeds or the app
quits.

# Hot-Reload (HotReloadMonitor)

Watches the **directory containing the running binary**, not the binary
file itself — a `DispatchSourceFileSystemObject` opened with `O_EVTONLY` on
`binaryDirectory`. This is deliberate: a build replaces the file at that
path (new inode), so a file-descriptor watch on the old file would go
stale and silently stop firing. A 3-second polling timer runs in parallel
as a fallback in case the `DispatchSource` event is ever missed.

On detecting a newer modification time than what was recorded at `start()`,
it debounces **1 second** (`debounceWorkItem`, to let `codesign` finish
writing) before calling `onNewBinaryDetected` on the main thread. The
caller (app delegate) is expected to save state and `exit(0)`; the
LaunchAgent's `KeepAlive = true` (see
[build, run, and deploy](/OPERATIONS/build-run-deploy.md)) is what actually
relaunches the process afterward — `HotReloadMonitor` itself never calls
`exec`/relaunches anything directly, it only detects and signals.

As documented in [build, run, and deploy](/OPERATIONS/build-run-deploy.md),
none of the four shipped scripts (`build.sh`/`run.sh`/`reload.sh`/`install.sh`)
currently trigger this path in the common case, because each of them
explicitly stops any running process **before** replacing the binary on
disk — by the time the new binary lands, the old process (and its
`HotReloadMonitor` instance) is already gone. The mechanism remains
correctly implemented and available as a safety net for an out-of-band
binary replacement (e.g. a future CI/deploy tool, or a manual `rsync` into
a live install without stopping it first) — a socket `{"command":"reload"}`
message reaches the same graceful-restart code path on demand, independent
of whether the file-watch itself ever fires.

# State Survives Restart

Because `xp`, `stage`, and every other creature/world/nurture/taught-behavior
field live in `state.db` rather than in-memory-only state, and the daemon
reopens the same WAL-mode database on every launch (crash-recovered or
not), a restart — whether triggered by hot-reload, a crash-and-KeepAlive
relaunch, or a manual quit/relaunch — never resets creature progress. The
only volatile pieces of runtime state are the ones this concept documents
as intentionally ephemeral: the heartbeat file (recreated fresh on every
launch) and anything cached purely in memory (the MCP server's own
in-process session bookkeeping — see
[MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md) — which is
per-Claude-Code-session by design, not meant to survive a daemon restart).

# Citations

[1] `Pushling/Sources/Pushling/State/StateCoordinator.swift`
[2] `Pushling/Sources/Pushling/State/HeartbeatManager.swift`
[3] `Pushling/Sources/Pushling/State/BackupManager.swift`
[4] `Pushling/Sources/Pushling/App/HotReloadMonitor.swift`
[5] `docs/plan/phase-1-foundation/PHASE-1.md` — P1-T2-08 (crash recovery), P1-T2-09 (backup system) — superseded snapshot; class names corrected above (no `StateManager` type exists; the shipped classes are `DatabaseManager` + `StateCoordinator`)
