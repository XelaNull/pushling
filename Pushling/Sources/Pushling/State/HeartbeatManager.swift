// HeartbeatManager.swift — Pushling crash recovery via heartbeat file
// Writes /tmp/pushling.heartbeat every 30 seconds with PID and timestamp.
// On launch, detects unclean shutdowns and logs crash recovery events.

import Foundation

// MARK: - HeartbeatState

/// JSON payload written to the heartbeat file.
struct HeartbeatPayload: Codable {
    let pid: Int32
    let timestamp: String
    let state: String  // "running" or "shutdown"
}

// MARK: - CrashRecoveryInfo

/// Information about a detected crash, used by the caller.
struct CrashRecoveryInfo {
    let previousPID: Int32
    let lastHeartbeat: String
    let crashDetected: Bool
}

// MARK: - HeartbeatManager

final class HeartbeatManager {

    /// Heartbeat file path.
    static let heartbeatPath = "/tmp/pushling.heartbeat"

    /// Heartbeat write interval in seconds.
    private static let heartbeatInterval: TimeInterval = 30.0

    /// Timer for periodic heartbeat writes.
    private var timer: DispatchSourceTimer?

    /// The dispatch queue for heartbeat I/O.
    private let queue = DispatchQueue(label: "com.pushling.heartbeat",
                                      qos: .utility)

    /// Current process ID.
    private let pid = ProcessInfo.processInfo.processIdentifier

    /// JSON encoder reused across writes.
    private let encoder = JSONEncoder()

    /// Reference to database manager for crash recovery journal entries.
    private weak var databaseManager: DatabaseManager?

    // MARK: - Lifecycle

    init(databaseManager: DatabaseManager? = nil) {
        self.databaseManager = databaseManager
    }

    deinit {
        stop()
    }

    // MARK: - Crash Detection (Call Before Starting)

    /// Checks for a previous unclean shutdown.
    /// Call this on launch BEFORE calling `start()`.
    ///
    /// - Returns: `CrashRecoveryInfo` describing what was found.
    func checkForCrash() -> CrashRecoveryInfo {
        let path = Self.heartbeatPath
        let fm = FileManager.default

        guard fm.fileExists(atPath: path) else {
            NSLog("[Pushling/Heartbeat] No previous heartbeat file — clean start")
            return CrashRecoveryInfo(previousPID: 0,
                                     lastHeartbeat: "",
                                     crashDetected: false)
        }

        // Read the heartbeat file
        guard let data = fm.contents(atPath: path),
              let payload = try? JSONDecoder().decode(HeartbeatPayload.self,
                                                      from: data) else {
            NSLog("[Pushling/Heartbeat] Heartbeat file exists but unreadable — "
                  + "treating as crash")
            cleanup()
            return CrashRecoveryInfo(previousPID: 0,
                                     lastHeartbeat: "",
                                     crashDetected: true)
        }

        // If state is "shutdown", previous quit was clean
        if payload.state == "shutdown" {
            NSLog("[Pushling/Heartbeat] Previous shutdown was clean "
                  + "(PID %d at %@)", payload.pid, payload.timestamp)
            cleanup()
            return CrashRecoveryInfo(previousPID: payload.pid,
                                     lastHeartbeat: payload.timestamp,
                                     crashDetected: false)
        }

        // State is "running" — check if the PID is still alive
        if isProcessRunning(pid: payload.pid) {
            NSLog("[Pushling/Heartbeat] WARNING: Previous instance (PID %d) "
                  + "is still running!", payload.pid)
            // Another instance is running — this is not a crash, but a
            // duplicate launch. The caller should handle this.
            return CrashRecoveryInfo(previousPID: payload.pid,
                                     lastHeartbeat: payload.timestamp,
                                     crashDetected: false)
        }

        // PID is not running and state was "running" — crash detected
        NSLog("[Pushling/Heartbeat] CRASH DETECTED: Previous PID %d, "
              + "last heartbeat %@", payload.pid, payload.timestamp)

        // Log crash recovery to journal
        logCrashRecovery(previousPID: payload.pid,
                         lastHeartbeat: payload.timestamp)

        cleanup()
        return CrashRecoveryInfo(previousPID: payload.pid,
                                 lastHeartbeat: payload.timestamp,
                                 crashDetected: true)
    }

