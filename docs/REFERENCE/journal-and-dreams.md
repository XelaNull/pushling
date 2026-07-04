---
type: Reference
title: Journal & Dreams
description: The 18-type journal entry taxonomy that records every meaningful event, the two distinct dream mechanics (wake-time speech-fragment bubble + autonomous nightly DreamEngine with personality drift), the Dream Theater somatic-twitch bridge from DreamEngine's real git-activity content, and the type-registry decision for seven new Phase-2 journal moments.
status: Live
tags: [journal, dreams, memory]
timestamp: 2026-07-03T00:00:00Z
---

Every meaningful event in the creature's life is written to a single
`journal` table, queried by `pushling_recall`'s filters (see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md) for the filter
list). This concept owns the entry-type taxonomy and the two dream
mechanics; it does not own recall's filter semantics or XP/commit
mechanics (see [commit feeding & XP](/SYSTEMS/commit-feeding-xp.md)).

# Journal Entry Types

**18 types**, per the live `journal.type` CHECK constraint
(`Schema.swift:142-147`) — 4 more than `PUSHLING_VISION.md`'s 14-entry
table, because the vision doc predates the creation systems (its last
substantive edit was 2026-03-23; `teach`/`nurture`/`world_change` and the
`ai_perform` tool all shipped after):

| Type | Example | In Vision Doc? |
|---|---|---|
| `commit` | "refactor auth" +7xp, pounced, ate 18 chars in 2.7s | yes |
| `touch` | Sustained touch 4s, purred, chin-scratch | yes |
| `ai_speech` | Claude spoke "good morning," filtered to "morning!" | yes |
| `failed_speech` | Intended text exceeded the stage's char budget | yes |
| `ai_move` | Claude directed creature to center, walk speed | yes |
| `ai_express` | Claude expressed joy at intensity 0.8 for 3s | yes |
| `ai_perform` | A `pushling_perform` call executed | **no** — newer than the vision doc |
| `surprise` | #27 Zoomies triggered at 14:23 | yes |
| `evolve` | Drop → Critter, ceremony played | yes |
| `first_word` | Creature said its own name unprompted | yes |
| `dream` | Nightly `DreamEngine` summary, or a wake-time fragment | yes |
| `discovery` | New repo landmark discovered | yes |
| `mutation` | A `MutationBadge` earned | yes |
| `hook` | A Claude Code hook fired | yes |
| `session` | Claude session started/ended | yes |
| `teach` | A trick composed/committed (see [the teach system](/SYSTEMS/teach-system.md)) | **no** |
| `nurture` | A habit/preference/quirk/routine/identity change | **no** |
| `world_change` | Weather, event, object, or companion change | **no** |

