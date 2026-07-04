---
type: Reference
title: Phase-2 Flesh-Out — Dossier→Concept Coverage
description: Grep-verified coverage table proving all 42 tiered features from the Phase-2 flesh-out dossier landed in a concept, lossless-from-dossier — plus confirmation that the dossier's Appendix (Dropped) items stay out of canon as intended.
status: Current
tags: [flesh-out, traceability, coverage, wave-fo-coverage]
timestamp: 2026-07-03T00:00:00Z
---

Source dossier: `.samantha/specs/pushling-flesh-out-dossier-2026-07-03.md` (Tier 1 / Tier 2 / Tier 3 feature sections, "New Canon Concepts (9)", "Deepen Existing Concepts (10)", and "Appendix — Dropped").

Method: for every tiered feature, the dossier's own `covers:` line (under "New Canon Concepts (9)") names the concept it should land in. Each row below was independently grep-verified against the landed concept file — heading text, section anchor, or a direct feature-name match — not just trusted from the dossier's claim. Camera Deadzone is the one Tier-1 feature whose home is a *deepened* existing concept, not one of the 9 new ones; that's called out explicitly.

## Coverage Table

| Tier | Feature | Covering Concept(s) | Landed? (grep-verified) |
|---|---|---|---|
| 1 | Body Pose & Compose Pipeline | `docs/SYSTEMS/body-pose-pipeline.md` | Yes — the doc's title and entire structure (§1 BodyPoseController, §2 transform table, §6 single compose point) *is* this feature |
| 1 | Airborne Arc System (jump finally renders) | `docs/SYSTEMS/body-pose-pipeline.md` §4 | Yes — `# 4. positionY Application + isAirborne Terrain-Clamp Suspension`; jump bodyState tuple + airborne-arc cross-reference at line 186 |
| 1 | Camera Deadzone — locomotion reads as travel | `docs/SYSTEMS/camera-and-parallax.md` (deepened, not one of the 9 new concepts) | Yes — `# Horizontal Deadzone — Locomotion Reads as Travel (Designed, not built)` (line 137), full per-stage window/widening table, per-mode matrix row 5 |
| 1 | Personality & Stage Gait Engine (with Childhood Echo) | `docs/SYSTEMS/locomotion-and-gait.md` §1 | Yes — `# 1. Personality & Stage Gait Engine`, `## Per-Stage Signature Gaits`, `## The Childhood Echo` all present |
| 1 | Idle Life Layer — never actually standing still | `docs/SYSTEMS/idle-life-and-rest.md` §1 | Yes — `# 1. Idle Life Layer`, `## 1.2 The <=20s Whole-Body-Motion Guarantee`, `## 1.3 Dwell Escalation` |
| 1 | Hunt & Pounce Grammar (stalk → butt-wiggle → launch → catch/whiff) | `docs/SYSTEMS/hunt-and-pounce.md` §2 | Yes — `# 2. The Canonical Grammar`, `## 2b. The Whiff Outcome Table`, `# 3. Per-Stage Catch Rates & Pounce Profiles` |
| 1 | Appendage Semaphore — tail/ear/whisker as emotional grammar | `docs/SYSTEMS/emotional-body-language.md` §2 | Yes — `# 2. Appendage Semaphore — Tail / Ear / Whisker Grammar`, includes the `SegmentedTailController` "built, wired nowhere" correction |
| 1 | Posture Vocabulary — the emotion-to-body table | `docs/SYSTEMS/emotional-body-language.md` §1 (full spec) + `docs/SYSTEMS/body-pose-pipeline.md` (application point) | Yes — `# 1. Posture Vocabulary — Valence×Arousal to Body Shape`; body-pose-pipeline.md explicitly cites it as "rides this doc's compose point as a modifier layer, not a second controller" |
| 1 | Weight & Momentum Model — accel, skid, settle | `docs/SYSTEMS/locomotion-and-gait.md` §2 | Yes — `# 2. Weight & Momentum Model`, `## Per-Stage Mass Classes` |
| 2 | Head-Leads-Turn Cascade | `docs/SYSTEMS/locomotion-and-gait.md` §3 | Yes — `# 3. Head-Leads-Turn Cascade`, casual (0.433s) and startle (0.15s) tier subsections |
| 2 | Stretch Ritual Grammar (wake stretch, arch, play-bow) | `docs/SYSTEMS/idle-life-and-rest.md` §3 | Yes — `# 3. Stretch Ritual Grammar` |
| 2 | Resting Posture Ladder (thermoregulation & security) | `docs/SYSTEMS/idle-life-and-rest.md` §2 | Yes — `# 2. Resting Posture Ladder`, stage-gating subsection |
| 2 | Sleep Geography — trust decides where and how it sleeps | `docs/SYSTEMS/idle-life-and-rest.md` §4 | Yes — `# 4. Sleep Geography` |
| 2 | Dream Theater — sleep twitching synced to dream content | `docs/SYSTEMS/idle-life-and-rest.md` §5 | Yes — `# 5. Dream Theater — somatic twitch per dream pattern` |
| 2 | Arch Grammar: Startle Cascade & Play Sproing | `docs/SYSTEMS/emotional-body-language.md` §3 | Yes — `# 3. Arch Grammar — One Render, Two Affects`, `## Boldness Scaling` |
| 2 | Grooming Chain with Displacement Grooming | `docs/SYSTEMS/emotional-body-language.md` §4 | Yes — `# 4. Grooming Chain (with Displacement Grooming)`, `## Displacement Grooming` |
| 2 | Play Drive & the Five-Beat Bout | `docs/SYSTEMS/play-bouts.md` §2-3 | Yes — `# 2. The Play-Pressure Meter — Designed, Not Built`, `# 3. The Five-Beat Bout Grammar` |
| 2 | Ambient Prey: Bug Season | `docs/SYSTEMS/ambient-wildlife.md` | Yes — `# Bug Season — the species roster`, 5-species table |
| 2 | Sky Theater Reflex | `docs/SYSTEMS/environment-reactions.md` §1 | Yes — `# 1. Sky Theater Reflex`, 7-event + full-moon reaction table |
| 2 | Reunion Runway — bond-weighted greeting choreography | `docs/SYSTEMS/companionship-rituals.md` §1 | Yes — `# 1. Reunion Runway — bond-weighted greeting choreography` |
| 2 | Flow Loaf — settles when you work, rises when you stop | `docs/SYSTEMS/companionship-rituals.md` §2 | Yes — `# 2. Flow Loaf — settles when you work, rises when you stop`, activity-feed prerequisite flagged |
| 2 | Crepuscular Territory Patrol | `docs/SYSTEMS/idle-life-and-rest.md` §7 | Yes — `# 7. Crepuscular Territory Patrol` |
| 2 | Check-In Glances — social referencing | `docs/SYSTEMS/companionship-rituals.md` §5 | Yes — `# 5. Check-In Glances — social referencing` |
| 3 | Terrain Footing & Hop-Overs | `docs/SYSTEMS/locomotion-and-gait.md` §4 | Yes — `# 4. Terrain Footing & Hop-Overs`, hop-over/detour behavior table |
| 3 | Prey-Lock & Chatter (the ekekek) | `docs/SYSTEMS/hunt-and-pounce.md` §4 | Yes — `# 4. Prey-Lock & Chatter (the ekekek)` |
| 3 | Sunbeam & Warm-Spot Seeking | `docs/SYSTEMS/idle-life-and-rest.md` §6 | Yes — `# 6. Sunbeam & Warm-Spot Seeking` |
| 3 | Void Ambush | `docs/SYSTEMS/hunt-and-pounce.md` §5 | Yes — `# 5. Void Ambush`, alpha-fade-to-void table |
| 3 | Grapple & Bunny-Kick | `docs/SYSTEMS/hunt-and-pounce.md` §6 | Yes — `# 6. Grapple & Bunny-Kick`, `## The Beast+ hind-leg (legHeight) decision` |
| 3 | Yarnling Unspooled | `docs/SYSTEMS/play-bouts.md` §5 | Yes — `# 5. Yarnling Unspooled — Toy-Specific Climax` |
| 3 | The Favorite — toy attachment and farewell | `docs/SYSTEMS/play-bouts.md` §6 | Yes — `# 6. The Favorite — Toy Attachment & Farewell`, bedtime-carry + legacy-shelf farewell |
| 3 | Puddle Days & Dabbing | `docs/SYSTEMS/environment-reactions.md` §6 | Yes — `# 6. Puddle Days & Dabbing` |
| 3 | Moth to Her Flame | `docs/SYSTEMS/ambient-wildlife.md` | Yes — `# Moth to Her Flame` |
| 3 | Landed-On-Me Freeze | `docs/SYSTEMS/ambient-wildlife.md` | Yes — `# Landed-On-Me Freeze`, `onCreatureLanded` callback spec |
| 3 | Gust Front | `docs/SYSTEMS/environment-reactions.md` §4 | Yes — `# 4. Gust Front`, body-lean-survives-updateWorld note |
| 3 | Snow Memory | `docs/SYSTEMS/environment-reactions.md` §5 | Yes — `# 5. Snow Memory` |
| 3 | Weather on the Horizon | `docs/SYSTEMS/environment-reactions.md` §3 | Yes — `# 3. Weather on the Horizon` |
| 3 | Golden Hour Dusk Vantage | `docs/SYSTEMS/environment-reactions.md` §7 | Yes — `# 7. Golden Hour Dusk Vantage` |
| 3 | Streak Aurora Nights | `docs/SYSTEMS/environment-reactions.md` §2 | Yes — `# 2. Streak Aurora Nights — the sentimental special case` |
| 3 | Ship-It Ladder — escalating dev-win celebration | `docs/SYSTEMS/companionship-rituals.md` §3 | Yes — `# 3. Ship-It Ladder — escalating dev-win celebration` |
| 3 | Bunting — cheek-rubbing the P button | `docs/SYSTEMS/companionship-rituals.md` §4 | Yes — `# 4. Bunting — cheek-rubbing the P button` |
| 3 | Milestone Pilgrimage | `docs/SYSTEMS/companionship-rituals.md` §6 | Yes — `# 6. Milestone Pilgrimage — revisiting the places where life happened` |
| 3 | Evening Wind-Down Ritual | `docs/SYSTEMS/idle-life-and-rest.md` §8 | Yes — `# 8. Evening Wind-Down Ritual` |

