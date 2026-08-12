import Foundation
import SQLite3

public struct SimStatBounds {
    public var towerKind: String
    public var stat: String
    public var minValue: Double
    public var maxValue: Double
    public var derivedFrom: String
}

/// Inclusive integer range the sweep searches for one tower row.
public struct SimTowerRange: Sendable {
    public var towerID: UUID
    public var towerKind: String
    public var towerLevel: Int
    public var branch: Int
    public var minRange: Int
    public var maxRange: Int

    /// Every value the sweep will try: whole numbers, step 1, min through max.
    public var values: [Int] { Array(minRange...Swift.max(minRange, maxRange)) }
}

public class SimBoundsDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "sim_stat_bounds", loggerName: SimBoundsDAO.self)
    }

    public func getBoundsFor(levelInfoId: UUID) throws -> [String: [String: SimStatBounds]] {
        var out: [String: [String: SimStatBounds]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                b.tower_kind,
                b.stat,
                b.min_value,
                b.max_value,
                b.derived_from,
                b.level_info_id
            FROM
                sim_stat_bounds b
            WHERE
                b.level_info_id = ? OR b.level_info_id IS NULL
            ORDER BY
                b.level_info_id IS NULL DESC
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let kind = try getString(stmt: stmt, colIndex: 0),
                  let stat = try getString(stmt: stmt, colIndex: 1) else { continue }
            let bounds = SimStatBounds(
                towerKind: kind,
                stat: stat,
                minValue: getDouble(stmt: stmt, colIndex: 2),
                maxValue: getDouble(stmt: stmt, colIndex: 3),
                derivedFrom: (try getString(stmt: stmt, colIndex: 4)) ?? ""
            )
            out[kind, default: [:]][stat] = bounds
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return out
    }

    /// Range search bounds from sim_tower_range, one entry per tower row that
    /// has one, keyed category then tower level.
    ///
    /// A tower with no row is not swept over range: the sweep uses its own
    /// tower_range instead. That is how the search stays confined to the levels
    /// the table actually describes.
    public func getTowerRanges() throws -> [String: [Int: SimTowerRange]] {
        var out: [String: [Int: SimTowerRange]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                r.tower_id,
                tt.tower_type_category,
                t.tower_level,
                t.branch,
                r.min_range,
                r.max_range
            FROM
                sim_tower_range r
            INNER JOIN
                tower t ON t.id = r.tower_id
            INNER JOIN
                tower_type tt ON tt.id = t.tower_type_id
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let category = try getString(stmt: stmt, colIndex: 1) else { continue }
            let towerID = try getUUID(stmt: stmt, colIndex: 0, msg: "sim_tower_range tower_id")
            let level = getInt(stmt: stmt, colIndex: 2)
            out[category, default: [:]][level] = SimTowerRange(
                towerID: towerID,
                towerKind: category,
                towerLevel: level,
                branch: getInt(stmt: stmt, colIndex: 3),
                minRange: getInt(stmt: stmt, colIndex: 4),
                maxRange: getInt(stmt: stmt, colIndex: 5)
            )
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return out
    }

    public func upsert(
        levelInfoId: UUID?, towerKind: String, stat: String,
        minValue: Double, maxValue: Double, derivedFrom: String
    ) throws {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            INSERT INTO sim_stat_bounds
                (id, level_info_id, tower_kind, stat, min_value, max_value, derived_from)
            VALUES
                (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (level_info_id, tower_kind, stat) DO UPDATE SET
                min_value = excluded.min_value,
                max_value = excluded.max_value,
                derived_from = excluded.derived_from
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, UUID().uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK,
              (levelInfoId == nil
                ? sqlite3_bind_null(stmt, 2)
                : sqlite3_bind_text(stmt, 2, levelInfoId!.uuidString.lowercased(), -1, SQLITE_TRANSIENT)) == SQLITE_OK,
              sqlite3_bind_text(stmt, 3, towerKind, -1, SQLITE_TRANSIENT) == SQLITE_OK,
              sqlite3_bind_text(stmt, 4, stat, -1, SQLITE_TRANSIENT) == SQLITE_OK,
              sqlite3_bind_double(stmt, 5, minValue) == SQLITE_OK,
              sqlite3_bind_double(stmt, 6, maxValue) == SQLITE_OK,
              sqlite3_bind_text(stmt, 7, derivedFrom, -1, SQLITE_TRANSIENT) == SQLITE_OK
        else {
            throw DbError.Db(message: "Unable to bind sim_stat_bounds upsert")
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DbError.Db(message: "sim_stat_bounds upsert failed: \(String(cString: sqlite3_errmsg(conn)!))")
        }

        sqlite3_finalize(stmt)
        stmt = nil
    }
}
