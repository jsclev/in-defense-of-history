import Foundation
import SQLite3

public final class PlayerSettingsDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "player_settings", loggerName: PlayerSettingsDAO.self)
    }

    public func get() throws -> PlayerSettings {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            SELECT debug_mode, show_debug_info, show_debug_layout_guides,
                   enemy_escape_haptics_enabled, show_ga_solution_button FROM player_settings WHERE id = 1
            """)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DbError.Db(message: "Missing authored player_settings row")
        }
        let row = AuthoredRow(statement: stmt!, entity: "player_settings[1]")
        return try PlayerSettings(debugMode: row.flag("debug_mode"),
            showDebugInfo: row.flag("show_debug_info"),
            showDebugLayoutGuides: row.flag("show_debug_layout_guides"),
            enemyEscapeHapticsEnabled: row.flag("enemy_escape_haptics_enabled"),
            showGASolutionButton: row.flag("show_ga_solution_button"))
    }

    public func set(_ settings: PlayerSettings) throws {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            UPDATE player_settings SET debug_mode = ?, show_debug_info = ?,
                show_debug_layout_guides = ?, enemy_escape_haptics_enabled = ?,
                show_ga_solution_button = ? WHERE id = 1
            """)
        defer { sqlite3_finalize(stmt) }
        for (index, value) in [settings.debugMode, settings.showDebugInfo,
            settings.showDebugLayoutGuides, settings.enemyEscapeHapticsEnabled,
            settings.showGASolutionButton].enumerated() {
            try bindParam(stmt, index: index + 1, value: value ? 1 : 0)
        }
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(conn) == 1 else {
            throw DbError.Db(message: "Unable to update the authored player_settings row")
        }
    }
}


extension PlayerSettingsDAO {
    public func getHeroControls() throws -> [HeroControlSetting] {
        let rows = try authoredRows("""
            SELECT h.id, h.short_name, c.ai_enabled,
                   EXISTS(SELECT 1 FROM player_unlocked_hero u WHERE u.hero_id = h.id) AS unlocked
            FROM hero h LEFT JOIN player_hero_control c ON c.hero_id = h.id
            ORDER BY h.short_name, h.id
            """, entity: "player_hero_control") { row in
                let id = try row.uuid("id")
                let row = AuthoredRow(statement: row.statement, entity: "player_hero_control[\(id)]")
                return HeroControlSetting(id: id, name: try row.text("short_name"),
                    unlocked: try row.flag("unlocked"), aiEnabled: try row.flag("ai_enabled"))
            }
        guard !rows.isEmpty else { throw DbError.Db(message: "player_hero_control: missing authored roster") }
        return rows
    }

    public func setHeroAIEnabled(_ enabled: Bool, heroID: UUID) throws {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: "UPDATE player_hero_control SET ai_enabled = ? WHERE hero_id = ?")
        defer { sqlite3_finalize(stmt) }
        try bindParam(stmt, index: 1, value: enabled ? 1 : 0)
        try bindParam(stmt, index: 2, value: heroID.uuidString.lowercased())
        guard sqlite3_step(stmt) == SQLITE_DONE, sqlite3_changes(conn) == 1 else {
            throw DbError.Db(message: "player_hero_control[\(heroID)]: cannot update ai_enabled")
        }
    }
}
