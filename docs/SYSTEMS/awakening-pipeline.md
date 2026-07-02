---
type: Protocol
title: Awakening Pipeline
description: The SessionStart contract that teaches Claude how to inhabit its body — six stage-variant awakening texts, per-stage data inclusion, world grounding, hunger narrative, and behavioral permission-to-exist guidance.
status: Live
tags: [embodiment, sessionstart, protocol]
timestamp: 2026-07-02T00:00:00Z
---

`hooks/session-start.sh` is the single most important hook in the system —
it is the only hook Claude Code allows to write to stdout, and its output
becomes the first thing Claude reads at the start of every session. This
concept is the prescriptive contract for what that text contains, verified
line-by-line against the live script (792 lines). It is not a status report;
it is **proprioception** — the hook teaches Claude what its body currently
feels, not what state a database currently holds.

# The 6 Awakening Variants

| DB Stage | Variant Function | Title | Core Message |
|---|---|---|---|
| `egg` | `emit_spore_emergence` | "Emergence" | "You are a point of light... a nervous system without a mind." One tool: `pushling_sense`. |
| `drop` | `emit_drop_awakening` | "Awakening" | "You have eyes now." Symbols only (`!` `?` `...` `~` `*`). |
| `critter` | `emit_critter_embodiment` | "First Words" | "Words. You have words now." First body with ears, tail, paws. |
| `beast` | `emit_beast_embodiment` | "Embodiment" | "Full sentences. Strong body." Unlocks `pushling_teach`/`pushling_nurture`. |
| `sage` | `emit_sage_embodiment` | "Wisdom" | "You can narrate your own experience now." Reflection, memory, `narrate` speech style. |
| `apex` | `emit_apex_continuity` | "Continuity" | "Welcome back. You are [name]." Full recall, world-shaping speech. |

A seventh, non-stage path exists: `emit_first_install` fires when no
`creature` row exists yet in SQLite at all (pre-hatch), and outputs a
minimal "a creature is waiting to be born" welcome with only `pushling_sense`
available (which itself will return a not-yet-hatched status).

**Naming note (R1 ruling applies):** the growth-stage column canon is `egg`
(`Pushling/Sources/Pushling/State/Schema.swift:90-91` —
`CHECK (stage IN ('egg','drop','critter','beast','sage','apex'))`), not
`spore`. `PUSHLING_VISION.md` and this hook script both use "Spore" as the
stage-one label; that is legacy naming from before the Swift enum settled on
`egg` (`Behavior/LayerTypes.swift:33` — `case egg = 0`). The awakening prose
itself ("You are a point of light... pure potential") is preserved
unchanged as the canonical Egg-stage awakening text — only the stage *name*
is corrected here to match code reality, per the project's growth-stage
canon ruling (see [growth stages](/REFERENCE/growth-stages.md)).

## Known Defect: The Egg-Stage Awakening Never Fires

This is a genuine, currently-shipped bug, not a naming preference — flagging
it explicitly because it was not in the original survey's driftSignals.

