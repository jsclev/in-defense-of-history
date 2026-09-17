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

        let rows = try authoredRows("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                m.min_hp,
                m.max_hp,
                m.min_damage,
                m.max_damage
            FROM
                sim_melee_unit m
            LEFT JOIN
                tower t ON t.id = m.tower_id
            LEFT JOIN
                tower_type tt ON tt.id = t.tower_type_id
        """, entity: "sim_melee_unit") { row in
            let category = try row.text("tower_type_category")
            let level = try row.integer("tower_level", minimum: 1)
            let minHP = try row.number("min_hp", minimum: 0, strictlyGreater: true)
            let minDamage = try row.number("min_damage", minimum: 0, strictlyGreater: true)
            let brackets = SimMeleeBrackets(
                hp: minHP...(try row.number("max_hp", minimum: minHP)),
                averageDamage: minDamage...(try row.number("max_damage", minimum: minDamage))
            )
            return (category, level, brackets)
        }
        for (category, level, brackets) in rows {
            guard out[category, default: [:]].updateValue(brackets, forKey: level) == nil else {
                throw DbError.Db(message: "sim_melee_unit: duplicate category/tier \(category)/\(level)")
            }
        }

        return out
    }
}
