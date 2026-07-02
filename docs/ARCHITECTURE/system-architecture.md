---
type: System
title: Pushling System Architecture
description: The four-process topology (daemon, MCP server, git hook, Claude Code hooks), the rendering target, and the on-disk state layout that everything else in the bundle assumes.
status: Live
tags: [architecture, ipc, process-topology, daemon, mcp]
timestamp: 2026-07-02T00:00:00Z
---

Pushling is four independent processes coordinating around one piece of shared,
durable state. This concept is the map — the "how the pieces connect" hub every
other ARCHITECTURE concept assumes. It does not repeat the wire format, the
command catalog, or the tool contract — those are their own authorities,
cross-linked below.

# Process Topology

| Process | Lifecycle | Purpose |
|---|---|---|
| **Pushling.app** (Swift daemon) | Persistent, `LaunchAgent`-managed | Renders the creature at 60fps in SpriteKit, runs the always-on nervous system (Physics + Reflexes + Autonomous layers), owns the Unix socket server, is the sole SQLite writer |
| **MCP server** (Node/TypeScript) | Spawned per Claude Code session (stdio subprocess) | Claude's embodiment layer — 9 `pushling_*` tools; reads SQLite read-only, writes go through the daemon socket |
| **Git post-commit hook** | Per commit, in each tracked repo's `.git/hooks/` | Captures commit metadata, writes feed JSON, signals the daemon |
| **Claude Code hooks** | Per session-lifecycle event | 8 hook scripts giving the creature full dev-session awareness (SessionStart/End, PostToolUse, UserPromptSubmit, SubagentStart/Stop, PostCompact, plus the shared hook library) |

`Pushling/` is a Swift Package Manager package (`swift-tools-version: 5.9`,
`platforms: [.macOS(.v14)]` — verified against `Pushling/Package.swift`),
not an Xcode project; `build.sh` drives `swift build` and wraps the product
into a `.app` bundle itself (see
[build, run, and deploy](/OPERATIONS/build-run-deploy.md)).

## Directory Map

The Swift daemon's sources are organized by subsystem, one directory per
concern; the concepts elsewhere in this bundle document the *behavior* each
directory implements, not its file layout, so this map is kept here as the
one place a reader can see how the source tree corresponds to the systems
above:

```
Pushling/Sources/Pushling/
├── App/         # AppDelegate, lifecycle, LaunchAgent, HotReloadMonitor
├── TouchBar/    # NSTouchBar setup, private API integration
├── Scene/       # SpriteKit scene, camera, layers, DiamondIndicator
├── Creature/    # Creature node, animations, state machine
├── World/       # Terrain, weather, sky, parallax, repo landmarks
├── Input/       # Touch handling, gesture recognition
├── Voice/       # TTS runtime, audio pipeline, voice evolution
├── Behavior/    # 4-layer behavior stack, blend controller
├── State/       # SQLite manager, state model, migration
├── IPC/         # Unix socket server, command handler, session manager
├── Feed/        # Event processing (commits, hooks, XP)
└── Assets/      # Texture atlases, sounds, TTS models

mcp/src/
├── index.ts     # MCP server entry, tool registration
├── tools/       # pushling_* embodiment tool implementations
├── ipc.ts       # Unix socket client to the daemon
└── state.ts     # SQLite read-only state queries

hooks/           # post-commit.sh + 8 Claude Code hook scripts + shared lib
```

