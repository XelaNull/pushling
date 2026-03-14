# Local Text-to-Speech Research: Making the Pushling Speak

**Compiled**: 2026-03-14 | **Scope**: On-device TTS for macOS Swift application (Apple Silicon)

---

## Executive Summary

The Pushling can learn to speak using entirely local, offline text-to-speech -- no API keys, no cloud services, no setup. The user opens their laptop one day and their Touch Bar creature says something out loud. Zero configuration magic.

After evaluating 11 TTS options across quality, latency, size, and Swift integration, our recommendation is a **tiered progression system** that mirrors the creature's growth stages:

| Growth Stage | TTS Tier | Engine | Quality | Why |
|-------------|----------|--------|---------|-----|
| Spore (0-19) | Silent | None | N/A | Spores don't speak. Mystery. |
| Drop (20-74) | Babble | espeak-ng (formant) | Robotic | First sounds. Alien. Charming because it's trying. |
| Critter (75-199) | Emerging | Piper (low/medium) | Decent | Recognizable words. Still has a "creature" quality. |
| Beast (200-499) | Speaking | Kokoro-82M (ONNX) | Good | Clear speech. Personality in voice. The "wow" moment. |
| Sage (500-1199) | Eloquent | Kokoro-82M (tuned) | Very Good | Warm, expressive, creature-characteristic voice. |
| Apex (1200+) | Transcendent | Kokoro + effects | Excellent | Full range. Whispers, exclaims, sings. |

**Total bundle size**: ~100-120MB (espeak-ng ~2MB + Piper low model ~16MB + Kokoro ONNX q8 ~80MB + voice data)

**The killer moment**: The user has had this creature for weeks. It's been showing text bubbles. Then one day at Beast stage, it opens its mouth and *actually speaks*. Out loud. With a warm little voice. No setup was required. The user never installed anything. It just... learned.

---

## Table of Contents

