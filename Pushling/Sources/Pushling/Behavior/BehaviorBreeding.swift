// BehaviorBreeding.swift — Emergent behavior breeding system
// When two taught behaviors fire within 30s: 5% chance of breeding.
// Combines elements from both parents into a self-taught hybrid.
//
// Breeding algorithm:
//   1. Trigger conditions from parent A (fired first)
//   2. Movement tracks from parent B (fired second)
//   3. Merge speech/particle tracks from both (interleave)
//   4. Filter through personality
//   5. Auto-generate name: "[parentA]-[parentB]"
//
// Hybrids start at Learning mastery, decay faster (0.03/day).
// Max 5 self-taught behaviors. Claude can reinforce to make permanent.

import Foundation

// MARK: - Breeding Candidate

/// Tracks recent taught behavior performances for breeding detection.
struct BreedingCandidate {
    let behaviorName: String
    let definition: ChoreographyDefinition
    let performedAt: TimeInterval
}

// MARK: - Breeding Result

/// The result of a successful breeding attempt.
struct BreedingResult {
    let hybridDefinition: ChoreographyDefinition
    let parentA: String
    let parentB: String
    let name: String
}

// MARK: - BehaviorBreeding

/// Detects breeding opportunities and creates hybrid behaviors.
final class BehaviorBreeding {

    // MARK: - Configuration

    /// Time window for breeding detection (seconds).
    private static let breedingWindow: TimeInterval = 30.0

    /// Probability of breeding when two behaviors fire within window.
    private static let breedingChance: Double = 0.05

    /// Maximum self-taught behaviors.
    static let maxHybrids = 5

    /// Decay rate for hybrids (per day).
    static let hybridDecayRate: Double = 0.03

    // MARK: - State

    /// The most recent taught behavior performance.
    private var lastCandidate: BreedingCandidate?

    /// Names of all current hybrids (for cap enforcement).
    private var currentHybridNames: Set<String> = []

    /// Callback when a hybrid is bred.
    var onBreedingSuccess: ((BreedingResult) -> Void)?

    // MARK: - Breeding Detection

    /// Records that a taught behavior was performed.
    /// If a previous behavior was performed within 30s, checks for breeding.
    ///
    /// - Parameters:
    ///   - name: The behavior name.
    ///   - definition: The full choreography definition.
    ///   - currentTime: Scene time of performance.
    /// - Returns: A BreedingResult if breeding occurred, nil otherwise.
    @discardableResult
    func recordPerformance(
        name: String,
        definition: ChoreographyDefinition,
        currentTime: TimeInterval
    ) -> BreedingResult? {
        defer {
            lastCandidate = BreedingCandidate(
                behaviorName: name,
                definition: definition,
                performedAt: currentTime
            )
        }

        guard let previous = lastCandidate else { return nil }

        // Same behavior can't breed with itself
        guard previous.behaviorName != name else { return nil }

        // Check time window
        let elapsed = currentTime - previous.performedAt
        guard elapsed <= Self.breedingWindow else { return nil }

        // Cap check
        guard currentHybridNames.count < Self.maxHybrids else {
            NSLog("[Pushling/Breeding] At max hybrids (%d). Skipping.",
                  Self.maxHybrids)
            return nil
        }

        // Already bred this pair?
        let pairName = "\(previous.behaviorName)-\(name)"
        let reverseName = "\(name)-\(previous.behaviorName)"
        guard !currentHybridNames.contains(pairName),
              !currentHybridNames.contains(reverseName) else {
            return nil
        }

        // Roll for breeding
        guard Double.random(in: 0...1) < Self.breedingChance else {
            return nil
        }

        // Breed!
        let result = breed(parentA: previous, parentB: BreedingCandidate(
            behaviorName: name, definition: definition,
            performedAt: currentTime
        ))

        if let result = result {
            currentHybridNames.insert(result.name)
            onBreedingSuccess?(result)
            NSLog("[Pushling/Breeding] New hybrid bred: '%@' "
                  + "from '%@' + '%@'",
                  result.name, result.parentA, result.parentB)
        }

        return result
    }

