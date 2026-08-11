import Foundation
import SQLite3

public class DifficultyDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "difficulty", loggerName: DifficultyDAO.self)
    }

    public func getAll() throws -> [Difficulty] {
        var difficulties: [Difficulty] = []

        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                d.id,
                d.difficulty_level,
                d.difficulty_name,
                d.difficulty_description,
                d.enemy_hp_multiplier
            FROM
                difficulty d
            ORDER BY
                d.difficulty_level
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "difficulty id")

            guard let name = try getString(stmt: stmt, colIndex: 2) else {
                throw DbError.Db(message: "difficulty row \(id.uuidString.lowercased()) has a null name.")
            }

            difficulties.append(Difficulty(
                id: id,
                level: getInt(stmt: stmt, colIndex: 1),
                name: name,
                detail: (try getString(stmt: stmt, colIndex: 3)) ?? "",
                enemyHPMultiplier: getDouble(stmt: stmt, colIndex: 4)
            ))
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return difficulties
    }

    public func getSelected() throws -> Difficulty? {
        var stmt: OpaquePointer?
        let sql = getCleanedSql("""
            SELECT
                d.id,
                d.difficulty_level,
                d.difficulty_name,
                d.difficulty_description,
                d.enemy_hp_multiplier
            FROM
                player_selected_difficulty psd
            INNER JOIN
                difficulty d ON psd.difficulty_id = d.id
            ORDER BY
                psd.selection_slot
        """)

        try prepare(conn: conn, stmt: &stmt, sql: sql)

        var selected: Difficulty?
        if sqlite3_step(stmt) == SQLITE_ROW {
            let id = try getUUID(stmt: stmt, colIndex: 0, msg: "difficulty id")

            guard let name = try getString(stmt: stmt, colIndex: 2) else {
                throw DbError.Db(message: "difficulty row \(id.uuidString.lowercased()) has a null name.")
            }

            selected = Difficulty(
                id: id,
                level: getInt(stmt: stmt, colIndex: 1),
                name: name,
                detail: (try getString(stmt: stmt, colIndex: 3)) ?? "",
                enemyHPMultiplier: getDouble(stmt: stmt, colIndex: 4)
            )
        }

        sqlite3_finalize(stmt)
        stmt = nil

        return selected
    }

    public func setSelected(difficultyID: UUID) throws {
        try executeNonQuery(conn: conn, sql: "DELETE FROM player_selected_difficulty;")

        var stmt: OpaquePointer?
        let sql = """
            INSERT INTO player_selected_difficulty (id, difficulty_id, selection_slot)
            VALUES (?, ?, 1);
        """

        try prepare(conn: conn, stmt: &stmt, sql: sql)
        try bindParam(stmt, index: 1, value: UUID().uuidString.lowercased())
        try bindParam(stmt, index: 2, value: difficultyID.uuidString.lowercased())
        try insertOneRow(conn: conn, stmt: &stmt)
    }
}
