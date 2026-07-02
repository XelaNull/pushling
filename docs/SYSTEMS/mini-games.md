---
type: System
title: Mini-Game System
description: The shared mini-game lifecycle (trigger, intro, active play, result screen), the five games it hosts, score-tier XP awards, and play-count unlock progression — all built solo-only, with cooperative Claude modes absent.
status: Live
tags: [touch, mini-games, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for the **shared mini-game framework** — lifecycle,
input routing, scoring, and unlock progression. Per-game rules are
summarized here (each game is small enough not to warrant its own
concept); this does not own touch gesture classification (see
[the touch input pipeline](/SYSTEMS/touch-input-pipeline.md)). Source:
`Input/Games/MiniGameManager.swift` and the five `Input/Games/*Game.swift`
implementations.

# Input Takeover

While `MiniGameManager.isGameActive` (any phase except `.inactive`),
`CreatureTouchHandler.gestureRecognizer(_:didRecognize:)` forwards
**only** `.tap` events to `miniGameManager.handleTap(at:)` and drops every
other gesture type — no petting, no laser pointer, no camera pan, no
object interaction runs while a game is active. This is a hard gate at
the very top of the gesture dispatch switch, checked before any
target-based routing.

# Lifecycle

```
Trigger -> intro (1.0s) -> active (game-specific duration) -> ending -> resultScreen (3.0s) -> inactive
```

`startGame(_:source:in:)` refuses to start if a game is already active
(`phase != .inactive`) or the requested type isn't yet unlocked. Three
`GameTriggerSource` values exist in the type system —
`.creatureInvitation`, `.claudeMCP`, `.humanGesture` — but only
`.humanGesture` triggers are wired from anywhere in the searched code (the
per-game gesture triggers described in `PHASE-6.md`, e.g. "rapid taps near
creature -> Catch begins," are not implemented as automatic starts either
— no call site passes `.creatureInvitation` or `.claudeMCP` was found, and
`mcp/src/tools/perform.ts`'s `VALID_BEHAVIORS` has no `game` parameter to
drive `.claudeMCP` starts). In the current build, mini-games can only be
started from whatever debug/menu entry point calls `startGame` directly —
see [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md)
for the missing invitation/MCP trigger paths.

On end, `endGame()` computes a score tier and awards XP/satisfaction:

| Score Fraction | XP | Satisfaction |
|---|---|---|
| >= 100% (perfect) | 12 | +20 |
| >= 70% | 8 | +15 |
| >= 30% | 5 | +10 |
| < 30% | 3 | +5 |

`GameResultScreen.show(...)` renders the tally; the game's node layer
(`zPosition = 80`, above world/below weather effects) is torn down and the
manager returns to `.inactive` after the fixed 3.0s result display.

# The 5 Games

| Game | Max Score | Unlock Condition | Notes vs. design |
|---|---|---|---|
| `catch` (`catchStars`) | 25 | Always unlocked | Stars fall, tap left/right of creature to move it. |
| `memory` | 50 | Complete 1 `catch` game | Symbol-sequence repeat game. |
| `treasure_hunt` | 100 | 3 total games completed (any type) | Hot/cold hint-based search. |
| `rhythm_tap` | 60 | 5 total games completed | Notes scroll toward a hit zone; tap on beat. |
| `tug_of_war` | 1 (binary win/lose) | 8 total games completed | Rapid-tap pull; see below. |

Unlock thresholds match `PHASE-6.md`'s P6-T3-11 table exactly (Catch free,
Memory at 1 Catch play, Treasure Hunt at 3 total, Rhythm Tap at 5 total,
Tug of War at 8 total) — this is one of the more faithfully-built Track 3
systems.

**Tug of War is solo-only.** The plan and vision docs describe it as
"Human vs Claude, creature in the middle," with Claude pulling via
repeated `pushling_perform({game: "tug"})` calls. `TugOfWarGame.swift`
implements only the human-vs-creature version: the creature itself
applies an automatic rightward pull (`creaturePullBase`/`creaturePullMax`,
ramping over time, plus an occasional `creatureSurgeForce` burst) tuned so
the human wins roughly 55% of the time — this is the "creature subtly
cheats" mechanic from the design, just applied to the creature-as-opponent
rather than Claude-as-opponent. No `pushling_perform` game parameter,
Claude-driven pull, or any other cooperative-input path exists in this
file or in `mcp/src/tools/perform.ts`.

**No game has a cooperative/COMBO mode.** `PHASE-6.md` describes
Claude-assisted modes for all five games (Catch's tap-plus-`pushling_move`
COMBO, Memory's alternating human/Claude symbols, Treasure Hunt's
`pushling_speak` direction hints, Rhythm Tap's dual-direction notes, Tug
of War's Claude pulls). Grepping all five `Input/Games/*.swift` files for
`combo`/`cooperative`/`pushling_` turns up nothing beyond the solo
implementations described above — every game here is a single-player
experience today. Tracked as intent-canon at
[interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md).

# Persistence

`game_scores` (high score + total plays per `game_type`) and
`game_unlocks` (unlocked flag + total plays per `game_type`) — see
[the game_scores/game_unlocks schema](/DATA_MODELS/state-database-schema.md#game_scores).
Both are written together in `saveGameState()` after every completed
game, using `INSERT ... ON CONFLICT DO UPDATE` upserts (`high_score` takes
`MAX(existing, new)`). `loadGameState()` re-derives `totalGamesCompleted`
by summing `totalPlays` across all loaded rows on daemon startup, so the
in-memory unlock-progression counters survive a restart.

# Citations

[1] `Pushling/Sources/Pushling/Input/Games/MiniGameManager.swift`
[2] `Pushling/Sources/Pushling/Input/Games/{CatchGame,MemoryGame,TreasureHuntGame,RhythmTapGame,TugOfWarGame,GameResultScreen}.swift`
[3] `mcp/src/tools/perform.ts` (`VALID_BEHAVIORS` — no game parameter)
[4] `docs/archive/plan/phase-6-interactivity/PHASE-6.md` — P6-T3-04 through P6-T3-11
[5] [state database schema](/DATA_MODELS/state-database-schema.md), [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md)
