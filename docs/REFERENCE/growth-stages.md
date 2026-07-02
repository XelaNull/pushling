---
type: Reference
title: Growth Stages & Evolution
description: The six XP-gated growth stages, their thresholds, sizes, and unlocks, plus the shared stage-transition ceremony.
status: Live
tags: [growth, evolution, xp, stages]
timestamp: 2026-07-02T00:00:00Z
---

Six stages. Each is a dramatic visual and behavioral transformation,
following a cat-spirit arc: from pure light, to eyes in the dark, to a
small creature finding its legs, to a confident animal, to a wise being, to
something transcendent. This concept is prescriptive canon per the human's
2026-07-02 R1 ruling: **code reality is canon.** For how a creature's first
stage-1 traits are actually determined, see
[creature identity & birth](/REFERENCE/creature-identity-birth.md); for how
stage gates speed/behavior availability every frame, see
[the behavior stack](/SYSTEMS/behavior-stack.md).

# Stages & XP Thresholds

| Stage | `GrowthStage` raw value | XP Threshold to Enter | Size (pts, code-verified) | Key Unlock |
|---|---|---|---|---|
| **Egg** | `.egg` = 0 | 0 (starting stage) | 9×11 | Just exists. Silent, no directed movement. |
| **Drop** | `.drop` = 1 | 100 | 10×12 | Eye expressions, sleep, commit reactions, symbol-only speech |
| **Critter** | `.critter` = 2 | 500 | 14×16 | Touch response, mood display, first speech bubbles, first word |
| **Beast** | `.beast` = 3 | 2,000 | 18×20 | Running, digging, schedule awareness, full sentences |
| **Sage** | `.sage` = 4 | 8,000 | 22×24 | Narration, meditation, teaching, memory flashbacks, paragraphs |
| **Apex** | `.apex` = 5 | 20,000 | 25×28 | World-shaping, dreaming, legacy, meta-awareness, full fluency |

Source of the thresholds: `GameCoordinator.stageThresholds`
(`Pushling/Sources/Pushling/App/GameCoordinator+Loading.swift`) — a literal
`[GrowthStage: Int]` map: `.drop: 100, .critter: 500, .beast: 2000,
.sage: 8000, .apex: 20000`. `GrowthStage` itself
(`Pushling/Sources/Pushling/Behavior/LayerTypes.swift`) is a
`Comparable, CaseIterable` `Int` enum with `egg` as raw value `0` — **the
first stage's canonical name is `egg`**, matching `Schema.swift`'s
`validStages = ["egg","drop","critter","beast","sage","apex"]` CHECK
constraint. XP itself is the `creature.xp` SQLite column (not
`total_xp` — see the Critical Knowledge table in
`pushling/CLAUDE.md`) and the commit-feeding XP formula that fills it is
owned by the commit-feeding concept, not this one.

**Size-table correction (cross-concept reconciliation):** the Egg row above
now reads 9×11pt, code-verified against `BodyPartController.swift`'s
`StageConfiguration(.egg, size: CGSize(width: 9, height: 11))` and
`StageRenderer.swift`'s `// MARK: - Egg (9x11)`. `PUSHLING_VISION.md`'s
original 6×6pt figure is superseded — preserved as historical intent only,
same treatment as the commits-eaten model below. This reconciles a drift
[creature visual design](/REFERENCE/creature-visual-design.md) had already
flagged against this file specifically; that concept's own proportions
table used 9×11pt throughout and no longer disagrees with this one.

# Evolution Mechanics

`GameCoordinator.checkEvolution()` runs after every XP award (paired with
`persistXPAndStage()`). It walks the stages in ascending order
(`.drop, .critter, .beast, .sage, .apex`), and for the first stage strictly
above the creature's current stage whose threshold the current `totalXP`
has reached, it evolves — then **`break`s out of the loop immediately**.
This is the literal mechanism behind "evolves one stage at a time": if a
single XP award crosses two thresholds at once (e.g. a huge refactor pushes
XP from 480 straight to 2,100, crossing both the Critter and Beast
thresholds), only the next stage up (Critter) is applied on this call;
reaching Beast requires `checkEvolution()` to run again on a subsequent XP
award and find `totalXP` still ≥ 2,000. On each evolution, in order: the
scene and creature node evolve (`creature.evolve(to:)`), the behavior
stack's stage updates, voice/voice-integration/speech-coordinator are
notified, the world manager's visual complexity updates, XP+stage persist
immediately, and an `evolve`-type journal row is inserted.

`GameCoordinator+Loading.loadStage(from:)` — the function that restores
stage from SQLite on daemon relaunch — falls back to `.critter` (not
`.egg`) if no `stage` row is readable or no name in `GrowthStage.allCases`
matches. This is a launch-time safety default for a corrupted/missing row,
not a design claim that Critter is a "default" stage; new creatures are
always created at `.egg` via the hatching flow.

# Superseded Design History: Commits-Eaten Model

