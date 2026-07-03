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

# Why Voice Progression Is the Entire Feature

`docs/archive/TTS-RESEARCH.md` §1 frames the stage-gated voice quality not as
a technical limitation to apologize for, but as the feature's emotional
engine, for five reasons: (1) **narratively coherent** — of course a baby
creature babbles, of course it gets better; (2) **solves the quality
problem** — early-stage robotic speech reads as charming, not embarrassing;
(3) **creates a "wow" moment** — the first time it speaks clearly is a
genuine surprise; (4) **rewards patience** — you raised this thing, you fed
it commits, now it can talk; (5) **requires zero setup** — every engine
loads without the developer doing anything (superseded in detail by
download-on-demand, see [voice-tts-stack](/SYSTEMS/voice-tts-stack.md), but
the *zero developer action* spirit holds).

**What the creature says.** Per the same section, utterances are meant to be
short (1–5 words) and drawn from six sources: commit messages it has eaten
("refactor!" "fixed the bug!"); emotional reactions ("happy!" "hungry...");
greetings and farewells ("morning!" "bye bye!"); surprise reactions ("whoa!"
"yikes!"); language preferences ("love PHP!" "ugh, yaml..."); and taught
words via `pushling_teach("speak")`. Of these, the shipped system covers the
first five in substance — through the per-type commit reaction table
([commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md)), the babble/vocabulary
mechanisms described below, and stage-appropriate filtering
([speech-filtering](/SYSTEMS/speech-filtering.md)) — but the sixth,
teaching the creature specific words to speak via `pushling_teach`, has no
corresponding code path; `pushling_teach` only choreographs body-part
animations (see [teach-system](/SYSTEMS/teach-system.md)), not vocabulary.
Preserved as an unbuilt utterance-source idea, not implemented.

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
- **Drop chirp synthesis spec**: sine wave (~800–1400Hz fundamental) blended
  with a ~30ms pink-noise burst, plus a pitch envelope starting 20% higher
  and sliding down over ~50ms (the "chirp" quality). Timing: 80–120ms per
  chirp, 40–80ms silence between chirps, 200ms pause at punctuation, pitch
  varying ±2 semitones randomly per chirp to prevent monotony. Drop
  emotion-to-chirp mapping (distinct from the Emotion → Voice table below,
  which describes the shipped TTS-era design): Happy → higher pitch center
  (+3 semitones), faster rate; Sad → lower pitch (−2 semitones), slower
  rate, longer silence gaps; Excited → rapid chirps, wider pitch variance
  (±4 semitones); Sleepy → very slow, quiet, descending pitch patterns.
  Spore/Egg stage optionally carried an even quieter sub-bass pulse
  (20–40Hz, "felt more than heard," an `SKAudioNode` sine at 0.05 volume) —
  "silence creates anticipation."
- **Critter syllable-repetition mitigations**: the design anticipated that
  26 base syllables would get repetitive over hundreds of hours of Critter
  stage, and proposed three mitigations — dynamic ±3-semitone pitch variance
  per syllable, 2–3 micro-variation recordings per syllable with timing
  jitter, and a natural volume envelope (stressed syllables louder,
  unstressed softer). The resulting capacity argument: 26 base syllables × 3
  variations × ~8 pitch levels ≈ 624 perceptually distinct sounds.
- **Beast word-selection heuristics**: when the hybrid mixer rolled a "TTS
  word" instead of a creature syllable, it was meant to prefer short 1–2
  syllable words, the creature's own name, emotionally significant words
  ("happy," "tired," "yum"), and words from recent commit messages — "the
  creature learns from what it eats!"
- **The Hybrid Voice Pipeline architecture** (§8): a `Stage Router` selecting
  per-stage pipeline → `Emotion Modulator` (adjusts pitch/rate/volume from
  emotional state) → `Personality Shaper` (applies the personality voice
  profile) → `Audio Output`. The prescribed processing-chain order, with the
  explicit rationale that "the order of effects matters for quality":
  high-pass filter (100Hz, remove rumble) → pitch shift → formant shift →
  breathiness mix → warm EQ → micro-pitch modulation → chorus (very subtle)
  → reverb (short tail, ~0.2s) → limiter (prevent clipping) → output. The
  Beast hybrid mixer additionally crossfaded creature-syllable and
  processed-TTS segments at word boundaries over 20ms so transitions felt
  organic.
