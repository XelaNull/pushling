// SocketServer.swift — Unix domain socket server for Pushling IPC
// Listens on /tmp/pushling.sock, accepts NDJSON connections, dispatches to CommandRouter.
// All I/O runs on a dedicated dispatch queue — never blocks the SpriteKit render thread.

import Foundation

// MARK: - ClientConnection

/// A single connected client with its own line buffer and session state.
final class ClientConnection {
    let id: UUID
    let fileHandle: FileHandle
    var lineBuffer: Data
    var sessionId: String?
    var readSource: DispatchSourceRead?

    init(fileHandle: FileHandle) {
        self.id = UUID()
        self.fileHandle = fileHandle
        self.lineBuffer = Data()
    }
}

// MARK: - SocketServer

/// Listens on a Unix domain socket for NDJSON commands from MCP clients.
/// Dispatches parsed commands to a `CommandRouter` and writes responses.
final class SocketServer {

    static let socketPath = "/tmp/pushling.sock"
    private static let maxMessageSize = 65_536  // 64 KB
    private static let readBufferSize = 8_192

    private let router: CommandRouter
    private let queue = DispatchQueue(label: "com.pushling.socket", qos: .userInitiated)
    private var serverFD: Int32 = -1
    private var isRunning = false
    private var connections: [UUID: ClientConnection] = [:]
    private let connectionsLock = NSLock()
    private var acceptSource: DispatchSourceRead?

    init(router: CommandRouter) {
        self.router = router
        signal(SIGPIPE, SIG_IGN)
    }

