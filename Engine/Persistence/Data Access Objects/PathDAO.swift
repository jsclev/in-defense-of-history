import Foundation
import SQLite3

public class PathDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "level_path_point", loggerName: PathDAO.self)
    }

    public func getPathsFor(levelInfoId: UUID) throws -> [Path] {
        var pointsByPath: [Int: [Point]] = [:]

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                lpp.path_index,
                lpp.point_index,
                lpp.map_position_x,
                lpp.map_position_y
            FROM
                level_path_point lpp
            WHERE
                lpp.level_info_id = ?
            ORDER BY
                lpp.path_index,
                lpp.point_index
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        guard sqlite3_bind_text(stmt, 1, levelInfoId.uuidString.lowercased(), -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DbError.Db(message: "Unable to bind level info id")
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let pathIndex = getInt(stmt: stmt, colIndex: 0)
            let x = getDouble(stmt: stmt, colIndex: 2)
            let y = getDouble(stmt: stmt, colIndex: 3)
            pointsByPath[pathIndex, default: []].append(Point(x, y))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        guard !pointsByPath.isEmpty else { return [] }

        let maxIndex = pointsByPath.keys.max() ?? -1
        var paths: [Path] = []
        for index in 0...maxIndex {
            guard let points = pointsByPath[index] else {
                throw DbError.Db(message: "Level \(levelInfoId.uuidString.lowercased()) is missing path_index \(index) (paths must be contiguous from 0).")
            }
            guard points.count >= 2 else {
                throw DbError.Db(message: "Level \(levelInfoId.uuidString.lowercased()) path_index \(index) has \(points.count) point(s); a path needs at least 2.")
            }
            paths.append(Path(points: points))
        }

        return paths
    }
}
