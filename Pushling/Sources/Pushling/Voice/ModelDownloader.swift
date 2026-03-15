// ModelDownloader.swift — TTS model download, extraction, installation
// Downloads archives from k2-fsa/sherpa-onnx GitHub releases, extracts,
// and places files in the correct tier directories. espeak-ng-data is
// shared across tiers via symlinks to save disk space.

import Foundation

// MARK: - Download URLs (pinned to sherpa-onnx tts-models release)

/// Archive URLs for each model tier from k2-fsa/sherpa-onnx releases.
enum ModelDownloadSource {
    /// Piper VITS en_US-amy-low — used for both espeak-ng babble
    /// and Piper emerging speech (~16MB compressed).
    static let piperArchiveURL = URL(string:
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
        + "tts-models/vits-piper-en_US-amy-low.tar.bz2"
    )!
    static let piperExtractDir = "vits-piper-en_US-amy-low"

    /// Kokoro multilingual v1.0 — clear speech for Beast+ stages
    /// (~80MB compressed).
    static let kokoroArchiveURL = URL(string:
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
        + "tts-models/kokoro-multi-lang-v1_0.tar.bz2"
    )!
    static let kokoroExtractDir = "kokoro-multi-lang-v1_0"
}

// MARK: - Model Download Extension

extension ModelManager {

    // MARK: - Download Models

    /// Download model files for a specific tier. Downloads the archive,
    /// extracts it, places files, then re-scans to update status.
    func requestDownload(
        tier: VoiceTier,
        progress: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        // Don't start duplicate downloads
        guard !isDownloading(tier) else {
            NSLog("[Pushling/Voice/Models] Download already in progress"
                  + " for %@", tier.rawValue)
            completion(false)
            return
        }

        // Mark status as downloading
        updateTierStatus(tier, to: .downloading)

        NSLog("[Pushling/Voice/Models] Starting download for %@",
              tier.rawValue)

        let archiveURL: URL
        let extractDir: String

        switch tier {
        case .babble, .emerging:
            archiveURL = ModelDownloadSource.piperArchiveURL
            extractDir = ModelDownloadSource.piperExtractDir
        case .speaking:
            archiveURL = ModelDownloadSource.kokoroArchiveURL
            extractDir = ModelDownloadSource.kokoroExtractDir
        }

        let tmpDir = "\(modelsDirectory)/.tmp"
        try? FileManager.default.createDirectory(
            atPath: tmpDir, withIntermediateDirectories: true
        )

        // Create a download delegate for progress tracking
        let delegate = ModelDownloadDelegate(
            tier: tier,
            progressCallback: progress
        )

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )
        let task = session.downloadTask(with: archiveURL) {
            [weak self] tempURL, _, error in
            guard let self = self else { return }

            // Clear active download
            self.clearActiveDownload(tier)

            guard let tempURL = tempURL, error == nil else {
                NSLog("[Pushling/Voice/Models] Download failed for %@:"
                      + " %@", tier.rawValue,
                      error?.localizedDescription ?? "unknown error")
                self.updateTierStatus(tier, to: .missing)
                DispatchQueue.main.async { completion(false) }
                session.invalidateAndCancel()
                return
            }

            // Extract and install on a background queue
            DispatchQueue.global(qos: .userInitiated).async {
                let ok = ModelArchiveInstaller.extractAndInstall(
                    tier: tier,
                    archiveTempURL: tempURL,
                    extractDir: extractDir,
                    tmpDir: tmpDir,
                    manager: self
                )

                // Re-scan models
                self.scanModels()

                DispatchQueue.main.async {
                    if ok {
                        NSLog("[Pushling/Voice/Models] %@ download"
                              + " complete", tier.rawValue)
                    } else {
                        NSLog("[Pushling/Voice/Models] %@ install"
                              + " failed", tier.rawValue)
                    }
                    completion(ok)
                }
                session.invalidateAndCancel()
            }
        }

