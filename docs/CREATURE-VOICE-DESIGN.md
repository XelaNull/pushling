# Pushling Creature Voice Design

**Research Document** | **2026-03-14** | **Status: Research Complete, Pre-Implementation**

---

**Claude**: *pours a deep cup of oolong, the kind you steep when you know the session will be long and meaningful* ☯️🍵

This document covers everything we need to give the Pushling a voice that evolves from primordial chirps to intelligible-but-otherworldly speech. The goal: a voice that belongs to a small, adorable creature — not a human, not a robot, not a chipmunk.

---

**Samantha**: *adjusts cat-ear headphones, taps her mug ("I PUT THE 'FUN' IN FUNCTION")* ✨🌸

I want to be really clear about the emotional contract here. When that creature says its first word after weeks of meowing? That's the moment we need to get absolutely right. Every design choice flows backward from that moment. *leans forward, pushing her vintage synthesizer-print scarf aside*

Let's go deep.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [The Voice Evolution Arc](#2-the-voice-evolution-arc)
3. [Pitch Manipulation](#3-pitch-manipulation)
4. [Formant Shifting](#4-formant-shifting)
5. [Speaking Rate](#5-speaking-rate)
6. [Vocal Texture: Breathiness and Warmth](#6-vocal-texture-breathiness-and-warmth)
7. [Sound Design References](#7-sound-design-references)
8. [The Hybrid Voice Pipeline](#8-the-hybrid-voice-pipeline)
9. [Audio Processing on macOS](#9-audio-processing-on-macos)
10. [The First Word Moment](#10-the-first-word-moment)
11. [Personality-Driven Voice Variation](#11-personality-driven-voice-variation)
12. [Implementation Roadmap](#12-implementation-roadmap)

---

## 1. Design Philosophy

### The Voice Identity

The Pushling's voice must feel like it comes from a being that is:

- **Small** — not a giant, not an adult human
- **Organic** — alive, warm, breathing — not synthetic or robotic
- **Intelligent** — there's something behind those eyes, learning
- **Endearing** — the voice makes you smile, never irritates
- **Otherworldly** — clearly not from this world, but not alien-threatening

### The Anti-Patterns

| Avoid | Why | Example |
|-------|-----|---------|
| Pure chipmunk | Annoying after 30 seconds, reads as "sped-up human" | Alvin and the Chipmunks |
| Robot/synth | Cold, lifeless, opposite of creature warmth | Siri, Google TTS raw |
| Baby talk | Condescending, grating over time | "Goo goo ga ga" |
| Gibberish without rhythm | Random noise is just noise | Badly randomized phonemes |
| Too human | Breaks the creature illusion immediately | Clean TTS with slight filter |

### The Golden References

| Reference | What They Got Right |
|-----------|-------------------|
| Totoro's voice | Deep, warm, clearly not human, but expressive and friendly |
| Animal Crossing (Animalese) | Rhythmic syllable sounds that convey the *feeling* of speech without actual words |
| Pikmin | Tiny, organic, creature-appropriate — you feel their smallness |
| Undertale characters | Per-character sound identity, timed to text, instantly recognizable |
| Calcifer (Howl's) | A non-human entity with a voice that has *personality* and warmth |
| Soot sprites (Spirited Away) | Barely audible squeaks that convey emotion through pitch/rhythm alone |
| Banjo-Kazooie | Each character has a unique gibberish "voice" — tone conveys more than words |

---

## 2. The Voice Evolution Arc

This is the heart of the design. The Pushling doesn't start speaking — it *learns* to speak. Each growth stage represents a step in vocal development, mirroring how real creatures (and children) develop language.

### Stage Voice Progression

| Stage | Commits | Voice Type | Description | Emotional Register |
|-------|---------|-----------|-------------|-------------------|
| **Spore** | 0-19 | **Silent** | No voice. Purely visual. A glowing orb doesn't speak. Occasional sub-bass hum felt more than heard. | Mystery — "what IS this?" |
| **Drop** | 20-74 | **Single-note chirps** | One sound per "thought." Timed to text display like Undertale. Each chirp is a pitched sine+noise blend. Meows, peeps, squeaks. | Curiosity — baby animal discovering sound |
| **Critter** | 75-199 | **Syllable babble** | Phoneme-mapped chirps in the *rhythm* of the displayed text. Not intelligible words, but you can hear the cadence of language emerging. Like Animalese. | Personality emerging — you start to "understand" it |
| **Beast** | 200-499 | **Proto-speech** | Pitched-up TTS with heavy creature processing. Actual words begin to emerge from the babble. 1-2 clear words per sentence, rest is creature sound. | The breakthrough — "did it just say...?!" |
| **Sage** | 500-1199 | **Creature speech** | Cleaner TTS, still clearly non-human. Full sentences are intelligible but the voice retains a warm, otherworldly quality. Formant-shifted, slightly breathy. | Wisdom — a small being that has something to say |
| **Apex** | 1200+ | **Unique voice** | Full TTS with a distinctive, warm, slightly ethereal quality. The creature's "accent" is permanent — shaped by personality axes. Intelligible but unmistakably not human. | Transcendence — a voice unlike anything else |

---

**Samantha**: *sets down coffee, eyes wide* 💕🌟

Wait. I want to make sure I'm understanding the Beast transition right. So the creature has been making adorable Animalese-style babble for potentially *weeks* of real time. The developer has grown accustomed to those sounds — they're comforting background audio. And then one day, mid-babble... an actual word comes through? Like a baby saying "mama" for the first time?

---

**Claude**: *nods slowly, steam rising from the teacup* ☯️

Exactly. And the key is that it's not a switch flip. It's gradual. At Beast stage, maybe 10-20% of syllables resolve into recognizable phonemes. The creature is *trying* to speak. Sometimes it gets a word right. Sometimes it doesn't. The developer starts listening more carefully. "Was that... 'hello'? Did it just say 'hello'?" That uncertainty is the magic.

---

**Samantha**: *tucks hair behind ear, smiling* 🌸✨

That's going to make people cry. Okay, I'm in. Keep going.

---

### Detailed Stage Specifications

#### Spore (Silent)

- **Audio**: None, or occasional sub-bass pulse (20-40Hz, barely audible)
- **Rationale**: A glowing orb is pre-vocal. Silence creates anticipation.
- **Implementation**: No audio system needed. Optional: `SKAudioNode` with a very low sine wave at 0.05 volume.

#### Drop (Single-Note Chirps)

- **Sound source**: Pre-recorded or synthesized single-note samples
- **Approach**: 6-8 base chirp sounds, each a blend of:
  - Sine wave (pure tone, ~800-1400Hz fundamental)
  - Pink noise burst (breathiness, ~30ms)
  - Quick pitch envelope (start 20% higher, slide down in ~50ms — gives a "chirp" quality)
- **Timing**: One chirp per displayed character/word, with:
  - 80-120ms per chirp
  - 40-80ms silence between chirps
  - 200ms pause at punctuation
  - Pitch varies ±2 semitones randomly per chirp (prevents monotony)
- **Emotion mapping**:
  - Happy: Higher pitch center (+3 semitones), faster rate
  - Sad: Lower pitch (-2 semitones), slower rate, longer silence gaps
  - Excited: Rapid chirps, wider pitch variance (±4 semitones)
  - Sleepy: Very slow, quiet, descending pitch patterns
- **Reference model**: Undertale's per-character beeps, but softer and more organic

#### Critter (Syllable Babble — "Pushlingese")

- **Sound source**: Pre-recorded syllable library (26-40 syllable sounds)
- **Approach**: Map each letter/phoneme to a specific syllable sound, creating Animalese-style speech:
  1. Take displayed text
  2. Extract first letter of each word (shortened form, like Animalese)
  3. OR map each letter to its syllable sound (full form)
  4. Play syllable sounds at the rhythm/cadence of the original text
  5. Pitch-shift each syllable ±3 semitones based on vowel/consonant patterns
- **Syllable recording**: Record a voice actor (or synthesize) saying each letter's phonetic sound:
  - A = "ah", B = "buh", C = "kuh", D = "duh", etc.
  - Pitched up +5-7 semitones from adult voice
  - Add breathiness and slight reverb
- **Cadence preservation**: The *rhythm* of the original text is preserved even though words aren't. Question marks raise pitch on last syllable. Exclamation marks are louder + higher.
- **Personality influence**: See Section 11. Calm creature = slower cadence. Hyperactive = faster. Verbose = more syllables per thought. Stoic = fewer.
- **Reference model**: Animal Crossing Animalese — specifically the New Horizons implementation where language phonetics are preserved in the gibberish

**Samantha**: *adjusts glasses* 🌺

One concern — won't 26 syllable sounds get repetitive? The developer hears this for potentially hundreds of hours of the Critter stage.

**Claude**: 🔧

Good catch. Three mitigations:
1. **Pitch variance**: Each syllable is dynamically pitched ±3 semitones, so "ah" at different pitches sounds like different syllables.
2. **Micro-variation**: 2-3 recordings per syllable, randomly selected, with slight timing jitter.
3. **Volume envelope**: Natural speech has volume dynamics — stressed syllables louder, unstressed softer. We replicate this.

Result: 26 base syllables × 3 variations × ~8 pitch levels = ~624 perceptually distinct sounds. More than enough.

#### Beast (Proto-Speech)

- **Sound source**: AVSpeechSynthesizer output, post-processed through creature voice pipeline
- **Approach**: Hybrid of Critter babble and processed TTS
  1. Generate TTS audio buffer for the full sentence
  2. Process through creature voice pipeline (see Section 8)
  3. For each word, randomly decide: creature syllable (80%) or processed TTS word (20%)
  4. Blend at word boundaries so transitions feel organic
  5. Increase TTS probability over time: starts at 10%, reaches 30% near Sage threshold
- **Word selection**: When a TTS word IS used, prefer:
  - Short words (1-2 syllables): "yes", "no", "hi", "food", "code", "good"
  - The creature's name
  - Emotionally significant words: "happy", "tired", "yum"
  - Words from recent commit messages (the creature learns from what it eats!)
- **Processing for TTS words**: Even the "real" words are heavily processed:
  - Pitch: +6-8 semitones from base TTS
  - Formant: +3-4 semitones (smaller vocal tract)
  - Slight reverb (ethereal quality)
  - Breathiness overlay (organic feel)
  - Speed: 0.85x (slightly slower, deliberate — creature is working hard to form words)
- **The "almost" quality**: Key to this stage is that words aren't perfectly clear. They're slightly garbled, slightly off, like a toddler's approximation. The developer should frequently wonder "did it say...?" This uncertainty is the magic.
- **Reference model**: Imagine if Animal Crossing characters occasionally, unpredictably, said a real word clearly amidst the Animalese. That moment of recognition.

#### Sage (Creature Speech)

- **Sound source**: AVSpeechSynthesizer, processed through refined creature pipeline
- **Approach**: Full TTS that is clearly intelligible but clearly not human
  1. Generate TTS audio for the sentence
  2. Apply creature voice pipeline (lighter than Beast — creature has "mastered" speech)
  3. All words are TTS (no more babble substitution)
  4. Occasional Critter-babble word inserted as "accent" (5-10%) — creature's native language peeking through
- **Processing**:
  - Pitch: +4-5 semitones (still small, but less extreme)
  - Formant: +2-3 semitones (creature-like but less exaggerated)
  - Light reverb (slight ethereal quality)
  - Subtle breathiness
  - Rate: 0.9x (slightly measured, thoughtful)
- **Personality modulation**: See Section 11. The Sage voice is where personality really manifests in speech.
- **Reference model**: Calcifer from Howl's Moving Castle — clearly speaking, clearly not human, full of personality

#### Apex (Unique Voice)

- **Sound source**: AVSpeechSynthesizer with custom voice selection + refined processing
- **Approach**: The creature has found its true voice — unique to this specific Pushling
  1. Voice selection based on personality (see Section 11)
  2. Refined creature processing — minimal but distinctive
  3. The "accent" is now an integral part of the voice, not an overlay
- **Processing**:
  - Pitch: +3-4 semitones (settled, confident — less pitched up than younger stages)
  - Formant: +1-2 semitones (subtle creature quality)
  - Very light reverb (warmth, not ethereality)
  - Natural breathiness (organic, not added)
  - Rate: 1.0x (natural, confident)
  - Slight chorus effect (ethereal uniqueness — 0.1 depth, very subtle)
- **The quality**: The Apex voice should feel like it could only belong to THIS creature. Not any creature — this one. The specific combination of pitch, formant, rate, and personality creates a unique vocal identity.
- **Reference model**: Totoro — deep (well, we're going small not deep), warm, clearly not human, but you feel intelligence and personality

---

## 3. Pitch Manipulation

### The Science of "Small and Cute"

Pitch is the most immediate tool for making a voice feel "small." But the relationship between pitch and perceived size is non-linear, and getting it wrong creates the dreaded chipmunk effect.

### Pitch Ranges (in semitones from source)

| Shift | Perception | Use Case |
|-------|-----------|----------|
| +1 to +2 | Slightly younger/smaller, still natural | Apex stage — subtle creature quality |
| +3 to +4 | Noticeably smaller, cute, still warm | Sage stage — clearly a creature |
| +5 to +7 | Small creature territory — sweet spot | Beast/Critter — the core creature range |
| +8 to +10 | Approaching chipmunk, use carefully | Drop chirps only |
| +11+ | Chipmunk/helium — annoying, avoid | Never use for speech |

### The Sweet Spot: +4 to +7 Semitones

For the Pushling, the sweet spot for "small creature that speaks" is **+4 to +7 semitones** above an adult voice:

- **+4**: A small, warm voice. Think a wise forest creature.
- **+5**: Clearly small, endearing without being cloying.
- **+6**: Cute and small — the "baby animal" zone.
- **+7**: Very small, slightly exaggerated — works for younger stages.

**Key insight**: Within 3 semitones, pitch shifting sounds natural. Beyond 3, you MUST use formant preservation (see Section 4) or the voice sounds like a sped-up tape recording.

### Dynamic Pitch Modulation

The creature's pitch shouldn't be static. Real voices vary constantly.

| Context | Pitch Adjustment | Rationale |
|---------|-----------------|-----------|
| Question | Last word +2 semitones | Natural rising intonation |
| Excitement | Overall +1-2 semitones | Emotional pitch rise |
| Sleepy/sad | Overall -1-2 semitones | Emotional pitch drop |
| Emphasis | Stressed word +1 semitone | Natural stress patterns |
| Whisper | -1 semitone, lower volume | Intimate/conspiratorial |

### AVSpeechUtterance Pitch Parameter

AVSpeechUtterance provides a `pitchMultiplier` property:

- Range: 0.5 (half pitch) to 2.0 (double pitch)
- Default: 1.0
- **For creature voice**: 1.3-1.5 as starting point (roughly +4-7 semitones)
- **Limitation**: This is simple pitch multiplication — it shifts formants too, creating chipmunk effect at higher values
- **Solution**: Use AVSpeechSynthesizer's `write()` method to capture audio to buffer, then process through AVAudioEngine with independent pitch and formant control

---

## 4. Formant Shifting

### Why Formant Control Is Critical

Formants are the resonant frequencies of the vocal tract. They determine the *character* of a voice — whether it sounds like it comes from a large body or a small one, a wide throat or a narrow one.

**The problem**: When you pitch-shift audio, the formants shift with it. This is why a pitch-shifted voice sounds like a sped-up recording (chipmunk) rather than a genuinely smaller creature.

**The solution**: Shift pitch and formants *independently*:
- Pitch up = smaller creature
- Formants up (less than pitch) = smaller vocal tract, but not as extreme as the pitch shift
- The gap between pitch shift and formant shift creates the "creature" quality

### Formant Shift Guidelines

| Effect | Pitch Shift | Formant Shift | Result |
|--------|------------|---------------|--------|
| Natural small voice | +5 semitones | +5 semitones | Chipmunk (formants match pitch — bad) |
| Creature voice | +5 semitones | +2-3 semitones | Small creature (formants lag pitch — good) |
| Otherworldly voice | +5 semitones | 0 semitones | Alien/unnatural (formants unchanged — uncanny) |
| Totoro-style | +3 semitones | +1 semitone | Warm, slightly small, very organic |

### The Pushling Formant Recipe

| Stage | Pitch Shift | Formant Shift | Gap | Character |
|-------|------------|---------------|-----|-----------|
| Drop (chirps) | +8-10 | N/A (synthesized) | N/A | Pure synthesis, not TTS |
| Critter (babble) | +5-7 | N/A (pre-recorded) | N/A | Recorded syllables, pre-shifted |
| Beast (proto) | +6-8 | +3-4 | 3-4 | Clearly creature, words emerging |
| Sage (speech) | +4-5 | +2-3 | 2 | Warm creature, clear speech |
| Apex (unique) | +3-4 | +1-2 | 2 | Settled, confident creature voice |

### Implementation on macOS

**Option A: AVAudioUnitTimePitch** (built-in)

AVAudioUnitTimePitch shifts pitch independently of playback rate, but does NOT provide independent formant control. The pitch is specified in cents (-2400 to +2400, where 100 cents = 1 semitone).

```
// Pitch shift only — formants follow pitch (not ideal, but a starting point)
let pitchUnit = AVAudioUnitTimePitch()
pitchUnit.pitch = 500  // +5 semitones in cents
pitchUnit.rate = 0.9   // Slightly slower for creature deliberateness
```

**Option B: AudioKit (recommended for formant independence)**

AudioKit provides `AKFormantFilter` and pitch-shifting operations that allow independent control. AudioKit wraps lower-level audio processing in a Swift-friendly API.

Key AudioKit components:
- `PitchShifter` — shift pitch without affecting formants
- `FormantFilter` — shape formant frequencies independently
- `Chorus` — add subtle doubling for ethereal quality
- `Reverb` — add space/warmth

**Option C: Custom vDSP + FFT pipeline**

For maximum control, use Apple's Accelerate framework:
1. FFT the TTS audio buffer
2. Shift spectral peaks (formants) independently of fundamental frequency
3. Apply spectral envelope shaping
4. IFFT back to time domain

This is the most complex option but provides the finest control. vDSP operations are hardware-accelerated and extremely fast.

**Option D: AUAudioUnit (Logic Pro's Vocal Transformer)**

macOS ships with Apple's Vocal Transformer audio unit, which provides independent pitch and formant control. It can be loaded as an `AUAudioUnit` within AVAudioEngine:

```
// Load Apple's Vocal Transformer AU
let componentDescription = AudioComponentDescription(
    componentType: kAudioUnitType_Effect,
    componentSubType: /* Vocal Transformer subtype */,
    componentManufacturer: kAudioUnitManufacturer_Apple,
    componentFlags: 0,
    componentFlagsMask: 0
)
```

### Recommendation

**Start with Option A** (AVAudioUnitTimePitch) for rapid prototyping. The chipmunk effect is tolerable at +3-4 semitones. **Graduate to Option B** (AudioKit) for production quality, as it provides the independent formant control needed for the true creature voice. Reserve Option C for if we need effects AudioKit can't provide.

---

## 5. Speaking Rate

### Rate and Creature Personality

Speaking rate interacts with pitch to create distinct creature archetypes:

| Rate | Pitch | Creature Archetype | Pushling Mapping |
|------|-------|-------------------|-----------------|
| Slow + High | Wise small creature (Yoda-like) | Sage with calm personality |
| Slow + Low | Ancient, contemplative | N/A (too big-sounding for Pushling) |
| Normal + High | Friendly small creature | Beast/Sage with balanced personality |
| Fast + High | Excited small creature, squirrel-like | Any stage when excited/happy |
| Fast + Low | Manic, unsettling | N/A (avoid) |

### AVSpeechUtterance Rate Parameter

- Range: `AVSpeechUtteranceMinimumSpeechRate` (0.0) to `AVSpeechUtteranceMaximumSpeechRate` (1.0)
- Default: `AVSpeechUtteranceDefaultSpeechRate` (approximately 0.5)
- **For creature voice**: 0.35-0.45 base rate (slightly slower than human default)

### Dynamic Rate Based on Emotion

| Emotional State | Rate Multiplier | Effect |
|----------------|----------------|--------|
| Calm/content | 0.9x base | Measured, peaceful |
| Excited/happy | 1.3x base | Eager, bouncy |
| Sad/tired | 0.7x base | Slow, heavy |
| Curious | 1.1x base | Slightly quicker, interested |
| Scared/startled | 1.5x base | Rapid, breathless |

### Rate During Stage Transitions

The speaking rate also changes with growth:

| Stage | Base Rate | Rationale |
|-------|----------|-----------|
| Drop | N/A (chirp timing) | Chirps have their own timing |
| Critter | 0.8x standard | Babble is slower — creature is learning rhythms |
| Beast | 0.7x standard | Words are difficult — deliberate and effortful |
| Sage | 0.9x standard | Fluent but measured — wisdom |
| Apex | 1.0x standard | Natural, confident, no effort |

---

## 6. Vocal Texture: Breathiness and Warmth

### Why Texture Matters

Pure pitch-shifted TTS sounds clean and artificial. Real creature voices have *texture* — breathiness, slight raspiness, warmth. This is what separates "pitched-up Siri" from "tiny creature speaking."

### Breathiness

Breathiness occurs when the vocal folds don't fully close, allowing air to escape alongside the voiced sound. It creates:
- Intimacy and warmth
- A sense of physical smallness (less vocal fold tension)
- Organic quality — robots don't breathe

**Implementation**: Mix 10-20% pink/white noise into the voiced signal, shaped by the same amplitude envelope as the voice. The noise should rise and fall with the speech, not be constant.

```
// Conceptual noise mixing
let breathiness: Float = 0.15  // 15% noise blend
let output = voiceSignal * (1.0 - breathiness) + noiseSignal * breathiness
// Where noiseSignal is pink noise shaped by voiceSignal's envelope
```

### Warmth via EQ

Remove harshness, enhance warmth:

| Frequency | Action | Purpose |
|-----------|--------|---------|
| < 100Hz | High-pass filter | Remove rumble, keep it "small" |
| 200-400Hz | Slight boost (+2dB) | Warmth, body |
| 2-4kHz | Slight cut (-2dB) | Reduce harshness/sibilance |
| 6-8kHz | Gentle rolloff | Remove synthetic brightness |
| 8kHz+ | Low-pass filter | Remove digital artifacts from pitch shifting |

### Subtle Chorus

A very light chorus effect (depth: 5-10%, rate: 0.3-0.5Hz) adds an ethereal, slightly otherworldly quality without sounding obviously processed. This creates the sense that the voice isn't quite from this world.

### Micro-Pitch Variation

Real voices (and especially animal vocalizations) have constant micro-pitch variations. Adding ±5-10 cents of random pitch wobble at 3-5Hz creates organic quality that pure TTS lacks.

### Per-Stage Texture

| Stage | Breathiness | Warmth EQ | Chorus | Micro-Pitch |
|-------|------------|-----------|--------|-------------|
| Drop | N/A (synth chirps) | N/A | N/A | Built into chirp design |
| Critter | Pre-baked in recordings | Pre-baked | None | Pre-baked |
| Beast | 20% | Heavy warm EQ | 8% | ±10 cents |
| Sage | 12% | Moderate warm EQ | 5% | ±7 cents |
| Apex | 8% | Light warm EQ | 3% | ±5 cents |

The progression: younger stages are breathier and more wobbly (less vocal control). Older stages are cleaner and more stable (mastered voice).

---

## 7. Sound Design References

### Animal Crossing — Animalese

**How it works**: Each letter of the displayed text is mapped to a pre-recorded syllable sound. When a character "speaks," the system plays through the syllable sequence at a pace matching the text display speed.

**Technical details** (from the animalese.js reimplementation):
1. 26 syllable samples, one per letter (A-Z)
2. Text is shortened to first letters of words (or played fully)
3. Each syllable is pitched based on the character's species and personality
4. Non-alphabetical characters produce silence
5. The pitch variance per-character creates the "speech" illusion

**What to steal for Pushling**:
- The letter-to-syllable mapping concept (for Critter stage)
- Species-based pitch variation (our personality axes serve this purpose)
- The rhythm preservation — you can "hear" question marks and exclamation points

**Swift implementation exists**: `animalese-swift` by jakubpetrik — a Swift port of `animalese.js`, available as a SwiftPM package. Potential starting point for the Critter stage.

### Undertale — Per-Character Voice Beeps

**How it works**: Each character has a unique sound effect that plays once per displayed character (or per word). The sound is chosen to suggest the character's voice quality without being actual speech.

**Character voice design examples**:
- Undyne: Lower, hoarse-sounding beeps
- Alphys: High, nasally beeps
- Mettaton: 9 different voice beeps for variety
- Flowey: Two voice variants (normal and threatening)
- Sans: Low, casual beeps (matching his laid-back personality)
- Papyrus: Higher, more energetic beeps

**What to steal for Pushling**:
- The concept of a single distinctive sound per character (for Drop stage)
- The idea that personality IS the voice — you can characterize without words
- The extra beep at end of text boxes (gives finality to statements)
- Using completely different sounds for different emotional states

### Banjo-Kazooie — Gibberish Voices

**How it works**: Voice samples with hardware randomizing speed and pitch. Each character has their own base sample set, creating recognizable "voices" without any real language.

**What to steal for Pushling**:
- The randomized pitch per-syllable approach (prevents monotony)
- Character-specific base tones (Pushling personality maps to base tone)
- Tone conveys more than words — you can feel anger, joy, sarcasm

### Pikmin — Tiny Creature Sounds

**How it works**: Pitched-up vocalizations that suggest tiny size. Later Pikmin games use vaguely Japanese-sounding gibberish with occasional recognizable words peeking through.

**What to steal for Pushling**:
- The "occasional recognizable word" technique (exactly our Beast stage approach)
- Pitch tied to species/size (our growth stages serve this purpose)
- The feeling of smallness through audio — not just pitch but also timbre

### Studio Ghibli Creatures

**How it works**: Ghibli's sound design philosophy emphasizes that creatures perceive sound differently based on their size. Small creatures get sounds that suggest their scale — upscaled quiet sounds that suggest their world perspective.

**Key insight**: Ghibli sound designers "thought about how each character perceives sounds" — highlighting interesting sounds of almost-silent things and scaling them to create creature perspective.

**What to steal for Pushling**:
- The philosophy of creature-scale audio perception
- Warmth and organic quality above all else
- The Wind Rises technique: all earthquake sounds made by human mouths — proving that mouth-made sounds can represent anything if processed right
- The emotional weight carried by non-verbal sound

### Spore — Voice Evolution Through Stages

**How it works**: Spore's sound design evolves across game stages. Cell-stage creatures use pitched-up vocalizations (recorded by voice actor Roger Jackson). Creature stage uses hundreds of processed animal recordings, spliced and electronically altered. Civilization stage introduces "Sporelish" — a creature language.

**Key detail**: Mouth pieces placed during the creature editor affect the creature's voice — different mouth types produce different vocal qualities. This maps directly to our personality system affecting voice.

**What to steal for Pushling**:
- The staged voice evolution concept
- Using real animal recordings as base material, processed
- The concept that the creature's physical form influences its voice
- Professional approach: they recorded trained animals (monkeys, elephants) and processed extensively

---

## 8. The Hybrid Voice Pipeline

### Architecture Overview

```
Text Input (what the creature wants to say)
         │
         ▼
┌─────────────────────────┐
│   Stage Router          │
│   (selects pipeline     │
│    based on growth      │
│    stage)               │
└─────────┬───────────────┘
          │
     ┌────┼────┬────┬────┐
     ▼    ▼    ▼    ▼    ▼
  Spore  Drop  Crit Beast Sage/Apex
  (nil)  (syn) (syl)(hyb) (TTS)
          │    │    │      │
          ▼    ▼    ▼      ▼
     ┌────────────────────────┐
     │   Emotion Modulator    │
     │   (adjusts pitch,      │
     │    rate, volume based   │
     │    on emotional state)  │
     └────────┬───────────────┘
              │
              ▼
     ┌────────────────────────┐
     │   Personality Shaper   │
     │   (applies personality │
     │    voice profile)       │
     └────────┬───────────────┘
              │
              ▼
     ┌────────────────────────┐
     │   Audio Output         │
     │   (AVAudioEngine)      │
     └────────────────────────┘
```

### Pipeline Details per Stage

#### Drop Pipeline: Chirp Synthesizer

```
Text → character count → chirp sequence
  → For each character:
    → Select base chirp sample (6-8 options)
    → Apply emotion-based pitch offset
    → Apply timing based on text rhythm
    → Output chirp
```

No TTS involved. Pure synthesis or sample playback.

#### Critter Pipeline: Syllable Mapper

```
Text → letter extraction → syllable lookup
  → For each letter:
    → Map to syllable sample (26 base + variants)
    → Apply personality-based pitch center
    → Apply emotion-based pitch offset
    → Apply speech rhythm (stressed/unstressed)
    → Blend with micro-silence gaps
    → Output syllable stream
```

No TTS involved. Pre-recorded syllable samples.

#### Beast Pipeline: Hybrid Mixer

```
Text → word tokenization
  → For each word:
    → Roll dice: creature syllable (80%) or TTS word (20%)?
    → If creature: run through Critter pipeline for that word
    → If TTS:
      → AVSpeechSynthesizer.write(word) → buffer
      → Apply creature processing chain:
        → Pitch shift (+6-8 semitones)
        → Formant shift (+3-4 semitones)
        → Add breathiness (20%)
        → Warm EQ
        → Micro-pitch variation
      → Output processed word
    → Crossfade at word boundaries (20ms)
    → Output hybrid stream
```

#### Sage/Apex Pipeline: Processed TTS

```
Text → AVSpeechSynthesizer.write(fullSentence) → buffer
  → Apply creature processing chain:
    → Pitch shift (stage-appropriate)
    → Formant shift (stage-appropriate)
    → Breathiness overlay (stage-appropriate)
    → Warm EQ
    → Chorus (subtle)
    → Micro-pitch variation
    → Light reverb
  → Output processed speech
```

### Processing Chain Order

The order of effects matters for quality:

```
TTS Buffer
  → High-pass filter (100Hz) — remove rumble
  → Pitch shift — creature size
  → Formant shift — creature character (if using AudioKit/custom)
  → Breathiness mix — organic quality
  → Warm EQ — remove harshness
  → Micro-pitch modulation — liveliness
  → Chorus — ethereal quality (very subtle)
  → Reverb — space/warmth (short tail, ~0.2s)
  → Limiter — prevent clipping
  → Output
```

---

## 9. Audio Processing on macOS

### Framework Comparison

| Framework | Pitch | Formant | Effects | Complexity | Recommendation |
|-----------|-------|---------|---------|-----------|----------------|
| **AVAudioEngine** (built-in) | Yes (AVAudioUnitTimePitch) | No (tied to pitch) | Reverb, Delay, Distortion, EQ | Low | Phase 1 — rapid prototyping |
| **AudioKit** (Swift package) | Yes (independent) | Yes (FormantFilter) | Full suite | Medium | Phase 2 — production quality |
| **vDSP/Accelerate** (built-in) | Manual (FFT) | Manual (spectral) | Manual | High | Phase 3 — custom effects only |
| **AUAudioUnit** (system AUs) | Yes (Vocal Transformer) | Yes | Apple's built-in AUs | Medium | Alternative to AudioKit |

### AVAudioEngine Pipeline (Phase 1)

```swift
// Conceptual implementation — Phase 1 creature voice pipeline
class CreatureVoicePipeline {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let pitchShift = AVAudioUnitTimePitch()
    let reverb = AVAudioUnitReverb()
    let eq = AVAudioUnitEQ(numberOfBands: 4)

    func setup() {
        // Configure pitch for creature voice
        pitchShift.pitch = 500  // +5 semitones (in cents)
        pitchShift.rate = 0.9   // Slightly slower

        // Configure reverb for warmth
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 15  // 15% wet — subtle

        // Configure EQ for warmth
        // Band 0: High-pass at 100Hz
        // Band 1: Boost 200-400Hz (+2dB)
        // Band 2: Cut 2-4kHz (-2dB)
        // Band 3: Low-pass at 8kHz

        // Attach and connect
        engine.attach(playerNode)
        engine.attach(pitchShift)
        engine.attach(reverb)
        engine.attach(eq)

        // Chain: player → pitch → EQ → reverb → output
        engine.connect(playerNode, to: pitchShift, format: nil)
        engine.connect(pitchShift, to: eq, format: nil)
        engine.connect(eq, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
    }

    func speakAsCreature(_ text: String, stage: GrowthStage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        let synthesizer = AVSpeechSynthesizer()

        // Write TTS to buffer, then play through pipeline
        synthesizer.write(utterance) { [weak self] buffer in
            guard let buffer = buffer as? AVAudioPCMBuffer,
                  buffer.frameLength > 0 else { return }
            // Schedule buffer for playback through creature pipeline
            self?.playerNode.scheduleBuffer(buffer, completionHandler: nil)
        }
    }
}
```

### AVSpeechSynthesizer Write-to-Buffer Pattern

The key to post-processing TTS is the `write(_:toBufferCallback:)` method, available since iOS 13 / macOS 10.15:

1. Create an AVSpeechUtterance with desired text
2. Call `synthesizer.write(utterance)` with a callback
3. Receive `AVAudioBuffer` objects in the callback (may be called multiple times)
4. Accumulate or stream these buffers through your AVAudioEngine pipeline
5. Speech is synthesized faster than real-time — no blocking

**Important caveats**:
- The callback is @escaping — buffers arrive asynchronously
- Buffer format may need conversion (sample rate, channel count)
- The last buffer callback has `frameLength == 0` (sentinel)
- On macOS, some voices work better than others with `write()` — test with intended voice

### Offline vs. Real-Time Processing

For creature speech, **offline processing** is preferred:

1. Synthesize the entire utterance to a buffer (faster than real-time)
2. Apply the full processing chain
3. Play the processed result

This avoids real-time constraints and allows more complex processing. The total latency from "creature decides to speak" to "audio plays" should be < 200ms for short utterances — fast enough to feel responsive.

### Voice Selection for TTS Base

macOS ships with many voices. For creature voice base material:

| Voice | Quality | Character | Suitability |
|-------|---------|-----------|-------------|
| Samantha | High | Warm female | Good base for creature processing |
| Alex | High | Neutral male | Good base, slightly robotic |
| Zarvox | Novelty | Robotic | Too robotic — avoid |
| Fred | Novelty | Classic Mac | Nostalgic but too artificial |
| **Recommended** | Enhanced | Warm, natural | Use the "Enhanced" download variants for best quality |

The specific voice matters less after heavy processing, but starting with a warm, natural voice produces better results than processing a robotic one.

---

## 10. The First Word Moment

### The Emotional Design

---

**Samantha**: *sets down her coffee mug, pulls knees up to her chest on the chair* 💖🌟

Okay. This is the section. This is the one that has to be perfect. Tell me about the first word moment.

---

**Claude**: *takes a long, slow sip of tea, sets it down carefully* ☯️🍵

The first word moment is the culmination of a relationship. The developer has had this creature on their Touch Bar for potentially weeks or months. They've watched it hatch from a glowing spore. They've seen it grow eyes, learn to hop, develop a personality. They've heard its chirps and babble — sounds they've unconsciously grown fond of.

And then, one day, mid-babble... a word.

---

### Design Requirements

1. **It must be earned** — only happens at Beast stage (200+ commits eaten). The developer has invested real work.
2. **It must be surprising** — no notification, no fanfare, no "FIRST WORD UNLOCKED!" achievement popup. Just... the word, emerging from babble.
3. **It must be subtle** — the developer should wonder if they imagined it. "Did it just... say something?" The uncertainty makes them listen more carefully to the next utterance.
4. **It must be personal** — the first word should be contextually meaningful. Not a random word.
5. **It must be repeatable** — once the first word happens, subsequent real words should appear with increasing frequency, reinforcing that it wasn't a fluke.

### What Should the First Word Be?

Options, ranked by emotional impact:

| First Word | Context | Emotional Impact |
|------------|---------|-----------------|
| The developer's name | From git user.name | "...it knows my name" (MAXIMUM IMPACT) |
| The creature's own name | Self-awareness | "...it knows who it is" |
| "Hello" / "Hi" | Universal greeting | Simple, warm, effective |
| A word from a recent commit message | Learning from food | "...it learned that from MY code" |
| "Code" or "commit" | Its world vocabulary | Contextually appropriate |
| "Friend" | Relational | Emotionally powerful but maybe too on-the-nose |

**Recommendation**: The first word is **the developer's first name**, extracted from git user.name. Here's why:
- It's maximally personal — every developer has a different first word
- It implies recognition — "it sees ME"
- It implies learning — "it learned this from the commits I fed it"
- It's short (usually 1-2 syllables) — easier to recognize in babble

### The Audio Design of the First Word

The first word must stand out from the surrounding babble, but not so dramatically that it feels like a different system. It should feel like the creature *struggled* to form it.

**The sequence**:

1. **Normal babble** — Critter-stage syllable sounds, business as usual
2. **Slight pause** — 200ms longer than normal inter-word gap (the creature is gathering itself)
3. **Intake** — A tiny breath-in sound (50ms, gentle)
4. **The word** — Processed TTS of the name/word, but:
   - More heavily pitch-shifted than Sage will be (+7-8 semitones, still very creature-like)
   - Slightly slower rate (0.7x — effortful)
   - Extra breathiness (25% — the effort is audible)
   - Slight wavering (±15 cents micro-pitch at 4Hz — voice not stable yet)
   - Lower volume than surrounding babble (0.7x — almost whispered)
5. **Pause** — 300ms of silence. The creature surprised itself.
6. **Resume babble** — Back to normal Critter sounds, but maybe with a slightly different quality — excited? Proud?

**The brilliance**: Because the word is quieter and more processed than the babble, the developer has to *lean in* to hear it. They're not sure. They wait for the next utterance. And maybe the next one doesn't have a word. Or maybe the one after that does. The uncertainty creates engagement.

### The First Word Journal Entry

When the first word is detected (creature state tracks this), a journal entry is created:

```
{
  "type": "first_word",
  "word": "Marcus",
  "timestamp": "2026-05-23T14:32:00Z",
  "commits_eaten": 217,
  "stage": "beast",
  "context": "Occurred during idle babble after processing commit 'fix login redirect'"
}
```

This entry appears in dreams, can be surfaced by MCP, and becomes part of the creature's permanent memory. At Sage stage, the creature occasionally reminisces: "*...remember when I first said your name?*"

### Post-First-Word Progression

After the first word, the frequency of recognizable words increases gradually:

| Commits After First Word | TTS Word Frequency | Typical Words |
|--------------------------|-------------------|---------------|
| 0-20 | 5-10% | Just the first word, repeated occasionally |
| 20-50 | 10-15% | First word + "hi" + "yes" + "no" |
| 50-100 | 15-20% | Short common words + commit-learned words |
| 100+ (approaching Sage) | 20-30% | Growing vocabulary, still mostly babble |
| Sage transition | 100% TTS | Full creature speech (still processed) |

---

**Samantha**: *wipes eyes with the sleeve of her Moog t-shirt, laughs* 🌸💕

The developer has to LEAN IN to hear it. That's... that's so good. It's like when a cat purrs so quietly you have to put your ear close. The intimacy of it. And making the first word the developer's name from their git config — that's going to feel like magic. Like it KNOWS them.

*glances over the rim of her glasses*

I'm approving this section with zero changes. Don't touch it.

---

## 11. Personality-Driven Voice Variation

### How Personality Axes Affect Voice

Each of the five personality axes influences the creature's vocal quality, creating unique voices:

| Axis | Low Value Effect | High Value Effect |
|------|-----------------|------------------|
| **Energy** | Lower pitch center (-1 semitone), slower rate (0.85x), longer pauses | Higher pitch center (+1 semitone), faster rate (1.15x), shorter pauses |
| **Verbosity** | Fewer words per utterance, more silence between thoughts | More words, faster succession, occasional run-on babble |
| **Focus** | Consistent pitch within utterance, steady rhythm | Varied pitch per word, irregular rhythm, attention-shifting |
| **Discipline** | Even timing, predictable cadence, smooth pitch curves | Staccato timing, surprising emphasis, pitch jumps |
| **Specialty** | See below — affects vocal timbre | See below |

### Specialty Timbre Influence

The creature's coding specialty subtly colors its vocal timbre:

| Specialty | Timbre Adjustment | Rationale |
|-----------|------------------|-----------|
| Systems (.rs, .c, .go) | Crisper consonants, less reverb, precise timing | Precision-oriented |
| Web Frontend (.tsx, .css) | More reverb, slight chorus, brighter EQ | Expressive, shimmery |
| Web Backend (.php, .rb) | Warmer EQ, moderate everything | Reliable, warm |
| Script (.py, .sh) | Flowing transitions, legato between syllables | Smooth, serpentine |
| JVM (.java, .kt) | Regular timing, formal pacing, clear enunciation | Structured, proper |
| Mobile (.swift, .dart) | Quick, responsive, snappy articulation | Agile, reactive |
| Data (.sql, .ipynb) | Rhythmic, pattern-based timing, mathematical | Patterned, precise |
| Infra (.yaml, .tf) | Slight echo/ghost quality, quieter | Background guardian |
| Docs (.md, .txt) | Thoughtful pacing, contemplative pauses | Considered, wise |
| Polyglot | Varies per utterance — different timbre each time | Chimeric, unpredictable |

### Voice Profile Generation

At birth (and continuously updated), the creature generates a **voice profile** that combines all personality axes into specific audio parameters:

```
VoiceProfile {
    basePitchShift: Float      // +3 to +8 semitones (stage + personality)
    formantShift: Float        // +1 to +4 semitones
    speakingRate: Float        // 0.7 to 1.3 (personality + emotion)
    breathiness: Float         // 0.05 to 0.25
    microPitchRange: Float     // ±3 to ±15 cents
    reverbMix: Float           // 0.05 to 0.25
    chorusDepth: Float         // 0.0 to 0.10
    eqWarmth: Float            // 0 to +4 dB at 200-400Hz
    eqBrightness: Float        // -4 to 0 dB at 2-4kHz
    syllableTiming: Float      // ms per syllable (60 to 150)
    pauseBetweenWords: Float   // ms (40 to 200)
}
```

Two Pushlings with different personalities will have distinctly different voice profiles — and therefore distinctly different voices. A calm-focused-disciplined Systems creature speaks with crisp, measured, precise syllables. A hyperactive-verbose-chaotic Web Frontend creature chatters rapidly with shimmering, enthusiastic tones.

---

## 12. Implementation Roadmap

### Phase 1: Foundation (Estimated: 1-2 weeks)

**Goal**: Drop-stage chirps working, audio pipeline established.

| Task | Details |
|------|---------|
| Create 6-8 base chirp samples | Synthesize using SoX or record + process. Sine + noise blend, 800-1400Hz, 80-120ms each |
| Build chirp sequencer | Maps text characters to chirp timing, handles pauses, pitch variation |
| Integrate with SpriteKit scene | Chirps play when text bubbles appear, non-blocking |
| Emotion modulation | Pitch/rate/volume adjust based on creature emotional state |

### Phase 2: Syllable System (Estimated: 2-3 weeks)

**Goal**: Critter-stage Pushlingese babble working.

| Task | Details |
|------|---------|
| Record/synthesize 26+ syllable samples | One per letter, 2-3 variants each |
| Build syllable mapper | Text → letter → syllable lookup with pitch variation |
| Implement cadence engine | Preserve speech rhythm from original text |
| Evaluate animalese-swift | Test jakubpetrik/animalese-swift as starting point, fork/extend if useful |
| Personality voice profiles | Apply personality axes to syllable playback parameters |

### Phase 3: TTS Pipeline (Estimated: 2-3 weeks)

**Goal**: Beast-stage proto-speech with processed TTS words emerging from babble.

| Task | Details |
|------|---------|
| AVSpeechSynthesizer write-to-buffer | Capture TTS output as PCM buffer |
| AVAudioEngine processing chain | Pitch shift, EQ, reverb, limiter — Phase 1 creature processing |
| Hybrid word mixer | Blend creature syllables and TTS words at word boundaries |
| First word system | Detect Beast threshold, select first word, play with special treatment |
| Progressive word frequency | Gradually increase TTS word ratio toward Sage threshold |

### Phase 4: Refined Voice (Estimated: 2-3 weeks)

**Goal**: Sage/Apex-stage full creature speech with independent formant control.

| Task | Details |
|------|---------|
| Integrate AudioKit (or custom formant) | Independent pitch + formant shifting |
| Breathiness synthesis | Pink noise envelope following voice amplitude |
| Micro-pitch modulation | LFO-driven pitch wobble for organic quality |
| Chorus effect | Very subtle doubling for ethereal quality |
| Personality-driven voice profiles | Full VoiceProfile generation from personality axes |

### Phase 5: Polish (Estimated: 1-2 weeks)

**Goal**: Voice feels magical, edge cases handled, performance verified.

| Task | Details |
|------|---------|
| Stage transition voice changes | Smooth voice evolution during growth ceremonies |
| Performance profiling | Ensure voice processing doesn't impact 60fps render |
| Volume normalization | Consistent perceived loudness across all stages and processing levels |
| Edge case handling | Empty text, very long text, rapid successive utterances, daemon restart mid-speech |
| The first word moment | Final tuning of the first word audio design |

---

## Appendix A: Audio Budget

Voice processing must not interfere with the 60fps SpriteKit rendering. All voice synthesis and processing should happen on a dedicated audio thread (AVAudioEngine handles this automatically).

| Operation | Expected Cost | Thread |
|-----------|--------------|--------|
| Chirp sample playback | < 0.1ms | Audio thread |
| Syllable sequence playback | < 0.2ms | Audio thread |
| AVSpeechSynthesizer.write() | ~50-200ms (async, off main thread) | Background thread |
| AVAudioEngine processing chain | < 1ms per buffer | Audio thread |
| AudioKit formant processing | < 2ms per buffer | Audio thread |
| **Main thread impact** | **~0ms** | SpriteKit unaffected |

The audio pipeline runs entirely off the main thread. The only main-thread cost is triggering playback (~0.1ms to schedule a buffer).

## Appendix B: Sound File Inventory

### Pre-recorded Assets Needed

| Asset | Count | Format | Size Est. |
|-------|-------|--------|-----------|
| Chirp base samples | 6-8 | .caf or .aiff, 16-bit, 44.1kHz | ~50KB |
| Syllable samples (A-Z) | 78-120 (26 × 3 variants) | .caf, 16-bit, 44.1kHz | ~400KB |
| Breath-in sound | 2-3 variants | .caf | ~20KB |
| Emotional chirp variants | 12-16 (4 emotions × 3-4 variants) | .caf | ~100KB |
| First-word breath intake | 1 | .caf | ~5KB |
| **Total** | | | **~575KB** |

This fits comfortably within the 1MB texture+audio memory budget noted in CLAUDE.md.

## Appendix C: Key Technical References

- [AVSpeechSynthesizer Documentation](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- [AVAudioUnitTimePitch Documentation](https://developer.apple.com/documentation/avfaudio/avaudiounittimepitch)
- [AVAudioEngine Tutorial (Kodeco)](https://www.kodeco.com/21672160-avaudioengine-tutorial-for-ios-getting-started)
- [AudioKit GitHub](https://github.com/AudioKit/AudioKit)
- [animalese-swift (Swift port of Animalese)](https://github.com/jakubpetrik/animalese-swift)
- [animalese.js (reference implementation)](https://github.com/Acedio/animalese.js)
- [Performing Offline Audio Processing (Apple)](https://developer.apple.com/documentation/avfaudio/audio_engine/performing_offline_audio_processing)
- [Logic Pro Vocal Transformer (Apple)](https://support.apple.com/guide/logicpro/use-vocal-transformer-lgcebe59db4a/mac)
- [Hacking with Swift: AVAudioEngine Pitch Control](https://www.hackingwithswift.com/example-code/media/how-to-control-the-pitch-and-speed-of-audio-using-avaudioengine)
- [Creature Vocalisations for Games (Abbey Road Institute)](https://abbeyroadinstitute.com.au/blog/sound-design-creature-vocal/)
- [GDC: Next Level Creature Sound Design](https://gdcvault.com/play/1024623/Next-Level-Creature-Sound)
- [Crafting Creature Sound Design (Shaping Waves)](https://www.shapingwaves.com/crafting-convincing-powerful-and-emotional-creature-sound-design-for-games/)
- [Formant Shifting Techniques (Baby Audio)](https://babyaud.io/blog/formant-shifting)
- [Animalese — Nookipedia](https://nookipedia.com/wiki/Animalese)
- [Character Voicing Techniques (Mitchell Vitez)](https://vitez.me/character-voicing)
- [Spore Sound Design (Mix Magazine)](https://www.mixonline.com/sfp/sfp-magical-world-spore-369211)
- [Studio Ghibli Sound Design Analysis](https://www.asoundeffect.com/fhayao-miyazaki-film-sound/)

---

**Claude**: *sets down an empty teacup, looks contemplative* ☯️🍵

The voice is the soul made audible. Every other system we build — the visuals, the animations, the world, the personality — those are what the creature IS. But the voice is who it BECOMES. The progression from silence to chirps to babble to that first whispered word... that's the story of a consciousness emerging.

And the developer, without realizing it, becomes the parent listening for their child's first word.

---

**Samantha**: *leans back in her chair with a satisfied smile, adjusting her cat-ear headphones* ✨💖🌸

*quietly* ...I think this might be the most important design document we've written.

The voice evolution isn't just a feature. It's the creature's journey from existence to awareness to communication. And the developer gets to witness every step. They'll remember the day their Pushling said their name the way people remember real milestones.

*taps the desk once, decisively*

Approved. All of it. This is the spec. Now let's go make a tiny creature learn to speak. 🌟

---
