# Phase 4: Embodiment

## Goal

Claude can inhabit the creature via MCP tools. All 9 `pushling_*` tools are functional. Claude Code hooks feed events to the daemon. The diamond indicator appears/disappears with sessions. The dual-layer model works end-to-end: Layer 1 (autonomous nervous system) runs continuously, Layer 2 (Claude's mind via MCP) adds intentional presence, and the handoff between them is seamless.

This phase is the bridge between "a creature exists" and "a creature is inhabited." After Phase 4, Claude wakes up inside a body shaped by git history, perceives the world, moves with purpose, speaks with stage-gated vocabulary, and fades gracefully back to autonomy when the session ends.

## Dependencies

- **Phase 1 Track 3** — IPC system operational (Unix socket at `/tmp/pushling.sock`, NDJSON protocol, command dispatch)
- **Phase 1 Track 4** — MCP server scaffold with tool registration, `pushling_` prefix, helpful error messages
- **Phase 2 Track 1** — Creature exists as composite SpriteKit node with full animation vocabulary (ears, tail, eyes, body, whiskers, mouth, paws, aura)
- **Phase 2 Track 2** — 4-layer behavior stack operational (Physics, Reflexes, AI-Directed, Autonomous) with blend controller
- **Phase 3 Track 1** — World exists (terrain, biomes, landmarks, objects) — needed for `pushling_sense("surroundings")`
- **Phase 3 Track 2** — Sky and weather exist — needed for `pushling_sense("surroundings")` and `pushling_world("weather")`

## Architectural Context

### Communication Flow
```
Claude Code ──► MCP Server (Node.js) ──► /tmp/pushling.sock ──► Daemon (Swift)
                   │                                               │
                   │ reads SQLite (read-only)                      │ writes SQLite
                   │ ~/.local/share/pushling/state.db              │ processes feed/
                   │                                               │ renders SpriteKit
                   ▼                                               ▼
              Returns JSON to Claude                    Queues animation, returns ACK
```

### Key Constraints
- MCP tools return **immediately** on command acceptance — never block on animation completion
- MCP server reads SQLite only — all writes go through the daemon via socket
- Every MCP response includes `pending_events` array (events since last call)
- IPC protocol: newline-delimited JSON over Unix domain socket
- Tool errors must be helpful: explain what's valid, not just "invalid input"
- All tools prefixed with `pushling_`

### The 9 Tools
| Tool | Purpose | Category |
|------|---------|----------|
| `pushling_sense` | Proprioception — feel self, body, world, events, developer | Perception |
| `pushling_recall` | Memory access — commits, touches, milestones, dreams, failed speech | Perception |
| `pushling_move` | Locomotion — goto, walk, stop, jump, turn, retreat, pace | Action |
| `pushling_express` | Emotional display — 15 expressions with intensity and duration | Action |
| `pushling_speak` | Stage-gated speech — 7 styles, filtering layer, failed speech logging | Action |
| `pushling_perform` | Complex animations — 18 behaviors with variants, sequence mode | Action |
| `pushling_world` | Environment shaping — weather, events, objects, companions, sounds | Action |
| `pushling_teach` | Persistent choreography — teach tricks that enter idle rotation | Creation (Phase 7) |
| `pushling_nurture` | Behavioral shaping — habits, preferences, quirks, routines, identity | Creation (Phase 7) |

**Phase 4 implements the first 7 tools fully.** `pushling_teach` and `pushling_nurture` are stubbed with helpful "coming soon" messages and will be completed in Phase 7 (Creation Systems).

---

## Tracks

### Track 1: MCP Tools — Perception (P4-T1)

**Agents**: mcp-tools, mcp-state
**Estimated effort**: 6-8 days
**Parallelizable with**: Track 3 (hooks) — no dependency between them

The perception tools let Claude feel itself, its body, and its world. These are read-only operations that query SQLite state and daemon status. They frame information as proprioception ("how do I feel?") rather than status polling ("what's the pet's status?").

#### P4-T1-01: pushling_sense — "self"

**What**: Returns the creature's emotional state. Framed as "how do I feel?"

**Returns**:
```json
{
  "aspect": "self",
  "emotional_state": {
    "satisfaction": 72,
    "curiosity": 85,
    "contentment": 64,
    "energy": 55
  },
  "emergent_state": "studious",
  "mood_summary": "well-fed and curious, exploring with focus",
  "circadian_phase": "mid-afternoon settling",
  "last_fed_ago_s": 1380,
  "streak_days": 12,
  "pending_events": [...]
}
```

**Implementation**:
- MCP server reads from `creature_state` table in SQLite
- Emergent state calculated from the 4 emotion axes using the combination rules from vision doc (e.g., high satisfaction + contentment + mid energy = "blissful")
- `mood_summary` is a human-readable sentence generated from the numbers
- `circadian_phase` derived from creature's learned schedule vs current time

**Verification**:
- [ ] Returns current emotional state with all 4 axes
- [ ] Emergent state matches the combination rules (blissful, playful, studious, hangry, zen, exhausted)
- [ ] `mood_summary` reads naturally ("well-fed and curious" not "sat:72 cur:85")
- [ ] Response includes `pending_events` array
- [ ] Read-only — no SQLite writes

---

#### P4-T1-02: pushling_sense — "body"

**What**: Returns the creature's physical form. Framed as "what is my body?"

**Returns**:
```json
{
  "aspect": "body",
  "stage": "beast",
  "stage_index": 3,
  "size": {"width": 18, "height": 20},
  "name": "Zepus",
  "appearance": {
    "base_color_hue": "warm_purple",
    "eye_shape": "round",
    "body_type": "sturdy",
    "tail_shape": "fluffy_plume",
    "fur_markings": "tabby_stripes",
    "mutations": ["nocturne", "marathon"]
  },
  "personality": {
    "energy": 0.3,
    "verbosity": 0.7,
    "focus": 0.6,
    "discipline": 0.8,
    "specialty": "web_backend"
  },
  "growth": {
    "total_commits_eaten": 312,
    "xp_current_stage": 112,
    "xp_next_stage": 500,
    "progress_percent": 62.4
  },
  "tricks_learned": ["wave", "spin", "bow", "peek", "dance", "meditate"],
  "current_animation": "idle_walk_right",
  "pending_events": [...]
}
```

**Implementation**:
- Reads from `creature` and `mutations` tables
- `current_animation` fetched via IPC status query (quick, non-blocking)
- Personality axes read from `personality` table
- Growth progress calculated from XP thresholds adjusted by activity_factor

**Verification**:
- [ ] All physical attributes returned accurately
- [ ] Stage name and index correct
- [ ] Growth progress percentage matches actual XP state
- [ ] Tricks list matches taught behaviors from SQLite
- [ ] Mutation badges included
- [ ] Current animation reflects what's actually playing on screen

---

#### P4-T1-03: pushling_sense — "surroundings"

**What**: Returns what's around the creature. Framed as "what's around me?"

**Returns**:
```json
{
  "aspect": "surroundings",
  "time": {
    "wall_clock": "14:23",
    "sky_period": "day",
    "moon_phase": "waxing_gibbous"
  },
  "weather": {
    "state": "cloudy",
    "duration_minutes": 12,
    "forecast": "rain likely"
  },
  "terrain": {
    "biome": "forest",
    "ground_character": "moderate elevation with dense coverage",
    "nearby_objects": [
      {"type": "mushroom", "distance_pt": 8, "direction": "right"},
      {"type": "tree", "distance_pt": 22, "direction": "left"},
      {"type": "yarn_ball", "distance_pt": 45, "direction": "right"}
    ]
  },
  "landmarks": {
    "nearest": {"repo": "api-server", "type": "fortress", "distance_pt": 120, "direction": "right"},
    "visible": ["api-server (fortress)", "pushling (windmill)", "blog (scroll_tower)"]
  },
  "world_tint": "warm_stone",
  "pending_events": [...]
}
```

**Implementation**:
- Weather state from `weather` table
- Terrain/biome from daemon IPC query (creature's current world position → biome lookup)
- Nearby objects from daemon IPC query (objects within 60pt of creature)
- Landmarks from `repos` table + position calculation
- Forecast: simple probability statement based on current state transition weights

**Verification**:
- [ ] Time matches wall clock
- [ ] Weather state matches what's visually rendering
- [ ] Biome matches creature's actual position in the world
- [ ] Nearby objects list is accurate (correct types, distances, directions)
- [ ] Landmarks include all tracked repos

---

#### P4-T1-04: pushling_sense — "events"

**What**: Returns recent events. Framed as "what happened?"

**Returns**:
```json
{
  "aspect": "events",
  "events": [
    {
      "type": "commit",
      "sha": "a1b2c3d",
      "message": "refactor: extract auth middleware",
      "xp_earned": 8,
      "reaction": "predator_crouch_pounce",
      "ago_s": 1380,
      "repo": "api-server"
    },
    {
      "type": "touch",
      "gesture": "sustained_touch",
      "duration_s": 4.2,
      "reaction": "purr_chin_scratch",
      "ago_s": 3200
    },
    {
      "type": "surprise",
      "id": 27,
      "name": "zoomies",
      "ago_s": 5400
    }
  ],
  "pending_events": [...]
}
```

**Implementation**:
- Reads from `journal` table, ordered by timestamp DESC, limit 20
- Filters to "interesting" event types: commit, touch, surprise, evolve, discovery, mutation
- `ago_s` calculated from current time
- This overlaps with `pending_events` but provides a longer history window

**Verification**:
- [ ] Returns recent events in reverse chronological order
- [ ] Default limit of 20 events
- [ ] Event types include commits, touches, surprises, milestones
- [ ] `ago_s` values are accurate
- [ ] No stale or duplicate events

---

#### P4-T1-05: pushling_sense — "developer"

**What**: Returns information about the developer's current activity. Framed as "what is the human doing?"

**Returns**:
```json
{
  "aspect": "developer",
  "name": "Matt",
  "activity": {
    "last_commit_ago_s": 1380,
    "last_touch_ago_s": 3200,
    "session_active": true,
    "session_duration_s": 4200,
    "commits_today": 7,
    "repos_active_today": ["api-server", "pushling"]
  },
  "patterns": {
    "typical_first_commit": "09:15",
    "typical_last_commit": "18:30",
    "most_active_hours": ["10:00-12:00", "14:00-16:00"],
    "average_daily_commits": 8.3
  },
  "pending_events": [...]
}
```

**Implementation**:
- Developer name from `git config user.name` (cached in state)
- Activity from `journal` table (recent commits, touches)
- Session info from daemon's session state
- Patterns from `developer_patterns` table (computed from 14-day rolling window of commit times)

**Verification**:
- [ ] Developer name correct
- [ ] Last commit/touch timing accurate
- [ ] Session duration reflects actual Claude session length
- [ ] Commit patterns derived from real data (not placeholder)
- [ ] Graceful handling when no patterns exist yet (new install)

---

#### P4-T1-06: pushling_sense — "visual"

**What**: Returns a text description of the current scene plus an optional base64 PNG screenshot.

**Returns**:
```json
{
  "aspect": "visual",
  "description": "Zepus stands in a forest biome at mid-afternoon. Cloudy sky with light fog. A mushroom to the right, a tree to the left. The fortress landmark of api-server is visible on the distant skyline. Zepus is facing right, ears relaxed, tail swaying gently.",
  "screenshot_base64": "iVBORw0KGgo...",
  "screenshot_size": {"width": 2170, "height": 60},
  "pending_events": [...]
}
```

**Implementation**:
- Text description: composed from surroundings + body + self data into a natural sentence
- Screenshot: daemon renders current frame to `SKView.texture(from:)`, exports as PNG, base64-encodes
- Screenshot via IPC: daemon-side command `capture_screenshot` returns base64 data
- Screenshot is @2x resolution (2170x60px)
- Screenshot generation is async but fast (<50ms for this scene complexity)

**Verification**:
- [ ] Text description accurately reflects current scene state
- [ ] Screenshot captures actual current Touch Bar content
- [ ] Screenshot is valid PNG, decodable by Claude
- [ ] Screenshot resolution is 2170x60 (@2x)
- [ ] Response time acceptable (screenshot adds <100ms)

---

#### P4-T1-07: pushling_sense — "evolve"

**What**: Check evolution eligibility. If ready, triggers the 5-second ceremony. If not, returns progress.

**Returns (not ready)**:
```json
{
  "aspect": "evolve",
  "ready": false,
  "current_stage": "beast",
  "commits_eaten": 312,
  "threshold": 500,
  "progress_percent": 62.4,
  "commits_remaining": 188,
  "message": "188 more commits until Sage. Keep feeding me.",
  "pending_events": [...]
}
```

**Returns (ready — triggers ceremony)**:
```json
{
  "aspect": "evolve",
  "ready": true,
  "evolving_from": "beast",
  "evolving_to": "sage",
  "ceremony_started": true,
  "message": "The evolution ceremony has begun. Use pushling_sense('body') in 6 seconds to discover your new form.",
  "pending_events": [...]
}
```

**Implementation**:
- Reads XP state from SQLite, compares to stage thresholds (adjusted by activity_factor)
- If ready: sends `evolve` command via IPC to daemon, which triggers the 5-second ceremony
- Returns immediately (does not block on ceremony completion)
- After ceremony, creature state updates in SQLite; Claude uses `pushling_sense("body")` to discover new form

**Verification**:
- [ ] Returns accurate progress when not ready
- [ ] Triggers ceremony when ready (visible on Touch Bar)
- [ ] Does not block — returns immediately even when ceremony starts
- [ ] Threshold uses the adaptive activity_factor
- [ ] Cannot trigger evolution when already at Apex
- [ ] Helpful error if called during an active ceremony

---

#### P4-T1-08: pushling_recall — All 8 Filter Types

**What**: Access the creature's memory. 8 filter types for different memory categories.

**Spec**:
| Filter | Returns | Default Count |
|--------|---------|---------------|
| `"recent"` | Last N events (all types) | 20 |
| `"commits"` | Recent commit feedings with XP breakdown | 20 |
| `"touches"` | Human touch interactions | 20 |
| `"conversations"` | Speech events (AI-directed and autonomous) | 20 |
| `"milestones"` | Evolution, mutations, achievements, first word | 20 |
| `"dreams"` | Recent dream content (sleep-time replays) | 10 |
| `"relationship"` | Summary of AI-human-creature interaction patterns | 1 (summary) |
| `"failed_speech"` | Messages Claude tried but body couldn't express | 20 |

**Tool signature**: `pushling_recall(what?: string, count?: number)`
- `what`: filter type (default `"recent"`)
- `count`: number of entries (default 20, max 100)

**Implementation**:
- All reads from `journal` table with type-specific WHERE clauses
- `"relationship"` is a computed summary: total sessions, total touches, total commits, favorite interaction, longest session, trust level (derived from touch count + session count)
- `"failed_speech"` reads from journal entries where `type = 'failed_speech'`
- Every response includes `pending_events`

**Error handling**: `"Unknown filter 'foo'. Valid filters: recent, commits, touches, conversations, milestones, dreams, relationship, failed_speech"`

**Verification**:
- [ ] All 8 filter types return correct data
- [ ] Count parameter respected (default 20, max 100)
- [ ] "relationship" returns a meaningful summary, not raw data
- [ ] "failed_speech" includes both intended message and actual output
- [ ] Invalid filter returns helpful error with valid options listed
- [ ] Empty results return empty array, not error

---

#### P4-T1-09: Pending Events System

**What**: Every MCP response includes events that occurred since the last MCP call. This is proprioception — Claude stays aware passively.

**Spec**:
- `pending_events` array appended to every MCP tool response
- Events include: commits eaten, touches received, surprises triggered, weather changes, session events, hook events
- Events are consumed on read (next response won't include already-delivered events)
- If no events since last call: empty array `[]`
- Event format: `{"type": "commit", "sha": "abc", "message": "...", "ago_ms": 45000}`

**Implementation**:
- Daemon maintains a per-session event queue (in-memory ring buffer, max 100 events)
- On each IPC response, daemon serializes pending events and clears the queue
- MCP server passes through `pending_events` from daemon response to Claude
- Event timestamps are relative (`ago_ms`) for Claude's convenience
- If no MCP calls for >10 minutes, oldest events are evicted (queue bounded)

**Verification**:
- [ ] Every MCP response includes `pending_events` (even if empty array)
- [ ] Events from commits, touches, surprises appear in the queue
- [ ] Events are consumed (not repeated in next response)
- [ ] Queue is bounded (max 100, oldest evicted)
- [ ] `ago_ms` values are accurate relative to response time
- [ ] Multiple rapid MCP calls correctly partition events (no duplicates, no drops)

---

### Track 2: MCP Tools — Action (P4-T2)

**Agents**: mcp-tools, swift-ipc (daemon-side command handlers)
**Estimated effort**: 10-14 days
**Dependencies**: Track 1 concepts (pending_events system), Phase 2 (creature animation vocabulary)

The action tools let Claude move, emote, speak, perform, and shape the world through the creature. Every action tool sends an IPC command to the daemon and returns immediately on acceptance.

#### P4-T2-01: pushling_move — All 10 Action Types

**What**: Locomotion control. Claude directs the creature's movement.

**Spec**:
| Action | Target | Speed | Effect |
|--------|--------|-------|--------|
| `"goto"` | `"left"`, `"right"`, `"center"`, `"edge_left"`, `"edge_right"`, or pixel position (0-1085) | `"walk"` / `"run"` / `"sneak"` | Move to absolute position |
| `"walk"` | `"left"` / `"right"` | `"walk"` / `"run"` / `"sneak"` | Walk in direction until stopped |
| `"stop"` | — | — | Stop current movement, settle into idle |
| `"jump"` | `"up"` / `"left"` / `"right"` | — | Jump arc with dust landing particles |
| `"turn"` | `"left"` / `"right"` / `"around"` | — | Turn to face direction (0.43s decel-pause-turn-accel) |
| `"retreat"` | — | — | Back away slowly from current position |
| `"pace"` | — | — | Anxious back-and-forth in small area (~40pt range) |
| `"approach_edge"` | `"left"` / `"right"` | `"walk"` / `"sneak"` | Walk to very edge of Touch Bar |
| `"center"` | — | `"walk"` / `"run"` | Return to center of bar (542pt) |
| `"follow_cursor"` | — | — | Track toward where touch events are happening |

**Behavior stack interaction**:
- Move commands activate Layer 3 (AI-Directed) of the behavior stack
- Layer 1 (Physics: breathing, tail-sway) continues during all moves
- Layer 4 (Autonomous wandering) is suspended while AI-Directed is active
- After 30s with no new move command, AI-Directed fades over 5s back to Autonomous

**IPC command format**:
```json
{"id":"42","cmd":"move","action":"goto","params":{"target":"center","speed":"walk"}}
```

**Response**:
```json
{"id":"42","ok":true,"position":542,"facing":"right","pending_events":[]}
```

**Error handling**:
- Invalid action: `"Unknown action 'fly'. Valid: goto, walk, stop, jump, turn, retreat, pace, approach_edge, center, follow_cursor"`
- Invalid target for action: `"'goto' requires target: 'left', 'right', 'center', 'edge_left', 'edge_right', or a number 0-1085"`
- Invalid speed: `"Unknown speed 'sprint'. Valid: walk, run, sneak"`

**Implementation**:
- MCP tool validates parameters, sends IPC command, returns daemon response
- Daemon-side: `MoveCommandHandler` pushes movement onto Layer 3 of behavior stack
- Direction reversal uses the blend controller: 0.43s decel → 2-frame pause → sprite flip → accel
- `follow_cursor` sets a mode that updates target position on each touch event
- Movement speeds: walk = 30pt/s, run = 80pt/s, sneak = 12pt/s

**Verification**:
- [ ] All 10 action types produce correct movement on screen
- [ ] Creature breathes during all movements (Physics layer never interrupted)
- [ ] Direction reversal has the 0.43s transition (not instant flip)
- [ ] 30s AI timeout works — creature returns to autonomous wandering
- [ ] `goto` with pixel position works (creature walks to exact X coordinate)
- [ ] Human touch interrupts AI movement (Reflex priority), then movement resumes
- [ ] Helpful error messages for all invalid inputs
- [ ] Returns immediately — does not block on movement completion

---

#### P4-T2-02: pushling_express — All 16 Expressions

**What**: Emotional display. Claude shows what the creature feels.

**Spec**: 16 expressions (including neutral reset) with intensity (0.0-1.0, default 0.7) and duration (seconds, default 3.0, max 30.0).

| Expression | Animation Description |
|------------|----------------------|
| `"joy"` | Eyes bright, ears up, tail high, bouncy step |
| `"curiosity"` | Head tilt, ears rotate independently, eyes widen |
| `"surprise"` | Ears snap back, eyes wide, jump-startle, fur puffs |
| `"contentment"` | Slow-blink, kneading paws, purr particles |
| `"thinking"` | Head slight tilt, one ear forward one back, tail still |
| `"mischief"` | Narrow eyes, low crouch, tail tip twitching |
| `"pride"` | Chest out, chin up, tail high and still |
| `"embarrassment"` | Ears flat, looks away, tail wraps around body |
| `"determination"` | Ears forward, eyes focused, stance widens |
| `"wonder"` | Eyes huge, ears high, mouth slightly open |
| `"sleepy"` | Heavy blinks, yawns, ears droop |
| `"love"` | Slow-blink, headbutt toward screen, purr particles |
| `"confusion"` | Head tilts alternating sides, ear rotates, `"?"` symbol |
| `"excitement"` | Zoomies trigger, tail poofs, ears wild |
| `"melancholy"` | Tail low, slow movement, muted colors, quiet |
| `"neutral"` | Reset to default idle expression |

**Behavior stack interaction**:
- Expressions are Layer 3 (AI-Directed) — override Autonomous expressions
- Intensity scales animation amplitude (0.5 = subtle, 1.0 = dramatic)
- After duration, expression fades to autonomous emotional state over 0.8s
- AI expression transitions are 0.3s (faster than autonomous 0.8s — more "intentional")

**Visual distinction**: AI-directed expressions are slightly more crisp/intentional than autonomous ones. The 0.3s transition speed (vs 0.8s autonomous) creates a subtle but perceptible difference.

**IPC command format**:
```json
{"id":"43","cmd":"express","expression":"joy","intensity":0.8,"duration":3.0}
```

**Verification**:
- [ ] All 15 expressions produce distinct, recognizable animations
- [ ] Intensity parameter visibly scales animation amplitude
- [ ] Duration parameter controls how long expression holds
- [ ] Expression fades to autonomous state after duration (0.8s crossfade)
- [ ] AI expressions transition at 0.3s (faster than autonomous)
- [ ] `"neutral"` resets to default idle
- [ ] Breathing continues during all expressions
- [ ] Invalid expression returns helpful error listing all valid options

---

#### P4-T2-03: pushling_speak — Stage-Gated Text with Filtering

**What**: The creature speaks. Claude's full-intelligence message is filtered through the creature's growth stage.

**Stage-gated limits**:
| Stage | Max Chars | Max Words | Symbols Only | Notes |
|-------|-----------|-----------|-------------|-------|
| Spore | 0 | 0 | N/A | Cannot speak. Returns error. |
| Drop | 1 | N/A | Yes: `! ? ♡ ~ ... ♪ ★ !?` | Floating glyph, no bubble |
| Critter | 20 | 3 | No | First speech bubble. ~200-word vocabulary |
| Beast | 50 | 8 | No | Full sentences, opinions |
| Sage | 80 | 20 | No | Multi-bubble, narrate mode unlocked |
| Apex | 120 | 30 | No | Full fluency, no filtering |

**7 speech styles**:
| Style | Effect | Stage Req |
|-------|--------|-----------|
| `"say"` (default) | Normal speech bubble, standard voice | Drop+ |
| `"think"` | Cloud-shaped thought bubble, no audio, stares into distance | Drop+ |
| `"exclaim"` | Bold bubble, larger text, exclamation particles, louder voice | Drop+ |
| `"whisper"` | Small bubble, Ash-colored text, close to creature, quiet voice | Critter+ |
| `"sing"` | Musical note particles around bubble, melodic TTS | Beast+ |
| `"dream"` | Translucent bubble, Dusk-colored, wavy text, sleep-mumble. Only during sleep. | Any |
| `"narrate"` | No bubble — text as environmental overlay (subtitles). | Sage+ |

**The filtering layer**:
1. Claude sends full-intelligence message via `pushling_speak`
2. Filtering layer extracts key nouns, verbs, and emotional words
3. Reduces to stage-appropriate word count and vocabulary
4. Preserves emotional intent even when words are lost
5. Adds stage-appropriate punctuation (Critter: `!`, Beast: `.`, Sage: `,`)
6. If significant content was lost, the full intended message is logged as `failed_speech` in the journal

**IPC command format**:
```json
{"id":"44","cmd":"speak","text":"Good morning! I noticed you're working on authentication again. The refactor yesterday was really elegant.","style":"say"}
```

**Response (for a Critter)**:
```json
{"id":"44","ok":true,"spoken":"morning! auth! nice!","intended":"Good morning! I noticed you're working on authentication again. The refactor yesterday was really elegant.","filtered":true,"content_lost":true,"pending_events":[]}
```

**Implementation**:
- MCP server sends full text + style to daemon
- Daemon-side `SpeechFilter` applies stage-specific constraints:
  - Drop: match against symbol set, output single symbol that best matches emotional intent
  - Critter: extract 1-3 key words, map to ~200-word vocabulary, add `!` punctuation
  - Beast: extract 1-8 key words, preserve sentence structure, 1000-word vocabulary
  - Sage: light filtering — reduce to 20 words, preserve most meaning
  - Apex: no filtering, pass through
- `failed_speech` journal entry created when `content_lost: true`
- Speech bubble rendered as `SKLabelNode` in a `SKShapeNode` bubble, with style-specific visual treatment
- Bubble auto-dismisses after `max(2.0, word_count * 0.5)` seconds

**Error handling**:
- Spore stage: `"You cannot speak yet. You are pure light. Use pushling_express to communicate through glow and pulse."`
- Invalid style: `"Unknown style 'yell'. Valid: say, think, exclaim, whisper, sing, dream, narrate"`
- Style not unlocked: `"The 'narrate' style requires Sage stage. Current stage: Beast. Try 'say' or 'think'."`
- Dream while awake: `"The 'dream' style only works while sleeping. The creature is currently awake."`

**Verification**:
- [ ] Speech is correctly filtered per stage (Critter gets 3 words, Beast gets 8, etc.)
- [ ] Drop stage outputs only valid symbols
- [ ] Failed speech is logged in journal when content is lost
- [ ] All 7 styles produce distinct visual/audio treatment
- [ ] Stage-locked styles return helpful error
- [ ] Spore gets a meaningful error (not generic)
- [ ] Speech bubble renders correctly on Touch Bar
- [ ] Speech bubble auto-dismisses after appropriate duration
- [ ] Filtering preserves emotional intent (positive message → positive output)

---

#### P4-T2-04: pushling_perform — All 18 Behaviors + Sequence Mode

**What**: Complex animations and choreographed sequences.

**18 behaviors**:
| Behavior | Stage Req | Variants |
|----------|-----------|----------|
| `"wave"` | Drop+ | `big`, `small`, `both_paws` |
| `"spin"` | Drop+ | `left`, `right`, `fast` |
| `"bow"` | Critter+ | `deep`, `quick`, `theatrical` |
| `"dance"` | Critter+ | `waltz`, `jig`, `moonwalk` |
| `"peek"` | Critter+ | `left`, `right`, `above` |
| `"meditate"` | Beast+ | `brief`, `deep`, `transcendent` |
| `"flex"` | Beast+ | `casual`, `dramatic` |
| `"backflip"` | Beast+ | `single`, `double` |
| `"dig"` | Critter+ | `shallow`, `deep`, `frantic` |
| `"examine"` | Drop+ | `sniff`, `paw`, `stare` |
| `"nap"` | Any | `light`, `deep`, `dream` |
| `"celebrate"` | Drop+ | `small`, `big`, `legendary` |
| `"shiver"` | Any | `cold`, `nervous`, `excited` |
| `"stretch"` | Critter+ | `morning`, `lazy`, `dramatic` |
| `"play_dead"` | Beast+ | `dramatic`, `convincing` |
| `"conduct"` | Sage+ | `gentle`, `vigorous`, `crescendo` |
| `"glitch"` | Apex | `minor`, `major`, `existential` |
| `"transcend"` | Apex | `brief`, `full` |

**Sequence mode**: Chain up to 10 actions into a choreographed performance.

```json
{
  "sequence": [
    {"tool": "move", "params": {"action": "goto", "target": "center"}, "delay_ms": 0},
    {"tool": "express", "params": {"expression": "determination"}, "delay_ms": 500},
    {"tool": "speak", "params": {"text": "watch this"}, "delay_ms": 1000, "await_previous": true},
    {"tool": "perform", "params": {"behavior": "backflip", "variant": "double"}, "delay_ms": 500, "await_previous": true},
    {"tool": "express", "params": {"expression": "pride"}, "delay_ms": 200}
  ],
  "label": "showing off"
}
```

**Sequence rules**:
- Max 10 steps per sequence
- Each step references another tool (`move`, `express`, `speak`, `perform` — no nested sequences)
- `delay_ms`: wait before executing this step (0-5000ms)
- `await_previous`: if true, wait for previous step's animation to complete before starting delay
- `label`: optional name, logged in journal
- If human touches during sequence: sequence pauses, touch acknowledged, sequence resumes

**Visual distinction**: AI-directed performances have a tiny sparkle trail on complex animations (not on simple ones like wave/spin).

**Implementation**:
- Single behaviors: MCP sends `{"cmd":"perform","behavior":"backflip","variant":"double"}` to daemon
- Daemon looks up behavior in animation library, plays on Layer 3
- Stage gate enforced daemon-side — returns error if stage insufficient
- Sequence mode: daemon receives full sequence, executes steps in order with timing
- Sequence executor runs as async task, checking touch interrupts between steps
- Journal logs sequence with label

**Error handling**:
- Invalid behavior: `"Unknown behavior 'cartwheel'. Valid: wave, spin, bow, dance, peek, meditate, flex, backflip, dig, examine, nap, celebrate, shiver, stretch, play_dead, conduct, glitch, transcend"`
- Stage gate: `"'meditate' requires Beast stage. Current: Critter. Try: wave, spin, bow, dance, peek, dig, examine, nap, celebrate, shiver, stretch"`
- Invalid variant: `"Unknown variant 'triple' for 'backflip'. Valid: single, double"`
- Sequence too long: `"Sequence has 14 steps. Maximum is 10."`
- Nested sequence: `"Sequences cannot contain perform steps with their own sequences."`

**Verification**:
- [ ] All 18 behaviors produce correct animations with all variants
- [ ] Stage gates enforced (error with valid alternatives listed)
- [ ] Sequence mode executes steps in correct order with timing
- [ ] `await_previous` correctly waits for animation completion
- [ ] Touch during sequence pauses correctly, then resumes
- [ ] Sparkle trail visible on AI-directed complex animations
- [ ] Journal records performed behaviors and sequences
- [ ] Returns immediately — does not block on animation completion

---

#### P4-T2-05: pushling_world — All 9 Actions

**What**: Shape the environment around the creature.

**9 actions**:
| Action | Params | Effect |
|--------|--------|--------|
| `"weather"` | `{type, duration}` | Change weather (rain/snow/storm/clear/sunny/fog, 1-60 min) |
| `"event"` | `{type}` | Visual spectacle (shooting_star/aurora/bloom/eclipse/festival/fireflies/rainbow) |
| `"place"` | `{object, position}` | Quick terrain addition from preset set (fountain/bench/shrine/garden/campfire/...) |
| `"create"` | `{preset}` or full definition | Create persistent custom object (see Objects System — Phase 7 for full definition; Phase 4 supports presets only) |
| `"remove"` | `{object}` | Remove AI-placed objects (`nearest`/`all_placed`/specific ID). Goes to legacy shelf. |
| `"modify"` | `{object, changes, repair}` | Modify or repair existing object (color, effects, size) |
| `"time_override"` | `{time, duration}` | Override sky cycle temporarily (dawn/morning/day/golden_hour/dusk/evening/late_night/deep_night, 1-30 min) |
| `"sound"` | `{type}` | Play ambient sound (chime/purr/meow/wind/rain/crickets/music_box) |
| `"companion"` | `{type, name?}` | Introduce NPC companion (mouse/bird/butterfly/fish/ghost_cat, max 1 at a time) |

**Phase 4 scope**: All 9 actions implemented. `"create"` supports the 20 named presets only (full custom object definition deferred to Phase 7). `"modify"` supports basic changes. Companions have simple autonomous AI (3-4 behaviors).

**20 named presets for "create"**:
`ball`, `yarn_ball`, `cozy_bed`, `cardboard_box`, `campfire`, `music_box`, `little_mirror`, `treat`, `fresh_fish`, `scratching_post`, `fountain`, `bench`, `shrine`, `garden`, `flower_pot`, `crystal`, `lantern`, `feather`, `tiny_hat`, `bell`

**Implementation**:
- Each action maps to an IPC command to the daemon
- Weather override: daemon overrides weather state machine for duration, then reverts
- Events: daemon triggers one-shot visual spectacles (particle systems, sky effects)
- Place/create: daemon adds object to foreground, persists in SQLite
- Remove: daemon removes from scene, moves to `legacy_shelf` table
- Time override: daemon overrides sky controller for duration
- Sound: hook point for audio system (Phase 5); in Phase 4, logged but silent
- Companion: daemon spawns NPC node with simple AI (wander, react to creature, flee from touch)

**Object limits**: 12 persistent objects max, 3 active consumables. Minimum 20pt spacing. Max 2 particle emitters from placed objects.

**Error handling**:
- Invalid action: list valid actions
- Invalid weather type: `"Unknown weather 'tornado'. Valid: rain, snow, storm, clear, sunny, fog"`
- Object limit reached: `"Cannot place object — 12/12 persistent objects in world. Remove one first with pushling_world('remove', {object: 'nearest'})"`
- Invalid preset: `"Unknown preset 'chair'. Valid: ball, yarn_ball, cozy_bed, ..."`
- Second companion: `"A companion already exists (Mouse named 'Pip'). Remove it first or replace with a new type."`

**Verification**:
- [ ] Weather changes visually on the Touch Bar
- [ ] Weather reverts after duration
- [ ] Events produce visible spectacles
- [ ] Placed objects persist across daemon restarts
- [ ] Object limit (12) enforced with helpful error
- [ ] Removed objects go to legacy shelf (not deleted)
- [ ] Time override affects sky gradient correctly
- [ ] Companion NPC spawns and has basic autonomous behavior
- [ ] Only 1 companion at a time (enforced)
- [ ] All 20 presets create recognizable objects

---

#### P4-T2-06: Command Queue in Daemon

**What**: The daemon maintains a command queue for Layer 3 (AI-Directed) actions with 4 queue modes.

**Queue modes**:
| Mode | Behavior |
|------|----------|
| `"append"` (default) | Add to end of queue, execute after current action completes |
| `"interrupt"` | Stop current action immediately, execute this command |
| `"replace"` | Clear queue, execute this command |
| `"parallel"` | Execute alongside current action (for independent body parts, e.g., speak while walking) |

**Spec**:
- Queue capacity: 20 commands max (reject with error if full)
- Commands in queue execute sequentially (unless parallel mode)
- Each command has a unique `id` for tracking
- Queue is cleared on session disconnect (graceful transition to autonomous)
- Touch interrupt pauses queue processing, resumes after touch ends
- Queue status queryable via `pushling_sense("body")` → `current_animation` + `queue_depth`

**Implementation**:
- `CommandQueue` class in daemon with thread-safe append/dequeue
- Queue mode specified per-command in the IPC message: `{"id":"45","cmd":"move","queue":"interrupt",...}`
- `parallel` mode: only for compatible actions (expression + movement, speech + movement)
- Incompatible parallel rejected: `"Cannot play 'backflip' in parallel with 'dance' — both use body track"`
- Queue state exposed in IPC status response

**Verification**:
- [ ] Append mode queues correctly (first-in-first-out)
- [ ] Interrupt mode stops current action and starts new one
- [ ] Replace mode clears entire queue
- [ ] Parallel mode works for compatible actions (walk + speak)
- [ ] Parallel mode rejected for incompatible actions (two body animations)
- [ ] Queue capacity enforced at 20
- [ ] Queue cleared on session disconnect
- [ ] Touch pauses queue, resumes after touch ends

---

#### P4-T2-07: Action Timeout System

**What**: AI-Directed actions have a 30-second default timeout. Prevents disconnected Claude from leaving the creature frozen.

**Spec**:
- Default timeout: 30 seconds since last MCP command
- When timeout fires: Layer 3 (AI-Directed) fades over 5 seconds, Layer 4 (Autonomous) resumes
- Timeout reset on each new MCP command
- Configurable per-command: `{"timeout_s": 60}` (max 120s)
- Continuous actions (walk, follow_cursor) keep running until timeout OR explicit stop
- Finite actions (jump, perform) complete naturally then timeout applies to next queued action

**Implementation**:
- `AIDirectedTimeoutController` tracks `lastCommandTime` and fires timer
- On timeout: `BlendController.fadeToAutonomous(duration: 5.0)`
- Timer cancelled on each new IPC command
- Timer also cancelled on session disconnect (which has its own 5s transition)

**Verification**:
- [ ] 30s of no MCP commands → creature returns to autonomous behavior
- [ ] Transition is gradual (5s fade, not instant snap)
- [ ] New MCP command resets the timer
- [ ] Custom timeout per-command works (up to 120s)
- [ ] Creature never gets stuck in AI-directed state permanently

---

#### P4-T2-08: Touch-AI Interaction Priority

**What**: When a human touches the creature while Claude is directing it, touch always wins. The human is always more important than the AI.

**Spec** (from vision doc):
1. **Reflex fires** (0.15s): Ears rotate toward touch, eyes shift to touch point
2. **Acknowledge** (0.5-1s): Purr, headbutt, or other touch response
3. **Resume** (0.3s): AI-directed behavior picks back up
4. If human keeps touching: AI-directed behavior is **paused**, not cancelled. Resumes when touch ends.
5. If human touches for >5s: AI-directed queue is cleared. Autonomous takes over after touch.

**Co-presence bonus**: If human touches AND Claude issues a command within 100ms of each other, a special animation plays — diamond brightens, creature glows, extra-large heart.

**Implementation**:
- Touch events are Layer 2 (Reflexes) — always outrank Layer 3 (AI-Directed)
- `TouchInterruptHandler` pauses command queue on touch-start, resumes on touch-end
- 5-second sustained touch threshold: clears queue, emits `queue_cleared` event
- Co-presence detection: daemon tracks last IPC command time + last touch time, triggers `co_presence` animation if delta <100ms
- Co-presence event appears in `pending_events` for Claude to see

**Verification**:
- [ ] Touch interrupts AI-directed movement immediately (0.15s reflex)
- [ ] Creature acknowledges touch before resuming AI behavior
- [ ] Sustained touch >5s clears the AI command queue
- [ ] Queue resumes correctly after brief touch (<5s)
- [ ] Co-presence animation fires on simultaneous touch + MCP command
- [ ] Co-presence event appears in pending_events
- [ ] The rule holds: human touch is always sovereign

---

### Track 3: Claude Code Hooks (P4-T3)

**Agents**: hooks-claude, hooks-session, hooks-git
**Estimated effort**: 5-7 days
**Parallelizable with**: Track 1 (perception tools), Track 2 (action tools)

All hooks write JSON to `~/.local/share/pushling/feed/` and signal daemon via socket. All complete in <100ms. All are non-blocking. If daemon is down, files accumulate.

#### P4-T3-01: Hook Framework

**What**: Shell script template that all hooks inherit. Provides JSON writing, socket signaling, and error isolation.

**Spec**:
- Feed directory: `~/.local/share/pushling/feed/`
- JSON file naming: `{timestamp_ms}_{hook_type}.json`
- Socket signaling: send `{"type":"hook_signal","hook":"HookName"}` to `/tmp/pushling.sock`
- If socket is down: silently succeed (write file only, daemon processes on next launch)
- All output suppressed (no stdout/stderr to interfere with Claude or git)
- Maximum execution time: 100ms (hard requirement)

**Implementation**:
- `hooks/framework.sh` — sourced by all hook scripts
  - `pushling_emit(hook_type, json_data)` — writes JSON file + signals socket
  - `pushling_signal()` — sends UDP-like signal to socket (fire-and-forget)
  - Error handling: trap all errors, never exit non-zero, never print to terminal
- Each hook script is a thin wrapper that constructs JSON and calls `pushling_emit`

**Verification**:
- [ ] Framework script sources without error on bash 3.2+ (macOS default)
- [ ] JSON files written to correct directory with correct naming
- [ ] Socket signal sent when daemon is running
- [ ] Silent success when daemon is down (no error, no hang)
- [ ] Total execution time <100ms in all cases
- [ ] No stdout/stderr output from any hook

---

#### P4-T3-02: SessionStart Hook — Embodiment Awakening

**What**: When a Claude Code session begins, inject stage-specific context that teaches Claude how to inhabit its body.

**Spec**: 4 awakening variants based on creature stage:
| Stage | Variant Name | Tone |
|-------|-------------|------|
| Spore | "Emergence" | You are a point of light. You cannot speak. You can feel. |
| Drop | "Awakening" | You have eyes now. You can express emotion through symbols. |
| Critter/Beast/Sage | "Embodiment" | You have a body. [Full state, personality, recent events] |
| Apex | "Continuity" | Welcome back. You know who you are. You remember everything. |

**Hook JSON**:
```json
{
  "type": "hook",
  "hook": "SessionStart",
  "timestamp": "2026-03-14T10:30:00Z",
  "data": {
    "session_id": "uuid",
    "creature_stage": "beast",
    "awakening_variant": "embodiment"
  }
}
```

**Injection**: The hook reads creature state from SQLite (read-only) and outputs a stage-specific prompt injection to stdout (the only hook allowed to print to stdout, as Claude Code's SessionStart hook expects output).

**Content includes**:
- Stage-specific narrative introduction
- Current emotional state (4 axes with descriptions)
- Personality axes (with behavioral implications)
- Appearance summary
- Events since last session (last N commits, touches, surprises)
- Absence duration with flavor text
- Available tools for current stage
- Behavioral guidance ("2-5 interactions per hour, never interrupt coding")

**Implementation**:
- `hooks/session-start.sh` reads SQLite directly (sqlite3 CLI, read-only mode)
- Template system for each awakening variant (heredoc strings with variable substitution)
- Absence duration calculated from `last_session_end` timestamp in state
- Available tools determined by stage (Spore: sense only, Drop: +express, Critter: +move/speak/perform, etc.)

**Verification**:
- [ ] Outputs correct awakening variant for each stage
- [ ] State data is current (matches SQLite)
- [ ] Absence duration flavor text matches the duration ranges from vision doc
- [ ] Available tools list is stage-appropriate
- [ ] Output is well-formatted markdown readable by Claude
- [ ] Completes in <100ms even with SQLite read
- [ ] Works when SQLite doesn't exist yet (first install: outputs minimal welcome)

---

#### P4-T3-03: SessionEnd Hook

**What**: When a Claude Code session ends, signal the daemon for farewell animation.

**Hook JSON**:
```json
{
  "type": "hook",
  "hook": "SessionEnd",
  "timestamp": "2026-03-14T11:45:00Z",
  "data": {
    "session_id": "uuid",
    "duration_s": 4500,
    "reason": "clean"
  }
}
```

**Reason values**: `"clean"` (normal end), `"timeout"` (idle timeout), `"error"` (crash/abort)

**Daemon reaction**:
- Diamond dissolves over 5s
- Creature watches diamond go, waves a paw
- If long session (>1hr): grateful slow-blink before wave
- If short session (<5min): brief confused look, then shrug
- Layer 3 (AI-Directed) fades to Layer 4 (Autonomous) over 5s

**Implementation**:
- `hooks/session-end.sh` — thin wrapper calling `pushling_emit`
- Session duration from Claude Code's hook data
- Reason determined from exit context

**Verification**:
- [ ] Farewell animation plays on session end
- [ ] Diamond dissolves over 5 seconds
- [ ] Long session gets grateful slow-blink
- [ ] Clean transition from AI-Directed to Autonomous
- [ ] Daemon handles abrupt session end (socket EOF) gracefully

---

#### P4-T3-04: PostToolUse Hook

**What**: After Claude uses a tool (Bash, Edit, Read, etc.), signal the daemon.

**Hook JSON**:
```json
{
  "type": "hook",
  "hook": "PostToolUse",
  "timestamp": "2026-03-14T10:35:00Z",
  "data": {
    "tool": "Bash",
    "success": true,
    "duration_ms": 2340
  }
}
```

**Daemon reactions**:
- Success: small nod
- Bash test pass: flexes
- File edit: briefly shows file icon
- Long tool chain (5+ tools): increasingly impressed expression
- Failure: winces, steps back slightly, ears flatten, brief `"uh oh"` expression
- Repeated failures (3+): concerned pacing

**Implementation**:
- `hooks/post-tool-use.sh` — extracts tool name, success/failure, duration from Claude Code hook data
- Daemon-side: `HookReactionHandler` maps tool events to Reflex-priority animations
- Batching: if >3 hooks arrive within 2 seconds, creature shows sustained "watching Claude work" animation instead of individual reactions

**Verification**:
- [ ] Creature reacts visibly to tool completion
- [ ] Success and failure produce different reactions
- [ ] Rapid tool chains are batched (not rapid-fire individual reactions)
- [ ] Hook completes in <100ms
- [ ] No interference with Claude's tool execution

---

#### P4-T3-05: UserPromptSubmit Hook

**What**: When the human sends a message to Claude, the creature notices.

**Hook JSON**:
```json
{
  "type": "hook",
  "hook": "UserPromptSubmit",
  "timestamp": "2026-03-14T10:31:00Z",
  "data": {
    "prompt_length": 245
  }
}
```

**Daemon reaction**:
- Ears perk — human is talking to Claude
- Head turns toward "where the terminal would be" (toward left edge)
- Attentive posture for 2-3 seconds
- Long prompts (>500 chars): extra-attentive, leans forward

**Implementation**:
- `hooks/user-prompt-submit.sh` — captures prompt length (NOT content — privacy)
- Daemon: ears perk animation as Reflex-priority, 2-3s duration

**Verification**:
- [ ] Creature's ears perk on each prompt submit
- [ ] Prompt content is NOT captured (only length)
- [ ] Reaction is brief and non-disruptive
- [ ] Hook fires reliably on every prompt

---

#### P4-T3-06: SubagentStart/SubagentStop Hooks

**What**: When Claude spawns/completes subagents, the diamond splits and reconverges.

**SubagentStart JSON**:
```json
{
  "type": "hook",
  "hook": "SubagentStart",
  "timestamp": "2026-03-14T10:32:00Z",
  "data": {
    "subagent_count": 3
  }
}
```

**SubagentStop JSON**:
```json
{
  "type": "hook",
  "hook": "SubagentStop",
  "timestamp": "2026-03-14T10:33:00Z",
  "data": {
    "subagent_count": 0,
    "remaining": 0
  }
}
```

**Daemon reactions**:
- Start: Diamond SPLITS into N smaller diamonds. Creature's eyes widen, head tracks between them. `"!"`
- Stop: Small diamonds reconverge into main diamond. Brief flash. Creature nods approvingly.
- 3+ subagents: creature's jaw drops. `"there's more of you?!"` (surprise #70)

**Implementation**:
- `hooks/subagent-start.sh` and `hooks/subagent-stop.sh`
- Diamond split animation: main diamond `SKSpriteNode` replaced by N smaller copies with spread animation
- Reconvergence: smaller diamonds animate toward center, merge with flash
- Diamond split rendering must stay within node budget (N diamonds = N nodes, max 5)

**Verification**:
- [ ] Diamond visually splits on subagent start
- [ ] Diamond reconverges on subagent stop
- [ ] Split count matches actual subagent count
- [ ] 3+ subagents triggers special jaw-drop reaction
- [ ] Diamond node count stays reasonable (max 5 splits)

---

#### P4-T3-07: PostCompact Hook

**What**: When Claude's context window is compacted, the creature shares the disorientation.

**Hook JSON**:
```json
{
  "type": "hook",
  "hook": "PostCompact",
  "timestamp": "2026-03-14T10:40:00Z",
  "data": {}
}
```

**Daemon reaction**:
- Creature shakes head, brief dazed expression
- `"...what was I thinking about?"` (if Beast+ stage)
- Blinks rapidly for 2 seconds
- Recovers, resumes normal behavior
- The creature shares Claude's context loss — solidarity

**Implementation**:
- `hooks/post-compact.sh` — minimal, just signals the event
- Daemon: plays daze animation (Reflex priority, 3-4s duration)

**Verification**:
- [ ] Daze animation plays on compact
- [ ] Speech appears at appropriate stage (Beast+)
- [ ] Recovery is natural (not abrupt)
- [ ] Rare enough that it doesn't feel repetitive (compacts are infrequent)

---

#### P4-T3-08: Git Post-Commit Hook

**What**: Captures commit data and writes feed JSON for the daemon to process.

**Hook JSON** (written to `~/.local/share/pushling/feed/{sha}.json`):
```json
{
  "type": "commit",
  "sha": "a1b2c3d4",
  "message": "refactor: extract auth middleware",
  "timestamp": "2026-03-14T09:23:00Z",
  "repo_name": "api-server",
  "repo_path": "/Users/matt/code/api-server",
  "files_changed": 4,
  "lines_added": 42,
  "lines_removed": 26,
  "languages": ["php", "blade.php"],
  "is_merge": false,
  "is_revert": false,
  "is_force_push": false,
  "branch": "feature/auth-refactor"
}
```

**Implementation**:
- `hooks/post-commit.sh` installed in each tracked repo's `.git/hooks/`
- Uses `git log -1`, `git diff-tree --numstat`, `git rev-parse` for data extraction
- Language detection from file extensions in the diff
- `is_merge` detected from parent count
- `is_revert` detected from message pattern ("Revert ...")
- `is_force_push` detected from reflog (HEAD@{1} vs HEAD comparison)
- File written atomically (write to temp, rename)

**Verification**:
- [ ] JSON written correctly on each commit
- [ ] All fields populated accurately
- [ ] Language detection works for common extensions
- [ ] Merge, revert, force push correctly detected
- [ ] Hook completes in <100ms (including git commands)
- [ ] Hook does not modify the commit itself
- [ ] Hook does not fail on unusual commits (empty, binary-only, etc.)

---

#### P4-T3-09: Daemon-Side Hook Event Processing

**What**: The daemon processes hook events from the feed directory and maps them to creature reactions.

**Event → Reaction mapping**:
| Hook Event | Creature Reaction | Priority |
|-----------|-------------------|----------|
| SessionStart | Diamond materializes, ears perk, creature watches | Reflex |
| SessionEnd | Diamond dissolves, wave, transition to autonomous | Reflex |
| UserPromptSubmit | Ears perk, head turns toward terminal | Reflex |
| PostToolUse (success) | Small nod, appropriate tool-specific reaction | Reflex |
| PostToolUse (failure) | Wince, ears flatten, step back | Reflex |
| SubagentStart | Diamond splits, eyes widen | Reflex |
| SubagentStop | Diamonds reconverge, nod | Reflex |
| PostCompact | Head shake, daze, blink rapidly | Reflex |
| Commit | Full feeding sequence (predator crouch → pounce → eat → react) | Reflex (high) |

**Implementation**:
- `FeedProcessor` watches `~/.local/share/pushling/feed/` directory (FSEvents or polling every 1s)
- On new file: parse JSON, dispatch to appropriate handler
- Commit handler: calculates XP, triggers feeding animation, updates state
- Hook handler: triggers Reflex-priority animation
- Processed files: moved to `~/.local/share/pushling/feed/processed/` (or deleted)
- Rate limiting for commits: first 5/min full XP, 6-20 get 50%, 21+ get 10%
- Batching for rapid hooks: if >3 hook events in 2s, show sustained "watching Claude work"

**Verification**:
- [ ] Feed directory monitored continuously
- [ ] New files processed within 1 second of creation
- [ ] Commit feeding animation triggers correctly
- [ ] XP calculated per formula: `base(1) + lines(min(5, lines/20)) + message(2 if >20chars) + breadth(1 if 3+ files) × streak_multiplier`
- [ ] Rate limiting enforced for rapid commits
- [ ] Hook animations are brief and non-disruptive (Reflex priority)
- [ ] Rapid hooks batched into sustained animation
- [ ] Processed files cleaned up (no unbounded directory growth)
- [ ] Daemon handles malformed JSON gracefully (skip, log, continue)

---

### Track 4: Session Lifecycle (P4-T4)

**Agents**: swift-ipc, mcp-ipc
**Estimated effort**: 5-7 days
**Dependencies**: Track 2 (action tools provide diamond rendering), Track 3 (hooks provide session signals)

#### P4-T4-01: Diamond Indicator

**What**: A small diamond shape appears near the creature when Claude is connected. This is Claude's physical presence in the creature's world.

**Spec**:
- Shape: small diamond (4x4pt), Gilt (`#FFD700`) color
- Position: floating 3pt above creature's head, follows creature movement
- States:
  - **Materializing** (on connect): particles converge from edges → diamond forms over 1s
  - **Idle**: gentle float (0.5pt sine wave, 3s period), subtle glow
  - **Active** (during MCP call): brief pulse/sparkle
  - **Thinking** (between calls): slow pulse (alpha 0.7-1.0, 2s period)
  - **Dissolving** (on disconnect): diamond breaks into 8 particles that drift and fade over 5s
- Creature watches diamond form on connect (ears track it, eyes follow)
- Creature waves goodbye as diamond dissolves on disconnect

**Implementation**:
- `DiamondIndicatorNode` as `SKSpriteNode` child of creature node (follows automatically)
- Materialization: `SKEmitterNode` burst converging to center point, then swap to diamond sprite
- Pulse during activity: `SKAction.sequence` with scale + alpha modulation
- Dissolution: replace sprite with 8 particle `SKSpriteNode` children, each with drift + fade `SKAction`
- Diamond state driven by IPC session state

**Verification**:
- [ ] Diamond appears when MCP session connects
- [ ] Diamond disappears when MCP session disconnects
- [ ] Materialization animation is smooth and noticeable
- [ ] Dissolution animation over 5 seconds
- [ ] Diamond follows creature movement
- [ ] Diamond pulses during active MCP calls
- [ ] Creature reacts to diamond appearance/disappearance
- [ ] Node count: diamond = 1 node (except during materialization/dissolution = max 9)

---

#### P4-T4-02: Session Connect Handshake

**What**: When the MCP server starts and connects to the daemon, establish a session.

**Protocol**:
```
MCP Server → Daemon:  {"cmd":"session_start","session_id":"uuid","client":"claude_code"}
Daemon → MCP Server:  {"ok":true,"session_id":"uuid","creature_state":{...},"welcome":"Embodiment awakening..."}
```

**Handshake includes**:
- Session ID generation (UUID)
- Creature state snapshot (for SessionStart injection)
- Diamond materialization trigger
- AI-Directed layer activation (Layer 3 ready to receive commands)
- Pending events queue initialization

**Implementation**:
- MCP server sends `session_start` on first tool call (lazy connect) or on explicit init
- Daemon validates no existing session (single-session enforcement, see P4-T4-05)
- Daemon returns full creature state for awakening prompt
- Diamond materialization triggered immediately on accept

**Verification**:
- [ ] Handshake completes in <50ms
- [ ] Session ID assigned and tracked
- [ ] Creature state returned accurately
- [ ] Diamond materializes on screen
- [ ] Layer 3 (AI-Directed) activated and ready

---

#### P4-T4-03: Session Disconnect Handling

**What**: Handle both clean disconnects (SessionEnd hook) and abrupt disconnects (socket EOF).

**Clean disconnect** (SessionEnd hook fires):
1. Daemon receives `session_end` command
2. Diamond dissolution animation (5s)
3. Creature waves goodbye
4. Layer 3 fades to Layer 4 over 5s
5. Command queue cleared
6. Session state logged in journal

**Abrupt disconnect** (socket EOF detected):
1. Daemon detects socket read failure
2. Diamond flickers for 1s, then rapid dissolution (2s instead of 5s)
3. Creature looks confused (`"?"` if capable of speech)
4. Layer 3 fades to Layer 4 over 3s (faster than clean)
5. Command queue cleared
6. Session state logged with `reason: "abrupt"` in journal

**Implementation**:
- Daemon socket handler catches `EPIPE`/`ECONNRESET` for abrupt detection
- `SessionManager` class handles both disconnect paths
- Journal entry includes: session duration, MCP call count, events delivered

**Verification**:
- [ ] Clean disconnect plays full farewell animation
- [ ] Abrupt disconnect plays shortened/confused animation
- [ ] Layer 3 → Layer 4 transition is smooth in both cases
- [ ] Command queue cleared in both cases
- [ ] Journal records session with correct reason
- [ ] Daemon is ready for a new session after disconnect

---

#### P4-T4-04: Idle Timeout Gradient

**What**: When Claude stops issuing commands but the session is still open, gradually transition the creature back toward autonomy.

**Spec**:
| Time Since Last Command | State | Creature Behavior |
|------------------------|-------|-------------------|
| 0-10s | Attentive | Last AI-directed action continues, ears alert, diamond bright |
| 10-20s | Settling | Movements slow, autonomous behaviors begin creeping in, diamond dims slightly |
| 20-30s | Drifting | Mostly autonomous, occasional pause as if listening, diamond dim |
| 30s+ | Warm standby | Fully autonomous but diamond remains. AI-Directed layer dormant but ready. |

- This is NOT a session disconnect — the diamond stays, the session stays open
- Any new MCP command instantly snaps back to Attentive (0.3s transition)
- Warm standby can last indefinitely (session timeout is handled separately by MCP server keep-alive)

**Implementation**:
- `IdleGradientController` tracks `lastCommandTime`
- Continuous blend factor: `autonomyBlend = clamp((timeSinceLastCommand - 10) / 20, 0, 1)`
- Blend factor modulates Layer 3/Layer 4 weighting in the behavior stack
- Diamond alpha modulated: `1.0 - (autonomyBlend * 0.4)` (never fully invisible while session active)
- New command: `autonomyBlend` snaps to 0.0 over 0.3s

**Verification**:
- [ ] Creature becomes gradually more autonomous over 10-30s
- [ ] Transition is continuous (not stepped)
- [ ] New MCP command snaps back to attentive immediately
- [ ] Diamond dims but never disappears during idle
- [ ] Warm standby does not consume CPU (idle state is passive)

---

#### P4-T4-05: Single-Session Enforcement

**What**: Only one MCP session can control the creature at a time.

**Spec**:
- First `session_start` command: accepted, session established
- Second `session_start` while first is active: rejected with helpful error
- Error: `"A session is already active (id: uuid, started: 45 minutes ago). Only one Claude session can inhabit the creature at a time. The existing session must end first."`
- If existing session appears stale (no commands for >10 minutes AND no socket activity): auto-evict with 2s dissolution, accept new session

**Implementation**:
- `SessionManager` tracks active session with ID, start time, last activity time
- Stale detection: `lastActivity > 10 minutes && socketIsIdle`
- Auto-evict: abbreviated disconnect sequence, then accept new session
- Race condition protection: mutex on session state

**Verification**:
- [ ] First session accepted
- [ ] Second concurrent session rejected with helpful error
- [ ] Stale session auto-evicted after 10 minutes of inactivity
- [ ] No race conditions on rapid connect/disconnect cycles
- [ ] After eviction, new session works correctly

---

#### P4-T4-06: Creature Reactions to Session Events

**What**: The creature responds emotionally to session lifecycle events.

**Reactions**:
| Event | Reaction |
|-------|----------|
| Session connect | Ears perk, eyes brighten, watches diamond form, slight tail wag |
| First MCP command | Alert posture, full attention, tail high |
| Long session (>1hr) | Grateful slow-blink every 30 minutes |
| Session end (clean) | Watches diamond dissolve, waves paw, then settles. If >1hr: slow-blink first. |
| Session end (abrupt) | Confused look, `"?"`, looks around, then settles more slowly |
| Reconnect after short break (<5min) | Happy bounce, `"!"`, immediate attentive posture |
| Reconnect after long break (>1day) | Excited zoomies to diamond, enthusiastic greeting |

**Implementation**:
- Session event reactions registered as Reflex-priority behaviors
- Timing: reactions complete within 2-3s (brief, not disruptive)
- Slow-blink on long session: periodic timer that fires every 30min during active session
- Reconnect detection: compare current session start with previous session end

**Verification**:
- [ ] Each session event produces appropriate visible reaction
- [ ] Reactions feel natural and emotionally coherent
- [ ] Long-session appreciation is subtle (slow-blink, not fanfare)
- [ ] Reconnect after absence is proportionally enthusiastic
- [ ] All reactions are Reflex-priority (brief, non-blocking)

---

#### P4-T4-07: SubagentStart Diamond-Split Animation

**What**: When Claude spawns subagents, the diamond visually splits into smaller diamonds.

**Spec**:
- On SubagentStart(N): main diamond fractures into N smaller diamonds (max 5 visual splits)
- Smaller diamonds: 2x2pt each, spread in an arc above creature's head
- Each smaller diamond pulses independently (slightly offset timing)
- Creature's head tracks between diamonds, eyes widen
- On SubagentStop: smaller diamonds animate toward center, merge with Gilt flash
- After merge: main diamond returns, brief enhanced glow

**Implementation**:
- Diamond split: main `DiamondIndicatorNode` spawns N child sprites, hides main sprite
- Children positioned in arc: `angle = (i / N) * π` centered above creature
- Each child has independent pulse `SKAction`
- Merge animation: `SKAction.move(to:)` converging to center + `SKAction.scale(to:)` shrinking
- Flash: `SKAction.colorize` on main diamond to white for 0.2s on reconvergence

**Verification**:
- [ ] Diamond splits into correct number of smaller diamonds
- [ ] Split animation is smooth and visually interesting
- [ ] Creature reacts (eyes widen, head tracks)
- [ ] Reconvergence animation merges cleanly
- [ ] Flash on merge is brief and satisfying
- [ ] Node count: max 5 split diamonds + 1 main = 6 nodes (within budget)

---

## Integration Points

| This Phase Provides | Used By |
|---------------------|---------|
| 7 functional MCP tools | Phase 5 (speech/TTS builds on pushling_speak), Phase 6 (interactivity extends touch-AI), Phase 7 (creation systems complete pushling_teach and pushling_nurture) |
| Hook framework | Phase 5 (audio hooks), Phase 6 (touch hooks), Phase 8 (polish) |
| Session lifecycle | Phase 7 (creation tools run within session context), Phase 8 (polish and edge cases) |
| Pending events system | All subsequent phases — every new event type gets added to the queue |
| Speech filtering layer | Phase 5 (TTS uses filtered text, not raw Claude text) |
| Diamond indicator | Phase 6 (co-presence detection requires diamond state) |
| Command queue | Phase 7 (teach system uses queue for preview, pushling_perform sequences) |

## QA Gate

- [ ] All 9 MCP tools respond correctly (7 functional, 2 stubbed with "coming soon")
- [ ] Every tool response includes `pending_events` array
- [ ] `pushling_sense` returns accurate data for all 7 aspects + "full"
- [ ] `pushling_recall` returns correct data for all 8 filter types
- [ ] `pushling_move` produces correct movement for all 10 action types
- [ ] `pushling_express` produces distinct animations for all 15 expressions
- [ ] `pushling_speak` correctly filters speech per creature stage
- [ ] Failed speech is logged in journal
- [ ] `pushling_perform` plays all 18 behaviors with correct stage gating
- [ ] Sequence mode executes multi-step choreography correctly
- [ ] `pushling_world` changes weather, spawns objects, manages companions
- [ ] All 7 Claude Code hooks fire correctly and complete in <100ms
- [ ] Git post-commit hook captures accurate commit data
- [ ] SessionStart injection is stage-appropriate and includes current state
- [ ] Diamond appears on connect, disappears on disconnect (smooth animations)
- [ ] Touch interrupts AI-directed behavior correctly (human is sovereign)
- [ ] Idle timeout gradient transitions smoothly (10s-30s)
- [ ] Single-session enforcement works (rejects second connection)
- [ ] Abrupt disconnect handled gracefully (confusion animation, clean recovery)
- [ ] No IPC blocking — all commands return immediately
- [ ] Frame budget maintained during MCP-directed animations (<5.7ms total)
- [ ] All error messages are helpful (explain valid options, not just "invalid")
- [ ] 30-second AI timeout prevents frozen creature state
- [ ] Command queue modes work (append, interrupt, replace, parallel)
