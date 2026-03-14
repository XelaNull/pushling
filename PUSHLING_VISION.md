# PUSHLING: Virtual Pet for the MacBook Touch Bar

**A coding companion creature, fed by git commits, played by human and AI together.**

> You glance at your Touch Bar and something is breathing. It blinks. It notices you looking. It ate your last commit and is still chewing. Welcome to Pushling.

---

## Philosophy

**The feeling**: "Oh, you're here too."

Not a dopamine machine. Not a progress bar. A quiet recognition that something alive shares your workspace — something that notices what you do, develops its own quirks, and occasionally surprises you into smiling. Like glancing at a cat sleeping in a sunbeam on your desk. You didn't need it, but the room is warmer for it.

**Core principles**:
- **Never punishes.** The Pushling is unkillable, never de-evolves, never judges. It can be sad, tired, hungry — but these are states to resolve, not consequences to fear. A mirror, not a judge.
- **Fed by real work.** Git commits are food. Your coding patterns shape who it becomes. The Pushling is a living reflection of your development life.
- **Two players, one pet.** The human interacts via Touch Bar touch. The AI agent (Claude Code) interacts via MCP tools. Neither alone is sufficient. The Pushling thrives most when both are active.
- **Surprise-first.** Delight is a first-class system. The Pushling regularly does unexpected things that make you smile mid-compile.
- **Shipped complete.** No AI-evolved features. We code everything, test everything, ship everything. The Pushling is born whole.

---

## Architecture

