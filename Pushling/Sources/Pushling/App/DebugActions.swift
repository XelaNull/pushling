// DebugActions.swift — Debug menu action handler
// Provides all debug/testing actions for the menu bar Debug submenu.
// Communicates with PushlingScene to trigger animations, stage changes,
// speech, weather, and surprises without waiting for real commits.

import AppKit
import SpriteKit

// MARK: - Debug Actions

/// Handles all debug menu actions. Holds a weak reference to the scene
/// and delegates all work to PushlingScene's debug methods.
final class DebugActions {

    // MARK: - Dependencies

    private weak var scene: PushlingScene?

    // MARK: - Init

    init(scene: PushlingScene?) {
        self.scene = scene
    }

    /// Update the scene reference (e.g., after Touch Bar re-creation).
    func updateScene(_ scene: PushlingScene?) {
        self.scene = scene
    }

    // MARK: - Feed Commits

    func feedSmallCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Fix typo in README",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 1,
            linesAdded: 5,
            linesRemoved: 5,
            languages: ["md"],
            isMerge: false,
            isRevert: false,
            isForcePush: false,
            branch: "main",
            timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .normal)
    }

    func feedLargeCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Refactor entire authentication module for OAuth2 compliance",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 12,
            linesAdded: 150,
            linesRemoved: 80,
            languages: ["swift", "swift", "swift"],
            isMerge: false,
            isRevert: false,
            isForcePush: false,
            branch: "feature/auth",
            timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .largeRefactor)
    }

    func feedTestCommit() {
        guard let scene = scene else { logNoScene(); return }
        let commit = CommitData(
            message: "Add unit tests for XP calculator edge cases",
            sha: String(UUID().uuidString.prefix(7)),
            repoName: "pushling",
            filesChanged: 3,
            linesAdded: 45,
            linesRemoved: 10,
            languages: ["swift", "test"],
            isMerge: false,
            isRevert: false,
            isForcePush: false,
            branch: "main",
            timestamp: Date()
        )
        scene.debugFeedCommit(commit: commit, type: .test)
    }

    func feedBatchCommits(count: Int) {
        guard let scene = scene else { logNoScene(); return }
        NSLog("[Pushling/Debug] Feeding %d commits...", count)

        for i in 0..<count {
            let delay = Double(i) * 0.3  // 300ms stagger
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                [weak scene] in
                guard let scene = scene else { return }
                let commit = CommitData(
                    message: "Batch commit \(i + 1) of \(count)",
                    sha: String(UUID().uuidString.prefix(7)),
                    repoName: "pushling",
                    filesChanged: Int.random(in: 1...5),
                    linesAdded: Int.random(in: 5...50),
                    linesRemoved: Int.random(in: 0...20),
                    languages: ["swift"],
                    isMerge: false,
                    isRevert: false,
                    isForcePush: false,
                    branch: "main",
                    timestamp: Date()
                )
                scene.debugFeedCommit(commit: commit, type: .normal)
            }
        }
    }

    // MARK: - Stage Changes

    func setStage(_ stage: GrowthStage) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSetStage(stage)
    }

    // MARK: - Evolution

    func evolveNow() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugEvolve()
    }

    // MARK: - Speech

    func sayHello() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSpeak(text: "hello!", style: .say)
    }

    func sayLongMessage() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSpeak(
            text: "I have been watching you code all day and I think "
                + "this refactor is going to be really good",
            style: .say
        )
    }

    func testFirstWord() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugFirstWord()
    }

    // MARK: - Weather

    func setWeather(_ state: WeatherState) {
        guard let scene = scene else { logNoScene(); return }
        scene.debugSetWeather(state)
    }

    // MARK: - Interactions

    func testCatBehavior() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugTriggerCatBehavior()
    }

    // MARK: - Info

    func showStats() {
        guard let scene = scene else { logNoScene(); return }
        scene.debugLogStats()
    }

    // MARK: - Private

    private func logNoScene() {
        NSLog("[Pushling/Debug] No scene available — Touch Bar may not be active")
    }
}
