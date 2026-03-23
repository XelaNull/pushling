// GitHubProfileFetcher.swift — Queries GitHub via gh CLI for personality data
//
// Checks if gh CLI is authenticated, then queries the developer's repos
// and languages. Results feed into the EggAccumulator for richer personality.
// All async, non-blocking, graceful failure.

import Foundation

enum GitHubProfileFetcher {

    struct GitHubProfile {
        let repoCount: Int
        let languages: [String: Int]  // language → count
        let username: String
    }

    /// Check if gh CLI is installed and authenticated.
    /// Returns true if `gh auth status` exits with 0.
    static func isAuthenticated() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh", "auth", "status"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Fetch GitHub profile data asynchronously.
    /// Calls completion on main thread with result or nil on failure.
    static func fetch(completion: @escaping (GitHubProfile?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            guard isAuthenticated() else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Get repo languages
            let languages = runGH(
                ["api", "user/repos", "--limit", "100",
                 "--jq", ".[].language // empty"]
            )

            // Count languages
            var langCounts: [String: Int] = [:]
            for lang in (languages ?? "").components(separatedBy: "\n") {
                let trimmed = lang.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                langCounts[trimmed, default: 0] += 1
            }

            // Get username
            let username = runGH(["api", "user", "--jq", ".login"])?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

            let profile = GitHubProfile(
                repoCount: langCounts.values.reduce(0, +),
                languages: langCounts,
                username: username
            )

            DispatchQueue.main.async { completion(profile) }
        }
    }

    /// Run a gh CLI command and return stdout.
    private static func runGH(_ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh"] + args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
