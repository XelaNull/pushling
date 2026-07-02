---
type: Protocol
title: Pushling IPC Wire Protocol
description: The NDJSON-over-Unix-socket transport contract between the Pushling daemon and its clients — framing, envelope, error vocabulary, and the implementation constraints both sides must honor.
status: Live
tags: [ipc, protocol, ndjson, unix-socket]
timestamp: 2026-07-02T00:00:00Z
---

The stable, slow-changing half of the IPC contract: how bytes on the wire
become requests and responses. The fast-changing half — which commands exist
and what each one accepts — is
[the command and action catalog](/ARCHITECTURE/ipc-command-catalog.md). Process
placement and the socket's role in the wider system is
[system architecture](/ARCHITECTURE/system-architecture.md).

# Transport

| Property | Value | Source |
|---|---|---|
| Socket type | `AF_UNIX`, `SOCK_STREAM` | `SocketServer.swift` |
| Socket path | `/tmp/pushling.sock` | `SocketServer.socketPath` |
| Max message size | 65,536 bytes (64 KB) | `SocketServer.maxMessageSize`, `mcp/src/ipc.ts MAX_MESSAGE_SIZE` |
| `listen()` backlog | 3 | `SocketServer.startListening()` — this bounds pending (not-yet-`accept`ed) connections, **not** total concurrent connections; there is no explicit cap on accepted concurrent clients |
| Line terminator | `\n` (0x0A) | both sides |
| Encoding | UTF-8 | both sides |
| Client request timeout | 5000ms (`DEFAULT_TIMEOUT_MS`), configurable per-`DaemonClient` instance | `mcp/src/ipc.ts` |
| Client reconnect | Exponential backoff `[1000, 2000, 4000]` ms, max 3 attempts, then gives up for the session | `mcp/src/ipc.ts RECONNECT_BACKOFF_MS` / `MAX_RECONNECT_ATTEMPTS` |

Encoding is NDJSON — one JSON object per line, no embedded newlines. Both
sides buffer partial reads and split on `\n`: a single `read()`/`data` event
may deliver a partial line, multiple lines, or a line split across two reads.

**Startup:** the daemon `unlink()`s any stale socket file, `bind()`s,
`listen()`s, and accepts on a dedicated `DispatchQueue` — never the render
thread (`SocketServer.queue`, `qos: .userInitiated`). **Shutdown:** all client
connections are sent a synthetic clean `disconnect`, then the socket file is
`unlink()`ed.

# Request Envelope

