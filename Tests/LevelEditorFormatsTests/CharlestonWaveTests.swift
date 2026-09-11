import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class CharlestonWaveTests: XCTestCase {
    private let levelID = UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testEditorPreservesAllRoutesAndAllWaveTiming() throws {
        let native = try NativeMapFile.read(Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.tdmap")))
        let data = try Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.geojson"))
        let authored = try LevelGeoJSON(data: data)
        let imported = try GeoJSONImport.draft(from: data)
        XCTAssertEqual(imported.waves, native.draft.waves)
        XCTAssertEqual(imported.waves.count, 15)
        let exported = try GeoJSONExport(virtualCanvas: native.canvas).document(for: imported)
        XCTAssertEqual(exported.collection.waves, authored.collection.waves)
        XCTAssertEqual(imported.enemyRoutes, native.draft.enemyRoutes)
        XCTAssertEqual(try LevelGeoJSONDAO.enemyRoutes(from: exported.data()), native.draft.enemyRoutes)
        let fromNative = try GeoJSONExport(virtualCanvas: native.canvas).document(for: native.draft)
        XCTAssertEqual(fromNative.collection.waves, authored.collection.waves)
        XCTAssertEqual(try LevelGeoJSONDAO.enemyRoutes(from: fromNative.data()), native.draft.enemyRoutes)
        XCTAssertEqual(Set(imported.waves.flatMap { $0.lines.map(\.road) }), [0, 1, 2, 3])
        var erased = imported
        erased.applyErase(.init(points: [Point(1600, 1000)], width: 20, erases: true),
                          mapGeometry: MapGeometry(virtualCanvas: native.canvas))
        XCTAssertEqual(erased.waves, imported.waves, "Painting the area must not renumber entrance routes")
    }

    func testDatabaseRoutesSpawnsAndAutomaticStartsMatchAuthoredWaves() throws {
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        try FileManager.default.copyItem(at: root.appendingPathComponent("Db/in_defense_of_history.sqlite"), to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }
        let db = Db(dbPath: copy.path, fullRefresh: false,
                    levelGeoJSONDao: LevelGeoJSONDAO(directory: root.appendingPathComponent("Db")))
        defer { db.close() }
        let level = try db.levelLoader.load(id: levelID)
        // Assert the SQL copy too: the runtime loader now prefers GeoJSON.
        XCTAssertEqual(try db.pathDao.getPathsFor(levelInfoId: levelID), level.paths)
        let geo = try LevelGeoJSON(data: Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.geojson")))
        let draft = try GeoJSONImport.draft(from: geo.data())
        let enemies = Dictionary(uniqueKeysWithValues: try db.enemyTypeDao.getAll().map { ($0.id, $0.name) })
        XCTAssertEqual(level.numWaves, 15)
        XCTAssertEqual(level.paths.count, 4)
        XCTAssertEqual(level.paths[0].points.first, draft.entrances[0])
        XCTAssertEqual(level.paths[0].points.last, draft.exits[1])
        XCTAssertEqual(level.paths[1].points.first, draft.entrances[1])
        XCTAssertEqual(level.paths[1].points.last, draft.exits[0])
        XCTAssertEqual(level.paths[2].points.first, draft.entrances[0])
        XCTAssertEqual(level.paths[2].points.last, draft.exits[0])
        XCTAssertEqual(level.paths[3].points.first, draft.entrances[1])
        XCTAssertEqual(level.paths[3].points.last, draft.exits[1])
        let area = try HeroMovementArea(geoJSON: geo.data(), defaultPathWidth: 140)
        for path in level.paths {
            XCTAssertTrue(zip(path.points, path.points.dropFirst()).allSatisfy { area.containsSegment(from: $0.0, to: $0.1) })
            // Walk the actual engine Path interpolation used by every enemy.
            for distance in stride(from: 0, through: path.totalLength, by: 0.5) {
                XCTAssertTrue(area.contains(path.point(atDistance: distance)))
            }
        }
        var schedule = try WaveStartSchedule(waves: level.waves)
        XCTAssertEqual(schedule.state(at: 100000), .manualFirstWave)
        XCTAssertEqual(schedule.startNextWave(at: 0, manually: true)?.index, 0)
        var start = 0.0
        var previousSpawnEnd = 0.0
        var total = 0
        for (index, pair) in zip(level.waves, geo.collection.waves).enumerated() {
            let (wave, authored) = pair
            XCTAssertEqual(wave.callButtonDelay, authored.callButtonDelay)
            XCTAssertEqual(wave.autoStartCountdown, authored.autoStartCountdown)
            XCTAssertEqual(wave.earlyCallBonus, authored.earlyCallBonus)
            if index > 0 {
                start += try XCTUnwrap(wave.callButtonDelay) + XCTUnwrap(wave.autoStartCountdown)
                let tick = Int64(start * Double(SimClock.ticksPerSecond))
                XCTAssertNotEqual(schedule.state(at: tick - 1), .due)
                XCTAssertEqual(schedule.state(at: tick), .due)
                XCTAssertEqual(schedule.startNextWave(at: tick, manually: false)?.index, index)
            }
            XCTAssertEqual(wave.startTime, start)
            XCTAssertEqual(previousSpawnEnd + authored.breather, start, accuracy: 0.000001)
            previousSpawnEnd = start + (authored.lines.map { $0.delay + Double($0.count - 1) * $0.every }.max() ?? 0)
            XCTAssertEqual(wave.spawns.count, authored.lines.count)
            for (spawn, line) in zip(wave.spawns, authored.lines) {
                XCTAssertEqual(enemies[spawn.enemyTypeID], line.foe)
                XCTAssertEqual(spawn.count, line.count)
                XCTAssertEqual(spawn.delay, line.delay)
                XCTAssertEqual(spawn.interval, line.every)
                XCTAssertEqual(spawn.pathIndex, line.pathIndex)
                total += spawn.count
            }
            XCTAssertFalse(CallWaveButtonPosition.visiblePositions(draft.callWaveButtons,
                forPathIndices: Set(wave.spawns.map(\.pathIndex))).isEmpty)
        }
        XCTAssertEqual(total, 424)
        XCTAssertEqual(start, 540)
        XCTAssertTrue(schedule.allWavesStarted)
    }
}
