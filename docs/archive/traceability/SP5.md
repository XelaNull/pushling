---
type: Reference
title: SP5 Traceability — Touch & Interaction
description: Source-to-concept mapping for Wave SP5 (WO-1 OKF migration) — proves zero fidelity loss across the eight touch/interaction concepts.
status: Current
tags: [okf-migration, traceability, wave-sp5]
timestamp: 2026-07-02T00:00:00Z
---

Wave SP5 authored eight concepts:
[touch-input-pipeline](/SYSTEMS/touch-input-pipeline.md),
[camera-and-parallax](/SYSTEMS/camera-and-parallax.md),
[gesture-response-map](/REFERENCE/gesture-response-map.md),
[touch-milestones](/SYSTEMS/touch-milestones.md),
[invitation-system](/SYSTEMS/invitation-system.md),
[mini-games](/SYSTEMS/mini-games.md),
[interactivity-unbuilt](/FEATURES/interactivity-unbuilt.md), and
[touch-bar-menu-patterns](/RESEARCH/touch-bar-menu-patterns.md).

"Deferred" below means the source section is real content out of this
wave's assigned scope, routed to the wave that owns that subject — not a
fidelity loss. Deferred sections were read for context only; nothing from
them was lifted as truth into an SP5 concept.

# docs/archive/MULTITOUCH-CAMERA-REFERENCE.md (primary source — entire file assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| Pipeline Overview | `touch-input-pipeline.md#pipeline` | migrated, corrected — the 4-recognizer diagram (click/magnification/2-finger-pan/1-finger-pan) doesn't match code; only click + one 1-finger pan are actually wired |
| §1 Gesture Types (13 total) | `touch-input-pipeline.md#gesturerecognizer-the-12-gesture-types` | migrated, corrected — code has exactly 12 `GestureType` cases; `pinchZoom` and `twoFingerDrag` don't exist anywhere in the sources |
| §2 Gesture Target Resolution | `touch-input-pipeline.md#gesturetarget` | migrated, corrected — `.commitText` exists in the enum but `targetFor(state:)` never returns it; commit-text is a separate grab path |
| §3 Routing Rules (creature-targeted, world-targeted->camera, milestone-gated) | `gesture-response-map.md` (per-gesture sections), `touch-milestones.md#the-9-milestones` | migrated, corrected and reconciled against `CreatureTouchHandler.swift` — several routing details differ from the doc (see the gesture-response-map's per-row notes, e.g. sleeping-creature tap only special-cased for the nose region, tap-rotation not actually varying the fired reflex) |
| §4 Camera Controller (state, lock modes, pan math, zoom math, Y-tracking, recenter) | `camera-and-parallax.md` (Design Canon + Current Shipped State sections) | migrated, corrected — doc presents pan/zoom as live; code has both disabled behind an unconditional early `return` (`FIXED-VIEWPORT` comment) per the R2 ruling. Numeric constants also corrected throughout (pan dampening, zoom range, decay half-life, Y-tracking dead zone/half-lives) — see the concept's closing citation for the full list of corrected values |
| §5 Creature Scaling Under Zoom | *(none)* | dropped-with-justification — no `cappedZoom`/`worldZoom`/counter-scale code exists anywhere; `PushlingScene.swift`'s actual `depthScale = 1.0 - z * 0.35` is unrelated depth-based scaling, not zoom-related, and belongs to a creature-visual concept (SP6a) if it needs documenting at all, not this wave's camera concept |
| §6 Zoom Detail Tiers (ZoomDetailController) | `interactivity-unbuilt.md#live-pan--zoom` | migrated as unbuilt — tier thresholds are accurate, but the class is referenced by zero other files (defined-but-unwired); full rendering detail deferred to SP6a's creature-visual concept |
| §7 Parallax Response (3-layer claim) | *(none — deferred)* | deferred — parallax layer configuration is explicitly out of scope for this wave's camera concept (owned by SP6a's `world-terrain-parallax.md` per the dispatch); noted in `camera-and-parallax.md`'s scope-boundary intro that this concept covers camera state only. Flagged for SP6a: the doc's "3-layer parallax" claim is wrong — `ParallaxSystem.swift` has 4 layers (far/deep/mid/fore) |
| §8 Frame Update Order | *(none — deferred)* | deferred — belongs with SP6a's scene/rendering concept; camera's own per-frame `update()` behavior is covered in `camera-and-parallax.md` directly from `CameraController.swift` rather than from this doc's frame-order summary |
| §9 Known Edge Cases (Petting vs Slow Drag, Camera Lock + Zoom, Multi-Touch Suppression, Tap 300ms Delay, Pan Decay, Coordinate Conversion) | `touch-input-pipeline.md` (multi-touch suppression, tap disambiguation), `gesture-response-map.md#petting-stroke` (petting vs. slow-drag), `camera-and-parallax.md` (pan decay) | migrated, corrected — "Tap 300ms Delay" is corrected to the real two-stage timer (0.3s then a further 0.15s) in `touch-input-pipeline.md`; coordinate-conversion-for-hit-testing edge case deferred to SP6a as rendering/scene detail, not touch-pipeline detail |
| §10 Key Source Files | *(distributed across all concepts' Citations sections)* | migrated (distributed, not as a standalone table) |

# docs/archive/plan/phase-6-interactivity/PHASE-6.md (primary source — entire file assigned)

| Source section | → Target concept#section | Status |
|---|---|---|
| Goal, Dependencies, Architecture Notes (coordinate system, performance budget) | `touch-input-pipeline.md` (coordinate system folded into TouchTracker section) | migrated (partial) — performance budget table dropped-with-justification: no per-subsystem input-latency profiling was found in code to verify against (<0.5ms gesture recognition, <0.1ms hit-testing, etc.); these are unverifiable design targets, not measured or enforced values, and asserting them as canon would risk minting unverified numbers |
| P6-T1-01 Touch Tracking System | `touch-input-pipeline.md#touchtracker-coordinate--state-tracking` | migrated, corrected — `TouchState` field list matches code closely; "4-frame window" velocity claim clarified as descriptive shorthand for a single-pole EMA, not a literal ring buffer |
| P6-T1-02 Gesture Recognizer Framework (incl. priority table) | `touch-input-pipeline.md#gesturerecognizer-the-12-gesture-types` | migrated, corrected — the numeric priority-resolution table doesn't exist in code as a ranked simultaneous-match system; replaced with the actual procedural precedence derived from the state machine's check order |
| P6-T1-02b Basic Gesture-to-Creature Response Map (incl. HUD overlay, near-evolution progress bar) | `gesture-response-map.md` (tap section); HUD-overlay and progress-bar detail | migrated (gesture-response mapping); HUD overlay and near-evolution progress bar visual detail dropped-with-justification — these are `HUDOverlay`/`EvolutionProgressBar` rendering concerns, not touch-routing concerns; belong to a scene/rendering concept (SP6a) if not already covered there. Tap-rotation drift (rotation not affecting the fired reflex) documented as a new finding in `gesture-response-map.md#tap` |
| P6-T1-02c 2-Finger Swipe — World Pan (incl. Sage+ temporal vision) | `interactivity-unbuilt.md` (implicitly, via the "2-finger gesture is a no-op except belly rub" note in `gesture-response-map.md#two-finger-dispatched-on-lift`) | migrated as unbuilt — code pans via single-finger drag on empty space, not 2-finger swipe; no temporal-rewind code exists anywhere. Explicitly called out in `gesture-response-map.md`'s two-finger section rather than duplicated into `interactivity-unbuilt.md`, to avoid restating the same negative finding twice |
| P6-T1-03 Laser Pointer Mode | `gesture-response-map.md#drag--slow-drag` | migrated, verified against `LaserPointerMode.swift` — speed thresholds and pounce-delay confirmed accurate |
| P6-T1-04 Petting Stroke | `gesture-response-map.md#petting-stroke` | migrated, verified against `PettingStroke.swift` |
| P6-T1-05 Object Flick/Launch | `gesture-response-map.md#flick` | migrated, verified against `ObjectInteraction.swift` — mass factors and restitution values match exactly |
| P6-T1-06 Object Pick Up and Move | `gesture-response-map.md#long-press` | migrated, verified against `ObjectInteraction.swift` |
| P6-T1-07 Hand-Feeding Commits | `gesture-response-map.md#hand-feeding-not-a-gesture-type--a-parallel-touch-start-path` | migrated, corrected — hand-feeding is not routed through `GestureTarget.commitText` as the doc implies; it's a parallel grab/drag/release path entered via `HandFeeding.tryGrab` |
| P6-T1-08 Rapid Tap Pounce Game | `gesture-response-map.md#rapid-taps` | migrated, verified against `PounceGame.swift` |
| P6-T1-09 Wake-Up Boop | `gesture-response-map.md#tap` | migrated, corrected — the doc implies any tap on a sleeping creature triggers boop-handling; code only special-cases the nose-area sub-region, with taps elsewhere falling through to the normal tap-cycle logic even while asleep |
| P6-T1-10 Tap-on-Object | `gesture-response-map.md#tap` | migrated, verified against `ObjectInteraction.tapObject` |
| P6-T1-11 Belly Rub | `gesture-response-map.md#two-finger-dispatched-on-lift` | migrated, corrected — trap chance is not a flat 30%; it's 20% for high-energy creatures and 40% otherwise (personality-dependent, per `CreatureTouchHandler.handleBellyRub`) |
| P6-T1-12 Touch Milestone Tracking (touch_stats schema, counting rules) | `touch-milestones.md#persistence-a-table-thats-never-written` | migrated, corrected — this is the wave's most significant new finding: the `touch_stats` table this section specifies is created in the schema but never written to by `MilestoneTracker`, which only persists a single `creature.touch_count` column. Flagged for DECISIONS.md |
| P6-T2-01 Touch Counter in SQLite | `touch-milestones.md#persistence-a-table-thats-never-written` | migrated, corrected — same finding as above; "batch write every 30s" claim verified accurate for the one column that IS persisted |
| P6-T2-02 Milestone Unlock System (incl. `milestones` table w/ `unlocked`/`unlocked_at`/`ceremony_played` columns) | `touch-milestones.md#checking--unlocking` | migrated, corrected — checking is always immediate (not "immediately AND after batch write" as two separate paths); the `milestones` table's real schema (shared across all milestone categories, keyed differently than this section's proposed `unlocked`/`unlocked_at` columns) is documented in [state database schema](/DATA_MODELS/state-database-schema.md) rather than restated here |
| P6-T2-03 Milestone Unlock Details (all 6 sub-milestones) | `touch-milestones.md#the-9-milestones` | migrated, corrected — `pre_contact_purr`'s described behavior has no implementing code (flagged as unbuilt); `touch_mastery`'s "2x particles" claim corrected to apply only to tap-heart particles, not the full list this section claims |
| P6-T2-04 Unlock Ceremony (incl. journal entry JSON) | `touch-milestones.md#checking--unlocking` | migrated, corrected — timing sequence verified against `UnlockCeremony.swift` (3.5s total, not the doc's 3.0s across flash+banner+demo+dismiss, once dismiss's 0.7s is counted); `onDemoRequest`/`extraCelebration` exist but have no wired consumer (noted); journal-entry JSON example dropped-with-justification — no journal-write call site was found in `UnlockCeremony.swift` for milestone unlocks specifically (the milestone's own `earned_at` column in the `milestones` table is the actual persistence, not a separate journal entry) |
| P6-T2-05 Pet Streak Tracking (incl. daily gift) | `touch-milestones.md#pet-streak-daily-interaction` | migrated, corrected — `midnightCheck()` exists but no timer call site was found invoking it automatically; gift-item world-placement has no implementation (moved to `interactivity-unbuilt.md`) |
| P6-T2-06 "Paying Attention" Rewards | `interactivity-unbuilt.md#touch-milestones--unbuilt-payloads` | migrated as unbuilt — the sparkle visual exists (`emitMomentRing`) but has exactly one call site (a menu placeholder), and no autonomous-behavior-timing-window detection exists |
| P6-T3-01 Invitation System (scheduling) | `invitation-system.md#scheduling` | migrated, corrected — this wave's second major new finding: the scheduler's own personality/emotion/stage/sleep/mini-game/ceremony inputs are never assigned by the sole owner (`CreatureTouchHandler`), so selection always runs against frozen defaults and two of the scheduler's own guard conditions are unreachable. Flagged for DECISIONS.md |
| P6-T3-02 Invitation Types (6 types, incl. per-type accept/reward detail) | `invitation-system.md#the-6-invitation-types` | migrated, corrected — stage gates and weight-bias formulas verified against `InvitationSystem.swift`; per-type animation/reward payloads (fetch volleys, transformation types, etc.) confirmed unimplemented and moved to `interactivity-unbuilt.md` rather than documented as prescriptive-but-unverifiable detail |
| P6-T3-03 Invitation Timeout & Self-Resolution (incl. per-type self-resolution animations, journal JSON) | `invitation-system.md#lifecycle` | migrated (lifecycle timing only); per-type self-resolution animations dropped-with-justification — same reason as P6-T3-02, no implementing code exists to verify against; journal-entry JSON examples dropped-with-justification, no journal-write call site found in `InvitationSystem.swift` |
| P6-T3-04 Mini-Game System Framework (lifecycle, scoring, trigger sources) | `mini-games.md#lifecycle`, `mini-games.md#input-takeover` | migrated, corrected — only `.humanGesture` trigger source is wired; `.creatureInvitation`/`.claudeMCP` have enum cases but no call sites (moved to unbuilt) |
| P6-T3-05 Catch Mini-Game (incl. cooperative COMBO) | `mini-games.md#the-5-games` | migrated (base game); cooperative COMBO mechanic moved to `interactivity-unbuilt.md#cooperative-mini-game-modes` — no combo/cooperative code in `CatchGame.swift` |
| P6-T3-06 Memory Mini-Game (incl. cooperative) | `mini-games.md#the-5-games` | migrated (base game); cooperative mode moved to unbuilt — no cooperative code in `MemoryGame.swift` |
| P6-T3-07 Treasure Hunt Mini-Game (incl. cooperative hints) | `mini-games.md#the-5-games` | migrated (base game); cooperative `pushling_speak` hint mode moved to unbuilt — no such code in `TreasureHuntGame.swift` |
| P6-T3-08 Rhythm Tap Mini-Game (incl. cooperative dual-direction) | `mini-games.md#the-5-games` | migrated (base game); cooperative dual-direction mode moved to unbuilt — no such code in `RhythmTapGame.swift` |
| P6-T3-09 Tug of War Mini-Game (incl. Claude cooperative pulls) | `mini-games.md#the-5-games` (solo-mode detail: creature-cheats-55/45) | migrated, corrected — the "Claude cooperative" framing is entirely absent; code implements only a human-vs-creature version with the 55/45 lean applied to the creature-as-opponent. Documented as the shipped reality, with the cooperative design preserved at `interactivity-unbuilt.md` |
| P6-T3-10 Mini-Game Result Screen | `mini-games.md` (score-tier table folded in; visual layout detail deferred) | migrated (scoring); exact `GameResultScreen` visual layout dropped-with-justification — rendering detail belongs to a creature-visual/UI concept (SP6a), not this wave's system-level mini-games concept |
| P6-T3-11 Game Unlock Progression | `mini-games.md#the-5-games` | migrated, verified exactly against `MiniGameManager.checkGameUnlocks` — thresholds match the plan precisely |
| Track 4 P6-T4-01 through 05 (Display Modes, Postcards, Konami, Co-Presence, Campfire) | `interactivity-unbuilt.md#track-4-advanced-gestures--display-modes` | migrated as unbuilt (P6-T4-01/02/03/05) or built-differently (P6-T4-04, noted explicitly rather than mis-filed as missing) |
| QA Gate (all checklist items) | *(none)* | dropped-with-justification — a per-item unchecked QA checklist for shipped Track 1-3 work has no prescriptive content beyond what the concepts above already establish as built/verified; archival of the residual `PHASE-6.md` file is SP8's job |

# docs/archive/plan/TODO-CONTEXT-MENU-SYSTEM.md (primary source — entire file assigned; disposition: migrate, separate built-canon from unbuilt-📐)

| Source section | → Target concept#section | Status |
|---|---|---|
| Problem Statement, Design Goals, Long-Press Conflict Resolution intro | `touch-bar-menu-patterns.md` intro, `interactivity-unbuilt.md#context-menu-system-todo-context-menu-systemmd` | migrated |
| Visual Design (menu item sizing math, color scheme, font, ASCII mockups) | *(none)* | dropped-with-justification — pixel-math and ASCII-art mockups for a never-built system are implementation detail with no independent value once the design's *conclusions* (item sizing constraints, palette choices) are captured in `touch-bar-menu-patterns.md`'s Accessibility and Context-Specific-Menu-Contents sections; re-preserving the raw mockups would be redundant with the prose that already explains what they show |
| Technical Architecture (`ContextMenuItem`/`ContextMenuDefinition`/`ContextMenuProvider`/`ContextMenuPresenter` Swift signatures, gesture integration, `CreatureTouchHandler` integration sketch) | `interactivity-unbuilt.md#context-menu-system-todo-context-menu-systemmd` (referenced, not reproduced) | dropped-with-justification — these are unbuilt code sketches (types that don't exist), not canon to prescribe; OKF concepts document built or clearly-intended-and-scoped systems, not speculative unimplemented class APIs. The *existence* and *scope* of the unbuilt system is preserved; its hypothetical Swift signatures are not, since prescribing them as canon risks locking in an API shape nobody has committed to building |
| Animation Specifications (menu open/close/select/auto-dismiss timing) | *(none)* | dropped-with-justification — same reasoning: detailed animation timing for an unbuilt, possibly-superseded system isn't canon-worthy; the pattern-level animation research (which *did* inform the eventual recommendation) is preserved in `touch-bar-menu-patterns.md`'s per-pattern evaluations instead |
| Example Menu Definitions (Creature/Object/World Swift literals) | `touch-bar-menu-patterns.md#context-specific-menu-contents-as-designed` | migrated (content, not as Swift code — as the prose "what items would appear" table) |
| Implementation Phases (8 phases), File List, Integration Points, Node Budget Impact, Performance Considerations | *(none)* | dropped-with-justification — project-planning scaffolding (task breakdowns, estimated line counts, day-by-day phasing) for unbuilt work; no prescriptive system knowledge beyond what's already captured |
| Open Questions (haptics, sound effects, dynamic items, nested menus, sleep-menu) | *(none)* | dropped-with-justification — open design questions for a superseded system; not worth preserving as unresolved canon questions when the system itself was never built and was superseded before these questions needed answers |
| Success Criteria | *(none)* | dropped-with-justification — acceptance checklist for unbuilt work |
| UX Alternatives & Interaction Patterns — Hardware Constraints Recap | `touch-bar-menu-patterns.md#hardware-constraints` | migrated |
| UX Alternatives — Patterns 1-6 (mockups, interaction flow, evaluation, strengths/weaknesses) | `touch-bar-menu-patterns.md#the-six-patterns-evaluated` | migrated (evaluations, strengths/weaknesses, and verdicts preserved in table + prose form; ASCII mockups dropped-with-justification as visual aids with no standalone informational content beyond what the evaluation prose already states) |
| Pattern Comparison Matrix | `touch-bar-menu-patterns.md#the-six-patterns-evaluated` (folded into the summary table) | migrated |
| Recommended Architecture: Dual-Pattern System | `touch-bar-menu-patterns.md#recommended-architecture-dual-pattern-system` | migrated |
| Long-Press Trigger Disambiguation (3 approaches) | `touch-bar-menu-patterns.md#long-press-trigger-disambiguation` | migrated |
| Affordance: Indicating Menu Availability (3 options) | `touch-bar-menu-patterns.md#affordance-teaching-the-human-the-menu-exists` | migrated |
| Nested Submenus (2 approaches) | `touch-bar-menu-patterns.md#nested-submenus` | migrated |
| Accessibility Considerations (touch targets, contrast, VoiceOver, motor, cognitive load) | `touch-bar-menu-patterns.md#accessibility-considerations` | migrated, corrected — the Visual Contrast subsection's palette hex values are wrong (`Ash #2A2A2A`/`Bone #E8E0D4`/`Gilt #D4A843` vs. `PushlingPalette`'s actual `displayP3` values, ≈`#5A5A5A`/`#F5F0E8`/`#FFD700`) and its "Void, Bone, Ash, Tide, Gilt" 5-color palette claim is incomplete (the real palette has 8 colors, also including Ember, Moss, Dusk); corrected values not restated in the accessibility section itself since exact hex isn't load-bearing there — flagged here for completeness |
| Context-Specific Menu Contents (Creature/World/Object menus, stage gating) | `touch-bar-menu-patterns.md#context-specific-menu-contents-as-designed` | migrated |
| Animation Specifications (Creature-Presented open/close, frame budget table) | `touch-bar-menu-patterns.md` (folded into the Pattern 6 writeup; frame-budget table dropped-with-justification as unverifiable-against-code for a system that doesn't exist) | migrated (partial) |
| Implementation Priority (P0-P3 table) | *(none)* | dropped-with-justification — task-prioritization scaffolding for unbuilt work |

# PUSHLING_VISION.md (assigned sections: Touch Interactions, Continuous Touch & Object Interaction, Creature-Initiated Invitations, Human Milestones, Mini-Games; P Button section)

| Source section | → Target concept#section | Status |
|---|---|---|
| Gameplay: The Core Loop ("Break" row touch mention) | `gesture-response-map.md` (folded implicitly — the row's content duplicates the Touch Interactions table below) | migrated (duplicate content, not separately restated) |
| Touch Interactions table | `gesture-response-map.md` (tap/double-tap/triple-tap/long-press/sustained-touch/two-finger sections) | migrated, corrected — reconciled against code throughout; see `gesture-response-map.md`'s per-section notes for each correction (tap-rotation not varying the reflex, sleeping-creature nose-only special case, belly-rub's true 20/40% split, etc.) |
| Continuous Touch & Object Interaction table | `gesture-response-map.md` (drag/laser/petting/flick/pick-up/hand-feeding/rapid-taps/tap-on-object/wake-boop sections) | migrated, corrected — same reconciliation as above |
| Creature-Initiated Invitations table | `invitation-system.md#the-6-invitation-types` | migrated, corrected — per-type payload detail moved to `interactivity-unbuilt.md` since no implementing code exists for the type-specific animations/rewards |
| Human Milestones table | `touch-milestones.md#the-9-milestones` | migrated, corrected — `pet_streak_7`'s framing as one of the milestone-table entries corrected: in code it's a separate `PetStreak` class, not one of the 9 `MilestoneID` cases (which include `gentle_wake` instead) |
| Mini-Games table (5 games + cooperative column) | `mini-games.md#the-5-games` | migrated, corrected — the "Cooperative" column's content for all 5 games moved to `interactivity-unbuilt.md#cooperative-mini-game-modes` as unimplemented |
| The P Button: Control Strip Gateway (progress-indicator + menu-drawer description) | `touch-bar-menu-patterns.md#outcome-what-actually-shipped` | migrated, corrected and reconciled against `TouchBarView.swift`/`TouchBarMenu.swift`/`GameCoordinator+MenuActions.swift` — the progress-indicator (gas-gauge border via `CAShapeLayer.strokeEnd`) is confirmed accurate; the menu-drawer's described contents ("Sound toggle and Stats buttons") are extended in the shipped build to include About, Pet, Feed, Play, and conditionally MCP |
| All other sections (Identity/Birth, Growth Stages, Personality, Visual System, Commit-as-Food, Speech Evolution, Behavior Stack, Hooks, Creation Systems, Surprises, Journal, Emotional Visual Feedback, Dream Journal, Release Celebrations, Performance, Roadmap) | *(not this wave)* | deferred — owned by SP3a/SP3b/SP4/SP6a/SP6b/SP7 per the bundle plan; read for context only where it clarified touch/interaction behavior (e.g. `GrowthStage` ordering, personality-axis names referenced by `InvitationSystem`), never lifted as truth into an SP5 concept |

# Citations

[1] `docs/archive/MULTITOUCH-CAMERA-REFERENCE.md`
[2] `docs/archive/plan/phase-6-interactivity/PHASE-6.md`
[3] `docs/archive/plan/TODO-CONTEXT-MENU-SYSTEM.md`
[4] `PUSHLING_VISION.md`
