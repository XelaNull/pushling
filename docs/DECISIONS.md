---
type: Reference
title: Decisions
description: Open-questions workspace for the OKF bundle — the first stop when a canon edge (gap, conflict, or change) is hit.
---

# DECISIONS — Open Questions

<!--
This is the open-questions workspace. It is the first stop when Samantha (or Monk)
hits a canon edge: a Gap (no canon covers it), a Conflict (action would contradict canon),
or a Change (canon itself appears wrong or stale).

LIFECYCLE:
1. Log the question here (OPEN) — do not stall; build the unambiguous kernel and continue.
2. Samantha drives the discussion with the human.
3. Human resolves → mark RESOLVED, draft an ADR if the resolution is durable.
4. Ratified ADR → entry here moves to CLOSED; canon is updated; the leash grows.

RULES:
- Append-only within each item once logged. Never delete or overwrite an open item.
- The human is the only one who can mark something RESOLVED or CLOSED.
- A DECISION logged here is NOT yet canon — act on the unambiguous kernel only.
- Items stale beyond 2 sprint cycles → flag to the human for triage.
-->

---

## OPEN

<!-- Items not yet resolved. -->

<!-- (empty) -->

---

## Resolved rulings

<!-- The 4 human canon rulings that seeded this bundle's migration (WO-1). Each RESOLVED. -->

### RESOLVED — R1 — Growth model: XP thresholds and first stage

**Filed:** 2026-07-02
**Resolved:** 2026-07-02
**Resolution:** Code reality is ratified as canon. XP thresholds are `100 / 500 / 2000 / 8000 / 20000`; the first stage is named `egg`. `PUSHLING_VISION.md`'s original commits-eaten / `Spore` model is preserved **in-concept as superseded design history** — it does not describe the shipped system.
**ADR:** pending

### RESOLVED — R2 — Camera: live pan/zoom vs. fixed viewport

**Filed:** 2026-07-02
**Resolved:** 2026-07-02
**Resolution:** The live pan/zoom camera is **intent-canon** — unbuilt parts of that design are marked with the 📐 (planned) status marker in `FEATURES/`. The current fixed-viewport behavior is documented as a **transitional state**, not the target design.
**ADR:** pending

### RESOLVED — R3 — First Word ceremony

**Filed:** 2026-07-02
**Resolved:** 2026-07-02
**Resolution:** The shipped ceremony is canon: triggers at the Critter stage after 10+ commits, the creature speaks its **own name**, and the ceremony runs for 5 seconds. `CREATURE-VOICE-DESIGN.md`'s alternative design is preserved as **considered-and-rejected history**.
**ADR:** pending

### RESOLVED — R3-amended — First-word milestones

**Filed:** 2026-07-02
**Resolved:** 2026-07-02 (human ruling, option A)
**Resolution:** R3's "considered-and-rejected" framing above is **dropped**. Code
verification (SP4) found `CREATURE-VOICE-DESIGN.md` §10's alternative was not
rejected — it shipped, nearly verbatim, as a **second, independent milestone**.
Canon now documents **two complementary shipped milestones**, both real, neither
superseding the other:

1. **Critter — First Word Ceremony** (`FirstWordCeremony.swift`): the creature's
   **own name**, spoken as a question, a scripted 5-second visual ceremony. (This
   is the milestone R3 above originally ratified.)
2. **Beast — First Audible Word** (`VoiceSystem.speakFirstWord()`): the
   **developer's first name** (from `git config user.name`), whispered through
   Kokoro 2.5s after first reaching Beast, audio-only, no visual fanfare.

`CREATURE-VOICE-DESIGN.md`'s alternative design is **absorbed into canon**
(partly live) as Milestone 2, not preserved as rejected history. Full detail:
[speech-milestones](/REFERENCE/speech-milestones.md).
**ADR:** pending

### RESOLVED — R4 — PUSHLING_VISION.md absorption

**Filed:** 2026-07-02
**Resolved:** 2026-07-02
**Resolution:** `PUSHLING_VISION.md` is absorbed into the OKF bundle and repointed **now**. Physical archival of the original file is **held until Phase 2 exit** — a banner is added to it marking that canon has moved to `docs/`.
**ADR:** pending

---

## CLOSED

<!-- Items fully absorbed into canon (ADR accepted + canon updated). Safe to archive. -->

<!-- (empty until first item completes the full loop) -->
