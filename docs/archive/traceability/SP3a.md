---
type: Reference
title: SP3a Traceability — Creature Core
description: Source-to-concept mapping for Wave SP3a (WO-1 OKF migration) — proves zero fidelity loss across the six creature-core concepts.
status: Current
tags: [okf-migration, traceability, wave-sp3a]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP3a authored six concepts: [vision](/vision.md),
[creature-identity-birth](/REFERENCE/creature-identity-birth.md),
[growth-stages](/REFERENCE/growth-stages.md),
[personality-emotional-state](/REFERENCE/personality-emotional-state.md),
[behavior-stack](/SYSTEMS/behavior-stack.md), and
[ai-command-queue](/SYSTEMS/ai-command-queue.md).

"Deferred" below means the source section is real content that belongs in
the final bundle but is out of this wave's assigned scope — it is **not** a
fidelity loss, it is routed to the wave that owns that subject. Background-
only sources (PHASE-2, PHASE-7, PHASE-8) were read for code-check context
only; nothing from them was lifted as truth into an SP3a concept — every
factual claim sourced from those files was independently re-verified
against the current Swift/TypeScript source before being written.

# PUSHLING_VISION.md (assigned sections: Philosophy; Dual-Layer Embodiment;
Core Principles; Identity/Birth; Growth Stages; Personality System;
Emotional State; Circadian cycle; Control Architecture / Behavior Stack)

