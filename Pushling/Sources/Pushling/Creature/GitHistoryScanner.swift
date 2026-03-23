// GitHistoryScanner.swift — Scans all discoverable git repos on the machine
// Analyzes commit patterns to compute initial personality axes and visual traits.
//
// Runs ONCE at birth (first launch with no creature). Background thread.
// 30-second timeout — uses whatever data was gathered.
// All git operations are read-only (git log, git config).

import Foundation

// MARK: - Git Scan Result

/// Aggregated results from scanning all repos.
struct GitScanResult {
    /// Computed personality axes.
    let personality: Personality

    /// Computed visual traits.
    let visualTraits: VisualTraits

    /// Total number of repos found.
    let repoCount: Int

    /// Total commits by this user across all repos.
    let totalCommits: Int

    /// Git user.email used for filtering.
    let userEmail: String

    /// Commit timestamps (for circadian cycle seeding).
    let commitTimestamps: [Date]

    /// Per-repo commit counts (for hatching ceremony montage).
    let repoCommitCounts: [(name: String, commits: Int)]

    /// Per-language commit counts (for hatching ceremony montage).
    let languageCounts: [(language: String, count: Int)]

    /// Total lines added across all repos.
    let totalLinesAdded: Int

    /// Total lines deleted across all repos.
    let totalLinesDeleted: Int

    /// Whether the scan completed before timeout.
    let completed: Bool

    /// Empty result when no repos are found.
    static let empty = GitScanResult(
        personality: .neutral,
        visualTraits: .neutral,
        repoCount: 0,
        totalCommits: 0,
        userEmail: "unknown@pushling",
        commitTimestamps: [],
        repoCommitCounts: [],
        languageCounts: [],
        totalLinesAdded: 0,
        totalLinesDeleted: 0,
        completed: true
    )
}

// MARK: - Git History Scanner

/// Scans all discoverable git repos and computes personality + visual traits.
final class GitHistoryScanner {

    // MARK: - Constants

    /// Maximum scan duration before we use whatever we've gathered.
    static let timeoutSeconds: TimeInterval = 30.0

    /// Directories to search for git repos.
    /// Avoids ~/Desktop, ~/Documents, ~/Downloads, and ~ (home) which
    /// trigger macOS TCC permission prompts. Uses developer-convention paths.
    static let searchDirs: [String] = [
        "~/Projects", "~/Developer",
        "~/code", "~/github", "~/repos", "~/src", "~/work"
    ]

    /// Maximum depth when searching for .git directories.
    static let maxSearchDepth = 4

    /// Directories to skip during search.
    static let skipDirs: Set<String> = [
        "node_modules", ".Trash", "Library", ".cache", ".npm",
        ".cargo", "vendor", "Pods", ".build", "build", "dist",
        ".git", "DerivedData", ".cocoapods", "Homebrew",
        "Applications", "Music", "Movies", "Pictures"
    ]

    // MARK: - Scan

