import Foundation
import SQLite3

public class EnemyTypeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "enemy_type", loggerName: EnemyTypeDAO.self)
    }

    public func getAll() throws -> [EnemyType] {
        var enemyTypes: [EnemyType] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                et.id,
                et.enemy_type_name,
                et.max_hp,
                et.speed,
                et.cover,
                et.discipline,
                et.hardiness,
                et.damage_min,
                et.damage_max,
                et.bounty,
                et.lives_cost,
                et.break_band_lo,
                et.break_band_hi,
                et.traits,
                et.morale_speed_threshold,
                et.morale_attack_threshold,
                et.morale_speed_multiplier,
                et.morale_attack_multiplier,
                et.enemy_type_key,
                et.enemy_type_description,
                et.image_name
            FROM
                enemy_type et
            ORDER BY
                et.enemy_type_name
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)
        defer { sqlite3_finalize(stmt) }

        var result = sqlite3_step(stmt)
        while result == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "enemy type id")

            guard let name = try getString(stmt: stmt, colIndex: 1),
                  let key = try getString(stmt: stmt, colIndex: 18),
                  let description = try getString(stmt: stmt, colIndex: 19),
                  let imageName = try getString(stmt: stmt, colIndex: 20),
                  [name, key, description, imageName].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw DbError.Db(message: "enemy_type row \(id.uuidString.lowercased()) is missing required identity, display copy or artwork.")
            }

            let breakBandLo = getDouble(stmt: stmt, colIndex: 11)
            let breakBandHi = getDouble(stmt: stmt, colIndex: 12)
            guard breakBandLo <= breakBandHi else {
                throw DbError.Db(message: "enemy_type '\(name)' has break_band_lo (\(breakBandLo)) > break_band_hi (\(breakBandHi)).")
            }

            let stats = EnemyStats(
                maxHP: getDouble(stmt: stmt, colIndex: 2),
                speed: getDouble(stmt: stmt, colIndex: 3),
                cover: getDouble(stmt: stmt, colIndex: 4),
                discipline: getDouble(stmt: stmt, colIndex: 5),
                hardiness: getDouble(stmt: stmt, colIndex: 6),
                damageMin: getDouble(stmt: stmt, colIndex: 7),
                damageMax: getDouble(stmt: stmt, colIndex: 8),
                gold: getInt(stmt: stmt, colIndex: 9),
                livesCost: getInt(stmt: stmt, colIndex: 10),
                breakBand: breakBandLo...breakBandHi,
                moraleResponse: EnemyMoraleResponse(
                    speedThreshold: getDouble(stmt: stmt, colIndex: 14),
                    attackThreshold: getDouble(stmt: stmt, colIndex: 15),
                    speedMultiplier: getDouble(stmt: stmt, colIndex: 16),
                    attackMultiplier: getDouble(stmt: stmt, colIndex: 17))
            )

            let traits = try decodeTraits(stmt: stmt, colIndex: 13, name: name)

            enemyTypes.append(EnemyType(id: id, key: key, name: name, description: description,
                                       imageName: imageName, stats: stats, traits: traits))
            result = sqlite3_step(stmt)
        }

        guard result == SQLITE_DONE else {
            throw DbError.Db(message: "Unable to read the enemy roster: \(String(cString: sqlite3_errmsg(conn)))")
        }

        return enemyTypes
    }

    private func decodeTraits(stmt: OpaquePointer?, colIndex: Int, name: String) throws -> [Trait] {
        guard let json = try getString(stmt: stmt, colIndex: colIndex), !json.isEmpty else {
            return []
        }

        guard let data = json.data(using: .utf8) else {
            throw DbError.Db(message: "enemy_type '\(name)' traits column is not valid UTF-8.")
        }

        do {
            return try JSONDecoder().decode([Trait].self, from: data)
        } catch {
            throw DbError.Db(message: "Unable to decode traits for enemy_type '\(name)': \(error)")
        }
    }
}
