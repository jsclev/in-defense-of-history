import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelNumberTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testAuthoredNumbersSupportBothExistingPaddingConventions() throws {
        let fixture = try AuthoredDatabaseFixture()
        for (number, name) in [(1, "Battle Road"), (2, "Bunker Hill"), (10, "Fort Ann"), (15, "Charleston")] {
            XCTAssertEqual(try fixture.db.levelInfoDao.getBy(number: number).name, name)
        }
        let ids = try (1...15).map { try fixture.db.levelInfoDao.getBy(number: $0).id }
        XCTAssertEqual(Set(ids).count, 15)
    }

    func testNumberUsesAuthoredIdentityAndReturnsDatabaseEdits() throws {
        let fixture = try AuthoredDatabaseFixture()
        let original = try fixture.db.levelInfoDao.getBy(number: 15)
        try execute("""
            UPDATE level_info SET level_name='Renamed battle', starting_money=713,
                started_at='1700-01-01', map_image_name='level_015_renamed_battle'
                WHERE id='\(original.id.uuidString.lowercased())';
            UPDATE level_info SET level_name='Renamed battle' WHERE map_image_name='level_01_battle_road';
            """, in: fixture)
        let revised = try fixture.db.levelInfoDao.getBy(number: 15)
        XCTAssertEqual(revised.id, original.id)
        XCTAssertEqual(revised.name, "Renamed battle")
        XCTAssertEqual(revised.startingMoney, 713)
        XCTAssertEqual(revised.mapImageName, "level_015_renamed_battle")

        try execute("UPDATE level_info SET map_image_name='level_105_renamed_battle' WHERE id='\(original.id.uuidString.lowercased())'", in: fixture)
        XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(number: 15))
        XCTAssertEqual(try fixture.db.levelInfoDao.getBy(number: 105).id, original.id)
    }

    func testMissingInvalidAndAmbiguousNumbersFailWithoutLeakingStatements() throws {
        let fixture = try AuthoredDatabaseFixture()
        for number in [0, -1, 16, 99, Int.max] {
            XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(number: number), "\(number)")
        }
        try execute("UPDATE level_info SET map_image_name='level_015_duplicate' WHERE map_image_name='level_01_battle_road'", in: fixture)
        XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(number: 15)) {
            let diagnostic = String(describing: $0)
            XCTAssertTrue(diagnostic.contains("ambiguous level number 15"), diagnostic)
            XCTAssertTrue(diagnostic.contains("level_info.map_image_name"), diagnostic)
        }
        XCTAssertNil(sqlite3_next_stmt(fixture.connection, nil))
    }

    func testMalformedMapNumbersCannotSelectAnotherLevel() throws {
        let fixture = try AuthoredDatabaseFixture()
        let id = try fixture.db.levelInfoDao.getBy(number: 15).id.uuidString.lowercased()
        for key in ["level_15x_charleston", "level_15", "level_15_", "level_+15_charleston", "other_15_charleston", "level_150_charleston"] {
            try execute("UPDATE level_info SET map_image_name='\(key)' WHERE id='\(id)'", in: fixture)
            XCTAssertThrowsError(try fixture.db.levelInfoDao.getBy(number: 15), key)
        }
    }
}
