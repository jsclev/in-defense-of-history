import Foundation
import SQLite3

public class TowerTypeDAO: BaseDAO {
    init(conn: OpaquePointer?) {
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

    /// Branch-1 combat stats per category and tower level, in tower_level
    /// order — the designer's fixed baseline the simulator reads and may only
    /// nudge with small per-level modifiers.
    public func getTowerLevels() throws -> [String: [TowerLevel]] {
        var levels: [String: [(Int, TowerLevel)]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                tt.tower_type_category,
                t.tower_level,
                t.cost,
                t.tower_range,
                t.fire_interval,
                t.shot_min,
                t.shot_max,
                t.terror_min,
                t.terror_max,
                t.aoe_radius,
                t.aoe_falloff_exponent,
                t.splash_cover_pierce,
                t.contagion_chance,
                t.targeting,
                t.projectile_speed,
                t.unit_count,
                t.unit_hp,
                t.unit_damage_min,
                t.unit_damage_max,
                t.unit_attack_interval,
                t.unit_respawn_seconds,
                t.unit_heal_per_second
            FROM
                tower t
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
            WHERE
                t.branch = 1
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let category = try getString(stmt: stmt, colIndex: 0) else { continue }
            let targeting = Targeting(rawValue: (try getString(stmt: stmt, colIndex: 13)) ?? "first") ?? .first
            let level = TowerLevel(
                cost: getInt(stmt: stmt, colIndex: 2),
                range: getDouble(stmt: stmt, colIndex: 3),
                fireInterval: getDouble(stmt: stmt, colIndex: 4),
                shotMin: getDouble(stmt: stmt, colIndex: 5),
                shotMax: getDouble(stmt: stmt, colIndex: 6),
                terrorMin: getDouble(stmt: stmt, colIndex: 7),
                terrorMax: getDouble(stmt: stmt, colIndex: 8),
                aoeRadius: getDouble(stmt: stmt, colIndex: 9),
                aoeFalloffExponent: getDouble(stmt: stmt, colIndex: 10),
                splashCoverPierce: getDouble(stmt: stmt, colIndex: 11),
                contagionChance: getDouble(stmt: stmt, colIndex: 12),
                targeting: targeting,
                projectileSpeed: getDouble(stmt: stmt, colIndex: 14),
                meleeUnitCount: getInt(stmt: stmt, colIndex: 15),
                meleeUnitHP: getDouble(stmt: stmt, colIndex: 16),
                meleeUnitDamageMin: getDouble(stmt: stmt, colIndex: 17),
                meleeUnitDamageMax: getDouble(stmt: stmt, colIndex: 18),
                meleeUnitAttackInterval: getDouble(stmt: stmt, colIndex: 19),
                meleeUnitRespawnSeconds: getDouble(stmt: stmt, colIndex: 20),
                meleeUnitHealPerSecond: getDouble(stmt: stmt, colIndex: 21)
            )
            levels[category, default: []].append((getInt(stmt: stmt, colIndex: 1), level))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return levels.mapValues { $0.sorted { $0.0 < $1.0 }.map { $0.1 } }
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