- Formant-control framework survey (§4/§9) named a fourth option beyond the
  AVAudioUnitTimePitch/AudioKit/vDSP options in
  [voice-tts-stack](/SYSTEMS/voice-tts-stack.md#aspirational-the-never-built-formant--chorus--breathiness-layer):
  **Option D**, macOS's own Vocal Transformer audio unit
  (`AUAudioUnit`, Apple manufacturer), loadable inside `AVAudioEngine` and
  providing independent pitch *and* formant control with no new external
  dependency — notable given this repo's no-new-dependency rule, since it
  would have been the one formant-independence path requiring zero
  third-party code. Never evaluated in code; preserved as an unexplored
  alternative to AudioKit.
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

# Per-Stage Voice Character Recipes (`TTS-RESEARCH` §17)

`docs/archive/TTS-RESEARCH.md` §17 specified a concrete voice recipe per
growth stage — engine, pitch/speed numbers, and how often the creature was
meant to speak at that stage. None of these numbers survive in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md), which documents only the
shipped tier-base pitch/rate values (babble 8.0st/0.5×, emerging 6.0st/
0.85×, speaking 5.5st/1.0×) — a different, code-derived set of numbers, not
this design's per-stage targets. Preserved here as the original recipe:

| Stage | Engine | Pitch | Speed | Voice / content notes | Speech frequency |
|---|---|---|---|---|---|
| Drop | espeak-ng | 85–95 (of 0–99 range, very high) | 80–120 wpm | Custom creature formant variant file; random phoneme sequences, occasional real phonemes (`"buh!"` `"nnn-dah!"`) | 1–2 babbles per minute during active states |
| Critter | Piper (`en_US-amy-low` or similar) | Post-processed +4 semitones | Slight speed increase over base | 30% babble mixed into single words (`"hi!"` `"...buh... happy!"`) | 1–3 words per 5 minutes |
| Beast | Kokoro-82M q8 | Post-processed +2–3 semitones | Emotion-driven rate | Warm preset, blended for unique character; short phrases and reactions | Contextual — reacts to events |
| Sage | Kokoro-82M q8, same base as Beast | Post-processed +1–2 semitones | Wider pitch range | Longer phrases, observations, wisdom | More frequent, more varied |
| Apex | Kokoro-82M q8, dynamic voice switching per emotion | Dynamic pitch | Dynamic | Multiple presets, emotion-selected; reverb on whispers, echo on shouts; full sentences, meta-awareness, singing | Rich and varied, context-driven |