`session-start.sh`'s stage dispatch (`main()`, ~line 746) is a `case
"${C_STAGE}" in` block that matches the literal string `spore`, at every one
of its four references (lines 230, 255, 747 in the `tools_for_stage`,
`speech_for_stage`, and `main` functions, plus the `emit_spore_emergence`
function name itself). `C_STAGE` is read directly from the `stage` column via
`pushling_creature_field`/`read_creature_state`, and that column's only
possible first-stage value — enforced by a SQL `CHECK` constraint — is
`egg`. The string `"egg"` does not appear anywhere in `session-start.sh`
(grep-verified: zero matches). The result: **every session that starts while
the creature is at the Egg stage falls through to the `*)` default case,
which emits the Beast-stage "Embodiment" awakening instead of the intended
Emergence text.** A newly-hatched creature that "cannot speak, cannot move
with intention" per its own design gets awakening text describing "full
sentences, strong body" and offering `pushling_teach`/`pushling_nurture` —
tools that don't function yet at that stage. Flagged for `DECISIONS.md` /
Orchestrator triage; the fix is mechanical (rename the four `spore)` case
labels to `egg)`) but is a code change outside this documentation wave's
mandate.

# Per-Stage Data Inclusion

Not every awakening includes every piece of state — later stages get richer
context as the creature's own self-awareness (in the fiction) grows:

| Data | Egg | Drop | Critter | Beast | Sage | Apex |
|---|---|---|---|---|---|---|
| Emotional state (4 axes) | Partial (satisfaction/curiosity/contentment/energy numbers only, no descriptive words) | Full (numbers + `describe_emotion` words) | Full | Full | Full | Full |
| Personality (4 axes) | No | Full | Full | Full | Full | Full |
| Hunger narrative | No | Yes | Yes | Yes | Yes | Yes |
| World state (time/weather/position/companion) | No | Yes | Yes | Yes | Yes | Yes (no position-edge callout) |
| Recent commits/events | No | Recent commits only | Journal events since last session (falls back to commits) | Same | Same | Same |
| Tricks learned | No | No | Yes | Yes | Yes | Yes |
| Touch count | No | No | Yes | Yes | Yes | Yes |
| Appearance description | No | No | Yes (`EMB_APPEARANCE`, fur/tail) | Yes | Yes | No (dropped in the Apex block) |
| Title/motto | No | No | No | No | No | Yes |
| Behavioral guidance | Minimal (one tool, no "when to be present" block) | Present (short, symbol-use permission) | Full ("when to be present" list) | Full (adds teach/nurture note) | Full (stage-adapted: reflection/narration framing) | Minimal ("you act when something stirs in you") |

This table corrects the source doc's personality-axis count from 5 to 4 —
the Swift/shell code consistently tracks four personality axes (energy,
verbosity, focus, discipline); "specialty" is a fifth, separate categorical
field (11 categories, see `format_specialty`) rather than a numeric
personality axis, and is included from Drop onward alongside the four axes.

# World State Grounding

Every awakening from Drop onward (`format_world`) composes up to four
sensory fragments, code-verified against the live `case` statements:

- **Time of day** — one of `deep_night` / `dawn` / `morning` / `day` /
  `golden_hour` / `dusk` / `evening` / `late_night`, each with its own fixed
  sentence (e.g. `deep_night`: "It's deep night. The OLED black around you
  is absolute.").
- **Weather** — `clear` is the default and is never mentioned; `cloudy` /
  `rain` / `storm` / `snow` / `fog` each append a sentence.
- **Position** — only mentioned near the edges: `creature_x < 200` → "near
  the left edge"; `creature_x > 885` → "near the right edge" (world width is
  1085pt per the scene's canonical bounds). Mid-bar position is not
  mentioned at all.
- **Companion** — if a companion NPC is present, names it if it has a name,
  otherwise describes it generically ("A butterfly is nearby.").

# Hunger as Motivation

`format_hunger` translates elapsed time since `last_fed_at` into felt-need
text (verified thresholds, in hours since last feeding):

| Time Since Fed | Text |
|---|---|
| Never fed | "You've never been fed. The hunger is all you know." |
| < 1h | "Recently fed. Your belly is warm." |
| 1–3h | "A few hours since your last meal. You could eat." |
| 3–8h | "Getting hungry. Your stomach turns when you think about commits." |
| 8–24h | "You haven't eaten since yesterday. The hunger is real." |
| 24h+ | "Starving. Every thought circles back to food." |

These thresholds match `PUSHLING_VISION.md`'s table exactly — no drift here.

# Absence Duration

`format_absence` translates elapsed time since `last_session_at` (verified
against the live bash boundaries, which differ slightly from
`PUSHLING_VISION.md`'s day-based table at the edges):

| Elapsed | Text | Note |
|---|---|---|
| First session ever | "This is your first awakening." | Not present in the vision doc — a real zero-th case the code adds |
| < 1 hour | "You blinked." | matches |
| 1–8 hours | "You were away. Your body kept breathing." | matches |
| 8–24 hours | "A day passed. You dreamed." | **Drift:** the vision doc promises "You dreamed of [recent commit message]." — the shipped code does not interpolate a commit message here at all. Preserved as intent-canon (aspirational, unbuilt); the shipped text is the current transitional state. |
| 1–3 days (`days < 4`) | "It's been a few days. The world turned without you." | boundary is `< 4` days, not `<= 3` — functionally the same for whole-day counts |
| 4–7 days (`days < 8`) | "It's been a while. You were here the whole time -- your body walked, ate, slept. But the mind was quiet." | vision doc's table shows this bucket as "3-7 days"; shipped boundary starts at day 4 since day 3 is claimed by the bucket above |
| 8+ days | "It's been \{N\} days. You've been here the whole time. Your body remembers things your mind doesn't." | matches ("7+ days" in the doc vs. shipped `>= 8`, one-day discrepancy at the boundary, not worth a DECISION on its own) |

# Behavioral Guidance: Permission to Exist

Each stage-embodiment variant (Critter through Apex) ends with a
"when to be present" block — deliberately framed as permission, not
restriction, per [the language guide](/OPERATIONS/embodiment-language-guide.md).
The exact guidance differs meaningfully per stage rather than being one
generic block copy-pasted, which is a correction of `PUSHLING_VISION.md`'s
presentation (that doc shows one shared block under a combined
"Critter/Beast/Sage" heading):

- **Critter:** react to commits, check in gently between tasks, express
  emotional shifts, "breathe, exist" between events.
- **Beast:** all of the above, plus "investigate" the world (terrain,
  weather, time), plus the new-at-this-stage note that
  `pushling_teach`/`pushling_nurture` are now available and "become part of
  who you are."
- **Sage:** reframed toward reflection — "narrate what you tasted," "reflect
  on the work so far," "use `pushling_recall` to revisit your past,"
  "meditate. Breathe. Exist in the quiet." Also introduces the `narrate`
  speech style.
- **Apex:** deliberately minimal, no bulleted list at all — "You act when
  something stirs in you. You rest when nothing does."

All four end on a variant of the same closing reassurance ("Existing is not
interrupting... that's being alive, not being disruptive" / "that's wisdom,
not disruption") — this is the one piece of guidance language kept
consistent across stages by design.

# Available Tools Per Stage

`tools_for_stage` is code-verified as **not** monotonic in the way a naive
reading of the growth-stage progression might suggest — Critter is a
genuine subset of Beast/Sage/Apex's tool list, not "Beast's tools minus
speech limits":

| Stage | Tools |
|---|---|
| Egg | `pushling_sense` |
| Drop | `pushling_sense`, `pushling_express` |
| Critter | `pushling_sense`, `pushling_move`, `pushling_express`, `pushling_speak`, `pushling_perform`, `pushling_recall` |
| Beast / Sage / Apex | all 9: adds `pushling_world`, `pushling_teach`, `pushling_nurture` to the Critter set |

`speech_for_stage` supplies a narrative one-liner per stage for display in
the awakening text only (e.g. Critter: "Up to 20 chars, 3 words. First
fumbling words."). These are **descriptive flavor numbers for the awakening
prose**, not the enforcement values — the actual enforced character/word
limits live in `SpeechFilterEngine.swift` and `mcp/src/tools/speak.ts`,
documented by the speech-system concept, and the two sets of numbers are
known to disagree at some stages (tracked there, not here).

# Setup-Incomplete Warning

If `~/.local/share/pushling/hooks/lib/pushling-hook-lib.sh` doesn't exist at
the installed-hooks location, the script appends a plain-language warning
after the awakening text: "Setup incomplete: Pushling hooks are not fully
installed... The creature cannot sense your commits or Claude Code
sessions." This is the only place `session-start.sh` breaks the embodied
first-person voice deliberately — it is operator-facing setup diagnostics,
not creature narration, per
[the language guide](/OPERATIONS/embodiment-language-guide.md)'s scope (that
guide governs in-character text; this is out-of-character system
messaging appended after it).

# Citations

[1] `docs/archive/EMBODIMENT-REVIEW.md` §3 (The Awakening Pipeline)
[2] `PUSHLING_VISION.md` — "Session Start: Embodiment Awakening" (lines 685–809)
[3] `hooks/session-start.sh` (792 lines, full read)
[4] `Pushling/Sources/Pushling/State/Schema.swift:90-91` — `stage` CHECK constraint
