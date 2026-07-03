---
type: Reference
title: Pushling Review Focus Areas
description: Per-skill tuning for reviewing this repo — the five diagnose investigation tracks, the polish extra category and its CONCURRENCY meaning, the spec-check rule, and the code-quality line-length ceilings, verified against current line counts.
status: Live
tags: [review, diagnose, polish, code-quality]
timestamp: 2026-07-02T00:00:00Z
---

This concept migrates `pushling/CLAUDE.md`'s "Review Focus Areas" and "Code
Quality" sections in full — it's a review-process tuning reference, not a
system spec, so most of it isn't "verifiable against code" in the usual
sense. Where a claim *is* checkable (the tool count, the line-length
ceiling), it was checked.

# `diagnose` Investigation Tracks

| Track | What to Check |
|---|---|
| **DAEMON** | Pushling.app running? Heartbeat fresh? Socket accepting connections? Crash logs? |
| **TOUCH BAR** | SpriteKit scene rendering? Touch events flowing? Creature visible and animating? |
| **MCP** | Server registered with Claude? All 9 embodiment tools responding? IPC to the daemon working? |
| **HOOKS** | Claude Code hooks installed and firing? Git hook installed? Feed files being written? |
| **VOICE** | TTS models loaded? Audio output working? Voice tier matching growth stage? No glitches? |

The MCP track's "all 9 embodiment tools" is code-verified — `mcp/src/index.ts`
registers exactly 9 `server.tool(...)` calls
(`sense`/`move`/`express`/`speak`/`perform`/`world`/`recall`/`teach`/`nurture`),
matching [the tool contract](/ARCHITECTURE/mcp-tool-contract.md). The heartbeat
freshness check (DAEMON track) and the hook-firing check (HOOKS track) can be
performed against the mechanisms documented in
[persistence and recovery](/OPERATIONS/persistence-and-recovery.md) — a fresh
heartbeat means `/tmp/pushling.heartbeat`'s `timestamp` is within the last
~30-60s of write cadence.

# `polish` Extra Categories

Beyond the standard DEAD-CODE / PERFORMANCE / ERROR-HANDLING / CONCURRENCY /
CONSISTENCY buckets, this repo adds:

- **GAME-BALANCE** — XP curve, evolution pacing, surprise frequency, voice
  progression. Judgment calls specific to the game-feel of the creature,
  not generic code-quality issues.
- **CONCURRENCY**, scoped specifically to: socket race conditions (the
  daemon's single `SocketServer` handling multiple concurrent MCP/session
  connections — see [the wire protocol's corrected concurrency
  note](/ARCHITECTURE/ipc-wire-protocol.md) for what that actually means
  today), SQLite contention (WAL single-writer/multi-reader — see
  [persistence and recovery](/OPERATIONS/persistence-and-recovery.md)), and
  audio-thread safety (TTS generation must stay off the render thread, per
  [the development pitfalls](/OPERATIONS/development-pitfalls.md)'s TTS
  preload row).

**Severity tags**, restored from `pushling/CLAUDE.md`'s original 6-category
table (lost from the migration without a matrix drop record): DEAD-CODE
(LOW), PERFORMANCE (MED), ERROR-HANDLING (MED), CONCURRENCY (**HIGH**),
CONSISTENCY (LOW), GAME-BALANCE (MED). CONCURRENCY carries the only HIGH —
consistent with it covering the daemon's shared-state surfaces (socket,
SQLite, audio thread) where a bug is a crash or data-loss risk rather than
a code-quality nit.

# `polish` Zone Partitioning (GOLD)

Restored from `pushling/CLAUDE.md`'s "Pushling-Specific GOLD Zone
Partitioning" table — the 5-zone split used to shard a `polish` analyze/fix
wave across parallel Monk instances without file conflicts, superseding
the generic "one Monk agent per zone" guidance in
`.claude/skills/polish/SKILL.md` with this repo's actual zone boundaries:

| Zone | Covers |
|---|---|
| DAEMON | Swift app — scene, creature, world, state, behavior stack |
| VOICE | TTS pipeline — model loading, audio rendering, voice evolution |
| MCP | TypeScript — embodiment tools, IPC client, state queries |
| HOOKS | Claude Code hooks + git hook — event sensing, feed pipeline |
| ASSETS | Textures, sounds, TTS models, configuration |

These five zones map roughly onto `Pushling/Sources/Pushling/{Behavior,Creature,World,State}/`
+ `App/` (DAEMON), `Pushling/Sources/Pushling/Speech/` (VOICE),
`mcp/src/` (MCP), `hooks/` (HOOKS), and non-code assets (ASSETS) — a
`polish` wave assigning one Monk per zone should partition file ownership
along these directory boundaries to avoid two agents editing the same file.

# `spec-check` Rule

