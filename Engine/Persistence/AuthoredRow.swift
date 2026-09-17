import Foundation
import SQLite3

struct AuthoredRow {
    let statement: OpaquePointer
    let entity: String

    func invalid(_ field: String, _ reason: String) -> DbError {
        DbError.Db(message: "\(entity): attribute '\(field)' \(reason)")
    }

    private func column(_ field: String) throws -> Int32 {
        for index in 0..<sqlite3_column_count(statement) {
            if String(cString: sqlite3_column_name(statement, index)) == field { return index }
        }
        throw invalid(field, "is missing")
    }

    func text(_ field: String) throws -> String {
        let index = try column(field)
        guard sqlite3_column_type(statement, index) == SQLITE_TEXT,
              let pointer = sqlite3_column_text(statement, index) else {
            throw invalid(field, "must contain text")
        }
        let value = String(cString: pointer)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalid(field, "is empty")
        }
        return value
    }

    func integer(_ field: String, minimum: Int) throws -> Int {
        let index = try column(field)
        guard sqlite3_column_type(statement, index) == SQLITE_INTEGER,
              let value = Int(exactly: sqlite3_column_int64(statement, index)), value >= minimum else {
            throw invalid(field, "must be an integer >= \(minimum)")
        }
        return value
    }

    func flag(_ field: String) throws -> Bool {
        let value = try integer(field, minimum: 0)
        guard value <= 1 else { throw invalid(field, "must be 0 or 1") }
        return value == 1
    }

    func number(_ field: String, minimum: Double, strictlyGreater: Bool = false,
                maximum: Double? = nil) throws -> Double {
        let index = try column(field)
        let type = sqlite3_column_type(statement, index)
        guard type == SQLITE_FLOAT || type == SQLITE_INTEGER else {
            throw invalid(field, "must contain a number")
        }
        let value = sqlite3_column_double(statement, index)
        guard value.isFinite, strictlyGreater ? value > minimum : value >= minimum,
              maximum.map({ value <= $0 }) ?? true else {
            throw invalid(field, "is outside its valid range")
        }
        return value
    }

    func requireNull(_ field: String) throws {
        guard sqlite3_column_type(statement, try column(field)) == SQLITE_NULL else {
            throw invalid(field, "must be NULL when its capability is disabled")
        }
    }

    func uuid(_ field: String) throws -> UUID {
        guard let value = UUID(uuidString: try text(field)) else {
            throw invalid(field, "must contain a UUID")
        }
        return value
    }
}

extension BaseDAO {
    func authoredRows<T>(_ sql: String, entity: String,
                         read: (AuthoredRow) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        try prepare(conn: conn, stmt: &statement, sql: sql)
        guard let statement else { throw DbError.Db(message: "\(entity): unable to read authored data") }
        defer { sqlite3_finalize(statement) }
        var result: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                result.append(try read(AuthoredRow(statement: statement, entity: entity)))
            case SQLITE_DONE:
                return result
            default:
                throw DbError.Db(message: "\(entity): \(String(cString: sqlite3_errmsg(conn)))")
            }
        }
    }
}
