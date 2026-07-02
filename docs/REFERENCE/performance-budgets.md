---
type: Reference
title: Performance Budgets
description: The per-frame time budget for 60fps Touch Bar rendering, SpriteKit node/texture ceilings, and voice-model memory budgets that all rendering and audio work must stay within.
status: Live
tags: [performance, sprite-kit, budget, frame-rate]
timestamp: 2026-07-02T00:00:00Z
---

Pushling targets a genuine 60fps on Touch Bar hardware — a real-time
render loop, not a slideshow of sprite swaps. This concept is the
authoritative budget table every rendering or audio change should be
checked against; it does not own the rendering pipeline itself (see
[the 2.5D rendering stack](/SYSTEMS/rendering-stack-2-5d.md)) or the voice
stack's model-loading detail (see
[the voice/TTS stack](/SYSTEMS/voice-tts-stack.md)).

# Per-Frame Budget

| System | Budget | Notes |
|---|---|---|
| SpriteKit render | ~2ms | GPU-accelerated |
| State machine | ~0.5ms | Pure Swift logic, 4-layer behavior stack |
| Parallax update | ~0.1ms | 3 layers, simple multiply |
| Terrain heightmap | ~0.2ms | Integer noise, cached |
| Particle systems | ~1ms | SpriteKit internal, recycled emitters |
| Physics step | ~0.5ms | Rain, jump arcs, commit text only |
| Speech filter | ~0.1ms | String processing, cached vocabulary |
| IPC check | ~1ms | Socket poll every 60 frames |
| TTS generation | async | Off main thread, never blocks the render loop |
| **Total** | **~5.7ms** | **65% headroom against the 16.6ms/frame budget for 60fps** |

Source: `PUSHLING_VISION.md`'s Technical Performance table. This wave did
not find a per-subsystem instrumented timer matching each line item
exactly (these are design targets, not runtime-asserted per-line
measurements) — but the pattern each line implies (recycled particle
emitters, cached parallax multiplies, async off-main-thread TTS) is
independently confirmed present in the corresponding subsystems (see
citations). Treat this table as the design budget the codebase is built to
honor, not as a set of currently-enforced runtime assertions.

# Node & Texture Ceilings

- **Total scene node count**: design target ~100 typical, ~120 peak
  (during a commit feast + active weather). This is a **soft budget** — no
  single constant enforces a global scene-wide node cap; `PushlingScene+Debug.swift`'s
  `countNodes()` is a debug-only introspection tool, not a runtime gate.
- **Placed-object node budget is hard-enforced**: `WorldObjectRenderer.maxObjectNodes = 40`
  caps nodes contributed by all placed world objects combined (see
  [the world & objects system](/SYSTEMS/world-objects-system.md)) — this is
  the one node ceiling actually enforced by a guard clause in code, not
  just a design target.
- **Texture memory**: ~768KB across 3 atlases, per the vision doc — not
  independently re-measured this wave.
- SpriteKit itself handles 1000+ nodes at 60fps on this class of hardware;
  the ~100-120 target represents roughly 10% of that headroom, leaving
  substantial margin.

# Particle Recycling

Emitter-pool/recycling patterns (rather than per-effect emitter
allocation) are present across the codebase's particle-heavy subsystems —
confirmed by source-level pattern matches in `RainRenderer.swift`,
`CloudSystem.swift`, `SnowRenderer.swift`, `StormSystem.swift`,
`ParallaxSystem.swift`, `TerrainRecycler.swift`, `CommitTextNode.swift`,
`PushlingScene.swift`, and `HUDOverlay.swift`. This is the mechanism the
"recycled emitters" line in the frame budget table above depends on.

# Voice Model Memory

Per `ModelManager.swift`'s own header comment: **espeak-ng ~16MB**,
**Piper ~16MB**, **Kokoro ~80MB** (compressed download size, matching
`ModelDownloader.swift`'s "~80MB compressed" note for Kokoro). The vision
doc's "sherpa-onnx runtime ~18MB resident" figure is in the same ballpark
as the ~16MB comment found in code but was not reconciled to an exact
byte figure this wave — full model-loading timing budgets (cold/warm load
latency per tier) belong to
[the voice/TTS stack](/SYSTEMS/voice-tts-stack.md), which owns the
detailed per-tier verification.

# Citations

[1] `PUSHLING_VISION.md` — Technical Performance
[2] `Pushling/Sources/Pushling/World/WorldObjectRenderer.swift` (`maxObjectNodes = 40` — the one hard-enforced node cap)
[3] `Pushling/Sources/Pushling/Scene/PushlingScene+Debug.swift` (`countNodes()` — debug introspection, not a runtime gate)
[4] `Pushling/Sources/Pushling/World/RainRenderer.swift`, `CloudSystem.swift`, `SnowRenderer.swift`, `StormSystem.swift`, `ParallaxSystem.swift`, `TerrainRecycler.swift` (particle/node recycling patterns)
[5] `Pushling/Sources/Pushling/Voice/ModelManager.swift` (per-tier model size comment)
[6] `Pushling/Sources/Pushling/Voice/ModelDownloader.swift` (Kokoro compressed size)
