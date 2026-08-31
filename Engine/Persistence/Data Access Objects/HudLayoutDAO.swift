import Foundation
import SQLite3

public class HudLayoutDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "player_hud_layout", loggerName: HudLayoutDAO.self)
    }

    public func get() throws -> HudLayoutConfig {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                phl.hud_section_name,
                phl.hud_location_name
            FROM
                player_hud_layout phl
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        var hudLocations: [HudSection: HudLocation] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let sectionName = try getString(stmt: stmt, colIndex: 0),
                  let hudSection = HudSection(rawValue: sectionName) else {
                sqlite3_finalize(stmt)
                throw DbError.Db(message: "player_hud_layout has an unrecognised hud_section_name.")
            }

            guard let locationName = try getString(stmt: stmt, colIndex: 1),
                  let hudLocation = HudLocation(rawValue: locationName) else {
                sqlite3_finalize(stmt)
                throw DbError.Db(message: "player_hud_layout has an unrecognised hud_location_name.")
            }

            hudLocations[hudSection] = hudLocation
        }

        sqlite3_finalize(stmt)
        stmt = nil

        guard let heroBar = hudLocations[.heroBar],
              let statsView = hudLocations[.statsView],
              let miscView = hudLocations[.miscView],
              let masterControls = hudLocations[.masterControls] else {
            throw DbError.Db(message: "player_hud_layout needs one row per HUD section.")
        }

        return HudLayoutConfig(heroBar: heroBar,
                               statsView: statsView,
                               miscView: miscView,
                               masterControls: masterControls)
    }

    public func set(hudLayoutConfig: HudLayoutConfig) throws {
        try executeNonQuery(conn: conn, sql: "DELETE FROM player_hud_layout;")

        let sql = """
            INSERT INTO player_hud_layout (id, hud_section_name, hud_location_name)
            VALUES (?, ?, ?);
        """

        for hudSection in HudSection.allCases {
            var stmt: OpaquePointer?
            try prepare(conn: conn, stmt: &stmt, sql: sql)
            try bindParam(stmt, index: 1, value: UUID().uuidString.lowercased())
            try bindParam(stmt, index: 2, value: hudSection.rawValue)
            try bindParam(stmt, index: 3,
                          value: hudLayoutConfig.location(of: hudSection).rawValue)
            try insertOneRow(conn: conn, stmt: &stmt)
        }
    }
}
