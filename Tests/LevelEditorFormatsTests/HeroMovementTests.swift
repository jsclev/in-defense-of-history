import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class HeroMovementTests: XCTestCase {
    private func area(_ geometry: [String: Any], width: Double? = nil) throws -> HeroMovementArea {
        var properties: [String: Any] = ["category": "gameplay", "kind": "enemy_path"]
        if let width { properties["widthPx"] = width }
        return try HeroMovementArea(geoJSON: JSONSerialization.data(withJSONObject: [
            "features": [["properties": properties, "geometry": geometry]]
        ]), defaultPathWidth: 20)
    }
    private func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> [[Double]] {
        [[x,y],[x+w,y],[x+w,y+h],[x,y+h],[x,y]]
    }
    private var context: MilitiaContext {
        MilitiaContext(freeEnemies: [], targetPosition: nil, rallyPoint: .zero,
                       towerPosition: .zero, leashRadius: 130, engageScanRadius: 80)
    }
    private func walk(_ movement: inout HeroMovement, _ unit: inout MilitiaUnit,
                      to target: Point, speed: Double = 73,
                      file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<20000 {
            let previous = unit.position
            _ = movement.update(&unit, context: context, moveSpeed: speed, deltaTime: SimClock.dt)
            XCTAssertTrue(movement.area.contains(unit.position), file: file, line: line)
            XCTAssertLessThanOrEqual(previous.distance(to: unit.position), speed * SimClock.dt + 1e-7, file: file, line: line)
            if unit.position == target, unit.state == .holding { return }
        }
        XCTFail("Hero stalled at \(unit.position), expected \(target)", file: file, line: line)
    }

    func testMovesToExactOffCenterAndSubTwoUnitDestinations() throws {
        let ground = try area(["type": "LineString", "coordinates": [[0,0],[200,0]]])
        var movement = try HeroMovement(area: ground, spawn: Point(10, 0))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        for destination in [Point(150.25, 8.5), Point(151, 8.75), Point(151.1, 8.75), Point(10, -8)] {
            XCTAssertTrue(movement.command(to: destination, unit: &unit))
            walk(&movement, &unit, to: destination)
            XCTAssertEqual(unit.position, destination)
        }
    }

    func testRejectedCommandsKeepExistingOrderAndCombatState() throws {
        let ground = try area(["type": "MultiPolygon", "coordinates": [[box(0, 0, 100, 100)], [box(120, 0, 100, 100)]]])
        var movement = try HeroMovement(area: ground, spawn: Point(20, 20))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        XCTAssertTrue(movement.command(to: Point(80, 80), unit: &unit))
        for destination in [Point(110, 50), Point(150, 50), Point(.nan, 50), Point(50, .infinity)] {
            XCTAssertFalse(movement.command(to: destination, unit: &unit))
            XCTAssertEqual(movement.station, Point(80, 80))
            XCTAssertEqual(unit.position, Point(20, 20))
        }
        walk(&movement, &unit, to: Point(80, 80))
        unit.state = .fighting; unit.targetSpawnID = 42
        XCTAssertFalse(movement.command(to: Point(110, 50), unit: &unit))
        XCTAssertEqual(unit.state, .fighting); XCTAssertEqual(unit.targetSpawnID, 42)
        XCTAssertTrue(movement.command(to: Point(20, 20), unit: &unit))
        XCTAssertEqual(unit.state, .returning); XCTAssertEqual(unit.targetSpawnID, -1)
        unit.state = .dead
        XCTAssertFalse(movement.command(to: Point(80, 80), unit: &unit))
    }

    func testWalksAroundHoleAndDoesNotCrossThinExclusions() throws {
        let ground = try area(["type": "Polygon", "coordinates": [box(0, 0, 200, 100), box(99.9, 10, 0.2, 80)]])
        XCTAssertFalse(ground.contains(Point(100, 50)))
        XCTAssertFalse(ground.containsSegment(from: Point(10, 50), to: Point(190, 50)))
        let route = try XCTUnwrap(ground.route(from: Point(10, 50), to: Point(190, 50)))
        for (a, b) in zip([Point(10, 50)] + route, route) {
            XCTAssertTrue(ground.containsSegment(from: a, to: b))
            // Independent rectangle check: a segment crossing x=100 must go above/below the hole.
            if min(a.x, b.x) < 100, max(a.x, b.x) > 100 {
                let y = a.y + (b.y - a.y) * (100 - a.x) / (b.x - a.x)
                XCTAssertTrue(y <= 10 || y >= 90)
            }
        }
        var movement = try HeroMovement(area: ground, spawn: Point(10, 50))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        XCTAssertTrue(movement.command(to: Point(190, 50), unit: &unit))
        walk(&movement, &unit, to: Point(190, 50))
    }

    func testNarrowBentPassageUsesBoundaryRouteInsteadOfBecomingUnreachable() throws {
        let ground = try area(["type": "Polygon", "coordinates": [
            [[1,1],[102,1],[102,102],[101,102],[101,2],[1,2],[1,1]]
        ]])
        let start = Point(1.5, 1.5), end = Point(101.5, 101.5)
        let route = try XCTUnwrap(ground.route(from: start, to: end))
        XCTAssertEqual(route.last, end)
        for (a, b) in zip([start] + route, route) { XCTAssertTrue(ground.containsSegment(from: a, to: b)) }
        var movement = try HeroMovement(area: ground, spawn: start)
        var unit = MilitiaUnit(position: start, hp: 100)
        XCTAssertTrue(movement.command(to: end, unit: &unit))
        walk(&movement, &unit, to: end)
    }

    func testNewCommandMidStepAndRespawnUseActualPosition() throws {
        let ground = try area(["type": "LineString", "coordinates": [[0,0],[100,0],[100,100]]], width: 20)
        var movement = try HeroMovement(area: ground, spawn: Point(0, 0))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        XCTAssertTrue(movement.command(to: Point(100, 100), unit: &unit))
        for _ in 0..<11 { _ = movement.update(&unit, context: context, moveSpeed: 73, deltaTime: SimClock.dt) }
        let current = unit.position
        let nearby = Point(current.x + 0.25, current.y + 0.25)
        XCTAssertTrue(movement.command(to: nearby, unit: &unit))
        XCTAssertEqual(unit.position, current, "Issuing an order must not teleport the unit")
        walk(&movement, &unit, to: nearby)
        unit.state = .dead
        movement.respawn(unit: &unit, hp: 123)
        XCTAssertEqual(unit.position, movement.spawn); XCTAssertEqual(movement.station, movement.spawn)
        XCTAssertEqual(unit.hp, 123)
        XCTAssertTrue(movement.command(to: Point(100, 100), unit: &unit))
        walk(&movement, &unit, to: Point(100, 100))
    }

    func testAuthoredWidthAndPolygonOverrideDefaultWidth() throws {
        let narrow = try area(["type": "LineString", "coordinates": [[0,0],[100,0]]], width: 6)
        XCTAssertTrue(narrow.contains(Point(50, 2.9))); XCTAssertFalse(narrow.contains(Point(50, 3.1)))
        let polygon = try area(["type": "Polygon", "coordinates": [box(0, 0, 200, 200)]], width: 2)
        XCTAssertTrue(polygon.contains(Point(199, 199)))
        XCTAssertFalse(polygon.contains(Point(201, 100)))
        XCTAssertThrowsError(try HeroMovement(area: polygon, spawn: Point(201, 100)))
    }

    func testMalformedAndMissingAreasFailInsteadOfUsingDatabaseRoads() throws {
        for geometry: [String: Any] in [
            ["type": "Polygon", "coordinates": []],
            ["type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1]]]],
            ["type": "Polygon", "coordinates": [[[0,0],[1,0],[2,0],[0,0]]]],
            ["type": "LineString", "coordinates": [[0,0],[0,0]]],
            ["type": "LineString", "coordinates": [[0,0,0],[1,1,1]]],
            ["type": "Point", "coordinates": [0,0]]
        ] { XCTAssertThrowsError(try area(geometry)) }
        XCTAssertThrowsError(try area(["type": "LineString", "coordinates": [[0,0],[100,0]]], width: -1))
        XCTAssertThrowsError(try HeroMovementArea(geoJSON: Data(#"{"features":[]}"#.utf8), defaultPathWidth: 140))
    }

    func testEnemyChaseReturnAndUnreachableEnemyUseSameArea() throws {
        let ground = try area(["type": "MultiPolygon", "coordinates": [[box(0, 0, 100, 100)], [box(110, 0, 100, 100)]]])
        var movement = try HeroMovement(area: ground, spawn: Point(20, 50))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        unit.state = .engaging; unit.targetSpawnID = 7
        var combat = context; combat.targetPosition = Point(95, 50)
        for _ in 0..<100 {
            _ = movement.update(&unit, context: combat, moveSpeed: 73, deltaTime: SimClock.dt)
            XCTAssertTrue(ground.contains(unit.position))
        }
        XCTAssertGreaterThan(unit.position.x, 20)
        combat.targetPosition = Point(120, 50)
        XCTAssertEqual(movement.update(&unit, context: combat, moveSpeed: 73, deltaTime: SimClock.dt), .disengage)
        unit.state = .returning; unit.targetSpawnID = -1
        walk(&movement, &unit, to: movement.spawn)
    }
}
