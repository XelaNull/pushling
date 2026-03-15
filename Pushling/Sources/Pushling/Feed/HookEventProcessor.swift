// HookEventProcessor.swift — Daemon-side processing of Claude Code hook events
//
// Watches ~/.local/share/pushling/feed/ for JSON files written by hooks.
// Parses each file, dispatches to the appropriate handler, and maps hook
// events to creature reactions (ear perk, tail twitch, diamond animation, etc.).
//
// Feed files are processed in timestamp order and moved to the processed/
// subdirectory afterward. Malformed files are logged and skipped.
//
// Types, rate limiter, and batch tracker are in FeedTypes.swift.
//
// File system monitoring uses DispatchSource (FSEvents-backed) for ~1s latency.
// Polling fallback every 2 seconds if DispatchSource is unavailable.

import Foundation
import QuartzCore  // For CACurrentMediaTime

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

    private let feedDirectory: String
    private let processedDirectory: String
    private static let processedFileMaxAge: TimeInterval = 86400

    // MARK: - Dependencies

    private weak var reflexLayer: ReflexLayer?
    private weak var eventBuffer: EventBuffer?

    /// Callback for commit processing (XP calculation, state update).
    var onCommitReceived: ((_ commitData: [String: Any], _ xpMultiplier: Double) -> Void)?

    /// Callback for session lifecycle events (diamond animation).
    var onSessionEvent: ((_ type: HookEventType, _ data: [String: Any]) -> Void)?

    // MARK: - State

    private let commitRateLimiter = CommitRateLimiter()
    private let hookBatchTracker = HookBatchTracker()
    private var isRunning = false
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollingTimer: DispatchSourceTimer?
    private var cleanupTimer: DispatchSourceTimer?

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

    init(feedDirectory: String, processedDirectory: String,
         reflexLayer: ReflexLayer? = nil, eventBuffer: EventBuffer? = nil) {
        self.feedDirectory = feedDirectory
        self.processedDirectory = processedDirectory
        self.reflexLayer = reflexLayer
        self.eventBuffer = eventBuffer
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        ensureDirectories()
        processingQueue.async { [weak self] in self?.processAllPendingFiles() }
        startDirectoryMonitoring()
        startPollingTimer()
        startCleanupTimer()
        NSLog("[Pushling/Feed] HookEventProcessor started, watching: %@", feedDirectory)
    }

    func stop() {
        isRunning = false
        dispatchSource?.cancel()
        dispatchSource = nil
        pollingTimer?.cancel()
        pollingTimer = nil
        cleanupTimer?.cancel()
        cleanupTimer = nil
        NSLog("[Pushling/Feed] HookEventProcessor stopped")
    }

    // MARK: - Directory Monitoring

    private func startDirectoryMonitoring() {
        let fd = open(feedDirectory, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[Pushling/Feed] Cannot open feed directory for monitoring")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: processingQueue
        )
        source.setEventHandler { [weak self] in self?.processAllPendingFiles() }
        source.setCancelHandler { close(fd) }
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
        let timer = DispatchSource.makeTimerSource(queue: processingQueue)
        timer.schedule(deadline: .now() + 3600, repeating: 3600, leeway: .seconds(60))
        timer.setEventHandler { [weak self] in self?.cleanupProcessedFiles() }
        timer.resume()
        cleanupTimer = timer
    }

    // MARK: - File Processing

    private func processAllPendingFiles() {
        guard let entries = try? FileManager.default
                .contentsOfDirectory(atPath: feedDirectory) else { return }

        let jsonFiles = entries
            .filter { $0.hasSuffix(".json") && !$0.hasPrefix(".") }
            .sorted()

        for filename in jsonFiles {
            let path = (feedDirectory as NSString).appendingPathComponent(filename)
            processFeedFile(at: path, filename: filename)
        }
    }

    private func processFeedFile(at path: String, filename: String) {
        guard let data = FileManager.default.contents(atPath: path) else {
            NSLog("[Pushling/Feed] Cannot read file: %@", filename)
            moveToProcessed(path: path, filename: filename)
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else {
            NSLog("[Pushling/Feed] Malformed JSON in: %@", filename)
            moveToProcessed(path: path, filename: filename)
            return
        }

        switch parseFeedEvent(json: json) {
        case .hook(let type, let hookData, let timestamp):
            handleHookEvent(type: type, data: hookData, timestamp: timestamp)
        case .commit(let commitData):
            handleCommitEvent(data: commitData)
        case .unknown(let rawType):
            NSLog("[Pushling/Feed] Unknown event type '%@' in: %@", rawType, filename)
        }

        moveToProcessed(path: path, filename: filename)
    }

    private func parseFeedEvent(json: [String: Any]) -> FeedEvent {
        guard let type = json["type"] as? String else {
            return .unknown(rawType: "missing_type")
        }
        switch type {
        case "hook":
            guard let hookName = json["hook"] as? String,
                  let hookType = HookEventType(rawValue: hookName) else {
                return .unknown(rawType: "hook:\(json["hook"] ?? "unknown")")
            }
            return .hook(type: hookType,
                         data: json["data"] as? [String: Any] ?? [:],
                         timestamp: json["timestamp"] as? String ?? "")
        case "commit":
            return .commit(data: json)
        default:
            return .unknown(rawType: type)
        }
    }

    // MARK: - Hook Dispatch

    private func handleHookEvent(type: HookEventType, data: [String: Any],
                                  timestamp: String) {
        let shouldAnimate = hookBatchTracker.recordHook()

        eventBuffer?.push(type: "hook", data: [
            "hook_type": type.rawValue, "data": data
        ])

        switch type {
        case .sessionStart:   handleSessionStart(data: data)
        case .sessionEnd:     handleSessionEnd(data: data)
        case .userPromptSubmit:
            if shouldAnimate { handleUserPromptSubmit(data: data) }
        case .postToolUse:
            if shouldAnimate { handlePostToolUse(data: data) }
            else if hookBatchTracker.isInBurstMode { triggerWatchingClaudeWork() }
        case .subagentStart:  handleSubagentStart(data: data)
        case .subagentStop:   handleSubagentStop(data: data)
        case .postCompact:
            if shouldAnimate { handlePostCompact(data: data) }
        }

        NSLog("[Pushling/Feed] Processed hook: %@ %@",
              type.rawValue, shouldAnimate ? "(animated)" : "(batched)")
    }

    // MARK: - Hook Handlers

    private func handleSessionStart(data: [String: Any]) {
        onSessionEvent?(.sessionStart, data)
        reflexLayer?.trigger(ReflexLayer.earPerk, at: CACurrentMediaTime())
        NSLog("[Pushling/Feed] Session started — diamond materializing")
    }

    private func handleSessionEnd(data: [String: Any]) {
        onSessionEvent?(.sessionEnd, data)
        NSLog("[Pushling/Feed] Session ended — reason: %@, duration: %ds",
              data["reason"] as? String ?? "clean",
              data["duration_s"] as? Int ?? 0)
    }

    /// P4-T4-06: UserPromptSubmit — ears forward, look toward "voice."
    private func handleUserPromptSubmit(data: [String: Any]) {
        let promptLength = data["prompt_length"] as? Int ?? 0
        let t = CACurrentMediaTime()

        // Ears forward, attentive posture — human is talking to Claude
        let earsForward = ReflexDefinition(name: "prompt_attention", duration: 1.2,
                                            fadeoutFraction: 0.25, output: {
            var o = LayerOutput()
            o.earLeftState = "forward"
            o.earRightState = "forward"
            o.eyeLeftState = "look_at"
            o.eyeRightState = "look_at"
            return o
        }())
        reflexLayer?.trigger(earsForward, at: t)

        // Long prompts: extra attentive — full body engagement
        if promptLength > 500 {
            reflexLayer?.trigger(ReflexLayer.lookAtTouch, at: t)
        }
    }

    /// P4-T4-06: PostToolUse — tail twitch + brief ear perk on success, wince on failure.
    private func handlePostToolUse(data: [String: Any]) {
        let success = data["success"] as? Bool ?? true
        let t = CACurrentMediaTime()

        if success {
            // Tail twitch + ear perk — acknowledgment of tool completion
            let toolSuccess = ReflexDefinition(name: "tool_success", duration: 0.8,
                                                fadeoutFraction: 0.3, output: {
                var o = LayerOutput()
                o.earLeftState = "perk"; o.earRightState = "perk"
                o.tailState = "twitch"
                o.eyeLeftState = "soft"; o.eyeRightState = "soft"
                return o
            }())
            reflexLayer?.trigger(toolSuccess, at: t)
        } else {
            let wince = ReflexDefinition(name: "tool_wince", duration: 1.2,
                                          fadeoutFraction: 0.25, output: {
                var o = LayerOutput()
                o.earLeftState = "flat"; o.earRightState = "flat"
                o.eyeLeftState = "squint"; o.eyeRightState = "squint"
                o.bodyState = "flinch"
                return o
            }())
            reflexLayer?.trigger(wince, at: t)
        }
    }

    private func handleSubagentStart(data: [String: Any]) {
        let count = data["subagent_count"] as? Int ?? 1
        let t = CACurrentMediaTime()
        onSessionEvent?(.subagentStart, data)
        let widen = ReflexDefinition(name: "subagent_surprise", duration: 2.0,
                                      fadeoutFraction: 0.2, output: {
            var o = LayerOutput()
            o.eyeLeftState = "wide"; o.eyeRightState = "wide"
            o.earLeftState = "perk"; o.earRightState = "perk"
            return o
        }())
        reflexLayer?.trigger(widen, at: t)
        if count >= 3 { reflexLayer?.trigger(ReflexLayer.startle, at: t) }
        NSLog("[Pushling/Feed] Subagents started: %d", count)
    }

    private func handleSubagentStop(data: [String: Any]) {
        let remaining = data["remaining"] as? Int ?? 0
        onSessionEvent?(.subagentStop, data)
        if remaining == 0 {
            let nod = ReflexDefinition(name: "subagent_done_nod", duration: 1.0,
                                        fadeoutFraction: 0.3, output: {
                var o = LayerOutput()
                o.earLeftState = "perk"; o.earRightState = "perk"
                o.eyeLeftState = "soft"; o.eyeRightState = "soft"
                return o
            }())
            reflexLayer?.trigger(nod, at: CACurrentMediaTime())
        }
    }

    /// P4-T4-06: PostCompact — creature blinks rapidly, shakes head.
    /// Shares Claude's context loss disorientation.
    private func handlePostCompact(data: [String: Any]) {
        let daze = ReflexDefinition(name: "compact_daze", duration: 3.5,
                                     fadeoutFraction: 0.2, output: {
            var o = LayerOutput()
            o.bodyState = "shake"          // Head shake
            o.earLeftState = "back"; o.earRightState = "back"
            o.eyeLeftState = "rapid_blink"; o.eyeRightState = "rapid_blink"
            o.mouthState = "open_slight"   // Bewildered expression
            o.tailState = "limp"           // Momentary loss of composure
            return o
        }())
        reflexLayer?.trigger(daze, at: CACurrentMediaTime())
        NSLog("[Pushling/Feed] Context compacted — creature dazed")
    }

    private func triggerWatchingClaudeWork() {
        let watch = ReflexDefinition(name: "watching_claude_work", duration: 4.0,
                                      fadeoutFraction: 0.25, output: {
            var o = LayerOutput()
            o.earLeftState = "rotate_toward"; o.earRightState = "perk"
            o.eyeLeftState = "focused"; o.eyeRightState = "focused"
            o.tailState = "still"
            return o
        }())
        reflexLayer?.trigger(watch, at: CACurrentMediaTime())
    }

    // MARK: - Commit Handler

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

        // XP formula: base(1) + lines(max 5) + message(2) + breadth(1) * rate
        let totalLines = linesAdded + linesRemoved
        var baseXP = 1
        baseXP += min(5, totalLines / 20)
        baseXP += (message.count > 20) ? 2 : 0
        baseXP += (filesChanged >= 3) ? 1 : 0

        let multiplier = commitRateLimiter.multiplierForNextCommit()
        commitRateLimiter.recordCommit()
        let finalXP = max(1, Int(Double(baseXP) * multiplier))

        eventBuffer?.push(type: "commit", data: [
            "sha": sha, "message": message, "xp": finalXP,
            "lines_added": linesAdded, "lines_deleted": linesRemoved,
            "repo": repoName,
            "commit_type": CommitClassifier.classify(
                message: message, isMerge: isMerge, isRevert: isRevert)
        ])

        let t = CACurrentMediaTime()
        if isForcePush {
            reflexLayer?.trigger(ReflexLayer.flinch, at: t)
        } else {
            reflexLayer?.trigger(ReflexLayer.earPerk, at: t)
        }

        onCommitReceived?(data, multiplier)
        NSLog("[Pushling/Feed] Commit %@ from %@: +%d XP (x%.1f) [%@]",
              sha, repoName, finalXP, multiplier, languages)
    }

    // MARK: - File Management

    private func ensureDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: feedDirectory,
                                withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: processedDirectory,
                                withIntermediateDirectories: true)
    }

    private func moveToProcessed(path: String, filename: String) {
        let dest = (processedDirectory as NSString).appendingPathComponent(filename)
        try? FileManager.default.moveItem(atPath: path, toPath: dest)
    }

    private func cleanupProcessedFiles() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            atPath: processedDirectory) else { return }

        let cutoff = Date().addingTimeInterval(-Self.processedFileMaxAge)
        var cleaned = 0

        for filename in entries {
            let path = (processedDirectory as NSString)
                .appendingPathComponent(filename)
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let mod = attrs[.modificationDate] as? Date,
                  mod < cutoff else { continue }
            try? fm.removeItem(atPath: path)
            cleaned += 1
        }

        if cleaned > 0 {
            NSLog("[Pushling/Feed] Cleaned up %d processed feed files", cleaned)
        }
    }
}
