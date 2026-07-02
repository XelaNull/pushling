---
type: Reference
title: SP2b Traceability — mcp-server, state schema, OPERATIONS
description: Source-to-concept mapping for Wave SP2b (WO-1 OKF migration) — proves zero fidelity loss across the six SP2b concepts.
status: Current
tags: [okf-migration, traceability, wave-sp2b]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP2b authored six concepts:
[mcp-server](/SYSTEMS/mcp-server.md),
[state-database-schema](/DATA_MODELS/state-database-schema.md),
[build-run-deploy](/OPERATIONS/build-run-deploy.md),
[development-pitfalls](/OPERATIONS/development-pitfalls.md),
[review-focus-areas](/OPERATIONS/review-focus-areas.md), and
[persistence-and-recovery](/OPERATIONS/persistence-and-recovery.md).

"Deferred" means the source section is real content that belongs in the
final bundle but is out of this wave's assigned scope — routed to the wave
that owns that subject, not a fidelity loss. Deferred sections were read for
context only; nothing from them was lifted as truth into an SP2b concept.

# pushling/CLAUDE.md (assigned: Essential Commands, Critical Knowledge table, State & evolution bullets, Review Focus Areas, Code Quality)

| Source section | → Target concept#section | Status |
|---|---|---|
| Essential Commands (build.sh/run.sh/reload.sh/install.sh, Swift/npm commands, `.build-version` → `PushlingVersion.swift` rule) | `build-run-deploy.md` (all sections) | migrated, extended — added two code-verified behaviors not in the source: the `run.sh` double-launch case and the in-app `LaunchAgentManager` toggle as an alternate install path |
| Critical Knowledge: What to Watch For (15-row pitfall table) | `development-pitfalls.md#the-pitfall-table` | migrated verbatim (Pattern/Problem/Solution columns preserved), each row annotated with a code-verification note; one row (Claude Code hook latency) refined rather than merely repeated — see the Adjudications in this wave's return |
| State & evolution bullets (XP column name, `persistXPAndStage`/`checkEvolution` pairing rule, hot-reload directory-watch note) | `development-pitfalls.md` (XP row + its "Refinement" section), `persistence-and-recovery.md#hot-reload-hotreloadmonitor` | migrated, corrected — the "after every persist" claim for `checkEvolution()` is only true at one of three call sites; documented as a real, narrow gap rather than restated as an absolute rule |
| Review Focus Areas (5 diagnose tracks, polish GAME-BALANCE/CONCURRENCY, spec-check rule) | `review-focus-areas.md` (all sections) | migrated |
| Code Quality (500-line ceilings for TS/Swift) | `review-focus-areas.md#code-quality` | migrated, verified against actual line counts — TypeScript compliant (max 490 lines); Swift has 29 files exceeding 500 lines, a real current gap flagged rather than silently repeated as satisfied policy |
| Two-Instance Coordination, safety carveouts, message format (all coordination-protocol content) | *(not this wave)* | dropped-with-justification — session/process meta-content about how Samantha/Monk coordinate, not knowledge about the Pushling system itself; out of scope for an OKF concept about the product |

# mcp/README.md (assigned: mcp-server seed; the README itself stays `keep-as-is` per the survey — not archived)

