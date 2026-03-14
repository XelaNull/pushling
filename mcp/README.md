# Pushling MCP Server

MCP server for Pushling — 9 embodiment tools for Claude to inhabit a Touch Bar virtual pet creature.

## Setup

```bash
cd mcp
npm install
npm run build
```

## Register with Claude Code

```bash
claude mcp add pushling -- node mcp/dist/index.js
```

Or for development (auto-recompile):

```bash
claude mcp add pushling -- npx tsx mcp/src/index.ts
```

## Architecture

The MCP server communicates through two channels:

- **SQLite** (read-only) — reads creature state from `~/.local/share/pushling/state.db`
- **Unix socket** (IPC) — sends commands to the Pushling daemon at `/tmp/pushling.sock`

The server works in degraded mode when the daemon is not running: read operations (sense, recall) return SQLite data, while write operations (move, express, speak) return a helpful error asking the user to launch Pushling.app.

## The 9 Tools

| Tool | Purpose | Requires Daemon |
|------|---------|-----------------|
| `pushling_sense` | Feel yourself, surroundings, and events | Partial (reads from SQLite, screenshots need daemon) |
| `pushling_move` | Locomotion — walk, run, jump, turn | Yes |
| `pushling_express` | Emotional display — joy, curiosity, love | Yes |
| `pushling_speak` | Speech bubbles, stage-gated | Yes |
| `pushling_perform` | Complex animations and sequences | Yes |
| `pushling_world` | Weather, objects, companions, sounds | Yes |
| `pushling_recall` | Access memories and journal | No (SQLite only) |
| `pushling_teach` | Teach new tricks via choreography | Partial (list reads from SQLite) |
| `pushling_nurture` | Shape habits, preferences, routines | Partial (list/get reads from SQLite) |

Every tool response includes a `pending_events` array with events that occurred since the last call (commits eaten, touches, surprises, etc.).

## File Structure

```
mcp/
├── src/
│   ├── index.ts          # MCP server entry, tool registration, lifecycle
│   ├── ipc.ts            # DaemonClient — Unix socket NDJSON client
│   ├── state.ts          # StateReader — SQLite read-only queries
│   └── tools/
│       ├── sense.ts      # pushling_sense — proprioception
│       ├── move.ts       # pushling_move — locomotion
│       ├── express.ts    # pushling_express — emotions
│       ├── speak.ts      # pushling_speak — speech bubbles
│       ├── perform.ts    # pushling_perform — animations/sequences
│       ├── world.ts      # pushling_world — environment shaping
│       ├── recall.ts     # pushling_recall — memory access
│       ├── teach.ts      # pushling_teach — choreography system
│       └── nurture.ts    # pushling_nurture — behavioral shaping
├── dist/                 # Compiled JavaScript (git-ignored)
├── package.json
├── tsconfig.json
└── README.md
```

## Development

```bash
npm run dev    # Run with tsx (auto-recompile)
npm run build  # Compile TypeScript
npm start      # Run compiled JS
```

## Transport

The server uses stdio transport — Claude Code launches it as a subprocess. All logging goes to stderr to avoid interfering with the MCP protocol on stdout.