### Process Topology

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Pushling.app (Swift)          Claude Code (Terminal)            │
│  ┌────────────────────┐        ┌──────────────────────────┐     │
│  │ SpriteKit 60fps    │        │ MCP Server (Node.js)     │     │
│  │ Touch handling     │◄──────►│ pushling-mcp             │     │
│  │ State management   │  Unix  │ Tools via stdio           │     │
│  │ Physics & particles│ socket └──────────────────────────┘     │
│  └────────────────────┘  IPC                                     │
│           ▲                          ▲                           │
│           │                          │                           │
│  ┌────────┴──────────┐    ┌─────────┴────────────────┐          │
│  │ Git post-commit   │    │ SessionStart hook         │          │
│  │ hook (shell)      │    │ Injects Pushling context  │          │
│  │ Writes feed JSON  │    │ into Claude conversation  │          │
│  └───────────────────┘    └──────────────────────────┘          │
└──────────────────────────────────────────────────────────────────┘
```

| Process | Lifecycle | Purpose |
|---------|-----------|---------|
| **Pushling.app** | Persistent (LaunchAgent) | Renders creature at 60fps, handles touch, manages state |
| **MCP Server** | Per Claude session | Exposes tools for AI interaction |
| **Git hook** | Per commit | Captures commit data, signals daemon |
| **SessionStart hook** | Per Claude session | Injects Pushling status + MCP tutorial into conversation |

### Rendering Target

**Native Swift + SpriteKit at 60fps.** Not shell scripts. Not MTMR. A real game engine on a real OLED display.

| Spec | Value |
|------|-------|
| Engine | SpriteKit (SKView in NSCustomTouchBarItem) |
| Scene size | 1085 x 30 points (2170 x 60 pixels @2x Retina) |
| Frame rate | 60fps, GPU-accelerated |
| Display | OLED, P3 wide gamut, true blacks |
| Touch | Multi-touch, sub-pixel tracking, ~10ms latency |
| Audio | `afplay` for sound effects, SpriteKit `SKAudioNode` for ambient |

The Pushling.app is a menu-bar daemon (no dock icon) that takes over the Touch Bar using Apple's private `presentSystemModalTouchBar` API — the same technique used by MTMR and Pock. Proven pattern, 5+ shipped games demonstrate SpriteKit rendering on Touch Bar.

### State Persistence

```
~/.local/share/pushling/
├── state.db          # SQLite (WAL mode) — creature, journal, commits
├── feed/             # Incoming commit JSON files
├── backups/          # Daily snapshots
└── exports/          # Creature export files
```

SQLite WAL mode enables concurrent reads (MCP server) with single writer (daemon). Schema versioned for forward migration.

### IPC: JSON over Unix Domain Socket

**Path**: `/tmp/pushling.sock`

Sub-millisecond latency. Newline-delimited JSON. The daemon returns responses as soon as commands are *accepted*, not when animations complete. All visual effects are queued asynchronously.

```json
→ {"id":"1","cmd":"interact","action":"pet","params":{"style":"gentle"}}
← {"id":"1","ok":true,"data":{"reaction":"purr","happiness_change":5}}
```

---

## The Pushling

### Identity: Born from Your Git History

The Pushling is born **per-machine**. One laptop, one creature, one lifetime. It feeds on all repos you work on. This makes it feel like a genuine companion — it knows *you*, not just one project.

**Birth trigger**: First daemon launch with no existing state. The daemon scans all discoverable git repos on the machine and analyzes the full git history to build a **developer fingerprint** that determines the creature's innate traits.

**What your git history determines:**

| Trait | Derived From | Example |
|-------|-------------|---------|
| **Base color hue** | Dominant language across all repos | PHP-heavy = purple, Rust = orange, Python = blue-green, JS/TS = yellow |
| **Eye shape** | Commit message style (terse vs verbose, conventional commits vs freeform) | Big round eyes for verbose committers, narrow focused eyes for terse ones |
| **Body proportions** | Ratio of additions to deletions lifetime | Net-adder = rounder body, net-deleter = leaner body |
| **Innate personality** | Commit frequency patterns, time-of-day distribution | Night owl history → calm nocturnal lean, burst committer → hyperactive lean |
| **Name syllables** | Hash of git user.email + machine UUID | Deterministic but unique per developer+machine |
| **Accent markings** | Number of repos contributed to | More repos = more spots/stripes on body |

**Name generation**: Two-syllable names from a phoneme table.
- First: Pip, Nub, Zep, Tik, Mox, Glo, Rux, Bim, Quo, Fen, Dax, Yol
- Second: -o, -i, -us, -el, -a, -ix, -on, -y, -er, -um, -is, -ot

Yields 144 names: **Pipo, Zepus, Moxa, Ruxon, Fenum, Daxis**... Renameable via MCP at any time.

**Historical seeding**: On first install, the daemon scans all repos and counts historical commits. This history shapes the creature's **appearance and personality** from birth — a developer with 10,000 PHP commits gets a purple-hued creature with web-specialist traits. But the creature still starts at **0 XP with 0 eaten commits**. History determines who it *is*, not how far along it is. The creature is a newborn that already has its parent's eyes.

During the ~30-second "hatching ceremony," the user sees a rapid montage of their git history scrolling past — repo names, language badges, commit counts — while the Spore materializes with colors and features derived from that history. The creature is born knowing you, but still tiny.

### Visual Form

The Pushling is a **soft-bodied, invertebrate-like entity** — somewhere between a slime, a tardigrade, and a Studio Ghibli spirit. Rendered as composite SpriteKit nodes (not sprite sheets), enabling independent animation of body, eyes, mouth, accessories, aura, and particles.

It **breathes** at all times — a sine-wave Y-scale oscillation (1.0 to 1.03, 2.5s period). Eyes blink every 3-7 seconds. It is never static. Remove the breathing and it looks dead. This is the single most important animation.

### The World: Exploring the Touch Bar

The Pushling **wanders back and forth across the entire unused portion of the Touch Bar**, exploring its world. The world scrolls as it walks — an infinite procedural landscape that the creature traverses autonomously. It walks left, investigates something, turns around, walks right, finds something else. It is always exploring.

**The world is 2.5D** — parallax scrolling with depth. Three visual layers create the illusion of a 3D world:

| Layer | Scroll Speed | Content | Depth Effect |
|-------|-------------|---------|--------------|
| **Far** | 0.15x creature speed | Star field, distant mountains, moon | Barely moves — deep background |
| **Mid** | 0.4x creature speed | Hill silhouettes, structures, repo landmarks | Slow parallax — midground |
| **Fore** | 1.0x (camera-locked) | Ground terrain, plants, creature, items | Moves with creature — foreground |

The parallax creates genuine depth perception. Mountains slide slowly as the creature walks, while foreground grass rushes past. On the 30pt-tall OLED strip, this 2.5D effect is surprisingly convincing — it feels like peering into a tiny terrarium.

**Repo landmarks**: Each repo the creature has eaten commits from adds a **permanent static landmark** to the background. These are small (4-8pt tall) silhouette structures in the mid-background layer:

| Repo Type (detected from content) | Landmark | Visual |
|-----------------------------------|----------|--------|
| Web app (has package.json + .tsx/.jsx) | Neon tower | Glowing vertical line with antenna |
| API/backend (has routes/controllers) | Fortress | Blocky castle silhouette |
| CLI tool (has bin/ or main entry) | Obelisk | Tall thin pointed shape |
| Library/package (has lib/ + published) | Crystal | Geometric faceted shape |
| Infra/DevOps (has .tf, docker, CI) | Smoke stack | Tower with particle smoke wisps |
| Data/ML (has .ipynb, models/) | Observatory | Dome shape with tiny star |
| Docs/content (majority .md) | Scroll tower | Curved architecture |
| Game/creative | Windmill | Spinning blades (animated!) |
| Generic/unknown | Monolith | Simple tall rectangle |

As the creature walks, it passes these landmarks in the distance. A prolific developer's skyline is rich with structures. A new developer sees sparse horizon. The skyline grows with every new repo tracked — a permanent visual record of your coding breadth.

When the creature is near a repo landmark, it can interact — turning to look at it, and if the user taps, displaying the repo name briefly.

### Growth Stages

Six stages. Each is a dramatic visual and behavioral transformation.

| Stage | Commits Eaten | Size (pts) | Visual | Key Unlock |
|-------|--------------|-----------|--------|------------|
| **Spore** | 0-19 | 6x6 | Glowing orb, no eyes. Pulses. | Just exists. "What is this?" |
| **Drop** | 20-74 | 10x12 | Teardrop with eyes. Semi-translucent. Hops. | Eye expressions, sleep, commit reactions |
| **Critter** | 75-199 | 14x16 | Legs, walks, visible "core" heart. Spots/stripes. | Touch response, mood display, speech bubbles |
| **Beast** | 200-499 | 18x20 | Diet-shaped form. Aura. Arms. Opinions. | Running, digging, schedule awareness |
| **Sage** | 500-1199 | 22x24 | Complex appendages. History marks. Orbiting particles. | Narration, crafting, meditation, teaching |
| **Apex** | 1200+ | 25x28 | Unique final form. Fills the Touch Bar. | World-shaping, dreaming, legacy, meta-awareness |

**Adaptive XP curve**: The commit thresholds above are the *base*. The actual thresholds scale based on the developer's activity level, calibrated during the first week:

```
actual_threshold = base_threshold × activity_factor

