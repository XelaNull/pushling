---
type: Playbook
title: Pushling Development Pitfalls
description: Known failure patterns and their required mitigations — verified against the shipped Swift/TypeScript/shell code, not just the design docs.
status: Live
tags: [pitfalls, playbook, performance, concurrency]
timestamp: 2026-07-02T00:00:00Z
---

This is the migrated, code-verified form of `pushling/CLAUDE.md`'s "Critical
Knowledge: What to Watch For" table plus the XP/evolution bullets from its
"State & evolution" section — the source table itself remains canon in
`CLAUDE.md` for a human skimming the repo, but this concept is where a
verification note or a nuance the flat table couldn't carry lives. Each row
was checked against code during this migration wave; a "Verified" note
marks confirmations, and any refinement is called out explicitly rather
than silently repeating a stale claim.

# The Pitfall Table

| Pattern | Problem | Solution | Verified |
|---|---|---|---|
| Blocking IPC in an MCP tool | Claude hangs waiting for animation | Return immediately on command-accept; animate async in the daemon | Confirmed — every `mcp/src/tools/*.ts` handler awaits only the socket round-trip, never an animation-completion signal; see [the tool contract](/ARCHITECTURE/mcp-tool-contract.md) |
| SQLite write from the MCP server | WAL contention with the daemon | MCP reads only. All writes go through the daemon socket. | Confirmed — `mcp/src/state.ts` opens `better-sqlite3` with `{ readonly: true }` plus `PRAGMA query_only = ON` as a second safety net; see [the MCP server concept](/SYSTEMS/mcp-server.md) |
| Heavy SpriteKit scene | Frame drops below 60fps | Keep nodes <120, recycle `SKEmitterNode` particles, profile with Instruments | Design budget, not independently re-measured this wave — matches `PUSHLING_VISION.md`'s Technical Performance table (~100 typical, ~120 peak nodes, ~5.7ms/frame total) |
| Git hook slows a commit | Developer frustration | Hook must complete in <100ms. Write JSON + signal, nothing else. Background all work. | Confirmed — `hooks/post-commit.sh` carries this exact budget in its own header comment |
| Claude Code hook latency | Perceptible delay in the dev workflow | Hooks must complete in <50ms. Write JSON + signal only — never compute inline. | Confirmed for 6 of 7 hooks (`post-tool-use.sh`, `user-prompt-submit.sh`, `subagent-start.sh`, `subagent-stop.sh`, `post-compact.sh`, `session-end.sh` all say `<50ms` verbatim). **Refinement:** `session-start.sh` alone carries a `<100ms` budget in its own header comment, not `<50ms` — a deliberate, documented exception (it does a heavier SQLite read plus multi-KB stdout generation for the awakening text, and is the only hook Claude Code injects into context), not a doc/code contradiction to resolve either way |
| Daemon crash mid-animation | Creature stuck in a weird state | Heartbeat file at `/tmp/pushling.heartbeat`. On relaunch, read recovery state, resume. | Confirmed — full mechanism documented in [persistence and recovery](/OPERATIONS/persistence-and-recovery.md) |
| State file corruption | Creature state lost | SQLite WAL + daily backups to `~/.local/share/pushling/backups/` | Confirmed — full mechanism in [persistence and recovery](/OPERATIONS/persistence-and-recovery.md)'s Daily Backups section (`VACUUM INTO`, 30-day retention). This row was silently dropped from the migrated table by an uncommitted pre-WO-1 `CLAUDE.md` edit — no drop record ever existed for it, restored here since the mitigation it names is real, shipped, and otherwise undocumented in this table |
| Touch Bar private API changes | App breaks on a macOS update | Abstract DFR calls behind a protocol. Test on beta macOS releases. | Not re-verified this wave — Touch Bar private-API integration detail is owned by a future rendering/hardware concept (SP6a/SP6b) |
| TTS model loading too slow | Audio delay on first speak | Pre-load models at daemon launch: espeak-ng <50ms, Piper <200ms, Kokoro <500ms cold / <50ms warm | Not re-verified this wave — Voice/TTS is owned by the future speech-and-voice concept (SP4) |
| TTS audio glitches | Pops, clicks, or stuttering | Use Audio Unit graph with ring buffer. Pre-render phrases when idle. Double-buffer output. | Not re-verified this wave — Voice/TTS is owned by SP4; grepped `docs/SYSTEMS/voice-tts-stack.md` and `docs/REFERENCE/creature-voice-design.md` for `double-buffer`/`Pre-render`/`ring buffer` and found no hits, so the shipped `AVAudioEngine` chain's actual glitch-prevention mechanism (if any) is unconfirmed against this stated mitigation — this row was silently dropped from the migrated table (same uncommitted pre-WO-1 edit as the row above) and is restored as the stated intent, not as a verified-live guarantee. Flagged for SP4's owner to reconcile against `Pushling/Sources/Pushling/Speech/`'s actual audio engine setup. |
| Voice mismatch at stage transition | Jarring quality jump | Cross-fade TTS tiers over 3–5 utterances during the transition window | Not re-verified this wave — same, owned by SP4 |
| Embodiment session leak | Creature stays "awake" after Claude disconnects | SessionEnd hook + 60s heartbeat timeout auto-transitions to dormant | Not re-verified this wave — session dormancy/idle behavior is owned by [MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md) (SP2a), which documents a *different* idle-gradient timing (10/20/30s phases, no literal "60s heartbeat timeout" constant found there) — flagged as a claim worth reconciling against `SessionManager.swift` by whichever wave finalizes session-lifecycle content |
| Behavior stack conflicts | AI-directed and autonomous fighting | Blend Controller interpolates ~200ms; Physics always wins; Reflexes hold a 500ms lease then release | Not re-verified this wave — owned by the creature/behavior-stack concept (SP3a) |
| Hook event flood | Too many events during rapid tool use | Rate-limit: max 10/second to the daemon; batch and coalesce | Not re-verified this wave — hooks/feed detail is owned by the future embodiment-and-hooks concept (SP7) |
| XP not persisting | Creature resets on restart | XP column is `xp`, not `total_xp`. Call `persistXPAndStage()` after every XP change. | Confirmed — `creature.xp` is the actual column (see [the schema](/DATA_MODELS/state-database-schema.md)); **refinement below** — "after every XP change" is not fully true in the shipped code |
| Hot-reload not triggering | Binary replaced but app doesn't restart | `HotReloadMonitor` watches the directory, not the file. Check LaunchAgent `KeepAlive` is enabled. | Confirmed mechanism — full detail in [persistence and recovery](/OPERATIONS/persistence-and-recovery.md), including the caveat that none of the shipped build scripts currently exercise this path in the common case |
| Evolution not firing | XP crosses a threshold, no stage change | `checkEvolution()` must run after every persist; only evolves one stage per call | Confirmed the one-stage-per-call mechanic (`checkEvolution()` loops stages in order and evolves at most one per invocation); **refinement below** — "after every persist" is not fully true in the shipped code |

