---
type: System
title: World & Objects System
description: Claude shapes the environment via pushling_world — weather, visual events, time overrides, ambient sound, persistent placed objects with autonomous interaction scoring, wear/repair, a legacy shelf, companions, height metadata, attachment scoring, and the milestone-decal budget.
status: Live
tags: [creation, world, objects, companions, attachment, decals]
timestamp: 2026-07-03T00:00:00Z
---

`pushling_world` is Claude's single tool for sculpting the environment
around the creature — weather, one-shot visual events, sky-time overrides,
ambient sound, and the persistent objects/companions the creature interacts
with autonomously. This concept owns object caps, the preset catalog, the
autonomous attraction-scoring model, wear/repair, and companions. It does
**not** own the wire-level action/param tables (see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md)) or terrain
generation / biomes (see
[biomes and terrain objects](/REFERENCE/biomes-and-terrain-objects.md)).

# Actions

`VALID_ACTIONS` (`mcp/src/tools/world.ts`): `weather`, `event`, `place`,
`create`, `remove`, `modify`, `time_override`, `sound`, `companion` — 9
actions. (The daemon additionally answers a `list` action used internally
for `world_objects` enumeration; it is not part of the MCP-exposed
vocabulary.)

- **`weather`** — one of `rain, snow, storm, clear, sunny, fog`
  (`VALID_WEATHER_TYPES`), optional `duration` 1–60 min. Transitions over
  30–60s daemon-side.
- **`event`** — one-shot visual spectacle: `shooting_star, aurora, bloom,
  eclipse, festival, fireflies, rainbow` (`VALID_EVENT_TYPES`). Requires
  Critter+ stage; the daemon returns `started: false` rather than an error
  if the stage gate isn't met.
- **`place`** — a *non-persistent-catalog* placeable from a separate list:
  `fountain, bench, shrine, garden, campfire, tree, rock, mushroom,
  lantern, bridge` (`VALID_PLACE_OBJECTS`). Counts against the same
  persistent-object cap as `create`.
- **`create`** — places a *named preset* (below).
- **`remove`** — target is `'nearest'`, `'all_placed'`, or a numeric ID.
- **`modify`** — `{changes}` and/or `{repair: true}`; only `repair` is
  currently implemented daemon-side (`WorldHandlers.handleWorldModify`
  rejects anything else with "Other modifications are not yet supported").
- **`time_override`** — one of the 8 `TimePeriod` values, optional
  `duration` 1–30 min; `period: "auto"` clears the override.
- **`sound`** — `chime, purr, meow, wind, rain, crickets, music_box`
  (`VALID_SOUND_TYPES`), with a `play`/`stop` sub-action.
- **`companion`** — `spawn|add`, `remove|despawn`, `status` sub-actions.

# Object Capacity & Placement

- **12 persistent objects max**, **3 active consumables** (consumables do
  not count against the persistent cap) — `MAX_PERSISTENT_OBJECTS` in
  `mcp/src/tools/world-validation.ts` and
  `WorldObjectRenderer.maxPersistentObjects/maxConsumables`
  (`Pushling/Sources/Pushling/World/WorldObjectRenderer.swift:71,74`),
  cross-checked and matching.
- **Minimum 20pt spacing** between objects (`WorldObjectRenderer.minimumSpacing`).
- **Max 40 nodes** contributed by all placed objects combined
  (`WorldObjectRenderer.maxObjectNodes`) — a hard SpriteKit budget line, see
  [performance budgets](/REFERENCE/performance-budgets.md).
- **Max 2 particle emitters** from placed objects active at once (vision
  doc claim; not independently re-verified against a named constant this
  wave — flagged as unverified, not contradicted).
