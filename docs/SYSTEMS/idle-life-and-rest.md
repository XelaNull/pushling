---
type: System
title: Idle Life & Rest
description: Everything the creature does when nothing is happening — the direct anti-static canon. The idle micro-behavior scheduler with its <=20s whole-body-motion guarantee and staged sit/lie escalation, the thermoregulatory/trust resting-posture ladder, the stretch ritual grammar, sleep geography, Dream Theater somatic twitching, sunbeam seeking, crepuscular patrol, and the evening wind-down ritual. Designed, not built, unless a mechanism is explicitly marked Shipped below.
status: Future
tags: [idle, rest, sleep, dream, posture, stretch, patrol, sunbeam, wind-down, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the direct answer to "it just stands around." It does not own
*how* a pose renders — every tuple below is a `bodyState` string consumed
by [the body pose pipeline](/SYSTEMS/body-pose-pipeline.md)'s compose
point, which must ship first (or these mechanisms schedule poses into the
same void that swallows every other `bodyState` today). It does not own
*why* a mood looks the way it does — that is [emotional body
language](/SYSTEMS/emotional-body-language.md)'s posture-vocabulary
modifier layer, which multiplies on top of whatever this doc schedules,
never the reverse. This doc owns **scheduling and selection**: when the
creature fidgets, sits, lies down, sleeps, dreams, seeks warmth, patrols,
and winds down for the night — eight dossier features, one anti-boredom
governor underneath all of them.

# 0. Today's Baseline (code-verified ground truth)

Two distinct "nothing is happening" states already exist, and neither
does anything beyond hold still:

1. **`AutonomousLayer.updateIdle`** (`Behavior/AutonomousLayer.swift:370-397`)
   — entered directly by the state machine's own selection logic, duration
   `regenerateStateDuration()`'s **2-8s base** (`randomRange(2.0, 8.0)`,
   line 601) run through `PersonalityFilter.idleDuration` (energy-inverted,
   `[0.5, 1.5]×`) and discipline jitter. Sets `bodyState = "stand"`,
   all four paws to `"ground"`, ears/whiskers to `"neutral"` — nothing
   else. Forces a transition to `.walking` if it somehow runs past 8s
   (line 393-397, a safety valve, not an intentional cap).
2. **`AutonomousLayer.updateDwell`** (lines 334-366) — entered *within*
   the `.walking` state after arriving at a destination, **3-8s**
   (`randomRange(3.0, 8.0)`, line 324), identical `bodyState = "stand"` /
   all-paws-`"ground"` output to `updateIdle` above. Two different code
   paths, same visible result.

Both states produce a torso that already has nothing to render even if
[the body pose pipeline](/SYSTEMS/body-pose-pipeline.md) shipped today —
`"stand"` is the identity tuple. What actually moves during either state
is `CreatureNode.updateNoiseIdle` (`Creature/CreatureNode.swift:284-304`):
six sine-wave offsets at amplitudes `[0.12, 0.15, 0.015, 0.015, 0.02,
0.02]`pt (line 57) applied continuously regardless of state — this is the
literal "waves its tail and ears" the human complained about, and it is
the **entire** idle repertoire today. There is no scheduler, no
escalation, no variety.

