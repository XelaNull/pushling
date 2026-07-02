---
type: Research Note
title: Local TTS Engine Evaluation (2026-03)
description: Point-in-time comparison of 13 on-device TTS options — quality, latency, size, license, and Swift-integration path — recording why sherpa-onnx + espeak-ng/Piper/Kokoro-82M won and why the alternatives were rejected or deferred.
status: Current
tags: [research, voice, tts, decision-record]
timestamp: 2026-07-02T00:00:00Z
---

Migrated from `docs/TTS-RESEARCH.md` (compiled 2026-03-14), which evaluated
11 named options across 15 numbered sections (two additional native-Swift
variants were folded in as options 12–13). This is a historical decision
record — it explains *why* the architecture in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) looks the way it does. Where
this note's technical specs (model sizes, license terms) differ from what
actually shipped, [voice-tts-stack](/SYSTEMS/voice-tts-stack.md) is
authoritative for current reality; this note is preserved as-evaluated,
un-corrected, since its value is as a record of the decision process itself.

# The Constraint Set

Zero API keys, zero cloud services, fully on-device, Apple Silicon macOS.
Target: bundle size under 100MB, latency under 500ms for 1–5 word creature
utterances, a working Swift integration path, and a permissive license.

# Option-by-Option Summary

| # | Option | Quality | Latency | Model size | Swift path | License | macOS min | Verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | `AVSpeechSynthesizer` | 2–4★ | 50–400ms | 0–400MB (premium, user-downloaded) | Native | Proprietary | 10.14 | Fallback candidate only — quality unreliable, premium voices need manual user action |
| 2 | Apple MLX / Core ML (mlx-audio) | 3–5★ | 100ms–10s | 315MB–5GB | Via `mlx-audio-swift` / `kokoro-ios` | MIT/Apache 2.0 | 14.0 | Strong Kokoro path but larger model than ONNX q8; compared against option 7 below |
| 3 | Piper TTS | 3–4★ | 50–150ms | 16–113MB per voice | Via sherpa-onnx or C bridge | MIT | 11.0/13.0 | **Winner** — Critter-stage engine, low-quality (~16MB) model is "recognizable but still learning" by design |
| 4 | Coqui TTS / XTTS-v2 | 4.5★ | 200ms–5s | 2.09GB | None (Python only) | MPL-2.0/LGPL | any | Rejected — model far too large, no Swift path, company shut down Dec 2025 |
| 5 | Bark (Suno) | 5★ | 2–30s | 1.5–5GB | None (MLX port experimental) | MIT | any | Rejected — latency alone disqualifying (30s response to a 1-word phrase) |
| 6 | VITS / VITS2 | 3–4★ | 50–200ms | 15–65MB | Via sherpa-onnx | MIT | 11.0 | Subsumed by Piper (which wraps VITS) and Kokoro |
| 7 | **Sherpa-ONNX** | N/A (runtime) | +5–10ms overhead | depends on loaded model | C/Swift, working iOS examples | Apache 2.0 | 11.0 | **Winner — the unified runtime.** Loads Piper, Kokoro, and espeak-ng phonemization through one API; can switch models at runtime for stage transitions |
| 8 | **espeak-ng** | 1.5★ | <10ms | ~2MB (upstream) | C library linkage | GPL-3.0 (isolated via sherpa-onnx's Apache 2.0 wrapper) | any | **Winner — Drop-stage babble.** Deliberately robotic; extreme customizability (pitch/formant/phoneme injection) is exactly right for a creature's first sounds |
| 9 | **Kokoro-82M (ONNX)** | 4.5★ | <200ms | ~80MB (q8) | Via sherpa-onnx | Apache 2.0 | 11.0 | **Winner — the primary voice.** Best quality-to-size ratio evaluated; 54 voice presets with blending |
| 10 | MeloTTS | 3.5★ | 200–400ms | ~400MB | None (Python only) | MIT | any | Rejected — Kokoro is smaller, higher quality, has a Swift path |
| 11 | NeuTTS | 4★ | ~1s | 400–800MB | Indirect (llama.cpp) | Apache 2.0 | any | Rejected — too large, marginal quality gain over Kokoro |
| 12 | Kokoro via MLX Swift (`kokoro-ios`) | 4.5★ (same model as #9) | 100–200ms | ~315MB | Native Swift Package | Apache 2.0 (assumed) | 15.0 | Alternative to #7 if macOS 15+ becomes the floor; loses Piper-in-same-runtime versatility |
| 13 | speech-swift (Soniqo) | 4–4.5★ | 100–300ms | ~315MB+ | Native Swift | Apache 2.0 | 14.0 | Worth watching for its CoreML/Neural-Engine execution (frees the GPU from SpriteKit contention) — young project, not adopted |

# Decision Matrix

| Criterion | Weight | Winner |
|---|---|---|
| Zero setup / just works | Critical | Bundled models (not `AVSpeechSynthesizer` premium voices) |
| Bundle size < 100MB | High | espeak-ng + Piper low + Kokoro q8 ≈ ~98MB (as evaluated; see [voice-tts-stack](/SYSTEMS/voice-tts-stack.md) for the shipped download-on-demand reality) |
| Latency < 500ms | High | All recommended options meet this |
| Swift integration | High | sherpa-onnx (unified), kokoro-ios (native) |
| Creature voice character | High | espeak-ng (babble), Kokoro (speech) |
| License compatibility | Medium | Apache 2.0 (sherpa-onnx, Kokoro), MIT (Piper) |
| macOS version range | Medium | sherpa-onnx path supports macOS 11.0+ |
| GPU/ANE offloading | Low–Medium | CoreML execution provider available in sherpa-onnx |

# Bundle Contents (As Evaluated)

| Component | Size | Purpose |
|---|---|---|
| sherpa-onnx framework | ~18MB | Unified TTS runtime (includes ONNX Runtime) |
| espeak-ng data (en) | ~2MB | Phonemization + babble synthesis |
| Piper voice (`en_US-amy-low`) | ~16MB | Critter-stage emerging speech |
| Kokoro-82M (ONNX q8) | ~80MB | Beast/Sage/Apex primary voice |
| Kokoro voice data | ~4MB | Voice presets + blending data |
| **Total (as evaluated)** | **~120MB** | |

The as-shipped reality (download-on-demand, not bundled; different per-tier
size accounting) is documented in
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) — this table reflects the
proposal at the time of evaluation.

# Recommended Architecture (As Proposed)

```
Pushling.app (Swift)
├─ VoiceManager: stage → engine tier, emotion → pitch/rate/volume, personality → voice preset
├─ TTS Engine Layer (sherpa-onnx C API)
│   ├─ Babble tier:  espeak-ng phoneme synthesis
│   ├─ Emerge tier:  Piper VITS (low quality)
│   └─ Speech tier:  Kokoro-82M (ONNX q8)
├─ Audio Post-Processing: pitch shift, rate adjustment, subtle reverb, volume envelope
└─ AVAudioEngine (playback)
```

Lazy loading was proposed by stage (`Spore`: none loaded, 0MB; `Drop`:
espeak-ng only, ~5MB; `Critter`: espeak-ng + Piper, ~30MB; `Beast+`: Kokoro
only, ~100MB, Piper unloaded) — see
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md) for the shipped tier-switching
mechanism, which follows this pattern closely (unload-then-load on stage
change rather than keeping multiple tiers resident).

