# Wiring TODO — Remaining Integration Gaps

## IPC CommandRouter: All 9 Tool Handlers Are Stubs

The CommandRouter returns hardcoded placeholder data for every pushling_* tool. The subsystems are built and wired in GameCoordinator but CommandRouter has no reference to dispatch to them.

**Root cause:** `GameCoordinator.wireCommandRouter()` is empty with a TODO comment. CommandRouter only holds EventBuffer and SessionManager references.

**Fix:** Pass GameCoordinator reference to CommandRouter, then replace each stub handler with real dispatch.

| Handler | Status | Dispatch To |
|---------|--------|------------|
| handleSense | STUB | EmotionalState, Personality, CreatureNode, WorldManager, DB |
| handleMove | STUB | AIDirectedLayer via BehaviorStack |
| handleExpress | STUB | AIDirectedLayer (expression-to-LayerOutput mapping) |
| handleSpeak | STUB | SpeechCoordinator.speak() (production-ready) |
| handlePerform | STUB | BehaviorStack + TaughtBehaviorEngine |
| handleWorld | STUB | WorldManager (weather, objects, companions) |
| handleRecall | STUB | DatabaseManager journal queries |
| handleTeach | STUB | ChoreographyParser + TaughtBehaviorEngine |
| handleNurture | STUB | HabitEngine, PreferenceEngine, QuirkEngine, RoutineEngine |
| handleConnect | MOSTLY REAL | SessionManager (done), creature state (stub) |
| handleDisconnect | REAL | SessionManager (done) |

## Touch Events: FIXED (commit 1d5eb4b)

Touch Bar events now forward to TouchTracker → GestureRecognizer → CreatureTouchHandler.

## Other Known Gaps (from previous audit)

- Hatching ceremony not triggered on first launch (creature hardcoded to .critter)
- Creature state not loaded from SQLite (hardcoded defaults)
- World objects not loaded from SQLite
- Extended cat behaviors not registered with BehaviorSelector
