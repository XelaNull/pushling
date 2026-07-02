---
type: Reference
title: SP6a Traceability — Rendering + Creature Visual
description: Source-to-concept mapping for Wave SP6a (WO-1 OKF migration) — proves zero fidelity loss across the eight rendering/creature-visual concepts.
status: Current
tags: [okf-migration, traceability, wave-sp6a]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP6a authored eight concepts:
[rendering-stack-2-5d](/SYSTEMS/rendering-stack-2-5d.md),
[world-terrain-parallax](/SYSTEMS/world-terrain-parallax.md),
[sky-celestial](/SYSTEMS/sky-celestial.md),
[weather](/SYSTEMS/weather.md),
[world-complexity-ambient-effects](/SYSTEMS/world-complexity-ambient-effects.md),
[visual-system-art-direction](/REFERENCE/visual-system-art-direction.md),
[creature-visual-design](/REFERENCE/creature-visual-design.md), and
[procedural-animation](/REFERENCE/procedural-animation.md).

This wave ran concurrently with six sibling waves (SP2b-SP7), all of which
had completed by the time this traceability was authored. Several of this
wave's intended cross-links were verified to resolve against already-landed
concepts from those waves (`/REFERENCE/palette.md`,
`/REFERENCE/oled-rendering-techniques.md`,
`/REFERENCE/biomes-and-terrain-objects.md`, `/REFERENCE/repo-landmarks.md`,
`/REFERENCE/growth-stages.md`, `/REFERENCE/creature-identity-birth.md`,
`/SYSTEMS/camera-and-parallax.md`, `/SYSTEMS/behavior-stack.md`,
`/SYSTEMS/world-objects-system.md`, `/RESEARCH/3d-rendering-feasibility.md`)
— where an authority split emerged with one of those waves mid-authoring,
this wave trimmed its own content to a cross-link rather than duplicating,
noted inline below.

"Deferred" below means the source section is real content belonging in the
final bundle but out of this wave's assigned scope. All deferred sections
were read for context only.

# `PUSHLING_VISION.md` (assigned: Visual System section + adjacent world/HUD content)

