---
type: Reference
title: SP6b Traceability — World Detail + Research + Hardware
description: Source-to-concept mapping for Wave SP6b (WO-1 OKF migration) — proves zero fidelity loss across the eight SP6b concepts.
status: Current
tags: [okf-migration, traceability, wave-sp6b]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP6b authored eight concepts:
[palette](/REFERENCE/palette.md),
[oled-rendering-techniques](/REFERENCE/oled-rendering-techniques.md),
[biomes-and-terrain-objects](/REFERENCE/biomes-and-terrain-objects.md),
[repo-landmarks](/REFERENCE/repo-landmarks.md),
[touch-bar-hardware](/REFERENCE/touch-bar-hardware.md),
[touch-bar-private-api](/REFERENCE/touch-bar-private-api.md),
[3d-rendering-feasibility](/RESEARCH/3d-rendering-feasibility.md), and
[touch-bar-prior-art](/RESEARCH/touch-bar-prior-art.md).

"Deferred" below means the source section is real content belonging in the
final bundle but out of this wave's assigned scope — not a fidelity loss,
routed to the wave that owns that subject. Deferred sections were read for
context only; nothing from them was lifted as truth into an SP6b concept.

# PUSHLING_VISION.md (assigned: Visual System — palette, world composition's terrain/skyline; hardware-adjacent facts)

| Source section | → Target concept#section | Status |
|---|---|---|
| Visual System: 8-Color P3 Palette | `palette.md` (full concept) | migrated, corrected — Moss blue channel corrected from doc's `#00E860` to code-verified `#00E858` (see Adjudications) |
| Visual System: World Composition — Terrain (biomes, object counts) | `biomes-and-terrain-objects.md` | migrated, corrected — biome transition width corrected from doc's "50-unit" to code's 150pt (see Adjudications) |
| Visual System: World Composition — Repo skyline | `repo-landmarks.md` | migrated, expanded with the full `RepoAnalyzer` detection heuristics (not itemized in the vision doc, which only names the landmark-growth concept) |
| Visual System: World Composition — Sky, Weather, Clouds, Diet-influenced tinting | *(not this wave)* | deferred — owned by SP6a (rendering + creature visual) and/or a future `world-terrain-parallax.md` system concept; this wave only owns terrain objects and landmarks |
| Visual System: Art Direction "Luminous Pixel Life", Visual Earned Complexity, The "Wow Factor" Moments, HUD Philosophy | *(not this wave)* | deferred — owned by SP6a (creature/world rendering presentation) |
| Architecture: Rendering Target (engine, scene size, frame rate, display, touch, audio table) | *(already migrated)* | previously migrated by SP2a into `system-architecture.md#rendering-target` — not re-authored here; this wave's `touch-bar-hardware.md` cross-links to it rather than duplicating |
| Technical Performance (frame budget table) | *(not this wave)* | deferred — owned by whichever wave authors the Performance Budgets reference concept per the survey's proposed-concepts list; not assigned to SP6b |
| All other sections (Philosophy, Identity/Birth, Growth Stages, Personality, Gameplay, Speech Evolution, Behavior Stack, MCP Integration, Hooks, Creation Systems, Surprises, Journal, Installation, P Button, Release Celebrations, Roadmap) | *(not this wave)* | deferred — owned by SP2a/SP2b/SP3a/SP3b/SP4/SP5/SP6a/SP7 per the bundle plan; not read in depth by this wave beyond the assigned Visual System subsections |

# docs/archive/3D-RENDERING-RESEARCH.md (assigned: the Research Note split only — §1-13, §15)

| Source section | → Target concept#section | Status |
|---|---|---|
| §1 Executive Summary (technical findings, excluding the Claude/Samantha narrative framing) | `3d-rendering-feasibility.md` intro | migrated |
| §1 Claude/Samantha dialogue framing ("pours a deep oolong...", "adjusts her tiny DOOM keychain earring...") | *(none)* | dropped-with-justification — narrative/roleplay flavor text characterizing the research session, not technical knowledge; the substantive conclusion it wraps is preserved in prose |
| §2 The Constraint: 36:1 Aspect Ratio | `3d-rendering-feasibility.md#the-constraint-361-aspect-ratio` | migrated |
| §3-10 Options 1-8 (SceneKit, Metal, RealityKit, Software 3D, Isometric, Voxel Engine, Sprite Stacking, Mode 7) | `3d-rendering-feasibility.md` (per-option headings) | migrated |
| §11 The Doom Precedent | `3d-rendering-feasibility.md#the-doom-precedent-what-it-actually-proves` | migrated |
| §12 The Aspect Ratio Problem | `3d-rendering-feasibility.md#the-aspect-ratio-problem-why-3d-fails-at-361` | migrated |
| §13 Comparison Matrix | `3d-rendering-feasibility.md#comparison-matrix` | migrated |
| §14 Recommended Approach: Enhanced 2.5D (stack table, Clouds System, Cat Visual Enhancement, Implementation Priority) | *(not this wave)* | deferred — owned by SP6a per the survey's split (`System: Enhanced 2.5D Rendering Stack`, `Reference: Cat Visual Design`); this wave's Research Note adds a brief **Outcome** section noting what actually shipped (sprite-stack technique, no Mode 7, SDF glow status) with cross-links to SP6a's expected concepts, without claiming authority over that content |
| §15 Sources | `3d-rendering-feasibility.md` Citations (full 43-source bibliography reproduced individually, not summarized) | migrated |
| Compiled/date footer | `3d-rendering-feasibility.md` frontmatter + intro line | migrated |

