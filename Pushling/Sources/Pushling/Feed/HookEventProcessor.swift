// HookEventProcessor.swift — Daemon-side processing of Claude Code hook events
//
// Watches ~/.local/share/pushling/feed/ for JSON files written by hooks.
// Parses each file, dispatches to the appropriate handler, and maps hook
// events to creature reactions (ear perk, tail twitch, diamond animation, etc.).
//
// Feed files are processed in timestamp order and moved to the processed/
// subdirectory afterward. Malformed files are logged and skipped.
//
// This processor handles two kinds of feed files:
//   1. Hook events: {"type":"hook","hook":"PostToolUse","data":{...}}
//   2. Commit events: {"type":"commit","sha":"...","message":"...","data":{...}}
//
// Rate limiting:
//   - Commits: first 5/min full XP, 6-20 get 50%, 21+ get 10%
//   - Hooks: if >3 hook events in 2 seconds, show sustained "watching Claude work"
//
// File system monitoring uses DispatchSource (FSEvents-backed) for ~1s latency.
// Polling fallback every 2 seconds if DispatchSource is unavailable.

import Foundation
import QuartzCore  // For CACurrentMediaTime

// MARK: - Hook Event Types

/// Represents a parsed hook event from the feed directory.
enum HookEventType: String, CaseIterable {
    case sessionStart    = "SessionStart"
    case sessionEnd      = "SessionEnd"
    case postToolUse     = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case subagentStart   = "SubagentStart"
    case subagentStop    = "SubagentStop"
    case postCompact     = "PostCompact"
}

/// Represents a parsed feed file of any type.
enum FeedEvent {
    case hook(type: HookEventType, data: [String: Any], timestamp: String)
    case commit(data: [String: Any])
    case unknown(rawType: String)
}

// MARK: - Commit Rate Limiter

/// Tracks commit rate for XP adjustment.
/// First 5/min: full XP. 6-20: 50%. 21+: 10%.
final class CommitRateLimiter {

    private var recentCommitTimes: [Date] = []
    private let window: TimeInterval = 60.0  // 1 minute window

    /// Returns the XP multiplier for the next commit (1.0, 0.5, or 0.1).
    func multiplierForNextCommit() -> Double {
        pruneExpired()
        let count = recentCommitTimes.count

        if count < 5 {
            return 1.0
        } else if count < 20 {
            return 0.5
        } else {
            return 0.1
        }
    }

    /// Record that a commit was processed.
    func recordCommit() {
        pruneExpired()
        recentCommitTimes.append(Date())
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-window)
        recentCommitTimes.removeAll { $0 < cutoff }
    }
}

// MARK: - Hook Batch Tracker

/// Tracks rapid hook events for batching into "watching Claude work" animation.
/// If >3 hook events arrive within 2 seconds, switch to sustained animation.
final class HookBatchTracker {

    private var recentHookTimes: [Date] = []
    private let batchWindow: TimeInterval = 2.0
    private let batchThreshold = 3

    /// Whether we're currently in batch/burst mode.
    private(set) var isInBurstMode = false

    /// Record a hook event and return whether it should be individually animated
    /// (true) or suppressed in favor of the sustained "watching" animation (false).
    func recordHook() -> Bool {
        let now = Date()
        pruneExpired(now: now)
        recentHookTimes.append(now)

        if recentHookTimes.count >= batchThreshold {
            if !isInBurstMode {
                isInBurstMode = true
                NSLog("[Pushling/Feed] Entering hook burst mode (%d hooks in %.1fs)",
                      recentHookTimes.count, batchWindow)
            }
            return false  // Suppress individual animation
        }

        isInBurstMode = false
        return true  // Animate individually
    }

    /// Call periodically to check if burst mode should end.
    func checkBurstEnd() {
        pruneExpired(now: Date())
        if recentHookTimes.count < batchThreshold {
            if isInBurstMode {
                isInBurstMode = false
                NSLog("[Pushling/Feed] Exiting hook burst mode")
            }
        }
    }

