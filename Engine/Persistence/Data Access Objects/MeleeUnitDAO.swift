import Foundation
import SQLite3

public class MeleeUnitDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "melee_unit", loggerName: MeleeUnitDAO.self)
    }

    public func getStatsByTowerId() throws -> [UUID: MeleeUnitStats] {
        let rows = try authoredRows("SELECT * FROM melee_unit", entity: "melee_unit") { row in
            let id = try row.uuid("tower_id")
            let row = AuthoredRow(statement: row.statement, entity: "tower[\(id)] melee_unit")
            let soldiers = try row.integer("soldier_count", minimum: 1)
            guard soldiers <= 4 else { throw row.invalid("soldier_count", "exceeds the engine limit") }
            let defense = try row.number("defense_rating", minimum: 0, maximum: 1)
            guard defense < 1 else { throw row.invalid("defense_rating", "must be less than 1") }
            return (id, MeleeUnitStats(soldierCount: soldiers,
                attackRating: try row.number("attack_rating", minimum: 0, strictlyGreater: true),
                defenseRating: defense,
                hp: try row.number("hp", minimum: 0, strictlyGreater: true),
                rallyPointRadius: try row.number("rally_point_radius", minimum: 0, strictlyGreater: true),
                attackInterval: try row.number("attack_interval", minimum: 0, strictlyGreater: true),
                respawnSeconds: try row.number("respawn_seconds", minimum: 0, strictlyGreater: true),
                healPerSecond: try row.number("heal_per_second", minimum: 0)))
        }
        var result: [UUID: MeleeUnitStats] = [:]
        for (id, stats) in rows {
            guard result.updateValue(stats, forKey: id) == nil else {
                throw DbError.Db(message: "tower[\(id)]: duplicate melee_unit")
            }
        }
        return result
    }
}
