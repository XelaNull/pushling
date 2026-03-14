// DatabaseManager.swift — Pushling SQLite database manager
// Singleton that owns the SQLite connection with WAL mode.
// The daemon is the ONLY writer. MCP server reads via separate connection.

import Foundation
import SQLite3

// MARK: - Database Error

enum DatabaseError: Error, CustomStringConvertible {
    case openFailed(path: String, code: Int32, message: String)
    case pragmaFailed(pragma: String, message: String)
    case executionFailed(sql: String, code: Int32, message: String)
    case prepareFailed(sql: String, code: Int32, message: String)
    case migrationFailed(version: Int, message: String)
    case directoryCreationFailed(path: String, underlying: Error)
    case databaseTooNew(dbVersion: Int, appVersion: Int)

    var description: String {
        switch self {
        case .openFailed(let path, let code, let msg):
            return "Failed to open database at \(path) (code \(code)): \(msg)"
        case .pragmaFailed(let pragma, let msg):
            return "PRAGMA \(pragma) failed: \(msg)"
        case .executionFailed(let sql, let code, let msg):
            return "SQL execution failed (code \(code)): \(msg)\nSQL: \(sql)"
        case .prepareFailed(let sql, let code, let msg):
            return "SQL prepare failed (code \(code)): \(msg)\nSQL: \(sql)"
        case .migrationFailed(let version, let msg):
            return "Migration to v\(version) failed: \(msg)"
        case .directoryCreationFailed(let path, let err):
            return "Failed to create directory \(path): \(err)"
        case .databaseTooNew(let dbVer, let appVer):
            return "Database schema v\(dbVer) is newer than app schema v\(appVer). "
                + "Upgrade the app or restore from backup."
        }
    }
}

// MARK: - DatabaseManager

final class DatabaseManager {

    /// Singleton instance — opened on first access.
    static let shared = DatabaseManager()

    /// The raw SQLite3 connection pointer.
    private var db: OpaquePointer?

    /// Serial queue for all write operations. Reads can happen concurrently
    /// via WAL mode from external processes (MCP server).
    private let writeQueue = DispatchQueue(label: "com.pushling.db.write",
                                           qos: .userInitiated)

    /// Whether the database is currently open.
    private(set) var isOpen = false

    /// The resolved database file path.
    private(set) var databasePath: String = ""

    // MARK: - Lifecycle

    private init() {}

    deinit {
        close()
    }

    /// Opens the database, enables WAL mode, and runs migrations.
    /// Call this once at app launch.
    ///
    /// - Parameter customPath: Override the default path (for testing).
    /// - Throws: `DatabaseError` if open, pragma, or migration fails.
    func open(at customPath: String? = nil) throws {
        let path = customPath ?? Self.defaultDatabasePath()
        databasePath = path

        // Ensure parent directory exists
        let directory = (path as NSString).deletingLastPathComponent
        try createDirectoryIfNeeded(directory)

        // Open SQLite connection
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &dbPointer, flags, nil)

        guard result == SQLITE_OK, let connection = dbPointer else {
            let msg = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(dbPointer)
            throw DatabaseError.openFailed(path: path, code: result, message: msg)
        }

        db = connection
        isOpen = true

        NSLog("[Pushling/DB] Opened database at: %@", path)

        // Configure pragmas for WAL mode and safety
        try configurePragmas()

        // Run migrations
        try MigrationManager.runMigrations(on: self)

