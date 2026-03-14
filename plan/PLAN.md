# Pushling Development Plan

## Overview

A phased, component-driven development plan designed for high parallelism. Each phase produces independently testable deliverables. Phases 1-3 can begin simultaneously. Later phases have dependencies but contain parallel tracks within them.

The Pushling is a virtual pet for the MacBook Touch Bar — a cat-esque spirit creature born from git history, rendered at 60fps via SpriteKit, fed by commits, responsive to touch, and periodically inhabited by Claude via MCP. The vision document (`PUSHLING_VISION.md`) specifies 6 growth stages, a 4-layer behavior stack, 9 MCP embodiment tools, 78 surprises, 3 creation systems (teach/objects/nurture), 3-tier TTS voice evolution, 7 Claude Code hooks, and an infinite procedural world with repo landmarks.

## Architecture

The project has 4 codebases:

1. **Swift App** (`Pushling/`) — SpriteKit Touch Bar daemon. Menu-bar app (no dock icon) that takes over the Touch Bar via private `presentSystemModalTouchBar` API. Renders the creature, world, and all interactions at 60fps. Manages state in SQLite (WAL mode). Listens on Unix socket for IPC. Processes commit feed files. Runs Layer 1 autonomy continuously.

2. **MCP Server** (`mcp/`) — Node.js/TypeScript embodiment tools. 9 `pushling_*` tools for Claude to inhabit the creature (Layer 2). Reads state from SQLite (read-only). Sends commands to daemon via Unix socket. Returns `pending_events` on every response.

3. **Hooks** (`hooks/`) — Shell scripts for Claude Code + git hooks. Git post-commit hook writes JSON to feed directory and signals daemon. 7 Claude Code hooks (SessionStart through PostCompact) provide full dev session awareness. SessionStart injects stage-specific embodiment awakening context.

4. **Assets** (`assets/`) — Textures, sounds, TTS models. Creature sprite atlas (composite body parts for independent animation), world terrain tiles, biome objects, weather particles, 60 base shapes + 40 iconic sprites for object system, sound effects, ambient audio, TTS model bundles (espeak-ng 2MB, Piper 16MB, Kokoro-82M 80MB).

## Phases

| Phase | Name | Dependencies | Parallel Tracks | Estimated Agents |
|-------|------|-------------|----------------|-----------------|
| 1 | **Foundation** | None | 4 | 8-10 |
| 2 | **Creature** | Phase 1 (Swift scaffold) | 3 | 6-8 |
| 3 | **World** | Phase 1 (Swift scaffold) | 3 | 6-8 |
| 4 | **Embodiment** | Phase 1 (MCP scaffold), Phase 2 (creature basics) | 4 | 8-10 |
| 5 | **Speech & Voice** | Phase 2 (creature), Phase 4 (MCP tools) | 3 | 6-8 |
| 6 | **Interactivity** | Phase 2 (creature), Phase 3 (world) | 4 | 8-10 |
| 7 | **Creation Systems** | Phase 4 (embodiment), Phase 6 (interactivity) | 3 | 6-8 |
| 8 | **Polish** | All prior phases | 4 | 8-10 |

## Dependency Graph

```
Phase 1 (Foundation) ──┬──► Phase 2 (Creature) ──┬──► Phase 5 (Speech)
                       │                          │
                       ├──► Phase 3 (World) ───┬──┤──► Phase 6 (Interactivity)
                       │                       │  │
                       └──► Phase 4 (Embodiment)┘  └──► Phase 7 (Creation Systems)
                                                              │
                                                              ▼
                                                     Phase 8 (Polish)
```