# A Third Persist Path: `persistXPAndStageSync()`

Beyond the async `persistXPAndStage()` this table and the pairing table
below cover, `GameCoordinator+Loading.swift:126` defines a **synchronous**
sibling, `persistXPAndStageSync()` — identical `UPDATE creature SET xp = ?,
stage = ? WHERE id = 1` write, but via `try? db.execute(...)` directly
rather than `db.performWriteAsync`. It has exactly one call site:
`GameCoordinator.shutdown()` (`GameCoordinator.swift:308`), where it runs
synchronously specifically because the database closes immediately
afterward — an async write queued at shutdown could be dropped by the
close racing ahead of it. See
[persistence and recovery's shutdown sequence](/OPERATIONS/persistence-and-recovery.md#startup-order)
for the full ordered list of what else `shutdown()` persists synchronously
alongside this call.

# Refinement: `persistXPAndStage()` / `checkEvolution()` Pairing

The table above (accurately) states the *rule*: any XP change should call
`persistXPAndStage()` and then `checkEvolution()`. Verified against every
call site in `GameCoordinator*.swift`:

| Call site | Pairs with `checkEvolution()`? |
|---|---|
| `GameCoordinator.swift:470-471` (commit XP award) | Yes — the only fully-paired call site |
| `GameCoordinator+MenuActions.swift:293` (treat-feeding XP) | **No** — persists XP and stage but never calls `checkEvolution()` afterward |
| `GameCoordinator+Hatching.swift:333` (egg→drop stage change) | N/A for evolution-triggering purposes — this call persists a stage transition that already happened via a separate path (hatching), not an XP award that might cross a threshold |

**Practical effect:** treat-feeding (a menu/touch action that awards 1–2
XP) can push `totalXP` across a stage threshold without triggering the
evolution ceremony immediately — the creature won't visibly evolve until
the *next* commit arrives and calls the fully-paired path. This is a real,
narrow gap (not a hypothetical), first surfaced during this migration
wave — not something to silently "fix" in this doc (DOCS WIN means the
concept states current shipped behavior; the fix, if wanted, is a code
change for the Orchestrator/backlog to schedule, not a doc call).

# Newly Discovered This Wave

Two additional pitfalls surfaced verifying `build.sh`/`run.sh` and the
`commits` table, neither previously documented anywhere in this bundle's
sources:

- **`./run.sh` double-launch** — running `run.sh` without `--no-build` when
  `/Applications/Pushling.app` already exists launches two Pushling
  processes (one via `build.sh`'s own deploy step, one via `run.sh`'s own
  explicit `open build/Pushling.app`). Full detail in
  [build, run, and deploy](/OPERATIONS/build-run-deploy.md).
- **`commits` table client/schema mismatch** — `StateCoordinator.swift`'s
  `MutationQueryProvider` conformance queries `commits.language` (singular)
  and `commits.has_tests`, neither of which exist on the table (the real
  columns are `languages`, plural, and there is no `has_tests` column at
  all). These queries fail silently via a `try?` fallback to `0`/`[]`/`false`
  rather than crashing. Full detail in
  [the schema concept](/DATA_MODELS/state-database-schema.md).

# Citations

[1] `pushling/CLAUDE.md` — Critical Knowledge: What to Watch For; State & evolution
[2] `Pushling/Sources/Pushling/App/GameCoordinator.swift`, `GameCoordinator+Loading.swift`, `GameCoordinator+MenuActions.swift`, `GameCoordinator+Hatching.swift`
[3] `Pushling/Sources/Pushling/State/StateCoordinator.swift` (`MutationQueryProvider`)
[4] `hooks/*.sh` (per-hook performance-budget header comments)
[5] `Pushling/Sources/Pushling/IPC/SessionManager.swift` (idle-gradient thresholds — see [MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md))
