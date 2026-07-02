---
type: Reference
title: SP7 Traceability — Embodiment, Hooks & Feeding
description: Source-to-concept mapping for Wave SP7 (WO-1 OKF migration) — proves zero fidelity loss across the five embodiment/hooks/feeding concepts.
status: Current
tags: [okf-migration, traceability, wave-sp7]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP7 authored five concepts:
[embodiment](/SYSTEMS/embodiment.md),
[awakening-pipeline](/SYSTEMS/awakening-pipeline.md),
[hook-sensory-system](/SYSTEMS/hook-sensory-system.md),
[commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md), and
[embodiment-language-guide](/OPERATIONS/embodiment-language-guide.md).

"Deferred" below means the source section is real content that belongs in
the final bundle but is owned by another wave — not a fidelity loss.
"Corrected" means the concept preserves the content but fixes a verified
doc↔code drift rather than copying the doc's claim forward.

# docs/EMBODIMENT-REVIEW.md (assigned: §1, §2, §3, §5, §6, §7, §8 — §4 was SP2a's)

| Source section | → Target concept#section | Status |
|---|---|---|
| §1 Philosophy — three forces table, key design principle | `embodiment.md#three-forces` | migrated, cross-linked to `/vision.md` for the philosophy prose rather than restating it |
| §2 How Embodiment Works — full lifecycle diagram, data flow diagram | `embodiment.md#the-full-session-lifecycle`, `embodiment.md#data-flow` | migrated, corrected — "Claude never directly sees hook output (except SessionStart)" preserved verbatim as a load-bearing design fact |
| §3 The Awakening Pipeline — 6 variants table, per-stage data matrix, world state, hunger, behavioral guidance | `awakening-pipeline.md` (all sections) | migrated, corrected — variant table re-verified line-by-line against `session-start.sh`; personality axis count corrected 5→4; the "spore vs. egg" naming gap and the resulting egg-stage awakening bug were discovered during this verification (not present in this source doc) |
| §4 MCP Tools: The Motor Cortex | *(not this wave)* | deferred — SP2a's `mcp-tool-contract.md` (per this wave's brief and SP2a's own traceability, which explicitly defers §1/§2/§3/§5/§6/§7/§8 to SP7) |
| §5 The Sensory Loop: Hooks — hook coverage table, hook architecture rules, awareness loop | `hook-sensory-system.md` (all sections) | migrated, corrected — latency budget disambiguated into a per-hook table (six hooks at <50ms, SessionStart and post-commit at <100ms) rather than the doc's single stated number; the 100-event ring buffer / `events_dropped` detail is deferred to `/ARCHITECTURE/pending-events.md` (SP2a's territory) and cross-linked rather than duplicated |
| §6 Embodiment Language Guide — Do/Don't lists, litmus test | `embodiment-language-guide.md` (all sections) | migrated verbatim (the do/don't lists), plus verbatim tool-description quotes re-sourced from `mcp/src/tools/*.ts` per this doc's own caveat that its Do-list first-person examples paraphrase the code lightly |
| §7 The Embodiment Test — failing/passing state, the measure | `embodiment.md#the-embodiment-test` | migrated, with an added note that this is a qualitative human/Samantha judgment, not an automatable assertion |
| §8 File Reference — file/role table | `embodiment.md#file-reference` | migrated, corrected — the four helper `mcp/src/tools/` modules missing from the source table (`nurture-validation.ts`, `sense-helpers.ts`, `teach-handlers.ts`, `world-validation.ts`) and `hooks/install.sh` are still not restated here individually (they're implementation detail of concepts this table already points to); every row now cross-links to the concept that owns that file's detail rather than describing it inline, since several files (EventBuffer, SessionManager) are owned by SP2a concepts this wave doesn't re-author |

# docs/plan/phase-4-embodiment/PHASE-4.md (assigned: Track 3 only — Tracks 1/2/4 were SP2a's)

| Source section | → Target concept#section | Status |
|---|---|---|
| P4-T3-01 Hook Framework — `pushling_emit`/`pushling_signal`, error isolation, 100ms budget | `hook-sensory-system.md#the-shared-library-contract` | migrated, corrected — framework path corrected from the doc's `hooks/framework.sh` to the actual `hooks/lib/pushling-hook-lib.sh` (SP2a's traceability already flagged this same path error in a different context; independently re-verified here) |
| P4-T3-02 SessionStart Hook | `awakening-pipeline.md` (whole concept) | migrated, corrected — doc describes only 4 awakening variants ("Spore/Drop/Critter-Beast-Sage/Apex" collapsed); code has 6 distinct variant functions (Critter, Beast, and Sage are each their own function with materially different guidance text, not one shared "Embodiment" block) |
| P4-T3-03 SessionEnd Hook | `hook-sensory-system.md` (SessionEnd row) | migrated |
| P4-T3-04 PostToolUse Hook — batching rule ">3 hooks in 2s" | `hook-sensory-system.md#two-independent-batching-mechanisms` | migrated, corrected — this doc's "2 seconds" figure is the daemon-side `HookBatchTracker` window specifically; it does not contradict the hook-script-side 10-second/3-tool window found in the actual `post-tool-use.sh` source (`PUSHLING_VISION.md`/`EMBODIMENT-REVIEW.md`'s figure) — both are real, both are documented, neither is corrected away |
| P4-T3-05 UserPromptSubmit Hook | `hook-sensory-system.md` (UserPromptSubmit row) | migrated |
| P4-T3-06 SubagentStart/SubagentStop Hooks | `hook-sensory-system.md` (SubagentStart/Stop rows) | migrated |
| P4-T3-07 PostCompact Hook | `hook-sensory-system.md` (PostCompact row) | migrated |
| P4-T3-08 Git Post-Commit Hook — JSON schema | `commit-feeding-xp.md#the-post-commit-hook-payload--16-fields-not-78` | migrated, corrected — doc's example payload (14 fields, `languages` as an array) replaced with the verified 16-field shape (`languages` as a comma-joined string, plus `full_sha` and `tags` which the doc's example omits) |
| P4-T3-09 Daemon-Side Hook Event Processing — event→reaction table, XP formula reference, rate limiting | `hook-sensory-system.md#daemon-side-processing`, `commit-feeding-xp.md` (XP sections) | migrated, corrected — this section's own restated XP formula (`base(1) + lines(min(5,lines/20)) + message(2 if >20chars) + breadth(1 if 3+ files) × streak_multiplier`) omits the fallow and rate-limit multipliers from its own bullet list despite the surrounding doc discussing both; the full six-term formula is documented in `commit-feeding-xp.md` from `XPCalculator.swift` directly, and the discovery that the *shipped* award path doesn't call `XPCalculator` at all is flagged as a new defect there |
| Track 3 Goal/Agents/Estimated-effort header | *(plan-wrapper scaffolding)* | dropped-with-justification — historical planning metadata (agent names, day estimates), no prescriptive content; archival of the residual `PHASE-4.md` file is SP8's job |