# docs/archive/TOUCHBAR-TECHNIQUES.md (assigned: §2, §3.3 (reconciled), §3.4-3.6, §6.2-6.3 (corrected), §10.3-10.5, §10.8, §11, Sources)

| Source section | → Target concept#section | Status |
|---|---|---|
| §2 Hardware Specifications | `touch-bar-hardware.md#schema` | migrated |
| §10.3 Sensor Input | `touch-bar-hardware.md#sensor-availability` | migrated, annotated — none of the three sensors (ambient light, accelerometer, camera) are wired in the current codebase; documented as designed-but-unbuilt, not stale, per the aspirational-features rule |
| §10.4 OLED Tricks | `oled-rendering-techniques.md#true-black-and-stealth-effects` | migrated, reconciled — cross-linked into the palette/OLED-technique concept rather than duplicated, per this wave's explicit reconciliation instruction |
| §1 line 36 ("We currently render emoji at 2 FPS via shell scripts in MTMR") and §3.1 (MTMR "Our Current Stack") | *(none — superseded runtime)* | dropped-with-justification — describes the retired MTMR/bash prototype as current; the native Swift daemon superseded it. Preserved only as a single historical footnote in `touch-bar-prior-art.md`'s rendering-taxonomy row 6, not migrated as an architecture claim |
| §3.2 BetterTouchTool | *(none)* | dropped-with-justification — a commercial-tool evaluation with no bearing on Pushling's shipped native architecture; not prescriptive canon and not prior-art catalog material either |
| §3.3 Native NSTouchBar API (Key Insight, Private APIs, "Nuclear Option" sketch) | `touch-bar-private-api.md` (full concept) | migrated, corrected — the "Nuclear Option" sketch's `/tmp/` file-based IPC replaced with the actual shipped Unix-socket + SQLite architecture (already canon via `system-architecture.md`, cross-linked not repeated); private API resolution mechanism corrected to distinguish `dlsym`-resolved C functions from Objective-C-runtime-resolved methods |
| §3.4 Hammerspoon, §3.5 Electron, §3.6 Software Comparison Matrix | `touch-bar-prior-art.md#software-ecosystem-comparisons` | migrated |
| §4-5 Rendering Techniques (braille, block elements, box drawing, symbols, emoji width control, fonts, color, image-based rendering), Animation & Motion (frame-by-frame, scrolling/parallax, position movement, transitions, particles, camera systems, character budget) | *(none — targets a runtime that no longer exists)* | dropped-with-justification — text/shell-rendering techniques (braille pixel art, ANSI/Unicode block elements, character-budget math) apply only to the retired MTMR/bash tier; the native SpriteKit daemon uses none of them. Per the survey's disposition, this bulk is archived with the source file, not converted to canon |
| §6.1 MTMR Touch Events, §6.4 BTT Continuous Swipe, §6.5 Haptic Feedback, §6.6 Keyboard Integration | *(none — same runtime as above)* | dropped-with-justification — MTMR/BTT-specific input mechanisms not applicable to the native daemon's gesture-recognizer-based input (see `touch-bar-private-api.md#touch-delivery-the-corrected-caveat` for the actual mechanism) |
| §6.2 Input Latency by Tool | `touch-bar-private-api.md` (context only, not a table migration) | dropped-with-justification — a cross-tool latency comparison (MTMR vs. BTT vs. native) that was useful for choosing an architecture, not a fact about the chosen one; the native row's "10-15ms" figure is unverifiable against current code and not asserted as canon |
| §6.3 Positional Touch (Native Only) | `touch-bar-private-api.md#touch-delivery-the-corrected-caveat` | migrated, corrected — the claimed sub-pixel ~60Hz `touchesMoved` positional tracking does not hold for Pushling's `SKView` (crashes on `NSTouch.normalizedPosition`); replaced with the verified gesture-recognizer-on-plain-NSView-only mechanism, and the unwired `wireGestureRecognizers`/`touchOverlay` dead code flagged as a new finding |
| §7 Game Design Patterns (genre matrix, hub architecture, universal render pattern) | *(none — bash/MTMR-era game design)* | dropped-with-justification — evaluates game genres for a text-rendering runtime; Pushling's actual gameplay design lives in `PUSHLING_VISION.md`'s Gameplay section, owned by other waves |
| §8 World Building & Terrain (procedural terrain via character palettes, viewport model, day/night via `date +%H`, weather via character sets, cave interiors, seasons, living world elements, pipeline cost) | *(none — bash/MTMR-era world rendering)* | dropped-with-justification — describes character-based terrain rendering superseded entirely by the native `BiomeManager`/`TerrainObjectPool` system this wave documents in `biomes-and-terrain-objects.md`; none of the shell-era techniques carry forward |
| §9 Performance Engineering (refresh rate sweet spot, performance budget, subshell tax, optimization opportunities, shell execution speed, alternative language comparison, daemon architecture, adaptive refresh) | *(none — bash/MTMR-era performance)* | dropped-with-justification — bash startup costs, subshell tax, and MTMR refresh-interval tuning are irrelevant to a compiled Swift daemon; the daemon's actual frame budget is documented elsewhere (Technical Performance, deferred per the PUSHLING_VISION.md row above) |
| §10.1 Sound Effects, §10.2 Desktop Integration, §10.6 Activity-Driven Narrative, §10.7 Git Lore/Archaeology | *(none — not this wave's subject)* | dropped-with-justification — sound/notification implementation detail and narrative-flavor features belong to feeding/journal concepts (SP7/SP3b), not world-detail or hardware research |
| §10.5 Multi-Touch-Bar Multiplayer | `touch-bar-prior-art.md#multi-touch-bar-multiplayer-zero-prior-art` | migrated |
| §10.8 Doom Was Here | `touch-bar-prior-art.md#doom-was-here` | migrated |
| §11 Existing Projects Catalog (all subsections) | `touch-bar-prior-art.md#existing-projects-catalog` | migrated |
| §12 Recommended Architecture & Roadmap (Phases 0-4, decision framework) | *(none — superseded roadmap)* | dropped-with-justification — prescribes MTMR/bash phased work against files that do not exist in the repo; the roadmap was bypassed for the native path (survey driftSignal). Phase 4's "prototype Swift daemon with SpriteKit" line is the one item that came true, and it's simply superseded by the fact that this bundle documents the daemon that resulted |
| Sources & References | `touch-bar-prior-art.md` Citations (full bibliography reproduced individually) | migrated |

# docs/archive/VECTOR-GRAPHICS-RESEARCH.md (assigned: Sec 9 only, reconciled with TOUCHBAR-TECHNIQUES' OLED subject)

| Source section | → Target concept#section | Status |
|---|---|---|
| Sec 9 OLED Rendering Techniques (Texture Caching, OLED-Specific Techniques table, Stroke Width, Anti-Aliasing, P3 Gamut) | `oled-rendering-techniques.md` (full concept) | migrated, annotated per-technique build status — Texture Caching and the ambient-presence/edge-softener/particle-ambient rows of the OLED-Specific Techniques table verified as **not yet built** (no per-body-part `texture(from:)` caching, no `ambientPresence`/`edgeSoftener` code found); the SDF Glow row corrected from "Future" to **shipped** (shape-based approximation in `CreatureNode+Effects.swift`) |
| Sec 1-2 (Bugs Found, Dead Code to Wire Up) | *(not this wave)* | deferred — owned by SP6a/SP3a (creature rendering); this is an audit of `StageRenderer.swift`/`ShapeFactory.swift`, not a world-detail or OLED-technique subject |
| Sec 3-8 (Design Philosophy, Proportions & Shape Language, Stage-by-Stage Recommendations, Feature Introduction Timeline, Animation Architecture, Procedural Animation Formulas) | *(not this wave)* | deferred — owned by SP6a per the survey's split into `Creature Visual Design Canon` and `Procedural Animation Formulas & Architecture`; not part of this wave's assignment |
| Sec 10-11 (Codebase Grades, Implementation Priority) | *(not this wave)* | deferred — point-in-time audit/priority-tier snapshot the survey explicitly flags as overtaken by commits within days; not canon material for any wave, archived with the source per the survey's disposition |
| Sec 12 Sources (OLED & SpriteKit Rendering references only) | `oled-rendering-techniques.md` Citations (context reference to the source doc; individual OLED-relevant URLs not separately itemized since Sec 12's OLED-specific citations were not distinguishable from the broader design-research bibliography without re-splitting Sec 12 itself, which is SP6a's document to own) | dropped-with-justification — Sec 12 is one shared bibliography backing all of Sec 3-11, not a per-section citation list; splitting out only the OLED-relevant entries would require editorial judgment calls about a bibliography this wave doesn't fully own (most of Sec 12 backs SP6a's sections). Flagged for SP6a/SP8 to reconcile if a citations gap is found later |

# Citations

[1] `PUSHLING_VISION.md`
[2] `docs/archive/3D-RENDERING-RESEARCH.md`
[3] `docs/archive/TOUCHBAR-TECHNIQUES.md`
[4] `docs/archive/VECTOR-GRAPHICS-RESEARCH.md`
