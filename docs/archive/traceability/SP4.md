---
type: Reference
title: SP4 Traceability — Speech & Voice
description: Source-to-concept mapping for Wave SP4 (WO-1 OKF migration) — proves zero fidelity loss across the eight speech-and-voice concepts.
status: Current
tags: [okf-migration, traceability, wave-sp4]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP4 authored eight concepts:
[speech-filtering](/SYSTEMS/speech-filtering.md),
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md),
[speech-rendering](/REFERENCE/speech-rendering.md),
[speech-milestones](/REFERENCE/speech-milestones.md),
[creature-voice-design](/REFERENCE/creature-voice-design.md),
[tts-engine-evaluation](/RESEARCH/tts-engine-evaluation.md),
[voice-psychoacoustics](/RESEARCH/voice-psychoacoustics.md), and
[game-voice-sound-design](/RESEARCH/game-voice-sound-design.md).

"Deferred" below means the source section is real content belonging in the
final bundle but out of this wave's assigned scope — not a fidelity loss,
routed to the wave that owns that subject. All deferred sections were read
for context only; nothing from them was lifted as truth into an SP4 concept.

# `docs/archive/TTS-RESEARCH.md` (primary source — entire file assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| Executive Summary | `tts-engine-evaluation.md` intro, `voice-tts-stack.md` (6-tier claim corrected to 3) | migrated, corrected |
| §1 The Growth-Stage Voice Concept | `voice-tts-stack.md#the-3-tiers-not-6` (tier mapping corrected); "What the creature says" utterance-source list *(see note)* | migrated, corrected — see note below on the `pushling_teach("speak")` utterance source |
| §2–14 (Options 1–13 evaluations) | `tts-engine-evaluation.md` (per-option summary table + verdicts) | migrated (condensed to a comparison table + verdict column rather than full per-option prose; every option's quality/latency/size/license/Swift-path/verdict is preserved) |
| §15 Comparison Matrix | `tts-engine-evaluation.md#decision-matrix` | migrated |
| §16 Recommended Architecture (stack diagram, bundle contents, fallback strategy, lazy loading, GPU/ANE) | `voice-tts-stack.md` (download-on-demand correction, sherpa-onnx confirmation, no-AVSpeech-fallback correction), `tts-engine-evaluation.md#recommended-architecture-as-proposed` (as-proposed record) | migrated, corrected — bundling premise and AVSpeechSynthesizer fallback both corrected against shipped code |
| §17 Voice Character Design (per-stage voice blocks, Emotion-to-Voice table, Personality-to-Voice table) | `creature-voice-design.md` (merged, per survey guidance) | migrated, merged with `CREATURE-VOICE-DESIGN.md` §11 rather than duplicated |
| §18 Implementation Roadmap (phases 1–4) | *(not migrated as prescriptive)* | dropped-with-justification — historical phase-sequencing narrative with no content beyond what §16/§17 already state as targets; the Performance Targets sub-table was migrated (`tts-engine-evaluation.md#performance-targets-as-proposed`) |
| Appendix A License Summary | `tts-engine-evaluation.md#license-summary` | migrated |
| Appendix B Key Repository Links | `tts-engine-evaluation.md#key-repository-links` | migrated |

**Note on the `pushling_teach("speak")` utterance source**: the source
doc's "What the creature says" list includes "Taught words (via
`pushling_teach("speak")`)." Verified: `mcp/src/tools/teach.ts`'s
`VALID_CATEGORIES` (`playful`/`affectionate`/`dramatic`/`calm`/`silly`/
`functional`) has no `speak` category or action. This utterance source is
stale and was **not** migrated into any SP4 concept — dropped-with-
justification, since documenting a non-existent teach mode as a canonical
speech source would mint incorrect prescriptive content. Flagged for the
Orchestrator (the teach-system wave should confirm this is fully stale).

