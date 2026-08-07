import Foundation
import SQLite3

public class CampaignDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "campaign", loggerName: CampaignDAO.self)
    }
    
//    public func getBy(id: UUID) throws -> LevelInfo {
//        var stmt: OpaquePointer?
//        let sql = getCleanedSql("""
//            SELECT
//                c.city_id,
//                c.player_id,
//                c.name,
//                c.tile_id,
//                t.row,
//                t.col
//            FROM
//                city c
//            INNER JOIN
//                player p ON p.player_id = c.player_id
//            INNER JOIN
//                tile t ON t.tile_id = c.tile_id
//            WHERE
//                c.city_id = ?
//        """)
//
//        try prepare(conn: conn, stmt: &stmt, sql: sql)
//        try bindParam(stmt, index: 1, value: id.lowercaseString)
//
//        if sqlite3_step(stmt) == SQLITE_ROW {
//            if let name = try getString(stmt: stmt, colIndex: 2) {
//                let row = getInt(stmt: stmt, colIndex: 4)
//                let col = getInt(stmt: stmt, colIndex: 5)
//
//                sqlite3_finalize(stmt)
//                stmt = nil
//
//                return City(id: id,
//                            publicGameState: publicGameState,
//                            owner: player,
//                            name: name,
//                            theme: theme,
//                            position: Position(row: row, col: col),
//                            logLevel: LogLevel.One)
//            }
//        }
//
//        sqlite3_finalize(stmt)
//        stmt = nil
//
//        throw DbError.Db(message: "No city with city_id = \(id).")
//    }
    
//    public func getBy(name: String) throws -> Campaign {
//        var stmt: OpaquePointer?
//        let sql = getCleanedSql("""
//            SELECT
//                l.id,
//                l.level_name,
//                strftime('%Y-%m-%dT%H:%M:%SZ', l.started_at) AS started_at,
//                strftime('%Y-%m-%dT%H:%M:%SZ', l.ended_at) AS ended_at,
//                l.starting_money,
//                l.num_starting_lives
//            FROM
//                level_info l
//            INNER JOIN
//                campaign c ON c.id = l.campaign_id
//            WHERE
//                l.level_name = ?
//        """)
//        
//        try prepare(conn: conn, stmt: &stmt, sql: sql)
//        try bindParam(stmt, index: 1, value: name)
//        
//        if sqlite3_step(stmt) == SQLITE_ROW {
//            let levelInfoId = try getUUID(stmt: stmt, colIndex: 0, msg: "level info id")
//
//            if let name = try getString(stmt: stmt, colIndex: 1) {
//                let startedAt = try getDate(stmt: stmt, colIndex: 2)
//                let endedAt = try getDate(stmt: stmt, colIndex: 3)
//                let startingMoney = getInt(stmt: stmt, colIndex: 4)
//                let numStartingLives = getInt(stmt: stmt, colIndex: 5)
//
//                sqlite3_finalize(stmt)
//                stmt = nil
//
//                return LevelInfo(id: levelInfoId,
//                                 name: name,
//                                 startedAt: startedAt,
//                                 endedAt: endedAt,
//                                 startingMoney: startingMoney,
//                                 numStartingLives: numStartingLives,
//                                 paths: [],
//                                 towerSlots: [],
//                                 waves: [])
//            }
//        }
//        
//        sqlite3_finalize(stmt)
//        stmt = nil
//
//        throw DbError.Db(message: "No level info with name = \(name).")
//    }
    
//    public func insert(player: Player, name: String, tile: Tile, theme: Theme) throws -> CityDTO {
//        var stmt: OpaquePointer?
//        let cityId = UUID()
//        let sql = getCleanedSql("INSERT INTO city (city_id, player_id, name, tile_id) VALUES (?, ?, ?, ?)")
//
//        try prepare(conn: conn, stmt: &stmt, sql: sql)
//
//        try bindParam(stmt, index: 1, value: cityId.lowercaseString)
//        try bindParam(stmt, index: 2, value: player.id.lowercaseString)
//        try bindParam(stmt, index: 3, value: name)
//        try bindParam(stmt, index: 4, value: tile.id.lowercaseString)
//
//        try insertOneRow(conn: conn, stmt: stmt)
//
//        return CityDTO(id: cityId,
//                       owner: player,
//                       name: name,
//                       theme: theme,
//                       position: tile.position)
//    }
    
//    public func getCities(gameId: UUID, publicGameState: PublicGameState, players: [Player]) throws -> Set<City> {
//        var cities: Set<City> = []
//
//        var stmt: OpaquePointer?
//        let sql = getCleanedSql("""
//            SELECT
//                c.city_id,
//                c.player_id,
//                c.name,
//                c.tile_id,
//                t.row,
//                t.col
//            FROM
//                city c
//            INNER JOIN
//                player p ON p.player_id = c.player_id
//            INNER JOIN
//                tile t ON t.tile_id = c.tile_id
//            WHERE
//                p.game_id = ?
//        """)
//
//        try prepare(conn: conn, stmt: &stmt, sql: sql)
//
//        guard sqlite3_bind_text(stmt, 1, gameId.lowercaseString, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
//            throw DbError.Db(message: "Unable to bind game id")
//        }
//
//        while sqlite3_step(stmt) == SQLITE_ROW {
//            let cityId = try getUUID(stmt: stmt, colIndex: 0, msg: "city id")
//            let row = getInt(stmt: stmt, colIndex: 4)
//            let col = getInt(stmt: stmt, colIndex: 5)
//            let playerId = try getUUID(stmt: stmt, colIndex: 1, msg: "player id")
//
//            if let cityName = try getString(stmt: stmt, colIndex: 2) {
//                if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
//                    cities.insert(City(id: cityId,
//                                       publicGameState: publicGameState,
//                                       owner: players[playerIndex],
//                                       name: cityName,
//                                       theme: Theme(name: "Standard"),
//                                       position: Position(row: row, col: col),
//                                       logLevel: LogLevel.One))
//                }
//            }
//        }
//
//        sqlite3_finalize(stmt)
//        stmt = nil
//
//        return cities
//    }
}
