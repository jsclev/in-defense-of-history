import Foundation
import SQLite3

/// Captured inputs and JSON checkpoints for one standalone simulator database.
/// Tables are authored in Db/DDL/create_simulator_invocation.sql.
public final class SimulatorInvocationDAO {
    private let conn: OpaquePointer?
    init(conn: OpaquePointer?) { self.conn = conn }

    private func statement<T>(_ sql: String, _ values: [String] = [],
                              _ body: (OpaquePointer) throws -> T) throws -> T {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw error() }
        defer { sqlite3_finalize(stmt) }
        for (index, value) in values.enumerated() {
            guard sqlite3_bind_text(stmt, Int32(index + 1), value, -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)) == SQLITE_OK else { throw error() }
        }
        return try body(stmt)
    }
    private func error() -> DbError { .Db(message: "simulator invocation: \(String(cString: sqlite3_errmsg(conn)))") }

    func begin(id: UUID, source: String, arguments: [String]) throws {
        try statement("INSERT INTO simulator_invocation VALUES(1,1,?,?,?,?)",
                      [id.uuidString, ISO8601DateFormatter().string(from: Date()), source,
                       String(decoding: try JSONEncoder().encode(arguments), as: UTF8.self)]) {
            guard sqlite3_step($0) == SQLITE_DONE else { throw error() }
        }
    }

    public func validate() throws {
        try statement("SELECT schema_version FROM simulator_invocation WHERE singleton=1") {
            guard sqlite3_step($0) == SQLITE_ROW, sqlite3_column_int($0, 0) == 1,
                  sqlite3_step($0) == SQLITE_DONE else {
                throw DbError.Db(message: "simulator_invocation: missing or unsupported invocation record")
            }
        }
    }

    public func isInvocation() throws -> Bool {
        try statement("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='simulator_invocation'") {
            guard sqlite3_step($0) == SQLITE_ROW else { throw error() }
            return sqlite3_column_int($0, 0) == 1
        }
    }

    func saveMap(_ data: Data, name: String) throws {
        _ = try JSONSerialization.jsonObject(with: data)
        try statement("INSERT INTO simulator_map(map_image_name,geojson) VALUES(?,?)",
                      [name, String(decoding: data, as: UTF8.self)]) {
            guard sqlite3_step($0) == SQLITE_DONE else { throw error() }
        }
    }

    public func maps() throws -> [String: Data] {
        try statement("SELECT l.map_image_name,m.geojson FROM level_info l LEFT JOIN simulator_map m ON m.map_image_name=l.map_image_name WHERE l.map_image_name <> '' OR l.map_image_name IS NULL") { stmt in
            var maps: [String: Data] = [:]
            var status = sqlite3_step(stmt)
            while status == SQLITE_ROW {
                guard let nameBytes = sqlite3_column_text(stmt, 0) else {
                    throw DbError.Db(message: "level_info.map_image_name is NULL")
                }
                let name = String(cString: nameBytes)
                guard !name.isEmpty, let json = sqlite3_column_text(stmt, 1) else {
                    throw DbError.Db(message: "simulator_map[\(name)].geojson is missing")
                }
                let data = Data(String(cString: json).utf8)
                _ = try JSONSerialization.jsonObject(with: data)
                maps[name] = data
                status = sqlite3_step(stmt)
            }
            guard status == SQLITE_DONE, !maps.isEmpty else { throw error() }
            return maps
        }
    }

    public func saveDocument(_ data: Data, name: String) throws {
        guard !name.isEmpty else { throw DbError.Db(message: "simulator_document.name is empty") }
        _ = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        try statement("INSERT INTO simulator_document(name,content_json) VALUES(?,?) ON CONFLICT(name) DO UPDATE SET content_json=excluded.content_json",
                      [name, String(decoding: data, as: UTF8.self)]) {
            guard sqlite3_step($0) == SQLITE_DONE else { throw error() }
        }
    }

    public func document(named name: String) throws -> Data {
        try statement("SELECT content_json FROM simulator_document WHERE name=?", [name]) {
            guard sqlite3_step($0) == SQLITE_ROW, let bytes = sqlite3_column_text($0, 0) else {
                throw DbError.Db(message: "simulator_document[\(name)].content_json is missing")
            }
            return Data(String(cString: bytes).utf8)
        }
    }
}
