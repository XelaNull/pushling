---
type: Reference
title: Speech Rendering
description: How speech appears on the Touch Bar — bubble anatomy, per-stage rendering modes and size budgets, the Drop-stage 17-symbol vocabulary, the narration overlay, and the 7 speech bubble styles.
status: Live
tags: [speech, rendering, touchbar]
timestamp: 2026-07-02T00:00:00Z
---

Authority for the visual side of speech — `SpeechBubbleNode`,
`DropSymbolSet`, and `NarrationOverlay`. See
[speech-filtering](/SYSTEMS/speech-filtering.md) for what text reaches the
bubble and [voice-tts-stack](/SYSTEMS/voice-tts-stack.md) for the audio that
plays alongside it. Sources: `docs/archive/plan/phase-5-speech/PHASE-5.md`
(P5-T1-01 through P5-T1-05, P5-T1-09, P5-T1-11, P5-T1-14),
`PUSHLING_VISION.md` (Speech Evolution: Text Speech Bubbles).

# Bubble Anatomy

A `SpeechBubbleNode` is a 2-node composite: one `SKShapeNode` combining the
rounded-rect bubble and its tail triangle into a single `CGPath` (kept at one
node instead of two), plus one `SKLabelNode` for text. Default palette: Gilt
fill at 85% opacity, Void text, Bone 1pt border. `zPosition = 950`, above the
fog-of-war layer (900) so speech is never occluded. The bubble is a child of
the creature node (or, for the primary render path, added to the scene root
and positioned in scene coordinates so it isn't clipped by other layers).

`PHASE-5.md` P5-T1-01 specifies a fixed min/max bubble size (20×10 to
120×18pt). The shipped code has no such fixed range — bubble width is
computed dynamically per stage from `bubbleMaxWidth()` and the actual text
metrics; see the per-stage table below for the real numbers.

# Per-Stage Rendering Modes

| Stage | Position mode | Max bubble width | Font | Notes |
|---|---|---|---|---|
| Egg | — | — | — | No speech at all; `SpeechCoordinator` gates before any bubble is created. |
| Drop | `.floating` | 12pt | 8pt bold | No bubble frame — the symbol glyph is a standalone label. Sine-wave horizontal drift + slow upward float. |
| Critter | `.above` | 40pt | 6pt | Compact bubble directly above the creature's head. |
| Beast | `.sideRight` / `.sideLeft` | 60pt | 7pt | Side-positioned (dynamically flips to the left if the creature is within 30pt of the right edge); word-wrap up to 2 lines. |
| Sage | side | 80pt | 7pt | Up to 3-bubble chains, 0.3s stagger, stacked 12pt apart. |
| Apex | side | 120pt | 7pt | Same chaining as Sage, larger sizing. |

These per-stage width values (`bubbleMaxWidth(for:)`) match
`PHASE-5.md` P5-T1-02's "Bubble Max Width" column exactly
(12/40/60/80/120) — a rare 1:1 match between design intent and shipped code.

# Hold Duration

```
symbols (<= 3 chars):  2.5s flat
otherwise:             max(3.0, min(8.0, wordCount * 0.8 + 1.5))
```

`PHASE-5.md` P5-T1-03 proposed a different formula
(`max(1.5, min(5.0, wordCount * 0.5 + 1.0))`, with symbols held at a flat
1.2s). The shipped constants are all higher — a higher floor, a higher cap,
a longer symbol hold, and a steeper per-word cost. Code wins per DOCS WIN;
the P5-T1-03 numbers are a superseded early estimate.

# Appear / Disappear Animation

- **Appear** (0.15s default): scale overshoots 0.0 → 1.05 with `easeOut`
  over the first 80% of the duration, then settles 1.05 → 1.0 over the
  remaining 20%; opacity ramps 0 → 1 linearly over the first ~67%.
- **Disappear** (0.4s): scale 1.0 → 0.95 and opacity 1 → 0 together with
  `easeIn`; a slight upward drift of 7.5pt/s (3pt total over the 0.4s).

Matches `PHASE-5.md` P5-T1-03's timings closely (0.15s appear with a 1.05
overshoot, 0.4s disappear with a 3pt drift) — confirmed accurate.

# Drop Stage: The 17-Symbol Vocabulary

`DropSymbolSet.symbols` defines the complete inventory:

| Glyph | Meaning | Emotion category | Notes |
|---|---|---|---|
| `!` | Alert / excitement | exclaiming | |
| `?` | Curiosity / confusion | questioning | |
| `...` | Thinking / processing | neutral | 1.5s hold override |
| `!?` | Surprise / shock | warning | |
| `~` | Contentment / ease | contentment | |
| `zzz` | Sleepy | sleepy | 1.8s hold override |
| `!!` | Extreme excitement | exclaiming | |
| `♥` (U+2665) | Love / affection | affection | |
| `★` (U+2605) | Delight / milestone | positive | |
| `♪` (U+266A) | Music / singing | contentment | Rotates; 1.5s hold override |
| `↑` (U+2191) | Up / growth / increase | positive | |
| `↓` (U+2193) | Down / decrease / concern | negative | |
| `→` (U+2192) | Direction / go | neutral | |
| `←` (U+2190) | Back / return | neutral | |
| `…` (U+2026, single-glyph ellipsis — distinct codepoint from `"..."`) | Trailing off | neutral | 1.5s hold override |
| `❤` (U+2764) | Strong love | affection | |
| `✨` (U+2728) | Sparkle / magic | positive | |

