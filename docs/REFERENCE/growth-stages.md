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

# Per-Stage Motion Signature

The XP/size/unlock table above is stage identity at the coarsest grain;
this section is the **stage-identity rollup** for everything Phase-2's
motion concepts pin to a specific `GrowthStage` — gait, jump apex,
pose-amplitude, blend timing, hunt catch/whiff rates, the Childhood Echo,
and each stage's signature reinterpretation of the shared grammar. **This
table is not the authority for any of these numbers** — each is owned and
derived by its source concept ([body pose & compose
pipeline](/SYSTEMS/body-pose-pipeline.md), [locomotion &
gait](/SYSTEMS/locomotion-and-gait.md), [hunt &
pounce](/SYSTEMS/hunt-and-pounce.md)) and reproduced here only to complete
the stage-identity picture; cross-link into the source concept for the
formula/mechanism behind any single number. Every mechanism below is
**Designed, not built** except where a citation marks it shipped — the
same live-vs-unbuilt discipline as the three source concepts.

| Stage | Gait dialect | Jump/hover apex | Pose scalar (scale/offset) | Blend-duration multiplier | Catch % / Whiff % |
|---|---|---|---|---|---|
| **Egg** | Roll — **DECISION-pending**, see `docs/DECISIONS.md` D-1 | N/A — **DECISION-pending**, see D-1 | 0.3 / 0.3 | N/A (rolls, does not reverse-flip in the walking sense) | N/A (excluded — pre-directed-movement per this doc's canon, contradicted by code per D-1) |
| **Drop** | Hop-scurry (promotion of the already-shipped ambient hop) | 2pt (shares the ambient hop's own ceiling) | 0.5 / 0.6 | ~0× (near-zero, featherweight ramp) | 30% / 70% |
| **Critter** | 4-beat walk, 2-beat trot | Not yet specified — flagged for the Airborne Arc System follow-up; hunt & pounce proposes 3pt pending confirmation | 1.0 / 1.0 | 1.0× (200ms baseline) | 35% / 65% |
| **Beast** | Sprint + skid | 6pt (hard-capped) | 1.15 / 1.10 | 2.0× (400ms) | 75% / 25% |
| **Sage** | Glide-walk | Not yet specified — flagged for the Airborne Arc System follow-up; hunt & pounce proposes a flat 4pt arc pending confirmation | 0.85 / 0.85 | 3.0× (600ms, sine-eased; never skids) | 90% / 10% |
| **Apex** | Drift / teleport-blink | 2pt, reinterpreted as a hover-lift, not a jump | 0.70 / 0.50 | N/A (continuous drift; a hard stop renders as a 10-frame, 20%-alpha afterimage instead of a discrete ramp) | 100% / 0% (the grammar's launch becomes an instant reappearance at the target, no leap) |

**Reading the blend-duration multiplier column:** `BodyPoseController`'s
own internal tuple-to-tuple ease (§1 of the pipeline doc) is a **flat
0.3s for every stage** — that number does not vary by stage and is not
what this column reports. The multiplier above is the [Weight & Momentum
Model](/SYSTEMS/locomotion-and-gait.md#2-weight--momentum-model)'s
per-stage direction-reversal ramp, expressed as a ratio against Critter's
200ms baseline (Beast's 400ms = 2.0×, Sage's 600ms = 3.0×, Drop's
near-zero featherweight ramp ≈ 0×) — the one place stage genuinely changes
how *long* a transition takes, as opposed to what shape it holds.

## Echo Unlocks (the Childhood Echo)

At peak-joy, an evolved creature briefly reverts to a younger stage's
gait before catching itself — [locomotion &
gait](/SYSTEMS/locomotion-and-gait.md#the-childhood-echo)'s full mechanism,
reproduced here as stage-identity content since it is literally about
which stages carry which earlier stage's memory:

| Stage | Echo unlock | Roll chance | Recovery |
|---|---|---|---|
| Critter+ | Egg-wobble | — (fires as a brief in-place callback, not chance-gated) | Immediate |
| Beast+ | Drop-hop (three 2pt hops at Beast's actual 18×20pt size) | 1% per walk bout, gated to peak-joy | Freeze + one sharp ear-flick |
| Sage+ | Kitten-trot (Critter's gait) | 1% per walk bout, gated to peak-joy | Freeze + ear-flick |

Apex carries no echo unlock — the table stops at Sage+; there is no stage
above Apex for it to look back on. Fires at most once per session and is
journal-logged, per the source concept.

## Per-Stage Reinterpretations

The one-new-feature-per-stage rhythm this doc's Key Unlock column already
establishes applies again at the motion layer: each stage past Critter
doesn't just scale the shared grammar, it bends one part of it into
something distinct.

- **Sage — floaty hang-time.** Sage's own jump apex is one of the two
  "not yet specified" gaps above, so the floaty read ships today as
  [locomotion & gait's](/SYSTEMS/locomotion-and-gait.md#per-stage-signature-gaits)
  occasional 1pt levitation-drift (3-6s, aura +15%) rather than a
  dedicated jump-and-hang — the dignified stillness of a hover standing
  in for the height Sage's headroom doesn't have to spare.
- **Apex — hover-not-jump.** Covered by the jump/hover apex column above:
  Apex's 2pt cap is explicitly a hover-lift, never a leap, per [body pose
  & compose pipeline](/SYSTEMS/body-pose-pipeline.md#4-positiony-application--isairborne-terrain-clamp-suspension).
- **Apex — teleport-blink.** Travel beyond 300pt skips the drift entirely:
  a 150ms alpha fade to true OLED void (Apex genuinely disappears — [it
  IS the light source](/SYSTEMS/body-pose-pipeline.md), so a void-faded
  Apex is invisible, not just dim) followed by a 1-frame Gilt shimmer on
  reappearance. Per [locomotion &
  gait](/SYSTEMS/locomotion-and-gait.md#per-stage-signature-gaits); camera
  easing must suspend for the duration or the parallax world lurches.
- **Apex — celebration-as-light.** Not yet separately authored by any
  source concept — this wave's own composition of two already-canonical
  pieces, not a new mechanic: a `celebrate` bodyState still resolves to
  the shared `bounce` tuple everywhere else, but Apex's 0.70/0.50 pose
  scalar (above) damps that oscillation almost flat, so pairing it with
  the already-tabled `sparkle` `auraState` (0.10→0.25 alpha, 0.6s sine,
  Gilt — [pipeline §8](/SYSTEMS/body-pose-pipeline.md#8-aurastate-consumption))
  reads the celebration as a light pulse instead of a physical bounce —
  fitting Apex's "power via subtraction" restraint elsewhere in this
  doc's motion table. Needs no further build beyond what the pipeline
  already specifies; flagged here as a synthesis worth a build-time
  confirmation, not an invented mechanism.
- **Drop — the hop IS the pounce.** No discrete stalk/wiggle/launch at
  this stage; [hunt & pounce](/SYSTEMS/hunt-and-pounce.md#3-per-stage-catch-rates--pounce-profiles)
  reuses the perpetual ambient hop itself as Drop's entire predator
  grammar — it "catches" when the hop happens to land on the target.

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
