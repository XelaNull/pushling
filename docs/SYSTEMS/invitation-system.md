---
type: System
title: Creature Invitation System
description: Scheduling, the 6 invitation types, personality-weighted selection, and the offer/accept/timeout lifecycle the creature uses to initiate interactive moments — the real-state wiring the selection logic never receives — plus the unified ambient-event governor (invitations, bug spawns, play bouts, patrols, rituals, glances share one cooldown pool) and play-bow as the universal pre-invitation telegraph.
status: Live
tags: [touch, invitations, governor, ambient-events, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the authority for **creature-initiated interactive moments** —
when they fire, which of the 6 types gets picked, and how they resolve if
ignored. Source: `Input/InvitationSystem.swift`, wired only from
`Input/CreatureTouchHandler.swift`.

# Scheduling

Checked once every 60 seconds (`checkInterval`) while no invitation is
currently active. Guard conditions, in order: not sleeping, no mini-game
active, no evolution ceremony active, Claude not AI-directing, activity
within the last 5 minutes (`activeUseWindow`), and at least 20 minutes
(`cooldownDuration`) since the last invitation. If all pass, a probability
roll decides whether one fires: base 3% (`baseProbability`), doubled to 6%
(`droughtProbability`) once more than 40 minutes (`droughtThreshold`) have
passed since the last invitation — and a further +1% for
high-energy creatures (`personality.energy > 0.6`).

**The guard/weighting inputs are never updated with real creature state.**
`InvitationSystem.creatureStage`, `.personality`, `.emotions`,
`.isSleeping`, `.isMiniGameActive`, `.isCeremonyActive`, and
`.isAIDirecting` are all public `var`s intended to be kept in sync by the
owner, but `CreatureTouchHandler` — the only place that holds a reference
to this system — never assigns any of them (grep-verified: no
`invitationSystem.creatureStage = `, `.personality = `, etc. anywhere).
Every one of these fields sits at its type's default for the life of the
process: `creatureStage = .critter`, `personality = .neutral`,
`emotions = .neutral`, and the three booleans all `false`. Practical
consequences:

- Invitation type selection (below) always uses the neutral
  personality/emotion weights — the "high-curiosity creatures favor
  exploration invitations" behavior described in the plan doc cannot
  currently differ creature-to-creature or moment-to-moment.
- Because `isMiniGameActive` and `isCeremonyActive` never flip true, the
  scheduler's own guard against firing during a mini-game or evolution
  ceremony is dead — `CreatureTouchHandler.update(deltaTime:currentTime:)`
  calls `invitationSystem.update(...)` unconditionally, including while
  `miniGameManager.isGameActive` is true, so an invitation could in theory
  begin its setup animation mid-game. (In practice this is rare given the
  low base probability and the 20-minute cooldown, but the guard exists in
  the code for exactly this case and is currently unreachable.)
- `creatureStage` frozen at `.critter` means the stage-gate filter in
  `selectInvitationType()` (below) always evaluates as if the creature
  were Critter-stage, regardless of its real stage — a Beast+ creature
  would never actually see `fishOffering` selected by this mechanism, and
  a Drop-stage creature would incorrectly be offered `ballPush`/`newWord`/
  `stuckOnTerrain` (all gated `>= .critter`) before it should.

This is flagged for `DECISIONS.md`/the Orchestrator as a wiring gap, not a
design question — the fix is straightforward (thread real stage/
personality/emotion/sleep/game-state updates into these properties each
frame or on change) once claimed.

# The Unified Ambient-Event Governor

The Phase-2 dossier's Risks section names a specific failure mode: the
idle layer, play bouts, bug spawns, crepuscular patrols, the golden-hour
and wind-down rituals, and check-in glances each individually respect
sparseness, but summed together they can read as a busy, needy creature —
the opposite of the presence ethos every one of those docs claims to
serve. The fix the dossier mandates is a single shared cooldown pool,
anchored on this system (the only piece of the family that's actually
shipped) rather than five independently-reinvented timers. This section
is that governor's design — **designed, not built**, same status as every
mechanism below it.

**Hard prerequisite: the guard-wiring gap above must close first.** A
governor that arbitrates *when* ambient events may fire is only as
trustworthy as the guards each event's own scheduler checks before firing
— and [the wiring gap documented above](#scheduling) means
`InvitationSystem`'s own guards (`isSleeping`, `isMiniGameActive`,
`isCeremonyActive`, `isAIDirecting`) are dead today. Every sibling
scheduler below either checks these same four conditions directly
(`ambient-wildlife.md`'s spawn governor cites the identical guard list) or
inherits them structurally through the behavior-stack priority order
([behavior-stack.md](/SYSTEMS/behavior-stack.md)). Wiring real state into
`InvitationSystem` is therefore not just this system's own fix — it is the
one change that makes every other ambient scheduler's guard promise real
at the same time. Building the shared-pool mechanics below on top of
unfed guards would produce a governor that correctly prevents *type A*
and *type B* from firing in the same 90-second window, while both still
fire during sleep — solving stacking while leaving the more basic problem
unsolved. Sequence: fix the guards, then land the pool.

**The pool: a cross-type floor over each family's own cadence.** Every
family below keeps its own recurrence cadence (owned and cited by its own
doc) unchanged — the pool does not replace or override any of these
numbers. What the pool adds is a single new rule: no two *different*
event families may **begin** within 90 seconds of each other, tracked as
one shared `lastAmbientEventTime` + `lastAmbientEventType` pair that every
family's scheduler both reads (as a guard) and writes (on firing) —
generalizing the coordination [`ambient-wildlife.md`'s Spawn
Governor](/SYSTEMS/ambient-wildlife.md#spawn-governor) already designed
one-directionally against this system's `lastInvitationTime` (a 30s
buffer, one-way). 90 seconds is chosen to comfortably clear the longest
single active-event window in the family — an invitation's own worst case
is `1.0s setup + 10.0s offer = 11.0s` (the 3.0s `cue` repeats *within* the
offer window, it doesn't extend it — [Lifecycle](#lifecycle) below) — with
wide margin, while staying far shorter than any *floor-subject* family's
own repeat-cooldown (the shortest of which is the wildlife spawner's 300s
minimum respawn — still >3x the floor), so the floor is never the
practically-binding constraint for a family repeating *itself* — it only
matters at the seams between different families. (Check-In Glances' 2-6
minute cadence is faster still, which is exactly why glances are exempt
from the floor rather than folded into this comparison — see below.)

| Event family | Owning concept | Own recurrence cadence (unchanged, cited by its own doc) | Subject to the 90s cross-type floor? |
|---|---|---|---|
| Invitation | this doc | 60s check tick, 20-min `cooldownDuration`, 3%/6% roll | Yes — anchors the pool (`lastAmbientEventTime` IS `lastInvitationTime` when an invitation fires) |
| Bug/wildlife spawn | [ambient-wildlife.md](/SYSTEMS/ambient-wildlife.md#spawn-governor) | random 300-600s (5-10min) respawn, 1 concurrent slot | Yes — already designed as a 30s one-way buffer against invitations specifically; generalizes to the full 90s floor against every family here |
| Play bout | [play-bouts.md](/SYSTEMS/play-bouts.md) | ~1 per 15-20 min (its own open composition question, addressed below) | Yes |
| Crepuscular patrol | [idle-life-and-rest.md §7](/SYSTEMS/idle-life-and-rest.md#7-crepuscular-territory-patrol) | at most once per `SkySystem.TimePeriod.dawn` window, once per `.dusk` window | Yes — mutually exclusive with the Golden Hour ritual below inside the same dawn/dusk window by construction (both are once-per-window; the floor decides which goes first if both would fire at the window's open) |
| Golden Hour / Evening Wind-Down ritual | [environment-reactions.md](/SYSTEMS/environment-reactions.md), [idle-life-and-rest.md §8](/SYSTEMS/idle-life-and-rest.md#8-evening-wind-down-ritual) | Golden Hour: once per dawn, once per dusk. Wind-Down: once nightly, scheduled not rolled | Yes — Golden Hour's own spec already states a 10-minute invitation-suppression window, tighter than the floor; the floor is the fallback for the other four families it didn't already consider |
| Check-in glance | [companionship-rituals.md §5](/SYSTEMS/companionship-rituals.md#5-check-in-glances--social-referencing) | every 2-6 active minutes (~10min during Flow Loaf) | **No — exempt.** See below |

**Why glances are exempt, not just another row.** A glance is a 1.5-3s
quarter-turn-and-blink that resumes exactly where the creature was — the
lowest-cost, lowest-visibility event in this entire family, closer to a
tic than a behavioral takeover. Gating it behind the same 90-second
cross-family floor as an invitation or a patrol would mean the creature
visibly ignores the developer for stretches at a time for no aliveness
gain — the opposite of what a governor protecting against neediness
should do. Glances instead carry only their own two guards: (1) their own
2-6 minute self-cadence, and (2) "no *major* ambient event is currently
active" (an invitation mid-offer, a bug hunt, a play bout, a patrol, or a
ritual) — checked, not counted. A glance firing does **not** write
`lastAmbientEventTime`, so it never blocks a major event from starting
immediately after one.

**Resolving play-bouts.md's open composition question.** That doc
correctly flags a real risk: its proposed ~15-20 minute bout cap sits
beside the already-shipped 300-second `interactionCooldown`
(`ObjectInteractionEngine.swift:163-167`) that throttles every toy
interaction generally, and if a bout maintained an independent timer a
creature could read as playing twice inside six minutes. This doc doesn't
re-litigate that fix — play-bouts.md's own proposal (a completed bout sets
`lastInteractionTime` the same way an ordinary interaction does, sharing
one clock rather than two) is the correct move and this governor assumes
it. The one addition the shared pool makes on top: a completed bout should
*also* write this doc's `lastAmbientEventTime`, so a bout ending doesn't
leave the door open for a bug to spawn or a patrol to begin in the same
breath — two different kinds of "the creature is now doing an ambient
thing" back to back reads exactly as needy as one type repeating itself.

# Play-Bow: the Universal Pre-Invitation Telegraph

The dossier's Stretch Ritual Grammar proposal makes the play-bow —
front-end sinking while the rear rises, tail high and flicking, held
around 400ms — the universal "something fun is about to happen" cue,
firing 400-700ms before zoomies, laser-pointer engagement, pounce
sequences, **and invitations**. This doc owns the *when* for the
invitation case only; the render grammar itself (the shear approximation,
the shared arch/sproing parameterization) belongs to [hunt &
pounce](/SYSTEMS/hunt-and-pounce.md) and [emotional body
language](/SYSTEMS/emotional-body-language.md) respectively, per
[idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md)'s own disclaimer —
this doc does not re-author the pose tuple.

**Integration point:** the existing `setup` phase of the lifecycle below
already has a fixed 1.0s budget with nothing to fill it beyond each type's
own setup animation (walk to the ball, spawn the glowing object, etc. —
[the per-type table above](#the-6-invitation-types)). The play-bow occupies
the *first* 400-700ms of that existing 1.0s window, common to all 6 types,
before the type-specific setup animation resolves in the remaining
300-600ms — no new phase, no change to the 1.0s total, no new timer. Like
every other piece of per-type setup detail in this doc, this is
**designed, not implemented**: `InvitationSystem` itself only emits the
lifecycle events (`.setup`/`.offer`/...) with no consumer of
`onInvitationEvent` to drive any of it, play-bow included.

# The 6 Invitation Types

| Type | Minimum Stage | Selection Weight Bias (when personality/emotion inputs are live) |
|---|---|---|
| `ball_push` | critter | +0.5 if `emotions.energy > 60`, +0.3 if `personality.energy > 0.6` |
| `glowing_object` | drop | +0.5 if `emotions.curiosity > 60`, +0.3 if `personality.focus > 0.6` |
| `new_word` | critter | +0.5 if `personality.verbosity > 0.5` |
| `stuck_on_terrain` | critter | fixed weight 0.8 (slightly less common) |
| `fish_offering` | beast | +0.3 if `emotions.contentment > 50` |
| `commit_release` | drop | fixed weight 0.5 |

All types start at a base weight of 1.0 before biases apply; selection is
a weighted random draw over whichever types pass the stage filter (which,
per the wiring gap above, currently always evaluates against `.critter`).
`InvitationSystem` itself only emits lifecycle events
(`.setup`/`.offer`/`.accepted`/`.selfResolved`/`.timeout`/`.cue`) —
verified with no consumer of `onInvitationEvent` anywhere in the searched
code. The lifecycle machinery above is real and complete; every type-specific
animation, particle effect, and reward below is **designed, not
implemented** (`PUSHLING_VISION.md`'s "Creature-Initiated Invitations"
table and `PHASE-6.md`'s P6-T3-02/03):

| Type | Setup | Accept Gesture | Interaction | Reward | Self-Resolution (ignored) |
|---|---|---|---|---|---|
| `ball_push` | pushes a ball toward the screen edge, looks up at the human | flick the ball back | fetch — chase/push-back, 3-5 volleys | +5 satisfaction, +3 contentment per volley | bats the ball around solo (3 swats), it rolls away |
| `glowing_object` | a Dusk-colored, pulsing 4pt object spawns; creature sniffs cautiously, backs away, looks at human | tap the glowing object | object transforms — random from 5 types (hatches into a butterfly, opens into a flower, splits into sparkles, reveals a music box); 2s spectacle | +8 curiosity, +5 satisfaction; the transformation result may persist as a temporary world object for 5 minutes | approaches, paws cautiously, object dissolves into harmless sparkles |
| `new_word` (Critter+) | creature says a new word hesitantly with a trailing `"?"`, looks at human | tap the creature (encouraging) | word's bubble text goes from 50% to 100% opacity with a Gilt outline flash; word is added to the creature's active vocabulary | +5 contentment, word permanently learned | word fades, creature shakes its head slightly, tries again later — word is **not** added |
| `stuck_on_terrain` (Critter+) | walks to a terrain object (rock/log), can't pass, paws at it, silent meow | tap the obstacle | obstacle slides aside 2pt (physics), creature squeezes through, grateful, tail up | +3 contentment, +2 satisfaction | backs up, takes the long way around, slightly exasperated |
| `fish_offering` (Beast+) | holds up a small Tide-colored fish sprite (3pt), offers it toward the screen edge | tap the fish | fish "accepted" — flies toward the edge and disappears, tallied in a `fish_accepted` SQLite counter; creature purrs with pride | +5 satisfaction, +3 contentment; **every 5th accepted fish is a "golden fish" worth double** | eats the fish itself, satisfied but less so than an accepted gift |
| `commit_release` | during commit arrival, crouches with a butt wiggle, waiting | tap to "release" the commit (like saying "go!") | pounces with 1.5x normal pounce arc — more dramatic than autonomous eating | +10% XP bonus (stacks with the hand-feeding bonus if both apply — see [the gesture-response map](/REFERENCE/gesture-response-map.md#hand-feeding-not-a-gesture-type--a-parallel-touch-start-path)), +3 satisfaction | if not tapped within 3s, pounces on its own (normal eating sequence) |

**Global self-resolution rules (P6-T3-03), also unimplemented:** a
self-resolution is designed to be worth **half** the accepted-path's
satisfaction/contentment reward — never zero, and never a punishment for
ignoring the creature (no guilt mechanic) — preceded by a brief 0.5s
"well, okay then" expression. Self-resolutions are also designed to log
differently from accepted invitations, e.g.
`{"type": "invitation", "invitation_type": "ball_push", "accepted": false, "self_resolved": true, "timestamp": "..."}`,
versus an `accepted: true` entry for the accepted path — no such
distinction exists in any journal-write call site today (both paths only
reach `completeInvitation()`, which doesn't differentiate accepted from
self-resolved for logging purposes).

None of the setup/offer/accept/reward detail above, nor the per-type
accept gesture, is differentiated in code — see the Lifecycle section
below for what actually gates a response (a generic tap, regardless of
type).

# Lifecycle

```
setup (1.0s fixed duration)
  -> offered (up to 10.0s offerTimeout; a repeating "cue" every 3.0s)
     -> accepted (human tap on the creature while offered)          -> complete
     -> selfResolved (10s elapsed with no accept)                    -> complete
```

`acceptInvitation()` is the sole entry point for a human response — wired
from [the gesture-response map](/REFERENCE/gesture-response-map.md#tap)'s
tap-on-creature-during-offer case. There is no per-invitation-type accept
gesture beyond a generic tap (the plan doc's per-type accept actions —
flick the ball, tap the glowing object, tap the obstacle, tap the fish,
tap to "release" the commit — are not differentiated in
`InvitationSystem`; any tap on the creature while `.offered` accepts
regardless of type). `completeInvitation()` records `lastInvitationTime`
(the cooldown anchor) and clears `activeInvitation`, whether the
invitation was accepted or self-resolved — both paths reset the 20-minute
cooldown identically.

# Citations

[1] `Pushling/Sources/Pushling/Input/InvitationSystem.swift`
[2] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (the sole owner — `recordActivity`, `update`, `activeInvitation`, `acceptInvitation` call sites; absence of state-sync assignments)
[3] `PUSHLING_VISION.md` — "Creature-Initiated Invitations" table
[4] `docs/archive/plan/phase-6-interactivity/PHASE-6.md` — P6-T3-01/02/03
[5] [gesture-response map](/REFERENCE/gesture-response-map.md), [mini-games](/SYSTEMS/mini-games.md)
[6] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift:163-167` (`interactionCooldown`, the 300s cross-category cooldown play-bouts.md's composition question is resolved against)
[7] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` — Risks ("Presence-ethos stacking"), Stretch Ritual Grammar (play-bow telegraph), "Deepen Existing Concepts" entry for this doc
[8] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.proposals` — Stretch Ritual Grammar / Bug Season / Crepuscular Territory Patrol / Check-In Glances feature entries (governor-adjacent numbers)
[9] [ambient-wildlife.md](/SYSTEMS/ambient-wildlife.md), [play-bouts.md](/SYSTEMS/play-bouts.md), [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md), [environment-reactions.md](/SYSTEMS/environment-reactions.md), [companionship-rituals.md](/SYSTEMS/companionship-rituals.md), [hunt-and-pounce.md](/SYSTEMS/hunt-and-pounce.md), [emotional-body-language.md](/SYSTEMS/emotional-body-language.md) — the six ambient-event families sharing this doc's governor, and the two docs that own the play-bow render
