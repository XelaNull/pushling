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
  connections), SQLite contention (WAL single-writer/multi-reader — see
  [persistence and recovery](/OPERATIONS/persistence-and-recovery.md)), and
  audio-thread safety (TTS generation must stay off the render thread, per
  [the development pitfalls](/OPERATIONS/development-pitfalls.md)'s TTS
  preload row).

# `spec-check` Rule

Diff directly against `PUSHLING_VISION.md` (now absorbed into this OKF
bundle per Ruling R4 — see the migration's traceability records) — it is
the single source of truth for growth stages, personality axes, emotional
state, the surprise catalogue, and the embodiment tool contract. There is
no separate audit-category checklist maintained in parallel; a `spec-check`
run should compare the codebase against the relevant bundle concepts
(growth-stages, personality, the surprise catalog, the tool contract) that
now carry that content, not against the raw file.

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