        NSLog("[Pushling/DB] Database ready (schema v%d)", Schema.currentVersion)
    }

    /// Closes the database connection. Call on app quit.
    func close() {
        guard isOpen, let connection = db else { return }

        // Checkpoint WAL before closing for a clean state
        sqlite3_wal_checkpoint_v2(connection, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil)

        sqlite3_close_v2(connection)
        db = nil
        isOpen = false
        NSLog("[Pushling/DB] Database closed")
    }

    // MARK: - Default Path

    /// Default database path: ~/.local/share/pushling/state.db
    static func defaultDatabasePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.local/share/pushling/state.db"
    }

    // MARK: - SQL Execution (Internal API)

    /// Executes a SQL statement with no result rows (CREATE, INSERT, UPDATE, DELETE).
    /// Thread-safe via the write queue.
    ///
    /// - Parameters:
    ///   - sql: The SQL statement to execute.
    ///   - arguments: Optional bind parameters (String, Int, Double, nil supported).
    /// - Throws: `DatabaseError.executionFailed` on failure.
    func execute(_ sql: String, arguments: [Any?] = []) throws {
        guard let connection = db else {
            throw DatabaseError.executionFailed(sql: sql, code: -1,
                                                 message: "Database not open")
        }

        var stmt: OpaquePointer?
        var rc = sqlite3_prepare_v2(connection, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.prepareFailed(sql: sql, code: rc, message: msg)
        }
        defer { sqlite3_finalize(statement) }

        // Bind arguments
        try bindArguments(arguments, to: statement, sql: sql)

        rc = sqlite3_step(statement)
        guard rc == SQLITE_DONE else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.executionFailed(sql: sql, code: rc, message: msg)
        }
    }

    /// Executes a raw SQL string that may contain multiple statements.
    /// Used for schema DDL. No parameter binding.
    func executeRaw(_ sql: String) throws {
        guard let connection = db else {
            throw DatabaseError.executionFailed(sql: sql, code: -1,
                                                 message: "Database not open")
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(connection, sql, nil, nil, &errorMessage)

        if rc != SQLITE_OK {
            let msg = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.executionFailed(sql: sql, code: rc, message: msg)
        }
    }

    /// Queries the database and returns rows as dictionaries.
    /// Suitable for small result sets. For large queries, use `query(sql:arguments:handler:)`.
    ///
    /// - Parameters:
    ///   - sql: The SELECT statement.
    ///   - arguments: Optional bind parameters.
    /// - Returns: Array of `[String: Any]` dictionaries, one per row.
    func query(_ sql: String, arguments: [Any?] = []) throws -> [[String: Any]] {
        guard let connection = db else {
            throw DatabaseError.executionFailed(sql: sql, code: -1,
                                                 message: "Database not open")
        }

        var stmt: OpaquePointer?
        var rc = sqlite3_prepare_v2(connection, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.prepareFailed(sql: sql, code: rc, message: msg)
        }
        defer { sqlite3_finalize(statement) }

        try bindArguments(arguments, to: statement, sql: sql)

        var rows: [[String: Any]] = []
        let columnCount = sqlite3_column_count(statement)

        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(statement, i))
                row[name] = columnValue(statement: statement, index: i)
            }
            rows.append(row)
        }

        return rows
    }

    /// Queries a single integer value (e.g., for PRAGMA or COUNT queries).
    func queryScalarInt(_ sql: String, arguments: [Any?] = []) throws -> Int? {
        guard let connection = db else {
            throw DatabaseError.executionFailed(sql: sql, code: -1,
                                                 message: "Database not open")
        }

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(connection, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.prepareFailed(sql: sql, code: rc, message: msg)
        }
        defer { sqlite3_finalize(statement) }

        try bindArguments(arguments, to: statement, sql: sql)

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int64(statement, 0))
        }
        return nil
    }

    /// Queries a single text value.
    func queryScalarText(_ sql: String, arguments: [Any?] = []) throws -> String? {
        guard let connection = db else {
            throw DatabaseError.executionFailed(sql: sql, code: -1,
                                                 message: "Database not open")
        }

        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(connection, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let statement = stmt else {
            let msg = String(cString: sqlite3_errmsg(connection))
            throw DatabaseError.prepareFailed(sql: sql, code: rc, message: msg)
        }
        defer { sqlite3_finalize(statement) }

        try bindArguments(arguments, to: statement, sql: sql)

        if sqlite3_step(statement) == SQLITE_ROW {
            if sqlite3_column_type(statement, 0) != SQLITE_NULL {
                return String(cString: sqlite3_column_text(statement, 0))
            }
        }
        return nil
    }

    // MARK: - Transaction Support

    /// Executes a block within a SQLite transaction.
    /// Rolls back on error, commits on success.
    func inTransaction(_ block: () throws -> Void) throws {
        try executeRaw("BEGIN TRANSACTION;")
        do {
            try block()
            try executeRaw("COMMIT;")
        } catch {
            try? executeRaw("ROLLBACK;")
            throw error
        }
    }

    /// Synchronously dispatches a write operation on the serial write queue.
    /// Use this to ensure thread-safe writes from any thread.
    func performWrite(_ block: @escaping () throws -> Void) throws {
        var writeError: Error?
        writeQueue.sync {
            do {
                try block()
            } catch {
                writeError = error
            }
        }
        if let error = writeError {
            throw error
        }
    }

    /// Asynchronously dispatches a write operation on the serial write queue.
    func performWriteAsync(_ block: @escaping () throws -> Void,
                           completion: ((Error?) -> Void)? = nil) {
        writeQueue.async {
            do {
                try block()
                completion?(nil)
            } catch {
                NSLog("[Pushling/DB] Async write error: %@", "\(error)")
                completion?(error)
            }
        }
    }

    // MARK: - Backup Support

    /// The raw SQLite connection for use by BackupManager's VACUUM INTO.
    /// Only call from the backup queue.
    var rawConnection: OpaquePointer? { db }

    // MARK: - Private Helpers

    private func configurePragmas() throws {
        let pragmas: [(String, String)] = [
            ("journal_mode", "WAL"),
            ("synchronous", "NORMAL"),
            ("foreign_keys", "ON"),
            ("busy_timeout", "5000")
        ]

        for (pragma, expected) in pragmas {
            if pragma == "journal_mode" {
                // journal_mode returns the mode as a result
                let result = try queryScalarText("PRAGMA journal_mode=WAL;")
                guard result?.lowercased() == "wal" else {
                    throw DatabaseError.pragmaFailed(
                        pragma: pragma,
                        message: "Expected WAL, got \(result ?? "nil")"
                    )
                }
                NSLog("[Pushling/DB] PRAGMA journal_mode = WAL")
            } else {
                try executeRaw("PRAGMA \(pragma)=\(expected);")
                NSLog("[Pushling/DB] PRAGMA %@ = %@", pragma, expected)
            }
        }
    }

    private func createDirectoryIfNeeded(_ path: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            do {
                try fm.createDirectory(atPath: path,
                                       withIntermediateDirectories: true,
                                       attributes: nil)
                NSLog("[Pushling/DB] Created directory: %@", path)
            } catch {
                throw DatabaseError.directoryCreationFailed(path: path,
                                                             underlying: error)
            }
        }
    }

    private func bindArguments(_ arguments: [Any?],
                               to statement: OpaquePointer,
                               sql: String) throws {
        for (index, arg) in arguments.enumerated() {
            let position = Int32(index + 1)
            let rc: Int32

            switch arg {
            case nil:
                rc = sqlite3_bind_null(statement, position)
            case let intVal as Int:
                rc = sqlite3_bind_int64(statement, position, Int64(intVal))
            case let int64Val as Int64:
                rc = sqlite3_bind_int64(statement, position, int64Val)
            case let doubleVal as Double:
                rc = sqlite3_bind_double(statement, position, doubleVal)
            case let stringVal as String:
                rc = sqlite3_bind_text(statement, position,
                                       (stringVal as NSString).utf8String, -1,
                                       unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let boolVal as Bool:
                rc = sqlite3_bind_int(statement, position, boolVal ? 1 : 0)
            default:
                let stringVal = "\(arg!)"
                rc = sqlite3_bind_text(statement, position,
                                       (stringVal as NSString).utf8String, -1,
                                       unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }

            guard rc == SQLITE_OK else {
                let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
                throw DatabaseError.executionFailed(
                    sql: sql, code: rc,
                    message: "Bind failed at position \(position): \(msg)"
                )
            }
        }
    }

    private func columnValue(statement: OpaquePointer, index: Int32) -> Any {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            return Int(sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement, index)
        case SQLITE_TEXT:
            return String(cString: sqlite3_column_text(statement, index))
        case SQLITE_BLOB:
            let bytes = sqlite3_column_bytes(statement, index)
            if let blob = sqlite3_column_blob(statement, index) {
                return Data(bytes: blob, count: Int(bytes))
            }
            return Data()
        case SQLITE_NULL:
            return NSNull()
        default:
            return NSNull()
        }
    }
}