None of these per-stage numbers, the speech-frequency pacing targets, or the
Apex dynamic-voice-switching/reverb-on-whisper/echo-on-shout behavior exist
in the shipped `AudioPlayer`/`VoicePersonalityCalculator` pipeline — the
shipped system uses one continuous personality-driven calculation per stage
(see [voice-tts-stack](/SYSTEMS/voice-tts-stack.md)'s "Voice Parameters from
Personality" table), not stage-specific recipes with their own babble/word
frequency targets. Preserved as unbuilt design intent.

# Personality → Voice Mapping (merged, `TTS-RESEARCH` §17 + `CREATURE-VOICE-DESIGN` §11)

`docs/archive/CREATURE-VOICE-DESIGN.md` §11's original table specified exact
values for two of the five axes: **Energy** low = pitch center −1 semitone,
rate 0.85×, longer pauses; Energy high = pitch center +1 semitone, rate
1.15×, shorter pauses. **Verbosity** low = fewer words per utterance, more
silence between thoughts; Verbosity high = more words, faster succession,
occasional run-on babble. The closing illustration: two Pushlings with
different personalities have distinctly different voice profiles — "a
calm-focused-disciplined Systems creature speaks with crisp, measured,
precise syllables. A hyperactive-verbose-chaotic Web Frontend creature
chatters rapidly with shimmering, enthusiastic tones."

| Personality trait | Voice effect |
|---|---|
| High Energy | Faster default rate (1.15×), wider pitch variance, shorter pauses, sharp onset |
| Low Energy | Slower, steadier, narrower pitch (0.85× rate, −1 semitone center), longer pauses, gentle onset |
| High Verbosity | More frequent speech, longer phrases, faster succession, occasional run-on babble, wide pitch variation (±2 semitones around base) |
| Low Verbosity | Rare speech, single words, more babble even at higher stages, more silence between thoughts, flat intonation |
| High Focus | Varied pitch per word, irregular rhythm, attention-shifting; precise diction, slightly clipped consonants |
| Low Focus | Consistent pitch within utterance, steady rhythm; even, measured delivery |
| High Discipline | Staccato timing, surprising emphasis, pitch jumps; crisp word boundaries, metronomic timing |
| Low Discipline | Even timing, predictable cadence, smooth pitch curves; relaxed timing, slight slur between words |
| Systems specialty | Slightly deeper, more precise articulation |
| Web Frontend specialty | Brighter, more varied pitch |

**Focus and Discipline are live axes** in the shipped 4-axis
`PersonalitySnapshot` (`energy`, `verbosity`, `focus`, `discipline` — see
[personality-emotional-state](/REFERENCE/personality-emotional-state.md)),
so their voice-effect rows above are exactly the kind of intended-but-unbuilt
intent this concept must preserve: `VoicePersonalityCalculator`
([voice-tts-stack](/SYSTEMS/voice-tts-stack.md)) reads only `energy` and
`verbosity` when computing `VoiceParameters` — `focus` and `discipline` are
not wired into any voice-parameter calculation today (they do drive the
*text*-side Discipline modifier in
[speech-filtering](/SYSTEMS/speech-filtering.md), a different, non-audio
mechanism). `docs/archive/CREATURE-VOICE-DESIGN.md` §11 describes this as one
of **five** personality axes (adding a "Specialty" axis to Energy/Verbosity/
Focus/Discipline) with a full 10-category timbre table (Systems, Web
Frontend, Web Backend, Script, JVM, Mobile, Data, Infra, Docs, Polyglot). No
`specialty` axis exists in the shipped personality model. The
Specialty-timbre table below is preserved as aspirational design intent with
no corresponding code today:

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
generated at birth, with these design ranges:

| Field | Range |
|---|---|
| `basePitchShift` | +3 to +8 semitones (stage + personality) |
| `formantShift` | +1 to +4 semitones |
| `speakingRate` | 0.7 to 1.3 (personality + emotion) |
| `breathiness` | 0.05 to 0.25 |
| `microPitchRange` | ±3 to ±15 cents |
| `reverbMix` | 0.05 to 0.25 |
| `chorusDepth` | 0.0 to 0.10 |
| `eqWarmth` | 0 to +4 dB at 200–400Hz |
| `eqBrightness` | −4 to 0 dB at 2–4kHz |
| `syllableTiming` | 60 to 150ms per syllable |
| `pauseBetweenWords` | 40 to 200ms |

The shipped `VoiceParameters` struct has 4 fields (`pitchSemitones`,
`rateMultiplier`, `intonationRange`, `warmthBoostDB`) — see
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) for the exact shipped
calculation. No `formantShift`, `breathiness`, `chorusDepth`, or `reverbMix`
per-personality field exists; the only reverb/breathiness values in the
shipped system are per-*style* constants (whisper/sing/dream), not
per-*personality* ones. Preserved as the original, larger aspirational
schema.

# Voice Selection for TTS Base (Historical, macOS-Voice Era)

`docs/archive/CREATURE-VOICE-DESIGN.md` §9 evaluated macOS system voices as
candidate TTS bases for the `AVSpeechSynthesizer`-era design:

| Voice | Quality | Character | Suitability |
|---|---|---|---|
| Samantha | High | Warm female | Good base for creature processing |
| Alex | High | Neutral male | Good base, slightly robotic |
| Zarvox | Novelty | Robotic | Too robotic — avoid |
| Fred | Novelty | Classic Mac | Nostalgic but too artificial |
| "Enhanced" download variants | Enhanced | Warm, natural | Recommended for best quality |

The durable insight, independent of which specific voice was chosen: "the
specific voice matters less after heavy processing, but starting with a
warm, natural voice produces better results than processing a robotic one."
This is entirely superseded once the sherpa-onnx/Kokoro architecture was
adopted — Kokoro ships its own 54 voice presets and has no macOS
system-voice dependency. Preserved as historical rationale only.

# Citations

[1] `docs/archive/CREATURE-VOICE-DESIGN.md` §1, §2, §4, §8, §9, §11
[2] `docs/archive/TTS-RESEARCH.md` §1, §17
[3] `Pushling/Sources/Pushling/Voice/VoicePersonality.swift`
[4] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift` (`PersonalityAxis`)
[5] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`PersonalitySnapshot`, `EmotionalSnapshot`)
