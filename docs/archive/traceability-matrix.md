---
type: Reference
title: WO-1 OKF Migration — Master Traceability Matrix
description: The single consolidated source-to-concept map for every one of WO-1's 24 surveyed source documents, assembled from the 9 parallel waves' sub-matrices — proves zero fidelity loss across the full migration and collects every intentional drop for Orchestrator sign-off.
status: Current
tags: [okf-migration, traceability, master-matrix, wo-1]
timestamp: 2026-07-02T00:00:00Z
---

This is the finalize-pass (SP8) consolidation of the nine per-wave
traceability sub-matrices (`docs/archive/traceability/SP2a.md` through
`SP7.md`) into one matrix, organized **by source document** rather than by
wave. It covers all 24 documents in the original migration survey
(`.samantha/scratch/okf-survey-2026-07-02.json`), including the three
sources (`PUSHLING_VISION.md`, `pushling/CLAUDE.md`, `mcp/README.md`) that
were split across several waves. Nothing here is re-derived from the source
docs directly — every row is carried forward from a wave's own sub-matrix,
which was itself verified against the shipping code at authoring time. Where
a source was assigned to more than one wave, this matrix merges their rows
under one table and tags each row with its originating wave.

**A note on detail level:** the Intentional Drops section immediately below
reproduces every `dropped-with-justification` row in full, since that's the
one section built specifically for a sign-off decision. The per-source
tables further down are intentionally **condensed** — each row states the
section, its target concept, and status in brief, with a pointer to the
originating wave's sub-matrix (`SPx.md`) for the full verbatim reasoning,
corrected values, and code citations. This avoids a second, drift-prone copy
of ~371 already-detailed rows; the sub-matrices remain the primary evidence,
this file is the navigation and sign-off layer on top of them.

# Coverage Summary

- **24 source documents** surveyed (per the original OKF migration survey);
  all 24 are accounted for below — either actively migrated by a wave,
  covered as background-verification-only, or (for the two `docs/archive/plan/`
  artifacts no wave was ever dispatched to trace individually)
  reconciled directly in this pass against the survey's own disposition.
- **371 source-section → concept mappings** (individual table rows) across
  the 9 waves' 38 sub-tables — the atomic unit of this migration's
  fidelity proof.
- **56 items tagged `dropped-with-justification`** across all waves,
  collected in full immediately below for one-place Orchestrator review.
  Most are procedural (plan-wrapper scaffolding: Goal/Dependencies/QA-Gate
  headers, superseded MTMR/bash-era technique catalogs) rather than
  contested canon calls — the substantive ones are marked **⚑** below.
  (SP8c reclassified one further item — MULTITOUCH §5 — from dropped to
  migrated-as-unbuilt; see that source's entry below for the full
  overturn rationale.)

# Intentional Drops — Awaiting Orchestrator Sign-Off

Every row across all 9 waves tagged `dropped-with-justification`, grouped by
source document. **⚑** marks the drops most worth the Orchestrator's actual
attention (a judgment call, not pure scaffolding); unmarked rows are
plan-wrapper/QA-checklist/superseded-runtime housekeeping that no wave
treated as a close call.

