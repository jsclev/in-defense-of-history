import Foundation
import SQLite3

public class LevelHeroDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "level_hero", loggerName: LevelHeroDAO.self)
    }

    public func getHeroesFor(levelInfoId: UUID) throws -> [LevelHero] {
        var levelHeroes: [LevelHero] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                lh.hero_id,
                lh.enemy_path_index,
                hc.attack_rating,
                hc.defense_rating,
                hc.hp,
                hc.attack_interval,
                hc.respawn_seconds,
                hc.heal_per_second,
                hc.move_speed
            FROM
                level_hero lh
            INNER JOIN
                hero_combat hc ON hc.hero_id = lh.hero_id
            WHERE
                lh.level_info_id = ?
            ORDER BY
                lh.enemy_path_index
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            levelHeroes.append(LevelHero(
                heroId: try getUUID(stmt: stmt, colIndex: 0, msg: "level hero hero id"),
                enemyPathIndex: getInt(stmt: stmt, colIndex: 1),
                combat: HeroCombatStats(
                    attackRating: getDouble(stmt: stmt, colIndex: 2),
                    defenseRating: getDouble(stmt: stmt, colIndex: 3),
                    hp: getDouble(stmt: stmt, colIndex: 4),
                    attackInterval: getDouble(stmt: stmt, colIndex: 5),
                    respawnSeconds: getDouble(stmt: stmt, colIndex: 6),
                    healPerSecond: getDouble(stmt: stmt, colIndex: 7),
                    moveSpeed: getDouble(stmt: stmt, colIndex: 8))
            ))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return levelHeroes
    }
}
