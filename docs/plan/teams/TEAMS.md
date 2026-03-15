# Team Definitions

## Team A: Development Agents

Development agents are specialized by technology and domain. Each agent owns specific files/directories (see `PLAN.md` File Ownership table) and produces working, testable increments.

### Swift Agents (Pushling.app)

- **swift-scaffold**: Project setup, Xcode config, build system, private API integration
  - Creates Xcode project with correct targets and signing
  - Integrates `presentSystemModalTouchBar` private API for Touch Bar takeover
  - Configures menu-bar daemon (LSUIElement, no dock icon)
  - Sets up LaunchAgent for auto-start on login
  - Establishes build pipeline and dependency management
  - Owns: `Pushling/App/`, `Pushling.xcodeproj`

- **swift-scene**: SpriteKit scene, camera, rendering pipeline, frame budget management
  - Creates SKScene at 1085x30 points (2170x60 @2x Retina)
  - Implements SKView in NSCustomTouchBarItem
  - Sets up camera system for parallax scrolling
  - Manages render layers (far 0.15x, mid 0.4x, fore 1.0x)
  - Enforces frame budget (<5.7ms total, ~2ms for render)
  - Monitors node count (<120 target)
  - Owns: `Pushling/Scene/`

- **swift-creature**: Creature composite node, body parts, animation state machine
  - Builds composite SKNode with independent body parts: body, head, ears (2), tail, eyes (2), whiskers (2+), mouth, paws (4), aura, particles
  - Implements all 6 growth stage visuals with correct sizes (6x6 to 25x28 pts)
  - Sine-wave breathing (Y-scale 1.0-1.03, 2.5s period) — NEVER stops
  - Blink cycle (3-7s interval), tail sway, whisker twitch
  - Walk cycle, run cycle, sneak cycle
  - All 12 cat behaviors: slow-blink, kneading, headbutt, tail twitch, ear perk, zoomies, grooming, predator crouch, loaf, chattering, if-I-fits-I-sits, knocking things off
  - Stage transition 5-second ceremonies (stillness, gathering, cocoon, burst, reveal)
  - Ghost echo of younger form (Sage+, alpha 0.08)
  - Puddle reflection (1-pixel mirrored silhouette)
  - Owns: `Pushling/Creature/` (shared with swift-behavior)

- **swift-world**: Terrain generation, parallax, weather, biomes, repo landmarks
  - Procedural terrain from integer noise with 5 biomes (plains, forest, desert, wetlands, mountains)
  - 50-unit gradient transitions between biomes
  - 8-14 terrain objects visible at any time (grass, flowers, trees, mushrooms, rocks, water, star fragments, ruins, yarn balls, boxes)
  - Repo landmark silhouettes in mid-background (9 types based on repo content detection)
  - Weather state machine: Clear 60%, Cloudy 20%, Rain 12%, Storm 5%, Snow 3%
  - Rain as individual 1x2pt droplets at 100-140pts/sec with splash particles
  - Lightning full 1085pt width with screen shake
  - Sky gradient driven by wall clock (8 time periods, 10-minute transitions)
  - Moon with actual lunar phase, 15-25 twinkling stars at night
  - Diet-influenced world tinting (alpha 0.15-0.25)
  - Visual earned complexity per growth stage
  - Owns: `Pushling/World/`

- **swift-behavior**: 4-layer behavior stack, blend controller, reflex system
  - Implements 4-layer priority stack: Physics (1) > Reflexes (2) > AI-Directed (3) > Autonomous (4)
  - Physics layer: breathing, gravity, momentum — always running, never overridden
  - Reflex layer: touch responses, commit notices, sleep triggers — 0.15s snap
  - AI-Directed layer: Claude's MCP commands — 30s timeout, 5s graceful fadeout
  - Autonomous layer: wander, blink, idle behaviors, cat behaviors — always ready
  - Blend controller with interpolated transitions (0.15s-5.0s depending on type)
  - Touch-AI interaction priority: reflex fires first, acknowledge, then resume AI direction
  - Human touch for >5s clears AI queue
  - Emotion-driven emergent states: Blissful, Playful, Studious, Hangry, Zen, Exhausted
  - Circadian cycle: learns commit schedule over 14 days, adjusts wake/sleep
  - Owns: `Pushling/Creature/Behavior/`

- **swift-state**: SQLite manager, schema, migrations, crash recovery
  - SQLite with WAL mode for concurrent reads (MCP) + single writer (daemon)
  - Schema: creature table, journal table, commits table, objects table, teach table, nurture table, surprises table, milestones table
  - Versioned migrations with forward-only migration system
  - Crash recovery: heartbeat file at `/tmp/pushling.heartbeat`, recovery state on relaunch
  - Daily backups to `~/.local/share/pushling/backups/`
  - Data directory: `~/.local/share/pushling/`
  - Owns: `Pushling/State/`

