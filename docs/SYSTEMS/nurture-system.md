---
type: System
title: Nurture System
description: Claude persistently shapes habits, preferences, quirks, routines, and identity via pushling_nurture — with mastery-tiered decay, personality-driven rejection, and 5-axis organic variation so nothing plays identically twice.
status: Live
tags: [creation, nurture, habits, preferences, quirks, routines, identity]
timestamp: 2026-07-02T00:00:00Z
---

`pushling_nurture` is how Claude acts as parent/trainer — installing
behavioral tendencies the creature performs autonomously, with organic
variation, that persist and decay like real memory. This concept owns the
5 nurture mechanisms, their caps and decay model, personality-based
rejection, and the variation engine. It does not own the wire-level
parameter tables (see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md)).

# The 6 Actions and 5 Types

`VALID_ACTIONS` (`mcp/src/tools/nurture.ts`): `set`, `remove`, `list`,
`suggest`, `reinforce`, `get`. `VALID_TYPES`: `habit`, `preference`,
`quirk`, `routine`, `identity`.

Unlike `pushling_teach` and `pushling_world` (which encode the sub-target
in the `action` string), `pushling_nurture` always sends `action = "set"`
(or `remove`/`reinforce`) with `type` as a separate field; the MCP layer
merges `type` into the daemon-bound params (`{type, ...params}`), and the
daemon's `handleNurtureSet` dispatches on `params["type"]`
(`NurtureHandlers.swift:12-31`). `list` and `get` never reach the daemon at
all — both read directly from SQLite via the MCP `StateReader`, matching
the "MCP reads, daemon writes" architecture.

# The 5 Mechanisms

| Type | What It Is | Cap | Verified Against |
|---|---|---|---|
| **Habits** | trigger → action | **20** | `HabitEngine.maxHabits` |
| **Preferences** | valence tags (-1.0 to +1.0) | **12** | `PreferenceEngine.maxPreferences` |
| **Quirks** | small behavior modifiers | **12** | `QuirkEngine.maxQuirks` |
| **Routines** | ordered steps per lifecycle slot | **10 slots** | `VALID_ROUTINE_SLOTS` length |
| **Identity** | name / title / motto | — | `creature.name/title/motto` columns |

All caps match `PUSHLING_VISION.md` exactly. Habits, preferences, and
quirks are enforced daemon-side by their respective engine's `add*`
returning `false` at capacity (`AT_CAP` error code); routines are keyed by
slot (`UNIQUE` on `routines.slot`) so "capacity" is really "one routine per
slot, 10 slots" rather than a count ceiling.

**Habit triggers — a live vocabulary mismatch.** The MCP's
`VALID_HABIT_TRIGGERS` (`mcp/src/tools/nurture-validation.ts`) lists:
`after_commit, on_idle, at_time, on_emotion, on_weather, near_object,
on_wake, on_session, on_touch, periodic, all_of, any_of, none_of`. The
daemon's `Self.parseTrigger` (`Pushling/Sources/Pushling/IPC/NurtureHelpers.swift:11-63`)
only recognizes: `after_event, on_idle, at_time, on_emotion, on_weather,
on_wake, on_session, on_touch, periodic, on_streak`. Concretely:
`after_commit` (MCP) vs. `after_event` (daemon) is a straight naming
mismatch — a request built exactly per the MCP schema's own trigger-type
enum would pass MCP-side validation, then fail daemon-side with "Invalid
trigger definition. Check 'type' field," because `parseTrigger` returns
`nil` for an unrecognized `type` string. `near_object` and the
`all_of`/`any_of`/`none_of` compound triggers are declared MCP-side with no
daemon support at all; `on_streak` exists daemon-side with no MCP-side
name. **New drift, not in the prior survey** — flagged for
`DECISIONS.md`/the Orchestrator. Until reconciled, the only triggers that
actually work end-to-end are `on_idle`, `at_time`, `on_emotion`,
`on_weather`, `on_wake`, `on_session`, and `on_touch`.

**Identity** (`params: {name?, title?, motto?}` — no separate `set`/`remove`
split; `remove` and `reinforce` are explicitly rejected for `type:
"identity"` by `nurture.ts`, since identity has no natural "remove" or
"strengthen" operation): `name` max 12 chars at any stage, `title` max 30
chars gated to Beast+, `motto` max 50 chars gated to Sage+ — all three
limits and both stage gates verified in
`mcp/src/tools/nurture-validation.ts:validateIdentity`.

# Strength, Reinforcement, and Mastery-Based Decay

