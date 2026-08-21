import Foundation
import CoreGraphics
import SQLite3

public class CanvasSpecDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "canvas_spec", loggerName: CanvasSpecDAO.self)
    }

    public func get() throws -> CanvasSpec {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                d.canvas_width,
                d.canvas_height,
                d.play_area_x,
                d.play_area_y,
                d.play_area_width,
                d.play_area_height,
                d.tower_slot_width,
                d.tower_slot_height,
                d.path_width,
                d.upper_left_occlusion_corner_width_fraction,
                d.upper_left_occlusion_corner_height_fraction,
                d.upper_right_occlusion_corner_width_fraction,
                d.upper_right_occlusion_corner_height_fraction,
                d.lower_left_occlusion_corner_width_fraction,
                d.lower_left_occlusion_corner_height_fraction,
                d.lower_right_occlusion_corner_width_fraction,
                d.lower_right_occlusion_corner_height_fraction
            FROM
                canvas_spec d
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            sqlite3_finalize(stmt)
            throw DbError.Db(message:"canvas_spec table cannot be empty")
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
        let upperLeftOcclusionCornerFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 9),
                                                      height: getDouble(stmt: stmt, colIndex: 10))
        let upperRightOcclusionCornerFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 11),
                                                       height: getDouble(stmt: stmt, colIndex: 12))
        let lowerLeftOcclusionCornerFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 13),
                                                      height: getDouble(stmt: stmt, colIndex: 14))
        let lowerRightOcclusionCornerFraction = CGSize(width: getDouble(stmt: stmt, colIndex: 15),
                                                       height: getDouble(stmt: stmt, colIndex: 16))
        
        let canvasSpec = CanvasSpec(size: canvasSize,
                                    playAreaRect: playAreaRect,
                                    pathWidth: pathWidth,
                                    towerSlotSize: towerSlotSize,
                                    upperLeftOcclusionCornerFraction: upperLeftOcclusionCornerFraction,
                                    upperRightOcclusionCornerFraction: upperRightOcclusionCornerFraction,
                                    lowerLeftOcclusionCornerFraction: lowerLeftOcclusionCornerFraction,
                                    lowerRightOcclusionCornerFraction: lowerRightOcclusionCornerFraction)

        let extraRow = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)

        guard !extraRow else {
            throw DbError.Db(message: "canvas_spec has more than one row")
        }

        return canvasSpec
    }
}
