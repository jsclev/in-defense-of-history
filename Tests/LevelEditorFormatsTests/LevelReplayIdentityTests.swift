import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelReplayIdentityTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testPresentationRenamePreservesReplayFingerprintButCombatEditDoesNot() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try fixture.db.levelInfoDao.getBy(number: 15).id
        func study() throws -> AuthoredMoneyStudy { try AuthoredMoneyStudy(db: fixture.db, levelID: id) }
        func context() throws -> GeneticSolutionContext {
            let current = try study()
            return try GeneticSolutionContext(study: current, db: fixture.db,
                startingMoney: current.level.startingMoney, bountyFraction: 1, maxGameSeconds: 1800)
        }
        XCTAssertEqual(try study().level.name, "Yorktown")
        let renamedSnapshot = try study().replaySnapshot(db: fixture.db, heroesEnabled: true)
        let renamedContext = try context()

        try execute("UPDATE level_info SET level_name='Charleston' WHERE id='\(id.uuidString.lowercased())'", in: fixture)
        XCTAssertEqual(try study().level.name, "Charleston")
        XCTAssertEqual(try study().replaySnapshot(db: fixture.db, heroesEnabled: true), renamedSnapshot)
        XCTAssertEqual(try context(), renamedContext)

        try execute("UPDATE level_info SET num_starting_lives=num_starting_lives+1 WHERE id='\(id.uuidString.lowercased())'", in: fixture)
        XCTAssertNotEqual(try study().replaySnapshot(db: fixture.db, heroesEnabled: true), renamedSnapshot)
        XCTAssertNotEqual(try context().contentSHA256, renamedContext.contentSHA256)
    }

    func testMissingAndInvalidReplayIdentitiesFailWithRecordDiagnostics() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try fixture.db.levelInfoDao.getBy(number: 15).id
        let key = id.uuidString.lowercased()
        try execute("PRAGMA ignore_check_constraints=ON; UPDATE level_replay_identity SET level_name='  ' WHERE level_info_id='\(key)'", in: fixture)
        for _ in 0..<2 {
            XCTAssertThrowsError(try AuthoredMoneyStudy(db: fixture.db, levelID: id)
                .replaySnapshot(db: fixture.db, heroesEnabled: true)) { error in
                let diagnostic = String(describing: error)
                XCTAssertTrue(diagnostic.contains("level_replay_identity[\(key)].level_name"), diagnostic)
            }
            try execute("DELETE FROM level_replay_identity WHERE level_info_id='\(key)'", in: fixture)
        }
        XCTAssertNil(sqlite3_next_stmt(fixture.connection, nil))
    }
}
