# Wiring TODO — Integration Status

**Last updated:** 2026-03-15
**Status:** ALL ITEMS COMPLETE

## IPC CommandRouter: ✅ ALL 9 HANDLERS DISPATCH TO REAL SUBSYSTEMS

Fixed in commit 78979b6. CommandRouter now has a `weak var gameCoordinator` reference. Every handler dispatches to the real subsystem.

| Handler | Status | Dispatches To |
|---------|--------|---------------|
| handleSense | ✅ REAL | EmotionalState, Personality, WorldManager, SQLite |
| handleMove | ✅ REAL | AIDirectedLayer via BehaviorStack |
| handleExpress | ✅ REAL | ExpressionMapping → AIDirectedLayer |
| handleSpeak | ✅ REAL | SpeechCoordinator.speak() with filtering |
| handlePerform | ✅ REAL | BehaviorStack + TaughtBehaviorEngine |
| handleWorld | ✅ REAL | WorldManager (weather, objects, companions, sounds) |
| handleRecall | ✅ REAL | DatabaseManager journal queries |
| handleTeach | ✅ REAL | ChoreographyParser + SQLite persistence |
| handleNurture | ✅ REAL | HabitEngine, PreferenceEngine, QuirkEngine, RoutineEngine |
| handleConnect | ✅ REAL | SessionManager + real creature state from DB |
| handleDisconnect | ✅ REAL | SessionManager |

## Touch Events: ✅ FIXED

Touch Bar events forward to TouchTracker → GestureRecognizer → CreatureTouchHandler.

## Previously Known Gaps: ✅ ALL FIXED

- ✅ Hatching ceremony triggered on first launch (GameCoordinator+Hatching.swift)
- ✅ Creature state loaded from SQLite (not hardcoded)
- ✅ World objects loaded from SQLite on startup
- ✅ All 12 cat behaviors registered with BehaviorSelector (including knocking_things_off and if_i_fits_i_sits)
- ✅ PersonalityFilter called from AutonomousLayer, CreatureNode, BlendController
- ✅ AbsenceAnimations wired to session lifecycle
- ✅ MutationSystem triggered on commits
- ✅ Nurture engines instantiated and receiving commands
- ✅ Voice callback wired (SpeechCoordinator → VoiceIntegration)
- ✅ Surprise variants checking cross-system context
- ✅ Object attraction scoring + interaction engine in autonomous layer
- ✅ Speech bubbles clamped to scene bounds

## Remaining Minor Items

- `sense("visual")` screenshot capture — returns text description (screenshot not implemented)
- 2 TODOs in codebase: pupil gaze targeting, screenshot capture
- TestMode/LifecycleSimulator not wired to debug menu (test infrastructure only)