- **Milestone-mark decals have a separate 5-node budget**, entirely
  outside this cap — see [Memory-Decal Budget](#memory-decal-budget-milestone-marks)
  below.

# Preset Catalog — A Live Cross-Process Mismatch

**This is the single most important drift in this concept.** The MCP
server and the Swift daemon each maintain their *own* preset list, and they
do not agree:

**MCP `VALID_PRESETS`** (`mcp/src/tools/world-validation.ts:23-28`, 20
entries — this is the list `pushling_world("create")` validates against
and the contract Claude sees):
`ball, yarn_ball, cozy_bed, cardboard_box, campfire, music_box,
little_mirror, treat, fresh_fish, scratching_post, fountain, bench, shrine,
garden, flower_pot, crystal, lantern, feather, tiny_hat, bell`

**Swift daemon `presets` dict** (`WorldHandlers.swift:240-261`, also 20
entries — this is what actually resolves shape/color/size defaults):
`ball, yarn_ball, campfire, cozy_bed, cardboard_box, scratching_post,
music_box, little_mirror, crystal, flower, treat, fresh_fish, milk_saucer,
fountain, lantern, mushroom, tree, rock, flag, bench`

Only **14 of 20** names appear in both lists. `shrine`, `garden`,
`flower_pot`, `feather`, `tiny_hat`, and `bell` pass MCP validation but have
**no entry in the daemon's preset table** — `handleWorldCreate`'s
`if let defaults = Self.presets[preset]` silently fails for these, so the
object is created anyway but with no resolved shape/color/name defaults
(falling through to a bare default sphere with no name). This is not a
rejected request; it is a request that silently degrades. Conversely
`flower` (Swift-only, MCP calls it `flower_pot`), `milk_saucer`, `mushroom`,
`tree`, `rock`, and `flag` exist as daemon defaults with no MCP-side name to
reach them.

**Adjudication:** per DOCS WIN, this concept documents the MCP
`VALID_PRESETS` list as canon — it is the actual contract Claude interacts
with — and records the Swift-side gap as a **code defect requiring a fix**,
not a doc question: either the daemon's `presets` dict needs the missing 6
entries added, or `VALID_PRESETS` needs to shrink to the 14 that actually
resolve. Flagged for `DECISIONS.md`/the Orchestrator; this is a new drift
signal, not one carried forward from the survey.

# Object Height Metadata — New This Wave

**Designed, not built.** Verified this wave: neither preset source
encodes a height. The MCP `VALID_PRESETS` entries
(`world-validation.ts:23-28`) carry no height/size-z field, and the Swift
`presets` dict (`WorldHandlers.swift:240-261`) resolves only
`base_shape`, `color`, `name`, `size` (a uniform scale factor), and an
optional `glow` flag — no vertical-extent value exists anywhere in either
source. [Terrain footing](/SYSTEMS/locomotion-and-gait.md#4-terrain-footing--hop-overs)'s
hop-vs-detour arbitration is explicitly blocked on this field not
existing; this section originates it, since object presets are this
concept's authority, not locomotion's.

Heights below are derived from each preset's existing `size` scale factor
and its `base_shape`'s implied real-world profile (a `pillar` needs more
vertical extent than a `disc` at the same `size`), kept internally
consistent so locomotion's already-authored per-stage ceilings (Critter
≤3pt hops, Beast ≤5pt hops, Sage/Drop never hop regardless of height)
produce a sensible spread of outcomes without further design work there:

| Preset | Base shape (Swift-resolved) | `size` | Height (pt, NEW) |
|---|---|---|---|
| `treat` | sphere | 0.4 | 0.4 |
| `feather`\* | — (unresolved) | — | 0.5 |
| `fresh_fish` | disc | 0.6 | 0.6 |
| `little_mirror` | disc | 0.6 | 0.8 |
| `tiny_hat`\* | — (unresolved) | — | 0.8 |
| `yarn_ball` | sphere | 0.7 | 0.9 |
| `ball` | sphere | 0.8 | 1.0 |
| `bell`\* | — (unresolved) | — | 1.0 |
| `garden`\* | — (unresolved) | — | 1.2 |
| `flower_pot`\* | — (unresolved) | — | 1.5 |
| `music_box` | box | 0.7 | 1.8 |
| `cozy_bed` | dome | 1.2 | 2.0 (low cushion despite its wide footprint) |
| `lantern` | diamond | 0.6, glow | 2.0 |
| `crystal` | diamond | 0.8, glow | 2.2 |
| `bench` | box | 1.0 | 2.5 |
| `cardboard_box` | box | 1.0 | 3.0 |
| `campfire` | triangle | 1.0, glow | 3.5 |
| `fountain` | dome | 1.0 | 4.0 |
| `shrine`\* | — (unresolved) | — | 6.0 |
| `scratching_post` | pillar | 1.0 | 7.0 |

