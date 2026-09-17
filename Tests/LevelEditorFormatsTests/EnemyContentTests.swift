import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyContentTests: XCTestCase {
    private func withDatabase(_ body: (Db, OpaquePointer) throws -> Void) throws {
        let fixture = try AuthoredDatabaseFixture()
        try body(fixture.db, fixture.connection)
    }

    func testRenamingInDatabaseUpdatesDesignCopyWithoutChangingIdentityArtworkOrStats() throws {
        try withDatabase { db, conn in
            let original = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.redcoatRegular)
            XCTAssertFalse(original.description.isEmpty)
            let statement = """
                UPDATE enemy_type SET enemy_type_name='Renamed test enemy',
                enemy_type_description='Revised test description.' WHERE id='\(original.id.uuidString.lowercased())'
                """
            XCTAssertEqual(sqlite3_exec(conn, statement, nil, nil, nil), SQLITE_OK)
            let updated = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.redcoatRegular)
            XCTAssertEqual(updated.name, "Renamed test enemy")
            XCTAssertEqual(updated.description, "Revised test description.")
            XCTAssertEqual(updated.key, original.key)
            XCTAssertEqual(updated.id, original.id)
            XCTAssertEqual(updated.imageName, original.imageName)
            XCTAssertEqual(updated.stats, original.stats)
            XCTAssertEqual(updated.traits, original.traits)
            XCTAssertEqual(try JSONDecoder().decode(EnemyType.self, from: JSONEncoder().encode(updated)), updated)
        }
    }

    func testSchemaAndLoaderRejectMissingCopy() throws {
        try withDatabase { db, conn in
            for column in ["enemy_type_name", "enemy_type_description", "image_name", "enemy_type_key"] {
                XCTAssertEqual(sqlite3_exec(conn, "UPDATE enemy_type SET \(column)='   '", nil, nil, nil), SQLITE_CONSTRAINT)
            }
            // Even a malformed database with checks bypassed must not invent text.
            XCTAssertEqual(sqlite3_exec(conn, "PRAGMA ignore_check_constraints=ON; UPDATE enemy_type SET enemy_type_description='   ';", nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try db.enemyTypeDao.getAll())
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
