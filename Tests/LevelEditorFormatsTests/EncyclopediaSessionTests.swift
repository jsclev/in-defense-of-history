import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EncyclopediaSessionTests: XCTestCase {
    @MainActor
    func testEveryVisitHasFreshIdentityCatalogsAndCategoryPicker() throws {
        let fixture = try AuthoredDatabaseFixture()
        let visits = try (0..<3).map { _ in try EncyclopediaSession(db: fixture.db) }

        XCTAssertEqual(Set(visits.map(\.id)).count, visits.count)
        for (index, visit) in visits.enumerated() {
            XCTAssertNil(visit.initialCategory)
            XCTAssertFalse(visit.arsenal.towers.isEmpty)
            XCTAssertFalse(visit.enemies.isEmpty)
            for earlier in visits.prefix(index) {
                XCTAssertFalse(visit.demonstrations === earlier.demonstrations,
                               "A new visit must not reuse the previous tower recording cache")
                XCTAssertFalse(visit.enemyDemonstrations === earlier.enemyDemonstrations,
                               "A new visit must not reuse the previous enemy recording cache")
            }
        }
    }

    @MainActor
    func testNextVisitReloadsAuthoredContentWithoutChangingThePreviousSnapshot() throws {
        let fixture = try AuthoredDatabaseFixture()
        let previous = try EncyclopediaSession(db: fixture.db)
        let originalTower = try XCTUnwrap(previous.arsenal.towers.flatMap(\.tiers).first)
        let originalEnemy = try XCTUnwrap(previous.enemies.first)
        try execute("""
            UPDATE tower SET tower_name = 'Revised authored tower'
            WHERE lower(id) = '\(originalTower.id.uuidString.lowercased())';
            UPDATE tower_history SET historical_description = 'Revised authored tower history'
            WHERE lower(tower_id) = '\(originalTower.id.uuidString.lowercased())';
            UPDATE enemy_type SET enemy_type_name = 'Revised authored enemy'
            WHERE lower(id) = '\(originalEnemy.id.uuidString.lowercased())';
            UPDATE enemy_encyclopedia SET historical_description = 'Revised authored enemy history'
            WHERE lower(enemy_type_id) = '\(originalEnemy.id.uuidString.lowercased())';
            """, in: fixture)

        let next = try EncyclopediaSession(db: fixture.db)
        let newTower = try XCTUnwrap(next.arsenal.towers.flatMap(\.tiers).first { $0.id == originalTower.id })
        let newEnemy = try XCTUnwrap(next.enemies.first { $0.id == originalEnemy.id })
        XCTAssertEqual(newTower.details.name, "Revised authored tower")
        XCTAssertEqual(newTower.history.description, "Revised authored tower history")
        XCTAssertEqual(newEnemy.enemy.name, "Revised authored enemy")
        XCTAssertEqual(newEnemy.history, "Revised authored enemy history")

        let retainedTower = try XCTUnwrap(previous.arsenal.towers.flatMap(\.tiers).first { $0.id == originalTower.id })
        let retainedEnemy = try XCTUnwrap(previous.enemies.first { $0.id == originalEnemy.id })
        XCTAssertEqual(retainedTower.details.name, originalTower.details.name)
        XCTAssertEqual(retainedTower.history.description, originalTower.history.description)
        XCTAssertEqual(retainedEnemy.enemy.name, originalEnemy.enemy.name)
        XCTAssertEqual(retainedEnemy.history, originalEnemy.history)
        XCTAssertNotEqual(retainedTower.details.name, newTower.details.name)
        XCTAssertNotEqual(retainedEnemy.enemy.name, newEnemy.enemy.name)
    }

    @MainActor
    func testReentryRejectsMissingRequiredContentAfterAnEarlierSuccessfulVisit() throws {
        for table in ["tower_history", "enemy_encyclopedia"] {
            let fixture = try AuthoredDatabaseFixture()
            let previous = try EncyclopediaSession(db: fixture.db)
            let tower = try XCTUnwrap(previous.arsenal.towers.flatMap(\.tiers).first)
            let enemy = try XCTUnwrap(previous.enemies.first)
            let column = table == "tower_history" ? "tower_id" : "enemy_type_id"
            let id = table == "tower_history" ? tower.id : enemy.id
            let record = table == "tower_history" ? id.uuidString.lowercased() : enemy.enemy.key
            try execute("DELETE FROM \(table) WHERE lower(\(column)) = '\(id.uuidString.lowercased())'", in: fixture)

            XCTAssertThrowsError(try EncyclopediaSession(db: fixture.db), table) { error in
                let diagnostic = String(describing: error).lowercased()
                XCTAssertTrue(diagnostic.contains(table), diagnostic)
                XCTAssertTrue(diagnostic.contains(column), diagnostic)
                XCTAssertTrue(diagnostic.contains(record), diagnostic)
            }
            XCTAssertTrue(previous.arsenal.towers.flatMap(\.tiers).contains { $0.id == tower.id })
            XCTAssertTrue(previous.enemies.contains { $0.id == enemy.id })
        }
    }

    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }
}
