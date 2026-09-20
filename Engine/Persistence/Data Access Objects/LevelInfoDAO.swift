import Foundation
import CoreGraphics
import SQLite3

public class LevelInfoDAO: BaseDAO {
    /// Database metadata only. LevelLoader assembles the playable level.
    public struct Record {
        public let id: UUID
        public let name: String
        public let campaign: Campaign
        public let startedAt: Date
        public let endedAt: Date
        public let startingMoney: Int
        public let numStartingLives: Int
        public let numWaves: Int
        public let playArea: CGRect
        public let mapImageName: String
    }

    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "level_info", loggerName: LevelInfoDAO.self)
    }

    public func getIdBy(levelName: String) throws -> UUID? {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                l.id
            FROM
                level_info l
            WHERE
                l.level_name = ?
            ORDER BY
                l.id
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelName, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level name")
        }

        var id: UUID?
        if sqlite3_step(stmt) == SQLITE_ROW {
            id = try getUUID(stmt: stmt, colIndex: 0, msg: "level info id")
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return id
    }

    /// Native map documents use either the authored display name or asset key.
    /// Resolve only exact identities; an ambiguous or missing level is an error.
    public func getIdForEditorDocument(named name: String) throws -> UUID {
        var statement: OpaquePointer?
        try prepare(conn: conn, stmt: &statement,
                    sql: "SELECT id FROM level_info WHERE level_name = ? OR map_image_name = ?")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT) == SQLITE_OK,
              sqlite3_bind_text(statement, 2, name, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind editor level identity")
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DbError.Db(message: "level_info: no authored level for editor document '\(name)'")
        }
        let id = try getUUID(stmt: statement, colIndex: 0, msg: "editor level id")
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DbError.Db(message: "level_info: ambiguous editor document '\(name)'")
        }
        return id
    }

    public func getCampaignLevels(campaignName: String) throws -> [CampaignLevel] {
        var levels: [CampaignLevel] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                l.id,
                l.level_name,
                l.world_map_x,
                l.world_map_y,
                l.map_image_name
            FROM
                level_info l
            INNER JOIN
                campaign c ON c.id = l.campaign_id
            WHERE
                c.campaign_name = ?
            ORDER BY
                l.started_at
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, campaignName, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind campaign name")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "level info id")

            guard let name = try getString(stmt: stmt, colIndex: 1) else {
                throw DbError.Db(message: "level_info row \(id.uuidString.lowercased()) has a null level_name.")
            }

            levels.append(CampaignLevel(
                id: id,
                name: name,
                worldMapPosition: CGPoint(x: getDouble(stmt: stmt, colIndex: 2),
                                          y: getDouble(stmt: stmt, colIndex: 3)),
                mapImageName: (try getString(stmt: stmt, colIndex: 4)) ?? ""
            ))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return levels
    }

    public func getBy(id: UUID) throws -> Record {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                l.id AS level_info_id,
                l.level_name,
                strftime('%Y-%m-%dT%H:%M:%SZ', l.started_at) AS started_at,
                strftime('%Y-%m-%dT%H:%M:%SZ', l.ended_at) AS ended_at,
                l.starting_money,
                l.num_starting_lives,
                c.id AS campaign_id,
                c.campaign_name,
                d.play_area_x,
                d.play_area_y,
                d.play_area_width,
                d.play_area_height,
                l.map_image_name,
                l.num_waves
            FROM
                level_info l
            INNER JOIN
                campaign c ON c.id = l.campaign_id
            CROSS JOIN
                virtual_canvas d
            WHERE
                l.id = ?
        """)
        
        try prepare(conn: conn, stmt: &stmt, sql: sql)
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_bind_text(stmt, 1, id.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }
        
        if sqlite3_step(stmt) == SQLITE_ROW {

            if let levelName = try getString(stmt: stmt, colIndex: 1),
               let campaignName = try getString(stmt: stmt, colIndex: 7) {
                let levelInfoId = try getUUID(stmt: stmt, colIndex: 0, msg: "level info id")
                let campaignId = try getUUID(stmt: stmt, colIndex: 6, msg: "campaign id")

                let startedAt = try getDate(stmt: stmt, colIndex: 2)
                let endedAt = try getDate(stmt: stmt, colIndex: 3)
                // This is the sole campaign starting-money read. SQLite's
                // numeric conversions otherwise turn NULL/text into zero or
                // truncate fractions and values larger than a 32-bit integer.
                guard sqlite3_column_type(stmt, 4) == SQLITE_INTEGER,
                      let startingMoney = Int(exactly: sqlite3_column_int64(stmt, 4)),
                      startingMoney > 0 else {
                    throw DbError.Db(message: "level_info row \(levelInfoId.uuidString.lowercased()) (\(levelName)) field starting_money must be a positive integer.")
                }
                let numStartingLives = getInt(stmt: stmt, colIndex: 5)
                let playArea = CGRect(
                    x: getDouble(stmt: stmt, colIndex: 8),
                    y: getDouble(stmt: stmt, colIndex: 9),
                    width: getDouble(stmt: stmt, colIndex: 10),
                    height: getDouble(stmt: stmt, colIndex: 11)
                )

                let mapImageName = (try getString(stmt: stmt, colIndex: 12)) ?? ""
                let numWaves = getInt(stmt: stmt, colIndex: 13)

                return Record(id: levelInfoId,
                                 name: levelName,
                                 campaign: Campaign(id: campaignId, name: campaignName),
                                 startedAt: startedAt,
                                 endedAt: endedAt,
                                 startingMoney: startingMoney,
                                 numStartingLives: numStartingLives,
                                 numWaves: numWaves,
                                 playArea: playArea,
                                 mapImageName: mapImageName)
            }
        }
        
        throw DbError.Db(message: "No level info with id = \(id.uuidString.lowercased()).")
    }

}
