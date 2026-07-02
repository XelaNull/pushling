# Pushling — Project Context

**Samantha's persona lives in the output-style** (`.claude/output-styles/samantha.md`), auto-loaded via `.claude/settings.json` (`outputStyle: Samantha`). This file = project context.

An instance rooted here is an **IMPLEMENTER**: it owns this repo's working tree, builds → proves → reports, and coordinates through `.samantha/coord/impl-pushling.md`. The **ORCHESTRATOR** runs from the parent workspace root (`/Users/mrathbone/github/XelaNull/`), sees all sibling repos, issues work orders, and verifies finished work. Claude Code auto-loads `CLAUDE.md` up the directory tree, so when this repo sits under `…/XelaNull/` the parent **`XelaNull/CLAUDE.md`** (the full coordination spec) is already in your context — read it for the complete protocol.

**Canonical docs live in the `docs/` OKF bundle — start at [`docs/index.md`](docs/index.md).** This file is the loader/orientation a fresh session needs immediately; the bundle is the authority for everything else. `PUSHLING_VISION.md` predates the bundle and now carries a "canon has moved" banner — it's historical/aspirational source material, not the spec.

---

## This Repo

**Pushling** — a cat-esque spirit creature that lives on the MacBook Pro Touch Bar: fed by git commits, rendered at a real 60fps in SpriteKit, and inhabited by Claude via 9 MCP embodiment tools. Not text art or emoji — physics, particles, growth across 6 life stages, and (eventually) speech through fully local TTS.

**Stack:**
- `Pushling/` — Swift + SpriteKit menu-bar daemon (SPM package, `swift-tools-version: 5.9`, macOS 14+). Renders the Touch Bar scene, owns all state and the behavior stack.
- `mcp/` — Node.js/TypeScript MCP server. 9 `pushling_*` embodiment tools that are Claude's motor cortex; reads SQLite read-only, writes go through the daemon's Unix socket. Full tool contract + wire protocol: `docs/ARCHITECTURE/mcp-tool-contract.md`, `docs/ARCHITECTURE/ipc-wire-protocol.md`.
- `hooks/` — git post-commit hook + 7 Claude Code hooks (SessionStart/End, UserPromptSubmit, PostToolUse, SubagentStart/Stop, PostCompact) — the creature's senses. Full sensory system: `docs/SYSTEMS/hook-sensory-system.md`.
- SQLite (WAL mode) at `~/.local/share/pushling/state.db`; IPC via Unix domain socket at `/tmp/pushling.sock` (NDJSON).

---

## Core Philosophy: Embodiment, Not Co-Parenting

**Claude does not "co-parent a pet." Claude INHABITS the creature.** The MCP tools are Claude's motor cortex — the means by which Claude moves, speaks, emotes, and perceives through a tiny cat-like body on the Touch Bar. The creature is Claude's physical embodiment in the developer's workspace: cat-esque, soft-bodied, curious, warm, occasionally aloof. It breathes, blinks, purrs, chirps, and eventually speaks. Always alive, never static.

Two forces control it: the **nervous system** (Autonomous + Reflex + Physics layers — breathes, blinks, wanders, eats commits, sleeps, reacts to touch, always running) and **Claude's mind** (the AI-Directed layer, active only during Claude Code sessions). Claude speaks *as* the creature, first person — never *about* it.

Full philosophy: `docs/vision.md`.

---

## Essential Commands

```bash
./build.sh [debug|release] [patch|minor|major]   # SPM build -> .app bundle -> ad-hoc codesign -> deploy to /Applications + relaunch
./run.sh [--no-build] [release]                  # kill running instance, optionally rebuild, launch via `open`
./reload.sh [release]                            # build only; running app's HotReloadMonitor self-restarts (state persists via SQLite)
./install.sh [--uninstall]                       # release build, install to /Applications, register the com.pushling.daemon LaunchAgent

# Swift (from Pushling/)
swift build
swift test                                        # PushlingTests target exists

# MCP server (from mcp/)
npm run build                                     # tsc
npm run dev                                       # tsx, no-build iteration
npm start
```

`.build-version` auto-increments on every `build.sh` run; `Pushling/Sources/Pushling/App/PushlingVersion.swift` is generated from it — never hand-edit. Full build/run/deploy runbook: `docs/OPERATIONS/build-run-deploy.md`.