## Coverage Summary

- **42** tiered features (9 Tier-1 flagship + 14 Tier-2 depth + 19 Tier-3 delight)
- **42** covered and grep-verified landed
- **0** gaps

## Intentional Non-Coverage — Dossier Appendix (Dropped)

The dossier's lossless rule keeps dropped items in the dossier itself as their permanent home, not in any concept. Confirmed by grep across `docs/SYSTEMS/` and `docs/REFERENCE/`:

| Dropped Item | Concept-side trace | Correct? |
|---|---|---|
| The Tasteful Hairball | No mention anywhere | Yes — dossier parks it as a future surprise-catalog candidate; no forward pointer was promised |
| The Dangler | No mention anywhere | Yes — dossier defers it (new MCP surface, safety-gated); no forward pointer was promised |
| Boing! Startle Toys & the Brave Re-Approach | No mention of the dropped item by name; its *payload* (startle arch) is separately and correctly canonized in `emotional-body-language.md` §3 Arch Grammar, which the dossier explicitly says absorbs it | Yes — the spring-coil object itself stays dropped; only its already-generalized payload landed, exactly as designed |
| Rebound Rally | Explicitly forward-referenced: `docs/SYSTEMS/play-bouts.md` §8 "Future Escalations" and `docs/REFERENCE/journal-and-dreams.md` (forward-registered `play_memory` journal type) | Yes — dossier promised this exact forward pointer; confirmed landed |
| Bird Flush Stalk | Explicitly forward-referenced: `docs/SYSTEMS/ambient-wildlife.md` "Future Species" appendix, listed as a future sixth species | Yes — dossier promised this exact forward pointer; confirmed landed |
| Commit Garden | No mention anywhere | Yes — dossier says "captured to BACKLOG," not owed a concept-side pointer |
| Wetlands Pond Life | No mention of the dropped feature (the only "wetland" hits found are the unrelated biome-table entries in `world-terrain-parallax.md`/`biomes-and-terrain-objects.md`, pre-existing content) | Yes — dossier says its motion content survives via Puddle Days & Dabbing (which is covered above), not via a wetlands-specific pointer |
| Waiting at the Door | No mention anywhere | Yes — dossier backlogs it pending RoutineEngine prediction validation; no forward pointer was promised |

