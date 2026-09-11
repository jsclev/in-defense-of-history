import SQLite3

public final class ReinforcementConfigDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "reinforcement_config", loggerName: ReinforcementConfigDAO.self)
    }

    public func get() throws -> ReinforcementConfig {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            SELECT time_to_live_seconds, cooldown_seconds
            FROM reinforcement_config WHERE id = 1;
            """)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DbError.Db(message: "The database needs a reinforcement_config row.")
        }
        let numericTypes = [SQLITE_INTEGER, SQLITE_FLOAT]
        guard numericTypes.contains(sqlite3_column_type(stmt, 0)),
              numericTypes.contains(sqlite3_column_type(stmt, 1)) else {
            throw DbError.Db(message: "Reinforcement time to live and cooldown must be numeric game seconds.")
        }
        return try ReinforcementConfig(timeToLiveSeconds: getDouble(stmt: stmt, colIndex: 0),
                                       cooldownSeconds: getDouble(stmt: stmt, colIndex: 1))
    }
}
