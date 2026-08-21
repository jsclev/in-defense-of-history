import Foundation
import CoreGraphics
import SQLite3

public class LevelInfoDAO: BaseDAO {
    private let towerSlotDao: TowerSlotDAO
    private let pathDao: PathDAO
    private let waveDao: WaveDAO

    init(conn: OpaquePointer?, towerSlotDao: TowerSlotDAO, pathDao: PathDAO,
         waveDao: WaveDAO) {
        self.towerSlotDao = towerSlotDao
        self.pathDao = pathDao
        self.waveDao = waveDao

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

    public func getBy(id: UUID) throws -> LevelInfo {
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
                let startingMoney = getInt(stmt: stmt, colIndex: 4)
                let numStartingLives = getInt(stmt: stmt, colIndex: 5)
                let playArea = CGRect(
                    x: getDouble(stmt: stmt, colIndex: 8),
                    y: getDouble(stmt: stmt, colIndex: 9),
                    width: getDouble(stmt: stmt, colIndex: 10),
                    height: getDouble(stmt: stmt, colIndex: 11)
                )

                let mapImageName = (try getString(stmt: stmt, colIndex: 12)) ?? ""
                let numWaves = getInt(stmt: stmt, colIndex: 13)

                sqlite3_finalize(stmt)
                stmt = nil

                let towerSlots = try towerSlotDao.getTowerSlotsFor(levelInfoId: id)
                let paths = try pathDao.getPathsFor(levelInfoId: id)
                let waves = try waveDao.getWavesFor(levelInfoId: id)

                return LevelInfo(id: levelInfoId,
                                 name: levelName,
                                 campaign: Campaign(id: campaignId, name: campaignName),
                                 startedAt: startedAt,
                                 endedAt: endedAt,
                                 startingMoney: startingMoney,
                                 numStartingLives: numStartingLives,
                                 numWaves: numWaves,
                                 playArea: playArea,
                                 mapImageName: mapImageName,
                                 paths: paths,
                                 towerSlots: towerSlots,
                                 waves: waves)
            }
        }
        
        sqlite3_finalize(stmt)
        stmt = nil

        throw DbError.Db(message: "No level info with id = \(id.uuidString.lowercased()).")
    }

}
