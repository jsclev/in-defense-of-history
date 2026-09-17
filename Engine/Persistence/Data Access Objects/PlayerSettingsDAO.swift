import SQLite3

public final class PlayerSettingsDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "player_settings", loggerName: PlayerSettingsDAO.self)
    }

    public func get() throws -> PlayerSettings {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            SELECT debug_mode, show_debug_info, show_debug_layout_guides,
                   enemy_escape_haptics_enabled FROM player_settings WHERE id = 1
            """)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DbError.Db(message: "Missing authored player_settings row")
        }
        return PlayerSettings(debugMode: getInt(stmt: stmt, colIndex: 0) == 1,
            showDebugInfo: getInt(stmt: stmt, colIndex: 1) == 1,
            showDebugLayoutGuides: getInt(stmt: stmt, colIndex: 2) == 1,
            enemyEscapeHapticsEnabled: getInt(stmt: stmt, colIndex: 3) == 1)
    }

    public func set(_ settings: PlayerSettings) throws {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            UPDATE player_settings SET debug_mode = ?, show_debug_info = ?,
                show_debug_layout_guides = ?, enemy_escape_haptics_enabled = ? WHERE id = 1
            """)
        defer { sqlite3_finalize(stmt) }
        for (index, value) in [settings.debugMode, settings.showDebugInfo,
            settings.showDebugLayoutGuides, settings.enemyEscapeHapticsEnabled].enumerated() {
            try bindParam(stmt, index: index + 1, value: value ? 1 : 0)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(conn) == 1 else {
            throw DbError.Db(message: "Unable to update the authored player_settings row")
        }
    }
}
