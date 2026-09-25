import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelStartingMoneyTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func levelIDs(_ fixture: AuthoredDatabaseFixture) throws -> [UUID] {
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(fixture.connection,
            "SELECT id FROM level_info ORDER BY id", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var ids: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            ids.append(try XCTUnwrap(UUID(uuidString: String(cString: sqlite3_column_text(statement, 0)))))
        }
        return ids
    }

    func testEveryAuthoredLevelHasItsOwnDatabaseBudgetAndEditsReachDAO() throws {
        let fixture = try fixture()
        let ids = try levelIDs(fixture)
        XCTAssertEqual(ids.count, 41)
        for (index, id) in ids.enumerated() {
            XCTAssertGreaterThan(try fixture.db.levelInfoDao.getBy(id: id).startingMoney, 0)
            let revised = 731 + index
            try execute("UPDATE level_info SET starting_money=\(revised) WHERE id='\(id.uuidString.lowercased())'", fixture)
            XCTAssertEqual(try fixture.db.levelInfoDao.getBy(id: id).startingMoney, revised)
        }
    }

    func testCharlestonUsesAuthored670CoinBudget() throws {
        let fixture = try fixture()
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        XCTAssertEqual(try fixture.db.levelInfoDao.getBy(id: id).startingMoney, 670)
        XCTAssertEqual(try fixture.db.levelLoader.load(id: id).startingMoney, 670)
    }

    @MainActor func testDatabaseEditReachesReloadAndSimulationWithoutReadingMapGold() throws {
        let fixture = try fixture()
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        for money in [617, 943, Int(Int32.max) + 11] {
            try execute("UPDATE level_info SET starting_money=\(money) WHERE id='\(id.uuidString.lowercased())'", fixture)
            // The map's legacy editor metadata still says 500. Neither a
            // first load nor a subsequent load may use it or cache the budget.
            for _ in 0..<2 {
                let level = try fixture.db.levelLoader.load(id: id)
                XCTAssertEqual(level.startingMoney, money)
                XCTAssertEqual(try GameSimulation(recording: .preview, content: BattleContent(db: fixture.db, levelID: id),
                    startingMoney: nil, heroesEnabled: false, seed: 1776).gold, money)
            }
        }
    }

    func testSchemaRejectsMissingMalformedAndNonpositiveStartingMoney() throws {
        let fixture = try fixture()
        for invalid in ["NULL", "'invalid'", "1.5", "0", "-1", "X'1234'"] {
            XCTAssertEqual(sqlite3_exec(fixture.connection,
                "UPDATE level_info SET starting_money=\(invalid)", nil, nil, nil), SQLITE_CONSTRAINT, invalid)
        }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(fixture.connection,
            "SELECT dflt_value FROM pragma_table_info('level_info') WHERE name='starting_money'",
            -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_type(statement, 0), SQLITE_NULL)
    }

    func testDAORejectsCorruptValuesWithRecordAndFieldDiagnostics() throws {
        let fixture = try fixture()
        let id = try XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        // Remove constraints only in disposable memory to exercise the reader.
        try execute("""
            PRAGMA foreign_keys=OFF;
            CREATE TABLE corrupted_level_info AS SELECT * FROM level_info;
            DROP TABLE level_info;
            ALTER TABLE corrupted_level_info RENAME TO level_info;
            """, fixture)
        for invalid in ["NULL", "'invalid'", "1.5", "0", "-1", "X'1234'", "1e999"] {
            try execute("UPDATE level_info SET starting_money=\(invalid) WHERE id='\(id.uuidString.lowercased())'", fixture)
            XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(id: id), invalid) {
                let message = String(describing: $0)
                XCTAssertTrue(message.contains(id.uuidString.lowercased()), message)
                XCTAssertTrue(message.contains("starting_money"), message)
            }
            XCTAssertThrowsError(try fixture.db.levelLoader.load(id: id), invalid)
        }
        try execute("DELETE FROM level_info WHERE id='\(id.uuidString.lowercased())'", fixture)
        XCTAssertThrowsError(try fixture.db.levelLoader.load(id: id)) {
            XCTAssertTrue(String(describing: $0).contains(id.uuidString.lowercased()))
        }
        try execute("ALTER TABLE level_info DROP COLUMN starting_money", fixture)
        XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(id: id)) {
            XCTAssertTrue(String(describing: $0).contains("starting_money"))
        }
        XCTAssertNil(sqlite3_next_stmt(fixture.connection, nil), "Failed reads must release their statements")
    }
}
