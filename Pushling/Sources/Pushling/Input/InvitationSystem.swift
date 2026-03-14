// InvitationSystem.swift — 1-2 creature invitations per hour during active use
// 6 types: ball-push, glowing-object, new-word, stuck-on-terrain,
// fish-offering, commit-release. 10s timeout if ignored. Personality-weighted
// selection. 20-minute cooldown between invitations. Drought timer at 40min.

import Foundation
import CoreGraphics

// MARK: - Invitation Type

/// The 6 invitation types the creature can initiate.
enum InvitationType: String, CaseIterable {
    case ballPush = "ball_push"
    case glowingObject = "glowing_object"
    case newWord = "new_word"
    case stuckOnTerrain = "stuck_on_terrain"
    case fishOffering = "fish_offering"
    case commitRelease = "commit_release"

    /// Minimum creature stage required for this invitation.
    var minimumStage: GrowthStage {
        switch self {
        case .ballPush:        return .critter
        case .glowingObject:   return .drop
        case .newWord:         return .critter
        case .stuckOnTerrain:  return .critter
        case .fishOffering:    return .beast
        case .commitRelease:   return .drop
        }
    }
}

// MARK: - Invitation State

/// The lifecycle state of an active invitation.
enum InvitationState {
    case setup          // Creature performing setup animation
    case offered        // Waiting for human response
    case accepted       // Human accepted
    case selfResolved   // Timeout — creature resolves alone
    case complete       // Invitation finished
}

// MARK: - Active Invitation

/// An invitation that is currently in progress.
struct ActiveInvitation {
    let type: InvitationType
    var state: InvitationState
    let startTime: TimeInterval
    var offerStartTime: TimeInterval?
    var cueTimer: TimeInterval      // Timer for repeating invitation cues
}

// MARK: - Invitation System

/// Manages creature-initiated interactive moments. Checks every 60 seconds
/// whether an invitation should fire, selects a type based on personality
/// and current state, and manages the offer/accept/timeout lifecycle.
final class InvitationSystem {

    // MARK: - Constants

    private static let checkInterval: TimeInterval = 60.0
    private static let baseProbability: Double = 0.03
    private static let droughtProbability: Double = 0.06
    private static let cooldownDuration: TimeInterval = 20 * 60
    private static let droughtThreshold: TimeInterval = 40 * 60
    private static let offerTimeout: TimeInterval = 10.0
    private static let cueInterval: TimeInterval = 3.0
    private static let setupDuration: TimeInterval = 1.0
    private static let activeUseWindow: TimeInterval = 5 * 60

    // MARK: - State

    /// The currently active invitation, if any.
    private(set) var activeInvitation: ActiveInvitation?

    /// Time since last invitation check.
    private var checkTimer: TimeInterval = 0

    /// Time of last invitation (for cooldown).
    private var lastInvitationTime: TimeInterval = 0

    /// Time of last activity (touch or commit).
    private var lastActivityTime: TimeInterval = 0

    /// Current creature stage.
    var creatureStage: GrowthStage = .critter

    /// Current personality snapshot.
    var personality: PersonalitySnapshot = .neutral

    /// Current emotional snapshot.
    var emotions: EmotionalSnapshot = .neutral

    /// Whether the creature is sleeping.
    var isSleeping = false

    /// Whether a mini-game is active.
    var isMiniGameActive = false

    /// Whether an evolution ceremony is playing.
    var isCeremonyActive = false

    /// Whether Claude AI is directing the creature.
    var isAIDirecting = false

    /// Callback for invitation events.
    var onInvitationEvent: ((InvitationEvent) -> Void)?

    // MARK: - Invitation Events

    enum InvitationEvent {
        case setup(type: InvitationType)
        case offer(type: InvitationType)
        case accepted(type: InvitationType)
        case selfResolved(type: InvitationType)
        case timeout(type: InvitationType)
        case cue(type: InvitationType)     // Repeated invitation hint
    }

    // MARK: - Activity Recording

    /// Records that an interaction occurred (keeps active-use alive).
    func recordActivity(at time: TimeInterval) {
        lastActivityTime = time
    }

    // MARK: - Per-Frame Update

    /// Called each frame. Manages invitation scheduling and lifecycle.
    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        // Update active invitation lifecycle
        if var invitation = activeInvitation {
            updateActiveInvitation(&invitation, currentTime: currentTime,
                                    deltaTime: deltaTime)
            activeInvitation = invitation
            return  // Don't check for new invitations while one is active
        }

