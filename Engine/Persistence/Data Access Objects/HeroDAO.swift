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
                lw.wave_index
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
               let detailsImageName = try getString(stmt: stmt, colIndex: 9) {
                heroes.append(Hero(
                    id: try getUUID(stmt: stmt, colIndex: 0, msg: "hero id"),
                    shortName: shortName,
                    longName: longName,
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
                    detailsImageName: detailsImageName
                ))
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return heroes
    }

    public func getSelectedHeroIds() throws -> [UUID] {
        var ids: [UUID] = []
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt,
                    sql: "SELECT hero_id FROM player_selected_hero ORDER BY selection_slot")
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.append(try getUUID(stmt: stmt, colIndex: 0, msg: "selected hero id"))
        }
        sqlite3_finalize(stmt)
        stmt = nil
        return ids
    }

    public func setSelectedHeroes(_ heroIds: [UUID]) throws {
        var stmt: OpaquePointer?
        try prepare(conn: conn, stmt: &stmt, sql: "DELETE FROM player_selected_hero")
        _ = sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        stmt = nil

        for (index, heroId) in heroIds.prefix(2).enumerated() {
            var insert: OpaquePointer?
            try prepare(conn: conn, stmt: &insert,
                        sql: "INSERT INTO player_selected_hero (id, hero_id, selection_slot) VALUES (?, ?, ?)")
            try bindParam(insert, index: 1, value: UUID().uuidString.lowercased())
            try bindParam(insert, index: 2, value: heroId.uuidString.lowercased())
            try bindParam(insert, index: 3, value: index + 1)
            try insertOneRow(conn: conn, stmt: insert)
            sqlite3_finalize(insert)
        }
    }
}
