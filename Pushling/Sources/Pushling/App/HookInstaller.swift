// HookInstaller.swift — Auto-installs git hooks, Claude Code hooks, and MCP server
//
// Multi-tier installation:
//   Tier 1: Copy hook scripts + lib to ~/.local/share/pushling/hooks/
//   Tier 2: Set global git hooks via core.hooksPath (with chaining wrapper)
//   Tier 3: Merge Claude Code hooks into ~/.claude/settings.json
//   Tier 4: Register MCP server via `claude mcp add`
//
// Called from AppDelegate on first launch. Idempotent — safe to run multiple times.
// Respects UserDefaults "hooksInstalled" flag (cleared by Reset Everything).

import Foundation

enum HookInstaller {

    // MARK: - Paths

    private static let dataDir = NSString(
        string: "~/.local/share/pushling"
    ).expandingTildeInPath

    private static let hooksInstallDir = NSString(
        string: "~/.local/share/pushling/hooks"
    ).expandingTildeInPath

    private static let globalGitHooksDir = NSString(
        string: "~/.local/share/pushling/git-hooks"
    ).expandingTildeInPath

    private static let claudeSettingsPath = NSString(
        string: "~/.claude/settings.json"
    ).expandingTildeInPath

    // MARK: - Source Resolution

    /// Find the hooks source directory. Tries several locations relative to
    /// the running binary, the build directory, and the source repo.
    private static func findHooksSource() -> String? {
        let fm = FileManager.default

        // The binary is at build/Pushling.app/Contents/MacOS/Pushling
        // The hooks are at hooks/ in the repo root
        if let execPath = Bundle.main.executablePath {
            let execURL = URL(fileURLWithPath: execPath)
            // Go up from MacOS → Contents → Pushling.app → build → repo root
            let repoRoot = execURL
                .deletingLastPathComponent()  // MacOS
                .deletingLastPathComponent()  // Contents
                .deletingLastPathComponent()  // Pushling.app
                .deletingLastPathComponent()  // build
            let hooksDir = repoRoot.appendingPathComponent("hooks").path
            if fm.fileExists(atPath: hooksDir + "/post-commit.sh") {
                return hooksDir
            }
        }

        // Try /Applications path → assume repo is at ~/github/pushling
        let commonPaths = [
            NSString(string: "~/github/pushling/hooks").expandingTildeInPath,
            NSString(string: "~/Projects/pushling/hooks").expandingTildeInPath,
            NSString(string: "~/code/pushling/hooks").expandingTildeInPath,
        ]
        for path in commonPaths {
            if fm.fileExists(atPath: path + "/post-commit.sh") {
                return path
            }
        }

        return nil
    }

    // MARK: - Install All

    /// Run the full installation. Call on background thread.
    static func installAll() {
        NSLog("[Pushling/Installer] Starting auto-installation...")

        guard let source = findHooksSource() else {
            NSLog("[Pushling/Installer] Cannot find hooks source directory "
                  + "— skipping installation")
            return
        }
        NSLog("[Pushling/Installer] Found hooks source: %@", source)

        installHookScripts(from: source)
        installGlobalGitHook()
        installClaudeCodeHooks()
        registerMCPServer(from: source)

        UserDefaults.standard.set(true, forKey: "hooksInstalled")
        NSLog("[Pushling/Installer] Installation complete")
    }

    // MARK: - Step 1: Copy Hook Scripts

    private static func installHookScripts(from source: String) {
        let fm = FileManager.default
        let libDir = hooksInstallDir + "/lib"

        // Create directories
        try? fm.createDirectory(atPath: libDir,
                                 withIntermediateDirectories: true)

        // Copy all .sh files
        let scripts = [
            "post-commit.sh", "session-start.sh", "session-end.sh",
            "post-tool-use.sh", "user-prompt-submit.sh",
            "subagent-start.sh", "subagent-stop.sh", "post-compact.sh"
        ]
        for script in scripts {
            let src = source + "/" + script
            let dst = hooksInstallDir + "/" + script
            try? fm.removeItem(atPath: dst)
            try? fm.copyItem(atPath: src, toPath: dst)
            // chmod +x
            try? fm.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: dst)
        }

