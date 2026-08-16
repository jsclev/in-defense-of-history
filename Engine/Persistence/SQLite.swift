import Foundation

#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum SQLiteValue: Sendable {
    case int(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null

    public static func integer(_ v: Int) -> SQLiteValue { .int(Int64(v)) }
}

public struct SQLiteRow {
    let stmt: OpaquePointer

    public func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
    public func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }

    public func text(_ i: Int32) -> String {
        guard let c = sqlite3_column_text(stmt, i) else { return "" }
        return String(cString: c)
    }

    public func blob(_ i: Int32) -> Data {
        let count = Int(sqlite3_column_bytes(stmt, i))
        guard count > 0, let base = sqlite3_column_blob(stmt, i) else { return Data() }
        return Data(bytes: base, count: count)
    }

    public func isNull(_ i: Int32) -> Bool {
        sqlite3_column_type(stmt, i) == SQLITE_NULL
    }
}

public final class SQLiteDatabase {
    private var handle: OpaquePointer?
    private var statementCache: [String: OpaquePointer] = [:]

    public let path: String

    public init(path: String) throws {
        self.path = path
        var h: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let rc = sqlite3_open_v2(path, &h, flags, nil)
        guard rc == SQLITE_OK, let opened = h else {
            if let h { sqlite3_close_v2(h) }
            throw SQLiteError.OpenDatabase(message: "Unable to open db")
        }
        handle = opened
        try tunePragmas()
    }

    deinit {
        for (_, stmt) in statementCache {
            sqlite3_finalize(stmt)
        }
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    private func tunePragmas() throws {
        try query("PRAGMA journal_mode=WAL;") { _ in }
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")
        try exec("PRAGMA temp_store=MEMORY;")
    }

    private func requireHandle() throws -> OpaquePointer {
        guard let handle else {
            throw SQLiteError.OpenDatabase(message: "database closed")
        }
        return handle
    }

    private func lastError(_ context: String) -> SQLiteError {
        let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
        
        return SQLiteError.Bind(message: msg)
    }

    public func exec(_ sql: String) throws {
        let h = try requireHandle()
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(h, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw SQLiteError.Prepare(message: msg)
        }
    }

    private func prepared(_ sql: String) throws -> OpaquePointer {
        if let cached = statementCache[sql] {
            sqlite3_reset(cached)
            sqlite3_clear_bindings(cached)
            return cached
        }
        let h = try requireHandle()
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(h, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let prepared = stmt else {
            throw lastError("prepare: \(sql)")
        }
        statementCache[sql] = prepared
        return prepared
    }

    private func bind(_ values: [SQLiteValue], to stmt: OpaquePointer) throws {
        for (i, value) in values.enumerated() {
            let idx = Int32(i + 1)
            let rc: Int32
            switch value {
            case .int(let v):
                rc = sqlite3_bind_int64(stmt, idx, v)
            case .real(let v):
                rc = sqlite3_bind_double(stmt, idx, v)
            case .text(let v):
                rc = sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case .blob(let data):
                if data.isEmpty {
                    rc = sqlite3_bind_zeroblob(stmt, idx, 0)
                } else {
                    rc = data.withUnsafeBytes { raw in
                        sqlite3_bind_blob(stmt, idx, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
                    }
                }
            case .null:
                rc = sqlite3_bind_null(stmt, idx)
            }
            if rc != SQLITE_OK {
                throw lastError("bind #\(idx)")
            }
        }
    }

    public func run(_ sql: String, _ binds: [SQLiteValue] = []) throws {
        let stmt = try prepared(sql)
        try bind(binds, to: stmt)
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
            throw lastError("step: \(sql)")
        }
    }

    public func query(
        _ sql: String,
        _ binds: [SQLiteValue] = [],
        row: (SQLiteRow) throws -> Void
    ) throws {
        let stmt = try prepared(sql)
        try bind(binds, to: stmt)
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                try row(SQLiteRow(stmt: stmt))
            } else if rc == SQLITE_DONE {
                break
            } else {
                throw lastError("step: \(sql)")
            }
        }
    }

    public func scalarInt(_ sql: String, _ binds: [SQLiteValue] = []) throws -> Int64? {
        var result: Int64? = nil
        try query(sql, binds) { r in
            if result == nil { result = r.isNull(0) ? nil : r.int(0) }
        }
        return result
    }

    public var lastInsertRowID: Int64 {
        handle.map { sqlite3_last_insert_rowid($0) } ?? 0
    }

    public var changes: Int {
        handle.map { Int(sqlite3_changes($0)) } ?? 0
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE;")
        do {
            let value = try body()
            try exec("COMMIT;")
            return value
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }
}
