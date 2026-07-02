// EggAccumulator.swift — Progressively learns about the developer from commits
//
// During the egg stage, each commit is silently absorbed and its data
// accumulated. After 5 commits, enough data exists to compute a unique
// personality and visual traits. The egg then cracks open into a styled Drop.

import Foundation

// MARK: - Mulberry32 PRNG

/// A simple, fast seeded PRNG. Same seed always produces the same sequence.
/// Used for deterministic rarity determination from identity hash.
private func mulberry32(_ seed: UInt32) -> (UInt32, Double) {
    var s = seed &+ 0x6D2B79F5
    s = (s ^ (s >> 15)) &* (s | 1)
    s ^= s &+ (s ^ (s >> 7)) &* (s | 61)
    let raw = s ^ (s >> 14)
    // Convert to [0, 1) double
    let fraction = Double(raw) / Double(UInt32.max)
    return (raw, fraction)
}

// MARK: - Identity Biases

/// Deterministic personality and visual biases derived from the developer's
/// git email hash. Computed once at egg→drop transition and baked into the
/// persisted personality and visual traits.
///
/// These biases are transient — they do not persist to SQLite directly.
/// Their effect is baked into the Personality and VisualTraits that do persist.
struct IdentityBiases {
    /// Hue shift applied to baseColorHue (±0.08).
    let hueShift: Double
    /// Eye shape tendency: 0.0 biases toward narrow, 1.0 toward round.
    /// 0.5 is neutral (commit data decides alone).
    let eyeTendency: Double
    /// Tail shape tendency: 0.0-0.25 thin, 0.25-0.5 serpentine,
    /// 0.5-0.75 fluffy, 0.75-1.0 standard. Only applied when commit data
    /// produces .standard (i.e. no dominant language signal).
    let tailTendency: Double
    /// Personality axis biases (±0.05). Applied before rarity spread.
    let energyBias: Double
    let verbosityBias: Double
    let focusBias: Double
    let disciplineBias: Double

    /// Zero bias — no identity influence.
    static let none = IdentityBiases(
        hueShift: 0,
        eyeTendency: 0.5,
        tailTendency: 0.5,
        energyBias: 0,
        verbosityBias: 0,
        focusBias: 0,
        disciplineBias: 0
    )
}

// MARK: - EggAccumulator

final class EggAccumulator {

    // MARK: - Accumulated Data

    private(set) var commitCount = 0
    var languageCounts: [String: Int] = [:]
    private(set) var totalMessageLength = 0
    private(set) var totalFilesChanged = 0
    private(set) var totalLinesAdded = 0
    private(set) var totalLinesRemoved = 0
    private(set) var repoNames: Set<String> = []
    private(set) var commitTimestamps: [Date] = []

    /// Number of commits required before the egg is ready to hatch.
    static let hatchThreshold = 5

    // MARK: - Record

    /// Record data from a commit. Call for each commit during the egg stage.
    func record(_ commit: CommitData) {
        commitCount += 1
        totalMessageLength += commit.message.count
        totalFilesChanged += commit.filesChanged
        totalLinesAdded += commit.linesAdded
        totalLinesRemoved += commit.linesRemoved
        repoNames.insert(commit.repoName)
        commitTimestamps.append(commit.timestamp)

        // Parse languages (may be CSV string or array)
        for lang in commit.languages where !lang.isEmpty {
            languageCounts[lang, default: 0] += 1
        }
    }

    /// Whether enough data has been accumulated to hatch.
    var isReadyToHatch: Bool { commitCount >= Self.hatchThreshold }

    /// Progress toward hatching (0.0 to 1.0).
    var hatchProgress: Double {
        min(1.0, Double(commitCount) / Double(Self.hatchThreshold))
    }

    // MARK: - Rarity Determination

    /// Compute an FNV-1a hash of the git user.email for use as a PRNG seed.
    /// Falls back to "unknown" if git is unavailable.
    static func gitEmailHash() -> UInt32 {
        let pipe = Pipe()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["config", "user.email"]
        task.standardOutput = pipe
        task.standardError = Pipe()  // suppress stderr
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let email = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"

        // FNV-1a hash → UInt32
        var hash: UInt32 = 2166136261
        for byte in email.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        NSLog("[Pushling/EggAccumulator] Identity seed from '%@': %u", email, hash)
        return hash
    }

