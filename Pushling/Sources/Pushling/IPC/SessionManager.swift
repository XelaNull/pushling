// SessionManager.swift — Session lifecycle state machine for Pushling
// Tracks the active Claude session, enforces single-session, manages idle
// timeout gradient, and emits state changes for the diamond indicator
// and AI-directed behavior layer.
//
// No SpriteKit imports — this is pure state. The scene observes state
// changes and drives visual updates.
//
// Thread safety: All public methods are protected by a lock. The session
// manager is accessed from both the socket queue (IPC) and the render
// thread (idle timeout checks).

import Foundation

// MARK: - Session State

/// The current state of the Claude session lifecycle.
enum SessionState: Equatable {
    /// No active session.
    case disconnected

    /// Session is connecting (handshake in progress).
    case connecting(sessionId: String)

    /// Session is active and Claude is present.
    case connected(sessionId: String)

    /// Session is disconnecting (farewell animation in progress).
    case disconnecting(sessionId: String, reason: DisconnectReason)

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting(let a), .connecting(let b)):
            return a == b
        case (.connected(let a), .connected(let b)):
            return a == b
        case (.disconnecting(let a, _), .disconnecting(let b, _)):
            return a == b
        default:
            return false
        }
    }
}

/// The reason for a session disconnect.
enum DisconnectReason {
    /// Clean disconnect (SessionEnd hook or explicit disconnect command).
    case clean
    /// Abrupt disconnect (socket EOF, crash).
    case abrupt
    /// Evicted by stale session detection.
    case evicted
}

// MARK: - Idle Phase

/// The idle timeout phase, driving the autonomy gradient.
enum IdlePhase: Equatable {
    /// 0-10s: Attentive — diamond bright, creature alert.
    case attentive
    /// 10-20s: Settling — diamond dims slightly, autonomy creeping in.
    case settling
    /// 20-30s: Drifting — diamond dim, mostly autonomous.
    case drifting
    /// 30s+: Warm standby — fully autonomous, diamond at minimum.
    case warmStandby
}

// MARK: - Session Event

/// Events emitted by SessionManager for the scene/creature to react to.
enum SessionEvent {
    /// Session connected — materialize diamond, creature greeting.
    case sessionStarted(sessionId: String)
    /// Session disconnected — dissolve diamond, creature farewell.
    case sessionEnded(sessionId: String, reason: DisconnectReason, duration: TimeInterval)
    /// MCP command received — sparkle diamond, reset idle.
    case commandReceived
    /// Idle phase changed.
    case idlePhaseChanged(phase: IdlePhase)
    /// Subagents started — split diamond.
    case subagentsStarted(count: Int)
    /// Subagents stopped — reconverge diamond.
    case subagentsStopped
    /// Session rejected (second connection attempt).
    case sessionRejected(existingId: String, startedAgo: TimeInterval)
}

// MARK: - Session Info

/// Metadata about the active session.
struct SessionInfo {
    let sessionId: String
    let startTime: Date
    var lastCommandTime: Date
    var commandCount: Int
    var subagentCount: Int

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var timeSinceLastCommand: TimeInterval {
        Date().timeIntervalSince(lastCommandTime)
    }
}

// MARK: - Session Manager

/// Manages the session lifecycle between Claude (via MCP/IPC) and the creature.
/// Enforces single-session, tracks idle timeout, and emits events.
final class SessionManager {

    // MARK: - Constants

    /// Stale session threshold (10 minutes of no activity).
    private static let staleSessionThreshold: TimeInterval = 600.0

    /// Idle timeout thresholds (seconds since last command).
    private static let settlingThreshold: TimeInterval = 10.0
    private static let driftingThreshold: TimeInterval = 20.0
    private static let warmStandbyThreshold: TimeInterval = 30.0

    // MARK: - State

    /// Current session state.
    private(set) var state: SessionState = .disconnected

    /// Active session info (nil when disconnected).
    private(set) var activeSession: SessionInfo?

    /// Current idle phase.
    private(set) var currentIdlePhase: IdlePhase = .attentive

    /// Previous session end time (for reconnect detection).
    private(set) var lastSessionEndTime: Date?

    /// Previous session ID (for reconnect detection).
    private(set) var lastSessionId: String?

    // MARK: - Thread Safety

    private let lock = NSLock()

    // MARK: - Event Handler

    /// Callback invoked on session events. Called on the caller's thread.
    /// The scene or coordinator should observe these to drive visual changes.
    var onSessionEvent: ((SessionEvent) -> Void)?

    // MARK: - Session Lifecycle

    /// Attempt to start a new session. Returns the session ID on success,
    /// or an error result if a session is already active.
    func startSession() -> IPCResult {
        lock.lock()
        defer { lock.unlock() }

        // Check for existing session
        if let existing = activeSession {
            // Check if existing session is stale
            if existing.timeSinceLastCommand > Self.staleSessionThreshold {
                // Auto-evict stale session
                NSLog("[Pushling/Session] Evicting stale session %@ (inactive for %.0fs)",
                      existing.sessionId, existing.timeSinceLastCommand)
                endSessionInternal(reason: .evicted)
                // Fall through to create new session
            } else {
                // Reject — session already active
                let startedAgo = existing.duration
                let event = SessionEvent.sessionRejected(
                    existingId: existing.sessionId,
                    startedAgo: startedAgo
                )
                onSessionEvent?(event)

                let minutes = Int(startedAgo / 60)
                let errorMsg = "A session is already active "
                    + "(id: \(existing.sessionId), started: \(minutes) minutes ago). "
                    + "Only one Claude session can inhabit the creature at a time. "
                    + "The existing session must end first."

                NSLog("[Pushling/Session] Rejected second session — existing: %@",
                      existing.sessionId)
                return .failure(error: errorMsg, code: "SESSION_EXISTS")
            }
        }

        // Create new session
        let sessionId = UUID().uuidString
        let now = Date()
        let session = SessionInfo(
            sessionId: sessionId,
            startTime: now,
            lastCommandTime: now,
            commandCount: 0,
            subagentCount: 0
        )

        activeSession = session
        state = .connected(sessionId: sessionId)
        currentIdlePhase = .attentive

        // Emit event
        onSessionEvent?(.sessionStarted(sessionId: sessionId))

        NSLog("[Pushling/Session] Session started: %@", sessionId)

        return .success([
            "session_id": sessionId,
            "protocol_version": "1.0",
            "welcome": "Embodiment awakening..."
        ])
    }

