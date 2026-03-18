// HotReloadMonitor.swift — Watches for new binary builds and triggers restart
// The app's LaunchAgent has KeepAlive: true, so exit(0) causes launchd to
// relaunch with the new binary automatically. This monitor detects when the
// binary has been replaced after a build and initiates a graceful restart.

import Foundation

final class HotReloadMonitor {

    // MARK: - Properties

    private let binaryPath: String
    private let binaryDirectory: String
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollingTimer: DispatchSourceTimer?
    private let monitorQueue = DispatchQueue(
        label: "com.pushling.hot-reload", qos: .utility
    )

    /// Modification date of the binary when monitoring started.
    private var lastModDate: Date?

    /// Debounce timer to wait for codesign to finish after binary write.
    private var debounceWorkItem: DispatchWorkItem?

    /// Called on the main thread when a newer binary is detected.
    var onNewBinaryDetected: (() -> Void)?

    // MARK: - Initialization

    init() {
        // Resolve the binary path from the running process
        let execPath = ProcessInfo.processInfo.arguments[0]
        // Resolve symlinks to get the real binary path
        self.binaryPath = (execPath as NSString).resolvingSymlinksInPath
        self.binaryDirectory = (binaryPath as NSString).deletingLastPathComponent

        NSLog("[Pushling/HotReload] Monitoring binary: %@", binaryPath)
    }

    // MARK: - Start / Stop

    func start() {
        // Record current modification date
        lastModDate = modificationDate(of: binaryPath)

        // Watch the directory containing the binary (not the file itself,
        // because builds replace the file — the old fd becomes stale)
        let fd = open(binaryDirectory, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: .write, queue: monitorQueue
            )
            source.setEventHandler { [weak self] in self?.checkForNewBinary() }
            source.setCancelHandler { close(fd) }
            source.resume()
            dispatchSource = source
            NSLog("[Pushling/HotReload] Directory watch active: %@",
                  binaryDirectory)
        } else {
            NSLog("[Pushling/HotReload] Cannot open directory for monitoring"
                  + " — falling back to polling only")
        }

        // 3-second polling fallback (catches cases where DispatchSource misses)
        let timer = DispatchSource.makeTimerSource(queue: monitorQueue)
        timer.schedule(deadline: .now() + 3.0, repeating: 3.0)
        timer.setEventHandler { [weak self] in self?.checkForNewBinary() }
        timer.resume()
        pollingTimer = timer
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        dispatchSource?.cancel()
        dispatchSource = nil
        pollingTimer?.cancel()
        pollingTimer = nil
        NSLog("[Pushling/HotReload] Monitor stopped")
    }

    // MARK: - Detection

    private func checkForNewBinary() {
        guard let currentMod = modificationDate(of: binaryPath),
              let lastMod = lastModDate else { return }

        if currentMod > lastMod {
            // Binary has been updated — debounce 1 second to let codesign finish
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                // Re-check after debounce to confirm the file is stable
                guard let finalMod = self.modificationDate(of: self.binaryPath),
                      finalMod > lastMod else { return }

                self.lastModDate = finalMod
                NSLog("[Pushling/HotReload] New binary detected — "
                      + "triggering graceful restart")

                DispatchQueue.main.async {
                    self.onNewBinaryDetected?()
                }
            }
            debounceWorkItem = work
            monitorQueue.asyncAfter(deadline: .now() + 1.0, execute: work)
        }
    }

    // MARK: - Helpers

    private func modificationDate(of path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[
            .modificationDate
        ] as? Date
    }
}
