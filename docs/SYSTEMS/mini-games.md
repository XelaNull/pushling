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

**Only input is gated — the behavior stack is not.** `PHASE-6.md`'s
P6-T3-04 design has the normal 4-layer behavior stack suspended during a
game, with only the Physics layer (breathing, gravity) continuing.
Code-verified this isn't what happens: `PushlingScene.update`'s
`updatePhysics()` calls `behaviorStack.update(...)` unconditionally, every
frame, with no check against `miniGameManager.isGameActive` anywhere in
that call path (grep-verified). The creature's Autonomous/Reflex/AI-Directed
layers keep running underneath a mini-game exactly as they would
otherwise — only the human's *touch input* is redirected, not the
creature's own ongoing behavior.

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
| `memory` | 50 | Complete 1 `catch` game | Symbol-sequence repeat game — built differently from the plan (below). |
| `treasure_hunt` | 100 | 3 total games completed (any type) | Cursor-and-temperature-bar search — built differently from the plan (below). |
| `rhythm_tap` | 60 | 5 total games completed | Notes scroll toward a hit zone; tap on beat — timing values match the plan exactly. |
| `tug_of_war` | 1 (binary win/lose) | 8 total games completed | Rapid-tap pull; see below. |

Unlock thresholds match `PHASE-6.md`'s P6-T3-11 table exactly (Catch free,
Memory at 1 Catch play, Treasure Hunt at 3 total, Rhythm Tap at 5 total,
Tug of War at 8 total) — this is one of the more faithfully-built Track 3
systems. The **discovery mechanic** the plan pairs with this table — the
creature teasing a locked game during idle (dropping a star for Catch,
showing symbols for Memory, digging for Treasure Hunt, floating notes for
Rhythm Tap) so it's "a mystery until unlocked" — has no code anywhere
(grep of `MiniGameManager` and the Autonomous layer); locked games are
simply invisible until unlocked. See [interactivity — unbuilt
features](/FEATURES/interactivity-unbuilt.md#cooperative-mini-game-modes).

**Catch** (`CatchGame.swift`) matches `PHASE-6.md`'s P6-T3-05 spec almost
exactly: 30s duration, stars fall at 40pt/sec, spawn interval ramps from
one every 2.0s to one every 0.8s (`initialSpawnInterval`/
`finalSpawnInterval`, linearly interpolated by elapsed time), a tap left
or right of the creature bursts it 50pt/sec for 0.3s
(`creatureMoveSpeed`/`moveBurstDuration`), and a missed star (reaching
Y=0) produces a 3-particle Ash dust puff with no score penalty.

**Memory** (`MemoryGame.swift`) is built to a **different design** than
`PHASE-6.md`'s P6-T3-06: instead of 4 symbol *shapes* each mapped to a
different *gesture type* (circle=tap, diamond=double-tap, star=long-press,
wave=swipe), the shipped game uses **6 fixed color-coded positions**
(Ember/Moss/Tide/Gilt/Dusk/Bone) and every input is a plain tap on the
correct position in sequence — there is no gesture-type variety. Sequence
length starts at 3 (`initialSequenceLength`) and grows by 1 each cleared
round up to a cap of 10 (`maxSequenceLength`); each symbol is shown for
0.6s (`showInterval`) with a 0.4s gap (`showPause`) — not the plan's
degressive 0.8s-to-0.5s per-round timing. Max score 50 matches the table
above (sum of successful round lengths). A wrong tap ends the round but
the game retries at the same sequence length if time remains (2s grace
before the 60s `gameDuration` cutoff); the plan's "perfect round = 2x
multiplier" bonus has no corresponding code.

**Treasure Hunt** (`TreasureHuntGame.swift`) is also built to a
**different design** than `PHASE-6.md`'s P6-T3-07. The plan's designed
6-tier hint system:

| Distance to Treasure | Creature Hint |
|---|---|
| > 500pt | Creature shivers. Speech: `"cold..."` (Critter+) or a snowflake symbol |
| 200-500pt | Creature looks around. Speech: `"hmm..."` or a `?` symbol |
| 100-200pt | Ears perk up. Speech: `"warmer!"` or a `!` symbol |
| 50-100pt | Tail wags fast. Speech: `"hot!"` or a `!!` symbol |
| < 50pt | Eyes wide, bouncing. Speech: `"HERE!"` or a star symbol |
| < 15pt | Treasure found |

and its input model (swipe left/right moves the search position 50-100pt
per swipe; the creature walks to the search position) — none of this is
what shipped. Instead, the shipped game renders a persistent temperature
bar (60x3pt, Tide fill) and a screen cursor the player bursts left/right
at 120pt/sec for 0.25s per tap (`moveSpeed`/`moveBurstDuration`, ~30pt per
tap — no swipe gesture, no creature walk-to), with its own **5-tier**
proximity-driven label (`updateTemperature`, `proximity = 1 -
distance/maxDistForHot(300)`): `< 0.3` COLD (Tide), `< 0.5` COOL (Tide),
`< 0.7` WARM (Moss), `< 0.85` HOT (Gilt), `>= 0.85` BURNING! (Ember) — text
labels and bar-fill color only, no speech lines, no symbol fallback, and
no creature reaction of any kind (no shiver/ear-perk/tail-wag/bounce).
Tapping within 30pt of the cursor (`digRadius`) attempts a dig. **3
treasures per 60s game** (`totalTreasures`), not the plan's single
treasure. Finding one within 25pt (`findRadius`) scores
`baseTreasureScore (40) + closenessBonus (15) * closeness-ratio +
timeBonus (10) * remaining-time-ratio` — a continuous proximity/time
formula, not the plan's discrete <15s/15-30s/30-45s/45-60s tiers.

**Rhythm Tap** (`RhythmTapGame.swift`) is the most faithful of the three:
120 BPM (`bpm`, matching the plan exactly) and perfect/good/OK timing
windows of 50/100/200ms (`perfectWindow`/`goodWindow`/`okWindow`) match
`PHASE-6.md`'s P6-T3-08 numbers exactly. It diverges on pattern count: 4
hardcoded patterns of increasing complexity (`patterns`, 8-18 beats each)
rather than the plan's "5 difficulty levels x 3 patterns" (15 total). The
"notes from both directions, human vs. Claude" cooperative variant has no
code — every note scrolls right-to-left toward a single hit zone.

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
[5] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (`updatePhysics()` — unconditional `behaviorStack.update` call)
[6] [state database schema](/DATA_MODELS/state-database-schema.md), [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md)
