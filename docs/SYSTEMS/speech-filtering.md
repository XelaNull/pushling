---
type: System
title: Speech Filtering
description: The pipeline that reduces Claude's full-intelligence speech to stage-appropriate creature output — the dual client+daemon filter passes, per-stage limits, failed_speech journaling, and the SPEECH_GATED error path.
status: Live
tags: [speech, filtering, system]
timestamp: 2026-07-02T00:00:00Z
---

This is **the** authority for the speech-filtering pipeline, superseding the
filtering sections of `PUSHLING_VISION.md` ("The Filtering Approach"),
`docs/archive/plan/phase-4-embodiment/PHASE-4.md` (P4-T2-03), and
`docs/archive/plan/phase-5-speech/PHASE-5.md` (P5-T1-06, P5-T1-07, P5-T1-13,
P5-T1-15). [The MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md)'s
`pushling_speak` section explicitly defers the pipeline's internals here.
Verified against `Pushling/Sources/Pushling/Speech/SpeechFilterEngine.swift`,
`Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift`,
`Pushling/Sources/Pushling/IPC/ActionHandlers.swift`, and
`mcp/src/tools/speak.ts`.

# Two Independent Filter Passes, Not One Shared Contract

Claude's text passes through **two separate, independently-implemented**
filters before it reaches the Touch Bar — not one filter mirrored on both
sides of the wire.

1. **MCP client-side** (`mcp/src/tools/speak.ts`, TypeScript): scores words
   with its own dictionaries (`STOP_WORDS`, `TECH_WORDS`, `EMOTION_WORDS`),
   trims to the stage's char/word budget, and sends the **already-shortened**
   result to the daemon as the `text` IPC parameter.
2. **Daemon-side** (`SpeechFilterEngine.swift`, Swift): re-tokenizes and
   re-scores that already-shortened text with its own, different dictionaries
   (`fillerWords`/`commonVerbs`/`commonAdjectives`/`technicalTerms`), reduces
   again to the same stage budget, and is what actually gets rendered.

Because both implementations converge on the same critter/beast/sage/apex
numbers (see below), the daemon's second pass on already-short text is mostly
a no-op re-simplification — but the char/word **budgets** are canonically the
daemon's, since `SpeechCoordinator.speak()` (invoked from
`ActionHandlers.handleSpeak`) is the actual, unbypassable rendering gate. A
caller cannot get an MCP-filtered string past a stricter daemon gate; the
daemon always gets the final word.

# Stage Limits (Canonical)

| Stage | Max Chars | Max Words | Behavior |
|---|---|---|---|
| Egg | 0 | 0 | Cannot speak. `SpeechCoordinator.speak()` returns a dedicated refusal before the filter pipeline ever runs. |
| Drop | symbol only (see below) | 0 | No word output — mapped to one of 17 canonical symbols. See [speech-rendering](/REFERENCE/speech-rendering.md). |
| Critter | 20 | 3 | ~200-word informal vocabulary simplification (see below). |
| Beast | 50 | 8 | Light vocabulary simplification, sentence structure preserved. |
| Sage | 80 | 20 | Minimal simplification. |
| Apex | 120 | 30 | Pass-through — no reduction. |

Both live implementations (`speak.ts STAGE_LIMITS` and
`SpeechFilterEngine.stageLimits()`) agree exactly on critter/beast/sage/apex:
20/3, 50/8, 80/20, 120/30. This resolves the drift the survey flagged against
`PUSHLING_VISION.md`'s older table (12/40/100/140 chars) and
`docs/archive/plan/phase-4-embodiment/PHASE-4.md`'s table (also 20/3, 50/8, 80/20,
120/30 — that one already matched) — per DOCS WIN, code wins; the vision
doc's 12/40/100/140 row is stale and superseded.

