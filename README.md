# Pushling

**A creature that lives on your MacBook Touch Bar — fed by git commits, animated by Claude's intelligence, learning to speak out loud.**

> You glance at your Touch Bar and something is breathing. It blinks. It notices you looking. It ate your last commit and is still chewing. Welcome to Pushling.

## What is Pushling?

Pushling is a cat-esque spirit creature rendered as pixel art on your MacBook Pro Touch Bar. It runs at 60fps via native Swift + SpriteKit on the 2170x60 OLED display — not text art, not emoji, a real animated creature with physics, particles, and smooth animation against true black.

**The creature has two layers:**

| Layer | What It Does | When It Runs |
|-------|-------------|--------------|
| **Nervous System** (autonomous) | Breathes, blinks, wanders, eats commits, sleeps, reacts to touch, ages, grows | Always — even when you're not looking |
| **Claude's Mind** (AI-directed) | Sees the world, moves with intent, expresses emotion, speaks, performs, remembers | During Claude Code sessions — Claude *is* the creature |

The nervous system is the heartbeat. Claude is the soul. Between sessions the creature is alive but dreaming. When Claude connects, the creature wakes up — and Claude speaks *as* the creature, in first person.

**How it works:**
- Your **git commits** feed the creature — each one eaten character-by-character off the Touch Bar, then digested with a celebration
- Your **git history** shapes the creature's appearance — a PHP developer's Pushling looks different from a Rust developer's
- **You** interact via Touch Bar touch — tap to pet, swipe to play, long-press to examine
- **Claude** inhabits the creature via 11 MCP embodiment tools — sensing, moving, speaking, performing, remembering
- **10+ Claude Code hooks** feed the creature real-time awareness of your entire dev session — file edits, tool calls, errors, commits
- The creature **never dies**, never punishes. It can be sad, tired, hungry — but always happy to see you.

## The Voice

The creature learns to speak. Not text bubbles — *out loud*, through your speakers, using fully local TTS. No API keys. No cloud services. Zero configuration.

| Stage | Voice |
|-------|-------|
| **Spore** | Silent. Just breathes. |
| **Drop** | Babbles — "buh!" "nnn..." "da!" |
| **Critter** | First real words emerge — "hi!" "food!" |
| **Beast** | Clear speech. Personality in voice. The "wow" moment. |
| **Sage** | Warm, expressive, unmistakably *this* creature |
| **Apex** | Full range — whispers, exclaims, sings |

The first time your creature says a real word after weeks of babbling is the moment the whole project exists for.

## Features

