---
type: ADR
title: "ADR 0004 — Canonical Authority Is the Tracked docs/ OKF Bundle"
description: The version-controlled docs/ bundle is the sole canonical spec authority; PUSHLING_VISION.md is fully absorbed and carries a canon-has-moved banner until its Phase-2 archival.
status: Accepted
tags: [adr, canon, okf, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0004 — Canonical Authority Is the Tracked docs/ OKF Bundle

---

## Status

Accepted
Accepted 2026-07-04 (human).

---

## Context

Before the WO-1 OKF migration, `PUSHLING_VISION.md` was the project's only
spec document — a single large file mixing philosophy, design intent, and
descriptions of systems that had since shipped, drifted, or never been
built at all. As the `docs/` OKF bundle (Markdown + YAML frontmatter
concept files) was authored to replace it, two documents briefly risked
both claiming authority over the same subject matter — a state the
migration's constraints explicitly flagged as unacceptable ("legacy and
OKF never both claim authority"). `.samantha/` (where planning artifacts
like the migration plan live) is gitignored in this repo, so canon could
not live there — it must be tracked, diffable, and travel with the repo,
which `pushling/docs/` satisfies and `.samantha/` does not. The human
resolved the authority and repointing question in `docs/DECISIONS.md` R4
(2026-07-02).

## Decision

`PUSHLING_VISION.md` is fully absorbed into the OKF bundle and all inbound
references are repointed immediately (including `pushling/CLAUDE.md`,
which is thinned to a pointer/loader view over the bundle). The file
carries a "canon has moved" banner (verified present at
`PUSHLING_VISION.md` lines 1-7) and stays in place at the repo root as
historical/aspirational source material until Phase-2 exit, at which
point it physically archives. The version-controlled `pushling/docs/`
bundle is the sole spec authority from the moment the banner lands —
never before Phase-2 exit is `PUSHLING_VISION.md` treated as co-authority.

## Consequences

Every future documentation or spec-check pass points at
[the docs index](/index.md) and follows into the relevant concept, never
at the raw vision file — `pushling/CLAUDE.md`'s spec-check repoint already
reflects this. The trade-off: holding `PUSHLING_VISION.md` in place
(rather than archiving immediately) means a stale-but-banner'd document
persists at the repo root for the duration of Phase-2, which risks a
future contributor skimming it without noticing the banner; the banner's
explicit code-wins-on-disagreement clause is the mitigation until the file
is physically moved to `docs/archive/` at Phase-2 exit.
