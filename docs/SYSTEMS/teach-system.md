---
type: System
title: Teach System
description: Claude choreographs multi-track body-part animations that persist as SQLite-backed taught behaviors, gain mastery through repeated performance, and can spontaneously breed into self-taught hybrids.
status: Live
tags: [creation, teach, choreography, mastery, behavior-breeding]
timestamp: 2026-07-02T00:00:00Z
---

Claude is a choreographer, not an animator — the Teach System composes new
tricks entirely from the creature's existing animation vocabulary (body-part
poses, expressions, particles, sound cues). Nothing taught requires new
rendering code. This concept owns the `pushling_teach` tool's workflow,
choreography format, mastery progression, and behavior breeding. It does
**not** own the wire-level parameter/action tables (see
[the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md)) or the idle
behavior stack that ultimately performs a taught trick (see
[the behavior stack](/SYSTEMS/behavior-stack.md)).

# Choreography Notation

A behavior is a multi-track timeline. **16 named tracks** are valid:
`body`, `head`, `ears`, `eyes`, `tail`, `mouth`, `whiskers`, `paw_fl`,
`paw_fr`, `paw_bl`, `paw_br` (the four paws independently), `particles`,
`aura`, `speech`, `sound`, `movement` — verified against `VALID_TRACKS` in
both `mcp/src/tools/teach.ts` and `mcp/src/tools/teach-handlers.ts`. Each
track is an array of keyframes (`{t, pose|state|action, ...}`); omitted
tracks inherit autonomous behavior (breathing never stops). A single
behavior may use **at most 13 of those 16 tracks** —
`ChoreographyParser.swift:209-212` rejects a `tracksDict.count > 13` with
"Maximum 13 tracks per behavior." Most tricks use 3–6.

`PUSHLING_VISION.md`'s "13 animatable tracks" framing conflates two
different numbers: the vocabulary has grown to 16 named tracks (the four
paws split out independently), while 13 remains the actual per-behavior
cap. This concept documents both numbers as what they are — a 16-name
vocabulary, a 13-track ceiling per behavior — rather than repeating the
doc's single "13 tracks" claim.

Values are semantic, not mechanical (`"ears": "perk"`, never a raw
rotation), and the daemon fuzzy-matches near-miss values rather than
rejecting them. Every performance is filtered through the creature's
personality axes before playback — a calm creature performs the same
choreography slower and more deliberately than a hyperactive one.

# The 7 Actions and the Compose → Commit Workflow

`pushling_teach` exposes exactly 7 actions (`VALID_ACTIONS` in
`mcp/src/tools/teach.ts`): `compose`, `preview`, `refine`, `commit`, `list`,
`remove`, `reinforce`.

1. **`compose`** — validates `name` (unique), `category` (one of 6, below),
   `duration_s` (0.5–15.0s), and `tracks` against the vocabulary above, then
   sends a draft to the daemon. `stage_min` defaults to `critter` if
   omitted. The MCP layer enforces `MAX_TAUGHT = 30` and duplicate-name
   checks client-side before ever reaching the daemon.
2. **`preview`** — plays the current draft once on the Touch Bar; no
   persistence.
3. **`refine`** — re-sends `compose` with the same name to replace the
   working draft; there is no separate refine-in-place mechanism daemon-side
   (`CreationHandlers.swift`'s `refine` case is a no-op note pointing back
   at `compose`).
4. **`commit`** — the daemon re-parses the choreography via
   `ChoreographyParser.parse(_:)` and, on success, upserts into
   `taught_behaviors` (`ON CONFLICT(name) DO UPDATE`), registers the
   behavior with the runtime engine (`gc.registerTaughtBehavior`), and logs
   a `teach`-type journal row. A 3-second learning ceremony plays (creature
   focuses, attempts clumsily, then lights up).
5. **`list`** — read-only from SQLite via the MCP `StateReader`; no daemon
   round-trip required except to attach any pending events.
6. **`remove`** — deletes the `taught_behaviors` row and its `teach`-type
   journal entries, unregisters the runtime behavior.
