import Foundation
import SQLite3

public class MeleeUnitDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "melee_unit", loggerName: MeleeUnitDAO.self)
    }

    public func getStatsByTowerId() throws -> [UUID: MeleeUnitStats] {
        var out: [UUID: MeleeUnitStats] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                m.tower_id,
                m.soldier_count,
                m.attack_rating,
                m.defense_rating,
                m.hp,
                m.rally_point_radius,
                m.attack_interval,
                m.respawn_seconds,
                m.heal_per_second
            FROM
                melee_unit m
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let towerId = try getUUID(stmt: stmt, colIndex: 0, msg: "melee_unit tower_id")
            out[towerId] = MeleeUnitStats(
                soldierCount: getInt(stmt: stmt, colIndex: 1),
                attackRating: getDouble(stmt: stmt, colIndex: 2),
                defenseRating: getDouble(stmt: stmt, colIndex: 3),
                hp: getDouble(stmt: stmt, colIndex: 4),
                rallyPointRadius: getDouble(stmt: stmt, colIndex: 5),
                attackInterval: getDouble(stmt: stmt, colIndex: 6),
                respawnSeconds: getDouble(stmt: stmt, colIndex: 7),
                healPerSecond: getDouble(stmt: stmt, colIndex: 8)
            )
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return out
    }
}
