---
type: Reference
title: Personality & Emotional State
description: The 5 slow-drifting personality axes and the 4 fast-moving emotional axes that together drive every behavioral and visual variation between two creatures at the same growth stage.
status: Live
tags: [personality, emotion, circadian, emergent-state]
timestamp: 2026-07-02T00:00:00Z
---

Two independent state systems shape how a Pushling looks and acts, on two
very different timescales. **Personality** (`Personality`,
`Pushling/Sources/Pushling/Creature/PersonalitySystem.swift`) is *who the
creature is* — set at birth (see
[creature identity & birth](/REFERENCE/creature-identity-birth.md)) and
drifting only slowly over weeks. **Emotional state** (`EmotionalState`,
`Pushling/Sources/Pushling/Creature/EmotionalState.swift`) is *how it
feels* — moving within minutes to hours. Both feed
[the behavior stack](/SYSTEMS/behavior-stack.md) every frame as read-only
snapshots (`PersonalitySnapshot`, `EmotionalSnapshot`) and are exposed to
Claude via `pushling_sense`.

# Personality: 5 Axes

All axes are `Double` in `[0.0, 1.0]`, persisted in the `creature` table's
`*_axis` columns, with `Personality.clampAxes()` enforcing range.

| Axis | 0.0 (low end) | 1.0 (high end) | Driven by (vision doc framing) |
|---|---|---|---|
| **Energy** | Calm, slow, long naps, gentle purr | Hyperactive, zoomies, bouncy, chatty | Commit frequency/bursts |
| **Verbosity** | Stoic, single symbols, meaningful stares | Speech bubbles, narration, running commentary | Message length/quality |
| **Focus** | Deliberate, sits in one spot, deep examiner | Scattered, chases everything, attention darting | Files per commit, repo switching |
| **Discipline** | Chaotic, jerky movement, unpredictable | Methodical, smooth patterns, ritual behaviors | Commit timing regularity |
| **Specialty** | *category, not a spectrum* — see below | | Dominant file extensions |