        // Copy lib
        let libSrc = source + "/lib/pushling-hook-lib.sh"
        let libDst = libDir + "/pushling-hook-lib.sh"
        try? fm.removeItem(atPath: libDst)
        try? fm.copyItem(atPath: libSrc, toPath: libDst)
        try? fm.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: libDst)

        NSLog("[Pushling/Installer] Hook scripts installed to %@",
              hooksInstallDir)
    }

    // MARK: - Step 2: Global Git Hook

    private static func installGlobalGitHook() {
        let fm = FileManager.default

        // Check if core.hooksPath is already set
        let existingPath = shell("git config --global core.hooksPath")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !existingPath.isEmpty &&
           !existingPath.contains("pushling") {
            // Another tool owns core.hooksPath — don't override
            NSLog("[Pushling/Installer] core.hooksPath already set to %@ "
                  + "— skipping global git hook", existingPath)
            return
        }

        // Create global hooks dir with chaining wrapper
        try? fm.createDirectory(atPath: globalGitHooksDir,
                                 withIntermediateDirectories: true)

        let wrapperPath = globalGitHooksDir + "/post-commit"
        let wrapper = """
        #!/usr/bin/env bash
        # Pushling global post-commit — chains to repo-local hooks

        # Run Pushling's hook (never fails, never blocks)
        "\(hooksInstallDir)/post-commit.sh" 2>/dev/null || true

        # Chain to repo-local hook if developer has one
        _git_dir="$(git rev-parse --git-dir 2>/dev/null)"
        for hook in "$_git_dir/hooks.local/post-commit" \
                     "$_git_dir/hooks.pre-pushling/post-commit"; do
            [[ -x "$hook" ]] && exec "$hook"
        done
        """
        try? wrapper.write(toFile: wrapperPath, atomically: true,
                            encoding: .utf8)
        try? fm.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: wrapperPath)

        // Set global hooks path
        _ = shell("git config --global core.hooksPath '\(globalGitHooksDir)'")

        NSLog("[Pushling/Installer] Global git hooks set at %@",
              globalGitHooksDir)
    }

    // MARK: - Step 3: Claude Code Hooks

    private static func installClaudeCodeHooks() {
        let fm = FileManager.default
        let claudeDir = NSString(
            string: "~/.claude").expandingTildeInPath

        // Ensure ~/.claude/ exists
        try? fm.createDirectory(atPath: claudeDir,
                                 withIntermediateDirectories: true)

        // Read existing settings or start fresh
        var settings: [String: Any] = [:]
        if let data = fm.contents(atPath: claudeSettingsPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = json
        }

        // Get or create hooks dictionary
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Define Pushling's 7 Claude Code hooks
        let hookDefs: [(event: String, script: String, timeout: Int, stdout: Bool)] = [
            ("SessionStart", "session-start.sh", 200, true),
            ("SessionEnd", "session-end.sh", 50, false),
            ("PostToolUse", "post-tool-use.sh", 50, false),
            ("UserPromptSubmit", "user-prompt-submit.sh", 50, false),
            ("SubagentStart", "subagent-start.sh", 50, false),
            ("SubagentStop", "subagent-stop.sh", 50, false),
            ("PostCompact", "post-compact.sh", 50, false),
        ]

        for def in hookDefs {
            let command = hooksInstallDir + "/" + def.script
            let hookEntry: [String: Any] = [
                "type": "command",
                "command": command,
                "timeout": def.timeout
            ]

            // Get existing hooks for this event type
            var eventHooks = hooks[def.event] as? [[String: Any]] ?? []

            // Check if Pushling hook already registered
            let alreadyRegistered = eventHooks.contains { entry in
                if let hooksList = entry["hooks"] as? [[String: Any]] {
                    return hooksList.contains { h in
                        (h["command"] as? String)?.contains("pushling") == true
                    }
                }
                return false
            }

            if !alreadyRegistered {
                eventHooks.append(["hooks": [hookEntry]])
                hooks[def.event] = eventHooks
            }
        }

        settings["hooks"] = hooks

        // Write back atomically
        if let jsonData = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]) {
            let tmpPath = claudeSettingsPath + ".tmp"
            try? jsonData.write(to: URL(fileURLWithPath: tmpPath))
            try? fm.removeItem(atPath: claudeSettingsPath)
            try? fm.moveItem(atPath: tmpPath, toPath: claudeSettingsPath)
        }

        NSLog("[Pushling/Installer] Claude Code hooks merged into %@",
              claudeSettingsPath)
    }

    // MARK: - Step 4: MCP Server Registration

    private static func registerMCPServer(from source: String) {
        // Check if MCP is already registered
        let existing = shell("claude mcp list 2>/dev/null")
        if existing.contains("pushling") {
            NSLog("[Pushling/Installer] MCP server already registered")
            return
        }

        // Find the MCP dist directory
        let sourceURL = URL(fileURLWithPath: source)
        let repoRoot = sourceURL.deletingLastPathComponent()
        let mcpIndex = repoRoot
            .appendingPathComponent("mcp/dist/index.js").path

        if FileManager.default.fileExists(atPath: mcpIndex) {
            _ = shell("claude mcp add pushling -- node '\(mcpIndex)' 2>/dev/null")
            NSLog("[Pushling/Installer] MCP server registered: %@", mcpIndex)
        } else {
            NSLog("[Pushling/Installer] MCP dist not found at %@ "
                  + "— skipping MCP registration", mcpIndex)
        }
    }

    // MARK: - Public Status Checks

    /// Check if the MCP server is registered with Claude Code.
    /// Safe to call from any thread (runs shell command).
    static func isMCPInstalled() -> Bool {
        let result = shell("claude mcp list 2>/dev/null")
        return result.contains("pushling")
    }

    /// Install the MCP server. Call from background thread.
    static func installMCP() {
        guard let source = findHooksSource() else {
            NSLog("[Pushling/Installer] Cannot find hooks source for MCP install")
            return
        }
        registerMCPServer(from: source)
    }

    // MARK: - Shell Helper

    @discardableResult
    private static func shell(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