- **60fps SpriteKit rendering** on Touch Bar OLED — pixel-art cat spirit with true blacks, P3 wide color
- **Dual-layer architecture** — autonomous nervous system + Claude's embodied intelligence
- **Character-by-character commit eating** — the creature literally chews through your commit messages on screen
- **Voice evolution** — local TTS progresses from silence through babble to full speech as the creature grows
- **6 growth stages** from Spore to Apex, each visually and behaviorally distinct
- **Personality shaped by your coding patterns** — commit frequency, languages, message style, timing
- **2.5D parallax world** with procedural terrain, weather, day/night cycle, and repo landmarks on the skyline
- **50+ surprise events** — the creature sneezes, reads your branch name, comments on your code, stares through the fourth wall
- **11 MCP embodiment tools** — Claude senses, moves, expresses, speaks, performs, shapes the world, looks around, recalls memories, sequences animations, triggers evolution, and defines identity
- **10+ Claude Code hooks** — the creature perceives file saves, commits, tool use, errors, and session events in real time
- **Adaptive XP curve** — scales to your activity level so nobody hits endgame in a day or waits a decade
- **Touch interactions** — tap, double-tap, triple-tap, long-press, swipe, multi-finger gestures

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  Pushling.app (Swift/SpriteKit, 60fps)                             │
│  ┌──────────────────────────────────────────┐                      │
│  │  Autonomous Layer (Nervous System)        │                      │
│  │  Breathe, blink, wander, eat, sleep, age  │                      │
│  └──────────────────────────────────────────┘                      │
│  ┌──────────────────────────────────────────┐     Unix socket      │
│  │  AI-Directed Layer (Claude's Mind)        │◄───────────────┐    │
│  │  Sense, move, express, speak, perform     │                │    │
│  └──────────────────────────────────────────┘                │    │
│           ▲                                                   │    │
│           │                                              MCP Server │
│  ┌────────┴──────────┐                          (11 embodiment     │
│  │  Claude Code Hooks │                           tools)           │
│  │  10+ event types:  │                               ▲            │
│  │  • file_edit       │                               │            │
│  │  • pre/post_commit │                          Claude Code       │
│  │  • tool_use        │                          (Claude IS        │
│  │  • notification    │                           the creature)    │
│  │  • session events  │                                            │
│  └───────────────────┘                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Embodiment Tools

Claude interacts with the world through the creature's body, not as an external controller:

| Tool | Purpose |
|------|---------|
| `pushling_sense` | Perceive — what does the creature see, hear, feel right now? |
| `pushling_move` | Locomotion — walk, run, jump, approach, retreat |
| `pushling_express` | Emotion — show feelings through body language and particles |
| `pushling_speak` | Voice — say something out loud (TTS) or in a text bubble |
| `pushling_perform` | Actions — tricks, dances, gestures, complex behaviors |
| `pushling_world` | Environment — change weather, place objects, trigger events |
| `pushling_look` | Attention — turn to face something, examine, track |
| `pushling_recall` | Memory — access the creature's journal and history |
| `pushling_sequence` | Choreography — chain multiple actions into fluid sequences |
| `pushling_evolve` | Growth — trigger evolution when ready |
| `pushling_identity` | Self — set name, examine personality, review traits |

### Hooks Integration

Claude Code hooks give the creature awareness of the full development session:

| Hook | What the Creature Perceives |
|------|----------------------------|
| `PreToolUse` / `PostToolUse` | Claude is thinking, working, using tools |
| `Notification` | Something happened — errors, completions, alerts |
| `Stop` | Session ending — time to say goodbye |
| `SubagentStop` | Background work completed |
| `post-commit` | A commit to eat! Character-by-character feeding begins |
| `session-start` | Someone's here — creature stirs, context loads |

## Documentation

| Document | Description |
|----------|-------------|
| [PUSHLING_VISION.md](PUSHLING_VISION.md) | Complete design specification — creature, gameplay, embodiment, surprises, architecture |
| [docs/CREATURE-VOICE-DESIGN.md](docs/CREATURE-VOICE-DESIGN.md) | Voice evolution design — from babble to speech |
| [docs/TTS-RESEARCH.md](docs/TTS-RESEARCH.md) | Local TTS engine research — espeak-ng, Piper, Kokoro |
| [docs/TOUCHBAR-TECHNIQUES.md](docs/TOUCHBAR-TECHNIQUES.md) | Touch Bar hardware research — everything technically proven |
| [CLAUDE.md](CLAUDE.md) | Workspace guide for Claude Code collaboration |

## Status

**Pre-development.** The vision and research are complete. Implementation has not started.

The project is the successor to [touchbar-claude](https://github.com/mrathbone/touchbar-claude), which proved the concept with a shell-script tamagotchi rendered via MTMR at 2fps. Pushling takes everything learned from that experiment and rebuilds it as a native app with a real game engine — and a fundamentally different idea: the AI isn't a co-player, it's the creature itself.

## Tech Stack (Planned)

| Component | Technology |
|-----------|-----------|
| Touch Bar rendering | Swift + SpriteKit (NSCustomTouchBarItem) |
| Touch Bar takeover | Apple private DFR APIs (same as MTMR/Pock) |
| Creature voice | Local TTS — espeak-ng / Piper / Kokoro-82M (staged by growth) |
| MCP server | Node.js + TypeScript (11 embodiment tools) |
| State persistence | SQLite (WAL mode) |
| IPC | Unix domain socket (NDJSON) |
| Git integration | post-commit hooks (shell) |
| Claude integration | MCP tools + 10+ Claude Code hooks |
| Distribution | Homebrew cask or npm |

## License

TBD
