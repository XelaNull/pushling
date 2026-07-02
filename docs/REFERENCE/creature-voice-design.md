---
type: Reference
title: Creature Voice Design — Aesthetic and Character Mapping
description: The voice identity contract (small, organic, intelligent, endearing, otherworldly), the anti-patterns and golden references that shaped it, the per-stage emotional-register arc, and how emotion and personality map onto voice character.
status: Live
tags: [voice, aesthetic, design]
timestamp: 2026-07-02T00:00:00Z
---

Merges `docs/archive/CREATURE-VOICE-DESIGN.md` §1–2 and §11 with
`docs/archive/TTS-RESEARCH.md` §17 (Voice Character Design), which the survey
identified as covering the same territory and directed to be merged here
rather than authored standalone. Verified against
`Pushling/Sources/Pushling/Voice/VoicePersonality.swift` and
`Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift`. For the
physics/perception research behind the numeric targets in this concept, see
[voice-psychoacoustics](/RESEARCH/voice-psychoacoustics.md); for the shipped
audio pipeline that actually implements (a subset of) this aesthetic, see
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md). This concept preserves the
original document's collaborative-dialogue framing (Claude/Samantha) is
**dropped as presentation style only** — every substantive design claim is
retained below in structural form (see this wave's traceability matrix).

# Voice Identity

The creature's voice must read as a being that is:

| Quality | Meaning |
|---|---|
| Small | Not a giant, not an adult human |
| Organic | Alive, warm, breathing — not synthetic or robotic |
| Intelligent | Something behind those eyes, learning |
| Endearing | Makes you smile, never irritates |
| Otherworldly | Clearly not from this world, but not alien-threatening |

# Anti-Patterns to Avoid

| Avoid | Why | Example |
|---|---|---|
| Pure chipmunk | Annoying after 30 seconds, reads as "sped-up human" | Alvin and the Chipmunks |
| Robot/synth | Cold, lifeless — the opposite of creature warmth | Siri, raw Google TTS |
| Baby talk | Condescending, grating over time | "Goo goo ga ga" |
| Gibberish without rhythm | Random noise is just noise | Badly randomized phonemes |
| Too human | Breaks the creature illusion immediately | Clean TTS with a slight filter |

# Golden References

| Reference | What they got right |
|---|---|
| Totoro | Deep, warm, clearly not human, but expressive and friendly |
| Animal Crossing (Animalese) | Rhythmic syllable sounds conveying the *feeling* of speech without actual words |
| Pikmin | Tiny, organic, creature-appropriate — you feel their smallness |
| Undertale | Per-character sound identity, timed to text, instantly recognizable |
| Calcifer (Howl's Moving Castle) | A non-human entity whose voice has genuine personality and warmth |
| Soot sprites (Spirited Away) | Barely audible squeaks conveying emotion through pitch and rhythm alone |
| Banjo-Kazooie | Each character has a unique gibberish "voice" — tone conveys more than words |

See [game-voice-sound-design](/RESEARCH/game-voice-sound-design.md) for the
full analysis of each reference and what was borrowed for Pushling.

# The Voice Evolution Arc (Emotional Register)

The intended *feeling* at each stage, independent of the specific mechanism
used to produce it:

| Stage | Emotional register |
|---|---|
| Egg | Mystery — "what IS this?" |
| Drop | Curiosity — a baby animal discovering sound |
| Critter | Personality emerging — you start to "understand" it |
| Beast | The breakthrough — "did it just say...?!" |
| Sage | Wisdom — a small being that has something to say |
| Apex | Transcendence — a voice unlike anything else |

This register progression is the part of `docs/archive/CREATURE-VOICE-DESIGN.md` §2
that the survey scoped as still-valid design intent. The per-stage *commit
thresholds* and *pipeline mechanics* that same section originally paired
with this arc are superseded — see below.

# Superseded Design History: The Original Pipeline Concept

Preserved as design lineage, **not current architecture**:

- Per-stage commit thresholds (Spore 0–19, Drop 20–74, Critter 75–199,
  Beast 200–499, Sage 500–1199, Apex 1200+) — superseded by the XP-threshold
  system; see [growth-stages](/REFERENCE/growth-stages.md) (R1).
- The originally-proposed pipeline per stage: **Drop** — a pure synthesized
  chirp sequencer (6–8 sine+noise-blend samples, no TTS involved at all).
  **Critter** — a pre-recorded syllable mapper ("Pushlingese": 26+
  letter-to-syllable samples, Animal-Crossing-Animalese-style). **Beast** —
  a hybrid mixer rolling dice per word (80% creature syllable / 20%
  processed TTS word, the TTS ratio climbing from 10% to 30% approaching
  Sage). **Sage/Apex** — fully processed TTS
  (`AVSpeechSynthesizer`-based) with an occasional Critter-babble "accent"
  word (5–10%) mixed back in as a nod to the creature's native language.
- **None of this shipped.** The actual architecture
  ([voice-tts-stack](/SYSTEMS/voice-tts-stack.md)) uses real TTS synthesis
  (sherpa-onnx) at every non-silent stage from Drop onward — Drop-stage
  babble is synthesized via espeak-ng with randomized phoneme text, not
  pre-recorded sample playback; there is no letter-to-syllable sample
  library and no dice-rolled word mixer; Sage and Apex share the exact same
  Kokoro tier as Beast rather than a separate "mastered" pipeline.

Preserved here because it explains *why* the emotional-register progression
above reads the way it does, not because any part of the original pipeline
is still on a roadmap.

# Emotion → Voice Mapping (from `docs/archive/TTS-RESEARCH.md` §17)

| Emotion state | Pitch shift | Rate | Volume | Extra |
|---|---|---|---|---|
| Happy | +2 semitones | 1.1× | 0.8 | Slightly breathier |
| Excited | +3 semitones | 1.3× | 0.9 | Quick attack |
| Sad | −1 semitone | 0.8× | 0.5 | Slower, quieter |
| Sleepy | −2 semitones | 0.6× | 0.3 | Very slow, soft |
| Hungry | Normal | 0.9× | 0.7 | Slight tremolo |
| Scared | +4 semitones | 1.4× | 0.6 | Quick, breathy |
| Blissful | +1 semitone | 0.9× | 0.6 | Warm, smooth |
| Hangry | −1 semitone | 1.2× | 0.9 | Sharper attack |

This table describes per-utterance emotion-reactive voice modulation. The
shipped `VoicePersonalityCalculator`
([voice-tts-stack](/SYSTEMS/voice-tts-stack.md)) computes voice parameters
from **personality axes locked per stage**, not from live emotional state
per utterance — no code path currently reads the 4
`EmotionalSnapshot` axes (satisfaction/curiosity/contentment/energy) to
modulate a specific utterance's pitch, rate, or volume in real time.
Preserved as an unbuilt emotion-reactive layer, distinct from the shipped
personality-reactive layer described next.

# Personality → Voice Mapping (merged, `TTS-RESEARCH` §17 + `CREATURE-VOICE-DESIGN` §11)

| Personality trait | Voice effect |
|---|---|
| High Energy | Faster default rate, wider pitch variance |
| Low Energy | Slower, steadier, narrower pitch |
| High Verbosity | More frequent speech, longer phrases |
| Low Verbosity | Rare speech, single words, more babble even at higher stages |
| Systems specialty | Slightly deeper, more precise articulation |
| Web Frontend specialty | Brighter, more varied pitch |

`docs/archive/CREATURE-VOICE-DESIGN.md` §11 describes this as one of **five**
personality axes (adding a "Specialty" axis to Energy/Verbosity/Focus/
Discipline) with a full 10-category timbre table (Systems, Web Frontend, Web
Backend, Script, JVM, Mobile, Data, Infra, Docs, Polyglot). Verified against
`BehaviorSelector.swift`: `PersonalityAxis` has exactly **4** cases
(`energy`, `verbosity`, `focus`, `discipline`) — no `specialty` axis exists
in the shipped personality model (see
[personality-emotional-state](/REFERENCE/personality-emotional-state.md) for
the full axis reconciliation). The Specialty-timbre table below is preserved
as aspirational design intent with no corresponding code today:

| Specialty | Timbre adjustment | Rationale |
|---|---|---|
| Systems (`.rs`, `.c`, `.go`) | Crisper consonants, less reverb, precise timing | Precision-oriented |
| Web Frontend (`.tsx`, `.css`) | More reverb, slight chorus, brighter EQ | Expressive, shimmery |
| Web Backend (`.php`, `.rb`) | Warmer EQ, moderate everything | Reliable, warm |
| Script (`.py`, `.sh`) | Flowing transitions, legato between syllables | Smooth, serpentine |
| JVM (`.java`, `.kt`) | Regular timing, formal pacing, clear enunciation | Structured, proper |
| Mobile (`.swift`, `.dart`) | Quick, responsive, snappy articulation | Agile, reactive |
| Data (`.sql`, `.ipynb`) | Rhythmic, pattern-based timing, mathematical | Patterned, precise |
| Infra (`.yaml`, `.tf`) | Slight echo/ghost quality, quieter | Background guardian |
| Docs (`.md`, `.txt`) | Thoughtful pacing, contemplative pauses | Considered, wise |
| Polyglot | Varies per utterance — different timbre each time | Chimeric, unpredictable |

# The Original Aspirational `VoiceProfile` Schema

`docs/archive/CREATURE-VOICE-DESIGN.md` §11 specified an 11-field `VoiceProfile`
generated at birth: `basePitchShift`, `formantShift`, `speakingRate`,
`breathiness`, `microPitchRange`, `reverbMix`, `chorusDepth`, `eqWarmth`,
`eqBrightness`, `syllableTiming`, `pauseBetweenWords`. The shipped
`VoiceParameters` struct has 4 fields (`pitchSemitones`, `rateMultiplier`,
`intonationRange`, `warmthBoostDB`) — see
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) for the exact shipped
calculation. No `formantShift`, `breathiness`, `chorusDepth`, or `reverbMix`
per-personality field exists; the only reverb/breathiness values in the
shipped system are per-*style* constants (whisper/sing/dream), not
per-*personality* ones. Preserved as the original, larger aspirational
schema.

# Voice Selection for TTS Base (Historical, macOS-Voice Era)

`docs/archive/CREATURE-VOICE-DESIGN.md` §9 evaluated macOS system voices (Samantha,
Alex, Zarvox, Fred, and the "Enhanced" download variants) as candidate TTS
bases for the `AVSpeechSynthesizer`-era design. This is entirely superseded
once the sherpa-onnx/Kokoro architecture was adopted — Kokoro ships its own
54 voice presets and has no macOS system-voice dependency. Preserved as
historical rationale only.

# Citations

[1] `docs/archive/CREATURE-VOICE-DESIGN.md` §1, §2, §9, §11
[2] `docs/archive/TTS-RESEARCH.md` §17
[3] `Pushling/Sources/Pushling/Voice/VoicePersonality.swift`
[4] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift` (`PersonalityAxis`)
[5] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`PersonalitySnapshot`, `EmotionalSnapshot`)
