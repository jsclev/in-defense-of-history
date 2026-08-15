import Foundation
import SQLite3

public struct SimMeleeBrackets {
    public var hp: ClosedRange<Double>
    public var averageDamage: ClosedRange<Double>
}

public class SimMeleeUnitDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "sim_melee_unit", loggerName: SimMeleeUnitDAO.self)
    }

    public func getBrackets() throws -> [String: [Int: SimMeleeBrackets]] {
        var out: [String: [Int: SimMeleeBrackets]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                m.min_hp,
                m.max_hp,
                m.min_damage,
                m.max_damage
            FROM
                sim_melee_unit m
            INNER JOIN
                tower t ON t.id = m.tower_id
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
            WHERE
                t.branch = 1
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let category = try getString(stmt: stmt, colIndex: 0) else { continue }
            let brackets = SimMeleeBrackets(
                hp: getDouble(stmt: stmt, colIndex: 2)...getDouble(stmt: stmt, colIndex: 3),
                averageDamage: getDouble(stmt: stmt, colIndex: 4)...getDouble(stmt: stmt, colIndex: 5)
            )
            out[category, default: [:]][getInt(stmt: stmt, colIndex: 1)] = brackets
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return out
    }
}