    private func pruneExpired(now: Date) {
        let cutoff = now.addingTimeInterval(-batchWindow)
        recentHookTimes.removeAll { $0 < cutoff }
    }
}

// MARK: - Hook Event Processor

/// Watches the feed directory and processes incoming hook/commit events.
///
/// Usage:
/// ```swift
/// let processor = HookEventProcessor(
///     reflexLayer: scene.behaviorStack.reflexLayer,
///     eventBuffer: ipcServer.eventBuffer
/// )
/// processor.start()
/// ```
final class HookEventProcessor {

    // MARK: - Configuration

    /// Feed directory path.
    private let feedDirectory: String

    /// Processed files subdirectory.
    private let processedDirectory: String

    /// Maximum age for processed files before cleanup (24 hours).
    private static let processedFileMaxAge: TimeInterval = 86400

    // MARK: - Dependencies

    /// The reflex layer to trigger creature reactions.
    private weak var reflexLayer: ReflexLayer?

    /// The event buffer to push events for MCP session delivery.
    private weak var eventBuffer: EventBuffer?

    /// Callback for commit processing (XP calculation, state update).
    /// The daemon's state coordinator provides this.
    var onCommitReceived: ((_ commitData: [String: Any], _ xpMultiplier: Double) -> Void)?

    /// Callback for session lifecycle events (diamond animation).
    var onSessionEvent: ((_ type: HookEventType, _ data: [String: Any]) -> Void)?

    // MARK: - State

    private let commitRateLimiter = CommitRateLimiter()
    private let hookBatchTracker = HookBatchTracker()
    private var isRunning = false
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollingTimer: DispatchSourceTimer?

    /// Serial queue for all file processing.
    private let processingQueue = DispatchQueue(
        label: "com.pushling.feed.processor",
        qos: .utility
    )

    // MARK: - Init

    init(reflexLayer: ReflexLayer? = nil, eventBuffer: EventBuffer? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.feedDirectory = "\(home)/.local/share/pushling/feed"
        self.processedDirectory = "\(home)/.local/share/pushling/feed/processed"
        self.reflexLayer = reflexLayer
        self.eventBuffer = eventBuffer
    }

    /// Designated initializer with explicit paths (for testing).
    init(feedDirectory: String, processedDirectory: String,
         reflexLayer: ReflexLayer? = nil, eventBuffer: EventBuffer? = nil) {
        self.feedDirectory = feedDirectory
        self.processedDirectory = processedDirectory
        self.reflexLayer = reflexLayer
        self.eventBuffer = eventBuffer
    }

    // MARK: - Lifecycle

    /// Start monitoring the feed directory for new files.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Ensure directories exist
        ensureDirectories()

        // Process any existing files first
        processingQueue.async { [weak self] in
            self?.processAllPendingFiles()
        }

        // Set up directory monitoring via GCD dispatch source
        startDirectoryMonitoring()

        // Polling fallback: check every 2 seconds in case FSEvents misses something
        startPollingTimer()

        // Periodic cleanup of old processed files
        startCleanupTimer()

