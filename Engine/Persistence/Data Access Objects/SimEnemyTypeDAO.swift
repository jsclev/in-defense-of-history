import Foundation
import SQLite3

public class SimEnemyTypeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "sim_enemy_type", loggerName: SimEnemyTypeDAO.self)
    }

    public func getSpeedBounds() throws -> [UUID: ClosedRange<Double>] {
        try bounds(minColumn: "min_speed", maxColumn: "max_speed")
    }

    public func getHpBounds() throws -> [UUID: ClosedRange<Double>] {
        try bounds(minColumn: "min_hp", maxColumn: "max_hp")
    }

    public func getBountyBounds() throws -> [UUID: ClosedRange<Double>] {
        try bounds(minColumn: "min_bounty", maxColumn: "max_bounty",
                   fromTable: "sim_enemy_type_bounty")
    }

    private func bounds(minColumn: String, maxColumn: String,
                        fromTable table: String = "sim_enemy_type") throws -> [UUID: ClosedRange<Double>] {
        var out: [UUID: ClosedRange<Double>] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                s.enemy_type_id,
                s.\(minColumn),
                s.\(maxColumn)
            FROM
                \(table) s
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "enemy type id")
            let lo = getDouble(stmt: stmt, colIndex: 1)
            let hi = getDouble(stmt: stmt, colIndex: 2)
            if hi >= lo { out[id] = lo...hi }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return out
    }
}
