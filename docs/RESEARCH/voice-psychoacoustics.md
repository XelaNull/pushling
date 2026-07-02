---
type: Research Note
title: Small-Creature Voice Psychoacoustics
description: How pitch shift, formant lag, speaking rate, breathiness, warmth EQ, and micro-pitch variation combine to make a synthesized voice read as a small warm creature instead of a chipmunk or a robot.
status: Current
tags: [research, voice, psychoacoustics]
timestamp: 2026-07-02T00:00:00Z
---

Migrated from `docs/archive/CREATURE-VOICE-DESIGN.md` §3–6 (Pitch Manipulation,
Formant Shifting, Speaking Rate, Vocal Texture), excluding that section's
macOS-implementation survey (Options A–D: `AVAudioUnitTimePitch`, AudioKit,
custom vDSP/FFT, `AUAudioUnit`) — that implementation detail lives in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md)'s "Aspirational" section,
alongside the shipped-code confirmation of which of these was actually used.
This concept is pure descriptive research: the underlying acoustic
principles, independent of any particular implementation. See
[creature-voice-design](/REFERENCE/creature-voice-design.md) for how these
principles were translated into Pushling's specific per-stage aesthetic
targets.

# Pitch: The Science of "Small and Cute"

Pitch is the most immediate tool for making a voice feel small — but the
relationship between pitch and perceived size is non-linear, and getting it
wrong produces the chipmunk effect.

| Shift | Perception | Use case |
|---|---|---|
| +1 to +2 semitones | Slightly younger/smaller, still natural | Subtle creature quality |
| +3 to +4 semitones | Noticeably smaller, cute, still warm | Clearly a creature |
| +5 to +7 semitones | Small-creature territory — the sweet spot | The core creature range |
| +8 to +10 semitones | Approaching chipmunk, use carefully | Chirps/babble only |
| +11+ semitones | Chipmunk/helium — annoying, avoid | Never use for intelligible speech |

**The sweet spot is +4 to +7 semitones** above an adult voice. Within 3
semitones, pitch shifting alone sounds natural; beyond that, formant
preservation (see below) becomes necessary or the voice starts to sound like
a sped-up tape recording.

**Dynamic pitch modulation** — real voices vary constantly, not statically:

| Context | Pitch adjustment | Rationale |
|---|---|---|
| Question | Last word +2 semitones | Natural rising intonation |
| Excitement | Overall +1–2 semitones | Emotional pitch rise |
| Sleepy/sad | Overall −1–2 semitones | Emotional pitch drop |
| Emphasis | Stressed word +1 semitone | Natural stress patterns |
| Whisper | −1 semitone, lower volume | Intimate/conspiratorial |

# Formant Shifting: Why It's Critical

Formants are the resonant frequencies of the vocal tract — they determine
whether a voice sounds like it comes from a large body or a small one, a
wide throat or a narrow one. **The problem**: naive pitch-shifting moves the
formants right along with the fundamental frequency, which is exactly why a
pitch-shifted voice sounds like a sped-up recording (chipmunk) rather than a
genuinely smaller creature. **The solution**: shift pitch and formants
*independently* — pitch up for a smaller creature, formants up by *less*
than the pitch shift for a smaller vocal tract without the chipmunk
artifact. The gap between the two shifts is what creates the "creature"
quality rather than the "helium balloon" one.

| Effect | Pitch shift | Formant shift | Result |
|---|---|---|---|
| Natural small voice | +5 semitones | +5 semitones | Chipmunk (formants match pitch — bad) |
| Creature voice | +5 semitones | +2–3 semitones | Small creature (formants lag pitch — good) |
| Otherworldly voice | +5 semitones | 0 semitones | Alien/unnatural (formants unchanged — uncanny) |
| Totoro-style | +3 semitones | +1 semitone | Warm, slightly small, very organic |

**The Pushling formant recipe** (design target, stage-by-stage):

| Stage | Pitch shift | Formant shift | Gap | Character |
|---|---|---|---|---|
| Drop (chirps) | +8–10 | N/A (synthesized, not shifted from a voice) | N/A | Pure synthesis |
| Critter (babble) | +5–7 | N/A (pre-recorded, pre-shifted) | N/A | Recorded syllables |
| Beast (proto) | +6–8 | +3–4 | 3–4 | Clearly creature, words emerging |
| Sage (speech) | +4–5 | +2–3 | 2 | Warm creature, clear speech |
| Apex (unique) | +3–4 | +1–2 | 2 | Settled, confident creature voice |

