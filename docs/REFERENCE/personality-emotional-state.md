---
type: Reference
title: Personality & Emotional State
description: The 5 slow-drifting personality axes and the 4 fast-moving emotional axes that together drive every behavioral and visual variation between two creatures at the same growth stage — plus the axis-to-motion modulation tables (shipped `PersonalityFilter`/`AttractionScorer` and Phase-2 designed extensions), the valence×arousal collapse, the boldness derivation, and the bond-tier derived stat the rest of the dossier reads from here.
status: Live
tags: [personality, emotion, circadian, emergent-state, boldness, bond-tier, modulation]
timestamp: 2026-07-03T00:00:00Z
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

**Superseding work in progress:** [emotional body language](/SYSTEMS/emotional-body-language.md)
documents this exact ten-row table as its own "Current Shipped Baseline"
(hard five-branch, threshold-gated) and designs a **continuous** replacement
— the [valence×arousal collapse](#valence--arousal-the-shared-mood-coordinate)
defined below, feeding a torso-wide Posture Vocabulary with no equivalent
here. This section remains the accurate description of what ships *today*;
that concept owns tomorrow's fuller version.

# Personality → Motion: The Shipped `PersonalityFilter` Table

`PersonalityFilter` (`Creature/PersonalityFilter.swift`) is a pure,
side-effect-free modulation library — every animation parameter in the
product that varies by personality passes through one of its functions.
Individual entries are already cited piecemeal across
[procedural animation](/REFERENCE/procedural-animation.md) (tail sway),
[locomotion & gait](/SYSTEMS/locomotion-and-gait.md) (`animationTempo`,
`modulatedWalkSpeed`), [idle life & rest](/SYSTEMS/idle-life-and-rest.md)
(`idleDuration`), and [behavior stack](/SYSTEMS/behavior-stack.md)
(expression-crossfade tempo) — this table is the first place the whole
file is cataloged in one pass, code-verified line-for-line. **All of it is
shipped.**

| Function | Axis | Formula | Output range |
|---|---|---|---|
| `walkSpeed` | Energy | `0.6 + energy × 0.8` | 0.6×–1.4× base speed |
| `walkDuration` | Energy (inverse) × Focus | `(1.5 − energy) × (0.8 + focus × 0.4)` | 0.5×–1.5× base, further scaled 0.8×–1.2× by focus |
| `idleDuration` | Energy (inverse) | `1.5 − energy` (× emergent-state multiplier) | 0.5×–1.5× base |
| `behaviorCooldown` | Energy (inverse) | `0.6 + (1 − energy) × 0.8` | 0.6×–1.4× base |
| `directionChangeProbability` | Focus (inverse) | `0.5 + (1 − focus) × 1.0` | 0.5×–1.5× base — scattered creatures change direction up to 3× as often as deliberate ones |
| `jitterRange` | Discipline (inverse) | `0.03 + (1 − discipline) × 0.17` | ±3% (metronomic) to ±20% (chaotic) — the **generic shipped jitter primitive**, applied via `applyJitter(base:jitterFactor:personality:)` to any timing value |
| `blinkInterval` | Energy | min `lerp(4.0, 2.5, energy)`, max `lerp(9.0, 5.0, energy)` | interval shrinks toward 2.5–5.0s at high energy from 4.0–9.0s at low |
| `tailSwayAmplitude` | Energy | `0.7 + energy × 0.6` | 0.7×–1.3× base |
| `tailSwayPeriod` | Energy (inverse) × Discipline | `(0.7 + (1 − energy) × 0.6) × (0.9 + discipline × 0.2)` | faster sway at high energy, more consistent period at high discipline |
| `reactionExpressiveness` | Verbosity | `0.5 + verbosity × 1.0` | 0.5×–1.5× — chatty creatures react with their whole body, stoic ones barely twitch |
| `earMovementFrequency` | Focus | `0.5 + focus × 1.0` | 0.5×–1.5× |
| `animationTempo` | Energy | `0.7 + energy × 0.7` | 0.7×–1.4× — the general transition-speed multiplier for body-part crossfades |
| `reflexSnapDuration` | Specialty (Mobile only) | `× 0.8` | Mobile specialists get 20% faster reflex snaps (0.12s vs 0.15s base) — the only Specialty-driven *timing* modifier; the rest of Specialty's effects (`bodyAlpha`, ear-perk sparkle, data-spark trail, smooth walk cycle, clockwork tail, heterochromia) are one-shot visual/cosmetic flags, not per-frame modulation |
| `modulatedWalkSpeed` | Energy (personality) × Energy (emotional) | `walkSpeed(energy) × (0.5 + emotionalEnergy/100 × 0.5)` | Compounds the *personality* Energy axis with the *emotional* Energy axis — the one function that deliberately reads both same-named-but-distinct axes at once |
| `visualModifiers` | Energy, Focus, Discipline | `eyeOpenness = 0.85 + energy×0.3`; `earAngle = (focus−0.5)×0.15`; `bodyHeightScale = 0.97 + discipline×0.06`; `whiskerSpread = 0.85 + focus×0.3`; `tailBaseAngle = (energy−0.5)×0.3` | One-time, applied at stage-build, not per-frame |

**Discrepancy flagged for Samantha:** [locomotion & gait](/SYSTEMS/locomotion-and-gait.md#personality-modulation)'s
designed (not-yet-built) stride-timing jitter table proposes a *new*
Discipline range of 0% (metronomic) to ±12% (chaotic) for per-stride
timing, rather than routing through the already-shipped generic
`jitterRange`/`applyJitter` primitive above (±3%–±20%). Both encode the
same "Discipline → regularity" idea with different numbers and a
different floor (0% vs 3%) — worth reconciling to one function when the
gait engine is built, rather than shipping a second, narrower jitter
range that silently diverges from the one every other timing value in the
product already uses.

# Personality → World-Object Affinity (`AttractionScorer`, shipped)

`AttractionScorer` (`World/AttractionScorer.swift`) is the second major
shipped axis-to-behavior bridge, distinct from `PersonalityFilter` above —
it doesn't modulate *how* an animation plays, it modulates *which*
autonomous object interaction the creature is drawn to. Its 7-factor
formula (`base × personality × mood × recency × novelty × proximity ×
time`) multiplies a per-category base weight by a personality-affinity
term:

```
personalityAffinity = lerp(low, high, axisValue)
```

where `axisValue` is the named axis read straight off `PersonalitySnapshot`
(`AttractionScorer.swift:180-189`). 15 interaction categories are wired
today, spanning four of the five axes (Specialty has no affinity entry —
it drives visual/tail-shape traits, not interaction preference):

| Category | Axis | Low → High affinity | Reads as |
|---|---|---|---|
| `chasing` | Energy | 0.5 → 2.0 | Energetic creatures chase 4× as readily as calm ones |
| `batting_toy` | Energy | 0.5 → 2.0 | Same curve as chasing |
| `string_play` | Energy | 0.6 → 1.8 | |
| `climbing` | Energy | 0.7 → 1.5 | |
| `eating` | Energy | 0.8 → 1.3 | Mildest energy skew of the set |
| `sitting` | Energy (inverse) | 2.0 → 0.5 | Calm creatures sit 4× as readily as hyperactive ones |
| `hiding` | Energy (inverse) | 1.5 → 0.5 | |
| `carrying` | Focus | 0.7 → 1.5 | |
| `examining` | Focus | 0.7 → 1.5 | |
| `listening` | Focus | 0.7 → 1.5 | |
| `reflecting` | Focus | 0.7 → 1.5 | |
| `watching` | Focus | 0.5 → 1.8 | Sharpest focus skew — deliberate creatures watch, scattered ones don't |
| `pushing` | Discipline (inverse) | 1.8 → 0.5 | Chaotic creatures push things over more; a live example of a *low*-axis affinity outranking its high end |
| `scratching` | Discipline | 0.8 → 1.3 | |
| `rubbing` | Verbosity | 0.8 → 1.3 | Social/chatty creatures scent-rub more — the one Verbosity-affinity entry, and a direct precedent for [companionship rituals](/SYSTEMS/companionship-rituals.md)'s developer-directed rubbing/bunting behaviors, which currently cite no personality gating of their own |

This table is the real, shipped precedent for personality-gated behavior
*selection* (as opposed to modulation of an already-chosen behavior's
motion), and the pattern any Phase-2 feature adding a new personality-
gated choice (bug-species preference, play-toy pick, patrol thoroughness)
should extend rather than re-invent.

# Axis → Motion Modulation: Phase-2 Designed Extensions

The shipped tables above cover what exists today. The features below are
**designed, not built** — this section is their shared axis-derivation
authority, cross-linked from the concepts that consume each one so no
second, conflicting formula gets invented downstream.

## Energy → Gait Amplitude & Play-Bout Frequency

[Locomotion & gait](/SYSTEMS/locomotion-and-gait.md#personality-modulation)
ships (as design) a body-bob amplitude scalar of 0.7× (low energy) to 1.5×
(high energy) for its walk-cycle torso coupling. That range is exactly
`0.7 + energy × 0.8` — the same linear form as `PersonalityFilter
.walkSpeed`'s `0.6 + energy × 0.8` above, just re-based 0.1 higher. Stated
here as the formula, not just the endpoints, so a future tuning pass keeps
the curve linear rather than re-fitting new endpoints in isolation:

```
gaitAmplitudeScalar = 0.7 + energy × 0.8   // 0.7x .. 1.5x
```

[Play bouts](/SYSTEMS/play-bouts.md#2-the-play-pressure-meter--designed-not-built)
designs a play-pressure-driven bout cap of "~1 per 15–20 min,
personality-`energy`-weighted" without stating the curve. This concept
supplies it, using the same energetic-creatures-more-often direction as
`AttractionScorer`'s `chasing`/`batting_toy` affinities above:

```
boutCapMinutes = 20 − energy × 5   // 20min (calm) .. 15min (hyperactive)
```

## Discipline → Stride Regularity, Grooming Thoroughness, Wind-Down Punctuality

**Stride regularity** — see the flagged discrepancy above: locomotion &
gait's proposed 0%–±12% per-stride jitter range does not match the
shipped generic `jitterRange` (±3%–±20%). This concept does not adjudicate
which number wins (that's a build-time decision for whoever ships the gait
engine); it flags the two live, disagreeing candidates.

**Grooming thoroughness** — Discipline drives grooming thoroughness via
the `beatCount` formula owned by
[emotional body language](/SYSTEMS/emotional-body-language.md#discipline-modulation)'s
Grooming Chain (1 beat chaotic, up to 4, with a 5th "flank" beat gated at
`discipline > 0.8` specifically). This concept does not restate the exact
formula — see that concept's Discipline Modulation section for the
literal derivation; ownership of both the formula and the grooming
*chain* itself stays there.

**Wind-down punctuality** — [idle life & rest](/SYSTEMS/idle-life-and-rest.md#8-evening-wind-down-ritual)
states that "High-Discipline creatures run [the wind-down ritual] within
the same 10-minute real-clock window nightly" via a "Discipline-scaled
jitter band," without giving the band's low-discipline end. This concept
supplies the missing half, anchored on that concept's stated 10-minute
high-discipline figure:

```
windDownJitterBandMinutes = 10 + (1 − discipline) × 50   // 10min (disciplined) .. 60min (chaotic)
```

## Focus → Whiff Rate & Stalk Patience

**Whiff rate** — [hunt & pounce](/SYSTEMS/hunt-and-pounce.md#2b-the-whiff-outcome-table)
already fully specifies this as a three-band threshold table keyed
directly off the raw Focus value (`<0.3` face-plant, `0.3–0.7` overshoot
tumble, `>0.7` whiff-spin) rather than a continuous curve — cited here as
the canon; no re-derivation needed, since a named-outcome selector reads
better as bands than as an interpolated scalar.

**Stalk patience** — that same concept states Critter-baseline stalk
freezes run "300-800ms" without tying the range to Focus explicitly. This
concept supplies the tie, using the stated range as the formula's
endpoints (0.0 scattered → shortest patience, 1.0 deliberate → longest):

```
stalkFreezeDurationMs = 300 + focus × 500   // 300ms (scattered) .. 800ms (deliberate)
```

## Valence × Arousal: The Shared Mood Coordinate

[Emotional body language](/SYSTEMS/emotional-body-language.md#1-posture-vocabulary--valencearousal-to-body-shape)
defines and uses this collapse of the four `EmotionalState` axes into a
2D mood coordinate, noting at the time of its authoring that "no code
defines a valence/arousal collapse today" and that it was the first
concept to need one. Ratified here as the shared coordinate any future
mood-driven feature should read rather than re-deriving its own average:

```
valence = clamp(((satisfaction - 50) + (contentment - 50)) / 100, -1, 1)
arousal = clamp(((energy - 50) + (curiosity - 50)) / 100, -1, 1)
```

Both terms are symmetric averages of two 0–50-centered axis deltas, so
`valence = 0, arousal = 0` is the exact neutral midpoint every emotional
axis decays toward — consistent with [the emotional
axes](#emotional-state-4-axes) table above. `emotional-body-language.md`
remains the owner of every *consumer* of this coordinate (the Posture
Vocabulary deltas, the zone table, the Sage arousal-damping override);
this concept owns only the collapse formula itself, so a second feature
needing valence/arousal reads it from here rather than reinventing the
(satisfaction+contentment)/(energy+curiosity) pairing independently.

# Boldness — A Derived Axis (Energy × Focus)

Three Phase-2 concepts — [emotional body
language](/SYSTEMS/emotional-body-language.md#boldness-scaling) (Arch
Grammar cascade amplitude/duration), [environment
reactions](/SYSTEMS/environment-reactions.md#1-sky-theater-reflex) (Sky
Theater's stage-fixed "bold" chase-harder/stand-tall variants, currently
locked to Beast pending this derivation), and that same concept's weather
front handling (shelter-seeker vs. bold trot-out-to-meet-it) — all consume
a `boldness` signal the dossier describes as "derived from personality
Energy/Focus," and all three, code-verified, confirm **no such axis
exists** on the shipped 5-axis `Personality` model
(`Creature/PersonalitySystem.swift:89-128`: energy, verbosity, focus,
discipline, specialty — no sixth field, no `boldness` column in the
`creature` table's `*_axis` set).

This concept is boldness's authoritative definition: a **derived value**,
computed at read time from the two existing axes the dossier names, never
persisted as its own column (matching the treatment `PersonalityFilter`
already gives every other cross-axis compound like `modulatedWalkSpeed`):

```
boldness = clamp(0.6 × energy + 0.4 × focus, 0.0, 1.0)
```

**Why these weights and this sign:** Energy is the primary driver (a
hyperactive creature acts rather than freezes) and gets the larger 0.6
weight; Focus contributes positively too, not inversely — a deliberate,
examining creature (`Creature/PersonalitySystem.swift:97`, "sits in one
spot, deep examiner") reads as *composed* under sudden stimuli, not
skittish, which is the same unflappability [the Sage-stage narrative
already establishes structurally](/SYSTEMS/environment-reactions.md#1-sky-theater-reflex)
("Sage sits facing it in the open, unbothered") — this formula makes that
same *personality* trait available at every stage, not just Sage. A
neutral creature (`Personality.neutral`, all axes 0.5) computes
`boldness = 0.5`, the exact midpoint, consistent with every other derived
default in this document.

| `boldness` | Band | Startle cascade ([emotional body language](/SYSTEMS/emotional-body-language.md#3-arch-grammar--one-render-two-affects)) | Weather-front response ([environment reactions](/SYSTEMS/environment-reactions.md#3-weather-on-the-horizon)) | Eclipse reaction ([environment reactions](/SYSTEMS/environment-reactions.md#1-sky-theater-reflex)) |
|---|---|---|---|---|
| < 0.35 | Cautious | Full cascade, no amplitude reduction | Shelter-seeking (full sequence) | `crouch` + full 1.08 `xScale` puff, held the full 20s |
| 0.35 – 0.65 | Neutral (default) | Standard cascade — today's shipped amplitude/timing, unmodified | Shelter-seeking — the universal default that concept ships until this landed | `crouch` (today's shipped default reaction) |
| > 0.65 | Bold | Reduced cascade — ear-flick + brief hump only, skips the freeze/recovery beats | Trots toward the front to meet it, per that concept's Beast-only row generalized | Stands tall (`yScale` 1.05) instead of crouching — the same variant [Beast already gets unconditionally](/SYSTEMS/environment-reactions.md#1-sky-theater-reflex); this table makes it a boldness gate usable at any stage rather than a stage lock |

The consuming concepts retain their own amplitude/duration scalar
mechanics (this doc supplies the 0–1 input and the three named decision
bands, not the render-side tuning); the Beast-only "bold" row those two
concepts currently ship as a stage-fixed placeholder is a reasonable
default for a bold-*leaning* stage, but should generalize to this table's
threshold once boldness is wired, rather than remain a stage lock forever.

# Bond Tier — A Derived Stat (Pet-Streak + Milestones + Days-Known)

[Companionship rituals](/SYSTEMS/companionship-rituals.md#the-bond-tier)
originated this metric — five of its six rituals key off it — and
explicitly flagged that this concept had not yet picked it up as of that
wave's authoring, asking that the formula be "promoted verbatim... rather
than re-derived independently." [Idle life &
rest](/SYSTEMS/idle-life-and-rest.md#4-sleep-geography) independently
consumes the same New/Familiar/Devoted labels for Sleep Geography, citing
this concept as the pending owner. Both are satisfied by ratifying the
formula as originally specified, unchanged:

```
bondScore = min(1.0, streakDays / 14.0)
          + min(1.0, milestonesUnlocked / 6.0)
          + min(1.0, daysKnown / 30.0)
// range 0.0 - 3.0
```

| Input | Source | Citation |
|---|---|---|
| Pet-streak days | `PetStreak.streakDays`, persisted `creature.streak_days` | `Input/PetStreak.swift:30`, `Input/CreatureTouchHandler.swift:26,91` |
| Touch milestones unlocked | Count of `MilestoneID` cases with `earned_at` set | `Input/MilestoneTracker.swift:12-21` — 9 cases total (`firstTouch`, `fingerTrail`, `petting`, `laserPointer`, `firstMiniGame`, `bellyRub`, `preContactPurr`, `touchMastery`, `gentleWake`); the formula's `/6.0` denominator is a deliberate design choice requiring only two-thirds of the roster to saturate this term, not an error against the 9-case count |
| Days known | `Date().timeIntervalSince(creature.created_at)` | `creature.created_at`, [state database schema](/DATA_MODELS/state-database-schema.md) — computed at read time, not a stored field |

| Tier | `bondScore` | Label |
|---|---|---|
| 0 | 0.0 – 1.0 | New |
| 1 | 1.0 – 2.2 | Familiar |
| 2 | 2.2 – 3.0 | Devoted |

The three inputs are deliberately uncorrelated by design (a human who
touches constantly on day one is still New off a near-zero days-known
term; a human who returns daily for a month without ever petting still
climbs to Familiar off streak + days alone) — this concept ratifies that
independence as intentional, not an oversight to fix. No storage column
exists for `bondScore` or a tier enum today; it is computed on demand from
the three already-persisted/derivable inputs above, the same treatment
[boldness](#boldness--a-derived-axis-energy--focus) gets.

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
[10] `Pushling/Sources/Pushling/Creature/PersonalityFilter.swift` (full file — shipped axis→motion modulation library: `walkSpeed`, `walkDuration`, `idleDuration`, `behaviorCooldown`, `directionChangeProbability`, `jitterRange`/`applyJitter`, `blinkInterval`, `tailSwayAmplitude`/`tailSwayPeriod`, `reactionExpressiveness`, `earMovementFrequency`, `animationTempo`, `reflexSnapDuration`, `modulatedWalkSpeed`, `visualModifiers`)
[11] `Pushling/Sources/Pushling/World/AttractionScorer.swift` (`personalityAffinities:55-70`, `categoryBaseWeights:43-52`, scoring formula `:180-189`)
[12] `Pushling/Sources/Pushling/Input/PetStreak.swift` (`streakDays:30`), `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (`petStreak:26,91`) — bond-tier pet-streak input
[13] `Pushling/Sources/Pushling/Input/MilestoneTracker.swift` (`MilestoneID:12-21`, thresholds `:26-33`) — bond-tier milestone input
[14] `docs/DATA_MODELS/state-database-schema.md` (`creature.created_at`) — bond-tier days-known input
[15] `docs/SYSTEMS/companionship-rituals.md` (bond-tier formula origin, ratified verbatim), `docs/SYSTEMS/idle-life-and-rest.md` (bond-tier co-consumer, Sleep Geography)
[16] `docs/SYSTEMS/emotional-body-language.md` (valence×arousal collapse origin, ratified verbatim; boldness-scaling and grooming Discipline-modulation consumers), `docs/SYSTEMS/environment-reactions.md` (boldness consumer, chase-vs-hide/shelter-seeking), `docs/SYSTEMS/locomotion-and-gait.md` (Personality Modulation table, gait-amplitude/stride-jitter consumer), `docs/SYSTEMS/hunt-and-pounce.md` (Focus-gated whiff outcomes, stalk-freeze range), `docs/SYSTEMS/play-bouts.md` (play-pressure bout-cap consumer)
[17] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (personality-emotional-state deepening spec: axis→motion modulation tables, boldness derivation, bond-tier), `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds` (code-reality baseline)