**Selection is a fixed, deterministic one-to-one lookup**
(`symbolForEmotion`): every emotion category maps to exactly one canonical
symbol — `positive → ★`, `negative → ↓`, `neutral → ...`,
`questioning → ?`, `exclaiming → !`, `warning → !?`, `affection → ♥`,
`sleepy → zzz`, `contentment → ~`. Two emotion categories have *two*
plausible glyphs defined in the inventory but only one is ever reachable:
`♥`/`❤` both exist for affection but only `♥` is returned; `★`/`✨`/`↑` all
exist as positive-adjacent glyphs but only `★` is returned. `↑`, `↓`, `→`,
`←`, `❤`, and `✨` are all defined in `DropSymbolSet.symbols` but have no
code path that selects them through `symbolForEmotion` — they are either
unused vocabulary or a hook for a future contextual selector, not a
doc/code drift.

**Three different "heart" glyphs exist across three sources for one
concept.** `mcp/src/tools/speak.ts`'s own `DROP_SYMBOLS` constant (its
8-entry client-side table: `! ? ♡ ~ ... ♪ ★ !?`) uses `♡` (U+2661, hollow
heart) for positive/affectionate intent, matching `PUSHLING_VISION.md`'s
Drop-stage symbol list — but `♡` never appears in the daemon's 17-symbol
canonical inventory above, which uses `♥` (U+2665) and `❤` (U+2764) instead.
**Canon: `♥` (U+2665)**, per `DropSymbolSet.swift`, the daemon's actual
rendering authority. See
[speech-filtering](/SYSTEMS/speech-filtering.md#drop-stage-symbol-selection-not-word-reduction)
for how this glyph mismatch compounds into a verified selection bug when the
MCP's pre-chosen glyph is re-processed by the daemon.

**Rendering specifics**: each symbol is a single `SKLabelNode`, system bold,
8pt, Gilt. Multi-character symbols (`zzz`, `...`, `!?`, `!!`) render as one
label rather than per-character. `♪` rotates gently; the rest are static
apart from the shared floating-glyph drift.

# The 7 Speech Styles

Visual treatment from `SpeechBubbleNode.configureBubble`'s per-style switch:

| Style | Visual | Fill | Border | Extra |
|---|---|---|---|---|
| `say` | Standard rounded rect | Gilt @ 85% | Bone, 1pt | — |
| `think` | Ellipse ("cloud") shape, no tail | Ash @ 60% | Bone, 0.75pt | — |
| `exclaim` | Standard shape, slightly wider corner radius, text +1pt | Gilt @ 85% | Ember, 1.5pt | — |
| `whisper` | Standard shape | Ash @ 40% | none | Ash-colored text |
| `sing` | Standard shape | Gilt @ 85% | Bone, 1pt | 3 orbiting musical-note labels (`♪ ♫ ♩`) |
| `dream` | Standard shape, no tail | Dusk @ 50% | none | Bone text @ 70% opacity; per-frame sine-wave Y-offset on the label (wavy text) |
| `narrate` | No bubble at all — routed to the narration overlay | — | — | — |

Per-style stage-minimum gating is owned by
[speech-filtering's Style Stage Gates table](/SYSTEMS/speech-filtering.md#style-stage-gates-the-real-three-way-reconciliation)
— this concept documents the visual treatment only, to avoid duplicating
that authority.

# Narration Overlay (Sage+)

`NarrationOverlay`: a top-of-bar overlay, 10pt tall, 5pt font, Bone text at
80% opacity over a Void background at 60% opacity. Static text (under 80pt
wide) holds for `max(2.0, min(5.0, wordCount * 0.5 + 1.0))` seconds; longer
text scrolls left at 30pt/sec, held for `(textWidth + sceneWidth) / 30`
seconds. Dims to 40% opacity while a normal speech bubble is concurrently
active (`dimForSpeech`/`restoreFromDim`), and can be tap-dismissed with a
0.15s fade. Matches `PHASE-5.md` P5-T1-11 closely — position, font, scroll
speed, and tap-dismiss behavior all match.

# Multi-Bubble Chains (Sage+)

Up to 3 simultaneous bubbles (`maxBubbles`, keyed off `currentStage`). Long
text is split into chunks at word boundaries, capped at 30 characters per
chunk and 3 chunks total (`splitIntoChunks`); chunks appear with a 0.3s
stagger, each stacked 12pt above the previous, with the oldest dismissed
once the active count exceeds `maxBubbles`.

# Citations

[1] `Pushling/Sources/Pushling/Speech/SpeechBubbleNode.swift`
[2] `Pushling/Sources/Pushling/Speech/DropSymbolSet.swift`
[3] `Pushling/Sources/Pushling/Speech/NarrationOverlay.swift`
[4] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift`
[5] `mcp/src/tools/speak.ts` (`DROP_SYMBOLS`)
[6] `docs/archive/plan/phase-5-speech/PHASE-5.md` — P5-T1-01 through P5-T1-05, P5-T1-09, P5-T1-11, P5-T1-14
[7] `PUSHLING_VISION.md` — Speech Evolution: Text Speech (Speech Bubbles)
