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

📐 **Fallback zoom input — two-finger same-direction drag.** Alongside the
pinch recognizer above, the design also specifies a drag-based zoom
fallback: 200pt of two-finger drag travel = 1.0 change in `zoomLevel`;
dragging left zooms out, dragging right zooms in. No `twoFingerDrag`
`GestureType` case exists (`GestureRecognizer` stops at `multiFingerTwo`/
`multiFingerThree`, which don't carry drag distance), so this mapping has
no code to attach to today. It's pan/zoom intent-canon like the pinch
recognizer above — a second, independent path to the same
`CameraController.zoom(delta:centerWorldX:)` entry point once one exists.

📐 **`ZoomDetailController` — 4-tier zoom-dependent creature detail.**
Fully implemented (`Creature/ZoomDetailController.swift`) but referenced by
zero other files in the codebase — a classic defined-but-unwired system; it
cannot do anything useful until zoom is re-enabled. Four tiers, hysteresis
0.1 (a tier only changes once zoom crosses the boundary by more than 0.1,
preventing flicker at the edge):

| Zoom | Tier | Whiskers | Inner Ears | Toe Pads (all paws) | Toe Beans (4/front paw) | Ear Tufts | Nose Highlight |
|---|---|---|---|---|---|---|---|
| < 0.8x | Simplified | hidden (alpha 0) | hidden (alpha 0) | hidden (alpha 0) | hidden | hidden | hidden |
| 0.8-1.2x | Normal | alpha 1.0 | alpha 0.4 | alpha 0.3 | hidden | hidden | hidden |
| 1.2-2.0x | Enhanced | alpha 1.0 | alpha 0.5 | alpha 0.45 | hidden | hidden | hidden |
| > 2.0x | Maximum | alpha 1.0 | alpha 0.55 | alpha 0.5 | alpha 0.35 (Soft-Ember) | alpha 0.5 (Ash outline) | alpha 0.3 (Bone) |

The Maximum-tier nodes (toe beans, ear tufts, nose highlight) are
**lazily created** the first time zoom crosses into that tier
(`createMaxDetailNodes()`, gated `stage >= .critter` — an egg/drop-stage
creature has no paw/ear/nose sub-nodes to attach detail to yet) and then
just toggled by alpha afterward. Toe bean size scales with stage (2.0pt
paw size below Beast, 2.5pt at Beast+). This entire mechanism composes
with, but is independent from, [counter-scaling](#live-pan--zoom) below —
one changes *which* sprite parts are visible, the other changes the
creature's overall *scale*.

📐 **Creature counter-scaling under zoom.** Designed to keep the creature
from clipping the 30pt bar as zoom increases: below a "comfortable" size
(26pt actual height) the creature scales linearly with zoom; past that
point growth decelerates via logarithmic compression, capped hard at 28pt
(leaving a 2pt margin on the 30pt bar). The designed formula:
`scaleFactor = cappedZoom / worldZoom`, applied as
`creature.setScale(depthScale * scaleFactor)`. No `cappedZoom`,
`worldZoom`, or any counter-scale code exists anywhere in the codebase
(grep-verified) — `PushlingScene.swift`'s real `depthScale = 1.0 - z * 0.35`
is unrelated depth-based scaling, not zoom-related, and would need to
compose with this mechanism rather than be confused for it. Like
`ZoomDetailController` above, this is inert until the `CameraController`
zoom `return`s are lifted — it's designed to activate the moment zoom
becomes user-driven again. See
[camera control](/SYSTEMS/camera-and-parallax.md) for the zoom range this
would apply against.

📐 **Zoom-compensated hit-testing.** Once pan/zoom re-enables, a raw
view-space touch needs an extra conversion step to land on the right
world-space target: `worldX = camera.effectiveWorldX + (viewX -
sceneCenter) / max(zoom, 0.1)`. The design's own caution: at high zoom,
small finger movements map to large world distances, which could cause
hit-test misses on small objects (a 2pt finger wobble at 3x zoom is a
6pt+ world-space miss). No such conversion exists in code today (grep of
`Input/*.swift` and `PushlingScene.swift`) — [the touch input
pipeline](/SYSTEMS/touch-input-pipeline.md#touchtracker-coordinate--state-tracking)
documents only the current normalized-to-scene (1085x30) conversion, which
has no zoom term because zoom is disabled. This is the same class of
unbuilt pan/zoom design intent as the rest of this section, not a dropped
system-fact — it has no live counterpart to correct or contradict.

📐 **Sage+ temporal vision (2-finger swipe).** Beyond the standard
2-finger world-pan behavior (see [the gesture-response
map](/REFERENCE/gesture-response-map.md#two-finger-dispatched-on-lift) for
what's actually wired there today), the design gives Sage+ creatures an
extra layer on the same gesture: swiping left triggers a "temporal rewind"
vision — the sky gradient shifts backward in time with a faded ghost of
the previous weather/lighting state overlaid — while swiping right shows a
"temporal forward" prediction of the near future, based on the circadian
cycle. During either, the whole scene takes on a Dusk tint at alpha 0.3;
the effect holds only as long as both fingers stay down and reverts
immediately on release. No trace of this exists in code
(grep-verified: `temporal`/`rewind`/`forward vision` return zero hits
outside the archive) — a full standard 2-finger world-pan hasn't shipped
either (see [Live Pan & Zoom](#live-pan--zoom) above), so this Sage+
extension has nothing built to layer onto yet.

# Basic Gesture Responses — Creature-Side Gaps

Three basic gesture responses from `PHASE-6.md`'s foundational
gesture-to-creature table have a built *object/world* half but no built
*creature* half — the event either has no listener at all, or there's no
event in the first place:

📐 **Tap left/right of creature — walk-to-point.** Tapping empty world
space near (not on) the creature was designed to make it walk to the
touch point, occasionally overshooting and stumbling, tail up, trotting.
[The gesture-response map](/REFERENCE/gesture-response-map.md#tap)'s
World row only shows the HUD overlay — there is no world-tap-near-creature
case anywhere in `CreatureTouchHandler.handleTap` (grep-verified for
`walk`/`overshoot`/`stumble`). This specific "tap to move" mechanic *does*
exist, but only inside `CatchGame.handleTap` as mini-game input (see
[mini-games](/SYSTEMS/mini-games.md#the-5-games)) — it was never
generalized to ordinary world-tap gameplay.

📐 **Tap-on-object — creature investigation.** The object side of a tap is
fully built (bounce, sparkle, 30s cooldown — see [the gesture-response
map](/REFERENCE/gesture-response-map.md#tap)), but `ObjectInteraction`'s
`onObjectEvent` callback — which would carry the `.tapped` event to a
creature response — is never assigned anywhere in the codebase
(grep-verified: zero `objectInteraction.onObjectEvent = ` call sites). The
designed creature response the event was meant to drive: ears perk toward
the object (0.15s), head turns (0.2s), the creature trots over (1-3s
depending on distance), then a personality-dependent investigation on
arrival — high curiosity gets an extended exam (1s sniff, 0.5s paw,
1s circle), low curiosity a brief glance, and toy-type objects (ball,
yarn) may trigger autonomous play.

📐 **Object flick — creature chase response.** `ObjectInteraction.flickObject`
fires an `.creatureChase(objectId:targetX:)` event on every flick (see
[the gesture-response map](/REFERENCE/gesture-response-map.md#flick) for
the built physics side), but — same root cause as tap-on-object above —
`onObjectEvent` has no listener, so the event reaches nobody. The designed
response: if the creature sees the flicked object (within 200pt, facing
toward it), it chases at run speed; on arrival, a personality-dependent
reaction — high energy bats it further (a second impulse at 50% of the
original), high focus examines it (1s sniff), low energy sits next to it
and looks at the human, high discipline carries it back to where it was
(fetch).

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
swipe, and it doesn't include the Journal or Constellation modes.) The
designed per-mode content, none of it built:

| Mode | Content | Visual |
|---|---|---|
| Normal (default) | living world, creature, weather, no HUD | standard scene |
| Stats | stage, XP, streak, satisfaction, curiosity, contentment, energy, mutation badges, touch count | Ash-tinted bottom overlay panel, creature dimmed to 60% |
| Journal | last 10 journal entries, scrolling, brief summaries + timestamps | scrolling Bone-on-Void text list, creature walks in background |
| Constellation | each milestone/achievement rendered as a star in a procedural map, connected by Ash lines | full-screen star map, creature at center |

Swipe left = next mode, swipe right = previous; any single tap returns to
Normal; each mode would fade in/out over 0.3s and read its content live
from SQLite (journal, milestones, creature state) rather than being
precomputed.

📐 **4-finger memory postcards.** No `PostcardController` and no 4-finger
`GestureType` case exist — `GestureRecognizer`'s multi-finger cases stop
at `multiFingerTwo`/`multiFingerThree` (see
[the touch input pipeline](/SYSTEMS/touch-input-pipeline.md#gesturerecognizer-the-12-gesture-types)).
A 4-finger swipe is not distinguishable from a 3-finger swipe in the
current recognizer at all. The designed content: each postcard is a
first-person snapshot generated lazily (on swipe, not precomputed) from a
milestone journal entry — hatch/first-word/first-mutation/evolve-type
entries, rendered as a full-Touch-Bar card (gradient background + wrapped
`SKLabelNode` text, horizontal carousel-style slide transitions), capped
at 50 stored postcards (oldest archived beyond that). Example first-person
text from the design doc, illustrating the intended voice:
- *"I opened my eyes for the first time. Everything was dark and warm."*
- *"I said my name. '...Zepus?' I wasn't sure it was mine yet."*
- *"The first storm. I hid under a mushroom and shivered."*

Single tap exits back to Normal mode.

📐 **Konami Code gesture-sequence easter egg.** Surprise #58 is defined in
`EasterEggSurprises.swift`, but no `KonamiDetector` or any
gesture-sequence-tracking window exists in `Input/` to fire it — the
surprise is data without a trigger. The designed detector: a 10-gesture
sliding window matching Up-Up-Down-Down-Left-Right-Left-Right-Tap-Tap,
where Up/Down/Left/Right are directional swipes across the Touch Bar
(bottom-to-top, top-to-bottom, right-to-left, left-to-right respectively)
and Tap is a single tap on the creature; each qualifying gesture must land
within 1.5s of the previous one or the window resets. On a full match:
an 8-bit triumphant fanfare via `afplay`, the creature does a full lap of
the Touch Bar trailing rainbow particles with a retro-pixel flash effect,
and the match is logged to the journal as an easter-egg achievement.

📐 **Automatic evening campfire spawn.** No time-period-transition spawn
logic exists; campfire is available only as a manual IPC object preset
(`WorldHandlers.swift`) and a debug-menu action — never spawned
automatically at a 40%-per-evening-transition roll as designed. The
designed trigger/behavior: fires on the "evening"/"late\_night" time-period
transition, only if no campfire object already exists and the creature is
Beast+; visual is an Ember glow with a tiny flame particle emitter and a
warm light radius (Gilt @ alpha 0.08, 20pt radius); the creature would
gravitate toward it and sit watching the flames (the `watching` interaction
template); with Claude connected, the campfire would enable a "campfire
stories" surprise variant (creature stares into the fire, thought bubbles
surfacing memories). It's marked `temporary: true` and exempt from the
12-object persistent-object cap, fading out over 30s at dawn.

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

📐 **Game discovery — pre-unlock teasers.** Before a game unlocks, the
design has the creature hint at it during idle so it's "a mystery until
unlocked" rather than a silent locked slot: Catch is teased by the
creature dropping a star and looking expectant; Memory by showing symbols
in sequence; Treasure Hunt by digging while looking at the human; Rhythm
Tap by musical notes floating past. No such idle-teaser behavior exists
anywhere in `MiniGameManager` or the Autonomous layer (grep-verified) —
locked games today are simply invisible until their play-count threshold
is crossed. See [mini-games](/SYSTEMS/mini-games.md#the-5-games).

# Touch Milestones — Unbuilt Payloads

📐 **`pre_contact_purr` (500 touches).** The milestone unlocks correctly,
but no code anywhere reads `isUnlocked(.preContactPurr)` to produce the
"creature senses an approaching finger and purrs before contact" behavior
it's supposed to gate. See [touch milestones](/SYSTEMS/touch-milestones.md#the-9-milestones).

📐 **"Paying attention" rewards.** `PUSHLING_VISION.md`/`PHASE-6.md`
describe a system that rewards a human tap landing within a short window
of specific autonomous creature behaviors with a distinct "we had a
moment" sparkle ring (Gilt particles, 10pt radius, 0.3s — visually
distinct from the ordinary tap response). The sparkle visual itself
exists (`TouchParticles.emitMomentRing`), but it has exactly one call
site in the whole codebase — the P-button menu's placeholder `menuPlay()`
action — and no autonomous-behavior-timing-window detection exists
anywhere to actually award this reward during real gameplay. The designed
per-behavior windows and rewards:

| Autonomous Behavior | Tap Window | Reward |
|---|---|---|
| Zoomies | during the run | "noticed!" sparkle, +3 satisfaction |
| Catching a mouse | during the pounce | "you saw!" sparkle, +5 satisfaction |
| Sneezing | within 0.5s of the sneeze | sheepish look, +2 satisfaction |
| Finding something | during examination | creature holds it up to show the human, +3 satisfaction |
| Knocking something off | during or within 1s after | guilty-and-proud look, +2 satisfaction |
| Slow-blink | during the blink | mutual moment — extended slow-blink, +5 contentment |
| First-word ceremony | during the word | extended emotional moment, +10 contentment |

Designed to count **once per behavior instance** — spam-tapping a single
zoomie shouldn't award the reward repeatedly.

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

# Between-Session Autonomous Speech — unbuilt (P5-T1-16)

`PHASE-5.md`'s P5-T1-16 designed 7 Layer-1 autonomous-speech triggers —
the creature speaking on its own, without Claude connected, using the
same rendering pipeline but skipping the MCP/IPC path entirely. Of the 7,
**2 are built and documented elsewhere**: commit-eaten reactions (see
[commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md)) and dream mumble (see
[journal-and-dreams](/REFERENCE/journal-and-dreams.md)). The other **5 have
no call sites anywhere in `SpeechCoordinator`/`GameCoordinator`**
(grep-verified) and are preserved here as designed-but-unbuilt intent:

📐 **Wake-greeting.** Critter+ stage. On waking, the creature was designed
to say `"morning!"` or a time-appropriate greeting, once per wake.

📐 **Sleepy-yawn.** Critter+ stage. When energy drops below 15, the
creature was designed to say `"sleepy..."` or display yawn text.

📐 **Satisfaction-heart.** Drop+ stage. When satisfaction crosses 80, the
creature was designed to show a heart symbol (Drop) or say `"happy!"`
(Critter+).

📐 **Weather-triggered speech.** Critter+ stage. On a weather change, the
creature was designed to react with weather-appropriate lines
(`"rain!"`, `"cold..."`, `"pretty!"`).

📐 **Idle-thought.** Beast+ stage. During idle (no touch, no Claude), the
creature was designed to surface a random thought from the speech cache
or a new observation, capped at once per 10 minutes idle.

All 5 are designed as template-driven Layer-1 behaviors (text generated
directly by the daemon from templates + personality + context, same as
the two built triggers) — none require new rendering machinery, only the
trigger-detection call sites themselves. Whether to wire or descope these
5 is a phase-3-backlog decision, not resolved here.

# Visual Sense — Full Screenshot Design Intent (P4-T1-06)

📐 **`pushling_sense(aspect: "visual")` — natural-language scene description +
inline base64 screenshot.** `SenseHandlers.swift`'s `"visual"` case
(`Pushling/Sources/Pushling/IPC/SenseHandlers.swift:29-33`, grep-verified)
returns nothing but a static acknowledgement —
`{"note": "Visual screenshot capture is not yet implemented. Use 'sense
surroundings' for world state."}` — regardless of scene state. The full
original design, from `docs/archive/plan/phase-4-embodiment/PHASE-4.md`
P4-T1-06:

```json
{
  "aspect": "visual",
  "description": "Zepus stands in a forest biome at mid-afternoon. Cloudy sky with light fog. A mushroom to the right, a tree to the left. The fortress landmark of api-server is visible on the distant skyline. Zepus is facing right, ears relaxed, tail swaying gently.",
  "screenshot_base64": "iVBORw0KGgo...",
  "screenshot_size": {"width": 2170, "height": 60},
  "pending_events": [...]
}
```

The `description` string was designed to be composed live from
surroundings + body + self data into a natural sentence (not a template
lookup) — the same underlying data `sense surroundings`/`sense self`/`sense
body` already expose separately, just narrated in prose. The screenshot
half: the daemon renders the current frame via `SKView.texture(from:)`,
exports it as PNG, and base64-encodes it inline into the response, at @2x
resolution (2170x60px) and under 50ms capture time (under 100ms total added
latency to the `sense` call).

**Not the same shape as the one screenshot mechanism that does exist.** A
separate, operator-only `screenshot` command (`CommandRouter.swift:75,191`)
is fully implemented — it captures a PNG and writes it to
`/tmp/pushling_screenshot.png`, returning the file path, not inline base64
data. `pushling_sense(aspect: "visual")` forwards to the `sense`/`visual`
socket action, not to `screenshot`, so the MCP tool never reaches this
working capture path — the two were designed as (and remain) separate
delivery mechanisms with separate response shapes. See [the current-state
note in the MCP tool contract](/ARCHITECTURE/mcp-tool-contract.md#pushling_sense)
and [the command catalog's `sense`
detail](/ARCHITECTURE/ipc-command-catalog.md#sense--detail-not-covered-by-the-tool-contract)
for the shipped-today behavior this design intent would replace.

# Citations

[1] `docs/archive/plan/phase-6-interactivity/PHASE-6.md` — Track 4 (P6-T4-01/02/03/05), P6-T1-02b/02c/05/10, P6-T2-06, P6-T3-04/05/06/08/09/11 cooperative and per-game subsections
[2] `docs/archive/plan/TODO-CONTEXT-MENU-SYSTEM.md`
[3] `PUSHLING_VISION.md` — Touch Interactions, Human Milestones, Creature-Initiated Invitations, Mini-Games
[4] `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md` — §4 Camera Controller (zoom fallback input), §5 Creature Scaling Under Zoom, §6 Zoom Detail Tiers, §9 Coordinate Conversion for Hit-Testing
[5] `docs/archive/plan/phase-5-speech/PHASE-5.md` — P5-T1-16 Between-Session Autonomous Speech
[6] `Pushling/Sources/Pushling/Creature/ZoomDetailController.swift` (tier alpha values, lazy max-detail creation)
[7] `Pushling/Sources/Pushling/Input/ObjectInteraction.swift` (`onObjectEvent` — declared, never assigned; grep-verified) and `Input/CreatureTouchHandler.swift` (no `objectInteraction.onObjectEvent = ` call site)
[8] `Pushling/Sources/Pushling/Input/Games/MiniGameManager.swift` (no idle-teaser/discovery logic)
[9] [camera control](/SYSTEMS/camera-and-parallax.md), [touch milestones](/SYSTEMS/touch-milestones.md), [invitation system](/SYSTEMS/invitation-system.md), [mini-games](/SYSTEMS/mini-games.md), [Touch Bar menu patterns](/RESEARCH/touch-bar-menu-patterns.md), [commit-feeding-xp](/SYSTEMS/commit-feeding-xp.md), [journal-and-dreams](/REFERENCE/journal-and-dreams.md), [the gesture-response map](/REFERENCE/gesture-response-map.md), [the touch input pipeline](/SYSTEMS/touch-input-pipeline.md)
[10] `docs/archive/plan/phase-4-embodiment/PHASE-4.md` — P4-T1-06 pushling_sense "visual"; `Pushling/Sources/Pushling/IPC/SenseHandlers.swift` (`"visual"` case, grep-verified not-implemented ack) and `Pushling/Sources/Pushling/IPC/CommandRouter.swift` (the separate `screenshot` command)
