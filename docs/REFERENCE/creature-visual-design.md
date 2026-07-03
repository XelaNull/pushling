---
type: Reference
title: Creature Visual Design
description: The cat's Bezier-path body-part geometry across all six growth stages — proportions, the five cat-identity identifiers, the feature-introduction timeline, personality-driven scaling, and the Diamond Indicator's visual states for Claude's presence.
status: Live
tags: [creature, visual-design, spritekit, reference]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **the creature's actual body-part shapes** — what
geometry each stage builds, in what proportion, and why. It does not own the
art-direction philosophy these shapes satisfy (see
[visual system & art direction](/REFERENCE/visual-system-art-direction.md)),
the spring/noise formulas animating these shapes (see
[procedural animation](/REFERENCE/procedural-animation.md)), the volumetric
silhouette-stacking or glow layered on top (see
[the Enhanced 2.5D rendering stack](/SYSTEMS/rendering-stack-2-5d.md)), the
XP thresholds/sizes gating which stage is active (see
[growth stages](/REFERENCE/growth-stages.md)), palette color values (see
[the 8-color palette](/REFERENCE/palette.md)), or which emotion-driven state
each body-part controller is told to display frame-to-frame (see
[personality & emotional state](/REFERENCE/personality-emotional-state.md#emotional-visual-feedback-axis--body-language)
for the full axis→body-part table). Source: `Creature/CatShapes.swift`,
`Creature/ShapeFactory.swift`, `Creature/StageRenderer.swift`,
`Creature/BodyPartController.swift`, `Scene/DiamondIndicator.swift`.

# The 5 Cat Identifiers (Priority Order)

Design research ranked which visual features most strongly signal "cat" at
small scale, in priority order: (1) **pointed triangular ears** — the single
most important feature; (2) **curved tail** (S-curve/question-mark
posture); (3) **spine S-curve** (a flexible, arched back); (4) **compact
rounded body** with shoulder/haunch definition; (5) **round head with cheek
taper** to a small chin. Every stage-specific body below is built to
preserve as many of these as its stage allows — Egg preserves none (it is
deliberately pre-cat), Drop hints at (1) and (2) via proto-features, Critter
onward carries all five.

**Ear-height calibration**: ears must stay within **33-45%** of head
diameter to read as "cat" — above 50% reads as "fox," above 60% as "rabbit."
Pushling's shipped range (48-70% across stages, ear-to-head ratio increasing
with stage) is *above* that guideline, which the design research judged
correct anyway for a stylized spirit-cat where ears are the primary visual
anchor on a 30pt display; ear outer edges are always convex (a concave curve
reads as bat/demon).

# Per-Stage Body Construction

`StageRenderer.build(stage:repoCount:visualTraits:)` dispatches to one
`build<Stage>` function per stage, each returning a `StageNodes` struct
(body, coreGlow, head, ears, eyes, mouth, whiskers, tail, four paws, aura,
particles — any part not applicable to that stage is `nil`, not an empty
placeholder). All body-part factories live in `ShapeFactory.swift`, which
converts `CatShapes`' pure `CGPath` Bezier geometry into positioned
`SKShapeNode`s. Sizes below are the code-verified `StageConfiguration.size`
values — see the note at the end of this section on a discrepancy with
`PUSHLING_VISION.md`'s numbers.

| Stage | Size (pt) | Body shape | Ears | Eyes | Tail | Distinguishing build detail |
|---|---|---|---|---|---|---|
| **Egg** | 9×11 | Smooth ellipse, no cat features | None | Invisible (alpha 0) | None | A `core_glow` inner ellipse (40% of body size, alpha 0.3) — the "life growing inside." Stroke is Ash at 0.15 alpha, not off-palette gray. |
| **Drop** | 10×12 | Teardrop (`CatShapes.teardropBody`) | Proto-ear nubs (small circles, alpha 0.3) | 1.0pt radius, round | Proto-tail hint (3pt curve, alpha 0.2) | The first stage with real eyes; proto-features are structural hints, not yet functional body parts (no `EarController`/`TailController` wired at this stage per `StageConfiguration`). |
| **Critter** | 14×16 | `CatShapes.catBody` at `.critter` proportions (rotund belly: `shoulderBump 0.05, bellyDrop 0.12, haunchWidth 0.95`) | Small triangular, first real `EarController` | 1.2pt, 85% roundness (near-circular) | 5pt, `curveFactor 0.5` (stubby) | **No whiskers, no mouth** — deliberately withheld: "Critter is a kitten: eyes + ears only," reserving whiskers/mouth as the *Beast* debut feature per the one-new-feature-per-stage rhythm. |
| **Beast** | 18×20 | `.beast` proportions (`shoulderBump 0.18` — the most pronounced shoulder of any stage, `haunchWidth 0.9`) | Larger, first inner-ear-detail visible | 1.5pt, 65% roundness (true almond) | 8pt, `curveFactor 0.7` (full S-curve) | **Whiskers, mouth, and nose all debut here together** as the "maturity" feature bundle, plus the first aura (Bone, 0.08 alpha) and a fur-texture overlay (density 0.2) |
| **Sage** | 22×24 | `.sage` proportions — deliberately *slimmer* than Beast (`shoulderBump 0.08, haunchWidth 0.85`) — power expressed via subtraction, not addition | Taller, more tapered | 1.5pt, 60% roundness | 10pt, `curveFactor 0.8` | Third-eye mark (Dusk, alpha-pulsing 0.15↔0.35 over 2s), 4 orbiting "wisdom dot" particles (Dusk, 0.4 alpha, radius 0.6× body width, rotating), half-lidded default eye state (see below), vertical-oval Gilt aura |
| **Apex** | 25×28 | `.apex` proportions (`shoulderBump 0.06, haunchWidth 0.88`) — ethereal, flowing | Tallest, most tapered | 1.8pt, 55% roundness | 12pt primary + up to 8 additional fanned tails | Body alpha oscillates 0.76-1.0 (semi-ethereal "flickering between realms"); 5 diamond-shaped (not circular) crown stars, individually staggered alpha pulse; wise beard (3 gilt strands from the chin); Bone aura at full body-width radius |

