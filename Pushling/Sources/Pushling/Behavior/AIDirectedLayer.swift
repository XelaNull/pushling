// AIDirectedLayer.swift — Layer 3: AI-Directed behavior
// Placeholder for Claude's MCP command queue. Inert until Phase 4,
// but structurally complete in the behavior stack.
//
// When active, this layer accepts commands from the MCP server via IPC,
// queues them, and outputs the appropriate LayerOutput for the current
// command. Commands have a 30s timeout — if no new command arrives,
// the layer begins a 5.0s fadeout back to Autonomous.
//
// Warm standby gradient: 10s/20s/30s with decreasing authority.
// After 10s idle: movements become slightly less precise.
// After 20s idle: speed normalizes toward autonomous defaults.
// After 30s idle: full fadeout begins (5.0s).

import Foundation
import CoreGraphics

// MARK: - AI Command

/// A command from Claude's MCP tools to direct the creature.
struct AICommand {
    /// Unique identifier for this command.
    let id: String

    /// The type of command (walk, speak, express, perform, etc.).
    let type: AICommandType

    /// The desired LayerOutput this command produces.
    let output: LayerOutput

    /// How long the command's output should be held (-1 = until next command).
    let holdDuration: TimeInterval

    /// When the command was enqueued.
    let enqueuedAt: TimeInterval

    /// Whether this command has been completed.
    var isComplete: Bool = false
}

/// Types of AI-directed commands.
enum AICommandType: String {
    case walk       // Walk to a position
    case speak      // Display speech bubble
    case express    // Change emotional expression
    case perform    // Perform a specific behavior/trick
    case look       // Look at something
    case idle       // Return to autonomous-like idle at current position
}

// MARK: - AI Layer State

/// The AI-directed layer's operational state.
enum AILayerState {
    /// Not active — outputs all nil. No Claude session.
    case inactive

    /// Actively executing a command.
    case executing

    /// Waiting for the next command (warm standby).
    /// Associated value is seconds since last command completed.
    case standby(idleTime: TimeInterval)

    /// Fading out control back to Autonomous (5.0s transition).
    /// Associated value is elapsed fadeout time.
    case fadingOut(elapsed: TimeInterval)
}

// MARK: - AI Directed Layer

final class AIDirectedLayer: BehaviorLayer {

    // MARK: - Constants

    /// Seconds without a new command before fadeout begins.
    private static let timeoutDuration: TimeInterval = 30.0

    /// Duration of the gradual control release.
    private static let fadeoutDuration: TimeInterval = 5.0

    /// Warm standby thresholds (seconds of idle time).
    private static let warmStandbyMild: TimeInterval = 10.0
    private static let warmStandbyModerate: TimeInterval = 20.0

    // MARK: - State

    /// Current operational state of the AI layer.
    private(set) var state: AILayerState = .inactive

    /// Queue of pending commands.
    private var commandQueue: [AICommand] = []

    /// The command currently being executed.
    private var currentCommand: AICommand?

    /// Scene time of the most recent command received.
    private var lastCommandTime: TimeInterval = 0

    /// Elapsed time executing the current command.
    private var commandElapsed: TimeInterval = 0

    /// Whether the AI layer is active (has a session connected).
    var isActive: Bool {
        if case .inactive = state { return false }
        return true
    }

    /// Whether the AI layer currently has opinions (non-nil output).
    var isOutputting: Bool {
        switch state {
        case .inactive:    return false
        case .executing:   return true
        case .standby:     return true  // Maintains position during standby
        case .fadingOut:   return true  // Still outputting during fade
        }
    }

