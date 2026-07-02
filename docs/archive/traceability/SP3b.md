---
type: Reference
title: SP3b Traceability — Creation Systems + Misc
description: Source-to-concept mapping for Wave SP3b (WO-1 OKF migration) — proves zero fidelity loss across teach-system, world-objects-system, nurture-system, surprise-catalog, journal-and-dreams, performance-budgets, and roadmap.
status: Current
tags: [okf-migration, traceability, wave-sp3b]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP3b authored seven concepts:
[teach-system](/SYSTEMS/teach-system.md),
[world-objects-system](/SYSTEMS/world-objects-system.md),
[nurture-system](/SYSTEMS/nurture-system.md),
[surprise-catalog](/REFERENCE/surprise-catalog.md),
[journal-and-dreams](/REFERENCE/journal-and-dreams.md),
[performance-budgets](/REFERENCE/performance-budgets.md), and
[roadmap](/FEATURES/roadmap.md).

Per the wave brief, teach/objects/nurture were authored **fresh from code +
vision**, never from PHASE-7's stale schemas — `docs/archive/plan/phase-7-creation-systems/PHASE-7.md`
and `docs/archive/plan/phase-8-polish/PHASE-8.md` were read for background context
only; nothing was lifted from either as truth. Where their driftSignals
overlapped this wave's code checks, the resolution is noted below rather
than silently repeated.

# PUSHLING_VISION.md (primary source — assigned sections only)