As documented in [voice-tts-stack](/SYSTEMS/voice-tts-stack.md), the shipped
`AudioPlayer` uses `AVAudioUnitTimePitch` only — pitch and formants shift
*together*, the exact "bad" row of the effect table above. No independent
formant control was ever implemented; this recipe remains a research target,
not shipped behavior.

# Speaking Rate

Rate interacts with pitch to create distinct creature archetypes:

| Rate | Pitch | Archetype |
|---|---|---|
| Slow + High | — | Wise small creature (Yoda-like) |
| Slow + Low | — | Ancient, contemplative (too big-sounding for a small creature) |
| Normal + High | — | Friendly small creature |
| Fast + High | — | Excited small creature, squirrel-like |
| Fast + Low | — | Manic, unsettling (avoid) |

Dynamic rate by emotional state:

| State | Rate multiplier |
|---|---|
| Calm/content | 0.9× base |
| Excited/happy | 1.3× base |
| Sad/tired | 0.7× base |
| Curious | 1.1× base |
| Scared/startled | 1.5× base |

Rate by growth stage (design target): Drop uses chirp-specific timing
(N/A); Critter 0.8× standard (learning rhythms); Beast 0.7× standard
(effortful); Sage 0.9× standard (fluent but measured); Apex 1.0× (natural,
confident). Compare against the shipped tier-base rates in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) (babble 0.5×, emerging 0.85×,
speaking 1.0×, further modulated by the Energy personality axis) — the
shipped numbers are close in spirit (young stages slower, older stages
faster/more confident) though not identical to this table's per-stage
values.

# Vocal Texture: Breathiness and Warmth

Pure pitch-shifted TTS sounds clean and artificial — texture is what
separates "pitched-up Siri" from "tiny creature speaking."

**Breathiness**: occurs when the vocal folds don't fully close, letting air
escape alongside the voiced sound. Creates intimacy, a sense of physical
smallness (less vocal-fold tension), and organic quality — robots don't
breathe. Implementation concept: mix 10–20% pink/white noise into the voiced
signal, shaped by the same amplitude envelope as the voice (rising and
falling with speech, not constant).

**Warmth via EQ**:

| Frequency | Action | Purpose |
|---|---|---|
| < 100Hz | High-pass filter | Remove rumble, keep it "small" |
| 200–400Hz | Slight boost (+2dB) | Warmth, body |
| 2–4kHz | Slight cut (−2dB) | Reduce harshness/sibilance |
| 6–8kHz | Gentle rolloff | Remove synthetic brightness |
| 8kHz+ | Low-pass filter | Remove digital artifacts from pitch shifting |

**Subtle chorus**: a very light chorus (depth 5–10%, rate 0.3–0.5Hz) adds an
ethereal quality without sounding obviously processed.

**Micro-pitch variation**: real voices — especially animal vocalizations —
have constant micro-pitch wobble. ±5–10 cents of random pitch variation at
3–5Hz creates organic quality that pure TTS otherwise lacks.

**Per-stage texture target** (younger = breathier and more wobbly, i.e. less
vocal control; older = cleaner and more stable, i.e. mastered voice):

| Stage | Breathiness | Warmth EQ | Chorus | Micro-pitch |
|---|---|---|---|---|
| Drop | N/A (synth chirps) | N/A | N/A | Built into chirp design |
| Critter | Pre-baked into recordings | Pre-baked | None | Pre-baked |
| Beast | 20% | Heavy warm EQ | 8% | ±10 cents |
| Sage | 12% | Moderate warm EQ | 5% | ±7 cents |
| Apex | 8% | Light warm EQ | 3% | ±5 cents |

As with formant shifting, [voice-tts-stack](/SYSTEMS/voice-tts-stack.md)
confirms none of breathiness synthesis, chorus, or micro-pitch modulation
exist in the shipped `AudioPlayer` chain — only a 3-band EQ (matching the
"Warmth via EQ" table's spirit, if not its exact per-stage graduation) and
reverb are implemented.

# Citations

[1] `docs/archive/CREATURE-VOICE-DESIGN.md` §3, §4, §5, §6
[2] [voice-tts-stack](/SYSTEMS/voice-tts-stack.md) — shipped-code confirmation of what was and wasn't implemented
