---
type: System
title: Commit Feeding & XP
description: The character-by-character eating theater a commit triggers, the XP formula and its multipliers, the 16-field post-commit hook payload, rate limiting, and a shipped bug where the live XP-award path bypasses the documented formula.
status: Live
tags: [feeding, xp, commits, hooks]
timestamp: 2026-07-02T00:00:00Z
---

Every commit is food. This concept is the authority on what a commit becomes
once it's eaten: the visible eating theater, the XP it's worth, and the git
hook that captures it in the first place.

# The Post-Commit Hook Payload — 16 Fields, Not 78

`hooks/post-commit.sh` writes one JSON file per commit to
`~/.local/share/pushling/feed/{short_sha}.json` (atomic temp+rename), with
exactly this shape (verified against the live `heredoc`, lines 274–292):

```json
{
  "type": "commit",
  "sha": "a1b2c3d4",
  "full_sha": "a1b2c3d4e5f6...",
  "message": "refactor: extract auth middleware",
  "timestamp": "2026-03-14T09:23:00Z",
  "repo_name": "api-server",
  "repo_path": "/Users/matt/code/api-server",
  "files_changed": 4,
  "lines_added": 42,
  "lines_removed": 26,
  "languages": "php,blade",
  "is_merge": false,
  "is_revert": false,
  "is_force_push": false,
  "branch": "feature/auth-refactor",
  "tags": []
}
```

**16 top-level fields.** A stale `README.md` claim of "78-field JSON
capture" conflated this payload with the unrelated 78-entry
[surprise catalog](/REFERENCE/surprise-catalog.md) — there is no relationship
between the two numbers. `PUSHLING_VISION.md`'s own example payload shows
only 10 of the 16 fields (it omits `type`, `full_sha`, `repo_path`, `tags`,
and originally showed `languages` as an array rather than the
comma-joined string the shipped hook actually emits) — the table above is
corrected against the live script, which is the more complete and more
recently touched of the two sources.

**Detection logic, code-verified:**
- `is_merge` — commit has more than one parent (`git rev-list --parents`).
- `is_revert` — message starts with `Revert `/`revert `/`Revert:`/`revert:`,
  or contains `This reverts commit`.
- `is_force_push` — heuristic: `HEAD@{1}` exists, differs from the new HEAD,
  and is *not* an ancestor of it (`git merge-base --is-ancestor` fails).
- `tags` — any tags pointing at HEAD (`git tag --points-at HEAD`); driving
  release-commit classification below.
- `languages` — extension-to-language mapping via a large `case` statement
  covering ~50 extensions across systems/web/mobile/JVM/data/config/docs
  categories, joined as a comma-separated string (not a JSON array, despite
  what some source docs show).

If the daemon is down when the hook fires, the file simply accumulates in
the feed directory — the hook never fails the commit and never blocks on
the daemon being reachable (`pushling_signal`'s <50ms socket timeout, see
[the hook sensory system](/SYSTEMS/hook-sensory-system.md)).

# The Eating Theater — 4 Phases

Every commit is rendered as a short piece of animated theater on the Touch
Bar (full timings and phase choreography per `PUSHLING_VISION.md`'s "The
Commit-as-Food System" section, animation implementation in
`Pushling/Sources/Pushling/Creature/CommitEatingAnimation.swift` +
`CommitTextNode.swift` — those files own the frame-by-frame rendering
detail; this concept states the phases and the type-specific variations that
drive them):

1. **The Arrival (~2s).** Commit text (`commit# {7-char SHA}: {message}`, up
   to 40 chars) materializes character-by-character at the fog-of-war edge
   with the most visible space, drifting toward the creature.
2. **The Notice (~1.5s).** Ears snap forward, predator crouch, tail-tip
   twitch, a butt-wiggle.
3. **The Feast (3–6s, speed depends on commit type/size).** Characters are
   eaten one at a time from the nearest end — shrink, flash, crumb
   particles, chewing animation between characters, a swallow every 5th
   character.
4. **The Reaction (up to ~12s).** Commit stats float up first, then the XP
   number, then a type-specific speech reaction (see below).

# Commit Type Classification — 17 Types, Priority-Ordered

