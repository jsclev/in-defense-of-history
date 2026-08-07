import Foundation
import SQLite3

public class TowerUnlockDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "level_tower_unlock", loggerName: TowerUnlockDAO.self)
    }

    public func getUnlocksFor(levelInfoId: UUID) throws -> [String: Int] {
        var unlocks: [String: Int] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                ltu.tower_kind,
                ltu.max_tower_level
            FROM
                level_tower_unlock ltu
            WHERE
                ltu.level_info_id = ?
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let kind = try getString(stmt: stmt, colIndex: 0) {
                unlocks[kind] = getInt(stmt: stmt, colIndex: 1)
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return unlocks
    }
}
