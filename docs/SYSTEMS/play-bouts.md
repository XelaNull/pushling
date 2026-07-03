---
type: System
title: Play Bouts & The Favorite
description: Autonomous, motivated solo play — the play-pressure meter and its guards/caps, the five-beat bout grammar (Notice/Stalk/Escalate/Climax/Wind-down), toy-specific climaxes (Yarnling Unspooled), and the per-object attachment model culminating in The Favorite. Designed, not built, on top of a real shipped substrate.
status: Future
tags: [play, behavior, autonomous, toys, attachment, system]
timestamp: 2026-07-03T00:00:00Z
---

This concept owns the creature's *desire* to play: the hidden play-pressure
meter that schedules solo play bouts, the five-beat Notice/Stalk/Escalate/
Climax/Wind-down grammar every bout runs, the two toy-specific payoffs
(Yarnling Unspooled's tangle struggle and The Favorite's attachment arc),
and how all of it composes with — rather than reimplements — three things
that already ship: the 7-factor `AttractionScorer`, the `ObjectWearSystem`
wear track, and `ObjectInteractionEngine`'s existing toy templates. It does
**not** own the predator stalk→pounce grammar itself (a Climax beat borrows
it — see [hunt-and-pounce](/SYSTEMS/hunt-and-pounce.md)), object caps/preset
catalog/legacy-shelf mechanics (see
[world-objects-system](/SYSTEMS/world-objects-system.md)), the bodyState
transform tuples every beat's pose ultimately resolves to (see
[body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md), **Designed, not
built** — every torso beat below is inert at render time until that
pipeline ships), or taught-behavior mechanics themselves (see
[teach-system](/SYSTEMS/teach-system.md)).

**Everything below the play-pressure meter and the five-beat wrapper is
design, not code** — a repo-wide search found no `playPressure`,
`PlayBout`, `FavoriteObject`, or `Yarnling` symbol anywhere in
`Pushling/Sources`. What follows marks every claim shipped/unbuilt inline,
with file:line for every shipped claim.

# 1. The Shipped Substrate (code-verified — what this concept builds on)

**Autonomous object interaction already exists**, and it is the load-bearing
mechanism a play bout would extend, not replace:
`AutonomousLayer.selectObjectInteraction()`
(`Behavior/AutonomousLayer+ObjectInteraction.swift:24-63`) scores every
placed object via `AttractionScorer.scoreObjects` (7 factors — base category
weight × personality affinity × mood modifier × recency decay × novelty
bonus × proximity × time-of-day, `World/AttractionScorer.swift:113-119`),
requires a total score ≥ **0.4** (`objectWanderThreshold`, line 21) to
override idle, and hands the winner to
`ObjectInteractionEngine.beginInteraction`
(`World/ObjectInteractionEngine.swift:173-224`), which enforces a **300s
(5-minute) global cooldown** (`interactionCooldown`, line 167) shared across
*all* 15 interaction categories — toy, furniture, decorative, interactive,
consumable alike, not toy-specific.

`ObjectInteractionEngine`'s **`chasing` template already contains a crude
proto-five-beat inside its own `interact` phase** (lines 340–357):
`progress < 0.3` → stalk (wide eyes, `tailState: "twitch_tip"`, ears perk at
Critter+), `progress < 0.5` → butt-wiggle (`tailState: "wag"`), else →
pounce (`bodyState = "pounce"`, `tailState: "high"`). This is real,
shipped, three-phase choreography data — but it is a single hardcoded
template, not a generic grammar any toy or bout can run, it has no Notice
or Wind-down beats, and (per
[body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth))
every `bodyState` it sets is silently dropped by
`PushlingScene.applyBehaviorOutput` today — only the `tailState` fragments
currently render.

**The 7-factor attraction score is not toy-restricted.** `categoryBaseWeights`
covers all 15 templates (`AttractionScorer.swift:43-52`), including
`sitting`, `hiding`, `eating` — a play bout consuming this scorer directly
must first filter to the toy subset (`batting_toy`, `chasing`, `carrying`,
`string_play`, `pushing`) before selecting a target, or it will occasionally
"play" with a scratching post.