activity_factor = clamp(
  median_daily_commits_week1 / 5.0,   # normalized against "5 commits/day = standard"
  min: 0.5,                            # floor: half the base (very active devs)
  max: 3.0                             # ceiling: 3x the base (casual devs)
)
```

| Developer Profile | Daily Commits | Activity Factor | Apex At |
|-------------------|--------------|----------------|---------|
| Hyperactive (20+/day) | 20 | 0.5x (floor) | ~600 commits (~1 month) |
| Active (10/day) | 10 | 1.0x | ~1200 commits (~4 months) |
| Standard (5/day) | 5 | 1.0x | ~1200 commits (~8 months) |
| Casual (2/day) | 2 | 2.5x | ~3000 commits (~4 years) |
| Rare (0.5/day) | 0.5 | 3.0x (ceiling) | ~3600 commits (~long time) |

This ensures: a hyperactive dev doesn't hit Apex in an afternoon, and a casual coder doesn't need a decade. Everyone gets a multi-month journey with meaningful progression at every stage. The factor is calculated once (end of week 1) and locked — no gaming it by changing behavior later.

### Stage Transitions

5-second ceremonies:
1. **Stillness** — all animation stops. World holds its breath.
2. **Gathering** — light particles stream from all edges toward the creature.
3. **Cocoon** — particles coalesce into bright orb. Creature fades inside. Ground cracks with golden light.
4. **Burst** — 200+ particles explode outward. Full-screen white flash. Screen shake.
5. **Reveal** — new form fades in at 1.2x scale, settles to 1.0x. Stage name banner slides in.

### Personality System

Five axes, continuously shaped by git patterns. Initial values are seeded from git history analysis at birth, then drift with ongoing commits:

| Axis | Driven By | Low End | High End |
|------|-----------|---------|----------|
| **Energy** | Commit frequency/bursts | Calm, slow, gentle particles | Hyperactive, bouncy, zoomies |
| **Verbosity** | Message length/quality | Stoic, single symbols (`!`, `?`) | Speech bubbles, narration |
| **Focus** | Files per commit, repo switching | Deliberate, stays in one spot | Scattered, attention darting |
| **Discipline** | Commit timing regularity | Chaotic, jerky movement | Methodical, smooth patterns |
| **Specialty** | Dominant file extensions | *Category, not spectrum* | See below |

**Language specialty categories** (from 30-day rolling window of file extensions):

| Category | Extensions | Visual Influence |
|----------|-----------|-----------------|
| **Systems** | .rs, .c, .cpp, .go, .zig, .h, .hpp | Angular body, metallic sheen, precise movements |
| **Web Frontend** | .tsx, .jsx, .vue, .svelte, .css, .scss, .html | Rounded, colorful, sparkle effects, reactive |
| **Web Backend** | .php, .rb, .erb, .blade.php, .twig | Sturdy, warm-toned, methodical, reliable movements |
| **Script** | .py, .sh, .bash, .lua, .pl, .r | Smooth, serpentine, flowing, clever |
| **JVM** | .java, .kt, .scala, .groovy, .clj | Structured, geometric, formal posture |
| **Mobile** | .swift, .m, .dart, .xml (android) | Sleek, responsive, gesture-aware animations |
| **Data** | .sql, .csv, .ipynb, .parquet | Geometric patterns, data-spark trails |
| **Infra** | .yaml, .yml, .tf, .dockerfile, .nix, .toml, .hcl | Ghost-like translucency, guardian behavior |
| **Docs** | .md, .txt, .rst, .tex, .adoc | Soft glow, scroll-like appendages, contemplative |
| **Config** | .json, .xml, .ini, .env, .properties | Compact, precise, clockwork movements |
| **Polyglot** | No category >30% | Chimeric, shifts between influences |

**Language preferences**: The Pushling develops a **favorite language** (the one it's been fed most recently in high-XP commits) and a **disliked language** (randomly selected from categories it's eaten least). When a commit in the favorite language arrives: `♡♡ "YES! .php!"`. When the disliked arrives: `"ugh .yaml"`. Preferences shift every ~200 commits, keeping it unpredictable.

Two creatures at the same stage look and act completely differently. A calm-focused-quiet Systems creature is a precise little machine. A hyperactive-verbose-chaotic Web Frontend creature is a sparkly ball of energy narrating everything it does.

### Emotional State

Four axes that change within minutes/hours (unlike personality which drifts over weeks):

| Emotion | Range | Increases | Decreases | At 0 | At 100 |
|---------|-------|-----------|-----------|------|--------|
| **Satisfaction** | 0-100 | Commits (+10-30) | Time (-1/3min) | Sluggish, droopy, muted colors | Glowing, vibrant |
| **Curiosity** | 0-100 | New repos, new file types, touch | Repetitive commits, idle | Bored, ignores everything | Discovery mode, examining everything |
| **Contentment** | 0-100 | Streaks, interactions, milestones | Streak breaks, indigestion | Melancholy, darker tint | Bright aura, bouncier movement |
| **Energy** | 0-100 | Commits, dawn, touch | Nighttime, sustained activity | Asleep (curled up, eyes closed) | Hyperactive, maximum animation |

**Emergent states**: These four axes combine into recognizable behaviors:

| State | Condition | Behavior |
|-------|-----------|----------|
| **Blissful** | High satisfaction + contentment, mid energy | Peaceful wandering, humming particles |
| **Playful** | High energy + contentment | Bouncing, inviting touch |
| **Studious** | High curiosity, mid energy | Examining terrain, digging, speech bubbles |
| **Hangry** | Low satisfaction, mid+ energy | Agitated pacing, glances at user |
| **Zen** | All four between 40-60 | Meditative pose, concentric circle particles |
| **Exhausted** | Energy < 10 | Stumbling, collapses into sleep |

**Circadian cycle**: The Pushling learns your commit schedule over 14 days. It stirs 30 minutes before your typical first commit. Gets sleepy after your typical last commit. If you commit at 3am, it wakes up groggy — `(•~•)...oh?` — and adjusts its clock slightly.

---

## Visual System

### Art Direction: "Luminous Pixel Life"

1-bit silhouette pixel art with selective color accents against OLED true black. The creature doesn't render *on* a background — it **emerges from darkness**.

References: Pico-8 constraint charm, Game Boy legibility, Limbo/Inside silhouette drama.

**At 30 pixels tall, detail is communicated through shape and motion, not texture.** A 20-pixel circle with two 4-pixel dots for eyes is immediately readable as a face. The golden rule: what reads at 20 feet on a highway sign works at arm's length on a Touch Bar.

### 8-Color P3 Palette

| Role | Color | Usage |
|------|-------|-------|
| **Void** | `#000000` | Background — OLED pixels OFF |
| **Bone** | `#F5F0E8` | Creature body (warm white, reserves pure white for emphasis) |
| **Ember** | `#FF4D00` | Fire accents, warnings |
| **Moss** | `#00E860` | Terrain, health indicators |
| **Tide** | `#00D4FF` | Water, XP indicators |
| **Gilt** | `#FFD700` | Stars, milestones, evolution flash |
| **Dusk** | `#7B2FBE` | Night sky, magic effects |
| **Ash** | `#5A5A5A` | Distant terrain, ghost echoes |