    /// Perform the full git history scan.
    /// Runs synchronously — call from a background thread.
    /// - Returns: Aggregated scan results.
    static func scan() -> GitScanResult {
        let startTime = Date()
        let timeoutDate = startTime.addingTimeInterval(timeoutSeconds)

        // 1. Get git user.email
        let email = getGitUserEmail()
        NSLog("[Pushling/GitScan] Scanning as: %@", email)

        // 2. Discover repos
        let repos = discoverRepos(deadline: timeoutDate)
        NSLog("[Pushling/GitScan] Found %d repos", repos.count)

        guard !repos.isEmpty else {
            NSLog("[Pushling/GitScan] No repos found — using defaults")
            return .empty
        }

        // 3. Analyze each repo
        var allTimestamps: [Date] = []
        var allExtensionCounts: [String: Int] = [:]
        var totalLinesAdded: Int = 0
        var totalLinesDeleted: Int = 0
        var totalMessageLength: Int = 0
        var totalCommits: Int = 0
        var totalFilesChanged: Int = 0
        var repoCommitCounts: [(String, Int)] = []
        var commitHours: [Int] = []  // for burst detection
        var commitTimeDiffs: [TimeInterval] = []  // for regularity

        for repoPath in repos {
            // Check timeout
            guard Date() < timeoutDate else {
                NSLog("[Pushling/GitScan] Timeout reached — "
                      + "using %d repos analyzed", repoCommitCounts.count)
                break
            }

            let repoName = (repoPath as NSString).lastPathComponent
            let analysis = analyzeRepo(at: repoPath, email: email,
                                        deadline: timeoutDate)

            if analysis.commitCount > 0 {
                repoCommitCounts.append((repoName, analysis.commitCount))
                allTimestamps.append(contentsOf: analysis.timestamps)
                totalLinesAdded += analysis.linesAdded
                totalLinesDeleted += analysis.linesDeleted
                totalMessageLength += analysis.totalMessageLength
                totalCommits += analysis.commitCount
                totalFilesChanged += analysis.totalFilesChanged
                commitHours.append(contentsOf: analysis.commitHours)
                commitTimeDiffs.append(contentsOf: analysis.timeDiffs)

                for (ext, count) in analysis.extensionCounts {
                    allExtensionCounts[ext, default: 0] += count
                }
            }
        }

        // 4. Compute personality axes
        let personality = computePersonality(
            totalCommits: totalCommits,
            commitHours: commitHours,
            timeDiffs: commitTimeDiffs,
            avgMessageLength: totalCommits > 0
                ? Double(totalMessageLength) / Double(totalCommits) : 0,
            avgFilesPerCommit: totalCommits > 0
                ? Double(totalFilesChanged) / Double(totalCommits) : 0,
            repoCount: repoCommitCounts.count,
            extensionCounts: allExtensionCounts,
            timestamps: allTimestamps
        )

        // 5. Compute visual traits
        let visualTraits = computeVisualTraits(
            extensionCounts: allExtensionCounts,
            linesAdded: totalLinesAdded,
            linesDeleted: totalLinesDeleted,
            repoCount: repoCommitCounts.count,
            specialty: personality.specialty,
            avgMessageLength: totalCommits > 0
                ? Double(totalMessageLength) / Double(totalCommits) : 30
        )

        // 6. Sort language counts for montage
        let langCounts = allExtensionCounts.sorted { $0.value > $1.value }
            .prefix(20)
            .map { (language: $0.key, count: $0.value) }

        let elapsed = Date().timeIntervalSince(startTime)
        let completed = Date() < timeoutDate
        NSLog("[Pushling/GitScan] Scan complete in %.1fs — "
              + "%d repos, %d commits, %@ specialty",
              elapsed, repoCommitCounts.count, totalCommits,
              personality.specialty.rawValue)

        return GitScanResult(
            personality: personality,
            visualTraits: visualTraits,
            repoCount: repoCommitCounts.count,
            totalCommits: totalCommits,
            userEmail: email,
            commitTimestamps: allTimestamps,
            repoCommitCounts: repoCommitCounts.sorted { $0.1 > $1.1 },
            languageCounts: Array(langCounts),
            totalLinesAdded: totalLinesAdded,
            totalLinesDeleted: totalLinesDeleted,
            completed: completed
        )
    }

    // MARK: - Git User Email

    /// Get the global git user.email.
    private static func getGitUserEmail() -> String {
        let output = runGit(["config", "--global", "user.email"], in: nil)
        let email = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? "unknown@pushling" : email
    }

    // MARK: - Repo Discovery

    /// Find all git repos in search directories.
    private static func discoverRepos(deadline: Date) -> [String] {
        var repos: Set<String> = []
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path

        for dirTemplate in searchDirs {
            guard Date() < deadline else { break }

            let dir = dirTemplate.replacingOccurrences(of: "~", with: home)

            guard fm.fileExists(atPath: dir) else { continue }
            scanDirectory(dir, depth: 0, repos: &repos,
                          fm: fm, deadline: deadline)
        }

        return Array(repos)
    }

    /// Recursively scan a directory for .git folders.
    private static func scanDirectory(_ path: String, depth: Int,
                                       repos: inout Set<String>,
                                       fm: FileManager,
                                       deadline: Date) {
        guard depth < maxSearchDepth else { return }
        guard Date() < deadline else { return }

        // Check if this directory itself is a git repo
        let gitDir = (path as NSString).appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir) {
            repos.insert(path)
            return  // Don't recurse into git repos (no nested repos)
        }

