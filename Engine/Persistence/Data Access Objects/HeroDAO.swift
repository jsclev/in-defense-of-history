import Foundation
import SQLite3

public class HeroDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "hero", loggerName: HeroDAO.self)
    }

    public func getAll() throws -> [Hero] {
        let heroes = try authoredRows("""
            SELECT h.*, lw.id AS resolved_wave_id,
                lw.level_info_id AS unlocked_level_id, li.level_name AS unlocked_level_name,
                c.id AS unlocked_campaign_id, c.campaign_name AS unlocked_campaign_name,
                lw.wave_index AS unlocked_wave,
                EXISTS(SELECT 1 FROM player_unlocked_hero u WHERE u.hero_id = h.id) AS unlocked
            FROM hero h
            LEFT JOIN level_wave lw ON lw.id = h.unlocked_at_level_wave_id
            LEFT JOIN level_info li ON li.id = lw.level_info_id
            LEFT JOIN campaign c ON c.id = li.campaign_id
            ORDER BY CASE WHEN c.campaign_name = 'Main' THEN 0 ELSE 1 END, li.started_at, h.id
            """, entity: "hero") { row in
                let id = try row.uuid("id")
                let row = AuthoredRow(statement: row.statement, entity: "hero[\(id)]")
                let wave = try row.uuid("unlocked_at_level_wave_id")
                guard let resolvedWave = try row.optionalText("resolved_wave_id"),
                      UUID(uuidString: resolvedWave) == wave else {
                    throw row.invalid("unlocked_at_level_wave_id", "does not identify an authored wave")
                }
                _ = try row.uuid("unlocked_campaign_id")
                let campaign = try row.text("unlocked_campaign_name")
                let ranking = try row.integer("ranking", minimum: 1)
                guard ranking <= 100 else { throw row.invalid("ranking", "must be <= 100") }
                let unitImage = try row.text("unit_image_name")
                do { _ = try HeroSpriteProfile.load(baseAssetName: unitImage) }
                catch { throw row.invalid("unit_image_name", String(describing: error)) }
                return Hero(id: id, shortName: try row.text("short_name"),
                    longName: try row.text("long_name"), ranking: ranking,
                    nickname: try row.optionalText("nickname"),
                    unlockedAtLevelId: try row.uuid("unlocked_level_id"),
                    unlockedAtLevelName: try row.text("unlocked_level_name"),
                    unlockedAtCampaignName: campaign,
                    unlockedAtWave: try row.integer("unlocked_wave", minimum: 1),
                    unlocked: try row.flag("unlocked"), fromMiniCampaign: campaign != "Main",
                    generalDescription: try row.text("general_description"),
                    historicalDescription: try row.text("historical_description"),
                    historicalText: try row.text("historical_text"),
                    primaryImageName: try row.text("primary_image_name"),
                    iconImageName: try row.text("icon_image_name"),
                    abilityIconImageName: try row.text("ability_icon_image_name"),
                    unitImageName: unitImage)
            }
        guard !heroes.isEmpty else { throw DbError.Db(message: "hero: authored roster is empty") }
        guard Set(heroes.map(\.id)).count == heroes.count else {
            throw DbError.Db(message: "hero: duplicate authored hero IDs")
        }
        return heroes
    }

    @discardableResult
    public func validateAuthoredContent() throws -> [Hero] {
        let heroes = try getAll()
        for hero in heroes { _ = try getCombatStats(heroID: hero.id) }
        _ = try getSelectedHeroes()
        let errors = try authoredRows("PRAGMA foreign_key_check", entity: "hero relationships") { row in
            (try row.text("table"), try row.integer("rowid", minimum: 0))
        }
        let heroTables: Set<String> = ["hero", "hero_combat", "level_hero", "player_selected_hero", "player_unlocked_hero"]
        if let invalid = errors.first(where: { heroTables.contains($0.0) }) {
            throw DbError.Db(message: "\(invalid.0)[rowid=\(invalid.1)]: missing referenced hero content")
        }
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
        guard let stmt else { throw DbError.Db(message: "Missing hero combat statement") }
        let stats = try AuthoredRow(statement: stmt, entity: "hero_combat \(heroID)").heroCombatStats()
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DbError.Db(message: "hero_combat[\(heroID)]: duplicate row or incomplete read")
        }
        return stats
    }

    public func getSelectedHeroIds() throws -> [UUID] {
        let rows = try authoredRows("""
            SELECT s.hero_id, s.selection_slot, h.id AS resolved_hero_id
            FROM player_selected_hero s LEFT JOIN hero h ON h.id = s.hero_id
            ORDER BY h.ranking DESC, h.id COLLATE NOCASE
            """, entity: "player_selected_hero") { row in
                let id = try row.uuid("hero_id")
                let row = AuthoredRow(statement: row.statement, entity: "player_selected_hero[\(id)]")
                guard id == (try row.uuid("resolved_hero_id")) else {
                    throw row.invalid("hero_id", "does not identify an authored hero")
                }
                let slot = try row.integer("selection_slot", minimum: 1)
                guard slot <= HeroSelection.maxSelected else { throw row.invalid("selection_slot", "is unsupported") }
                return (id, slot)
            }
        if !rows.isEmpty {
            guard Set(rows.map { $0.1 }) == Set(1...rows.count),
                  Set(rows.map { $0.0 }).count == rows.count else {
                throw DbError.Db(message: "player_selected_hero: missing or duplicate selection_slot or hero_id")
            }
        }
        return rows.map { $0.0 }
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
