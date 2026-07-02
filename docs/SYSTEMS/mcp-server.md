---
type: System
title: Pushling MCP Server
description: The Node/TypeScript process that gives Claude embodiment — stdio transport, stderr-only logging, claude mcp add registration, the read-only SQLite + Unix-socket dual-channel client, and degraded-mode behavior when the daemon isn't running.
status: Live
tags: [mcp, system, process, nodejs]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for the MCP server **as a process** — how it starts,
transports, logs, and stays connected. It does **not** own the 9
`pushling_*` tool contract (params, stage gates, per-tool degraded-mode
messages — see [the tool contract](/ARCHITECTURE/mcp-tool-contract.md)), the
wire protocol (see [the IPC wire protocol](/ARCHITECTURE/ipc-wire-protocol.md)),
or the session handshake/idle/disconnect state machine (see
[MCP session lifecycle](/ARCHITECTURE/mcp-session-lifecycle.md)). Those are
their own authorities; this concept is the thing that hosts them —
`mcp/src/index.ts`, `mcp/src/ipc.ts`, `mcp/src/state.ts`.

# Process & Transport

The server is a Node.js (`engines.node >= 18.0.0`) process compiled from
TypeScript (`tsconfig.json`: `target: ES2022`, `module: Node16`, `strict:
true`) to `dist/index.js` via `tsc`, or run directly from source via `tsx`
for development (no build step). Claude Code launches it as a **subprocess
over stdio** — `StdioServerTransport` from `@modelcontextprotocol/sdk`
carries the MCP JSON-RPC protocol on stdin/stdout. One process per Claude
Code session (same per-session lifecycle noted in
[the system architecture concept](/ARCHITECTURE/system-architecture.md)'s
process topology table).

**All logging goes to `stderr`, with zero exceptions.** Every diagnostic in
`mcp/src/index.ts`, `ipc.ts`, and `state.ts` uses `console.error(...)` —
there is no `console.log` or direct `process.stdout.write` anywhere in
`mcp/src/` (grep-verified). Writing anything to stdout other than the MCP
protocol frames would corrupt the JSON-RPC stream and break the connection
to Claude Code.

# Registration

```bash
# Production — runs the compiled JS
claude mcp add pushling -- node mcp/dist/index.js

# Development — auto-recompiles via tsx, no build step needed
claude mcp add pushling -- npx tsx mcp/src/index.ts
```

Both forms register the same server (`name: "pushling-mcp"`, `version:
"0.1.0"` in the `McpServer` constructor) — the only difference is whether
Claude Code launches the compiled artifact or the TypeScript source directly.

`mcp/package.json` scripts: `npm run build` (`tsc`), `npm start` (`node
dist/index.js`), `npm run dev` (`tsx src/index.ts`, matching the
development registration form above).

# Startup / Shutdown Sequence

`main()` in `mcp/src/index.ts` runs `startup()` before connecting the
transport:

1. `StateReader.open()` — opens SQLite read-only. Returns `false` (logged,
   non-fatal) if `~/.local/share/pushling/state.db` doesn't exist yet
   (daemon has never run) — see [state persistence](/OPERATIONS/persistence-and-recovery.md).
2. `DaemonClient.connect()` + `startSession()` — attempts the Unix-socket
   handshake. Failure here is also **non-fatal**: caught and logged, the
   server continues into degraded mode (see below).
3. Only after both attempts does the server call `server.connect(transport)`
   and start accepting MCP tool calls.

`shutdown()` (invoked on `SIGINT`/`SIGTERM`) disconnects the daemon client
and closes the SQLite handle, then `process.exit(0)`. There is no
`beforeExit`/`atexit` fallback — a hard kill (`SIGKILL`) skips this cleanup
entirely, which is safe because the MCP server never writes to SQLite and
its socket disconnect is best-effort anyway.

# Two-Channel Client

