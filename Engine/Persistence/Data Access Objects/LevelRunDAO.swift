import Foundation
import SQLite3

public enum LevelRunSource: String, Codable { case player, simulator, editor }
public enum LevelRunStatus: String, Codable {
    case running, victory, defeat, timeout, abandoned, failed
}

public struct LevelRunRecord {
    public let id: UUID
    public let levelID: UUID
    public let source: LevelRunSource
    public let playSpeed: PlaySpeed
    public let status: LevelRunStatus
    public let lastSequence: Int64
    public let lastTick: Int64
    public let resultJSON: String?
    let setup: Data
}

public struct LevelActionRecord {
    public let runID: UUID
    public let sequence: Int64
    public let tick: Int64
    public let category: String
    public let name: String
    public let payloadJSON: String
    let presentation: Data?
}

struct PendingLevelAction {
    let tick: Int64
    let category: String
    let name: String
    let payload: String
    var presentation: Data? = nil
}

/// Only persistence lives here. No validation of purchases, combat or movement.
/// Each append commits all events and their resolved presentation atomically.
public final class LevelRunDAO {
    private var conn: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    init(conn: OpaquePointer?) { self.conn = conn }
    func close() { conn = nil }

    private func fail(_ message: String) -> DbError {
        DbError.Db(message: "level_run: \(message); \(conn.map { String(cString: sqlite3_errmsg($0)) } ?? "database is closed")")
    }
    private func statement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard let conn else { throw fail("connection unavailable") }
        var prepared: OpaquePointer?
        guard sqlite3_prepare_v2(conn, sql, -1, &prepared, nil) == SQLITE_OK, let prepared else {
            throw fail("prepare failed")
        }
        defer { sqlite3_finalize(prepared) }
        return try body(prepared)
    }
    private func text(_ stmt: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, transient)
    }
    private func blob(_ stmt: OpaquePointer, _ index: Int32, _ value: Data) {
        value.withUnsafeBytes { bytes in
            _ = sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(bytes.count), transient)
        }
    }
    private func string(_ stmt: OpaquePointer, _ index: Int32) throws -> String {
        guard sqlite3_column_type(stmt, index) == SQLITE_TEXT, let bytes = sqlite3_column_text(stmt, index) else {
            throw fail("NULL or invalid text at column \(index)")
        }
        return String(cString: bytes)
    }
    private func data(_ stmt: OpaquePointer, _ index: Int32) throws -> Data {
        guard sqlite3_column_type(stmt, index) == SQLITE_BLOB, let bytes = sqlite3_column_blob(stmt, index) else {
            throw fail("NULL or invalid recording at column \(index)")
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, index)))
    }
    private func done(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw fail("write failed") }
    }
    private func exec(_ sql: String) throws { try statement(sql) { try done($0) } }

    func begin(levelID: UUID, source: LevelRunSource, playSpeed: PlaySpeed, setup: Data) throws -> UUID {
        let id = UUID()
        try statement("""
            INSERT INTO level_run(id,level_id,source,started_at,status,last_sequence,last_tick,format_version,setup,play_speed_factor)
            VALUES(?,?,?,?,'running',-1,0,2,?,?)
            """) {
            text($0, 1, id.uuidString); text($0, 2, levelID.uuidString); text($0, 3, source.rawValue)
            text($0, 4, ISO8601DateFormatter().string(from: Date())); blob($0, 5, setup)
            sqlite3_bind_double($0, 6, playSpeed.factor)
            try done($0)
        }
        return id
    }

    func append(runID: UUID, after sequence: Int64, actions: [PendingLevelAction]) throws {
        guard !actions.isEmpty else { return }
        try exec("BEGIN IMMEDIATE")
        var committed = false
        defer { if !committed { try? exec("ROLLBACK") } }
        // Appending never needs the (potentially large) immutable setup blob.
        // Keep hot-path queries in the DAO and read only the write cursor.
        let lastTick: Int64 = try statement("SELECT status,last_sequence,last_tick FROM level_run WHERE id=?") {
            text($0, 1, runID.uuidString)
            guard sqlite3_step($0) == SQLITE_ROW, try string($0, 0) == LevelRunStatus.running.rawValue,
                  sqlite3_column_int64($0, 1) == sequence else { throw fail("\(runID): closed run or out-of-order writer") }
            return sqlite3_column_int64($0, 2)
        }
        var previousTick = lastTick
        try statement("INSERT INTO level_action(run_id,sequence,tick,category,name,payload_json,presentation) VALUES(?,?,?,?,?,?,?)") { stmt in
            for (offset, action) in actions.enumerated() {
                guard action.tick >= previousTick else { throw fail("\(runID): tick went backwards") }
                previousTick = action.tick
                text(stmt, 1, runID.uuidString)
                sqlite3_bind_int64(stmt, 2, sequence + Int64(offset) + 1)
                sqlite3_bind_int64(stmt, 3, action.tick)
                text(stmt, 4, action.category); text(stmt, 5, action.name); text(stmt, 6, action.payload)
                if let frame = action.presentation { blob(stmt, 7, frame) } else { sqlite3_bind_null(stmt, 7) }
                try done(stmt); sqlite3_reset(stmt); sqlite3_clear_bindings(stmt)
            }
        }
        try statement("UPDATE level_run SET last_sequence=?,last_tick=? WHERE id=?") {
            sqlite3_bind_int64($0, 1, sequence + Int64(actions.count)); sqlite3_bind_int64($0, 2, previousTick)
            text($0, 3, runID.uuidString); try done($0)
        }
        try exec("COMMIT"); committed = true
    }

    func finish(id: UUID, status: LevelRunStatus, resultJSON: String?) throws {
        guard status != .running else { throw fail("finish requires a terminal status") }
        try statement("UPDATE level_run SET status=?,finished_at=?,result_json=? WHERE id=? AND status='running'") {
            text($0, 1, status.rawValue); text($0, 2, ISO8601DateFormatter().string(from: Date()))
            if let resultJSON { text($0, 3, resultJSON) } else { sqlite3_bind_null($0, 3) }
            text($0, 4, id.uuidString); try done($0)
            guard sqlite3_changes(conn) == 1 else { throw fail("\(id): missing or already finished run") }
        }
    }

    public func get(id: UUID) throws -> LevelRunRecord {
        try statement("SELECT level_id,source,status,last_sequence,last_tick,setup,result_json,format_version,play_speed_factor FROM level_run WHERE id=?") {
            text($0, 1, id.uuidString)
            guard sqlite3_step($0) == SQLITE_ROW else { throw fail("\(id): missing run") }
            guard let levelID = UUID(uuidString: try string($0, 0)),
                  let source = LevelRunSource(rawValue: try string($0, 1)),
                  let status = LevelRunStatus(rawValue: try string($0, 2)),
                  sqlite3_column_int($0, 7) == 2,
                  [SQLITE_INTEGER, SQLITE_FLOAT].contains(sqlite3_column_type($0, 8)) else { throw fail("\(id): invalid run metadata or format") }
            return LevelRunRecord(id: id, levelID: levelID, source: source, playSpeed: try PlaySpeed(sqlite3_column_double($0, 8)), status: status,
                lastSequence: sqlite3_column_int64($0, 3), lastTick: sqlite3_column_int64($0, 4),
                resultJSON: sqlite3_column_type($0, 6) == SQLITE_NULL ? nil : try string($0, 6), setup: try data($0, 5))
        }
    }

    public func runs(levelID: UUID, limit: Int = 100) throws -> [LevelRunRecord] {
        guard (1...10_000).contains(limit) else { throw fail("invalid query limit") }
        let ids: [UUID] = try statement("SELECT id FROM level_run WHERE level_id=? ORDER BY started_at DESC,rowid DESC LIMIT ?") {
            text($0, 1, levelID.uuidString); sqlite3_bind_int($0, 2, Int32(limit))
            var ids: [UUID] = []
            var code = sqlite3_step($0)
            while code == SQLITE_ROW {
                guard let id = UUID(uuidString: try string($0, 0)) else { throw fail("invalid run UUID") }
                ids.append(id); code = sqlite3_step($0)
            }
            guard code == SQLITE_DONE else { throw fail("run query failed") }
            return ids
        }
        return try ids.map { try get(id: $0) }
    }

    public func actions(runID: UUID, after sequence: Int64 = -1, limit: Int = 256) throws -> [LevelActionRecord] {
        guard sequence >= -1, (1...10_000).contains(limit) else { throw fail("invalid action cursor or limit") }
        return try statement("SELECT sequence,tick,category,name,payload_json,presentation FROM level_action WHERE run_id=? AND sequence>? ORDER BY sequence LIMIT ?") {
            text($0, 1, runID.uuidString); sqlite3_bind_int64($0, 2, sequence); sqlite3_bind_int($0, 3, Int32(limit))
            var rows: [LevelActionRecord] = [], code = sqlite3_step($0)
            while code == SQLITE_ROW {
                rows.append(LevelActionRecord(runID: runID, sequence: sqlite3_column_int64($0, 0), tick: sqlite3_column_int64($0, 1),
                    category: try string($0, 2), name: try string($0, 3), payloadJSON: try string($0, 4),
                    presentation: sqlite3_column_type($0, 5) == SQLITE_NULL ? nil : try data($0, 5)))
                code = sqlite3_step($0)
            }
            guard code == SQLITE_DONE else { throw fail("\(runID): action query failed") }
            return rows
        }
    }

    func presentationEncoding(runID: UUID) throws -> String {
        try statement("SELECT name FROM level_action WHERE run_id=? AND category='presentation' ORDER BY sequence LIMIT 1") {
            text($0, 1, runID.uuidString)
            guard sqlite3_step($0) == SQLITE_ROW else { throw fail("\(runID): missing presentation") }
            return try string($0, 0)
        }
    }
}
