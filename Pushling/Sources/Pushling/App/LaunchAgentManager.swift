// LaunchAgentManager.swift — Install/remove launchd plist for auto-start
// Manages ~/Library/LaunchAgents/com.pushling.daemon.plist
//
// Configuration:
//   - RunAtLoad = true (start on login)
//   - KeepAlive = true (restart on crash)
//   - ProcessType = Interactive (higher scheduling priority for 60fps)
//   - Logs to ~/Library/Logs/Pushling/

import Foundation

final class LaunchAgentManager {

    // MARK: - Constants

    private static let plistName = "com.pushling.daemon.plist"
    private static let label = "com.pushling.daemon"

    // MARK: - Paths

    /// ~/Library/LaunchAgents/
    private var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    /// Full path to the plist file.
    private var plistURL: URL {
        launchAgentsDir.appendingPathComponent(Self.plistName)
    }

    /// ~/Library/Logs/Pushling/
    private var logDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Pushling", isDirectory: true)
    }

    /// Path to the current executable.
    private var executablePath: String {
        // For development: use the currently-running binary path
        // For production: would be /Applications/Pushling.app/Contents/MacOS/Pushling
        return ProcessInfo.processInfo.arguments[0]
    }

    // MARK: - State

    /// Whether the launch agent plist is installed.
    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    // MARK: - Install

    /// Install the LaunchAgent plist and create log directory.
    func install() {
        do {
            // Ensure LaunchAgents directory exists
            try FileManager.default.createDirectory(
                at: launchAgentsDir,
                withIntermediateDirectories: true
            )

            // Ensure log directory exists
            try FileManager.default.createDirectory(
                at: logDir,
                withIntermediateDirectories: true
            )

            // Build the plist content
            let plist = buildPlist()

            // Write the plist
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)

            NSLog("[Pushling] Launch agent installed at: \(plistURL.path)")

            // Load the agent (so it takes effect without logout)
            loadAgent()

        } catch {
            NSLog("[Pushling] Failed to install launch agent: \(error.localizedDescription)")
        }
    }

    /// Remove the LaunchAgent plist.
    func uninstall() {
        // Unload the agent first
        unloadAgent()

        do {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
                NSLog("[Pushling] Launch agent removed from: \(plistURL.path)")
            }
        } catch {
            NSLog("[Pushling] Failed to remove launch agent: \(error.localizedDescription)")
        }
    }

    // MARK: - Plist Generation

    private func buildPlist() -> [String: Any] {
        let stdoutPath = logDir.appendingPathComponent("pushling.stdout.log").path
        let stderrPath = logDir.appendingPathComponent("pushling.stderr.log").path

        return [
            "Label": Self.label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "StandardOutPath": stdoutPath,
            "StandardErrorPath": stderrPath,
            "EnvironmentVariables": [
                "PUSHLING_LAUNCHED_BY_AGENT": "1"
            ]
        ]
    }

    // MARK: - launchctl Integration

    private func loadAgent() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", plistURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                NSLog("[Pushling] Launch agent loaded via launchctl")
            } else {
                NSLog("[Pushling] launchctl load returned status \(task.terminationStatus)")
            }
        } catch {
            NSLog("[Pushling] Failed to run launchctl load: \(error.localizedDescription)")
        }
    }

    private func unloadAgent() {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistURL.path]

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                NSLog("[Pushling] Launch agent unloaded via launchctl")
            }
        } catch {
            NSLog("[Pushling] Failed to run launchctl unload: \(error.localizedDescription)")
        }
    }
}
