---
type: ADR
title: "ADR 0003 — Two Complementary First-Word Milestones Are Canon"
description: Canon documents both shipped first-word milestones — Critter's own-name FirstWordCeremony and Beast's developer-name first audible word — as complementary, neither superseding the other. Amends R3's original considered-and-rejected framing.
status: Accepted
tags: [adr, speech, voice, decisions]
timestamp: 2026-07-04T03:07:17Z
---

# ADR 0003 — Two Complementary First-Word Milestones Are Canon

---

## Status

Accepted
Accepted 2026-07-04 (human).

---

## Context

`docs/DECISIONS.md` R3 (filed and resolved 2026-07-02) originally ratified
the shipped `FirstWordCeremony.swift` (Critter stage, the creature's own
name, a scripted 5-second visual ceremony) as canon, and characterized
`docs/archive/CREATURE-VOICE-DESIGN.md` §10's alternative design — Beast
stage, the developer's first name, deliberately unceremonious, audio-only
— as "considered-and-rejected history."

Code verification during the SP4 flesh-out wave found that characterization
**incomplete**: the §10 alternative was not rejected. It shipped, nearly
verbatim, as a second, independent milestone —
`VoiceIntegration.triggerFirstWordCeremony()`
(`Pushling/Sources/Pushling/Voice/VoiceIntegration.swift:85` checks
`stage >= .beast && !voiceSystem.hasSpokenFirstWord`, line 181 fires
`triggerFirstWordCeremony()`, defined at line 198), which calls
`VoiceSystem.speakFirstWord()`
(`Pushling/Sources/Pushling/Voice/VoiceSystem.swift`). This fires
automatically 2.5 seconds after the creature first reaches Beast stage.
`PUSHLING_VISION.md`'s "Audio Voice (TTS)" section and
`docs/archive/plan/phase-5-speech/PHASE-5.md` P5-T2-08 both independently
describe this same second milestone under the name "the first audible
word" — three of the four source documents (plus the shipped code) agree
it exists as designed. Recording R3's original framing as settled canon
would have permanently mischaracterized a shipped, working feature as
abandoned. The human resolved this as R3-amended (2026-07-02, option A).

## Decision

R3's original "considered-and-rejected" framing is dropped. Canon
documents **both** shipped milestones as complementary, neither
superseding the other:

1. **Critter — First Word Ceremony** (`FirstWordCeremony.swift`,
   orchestrated by `SpeechCoordinator.checkFirstWordCeremony`): the
   creature's own name, spoken as a question, a scripted 5-second visual
   ceremony.
2. **Beast — First Audible Word** (`VoiceSystem.speakFirstWord()`,
   triggered by `VoiceIntegration.triggerFirstWordCeremony()`): the
   developer's first name (from `git config user.name`), whispered
   through Kokoro 2.5 seconds after first reaching Beast, audio-only, no
   visual fanfare.

`docs/archive/CREATURE-VOICE-DESIGN.md` §10's alternative design is
absorbed into canon (partly live) as Milestone 2, not preserved as
rejected history. Full detail:
[speech-milestones](/REFERENCE/speech-milestones.md).

## Consequences

Future speech/voice work can cite two independent, non-competing
first-word triggers instead of reconciling one canonical milestone against
a "rejected" design that actually shipped. The trade-off: this ADR
formalizes a known gap the SP4 verification also surfaced — Milestone 2
has no SQLite persistence of its one-shot flag and no journal write
anywhere in `IPC/` or `Speech/` (flagged separately as a code-gap backlog
item, not something this ADR closes). Any future work restoring that
persistence should treat Milestone 2 as already-canon, not as new scope
requiring re-ratification.