**Multi-tail count is repo-count-driven at Apex**: `buildApex(repoCount:)`
fans `min(9, max(1, repoCount)) − 1` additional tails from the same
attachment point at 15° (0.26 rad) intervals, each independently
length-jittered (±1pt) and alpha-fading with fan position (0.85 primary,
0.7 for the first extra, descending) — a creature that has fed from nine
tracked repos displays nine tails, kitsune-style.

**Reconciled (was flagged, now resolved):** `growth-stages.md`'s size table
originally listed Egg at 6×6pt (per `PUSHLING_VISION.md`); it has since been
corrected to the same code-verified **9×11pt** this concept uses throughout
(`StageConfiguration.all[.egg].size`, matching
`docs/archive/VECTOR-GRAPHICS-RESEARCH.md`'s own proportions table). No live
cross-concept discrepancy remains — `PUSHLING_VISION.md`'s original 6×6pt is
preserved in `growth-stages.md` as superseded design history only.

# Feature Introduction Timeline

| Feature | Egg | Drop | Critter | Beast | Sage | Apex |
|---|---|---|---|---|---|---|
| Eyes | hidden | large, round | very large | almond + slit pupil | half-lidded default | almond + glow |
| Ears | none | proto-bumps | small triangles | taller, sharper | tall, tapered | tall, tapered |
| Tail | none | proto-nub | short stub | full S-curve | long, tapered | multi-tail fan |
| Whiskers | none | none | **none** (deliberately withheld) | **NEW** | 3/side, longer | 3/side, longer |
| Mouth | none | none | **none** | **NEW** | present | present |
| Nose | none | none | none | **NEW** | present | present |
| Core glow | pulsing | none | faint chest glow | none (aura instead) | none | none |
| Aura | none | none | none | **NEW** — warm Bone | Gilt vertical oval | Bone, full radius |
| Third eye | none | none | none | none | **NEW** | crown of 5 stars |
| Orbiting particles | none | none | none | none | **NEW** — 4 wisdom dots | crown + potential dissolution (design intent; no dissolution-particle pool found in shipped code — preserved as future work) |
| Wise beard | none | none | none | none | none | **NEW** — 3 gilt strands |

# Eye Construction

Every eye is a compound node, not a single shape (`ShapeFactory.makeEye`):
an almond-shaped outer (`CatShapes.catEye`, roundness varying 55%-100% by
stage — Egg/Drop are fully round, Apex is the sharpest almond at 55%), an
iris ring at 85% of eye radius (Tide), a vertical-slit pupil
(`CatShapes.catPupil`, designed to dilate via `xScale`), a primary catch-
light (12% radius, positioned at the "10 o'clock" corner) and a smaller
secondary catch-light at 50% alpha in the opposite corner — five layered
shapes per eye, ten total for the pair. **Sage+ defaults to a half-lidded
eye state** (`CreatureNode.applyDefaultStates`: `currentStage >= .sage ?
"half" : "open"`) rather than the fully-open default every earlier stage
uses — "the Sage has seen everything," per the design intent.

# Personality-Driven Visual Scaling — Current State

`VisualTraits.bodyProportion` (derived from the personality `focus` axis at
hatching, see [creature identity & birth](/REFERENCE/creature-identity-birth.md))
does drive live body scaling: `StageRenderer.build` maps it to
`wScaled = w × (0.9 + propScale × 0.2)` and
`hScaled = h × (1.05 − propScale × 0.1)` — a lean creature (low focus) is
narrower and taller, a round one (high focus) wider and shorter, applied on
top of every stage's base dimensions.

**Personality-driven *color* is not currently live**, despite
`VisualTraits.baseColorHue` existing and being used elsewhere (the [hatching
ceremony](/REFERENCE/creature-identity-birth.md)'s egg-glow color). Every
`build<Stage>` call in `StageRenderer` receives `bodyColor:
PushlingPalette.bone` unconditionally — the source comment reads "Body
color: use PushlingPalette.bone directly — guaranteed visible. The warm
cream always renders clearly on OLED dark backgrounds" (commit `3664bec`, a
debug-visibility revert). `PUSHLING_VISION.md`'s "diet-influenced fur hue"
and personality-color-expression tables describe a design that is real for
the pre-hatch egg glow but currently disabled for the post-hatch body — this
is intent-canon, not stale documentation to prune, since the disabling
commit's own message frames it as a temporary visibility fix rather than a
permanent design reversal.

# The Diamond Indicator

Claude's presence marker — a ~4pt diamond floating near the creature,
updated entirely per-frame (no `SKAction`s driving its core state machine,
for precise interruptibility). `DiamondIndicator` (`Scene/DiamondIndicator.swift`)
exposes named transitions that the session-lifecycle system (owned
elsewhere) calls to reflect Claude's connection state:

| Transition | Visual result |
|---|---|
| `materialize()` | Scale-up from 0.01 with an ease-out overshoot in the final 30% (a "juicy" pop), fading in over 1.0s |
| `setIdle()` / `setThinking()` | Gentle vertical float (±0.5pt, 3.0s period) continues in both; thinking additionally pulses alpha at a 2.0s period and brightens the glow slightly |
| `setActive()` | A quick 0.4s sparkle: color shifts Tide→Bone and back while scaling up to 1.3× and back, before settling into `thinking` |
| `dissolveClean()` | 8 small diamond particles scatter outward and fade over **5.0 seconds** — the "graceful disconnect" path |
| `dissolveAbrupt()` | A rapid 1.0s, 6-count alpha flicker, then the same particle-scatter dissolve compressed to **2.0 seconds** — the "connection dropped" path |
| `splitInto(count:)` | Up to 5 sub-diamonds (2pt each) spread outward along a 6pt-radius arc over 0.5s, each independently alpha-pulsing — represents parallel subagent work |
| `reconverge()` | Sub-diamonds collapse back to center over 0.6s, then the main diamond flashes Gilt at 1.5× scale before returning to `active` — the one point in the whole state machine where the diamond is not Tide |
| `forceHide()` | Immediate reset — clears all particles/sub-diamonds and returns to `hidden` with no animation, an escape hatch for abnormal termination |

The diamond and its glow are always Tide except for the one-frame Gilt flash
on reconvergence; the glow node trails the main diamond at 2× scale and a
low, breathing-like alpha (0.12 ± 0.05, modulated independently in idle vs.
thinking states).

## Three Designed-But-Unbuilt Distinction Cues

`PUSHLING_VISION.md`'s "When AI Acts, Human Sees It" table (lines 1009–1023)
specifies three further per-action visual cues beyond the diamond state
machine above, none of which a repo-wide grep found any trace of
(`diamondIcon`/`bubbleCorner`, `wandSparkle`, `sparkleTrail` and close
variants all return zero hits under `Pushling/Sources/`):

- **A tiny diamond icon in the corner of Claude-spoken speech bubbles** —
  distinguishing AI speech from autonomous speech at a glance, beyond the
  already-shipped 0.3s-vs-0.8s expression-transition speed difference (see
  [the behavior stack](/SYSTEMS/behavior-stack.md#the-blend-controller)).
- **A wand-sparkle effect at the point of a Claude-driven world change** —
  a momentary visual marker distinct from the change itself.
- **A sparkle trail on complex Claude-performed animations** — visually
  distinguishing a choreographed `pushling_perform` from ordinary movement.

This closes out the migration's prior "deferred to SP6a" placeholder for
this table: the diamond's own materialize/dissolve/split/reconverge state
machine above is fully shipped and covers most of the vision doc's table,
but these three finer-grained per-action cues are confirmed unbuilt design
intent, not merely undocumented — preserved here rather than silently
dropped, since this concept is the Diamond Indicator's owning authority.

# Citations

[1] `Pushling/Sources/Pushling/Creature/CatShapes.swift`
[2] `Pushling/Sources/Pushling/Creature/ShapeFactory.swift`
[3] `Pushling/Sources/Pushling/Creature/StageRenderer.swift`
[4] `Pushling/Sources/Pushling/Creature/BodyPartController.swift` (`StageConfiguration`)
[5] `Pushling/Sources/Pushling/Creature/PersonalitySystem.swift` (`VisualTraits`)
[6] `Pushling/Sources/Pushling/Scene/DiamondIndicator.swift`
[7] `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §3-6 (Design Philosophy, Proportions, Stage-by-Stage Recommendations, Feature Introduction Timeline)
[8] `docs/archive/3D-RENDERING-RESEARCH.md` §14 "Cat Visual Enhancement" — target-state part table, cross-verified against `CatShapes.swift`
[9] `PUSHLING_VISION.md` — "When AI Acts, Human Sees It" (lines 1009–1023)