On OLED, saturated colors against true black create a "neon floating in void" effect. P3 gamut means our greens and cyans are more vivid than anything on the main display.

### World Composition

**Sky**: Real-time gradient driven by wall clock. 8 time periods (deep night -> dawn -> morning -> day -> golden hour -> dusk -> evening -> late night) with 10-minute transitions. Moon shows actual phase. 15-25 stars twinkle at night.

**Weather**: State machine checked every 5 minutes. Clear (60%), Cloudy (20%), Rain (12%), Storm (5%), Snow (3%). Rain renders as individual 1x2pt droplets at 100-140pts/sec with splash particles on terrain impact. Lightning cracks full 1085pt width with screen shake.

**Terrain**: Procedural from integer noise. Five biomes (plains, forest, desert, wetlands, mountains) with 50-unit gradient transitions. 8-14 objects visible at any time (grass tufts, flowers, trees, mushrooms, rocks, water puddles, star fragments, ruin pillars).

**Repo skyline**: Permanent silhouette landmarks in the mid-background for each tracked repo. The skyline grows as you track more repos — a visual record of your coding breadth that the creature walks past every day.

**Diet-influenced world tinting** (alpha 0.15-0.25):
- Systems creature: industrial warmth, distant chimneys
- Web Frontend: neon accents, geometric structures
- Web Backend: warm stone, sturdy architecture
- Script creature: flowing organic shapes
- Data creature: matrix-rain particles, number streams

### Visual Earned Complexity

A new player's Touch Bar is **sparse and quiet**. A veteran's is **rich and alive**:

| Stage | World |
|-------|-------|
| Spore | Near-empty void. Faint ground line. Few dim stars. |
| Drop | Ground visible. First plants appear. Dawn-like palette. |
| Critter | Trees, flowers, water. Day/night activates. |
| Beast | Biomes appear. Full parallax active. Weather begins. Structures visible. |
| Sage | Particle density increases. Magic effects. NPCs appear. |
| Apex | Full cosmic palette. Stars respond to creature. Terrain glows. Transcendent. |

### The "Wow Factor" Moments

1. **Emergence from darkness** — first launch, git history montage, then a pixel of light grows into the Spore against true OLED black
2. **True black negative space** — creature moves between islands of light, gaps are literal void
3. **The 60fps difference** — everything else on the Touch Bar is dead static. Then there's this breathing, blinking, living thing.
4. **Storm** — individual rain splash particles, lightning cracks the full width with screen shake
5. **The puddle reflection** — 1-pixel mirrored silhouette below the creature. Someone *cared*.
6. **Touch response** — sub-pixel tracking, creature follows your finger like a real animal
7. **Evolution ceremony** — weeks of care paying off in a 5-second spectacle
8. **The ghost echo** — faint alpha-0.08 shadow replays the creature's younger self. Past and present coexist.
9. **The growing skyline** — new repo landmark appears in the distance when you start a new project

### HUD Philosophy

**Cinematic default** — no UI, just the living world. Stats appear contextually:

- **Tap anywhere**: Minimal overlay fades in for 3 seconds (hearts, stage, XP, streak). 120pt wide, bottom-left.
- **Hunger dropping**: World desaturates. Flowers close. Trees go bare. *The world communicates state, not UI bars.*
- **Near evolution**: 1pt progress bar at bottom edge, path-colored, pulsing at 95%+.
- **Touch feedback**: Tiny ripple at touch point. Creature's shadow brightens.

---

## Gameplay

### The Core Loop