    // MARK: - Breeding Algorithm

    /// Combines two parent behaviors into a hybrid.
    private func breed(parentA: BreedingCandidate,
                       parentB: BreedingCandidate) -> BreedingResult? {
        let defA = parentA.definition
        let defB = parentB.definition

        // 1. Triggers from parent A
        let triggers = defA.triggers

        // 2. Movement tracks from parent B
        var tracks: [String: [Keyframe]] = [:]

        // Take movement from B
        if let movementTrack = defB.tracks["movement"] {
            tracks["movement"] = movementTrack
        }

        // Take body/paw tracks from B (the "physical" moves)
        for trackName in ["body", "paw_fl", "paw_fr", "paw_bl", "paw_br"] {
            if let track = defB.tracks[trackName] {
                tracks[trackName] = track
            }
        }

        // 3. Take expression tracks from A
        for trackName in ["eyes", "ears", "tail", "mouth", "whiskers", "head"] {
            if let track = defA.tracks[trackName] {
                tracks[trackName] = track
            }
        }

        // 4. Merge speech/particle tracks (interleave by time)
        tracks["particles"] = mergeTracksInterleaved(
            defA.tracks["particles"], defB.tracks["particles"]
        )
        tracks["aura"] = mergeTracksInterleaved(
            defA.tracks["aura"], defB.tracks["aura"]
        )
        tracks["speech"] = mergeTracksInterleaved(
            defA.tracks["speech"], defB.tracks["speech"]
        )

        // Remove empty tracks
        tracks = tracks.filter { !$0.value.isEmpty }

        // 5. Use the longer duration
        let duration = max(defA.durationSeconds, defB.durationSeconds)

        // 6. Category from parent A
        let category = defA.category

        // 7. Stage min = max of both parents
        let stageMin: GrowthStage
        if defA.stageMin >= defB.stageMin {
            stageMin = defA.stageMin
        } else {
            stageMin = defB.stageMin
        }

        let name = "\(parentA.behaviorName)-\(parentB.behaviorName)"

        let hybrid = ChoreographyDefinition(
            name: name,
            category: category,
            stageMin: stageMin,
            durationSeconds: duration,
            tracks: tracks,
            triggers: triggers
        )

        return BreedingResult(
            hybridDefinition: hybrid,
            parentA: parentA.behaviorName,
            parentB: parentB.behaviorName,
            name: name
        )
    }

    /// Interleaves keyframes from two tracks by time.
    private func mergeTracksInterleaved(
        _ a: [Keyframe]?, _ b: [Keyframe]?
    ) -> [Keyframe] {
        var merged: [Keyframe] = []
        if let a = a { merged.append(contentsOf: a) }
        if let b = b { merged.append(contentsOf: b) }
        merged.sort { $0.time < $1.time }
        // Remove duplicates at same time (keep first)
        var seen: Set<Int> = []
        merged = merged.filter { kf in
            let bucket = Int(kf.time * 10)  // 100ms buckets
            if seen.contains(bucket) { return false }
            seen.insert(bucket)
            return true
        }
        return merged
    }

    // MARK: - Hybrid Management

    /// Registers an existing hybrid name (loaded from SQLite).
    func registerHybrid(name: String) {
        currentHybridNames.insert(name)
    }

    /// Removes a hybrid (when reinforced by Claude to become permanent,
    /// or when it decays away).
    func removeHybrid(name: String) {
        currentHybridNames.remove(name)
    }

    /// Whether the hybrid cap has been reached.
    var isAtHybridCap: Bool {
        currentHybridNames.count >= Self.maxHybrids
    }

    /// Current number of hybrids.
    var hybridCount: Int { currentHybridNames.count }

    /// All current hybrid names.
    var hybridNames: [String] { Array(currentHybridNames) }

    /// Resets all breeding state.
    func reset() {
        lastCandidate = nil
        currentHybridNames.removeAll()
    }
}
