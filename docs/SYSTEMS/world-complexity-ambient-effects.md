---
type: System
title: World Complexity & Ambient Effects
description: The six-tier stage-gated world-richness controller, and the ambient/emotional-feedback systems layered on top of it — diet-influenced world tinting, the ghost echo, puddle reflections, hunger desaturation, ruin inscriptions, the seven visual-event spectacles, and the cinematic tap-to-show HUD.
status: Live
tags: [world, complexity, ambient, hud, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **how much world the creature has earned** and
**how the world communicates emotional/environmental state without a UI**.
It does not own the terrain/parallax/biome mechanics being gated (see
[world terrain & parallax](/SYSTEMS/world-terrain-parallax.md)), the sky/moon/
star/cloud elements being gated (see
[sky & celestial system](/SYSTEMS/sky-celestial.md)), or the weather states
being gated (see [weather system](/SYSTEMS/weather.md)) — those systems own
their own mechanics; this concept owns the *gate*. Source:
`World/VisualComplexity.swift`, `World/WorldTinting.swift`,
`World/GhostEcho.swift`, `World/PuddleReflection.swift`,
`World/HungerDesaturation.swift`, `World/RuinInscriptions.swift`,
`World/VisualEvents.swift` + `VisualEventBuilders.swift`,
`Scene/HUDOverlay.swift`, `Scene/EvolutionProgressBar.swift`.

# Complexity Levels

`VisualComplexityController` maps each `GrowthStage` 1:1 to a
`ComplexityLevel` (void/emerging/alive/thriving/magical/cosmic) and caches
per-level configuration structs, recomputed only on stage change — every
system below queries these cached values, never running per-frame gate
logic of its own.

| Stage → Level | Max terrain objects | Star cap | Weather enabled | Biomes visible | Fog-of-war radius |
|---|---|---|---|---|---|
| Egg → void | 0 | 3 | no (clear only) | 0 | 40pt |
| Drop → emerging | 4 (grass/flower/rock only) | 10 | no | 1 | 100pt |
| Critter → alive | 10 | 18 | yes — clear/cloudy only | 2 | 200pt |
| Beast → thriving | 14 (all types) | 25 | yes — all 6 states | 5 (full) | 400pt |
| Sage → magical | 14 | 25 | yes — all 6 | 5 | 600pt |
| Apex → cosmic | 14 | 25 (stars react to creature) | yes — all 6 | 5 | 1200pt |

Convenience gates derived from level: day/night cycle at Critter+
(`dayNightEnabled`), full 3-layer-plus parallax and repo landmarks at Beast+
(`fullParallaxEnabled`/`landmarksVisible`), magic ambient motes and the ghost
echo at Sage+ (`magicEffectsEnabled`/`ghostEchoEnabled`), terrain-glow-near-
creature at Apex only (`terrainGlowEnabled`), puddle reflections from
Critter+ (`puddleReflectionsEnabled`), ruin inscriptions from Beast+
(`ruinInscriptionsEnabled`), and visual-event spectacles available from
Critter+ (`visualEventsEnabled`). Terrain texture detail (contour lines,
valley shadow/hilltop highlight, micro-detail grass strokes) scales through
its own four-tier table, from fully off at Egg to 3 contour lines + 8pt
micro-detail spacing + slope-shading at Beast+.

# Diet-Influenced World Tinting

`WorldTinting` maintains a single full-scene `SKSpriteNode` overlay
(`.alpha` blend mode, z-position 500 — above world, below HUD) whose color
tracks the creature's current `LanguageSpecialty` — Systems (Ember),
Frontend (Tide, 0.20 alpha — "slightly more visible for neon/matrix feel"),
Backend (Ember→Bone 50% blend), Scripting (Moss), Data (Tide, 0.20 alpha),
JVM (Tide→Dusk 40% blend), Devops (Bone), Mobile (Tide→Ember 30% blend); most
specialties tint at 0.15 alpha. A specialty change **crossfades over 10
seconds** (`crossfadeDuration`) via simultaneous `colorize` + `fadeAlpha`
actions. **Polyglot** (no category over 30%) instead runs a **30-second**
repeating cycle (`polyglotCycleDuration`) through six of the specialty
tints in sequence at a fixed 0.15 alpha, rather than settling on one color —
this is the one specialty whose "tint" is a perpetual `SKAction.repeatForever`
loop, not a static value. Zero additional node cost beyond the one overlay
sprite.

# Ghost Echo

Sage+ only. A single, barely-visible (**alpha 0.08**) silhouette of the
creature's form one stage below current (or, at Apex, a *random* past stage
re-rolled on each appearance) walks 20pt behind the creature with a 0.3s
position-history delay, so its motion trails rather than mirrors in
lockstep. Appearances last **30 seconds**, fading in/out over 5s each, with a
**2-5 minute cooldown** between them — an intermittent discovery, not a
constant companion. The ghost's own breathing runs on a desynced 3.0s sine
independent of the real creature's breathing cycle, so the two never move in
sync even when overlapping. Node cost: 0 when dormant, 2 while appearing
(container + body shape, built from the same `bodySilhouette` path family as
[creature visual design](/REFERENCE/creature-visual-design.md)).

