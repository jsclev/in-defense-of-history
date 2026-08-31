import Foundation
import CoreGraphics
import SQLite3

public class VirtualCanvasDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "virtual_canvas", loggerName: VirtualCanvasDAO.self)
    }

    public func get() throws -> VirtualCanvas {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                canvas_width,
                canvas_height,
                play_area_x,
                play_area_y,
                play_area_width,
                play_area_height,
                slot_width,
                slot_height,
                path_width,
                tower_menu_total_width,
                tower_menu_total_height,
                stats_view_width_fraction,
                stats_view_height_fraction,
                master_controls_width_fraction,
                master_controls_height_fraction,
                hero_bar_width_fraction,
                hero_bar_height_fraction,
                misc_view_width_fraction,
                misc_view_height_fraction
            FROM
                virtual_canvas
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            sqlite3_finalize(stmt)
            throw DbError.Db(message:"virtual_canvas table cannot be empty")
        }
        
        let canvasSize = CGSize(width: getDouble(stmt: stmt, colIndex: 0),
                                height: getDouble(stmt: stmt, colIndex: 1))
        let playAreaRect = CGRect(
            x: getDouble(stmt: stmt, colIndex: 2),
            y: getDouble(stmt: stmt, colIndex: 3),
            width: getDouble(stmt: stmt, colIndex: 4),
            height: getDouble(stmt: stmt, colIndex: 5)
        )
        let towerSlotSize = CGSize(width: getDouble(stmt: stmt, colIndex: 6),
                                   height: getDouble(stmt: stmt, colIndex: 7))
        let pathWidth = getDouble(stmt: stmt, colIndex: 8)
        let towerMenuTotalSize = CGSize(width: getDouble(stmt: stmt, colIndex: 9),
                                        height: getDouble(stmt: stmt, colIndex: 10))
        let statsViewSizeFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 11),
                                                      height: getDouble(stmt: stmt, colIndex: 12))
        let masterControlsSizeFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 13),
                                                       height: getDouble(stmt: stmt, colIndex: 14))
        let heroBarSizeFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 15),
                                                      height: getDouble(stmt: stmt, colIndex: 16))
        let miscViewSizeFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 17),
                                                       height: getDouble(stmt: stmt, colIndex: 18))
        
        let virtualCanvas = VirtualCanvas(size: canvasSize,
                                    playAreaRect: playAreaRect,
                                    pathWidth: pathWidth,
                                    towerSlotSize: towerSlotSize,
                                    towerMenuTotalSize: towerMenuTotalSize,
                                    statsViewSizeFraction: statsViewSizeFraction,
                                    masterControlsSizeFraction: masterControlsSizeFraction,
                                    heroBarSizeFraction: heroBarSizeFraction,
                                    miscViewSizeFraction: miscViewSizeFraction)

        let extraRow = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)

        guard !extraRow else {
            throw DbError.Db(message: "virtual_canvas has more than one row")
        }

        return virtualCanvas
    }
}