    /// Determine rarity tier and shiny flag from a seed value.
    /// Two sequential PRNG draws from the seed: first for tier, second for shiny.
    /// Same seed always produces the same result.
    ///
    /// - Parameter seed: UInt32 identity hash (will use gitEmailHash() if not provided).
    /// - Returns: Tuple of (rarity, isShiny).
    static func determineRarity(seed: UInt32) -> (rarity: RarityTier, shiny: Bool) {
        // First draw: rarity tier
        let (seed2, rarityRoll) = mulberry32(seed)
        let tier = RarityTier.fromRoll(rarityRoll)

        // Second draw: shiny (1% independent)
        let (_, shinyRoll) = mulberry32(seed2)
        let isShiny = shinyRoll < 0.01

        NSLog("[Pushling/EggAccumulator] Rarity determined: %@ (shiny: %@)",
              tier.rawValue, isShiny ? "yes" : "no")
        return (tier, isShiny)
    }

    // MARK: - Identity Bias Computation

    /// Compute deterministic identity biases from a seed (typically the FNV-1a
    /// hash of the developer's git email). Same seed always produces identical
    /// biases. Uses draws 3-9 of the mulberry32 chain starting from an offset
    /// seed so these draws are independent of the rarity draws (1-2).
    ///
    /// Offset seed: `seed ^ 0xDEADBEEF` — keeps bias and rarity chains independent.
    ///
    /// - Parameter seed: UInt32 identity hash (from `gitEmailHash()`).
    /// - Returns: `IdentityBiases` struct with all 7 bias values.
    static func computeIdentityBiases(seed: UInt32) -> IdentityBiases {
        // Use an offset seed so the bias chain is independent from rarity draws.
        let biasSeed: UInt32 = seed ^ 0xDEAD_BEEF

        // Draw 1: hue shift → map [0,1) to [-0.08, +0.08]
        let (s1, hueRaw)       = mulberry32(biasSeed)
        // Draw 2: eye tendency → [0,1) used directly as tendency
        let (s2, eyeRaw)       = mulberry32(s1)
        // Draw 3: tail tendency → [0,1) used directly as tendency
        let (s3, tailRaw)      = mulberry32(s2)
        // Draw 4: energy bias → map [0,1) to [-0.05, +0.05]
        let (s4, energyRaw)    = mulberry32(s3)
        // Draw 5: verbosity bias
        let (s5, verbosityRaw) = mulberry32(s4)
        // Draw 6: focus bias
        let (s6, focusRaw)     = mulberry32(s5)
        // Draw 7: discipline bias
        let (_, disciplineRaw) = mulberry32(s6)

        return IdentityBiases(
            hueShift:       (hueRaw - 0.5) * 0.16,
            eyeTendency:    eyeRaw,
            tailTendency:   tailRaw,
            energyBias:     (energyRaw - 0.5) * 0.10,
            verbosityBias:  (verbosityRaw - 0.5) * 0.10,
            focusBias:      (focusRaw - 0.5) * 0.10,
            disciplineBias: (disciplineRaw - 0.5) * 0.10
        )
    }

    // MARK: - Personality Computation

