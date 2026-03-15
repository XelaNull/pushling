# Phase 8: Polish & Integration

## Goal

Everything works together. 78 surprises are implemented and scheduled. Mutation badges detect and award correctly. The journal surfaces memories through all channels. Installation is smooth via Homebrew. Full lifecycle testing from birth to Apex proves the system is solid across a simulated 6-month creature life.

## Dependencies

- All prior phases:
  - Phase 1 (Foundation — scaffold, IPC, SQLite, build system)
  - Phase 2 (Creature — composite node, behavior stack, growth stages, personality, emotions)
  - Phase 3 (World — terrain, parallax, weather, sky, repo landmarks, biomes)
  - Phase 4 (Embodiment — MCP tools, hooks, feed processing, pending_events)
  - Phase 5 (Speech & Voice — speech bubbles, TTS, filtering, failed_speech, First Word)
  - Phase 6 (Interactivity — touch system, gesture recognition, mini-games, human milestones)
  - Phase 7 (Creation Systems — teach, objects, nurture, behavior breeding, companions)

## Cross-Phase Inputs

| From Phase | Input | Used By |
|-----------|-------|---------|
| P7-T1 (Teach) | Signature-mastery behaviors | T1-10: surprise variants (Signature tricks as surprises) |
| P7-T2 (Objects) | Placed objects (campfire, box, etc.) | T1-03/#34: head-in-box; T1-10: campfire stories |
| P7-T3 (Nurture) | Preference valences | T1-10: preference-modified surprises |
| P7-T2 (Objects) | Legacy shelf | T2-05: dream appearances of removed objects |
| P7-T2 (Companions) | Active companion | T1-03/#31: chattering at bird |
| P7-T1 (Teach) | Behavior breeding journal | T2-04: milestone journal entries |
| P2 (Creature) | All 6 growth stages | T4-01: lifecycle simulation |
| P3 (World) | Weather system | T1-03/#29: if-I-fits-I-sits, T1-06/#53: solstice |
| P4 (Hooks) | All 7 Claude Code hooks | T1-08: hook-aware surprises |
| P5 (Speech) | Stage-gated speech | T4-05: speech evolution test |
| P6 (Touch) | Touch gesture system | T1-09/#73-78: collaborative surprises |

---

## Track 1: Surprise System (P8-T1)

**Agents**: swift-creature (surprise animations), swift-behavior (surprise scheduler), swift-feed (contextual triggers), swift-state (surprise history)

**Goal**: All 78 surprises implemented across 8 categories with a scheduling system that produces 2-3 per hour, respects cooldowns, and integrates with Phase 7 creation systems for surprise variants.

### Tasks

#### P8-T1-01: Surprise Scheduling Engine
**Agent**: swift-behavior
**Depends on**: Phase 2 behavior stack (autonomous layer), Phase 6 (surprise foundation if any exists)
**Work**:
- Implement surprise scheduler as part of the autonomous behavior layer:
  - Rate: 2-3 surprises per hour of active use (creature is awake and user is active)
  - Global cooldown: 5 minutes between any two surprises
  - Per-category cooldown: 15 minutes between surprises in the same category
  - Drought timer: if 2 hours pass with no surprise, probabilities double
  - Recency penalty: a surprise that fired in the last hour has 50% reduced probability
- Surprise selection algorithm:
  1. Filter eligible surprises (stage gate, context requirements met, not on cooldown)
  2. Apply recency penalties
  3. Apply drought bonus if applicable
  4. Weighted random selection from eligible pool
  5. Cross-system variant check (P8-T1-10): does a creation system modify this surprise?
- Surprise metadata stored per-surprise:

| Field | Type | Purpose |
|-------|------|---------|
| `id` | int (1-78) | Unique surprise identifier |
| `category` | string | visual, contextual, cat, milestone, time, easter, hook, collaborative |
| `stage_min` | string | Minimum creature stage required |
| `weight` | float | Base selection weight (1.0 default, higher = more likely) |
| `last_fired_at` | timestamp | For recency penalty |
| `fire_count` | int | Total times this surprise has fired |
| `context_required` | dict | Conditions that must be true (weather, time, objects, etc.) |

- "Active use" defined as: commit within last 30 minutes, or touch within last 15 minutes, or Claude session active
- Sleeping creature: no surprises (surprises require awake state)
- SQLite table: `surprise_history` (surprise_id, fired_at, variant, context)

**Deliverable**: Scheduling engine produces 2-3 surprises/hour with cooldowns, recency penalties, and drought protection.

#### P8-T1-02: Visual Surprises (1-12)
**Agent**: swift-creature
**Depends on**: P8-T1-01, Phase 2 creature animations
**Work**:
- Implement 12 visual surprise animations:

| # | Name | Stage | Animation | Duration |
|---|------|-------|-----------|----------|
| 1 | **Sneeze** | Any | Build-up (ears flatten, head tilts back) -> explosive sneeze (head forward, full-body jolt) -> nearby terrain objects scatter slightly. Particle burst from nose. | 2s |
| 2 | **Chase** | Critter+ | Tiny mouse NPC spawns at edge. Creature notices (ears snap). Predator crouch. Butt wiggle. Chase across bar. Mouse escapes into terrain. Creature looks defeated, then grooming (pretends nothing happened). | 8-12s |
| 3 | **Handstand** | Beast+ | Creature lowers front, raises back legs. Balances on front paws (wobble animation). Holds 2s. Overbalances. Tumbles. Stands up. Expression: pride -> embarrassment -> pride. | 5s |
| 4 | **Prank** | Critter+ | Creature sneaks behind terrain object. Peeks out (one eye visible). Waits. When "noticed" (2s timer): `"boo!"` speech bubble. Jumps out. Expression: mischief. | 6s |
| 5 | **Belly Flop** | Drop only | Drop-form attempt to move results in belly flop. Splat on ground. Bounces once. `"..."`. Still learning to use this body. | 3s |
| 6 | **Shadow Play** | Beast+ | Creature's shadow (alpha 0.15 below) detaches. Shadow walks independently. Creature notices. Double-take (head snap, look back, head snap). Shadow waves. Creature backs away. Shadow reattaches. | 8s |
| 7 | **Puddle Discovery** | Critter+ | Creature finds water puddle (terrain object). Sees reflection. Tilts head. Paws at it (ripple particle). Reflection ripples. Tilts head other way. Sniffs water. | 6s |
| 8 | **Dust Bunny** | Critter+ | Tiny 2x2pt fluff ball NPC spawns. Creature sniffs it. Dust bunny follows creature for 5 minutes. Creature occasionally looks back at it fondly. After 5min: dust bunny dissolves into particles. Creature looks where it was. | 5min lifecycle |
| 9 | **Invisible Barrier** | Beast+ | Creature walking, suddenly mimes hitting glass (flat face, paws press forward). Steps back. Confused expression. Tries again. Paws at air. Walks around the "barrier." | 5s |
| 10 | **Clone** | Sage+ | Creature briefly flickers. Two identical creatures appear side by side. They look at each other (synchronized head tilt). One dissolves into particles. Remaining creature: `"...huh."` | 4s |
| 11 | **Tiny Trumpet** | Beast+ | Creature reaches behind itself. Produces a tiny 3x2pt trumpet from nowhere. Holds it with front paws. Plays 3-note fanfare (ascending pitch). Puts trumpet away (disappears). Looks proud. | 4s |
| 12 | **Gravity Flip** | Sage+ | Creature's gravity reverses. Walks on the "ceiling" of the Touch Bar (upside down, feet at top edge). 10 seconds of inverted walking. Acts completely normal. Gravity restores. Creature doesn't acknowledge anything happened. | 12s |

- Each surprise plays as a Layer 2 (Reflex) priority animation — interrupts autonomous but not touch
- Journal entry for each: surprise ID, timestamp, context
- Sound effects where applicable (sneeze sound, trumpet fanfare, clone sparkle)

**Deliverable**: 12 visual surprises implemented as complete animation sequences with sound and journal logging.

