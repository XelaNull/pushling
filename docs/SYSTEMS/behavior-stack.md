---
type: System
title: 4-Layer Behavior Stack
description: The Physics > Reflexes > AI-Directed > Autonomous priority stack that resolves into one creature pose every frame, and the blend controller that smooths every transition between them. Also documents where Posture Vocabulary and the Idle Micro-Behavior Scheduler sit relative to this priority resolution, generalizes the reflex-injection ("checkpoint/resume") mechanism reused by surprises, glances, and sky reactions, and documents the shipped `BehaviorSelector` weight formula — a registry distinct from the AI-Directed manual-perform `CatBehavior` one, with a code-verified defect (`tongue_blep`'s mouth doesn't exist pre-Beast at either registry's own minimum stage).
status: Live
tags: [behavior, animation, blend, physics, reflexes, ai-directed, posture, idle-scheduler, reflex-injection, behavior-selector]
timestamp: 2026-07-03T00:00:00Z
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

This concept's own output — one fully-resolved `ResolvedCreatureState` per
frame — is a complete contract, but it is not the same thing as a rendered
creature: what happens to that state downstream is out of scope here and
owned by two sibling concepts. [Body pose & compose](/SYSTEMS/body-pose-pipeline.md)
owns whether `bodyState`/`positionY`/`auraState` actually reach the torso —
today, `PushlingScene.applyBehaviorOutput` applies only `positionX`,
`facing`, and the appendage-controller states from what this stack
resolves, so the rest is computed correctly here and then silently dropped
one function later (see [that concept's dropped-wire
findings](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)
for the exact citations). [Emotional body
language](/SYSTEMS/emotional-body-language.md) owns a posture-vocabulary
modifier that rides that pipeline's compose point *after* this stack has
already picked its per-property winner — see [Posture Vocabulary, below](#posture-vocabulary--a-modifier-outside-the-priority-stack),
it is explicitly not a fifth priority layer competing with the four below.

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
properties it overrides). Four named reflexes are defined in code —
`ear_perk` (0.8s), `flinch` (1.5s), `look_at_touch` (1.0s), and `startle`
(0.5s) — triggered via `BehaviorStack.triggerReflex(named:at:)`, called by
`CreatureTouchHandler` (e.g. `"ear_perk"` and `"look_at_touch"` on touch
events) and by commit processing. `triggerReflex(_:at:)` (the underlying
general form, taking a `ReflexDefinition` directly rather than a name) is
not limited to these four — see [Generalized Reflex
Injection](#generalized-reflex-injection--one-bridge-for-surprises-glances-and-sky-reactions)
below for the mechanism every surprise, and every future glance/sky
reaction, actually uses. There is no separate "500ms lease" constant in code — each
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

### The Shipped Weight-Based Selection Formula (code-verified, previously undocumented)

`BehaviorSelector` (one instance per `BehaviorStack`, constructed at
`BehaviorStack.swift:111`) is a second, independent registry from the
`CatBehavior` one the [12 Cat Behaviors](#the-12-cat-behaviors) table below
documents — same 12 names (plus a 13th, Sage-only `meditation`, see
[idle & rest's stage-gating table](/SYSTEMS/idle-life-and-rest.md#21-stage-gating)
for the behavior itself), but a different struct with different numbers,
and it is what `AutonomousLayer.updateIdle` actually calls
(`behaviorSelector.selectBehavior(stage:personality:emotions:)`,
`AutonomousLayer.swift:415`) every idle→behavior transition. Its own
weighted-random pick is documented in the file's own header comment
(`BehaviorSelector.swift:9-16`) and implemented in `calculateWeight()`
(`BehaviorSelector.swift:406-429`):

```
weight = baseWeight
       × personalityAffinity   (0.5–2.0, category → one PersonalityAxis, lerped)
       × emotionalBoost        (1.0–1.5, category → one EmotionalSnapshot axis)
       × recencyPenalty        (0.3 / 0.6 / 1.0, by time since last performed)
       × noveltyBonus          (1.5× flat while performanceCount < 3)
```

floored at `max(weight, 0.01)` so no eligible behavior ever hits exactly
zero (`BehaviorSelector.swift:428`). Eligibility itself is gated ahead of
weighting by `stageMin`, per-behavior `cooldown` (personality-modulated, see
below), an optional `EmotionalCondition`, and a **global 30s cooldown**
(`globalCooldown`, `BehaviorSelector.swift:130`) between any two autonomous
behaviors regardless of which ones — `selectBehavior` returns `nil` (falls
back to `.walking`) if that floor hasn't elapsed, before it even builds the
eligible pool.

**`personalityAffinity`** (`affinityMap`, `BehaviorSelector.swift:277-308`)
maps each of the 6 `BehaviorCategory` values to one personality axis and a
`[low, high]` multiplier range, lerped by that axis's current 0–1 value:

| Category | Axis | Low (axis→0) | High (axis→1) |
|---|---|---|---|
| `playful` | energy | 0.5 | 2.0 |
| `calm` | energy | 2.0 | 0.5 |
| `social` | verbosity | 0.7 | 1.5 |
| `investigative` | focus | 0.7 | 1.5 |
| `mischievous` | discipline | 1.8 | 0.5 |
| `ritualistic` | discipline | 0.7 | 1.5 |

**`emotionalBoost`** (`BehaviorSelector.swift:432-456`) scales per-category
against one `EmotionalSnapshot` axis: `playful`→energy, `calm`→contentment,
`social`→satisfaction, `investigative`→curiosity, and `ritualistic`→
contentment again but capped at **1.3×** (`× 0.3`, not the `× 0.5` every
other category uses — a real asymmetry in the formula, not a typo to
normalize away). `mischievous` is the one non-linear case: it boosts only
when high energy *and* low satisfaction align jointly
(`energyFactor × satFactor`, both 0–1), so a mischievous behavior needs both
conditions at once to approach its own 1.5× ceiling — a satisfied creature
gets little mischievous boost even at max energy.

**`recencyPenalty`** (`BehaviorSelector.swift:459-471`): 0.3× if performed
under 1 hour ago, 0.6× under 2 hours, 1.0× (no penalty) beyond that or if
never performed. **`noveltyBonus`**: a flat 1.5× multiplier while
`performanceCount` (lifetime, not per-session) is under 3.

**Cooldowns are also personality-modulated**, separately from the weight
formula: `cooldownModifier()` (`BehaviorSelector.swift:474-477`) computes
`0.6 + (1.0 - personality.energy) × 0.8`, so a hyper creature
(`energy` → 1.0) waits only 0.6× a behavior's listed cooldown while a calm
one (`energy` → 0.0) waits 1.4×.

This registry's own `baseWeight`/`cooldown`/`category`/`emotionalCondition`
values (`BehaviorSelector.swift:135-272`) are genuinely different numbers
from the `CatBehavior.weight`/`priority` values in the table below — they
are not two views of one dataset, they are two datasets that happen to
share names, because they feed two different call paths entirely.
[Hunt & pounce](/SYSTEMS/hunt-and-pounce.md#1-the-fragments-code-verified-ground-truth)
independently documents this exact split for one behavior
(`predator_crouch`); the general shape it found there — one
`BehaviorSelector` entry driving `AutonomousLayer`'s own idle→behavior
transition, and one separate `CatBehavior` entry reachable only through the
AI-Directed manual-perform path — is universal across all 12, not specific
to that behavior. The AI-Directed path is `ActionHandlers.swift:377-393`:
an MCP `pushling_perform` command action-string first checked against
`CatBehaviors.named(action)`, and if found, dispatched straight to
`catBehavior.perform(creature)` — a direct `CreatureNode` mutation that
never touches `BehaviorSelector`, `BehaviorStack`, or the Autonomous layer's
own state machine at all. A behavior can therefore be selected
autonomously, performed on command, or both in the same session, through
two call paths that don't share weighting, cooldown tracking, or even a
struct definition.

### The Idle Micro-Behavior Scheduler (designed, not built)

[Idle & rest](/SYSTEMS/idle-life-and-rest.md#1-idle-life-layer)'s scheduler
— the ≤20s whole-body-motion guarantee, the weight-shift/paw-reposition/
turn-in-place/shake-off micro-actions, and the staged sit→loaf dwell
escalation — is not a new priority tier. It is a further elaboration
entirely inside Layer 4's own `update()` return value, which already sits
at the bottom of this stack's per-property fallback chain (`physics ??
reflexes ?? ai ?? autonomous ?? stageDefault`, above). Whatever the
scheduler ends up authoring — a weight-shift `LayerOutput`, a sit-sequence
`bodyState`, a loaf hold — arrives through the exact same `AutonomousLayer`
frame output this section already documents, resolved at the exact same
lowest priority; no new `LayerOutput` field, `BehaviorLayer` conformer, or
resolution-chain entry is required in principle.

**Today's baseline is a materially lower ceiling than the scheduler's own
numbers.** `AutonomousLayer.updateIdle` (`AutonomousLayer.swift:370-397`)
holds a fixed `bodyState = "stand"` for a 2-8s dwell
(`PersonalityFilter.idleDuration`-modulated), then forces a transition to
`.walking` if it somehow runs past 8s (line 393-397) — [idle & rest's own
grounds](/SYSTEMS/idle-life-and-rest.md#0-todays-baseline-code-verified-ground-truth)
correctly call this "a safety valve, not an intentional cap." The
scheduler's 30-90s sit-escalation and further 60-180s loaf-escalation
thresholds are 4-10x past that valve, so building it means replacing the
valve's role inside `updateIdle`/`updateDwell`, not layering underneath it
unchanged. Whether the eventual implementation models the escalation as
new internal sub-states of `updateIdle` or as new `AutonomousState` cases
is an implementation choice that belongs to [idle &
rest](/SYSTEMS/idle-life-and-rest.md), not a behavior-stack-level decision
— this stack's only stake in the outcome is that the result keeps
returning a `LayerOutput` from Layer 4, same as today.

## The 12 Cat Behaviors

`CatBehaviors.swift` + `CatBehaviorsExtended.swift` register **12
cat-specific choreographies**, each an independent state machine composing
`CreatureNode`'s body-part controllers directly. The `weight`/`priority`
columns below belong to this registry's own `CatBehavior` struct, which
powers only the **AI-Directed manual-perform path** (an MCP
`pushling_perform` command dispatched through `catBehavior.perform(creature)`
— see [the shipped weight-based selection
formula](#the-shipped-weight-based-selection-formula-code-verified-previously-undocumented)
above for the citation). What the Autonomous layer's own `BehaviorSelector`
picks weighted-randomly for `.behavior(name:)` states is a *separate*
registry with its own weights, documented in that same section — the two
share behavior names, not numbers. All 12 exist and are wired — code-verified
against the vision doc's 12-item catalog, but **not name-for-name**: 10 of the 12
match the vision list exactly (slow-blink, kneading, headbutt, predator
crouch, loaf, grooming, zoomies, chattering, if-I-fits-I-sits, knocking
things off); the vision doc's remaining two entries are **"tail twitch"**
and **"ear perk"** (`PUSHLING_VISION.md:162-163`), neither of which exists
as an autonomous-behavior name — the code's 11th and 12th slots are
`tail_chase` and `tongue_blep` instead, two different behaviors entirely.
The substance of tail-twitch/ear-perk survives elsewhere in the codebase
as reflexes and reactive body-language rather than autonomous behaviors
(see [Layer 2: Reflexes](#layer-2-reflexes) above and [emotional visual
feedback](/REFERENCE/personality-emotional-state.md#emotional-visual-feedback-axis--body-language)),
just not as members of this 12-item registry:

| # | Name (code) | Min stage | Duration | Cooldown | Weight | Priority | Trigger semantic |
|---|---|---|---|---|---|---|---|
| 1 | `slow_blink` | Drop | 1.0–1.2s | 120s | 0.8 | 3 | Affection/trust — eyes close halfway, hold, open |
| 2 | `kneading` | Critter | 4–8s | 300s | 0.5 | 2 | Pre-sleep ritual — front paws alternate, eyes half-close |
| 3 | `headbutt` | Critter | 1.2–1.8s | 180s | 0.6 | 3 | Affection display — walks to edge, bonks, recoils |
| 4 | `predator_crouch` | Critter | 1.5–2.5s | 60s | 0.7 | 5 | Hunting incoming commits — low stance, butt-wiggle ×3, ears flat |
| 5 | `loaf` | Critter | 30–60s | 600s | 0.3 | 1 | Maximum comfort — all paws tucked, perfect rectangle |
| 6 | `grooming` | Critter | 3–5s | 240s | 0.5 | 2 | Post-meal idle — paw-lick, head tilt |
| 7 | `zoomies` | Critter | 2–4s | 600s | 0.2 | **6 (highest)** | Sudden speed burst — no warning, no reason |
| 8 | `chattering` | Critter | 1.5–2.5s | 180s | 0.4 | 4 | Jaw vibrates at flying birds/particles — prey drive |
| 9 | `if_i_fits_i_sits` | Critter | 10–20s | 600s | 0.2 | 2 | Squeezes into the smallest terrain gap available |
| 10 | `knocking_things_off` | **Beast** | 2.5–3.5s | 420s | 0.3 | 3 | Deliberately pushes a terrain object off, watches, looks at camera |
| 11 | `tail_chase` | Critter | 4–6s | 480s | 0.2 | 3 | Notices own tail, chases in circles, catches it, pretends nothing happened |
| 12 | `tongue_blep` | Drop | 15–30s | 600s | 0.15 | 1 (lowest) | Tongue sticks out 1px, stays out, creature doesn't notice (also [Surprise #42](/REFERENCE/surprise-catalog.md)) |

`zoomies` carries the highest `priority` value (6) of any behavior in this
table, `tongue_blep` the lowest (1) — but this `priority` field is
**decorative, not arbitrating**: grepping every call site of
`CatBehavior.priority` outside its own definition
(`CatBehaviors.swift`/`CatBehaviorsExtended.swift`) turns up none — no
override-preemption, no sort, no comparison reads it anywhere in the
codebase. Read it as author intent ("zoomies should feel like it overrides
everything") rather than as a live mechanism that actually lets zoomies
preempt anything or lets tongue_blep be preempted; the real
override-preemption in this stack is [the four-layer priority
resolution](#the-four-layers) above, which this field sits entirely outside
of. `loaf` and `if_i_fits_i_sits` are the two longest-running (up to 60s and
20s respectively) and both carry a 600s cooldown to match, so the creature
isn't stuck loafing or wedged for a large fraction of an active session.
`knocking_things_off` is the only one of the 12 gated to Beast+ rather than
Critter+ or Drop+ — code-verified, not vision-doc-specified.

### Known Defect — `tongue_blep`'s Mouth Doesn't Exist Yet at Its Own Minimum Stage

Both registries gate `tongue_blep` at `stageMin`/`minimumStage: .drop`
(`BehaviorSelector.swift:230-236`, `CatBehaviorsExtended.swift:249-255`),
but `StageRenderer` builds `mouth: nil` for Egg, Drop, *and* Critter
(`StageRenderer.swift:112`, `:175`, `:253`; the Critter builder even
comments it explicitly: `// No mouth or whiskers at Critter stage — they
debut at Beast`, `:227-228`) — the first real mouth node isn't constructed
until `buildBeast()`'s own `makeMouth(...)` call
(`StageRenderer.swift:312-314`). `CreatureNode` only constructs a
`mouthController` `if config.hasMouth, let mouth = nodes.mouth`
(`CreatureNode.swift:584-591`), so at Drop and Critter that controller is
`nil` too. The result is a silent no-op on **both** call paths the section
above documents, for the entirety of the behavior's 15-30s duration, at
**two** stages rather than the one the archived research note flagged:
autonomous selection sets `output.mouthState = "blep"`
(`BehaviorChoreography.swift:249-250`, `applyTongueBlep`) into a
`LayerOutput` no downstream mouth node exists to render, and the
AI-Directed path's `creature.mouthController?.setState("blep", ...)`
(`CatBehaviorsExtended.swift:260`) evaluates against a `nil` optional and
does nothing. A Drop or Critter creature performing `tongue_blep` — however
it got selected — looks and behaves exactly as if nothing happened; there is
no visible symptom to notice without reading the code, only the absence of
one. Also cross-referenced from [predator behavior in hunt &
pounce](/SYSTEMS/hunt-and-pounce.md#1-the-fragments-code-verified-ground-truth)
and [Surprise #42](/REFERENCE/surprise-catalog.md), both of which describe
this behavior's *intended* effect without flagging that it's currently
invisible pre-Beast. The fix is a one-line bump of both registries'
`stageMin`/`minimumStage` from `.drop` to `.beast` — not attempted here, as
this is a documentation pass, not a code change.

## Absence-Scaled Wake Behaviors

`AbsenceAnimations.swift` implements the vision doc's "longer absence, more
excited reunion" wake rule as **6 graduated categories** (finer-grained than
the vision doc's 3-tier framing), each a keyframed `AnimationKeyframe`
sequence consumed by the Autonomous layer on wake:

| Category | Absence | Animation duration | Choreography |
|---|---|---|---|
| `brief` | < 1hr | 1.0s | Quick stretch, stand |
| `shortBreak` | 1–8hr | 3.0s | Ears droop → yawn → stretch → stand → kneading (Critter+) |
| `overnight` | 8–24hr | 4.0s | Sleep-curl → stir → big yawn → dramatic stretch (paws extend) → shake head, look around |
| `fewDays` | 1–3d | 5.0s | Overnight sequence + cautious crouch-sniff (ears perk, eyes wide, whiskers forward) → stand and look around |
| `longAbsence` | 3–7d | 6.0s | Sleep-curl with **cobweb** metadata → stir/shake-cobwebs → eyes wide (recognizes developer) → tail poofs → **run across the bar** (walk speed 50) → slow down |
| `extended` | 7+d | 8.0s | Deep sleep, **heavy cobwebs** → slow stir → vigorous shake (cobwebs fly off) → extreme happiness (wide eyes, poofed tail, smile) → **zoomies** (walk speed 70) → turn and zoom back → slow down, overjoyed (happy eyes, wagging tail, smile) → calm |

This directly and verifiably implements the vision doc's "No guilt — longer
absence = more excited reunion" rule: animation duration, walk speed, and
emotional intensity (droop → stretch → wide-eyed → poofed-tail → full
zoomies) all scale monotonically with absence length, with cobweb-shedding
appearing only at 3+ days and heavy cobwebs only at 7+.

**Late-night lantern** (`LateNightLantern`, same file): after **10PM**
(`activationHour = 22`), if the developer is still active, the creature
produces a tiny Gilt lantern that bobs gently at its side; it persists until
**5AM** (`dismissHour`) or a **30-minute cooldown** after manual dismissal.
If the developer goes idle for **10 minutes** (`sleepIdleSeconds`) while the
lantern is out, the lantern dims to a "sleeping with lantern" state (alpha
0.4, dimmer glow) rather than being dismissed — "solidarity, not judgment,"
per the vision doc, implemented as the creature keeping the lantern lit
through its own idle/sleep rather than putting it away.

**Not built**: the vision doc's Working-row ambient behaviors — ears
tracking toward the keyboard and idle daydreams referencing recent commit
messages — have no corresponding code (`isTyping`/keystroke-tracking greps
return nothing); preserved as unbuilt intent in
[the feature roadmap](/FEATURES/roadmap.md#tier-3-developer-workflow-integration)
rather than asserted as live here.

**Session-event reactions** (first MCP command, session connect/disconnect,
reconnect-after-absence) are wired through `SessionManager`/
`SessionLifecycleReactions`, not this stack's own layer-priority machinery
— that content, including the P4-T4-06 design table and what actually
shipped of it, lives in
[MCP session lifecycle's Session Event Reactions](/ARCHITECTURE/mcp-session-lifecycle.md#session-event-reactions),
cross-linked from here rather than duplicated.

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

# Posture Vocabulary — A Modifier Outside the Priority Stack

Everything above resolves per-property into one `ResolvedCreatureState` —
that is this stack's complete output. [Emotional body
language](/SYSTEMS/emotional-body-language.md#1-posture-vocabulary--valencearousal-to-body-shape)'s
Posture Vocabulary (`hipHeight`/`spineCurve`/`headPitch`/`tailCarriage`/
`gaitBounce`, driven by a valence×arousal collapse of the four
`EmotionalSnapshot` axes — `satisfaction`/`curiosity`/`contentment`/
`energy`, `LayerTypes.swift:281-291` — itself a synthesized read of
existing data, not a stored field anywhere in the codebase today) is
deliberately specified to apply **after** this stack finishes, as a
multiplicative modifier riding [body pose &
compose](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula)'s
own compose point (`CreatureNode.updateBreathing()`), not as a value any
of the four layers above could set, read, or override.

This boundary is deliberate, not incidental. The four layers' per-property
resolution already answers one question — "which layer owns this property
right now" (Physics vs. Reflex vs. AI-Directed vs. Autonomous) — and mood
is a different question entirely: "how does the current emotional state
bend whatever pose already won." Answering the second question inside
`resolveOutputs()` would require every one of the four layers to separately
account for mood, multiplying the same modifier four times instead of once
at the render-side compose point it actually rides. Keeping it downstream
is also what lets a dejected `loaf` and a joyful `loaf` share one
`bodyState` string and one priority-resolution outcome, differing only in
the modifier layered on after — see [idle &
rest](/SYSTEMS/idle-life-and-rest.md#2-resting-posture-ladder) for a
worked example (the resting-posture ladder is itself scheduled by that
concept and reshaped by this one). Any future change to this stack's
`resolveOutputs()` priority chain should treat a proposal to special-case
an emotional axis there as a signal that the change belongs in
`BodyPoseController`/`CreatureNode` instead, not a reason to add a fifth
layer here.

# Generalized Reflex Injection — One Bridge for Surprises, Glances, and Sky Reactions

[Environment reactions](/SYSTEMS/environment-reactions.md#the-one-reusable-bridge-reflex-injection-not-a-new-mechanism)
and [companionship rituals](/SYSTEMS/companionship-rituals.md#5-check-in-glances--social-referencing)
both specify reactions (Sky Theater's per-event choreography, Check-In
Glances' periodic pause) as reuses of what the dossier and this program's
own dispatches call "the reflex checkpoint/resume mechanism (the surprise
mechanism)" — and both, independently, flag that this stack does not yet
document that mechanism as a named, generalized pattern. This section is
that documentation.

**There is no checkpoint and no resume.** "Checkpoint/resume" is
shorthand in circulation across this program's concepts for what
[Layer 2](#layer-2-reflexes) already does every frame: `ReflexLayer.update`
(`ReflexLayer.swift:144-161`) returns a per-property merged `LayerOutput`
while a reflex is active and `.empty` (all-nil — "defer to the layer
below") the instant it expires. No other layer is paused, snapshotted, or
restored — [every layer runs `update(deltaTime:currentTime:)`
independently, every frame, regardless of priority](#the-four-layers), the
whole time a reflex is masking it. "Seamless resume" is therefore not a
save/restore of anything: it is that the masked layer's own state machine
was never stopped, so whatever it happens to be outputting *right now*
becomes visible again the moment the mask lifts — not whatever it was
outputting the instant the mask began. A design describing a behavior as
"pausing and resuming" a lower layer should state it this way, or it will
imply a snapshot capability that does not exist and would surprise whoever
implements it.

**The mechanism this shorthand actually refers to is already fully built
and duration-agnostic**, proven by `SurpriseAnimationPlayer`
(`Surprise/SurpriseAnimationPlayer.swift`): short surprises (<10s) inject a
single `ReflexDefinition`; long surprises (≥10s) inject a *series* of them
over time, via an `onInjectReflex` callback into this stack's own
`triggerReflex(_:at:)` (`BehaviorStack.swift:336`) — the same general entry
point `ReflexLayer.trigger(_:at:)` exposes, distinct from and not gated by
the four-name `trigger(named:)` switch [Layer 2](#layer-2-reflexes)
documents above. `SurpriseAnimationPlayer` proves the generalization by
example: it constructs a fresh, dynamically-named `ReflexDefinition` per
keyframe (`"surprise_\(id)_kf\(index)"`) and injects it directly, never
touching the named-reflex switch at all. Any future concept wanting a
"reflex-style reaction to an event" — Sky Theater's per-`VisualEvents`-type
chains (2s shooting-star startle through 45s aurora gaze), a Check-In
Glance's quarter-turn-and-blink pause, or anything similar — needs **zero
new behavior-stack machinery**: one or more `ReflexDefinition` values
authored at the concept's own call site, triggered through the existing
`triggerReflex(_:at:)`, is the complete contract.

**Two constraints any such design must respect**, both already true of the
mechanism as built: (1) capacity — `ReflexLayer` holds at most 5
concurrent `ActiveReflex` instances, oldest evicted past that
([Layer 2](#layer-2-reflexes)) — a long reflex chain (aurora's 45s gaze)
shares that budget with whatever `ear_perk`/`flinch`/touch reflexes fire
from unrelated input in the same window, system-wide, not per-feature; (2)
the masked-layer-keeps-running rule above has a cosmetic edge case worth
budgeting for up front — a reflex that masks `walkSpeed` (none of the four
shipped `ReflexDefinition`s do today; a new one authored for this purpose
would) doesn't pause `AutonomousLayer`'s own walk-bout timer, so a bout that
happens to complete *during* the mask picks a new destination/speed before
the mask lifts, and "resume" surfaces that new choice rather than the
pre-mask one. Not a bug — the honest behavior of "never stopped running,"
not "paused and restored" — but worth stating in any concept's own design
rather than discovering it at build time.

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
[9] `Pushling/Sources/Pushling/Creature/CatBehaviors.swift`, `CatBehaviorsExtended.swift` (all 12 cat behaviors)
[10] `Pushling/Sources/Pushling/Creature/AbsenceAnimations.swift` (`AbsenceCategory`, `AbsenceWakeAnimation`, `LateNightLantern`)
[11] `PUSHLING_VISION.md` — Control Architecture: The 4-Layer Behavior Stack; The Blend Controller; Touch-AI Interaction Priority; Cat behaviors baked into Layer 1 (lines 158–171); Core Loop (lines 393–404)
[12] `Pushling/Sources/Pushling/Surprise/SurpriseAnimationPlayer.swift` (the reflex-injection bridge every surprise, and the generalized reaction pattern in this doc, both ride)
[13] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift` (the `BehaviorDefinition` registry, weight formula, and `affinityMap` — a second registry distinct from citation [9]'s `CatBehavior`)
[14] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift` (the AI-Directed `pushling_perform` dispatch into `CatBehaviors.named(action)?.perform(creature)`, lines 377-393)
[15] `Pushling/Sources/Pushling/Creature/StageRenderer.swift` (per-stage `mouth` node construction — `nil` through Egg/Drop/Critter, first built at Beast)
[16] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`mouthController` construction, gated on `config.hasMouth` and a non-nil `nodes.mouth`)
