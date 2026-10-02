import Foundation
import SQLite3

/// Small typed SQLite adapter shared by the GA DAOs. Prepared statements are
/// reused across a batch; no serialization or DDL occurs on the write path.
final class GeneticSQL {
    let conn: OpaquePointer
    private var statements: [String: OpaquePointer] = [:]
    init(_ connection: OpaquePointer?) throws {
        guard let connection else { throw DbError.Db(message: "GA database is closed") }
        conn = connection
    }
    deinit { for statement in statements.values { sqlite3_finalize(statement) } }
    func error(_ detail: String) -> DbError { .Db(message: "GA \(detail): \(String(cString: sqlite3_errmsg(conn)))") }
    func statement(_ sql: String, _ values: [Any?]) throws -> OpaquePointer {
        let stmt: OpaquePointer
        if let cached = statements[sql] { stmt = cached }
        else {
            var prepared: OpaquePointer?
            guard sqlite3_prepare_v2(conn, sql, -1, &prepared, nil) == SQLITE_OK, let prepared else { throw error(sql) }
            statements[sql] = prepared; stmt = prepared
        }
        sqlite3_reset(stmt); sqlite3_clear_bindings(stmt)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1), status: Int32
            switch value {
            case nil: status = sqlite3_bind_null(stmt, index)
            case let value as String: status = sqlite3_bind_text(stmt, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let value as UUID: status = sqlite3_bind_text(stmt, index, value.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let value as Bool: status = sqlite3_bind_int(stmt, index, value ? 1 : 0)
            case let value as Int: status = sqlite3_bind_int64(stmt, index, Int64(value))
            case let value as Int64: status = sqlite3_bind_int64(stmt, index, value)
            case let value as Double:
                guard value.isFinite else { throw error("non-finite value in \(sql)") }
                status = sqlite3_bind_double(stmt, index, value)
            default: throw error("unsupported value in \(sql)")
            }
            guard status == SQLITE_OK else { throw error(sql) }
        }
        return stmt
    }
    func execute(_ sql: String, _ values: [Any?] = []) throws {
        let stmt = try statement(sql, values)
        defer { sqlite3_reset(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(sql) }
    }
    func rows(_ sql: String, _ values: [Any?] = []) throws -> [Row] {
        let stmt = try statement(sql, values)
        defer { sqlite3_reset(stmt) }
        var result: [Row] = []
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            var fields: [String: Value] = [:]
            for i in 0..<sqlite3_column_count(stmt) {
                let key = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_NULL: fields[key] = .null
                case SQLITE_INTEGER: fields[key] = .integer(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT: fields[key] = .real(sqlite3_column_double(stmt, i))
                case SQLITE_TEXT: fields[key] = .text(String(cString: sqlite3_column_text(stmt, i)))
                default: throw error("unexpected BLOB in \(sql).\(key)")
                }
            }
            result.append(Row(fields: fields, source: sql)); code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw error(sql) }
        return result
    }
    func one(_ sql: String, _ values: [Any?] = []) throws -> Row {
        let found = try rows(sql, values)
        guard found.count == 1 else { throw error("expected one record, found \(found.count): \(sql)") }
        return found[0]
    }
    func insert(_ table: String, _ columns: String, _ values: [Any?]) throws {
        try execute("INSERT INTO \(table)(\(columns)) VALUES(\(Array(repeating: "?", count: values.count).joined(separator: ",")))", values)
    }
    var lastID: Int64 { sqlite3_last_insert_rowid(conn) }
    var changes: Int { Int(sqlite3_changes(conn)) }
    func transaction<T>(_ body: () throws -> T) throws -> T {
        // SAVEPOINT composes safely with the catalog's outer transaction.
        try execute("SAVEPOINT ga_write")
        do {
            let value = try body(); try execute("RELEASE ga_write"); return value
        } catch {
            try? execute("ROLLBACK TO ga_write"); try? execute("RELEASE ga_write"); throw error
        }
    }
    enum Value { case null, integer(Int64), real(Double), text(String) }
    struct Row {
        let fields: [String: Value]
        let source: String
        func invalid(_ key: String) -> DbError { .Db(message: "GA record: missing or invalid \(key) in \(source)") }
        func isNull(_ key: String) throws -> Bool {
            guard let value = fields[key] else { throw invalid(key) }
            if case .null = value { return true }; return false
        }
        func string(_ key: String) throws -> String {
            guard case let .text(value) = fields[key] else { throw invalid(key) }; return value
        }
        func int64(_ key: String) throws -> Int64 {
            guard case let .integer(value) = fields[key] else { throw invalid(key) }; return value
        }
        func int(_ key: String) throws -> Int { Int(try int64(key)) }
        func double(_ key: String) throws -> Double {
            let value: Double
            switch fields[key] {
            case let .real(v): value = v
            case let .integer(v): value = Double(v)
            default: throw invalid(key)
            }
            guard value.isFinite else { throw invalid(key) }; return value
        }
        func bool(_ key: String) throws -> Bool {
            let value = try int(key); guard value == 0 || value == 1 else { throw invalid(key) }; return value == 1
        }
        func uuid(_ key: String) throws -> UUID {
            guard let value = UUID(uuidString: try string(key)) else { throw invalid(key) }; return value
        }
        func seed(_ key: String) throws -> UInt64 {
            guard let value = UInt64(try string(key)) else { throw invalid(key) }; return value
        }
    }
}
