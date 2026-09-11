import XCTest
import CoreGraphics
@testable import LevelEditorFormats

/// Loads the files shipped with the game through the production DAO and drives
/// the same movement/AI update used by LevelRunner. No views or source extraction.
final class HeroMovementIntegrationTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    private var directory: URL { root.appendingPathComponent("Db") }
    private func maps() throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "geojson" }.sorted { $0.path < $1.path }
        XCTAssertEqual(files.count, 15)
        return files
    }
    private func legacyRoads(_ data: Data) throws -> [(path: LevelEditorFormats.Path, width: Double)] {
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let features = try XCTUnwrap(root["features"] as? [[String: Any]])
        return features.compactMap { feature in
            guard let properties = feature["properties"] as? [String: Any],
                  properties["kind"] as? String == "enemy_path",
                  let geometry = feature["geometry"] as? [String: Any], geometry["type"] as? String == "LineString",
                  let coordinates = geometry["coordinates"] as? [[Double]] else { return nil }
            return (LevelEditorFormats.Path(points: coordinates.map { Point($0[0], $0[1]) }),
                    properties["widthPx"] as? Double ?? 140)
        }
    }
    private func context() -> MilitiaContext {
        MilitiaContext(freeEnemies: [], targetPosition: nil, rallyPoint: .zero,
                       towerPosition: .zero, leashRadius: 130, engageScanRadius: 80)
    }
    private func arrive(_ movement: inout HeroMovement, _ unit: inout MilitiaUnit,
                        at destination: Point, map: String,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let route = try XCTUnwrap(movement.area.route(from: unit.position, to: destination), map, file: file, line: line)
        var length = 0.0
        for (a, b) in zip([unit.position] + route, route) {
            XCTAssertTrue(movement.area.containsSegment(from: a, to: b), map, file: file, line: line)
            length += a.distance(to: b)
        }
        XCTAssertTrue(movement.command(to: destination, unit: &unit), map, file: file, line: line)
        let speed = 73.0
        let maxTicks = Int(ceil(length / (speed * SimClock.dt))) + 4
        for _ in 0..<maxTicks {
            let previous = unit.position
            _ = movement.update(&unit, context: context(), moveSpeed: speed, deltaTime: SimClock.dt)
            XCTAssertTrue(movement.area.contains(unit.position), "\(map): \(unit.position)", file: file, line: line)
            XCTAssertLessThanOrEqual(previous.distance(to: unit.position), speed * SimClock.dt + 1e-7, map, file: file, line: line)
            if unit.position == destination, unit.state == .holding { break }
        }
        XCTAssertEqual(unit.position, destination, map, file: file, line: line)
        XCTAssertEqual(unit.state, .holding, map, file: file, line: line)
    }

    func testAllLegacyLevelRoadsPermitMovementAlongWaypointsAndAcrossTheirWidth() throws {
        var testedRoads = 0
        for file in try maps() {
            let name = file.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: file)
            let area = try LevelGeoJSONDAO(directory: directory).getHeroMovementArea(mapImageName: name, defaultPathWidth: 140)
            for (road, width) in try legacyRoads(data) {
                testedRoads += 1
                // Every authored waypoint must belong to the movement area.
                for point in road.points { XCTAssertTrue(area.contains(point), name) }
                var movement = try HeroMovement(area: area, spawn: road.points[0])
                var unit = MilitiaUnit(position: movement.spawn, hp: 100)
                for fraction in [0.1, 0.25, 0.5, 0.75, 0.9, 1.0, 0.0] {
                    let point = road.point(atDistance: road.totalLength * fraction)
                    try arrive(&movement, &unit, at: point, map: name)
                }
                let a = road.point(atDistance: road.totalLength * 0.5)
                let b = road.point(atDistance: road.totalLength * 0.5 + 1)
                let gap = a.distance(to: b)
                for sign in [-1.0, 1.0] {
                    let interior = Point(a.x - (b.y - a.y) / gap * width * 0.3 * sign,
                                         a.y + (b.x - a.x) / gap * width * 0.3 * sign)
                    try arrive(&movement, &unit, at: interior, map: name)
                }
            }
        }
        XCTAssertEqual(testedRoads, 33)
    }

    func testAllAuthoredHeroStartsCanMoveAndRespawnInsideTheirLevelArea() throws {
        let dao = LevelGeoJSONDAO(directory: directory)
        var testedHeroes = 0
        for file in try maps() {
            let name = file.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: file)
            let area = try dao.getHeroMovementArea(mapImageName: name, defaultPathWidth: 140)
            let configuration = try dao.getHeroConfiguration(mapImageName: name)
            let roads = try legacyRoads(data)
            for spawn in configuration.spawns {
                testedHeroes += 1
                XCTAssertTrue(area.contains(spawn.position), "\(name) \(spawn.role)")
                var movement = try HeroMovement(area: area, spawn: spawn.position)
                var unit = MilitiaUnit(position: spawn.position, hp: 100)
                let destination: Point
                if let nearest = roads.min(by: {
                    $0.path.point(atDistance: $0.path.nearestDistance(to: spawn.position)).distance(to: spawn.position) <
                    $1.path.point(atDistance: $1.path.nearestDistance(to: spawn.position)).distance(to: spawn.position)
                }) {
                    destination = nearest.path.point(atDistance: nearest.path.totalLength * 0.5)
                } else {
                    // Charleston's polygon contains a continuous route between both starts.
                    destination = try XCTUnwrap(configuration.spawns.first { $0.position != spawn.position }).position
                }
                try arrive(&movement, &unit, at: destination, map: name)
                unit.state = .dead
                movement.respawn(unit: &unit, hp: 100)
                XCTAssertEqual(unit.position, spawn.position)
                try arrive(&movement, &unit, at: destination, map: name)
            }
        }
        XCTAssertEqual(testedHeroes, 25)
    }

    func testCharlestonPolygonAllowsAreaDestinationsAndPreservesItsHoles() throws {
        let file = directory.appendingPathComponent("level_15_charleston.geojson")
        let document = try LevelGeoJSON(data: Data(contentsOf: file))
        let geometry = try XCTUnwrap(document.collection.features.first { $0.properties.kind == .path }).geometry
        // The editor's independent geometry path is the reference for the export.
        let reference = PathFlattening.area(for: geometry)
        let area = try LevelGeoJSONDAO(directory: directory).getHeroMovementArea(
            mapImageName: "level_15_charleston", defaultPathWidth: 1)
        var movement = try HeroMovement(area: area, spawn: Point(1638, 548))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        var checked = 0
        var outside = 0
        for y in stride(from: 540.0, through: 1480, by: 110) {
            for x in stride(from: 520.0, through: 2360, by: 110) {
                let p = Point(x, y)
                if reference.contains(CGPoint(x: x, y: y)) {
                    try arrive(&movement, &unit, at: p, map: "Charleston polygon")
                    checked += 1
                } else {
                    let previous = unit.position
                    XCTAssertFalse(movement.command(to: p, unit: &unit))
                    XCTAssertEqual(unit.position, previous)
                    outside += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 20); XCTAssertGreaterThan(outside, 20)
    }

    func testReexportedAreaImmediatelyChangesMovementWithoutDatabaseWaypoints() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let dao = LevelGeoJSONDAO(directory: folder)
        XCTAssertThrowsError(try dao.getHeroMovementArea(mapImageName: "level", defaultPathWidth: 140))
        let file = folder.appendingPathComponent("level.geojson")
        let start = Point(20, 50), destination = Point(180, 50)
        func export(_ holes: String) throws {
            let json = """
            {"features":[{"properties":{"category":"gameplay","kind":"enemy_path"},
            "geometry":{"type":"Polygon","coordinates":[[[0,0],[200,0],[200,100],[0,100],[0,0]]\(holes)]}}]}
            """
            try Data(json.utf8).write(to: file)
        }
        try export("")
        let original = try dao.getHeroMovementArea(mapImageName: "level", defaultPathWidth: 140)
        XCTAssertEqual(original.route(from: start, to: destination), [destination])
        try export(",[[90,10],[110,10],[110,90],[90,90],[90,10]]")
        let revised = try dao.getHeroMovementArea(mapImageName: "level", defaultPathWidth: 140)
        XCTAssertFalse(revised.containsSegment(from: start, to: destination))
        XCTAssertFalse(revised.contains(Point(100, 50)))
        var movement = try HeroMovement(area: revised, spawn: start)
        var unit = MilitiaUnit(position: start, hp: 100)
        try arrive(&movement, &unit, at: destination, map: "reexport")
    }

    func testRuntimeCanvasInputRoundTripAndResizeDoNotChangeMovement() throws {
        let db = Db(dbPath: directory.appendingPathComponent("in_defense_of_history.sqlite").path, fullRefresh: false)
        defer { db.close() }
        let canvas = try db.virtualCanvasDao.get()
        let area = try LevelGeoJSONDAO(directory: directory).getHeroMovementArea(
            mapImageName: "level_15_charleston", defaultPathWidth: canvas.pathWidth)
        let destination = Point(1638, 548)
        var movement = try HeroMovement(area: area, spawn: Point(2278, 1248))
        var unit = MilitiaUnit(position: movement.spawn, hp: 100)
        for (screen, safe) in [
            (CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 381)),
            (CGRect(x: 0, y: 0, width: 956, height: 440), CGRect(x: 62, y: 0, width: 832, height: 419)),
            (CGRect(x: 31, y: 19, width: 1024, height: 768), CGRect(x: 51, y: 39, width: 984, height: 728))
        ] {
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: screen, safeInsetsRect: safe)
            let input = MapDestinationInput(runtimeCanvas: runtime)
            let viewPoint = input.projection.viewPoint(CGPoint(x: destination.x, y: destination.y))
            let modelPoint = try XCTUnwrap(input.mapPoint(at: viewPoint))
            XCTAssertEqual(modelPoint.x, destination.x, accuracy: 1e-9)
            XCTAssertEqual(modelPoint.y, destination.y, accuracy: 1e-9)
            let previous = unit.position
            XCTAssertTrue(movement.command(to: Point(modelPoint.x, modelPoint.y), unit: &unit))
            XCTAssertEqual(unit.position, previous)
            for _ in 0..<30 { _ = movement.update(&unit, context: context(), moveSpeed: 73, deltaTime: SimClock.dt) }
            XCTAssertTrue(area.contains(unit.position))
            XCTAssertNil(input.mapPoint(at: CGPoint(x: -100, y: -100)))
        }
        try arrive(&movement, &unit, at: destination, map: "canvas resize")
    }
}
