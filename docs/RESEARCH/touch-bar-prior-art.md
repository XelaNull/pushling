---
type: Research Note
title: Touch Bar Prior Art Catalog
description: A 2026-03-14 survey of the Touch Bar software ecosystem — 15+ games, animation projects, tools/frameworks, and the six rendering-technique taxonomy — establishing that no prior Touch Bar virtual pet existed and that SpriteKit-at-60fps is proven by shipped projects.
status: Current
tags: [research, touch-bar, prior-art, spritekit]
timestamp: 2026-07-02T00:00:00Z
---

**Survey date: 2026-03-14, compiled by 11 parallel research agents.** This is
a point-in-time market/prior-art survey, preserved for its competitive
findings — it predates Pushling's native Swift daemon and should be read as
historical research, not a description of Pushling's current implementation
(see [Touch Bar hardware reference](/REFERENCE/touch-bar-hardware.md) and
[NSTouchBar private API reference](/REFERENCE/touch-bar-private-api.md) for
that). One entry in this catalog (row 6 of the rendering-technique taxonomy,
"touchbar-claude (us)") refers to Pushling's since-superseded MTMR/bash-era
prototype, not the shipped native daemon.

# Competitive Landscape

| Niche | Existing Projects | Position at Survey Time |
|---|---|---|
| Touch Bar games | 15+ projects | All traditional games; none are persistent creatures |
| **Touch Bar virtual pet** | **Zero** | **First-to-market** |
| Touch Bar + AI | claude-touch-bar (status only) | AI-evolving gameplay unique |
| **MTMR games** | **Zero** | **No one had built a game in MTMR** |

# Software Ecosystem Comparisons

## Hammerspoon

Free, open-source, Lua-scripted. The `hs._asm.undocumented.touchbar` module
enables `hs.canvas` objects in the Touch Bar — arbitrary graphics
(rectangles, ellipses, lines, text, images), compositing with blend modes,
touch events (mouseDown/Up/Move/EnterExit), ~30fps achievable, no Xcode
required. Identified as the "missing middle tier" between shell-script
rendering and a full native Swift build. Limitations: relies on private/
undocumented APIs (may break with macOS updates), smaller community, Lua is
less common than Bash or Swift.

## Electron

A thin wrapper around standard NSTouchBar items — buttons, labels, sliders,
scrubbers only, no custom rendering. Assessed as not useful for gaming.

## Software Comparison Matrix

| Capability | MTMR | BTT | Hammerspoon | Native Swift |
|---|---|---|---|---|
| Custom pixel graphics | No | No (44x44 icons) | Yes (canvas) | Yes (full 2170x60) |
| Animation FPS | 1-4 | 1-10 | ~30 | 60 |
| SpriteKit/Physics | No | No | No | Yes |
| Touch position tracking | No | No (discrete buttons) | Yes | Yes (sub-pixel) |
| Shell scripting | Yes | Yes | Via Lua | Via Process |
| MCP integration ease | Easy | Medium | Medium | Hard |
| Setup complexity | Low | Low | Medium | High |
| Push-based updates | No | Yes | Yes | Direct rendering |
| Haptic feedback | Yes (global) | Unknown | Unknown | Yes (private API) |
| Cost | Free | $12-24 | Free | Free (Xcode) |

# Existing Projects Catalog

## Games

| Project | Stars | Engine | Genre |
|---|---|---|---|
| Touch-Bar-Lemmings | 534 | SpriteKit | Puzzle/Platformer |
| TouchBarDino | 451 | SpriteKit | Runner |
| Pac-Bar | 380 | SpriteKit | Pac-Man |
| TouchBarSpaceFight | 376 | SpriteKit | Shooter |
| TouchBreakout | 344 | SpriteKit | Breakout |
| TouchBarPong | 138 | SpriteKit | Pong |
| Flappy Bird (touchbar-flappy-bird) | 14 | SpriteKit | Flappy |
| ESCapeEleanor | 8 | SpriteKit | Escape room (WWDC20 student submission) |
| TouchBarGopher | 7 | Swift | Whack-a-mole |
| Space-Bar | N/A | Native | Breakout hybrid |
| JoesDungeon | 2 | SpriteKit | Dungeon |
| TouchBarSpaceInvaders | 2 | Native | Space Invaders |
| WhackBar | 1 | Swift | Whack-a-mole |
| BananaMan | 0 | SpriteKit | Endless runner |
| Doom (Adam Bell demo) | N/A | Custom renderer | FPS |