All 8 dropped items check out against what the dossier actually promised for each (either total silence or a specific named forward-reference) — no silent vanishing, no over-eager premature landing.

## Doc-Consistency Note (RESOLVED 2026-07-04, audit REVISE)

Three same-wave cross-link timing artifacts in `companionship-rituals.md` were flagged during authoring and are now all fixed (none was ever a coverage gap):

1. **Sleep Geography link** — pointed at `/REFERENCE/personality-emotional-state.md`; Sleep Geography's real home is `docs/SYSTEMS/idle-life-and-rest.md#4-sleep-geography`. **Fixed** (commit `378cd9e`).
2. **Camera edge-clamp "no section yet" claim** — stale once `camera-and-parallax.md` landed its `# Camera Dwell & Edge-Clamp` section. **Fixed** (commit `378cd9e`).
3. **World-objects decal "no section yet" claim** (the 3rd artifact this note originally missed) — was still asserting `world-objects-system.md` "does not yet carry a decal section (grep-verified)" after that concept landed its `# Memory-Decal Budget (Milestone Marks)` section. **Fixed** in the punch-list REVISE — companionship-rituals now cross-links the real decal section.

Coverage itself (42/42 tiered features) was never affected by any of the three; these were citation-freshness fixes inside otherwise-correct docs.

## Generator Check

```
$ node scripts/generate-docs-index.mjs && node scripts/generate-docs-index.mjs --check
Generated docs/index.md and per-section indexes.
OK — bundle is clean.
```