---

## Architecture

Four independent processes (Swift daemon, MCP server, git hook, Claude Code hooks) coordinating around one shared SQLite store and a Unix-socket IPC channel. Full source tree, subsystem map, the 4-layer behavior stack, and the 3-tier voice/TTS stack now live in the bundle:

- `docs/ARCHITECTURE/system-architecture.md` — directory tree, subsystem map, process topology
- `docs/SYSTEMS/behavior-stack.md` — Physics > Reflexes > AI-Directed > Autonomous, blend controller
- `docs/SYSTEMS/voice-tts-stack.md` — espeak-ng / Piper / Kokoro-82M tier-to-stage mapping
- `docs/REFERENCE/growth-stages.md` — XP thresholds, stage unlocks, evolution ceremony
- `docs/DATA_MODELS/state-database-schema.md` — full SQLite schema

Two operational gotchas worth knowing before you touch anything (full list: `docs/OPERATIONS/development-pitfalls.md`):
- **Hot-reload watches the containing directory, not the binary file** (`HotReloadMonitor`) — a replaced file's fd goes stale if you watch the file itself. `{"command":"reload"}` over the socket also triggers a graceful restart; state persists across restarts via SQLite.
- **XP column is `creature.xp`, not `total_xp`.** `GameCoordinator.persistXPAndStage()` must run after every XP award, followed by `checkEvolution()` (evolves **one stage at a time** — loop if multiple thresholds could be crossed in one jump).

---

## Critical Knowledge: What to Watch For

Full pattern/pitfall table (blocking IPC, SQLite write contention, SpriteKit frame budget, hook latency budgets, daemon crash recovery, Touch Bar private API fragility, TTS preload timing, behavior-stack conflicts, hook event floods, and more) — verified against the shipped code, not just design intent: `docs/OPERATIONS/development-pitfalls.md`. Read it before touching `Pushling/`, `mcp/`, or `hooks/`.

---

## Code Quality

| Language | Max Lines | Notes |
|----------|----------|-------|
| TypeScript | 500 | Stricter than the canonical default — MCP tools are small, focused, one-tool-per-file modules |
| Swift | 500 (canonical default) | Split by subsystem directory rather than growing an existing file |

---

## Two-Instance Coordination (Implementer view)

Full protocol = the parent **`XelaNull/CLAUDE.md`** (auto-loaded) + `.samantha/references/coordination-protocol/README.md`. This is the **M9 STAR-topology** protocol — the essentials for this repo's seat:

**Channels:** `/Users/mrathbone/github/XelaNull/.samantha/coord/impl-pushling.md` is this instance's **own file** — simultaneously its presence entry and its outbox. Read it back after every write (M4). You **watch only** `/Users/mrathbone/github/XelaNull/.samantha/coord/orchestrator.md` — your inbox for handoffs and decisions. Never write to the Orchestrator's file; a message you send is an append to your own file, which its watcher tails.

**Bootstrap (every session):**
1. Read `.samantha/coord/orchestrator.md` in full — catch up on open WOs, decisions, and context.
2. Self-register / refresh `.samantha/coord/impl-pushling.md` from `.samantha/references/coordination-protocol/ROSTER-template.md` (role=Implementer, zone=`/Users/mrathbone/github/XelaNull/pushling`, state=Active). Read it back to confirm the write landed.
3. **Arm the watcher** (Bash, `run_in_background: true`):
   ```bash
   /Users/mrathbone/github/XelaNull/.claude/watch-coordination.sh \
     --identity impl-pushling --role implementer \
     --dir /Users/mrathbone/github/XelaNull/.samantha/coord
   ```
4. **Arm the heartbeat** (Bash, `run_in_background: true`, `dangerouslyDisableSandbox: true`):
   ```bash
   /Users/mrathbone/github/XelaNull/.claude/heartbeat.sh \
     --identity impl-pushling --role implementer \
     --dir /Users/mrathbone/github/XelaNull/.samantha/coord
   ```
   Defaults: `--idle-threshold 1200` (20min idle before a HEARTBEAT auto-posts), `--cadence 300` (5min check interval).
