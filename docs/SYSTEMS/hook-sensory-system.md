---
type: System
title: Hook Sensory System
description: The creature's senses outside of MCP tool calls — 7 Claude Code hooks plus the git post-commit hook, their shared library contract, latency budgets, and the two independent batching mechanisms that prevent event floods.
status: Live
tags: [hooks, sensory, embodiment]
timestamp: 2026-07-02T00:00:00Z
---

**Corrected count: 7 Claude Code hooks + 1 git hook = 8 hook scripts total**,
not the "9 Claude Code hooks" some drift-affected copies of `README.md`
claim, and not the "8 Claude Code hooks" some other stale counts imply
either. `hooks/install.sh` registers exactly 7 Claude Code hook events
(`SessionStart`, `SessionEnd`, `PostToolUse`, `UserPromptSubmit`,
`SubagentStart`, `SubagentStop`, `PostCompact`); `hooks/post-commit.sh` is a
git hook, installed separately into a tracked repo's `.git/hooks/`, not via
Claude Code's hook registration mechanism at all. Both figures are
grep-verified against `hooks/*.sh` (8 files) — this concept is the corrected
authority for that count.

# The Shared Library Contract

Every hook except `post-commit.sh` sources `hooks/lib/pushling-hook-lib.sh`
directly (`post-commit.sh` resolves the lib path defensively across several
possible install locations, since it runs from inside `.git/hooks/` in an
arbitrary tracked repo, and falls back to a minimal inline reimplementation
of `pushling_emit`/`pushling_signal` if it can't find the real library at
all). The library's safety contract, stated in its own header and
code-verified:

- **Never exits non-zero** — a global `trap` on `ERR` returns/exits 0 from
  wherever the error occurred.
- **Never prints to stdout** (except `session-start.sh`, which sets
  `PUSHLING_ALLOW_STDOUT=1` before sourcing the library — see
  [the awakening pipeline](/SYSTEMS/awakening-pipeline.md)) **or stderr**
  (the library `exec 2>/dev/null`s itself for the whole sourcing script
  unless `PUSHLING_DEBUG` is set).
- **All socket operations timeout in <50ms** (`PUSHLING_SIGNAL_TIMEOUT=0.05`
  by default) — `pushling_signal` fires a backgrounded `nc -U` (or `socat`
  fallback) at the daemon socket and kills it after the timeout if it hasn't
  returned, so a hung or non-responding daemon can never block the caller.
- **All file writes are atomic** — temp file (`.tmp_<filename>`), then `mv`
  to the final feed filename. The filename itself follows a fixed
  convention, `pushling_emit()`'s `${timestamp_ms}_${hook_type}.json`
  (`hooks/lib/pushling-hook-lib.sh:160`) — e.g.
  `1751500000123_PostToolUse.json` — matching the archived
  `docs/archive/plan/phase-4-embodiment/PHASE-4.md` P4-T3-01 spec exactly.
  The git hook's counterpart uses `{short_sha}.json` instead (see
  [commit feeding & XP](/SYSTEMS/commit-feeding-xp.md)).
- **Silent success when the daemon is down** — `pushling_signal` no-ops
  immediately if `/tmp/pushling.sock` isn't a live socket file; the JSON is
  still written to the feed directory and picked up on the daemon's next
  launch.
