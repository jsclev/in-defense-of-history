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
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        var step = sqlite3_step(stmt)
        while step == SQLITE_ROW {
            let row = AuthoredRow(statement: stmt!, entity: "level_tower_unlock[\(levelInfoId)]")
            let kind = try row.text("tower_kind")
            guard TowerKind(rawValue: kind) != nil else {
                throw row.invalid("tower_kind", "is unsupported")
            }
            let maximum = try row.integer("max_tower_level", minimum: 0)
            guard unlocks.updateValue(maximum, forKey: kind) == nil else {
                throw row.invalid("tower_kind", "is duplicated")
            }
            step = sqlite3_step(stmt)
        }
        guard step == SQLITE_DONE, Set(unlocks.keys) == Set(TowerKind.allCases.map(\.rawValue)) else {
            throw DbError.Db(message: "level_tower_unlock[\(levelInfoId)]: every tower kind requires an explicit maximum level")
        }
        let rows = try authoredRows("SELECT tower_type_key, level_layout FROM tower_type", entity: "tower_type") { row in
            guard let kind = TowerKind(rawValue: try row.text("tower_type_key")) else { throw row.invalid("tower_type_key", "is unsupported") }
            let layout = try JSONDecoder().decode([[Int]].self, from: Data(try row.text("level_layout").utf8))
            return (kind.rawValue, layout.count)
        }
        for (kind, count) in rows {
            guard let maximum = unlocks[kind], maximum <= count else {
                throw DbError.Db(message: "level_tower_unlock[\(levelInfoId)]: max_tower_level exceeds authored levels for \(kind)")
            }
        }

        return unlocks
    }
}
