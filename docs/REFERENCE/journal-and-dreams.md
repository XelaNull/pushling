---
type: Reference
title: Journal & Dreams
description: The 18-type journal entry taxonomy that records every meaningful event, and the two distinct dream mechanics — a wake-time speech-fragment dream bubble, and a full autonomous nightly DreamEngine with personality drift.
status: Live
tags: [journal, dreams, memory]
timestamp: 2026-07-02T00:00:00Z
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

# Surfacing Channels

Per the vision doc: dreams (automatic), a stats display (3-finger swipe),
memory postcards (4-finger swipe), `pushling_recall`, Sage+ idle
reminiscence, and ruin inscriptions in terrain. This wave did not
independently re-verify the memory-postcard mechanic — a prior survey pass
on a different source doc (PHASE-8) found no `postcard`/`FourFinger` hits
anywhere in `Pushling/Sources`, suggesting it may be unbuilt; flagged here
for whichever wave owns touch gestures
([touch interaction](/SYSTEMS/touch-input-pipeline.md)) to confirm.

# Citations

[1] `Pushling/Sources/Pushling/State/Schema.swift` (`journal` table CHECK constraint, lines 138-152)
[2] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift` (`showDreamBubble`)
[3] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (wake → `showDreamBubble` call site)
[4] `Pushling/Sources/Pushling/Behavior/DreamEngine.swift` (gates, phase machine, personality drift, persistence)
[5] `Pushling/Sources/Pushling/Behavior/DreamTemplates.swift` (`DreamPattern`, `generate`)
[6] `Pushling/Sources/Pushling/App/GameCoordinator+DreamEngine.swift` (wiring into `AutonomousLayer`)
[7] `Pushling/Sources/Pushling/Behavior/MasteryTracker.swift` (`selectDreamBehavior` — unwired)
[8] `PUSHLING_VISION.md` — The Journal; Dream Journal; sleep/dream mentions in Core Loop