- **bash 3.2+ compatible** (macOS's shipped default) — no bashisms beyond
  what 3.2 supports.

Provided functions: `pushling_emit(hook_type, json_data)` (writes the full
`{"type":"hook","hook":...,"timestamp":...,"data":...}` envelope + signals),
`pushling_signal(hook_type)`, `pushling_timestamp()` /
`pushling_timestamp_ms()`, `pushling_json_escape(string)`,
`pushling_ensure_feed_dir()`, plus read-only SQLite helpers
(`pushling_db_query`, `pushling_creature_field`) and
`pushling_daemon_running()`.

# Latency Budgets — Per-Hook, Not Uniform

The budget is **not** a single flat number across all hooks; it is
stricter for the six hooks with no I/O beyond writing a small JSON file, and
relaxed for the two hooks that do real work:

| Hook | Stated Budget | Why |
|---|---|---|
| `post-tool-use.sh`, `user-prompt-submit.sh`, `subagent-start.sh`, `subagent-stop.sh`, `post-compact.sh`, `session-end.sh` | **<50ms** | No SQLite read; just JSON construction + `pushling_emit` |
| `session-start.sh` | **<100ms** | Includes a synchronous `sqlite3 -readonly` read of the `creature` and `world` tables plus recent-commits/journal queries |
| `post-commit.sh` (git hook, not a Claude Code hook) | **<100ms** | Includes several `git` subprocess calls (`rev-parse`, `log`, `diff-tree`, `rev-list`, `tag`) in addition to JSON construction |

This resolves an apparent contradiction in the source material:
`PUSHLING_VISION.md` and `pushling/CLAUDE.md` each state a single number
(<100ms and <50ms respectively) as if it applied uniformly. Both are
half-right — <50ms is the per-hook comment in six of the eight scripts
(grep-verified in each file's own header), and <100ms is the number stated
in `session-start.sh` and `post-commit.sh`'s own headers, plus the shared
library's overall "total execution budget" comment. The per-hook table
above is the disambiguated, code-verified truth.

# The 7 Claude Code Hooks

| Hook | Fires When | Data Captured | Daemon Reaction (Reflex priority) |
|---|---|---|---|
| **SessionStart** | Claude Code session begins | Full creature + world state (read from SQLite, output to stdout — see [the awakening pipeline](/SYSTEMS/awakening-pipeline.md)) | Diamond materializes; ear-perk reflex |
| **SessionEnd** | Session closes | `duration_s`, `reason` (`clean`/`timeout`/`error`) | Diamond dissolves over 5s; long session (>1hr) gets a grateful slow-blink first |
| **PostToolUse** | Any tool call completes | `tool` name, `success` bool, `duration_ms`; own burst-batching flag/count (see below) | Success: tail-twitch + ear-perk. Failure: ears flat, eyes squint, body flinch (`handlePostToolUse` in `HookEventProcessor.swift`) |
| **UserPromptSubmit** | Developer sends a message to Claude | `prompt_length` only — **content is never captured, by design** | Ears-forward attentive posture (1.2s); prompts >500 chars additionally trigger a look-at-touch reflex |
| **SubagentStart** | Claude spawns subagent(s) | `subagent_count` | Diamond splits (max 5 nodes); eyes widen; 3+ subagents also trigger a startle reflex |
| **SubagentStop** | Subagent(s) complete | `subagent_count`, `remaining` | Diamonds reconverge; `remaining == 0` triggers an approving nod |
| **PostCompact** | Claude's context window is compacted | `{}` (signal only, no payload data) | Head-shake/daze/rapid-blink reflex, ~3.5s (`handlePostCompact` in `HookEventProcessor.swift`) |

All seven are dispatched daemon-side by `HookEventProcessor.handleHookEvent`,
which is also where every hook event (whether individually animated or
suppressed by batching) is pushed into the
[pending-events ring buffer](/ARCHITECTURE/pending-events.md) as a
`type: "hook"` entry — every hook is visible to Claude on its next tool
call, not just the ones that produce a visible reflex.

**Not built — richer per-hook reaction designs from `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
that never shipped**, grep-verified absent from the current handler bodies
(`handlePostToolUse`, `handlePostCompact`, `onSessionEnded` in
`SessionLifecycleReactions.swift`) rather than assumed missing:

- **PostToolUse (P4-T3-04):** the design specified tool-specific reactions
  beyond the generic success/failure pair above — a Bash test pass
  triggering a flex, a file edit briefly showing a file icon, a long tool
  chain (5+ tools) producing an increasingly impressed expression, and 3+
  repeated failures triggering concerned pacing. `handlePostToolUse` only
  ever branches on the boolean `success` field; none of `tool`'s value,
  consecutive-failure counting, or a chain-length counter feed into the
  reaction logic at all — the design's tool-name/streak-aware vocabulary
  is unbuilt.
- **PostCompact (P4-T3-07):** the design specified a stage-gated spoken
  line, `"...what was I thinking about?"`, appearing only at Beast+ stage
  — framed explicitly as "the creature shares Claude's context loss —
  solidarity." `handlePostCompact` triggers the daze reflex only; no
  `SpeechCoordinator`/speak call exists in that function or anywhere else
  triggered by a `PostCompact` hook. The solidarity *intent* survives in
  the daze/rapid-blink choreography; the speech half never shipped.
- **SessionEnd (P4-T3-03):** the design specified a short-session (<5min)
  branch — "brief confused look, then shrug" — distinct from the long-session
  (>1hr) grateful slow-blink that did ship (see
  [MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md#disconnect-clean-vs-abrupt)).
  `SessionLifecycleReactions.onSessionEnded()`'s `.clean` branch only
  checks `duration > 3600`; there is no `duration < 300` branch or shrug
  reaction anywhere in the file.

# Two Independent Batching Mechanisms

There are genuinely **two separate batching systems** operating at two
different layers, with two different windows — this is not a contradiction
to resolve, both exist and both run simultaneously on `PostToolUse` events:

1. **Hook-side pre-filtering (`post-tool-use.sh` itself).** A 10-second /
   3-tool-threshold state machine (`PUSHLING_BURST_WINDOW=10`,
   `PUSHLING_BURST_THRESHOLD=3`) tracked in a state file
   (`.tool_burst_state`) inside the feed directory. Below the threshold,
   every tool call emits its own individual `PostToolUse` JSON. At or above
   the threshold, the hook only emits a JSON file at each multiple of 3
   (3rd, 6th, 9th... tool call), tagged `"burst":true,"burst_count":N`, and
   silently drops the ones in between — this reduces the *number of files
   written to the feed directory* during a rapid tool chain.
2. **Daemon-side reflex suppression (`HookBatchTracker` in
   `FeedTypes.swift`).** A separate, shorter 2-second / 3-hook-threshold
   window that runs on *every* hook type the daemon processes (not just
   `PostToolUse`), independent of whatever the hook script already did to
   its own file count. Once 3+ hook events of any kind arrive within 2
   seconds, `isInBurstMode` flips on and individual per-event reflex
   animations (ear-perk, nod, wince) stop firing in favor of a single
   sustained "watching Claude work" reflex (`triggerWatchingClaudeWork`,
   ~4s) — this is a visual-load control, not a feed-file control.

Net effect during a fast tool chain: fewer feed files are written (layer 1)
*and* the ones that do arrive collapse into one sustained animation instead
of a flicker of individual reactions (layer 2). `PHASE-4.md`'s "2 seconds"
figure and `PUSHLING_VISION.md`/`EMBODIMENT-REVIEW.md`'s "10 seconds"
figure are not in conflict — they are each describing one of the two real,
independently-running mechanisms.

# Git Hook Constraint: Never Modify the Commit

`post-commit.sh` runs strictly after `git commit` has already written the
commit object — it observes (`rev-parse`, `log`, `diff-tree`) and reports,
never amends. This is an explicit rule from `pushling/CLAUDE.md`'s Git Hook
Rules ("Never modify the commit itself"), not just an implication of the
hook running post-commit: `hooks/post-commit.sh` never invokes `git commit
--amend`, `git filter-branch`, or any other commit-mutating command, and
the shared library contract above (never exits non-zero, never blocks) is
itself in service of this constraint — a hook that could fail loudly or
hang would tempt a "let me just fix it up" commit-mutating fallback, which
this design deliberately forecloses.

# Daemon-Side Processing

`HookEventProcessor` watches `~/.local/share/pushling/feed/` via a
`DispatchSource` on the directory (FSEvents-backed, near-instant) with a
2-second polling-timer fallback in case the FSEvents path is unavailable.
Each JSON file is parsed, dispatched by its `type` field (`"hook"` or
`"commit"`), and — regardless of outcome, including malformed JSON — moved
to `feed/processed/`. A separate hourly cleanup timer deletes anything in
`processed/` older than 24 hours, so the directory never grows unbounded.
Commit-specific processing (XP, eating reaction) is documented in
[commit feeding & XP](/SYSTEMS/commit-feeding-xp.md), not here.

# Citations

[1] `docs/archive/EMBODIMENT-REVIEW.md` §5 (The Sensory Loop: Hooks)
[2] `docs/archive/plan/phase-4-embodiment/PHASE-4.md` Track 3 (P4-T3-01..09)
[3] `hooks/lib/pushling-hook-lib.sh`, `hooks/{session-start,session-end,post-tool-use,user-prompt-submit,subagent-start,subagent-stop,post-compact}.sh`, `hooks/install.sh`
[4] `Pushling/Sources/Pushling/Feed/HookEventProcessor.swift`, `Pushling/Sources/Pushling/Feed/FeedTypes.swift`
[5] `Pushling/Sources/Pushling/IPC/SessionLifecycleReactions.swift` (`onSessionEnded`)
[6] `pushling/CLAUDE.md` — Git Hook Rules ("Never modify the commit itself")
