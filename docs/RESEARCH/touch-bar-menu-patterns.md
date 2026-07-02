---
type: Research Note
title: Touch Bar Context-Menu Interaction Patterns (30pt Strip)
description: Evaluation of six context-menu interaction patterns against the Touch Bar's 30x1085pt capacitive constraints, the recommended dual-pattern design, and the shipped P-button menu that superseded it before it was built.
status: Current
tags: [research, touch, ux, touchbar]
timestamp: 2026-07-02T00:00:00Z
---

Preserved research from `docs/plan/TODO-CONTEXT-MENU-SYSTEM.md` — a
context-menu system designed but never built. Its discoverability goal
(surfacing available actions without requiring the human to already know
specific gesture types) was ultimately met by a different shipped
mechanism; see [the outcome](#outcome-what-actually-shipped) at the end
of this document. The design's own unbuilt status is tracked at
[interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md#context-menu-system-todo-context-menu-systemmd).

# Hardware Constraints

| Constraint | Value | Impact |
|---|---|---|
| Touch Bar height | 30pt (60px @2x) | No vertical stacking — one row only |
| Touch Bar width | 1085pt (2170px @2x) | Generous horizontal space |
| Touch precision | Sub-pixel float, 60Hz | Smooth tracking, no force/pressure |
| Force/pressure | None — purely capacitive | No "press harder" mechanics |
| Multi-touch | 2-3 practical simultaneous | Strip width limits practical touches |
| Display | True-black OLED, P3 gamut | Items on black are invisible until lit |
| Frame budget | 16.6ms/frame, ~5.7ms already used | ~11ms headroom for menu rendering |
| Existing long-press (500ms) | Creature -> examine/thought bubble; Object -> pick up & move | Any new menu trigger must not silently break these |

**The fundamental constraint**: 30pt of height makes every menu pattern
effectively **one-dimensional** — vertical arrangement is impossible for
readable, tappable items. All six patterns evaluated below are horizontal
or use workarounds to fake a second dimension.

# The Six Patterns Evaluated

| # | Pattern | Concept | Max Items | Creature Stays Alive? | Aliveness Score |
|---|---|---|---|---|---|
| 1 | Horizontal Strip | Items slide in from the long-press point, full 30pt height | 5-7 | Partial (world behind items obscured) | 4/10 |
| 2 | Replace Scene (Full Takeover) | Scene slides off, full-width menu slides in | 8-12 | **No** — creature off-screen entirely | 1/10 |
| 3 | Scroll Wheel (Single-Slot Carousel) | One slot at press point; swipe left/right cycles options | Unlimited | Yes | 6/10 |
| 4 | Expanding Bubble | Options fan out from the creature center | 4-6 | Yes (center) | 7/10 |
| 5 | Radial (Semi-Circle) | Classic radial menu compressed into 30pt | 3-5 | Partial | 3/10 |
| 6 | Creature-Presented (recommended hybrid) | Creature sits up; options emerge from it like speech, gaze-following hover reactions | 6-8 | **Yes, actively participating** | 9/10 |

**Pattern 2 (Replace Scene)** was rejected as a primary pattern despite
its item-capacity advantage specifically because it violates the
project's "always alive, never static" core principle — the creature
disappears entirely during menu use. It remains viable as a fallback for
deep settings screens needing 12+ items, with a mitigation of a tiny
breathing creature silhouette in the back button.

**Pattern 5 (Radial)** was rejected outright: a semi-circle that fits in
30pt height has a radius so small (~15pt) that items are 8-12pt apart —
below reliable touch discrimination — and widening the radius to make
items touchable (~60pt) flattens the arc until it's visually
indistinguishable from a horizontal line. "A radial menu on a 30pt-tall
strip is a horizontal strip with extra math and no benefit."

**Pattern 3 (Scroll Wheel)** trades capacity for speed — it can host
unlimited options in ~5 nodes, but cycling through 8 options serially
takes 8 discrete swipes, and both the trigger and the cycle mechanic are
hidden, making it unsuitable for frequent-use menus. Its OLED-minimal
footprint (only one slot occupied) was its strongest point.

**Pattern 4 (Expanding Bubble)** scored well on aliveness and visual
polish (OLED glow rings around each option) but caps at 4-6 items with
touch targets as small as 15-20pt diameter — below any reasonable target
size on a device already fighting the Touch Bar's 30pt ceiling.

## Pattern 6: Creature-Presented (Recommended)

The creature itself becomes the menu interface: long-press causes it to
sit up into a "presenting" pose, and options emerge from it outward
(splitting left/right, or all to one side near a screen edge), with the
world dimming to 60% brightness behind them. During slide-to-select, the
creature's gaze and posture react to which option the finger currently
hovers — leaning toward "Pet," perking ears for "Play," yawning for
"Nap," parting its mouth for "Talk." Confirming a selection makes the
creature nod before the menu retracts back into it over 150ms.

This scored highest specifically because it turns the *menu itself* into
an embodiment moment rather than a UI overlay competing with the
creature for the human's attention — directly aligned with the project's
"the creature IS the interface" principle. Its weaknesses are cost, not
design: it requires dedicated "presenting"-pose and per-option-hover
creature animations that don't otherwise exist, and it only solves the
creature-target case — a separate pattern is still needed for
world/empty-space menus, which have no creature to center on.

## Recommended Architecture: Dual-Pattern System

| Context | Pattern | Why |
|---|---|---|
| Creature menu (long-press on creature) | Pattern 6 (Creature-Presented) | Creature participates; natural metaphor; 6-8 item capacity |
| World/system menu (long-press on empty space, or 3-finger tap) | Pattern 1 (Horizontal Strip), with Pattern 2 (Replace Scene) reserved for 12+ item deep-settings screens | Preserves creature visibility for the common case |

# Long-Press Trigger Disambiguation

The 500ms long-press was already claimed by two existing behaviors
(thought bubble on creature, pick-up on object), so a menu trigger needed
to avoid colliding with them. Three approaches were compared:

**Approach A — Duration-based (recommended)**: 500-800ms + release fires
the *original* behavior (thought bubble / pick-up); continuing to hold
past 800ms opens the menu instead. A "loading ring" indicator (a thin arc
filling 0-360 degrees between 500-800ms) makes the mechanic self-teaching
— users who accidentally over-hold discover the menu, and the ring
teaches the timing for next time.

**Approach B — Target-based**: split the creature hitbox into head
(original thought-bubble behavior) and body (menu) regions. Rejected as
fragile given the creature's small hitbox sizes (6-25pt wide at early
stages).

**Approach C — Gesture modifier**: use an entirely distinct gesture
(double-tap-then-hold, or two-finger tap) so long-press keeps its
original meaning untouched. Avoids all conflicts but is less discoverable.

Approach A was the recommendation, on the basis that the self-teaching
loading-ring affordance offsets its slightly more complex
disambiguation logic.

# Affordance: Teaching the Human the Menu Exists

Three layered mechanisms were recommended together, not as alternatives:

1. **Idle pulse** — after 30+ seconds of no interaction, the creature's
   outline briefly brightens 10% (at most once per 5 minutes; more
   frequently, once per 2 minutes, during a new user's first week).
2. **First-touch tutorial extension** — the existing tap/double-tap/
   long-press tutorial panel (shown at the `first_touch` milestone — see
   [touch milestones](/SYSTEMS/touch-milestones.md#the-9-milestones)) gains
   a fourth, deliberately mysterious hint: `"Hold+ = ..."`.
3. **Creature self-demo / verbal hint** — at earlier stages, the creature
   occasionally sits into the "presenting" pose briefly during idle,
   unprompted, then relaxes — demonstrating the menu without the human
   triggering it. At Beast+ (once speech-capable), it occasionally says
   `"hold me..."` or `"ask me..."`.

# Nested Submenus

For menus needing more than 6-8 items (e.g. a "Games" category expanding
into the 5 mini-games), a **lateral slide** was recommended over an
instant replace-in-place swap: selecting a category item slides the
current menu left and slides a submenu in from the right, with a "◀" back
item appearing at the left edge. Category items carry a "▸" suffix
indicator. Limited to 2 levels deep (main -> sub, no sub-sub-menus),
150ms transition.

# Accessibility Considerations

- **Touch targets**: every pattern here inherently falls below Apple
  HIG's 44pt minimum *height* (the Touch Bar itself is 30pt) — an accepted
  platform limitation, not a design flaw specific to this system. Widths
  of 60-120pt (Strip/Replace-Scene/Scroll-Wheel/Creature-Presented) are
  acceptable; the Expanding Bubble's 15-20pt icon-only targets were
  flagged as genuinely too small and would need invisible hit-zone padding
  out to 30-40pt if built.
- **VoiceOver**: the Touch Bar supports `NSAccessibility` — each menu item
  would need an `accessibilityLabel`, with left/right arrow-key navigation
  and VO+Space activation when VoiceOver is active.
- **Motor accessibility**: no time pressure while a finger is down;
  tap-to-select as an explicit fallback for anyone who can't do
  slide-to-select; the default 3-second idle timeout should be
  user-extendable to 10s; minimum 8pt gaps between items to prevent
  accidental adjacent selection.
- **Cognitive load**: cap at 6-8 items per menu level (Miller's law,
  7±2), pair icons with text labels where space allows, keep item order
  stable across sessions, and visually distinguish category items (with
  submenus) from direct action items.

# Context-Specific Menu Contents (as designed)

**Creature menu** — stage-gated, so a Spore/Egg creature's menu has only
2-3 items and an Apex creature's has 7+: Pet (no gate), Nap (Drop+), Talk
(Beast+, if Claude connected), Play -> submenu of available mini-games
(Critter+), Tricks -> submenu of taught tricks (once any exist), Stats (no
gate), Mood (Critter+).

**World menu** — Create (if Claude connected), Weather, Explore (pan to
nearest landmark), Journal, Settings (submenu).

**Object menu** — recommendation was to leave object long-press as
pick-up-only rather than overload it further; if an object menu were
ever needed, trigger it via double-tap on the object instead of a second
long-press tier.

# Outcome: What Actually Shipped

None of the above was built. Instead, `TouchBar/TouchBarMenu.swift`'s
`MenuStripView` — a persistent P-button-triggered slide-out strip — and
`App/GameCoordinator+MenuActions.swift`'s action handlers ship the same
core discoverability goal this research was written to solve, via a
different mechanism entirely: a tap on the always-visible P button (not a
long-press on the creature) expands a horizontal strip of labeled buttons
(currently ♪ sound-toggle, Stats, About, Pet, Feed, Play, and
conditionally MCP), each wired to an instant, visible creature reaction
(`menuPet`/`menuFeed`/`menuPlay` in `GameCoordinator+MenuActions.swift`).
The strip fades out after 20 seconds of inactivity and restores on any
button press. A separate `StatsPopupView` (reached via the strip's
"Stats" button) renders a 5-page swipeable stats overlay — its own
content (identity, emotional state, personality, history, appearance)
goes beyond what this research's "Stats" menu item ever specified.

This is a genuine supersession, not a partial implementation of the
design above: no `.contextMenu` `GestureType`, no long-press-duration
disambiguation, no per-target (creature/object/world) menu, and no
creature-presenting-pose animation exist anywhere in the codebase
(grep-verified for `ContextMenu` across `Pushling/Sources/`). The
P-button strip solves the same "how does the human discover available
actions" problem this document explores, at the cost of the
creature-centric interaction language Pattern 6 was designed around.

# Citations

[1] `docs/plan/TODO-CONTEXT-MENU-SYSTEM.md` — full original research (UX Alternatives & Interaction Patterns section)
[2] `Pushling/Sources/Pushling/TouchBar/TouchBarMenu.swift` (`MenuStripView`, `StatsPopupView`)
[3] `Pushling/Sources/Pushling/App/GameCoordinator+MenuActions.swift` (`menuPet`, `menuFeed`, `menuPlay`)
[4] [interactivity — unbuilt features](/FEATURES/interactivity-unbuilt.md)
