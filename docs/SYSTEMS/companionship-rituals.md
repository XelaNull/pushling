---
type: System
title: Companionship Rituals
description: Body language directed at the developer specifically — greeting, work-companionship, glances, scent-marking, dev-win celebration, and memory pilgrimage — organized around a bond tier derived from pet-streak, touch milestones, and days-known. Designed, not built, gated on the body-pose pipeline.
status: Future
tags: [companionship, bond, reunion, celebration, ritual, milestone, system]
timestamp: 2026-07-03T00:00:00Z
---

Six rituals in which the creature's body takes a position **relative to the
developer**, not just relative to its own internal state: it runs to you,
settles beside your work, glances at you, claims the button your finger
touches, celebrates your commits, and revisits the ground where your shared
history happened. Every one of them is a whole-torso behavior blocked on
[the body pose & compose pipeline](/SYSTEMS/body-pose-pipeline.md) — none can
render as designed until `bodyState`/`positionY` stop being dropped at
`applyBehaviorOutput`. This concept owns the choreography and the bond-tier
metric; it does not own the pose-tuple mechanics (that pipeline), the touch
substrate (below), or the reflex-priority machinery (behavior-stack.md).

# The Bond Tier

Every ritual below scales its intensity off one shared metric: a New /
Familiar / Devoted tier derived from three persisted signals — pet-streak
days, touch milestones unlocked, and days known. **Canonical home:**
[personality & emotional state's Bond Tier
section](/REFERENCE/personality-emotional-state.md#bond-tier--a-derived-stat-pet-streak--milestones--days-known)
now owns the `bondScore` formula, its three inputs' citations, and the
tier thresholds — ratified there verbatim from this doc's original
definition (that concept's own text confirms the promotion, and cites back
here as the metric's origin). This section no longer needs to carry a
second copy that could silently desync from that one. Five of the six
rituals below key off the resulting New/Familiar/Devoted label; this doc
only consumes the tiers.

# 1. Reunion Runway — bond-weighted greeting choreography

Extends the shipped [`AbsenceWakeAnimation`](/SYSTEMS/behavior-stack.md#absence-scaled-wake-behaviors)
keyframe sequences (`Creature/AbsenceAnimations.swift:124-427`, six
`AbsenceCategory` tiers from `brief` <1hr to `extended` 7+d) with a whole-
body run-in on wake, gated to any category except `brief` so a short
look-away never triggers the full sequence. (`AbsenceCategory` is a plain
`enum` today with no `Comparable` conformance — a future implementation
needs an explicit case-list check or ordinal mapping, not a `>=` operator.)

**What's already real vs. what's blocked:** the shipped `longAbsenceWake`/
`extendedWake` keyframes already set `walkSpeed: 50`/`70`
(`AbsenceAnimations.swift:337,392,403`) — and `walkSpeed` is one of the few
channels that **does** reach the screen today, via
`BlendController.updatePosition`'s speed integration (confirmed live in
[the body pose pipeline's grounds](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)).
The "run across the bar" itself is not new work. What Reunion Runway adds —
and what stays fully blocked until the pipeline ships — is everything routed
through `bodyState`: the keyframes' `sleep_curl` → `stretch` → `stand`
sequence, the skid-stop squash, and the finisher pose. Today those three
`bodyState` strings are computed and silently dropped, so a wake reads as
"ears and eyes change, creature slides across the bar" with no torso motion
at all.

| Bond Tier | Finisher (after the shared run-in) |
|---|---|
| New | Tall-stand (`sit`-adjacent, `headOffset +0.3`) + one ear perk. No leap. |
| Familiar | Tall-stand + tail question-mark hook (`tailState: "high"`, already in the shipped keyframes at `AbsenceAnimations.swift:332`). |
| Devoted | Vertical leap landing into a walk toward the P-button end of the bar (see [Bunting](#4-bunting--cheek-rubbing-the-p-button) below for the destination). |

**Devoted leap height is capped by the pipeline, not invented here:** the
dossier's own pitch says "6-10pt" — that number **must not** be used as
written. [The body pose pipeline's per-stage jump-apex headroom table](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)
caps Beast at 6pt and leaves Critter/Sage **not yet specified** — Reunion
Runway's leap inherits whatever that table settles on per stage rather than
its own number, so it never becomes a fourth conflicting jump-height source.

**Stage reinterpretation** (per dossier, using the pipeline's existing
per-stage scalars where they overlap): Drop gets a hop-scurry approach with
no leap (matches its 0.5/0.6 scale/offset scalars — deformation halves at
this stage anyway). Critter runs the choreography above as written — the
shared run-in, skid-stop, and bond-tier finishers described at the top of
this section are Critter's own version, not a stage-agnostic default,
named explicitly here rather than left implicit. Beast trades the run for
a low prowl-rush that resolves into a pounce-greeting instead of a skid-stop:
the run-in eases down into the [`crouch` bodyState
tuple](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
partway through rather than staying upright, then resolves into the
[`pounce` tuple](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
at contact — reusing [hunt & pounce's canonical Stalk→Launch
phases](/SYSTEMS/hunt-and-pounce.md#2-the-canonical-grammar) (the same
crouch/pounce shape [independently reinvented nine
times](/SYSTEMS/hunt-and-pounce.md#1-the-fragments-code-verified-ground-truth)
elsewhere in the codebase) rather than inventing a tenth variant for this
ritual alone; the leap-height cap for Beast's finisher, where one applies,
still defers to the 6pt ceiling above — this reinterpretation changes the
approach shape, not the cap. Sage swaps the run for a measured approach
ending in one deep
[`arch`](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)-adjacent
bow — no version of this concept's run-in survives Sage's 0.85 restraint
scalar as a full sprint without breaking the Solid Fill Test at speed. Apex
does not run at all: a 4pt forward drift plus one slow blink plus a gilt
aura pulse at 0.3 alpha (using the `auraState` `pulse`/`transcendent`
mechanics already tabled in [the pipeline's §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) —
restraint as intimacy, not a smaller version of the same choreography.

**Camera:** the run-in needs the cinematic override released mid-sequence so
the camera can re-center on an off-screen-spawned creature rather than the
fixed center-pin — `CameraController.setCinematicState`/`clearCinematicState`
exist and are load-bearing here (`camera-and-parallax.md`'s Cinematic
Override section), but no sequencer wires an absence-wake trigger into them
today; this is new plumbing, not a reused call site.

# 2. Flow Loaf — settles when you work, rises when you stop

**Correction to the dossier's feasibility claim.** The pitch states
"`EmotionalState.sustainedActivityTimer` exists" as the load-bearing signal
— true, but its actual shipped behavior is narrower and less useful than
that phrasing implies, verified directly against `Creature/EmotionalState.swift`:

- `isActive` (line 67) becomes `true` **only** inside `boostFromCommit`
  (line 164) — i.e. only on a commit event, not on general "developer is
  typing/active" signal — and becomes `false` **only** inside `markInactive()`
  (line 209-212), which **has zero call sites anywhere in the codebase**
  (grep-verified). Once a single commit lands, `isActive` stays `true`
  forever; there is no live path that ever flips it back off.
- `sustainedActivityTimer` (line 64) only accumulates while `isActive`, and
  its **only** consumer is a `> 7200` (2-hour) check at line 133 that drains
  `energy` — it has no external readers (grep-verified) and no 90-second
  threshold anywhere near it.

So this is not "the signal exists but needs plumbing shared with the
invitation guards" (the dossier's framed risk) — it is a **different,
narrower signal measuring a different thing** (commit-triggered 2-hour
marathon fatigue) than what Flow Loaf needs (a rolling ~90-second "hook
events are arriving" window). Flow Loaf's settle trigger needs new state
entirely: a last-hook-event timestamp compared against "now," fed from [the
hook sensory system](/SYSTEMS/hook-sensory-system.md)'s existing event
stream, not a repurposing of `sustainedActivityTimer`. This puts it in the
same boat as [the invitation system's guard/weighting
inputs](/SYSTEMS/invitation-system.md#scheduling), which are separately
flagged as never fed real state — both need a real state feed that today
doesn't exist, and both should probably be fed by the same plumbing rather
than two independent fixes.

**Sequence once that new timer exists** (unchanged from the dossier design):
after ~90s of continuous hook activity, walk to a nearby spot, one circle
(`zRotation` sweep — the one channel that survives `updateWorld` untouched
today, per [the pipeline's dropped-wire findings](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)),
settle into the `loaf` `bodyState` tuple (`yScale 0.82, xScale 1.10, yOffset
-0.35, pawAlpha 0.3` — [pipeline table](/SYSTEMS/body-pose-pipeline.md#static-postures-hold-a-shape)),
breathing period stretched toward 4s, blink every 8-12s, wander and
[invitation](/SYSTEMS/invitation-system.md) rolls suppressed. On a >45s gap
in hook activity: `headOffset` pops via the pipeline's additive head-delta
mechanism (no new channel needed) in ~300ms, then the torso follows over
700ms back toward `stand`. Past 5 minutes of continued silence, relocates
toward the P-button end and waits — this last behavior overlaps Waiting at
the Door, an unbuilt dossier-appendix item with no owning concept yet (its
RoutineEngine-gated return-prediction confidence is unproven, per the
dossier's own appendix note); Flow Loaf's version is unconditional (fires
on any pause, not a predicted-return window) and should share one
destination-walk call rather than two competing "go wait by the button"
triggers, once Waiting at the Door lands somewhere.

**Stage gating:** Drop cannot loaf (its `bodyState` machinery is Critter+
per the pipeline's stage gate) — puddle-rests instead, one blink per 10s.
Sage settles into the existing `meditate` perform action's `auraState:
"pulse"` treatment (`PerformActionMapping`, already tabled in [the
pipeline's §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)) —
its body finally visible once the pipeline ships. Apex hovers 1pt lower and
dims aura 20% rather than adopting a ground pose at all.

# 3. Ship-It Ladder — escalating dev-win celebration

Commit reactions ship today as pure `EmotionalState` deltas with **zero**
body output: `boostFromCommit(size:)` (`EmotionalState.swift:152-165`)
adjusts `satisfaction`/`energy` by a fixed amount per `CommitSize` (`.small`
+10/+5, `.medium` +20/+5, `.large` +30/+5 — `CommitSize.from(linesChanged:)`,
lines 353-361) and touches no `bodyState`, `positionY`, or reflex trigger
anywhere in `GameCoordinator.swift:370`'s call site. This ladder is the
missing body grammar for an event that already fires reliably.

| Commit size | Body grammar | Duration | Interrupts current behavior? |
|---|---|---|---|
| Small | Head bob + one tail snap | 400ms | No |
| Medium | Rear-up: front paws lift 2pt, one paw-punch | 600ms | No |
| Large | 4pt vertical leap → land → 360° `roll_side` → pop to `stand` → tail hook | 900ms | Yes (reflex-priority) |
| Streak (3+ commits/hour) | Adds 1 repeat of the same-size grammar + 1 gilt sparkle mote, capped at 3 repeats / 2.5s total | — | Same as base tier |

**The streak trigger is new state, not existing code.** No shipped counter
tracks "commits in the last rolling hour" anywhere in `GameCoordinator` or
`EmotionalState` (grep-verified). The closest existing thing is a *day*-
granularity streak multiplier in `XPCalculator.calculate` — but [commit
feeding & XP's own known-defect
finding](/SYSTEMS/commit-feeding-xp.md#known-defect-the-shipped-xp-award-path-bypasses-xpcalculator)
already establishes that the **live** commit-XP path
(`GameCoordinator.swift`'s `wireFeedProcessor()`) bypasses `XPCalculator`
entirely and applies no streak multiplier at all in production — so there
is no existing streak signal of *any* granularity actually reaching a real
commit today, day- or hour-scale. This ladder's hour-window commit-cadence
counter is wholly new state, not a repurposing of anything nearby, and
should be careful not to entangle itself with `XPCalculator`'s already-
orphaned formula while it's fixed.

**Large-commit leap height is capped by the pipeline, not this doc:** same
rule as Reunion Runway above — 4pt is illustrative only where the [per-stage
headroom table](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)
hasn't specified a cap yet (Critter, Sage); at Beast it must not exceed 6pt.
The `roll_side` tuple already exists in the pipeline table (`yScale 0.65,
xScale 1.30, zRotation 1.40rad, path-swap: yes`) — this ladder is a pure
consumer of that tuple plus the `positionY` mechanism, adding no new pose
math, only timing/trigger logic and the reusable-primitive framing the
dossier calls out (roadmap PR-merge celebration and build-status watching
are future callers of this same ladder, not duplicates of it).

**Stage reinterpretation:** Drop does a triple hop at escalating heights
(2/3/4pt — but capped to Drop's own 2pt ceiling per the pipeline table, so
in practice all three hops read at the same height until Drop's cap is
revisited). Beast's large tier is the first stage where `backflip`'s
existing `PerformActionMapping.swift:83` mapping (`positionY: 12.0`, gated
`stage >= .beast`) finally gets a body — **but that literal value is
already flagged in the pipeline doc as 2x over Beast's own 6pt cap** and
needs the fix noted there before this ladder can honestly use it. Sage: a
single slow 3pt float-rise + one `arch`-adjacent bow. Apex: body stays
still — an `auraState: "sparkle"` flare (already tabled) plus one gilt ring
particle expanding outward — celebration as light, not motion.

# 4. Bunting — cheek-rubbing the P button

The P button (`ProgressButtonView`, `TouchBar/TouchBarView.swift:63`,
collapsed frame `NSRect(x: 2, y: 4, width: 24, height: 22)`) is the one
literal pixel-region the developer's finger touches — a native AppKit
overlay button, not a SpriteKit node, sitting at the extreme left edge of
the bar. Bunting is the creature walking to that end and performing a
cheek-rub against it.

**Triggers**, each tied to a real, verified event:

| Trigger | Source | Citation |
|---|---|---|
| Capping a Devoted-tier reunion | [Reunion Runway](#1-reunion-runway--bond-weighted-greeting-choreography) finisher | this doc |
| Within 10s of a petting session ending | `PettingStroke.PettingEvent.strokeComplete(count:)` | `Input/PettingStroke.swift:67`, wired (heart-burst only) at `Input/CreatureTouchHandler.swift:512-518` |
| After a hand-feed | `milestoneTracker.recordSpecial(.handFeed)` on successful release | `Input/CreatureTouchHandler.swift:488` |
| Rare high-contentment idle (contentment > 75, 15-min cooldown) | `EmotionalState.contentment` (0-100 scale, schema `creature.contentment`) | `Creature/EmotionalState.swift`, `DATA_MODELS/state-database-schema.md` |

None of these four call sites currently does anything beyond their existing
narrow effect (heart particle, milestone counter increment, stat delta) —
this ritual is new listener logic on top of already-firing events, not a
new touch mechanic.

**Choreography:** walk to the button end, head drops 2pt and tilts (head
group is already independently addressable per the [pipeline's headOffset
delta mechanism](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)),
body leans into the edge (`xScale` skew, contact side), head drags along the
edge over 1.8s while contact-side whiskers compress — **a new whisker
state**: `WhiskerController`'s five valid states today are `neutral`,
`forward`, `back`, `twitch`, `droop` (`Creature/WhiskerController.swift:2,12`),
none of which reads as "pressed flat against a surface"; this needs a sixth
literal, not a repurposing of `forward` — then a facing flip
(`CreatureNode.setFacing`, already the one instant-flip mechanism that
works today) and a mirrored rub. 1-3 rubs,
then a `sit` tuple hold — the "satisfied tall-sit" the dossier names is
this pipeline `sit` tuple (`yScale 0.90, headOffset +0.3`), not a new pose.

**Camera dependency — flagged, not resolved here.** The creature must be
physically positionable at the screen's left edge for this to read; today
`CameraController` keeps the creature pinned near screen center (per [the
body pose pipeline's grounds](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)
and [camera-and-parallax.md](/SYSTEMS/camera-and-parallax.md)'s hard Y-clamp
precedent for the vertical axis). The dossier assigns an analogous X-axis
"edge-clamp" to [camera-and-parallax.md's Camera Dwell & Edge-Clamp section](/SYSTEMS/camera-and-parallax.md#camera-dwell--edge-clamp-designed-not-built), which now owns the mechanism.
Bunting and [Sleep Geography](/SYSTEMS/idle-life-and-rest.md#4-sleep-geography)
both require it — this doc does not invent the mechanism, only the
requirement: the camera must be able to suspend its normal center-tracking
long enough for the creature to stand beside the real button frame above
without the world scrolling underneath it.

**Stage reinterpretation:** Drop has no articulated head yet — a whole-body
lean-bump against the edge, twice, substitutes for the cheek-rub. Sage adds
two 0.75pt Bone purr motes rising on contact (minimum-stroke-width compliant
per [grounds[1]](#citations)). Apex bunts at most once per day (a cooldown,
not a pose change) — scarcity as the payoff, not a bigger gesture.

# 5. Check-In Glances — social referencing

The smallest complete unit of relationship: every 2-6 active minutes, the
creature pauses 1.5-3s, quarter-turns toward screen-forward, pitches its
head up ~10°, blinks once, then resumes. Suppressed to ~10min during Flow
Loaf so the two never compete for the same idle window.

**"Reflex checkpoint/resume" — what the mechanism actually does, verified
against `Behavior/ReflexLayer.swift`.** The dossier and this wave's brief
both describe glances as reusing "the reflex checkpoint/resume mechanism
(the surprise mechanism)." There is no literal save/restore of
in-progress state anywhere in the reflex system — [the behavior stack
already documents](/SYSTEMS/behavior-stack.md) that every layer runs
`update(deltaTime:currentTime:)` **independently, every frame, regardless
of priority** (line 25-26). `ReflexLayer.update` (`ReflexLayer.swift:144-161`)
returns a per-property merged `LayerOutput` while a reflex is active, and
`.empty` (all-nil, meaning "defer to the layer below") once it expires — it
never pauses `AutonomousLayer`, which keeps computing its own walk/idle
state machine underneath, unaffected, the entire time. "Seamless resume" is
therefore not a checkpoint at all: it's that the masked layer was never
stopped, so whatever it's currently outputting becomes visible again the
instant the mask lifts. This matters for the glance's implementation: none
of the four shipped `ReflexDefinition`s (`earPerk`, `flinch`, `lookAtTouch`,
`startle`, `ReflexLayer.swift:67-125`) touch `facing` or `walkSpeed` — a
glance that wants to visibly halt mid-walk (not just override the face while
the body keeps sliding) needs a **new** reflex definition that also
overrides `walkSpeed: 0` for its duration; on expiry, `AutonomousLayer`'s
walk-bout timer — which never stopped ticking during the glance — resumes
with whatever destination/speed it currently wants, which will not
necessarily match the pre-glance value exactly (e.g. if a walk bout's own
3-12s duration happened to end during the glance window). This is a cosmetic
edge case, not a functional bug, but it's the honest mechanism, not a true
snapshot/restore.

[The reflex-priority generalization this glance (and Sky Theater Reflex)
would formalize belongs to behavior-stack.md](/SYSTEMS/behavior-stack.md) —
as of this wave's authoring that concept documents the existing four
reflexes and priority table but no generalized "interruptible social pause"
category (grep-verified, no `checkpoint`/`resume` hits). This doc specifies
the requirement (a reflex that overrides `facing`+`headOffset`+eye state,
optionally `walkSpeed`, for 1.5-3s); the generalized mechanism name and any
shared plumbing across glances/sky-reactions is that concept's call.

**Payoff:** if the human interacts (touch, MCP command) within 2s of a
glance firing, log a creature-initiated "we saw each other" journal moment
— an 8th, creature-side row alongside [the 📐 paying-attention table's seven
human-initiated ones](/FEATURES/interactivity-unbuilt.md#touch-milestones--unbuilt-payloads)
(itself unbuilt today — the reward sparkle exists but no autonomous-
behavior-timing-window detection fires it in real gameplay; a glance-side
8th row inherits the same gap, not a new one). Frequency scales with bond
tier: New checks in every 6 minutes, Devoted every 2.

**Stage reinterpretation:** Drop has no articulated neck — a whole-body
tilt toward the viewer substitutes. Sage holds the gaze 5s instead of 1.5-3.
Apex skips the head turn entirely: the aura leans 1pt toward screen-forward
via the same additive-offset pattern the pipeline uses for `headOffset`,
applied to `auraNode` instead — "you simply feel watched."

# 6. Milestone Pilgrimage — revisiting the places where life happened

Milestones (evolution, first word, mastered trick, 7-day streak) stamp a
permanent, low-alpha terrain decal at the world X coordinate where they
occurred. Rarely, the creature walks back to one, sits, gazes, and
sometimes touches it.

**Decal budget — specified here, adopted downstream.** Terrain marks are
1-node decals that must not compete with
[`WorldObjectRenderer.maxObjectNodes = 40`](/SYSTEMS/world-objects-system.md)
(`World/WorldObjectRenderer.swift:80`, guarded at line 153) — that cap is
scoped to *interactive* placed objects (12 persistent + 3 consumables per
the file's own header comment, line 5), not passive terrain decoration, so
milestone marks get their **own** 5-node ceiling, oldest-evicted-first once
a 6th milestone would stamp a mark. [World objects system's Memory-Decal
Budget section](/SYSTEMS/world-objects-system.md#memory-decal-budget-milestone-marks)
now carries this number as its own adopted authority over the enforcement
shape (it already owns the analogous interactive-object cap) — this doc
originates the 5-node ceiling and the eviction policy; the enforcement
detail (the proposed `decals` dictionary, the missing `position_x` storage
column) lives at that section, cross-linked rather than re-derived here.

| Milestone type | Mark visual | Alpha |
|---|---|---|
| Evolution | 3pt scorch-bloom, stage's accent color | 0.25, decays to 0.08 over 30 days |
| First word | 2pt Bone star-etch | 0.25, decays to 0.08 over 30 days |
| Mastered trick / 7-day streak | Same decal family, palette color per source system | 0.25, decays to 0.08 over 30 days |

Marks never fully vanish (0.08 alpha floor) — "nothing silently vanishes"
extends to the world itself, not just the dossier's own appendix rule.

**Trigger:** 2%/hour roll, max once/day, gated `contentment > 60`
(`EmotionalState.contentment`, same 0-100 scale `boostFromMilestone()`
already feeds at +15 per hit — `EmotionalState.swift:194-196`). Walks to a
mark (destination-walk already exists per every other ritual in this
bundle), sits (pipeline `sit` tuple), gazes 8-20s with slow blinks,
sometimes extends one paw to touch it (`pawAlpha`-independent — a targeted
paw-controller animation, not the pipeline's pose-driven alpha channel),
stretches, wanders off. Procedural-animation.md documents this as an
explicitly **unbuilt** "staged sitting sequence"
(`docs/REFERENCE/procedural-animation.md:182`: "rear lowers first, front
paws adjust, tail wraps to side, settle wiggle" vs. the shipped `loaf`'s
single-frame settle) — Milestone Pilgrimage is that sequence's first named
consumer, not a new requirement for it.

**Sage+ reminiscence caller — doubly blocked, not singly.** At Sage+, a
pilgrimage is meant to become the trigger for [the designed-but-uncalled
Sage+ idle reminiscence system](/REFERENCE/journal-and-dreams.md#sage-idle-reminiscence--design-intent-unbuilt-p8-t2-07)
(P8-T2-07: `SpeechCache.failedSpeechEntries()`, zero callers repo-wide).
That is only the first of two blockers — [speech-filtering.md's own
consumer audit](/SYSTEMS/speech-filtering.md) already carries the deeper
finding, cross-linked rather than re-derived here: `SpeechCache`'s backing
`speech_cache` table's `CREATE TABLE`/`CREATE INDEX` statements are never
executed anywhere in the codebase (full detail: [state database
schema](/DATA_MODELS/state-database-schema.md#speech_cache--designed-never-actually-created)),
so every `store()`/query call fails against a table that doesn't exist.
Wiring a Milestone Pilgrimage caller into `failedSpeechEntries()` today
would call a dead read path against a table that was never created —
**both** gaps need fixing together; closing the caller alone still returns
nothing. At Apex, pilgrimages happen at night only and re-brighten every
historic mark simultaneously — the bar becomes a ground constellation,
reusing the same alpha-restore mechanism as a normal mark touch, just
applied to all 5 marks at once.

**Palette-safe:** all mark colors are stage accent colors at low alpha —
no 9th color, per [grounds[1]](#citations)'s hard palette rule.

# Interactions With Sibling Concepts

- [Body pose & compose pipeline](/SYSTEMS/body-pose-pipeline.md) — every
  ritual above that renders a `bodyState` (all six) is blocked until this
  ships; this doc adds no new pose tuples beyond what that pipeline already
  tables (`sit`, `loaf`, `roll_side`, `arch`, `stretch`).
- [Behavior stack](/SYSTEMS/behavior-stack.md) — owns reflex-priority
  arbitration; Check-In Glances needs a new reflex definition there, not a
  new priority layer.
- [Touch milestones](/SYSTEMS/touch-milestones.md) — the bond-tier
  substrate; this doc does not re-specify milestone IDs or thresholds.
- [Camera & parallax](/SYSTEMS/camera-and-parallax.md) — Bunting and
  Reunion Runway both need an X-axis edge-clamp / cinematic-release this
  doc does not define, only requires.
- [World objects system](/SYSTEMS/world-objects-system.md) — Milestone
  Pilgrimage's 5-node decal budget is scoped separately from that concept's
  40-node interactive cap; both should be enforced by the same renderer.
- [Journal & dreams](/REFERENCE/journal-and-dreams.md) /
  [speech-filtering](/SYSTEMS/speech-filtering.md) — Sage+ Idle
  Reminiscence is the wiring target Milestone Pilgrimage exists partly to
  provide; the "doubly blocked" framing (zero callers *and* the backing
  table never created) is those concepts' own finding, cross-linked here,
  not re-derived.
- [Invitation system](/SYSTEMS/invitation-system.md) — Flow Loaf must
  suppress the same invitation rolls that system's own guard-wiring gap
  already flags as unfed; fixing one without the other leaves Flow Loaf
  suppressing invitations that were never going to fire correctly anyway.

# Citations

[1] `Pushling/Sources/Pushling/Creature/AbsenceAnimations.swift` (`AbsenceCategory`, `AbsenceWakeAnimation.keyframes`, `longAbsenceWake`/`extendedWake` walkSpeed literals)
[2] `Pushling/Sources/Pushling/Creature/EmotionalState.swift` (`sustainedActivityTimer`, `isActive`, `markInactive`, `boostFromCommit`, `CommitSize`, `boostFromMilestone`, `contentment`)
[3] `Pushling/Sources/Pushling/App/GameCoordinator.swift:370` (`boostFromCommit` call site)
[4] `Pushling/Sources/Pushling/Behavior/ReflexLayer.swift` (`ReflexDefinition`s, `update`, per-property merge, `.empty` defer)
[5] `Pushling/Sources/Pushling/Input/PettingStroke.swift`, `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift:508-519,485-488` (`PettingEvent`, hand-feed trigger, ignored-callback cases)
[6] `Pushling/Sources/Pushling/TouchBar/TouchBarView.swift:63` (P button `ProgressButtonView` frame)
[7] `Pushling/Sources/Pushling/World/WorldObjectRenderer.swift:5,80,153` (`maxObjectNodes`, object-cap scope)
[8] `/SYSTEMS/speech-filtering.md`, `/DATA_MODELS/state-database-schema.md#speech_cache--designed-never-actually-created` (the `speech_cache` table-never-created finding, cross-linked not re-derived)
[9] `Pushling/Sources/Pushling/Input/PetStreak.swift`, `Pushling/Sources/Pushling/Input/MilestoneTracker.swift` (bond-tier inputs)
[10] `docs/REFERENCE/procedural-animation.md:182` (unbuilt staged sitting sequence)
[11] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (Reunion Runway, Flow Loaf, Ship-It Ladder, Bunting, Check-In Glances, Milestone Pilgrimage sections; COMPANIONSHIP DEPTH lens proposals)
[12] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds[1]` (palette, frame budget, silhouette constraints), `.proposals` (COMPANIONSHIP DEPTH lens, per-feature `visual`/`stageGating`/`feasibility`)
