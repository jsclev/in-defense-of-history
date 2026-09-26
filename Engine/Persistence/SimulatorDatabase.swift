import Foundation
import SQLite3

/// Creates an independent content snapshot with empty, SQL-defined result tables.
/// Never writes to the source database or replaces an existing destination.
public enum SimulatorDatabase {
    private static let history: Set<String> = ["simulator_run", "sweep_row", "money_study",
        "money_study_result", "level_run", "level_action", "genetic_solution",
        "simulator_invocation", "simulator_map", "simulator_document"]

    public static func starter(beside executable: URL, buildName: String) -> URL {
        executable.deletingLastPathComponent().appendingPathComponent("liberty-line-simulator-\(buildName).sqlite")
    }

    public static func destination(beside executable: URL, buildName: String, id: UUID = UUID(), date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return executable.deletingLastPathComponent().appendingPathComponent(
            "liberty-line-simulator-\(buildName)-run-\(formatter.string(from: date))-\(id.uuidString).sqlite")
    }

    public static func create(source: Db, destination: URL, arguments: [String],
                              schema: URL? = nil) throws -> Db {
        // Exclusive creation also prevents two coordinators from sharing a run.
        try Data().write(to: destination, options: .withoutOverwriting)
        var connection: OpaquePointer?
        var complete = false
        defer {
            if let connection { sqlite3_close(connection) }
            if !complete { try? FileManager.default.removeItem(at: destination) }
        }
        guard sqlite3_open_v2(destination.path, &connection,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let target = connection else { throw DbError.Db(message: "Cannot open new simulator database \(destination.path)") }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(target, sql, nil, nil, nil) == SQLITE_OK else {
                throw DbError.Db(message: "simulator snapshot: \(String(cString: sqlite3_errmsg(target)))")
            }
        }
        func identifier(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        try execute("PRAGMA foreign_keys=OFF; PRAGMA journal_mode=DELETE;")
        if source.path == ":memory:" {
            guard let backup = sqlite3_backup_init(target, "main", source.conn, "main") else {
                throw DbError.Db(message: "simulator snapshot: cannot copy in-memory content")
            }
            let step = sqlite3_backup_step(backup, -1), finish = sqlite3_backup_finish(backup)
            guard step == SQLITE_DONE, finish == SQLITE_OK else {
                throw DbError.Db(message: "simulator snapshot: in-memory copy failed")
            }
            try execute("BEGIN")
            // Use the source schema, even when its simulator extension is absent.
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(target, "SELECT name FROM sqlite_master WHERE type='table'", -1, &stmt, nil) == SQLITE_OK else {
                throw DbError.Db(message: "simulator snapshot: missing schema")
            }
            var tables: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW { tables.append(String(cString: sqlite3_column_text(stmt, 0))) }
            sqlite3_finalize(stmt)
            for name in tables where history.contains(name) { try execute("DELETE FROM \(identifier(name))") }
        } else {
            var attach: OpaquePointer?
            guard sqlite3_prepare_v2(target, "ATTACH DATABASE ? AS authored", -1, &attach, nil) == SQLITE_OK else {
                throw DbError.Db(message: "simulator snapshot: cannot attach source")
            }
            let uri = URL(fileURLWithPath: source.path).absoluteString + "?mode=ro"
            sqlite3_bind_text(attach, 1, uri, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            let status = sqlite3_step(attach)
            sqlite3_finalize(attach)
            guard status == SQLITE_DONE else { throw DbError.Db(message: "simulator snapshot: cannot read \(source.path)") }
            try execute("BEGIN")
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(target, "SELECT type,name,sql FROM authored.sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END", -1, &stmt, nil) == SQLITE_OK else {
                throw DbError.Db(message: "simulator snapshot: missing source schema")
            }
            var definitions: [(String, String, String)] = []
            var statusRow = sqlite3_step(stmt)
            while statusRow == SQLITE_ROW {
                definitions.append((String(cString: sqlite3_column_text(stmt, 0)),
                    String(cString: sqlite3_column_text(stmt, 1)), String(cString: sqlite3_column_text(stmt, 2))))
                statusRow = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            guard statusRow == SQLITE_DONE, !definitions.isEmpty else { throw DbError.Db(message: "simulator snapshot: empty or unreadable source schema") }
            for (_, _, sql) in definitions { try execute(sql) }
            for (type, name, _) in definitions where type == "table" && !history.contains(name) {
                let table = identifier(name)
                try execute("INSERT INTO main.\(table) SELECT * FROM authored.\(table)")
            }
        }
        // Only starter creation supplies the authored schema file. Normal runs
        // copy it from the installed database, with no checkout file access.
        if let schema { try execute(String(contentsOf: schema, encoding: .utf8)) }
        let dao = SimulatorInvocationDAO(conn: target)
        try dao.begin(id: UUID(), source: source.path, arguments: arguments)
        // Enumerate the captured database, then store the exact authored map bytes.
        var maps: OpaquePointer?
        // Future, unauthored levels explicitly have an empty map name. They
        // remain in the content snapshot, but have no map bytes to capture.
        guard sqlite3_prepare_v2(target, "SELECT DISTINCT map_image_name FROM level_info WHERE map_image_name <> '' OR map_image_name IS NULL", -1, &maps, nil) == SQLITE_OK else {
            throw DbError.Db(message: "simulator snapshot: missing level_info.map_image_name")
        }
        var names: [String] = []
        var status = sqlite3_step(maps)
        while status == SQLITE_ROW {
            guard let bytes = sqlite3_column_text(maps, 0) else {
                sqlite3_finalize(maps)
                throw DbError.Db(message: "level_info.map_image_name is NULL")
            }
            names.append(String(cString: bytes)); status = sqlite3_step(maps)
        }
        sqlite3_finalize(maps)
        guard status == SQLITE_DONE, !names.isEmpty else { throw DbError.Db(message: "simulator snapshot: no authored maps") }
        for name in names {
            guard !name.isEmpty else { throw DbError.Db(message: "level_info.map_image_name is empty") }
            try dao.saveMap(source.levelGeoJSONDao.sourceData(mapImageName: name), name: name)
        }
        try execute("COMMIT")
        if source.path != ":memory:" { try execute("DETACH DATABASE authored") }
        let result = try open(destination)
        complete = true
        return result
    }

    public static func open(_ url: URL, readOnly: Bool = false) throws -> Db {
        var conn: OpaquePointer?
        guard sqlite3_open_v2(url.path, &conn, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let conn { sqlite3_close(conn) }
            throw DbError.Db(message: "Cannot read simulator database \(url.path)")
        }
        defer { sqlite3_close(conn) }
        let dao = SimulatorInvocationDAO(conn: conn)
        try dao.validate()
        return Db(dbPath: url.path, fullRefresh: false,
                  levelGeoJSONDao: LevelGeoJSONDAO(documents: try dao.maps()), readOnly: readOnly)
    }
}