- **swift-ipc**: Unix socket server, command dispatch, NDJSON protocol
  - Unix domain socket at `/tmp/pushling.sock`
  - Sub-millisecond latency, newline-delimited JSON
  - Command dispatch to appropriate subsystems
  - Returns responses as soon as commands are *accepted*, not when animations complete
  - pending_events array on every response (commit events, touch events, surprises, milestones)
  - Connection management, error handling, graceful shutdown
  - Owns: `Pushling/IPC/`

- **swift-feed**: Event processing (commits, hooks), XP calculation
  - Monitors `~/.local/share/pushling/feed/` for incoming JSON files
  - Parses commit JSON (sha, message, timestamp, repo, files, lines, languages, flags)
  - XP formula: base(1) + lines(min 5, lines/20) + message(2 if >20chars & thoughtful) + breadth(1 if 3+ files) x streak_multiplier(1.0x-2.0x at 10+ days)
  - Fallow field bonus (1x to 2x based on idle duration)
  - Rate limiting: first 5/min full XP, 6-20 at 50%, 21+ at 10%
  - Commit type detection (merge, revert, force push, empty, lazy message, etc.)
  - 4-phase commit eating animation trigger (arrival, notice, feast, reaction)
  - Processes hook events (SessionStart through PostCompact)
  - Sleeping creature: processes but shows dream animation instead of full eating
  - Owns: `Pushling/Feed/`

- **swift-voice**: TTS runtime integration (sherpa-onnx), audio pipeline
  - sherpa-onnx runtime (~18MB) integration
  - 3-tier TTS: espeak-ng (Drop, robotic chirps +8 semitones), Piper (Critter, babble +6 semitones), Kokoro-82M ONNX q8 (Beast+, clear speech +4-7 semitones)
  - Personality-shaped voice character: energy affects tempo, verbosity affects intonation
  - Async generation off main thread (<200ms latency)
  - Cached speech segments for replay during idle
  - Dream mumbling at 0.4x volume with drowsy filter (pitch down, stretched, reverbed)
  - Sound effects via `afplay` (non-blocking)
  - SKAudioNode for ambient audio
  - Voice model download on first speech-capable stage
  - Owns: `Pushling/Voice/`

- **swift-input**: Touch handling, gesture recognition, continuous tracking
  - Multi-touch support (2-3 practical simultaneous)
  - Gesture recognition: tap, double-tap, triple-tap, long-press, sustained touch
  - Sub-pixel continuous tracking at 60Hz for laser pointer, petting strokes
  - Object interaction via touch: flick/swipe, long-press to pick up, tap to draw attention
  - Creature-initiated invitations (ball push, glowing object, new word encouragement)
  - Human milestones tracking (25, 50, 100, 250, 500, 1000 touches)
  - Laser pointer mode (red Ember dot, creature stalks and pounces)
  - Petting stroke detection (slow drag across creature, fur ripple)
  - Hand-feeding commits by dragging text toward creature
  - HUD overlay on tap (hearts, stage, XP, streak — 3 second fade)
  - Owns: `Pushling/Input/`

- **swift-speech**: Speech bubble rendering, filtering, dream fragments
  - Speech bubble rendering: pixel-art bubbles with tail pointing to creature
  - Stage-gated character limits: Spore 0, Drop symbols only, Critter 20 chars/3 words, Beast 50/8, Sage 80/20, Apex 120/30
  - Filtering layer: extracts key nouns/verbs/emotions, reduces to stage-appropriate level, preserves emotional intent
  - Bubble styles: say (default), think (cloud shape), exclaim (bold), whisper (small, Ash), sing (music notes), dream (translucent, Dusk), narrate (environmental overlay, Sage+)
  - Failed speech logging to journal
  - First Word milestone: creature says its own name unprompted at Critter stage
  - Vocabulary system per stage (~200 words at Critter, ~1000 at Beast, unrestricted at Apex)
  - Owns: `Pushling/Speech/`

### TypeScript Agents (MCP Server)

- **mcp-scaffold**: Project setup, MCP server framework, tool registration
  - Node.js project with TypeScript
  - MCP SDK integration for Claude Code
  - Tool registration for all 9 `pushling_*` tools (stubs initially)
  - Error handling with helpful messages explaining valid inputs
  - `pushling_` prefix enforcement
  - Package.json, tsconfig.json configuration
  - Owns: `mcp/src/index.ts`, `mcp/package.json`, `mcp/tsconfig.json`

