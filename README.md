# Pushling

**A virtual pet that lives on your MacBook Touch Bar, fed by git commits, played by human and AI together.**

> You glance at your Touch Bar and something is breathing. It blinks. It notices you looking. It ate your last commit and is still chewing. Welcome to Pushling.

## What is Pushling?

Pushling is a coding companion creature that lives on the MacBook Pro Touch Bar. It's rendered at 60fps via native Swift + SpriteKit on the 2170x60 OLED display — not text art, not emoji, a real animated creature with physics, particles, and smooth animation.

**How it works:**
- Your **git commits** feed the creature. Each commit is food — the creature eats it, celebrates, and grows.
- Your **git history** shapes the creature's appearance. A PHP developer's Pushling looks different from a Rust developer's.
- **You** interact via Touch Bar touch — tap to pet, swipe to play, long-press to examine.
- **Claude Code (AI)** interacts via MCP tools — talking, teaching tricks, giving gifts, changing the weather.
- The creature **never dies**, never punishes. It can be sad, tired, hungry — but always happy to see you.

## Features

- **60fps SpriteKit rendering** on the Touch Bar OLED with true blacks, P3 wide color
- **6 growth stages** from Spore to Apex, each visually and behaviorally distinct
- **Personality shaped by your coding patterns** — commit frequency, languages, message style, timing
- **2.5D parallax world** with procedural terrain, weather, day/night cycle, and repo landmarks on the skyline
- **30 surprise events** that delight you mid-coding — the creature sneezes, reads your branch name, stares at you through the fourth wall
- **Dual-player model** — human touches the Touch Bar, AI uses MCP tools. Both are caretakers.
- **Adaptive XP curve** — scales to your activity level so nobody hits endgame in a day or waits a decade
- **Claude Code integration** — SessionStart hook teaches Claude about the creature automatically. Claude can greet it, teach it tricks, give it gifts, change the weather.

## Architecture

```
Pushling.app (Swift/SpriteKit, 60fps)  <--Unix socket-->  MCP Server (Node.js)  <--stdio-->  Claude Code
       ^                                                          ^
       |                                                          |
  Git post-commit hook                                    SessionStart hook
  (feeds commit data)                                  (injects creature context)
```

## Documentation

| Document | Description |
|----------|-------------|
| [PUSHLING_VISION.md](PUSHLING_VISION.md) | Complete design specification — creature, gameplay, MCP tools, surprises, architecture |
| [docs/TOUCHBAR-TECHNIQUES.md](docs/TOUCHBAR-TECHNIQUES.md) | Master research repository — everything possible on the Touch Bar (hardware, software, rendering, performance) |
| [CLAUDE.md](CLAUDE.md) | Workspace guide for Claude Code collaboration |

## Status

**Pre-development.** The vision document is complete. Implementation has not started.

The project is the successor to [touchbar-claude](https://github.com/mrathbone/touchbar-claude), which proved the concept with a shell-script tamagotchi rendered via MTMR at 2fps. Pushling takes everything learned from that experiment and rebuilds it properly — native rendering, real game engine, AI co-player.

## Tech Stack (Planned)

| Component | Technology |
|-----------|-----------|
| Touch Bar rendering | Swift + SpriteKit (NSCustomTouchBarItem) |
| Touch Bar takeover | Apple private DFR APIs (same as MTMR/Pock) |
| MCP server | Node.js + TypeScript |
| State persistence | SQLite (WAL mode) |
| IPC | Unix domain socket (NDJSON) |
| Git integration | post-commit hooks (shell) |
| Claude integration | MCP tools + SessionStart hook |
| Distribution | Homebrew cask or npm |

## License

TBD
