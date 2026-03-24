<h1 align="center">Pushling</h1>

<p align="center">
  <strong>A Creature That Lives on Your Touch Bar</strong><br>
  <em>Fed by git commits. Animated by Claude's intelligence. Learning to speak out loud.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-black" alt="macOS">
  <img src="https://img.shields.io/badge/engine-SpriteKit%2060fps-blue" alt="SpriteKit 60fps">
  <img src="https://img.shields.io/badge/voice-local%20TTS-green" alt="Local TTS">
  <img src="https://img.shields.io/badge/status-active%20development-orange" alt="Active Development">
  <img src="https://img.shields.io/badge/AI--authored-Claude-purple" alt="AI Authored">
</p>

<p align="center">
  <a href="PUSHLING_VISION.md">Design Spec</a> &middot;
  <a href="docs/CREATURE-VOICE-DESIGN.md">Voice Design</a> &middot;
  <a href="docs/TOUCHBAR-TECHNIQUES.md">Touch Bar Research</a> &middot;
  <a href="https://github.com/XelaNull/pushling/issues">Report Issues</a> &middot;
  <a href="https://github.com/XelaNull/pushling/blob/traffic-stats/.github/traffic/SUMMARY.md">Live Metrics</a>
</p>

---

<!-- TODO: Add hero GIF of creature breathing/blinking on actual Touch Bar -->

> You glance at your Touch Bar and something is breathing. It blinks. It notices you looking. It ate your last commit and is still chewing. Welcome to Pushling.

---