**The exact formulas differ depending on which birth computation path
produced them** — see
[creature identity & birth](/REFERENCE/creature-identity-birth.md#the-live-birth-flow-progressive-learning-via-eggaccumulator)
for the live 5-commit `EggAccumulator` formulas (fixed 0.5 Discipline; no
true regularity signal yet) versus the fuller lifetime `GitHistoryScanner`
formulas (Discipline genuinely computed from `1.0 - stddev(commit_hour) /
6.0`) that exist in code but are not currently wired into the birth flow.
Both agree on Energy/Verbosity/Focus being burst-ratio, message-length, and
files-per-commit driven respectively, consistent with the vision doc's
framing above.

## Language Specialty Categories

`LanguageCategory` — 11 categories, not a spectrum. Determines
`baseColorHue` for the creature's body tint and feeds `TailShape` selection
(via [creature identity & birth](/REFERENCE/creature-identity-birth.md)):

| Category | Extensions (subset) | Hue | Tail influence |
|---|---|---|---|
| Systems | .rs .c .cpp .go .zig .h .hpp .cc | 0.08 (orange) | thin whip |
| Frontend | .tsx .jsx .vue .svelte .css .scss .html .less .sass | 0.15 (yellow) | fluffy plume |
| Backend | .php .rb .erb | 0.75 (purple) | fluffy plume |
| Script | .py .sh .bash .lua .pl .r .zsh | 0.45 (blue-green) | serpentine curl |
| JVM | .java .kt .scala .groovy .clj | 0.58 (blue) | standard |
| Mobile | .swift .m .dart | 0.05 (red-orange) | standard |
| Data | .sql .csv .ipynb .parquet | 0.55 (cyan-blue) | standard |
| Infra | .yaml .yml .tf .dockerfile .nix .toml .hcl | 0.30 (green) | standard |
| Docs | .md .txt .rst .tex .adoc | 0.12 (warm yellow) | standard |
| Config | .json .xml .ini .env .properties | 0.60 (blue) | standard |
| Polyglot | *(no category > 30%)* | 0.50 (neutral teal) | standard |

Dominant-category determination requires one category to exceed 30% of
observed extension counts; otherwise the creature is `.polyglot`. **This
`LanguageCategory` enum's raw values do not fully match the `specialty`
column's SQLite `CHECK` constraint** — see the adjudication in
[creature identity & birth](/REFERENCE/creature-identity-birth.md#adjudication-specialty-column-check-constraint-mismatch)
for the specific mismatched values and the persistence-failure risk it
creates; this concept documents the enum (matching vision-doc canon) as the
prescriptive truth for what "specialty" means.

# Emotional State: 4 Axes

All axes are `Double` in `[0, 100]`, decaying toward a neutral midpoint
(50, or toward 0 for satisfaction) when unfed, persisted every 60 seconds
(not every frame) to the `creature` table's `satisfaction`, `curiosity`,
`contentment`, `emotional_energy` columns.

| Emotion | Increases | Decreases | At 0 | At 100 |
|---|---|---|---|---|
| **Satisfaction** | Commits (+10/+20/+30 by `CommitSize` small/medium/large) | Continuous decay, `-1` per 3 min | Sluggish, droopy ears, muted colors | Glowing coat, vibrant, purring |
| **Curiosity** | New repos (+20), new file types (+10), touch (+5) | Repetitive commits (-5), idle > 10 min (additional `-2`/min on top of the baseline drift toward 50) | Bored, ignores everything, loafs | Discovery mode, examining everything |
| **Contentment** | Streak days (+5), interactions (+8), milestones (+15) | Streak breaks (-20); baseline drift toward 50 at `-1`/10 min when idle | Melancholy, darker tint, tail low | Bright aura, kneading, slow-blinks |
| **Energy** (emotional) | Commits (+5 alongside satisfaction), dawn hours 06:00–10:00 (`+1`/min) | Nighttime 22:00–05:00 (`-0.5`/min); sustained activity past 2 continuous hours (`-1`/min) | Asleep (curled, tail over nose) | Zoomies, maximum animation speed |

This *emotional* Energy axis (`EmotionalState.energy`) is distinct from the
*personality* Energy axis above — same name, different timescale and
different code type (`EmotionalSnapshot.energy` vs
`PersonalitySnapshot.energy`), a distinction the class-level doc comment in
`EmotionalState.swift` calls out explicitly to avoid confusion.

`EmotionalState.applyElapsedDecay(seconds:averageHour:)` runs once on
daemon launch to fast-forward decay for the gap since the last persisted
`last_session_at`, so a creature that was quit for 8 hours doesn't read as
still having the emotional state from 8 hours ago.

# Emergent States

`EmergentStateDetector` (`Pushling/Sources/Pushling/Creature/EmergentStates.swift`)
combines the four emotional axes into named compound states, re-evaluated
every 5 seconds (not every frame), one active at a time, in this priority
order (highest first — matches the vision doc's stated order exactly):

| State | Condition (exact thresholds from code) | Modifiers |
|---|---|---|
| **Exhausted** | `energy < 10` | 0.3× walk speed, 5× cooldown multiplier, tail low, half-closed eyes |
| **Hangry** | `satisfaction < 25 AND energy > 40` | 1.1× walk speed, agitated (2.5× direction-change frequency), tail twitch, squint |
| **Blissful** | `satisfaction > 75 AND contentment > 75 AND 30 ≤ energy ≤ 70` | 0.8× walk speed, purr particles on, slow-blink every 20s, warm aura |
| **Playful** | `energy > 70 AND contentment > 60` | 1.3× walk speed, 1.5× direction-change frequency, tail high |
| **Studious** | `curiosity > 75 AND 30 ≤ energy ≤ 70` | 0.7× walk speed, longer idle durations, tail-tip twitch |
| **Zen** | all four axes within `[40, 60]` | 0.0× walk speed (stationary), 3× cooldown, half-closed eyes, pulsing aura |

If none of these conditions match, no emergent state is active
(`currentState == nil`) and the autonomous layer runs with no modifiers.
`sense.ts`/`SenseHandlers.swift` expose the active state (or its absence)
plus a derived `mood_summary` string and `circadian_phase` in the
`pushling_sense("self")` response — these three fields are **computed at
IPC-response time**, not persisted SQLite columns; a grep for
`emergent_state`/`mood_summary`/`circadian_phase` as table columns finds
none.

# Emotional Visual Feedback: Axis → Body Language

The four emotional axes above are not just numbers Claude reads via
`pushling_sense` — they are **visually manifest** on the creature's body
every frame, independent of the named [emergent states](#emergent-states)
above. `EmotionalVisualController.update()` (called once per frame from
`PushlingScene.updateRender()`) reads `EmotionalState` directly and drives
the body-part controllers ([creature visual design](/REFERENCE/creature-visual-design.md)
owns the controllers themselves):

| Emotion condition | Body part | Visual effect |
|---|---|---|
| Satisfaction < 30 | Tail | `"low"` (droops) |
| Satisfaction < 30 | Ears | `"droop"` |
| Curiosity > 70 | Ears | `"perk"` (forward) |
| Curiosity > 70 | Eyes | `"wide"` |
| Energy > 70 | Breathing | period overridden to 2.0s (faster) |
| Energy < 30 | Breathing | period overridden to 3.5s (slower) |
| Energy < 30 | Eyes | `"half"` (sleepy) |
| Contentment > 75 | Tail | `"sway"` (happy) |
| Hangry (satisfaction < 25 AND energy > 40) | Ears | `"back"` (flatten) |
| Hangry | Tail | `"twitch_tip"` (annoyed) |

Hangry is checked first and, when active, suppresses the sad/curious/content
ear and tail overrides for that frame (it does not suppress the breathing or
mouth mapping below). All ten rows are code-verified against
`EmotionalVisualController.swift`'s exact threshold literals — they match
the vision doc's "Emotional Visual Feedback" table number-for-number.

**Hysteresis**: each of the six tracked boolean states (sad/curious/content/
tired/hangry, plus the mouth state machine below) only flips once the axis
crosses its threshold by **`activateMargin = 5.0`** points beyond the
trigger direction (e.g. curiosity must exceed 75, not just 70, to *activate*
"curious," but must drop below 65, not just 70, to *deactivate* it) — the
5-point margin the vision doc calls for, implemented as an asymmetric
re-arm band around each threshold rather than a single crossing check.

**Beyond the vision doc**: `EmotionalVisualController` also drives a mouth
state machine with no equivalent in `PUSHLING_VISION.md` — pout (hangry,
highest priority), smile (satisfaction > 70 AND contentment > 70), frown
(satisfaction < 30), `open_small` (curiosity > 70), and an occasional yawn
(energy < 25, 60-second cooldown) when none of the above apply, falling
back to closed. This is documented here as canon (later-built, matching this
migration's rule for undocumented shipped systems) rather than treated as a
gap.

# Circadian Cycle

`CircadianCycle` (`Pushling/Sources/Pushling/Creature/CircadianCycle.swift`)
learns the developer's commit schedule over a 14-day rolling window
(`learningPeriodDays = 14`) via a 24-bin hourly commit histogram, then
derives a weighted first/last commit hour (defaults: 09:00 / 18:00 before
enough data exists). Five `CircadianPhase` values: `sleeping`, `waking`
(30 min before the learned first-commit hour, `wakeLeadMinutes = 30`),
`awake`, `sleepy` (30 min after the learned last-commit hour,
`sleepyLagMinutes = 30`), `drowsy` (after `sleepIdleMinutes = 10` minutes
of idle past the sleepy threshold). An out-of-schedule commit nudges the
schedule by `adjustmentMinutesPerCommit = 15` minutes toward the new data
point, so a habitual night-owl session gradually shifts the learned window
rather than being treated as a one-off anomaly. This matches the vision
doc's circadian description (stirs before typical first commit, sleepy
after typical last, adjusts on off-schedule activity) with the specific
minute values verified above.

# Citations

[1] `Pushling/Sources/Pushling/Creature/PersonalitySystem.swift`
[2] `Pushling/Sources/Pushling/Creature/EmotionalState.swift`
[3] `Pushling/Sources/Pushling/Creature/EmergentStates.swift`
[4] `Pushling/Sources/Pushling/Creature/CircadianCycle.swift`
[5] `Pushling/Sources/Pushling/Creature/GitHistoryScanner.swift` (lifetime personality formulas)
[6] `Pushling/Sources/Pushling/Creature/EggAccumulator.swift` (5-commit personality formulas, identity bias)
[7] `Pushling/Sources/Pushling/IPC/SenseHandlers.swift`, `mcp/src/tools/sense.ts`, `mcp/src/tools/sense-helpers.ts` (`emergent_state`, `mood_summary`, `circadian_phase`)
[8] `Pushling/Sources/Pushling/Creature/EmotionalVisualController.swift` (axis→body-part bridge, hysteresis, mouth state machine)
[9] `PUSHLING_VISION.md` — Personality System; Emotional State; Circadian cycle; Emotional Visual Feedback (lines 1507–1524)