**A third state, `.resting`, already exists and is closer to "asleep" than
either idle state** (`updateResting`, lines 463-494): entered globally
when `emotions.energy < 20` and the creature has held its current state
`> 15.0s` (line 247, guarded off during walking/taught-behavior/object-
interaction/dreaming so it never interrupts them). It sets `bodyState =
"sleep_curl"`, closes both eyes, droops ears (Critter+), wraps the tail,
tucks all four paws — a real appendage-level "asleep" look, dropped at the
torso like every other `bodyState`. After holding for `> 10.0s` it calls
`shouldBeginDream(...)` (`AutonomousLayer+Dreaming.swift:59-75`) and either
enters `.dreaming` or falls back to `.idle` — **there is no persistent
"asleep until morning" state**; a creature that fails the dream gates
(energy still `< 20` but the 4 gates below don't all pass) simply cycles
`resting → idle → resting` all night, waking fully every time energy
happens to tick back above 20.

**Two mechanisms this doc's features need are fully coded and never
called — confirmed by exhaustive grep, zero call sites beyond their own
file:**

- **`BehaviorStack.setSleeping(_:)`** (`Behavior/BehaviorStack.swift:363-369`)
  sets `physics.isSleeping` and force-transitions `autonomous` to
  `.resting`. It is called from **nowhere** in the app target.
  `PushlingScene.applyBehaviorOutput` (`Scene/PushlingScene.swift:820`)
  reads `behaviorStack?.physics.isSleeping ?? false` every frame and
  forwards it to `creature.setSleeping(_:)` — but since the upstream
  setter is never invoked, this read is permanently `false` in
  production. The consequence: `CreatureNode.updateNoiseIdle`'s `isSleeping
  ? 0.1 : 1.0` amplitude damp (line 286) and `updateBreathing`'s slow
  5.0s-period sleep breathing (line 313, cited in [the body pose
  pipeline](/SYSTEMS/body-pose-pipeline.md)) **never activate** — a
  creature in `.resting` or `.dreaming` still fidgets and breathes at full
  waking amplitude. `docs/REFERENCE/procedural-animation.md`'s existing
  claim that "breathing amplitude/period already differ while asleep" is
  **only true of the internal formula, not of any live trigger path** —
  worth a follow-up correction pass on that doc since this wave doesn't
  own it.
- **`CircadianCycle`** (`Creature/CircadianCycle.swift`) — a fully-built
  14-day commit-histogram learner with `currentPhase()`,
  `shouldBeSleeping()`, and a `WakeSequence` struct (duration/yawn/knead
  flags per phase, lines 317-369) — is constructed and fed commits
  (`GameCoordinator.swift:376`) but **`currentPhase`/`shouldBeSleeping`/
  `wakeSequence` have zero callers anywhere** outside `CircadianCycle.swift`
  itself and one debug time-advance helper (`DebugActions.swift:502`). No
  feature in this doc should gate on it as-is. The **live** clock every
  dawn/dusk/evening trigger below actually uses is
  [`SkySystem.TimePeriod`](/SYSTEMS/environment-reactions.md) (`World/
  SkySystem.swift:14-23`) — 8 named periods on a fixed real-clock schedule
  (`deepNight` 00:00, `dawn` 04:30, `morning` 06:00, `day`, `goldenHour`,
  `dusk`, `evening`, `lateNight`) — which is already read by
  `DreamEngine.checkGates`'s `timePeriod == .lateNight || .deepNight` gate
  (`DreamEngine.swift:89`). **Recommendation for the eventual build WO:**
  every dawn/dusk/evening trigger in this doc keys off `SkySystem.TimePeriod`,
  not `CircadianCycle` — flagging this as a call worth Samantha's eyes
  since the dossier's proposals name "circadian" loosely and the two
  systems are not interchangeable (one is live and real-clock-based, the
  other is commit-schedule-learned and completely dead).

**`DreamEngine`'s dream content is not thematic — it is git-activity
pattern-matched, not "chase/hunt/social/storm" imagery.** `DreamPattern`
(`Behavior/DreamEngine.swift:302-329`) resolves to one of 15 cases —
`.manyCommits(language:)`, `.lateNightCoding`, `.touchHeavy`,
`.errorStreak`, `.diverseLanguages`, `.longSession`, `.quiet`,
`.highDebugging`, `.highChaos`, `.streakBuilding`, `.shortCommits`,
`.verboseCommits`, `.multiRepo`, `.noActivity`, `.generic` — purely from
commit/touch/hook-error counts in the last 24h of journal rows, feeding
`DreamTemplates.generate(pattern:)` for the dream's text summary. There is
**no** chase/hunt/social/storm taxonomy anywhere in the engine; the only
per-frame somatic signal it emits today is a single uniform twitch pulse
(`isTwitching`, `dreamingOutput(twitching:)`, lines 170-185, 404-415) every
`twitchInterval = 10.0`s for `0.25`s, applied identically regardless of
`DreamPattern`. [§5](#5-dream-theater--somatic-twitch-per-dream-pattern)
below proposes the mapping this doc needs to make "dream content" mean
something visible, since the dossier's phrasing assumes a categorization
that does not exist in code.

# 1. Idle Life Layer

A lowest-priority micro-behavior scheduler riding inside the existing
`.idle`/dwell-in-`.walking` states above — it does not add a new
`AutonomousState` case, it decorates the two that already exist. Per the
dossier's own framing this is a scheduled `LayerOutput` injection at
Autonomous priority (the lowest of the [4 layers](/SYSTEMS/behavior-stack.md)),
so it is free to yield to Reflex/AI-Directed/Physics without any new
arbitration code — the stack's existing per-property `physics ?? reflexes
?? ai ?? autonomous` fallthrough already handles it.

**Not the same mechanism as `IdleRotationGovernor`.** That governor
(`Behavior/IdleRotationGovernor.swift`) gates the ratio of *taught*
choreography vs. ordinary cat behaviors in the existing `.behavior`/
`.taughtBehavior` selection pool (80/20 cap, max 3 taught/hour) — it has
no concept of micro-fidgets and does not need to be touched by this
feature; the dossier's synergies note ("feeds the existing
IdleRotationGovernor") is imprecise and is corrected here rather than
carried forward.

## 1.1 Micro-Action Roll (during `.idle` and walking `dwell`)

Every 4-12s of continuous stand-dwell (either code path in
[§0](#0-todays-baseline-code-verified-ground-truth)), roll one micro-action
from the weighted table below. None of these need a new `bodyState`
string — they ride the same continuous-offset channel
`CreatureNode.updateNoiseIdle` already uses (subtract-previous-then-add-new,
so they compose with noise-idle rather than fighting it), plus direct
`pawStates`/`earState` dictionary writes the appendage controllers already
consume every frame.

| Micro-action | Motion | Weight | Cooldown vs. last pick |
|---|---|---|---|
| Weight shift | Body `xScale` drifts +0.02 over 600ms with 0.4pt x-position nudge; one rear paw lifts 0.5pt and replants 1s later | 30% | none (most frequent, cheapest) |
| Paw reposition | One randomly-chosen paw state cycles `ground → lift → ground` over 400ms | 25% | none |
| Turn-in-place | `facing` flips without a destination change (reuses `pendingDirectionChange`, already read by `updateIdle`, line 388-391) | 15% | 20s (avoid dizzying flip-spam) |
| Ear-orient | Both ears cycle `neutral → perk → neutral` over 500ms | 20% | none |
| Shake-off | Reuses the already-tabled `shake` `bodyState` dynamic (`zRotation` ±0.15rad @ 10Hz, decaying — [body pose pipeline §2](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)) over 500ms; +2 pooled droplet particles if `WeatherSystem.current == .rain` within the last 5 min | 10% | 90s |

**Roll cadence** is itself personality/circadian-weighted: base interval
`randomRange(4.0, 12.0)`s, scaled by `EmotionalState.energy` the same way
`PersonalityFilter.idleDuration` already scales walk/idle durations
(`energyMod = 1.5 - energy×1.0`, so a low-energy creature rolls roughly
1.5x less often, a hyper one ~1.5x more).

## 1.2 The <=20s Whole-Body-Motion Guarantee

**Hard rule:** if 20s elapse with no micro-action roll, `bodyState`
transition, or state-machine transition, the scheduler force-fires the
next-due micro-action regardless of its normal cooldown. This is a single
`timeSinceLastWholeBodyMotion` accumulator, reset by *any* of: a
micro-action firing, a `.behavior`/`.taughtBehavior` entry, a walk-bout
start, or a dream-twitch (§5) — not a new timer per mechanism, one shared
watchdog. Because §1.1's own roll interval tops out at 12s, this guarantee
is a backstop for the unlucky case where several idle-then-walk-then-idle
cycles land back-to-back with the roll's own randomness pushing past 12s
— it should almost never actually trigger the force-fire path once §1.1 is
live, but it is the literal, auditable answer to "it just stands around."

## 1.3 Dwell Escalation — the staged sit/lie sequence

`docs/REFERENCE/procedural-animation.md` already names the staged
sitting sequence as its own unbuilt item; this is where it lives now.
Both idle-state paths accumulate a `dwellElapsed` timer (distinct from
each state's own `stateTimer`, since a creature might idle→walk→idle
repeatedly without ever completing the ladder — this timer only resets on
walking or a completed sit-to-standing recovery):

| Dwell elapsed | Transition | `bodyState` target | Duration |
|---|---|---|---|
| 0-30s | (§1.1 micro-actions only) | `stand` | — |
| 30-90s (rolls once in this window, personality-jittered) | Sit-down | `sit` (existing tuple, [body pose pipeline](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)) | 900ms transition, then holds |
| +60-180s further (only from `sit`) | Loaf-down | `loaf` (existing tuple) | 1.4s transition, then holds |
| Any point past `sit` | Interrupted by a real destination pick, reflex, or AI command | reverts immediately via the stack's normal priority fallthrough | — |

Both target states (`sit`, `loaf`) already exist in [the body pose
pipeline's tuple table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
— this feature needs **zero new `bodyState` strings**, only the
scheduling logic above plus the transition-duration overrides (900ms /
1.4s vs. that pipeline's default 0.3s ease, using the same reflex-vs-normal
distinction already specified there).

## 1.4 Stage Gating

| Stage | Micro-action set | Roll cadence | Escalation |
|---|---|---|---|
| Egg | Lean-wobble only (±3deg, reuses egg-wobble's own `zRotation` channel per [body pose pipeline §3](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)'s Egg note — do not add a second `zRotation` writer) | n/a (pre-directed-movement stage) | none |
| Drop | Weight-shift + sit only, 0.6x amplitude | 4-12s | Sit only, no loaf (Drop has no `loaf` tuple use case — [growth-stages.md](/REFERENCE/growth-stages.md) reserves Drop's signature vertical motion for the hop, not a seated pose) |
| Critter | Full 5-action set | 4-12s | Full ladder |
| Beast | Full set + heavier resettle (weight-shift amplitude ×1.3, "grunt-shift" per dossier) | 4-12s | Full ladder |
| Sage | Reduced action count (drop paw-reposition and ear-orient — restrained per [body pose pipeline §3](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)'s "power via subtraction") | 8-20s (slower, calmer) | Full ladder, but each transition takes 1.5x as long |
| Apex | Micro-actions replaced entirely by a 20s-period Lissajous position drift (+-2pt) while `auraState` breathes — the guarantee is satisfied by ambient drift, not discrete fidgets | continuous | none (Apex idles by floating, never sits/loafs in the ordinary sense — reinterprets the ladder as [Sleep Geography](#4-sleep-geography)'s levitation-sleep) |

# 2. Resting Posture Ladder

Replaces `updateResting`'s single hard-coded `sleep_curl` target with a
continuous 5-rung axis, selected once on entering `.resting` (not
re-evaluated every frame — a resting creature doesn't re-roll its posture
mid-nap) from three live inputs: `WeatherSystem.current` (cold biases
tighter), `EmotionalState.energy` (already read by `updateResting`'s own
entry gate, `< 20`; the exact residual value below 20 flattens the curve —
lower energy = flatter rung), and `EmotionalState.contentment` (high
contentment exposes the belly, low contentment cinches in and keeps the
`facing` toward the screen rather than away).

| Rung | `bodyState` (new unless noted) | Tuple `(yScale, xScale, yOffset, zRotation, headOffset, pawAlpha)` | Selected when |
|---|---|---|---|
| Sprawl | `sprawl` **(new string — not in the 21 already enumerated by [body pose pipeline §2](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table))** | `(0.60, 1.30, -0.7, 0, -0.2, 0.6)`, path-swap yes (belly-up curve, one hind paw offset via `pawStates["bl"]="kicked"` — new paw-state literal) | contentment > 65 AND weather != rain/storm/snow |
| Side-lie | `roll_side` **(existing)** | `(0.65, 1.30, -0.5, 1.40, 0.0, 0.55)` — reused as-is | contentment 40-65, energy > 10 |
| Sphinx | `sphinx` **(new string)** | `(0.78, 1.05, -0.25, 0, +0.1, 1.0)` (paws stay visible under the chest — the one rung that keeps `pawAlpha` near 1.0, matching real sphinx posture) | contentment 25-40, mild caution |
| Loaf | `loaf` **(existing)** | `(0.82, 1.10, -0.35, 0, -0.15, 0.3)` — reused as-is | default / contentment 15-40, cold-neutral |
| Curl | `curl` or `sleep_curl` **(existing — `sleep_curl` once dreaming per §5, `curl` while merely resting)** | `(0.60, 1.15, -0.8, 0, -0.45, 0.35/0.20)` | contentment < 25 OR weather in {rain, storm, snow} OR energy < 8 |

Transitions between rungs are **1.5-3s eased morphs** (never a snap — the
existing per-property 0.3s default ease from [the body pose
pipeline](/SYSTEMS/body-pose-pipeline.md#1-the-bodyposecontroller--the-missing-13th-part-controller)
is too fast for a settle; this feature needs its own longer transition
duration for the `bodyState`-change case specifically, not a global
change). A cold rung (Curl selected for weather reasons, not contentment)
adds a periodic 0.3pt shiver tremor riding the same `shiver` dynamic
tuple already tabled; a warm Sprawl runs `breathPeriodOverride = 1.5x`
the `DreamEngine`-style breath-period-override mechanism already proven
in `DreamOutput.breathPeriodOverride` (`DreamEngine.swift:29`) — reused
here as a **non-dream** consumer of the same optional field, since
`CreatureNode.updateBreathing`'s period read is not exclusive to dreaming.

## 2.1 Stage Gating

| Stage | Available rungs |
|---|---|
| Egg | N/A |
| Drop | Sprawl (relaxed puddle-spread) or Curl (tight bead) only — two-rung ladder, matches Drop's existing binary hop/still repertoire |
| Critter | Loaf + Curl (Sphinx/Sprawl/Side-lie withheld — Critter's 14x16pt silhouette is the tightest that still clears the Solid Fill Test for the belly-exposed sub-shape) |
| Beast | Full 5-rung ladder; largest sprawl amplitude |
| Sage | Loaf/Curl only, plus the `meditation` choreography (already shipped, `BehaviorChoreography.applyMeditation`, `bodyState = "loaf"`, eyes-closed) as the Sage-exclusive rung substitute — "power via subtraction" applies here too |
| Apex | Curl only, executed as [Sleep Geography](#4-sleep-geography)'s levitation-sleep (1pt hover, `auraState = "transcendent"` pulse) rather than a ground-contact pose |

# 3. Stretch Ritual Grammar

Every wake transition resolves through this 3-beat sequence **before**
anything else, including the [dawn wake-greeting
speech](/SYSTEMS/voice-tts-stack.md) (designed, not built — this sequence
is upstream of it either way). Trigger surfaces: `SkySystem.TimePeriod`
reaching `dawn`, the 3-tap wake-up boop gesture, `AbsenceAnimations`'
return-from-absence wake keyframes, and completing a `.dreaming` cycle
(`DreamEngine.update`'s `.waking` phase, `wakingOutput`, already producing
`eyeState`/`earState` progressively — this sequence's body beat slots in
alongside that existing progression, not instead of it). **Needs zero new
`bodyState` strings** — `stretch` and `arch` are both already in [the body
pose pipeline's tuple table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
(`(1.22, 0.82, +0.3, 0, +0.6, 1.0)` and `(1.18, 0.83, +0.35, 0, -0.3, 1.0)`
respectively) — this is pure sequencing + trigger wiring, the cheapest
feature in this doc.

| Beat | Duration | `bodyState` / states | Detail |
|---|---|---|---|
| Reach | ~0.5s | `stretch` | Front-biased elongation, front paw-beans slide forward 2-3pt (`pawStates` dict, not a new controller) |
| Shiver + yawn | ~0.5s | `arch` (torso) + `mouthState = "yawn"` (existing, `procedural-animation.md` confirms shipped) + `eyeState = "closed"` | 0.3pt high-frequency tremor riding the `shiver` dynamic tuple |
| Strop/settle | ~0.4s | eases back to `stand` | Brief `xScale` wobble (shoulder-roll read), then one slow-blink (existing `slow_blink` choreography, `BehaviorChoreography.applySlow​Blink`) |

Total ~1.4s, matching the dossier's number. **Play-bow telegraph** (the
"fun incoming" 400-700ms beat before zoomies/laser/invitations/pounces) is
a **separate, shorter** use of the same `arch`-adjacent shape family but
belongs to [hunt & pounce](/SYSTEMS/hunt-and-pounce.md) and [emotional body
language](/SYSTEMS/emotional-body-language.md)'s arch-grammar (fright vs.
play parameterization of one render) — cross-linked, not duplicated here;
this doc only owns the **wake** stretch, not the play-invitation one.

## 3.1 Stage Gating

| Stage | Variant |
|---|---|
| Egg | N/A — the hatch ceremony owns its own wake |
| Drop | Squash-and-rebound "boing" wake (reuses Drop's existing perpetual hop mechanic as the wake gesture, not a new one) |
| Critter | Slightly stiff, shortened reach (~1.0s total) — "first true stretch" |
| Beast | Full ~1.4s theatrical version, largest `arch` amplitude via the stage scalar already tabled |
| Sage | Single unhurried arch, no separate yawn beat, ~1.8s (slower, per Sage's restrained-amplitude/longer-ease convention established in [body pose pipeline §3](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)) |
| Apex | Stretch briefly lifts `positionY` by [its own 2pt hover cap](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension) — gravity-release read, not a jump |

# 4. Sleep Geography

Where and how the creature sleeps becomes a visible trust signal on the
1085pt bar — but the **bond tier** input (New/Familiar/Devoted) this
feature keys off is a **derived stat owned by [personality &
emotional-state](/REFERENCE/personality-emotional-state.md)**, not built
yet as of this wave (it is that concept's dossier-assigned deepening item:
pet-streak + touch milestones + days-known collapsed to one tier). This
doc consumes that tier once it exists; it does not define it. The raw
ingredients already exist and are real numbers today —
`MilestoneTracker`'s touch thresholds (`Input/MilestoneTracker.swift:26-33`:
`first_touch`=1, `finger_trail`=25, `petting`=50, `laser_pointer`=100,
`belly_rub`=250, `pre_contact_purr`=500, `touch_mastery`=1000) and
`PetStreak` (`Input/CreatureTouchHandler.swift:26,91`) — but no code
today collapses them into a tier enum.

| Tier (pending [personality-emotional-state.md](/REFERENCE/personality-emotional-state.md)'s definition) | Sleep location on the 1085pt bar | Posture | Facing |
|---|---|---|---|
| New | Far end from the P button | Curl (tightest rung, [§2](#2-resting-posture-ladder)) | Outward, away from the button |
| Familiar | Mid-bar, back against a favorite world object (`AttractionScorer`'s existing 7-factor score, `World/AttractionScorer.swift`, picks the object) | Loaf | Toward the object |
| Devoted | Within 12pt of the P button | Sprawl (most vulnerable rung) | Toward the button |

Weather modulates independently of tier: `WeatherSystem.current == .rain`
or `.storm` relocates the sleep spot to the nearest world object flagged
as shelter (needs a shelter-capable flag added to [the world objects
system](/SYSTEMS/world-objects-system.md)'s 20 presets — not assumed to
exist); `.snow` or low ambient temperature (no temperature scalar exists
yet independent of weather type — this doc treats `.snow`/`.storm` as the
cold proxy until one is designed) forces the Curl rung regardless of tier.

**Mechanically:** on entering `.resting`, a one-time destination pick
(reusing the existing `selectDestination()`/walk-to-point machinery
`AutonomousLayer` already has for ordinary wandering) walks the creature
to its tier's spot *before* the posture settles — sleep is preceded by a
short walk, not an instant teleport. [Camera
dwell](/SYSTEMS/camera-and-parallax.md) (stopping the tracking re-center
while a sleeper sits off-center) is a prerequisite this doc flags but does
not own — without it, an off-center New-tier sleeper gets re-centered by
the camera every frame, defeating the entire visible-trust-signal point.

## 4.1 Stage Gating

| Stage | Variant |
|---|---|
| Drop | Puddle-flatten (`(0.70, 1.25, ...)`-shaped, reusing the Sprawl tuple's silhouette family at reduced amplitude) regardless of tier — Drop has no location choice yet (pre-directed-movement) |
| Critter/Beast | Full location+posture ladder as tabled |
| Sage (Devoted) | Levitation-sleep: 1pt off the ground, `auraState = "pulse"` (Dusk-tinted, per [body pose pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) |
| Apex | Sleep alpha drops to 0.6 — on true OLED black this half-dissolves into void, leaving only the breathing outline (an `alpha` write on the root node, distinct from and layered on top of §5's aura pulse) |

# 5. Dream Theater — somatic twitch per dream pattern

Gives each of `DreamEngine`'s **already-computed** `DreamPattern` cases
(§0's 15-case reality, not the dossier's assumed chase/hunt/social/storm
taxonomy) a distinct somatic channel during the `.dreaming` phase, instead
of the single uniform 10s-interval twitch pulse that runs today
(`dreamingOutput(twitching:)`, `DreamEngine.swift:404-415`). This is a
**mapping this doc introduces** to make "dream content" mean something
visible — flagging it explicitly since it is an interpretive bridge, not
a 1:1 reflection of an existing design document (none maps this pairing
today).

**Which `DreamPattern` maps to which category is owned by
[journal-and-dreams.md](/REFERENCE/journal-and-dreams.md#dream-theater--somatic-categories-mapped-to-dreamengine-content)**
— this section previously carried its own copy of that assignment, and it
had drifted from journal-and-dreams.md's (e.g. `.streakBuilding` landed in
different somatic buckets in each doc). That doc is the correct owner: it's
the one that actually reasons about what `DreamEngine`'s content *is*, this
one only renders it. This section's job is narrower — what each of
journal-and-dreams.md's five categories (Paddle, Flick-and-track, Suckle,
Shiver-and-tighten, Still) actually does to the body:

| Somatic category (assignment owned by journal-and-dreams.md) | Motion |
|---|---|
| Paddle | Front paws paddle alternating 1pt strokes @ ~2Hz, 2-3s bursts every 20-40s (`pawStates` alternation, no new controller) |
| Flick-and-track | Tail-tip flicks ~8deg + whisker tremble (reuses `whiskerTwitch: Bool`, already a live `DreamOutput` field, `DreamEngine.swift:30`) |
| Suckle | Tiny mouth `suckle` (new `mouthState` literal, alongside existing `lick`/`closed`/`yawn`) + soft ear swivel every 15-25s |
| Shiver-and-tighten | 300ms full-body shiver (reuses the `shiver` dynamic tuple) then the curl rung tightens by one increment |
| Still | No category-specific motion beyond the existing uniform twitch — these patterns are dream-text-only today and stay that way; forcing a somatic read onto them would misrepresent it |

All amplitudes 0.5-1pt, riding the vector sub-pixel advantage already
established in [the body pose pipeline](/SYSTEMS/body-pose-pipeline.md).
Occasional (not per-pattern-gated — a flat 5% roll per `twitchInterval`
tick) half-woken head-lift: `headOffset` +0.4pt for 400ms via the same
delta-pattern `updateNoiseIdle`/[body pose pipeline
§2](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)'s
`headOffset` already uses, then a flop-back exhale (`yScale` 1.04→0.98
over 800ms, riding [the compose point](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula)).

**Does not duplicate:** the wake-time fragment bubble, the nightly
`dream`-type journal text (`DreamTemplates.generate`), or the designed
trick-replay/offline-replay mechanics — this is exclusively the somatic
layer that runs *underneath* all of those while `.dreaming` is active.

## 5.1 Stage Gating

| Stage | Variant |
|---|---|
| Drop | Whole-body pulse twitches only (no per-category differentiation — Drop predates the dream system's own `stageMin` gates on most autonomous behaviors) |
| Critter+ | Full category-mapping table above |
| Sage/Apex | Additionally leaks 1-2 Dusk-tinted motes drifting upward from the body — one pooled emitter, reused rather than allocated per-dream (per [grounds[1]](#citations)'s particle-pooling hard rule) |

# 6. Sunbeam & Warm-Spot Seeking

**Naming correction against the dossier:** there is no `.sunny`
`WeatherType` case — `WeatherSystem.WeatherType`
(`World/WeatherSystem.swift:15-20`) is `clear`, `cloudy`, `rain`, `storm`,
`snow`, `fog`. This feature keys off `weather == .clear` combined with
`SkySystem.TimePeriod` in `{.morning, .day, .goldenHour}` (excluding
`.dawn`/`.dusk`/night periods, when there is no beam to seek) — not a
weather case that does not exist.

On qualifying onset, a beam-x signal (a single low-alpha gradient node,
Gilt/Ember lerp per [grounds[1]](#citations)'s palette rule, no new
color) appears at a pseudo-random x on the 1085pt bar. The creature
walks to it (reusing working X-locomotion — `BlendController`'s existing
integration, no new movement code) and settles into the **Sprawl** rung
from [§2](#2-resting-posture-ladder) — this feature is a **consumer** of
the Resting Posture Ladder's Sprawl tuple, not a second definition of it.
Every 20-40s the beam drifts a few pt; the creature cracks one eye
(`eyeLeftState`/`eyeRightState` set to different values — no new
capability needed, `PushlingScene.applyBehaviorOutput` already drives
`eyeLeftController`/`eyeRightController` independently per side; this
feature is simply the first to deliberately use that existing
independence rather than always setting both eyes identically), sighs
(bigger breath via
`breathPeriodOverride`), heaves up, shuffles 3-6pt, flops back into
Sprawl. Cloud-over (`weather` transitions away from `.clear`) fades the
beam and droops both ears.

## 6.1 Stage Gating

| Stage | Variant |
|---|---|
| Egg/Drop | N/A (Drop can do a stationary "bask puddle" — flattens in place using its own puddle tuple from [§2.1](#21-stage-gating), no beam-seeking walk) |
| Critter | Seeks and loafs in the beam (Loaf rung, not Sprawl — Critter's ladder withholds Sprawl per [§2.1](#21-stage-gating)) |
| Beast | Full belly-sprawl + migration comedy as tabled |
| Sage | Meditates in the beam (`meditation` choreography substituting for Sprawl) rather than chasing its drift |
| Apex | Generates its own warm `auraState = "warm"` glow (existing tuple, [body pose pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) and basks anywhere, weather-independent |

# 7. Crepuscular Territory Patrol

A scheduler/motivation reskin of the fully-working destination-wandering
machinery ([§0](#0-todays-baseline-code-verified-ground-truth)'s
`.walking` state) — no new locomotion code, only a purposeful waypoint
sequence and an investigative carriage layered on top of the existing
walk. Gated to `SkySystem.TimePeriod` in `{.dawn, .dusk}` (the live clock,
not dead `CircadianCycle`, per [§0](#0-todays-baseline-code-verified-ground-truth)),
biased further by the Discipline personality axis toward regularity.

**Waypoint sequence:** every placed world object (`World/
AttractionScorer.swift` already scores them) plus both screen edges, in
sequence, at the stage's `baseWalkSpeed` reduced ~40-55% for an
investigative trot (Critter 15pt/s → ~7-8pt/s patrol speed, Beast 25pt/s
→ ~11-14pt/s, using [`LayerTypes.swift:45-52`](#citations)'s exact
per-stage `baseWalkSpeed` table as the baseline the reduction applies to).
At each waypoint: 1-2s sniff pause (small 0.3pt nose-bobs via
`headOffset`, whiskers-forward), then either a **bunt** — reusing the
existing but currently-clobbered `headbutt` `BehaviorChoreography`
(`applyHeadbutt`, `bodyState = "stretch"` at 60%+ progress, `duration:
1.5...1.5` per `BehaviorSelector.swift:159-162` — this feature is
exactly the autonomous home the dossier says that choreography lacks
today, since it currently only fires via the `IdleRotationGovernor`'s cat-
behavior pool with no waypoint context) plus a 1px pooled scent-glow
fading over ~3s — or a satisfied tail-flick and move on. Ends by returning
to whatever [Resting Posture Ladder](#2-resting-posture-ladder) or [Sleep
Geography](#4-sleep-geography) spot is appropriate for the time of day.

## 7.1 Stage Gating

| Stage | Patrol scope |
|---|---|
| Egg/Drop | N/A (rooted) |
| Critter | Short, 2-3 waypoints near the sleep spot |
| Beast | Full-strip patrol, most thorough sniffing/bunting |
| Sage | Sparse — fewer stops, each held 2-3x longer (contemplative, not perimeter-anxious) |
| Apex | Drifts/floats the perimeter (`positionY` hover per [body pose pipeline §4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)'s 2pt cap) and marks with aura-glow instead of a cheek-bunt |

# 8. Evening Wind-Down Ritual

Triggered by `SkySystem.TimePeriod == .evening` AND `EmotionalState.energy
< 40`, an interruptible 90-150s sequence — interruptible by any real
activity per the presence ethos's never-locks rule, exiting cleanly back
to whatever state fired mid-sequence. High-Discipline creatures run it
within the same 10-minute real-clock window nightly (a `Personality
.discipline`-scaled jitter band around the first `.evening` tick, not a
fixed clock alarm — `SkySystem.TimePeriod.evening`'s own `startHour` is
already fixed, so "same time nightly" falls out naturally from a
consistent trigger point plus a narrow jitter).

| Step | Duration | Mechanism |
|---|---|---|
| (a) Long stretch | 1.4s | Reuses [§3](#3-stretch-ritual-grammar)'s Reach beat exactly — not a second stretch definition |
| (b) Grooming | ~3-5s | Reuses the existing shipped `grooming` choreography (`BehaviorChoreography.applyGrooming`, `bodyState = "stand"` — appendage-only today, unaffected by this doc), with a body-lean addition (`xScale` +0.03 toward the licked side) as this feature's one new increment |
| (c) Walk to spot | Variable | Reuses [Sleep Geography](#4-sleep-geography)'s tier-based destination walk |
| (d) Decreasing circles | ~3s | `zRotation` sweeps 720-1080deg shrinking to a 2pt-radius settle — the one channel that already survives `updateWorld`'s clobber unmodified per [the body pose pipeline's dropped-wire analysis](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth), so this step works even if the body pose pipeline has not shipped yet |
| (e) Kneading | ~10s | Reuses the shipped "Kneading Session" surprise (`Surprise/CatSurprises.swift:105-118`, id 32, `stageMin: .critter`, `cooldown: 600`, `duration: 10.0`) **if** a soft world object is present within range — this feature is a new caller of that surprise's animation closure outside its normal random-surprise-roll path, not a duplicate |
| (f) Settle and curl | 1.5-3s | [Resting Posture Ladder](#2-resting-posture-ladder)'s Curl rung, handing off directly into `.resting`/`.dreaming` |

If the [designed-but-unbuilt evening campfire](#citations) (40%/evening
spawn roll, per grounds[2]) has spawned that night, steps (c)-(f) target
it instead of the tier-based sleep spot, and the curl faces the flames.

## 8.1 Stage Gating

| Stage | Variant |
|---|---|
| Drop | Two-step only: wobble, then puddle-flatten |
| Critter/Beast | Full six-step sequence |
| Sage | Replaces step (d)'s circling with one slow bow |
| Apex | The whole ritual is a 10s alpha fade 1.0→0.6 while curling — dissolution into void, not a discrete step sequence |

# What This Concept Does Not Cover

- **How any `bodyState` tuple actually renders** — every pose target named
  above (`stand`/`sit`/`loaf`/`curl`/`sleep_curl`/`stretch`/`arch`/
  `roll_side`/`shiver`/`shake`, plus this doc's new `sprawl`/`sphinx`
  literals) is a consumer of [the body pose
  pipeline](/SYSTEMS/body-pose-pipeline.md)'s compose point and transform
  table, not a redefinition of it.
- **Why a mood looks the way it does** — the valence/arousal posture
  modifier (hipHeight/spineCurve/headPitch/tailCarriage/gaitBounce) that
  further shapes every pose scheduled here belongs to [emotional body
  language](/SYSTEMS/emotional-body-language.md).
- **The bond-tier derivation** ([§4](#4-sleep-geography)'s New/Familiar/
  Devoted) — owned by [personality &
  emotional-state](/REFERENCE/personality-emotional-state.md)'s dossier-
  assigned deepening, not authored here.
- **Camera dwell for off-center sleepers** — flagged as a prerequisite in
  [§4](#4-sleep-geography), owned by
  [camera-and-parallax.md](/SYSTEMS/camera-and-parallax.md).
- **The play-bow pre-invitation telegraph** and the fright/play arch
  render — both belong to [hunt & pounce](/SYSTEMS/hunt-and-pounce.md) and
  [emotional body language](/SYSTEMS/emotional-body-language.md)
  respectively; this doc's Stretch Ritual Grammar owns only the *wake*
  stretch.
- **The unified ambient-event governor** that keeps this doc's autonomous
  triggers (patrol, sunbeam-seeking, wind-down) from stacking with bug
  spawns/play bouts/invitations into a needy creature — owned by
  [invitation-system.md](/SYSTEMS/invitation-system.md)'s dossier-assigned
  deepening.

# Citations

[1] `Pushling/Sources/Pushling/Behavior/AutonomousLayer.swift` (`updateIdle:370-397`, `updateDwell:334-366`, `updateResting:463-494`, `regenerateStateDuration:589-617`, `updateWalking:254-332`)
[2] `Pushling/Sources/Pushling/Behavior/AutonomousLayer+Dreaming.swift` (`updateDreaming`, `shouldBeginDream`, `beginDreamCycle`, `applyDreamOutput`)
[3] `Pushling/Sources/Pushling/Behavior/DreamEngine.swift` (`DreamPattern`, `checkGates`, `resolveDreamPattern:302-329`, `dreamingOutput:404-415`, timing constants:46-57)
[4] `Pushling/Sources/Pushling/Behavior/BehaviorStack.swift` (`setSleeping:363-369`, confirmed zero external call sites)
[5] `Pushling/Sources/Pushling/Scene/PushlingScene.swift` (`applyBehaviorOutput:810-838`, `creature.setSleeping` read at line 820)
[6] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`updateNoiseIdle:284-304`, `noiseAmps:57`, `isSleeping:14`, `setSleeping:399`)
[7] `Pushling/Sources/Pushling/Creature/CircadianCycle.swift` (full file — confirmed zero callers of `currentPhase`/`shouldBeSleeping`/`wakeSequence` outside itself and `DebugActions.swift:502`)
[8] `Pushling/Sources/Pushling/World/SkySystem.swift` (`TimePeriod:14-23`, `startHour`)
[9] `Pushling/Sources/Pushling/World/WeatherSystem.swift` (`WeatherType:15-20` — confirms no `.sunny` case)
[10] `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift` (`applyLoaf:135-143`, `applyMeditation:145-`, `applyHeadbutt:211-`, `applyGrooming:117-133`)
[11] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift` (durations: `headbutt` 1.5s, `predator_crouch` 2.0s, `loaf` 30-60s, `if_i_fits_i_sits`/`meditation` 10-20s)
[12] `Pushling/Sources/Pushling/Surprise/CatSurprises.swift` (`kneadingSession:105-118`, id 32, cooldown 600s, duration 10s)
[13] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`baseWalkSpeed:45-52` — Egg 3, Drop 8, Critter 15, Beast 25, Sage 20, Apex 22 pt/s)
[14] `Pushling/Sources/Pushling/Input/MilestoneTracker.swift` (touch thresholds:26-33)
[15] `Pushling/Sources/Pushling/World/AttractionScorer.swift` (7-factor object attraction, reused for Familiar-tier sleep spot and patrol waypoints)
[16] `docs/SYSTEMS/body-pose-pipeline.md` (`bodyState` transform tuple table, compose point, stage amplitude scalars — this doc's rendering dependency)
[17] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds[0]` (body-movement baseline), `.grounds[1]` (hard constraints), `.grounds[2]` (shipped/designed feature landscape); `.proposals[0]` (Idle Life Layer), `.proposals[1]` (Resting Posture Ladder, Wake Stretch & Strop, Sunbeam & Warm-Spot Seeking, Crepuscular Territory Patrol), `.proposals[4]` (Sleep Geography, Dream Theater, Evening Wind-Down Ritual)
[18] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` lines 32-35, 65-72, 95-96, 109-110, 157-158, 168-169 (this concept's dossier spec and covered-feature pitches)