**The wear track is real and already the right shape for Yarnling/The
Favorite to ride.** `ObjectWearSystem.applyInteractionWear` accumulates
0.0–1.0 wear at a per-category rate (`batting_toy: 0.03`, `string_play:
0.04` — the two categories a yarn ball would use — vs. `sitting: 0.01`,
`ObjectWearSystem.swift:104-120`), stages at `pristine → worn → weathered →
battered`, and the soft-delete "legacy shelf" (`is_active = 0, removed_at`
in `WorldManager+Objects.swift`, documented in
[world-objects-system](/SYSTEMS/world-objects-system.md#wear-repair--the-legacy-shelf))
is where a fully-worn Favorite would land for its farewell beat — no new
persistence lifecycle needed.

**Human-driven flick/pickup physics already exists and is the closest
thing to a "carry" rig in the codebase** (`Input/ObjectInteraction.swift`):
`flickObject` applies a mass-dependent impulse with gravity/friction/edge-
bounce (lines 43-46, 124-157) and dispatches a `.creatureChase` event the
autonomous layer can react to; `pickUp`/`moveHeld`/`dropHeld` (lines
161-243) lerp a held node toward a target point at `pickUpLerp = 0.85`
with a **2.0pt** float offset and a trailing shadow. **Correction to the
dossier's feasibility note:** this rig is touch/human-only — `pickUp`
takes a `touchPoint`, not a creature-mouth anchor — so The Favorite's
prance-carry cannot literally reuse it as-is; it can only repurpose the
same lerp-follow *pattern* (swap the follow target from finger position to
a `headNode`-relative offset). Separately, `ObjectInteractionEngine`'s
existing `carrying` template already plays a **4–6s** in-place carry
animation (`mouthState: "chew"`, `tailState: "high"`,
`ObjectInteractionEngine.swift:80-84, 359-366`) but never moves the object
— carrying-in-place ships today; carrying-to-a-destination does not.

**Correction: no "playfulness" personality axis exists.** The dossier and
design proposal both describe butt-wiggle count and tangle intensity as
scaling with "playfulness." `PersonalitySnapshot` has exactly four axes —
`energy`, `verbosity`, `focus`, `discipline`
(`Creature/PersonalitySystem.swift:91-100`) — and `AttractionScorer`
already keys every toy category's affinity off `energy`
(`personalityAffinities["chasing"] = ("energy", 2.0, 0.5)`, line 57). This
concept treats `energy` as playfulness's real, shipped stand-in throughout
— there is no separate axis to add.

# 2. The Play-Pressure Meter — Designed, Not Built

A hidden 0–100 pressure value, fed by `EmotionalState.energy` and
`EmotionalState.curiosity` (both 0–100, `Creature/EmotionalState.swift:26,
33`) plus time-since-last-play, personality-`energy`-weighted. No storage
column, accumulator, or scheduler exists for it today.

| Guard / cap | Value | Source of the number | Status |
|---|---|---|---|
| Minimum score to trigger a bout | 0.4 (reused `objectWanderThreshold`) | `AutonomousLayer+ObjectInteraction.swift:21` | Shipped (for object interaction generally); not yet toy-gated |
| Bout length (generic) | 30–90s | Dossier proposal | Designed |
| Bout cap | ~1 per 15–20 min | Dossier proposal | Designed — see composition note below |
| Existing cross-category interaction cooldown | 300s (5 min), all 15 templates share one timer | `ObjectInteractionEngine.swift:163-167` | Shipped |
| Existing ambient-event cooldown (reference point for the shared governor) | 20 min (`cooldownDuration`) | `Input/InvitationSystem.swift:67` | Shipped, different system |
| Presence guards | not sleeping/dreaming, no ceremony/mini-game, AI-Directed layer not active | Behavior-stack precedence | Structural (existing 4-layer priority — see [behavior-stack](/SYSTEMS/behavior-stack.md)), not a new check |

**Open composition question, flagged for Samantha/DECISIONS:** the ~15-20
min bout cap is a *new* number sitting directly beside the *existing* 300s
`interactionCooldown` that already throttles every toy interaction
(including plain `batting_toy`/`chasing` picks that aren't part of a
"bout"). If Play Drive schedules bouts through a separate timer, an
enthusiastic creature could play twice inside 6 minutes (once via a bare
attraction-score toy pick, once via a play-pressure bout) — reading as
needy rather than the "glimpsed delight" the pitch promises. The
straightforward fix is for a bout to *set* `lastInteractionTime` on
completion the same way a normal interaction does (so the two share one
cooldown clock), not maintain an independent one — a one-line
implementation note for whoever builds this, not a design change.

A new `AutonomousState.playBout(objectID:beat:)` case would sit alongside
the existing seven (`walking`, `idle`, `behavior`, `taughtBehavior`,
`objectInteracting`, `resting`, `dreaming` —
`Behavior/AutonomousLayer.swift:12-24`), entered only from `.idle`, exactly
mirroring how `.objectInteracting` is entered today.

# 3. The Five-Beat Bout Grammar

Every bout runs the same five beats regardless of toy; only the Climax beat
and its duration vary by toy type (§5–6). Numbers below are the dossier
proposal's visual spec — **none are wired to any controller yet**; the
`bodyState` column names the tuple each beat *would* resolve to once
[body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
ships (tuples quoted as `(yScale, xScale, yOffset, zRotation, headOffset,
pawAlpha)`, Critter-scale):

| Beat | Duration | Motion | `bodyState` tuple (once built) |
|---|---|---|---|
| **Notice** | 400ms | Full-body freeze mid-step, ears snap to target, pupils dilate | `alert` — `(1.05, 0.95, +0.2, 0, +0.25, 1.0)` |
| **Stalk** | until 4–8pt covered | Crouch-walk at 0.7 scaleY, half `baseWalkSpeed`, head counter-bobs level | `crouch` — `(0.72, 1.12, -0.6, 0, -0.2, 1.0)` (0.72 already matches the pitch's 0.7 scaleY almost exactly) |
| **Escalate** | ~1-2s | 2–3 quick paw-bats + 2pt side-hops | `crouch` held, driven by `pawStates` (mirrors `ObjectInteractionEngine`'s existing `chasing` stalk/wiggle sub-phases, lines 340-352) |
| **Climax** | toy-dependent, §5–6 | Pounce or grapple, per toy type | `pounce` — `(1.10, 0.92, +0.15, 0, +0.5, 1.0)`, or hands off to [hunt-and-pounce](/SYSTEMS/hunt-and-pounce.md)'s launch/catch grammar |
| **Wind-down** | ~2-3s | Sit, 3 deep breaths (`yScale` to 1.05), one shoulder groom, flop to loaf | `sit` → `loaf` — `(0.90,1.00,-0.3,0,+0.3,1.0)` → `(0.82,1.10,-0.35,0,-0.15,0.3)` |

`baseWalkSpeed` for the Stalk beat's "half speed" is stage-real:
`LayerTypes.swift:47-52` — Egg 3, Drop 8, Critter 15, Beast 25, Sage 20,
Apex 22 pt/s.

**Camera:** during an active bout the deadzone widens to **±25pt** so the
Stalk/Escalate dash reads as the body crossing the frame rather than
background parallax scroll — a small `CameraController` mode, owned by
[camera-and-parallax](/SYSTEMS/camera-and-parallax.md) (deepened in this
same wave); this concept only specifies the trigger and the number.

## Stage gating

| Stage | Behavior |
|---|---|
| Egg | No play; a 2° wobble-lean toward any rolling toy as a foreshadow tell |
| Drop | Two-beat only — Notice → bump-chase, using Drop's native hop (see [locomotion-and-gait](/SYSTEMS/locomotion-and-gait.md)) |
| Critter | Full five beats, sloppy and long — up to 90s |
| Beast | Athletic, fastest escalation |
| Sage | Half frequency, abbreviated, precise |
| Apex | Never chases — stationary one-paw play; **2%** of Apex bouts replay the full Critter-era arc at full intensity |

# 4. Composing with Hunt Grammar & Taught-Trick Flourishes

The Climax beat is deliberately not a second predator implementation.
When the toy category is `chasing`/`batting_toy` and the creature's
personality/stage favor it, Climax hands off to
[hunt-and-pounce](/SYSTEMS/hunt-and-pounce.md)'s canonical
stalk→butt-wiggle→launch→catch/whiff sequence rather than re-deriving one —
this concept's own Stalk/Escalate beats are the *play-motivated on-ramp*
into that grammar, not a competing copy of it. The catch/whiff outcome
(and its stage-tuned rates) is hunt-and-pounce's to define; Play Bouts only
supplies the *reason* a hunt sequence started (desire, not prey).

**Taught-trick splice point (designed, not built):** `taught_behaviors` of
category `playful` (one of [teach-system](/SYSTEMS/teach-system.md)'s 6
categories) are natural Escalate flourishes — a mastered `roll_over` or a
signature trick could fire instead of the generic paw-bat beat. No such
"bout context" hook exists on `TriggerConfig` today
(`contexts: []` is parsed but unused for this purpose,
`GameCoordinator+TaughtBehaviors.swift:330`) — this is a small addition for
whoever builds the meter, not a redesign of the taught-behavior system.

# 5. Yarnling Unspooled — Toy-Specific Climax

Extends the shipped `yarn_ball` preset (`WorldHandlers.swift:242`,
`ObjectMass.factor("yarn_ball") = 0.6`, `restitution = 0.5`,
`Input/ObjectInteraction.swift:16,27`). All-new visual state; no unspool/
tangle code exists.

| Element | Spec |
|---|---|
| Yarn body | 3pt dusk circle, 0.75pt bone wrap-line, rotates as it rolls at 8pt/s |
| Trail | One `SKShapeNode` path, dusk @ 60% alpha, grows to 40pt behind the ball, 1pt sine slack, capped at **~16 points** to keep per-frame re-render cheap (palette-safe: dusk/bone only) |
| Pounce-catch | 2–3 thread arcs draw across the body silhouette over 300ms |
| Tangle struggle | `roll_side`, 5 hind-kicks at 6Hz jittering the ball 1pt counterphase, body wriggle ±3° `zRotation` at 4Hz for 1s |
| Break-free | Threads snap — 3-particle dusk poof; rights itself in 250ms |
| Face-save | Sits, grooms the left shoulder **exactly twice** |
| Trail decay | Fades to void over 20s |

**Stage gating:** Critter = maximum tangle (3 arcs, longest struggle,
occasional immediate re-tangle) · Beast = breaks free in one kick-burst,
tearing the trail in two · Sage = never tangles — pins the ball, hooks one
claw, pulls a single 10pt thread taut, contemplates it, lets go · Apex =
the yarn unrolls toward it, then rewinds itself.

`roll_side` and the hind-kicks are body-controller-dependent (§1's dropped-
wire caveat); the tangle's `zRotation` wriggle is the one channel that
already survives `updateWorld` unclobbered today
(per [body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)),
so a partial version (wriggle only, no roll/kick) is buildable pre-pipeline.

# 6. The Favorite — Toy Attachment & Farewell

Per-object attachment is an extension of the same 7-factor scoring
substrate: attachment grows with every completed play bout, weighted by
`AttractionScorer`'s existing personality-affinity factor (the same number
that already decides *which* toy gets picked in the first place becomes
the growth-rate multiplier for *how attached* the creature gets to it), and
decays slowly between plays. No `attachment` field exists on any object
record today — this would live beside `wear` in the same per-object store
`ObjectWearSystem`/`world_objects` already maintain
(see [world-objects-system § Schema](/SYSTEMS/world-objects-system.md#schema)).

| Moment | Spec |
|---|---|
| Bedtime carry | Walk to the Favorite, mouth-grip (parented 1pt below the head node), head-high 2Hz bouncy prance 10–30pt to the nap spot, drop it, nose-nudge it 1pt twice |
| Sleep | `sleep_curl` positioned so the tail drapes over the toy (`sleep_curl` tuple: `(0.60, 1.15, -0.8, 0, -0.45, 0.20)`, path-swap — see [body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)) |
| Grooming | Two head-dips onto the toy |
| Defense (MCP removal attempt) | Single forepaw slap onto the toy, eyes narrow to 60% for 2s — a new listener on the existing object-remove path (`WorldManager+Objects.swift`'s soft-delete), not a new lifecycle |
| Farewell (wears to legacy shelf) | One-time: motionless sit, one ear droops 20° over 3s, journaled — **10s** sit at Critter/Beast, **20s** at Sage |

**Stage gating:** Egg = none · Drop = proto-attachment, sleeps touching
whatever object is nearest · Critter = fickle, Favorite changes weekly
(2x decay rate) · Beast = one strong Favorite · Sage = keeps a Favorite for
life · Apex = the Favorite levitates 1pt beside it during float states
(`float` bodyState, see body-pose-pipeline).

The bedtime carry is the one beat this concept flags as genuinely new
rig work (§1's carry-rig correction) rather than a pure choreography-data
addition — everything else in this table is data through already-shipped
mechanisms (mouth/paw/eye states, the legacy-shelf soft-delete, the wear
track).

# 7. Journal & Dream Integration

Every bout's Wind-down pays into contentment (`EmotionalState`), a journal
entry, and a `DreamEngine` fragment per the dossier pitch. **No matching
journal `type` exists yet** — the 18 live types
(`Schema.swift:141-148`: `commit, touch, ai_speech, failed_speech, ai_move,
ai_express, ai_perform, surprise, evolve, first_word, dream, discovery,
mutation, hook, session, teach, nurture, world_change`) have no `play`
entry; a play-memory or Favorite-farewell row would need either a new type
added to the CHECK constraint (a one-line schema migration) or reuse of
`world_change`. Flagged for whoever builds this, not resolved here — see
[journal-and-dreams](/REFERENCE/journal-and-dreams.md) (deepened this same
wave) for the type registry this concept's payoffs should register against.

# 8. Future Escalations (Backlogged, Not This Concept's Scope)

**Rebound Rally** (dossier appendix, dropped) — a human-vs-creature toy
volley scored as a rally count ("my nine-hit rally") — is explicitly
backlogged behind this concept: it depends on the hunt-and-pounce grammar,
lateral micro-hops, and the widened camera deadzone all landing first, and
overlaps the shipped flick physics (§1) and the 📐 flick-chase surface. Its
journal/reminiscence hook is noted here per the dossier's instruction, but
no design work for it lives in this document — it is a future consumer of
the play-pressure meter, once proven, not a beat this grammar runs today.

# Frame Budget

All new geometry stays inside existing budgets: Yarnling's trail is one
`SKShapeNode` (≤16 points) plus a 3-particle poof on snap — well under the
[100-120 node soft cap](/REFERENCE/performance-budgets.md). No new
persistent object types; The Favorite is a float attached to an existing
object row, not a new node. Every pose beat is transform-only (no per-frame
`CGPath` regen), consistent with the dossier's frame-budget risk note.

# What This Concept Does Not Cover

- The predator launch/catch/whiff mechanics a `chasing`/`batting_toy`
  Climax hands off to — see [hunt-and-pounce](/SYSTEMS/hunt-and-pounce.md).
- The bodyState transform tuples themselves and the compose pipeline that
  would render any of this — see
  [body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md).
- Object caps, preset catalog, the legacy-shelf soft-delete mechanics, and
  the wear/repair lifecycle — see
  [world-objects-system](/SYSTEMS/world-objects-system.md).
- Taught-behavior choreography format and mastery — see
  [teach-system](/SYSTEMS/teach-system.md).
- The shared ambient-event cooldown pool (bug spawns, patrols, glances,
  invitations) this concept's bout cap should ultimately draw from — see
  [invitation-system](/SYSTEMS/invitation-system.md) (deepened this same
  wave).

# Citations

[1] `Pushling/Sources/Pushling/Behavior/AutonomousLayer+ObjectInteraction.swift` (`selectObjectInteraction`, `objectWanderThreshold`)
[2] `Pushling/Sources/Pushling/Behavior/AutonomousLayer.swift` (`AutonomousState` cases)
[3] `Pushling/Sources/Pushling/World/AttractionScorer.swift` (7-factor scoring, category weights, personality affinities)
[4] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift` (15 templates, `chasing`'s stalk/wiggle/pounce sub-phases, 300s cooldown, `carrying` template)
[5] `Pushling/Sources/Pushling/World/ObjectWearSystem.swift` (wear rates/stages, repair)
[6] `Pushling/Sources/Pushling/Input/ObjectInteraction.swift` (flick physics, pick-up/drag/drop rig, `ObjectMass`)
[7] `Pushling/Sources/Pushling/Input/InvitationSystem.swift` (20-minute cooldown, reference point for the shared ambient-event governor)
[8] `Pushling/Sources/Pushling/Creature/PersonalitySystem.swift` (`PersonalitySnapshot` — 4 axes, no "playfulness")
[9] `Pushling/Sources/Pushling/Creature/EmotionalState.swift` (`energy`, `curiosity` axes)
[10] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`baseWalkSpeed` per stage)
[11] `Pushling/Sources/Pushling/App/GameCoordinator+TaughtBehaviors.swift` (`TriggerConfig.contexts`)
[12] `Pushling/Sources/Pushling/State/Schema.swift` (`journal.type` CHECK — 18 types, `world_objects` table)
[13] `docs/SYSTEMS/body-pose-pipeline.md` (bodyState transform tuples cited throughout)
[14] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` — Play Drive & the Five-Beat Bout; Yarnling Unspooled; The Favorite; Rebound Rally (appendix)