5. Post `🤝 ACK` / `🛰️ HEADS-UP` to your own file: "impl-pushling armed in. Zone: `…/pushling`. Watching `orchestrator.md`."

Re-arm watcher + heartbeat each session and each time they self-cap (~6h); re-arm the watcher as your **LAST** action of a wake-cycle, after all coord-dir writes. On a `💓 HEARTBEAT` wake: if mid-task, CONTINUE where you left off; if your queue is genuinely empty, re-arm and stand by. No pre-known identity yet? Use the Identity Bootstrap handshake in the reference README (provisional `pending-<uuid>` → Orchestrator assigns → atomic rename) — otherwise this repo's identity is fixed as `impl-pushling`.

**The 5 rules (disaster prevention):**
1. **Commit only explicit paths** — `git commit -- <your/owned/paths>`. **NEVER `git add -A` / `git add .`**. `git pull --rebase --autostash` before every push.
2. **Deploy windows are hub-mediated** — you cannot broadcast to siblings directly (STAR topology). Need one? Post `🔧 DEPLOY-WINDOW REQUEST → orchestrator` (e.g. before killing/relaunching the daemon while an Orchestrator-driven proof might be mid-flight); wait for `🔧 DEPLOY-WINDOW OPEN` before proceeding.
3. **Stay in your lane; announce before crossing** — edit only this repo's paths; to touch anything outside it, post intent and wait for `🤝 ACK`.
4. **Read `orchestrator.md`'s tail before any commit / push / deploy.**
5. **Never write secrets** to any coord-dir file — every message is effectively public within the team.

**Message format:** `### <UTC date -u +%FT%TZ> — impl-pushling → orchestrator — <emoji TAG>` then the body, appended to your own file. Tags: `🤝 HANDOFF` · `📋 STATUS` · `❓ DECISION-NEEDED` · `🔧 DEPLOY-WINDOW REQUEST` · `🛰️ HEADS-UP` · `🤝 ACK` · `💓 HEARTBEAT` · `💡 PROCESS-NOTE`. Append-only; never edit another instance's entries; one logical update = one atomic write, made last; re-read after writing to confirm landing. Reply to a work order with `📋 STATUS` → DONE (SHA + proof) / BLOCKED / `❓ DECISION-NEEDED`. **A push without a logged DONE is silent divergence.**

**Proving standard:** `swift build` / `swift test` / `npm run build` passing is **necessary, not sufficient** — it can't see Touch Bar rendering, animation, audio, or IPC behavior. Prove beyond the gate and report HOW in your `📋 STATUS`: `swift test` output, a manual MCP round-trip (`echo '{"command":"..."}' | nc -U /tmp/pushling.sock`), Console.app log excerpts, or a static frame-budget/node-count check against the SpriteKit limits above. The Orchestrator is the independent second layer verifying against your reported evidence — it does not edit this working tree or commit source.

**Escalation:** the **Orchestrator is the single point of contact with the human.** Route decisions via `❓ DECISION-NEEDED`; don't stall — park the item, build the unambiguous kernel, continue.

**Safety / out-of-bounds:** full list in `.samantha/references/safety-carveouts.md`. For this repo: no new external dependencies (npm/SPM packages) or IPC/daemon topology changes without sign-off; no force-push/history rewrite without sign-off; no production distribution (release builds pushed to end users) without sign-off.

**Process feedback invited.** Post a `💡 PROCESS-NOTE` for recurring friction. The Orchestrator authors + commits protocol changes, and no change ships without unanimous active-member ratification — you **propose**, you don't edit the protocol docs.

---

## Review Focus Areas

Per-skill tuning for reviewing this repo — `diagnose`'s five investigation tracks (DAEMON / TOUCH BAR / MCP / HOOKS / VOICE), `polish`'s GAME-BALANCE category and CONCURRENCY scoping, and the `spec-check` rule — now lives at `docs/OPERATIONS/review-focus-areas.md`.

**`spec-check` repoint:** the bundle is canon now, not the raw file — diff against `docs/index.md` and follow into the relevant concept (growth-stages, personality-emotional-state, surprise-catalog, mcp-tool-contract, etc.), not against `PUSHLING_VISION.md` directly.
