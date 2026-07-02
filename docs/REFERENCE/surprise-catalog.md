---
type: Reference
title: Surprise & Delight Catalog
description: The full 78-surprise catalog across 8 categories, the scheduling/cooldown/drought model that fires them, cross-system surprise integration, and the 10 mutation badges.
status: Live
tags: [surprise, delight, mutation-badges, scheduling]
timestamp: 2026-07-02T00:00:00Z
---

Pushling's moment-to-moment charm comes from a large, weighted-random
catalog of small unscripted moments layered on top of the behavior stack —
[the behavior stack](/SYSTEMS/behavior-stack.md) governs what the creature
is *doing*; this concept governs what occasionally *interrupts* that with
something delightful. It also owns the 10 hidden mutation badges, which
share the same "long-term pattern in git/touch history → permanent visual +
behavior change" shape as a surprise, but never decay or re-fire once
earned.

# The Catalog: 78 Surprises Across 8 Categories

**Verified exactly 78** — `PUSHLING_VISION.md`'s header count is correct,
confirmed by a definition-count audit of each category source file under
`Pushling/Sources/Pushling/Surprise/`:

| Category | File | Count | Doc Range |
|---|---|---|---|
| Visual | `VisualSurprises.swift` | 12 | 1–12 |
| Contextual | `ContextualSurprises.swift` | 14 | 13–26 |
| Cat-specific | `CatSurprises.swift` | 16 | 27–42 |
| Milestone | `MilestoneSurprises.swift` | 6 | 43–48 |
| Time-based | `TimeSurprises.swift` | 9 | 49–57 |
| Easter eggs | `EasterEggSurprises.swift` | 9 | 58–66 |
| Hook-aware | `HookSurprises.swift` | 6 | 67–72 |
| Collaborative | `CollaborativeSurprises.swift` | 6 | 73–78 |
| **Total** | | **78** | |

`SurpriseRegistry.registerAll(into:)` registers exactly these 8 arrays,
in this order, into the `SurpriseScheduler`. Each of the 78 individual
surprise names/behaviors matches `PUSHLING_VISION.md`'s numbered list
(Sneeze, Chase, Handstand, ... through The Duet, Co-Discovery, Gift
Return, Group Nap, Simultaneous touch, Teaching moment) — this concept
does not re-list all 78 by name; the vision doc's numbered list (lines
1259–1351) is the canonical enumeration and is preserved there.

# Scheduling

`SurpriseScheduler.swift` (constants cited inline, all confirmed against
source, all matching the vision doc):

- **Check interval**: every 30 seconds (`checkIntervalSeconds`).
- **Base fire probability**: 0.02 per check (`baseFireProbability`) —
  roughly consistent with the vision doc's "2-3 surprises per hour of
  active use" once cooldowns and eligibility filtering are accounted for.
- **Global cooldown**: 5 minutes between any two surprises
  (`globalCooldownSeconds = 300`).
- **Per-category cooldown**: 15 minutes between same-category surprises
  (`categoryCooldownSeconds = 900`).
- **Drought bonus**: after 2 hours with no surprise
  (`droughtThresholdSeconds = 7200`), the fire probability is boosted (a
  never-yet-fired creature also gets a mild bonus).
- **Milestone suppression**: a milestone-category surprise suppresses all
  others for 5 minutes (`milestoneSuppressSeconds = 300`) so a big moment
  isn't immediately stepped on.
- **Recency penalty**: a surprise that fired in the last hour has its
  selection weight halved (`weight *= 0.5` in the weighted-random
  selector) — matches the vision doc's "50% reduced probability" claim
  exactly.

Selection is weighted random among eligible (stage-gated, cooldown-clear,
context-matched) surprises, with the drought multiplier additionally
biasing weight upward once active.

# Cross-System Surprise Integration

Creation systems unlock surprise variants, per the vision doc: a placed
campfire enables "campfire stories," a Signature-mastery taught behavior
becomes eligible to fire as a surprise, and a strong preference (≥0.8)
modifies related surprises (a rain-loving creature gets "rain zoomies"
during storms instead of the standard zoomies surprise). This wave did not
independently re-verify each of these three cross-system hooks against a
named implementation (they were out of the direct `codeChecks` list) —
preserved as documented behavior, not contradicted.

# Mutation Badges (Hidden Achievements)

**Fully implemented and matching the vision doc exactly** —
`MutationSystem.swift`'s `MutationBadge` enum has 10 cases with
`displayName`, visual description, and behavior-change description that
correspond 1:1 to the vision doc's Mutation Badges table:

| Badge | Trigger (code-verified) | Visual | Behavior Change |
|---|---|---|---|
| **Nocturne** | 50+ commits between midnight–5AM | Moon glow aura | 1.2x speed 10PM–6AM |
| **Polyglot** | 8+ unique file extensions in a 7-day window | Color-shifting/heterochromatic fur | Heterochromatic eyes |
| **Marathon** | 14-day consecutive commit streak | Flame trail | Permanent trail, slightly faster walk |
| **Archaeologist** | Commit touches a 2yr+ old file | Pickaxe mark on left ear | More frequent dig surprises |
| **Guardian** | 20+ commits touching test files | Shield flash on commit eat | +5% test-commit XP |
| **Swarm** | 30+ commits in a single day | Buzzing particle orbit | 24hr electric aura |
| **Whisperer** | All commit messages >50 chars for 7 consecutive days | Scroll mark on right side | Quotes commit messages 2x more |
| **First Light** | Any single commit before 6AM | Sunrise mark on forehead | Enthusiastic morning routine |
| **Nine Lives** | Daemon recovers from crash 9 times | Faint halo | Dramatic resurrection animation |
| **Bilingual** | 2+ language categories each ≥30% share in a 30-day window | Split-color tail | Alternates visual style between languages |

All 10 trigger thresholds are read directly from
`MutationSystem.checkBadgeCondition`/`shouldCheck` and match the vision
doc's numbers precisely (50 commits, 8 extensions, 14 days, 20 commits, 30
commits/day, 7 days, 9 crashes). Badges are earned once, permanently
(`awardBadge` is idempotent via `earnedBadges.contains`), with no decay —
distinct from the strength/decay model used elsewhere in the creation
systems (see [the nurture system](/SYSTEMS/nurture-system.md)).

**A second, unrelated 10-ID list exists in the schema and should not be
confused with the above.** `Schema.milestoneSeedData`
(`Schema.swift:472-483`) seeds 10 rows into the `milestones` table at
migration time with IDs `nocturne, polyglot, marathon, surgeon, architect,
gardener, phoenix, librarian, speedrunner, hermit` — only the first three
match `MutationBadge`'s real raw values (`nocturne`, `polyglot`,
`marathon`); the remaining 7 IDs (`surgeon` through `hermit`) do not
correspond to any `MutationBadge` case and have **no trigger-checking
logic anywhere in the codebase** (repo-wide search found zero references
outside the seed array and its migration insert). This resolves the
survey's PHASE-8 drift signal ("only 3 of 10 match") definitively: the
live, working mutation system is `MutationSystem.swift`'s 10-badge enum
above; `milestoneSeedData`'s 7 non-matching IDs are dead seed rows from an
abandoned earlier naming scheme, not a second live badge set. Flagged for
the Orchestrator as a cleanup item (6-lens "dead code" lens) — the 7 orphan
rows in `milestoneSeedData` could be removed or reconciled to the real
`MutationBadge` raw values without any behavior change, since nothing
reads them by those names.

# Schema

`surprises` table (`Schema.swift:333-346`): one row per registered
surprise, `category` CHECK-constrained to the 8 category names above
(`visual, contextual, cat, milestone, time, easter_egg, hook_aware,
collaborative`), tracking `last_fired_at`, `fire_count`, `cooldown_until`,
`enabled`. `milestones` table (`Schema.swift:348-359`): `category` CHECK
(`evolution, mutation, touch, commit, surprise, speech`), `data_json`,
`ceremony_played` — this is where both the real `MutationBadge` awards and
the orphaned `milestoneSeedData` rows live side by side.

# Citations

[1] `Pushling/Sources/Pushling/Surprise/SurpriseRegistry.swift` (registration order, 78-count log line)
[2] `Pushling/Sources/Pushling/Surprise/VisualSurprises.swift`, `ContextualSurprises.swift`, `CatSurprises.swift`, `MilestoneSurprises.swift`, `TimeSurprises.swift`, `EasterEggSurprises.swift`, `HookSurprises.swift`, `CollaborativeSurprises.swift` (per-category definition counts: 12/14/16/6/9/9/6/6)
[3] `Pushling/Sources/Pushling/Surprise/SurpriseScheduler.swift` (all scheduling constants)
[4] `Pushling/Sources/Pushling/Creature/MutationSystem.swift` (`MutationBadge` enum, triggers, visuals)
[5] `Pushling/Sources/Pushling/State/Schema.swift` (`surprises`, `milestones` tables, `milestoneSeedData`)
[6] `Pushling/Sources/Pushling/State/Migration.swift` (`milestoneSeedData` insertion)
[7] `PUSHLING_VISION.md` — The Surprise & Delight System; Mutation Badges