    /// Compute personality from accumulated commit data.
    /// - Parameter raritySpread: Optional spread bonus from rarity tier.
    ///   Pushes each axis further from 0.5 (neutral). Default 0 = no change.
    /// - Parameter identityBias: Optional bias derived from the developer's
    ///   git email hash. Applied before rarity spread so the spread amplifies
    ///   the identity signal. Default nil = no bias (backward compatible).
    func computePersonality(raritySpread: Double = 0.0,
                             identityBias: IdentityBiases? = nil) -> Personality {
        let avgMessageLength = commitCount > 0
            ? Double(totalMessageLength) / Double(commitCount) : 30.0
        let avgFilesPerCommit = commitCount > 0
            ? Double(totalFilesChanged) / Double(commitCount) : 2.0

        // Energy: burst frequency — were commits clustered or spread out?
        let rawEnergy: Double
        if commitTimestamps.count >= 2 {
            let intervals = zip(commitTimestamps, commitTimestamps.dropFirst())
                .map { $1.timeIntervalSince($0) }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            // Short intervals (< 5 min) = high energy, long (> 30 min) = low
            rawEnergy = max(0, min(1, 1.0 - (avgInterval / 1800.0)))
        } else {
            rawEnergy = 0.5
        }

        // Verbosity: average message length
        let rawVerbosity = max(0, min(1, (avgMessageLength - 10) / 60.0))

        // Focus: files per commit (fewer = more focused)
        let rawFocus = max(0, min(1, 1.0 - (avgFilesPerCommit - 1) / 10.0))

        // Discipline: timing consistency (limited with few commits)
        let rawDiscipline = 0.5  // neutral with so few data points

        // Specialty: dominant language
        let specialty = dominantLanguageCategory()

        // Apply identity bias BEFORE rarity spread so the spread amplifies it.
        // Bias clamps within [0,1] before spread, then spread clamps again.
        let bias = identityBias ?? .none
        func applyBias(_ axis: Double, _ biasValue: Double) -> Double {
            return max(0.0, min(1.0, axis + biasValue))
        }

        let biasedEnergy     = applyBias(rawEnergy,     bias.energyBias)
        let biasedVerbosity  = applyBias(rawVerbosity,  bias.verbosityBias)
        let biasedFocus      = applyBias(rawFocus,      bias.focusBias)
        let biasedDiscipline = applyBias(rawDiscipline, bias.disciplineBias)

        // Apply rarity spread: push each axis further from neutral (0.5)
        // axis = 0.5 + (axis - 0.5) * (1.0 + spreadBonus)
        func applySpread(_ axis: Double) -> Double {
            let spread = 0.5 + (axis - 0.5) * (1.0 + raritySpread)
            return max(0.0, min(1.0, spread))
        }

        return Personality(
            energy:     applySpread(biasedEnergy),
            verbosity:  applySpread(biasedVerbosity),
            focus:      applySpread(biasedFocus),
            discipline: applySpread(biasedDiscipline),
            specialty:  specialty
        )
    }

    // MARK: - Visual Traits Computation

    /// Compute visual traits from accumulated commit data.
    /// - Parameter identityBias: Optional bias derived from the developer's
    ///   git email hash. Shifts hue and biases eye/tail shape selection.
    ///   Default nil = no bias (backward compatible).
    func computeVisualTraits(identityBias: IdentityBiases? = nil) -> VisualTraits {
        // Personality is computed without bias here — visual traits use the
        // raw commit-data personality for bodyProportion/specialty signals,
        // and apply bias separately to hue, eye, and tail.
        let personality = computePersonality()
        let repoCount = repoNames.count
        let bias = identityBias ?? .none

        let avgMessageLength = commitCount > 0
            ? Double(totalMessageLength) / Double(commitCount) : 30.0

        // Hue: commit-data specialty hue plus identity hue shift, clamped to [0,1).
        let rawHue = personality.specialty.baseColorHue + bias.hueShift
        let baseColorHue = (rawHue.truncatingRemainder(dividingBy: 1.0) + 1.0)
            .truncatingRemainder(dividingBy: 1.0)  // wrap to [0,1) rather than clamp

        // Eye shape: shift effective message length by ±15 chars based on
        // eyeTendency (0.5 = neutral, 0.0 = bias toward narrow, 1.0 = toward round).
        let eyeLengthShift = (bias.eyeTendency - 0.5) * 30.0
        let eyeShape = EyeShape.fromAverageMessageLength(
            avgMessageLength + eyeLengthShift
        )

        // Tail shape: commit-data category decides. If it produces .standard
        // (the "no dominant signal" fallback), identity tendency breaks the tie.
        let categoryTail = TailShape.fromCategory(personality.specialty)
        let tailShape: TailShape
        if categoryTail == .standard {
            // Identity tendency selects an alternative:
            // [0.00, 0.25) → thin, [0.25, 0.50) → serpentine,
            // [0.50, 0.75) → fluffy, [0.75, 1.00] → keep standard
            switch bias.tailTendency {
            case ..<0.25:  tailShape = .thin
            case ..<0.50:  tailShape = .serpentine
            case ..<0.75:  tailShape = .fluffy
            default:       tailShape = .standard
            }
        } else {
            tailShape = categoryTail
        }

        return VisualTraits(
            baseColorHue:   baseColorHue,
            bodyProportion: personality.focus,
            furPattern:     FurPattern.fromRepoCount(repoCount),
            tailShape:      tailShape,
            eyeShape:       eyeShape
        )
    }

    // MARK: - Private

    private func dominantLanguageCategory() -> LanguageCategory {
        guard let topLang = languageCounts.max(by: { $0.value < $1.value })
        else { return .polyglot }
        return LanguageCategory.extensionMap[topLang.key] ?? .polyglot
    }
}