7. **`reinforce`** — adds **+0.15 strength** (capped at 1.0), matching the
   nurture strength model (see [the nurture system](/SYSTEMS/nurture-system.md)).

**6 categories** (`VALID_CATEGORIES`, also the `taught_behaviors.category`
CHECK constraint in `Schema.swift`): `playful`, `affectionate`, `dramatic`,
`calm`, `silly`, `functional`.

**Capacity: 30 active taught behaviors** (`MAX_TAUGHT`), enforced both at
`compose` (client-side, MCP) and at `commit` (server-side check against the
live SQLite count) — a double gate, so a race between two rapid composes
still can't exceed 30.

# Triggers

A behavior's `triggers` object accepts `idle_weight` (0.0–1.0, default 0.3),
`on_touch` (boolean), and `emotional_conditions` (per-axis `{min, max}`).
Committed triggers additionally persist `cooldown_s`, `on_commit_type`, and
`contexts` when present (`CreationHandlers.serializeTriggers`). Idle
selection itself is gated by the **`IdleRotationGovernor`**, which enforces
an **80% pure-autonomous / 20% taught-or-special** ratio and a hard ceiling
of **3 taught-behavior performances per hour**
(`IdleRotationGovernor.swift:2-3,20,32`) — a taught trick with a high
`idle_weight` competes for a slot within that 20%, it does not bypass the
ratio.

# 4-Tier Mastery System

Mastery is tracked per-behavior by performance count, independent of the
nurture-style strength/decay model (mastery never decays):

| Tier | Performances | Timing Jitter | Fumble Chance | Character |
|---|---|---|---|---|
| **Learning** | 0–2 | ±20% | 30% per keyframe | Clumsy, false starts |
| **Practiced** | 3–9 | ±10% | 15% | Smoother, occasional overshoot |
| **Mastered** | 10–24 | ±3% | 0% | Clean, personality flair added |
| **Signature** | 25+ | ±1% | 0% | Embellished, part of identity |

Verified against `MasteryTracker.swift`'s `MasteryLevel` enum
(`timingJitter`, `fumbleProbability` per case) — figures match
`PUSHLING_VISION.md`'s table exactly. `dreamEligible` is `true` at Mastered
and above.

**Drift flagged:** the MCP display layer's `masteryLabel()`
(`mcp/src/tools/teach.ts:159-167`) maps raw levels 0–3 to
`"learning"/"familiar"/"practiced"/"mastered"` — this does **not** match
the canonical tier names above (`Learning/Practiced/Mastered/Signature`).
A behavior at Signature mastery (level 3) would be mislabeled `"mastered"`
in a `pushling_teach("list")` response, and level 1 (`Practiced`, per the
daemon) is mislabeled `"familiar"`. This is an MCP-side display bug, not a
documentation question — flagged for `DECISIONS.md`/the Orchestrator; the
daemon's `mastery_level` column (0–3) and `MasteryLevel.displayName` are the
canonical source, `teach.ts`'s `masteryLabel()` should be corrected to
match them.

# Dream Integration — Designed, Not Wired

`PUSHLING_VISION.md` states "mastered tricks replay during sleep at 0.5x
speed with a ghostly render filter." The selection half of this exists —
`MasteryTracker.selectDreamBehavior()` weights Mastered/Signature behaviors
(Signature at 3x weight) and picks one — but a repo-wide search found **no
call site** for `selectDreamBehavior()` anywhere else in
`Pushling/Sources`. The live `DreamEngine` (see
[journal & dreams](/REFERENCE/journal-and-dreams.md)) generates a
pattern-based text summary and a small personality drift; it does not
invoke behavior playback at all. This is a **defined-but-unwired** gap:
the mastery-weighted selection logic is built and ready, but nothing
connects it to the dreaming state. Preserved here as intent-canon (📐 would
apply if this were a FEATURES/ concept); flagged for the Orchestrator as a
discovered gap, not a regression to fix silently.

# Behavior Breeding