## Animations & Fun

| Project | Stars | What It Does | Technique |
|---|---|---|---|
| touchbar_nyancat | 2,992 | Animated Nyan Cat | NSImageView + GIF + 100Hz Timer |
| KnightTouchBar2000 | 504 | KITT scanner sweep | Core Animation (CAShapeLayer) + audio |
| osx-touchbar-party-parrot | 297 | Party parrots | Electron + frame-by-frame PNGs |
| sl_on_touchbar | 57 | Steam locomotive | Swift native |
| parrots-on-steroids | 42 | Enhanced parrots | Electron + 128x128 PNG frames |

## Productivity Tools with Creative UI

| Project | Stars | What It Does |
|---|---|---|
| Thief | 6,030 | Read novels on Touch Bar at work |
| Muse | 635 | Spotify controller with album art in Control Strip |
| CoinPriceBar | 313 | Live crypto prices |
| Clock-Bar | 302 | Clock display |
| touchbar-systemmonitor | 264 | CPU/RAM/network (Electron, color-coded) |
| toucHNews | 193 | Hacker News reader (Rust) |
| touch-bar-emojis | 163 | Persistent emoji picker (private APIs) |
| Touch-Bar-iStats | 155 | CPU/GPU temp (BTT) |
| MVTouchbar | 59 | Audio visualizer in Control Strip |
| WriteBar | 43 | Text line displayed on Touch Bar |
| claude-touch-bar | 0 | Claude Code status with color transitions (DFR private APIs) |

## Tools & Frameworks

| Project | Stars | Purpose |
|---|---|---|
| MTMR | 4,283 | Touch Bar customizer (JSON config) |
| Pock | 10,140 | Dock in Touch Bar + PockKit widget SDK |
| BetterTouchTool | Commercial | Touch Bar + gestures + automation |
| Hammerspoon | 12K+ | macOS automation (Lua) + Touch Bar canvas |
| touch-baer | 237 | Control Strip private API |
| react-native-touchbar | 758 | React Native Touch Bar bridge |
| TouchBarKit | N/A | Control Strip wrapper |
| TouchBarHelper | N/A | Private API wrapper |
| btt (Worie) | 125 | JavaScript wrapper for the BTT webserver |

## Developer Tools

| Project | Stars | Purpose |
|---|---|---|
| touch-bar-simulator | 1,927 | Standalone Touch Bar simulator |
| TouchBarDemoApp | 1,650 | Touch Bar on iPad via USB / on-screen |
| HapticKey | 1,670 | Haptic feedback on Touch Bar tap |
| TouchBarRecorder | N/A | Command-line Touch Bar video recorder |

## MTMR & BTT Preset Collections

| Collection | Stars | Notes |
|---|---|---|
| btt-touchbar-presets | 1,835 | 13+ presets including GoldenChaos |
| MTMR-presets | 437 | 86+ community presets — no games, all productivity |
| GoldenChaos-BTT | 314 | Complete Touch Bar UI replacement |
| GoldenRabbit-BTT | 217 | Optimized BTT preset (~30MB RAM) |

## Music & Visualization

| Project | Purpose |
|---|---|
| Touch Bar Piano | Polyphonic piano, 128 instruments |
| MIDI Touchbar | MIDI controller for DAWs |
| Samplr for Touchbar | Audio sampler |
| Knight Rider | KITT scanner sweep (Core Animation) |
| Touch Bar Visualizer | Audio frequency visualization |
| AVTouchBar | Customizable audio visualizer |
| StoqTkr / TickerBar | Stock/crypto ticker displays |

## Rendering Technique Taxonomy (All 6 Methods Ever Used)

| # | Technique | Used By | FPS | Touch | Scripted? |
|---|---|---|---|---|---|
| 1 | SpriteKit (SKView) | Dino, Pac-Bar, Lemmings, Breakout, 5+ others | 60 | Full multi-touch | No (Swift) |
| 2 | NSImageView + GIF | Nyan Cat, Santa | 10-30 + 100Hz position | Touch drag | No (Swift) |
| 3 | PNG frame sequences (Electron) | Party parrots | 10-30 | Tap only | JS |
| 4 | Canvas→base64→button (Electron) | vue-electron-touchbar-game | 30 | Tap only | JS |
| 5 | Core Animation (CALayer) | Knight Rider, TouchBreakout paddle | 60 | Full | No (Swift) |
| 6 | Text/emoji via shell (MTMR) | **touchbar-claude (us)** — this project's since-superseded MTMR/bash-era prototype | 1-4 | Tap | Yes (Bash) |