    deinit { stop() }

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in self?.startListening() }
    }

    func stop() {
        queue.sync { [weak self] in self?.stopListening() }
    }

    var connectionCount: Int {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        return connections.count
    }

    // MARK: - Server Setup

    private func startListening() {
        guard !isRunning else { return }

        unlink(SocketServer.socketPath)

        serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            NSLog("[Pushling:IPC] Failed to create socket: \(errnoString)")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = SocketServer.socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            sunPathPtr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { ptr in
                for i in 0..<pathBytes.count { ptr[i] = pathBytes[i] }
            }
        }

        let bindOK = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        } == 0

        guard bindOK else {
            NSLog("[Pushling:IPC] Failed to bind: \(errnoString)")
            close(serverFD); serverFD = -1
            return
        }

        guard listen(serverFD, 3) == 0 else {
            NSLog("[Pushling:IPC] Failed to listen: \(errnoString)")
            close(serverFD); serverFD = -1; unlink(SocketServer.socketPath)
            return
        }

        setNonBlocking(serverFD)
        isRunning = true
        NSLog("[Pushling:IPC] Listening on \(SocketServer.socketPath)")

        let source = DispatchSource.makeReadSource(fileDescriptor: serverFD, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.setCancelHandler { [weak self] in
            guard let self = self, self.serverFD >= 0 else { return }
            close(self.serverFD); self.serverFD = -1
        }
        acceptSource = source
        source.resume()
    }

    private func stopListening() {
        guard isRunning else { return }
        isRunning = false
        acceptSource?.cancel()
        acceptSource = nil

        connectionsLock.lock()
        let all = Array(connections.values)
        connections.removeAll()
        connectionsLock.unlock()

        for conn in all { disconnectClient(conn, reason: "server shutdown") }
        unlink(SocketServer.socketPath)
        NSLog("[Pushling:IPC] Server stopped")
    }

    // MARK: - Connection Management

    private func acceptConnection() {
        var clientAddr = sockaddr_un()
        var addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let clientFD = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(serverFD, $0, &addrLen)
            }
        }
        guard clientFD >= 0 else {
            if errno != EAGAIN && errno != EWOULDBLOCK {
                NSLog("[Pushling:IPC] Accept failed: \(errnoString)")
            }
            return
        }

        setNonBlocking(clientFD)
        let conn = ClientConnection(fileHandle: FileHandle(fileDescriptor: clientFD, closeOnDealloc: true))

        connectionsLock.lock()
        connections[conn.id] = conn
        connectionsLock.unlock()

        NSLog("[Pushling:IPC] Client connected: \(conn.id)")

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        source.setEventHandler { [weak self] in self?.handleRead(for: conn) }
        source.setCancelHandler { [weak self] in
            self?.disconnectClient(conn, reason: "read source cancelled")
        }
        conn.readSource = source
        source.resume()
    }

    private func handleRead(for conn: ClientConnection) {
        var buffer = [UInt8](repeating: 0, count: SocketServer.readBufferSize)
        let bytesRead = read(conn.fileHandle.fileDescriptor, &buffer, buffer.count)

        if bytesRead <= 0 {
            if bytesRead == 0 || (errno != EAGAIN && errno != EWOULDBLOCK) {
                conn.readSource?.cancel()
            }
            return
        }

        conn.lineBuffer.append(contentsOf: buffer[0..<bytesRead])

        if conn.lineBuffer.count > SocketServer.maxMessageSize {
            writeJSON(errorDict(id: "__size_error__",
                error: "Message exceeds 64KB limit.", code: "MESSAGE_TOO_LARGE"), to: conn)
            conn.lineBuffer = Data()
            return
        }

        processLines(for: conn)
    }

    private func processLines(for conn: ClientConnection) {
        while let idx = conn.lineBuffer.firstIndex(of: 0x0A) {
            let lineData = conn.lineBuffer[conn.lineBuffer.startIndex..<idx]
            conn.lineBuffer = Data(conn.lineBuffer[(idx + 1)...])
            guard !lineData.isEmpty,
                  let line = String(data: Data(lineData), encoding: .utf8) else { continue }
            processMessage(line, from: conn)
        }
    }

    private func processMessage(_ message: String, from conn: ClientConnection) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            writeJSON(errorDict(id: "__parse_error__",
                error: "Failed to parse request as JSON.", code: "PARSE_ERROR"), to: conn)
            return
        }

        let id = json["id"] as? String ?? "__missing_id__"
        guard let cmd = json["cmd"] as? String else {
            writeJSON(errorDict(id: id,
                error: "Missing 'cmd' field in request.", code: "PARSE_ERROR"), to: conn)
            return
        }

        let sessionCmds: Set<String> = ["connect", "disconnect", "ping"]
        if !sessionCmds.contains(cmd) && conn.sessionId == nil {
            writeJSON(errorDict(id: id,
                error: "No active session. Send a 'connect' command first.",
                code: "SESSION_REQUIRED"), to: conn)
            return
        }

        let request = IPCRequest(
            id: id, cmd: cmd,
            action: json["action"] as? String,
            params: json["params"] as? [String: Any] ?? [:],
            sessionId: conn.sessionId
        )
        let result = router.route(request)

        if cmd == "connect", result.ok, let sid = result.data["session_id"] as? String {
            conn.sessionId = sid
        } else if cmd == "disconnect", result.ok {
            conn.sessionId = nil
        }

        let events = conn.sessionId.map { router.drainEvents(for: $0) } ?? []
        writeJSON(buildResponse(from: result, id: id, events: events), to: conn)
    }

    // MARK: - Disconnect

    private func disconnectClient(_ conn: ClientConnection, reason: String) {
        connectionsLock.lock()
        connections.removeValue(forKey: conn.id)
        connectionsLock.unlock()

        if let sid = conn.sessionId {
            // P4-T4-03: Use handleAbruptDisconnect for socket-level disconnects.
            // This triggers the abrupt disconnect animation (flicker + fast dissolve)
            // rather than the clean farewell.
            if reason == "server shutdown" {
                // Server shutdown is orderly, route as clean disconnect
                let req = IPCRequest(id: UUID().uuidString, cmd: "disconnect",
                    action: nil, params: ["session_id": sid], sessionId: sid)
                _ = router.route(req)
            } else {
                // Socket EOF or error — abrupt disconnect
                router.handleAbruptDisconnect(sessionId: sid)
            }
        }
        NSLog("[Pushling:IPC] Client disconnected: \(conn.id) (\(reason))")
    }

    // MARK: - Response Helpers

    private func buildResponse(
        from result: IPCResult, id: String, events: [[String: Any]]
    ) -> [String: Any] {
        var resp: [String: Any] = ["id": id, "ok": result.ok, "pending_events": events]
        if result.ok {
            resp["data"] = result.data
        } else {
            resp["error"] = result.error ?? "Unknown error"
            resp["code"] = result.code ?? "INTERNAL_ERROR"
        }
        return resp
    }

    private func errorDict(id: String, error: String, code: String) -> [String: Any] {
        ["id": id, "ok": false, "error": error, "code": code, "pending_events": [] as [Any]]
    }

    private func writeJSON(_ dict: [String: Any], to conn: ClientConnection) {
        guard var data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
        else { return }
        data.append(0x0A)  // newline

        let fd = conn.fileHandle.fileDescriptor
        data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            var written = 0
            while written < buf.count {
                let n = write(fd, base + written, buf.count - written)
                if n <= 0 {
                    if errno == EAGAIN || errno == EWOULDBLOCK { usleep(1000); continue }
                    NSLog("[Pushling:IPC] Write failed: \(errnoString)")
                    return
                }
                written += n
            }
        }
    }

    // MARK: - Utilities

    private func setNonBlocking(_ fd: Int32) {
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    }

    private var errnoString: String { String(cString: strerror(errno)) }
}
