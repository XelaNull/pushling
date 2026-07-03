---
type: System
title: Environment Reactions
description: Every ambient world system terminates in a creature verb — the sky-theater per-event reaction table (7 VisualEvents + full moon), the streak-aurora sentimental glance-back, weather-anticipation (horizon fronts + sense-beat + shelter-seeking), Gust Front's windVector body language, Snow Memory's footprint/cap/shake-off record, Puddle Days & Dabbing's play verbs, and the Golden Hour dusk vantage ritual. Designed, not built, except where cited as shipped.
status: Future
tags: [world, weather, sky, reflex, reaction, wind, snow, puddle, dusk, system]
timestamp: 2026-07-03T00:00:00Z
---

This is the authority for **how the creature's body answers the world** —
every reaction verb the ambient/weather/sky systems provoke. It does not own
any ambient system's own state machine or renderer: sky gradient/moon/stars/
clouds belong to [sky & celestial](/SYSTEMS/sky-celestial.md); the six-state
weather machine, its particle renderers, and the *already-shipped*
rain/lightning/thunder/snow-begin/fog/weather-clear reactions belong to
[weather](/SYSTEMS/weather.md); the seven `VisualEvents` spectacles'
renderers belong to [world complexity & ambient
effects](/SYSTEMS/world-complexity-ambient-effects.md); the torso transform
every posture below ultimately resolves to belongs to [body pose &
compose](/SYSTEMS/body-pose-pipeline.md); "boldness"/shelter-seeking and
puddle-tiptoe personality weighting are derived signals owned by
[personality & emotional state](/REFERENCE/personality-emotional-state.md).
This concept is the **consumer** of all of them — it specifies the reaction,
not the thing reacted to.

Source referenced (nothing below is a new file until built):
`World/VisualEvents.swift`, `World/VisualEventBuilders.swift`,
`World/MoonPhase.swift`, `World/WeatherSystem.swift`,
`World/SnowRenderer.swift`, `World/PuddleReflection.swift`,
`World/TerrainObjectPool.swift`, `World/TerrainGenerator.swift`,
`World/AttractionScorer.swift`, `Input/PetStreak.swift`,
`Surprise/SurpriseAnimationPlayer.swift`, `Behavior/ReflexLayer.swift`,
`Behavior/BehaviorStack.swift`.

# The One Reusable Bridge: Reflex Injection, Not a New Mechanism

