import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EngineerObstacleTests: XCTestCase {
    func testFootprintOverlapAndRetreat() {
        let fields = [0.2, 0.3, 0.4].map {
            EngineerObstacleField(position: .zero, stats: .init(radius: 100, slowFraction: $0))
        }
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: false, fields: fields), 0.6)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: CGPoint(x: 100, y: 0), retreating: false, fields: fields), 0.6)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: CGPoint(x: 0, y: 71), retreating: false, fields: fields), 1)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: true, fields: fields), 1)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: false, fields: []), 1)
    }

    func testAuthoredProgressionAndRealSimulationMovement() throws {
        let db = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false)
        defer { db.close() }
        let type = try XCTUnwrap(db.towerTypeDao.getTowerTypes()["Special"])
        XCTAssertEqual(type.levels.map(\.cost), [100, 150, 220])
        XCTAssertEqual(type.levels.map { $0.engineerObstacles?.radius }, [90, 115, 140])
        XCTAssertEqual(type.levels.map { $0.engineerObstacles?.slowFraction }, [0.2, 0.3, 0.4])
        XCTAssertTrue(type.levels.allSatisfy { $0.shotMaxDamage == 0 && $0.terrorMax == 0 && $0.fireInterval == 0 })
        let branches = try db.towerTypeDao.getTowerLevelsByBranch()
        XCTAssertEqual(branches["Special"]?[4]?[2]?.engineerObstacles, type.levels[2].engineerObstacles)
        XCTAssertNil(branches["Special"]?[4]?[3]?.engineerObstacles)
        let enemy = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.loyalistMilitia)
        let level = LevelInfo(id: UUID(), name: "Obstacles", campaign: Campaign(id: UUID(), name: "Test"),
            startedAt: Date(), endedAt: Date(), startingMoney: 1000, numStartingLives: 10,
            playArea: CGRect(x: 0, y: 0, width: 1000, height: 500),
            paths: [Path(points: [Point(0, 0), Point(1000, 0)])],
            towerSlots: [TowerSlot(id: UUID(), position: Point(0, 40))],
            waves: [Wave(startTime: 0, spawns: [SpawnEntry(enemyTypeID: enemy.id, count: 1, interval: 1)])])
        let sim = try Simulation(level: level, catalog: ContentCatalog(enemyTypes: [enemy], towerTypes: [type]),
                                 policy: IdleCommander(), seed: 1)
        XCTAssertEqual(sim.build(slot: 0, towerID: type.id), .ok)
        XCTAssertEqual(sim.gold, 900)
        XCTAssertEqual(sim.engineerObstaclePositions[0], .zero)
        for tier in 0..<3 {
            if tier > 0 { XCTAssertEqual(sim.upgrade(slot: 0), .ok) }
            let before = sim.enemies.first?.distance ?? 0
            sim.step()
            let after = try XCTUnwrap(sim.enemies.first)
            XCTAssertEqual(after.distance - before, enemy.stats.speed * SimClock.dt * (0.8 - Double(tier) * 0.1), accuracy: 1e-8)
            XCTAssertEqual(after.hp, enemy.stats.maxHP)
            XCTAssertEqual(sim.engineerObstaclePositions[0], .zero)
        }
        XCTAssertEqual(sim.gold, 530)
        sim.setEngineerObstacles(slot: 0, to: CGPoint(x: 250, y: 30))
        XCTAssertEqual(sim.engineerObstaclePositions[0], CGPoint(x: 250, y: 0))
        sim.setEngineerObstacles(slot: 0, to: CGPoint(x: 9999, y: 0))
        XCTAssertEqual(sim.engineerObstaclePositions[0], CGPoint(x: 250, y: 0))
        let before = try XCTUnwrap(sim.enemies.first).distance
        sim.step()
        XCTAssertEqual(try XCTUnwrap(sim.enemies.first).distance - before, enemy.stats.speed * SimClock.dt, accuracy: 1e-8)
        sim.setEngineerObstacles(slot: -1, to: .zero)
        sim.setEngineerObstacles(slot: 999, to: .zero)
    }

    func testUpgradeCanReachANewLaneWithoutInventingAnUnreachableField() throws {
        let fixture = try AuthoredDatabaseFixture()
        var type = try XCTUnwrap(fixture.db.towerTypeDao.getTowerTypes()["Special"])
        type.levels[0].range = 100
        type.levels[0].engineerObstacles = .init(radius: 30, slowFraction: 0.2)
        type.levels[1].range = 300
        type.levels[1].engineerObstacles = .init(radius: 60, slowFraction: 0.3)
        let level = LevelInfo(id: UUID(), name: "Reach", campaign: Campaign(id: UUID(), name: "Test"),
            startedAt: Date(), endedAt: Date(), startingMoney: 1000, numStartingLives: 10,
            playArea: CGRect(x: 0, y: 0, width: 1000, height: 500),
            paths: [Path(points: [Point(0, 200), Point(1000, 200)])],
            towerSlots: [TowerSlot(id: UUID(), position: Point(0, 0))], waves: [])
        let sim = try Simulation(level: level, catalog: ContentCatalog(enemyTypes: [], towerTypes: [type]),
                                 policy: IdleCommander(), seed: 1)
        XCTAssertEqual(sim.build(slot: 0, towerID: type.id), .ok)
        XCTAssertTrue(sim.engineerObstacleFields.isEmpty)
        XCTAssertEqual(sim.upgrade(slot: 0), .ok)
        XCTAssertEqual(sim.engineerObstaclePositions[0], CGPoint(x: 0, y: 200))
    }

    func testOptionalTuningRoundTripsWithoutChangingOldTowers() throws {
        let old = try AuthoredDatabaseFixture.tower("Ranged", level: 1, branch: 1)
        XCTAssertNil(try JSONDecoder().decode(TowerLevel.self, from: JSONEncoder().encode(old)).engineerObstacles)
        let new = try AuthoredDatabaseFixture.tower("Special", level: 1, branch: 1)
        XCTAssertEqual(try JSONDecoder().decode(TowerLevel.self, from: JSONEncoder().encode(new)), new)
    }
}