The server's two outbound channels — implemented in `state.ts`
(`StateReader`) and `ipc.ts` (`DaemonClient`) — are the client-side half of
the split described in
[system-architecture.md's "Two Channels, One Server"](/ARCHITECTURE/system-architecture.md#two-channels-one-server).
This concept covers what's specific to the **client implementations**:

**`StateReader` (SQLite, read-only):** opens
`~/.local/share/pushling/state.db` via `better-sqlite3` with
`{ readonly: true }`, then additionally sets `PRAGMA query_only = ON` as a
belt-and-suspenders safety net against accidental writes, and `PRAGMA
journal_mode = WAL` to match the daemon's WAL configuration for readers. If
`existsSync(DB_PATH)` is false, `open()` returns `false` and every query
method degrades to returning `null`/`[]`/`0` rather than throwing — callers
never need to null-check `isAvailable()` before calling a getter.

**`DaemonClient` (Unix socket, NDJSON):** connects to `/tmp/pushling.sock`.
On unexpected disconnect (`socket.on("close")` while a session was active,
or a socket error after a successful connect), it attempts automatic
reconnection with exponential backoff: **3 attempts**, delays **1000ms,
2000ms, 4000ms** (`MAX_RECONNECT_ATTEMPTS`, `RECONNECT_BACKOFF_MS` in
`ipc.ts`). If a session was active when the disconnect happened, a
successful reconnect also re-runs `startSession()` to re-establish one.
After 3 failed attempts, reconnection gives up permanently for that MCP
process lifetime (a fresh Claude Code session spawns a fresh MCP process,
which starts this logic over). Every outbound message is capped at **64 KB**
(`MAX_MESSAGE_SIZE`); the client also caps its own inbound receive buffer at
128 KB, discarding and resetting on overflow (protects against a runaway or
malformed daemon stream). Every `send()` has a **5-second default timeout**
(`DEFAULT_TIMEOUT_MS`), independently configurable per `DaemonClient`
instance.

# Degraded Mode

When the daemon isn't running (or the socket connection has permanently
failed after the reconnect budget above), the MCP server does not exit or
refuse to start — it stays up in **degraded mode**: SQLite-backed reads
keep working (`pushling_sense`, `pushling_recall`, and the `list`/`get`
actions on `pushling_teach`/`pushling_nurture`), while any tool call that
requires a live daemon write returns a helpful, in-character error rather
than hanging or crashing. The exact per-tool message and which actions
qualify as "requires the daemon" are catalogued tool-by-tool in
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md) — this concept
only establishes the mechanism (per-channel independence, non-fatal
connection failures, automatic reconnect) that makes degraded mode possible.

# Pending Events Formatting

Every tool response is a single text block: the tool's own content plus, if
the daemon returned any `pending_events`, a human-readable "What happened
since you last checked" appendix appended by `formatPendingEvents()` in
`index.ts`. Up to 10 events render in full; beyond that, the first 8 render
plus a "...and N more events" summary line. Each event type
(`commit`/`touch`/`surprise`/`evolve`/`weather_change`/`session`/`hook`) has
its own in-character phrasing (`eventSummary()`) — e.g. a `commit` event
renders as "Devoured ... — a feast! +N XP" above 30 XP, "Ate ..." above 15,
else "Nibbled ...". The event *data model* and buffering semantics
(sequence numbers, overflow policy) belong to
[pending events](/ARCHITECTURE/pending-events.md); this is purely the MCP
server's presentation layer on top of that data.

# Citations

[1] `mcp/src/index.ts` (`startup`, `shutdown`, `main`, `formatPendingEvents`, `eventSummary`)
[2] `mcp/src/ipc.ts` (`DaemonClient` — `SOCKET_PATH`, `MAX_RECONNECT_ATTEMPTS`, `RECONNECT_BACKOFF_MS`, `MAX_MESSAGE_SIZE`, `DEFAULT_TIMEOUT_MS`)
[3] `mcp/src/state.ts` (`StateReader` — `DB_PATH`, `{ readonly: true }`, `PRAGMA query_only`)
[4] `mcp/package.json` (scripts, `engines.node`)
[5] `mcp/tsconfig.json`
[6] `mcp/README.md` — Setup, Register with Claude Code, Transport
