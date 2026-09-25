import Foundation
import SQLite3

public struct EncyclopediaDemoSettings {
    public let contextLevelID: UUID
    public let startingMoney: Int
}

public final class EncyclopediaDemoDAO: BaseDAO {
    init(conn: OpaquePointer?) {
        super.init(conn: conn, table: "encyclopedia_demo", loggerName: EncyclopediaDemoDAO.self)
    }

    public func get() throws -> EncyclopediaDemoSettings {
        var statement: OpaquePointer?
        try prepare(conn: conn, stmt: &statement, sql:
            "SELECT context_level_id, starting_money FROM encyclopedia_demo WHERE id = 1")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw DbError.Db(message: "encyclopedia_demo[1]: missing required record")
        }
        guard let raw = try getString(stmt: statement, colIndex: 0), let id = UUID(uuidString: raw) else {
            throw DbError.Db(message: "encyclopedia_demo[1].context_level_id: expected a UUID")
        }
        guard sqlite3_column_type(statement, 1) == SQLITE_INTEGER,
              sqlite3_column_int64(statement, 1) > 0,
              sqlite3_column_int64(statement, 1) <= Int32.max else {
            throw DbError.Db(message: "encyclopedia_demo[1].starting_money: expected a positive integer")
        }
        return EncyclopediaDemoSettings(contextLevelID: id,
                                         startingMoney: getInt(stmt: statement, colIndex: 1))
    }
}