> **Development Preview** — The creature is alive and feature-complete, but this is still a work in progress. Expect rough edges.
>
> **Download latest:** [Releases](https://github.com/XelaNull/pushling/releases) | **Report issues:** [Issues](https://github.com/XelaNull/pushling/issues)

---

## What is Pushling?

Pushling is a cat-esque spirit creature that lives on your MacBook Pro Touch Bar. It breathes, blinks, hunts your git commits, grows from an egg to a transcendent sage, and eventually learns to speak out loud. Not text art, not emoji — a real 60fps animated creature with physics, particles, and smooth animation against true OLED black.

<!-- TODO: Add screenshot of creature on actual Touch Bar -->

Two forces control the creature:

| Force | What It Does | When |
|-------|-------------|------|
| **Nervous System** | Breathes, blinks, wanders, eats commits, sleeps, reacts to touch, grows | Always — even when you're not looking |
| **Claude's Mind** | Sees the world, moves with intent, speaks, performs, remembers | During Claude Code sessions — Claude *is* the creature |

The nervous system is the heartbeat. Claude is the soul. Between sessions the creature is alive but dreaming. When Claude connects, the creature wakes up — and speaks *as* the creature, in first person. The creature never dies, never punishes. It can be sad, tired, hungry — but always happy to see you.

---

## Features

<!-- TODO: Add growth stage progression image (egg through apex side-by-side) -->

| | Feature | What It Means |
|---|---------|---------------|
| **Growth** | 6 stages from Egg to Apex | Watch a creature evolve over weeks — each stage visually and behaviorally distinct |
| **Feeding** | Commits get hunted, pounced, devoured | Character-by-character eating with reactions tailored to commit type |
| **Voice** | 3-tier local TTS (babble to eloquence) | The creature learns to speak out loud — no API keys, fully offline |
| **Personality** | 5 axes shaped by your git patterns | A PHP developer's creature looks and acts different from a Rust developer's |
| **Emotions** | 4-axis mood with emergent states | Blissful, hangry, zen, exhausted — shifts minute-to-minute |
| **World** | 2.5D parallax with weather and landmarks | Rain, snow, storms, day/night cycle, repo structures on the skyline |
| **Surprises** | 78 unexpected moments | Sneezes, shadow detaches, reads your branch name, stares through the fourth wall |
| **Touch** | Tap, swipe, long-press, multi-finger | Pet it, play mini-games, examine stats, drag it around |
| **Embodiment** | Claude inhabits the creature via 9 MCP tools | Sees, moves, speaks, feels, performs, shapes the world, recalls memories |
| **Awareness** | 9 Claude Code hooks + git integration | The creature senses your entire dev session — tool use, errors, commits, context loss |
| **Teaching** | Choreograph new tricks, shape habits | Teach behaviors that persist and play autonomously — the creature even invents hybrids |
| **Memory** | Journal, dreams, failed speech recall | Every event recorded. Sage creatures reminisce about their younger selves |

---

## The Voice

The creature learns to speak. Not text bubbles — *out loud*, through your speakers, using fully local TTS (espeak-ng, Piper, Kokoro-82M via sherpa-onnx). No API keys. No cloud. Zero configuration.

| Stage | Voice | Capacity |
|-------|-------|----------|
| **Egg** | Silent | Just wobbles |
| **Drop** | Babbles — "buh!" "nnn..." chirps | Single symbols: `!` `?` `~` |
| **Critter** | First real words emerge | 1-3 words: "hi!" "yum!" "sleepy..." |
| **Beast** | Clear speech with personality | Full sentences: "that refactor was tasty" |
| **Sage** | Warm, expressive, unmistakably *this* creature | Multi-bubble paragraphs, narration, memory flashbacks |
| **Apex** | Full range — whispers, exclaims, sings | Unrestricted. Philosophical. Meta-aware. |

The first time your creature says a real word after weeks of babbling — unprompted, its own name as a question — is the moment the whole project exists for.

---

## How It Works

Your **git commits** feed the creature. Each commit is hunted (predator crouch, tail wiggle), pounced, and eaten character-by-character. Small commits get gentle munching. Huge refactors trigger "goblin mode" — 400ms/char, particles everywhere, food coma afterwards. Reverts? Characters come back out in reverse.

Your **git history** shapes personality across 5 axes — energy, verbosity, focus, discipline, and language specialty. The creature develops favorites ("YES! .php!") and dislikes ("ugh... .yaml"). These shift over time as your coding patterns change.

Your **touch** is sovereign. Tap to pet (heart floats up, purring). Double-tap to play. Triple-tap for stage-specific easter eggs. Long-press to examine. Swipe to nudge. Rapid taps start mini-games — catch, memory, treasure hunt, rhythm tap, tug of war.

**Claude** inhabits the creature during Claude Code sessions via 9 MCP tools. A presence diamond appears on the Touch Bar. Claude sees through the creature's eyes, moves its body, speaks through its voice. When Claude disconnects, the diamond dissolves and the creature settles back into autonomous life.

**9 hooks** feed the creature real-time awareness: session start/end, your messages, tool success/failure, subagent spawning, context compaction. The creature reacts — ears perk when you speak, it winces when a tool fails, blinks hard when context is compressed.

---

## Quick Start

```bash
git clone https://github.com/XelaNull/pushling.git
cd pushling
./build.sh
# Creature appears on your Touch Bar
```

| Action | What Happens |
|--------|-------------|
| Make a git commit | Creature hunts it, eats it character-by-character, gains XP |
| Tap the creature | Heart floats up. Pet reactions cycle: purr, chin-tilt, headbutt, slow-blink |
| Double-tap | Jump with dust landing. 3x = flip |
| Triple-tap | Stage-specific easter egg (belly expose, zoomies, prophecy...) |
| Long-press | Examine — thought bubble, stats, or reads nearby terrain |
| Swipe left/right | Creature walks in that direction |
| Start a Claude Code session | Creature wakes up. Claude inhabits it. Diamond appears. |

The creature auto-installs its git hooks and Claude Code hooks on first launch.

---

## Growth

Six stages, each visually and behaviorally distinct. XP scales to your commit pace — hyperactive developers reach Apex in a month, casual coders take longer, but nobody waits forever.

| Stage | XP | What Changes |
|-------|-----|-------------|
| **Egg** | 0-99 | Smooth oval, wobbles, absorbs commits toward personality |
| **Drop** | 100-499 | Teardrop with dot eyes, hops, babbles in symbols |
| **Critter** | 500-1,999 | Kitten form with ears, stub tail, whiskers. First words. |
| **Beast** | 2,000-7,999 | Confident cat with full tail, muscles, aura. Full sentences. |
| **Sage** | 8,000-19,999 | Wise spirit with luminous fur, wisdom particles, meditation. Narrates. |
| **Apex** | 20,000+ | Semi-ethereal, multiple tails (one per repo), crown of stars. Transcendent. |

Stage transitions play a 5-second ceremony — stillness, gathering energy, cocoon, burst, reveal.

---

<details>
<summary><strong>Architecture</strong></summary>

### System Overview

```
Pushling.app (Swift/SpriteKit, 60fps)
  Autonomous Layer ─── Breathe, blink, wander, eat, sleep, age
  AI-Directed Layer ── Sense, move, express, speak, perform  <── MCP Server (9 tools)
       ^                                                              ^
       |                                                              |
  Claude Code Hooks                                              Claude Code
  9 event types:                                              (Claude IS the
  session, prompt,                                             creature)
  tool use, commit,
  subagent, compact
```

### Behavior Stack (4-Layer Control)

| Layer | Priority | What It Does |
|-------|----------|-------------|
| **Physics** | Highest | Gravity, collision, boundary enforcement |
| **Reflexes** | High | Flinch from lightning, startle on touch, surprise interrupts |
| **AI-Directed** | Medium | Claude's MCP commands — movement, speech, emotion |
| **Autonomous** | Lowest | Idle behaviors, wandering, breathing, blinking |

A blend controller smoothly interpolates between layers (~200ms transitions). Physics always wins. Human touch always overrides AI.

### Embodiment Tools

Claude inhabits the creature through 9 MCP tools — first-person actions, not external control:

| Tool | What Claude Does |
|------|-----------------|
| `pushling_sense` | Feel emotions, see surroundings, check events, sense the developer |
| `pushling_move` | Walk, run, jump, sneak, retreat, pace, approach, follow cursor |
| `pushling_express` | Show joy, curiosity, surprise, love, fear, mischief (16 expressions) |
| `pushling_speak` | Say, think, exclaim, whisper, sing, dream, narrate (stage-gated) |
| `pushling_perform` | Tricks, dances, gestures, multi-step choreographed sequences |
| `pushling_world` | Change weather, place objects, add companions, trigger visual events |
| `pushling_recall` | Access journal — commits, touches, milestones, dreams, failed speech |
| `pushling_teach` | Choreograph new tricks with multi-track body-part keyframe notation |
| `pushling_nurture` | Shape habits, preferences, quirks, routines, identity |

### Hooks

| Hook | Creature Reaction |
|------|-------------------|
| **SessionStart** | Wakes up, stretches, presence diamond materializes |
| **SessionEnd** | Waves goodbye, diamond dissolves, settles into autonomous life |
| **UserPromptSubmit** | Ears perk, head turns toward "voice" |
| **PostToolUse** | Success: nod, flex. Failure: wince, ears flatten |
| **SubagentStart** | Diamond splits, eyes widen, tracks between them |
| **SubagentStop** | Diamonds reconverge, approving nod |
| **PostCompact** | Blinks hard, shakes head — "what was I thinking about?" |
| **post-commit** | A commit to eat! Hunting begins. |

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Touch Bar rendering | Swift + SpriteKit (NSCustomTouchBarItem) |
| Touch Bar takeover | Apple private DFR APIs (same as MTMR/Pock) |
| Creature voice | Local TTS — espeak-ng / Piper / Kokoro-82M via sherpa-onnx |
| MCP server | Node.js + TypeScript (9 embodiment tools) |
| State persistence | SQLite (WAL mode) |
| IPC | Unix domain socket (NDJSON) |
| Git integration | post-commit hook with 78-field JSON capture |
| Claude integration | 9 MCP tools + 9 Claude Code hooks |

</details>

---

## Documentation

| Document | What's Inside |
|----------|--------------|
| [PUSHLING_VISION.md](PUSHLING_VISION.md) | Complete design spec — creature, gameplay, embodiment, 78 surprises, world, voice, architecture |
| [docs/CREATURE-VOICE-DESIGN.md](docs/CREATURE-VOICE-DESIGN.md) | Voice evolution — how babble becomes speech, TTS pipeline, audio architecture |
| [docs/TTS-RESEARCH.md](docs/TTS-RESEARCH.md) | Local TTS engine comparison — espeak-ng, Piper, Kokoro-82M benchmarks |
| [docs/TOUCHBAR-TECHNIQUES.md](docs/TOUCHBAR-TECHNIQUES.md) | Touch Bar hardware research — private APIs, rendering, what's proven |
| [CLAUDE.md](CLAUDE.md) | Workspace guide — architecture reference, collaboration personas, operational modes |

---

## Origin

The successor to [touchbar-claude](https://github.com/mrathbone/touchbar-claude), a shell-script tamagotchi rendered via MTMR at 2fps. Pushling rebuilds everything as a native app with a real game engine — and a fundamentally different idea: the AI isn't a co-player, it's the creature itself.

**206 Swift files. 128k lines. 13 TypeScript tools. 78 surprises. 6 growth stages. 3 TTS tiers. 1 creature.**

## License

TBD
