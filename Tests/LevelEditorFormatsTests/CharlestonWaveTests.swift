import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class CharlestonWaveTests: XCTestCase {
    private let levelID = UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func openAuthoredDatabase() -> Db {
        Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false,
           levelGeoJSONDao: LevelGeoJSONDAO(directory: root.appendingPathComponent("Db")))
    }

    func testEditorPreservesAllRoutesAndAllWaveTiming() throws {
        let native = try NativeMapFile.read(Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.tdmap")))
        let data = try Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.geojson"))
        let authored = try LevelGeoJSON(data: data)
        let imported = try GeoJSONImport.draft(from: data)
        XCTAssertEqual(imported.entrances, native.draft.entrances)
        XCTAssertEqual(imported.exits, native.draft.exits)
        XCTAssertEqual(imported.slots, native.draft.slots)
        XCTAssertEqual(imported.slots.count, 19)
        XCTAssertEqual(imported.primaryHeroPosition, native.draft.primaryHeroPosition)
        XCTAssertEqual(imported.secondaryHeroPosition, native.draft.secondaryHeroPosition)
        XCTAssertEqual(imported.callWaveButtons, native.draft.callWaveButtons)
        XCTAssertEqual(imported.callWaveButtons.map(\.pathIndices), [[0, 2, 4], [1, 3, 5]])
        XCTAssertEqual(imported.startingGold, 500)
        XCTAssertEqual(imported.waves, native.draft.waves)
        XCTAssertEqual(imported.waves.count, 15)
        let exported = try GeoJSONExport(virtualCanvas: native.canvas).document(for: imported)
        XCTAssertEqual(exported.collection.waves, authored.collection.waves)
        XCTAssertEqual(imported.enemyRoutes, native.draft.enemyRoutes)
        XCTAssertEqual(try LevelGeoJSONDAO.enemyRoutes(from: exported.data()), native.draft.enemyRoutes)
        let fromNative = try GeoJSONExport(virtualCanvas: native.canvas).document(for: native.draft)
        XCTAssertEqual(fromNative.collection.waves, authored.collection.waves)
        XCTAssertEqual(try LevelGeoJSONDAO.enemyRoutes(from: fromNative.data()), native.draft.enemyRoutes)
        XCTAssertEqual(Set(imported.waves.flatMap { $0.lines.map(\.road) }), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(Set(imported.waves.last!.lines.map(\.road)), [0, 1, 2, 3, 4, 5])
        var erased = imported
        erased.applyErase(.init(points: [Point(1600, 1000)], width: 20, erases: true),
                          mapGeometry: MapGeometry(virtualCanvas: native.canvas))
        XCTAssertEqual(erased.waves, imported.waves, "Painting the area must not renumber entrance routes")
    }

    func testDatabaseRoutesSpawnsAndAutomaticStartsMatchAuthoredWaves() throws {
        let db = openAuthoredDatabase()
        defer { db.close() }
        let level = try db.levelLoader.load(id: levelID)
        // Assert the SQL copy too: the runtime loader now prefers GeoJSON.
        XCTAssertEqual(try db.pathDao.getPathsFor(levelInfoId: levelID), level.paths)
        let geo = try LevelGeoJSON(data: Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.geojson")))
        let draft = try GeoJSONImport.draft(from: geo.data())
        let enemies = Dictionary(uniqueKeysWithValues: try db.enemyTypeDao.getAll().map { ($0.id, $0.key) })
        XCTAssertEqual(try db.levelInfoDao.getBy(number: 15).id, levelID)
        XCTAssertEqual(level.startingMoney, 670, "Campaign money must remain the SQL-authored budget")
        XCTAssertEqual(level.numWaves, 15)
        XCTAssertEqual(level.waves.count, level.numWaves)
        XCTAssertEqual(level.paths.count, 6)
        XCTAssertEqual(level.paths[0].points.first, draft.entrances[0])
        XCTAssertEqual(level.paths[0].points.last, draft.exits[1])
        XCTAssertEqual(level.paths[1].points.first, draft.entrances[1])
        XCTAssertEqual(level.paths[1].points.last, draft.exits[0])
        XCTAssertEqual(level.paths[2].points.first, draft.entrances[0])
        XCTAssertEqual(level.paths[2].points.last, draft.exits[0])
        XCTAssertEqual(level.paths[3].points.first, draft.entrances[1])
        XCTAssertEqual(level.paths[3].points.last, draft.exits[1])
        XCTAssertEqual(level.paths[4].points.first, draft.entrances[0])
        XCTAssertEqual(level.paths[4].points.last, draft.exits[0])
        XCTAssertEqual(level.paths[5].points.first, draft.entrances[1])
        XCTAssertEqual(level.paths[5].points.last, draft.exits[1])
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
            XCTAssertEqual(wave.autoStartCountdown, index == 0 ? 0 : 13)
            XCTAssertEqual(wave.earlyCallBonus, index == 0 ? 0 : 13)
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
        XCTAssertEqual(total, 991)
        XCTAssertEqual(start, 600)
        XCTAssertTrue(schedule.allWavesStarted)
    }

    func testCountsRiseGraduallyAndLateColumnsPressureBothEntrances() throws {
        let db = openAuthoredDatabase()
        defer { db.close() }
        let waves = try db.waveDao.getWavesFor(levelInfoId: levelID)
        let counts = waves.map { $0.spawns.reduce(0) { $0 + $1.count } }
        for (earlier, later) in zip(counts, counts.dropFirst()) {
            XCTAssertGreaterThan(later, earlier)
            XCTAssertLessThanOrEqual(Double(later), Double(earlier) * 1.35,
                "A new wave must not repeat the former abrupt infantry-count spikes")
        }
        XCTAssertEqual(Set(waves.prefix(7).flatMap { $0.spawns.map(\.pathIndex) }), [0, 1, 2, 3, 4, 5],
            "Introduce all roads before combining their specialist threats")
        let regular = try XCTUnwrap(db.enemyTypeDao.getAll().first { $0.key == "redcoat_regular" })
        XCTAssertLessThan(regular.stats.discipline, 1, "The main columns must be vulnerable to morale damage")
        for wave in waves.dropFirst(7) {
            let columns = wave.spawns.filter { $0.enemyTypeID == regular.id && $0.count >= 20 && $0.interval <= 0.5 }
            XCTAssertGreaterThanOrEqual(columns.count, 2)
            XCTAssertEqual(Set(columns.map { $0.pathIndex % 2 }), [0, 1], "Each entrance needs artillery coverage")
            let firstEntrance = try XCTUnwrap(columns.filter { $0.pathIndex % 2 == 0 }.map(\.delay).min())
            let secondEntrance = try XCTUnwrap(columns.filter { $0.pathIndex % 2 == 1 }.map(\.delay).min())
            XCTAssertNotEqual(firstEntrance, secondEntrance, "The two approaches should arrive as staggered pulses")
        }
    }

    func testActiveSpecialistsHaveControlledIntroductions() throws {
        let db = openAuthoredDatabase()
        defer { db.close() }
        let level = try db.levelLoader.load(id: levelID)
        let enemies = try db.enemyTypeDao.getAll()
        let ranger = try XCTUnwrap(enemies.first { $0.key == "queens_ranger" })
        let dragoon = try XCTUnwrap(enemies.first { $0.key == "light_dragoon" })
        let officer = try XCTUnwrap(enemies.first { $0.key == "mounted_officer" })
        XCTAssertNotNil(ranger.concealmentRules)
        XCTAssertTrue(dragoon.has(.rideDown), "Cavalry must still bypass melee and hero blocking")
        let reserve = try XCTUnwrap(officer.reinforcementCallRules)
        XCTAssertEqual(reserve.enemyTypeKey, "redcoat_regular")
        XCTAssertEqual(reserve.count * reserve.maxCalls, 4, "The first officer must have a finite, small reserve")

        let rangerWave = try XCTUnwrap(level.waves.firstIndex { $0.spawns.contains { $0.enemyTypeID == ranger.id } })
        let dragoonWave = try XCTUnwrap(level.waves.firstIndex { $0.spawns.contains { $0.enemyTypeID == dragoon.id } })
        let officerWave = try XCTUnwrap(level.waves.firstIndex { $0.spawns.contains { $0.enemyTypeID == officer.id } })
        XCTAssertEqual(rangerWave, 4)
        XCTAssertEqual(dragoonWave, 6)
        XCTAssertEqual(officerWave, 7)
        for (enemy, firstWave, maximumCount) in [(ranger, rangerWave, 4), (dragoon, dragoonWave, 4), (officer, officerWave, 1)] {
            let introduction = level.waves[firstWave].spawns.filter { $0.enemyTypeID == enemy.id }
            XCTAssertLessThanOrEqual(introduction.reduce(0) { $0 + $1.count }, maximumCount)
            XCTAssertEqual(Set(introduction.map(\.pathIndex)).count, 1, "Teach each active ability on one approach")
            let route = try XCTUnwrap(introduction.first?.pathIndex)
            XCTAssertGreaterThan(level.paths[route].totalLength, level.paths[1].totalLength,
                "Give the first specialist packet more response time than the short upper road")
        }
        let familiarRoutes = Set(level.waves.prefix(rangerWave).flatMap { $0.spawns.map(\.pathIndex) })
        let firstRangers = level.waves[rangerWave].spawns.filter { $0.enemyTypeID == ranger.id }
        XCTAssertTrue(firstRangers.allSatisfy { familiarRoutes.contains($0.pathIndex) },
            "Concealment should first appear on a road the player has already defended")
        XCTAssertTrue(level.waves.suffix(3).contains { $0.spawns.contains { $0.enemyTypeID == dragoon.id } })
    }

    func testFinalSiegeBossArrivesBeforeEscortsOnTheLongestRoad() throws {
        let db = openAuthoredDatabase()
        defer { db.close() }
        let level = try db.levelLoader.load(id: levelID)
        let enemies = try db.enemyTypeDao.getAll()
        let clinton = try XCTUnwrap(enemies.first { $0.key == "clinton_siege" })
        let barrage = try XCTUnwrap(clinton.bossRules)
        XCTAssertGreaterThan(barrage.barrageRange, 0)
        XCTAssertGreaterThan(barrage.barrageWindup, 0, "The siege barrage needs a visible warning")
        XCTAssertGreaterThan(barrage.barrageDamage, 0)
        XCTAssertGreaterThanOrEqual(clinton.stats.livesCost, level.numStartingLives)
        let bossIDs = Set(enemies.filter { $0.bossRules != nil }.map(\.id))
        XCTAssertFalse(level.waves.dropLast().contains { $0.spawns.contains { bossIDs.contains($0.enemyTypeID) } })

        let final = try XCTUnwrap(level.waves.last)
        let bosses = final.spawns.filter { bossIDs.contains($0.enemyTypeID) }
        XCTAssertEqual(bosses.count, 1)
        let boss = try XCTUnwrap(bosses.first)
        XCTAssertEqual(boss.enemyTypeID, clinton.id)
        XCTAssertEqual(boss.count, 1)
        let longestRoad = try XCTUnwrap(level.paths.indices.max { level.paths[$0].totalLength < level.paths[$1].totalLength })
        XCTAssertEqual(boss.pathIndex, longestRoad)
        XCTAssertLessThanOrEqual(boss.delay, 10, "The slow siege train must not begin after the assault has finished")
        XCTAssertTrue(final.spawns.contains { $0.enemyTypeID != clinton.id && $0.pathIndex == boss.pathIndex && $0.delay > boss.delay },
            "The boss needs an escort on its own road")
        let lastSpawn = try XCTUnwrap(final.spawns.map { $0.delay + Double($0.count - 1) * $0.interval }.max())
        XCTAssertGreaterThanOrEqual(lastSpawn - boss.delay, 30, "Keep escort and flank pressure after the boss arrives")
        let concealedIDs = Set(enemies.filter { $0.concealmentRules != nil }.map(\.id))
        XCTAssertFalse(final.spawns.contains { concealedIDs.contains($0.enemyTypeID) },
            "The finale should let heroes focus on the siege-blocking task")
        XCTAssertEqual(Set(final.spawns.map(\.pathIndex)), [0, 1, 2, 3, 4, 5])
    }
}
