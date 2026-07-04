---
type: ADR
title: "ADR 0001 — Ratify XP-Threshold Growth Model"
description: Shipped XP thresholds (100/500/2000/8000/20000) and the egg first stage are ratified as canon, superseding PUSHLING_VISION.md's unbuilt commits-eaten/Spore model.
status: Accepted
tags: [adr, growth, xp, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0001 — Ratify XP-Threshold Growth Model

---

## Status

Accepted
Accepted 2026-07-04 (human).

---

## Context

`PUSHLING_VISION.md`'s original Growth Stages design gated evolution on
**commits eaten** (with an `activity_factor` multiplier) and named the
first stage **Spore**. That model was never built. The shipped daemon
instead evolves the creature on an **XP** stat with fixed thresholds, and
names its first stage **egg** — a different vocabulary, a different
mechanism, and a different first-stage name from the source design.

This is a canon-vs-code conflict of the "gap between vision and shipped
reality" kind: two incompatible growth vocabularies could not both stand
as canon without poisoning every stage-gated concept downstream (growth
stages, evolution ceremonies, stage-gated feature docs all need one
authoritative model to cite). The question was escalated during the WO-1
OKF migration and resolved by the human (`docs/DECISIONS.md` R1,
2026-07-02): does canon describe the never-built vision intent, or the
shipped, working system?

## Decision

Shipped code is canon. XP thresholds are `100 / 500 / 2000 / 8000 / 20000`
gating the six growth stages, and the first stage is named `egg`.
`PUSHLING_VISION.md`'s commits-eaten model with its `Spore` first stage is
preserved **in-concept as superseded design history** — clearly marked as
such, not deleted, and not presented as describing the shipped system. See
[growth-stages](/REFERENCE/growth-stages.md) for the full stage table and
the "Superseded Design History: Commits-Eaten Model" section that carries
the original vision-doc table forward as historical record.

## Consequences

Every stage-gated concept in the bundle (evolution ceremonies, per-stage
feature unlocks, [companionship-rituals](/SYSTEMS/companionship-rituals.md),
[speech-filtering](/SYSTEMS/speech-filtering.md), etc.) can cite one
authoritative growth vocabulary — XP and `egg`/`drop`/`critter`/`beast`/
`sage`/`apex` — without needing to reconcile a second, conflicting
commits-eaten model. The trade-off: `PUSHLING_VISION.md`'s original
design intent is demoted to historical record rather than shaping future
growth-model work; any future desire to revive activity-weighted
progression would need its own ADR rather than falling out of existing
canon. Code reference: `GameCoordinator.stageThresholds`
(`Pushling/Sources/Pushling/App/GameCoordinator+Loading.swift`, the literal
`.drop: 100, .critter: 500, .beast: 2000, .sage: 8000, .apex: 20000` map)
and `GrowthStage` (`Pushling/Sources/Pushling/Behavior/LayerTypes.swift`,
`egg` raw value `0`).