## `PUSHLING_VISION.md` (SP3b)
- **The Nurture System's "Before and after" narrative example** — purely illustrative flavor text ("a nurtured creature has 14 habits...") with no independently verifiable claim; the caps/mechanics it illustrates are fully covered by the mechanism tables elsewhere in `nurture-system.md`.
- *(Flagged alongside the drop above in SP3b's own sign-off list, but not true content losses — preserved with an unverified flag rather than omitted:)* the Objects System's 60-base-shape breakdown (20 primitives + 40 mini-sprites, not independently checked against a named shape-registry constant) and Cross-system surprise integration's three named examples (campfire stories, Signature-mastery spontaneous performance, preference-modified surprises) are both still present in `world-objects-system.md` / `surprise-catalog.md`, just called out as "documented, not independently re-verified this wave" rather than confirmed fact.

## `pushling/CLAUDE.md` (SP2b)
- **⚑ Two-Instance Coordination, safety carveouts, message format** — session/process meta-content about how Samantha/Monk coordinate, not knowledge about the Pushling product itself; out of scope for an OKF concept.

## `mcp/README.md` (SP2a, SP2b)
- **Setup, Register with Claude Code, Development commands** — README-native onboarding instructions (`npm install`, `claude mcp add`, `npm run dev`); not canon knowledge, README stays `keep-as-is`. *(Note: SP2b later re-included the two `claude mcp add` registration forms specifically in `mcp-server.md#registration`, judging the prod-vs-dev choice a real gotcha rather than pure onboarding fluff — flagged by SP2b as diverging from SP2a's original call.)*
- **File Structure tree** (flagged independently by both SP2a and SP2b) — directory listing is derivable from the repo and was already known-stale at survey time (missing `nurture-validation.ts`, `sense-helpers.ts`, `teach-handlers.ts`, `world-validation.ts`); not worth re-freezing.

## `docs/archive/plan/phase-4-embodiment/PHASE-4.md` (SP2a, SP3a, SP7)
- **⚑ P4-T2-06 Command Queue in Daemon** (4 modes, capacity 20) — SP2a's initial pass dropped this as unverified; SP3a's follow-up code search confirmed zero implementation exists (`CommandQueue`, queue-mode params: no matches) and **did** migrate it into `ai-command-queue.md#what-is-built-the-command-queue-as-it-runs-today` as documented-unbuilt design intent. Net effect: not lost, but downgraded from "built" to "designed, never shipped" — worth the Orchestrator's awareness since it's a real gap between `PUSHLING_VISION.md`'s implication and shipped behavior.
- Goal, Dependencies, Integration Points, QA Gate — plan-wrapper scaffolding (agent assignments, effort estimates, phase-completion checklist); archival of the residual file is this wave's job.
- Track 3 Goal/Agents/Estimated-effort header — same rationale, SP7's Track 3 slice.

## `docs/archive/plan/phase-2-creature/PHASE-2.md` (SP3a, background-only)
- **P2-T2-01/07** ("AI-Directed layer is inert in Phase 2") — a historical build-state scoping statement from a moment in development long past; `AIDirectedLayer` is fully live today, documented fresh from code in `behavior-stack.md`.

## `docs/archive/CREATURE-VOICE-DESIGN.md` (SP4)
- §2, §10, and opening/closing in-line Claude/Samantha dialogue framing — theatrical presentation device; every substantive claim the dialogue wraps is accounted for in the concept's prose.
- §12 Implementation Roadmap — historical planning artifact, no content beyond what §2–11 already state as design targets.
- **Appendix A Audio Budget** — per-operation cost estimates (`AVSpeechSynthesizer.write()`, AudioKit) for an architecture that was never built; shipped performance characteristics are in `voice-tts-stack.md`, verified against real code instead.
- **Appendix B Sound File Inventory** (~575KB pre-recorded asset budget) — superseded entirely; the shipped system synthesizes everything programmatically (`SoundGenerators.swift` — "No audio files needed").

## `docs/archive/TTS-RESEARCH.md` (SP4)
- §18 Implementation Roadmap — historical phase-sequencing narrative, no content beyond §16/§17 (already migrated); the Performance Targets sub-table was separately migrated.

## `docs/archive/plan/phase-5-speech/PHASE-5.md` (SP4, SP7)
- Goal, Dependencies, Architecture Notes, Performance Budget — plan-wrapper scaffolding; the "where speech lives" file-path claims (`SpeechFilter.swift`, `Feed/CommitEater.swift`) are stale, superseded by the wave's verified code paths.
- QA Gate (Track 1/2/3 checklists) — testing artifact, not canon; every claim it verifies is confirmed/corrected in the prose sections it covers.
- **P5-T3-10 Sleeping Creature Commit Processing** — sleep-state/dream-rendering detail (how eating *renders* while asleep) with no XP or detection implications of its own; belongs with a creature/sleep-cycle concept, not commit-feeding.
- Track 3 Goal/Dependencies header, QA Gate checklist — plan-wrapper scaffolding (SP7's slice).

## `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` (SP5) — RECLASSIFIED (SP8c)
- ~~**⚑ §5 Creature Scaling Under Zoom**~~ — originally proposed as
  dropped by SP5 ("no `cappedZoom`/`worldZoom`/counter-scale code exists
  anywhere; `PushlingScene.swift`'s real `depthScale = 1.0 − z × 0.35` is
  unrelated depth-based scaling, not zoom-related"). **Overturned this
  pass**: unbuilt is not droppable under ruling R2 — this is part of the
  live-pan-zoom design R2 made intent-canon. Migrated instead as 📐
  unbuilt design intent into
  `docs/FEATURES/interactivity-unbuilt.md#live-pan--zoom` (table, formula,
  and hard cap preserved in full). No longer counted as a drop.

## `docs/archive/plan/phase-6-interactivity/PHASE-6.md` (SP5)
- Goal/Dependencies/Architecture Notes performance-budget table — no per-subsystem input-latency profiling exists in code to verify against (<0.5ms gesture recognition, etc.); unverifiable design targets, not measured/enforced values.
- ~~HUD overlay + near-evolution progress bar visual detail (from P6-T1-02b)~~ — **corrected this pass (RM-TOUCH): not actually dropped.** Both are fully documented, with corrected code values (80%/95%/99% pulse thresholds), in `/SYSTEMS/world-complexity-ambient-effects.md#the-cinematic-hud` and `#evolution-progress-bar` — this row was more conservative than reality; removed as a drop.
- Milestone unlock journal-entry JSON examples (P6-T2-04) — no implementing/journal-write call sites found to verify against.
- ~~Per-type invitation self-resolution animations + journal JSON (P6-T3-03)~~ — **reclassified this pass (RM-TOUCH), same R2-style ruling as MULTITOUCH §5/§6 above: unbuilt design intent is not droppable just because there's no implementing call site.** Restored as unbuilt intent in `/SYSTEMS/invitation-system.md#the-6-invitation-types` (self-resolution animations table, half-reward rule, journal JSON shape). No longer counted as a drop.
- Mini-Game Result Screen visual layout (P6-T3-10) — rendering detail, belongs to a creature-visual/UI concept.
- QA Gate (all Track 1-3 checklist items) — no prescriptive content beyond what the concepts already establish as built/verified.

## `docs/archive/plan/TODO-CONTEXT-MENU-SYSTEM.md` (SP5)
- Visual Design (item-sizing math, palette, ASCII mockups) — implementation detail for a never-built system; the design's *conclusions* are captured in `touch-bar-menu-patterns.md`'s prose instead.
- **Technical Architecture** (`ContextMenuItem`/`ContextMenuDefinition`/etc. Swift signatures) — unbuilt code sketches; OKF concepts document built or clearly-scoped systems, not speculative unimplemented class APIs. The system's *existence and scope* is preserved; its hypothetical signatures are not.
- Animation Specifications, Implementation Phases/File List/Integration Points/Node Budget/Performance Considerations, Open Questions, Success Criteria, Implementation Priority — project-planning scaffolding and open questions for a system that was never built and was superseded before they needed answering.
- ASCII mockups within the Six Patterns evaluation and the Pattern 6 frame-budget table — visual aids / unverifiable-against-nonexistent-code detail with no standalone value beyond the evaluation prose already captured.

## `docs/archive/3D-RENDERING-RESEARCH.md` (SP6a, SP6b)
- **§14 "What We Explicitly Reject"** — identical content to §1-13's rejected-options analysis, already fully owned by `3d-rendering-feasibility.md#what-was-explicitly-rejected`; cross-linked, not restated.
- §1 Claude/Samantha dialogue framing — narrative/roleplay flavor text; the substantive conclusion it wraps is preserved in prose.

## `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` (SP6a, SP6b)
- **Sec 7's spine-chain/two-bone-IK skeleton-upgrade phases** — zero code trace found for this multi-phase plan; re-authoring an entirely-unbuilt plan as canon risked minting speculative content beyond what any wave's code search surfaced. (The "what NOT to do" half of the same section *was* migrated.)
- Sec 10-11 (Codebase Grades, Implementation Priority) — the survey itself flags these as a point-in-time snapshot overtaken by commits within days of the document's date.
- Sec 12 Sources (OLED-specific citation subset) — one shared bibliography backing Sec 3-11 as a whole; splitting out only the OLED-relevant entries would require editorial judgment calls about a bibliography this wave doesn't fully own.

## `docs/archive/plan/phase-3-world/PHASE-3.md` (SP6a)
- Integration Points, QA Gate — historical Phase 4/6/7/8 cross-references and a per-item checklist, superseded by the shipped, already-integrated system each concept documents directly.

## `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` (SP6a)
- The Problems (Problem 1/2: Flat Geometry, No Depth) — describes a pre-implementation state that no longer exists in any form; both are fully resolved in shipped code and are historical motivation, not current or intended state.
- Implementation Order table, Key Files to Modify, Success Criteria — project-management scaffolding for a now-largely-complete plan (Success Criteria's substance was migrated into `visual-system-art-direction.md` instead).

## `docs/archive/TOUCHBAR-TECHNIQUES.md` (SP6a, SP6b)
- §1 Executive Summary, §4 Rendering Techniques, §5 Animation & Motion, §7 Game Design Patterns, §8 World Building & Terrain, §9 Performance Engineering, §12 Recommended Architecture & Roadmap — every one of these describes techniques for the **retired MTMR/bash-shell tamagotchi prototype** that predates and was fully replaced by the native daemon; none have any bearing on the shipped system. A single historical footnote survives in `touch-bar-prior-art.md`'s rendering-taxonomy row.
- §1 line 36 / §3.1 (MTMR "Our Current Stack"), §3.2 BetterTouchTool, §6.1/§6.4/§6.5/§6.6 (MTMR/BTT-specific input mechanisms), §6.2 Input Latency by Tool, §10.1/§10.2/§10.6/§10.7 — same superseded-runtime or out-of-subject reasoning; the native mechanism each nominally maps to is separately documented from code where a live equivalent exists.

## `docs/archive/plan/PLAN.md` (not assigned to any wave — see note below)
- **⚑ Entire file** — never individually traced by a wave sub-matrix. The survey's own disposition (`retire-archive`) already judged this a project-execution artifact whose durable facts (the "Shared Interfaces (Frozen After Phase 1)" bullets: IPC wire format, feed path) are secondary copies of `PUSHLING_VISION.md`/code-level truth, both fully migrated elsewhere (`ipc-wire-protocol.md`, `hook-sensory-system.md`). The survey's conditional "mint a Shared Interface Contracts Reference concept **only if** no other surveyed doc covers these contracts" was correctly never triggered — SP2a (IPC), SP2b (schema/deploy), and SP2a's `mcp-tool-contract.md` (tool signatures) collectively already cover every bullet. No content loss; confirmed in this pass, not a prior wave's oversight.

## `docs/archive/plan/teams/TEAMS.md` (not assigned to any wave — see note below)
- **⚑ Entire file** — same situation as `PLAN.md`. The survey's own disposition (`retire-archive`) judged its unique content (agent roster, file-ownership table, sequential/parallel-track coordination rules) as describing a one-shot March 2026 build process superseded by the live M9 STAR coordination protocol; its durable facts (frame/node/latency budgets, tool lists, subsystem responsibilities, schema) are secondary copies of `PUSHLING_VISION.md`/`docs/archive/TOUCHBAR-TECHNIQUES.md`/`CLAUDE.md`, all migrated elsewhere. Confirmed in this pass: no wave found unique canon-worthy content here beyond what those primary sources already carry.

## `docs/archive/plan/phase-1-foundation/PHASE-1.md` (SP2b)
- **P1-T1-01** (Xcode project claim, empty-directory snapshot) — explicitly superseded per the survey's own driftSignal (no `.xcodeproj` exists; the SPM package is the shipped form); scaffolding-era history, not schema/persistence content.

# Per-Source Tables

Condensed; full verbatim reasoning, corrected numeric values, and code
citations live in the named `SPx.md` sub-matrix.

# SP4 Deferral Findings

SP4's own traceability deferred three `PHASE-5.md` sections to other waves
without confirming they'd actually land. This pass ran that confirmation:

- **P5-T1-08 "Speech Cache & Replay"** — SP4 explicitly flagged this as an
  unresolved deferral ("if no other wave picks it up this is a gap to flag,
  not a silent drop") and no wave did, through SP8's dedicated gap-closure
  pass — the consolidated matrix had no row for it at all until this pass.
  Code check found the cache itself **is** built
  (`Pushling/Sources/Pushling/Speech/SpeechCache.swift`, wired into
  `GameCoordinator`/`SpeechCoordinator`, matching the 100-utterance FIFO cap
  and schema exactly) but its two consumer scenarios — idle replay and Sage
  reminiscence — are both dead code (`recentUtterances()` and
  `failedSpeechEntries()` have zero callers). This pass's own "gap closed"
  claim was itself overstated — recorded in this matrix but never actually
  inlined into a concept doc; **RM-FINALIZE caught the discrepancy, and
  RM-FIX-P5T108 landed it for real**: see the PHASE-5.md per-source table
  row above for the full finding.
- **P5-T1-12 "Apex World-Shaping Speech"** — did **not** land anywhere
  before this pass. `growth-stages.md` and `awakening-pipeline.md` both
  name-drop "world-shaping" as an Apex-stage flavor phrase, but neither
  documents the actual mechanism. Code check found a real, fully-wired
  mechanism (`SpeechCoordinator.checkWorldShaping`, an 18-keyword trigger
  table, a 5-minute cooldown, wired to `debugForceWeather` in
  `GameCoordinator.wireSpeechSystem()`) — plus a genuine new finding: 4 of
  the mechanism's 8 named effects (`night`/`dawn`/`bloom`/`shake`) aren't
  valid `WeatherState` cases and silently no-op when triggered. **Gap
  closed this pass**: added as a new section,
  [Apex Speech-Triggered World Effects](/SYSTEMS/weather.md#apex-speech-triggered-world-effects-p5-t1-12),
  in `weather.md`.
- **P5-T1-16 "Between-Session Autonomous Speech"** — **partial gap,
  unresolved.** Of the table's 7 trigger rows (commit-eaten, waking-up,
  getting-sleepy, high-satisfaction, weather-reaction, idle-thought,
  dream-mumble), only two are documented and code-confirmed elsewhere:
  commit-eaten reactions ([commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md))
  and dream mumble ([journal-and-dreams](/REFERENCE/journal-and-dreams.md)).
  A code search for the other five (waking-up greeting, sleepy yawn,
  satisfaction heart, weather-triggered speech, idle-thought) found no
  matching `SpeechCoordinator`/`GameCoordinator` call sites beyond the two
  confirmed rows plus two unrelated triggers (mutation-badge announcements,
  surprise-triggered speech) that aren't part of this table at all. This
  looks like a real, still-open gap between design intent and shipped
  behavior — `speech-milestones.md`'s own "Post-Milestone Progression"
  section already flags one adjacent piece of this (no frequency-cap code
  for the Critter first-word's "say it again max once per hour" idle
  repeat). **Closed this pass (SP8c)**: the 5 unbuilt triggers
  (wake-greeting, sleepy-yawn, satisfaction-heart, weather-triggered
  speech, idle-thought) are preserved as 📐 unbuilt design intent in
  [Between-Session Autonomous Speech](/FEATURES/interactivity-unbuilt.md#between-session-autonomous-speech--unbuilt-p5-t1-16)
  per the lossless-preservation mandate — the wire-or-descope decision
  itself remains open, deferred to a phase-3-backlog item rather than
  resolved here.

## `README.md` (repo root)

Not assigned to any wave for content migration — survey disposition
`keep-as-is` (dispositionReason: presentation/marketing, not canon; every
substantive fact it states already has a primary canonical source
elsewhere). This SP8 pass repointed 3 of its outbound doc links to their new
bundle homes (`docs/REFERENCE/creature-voice-design.md`,
`docs/RESEARCH/tts-engine-evaluation.md`, `docs/REFERENCE/index.md`) — see
this wave's return message for the before/after diff. No content rows to
trace.

## `PUSHLING_VISION.md`

| Section | → Target concept | Status | Wave |
|---|---|---|---|
| Philosophy, Dual-Layer Embodiment Model, Core Principles, What Makes This Different | `/vision.md` | migrated | SP3a |
| Identity: Born from Your Git History | `/REFERENCE/creature-identity-birth.md` | migrated, corrected (historical-seeding model superseded by `EggAccumulator`) | SP3a |
| Growth Stages table, Adaptive XP curve | `/REFERENCE/growth-stages.md` | migrated, corrected (R1: code XP thresholds + `egg` naming are canon; commits-eaten table preserved as superseded history) | SP3a |
| Stage Transitions ceremony | `/REFERENCE/growth-stages.md#stage-transition-ceremony` | migrated, verified | SP3a |
| Personality System, Emotional State, Circadian cycle | `/REFERENCE/personality-emotional-state.md` | migrated, corrected/verified; Emotional Visual Feedback table (1507–1524) inlined this pass, was previously dropped in SP3a↔SP6a↔SP5 deferral ping-pong | SP3a, RM-VISION |
| Control Architecture: 4-Layer Behavior Stack, Blend Controller | `/SYSTEMS/behavior-stack.md` | migrated, verified + extended (sub-timing); the 12-item cat-behavior catalog (158–171) and absence-scaled wake/lantern behaviors (Core Loop, 393–404) inlined this pass as the Autonomous layer's own catalog, both fully shipped and code-verified | SP3a, RM-VISION |
| Touch-AI Interaction Priority | `/SYSTEMS/behavior-stack.md`, `/SYSTEMS/ai-command-queue.md` | migrated, corrected (only steps 1-3 built; pause/queue-clear/co-presence bonus unbuilt) | SP3a |
| Visual Form: Cat-Esque Spirit Creature | `/REFERENCE/creature-visual-design.md`, `/REFERENCE/procedural-animation.md` | migrated; Diamond Indicator's 3 residual "When AI Acts" cues (see below) closed out this pass as confirmed-unbuilt, not left deferred | SP6a, RM-VISION |
| Architecture: Process Topology, Rendering Target, State Persistence, IPC | `/ARCHITECTURE/system-architecture.md`, `/ARCHITECTURE/ipc-wire-protocol.md` | migrated | SP2a |
| MCP Integration: Session Start Awakening | `/SYSTEMS/awakening-pipeline.md` | migrated, corrected (6 variants, not the doc's collapsed 4) | SP7 |
| MCP Integration: the `pushling_*` tool tables + Key Design Principles | `/ARCHITECTURE/mcp-tool-contract.md` | migrated, reconciled against code | SP2a |
| MCP Integration: When AI Acts, Human Sees It | `/REFERENCE/creature-visual-design.md#three-designed-but-unbuilt-distinction-cues` | migrated — the diamond materialize/dissolve/split/reconverge state machine was already documented under the Diamond Indicator; the 3 finer per-action cues (speech-bubble diamond icon, wand-sparkle, sparkle-trail) grep-confirmed unbuilt and recorded there this pass, closing the prior "deferred to SP6a" placeholder | SP2a, RM-VISION |
| The Creation Systems intro, Teach System, Behavior Breeding | `/SYSTEMS/teach-system.md` | migrated, corrected (16 tracks not 13; dream integration designed-but-unwired) | SP3b |
| The Objects System, Companions | `/SYSTEMS/world-objects-system.md` | migrated, corrected (preset-catalog mismatch, 15 not 14 templates) | SP3b |
| The Nurture System | `/SYSTEMS/nurture-system.md` | migrated, corrected (trigger-vocabulary mismatch) | SP3b |
| The Surprise & Delight System, Mutation Badges | `/REFERENCE/surprise-catalog.md` | migrated, verified (78 surprises, 10 badges exact); all 78 individual designs (1267–1359) inlined this pass — previously only counts/ID-ranges with a "VISION is canonical enumeration" pointer, a root-cause-(a) violation | SP3b, RM-VISION |
| Git Integration: The Journal, Dream Journal, Core Loop Sleep row | `/REFERENCE/journal-and-dreams.md` | migrated, corrected/extended (18 journal types not 14; `DreamEngine` far richer than the doc describes); commit-while-asleep mumble/stir mechanic (line 1405) confirmed unbuilt and documented as a gap in `/SYSTEMS/commit-feeding-xp.md#commit-while-asleep-designed-not-wired` this pass, cross-linked here | SP3b, RM-VISION |
| Technical Performance table | `/REFERENCE/performance-budgets.md` | migrated verbatim (design targets, not instrumented assertions) | SP3b |
| Future Feature Roadmap, Installation (aspirational) | `/FEATURES/roadmap.md` | migrated verbatim; distribution-story correction added this pass (see edits); Working-row ambient behaviors (ear-tracking, commit-message daydreams) added as a confirmed-unbuilt Tier 3 item this pass | SP3b, RM-VISION |
| Visual System: Art Direction, 8-Color Palette, World Composition, Wow-Factor Moments, HUD Philosophy | `/REFERENCE/visual-system-art-direction.md`, `/REFERENCE/palette.md`, `/SYSTEMS/sky-celestial.md`, `/SYSTEMS/weather.md`, `/SYSTEMS/world-complexity-ambient-effects.md` | migrated across multiple concepts, split per subject-authority | SP6a, SP6b |
| The World: Exploring the Touch Bar (parallax, repo landmarks) | `/SYSTEMS/world-terrain-parallax.md`, `/REFERENCE/repo-landmarks.md` | migrated, corrected (4 parallax layers not 3) | SP6a, SP6b |
| Touch Interactions, Continuous Touch & Object Interaction, Creature-Initiated Invitations, Human Milestones, Mini-Games, The P Button | `/REFERENCE/gesture-response-map.md`, `/SYSTEMS/invitation-system.md`, `/SYSTEMS/touch-milestones.md`, `/SYSTEMS/mini-games.md`, `/RESEARCH/touch-bar-menu-patterns.md` | migrated, corrected throughout; P Button's full gas-gauge/tap-sequence/stats-popup choreography (1485–1504) inlined into `touch-bar-menu-patterns.md`'s "Outcome" section this pass — SP5 had claimed this migration but the choreography itself was absent | SP5, RM-VISION |
| The Commit-as-Food System | `/SYSTEMS/commit-feeding-xp.md` | migrated, corrected (17 commit types not 15; live award path bypasses `XPCalculator`); per-type *physical* choreography (442–460 — backward-eating reverts, both-sides merges, force-push knockback, food-coma, achievement popups) confirmed unbuilt this pass and inlined as a labeled design-intent table, replacing a bare "full timings per VISION" pointer | SP7, RM-VISION |
| Claude Code Hooks: Full Dev Session Awareness | `/SYSTEMS/hook-sensory-system.md` | migrated, corrected (per-hook latency budgets disambiguated) | SP7 |
| Speech Evolution (First Word, Audio Voice/TTS) | `/REFERENCE/speech-milestones.md`, `/SYSTEMS/voice-tts-stack.md` | migrated, both milestones confirmed shipped (see R3-amended) | SP4 |

## `pushling/CLAUDE.md`

| Section | → Target concept | Status | Wave |
|---|---|---|---|
| Essential Commands | `/OPERATIONS/build-run-deploy.md` | migrated, extended (double-launch case, LaunchAgentManager toggle) | SP2b |
| Critical Knowledge: What to Watch For (15-row table) | `/OPERATIONS/development-pitfalls.md#the-pitfall-table` | migrated verbatim + code-verification annotations; **RM-ARCH restored** 2 rows (TTS audio glitches, State file corruption) silently dropped by an uncommitted pre-WO-1 edit before SP2b ever saw a 15-row (not 17-row) table — no drop record existed for either; table is 17 rows again | SP2b, RM-ARCH |
| State & evolution bullets | `/OPERATIONS/development-pitfalls.md`, `/OPERATIONS/persistence-and-recovery.md` | migrated, corrected (checkEvolution "after every persist" true at only 1 of 3 sites); **RM-ARCH restored** the `persistXPAndStageSync()` shutdown-time sync variant (code-verified, one call site in `GameCoordinator.shutdown()`), previously undocumented in both target concepts | SP2b, RM-ARCH |
| Review Focus Areas, Code Quality | `/OPERATIONS/review-focus-areas.md` | migrated, verified (Swift has 29 files over the 500-line ceiling — real current gap); **RM-ARCH restored** the GOLD Zone Partitioning table (5 zones), the 6 Issue Categories' severity tags, and the VIOLET 15-category audit checklist (corrected: 30→78 surprises) — all three had been silently dropped or overstated as "no longer maintained" without a matrix drop record | SP2b, RM-ARCH |
| This Repo (stack list), Architecture (source-tree map), hot-reload paragraph | `/ARCHITECTURE/system-architecture.md` | **gap found and filled this pass** — see Losslessness Guard below | SP8 |
| MCP Server Rules ("helpful error messages... explain what's valid") | `/ARCHITECTURE/mcp-tool-contract.md` | **RM-ARCH: gap found and filled this pass** — never previously traced to any concept; restored as a code-verified-followed principle (every `mcp/src/tools/*.ts` validation branch names valid alternatives) | RM-ARCH |
| Git Hook Rules ("Never modify the commit itself") | `/SYSTEMS/hook-sensory-system.md` | **RM-ARCH: gap found and filled this pass** — never previously traced; restored as an explicit constraint section | RM-ARCH |
| Persona: Pause Triggers, Agent Failure protocol, Compound Requests, Missing Infrastructure fallback, Built-In Skills/Plugins table, canonical Code Quality table (Python/Shell/Lua), GitHub edit-not-comment rule, After Monk Returns step 5 / Session Reminder 8 | *(escalated, not a bundle concept)* | **RM-ARCH: confirmed lost, not restorable into `docs/` bundle concepts** — these are Samantha/CLAUDE.md persona and process rules, not system documentation; the bundle documents the software, not the orchestrator's own working rules. Flagged for Samantha to route a CLAUDE.md/output-style fix (gated edit) rather than migrated here | RM-ARCH |

## `mcp/README.md`

Disposition `keep-as-is`. | Transport, Architecture (two channels) | `/SYSTEMS/mcp-server.md`, `/ARCHITECTURE/system-architecture.md` | migrated | SP2a, SP2b. The 9 Tools table → `/ARCHITECTURE/mcp-tool-contract.md` (SP2a). Setup/Register/Dev-commands and File Structure tree → see Intentional Drops above (SP2a dropped, SP2b re-included registration substance).

## `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` (SP5)

| Section | → Target concept | Status |
|---|---|---|
| Pipeline Overview, Gesture Types (13→12), Gesture Target Resolution | `/SYSTEMS/touch-input-pipeline.md` | migrated, corrected |
| Routing Rules | `/REFERENCE/gesture-response-map.md`, `/SYSTEMS/touch-milestones.md` | migrated, corrected |
| Camera Controller (pan/zoom math) | `/SYSTEMS/camera-and-parallax.md` | migrated, corrected (R2: pan/zoom disabled behind a `FIXED-VIEWPORT` early return; documented as transitional, intent-canon preserved); **RM-TOUCH restored** the §4 two-finger-drag zoom fallback (200pt = 1.0 zoom level, left/right) as unbuilt intent into `/FEATURES/interactivity-unbuilt.md#live-pan--zoom` — SP5's "migrated, corrected" claim had dropped this input mapping entirely (no matrix drop row covered it) |
| §5 Creature Scaling Under Zoom | `/FEATURES/interactivity-unbuilt.md#live-pan--zoom` | migrated-as-unbuilt (SP8c, reclassified from dropped) |
| §6 Zoom Detail Tiers | `/FEATURES/interactivity-unbuilt.md#live-pan--zoom` | migrated as unbuilt, **corrected this pass (RM-TOUCH)** — SP5 preserved tier thresholds/hysteresis only; the full per-tier visual-changes table (whiskers/inner-ears/toe-pads/toe-beans/ear-tufts/nose-highlight, with exact per-tier alpha values) was dropped via a dangling deferral to a "creature-visual concept" section that never existed. Restored in full, code-verified against `ZoomDetailController.swift` |
| §7 Parallax Response | `/SYSTEMS/world-terrain-parallax.md` | migrated, corrected (4 layers not 3) — confirmed landed, SP5's deferral to SP6a did close |
| §8 Frame Update Order | `/SYSTEMS/camera-and-parallax.md#frame-update-order` | **gap closed this pass (RM-TOUCH)** — SP5 deferred this to "SP6a's scene/rendering concept," but SP6a's sub-matrix never picked it up (no row, no drop) and the ordering fact fell between waves. Restored as a live, code-verified section (`PushlingScene.update`'s cinematic→physics→world→render sequence) |
| §9 Known Edge Cases | `/SYSTEMS/touch-input-pipeline.md`, `/REFERENCE/gesture-response-map.md`, `/SYSTEMS/camera-and-parallax.md` | migrated, corrected (real two-stage tap timer); **RM-TOUCH restored** the Coordinate Conversion for Hit-Testing sub-case (zoom-compensated `worldX` formula + high-zoom hit-test-miss caveat) as unbuilt intent into `/FEATURES/interactivity-unbuilt.md#live-pan--zoom`, with a cross-link from `touch-input-pipeline.md` — same dangling-deferral-to-SP6a pattern as §6/§8 above; no code implements the conversion, so it's intent-canon, not a live fact |

## `docs/archive/3D-RENDERING-RESEARCH.md` (SP6a §14 only; SP6b §1-13/§15)

| Section | → Target concept | Status |
|---|---|---|
| §1-13 (8 option analyses), §11 Doom Precedent, §12 Aspect Ratio Problem, §13 Comparison Matrix | `/RESEARCH/3d-rendering-feasibility.md` | migrated; **RM-VISUAL restored** the SceneKit rim-lighting nuance ("partially defeats the purpose of using 3D") and a missing Outcome reconciliation note (shipped multiply-blend lighting overlay vs. the recommended normal-mapped sprites) | SP6b, RM-VISUAL
| §14 Enhanced 2.5D Stack, Clouds, Cat Visual Enhancement | `/SYSTEMS/rendering-stack-2-5d.md`, `/SYSTEMS/sky-celestial.md#clouds`, `/REFERENCE/creature-visual-design.md`, `/REFERENCE/procedural-animation.md` | migrated, reconciled (sprite-stacking, not the proposed 10-18 texture-slice technique); **RM-VISUAL restored** the 8-row Animation Refinements table into `procedural-animation.md` (code-verified: diagonal gait genuinely shipped in `PawController`/`CreatureNode`, most other rows unbuilt), the Paws/Belly/Mouth per-part specs into `creature-visual-design.md` (Paws+Mouth shipped, Belly unbuilt), the Color & Personality Visual Expression table into `creature-visual-design.md` (unbuilt), the mid/background depth-blur half of this row into `rendering-stack-2-5d.md`'s Deferred section (unbuilt), and the 9-item Implementation Priority list into `creature-visual-design.md` (historical, most items now shipped under other concepts) | SP6a, RM-VISUAL
| §14 What We Explicitly Reject | *(dropped)* | see Intentional Drops | SP6a
| §15 Sources | `/RESEARCH/3d-rendering-feasibility.md` Citations | migrated (43-source bibliography) | SP6b

## `docs/archive/IPC-PROTOCOL.md` (SP2a — entire file)

| Section | → Target concept | Status |
|---|---|---|
| Overview, Transport Details | `/ARCHITECTURE/ipc-wire-protocol.md` | migrated; **RM-ARCH restored** the "accepted, not when-complete" wire semantic (SP2a's migration had silently dropped it — no corresponding content existed anywhere in the bundle) |
| Request/Response Format, Error Codes | `/ARCHITECTURE/ipc-wire-protocol.md`, `/ARCHITECTURE/ipc-command-catalog.md` | migrated, corrected (`STAGE_GATE`→`STAGE_GATED`; ~10 real codes added) |
| Session Management (Connect/Disconnect/Ping) | `/ARCHITECTURE/mcp-session-lifecycle.md`, `/ARCHITECTURE/ipc-command-catalog.md` | migrated, corrected (connect snapshot promises fields the code never sends) |
| Pending Events | `/ARCHITECTURE/pending-events.md` | migrated, corrected (buffer-overflow is cursor-gap detection, not push-time); **RM-ARCH restored** the full 13-type Event Types field catalog, split honestly into 3 Live types (`commit`, `hook`, `events_dropped`) vs. 10 designed-only type strings with **zero live `EventBuffer.push` call sites** — a deeper finding than the original loss report, discovered by grepping every push call site in the codebase (only 2 exist) |
| Tool Command Details (9 tools) | `/ARCHITECTURE/mcp-tool-contract.md`, `/ARCHITECTURE/ipc-command-catalog.md` | migrated, reconciled against code; **RM-ARCH restored** the full response-`data`-shape table for move/express/perform/world/teach/nurture into `ipc-command-catalog.md` — every shape code-verified and corrected against the archived doc's guesses (e.g. `move`'s real field is `position_x` not `position`; `world create`'s object has no `object_id`/`preset` fields; `world companion` has no `companion_id`; `teach compose` has no `draft_id`; `nurture habit` has no `habit_id`; `perform` has no `stage_ok`) |
| Wire Examples, Implementation Notes | `/ARCHITECTURE/ipc-wire-protocol.md` | migrated; **RM-ARCH corrected** the "sequential per connection, concurrent across connections" claim — code-verified (`SocketServer.swift`) to be a single global serial `DispatchQueue` with no cross-connection concurrency at all, stricter than the archived claim |

## `docs/archive/TTS-RESEARCH.md` (SP4 — entire file)

| Section | → Target concept | Status |
|---|---|---|
| Executive Summary, §1 Growth-Stage Voice Concept | `/SYSTEMS/voice-tts-stack.md`, `/REFERENCE/creature-voice-design.md#why-voice-progression-is-the-entire-feature` | migrated, corrected (3 tiers not 6); RM-VOICE restored the 5-reasons design rationale and the 6-item utterance-source list (5 of 6 realized in shipped systems, `pushling_teach` vocabulary the one confirmed-unbuilt item) into `creature-voice-design.md`, correcting SP4's overstated "(see note)" migration claim |
| §2-14 Options 1-13, §15 Comparison Matrix | `/RESEARCH/tts-engine-evaluation.md` | migrated (condensed to a comparison table); RM-VOICE restored supplementary per-option detail (Novelty Voices table + word-boundary callbacks for Option 1, x_low tier/named voices/`length_scale` for Option 3, Kokoro ONNX quantization ladder/44% win-rate/voice-blend recipe for Option 9, the Bark-vs-Kokoro quantified comparison for Option 5, the full espeak-ng parameter table for Option 8) in a new "Supplementary Evaluation Detail" section, code-verified against `SherpaOnnxBridge`/`VoiceSystem` |
| §16 Recommended Architecture | `/SYSTEMS/voice-tts-stack.md`, `/RESEARCH/tts-engine-evaluation.md` | migrated, corrected (download-on-demand, no AVSpeech fallback); RM-VOICE restored the explicit CPU-first/profile/then-CoreML staged rollout plan into `tts-engine-evaluation.md`, code-verified as never acted on (`SherpaOnnxBridge` runs CPU-only, no CoreML/ANE reference anywhere in `Voice/`) |
| §17 Voice Character Design | `/REFERENCE/creature-voice-design.md` | **corrected this pass** — SP4's "migrated, merged" claim was half true: only the Emotion→Voice and Personality→Voice tables had landed; the 5 per-stage voice-recipe blocks (Drop/Critter/Beast/Sage/Apex pitch/speed/pacing numbers) were missing entirely. RM-VOICE restored them as a new "Per-Stage Voice Character Recipes" table, code-verified against `VoicePersonalityCalculator` (confirmed the recipes never shipped — the live calculation uses one continuous formula per stage, not per-stage recipe blocks) |
| §18 Implementation Roadmap | *(dropped, Performance Targets sub-table migrated)* | see Intentional Drops |
| Appendix A/B (License Summary, Repository Links) | `/RESEARCH/tts-engine-evaluation.md` | migrated |

## `docs/archive/CREATURE-VOICE-DESIGN.md` (SP4 — entire file)

| Section | → Target concept | Status |
|---|---|---|
| §1 Design Philosophy | `/REFERENCE/creature-voice-design.md` | migrated |
| §2 Voice Evolution Arc (pipeline mechanics) | `/REFERENCE/creature-voice-design.md#superseded-design-history-the-original-pipeline-concept` | migrated as superseded design history; RM-VOICE restored the Drop chirp synthesis spec (sine+pink-noise+envelope numbers, timing, per-emotion chirp mapping), the Critter syllable-repetition mitigations (pitch variance/micro-variation/volume envelope, ~624-sound capacity math), and the Beast word-selection heuristics (short words, name, emotion words, commit-message vocabulary) — SP4's "preserved in the superseded-pipeline summary" claim for the mitigations was false, corrected this pass |
| §3 Pitch, §4 Formant Shifting, §5 Speaking Rate, §6 Vocal Texture | `/RESEARCH/voice-psychoacoustics.md` | migrated; RM-VOICE spot-checked and confirmed high-fidelity, no action taken (audit found this migration essentially lossless) |
| §7 Sound Design References | `/RESEARCH/game-voice-sound-design.md` | migrated; RM-VOICE spot-checked and confirmed lossless, no action taken |
| §8 Hybrid Voice Pipeline, §9 Audio Processing on macOS | `/REFERENCE/creature-voice-design.md#superseded-design-history-the-original-pipeline-concept`, `/SYSTEMS/voice-tts-stack.md#aspirational-the-never-built-formant--chorus--breathiness-layer` | migrated as superseded history (never-built `AVSpeechSynthesizer` architecture); RM-VOICE restored the Stage-Router→Emotion-Modulator→Personality-Shaper architecture, the full 9-step processing-chain order with its "order matters for quality" rationale, and the 20ms Beast word-boundary crossfade into `creature-voice-design.md`; restored the previously-unnamed **Option D (`AUAudioUnit`/Vocal Transformer)** framework choice into `voice-tts-stack.md`'s Aspirational section — SP4's "§4 Options A-D... migrated" claim omitted Option D at the destination entirely |
| §10 The First Word Moment | `/REFERENCE/speech-milestones.md` | migrated — shipped as Milestone 2, R3-amended (not rejected); **corrected this pass** — SP4's claims that the "audio-design sequence" and "post-first-word progression table" had migrated were false (verified: neither existed in `speech-milestones.md`). RM-VOICE restored the full 6-step audio choreography (pause/intake/word/pause with all numeric parameters) as design-intent-not-shipped, the commits-after-first-word frequency-progression table, the first-word-choice ranking (including the "code"/"commit" option), the 4-bullet name-choice rationale, and the journal-entry `context` field / dreams-MCP-surfacing / Sage-reminiscence intent (the last flagged as an open cross-concept gap with `journal-and-dreams.md`, not resolved; **RM-FINALIZE closed this gap** — bidirectional cross-link added, with a new `journal-and-dreams.md#sage-idle-reminiscence--design-intent-unbuilt-p8-t2-07` section documenting the general P8-T2-07 mechanic as unbuilt (zero callers for `recentUtterances()`/`failedSpeechEntries()`, re-verified) and calling out the first-word-specific reminiscence line as a category with no home among PHASE-8's six) |
| §11 Personality-Driven Voice Variation | `/REFERENCE/creature-voice-design.md` | migrated, corrected (Specialty axis + 11-field schema flagged aspirational vs. shipped 4-axis/4-field); **corrected this pass** — SP4's "5-axis table... migrated" claim covered only 3 of 5 axes (Energy/Verbosity/Specialty); Focus and Discipline's voice-effect rows were missing. RM-VOICE restored them (code-verified: `VoicePersonalityCalculator` reads only `energy`/`verbosity`, confirming Focus/Discipline voice mapping is genuinely unbuilt, distinct from their separate, already-documented text-filtering role in `speech-filtering.md`), plus the `VoiceProfile` schema's 11 field-value ranges and the Voice-Selection-for-TTS-Base per-voice verdict table (Samantha/Alex/Zarvox/Fred), both previously reduced to bare labels |
| §2/§10/opening-closing dialogue framing, §12 Roadmap, Appendix A/B | *(dropped)* | see Intentional Drops |

## `docs/archive/EMBODIMENT-REVIEW.md` (SP2a §4; SP7 §1,2,3,5,6,7,8)

| Section | → Target concept | Status | Wave |
|---|---|---|---|
| §1 Philosophy (three forces) | `/SYSTEMS/embodiment.md#three-forces` | migrated | SP7 |
| §2 How Embodiment Works | `/SYSTEMS/embodiment.md` | migrated, corrected | SP7 |
| §3 The Awakening Pipeline | `/SYSTEMS/awakening-pipeline.md` | migrated, corrected (personality axis count 5→4; egg-stage awakening bug found) | SP7 |
| §4 MCP Tools: The Motor Cortex | `/ARCHITECTURE/mcp-tool-contract.md` | migrated, re-verbatimed against `.ts` source; **RM-ARCH restored** the `pushling_move` response's `narrative` field (confirmed **live**, not aspirational — `move.ts generateMoveNarrative()`, including weather modulation) and the `pushling_express` response's `visual` pose-description field, plus the Egg-stage speak refusal's exact live text vs. the archived example's different, nonexistent-`STAGE_GATE` wording | SP2a, RM-ARCH |
| §5 The Sensory Loop: Hooks | `/SYSTEMS/hook-sensory-system.md` | migrated, corrected | SP7 |
| §6 Embodiment Language Guide | `/OPERATIONS/embodiment-language-guide.md` | migrated verbatim | SP7 |
| §7 The Embodiment Test | `/SYSTEMS/embodiment.md#the-embodiment-test` | migrated | SP7 |
| §8 File Reference | `/SYSTEMS/embodiment.md#file-reference` | migrated, corrected (4 missing helper modules added) | SP7 |

## `docs/archive/TOUCHBAR-TECHNIQUES.md` (SP6a deferred-confirm; SP6b primary)

| Section | → Target concept | Status |
|---|---|---|
| §2 Hardware Specifications | `/REFERENCE/touch-bar-hardware.md` | migrated |
| §3.3 Native NSTouchBar API | `/REFERENCE/touch-bar-private-api.md` | migrated, corrected (Nuclear Option's `/tmp/` IPC sketch replaced with the real socket+SQLite architecture); **RM-VISUAL restored** the 6-row NSView-subclass capability table (SKView/Custom NSView+drawRect/NSImageView/CALayer proven, MTKView/WKWebView theoretical) as a new "NSView Subclass Capability Survey" section |
| §3.4-3.6 Software Ecosystem comparisons | `/RESEARCH/touch-bar-prior-art.md` | migrated; **RM-VISUAL restored** the "Key Technique" column (from §3.3's separate proven-games table) and the per-project URL column onto the Games/Tools tables |
| §6.3 Positional Touch | `/REFERENCE/touch-bar-private-api.md#touch-delivery-the-corrected-caveat` | migrated, corrected (claimed sub-pixel `touchesMoved` tracking doesn't hold for `SKView`); **RM-VISUAL restored** the "600-unit coordinate space" TouchBreakout datum into `touch-bar-prior-art.md`'s Games table |
| §10.3 Sensor Input | `/REFERENCE/touch-bar-hardware.md#sensor-availability` | migrated, annotated (none of the 3 sensors wired); **RM-VISUAL restored** the camera row's "face detected = creature notices you" game-use intent, which the earlier annotation pass had silently dropped |
| §10.4 OLED Tricks | `/REFERENCE/oled-rendering-techniques.md` | migrated, reconciled |
| §10.5 Multi-Touch-Bar Multiplayer, §10.8 Doom Was Here, §11 Existing Projects Catalog | `/RESEARCH/touch-bar-prior-art.md` | migrated; **RM-VISUAL restored** ~10 project repository URLs onto the Games and Tools tables (see §3.4-3.6 row above, same fix) |
| §1/§3.1/§3.2/§4/§5/§6.1/§6.2/§6.4-6.6/§7/§8/§9/§10.1-2/§10.6-7/§12 | *(dropped — superseded MTMR/bash runtime)* | see Intentional Drops |

## `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` (SP6a Secs 3,4,6,7,8,12; SP6b Sec 9)

| Section | → Target concept | Status |
|---|---|---|
| Sec 3 Design Philosophy | `/REFERENCE/visual-system-art-direction.md` | migrated; **RM-VISUAL restored** the "Animation Over Detail" pillar (Celeste/Madeline framing) as its own named section, previously only thinned into other principles' prose |
| Sec 4 Proportions & Shape Language | `/REFERENCE/creature-visual-design.md` | migrated, superseded by code-verified per-stage table; **corrected this pass** — the supersession claim only held for the sizes/eye-radius/ear-ratio columns, not head-size/head-percentage (which the code-verified table never carried). RM-VISUAL restored the historical head-percentage table (Critter 52%->Apex 36%) and the Chibi Proportion Guideline into `creature-visual-design.md`, and the Vector Advantage rationale (sub-pixel antialiasing expressiveness) into `visual-system-art-direction.md` |
| Sec 5 Stage-by-Stage Recommendations | `/REFERENCE/creature-visual-design.md` | migrated as verification input; **corrected this pass** — "verification input" wasn't a drop-justification for the recommendation cells that were never adopted. RM-VISUAL restored the Sage/Apex-exclusive behavior intent (code-verified: `meditation` genuinely shipped Sage+-exclusive in `BehaviorSelector`/`BehaviorChoreography`; contemplation, Sage-exclusive slow-blink, zoomies-rarity, Apex ethereal-float/phase-shift/cosmic-awareness, and multi-tail emotion-expression all confirmed unbuilt) and the unbuilt visual-polish design intent (fur tips, emotion-responsive third eye, reactive crown, egg crack marks/bounce, Drop core-glow shimmer, Beast aura pulse/swagger, Apex aura-regression note) into `creature-visual-design.md` |
| Sec 6 Feature Introduction Timeline | `/REFERENCE/creature-visual-design.md#feature-introduction-timeline` | migrated, corrected (Apex dissolution-particle progression unbuilt); **RM-VISUAL restored** the Paws row (toe-pad progression, code-verified shipped Beast+ via `showToes: true`) and confirmed the Drop transparency row (0.88-0.92 semi-translucency) is unbuilt, into `creature-visual-design.md`'s new Paw/Mouth/Belly Construction section |
| Sec 7 Animation Architecture ("what NOT to do") | `/REFERENCE/procedural-animation.md` | migrated; skeleton-upgrade phases dropped (see Intentional Drops) |
| Sec 8 Procedural Animation Formulas | `/REFERENCE/procedural-animation.md` | migrated, extensively reconciled (only tail/camera ship spring-family math; ears/whiskers use plain `SKAction`); **RM-VISUAL restored** the full Emotion-to-Movement Mapping table (5 states x 5 parameters, confirmed unbuilt, distinct from the shipped single-axis Energy breathing override in `personality-emotional-state.md`), the 3 missing critical-damper Spring Presets (Sad droop/Tail settle/Head tracking), and the NoiseIdleSystem walk-attenuation (0.3x, unbuilt) plus whisker acceleration-response (unbuilt) notes |
| Sec 9 OLED Rendering Techniques | `/REFERENCE/oled-rendering-techniques.md` | migrated, per-technique build status annotated (SDF Glow corrected Future→shipped) |
| Sec 1-2, 10-12 | *(not this wave's subject / dropped)* | see Intentional Drops |

## `docs/archive/plan/PLAN.md`, `docs/archive/plan/teams/TEAMS.md`

Not traced by any wave sub-matrix — see the **⚑** entries under Intentional
Drops above; both confirmed in this pass to hold no unique canon content
beyond what's already migrated from their named primary sources.

## `docs/archive/plan/TODO-CONTEXT-MENU-SYSTEM.md` (SP5 — entire file)

| Section | → Target concept | Status |
|---|---|---|
| Problem Statement, Design Goals | `/RESEARCH/touch-bar-menu-patterns.md` intro, `/FEATURES/interactivity-unbuilt.md` | migrated |
| Example Menu Definitions | `/RESEARCH/touch-bar-menu-patterns.md#context-specific-menu-contents-as-designed` | migrated (as prose, not Swift literals) |
| UX Alternatives: Hardware Constraints, Six Patterns Evaluated, Recommended Architecture, Long-Press Disambiguation, Affordance, Nested Submenus, Accessibility, Context-Specific Contents | `/RESEARCH/touch-bar-menu-patterns.md` | migrated, corrected (palette hex values wrong; 5-color claim incomplete, real palette has 8) |
| Visual Design, Technical Architecture, Animation Specs, Implementation Phases/Priority, Open Questions, Success Criteria | *(dropped)* | see Intentional Drops |

## `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` (SP6a — entire file)

| Section | → Target concept | Status |
|---|---|---|
| Design Principles (8) | `/REFERENCE/visual-system-art-direction.md#silhouette-first-design-principles` | migrated |
| Phase 0 Depth System | `/SYSTEMS/world-terrain-parallax.md#depth--atmospheric-perspective--reconciled-history` | migrated, extensively reconciled (Z-axis convention inverted from plan) |
| Phase 2 Creature Improvements | `/REFERENCE/creature-visual-design.md` | migrated, doc-vs-doc conflict adjudicated (code + later VECTOR-GRAPHICS-RESEARCH win over this plan's whisker-stub recommendation) |
| Phase 4 Weather & Atmosphere Polish | `/SYSTEMS/weather.md`, `/SYSTEMS/world-complexity-ambient-effects.md` | migrated as confirmation (all 3 items shipped) |
| Phase 5 Texture Atlas Swap | `/SYSTEMS/rendering-stack-2-5d.md#deferred--not-pursued` | migrated as a deferred-intent note |
| The Problems, Phase 1 (deferred to SP6b/SP3b), Phase 3 (deferred to SP6b), Implementation Order/Key Files/Success Criteria | *(dropped or deferred)* | see Intentional Drops |

## `docs/archive/plan/phase-1-foundation/PHASE-1.md` (SP2b — background)

| Section | → Target concept | Status |
|---|---|---|
| P1-T2-01..07 (schema tables, migration system) | `/DATA_MODELS/state-database-schema.md` | background-verified, corrected (`StateManager` doesn't exist; shipped classes are `DatabaseManager`+`StateCoordinator`; 16 tables not 12) |
| P1-T2-08/09 (crash recovery, backups) | `/OPERATIONS/persistence-and-recovery.md` | background-verified, corrected (class names updated to shipped `HeartbeatManager`/`BackupManager`) |
| P1-T1-01 | *(dropped)* | see Intentional Drops |

## `docs/archive/plan/phase-2-creature/PHASE-2.md` (SP3a — background only)

| Section | → Target concept | Status |
|---|---|---|
| P2-T1-08/09 (growth stage table, evolution trigger) | `/REFERENCE/growth-stages.md` (cross-checked only) | not migrated as truth — used only to confirm the survey's driftSignal |
| P2-T2-01/07 | *(dropped)* | see Intentional Drops |
| Personality/Emotional axis formulas, blend timings | *(pointer only)* | not migrated — actual Swift source read directly instead |

## `docs/archive/plan/phase-3-world/PHASE-3.md` (SP6a — entire file)

| Section | → Target concept | Status |
|---|---|---|
| Architectural Context, P3-T1-01/02/06 (parallax, terrain gen, tile recycling) | `/SYSTEMS/world-terrain-parallax.md` | migrated, corrected (4 layers not 3; 150pt transition not 50pt) |
| P3-T1-03/04/05/07/08 (biomes, object pools, landmarks) | `/REFERENCE/biomes-and-terrain-objects.md`, `/REFERENCE/repo-landmarks.md` | deferred to SP6b |
| P3-T1-09 (diet tinting), P3-T2-01..09 (sky, moon, stars, weather, reactions) | `/SYSTEMS/world-complexity-ambient-effects.md`, `/SYSTEMS/sky-celestial.md`, `/SYSTEMS/weather.md` | migrated, corrected (crossfade randomized 30-60s not fixed 30s) |
| P3-T3-01/02 (palette, OLED) | *(deferred to SP6b)* | deferred |
| P3-T3-03..11 (complexity levels, puddles, ghost echo, HUD, progress bar, hunger desaturation, spectacles, ruin inscriptions) | `/SYSTEMS/world-complexity-ambient-effects.md` | migrated |
| Integration Points, QA Gate | *(dropped)* | see Intentional Drops |

## `docs/archive/plan/phase-4-embodiment/PHASE-4.md` (SP2a Tracks 1,2,4; SP3a P4-T2-06/07/08,T4-04; SP7 Track 3)

| Section | → Target concept | Status | Wave |
|---|---|---|---|
| Track 1 (sense, recall, pending events) | `/ARCHITECTURE/mcp-tool-contract.md`, `/ARCHITECTURE/pending-events.md` | migrated, corrected; **RM-ARCH restored** P4-T1-03's `forecast` field as confirmed-unbuilt (no computation anywhere in `mcp/src/` or `Pushling/Sources/`) and flagged P4-T1-06's visual-sense description+inline-screenshot design as a `FEATURES/` intent-canon gap (no `FEATURES/` concept currently covers it — escalated, not authored, since `FEATURES/` is outside this wave's owned files); **RM-FINALIZE closed this gap** — restored in full as a 📐 subsection at `/FEATURES/interactivity-unbuilt.md#visual-sense--full-screenshot-design-intent-p4-t1-06`, code-re-verified against `SenseHandlers.swift`'s `"visual"` case (still a static not-implemented ack) | SP2a, RM-ARCH, RM-FINALIZE |
| Track 2 (move/express/speak/perform/world specs) | `/ARCHITECTURE/mcp-tool-contract.md` | migrated, corrected (Drop speech limit 6 MCP / 3 daemon); **RM-ARCH restored** P4-T2-02's full 16-expression "Animation Description" table (HIGH finding) — code-verified **live and shipped**, word-for-word in `express.ts EXPRESSION_DESCRIPTIONS`, not unbuilt design intent. P4-T2-05 (companion behavior AI spec) is `world-objects-system.md`'s territory, owned by a different concurrent wave — not touched here | SP2a, RM-ARCH |
| P4-T2-06 Command Queue | `/SYSTEMS/ai-command-queue.md` | migrated as unbuilt (see Intentional Drops) | SP2a→SP3a |
| P4-T2-07 Action Timeout | `/SYSTEMS/ai-command-queue.md#action-timeout-built--matches-p4-t2-07-closely` | migrated, corrected | SP3a |
| P4-T2-08 Touch-AI Priority | `/SYSTEMS/ai-command-queue.md`, `/SYSTEMS/behavior-stack.md` | migrated, corrected (layer-precedence, not a dedicated handler) | SP3a |
| Track 4 (session handshake, disconnect, idle gradient, single-session, Diamond Indicator reference) | `/ARCHITECTURE/mcp-session-lifecycle.md` | migrated, corrected (opacity/timing verified); **RM-ARCH landed P4-T4-06** (Creature Reactions to Session Events) here — the correct owner, ending an SP2a→SP3a deferral that neither wave ever picked up. Code-verified: "first MCP command" alert reflex and the session-connect greeting fallback are **live**; the design's separate <5min/>1day reconnect reactions were **superseded before shipping** by the richer unified 6-tier absence-wake system in `behavior-stack.md`, cross-linked rather than restored as a second authority. Also restored P4-T4-03's journal-entry-fields gap (MCP call count / events delivered are designed, not logged) | SP2a, RM-ARCH |
| Track 3 (hook framework, per-hook specs) | `/SYSTEMS/hook-sensory-system.md` | migrated, corrected (framework path corrected); **RM-ARCH restored** P4-T3-01's feed filename convention (`{timestamp_ms}_{hook_type}.json`, code-verified live) and added explicit "Not built" callouts, code-verified absent, for P4-T3-04's tool-specific PostToolUse reaction vocabulary (bash-test flex, file icon, impressed/concerned-pacing), P4-T3-07's Beast+ PostCompact speech line, and P4-T3-03's short-session (<5min) shrug branch — none of the three exist in `HookEventProcessor.swift`/`SessionLifecycleReactions.swift` | SP7, RM-ARCH |
| Goal/Deps/Integration/QA (both Track headers) | *(dropped)* | see Intentional Drops | SP2a, SP7 |

## `docs/archive/plan/phase-5-speech/PHASE-5.md` (SP4 Tracks 1,2; SP7 Track 3)

| Section | → Target concept | Status | Wave |
|---|---|---|---|
| Track 1 (bubble rendering, Drop symbols, filtering, first-word ceremony, narration) | `/REFERENCE/speech-rendering.md`, `/SYSTEMS/speech-filtering.md`, `/REFERENCE/speech-milestones.md` | migrated, corrected throughout; RM-VOICE restored P5-T1-02's left-edge/both-edges bubble-position rules (found correct-by-default/physically-unreachable, not missing behavior), P5-T1-04/05's Drop-glyph animation numbers (0.2s fade-in and per-glyph emoji sizing confirmed NOT shipped; also found and corrected a stale doc claim that `♪` rotates — the `rotates` flag is dead code, nothing rotates), P5-T1-06's tokenization/emotion/scoring internals (word-tag hierarchy inversion at the bottom two tiers, missing commit-content scoring boost, missing 0.0–1.0 emotion confidence score — all code-verified), and P5-T1-13's Verbosity/Focus text-modifier rows (previously only Focus/Specialty were flagged missing; Verbosity was silently omitted from the loss note despite also being unbuilt) | SP4, RM-VOICE |
| P5-T1-08 Speech Cache & Replay | `/SYSTEMS/speech-filtering.md#speech-cache--replay-p5-t1-08` | **FIXED — landed for real this pass.** Restored in full under a dedicated section: cache storage (schema, `source`/`emotion`/`tts_cache_path` columns, 100-utterance FIFO eviction, `SpeechCache.swift:100-109`) plus all three designed replay consumers with their actual live/dead status, code-verified. **Dream replay is live** (`dreamUtterance()`+`dreamFragment(from:)`, wired to the wake-up path) — cross-linked to `journal-and-dreams.md`'s existing full mechanic write-up rather than duplicated. **Sage+ reminiscence is dead** (`failedSpeechEntries()`, zero callers) — cross-linked to `journal-and-dreams.md`'s existing P8-T2-07 gap write-up rather than duplicated. **Idle replay is dead** (`recentUtterances()`, zero callers) — unlike the other two, this scenario had no doc home anywhere in the bundle until this pass; documented fresh, distinguishing it from the Sage-reminiscence scenario it's easy to conflate with (no stage gate, no sleep requirement, full utterance not a fragment). Explicitly distinguished from the unrelated 50MB WAV audio-file cache at `voice-tts-stack.md#caching` (cross-linked, not duplicated). `recentUtterances()`/`failedSpeechEntries()` zero-caller claim re-confirmed by fresh grep this pass. | SP4→SP8 (gap unresolved) →RM-VOICE (recorded, not landed) →RM-FINALIZE (drift caught, still open) →RM-FIX-P5T108 (landed) |
| P5-T1-12 Apex World-Shaping Speech | `/SYSTEMS/weather.md#apex-speech-triggered-world-effects-p5-t1-12` | gap found and filled by SP4→SP8 (see SP4 Deferral Findings below); **RM-TOUCH corrected/completed this pass** — the gap-fill's "every rendered utterance is scanned" claim was itself wrong (code gates `currentStage == .apex && request.source == .ai`, so autonomous Layer-1 speech never triggers it); also restored the trigger-word Ember glow and journal-log design (both unbuilt, grep-verified) and corrected the "1-5 min override" claim against the real code, which reverts on a fixed 5-minute timer (`debugForceWeather` → `forceWeather(state, duration: 300)`) | SP4→SP8→RM-TOUCH |
| P5-T1-16 Between-Session Autonomous Speech (5 of 7 triggers) | `/FEATURES/interactivity-unbuilt.md#between-session-autonomous-speech--unbuilt-p5-t1-16` | migrated-as-unbuilt (SP8c, reclassified from partial gap) | SP4→SP8→SP8c |
| Track 2 (sherpa-onnx integration, Piper/Kokoro tiers, audio pipeline, caching) | `/SYSTEMS/voice-tts-stack.md` | migrated, corrected (no `VoiceEngine` class; real API is `SherpaOnnxBridge`+`ModelManager`+`VoiceSystem`); RM-VOICE restored/verified: P5-T2-02's Drop symbol→phoneme mapping design (never shipped — `generateBabbleText` ignores the displayed glyph), P5-T2-04's Kokoro ceremony-preload/memory-pressure design (unbuilt — stage-change reload is generic, not ceremony-timed), P5-T2-05's audio-session rules (N/A on macOS — `AVAudioSession` is iOS-only, flagged as a platform-mismatch in the original design rather than a gap), P5-T2-07's evolution-ceremony crossfade choreography (unbuilt — tier reload isn't synced to ceremony phase timers), P5-T2-09's eager-pre-render design (partially shipped: `prerenderCommonPhrases` exists but fires on stage-change, not genuine idle, and covers 5–8 phrases per stage, not 20), P5-T2-10's dream-audio onset timing (unbuilt) **plus a verified dead-code finding: `onDreamBubble` — the sole caller of dream audio generation — has zero callers itself, so dream audio never plays today, full stop**, and P5-T2-11's queue-depth rule (`maxQueueDepth = 3`, drop-oldest — verified **exact** match; the "no pre-render while speech queued" sub-rule is unenforced) | SP4, RM-VOICE |
| P5-T2-08 First Audible Word | `/REFERENCE/speech-milestones.md#milestone-2` | migrated, corrected (`first_audible_word` journal entry never written) | SP4 |
| Track 3 (commit-eating theater, XP formula, fallow bonus, rate limiting) | `/SYSTEMS/commit-feeding-xp.md` | migrated verbatim + new defect found (award path bypasses `XPCalculator`) | SP7 |
| Goal/Deps/QA Gate (both tracks) | *(dropped)* | see Intentional Drops | SP4, SP7 |

## `docs/archive/plan/phase-6-interactivity/PHASE-6.md` (SP5 — entire file)

| Section | → Target concept | Status |
|---|---|---|
| P6-T1 (touch tracking, gesture recognizer, response map, laser/petting/flick/pick-up/hand-feeding/pounce/wake-boop/tap-on-object) | `/SYSTEMS/touch-input-pipeline.md`, `/REFERENCE/gesture-response-map.md` | migrated, corrected throughout; **RM-TOUCH restored substantial dropped detail** — the wake-up boop's full 3-tap progressive sequence (only routing had migrated; the durations/response-per-tap table did not) and the laser pointer's dot visual/pounce-escape/end-behavior spec (both fully code-verified as *live*, not unbuilt) were missing entirely; fur-ripple mechanism numbers restored for petting, alongside a new finding that `PettingStroke`'s `.slowBlink`/`.lieDown`/`.rejection`/`.purrIntensify` events are fired but have zero consumers (only `.strokeComplete` is wired); flick's per-object-type restitution table restored, alongside a new finding that `ObjectInteraction.onObjectEvent` (creature-tap-response and creature-chase-response) has zero listeners anywhere; hand-feeding's XP/contentment reward found to be similarly dead (`HandFeeding.onFeedingEvent` never assigned); tap-left/right-of-creature "walk to point" and tap-on-object creature investigation restored as unbuilt intent in `interactivity-unbuilt.md` (neither had a home before) |
| P6-T2 (milestone tracking, unlock system, ceremony, pet streak) | `/SYSTEMS/touch-milestones.md` | migrated, corrected (`touch_stats` table created but never written — flagged for DECISIONS.md) |
| P6-T3 (invitations, mini-games ×5, unlock progression) | `/SYSTEMS/invitation-system.md`, `/SYSTEMS/mini-games.md` | migrated, corrected (scheduler's own inputs never assigned — flagged for DECISIONS.md; cooperative modes all unbuilt); **RM-TOUCH restored the full per-type invitation payload table** (all 6 types' setup/accept/interaction/reward/self-resolution, plus the P6-T3-03 global self-resolution rules) directly into `invitation-system.md` — SP5's "moved to interactivity-unbuilt.md" claim was inaccurate, only a one-sentence pointer had moved, not the substance; also restored per-game built specifics for Catch/Memory/Treasure Hunt/Rhythm Tap into `mini-games.md`, finding Memory and Treasure Hunt were built to **materially different designs** than PHASE-6 (color-position-tap, not shape-to-gesture-type; cursor+temperature-bar, not swipe+hint-speech) while Rhythm Tap's BPM/timing windows match exactly; the game-discovery/idle-teaser mechanic and the mini-game framework's claimed behavior-stack suspension (code shows the full 4-layer stack keeps running unconditionally — only touch input is gated) were both found unbuilt/incorrect and corrected |
| Track 4 (display modes, postcards, Konami, co-presence, campfire) | `/FEATURES/interactivity-unbuilt.md#track-4-advanced-gestures--display-modes` | migrated as unbuilt/built-differently; **RM-TOUCH restored the design substance behind each item** — SP5 had preserved only names/labels (mode names, "4-finger memory postcards," Konami's existence, campfire's 40% roll). Restored: the 4-mode content/visual table, the postcard narrative design (source, format, 3 example texts, 50-postcard cap), the Konami 10-gesture sliding-window detector spec (mapping, 1.5s window, payload), and the campfire's full trigger/visual/behavior spec — none of it changes built-vs-unbuilt status, all newly-added content is 📐 |
| P6-T1-02c 2-Finger Swipe (Sage+ temporal vision) | `/FEATURES/interactivity-unbuilt.md#live-pan--zoom` | **gap closed this pass (RM-TOUCH)** — SP5 claimed this migrated "implicitly" via the 2-finger-no-op note in `gesture-response-map.md`, but nothing of the Sage+ temporal-rewind/forward design had actually landed anywhere; restored in full as unbuilt intent |
| P6-T2-06 "Paying Attention" Rewards | `/FEATURES/interactivity-unbuilt.md#touch-milestones--unbuilt-payloads` | **corrected this pass (RM-TOUCH)** — SP5's entry preserved only the concept summary; the 7-row behavior/window/reward table and the once-per-instance rule were missing. Restored in full |
| Various journal-JSON examples, HUD/progress-bar visuals, result-screen layout, QA Gate | *(dropped)* | see Intentional Drops |

## `docs/archive/plan/phase-7-creation-systems/PHASE-7.md` (SP3a, SP3b — background only)

Read for context per both waves' briefs ("never lift stale schemas");
its driftSignals were independently re-discovered from live code rather
than trusted from this doc. No rows migrated as truth. Confirmed
still-relevant driftSignals: `taught_behaviors` schema shape, the
13-tracks-vs-16-vocabulary conflation, 3-creation-interfaces-vs-preset-only,
14-templates-vs-actual-vocabulary, `habits` schema column mismatch, category
CHECK vocabulary — all independently resolved fresh from code in
`teach-system.md`/`world-objects-system.md`/`nurture-system.md` (SP3b) and
`ai-command-queue.md` (SP3a).

## `docs/archive/plan/phase-8-polish/PHASE-8.md` (SP3a, SP3b — background only)

Same background-only treatment. Confirmed still-relevant driftSignal:
mutation badge names (doc's 10 vs. `milestoneSeedData`'s 10, only 3
matching) — resolved definitively in `surprise-catalog.md` (the live,
doc-matching system is `MutationSystem.swift`'s enum; `milestoneSeedData`'s
non-matching IDs are dead/orphaned seed rows, not a competing system).

# Citations

[1] `docs/archive/traceability/SP2a.md` through `SP7.md` (the 9 wave sub-matrices this file consolidates)
[2] `.samantha/scratch/okf-survey-2026-07-02.json` (the original 24-source migration survey)
[3] `docs/DECISIONS.md` (R1-R4 and R3-amended — the human canon rulings referenced throughout)