**Drop's char limit is a live three-way mismatch, not fully resolved by
code agreement.** `SpeechFilterEngine.stageLimits(.drop)` declares
`(maxChars: 3, maxWords: 0)`; `speak.ts STAGE_LIMITS.drop` declares `[6, 0]`.
Neither number is actually enforced as a truncation limit for Drop — the
Drop branch of both filters bypasses char/word truncation entirely and
instead selects one whole symbol glyph (see below). The daemon's `3` happens
to equal the longest glyph in its own 17-symbol inventory (`"..."` and
`"zzz"`, both 3 characters); the MCP's `6` doesn't correspond to anything in
its own 8-symbol table (longest is also `"..."` at 3 characters) — it
appears to be an unused, uninforced constant carried over from an earlier
draft. **Canon: 3 characters**, matching the daemon's actual symbol
inventory; `speak.ts`'s `6` should be corrected to `3` (flagged for the
Orchestrator's backlog — not a doc call to make).

# Drop Stage: Symbol Selection, Not Word Reduction

At Drop, the pipeline doesn't shorten words — it discards them entirely and
picks one symbol that best matches the detected emotional intent
(`DropSymbolSet.selectSymbol` → `symbolForEmotion`, deterministic, one symbol
per emotion category). `contentLossPercent` is always reported as `100` for
Drop, and `isFailedSpeech` is `true` whenever the input contained any content
words at all — Drop speech is *definitionally* lossy. The full 17-symbol
inventory and its selection rules are owned by
[speech-rendering](/REFERENCE/speech-rendering.md); this concept only owns
the emotion-detection step that feeds it (`EmotionDetector.detect`, keyword +
punctuation scoring, deterministic tie-break by emotion priority).

**A verified implementation bug in the Drop double-filter interaction.**
Because MCP pre-selects a symbol client-side (from its own 8-symbol
`DROP_SYMBOLS` table: `! ? ♡ ~ ... ♪ ★ !?`) and sends *that already-chosen
glyph* as the `text` IPC parameter, the daemon's `EmotionDetector.detect()`
then runs its keyword/punctuation scoring against the glyph itself — not
Claude's original sentence. Traced through `EmotionDetector.detect`'s actual
keyword and punctuation checks: `!`, `?`, `!?`, and `"..."` re-detect
correctly (they contain matchable punctuation), but `♡`, `~`, `♪`, and `★`
match no keyword or punctuation rule and fall through to `.neutral`, which
`symbolForEmotion(.neutral)` renders as `"..."`. Concretely: Claude speaks
`"that's wonderful, I love this!"` at Drop stage → MCP's `filterToSymbol`
matches `"wonderful"`/`"love"` against its `positiveWords` list and picks
`"♡"` → the daemon receives `text: "♡"` → `EmotionDetector.detect("♡")` finds
no match → returns `.neutral` → the creature displays `"..."` instead of the
heart the MCP layer chose. Four of the MCP's eight symbols (`♡`, `~`, `♪`,
`★`) are silently downgraded to `"..."` this way roughly half the time this
architecture is exercised. This is a genuine code defect discovered during
this wave's verification, not a documentation drift — flagged for
`docs/DECISIONS.md` / the Orchestrator's backlog (see this wave's return
message).

# Tokenization, Emotion Detection, and Word Scoring (Stages 1–3)

Before stage reduction (Stage 4, below) runs, the daemon-side engine
tokenizes and scores the input. `PHASE-5.md` P5-T1-06 specified this as a
3-stage pipeline, and the shipped `SpeechFilterEngine` matches its structure
closely:

- **Stage 1 (Tokenization)**: each word is tagged by a `WordTag` enum whose
  raw values double as importance scores — `filler`(0), `connector`(1),
  `adverb`(2), `adjective`(3), `verb`(4), `noun`(5), `emotionWord`(6). The
  design's stated hierarchy was "nouns > verbs > adjectives > adverbs >
  fillers > connectors" — the shipped ordering matches for noun/verb/
  adjective/adverb but **inverts the bottom two tiers**: code ranks
  `connector` above `filler`, the design ranked fillers above connectors.
  Minor, but a real discrepancy, not just a naming difference. Classification
  uses a curated dictionary rather than NLP, matching the design's "~500
  tagged words" scale in spirit (the code's own header comment states
  "~500-word curated vocabulary lookups").
