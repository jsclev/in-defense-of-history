import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EngineerObstacleTests: XCTestCase {
    func testBroadRectangleFollowsRoadDirectionWithoutChangingThePath() throws {
        let stats = try XCTUnwrap(AuthoredDatabaseFixture.tower(.special, level: 1, branch: 1).engineerObstacles)
        let road = Path(points: [Point(300, 0), Point(300, 1000)])
        let field = EngineerObstacleField(position: CGPoint(x: 300, y: 500), stats: stats, paths: [road])
        XCTAssertEqual(field.heading, .pi / 2, accuracy: 1e-8)
        XCTAssertTrue(field.contains(CGPoint(x: 380, y: 640)), "The broad corner used to fall outside the mud ellipse")
        XCTAssertFalse(field.contains(CGPoint(x: 390, y: 500)), "Must regain speed beyond the side edge")
        XCTAssertFalse(field.contains(CGPoint(x: 300, y: 644)), "Must regain speed beyond the end")
        let diagonal = Path(points: [Point(0, 0), Point(1000, 1000)])
        let diagonalField = EngineerObstacleField(position: CGPoint(x: 500, y: 500), stats: stats, paths: [diagonal])
        XCTAssertEqual(diagonalField.heading, .pi / 4, accuracy: 1e-8)
        XCTAssertTrue(diagonalField.contains(CGPoint(x: 500, y: 620)))
        XCTAssertFalse(diagonalField.contains(CGPoint(x: 500, y: 630)))
        XCTAssertEqual(road.points, [Point(300, 0), Point(300, 1000)])
        XCTAssertEqual(diagonal.points, [Point(0, 0), Point(1000, 1000)])
    }

    func testRoadMaskUsesAuthoredWidthHolesAndChangedGeometry() throws {
        func road(width: Double) throws -> HeroMovementArea {
            let outer = [[0.0, -width / 2], [1000, -width / 2], [1000, width / 2],
                         [0, width / 2], [0, -width / 2]]
            let hole = [[490.0, 10], [510, 10], [510, 20], [490, 20], [490, 10]]
            let data = try JSONSerialization.data(withJSONObject: ["features": [[
                "properties": ["category": "gameplay", "kind": "enemy_path"],
                "geometry": ["type": "Polygon", "coordinates": [outer, hole]]]]])
            return try HeroMovementArea(geoJSON: data, defaultPathWidth: 999)
        }
        let narrow = try road(width: 80), wide = try road(width: 180)
        let stats = try XCTUnwrap(AuthoredDatabaseFixture.tower(.special, level: 3, branch: 1).engineerObstacles)
        let field = EngineerObstacleField(position: CGPoint(x: 500, y: 0), stats: stats, heading: 0)
        for scale in [0.25, 1.0, 3.0] {
            var transform = field.worldToArtwork(scale: scale)
            let mask = try XCTUnwrap(narrow.boundaryPath.copy(using: &transform))
            let widerMask = try XCTUnwrap(wide.boundaryPath.copy(using: &transform))
            let offNarrowRoad = CGPoint(x: 500, y: 70)
            XCTAssertTrue(field.contains(offNarrowRoad), "Reproduces the old upgrade overflow")
            XCTAssertFalse(mask.contains(offNarrowRoad.applying(transform), using: .evenOdd))
            XCTAssertTrue(widerMask.contains(offNarrowRoad.applying(transform), using: .evenOdd),
                          "Changing GeoJSON width must change the mask without a tower size change")
            XCTAssertFalse(mask.contains(CGPoint(x: 500, y: 15).applying(transform), using: .evenOdd))
            XCTAssertTrue(mask.contains(field.position.applying(transform), using: .evenOdd))
        }
    }

    func testCharlestonRoadMaskFitsEverySlotAndUpgradeAndPreservesEnemyCoverage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let db = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false,
                    levelGeoJSONDao: LevelGeoJSONDAO(directory: root.appendingPathComponent("Db")))
        defer { db.close() }
        let level = try db.levelLoader.load(id: UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!)
        let area = try db.levelGeoJSONDao.getHeroMovementArea(mapImageName: level.mapImageName, defaultPathWidth: 140)
        let types = try db.towerTypeDao.getTowerLevelsByBranch()
        let first = try XCTUnwrap(types[.special]?[1]?[1])
        let fourth = try XCTUnwrap(types[.special]?[4]?[2])
        var upgrades = TowerUpgradeProgress(), budget = 10_000
        for path in fourth.upgradePaths {
            for _ in path.ranks { XCTAssertEqual(upgrades.purchase(pathID: path.id, from: fourth, money: &budget), .ok) }
        }
        let tuning = try (1...3).map { try XCTUnwrap(types[.special]?[$0]?[1]) }
            + [fourth, fourth.upgraded(with: upgrades)]
        var overflowCases = 0
        for slot in level.towerSlots {
            let position = CGPoint(x: slot.position.x, y: slot.position.y)
            let site = try XCTUnwrap(first.attackRange.nearestPathPoint(to: position, from: position, paths: level.paths))
            for tier in tuning {
                let field = EngineerObstacleField(position: site,
                    stats: try XCTUnwrap(tier.engineerObstacles), paths: level.paths)
                var transform = field.worldToArtwork(scale: 340.0 / 1080)
                let mask = try XCTUnwrap(area.boundaryPath.copy(using: &transform))
                let center = site.applying(transform)
                XCTAssertEqual(center.x, field.size.width * 340 / 1080 / 2, accuracy: 1e-8)
                XCTAssertEqual(center.y, field.size.height * 340 / 1080 / 2, accuracy: 1e-8)
                var overflow = false
                for x in stride(from: 0.5, to: field.size.width * 340 / 1080, by: 2) {
                    for y in stride(from: 0.5, to: field.size.height * 340 / 1080, by: 2) {
                        let local = CGPoint(x: x, y: y)
                        let world = local.applying(transform.inverted())
                        let onRoad = area.contains(Point(world.x, world.y))
                        XCTAssertEqual(mask.contains(local, using: .evenOdd), onRoad)
                        if !onRoad { overflow = true }
                    }
                }
                if overflow { overflowCases += 1 }
                for path in level.paths {
                    for distance in stride(from: 0.0, through: path.totalLength, by: 3) {
                        let point = path.point(atDistance: distance)
                        let world = CGPoint(x: point.x, y: point.y)
                        if field.contains(world) {
                            XCTAssertTrue(mask.contains(world.applying(transform), using: .evenOdd),
                                          "Road mask hid a slowed enemy location at \(point)")
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(overflowCases, 50, "The real map must exercise the upgrade overflow regression")
        XCTAssertEqual(level.towerSlots.count * tuning.count, 95)
    }

    func testFootprintOverlapAndRetreat() {
        let fields = [0.2, 0.3, 0.4].map {
            EngineerObstacleField(position: .zero, stats: .init(radius: 100, slowFraction: $0, widthFraction: 0.7), heading: 0)
        }
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: false, fields: fields), 0.6)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: CGPoint(x: 100, y: 0), retreating: false, fields: fields), 0.6)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: CGPoint(x: 0, y: 71), retreating: false, fields: fields), 1)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: true, fields: fields), 1)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: .zero, retreating: false, fields: []), 1)
    }

    @MainActor func testAuthoredProgressionAndRealSimulationMovement() throws {
        let db = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false)
        defer { db.close() }
        let type = try XCTUnwrap(db.towerTypeDao.getTowerTypes()[.special])
        XCTAssertEqual(type.levels.map(\.cost), [100, 150, 220])
        XCTAssertEqual(type.levels.map { $0.engineerObstacles?.radius }, [143, 183, 223])
        XCTAssertEqual(type.levels.map { $0.engineerObstacles?.slowFraction }, [0.5, 0.6, 0.7])
        XCTAssertTrue(type.levels.allSatisfy { $0.shotMaxDamage == 0 && $0.terrorMax == 0 && $0.fireInterval == 0 })
        let branches = try db.towerTypeDao.getTowerLevelsByBranch()
        XCTAssertEqual(branches[.special]?[4]?[2]?.engineerObstacles, type.levels[2].engineerObstacles)
        XCTAssertNil(branches[.special]?[4]?[3]?.engineerObstacles)
        let enemy = try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()).type(.loyalistMilitia)
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(0, 40)], money: 1000)
        let sim = try GameSimulation(content: BattleTestFixture.content(level: level, enemies: [enemy]),
                                     startingMoney: nil, heroesEnabled: false, seed: 1)
        try BattleTestFixture.build(.special, in: sim)
        sim.startNextWave()
        XCTAssertEqual(sim.gold, 900)
        XCTAssertEqual(sim.engine.placedTower(atSlot: 0)?.engineerObstaclePosition, .zero)
        for tier in 0..<3 {
            if tier > 0 { XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok) }
            let before = sim.engine.walkers.first?.pathDistance ?? 0
            sim.step()
            let after = try XCTUnwrap(sim.engine.walkers.first)
            XCTAssertEqual(after.pathDistance - before, enemy.stats.speed * SimClock.dt * (0.5 - Double(tier) * 0.1), accuracy: 1e-8)
            XCTAssertEqual(after.hp, enemy.stats.maxHP)
            XCTAssertEqual(sim.engine.placedTower(atSlot: 0)?.engineerObstaclePosition, .zero)
        }
        XCTAssertEqual(sim.gold, 530)
        _ = sim.perform(.placeObstacles(slot: 0, point: Point(250, 30)))
        XCTAssertEqual(sim.engine.placedTower(atSlot: 0)?.engineerObstaclePosition, CGPoint(x: 250, y: 0))
        _ = sim.perform(.placeObstacles(slot: 0, point: Point(9999, 0)))
        XCTAssertEqual(sim.engine.placedTower(atSlot: 0)?.engineerObstaclePosition, CGPoint(x: 250, y: 0))
        let before = try XCTUnwrap(sim.engine.walkers.first).pathDistance
        sim.step()
        XCTAssertEqual(try XCTUnwrap(sim.engine.walkers.first).pathDistance - before, enemy.stats.speed * SimClock.dt, accuracy: 1e-8)
        _ = sim.perform(.placeObstacles(slot: -1, point: .zero))
        _ = sim.perform(.placeObstacles(slot: 999, point: .zero))
    }

    @MainActor func testUpgradeCanReachANewLaneWithoutInventingAnUnreachableField() throws {
        let fixture = try AuthoredDatabaseFixture()
        var type = try XCTUnwrap(fixture.db.towerTypeDao.getTowerTypes()[.special])
        type.levels[0].range = 100
        type.levels[0].engineerObstacles = .init(radius: 30, slowFraction: 0.2, widthFraction: 0.7)
        type.levels[1].range = 300
        type.levels[1].engineerObstacles = .init(radius: 60, slowFraction: 0.3, widthFraction: 0.7)
        let enemy = try XCTUnwrap(fixture.db.enemyTypeDao.getAll().first)
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(0, 0)], starts: [Point(0, 200)])
        let content = try BattleTestFixture.content(level: level, enemies: [enemy],
            tiers: [.init(.special, 1): type.levels[0], .init(.special, 2): type.levels[1]])
        let sim = try GameSimulation(content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
        try BattleTestFixture.build(.special, in: sim)
        XCTAssertTrue(sim.engine.engineerObstacleFields.isEmpty)
        XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok)
        XCTAssertEqual(sim.engine.placedTower(atSlot: 0)?.engineerObstaclePosition, CGPoint(x: 0, y: 200))
    }

    func testOptionalTuningRoundTripsWithoutChangingOldTowers() throws {
        let old = try AuthoredDatabaseFixture.tower(.ranged, level: 1, branch: 1)
        XCTAssertNil(try JSONDecoder().decode(TowerLevel.self, from: JSONEncoder().encode(old)).engineerObstacles)
        let new = try AuthoredDatabaseFixture.tower(.special, level: 1, branch: 1)
        XCTAssertEqual(try JSONDecoder().decode(TowerLevel.self, from: JSONEncoder().encode(new)), new)
    }
}