        // Check for new invitation
        checkTimer += deltaTime
        if checkTimer >= Self.checkInterval {
            checkTimer = 0
            checkForNewInvitation(currentTime: currentTime)
        }
    }

    // MARK: - Invitation Lifecycle

    private func updateActiveInvitation(_ invitation: inout ActiveInvitation,
                                         currentTime: TimeInterval,
                                         deltaTime: TimeInterval) {
        switch invitation.state {
        case .setup:
            // Wait for setup to complete
            if currentTime - invitation.startTime >= Self.setupDuration {
                invitation.state = .offered
                invitation.offerStartTime = currentTime
                invitation.cueTimer = 0
                onInvitationEvent?(.offer(type: invitation.type))
            }

        case .offered:
            guard let offerStart = invitation.offerStartTime else { return }

            // Check timeout
            if currentTime - offerStart >= Self.offerTimeout {
                invitation.state = .selfResolved
                onInvitationEvent?(.selfResolved(type: invitation.type))
                completeInvitation(currentTime: currentTime)
                return
            }

            // Repeated cues
            invitation.cueTimer += deltaTime
            if invitation.cueTimer >= Self.cueInterval {
                invitation.cueTimer = 0
                onInvitationEvent?(.cue(type: invitation.type))
            }

        case .accepted:
            completeInvitation(currentTime: currentTime)

        case .selfResolved:
            completeInvitation(currentTime: currentTime)

        case .complete:
            activeInvitation = nil
        }
    }

    /// Called when the human accepts the current invitation.
    func acceptInvitation() {
        guard var invitation = activeInvitation,
              invitation.state == .offered else { return }

        invitation.state = .accepted
        activeInvitation = invitation
        onInvitationEvent?(.accepted(type: invitation.type))
        NSLog("[Pushling/Invitation] Accepted: %@", invitation.type.rawValue)
    }

    private func completeInvitation(currentTime: TimeInterval) {
        lastInvitationTime = currentTime
        activeInvitation?.state = .complete
        activeInvitation = nil
    }

    // MARK: - Scheduling

    private func checkForNewInvitation(currentTime: TimeInterval) {
        // Guard conditions
        guard !isSleeping else { return }
        guard !isMiniGameActive else { return }
        guard !isCeremonyActive else { return }
        guard !isAIDirecting else { return }

        // Active use check
        guard currentTime - lastActivityTime < Self.activeUseWindow else {
            return
        }

        // Cooldown check
        guard currentTime - lastInvitationTime >= Self.cooldownDuration else {
            return
        }

        // Probability check (with drought timer)
        let timeSinceLastInvitation = currentTime - lastInvitationTime
        let probability: Double
        if timeSinceLastInvitation > Self.droughtThreshold {
            probability = Self.droughtProbability
        } else {
            probability = Self.baseProbability
        }

        // High energy creatures invite more often
        let adjustedProbability = personality.energy > 0.6
            ? probability + 0.01
            : probability

        guard Double.random(in: 0...1) < adjustedProbability else { return }

        // Select invitation type
        guard let type = selectInvitationType() else { return }

        // Launch invitation
        let invitation = ActiveInvitation(
            type: type,
            state: .setup,
            startTime: currentTime,
            offerStartTime: nil,
            cueTimer: 0
        )
        activeInvitation = invitation
        onInvitationEvent?(.setup(type: type))

        NSLog("[Pushling/Invitation] Launching: %@", type.rawValue)
    }

    private func selectInvitationType() -> InvitationType? {
        // Filter by stage requirements
        let available = InvitationType.allCases.filter {
            $0.minimumStage <= creatureStage
        }
        guard !available.isEmpty else { return nil }

        // Weight by personality and emotion
        var weights: [InvitationType: Double] = [:]
        for type in available {
            var w = 1.0
            switch type {
            case .ballPush:
                if emotions.energy > 60 { w += 0.5 }
                if personality.energy > 0.6 { w += 0.3 }
            case .glowingObject:
                if emotions.curiosity > 60 { w += 0.5 }
                if personality.focus > 0.6 { w += 0.3 }
            case .newWord:
                if personality.verbosity > 0.5 { w += 0.5 }
            case .stuckOnTerrain:
                w = 0.8  // Slightly less common
            case .fishOffering:
                if emotions.contentment > 50 { w += 0.3 }
            case .commitRelease:
                w = 0.5  // Only during commit arrival
            }
            weights[type] = w
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        var roll = Double.random(in: 0..<totalWeight)
        for (type, weight) in weights {
            roll -= weight
            if roll <= 0 { return type }
        }

        return available.randomElement()
    }

    // MARK: - Reset

    func reset() {
        activeInvitation = nil
        checkTimer = 0
    }
}