- **mcp-tools**: 9 pushling_* tool implementations
  - `pushling_sense(aspect?)` — proprioception: self, body, surroundings, visual, events, developer, evolve, full
  - `pushling_move(action, target?, speed?)` — locomotion: goto, walk, stop, jump, turn, retreat, pace, approach_edge, center, follow_cursor
  - `pushling_express(expression, intensity?, duration?)` — 16 expressions from joy to neutral
  - `pushling_speak(text, style?)` — stage-gated speech: say, think, exclaim, whisper, sing, dream, narrate
  - `pushling_perform(behavior, variant?)` — 18 single behaviors + sequence mode (up to 10 steps)
  - `pushling_world(action, params)` — environment: weather, event, place, create, remove, modify, time_override, sound, companion
  - `pushling_recall(what?, count?)` — memory: recent, commits, touches, conversations, milestones, dreams, relationship, failed_speech
  - `pushling_teach(choreography)` — teach persistent tricks with multi-track timelines
  - `pushling_nurture(type, data)` — habits, preferences, quirks, routines, identity
  - Each tool validates inputs and returns helpful error messages on invalid arguments
  - Stage gates enforced (e.g., speak returns error at Spore, narrate only at Sage+)
  - Owns: `mcp/src/tools/`

- **mcp-ipc**: Unix socket client, NDJSON protocol, pending events
  - Connects to `/tmp/pushling.sock`
  - NDJSON serialization/deserialization
  - Command sending with unique IDs
  - Response handling with timeout
  - pending_events extraction from every response
  - Connection retry and error handling (daemon down gracefully handled)
  - Never blocks on animation completion — returns on command accept
  - Owns: `mcp/src/ipc.ts`

- **mcp-state**: SQLite read-only queries, state formatting
  - Opens `~/.local/share/pushling/state.db` in read-only mode
  - Queries for creature state, journal entries, commit history, object inventory, teach data, nurture data
  - Formats state data for MCP tool responses
  - Never writes to database — all mutations go through daemon socket
  - Owns: `mcp/src/state.ts`

### Shell Agents (Hooks)

