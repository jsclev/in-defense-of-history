import Foundation
import SQLite3

/// Owns the complete active selection and star ledger. Writes always read fresh
/// state inside a transaction; an older screen cannot overwrite a newer purchase.
public final class PlayerMetaUpgradeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "player_meta_upgrade_selection", loggerName: PlayerMetaUpgradeDAO.self)
    }

    public func get(profile: MetaUpgradeProfile = .active) throws -> PlayerMetaUpgradeState {
        try transaction { try read(profile: profile) }
    }

    public func getAll() throws -> [MetaUpgradeProfile: PlayerMetaUpgradeState] {
        try transaction {
            try Dictionary(uniqueKeysWithValues: MetaUpgradeProfile.allCases.map { ($0, try read(profile: $0)) })
        }
    }

    public func setSelectedUpgrades(_ selected: Set<MetaUpgrade>) throws {
        try change { current in
            (try current.selecting(selected), ())
        }
    }

    @discardableResult public func purchase(_ upgrade: MetaUpgrade) throws -> Bool {
        try change { current in
            var loadout = current.loadout
            let purchased = loadout.purchase(upgrade)
            return (try PlayerMetaUpgradeState(catalog: current.loadout.catalog, selected: loadout.selected, bestStarsByLevel: current.bestStarsByLevel), purchased)
        }
    }

    public func refund(_ upgrade: MetaUpgrade) throws {
        try change { current in
            var loadout = current.loadout
            loadout.refund(upgrade)
            return (try PlayerMetaUpgradeState(catalog: current.loadout.catalog, selected: loadout.selected, bestStarsByLevel: current.bestStarsByLevel), ())
        }
    }

    /// A respec preserves the earned star ledger.
    public func reset() throws { try setSelectedUpgrades([]) }

    /// Restore selections AND results from authored SQL, never a Swift preset.
    public func restoreLevel15() throws {
        try change { _ in (try self.read(profile: .level15), ()) }
    }

    @discardableResult public func recordVictory(levelID: UUID, lives: Int, startingLives: Int) throws -> Int {
        guard startingLives > 0, (0...startingLives).contains(lives) else {
            throw DbError.Db(message: "player_meta_upgrade_level_stars[\(levelID)]: invalid lives \(lives)/\(startingLives)")
        }
        return try change { current in
            guard let previous = current.bestStarsByLevel[levelID] else {
                throw DbError.Db(message: "player_meta_upgrade_level_stars[active:\(levelID)]: missing level_info_id")
            }
            guard lives > 0 else { return (current, 0) }
            let reward = try VictoryReward(lives: lives, startingLives: startingLives, previousBestStars: previous)
            var results = current.bestStarsByLevel
            results[levelID] = reward.bestStars
            return (try PlayerMetaUpgradeState(catalog: current.loadout.catalog, selected: current.loadout.selected, bestStarsByLevel: results), reward.earned)
        }
    }

    private func read(profile: MetaUpgradeProfile) throws -> PlayerMetaUpgradeState {
        let catalog = try MetaUpgradeDAO(conn: conn).get()
        let profiles = try authoredRows("SELECT profile_key FROM player_meta_upgrade_profile", entity: "player_meta_upgrade_profile") {
            try $0.text("profile_key")
        }
        guard Set(profiles) == Set(MetaUpgradeProfile.allCases.map(\.rawValue)), profiles.count == MetaUpgradeProfile.allCases.count else {
            throw DbError.Db(message: "player_meta_upgrade_profile: attribute 'profile_key' must contain exactly active and level15")
        }
        // profile.rawValue comes exclusively from the closed enum above.
        let selectionRows = try authoredRows("""
            SELECT upgrade_key, is_selected FROM player_meta_upgrade_selection
            WHERE profile_key = '\(profile.rawValue)' ORDER BY upgrade_key
            """, entity: "player_meta_upgrade_selection[\(profile.rawValue)]") { row in
                let key = try row.text("upgrade_key")
                let row = AuthoredRow(statement: row.statement, entity: "player_meta_upgrade_selection[\(profile.rawValue):\(key)]")
                guard let upgrade = MetaUpgrade(rawValue: key) else {
                    throw row.invalid("upgrade_key", "is unknown")
                }
                return (upgrade, try row.flag("is_selected"))
            }
        let keys = Set(selectionRows.map { $0.0 })
        for upgrade in MetaUpgrade.allCases where !keys.contains(upgrade) {
            throw DbError.Db(message: "player_meta_upgrade_selection[\(profile.rawValue):\(upgrade.rawValue)]: missing is_selected row")
        }
        guard keys.count == selectionRows.count else {
            throw DbError.Db(message: "player_meta_upgrade_selection[\(profile.rawValue)]: duplicate upgrade_key")
        }
        let expectedLevels = try authoredRows("SELECT id FROM level_info", entity: "level_info") { try $0.uuid("id") }
        guard !expectedLevels.isEmpty else { throw DbError.Db(message: "level_info: missing authored campaign levels") }
        let starRows = try authoredRows("""
            SELECT s.level_info_id, s.best_stars, l.id AS resolved_level_id
            FROM player_meta_upgrade_level_stars s LEFT JOIN level_info l ON l.id = s.level_info_id
            WHERE s.profile_key = '\(profile.rawValue)' ORDER BY s.level_info_id
            """, entity: "player_meta_upgrade_level_stars[\(profile.rawValue)]") { row in
                let id = try row.uuid("level_info_id")
                let row = AuthoredRow(statement: row.statement, entity: "player_meta_upgrade_level_stars[\(profile.rawValue):\(id)]")
                guard try row.uuid("resolved_level_id") == id else {
                    throw row.invalid("level_info_id", "does not reference an authored level")
                }
                let stars = try row.integer("best_stars", minimum: 0)
                guard stars <= 3 else { throw row.invalid("best_stars", "must be <= 3") }
                return (id, stars)
            }
        let levelIDs = Set(starRows.map { $0.0 })
        for id in expectedLevels where !levelIDs.contains(id) {
            throw DbError.Db(message: "player_meta_upgrade_level_stars[\(profile.rawValue):\(id)]: missing best_stars row")
        }
        guard levelIDs.count == starRows.count else {
            throw DbError.Db(message: "player_meta_upgrade_level_stars[\(profile.rawValue)]: duplicate level_info_id")
        }
        return try PlayerMetaUpgradeState(catalog: catalog, selected: Set(selectionRows.filter { $0.1 }.map { $0.0 }),
            bestStarsByLevel: Dictionary(uniqueKeysWithValues: starRows), profile: profile)
    }

    private func change<T>(_ operation: (PlayerMetaUpgradeState) throws -> (PlayerMetaUpgradeState, T)) throws -> T {
        try transaction {
            let current = try read(profile: .active)
            let (updated, result) = try operation(current)
            if updated != current { try write(updated) }
            return result
        }
    }

    private func write(_ state: PlayerMetaUpgradeState) throws {
        for upgrade in MetaUpgrade.allCases {
            try updateRow("""
                UPDATE player_meta_upgrade_selection SET is_selected = ?
                WHERE profile_key = 'active' AND upgrade_key = ?
                """, value: state.loadout.selected.contains(upgrade) ? 1 : 0,
                key: upgrade.rawValue, entity: "player_meta_upgrade_selection")
        }
        for (level, stars) in state.bestStarsByLevel {
            try updateRow("""
                UPDATE player_meta_upgrade_level_stars SET best_stars = ?
                WHERE profile_key = 'active' AND level_info_id = ?
                """, value: stars, key: level.uuidString.lowercased(), entity: "player_meta_upgrade_level_stars")
        }
        guard try read(profile: .active) == state else {
            throw DbError.Db(message: "player_meta_upgrade_selection: stored state differs from requested update")
        }
    }

    private func updateRow(_ sql: String, value: Int, key: String, entity: String) throws {
        var statement: OpaquePointer?
        try prepare(conn: conn, stmt: &statement, sql: sql)
        defer { sqlite3_finalize(statement) }
        try bindParam(statement, index: 1, value: value)
        try bindParam(statement, index: 2, value: key)
        guard sqlite3_step(statement) == SQLITE_DONE, sqlite3_changes(conn) == 1 else {
            throw DbError.Db(message: "\(entity)[active:\(key)]: update failed: \(String(cString: sqlite3_errmsg(conn)))")
        }
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        try executeNonQuery(conn: conn, sql: "SAVEPOINT player_meta_upgrade_change")
        do {
            let result = try operation()
            try executeNonQuery(conn: conn, sql: "RELEASE player_meta_upgrade_change")
            return result
        } catch {
            try? executeNonQuery(conn: conn, sql: "ROLLBACK TO player_meta_upgrade_change")
            try? executeNonQuery(conn: conn, sql: "RELEASE player_meta_upgrade_change")
            throw error
        }
    }
}
