import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyContentTests: XCTestCase {
    private func withDatabase(_ body: (Db, OpaquePointer) throws -> Void) throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        try body(fixture.db, fixture.connection)
    }

    func testRenamingInDatabaseUpdatesDesignCopyWithoutChangingIdentityArtworkOrStats() throws {
        try withDatabase { db, conn in
            let original = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.redcoatRegular)
            XCTAssertFalse(original.description.isEmpty)
            let statement = """
                UPDATE enemy_type SET enemy_type_name='Renamed test enemy', enemy_type_long_name='Full renamed test enemy',
                enemy_type_description='Revised test description.' WHERE id='\(original.id.uuidString.lowercased())'
                """
            XCTAssertEqual(sqlite3_exec(conn, statement, nil, nil, nil), SQLITE_OK)
            let updated = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.redcoatRegular)
            XCTAssertEqual(updated.name, "Renamed test enemy")
            XCTAssertEqual(updated.longName, "Full renamed test enemy")
            XCTAssertEqual(updated.description, "Revised test description.")
            XCTAssertEqual(updated.key, original.key)
            XCTAssertEqual(updated.id, original.id)
            XCTAssertEqual(updated.imageName, original.imageName)
            XCTAssertEqual(updated.iconImageName, original.iconImageName)
            XCTAssertEqual(updated.stats, original.stats)
            XCTAssertEqual(updated.traits, original.traits)
            XCTAssertEqual(try JSONDecoder().decode(EnemyType.self, from: JSONEncoder().encode(updated)), updated)
        }
    }

    func testSchemaAndLoaderRejectMissingCopy() throws {
        try withDatabase { db, conn in
            for column in ["enemy_type_name", "enemy_type_long_name", "enemy_type_description", "image_name", "icon_image_name", "enemy_type_key"] {
                XCTAssertEqual(sqlite3_exec(conn, "UPDATE enemy_type SET \(column)='   '", nil, nil, nil), SQLITE_CONSTRAINT)
                XCTAssertEqual(sqlite3_exec(conn, "UPDATE enemy_type SET \(column)=NULL", nil, nil, nil), SQLITE_CONSTRAINT)
            }
            // Even a malformed database with checks bypassed must not invent text.
            XCTAssertEqual(sqlite3_exec(conn, "PRAGMA ignore_check_constraints=ON; UPDATE enemy_type SET enemy_type_description='   ';", nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try db.enemyTypeDao.getAll())
        }
    }

    func testMalformedFullNameAndIconFailWithEnemyAndFieldDiagnostic() throws {
        for field in ["enemy_type_long_name", "icon_image_name"] {
            for mutation in [
                "PRAGMA ignore_check_constraints=ON; UPDATE enemy_type SET \(field)='   '",
                "ALTER TABLE enemy_type RENAME TO original_enemy_type; CREATE TABLE enemy_type AS SELECT * FROM original_enemy_type; UPDATE enemy_type SET \(field)=NULL",
                "ALTER TABLE enemy_type DROP COLUMN \(field)"
            ] {
                try withDatabase { db, conn in
                    XCTAssertEqual(sqlite3_exec(conn, mutation, nil, nil, nil), SQLITE_OK)
                    XCTAssertThrowsError(try db.enemyTypeDao.getAll()) { error in
                        let message = String(describing: error)
                        XCTAssertTrue(message.contains("enemy_type"), message)
                        XCTAssertTrue(message.contains(field), message)
                        XCTAssertTrue(Foe.allCases.contains { message.contains($0.id.uuidString) }, message)
                    }
                }
            }
        }
    }

    func testOldRecordedEnemyNamesRemainReadableAndNewRecordingsKeepBoth() throws {
        try withDatabase { db, _ in
            let enemy = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.howeAssault)
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(enemy)) as? [String: Any])
            XCTAssertEqual(json["longName"] as? String, enemy.longName)
            XCTAssertEqual(json["iconImageName"] as? String, enemy.iconImageName)
            XCTAssertNotEqual(enemy.name, enemy.longName)
            json.removeValue(forKey: "longName")
            json.removeValue(forKey: "iconImageName")
            let old = try JSONDecoder().decode(EnemyType.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(old.name, enemy.name)
            XCTAssertEqual(old.longName, old.name)
            XCTAssertEqual(old.iconImageName, old.imageName)
            XCTAssertEqual(old.stats, enemy.stats)
            for malformed in [NSNull(), "   "] as [Any] {
                json["longName"] = malformed
                XCTAssertThrowsError(try JSONDecoder().decode(EnemyType.self, from: JSONSerialization.data(withJSONObject: json)))
            }
            json["longName"] = enemy.longName
            for malformed in [NSNull(), "   "] as [Any] {
                json["iconImageName"] = malformed
                XCTAssertThrowsError(try JSONDecoder().decode(EnemyType.self, from: JSONSerialization.data(withJSONObject: json)))
            }
        }
    }

    func testDesignRosterRequiresEveryAuthoredIdentity() throws {
        try withDatabase { db, _ in
            var rows = try db.enemyTypeDao.getAll()
            XCTAssertEqual(Set(rows.map(\.key)), Set(Foe.allCases.map(\.rawValue)))
            rows.removeLast()
            XCTAssertThrowsError(try DesignRoster(enemyTypes: rows))
        }
    }

    func testSimulatorRosterRejectsEachMissingDatabaseEnemyEvenWhenOthersExist() throws {
        try withDatabase { db, conn in
            for foe in Foe.allCases {
                XCTAssertEqual(sqlite3_exec(conn, """
                    SAVEPOINT missing_enemy;
                    DELETE FROM enemy_type WHERE id='\(foe.id.uuidString.lowercased())';
                    """, nil, nil, nil), SQLITE_OK)
                // A missing reserve target fails in the DAO before the design
                // roster is constructed; either boundary must identify it.
                XCTAssertThrowsError(try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()), foe.rawValue) {
                    let message = String(describing: $0)
                    XCTAssertTrue(message.contains(foe.rawValue), message)
                }
                XCTAssertEqual(sqlite3_exec(conn, "ROLLBACK TO missing_enemy; RELEASE missing_enemy",
                                           nil, nil, nil), SQLITE_OK)
            }
        }
    }

    func testSimulatorEnemyLookupPreservesIdentityAndDatabaseEdits() throws {
        try withDatabase { db, conn in
            for foe in Foe.allCases {
                let original = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(foe)
                XCTAssertEqual(sqlite3_exec(conn, """
                    SAVEPOINT changed_enemy;
                    UPDATE enemy_type SET speed = speed + 1 WHERE id='\(foe.id.uuidString.lowercased())';
                    """, nil, nil, nil), SQLITE_OK)
                let updated = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(foe)
                XCTAssertEqual(updated.id, foe.id)
                XCTAssertEqual(updated.key, foe.rawValue)
                XCTAssertEqual(updated.stats.speed, original.stats.speed + 1)
                XCTAssertEqual(sqlite3_exec(conn, "ROLLBACK TO changed_enemy; RELEASE changed_enemy",
                                           nil, nil, nil), SQLITE_OK)
            }
        }
    }

    func testSimulationRejectsEveryMissingRequestedEnemyBeforeStarting() throws {
        try withDatabase { db, _ in
            let levelID = try XCTUnwrap(db.levelInfoDao.getCampaignLevels(campaignName: "Main").first?.id)
            var level = try db.levelLoader.load(id: levelID)
            let enemies = try db.enemyTypeDao.getAll()
            let base = try BattleTestFixture.authored(db: db)
            for foe in Foe.allCases {
                level.waves = [Wave(startTime: 0, spawns: [
                    SpawnEntry(enemyTypeID: foe.id, count: 1, interval: 1)
                ], callButtonDelay: 0, autoStartCountdown: 0, earlyCallBonus: 0)]
                level.numWaves = 1
                for remaining in [enemies.filter { $0.id != foe.id }, []] {
                    XCTAssertThrowsError(try BattleTestFixture.content(level: level, enemies: remaining, base: base)) {
                        let message = String(describing: $0)
                        XCTAssertTrue(message.contains(foe.id.uuidString) || message.contains(foe.rawValue), message)
                    }
                }
            }
        }
    }

    func testUnknownEditorEnemyCannotBecomeAnotherEnemySilently() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let native = try NativeMapFile.read(Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.tdmap")))
        var draft = native.draft
        draft.waves[0].lines[0].foe = "unknown_enemy_key"
        try withDatabase { db, _ in
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            XCTAssertThrowsError(try draft.makeBlueprint(virtualCanvas: native.canvas, arsenal: arsenal))
            XCTAssertThrowsError(try SwiftExport.code(for: draft, arsenal: arsenal))
        }
    }
}