- **Stage 2 (Emotion Extraction)**: `EmotionDetector.detect` returns one
  `SpeechEmotion` category (positive/negative/neutral/questioning/
  exclaiming/warning/affection/sleepy/contentment — see
  [speech-rendering](/REFERENCE/speech-rendering.md) for how these map to
  Drop symbols) via keyword and punctuation scoring. The design additionally
  specified a numeric **confidence score (0.0–1.0)** alongside the category;
  no such score exists anywhere in `EmotionDetector` — the shipped detector
  is categorical only, with no confidence value attached to its result.
- **Stage 3 (Key Word Selection / scoring boosts)**: `scoreWords` applies
  three of the design's four boosts, verified exact — emotion words **+3**,
  capitalized non-sentence-start words (treated as proper nouns) **+2**,
  technical terms **+1** (a ~30-entry `technicalTerms` set: `"api"`,
  `"auth"`, `"bug"`, `"refactor"`, `"deploy"`, etc.). The design's fourth
  boost — **+2** for "words matching recent commit content" — does not
  exist in code; there is no commit-context input anywhere in
  `SpeechFilterEngine`, so a word's relevance to what the creature just ate
  never affects which words survive filtering.

The design's vocabulary-file architecture (`critter_vocab.json` 200 words,
`beast_vocab.json` 1000 words, `sage_vocab.json` 5000 words,
`emotion_tags.json`, `simplify_map.json`) is covered separately below under
Vocabulary Simplification — none of these files exist; the shipped
vocabulary is a small hardcoded Swift dictionary at every tier.

# Failed Speech & the Journal

- **Threshold**: `isFailedSpeech = contentLossPercent > 40` (percentage of
  content words — tag score ≥ `.adjective` — dropped during Stage 4
  reduction). Matches `PHASE-5.md` P5-T1-06/07's ">40%" rule exactly.
- **Journal type selection** (`ActionHandlers.handleSpeak`):
  `loggedAsFailedSpeech ? "failed_speech" : "ai_speech"`. Both types exist in
  the journal's type `CHECK` constraint (`State/Schema.swift`).
- **`SPEECH_GATED`** is the IPC error code returned whenever
  `SpeechCoordinator.speak()` rejects a request: Egg-stage attempt, a style
  below its `minimumStage` (see below), `dream` style while awake, or empty
  text.