Every reaction in this document is designed to ride the **same, already-built
bridge** the surprise catalog uses — no new behavior-stack machinery is
proposed anywhere below. `SurpriseAnimationPlayer` (shipped,
`Surprise/SurpriseAnimationPlayer.swift:1-10`) documents its own rule in a
header comment: *"Short surprises (<10s) are injected as
`ReflexDefinition`s. Long surprises (>=10s) inject a series of reflexes over
time."* — via the `onInjectReflex` callback into
`BehaviorStack.triggerReflex(_:at:)` (`BehaviorStack.swift:336`). A
`ReflexDefinition` (`ReflexLayer.swift:21-24`) is a `(duration,
fadeoutFraction, LayerOutput properties)` tuple; `ReflexLayer` holds up to 5
concurrent `ActiveReflex` instances (behavior-stack.md's Layer 2). This is
exactly the shape every reaction table below needs: a short reflex for a 2s
shooting-star startle, a **chain** of reflexes for a 45s aurora gaze. No new
LayerOutput fields, no new priority layer — every mechanism below is
authored as one or more `ReflexDefinition`s and a trigger call site.

**Degrade-gracefully rule, stated once:** every reaction below that names a
`bodyState` (`sit`, `crouch`, `alert`, etc.) or a `positionY` hop is written
against [body pose & compose](/SYSTEMS/body-pose-pipeline.md)'s pipeline,
which is itself designed-not-built. Until that pipeline ships, every such
reaction **silently degrades** to its head/eye/ear/tail/whisker/paw
components only (the reflex still fires, the torso just doesn't move) —
this document does not gate any reaction behind the pipeline landing first;
it specifies the full intended reaction and flags the degraded fallback
inline.

# 1. Sky Theater Reflex

A per-event reaction wired to the 7 shipped `VisualEvents` types
(`shooting_star`, `aurora`, `bloom`, `eclipse`, `festival`, `fireflies`,
`rainbow` — confirmed exhaustive against
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md#visual-event-spectacles)'s
event table, not a design guess) plus the moon's `isFullMoon` state
(`MoonPhase.swift:254`). **Zero new renderers** — every row below is a
reflex injection keyed off the same trigger point `VisualEventManager`
already has (one dictionary lookup at event start, per-event `ReflexDefinition`
chain matching the event's own shipped duration so the reaction never
outlives its spectacle).

| Event | Shipped duration | Reaction | Reaction duration | Channels used today | Needs body-pose fix? |
|---|---|---|---|---|---|
| `shooting_star` | 2s | Freeze mid-pose; head rotates up 0.15rad; eyes track the streak L→R; one ear-flick; glance toward screen-front | 0.8s track + 0.3s glance | head, eyes, ears | No — pure head/eye/ear |
| `aurora` | 45s | Walk ≤40pt to open ground; sit; head up 0.2rad; eye-fill color lerps tide→dusk→tide on a 3s cycle; tail wraps front paws | Full 45s, chained reflexes | head, eyes (fill-color lerp), locomotion (walk works today) | **Yes** — `sit` bodyState; degrades to standing gaze |
| `eclipse` | 20s | Body puffs to 1.08 `xScale`; `crouch` bodyState; eyes full-round; whiskers forward; held frightened-awe stillness | Full 20s (5s ramp + 10s hold + 5s release, matching the event's own eclipse ramp/hold/release per world-complexity-ambient-effects.md) | eyes, whiskers | **Yes** — `crouch`/puff; degrades to eyes+whiskers only |
| `fireflies` | 45s | 2-3 pounce attempts: predator crouch, 6pt hop arc at nearest firefly point, paw swipe on landing | ~8-12s per attempt × 2-3 | paws (swipe works today) | **Yes** — crouch + hop `positionY`; degrades to paw-swipe-in-place |
| `rainbow` | 20s | Trot 30-50pt toward the rainbow's terrain end; stop; sit; head-tilt 0.1rad | ~5-8s trot + hold to event end | head, locomotion (walk works today) | **Yes** — `sit`; degrades to stand + head-tilt |
| `bloom` | 5s | Sniff-and-sneeze: head lowers 0.1rad toward the rising Moss particles, one sneeze-flinch (reuses the shipped `tool_wince` flinch's 1.2s cascade shape at 1/3 scale) | ~2s of the 5s window | head, mouth | No — pure head/mouth |
| `festival` | 15s | Bounce-in-place: `bounce` bodyState oscillation synced to the confetti's staggered timing | Full 15s | — | **Yes** — fully gated on body-pose; degrades to ear-perk + tail-sway only |
| Full moon rise (`isFullMoon`) | n/a (state, not event) | **Already shipped** — Surprise #57's `fullMoon` definition (`Surprise/TimeSurprises.swift`, `isEligible: { Self.isFullMoon(date:) }`) plays a one-shot 2.5s howl: `eyes = "closed"`, `ears = "back"`, `mouth = "open_small"`, `body = "howl"`, whispered speech `"awoo"` | 2.5s (`kf(2.0, 1.5)`) | eyes, ears, mouth, body, speech | This row is **satisfied by existing code** — Sky Theater does not need to author a new full-moon reaction; it is listed here for completeness against the dossier's "7 events + full moon" framing, not as new scope. Note for [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md): the surprise system's `.body = "howl"` keyframe field sets a 23rd literal `bodyState` string ("howl") not present in that concept's 21/22-entry enumeration — a citation gap worth folding into that doc's next pass, not fixed here. |

**Stage gating** (applies uniformly across all 7 event rows above; full moon's
reaction is stage-agnostic since it's a pre-existing surprise):

| Stage | Modifier |
|---|---|
| Egg | Shell-wobble amplitude doubles during any active event (feels it through the shell — no locomotion, no bodyState). |
| Drop | Head/eye/ear tracking only; no locomotion, no pounce/hop component. |
| Critter | Full reaction as tabled. |
| Beast | Bold variants: chases fireflies harder (all 3 attempts, not 2-3 rolled), stands tall (`yScale` 1.05) through the eclipse rather than crouching. |
| Sage | All reactions become sit-and-contemplate variants with slow blinks (reuses [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md)'s slow-blink primitive once that lands). |
| Apex | Adds aura resonance: `auraNode` alpha pulses in the event's accent color (gilt for festival, dusk for aurora) — this is `auraState` consumption, owned by [body-pose-pipeline.md §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption); Sky Theater only selects which accent color to request, not how it renders. |

**Feasibility:** frame cost is one dictionary lookup at each event's start
(`VisualEventManager`'s existing per-case switch already has a hangable
callback point); no new nodes for any row above except the ones already
budgeted by the event renderers themselves. Personality's `boldness` axis
(picking chase-harder vs. hide-longer variants) does not exist on the
shipped 5-axis `Personality` model (Energy/Verbosity/Focus/Discipline/
Specialty — [personality & emotional state](/REFERENCE/personality-emotional-state.md#personality-5-axes)) —
this table's stage-gated variants are authored as **fixed per-stage**
behavior rather than a personality-modulated one, pending that concept's
own axis-derivation work for "boldness."

# 2. Streak Aurora Nights — the sentimental special case

An autonomous trigger for the shipped 45s aurora builder, keyed to
`PetStreak.streakDays >= 7` (`Input/PetStreak.swift:15`, the existing
`giftStreakThreshold` constant — reused as a *second* consumer distinct from
its current sole use gating the daily-gift behavior;
[touch-milestones.md](/SYSTEMS/touch-milestones.md) documents that this
streak is not wired to fire anything automatically at midnight today, so
this feature and the gift-check both need the same not-yet-built
midnight-tick call site) or a `MilestoneTracker` milestone landing that
same day. **No code wires `PetStreak` to `VisualEventManager` today** —
this entire feature is a new trigger connecting two systems that currently
don't know about each other.

The reaction is **Sky Theater's own `aurora` row (§1), unmodified, plus one
addition**: at the 20s mark of the 45s gaze, three head keyframes fire in
sequence —

| Keyframe | Time | Head/eye state |
|---|---|---|
| 1. Turn | 20.0s | Head group rotates to face screen-front dead-on over 0.4s |
| 2. Hold | 20.4s–22.4s | Full 5-shape eye-open, one slow blink at 21.4s |
| 3. Return | 22.4s | Head rotates back to sky-gaze over 0.4s |

— "are you seeing this too?" On streak nights only, 2-3 gilt flecks drift
down from the ribbons (a cosmetic addition to the shipped aurora renderer,
owned by [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md),
noted here as this feature's one rendering ask of that concept).

**Never wakes a sleeping creature** — the trigger explicitly checks
`!creature.isSleeping` (the same guard `weather.md`'s `CatWeatherReactions`
already uses at `guard !creature.isSleeping`) before scheduling; if the
creature is already asleep when the streak/milestone condition is met that
night, the aurora still plays (it's a world-level `VisualEvents` spectacle,
not creature-gated) but the creature's reaction is skipped entirely — the
sleeping silhouette under the aurora is its own screenshot, not a bug to
fix.

**Stage gating:** Critter watches from wherever it is (no glance-back).
Beast gets the full ritual including the glance-back above. Sage/Apex ride
Sky Theater's own §1 stage table (contemplative gaze / aura resonance) with
the glance-back beat layered in identically.

# 3. Weather on the Horizon

20-40 seconds of advance warning before `WeatherSystem` transitions to
rain, storm, or snow — the creature senses the front before the human can
read it. **Concrete hook point, verified against shipped code:**
`WeatherSystem.checkForWeatherChange()` runs once every 5 minutes
(`checkInterval = 300`, `WeatherSystem.swift:145`) and, on a hit, calls
`selectNextWeather()` then `beginTransition(to:)` (`WeatherSystem.swift:265,
294`) — the decision and the start of the 30-60s crossfade
(`transitionDurationRange`, `WeatherSystem.swift:148`) happen at the exact
same instant. There is **no existing lead-time signal** — the crossfade
begins immediately at `beginTransition`. This feature's only new hook is a
delegate callback fired from inside `beginTransition` (before the renderer
crossfade itself starts), giving the front visual and the creature's
sense-beat their full runway *inside* the crossfade's own 30-60s window
rather than needing a second, separate scheduler: "first drops" is defined
as the point where `WeatherTransition.progress` (already computed every
frame by `updateTransitionRenderers`, `WeatherSystem.swift:343`) crosses
0.4 — i.e., the front is visible and sensed from progress 0.0, and the
20-40s lead time falls naturally out of wherever 0.4 lands within that
transition's randomly-rolled 30-60s duration.

| Incoming state | Front visual (far parallax layer, zPos -100, per [world terrain & parallax](/SYSTEMS/world-terrain-parallax.md#parallax-layers)) |
|---|---|
| Rain | Ash-tinted column, 30pt wide, 0.75pt diagonal hatch strokes at 0.25 alpha, sliding in at ~2pt/s |
| Storm | Same as rain, plus one 60ms Bone flash inside the column |
| Snow | Soft Bone gradient band, same 30pt width and slide rate |

**Sense-beat** (2s, fires at progress 0.0 — the earliest possible moment):
full stop → head rises 0.15rad → two sniff bobs (0.5s each) → both ears
swivel windward and hold. All four channels (head, mouth/sniff, both ears)
work today per [weather.md](/SYSTEMS/weather.md#creature-reactions)'s
already-shipped rain/snow/fog reactions using the same controller set.

**Shelter-seeking** (personality-weighted, timed to settle at progress
≈0.35, just before the "first drops" threshold at 0.4): walks to the
nearest object with `height >= 6` from the shipped `TerrainObjectPool`
(`.tree` height 8, `.ruinPillar` height 6 —
`World/TerrainObjectPool.swift:33-41`; **not** the 20-preset interactive
`WorldObjectRenderer` catalog documented in
[world-objects-system.md](/SYSTEMS/world-objects-system.md) — these are two
distinct object systems and this feature deliberately queries the ambient
one), reusing `TerrainRecycler.nearestObjectOfType(_:to:maxDistance:)`
(`TerrainRecycler.swift:437`) exactly as `WorldManager.findNearestPuddle`
already does for `.waterPuddle` (`WorldManager.swift:434-438`) — same
function, different `TerrainObjectType` argument, no new query
infrastructure. Sits with tail wrapped, watches the rain start from cover.

Personality's `boldness` axis (shelter-seekers vs. bold ones who trot out
to meet the front) is, like §1's chase-vs-hide variant, **not a shipped
axis** — this feature is written to consume a `boldness`-derived signal
from [personality & emotional state](/REFERENCE/personality-emotional-state.md)
once that concept's deepening defines its formula; until then, ship the
shelter-seeking branch as the universal default (it is the more broadly
"reads as sensing" behavior of the two).

**Stage gating:** Drop hides fully behind an object, peeking (1pt of head
visible). Critter is the shelter-seeker default described above, with an
occasional (personality-independent, rolled) mistimed dash to cover after
progress 0.4 has already passed. Beast trots toward the front and stands in
the first drops instead of sheltering. Sage sits facing it in the open,
unbothered. Apex doesn't move; its aura brightens 20% as the front passes
overhead — another `auraState` consumption request handed to
[body-pose-pipeline.md §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption).

**No sound, no interruption** — strictly a background pantomime; the
sit-under-shelter pose needs the `sit` bodyState (degrades to walk-to-cover
+ stand without it — the walk itself is unaffected).

# 4. Gust Front

A new `windVector` scalar in `[-1, 1]`, derived from `WeatherSystem`'s
current state — **confirmed absent from the codebase**: the only existing
"wind" value is `RainRenderer.windDrift` (`RainRenderer.swift:120`), a
private, rain-renderer-internal `CGFloat` in `[-15, 15]`pt/s used solely to
angle falling raindrop sprites, randomized fresh on every rain activation
(`RainRenderer.swift:168, 238`) — it is not a world-readable signal and this
feature does not reuse it; `windVector` is new, computed signal:

| `WeatherSystem.currentState` | `windVector` behavior |
|---|---|
| Storm | Strong, held near ±1.0 for the state's duration |
| Cloudy | Gusty — random ±0.3 to ±0.6 pulses, 3-8s each, 10-30s gaps between |
| Rain | Moderate steady ±0.4-0.6 |
| Clear | Rare breezes — a ±0.15-0.25 pulse, 3-8s, low probability per check |
| Snow, Fog | Near-zero (±0.0-0.1) — these states don't read as windy today |

**Creature reaction, by channel:**

| Channel | Response | Survives `updateWorld` clobber today? |
|---|---|---|
| Ears | Both rotate flat toward windward over 0.3s | Yes — ear controllers are unaffected by `updateWorld`'s root-transform rewrite |
| Whiskers | Sweep back (streamline) | Yes |
| Tail | Streams downwind | Yes |
| Body lean | `zRotation` 2-4° into the wind | **Yes — the only body-transform channel [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md#the-dropped-wire-code-verified-ground-truth) confirms `updateWorld` never touches**; this is why Gust Front's core reads work *before* the body-pose fix lands, unlike every other feature in this document |
| Walk speed | -30% walking upwind, +20% "comic scoot" downwind | Multiplies into `BlendController`'s existing `walkSpeed` integration — no new speed system |
| Brace squash (strong gust while sitting) | Paws widen 1pt, squash to 0.97 | **No** — needs [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md); degrades to ear/whisker/tail/lean only |

**World-side companions** (owned by [weather.md](/SYSTEMS/weather.md)'s
future deepening, not this concept, but listed for completeness since they
share the one `windVector` signal): `CloudSystem` drift ×3, 2-4 debris
flecks (1×0.5pt Ash/Moss) streaking at 60pt/s, feather-type world objects
tumbling 4-10pt downwind via the shipped flick-physics impulse path.

**Composition rule:** `windVector`-driven ear flattening **biases, never
overrides**, `EmotionalVisualController`'s existing mood-driven ear state
(`Creature/EmotionalVisualController.swift`) — implemented as an additive
offset on the ear controller's target angle, not a competing hard-set, so a
happy creature in a gust still reads as happy-with-flattened-ears rather
than snapping to a generic "windy" expression.

**Stage gating:** Egg rocks 0.05rad per gust. Drop gets scooted 1-2pt
sideways by strong gusts (too light — weightless comedy). Critter runs the
full ear/lean/speed table and chases tumbling debris flecks (an
`AttractionScorer`-eligible autonomous target once debris exists). Beast
leans less, "plants itself" demonstratively (reduced lean angle, same
duration). Sage stays visually unmoved except whiskers/tail streaming.
Apex's beard and multi-tail sway channels stream while its aura holds
perfectly steady (another `auraState` request to §8 of the pose pipeline —
`static`, no oscillation, during a gust).

# 5. Snow Memory

`SnowRenderer`'s existing ground-accumulation bar
(`accumulationNode`, `SnowRenderer.swift:82`, building at `0.05`/minute and
melting at `0.2`/minute — `SnowRenderer.swift:68,71`) accumulates but
records nothing about the creature's passage; this feature makes it
remember.

| Mechanism | Spec | New vs. extension |
|---|---|---|
| Footprints | At `accumulationLevel >= 0.5`, each footfall notches a 1×0.5pt void gap into the accumulation bar's fill path, refilling over 60-120s — a decay array (timestamp + world-X per notch) driving one path rebuild per stamp, extending the existing `accumulationNode` rather than adding a new node | Extension |
| Creature snow-cap | A bone crescent grows 0.3→1pt on the head+back silhouette over 2-3 minutes of continuous snowfall — one new node tracking `bodyNode`'s transform | New node (1) |
| Shake-off | 0.6s whole-body wiggle: `xScale` ±6% at 8Hz, `zRotation` ±0.08rad; cap node vanishes into 8 pooled bone flecks arcing 3-5pt outward | Needs body-pose fix for the `xScale`/`zRotation` wiggle (the root/`bodyNode` clobber problem this whole document inherits from [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)); **fallback**: route the wiggle through the existing breathing `yScale` channel (`CreatureNode.updateBreathing`) as a lower-fidelity stand-in until the real fix ships, per that concept's own compose point |
| First-snow double-take | Full stop; head tracks one falling flake to the ground; front paw lifts and shakes | No fix needed — head + paw channels work today |

**Stage gating:** Drop gets comically snow-capped in 60s (small body, same
0.3→1pt range reads much faster relative to its 10×12pt silhouette); its
shake-off briefly lifts it 1pt (a `positionY` micro-hop — needs the pose
fix, same fallback rule as above). Critter runs standard footprints +
shake. Beast's zoomies (shipped sprint choreography) carve a continuous
1pt-deep trench instead of discrete footprint dots while sprinting through
snow. Sage lets snow accumulate serenely into a snow-cat silhouette before
one unhurried shake. Apex: flakes vaporize with a 0.2-alpha shimmer 2pt
before touching it — it leaves no footprints and grows no cap at all
(power via subtraction, matching [body-pose-pipeline.md §3](/SYSTEMS/body-pose-pipeline.md#3-per-stage-amplitude-scalars)'s
"restrained rather than exaggerated" Apex philosophy).

**Companionship payoff:** a returning human sees footprint trails and a
plowed trench from creature activity while away — this is Snow Memory's
version of the "world remembers you were alive" beat
[Reunion Runway](/SYSTEMS/companionship-rituals.md) covers for the greeting
itself.

# 6. Puddle Days & Dabbing

**Ground truth, verified against shipped code — two distinct puddle
concepts exist, do not conflate them:**

1. **`TerrainObjectType.waterPuddle`** (`TerrainObjectPool.swift:19`) is one
   of the **10** ambient scenery types in the terrain-decoration pool (8×1.5pt
   ellipse, `PushlingPalette.tide` at 0.6 alpha, height 1pt) — placed by the
   normal biome-weighted terrain generation, **not** by weather. This is what
   [`PuddleReflection`](/SYSTEMS/world-complexity-ambient-effects.md#puddle-reflections)
   already reacts to today (mirrored silhouette within 10pt, ripple within
   4pt, 5%-per-10s reflection-gaze cue while lingering within 6pt) — the
   "starved" system the dossier refers to, because a `.waterPuddle` object
   only exists where terrain generation happened to place one, independent
   of whether it has rained.
2. **Rain-triggered ephemeral puddles** (2-3 puddles spawning at terrain low
   points after a rain/storm ends, evaporating over 10-20 minutes) are
   **designed, not built**, and are owned by [weather.md](/SYSTEMS/weather.md)'s
   pending deepening (dossier: "post-rain puddle spawn/evaporation lifecycle
   at terrain low points") — this concept does not author that spawn/decay
   logic, only the creature verbs that consume *either* puddle source once
   the ephemeral kind exists.

The verb set below is puddle-source-agnostic — it fires against the shipped
`PuddleReflection` proximity thresholds regardless of which system placed
the puddle:

| Verb | Trigger | Motion | Duration |
|---|---|---|---|
| Paw-dab | Within `PuddleReflection`'s existing 4pt ripple radius | One forepaw extends 2pt, touches; 2-3 concentric 0.75pt tide ripple rings expand 4pt and fade over 600ms; paw retracts, shakes at 8Hz for 300ms | ~1.2s |
| Splash-hop crossing | Approaching a puddle at walk speed, personality-weighted (playful) | 5pt jump arc over/into the puddle, 0.93 landing squash, 4 pooled tide-droplet flecks (1pt, 0.4s ballistic arcs), two more expanding 0.5→3pt ripple rings, then two 15Hz wet-paw shakes | ~1.5s |
| Tiptoe detour | Approaching, personality-weighted (fastidious) | Path bends 6pt around the puddle; walk bobs increase to 2.5pt; ears fold back | Duration of the detour itself |
| Reflection gaze | The existing 5%-per-10s `PuddleReflection` cue fires | Sits at the edge; paw extends onto the surface once; head-tilt at the wobbling mirror image | ~5s |
| Wet shake | After any dab/splash contact | Full-body `xScale` wobble ±8% at 12Hz for 500ms with 6 pooled droplets | 0.5s |
| Offended flick-and-retreat | Water-averse personality lean (nurture-tracked preference, not a personality axis) | Paw flick, turn, three quick steps, sit facing away | ~2s |

Splash-hop, tiptoe's bob increase, and the wet-shake's `xScale` wobble
depend on [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md)'s
compose-not-clobber fix for the jump arc and torso wobble respectively; the
dab, reflection-gaze, and offended-retreat verbs use only paw/head/ear/tail
channels and work with today's code once `PuddleReflection`'s trigger
callbacks are wired to a reaction table instead of nothing.

**Stage gating:** Drop sits IN the puddle, delighted, ripples radiating on
its existing hop beat (`CreatureNode.swift`'s perpetual Drop hop — no new
timing needed, the ripple just samples the hop's existing phase). Critter
runs full escalation to splash-hops. Beast delivers one deliberate stomp
that empties the puddle (`alpha → 0` on the puddle node — works for either
puddle source). Sage watches its reflection — the existing 30%-alpha
inverted silhouette — for 5s, then dabs once. Apex's puddle mirrors its aura
color (another `auraState`-adjacent visual, owned in rendering terms by
whichever system draws the puddle) and it never touches the surface at all.
Water-loves/hates preference persists via the shipped nurture preference
system, exactly as the dossier's Puddle Dabbing proposal specifies.

# 7. Golden Hour Dusk Vantage

**Scope note:** the dossier's "Golden Hour Rituals" source proposal
describes both a dawn wake-stretch and a dusk vantage sit; the dawn half is
explicitly reassigned to [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md)'s
Stretch Ritual Grammar per the dossier's own concept-assignment note (line
142: *"the dawn half is folded into the tier-2 Stretch Ritual Grammar"*).
This concept owns **only the dusk vantage ritual**.

Once per dusk, keyed to [sky & celestial](/SYSTEMS/sky-celestial.md#sky-gradient--8-time-periods)'s
`Dusk` period (wall-clock start 18:00, per that concept's own gradient
table): the creature walks to the nearest terrain rise within 60pt, sits
facing the brightest column of the horizon gradient, and watches for 20-40
seconds.

**"Nearest terrain rise" query — new, but cheap:** `TerrainGenerator`
exposes only `heightAt(worldX:)` (`TerrainGenerator.swift:100`) — there is
**no existing local-maximum or "rise" query**. The feature is specified to
sample `heightAt` across the ±60pt window at a coarse stride (e.g. every
4pt, 30 samples) and walk to the highest-sampled point — a loop over the
existing height function, not a new `TerrainGenerator` API.

| Beat | Timing | Motion |
|---|---|---|
| Walk to rise | Up to 60pt, at normal walk speed | Existing locomotion — works today |
| Sit | On arrival | `sit` bodyState, tail wrapped — **needs body-pose fix**; degrades to a stand-and-face fallback |
| Head bearing | Held for the ritual's duration | Head rotates to the exact bearing of the gradient's brightest column (a color-sample query into the same gradient texture [sky-celestial.md](/SYSTEMS/sky-celestial.md#sky-gradient--8-time-periods) already renders) |
| Breath stretch | Over the ritual's first ~5s | Breath period eases from the default 2.5s (`CreatureNode.breathPeriodAwake`, `CreatureNode.swift:71`) to 5s via the existing `EmotionalVisualController.breathPeriodOverride` channel (`EmotionalVisualController.swift:194-198`) — no new breath mechanism, an additional override source |
| Slow blinks | Every 8s | Reuses whatever slow-blink primitive [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md) authors for its own resting/contemplative states — cross-linked, not duplicated here |
| Total hold | 20-40s | Ends via the yield rules below, or naturally as dusk transitions out |

**Yield rules (explicit precedence, highest first):** sleep → mini-games →
ceremonies (evolution) → AI-direction (an active Claude session command) →
the designed-but-unbuilt campfire
([`docs/FEATURES/interactivity-unbuilt.md`](/FEATURES/interactivity-unbuilt.md) —
if the campfire has spawned, the ritual targets the campfire instead of the
generic terrain rise, and campfire wins any conflict) → this ritual. Also
suppressed within 10 minutes of an active invitation, per
[invitation-system.md](/SYSTEMS/invitation-system.md)'s shared ambient-event
cooldown pool (once that pool exists — flagged the same way §1/§3 flag their
pending personality-axis dependency).

**Stage gating:** Drop can't sit still — bounces gently in place facing the
sun instead (reuses its perpetual hop, no new timing). Critter runs a
shortened 10s version and abandons it if a bug spawns
([ambient-wildlife.md](/SYSTEMS/ambient-wildlife.md), once built). Beast
runs the full ritual; on full-moon dusks it chains directly into the
shipped Surprise #57 full-moon howl (§1) at the vantage point, silhouetted.
Sage adds a 1pt levitation sliver (`positionY += 1`) during the sit — needs
the pose pipeline's `positionY` compose (§4 of that doc), same dependency
as every other seated pose here. Apex: the gradient's brightest column
subtly re-aligns to wherever it sits — the sun sets where Apex faces (a
request back into [sky-celestial.md](/SYSTEMS/sky-celestial.md)'s gradient
renderer, not implemented by this concept).

**The flagship screenshot:** the void-black silhouette against the
ember-to-dusk gradient lerp, unmodified by anything else in this document —
this ritual's entire value is compositional (existing sky gradient + a
seated silhouette that isn't moving), which is why it is buildable almost
entirely from channels that already exist once `sit` lands.

# Frame Budget & Feasibility Summary

Every reaction above is either (a) a reflex injection via the already-shipped
`SurpriseAnimationPlayer` bridge — zero new behavior-stack infrastructure —
or (b) pooled-particle/single-node cosmetic additions within the existing
frame budget (~5.7ms design allocation, [grounds[1]](#citations)). The two
genuinely new signals this document introduces are `windVector` (§4, one
`Double` derived from `WeatherSystem.currentState`, updated on the same
5-minute check cadence weather already uses) and the weather-transition
lead-time callback (§3, fired once per `beginTransition` call, not
per-frame). No feature here proposes a new node cap, a new particle pool
beyond the existing pooling rule, or a new palette color — puddle droplets,
snow flecks, and debris all draw from the 8-color Display P3 set via
alpha/lerp only.

# What This Concept Does Not Cover

- The weather state machine, particle renderers, or the already-shipped
  rain/lightning/thunder/snow-begin/fog/weather-clear reflexes —
  [weather.md](/SYSTEMS/weather.md).
- The sky gradient, moon phase, star field, or cloud layer mechanics —
  [sky-celestial.md](/SYSTEMS/sky-celestial.md).
- The `VisualEvents` renderers themselves (what a shooting star or aurora
  looks like) — [world-complexity-ambient-effects.md](/SYSTEMS/world-complexity-ambient-effects.md).
- Any torso transform (`sit`, `crouch`, `bounce`, `positionY` hops) —
  every such reaction here is a *consumer* of
  [body-pose-pipeline.md](/SYSTEMS/body-pose-pipeline.md), not a redefinition
  of it.
- `boldness`/fastidiousness/water-preference axis formulas —
  [personality-emotional-state.md](/REFERENCE/personality-emotional-state.md)
  (boldness), the shipped nurture preference system (water-preference).
- The rain→ephemeral-puddle spawn/evaporation lifecycle — pending
  [weather.md](/SYSTEMS/weather.md) deepening.
- The dawn wake-stretch — [idle-life-and-rest.md](/SYSTEMS/idle-life-and-rest.md)'s
  Stretch Ritual Grammar.

# Citations

[1] `Pushling/Sources/Pushling/World/VisualEvents.swift`, `World/VisualEventBuilders.swift` — 7 shipped event types and durations
[2] `Pushling/Sources/Pushling/World/MoonPhase.swift:254` (`isFullMoon`)
[3] `Pushling/Sources/Pushling/Surprise/TimeSurprises.swift` (`fullMoon` `SurpriseDefinition`, `isFullMoon(date:)`)
[4] `Pushling/Sources/Pushling/Surprise/SurpriseAnimationPlayer.swift:1-10,46-54` (short/long surprise → reflex injection rule, `onInjectReflex`)
[5] `Pushling/Sources/Pushling/Behavior/BehaviorStack.swift:336,343` (`triggerReflex`)
[6] `Pushling/Sources/Pushling/Behavior/ReflexLayer.swift:21-24` (`ReflexDefinition`)
[7] `Pushling/Sources/Pushling/Input/PetStreak.swift:15-17` (`giftStreakThreshold`, `streakDays`)
[8] `Pushling/Sources/Pushling/World/WeatherSystem.swift:145,148,265,294,343` (`checkInterval`, `transitionDurationRange`, `selectNextWeather`, `beginTransition`, `updateTransitionRenderers`)
[9] `Pushling/Sources/Pushling/World/RainRenderer.swift:120,168,238` (`windDrift` — private, rain-only, not reused by `windVector`)
[10] `Pushling/Sources/Pushling/World/SnowRenderer.swift:68,71,82` (`accumulationRate`, `meltRate`, `accumulationNode`)
[11] `Pushling/Sources/Pushling/World/TerrainObjectPool.swift:13-53` (`TerrainObjectType`, 10 ambient types, `height`/`width`, `.waterPuddle`)
[12] `Pushling/Sources/Pushling/World/TerrainRecycler.swift:437` (`nearestObjectOfType`)
[13] `Pushling/Sources/Pushling/World/WorldManager.swift:362-373,432-438` (`updateCreatureVisuals`'s `PuddleReflection` wiring, `findNearestPuddle`)
[14] `Pushling/Sources/Pushling/World/TerrainGenerator.swift:100` (`heightAt` — the only height query that exists)
[15] `Pushling/Sources/Pushling/Creature/CreatureNode.swift:71` (`breathPeriodAwake`)
[16] `Pushling/Sources/Pushling/Creature/EmotionalVisualController.swift:194-198` (`breathPeriodOverride`)
[17] `.samantha/scratch/flesh-out-design-2026-07-03.json` `.grounds[0]` (body-movement findings), `.grounds[1]` (hard constraints), `.proposals` (WORLD ALIVENESS & SPECTACLE lens: Sky Theater Reflex, Streak Aurora Nights, Weather on the Horizon, Gust Front, Snow Memory, Puddle Days; Play & Toys lens: Puddle Dabbing)
[18] `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` lines 86-146, 176-177 (feature pitches, concept assignment)