1. [The Growth-Stage Voice Concept](#1-the-growth-stage-voice-concept)
2. [Option 1: macOS Built-in (AVSpeechSynthesizer)](#2-option-1-macos-built-in-avspeechsynthesizer)
3. [Option 2: Apple MLX / Core ML](#3-option-2-apple-mlx--core-ml)
4. [Option 3: Piper TTS](#4-option-3-piper-tts)
5. [Option 4: Coqui TTS / XTTS-v2](#5-option-4-coqui-tts--xtts-v2)
6. [Option 5: Bark (Suno)](#6-option-5-bark-suno)
7. [Option 6: VITS / VITS2](#7-option-6-vits--vits2)
8. [Option 7: Sherpa-ONNX](#8-option-7-sherpa-onnx)
9. [Option 8: espeak-ng](#9-option-8-espeak-ng)
10. [Option 9: Kokoro-82M](#10-option-9-kokoro-82m)
11. [Option 10: MeloTTS](#11-option-10-melotts)
12. [Option 11: NeuTTS](#12-option-11-neutts)
13. [Option 12: Kokoro via MLX Swift (Native)](#13-option-12-kokoro-via-mlx-swift-native)
14. [Option 13: speech-swift (Soniqo)](#14-option-13-speech-swift-soniqo)
15. [Comparison Matrix](#15-comparison-matrix)
16. [Recommended Architecture](#16-recommended-architecture)
17. [Voice Character Design](#17-voice-character-design)
18. [Implementation Roadmap](#18-implementation-roadmap)

---

## 1. The Growth-Stage Voice Concept

The Pushling's TTS progression is not a limitation -- it's the *entire feature*. The creature literally learns to speak over the course of weeks or months, and the quality of its voice mirrors its growth. This is a deeply satisfying mechanic because:

1. **It's narratively coherent.** Of course a baby creature babbles. Of course it gets better.
2. **It solves the quality problem.** Early-stage robotic speech is charming, not embarrassing.
3. **It creates a "wow" moment.** The first time it speaks clearly is a genuine surprise.
4. **It rewards patience.** You raised this thing. You fed it commits. Now it can talk.
5. **It requires zero setup.** Every engine is bundled. No downloads, no API keys.

### What the creature says

The Pushling speaks short phrases, not paragraphs. Utterances are 1-5 words, drawn from:

- Commit messages it has eaten ("refactor!" "fixed the bug!")
- Emotional reactions ("happy!" "hungry..." "sleepy...")
- Greetings and farewells ("morning!" "bye bye!")
- Surprise reactions ("whoa!" "ooh!" "yikes!")
- Language preferences ("love PHP!" "ugh, yaml...")
- Taught words (via `pushling_teach("speak")`)

At 1-5 words, even a 500ms latency budget is generous. Most phrases will synthesize in under 200ms.

### Stage-by-stage voice progression

| Stage | Voice Behavior | Technical Implementation |
|-------|---------------|-------------------------|
| **Spore** | Silent. Pure visual creature. Text bubble only shows `...` or `!` | No TTS engine loaded |
| **Drop** | Babbles. Phonemes and fragments. "buh!" "nnn..." "da!" | espeak-ng at extreme pitch (2.0x), rate 0.5x. Random phoneme sequences. |
| **Critter** | First words emerge from babble. "hi!" "food!" mixed with babble | Piper TTS (low quality) with high pitch. 30% babble, 70% words. |
| **Beast** | Clear speech with creature character. "morning!" "that was yummy!" | Kokoro-82M ONNX. Custom voice blend. This is the surprise moment. |
| **Sage** | Expressive, warm, wise-sounding. "Ah, a fine refactor." | Kokoro-82M with slower rate, deeper pitch, more expression. |
| **Apex** | Full vocal range. Whispers, exclaims, sings, does impressions. | Kokoro-82M with dynamic pitch/rate/voice per emotion. Post-processing effects. |

---

## 2. Option 1: macOS Built-in (AVSpeechSynthesizer)

### Overview

Apple's built-in speech synthesis framework, available on macOS since Mojave. The modern replacement for the older NSSpeechSynthesizer. Supports premium neural voices starting with macOS Ventura.

### Quality Rating: 2-4 stars (depends on voice tier)

- **Default voices**: 2 stars. Functional but obviously synthetic.
- **Enhanced voices**: 3 stars. Noticeably better, more natural cadence.
- **Premium voices**: 4 stars. Neural TTS, genuinely pleasant. Must be downloaded by the user first (150-400MB each).

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~50-150ms (default/enhanced), ~200-400ms (premium) |
| **Binary size** | 0 bytes -- built into macOS |
| **Model size** | 0 (default) to 400MB (premium, user-downloaded) |
| **macOS compatibility** | macOS 10.14+ (AVSpeechSynthesizer), 13.0+ (premium voices) |
| **Apple Silicon** | Native -- uses Neural Engine for premium voices |
| **License** | Apple proprietary (but free to use in any macOS app) |
| **Swift integration** | Native first-class API. 5 lines of code. |

### Customization

```swift
let utterance = AVSpeechUtterance(string: "hello!")
utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
utterance.pitchMultiplier = 1.5  // Range: 0.5 (deep) to 2.0 (high)
utterance.rate = 0.4             // Range: 0.0 to 1.0
utterance.volume = 0.8           // Range: 0.0 to 1.0
synthesizer.speak(utterance)
```

- **Pitch**: 0.5x to 2.0x. Can make voices higher/squeakier for creature effect.
- **Rate**: 0.0 to 1.0. Slower = more deliberate, faster = excited.
- **SSML**: Supported via `AVSpeechUtterance(ssmlRepresentation:)` for phoneme-level control.
- **IPA notation**: Can control exact pronunciation via attributed strings.
- **Delegate callbacks**: Word-boundary callbacks for syncing mouth animation.

### Novelty Voices (Still Available!)

macOS still ships these classic MacinTalk voices, accessible programmatically:

| Voice | Character | Creature Use |
|-------|-----------|-------------|
| Albert | Hoarse, old-man quality | Sage stage? |
| Bells | Musical bell tones | Evolution ceremony |
| Boing | Bouncy, cartoonish | Drop stage babble |
| Bubbles | Underwater gurgling | Spore stage? Water biome? |
| Whisper | Breathy whisper | Late night, sleepy creature |
| Zarvox | Robot with melodic background | Early robotic speech |
| Cellos | Sings text to Grieg melody | Easter egg |

These require the user to download them in System Settings > Accessibility > Spoken Content, which breaks our "zero setup" requirement.

### Pros
- Zero bundle size -- already on every Mac
- Native Swift API, trivially easy to integrate
- Word-boundary delegate callbacks for mouth animation sync
- SSML support for fine-grained control
- Premium voices use Neural Engine (fast, efficient)
- Novelty voices could be fun easter eggs

### Cons
- Premium voices require user to manually download them (150-400MB each)
- Default voices sound obviously like "computer speech" -- not warm or cute
- Cannot bundle or guarantee specific voice availability
- No custom voice creation -- stuck with Apple's offerings
- Voice availability varies by macOS version and user configuration
- Pitch modification makes most voices sound worse, not cuter

### Verdict

**Best as a fallback, not the primary engine.** The zero-bundle-size advantage is significant, and it provides an instant "works everywhere" baseline. But relying on it means we can't guarantee voice quality or availability. The premium voices require user action, which breaks the magic. The novelty voices (Bubbles, Boing) could be hilarious easter eggs if they happen to be installed.

**Recommended role**: Fallback engine if neural models fail to load. Possible easter egg with novelty voices.

---

## 3. Option 2: Apple MLX / Core ML

### Overview

Apple's MLX framework (open source, launched late 2023) enables running ML models natively on Apple Silicon with unified memory. Several TTS models have been ported to MLX, most notably Kokoro and Bark. MLX Swift bindings allow direct integration in Swift apps.

### The MLX-Audio Ecosystem

The [mlx-audio](https://github.com/Blaizzy/mlx-audio) project provides Python APIs, and a companion [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift) package provides native Swift integration. Supported TTS models include:

- **Kokoro**: 82M params, fast, good quality
- **Bark**: Suno's model, very natural but large and slow
- **Qwen3-TTS**: Recent addition, voice cloning capability

### Quality Rating: 3-5 stars (model dependent)

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | 100-500ms (Kokoro), 2-10s (Bark) |
| **Binary size** | MLX framework ~15MB + model weights |
| **Model size** | ~315MB (Kokoro safetensors), ~5GB (Bark full) |
| **macOS compatibility** | macOS 14.0+ (MLX requirement) |
| **Apple Silicon** | Required -- MLX is Apple Silicon only |
| **License** | MIT (MLX), Apache 2.0 (most models) |
| **Swift integration** | Via mlx-audio-swift Swift Package, or kokoro-ios native package |

### The kokoro-ios Swift Package

A native Swift implementation exists: [kokoro-ios](https://github.com/mlalma/kokoro-ios)

- Direct Swift Package Manager integration
- Uses MLX Swift for inference on Apple Silicon GPU
- ~3.3x faster than real-time on iPhone 13 Pro (faster on M-series Macs)
- Requires macOS 15.0+ / iOS 18.0+
- Model file: ~315MB (kokoro-v1_0.safetensors)
- Uses espeak-ng internally for phonemization

### Pros
- Native Apple Silicon optimization via Metal GPU
- Best-in-class performance for on-device inference
- MLX is Apple's own framework -- long-term support likely
- Swift Package Manager integration exists
- Multiple model options (Kokoro, Bark, Qwen3-TTS)
- Community actively porting new models

### Cons
- macOS 14.0+ minimum (MLX), macOS 15.0+ (kokoro-ios)
- Apple Silicon required -- no Intel Mac support
- Model files are large (~315MB for Kokoro safetensors vs ~80MB for ONNX q8)
- MLX framework adds complexity vs simpler ONNX path
- Less mature than ONNX ecosystem for TTS specifically
- espeak-ng dependency for phonemization adds complexity

### Verdict

**The native Swift path for Kokoro.** If we target macOS 15+ only (which is reasonable for a Touch Bar app in 2026), this is the most "Apple-native" approach. The kokoro-ios Swift package is ready-made. However, the model size (~315MB) is larger than ONNX alternatives (~80MB quantized), and the macOS version requirement is strict. Worth comparing against the ONNX path.

**Recommended role**: Primary candidate for Beast/Sage/Apex tier TTS if we accept macOS 15+ requirement and ~315MB model size.

---

## 4. Option 3: Piper TTS

### Overview

Piper is a fast, local neural text-to-speech system by Rhasspy. Uses VITS architecture exported to ONNX format. Designed for edge devices like Raspberry Pi. Hundreds of pre-trained voices in dozens of languages.

### Quality Rating: 3 stars (low), 3.5 stars (medium), 4 stars (high)

Piper voices sound notably better than formant synthesis but lack the expressiveness of larger neural models. The "medium" quality tier hits a sweet spot of quality vs size for a creature that's still learning to speak.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~50-150ms for short phrases (CPU) |
| **Binary size** | ~14MB (piper binary + ONNX runtime for macOS ARM64) |
| **Model size** | ~16MB (low), ~63MB (medium), ~113MB (high) per voice |
| **macOS compatibility** | macOS 13.0+ (aarch64), macOS 11.0+ (x86_64) |
| **Apple Silicon** | Yes, native ARM64 builds available |
| **License** | MIT |
| **Swift integration** | Via C API bridge or sherpa-onnx Swift bindings |

### Voice Quality Tiers

| Quality | Sample Rate | Model Size | Description |
|---------|------------|------------|-------------|
| x_low | 16kHz | ~8MB | Very robotic. Good for "learning to speak" stage. |
| low | 16kHz | ~16MB | Slightly smoother. Still clearly synthetic. |
| medium | 22.05kHz | ~63MB | Good balance. Natural-ish cadence, some artifacts. |
| high | 22.05kHz | ~113MB | Best Piper quality. Still behind Kokoro. |

### Notable Voices (English)

- `en_US-lessac-medium`: Clear American female, good for general use
- `en_US-amy-low`: Smaller model, decent quality
- `en_GB-alba-medium`: British accent option
- Many others -- see [Piper voice samples](https://rhasspy.github.io/piper-samples/)

### Customization

- **Speed**: Adjustable via `length_scale` parameter (lower = faster)
- **Pitch**: No direct pitch control in Piper itself, but audio output can be pitch-shifted post-synthesis
- **Custom voices**: Can train custom voices with ~30 minutes of audio data

### Pros
- Very fast inference -- designed for Raspberry Pi, runs instantly on Apple Silicon
- Small model files, especially at low/x_low quality
- MIT license -- fully permissive
- Hundreds of pre-trained voices available
- Proven ONNX runtime compatibility
- Can be bundled via sherpa-onnx for unified Swift API

### Cons
- No native Swift API -- requires C bridge or sherpa-onnx wrapper
- Quality ceiling below Kokoro and other modern models
- Limited pitch/prosody control compared to AVSpeechSynthesizer
- Voice character is "neutral narrator" -- not inherently cute or creature-like
- Post-synthesis pitch shifting needed for creature voice effect

### Verdict

**Ideal for the Critter stage (75-199 commits).** The low-quality models (~16MB) produce speech that's recognizable but still clearly synthetic -- perfect for a creature that's just learning words. The fast inference means reactive speech. The small model size keeps the bundle lean.

**Recommended role**: Critter-stage voice engine. Bundle one low or medium voice (~16-63MB). Feed it through pitch shifting and rate adjustment to sound creature-like.

---

## 5. Option 4: Coqui TTS / XTTS-v2

### Overview

Coqui TTS was a comprehensive open-source TTS toolkit. Its flagship model, XTTS-v2, offered state-of-the-art voice cloning and multilingual synthesis. The company shut down in December 2025, but the open-source project continues via community (idiap/coqui-ai-TTS fork).

### Quality Rating: 4.5 stars (XTTS-v2)

XTTS-v2 produces remarkably natural speech with voice cloning capability. Quality rivals commercial offerings.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~200ms-1s (streaming mode on GPU), 2-5s on CPU |
| **Binary size** | Large -- Python runtime + PyTorch + model |
| **Model size** | ~2.09GB (XTTS-v2 full model) |
| **macOS compatibility** | macOS (Python), MPS GPU acceleration supported |
| **Apple Silicon** | Yes, via MPS (Metal Performance Shaders) |
| **License** | MPL-2.0 (XTTS-v2 model), LGPL (Coqui TTS framework) |
| **Swift integration** | None -- Python only. Would require subprocess or embedded Python. |

### Pros
- Excellent voice quality, state of the art for open source (at time of shutdown)
- Voice cloning with just 6 seconds of reference audio
- 17 language support
- Streaming mode for lower latency
- Can potentially clone a "creature voice" from a reference

### Cons
- **2.09GB model size** -- far too large for bundling
- **Python-only** -- no Swift integration path without embedding Python runtime
- **CPU inference is slow** (2-5s per utterance) -- breaks our 500ms budget
- **Company shut down** -- community maintenance only, uncertain future
- **GPU required for real-time** -- adds complexity
- LGPL license for framework is restrictive for app embedding
- Complex dependency chain (PyTorch, etc.)

### Verdict

**Not suitable for Pushling.** The model is too large (2GB), inference is too slow on CPU, and there's no Swift integration path. The Python dependency chain would be absurd to bundle in a macOS menu bar app. The voice quality is excellent but the practical constraints are disqualifying.

**Recommended role**: None. Pass.

---

## 6. Option 5: Bark (Suno)

### Overview

Bark is a generative text-to-audio model by Suno AI. Unlike traditional TTS, Bark can generate speech with emotion, laughter, sighs, music, and sound effects. It follows a GPT-style architecture and produces remarkably natural-sounding speech.

### Quality Rating: 5 stars (when it works)

Bark produces the most natural-sounding speech of any model evaluated. It can laugh, sigh, whisper, and express genuine emotion. However, output is non-deterministic and sometimes produces artifacts.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | 2-10s on GPU, 10-30s+ on CPU |
| **Binary size** | Large -- Python + PyTorch |
| **Model size** | ~5GB (full), ~1.5GB (small) |
| **macOS compatibility** | Via Python + MPS acceleration |
| **Apple Silicon** | Yes, via MPS flag (--enablemps) |
| **License** | MIT |
| **Swift integration** | None directly. MLX port exists (mlx_bark) but is experimental. |

### Pros
- Most natural speech quality available
- Can generate laughter, sighs, music -- not just speech
- MIT license
- MLX port exists for Apple Silicon
- Non-verbal expressions would be magical for a creature

### Cons
- **WAY too slow** -- 5-30 seconds per utterance. Unusable for reactive speech.
- **5GB model** -- absurd for bundling
- **Non-deterministic** -- sometimes generates garbage
- **Python-only** (MLX port is also Python)
- No real-time capability
- GPU-hungry (12GB VRAM recommended for full model)

### Verdict

**Not suitable for Pushling.** The latency alone is disqualifying -- 5-30 seconds for a short phrase means the creature would respond to your commit half a minute later. The model size is also prohibitive. Bark is a research demo, not a production TTS engine.

**Recommended role**: None. The technology is inspiring (emotional speech generation!) but the practical constraints are too severe. Kokoro achieves 80% of the naturalness at 1/50th the size and 20x the speed.

---

## 7. Option 6: VITS / VITS2

### Overview

VITS (Variational Inference with adversarial learning for end-to-end Text-to-Speech) and its successor VITS2 are the architecture underlying Piper TTS. Running VITS directly (rather than through Piper) gives access to more models and configurations, though the core technology is the same.

### Quality Rating: 3-4 stars (model dependent)

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~50-200ms for short phrases |
| **Binary size** | Via ONNX runtime (~10MB) |
| **Model size** | ~15-65MB (varies by model and quality) |
| **macOS compatibility** | Via ONNX Runtime (all macOS) |
| **Apple Silicon** | Yes, via ONNX Runtime with CoreML execution provider |
| **License** | MIT |
| **Swift integration** | Via sherpa-onnx C/Swift bindings |

### Pre-trained Models Available

Via sherpa-onnx, numerous VITS models are available:
- LJSpeech (English female, ~63MB)
- VCTK (English multi-speaker, ~63MB)
- Various language-specific models
- All Piper models are VITS models

### Pros
- Solid, proven architecture
- Fast inference
- Many pre-trained models
- ONNX export well-supported
- Sherpa-onnx provides unified access

### Cons
- Essentially the same as Piper (which wraps VITS)
- Quality ceiling below newer models like Kokoro
- Using VITS directly adds complexity vs using Piper's packaged models

### Verdict

**Subsumed by Piper (Option 3) and Kokoro (Option 9).** VITS is the underlying architecture, but Piper packages it better with more voices, and Kokoro surpasses it in quality. No reason to use raw VITS when better packaging exists.

**Recommended role**: None directly. Accessed via Piper or sherpa-onnx.

---

## 8. Option 7: Sherpa-ONNX

### Overview

Sherpa-ONNX is a C++ library by k2-fsa (Next-gen Kaldi) that provides on-device speech processing including TTS, STT, speaker diarization, and VAD. It wraps ONNX Runtime and supports 12 programming languages including Swift. It's not a TTS model itself -- it's a *runtime* that can load multiple TTS model types.

### Quality Rating: N/A (depends on loaded model)

Sherpa-ONNX is the runtime, not the voice. Quality depends on which model you load.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | Depends on model -- adds ~5-10ms overhead |
| **Binary size** | ~15-20MB (sherpa-onnx + ONNX Runtime, macOS ARM64) |
| **Model size** | Depends on loaded model |
| **macOS compatibility** | macOS 11.0+ (ARM64 and x86_64) |
| **Apple Silicon** | Native ARM64, CoreML execution provider available |
| **License** | Apache 2.0 |
| **Swift integration** | Yes! C API with Swift wrappers. iOS SwiftUI examples in repo. |

### Supported TTS Models

| Model Family | Available Models | Quality |
|-------------|-----------------|---------|
| Piper VITS | Hundreds of voices, all languages | 3-4 stars |
| Kokoro | v0.19, v1.0, multi-lang | 4-4.5 stars |
| Matcha TTS | Various languages | 3.5 stars |
| Coqui VITS | Converted Coqui models | 3.5 stars |

### Swift Integration Path

Sherpa-ONNX provides:
1. C API headers (`sherpa-onnx-c-api.h`)
2. Pre-built frameworks for macOS/iOS
3. SwiftUI example apps (TTS, STT)
4. Build scripts for macOS (`build-macOS.sh`)

Example from their iOS SwiftUI TTS demo:
```swift
// Load model
let config = sherpaOnnxOfflineTtsConfig(/* model paths */)
let tts = SherpaOnnxOfflineTts(config: config)

// Generate speech
let audio = tts.generate(text: "hello!", speed: 1.0)

// Play audio
let player = AVAudioPlayer(data: audio.toWavData())
player.play()
```

### Pros
- **Unified runtime for multiple model families** -- load Piper OR Kokoro through same API
- Swift/C API with working iOS examples
- Apache 2.0 license -- fully permissive
- Active development (v1.12.29 released March 2026)
- Supports CoreML execution provider for ANE acceleration
- Pre-built binaries available
- Can switch models at runtime -- perfect for growth stage transitions!
- Handles model loading, audio generation, and output in one library

### Cons
- C API requires some bridging work (though examples exist)
- Library + ONNX Runtime adds ~15-20MB to bundle
- Documentation is comprehensive but scattered across docs site
- Building from source requires CMake

### Verdict

**STRONG CANDIDATE as the unified runtime layer.** Rather than integrating each TTS engine separately, we use sherpa-onnx as our single TTS abstraction layer. It can load espeak-ng phonemization, Piper models, AND Kokoro models through the same API. This means our growth-stage voice system only needs one integration, swapping models as the creature evolves.

**Recommended role**: Primary TTS runtime. Wraps all our model tiers (Piper + Kokoro) in a single Swift-callable API. The only integration we need to build.

---

## 9. Option 8: espeak-ng

### Overview

espeak-ng is an open-source speech synthesizer using formant synthesis (not neural networks). It synthesizes speech by generating waveforms algorithmically, producing a distinctive robotic sound. Supports 100+ languages. Written in C.

### Quality Rating: 1.5 stars

The speech is clear and intelligible but obviously robotic. This is 1990s-era synthesis quality. However, for a creature learning to babble, this is exactly what we want.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | <10ms -- near instantaneous |
| **Binary size** | ~2MB (library + data files for one language) |
| **Model size** | N/A -- no neural model, rule-based |
| **macOS compatibility** | macOS (all versions), Homebrew available |
| **Apple Silicon** | Yes -- pure C code, compiles anywhere |
| **License** | GPL-3.0 |
| **Swift integration** | Via C library linkage (speak_lib.h API) |

### Customization -- THIS IS THE KEY FEATURE

espeak-ng's voice is highly configurable, making it perfect for creature voice design:

| Parameter | Range | Creature Use |
|-----------|-------|-------------|
| **Pitch** | 0-99 (default 50) | High pitch (80-99) = tiny creature |
| **Speed** | 20-450 wpm (default 175) | Slow (80-100) = deliberate creature speech |
| **Amplitude** | 0-200 | Quiet for whispers, loud for excitement |
| **Word gap** | 0-500ms | Long gaps = thinking creature |
| **Formant frequencies** | Fully adjustable | Alien/creature quality |
| **Voice variants** | File-based configs | Pre-built: whisper, croak, klatt |

Voice variant files can create entirely custom vocal characteristics:
- Shift formant frequencies to make alien/creature sounds
- Add breathiness, whisper, or croak effects
- Modify pitch range and contour
- Create echo effects

### The "Learning to Babble" Feature

espeak-ng can be given individual phonemes rather than words, making it perfect for babble:

```bash
# Actual word
espeak-ng "hello"

# Random phonemes (babble)
espeak-ng --ipa "bʌ dæ gɪ pʊ"

# High pitch, slow, creature-like
espeak-ng -p 85 -s 100 -v en+croak "hi!"
```

### GPL-3.0 License Consideration

espeak-ng is GPL-3.0, which means:
- If we statically link it, our app must also be GPL-3.0
- If we dynamically link (as a separate .dylib), we may have more flexibility
- Alternative: use it as a subprocess (`espeak-ng` CLI) -- no linking required
- Sherpa-onnx includes espeak-ng for phonemization and handles this

### Pros
- Incredibly small (~2MB total)
- Near-instant synthesis (<10ms)
- Extreme customizability for creature-like voices
- Can generate babble from raw phonemes
- C library with clean API
- 100+ languages
- Perfect "bad on purpose" quality for early growth stages
- espeak-ng is already used by Kokoro/Piper for phonemization

### Cons
- GPL-3.0 license (need careful integration strategy)
- Genuinely robotic sound -- not suitable for primary speech
- No neural network quality -- purely algorithmic
- Requires C bridging for Swift (but straightforward)

### Verdict

**Perfect for Drop-stage babble (20-74 commits).** espeak-ng's "robotic" quality is normally a disadvantage, but for a creature learning its first sounds, it's exactly right. The extreme customizability (pitch, formants, phoneme injection) makes it ideal for creature-like babbling. The tiny size (~2MB) and instant synthesis (<10ms) make it trivial to bundle and use.

Since Kokoro and Piper already depend on espeak-ng for phonemization (and sherpa-onnx bundles it), we get espeak-ng essentially for free as part of the Kokoro/sherpa-onnx integration.

**Recommended role**: Drop-stage babble engine. Already included via sherpa-onnx. Use its phoneme synthesis for alien/creature sounds.

---

## 10. Option 9: Kokoro-82M

### Overview

Kokoro is a lightweight TTS model with 82 million parameters. Despite its small size, it delivers speech quality comparable to much larger models. It has 54 voice presets across 8 languages. As of early 2026, it has a 44% win rate on TTS Arena V2, beating many models 10-50x its size.

This is the standout option for the Pushling's primary voice.

### Quality Rating: 4.5 stars

Natural, warm, clear speech. Slight artifacts on complex sentences, but for short creature phrases (1-5 words), quality is excellent. Voices have genuine character and expressiveness.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | <200ms for short phrases on Apple Silicon |
| **Binary size** | Via ONNX Runtime (~15MB) or MLX (~15MB) |
| **Model size** | ~80MB (ONNX q8), ~315MB (MLX safetensors), ~330MB (ONNX fp32) |
| **macOS compatibility** | macOS 11.0+ (ONNX), macOS 15.0+ (MLX Swift) |
| **Apple Silicon** | Excellent -- Metal via MLX or CoreML via ONNX |
| **License** | Apache 2.0 |
| **Swift integration** | Via sherpa-onnx (ONNX path) or kokoro-ios (MLX path) |

### ONNX Quantization Options

| Format | Size | Quality | Speed |
|--------|------|---------|-------|
| fp32 | ~330MB | Best | Baseline |
| fp16 | ~165MB | Near-best | Faster |
| q8 | ~80MB | Very good | Faster |
| q4 | ~45MB | Good | Fastest |
| q4f16 | ~45MB | Good+ | Fast |

The q8 quantization at ~80MB offers the best quality-to-size ratio. Quality degradation is minimal for short phrases.

### Voice Presets

54 voices across 8 languages. Key voices for creature design:

- Multiple male and female voices with different characters
- British and American English accents
- Voice blending: can mix two voices at arbitrary ratios
- Speed control: 0.5x to 2.0x

### Voice Customization for Creature Effect

Kokoro supports several approaches to creating a unique creature voice:

1. **Voice blending**: Mix two voices to create a unique timbre
2. **Speed modification**: 0.5x-2.0x range
3. **Post-synthesis pitch shifting**: Shift the output audio up/down
4. **Pitch morphing**: Advanced setting (0.4-1.0) for voice transformation
5. **Custom voice training**: Possible but requires significant effort

For the Pushling, the approach would be:
- Select a warm, slightly higher-pitched base voice
- Blend with a second voice for unique character
- Apply subtle pitch-up shift (+2-4 semitones) for "cute" quality
- Vary speed based on creature's emotional state

### Pros
- **Best quality-to-size ratio of any model evaluated**
- Sub-200ms latency on Apple Silicon -- reactive speech
- 82M params means fast inference even on CPU
- 54 voice presets with blending capability
- ONNX q8 model is only ~80MB -- fits our bundle budget
- Apache 2.0 license -- fully permissive
- Active development with community contributions
- Available via sherpa-onnx (ONNX) or kokoro-ios (MLX)
- Voice customization options for creature character

### Cons
- ONNX path still requires espeak-ng for phonemization (handled by sherpa-onnx)
- MLX path requires macOS 15.0+
- No built-in emotion/expression control (unlike Bark)
- Voice quality, while good, is not as expressive as Bark at its best
- For very short utterances (1 word), may have artifacts

### Verdict

**THE PRIMARY VOICE ENGINE.** Kokoro-82M is the clear winner for the Pushling's main speech capability. At ~80MB (ONNX q8), sub-200ms latency, good voice quality, and Apache 2.0 licensing, it checks every requirement. The voice blending and pitch modification capabilities allow us to create a distinctive creature voice. Available through sherpa-onnx for a clean Swift integration path.

**Recommended role**: Beast/Sage/Apex stage voice engine. The "surprise" voice that emerges when the creature grows up. Bundle the q8 ONNX model (~80MB) with the Piper low model (~16MB) for a total neural TTS footprint of ~96MB.

---

## 11. Option 10: MeloTTS

### Overview

MeloTTS by MyShell.ai is a lightweight, multi-lingual TTS model optimized for real-time CPU inference. Supports multiple English accents (American, British, Indian, Australian) plus other languages.

### Quality Rating: 3.5 stars

Clear, fast speech with reasonable naturalness. Better than Piper but below Kokoro in expressiveness.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~200-400ms on CPU |
| **Binary size** | Python runtime + dependencies |
| **Model size** | ~400MB |
| **macOS compatibility** | macOS via Python, MPS supported |
| **Apple Silicon** | Yes, via MPS |
| **License** | MIT |
| **Swift integration** | None -- Python only |

### Pros
- Fast CPU inference
- Multiple English accents
- MIT license
- Active maintenance

### Cons
- **Python-only** -- no Swift path
- **400MB model** -- larger than Kokoro q8
- Quality below Kokoro despite larger size
- Would need subprocess or embedded Python

### Verdict

**Not recommended.** Kokoro is smaller, higher quality, and has a Swift integration path. MeloTTS offers nothing that Kokoro doesn't do better.

**Recommended role**: None.

---

## 12. Option 11: NeuTTS

### Overview

NeuTTS by Neuphonic is a new on-device TTS model (2026) using GGUF quantization. Supports voice cloning and runs on CPU. Built on Qwen2 language model architecture.

### Quality Rating: 4 stars

Natural speech with voice cloning capability. Quality is good but the model is relatively new and less battle-tested.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | <1s for short phrases on mid-range CPU |
| **Binary size** | Needs llama.cpp runtime |
| **Model size** | ~400-500MB (Q4 GGUF), ~800MB (Q8 GGUF) |
| **macOS compatibility** | macOS via llama.cpp, Accelerate framework |
| **Apple Silicon** | Yes, optimized for ARM via Accelerate |
| **License** | Apache 2.0 |
| **Swift integration** | Via llama.cpp Swift bindings (indirect) |

### Pros
- Voice cloning from reference audio
- GGUF format is well-supported on Apple Silicon
- Apache 2.0 license
- On-device, no internet needed

### Cons
- **400-500MB minimum** -- too large for our budget
- **748M parameters** -- ~9x larger than Kokoro for marginal quality gain
- Requires llama.cpp integration (additional complexity)
- New and less proven than established options
- Latency (~1s) is borderline for reactive speech

### Verdict

**Not recommended for Pushling.** Too large, too complex, and marginal quality improvement over Kokoro. The GGUF/llama.cpp integration path adds unnecessary complexity when sherpa-onnx already provides a clean solution.

**Recommended role**: None. Interesting technology to watch but doesn't fit our constraints.

---

## 13. Option 12: Kokoro via MLX Swift (Native)

### Overview

The [kokoro-ios](https://github.com/mlalma/kokoro-ios) Swift package runs Kokoro TTS natively using Apple's MLX Swift framework. This is the most "Apple-native" integration path for Kokoro.

### Quality Rating: 4.5 stars (same as Kokoro -- same model)

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~100-200ms (3.3x real-time on iPhone 13 Pro, faster on Mac) |
| **Binary size** | MLX Swift framework + model loader (~20MB) |
| **Model size** | ~315MB (safetensors format) |
| **macOS compatibility** | macOS 15.0+ (Sequoia) required |
| **Apple Silicon** | Required -- MLX is Apple Silicon only |
| **License** | Apache 2.0 (assumed, based on Kokoro license) |
| **Swift integration** | Native Swift Package Manager |

### Integration

```swift
// Swift Package Manager
.package(url: "https://github.com/mlalma/kokoro-ios.git", from: "1.0.0")

// Usage (conceptual)
import KokoroSwift
let tts = KokoroTTS(modelPath: "kokoro-v1_0.safetensors")
let audio = tts.synthesize("hello!", voice: .preset("af_heart"))
```

### Pros
- Pure Swift -- no C bridging needed
- Native Metal GPU acceleration via MLX
- Swift Package Manager integration
- Potentially fastest inference (GPU-native)
- Most idiomatic for a Swift app

### Cons
- **macOS 15.0+ requirement** -- excludes older systems
- **315MB model file** -- 4x larger than ONNX q8 version
- **Apple Silicon only** -- no Intel fallback
- Less flexible than sherpa-onnx (can't load Piper models too)
- Younger project, fewer contributors
- Still depends on espeak-ng for phonemization

### Verdict

**Strong alternative to sherpa-onnx for the Kokoro layer.** If we decide macOS 15.0+ is acceptable and we don't need Piper model support in the same runtime, this is the cleanest Swift integration. However, the 315MB model size vs 80MB ONNX q8 is a significant tradeoff, and losing the ability to also load Piper models through the same API makes the sherpa-onnx path more versatile.

**Recommended role**: Alternative path if we find sherpa-onnx's C API too cumbersome. Consider if macOS 15+ is our minimum target anyway.

---

## 14. Option 13: speech-swift (Soniqo)

### Overview

[speech-swift](https://github.com/soniqo/speech-swift) is a comprehensive AI speech toolkit for Apple Silicon covering ASR, TTS, speech-to-speech, VAD, and diarization, powered by MLX and CoreML.

### Quality Rating: 4-4.5 stars

Integrates Kokoro TTS with CoreML/Neural Engine support for optimized inference.

### Technical Details

| Attribute | Value |
|-----------|-------|
| **Latency** | ~100-300ms (varies by model and execution provider) |
| **Binary size** | MLX/CoreML frameworks + model |
| **Model size** | ~315MB+ (Kokoro model) |
| **macOS compatibility** | macOS 14.0+ |
| **Apple Silicon** | Required (MLX dependency) |
| **License** | Apache 2.0 |
| **Swift integration** | Native Swift package |

### Key Feature: CoreML Neural Engine

speech-swift can run Kokoro TTS on the Neural Engine via CoreML, which:
- Frees the GPU for other work (like SpriteKit rendering!)
- Better battery efficiency
- Can run alongside other ML models without contention

This is significant because the Pushling runs a 60fps SpriteKit scene on the GPU. Running TTS on the Neural Engine avoids GPU contention.

### Pros
- CoreML/Neural Engine support -- avoids GPU contention with SpriteKit
- Comprehensive toolkit (ASR, TTS, VAD in one package)
- Native Swift
- Active development (Feb 2026 updates)
- Apache 2.0 license

### Cons
- Larger scope than we need (we only want TTS)
- Newer project, less battle-tested
- Same 315MB model size issue as other MLX paths
- macOS 14.0+ minimum

### Verdict

**Worth watching.** The CoreML Neural Engine angle is genuinely interesting -- letting TTS run on the ANE while SpriteKit uses the GPU is architecturally smart. However, the project is young, and sherpa-onnx also supports CoreML execution provider. If CoreML/ANE execution becomes important, this is the cleanest path.

**Recommended role**: Future consideration. The ANE execution concept should inform our architecture even if we use sherpa-onnx initially.

---

## 15. Comparison Matrix

### All Options at a Glance

| Option | Quality | Latency | Model Size | Bundle Size | Swift Path | License | macOS Min | Creature Voice? |
|--------|---------|---------|-----------|-------------|-----------|---------|-----------|----------------|
| AVSpeechSynthesizer | 2-4 | 50-400ms | 0-400MB* | 0 | Native | Proprietary | 10.14 | Limited pitch |
| MLX-Audio (Python) | 3-5 | 100-10s | 315MB-5GB | Huge | None (Python) | MIT/Apache | 14.0 | Via model |
| Piper TTS | 3-4 | 50-150ms | 16-113MB | ~30MB | Via sherpa-onnx | MIT | 11.0 | Post-processing |
| Coqui/XTTS-v2 | 4.5 | 200ms-5s | 2.09GB | Huge | None (Python) | MPL/LGPL | Any | Voice cloning |
| Bark | 5 | 2-30s | 1.5-5GB | Huge | None | MIT | Any | Incredible |
| VITS/VITS2 | 3-4 | 50-200ms | 15-65MB | ~30MB | Via sherpa-onnx | MIT | 11.0 | Post-processing |
| **Sherpa-ONNX** | **N/A** | **+5-10ms** | **N/A** | **~18MB** | **C/Swift** | **Apache 2.0** | **11.0** | **Loads all** |
| **espeak-ng** | **1.5** | **<10ms** | **~2MB** | **~2MB** | **C library** | **GPL-3.0** | **Any** | **Excellent** |
| **Kokoro-82M (ONNX)** | **4.5** | **<200ms** | **~80MB (q8)** | **~80MB** | **Via sherpa-onnx** | **Apache 2.0** | **11.0** | **Good** |
| MeloTTS | 3.5 | 200-400ms | ~400MB | Huge | None (Python) | MIT | Any | Limited |
| NeuTTS | 4 | ~1s | 400-500MB | ~500MB | Indirect | Apache 2.0 | Any | Voice cloning |
| kokoro-ios (MLX) | 4.5 | 100-200ms | ~315MB | ~335MB | Native Swift | Apache 2.0 | 15.0 | Good |
| speech-swift | 4-4.5 | 100-300ms | ~315MB+ | ~335MB+ | Native Swift | Apache 2.0 | 14.0 | Good |

*\*Premium voices require user download*

**Bold = recommended options**

### Decision Matrix: What Matters Most

| Criterion | Weight | Winner |
|-----------|--------|--------|
| Zero setup / just works | Critical | Bundled models (not AVSpeech premium) |
| Bundle size < 100MB | High | espeak-ng + Piper low + Kokoro q8 = ~98MB |
| Latency < 500ms | High | All recommended options meet this |
| Swift integration | High | sherpa-onnx (unified), kokoro-ios (native) |
| Creature voice character | High | espeak-ng (babble), Kokoro (speech) |
| License compatibility | Medium | Apache 2.0 (sherpa-onnx, Kokoro), MIT (Piper) |
| macOS version range | Medium | sherpa-onnx path supports macOS 11.0+ |
| GPU/ANE offloading | Low-Med | CoreML execution provider in sherpa-onnx |

---

## 16. Recommended Architecture

### The Stack

```
┌─────────────────────────────────────────────────────┐
│                 Pushling.app (Swift)                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│  VoiceManager                                       │
│  ├── stage → selects engine tier                    │
│  ├── emotion → adjusts pitch/rate/volume            │
│  ├── personality → selects voice preset             │
│  └── speak("text") → synthesize + play              │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  TTS Engine Layer (sherpa-onnx C API)               │
│  ├── Babble Tier:  espeak-ng phoneme synthesis      │
│  ├── Emerge Tier:  Piper VITS (low quality)         │
│  └── Speech Tier:  Kokoro-82M (ONNX q8)            │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Audio Post-Processing                              │
│  ├── Pitch shift (+2-4 semitones for cute)          │
│  ├── Rate adjustment (emotion-driven)               │
│  ├── Reverb (subtle, for "world" feel)              │
│  └── Volume envelope (fade in/out)                  │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  AVAudioEngine (playback)                           │
│  └── Real-time audio output                         │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Bundle Contents

| Component | Size | Purpose |
|-----------|------|---------|
| sherpa-onnx framework | ~18MB | Unified TTS runtime (includes ONNX Runtime) |
| espeak-ng data (en) | ~2MB | Phonemization + babble synthesis |
| Piper voice (en_US-amy-low) | ~16MB | Critter-stage emerging speech |
| Kokoro-82M (ONNX q8) | ~80MB | Beast/Sage/Apex primary voice |
| Kokoro voice data | ~4MB | Voice presets + blending data |
| **Total** | **~120MB** | |

### Fallback Strategy

```
Primary path:   sherpa-onnx → Kokoro/Piper/espeak-ng
Fallback:       AVSpeechSynthesizer (if sherpa-onnx fails to load)
Silent mode:    Text bubbles only (if all audio fails)
```

### Lazy Loading Strategy

Not all models need to be in memory simultaneously:

| Stage | Models Loaded | Memory |
|-------|--------------|--------|
| Spore | None | 0 |
| Drop | espeak-ng only | ~5MB |
| Critter | espeak-ng + Piper | ~30MB |
| Beast+ | Kokoro only (unload Piper) | ~100MB |

### GPU/ANE Considerations

The Pushling runs SpriteKit at 60fps on the GPU. TTS must not cause frame drops.

- **sherpa-onnx ONNX Runtime**: CPU by default. Fast enough for short phrases.
- **CoreML execution provider**: Can route to ANE, freeing GPU entirely.
- **Recommendation**: Use CPU inference initially. Profile. If it causes frame drops during synthesis, enable CoreML/ANE execution.

Since TTS generates audio in a single burst (not streaming), the ~100-200ms synthesis can happen on a background thread without affecting the render loop.

---

## 17. Voice Character Design

### The Pushling Voice Identity

The creature's voice should feel:
- **Small**: Higher-pitched than adult human speech
- **Warm**: Not cold or robotic (at higher stages)
- **Distinct**: Uniquely "Pushling" -- not generic TTS
- **Emotional**: Pitch and rate vary with mood
- **Consistent**: Same base character across sessions

### Per-Stage Voice Design

#### Drop Stage: Babble (espeak-ng)
```
Engine: espeak-ng
Pitch: 85-95 (of 0-99 range, very high)
Speed: 80-120 wpm (slow, deliberate)
Voice variant: custom creature formant file
Content: Random phoneme sequences, occasional real phonemes
Example: "buh!" "nnn-dah!" "puh puh!" "...mmmm"
Frequency: 1-2 babbles per minute during active states
```

#### Critter Stage: Emerging Words (Piper low)
```
Engine: Piper (en_US-amy-low or similar)
Post-processing: Pitch +4 semitones, slight speed increase
Content: Single words, 30% babble mixed in
Example: "hi!" "food!" "...buh... happy!" "sleepy..."
Frequency: 1-3 words per 5 minutes
```

#### Beast Stage: Clear Speech (Kokoro)
```
Engine: Kokoro-82M q8
Voice: Warm preset, blended for unique character
Post-processing: Pitch +2-3 semitones, emotion-driven rate
Content: Short phrases, reactions, greetings
Example: "morning!" "that was yummy!" "love this code!"
Frequency: Contextual -- reacts to events
```

#### Sage Stage: Expressive (Kokoro, tuned)
```
Engine: Kokoro-82M q8
Voice: Same base, slightly lower pitch than Beast
Post-processing: Pitch +1-2 semitones, wider pitch range
Content: Longer phrases, observations, wisdom
Example: "Ah, a fine refactor." "The stars are bright tonight."
Frequency: More frequent, more varied
```

#### Apex Stage: Full Range (Kokoro + effects)
```
Engine: Kokoro-82M q8 with dynamic voice switching
Voice: Multiple presets, emotion-selected
Post-processing: Dynamic pitch, reverb on whispers, echo on shouts
Content: Full sentences, meta-awareness, singing
Example: "You're watching me, aren't you?" *whispers* "our secret"
Frequency: Rich and varied, context-driven
```

### Emotion-to-Voice Mapping

| Emotion State | Pitch Shift | Rate | Volume | Extra |
|--------------|------------|------|--------|-------|
| Happy | +2 semitones | 1.1x | 0.8 | Slightly breathier |
| Excited | +3 semitones | 1.3x | 0.9 | Quick attack |
| Sad | -1 semitone | 0.8x | 0.5 | Slower, quieter |
| Sleepy | -2 semitones | 0.6x | 0.3 | Very slow, soft |
| Hungry | Normal | 0.9x | 0.7 | Slight tremolo |
| Scared | +4 semitones | 1.4x | 0.6 | Quick, breathy |
| Blissful | +1 semitone | 0.9x | 0.6 | Warm, smooth |
| Hangry | -1 semitone | 1.2x | 0.9 | Sharper attack |

### Personality-to-Voice Mapping

The creature's personality (from git patterns) subtly affects its voice:

| Personality Trait | Voice Effect |
|------------------|-------------|
| High Energy | Faster default rate, wider pitch variance |
| Low Energy | Slower, steadier, narrower pitch |
| High Verbosity | More frequent speech, longer phrases |
| Low Verbosity | Rare speech, single words, more babble even at high stages |
| Systems specialty | Slightly deeper, more precise articulation |
| Web Frontend | Brighter, more varied pitch |

---

## 18. Implementation Roadmap

### Phase 1: Foundation (espeak-ng babble)
1. Integrate sherpa-onnx framework into Xcode project
2. Load espeak-ng for phonemization (needed by all models anyway)
3. Implement VoiceManager with stage-awareness
4. Create creature babble using espeak-ng phoneme synthesis
5. Hook babble to Drop-stage creature events
6. Basic audio playback via AVAudioEngine

### Phase 2: First Words (Piper)
1. Bundle one Piper low-quality voice model (~16MB)
2. Load Piper model at Critter stage transition
3. Implement word selection from commit messages and emotion vocabulary
4. Mix babble and real words (configurable ratio per sub-stage)
5. Add pitch shifting post-processing

### Phase 3: True Speech (Kokoro)
1. Bundle Kokoro-82M ONNX q8 model (~80MB)
2. Load Kokoro at Beast stage transition (unload Piper to save memory)
3. Design creature voice blend from Kokoro presets
4. Implement emotion-to-voice mapping
5. Add the "first clear speech" ceremony -- this is the wow moment
6. Connect speech to surprise system, commit reactions, greetings

### Phase 4: Expression (Polish)
1. Implement personality-to-voice mapping
2. Add Sage/Apex voice variations
3. Implement whisper, exclaim, and other vocal modes
4. Add subtle reverb/effects processing
5. Tune timing and frequency of speech
6. AVSpeechSynthesizer fallback for edge cases

### Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Synthesis latency | <200ms for 1-5 words | Background thread, no frame drops |
| Audio playback start | <50ms after synthesis | Pre-buffered AVAudioEngine |
| Memory (models loaded) | <100MB peak | Lazy load, unload unused models |
| SpriteKit frame impact | 0 dropped frames | TTS on background thread |
| Bundle size (TTS total) | <120MB | sherpa-onnx + espeak + Piper + Kokoro |

---

## Appendix A: License Summary

| Component | License | Commercial Use | Linking Concern |
|-----------|---------|---------------|----------------|
| sherpa-onnx | Apache 2.0 | Yes | None |
| ONNX Runtime | MIT | Yes | None |
| Kokoro-82M | Apache 2.0 | Yes | None |
| Piper | MIT | Yes | None |
| espeak-ng | GPL-3.0 | Yes* | *Via sherpa-onnx (Apache 2.0 wrapper). Sherpa-onnx handles the GPL boundary. |
| AVSpeechSynthesizer | Apple proprietary | Yes (in macOS apps) | None |

Note: sherpa-onnx includes espeak-ng for phonemization and is distributed under Apache 2.0. The sherpa-onnx project has addressed GPL compatibility -- espeak-ng is used as a separate component for text processing, not linked into the core library in a way that would require the entire project to be GPL.

## Appendix B: Key Repository Links

- sherpa-onnx: https://github.com/k2-fsa/sherpa-onnx
- Kokoro ONNX models: https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX
- Piper voices: https://github.com/rhasspy/piper
- kokoro-ios (MLX Swift): https://github.com/mlalma/kokoro-ios
- mlx-audio-swift: https://github.com/Blaizzy/mlx-audio-swift
- speech-swift: https://github.com/soniqo/speech-swift
- espeak-ng: https://github.com/espeak-ng/espeak-ng

---

*The Pushling starts silent. Then it babbles. Then it speaks its first word. Then one day it says "good morning" and you realize: it learned. You taught it. Every commit was a lesson. And it needed zero setup -- the voice was always there, waiting for enough commits to unlock it.*
