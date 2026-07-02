---
type: System
title: 4-Layer Behavior Stack
description: The Physics > Reflexes > AI-Directed > Autonomous priority stack that resolves into one creature pose every frame, and the blend controller that smooths every transition between them.
status: Live
tags: [behavior, animation, blend, physics, reflexes, ai-directed]
timestamp: 2026-07-02T00:00:00Z
---

`BehaviorStack` (`Pushling/Sources/Pushling/Behavior/BehaviorStack.swift`)
is the single source of truth for creature visual state, called once per
frame from `PushlingScene.update()` and required to complete in under 1ms.
It is the mechanical implementation of the philosophy in
[the vision concept](/vision.md#the-dual-layer-embodiment-model): Layer 1
(Physics + Reflexes + Autonomous) is the nervous system that never stops;
Layer 3 (AI-Directed) is Claude's mind, active only while inhabiting the
creature. This concept covers the priority resolution and blend timing
built and shipped; the command-queue semantics that were *designed* for
Layer 3 but never built are documented separately in
[the AI command queue](/SYSTEMS/ai-command-queue.md) to avoid minting
unverified prescriptive contract here.

# The Four Layers

Each layer implements `BehaviorLayer.update(deltaTime:currentTime:) ->
LayerOutput` independently, every frame, regardless of whether higher
layers will end up overriding it — a lower layer's computation never stops
just because a higher layer currently wins.

| Priority | Layer | Source | Duration | Example |
|---|---|---|---|---|
| 1 (highest) | **Physics** | Daemon core (`PhysicsLayer`) | Always | Breathing sine-wave, gravity, boundary enforcement |
| 2 | **Reflexes** | Input events (`ReflexLayer`) | 0.5–3.0s per reflex | Ear perk on commit, flinch on force push |
| 3 | **AI-Directed** | Claude's MCP commands (`AIDirectedLayer`) | Until complete or 30s timeout | Walk to center, speak, express joy |
| 4 (lowest) | **Autonomous** | Daemon's own state machine (`AutonomousLayer`) | Continuous default | Wander, blink, groom, explore, loaf |

**Resolution rule, per-property:** for every property in `LayerOutput`
(position, facing, walk speed, and each body-part semantic state),
`BehaviorStack.resolveOutputs()` picks the **highest-priority layer whose
value for that property is non-nil**, falling through
`physics ?? reflexes ?? ai ?? autonomous ?? stageDefault`. A `nil` means "I
have no opinion — defer to the layer below me," so two layers can each own
different properties simultaneously (e.g. the Reflex layer overrides only
ear state while the AI-Directed layer still owns walk speed and position).
This per-property merge — not a single "which layer is active" switch — is
the actual mechanism behind the vision doc's "human touch always wins"
claim: a touch-triggered reflex overriding `earLeftState`/`earRightState`
takes effect immediately regardless of what Layer 3 (AI-Directed) is doing
with position or speech that same frame, with no special-cased touch/AI
arbitration code required.

## Layer 1: Physics

Always running, never suppressed even during a cinematic freeze — breathing
continues literally always. Computes gravity, boundary detection
(`nearBoundary()`, which the stack uses to tell the Autonomous layer to
turn around), and jump arcs. Owns the `breathingScale` output, which
bypasses the blend controller entirely and applies directly to the
creature's Y-scale every frame — the one animation that is never
interpolated because it must never visibly pause.

## Layer 2: Reflexes

`ReflexLayer` holds up to 5 simultaneous `ActiveReflex` instances (oldest
evicted past that), each an instance of a pre-defined `ReflexDefinition`
(name, duration 0.5–3.0s, a `fadeoutFraction` — typically 0.2 — of that
duration spent blending its override back toward nil, and the `LayerOutput`
properties it overrides). `ear_perk` (0.8s duration) and `flinch` are two
named reflexes defined in code; reflexes are triggered via
`BehaviorStack.triggerReflex(named:at:)`, called by `CreatureTouchHandler`
(e.g. `"ear_perk"` and `"look_at_touch"` on touch events) and by commit
processing. There is no separate "500ms lease" constant in code — each
reflex's own `duration` field governs how long it holds priority, and its
own `blendFactor` (1.0 during the active portion, ramping to 0.0 during the
trailing fadeout fraction) governs the smoothness of its release, not a
single universal lease timer.

## Layer 3: AI-Directed

`AIDirectedLayer` runs a state machine with four states: `inactive`,
`executing`, `standby(idleTime:)`, `fadingOut(elapsed:)`. Commands
(`AICommand`: id, `AICommandType` — walk/speak/express/perform/look/idle —
a `LayerOutput`, a `holdDuration`, an enqueue timestamp) are appended to a
plain FIFO array via `BehaviorStack.enqueueAICommand()`; see
[the AI command queue concept](/SYSTEMS/ai-command-queue.md) for exactly
what this array does and does not do relative to the originally-designed
spec.

**Verified constants** (`AIDirectedLayer.swift`):

| Constant | Value | Effect |
|---|---|---|
| `timeoutDuration` | 30.0s | Seconds of no new command before fadeout begins |
| `fadeoutDuration` | 5.0s | Duration of the gradual release back to Autonomous |
| `warmStandbyMild` | 10.0s | After this much idle time, walk speed begins reducing toward 0 (floor 0.3× at the moderate threshold) |
| `warmStandbyModerate` | 20.0s | After this, walk-speed override clears entirely, ceding speed to Autonomous |

During `fadingOut`, properties release in a staggered order rather than all
at once, matching the vision doc's "gradual softening" framing exactly:
walk speed holds through 60% of the 5.0s fadeout (3s), all body-part
expression states hold through 40% (2s), and position/facing hold longest,
through 80% (4s) — so a walking, expressive AI-directed action visibly
slows first, stops "meaning" anything expressively next, and only loses its
spot in space last.

## Layer 4: Autonomous

`AutonomousLayer` runs a state machine (`walking`, `idle`,
`behavior(name:)`, `taughtBehavior(name:)`, `objectInteracting(objectID:)`,
`resting`, `dreaming`) driven by `BehaviorSelector`'s weighted random
selection, gated by the current `GrowthStage` (via `stage.baseWalkSpeed`/
`baseRunSpeed`, defined per-stage in `GrowthStage` — see
[growth stages](/REFERENCE/growth-stages.md)) and modulated by the current
`PersonalitySnapshot`/`EmotionalSnapshot` and any active
[emergent state](/REFERENCE/personality-emotional-state.md#emergent-states).
Always computing, even while a higher layer is fully in control — this is
what lets the "AI releases control" fadeout hand off smoothly instead of
needing to spin the Autonomous layer up cold.

# The Blend Controller

`BlendController` never lets the resolved per-frame state snap
instantaneously; it interpolates per-property, tracking independent
`PropertyBlend`s so different body parts can be mid-transition
simultaneously. Verified transition durations
(`Pushling/Sources/Pushling/Behavior/LayerTypes.swift` `BlendTransitionType`,
cross-checked against `BlendController.swift`):

| Transition | Duration | Mechanism |
|---|---|---|
| **Direction reversal** | 0.433s total | 4-phase state machine: decelerate to 0 (0.15s, ease-out) → pause 2 frames (~0.033s) → flip facing → accelerate to target speed (0.25s, ease-in) |
| **Expression change** | 0.8s base | Per-body-part crossfade with independent sub-timing: ears lead at 0.2s, eyes 0.15s, mouth/body 0.3s, tail/aura 0.5s, whiskers 0.1s — all scaled by `PersonalityFilter.animationTempo()` (energetic creatures transition faster) |
| **Reflex interrupt** | 0.15s total | Cascading snap, NOT tempo-scaled (must stay consistently fast regardless of personality): ears at 0s, eyes/whiskers at 0.05s, body/tail/mouth/aura at 0.10s, each a further 0.05s ramp |
| **AI takes control** | 0.3s | Ease-in |
| **AI releases control** | 5.0s | Ease-out, matching `AIDirectedLayer`'s `fadeoutDuration` above |

Position is blended separately from body-part states: while walking,
position advances by `currentWalkSpeed × facing`; a large discrepancy
between the blended position and a directly-requested position (e.g. an AI
`walk`-to-target command) is closed by lerp at a rate that's faster during
an active AI-takeover transition (0.3s time-constant) than otherwise
(0.1s). A reflex interrupt can preempt an in-flight lower-priority
transition, but a lower-priority transition cannot preempt an in-flight
reflex interrupt before its own 0.15s completes — the one explicit
priority rule inside the blend controller itself, separate from the layer
resolution priority above.

# External API Surface

Callers outside the stack (`CommandRouter`/`ActionHandlers` for MCP
commands, `CreatureTouchHandler` for touch, `GameCoordinator` for habits and
mutation-badge reactions) interact through:
`triggerReflex(_:at:)` / `triggerReflex(named:at:)`, `enqueueAICommand(_:)`,
`cancelAICommands()`, `aiSessionEnded()`, `setSleeping(_:)`,
`startJump(initialVelocity:)`, `updateStage(_:)`,
`freezeForCinematic()`/`thawFromCinematic()` (used for scripted sequences —
suppresses Autonomous transitions and clears Reflexes, but Physics/breathing
always continues even here), and `reset(stage:position:facing:)`.

# Citations

[1] `Pushling/Sources/Pushling/Behavior/BehaviorStack.swift`
[2] `Pushling/Sources/Pushling/Behavior/BlendController.swift`
[3] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`GrowthStage`, `LayerOutput`, `BlendTransitionType`, `Easing`)
[4] `Pushling/Sources/Pushling/Behavior/PhysicsLayer.swift`
[5] `Pushling/Sources/Pushling/Behavior/ReflexLayer.swift`
[6] `Pushling/Sources/Pushling/Behavior/AIDirectedLayer.swift`
[7] `Pushling/Sources/Pushling/Behavior/AutonomousLayer.swift`
[8] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (reflex trigger call sites)
[9] `PUSHLING_VISION.md` — Control Architecture: The 4-Layer Behavior Stack; The Blend Controller; Touch-AI Interaction Priority