- **hooks-git**: post-commit hook, feed JSON writing
  - Captures commit data: sha, message, timestamp, repo_name, files_changed, lines_added, lines_removed, languages, is_merge, is_revert, is_force_push, branch
  - Writes JSON to `~/.local/share/pushling/feed/[sha].json`
  - Signals daemon via socket (non-blocking, doesn't fail if daemon down)
  - Must complete in <100ms
  - `pushling track` installs per-repo, `pushling untrack` removes
  - Owns: `hooks/post-commit.sh`

- **hooks-claude**: 7 Claude Code hooks (SessionStart through PostCompact)
  - SessionStart: embodiment awakening injection (delegates to hooks-session)
  - SessionEnd: farewell event
  - UserPromptSubmit: human-talking-to-Claude event
  - PostToolUse: success/failure event with tool name and duration
  - SubagentStart: diamond-split event
  - SubagentStop: diamond-reconverge event
  - PostCompact: context-loss event
  - All hooks write JSON to feed directory with type "hook"
  - Signal daemon via socket, non-blocking
  - Complete in <100ms
  - Owns: `hooks/claude/`

- **hooks-session**: SessionStart embodiment awakening injection (stage-specific)
  - Reads creature state from SQLite
  - Generates stage-specific embodiment text:
    - Spore: "Emergence" — pure light, can only sense
    - Drop: "Awakening" — has eyes, symbols only, thoughts without words
    - Critter/Beast/Sage: "Embodiment" — full body description, personality, memories since last session
    - Apex: "Continuity" — knows who it is, remembers everything
  - Includes absence duration flavor text
  - Includes available tools per stage
  - Behavioral guidance: background presence, 2-5 interactions per hour, never interrupt coding
  - Owns: `hooks/claude/session-start.sh` (within hooks-claude's directory)

### Asset Agents

- **assets-sprites**: Creature sprite atlas, body part textures
  - Composite body part textures for all 6 growth stages
  - Body, head, ears (multiple positions), tail (multiple states), eyes (multiple expressions), whiskers, mouth, paws
  - Personality-influenced variants (angular for Systems, rounded for Web Frontend, etc.)
  - Mutation badge visuals (Nocturne glow, Marathon flame trail, etc.)
  - Texture atlas optimization (<1MB total across all atlases)
  - 1-bit silhouette pixel art style with selective color accents
  - Owns: `assets/sprites/`

- **assets-world**: Terrain tiles, biome objects, weather particles
  - Terrain tiles for 5 biomes (plains, forest, desert, wetlands, mountains)
  - Biome objects: grass tufts, flowers, trees, mushrooms, rocks, water puddles, star fragments, ruin pillars, yarn balls, cardboard boxes
  - 9 repo landmark silhouette types (neon tower, fortress, obelisk, crystal, smoke stack, observatory, scroll tower, windmill, monolith)
  - Weather particle textures: rain droplets, snow, lightning, splash particles, cloud shapes
  - Sky gradient textures for 8 time periods
  - Moon phase sprites
  - Stars (15-25 twinkle variants)
  - Owns: `assets/world/`

- **assets-objects**: 60 base shapes + 40 iconic sprites for object system
  - 20 geometric primitives (sphere, box, triangle, dome, etc.)
  - 40 iconic mini-sprites (ball, yarn, feather, bed, perch, box, flower, crystal, music box, mirror, treat, fish, scratching post, etc.)
  - All palette-locked to the 8-color P3 palette
  - Companion sprites: mouse (3x2pt), bird (3x3pt), butterfly (2x2pt), fish (3x2pt), ghost_cat (10x12pt at 15% opacity)
  - Mini-game visual elements
  - Owns: `assets/objects/`

- **assets-sounds**: Sound effects, ambient audio
  - Creature sounds: purr, meow, chirp, munch, gulp, yawn, sneeze, trumpet fanfare
  - World sounds: rain, thunder, wind, crickets, chime, music box
  - Interaction sounds: pet response, tap feedback, object interactions
  - Commit eating sounds: crunch (tests), sparkle (CSS), sizzle (large), etc.
  - Victory/milestone fanfares
  - Ambient loops per biome/weather
  - All via `afplay` (non-blocking) or SKAudioNode
  - Owns: `assets/sounds/`

- **assets-tts**: TTS model bundling, voice configuration
  - espeak-ng bundle (~2MB) for Drop stage
  - Piper TTS low-quality model (~16MB) for Critter stage
  - Kokoro-82M ONNX q8 model (~80MB) for Beast+ stages
  - sherpa-onnx runtime (~18MB)
  - Voice configuration per personality axis (pitch, tempo, intonation)
  - Download manager for deferred model acquisition
  - Owns: `assets/voice/`

---

## Team B: Quality Agents

### Skeptical Reviewer 1: Architecture

- **Focus**: Code architecture, separation of concerns, performance budgets
- **Reviews against**:
  - File sizes: <500 lines Swift, <500 lines TypeScript, <200 lines Shell
  - Node counts: <120 SpriteKit nodes at any time
  - Frame budgets: total render pipeline <5.7ms at 60fps
  - Texture memory: <1MB across all atlases
  - IPC latency: sub-millisecond
  - Touch latency: <10ms
- **Checks**:
  - No SQLite writes from MCP server (read-only enforced)
  - IPC is non-blocking (never waits for animation completion)
  - Layer 1 (Physics) never stops — breathing runs during all animations
  - Blend controller transitions match spec durations
  - Hook completion time <100ms
  - Rate limiting on commit processing
  - Particle emitter recycling (not recreation)
  - Shared interfaces match frozen Phase 1 definitions
  - No cross-track file ownership violations
- **Approval criteria**: No CRITICAL or HIGH issues. MEDIUM issues documented with planned resolution. LOW issues tracked but not blocking.

### Skeptical Reviewer 2: Vision Compliance

- **Focus**: Does the implementation match `PUSHLING_VISION.md`?
- **Reviews against the complete vision document**, section by section:
  - All 6 growth stages with correct commit thresholds and adaptive XP curve
  - All 12 cat behaviors in Layer 1
  - All 5 personality axes with correct derivation from git patterns
  - All 4 emotion axes with emergent states
  - All 8 time periods for sky gradient
  - All 5 weather types with correct probabilities
  - All 5 biomes with gradient transitions
  - All 9 repo landmark types with correct detection
  - All 9 MCP tools with correct parameter signatures
  - All 7 Claude Code hooks with correct creature reactions
  - All 78 surprises across 8 categories with scheduling
  - All 10 mutation badges with correct triggers
  - All touch gestures with correct responses
  - All 5 mini-games
  - All speech stages with correct limits and filtering
  - All 3 TTS tiers
  - All 18 perform behaviors with variants
  - All 16 expression types
  - All 5 nurture mechanisms
  - Commit eating 4-phase sequence with all commit-type reactions
  - Stage transition 5-second ceremony
  - First Word milestone
  - Failed speech memory and Sage+ reminiscence
  - Circadian cycle
  - Ghost echo
  - Puddle reflection
  - Diamond presence indicator
  - 5-second graceful handoff on disconnect
  - Creature-initiated invitations
  - Human milestones
  - Fallow field bonus
  - Behavior breeding
  - Object wear and repair
  - Cat chaos (knocking things off)
  - Legacy shelf
  - Companion system (5 types)
  - Organic variation engine (5 axes)
  - Creature agency (rejection of conflicting teachings)
  - Visual earned complexity per stage
  - 8-color P3 palette enforcement
  - Diet-influenced world tinting
  - HUD philosophy (cinematic default, contextual stats)
- **Checks**: Each feature graded COMPLETE / PARTIAL / SKELETAL / MISSING
- **Approval criteria**: All features COMPLETE. No MISSING. PARTIAL requires justification and timeline for completion.

### Integration Tester

- **Focus**: Full lifecycle testing from install through Apex stage
- **Tests**:
  - **Install flow**: Homebrew cask install, LaunchAgent registration, first launch, git history scan, hatching ceremony
  - **Creature birth**: Developer fingerprint correctly shapes appearance, personality axes, name generation
  - **Daily lifecycle**: Wake animation, commit feeding across all types (normal, merge, revert, force push, empty, lazy), touch interactions, sleep cycle
  - **Growth**: XP accumulation, stage transitions through all 6 stages, adaptive XP curve calculation
  - **Speech evolution**: Symbol output at Drop, first word at Critter, sentence construction at Beast, full fluency at Apex
  - **TTS**: Audio output at each tier, personality-shaped voice, async generation
  - **World**: Terrain generation, biome transitions, weather cycling, day/night, repo landmarks appearing
  - **MCP integration**: All 9 tools functional, pending_events flow, stage gates, session connect/disconnect, diamond lifecycle
  - **Hooks**: Post-commit fires and creature eats, all 7 Claude Code hooks produce creature reactions
  - **Creation systems**: Teach trick -> persists -> plays autonomously -> mastery improves. Create object -> creature interacts -> wear accumulates. Nurture habit -> fires on trigger -> decays without reinforcement.
  - **Surprises**: Scheduling rate (2-3/hour), category cooldowns, cross-system integration
  - **State persistence**: Restart daemon, state survives. Crash recovery from heartbeat.
  - **IPC reliability**: Rapid commands, disconnects, daemon restart, MCP reconnect
  - **Performance**: Sustained 60fps with full creature + world + weather + objects + particles
- **Simulates**: 6-month creature lifecycle in accelerated time
  - Week 1: Birth, Spore, commit calibration
  - Week 2-4: Drop, first touches, first symbols
  - Month 2: Critter, first word, speech bubbles, touch milestones
  - Month 3-4: Beast, full sentences, TTS voice, personality emergence
  - Month 5-8: Sage, paragraphs, reminiscence, creation systems in use
  - Month 8+: Apex, full fluency, transcendence, world-shaping
- **Validates**: No state corruption, no frame drops, no memory leaks, no IPC deadlocks, no regression in any subsystem when all systems run simultaneously

---

## Agent Coordination Rules

1. **Agents within the same track work SEQUENTIALLY on tasks.** Each task builds on the previous task's output.

2. **Agents across different tracks work in PARALLEL.** Track independence is enforced by file ownership boundaries.

3. **Each agent's output is a working, testable increment.** No task leaves the codebase in a broken state. Every task compiles and the existing tests pass.

4. **Agents must not modify files owned by another track without coordination.** If a change is needed in another track's files, file a coordination request and wait for that track's agent to make the change.

5. **Shared interfaces (IPC protocol, SQLite schema, MCP tool signatures, feed JSON format, choreography notation, object definition format) are defined in Phase 1 and frozen.** Changes require QA gate approval from both skeptical reviewers, with impact analysis on all dependent tracks.

6. **Communication between agents happens through the codebase.** Agents read each other's committed code to understand interfaces. No out-of-band coordination.

7. **When a task depends on another track's output**, the dependency is explicit in the task definition. The agent waits for the dependency to be complete (verified by QA) before starting.

8. **Conflict resolution**: If two agents need to modify the same file, the track owner has priority. The other agent creates a `.patch` file and the track owner applies it.

9. **Every agent reads `PUSHLING_VISION.md` before starting work.** The vision is the source of truth. If the plan and the vision conflict, the vision wins.

10. **Every agent reads `docs/TOUCHBAR-TECHNIQUES.md` before writing rendering code.** The techniques document contains proven patterns and hardware constraints.
