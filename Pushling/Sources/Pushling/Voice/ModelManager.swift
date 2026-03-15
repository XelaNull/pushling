// ModelManager.swift — TTS model discovery, validation, and status
// Checks for model files at ~/.local/share/pushling/voice/models/
// Manages 3 model tiers: espeak-ng (~16MB), Piper (~16MB), Kokoro (~80MB).
//
// Download logic lives in ModelDownloader.swift (extension on this class).
// Models can be pre-installed via `pushling voice download` or
// `bin/pushling-voice-setup`, or downloaded on-demand via URLSession.
//
// The manager reports model status for each tier, enabling graceful
// degradation: if Kokoro isn't present, the creature uses Piper.
// If nothing is present, voice system stays silent (text bubbles only).

import Foundation

// MARK: - Model Status

/// Status of a single model tier.
enum ModelStatus: String, CustomStringConvertible {
    case available    // Model files present and validated
    case missing      // Model files not found
    case downloading  // Download in progress
    case corrupted    // Files present but validation failed
    case incompatible // Wrong version or format

    var description: String { rawValue }

    var isUsable: Bool { self == .available }
}

// MARK: - Model Tier Info

/// Information about a model tier's files and status.
struct ModelTierInfo {
    let tier: VoiceTier
    let status: ModelStatus
    let directory: String
    let requiredFiles: [String]
    let presentFiles: [String]
    let totalSizeBytes: Int64
    let estimatedDownloadMB: Int

    /// Human-readable status message.
    var statusMessage: String {
        switch status {
        case .available:
            return "\(tier.rawValue): ready (\(totalSizeBytes / 1024)KB)"
        case .missing:
            let missing = Set(requiredFiles)
                .subtracting(presentFiles)
            return "\(tier.rawValue): missing files: "
                + missing.joined(separator: ", ")
        case .downloading:
            return "\(tier.rawValue): downloading..."
        case .corrupted:
            return "\(tier.rawValue): files corrupted, re-download needed"
        case .incompatible:
            return "\(tier.rawValue): incompatible model version"
        }
    }
}

// MARK: - Model Manager

/// Manages TTS model files on disk.
/// Checks availability, validates integrity, and provides paths
/// for the SherpaOnnxBridge to load.
///
/// Download capabilities are provided via extension in
/// ModelDownloader.swift.
final class ModelManager {

    // MARK: - Paths

    /// Base directory for all voice models.
    let modelsDirectory: String

    /// Per-tier subdirectories.
    var espeakDir: String { "\(modelsDirectory)/espeak-ng" }
    var piperDir: String { "\(modelsDirectory)/piper" }
    var kokoroDir: String { "\(modelsDirectory)/kokoro" }

    // MARK: - Required Files per Tier

    /// Files required for espeak-ng babble (Drop stage).
    private static let espeakRequiredFiles = [
        "model.onnx",
        "tokens.txt",
        "espeak-ng-data"  // Directory
    ]

    /// Files required for Piper VITS (Critter stage).
    private static let piperRequiredFiles = [
        "en_US-amy-low.onnx",
        "tokens.txt",
        "espeak-ng-data"  // Directory
    ]

    /// Files required for Kokoro-82M (Beast+ stage).
    private static let kokoroRequiredFiles = [
        "model.onnx",
        "voices.bin",
        "tokens.txt",
        "espeak-ng-data"  // Directory
    ]

    // MARK: - State

    /// Cached status for each tier (refreshed on scan).
    private(set) var tierStatus: [VoiceTier: ModelTierInfo] = [:]

    /// The highest available tier.
    var highestAvailableTier: VoiceTier? {
        if tierStatus[.speaking]?.status.isUsable == true {
            return .speaking
        }
        if tierStatus[.emerging]?.status.isUsable == true {
            return .emerging
        }
        if tierStatus[.babble]?.status.isUsable == true {
            return .babble
        }
        return nil
    }

    /// Whether ANY model is available (voice system can function).
    var hasAnyModel: Bool {
        return highestAvailableTier != nil
    }

    // MARK: - Download State (used by ModelDownloader.swift)