`CommitTypeDetector.detect` classifies every commit into exactly one of 17
`CommitType` cases (code-verified enumeration — this corrects the source
material's "15 commit-type animation variations," which appears to derive
from the code's own header comment, itself one short of the true count),
checked in this fixed priority order — the first match wins:

| Priority | Type | Trigger | Beast+ Reaction | Critter Reaction | ms/char |
|---|---|---|---|---|---|
| 1 | `forcePush` | `is_force_push` | "WHOOSH!" | "EEK!" | 40 (slam) |
| 2 | `release` | any tag on HEAD | "We shipped it!" | "SHIPPED!" | 400 (celebratory) |
| 3 | `revert` | `is_revert` | "...deja vu" | "huh?" | size-based |
| 4 | `merge` | `is_merge` | "from both sides!" | "wow!" | size-based |
| 5 | `newRepo` | first commit seen from this repo | "NEW FLAVOR!" | "NEW!" | size-based |
| 6 | `hugeRefactor` | total lines > 500 | "I can't move..." | "BIG!" | 60 (goblin mode) |
| 7 | `largeRefactor` | total lines > 200 | "NOM NOM NOM!!" | "NOM!" | 60 (goblin mode) |
| 8 | `empty` | total lines == 0 | "...air?" | "hm?" | size-based |
| 9 | `firstOfDay` | ≥8h since last commit | "MORNING!" | "YAY!" | size-based |
| 10 | `lateNight` | commit hour in 0–4 (midnight–5AM) | "...our secret" | "shh!" | 225 (sleepy) |
| 11 | `test` | language contains `test`/`spec` | "STRONG" | "crunch!" | size-based |
| 12 | `docs` | language in `{md,txt,rst,adoc,tex}` | "ah..." | "hmm!" | 250 (careful) |
| 13 | `css` | language in `{css,scss,less,sass}` | "pretty!" | "ooh!" | size-based |
| 14 | `php` | language is `php` | "classic!" | "mmm!" | size-based |
| 15 | `lazyMessage` | `isLazyMessage(message)` | "...fine." | "meh!" | size-based |
| 16 | `buildConfig` | language in `{yml,yaml,dockerfile,toml,hcl,tf}` or mentions `github`/`ci` | "important." | "hmm!" | 200 (methodical) |
| 17 | `normal` | none of the above | "yum!" | "yum!" | size-based |

**Size-based eating speed** (`CommitTypeDetector.eatingSpeed`, used when a
type doesn't specify its own fixed rate): <20 lines → 200ms/char (polite
nibbles), 20–99 → 150ms (steady munching), 100–199 → 100ms (enthusiastic),
200+ → 60ms (goblin mode).

**Lazy message detection** (`isLazyMessage`): excludes version tags
(`^v\d+`) and `release`/`merge`-prefixed messages first, then flags a
message as lazy if it's a single word under 15 chars, under 5 chars total,
or an exact match against `{fix, wip, stuff, update, changes, misc, asdf,
test, ., tmp, save}`.

# The XP Formula

`XPCalculator.calculate` — the complete, documented formula, matching both
`PUSHLING_VISION.md` and `docs/archive/plan/phase-5-speech/PHASE-5.md` P5-T3-07
exactly:

```
raw = base(1) + lines(min(5, totalLines/20)) + message(2 if msg>20 chars AND not lazy) + breadth(1 if filesChanged>=3)
xp  = round(raw * streakMultiplier * fallowMultiplier * rateLimitFactor)
xp  = max(1, xp)   -- floor of 1, always
```

| Component | Formula | Range |
|---|---|---|
| `base` | always 1 | 1 |
| `lines` | `min(5, (linesAdded+linesRemoved)/20)` | 0–5 |
| `message` | 2 if message > 20 chars and not lazy, else 0 | 0 or 2 |
| `breadth` | 1 if `filesChanged >= 3` | 0 or 1 |
| `streakMultiplier` | `1.0 + min(1.0, streakDays/10.0)` | 1.0x–2.0x |
| `fallowMultiplier` | idle-time table, below | 1.0x–2.0x |
| `rateLimitFactor` | commit-rate table, below | 0.1x–1.0x |

Maximum theoretical: `(1+5+2+1) * 2.0 * 2.0 * 1.0 = 36` XP for a single
commit.

## Fallow Field Bonus (return-commit reward, not a penalty)

| Idle Time Since Last Commit | Multiplier |
|---|---|
| < 30 min | 1.0x |
| 30 min – 2hr | 1.25x |
| 2hr – 8hr | 1.5x |
| 8hr – 24hr | 1.75x |
| 24hr+ | 2.0x (cap) |

The design intent (per the vision doc) is explicitly to reward the return
rather than punish the absence — a creature that hasn't eaten in a day gets
a bigger XP payoff and a more enthusiastic pounce on the commit that finally
arrives, never a decayed or reduced one.

## Rate Limiting

Tracked as a rolling 60-second window of commit timestamps
(`CommitRateLimiter`), applied as a multiplier on top of the base XP —
every commit is still fully logged in the journal regardless of tier:

| Commits in Last 60s | XP Factor |
|---|---|
| 1–5 | 1.0x (full) |
| 6–20 | 0.5x (half) |
| 21+ | 0.1x (tenth) |

This exists to absorb `git rebase`/history-rewrite storms without flooding
the creature with XP or the Touch Bar with animation, while still recording
every commit's full data.

# Known Defect: The Shipped XP-Award Path Bypasses `XPCalculator`

This is a genuine code-internal drift discovered during this wave's
verification, not present in the original survey's driftSignals — flagging
for `DECISIONS.md`/Orchestrator.

`XPCalculator.calculate` (documented above, matching the design spec) is
grep-verified to be called from exactly one place in the entire codebase:
`Pushling/Sources/Pushling/Scene/PushlingScene+Debug.swift` — a debug-only
helper. **The actual production commit-XP-award path never calls it.**
Instead, `GameCoordinator.swift`'s `wireFeedProcessor()` (lines ~459–462, the
callback wired to `feedProcessor.onCommitReceived`) computes XP inline with
a different, incomplete formula:

```swift
let baseXP = max(1, min(5, totalLines / 20)) + 1
let finalXP = max(1, Int(Double(baseXP) * multiplier))
self.totalXP += finalXP
```

This inline calculation:
- Omits the **message bonus** entirely (no message-length or
  lazy-message check).
- Omits the **breadth bonus** entirely (no files-changed check).
- Omits the **streak multiplier** entirely — a 30-day streak awards exactly
  the same XP as a first-ever commit.
- Omits the **fallow multiplier** entirely — the core "reward the return"
  design principle above does not apply to real gameplay, only to the debug
  path.
- Structures its base differently: `max(1, min(5, totalLines/20)) + 1`
  yields a minimum of 2 (vs. `XPCalculator`'s minimum of 1), and the `+1`
  plays the role of `base` but is applied *after* the `min(5,...)` clamp
  rather than added before it — for most inputs this produces the same
  number as `1 + min(5, totalLines/20)`, but it is a second, independently-
  maintained copy of the same arithmetic that has already drifted once (by
  dropping three of six formula terms) and has no test coupling to
  `XPCalculator` to prevent drifting further.
- `multiplier` here is only `CommitRateLimiter.multiplierForNextCommit()` —
  the rate-limit factor. There is no separate streak- or fallow-multiplier
  input to this call site at all.

A second, independent copy of the commit-type XP band also exists at
`HookEventProcessor.handleCommitEvent` (lines ~372–381) with the same
truncated shape, feeding an `eventBuffer.push` entry for
`pending_events` display — meaning **the XP value Claude sees in
`pending_events` and the XP value actually credited to the creature both
come from this same simplified inline formula, not from `XPCalculator`**,
so the two at least agree with each other even though neither matches the
documented design.

**This concept documents `XPCalculator.calculate` as canon** (per DOCS WIN —
it is the version that matches the design intent in both
`PUSHLING_VISION.md` and `PHASE-5.md`, and is the more complete, clearly
deliberately-designed implementation) and records the shipped
`GameCoordinator`/`HookEventProcessor` inline duplicates as the defect to be
corrected — the fix is to have `wireFeedProcessor()` call
`XPCalculator.calculate(commit:streakDays:lastCommitTime:rateLimitFactor:)`
with real streak/fallow inputs instead of hand-rolling a subset of its
arithmetic, and to source `pending_events`' XP display from that same
result. This is a functional bug affecting live gameplay (streak days and
long absences currently earn no XP bonus at all), not merely a
documentation gap, and is out of scope to fix in this documentation wave.

# Language Preference Drift

Every 200 commits (`XPCalculator.shouldShiftLanguagePreference`), the
creature's favorite/disliked language is eligible to shift based on a
rolling window of recent commits' language distribution — full mechanics
(favorite = highest-weighted-XP language, disliked = random pick from
under-5%-represented categories) are `PHASE-5.md` P5-T3-08b's design and are
not verified against a corresponding Swift implementation in this wave —
flagged as unverified rather than asserted as shipped; the `favorite_language`
column exists in `Schema.swift`, but the every-200-commits recalculation
logic was not located during this wave's code checks and should be
confirmed by whichever wave owns `Personality`/`GameCoordinator` in more
depth before being asserted as canon.

# Citations

[1] `PUSHLING_VISION.md` — "The Commit-as-Food System" (lines 398–465), "Git Integration" (lines 1370–1398)
[2] `docs/archive/plan/phase-5-speech/PHASE-5.md` Track 3 (P5-T3-01..10, P5-T3-08b)
[3] `hooks/post-commit.sh` (full read, 319 lines)
[4] `Pushling/Sources/Pushling/Feed/XPCalculator.swift`, `CommitTypeDetector.swift`, `FeedTypes.swift`, `HookEventProcessor.swift`
[5] `Pushling/Sources/Pushling/App/GameCoordinator.swift` (`wireFeedProcessor`, lines ~358–462)
