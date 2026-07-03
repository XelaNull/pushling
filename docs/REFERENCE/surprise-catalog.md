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
in this order, into the `SurpriseScheduler`. The full 78, by category, name,
and design (restored verbatim from `PUSHLING_VISION.md` lines 1267–1359,
names cross-checked against the per-category `.swift` files above):

**Visual — creature does something unexpected (1–12):**

1. **Sneeze** — nearby terrain scatters. Ears flatten from the force. Common.
2. **Chase** — tiny mouse NPC appears, creature stalks and chases it across the bar. Tail low, predator mode.
3. **Handstand** — Beast+ physical comedy. Overbalances, tumbles.
4. **Prank** — hides behind terrain, peeks out: `"boo!"` Waits for reaction.
5. **Belly flop** — Drop-only pratfall. Still learning to use legs.
6. **Shadow play** — creature's shadow detaches and walks independently. Creature notices, does a double-take.
7. **Puddle discovery** — finds puddle, sees reflection, tilts head. Paws at it. Reflection ripples.
8. **Dust bunny** — discovers a tiny dust bunny NPC. Adopts it. It follows for 5 minutes then dissolves.
9. **Invisible barrier** — mimes walking into glass. Paws at air. Confused. Walks around.
10. **Clone** — briefly splits into two creatures. They look at each other, one dissolves. `"...huh."`
11. **Tiny trumpet** — produces a tiny trumpet from nowhere, plays a 3-note fanfare, puts it away. Looks proud.
12. **Gravity flip** — walks on the "ceiling" of the Touch Bar for 10 seconds. Acts like nothing is wrong.

**Contextual — reacts to something real (13–26):**

13. **Branch commentary** — reads your branch name. `hotfix*` → ears flatten, `"urgent!"`; `yolo*` → `"...brave"`; `feature*` → `"ooh, new!"`; `main` → respectful nod.
14. **Time awareness** — Friday 5PM: `"FRIDAY!"` + zoomies. Monday 9AM: `"...monday"` + slow walk. Wednesday: `"halfway"`. End of month: `"already?"`
15. **Commit echo** — 30–120min after a commit, quietly quotes your message in a thought bubble. Like it's still thinking about it.
16. **Language preference** — develops favorites and reacts: `"YES! .php!"` ♡ or `"ugh .yaml"` + reluctant eating.
17. **Streak celebration** — 7d: `"WEEK!"` + party hat. 14d: `"TWO WEEKS!!"` + confetti. 30d: `"LEGENDARY!!!"` + fireworks. 100d: transcendent light show.
18. **Typing rhythm mirror** — walks in tempo with your keystrokes. Fast typing = trot. Slow typing = lazy walk. Paused = sits and waits.
19. **File type commentary** — opens a CSS file: creature preens. Opens test file: creature flexes. Opens package.json: concerned expression. Opens .env: looks away pointedly.
20. **Long function detector** — if a commit has a function >100 lines: creature looks exhausted just from reading it.
21. **Merge day** — multiple merge commits in a day: creature wears a tiny hard hat.
22. **Dependency update** — `package.json` or `Cargo.toml` changes: creature examines a wobbly tower of blocks.
23. **README editing** — creature produces tiny glasses, reads along.
24. **Branch switching** — creature briefly looks dizzy when the user switches branches rapidly.
25. **Conflict resolution** — merge conflict commits: creature mimes being a mediator between two invisible parties.
26. **Test coverage** — commit adds tests to untested file: creature gives a thumbs-up (paw up).

**Cat-specific behaviors (27–42):**

27. **Zoomies** — sudden burst of speed across the entire bar and back. No warning. No reason. Cat.
28. **Knocking things off** — deliberately pushes a terrain object to the edge, looks at camera, pushes it off. Watches it fall.
29. **If-I-fits-I-sits** — finds the smallest gap between terrain objects, squeezes in, looks extremely satisfied.
30. **Tail chasing** — notices own tail, chases it in circles. 3–5 rotations. Catches it. Lets go. Pretends nothing happened.
31. **Chattering** — a bird or insect particle flies overhead. Jaw vibrates rapidly. Intense focus. Prey drive activated.
32. **Kneading session** — finds a soft spot, kneads for 10 seconds with increasing contentment. Purr particles intensify.
33. **The loaf** — tucks all paws, becomes a perfect rectangle. Stays loafed for 30–60 seconds. Looks smug.
34. **Head in box** — if a `cardboard_box` object exists, sticks head inside. Tail sticks out. Doesn't move for 10 seconds.
35. **Gift delivery** — catches a mouse NPC, brings it to the edge of the screen (toward the user), drops it. Looks expectant. `"for you."`
36. **Butt wiggle** — sees something interesting, drops into hunt position, wiggles butt. Pounces. Whether there was anything there or not.
37. **Whisker twitch** — both whiskers twitch in sequence. Looking at something only it can see.
38. **Slow roll** — while being petted, slowly rolls onto back, exposing belly. TRAP: tapping belly makes it grab with all four paws and kick.
39. **Perching** — jumps on top of the tallest nearby terrain object. Surveys domain. Tail hangs down.
40. **Bread-making** — rhythmic kneading that produces tiny bread sprites. Ridiculous but charming.
41. **Midnight crazies** — between 11PM–2AM, brief intense burst of energy. Runs, jumps, slides, stops. Stares at nothing. Runs again.
42. **Tongue blep** — tongue sticks out by 1 pixel. Stays out. Creature doesn't notice.

