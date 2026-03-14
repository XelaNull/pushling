// BackupManager.swift — Pushling daily SQLite backup system
// Uses VACUUM INTO for online backups that don't block WAL readers.
// Retains 30 days of backups, runs on a background thread.

import Foundation
import SQLite3

// MARK: - BackupManager

final class BackupManager {

    /// Backup directory: ~/.local/share/pushling/backups/
    static var backupDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.local/share/pushling/backups"
    }

    /// Reference to the database manager for running VACUUM INTO.
    private weak var databaseManager: DatabaseManager?

    /// Background queue for backup operations — never blocks the render loop.
    private let backupQueue = DispatchQueue(label: "com.pushling.backup",
                                            qos: .background)

    /// Maximum number of daily backups to retain.
    private static let maxBackupDays = 30

    /// Date formatter for backup file names.
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df
    }()

    /// Tracks the last successful backup date to avoid redundant backups.
    private var lastBackupDate: String?

    /// Whether a backup is currently in progress.
    private var isBackingUp = false

    /// Retry timer for failed backups (retry after 1 hour).
    private var retryTimer: DispatchSourceTimer?

    // MARK: - Lifecycle

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    deinit {
        retryTimer?.cancel()
    }

    // MARK: - Public API

    /// Checks if a backup is needed and runs one if so.
    /// Call this from the frame update loop (it dispatches to background).
    ///
    /// A backup is needed if:
    /// - No backup exists for today, OR
    /// - Force is true
    func backupIfNeeded(force: Bool = false) {
        guard !isBackingUp else { return }
        guard databaseManager != nil else { return }

        let today = Self.dateFormatter.string(from: Date())

        // Skip if we already backed up today (unless forced)
        if !force && lastBackupDate == today {
            return
        }

        // Check if today's backup file already exists
        let backupPath = self.backupPath(for: today)
        if !force && FileManager.default.fileExists(atPath: backupPath) {
            lastBackupDate = today
            return
        }

        // Run backup on background queue
        isBackingUp = true
        backupQueue.async { [weak self] in
            self?.performBackup(date: today)
        }
    }

    /// Performs backup on launch if none exists for today.
    /// Call once during app startup after database is open.
    func backupOnLaunchIfNeeded() {
        let today = Self.dateFormatter.string(from: Date())
        let backupPath = self.backupPath(for: today)

        if !FileManager.default.fileExists(atPath: backupPath) {
            NSLog("[Pushling/Backup] No backup for today — creating one")
            backupIfNeeded(force: true)
        } else {
            lastBackupDate = today
            NSLog("[Pushling/Backup] Today's backup already exists")
        }
    }

    // MARK: - Internal Backup Logic

    private func performBackup(date: String) {
        defer { isBackingUp = false }

        guard let db = databaseManager, db.isOpen,
              let connection = db.rawConnection else {
            NSLog("[Pushling/Backup] Cannot backup — database not available")
            scheduleRetry()
            return
        }

        let directory = Self.backupDirectory
        let backupPath = self.backupPath(for: date)

        // Ensure backup directory exists
        do {
            try FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            NSLog("[Pushling/Backup] Failed to create backup directory: %@",
                  "\(error)")
            scheduleRetry()
            return
        }

        // Use VACUUM INTO for an online backup that doesn't block readers
        let sql = "VACUUM INTO '\(backupPath)';"
        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(connection, sql, nil, nil, &errorMessage)

        if rc == SQLITE_OK {
            lastBackupDate = date
            retryTimer?.cancel()
            retryTimer = nil

            // Get backup file size for logging
            let size = fileSize(at: backupPath)
            NSLog("[Pushling/Backup] Backup successful: %@ (%@)",
                  backupPath, formatBytes(size))

            // Clean up old backups
            cleanupOldBackups()
        } else {
            let msg = errorMessage.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errorMessage)
            NSLog("[Pushling/Backup] Backup FAILED (code %d): %@", rc, msg)
            scheduleRetry()
        }
    }

    // MARK: - Cleanup

    /// Removes backups older than 30 days.
    private func cleanupOldBackups() {
        let fm = FileManager.default
        let directory = Self.backupDirectory

        guard let files = try? fm.contentsOfDirectory(atPath: directory) else {
            return
        }

        // Filter to backup files matching our naming pattern
        let backupFiles = files
            .filter { $0.hasPrefix("state-") && $0.hasSuffix(".db") }
            .sorted()

        // Keep only the most recent maxBackupDays files
        if backupFiles.count > Self.maxBackupDays {
            let toDelete = backupFiles.prefix(backupFiles.count - Self.maxBackupDays)
            for file in toDelete {
                let path = (directory as NSString).appendingPathComponent(file)
                do {
                    try fm.removeItem(atPath: path)
                    NSLog("[Pushling/Backup] Removed old backup: %@", file)
                } catch {
                    NSLog("[Pushling/Backup] Failed to remove old backup %@: %@",
                          file, "\(error)")
                }
            }
        }
    }

    // MARK: - Retry

    /// Schedules a retry in 1 hour after a failed backup.
    private func scheduleRetry() {
        retryTimer?.cancel()

        let source = DispatchSource.makeTimerSource(queue: backupQueue)
        source.schedule(deadline: .now() + 3600) // 1 hour
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let today = Self.dateFormatter.string(from: Date())
            self.performBackup(date: today)
        }
        source.resume()
        retryTimer = source

        NSLog("[Pushling/Backup] Retry scheduled in 1 hour")
    }

    // MARK: - Helpers

    /// Builds the backup file path for a given date string.
    private func backupPath(for date: String) -> String {
        return (Self.backupDirectory as NSString)
            .appendingPathComponent("state-\(date).db")
    }

    /// Returns the file size in bytes, or 0 if not found.
    private func fileSize(at path: String) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else {
            return 0
        }
        return size
    }

    /// Formats bytes into a human-readable string.
    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB",
                          Double(bytes) / (1024.0 * 1024.0))
        }
    }
}