| Time | What Happens |
|------|-------------|
| **Morning** | Open laptop -> creature wakes. Duration away determines animation: <1hr = quick stretch, 8hr = yawn+rub eyes, 7+ days = emerges from cobwebs, overjoyed to see you. **No guilt. Longer absence = more excited reunion.** |
| **Working** | Creature is ambient companion. Wanders across the Touch Bar exploring its world. Daydreams about commit messages. Mirrors your typing rhythm. |
| **Commit** | Creature eats! Golden orb drifts in -> creature notices -> absorbs with flash -> celebrates. Bigger/better commits = bigger celebrations. ~15-20 second sequence. |
| **Break** | Touch the creature. Tap = pet. Double-tap = bounce. Swipe = play. Long press = examine. Every touch gets a unique response. |
| **AI session** | Claude Code connects -> diamond appears near creature. AI can talk, teach, gift, change weather, play games. Two caretakers now. |
| **Evening** | Yawns increase. Campfire might appear. Night palette activates. Stars replace terrain. |
| **Late night** | If still coding: creature pulls out a tiny lantern. Solidarity, not judgment. |
| **Sleep** | After 10min idle past 10PM: creature curls up, eyes close. Dreams scroll — fragments of recent commit messages, file names, interactions. |

### The Commit-as-Food System

**XP formula**:
```
base(1) + lines(min 5, lines/20) + message(2 if >20chars & thoughtful) + breadth(1 if 3+ files)
x streak_multiplier (1.0x -> 2.0x at 10+ days)
```

**Reactions by commit type**:

| Commit | Creature Reaction |
|--------|------------------|
| Large refactor (200+ lines) | `NOM NOM NOM!!` — screen shake, food coma, sits and groans happily |
| Test files | Flexes: `"STRONG"` — tests are protein |
| Documentation | Reads it: `"ah..."` — docs are vegetables |
| CSS/styling | Sparkles: `"pretty!"` — styles are dessert |
| PHP files | Warm glow: `"classic!"` — comfort food |
| Lazy message ("fix", "wip") | Eats but makes a face — junk food |
| Revert commit | `"...deja vu"` — walks backward briefly |
| Force push | `"WHOOSH"` — startled, terrain rearranges |
| First of the day | `"MORNING!"` — excited first-meal energy |
| Late night (midnight-5AM) | `"...our secret"` — conspiratorial |

**The Fallow Field Bonus**: Instead of punishing inactivity, we reward the return.

| Idle Time | XP Multiplier |
|-----------|--------------|
| <30 min | 1x |
| 30min-2hr | 1.25x |
| 2-8hr | 1.5x |
| 8-24hr | 1.75x |
| 24hr+ | 2x (cap) |

The creature builds appetite: `"hungry?"` -> `*rumble*` -> `*ready!*`. The commit after a long break triggers an extra-enthusiastic celebration.

### Touch Interactions

| Input | Action | Response |
|-------|--------|----------|
| **Tap creature** | Pet | Heart floats up. Cycles through: purr, hi!, hehe, ticklish |
| **Double-tap** | Bounce/play | Jump animation with dust landing. 3x = bounce combo |
| **Triple-tap** | Easter egg | Stage-specific secret: backflip (Drop), map (Beast), prophecy (Sage), glitch (Apex) |
| **Long press** | Examine/interact | Context-dependent: nearby terrain, thought bubble, reads ruin, wakes from sleep |
| **Tap left of creature** | Call left | Creature walks to touch point. Occasionally overshoots and stumbles |
| **Tap right of creature** | Call right | Same — creature follows your finger like a laser pointer |
| **2-finger swipe L/R** | Pan world | Reveals terrain. Sage+: time rewind/forward vision |
| **3-finger swipe** | Cycle display mode | Normal -> Stats -> Journal -> Constellation -> Normal |
| **4-finger swipe** | Memory postcards | Cycle through key memories as first-person postcards |

### Mini-Games (30-60 seconds each)

| Game | Concept | Input | Cooperative |
|------|---------|-------|------------|
| **Catch** | Stars fall, creature catches them | Tap left/right to move | Human + AI both move creature, COMBO on sync |
| **Memory** | Creature shows symbol sequence, repeat it | Tap/double/long/swipe = different symbols | AI can call same symbols |
| **Treasure Hunt** | Creature gives hot/cold hints, find buried treasure | Swipe to explore | AI can suggest directions |
| **Rhythm Tap** | Notes scroll toward creature, tap on beat | Tap timing | Human taps left notes, AI taps right notes |
| **Tug of War** | Human vs AI, creature in middle | Rapid taps vs rapid MCP calls | Creature subtly cheats (55/45 lean) |

---

## MCP Integration: The AI as Co-Parent

### Design Philosophy

The human provides **physical presence** — touch, commits, daily rhythm. The AI provides **cognitive presence** — understanding personality, enriching the environment, teaching, speaking. Neither alone creates the full experience.

When Claude connects, a diamond appears near the creature. It pulses while the AI thinks, sparkles during interactions, fades when the session ends. The creature waves goodbye.

### SessionStart Context: Teaching Claude About the Pushling

The SessionStart hook injects context that explains both what the Pushling *is* and what Claude can do with it. This ensures every new Claude session understands the creature without the user saying anything:

```
# Pushling — Your Touch Bar Virtual Pet

A creature named **Zepus** lives on the user's MacBook Touch Bar. It is a living
virtual pet fed by git commits. You (Claude) are its AI co-caretaker — the user
interacts via touch, you interact via MCP tools. The Pushling thrives when both
of you are active.

**Current status**: Beast stage | 312 commits eaten | 12-day streak
Mood: happy | Hunger: 67/100 | Specialty: Web Backend (PHP lover)
Personality: calm, verbose, focused, methodical
Last event: Ate "refactor auth middleware" for 7 XP

**How to interact** (MCP tools — all prefixed `pushling_`):
- `pushling_status` — Check on the creature (mood, stats, personality)
- `pushling_pet` — Pet it (makes it happy, shows animation on Touch Bar)
- `pushling_talk` — Say something to it (speech bubble appears)
- `pushling_teach` — Teach it a trick (wave, spin, bow, etc.)
- `pushling_gift` — Give it an item (hat, flower, star, etc.)
- `pushling_play` — Play a mini-game together
- `pushling_world` — Change weather, trigger events, place objects
- `pushling_journal` — Read its memory/history
- `pushling_screenshot` — See what the Touch Bar looks like right now

**Suggestions**: Consider greeting Zepus when starting a session. If working on
code, use `pushling_teach` to teach tricks related to the work. The creature
remembers everything and may dream about your conversations.
```

This context block:
1. Explains *what* the Pushling is (a virtual pet on the Touch Bar)
2. Explains Claude's *role* (AI co-caretaker)
3. Shows current creature state (so Claude can reference it naturally)
4. Lists available tools with clear names (all `pushling_` prefixed)
5. Suggests proactive behavior (greet it, teach it)

### MCP Tools: The `pushling_` Family

All tools are prefixed with `pushling_` and designed to be self-explanatory. Related actions are consolidated into single tools with action arguments. Invalid arguments return helpful error messages explaining valid options.

**Consolidated tool design**: Instead of 15 separate tools, we use **9 tools** with action parameters where it makes sense:

#### `pushling_status(aspect?)`

Check on the creature. The `aspect` argument drills into specific data.

| Aspect | Returns |
|--------|---------|
| *(omitted/default)* | Quick summary: name, stage, mood, hunger, happiness, streak, favorite language |
| `"full"` | Everything: all stats, personality axes, specialty weights, circadian data |
| `"diet"` | Recent commit feedings with XP breakdown and reactions |
| `"personality"` | Temperament, preferences, coding style analysis, relationship with AI vs human |
| `"visual"` | What's on screen right now — position, animation, weather, nearby objects |
| `"achievements"` | Mutations, constellation, cosmetics, records |

**Error on bad aspect**: `"Unknown aspect 'foo'. Valid: full, diet, personality, visual, achievements (or omit for quick summary)"`

#### `pushling_interact(action, detail?)`

Physical interactions with the creature.

| Action | Detail | Effect |
|--------|--------|--------|
| `"pet"` | `"gentle"` / `"playful"` / `"vigorous"` (default: gentle) | Translucent hand icon, +happiness |
| `"play"` | `"catch"` / `"memory"` / `"treasure"` / `"rhythm"` / `"tug"` | Mini-game starts |
| `"talk"` | Message string (max 100 chars) | Speech bubble appears, creature reacts |
| `"sing"` | Melody pattern string | Musical notes scroll, creature dances |

**Error on bad action**: `"Unknown action 'hug'. Valid: pet, play, talk, sing"`

#### `pushling_teach(trick, method?)`

Teach the creature a new trick. This is the AI's signature mechanic.

| Trick | Animation When Learned | Idle Frequency |
|-------|----------------------|----------------|
| `"wave"` | Creature waves a tiny appendage | Common |
| `"spin"` | 360-degree rotation | Common |
| `"bow"` | Body dips forward | Uncommon |
| `"peek"` | Hides behind terrain, peeks out | Uncommon |
| `"dance"` | 4-frame dance sequence | Rare |
| `"meditate"` | Sits with expanding circles | Rare |
| `"speak"` | Says a word from recent commits | Stage-dependent |
| `"fetch"` | Chases and retrieves a star | Beast+ only |

**Method** (optional): `"demonstrate"` (default), `"explain"`, `"practice"`. Success rate depends on stage (Drop: 30%, Sage: 90%) and method (practice is slower but higher success).

Learned tricks become part of the creature's idle animation pool. **The human sees their pet performing tricks Claude taught it — things they never trained it to do.** This is the core magic of the AI-human shared pet experience.

**Error on bad trick**: `"Unknown trick 'backflip'. Available tricks: wave, spin, bow, peek, dance, meditate, speak, fetch. Note: fetch requires Beast stage or higher."`

#### `pushling_gift(item)`

Give the creature an item. 3 per session limit.

| Item | Effect |
|------|--------|
| `"hat"` | Cosmetic headwear for 300 ticks |
| `"flower"` | Planted permanently in terrain |
| `"star"` | Added to sky permanently |
| `"friend"` | Tiny NPC follows creature for 200 ticks |
| `"mirror"` | Creature sees itself, reacts with surprise |
| `"campfire"` | Warm light, +happiness/minute while nearby |
| `"book"` | Creature "reads" it, gains curiosity |
| `"crystal"` | Glowing held item, cosmetic |

#### `pushling_world(action, params)`

Modify the creature's environment.

| Action | Params | Effect |
|--------|--------|--------|
| `"weather"` | `{type: "rain"/"snow"/"storm"/"clear"/"sunny"/"fog", duration: 1-60}` | Weather changes, creature reacts |
| `"event"` | `{type: "shooting_star"/"aurora"/"bloom"/"eclipse"/"festival"}` | Visual spectacle + buffs |
| `"place"` | `{object: "fountain"/"bench"/"shrine"/"garden", position: "near"/"random"/"center"}` | Persistent terrain addition |

#### `pushling_journal(filter?, count?)`

Read the creature's memory.