        // List contents and recurse
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return
        }

        for item in contents {
            guard Date() < deadline else { return }

            // Skip hidden dirs (except .git which we check above)
            if item.hasPrefix(".") { continue }

            // Skip known unproductive directories
            if skipDirs.contains(item) { continue }

            let fullPath = (path as NSString).appendingPathComponent(item)

            // Don't follow symlinks into system directories
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // Check for symlink
            if let attrs = try? fm.attributesOfItem(atPath: fullPath),
               let type = attrs[.type] as? FileAttributeType,
               type == .typeSymbolicLink {
                continue  // Skip symlinks
            }

            scanDirectory(fullPath, depth: depth + 1,
                          repos: &repos, fm: fm, deadline: deadline)
        }
    }

    // MARK: - Repo Analysis

    /// Per-repo analysis result.
    private struct RepoAnalysis {
        var commitCount: Int = 0
        var timestamps: [Date] = []
        var commitHours: [Int] = []
        var timeDiffs: [TimeInterval] = []
        var extensionCounts: [String: Int] = [:]
        var linesAdded: Int = 0
        var linesDeleted: Int = 0
        var totalMessageLength: Int = 0
        var totalFilesChanged: Int = 0
    }

    /// Analyze a single git repo.
    private static func analyzeRepo(at path: String, email: String,
                                     deadline: Date) -> RepoAnalysis {
        var result = RepoAnalysis()

        // git log with custom format: timestamp|message_length|files|additions|deletions
        let format = "%aI|%s|%H"
        let output = runGit([
            "log", "--author=\(email)",
            "--format=\(format)",
            "--numstat",
            "--no-merges",
            "-n", "5000"  // Cap at 5000 commits per repo
        ], in: path, timeout: 10)

        guard !output.isEmpty else { return result }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime,
                                    .withFractionalSeconds]
        let basicFormatter = ISO8601DateFormatter()

        var previousDate: Date?
        let calendar = Calendar.current

        // Parse output line by line
        let lines = output.components(separatedBy: "\n")
        var currentMessageLength = 0
        var inNumstat = false

        for line in lines {
            guard Date() < deadline else { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                inNumstat = false
                continue
            }

            if trimmed.contains("|") && !inNumstat {
                // Commit header line: timestamp|message|sha
                let parts = trimmed.components(separatedBy: "|")
                guard parts.count >= 2 else { continue }

                let dateStr = parts[0]
                let message = parts[1]

                // Parse date
                if let date = formatter.date(from: dateStr)
                    ?? basicFormatter.date(from: dateStr) {
                    result.timestamps.append(date)
                    let hour = calendar.component(.hour, from: date)
                    result.commitHours.append(hour)

                    if let prev = previousDate {
                        let diff = prev.timeIntervalSince(date)
                        if diff > 0 {
                            result.timeDiffs.append(diff)
                        }
                    }
                    previousDate = date
                }

                currentMessageLength = message.count
                result.totalMessageLength += currentMessageLength
                result.commitCount += 1
                inNumstat = true

            } else if inNumstat {
                // Numstat line: additions\tdeletions\tfilepath
                let numParts = trimmed.components(separatedBy: "\t")
                guard numParts.count >= 3 else { continue }

                let addStr = numParts[0]
                let delStr = numParts[1]
                let filePath = numParts[2]

                if let added = Int(addStr) { result.linesAdded += added }
                if let deleted = Int(delStr) { result.linesDeleted += deleted }
                result.totalFilesChanged += 1

                // Extract extension
                let ext = (filePath as NSString).pathExtension.lowercased()
                if !ext.isEmpty {
                    result.extensionCounts[ext, default: 0] += 1
                }
            }
        }

        return result
    }

    // MARK: - Personality Computation

    /// Compute personality axes from aggregated git data.
    private static func computePersonality(
        totalCommits: Int,
        commitHours: [Int],
        timeDiffs: [TimeInterval],
        avgMessageLength: Double,
        avgFilesPerCommit: Double,
        repoCount: Int,
        extensionCounts: [String: Int],
        timestamps: [Date]
    ) -> Personality {

        guard totalCommits > 0 else { return .neutral }

        // --- Energy: burst_ratio × 0.7 + commits_per_day_normalized × 0.3 ---
        let burstRatio = computeBurstRatio(timeDiffs: timeDiffs)
        let commitsPerDay = computeCommitsPerDay(timestamps: timestamps)
        let cpdNormalized = min(commitsPerDay / 20.0, 1.0)
        let energy = clamp(burstRatio * 0.7 + cpdNormalized * 0.3,
                           min: 0, max: 1)

        // --- Verbosity: avg_message_length / 100 ---
        let verbosity = clamp(avgMessageLength / 100.0, min: 0, max: 1)

        // --- Focus: 1.0 - files/20 × 0.5 - repo_switch × 0.5 ---
        let filesFactor = clamp(avgFilesPerCommit / 20.0, min: 0, max: 1)
        let repoSwitchFreq = computeRepoSwitchFrequency(timestamps: timestamps,
                                                          repoCount: repoCount)
        let focus = clamp(1.0 - filesFactor * 0.5 - repoSwitchFreq * 0.5,
                          min: 0, max: 1)

        // --- Discipline: 1.0 - std_dev_commit_hour / 6.0 ---
        let stdDevHour = standardDeviation(commitHours.map { Double($0) })
        let discipline = clamp(1.0 - stdDevHour / 6.0, min: 0, max: 1)

        // --- Specialty: dominant category ---
        let specialty = computeSpecialty(extensionCounts: extensionCounts)

        var personality = Personality(
            energy: energy, verbosity: verbosity,
            focus: focus, discipline: discipline,
            specialty: specialty
        )
        personality.clampAxes()

        NSLog("[Pushling/GitScan] Personality computed — "
              + "E:%.2f V:%.2f F:%.2f D:%.2f S:%@",
              energy, verbosity, focus, discipline, specialty.rawValue)

        return personality
    }

    // MARK: - Visual Trait Computation

    /// Compute visual traits from aggregated git data.
    private static func computeVisualTraits(
        extensionCounts: [String: Int],
        linesAdded: Int,
        linesDeleted: Int,
        repoCount: Int,
        specialty: LanguageCategory,
        avgMessageLength: Double
    ) -> VisualTraits {

        // Base color from specialty
        let hue = specialty.baseColorHue

        // Body proportion from add/delete ratio
        let proportion: Double
        if linesDeleted > 0 {
            let ratio = Double(linesAdded) / Double(linesDeleted)
            if ratio > 1.5 {
                proportion = 0.7  // Net-adder = rounder
            } else if ratio < 0.7 {
                proportion = 0.3  // Net-deleter = lean
            } else {
                proportion = 0.5
            }
        } else {
            proportion = 0.6  // Only additions = slightly round
        }

        let furPattern = FurPattern.fromRepoCount(repoCount)
        let tailShape = TailShape.fromCategory(specialty)
        let eyeShape = EyeShape.fromAverageMessageLength(avgMessageLength)

        return VisualTraits(
            baseColorHue: hue,
            bodyProportion: proportion,
            furPattern: furPattern,
            tailShape: tailShape,
            eyeShape: eyeShape
        )
    }

    // MARK: - Specialty Computation

    /// Determine the language specialty from file extension counts.
    private static func computeSpecialty(
        extensionCounts: [String: Int]
    ) -> LanguageCategory {
        var categoryCounts: [LanguageCategory: Int] = [:]

        for (ext, count) in extensionCounts {
            if let cat = LanguageCategory.extensionMap[ext] {
                categoryCounts[cat, default: 0] += count
            }
        }

        let total = categoryCounts.values.reduce(0, +)
        guard total > 0 else { return .polyglot }

        // Find dominant category
        let sorted = categoryCounts.sorted { $0.value > $1.value }
        guard let top = sorted.first else { return .polyglot }

        // Polyglot if no category >30%
        let topPercent = Double(top.value) / Double(total)
        if topPercent <= 0.30 {
            return .polyglot
        }

        return top.key
    }

    // MARK: - Statistical Helpers

    /// Compute burst ratio: fraction of commits in bursts of 5+ within 1 hour.
    private static func computeBurstRatio(
        timeDiffs: [TimeInterval]
    ) -> Double {
        guard timeDiffs.count >= 5 else { return 0.3 }

        var burstCommits = 0
        var currentBurstSize = 1

        for diff in timeDiffs {
            if diff < 3600 {  // Within 1 hour
                currentBurstSize += 1
            } else {
                if currentBurstSize >= 5 {
                    burstCommits += currentBurstSize
                }
                currentBurstSize = 1
            }
        }
        // Don't forget the last burst
        if currentBurstSize >= 5 {
            burstCommits += currentBurstSize
        }

        return Double(burstCommits) / Double(timeDiffs.count + 1)
    }

    /// Compute average commits per day.
    private static func computeCommitsPerDay(
        timestamps: [Date]
    ) -> Double {
        guard timestamps.count >= 2 else {
            return Double(timestamps.count)
        }

        let sorted = timestamps.sorted()
        guard let first = sorted.first, let last = sorted.last else {
            return 0
        }

        let days = max(last.timeIntervalSince(first) / 86400.0, 1.0)
        return Double(timestamps.count) / days
    }

    /// Compute a rough "repo switching" frequency based on timestamps.
    /// Higher value = more scattered (switches repos often).
    private static func computeRepoSwitchFrequency(
        timestamps: [Date], repoCount: Int
    ) -> Double {
        // Simple heuristic: more repos relative to commits = more switching
        guard timestamps.count > 0 else { return 0 }
        let reposPerCommitBatch = Double(repoCount) / max(1, Double(timestamps.count / 100))
        return clamp(reposPerCommitBatch / 5.0, min: 0, max: 1)
    }

    /// Standard deviation of a set of values.
    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }

    // MARK: - Git Process Runner

    /// Run a git command and return stdout as a string.
    private static func runGit(_ arguments: [String],
                                in directory: String?,
                                timeout: TimeInterval = 10) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments

        if let dir = directory {
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // Suppress errors

        do {
            try process.run()
        } catch {
            return ""
        }

        // Wait with timeout
        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()

        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        let result = group.wait(timeout: deadline)
        if result == .timedOut {
            process.terminate()
            return ""
        }

        guard process.terminationStatus == 0 else { return "" }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
