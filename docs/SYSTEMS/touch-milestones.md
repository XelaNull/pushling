---
type: System
title: Touch Milestones
description: The 9 touch-count milestones that gate gestures and cosmetic effects, the unlock ceremony, and daily pet-streak tracking — including a schema table the tracker never actually writes to.
status: Live
tags: [touch, milestones, progression]
timestamp: 2026-07-02T00:00:00Z
---

This is the authority for **human progression through touch** — milestone
IDs, thresholds, what each gates, the unlock ceremony, and daily-streak
tracking. It does not own gesture classification (see
[the touch input pipeline](/SYSTEMS/touch-input-pipeline.md)) or per-gesture
response detail (see [the gesture-response map](/REFERENCE/gesture-response-map.md)).
Source: `Input/MilestoneTracker.swift`, `Input/UnlockCeremony.swift`,
`Input/PetStreak.swift`.

# The 9 Milestones

`MilestoneID` (`Input/MilestoneTracker.swift:12-21`):

| ID | Threshold | Gates |
|---|---|---|
| `first_touch` | 1 total touch | Unlock ceremony banner only (no gameplay gate) |
| `finger_trail` | 25 total touches | Sparkle trail on drag (`emitFingerTrailParticle`) |
| `petting` | 50 total touches | The `pettingStroke` gesture (see [gesture-response map](/REFERENCE/gesture-response-map.md#petting-stroke)) |
| `laser_pointer` | 100 total touches | Laser pointer mode on drag |
| `first_mini_game` | first game completion (not a touch count — checked via `recordSpecial(.miniGameComplete)`) | — (ceremony only; toybox-access framing from the plan doc isn't implemented as a gameplay gate) |
| `belly_rub` | 250 total touches | Two-finger-on-creature belly rub |
| `pre_contact_purr` | 500 total touches | **Not implemented** — the milestone unlocks and its threshold check exists, but no "creature purrs before contact" behavior reads `isUnlocked(.preContactPurr)` anywhere in the touch/creature code (grep-verified). See [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md). |
| `touch_mastery` | 1000 total touches | `MilestoneTracker.particleMultiplier` returns 2.0 instead of 1.0 — read by `emitHeartParticle` (tap-on-creature hearts). Not wired into any other particle emitter (petting purrs, laser trail, pounce sparkles, object-tap sparkles all use fixed particle counts regardless of this milestone). |
| `gentle_wake` | not a touch count — first successful `WakeUpBoop` completion (`recordSpecial(.gentleWake)`) | Ceremony only. See [the 3-tap wake sequence](/REFERENCE/gesture-response-map.md#wake-up-boop--the-3-tap-sequence) for what "successful completion" actually requires. |

The vision doc and `PHASE-6.md` additionally describe a `pet_streak_7`
milestone (7-day streak unlocks a daily-gift behavior) as part of this
same enum; in code, the daily-gift mechanic is real but lives entirely in
`PetStreak` (below) and is **not** one of the 9 `MilestoneID` cases —
`gentle_wake` occupies the ninth slot instead. Both mechanics exist; they
just aren't organized under one milestone list the way the plan doc
describes.

# Checking & Unlocking

Every `recordGesture(_:)` and `recordSpecial(_:)` call increments
`stats.totalTouches` and immediately calls `checkMilestones()`, which
scans all `MilestoneID.allCases` and unlocks any whose `touchThreshold` is
now met. There is no separate periodic re-check beyond this per-touch
scan — the "batch write every 30 seconds, AND immediately after any touch
event" cadence from the plan doc collapses to: **milestone unlocking is
always immediate**; only the SQLite *write* is what's actually batched
(`update(deltaTime:)`, `flushInterval = 30.0`, dirty-flag gated).

Unlocking calls `onMilestoneUnlocked?(milestone)`, which
`CreatureTouchHandler` wires to `UnlockCeremony.play(milestone:in:)` — a
non-blocking 3.5s sequence: a 0.3s white flash + 0.5pt screen shake, a
Gilt banner sliding in from the right showing the milestone's display
name (2.0s hold), a demo-request callback fired 0.5s after the flash
(intended to trigger the creature performing the newly-unlocked gesture —
`onDemoRequest` exists but has no wired consumer in the code searched for
this concept), and a 0.7s fade-out dismiss. `extraCelebration(in:)` is
available for an in-ceremony bonus sparkle burst if the human performs the
gesture mid-ceremony, but nothing currently calls it either.

# Persistence: A Table That's Never Written

The schema defines a full `touch_stats` table
(migration v3) with one column per gesture type — see
[the touch_stats schema](/DATA_MODELS/state-database-schema.md#touch_stats).
**`MilestoneTracker` never reads or writes this table.** Its
`loadFromDatabase()`/`flushToDatabase()` only touch a single column,
`creature.touch_count`, for the running total; the per-gesture breakdown
fields on `TouchStats` (`taps`, `doubleTaps`, `tripleTaps`, `longPresses`,
`sustainedTouches`, `drags`, `pettingStrokes`, `flicks`, `rapidTaps`,
`boops`, `bellyRubs`, `handFeeds`, `laserPointerSeconds`,
`dailyInteractionStreak`, `lastInteractionDate`) are tracked in memory for
the lifetime of the process and then **discarded on quit** — they are
never persisted to the `touch_stats` table that exists specifically to
hold them. `dailyInteractionStreak`/`lastInteractionDate` are tracked
redundantly in `TouchStats` too, but the persisted daily-streak value
actually used elsewhere comes from the separate `PetStreak` class below
(`creature.streak_days`/`streak_last_date`), not from `touch_stats`.

This is a genuine defined-but-unwired schema table, not a naming drift —
flagged for the Orchestrator/`DECISIONS.md`: either wire `MilestoneTracker`
to persist the granular counters `touch_stats` was built to hold, or
retire the table.

Milestone *unlock* state does persist correctly, in the shared
`milestones` table (`category = 'touch'`), one seeded row per ID with
`earned_at`/`ceremony_played` columns — see
[the milestones schema](/DATA_MODELS/state-database-schema.md#milestones).

# Pet Streak (Daily Interaction)

`PetStreak` is a separate class, not part of `MilestoneTracker`. A "pet
day" is any calendar day with at least one `recordInteraction()` call
(fired from every gesture, same as milestone tracking). Consecutive-day
logic: if the last interaction was yesterday, `streakDays += 1`; if it was
any earlier day, the streak resets to 1; a same-day repeat is a no-op.
Persisted to `creature.streak_days`/`creature.streak_last_date` after
every change (not batched). A separate `midnightCheck()` method exists to
break the streak if a full day is missed without an interaction, but nothing
in the searched code calls it on a timer — it is present but not
demonstrably wired to fire automatically at midnight; the streak would
otherwise only correct itself lazily, the next time `recordInteraction()`
runs and compares against `yesterdayString()`.

At `streakDays >= 7` (`giftStreakThreshold`), `hasGiftStreak` is true and
the first interaction of a new day triggers `checkDailyGift()` — a random
pick from a 20-item cosmetic pool (`tiny_flower`, `colored_pebble`, ...,
`dried_flower`, matching the vision doc's list exactly) via
`onGiftReady`. `dailyGiftGiven` resets false on every new day so the gift
fires at most once per day. `CreatureTouchHandler.gestureRecognizer(_:didRecognize:)`
checks `petStreak.hasGiftStreak` and calls `checkDailyGift()` on every
gesture once the streak is active — the actual placement of the gifted
item in the world (per the vision doc's "creature trots to screen edge,
pulls back a small item" sequence) is not implemented in the code
searched for this concept; `onGiftReady` fires with the item name but no
world-object-spawn consumer was found.

# Citations

[1] `Pushling/Sources/Pushling/Input/MilestoneTracker.swift`
[2] `Pushling/Sources/Pushling/Input/UnlockCeremony.swift`
[3] `Pushling/Sources/Pushling/Input/PetStreak.swift`
[4] `Pushling/Sources/Pushling/State/Schema.swift` (`createTouchStatsTable`, `createMilestonesTable`)
[5] [state database schema](/DATA_MODELS/state-database-schema.md) — `touch_stats`, `milestones`
[6] [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md) — `pre_contact_purr` behavior, gift world-placement