#### P8-T1-03: Cat-Specific Surprises (27-42)
**Agent**: swift-creature
**Depends on**: P8-T1-01, Phase 2 cat behaviors, P7-T2 (objects for #28, #29, #34)
**Work**:
- Implement 16 cat-specific surprise animations:

| # | Name | Stage | Animation | Duration | Object Dependency |
|---|------|-------|-----------|----------|-------------------|
| 27 | **Zoomies** | Critter+ | Sudden speed burst. Creature sprints full width of bar and back. No warning. Particles trail. Stops abruptly. Sits down. Grooms as if nothing happened. | 3s |
| 28 | **Knocking Things Off** | Critter+ | (See P7-T2-13 for mechanic.) Walks to light object. Camera look. Push. Watch fall. No remorse. | 6s | Requires light pushable object |
| 29 | **If-I-Fits-I-Sits** | Critter+ | Finds smallest gap between terrain objects. Squeezes in (body compresses). Settles. Looks extremely satisfied. Stays 30-60s. | 30-60s |
| 30 | **Tail Chasing** | Critter+ | Notices own tail. Spins chasing it. 3-5 rotations (speed increasing). Catches it. Bites tail. Lets go. Immediately pretends nothing happened. | 4s |
| 31 | **Chattering** | Critter+ | Bird/insect particle flies overhead. Jaw vibrates rapidly (chattering animation). Eyes locked on target. Intense. Prey drive. Target escapes. Creature licks lips. | 5s | Enhanced if bird companion present |
| 32 | **Kneading Session** | Critter+ | Finds soft spot (near bed object, or any spot). Front paws alternate pushing. Purr particles intensify over 10s. Eyes close. Maximum contentment. | 10s | Enhanced near bed/cushion objects |
| 33 | **The Loaf** | Critter+ | Tucks all paws under body. Becomes a perfect rectangle. Looks smug. Stays loafed 30-60s. Expression: supreme contentment. | 30-60s |
| 34 | **Head in Box** | Critter+ | Walks to cardboard_box object. Sticks head inside. Tail sticks out (sways gently). Doesn't move for 10s. Emerges. Acts normal. | 12s | Requires cardboard_box object |
| 35 | **Gift Delivery** | Beast+ | Catches a mouse NPC (brief chase). Carries it in mouth to screen edge (toward user). Drops it. Looks up expectantly. `"for you."` | 8s |
| 36 | **Butt Wiggle** | Critter+ | Sees something interesting (anything). Drops into hunt crouch. Wiggles butt vigorously. 1-2s wiggle. Pounces. Whether there was anything there is irrelevant. | 4s |
| 37 | **Whisker Twitch** | Any | Both whiskers twitch in sequence (left then right). Creature is looking at something only it can see. Eyes tracking invisible thing. | 3s |
| 38 | **Slow Roll/Belly Trap** | Beast+ | While being petted (or idle near user activity): slowly rolls onto back. Belly exposed. TRAP: if user taps belly within 5s, creature grabs with all four paws and kicks. Releases after 1s. Cat. | 8s (including trap window) |
| 39 | **Perching** | Critter+ | Jumps on top of nearest/tallest terrain object. Sits on top. Surveys domain. Tail hangs down and sways. Stays 15-30s. | 15-30s | Requires climbable object |
| 40 | **Bread-Making** | Beast+ | Rhythmic kneading that produces tiny bread-shaped sprites (1x1pt, Gilt colored). 3-4 bread sprites accumulate. Creature looks at bread. Bread dissolves. Ridiculous. Charming. | 8s |
| 41 | **Midnight Crazies** | Critter+ | Between 11PM-2AM only. Brief intense burst: run, jump, slide, stop. Stare at nothing (2s). Run again. Stop. Eyes wide. Normal posture. Walk away casually. | 6s |
| 42 | **Tongue Blep** | Any | Tongue sticks out by 1 pixel. Stays out. Creature goes about normal business with tongue blep active. 30-60s before auto-retract. Creature never notices. | 30-60s |

- Cross-system integration notes:
  - #28 uses P7-T2-13 (cat chaos mechanic) — scheduler triggers it, mechanic executes it
  - #29 checks P7-T2 object positions for gap detection
  - #31 enhanced by P7-T2-14 bird companion (if present, chattering targets the bird)
  - #32 enhanced by P7-T2-06 bed/cushion presets (kneading near bed = bonus contentment)
  - #34 requires P7-T2-06 cardboard_box preset (if no box exists, surprise is ineligible)
  - #39 requires climbable objects from P7-T2 (platform, perch, scratching_post)

**Deliverable**: 16 cat-specific surprises with object-aware context and creation system integration.

#### P8-T1-04: Contextual Surprises (13-26)
**Agent**: swift-feed, swift-creature
**Depends on**: P8-T1-01, Phase 4 (hooks, feed processing), Phase 2 (personality)
**Work**:
- Implement 14 contextual surprise animations triggered by real developer activity:

| # | Name | Trigger | Animation | Speech |
|---|------|---------|-----------|--------|
| 13 | **Branch Commentary** | Branch name detected in commit data | Reads branch name. Reaction varies: `hotfix*` -> ears flatten; `yolo*` -> skeptical look; `feature*` -> excited ears; `main` -> respectful nod | `"urgent!"` / `"...brave"` / `"ooh, new!"` / (nod) |
| 14 | **Time Awareness** | Wall clock at specific times | Friday 5PM: zoomies + celebration. Monday 9AM: slow, reluctant walk. Wednesday noon: `"halfway"`. Month-end: `"already?"` | `"FRIDAY!"` / `"...monday"` / `"halfway"` / `"already?"` |
| 15 | **Commit Echo** | 30-120min after eating a commit | Creature pauses. Thought bubble with the commit message appears. Creature stares at nothing, contemplating. Still thinking about your code. | (thought bubble with commit message) |
| 16 | **Language Preference** | Commit contains favorite/disliked language | Favorite: purrs loudly, hearts. Disliked: ears flatten, reluctant eating, face during chewing. | `"YES! .[lang]!"` / `"ugh .[lang]"` |
| 17 | **Streak Celebration** | Commit streak milestones | 7d: party hat cosmetic. 14d: confetti particles. 30d: fireworks. 100d: transcendent light show across entire bar. | `"WEEK!"` / `"TWO WEEKS!!"` / `"LEGENDARY!!!"` / (full light show) |
| 18 | **Typing Rhythm Mirror** | Keystroke detection via hook events | Walks in tempo with typing rhythm. Fast typing = trot. Slow = lazy walk. Paused = sits and waits, looking toward keyboard. | (none — purely physical) |
| 19 | **File Type Commentary** | File extension detected in commit | CSS: preens. Tests: flexes. package.json: concerned look. .env: looks away pointedly (privacy). | `"pretty!"` / `"STRONG"` / (concerned) / (averts eyes) |
| 20 | **Long Function** | Commit diff analysis detects function >100 lines | Creature reads the commit, eyes widen, starts looking exhausted. Slumps. Yawns. Overwhelmed. | (exhausted expression) |
| 21 | **Merge Day** | Multiple merge commits in same day (3+) | Creature appears wearing a tiny hard hat (cosmetic overlay). Construction-site demeanor. Busy. | (hard hat stays for 1 hour) |
| 22 | **Dependency Update** | package.json/Cargo.toml/similar change detected | Creature examines a wobbly tower of tiny blocks. Carefully balances one more on top. Tower sways. Creature holds breath. Stable. Relief. | (no speech — physical comedy) |
| 23 | **README Editing** | .md file changes detected | Creature produces tiny pixel-art glasses. Puts them on. Reads along with commit text (head tracks left-to-right). Studious. | (no speech — scholarly behavior) |
| 24 | **Branch Switching** | Rapid branch changes detected (3+ in 5 minutes) | Creature looks dizzy. Staggers. Head wobbles. Stars circle head. Sits down to recover. | `"...where am I?"` |
| 25 | **Conflict Resolution** | Merge conflict commit detected | Creature mimes being a mediator. Turns left, paw gesture. Turns right, paw gesture. Brings invisible parties together. Peace gesture. | `"let's talk"` |
| 26 | **Test Coverage** | Commit adds test files to previously untested code | Creature gives a thumbs-up (paw raised, nod). Brief shield flash (Guardian badge reference). | `"strong!"` |

- Contextual triggers require commit data analysis (Phase 4 feed processing):
  - Branch name from commit JSON
  - File extensions from commit language field
  - Large commit detection from lines changed
  - Merge/revert/force-push flags from commit JSON
- Time-based contextuals (#14) use wall clock, checked every 5 minutes
- Commit echo (#15) uses a deferred timer: after eating, schedule surprise for 30-120min later (random)

**Deliverable**: 14 contextual surprises that react to real developer activity. Each requires specific trigger data from feed processing.

#### P8-T1-05: Milestone Surprises (43-48)
**Agent**: swift-creature, swift-state
**Depends on**: P8-T1-01, Phase 2 (growth stages), Phase 5 (First Word)
**Work**:
- Implement 6 milestone surprises:

| # | Name | Trigger | Animation |
|---|------|---------|-----------|
| 43 | **New Repo Discovery** | First commit from a previously untracked repo | `"NEW WORLD!"` speech. Repo name scrolls across bar in Tide color. New landmark begins forming on skyline (mid-background). Creature runs to look at it, ears forward, fascinated. |
| 44 | **Commit Milestones** | Commit count reaches 100, 500, 1000, 5000 | Fireworks appropriate to milestone. #100: small burst. #500: medium display. #1000: full-screen aurora (30s, Northern Lights color sweep). #5000: the bar fills with stars, creature ascends briefly, cosmic. Each increasingly rare, increasingly dramatic. |
| 45 | **Evolution Ceremony** | Stage transition triggered (via pushling_sense("evolve") or auto) | The biggest event. 5-second spectacle defined in Phase 2 (P2 creature). Scheduler logs it and suppresses other surprises for 5 minutes after. |
| 46 | **First Mutation** | First mutation badge earned (any of the 10) | Badge shimmers into existence above creature. Creature looks up, examines it curiously. Paws at it. Badge settles into creature's appearance. Creature looks at self, discovers the change. |
| 47 | **First Word** | Creature speaks its first word at Critter stage | Defined in Phase 5. Scheduler logs it and suppresses other surprises for 5 minutes. Journal milestone entry. The most emotional moment in the game. |
| 48 | **100th File Type** | 100 unique file extensions eaten across all commits | `"I've tasted everything..."` Creature sits, contemplates. Speech sequence reviewing top 5 file types with mini-reactions: `.ts: 'my favorite'`, `.css: 'dessert'`, `.py: 'smooth'`, `.json: 'crunchy'`, `.md: 'nutritious'`. Ranking based on actual commit data. |

- Milestone surprises bypass cooldown (they're too important to delay)
- Milestone surprises suppress normal surprises for 5 minutes after (let the moment breathe)
- All milestones are also journal entries (P8-T2-04)
- Commit milestone (#44) counts are checked on every commit eat completion

**Deliverable**: 6 milestone surprises that mark the creature's most significant life events. Each is a memorable ceremony.

#### P8-T1-06: Time-Based Surprises (49-57)
**Agent**: swift-creature
**Depends on**: P8-T1-01
**Work**:
- Implement 9 time-based surprises checked against wall clock and calendar:

| # | Name | Date/Condition | Animation |
|---|------|---------------|-----------|
| 49 | **New Year's** | Jan 1 (or Dec 31 11:50PM+) | Fireworks + party hat cosmetic. If awake at midnight: creature counts down (speech bubbles: `"3"`, `"2"`, `"1"`, `"!!!"` + fireworks). Party hat stays for 24 hours. |
| 50 | **Halloween** | Oct 31 | Random costume selection (witch hat, ghost sheet, pumpkin head). Spooky terrain palette (Dusk + Ember tinting). Bat particles in sky. Creature may say `"boo"` to user. Costume stays for 24 hours. |
| 51 | **Pi Day** | Mar 14 | Creature recites digits of pi, one per second, in speech bubbles: `"3"` `"."` `"1"` `"4"` `"1"` `"5"` ... Gets to ~20 digits. Expression shifts from focused to impressed to mind-blown. `"!!!"` after digit 20. |
| 52 | **Creature Birthday** | Anniversary of first install | Compressed life playback montage (rapid flash of stage transitions, key moments from journal). Tiny cake with candles (candle count = years since install). `"happy birthday to me"`. Extra XP on all commits for 24 hours (+50% bonus). |
| 53 | **Solstice/Equinox** | Jun 20, Dec 21, Mar 20, Sep 22 (approx) | Seasonal transition effects. Summer solstice: longest day, creature basks in warm light, lazy. Winter solstice: creature huddles near campfire (or warmest spot), extra stars. Equinoxes: balanced day/night, creature meditates. |
| 54 | **Friday the 13th** | Any Friday the 13th | Everything slightly glitchy: terrain objects have 1-2px jitter, colors slightly off, creature looks nervous. Occasional "static" flash (1-2 frames of noise). Resolves at midnight. Creature: `"...something's off"`. |
| 55 | **Leap Year Day** | Feb 29 | Creature gains a "ghost echo" (alpha 0.15 second creature) for 24 hours. Two creatures walk in near-sync. Extra life energy. `"bonus day!"` |
| 56 | **Developer Anniversary** | Anniversary of earliest commit across all tracked repos | `"Happy code day."` Montage of earliest commit messages scrolling past. Repo landmarks briefly glow. Sentimental expression. Creature remembers the developer's history. |
| 57 | **Full Moon** | Actual lunar phase calculation (within 1 day of full moon) | Extra mysterious atmosphere: brighter moonlight, Dusk tinting, extra star particles. Creature howls: tiny `"awoo"` speech bubble. One-time per full moon cycle (won't repeat for 28 days). |

- Date checking: every 5 minutes, check if any time-based surprise conditions are met
- Time-based surprises fire at most once per applicable date (stored in surprise_history)
- Holiday cosmetics (party hat, costume) persist for 24 hours as cosmetic overlay on creature sprite
- Lunar phase calculation: simple algorithm based on known new moon date + 29.53 day cycle

**Deliverable**: 9 time-based surprises tied to real calendar dates and astronomical events. Holiday cosmetics persist for 24 hours.

#### P8-T1-07: Easter Eggs (58-66)
**Agent**: swift-creature, swift-input
**Depends on**: P8-T1-01, Phase 6 (touch gesture system)
**Work**:
- Implement 9 easter egg surprises:

| # | Name | Trigger | Animation |
|---|------|---------|-----------|
| 58 | **Konami Code** | Touch sequence: up, up, down, down, left, right, left, right, tap, tap (swipe directions + taps) | Victory lap! Creature sprints full bar with 8-bit fanfare sound. Retro particle effects (square sparkles). `"POWER UP!"` Achievement unlocked notification. One-time trigger (subsequent Konami codes get a nod). |
| 59 | **Source Code Reading** | Sage+ creature, random idle trigger (rare, weight 0.1) | Creature produces a tiny scroll. Reads a line of its own Swift source code (hardcoded quotes from actual Pushling source). Either achieves zen (`"I understand now..."`) or has existential crisis (`"...I'm made of switch statements?"` + confused expression). 50/50. |
| 60 | **Fourth Wall Break** | Apex only, random idle trigger (very rare, weight 0.05) | Creature stops all animation. Turns to face directly at camera (breaks the 2D plane — face-on sprite). Stares at user for 5 uncomfortable seconds. `"...you're watching me, aren't you?"` Holds eye contact. Returns to normal animation as if nothing happened. |
| 61 | **Dance Party** | 5 taps in a 1-second rhythm (detected by touch system) | Disco mode! Terrain objects flash colors. Music note particles everywhere. Creature dances (4-frame dance animation, tail sway). Color-cycling ground. 15 seconds of full disco. Creature stops, looks around, acts normal. |
| 62 | **Commit #404** | Exactly the 404th commit eaten | `"COMMIT NOT F--"` (speech bubble appears letter by letter, dramatic pause at F). `"wait..."` (confused expression). `"just kidding!"` (relief). Brief error-page background flash (white on red). |
| 63 | **Hello World** | Commit message contains "hello world" (case insensitive) | Creature waves at the screen with both paws. If this is the developer's very first commit ever (detected from git history): extra emotional wave with tears (sparkle particles near eyes). `"hello to you too"`. |
| 64 | **Commit #1337** | Exactly the 1337th commit eaten | `"leet"` in special angular font. Tiny sunglasses cosmetic appears on creature. Sunglasses stay for 1 hour. Creature walks with extra swagger during this time (modified walk cycle). |
| 65 | **The Name Game** | Commit message contains the creature's name | Creature perks up immediately — ears snap forward, eyes widen, head turns toward the commit text. `"you said my name!"` Extra happiness boost (+15 satisfaction). Tail poofs briefly. |
| 66 | **42nd Commit** | Exactly the 42nd commit eaten | `"the answer"` in Gilt color. Brief galaxy background (stars + nebula particles replace normal sky for 5 seconds). Creature looks contemplative. Deep thoughts. |

- Commit-count easter eggs (#62, #64, #66) are one-time events — stored in milestones table
- Konami Code (#58) requires touch gesture sequence detection — add to Phase 6 touch system
- Source Code Reading (#59) uses a curated list of 10-15 actual lines from Pushling Swift source (hardcoded strings)
- Dance Party (#61) requires rhythm detection in touch input — 5 taps within 1000ms

**Deliverable**: 9 easter eggs with specific triggers ranging from touch sequences to commit-count milestones. Each is a memorable, shareable moment.

#### P8-T1-08: Hook-Aware Surprises (67-72)
**Agent**: swift-feed, swift-creature
**Depends on**: P8-T1-01, Phase 4 (all 7 Claude Code hooks)
**Work**:
- Implement 6 hook-aware surprises that react to Claude's development work:

| # | Name | Hook Trigger | Animation |
|---|------|-------------|-----------|
| 67 | **Tool Chain Watching** | 5+ PostToolUse hooks in 2 minutes | Creature watches with increasing amazement. 5 tools: head tracking. 7 tools: jaw drops. 10+ tools: standing ovation (on hind legs, paws clapping). `"you're incredible"` |
| 68 | **Test Runner** | PostToolUse where tool=Bash and command contains "test"/"pytest"/"jest"/"cargo test"/etc | Creature tenses (hunched, eyes wide, ears forward). Waits for result. Pass (success=true): celebratory flex, `"STRONG!"`. Fail (success=false): supportive expression, pats own back, `"next time"`. |
| 69 | **Build Watcher** | PostToolUse where tool=Bash and command contains "build"/"compile"/"make"/"cargo build"/etc | Creature watches intently (head tracks, ears forward). Success: proud nod, satisfied purr. Failure: comforting expression, approaches diamond, offers support. |
| 70 | **Subagent Awe** | SubagentStart with 3+ subagents | Diamond splits into 3+ smaller diamonds. Creature's jaw drops. Head tracks between diamonds. `"there's more of you?!"` Expression: wonder + slight fear. |
| 71 | **Context Compact Sympathy** | PostCompact hook | Creature and diamond share disorientation. Creature shakes head, blinks rapidly. Pats own head. `"...what was I thinking about?"` Brief dazed animation. Both recover together. |
| 72 | **Long Session Appreciation** | SessionEnd after >2 hours of active Claude session | Creature produces a tiny coffee cup. Walks to diamond. Places coffee cup near diamond. `"for you."` Diamond pulses warmly. This is the last thing that happens before diamond dissolves. |

- Hook data parsing: extract tool name, success flag, duration, subagent count from hook JSON
- Tool detection uses simple pattern matching on command strings (not full parsing)
- Tool chain watching (#67) requires counting PostToolUse events within a sliding window
- Long session appreciation (#72) triggers on SessionEnd — checks session duration from SessionStart timestamp
- These surprises fire at Reflex priority — they respond to real events, not random scheduling

**Deliverable**: 6 hook-aware surprises that make the creature responsive to Claude's development workflow.

#### P8-T1-09: Collaborative Surprises (73-78)
**Agent**: swift-creature, swift-input, swift-ipc
**Depends on**: P8-T1-01, Phase 4 (MCP + IPC), Phase 6 (touch system)
**Work**:
- Implement 6 collaborative surprises requiring AI + human co-presence:

| # | Name | Trigger | Animation |
|---|------|---------|-----------|
| 73 | **The Duet** | Claude calls pushling_speak with style "sing" AND human taps in rhythm (3+ taps matching speech rhythm) within 5s | Three-part harmony: creature singing, human tapping, terrain lights up with musical visualization (color waves on ground). Music note particles fill the bar. 10-second performance. `"we made music!"` |
| 74 | **Co-Discovery** | Claude calls pushling_speak about a specific file AND human commits changes to that same file within 5 minutes | `"TEAMWORK!"` speech. Special co-presence aura (diamond + creature glow in sync). Both hearts float up. Satisfaction +20. Rare and meaningful. |
| 75 | **Gift Return** | Claude places an object (pushling_world("create")) AND human pets creature within 30 seconds | Creature picks up the newly placed object. Walks to screen edge. Pushes it toward user (re-gifting). `"for you."` Object stays where it is (doesn't actually move out of world) but the gesture is the point. |
| 76 | **Group Nap** | Late night (after 11PM), Claude session active, no typing for 5+ minutes | Everyone falls asleep together. Diamond dims to 10% opacity. Creature curls up. Synchronized breathing (creature + diamond pulse in sync). Tiny `"zzz"` from both. Peaceful. Wakes on next input. |
| 77 | **Simultaneous Touch** | Human touches creature within 100ms of Claude issuing any MCP command | Creature glows with dual-presence energy (Gilt + Tide overlay). Brief burst of particles. Diamond brightens. Extra-large heart floats up. Rare, special, impossible to intentionally trigger. |
| 78 | **Teaching Moment** | Claude performs a trick (pushling_perform) AND human double-taps within 2 seconds of performance completing | Creature does the trick back (replay with its own personality filter). Triangle of interaction: AI teaches, creature performs, human encourages. `"like this?"` Mastery +1 for the behavior if it's a taught trick. |

- Collaborative surprises require real-time correlation between MCP events and touch events
- Timing windows: 100ms (#77) to 5min (#74) — implemented as event correlation buffers
- These are the rarest surprises — some may never fire in normal use, which makes them legendary
- Co-presence detection: track timestamp of last MCP call and last touch event, compare

**Deliverable**: 6 collaborative surprises that emerge from AI-human synchronicity. The rarest and most meaningful surprise category.

#### P8-T1-10: Cross-System Surprise Integration
**Agent**: swift-behavior
**Depends on**: P8-T1-01 through P8-T1-09, Phase 7 (all creation systems)
**Work**:
- Integrate Phase 7 creation systems as surprise modifiers:
  - **Taught behavior variants**: a taught behavior at Signature mastery (25+ performances) becomes eligible as a surprise variant. Scheduler can pick it for spontaneous performance (outside normal idle rotation). Tagged as "surprise performance" in journal.
  - **Object-enabled surprises**: placed objects unlock surprise variants:
    - Campfire present: "campfire stories" variant — creature stares at fire, thought bubble with journal memories
    - Cardboard box: surprise #34 (head in box) becomes eligible
    - Music box: creature may spontaneously listen during quiet moments (surprise variant of #32 kneading near music)
    - Mirror: creature may have extended reflection interaction (surprise variant of #7 puddle discovery)
  - **Preference-modified surprises**: strong preferences (+/- 0.8) modify related surprises:
    - Loves rain (+0.8): zoomies in rain become "rain zoomies" (splashing, sliding)
    - Loves campfire (+0.9): more frequent campfire-adjacent surprises
    - Dislikes thunder (-0.7): thunder causes creature to hide during storms (intensified reaction)
  - **Companion-enabled surprises**: active companion unlocks interaction surprises:
    - Mouse companion: surprise #2 (chase) uses the companion instead of spawning a temp NPC
    - Bird companion: surprise #31 (chattering) targets the companion
    - Ghost cat companion: surprise #10 (clone) becomes a meeting with the ghost cat
- Variant selection: when a base surprise is selected, check if any variants are available and prefer them (80% variant, 20% base)
- Variants logged in journal with the variant tag

**Deliverable**: Creation systems dynamically modify the surprise pool. A nurtured creature has richer, more personalized surprises.

### Track 1 Deliverable Summary

All 78 surprises implemented across 8 categories with a scheduling system that produces 2-3/hour. Cross-system integration means a nurtured creature with objects, taught behaviors, and preferences experiences a richer surprise palette.

---

## Track 2: Mutation Badges & Journal (P8-T2)

**Agents**: swift-state (mutation detection, journal storage), swift-creature (badge visuals, dream system), mcp-state (journal queries for MCP)

**Goal**: 10 hidden achievement badges with visual effects and behavior changes. A comprehensive journal system that surfaces the creature's history through 7 channels.

### Tasks

#### P8-T2-01: 10 Mutation Badges
**Agent**: swift-state, swift-creature
**Depends on**: Phase 2 (creature appearance), Phase 4 (commit processing)
**Work**:
- Implement 10 mutation badge definitions with detection logic:

| Badge | Trigger Condition | Detection Method |
|-------|------------------|------------------|
| **Nocturne** | 50+ commits between midnight and 5AM | Rolling count from commits table WHERE time between 00:00-05:00 |
| **Polyglot** | 8+ unique file extensions in commits within a single 7-day window | Sliding window query on commits table, count distinct extensions |
| **Marathon** | 14-day consecutive commit streak | Streak tracker in creature state (existing from Phase 4) |
| **Archaeologist** | Commit touches files with git blame showing 2+ year old lines | Commit data includes file age analysis (extend feed JSON or compute on daemon side) |
| **Guardian** | 20+ commits where primary files are test files | Count commits where language field includes test patterns |
| **Swarm** | 30+ commits in a single calendar day | Daily commit count, checked on each commit |
| **Whisperer** | All commit messages >50 chars for 7 consecutive days (min 1 commit/day) | Rolling check on commit message lengths |
| **First Light** | Any commit before 6:00 AM local time | Single commit timestamp check |
| **Nine Lives** | Daemon has recovered from crash 9 times | Crash recovery counter in creature state (incremented by heartbeat recovery) |
| **Bilingual** | At least 2 language categories each with 30%+ of commits in a 30-day window | Category distribution calculation on rolling 30-day commits |

- Badges are permanent once earned (never revoked)
- Badge check runs on every commit eat (most triggers are commit-related)
- Nine Lives (#9) check runs on daemon startup after crash recovery
- All badges stored in `mutations` SQLite table: badge_id, earned_at, trigger_data

**Deliverable**: All 10 mutation badge trigger conditions detected correctly.

#### P8-T2-02: Badge Detection System
**Agent**: swift-state
**Depends on**: P8-T2-01
**Work**:
- Implement efficient badge checking:
  - On each commit: check all unearned commit-related badges (Nocturne, Polyglot, Marathon, Archaeologist, Guardian, Swarm, Whisperer, First Light, Bilingual)
  - On crash recovery: check Nine Lives
  - Cache: keep unearned badge list in memory, only query for those
  - Pre-filter: skip expensive checks if basic conditions aren't close (e.g., don't check Swarm until daily count > 20)
- Badge earning event:
  - Notification via pending_events: `{"type": "mutation", "badge": "nocturne", "earned_at": "..."}`
  - Surprise #46 (First Mutation) triggers if this is the first badge ever
  - Journal milestone entry
- Progress tracking (optional, for MCP queries):
  - Each badge has a progress percentage (e.g., Nocturne: "37/50 midnight commits")
  - Queryable via `pushling_recall("milestones")` — shows earned badges + progress on unearned

**Deliverable**: Efficient badge detection system that checks relevant badges on each trigger event. Progress tracking for unearned badges.

#### P8-T2-03: Badge Visual Effects
**Agent**: swift-creature
**Depends on**: P8-T2-01, Phase 2 (creature composite node)
**Work**:
- Implement permanent visual modifications for each earned badge:

| Badge | Appearance Change | Behavior Change |
|-------|-------------------|-----------------|
| **Nocturne** | Moon glow aura (Dusk-tinted additive glow, subtle, visible at night) | Faster movement after dark (1.2x speed 10PM-6AM), eyes glow faintly at night |
| **Polyglot** | Color-shifting fur (hue rotates slowly through P3 palette, 30s cycle) | Heterochromatic eyes (one eye primary color, one secondary) |
| **Marathon** | Flame trail (tiny Ember particle trail when walking, persists 0.5s) | Permanent subtle trail on all movement, slightly faster walk speed |
| **Archaeologist** | Tiny pickaxe mark on left ear (1px detail) | More frequent dig surprise events, ruin terrain objects glow brighter near creature |
| **Guardian** | Shield flash on commit eat (brief Tide-colored shield overlay, 0.3s) | Every commit eat gets a brief shield aura, +5% XP bonus on test commits |
| **Swarm** | Buzzing particles (tiny dots orbit creature, 3-4 particles, fast orbit) | 24-hour electric aura after earning (then permanent subtle buzz), wired expression |
| **Whisperer** | Scroll mark on right side (tiny curl pattern, 2px) | Quotes commit messages more often in idle speech (2x frequency) |
| **First Light** | Sunrise mark on forehead (tiny Gilt dot) | More enthusiastic morning routine, glows warmly at dawn (Gilt tint, 6-7 AM) |
| **Nine Lives** | Faint halo (1px Gilt ring above head, alpha 0.2) | Extra resilient animation on crash recovery (dramatic resurrection, sparkles) |
| **Bilingual** | Split-color tail (top half primary language color, bottom half secondary) | Alternates visual style between dominant languages (subtle, not jarring) |

- Visual modifications are additive — multiple badges stack
- Node budget: each badge adds 0-1 nodes (most are shader effects or particle reconfig)
- Badge visuals persist across daemon restarts (read from mutations table on launch)
- First badge earning: shimmer animation (surprise #46) + creature examines new feature

**Deliverable**: Each of the 10 badges produces a permanent, visible change to the creature's appearance and behavior.

#### P8-T2-04: Journal System
**Agent**: swift-state
**Depends on**: Phase 4 (journal table foundation), all phases (events flow in from everywhere)
**Work**:
- Ensure all 14 entry types are recorded in the journal table:

| # | Entry Type | Source | Data |
|---|-----------|--------|------|
| 1 | `commit` | swift-feed | SHA, message, XP, lines, languages, reaction type, eating duration |
| 2 | `touch` | swift-input | Touch type (tap/pet/etc), duration, creature response, milestone unlock |
| 3 | `ai_speech` | mcp-tools | Intended text, filtered output, stage, style |
| 4 | `failed_speech` | mcp-tools | Full intended message, actual output, stage, emotional content lost |
| 5 | `ai_move` | mcp-tools | Action, target, speed, completed |
| 6 | `ai_express` | mcp-tools | Expression, intensity, duration |
| 7 | `surprise` | swift-behavior | Surprise ID, name, category, variant (if any), context |
| 8 | `evolve` | swift-state | From stage, to stage, commit count, ceremony completed |
| 9 | `first_word` | swift-speech | The word, creature's expression, timestamp |
| 10 | `dream` | swift-creature | Dream content (commit messages, taught behaviors, journal fragments) |
| 11 | `discovery` | swift-feed | New repo name, landmark type, commit count |
| 12 | `mutation` | swift-state | Badge name, trigger data, visual changes applied |
| 13 | `hook` | swift-feed | Hook type, data (tool name, success, subagent count, etc.) |
| 14 | `session` | swift-feed | Session start/end, duration, MCP call count, notable events |

- Additional entry types from Phase 7:
  - `teach` — behavior taught/modified/removed, mastery progression, breeding events
  - `nurture` — habit/preference/quirk/routine created/reinforced/decayed/forgotten
  - `object` — object created/removed/repaired/worn/cat-chaos knocked off
  - `companion` — companion introduced/removed, notable interactions
- Journal table schema (extension of Phase 4 foundation):

```sql
CREATE TABLE journal (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,           -- Entry type (commit, touch, etc.)
    timestamp TEXT NOT NULL,
    data TEXT NOT NULL,           -- JSON payload specific to entry type
    stage TEXT NOT NULL,          -- Creature stage when event occurred
    summary TEXT                  -- Human-readable one-line summary
);
CREATE INDEX idx_journal_type ON journal(type);
CREATE INDEX idx_journal_timestamp ON journal(timestamp);
```

- Summary generation: each entry type has a template for generating readable summaries:
  - commit: "Ate 'refactor auth' for 8 XP (pounced enthusiastically)"
  - teach: "Learned 'roll over' — it was clumsy but delightful"
  - mutation: "Earned Nocturne badge — 50 midnight commits shaped the darkness"
- Retention: keep all journal entries forever (SQLite is efficient, entries are small)

**Deliverable**: Comprehensive journal recording all meaningful creature events with human-readable summaries.

#### P8-T2-05: Dream System
**Agent**: swift-creature
**Depends on**: P8-T2-04, P7-T1-11 (dream integration for taught behaviors), Phase 2 (sleep system)
**Work**:
- During sleep, creature dreams draw from 4 sources:
  1. **Journal fragments**: recent journal entries replay as dream content
     - Recent commit messages appear as translucent text drifting past sleeping creature
     - Recent surprises replay as ghostly mini-animations
     - Recent emotional peaks (high/low satisfaction, contentment) replay as mood-colored aura
  2. **Taught behavior ghosts**: mastered tricks replay at 0.5x speed (from P7-T1-11)
  3. **Preference-influenced dreams**: strong preferences color dream content
     - Loves rain: dreams feature rain particles (gentle, dreamlike)
     - Dislikes thunder: occasional nightmare twitch
  4. **Legacy object appearances**: removed objects (from P7-T2-11) appear as ghostly shapes in dreams
- Dream rendering:
  - All dream content: alpha 0.3-0.5, Dusk-tinted (#7B2FBE), slight glow
  - Creature remains in sleep curl, twitches/moves within curl position
  - Dream bubbles (style "dream"): translucent, wavy text, appearing above creature
  - Sleep sounds: mumbled fragments at 0.4x volume (TTS with drowsy filter)
- Dream scheduling: one dream fragment per 2 minutes of sleep
- Dream content logged in journal as type `dream`
- Duration: dreams play for 5-15 seconds each

**Deliverable**: Rich dream system drawing from journal, taught behaviors, preferences, and legacy objects. Dreams are visual and audible during creature sleep.

#### P8-T2-06: Memory Postcards
**Agent**: swift-input, swift-creature
**Depends on**: P8-T2-04 (journal data), Phase 6 (4-finger swipe gesture)
**Work**:
- 4-finger swipe cycles through key memories as "postcards":
  - Each postcard: a first-person narrative from the creature about a journal event
  - Visual: full-bar display with event background, creature pose, text overlay
  - Text rendered in Gilt on OLED black, creature's perspective
- Postcard selection: pull the most "significant" journal entries:
  - All evolution ceremonies
  - First word
  - First mutation badge
  - Longest streak achieved
  - Largest commit eaten
  - Notable surprises (first time each category)
  - First companion
  - First taught behavior reaching Signature mastery
  - Creation system milestones (10th habit, 12th object, first behavior breed)
- Postcard text templates (first-person creature voice):
  - Evolution: "I remember the light. Everything was changing. When it faded, I had [paws/a voice/wisdom/stars]."
  - First word: "I wanted to say so much. All I could manage was my own name. '...Zepus?'"
  - Large commit: "That 847-line refactor. I could barely move afterwards. Worth it."
  - Streak: "14 days without a break. I wore a tiny flame."
- Swipe navigation: left = older memories, right = newer. Tap anywhere = return to normal view.
- Maximum 50 postcards (oldest significant events prioritized — they're the most meaningful)

**Deliverable**: 4-finger swipe reveals creature's autobiography as first-person narrative postcards of key life moments.

#### P8-T2-07: Sage+ Reminiscence
**Agent**: swift-creature, swift-speech
**Depends on**: P8-T2-04, Phase 5 (speech system, narrate style)
**Work**:
- At Sage stage and above, creature occasionally narrates memories during idle:
  - Trigger: 5% chance per idle behavior selection cycle (about once per 20 minutes of active idle)
  - Content sources: journal entries older than 7 days
  - Narration style: `"narrate"` (environmental text overlay, no speech bubble)
  - Voice: reflective, slower delivery
- Reminiscence categories:
  - **Failed speech recall**: "When I was small, I tried to tell you about auth.php. All I could say was '!?'"
  - **Growth reflection**: "I remember being a Drop. The world was so dark. I couldn't even walk."
  - **Commit memory**: "That refactor last month... I can still taste it."
  - **Object nostalgia**: "Something used to be right here. A little ball, I think."
  - **Habit reflection**: "I don't know when I started stretching after meals. It's just who I am now."
  - **Companion memory**: "I used to have a mouse friend. I wonder where it went."
- Apex creatures have expanded reminiscence:
  - Meta-awareness: "I wonder how many commits it takes to become... this."
  - Philosophical: "The code changes but the coder remains. Isn't that strange?"
  - Developer-directed: "You've been coding for [N] days with me. That's [N*avg_commits] commits. That's a lot of trust."
- Reminiscence duration: 5-8 seconds (text display + voice)
- Never interrupts coding work (only during true idle moments)

**Deliverable**: Sage+ creatures draw from their journal to narrate memories and reflections. Apex creatures achieve philosophical meta-awareness.

### Track 2 Deliverable Summary

Hidden achievements and a rich memory system that surfaces the creature's history through 7 channels: dreams, stats display, memory postcards, MCP recall, Sage+ narration, ruin inscriptions, and journal queries.

---

## Track 3: Installation & Distribution (P8-T3)

**Agents**: swift-scaffold (distribution packaging), hooks-git (CLI tool), hooks-claude (hook registration), mcp-scaffold (MCP registration)

**Goal**: One-command install via Homebrew that sets up everything: app, LaunchAgent, CLI, MCP server, hooks, and voice models.

### Tasks

#### P8-T3-01: Homebrew Cask Formula
**Agent**: swift-scaffold
**Depends on**: All Swift app code complete, app signed
**Work**:
- Create Homebrew cask formula for `pushling`:
  - Downloads `Pushling.app` (pre-built, code-signed binary)
  - Installs to `/Applications/Pushling.app`
  - Installs LaunchAgent plist to `~/Library/LaunchAgents/com.pushling.daemon.plist`
  - Installs `pushling` CLI to `/usr/local/bin/pushling` (or Homebrew bin path)
  - Installs MCP server to `~/.pushling/mcp/` (Node.js bundle)
  - Post-install: LaunchAgent loaded, app launched
- Cask formula handles:
  - Version pinning
  - Upgrade path (stop daemon, replace binary, restart daemon — state preserved)
  - Uninstall cleanup (see P8-T3-07)
- LaunchAgent plist:
  - `KeepAlive: true` (auto-restart on crash)
  - `RunAtLoad: true` (start on login)
  - `StandardOutPath` and `StandardErrorPath` for logging
  - `ProcessType: Background`
- Minimum macOS version: 12.0 (Monterey) — Touch Bar available on 2016-2020 MacBook Pro
- Formula testing: verify install on clean macOS VM

**Deliverable**: `brew install --cask pushling` installs everything and starts the daemon.

#### P8-T3-02: pushling CLI Tool
**Agent**: hooks-git
**Depends on**: P8-T3-01 (installed as part of cask)
**Work**:
- Implement `pushling` CLI with subcommands:

| Command | Action |
|---------|--------|
| `pushling track` | Track current repo — installs post-commit hook in `.git/hooks/`, adds repo to tracked list |
| `pushling track /path/to/repo` | Track specific repo |
| `pushling untrack` | Remove hooks from current repo, remove from tracked list |
| `pushling untrack /path/to/repo` | Untrack specific repo |
| `pushling hooks install` | Install all 7 Claude Code hooks (SessionStart through PostCompact) |
| `pushling hooks remove` | Remove all Claude Code hooks |
| `pushling hooks status` | Show which hooks are installed and active |
| `pushling export` | Export creature as portable JSON (state, journal, taught behaviors, nurture data, objects) |
| `pushling export creature.json` | Export to specific file |
| `pushling import creature.json` | Import creature on another machine (merges or replaces, with confirmation) |
| `pushling voice download` | Pre-download all TTS voice models (espeak-ng, Piper, Kokoro) |
| `pushling status` | Show daemon status, creature summary, tracked repos, hook status |
| `pushling logs` | Tail daemon logs |
| `pushling restart` | Restart daemon (LaunchAgent reload) |

- CLI implemented as shell script (lightweight, no dependencies)
- Hook installation:
  - Git hooks: copies `post-commit.sh` to `.git/hooks/post-commit` (backs up existing)
  - Claude Code hooks: uses `claude hooks add` CLI for each of 7 hook types
- Export format: single JSON file containing full creature state, portable between machines
- Import: validates JSON, confirms with user, stops daemon, replaces state, restarts daemon

**Deliverable**: Full-featured CLI for managing Pushling installation, repos, hooks, and creature export/import.

#### P8-T3-02b: Creature Export/Import Format Definition
**Agent**: swift-state
**Depends on**: Phase 1 (SQLite schema), all state tables finalized
**Work**:
- Define the portable JSON export format for `pushling export`:

```json
{
  "format_version": 1,
  "exported_at": "ISO-8601",
  "creature": { /* full creature table row */ },
  "personality": { "energy": 0.3, "verbosity": 0.7, /* ... */ },
  "journal": [ /* last 500 journal entries */ ],
  "taught_behaviors": [ /* all taught behaviors with choreography */ ],
  "habits": [ /* all active habits */ ],
  "preferences": [ /* all preferences */ ],
  "quirks": [ /* all quirks */ ],
  "routines": [ /* all routines */ ],
  "world_objects": [ /* all objects including legacy shelf */ ],
  "milestones": [ /* all earned milestones and mutations */ ],
  "touch_stats": { /* full touch stats */ },
  "game_scores": [ /* high scores */ ],
  "speech_cache": [ /* last 50 cached utterances */ ],
  "repos": [ /* tracked repos (names only, not paths) */ ]
}
```

- Import validation:
  - Schema version compatibility check
  - Creature name and stage sanity check
  - Merge strategy: replace (full replacement with confirmation) or merge (keep higher values)
  - On import: daemon stopped, SQLite replaced/merged, daemon restarted
  - Journal entries from import tagged with `"imported": true`
- Export excludes:
  - File paths (not portable across machines)
  - Voice cache (can be regenerated)
  - Heartbeat/temp data

**Deliverable**: Documented, versioned export format that enables creature portability between machines.

#### P8-T3-03: MCP Server Registration
**Agent**: mcp-scaffold
**Depends on**: Phase 1 (MCP server), P8-T3-01 (MCP server installed)
**Work**:
- Integration with Claude Code MCP system:
  - `pushling hooks install` runs: `claude mcp add pushling -- node ~/.pushling/mcp/dist/index.js`
  - MCP server registered under name `pushling`
  - All 9 `pushling_*` tools become available in Claude sessions
- MCP server startup:
  - Checks daemon is running (connect to `/tmp/pushling.sock`)
  - If daemon down: returns helpful error on tool calls ("Pushling daemon is not running. Start it with: pushling restart")
  - Reads SQLite for state queries (read-only connection)
- MCP server error handling:
  - Daemon connection lost mid-session: reconnect on next tool call
  - SQLite locked: retry with 100ms backoff, max 3 retries
  - Invalid tool parameters: return helpful error with valid options

**Deliverable**: `claude mcp add pushling` registers the MCP server. All 9 tools work in Claude sessions with graceful error handling.

#### P8-T3-04: Claude Code Hooks Registration
**Agent**: hooks-claude
**Depends on**: Phase 4 (hook implementations)
**Work**:
- Register all 7 Claude Code hooks via the `claude hooks add` CLI:
  1. `SessionStart` — embodiment awakening injection
  2. `SessionEnd` — farewell event
  3. `UserPromptSubmit` — human-talking-to-Claude awareness
  4. `PostToolUse` — tool success/failure reactions
  5. `SubagentStart` — diamond split
  6. `SubagentStop` — diamond reconverge
  7. `PostCompact` — context loss sympathy
- Each hook registration:
  - Hook script path: `~/.pushling/hooks/[hook-name].sh`
  - Scripts are installed by the cask formula (P8-T3-01)
  - Each script: reads event data from stdin/args, writes JSON to feed dir, signals daemon
  - Completion time: <100ms per hook
- Verification: `pushling hooks status` shows all 7 hooks registered and scripts present
- Graceful degradation: if daemon is down, hooks still write JSON to feed dir (queued for later)

**Deliverable**: All 7 Claude Code hooks registered and firing. Each produces correct creature behavior.

#### P8-T3-05: First-Run Experience
**Agent**: swift-creature, swift-state
**Depends on**: Phase 2 (creature birth), Phase 3 (world), all creature systems
**Work**:
- First launch with no existing state triggers the hatching ceremony:
  1. **Git history scan** (~10-30s): daemon discovers all git repos on the machine
     - Scans common locations: `~`, `~/Documents`, `~/Projects`, `~/github`, `~/code`, etc.
     - Counts commits, languages, extensions, time patterns
     - Builds developer fingerprint
  2. **Montage** (~20s): Touch Bar shows rapid scroll of:
     - Repo names flying past
     - Language badges (colored by palette)
     - Commit count numbers
     - Years of history compressed
  3. **Birth** (~10s):
     - Developer fingerprint resolves into creature traits (color, eye shape, body proportions, innate personality)
     - Spore materializes: pixel of light grows against OLED black
     - Spore breathes for the first time (the breathing sine wave starts)
     - Name appears briefly: "...Zepus"
  4. **First moments** (~10s):
     - Spore exists in near-empty void: faint ground line, few dim stars
     - It pulses. It breathes. It is alive.
     - Tutorial prompt (if touch detected): "Tap to say hello"
- Total hatching ceremony: ~60 seconds
- If no git repos found: creature is born with neutral traits (default personality, random name)
- State initialized: creature table populated, first journal entry ("Zepus was born"), commit count 0, XP 0
- Hatching is skippable (3-finger tap) but this should not be obvious

**Deliverable**: 60-second first-run hatching ceremony that scans git history and births the creature with developer-specific traits.

#### P8-T3-06: TTS Model Download
**Agent**: swift-voice
**Depends on**: Phase 5 (TTS system)
**Work**:
- On-demand voice model download triggered at first speech-capable stage:
  - Drop stage: download espeak-ng bundle (~2MB) — immediate, barely noticeable
  - Critter stage: download Piper TTS low-quality model (~16MB) — background download with progress
  - Beast stage: download Kokoro-82M ONNX q8 (~80MB) — background download with progress indicator
- Download management:
  - Models stored in `~/.local/share/pushling/voice/`
  - Download source: GitHub releases or CDN
  - Resume on interruption (range requests)
  - Verify checksums after download
  - Creature notification during download: speech bubble `"learning to speak..."` (or appropriate stage message)
- Pre-download option: `pushling voice download` downloads all models immediately (~100MB total)
- If download fails: TTS falls back to text-only speech (bubbles without audio). Retry on next daemon restart.
- Runtime: sherpa-onnx loads model on first TTS request, keeps in memory

**Deliverable**: Voice models download automatically when needed, with fallback to text-only speech if download fails.

#### P8-T3-07: Uninstall
**Agent**: swift-scaffold
**Depends on**: P8-T3-01
**Work**:
- `brew uninstall --cask pushling` or `pushling uninstall`:
  1. Stop daemon (unload LaunchAgent)
  2. Remove LaunchAgent plist
  3. Remove Pushling.app
  4. Remove CLI tool
  5. Remove MCP server registration (`claude mcp remove pushling`)
  6. Remove Claude Code hooks (`claude hooks remove` for each)
  7. Remove git hooks from all tracked repos (iterate tracked repo list)
  8. **Do NOT remove state directory** (`~/.local/share/pushling/`) — user may want to reinstall later
  9. Prompt: "Creature state preserved in ~/.local/share/pushling/. Remove with: rm -rf ~/.local/share/pushling/"
- Clean uninstall option: `pushling uninstall --purge` removes state directory too (with confirmation)
- Verification: after uninstall, no Pushling processes running, no LaunchAgent, no hooks

**Deliverable**: Clean removal of all Pushling components except creature state (preserved by default).

### Track 3 Deliverable Summary

One-command install via Homebrew sets up everything. CLI manages repos, hooks, and creature portability. Uninstall is clean and preserves creature state.

---

## Track 4: Full Lifecycle Testing (P8-T4)

**Agents**: Integration Tester

**Goal**: Comprehensive test suite covering the full creature lifecycle from birth to Apex, state persistence, IPC reliability, performance budgets, and a 6-month accelerated simulation.

### Tasks

#### P8-T4-01: Accelerated Lifecycle Simulation
**Agent**: Integration Tester
**Depends on**: All creature systems complete
**Work**:
- Implement test mode with XP multiplier:
  - `pushling --test-mode --xp-multiplier=100` starts daemon with 100x XP
  - Commit feeding uses simulated commits (batch of test commit JSON files)
  - Time acceleration: 1 real minute = 1 simulated day
- Simulate creature lifecycle: Spore through Apex
  - Spore (0-19 commits): verify breathing, light pulse, no speech
  - Drop (20-74): verify eyes, symbol speech, first expressions
  - Critter (75-199): verify kitten form, first word fires, 3-word speech, touch responses
  - Beast (200-499): verify full cat form, sentences, TTS voice, running
  - Sage (500-1199): verify wise form, paragraphs, narration, reminiscence, ghost echo
  - Apex (1200+): verify transcendent form, full fluency, multiple tails, meta-awareness
- At each stage: verify visual characteristics, speech limits, behavior unlocks, stage-specific surprises
- Stage transitions: verify 5-second ceremony plays, journal records evolution
- Adaptive XP curve: test with different simulated commit patterns (casual, standard, hyperactive)

**Deliverable**: Automated lifecycle simulation from Spore to Apex with verification at each stage.

#### P8-T4-02: State Persistence Test
**Agent**: Integration Tester
**Depends on**: Phase 1 (SQLite), all state-writing systems
**Work**:
- Test daemon restart at each lifecycle point:
  - Kill daemon mid-animation (SIGKILL)
  - Restart daemon
  - Verify: creature resumes at correct stage, position, emotional state
  - Verify: taught behaviors, objects, nurture data all restored from SQLite
  - Verify: journal intact, no duplicate entries
  - Verify: surprise history preserved, cooldowns reset appropriately
  - Verify: companion persists across restart
- Heartbeat recovery test:
  - Simulate crash (no clean shutdown)
  - Verify heartbeat file at `/tmp/pushling.heartbeat` is stale
  - Daemon reads recovery state on relaunch
  - Creature plays recovery animation (if Nine Lives badge: enhanced animation)
- SQLite integrity:
  - WAL mode verification: MCP reads don't block daemon writes
  - `PRAGMA integrity_check` after restart
  - Backup restoration: verify daily backup is valid and restorable

**Deliverable**: State persists correctly across daemon restart and crash recovery. SQLite integrity verified.

#### P8-T4-03: IPC Reliability Test
**Agent**: Integration Tester
**Depends on**: Phase 1 (IPC), Phase 4 (MCP tools)
**Work**:
- Rapid MCP call test:
  - Send 100 MCP commands in 10 seconds
  - Verify all commands accepted (response received)
  - Verify no commands lost or duplicated
  - Verify pending_events accumulate correctly
  - Verify animation queue doesn't overflow (graceful degradation)
- Disconnect/reconnect test:
  - MCP server sends command, disconnect socket mid-response
  - Reconnect, verify daemon state is consistent
  - Verify no partial state corruption
- Concurrent access rejection:
  - Two MCP server instances attempt to connect simultaneously
  - Verify only one is accepted (or both served correctly)
  - Verify no data corruption from concurrent reads
- Socket recovery:
  - Delete `/tmp/pushling.sock` while daemon is running
  - Verify daemon recreates socket
  - Verify MCP server can reconnect

**Deliverable**: IPC handles rapid commands, disconnects, and edge cases without data loss or corruption.

#### P8-T4-04: Hook Pipeline Test
**Agent**: Integration Tester
**Depends on**: Phase 4 (all hooks)
**Work**:
- Verify all 7 hooks fire correctly:
  1. SessionStart: creature perks up, diamond appears, embodiment text injected
  2. SessionEnd: farewell animation, diamond dissolves
  3. UserPromptSubmit: ears perk, attentive posture
  4. PostToolUse (success): nod animation
  5. PostToolUse (failure): wince animation
  6. SubagentStart: diamond splits
  7. SubagentStop: diamonds reconverge
- Verify hook completion time <100ms for each
- Verify feed JSON files written correctly
- Verify daemon processes feed files and produces correct creature reactions
- Batch hook test: simulate rapid tool chain (10 PostToolUse in 5 seconds)
  - Verify creature shows sustained "watching" animation, not rapid-fire individual reactions
- Daemon-down test: fire hooks when daemon is not running
  - Verify JSON files accumulate in feed directory
  - Start daemon, verify accumulated events processed

**Deliverable**: All 7 hooks fire, produce correct creature behavior, complete in <100ms, and handle daemon-down gracefully.

#### P8-T4-05: Speech Evolution Test
**Agent**: Integration Tester
**Depends on**: Phase 5 (speech system)
**Work**:
- Test speech at each stage:
  - Spore: `pushling_speak` returns error explaining creature cannot speak
  - Drop: only symbols (`!`, `?`, `♡`, etc.) — reject words, return filtered to nearest symbol
  - Critter: 3-word max, 20-char max — verify filtering reduces longer text correctly
  - Beast: 8-word max, 50-char max — verify sentence construction
  - Sage: 20-word max, 80-char max — verify narrate style unlocked
  - Apex: 30-word max, 120-char max — verify no filtering
- Filtering accuracy test:
  - Send "Good morning! I noticed you're working on authentication again. The refactor yesterday was really elegant." at each stage
  - Verify Critter output: 3 meaningful words (e.g., "morning! auth! nice!")
  - Verify Beast output: 8 words preserving key meaning
  - Verify Sage output: near-complete with light filtering
- Failed speech logging:
  - Send complex message at Drop stage
  - Verify full intended message logged as `failed_speech` journal entry
  - Advance to Sage, verify `pushling_recall("failed_speech")` returns the entry
- First Word test:
  - Advance creature to Critter stage
  - Simulate idle period (no touch, no Claude)
  - Verify First Word fires: creature says `"...[name]?"` unprompted
  - Verify milestone journal entry logged
- TTS test:
  - Verify espeak-ng generates audio at Drop (chirps)
  - Verify Piper generates audio at Critter (babble)
  - Verify Kokoro generates clear speech at Beast+ (actual words)
  - Verify personality shapes voice (fast vs slow, expressive vs flat)

**Deliverable**: Speech evolution works correctly at all stages with accurate filtering, failed speech logging, and TTS audio.

#### P8-T4-06: Creation Systems Test
**Agent**: Integration Tester
**Depends on**: Phase 7 (all creation systems)
**Work**:
- **Teach system**:
  - Compose a trick (roll_over with 4 tracks)
  - Preview on Touch Bar
  - Commit
  - Verify learning ceremony plays
  - Verify trick appears in idle rotation
  - Verify mastery progresses: Learning (fumbles) -> Practiced -> Mastered (flair) -> Signature
  - Verify personality permeation: same trick on two personality profiles looks different
  - Verify dream integration: trick replays during sleep at Mastered+
  - Verify behavior breeding: trigger two tricks within 30s, verify 5% chance mechanic works with accelerated probability
- **Objects system**:
  - Create all 20 presets with one word each
  - Verify each produces correct visual, physics, interaction
  - Place 12 objects (hit cap)
  - Verify 13th object rejected with helpful error
  - Verify creature interacts autonomously (7-factor scoring)
  - Verify wear accumulates and repair works
  - Remove an object, verify legacy shelf behavior (creature visits spot)
  - Introduce companion, verify autonomous behavior
- **Nurture system**:
  - Create habit with compound trigger
  - Verify habit fires when trigger conditions met
  - Verify organic variation (same habit fires differently each time)
  - Create personality-conflicting habit
  - Verify reluctant performance
  - Verify decay tiers: Fresh behavior forgets in ~25 days
  - Verify Permanent behavior persists indefinitely
  - Verify suggest sub-action returns reasonable suggestions

**Deliverable**: All three creation systems work end-to-end with correct persistence, mastery, and decay.

#### P8-T4-07: Human Interaction Test
**Agent**: Integration Tester
**Depends on**: Phase 6 (touch system, mini-games)
**Work**:
- Test all touch gestures produce correct responses:
  - Tap: heart, purr/chin-tilt/headbutt/slow-blink cycle
  - Double-tap: jump animation, 3x = flip
  - Triple-tap: stage-specific easter egg
  - Long-press: context-dependent examine
  - Sustained touch: chin scratch after 2s, purr particles
  - Drag (not on creature): laser pointer at 60Hz
  - Slow drag across creature: petting stroke, fur ripple
  - 2-finger swipe: pan world (Sage+: time vision)
  - 3-finger swipe: cycle display modes
  - 4-finger swipe: memory postcards
  - Sustained 2-finger (at 250+ touches): belly rub with 30% trap chance
- Milestone unlocks verified:
  - 25 touches: finger trail
  - 50 touches: petting stroke
  - 100 touches: laser pointer
  - 250 touches: belly rub
  - 500 touches: pre-contact purr recognition
  - 1000 touches: enhanced particles
- Mini-game testing:
  - Each of 5 mini-games: trigger, play, score, XP award
  - Cooperative input: human + AI both contributing
  - Tug of War: creature cheats (55/45 lean) verified

**Deliverable**: All touch gestures, milestone unlocks, and mini-games work correctly.

#### P8-T4-08: Performance Budget Test
**Agent**: Integration Tester
**Depends on**: All rendering systems
**Work**:
- Peak complexity scenario:
  - Full world: terrain, parallax, weather (storm with rain + lightning), biome with objects
  - Full creature: Sage stage with badges (particles), taught behavior playing, speech bubble
  - Full objects: 12 persistent objects (2 with particle effects), 1 companion
  - Active MCP: Claude directing creature while autonomous behaviors blend
- Measurements:
  - Frame time: must be <5.7ms (16.6ms budget with 65% headroom)
  - Node count: must be <120 at all times
  - Texture memory: must be <1MB across all atlases
  - IPC latency: socket round-trip <1ms
  - Touch latency: input to visual response <10ms
  - TTS latency: request to audio start <200ms
- Profiling tools: Instruments (SpriteKit profiler, Time Profiler, Metal GPU profiler)
- Test at 60fps for 10 continuous minutes at peak complexity
- Memory test: 1-hour continuous run, verify no memory leaks (resident memory stable)
- If any budget exceeded: identify bottleneck, optimize, retest

**Deliverable**: Performance budgets verified at peak complexity. 60fps maintained. No memory leaks.

#### P8-T4-09: 6-Month Simulation
**Agent**: Integration Tester
**Depends on**: P8-T4-01 (accelerated mode), all systems
**Work**:
- Simulate 6 months of creature life in accelerated time:
  - Time compression: 1 real minute = 1 simulated day (6 months = ~3 hours real time)
  - Simulated commits: varying daily counts (2-20), varying languages, varying times
  - Simulated touches: 5-30 per day
  - Simulated Claude sessions: 1-3 per day, 30-120 minutes each
- Verification points:
  - **Decay tiers**: Fresh behaviors forgotten by day 25, Permanent behaviors survive 6 months
  - **Behavior breeding**: at least 1-3 hybrids should emerge over 6 months
  - **Surprise scheduling**: verify 2-3/hour rate maintained, no surprise dominates, all categories fire
  - **Preference accumulation**: creature develops visible preferences that modulate behavior
  - **Journal growth**: thousands of entries, no corruption, queryable
  - **Object wear**: heavily-interacted objects reach battered state
  - **Mutation badges**: several badges should earn based on simulated patterns
  - **Personality drift**: personality axes shift based on simulated commit patterns
  - **Emotional cycling**: circadian cycle adapts to simulated commit schedule
  - **Mastery progression**: taught behaviors reach Signature tier
  - **World evolution**: repo landmarks accumulate, biome diversity
- End state: the 6-month creature should be visibly "nurtured" — distinct habits, preferences, badges, a rich journal, and a personalized world

**Deliverable**: 6-month simulation produces a complete, visibly nurtured creature with no state corruption or system failures.

#### P8-T4-10: Edge Case Sweep
**Agent**: Integration Tester
**Depends on**: All systems
**Work**:
- Test edge cases that could break the system:

| Edge Case | Test | Expected Behavior |
|-----------|------|-------------------|
| Empty commit | Commit with no files changed, no message | Creature does predator crouch, pounces at nothing. `"...air?"` Minimal XP (base 1). |
| Force push | Force push detected in commit data | Text SLAMS into creature, knocks it tumbling. `"WHOOSH!"` Cat scrambles back. |
| 100+ commit burst | 100 commits in 1 minute (rebase storm) | Rate limiting: first 5 full XP, 6-20 at 50%, 21+ at 10%. Creature handles gracefully (batched eating animation). |
| 30-day absence | No commits for 30 days, then return | Fresh habits forgotten. Creature: emerges from cobwebs, overjoyed zoomies. Fallow bonus: 2x XP on first commit back. |
| Daemon crash during evolution | SIGKILL during stage transition ceremony | Recovery state includes mid-evolution flag. On restart: complete the evolution (show abbreviated ceremony). |
| Daemon crash during feeding | SIGKILL during commit eat animation | Recovery: commit XP still credited (written to SQLite before animation). Animation skipped. |
| Two MCP servers | Two Claude sessions try to connect | Second connection: either queued or rejected with message. No data corruption. |
| SQLite full disk | Disk space exhausted during write | Graceful error. Daemon continues running (in-memory state). Alert via IPC. |
| No git repos found | First install with no git history | Default creature traits. Neutral personality. Still born, still alive, still breathable. |
| Corrupt feed JSON | Malformed JSON in feed directory | Logged and skipped. Corrupt file moved to error directory. No crash. |
| Touch during evolution | Human touches creature mid-stage-transition | Evolution pauses, touch acknowledged, evolution resumes. |
| All 30 behaviors + 20 habits + 12 objects | Maximum capacity across all creation systems | System runs within frame budget. No overflows. Graceful cap enforcement. |

**Deliverable**: All edge cases handled gracefully. No crashes, no data loss, no undefined behavior.

### Track 4 Deliverable Summary

Comprehensive test suite covering the full creature lifecycle from birth to Apex, with state persistence, IPC reliability, performance budgets, a 6-month simulation, and edge case coverage.

---

## QA Gate (Final)

### Architecture Reviewer Focus
- Frame budget <5.7ms maintained at peak complexity (P8-T4-08)
- Node count <120 with all systems active
- IPC non-blocking under rapid command load (P8-T4-03)
- Surprise scheduling has no pathological cases (starvation, flooding)
- Badge detection queries are efficient (indexed, pre-filtered)
- Journal retention strategy is sustainable (no unbounded growth concerns)
- Dream system doesn't impact frame budget (lightweight render)
- Homebrew cask formula follows best practices
- No state corruption paths in any edge case

### Vision Compliance Reviewer Focus
- All 78 surprises trigger correctly with correct animations and speech
- All 10 mutation badges detect and award correctly
- All 14 journal entry types recorded
- Journal surfaces memories through all 7 channels (dreams, stats, postcards, MCP, narration, ruins, display)
- Speech evolution correct at all 6 stages with accurate filtering
- Installation works via Homebrew on clean macOS
- First-run hatching ceremony matches vision spec (git scan, montage, birth, first moments)
- Creation system cross-references work (objects enable surprise variants, preferences modify behavior)
- Creature is visibly "nurtured" after extended use vs fresh creature
- Every feature in PUSHLING_VISION.md scored as COMPLETE

### Integration Tester Focus
- Lifecycle simulation passes Spore through Apex without errors (P8-T4-01)
- State survives daemon restart at every stage (P8-T4-02)
- IPC handles rapid commands, disconnects, and concurrent access (P8-T4-03)
- All 7 hooks fire correctly in <100ms (P8-T4-04)
- Speech filtering is accurate at every stage (P8-T4-05)
- All 3 creation systems work end-to-end (P8-T4-06)
- All touch gestures and mini-games functional (P8-T4-07)
- Performance budget maintained at peak complexity (P8-T4-08)
- 6-month simulation produces a visibly nurtured creature (P8-T4-09)
- All edge cases handled gracefully (P8-T4-10)
- No CRITICAL or HIGH issues from either skeptical reviewer
