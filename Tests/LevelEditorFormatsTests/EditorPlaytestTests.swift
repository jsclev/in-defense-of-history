import XCTest
import SQLite3
@testable import LevelEditorFormats

@MainActor
final class EditorPlaytestTests: XCTestCase {
    private func source() throws -> NativeMapFile {
        try NativeMapFile.read(Data(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("level_15_charleston.tdmap")))
    }

    func testNativeCharlestonPlaytestUsesEngineAndDatabaseBudget() throws {
        let file = try source()
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = try fixture.db.levelInfoDao.getIdForEditorDocument(named: file.draft.name)
        XCTAssertEqual(id, try fixture.db.levelInfoDao.getIdBy(levelName: "Charleston"))
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE level_info SET starting_money=777 WHERE id='\(id.uuidString.lowercased())'", nil, nil, nil), SQLITE_OK)
        let session = try SimSession(draft: file.draft, db: fixture.db, virtualCanvas: file.canvas)
        XCTAssertEqual(session.sim.gold, 777)
        XCTAssertEqual(session.level.paths.count, file.draft.enemyRoutes.count)
        XCTAssertEqual(session.sim.currentWave, 0)
        let shadow = try GameSimulation(recording: .preview, content: session.content, startingMoney: nil, heroesEnabled: true, seed: session.seed)
        session.build(.ranged, at: 17)
        XCTAssertEqual(shadow.perform(.build(slot: 17, kind: .ranged)), .ok)
        session.sim.startNextWave(); shadow.startNextWave()
        let date = Date(timeIntervalSince1970: 0)
        session.advance(to: date)
        session.advance(to: date.addingTimeInterval(0.2))
        for _ in 0..<6 { shadow.step() }
        XCTAssertEqual(session.sim.time, shadow.time)
        XCTAssertEqual(session.sim.gold, shadow.gold)
        XCTAssertEqual(session.sim.enemies.map(\.hp), shadow.enemies.map(\.hp))
        XCTAssertEqual(session.sim.enemies.map(\.position), shadow.enemies.map(\.position))
        session.restart()
        XCTAssertEqual(session.sim.gold, 777)
        XCTAssertEqual(session.sim.currentWave, 0)
    }

    func testMissingDraftTimingAndUnknownDatabaseLevelDoNotGetFallbackRules() throws {
        var file = try source()
        let fixture = try AuthoredDatabaseFixture()
        XCTAssertThrowsError(try fixture.db.levelInfoDao.getIdForEditorDocument(named: "unpublished map"))
        file.draft.waves[0].callButtonDelay = nil
        XCTAssertThrowsError(try SimSession(draft: file.draft, db: fixture.db, virtualCanvas: file.canvas)) {
            XCTAssertTrue(String(describing: $0).contains("timing"), "\($0)")
        }
    }
}
