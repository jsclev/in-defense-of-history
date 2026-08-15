import Foundation
import CoreGraphics
import SQLite3

public class CanvasSpecDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "canvas_spec", loggerName: CanvasSpecDAO.self)
    }

    /// The canvas_spec row. Exactly one must exist; zero means the database
    /// predates the table (rebuild with Db/create_db.sh) and more than one
    /// means the seed DML ran twice.
    public func get() throws -> CanvasSpecValues {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                d.canvas_width,
                d.canvas_height,
                d.play_area_x,
                d.play_area_y,
                d.play_area_width,
                d.play_area_height,
                d.slot_width,
                d.slot_height,
                d.path_width,
                d.occlusion_corner_width_fraction,
                d.occlusion_corner_height_fraction
            FROM
                canvas_spec d
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            sqlite3_finalize(stmt)
            throw DbError.Db(message:
                "canvas_spec is empty - rebuild the database with Db/create_db.sh")
        }

        let values = CanvasSpecValues(
            canvasWidth: getDouble(stmt: stmt, colIndex: 0),
            canvasHeight: getDouble(stmt: stmt, colIndex: 1),
            playArea: CGRect(
                x: getDouble(stmt: stmt, colIndex: 2),
                y: getDouble(stmt: stmt, colIndex: 3),
                width: getDouble(stmt: stmt, colIndex: 4),
                height: getDouble(stmt: stmt, colIndex: 5)
            ),
            slotSize: CGSize(width: getDouble(stmt: stmt, colIndex: 6),
                             height: getDouble(stmt: stmt, colIndex: 7)),
            pathWidth: getDouble(stmt: stmt, colIndex: 8),
            occlusionCornerFraction: CGSize(width: getDouble(stmt: stmt, colIndex: 9),
                                            height: getDouble(stmt: stmt, colIndex: 10))
        )

        let extraRow = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        stmt = nil

        guard !extraRow else {
            throw DbError.Db(message: "canvas_spec has more than one row")
        }

        return values
    }
}
