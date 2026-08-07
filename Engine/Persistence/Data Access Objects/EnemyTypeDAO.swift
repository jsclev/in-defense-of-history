import Foundation
import SQLite3

public class EnemyTypeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "enemy_type", loggerName: EnemyTypeDAO.self)
    }

    /// Loads the full enemy roster — the source of the encyclopedia, the
    /// simulation catalog, and wave authoring. Ordered by name for stable output.
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
                et.traits
            FROM
                enemy_type et
            ORDER BY
                et.enemy_type_name
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "enemy type id")

            guard let name = try getString(stmt: stmt, colIndex: 1) else {
                throw DbError.Db(message: "enemy_type row \(id.uuidString.lowercased()) has a null name.")
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
                breakBand: breakBandLo...breakBandHi
            )

            let traits = try decodeTraits(stmt: stmt, colIndex: 13, name: name)

            enemyTypes.append(EnemyType(id: id, name: name, stats: stats, traits: traits))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return enemyTypes
    }

    /// The `traits` column stores the same human-readable JSON the `Trait`
    /// Codable produces, so decoding round-trips through JSONDecoder.
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
