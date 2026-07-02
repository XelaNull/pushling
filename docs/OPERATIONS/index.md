<!-- GENERATED — do not hand-edit. Run: node scripts/generate-docs-index.mjs -->

# OPERATIONS Index

- [Build, Run, and Deploy Pushling](build-run-deploy.md) — What build.sh / run.sh / reload.sh / install.sh actually do — versioning, codesign, LaunchAgent setup, and the hot-reload deploy path — verified against the shipped scripts.
- [Pushling Development Pitfalls](development-pitfalls.md) — Known failure patterns and their required mitigations — verified against the shipped Swift/TypeScript/shell code, not just the design docs.
- [Embodiment Language Guide](embodiment-language-guide.md) — Writing rules for tool descriptions, awakening text, and response formatting in the creature's first-person embodied voice — with do/don't examples and the read-aloud litmus test.
- [Pushling Persistence, Crash Recovery, and Hot-Reload](persistence-and-recovery.md) — The heartbeat liveness file, crash-detection-on-launch flow, daily VACUUM INTO backups, and the HotReloadMonitor directory-watch mechanism that together let creature state survive restarts, crashes, and rebuilds.
- [Pushling Review Focus Areas](review-focus-areas.md) — Per-skill tuning for reviewing this repo — the five diagnose investigation tracks, the polish extra category and its CONCURRENCY meaning, the spec-check rule, and the code-quality line-length ceilings, verified against current line counts.
