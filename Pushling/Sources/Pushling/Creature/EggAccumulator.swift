// EggAccumulator.swift — Progressively learns about the developer from commits
//
// During the egg stage, each commit is silently absorbed and its data
// accumulated. After 5 commits, enough data exists to compute a unique
// personality and visual traits. The egg then cracks open into a styled Drop.

import Foundation

final class EggAccumulator {

    // MARK: - Accumulated Data

    private(set) var commitCount = 0
    var languageCounts: [String: Int] = [:]
    private(set) var totalMessageLength = 0
    private(set) var totalFilesChanged = 0
    private(set) var totalLinesAdded = 0
    private(set) var totalLinesRemoved = 0
    private(set) var repoNames: Set<String> = []
    private(set) var commitTimestamps: [Date] = []

    /// Number of commits required before the egg is ready to hatch.
    static let hatchThreshold = 5

    // MARK: - Record

    /// Record data from a commit. Call for each commit during the egg stage.
    func record(_ commit: CommitData) {
        commitCount += 1
        totalMessageLength += commit.message.count
        totalFilesChanged += commit.filesChanged
        totalLinesAdded += commit.linesAdded
        totalLinesRemoved += commit.linesRemoved
        repoNames.insert(commit.repoName)
        commitTimestamps.append(commit.timestamp)

        // Parse languages (may be CSV string or array)
        for lang in commit.languages where !lang.isEmpty {
            languageCounts[lang, default: 0] += 1
        }
    }

    /// Whether enough data has been accumulated to hatch.
    var isReadyToHatch: Bool { commitCount >= Self.hatchThreshold }

    /// Progress toward hatching (0.0 to 1.0).
    var hatchProgress: Double {
        min(1.0, Double(commitCount) / Double(Self.hatchThreshold))
    }

    // MARK: - Personality Computation

    /// Compute personality from accumulated commit data.
    func computePersonality() -> Personality {
        let avgMessageLength = commitCount > 0
            ? Double(totalMessageLength) / Double(commitCount) : 30.0
        let avgFilesPerCommit = commitCount > 0
            ? Double(totalFilesChanged) / Double(commitCount) : 2.0

        // Energy: burst frequency — were commits clustered or spread out?
        let energy: Double
        if commitTimestamps.count >= 2 {
            let intervals = zip(commitTimestamps, commitTimestamps.dropFirst())
                .map { $1.timeIntervalSince($0) }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            // Short intervals (< 5 min) = high energy, long (> 30 min) = low
            energy = max(0, min(1, 1.0 - (avgInterval / 1800.0)))
        } else {
            energy = 0.5
        }

        // Verbosity: average message length
        let verbosity = max(0, min(1, (avgMessageLength - 10) / 60.0))

        // Focus: files per commit (fewer = more focused)
        let focus = max(0, min(1, 1.0 - (avgFilesPerCommit - 1) / 10.0))

        // Discipline: timing consistency (limited with few commits)
        let discipline = 0.5  // neutral with so few data points

        // Specialty: dominant language
        let specialty = dominantLanguageCategory()

        return Personality(
            energy: energy,
            verbosity: verbosity,
            focus: focus,
            discipline: discipline,
            specialty: specialty
        )
    }

    // MARK: - Visual Traits Computation

    /// Compute visual traits from accumulated commit data.
    func computeVisualTraits() -> VisualTraits {
        let personality = computePersonality()
        let repoCount = repoNames.count

        return VisualTraits(
            baseColorHue: personality.specialty.baseColorHue,
            bodyProportion: personality.focus,
            furPattern: FurPattern.fromRepoCount(repoCount),
            tailShape: TailShape.fromCategory(personality.specialty),
            eyeShape: EyeShape.fromAverageMessageLength(
                commitCount > 0
                    ? Double(totalMessageLength) / Double(commitCount)
                    : 30.0
            )
        )
    }

    // MARK: - Private

    private func dominantLanguageCategory() -> LanguageCategory {
        guard let topLang = languageCounts.max(by: { $0.value < $1.value })
        else { return .polyglot }
        return LanguageCategory.extensionMap[topLang.key] ?? .polyglot
    }
}