| Source section | → Target concept#section | Status |
|---|---|---|
| Visual System: Art Direction "Luminous Pixel Life" | `visual-system-art-direction.md` intro | migrated |
| Visual System: 8-Color P3 Palette | *(not this wave)* | deferred — owned by SP6b's `palette.md`, which landed first; this wave's concepts reference colors by name and cross-link there rather than restating the table |
| Visual System: World Composition (Sky, Weather, Clouds, Diet-influenced tinting, Terrain, Repo skyline) | `sky-celestial.md` (Sky, Moon, Star Field, Clouds), `weather.md` (Weather), `world-complexity-ambient-effects.md` (Diet-Influenced World Tinting), `world-terrain-parallax.md` (Terrain mechanics — catalog deferred to SP6b's `biomes-and-terrain-objects.md`), `repo-landmarks.md` (not this wave — SP6b) | migrated across 4 concepts, split per subject-authority |
| Visual System: Visual Earned Complexity | `world-complexity-ambient-effects.md` (Complexity Levels — full mechanics), `visual-system-art-direction.md` (brief principle + cross-link) | migrated, split mechanics/philosophy |
| Visual System: The "Wow Factor" Moments (12 items) | `visual-system-art-direction.md#the-wow-factor-moments` | migrated — each of the 12 moments cross-linked to its actual owning concept (several outside this wave: touch response, evolution ceremony, first word, commit predator crouch, slow-blink) rather than re-described |
| Visual System: HUD Philosophy | `world-complexity-ambient-effects.md#the-cinematic-hud` (mechanics), `visual-system-art-direction.md#hud-philosophy` (principle) | migrated, split mechanics/philosophy |
| The Pushling: Visual Form — Cat-Esque Spirit Creature (composite-node approach, cat behaviors list, breathing) | `creature-visual-design.md` (composite-node construction), `procedural-animation.md` (breathing formula) | migrated — the cat-behaviors list itself (slow-blink, kneading, headbutt, etc. as *named behaviors*) is deferred to the behavior-stack/personality concepts (not this wave); this wave owns only the *rendering* of the body parts those behaviors move |
| The World: Exploring the Touch Bar (3-layer parallax table, repo landmarks) | `world-terrain-parallax.md` (corrected to 4 layers), `repo-landmarks.md` (not this wave) | migrated, corrected — see driftSignal reconciliation below |
| Growth Stages table (sizes) | *(not this wave)* | deferred to SP6b/SP3a's `growth-stages.md`; this wave's `creature-visual-design.md` uses the code-verified sizes and flags a size-table discrepancy for the Orchestrator (see Adjudications in this wave's return) rather than editing that file directly |
| Stage Transitions (5-second ceremony) | *(not this wave)* | deferred — owned by `growth-stages.md` (already landed, confirmed to cover this) |
| Technical Performance (frame budget table) | `rendering-stack-2-5d.md#frame-budget` (brief reference only — full budget table ownership undetermined, flagged) | partially migrated — this wave's Frame Budget section references the ~5.7ms/16.6ms/120-node figures already established project-wide (per `pushling/CLAUDE.md`) without re-authoring a full Performance Budgets reference concept, since no such concept was found to exist yet across any wave's traceability at authoring time |

# `docs/archive/3D-RENDERING-RESEARCH.md` (assigned: §14 only — §1-13, §15 owned by SP6b)

| Source section | → Target concept#section | Status |
|---|---|---|
| §14 "The Enhanced 2.5D Stack" table, "Clouds System", "Cat Visual Enhancement", "Implementation Priority", "What This Achieves" | `rendering-stack-2-5d.md` (stack table → Shipped Stack section; Clouds → deferred to `sky-celestial.md` since clouds are a sky-layer subject, not a creature-rendering one), `sky-celestial.md#clouds`, `creature-visual-design.md` (Cat Visual Enhancement's per-part/per-stage tables) | migrated, reconciled against shipped code — SpriteStackRenderer's shadow/highlight-duplicate technique documented as materially different from this section's 10-18 texture-slice proposal |
| §14 "What We Explicitly Reject" | *(not duplicated)* | dropped-with-justification — identical content to §1-13's rejected-options analysis, already fully owned by SP6b's `3d-rendering-feasibility.md#what-was-explicitly-rejected`; this wave's `rendering-stack-2-5d.md` cross-links there instead of restating |
| §1-13, §15 (executive summary, aspect-ratio constraint, all 8 option analyses, Doom precedent, comparison matrix, sources) | *(not this wave)* | deferred — owned by SP6b's `3d-rendering-feasibility.md`, which landed during this wave's authoring; this wave's `rendering-stack-2-5d.md` was trimmed to cross-link there rather than duplicate the now-existing Research Note |

# `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` (assigned: design half only — Sec 3, 4, 6, 7, 8, plus Sec 12 citations; audit half Sec 1/2/5/10/11 explicitly excluded)

| Source section | → Target concept#section | Status |
|---|---|---|
| Sec 3 Design Philosophy (Solid Fill Test, One New Feature Per Stage, Shape Language Arc, the Ori Principle, Animation Over Detail) | `visual-system-art-direction.md` (Luminous Pixel Life, Solid Fill Test, One New Feature Per Stage, Shape Language Arc) | migrated |
| Sec 4 Proportions & Shape Language (5 cat identifiers, ear-ratio calibration, current-proportions table, chibi-proportion guide, vector-advantage note) | `creature-visual-design.md` (The 5 Cat Identifiers) | migrated — the "Current Proportions (Validated as Good)" table's exact head%/ear%/eye-radius numbers were superseded by the code-verified per-stage table built directly from `StageRenderer.swift`/`CatShapes.swift`, which is more precise than the doc's rounded percentages |
| Sec 6 Feature Introduction Timeline | `creature-visual-design.md#feature-introduction-timeline` | migrated, corrected — added a note that Sage+'s "orbiting particles → dissolution + orbit" progression at Apex has no matching dissolution-particle-pool implementation found in code (preserved as unbuilt design intent) |
| Sec 5 Stage-by-Stage Recommendations | `creature-visual-design.md` (Per-Stage Body Construction table) | migrated as verification input — cross-checked every "Recommended" cell against shipped `StageRenderer.swift`; used to confirm e.g. Critter's whisker/mouth removal and Sage's half-lidded default eyes are now live, not merely recommended |
| Sec 7 Animation Architecture (skeleton upgrade phases, performance cost, what-NOT-to-do) | `procedural-animation.md` (What NOT To Do; the phased skeleton plan itself — hip/chest spine bones, two-bone IK legs — found unbuilt, mentioned nowhere since no partial implementation exists to reconcile against) | migrated (what-not-to-do), dropped-with-justification (spine-chain/IK phases — zero code trace found; re-authoring an entirely-unbuilt multi-phase plan as a Reference concept risked minting speculative canon beyond what any other wave's search surfaced; flagged here rather than silently included) |
| Sec 8 Procedural Animation Formulas (critical/under-damped spring formulas, halflife guide, spring presets, NoiseIdleSystem, follow-through, emotion-to-movement mapping, squash-stretch, asymmetric breathing) | `procedural-animation.md` (Breathing, Noise Idle System, the Design-Era Spring-Damper Toolkit) | migrated, extensively reconciled — asymmetric breathing and the noise-idle six-target system are shipped near-verbatim; the spring-damper formulas are preserved as reference math but the reconciliation explicitly documents that only the tail (force-based, not halflife-based) and camera (halflife-based, not spring-based) ship anything in this family, while ears/whiskers use plain `SKAction` easing; follow-through, emotion-to-movement mapping, and velocity-driven squash-stretch are flagged unbuilt |
| Sec 9 OLED Rendering Techniques | *(not this wave)* | deferred — owned by SP6b's `oled-rendering-techniques.md`, per that wave's task description explicitly listing "oled-rendering-techniques" as its concept; not duplicated here despite being nominally part of the "design half" this wave's sources list named |
| Sec 12 Sources (relevant citations) | Distributed across this wave's 8 concepts' Citations sections | migrated — no single concept reproduces the full Sec 12 bibliography; each citation was routed to whichever concept actually used the claim it backs |
| Sec 1 Bugs Found, Sec 2 Dead Code to Wire Up | *(not canon — backlog only)* | **BUG-4** (`tongue_blep` registered at `.drop` minimum stage while Drop has no mouth, `BehaviorSelector.swift:230-232`) verified still live and reported as a backlog item in this wave's return message per dispatch instruction — NOT minted as canon in any concept. BUG-1/2/3 confirmed fixed in code (stage-param passthrough, egg coreGlow, head-color-from-bodyColor) and not migrated as "bugs" since they no longer exist; the Dead Code table's items (nose, fur texture, toe pads) confirmed wired and folded into `creature-visual-design.md`'s per-stage table as ordinary shipped features, not flagged as former dead code |
| Sec 10 Codebase Grades, Sec 11 Implementation Priority | *(not canon)* | dropped-with-justification — the survey explicitly flags these as a point-in-time snapshot overtaken by commits within days of the document's date; not authored as canon by any wave |

# `docs/archive/plan/phase-3-world/PHASE-3.md` (assigned: entire file)

| Source section | → Target concept#section | Status |
|---|---|---|
| Architectural Context (3-layer parallax claim, integer-noise terrain, 5-biome/50pt-transition claim, weather-every-5-min, performance envelope) | `world-terrain-parallax.md` (Parallax Layers — corrected to 4; Terrain Generation), `world-complexity-ambient-effects.md`, `weather.md` | migrated, corrected — 3-layer and 50pt-transition claims superseded per driftSignal, both explicitly reconciled in-concept |
| P3-T1-01 3-Layer Parallax System | `world-terrain-parallax.md#parallax-layers` | migrated, corrected to 4 layers (far/deep/mid/fore) |
| P3-T1-02 Procedural Terrain Generation | `world-terrain-parallax.md#terrain-generation` | migrated |
| P3-T1-03 5-Biome System | *(not this wave)* | deferred — biome catalog owned by SP6b's `biomes-and-terrain-objects.md`; `world-terrain-parallax.md` retains only the transition-width mechanism (corrected 150pt) and cross-links for the catalog |
| P3-T1-04 Terrain Objects — Placement & Pool, P3-T1-05 Biome-Specific Object Pools | *(not this wave)* | deferred — object catalog and per-biome pools owned by SP6b's `biomes-and-terrain-objects.md`; `world-terrain-parallax.md` retains only the placement mechanism (noise stream, spacing, density threshold) |
| P3-T1-06 Terrain Tile Recycling | `world-terrain-parallax.md#tile-recycling` | migrated |
| P3-T1-07 Repo Landmark System, P3-T1-08 Landmark Generation from Repo Analysis | *(not this wave)* | deferred — owned by SP6b's `repo-landmarks.md` |
| P3-T1-09 Diet-Influenced World Tinting | `world-complexity-ambient-effects.md#diet-influenced-world-tinting` | migrated |
| P3-T2-01 Real-Time Sky Gradient | `sky-celestial.md#sky-gradient--8-time-periods` | migrated |
| P3-T2-02 Moon with Lunar Phase | `sky-celestial.md#moon` | migrated |
| P3-T2-03 Star Field | `sky-celestial.md#star-field` | migrated |
| P3-T2-04 Weather State Machine | `weather.md#the-state-machine` | migrated, corrected — fixed 30s crossfade corrected to randomized 30-60s |
| P3-T2-05 Rain Particles, P3-T2-06 Snow Particles, P3-T2-07 Storm System, P3-T2-08 Fog System | `weather.md` (Rain, Snow, Storm, Fog subsections) | migrated |
| P3-T2-09 Creature Weather Reactions | `weather.md#creature-reactions` | migrated |
| P3-T3-01 8-Color P3 Palette Implementation | *(not this wave)* | deferred — owned by SP6b's `palette.md` |
| P3-T3-02 OLED True-Black Optimization | *(not this wave)* | deferred — owned by SP6b's `oled-rendering-techniques.md` |
| P3-T3-03 Visual Earned Complexity | `world-complexity-ambient-effects.md#complexity-levels` | migrated |
| P3-T3-04 Puddle Reflections | `world-complexity-ambient-effects.md#puddle-reflections` | migrated |
| P3-T3-05 Ghost Echo | `world-complexity-ambient-effects.md#ghost-echo` | migrated |
| P3-T3-06 HUD System | `world-complexity-ambient-effects.md#the-cinematic-hud` | migrated |
| P3-T3-07 Near-Evolution Progress Bar | `world-complexity-ambient-effects.md#evolution-progress-bar` | migrated |
| P3-T3-08 Hunger Desaturation | `world-complexity-ambient-effects.md#hunger-desaturation` | migrated |
| P3-T3-09 Visual Event Spectacles | `world-complexity-ambient-effects.md#visual-event-spectacles` | migrated — tool-trigger contract cross-linked to SP3b's `world-objects-system.md` rather than duplicated |
| P3-T3-10 Repos Table Schema | *(not this wave)* | deferred — owned by SP6b's `repo-landmarks.md` or a state-schema concept (not verified which; not this wave's authority either way) |
| P3-T3-11 Ruin Inscriptions | `world-complexity-ambient-effects.md#ruin-inscriptions` | migrated |
| Integration Points, QA Gate | *(not migrated as a section)* | dropped-with-justification — the Integration Points table describes Phase 4/6/7/8 cross-references from the original multi-phase build plan, all of which are now historical scaffolding superseded by the shipped, already-integrated system; the QA Gate checklist's items are individually satisfied and verified throughout this wave's concepts rather than reproduced as a standalone checklist artifact |

# `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` (assigned: entire file)

| Source section | → Target concept#section | Status |
|---|---|---|
| The Problems (Problem 1: Flat Geometry, Problem 2: No Depth) | *(not migrated as canon)* | dropped-with-justification — describes a pre-implementation state ("a campfire is a triangle colored orange," "mountains are a single 2D gray polygon") that no longer exists in any form; both problems are fully resolved in shipped code (composite shape factories, 4-layer depth terrain) and are historical motivation, not current or intended state |
| Design Principles (8 numbered) | `visual-system-art-direction.md#silhouette-first-design-principles` | migrated |
| Phase 0 Depth System (0A Multi-Layer Mountains, 0B Creature Depth Movement, 0C Object Depth, 0D Atmospheric Perspective, 0E Dynamic Z-Ordering) | `world-terrain-parallax.md#depth--atmospheric-perspective--reconciled-history` | migrated, extensively reconciled — Z-axis convention found inverted from the plan (code: 0.0=near, plan: 0.0=far), an internal clamp inconsistency between `PhysicsLayer` (0.0-0.8) and `ActionHandlers` (0.0-1.0) flagged rather than resolved (outside this wave's authority to change code), object-layer routing confirmed shipped, `atmosphericColor` signature confirmed shipped with a different (depth-based, not layer-enum) signature than proposed, MCP-level depth control (`pushling_move(depth:)`) confirmed never shipped and flagged as defined-but-unwired rather than documented as a live tool capability |
| Phase 1 World Objects (20 composite object redesigns: campfire, ball, tree, flower, mushroom, cozy bed, scratching post, cardboard box, fresh fish, milk saucer, treat, crystal, lantern, music box, mirror, fountain, rock, flag, bench) | *(not this wave)* | deferred — object-shape/composite-factory design is world-object-catalog territory, owned by SP6b's `biomes-and-terrain-objects.md` or SP3b's `world-objects-system.md` depending on whether the object is terrain-ambient or Claude-placeable; not re-verified against `CompositeShapeFactory.swift` by this wave since it falls outside this wave's assigned code-check list |
| Phase 2 Creature Improvements (2a Spore/Drop proto-cat hints, 2b Apex multi-tail, 2c Critter whisker stubs, all-stages animated decorative elements) | `creature-visual-design.md` (Per-Stage Body Construction, Feature Introduction Timeline) | migrated, with one **doc-vs-doc conflict adjudicated**: this section's Phase 2c recommends adding whisker stubs at Critter, directly contradicting `VECTOR-GRAPHICS-RESEARCH.md`'s (later, 2026-03-23) recommendation to *remove* whiskers from Critter and reserve them for Beast's debut. Shipped code (`StageRenderer.swift:227-228`, explicit comment "No mouth or whiskers at Critter stage — they debut at Beast") sides with VECTOR-GRAPHICS-RESEARCH. Adjudicated: the later document plus code is canon; this section's Phase 2c is superseded design history, not migrated as a contradiction to reconcile in code. Apex multi-tail (2b) confirmed shipped exactly as described (repo-count-driven, capped at 9) |
| Phase 3 Landmarks (9 silhouette + color-accent improvements) | *(not this wave)* | deferred — owned by SP6b's `repo-landmarks.md` |
| Phase 4 Weather & Atmosphere Polish (teardrop rain, variable snow-flake sizes, firefly afterimage trail) | `weather.md` (Rain, Snow subsections), `world-complexity-ambient-effects.md#visual-event-spectacles` (fireflies) | migrated as confirmation — all three items verified fully shipped (teardrop droplet texture, 3-size-class snowflakes, firefly trail child node), none remain open work |
| Phase 5 Texture Atlas Swap | `rendering-stack-2-5d.md#deferred--not-pursued` | migrated as a one-line deferred-intent note — no art pipeline exists, not scheduled |
| Implementation Order table, Key Files to Modify, Success Criteria | *(not migrated as standalone sections)* | dropped-with-justification — the Implementation Order/Key-Files tables are project-management scaffolding for a now-largely-complete plan, superseded by the shipped state each relevant concept documents; Success Criteria migrated into `visual-system-art-direction.md` instead (see Design Principles row above) |

# `docs/archive/TOUCHBAR-TECHNIQUES.md` (assigned per this wave's dispatch; largely pre-empted by SP6b)

| Source section | → Target concept#section | Status |
|---|---|---|
| §2 Hardware Specifications, §3.3 Native NSTouchBar API, §3.4-3.6 Software Ecosystem, §6.2-6.3 Input Latency/Positional Touch, §10.3-10.5 Sensor Input/OLED Tricks/Multiplayer, §10.8 Doom Was Here, §11 Existing Projects Catalog, Sources | *(not this wave)* | deferred — SP6b's traceability confirms full migration of these sections into `touch-bar-hardware.md`, `touch-bar-private-api.md`, and `touch-bar-prior-art.md`, landed before this wave's authoring completed; not duplicated |
| §1 Executive Summary (capability tiers, top-10 discoveries), §4 Rendering Techniques (braille pixel art, Unicode block elements, box drawing, emoji width control — Tier 1/2 bash-and-MTMR-era techniques), §5 Animation & Motion (bash frame-by-frame, string-slice parallax), §7 Game Design Patterns (genre feasibility matrix, hub architecture), §8 World Building & Terrain (bash sine-wave/integer-Perlin terrain, ASCII biome palettes, `date +%H` day/night), §9 Performance Engineering, §12 Recommended Architecture & Roadmap | *(not canon — superseded runtime)* | dropped-with-justification — every one of these sections describes techniques for the retired MTMR/bash-shell-script tamagotchi prototype (`items.json`, `tamagotchi.sh`, `evolve.sh`) that predates and was fully replaced by the native Swift/SpriteKit daemon this entire concept bundle documents. None of these bash-era rendering/performance/terrain techniques have any bearing on the shipped system; SP6b's `touch-bar-prior-art.md` already preserves a single historical footnote (rendering-taxonomy row 6) acknowledging the MTMR predecessor existed, which is sufficient context without re-authoring an obsolete implementation's technique catalog as if it were live guidance |

# Citations reconciliation note

Several citations in this wave's 8 concepts point to source documents already
fully migrated by sibling waves (`docs/archive/3D-RENDERING-RESEARCH.md`,
`docs/archive/TOUCHBAR-TECHNIQUES.md`). Those citations remain in this wave's
concepts only where the specific claim being cited is genuinely this wave's
authority (e.g. §14's stack table, §9's sprite-stacking technique) — never
as a substitute for cross-linking to the sibling concept that now owns the
broader source document.
