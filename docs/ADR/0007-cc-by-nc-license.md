---
type: ADR
title: "ADR 0007 — License Pushling Under CC BY-NC 4.0"
description: Pushling is licensed Creative Commons Attribution-NonCommercial 4.0 — free to use, share, and adapt with attribution; commercial use is prohibited.
status: Accepted
tags: [adr, license, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0007 — License Pushling Under CC BY-NC 4.0

---

## Status

Accepted
Accepted 2026-07-04 (human).

---

## Context

Pushling needed a license before it could be shared or distributed beyond
the human's own machine. The commit that introduced `LICENSE` (`1279bc9`,
authored by the human, 2026-03-24) states the intent plainly: "free to use
and modify, not for sale." No prior license existed. The choice made was
notably a **content license** — Creative Commons — applied to a software
project, rather than one of the software-native noncommercial licenses
(e.g. PolyForm Noncommercial) that exist specifically for this use case.

## Decision

Pushling is licensed under **Creative Commons Attribution-NonCommercial
4.0 International** (`LICENSE`). Anyone may share and adapt the project in
any medium or format, provided they give appropriate credit, link to the
license, and indicate changes made. Commercial use is prohibited. No
additional legal or technological restrictions may be layered on top of
what the license already permits.

## Consequences

Pushling can be freely shared, forked, and modified for non-commercial
purposes with attribution, which fits the project's current status as a
personal/hobby creature rather than a commercial product. The trade-off,
inherited from choosing a content license over a software-native one: CC
BY-NC 4.0 was not written with source code's specific concerns in mind
(e.g. patent grants, and the license's own explicit note that it does not
apply to elements of the material in the public domain or where the use
is permitted by an applicable exception or limitation to copyright) — a
software-native NC license would have addressed those more directly. Any
future move toward commercial distribution (e.g. the planned
[Homebrew cask channel](/FEATURES/roadmap.md)) would require relicensing,
which is a separate decision this ADR does not make.