# Performance Targets (As Proposed)

| Metric | Target |
|---|---|
| Synthesis latency | <200ms for 1–5 words, on a background thread |
| Audio playback start | <50ms after synthesis, pre-buffered `AVAudioEngine` |
| Memory (models loaded) | <100MB peak, lazy-loaded, unused models unloaded |
| SpriteKit frame impact | 0 dropped frames — TTS entirely off the main thread |
| Bundle size (TTS total) | <120MB |

# License Summary

| Component | License | Commercial use | Linking concern |
|---|---|---|---|
| sherpa-onnx | Apache 2.0 | Yes | None |
| ONNX Runtime | MIT | Yes | None |
| Kokoro-82M | Apache 2.0 | Yes | None |
| Piper | MIT | Yes | None |
| espeak-ng | GPL-3.0 | Yes* | *Via sherpa-onnx (Apache 2.0 wrapper) — sherpa-onnx uses espeak-ng as a separate text-processing component, not linked in a way that would require the whole project to be GPL |
| `AVSpeechSynthesizer` | Apple proprietary | Yes (in macOS apps) | None |

# Key Repository Links

- sherpa-onnx: https://github.com/k2-fsa/sherpa-onnx
- Kokoro ONNX models: https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX
- Piper voices: https://github.com/rhasspy/piper
- kokoro-ios (MLX Swift): https://github.com/mlalma/kokoro-ios
- mlx-audio-swift: https://github.com/Blaizzy/mlx-audio-swift
- speech-swift: https://github.com/soniqo/speech-swift
- espeak-ng: https://github.com/espeak-ng/espeak-ng

# Citations

[1] `docs/TTS-RESEARCH.md` (source document, compiled 2026-03-14)
[2] [voice-tts-stack](/SYSTEMS/voice-tts-stack.md) — the shipped architecture this research led to