- Recallable via `pushling_recall("failed_speech")` — see
  [the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md#pushling_recall).

**`intended_text` is sent by MCP but never read by the daemon.**
`speak.ts` sets `params.intended_text = text` (Claude's true original
message) whenever its own client-side filter judged content was lost — but
`ActionHandlers.handleSpeak` reads only `req.params["text"]` (the
MCP-filtered string) to build the `SpeechRequest`. Consequently,
`SpeechResponse.intended` — and therefore what gets journaled and returned to
Claude as `"intended"` — is actually **the MCP's already-shortened text**,
not Claude's true original full-intelligence message, whenever a Drop/
Critter/Beast/Sage speak call also lost content in the daemon's own
re-filter pass. `PHASE-5.md` P5-T1-07's "MCP response augmentation" example
implies the full original round-trips intact; in the shipped wiring it does
not survive the MCP hop. Flagged for the Orchestrator's backlog — the fix
(daemon reads `intended_text` when present) is a code change, not a doc call.

# Personality Post-Filter Modifiers

Applied by `SpeechFilterEngine.applyPersonalityModifiers`, after Stage 4
(reduction) and before the character-limit truncation:

| Axis | Condition | Effect |
|---|---|---|
| Energy | < 0.3 | Lowercases the whole string; appends `"..."` if it doesn't already end in `...`/`?`; strips all `!`. |
| Energy | > 0.7 | Appends `!` if the string doesn't already end in `!`/`?`. |
| Discipline | < 0.3 | Informal substitutions: `"yes"→"ya"`, `"you"→"u"`. |
| Discipline | > 0.7 | Appends `.` if the string has no terminal punctuation. |

`PHASE-5.md` P5-T1-13 describes a richer table spanning all 5 of the
design's original personality axes, with only Energy and Discipline making
it into `applyPersonalityModifiers`:

| Axis | Low (0.0–0.3) | High (0.7–1.0) |
|---|---|---|
| Energy | Lowercase everything, trailing `...`, fewer `!` (shipped, above) | Occasional ALL CAPS, extra `!`, shorter punchier sentences (shipped, above) |
| Verbosity | Maximum word reduction — fragments, single words, long pauses between bubbles | Minimum word reduction — full sentences preserved, extra descriptive words added |
| Focus | Scattered topic changes, may reference unrelated things | Precise word choice, technical terms preserved even through filtering |
| Discipline | Informal, dropped articles, sentence fragments, "ya" for "yes" (shipped, above) | Proper grammar always, complete sentences, periods at the end (shipped, above) |
| Specialty | N/A (category, not spectrum) | Influences word choice: Systems creature uses precise terms, Web creature uses casual/emoji-adjacent language |

Verified: neither `verbosity`, `focus`, nor `specialty` is referenced
anywhere in `applyPersonalityModifiers`, and `PersonalitySnapshot`
(`Behavior/LayerTypes.swift`) has no `specialty` field at all — see
[the growth-stages/personality concept](/REFERENCE/personality-emotional-state.md)
for the full 4-axis model. Verbosity's absence is notable because, unlike
Focus and Specialty, `verbosity` **is** a live axis on `PersonalitySnapshot`
— it drives the audio-side intonation range in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md)'s
`VoicePersonalityCalculator`, but that is a different mechanism (voice
pitch/rate parameters) from this design's *text*-content Verbosity effect
(word-count reduction and sentence-fragment intensity). The Verbosity/Focus/
Specialty text-filtering modifiers are **designed but not implemented** —
preserved here as intent, not current behavior.

# Vocabulary Simplification

`simplifyWord` (Critter) and `simplifyWordBeast` (Beast) consult small,
hand-curated maps (`critterSimplifyMap`: ~20 entries, e.g. `"authentication"→"auth"`,
`"refactoring"→"fix"`; `beastSimplifyMap`: 5 entries, e.g.
`"configuration"→"config"`) — words absent from the map fall back to a
length heuristic (Critter: truncate anything over 5 characters). `PHASE-5.md`
P5-T1-06 describes this as loading three JSON vocabulary files
(`critter_vocab.json` 200 words, `beast_vocab.json` 1000 words,
`sage_vocab.json` 5000 words) plus `emotion_tags.json` and
`simplify_map.json`. None of these files exist in the repo — the vocabulary
is a small hardcoded Swift dictionary, an order of magnitude smaller than the
designed 200/1000/5000-word scale. This is a scale gap between design intent
and shipped implementation, not a contradiction to adjudicate; both
describe the same mechanism (curated lookup, not NLP), just at very
different sizes.

# Stage Punctuation

`addStagePunctuation`: Critter appends `!` if the reassembled text has no
terminal punctuation (`"Critter loves !"` per the code comment); Beast and
Sage add nothing automatically here (their punctuation comes from the
Discipline personality modifier instead, or is simply absent).

# Style Stage Gates: the Real Three-Way Reconciliation

Three sources define per-style minimum stages, and they don't all agree.
`SpeechCoordinator.speak()` — which enforces `request.style.minimumStage >
currentStage` via `SpeechBubbleNode.SpeechStyle.minimumStage` — is the
**actual, final, unbypassable gate**: every `pushling_speak` call is routed
through it (`ActionHandlers.handleSpeak` → `gc.speechCoordinator.speak`).