When two taught behaviors perform within **30 seconds** of each other
(`BehaviorBreeding.breedingWindow`), there is a **5% chance**
(`breedingChance`) of a hybrid: the hybrid takes trigger conditions from one
parent and movement elements from the other, filtered through personality,
then stored as `source = 'self_taught'` with its own mastery track starting
at Learning. Hybrids count toward the 30-behavior cap. **Maximum 5
self-taught behaviors** at a time (`BehaviorBreeding.maxHybrids`); once at
cap, breeding attempts are skipped and logged, not queued. Hybrids decay
**faster** than Claude-taught behaviors — **0.03/day**
(`BehaviorBreeding.hybridDecayRate`) vs. the standard nurture decay tiers —
unless Claude reinforces one, at which point it is treated as a regular
taught behavior for decay purposes. All constants verified against
`BehaviorBreeding.swift:44,47,50,53`, matching the vision doc exactly.

# Schema

`taught_behaviors` (`Pushling/Sources/Pushling/State/Schema.swift:185-210`):

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `name` | TEXT UNIQUE NOT NULL | |
| `category` | TEXT CHECK | one of the 6 categories above |
| `stage_min` | TEXT CHECK | default `'egg'`; one of the 6 growth stages |
| `duration_s` | REAL NOT NULL | |
| `tracks_json` | TEXT NOT NULL | serialized keyframes per track |
| `triggers_json` | TEXT NOT NULL | serialized trigger config |
| `mastery_level` | INTEGER CHECK 0–3 | see mastery table above |
| `performance_count` | INTEGER DEFAULT 0 | drives `mastery_level` |
| `strength` | REAL CHECK 0.0–1.0 DEFAULT 0.5 | nurture-style strength, +0.15 per reinforce |
| `reinforcement_count` | INTEGER DEFAULT 0 | |
| `source` | TEXT CHECK | `'taught'` or `'self_taught'` |
| `parent_a`, `parent_b` | TEXT | set for hybrids |
| `created_at`, `last_performed_at`, `last_decayed_at` | TEXT | |

Note the schema's `stage_min` default is `'egg'`, not `'critter'` — the
`'critter'` default the vision doc and `teach.ts` describe is applied by
the *client* (`compose`'s `stage_min ?? "critter"`) before the row is ever
written; the column itself has no functional default requirement.

# Examples

```json
{
  "action": "compose",
  "name": "roll_over",
  "category": "playful",
  "duration_s": 3.0,
  "stage_min": "critter",
  "tracks": {
    "body": [
      {"t": 0.0, "pose": "crouch"},
      {"t": 0.5, "pose": "roll_back"},
      {"t": 1.8, "pose": "stand"}
    ],
    "tail": [
      {"t": 0.0, "action": "poof"},
      {"t": 0.5, "action": "wag", "speed": "fast"}
    ]
  },
  "triggers": {"idle_weight": 0.3, "on_touch": true}
}
```

# Citations

[1] `mcp/src/tools/teach.ts` (`VALID_ACTIONS`, `VALID_CATEGORIES`, `VALID_TRACKS`, `MAX_TAUGHT`, `masteryLabel`)
[2] `mcp/src/tools/teach-handlers.ts` (`handleCompose`, `handleCommit`, `handleReinforce` — client-side validation and caps)
[3] `Pushling/Sources/Pushling/IPC/CreationHandlers.swift` (`handleTeach*`, `serializeTracks`, `serializeTriggers`)
[4] `Pushling/Sources/Pushling/Behavior/ChoreographyParser.swift` (13-track cap, keyframe validation)
[5] `Pushling/Sources/Pushling/Behavior/MasteryTracker.swift` (`MasteryLevel`, `selectDreamBehavior`)
[6] `Pushling/Sources/Pushling/Behavior/BehaviorBreeding.swift` (breeding window/chance, hybrid cap/decay)
[7] `Pushling/Sources/Pushling/Behavior/IdleRotationGovernor.swift` (80/20 ratio, 3/hour cap)
[8] `Pushling/Sources/Pushling/State/Schema.swift` (`taught_behaviors` table)
[9] `PUSHLING_VISION.md` — The Teach System; Behavior Breeding
