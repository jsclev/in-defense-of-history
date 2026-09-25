import SQLite3

public final class PlaySpeedDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "play_speed", loggerName: PlaySpeedDAO.self)
    }

    public func get(for source: LevelRunSource) throws -> PlaySpeed {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: "SELECT factor FROM play_speed WHERE source = '\(source.rawValue)'")
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DbError.Db(message: "play_speed[\(source.rawValue)].factor: missing required row")
        }
        guard [SQLITE_INTEGER, SQLITE_FLOAT].contains(sqlite3_column_type(stmt, 0)) else {
            throw DbError.Db(message: "play_speed[\(source.rawValue)].factor: expected a non-NULL number")
        }
        do { return try PlaySpeed(sqlite3_column_double(stmt, 0)) }
        catch { throw DbError.Db(message: "play_speed[\(source.rawValue)].factor: \(error)") }
    }

    public func get() throws -> PlaySpeedConfiguration {
        try PlaySpeedConfiguration(player: get(for: .player), simulator: get(for: .simulator), editor: get(for: .editor))
    }
}
