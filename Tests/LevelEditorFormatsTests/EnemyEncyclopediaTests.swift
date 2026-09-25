import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyEncyclopediaTests: XCTestCase {
    func testCompleteRosterUsesTheProductionRecordsAndRequiredHistory() throws {
        let fixture = try AuthoredDatabaseFixture()
        let entries = try fixture.db.enemyTypeDao.getEncyclopedia()
        XCTAssertEqual(entries.map(\.id), Foe.allCases.map(\.id))
        let roster = try DesignRoster(enemyTypes: fixture.db.enemyTypeDao.getAll())
        for entry in entries {
            XCTAssertEqual(entry.enemy, roster.enemyTypes.first { $0.id == entry.id })
            XCTAssertFalse(entry.strategy.isEmpty)
            XCTAssertFalse(entry.history.isEmpty)
            XCTAssertFalse(entry.inclusionReason.isEmpty)
            XCTAssertFalse(entry.adaptation.isEmpty)
            XCTAssertEqual(entry.sourceURL.scheme, "https")
        }
    }

    func testDatabaseEditsReachCopyStatsAndArtwork() throws {
        let fixture = try AuthoredDatabaseFixture()
        let id = Foe.redcoatRegular.id.uuidString.lowercased()
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE enemy_type SET enemy_type_name='Changed name', image_name='changed_art', max_hp=123, speed=77 WHERE id='\(id)';
            UPDATE enemy_encyclopedia SET strategy_text='Changed strategy', historical_description='Changed history',
              inclusion_reason='Changed rationale', adaptation_text='Changed adaptation', source_title='Changed source',
              source_url='https://www.nps.gov/' WHERE enemy_type_id='\(id)';
            """, nil, nil, nil), SQLITE_OK)
        let entry = try XCTUnwrap(fixture.db.enemyTypeDao.getEncyclopedia().first { $0.id == Foe.redcoatRegular.id })
        XCTAssertEqual(entry.enemy.name, "Changed name")
        XCTAssertEqual(entry.enemy.imageName, "changed_art")
        XCTAssertEqual(entry.enemy.stats.maxHP, 123)
        XCTAssertEqual(entry.enemy.stats.speed, 77)
        XCTAssertEqual(entry.strategy, "Changed strategy")
        XCTAssertEqual(entry.history, "Changed history")
        XCTAssertEqual(entry.inclusionReason, "Changed rationale")
        XCTAssertEqual(entry.adaptation, "Changed adaptation")
        XCTAssertEqual(entry.sourceTitle, "Changed source")
        XCTAssertEqual(entry.sourceURL.absoluteString, "https://www.nps.gov/")
        let rows = EnemyEncyclopediaStats(enemy: entry.enemy, rules: try fixture.db.combatRulesDao.get()).rows
        XCTAssertEqual(rows.first { $0.label == "Health" }?.value, "123")
    }

    func testMissingAndInvalidContentFailsWithRecordAndField() throws {
        let id = Foe.redcoatRegular.id.uuidString.lowercased()
        var mutations = [("DELETE FROM enemy_encyclopedia WHERE enemy_type_id='\(id)'", "enemy_type_id")]
        for field in ["strategy_text", "historical_description", "inclusion_reason", "adaptation_text", "source_title", "source_url"] {
            mutations.append(("UPDATE enemy_encyclopedia SET \(field)=' ' WHERE enemy_type_id='\(id)'", field))
        }
        mutations.append(("UPDATE enemy_encyclopedia SET source_url='relative/path' WHERE enemy_type_id='\(id)'", "source_url"))
        for (mutation, field) in mutations {
            let fixture = try AuthoredDatabaseFixture()
            XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints=ON; " + mutation, nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getEncyclopedia()) {
                let message = String(describing: $0)
                XCTAssertTrue(message.contains("enemy_encyclopedia"), message)
                XCTAssertTrue(message.contains(field), message)
            }
        }
        let fixture = try AuthoredDatabaseFixture()
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE enemy_encyclopedia SET inclusion_reason=NULL", nil, nil, nil), SQLITE_CONSTRAINT)
    }

    @MainActor func testEveryEnemyCompletesAnUnmodifiedSharedEngineEncounter() throws {
        let fixture = try AuthoredDatabaseFixture()
        let enemies = try fixture.db.enemyTypeDao.getEncyclopedia()
        let difficulty = try XCTUnwrap(fixture.db.difficultyDao.getSelected())
        for entry in enemies {
            let demo = try TowerDemonstration(db: fixture.db, enemyID: entry.id)
            XCTAssertNotNil(demo.outcome, entry.enemy.key)
            XCTAssertTrue(demo.frames.last!.enemies.isEmpty, entry.enemy.key)
            XCTAssertEqual(demo.frames.last!.killed.count + demo.escaped, 1, entry.enemy.key)
            XCTAssertGreaterThan(demo.frames.last!.shots, 0, entry.enemy.key)
            XCTAssertTrue(demo.frames.contains { $0.enemies.contains { $0.hp < $0.maxHP } }, entry.enemy.key)
            for enemy in demo.frames.flatMap(\.enemies) {
                XCTAssertEqual(enemy.assetName, entry.enemy.imageName)
                XCTAssertEqual(enemy.speed, entry.enemy.stats.speed)
                XCTAssertEqual(enemy.damageMin, entry.enemy.stats.damageMin)
                XCTAssertEqual(enemy.discipline, entry.enemy.stats.discipline)
                XCTAssertEqual(enemy.maxHP, entry.enemy.stats.maxHP * difficulty.enemyHPMultiplier)
            }
            if entry.enemy.has(.rideDown) {
                XCTAssertTrue(demo.frames.allSatisfy { $0.blocked.isEmpty })
                XCTAssertGreaterThan(demo.escaped, 0)
            }
            print("ENEMY \(entry.enemy.key): \(demo.loopDuration)s, killed \(demo.frames.last!.killed.count), escaped \(demo.escaped)")
        }
    }

    @MainActor func testEnemyMutationChangesDemonstrationAndInvalidDataStopsIt() throws {
        let fixture = try AuthoredDatabaseFixture()
        let original = try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE enemy_type SET speed=100 WHERE enemy_type_key='redcoat_regular'", nil, nil, nil), SQLITE_OK)
        let changed = try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id)
        XCTAssertEqual(changed.frames.first!.enemies.first!.speed, 100)
        XCTAssertNotEqual(original.frames[30].enemies.first!.position, changed.frames[30].enemies.first!.position)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints=ON; UPDATE enemy_type SET max_hp=-1 WHERE enemy_type_key='redcoat_regular'", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try TowerDemonstration(db: fixture.db, enemyID: Foe.redcoatRegular.id))
    }
}
