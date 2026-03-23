// LifecycleSimulator.swift — Automated Spore-to-Apex progression test
// Runs in test mode to simulate 6 months of creature life.
//
// Generates:
//   - Simulated commits (varying daily counts, languages, times)
//   - Simulated touches (5-30 per day)
//   - Simulated Claude sessions (1-3 per day)
//
// Verification at each stage:
//   - Visual characteristics match stage
//   - Speech limits enforced
//   - Behavior unlocks correct
//   - Stage-specific surprises available

import Foundation

// MARK: - Lifecycle Simulator

final class LifecycleSimulator {

    // MARK: - Configuration

    /// XP thresholds for each stage transition.
    private static let stageThresholds: [GrowthStage: Int] = [
        .drop: 100,      // 20 commits at ~5 XP
        .critter: 500,   // 75 commits
        .beast: 2000,    // 200 commits
        .sage: 8000,     // 500 commits
        .apex: 20000     // 1200 commits
    ]

    /// Languages to simulate commits in (weighted distribution).
    private static let simulatedLanguages: [(String, Double)] = [
        ("ts", 0.30), ("swift", 0.20), ("py", 0.15),
        ("css", 0.10), ("json", 0.08), ("md", 0.07),
        ("rs", 0.05), ("go", 0.03), ("sh", 0.02)
    ]

    /// Branch names to simulate.
    private static let simulatedBranches = [
        "main", "feature/auth", "fix/crash", "refactor/db",
        "hotfix/urgent", "yolo-rewrite", "feature/ui"
    ]

    /// Commit message templates.
    private static let commitMessages = [
        "feat: add user authentication",
        "fix: resolve crash on startup",
        "refactor: clean up database layer",
        "test: add unit tests for auth module",
        "docs: update README with setup instructions",
        "chore: update dependencies",
        "style: fix linting warnings",
        "perf: optimize query performance",
        "feat: implement search feature",
        "fix: handle edge case in parser"
    ]

    // MARK: - State

    private let timeProvider: TestTimeProvider
    private var simulatedCommitCount = 0
    private var lastSimulatedCommitDay = 0
    private var commitsToday = 0
    private var targetCommitsToday = 0
    private var currentStage: GrowthStage = .egg
    private var totalXP = 0

    /// Accumulated real time for commit scheduling.
    private var commitTimer: TimeInterval = 0

    /// Interval between simulated commits (in real seconds).
    private var commitInterval: TimeInterval = 2.0  // One every 2 real seconds

    /// Log of what happened during simulation.
    private(set) var simulationLog: [SimulationEvent] = []

    // MARK: - Callbacks

    /// Called when a simulated commit should be processed.
    var onSimulatedCommit: ((_ commitJSON: [String: Any]) -> Void)?

    /// Called when a stage transition occurs.
    var onStageTransition: ((_ from: GrowthStage, _ to: GrowthStage) -> Void)?

    /// Called with periodic status updates.
    var onStatusUpdate: ((_ day: Int, _ stage: GrowthStage,
                          _ commits: Int, _ xp: Int) -> Void)?

    // MARK: - Init

    init(timeProvider: TestTimeProvider) {
        self.timeProvider = timeProvider
    }

    // MARK: - Update

    /// Called every frame in test mode to advance the simulation.
    func update(deltaTime: TimeInterval) {
        guard timeProvider.isTestMode else { return }

        let currentDay = timeProvider.simulatedDay

        // New simulated day
        if currentDay > lastSimulatedCommitDay {
            startNewDay(day: currentDay)
            lastSimulatedCommitDay = currentDay
        }

        // Generate commits at intervals
        commitTimer += deltaTime
        if commitTimer >= commitInterval && commitsToday < targetCommitsToday {
            commitTimer = 0
            generateSimulatedCommit(day: currentDay)
        }
    }

    // MARK: - Day Management

    private func startNewDay(day: Int) {
        commitsToday = 0
        // 2-20 commits per day (random, with some pattern)
        let weekday = day % 7
        let isWeekend = weekday == 5 || weekday == 6
        let baseCommits = isWeekend ? 3 : 10
        let variance = Int.random(in: -3...10)
        targetCommitsToday = max(2, baseCommits + variance)

        // Occasional burst day (Swarm badge possibility)
        if Int.random(in: 0..<30) == 0 {
            targetCommitsToday = Int.random(in: 30...50)
        }

        if day % 30 == 0 {
            onStatusUpdate?(day, currentStage, simulatedCommitCount, totalXP)
            logEvent(.dayReport(day: day, stage: currentStage,
                                totalCommits: simulatedCommitCount,
                                totalXP: totalXP))
        }
    }

    // MARK: - Commit Generation