All nurture data (habits, preferences, quirks, routines) carries a
`strength` value 0.0–1.0, starting at **0.5** on creation. `reinforce`
adds **+0.15** (capped at 1.0) — verified identically in both the MCP
response builder and `NurtureDecayManager.reinforce()`. Decay tier is
purely a function of `reinforcement_count`
(`NurtureDecayManager.swift:54-61`):

| Tier | Reinforcements | Decay Rate | Floor |
|---|---|---|---|
| Fresh | 0–2 | 0.02/day | 0.0 (forgotten) |
| Established | 3–9 | 0.01/day | 0.2 (vaguely remembered) |
| Rooted | 10–24 | 0.005/day | 0.4 (still knows it) |
| Permanent | 25+ | 0.001/day | 0.6 (core identity) |

Rates and floors match `PUSHLING_VISION.md` exactly. **The "days to floor"
figures do not.** The vision doc claims "~25 days" (Fresh) and "~80 days"
(Rooted) to reach the floor; the code's own `daysToFloor` documents
Fresh at 25 (matches, computed from strength 0.5) but Rooted at **20**, not
80 (`(0.5 - 0.4) / 0.005 = 20`, per the code comment "From 0.5 to 0.4" at
`NurtureDecayManager.swift:49`). The doc's 80-day figure would only hold if
decay started from a much higher strength (e.g. ~0.9, reachable after
several reinforcements) rather than the fresh-install value of 0.5 the
code's own comment assumes. This is a minor doc-accuracy note, not a
functional contradiction — the rate and floor (the load-bearing numbers)
are correct; only the illustrative "days to floor" example is
context-dependent and inconsistent between doc and code comment.

Decay runs on daemon startup and every 6 hours thereafter
(`decayIntervalHours`). A developer returning after weeks away finds
Fresh habits forgotten, Established ones weakened-but-present, Rooted and
Permanent ones intact — matching the vision doc's "the creature
remembered" framing exactly.

# Creature Agency: Rejection

`CreatureRejection.checkAlignment` runs on every `habit` `set` (habits
only — preferences/quirks/routines have no rejection path in the code).
Four conflict types, each keyed to a personality axis: `energyTooHigh`
(high-energy behavior + calm creature), `energyTooLow` (reverse), `disciplineMismatch`
(`functional`/`calm` category + `discipline < 0.2`), `verbosityMismatch`
(`dramatic` category + `verbosity < 0.2`). On conflict, `set` is rejected
by default with a `personality_conflict: true` response describing the
mismatch; passing `{"force": true}` overrides it, but the habit starts at
**0.3 strength** instead of 0.5 and has a reluctance level that scales its
performance speed (`×0.7` at max reluctance) and amplitude (`×0.6`), plus a
**15% chance of a visible balk** (head-shake animation,
`CreatureRejection.balkOutput`) scaled by reluctance. Reluctance decays
linearly with reinforcement — `1.0 - reinforcementCount × 0.1` — reaching
full acceptance (`hasAccepted`) at **10 reinforcements**, matching the
vision doc's "creature agency" description precisely.

# Organic Variation Engine — 5 Axes

Every performance of a habit/quirk/routine generates a fresh
`VariationSeed` (`OrganicVariationEngine.generateSeed`), so nothing plays
identically twice:

1. **Timing jitter** — `±(variation.jitterPercent × (1.5 - discipline))`;
   higher discipline narrows the range.
2. **Probabilistic skipping** — base skip rate by frequency (`always`
   5%, `often` 10%, `sometimes` 15%, `rarely` 20%), scaled the same way by
   discipline. Even an "always" habit skips sometimes — "the creature
   *chooses* not to," per the vision doc.
3. **Mood modulation** — average of satisfaction/contentment below 0.3
   slows performance to 0.7x speed and 0.6x amplitude; above 0.7 gives a
   slight 1.1x speed boost at full amplitude.
4. **Energy scaling** — speed floor of 0.5x at zero energy.
5. **Personality consistency** — an overall `[0.8, 1.2]` modifier scaled by
   discipline, applied on top of the others.