Hot-reload (build → running-app self-restart without losing state) is its
own mechanism, not process topology — see
[persistence and recovery](/OPERATIONS/persistence-and-recovery.md#hot-reload-hotreloadmonitor).

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  Pushling.app (Swift)                  Claude Code (per session)     │
│  ┌──────────────────────┐              ┌───────────────────────┐    │
│  │ SpriteKit 60fps       │◄────────────►│ MCP Server (Node.js)  │    │
│  │ Physics/Reflexes/     │  Unix socket │ 9 pushling_* tools    │    │
│  │ Autonomous layers     │  NDJSON      └───────────────────────┘    │
│  │ SocketServer + Router │  /tmp/pushling.sock                       │
│  │ Sole SQLite writer    │                                           │
│  └──────────────────────┘                                            │
│           ▲                                     ▲                    │
│           │ feed JSON                           │ feed JSON          │
│  ┌────────┴──────────┐              ┌───────────┴────────────────┐  │
│  │ git post-commit    │              │ Claude Code hooks           │  │
│  │ hook (shell)       │              │ SessionStart + 7 more       │  │
│  └────────────────────┘              └──────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────┘
```

The MCP server and the two hook families never talk to each other directly —
they only ever go through the daemon (socket for the MCP server, the feed
directory for hooks). See [the IPC wire protocol](/ARCHITECTURE/ipc-wire-protocol.md)
for the socket side and the future hooks/feed concept (SP7) for the feed-directory
side.

# Rendering Target

Native Swift + SpriteKit at 60fps — a real game engine, not shell scripts or a
Touch Bar widget framework.

| Spec | Value |
|---|---|
| Engine | SpriteKit (`SKView` inside `NSCustomTouchBarItem`) |
| Scene size | 1085 x 30 points (`SceneConstants.sceneWidth = 1085.0`) — 2170 x 60 px @2x Retina |
| Frame rate | 60fps, GPU-accelerated |
| Display | OLED, P3 wide gamut, true blacks |
| Touch | Multi-touch, sub-pixel tracking |

Pushling.app is a menu-bar daemon (no Dock icon) that takes over the Touch Bar
via Apple's private `presentSystemModalTouchBar` API. Touch Bar hardware
integration detail (private API surface, `NSTouchBar` setup) is out of scope
for this concept — see the future Touch Bar research concept (SP6b).

# State Persistence

```
~/.local/share/pushling/
├── state.db          # SQLite, WAL mode — creature, journal, commits, world, nurture tables
├── feed/              # Incoming hook + commit JSON files (async-processed by the daemon)
├── backups/           # Daily snapshots
├── voice/              # Cached TTS audio segments
└── exports/            # Creature export files
```

SQLite runs in WAL mode: the daemon is the **sole writer**; the MCP server
opens the database **read-only** (`mcp/src/state.ts`, `Database` opened with
`{ readonly: true }`). WAL mode is what makes that split safe — concurrent
reads don't block the writer. The full schema (tables, columns, the `xp` vs
`total_xp` naming gotcha) is its own authority — see the future state-schema
concept (SP2b).

# IPC: Unix Domain Socket

**Path:** `/tmp/pushling.sock` — Unix domain socket, NDJSON framing (one JSON
object per line). The daemon accepts a command as soon as it's parsed and
routes it; it does **not** wait for the resulting animation to finish before
responding. All visual effects queue asynchronously on the SpriteKit render
thread.

The full transport contract (framing, envelope shape, error vocabulary) is
[the IPC wire protocol](/ARCHITECTURE/ipc-wire-protocol.md). The full set of
socket commands and their actions is
[the IPC command and action catalog](/ARCHITECTURE/ipc-command-catalog.md).
The session handshake/lifecycle riding on top of that transport is
[MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md), and the
proprioception piggyback on every response is
[pending events](/ARCHITECTURE/pending-events.md). What Claude actually calls
— the 9 `pushling_*` tools — is
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md).

# Two Channels, One Server

The MCP server never has a monopoly on either channel — this is the shape
every tool implementation in `mcp/src/tools/` follows:

| Channel | Direction | Used by |
|---|---|---|
| SQLite (`~/.local/share/pushling/state.db`, read-only) | daemon → MCP server | `pushling_sense`, `pushling_recall`, list/get actions on `pushling_teach`/`pushling_nurture` — works even if the daemon is not running |
| Unix socket (`/tmp/pushling.sock`, NDJSON) | MCP server ↔ daemon | Everything that changes creature/world state — `pushling_move`, `pushling_express`, `pushling_speak`, `pushling_perform`, `pushling_world`, and the write actions of `pushling_teach`/`pushling_nurture` |

When the daemon is not running, the MCP server still starts (SQLite-backed
reads keep working) and every write-tool call returns a helpful error asking
the developer to launch Pushling.app, rather than hanging or crashing. This
"degraded mode" is implemented per-tool, not centrally — see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md) for the exact
message each tool returns.

# Citations

[1] `Pushling/Sources/Pushling/IPC/SocketServer.swift`
[2] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`SceneConstants.sceneWidth`)
[3] `mcp/src/state.ts` (read-only `Database` open)
[4] `mcp/src/ipc.ts` (`SOCKET_PATH`)
[5] `PUSHLING_VISION.md` — Architecture: Process Topology, Rendering Target, State Persistence, IPC
[6] `Pushling/Package.swift` (`swift-tools-version`, `platforms`)
[7] `pushling/CLAUDE.md` — This Repo, Architecture (source-tree map)
