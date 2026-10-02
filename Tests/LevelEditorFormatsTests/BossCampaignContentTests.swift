import XCTest
import SQLite3
@testable import LevelEditorFormats

final class BossCampaignContentTests: XCTestCase {
    func testThreeBossesAppearOnceInTheirFinalCampaignWaves() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let cases: [(Int, Foe, Int, Int)] = [
            (5, .howeAssault, 9, 350), (10, .hillRearguard, 12, 400), (15, .clintonSiege, 15, 670)
        ]
        let bossIDs = Set(try fixture.db.enemyTypeDao.getAll().filter { $0.bossRules != nil }.map(\.id))
        XCTAssertEqual(bossIDs, Set(cases.map { $0.1.id }))
        for (number, foe, waveCount, money) in cases {
            let record = try fixture.db.levelInfoDao.getBy(number: number)
            let content = try BattleContent(db: fixture.db, levelID: record.id)
            XCTAssertEqual(record.startingMoney, money)
            XCTAssertEqual(content.level.startingMoney, money)
            XCTAssertEqual(content.level.numWaves, waveCount)
            XCTAssertEqual(content.level.waves.count, waveCount)
            let allBossSpawns = content.level.waves.flatMap(\.spawns).filter { bossIDs.contains($0.enemyTypeID) }
            XCTAssertEqual(allBossSpawns.count, 1)
            let boss = try XCTUnwrap(allBossSpawns.first)
            XCTAssertEqual(boss.enemyTypeID, foe.id)
            XCTAssertEqual(boss.count, 1)
            XCTAssertTrue(content.level.waves.last!.spawns.contains { $0.enemyTypeID == foe.id })
            XCTAssertFalse(content.level.waves.dropLast().flatMap(\.spawns).contains { bossIDs.contains($0.enemyTypeID) })
            XCTAssertTrue(content.level.paths.indices.contains(boss.pathIndex))
        }

        // Check the complete SQL catalog as well, including levels that are not
        // yet playable. A boss cannot leak into generated regular wave mixes.
        var statement: OpaquePointer?
        let sql = """
            SELECT l.map_image_name, w.wave_index, l.num_waves, e.enemy_type_key, s.num_enemies
            FROM level_wave_enemy_spawn s
            JOIN level_wave w ON w.id=s.level_wave_id
            JOIN level_info l ON l.id=w.level_info_id
            JOIN enemy_type e ON e.id=s.enemy_type_id
            WHERE EXISTS (SELECT 1 FROM json_each(e.traits) t WHERE json_extract(t.value,'$.type')='boss')
            ORDER BY l.map_image_name
            """
        XCTAssertEqual(sqlite3_prepare_v2(fixture.connection, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var keys = Set<String>()
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            count += 1
            let key = String(cString: sqlite3_column_text(statement, 3))
            XCTAssertTrue(keys.insert(key).inserted)
            XCTAssertEqual(sqlite3_column_int(statement, 1), sqlite3_column_int(statement, 2))
            XCTAssertEqual(sqlite3_column_int(statement, 4), 1)
        }
        XCTAssertEqual(count, 3)
        XCTAssertEqual(keys, Set(cases.map { $0.1.rawValue }))
    }
}
