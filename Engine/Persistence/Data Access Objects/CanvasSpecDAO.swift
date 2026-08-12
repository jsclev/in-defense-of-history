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
                d.playable_rect_x,
                d.playable_rect_y,
                d.playable_rect_width,
                d.playable_rect_height,
                d.slot_width,
                d.slot_height
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
            playableRect: CGRect(
                x: getDouble(stmt: stmt, colIndex: 2),
                y: getDouble(stmt: stmt, colIndex: 3),
                width: getDouble(stmt: stmt, colIndex: 4),
                height: getDouble(stmt: stmt, colIndex: 5)
            ),
            slotSize: CGSize(width: getDouble(stmt: stmt, colIndex: 6),
                             height: getDouble(stmt: stmt, colIndex: 7))
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