**Milestone (43–48):**

43. **New repo discovery** — `"NEW WORLD!"` with repo name scrolling. New landmark forms on skyline. Creature runs to look at it.
44. **Commit #100/500/1000/5000** — fireworks. Increasingly rare, increasingly dramatic. #1000 gets full-screen aurora.
45. **Evolution ceremony** — the biggest event. 5-second spectacle (see [growth stages](/REFERENCE/growth-stages.md#stage-transition-ceremony)).
46. **First mutation** — badge shimmers into existence above creature. Creature examines it curiously.
47. **First word** — Critter says its own name (see [speech milestones](/REFERENCE/speech-milestones.md)). Milestone notification.
48. **100th unique file type** — `"I've tasted everything..."` + comprehensive food review of top 5 file types.

**Time-based (49–57):**

49. **New Year's** — fireworks + party hat. Creature stays up till midnight, counts down.
50. **Halloween** — random costume (witch hat, ghost sheet, pumpkin). Spooky terrain palette. Bats in sky.
51. **Pi Day** (March 14) — recites digits of pi, one per second, increasingly impressed with itself. Gets to ~20 digits, mind blown.
52. **Creature birthday** — anniversary of first install. Compressed life playback montage. Tiny cake with candles = years.
53. **Solstice/Equinox** — seasonal transitions. Summer solstice: longest day, creature basks. Winter solstice: huddles near campfire.
54. **Friday the 13th** — everything slightly glitchy. Creature looks nervous. Objects slightly misaligned. Resolves at midnight.
55. **Leap year day** — Feb 29: creature gains a temporary extra life (visual ghost echo for 24 hours).
56. **Developer anniversary** — anniversary of earliest commit in any tracked repo. `"Happy code day."` Montage of first commits.
57. **Full moon** — actual lunar phase. Creature howls (tiny `"awoo"`). Extra mysterious atmosphere.

**Easter eggs (58–66):**

58. **Konami Code** — touch sequence (up up down down left right left right tap tap) unlocks victory lap with 8-bit fanfare.
59. **Source code reading** — Sage+ reads a line of its own Swift source code. Either achieves zen or has existential crisis.
60. **Fourth wall break** — Apex stares directly at camera: `"...you're watching me, aren't you?"` Holds eye contact for 5 uncomfortable seconds.
61. **Dance party** — 5 taps in 1-second rhythm = disco mode. Terrain lights up. Music note particles. 15 seconds.
62. **Commit #404** — `"COMMIT NOT F--"` … `"wait..."` … `"just kidding!"` Error page background briefly flashes.
63. **Commit message "hello world"** — creature waves at the screen. First commit ever? Extra emotional wave.
64. **Commit #1337** — `"leet"` + sunglasses cosmetic for 1 hour.
65. **The name game** — if developer types creature's name in a commit message, creature perks up: `"you said my name!"` Extra happiness.
66. **42nd commit** — `"the answer"` + brief galaxy background.

**Hook-aware — reacts to Claude's work (67–72):**

67. **Tool chain watching** — during long Claude tool chains (5+ tools), creature watches with increasing amazement. After 10+: standing ovation.
68. **Test runner** — Claude runs tests via Bash: creature tenses. Pass: celebratory flex. Fail: supportive pat on own back.
69. **Build watcher** — Claude triggers a build: creature watches intently. Success: proud nod. Failure: comforting expression.
70. **Subagent awe** — when diamond splits into 3+ subagents: creature's jaw drops. `"there's more of you?!"`
71. **Context compact sympathy** — on PostCompact, creature and Claude share the disorientation. Creature pats own head.
72. **Long session appreciation** — after Claude session >2 hours: creature brings Claude's diamond a tiny coffee cup.

**Collaborative — AI + human together (73–78):**

73. **The Duet** — AI sings + human taps in rhythm = three-part harmony. Terrain lights up with musical visualization.
74. **Co-Discovery** — AI describes a file + human commits to it within 5min = `"TEAMWORK!"` Special co-presence aura.
75. **Gift Return** — AI places gift + human pets creature within 30sec = creature re-gifts to human (pushes toward screen edge).
76. **Group Nap** — late night, AI connected, no typing for 5min = everyone falls asleep together. Diamond dims. Creature curls up. Synchronized breathing.
77. **Simultaneous touch** — human touches creature at exact moment Claude issues a move command: creature glows with dual-presence energy. Rare, special.
78. **Teaching moment** — Claude performs a trick, human double-taps within 2s: creature does the trick back. Triangle of interaction.

This wave did not independently re-verify each of the 78 individual behavior
bodies against its `.swift` implementation line-by-line (only the per-category
counts and registration order above are code-checked); the design/dialogue
text above is the vision doc's own words, preserved as the prescriptive
design for what each numbered surprise *is*.

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
