import Foundation
import SQLite3

public class TowerTypeDAO: BaseDAO {
    private let meleeUnitDao: MeleeUnitDAO

    init(conn: OpaquePointer?, meleeUnitDao: MeleeUnitDAO) {
        self.meleeUnitDao = meleeUnitDao
        super.init(conn: conn, table: "tower_type", loggerName: TowerTypeDAO.self)
    }

    public func getCostsByLevel() throws -> [String: [Int: [Int: Int]]] {
        var costs: [String: [Int: [Int: Int]]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                t.branch,
                t.cost
            FROM
                tower t
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let category = try getString(stmt: stmt, colIndex: 0) {
                let level = getInt(stmt: stmt, colIndex: 1)
                let branch = getInt(stmt: stmt, colIndex: 2)
                costs[category, default: [:]][level, default: [:]][branch] =
                    getInt(stmt: stmt, colIndex: 3)
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return costs
    }

    public func getNamesByLevel() throws -> [String: [Int: [Int: String]]] {
        var names: [String: [Int: [Int: String]]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                t.branch,
                t.tower_name
            FROM
                tower t
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let category = try getString(stmt: stmt, colIndex: 0),
               let name = try getString(stmt: stmt, colIndex: 3) {
                let level = getInt(stmt: stmt, colIndex: 1)
                let branch = getInt(stmt: stmt, colIndex: 2)
                names[category, default: [:]][level, default: [:]][branch] = name
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return names
    }

    private typealias TowerLevelRow =
        (category: String, level: Int, branch: Int, tuning: TowerLevel)

    /// Every tuning row in the tower table. The two public accessors below
    /// shape this; the column list lives here once so the two can't drift.
    private func getTowerLevelRows() throws -> [TowerLevelRow] {
        var rows: [TowerLevelRow] = []
        let meleeByTowerId = try meleeUnitDao.getStatsByTowerId()

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                t.branch,
                t.cost,
                t.tower_range,
                t.fire_interval,
                t.shot_min_damage,
                t.shot_max_damage,
                t.terror_min,
                t.terror_max,
                t.aoe_radius,
                t.aoe_falloff_exponent,
                t.splash_cover_pierce,
                t.contagion_chance,
                t.targeting,
                t.projectile_speed,
                t.id
            FROM
                tower t
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let category = try getString(stmt: stmt, colIndex: 0) else { continue }
            let targeting = Targeting(rawValue: (try getString(stmt: stmt, colIndex: 14)) ?? "first") ?? .first
            let towerId = try getUUID(stmt: stmt, colIndex: 16, msg: "tower id")
            let tuning = TowerLevel(
                cost: getInt(stmt: stmt, colIndex: 3),
                range: getDouble(stmt: stmt, colIndex: 4),
                fireInterval: getDouble(stmt: stmt, colIndex: 5),
                shotMinDamage: getDouble(stmt: stmt, colIndex: 6),
                shotMaxDamage: getDouble(stmt: stmt, colIndex: 7),
                terrorMin: getDouble(stmt: stmt, colIndex: 8),
                terrorMax: getDouble(stmt: stmt, colIndex: 9),
                aoeRadius: getDouble(stmt: stmt, colIndex: 10),
                aoeFalloffExponent: getDouble(stmt: stmt, colIndex: 11),
                splashCoverPierce: getDouble(stmt: stmt, colIndex: 12),
                contagionChance: getDouble(stmt: stmt, colIndex: 13),
                targeting: targeting,
                projectileSpeed: getDouble(stmt: stmt, colIndex: 15),
                meleeUnit: meleeByTowerId[towerId]
            )
            rows.append((category,
                         getInt(stmt: stmt, colIndex: 1),
                         getInt(stmt: stmt, colIndex: 2),
                         tuning))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        // A melee category with a stats-less level would freeze its garrison
        // mid-fight (engine) or feed zeroed stats to the GPU kernel; fail at
        // load instead so the missing melee_unit row is caught immediately.
        let meleeCategories = Set(rows.filter { $0.tuning.meleeUnit != nil }.map { $0.category })
        for category in meleeCategories {
            let missing = rows.filter { $0.category == category && $0.tuning.meleeUnit == nil }
            if !missing.isEmpty {
                throw DbError.Db(message: "tower_type '\(category)' has melee_unit rows for "
                    + "some tower levels but not others; every level of a melee tower "
                    + "needs a melee_unit row")
            }
        }

        return rows
    }

    /// Branch 1 only, ordered by level — the upgrade spine, for callers that
    /// don't model branching.
    public func getTowerLevels() throws -> [String: [TowerLevel]] {
        var levels: [String: [(Int, TowerLevel)]] = [:]

        for row in try getTowerLevelRows() where row.branch == 1 {
            levels[row.category, default: []].append((row.level, row.tuning))
        }

        return levels.mapValues { $0.sorted { $0.0 < $1.0 }.map { $0.1 } }
    }

    /// Keyed category → level → branch, so a caller holding a placed tower's
    /// level and branch can read that tower's exact tuning row.
    public func getTowerLevelsByBranch() throws -> [String: [Int: [Int: TowerLevel]]] {
        var levels: [String: [Int: [Int: TowerLevel]]] = [:]

        for row in try getTowerLevelRows() {
            levels[row.category, default: [:]][row.level, default: [:]][row.branch] = row.tuning
        }

        return levels
    }

    /// Every tower type as the engine models it, keyed by `tower_type_category`:
    /// real database id, display name and the branch-1 upgrade spine.
    ///
    /// Keyed by category because that is the join key callers hold - the editor's
    /// `Emplacement` raw values are exactly these category strings.
    ///
    /// This is what a ContentCatalog needs. `DesignArsenal` used to carry a
    /// hardcoded copy of the same numbers, under its own invented UUIDs, and it
    /// had drifted from the tower table - tier-1 range read 140 there against
    /// 150 here.
    public func getTowerTypes() throws -> [String: TowerType] {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.id,
                tt.tower_type_category,
                tt.tower_type_name
            FROM
                tower_type tt
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        var identities: [(id: UUID, category: String, name: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let category = try getString(stmt: stmt, colIndex: 1),
                  let name = try getString(stmt: stmt, colIndex: 2) else { continue }
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "tower_type id")
            identities.append((id, category, name))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        let levelsByCategory = try getTowerLevels()
        var byCategory: [String: TowerType] = [:]
        for identity in identities {
            guard let levels = levelsByCategory[identity.category], !levels.isEmpty else { continue }
            byCategory[identity.category] = TowerType(id: identity.id,
                                                      name: identity.name,
                                                      levels: levels)
        }
        return byCategory
    }

    public func getDisplayNames() throws -> [String: String] {
        var names: [String: String] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                tt.tower_type_name
            FROM
                tower_type tt
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let category = try getString(stmt: stmt, colIndex: 0),
               let name = try getString(stmt: stmt, colIndex: 1) {
                names[category] = name
            }
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return names
    }
}
