# Pushling IPC Protocol Specification

**Version**: 1.0
**Transport**: Unix Domain Socket
**Path**: `/tmp/pushling.sock`
**Encoding**: NDJSON (Newline-Delimited JSON)
**Last Updated**: 2026-03-14

---

## Overview

The Pushling daemon (Swift) listens on a Unix domain socket. MCP servers (Node.js) connect as clients. Communication is NDJSON — one JSON object per line, terminated by `\n`. No newlines are permitted within a message body; all JSON must be serialized as a single line.

The daemon responds to commands as soon as they are **accepted**, not when animations complete. All visual effects are queued asynchronously on the render thread.

Every response includes a `pending_events` array — events that occurred since the last response to this session. This piggyback system ensures Claude stays aware of world state without polling.

---

## Transport Details

| Property | Value |
|----------|-------|
| Socket type | `AF_UNIX`, `SOCK_STREAM` |
| Socket path | `/tmp/pushling.sock` |
| Max message size | 64 KB |
| Line terminator | `\n` (0x0A) |
| Encoding | UTF-8 |
| Max concurrent connections | 3 |

### Startup

1. If `/tmp/pushling.sock` exists, `unlink()` it (previous instance may have crashed).
2. Create socket, `bind()`, `listen()` with backlog of 3.
3. Accept connections on a dedicated dispatch queue (never the render thread).

### Shutdown

1. Close all client connections.
2. `unlink()` the socket file.
3. Log shutdown.

### Partial Reads

The socket is stream-oriented. Both sides must buffer incoming data and split on `\n` boundaries. A single `read()` call may return:
- A partial line (buffer until `\n` arrives)
- Multiple lines (split and process each)
- A line split across two reads (concatenate with buffer)

---

## Request Format

Every request from the client is a single JSON line:

```json
{"id":"<uuid>","cmd":"<command>","action":"<action>","params":{...}}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string (UUID v4) | Yes | Unique request identifier. Used to match responses. |
| `cmd` | string | Yes | Command name. One of the 9 tool commands or 3 session commands. |
| `action` | string | Depends on cmd | Sub-action within the command. Required for most commands. |
| `params` | object | No | Additional parameters. Command-specific. Defaults to `{}`. |

### Session Commands

These manage the connection lifecycle. They do not map to MCP tools.

| Command | Action | Description |
|---------|--------|-------------|
| `connect` | — | Client announces its presence. Returns session ID + creature state. |
| `disconnect` | — | Client announces departure. Triggers farewell animation. |
| `ping` | — | Heartbeat. Returns `ok` with pending events. |

### Tool Commands

These map 1:1 to the 9 `pushling_*` MCP tools.

| Command | Valid Actions | Maps To |
|---------|-------------|---------|
| `sense` | `self`, `body`, `surroundings`, `visual`, `events`, `developer`, `evolve`, `full` | `pushling_sense` |
| `move` | `goto`, `walk`, `stop`, `jump`, `turn`, `retreat`, `pace`, `approach_edge`, `center`, `follow_cursor` | `pushling_move` |
| `express` | `joy`, `curiosity`, `surprise`, `contentment`, `thinking`, `mischief`, `pride`, `embarrassment`, `determination`, `wonder`, `sleepy`, `love`, `confusion`, `excitement`, `melancholy`, `neutral` | `pushling_express` |
| `speak` | `say`, `think`, `exclaim`, `whisper`, `sing`, `dream`, `narrate` | `pushling_speak` |
| `perform` | `wave`, `spin`, `bow`, `dance`, `peek`, `meditate`, `flex`, `backflip`, `dig`, `examine`, `nap`, `celebrate`, `shiver`, `stretch`, `play_dead`, `conduct`, `glitch`, `transcend`, or `sequence` (for choreographed sequences) | `pushling_perform` |
| `world` | `weather`, `event`, `place`, `create`, `remove`, `modify`, `time_override`, `sound`, `companion` | `pushling_world` |
| `recall` | `recent`, `commits`, `touches`, `conversations`, `milestones`, `dreams`, `relationship`, `failed_speech` | `pushling_recall` |
| `teach` | `compose`, `preview`, `refine`, `commit`, `list`, `remove` | `pushling_teach` |
| `nurture` | `habit`, `preference`, `quirk`, `routine`, `identity`, `suggest`, `list`, `remove` | `pushling_nurture` |

---

## Response Format

### Success Response

```json
{"id":"<matching_uuid>","ok":true,"data":{...},"pending_events":[...]}
```

| Field | Type | Always Present | Description |
|-------|------|----------------|-------------|
| `id` | string | Yes | Matches the request `id`. |
| `ok` | boolean | Yes | `true` for success. |
| `data` | object | Yes | Command-specific response data. |
| `pending_events` | array | Yes | Events since last response to this session. May be empty `[]`. |

### Error Response

```json
{"id":"<matching_uuid>","ok":false,"error":"<human-readable message>","code":"<ERROR_CODE>","pending_events":[...]}
```

| Field | Type | Always Present | Description |
|-------|------|----------------|-------------|
| `id` | string | Yes | Matches the request `id`. |
| `ok` | boolean | Yes | `false` for errors. |
| `error` | string | Yes | Human-readable error message with guidance on valid values. |
| `code` | string | Yes | Machine-readable error code. |
| `pending_events` | array | Yes | Events are still delivered even on errors. |

### Error Codes

| Code | Meaning |
|------|---------|
| `UNKNOWN_COMMAND` | The `cmd` field is not a recognized command. |
| `UNKNOWN_ACTION` | The `action` field is not valid for the given command. |
| `INVALID_PARAMS` | The `params` object is missing required fields or has invalid values. |
| `STAGE_GATE` | The creature's current growth stage does not support this action. |
| `SESSION_REQUIRED` | A `connect` command must be sent before using tool commands. |
| `SESSION_NOT_FOUND` | The provided session ID does not match an active session. |
| `PARSE_ERROR` | The request could not be parsed as JSON. |
| `MESSAGE_TOO_LARGE` | The request exceeds the 64 KB limit. |
| `INTERNAL_ERROR` | An unexpected error occurred in the daemon. |
| `CAPACITY_EXCEEDED` | A limit has been reached (e.g., max objects, max tricks). |

---

## Session Management

### Connect

**Request**:
```json
{"id":"abc-123","cmd":"connect","params":{"client":"mcp","version":"1.0"}}
```

**Response**:
```json
{
  "id": "abc-123",
  "ok": true,
  "data": {
    "session_id": "sess-uuid-here",
    "protocol_version": "1.0",
    "creature": {
      "name": "Zepus",
      "stage": "beast",
      "xp": 312,
      "personality": {
        "energy": 0.3,
        "verbosity": 0.7,
        "focus": 0.6,
        "discipline": 0.8,
        "specialty": "web_backend"
      },
      "emotions": {
        "satisfaction": 72,
        "curiosity": 85,
        "contentment": 64,
        "energy": 55
      },
      "speech": {
        "max_chars": 50,
        "max_words": 8,
        "styles": ["say", "think", "exclaim", "whisper", "sing"]
      },
      "tricks_known": 6,
      "streak_days": 12
    }
  },
  "pending_events": []
}
```

The `creature` object provides the full snapshot that the MCP server caches and includes in the SessionStart hook context injection.

### Disconnect

**Request**:
```json
{"id":"def-456","cmd":"disconnect","params":{"session_id":"sess-uuid-here"}}
```

**Response**:
```json
{"id":"def-456","ok":true,"data":{"farewell":true},"pending_events":[]}
```

The daemon triggers the 5-second farewell animation (diamond dissolves, creature waves). If the socket closes without a `disconnect` command, the daemon detects the broken connection and triggers the farewell automatically.

### Ping

**Request**:
```json
{"id":"ghi-789","cmd":"ping","params":{}}
```

**Response**:
```json
{"id":"ghi-789","ok":true,"data":{"uptime_s":3600},"pending_events":[...]}
```

Use `ping` to poll for pending events without issuing a tool command. Useful during long idle periods.

---

## Pending Events

Every response includes a `pending_events` array. Events are buffered per-session in a ring buffer (capacity: 100 events). When `drain()` is called to build a response, all buffered events for that session are returned and the buffer is cleared.

### Event Format

```json
{
  "seq": 42,
  "type": "commit",
  "timestamp": "2026-03-14T10:30:00Z",
  "data": {
    "sha": "a1b2c3d",
    "message": "fix: resolve auth race condition",
    "xp": 8,
    "lines_added": 23,
    "lines_deleted": 7
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `seq` | integer | Monotonically increasing sequence number (global, not per-session). |
| `type` | string | Event type. See table below. |
| `timestamp` | string | ISO 8601 timestamp of when the event occurred. |
| `data` | object | Event-specific payload. |

### Event Types

| Type | When | Data Fields |
|------|------|-------------|
| `commit` | Creature ate a commit | `sha`, `message`, `xp`, `lines_added`, `lines_deleted`, `repo`, `commit_type` |
| `touch` | Human touched the Touch Bar | `gesture` (tap/double_tap/long_press/swipe/drag), `position`, `duration_ms` |
| `surprise` | A surprise event triggered | `surprise_id`, `category`, `description` |
| `weather` | Weather changed | `from`, `to`, `duration_min` |
| `evolve` | Creature evolved to new stage | `from_stage`, `to_stage`, `total_xp` |
| `milestone` | Achievement unlocked | `milestone_id`, `description` |
| `emotion` | Significant emotional state change | `axis`, `from`, `to`, `trigger` |
| `trick` | Creature performed a trick | `trick_name`, `mastery_level`, `autonomous` |
| `companion` | Companion NPC event | `companion_type`, `action` |
| `object` | Object interaction | `object_id`, `interaction_type` |
| `hook` | Claude Code hook fired | `hook_type`, `data` |
| `session` | Another session connected/disconnected | `action`, `session_id` |
| `events_dropped` | Buffer overflow occurred | `count` (number of events lost) |

### Buffer Overflow

When the 100-event buffer is full and a new event arrives:
1. The oldest event is discarded.
2. An `events_dropped` meta-event is injected with `count: 1`.
3. If consecutive drops occur, the count accumulates in the existing `events_dropped` event rather than creating multiple meta-events.

---

## Tool Command Details

### sense

Proprioception — feel yourself, your surroundings, and what is happening.

**Request**:
```json
{"id":"...","cmd":"sense","action":"self","params":{}}
```

The `action` field selects which aspect to sense. Default is `full`.

| Action | Response `data` contents |
|--------|------------------------|
| `self` | `emotions` object (satisfaction, curiosity, contentment, energy) |
| `body` | `stage`, `size`, `appearance`, `personality`, `current_animation` |
| `surroundings` | `weather`, `terrain`, `nearby_objects`, `time_of_day`, `biome` |
| `visual` | `screenshot` (base64 PNG of current Touch Bar render) |
| `events` | `recent_events` array (last 20 events) |
| `developer` | `typing_active`, `last_commit_ago_s`, `session_duration_s` |
| `evolve` | `eligible` (bool), `current_xp`, `threshold`, or triggers ceremony if eligible |
| `full` | All of the above combined (except `visual` and `evolve`) |

**Error on bad action**:
```json
{"id":"...","ok":false,"error":"Unknown aspect 'foo'. Valid: self, body, surroundings, visual, events, developer, evolve, full","code":"UNKNOWN_ACTION"}
```

### move

Locomotion. Move this body.

**Request**:
```json
{"id":"...","cmd":"move","action":"goto","params":{"target":"center","speed":"walk"}}
```

| Action | Required Params | Optional Params |
|--------|----------------|-----------------|
| `goto` | `target` (left/right/center/edge_left/edge_right or pixel pos) | `speed` (walk/run/sneak) |
| `walk` | `direction` (left/right) | `speed` |
| `stop` | — | — |
| `jump` | `direction` (up/left/right) | — |
| `turn` | `direction` (left/right/around) | — |
| `retreat` | — | — |
| `pace` | — | — |
| `approach_edge` | `direction` (left/right) | `speed` |
| `center` | — | `speed` |
| `follow_cursor` | — | — |

**Response `data`**: `{"accepted": true, "position": 542, "facing": "right"}`

### express

Emotional display. Show what you feel.

**Request**:
```json
{"id":"...","cmd":"express","action":"joy","params":{"intensity":0.8,"duration":3.0}}
```

The `action` field is the expression name. See the full list under Tool Commands above.

| Param | Type | Default | Range |
|-------|------|---------|-------|
| `intensity` | float | 0.7 | 0.0 - 1.0 |
| `duration` | float | 3.0 | 0.1 - 30.0 |

**Response `data`**: `{"expression": "joy", "intensity": 0.8, "duration": 3.0}`

### speak

The voice of the creature. Stage-gated.

**Request**:
```json
{"id":"...","cmd":"speak","action":"say","params":{"text":"good morning!"}}
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | Yes | The text to speak. Will be filtered by stage. |

**Response `data`**:
```json
{
  "spoken": "morning!",
  "intended": "good morning!",
  "filtered": true,
  "style": "say",
  "stage": "critter",
  "max_chars": 20,
  "max_words": 3
}
```

**Stage gate error** (Spore cannot speak):
```json
{"id":"...","ok":false,"error":"Spore cannot speak. You are pure light — communication is through brightness and pulse. Grow to Drop stage to unlock symbol expression.","code":"STAGE_GATE"}
```

### perform

Complex animations and choreographed sequences.

**Single behavior request**:
```json
{"id":"...","cmd":"perform","action":"wave","params":{"variant":"big"}}
```

**Sequence request**:
```json
{
  "id": "...",
  "cmd": "perform",
  "action": "sequence",
  "params": {
    "sequence": [
      {"tool": "move", "params": {"action": "goto", "target": "center"}, "delay_ms": 0},
      {"tool": "express", "params": {"expression": "determination"}, "delay_ms": 500},
      {"tool": "speak", "params": {"text": "watch this"}, "delay_ms": 1000, "await_previous": true},
      {"tool": "perform", "params": {"behavior": "backflip", "variant": "double"}, "delay_ms": 500, "await_previous": true},
      {"tool": "express", "params": {"expression": "pride"}, "delay_ms": 200}
    ],
    "label": "showing off"
  }
}
```

**Response `data`**: `{"accepted": true, "behavior": "wave", "variant": "big", "stage_ok": true}`

For sequences: `{"accepted": true, "steps": 5, "label": "showing off", "estimated_duration_ms": 4200}`

### world

Shape the environment around you.

**Request**:
```json
{"id":"...","cmd":"world","action":"weather","params":{"type":"rain","duration":10}}
```

**Response `data`** varies by action:
- `weather`: `{"type": "rain", "duration": 10, "previous": "clear"}`
- `place`: `{"object_id": "obj-uuid", "position": 340, "type": "campfire"}`
- `create`: `{"object_id": "obj-uuid", "preset": "ball"}`
- `companion`: `{"companion_id": "comp-uuid", "type": "mouse", "name": "Pip"}`

### recall

Access memories. What do you remember?

**Request**:
```json
{"id":"...","cmd":"recall","action":"recent","params":{"count":10}}
```

| Param | Type | Default | Max |
|-------|------|---------|-----|
| `count` | integer | 20 | 100 |

**Response `data`**: `{"memories": [...], "count": 10, "filter": "recent"}`

### teach

Teach the creature new tricks.

**Request**:
```json
{"id":"...","cmd":"teach","action":"compose","params":{"name":"roll_over","duration_s":3.0,"tracks":{...}}}
```

| Action | Description |
|--------|-------------|
| `compose` | Define a new trick with choreography notation. |
| `preview` | Play a trick once without committing it. |
| `refine` | Modify an existing draft trick. |
| `commit` | Save a previewed trick permanently. Learning ceremony plays. |
| `list` | List all taught tricks with mastery levels. |
| `remove` | Remove a taught trick by name. |

**Response `data`** (compose): `{"draft_id": "draft-uuid", "name": "roll_over", "tracks": 3, "duration_s": 3.0}`

### nurture

Persistently shape the creature's behavioral tendencies.

**Request**:
```json
{"id":"...","cmd":"nurture","action":"habit","params":{"trigger":"after_commit","behavior":"stretch","frequency":"often"}}
```

| Action | Description |
|--------|-------------|
| `habit` | Add or modify a conditional behavior. |
| `preference` | Set a valence tag on something. |
| `quirk` | Add a small behavior modifier. |
| `routine` | Set a multi-step sequence for a lifecycle slot. |
| `identity` | Set name, title, or motto. |
| `suggest` | Ask the daemon for nurture suggestions based on observed patterns. |
| `list` | List all active nurture data (habits, preferences, quirks, routines). |
| `remove` | Remove a specific nurture item by ID. |

**Response `data`** (habit): `{"habit_id": "hab-uuid", "trigger": "after_commit", "behavior": "stretch", "strength": 0.5}`

---

## Wire Examples

### Full Round-Trip: Connect + Sense + Disconnect

**Client sends** (3 lines):
```
{"id":"c1","cmd":"connect","params":{"client":"mcp","version":"1.0"}}
{"id":"c2","cmd":"sense","action":"self","params":{}}
{"id":"c3","cmd":"disconnect","params":{"session_id":"sess-abc"}}
```

**Daemon responds** (3 lines):
```
{"id":"c1","ok":true,"data":{"session_id":"sess-abc","protocol_version":"1.0","creature":{...}},"pending_events":[]}
{"id":"c2","ok":true,"data":{"emotions":{"satisfaction":72,"curiosity":85,"contentment":64,"energy":55}},"pending_events":[{"seq":41,"type":"commit","timestamp":"2026-03-14T10:30:00Z","data":{"sha":"a1b2c3d","message":"fix auth","xp":8}}]}
{"id":"c3","ok":true,"data":{"farewell":true},"pending_events":[]}
```

### Error: Unknown Command

```
→ {"id":"e1","cmd":"fly","action":"up","params":{}}
← {"id":"e1","ok":false,"error":"Unknown command 'fly'. Valid: sense, move, express, speak, perform, world, recall, teach, nurture, connect, disconnect, ping","code":"UNKNOWN_COMMAND","pending_events":[]}
```

### Error: Malformed JSON

```
→ {this is not json
← {"id":"__parse_error__","ok":false,"error":"Failed to parse request as JSON. Ensure the message is a valid single-line JSON object terminated by \\n.","code":"PARSE_ERROR","pending_events":[]}
```

### Error: No Session

```
→ {"id":"n1","cmd":"sense","action":"self","params":{}}
← {"id":"n1","ok":false,"error":"No active session. Send a 'connect' command first.","code":"SESSION_REQUIRED","pending_events":[]}
```

---

## Implementation Notes

### For Swift Daemon (Server)

- Listen on a dedicated `DispatchQueue` (not the main/render thread).
- Use `DispatchIO` or POSIX `read()`/`write()` with non-blocking I/O.
- Maintain a line buffer per connection for partial read assembly.
- Clean up `/tmp/pushling.sock` on both startup and shutdown.
- Track sessions by UUID. Each session has its own pending events ring buffer.
- Handle `SIGPIPE` to prevent crashes on broken connections.

### For Node.js MCP Server (Client)

- Use the `net` module (no external dependencies).
- Maintain a line buffer for partial read assembly.
- Match responses to requests by `id` (UUID v4).
- Implement auto-reconnect with exponential backoff (1s, 2s, 4s — 3 attempts).
- Timeout pending requests after 5 seconds (configurable).
- Handle multiple in-flight requests concurrently.

### General

- All timestamps are ISO 8601 in UTC.
- All UUIDs are v4.
- The daemon processes commands sequentially per connection but concurrently across connections.
- Max message size is 64 KB. Messages exceeding this are rejected with `MESSAGE_TOO_LARGE`.