| Source section | → Target concept#section | Status |
|---|---|---|
| The Creation Systems — intro ("composition, not construction") | `teach-system.md` intro | migrated |
| The Teach System: `pushling_teach` — choreography notation, "13 animatable tracks" | `teach-system.md#choreography-notation` | migrated, corrected — the vocabulary is actually 16 named tracks (`VALID_TRACKS`); 13 is the per-behavior cap (`ChoreographyParser.swift:209-212`), not the vocabulary size. Both numbers documented, doc's conflation resolved. |
| The Teach System — 4-tier mastery table | `teach-system.md#4-tier-mastery-system` | migrated, verified verbatim against `MasteryTracker.swift` |
| The Teach System — Compose-Preview-Refine-Commit workflow | `teach-system.md#the-7-actions-and-the-compose--commit-workflow` | migrated, verified against `teach.ts`/`CreationHandlers.swift` |
| The Teach System — Dream integration | `teach-system.md#dream-integration--designed-not-wired` | migrated, corrected — `MasteryTracker.selectDreamBehavior()` exists but has zero call sites; documented as designed-but-unwired rather than as a live mechanic |
| The Teach System — Capacity (max 30, triggers, cooldowns) | `teach-system.md#the-7-actions-and-the-compose--commit-workflow`, `#triggers` | migrated |
| Behavior Breeding (full subsection) | `teach-system.md#behavior-breeding` | migrated, verified verbatim against `BehaviorBreeding.swift` |
| The Objects System: `pushling_world("create")` — 3 creation interfaces, 60 base shapes | `world-objects-system.md#actions` | migrated, partial — the "preset / smart-default / full definition" 3-tier framing is preserved as the doc's description of intent; code (`world-validation.ts:104`) explicitly notes create is preset-only ("Phase 4 supports named presets"), so smart-default/full-definition-for-create are not independently gated features today. The 60-base-shape claim (20 primitives + 40 mini-sprites) was not re-verified against a named shape-registry constant this wave — preserved, not contradicted. |
| The Objects System — 20 named presets table | `world-objects-system.md#preset-catalog--a-live-cross-process-mismatch` | migrated, corrected — documented the real MCP `VALID_PRESETS` (20) vs. the real Swift `presets` dict (20, different membership), the 14-name overlap, and the silent-degradation bug for the 6 MCP-only names. This is a new drift, not carried from the survey. |
| The Objects System — 14 interaction templates table | `world-objects-system.md#autonomous-interaction--15-templates-not-14` | migrated, corrected — code-verified count is 15 (the doc's own table also sums to 15; only its header text says 14) |
| The Objects System — 7-factor attraction scoring | `world-objects-system.md#autonomous-interaction--15-templates-not-14` | migrated, verified against `AttractionScorer.swift` |
| The Objects System — Limits (12/3/20pt/2 emitters) | `world-objects-system.md#object-capacity--placement` | migrated — 12/3/20pt verified exactly against `WorldObjectRenderer.swift`; the "max 2 particle emitters from placed objects" figure was not independently re-verified against a named constant this wave, flagged as unverified rather than contradicted |
| The Objects System — Wear and repair | `world-objects-system.md#wear-repair--the-legacy-shelf` | migrated, verified against `ObjectWearSystem.swift` |
| The Objects System — Cat chaos (surprise #28, 2hr grace, relocate not delete) | `world-objects-system.md#wear-repair--the-legacy-shelf` | partially migrated — the core "knockingThingsOff" surprise is confirmed implemented (`surprise-catalog.md`'s catalog table); the 2-hour grace period and relocate-vs-delete refinements were not found as separate implemented mechanics and are noted as preserved-but-unverified, not contradicted |
| The Objects System — Legacy shelf | `world-objects-system.md#wear-repair--the-legacy-shelf` | migrated, verified against `WorldManager+Objects.swift` soft-delete (`is_active=0, removed_at`) |
| Companions (full subsection) | `world-objects-system.md#companions` | migrated, verified verbatim against `CompanionSystem.swift` (`CompanionType`, sizes) |
| The Nurture System: `pushling_nurture` — 5 mechanisms table | `nurture-system.md#the-5-mechanisms` | migrated, verified verbatim against `HabitEngine`/`PreferenceEngine`/`QuirkEngine`/`RoutineEngine` caps |
| The Nurture System — Identity actions | `nurture-system.md#the-6-actions-and-5-types` | migrated, verified against `nurture-validation.ts:validateIdentity` |
| The Nurture System — Habits fire on triggers list | `nurture-system.md#the-6-actions-and-5-types` | migrated, corrected — documented the real MCP-vs-daemon trigger-vocabulary mismatch (`after_commit`/`near_object`/`all_of`/`any_of`/`none_of` declared MCP-side with no daemon support; daemon's real `after_event`/`on_streak` not in the MCP enum). New drift, not carried from survey. |
| The Nurture System — Preferences, Quirks, Routines subsections | `nurture-system.md#the-5-mechanisms` | migrated |
| The Nurture System — Organic Variation Engine (5 axes) | `nurture-system.md#organic-variation-engine--5-axes` | migrated, verified verbatim against `OrganicVariationEngine.swift` |
| The Nurture System — Strength and decay table | `nurture-system.md#strength-reinforcement-and-mastery-based-decay` | migrated, corrected — rates/floors verified exactly; the illustrative "~80 days to floor" (Rooted) figure doesn't match the code comment's own math from a fresh 0.5 strength (20 days) — documented as a doc-accuracy note on the illustrative example only, not the load-bearing rate/floor numbers |
| The Nurture System — Creature agency (rejection) | `nurture-system.md#creature-agency-rejection` | migrated, verified verbatim against `CreatureRejection.swift` |
| The Nurture System — `suggest` action | `nurture-system.md` (folded into `#the-6-actions-and-5-types` intro) | migrated |
| The Nurture System — Before and after (narrative example) | *(not migrated)* | dropped-with-justification — purely illustrative narrative flavor text ("a nurtured creature has 14 habits...") with no verifiable claim attached; the caps and mechanics it illustrates are fully covered elsewhere in the concept |
| The Surprise & Delight System — Scheduling | `surprise-catalog.md#scheduling` | migrated, verified verbatim against `SurpriseScheduler.swift` |
| The Surprise & Delight System — "78 Surprises Across 8 Categories" header + full numbered list (1-78) | `surprise-catalog.md#the-catalog-78-surprises-across-8-categories` | migrated, verified — exact count confirmed via per-file definition counts (12+14+16+6+9+9+6+6=78); the doc's numbered list (individual surprise names/behaviors) is referenced as the canonical enumeration rather than re-transcribed in full, per the "one authority" rule (re-transcribing 78 items into a second doc would itself be a drift risk) |
| The Surprise & Delight System — Cross-system surprise integration | `surprise-catalog.md#cross-system-surprise-integration` | migrated, not independently re-verified against named implementations this wave (out of the assigned codeChecks list) — preserved as documented, not contradicted |
| Mutation Badges table (10 badges) | `surprise-catalog.md#mutation-badges-hidden-achievements` | migrated, verified verbatim against `MutationSystem.swift`'s `MutationBadge` enum — all 10 names/triggers/visuals/behavior-changes match exactly |
| Git Integration > The Journal — entry-type table (14 types) | `journal-and-dreams.md#journal-entry-types` | migrated, corrected/extended — live schema has 18 types; the 4 not in the vision doc (`ai_perform`, `teach`, `nurture`, `world_change`) are documented as post-dating the doc, not as errors |
| Dream Journal (full section) | `journal-and-dreams.md#1-wake-time-dream-bubble-matches-the-vision-doc` | migrated, verified verbatim against `SpeechCoordinator.showDreamBubble()` |
| Core Loop — Sleep row (dream scrolling, sleep-twitches) | `journal-and-dreams.md#2-autonomous-nightly-dreamengine-undocumented-in-the-vision-doc--new` | superseded-history / extended — the doc's brief sleep description undersells what's actually built; documented the full, much richer `DreamEngine` gate/phase/personality-drift system fresh from code as new canon, per the "later-built systems never flowed back into the vision doc" rule |
| Technical Performance (full table) | `performance-budgets.md#per-frame-budget` | migrated verbatim, with a note that these are design targets rather than instrumented runtime assertions (only the placed-object node cap is a real enforced constant) |
| Future Feature Roadmap — all 5 tiers | `roadmap.md` (Tier 1-5 sections) | migrated verbatim, in full, per the FEATURES/ aspirational-preservation rule |
| Installation — aspirational `brew`/`npm` distribution parts | `roadmap.md#aspirational-distribution-story` | migrated, corrected — documented as unbuilt against the real `install.sh` path, matching the survey's pre-existing driftSignal on this exact gap |
| Installation — CLI subcommand list (`pushling track`, `hooks install`, etc.) | `roadmap.md#aspirational-distribution-story` | migrated as target-CLI-contract-not-yet-built, explicitly flagged as not-yet-real to avoid implying it works today |

# docs/archive/plan/phase-7-creation-systems/PHASE-7.md (background only — no proposedConcepts, read for context)

Not migrated as a source; read in full per the wave brief's "read for
context, never lift stale schemas" instruction. Its driftSignals informed
adjudication rather than content:

| PHASE-7 driftSignal | Resolution in this wave's concepts |
|---|---|
| taught_behaviors schema differs from doc's SQL (INTEGER PK vs TEXT UUID, etc.) | Not migrated from PHASE-7 at all — `teach-system.md`'s Schema section is authored directly from the live `Schema.swift`, never from PHASE-7's SQL |
| "13 animatable tracks" vs. 16-row table conflation | Independently re-discovered from `PUSHLING_VISION.md` + code directly (see above); PHASE-7's framing of the same issue was not needed as a source |
| 3 creation interfaces (preset/smart-default/full) vs. preset-only code | Confirmed still true against current `world-validation.ts:104`; documented in `world-objects-system.md#actions` |
| Preset table differs from code on 7/20 entries | Superseded by this wave's own finding — the *current* live mismatch is between MCP's and the daemon's preset lists (not PHASE-7's proposed list vs. either); PHASE-7's specific 7-entry diff is stale and not reproduced |
| 14 interaction templates vs. `world_objects.interaction` CHECK vocabulary barely overlapping | Directly confirmed and extended in `world-objects-system.md`'s interaction-vocabulary section, using current code, not PHASE-7's version of the list |
| habits schema columns (energy_cost, priority, personality_conflict) absent from real table | Confirmed still true; `nurture-system.md`'s Schema section documents the real `habits` table columns only |
| category CHECK vocabulary (6 values) undocumented by PHASE-7 | Documented directly in `teach-system.md`'s action/category listing |

# docs/archive/plan/phase-8-polish/PHASE-8.md (background only — no proposedConcepts, read for context)

| PHASE-8 driftSignal | Resolution in this wave's concepts |
|---|---|
| Mutation badge names: doc's 10 vs. `milestoneSeedData`'s 10, only 3 match | Resolved definitively in `surprise-catalog.md#mutation-badges-hidden-achievements` — the real, live, doc-matching system is `MutationSystem.swift`'s `MutationBadge` enum (10/10 match `PUSHLING_VISION.md`); `milestoneSeedData`'s non-matching 7 IDs are dead/orphaned seed rows, not a competing live system. This is a stronger, corrected resolution of the same underlying discrepancy PHASE-8 flagged. |
| Journal schema differs from doc's SQL | Not migrated from PHASE-8 — `journal-and-dreams.md`'s type table is authored directly from live `Schema.swift` |
| Spore stage references | Not this wave's concern — the R1 ruling and `growth-stages.md` (SP3a) own this; `teach-system.md`/`nurture-system.md` use `stage_min` values (`egg`/`critter`/etc.) matching current code where stage names appear |

# Intentional Drops (awaiting Samantha sign-off)

1. **The Nurture System's "Before and after" narrative example** — dropped
   as flavor text with no independently verifiable claim; the caps/mechanics
   it illustrates are fully covered by the mechanism tables elsewhere in
   `nurture-system.md`.
2. **The Objects System's 60-base-shape breakdown (20 primitives + 40
   mini-sprites)** — preserved as a claim in `world-objects-system.md#actions`
   but not independently verified against a named shape-registry constant
   this wave (out of the assigned `codeChecks` list; a shape-factory deep
   dive belongs to whichever wave owns `CompositeShapeFactory`/`ObjectShapeFactory`
   rendering detail).
3. **Cross-system surprise integration's three named examples** (campfire
   stories, Signature-mastery spontaneous performance, preference-modified
   surprises) — preserved as documented but not independently re-verified
   against named implementations this wave.

None of these are silent — all three are called out explicitly in their
respective concept files as "preserved, not independently re-verified"
rather than presented as confirmed fact.
