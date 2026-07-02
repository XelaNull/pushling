---
type: Feature
title: Pushling Feature Roadmap
description: The 5-tier future feature roadmap (quick wins through community/social) plus the aspirational brew/npm distribution story — non-prescriptive intent-canon, preserved in full.
status: Future
tags: [roadmap, future, distribution]
timestamp: 2026-07-02T00:00:00Z
---

Everything below is **aspirational, non-prescriptive intent** —
`PUSHLING_VISION.md`'s wishlist for where the project could go next, not a
committed backlog with dates or owners. Per this migration's rule for
FEATURES/ concepts, every item is preserved in full regardless of how far
it is from being built; nothing here is pruned as "stale" just because it
hasn't shipped. 📐 marks a planned-but-unbuilt item — since every item on
this page is by definition unbuilt, the marker is used sparingly, only
where a note calls out something with *partial* groundwork already in
place, to distinguish it from a pure blank-slate idea.

# Tier 1: Quick Wins

- **Streak counter on HUD** — display consecutive commit-days; the vision
  doc notes this is "already tracked in DB." `creature.streak_days` is
  indeed a live column (confirmed via `GameCoordinator+DreamEngine`-adjacent
  schema reads elsewhere in this wave), so this tier's premise — the data
  exists, only the HUD surface doesn't — holds.
- **Language-specific eating particles** — CSS = glitter, Rust = sparks,
  Python = blue swirls, etc.
- **Morning greeting variation** — different wake speech based on absence
  duration (the Core Loop table already describes duration-scaled wake
  animations; this item is about varying the *speech*, not the animation,
  by the same signal).

# Tier 2: Engagement Loops

- **Achievement badges gallery** — a visible list of earned mutations and
  milestones in the Stats popup. 📐 Partial groundwork exists: the 10 real
  `MutationBadge` earns are already tracked and persisted (see
  [the surprise catalog](/REFERENCE/surprise-catalog.md#mutation-badges-hidden-achievements)) —
  what's missing is a gallery UI surfacing them, not the underlying data.
- **Offline dream sequences** — a brief dream replay of highlights on wake
  after 8+ hours away. 📐 Closely adjacent to, but distinct from, both
  shipped dream mechanics (see
  [journal & dreams](/REFERENCE/journal-and-dreams.md)) — the wake-time
  dream bubble already renders *a* fragment on wake, but not a
  multi-highlight "replay."
- **Seasonal biome events** — spring flowers, autumn leaves, winter snow on
  terrain.
- **Creature photo booth** — tap-hold to capture creature state as a
  shareable image.

# Tier 3: Developer Workflow Integration

- **Build status awareness** — watch the build directory; celebrate green,
  worry at red.
- **Debugging pattern detection** — rapid commit-revert cycles trigger
  empathetic reactions.
- **Language affinity drift** — personality specialty shifts based on a
  30-day rolling window of commit languages.
- **Break reminders** — creature yawns after 2+ hours of sustained
  commits.
- **PR merge reactions** — detect merges to main, celebrate collaboration.

# Tier 4: Deep Engagement

- **Creature scrapbook** — a visual timeline of milestones: first word,
  evolution, biggest commits.
- **Secret evolution variants** — specific personality + mutation
  combinations unlock rare visual traits.
- **Accelerometer integration** — tilt the laptop, the creature tumbles.
- **Ambient light sensor** — lights dim, the creature gets sleepy.
- **Prestige/legacy system** — after Apex + 1 year, the creature ascends
  and leaves traits for a next generation.

# Tier 5: Community & Social

- **Creature card export** — a shareable image with creature stats and
  personality.
- **Multi-machine sync** — iCloud sync so the creature follows a developer
  across devices.
- **Creature visiting** — opt-in brief visits to other developers'
  Touch Bars.
- **Global surprise events** — rare events firing for all Pushling users
  simultaneously.

# Aspirational Distribution Story

`PUSHLING_VISION.md`'s Installation section presents `brew install --cask
pushling` and `npm install -g pushling && pushling install` as the
install path. **Correction to this migration's own earlier finding:** an
initial pass through this wave assumed neither existed in any form; a later,
more careful check (SP2b) found that's wrong. `bin/pushling` (~660 lines) and
`bin/pushling-voice-setup` (~500 lines) are fully-implemented, non-stub
bash CLIs, and `Formula/pushling.rb` is a real (if unpublishable) Homebrew
cask — see [build, run, and deploy](/OPERATIONS/build-run-deploy.md) for the
verified detail. What's genuinely still aspirational: `Formula/pushling.rb`
isn't wired to a published Homebrew tap (placeholder `sha256`, no matching
GitHub release), `bin/pushling` isn't copied into the app bundle or
`/usr/local/bin` by any of `build.sh`/`install.sh`/`run.sh`/`reload.sh` (a
repo checkout is required to invoke it directly), and `npm install -g
pushling` specifically has no `bin` entry in `mcp/package.json` and no npm
publish config — likely aspirational, not verified either way. The actual,
current *installed-app* path remains `./install.sh` — a release build
installed directly to `/Applications` with a `com.pushling.daemon`
LaunchAgent registered for login auto-start (per `pushling/CLAUDE.md` and
`install.sh` itself). This is recorded here, in FEATURES/, specifically
because packaging-and-distribution *is* legitimate forward-looking intent —
unlike a SYSTEMS/ concept (which must describe only what's live), this is
exactly where an aspirational install story belongs. The CLI surface the
vision doc describes (`pushling track`, `pushling untrack`, `pushling hooks
install/remove`, `pushling export`/`import`, `pushling voice download`) is
preserved here in full as the target CLI contract, and — unlike this
section's original draft — most of it is not merely a target: `bin/pushling`
already implements nearly all of it. Only its packaging/distribution
(published tap, npm global install) remains unbuilt.

# Citations

[1] `PUSHLING_VISION.md` — Future Feature Roadmap; Installation
[2] `pushling/CLAUDE.md` — Essential Commands (the real, current install/build/run/deploy story)
[3] `install.sh`, `build.sh`, `run.sh`, `reload.sh` (actual scripts vs. the aspirational `brew`/`npm` commands)
[4] [the surprise catalog](/REFERENCE/surprise-catalog.md) (mutation-badge data already backing the Tier 2 achievement-gallery idea)
[5] [journal & dreams](/REFERENCE/journal-and-dreams.md) (existing dream mechanics adjacent to the Tier 2 offline-dream-sequence idea)
