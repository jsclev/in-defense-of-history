import XCTest
import SQLite3
@testable import LevelEditorFormats

final class BattleFixedGeometryTests: XCTestCase {
    @MainActor private func engine(_ content: BattleContent? = nil) throws -> BattleEngine {
        try BattleEngine(recording: .preview, content: content ?? BattleTestFixture.authored(),
            heroesEnabled: false, startingMoneyOverride: 100_000, seed: 1776, onVictory: { _, _ in 0 })
    }
    private func bits(_ point: Point) -> [UInt64] { [point.x.bitPattern, point.y.bitPattern] }

    @MainActor private func assertMilitia(_ engine: BattleEngine, file: StaticString = #filePath, line: UInt = #line) {
        let geometry = engine.fixedMilitiaGeometry()
        let expected = engine.meleeFormation.sharedPosts(squads: engine.garrisonsBySlot.map {
            (slot: $0.key, rallyPoint: $0.value.rallyPoint, count: $0.value.units.count)
        })
        XCTAssertEqual(geometry.slots, engine.garrisonsBySlot.keys.sorted(), file: file, line: line)
        XCTAssertEqual(geometry.posts.mapValues { $0.map(bits) }, expected.mapValues { $0.map(bits) }, file: file, line: line)
        for (slot, garrison) in engine.garrisonsBySlot {
            let path = engine.pathNearest(to: garrison.rallyPoint)
            XCTAssertEqual(geometry.marches[slot]?.path, path, file: file, line: line)
            XCTAssertEqual(geometry.marches[slot]?.targetAlong?.bitPattern,
                           path?.nearestDistance(to: garrison.rallyPoint).bitPattern, file: file, line: line)
        }
    }

    @MainActor func testMilitiaCacheTracksSharedFlagsCountsMembershipAndPaths() throws {
        let engine = try engine()
        engine.paths = [Path(points: [Point(-100, 0), Point(100, 0), Point(100, 200)]),
                        Path(points: [Point(-100, 20), Point(100, 20), Point(300, 20)])]
        let units = (0..<3).map { _ in MilitiaUnit(position: .zero, hp: 100) }
        engine.garrisonsBySlot = [2: .init(rallyPoint: Point(40, 10), units: units),
                                  -1: .init(rallyPoint: Point(40, 10), units: units)]
        assertMilitia(engine)
        var previous = engine.fixedMilitiaGeometry()
        // Equal-distance paths retain the original first-path tie break.
        XCTAssertEqual(previous.marches[2]?.path, engine.paths[0])
        XCTAssertEqual(Set(previous.posts[2]! + previous.posts[-1]!).count, 6)
        engine.garrisonsBySlot[2]!.units[0].position = Point(70, 15)
        engine.garrisonsBySlot[2]!.units[0].state = .dead
        engine.garrisonsBySlot[2]!.units[0].hp = 0
        XCTAssertTrue(previous === engine.fixedMilitiaGeometry())
        engine.garrisonsBySlot[2]!.units[0] = MilitiaUnit(position: .zero, hp: 100)
        XCTAssertTrue(previous === engine.fixedMilitiaGeometry(), "Respawning changes no fixed geometry")

        engine.garrisonsBySlot[2]!.rallyPoint = Point(60, 20)
        XCTAssertFalse(previous === engine.fixedMilitiaGeometry()); assertMilitia(engine)
        previous = engine.fixedMilitiaGeometry()
        engine.garrisonsBySlot[2]!.units.append(MilitiaUnit(position: .zero, hp: 100))
        XCTAssertFalse(previous === engine.fixedMilitiaGeometry()); assertMilitia(engine)
        previous = engine.fixedMilitiaGeometry()
        engine.garrisonsBySlot[-1] = nil
        engine.garrisonsBySlot[-2] = .init(rallyPoint: Point(60, 20), units: units)
        XCTAssertFalse(previous === engine.fixedMilitiaGeometry(), "Same squad count, different membership")
        assertMilitia(engine)
        previous = engine.fixedMilitiaGeometry()
        engine.paths.reverse()
        XCTAssertFalse(previous === engine.fixedMilitiaGeometry()); assertMilitia(engine)
        previous = engine.fixedMilitiaGeometry()
        engine.paths = []
        XCTAssertFalse(previous === engine.fixedMilitiaGeometry()); assertMilitia(engine)
        XCTAssertNil(engine.fixedMilitiaGeometry().marches[2]?.path)
        engine.garrisonsBySlot.removeAll()
        XCTAssertTrue(engine.fixedMilitiaGeometry().posts.isEmpty)
        XCTAssertTrue(engine.fixedMilitiaGeometry().marches.isEmpty)
    }