\* One of the [six MCP-only presets](#preset-catalog--a-live-cross-process-mismatch)
that pass MCP validation but have no Swift-side resolution — these
heights are assigned pending that drift's fix; until the daemon's
`presets` dict gains an entry (or `VALID_PRESETS` shrinks), these objects
silently degrade to a bare default sphere and their height, like their
shape and color, would never actually render.

**Where height stops mattering.** Furniture-category presets (`cozy_bed`,
`scratching_post`, `bench`, `fountain`) carry high [category base
weights](#autonomous-interaction--15-templates-not-14) (0.7–0.9) that
frequently clear the [0.4 investigation
threshold](#hop-vs-investigate-arbitration) before a hop-over is ever
evaluated — height mostly governs Toy and Decorative presets encountered
below the threshold during ordinary path traversal, not the objects the
creature actually wants to visit.

# Autonomous Interaction — 15 Templates, Not 14

`ObjectInteractionEngine.swift` defines the live interaction-template
vocabulary, matching `AttractionScorer.swift`'s scoring-category keys
exactly:

| Category | Templates | Count |
|---|---|---|
| Toy | `batting_toy`, `chasing`, `carrying`, `string_play`, `pushing` | 5 |
| Furniture | `sitting`, `climbing`, `scratching`, `hiding` | 4 |
| Decorative | `examining`, `rubbing` | 2 |
| Interactive | `listening`, `watching`, `reflecting` | 3 |
| Consumable | `eating` | 1 |

That sums to **15**, not the 14 `PUSHLING_VISION.md`'s section header
claims (the doc's own table sums to 15 as well — the header text is simply
wrong). This concept documents 15 as the code-verified count.

**7-factor attraction score** (`AttractionScorer.swift`): `base category
weight × personality affinity × mood modifier × recency decay × novelty
bonus × proximity × time-of-day`. Personality affinity keys off a specific
axis per category (e.g. `chasing` scales with `energy`, `rubbing` with
`verbosity`) with distinct high/low multipliers per axis — see the
`personalityAffinities` table in source for the full per-category mapping.
Recently-placed objects get a novelty bonus per the vision doc's "3x
novelty" claim (not independently re-derived from a named constant this
wave).

**A separate, largely dead vocabulary exists in the schema.** The
`world_objects.interaction` column's CHECK constraint
(`Schema.swift:288-293`) restricts stored values to a *different* 14-name
set: `examining, sitting_on, hiding_behind, pushing, climbing,
sleeping_near, eating, playing_with, collecting, wearing, building_with,
guarding, sharing, worshipping`. Only `examining`, `pushing`, `climbing`,
and `eating` overlap the real 15-template vocabulary above. In practice
every object created via a preset gets `interaction = "examining"` (the
hardcoded default in `WorldManager+Objects.swift` — no preset entry sets an
`interaction` key), so the mismatch rarely surfaces. But `ObjectWearSystem`
keys its `wearRates` dictionary off the *real* template names
(`"batting_toy": 0.03`, ...) — passing a "full definition" object with
`interaction: "batting_toy"` (the vocabulary the doc and the scorer both
use) would **violate the schema's CHECK constraint** and fail the INSERT.
Flagged as a new drift for `DECISIONS.md`: the CHECK constraint appears to
be a leftover from an earlier, abandoned interaction-naming scheme and
should be migrated to the 15-name `ObjectInteractionEngine` vocabulary.

# Hop-vs-Investigate Arbitration

`AutonomousLayer.objectWanderThreshold`
(`AutonomousLayer+ObjectInteraction.swift:21`) is a real, shipped
constant — **0.4** — gating whether the creature's highest-scoring nearby
object is interesting enough to interrupt idle/walk flow for an approach
(`selectObjectInteraction`, same file:57). This is exactly the
"investigation threshold" [locomotion-and-gait.md's Terrain Footing
arbitration rule](/SYSTEMS/locomotion-and-gait.md#4-terrain-footing--hop-overs)
describes in the abstract ("if an object's attraction score is above the
investigation threshold, it wins and converts what would have been a
hop-over into an approach") — this section supplies the concrete number
so that concept can consume the real constant rather than inventing a
parallel one.

**The arbitration, stated plainly:** during a walk bout, for each placed
object a path-scan encounters, `AttractionScorer.scoreObjects` produces a
`totalScore`. If `totalScore >= 0.4`, the object wins outright and the
walk bout redirects into `startObjectInteraction` — an approach,
choreographed per [Autonomous Interaction](#autonomous-interaction--15-templates-not-14)
above — and the [height-metadata](#object-height-metadata--new-this-wave)
hop-vs-detour decision never runs. Below 0.4, the object is beneath
notice for interaction purposes, and height alone decides hop vs. detour.
No new scoring logic is needed here: `objectWanderThreshold` already
exists and already gates exactly this decision for the idle-interaction
path — Terrain Footing's job is to call the same check from its own
walk-bout path-scan, not build a second one.

# Wear, Attachment & the Legacy Shelf

Objects accumulate wear (0.0–1.0) per interaction, at a category-specific
rate (`ObjectWearSystem.wearRates`, e.g. `batting_toy: 0.03/interaction`
wears faster than `sitting: 0.01`). Wear stages are `pristine → worn →
weathered → battered`, each with its own visual treatment. `pushling_world("modify",
{repair: true})` resets wear to 0.0 and applies a "patched" visual mark
(`ObjectWearSystem.repair`). Worn objects remain functional; only visual
treatment and (per the vision doc) enthusiasm of interaction change.

Removing an object never deletes its row — `WorldManager+Objects.swift`
sets `is_active = 0, removed_at = <timestamp>` (a soft delete), matching
the vision doc's "legacy shelf" concept: the row persists in SQLite, no
longer rendered, available for historical reference or dream-sequence
callbacks. The vision doc's additional flourishes (creature sniffing the
empty spot, Sage+ narration, a 2-hour grace period before an object can be
"knocked off the edge") were not found as separate implemented mechanics
this wave — preserved as intent-canon, not contradicted.

## Per-Object Attachment — The Favorite

**Designed, not built.** No `attachment` field exists on `world_objects`
today (verified: [the schema](#schema) has `wear` but nothing analogous)
— [play-bouts.md owns The Favorite's growth curve and
choreography](/SYSTEMS/play-bouts.md#6-the-favorite--toy-attachment--farewell)
and calls for this field to "live beside `wear` in the same per-object
store"; this concept's job is to spec that storage, since it owns the
`world_objects` schema.

**Proposed column:** `attachment REAL NOT NULL DEFAULT 0.0 CHECK
(attachment >= 0.0 AND attachment <= 1.0)`, alongside `wear` in
`world_objects` (`Schema.swift:294-295`).

**Growth/decay formula (this wave's design number — nothing shipped to
verify it against yet):**

| Event | Effect |
|---|---|
| Completed play bout | `attachment += 0.05 × personalityAffinity` — reuses [AttractionScorer's existing per-category personality-affinity multiplier](#autonomous-interaction--15-templates-not-14) verbatim (e.g. `chasing`'s `energy` axis: 2.0 high / 0.5 low) as the growth-rate multiplier, so a well-matched toy for a high-energy creature gains +0.10/bout and a mismatched one +0.025/bout |
| Idle day (no play) | `attachment -= 0.01/day`, doubled to `-0.02/day` at Critter — the concrete number behind [play-bouts.md's stage-gating table](/SYSTEMS/play-bouts.md#6-the-favorite--toy-attachment--farewell) ("Critter = fickle... 2x decay") |
| Sage, once `attachment >= 0.9` | Decay suspended (0.0/day) — the concrete mechanism behind "Sage = keeps a Favorite for life" |
| Object wears to the legacy shelf | `attachment` is retained on the soft-deleted row (not reset) — the farewell beat play-bouts.md specs reads this value to decide whether a departing object earns the 10s/20s sit at all |

**The Favorite** is whichever active object holds the highest
`attachment` value once it clears **0.6** — below that threshold, no
object is distinguished enough to earn the bedtime-carry/defense/farewell
choreography that [play-bouts.md](/SYSTEMS/play-bouts.md#6-the-favorite--toy-attachment--farewell)
owns in full; this concept does not re-specify that choreography.

# Companions

**5 types** (`CompanionType`, `Pushling/Sources/Pushling/World/CompanionSystem.swift`):
`mouse` (3×2pt), `bird` (3×3pt), `butterfly` (2×2pt), `fish` (3×2pt),
`ghost_cat` (10×12pt at reduced alpha) — sizes and the type list match the
vision doc exactly. **Max 1 companion at a time** — `addCompanion`
replaces any existing companion rather than stacking (no explicit cap
constant; enforced structurally by `WorldManager` holding a single optional
companion reference). `companion` sub-actions are `spawn`/`add`,
`remove`/`despawn`, and `status`.

**Per-type behavior vocabulary (code-verified, previously undocumented).**
`docs/archive/plan/phase-4-embodiment/PHASE-4.md` P4-T2-05 describes this
only as "simple autonomous AI (3-4 behaviors): wander, react to creature,
flee from touch" — the shipped `CompanionType.behaviors` vocabulary is
considerably richer than that summary and supersedes it as canon:

| Type | Behaviors (duration range) |
|---|---|
| Mouse | `scurry` 2–4s (horizontal dash, bounces off scene bounds), `hideObject` 3–6s (motionless at ground level), `peekOut` 1–2s (rises 1pt), `freeze` 2–5s (motionless) |
| Bird | `flyOverhead` 3–6s (y=22pt + 3pt sine bob, wraps scene bounds), `landObject` 4–8s (y=12pt perched + 0.3pt sine bob), `hop` 1–2s (rises 3pt + drifts, then lands), `preen` 3–5s (stationary) |
| Butterfly | `randomDrift` 4–8s (10pt-amplitude sine drift in x, ±5pt in y), `landFlower` 3–6s (y=ground+4pt), `landCreature` 2–4s (snaps to creature position, y=creature+8pt), `flutter` 2–3s (±2pt sine bob) |
| Fish | `swim` 3–6s (horizontal patrol at ground level, bounces off bounds), `splash` 1–2s (±2pt sine oscillation), `jump` 1–2s (6pt sine arc) |
| Ghost Cat | `mirrorWalk` 5–10s (tracks the creature at a ±60pt offset, speed 15pt/s), `independentWalk` 5–10s (patrols at speed 12pt/s, bounces off bounds), `glance` 1–2s (faces the creature), `wave` 1.5–2s (animation-only, no position change) |
| Shared | `idle` 3–8s (motionless; the fallback when a type's pool is empty) |

**Behavior selection** (`CompanionSystem.selectNextBehavior`): on duration
expiry, the next behavior is a weighted random pick from the type's pool —
*except* when the companion is within 30pt of the creature, which forces a
type-specific reactive behavior: mouse `freeze`/`scurry` (50/50), bird
`flyOverhead`, butterfly `landCreature`, fish `splash`, ghost cat `glance`.
This is the shipped form of PHASE-4's "react to creature." No touch-based
fleeing exists in `CompanionSystem.swift` (no touch input is read anywhere
in the file) — PHASE-4's "flee from touch" clause remains unbuilt design
intent, not a mismatch to be corrected.

# Memory-Decal Budget (Milestone Marks)

**Designed, not built; the number originated in a sibling concept, adopted
here as this concept's authority over `WorldObjectRenderer`'s node
budgets.** [Companionship rituals' Milestone
Pilgrimage](/SYSTEMS/companionship-rituals.md#6-milestone-pilgrimage--revisiting-the-places-where-life-happened)
specs a permanent, low-alpha terrain decal stamped at evolution, first
word, mastered trick, and 7-day-streak milestones, and explicitly flags
that this concept "does not yet carry a decal section" and should adopt
its number rather than re-deriving one. This section is that adoption.

**The cap is structurally separate from [the 40-node interactive
cap](#object-capacity--placement).** `WorldObjectRenderer.maxObjectNodes`
(`WorldObjectRenderer.swift:80`, guarded at line 153) scopes only the 12
persistent + 3 consumable *interactive* objects the `objects: [String:
RenderedObject]` dictionary tracks (`WorldObjectRenderer.swift:89`) —
milestone marks are passive terrain decoration, not interactive objects,
and must not compete with that budget for the same 40-node ceiling. Per
companionship-rituals.md's number:

| Property | Value |
|---|---|
| Max concurrent decals | **5** (own ceiling, independent of the 40-node cap) |
| Nodes per decal | 1 (a flat low-alpha shape — scorch-bloom or star-etch per [companionship-rituals.md's mark table](/SYSTEMS/companionship-rituals.md#6-milestone-pilgrimage--revisiting-the-places-where-life-happened)) |
| Eviction policy | Oldest-evicted-first once a 6th milestone would stamp a mark |
| Storage | Not yet built — `milestones` (`Schema.swift:349-358`) has no world-position column; would need a new `position_x REAL` column recording where each milestone was earned |

**Proposed enforcement shape** (this concept's mandate, per
companionship-rituals.md's "both should be enforced by the same
renderer"): a `decals: [String: RenderedDecal]` dictionary sibling to
`WorldObjectRenderer.objects`, with its own `maxDecalNodes = 5` constant —
structurally parallel to, but never summed with, `maxObjectNodes`. No
code exists yet for either the dictionary or the constant (grep-verified
against `WorldObjectRenderer.swift` this wave).

# Schema

`world_objects` (`Schema.swift:277-303`) — see the interaction-vocabulary
discussion above for the CHECK constraint mismatch. Notable columns:
`layer` (`far|mid|fore`), `size`, `wear` (CHECK 0.0–1.0), `source`
(`system|ai_placed|repo_landmark`), `is_active`/`removed_at` (the legacy
shelf mechanism). `repo_name` and `landmark_type` columns are present but
**deprecated and unused** — repo landmarks are tracked via the separate
`repos` table and an in-memory `LandmarkSystem` array instead (see
[repo landmarks](/REFERENCE/repo-landmarks.md)).

**Two columns are proposed but not yet built** (this wave's deepening):
`world_objects.attachment` beside `wear` (see [Per-Object
Attachment](#per-object-attachment--the-favorite) above), and
`milestones.position_x` on the unrelated `milestones` table (see [Memory-Decal
Budget](#memory-decal-budget-milestone-marks) above) — neither exists in
`Schema.swift` today.

# What This Concept Does Not Cover

- **Terrain-footing choreography** (the hop-over arc, detour sidestep, and
  stumble beats that consume [object height](#object-height-metadata--new-this-wave)
  and the [investigation-threshold arbitration](#hop-vs-investigate-arbitration))
  — owned by [locomotion & gait](/SYSTEMS/locomotion-and-gait.md#4-terrain-footing--hop-overs).
  This concept owns the object-side data (height, attraction scoring); that
  concept owns the render mechanism.
- **The Favorite's growth-curve mechanics beyond storage, choreography, and
  journal payoff** (bedtime carry, sleep-curl drape, grooming, defense,
  farewell) — owned by [play-bouts.md](/SYSTEMS/play-bouts.md#6-the-favorite--toy-attachment--farewell).
  This concept owns only the `attachment` column and its growth/decay
  numbers.
- **Milestone Pilgrimage's trigger, choreography, and the Sage+
  reminiscence wiring** it feeds — owned by [companionship
  rituals](/SYSTEMS/companionship-rituals.md#6-milestone-pilgrimage--revisiting-the-places-where-life-happened).
  This concept owns only the decal node budget and its structural
  separation from the interactive-object cap.

# Examples

```json
// Preset creation
{"action": "create", "params": {"preset": "campfire"}}

// Full definition (subject to the interaction-vocabulary caveat above)
{"action": "create", "params": {
  "base_shape": "sphere", "size": 1.2, "interaction": "batting_toy"
}}

// Companion
{"action": "companion", "params": {"action": "spawn", "type": "mouse", "name": "Whiskers"}}
```

# Citations

[1] `mcp/src/tools/world.ts` (`VALID_ACTIONS`, response builder)
[2] `mcp/src/tools/world-validation.ts` (`VALID_PRESETS`, `VALID_WEATHER_TYPES`, `VALID_EVENT_TYPES`, `MAX_PERSISTENT_OBJECTS`, `VALID_COMPANION_TYPES`)
[3] `Pushling/Sources/Pushling/IPC/WorldHandlers.swift` (`presets` dict, `handleWorldCreate`, `handleWorldCompanion`, `handleWorldModify`)
[4] `Pushling/Sources/Pushling/World/WorldObjectRenderer.swift` (caps, spacing, node budget)
[5] `Pushling/Sources/Pushling/World/AttractionScorer.swift` (7-factor scoring, category weights, personality affinities)
[6] `Pushling/Sources/Pushling/World/ObjectInteractionEngine.swift` (15 interaction templates)
[7] `Pushling/Sources/Pushling/World/ObjectWearSystem.swift` (wear stages, repair)
[8] `Pushling/Sources/Pushling/World/WorldManager+Objects.swift` (legacy shelf soft-delete, `interaction` default)
[9] `Pushling/Sources/Pushling/World/CompanionSystem.swift` (`CompanionType`)
[10] `Pushling/Sources/Pushling/State/Schema.swift` (`world_objects`, `milestones` tables)
[11] `PUSHLING_VISION.md` — The Objects System; Companions
[12] `Pushling/Sources/Pushling/Behavior/AutonomousLayer+ObjectInteraction.swift` (`objectWanderThreshold`, `selectObjectInteraction`)
[13] `docs/SYSTEMS/locomotion-and-gait.md` — Terrain Footing & Hop-Overs (height-metadata dependency, per-stage hop ceilings)
[14] `docs/SYSTEMS/play-bouts.md` — The Favorite (attachment growth-curve spec, storage request)
[15] `docs/SYSTEMS/companionship-rituals.md` — Milestone Pilgrimage (decal budget number, eviction policy)
