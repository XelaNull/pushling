---
type: System
title: Ambient Wildlife
description: Transient micro-fauna distinct from companions — the Bug Season species roster (beetle/moth/snail/grasshopper/rain-skater), the creature's-own-aura-drawn night moth, the Landed-On-Me Freeze reflex, and the unified spawn governor shared with InvitationSystem so ambient life never stacks on an invitation. Designed, not built.
status: Future
tags: [world, wildlife, prey, ambient, hunt, moth, spawn-governor, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the authority for **transient micro-fauna** — small, un-owned
creatures that wander through the strip on their own schedule, distinct
from [companions](/SYSTEMS/world-objects-system.md) (persistent,
Claude-placed, max 1 of 5 types) and from the scripted gift-delivery-mouse
surprise (a one-shot [surprise catalog](/REFERENCE/surprise-catalog.md)
entry, not a wandering agent). Nothing described below exists in code
today; no bug/insect/moth/wildlife system was found anywhere under `World/`
or `Behavior/` (grep-verified). This concept exists so a future code WO can
build it without doing design work, in the same spirit as
[body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md).

Three features live here: **Bug Season** (a five-species huntable-prey
roster), **Moth to Her Flame** (a single special moth drawn to the
creature's own light, not prey), and **Landed-On-Me Freeze** (the reflex
that answers anything that alights on the creature). All three share one
spawn governor so they never stack on each other or on an
[invitation](/SYSTEMS/invitation-system.md).

# Spawn Governor

A single new component (`AmbientWildlifeGovernor`, unbuilt) arbitrates
**both** wildlife slots below — Bug Season prey and the Moth-to-Flame
encounter are mutually exclusive with each other, not just internally
capped at 1 each. Modeled on the shipped cooldown-timer pattern already
proven in this codebase (`World/GhostEcho.swift:37,56` — a randomized
cooldown range, decremented per frame, rerolled on spawn) rather than a
per-tick probability roll, because "spawns at most every 5-10 minutes" is
a hard-cadence design intent, not a rare-event roll like invitations.

| Parameter | Value |
|---|---|
| Concurrent wildlife slots | 1 (Bug Season prey OR the Moth-to-Flame moth — never both) |
| Respawn cooldown | random 300-600s (5-10 min) between despawn and next eligible spawn, GhostEcho-style |
| Guard conditions before rolling | not sleeping, no mini-game active, no evolution ceremony active, Claude not AI-directing — the same four guards `InvitationSystem` already declares (`Input/InvitationSystem.swift:215-218`) |
| Invitation coordination | governor also requires `InvitationSystem.activeInvitation == nil` **and** at least 30s since `InvitationSystem.lastInvitationTime`, so a bug never wanders in during an invitation's setup/offer/cue animation |
| Reverse coordination (new wiring gap) | `InvitationSystem`'s own scheduler would need a symmetric `isAmbientWildlifeActive` guard input to skip its 60s check while a bug or moth is live — this does not exist and is not proposed as an `InvitationSystem` code change here; it is the same class of guard-wiring gap [invitation-system.md](/SYSTEMS/invitation-system.md) already documents for its own `isSleeping`/`isMiniGameActive`/etc. inputs never being assigned by `CreatureTouchHandler` |
| Node budget | 1-2 pooled `SKShapeNode`s per active critter/moth — trivial against the ~100 typical / ~120 peak soft scene budget; **not** counted against `WorldObjectRenderer.maxObjectNodes = 40` (`World/WorldObjectRenderer.swift:80`), since wildlife is not a placed world object, same precedent as `CompanionSystem` adding its own node(s) directly rather than through the object renderer |

# Bug Season — the species roster

Five species, one slot, day/night/weather-gated. Every species maps to a
hunt verb so the creature's stalk/pounce grammar has autonomous prey
instead of waiting on a human flick. **The stalk → butt-wiggle → launch →
catch/whiff mechanics themselves (per-stage catch rates, the whiff/recover
table, target-position plumbing) are owned by
[hunt-and-pounce.md](/SYSTEMS/hunt-and-pounce.md)** — this table only maps
species to which hunt-and-pounce branch fires and to the two
species-specific consequence beats (trophy prance / tail-lash-and-groom)
that are unique to ambient prey, not part of the generic grammar.

| Species | Silhouette | Motion | Lifetime | Gate | Hunt Verb |
|---|---|---|---|---|---|
| Beetle | 1.2x1pt ash oval bean, 2 alternating 0.75pt bone leg-ticks | ground trundle 2-3pt/s, random ~90ms pauses | 30-60s | day only (any `TimePeriod` except `deepNight`/`lateNight`, `World/SkySystem.swift:15-22`) | standard stalk → pounce (hunt-and-pounce.md); escapes under a terrain bump |
| Moth (Bug Season) | 1.5x1.5pt bone double-lobe (two triangles), 6-8Hz wing flutter | spiraling 3-4pt loops near y=26 (top bezel) | 20-40s | night only (`deepNight`/`lateNight`) | mirrored startle + paw `swipe` (`Creature/PawController.swift:103-104`, shipped state), always 1pt behind — a miss is the point |
| Snail | 2x1.5pt moss dome + 4pt fading glint trail | crawl 0.5pt/s | 60-90s (longest-lived — comedy pacing, not a real hunt) | day, bonus spawn weight post-rain | follow-the-snail comedy: walk 3 steps, sit 2s, repeat, matching the snail's pace — no pounce, no catch/whiff branch |
| Grasshopper | 1x1.5pt moss wedge | 4-6pt hops, ~1.5s between hops | 20-40s | day only | mirrored startle-hop (creature hops 2pt in synced timing); a real catch mid-hop needs the airborne-arc/jump fix ([body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)) — pre-fix, the creature only watches and mirrors |
| Rain-skater | 1.5x1pt tide bean (named "worm" in one early lens proposal — unified here as rain-skater, a water-strider skimming rain puddles) | skims a puddle surface at 3pt/s, 2pt hop over the puddle rim | 20-40s | `WeatherState.rain` (`World/WeatherSystem.swift:17`) or up to 5 min after rain ends, and only while a puddle exists ([world-complexity-ambient-effects.md](/SYSTEMS/world-complexity-ambient-effects.md) owns `PuddleReflection`) | paw-pin-and-peek: paw `extend` (`PawController.swift:105-106`, shipped state, holds), lift 1pt to peek, then the skater bolts |

**Stage gating** (applies uniformly across all five species; per-species
catch-rate deltas belong to hunt-and-pounce.md):

| Stage | Response |
|---|---|
| Egg | none — no wildlife spawns |
| Drop | tracks with head/eyes only (see Tracking Reality below); does not hunt |
| Critter | hunts everything via the standard grammar |
| Beast | adds grasshopper mid-hop catches and rain-skater paw-pin (both require the jump/positionY fix; pre-fix, Beast behaves like Critter for these two species) |
| Sage | floor prey only; pins with one paw without breaking its `loaf` pose (bodyState-dropped today, so pre-fix this reads as tail `wrap` + `eye` half-close only — see Cross-Reference below) |
| Apex | never hunts — 2-3 gilt-alpha specks orbit its aura at ~4pt radius instead of wandering as prey (a stylistic reuse of the pooled sparkle particles, not a hunt encounter) |

**Catch consequence — trophy prance (universal, all species).** On catch,
the prey vanishes under the paws; the creature carries an invisible
trophy to screen center, sits, and curls its tail around its feet.
`tailState = "wrap"` is a shipped state (`TailController.swift:84-87`) so
the tail-curl half of this reads correctly today; the "bouncy prance
carry" half needs a directed head-lift, which is designed-not-built —
`CreatureNode`'s only existing head-vertical channel is the noise-idle bob
offset (`headNode?.position.y`, `Creature/CreatureNode.swift:298`), which
is untargeted ambient jitter, not a controllable "lift and carry" gesture.

**Escape consequence — tail-lash and groom (universal, all species).** On
escape, the design calls for the tail lashing hard (+-40 degrees, twice)
followed by a grooming pass. The grooming half is **already fully shipped
and visible today** — `BehaviorChoreography.applyGrooming`
(`Behavior/BehaviorChoreography.swift:118-133`) drives only a front-paw
lift and `mouthState = "lick"`, both appendage channels untouched by the
dropped-bodyState bug, so triggering the existing `"grooming"` autonomous
behavior after an escape works with zero new rendering code. The
tail-lash half does **not** exist as shipped motion: `TailController`'s
closest state is `twitch_tip`, a +-0.1 rad (~5.7 degree) tip-only flick at
12 rad/s (`TailController.swift:152-156`) — an order of magnitude smaller
than the ±40° whole-tail lash the design wants. A real lash needs either a
new `TailController` state or a parametrized amplitude override; until
then, repeated `twitch_tip` triggers are the honest substitute.

# Moth to Her Flame

Night-only, gated `Critter+` (aura glow is Critter+ per
[world-complexity-ambient-effects.md](/SYSTEMS/world-complexity-ambient-effects.md),
so pre-glow stages have no flame to draw a moth). This is **not** a Bug
Season species and does not go through the hunt-and-pounce grammar — it is
a scripted intimate encounter: a single dusk-colored moth spirals in from
off-screen and orbits the creature's own aura glow at a 4-8pt radius with
flutter jitter, on the theory that on an OLED strip where the creature is
literally the only light source, a moth navigating toward it is diegetic,
not decorative.

| Parameter | Value |
|---|---|
| Silhouette | 2x1.5pt dusk double-lobe (two 1pt triangles), 8Hz / 0.3pt wing flutter |
| Orbit | 4-8pt radius, drunken 3pt-amplitude wobble, sine-pair per frame |
| Duration | 20-40s, then spirals up and out over 2s |
| Gate | night (`TimePeriod.deepNight`/`.lateNight`) AND `Critter+` AND not sleeping (never wakes a sleeping creature — presence ethos: never interrupt sleep) |
| Spawn slot | shares the single ambient-wildlife slot with Bug Season (see Spawn Governor) |

**Tracking reality (the honest gap).** The pitch calls for continuous head
rotation easing toward the moth's bearing (0.15s lag) and eyes converging
on it, going fully cross-eyed at close range. Verified against the shipped
controllers:

- **No head tracking exists at all.** There is no `HeadController`.
  `CreatureNode.headNode` (`Creature/CreatureNode.swift:20`) has exactly
  one consumer — the untargeted noise-idle bob offset
  (`CreatureNode.swift:298`) — no rotation-toward-a-bearing capability of
  any kind. This is a new part controller, not a fix to an existing one.
- **Per-eye convergence math exists but has zero callers.**
  `EyeController.setLookTarget(worldPosition:eyeWorldPosition:maxRange:)`
  (`Creature/EyeController.swift:252-265`) computes a real per-eye pupil
  offset toward an arbitrary world point — call it once per eye with the
  moth's position and each eye's own position, and the two pupils
  naturally converge on a near target (true stereo convergence, not a
  canned animation). It is fully implemented and grep-verified to have
  **no call site anywhere in the codebase** — the shipped `"look_at"`
  state (`EyeController.swift:106-107`, wired to touch via
  `ReflexLayer.swift:97-103`) only replays whatever `lookTarget` was last
  set, which stays `.zero` because `setLookTarget` itself is never
  invoked. Wiring the moth's position through `setLookTarget` each frame
  is a small, well-scoped addition to a real, tested primitive — not new
  eye-tracking math.
- **"Cross-eyed" (`x_eyes`) is a placeholder today, not a crossed-pupil
  visual.** `EyeController.applyXEyes()` (`EyeController.swift:234-239`)
  just squashes the eye to a slit (`yScale 0.1, xScale 0.8`) — its own
  comment calls it a placeholder ("For placeholder: just close to a tiny
  slit"). The nose-proximity "fully cross-eyed" beat this feature wants is
  better served by `setLookTarget` pushing both pupils to their
  `maxRange` toward the same near point (real convergence) than by the
  `x_eyes` state as it exists today.
- **Paw swipes work as-is.** The "always-late paw swipe" reuses the
  shipped `swipe` `PawController` state directly — no gap here.

**Stage gating:**

| Stage | Response |
|---|---|
| Critter | track (once head tracking exists) + paw `swipe` |
| Beast | one 8pt vertical leap at it — needs the jump/positionY fix ([body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)); the miss is the point |
| Sage | moth lands on an ear tip for 5 held-breath seconds — feeds directly into [Landed-On-Me Freeze](#landed-on-me-freeze) below, same reflex, different visitor |
| Apex | moth spirals into the aura and dissolves into 3 gilt sparkle flecks (pooled particles); creature closes its eyes for 1s |

# Landed-On-Me Freeze

A generic "something is standing on me" reflex answering every visitor
that alights on the creature: the butterfly companion's shipped
`landCreature` behavior, the Sage-tier moth above, and (future, owned
elsewhere) a leaf on a gust or a snowflake clump.

**The gap this closes.** `CompanionSystem.landCreature`
(`World/CompanionSystem.swift:354-357`) already repositions the butterfly
companion onto the creature (`companion.positionX = creatureX`,
`companion.positionY = creatureY + 8`) every time that behavior is
selected (`CompanionSystem.swift:112` — a 2-4 second `durationRange` entry,
not a selection weight; selection itself is either random-from-pool or
forced to `landCreature` when the creature is within 30pt, per
`selectNextBehavior`'s proximity branch at `CompanionSystem.swift:278`) —
but nothing on the creature side ever responds. It is a shipped behavior
with zero creature-facing effect today.

**Fix: one new callback.** `CompanionSystem` needs
`var onCreatureLanded: ((LandingSource) -> Void)?`, matching the existing
`onXEvent` closure-callback pattern used throughout `Input/` (e.g.
`onObjectEvent`, `onInvitationEvent`, `onFeedingEvent` — see
[gesture-response map](/REFERENCE/gesture-response-map.md)), fired once
per `landCreature` transition (not every frame) and reused by the Sage
Moth-to-Flame landing above.

| Parameter | Value |
|---|---|
| Trigger | `onCreatureLanded(.butterfly)`, `onCreatureLanded(.moth)` (Sage-tier only), future `.leaf`/`.snowflakeClump` |
| Damping | breath amplitude to 30%, tail sway to 20%, walk halts with one settling half-bob, all over a 0.3s ease |
| Eye response | both pupils converge toward the landing point via `setLookTarget` (same primitive as Moth to Her Flame); nose landings pinch fully inward |
| Hold | 3-8s, stage-scaled (see below) |
| Exit A — sneeze | 0.15s pre-squash, 1pt recoil hop, visitor launches on a 6pt arc with 2 sparkle flecks |
| Exit B — visitor leaves first | 0.5s whole-body shake, then sits and stares at the empty spot |

**The breath-amplitude gap.** `CreatureNode`'s breathing amplitude is two
hardcoded private constants, `breathAmplitudeAwake = 0.03` and
`breathAmplitudeSleep = 0.02` (`Creature/CreatureNode.swift:69-70`) — there
is no public amplitude channel to dial down, only
`breathPeriodOverride` (`CreatureNode.swift:75`), which changes breathing
*speed*, not depth. "Breath drops to 30%" needs a new
`breathAmplitudeOverride: CGFloat?` sibling to the existing period
override, following the exact same pattern — a small, well-precedented
addition, not a redesign of the breathing system.

**Stage gating:**

| Stage | Response |
|---|---|
| Egg | n/a — no companions/moths exist yet at Egg |
| Drop | doesn't understand — wobbles in confusion (zRotation, comedy) until the visitor gives up |
| Critter | 3s hold, usually ends in sneeze |
| Beast | fights the freeze — tail sway amplitude creeps up over the hold until it explodes into the shake exit |
| Sage | 8s serene hold, breath nearly stopped, always lets the visitor leave on its own (never sneezes) |
| Apex | visitor dissolves gently into its light after 3s, same as the Apex Moth-to-Flame ending — nothing can perch on a sun |

# Future Species (appendix, not fully specced here)

**Bird Flush Stalk** — folded into this roster as a future sixth species
rather than a standalone feature, per the dossier's disposition: it is
exactly [hunt-and-pounce.md](/SYSTEMS/hunt-and-pounce.md)'s
always-escapes-upward branch, reusing `CompanionSystem`'s bird renderer
(`flyOverhead`/`landObject`/`hop`/`preen` already exist,
`World/CompanionSystem.swift`) in a transient, non-companion spawn mode.
Full detail (the 5% tail-feather-drop catch at Beast+, the Sage
slow-blink-exchange variant) is intentionally left in
`.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` rather than
duplicated here — this doc's roster only reserves its slot in the spawn
governor and its place in the species table above for when it's promoted.

# Citations

[1] `Pushling/Sources/Pushling/World/GhostEcho.swift:37,56,88-89,203-204,241-242` (the cooldown-timer pattern this governor is modeled on)
[2] `Pushling/Sources/Pushling/Input/InvitationSystem.swift:64-72,215-226` (guard conditions and cooldown constants this governor coordinates with)
[3] `Pushling/Sources/Pushling/World/WorldObjectRenderer.swift:80,153-155` (`maxObjectNodes = 40`, confirmed not to apply to wildlife)
[4] `Pushling/Sources/Pushling/World/SkySystem.swift:14-22` (`TimePeriod` night/day gate)
[5] `Pushling/Sources/Pushling/World/WeatherSystem.swift:14-17` (`WeatherState.rain`)
[6] `Pushling/Sources/Pushling/Creature/PawController.swift:103-106` (`swipe`, `extend` states)
[7] `Pushling/Sources/Pushling/Creature/TailController.swift:13-15,84-87,152-156` (`wrap`, `twitch_tip` states and amplitude)
[8] `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift:41-42,118-133` (`grooming` behavior, fully appendage-rendered)
[9] `Pushling/Sources/Pushling/Creature/CreatureNode.swift:20,69-70,75,298` (`headNode`, breath amplitude constants, `breathPeriodOverride`)
[10] `Pushling/Sources/Pushling/Creature/EyeController.swift:13-16,106-107,234-239,252-265` (`validStates`, `x_eyes` placeholder, `setLookTarget` — implemented, zero callers)
[11] `Pushling/Sources/Pushling/World/CompanionSystem.swift:62,91,112,278,354-357` (`landCreature`, its 2-4s `durationRange` entry, its proximity-forced selection branch, and its butterfly-only call site)
[12] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift:170`, `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift:58-59,224-234` (`predator_crouch`, subsumed by hunt-and-pounce.md)
[13] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` — "Ambient Prey: Bug Season", "Moth to Her Flame", "Landed-On-Me Freeze", "Bird Flush Stalk" (dropped-appendix disposition)
[14] [hunt-and-pounce.md](/SYSTEMS/hunt-and-pounce.md), [invitation-system.md](/SYSTEMS/invitation-system.md), [world-complexity-ambient-effects.md](/SYSTEMS/world-complexity-ambient-effects.md), [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md), [gesture-response-map.md](/REFERENCE/gesture-response-map.md)
