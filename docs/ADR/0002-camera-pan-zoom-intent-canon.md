---
type: ADR
title: "ADR 0002 — Live Pan/Zoom Camera Is Intent-Canon"
description: The designed live pan/zoom camera is ratified as canon-of-intent with unbuilt parts marked 📐 (planned); the shipped fixed-viewport behavior is documented as a deliberate transitional state, not the target design.
status: Proposed
tags: [adr, camera, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0002 — Live Pan/Zoom Camera Is Intent-Canon

---

## Status

Proposed

---

## Context

`CameraController`'s `pan(deltaX:)`, `zoom(delta:centerWorldX:)`, and
`setZoom(_:animated:)` each begin with an unconditional early `return`,
guarded by a `// FIXED-VIEWPORT: pan disabled for Day 1 proof-of-life`
comment (as of build `8860e91`, 2026-07-01). All of the pan/zoom math
described in the design canon still exists in the method bodies below
that `return` — dead code, not deleted code, kept in place for the
eventual re-enable. Git history shows this is a deliberate
regression-by-design, not an oversight: commits `4159177` and `f13b1e0`
tuned pan sensitivity down from 0.3x to 0.02x of finger-drag distance to
fix an over-sensitive background, only for the very next commit
(`8860e91`) to disable pan/zoom entirely.

This is the inverse of the usual "shipped code wins" adjudication: here
the shipped behavior (fixed viewport) is the *lesser* state, and the
unbuilt design (live pan/zoom) is the intended target. Downstream, the
question mattered concretely: `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md`
§5's creature-scaling-under-zoom feature only makes sense if pan/zoom is
real canon-of-intent, not a rejected idea — a drop of §5 during the WO-1
migration was proposed and the human rejected it specifically because it
belongs to this intent-canon. The human resolved the underlying question
in `docs/DECISIONS.md` R2 (2026-07-02).

## Decision

The live pan/zoom camera design is canon-of-intent: unbuilt parts of that
design carry the 📐 (planned) status marker in
[interactivity-unbuilt](/FEATURES/interactivity-unbuilt.md). The current
fixed-viewport behavior is documented as a **deliberate transitional
state**, not the intended end state — see
[camera-and-parallax](/SYSTEMS/camera-and-parallax.md)'s "Current Shipped
State: Fixed Viewport" section. `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md`
§5 (creature scaling under zoom) is preserved as intent-canon rather than
dropped, because it belongs to this same unbuilt-but-intended pan/zoom
system.

## Consequences

Future work on the camera treats the pan/zoom design (per-stage
constraints, lock modes, decay, recenter, Y-tracking) as the thing being
built *toward*, not a rejected alternative to the fixed viewport — a
re-enable of `CameraController`'s disabled math is completing existing
canon, not proposing new scope. The trade-off: the bundle now documents a
system as canon that does not currently run, which risks a future reader
mistaking the design canon for shipped behavior; the "Current Shipped
State: Fixed Viewport" section exists specifically to prevent that
confusion and must stay accurate as the re-enable work progresses. Code
reference: `Pushling/Sources/Pushling/Scene/CameraController.swift`.