```json
{"id":"<uuid>","cmd":"<command>","action":"<action>","params":{...}}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | Recommended | Echoed back on the response for matching. The MCP client always sends a `randomUUID()`; a missing `id` is tolerated server-side (treated as `"__missing_id__"`) but the response can't then be matched to a specific in-flight request. |
| `cmd` | string | Yes | One of the [15 commands](/ARCHITECTURE/ipc-command-catalog.md). Missing `cmd` → `PARSE_ERROR`. |
| `action` | string | Depends on `cmd` | Sub-action within the command. Omitted actions fall back to a per-command default (e.g. `sense` defaults to `"full"`, `move` defaults to `"stop"`). |
| `params` | object | No | Command-specific. Defaults to `{}` server-side; the MCP client omits the key entirely when there's nothing to send rather than sending `{}`. |

# Response Envelope

**Success:**
```json
{"id":"<matching_uuid>","ok":true,"data":{...},"pending_events":[...]}
```

**Error:**
```json
{"id":"<matching_uuid>","ok":false,"error":"<human-readable message>","code":"<ERROR_CODE>","pending_events":[...]}
```

`pending_events` is present on **every** response, success or error — see
[pending events](/ARCHITECTURE/pending-events.md) for the ring-buffer contract
behind it. `ok`, `id`, and `pending_events` are always present; `data` is
present only on success, `error`/`code` only on failure.

# Session Gating

A fixed set of commands are **session-exempt** — callable before `connect`:
`connect`, `disconnect`, `ping`, `screenshot`, `debug_nodes`
(`SocketServer.swift` `sessionCmds`, mirrored in `CommandRouter.route()`'s
own `sessionCmds` set for idle-timeout bookkeeping). Every other command sent
on a connection with no established session is rejected before it ever
reaches the router:

```json
← {"id":"n1","ok":false,"error":"No active session. Send a 'connect' command first.","code":"SESSION_REQUIRED","pending_events":[]}
```

# Error Vocabulary

The codes actually emitted by the Swift daemon today (grepped across
`SocketServer.swift`, `CommandRouter.swift`, and every `*Handlers.swift`) —
this supersedes the older `docs/IPC-PROTOCOL.md` list, which named two codes
(`STAGE_GATE`, `SESSION_NOT_FOUND`) that do not exist in code and omitted
about ten that do:

| Code | Meaning | Emitted by |
|---|---|---|
| `UNKNOWN_COMMAND` | `cmd` isn't one of the 15 known commands | `CommandRouter.route()` |
| `UNKNOWN_ACTION` | `action` isn't valid for the given `cmd` | `CommandRouter.route()`, and several handlers' own `default:` branches |
| `INVALID_PARAMS` | `params` is missing a required field or has an invalid value | every action/world/nurture/creation handler |
| `SESSION_REQUIRED` | a non-exempt command arrived with no session | `SocketServer.processMessage()` |
| `SESSION_EXISTS` | a second `connect` arrived while a session is already active and not stale | `SessionManager.startSession()` |
| `PARSE_ERROR` | the line wasn't valid JSON, or was missing `cmd` | `SocketServer.processMessage()` |
| `MESSAGE_TOO_LARGE` | buffered data exceeded 64 KB before a newline arrived | `SocketServer.handleRead()` |
| `STAGE_GATED` | the creature's growth stage doesn't support this action | `ActionHandlers` (perform, teach), `CreationHandlers` |
| `SPEECH_GATED` | `pushling_speak` rejected by the speech coordinator | `ActionHandlers.handleSpeak()` |
| `AT_CAP` | a nurture-mechanism cap was reached (20 habits / 12 preferences / 12 quirks / 10 routine slots) | `NurtureHandlers` |
| `OBJECT_CAP_REACHED` | world-object placement cap (12 persistent / 3 consumable), min-spacing, or node-budget rule violated | `WorldHandlers.handleWorldCreate()` |
| `INVALID_CHOREOGRAPHY` | a `pushling_teach` choreography definition failed to parse | `CreationHandlers` |
| `UNKNOWN_BEHAVIOR` | `pushling_perform` behavior name not recognized as taught, built-in, or mapped | `ActionHandlers.handlePerform()` |
| `NO_COMPANION` | `world companion remove` with no active companion | `WorldHandlers.handleWorldCompanion()` |
| `NOT_FOUND` | a referenced object/habit/preference/quirk/routine ID doesn't exist | `WorldHandlers`, `NurtureHandlers` |
| `DB_ERROR` | a SQLite write failed | `CreationHandlers`, `NurtureHandlers` (identity) |
| `NOT_READY` | `gameCoordinator` (or the scene) isn't initialized yet | most handlers' entry guard |
| `TIMEOUT` | a main-thread capture (e.g. `debug_nodes`) didn't complete within 2s | `CommandRouter.handleDebugNodes()` |
| `CAPTURE_FAILED` | `screenshot`'s SpriteKit capture timed out or returned no data | `CommandRouter.handleScreenshot()` |
| `WRITE_FAILED` | `screenshot`'s PNG write to `/tmp/pushling_screenshot.png` failed | `CommandRouter.handleScreenshot()` |
| `INTERNAL_ERROR` | fallback used by `SocketServer.buildResponse()` if a handler returns a failure with no `code` | `SocketServer.swift` (default, not currently hit by any handler) |

# Wire Examples

**Connect → sense → disconnect:**
```
→ {"id":"c1","cmd":"connect","params":{"client":"mcp","version":"1.0"}}
← {"id":"c1","ok":true,"data":{"session_id":"...","protocol_version":"1.0","welcome":"Embodiment awakening...","creature":{...}},"pending_events":[]}
→ {"id":"c2","cmd":"sense","action":"self","params":{}}
← {"id":"c2","ok":true,"data":{"emotions":{"satisfaction":72,"curiosity":85,"contentment":64,"energy":55}},"pending_events":[{"seq":41,"type":"commit","timestamp":"2026-07-02T10:30:00Z","data":{"sha":"a1b2c3d","message":"fix auth"}}]}
→ {"id":"c3","cmd":"disconnect","params":{"session_id":"..."}}
← {"id":"c3","ok":true,"data":{"farewell":true},"pending_events":[]}
```

**Malformed JSON:**
```
→ {this is not json
← {"id":"__parse_error__","ok":false,"error":"Failed to parse request as JSON.","code":"PARSE_ERROR","pending_events":[]}
```

**No session:**
```
→ {"id":"n1","cmd":"sense","action":"self","params":{}}
← {"id":"n1","ok":false,"error":"No active session. Send a 'connect' command first.","code":"SESSION_REQUIRED","pending_events":[]}
```

# Implementation Notes

**Swift daemon (server):**
- Listens on a dedicated `DispatchQueue`, never the render thread.
- Non-blocking `read()`/`write()`, one line buffer (`ClientConnection.lineBuffer`) per connection for partial-read assembly.
- Writes retry on `EAGAIN`/`EWOULDBLOCK` up to 50 times at 1ms intervals (~50ms max) before giving up silently.
- `SIGPIPE` is ignored at `SocketServer.init()` so a client disconnect can't crash the daemon.

**Node MCP client:**
- Plain `node:net`, no external dependency.
- Buffers partial lines; hard safety cap discards the buffer if it exceeds 2× `MAX_MESSAGE_SIZE` without a newline (protects against a daemon sending malformed/endless data).
- Matches responses to requests by `id`; a response with no matching in-flight request (arrived after its own timeout, or unsolicited) is silently ignored.
- On disconnect, rejects all in-flight requests immediately, then attempts the backoff reconnect above; if it had an active session, it calls `startSession()` again after reconnecting.

# Citations

[1] `Pushling/Sources/Pushling/IPC/SocketServer.swift`
[2] `Pushling/Sources/Pushling/IPC/CommandRouter.swift`
[3] `Pushling/Sources/Pushling/IPC/IPCTypes.swift`
[4] `mcp/src/ipc.ts`
[5] `docs/IPC-PROTOCOL.md` (superseded by this concept — see [SP2a traceability](/archive/traceability/SP2a.md))
