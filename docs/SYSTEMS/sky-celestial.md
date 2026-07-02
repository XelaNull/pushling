---
type: System
title: Sky & Celestial System
description: The real-time wall-clock sky gradient across eight time periods, the Metonic-approximation lunar phase moon, the twinkling star field, and the drifting cloud layer — all rendered on the far/deep parallax layers.
status: Live
tags: [world, sky, weather-adjacent, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **everything above the terrain that isn't
weather** — the sky gradient, moon, stars, and clouds. It does not own
weather particle states or transitions (see
[weather system](/SYSTEMS/weather.md), which *drives* some of this concept's
inputs — sky darkening, cloud density/color), the parallax layer
configuration these elements ride on (see
[world terrain & parallax](/SYSTEMS/world-terrain-parallax.md)), or
stage-gated star-count/complexity gating (see
[world complexity & ambient effects](/SYSTEMS/world-complexity-ambient-effects.md)).
Source: `World/SkySystem.swift`, `World/MoonPhase.swift`,
`World/StarField.swift`, `World/CloudSystem.swift`.

# Sky Gradient — 8 Time Periods

`SkySystem` computes the current time period and an interpolation factor
from wall-clock time (`Calendar.current`, local timezone), recalculating
once per second (`updateInterval = 60` frames) — cheap enough that a
per-second cadence is more than sufficient for a smoothly-perceived
transition. Each period defines a two-stop vertical gradient
(top→bottom), built from **only** palette colors at reduced alpha (never a
raw hex):

| Period | Wall clock start | Gradient (top → bottom) |
|---|---|---|
| Deep Night | 00:00 | Void → Dusk @ 0.3 |
| Dawn | 04:30 | Dusk @ 0.6 → Ember @ 0.4 |
| Morning | 06:00 | Ember @ 0.3 → Tide @ 0.2 |
| Day | 09:00 | Tide @ 0.15 → Bone @ 0.1 |
| Golden Hour | 16:00 | Gilt @ 0.3 → Ember @ 0.35 |
| Dusk | 18:00 | Ember @ 0.25 → Dusk @ 0.6 |
| Evening | 19:30 | Dusk @ 0.5 → Void |
| Late Night | 22:00 | Void → Dusk @ 0.15 |

**Transitions are 10 minutes** (`transitionDuration = 600s`), beginning at
`(period duration − 10min)` into the current period and completing exactly
at the next period's start hour — never a hard color snap. The gradient
renders to a small (2×30px) pre-rendered texture
(`SkyGradientNode.updateGradient`), regenerated only when the interpolated
top/bottom colors actually change beyond a 0.005 threshold, and stretched
across the full scene width by SpriteKit — this is deliberately cheap: one
texture upload roughly once per transition tick, not a per-frame shader.
Deep Night's sky is literal `#000000` (Void) at the top — true OLED-black,
pixels off.

Weather can darken the sky further via
`applyWeatherDarkening(alpha:color:)`, which the
[weather system](/SYSTEMS/weather.md) drives directly (storm blends toward
Void+Dusk at up to 50% alpha; other states blend toward Ash at their own
darkening factors) — this composes with, rather than replaces, the
time-of-day gradient.

# Moon

`MoonPhaseNode` renders a **3×3pt** moon (8×8px texture, nearest-neighbor
filtered for crisp pixel edges) at a fixed far-layer position
(`x: 950, y: 24`) — upper-right, as specified. Phase is computed by
`LunarPhase`, a **Metonic-cycle approximation**: Julian Day minus a known
new-moon reference (2000-01-06 18:14 UTC, JD 2451550.26), divided by the
synodic month (29.53058770576 days), fractional remainder gives phase 0.0-1.0
(0/1 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter). No
ephemeris library — this is intentionally simple and accurate to within
about a day, which is more than sufficient at a 3pt render size. Illumination
fraction uses `(1 − cos(2π·phase)) / 2`; the phase texture (Bone-lit /
Ash-shadowed hemispheres split by a cosine terminator, waxing lights from
the right / waning darkens from the right) regenerates once per calendar
day, not per frame. `isFullMoon` (illumination > 0.95) is the hook point for
the full-moon surprise. Visibility fades in/out with the sky system's
per-period `nightAlpha`, easing 10% of the remaining distance toward target
each update rather than snapping.

# Star Field

`StarFieldNode` holds **15-25** 1×1pt Gilt-colored sprites (a `2×1pt`
"bright" variant at 15% probability), placed randomly within the upper
two-thirds of the sky (`y: 10...28`, margin 20pt from horizontal edges) while
excluding an 8pt radius around the moon's fixed position. A brand-new
arrangement generates once per calendar day (`Calendar.ordinality(of: .day,
in: .year, for:)` tracked against the last-generated day) — "new sky each
night," as specified, not a fixed constellation. Each star independently
oscillates alpha via `baseAlpha ± twinkleAmplitude·sin(2π·frequency·t +
phase)`, frequency randomized 0.5-2.0Hz, amplitude 0.1-0.3 — the twinkle
update runs every frame but is skipped entirely when the field's overall
alpha is below 0.01 (i.e., during the day), so the ~0.01ms-for-25-stars cost
is paid only at night. Field-level alpha tracks the same `nightAlpha` value
the moon uses, so both fade together.

# Clouds

`CloudSystem` is a distinct sub-layer between the far and mid parallax
layers, at `zPosition: -75` (the same z-band as the deep layer) with its own
**0.25× scroll factor**. A pool of **6-8** `CloudNode` instances, each built
from **3-5 overlapping ellipses** (organic, non-symmetric silhouette:
30-80pt overall width, 4pt base height, per-ellipse size/vertical-offset
jitter), drift **leftward** (negative `driftSpeed`, 5-15pt/sec) plus a slow
sinusoidal vertical bob (0.5pt amplitude × per-cloud 0.7-1.3 jitter, ~8s
period). This canonizes the shipped direction over the design-era doc's
"drift slowly left-to-right" — `CloudSystem.swift`'s own header and its
`CloudConfig` doc comment both say leftward, and that is what ships; the
"left-to-right" phrasing in `docs/3D-RENDERING-RESEARCH.md` §14 is
superseded design history. Clouds wrap around a virtual strip wider than the
viewport (`sceneWidth / scrollFactor + 2×recyclePadding`) and recycle
(reconfigure with fresh random parameters, reposition just past the right
edge) once they've drifted fully off the left edge.

**Appearance is driven by both time-of-day and weather**, recalculated only
on state change (not per-frame):

| Time period | Base tint |
|---|---|
| Golden Hour | Ember↔Gilt blend (50%) |
| Dusk | Ember→Bone (40%) |
| Dawn | Ember→Bone (60%) |
| Deep/Late Night | Ash |
| Evening | Ash→Bone (30%) |
| Morning, Day | Bone |

| Weather state | Alpha / color adjustment |
|---|---|
| Clear | 0.12 alpha — wispy |
| Cloudy | 0.35 alpha — dense |
| Rain | 0.40 alpha, blended 50% toward Ash |
| Storm | 0.55 alpha, Ash→Void blend (40%) — "dark Ash clouds" |
| Snow | 0.30 alpha, blended 30% toward Bone |
| Fog | 0.0 alpha — invisible; the fog renderer owns atmosphere in that state |

Total node cost is bounded: 6-8 clouds × 3-5 ellipses = 24-40 child nodes,
well inside the project's 120-node ceiling, and per-frame cost is limited to
position/bob math (no per-frame texture or shader work).

# Citations

[1] `Pushling/Sources/Pushling/World/SkySystem.swift`
[2] `Pushling/Sources/Pushling/World/MoonPhase.swift`
[3] `Pushling/Sources/Pushling/World/StarField.swift`
[4] `Pushling/Sources/Pushling/World/CloudSystem.swift`
[5] `docs/plan/phase-3-world/PHASE-3.md` (P3-T2-01 through P3-T2-03) — original spec, all numbers confirmed unchanged except cloud drift direction
[6] `docs/3D-RENDERING-RESEARCH.md` §14 "Clouds System" — superseded drift-direction/size/count claims, corrected above
[7] `PUSHLING_VISION.md` "World Composition" (Sky, Clouds subsections)