# docs/plan/phase-5-speech/PHASE-5.md (assigned: Track 3 only — Tracks 1/2 belong to the speech/voice wave)

| Source section | → Target concept#section | Status |
|---|---|---|
| P5-T3-01/02/03/04/05 Commit Text Materialization, 4-phase choreography | `commit-feeding-xp.md#the-eating-theater--4-phases` | migrated (summary level — frame-by-frame animation detail stays owned by `CommitEatingAnimation.swift`/`CommitTextNode.swift` per this doc's own file references, cross-linked rather than restated) |
| P5-T3-06 Special Commit Type Variations | `commit-feeding-xp.md#commit-type-classification--17-types-priority-ordered` | migrated, corrected — doc/header-comment both say "15" commit types; the live `CommitType` enum has 17 cases (including `release` and `normal`, both real cases the "15" count appears to exclude) — table lists all 17 with priority order, reactions, and eating speed verified against `CommitTypeDetector.swift` directly |
| P5-T3-07 XP Calculation Engine — full formula | `commit-feeding-xp.md#the-xp-formula` | migrated verbatim (matches `XPCalculator.swift` exactly), plus the new defect section documenting that the live award path bypasses this formula |
| P5-T3-08 Fallow Field Bonus | `commit-feeding-xp.md#fallow-field-bonus-return-commit-reward-not-a-penalty` | migrated verbatim (table matches `XPCalculator.calculateFallowMultiplier` exactly) |
| P5-T3-08b Language Preference Drift | `commit-feeding-xp.md#language-preference-drift` | migrated, flagged unverified — the every-200-commits recalculation logic (favorite/disliked language shift) was not located in the Swift codebase during this wave's code checks; documented as design intent with an explicit unverified-implementation flag rather than asserted as shipped, since asserting it as canon without a code sighting would risk minting a false prescriptive claim |
| P5-T3-09 Rate Limiting | `commit-feeding-xp.md#rate-limiting` | migrated verbatim (matches `CommitRateLimiter` exactly) |
| P5-T3-10 Sleeping Creature Commit Processing | *(not this wave)* | dropped-with-justification — this is sleep-state/dream-rendering detail (dream bubble rendering, sleep animation variant) that belongs with the creature/sleep-cycle concept, not commit-feeding; the commit-feeding-xp concept documents the XP/detection/theater pipeline that applies regardless of waking state, and this section's content (how the *rendering* differs while asleep) has no XP or detection implications of its own |
| Track 3 Goal/Dependencies header, QA Gate checklist | *(plan-wrapper scaffolding)* | dropped-with-justification — same rationale as PHASE-4's header; QA Gate is a Phase-completion checklist, not prescriptive content |

# PUSHLING_VISION.md (assigned sections: Commit-as-Food System; MCP Integration §Session-Start-Embodiment-Awakening; Claude Code Hooks; Git Integration §Post-Commit-Hook)

| Source section | → Target concept#section | Status |
|---|---|---|
| The Commit-as-Food System (character-by-character eating, XP formula, reactions table, fallow bonus) | `commit-feeding-xp.md` (all sections) | migrated, corrected — reactions table cross-checked against `CommitTypeDetector.swift`'s actual 17-case enum (see PHASE-5 row above); XP formula confirmed matching `XPCalculator.swift` |
| MCP Integration: Session Start — Embodiment Awakening (all 6 variants, absence duration table) | `awakening-pipeline.md` (all sections) | migrated, corrected — absence-duration boundary values re-verified against `format_absence`'s actual bash comparisons (day<4/day<8 vs. the doc's 1-3/3-7 day framing — functionally near-identical, documented with the exact boundary); the 8-24h bucket's promised commit-message interpolation ("You dreamed of [recent commit message]") is not present in the shipped text — preserved as aspirational intent, flagged as current-shipped-simpler |
| Git Integration: Post-Commit Hook (JSON example, rate limiting, sleeping-creature note) | `commit-feeding-xp.md#the-post-commit-hook-payload--16-fields-not-78`, `#rate-limiting` | migrated, corrected — JSON example was a 10-field partial subset of the real 16; sleeping-creature processing note deferred (see PHASE-5 P5-T3-10 row) |
| The Journal — entry-type table | *(not this wave)* | deferred — journal is its own cross-cutting reference concept (multiple systems write to it: commits, touches, speech, hooks, surprises); owned by whichever wave holds `/REFERENCE/journal.md` in the bundle plan, not authored here to avoid a second "one authority per subject" violation |
| Claude Code Hooks: Full Dev Session Awareness (the 7 hooks table, hook implementation rules) | `hook-sensory-system.md` (all sections) | migrated, corrected — the doc's own hook-JSON example (`PostToolUse`) matches the shipped payload shape exactly; the doc's single "<100ms" budget claim is disambiguated per-hook against the actual script headers |
| All other sections (Philosophy, Identity/Birth, Growth Stages, Personality, Visual System, Touch Interactions, Speech Evolution detail, Behavior Stack, remaining MCP Integration subsections, Creation Systems, Surprises, Installation, Performance, P Button, Roadmap) | *(not this wave)* | out of scope — owned by SP3a/SP3b/SP4/SP5/SP6a/SP6b per the bundle plan; not read in depth beyond the four assigned sections above |

# Citations

[1] `docs/EMBODIMENT-REVIEW.md`
[2] `docs/plan/phase-4-embodiment/PHASE-4.md`
[3] `docs/plan/phase-5-speech/PHASE-5.md`
[4] `PUSHLING_VISION.md`