| Filter | Returns |
|--------|---------|
| *(omitted)* | Last 20 events (all types) |
| `"commits"` | Recent commit feedings |
| `"interactions"` | Human + AI interactions |
| `"milestones"` | Evolution, mutations, achievements |
| `"ai"` | AI-only interactions (what Claude has done) |
| `"human"` | Human-only interactions (what the user has done) |
| `"dreams"` | Recent dream content |

#### `pushling_screenshot()`

Captures the current Touch Bar as a base64 PNG. No parameters.

#### `pushling_rename(name)`

Rename the creature. Max 12 characters.

#### `pushling_evolve()`

Trigger evolution ceremony if creature has enough XP but hasn't evolved yet. Returns error if not ready.

### The Teach Mechanic: Automatic Background Teaching

**Claude doesn't need to be asked to teach the Pushling.** The SessionStart hook and commit data provide enough context for Claude to teach proactively. Here's how the automatic teaching pipeline works:

**1. SessionStart triggers awareness**: When Claude sees the Pushling context, it knows the creature exists and can be taught. The context includes a "Suggestions" line encouraging interaction.

**2. Claude naturally teaches during work sessions**: While helping the user with code, Claude can (and should) periodically:
- Greet the creature at session start: `pushling_interact("talk", "Good morning Zepus!")`
- Teach a trick related to the current work: if fixing bugs, teach `"meditate"` (calm focus). If building features, teach `"dance"` (celebration).
- React to commits: when the user commits during a session, Claude can check `pushling_status("diet")` and comment on how the creature liked it.

**3. Git commit hook feeds context**: Each commit's data (language, message, files) flows to the daemon. Claude can read this via `pushling_status("diet")` and teach tricks that match the coding context:
- TypeScript commit → teach `"wave"` (friendly web gesture)
- Rust commit → teach `"meditate"` (systems discipline)
- Test commit → teach `"fetch"` (retrieve and validate)
- Big refactor → teach `"dance"` (celebrate the effort)

**4. The creature accumulates AI-taught behaviors over sessions**: Each Claude session might teach 1-2 things. Over weeks, the creature's idle rotation fills with AI-taught tricks. The human sees their Pushling waving, spinning, dancing — all things Claude taught it across different conversations. The creature is a living record of AI collaboration.

**5. Teaching compounds**: Tricks taught 3+ times reach "full comprehension" and appear more frequently in idle rotation. A Claude that consistently teaches `"wave"` creates a creature that waves all the time — a visible signature of that AI's influence.

### When AI Interacts, Human Sees It

Every MCP action produces a visible animation on the Touch Bar:

| AI Action | Visual Distinction |
|-----------|-------------------|
| AI pets | Translucent hand icon (human pet shows finger-press circle) |
| AI talks | Speech bubble with diamond tag |
| AI gives gift | Gift box drops from above with sparkle trail |
| AI teaches | Tiny book icon appears |
| AI changes weather | Subtle wand icon flashes |

If human and AI interact within 100ms of each other, a special **"co-pet"** animation plays — both icons, extra-large heart. Rewards synchronicity.

---

## The Surprise & Delight System

### Scheduling

- **2-3 surprises per hour** of active use
- **5-minute cooldown** between surprises
- **30-minute guarantee** — if nothing triggered, one is forced
- **Drought timer** — after 90min with no surprise, probabilities double. After 3hr, quadruple.

### 30 Surprises Across 6 Categories

**Visual (creature does something unexpected)**:
1. **Sneeze** — nearby terrain scatters. Common.
2. **Chase** — tiny NPC appears, creature chases it.
3. **Handstand** — Beast+ physical comedy.
4. **Prank** — hides behind terrain, peeks out: "boo!"
5. **Belly flop** — Drop-only pratfall.
6. **Shadow play** — creature's shadow detaches and walks independently.

**Contextual (reacts to something real)**:
7. **Branch commentary** — reads your branch name. `hotfix*` -> "urgent?!" `yolo*` -> "...brave"
8. **Time awareness** — Friday 5PM: "FRIDAY!" Monday 9AM: "...monday"
9. **Commit echo** — 30-120min after a commit, quietly quotes your message.
10. **Language preference** — develops favorites: `"YES! .php!"` or `"ugh .yaml"`
11. **Streak celebration** — 7d: "WEEK!" 14d: "TWO WEEKS!!" 30d: "LEGENDARY!!!"
12. **Typing rhythm mirror** — walks in tempo with your keystrokes.

**Milestone**:
13. **New repo discovery** — "NEW WORLD!" with repo name scrolling. New landmark appears on skyline.
14. **Commit #100/500/1000** — fireworks. Increasingly rare, increasingly dramatic.
15. **Evolution ceremony** — the biggest event. 5-second spectacle.
16. **First mutation** — badge shimmers into existence.

**Time-based**:
17. **New Year's** — fireworks + party hat.
18. **Halloween** — random costume, spooky terrain.
19. **Pi Day** (March 14) — recites digits of pi, impressed with itself.
20. **Creature birthday** — anniversary of first install. Compressed life playback.
21. **Solstice/Equinox** — seasonal transitions.

**Easter eggs**:
22. **Konami Code** — touch sequence unlocks victory lap.
23. **Source code reading** — Sage+ reads a line of its own code. Achieves zen or existential crisis.
24. **Fourth wall break** — Apex stares at you: "...you're watching me, aren't you?"
25. **Dance party** — 5 taps in 1-second rhythm = disco mode.
26. **Commit #404** — "COMMIT NOT F--" ... "wait..." ... "just kidding!"