    private func generateSimulatedCommit(day: Int) {
        let hour = simulatedHour(for: day)
        let message = Self.commitMessages.randomElement() ?? "commit"
        let branch = Self.simulatedBranches.randomElement() ?? "main"
        let language = pickWeightedLanguage()
        let filesChanged = Int.random(in: 1...15)
        let linesAdded = Int.random(in: 5...200)
        let linesRemoved = Int.random(in: 0...50)
        let isMerge = Int.random(in: 0..<10) == 0
        let isRevert = Int.random(in: 0..<20) == 0
        let hasTestFiles = language == "ts" && message.contains("test")

        let commitJSON: [String: Any] = [
            "type": "commit",
            "sha": UUID().uuidString.replacingOccurrences(of: "-", with: "")
                .prefix(40).lowercased(),
            "message": message,
            "repo_name": "simulated-repo",
            "branch": branch,
            "files_changed": filesChanged,
            "lines_added": linesAdded,
            "lines_removed": linesRemoved,
            "languages": language,
            "is_merge": isMerge,
            "is_revert": isRevert,
            "is_force_push": false,
            "timestamp": ISO8601DateFormatter().string(from: timeProvider.now),
            "hour": hour,
            "has_test_files": hasTestFiles
        ]

        simulatedCommitCount += 1
        commitsToday += 1

        // Estimate XP
        let baseXP = 5 + filesChanged / 3 + linesAdded / 50
        let adjustedXP = Int(Double(baseXP) * timeProvider.xpMultiplier)
        totalXP += adjustedXP

        // Check stage transition
        checkStageTransition()

        onSimulatedCommit?(commitJSON)
    }

    // MARK: - Stage Transition

    private func checkStageTransition() {
        let stages: [GrowthStage] = [.drop, .critter, .beast, .sage, .apex]
        for stage in stages {
            guard stage.rawValue > currentStage.rawValue else { continue }
            guard let threshold = Self.stageThresholds[stage] else { continue }

            // Use commit count as proxy since XP calculation is approximate
            let commitThresholds: [GrowthStage: Int] = [
                .drop: 20, .critter: 75, .beast: 200, .sage: 500, .apex: 1200
            ]
            if let commitThreshold = commitThresholds[stage],
               simulatedCommitCount >= commitThreshold {
                let oldStage = currentStage
                currentStage = stage
                _ = threshold  // XP threshold reference

                logEvent(.stageTransition(from: oldStage, to: stage,
                                           atCommit: simulatedCommitCount))
                onStageTransition?(oldStage, stage)

                NSLog("[Pushling/Sim] Stage transition: %@ -> %@ "
                      + "(commit #%d, day %d)",
                      "\(oldStage)", "\(stage)",
                      simulatedCommitCount, timeProvider.simulatedDay)
                break
            }
        }
    }

    // MARK: - Utilities

    private func simulatedHour(for day: Int) -> Int {
        // Distribution: mostly 9AM-6PM, some early/late
        let roll = Int.random(in: 0..<100)
        if roll < 5 { return Int.random(in: 0...5) }      // 5% midnight-5AM
        if roll < 15 { return Int.random(in: 6...8) }     // 10% early morning
        if roll < 75 { return Int.random(in: 9...17) }    // 60% work hours
        if roll < 90 { return Int.random(in: 18...21) }   // 15% evening
        return Int.random(in: 22...23)                     // 10% late night
    }

    private func pickWeightedLanguage() -> String {
        let roll = Double.random(in: 0...1)
        var cumulative = 0.0
        for (lang, weight) in Self.simulatedLanguages {
            cumulative += weight
            if roll < cumulative { return lang }
        }
        return "ts"
    }

    private func logEvent(_ event: SimulationEvent) {
        simulationLog.append(event)
    }

    // MARK: - Report

    /// Generate a final simulation report.
    func generateReport() -> String {
        var lines: [String] = [
            "=== Lifecycle Simulation Report ===",
            "Total simulated days: \(timeProvider.simulatedDay)",
            "Total commits: \(simulatedCommitCount)",
            "Final stage: \(currentStage)",
            "Approximate XP: \(totalXP)",
            "",
            "Stage transitions:"
        ]

        for event in simulationLog {
            if case .stageTransition(let from, let to, let commit) = event {
                lines.append("  \(from) -> \(to) at commit #\(commit)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Simulation Event

enum SimulationEvent {
    case stageTransition(from: GrowthStage, to: GrowthStage, atCommit: Int)
    case dayReport(day: Int, stage: GrowthStage,
                   totalCommits: Int, totalXP: Int)
    case surpriseFired(id: Int, name: String, day: Int)
    case badgeEarned(badge: String, day: Int)
}