    // MARK: - BehaviorLayer

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) -> LayerOutput {
        switch state {
        case .inactive:
            return .empty

        case .executing:
            return updateExecuting(deltaTime: deltaTime, currentTime: currentTime)

        case .standby(let idleTime):
            return updateStandby(idleTime: idleTime, deltaTime: deltaTime,
                                 currentTime: currentTime)

        case .fadingOut(let elapsed):
            return updateFadeout(elapsed: elapsed, deltaTime: deltaTime)
        }
    }

    // MARK: - Executing

    private func updateExecuting(deltaTime: TimeInterval,
                                 currentTime: TimeInterval) -> LayerOutput {
        guard let command = currentCommand else {
            // No current command but in executing state — transition to standby
            state = .standby(idleTime: 0)
            return .empty
        }

        commandElapsed += deltaTime

        // Check if command has a hold duration and it's elapsed
        if command.holdDuration > 0 && commandElapsed >= command.holdDuration {
            completeCurrentCommand(currentTime: currentTime)
            return currentCommand?.output ?? .empty
        }

        return command.output
    }

    // MARK: - Standby

    private func updateStandby(idleTime: TimeInterval,
                               deltaTime: TimeInterval,
                               currentTime: TimeInterval) -> LayerOutput {
        let newIdleTime = idleTime + deltaTime
        state = .standby(idleTime: newIdleTime)

        // Check for timeout -> fadeout
        if newIdleTime >= Self.timeoutDuration {
            state = .fadingOut(elapsed: 0)
            NSLog("[Pushling/Behavior] AI layer timeout — beginning fadeout")
            return .empty
        }

        // Warm standby: maintain last command's output but with decreasing authority
        guard let lastOutput = currentCommand?.output else {
            return .empty
        }

        // After 10s: movements become slightly less precise (position jitter)
        // After 20s: speed normalizes toward autonomous defaults
        // This is communicated through the output — the blend controller
        // handles the actual interpolation.
        var output = lastOutput

        if newIdleTime >= Self.warmStandbyModerate {
            // After 20s: clear speed override, let autonomous speed take over
            output.walkSpeed = nil
        } else if newIdleTime >= Self.warmStandbyMild {
            // After 10s: slightly reduce walk speed toward zero
            if let speed = output.walkSpeed {
                let factor = 1.0 - CGFloat((newIdleTime - Self.warmStandbyMild)
                    / (Self.warmStandbyModerate - Self.warmStandbyMild))
                output.walkSpeed = speed * max(factor, 0.3)
            }
        }

        return output
    }

    // MARK: - Fadeout

    private func updateFadeout(elapsed: TimeInterval,
                               deltaTime: TimeInterval) -> LayerOutput {
        let newElapsed = elapsed + deltaTime
        state = .fadingOut(elapsed: newElapsed)

        // Fadeout complete
        if newElapsed >= Self.fadeoutDuration {
            state = .inactive
            currentCommand = nil
            commandQueue.removeAll()
            NSLog("[Pushling/Behavior] AI layer fadeout complete — now inactive")
            return .empty
        }

        // During fadeout, we return an increasingly empty output.
        // The blend controller uses the AI release transition (5.0s)
        // to smoothly hand off to Autonomous.
        // Properties release in order: speed first, then expressions,
        // then position, matching the spec's gradient.
        let progress = newElapsed / Self.fadeoutDuration

        guard let lastOutput = currentCommand?.output else {
            return .empty
        }

        var output = LayerOutput()

        // Speed normalizes first (releases by t=0.6 / 3s)
        if progress < 0.6 {
            output.walkSpeed = lastOutput.walkSpeed
        }

        // Expressions release by t=0.4 (2s)
        if progress < 0.4 {
            output.bodyState = lastOutput.bodyState
            output.earLeftState = lastOutput.earLeftState
            output.earRightState = lastOutput.earRightState
            output.eyeLeftState = lastOutput.eyeLeftState
            output.eyeRightState = lastOutput.eyeRightState
            output.tailState = lastOutput.tailState
            output.mouthState = lastOutput.mouthState
            output.whiskerState = lastOutput.whiskerState
            output.auraState = lastOutput.auraState
            output.pawStates = lastOutput.pawStates
        }

        // Position holds longest — releases by t=0.8 (4s)
        if progress < 0.8 {
            output.positionX = lastOutput.positionX
            output.positionY = lastOutput.positionY
            output.facing = lastOutput.facing
        }

        return output
    }

    // MARK: - Command Queue Management

    /// Enqueue a new command from the MCP server.
    func enqueue(command: AICommand) {
        // If inactive, activate
        if case .inactive = state {
            NSLog("[Pushling/Behavior] AI layer activated")
        }

        lastCommandTime = command.enqueuedAt
        commandQueue.append(command)

        // If nothing is executing, start this command immediately
        if currentCommand == nil || currentCommand?.isComplete == true {
            executeNext(currentTime: command.enqueuedAt)
        }

        // If we were in standby or fadeout, resume executing
        state = .executing
    }

    /// Cancel the current command and begin fadeout.
    func cancel() {
        guard currentCommand != nil else { return }
        currentCommand?.isComplete = true

        if let next = commandQueue.first {
            commandQueue.removeFirst()
            currentCommand = next
            commandElapsed = 0
            state = .executing
        } else {
            state = .standby(idleTime: 0)
        }

        NSLog("[Pushling/Behavior] AI command cancelled")
    }

    /// Cancel all commands and begin fadeout.
    func cancelAll() {
        commandQueue.removeAll()
        currentCommand?.isComplete = true
        state = .fadingOut(elapsed: 0)
        NSLog("[Pushling/Behavior] All AI commands cancelled — fading out")
    }

    /// Called when the Claude session disconnects.
    func sessionEnded() {
        cancelAll()
    }

    // MARK: - Private

    /// Completes the current command and moves to the next or standby.
    private func completeCurrentCommand(currentTime: TimeInterval) {
        currentCommand?.isComplete = true

        if !commandQueue.isEmpty {
            executeNext(currentTime: currentTime)
        } else {
            state = .standby(idleTime: 0)
            NSLog("[Pushling/Behavior] AI command complete — entering standby")
        }
    }

    /// Dequeues and begins executing the next command.
    private func executeNext(currentTime: TimeInterval) {
        guard !commandQueue.isEmpty else { return }

        currentCommand = commandQueue.removeFirst()
        commandElapsed = 0
        lastCommandTime = currentTime
        state = .executing

        if let cmd = currentCommand {
            NSLog("[Pushling/Behavior] Executing AI command: %@ (%@)",
                  cmd.id, cmd.type.rawValue)
        }
    }
}
