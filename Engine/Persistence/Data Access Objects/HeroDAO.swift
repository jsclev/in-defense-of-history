import Foundation
import SQLite3

public class HeroDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "hero", loggerName: HeroDAO.self)
    }

    public func getAll() throws -> [Hero] {
        var heroes: [Hero] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                h.id,
                h.short_name,
                h.long_name,
                h.nickname,
                lw.level_info_id,
                h.general_description,
                h.historical_description,
                h.historical_text,
                h.primary_image_name,
                h.details_image_name,
                CASE WHEN c.campaign_name = 'Main' THEN 0 ELSE 1 END AS mini,
                li.level_name,
                c.campaign_name,
                CASE WHEN u.hero_id IS NULL THEN 0 ELSE 1 END AS unlocked,
                lw.wave_index,
                h.icon_image_name,
                h.ability_icon_image_name,
                h.unit_image_name,
                h.ranking
            FROM
                hero h
            LEFT JOIN
                level_wave lw ON lw.id = h.unlocked_at_level_wave_id
            LEFT JOIN
                level_info li ON li.id = lw.level_info_id
            LEFT JOIN
                campaign c ON c.id = li.campaign_id
            LEFT JOIN
                player_unlocked_hero u ON u.hero_id = h.id
            ORDER BY
                mini, li.started_at
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let shortName = try getString(stmt: stmt, colIndex: 1),
               let longName = try getString(stmt: stmt, colIndex: 2),
               let generalDescription = try getString(stmt: stmt, colIndex: 5),
               let historicalDescription = try getString(stmt: stmt, colIndex: 6),
               let historicalText = try getString(stmt: stmt, colIndex: 7),
               let primaryImageName = try getString(stmt: stmt, colIndex: 8),
               let detailsImageName = try getString(stmt: stmt, colIndex: 9),
               let iconImageName = try getString(stmt: stmt, colIndex: 15),
               let abilityIconImageName = try getString(stmt: stmt, colIndex: 16) {
                heroes.append(Hero(
                    id: try getUUID(stmt: stmt, colIndex: 0, msg: "hero id"),
                    shortName: shortName,
                    longName: longName,
                    ranking: getInt(stmt: stmt, colIndex: 18),
                    nickname: try getString(stmt: stmt, colIndex: 3),
                    unlockedAtLevelId: try? getUUID(stmt: stmt, colIndex: 4, msg: "unlock level id"),
                    unlockedAtLevelName: try getString(stmt: stmt, colIndex: 11),
                    unlockedAtCampaignName: try getString(stmt: stmt, colIndex: 12),
                    unlockedAtWave: getInt(stmt: stmt, colIndex: 14),
                    unlocked: getInt(stmt: stmt, colIndex: 13) == 1,
                    fromMiniCampaign: getInt(stmt: stmt, colIndex: 10) == 1,
                    generalDescription: generalDescription,
                    historicalDescription: historicalDescription,
                    historicalText: historicalText,
                    primaryImageName: primaryImageName,
                    detailsImageName: detailsImageName,
                    iconImageName: iconImageName,
                    abilityIconImageName: abilityIconImageName,
                    unitImageName: try getString(stmt: stmt, colIndex: 17)
                ))
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return heroes
    }

    public func getCombatStats(heroID: UUID) throws -> HeroCombatStats {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: """
            SELECT attack_rating, defense_rating, hp, attack_interval,
                   respawn_seconds, heal_per_second, move_speed
            FROM hero_combat WHERE hero_id = ?
            """)
        defer { sqlite3_finalize(stmt) }
        try bindParam(stmt, index: 1, value: heroID.uuidString.lowercased())
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw DbError.Db(message: "Missing combat stats for hero \(heroID)")
        }
        return HeroCombatStats(attackRating: getDouble(stmt: stmt, colIndex: 0),
            defenseRating: getDouble(stmt: stmt, colIndex: 1), hp: getDouble(stmt: stmt, colIndex: 2),
            attackInterval: getDouble(stmt: stmt, colIndex: 3), respawnSeconds: getDouble(stmt: stmt, colIndex: 4),
            healPerSecond: getDouble(stmt: stmt, colIndex: 5), moveSpeed: getDouble(stmt: stmt, colIndex: 6))
    }

    public func getSelectedHeroIds() throws -> [UUID] {
        var ids: [UUID] = []
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt,
                    sql: """
                        SELECT s.hero_id FROM player_selected_hero s
                        INNER JOIN hero h ON h.id = s.hero_id
                        ORDER BY h.ranking DESC, h.id COLLATE NOCASE
                        """)
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(try getUUID(stmt: stmt, colIndex: 0, msg: "selected hero id"))
        }
        return ids
    }

    public func getSelectedHeroes() throws -> HeroSelection {
        let ids = try getSelectedHeroIds()
        let roster = try getAll()
        let heroes = ids.compactMap { id in roster.first { $0.id == id } }
        guard heroes.count == ids.count else { throw HeroSelection.SelectionError.unknownHero }
        return try HeroSelection(heroes: heroes)
    }

    public func setSelectedHeroes(_ heroIds: [UUID]) throws {
        let roster = try getAll()
        let heroes = heroIds.compactMap { id in roster.first { $0.id == id } }
        guard heroes.count == heroIds.count else { throw HeroSelection.SelectionError.unknownHero }
        let selection = try HeroSelection(heroes: heroes)

        // Validate before deleting, and roll back the complete selection if any
        // insert fails. Slot 1 is primary; slot 2 is secondary at save time.
        try executeNonQuery(conn: conn, sql: "SAVEPOINT hero_selection")
        do {
            try executeNonQuery(conn: conn, sql: "DELETE FROM player_selected_hero")
            for (index, heroId) in selection.ids.enumerated() {
                var insert: OpaquePointer?
                try prepare(conn: conn, stmt: &insert,
                            sql: "INSERT INTO player_selected_hero (id, hero_id, selection_slot) VALUES (?, ?, ?)")
                defer { sqlite3_finalize(insert) }
                try bindParam(insert, index: 1, value: UUID().uuidString.lowercased())
                try bindParam(insert, index: 2, value: heroId.uuidString.lowercased())
                try bindParam(insert, index: 3, value: index + 1)
                guard sqlite3_step(insert) == SQLITE_DONE else {
                    throw DbError.Db(message: String(cString: sqlite3_errmsg(conn)))
                }
            }
            try executeNonQuery(conn: conn, sql: "RELEASE hero_selection")
        } catch {
            try? executeNonQuery(conn: conn, sql: "ROLLBACK TO hero_selection")
            try? executeNonQuery(conn: conn, sql: "RELEASE hero_selection")
            throw error
        }
    }
}