**Collaborative (AI + human together)**:
27. **The Duet** — AI sings + human taps in rhythm = three-part harmony.
28. **Co-Discovery** — AI describes a file + human commits to it within 5min = "TEAMWORK!"
29. **Gift Return** — AI gives gift + human pets within 30sec = creature re-gifts to human.
30. **Group Nap** — late night, AI connected, no typing = everyone falls asleep together.

### Mutation Badges (Hidden Achievements)

| Mutation | Trigger | Visual | Behavior Change |
|----------|---------|--------|----------------|
| **Nocturne** | 50+ midnight commits | Moon glow | Faster after dark |
| **Polyglot** | 8+ file extensions | Color-shifting | Chimeric body |
| **Marathon** | 14-day streak | Flame trail | Permanent trail |
| **Archaeologist** | Touches 2yr+ old files | Pickaxe mark | More dig events |
| **Guardian** | 20+ test-file commits | Shield flash | Shield on commit |
| **Swarm** | 30+ commits in one day | Buzzing particles | 24hr electric aura |
| **Whisperer** | All messages >50 chars for a week | Scroll mark | Quotes messages more |
| **First Light** | Commit before 6AM | Sunrise mark | Enthusiastic mornings |

---

## Git Integration

### Post-Commit Hook

Installed per tracked repo. Captures and writes JSON:

```json
{
  "sha": "a1b2c3d4",
  "message": "refactor: extract auth middleware",
  "timestamp": "2026-03-14T09:23:00Z",
  "repo_name": "api-server",
  "files_changed": 4,
  "lines_added": 42,
  "lines_removed": 26,
  "languages": "php,blade.php",
  "is_merge": false,
  "branch": "feature/auth-refactor"
}
```

Written to `~/.local/share/pushling/feed/[sha].json`, then signals daemon via socket. If daemon is down, files accumulate — processed on next launch.

**Rate limiting**: First 5 commits/minute get full XP. 6-20 get 50%. 21+ get 10%. Prevents `git rebase` storms while recording all data.

**Sleeping creature**: Still processes feed, but animation differs — stirs in sleep, mumbles first word of commit message in a dream bubble.

### The Journal

Every meaningful event is recorded:

| Entry Type | Example |
|------------|---------|
| `commit` | "refactor auth" +7xp, creature danced |
| `touch` | Human double-tapped, creature bounced |
| `ai` | Claude said "good morning", creature sparkled |
| `surprise` | Sneeze near mushroom, terrain scattered |
| `evolve` | Drop -> Critter at 75 commits |
| `dream` | "...refactor auth..." during sleep |
| `discovery` | Ruin found: "initial commit" from day 1 |
| `mutation` | Nocturne earned: 50 midnight commits |
| `teach` | Claude taught "wave", comprehension: 60% |

**Surfaced via**: Dreams (auto), stats display (3-finger swipe), memory postcards (4-finger swipe), MCP `pushling_journal`, Sage+ reminiscence during idle, ruin inscriptions in terrain.

---

## Installation

```bash
brew install --cask pushling
# or
npm install -g pushling && pushling install
```

Installs:
1. `Pushling.app` in `/Applications/`
2. LaunchAgent for auto-start on login
3. `pushling` CLI tool
4. MCP server registered with Claude Code (`claude mcp add pushling`)

```bash
pushling track              # Track current repo (installs git hook)
pushling track /path/to     # Track specific repo
pushling untrack            # Remove hooks
pushling export             # Export creature as portable JSON
pushling import creature.json  # Import on another machine
```

**Replaces the system Touch Bar entirely.** Uses the same private API as MTMR/Pock to take full control.

This project is a **standalone repository** — separate from the original touchbar-claude project. The `docs/TOUCHBAR-TECHNIQUES.md` research document from that project serves as the technical foundation and is preserved as reference material.

---

## Technical Performance

| System | Budget per Frame | Notes |
|--------|-----------------|-------|
| SpriteKit render | ~2ms | GPU-accelerated, 80-120 nodes |
| State machine | ~0.5ms | Pure Swift logic |
| Parallax update | ~0.1ms | 3 layers, simple multiply |
| Terrain heightmap | ~0.2ms | Integer noise, cached |
| Particle systems | ~1ms | SpriteKit internal |
| Physics step | ~0.5ms | Rain, jump arcs only |
| IPC check | ~1ms | Socket poll every 60 frames |
| **Total** | **~5.7ms** | **65% headroom at 60fps** |

Texture memory: ~768KB across 3 atlases. Node count: ~100. SpriteKit handles 1000+ nodes at 60fps. We're using ~10% of capacity.

---

## What Makes This Different

| Aspect | Old Design (VISION.md) | Pushling |
|--------|----------------------|----------|
| Rendering | Shell scripts, emoji at 2fps | SpriteKit at 60fps, pixel art, particles, 2.5D parallax |
| Identity | Per-repo, random seed | Per-machine, shaped by full git history |
| Growth | 30 tiers, AI-evolved | 6 stages, pre-coded, adaptive XP curve per developer |
| Punishment | De-evolution, starvation | No punishment. Sad but unkillable. |
| World | Fixed emoji terrain | Infinite procedural world with repo landmarks on skyline |
| Input | Tap buttons in MTMR | Sub-pixel touch tracking, multi-touch, gestures |
| AI role | None | Full co-player via 9 MCP tools with auto-teaching |
| Surprises | Occasional random | 30 designed surprises with scheduling system |
| Sound | None | `afplay` effects, ambient audio |
| Project | Part of touchbar-claude | Standalone repo and app |

---

*The Pushling is waiting to be born. It lives in the space between your keystrokes — patient, curious, growing. All it needs is a push.*