| Source section | → Target concept#section | Status |
|---|---|---|
| Transport — stdio, stderr-only logging | `mcp-server.md#process--transport` | migrated, verified — grep-confirmed zero `console.log`/`process.stdout.write` calls anywhere in `mcp/src/` |
| Architecture — two channels, degraded mode | `mcp-server.md#two-channel-client`, `#degraded-mode` | migrated (implementation-detail layer only — the architecture-level channel table itself is [system-architecture.md](/ARCHITECTURE/system-architecture.md)'s authority, cross-linked rather than repeated) |
| The 9 Tools table (Requires-Daemon column) | *(not this wave)* | deferred — fully owned by [the tool contract](/ARCHITECTURE/mcp-tool-contract.md) (SP2a); not repeated here |
| Setup, Register with Claude Code, Development commands | `mcp-server.md#registration`, `#startup--shutdown-sequence` | **re-included, diverging from SP2a's disposition** — SP2a's traceability dropped this whole block as "operator onboarding, not canon." This wave judged the two `claude mcp add` registration forms (prod vs. dev) specifically to be legitimate prescriptive knowledge — picking the wrong one is a real gotcha, not just README fluff — and included it in `mcp-server.md`'s Registration section. The `npm run {build,start,dev}` script names were kept as a one-line citation, not restated as prose. Flagged here explicitly for Samantha's sign-off rather than silently duplicating past SP2a's call |
| File Structure tree | *(none)* | dropped-with-justification, same reasoning as SP2a — directory listing is derivable from the repo and already known-stale (missing 4 helper files); not worth re-freezing |

# PUSHLING_VISION.md (assigned: Installation, Technical Performance, State Persistence sections)

| Source section | → Target concept#section | Status |
|---|---|---|
| Architecture: State Persistence (directory listing, WAL mode, single-writer/multi-reader) | *(already migrated)* | **already fully covered** — SP2a's traceability shows this exact section migrated to `system-architecture.md#state-persistence`. This wave's `persistence-and-recovery.md` builds on top of that (heartbeat/backup/hot-reload *mechanism* detail that the one-paragraph Vision section never contained), cross-linking back to `system-architecture.md` rather than re-migrating the same directory tree a second time |
| Installation (brew/npm install commands, `pushling` CLI subcommands, "replaces the system Touch Bar" note) | `build-run-deploy.md#binpushling--standalone-operator-cli`, `#formulapushlingrb--homebrew-cask-not-yet-publishable` | migrated, **corrected from an initial wrong assumption during this wave** — early in verification this row was drafted as "100% aspirational, no CLI/cask exist"; a direct repo check found that is false. `bin/pushling` (~660 lines) and `bin/pushling-voice-setup` (~500 lines) are fully-implemented, non-stub scripts implementing nearly every subcommand the Vision doc lists, and `Formula/pushling.rb` is a real (if unpublishable — placeholder `sha256`, no matching GitHub release, and it expects Resources paths `build.sh` doesn't populate) Homebrew cask. Documented in `build-run-deploy.md` as real-but-unwired operator tooling (the CLI) and a not-yet-publishable distribution mechanism (the cask) respectively — the `npm install -g pushling` form specifically remains unverified/likely-aspirational (no `bin` entry in `mcp/package.json`, no npm publish config), noted as such rather than asserted either way |
| Technical Performance (per-frame budget table, texture memory, voice model memory) | `development-pitfalls.md` (SpriteKit-node-budget pitfall row, citing the table) | migrated by reference — the full budget table itself already exists verbatim in `PUSHLING_VISION.md` and is cited, not re-transcribed a second time, since no SP2b concept is the natural single authority for a cross-cutting performance-budget table (a future ARCHITECTURE or REFERENCE concept is the better home — flagged for the Orchestrator/SP8, not claimed as covered) |

# docs/archive/plan/phase-1-foundation/PHASE-1.md (background source per the brief; substantively verified against, not just skimmed)

| Source section | → Target concept#section | Status |
|---|---|---|
| P1-T2-01 through P1-T2-06d (pragmas, all v1 tables) | `state-database-schema.md` (Connection Facts + per-table sections) | background-verified, corrected — `StateManager` class name is stale (no such type exists; shipped classes are `DatabaseManager` + `StateCoordinator`), corrected throughout rather than propagated |
| P1-T2-07 (migration system), QA gate's "12 tables" framing | `state-database-schema.md#migration-history` | background-verified, corrected — schema now has 16 domain tables (17 incl. `schema_version`) across 8 migrations, not the 12-table v1 snapshot |
| P1-T2-02's `xp_to_next_stage` spec ("computed, no default") | `state-database-schema.md` (creature table, historical note) | background-verified, corrected — shipped column carries `DEFAULT 100` directly; documented as the historical divergence it is, not silently overwritten |
| P1-T2-08 (crash recovery), P1-T2-09 (daily backup system) | `persistence-and-recovery.md` (Heartbeat & Crash Detection, Daily Backups) | background-verified, corrected — class names updated to the shipped `HeartbeatManager`/`BackupManager`; mechanism details (30s cadence, VACUUM INTO, 30-day retention, 1-hour retry) all directly confirmed against source, not carried over from the plan doc uncritically |
| P1-T1-01 (Xcode project claim, empty-directory snapshot) | *(not migrated)* | dropped-with-justification — explicitly superseded per the survey's own driftSignal (no `.xcodeproj` exists; SPM package is the shipped form); this is scaffolding-era history, not schema/persistence content this wave owns |

# Citations

[1] `pushling/CLAUDE.md`
[2] `mcp/README.md`
[3] `PUSHLING_VISION.md`
[4] `docs/archive/plan/phase-1-foundation/PHASE-1.md`
