---
type: System
title: Creature Invitation System
description: Scheduling, the 6 invitation types, personality-weighted selection, and the offer/accept/timeout lifecycle the creature uses to initiate interactive moments — plus the real-state wiring the selection logic never receives.
status: Live
tags: [touch, invitations, system]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **creature-initiated interactive moments** —
when they fire, which of the 6 types gets picked, and how they resolve if
ignored. Source: `Input/InvitationSystem.swift`, wired only from
`Input/CreatureTouchHandler.swift`.

# Scheduling

Checked once every 60 seconds (`checkInterval`) while no invitation is
currently active. Guard conditions, in order: not sleeping, no mini-game
active, no evolution ceremony active, Claude not AI-directing, activity
within the last 5 minutes (`activeUseWindow`), and at least 20 minutes
(`cooldownDuration`) since the last invitation. If all pass, a probability
roll decides whether one fires: base 3% (`baseProbability`), doubled to 6%
(`droughtProbability`) once more than 40 minutes (`droughtThreshold`) have
passed since the last invitation — and a further +1% for
high-energy creatures (`personality.energy > 0.6`).

**The guard/weighting inputs are never updated with real creature state.**
`InvitationSystem.creatureStage`, `.personality`, `.emotions`,
`.isSleeping`, `.isMiniGameActive`, `.isCeremonyActive`, and
`.isAIDirecting` are all public `var`s intended to be kept in sync by the
owner, but `CreatureTouchHandler` — the only place that holds a reference
to this system — never assigns any of them (grep-verified: no
`invitationSystem.creatureStage = `, `.personality = `, etc. anywhere).
Every one of these fields sits at its type's default for the life of the
process: `creatureStage = .critter`, `personality = .neutral`,
`emotions = .neutral`, and the three booleans all `false`. Practical
consequences:

- Invitation type selection (below) always uses the neutral
  personality/emotion weights — the "high-curiosity creatures favor
  exploration invitations" behavior described in the plan doc cannot
  currently differ creature-to-creature or moment-to-moment.
- Because `isMiniGameActive` and `isCeremonyActive` never flip true, the
  scheduler's own guard against firing during a mini-game or evolution
  ceremony is dead — `CreatureTouchHandler.update(deltaTime:currentTime:)`
  calls `invitationSystem.update(...)` unconditionally, including while
  `miniGameManager.isGameActive` is true, so an invitation could in theory
  begin its setup animation mid-game. (In practice this is rare given the
  low base probability and the 20-minute cooldown, but the guard exists in
  the code for exactly this case and is currently unreachable.)
- `creatureStage` frozen at `.critter` means the stage-gate filter in
  `selectInvitationType()` (below) always evaluates as if the creature
  were Critter-stage, regardless of its real stage — a Beast+ creature
  would never actually see `fishOffering` selected by this mechanism, and
  a Drop-stage creature would incorrectly be offered `ballPush`/`newWord`/
  `stuckOnTerrain` (all gated `>= .critter`) before it should.

This is flagged for `DECISIONS.md`/the Orchestrator as a wiring gap, not a
design question — the fix is straightforward (thread real stage/
personality/emotion/sleep/game-state updates into these properties each
frame or on change) once claimed.

# The 6 Invitation Types

| Type | Minimum Stage | Selection Weight Bias (when personality/emotion inputs are live) |
|---|---|---|
| `ball_push` | critter | +0.5 if `emotions.energy > 60`, +0.3 if `personality.energy > 0.6` |
| `glowing_object` | drop | +0.5 if `emotions.curiosity > 60`, +0.3 if `personality.focus > 0.6` |
| `new_word` | critter | +0.5 if `personality.verbosity > 0.5` |
| `stuck_on_terrain` | critter | fixed weight 0.8 (slightly less common) |
| `fish_offering` | beast | +0.3 if `emotions.contentment > 50` |
| `commit_release` | drop | fixed weight 0.5 |

All types start at a base weight of 1.0 before biases apply; selection is
a weighted random draw over whichever types pass the stage filter (which,
per the wiring gap above, currently always evaluates against `.critter`).
The specific animation/particle detail for each type's setup, offer, and
accept sequences (ball fetch volleys, glowing-object transformation,
vocabulary solidification, etc.) is prescribed in `PUSHLING_VISION.md`'s
"Creature-Initiated Invitations" table and `PHASE-6.md`'s P6-T3-02, but
`InvitationSystem` itself only emits lifecycle events
(`.setup`/`.offer`/`.accepted`/`.selfResolved`/`.timeout`/`.cue`) — the
actual creature animations, particle effects, and reward application for
each type are not implemented in `InvitationSystem` and no consumer of
`onInvitationEvent` was found elsewhere in the searched code. The
lifecycle machinery is real and complete; the six types' individual
payloads are not yet built out.

# Lifecycle

```
setup (1.0s fixed duration)
  -> offered (up to 10.0s offerTimeout; a repeating "cue" every 3.0s)
     -> accepted (human tap on the creature while offered)          -> complete
     -> selfResolved (10s elapsed with no accept)                    -> complete
```

`acceptInvitation()` is the sole entry point for a human response — wired
from [the gesture-response map](/REFERENCE/gesture-response-map.md#tap)'s
tap-on-creature-during-offer case. There is no per-invitation-type accept
gesture beyond a generic tap (the plan doc's per-type accept actions —
flick the ball, tap the glowing object, tap the obstacle, tap the fish,
tap to "release" the commit — are not differentiated in
`InvitationSystem`; any tap on the creature while `.offered` accepts
regardless of type). `completeInvitation()` records `lastInvitationTime`
(the cooldown anchor) and clears `activeInvitation`, whether the
invitation was accepted or self-resolved — both paths reset the 20-minute
cooldown identically.

# Citations

[1] `Pushling/Sources/Pushling/Input/InvitationSystem.swift`
[2] `Pushling/Sources/Pushling/Input/CreatureTouchHandler.swift` (the sole owner — `recordActivity`, `update`, `activeInvitation`, `acceptInvitation` call sites; absence of state-sync assignments)
[3] `PUSHLING_VISION.md` — "Creature-Initiated Invitations" table
[4] `docs/archive/plan/phase-6-interactivity/PHASE-6.md` — P6-T3-01/02/03
[5] [gesture-response map](/REFERENCE/gesture-response-map.md), [mini-games](/SYSTEMS/mini-games.md)