Diff directly against `PUSHLING_VISION.md` (now absorbed into this OKF
bundle per Ruling R4 — see the migration's traceability records) — it is
the single source of truth for growth stages, personality axes, emotional
state, the surprise catalogue, and the embodiment tool contract. A
`spec-check` run should compare the codebase against the relevant bundle
concepts (growth-stages, personality, the surprise catalog, the tool
contract) that now carry that content, not against the raw file.

**The 15-category checklist itself, restored.** `pushling/CLAUDE.md`'s
"Pushling-Specific VIOLET Audit Categories" table was a fixed decomposition
used to grade the codebase against the vision doc, category by category,
COMPLETE/PARTIAL/SKELETAL/MISSING. This concept previously said "there is
no separate audit-category checklist maintained in parallel" as if the
15-way decomposition itself had been superseded — that was an overstatement
never recorded as an intentional drop in `docs/archive/traceability-matrix.md`.
The decomposition is still a useful `spec-check` starting checklist; it's
restored below with its two stale numeric claims corrected against current
canon rather than left wrong:

| # | Category | What to Check | Current Canon |
|---|---|---|---|
| 1 | Growth Stages | All 6 stages with correct thresholds, visuals, behaviors | [growth-stages.md](/REFERENCE/growth-stages.md) |
| 2 | Personality | 5 axes calculated from git patterns, affecting creature behavior | [personality-emotional-state.md](/REFERENCE/personality-emotional-state.md) |
| 3 | Emotional State | 4 axes with emergent states, circadian cycle | [personality-emotional-state.md](/REFERENCE/personality-emotional-state.md) |
| 4 | World | Parallax, weather, biomes, repo landmarks, day/night | [world-terrain-parallax.md](/SYSTEMS/world-terrain-parallax.md), [weather.md](/SYSTEMS/weather.md), [biomes-and-terrain-objects.md](/REFERENCE/biomes-and-terrain-objects.md) |
| 5 | Commit Feeding | XP formula, reactions, rate limiting, fallow bonus | [commit-feeding-xp.md](/SYSTEMS/commit-feeding-xp.md) |
| 6 | Touch Input | All gesture types handled, creature responds to each | [touch-input-pipeline.md](/SYSTEMS/touch-input-pipeline.md), [gesture-response-map.md](/REFERENCE/gesture-response-map.md) |
| 7 | MCP Tools | All 9 `pushling_*` tools working with error handling | [mcp-tool-contract.md](/ARCHITECTURE/mcp-tool-contract.md) |
| 8 | Surprises | **78** surprises implemented with scheduling system — the original table said "30 surprises," stale against the shipped catalog; corrected here | [surprise-catalog.md](/REFERENCE/surprise-catalog.md) |
| 9 | Journal | All entry types recorded, surfaced through dreams/display/MCP | [journal-and-dreams.md](/REFERENCE/journal-and-dreams.md) |
| 10 | Teach Mechanic | Tricks taught via MCP appear in idle rotation | [teach-system.md](/SYSTEMS/teach-system.md) |
| 11 | Voice/TTS | Three-tier progression, voice evolution matches growth, audio quality | [voice-tts-stack.md](/SYSTEMS/voice-tts-stack.md) |
| 12 | Hooks Integration | All 7 Claude Code hooks firing, event flow to daemon, creature reacting | [hook-sensory-system.md](/SYSTEMS/hook-sensory-system.md) |
| 13 | Behavior Stack | 4-layer stack (Physics/Reflexes/AI-Directed/Autonomous) with blend controller | [behavior-stack.md](/SYSTEMS/behavior-stack.md) |
| 14 | Embodiment | Claude can move/speak/emote/perceive as the creature, session lifecycle works | [embodiment.md](/SYSTEMS/embodiment.md), [mcp-session-lifecycle.md](/ARCHITECTURE/mcp-session-lifecycle.md) |
| 15 | Creation Systems | `pushling_teach` working, objects system functional, nurture system with organic variation | [teach-system.md](/SYSTEMS/teach-system.md), [world-objects-system.md](/SYSTEMS/world-objects-system.md), [nurture-system.md](/SYSTEMS/nurture-system.md) |

Grades: COMPLETE / PARTIAL / SKELETAL / MISSING, assessed against the
"Current Canon" concept in the right column, not the original vision file.

# Code Quality

| Language | Max Lines | Notes |
|---|---|---|
| TypeScript | 500 | Stricter than the canonical default — MCP tools are small, focused, one-tool-per-file modules |
| Swift | 500 (canonical default) | Split by subsystem directory rather than growing an existing file |

**Verified against the shipped tree:**

- **TypeScript:** every file under `mcp/src/tools/` is currently within
  budget — the largest is `nurture.ts` at 490 lines, `perform.ts` at 486,
  `speak.ts` at 471. The policy is holding in practice.
- **Swift:** **29 files** currently exceed the stated 500-line ceiling,
  ranging from `GestureRecognizer.swift` at 503 lines to
  `PushlingScene.swift` at 950, `GameCoordinator+Loading.swift` at 870, and
  `HatchingCeremony.swift` at 809. This is a real, current gap between the
  stated policy and the codebase, not a hypothetical — surfaced here per
  DOCS WIN rather than silently omitted or silently used to declare the
  policy itself wrong. Whether the right fix is enforcing the split (code
  change) or revising the ceiling (a canon change via `DECISIONS.md` → ADR)
  is a call for the Orchestrator/human, not something this concept resolves
  unilaterally.

# Citations

[1] `pushling/CLAUDE.md` — Review Focus Areas, Code Quality
[2] `mcp/src/index.ts` (9 `server.tool()` registrations)
[3] `find Pushling/Sources -name '*.swift' | xargs wc -l` (line-count verification, this wave)
[4] `find mcp/src/tools -name '*.ts' | xargs wc -l` (line-count verification, this wave)