`PUSHLING_VISION.md`'s original Growth Stages table gated evolution on
**commits eaten**, not XP, and named the first stage **Spore**:

| Stage (vision doc, superseded) | Commits Eaten | Adaptive multiplier |
|---|---|---|
| Spore | 0–19 | — |
| Drop | 20–74 | × `activity_factor` |
| Critter | 75–199 | × `activity_factor` |
| Beast | 200–499 | × `activity_factor` |
| Sage | 500–1,199 | × `activity_factor` |
| Apex | 1,200+ | × `activity_factor` |

The doc additionally specified an **adaptive XP curve**: `actual_threshold
= base_threshold × activity_factor`, where `activity_factor =
clamp(median_daily_commits_week1 / 5.0, min: 0.5, max: 3.0)` — calculated
once at the end of the first week and locked, so a hyperactive developer
(20+ commits/day) reaches Apex in roughly a month while a casual developer
(0.5/day) takes years, everyone getting a "multi-month journey."

**This model does not match the running code and is preserved here as
historical design intent only.** `GameCoordinator.checkEvolution()`
compares `totalXP` (not a `commits_eaten` counter) against the fixed
thresholds in the table above — there is no per-developer scaling logic
present at all. The `activity_factor` column *does* exist in the SQLite
`creature` table (`REAL NOT NULL DEFAULT 1.0 CHECK (activity_factor >= 0.5
AND activity_factor <= 3.0)`, per `Schema.swift`) and the `commits_eaten`
column also exists (`INTEGER NOT NULL DEFAULT 0`) — both are present in the
schema, giving the adaptive-curve design a place to live, but neither is
read by `checkEvolution()` or by any other evolution-gating code found
during this wave's search. This is intent-canon preserved per the
migration's aspirational-content rule, not a currently-active mechanism —
if the adaptive per-developer curve is still wanted, it needs to be wired
into `checkEvolution()`, which is a build task, not a documentation fix.

Similarly, the **first-stage naming split** the survey flagged is resolved
by this ruling: the Swift daemon's canonical name is `egg`
(`GrowthStage.egg`, `Schema.validStages`), while the MCP TypeScript layer
(`mcp/src/tools/sense.ts` `STAGE_ORDER = ["spore", "drop", "critter",
"beast", "sage", "apex"]`) still uses `"spore"` as of this wave's
verification. **This is a live cross-process naming mismatch, not just a
documentation artifact** — the daemon persists and evolves the creature
under `"egg"`, but the MCP server's own stage-index table would never match
a `"egg"` string against its `STAGE_INDEX` lookup, defaulting it to index 0
regardless (the same numeric position `"spore"` would have occupied, so the
practical effect may be benign for ordinal comparisons, but the string
itself is wrong wherever it's surfaced to Claude verbatim). Flagged for
`DECISIONS.md`/the Orchestrator as a real MCP-layer bug, not merely a stale
doc — canon is `egg`; `mcp/src/tools/sense.ts` should be corrected to match.

# Stage Transition Ceremony

A shared 5-second ceremony plays on every evolution (distinct from the
30-second one-time [hatching ceremony](/REFERENCE/creature-identity-birth.md)):

1. **Stillness** — all animation stops, ears flatten, the world holds its
   breath.
2. **Gathering** — light particles stream from all edges toward the
   creature; fur begins to glow.
3. **Cocoon** — particles coalesce into a bright orb; the creature curls
   into a ball inside; the ground cracks with golden light.
4. **Burst** — 200+ particles explode outward, full-screen white flash,
   screen shake; a brief silhouette of the new form is visible in the
   flash.
5. **Reveal** — the new form fades in at 1.2× scale, settles to 1.0×; a
   stage-name banner slides in; a first action plays at the new stage
   (e.g. Critter takes its first step, Beast runs a victory lap, Sage sits
   and meditates for 3 seconds).

This choreography is implemented in
`Pushling/Sources/Pushling/Creature/EvolutionCeremony.swift`, invoked from
`GameCoordinator.checkEvolution()` via `creature.evolve(to:)`'s completion
handler, which then calls back into `behaviorStack.updateStage()` and
`scene.onEvolutionCeremonyComplete()` to resume normal operation.

# Citations

[1] `Pushling/Sources/Pushling/App/GameCoordinator+Loading.swift` (`stageThresholds`, `checkEvolution`, `persistXPAndStage`, `loadStage`)
[2] `Pushling/Sources/Pushling/Behavior/LayerTypes.swift` (`GrowthStage` enum)
[3] `Pushling/Sources/Pushling/State/Schema.swift` (`validStages`, `commits_eaten`, `activity_factor`, `xp` columns)
[4] `Pushling/Sources/Pushling/Creature/EvolutionCeremony.swift`
[5] `mcp/src/tools/sense.ts` (`STAGE_ORDER`, `STAGE_INDEX`)
[6] `pushling/CLAUDE.md` (XP column gotcha, one-stage-per-call gotcha)
[7] `PUSHLING_VISION.md` — Growth Stages; Stage Transitions; adaptive XP curve (superseded)