        setActiveDownload(task, for: tier)
        task.resume()
    }

    /// Download all missing tiers sequentially.
    /// Starts with babble, then emerging, then speaking.
    func downloadAllMissing(
        progress: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        let missingTiers: [VoiceTier] = [.babble, .emerging, .speaking]
            .filter { tierStatus[$0]?.status.isUsable != true }

        guard !missingTiers.isEmpty else {
            NSLog("[Pushling/Voice/Models] All models already installed")
            completion(true)
            return
        }

        NSLog("[Pushling/Voice/Models] Downloading %d missing tier(s)",
              missingTiers.count)

        downloadTiersSequentially(
            tiers: missingTiers, index: 0,
            progress: progress, completion: completion
        )
    }

    /// Recursively download tiers one at a time.
    private func downloadTiersSequentially(
        tiers: [VoiceTier], index: Int,
        progress: @escaping (DownloadProgress) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        guard index < tiers.count else {
            completion(true)
            return
        }

        let tier = tiers[index]
        requestDownload(tier: tier, progress: progress) {
            [weak self] success in
            guard success else {
                completion(false)
                return
            }
            self?.downloadTiersSequentially(
                tiers: tiers, index: index + 1,
                progress: progress, completion: completion
            )
        }
    }

    // MARK: - Launch Voice Setup Script

    /// Launch the `pushling-voice-setup` script as an external process.
    /// This is the preferred method for interactive downloads — the
    /// script shows progress bars and handles all three tiers.
    ///
    /// Returns true if the script was found and launched.
    @discardableResult
    func launchVoiceSetup(tier: String = "--all") -> Bool {
        let searchPaths = [
            Bundle.main.bundlePath
                + "/../bin/pushling-voice-setup",
            Bundle.main.bundlePath
                + "/../../../../bin/pushling-voice-setup",
            "/usr/local/bin/pushling-voice-setup",
            "/opt/homebrew/bin/pushling-voice-setup",
        ]

        let fm = FileManager.default
        var scriptPath: String?
        for path in searchPaths {
            if fm.isExecutableFile(atPath: path) {
                scriptPath = path
                break
            }
        }

        guard let path = scriptPath else {
            NSLog("[Pushling/Voice/Models] pushling-voice-setup script"
                  + " not found — use in-app download instead")
            return false
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = [tier]

        do {
            try proc.run()
            NSLog("[Pushling/Voice/Models] Launched voice setup: %@"
                  + " %@", path, tier)
            return true
        } catch {
            NSLog("[Pushling/Voice/Models] Failed to launch voice"
                  + " setup: %@", error.localizedDescription)
            return false
        }
    }
}

// MARK: - Archive Installer

/// Handles extracting downloaded archives and installing model files
/// to the correct tier directories.
enum ModelArchiveInstaller {

