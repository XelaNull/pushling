---
type: System
title: Hunt & Pounce Grammar
description: The canonical predator sequence (spot/lock -> stalk -> butt-wiggle -> launch -> catch/whiff -> recover) that every hunting context in the product should share, plus its three siblings -- Prey-Lock & Chatter, Void Ambush, and Grapple & Bunny-Kick -- and the retrofit map for the 9+ fragmented implementations that exist today. Designed, not built; the fragments are shipped or dead-callback.
status: Future
tags: [hunt, pounce, predator, stalk, chatter, ambush, grapple, bunny-kick, laser, behavior-grammar]
timestamp: 2026-07-03T00:00:00Z
---

Three of five Phase-2 design lenses independently proposed the same thing:
one motivated predator sequence, instead of the nine-plus independent
fragments the codebase has actually accumulated. This concept is that one
grammar. It is entirely **composed**, not new render tech: every phase
below routes through the `bodyState` channel and per-stage amplitude
scalars owned by [body-pose & compose pipeline](/SYSTEMS/body-pose-pipeline.md)
(§2's `crouch`/`pounce`/`land` tuples, §3's stage scalars, §4's
`positionY`/headroom caps) and the appendage controllers (tail/eye/ear/
mouth/paw) that already render correctly today. **Nothing in this document
requires a new node, a new controller, or new render tech** -- only the
pipeline landing (a separate, already-specified prerequisite) and authored
timelines on top of it.

# 1. The Fragments (code-verified ground truth)

The same predator behavior has been independently authored **nine
separate times**, in nine different files, by nine different call paths.
Every one of them either (a) sets `bodyState`/root-transform values that
[the dropped wire](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)
silently discards, or (b) fires a callback with zero listeners. None of
them talk to each other. This table is the case for consolidation:

| # | Fragment | Location | What it authors | Why it's dead today |
|---|---|---|---|---|
| 1 | `predator_crouch` (autonomous) | `Behavior/BehaviorChoreography.swift:224-234` (`applyPredatorCrouch`); registered `Behavior/BehaviorSelector.swift:167-174` (category `.investigative`, weight 0.6, cooldown 240s, stage-min Critter) | `bodyState = "crouch"`, eyes `"wide"`, tail `"twitch_tip"`, ears `"perk"` (Critter+) | `bodyState` dropped at `applyBehaviorOutput`; only eyes/tail/ears (appendage controllers, all children) render |
| 2 | `predator_crouch` (MCP `pushling_perform`) | `Creature/CatBehaviors.swift:138-165` (priority 5, weight 0.7, cooldown 60s) | Direct root-node `SKAction.scaleY(to: 0.85)` crouch + 3-step `moveBy` haunch wiggle, reachable only via `ActionHandlers.swift:378-389` (or the debug overlay, `PushlingScene+Debug.swift:322-328`) | Root `xScale`/`yScale`/`position` are rewritten every frame by `updateWorld` (`PushlingScene.swift:339-342`, `368-378`) **before** the action's delta from the prior frame can ever accumulate into a visible pose -- same clobber [body-pose-pipeline.md's §"Dropped Wire"](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth) documents |
| 3 | `"chasing"` interaction template (autonomous, world-object) | `World/ObjectInteractionEngine.swift:75-79` (category `.toy`, duration 6-10s, `requiresProximity: 30pt`, `satisfactionBoost: 12`), choreography at `:340-357` | A **complete, already-authored 3-phase state machine**: stalk (progress <0.3, eyes wide/tail twitch/ears perk, `bodyState="crouch"`) -> wiggle (0.3-0.5, `bodyState="crouch"`, tail `"wag"`) -> pounce (>0.5, `bodyState="pounce"`, tail `"high"`) | Same drop -- only tail/eyes/ears render; this is the richest already-written fragment in the codebase and the cheapest possible proof of the pipeline once it lands |
| 4 | Commit-eating "predator crouch" | `App/CommitEatingAnimation.swift:269-320` (comment: *"predator crouch with butt wiggle"*) | Root `SKAction.scaleY(to: 0.85, duration: 0.15)` compress + spring-forward `moveBy` release, on catching an incoming commit | Same root-node clobber as fragment 2 -- a 15% compress that never holds a frame |
| 5 | Surprise #35 Gift Delivery, #36 Butt Wiggle | `Surprise/CatSurprises.swift:156-186` | Full keyframe sequences: `run` -> `pounce` -> `carrying` (gift), and `crouch` -> `wiggle` -> `pounce` -> confused `stand` (butt wiggle, journal: *"There was nothing there. Cat."* -- an authored whiff) | Injected as reflex `LayerOutput`s; `bodyState` values (`"pounce"`, `"wiggle"`) dropped identically |
| 6 | Surprise #2 "Chase" | `Surprise/VisualSurprises.swift:34-49` | `alert` -> `crouch` (+ all 4 paws `"crouch"`) -> `wiggle` -> `run`(80pt/s, right) -> `run`(left) -> `stand` -> `groom`. Journal: *"Chased a mouse across the bar. Missed. Groomed."* | The `run` phase's `speed` field drives real `walkSpeed` integration (horizontal locomotion works today, camouflaged by camera re-centering per the pipeline doc) -- so this fragment is **partially** visible; only the crouch/wiggle body shape is dropped |
| 7 | `play_dead` -> `roll_side` | `IPC/PerformActionMapping.swift:141-150` | `bodyState = "roll_side"`, eyes `"x"`, tail `"limp"` | Dropped; feeds directly into [Grapple & Bunny-Kick's](#6-grapple--bunny-kick) `roll_side` reuse below |
| 8 | `PounceGame` (rapid-tap pounce) | `Input/PounceGame.swift` (full file) | A **real, working reflex-timing state machine** independent of the behavior stack entirely: `.idle -> .hunting -> .pouncing -> .catchWindow -> .idle`, with `crouchDelay=0.3s`, `pounceDuration=0.4s`, `catchWindow=0.3s`, `creatureProximity=50pt`, catch tolerance `20pt` | `onPounceEvent: ((PounceEvent) -> Void)?` (`:36`) has **zero assignments anywhere** (grep-verified) -- `.huntMode`/`.pounce`/`.caught`/`.missed` all fire into silence. Only the two particle effects that bypass the callback (`emitDustPuff`, `emitCatchSparkles`, called directly from within `PounceGame` itself) render. `satisfactionReward = 5` (`:21`) is declared and **never referenced again anywhere in the file** -- the catch has no gameplay reward at all today, contrary to [gesture-response-map.md](/REFERENCE/gesture-response-map.md#rapid-taps)'s current text (see [§9](#9-a-doc-vs-code-correction-owed-to-a-sibling-file)) |
| 9 | `LaserPointerMode` | `Input/LaserPointerMode.swift` | 6-case creature-behavior classification by drag speed (`stalk`/`trot`/`chase`/`stare`/`pounce`/`sniffEnd`, `:66-73`), `pounceDelay=0.5s` stationary trigger, `dotEscapePounce()` (`:207-224`, a 30pt random-direction escape jump) | `onCreatureBehavior: ((LaserCreatureBehavior) -> Void)?` (`:61`) has **zero assignments anywhere**. Worse: `dotEscapePounce()` itself has **zero call sites anywhere in the codebase** -- not even conditionally, from `CreatureTouchHandler`'s laser-drag handling (`:330-336`) or `deactivate()` -- it is not "unwired," it is simply never invoked. Only the dot's own visuals (position/glow/4-node trail) are live |

A tenth fragment, `ObjectInteraction.flickObject`'s `onObjectEvent?(.creatureChase(...))`
(`Input/ObjectInteraction.swift`), is the same dead-callback shape but is
**already documented** by [gesture-response-map.md#flick](/REFERENCE/gesture-response-map.md#flick)
and [interactivity -- unbuilt](/FEATURES/interactivity-unbuilt.md#basic-gesture-responses--creature-side-gaps)
-- cross-linked here as a consumer in [§8](#8-consumer-retrofit-map), not
re-claimed.

**The pattern across all nine:** every fragment independently reinvents
the same crouch-wiggle-pounce shape, and every one is either killed by the
identical root-transform clobber or a `Callback?`-with-zero-assignments.
This is the strongest possible argument that one canonical, fully-specified
grammar -- built once against the pipeline -- retroactively fixes all nine
at once, rather than patching each fragment's render path individually.

# 2. The Canonical Grammar

Six phases. Every static pose below is a `bodyState` string that either
already exists in [the pipeline's tuple table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
or is specified here because the pipeline's table doesn't yet cover it
(flagged inline).

| Phase | Trigger | `bodyState` | Duration | What plays |
|---|---|---|---|---|
| **Lock** | Target enters range | `alert` (pipeline: 1.05/0.95/+0.2/0/+0.25/1.0) | 0.2-0.5s | Freeze; eyes `wide`; ears rotate to `perk`; tail goes rigid (`still`) |
| **Stalk** | Immediately after Lock | `crouch` (pipeline: 0.72/1.12/-0.6/0/-0.2/1.0) | Variable (see [catch-rate table](#3-per-stage-catch-rates--pounce-profiles)) | Creep at 3-5pt/s (Critter baseline) with 300-800ms full freezes (only tail-tip `twitch_tip` and eyes move during a freeze); reuses the existing horizontal-locomotion channel (`walkSpeed`), not a new movement system |
| **Wiggle** | Stalk completes at range | `wiggle` **(gap -- see [§2a](#2a-wiggle-a-bodystate-not-yet-in-the-pipelines-table))** | 0.5-0.9s | Rear-of-silhouette lateral oscillation, count scales with playfulness (personality `energy` axis, `Creature/PersonalitySystem.swift:91`) |
| **Launch** | Wiggle completes | `pounce` (pipeline: dynamic -- eases to 1.10/0.92/+0.15/0/+0.5/1.0 "forward launch lean") | 220-300ms (stage-scaled, [§3](#3-per-stage-catch-rates--pounce-profiles)) | `positionY` parabola through [the pipeline's §4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension) `isAirborne` path, apex capped per stage |
| **Land** | Launch's positionY returns to 0 | `land` (pipeline: 0.62/1.30/-0.4/0/-0.3/1.0, held 2 frames per `PhysicsLayer.JumpState.landingCompressionFrames`) | 2 frames (~33ms) | Front-paw pin (`pawStates` all `"ground"` except forepaws briefly `"tap"`), then branches to **Catch** or **Whiff** |
| **Catch** | Land + roll succeeds | `stand` (front paws pin) | 0.3-0.6s hold | Tail lashes twice (`"lash"`/existing tail vocabulary); triumphant beat, then resumes normal stack |
| **Whiff** | Land + roll fails | See [§2b](#2b-the-whiff-outcome-table) | Variable | One of three named misses, always ending in the shared displacement-groom handoff |

## 2a. `wiggle` -- a `bodyState` not yet in the pipeline's table

Grepped occurrences: `Surprise/CatSurprises.swift:180`, `Surprise/VisualSurprises.swift:42`
(`$0.body = "wiggle"`). **Update (post-flesh-out-keystone-revise):**
[body-pose-pipeline.md's §2](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
no longer claims a 21-string enumeration -- a later wave completed it to
the full, code-verified **111-string inventory** (22 hand-tuned core
strings + 89 aliased in [its §2b](/SYSTEMS/body-pose-pipeline.md#2b-the-remaining-89-strings--alias-map--fallback-rule)),
and both gaps this section originally flagged are now resolved there:
`tense` is aliased to the `crouch` tuple, and `wiggle` is explicitly
carved out as a **named non-alias** -- the pipeline's table catalogs the
string's existence and its consumers but points back here for the
render definition, rather than defaulting it to `shiver` the way the
similar-sounding `stagger`/`wobble` jitter family is. This section
remains the **authority** for that render definition -- the pipeline
only defers to it, it doesn't duplicate it. (`locked_up`, `CatSurprises.swift:96`,
is a separate eye-state controller's contract, not a `bodyState`, and
isn't this table's concern either way.) It's specified here as a
**dynamic** state (matching that table's `bounce`/`spin` convention -- an
oscillation formula, not a fixed tuple, since a lateral rear-shimmy has
no home in the 6-component `(yScale, xScale, yOffset, zRotation,
headOffset, pawAlpha)` tuple as defined):

```
wiggleXOffset(t) = ±0.6-0.8pt lateral, oscillating at 3Hz -> 5Hz over the
                   wiggle's duration (accelerating -- the "building up to
                   it" read), applied to bodyNode's rear half only via a
                   secondary offset composited AFTER the crouch tuple's
                   yOffset, not replacing it
front-half-anchor = true   // front paws/head stay planted; only the rear
                            // silhouette rocks, which is what reads as
                            // "wiggle" rather than "shiver"
```

This needs a rear/front silhouette split that the current single
`bodyNode` transform doesn't expose -- flagged as an open question for
whoever builds this grammar against the pipeline (see [§10](#10-open-questions-for-samantha)):
either a cheap fake (skew the whole `bodyNode` via a small secondary
`SKAction`-free x-shear proportional to a triangular envelope peaking at
the rear) or a genuine front/rear anchor split, which the pipeline's
single-`bodyNode` model doesn't currently support.

## 2b. The Whiff Outcome Table

Three named misses, gated by the personality **Focus** axis
(`Creature/PersonalitySystem.swift:97`, 0.0 scattered / 1.0 deliberate --
already shipped, 0.0-1.0 scale) rather than pure chance, so a whiff reads
as *this cat's* character instead of noise:

| Outcome | Selector | `bodyState` / channel | Beats | Ends in |
|---|---|---|---|---|
| **Overshoot tumble** | Default (mid Focus, 0.3-0.7) | `zRotation` sweep, the one channel `updateWorld` never touches (already the load-bearing survivor per [the pipeline's §"Dropped Wire"](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth)) | 360° roll over 350ms, sit-up-and-blink recovery | Displacement groom |
| **Face-plant** | Low Focus (<0.3) -- misjudged the gap short | `land` tuple held 200ms past its normal 2-frame window (undershoot read: nose-down, `headOffset` pushed further negative than the table value) | 200ms nose-down hold, then 8Hz head-shake (reuses `shake`'s existing `zRotation` oscillation formula from the pipeline's dynamic table) for 250ms | Displacement groom |
| **Whiff-spin** | High Focus (>0.7) but target moved mid-launch (laser dot escaped, companion dodged) | `spin` tuple's existing `zRotation` sweep-to-duration formula, redirected mid-flight | Full 360° spin chasing the target's new position, then a beat of "did that just happen" (`eyes = "confused"` -- already a real eye state, `CatSurprises.swift:182`) | Displacement groom |

**Every whiff hands off to the same beat:** a displacement groom --
over-casual self-washing that reads as "I meant to do that." This is the
shared dignity-recovery beat [emotional
body language](/SYSTEMS/emotional-body-language.md) owns as a general
grooming-chain mechanism (triggered by *any* fumble, not just a hunt
whiff); this concept only specifies the **handoff trigger** (whiff
resolves -> fire the groom-chain's displacement entry point), not the
groom choreography itself. `CatBehaviors.grooming`'s existing 0.1rad
head-tilt `zRotation` (`Creature/CatBehaviors.swift`, one of the few
whole-body `SKAction`s that survives the clobber today via the same
`zRotation`-is-safe loophole) is the cheapest placeholder until that
concept's fuller chain lands.

# 3. Per-Stage Catch Rates & Pounce Profiles

Two lenses proposed different curves for the same five stages (Pounce
Grammar gave wiggle-count and gap-close-speed framing; Wiggle-Pounce gave
explicit catch percentages). This concept **reconciles them as canon** --
see the note under Beast below for the one place they numerically
disagree.

| Stage | Wiggle beats | Catch rate | Whiff rate | Pounce apex (positionY) | Launch duration | Notes |
|---|---|---|---|---|---|---|
| Egg | N/A | N/A | N/A | N/A | N/A | Excluded -- pre-directed-movement, per [growth stages](/REFERENCE/growth-stages.md) |
| Drop | 0 (no stalk) | **30%** | 70% | 2pt (matches the pipeline's already-shipped [Drop hop amplitude](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension), `CreatureNode.swift:209`) | N/A -- reuses the perpetual hop, not a discrete launch | Drop's existing hop **is** the pounce; it "catches" when the hop happens to land on the target. No separate stalk/wiggle choreography -- reuses shipped motion, authors nothing new |
| Critter | 2-4 cycles (playfulness-scaled) | 35% | 65% | **3pt** (proposed here -- pipeline §4 flags Critter's headroom cap as "not yet specified"; this is the first concrete number, pending Airborne Arc System confirmation) | 300ms | Debut stage for the full grammar; frequent charming misses are the point |
| Beast | 4-6 cycles, most dramatic | **75%** | **25%** (see reconciliation note below) | **6pt (hard-capped)** -- the pipeline's [§4 headroom table](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension) already canonizes Beast at exactly 6pt; both source proposals (6-8pt / 12pt-apex) exceed it and are corrected down to the cap, not layered on top of it | ~210ms (30% faster than Critter, per Pounce Grammar's framing) | **Reconciliation:** Pounce Grammar proposed a 10% whiff rate; Wiggle-Pounce's 75% catch rate implies 25%. This concept canonizes **25%** (Wiggle-Pounce's number) because it is the only proposal giving a complete, internally-consistent 5-stage percentage curve; Pounce Grammar's 10% figure is superseded |
| Sage | Skips the wiggle entirely (undignified) -- OR a minimal 2-cycle version if Focus < 0.5 | 90% | 10% | **4pt** (proposed here -- pipeline §4 also flags Sage as "not yet specified"; per Wiggle-Pounce's explicit "low flat 4pt arcs") | 250ms, flat trajectory | Power via subtraction -- one decisive pounce, near-zero theatrics |
| Apex | Vestigial ~0.2pt wiggle ("the joke" -- all three lenses converge here) | 100% | 0% | No leap at all -- see below | Instant | Stalk at 60% alpha (fading toward void = literal OLED stealth); the "pounce" is an **appearance** at the target position, consistent with the pipeline's Apex 2pt hover-lift reinterpretation ([§4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)) applied to this specific move rather than a literal jump |

# 4. Prey-Lock & Chatter (the ekekek)

The frustrated cousin of the hunt cycle -- all intent, no execution, for a
target the creature can see but can't reach (a companion overhead, a sky
event, the laser dot held just out of stalking range). The mouth
`"chatter"` state already ships and already renders (it's an appendage
controller, a child node, immune to the root clobber) via two independent
call paths -- but both are **context-free**, with no target and no
crouch:

- `BehaviorChoreography.applyChattering` (`Behavior/BehaviorChoreography.swift:237-246`) -- autonomous, sets `mouthState="chatter"` + eyes `"wide"` + ears `"perk"` (Critter+), no target, no `bodyState` at all.
- `CatBehaviorsExtended.chattering` (`Creature/CatBehaviorsExtended.swift:72-99`, MCP `pushling_perform`, priority 4, weight 0.4, cooldown 180s) -- its own section comment reads **"At Flying Things"**, yet the implementation has zero target input and zero body compression; a canned 2s mouth/eye/ear/tail sequence that always auto-ends the same way regardless of what, if anything, is overhead.
- Surprise #31 "Chattering" (`Surprise/CatSurprises.swift:89-101`) -- a fourth authored instance, this one with a genuinely evocative `eyes = "locked_up"` state and `body = "tense"` (another `bodyState` gap, see [§10](#10-open-questions-for-samantha)) and the journal line *"Something flew overhead. The chattering was intense. It escaped."* -- scripted as a one-off rather than a motivated, reusable reaction.

**The retrofit:** give the existing `"chatter"` mouth state the target and
crouch it's always been missing.

| Beat | Duration | What plays |
|---|---|---|
| Sink | 200-300ms | `bodyState = "crouch"` (pipeline tuple, unmodified) -- but held rigidly still, unlike the Hunt Cycle's creeping Stalk |
| Lock | Held 1.5-3s | Everything freezes except: eyes track the target's X via head yaw (±0.1rad, reusing `CreatureNode`'s existing head-follow math wherever it already tracks a companion node); mouth `"chatter"` at the existing 2s auto-cycle; tail-tip `twitch_tip` at high frequency while the tail base stays planted |
| Break | 0.5-1s | Frustrated tail-lash (reuses the Whiff table's tumble-adjacent `zRotation` lash, not a new asset) then a deliberately casual look-away and walk-off |

**Stage gating:** Critter debuts it (brief); Beast holds the longest,
most intense fixation; Sage gives one dignified chirp-trill instead of
frantic chatter (a `mouthState` this concept doesn't yet name -- flagged
alongside the other bodyState gaps); Apex doesn't chatter at all -- it
teleport-blinks the target closer via `auraState` (consuming [the
pipeline's §8 aura consumption](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption),
`transcendent` or a bespoke aura read), the only stage that resolves its
own frustration.

**Safest triggers, in order:** the in-scene companion node (bird/butterfly/
fish -- position already available), then laser-pointer mode's dot held
just outside stalking range. A live cursor-hover trigger is explicitly
out of scope -- Touch Bar touch is binary with no hover, so there is no
"the cursor is overhead but not touching" signal to read.

# 5. Void Ambush

Slink-crouch behind a world object or terrain rise, fade to true OLED
black -- genuinely invisible except two blinking eye-dots -- then explode
out at a trigger, or 20% of the time at nothing at all.

| Beat | Duration | What plays |
|---|---|---|
| Slink | Variable | `bodyState = "crouch"` at 0.65 yScale (per-lens number, slightly deeper than the pipeline's stock 0.72 crouch -- a stealth-specific variant, not the stock tuple) |
| Fade | 800ms | All part-controller alphas -> 0 (ears/eyes/tail/mouth/paws/body), except two `bone`-colored 0.8pt eye-dot nodes that persist at full alpha, blinking on a 4s cycle and tracking the target's X via the same head-yaw math as Prey-Lock |
| Hold | 3-10s | Genuinely idle -- **zero camera or locomotion cost**, the cheapest hold-state in the whole grammar |
| Burst | 100ms | Alpha snaps to 1.0 simultaneously with a no-wiggle emergency Launch (this concept's [§2](#2-the-canonical-grammar) Launch phase, skipping Stalk/Wiggle entirely -- ambush is explicitly the one hunt variant with no telegraph) |
| Walk-off (20% of holds) | -- | No trigger arrives; look left, look right, casual walk-off -- the "ambushing nothing" branch that makes the 80% real ambushes land harder |

Trigger detection is a proximity check against the existing companion
node and the ≤12 world objects (`world-objects-system.md`'s object cap),
polled at 250ms -- cheap, matching the "costs nothing while holding
still" framing in the source proposal.

**Stage gating:** Critter hides terribly on purpose -- tail stays fully
visible and wiggling beside the cover object, body only fades to 60%
alpha (comedy, not competence). Beast gets a clean vanish with a 0.3-alpha
ember ear-tip tell (a small deliberate imperfection). Sage vanishes
perfectly, eye-dots narrowing to 0.3pt slits. Apex inverts the whole
mechanic -- it doesn't hide; the world dims 10% around it and prey wanders
in on its own (consuming [the pipeline's `auraState`](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)
rather than an alpha fade).

**Dependency note:** the per-part alpha fade needs [the pipeline's §7
sprite-stack propagation](/SYSTEMS/body-pose-pipeline.md#7-sprite-stack-propagation)
to ship in the same WO, or the depth-stack layers behind the front body
(3-7 layers at Critter+) will stay visible after the front body fades,
breaking the "genuinely invisible" premise the whole feature depends on.

# 6. Grapple & Bunny-Kick

The predator's finishing move -- the payoff for a Hunt Cycle catch, and
the missing body-motion for the shipped-but-inert belly-rub trap
(`Input/CreatureTouchHandler.swift:428-439`: `handleBellyRub()` rolls a
20%/40% trap chance by personality energy, and on a trap does **nothing
but `NSLog`** -- no animation, not even a contentment penalty; the "trap"
today is invisible except by the *absence* of the normal +15 contentment
outcome).

| Beat | Duration | What plays |
|---|---|---|
| Grab | 250ms | Forepaws clamp the target; `bodyState` rotates 80° to `"roll_side"` (pipeline tuple: 0.65/1.30/-0.5/**1.40**/0.0/0.55 -- the `zRotation=1.40` component *is* the "rotate to its side" read, already authored by [the pipeline table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table) for `play_dead`, fragment 7 in [§1](#1-the-fragments-code-verified-ground-truth) -- this is `roll_side`'s **second** caller, exactly as the source proposal names it) |
| Kick | 1-2s (personality-scaled reps, 4-8 at high Energy) | Rear paw-beans piston 2-3pt at 5-6Hz; body rocks ±1pt roll per kick (a small oscillation on top of the held `roll_side` tuple, not replacing it); tail lashes |
| Flop | 100ms | Full release, `bodyState` returns toward `stand`; `breathPeriodOverride` (`Creature/CreatureNode.swift:75`, already shipped and already exercised by `DreamEngine`/`EmotionalVisualController` for slow/fast breathing -- `EmotionalVisualController.swift:194-198`'s pattern is the one to imitate, not the `LayerOutput`/behavior-stack channel) set to roughly half the awake period (`~1.2s` vs the default `2.5s`) for the following 1.5s hold to read as visibly fast breathing, then released back to `nil` |

## The Beast+ hind-leg (`legHeight`) decision

`ShapeFactory.makePaw` already accepts `legHeight`/`legAngle`/`isFront`
parameters and renders a real tapered leg shape via `CatShapes.catLeg`
(`Creature/CatShapes.swift:468-`, which already differentiates front-leg
"clean inward taper" from back-leg "outward thigh bulge then taper" --
the hind-leg shape is already designed, just unused). **All five
`StageRenderer` call sites** (`:235-241`, `:330-336`, `:444-450`,
`:615-621`) construct paws with the parameter's default, `legHeight: 0`
-- no caller anywhere passes a nonzero value; `PawController`'s
`"_leg"`-suffixed node lookup (dead code, since the node it would find
never exists) confirms this has been true since the parameter was added.

**Decision:** do not make hind legs a permanent Beast+ structural change
(that is a broader silhouette redesign this concept isn't authorized to
make). Instead, **this move alone** activates `legHeight` transiently:
Beast+ passes `legHeight: 3.0, isFront: false` to the two rear
`makePaw` calls for the duration of the Kick beat only (driven by
`legAngle` oscillating through the same 5-6Hz piston formula as the
paw-bean position), reverting to `legHeight: 0` on Flop. This is scoped,
reversible, and costs nothing outside the ~1-2s the move plays. **Below
Beast**, the fallback the source proposal specifies is used unmodified:
rear paw-beans alone piston against a flattened `roll_side` body -- no
legs, no fallback assets to author. The **general** `StageRenderer` ->
`ShapeFactory` wiring contract for `legHeight` (the plumbing itself, for
any future consumer) is [rendering-stack-2-5d.md](/SYSTEMS/rendering-stack-2-5d.md)'s
concern, not re-specified here -- this section makes the creative call for
*this* move only and should be the reference example that concept's
general wiring section cites.

**Stage gating:** Critter does a brief clumsy two-kick, sometimes losing
the toy mid-kick (it shoots 6pt away -- an instant re-chase back into
[§2](#2-the-canonical-grammar)'s Stalk phase). Beast is the signature
stage -- full sustained flurry, the toy visibly squashes 10% per kick
(a world-object transform, not a creature one). Sage does one ceremonial
slow kick then a hug-hold instead of a flurry (dignity). Apex holds the
target to its chest with no kicks at all, aura brightening 10% (another
[§8 aura](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption)
consumer). Drop can't grapple (no legs, no roll rig at that scale per
[the pipeline's Drop amplitude note](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)) --
it belly-flops onto the toy and vibrates instead, its own version of the
same beat.

# 7. Target-Position Plumbing

The grammar is generic over *where the target is* -- every consumer just
needs to supply a target X (and, for the laser dot, a speed) into the same
six phases:

| Source | Target-X available today? | Wiring needed |
|---|---|---|
| Laser dot | **Yes** -- `LaserPointerMode.updatePosition` already computes it and classifies speed into the right phase (`:159-203`) | Assign `onCreatureBehavior` (fragment 9) to route into this grammar's phases instead of a bespoke response; wire `dotEscapePounce()`'s **currently-never-called** escape jump to fire on a Catch outcome specifically (turning a plain catch into occasional "it got away" content) |
| Rapid-tap ground pounce | **Yes** -- `PounceGame`'s own phase machine already tracks a target X through `.hunting`/`.pouncing`/`.catchWindow` | Assign `onPounceEvent` (fragment 8) to drive this grammar instead of silence; `PounceGame`'s own timings (`crouchDelay`/`pounceDuration`/`catchWindow`) are close enough to [§3](#3-per-stage-catch-rates--pounce-profiles)'s Critter-baseline numbers to reuse directly rather than re-tuning |
| World-object toy (autonomous) | **Yes** -- `ObjectInteractionEngine`'s `"chasing"` template (fragment 3) already tracks `objectX` | Replace the template's hand-rolled progress-phase bodyState assignments with calls into this grammar's phase functions -- this is the **cheapest possible retrofit**, since the template's own phase boundaries (0.3/0.5 progress splits) already match this grammar's Stalk/Wiggle/Launch structure almost exactly |
| Flicked object (reactive, 📐) | Physics is shipped (`ObjectInteraction.flickObject`'s per-object mass/bounce, [gesture-response-map.md#flick](/REFERENCE/gesture-response-map.md#flick)); target tracking is not | `onObjectEvent`'s `.creatureChase` case ([interactivity -- unbuilt](/FEATURES/interactivity-unbuilt.md#basic-gesture-responses--creature-side-gaps)'s designed 200pt sight-range chase) is the trigger; once wired, its arrival beat should call this grammar's Launch/Land/Catch phases instead of authoring a new pounce, and its "high-discipline carries it back" fetch behavior hands off to [play-bouts.md](/SYSTEMS/play-bouts.md)'s toy-return mechanics rather than duplicating them here |
| Companion prey (bird/mouse/butterfly) | Companion X is already in-scene (per the design grounds) | Same phase calls; companions that are caught should trigger a startle-hop reaction on their own node, distinct from this grammar's creature-side phases |

# 8. Consumer Retrofit Map

| Consumer | Current state | What changes |
|---|---|---|
| `predator_crouch` (autonomous + MCP) | Two independent, both-dead crouch fragments (#1, #2 in [§1](#1-the-fragments-code-verified-ground-truth)) | Both become thin callers into this grammar's **Lock + Stalk** phases only (no target -- autonomous investigative browsing has no prey, so it never reaches Wiggle/Launch); the name `predator_crouch` can retire once every caller routes through the shared phases |
| `"chasing"` interaction template | Fully authored 3-phase machine, dropped at body level (#3) | Cheapest retrofit -- see [§7](#7-target-position-plumbing) |
| Commit-eating crouch | Root-clobbered SKAction (#4) | Retarget at `bodyPoseController.setState` (per [the pipeline's §6 rule](/SYSTEMS/body-pose-pipeline.md#6-the-single-compose-point-full-formula) -- "if ever reactivated, must target `bodyPoseController.setState`, not `bodyNode` directly") instead of a raw `SKAction`, calling this grammar's Stalk phase with the incoming commit as the target |
| Surprises #35/#36/#2 | Authored keyframes, dropped `bodyState` (#5, #6) | No change needed to the surprise definitions themselves once the pipeline lands -- they already produce the right strings; this is the one consumer that costs nothing beyond the pipeline itself |
| `PounceGame` (rapid-tap) | Real timing, dead callback (#8) | See [§7](#7-target-position-plumbing) |
| `LaserPointerMode` | Real classification, dead callback + genuinely-uncalled escape (#9) | See [§7](#7-target-position-plumbing); also fixes the `gesture-response-map.md` inaccuracy in [§9](#9-a-doc-vs-code-correction-owed-to-a-sibling-file) |
| 📐 Flick-chase/fetch | Physics shipped, trigger dead | See [§7](#7-target-position-plumbing) |
| Ambient prey (Bug Season, 📐) | Not yet built | Owned by [ambient-wildlife.md](/SYSTEMS/ambient-wildlife.md); consumes this grammar's phases for the stalk/pounce hunt-verb species, cross-linked there, not duplicated here |

# 9. A doc-vs-code correction owed to a sibling file

Two verified inaccuracies in [gesture-response-map.md](/REFERENCE/gesture-response-map.md),
found while grounding this concept against the same source files that doc
cites -- **not fixed here** (out of this wave's assigned scope: disjoint
files, no cross-edits), flagged for Samantha to route:

1. **`#laser-pointer` (lines ~102-106):** the doc states `dotEscapePounce()`
   "-- called if the finger is still down after the pounce." Grep-verified:
   `dotEscapePounce()` has **zero call sites anywhere in the codebase**,
   including from the laser-drag handling in `CreatureTouchHandler.swift`
   that would need to call it. It is not merely unwired via a dead
   callback (like `onCreatureBehavior`) -- it is simply never invoked at
   all.
2. **`#rapid-taps` (lines ~217-226):** the doc states a catch yields "+5
   satisfaction -- `satisfactionReward`." Grep-verified:
   `PounceGame.satisfactionReward` (`:21`) has **zero references anywhere
   in the file besides its own declaration** -- it is never added to
   anything. The doc's own next sentence *does* correctly flag the
   `"got it!"` speech line as code-absent, but doesn't extend the same
   scrutiny to the reward constant one sentence earlier, nor mention that
   `onPounceEvent` itself (the callback that would drive the creature's
   crouch/launch/whiff, i.e., fragment 8 above) has zero listeners at all
   -- the same "declared event, zero listeners" pattern the doc correctly
   calls out for Laser (two paragraphs earlier) and Flick (below), just
   not for Rapid Taps.

# 10. Open Questions for Samantha

- **`wiggle`'s rear/front silhouette split** ([§2a](#2a-wiggle-a-bodystate-not-yet-in-the-pipelines-table))
  doesn't fit the pipeline's single-`bodyNode` transform model cleanly --
  needs a build-time call on whether a shear approximation is good enough
  or a real anchor split is worth it.
- **`bodyState` enumeration completeness -- RESOLVED:** this wave's
  research turned up `wiggle`, `tense`, and the eye state `locked_up` as
  real, shipped strings not present in
  [body-pose-pipeline.md's §2 table](/SYSTEMS/body-pose-pipeline.md#2-the-bodystate--transform-tuple-table)
  at the time. A later flesh-out-keystone-revise wave closed this gap:
  the table now covers the full 111-string inventory, `tense` aliases to
  `crouch`, and `wiggle` is carved out as this concept's own render
  authority (see [§2a](#2a-wiggle-a-bodystate-not-yet-in-the-pipelines-table)'s
  updated text). `locked_up` remains out of scope for either doc -- it's
  an eye-state controller's contract, not a `bodyState`.
- **Critter and Sage pounce apexes** (3pt, 4pt above) are this concept's
  proposal, not yet cross-confirmed by [body-pose-pipeline.md's §4](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension)
  (which explicitly left them open) -- should be folded back into that
  table's headroom cap list once ratified, so there's one authoritative
  home for all five stage caps instead of two documents each holding half.
- **The §9 doc corrections** should route to whoever next touches
  `gesture-response-map.md`.
- **Commit-eating's "predator crouch"** (fragment 4) is not named in the
  dossier's `covers` list for this concept, but it is unambiguously the
  same grammar under a fourth name -- flagging it as an in-scope retrofit
  target (see [§8](#8-consumer-retrofit-map)) rather than silently leaving
  a tenth fragment out of the consolidation.
- **The Beast+ `legHeight` decision** ([§6](#6-grapple--bunny-kick)) is
  made here because the dossier explicitly ties it to this move, but
  `rendering-stack-2-5d.md`'s deepening also names "the legHeight-at-Beast+
  decision" as its own scope -- worth confirming the split (this concept
  owns the creative call for *this* move; that concept owns the general
  `StageRenderer`/`ShapeFactory` wiring contract) doesn't collide with
  whatever that sibling wave lands.

# What This Concept Does Not Cover

- The **rendering mechanism** for `crouch`/`pounce`/`land`/`roll_side`
  transforms -- owned entirely by [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md),
  which this concept only consumes.
- **Landing recovery and general momentum/skid physics** after any
  launch -- owned by [locomotion-and-gait.md](/SYSTEMS/locomotion-and-gait.md)'s
  Weight & Momentum Model; this concept's Land/Catch/Whiff phases hand off
  to it rather than authoring their own settle physics.
- **The displacement-groom choreography itself** (only the handoff
  trigger) -- owned by [emotional-body-language.md](/SYSTEMS/emotional-body-language.md)'s
  Grooming Chain.
- **Autonomous scheduling** of *when* a hunt bout starts (play-pressure,
  cooldowns, caps) -- owned by [play-bouts.md](/SYSTEMS/play-bouts.md),
  which calls into this grammar's phases as its Escalate/Climax beats
  rather than this concept scheduling itself.
- **Ambient prey species** (Bug Season) that hunt-verb-map onto this
  grammar -- owned by [ambient-wildlife.md](/SYSTEMS/ambient-wildlife.md).
- The 📐 **flick-chase/fetch** trigger wiring itself (only its consumption
  of this grammar once wired) -- owned by whichever WO connects
  `ObjectInteraction.onObjectEvent`.

# Citations

[1] `Pushling/Sources/Pushling/Behavior/BehaviorChoreography.swift` (`applyPredatorCrouch:224-234`, `applyChattering:237-246`)
[2] `Pushling/Sources/Pushling/Behavior/BehaviorSelector.swift` (`predator_crouch` registration, `:167-174`)
[3] `Pushling/Sources/Pushling/Creature/CatBehaviors.swift` (`predatorCrouch:138-165`, `all` registry)
[4] `Pushling/Sources/Pushling/Creature/CatBehaviorsExtended.swift` (`chattering:72-99`)
[5] `Pushling/Sources/Pushling/IPC/ActionHandlers.swift` (`:378-389`, MCP `pushling_perform` dispatch)
[6] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift` (`"chasing"` template `:75-79`, `:340-357`)
[7] `Pushling/Sources/Pushling/App/CommitEatingAnimation.swift` (`:269-320`, "predator crouch with butt wiggle")
[8] `Pushling/Sources/Pushling/Surprise/CatSurprises.swift` (#35 Gift Delivery `:156-169`, #36 Butt Wiggle `:173-186`, #31 Chattering `:89-101`)
[9] `Pushling/Sources/Pushling/Surprise/VisualSurprises.swift` (#2 Chase `:34-49`)
[10] `Pushling/Sources/Pushling/IPC/PerformActionMapping.swift` (`play_dead` -> `roll_side`, `:141-150`)
[11] `Pushling/Sources/Pushling/Input/PounceGame.swift` (full file -- `onPounceEvent`, `satisfactionReward`, phase timing constants)
[12] `Pushling/Sources/Pushling/Input/LaserPointerMode.swift` (full file -- `onCreatureBehavior`, `dotEscapePounce`, speed thresholds)
[13] `Pushling/Sources/Pushling/Input/ObjectInteraction.swift` (`flickObject`, `onObjectEvent`)
[14] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (`handleBellyRub:428-439`, laser-drag dispatch `:330-336`)
[15] `Pushling/Sources/Pushling/Creature/ShapeFactory.swift` (`makePaw:276-315`, `legHeight` default)
[16] `Pushling/Sources/Pushling/Creature/CatShapes.swift` (`catLeg:468-`, front/back taper differentiation)
[17] `Pushling/Sources/Pushling/Creature/StageRenderer.swift` (all 5 `makePaw` call sites, `:235-241`, `:330-336`, `:444-450`, `:615-621`)
[18] `Pushling/Sources/Pushling/Creature/PersonalitySystem.swift` (`energy:91`, `focus:97` axes)
[19] `Pushling/Sources/Pushling/Creature/CreatureNode.swift` (`breathPeriodOverride:75`)
[20] `Pushling/Sources/Pushling/Creature/EmotionalVisualController.swift` (`breathPeriodOverride` usage pattern, `:194-198`)
[21] `/SYSTEMS/body-pose-pipeline.md` (the `bodyState` tuple table, headroom caps, blend timing, aura consumption -- authority for every transform this concept references)
[22] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.proposals` (LOCOMOTION & PHYSICALITY: "Pounce Grammar"; Feline Ethology: "The Hunt Cycle", "Prey-Lock & Chatter", "Bunny-Kick Toy Wrestle"; Play & Toys: "Wiggle-Pounce & the Comedy of Misses", "Grapple & Bunny-Kick", "Void Ambush", "Chatter at the Unreachable")
[23] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` lines 37-40, 106-107, 112-113, 115-116, 166-167 (Hunt & Pounce spec, covers list)
