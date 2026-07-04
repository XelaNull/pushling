---
type: ADR
title: "ADR 0005 — Egg Stage Locomotion: The Egg Hops"
description: Code intent is ratified over canon text — the Egg makes occasional slow scoots rather than staying silent and motionless; no .egg gate is added, and the hop's rendering is pending the body-pose-pipeline keystone fix.
status: Proposed
tags: [adr, egg, locomotion, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0005 — Egg Stage Locomotion: The Egg Hops

---

## Status

Proposed

---

## Context

`growth-stages.md` stated the Egg stage is "Silent, no directed
movement." But the shipped code gives Egg real locomotion:
`GrowthStage.baseWalkSpeed` (`Pushling/Sources/Pushling/Behavior/
LayerTypes.swift:47`) returns `case .egg: return 3 // Egg hops slowly` —
a nonzero speed with a comment showing authored intent to move — and no
`.egg` gate exists anywhere in `AutonomousLayer` excluding Egg from the
`.walking` bodyState. This is a genuine canon-vs-code conflict, discovered
during the Phase-2 FO-LOCOMOTION flesh-out wave and verified by Samantha:
it was genuinely ambiguous which side was stale — the doc text describing
intended silence, or the code's small but deliberate walk speed — so it
was escalated rather than silently adjudicated (`docs/DECISIONS.md` D-1,
filed 2026-07-03).

## Decision

The human ruled Option B: **the Egg hops.** Code intent is ratified as
canon — the Egg makes occasional slow scoots (the `baseWalkSpeed: 3`
class of movement, per `LayerTypes.swift:47`'s `// Egg hops slowly`
comment), read as anticipation of the creature growing inside. No `.egg`
gate is added to exclude it from walking; hopping is the intended
behavior, not a bug to fix away. The hop stays **invisible** in the
shipped build until the Phase-3
[body-pose-pipeline](/SYSTEMS/body-pose-pipeline.md) keystone fix ships,
because Egg locomotion routes through the same dropped `positionX`/
`bodyState` channel that keystone fix addresses — the ratified behavior
is real; its rendering is pending on other, already-tracked work.

## Consequences

[growth-stages](/REFERENCE/growth-stages.md)'s "Silent, no directed
movement" text is amended to describe the slow occasional hop, and the
DECISION-pending Egg-row notes in growth-stages, body-pose-pipeline, and
[locomotion-and-gait](/SYSTEMS/locomotion-and-gait.md) are un-parked to
describe the ratified hop with a rendering-pends-keystone caveat. The
trade-off: canon now documents a behavior that is currently invisible to
an end user watching the Touch Bar — anyone reading only the shipped
build without this ADR's context could reasonably conclude the Egg is
still silent, since nothing on screen contradicts that until the
body-pose-pipeline fix lands. The rendering-pends-keystone note in each of
the three amended concepts is the standing mitigation until that fix
ships.
