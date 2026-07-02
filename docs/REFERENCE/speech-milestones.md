---
type: Reference
title: Speech Milestones
description: The two never-repeating speech milestones — the First Word ceremony (Critter stage, the creature's own name, visual) and the First Audible Word (Beast stage, the developer's name, audio-only) — both shipped, both canon.
status: Live
tags: [speech, milestones, first-word]
timestamp: 2026-07-02T00:00:00Z
---

**A note on canon history.** `docs/DECISIONS.md` R3 (filed and resolved
2026-07-02) originally ratified the shipped `FirstWordCeremony.swift`
(Critter stage, the creature's own name) as canon, and characterized
`docs/archive/CREATURE-VOICE-DESIGN.md` §10's alternative design (Beast stage, the
developer's first name, deliberately no visual fanfare) as
"considered-and-rejected history." Code verification during the SP4 wave
found that characterization **incomplete**: the CREATURE-VOICE-DESIGN
alternative was not rejected — it shipped, nearly verbatim, as a **second,
independent milestone** (`VoiceSystem.speakFirstWord()` orchestrated by
`VoiceIntegration.triggerFirstWordCeremony()`), which fires automatically
2.5 seconds after the creature first reaches Beast stage.
`PUSHLING_VISION.md`'s "Audio Voice (TTS)" section and
`docs/archive/plan/phase-5-speech/PHASE-5.md` P5-T2-08 both independently document
this same second milestone under the name "the first audible word" — three
of the four source documents (and the shipped code) agree it exists as
designed. **R3-amended** (ratified 2026-07-02) has since corrected the
"rejected" characterization: canon now documents **both** milestones below
as shipped, complementary canon, neither superseding the other.

# Milestone 1: The First Word (Critter, Own Name, Visual)

Implemented by `FirstWordCeremony.swift`, orchestrated from
`SpeechCoordinator.checkFirstWordCeremony`.

**Trigger conditions** (`FirstWordCeremony.conditionsMet`, all required):

- Stage is exactly Critter
- At least 10 commits eaten (tracked since Critter evolution — see
  [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md) for how commits are
  counted)
- Energy > 30, Contentment > 40
- Currently in autonomous idle (no active touch, no Claude session)
- Has never triggered before (`hasTriggered`, a one-shot in-memory flag on
  the ceremony instance)

**The 5-phase sequence** (5.0s total, verified against the shipped
`Phase` enum and its `phaseTimer` thresholds):

| Phase | Duration | What happens |
|---|---|---|
| Pause | 0.0–0.5s | Walking stops; tail-sway and whisker twitches freeze; breathing continues. |
| Look Up | 0.5–1.3s | Ears snap to `"alert"`; eyes widen to `"wide"`. |
| Hesitation | 1.3–2.3s | Mouth opens/closes twice; a fading `"..."` glyph appears above the creature partway through. |
| The Word | 2.3–3.8s | A `.say`-style bubble appears at the `.above` position: `"...[name]?"` — the question mark is essential, it's asking, not stating. |
| Aftermath | 3.8–5.0s | Two blinks; ears return to neutral; tail-sway and whisker twitches resume. |

**Journal entry**: `{"type":"first_word","word":<name>,"stage":"critter","commits_eaten":N,"timestamp":...}`.

This matches `PHASE-5.md` P5-T1-10 and `PUSHLING_VISION.md`'s "The First
Word" paragraph closely — same 5-second total, same name-as-question
framing, same one-time rule, same Critter-stage trigger. One of the more
faithfully-shipped design sections in this entire domain.

# Milestone 2: The First Audible Word (Beast, Developer's Name, Audio-Only)

Implemented by `VoiceSystem.speakFirstWord()`, triggered from
`VoiceIntegration.triggerFirstWordCeremony()`.

**Trigger**: the creature's stage crosses from below Beast to Beast-or-above
for the first time (`VoiceIntegration.onStageChanged`, comparing
`oldStage < .beast && stage >= .beast`). 2.5 seconds after that transition,
`VoiceSystem.speakFirstWord()` fires if: the voice system is enabled, the
current tier is `.speaking` (Kokoro), `hasSpokenFirstWord == false`, and a
developer name was successfully extracted.

**Name source**: the first space-delimited token of `git config user.name`,
read once at voice-system initialization
(`VoiceSystem.extractDeveloperFirstName`).

**Presentation**: audio only. There is no dedicated visual ceremony beyond
whatever the ambient Beast-evolution animation is already doing — the name
is whispered through Kokoro at `rate × 0.8`, volume `0.21` (0.7× of the 0.3
whisper base — the code's own comment reads `"vision spec: 0.3 base * 0.7"`,
directly matching `PUSHLING_VISION.md`'s "whispered at 0.7x volume"). No
speech bubble is created specifically for this event.

**A gap between design and shipped behavior**: `hasSpokenFirstWord` is a
one-shot in-memory flag with no observed SQLite persistence (a failed
generation resets it to `false` to allow a retry, but a *successful*
ceremony has no corresponding write anywhere in `IPC/` or `Speech/`).
`PHASE-5.md` P5-T2-08 documents a `first_audible_word` journal schema for
this event; a repo-wide search for that string finds no matches outside the
design docs — the daemon never calls `journalLog` for this milestone.
Flagged for the Orchestrator's backlog: this is a code gap (missing journal
write + missing persistence of the one-shot flag), not something a
documentation-only wave can close.

Matches `PUSHLING_VISION.md`'s first-audible-word paragraph and
`PHASE-5.md` P5-T2-08 on stage (Beast), name source (`git config user.name`),
whisper-volume ratio (0.7×), and one-time nature.

# Design Lineage: How Two Milestones Emerged From One Idea

`docs/archive/CREATURE-VOICE-DESIGN.md` §10 (dated 2026-03-14, well before R3's
2026-07-02 ruling) originally proposed a *single* "First Word Moment": Beast
stage (200+ commits, under that document's now-superseded commits-eaten
model — see [growth-stages](/REFERENCE/growth-stages.md)), the developer's
first name, deliberately unceremonious — *"no notification, no fanfare, no
'FIRST WORD UNLOCKED!' achievement popup... just the word, emerging from
babble"* — designed to preserve the uncertainty of "did it just say
something?" That section also ranked alternative first-word choices (the
creature's own name, "hello", a word from a recent commit message, "friend")
before settling on the developer's name for maximum emotional impact.

The shipped system kept this idea almost verbatim as **Milestone 2** above —
same stage, same name source, same whisper treatment, same one-time rule —
and **added** a second, earlier, more theatrical milestone at Critter stage
(**Milestone 1** above) where the creature asks its own name as a question,
per `docs/DECISIONS.md` R3. The two milestones are complementary, not
competing: the Critter milestone is about self-recognition (visual, playful,
uncertain, one week's worth of Critter-stage life away from Beast); the
Beast milestone is about recognizing the developer (audio, intimate,
hushed). Read together, the creature learns its own name before it learns
yours.

# Post-Milestone Progression

- **After the First Word (Critter)**: `PUSHLING_VISION.md` describes the
  creature's own name being added to its Critter vocabulary and said again
  during idle "max once per hour." This wave found no corresponding
  frequency-cap code in `Speech/` — flagged for whichever wave owns the
  autonomous-speech trigger table (behavior-stack / commit-feeding) to
  confirm whether this cap exists elsewhere or is unbuilt intent.
- **After the First Audible Word (Beast)**: no frequency-cap code was found
  either. `VoiceSystem.prerenderCommonPhrases()` includes the creature's
  *own* name (not the developer's) in its per-stage phrase cache starting at
  Critter — the developer's first name is used **only** for the
  first-audible-word ceremony itself and is not otherwise part of the
  routine phrase-cache system observed in code.

# Citations

[1] `Pushling/Sources/Pushling/Speech/FirstWordCeremony.swift`
[2] `Pushling/Sources/Pushling/Speech/SpeechCoordinator.swift` (`checkFirstWordCeremony`)
[3] `Pushling/Sources/Pushling/Voice/VoiceSystem.swift` (`speakFirstWord`, `extractDeveloperFirstName`)
[4] `Pushling/Sources/Pushling/Voice/VoiceIntegration.swift` (`triggerFirstWordCeremony`)
[5] `docs/archive/CREATURE-VOICE-DESIGN.md` §10 — The First Word Moment
[6] `docs/archive/plan/phase-5-speech/PHASE-5.md` — P5-T1-10, P5-T2-08
[7] `PUSHLING_VISION.md` — Speech Evolution: The First Word; Audio Voice (TTS)
[8] `docs/DECISIONS.md` — R3
