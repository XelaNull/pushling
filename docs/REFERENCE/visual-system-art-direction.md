---
type: Reference
title: Visual System & Art Direction
description: The "Luminous Pixel Life" art direction — silhouette-first design principles, the Solid Fill Test, the one-new-feature-per-stage evolution rhythm, and the shape-language arc — plus the catalogued Wow Factor moments and the philosophy behind the cinematic no-UI HUD.
status: Live
tags: [art-direction, design-philosophy, silhouette, reference]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **the design philosophy behind everything Pushling
renders** — the principles a new visual feature must satisfy before it ships,
not the mechanics of any one system. It does not own the P3 palette or
OLED-specific rendering practices (see
[the 8-color palette](/REFERENCE/palette.md) and
[OLED rendering techniques](/REFERENCE/oled-rendering-techniques.md)), the
stage-by-stage cat design these principles produce (see
[creature visual design](/REFERENCE/creature-visual-design.md)), the
complexity-gating mechanics or HUD implementation (see
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)),
or the rendering-technique stack itself (see
[the Enhanced 2.5D rendering stack](/SYSTEMS/rendering-stack-2-5d.md)).

# Luminous Pixel Life

The art direction, named in `PUSHLING_VISION.md`: **1-bit silhouette pixel
art with selective color accents against OLED true black.** The creature
does not render *on* a background — it emerges *from* darkness. References
cited in the design research: Pico-8's hardware-constraint charm, Game Boy
legibility, the silhouette drama of *Limbo*/*Inside*, and Studio Ghibli's
forest-spirit design language. The governing test, borrowed from highway
signage: **what reads at 20 feet on a highway sign works at arm's length on
a Touch Bar.** At 30 pixels tall, detail is communicated through *shape and
motion*, not texture — two triangular ears, two luminous dots for eyes, a
curved tail silhouette is immediately readable as a cat-spirit without any
learning curve, because millions of years of human-cat coevolution already
taught the viewer to read a slow-blink as trust and an ear-flatten as fear.

The **Ori Principle** (named for *Ori and the Blind Forest*'s art direction):
the creature *is* the light source — a pure self-luminous silhouette on a
dark background. On true OLED black, any non-black pixel literally glows
against the void; this is the visual mechanism that makes "emerges from
darkness" more than a slogan — it is why a lit creature against `void`
(#000000, genuinely unlit OLED pixels) reads as luminous rather than merely
"a shape on black."

# The Solid Fill Test (North Star)

**Render the creature as one flat color at actual Touch Bar scale. If it
doesn't instantly read as its intended form — egg, blob, kitten, cat,
spirit — simplify until it does.** At 30pt tall, silhouette is essentially
the entire signal; detail is a bonus, never a substitute. This is the single
governing acceptance test for every new body-part shape or terrain-object
silhouette added to the codebase — see
[creature visual design](/REFERENCE/creature-visual-design.md) for how it
was applied to the six growth-stage bodies.

# Silhouette-First Design Principles

Eight numbered principles from the graphics-overhaul planning pass
(`docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md`), governing every object and body
part rendered on the Touch Bar — not just the creature:

1. **Recognize in under 200ms** — a glance should register "campfire," not
   "orange triangle."
2. **Silhouette-first** — if an object reads correctly filled solid black,
   it reads at any color.
3. **Depth through layers** — the parallax stack (see
   [world terrain & parallax](/SYSTEMS/world-terrain-parallax.md)) creates
   real spatial depth; a flat scene should never be the fallback.
4. **Scale = distance** — objects closer to the camera render larger.
5. **Stay on-palette** — all 8 P3 colors remain the only fills; depth comes
   from alpha and color-shift ([atmospheric perspective](/REFERENCE/palette.md#general-purpose-palette-operations)),
   never a 9th color.
6. **Composite shapes** — recognizable objects are built from 2-5 simple
   shapes, never a single primitive standing in for something complex.
7. **Motion sells it** — a flickering campfire reads better than a
   perfectly-drawn static one; timing matters more than shape fidelity.
8. **Node budget** — every visual addition respects the project-wide
   ~120-node ceiling; LOD culling keeps distant/off-screen detail hidden
   rather than rendered and clipped.

**Success criteria**, as originally specified and still the acceptance bar
for any visual-recognizability work: showing a Touch Bar screenshot to
someone unfamiliar with the project and asking them to identify each visible
object should produce **>80% correct identification** without hints (a
<60% result, or a response of "I see shapes and dots," is a fail). For depth
specifically: a creature walking toward the camera should look noticeably
larger, mountain ranges should visibly overlap and parallax-scroll at
different speeds, and the honest pass/fail signal is whether an observer
volunteers "it feels 3D" unprompted, versus "it's flat."

# One New Feature Per Stage

Each of the six growth-stage evolutions is designed to feel like a Pokémon-
style event: **exactly one new signature visual feature debuts per
transition**, never a redesign-everything moment. Egg→Drop is "eyes appear"
(life begins); Drop→Critter is "cat silhouette forms" (ears, tail, paws);
Critter→Beast is "whiskers + mouth + aura appear" (maturity); Beast→Sage is
"third eye mark appears" (wisdom); Sage→Apex is "multi-tails + crown +
ethereal body" (transcendence). The full per-feature introduction timeline
(exactly which stage gets whiskers, nose, aura, particles, and why some
features are deliberately withheld one extra stage — e.g. whiskers waiting
for Beast rather than debuting at Critter — is catalogued at
[creature visual design](/REFERENCE/creature-visual-design.md).

# Shape Language Arc

The stage progression is **not** a linear march from round to angular
shapes — it is a narrative arc that returns to roundness at the top:

| Stage | Dominant shape language | Narrative meaning |
|---|---|---|
| Egg | Pure circle/oval | Safety, potential, dormancy |
| Drop | Circle + upward point | Emergence, vulnerability |
| Critter | Circle + triangle ears | Innocence with emerging alertness |
| Beast | Circle + triangle blend | Confidence, capability, personality |
| Sage | **Return to rounder** + flowing curves | Wisdom transcends power |
| Apex | Flowing spirals + dissolving edges | Beyond fixed geometry |

The key insight, drawn from Ghibli spirit-design analysis: **power is
expressed through subtraction, not addition.** The Sage's silhouette is
simpler than the Beast's, not more ornamented — the most powerful spirits in
that design tradition are the most abstract, not the most detailed. This is
why Sage's `shoulderBump`/`haunchWidth` body proportions (see
[creature visual design](/REFERENCE/creature-visual-design.md)) are more
elegant and slimmer than Beast's more muscular ones, even though Sage is the
later, "stronger" stage.

# Visual Earned Complexity

A new developer's Touch Bar is sparse and quiet; a veteran's is rich and
alive — world detail (terrain objects, weather variety, star count, biome
count, ambient particle density) scales through six tiers matched to growth
stage, from Egg's near-empty void to Apex's full cosmic palette. This is a
design *principle*; the exact per-stage gate values (object caps, star
counts, weather-state availability) are the mechanical authority of
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md).

# The "Wow Factor" Moments

`PUSHLING_VISION.md` catalogues twelve deliberately-engineered delight
moments as the design target for the whole visual system — each is
implemented and owned by a specific concept, cross-linked below rather than
re-described here:

1. **Emergence from darkness** — first launch, a pixel of light grows into
   the Spore against true OLED black (see
   [creature identity & birth](/REFERENCE/creature-identity-birth.md)).
2. **True black negative space** — the creature moves between islands of
   light with literal void between them (Luminous Pixel Life, above).
3. **The 60fps difference** — everything else on the Touch Bar is static;
   Pushling breathes, blinks, and sways its tail continuously (see
   [procedural animation](/REFERENCE/procedural-animation.md)).
4. **Storm** — rain-splash particles, a full-width lightning crack with
   screen shake, the creature hunching and flattening its ears (see
   [weather system](/SYSTEMS/weather.md)).
5. **The puddle reflection** — a 1-pixel mirrored silhouette the creature
   occasionally pauses to gaze at (see
   [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)).
6. **Touch response** — sub-pixel finger-tracking, the creature chasing a
   touch like a real cat chasing a laser pointer (owned by the touch/
   interaction concept set).
7. **Evolution ceremony** — a 5-second spectacle marking weeks of care
   (owned by the growth-stages concept).
8. **The ghost echo** — an alpha-0.08 shadow replaying the creature's
   younger form, "past and present coexist" (see
   [world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)).
9. **The growing skyline** — a new repo landmark appears in the distance
   when a new project is tracked (see
   [repo landmarks](/REFERENCE/repo-landmarks.md)).
10. **The first word** — the Critter stage's unprompted self-naming
    ceremony (owned by the speech/voice concept set).
11. **Commit predator crouch** — the hunting-instinct theater of the
    commit-eating animation (owned by the commit-feeding concept).
12. **The slow-blink** — after a long, meaningful Claude session, the
    creature slow-blinks at the camera, signaling trust (owned by the
    personality/emotional-state concept).

# HUD Philosophy

**Cinematic default: no UI, just the living world.** Stats surface only on
an explicit tap, for exactly 3 seconds, and even then the emphasis is
minimal (hearts, stage, XP, streak — not a dashboard). The deeper principle
this enforces is that *the world itself is the interface* wherever possible:
hunger is communicated by desaturating the world and wilting its flowers,
not a hunger bar; imminent evolution is a 1-pixel progress bar at the very
bottom edge, not a banner. The implementation of both the tap-to-show panel
and the progress bar is owned by
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md);
this entry records the principle that shaped that implementation.

# Citations

[1] `PUSHLING_VISION.md` — Visual System: Art Direction, Visual Earned Complexity, The "Wow Factor" Moments, HUD Philosophy
[2] `docs/archive/VECTOR-GRAPHICS-RESEARCH.md` §3 (Design Philosophy — Solid Fill Test, One New Feature Per Stage, Shape Language Arc, the Ori Principle, Animation Over Detail)
[3] `docs/archive/plan/TODO-GRAPHICS-OVERHAUL.md` — Design Principles (8 numbered), Success Criteria
[4] `docs/archive/3D-RENDERING-RESEARCH.md` §1, §12 — "what reads at 20 feet..." framing, aspect-ratio-driven readability argument