    /// Download progress for a tier.
    struct DownloadProgress {
        let tier: VoiceTier
        let bytesDownloaded: Int64
        let totalBytes: Int64
        var fraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesDownloaded) / Double(totalBytes)
        }
    }

    /// Active download tasks keyed by tier.
    private var activeDownloads: [VoiceTier: URLSessionDownloadTask] = [:]

    /// Whether a download is in progress for a given tier.
    func isDownloading(_ tier: VoiceTier) -> Bool {
        return activeDownloads[tier] != nil
    }

    /// Set an active download task (called from ModelDownloader).
    func setActiveDownload(
        _ task: URLSessionDownloadTask, for tier: VoiceTier
    ) {
        activeDownloads[tier] = task
    }

    /// Clear an active download (called from ModelDownloader).
    func clearActiveDownload(_ tier: VoiceTier) {
        activeDownloads[tier] = nil
    }

    /// Update a tier's status in the cache.
    func updateTierStatus(
        _ tier: VoiceTier, to status: ModelStatus
    ) {
        if let info = tierStatus[tier] {
            tierStatus[tier] = ModelTierInfo(
                tier: info.tier, status: status,
                directory: info.directory,
                requiredFiles: info.requiredFiles,
                presentFiles: info.presentFiles,
                totalSizeBytes: info.totalSizeBytes,
                estimatedDownloadMB: info.estimatedDownloadMB
            )
        }
    }

    // MARK: - Initialization

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.modelsDirectory =
            "\(home)/.local/share/pushling/voice/models"
    }

    /// Initialize with a custom models directory (for testing).
    init(modelsDirectory: String) {
        self.modelsDirectory = modelsDirectory
    }

    // MARK: - Scan

    /// Scan all model directories and update status.
    /// Call during voice system initialization and after downloads.
    func scanModels() {
        tierStatus[.babble] = scanTier(
            tier: .babble,
            directory: espeakDir,
            requiredFiles: Self.espeakRequiredFiles,
            estimatedDownloadMB: 16
        )

        tierStatus[.emerging] = scanTier(
            tier: .emerging,
            directory: piperDir,
            requiredFiles: Self.piperRequiredFiles,
            estimatedDownloadMB: 16
        )

        tierStatus[.speaking] = scanTier(
            tier: .speaking,
            directory: kokoroDir,
            requiredFiles: Self.kokoroRequiredFiles,
            estimatedDownloadMB: 80
        )

        NSLog("[Pushling/Voice/Models] Scan complete: %@",
              tierStatus.values.map { $0.statusMessage }
                .joined(separator: " | "))
    }

    /// Scan a single tier's directory for required files.
    private func scanTier(
        tier: VoiceTier,
        directory: String,
        requiredFiles: [String],
        estimatedDownloadMB: Int
    ) -> ModelTierInfo {
        let fm = FileManager.default

        guard fm.fileExists(atPath: directory) else {
            return ModelTierInfo(
                tier: tier, status: .missing, directory: directory,
                requiredFiles: requiredFiles, presentFiles: [],
                totalSizeBytes: 0,
                estimatedDownloadMB: estimatedDownloadMB
            )
        }

        // Check which required files/directories exist
        var presentFiles: [String] = []
        var totalSize: Int64 = 0

        for file in requiredFiles {
            let path = "\(directory)/\(file)"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir) {
                presentFiles.append(file)
                if isDir.boolValue {
                    totalSize += directorySize(path, fm: fm)
                } else {
                    if let attrs = try? fm.attributesOfItem(
                        atPath: path
                    ), let size = attrs[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }
        }

        let allPresent = Set(requiredFiles)
            .isSubset(of: Set(presentFiles))

        // Validate model files (basic size check)
        let status: ModelStatus
        if allPresent {
            if totalSize < 1024 {
                status = .corrupted
            } else {
                status = .available
            }
        } else {
            status = .missing
        }

        return ModelTierInfo(
            tier: tier, status: status, directory: directory,
            requiredFiles: requiredFiles, presentFiles: presentFiles,
            totalSizeBytes: totalSize,
            estimatedDownloadMB: estimatedDownloadMB
        )
    }

    /// Calculate total size of a directory recursively.
    private func directorySize(
        _ path: String, fm: FileManager
    ) -> Int64 {
        guard let enumerator = fm.enumerator(atPath: path) else {
            return 0
        }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? String {
            let filePath = "\(path)/\(file)"
            if let attrs = try? fm.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    // MARK: - Model Availability for Stage

    /// Check if the required model for a growth stage is available.
    func isModelAvailable(for stage: GrowthStage) -> Bool {
        guard let tier = VoiceTier.forStage(stage) else {
            return false  // Spore doesn't need a model
        }
        return tierStatus[tier]?.status.isUsable == true
    }

    /// Get the best available tier for a given stage.
    /// Falls back to lower tiers if the ideal one isn't available.
    func bestAvailableTier(for stage: GrowthStage) -> VoiceTier? {
        guard let idealTier = VoiceTier.forStage(stage) else {
            return nil  // Spore is silent
        }

        // Try ideal tier first
        if tierStatus[idealTier]?.status.isUsable == true {
            return idealTier
        }

        // Fall back to lower tiers
        let fallbackOrder: [VoiceTier]
        switch idealTier {
        case .speaking:
            fallbackOrder = [.emerging, .babble]
        case .emerging:
            fallbackOrder = [.babble]
        case .babble:
            fallbackOrder = []
        }

        for fallback in fallbackOrder {
            if tierStatus[fallback]?.status.isUsable == true {
                NSLog("[Pushling/Voice/Models] Falling back from"
                      + " %@ to %@",
                      idealTier.rawValue, fallback.rawValue)
                return fallback
            }
        }

        return nil
    }

    /// Get the sherpa-onnx config for a specific tier.
    func sherpaConfig(for tier: VoiceTier) -> SherpaTtsConfig? {
        guard tierStatus[tier]?.status.isUsable == true else {
            return nil
        }

        switch tier {
        case .babble:
            return SherpaOnnxBridge.espeakConfig(
                modelDir: modelsDirectory
            )
        case .emerging:
            return SherpaOnnxBridge.piperConfig(
                modelDir: modelsDirectory
            )
        case .speaking:
            return SherpaOnnxBridge.kokoroConfig(
                modelDir: modelsDirectory
            )
        }
    }

    // MARK: - Directory Setup

    /// Create the model directory structure if it doesn't exist.
    func ensureDirectories() {
        let fm = FileManager.default
        for dir in [modelsDirectory, espeakDir, piperDir, kokoroDir] {
            if !fm.fileExists(atPath: dir) {
                try? fm.createDirectory(
                    atPath: dir, withIntermediateDirectories: true
                )
            }
        }
    }

    // MARK: - Status Report

    /// Generate a human-readable status report for all model tiers.
    func statusReport() -> String {
        var lines: [String] = ["[Voice Models Status]"]
        lines.append("Directory: \(modelsDirectory)")

        for tier in [VoiceTier.babble, .emerging, .speaking] {
            if let info = tierStatus[tier] {
                lines.append("  \(info.statusMessage)")
            } else {
                lines.append("  \(tier.rawValue): not scanned")
            }
        }

        if let best = highestAvailableTier {
            lines.append("Best available: \(best.rawValue)")
        } else {
            lines.append("No models available — voice system disabled")
        }

        return lines.joined(separator: "\n")
    }
}