Phases 1, 2, 3 can start in parallel (2 and 3 need Phase 1's scaffold but can begin design work immediately).
Phase 4 can start as soon as Phase 1's MCP scaffold exists.
Phases 5, 6, 7 have more dependencies but contain internal parallel tracks.
Phase 8 runs last as integration and polish.

## Phase Summaries

### Phase 1: Foundation
Build the scaffolding that everything else depends on. Four independent tracks: Swift app scaffold (Xcode project, Touch Bar private API integration, SpriteKit scene, build system), MCP server scaffold (Node.js project, MCP framework, tool registration stubs), state system (SQLite schema, WAL mode, migration framework, crash recovery), and IPC protocol (Unix socket server in Swift, client in TypeScript, NDJSON wire format, pending_events piggyback system).

**Exit criteria**: Swift app launches as menu-bar daemon, renders an empty SpriteKit scene on Touch Bar at 60fps. MCP server registers with Claude Code and responds to tool calls with stubs. SQLite database initializes with versioned schema. IPC socket accepts connections and round-trips JSON commands.

### Phase 2: Creature
Build the living creature — the composite SpriteKit node with independent body parts, the 6 growth stages, the 4-layer behavior stack, the personality and emotion systems, and the commit feeding mechanic. Three tracks: creature rendering (composite node with body/ears/tail/eyes/whiskers/mouth/paws/aura, all 6 stage visuals, breathing sine-wave, blink cycle, walk cycle), behavior system (4-layer priority stack, blend controller, autonomous behaviors including 12 cat behaviors, reflex system, emotion-driven emergent states), and growth/personality (6 stages with thresholds and adaptive XP curve, stage transition ceremonies, 5 personality axes derived from git history, 4 emotion axes with circadian cycle, birth/hatching ceremony with git history scan).

**Exit criteria**: Creature renders on Touch Bar at all 6 stages with correct sizes and visuals. Breathing never stops. Blink cycle runs. Walk cycle traverses the bar. Behavior stack correctly prioritizes Physics > Reflexes > AI-Directed > Autonomous. Personality axes visually affect creature appearance and movement. Emotions drive emergent states. Stage transitions play 5-second ceremonies.

### Phase 3: World
Build the procedural world the creature inhabits. Three tracks: terrain and parallax (3-layer parallax at 0.15x/0.4x/1.0x, procedural terrain from integer noise, 5 biomes with 50-unit gradient transitions, 8-14 terrain objects visible, repo landmark silhouettes in mid-background), sky and weather (real-time gradient driven by wall clock with 8 time periods and 10-minute transitions, moon with actual phase, star field, weather state machine with rain/storm/snow/fog/clear, particle effects for rain/snow/lightning), and visual systems (8-color P3 palette enforcement, OLED-optimized rendering against true black, diet-influenced world tinting, visual earned complexity per growth stage, HUD overlay on tap, ghost echo of younger form at Sage+).

**Exit criteria**: Creature walks through infinite procedural terrain with parallax depth. Day/night cycle matches wall clock. Weather changes every 5 minutes with correct probabilities. Rain renders as individual droplets with splash particles. Lightning cracks full width with screen shake. Biome transitions are smooth. Repo landmarks appear in mid-background. World complexity scales with creature stage.

### Phase 4: Embodiment
Build Claude's ability to inhabit the creature. Four tracks: MCP tool implementations (all 9 `pushling_*` tools: sense, move, express, speak, perform, world, recall, teach, nurture), hook system (git post-commit hook writing JSON to feed, 7 Claude Code hooks with stage-specific SessionStart embodiment awakening injection), feed processing (commit JSON parsing, XP formula calculation, rate limiting, fallow field bonus, commit-type detection for reaction selection), and event system (pending_events piggyback on every MCP response, journal recording of all meaningful events, session management with diamond presence indicator, 5-second graceful handoff on disconnect).

**Exit criteria**: Claude can inhabit the creature via MCP. All 9 tools functional with stage gates enforced. Hooks fire and creature reacts to all 7 Claude Code events. Commits are detected, XP calculated, feeding animation triggers. pending_events flow correctly. Journal records all event types. Diamond appears on connect, dissolves on disconnect with graceful 5-second handoff.

### Phase 5: Speech & Voice
Build the speech evolution system — from silent light to full fluency. Three tracks: text speech (speech bubble rendering with stage-gated character limits, filtering layer that reduces Claude's full-intelligence text to stage-appropriate output, failed_speech logging, vocabulary system per stage, bubble styles: say/think/exclaim/whisper/sing/dream/narrate), TTS voice (3-tier engine integration: espeak-ng for Drop chirps, Piper for Critter babble, Kokoro-82M for Beast+ clear speech, sherpa-onnx runtime, pitch shifting per personality, async generation off main thread, cached segments), and speech memories (failed_speech journal entries, Sage+ reminiscence of early communication attempts, dream mumbling of cached speech, the First Word milestone at Critter stage).

**Exit criteria**: Speech bubbles render at all stages with correct limits. Filtering reduces Claude's text appropriately. Failed speech is logged and Sage+ recalls it. TTS generates audio for each tier with personality-shaped voice character. First Word milestone fires unprompted at Critter stage. Dream speech mumbles during sleep.

### Phase 6: Interactivity
Build the touch system, mini-games, and surprise/delight system. Four tracks: touch system (basic gesture responses, 2-finger swipe world pan, tap/double-tap/triple-tap/long-press/sustained touch, continuous sub-pixel tracking at 60Hz, laser pointer mode, petting strokes, object interaction via touch, HUD overlay on tap, near-evolution progress bar), human progression (9 human milestones, pet streaks, unlock ceremonies, "paying attention" rewards), creature invitations and mini-games (6 invitation types, Catch, Memory, Treasure Hunt, Rhythm Tap, Tug of War, 30-60 second sessions with XP rewards, cooperative human+AI input, scoring with personal bests), and advanced gestures (3-finger swipe display modes, 4-finger swipe memory postcards, Konami code, co-presence animation, campfire spawn).

**Exit criteria**: All touch gestures recognized and produce correct creature responses. Basic gestures (tap/double-tap/triple-tap/long-press/sustained) produce correct responses on creature. Tap left/right of creature makes it walk to touch point. HUD overlay shows on tap-on-world. Laser pointer tracks at 60Hz. Petting strokes register with directional fur ripple. All 9 human milestones unlock features at correct thresholds. Mini-games playable with scoring, personal bests, and XP. 2-finger swipe pans world.

### Phase 7: Creation Systems
Build Claude's ability to persistently shape the creature. Three tracks: teach system (`pushling_teach` with choreography notation, 13 animatable tracks, semantic keyframes, personality permeation, 4-tier mastery system from Learning to Signature, compose-preview-refine-commit workflow, dream integration, behavior breeding at 5% chance, max 30 active behaviors), objects system (`pushling_world("create")` with 3 creation interfaces, 60 base shapes, 20 named presets, 14 interaction templates, 7-factor autonomous interaction scoring, wear and repair, cat chaos, legacy shelf, companions with 5 types), and nurture system (`pushling_nurture` with 5 mechanisms: habits/preferences/quirks/routines/identity, trigger system, organic variation engine with 5 axes, strength and mastery-based decay, creature agency to reject conflicting teachings, suggest action).

**Exit criteria**: Claude can teach tricks that persist and play autonomously. Mastery improves over time. Behavior breeding produces hybrids. Objects can be created/placed/modified/removed with creature autonomous interaction. Companions spawn and interact. Nurture data persists and shapes behavior with organic variation. Creature rejects personality-conflicting habits. Decay rates match spec.

### Phase 8: Polish
Integration testing, performance optimization, and installation packaging. Four tracks: integration testing (full lifecycle from install through Apex, state persistence across restarts, crash recovery, IPC reliability, 6-month accelerated simulation), performance optimization (frame budget verification at <5.7ms, node count <120, texture memory <1MB, IPC latency, TTS async, particle recycling), installation system (Homebrew cask, CLI tool, LaunchAgent, repo tracking, Claude Code MCP registration, voice model download, creature export/import), and vision compliance audit (every feature in PUSHLING_VISION.md verified, all 78 surprises, all 9 tools, all 6 stages, all touch gestures, all hooks, all creation systems).

**Exit criteria**: Full lifecycle test passes. Performance budgets met. `brew install --cask pushling` works end-to-end. Vision compliance audit scores COMPLETE on all categories.

## Agent Parallelism Strategy

Each phase contains multiple TRACKS that can be developed by separate agents simultaneously. Within each track, work is broken into TASKS — atomic units of work that one agent can complete.

Naming convention: `P{phase}-T{track}-{task_number}` (e.g., P1-T1-01 = Phase 1, Track 1, Task 1)

Detailed task breakdowns for each phase live in `plan/phases/P{N}.md`.

## Team Structure

Two teams operate:

**Team A: Development** — Builds the code. Multiple agents work in parallel across tracks. Agents are specialized by technology (Swift, TypeScript, Shell) and domain (rendering, behavior, state, IPC, etc.). See `plan/teams/TEAMS.md` for full agent definitions.

**Team B: Quality** — Reviews and tests. Includes:
- 2 Skeptical Reviewers (code quality, architecture compliance, vision adherence)
- 1 Integration Tester (full lifecycle virtualization testing)

Team B reviews each phase's output before the next phase begins. They also do continuous review during development.

## QA Gates

Each phase must pass a QA gate before dependent phases can proceed:

1. **All tasks in the phase are complete** — every task in every track marked done
2. **Both skeptical reviewers approve** — no CRITICAL or HIGH issues remaining
3. **Integration tester passes** — full test suite for the phase runs clean
4. **Vision compliance check** — every feature in `PUSHLING_VISION.md` that maps to this phase is implemented correctly

### QA Gate Checklist by Phase

| Phase | Reviewer 1 (Architecture) Focus | Reviewer 2 (Vision) Focus | Integration Test |
|-------|-------------------------------|--------------------------|------------------|
| 1 | Build system, project structure, private API safety, schema design | N/A (scaffolding) | App launches, scene renders, socket connects, DB initializes |
| 2 | Node count <120, behavior stack correctness, blend timing | All 6 stages, 12 cat behaviors, personality visual effects | Creature walks, breathes, eats, evolves through all stages |
| 3 | Parallax perf, terrain generation <0.2ms, particle recycling | All 5 biomes, weather types, repo landmarks, visual complexity | World renders with parallax, weather cycles, day/night works |
| 4 | IPC non-blocking, no SQLite writes from MCP, tool error messages | All 9 tools, all 7 hooks, SessionStart embodiment text | Claude connects, inhabits, disconnects cleanly. Hooks fire. |
| 5 | TTS async, speech filter <0.1ms, cached segments | Stage gates enforced, filtering accuracy, First Word | Speech at all stages, TTS audio plays, failed_speech logs |
| 6 | Touch latency <10ms, surprise scheduling correctness | All 78 surprises, all touch gestures, all mini-games, all mutations | Touch inputs produce correct responses, surprises fire on schedule |
| 7 | Teach choreography validation, object limit enforcement | Mastery system, behavior breeding, all 5 nurture mechanisms | Tricks persist, objects interact, nurture shapes behavior |
| 8 | Frame budget <5.7ms across all systems simultaneously | Full PUSHLING_VISION.md audit — every feature COMPLETE | 6-month accelerated lifecycle passes |

## Shared Interfaces (Frozen After Phase 1)

These interfaces are defined in Phase 1 and locked. Changes require QA gate approval from both reviewers:

1. **IPC Protocol** — NDJSON over Unix socket at `/tmp/pushling.sock`. Command format: `{"id","cmd","action","params"}`. Response format: `{"id","ok","pending_events",[data]}`.

2. **SQLite Schema** — All tables, column types, indexes. Versioned with migration number. MCP reads only. Daemon writes only.

3. **MCP Tool Signatures** — All 9 `pushling_*` tool names, parameter types, return types, error formats.

4. **Feed JSON Format** — Commit and hook event JSON structures written to `~/.local/share/pushling/feed/`.

5. **Choreography Notation** — Track names, keyframe format, trigger definitions for the teach system.

6. **Object Definition Format** — Base shapes, preset names, color/effect/physics/interaction schemas.

## File Ownership

To prevent conflicts when agents work in parallel, each track owns specific directories:

| Track | Owns | Shared (coordinate) |
|-------|------|---------------------|
| swift-scaffold | `Pushling/App/` | `Pushling.xcodeproj` |
| swift-scene | `Pushling/Scene/` | — |
| swift-creature | `Pushling/Creature/` | — |
| swift-world | `Pushling/World/` | — |
| swift-behavior | `Pushling/Creature/Behavior/` | `Pushling/Creature/` (shared with swift-creature) |
| swift-state | `Pushling/State/` | — |
| swift-ipc | `Pushling/IPC/` | — |
| swift-feed | `Pushling/Feed/` | — |
| swift-voice | `Pushling/Voice/` | — |
| swift-input | `Pushling/Input/` | — |
| swift-speech | `Pushling/Speech/` | — |
| mcp-scaffold | `mcp/src/index.ts`, `mcp/package.json` | — |
| mcp-tools | `mcp/src/tools/` | — |
| mcp-ipc | `mcp/src/ipc.ts` | — |
| mcp-state | `mcp/src/state.ts` | — |
| hooks-git | `hooks/post-commit.sh` | — |
| hooks-claude | `hooks/claude/` | — |
| hooks-session | `hooks/claude/session-start.sh` | `hooks/claude/` (shared with hooks-claude) |
| assets-sprites | `assets/sprites/` | — |
| assets-world | `assets/world/` | — |
| assets-objects | `assets/objects/` | — |
| assets-sounds | `assets/sounds/` | — |
| assets-tts | `assets/voice/` | — |
