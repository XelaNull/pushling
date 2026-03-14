// IPCTypes.swift — Shared types for Pushling IPC protocol
// Used by SocketServer, CommandRouter, and EventBuffer.

import Foundation

/// A parsed IPC request ready for routing.
struct IPCRequest {
    let id: String
    let cmd: String
    let action: String?
    let params: [String: Any]
    let sessionId: String?
}

/// The result of routing a command, before pending events are attached.
struct IPCResult {
    let ok: Bool
    let data: [String: Any]
    let error: String?
    let code: String?

    static func success(_ data: [String: Any]) -> IPCResult {
        IPCResult(ok: true, data: data, error: nil, code: nil)
    }

    static func failure(error: String, code: String) -> IPCResult {
        IPCResult(ok: false, data: [:], error: error, code: code)
    }
}
