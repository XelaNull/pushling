---
type: System
title: Voice / TTS Stack
description: The three-tier local text-to-speech runtime (espeak-ng / Piper / Kokoro-82M via sherpa-onnx) that gives the creature an audible voice — tier-to-stage mapping, download-on-demand model acquisition, the AVAudioEngine effects chain, and personality-driven voice parameters.
status: Live
tags: [voice, tts, audio, system]
timestamp: 2026-07-02T00:00:00Z
---

This is **the** single authority for the TTS stack, merging
`docs/archive/TTS-RESEARCH.md` §16 (Recommended Architecture) and
`docs/archive/plan/phase-5-speech/PHASE-5.md` Track 2 (P5-T2-01 through P5-T2-11)
into one concept verified against
`Pushling/Sources/Pushling/Voice/*.swift`. Both source documents also
described an `AVSpeechSynthesizer`-based pipeline
(`docs/archive/CREATURE-VOICE-DESIGN.md` §8–9) as an alternative architecture — that
path was **not** what shipped; see below.

# The 3 Tiers (Not 6)

`VoiceTier` (`VoicePersonality.swift`) has exactly three cases:

| Tier | Engine | Stage(s) |
|---|---|---|
| `babble` | espeak-ng (formant synthesis) | Drop |
| `emerging` | Piper VITS (low quality) | Critter |
| `speaking` | Kokoro-82M (ONNX) | Beast, Sage, **and** Apex — all three collapse to the same tier |

`VoiceTier.forStage(.egg)` returns `nil` (silent — no model needed).
`docs/archive/TTS-RESEARCH.md`'s Executive Summary table and
`docs/archive/CREATURE-VOICE-DESIGN.md` §2's stage table both describe **six**
distinct voice types (adding "Eloquent" at Sage and "Transcendent" at Apex,
each with its own described tuning). No such distinction exists in code —
Sage and Apex share the exact same `VoiceTier.speaking` / Kokoro-82M path as
Beast. The finer per-stage character difference both docs describe (Sage
"warmer, slower", Apex "full range + effects") is expressed today only
through the personality/stage-driven parameter table below (e.g. `warmthBoostDB`
does step up 3.0→3.5→4.0 across Beast/Sage/Apex), not through a separate
model or pipeline. Preserved below as intent for a possible finer-grained
future tier split — not current architecture.

# Download-on-Demand, Not Bundled

Both `docs/archive/TTS-RESEARCH.md` ("Every engine is bundled. No downloads.") and
`docs/archive/CREATURE-VOICE-DESIGN.md` assume all TTS models ship inside
Pushling.app (~100–120MB total). **This is not what shipped.**
`ModelDownloader.swift` fetches model archives at runtime from
`k2-fsa/sherpa-onnx`'s GitHub releases (`piperArchiveURL`,
`kokoroArchiveURL`) via `URLSession`, extracts them with `/usr/bin/tar`, and
installs the files into
`~/.local/share/pushling/voice/models/{espeak-ng,piper,kokoro}/`. Nothing
voice-related ships inside the `.app` bundle itself.

| Tier | Directory | Required files | `ModelManager`'s size estimate |
|---|---|---|---|
| `babble` (espeak-ng) | `espeak-ng/` | `model.onnx`, `tokens.txt`, `espeak-ng-data/` | ~16MB |
| `emerging` (Piper) | `piper/` | `en_US-amy-low.onnx`, `tokens.txt`, `espeak-ng-data/` | ~16MB |
| `speaking` (Kokoro) | `kokoro/` | `model.onnx`, `voices.bin`, `tokens.txt`, `espeak-ng-data/` | ~80MB |

