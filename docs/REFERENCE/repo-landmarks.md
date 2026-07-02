---
type: Reference
title: Repo Landmarks
description: The 9 permanent mid-parallax landmark types generated from a developer's tracked repos, the repo-type detection heuristics that choose them, and their placement and emergence animation.
status: Live
tags: [world, landmarks, repos, terrain]
timestamp: 2026-07-02T00:00:00Z
---

Every repo a developer's creature "eats" commits from earns a permanent
silhouette landmark on the mid-parallax layer — a visual record of coding
breadth that grows as more repos are tracked, and that the creature walks
past every day. This is `LandmarkSystem`
(`Pushling/Sources/Pushling/World/LandmarkSystem.swift` +
`RepoAnalyzer.swift`).

# The 9 Landmark Types

| Landmark | Repo Type | Visual Motif |
|---|---|---|
| **Neon Tower** | Web app | Tall thin tower, blinking Tide antenna light, glowing windows |
| **Fortress** | API/backend | Crenellated twin-tower silhouette, swaying Ember flag |
| **Obelisk** | CLI tool | Tapered pillar with a faint Gilt hieroglyph line |
| **Crystal** | Library/package | Faceted gem shape with Dusk refraction lines and a twinkle |
| **Smoke Stack** | Infra/DevOps | Industrial stack with an Ember warning stripe and drifting smoke particles |
| **Observatory** | Data/ML | Domed building with a slit window and a twinkling Gilt star |
| **Scroll Tower** | Docs/content | Curved-top tower with horizontal scroll-line markings |
| **Windmill** | Game/creative | Spinning 4-blade windmill with a lit window and door |
| **Monolith** | Generic/unknown fallback | Plain rectangular slab with a crack and a mossy base |

Each is a self-contained `SKNode` composition, 4-8pt tall, built from plain
shapes in `PushlingPalette.ash` (the base landmark color) with palette-color
accent details (see [the 8-color P3 palette](/REFERENCE/palette.md)) —
distant-layer atmospheric tinting is applied via
`PushlingPalette.atmosphericColor(_:depth: 0.4)`.

# Repo Type Detection

`RepoAnalyzer.analyzeRepo(at:)` runs a **shallow, one-level-deep** scan of a
repo's root directory — no git log needed — and checks heuristics in
**priority order, first match wins**:

1. **Web app** — has `package.json` *and* a `.tsx`/`.jsx`/`.vue`/`.svelte`
   file (root or one subdirectory deep)
2. **Infra/DevOps** — has a `.tf` file, a `Dockerfile`, or `.github/workflows`
3. **Data/ML** — has a `.ipynb` file (root or nested), or a `models`
   directory
4. **API/backend** — has a `routes`, `controllers`, or `app` directory,
   *and* one of `package.json`/`.py`/`.rb`/`.php`/`.go`
5. **CLI tool** — has a `bin` directory, `main.go`, `src/main.rs`, or
   `src/main.ts`
6. **Library** — has a `lib` directory *and* one of `.npmrc`/`setup.py`/
   `Cargo.toml`/`Package.swift`
7. **Game/creative** — has a `.unity`/`.godot`/`SpriteKit`/`SDL` file or
   directory
8. **Docs/content** — more than half the root directory's entries (with at
   least 3 entries) have a `.md`/`.txt`/`.rst`/`.tex`/`.adoc` extension
9. **Generic** (fallback) — none of the above matched

# Placement

- **Minimum spacing**: 80pt between landmarks (`LandmarkSystem.minSpacing`)
- **Baseline**: y = 6.0pt on the mid-parallax layer
  (`LandmarkSystem.baselineY`)
- **Position**: each new landmark's world-X is the running `nextWorldX`
  cursor plus a deterministic ±20pt jitter derived from a djb2-style hash of
  the repo name — same repo name always lands at the same relative jitter,
  keeping placement reproducible across restarts
- A repo is only ever registered once — `addLandmark` is a no-op if the
  repo name already has a landmark

# Emergence Animation

When a new landmark first appears, it rises from the ground rather than
popping in instantly (~3 second sequence):

| Time | Effect |
|---|---|
| t=0 | Node starts 5pt below its resting Y, fully transparent |
| t=0 to 1.5s | Fades in while rising |
| t=0 to 3.0s | Rise completes (ease-out) |
| t=0.5s | Three small Ash dust particles spawn at the base, drift outward and fade over 1.5s |
| t=2.5s | A Gilt glow flash appears and fades over 0.5s, marking arrival |

# Nearest-Landmark Query

`nearestLandmark(to:maxDistance:)` returns the closest landmark to a given
world-X within a default 60pt radius, or `nil` if none is within range —
used to let the creature react to (or the camera favor) a nearby landmark.

# Citations

[1] `Pushling/Sources/Pushling/World/LandmarkSystem.swift`
[2] `Pushling/Sources/Pushling/World/RepoAnalyzer.swift`
[3] `PUSHLING_VISION.md` — Visual System: World Composition (Repo skyline)
