---
type: Feature
title: Interactivity — Unbuilt & Partially-Built Features
description: Designed-but-unshipped Phase 6/7 interactivity features — Track 4 advanced gestures, cooperative mini-game modes, disabled pan/zoom, and the context-menu system — preserved as intent-canon, not pruned as stale.
status: Future
tags: [touch, roadmap, features]
timestamp: 2026-07-02T00:00:00Z
---

Every item below is **designed intent, not abandoned scope** — preserved
in full per the OKF migration's aspirational-preservation rule. Status
markers here follow the framework vocabulary: 📐 planned/designed, not
built; 🚧 partially built. Built systems referenced for contrast are
cross-linked to their `SYSTEMS/`/`REFERENCE/` concepts, which stay
markers-free per the status-discipline rule.

# Live Pan & Zoom

📐 **User-driven camera pan and pinch-zoom.** Fully designed and
implemented in `CameraController` (per-stage pan ranges, zoom ranges,
decay, recenter, focus-point-compensated zoom) but every entry point
(`pan(deltaX:)`, `zoom(delta:centerWorldX:)`, `setZoom(_:animated:)`)
begins with an unconditional early `return` behind a
`// FIXED-VIEWPORT: pan disabled for Day 1 proof-of-life` comment as of
the current build. See
[camera control](/SYSTEMS/camera-and-parallax.md#current-shipped-state-fixed-viewport)
for the full transitional-state writeup, including the sensitivity-tuning
history (0.3x -> 0.02x across two commits) that was mid-flight when pan
was disabled entirely.

🚧 **Multi-touch pinch recognizer.** No `NSMagnificationGestureRecognizer`
and no second, two-finger `NSPanGestureRecognizer` exist in
`TouchBarView.wireGestureRecognizers()` — only a click recognizer and a
single one-finger pan. Even once the `CameraController` pan/zoom `return`s
above are lifted, the AppKit-level input to drive zoom by pinch would need
to be added. See [the touch input pipeline](/SYSTEMS/touch-input-pipeline.md#pipeline).

📐 **`ZoomDetailController` — 4-tier zoom-dependent creature detail.**
Tier thresholds (< 0.8x simplified, 0.8-1.2x normal, 1.2-2.0x enhanced,
> 2.0x maximum, with 0.1 hysteresis) are fully implemented, but the class
is referenced by zero other files in the codebase — a classic
defined-but-unwired system. It cannot do anything useful until zoom is
re-enabled anyway. Full rendering detail belongs to the creature-visual
concept that owns `Creature/`; noted here because it's inert for the same
root reason as pan/zoom above.

# Track 4: Advanced Gestures & Display Modes

None of P6-T4-01 through P6-T4-03/05 exist in code (grep-verified — no
matching classes, no matching `GestureType` cases):

📐 **3-finger display-mode cycling** (Normal -> Stats -> Journal ->
Constellation). `CreatureTouchHandler.handleThreeFinger` is an empty
method body (`// Display mode cycling (handled by scene)`); no
`DisplayModeController` or per-mode overlay exists anywhere in `Scene/`.
The "handled by scene" comment references a consumer that was never
written. (A closely-related but distinct 5-page stats popup *does* ship
today via the P button's `StatsPopupView` — see
[Touch Bar menu patterns](/RESEARCH/touch-bar-menu-patterns.md) — but it's
reached by tapping the P-button menu's "Stats" item, not by a 3-finger
swipe, and it doesn't include the Journal or Constellation modes.)

📐 **4-finger memory postcards.** No `PostcardController` and no 4-finger
`GestureType` case exist — `GestureRecognizer`'s multi-finger cases stop
at `multiFingerTwo`/`multiFingerThree` (see
[the touch input pipeline](/SYSTEMS/touch-input-pipeline.md#gesturerecognizer-the-12-gesture-types)).
A 4-finger swipe is not distinguishable from a 3-finger swipe in the
current recognizer at all.

📐 **Konami Code gesture-sequence easter egg.** Surprise #58 is defined in
`EasterEggSurprises.swift`, but no `KonamiDetector` or any
gesture-sequence-tracking window exists in `Input/` to fire it — the
surprise is data without a trigger.

📐 **Automatic evening campfire spawn.** No time-period-transition spawn
logic exists; campfire is available only as a manual IPC object preset
(`WorldHandlers.swift`) and a debug-menu action — never spawned
automatically at a 40%-per-evening-transition roll as designed.

**Not unbuilt — built differently:** P6-T4-04's co-presence concept (human
touch + Claude MCP command within 100ms) *is* implemented, just not as a
standalone daemon-level `co_presence` pending-event as P6-T4-04
describes — it lives as Surprise #77 "Simultaneous Touch" in
`CollaborativeSurprises.swift` with a 100ms coincidence window. That
surprise's full behavior belongs to whichever concept owns the Surprise
system; noted here only to keep this list from double-counting it as
missing.

# Cooperative Mini-Game Modes

📐 **Claude-cooperative play for all 5 mini-games.** `PHASE-6.md` and
`PUSHLING_VISION.md` both describe Claude-assisted modes — Catch's
tap-plus-`pushling_move` COMBO, Memory's alternating human/Claude symbol
turns, Treasure Hunt's `pushling_speak` directional hints, Rhythm Tap's
notes-from-both-directions, and Tug of War's `pushling_perform({game:
"tug"})` pulls. None exist: `mcp/src/tools/perform.ts`'s
`VALID_BEHAVIORS` has no `game` parameter, and none of the five
`Input/Games/*Game.swift` files reference cooperative state, a Claude
turn, or a combo window. Every shipped game is single-player. Full detail
at [mini-games](/SYSTEMS/mini-games.md#the-5-games).

📐 **Mini-game trigger sources beyond human gesture.** The
`GameTriggerSource` enum has `.creatureInvitation` and `.claudeMCP` cases
alongside `.humanGesture`, but no call site was found passing either of
the first two — games can currently only be started by whatever direct
call invokes `startGame`, not by a creature-presented invitation or an
MCP tool call. See [mini-games](/SYSTEMS/mini-games.md#lifecycle).

# Touch Milestones — Unbuilt Payloads

📐 **`pre_contact_purr` (500 touches).** The milestone unlocks correctly,
but no code anywhere reads `isUnlocked(.preContactPurr)` to produce the
"creature senses an approaching finger and purrs before contact" behavior
it's supposed to gate. See [touch milestones](/SYSTEMS/touch-milestones.md#the-9-milestones).

📐 **"Paying attention" rewards.** `PUSHLING_VISION.md`/`PHASE-6.md`
describe a system that rewards a human tap landing within a short window
of specific autonomous creature behaviors (zoomies, pounce, sneeze, etc.)
with a distinct "we had a moment" sparkle ring. The sparkle visual itself
exists (`TouchParticles.emitMomentRing`), but it has exactly one call
site in the whole codebase — the P-button menu's placeholder `menuPlay()`
action — and no autonomous-behavior-timing-window detection exists
anywhere to actually award this reward during real gameplay.

📐 **Daily-gift world placement.** `PetStreak.checkDailyGift()` correctly
fires `onGiftReady` with a randomly-chosen cosmetic item name once a
7-day streak is active, but no consumer of that callback spawns the
item as a world object — the vision doc's "creature trots to screen
edge, pulls back a small item" sequence has no implementation to attach
to. See [touch milestones](/SYSTEMS/touch-milestones.md#pet-streak-daily-interaction).

📐 **Granular `touch_stats` persistence.** The `touch_stats` table exists
in the schema with a column per gesture type, but `MilestoneTracker` only
ever persists the single `creature.touch_count` total — the per-gesture
breakdown is tracked in memory and lost on quit. See
[touch milestones](/SYSTEMS/touch-milestones.md#persistence-a-table-thats-never-written).

# Invitation System — Unbuilt State Wiring & Payloads

📐 **Real personality/emotion/stage input to invitation selection.**
`InvitationSystem`'s `creatureStage`/`personality`/`emotions`/`isSleeping`/
`isMiniGameActive`/`isCeremonyActive`/`isAIDirecting` properties are never
assigned by their sole owner (`CreatureTouchHandler`) — selection always
runs against frozen defaults. See
[invitation system](/SYSTEMS/invitation-system.md#scheduling).

📐 **Per-invitation-type animation/reward payloads.** The scheduling and
lifecycle machinery (setup/offer/accept/self-resolve/timeout) is complete
and generic across all 6 types, but the type-specific creature animations,
particle effects, and reward application described for each of the 6
invitation types in `PUSHLING_VISION.md` are not implemented — no
consumer of `InvitationSystem.onInvitationEvent` was found. See
[invitation system](/SYSTEMS/invitation-system.md#the-6-invitation-types).

# Context Menu System (`TODO-CONTEXT-MENU-SYSTEM.md`)

📐 **The entire horizontal context-menu design** — `ContextMenuItem`,
`ContextMenuDefinition`, `ContextMenuProvider`, `ContextMenuPresenter`, the
`.contextMenu` `GestureType` case, the 800ms two-phase long-press
disambiguation, and per-target (creature/object/world) menu content — is
**unimplemented**. Grepping `Pushling/Sources/` for `ContextMenu` returns
zero hits. This entire feature was **superseded by a different shipped
design** before it was built: the P-button `MenuStripView` slide-out strip
(Pet/Feed/Play/Stats/About/Sound-toggle buttons) delivers the same
discoverability goal the context-menu TODO was written to solve, via a
persistent AppKit button instead of a long-press gesture. Full research
content and the pattern-comparison analysis that led to the recommended
"Creature-Presented" pattern are preserved at
[Touch Bar menu patterns](/RESEARCH/touch-bar-menu-patterns.md) — that
document is the canonical home for this design; this entry exists only so
the unbuilt status is discoverable from the FEATURES index.

# Citations

[1] `docs/plan/phase-6-interactivity/PHASE-6.md` — Track 4, P6-T3-04/05/06/08/09 cooperative subsections
[2] `docs/plan/TODO-CONTEXT-MENU-SYSTEM.md`
[3] `PUSHLING_VISION.md` — Touch Interactions, Human Milestones, Creature-Initiated Invitations, Mini-Games
[4] [camera control](/SYSTEMS/camera-and-parallax.md), [touch milestones](/SYSTEMS/touch-milestones.md), [invitation system](/SYSTEMS/invitation-system.md), [mini-games](/SYSTEMS/mini-games.md), [Touch Bar menu patterns](/RESEARCH/touch-bar-menu-patterns.md)