The canvas→base64→button hack (#4) is notable: render to an HTML canvas,
dump as base64, set as a giant button icon every 33ms. Achieves 30fps via
web tech alone.

## Notable Discoveries

| Project | What It Proved |
|---|---|
| Touchbar Pet (Grace Avery) | Native Swift tamagotchi with touch interaction — validated the concept |
| claude-touch-bar (darrellgum) | DFR Control Strip integration for Claude Code status — adjacent project |
| DFRDisplayKm | Touch Bar as a raw framebuffer device (Windows driver) |
| Wenting Zhang | Touch Bar OLED driven standalone by an RP2040 microcontroller |
| vue-electron-touchbar-game | Canvas→base64→button achieves 30fps in Electron |
| GX (Devpost) | Hackathon game collection for the Touch Bar |

# Multi-Touch-Bar Multiplayer (Zero Prior Art)

No prior art existed for this concept at survey time: two MacBooks
synchronizing game state via `nc` (netcat) or shared files, each rendering
its own viewport of a shared world. Turn-based play works even over
high-latency connections at a 1-second refresh; real-time on a LAN is
achievable at ~100ms sync. Speculative modes noted: cooperative creature
care (one player feeds, one plays) and shared-world exploration (creatures
from different Macs interacting).

# Doom Was Here

Adam Bell ported Doom to the Touch Bar — full 3D rendering at 2170x60 with
HUD, sound, and gameplay. Proof that the hardware has no inherent rendering
limitation; the constraint is software, not silicon. (Full feasibility
analysis of this precedent for Pushling's own rendering choice is
[the 3D rendering feasibility research](/RESEARCH/3d-rendering-feasibility.md),
not this concept.)

# Citations

### Primary Research Sources
[1] [MTMR Repository](https://github.com/Toxblh/MTMR) — source code analysis
[2] [BetterTouchTool Documentation](https://docs.folivora.ai/) — official docs
[3] [Pock Repository](https://github.com/pock/pock) — private API headers
[4] [Apple NSTouchBar Documentation](https://developer.apple.com/documentation/appkit/nstouchbar)
[5] [Hammerspoon Touch Bar Module](https://github.com/asmagill/hs._asm.undocumented.touchbar)

### Game Source Code Analyzed
[6] [touchbar_nyancat](https://github.com/avatsaev/touchbar_nyancat) — NSImageView animation
[7] [TouchBarDino](https://github.com/yuhuili/TouchBarDino) — SpriteKit game
[8] [TouchBarSpaceFight](https://github.com/insidegui/TouchBarSpaceFight) — SpriteKit shooter
[9] [TouchBreakout](https://github.com/krayc425/TouchBreakout) — SpriteKit + touch tracking
[10] [Knight Rider](https://github.com/sudo-self/Knight-rider-touchbar) — Core Animation

### Hardware Research
[11] [DFRDisplayKm](https://github.com/imbushuo/DFRDisplayKm) — Windows framebuffer driver
[12] [Wenting Zhang — reverse-engineering the Apple Touch Bar screen](https://hackaday.com/2024/01/23/reverse-engineering-the-apple-touch-bar-screen/)
[13] [apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer) — IMU access
[14] [spank](https://github.com/taigrr/spank) — MacBook slap detection
[15] [Touch Bar iFixit Teardown](https://www.ifixit.com/Teardown/MacBook+Pro+13-Inch+Touch+Bar+Teardown/73480)

### Tools & Libraries
[16] [Drawille](https://github.com/asciimoo/drawille) — Braille pixel rendering
[17] [mbeep](https://github.com/7402/mbeep) — CLI tone generator
[18] [HapticKey](https://github.com/niw/HapticKey) — Haptic feedback
[19] [touch-baer](https://github.com/a2/touch-baer) — Control Strip private API
[20] [TouchBarKit](https://github.com/L1cardo/TouchBarKit) — Private API wrapper
[21] [awesome-touchbar](https://github.com/z11h/awesome-touchbar) — Curated list

### Primary Source
[22] `docs/archive/TOUCHBAR-TECHNIQUES.md` — §3.4-3.6 (Software Ecosystem), §10.5 (Multi-Touch-Bar Multiplayer), §10.8 (Doom Was Here), §11 (Existing Projects Catalog, all subsections), Sources & References (full document, compiled 2026-03-14 by 11 parallel research agents)