    @MainActor func testMilitiaCachePreservesSignedZeroAndIsIsolatedBetweenBattles() throws {
        let first = try engine(), second = try engine()
        let units = [MilitiaUnit(position: .zero, hp: 100)]
        first.garrisonsBySlot[1] = .init(rallyPoint: Point(-0.0, 0), units: units)
        second.garrisonsBySlot = first.garrisonsBySlot
        let original = first.fixedMilitiaGeometry()
        XCTAssertFalse(original === second.fixedMilitiaGeometry())
        XCTAssertEqual(original.posts[1]!.map(bits), [bits(Point(-0.0, 0))])
        first.garrisonsBySlot[1]!.rallyPoint.x = 0.0
        XCTAssertFalse(original === first.fixedMilitiaGeometry())
        assertMilitia(first); assertMilitia(second)
    }

    @MainActor private func assertObstacles(_ engine: BattleEngine, file: StaticString = #filePath, line: UInt = #line) {
        let geometry = engine.fixedObstacleGeometry()
        let expected = engine.placedTowers.compactMap { engine.engineerObstacleField(for: $0) }
        XCTAssertEqual(geometry.fields, expected, file: file, line: line)
        XCTAssertEqual(geometry.fields.map { $0.heading.bitPattern }, expected.map { $0.heading.bitPattern }, file: file, line: line)
        XCTAssertEqual(geometry.fields.map { Double($0.position.x).bitPattern }, expected.map { Double($0.position.x).bitPattern }, file: file, line: line)
        XCTAssertEqual(geometry.slots, engine.placedTowers.filter { engine.engineerObstacleField(for: $0) != nil }.map(\.slotIndex), file: file, line: line)
        for point in [CGPoint.zero, CGPoint(x: 50, y: 30), CGPoint(x: 130, y: 40)] {
            XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: point, retreating: false, fields: geometry.fields).bitPattern,
                           EngineerObstacleField.movementMultiplier(at: point, retreating: false, fields: expected).bitPattern, file: file, line: line)
        }
    }

    @MainActor func testObstacleCacheTracksPlacementAllTiersRanksOrderingAndLoadedTuning() throws {
        let engine = try engine()
        engine.paths = [Path(points: [Point(-100, 0), Point(100, 0), Point(100, 250)])]
        let family = try XCTUnwrap(engine.content.arsenal.towers.first { $0.kind == .special })
        for tier in family.tiers {
            var tower = PlacedTower(combatRules: engine.combatRules, slotIndex: 0, kind: .special,
                position: CGPoint(x: 30, y: 50), level: tier.level, branch: tier.branch)
            tower.engineerObstaclePosition = CGPoint(x: 90, y: 0)
            engine.placedTowers = [tower]; assertObstacles(engine)
            for path in tier.tuning.upgradePaths {
                var money = 100_000
                for _ in path.ranks {
                    let before = engine.fixedObstacleGeometry()
                    XCTAssertEqual(tower.upgrades.purchase(pathID: path.id, from: tier.tuning, money: &money), .ok)
                    engine.placedTowers = [tower]
                    XCTAssertFalse(before === engine.fixedObstacleGeometry()); assertObstacles(engine)
                }
            }
        }
        var tower = PlacedTower(combatRules: engine.combatRules, slotIndex: 0, kind: .special, position: .zero)
        tower.engineerObstaclePosition = CGPoint(x: 90, y: 0)
        engine.placedTowers = [tower]
        var previous = engine.fixedObstacleGeometry()
        engine.placedTowers[0].artilleryAim.track(from: .zero, to: CGPoint(x: 100, y: 100), radiansPerSecond: 1, deltaTime: 1)
        engine.money += 1
        XCTAssertTrue(previous === engine.fixedObstacleGeometry())
        engine.placedTowers[0].engineerObstaclePosition = CGPoint(x: 100, y: 80)
        XCTAssertFalse(previous === engine.fixedObstacleGeometry()); assertObstacles(engine)
        previous = engine.fixedObstacleGeometry()
        engine.pricedTowerLevels[.special]![1]![1]!.engineerObstacles!.radius += 15
        engine.pricedTowerLevels[.special]![1]![1]!.engineerObstacles!.slowFraction -= 0.1
        engine.pricedTowerLevels[.special]![1]![1]!.engineerObstacles!.widthFraction -= 0.1
        XCTAssertFalse(previous === engine.fixedObstacleGeometry()); assertObstacles(engine)
        previous = engine.fixedObstacleGeometry()
        engine.paths = [Path(points: [Point(0, -100), Point(0, 300)])]
        XCTAssertFalse(previous === engine.fixedObstacleGeometry()); assertObstacles(engine)
        var second = PlacedTower(combatRules: engine.combatRules, slotIndex: 1, kind: .special, position: .zero)
        second.engineerObstaclePosition = CGPoint(x: 0, y: 150)
        engine.placedTowers.append(second)
        previous = engine.fixedObstacleGeometry()
        engine.placedTowers.reverse()
        XCTAssertFalse(previous === engine.fixedObstacleGeometry()); assertObstacles(engine)
        engine.placedTowers[0].engineerObstaclePosition = nil
        assertObstacles(engine)
        engine.placedTowers.removeAll()
        XCTAssertTrue(engine.engineerObstacleFields.isEmpty)
    }

    @MainActor func testObstacleCacheReloadsDatabaseEditsAndRetainsIndependentOldBattle() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let first = try engine(BattleTestFixture.authored(db: fixture.db).selectingMetaUpgrades([]))
        var tower = PlacedTower(combatRules: first.combatRules, slotIndex: 0, kind: .special, position: .zero)
        tower.engineerObstaclePosition = CGPoint(x: first.paths[0].points[0].x, y: first.paths[0].points[0].y)
        first.placedTowers = [tower]
        let original = first.fixedObstacleGeometry()
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE tower SET obstacle_radius=obstacle_radius+17 WHERE has_engineer_obstacles=1", nil, nil, nil), SQLITE_OK)
        let second = try engine(BattleTestFixture.authored(db: fixture.db).selectingMetaUpgrades([]))
        second.placedTowers = [tower]
        XCTAssertEqual(second.engineerObstacleFields[0].stats.radius, original.fields[0].stats.radius + 17)
        XCTAssertTrue(original === first.fixedObstacleGeometry())
        assertObstacles(first); assertObstacles(second)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints=ON; UPDATE tower SET obstacle_radius=NULL WHERE has_engineer_obstacles=1", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try BattleTestFixture.authored(db: fixture.db))
    }

    // Independent linear lookup and the pre-cache projection formula provide a
    // bit-level oracle for ties, duplicate vertices, endpoints and round trips.
    private func referencePoint(_ path: Path, _ distance: Double) -> Point {
        if distance <= 0 { return path.points[0] }
        if distance >= path.totalLength { return path.points.last! }
        let lo = (0..<(path.points.count - 1)).last { path.cumulative[$0] <= distance }!
        let length = path.cumulative[lo + 1] - path.cumulative[lo]
        return Point.lerp(path.points[lo], path.points[lo + 1], length > 0 ? (distance - path.cumulative[lo]) / length : 0)
    }
    private func referenceNearest(_ path: Path, _ target: Point) -> Double {
        var best = 0.0, gap = Double.infinity
        for i in 1..<path.points.count {
            let a = path.points[i - 1], b = path.points[i]
            let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
            var t = 0.0
            if length > 0 { t = min(max(((target.x - a.x) * dx + (target.y - a.y) * dy) / length, 0), 1) }
            let candidate = Point(a.x + dx * t, a.y + dy * t).distance(to: target)
            if candidate < gap {
                gap = candidate
                best = path.cumulative[i - 1] + (path.cumulative[i] - path.cumulative[i - 1]) * t
            }
        }
        return best
    }

    @MainActor func testPreparedPathSegmentsPreserveEveryBitAndSerializedFormat() throws {
        var random = SeededRNG(seed: 1776)
        let paths = try BattleTestFixture.authored().level.paths + [
            Path(points: [Point(-0.0, -0.0), .zero, Point(100, 0), Point(100, 0), Point(100, 100), .zero]),
            Path(points: [.zero, .zero]),
            Path(points: (0..<150).map { _ in Point(random.double(in: -3000...3000), random.double(in: -3000...3000)) })]
        for path in paths {
            let encoded = try JSONEncoder().encode(path)
            XCTAssertEqual(Set(try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any]).keys), ["points"])
            let restored = try JSONDecoder().decode(Path.self, from: encoded)
            for route in [path, restored] {
                let distances = route.cumulative.flatMap { [$0.nextDown, $0, $0.nextUp] }
                    + (0..<200).map { _ in random.double(in: -100...(route.totalLength + 100)) }
                for distance in distances {
                    XCTAssertEqual(bits(route.point(atDistance: distance)), bits(referencePoint(route, distance)))
                }
                let targets = route.points + (0..<200).map { _ in Point(random.double(in: -5000...5000), random.double(in: -5000...5000)) }
                for target in targets {
                    XCTAssertEqual(route.nearestDistance(to: target).bitPattern, referenceNearest(route, target).bitPattern)
                }
            }
        }
    }
}