The `babble` tier is installed from the **Piper archive** (there is no
standalone espeak-ng-only download) — `ModelDownloader`'s
`installEspeakFiles` copies the same `en_US-amy-low.onnx` used by the
`emerging` tier into the `espeak-ng/` directory and renames it `model.onnx`.
`docs/archive/TTS-RESEARCH.md`'s claimed "espeak-ng ~2MB" figure describes the
upstream espeak-ng project's own footprint, not what Pushling actually
downloads for its babble tier (~16MB, since it's really a Piper voice file).
`espeak-ng-data/` is symlinked from the babble tier into the emerging/
speaking tiers when present, rather than duplicated
(`linkOrCopyEspeakData`).

**Fallback chain**: `ModelManager.bestAvailableTier(for:)` tries the ideal
tier for the current stage, then falls back down
(`speaking → emerging → babble → nil`) if higher tiers aren't installed.
`hasAnyModel == false` means total silence — text bubbles only, no audio at
all. An interactive alternative path exists (`launchVoiceSetup()`, which
shells out to a `pushling-voice-setup` script if found on disk) but the
primary path is the in-app `requestDownload`/`downloadAllMissing` API.

# The Actual Engine: sherpa-onnx — No AVSpeechSynthesizer, No Fallback

`SherpaOnnxBridge.swift` dynamically resolves symbols from the sherpa-onnx C
API (`isNativeAvailable`, `isModelLoaded`, `sampleRate`,
`espeakConfig`/`piperConfig`/`kokoroConfig` factory methods) — this is the
"STRONG CANDIDATE" runtime `docs/archive/TTS-RESEARCH.md` §8 recommended, and it won
outright. A repo-wide search finds **zero** references to
`AVSpeechSynthesizer` or `AVSpeechUtterance` anywhere in
`Pushling/Sources/`. Two design-doc claims about this are stale:

- `docs/archive/CREATURE-VOICE-DESIGN.md` §8–9's entire pipeline — `AVSpeechSynthesizer.write(_:toBufferCallback:)` capturing audio to a buffer, then processing through a custom `AVAudioEngine` chain with `AudioKit` for independent formant control — was the **design-time plan**, never built. The sherpa-onnx architecture from `docs/archive/TTS-RESEARCH.md` was chosen instead.
- `docs/archive/TTS-RESEARCH.md` §16's own "Fallback: AVSpeechSynthesizer (if sherpa-onnx fails to load)" was also never implemented. If no sherpa-onnx model is available, `VoiceSystem.isEnabled` is simply `false` and the creature stays silent (text bubbles only) — there is no synthesizer fallback tier.

# Tier Loading & Switching

`VoiceSystem.initialize(stage:personality:)` sets `currentTier` from
`VoiceTier.forStage`, scans installed models
(`modelManager.scanModels()`), and asynchronously loads the best available
model on a dedicated serial `voiceQueue`. `VoiceSystem.onStageChanged(to:)`
recalculates `voiceParams` (see below) unconditionally, and — only if the
resolved tier actually changed — unloads the old model and loads the new one
on `voiceQueue`, then clears the WAV cache (voice parameters changed, so
cached audio is now stale). `stageForTier` provides the reverse mapping used
to re-run `bestAvailableTier` lookups for a tier (`babble→.drop`,
`emerging→.critter`, `speaking→.beast`).

# The Audio Effects Chain (Confirmed Real)

`AudioPlayer.swift` builds a real `AVAudioEngine` chain:

```
AVAudioPlayerNode → AVAudioUnitTimePitch → AVAudioUnitEQ (3-band) → AVAudioUnitReverb → mainMixerNode
```

- EQ: high-pass at 100Hz (band 0, removes rumble); parametric +3dB boost at
  300Hz (band 1, warmth — this is the band `warmthBoostDB` from
  `VoiceParameters` drives per-request); parametric −2dB cut at 4kHz (band
  2, de-harshens).
- Reverb: `.smallRoom` factory preset, wet/dry mix set per-request (0% for
  normal speech, 20% for whisper, 15% for sing, and — for dream audio — the
  `DreamModifiers.reverbWet` value, 40%).
- Pitch: `AVAudioUnitTimePitch.pitch` in cents (100 cents = 1 semitone),
  `.rate` clamped to `[0.25, 4.0]` (the hardware's own limits).

This matches `docs/archive/TTS-RESEARCH.md` §16's proposed
pitch→EQ→reverb→AVAudioEngine pipeline and `PHASE-5.md` P5-T2-05 closely —
one of the few places in this domain where the design intent and the shipped
code line up almost exactly.

**Volume table** (`VoicePersonalityCalculator.volumeForStyle` + special
cases):

| Context | Volume | Notes |
|---|---|---|
| `say` | 0.6 | Default |
| `exclaim` | 0.8 | +3dB above normal |
| `whisper` | 0.3 | −6dB |
| `dream` | 0.24 | 0.6 × 0.4 |
| `sing` | 0.6 | Pitch modulation instead of volume change |
| `think` | 0.0 | No audio at all (`styleProducesAudio(.think) == false`) |
| `narrate` | 0.5 | Slightly quieter |
| First Audible Word | 0.21 | 0.3 × 0.7 — see [speech-milestones](/REFERENCE/speech-milestones.md) |

# Voice Parameters from Personality

`VoicePersonalityCalculator.calculate(personality:stage:)` derives a
`VoiceParameters` struct (`pitchSemitones`, `rateMultiplier`,
`intonationRange`, `warmthBoostDB`) that is **locked at each stage
transition** — recomputed once when the creature evolves, not per-utterance:

| Input | Effect |
|---|---|
| Tier base pitch | babble 8.0st, emerging 6.0st, speaking 5.5st |
| Energy → pitch offset | < 0.3: −1.0st; > 0.7: +1.5st; mid-range: linear `(energy−0.5)×3.0` |
| Tier base rate | babble 0.5×, emerging 0.85×, speaking 1.0× |
| Energy → rate modifier | < 0.3: 0.8×; > 0.7: 1.2×; mid-range: linear |
| Verbosity → intonation range | < 0.3: 0.3 (flat); > 0.7: 2.0 (expressive); mid-range: linear |
| Stage → warmth boost (dB) | egg/drop: 0.0; critter: 2.0; beast: 3.0; sage: 3.5; apex: 4.0 |

This matches the "voice identity locking" intent of `PHASE-5.md` P5-T2-06
(same rationale: consistent voice within a stage, recalculated only at
evolution) — but see the storage note below for where that document's detail
diverges.

**Storage**: `PHASE-5.md` P5-T2-06 and `VoicePersonality.swift`'s own header
comment both describe voice parameters as persisted in a SQLite
`creature_voice` table (columns: `stage`, `pitch_semitones`,
`rate_multiplier`, `intonation_range`, `warmth_boost_db`). A grep of
`State/Schema.swift`'s `CREATE TABLE` list confirms no such table exists.
`VoiceParameters` are recalculated in memory on every `onStageChanged` call
— which is equivalent in practice, since the calculation is deterministic
from personality + stage, but it means there is no persisted
`creature_voice` row to query directly. Flagged as an unbuilt storage detail;
the *values* the table would hold are fully described above regardless.

# Critter Speech Mix (Babble-to-Words Ratio)

```
ratio = clamp((commitsEaten − 75) / 124.0, 0.2, 0.8)
```

Each word in the text independently rolls against `ratio`: below the roll,
the real word is kept; above it, a random phoneme from the shared babble
pool is substituted (`critterSpeechMix`). `PHASE-5.md` P5-T2-03 describes
this as three discrete bands (20–30% real speech at 75–100 commits, 50–60%
at 100–150, 80% at 150–199) — the code's continuous linear formula produces
practically the same range as a smooth function rather than stepped bands;
the design doc's table is a reasonable prose approximation of the same
formula, not a contradiction.

# Babble Generation (Drop-Stage Audio)

`generateBabbleText()` picks 1–3 random phonemes from a 23-entry pool
(`"buh"`, `"dah"`, `"gah"`, … `"ee"`, `"oo"`, `"ah"`, `"oh"`, `"ih"`),
occasionally suffixing the last one with `"!"` or `"..."` for rhythm. This is
independent, per-utterance audio synthesis — it is **not** the same string
as the Drop-stage visual symbol glyph shown in the speech bubble (see
[speech-rendering](/REFERENCE/speech-rendering.md)); the two fire together
but are generated by unrelated code paths.

# Caching

50MB WAV cache at `~/.local/share/pushling/voice/cache/`, keyed by an FNV-1a
hash of `(text, pitch, rate, stage)`; LRU eviction by file modification date
once the cap is exceeded (`AudioPlayer.evictCacheIfNeeded`). Matches
`PHASE-5.md` P5-T2-09's cache design closely (same 50MB cap, same
hit/generate/play flow) — another section where the shipped implementation
tracks the design doc almost exactly.

# Dream Audio

`onDreamBubble` → `generateDreamAudio`: pitch shifted −3 semitones, rate ×0.7,
reverb 40% wet, volume 0.24 (0.6 × 0.4) — the `DreamModifiers` struct's
values match `PHASE-5.md` P5-T2-10 and `PUSHLING_VISION.md`'s "Between
sessions" paragraph exactly.

# Aspirational: The Never-Built Formant / Chorus / Breathiness Layer

`docs/archive/CREATURE-VOICE-DESIGN.md` §4/§6/§9 and `docs/archive/TTS-RESEARCH.md`'s Voice
Character Design section both call for independent formant shifting
(`AudioKit`'s `FormantFilter`, or a custom vDSP/FFT pipeline), breathiness
(pink-noise mixed into the voiced signal, envelope-shaped), a subtle chorus
effect, and micro-pitch (LFO) wobble, as essential to reading as "small
creature" rather than "pitch-shifted human." **None of this exists in the
shipped `AudioPlayer.swift` pipeline.** Only pitch (`AVAudioUnitTimePitch`,
which shifts formants together with pitch — precisely the "chipmunk risk"
both source documents warn against), a 3-band EQ, and reverb are
implemented; this is "Option A" from `docs/archive/CREATURE-VOICE-DESIGN.md` §4's
own framework, the prototyping starting point that document explicitly
recommended graduating away from ("Graduate to Option B [AudioKit] for
production quality"). That graduation never happened. See
[voice-psychoacoustics](/RESEARCH/voice-psychoacoustics.md) for the research
behind these targets and
[creature-voice-design](/REFERENCE/creature-voice-design.md) for the
aesthetic recipe tables — both describe intent, not current code.

# Citations

[1] `Pushling/Sources/Pushling/Voice/VoicePersonality.swift`
[2] `Pushling/Sources/Pushling/Voice/VoiceSystem.swift`
[3] `Pushling/Sources/Pushling/Voice/ModelManager.swift`
[4] `Pushling/Sources/Pushling/Voice/ModelDownloader.swift`
[5] `Pushling/Sources/Pushling/Voice/SherpaOnnxBridge.swift`
[6] `Pushling/Sources/Pushling/Voice/AudioPlayer.swift`
[7] `Pushling/Sources/Pushling/Voice/VoiceIntegration.swift`
[8] `docs/archive/TTS-RESEARCH.md` §1, §16
[9] `docs/archive/plan/phase-5-speech/PHASE-5.md` — P5-T2-01 through P5-T2-11
[10] `docs/archive/CREATURE-VOICE-DESIGN.md` §4, §8–9 (superseded architecture)
