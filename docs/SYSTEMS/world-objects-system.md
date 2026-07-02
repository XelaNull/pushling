---
type: System
title: World & Objects System
description: Claude shapes the environment via pushling_world — weather, visual events, time overrides, ambient sound, persistent placed objects with autonomous interaction scoring, wear/repair, a legacy shelf, and companions.
status: Live
tags: [creation, world, objects, companions]
timestamp: 2026-07-02T00:00:00Z
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

# Wear, Repair & the Legacy Shelf

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

# Companions

**5 types** (`CompanionType`, `Pushling/Sources/Pushling/World/CompanionSystem.swift`):
`mouse` (3×2pt), `bird` (3×3pt), `butterfly` (2×2pt), `fish` (3×2pt),
`ghost_cat` (10×12pt at reduced alpha) — sizes and the type list match the
vision doc exactly. **Max 1 companion at a time** — `addCompanion`
replaces any existing companion rather than stacking (no explicit cap
constant; enforced structurally by `WorldManager` holding a single optional
companion reference). `companion` sub-actions are `spawn`/`add`,
`remove`/`despawn`, and `status`.

# Schema

`world_objects` (`Schema.swift:277-303`) — see the interaction-vocabulary
discussion above for the CHECK constraint mismatch. Notable columns:
`layer` (`far|mid|fore`), `size`, `wear` (CHECK 0.0–1.0), `source`
(`system|ai_placed|repo_landmark`), `is_active`/`removed_at` (the legacy
shelf mechanism). `repo_name` and `landmark_type` columns are present but
**deprecated and unused** — repo landmarks are tracked via the separate
`repos` table and an in-memory `LandmarkSystem` array instead (see
[repo landmarks](/REFERENCE/repo-landmarks.md)).

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
[10] `Pushling/Sources/Pushling/State/Schema.swift` (`world_objects` table)
[11] `PUSHLING_VISION.md` — The Objects System; Companions