# `docs/archive/CREATURE-VOICE-DESIGN.md` (primary source — entire file assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| §1 Design Philosophy (Voice Identity, Anti-Patterns, Golden References) | `creature-voice-design.md#voice-identity`, `#anti-patterns-to-avoid`, `#golden-references` | migrated |
| §2 Voice Evolution Arc — stage table's Emotional Register column only | `creature-voice-design.md#the-voice-evolution-arc-emotional-register` | migrated |
| §2 Voice Evolution Arc — commit thresholds + per-stage pipeline mechanics (chirp synth / syllable mapper / hybrid mixer / TTS) | `creature-voice-design.md#superseded-design-history-the-original-pipeline-concept` | migrated as superseded design history (per survey scoping — not current architecture) |
| §2 Detailed Stage Specifications (Spore/Drop/Critter/Beast/Sage/Apex pipeline detail) | `creature-voice-design.md#superseded-design-history-the-original-pipeline-concept` | migrated, condensed into the superseded-pipeline summary rather than reproduced phase-by-phase (every distinct mechanism named: chirp synth, syllable mapper, hybrid 80/20 mixer, TTS+accent-babble) |
| §2 in-line dialogue (Claude/Samantha discussing the Beast transition, the "26 syllables won't get repetitive" exchange) | *(presentation only)* | dropped-with-justification — theatrical dialogue framing; the substantive content (pitch-variance/micro-variation/volume-envelope mitigations for syllable repetition) is preserved in the superseded-pipeline summary, the framing device itself is not reproduced |
| §3 Pitch Manipulation (ranges, sweet spot, dynamic modulation, `AVSpeechUtterance` pitch param) | `voice-psychoacoustics.md#pitch-the-science-of-small-and-cute` | migrated (the `AVSpeechUtterance`-specific parameter note is folded into the general pitch-shift guidance since that API was never used — see `voice-tts-stack.md` for the actual API) |
| §4 Formant Shifting — principle, guideline tables, Pushling recipe table | `voice-psychoacoustics.md#formant-shifting-why-its-critical` | migrated |
| §4 Options A–D implementation survey (`AVAudioUnitTimePitch`, AudioKit, vDSP/FFT, `AUAudioUnit`) | `voice-tts-stack.md#aspirational-the-never-built-formant--chorus--breathiness-layer` | migrated, per survey's explicit exclusion from the psychoacoustics concept — routed to the shipped-architecture concept instead, since it's implementation-option detail (confirmed: Option A is what shipped, uncombined with any of B/C/D) |
| §5 Speaking Rate (archetype table, `AVSpeechUtterance` rate param, dynamic-by-emotion table, by-stage table) | `voice-psychoacoustics.md#speaking-rate` | migrated |
| §6 Vocal Texture (breathiness, warmth EQ, chorus, micro-pitch, per-stage texture table) | `voice-psychoacoustics.md#vocal-texture-breathiness-and-warmth` | migrated |
| §7 Sound Design References (Animal Crossing, Undertale, Banjo-Kazooie, Pikmin, Ghibli, Spore) | `game-voice-sound-design.md` | migrated |
| §8 The Hybrid Voice Pipeline (architecture diagram, per-stage pipeline pseudocode, processing chain order) | `creature-voice-design.md#superseded-design-history-the-original-pipeline-concept` | migrated as superseded design history (this is the detailed pseudocode for the same never-built pipeline named in §2) |
| §9 Audio Processing on macOS (framework comparison, `AVAudioEngine`/`AVSpeechSynthesizer` Phase-1 code sample, write-to-buffer pattern, voice selection table) | `voice-tts-stack.md#the-actual-engine-sherpa-onnx--no-avspeechsynthesizer-no-fallback` (confirmation this never shipped), `creature-voice-design.md#voice-selection-for-tts-base-historical-macos-voice-era` (voice-selection table) | migrated, corrected — this entire section describes the `AVSpeechSynthesizer`-based architecture that was NOT adopted; documented as superseded rather than current |
| §10 The First Word Moment (design requirements, first-word-choice ranking, audio-design sequence, journal schema, post-first-word progression table) | `speech-milestones.md#milestone-2-the-first-audible-word-beast-developers-name-audio-only`, `#design-lineage-how-two-milestones-emerged-from-one-idea` | migrated, and the R3 "rejected" characterization corrected — this design shipped as a second milestone, not as a rejected alternative (see this wave's return message) |
| §10 in-line dialogue (Claude/Samantha discussing the first-word moment, "I'm approving this section with zero changes") | *(presentation only)* | dropped-with-justification — theatrical framing dropped; the approval sentiment itself is superseded by this wave's finding that the design shipped as a second milestone rather than being adopted unmodified |
| §11 Personality-Driven Voice Variation (5-axis table, Specialty timbre table, `VoiceProfile` 11-field schema) | `creature-voice-design.md#personality--voice-mapping-merged-tts-research-17--creature-voice-design-11`, `#the-original-aspirational-voiceprofile-schema` | migrated, corrected — Specialty axis and 11-field schema flagged as aspirational/unbuilt against the shipped 4-axis `PersonalitySnapshot` and 4-field `VoiceParameters` |
| §12 Implementation Roadmap (Phases 1–5, task tables) | *(not migrated as prescriptive)* | dropped-with-justification — historical planning artifact (task/estimate tables) with no content beyond what §2–11 already state as design targets |
| Appendix A Audio Budget | *(not migrated)* | dropped-with-justification — describes per-operation cost estimates (`AVSpeechSynthesizer.write()` ~50-200ms, AudioKit ~2ms/buffer) for an architecture that was never built; the shipped system's actual performance characteristics belong to `voice-tts-stack.md` (verified against real code, not this estimate) |
| Appendix B Sound File Inventory (~575KB pre-recorded asset budget) | *(not migrated)* | dropped-with-justification — describes a pre-recorded-sample asset pipeline (chirps, syllables, breath sounds) that was superseded entirely; the shipped system synthesizes everything programmatically (`SoundGenerators.swift`, confirmed by SP3a/SP3b's code checks — "No audio files needed") |
| Appendix C Key Technical References | `game-voice-sound-design.md#citations` (sound-design links only) | migrated (partial) — the sound-design/game-reference links were migrated; the `AVSpeechSynthesizer`/AudioKit/vDSP API-documentation links were not, since that API path is documented as superseded rather than needing further reference links |
| Opening/closing collaborative-dialogue framing (the full Claude/Samantha conversation structuring the whole document) | *(presentation only)* | dropped-with-justification — narrative device, not content; every substantive claim made within the dialogue is accounted for in the rows above |

# `docs/archive/plan/phase-4-embodiment/PHASE-4.md` (assigned: P4-T2-03 only)

| Source section | → Target concept#section | Status |
|---|---|---|
| P4-T2-03 stage-gated limits table, 7-styles table, filtering-layer description, IPC example, implementation notes, error handling | `speech-filtering.md` (stage limits, style gates, round-trip, error path) | migrated, corrected — Drop's "Max Chars 1" corrected to the reconciled 3 (daemon)/6 (MCP, dead value) numbers; verification checklist items folded into the relevant prose sections rather than reproduced as a QA list |

# `docs/archive/plan/phase-5-speech/PHASE-5.md` (assigned: Track 1 P5-T1-01 through P5-T1-16, Track 2 P5-T2-01 through P5-T2-11; Track 3 explicitly NOT assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| Goal, Dependencies, Architecture Notes (where speech lives), Performance Budget | *(plan-wrapper scaffolding)* | dropped-with-justification — historical planning artifact; the "where speech lives" file-path claims are stale (e.g. `SpeechFilter.swift` vs. actual `SpeechFilterEngine.swift`, `Feed/CommitEater.swift` vs. actual `Feed/XPCalculator.swift` etc.) and superseded by this wave's verified code paths throughout |
| P5-T1-01 Speech Bubble Base Node | `speech-rendering.md#bubble-anatomy` | migrated, corrected — fixed min/max size range replaced with the real dynamic per-stage width table |
| P5-T1-02 Bubble Positioning Algorithm | `speech-rendering.md#per-stage-rendering-modes` | migrated, confirmed exact match |
| P5-T1-03 Bubble Animation System | `speech-rendering.md#appear--disappear-animation`, `#hold-duration` | migrated, corrected — hold-duration formula's constants differ from the shipped ones (documented as such) |
| P5-T1-04 Stage-Gated Rendering Modes | `speech-rendering.md#per-stage-rendering-modes` | migrated |
| P5-T1-05 Drop Symbol Set & Rendering (17-symbol table, selection algorithm) | `speech-rendering.md#drop-stage-the-17-symbol-vocabulary` | migrated, corrected — this wave's own doc-internal inconsistency flag (headline claims 17, table lists only 7) resolved by using the verified 17-entry `DropSymbolSet.symbols` array as canon |
| P5-T1-06 Speech Filtering Engine Architecture (5-stage pipeline, vocabulary files) | `speech-filtering.md` (stage limits, vocabulary simplification, stage punctuation) | migrated, corrected — JSON vocabulary files (`critter_vocab.json` etc.) don't exist; documented as a scale gap against the shipped hardcoded maps |
| P5-T1-07 Failed Speech Logging | `speech-filtering.md#failed-speech--the-journal` | migrated, corrected — the `intended_text` round-trip gap (MCP sends it, daemon never reads it) is a new finding beyond what this source describes |
| P5-T1-08 Speech Cache & Replay | *(not this wave's primary ownership — cache mechanics referenced)* | deferred (partial) — `SpeechCache.swift`'s dream/idle-replay mechanics are referenced from `speech-rendering.md` and `speech-milestones.md` but the cache's own full schema/replay-scenario detail is not separately re-authored here; no other SP4 concept claims to own it exhaustively, so if no other wave picks it up this is a gap to flag, not a silent drop |
| P5-T1-09 Dream Bubble Rendering | `speech-rendering.md` (style table, `dream` row) | migrated (partial) — the dream-bubble visual specifics (wavy text, Dusk fill, no tail) are captured in the styles table; the dream-fragment content-selection algorithm (`SpeechCache.dreamFragment`) is referenced but not reproduced in full, since it's cache-system detail (see P5-T1-08 note above) |
| P5-T1-10 The First Word Ceremony | `speech-milestones.md#milestone-1-the-first-word-critter-own-name-visual` | migrated, confirmed exact match (phase timings verified against shipped code) |
| P5-T1-11 Sage Narration Mode | `speech-rendering.md#narration-overlay-sage` | migrated, confirmed close match |
| P5-T1-12 Apex World-Shaping Speech | *(not this wave)* | deferred — this is a `SpeechCoordinator` feature but its substance (weather/time/environment triggers) belongs with the world/weather systems wave (SP6b), which owns weather and time-of-day; `speech-filtering.md`/`speech-rendering.md` do not claim this territory |
| P5-T1-13 Personality Influence on Speech | `speech-filtering.md#personality-post-filter-modifiers` | migrated, corrected — Focus/Specialty axis modifiers flagged as designed-but-unimplemented against the shipped 2-of-4-axis `applyPersonalityModifiers` |
| P5-T1-14 Speech Bubble Styles (7-style table with stage reqs) | `speech-rendering.md#the-7-speech-styles`, gate authority cross-linked to `speech-filtering.md#style-stage-gates-the-real-three-way-reconciliation` | migrated, corrected — `exclaim` and `sing` stage minimums corrected against the daemon's actual enforced gate (both `critter`, not this doc's `critter`/`beast` split respectively — note this source doc already said `critter` for both, matching this wave's adjudicated canon; the drift is against `speak.ts`, not this source) |
| P5-T1-15 MCP `pushling_speak` Tool Integration (call flow, error responses) | `speech-filtering.md#the-round-trip`, error rows folded into relevant sections | migrated |
| P5-T1-16 Between-Session Autonomous Speech | *(not this wave)* | deferred — this is a Layer-1/autonomous-behavior trigger table that belongs with the behavior-stack concept (SP3a, already completed) or the commit-feeding concept, not the filtering/rendering/voice concepts this wave owns; flagged for the Orchestrator to confirm it landed somewhere |
| P5-T2-01 sherpa-onnx Runtime Integration (`VoiceEngine` API surface) | `voice-tts-stack.md#the-actual-engine-sherpa-onnx--no-avspeechsynthesizer-no-fallback` | migrated, corrected — no `VoiceEngine` class exists; the actual API surface is `SherpaOnnxBridge` + `ModelManager` + `VoiceSystem`, documented as such |
| P5-T2-02 espeak-ng Model for Drop Babble (phoneme-to-symbol mapping table) | `voice-tts-stack.md#babble-generation-drop-stage-audio` | migrated, corrected — the described symbol→phoneme mapping table (`!`→"ba!" etc.) doesn't exist in code; `generateBabbleText()` produces random phoneme sequences unrelated to the specific symbol being displayed, documented as such |
| P5-T2-03 Piper TTS Low-Quality Model for Critter (babble-ratio bands) | `voice-tts-stack.md#critter-speech-mix-babble-to-words-ratio` | migrated, reconciled — three discrete bands vs. the code's continuous formula, documented as compatible approximation not contradiction |
| P5-T2-04 Kokoro-82M Model for Beast+ Speech | `voice-tts-stack.md#the-3-tiers-not-6` | migrated |
| P5-T2-05 Audio Pipeline (`AVAudioEngine`) | `voice-tts-stack.md#the-audio-effects-chain-confirmed-real` | migrated, confirmed close match |
| P5-T2-06 Personality-Driven Voice Character (mapping table, `creature_voice` SQLite storage) | `voice-tts-stack.md#voice-parameters-from-personality` | migrated, corrected — `creature_voice` table doesn't exist; parameters are recomputed in memory, documented as such |
| P5-T2-07 Three-Tier Voice Switching (tier assignments, transition behavior) | `voice-tts-stack.md#the-3-tiers-not-6`, `#tier-loading--switching` | migrated, corrected — "Eloquent"/"Transcendent" tier names dropped (Sage/Apex share the `speaking` tier) |
| P5-T2-08 First Audible Word | `speech-milestones.md#milestone-2-the-first-audible-word-beast-developers-name-audio-only` | migrated, corrected — the described `first_audible_word` journal entry is never written by the shipped code; documented as a design/code gap |
| P5-T2-09 Audio Cache System | `voice-tts-stack.md#caching` | migrated, confirmed close match |
| P5-T2-10 Dream Audio | `voice-tts-stack.md#dream-audio` | migrated, confirmed exact match |
| P5-T2-11 Async TTS & Main Thread Safety | `voice-tts-stack.md` (implicit throughout — `voiceQueue` serial dispatch, non-blocking `generate()`) | migrated (partial) — the specific "alert if >500ms" instrumentation claim was not verified in code this wave and is not asserted as shipped; the queue-depth-3 max-queue-depth rule is captured (`VoiceSystem.maxQueueDepth`) |
| Track 3 (P5-T3-01 through P5-T3-10, commit eating/XP) | *(not this wave)* | deferred — explicitly out of scope per this wave's dispatch; owned by whichever wave covers commit-feeding/creature-eating (`commit-feeding-xp.md`, already authored by another wave) |
| QA Gate (Track 1/2/3 verification checklists, Integration Verification) | *(not migrated as a standalone list)* | dropped-with-justification — a QA checklist is a testing artifact, not canon knowledge; every claim it verifies is either confirmed or corrected in the prose sections above |

# Cross-wave dependencies noted during authoring

- `growth-stages.md`, `personality-emotional-state.md`, and
  `commit-feeding-xp.md` were confirmed to already exist (other waves
  completed before this one finished) and are cross-linked directly rather
  than treated as forward references.
- `speech-milestones.md` and `creature-voice-design.md` both reference
  `docs/DECISIONS.md` R3; this wave does not edit `DECISIONS.md` itself
  (out of scope per the dispatch's file-ownership constraint) — the proposed
  amendment is relayed in this wave's return message for the Orchestrator to
  action.