    // MARK: - Start / Stop

    /// Starts the periodic heartbeat writer.
    /// Writes immediately, then every 30 seconds.
    func start() {
        // Write the first heartbeat immediately
        writeHeartbeat()

        // Schedule periodic writes
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + Self.heartbeatInterval,
                        repeating: Self.heartbeatInterval,
                        leeway: .seconds(1))
        source.setEventHandler { [weak self] in
            self?.writeHeartbeat()
        }
        source.resume()
        timer = source

        NSLog("[Pushling/Heartbeat] Started (PID %d, interval %.0fs)",
              pid, Self.heartbeatInterval)
    }

    /// Stops the heartbeat timer and writes a clean shutdown marker.
    /// Call on app quit.
    func stop() {
        timer?.cancel()
        timer = nil

        writeShutdownMarker()
        NSLog("[Pushling/Heartbeat] Stopped — clean shutdown recorded")
    }

    // MARK: - Private

    /// Writes the heartbeat payload to disk. Must complete in < 1ms.
    private func writeHeartbeat() {
        let now = ISO8601DateFormatter().string(from: Date())
        let payload = HeartbeatPayload(pid: pid,
                                        timestamp: now,
                                        state: "running")

        guard let data = try? encoder.encode(payload) else {
            NSLog("[Pushling/Heartbeat] Failed to encode heartbeat payload")
            return
        }

        do {
            try data.write(to: URL(fileURLWithPath: Self.heartbeatPath),
                           options: .atomic)
        } catch {
            NSLog("[Pushling/Heartbeat] Failed to write heartbeat: %@",
                  "\(error)")
        }
    }

    /// Writes a shutdown marker so the next launch knows we quit cleanly.
    private func writeShutdownMarker() {
        let now = ISO8601DateFormatter().string(from: Date())
        let payload = HeartbeatPayload(pid: pid,
                                        timestamp: now,
                                        state: "shutdown")

        guard let data = try? encoder.encode(payload) else { return }

        try? data.write(to: URL(fileURLWithPath: Self.heartbeatPath),
                        options: .atomic)
    }

    /// Removes the heartbeat file.
    private func cleanup() {
        try? FileManager.default.removeItem(atPath: Self.heartbeatPath)
    }

    /// Checks if a process with the given PID is currently running.
    private func isProcessRunning(pid: Int32) -> Bool {
        // kill(pid, 0) returns 0 if process exists, -1 with ESRCH if not
        return kill(pid, 0) == 0
    }

    /// Records a crash recovery event in the journal table.
    private func logCrashRecovery(previousPID: Int32, lastHeartbeat: String) {
        guard let db = databaseManager, db.isOpen else {
            // Database may not be open yet during early launch.
            // The caller can log this after DB is ready.
            NSLog("[Pushling/Heartbeat] Cannot write crash recovery to journal "
                  + "— database not open yet")
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let dataJSON = """
            {"previous_pid":\(previousPID),\
            "last_heartbeat":"\(lastHeartbeat)",\
            "recovered_at":"\(now)"}
            """

        do {
            try db.execute("""
                INSERT INTO journal (type, summary, timestamp, data)
                VALUES (?, ?, ?, ?);
                """,
                arguments: [
                    "hook",
                    "Crash recovery: previous instance (PID \(previousPID)) "
                        + "did not shut down cleanly",
                    now,
                    dataJSON
                ]
            )
            NSLog("[Pushling/Heartbeat] Crash recovery logged to journal")
        } catch {
            NSLog("[Pushling/Heartbeat] Failed to log crash recovery: %@",
                  "\(error)")
        }
    }
}