**Known gap, code-verified this wave: session-lifecycle journal writes
already violate this CHECK constraint.** `SessionLifecycleReactions.swift`
calls `onJournalEntry?("session_start", …)` (line 176) and
`onJournalEntry?("session_end", …)` (line 273) — but the CHECK constraint
above allows only the bare `session` value, not `session_start`/
`session_end`. The closure chain routes straight to a raw `INSERT INTO
journal (type, …)` with `type` passed through unchanged
(`PushlingScene.swift:549-558`), inside `performWriteAsync` with no
completion handler supplied — so every session start and every session end
throws a SQLite CHECK-constraint error that's swallowed to an `NSLog` line
(`DatabaseManager.swift:297-308`) and never surfaces anywhere else. In
practice: **no session-boundary journal row has ever been successfully
written**, silently, since this shipped. This also means the "session"
type's own vision-doc description ("Claude session started/ended") is
aspirational, not actually populated by that code path today.
[`mcp-session-lifecycle.md`](/ARCHITECTURE/mcp-session-lifecycle.md#reconnection)
documents `session_start`/`session_end` as if they were live journal types
without registering this mismatch — flagged here as the type-registry
owner; the fix is a one-line schema change (add `session_start`,
`session_end` to the CHECK list, `Schema.swift:142-147`) or a one-line code
change (pass `"session"` instead of the two granular strings), not resolved
in this pass.

# Two Distinct Dream Mechanics

The vision doc describes one "Dream Journal" mechanic; the running code has
**two**, coexisting and serving different moments:

## 1. Wake-Time Dream Bubble (matches the vision doc)

`SpeechCoordinator.showDreamBubble()` — triggered from `PushlingScene`'s
wake-up path — pulls a cached prior utterance via `SpeechCache.dreamUtterance()`,
extracts a 1–3 word fragment via `SpeechCache.dreamFragment(from:)`, and
renders it as a dusk-colored, wavy, low-opacity dream-style speech bubble.
This is the literal "...the authentication..." mechanic the vision doc
describes, verified still present and wired to the wake animation. A related,
separately-designed mechanic — a commit arriving *while the creature is
asleep* triggering this same dream bubble with the commit message's first
word — is not wired to the commit-arrival path; see
[commit feeding & XP](/SYSTEMS/commit-feeding-xp.md#commit-while-asleep-designed-not-wired)
for the full gap detail.

## 2. Autonomous Nightly DreamEngine (undocumented in the vision doc — new)

`DreamEngine.swift` runs a full settling → dreaming → waking state machine
during actual overnight sleep, independent of the wake-bubble mechanic
above. Four gates must all pass (`checkGates`):

1. **Time of day**: current period is `.lateNight` or `.deepNight`.
2. **Energy**: emotional energy below **25.0**.
3. **Journal volume**: at least **20 unprocessed journal entries**
   since the last dream (or in the last 24h, if never dreamed).
4. **Cooldown**: at least **4 hours** since the previous dream.

Once triggered, the cycle runs **settling (10s) → dreaming (30–60s
random) → waking (5s)**, with a whisker-twitch every 10s during the
dreaming phase (a REM-like tell). At the start of the dreaming phase, it
analyzes the last 24 hours of journal rows (up to 200) and computes a
small **personality drift**, capped at **±0.02 per axis per dream**:
high commit density (>30 in-window) nudges `energy` up, heavy touch
activity (>20) nudges `verbosity` up, a run of hook-error entries (>5)
nudges `discipline` down, and a high commit-to-total ratio (>0.4) nudges
`focus` up. The drift and a pattern-selected dream summary (via
`DreamTemplates.generate(pattern:)`, 15 distinct patterns from
`.lateNightCoding` to `.noActivity`) are persisted together: `creature.last_dream_at`/`dream_count`
update, a `dream`-type journal row is inserted with the generated summary
text, and the personality drift is saved via `PersonalityPersistence`.

**This is a substantial, fully-wired system with no mention anywhere in
`PUSHLING_VISION.md`.** It is documented here fresh from code per this
migration's rule that later-built systems (this one postdates the vision
doc, alongside `HotReloadMonitor` and other CLAUDE.md-only additions) are
authored as canon directly, not forced to reconcile against a doc that
never described them.

**A related gap: mastery-weighted trick replay is designed but not wired.**
The vision doc additionally claims "mastered tricks replay during sleep at
0.5x speed with a ghostly render filter." `MasteryTracker.selectDreamBehavior()`
implements the *selection* logic (weighting Signature-tier behaviors 3x
over Mastered), but a repo-wide search found no call site for it — the
live `DreamEngine` produces text and personality drift only, it never
selects or replays a taught behavior. See
[the teach system](/SYSTEMS/teach-system.md#dream-integration-designed-not-wired)
for the full detail; noted here because it directly concerns what "dreams"
functionally do today. Preserved as intent-canon, flagged as a
defined-but-unwired gap for the Orchestrator.

# Dream Theater — Somatic Categories Mapped to DreamEngine Content

**Designed, not built.** [`idle-life-and-rest.md`](/SYSTEMS/idle-life-and-rest.md)
owns the Dream Theater feature itself — the somatic-twitch mechanism, its
channels, amplitudes, and frame budget. This concept's job, as the owner of
what DreamEngine's content actually *is*, is narrower: map that real content
onto Dream Theater's proposed somatic categories honestly, because the
dossier's own framing of that mapping does not match the shipped engine.

**The correction.** The dossier's Dream Theater pitch describes "chase
dreams paddle the front paws… hunt dreams flick tail-tip + tremble
whiskers, social dreams suckle, storm dreams shiver and tighten the curl" —
phrasing that reads as if `DreamEngine` already produces chase/hunt/social/
storm *imagery*. It does not, and never has. `DreamPattern`
(`DreamTemplates.swift:12-27`) is a 15-case **git-activity taxonomy**:
`.manyCommits(language:)`, `.lateNightCoding`, `.touchHeavy`,
`.errorStreak`, `.diverseLanguages`, `.longSession`, `.quiet`,
`.highDebugging`, `.highChaos`, `.streakBuilding`, `.shortCommits`,
`.verboseCommits`, `.multiRepo`, `.noActivity`, `.generic`. Every one of
these describes what the *developer* was doing (commit volume, touch
volume, error density, language mix, time of day) — none of them are chase,
hunt, social, or storm content in any literal sense. The four labels the
dossier uses are an evocative gloss this concept has to construct fresh,
not content already sitting in the engine waiting to be surfaced.

**A second correction, code-verified: 6 of the 15 declared patterns are
unreachable.** `DreamEngine.resolveDreamPattern` (`DreamEngine.swift:302-329`)
is a hard-coded if/return chain, checked in this exact order, that returns
on the first match: `.lateNightCoding` (hour ≥22 or <5) → `.errorStreak`
(hookErrorCount >5) → `.touchHeavy` (touchCount >20) → `.manyCommits`
(commitCount >40) → `.diverseLanguages` (>4 distinct languages) →
`.streakBuilding` (commitCount >20) → `.noActivity` (<5 total entries) →
`.quiet` (<15 total entries) → `.generic` (fallback). That is 9 reachable
cases. `.highDebugging`, `.highChaos`, `.shortCommits`, `.verboseCommits`,
`.multiRepo`, and `.longSession` all have complete template banks in
`DreamTemplates.swift` (lines 71-76, 85-125) but no branch in
`resolveDreamPattern` ever returns them — dead-but-declared code, the same
shape as this concept's own already-noted
`MasteryTracker.selectDreamBehavior()` gap above. Flagged for whoever next
touches `resolveDreamPattern`; not fixed here (no code changes in this
pass).

**The channels available today.** `DreamOutput`
(`DreamEngine.swift:23-32`) exposes `eyeState` ("open"/"closing"/"closed"),
`earState` ("neutral"/"droop"/"flat"), `tailState` ("sway"/"wrap"),
`pawState` ("ground"/"tuck"), `bodyState` ("stand"/"sleep_curl"),
`breathPeriodOverride` (nil or a slow ~5.0s override), and `whiskerTwitch`
(a bool). The one somatic tell that already ships, driving *every* dream
regardless of pattern: `whiskerTwitch` fires true for a 0.25s window every
10.0s during the `.dreaming` phase (`twitchInterval = 10.0`,
`DreamEngine.swift:172-175`) — the REM-like baseline this whole feature
builds on top of. Neither `pawState` nor `tailState` has a "paddle" or
"flick" value today; those are new content Dream Theater would add, not
values already sitting unused in the enum.

**The honest bridge** — five somatic categories, built from the real
templates' tone (not the dossier's imagery), covering all 15 `DreamPattern`
cases:

| Somatic category | `DreamPattern` case(s) | Reachable today? | Template evidence | Proposed new channel value (idle-life-and-rest.md's to build) |
|---|---|---|---|---|
| **Paddle** (fast, high-volume activity) | `.manyCommits`, `.highChaos` | `.manyCommits` yes / `.highChaos` no (dead) | "swimming in %@", "force pushes and reverts and merges… managing a lot" | `pawState: "paddle"` — new value alongside `ground`/`tuck` |
| **Flick-and-track** (searching, vigilant) | `.diverseLanguages`, `.multiRepo`, `.highDebugging` | `.diverseLanguages` yes / other two dead | "a tower with many doors", "the bug was hiding under a floorboard", "standing between several towers" | `tailState: "flick"` — new value alongside `sway`/`wrap`; whiskerTwitch already covers the "tremble" half |
| **Suckle** (bonded contentment) | `.touchHeavy`, `.streakBuilding` | both reachable | "made of warm things", "the streak grew… it felt warm" | a new `mouthState` field — none of the 7 existing `DreamOutput` fields touch the mouth |
| **Shiver-and-tighten** (mild distress) | `.errorStreak` | reachable | "I hope the human is okay", "I sat close" | `bodyState`: a tighter `sleep_curl` variant (coordinate with [body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table) before adding a new tuple) + a shortened `breathPeriodOverride` |
| **Still** (baseline REM, no differentiation) | `.lateNightCoding`, `.quiet`, `.noActivity`, `.generic`, `.shortCommits`, `.verboseCommits`, `.longSession` | mixed (4 reachable, 3 dead) | low-intensity/neutral tone across all seven | none — this is exactly what ships today (whiskerTwitch-only) |

Every category rides on top of the shared 0.25s/10s whisker baseline —
idle-life-and-rest.md's job is to layer the four differentiated categories
*onto* that baseline via new `pawState`/`tailState`/`mouthState` values and
a curl variant, not to replace it. The dead six patterns (`.highChaos`,
`.multiRepo`, `.highDebugging`, `.shortCommits`, `.verboseCommits`,
`.longSession`) are mapped above for design completeness, but since
`resolveDreamPattern` never selects them, their somatic categories are
currently moot in practice — worth noting if `resolveDreamPattern`'s dead
branches ever get wired up.

**This table is the single authority for `DreamPattern`-to-somatic-category
assignment.** [idle-life-and-rest.md's Dream Theater
section](/SYSTEMS/idle-life-and-rest.md#5-dream-theater--somatic-twitch-per-dream-pattern)
cross-links here for which pattern maps to which category rather than
carrying its own copy — it previously did, and the two had drifted apart
(the same category, e.g. `.streakBuilding`, landed in different somatic
buckets in each doc). That concept still owns the somatic-render mechanism
itself: motion shapes, amplitudes, timing, and frame budget.

# Surfacing Channels

Per the vision doc: dreams (automatic), a stats display (3-finger swipe),
memory postcards (4-finger swipe), `pushling_recall`, Sage+ idle
reminiscence, and ruin inscriptions in terrain. This wave did not
independently re-verify the memory-postcard mechanic — a prior survey pass
on a different source doc (PHASE-8) found no `postcard`/`FourFinger` hits
anywhere in `Pushling/Sources`, suggesting it may be unbuilt; flagged here
for whichever wave owns touch gestures
([touch interaction](/SYSTEMS/touch-input-pipeline.md)) to confirm.

## Sage+ Idle Reminiscence — Design Intent, Unbuilt (P8-T2-07)

`docs/archive/plan/phase-8-polish/PHASE-8.md` P8-T2-07 designs a Sage+-stage
idle behavior where the creature occasionally narrates a memory drawn from
its own journal (5% chance per idle-behavior-selection cycle, `"narrate"`
style — environmental text, no speech bubble): failed-speech recall,
growth reflection, commit memory, object nostalgia, habit reflection, and
companion memory, with an expanded Apex tier adding meta-awareness,
philosophical, and developer-directed lines. **No call site exists for
this anywhere in the codebase.** `SpeechCache.failedSpeechEntries()` — its
own doc comment reads "Retrieve failed speech entries for Sage
reminiscence" — and `SpeechCache.recentUtterances()` are both fully
implemented read paths with **zero callers** repo-wide (grep-verified);
nothing in `Behavior/` or `Speech/` selects a reminiscence category, rolls
the 5% chance, or renders the narration. This is the same
declared-but-unwired shape as the DreamEngine's unwired mastery-weighted
trick replay noted above.

A specific reminiscence line has no home in PHASE-8's six categories at
all: [the first-word milestone](/REFERENCE/speech-milestones.md#milestone-1-the-first-word-critter-own-name-visual)'s
original design (`docs/archive/CREATURE-VOICE-DESIGN.md` §10, via
[speech-milestones](/REFERENCE/speech-milestones.md#first-word-choice-what-was-considered))
specified the entry should be surfaceable through this exact mechanic with
an explicit Sage-stage line — *"...remember when I first said your
name?"* — once the creature reaches Sage. That intent has never been wired
into either the first-word write path (Milestone 1's journal entry has no
`context` field to narrate from) or this reminiscence system (no
first-word-specific category exists among the six above). Two independent
unbuilt systems would need to connect for this specific line to ever be
spoken; neither exists today.

# New Journal Moment Types (Design Intent) — the Type-Registry Decision

Seven new journal-worthy moments were proposed across this wave's
companionship, hunt, play, locomotion, and weather concepts. None have a
matching `journal.type` value in the live 18-entry CHECK constraint above,
and none have a write call site yet — each is gated on its owning
feature's own body-pose/reflex dependencies landing first. This concept
owns the taxonomy, so it makes the registry call for all seven here rather
than leaving each owning doc to invent its own type independently.

**The governing precedent, verified against shipped call sites, not
assumed:** the existing taxonomy does not mint a new CHECK value per
distinguishable event. `ai_perform` covers all 18 `pushling_perform`
actions from four call sites (`ActionHandlers.swift:363,390,414,468`), and
`world_change` covers weather/event/object/companion changes from eight
call sites (`WorldHandlers.swift`) — both differentiated purely by
`summary` text, since the shared `journalLog(gc:type:summary:)` helper
(`CreationHandlers.swift:599-610`) doesn't even take a `data` parameter.
New CHECK values were added historically (`teach`, `nurture`,
`world_change`, `ai_perform` — the 14→18 growth this doc's own table
already tracks) only for genuinely new *systems*, not new *variety within*
a system. This wave's seven moments are judged against that same bar:

| Moment | Owning concept | Registry decision | Why |
|---|---|---|---|
| Reunion (bond-tier greeting finisher) | [companionship-rituals §1](/SYSTEMS/companionship-rituals.md#1-reunion-runway--bond-weighted-greeting-choreography) | **New type: `companion`** | A genuinely new system (bond-tiered developer-relationship beats) with no honest fit among the 18 — reusing `session` would compound the CHECK-violation gap above, not just borrow it; reusing `surprise` would mix autonomous-delight moments with relationship-specific ones `pushling_recall` should be able to filter apart |
| "We saw each other" (creature-initiated glance payoff) | [companionship-rituals §5](/SYSTEMS/companionship-rituals.md#5-check-in-glances--social-referencing) | **Same new type: `companion`** | Same system, same bond-relationship shape as Reunion — the ai_perform/world_change precedent says "one type per system," and future companionship-rituals beats (Bunting, Milestone Pilgrimage) belong under this same value once built, differentiated by summary text |
| First catch | [hunt-and-pounce §3](/SYSTEMS/hunt-and-pounce.md#3-per-stage-catch-rates--pounce-profiles) | **New type: `play_memory`** | play-bouts.md itself flags this exact gap ("no `play` entry… flagged for whoever builds this" — `play-bouts.md:264-276`) and floats a `play`-shaped name; `play_memory` follows the same two-word snake_case convention as `world_change`/`first_word` and reads unambiguously in a recall filter list |
| Longest rally-class play memory | (backlogged Rebound Rally, per [play-bouts §8](/SYSTEMS/play-bouts.md#8-future-escalations-backlogged-not-this-concepts-scope)) | **Same new type: `play_memory`** | Forward-registered for whenever a rally-scoring feature lands — no need for its own value when it's the same "memorable play moment" shape as First Catch |
| Favorite farewell | [play-bouts §6](/SYSTEMS/play-bouts.md#6-the-favorite--toy-attachment--farewell) | **Same new type: `play_memory`** | Play-bouts.md's own proposed alternative was reusing `world_change` for this — rejected here: a toy's emotional farewell is a play/attachment event, not a world-state change, and burying it under `world_change` would make it unfindable alongside weather/object noise |
| Childhood Echo | [locomotion-and-gait §"The Childhood Echo"](/SYSTEMS/locomotion-and-gait.md#the-childhood-echo) | **Reuse existing type: `evolve`** | Locomotion-and-gait.md already calls this "journal-logged as a distinct moment type" without picking one; a Childhood Echo is the temporal inverse of an evolution (a brief, nostalgic reversion to a younger stage's gait vs. a permanent stage-up) — grouping both under `evolve` keeps every stage-identity journal moment under one filterable value, differentiated by summary text ("...briefly wobbled like an Egg again" vs. "Drop → Critter, ceremony played") rather than minting a 19th/20th value for a feature that "fires at most once per session" |
| Watched a storm roll in | [environment-reactions §3](/SYSTEMS/environment-reactions.md#3-weather-on-the-horizon) | **Reuse existing type: `world_change`** | This type's own definition already names "Weather" explicitly (see the table above) — the sense-beat/shelter-seeking reaction is the creature's authored response alongside the exact weather transition `world_change` already logs from `WorldHandlers.swift`; no gap to fill |

**Net schema impact, if/when built:** two new CHECK values (`companion`,
`play_memory`) — an 18→20 growth, the same shape as the 14→18 growth this
doc's entry-type table already documents — plus two new summary-string
conventions layered onto the existing `evolve`/`world_change` values. This
is a one-line schema migration (`Schema.swift:142-147`) whenever the first
of the two new types' owning features actually lands; not resolved in this
doc-only pass, and not blocking any of this wave's six sibling concepts,
which can cite this table today and defer the schema edit to their own
build.

# Citations

[1] `Pushling/Sources/Pushling/State/Schema.swift` (`journal` table CHECK constraint, lines 138-152)
[2] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift` (`showDreamBubble`)
[3] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (wake → `showDreamBubble` call site)
[4] `Pushling/Sources/Pushling/Behavior/DreamEngine.swift` (gates, phase machine, personality drift, persistence)
[5] `Pushling/Sources/Pushling/Behavior/DreamTemplates.swift` (`DreamPattern`, `generate`)
[6] `Pushling/Sources/Pushling/App/GameCoordinator+DreamEngine.swift` (wiring into `AutonomousLayer`)
[7] `Pushling/Sources/Pushling/Behavior/MasteryTracker.swift` (`selectDreamBehavior` — unwired)
[8] `PUSHLING_VISION.md` — The Journal; Dream Journal; sleep/dream mentions in Core Loop
[9] `Pushling/Sources/Pushling/IPC/SessionLifecycleReactions.swift` (`onJournalEntry?("session_start"/"session_end", …)` calls, lines 176, 273 — CHECK-constraint mismatch)
[10] `Pushling/Sources/Pushling/State/DatabaseManager.swift` (`performWriteAsync`, lines 297-308 — swallowed write errors)
[11] `Pushling/Sources/Pushling/IPC/CreationHandlers.swift` (`journalLog(gc:type:summary:)` helper, lines 599-610 — no `data` parameter)
[12] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift` / `WorldHandlers.swift` (`ai_perform`/`world_change` multi-call-site precedent for the type registry)
[13] `docs/ARCHITECTURE/mcp-session-lifecycle.md` (`session_start`/`session_end` documented without the CHECK-constraint gap)
[14] `docs/SYSTEMS/idle-life-and-rest.md` (Dream Theater mechanism owner — channels, amplitudes, frame budget)
[15] `docs/SYSTEMS/companionship-rituals.md`, `docs/SYSTEMS/hunt-and-pounce.md`, `docs/SYSTEMS/play-bouts.md`, `docs/SYSTEMS/locomotion-and-gait.md`, `docs/SYSTEMS/environment-reactions.md` (owning concepts for the seven new journal moments)
[16] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (Dream Theater; journal-and-dreams deepening spec)