# Puddle Reflections

Available from Critter+ (`puddleReflectionsEnabled`). When the creature is
within **10pt** of a water-puddle terrain object, a 1-pixel-tall mirrored
silhouette (the same `bodySilhouette` path, y-squished to 15% via an affine
transform, `yScale = -1` for the mirror) fades in below the puddle surface
at 0.15 alpha in the creature's stage color. Walking within 4pt of the
puddle triggers a ripple — an expanding-and-fading ellipse (2×→1.5×, 0.5s).
Every 10 seconds while lingering within 6pt, there is a 5% chance the
creature is cued to pause and gaze at its own reflection — a rare,
deliberately subtle "wow factor" moment rather than a guaranteed one. Node
cost: 0 idle, 2 while a puddle is nearby (reflection + ripple).

# Hunger Desaturation

A single full-scene Ash-tinted overlay (no `CIFilter` — deliberately cheap,
just an alpha-blended flat-color sprite) that communicates low satisfaction
**through the world itself, never a UI bar**. Below satisfaction 25, alpha
ramps toward a maximum of 0.45 proportional to `(25 − satisfaction) / 25`
(so satisfaction 0 = full desaturation); above satisfaction 30, the overlay
recovers to zero **over 30 seconds** rather than snapping clear the instant
the threshold is crossed. Exposes three query properties consumed elsewhere
in the world: `flowersWilted` (true above 0.3 intensity),
`treesBare` (true above 0.5), and `groundDesaturation` (intensity × 0.6, for
blending terrain fill color toward Ash). One node, always present, usually
at alpha 0.

# Ruin Inscriptions

Available at Beast+ (creature "needs literacy"). When the creature
autonomously examines a ruin-pillar terrain object, there is a **30% chance**
(gated additionally by a **30-minute cooldown** and by not already mid-
display) that a journal fragment is shown — the first 10 words of an actual
journal entry (oldest-preferred, cycling through a periodically-refreshed
cache), quoted, rendered as tiny 5pt Menlo text at 60% Ash alpha above the
ruin for 3 seconds (0.5s fade in/out each side). The creature is cued via
`onCreatureReading` to show a thoughtful/reading posture for the duration.
One node, present only during an active reading.

# Visual Event Spectacles

Seven one-shot events — the tool-level trigger contract (action name,
required params) belongs to
[world & objects system](/SYSTEMS/world-objects-system.md); this concept
owns what actually renders. Triggerable via `pushling_world("event")`, queued (not
dropped) if one is already playing so a rapid-fire trigger never loses an
event — `VisualEventManager` runs exactly one at a time:

| Event | Duration | What renders |
|---|---|---|
| `shooting_star` | 2s | A Gilt streak crosses left-to-right with a 3-particle fading trail and a Bone flash burst near the end of its path |
| `aurora` | 45s | Five overlapping horizontal Moss/Tide/Dusk bars near the top of the sky, each fading in over 3s then perpetually wave-bobbing and slow-drifting until the event ends |
| `bloom` | 5s | 8 staggered Moss particles rise from the ground with drift and fade, plus a brief low-alpha Moss pulse across the whole scene |
| `eclipse` | 20s | A Void darken layer (peaks at 0.4 alpha) plus a Dusk tint layer (peaks at 0.15), each ramping over 5s, holding 10s, then releasing over 5s |
| `festival` | 15s | 12 confetti pieces in all 6 palette colors fall from the top with randomized drift/spin/fade, staggered over the full event window |
| `fireflies` | 45s | 8-15 Gilt dots with per-frame random-walk drift, a sine-based pulse tied to position, and an inversely-pulsing trail child node on each — this is the shipped implementation of the "gentle streaking" trail effect once proposed as future work in `docs/plan/TODO-GRAPHICS-OVERHAUL.md` Phase 4 |
| `rainbow` | 20s | Five staggered-radius arcs in the 5 non-Bone/Void palette colors, each fading in over 3s and holding before fading out over 4s |

Events layer above the world and below speech bubbles (`zPosition: 300`);
node budget for any single event is bounded well under the 15-node target
listed in the design source. The creature is expected to react with a
generic "wonder" expression during any active event (owned by the emotional-
expression system, cross-referenced rather than duplicated here).

# The Cinematic HUD

**Default state is zero UI** — the philosophy is that the world itself is the
interface (hunger desaturation, the evolution progress bar below, are the
"HUD" in spirit). A tap on empty space (filtered from creature-taps and
object-taps upstream) triggers `HUDOverlay.handleTap`: a small ripple at the
touch point, and a 120×18pt bottom-left panel that fades in over 0.2s, holds
for **3 seconds**, and fades out over 0.5s, showing hearts (satisfaction, one
per 20 points, filled vs. hollow Unicode heart glyphs in Ember), stage name
(in the stage's palette color), current/next-threshold XP (Tide), and streak
days if any (Gilt). The ripple pool is 3 reusable circles, expanding
2pt→6pt over 200ms. Node budget is a flat 10 (root + container + background
+ 4 labels + 3 ripples), always resident but hidden at alpha 0 between taps
— cheaper than repeated add/remove.

# Evolution Progress Bar

A single-pixel-tall bar at the very bottom edge of the scene, invisible until
the creature crosses **80%** progress toward its next stage threshold
(`showThreshold`). Width is proportional to remapped progress across the
final 20%; fill color matches the creature's current stage color
(`PushlingPalette.stageColor(for:)`). At **95%** it begins a 1Hz sinusoidal
alpha pulse (0.5→1.0); at **99%** the pulse intensifies to 2Hz (0.3→1.0
range) and the fill color interpolates toward Gilt over that final 1% —
visible urgency escalating right up to the evolution ceremony, during which
the bar is explicitly hidden (`hideForCeremony`) and reset to 0% for the
next stage on reappearance. One node, updated on XP change rather than every
frame (the pulse animation is the only per-frame work, and only while
visible past the 95% threshold).

# Citations

[1] `Pushling/Sources/Pushling/World/VisualComplexity.swift`
[2] `Pushling/Sources/Pushling/World/WorldTinting.swift`
[3] `Pushling/Sources/Pushling/World/GhostEcho.swift`
[4] `Pushling/Sources/Pushling/World/PuddleReflection.swift`
[5] `Pushling/Sources/Pushling/World/HungerDesaturation.swift`
[6] `Pushling/Sources/Pushling/World/RuinInscriptions.swift`
[7] `Pushling/Sources/Pushling/World/VisualEvents.swift`, `World/VisualEventBuilders.swift`
[8] `Pushling/Sources/Pushling/Scene/HUDOverlay.swift`, `Scene/EvolutionProgressBar.swift`
[9] `docs/plan/phase-3-world/PHASE-3.md` (P3-T1-09, P3-T3-03 through P3-T3-11) — original spec, numbers confirmed
[10] `PUSHLING_VISION.md` "Visual Earned Complexity", "HUD Philosophy", "The 'Wow Factor' Moments"