| Style | Daemon truth (enforced) | MCP declared (`speak.ts STYLE_STAGE_MIN`) | Agreement |
|---|---|---|---|
| `say` | drop | drop | match |
| `think` | drop | drop | match |
| `exclaim` | **critter** | drop | **mismatch — MCP admits a Drop-stage call, daemon then rejects it with `SPEECH_GATED`** |
| `whisper` | critter | critter | match |
| `sing` | **critter** | beast | **mismatch — MCP is stricter than the daemon actually is, blocking a Critter-stage call the daemon would accept** |
| `dream` | drop | egg (`"spore"`, index 0) | harmless — Egg is blocked earlier by the stage-0 refusal regardless of style |
| `narrate` | sage | sage | match |

The `exclaim` mismatch was already flagged in this wave's brief (client +
`PUSHLING_VISION.md`/`PHASE-4.md`'s design docs say `drop`, code says
`critter`). The **`sing` mismatch is a new finding from this wave**: it runs
the opposite direction — the MCP layer is too *restrictive*, not too
permissive. **Canon (this concept): `exclaim` and `sing` both require
Critter+**, matching the daemon's actual, unbypassable gate. `speak.ts`'s
`STYLE_STAGE_MIN` should be corrected to `exclaim: "critter"` and
`sing: "critter"` — a code fix, flagged for the Orchestrator's backlog, not
a doc call.

# The Round-Trip

```
Claude → pushling_speak(text, style?)
  → MCP: validate style, check stage via cached snapshot, client-filter text
  → IPC {"cmd":"speak","action":<style>,"params":{"text":<filtered>,"style":<style>[,"intended_text":<original>]}}
  → Daemon CommandRouter.handleSpeak → SpeechCoordinator.speak(SpeechRequest)
     1. Gate: Egg stage → refuse
     2. Gate: style.minimumStage vs currentStage → refuse (SPEECH_GATED)
     3. Gate: dream style while awake → refuse
     4. Gate: empty text → refuse
     5. SpeechFilterEngine.filter() — the daemon's own reduction pass
     6. Render bubble / narration overlay (see speech-rendering.md)
     7. Cache utterance (SpeechCache)
     8. Notify VoiceIntegration for TTS audio (see voice-tts-stack.md)
     9. Journal: "failed_speech" or "ai_speech"
  → Daemon responds {ok, spoken, intended, filtered, content_loss_percent?}
  → MCP returns to Claude with pending_events
```

See [the IPC command catalog](/ARCHITECTURE/ipc-command-catalog.md) for the
generic wire-envelope shape this rides on.

# A Naming Footnote: Egg vs. Spore

The MCP-side Egg-stage refusal (`stage === "spore"` in `speak.ts`) checks
against the literal string `"spore"`, while the daemon's `GrowthStage` enum
and the SQLite `stage` column both use `"egg"` (per
`docs/DECISIONS.md` R1: code reality is canon, first stage is `egg`). This
is the same cross-boundary naming split documented in full at
[the growth-stages concept](/REFERENCE/growth-stages.md); it's called out
here only because `pushling_speak`'s Egg-stage refusal is the first place a
caller actually observes it, firing entirely client-side before the daemon
is ever contacted.

# Citations

[1] `Pushling/Sources/Pushling/Speech/SpeechFilterEngine.swift`
[2] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift`
[3] `Pushling/Sources/Pushling/Speech/DropSymbolSet.swift` (`EmotionDetector`)
[4] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift` (`handleSpeak`)
[5] `mcp/src/tools/speak.ts`
[6] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`PersonalitySnapshot`)
[7] `PUSHLING_VISION.md` — Speech Evolution: The Filtering Approach
[8] `docs/archive/plan/phase-4-embodiment/PHASE-4.md` — P4-T2-03
[9] `docs/archive/plan/phase-5-speech/PHASE-5.md` — P5-T1-06, P5-T1-07, P5-T1-13, P5-T1-15