| Source section | → Target concept#section | Status |
|---|---|---|
| Opening tagline; the "something is breathing" epigraph | `vision.md` (epigraph) | migrated |
| Philosophy: "The feeling" | `vision.md#the-feeling` | migrated |
| The Dual-Layer Embodiment Model (Layer 1, Layer 2, Incarnation not possession, The handoff) | `vision.md#the-dual-layer-embodiment-model` | migrated |
| Core Principles (5 bullets) | `vision.md#core-principles` | migrated |
| What Makes This Different; closing line | `vision.md#what-makes-this-different` | migrated |
| Identity: Born from Your Git History — birth trigger, trait-derivation table, name generation, historical seeding, hatching ceremony narrative | `creature-identity-birth.md` (naming, birth-flow, adjudication sections) | migrated, corrected — the "historical seeding" model is preserved as superseded design history, not current truth; see the wave's Adjudication #1 (`GitHistoryScanner` is real code but never invoked; the live path is `EggAccumulator`'s 5-commit progressive learning, which the vision doc never describes at all) |
| Visual Form: Cat-Esque Spirit Creature (cat behaviors list, breathing) | *(not this wave)* | deferred — rendering/animation-catalog detail owned by the creature-visual wave (SP6a); `creature-identity-birth.md` and `behavior-stack.md` reference breathing/physics only insofar as they're mechanism, not the full behavior catalog |
| Growth Stages table (Spore 0-19 commits through Apex 1200+) | `growth-stages.md#superseded-design-history-commits-eaten-model` | migrated, corrected — per R1 ruling, code's XP thresholds (100/500/2000/8000/20000) and `egg` as stage-0 name are canon; the commits-eaten table and `Spore` naming are preserved as superseded history, not current truth |
| Adaptive XP curve (`activity_factor` formula, developer-profile table) | `growth-stages.md#superseded-design-history-commits-eaten-model` | migrated, corrected — flagged as intent-canon-but-unwired: the `activity_factor`/`commits_eaten` SQLite columns exist but `checkEvolution()` reads neither |
| Stage Transitions (5-phase ceremony) | `growth-stages.md#stage-transition-ceremony` | migrated, verified against `EvolutionCeremony.swift` |
| Personality System (5-axis table, language specialty table, language preferences) | `personality-emotional-state.md#personality-5-axes`, `#language-specialty-categories` | migrated, corrected — noted the two live formula sets (`EggAccumulator` 5-commit vs. `GitHistoryScanner` lifetime) differ, and flagged the `specialty` SQLite CHECK-constraint mismatch as a new drift signal (cross-referenced from `creature-identity-birth.md`'s adjudication) |
| Emotional State (4-axis table, emergent states table) | `personality-emotional-state.md#emotional-state-4-axes`, `#emergent-states` | migrated, verified exact thresholds/rates against `EmotionalState.swift`/`EmergentStates.swift` |
| Circadian cycle | `personality-emotional-state.md#circadian-cycle` | migrated, verified constants against `CircadianCycle.swift` |
| Language preferences (favorite/disliked language, shifts every ~200 commits) | *(not this wave)* | deferred — this is a commit-feeding/reaction-system behavior (favorite/disliked language reveal on eating), owned by the commit-feeding concept, not identity or personality; `favorite_language`/`disliked_language` columns exist in `creature` table but their read/write logic lives in the feed pipeline |
| Control Architecture: 4-Layer Behavior Stack (layer table, key rules) | `behavior-stack.md#the-four-layers` | migrated, verified constants against `AIDirectedLayer.swift`/`ReflexLayer.swift`/`AutonomousLayer.swift` |
| The Blend Controller (transition timing table) | `behavior-stack.md#the-blend-controller` | migrated, verified all 5 transition durations exactly against `LayerTypes.swift`/`BlendController.swift`; added the previously-undocumented per-body-part sub-timing (expression crossfade lead/lag, reflex cascade order) that exists in code but not in the vision doc |
| Touch-AI Interaction Priority (5-step list, co-presence bonus mention) | `behavior-stack.md#the-four-layers` (layer-precedence explanation), `ai-command-queue.md#touch-priority-built-but-via-layer-precedence-not-a-dedicated-handler` | migrated, corrected — steps 1–3 (reflex fires, acknowledge, resume) are true via layer precedence; steps 4–5 (pause-not-cancel, 5s queue-clear) and the co-presence bonus are **not implemented** — documented as unbuilt design in `ai-command-queue.md` rather than silently presented as current behavior |
| Key Design Principles 2-4 | `vision.md` (folded into Core Principles / handoff prose, not as a standalone numbered list) | migrated (distributed) |

# docs/archive/plan/phase-4-embodiment/PHASE-4.md (assigned: P4-T2-06, P4-T2-07,
P4-T2-08, P4-T4-04 — routed from SP2a's traceability; Track 4 daemon-
reaction tables P4-T3-02/03/06 read for context only, not assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| P4-T2-06 Command Queue in Daemon (4 modes, capacity 20) | `ai-command-queue.md#what-is-built-the-command-queue-as-it-runs-today` | dropped-with-justification, documented as unbuilt — confirmed via code search (`CommandQueue`, queue-mode params, capacity enforcement: zero matches) that no such system exists; NOT migrated as canon per the explicit routing instruction from SP2a. Preserved as intent, flagged for `DECISIONS.md` + a future `FEATURES/` entry (out of this wave's assigned concept list) |
| P4-T2-07 Action Timeout System (30s timeout, 5s fade, configurable per-command) | `ai-command-queue.md#action-timeout-built--matches-p4-t2-07-closely` | migrated, corrected — the 30s/5s constants match exactly; the per-command configurable `timeout_s` (max 120s) does not exist in code and is flagged as such, not silently dropped |
| P4-T2-08 Touch-AI Interaction Priority (5-step spec, co-presence bonus, `TouchInterruptHandler`) | `ai-command-queue.md#touch-priority-built--but-via-layer-precedence-not-a-dedicated-handler`, `behavior-stack.md` | migrated, corrected — touch-wins IS true today but via simple layer-precedence, not the designed dedicated handler; the 5s-clear and co-presence mechanics are documented as unbuilt, not fabricated as present |
| P4-T4-04 Idle Timeout Gradient (continuous `autonomyBlend` formula, diamond alpha) | `ai-command-queue.md#idle-gradient-built-but-as-a-discrete-3-step-machine-not-a-continuous-blend` | migrated, corrected — the continuous blend formula does not exist; what exists is a discrete 3-step degradation inside `AIDirectedLayer`, which is a *different* mechanism from (and not to be confused with) `SessionManager`'s separately-documented (SP2a) diamond-opacity idle gradient that happens to share the same 10/20/30s thresholds |

# docs/archive/plan/phase-2-creature/PHASE-2.md (background only — retire-archive
disposition; read for code-check pointers only)

| Source section | → Target concept#section | Status |
|---|---|---|
| P2-T1-08 Growth stage table (Spore walk speed "0, floats") | `growth-stages.md` (superseded history section, cross-checked) | not migrated as truth — this background doc's own numbers were superseded before code shipped (egg `baseWalkSpeed = 3`, not 0); used only to confirm the survey's driftSignal, not cited as a source of canon |
| P2-T1-09 Evolution trigger ("commits_eaten crosses threshold") | `growth-stages.md#superseded-design-history-commits-eaten-model` (cross-checked, not additionally cited) | not migrated as truth — corroborates but does not add beyond what `PUSHLING_VISION.md`'s own Growth Stages table already established; `PUSHLING_VISION.md` remains the cited source per the survey's guidance that plan docs are background-only |
| P2-T2-01/07 Behavior stack file paths, "AI-Directed layer is inert in Phase 2" | *(none)* | dropped-with-justification — historical build-state scoping statement, describes a moment in development long past; current `AIDirectedLayer` is fully live, documented fresh from code in `behavior-stack.md` |
| Personality/Emotional axis formulas, blend timings (used as pointers to `PersonalitySystem.swift`/`EmotionalState.swift`/`BlendController.swift`) | *(none — pointer only)* | not migrated — this wave read the *actual* Swift source directly rather than trusting the plan doc's constants, several of which (e.g. reflex/blend sub-timings) were more precisely verifiable in code than in the plan prose |

# docs/archive/plan/phase-7-creation-systems/PHASE-7.md, docs/archive/plan/phase-8-polish/PHASE-8.md (background only)

| Source section | → Target concept#section | Status |
|---|---|---|
| *(no sections overlapped this wave's 6 concepts)* | *(none)* | not applicable — these two background docs were checked for any creature-core/behavior-stack/identity content that might contradict or extend the assigned concepts; none was found relevant to this wave's scope |

# Citations

[1] `PUSHLING_VISION.md`
[2] `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
[3] `docs/archive/plan/phase-2-creature/PHASE-2.md`
[4] `docs/archive/plan/phase-7-creation-systems/PHASE-7.md`
[5] `docs/archive/plan/phase-8-polish/PHASE-8.md`
