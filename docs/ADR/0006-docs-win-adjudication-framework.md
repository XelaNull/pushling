---
type: ADR
title: "ADR 0006 — Doc-vs-Code Adjudication Framework"
description: Where docs contradict shipped code, code wins unless the human ruled otherwise, and every adjudication is recorded, never silently picked. Complemented by intent-canon preservation of designed-but-unbuilt features under 📐 markers.
status: Accepted
tags: [adr, canon, process, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0006 — Doc-vs-Code Adjudication Framework

---

## Status

Accepted
Accepted 2026-07-04 (human).

---

## Context

The WO-1 OKF migration converted dense, hand-authored source design docs
(`PUSHLING_VISION.md`, `docs/archive/*.md` plan/research files) into the
`docs/` bundle while the shipped Swift/TypeScript code had, in many
places, drifted from what those source docs described — sometimes because
a feature shipped differently than designed, sometimes because a feature
was never built at all. Migrating the source text verbatim would have
enshrined stale claims as canon; silently rewriting to match code would
have erased the human's actual product intent wherever it still mattered
(as ADR-0002's camera ruling shows — sometimes the *design* is the
correct target, not the shipped state). Without a stated rule, each
concept's author would adjudicate divergences inconsistently, and the
same conflict could be silently resolved two different ways in two
different concepts. This adjudication rule was set as a standing WO-1
constraint and has since been invoked explicitly in 9+ live concepts
(e.g. `ai-command-queue.md` line 20, `speech-filtering.md` line 61,
`world-objects-system.md` line 99, `creature-identity-birth.md` line 190,
`commit-feeding-xp.md` line 321).

## Decision

Where a source doc contradicts shipped code: **shipped code wins unless
the human explicitly ruled otherwise** (as in ADR-0002's camera ruling,
and ADR-0005's egg-hop ruling). Every such adjudication is recorded
in-concept or in `docs/DECISIONS.md` — never silently picked. Complementing
this: designed-but-unbuilt features are **intent-canon**, preserved in
full with a 📐 (planned) status marker rather than pruned as stale. "No
code exists" is the definition of 📐, never a justification to drop the
content — enforced twice during the migration (the rejected drop of
`docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` §5 creature-scaling-under-
zoom, and the preserved P5-T1-16 seven between-session speech triggers).
Wire-or-descope decisions for any given 📐 item remain separate future
work, not resolved by this ADR.

## Consequences

Every concept author (human or agent) has one rule to apply at a doc-vs-
code conflict instead of inventing a fresh judgment call each time, and
every reader of the bundle can trust that a divergence, if present, was
adjudicated and recorded rather than silently resolved. The trade-off:
this rule generates ongoing bookkeeping — every adjudication needs a
recorded trail (an in-concept note or a `docs/DECISIONS.md` entry) — and
some 📐-marked content will describe features that may never be built,
which a future contributor could mistake for near-term commitments if
they skip the status marker. The marker convention and the
`docs/DECISIONS.md` workspace are the standing mitigations for both risks.