    /// End the active session.
    func endSession(sessionId: String, reason: DisconnectReason) {
        lock.lock()
        defer { lock.unlock() }

        guard let session = activeSession, session.sessionId == sessionId else {
            NSLog("[Pushling/Session] Attempted to end unknown session: %@", sessionId)
            return
        }

        endSessionInternal(reason: reason)
    }

    /// End the active session (must be called with lock held).
    private func endSessionInternal(reason: DisconnectReason) {
        guard let session = activeSession else { return }

        let duration = session.duration
        state = .disconnecting(sessionId: session.sessionId, reason: reason)

        // Store for reconnect detection
        lastSessionEndTime = Date()
        lastSessionId = session.sessionId

        // Emit event
        onSessionEvent?(.sessionEnded(
            sessionId: session.sessionId,
            reason: reason,
            duration: duration
        ))

        // Clear session
        activeSession = nil
        currentIdlePhase = .attentive

        // Transition to disconnected (visual animation handles timing)
        state = .disconnected

        NSLog("[Pushling/Session] Session ended: %@ (reason: %@, duration: %.0fs, commands: %d)",
              session.sessionId,
              "\(reason)",
              duration,
              session.commandCount)
    }

    // MARK: - Command Tracking

    /// Record that a command was received from Claude.
    /// Resets idle timer and sparkles the diamond.
    func recordCommand() {
        lock.lock()
        defer { lock.unlock() }

        guard activeSession != nil else { return }
        activeSession?.lastCommandTime = Date()
        activeSession?.commandCount += 1

        // Reset idle phase
        let previousPhase = currentIdlePhase
        currentIdlePhase = .attentive

        if previousPhase != .attentive {
            onSessionEvent?(.idlePhaseChanged(phase: .attentive))
        }

        onSessionEvent?(.commandReceived)
    }

    // MARK: - Subagent Tracking

    /// Record that subagents have started.
    func subagentsStarted(count: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard activeSession != nil else { return }
        activeSession?.subagentCount = count
        onSessionEvent?(.subagentsStarted(count: count))
    }

    /// Record that subagents have stopped.
    func subagentsStopped() {
        lock.lock()
        defer { lock.unlock() }

        guard activeSession != nil else { return }
        activeSession?.subagentCount = 0
        onSessionEvent?(.subagentsStopped)
    }

    // MARK: - Idle Timeout Update

    /// Called periodically (e.g., every frame or every second) to update
    /// the idle timeout gradient.
    ///
    /// Returns the current diamond opacity multiplier (1.0 = full, 0.3 = minimum).
    @discardableResult
    func updateIdleTimeout() -> CGFloat {
        lock.lock()
        defer { lock.unlock() }

        guard let session = activeSession else { return 0.0 }
        let idleTime = session.timeSinceLastCommand

        // Determine idle phase
        let newPhase: IdlePhase
        if idleTime < Self.settlingThreshold {
            newPhase = .attentive
        } else if idleTime < Self.driftingThreshold {
            newPhase = .settling
        } else if idleTime < Self.warmStandbyThreshold {
            newPhase = .drifting
        } else {
            newPhase = .warmStandby
        }

        if newPhase != currentIdlePhase {
            currentIdlePhase = newPhase
            onSessionEvent?(.idlePhaseChanged(phase: newPhase))
            NSLog("[Pushling/Session] Idle phase: %@", "\(newPhase)")
        }

        // Calculate opacity multiplier:
        // 0-10s: 1.0
        // 10-30s: linear from 1.0 to 0.6
        // 30s+: 0.3 (but never invisible)
        if idleTime < Self.settlingThreshold {
            return 1.0
        } else if idleTime < Self.warmStandbyThreshold {
            let t = (idleTime - Self.settlingThreshold)
                / (Self.warmStandbyThreshold - Self.settlingThreshold)
            return CGFloat(1.0 - t * 0.4)  // 1.0 -> 0.6
        } else {
            return 0.3
        }
    }

    // MARK: - Queries

    /// Whether a session is currently active.
    var isSessionActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeSession != nil
    }

    /// The active session ID, if any.
    var activeSessionId: String? {
        lock.lock()
        defer { lock.unlock() }
        return activeSession?.sessionId
    }

    /// Whether this is a reconnect and how long since the last session.
    var reconnectInfo: (isReconnect: Bool, timeSince: TimeInterval)? {
        lock.lock()
        defer { lock.unlock() }

        guard let endTime = lastSessionEndTime else { return nil }
        let timeSince = Date().timeIntervalSince(endTime)
        return (isReconnect: true, timeSince: timeSince)
    }

    /// Whether the AI-directed layer should be active.
    /// True when connected and in attentive or settling phase.
    /// During drifting/warm standby, the AI layer should fade.
    var shouldAILayerBeActive: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard activeSession != nil else { return false }
        switch currentIdlePhase {
        case .attentive, .settling:
            return true
        case .drifting, .warmStandby:
            return false
        }
    }
}
