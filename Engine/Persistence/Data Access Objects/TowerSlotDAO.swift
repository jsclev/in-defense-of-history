import Foundation
import CoreGraphics
import SQLite3

public class TowerSlotDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "tower_slot", loggerName: TowerSlotDAO.self)
    }
    
    public func getTowerSlotsFor(levelInfoId: UUID) throws -> [TowerSlot] {
        var towerSlots: [TowerSlot] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                ts.id,
                ts.map_position_x,
                ts.map_position_y,
                ts.slot_width,
                ts.slot_height
            FROM
                tower_slot ts
            WHERE
                ts.level_info_id = ?
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let towerSlotId = try getUUID(stmt: stmt, colIndex: 0, msg: "tower slot id")
            
            let map_position_x = getDouble(stmt: stmt, colIndex: 1)
            let map_position_y = getDouble(stmt: stmt, colIndex: 2)
            let position = Point(map_position_x, map_position_y)
            let size = CGSize(width: getDouble(stmt: stmt, colIndex: 3),
                              height: getDouble(stmt: stmt, colIndex: 4))

            towerSlots.append(TowerSlot(id: towerSlotId, position: position, size: size))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return towerSlots
    }
}