All 5 axes and their constants verified against
`OrganicVariationEngine.swift`, matching the vision doc's 5-axis
description exactly (including "even 'always' habits skip 5-10% of the
time").

# Suggest — Shipped Heuristic vs. Designed Observation Engine

`suggest` (`handleNurtureSuggest`, `Pushling/Sources/Pushling/IPC/CreationHandlers.swift:525-548`)
is a **shallow state checklist**, not the pattern-learning engine the design
called for. It walks a fixed list of static thresholds against current
state and returns whichever match, in a flat `{action, type}` shape (a
free-text sentence, not a structured suggestion object):

| Condition Checked | Suggestion Returned |
|---|---|
| `satisfaction < 30` | "Commit some code! The creature is hungry." (feeding) |
| `energy < 20` | "Let the creature rest — use 'perform nap'." (rest) |
| `curiosity > 70` | "Teach a new trick — the creature is eager to learn." (teach) |
| `creatureName == "Pushling"` (never renamed) | "Give the creature a name..." (identity) |
| no habits set | "Set a habit — e.g. stretch after every commit." (habit) |
| no preferences set | "Set a preference — does the creature love rain?" (preference) |
| *(always appended)* | "Express joy or love to build the bond." (expression) |

None of this reads `object_interactions`, location-dwell time, or
time-of-day activity — it's a point-in-time state check, not a rolling
observation window.

**Unbuilt design intent** (`docs/archive/plan/phase-7-creation-systems/PHASE-7.md`
P7-T3-10): the original design was a genuine pattern-observation engine.
The daemon would track a rolling **7-day window** of autonomous behavior —
object-interaction counts ("23 autonomous interactions with mushrooms this
week"), location dwell percentage ("40% of idle time near the campfire"),
time-of-day activity clustering, and emotional correlations ("satisfaction
spikes after rain") — and return **3-5 confidence-ranked suggestions**
(minimum confidence 0.5, cached and refreshed every 24h rather than
computed per call) in a structured shape:

```json
{
  "suggestions": [
    {
      "type": "preference",
      "suggestion": {"subject": "mushrooms", "valence": 0.7},
      "reason": "interacted with mushrooms 23 times this week (3x average)",
      "confidence": 0.85
    }
  ]
}
```

The stated goal — "Claude can codify what the creature is already doing
naturally" — describes this observation engine, not the shipped
checklist; the shipped version can only ever suggest actions Claude
hasn't yet taken, never patterns the creature has organically formed on
its own.

# Schema

`habits`, `preferences`, `quirks`, `routines`
(`Pushling/Sources/Pushling/State/Schema.swift:213-274`) each carry
`strength REAL CHECK (0.0-1.0) DEFAULT 0.5` and `reinforcement_count
INTEGER DEFAULT 0`. `habits.trigger_json`/`action_json` and
`quirks.modifier_json` store the structured trigger/action/modifier as
serialized JSON (not normalized columns). `routines.slot` is `UNIQUE`,
CHECK-constrained to the 10 lifecycle slots (`morning, post_meal, bedtime,
greeting, farewell, return, milestone, weather_change, boredom,
post_feast`).

# Examples

```json
{"action": "set", "type": "preference",
 "params": {"subject": "rain", "valence": 0.8}}

{"action": "set", "type": "habit",
 "params": {"name": "stretch_after_eating", "behavior": "stretch",
            "trigger": {"type": "after_event", "event": "commit"},
            "frequency": "often"}}
```

Note the `trigger.type` in the working example is `"after_event"` (the
daemon's real vocabulary), not `"after_commit"` — see the drift note above.

# Citations

[1] `mcp/src/tools/nurture.ts` (`VALID_ACTIONS`, `VALID_TYPES`, dispatch)
[2] `mcp/src/tools/nurture-validation.ts` (`VALID_HABIT_TRIGGERS`, `validateIdentity`, caps referenced in error text)
[3] `Pushling/Sources/Pushling/IPC/NurtureHandlers.swift` (`handleNurtureSet*`, `handleNurtureRemove`, `handleNurtureReinforce`)
[4] `Pushling/Sources/Pushling/IPC/NurtureHelpers.swift` (`parseTrigger` — real trigger vocabulary)
[5] `Pushling/Sources/Pushling/Nurture/HabitEngine.swift`, `PreferenceEngine.swift`, `QuirkEngine.swift`, `RoutineEngine.swift` (caps)
[6] `Pushling/Sources/Pushling/Nurture/NurtureDecayManager.swift` (decay tiers, reinforcement)
[7] `Pushling/Sources/Pushling/Nurture/CreatureRejection.swift` (conflict detection, reluctance, balk)
[8] `Pushling/Sources/Pushling/Nurture/OrganicVariationEngine.swift` (5 variation axes)
[9] `Pushling/Sources/Pushling/State/Schema.swift` (habits/preferences/quirks/routines tables)
[10] `PUSHLING_VISION.md` — The Nurture System
[11] `Pushling/Sources/Pushling/IPC/CreationHandlers.swift:525-548` (`handleNurtureSuggest` — shipped checklist)
[12] `docs/archive/plan/phase-7-creation-systems/PHASE-7.md` — P7-T3-10 (designed observation engine)