        NSLog("[Pushling/Feed] HookEventProcessor started, watching: %@", feedDirectory)
    }

    /// Stop monitoring.
    func stop() {
        isRunning = false
        dispatchSource?.cancel()
        dispatchSource = nil
        pollingTimer?.cancel()
        pollingTimer = nil
        NSLog("[Pushling/Feed] HookEventProcessor stopped")
    }

    // MARK: - Directory Monitoring

    private func startDirectoryMonitoring() {
        let fd = open(feedDirectory, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[Pushling/Feed] Cannot open feed directory for monitoring, using polling only")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: processingQueue
        )

        source.setEventHandler { [weak self] in
            self?.processAllPendingFiles()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        dispatchSource = source
    }

    private func startPollingTimer() {
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + 2.0, repeating: 2.0, leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            self?.processAllPendingFiles()
            self?.hookBatchTracker.checkBurstEnd()
        }
        timer.resume()
        pollingTimer = timer
    }

    private func startCleanupTimer() {
        // Clean up processed files every hour
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + 3600, repeating: 3600, leeway: .seconds(60))
        timer.setEventHandler { [weak self] in
            self?.cleanupProcessedFiles()
        }
        timer.resume()
    }

    // MARK: - File Processing

    /// Scans the feed directory and processes all pending .json files.
    private func processAllPendingFiles() {
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: feedDirectory) else {
            return
        }

        // Filter for .json files only (skip dotfiles, processed dir, etc.)
        let jsonFiles = entries
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted()  // Process in alphabetical (roughly chronological) order

        guard !jsonFiles.isEmpty else { return }

        for filename in jsonFiles {
            let filePath = (feedDirectory as NSString).appendingPathComponent(filename)
            processFeedFile(at: filePath, filename: filename)
        }
    }

    /// Process a single feed file: parse, dispatch, and move to processed/.
    private func processFeedFile(at path: String, filename: String) {
        // Read file contents
        guard let data = FileManager.default.contents(atPath: path) else {
            NSLog("[Pushling/Feed] Cannot read file: %@", filename)
            moveToProcessed(path: path, filename: filename)
            return
        }

        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("[Pushling/Feed] Malformed JSON in: %@", filename)
            moveToProcessed(path: path, filename: filename)
            return
        }

        // Determine event type
        let feedEvent = parseFeedEvent(json: json)

        // Dispatch to handler
        switch feedEvent {
        case .hook(let type, let hookData, let timestamp):
            handleHookEvent(type: type, data: hookData, timestamp: timestamp)

        case .commit(let commitData):
            handleCommitEvent(data: commitData)

        case .unknown(let rawType):
            NSLog("[Pushling/Feed] Unknown event type '%@' in: %@", rawType, filename)
        }

        // Move to processed directory
        moveToProcessed(path: path, filename: filename)
    }

    /// Parse the top-level JSON into a FeedEvent.
    private func parseFeedEvent(json: [String: Any]) -> FeedEvent {
        guard let type = json["type"] as? String else {
            return .unknown(rawType: "missing_type")
        }

        switch type {
        case "hook":
            guard let hookName = json["hook"] as? String,
                  let hookType = HookEventType(rawValue: hookName) else {
                let rawHook = json["hook"] as? String ?? "unknown"
                return .unknown(rawType: "hook:\(rawHook)")
            }
            let data = json["data"] as? [String: Any] ?? [:]
            let timestamp = json["timestamp"] as? String ?? ""
            return .hook(type: hookType, data: data, timestamp: timestamp)

        case "commit":
            return .commit(data: json)

        default:
            return .unknown(rawType: type)
        }
    }

    // MARK: - Hook Event Handlers

    /// Routes hook events to the appropriate creature reaction.
    private func handleHookEvent(type: HookEventType, data: [String: Any], timestamp: String) {
        // Check if we should animate individually or batch
        let shouldAnimate = hookBatchTracker.recordHook()

        // Always push to event buffer for MCP delivery
        eventBuffer?.push(type: "hook", data: [
            "hook_type": type.rawValue,
            "data": data
        ])

        // Route to specific handler
        switch type {
        case .sessionStart:
            handleSessionStart(data: data)

        case .sessionEnd:
            handleSessionEnd(data: data)

        case .userPromptSubmit:
            if shouldAnimate {
                handleUserPromptSubmit(data: data)
            }

        case .postToolUse:
            if shouldAnimate {
                handlePostToolUse(data: data)
            } else if hookBatchTracker.isInBurstMode {
                // In burst mode: trigger sustained "watching Claude work" once
                triggerWatchingClaudeWork()
            }

        case .subagentStart:
            handleSubagentStart(data: data)

        case .subagentStop:
            handleSubagentStop(data: data)

        case .postCompact:
            if shouldAnimate {
                handlePostCompact(data: data)
            }
        }

        NSLog("[Pushling/Feed] Processed hook: %@ %@",
              type.rawValue,
              shouldAnimate ? "(animated)" : "(batched)")
    }

    // MARK: - Individual Hook Handlers

    /// SessionStart: Diamond materializes, ears perk, creature watches.
    private func handleSessionStart(data: [String: Any]) {
        // Notify session lifecycle handler (for diamond animation)
        onSessionEvent?(.sessionStart, data)

        // Creature reaction: ears perk up, attentive posture
        let currentTime = CACurrentMediaTime()

        // Ear perk for session start — use the pre-defined reflex
        reflexLayer?.trigger(ReflexLayer.earPerk, at: currentTime)

        NSLog("[Pushling/Feed] Session started — diamond materializing")
    }

    /// SessionEnd: Diamond dissolves, creature waves, transition to autonomous.
    private func handleSessionEnd(data: [String: Any]) {
        // Notify session lifecycle handler (for farewell animation)
        onSessionEvent?(.sessionEnd, data)

        let duration = data["duration_s"] as? Int ?? 0
        let reason = data["reason"] as? String ?? "clean"

        NSLog("[Pushling/Feed] Session ended — reason: %@, duration: %ds",
              reason, duration)
    }

    /// UserPromptSubmit: Ears perk, head turns toward terminal.
    private func handleUserPromptSubmit(data: [String: Any]) {
        let promptLength = data["prompt_length"] as? Int ?? 0
        let currentTime = CACurrentMediaTime()

        // Ear perk reflex
        reflexLayer?.trigger(ReflexLayer.earPerk, at: currentTime)

        // Long prompts (>500 chars): extra attentive — trigger look_at_touch
        // (reusing the "look at something" reflex for attentive posture)
        if promptLength > 500 {
            reflexLayer?.trigger(ReflexLayer.lookAtTouch, at: currentTime)
        }
    }

    /// PostToolUse: Success = nod, failure = wince.
    private func handlePostToolUse(data: [String: Any]) {
        let success = data["success"] as? Bool ?? true
        let tool = data["tool"] as? String ?? "unknown"
        let currentTime = CACurrentMediaTime()

        if success {
            // Small nod — ear perk is the closest we have for now
            let nodReflex = ReflexDefinition(
                name: "tool_nod",
                duration: 0.6,
                fadeoutFraction: 0.3,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "perk"
                    o.earRightState = "perk"
                    o.eyeLeftState = "soft"
                    o.eyeRightState = "soft"
                    return o
                }()
            )
            reflexLayer?.trigger(nodReflex, at: currentTime)
        } else {
            // Failure: wince, ears flatten, step back
            let winceReflex = ReflexDefinition(
                name: "tool_wince",
                duration: 1.2,
                fadeoutFraction: 0.25,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "flat"
                    o.earRightState = "flat"
                    o.eyeLeftState = "squint"
                    o.eyeRightState = "squint"
                    o.bodyState = "flinch"
                    return o
                }()
            )
            reflexLayer?.trigger(winceReflex, at: currentTime)
        }

        NSLog("[Pushling/Feed] Tool %@ %@: %@",
              tool, success ? "succeeded" : "failed",
              data["duration_ms"].map { "\($0)ms" } ?? "?ms")
    }

    /// SubagentStart: Diamond splits, eyes widen.
    private func handleSubagentStart(data: [String: Any]) {
        let count = data["subagent_count"] as? Int ?? 1
        let currentTime = CACurrentMediaTime()

        // Notify session handler for diamond split animation
        onSessionEvent?(.subagentStart, data)

        // Eyes widen reflex
        let eyeWidenReflex = ReflexDefinition(
            name: "subagent_surprise",
            duration: 2.0,
            fadeoutFraction: 0.2,
            output: {
                var o = LayerOutput()
                o.eyeLeftState = "wide"
                o.eyeRightState = "wide"
                o.earLeftState = "perk"
                o.earRightState = "perk"
                return o
            }()
        )
        reflexLayer?.trigger(eyeWidenReflex, at: currentTime)

        // 3+ subagents: jaw drop (surprise #70)
        if count >= 3 {
            reflexLayer?.trigger(ReflexLayer.startle, at: currentTime)
        }

        NSLog("[Pushling/Feed] Subagents started: %d — diamond splitting", count)
    }

    /// SubagentStop: Diamonds reconverge, creature nods.
    private func handleSubagentStop(data: [String: Any]) {
        let remaining = data["remaining"] as? Int ?? 0

        // Notify session handler for diamond reconvergence
        onSessionEvent?(.subagentStop, data)

        if remaining == 0 {
            // All subagents done — nod approvingly
            let currentTime = CACurrentMediaTime()
            let nodReflex = ReflexDefinition(
                name: "subagent_done_nod",
                duration: 1.0,
                fadeoutFraction: 0.3,
                output: {
                    var o = LayerOutput()
                    o.earLeftState = "perk"
                    o.earRightState = "perk"
                    o.eyeLeftState = "soft"
                    o.eyeRightState = "soft"
                    return o
                }()
            )
            reflexLayer?.trigger(nodReflex, at: currentTime)
        }

        NSLog("[Pushling/Feed] Subagent stop — remaining: %d", remaining)
    }

    /// PostCompact: Head shake, daze, rapid blink.
    private func handlePostCompact(data: [String: Any]) {
        let currentTime = CACurrentMediaTime()

        // Daze reflex: confused, head shake, rapid blink
        let dazeReflex = ReflexDefinition(
            name: "compact_daze",
            duration: 3.5,
            fadeoutFraction: 0.2,
            output: {
                var o = LayerOutput()
                o.bodyState = "shake"
                o.earLeftState = "back"
                o.earRightState = "back"
                o.eyeLeftState = "rapid_blink"
                o.eyeRightState = "rapid_blink"
                o.mouthState = "open_slight"
                return o
            }()
        )
        reflexLayer?.trigger(dazeReflex, at: currentTime)

        NSLog("[Pushling/Feed] Context compacted — creature dazed")
    }

    /// Sustained "watching Claude work" animation during tool bursts.
    private func triggerWatchingClaudeWork() {
        let currentTime = CACurrentMediaTime()

        let watchReflex = ReflexDefinition(
            name: "watching_claude_work",
            duration: 4.0,
            fadeoutFraction: 0.25,
            output: {
                var o = LayerOutput()
                o.earLeftState = "rotate_toward"
                o.earRightState = "perk"
                o.eyeLeftState = "focused"
                o.eyeRightState = "focused"
                o.tailState = "still"
                return o
            }()
        )
        reflexLayer?.trigger(watchReflex, at: currentTime)
    }

    // MARK: - Commit Event Handler

    /// Process a commit feed file: calculate XP, trigger feeding animation.
    private func handleCommitEvent(data: [String: Any]) {
        let sha = data["sha"] as? String ?? "unknown"
        let message = data["message"] as? String ?? ""
        let filesChanged = data["files_changed"] as? Int ?? 0
        let linesAdded = data["lines_added"] as? Int ?? 0
        let linesRemoved = data["lines_removed"] as? Int ?? 0
        let isMerge = data["is_merge"] as? Bool ?? false
        let isRevert = data["is_revert"] as? Bool ?? false
        let isForcePush = data["is_force_push"] as? Bool ?? false
        let repoName = data["repo_name"] as? String ?? "unknown"
        let languages = data["languages"] as? String ?? ""

        // Calculate base XP
        let totalLines = linesAdded + linesRemoved
        var baseXP = 1                                               // Base: 1
        baseXP += min(5, totalLines / 20)                           // Lines: up to 5
        baseXP += (message.count > 20) ? 2 : 0                     // Message quality: 2
        baseXP += (filesChanged >= 3) ? 1 : 0                      // Breadth: 1

        // Apply rate limiter
        let multiplier = commitRateLimiter.multiplierForNextCommit()
        commitRateLimiter.recordCommit()
        let finalXP = max(1, Int(Double(baseXP) * multiplier))

        // Push to event buffer
        eventBuffer?.push(type: "commit", data: [
            "sha": sha,
            "message": message,
            "xp": finalXP,
            "lines_added": linesAdded,
            "lines_deleted": linesRemoved,
            "repo": repoName,
            "commit_type": classifyCommit(message: message, isMerge: isMerge,
                                           isRevert: isRevert)
        ])

        // Trigger creature reaction
        let currentTime = CACurrentMediaTime()

        if isForcePush {
            // Force push: flinch!
            reflexLayer?.trigger(ReflexLayer.flinch, at: currentTime)
        } else if isRevert {
            // Revert: confused ear perk
            reflexLayer?.trigger(ReflexLayer.earPerk, at: currentTime)
        } else {
            // Normal commit: ear perk (feeding animation handled by onCommitReceived)
            reflexLayer?.trigger(ReflexLayer.earPerk, at: currentTime)
        }

        // Notify the state coordinator for XP and feeding animation
        onCommitReceived?(data, multiplier)

        NSLog("[Pushling/Feed] Commit %@ from %@: +%d XP (x%.1f) [%@]",
              sha, repoName, finalXP, multiplier, languages)
    }

    /// Classify a commit by its message prefix.
    private func classifyCommit(message: String, isMerge: Bool, isRevert: Bool) -> String {
        if isMerge { return "merge" }
        if isRevert { return "revert" }

        let lower = message.lowercased()

        // Conventional commit prefixes
        if lower.hasPrefix("feat")    { return "feature" }
        if lower.hasPrefix("fix")     { return "bugfix" }
        if lower.hasPrefix("refactor") { return "refactor" }
        if lower.hasPrefix("test")    { return "test" }
        if lower.hasPrefix("docs")    { return "docs" }
        if lower.hasPrefix("style")   { return "style" }
        if lower.hasPrefix("chore")   { return "chore" }
        if lower.hasPrefix("ci")      { return "ci" }
        if lower.hasPrefix("perf")    { return "perf" }
        if lower.hasPrefix("build")   { return "build" }

        // Heuristics for non-conventional commits
        if lower.contains("fix") || lower.contains("bug") { return "bugfix" }
        if lower.contains("add") || lower.contains("new") { return "feature" }
        if lower.contains("refactor") || lower.contains("clean") { return "refactor" }
        if lower.contains("test") { return "test" }
        if lower.contains("doc") || lower.contains("readme") { return "docs" }

        return "general"
    }

    // MARK: - File Management

    private func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: feedDirectory,
                                withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: processedDirectory,
                                withIntermediateDirectories: true)
    }

    /// Move a processed file to the processed/ subdirectory.
    private func moveToProcessed(path: String, filename: String) {
        let destination = (processedDirectory as NSString).appendingPathComponent(filename)
        try? FileManager.default.moveItem(atPath: path, toPath: destination)
    }

    /// Delete processed files older than 24 hours.
    private func cleanupProcessedFiles() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: processedDirectory) else { return }

        let cutoff = Date().addingTimeInterval(-Self.processedFileMaxAge)
        var cleanedCount = 0

        for filename in entries {
            let path = (processedDirectory as NSString).appendingPathComponent(filename)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            if modDate < cutoff {
                try? fm.removeItem(atPath: path)
                cleanedCount += 1
            }
        }

        if cleanedCount > 0 {
            NSLog("[Pushling/Feed] Cleaned up %d processed feed files", cleanedCount)
        }
    }
}