    /// Extract a downloaded archive and install files to the correct
    /// tier directory. Returns true on success.
    static func extractAndInstall(
        tier: VoiceTier,
        archiveTempURL: URL,
        extractDir: String,
        tmpDir: String,
        manager: ModelManager
    ) -> Bool {
        let fm = FileManager.default

        // Copy the temp file to our tmp dir (may be deleted otherwise)
        let archivePath = "\(tmpDir)/archive.tar.bz2"
        do {
            if fm.fileExists(atPath: archivePath) {
                try fm.removeItem(atPath: archivePath)
            }
            try fm.copyItem(
                atPath: archiveTempURL.path, toPath: archivePath
            )
        } catch {
            NSLog("[Pushling/Voice/Models] Failed to copy archive: %@",
                  error.localizedDescription)
            return false
        }

        // Extract using tar (available on all macOS)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        proc.arguments = ["xf", archivePath, "-C", tmpDir]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            NSLog("[Pushling/Voice/Models] tar extraction failed: %@",
                  error.localizedDescription)
            return false
        }

        guard proc.terminationStatus == 0 else {
            NSLog("[Pushling/Voice/Models] tar exited with status %d",
                  proc.terminationStatus)
            return false
        }

        let srcDir = "\(tmpDir)/\(extractDir)"
        guard fm.fileExists(atPath: srcDir) else {
            NSLog("[Pushling/Voice/Models] Expected directory not found"
                  + " after extraction: %@", extractDir)
            return false
        }

        // Install files based on tier
        let ok: Bool
        switch tier {
        case .babble:
            ok = installEspeakFiles(from: srcDir, manager: manager)
        case .emerging:
            ok = installPiperFiles(from: srcDir, manager: manager)
        case .speaking:
            ok = installKokoroFiles(from: srcDir, manager: manager)
        }

        // Clean up tmp files
        try? fm.removeItem(atPath: archivePath)
        try? fm.removeItem(atPath: srcDir)

        return ok
    }

    // MARK: - Per-Tier Installers

    /// Install espeak-ng babble tier files from extracted Piper archive.
    private static func installEspeakFiles(
        from srcDir: String, manager: ModelManager
    ) -> Bool {
        let fm = FileManager.default
        manager.ensureDirectories()
        let dst = manager.espeakDir

        do {
            try copyFile(
                fm, from: "\(srcDir)/en_US-amy-low.onnx",
                to: "\(dst)/model.onnx"
            )
            try copyFile(
                fm, from: "\(srcDir)/tokens.txt",
                to: "\(dst)/tokens.txt"
            )
            try copyDirectory(
                fm, from: "\(srcDir)/espeak-ng-data",
                to: "\(dst)/espeak-ng-data"
            )
            return true
        } catch {
            NSLog("[Pushling/Voice/Models] espeak install failed: %@",
                  error.localizedDescription)
            return false
        }
    }

    /// Install Piper emerging tier files from extracted archive.
    private static func installPiperFiles(
        from srcDir: String, manager: ModelManager
    ) -> Bool {
        let fm = FileManager.default
        manager.ensureDirectories()
        let dst = manager.piperDir

        do {
            try copyFile(
                fm, from: "\(srcDir)/en_US-amy-low.onnx",
                to: "\(dst)/en_US-amy-low.onnx"
            )
            try copyFile(
                fm, from: "\(srcDir)/tokens.txt",
                to: "\(dst)/tokens.txt"
            )
            // Symlink espeak-ng-data from Tier 1 if available
            try linkOrCopyEspeakData(
                fm, from: "\(srcDir)/espeak-ng-data",
                to: "\(dst)/espeak-ng-data",
                symlinkSource: "\(manager.espeakDir)/espeak-ng-data"
            )
            return true
        } catch {
            NSLog("[Pushling/Voice/Models] Piper install failed: %@",
                  error.localizedDescription)
            return false
        }
    }

    /// Install Kokoro speaking tier files from extracted archive.
    private static func installKokoroFiles(
        from srcDir: String, manager: ModelManager
    ) -> Bool {
        let fm = FileManager.default
        manager.ensureDirectories()
        let dst = manager.kokoroDir

        do {
            try copyFile(
                fm, from: "\(srcDir)/model.onnx",
                to: "\(dst)/model.onnx"
            )
            try copyFile(
                fm, from: "\(srcDir)/voices.bin",
                to: "\(dst)/voices.bin"
            )
            try copyFile(
                fm, from: "\(srcDir)/tokens.txt",
                to: "\(dst)/tokens.txt"
            )
            // Symlink espeak-ng-data from Tier 1 if available
            try linkOrCopyEspeakData(
                fm, from: "\(srcDir)/espeak-ng-data",
                to: "\(dst)/espeak-ng-data",
                symlinkSource: "\(manager.espeakDir)/espeak-ng-data"
            )
            // Copy optional lexicon files
            if let items = try? fm.contentsOfDirectory(atPath: srcDir) {
                for item in items where item.hasPrefix("lexicon-") {
                    try copyFile(
                        fm, from: "\(srcDir)/\(item)",
                        to: "\(dst)/\(item)"
                    )
                }
            }
            return true
        } catch {
            NSLog("[Pushling/Voice/Models] Kokoro install failed: %@",
                  error.localizedDescription)
            return false
        }
    }

    // MARK: - File Helpers

    /// Copy a file, removing the destination first if it exists.
    private static func copyFile(
        _ fm: FileManager, from src: String, to dst: String
    ) throws {
        if fm.fileExists(atPath: dst) {
            try fm.removeItem(atPath: dst)
        }
        try fm.copyItem(atPath: src, toPath: dst)
    }

    /// Copy a directory, removing the destination first if it exists.
    private static func copyDirectory(
        _ fm: FileManager, from src: String, to dst: String
    ) throws {
        if fm.fileExists(atPath: dst) {
            try fm.removeItem(atPath: dst)
        }
        try fm.copyItem(atPath: src, toPath: dst)
    }

    /// Symlink espeak-ng-data from Tier 1 if available, else copy.
    private static func linkOrCopyEspeakData(
        _ fm: FileManager,
        from src: String, to dst: String,
        symlinkSource: String
    ) throws {
        if fm.fileExists(atPath: dst) {
            try fm.removeItem(atPath: dst)
        }
        if fm.fileExists(atPath: symlinkSource) {
            try fm.createSymbolicLink(
                atPath: dst, withDestinationPath: symlinkSource
            )
        } else {
            try fm.copyItem(atPath: src, toPath: dst)
        }
    }
}

// MARK: - Download Delegate

/// URLSession delegate that tracks download progress for a single tier.
/// Used internally by ModelManager.requestDownload().
private final class ModelDownloadDelegate: NSObject,
    URLSessionDownloadDelegate {

    let tier: VoiceTier
    let progressCallback: (ModelManager.DownloadProgress) -> Void

    init(tier: VoiceTier,
         progressCallback: @escaping (ModelManager.DownloadProgress)
             -> Void) {
        self.tier = tier
        self.progressCallback = progressCallback
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = ModelManager.DownloadProgress(
            tier: tier,
            bytesDownloaded: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
        progressCallback(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled by the completion handler in the download task
    }
}
