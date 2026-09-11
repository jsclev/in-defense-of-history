import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyRouteTests: XCTestCase {
    private func document() -> [String: Any] {
        ["features": [
            ["id": "ground", "properties": ["category": "gameplay", "kind": "enemy_path"],
             "geometry": ["type": "Polygon", "coordinates": [[[0,0],[200,0],[200,100],[0,100],[0,0]], [[90,20],[110,20],[110,80],[90,80],[90,20]]]]],
            ["id": "entry", "properties": ["kind": "spawn_point"], "geometry": ["type": "Point", "coordinates": [10,50]]],
            ["id": "exit", "properties": ["kind": "goal_point"], "geometry": ["type": "Point", "coordinates": [190,50]]],
            ["id": "route", "properties": ["category": "gameplay", "kind": "enemy_route", "name": "Around the courtyard", "pathIndex": 0,
                                              "entranceID": "entry", "exitID": "exit"],
             "geometry": ["type": "LineString", "coordinates": [[10,50],[80,10],[120,10],[190,50]]]]
        ], "waves": [["lines": [["pathIndex": 0]]]]]
    }
    private func bytes(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

    func testLoadsDirectedRouteAndRejectsSegmentAcrossHoleEvenWithValidEndpoints() throws {
        var doc = document()
        let routes = try XCTUnwrap(try LevelGeoJSONDAO.enemyRoutes(from: bytes(doc)))
        XCTAssertEqual(routes.count, 1); XCTAssertEqual(routes[0].entranceID, "entry")
        XCTAssertEqual(routes[0].points, [Point(10,50), Point(80,10), Point(120,10), Point(190,50)])
        var features = doc["features"] as! [[String: Any]]
        features[3]["geometry"] = ["type": "LineString", "coordinates": [[10,50],[190,50]]]
        doc["features"] = features
        XCTAssertThrowsError(try LevelGeoJSONDAO.enemyRoutes(from: bytes(doc)))
    }

    func testRejectsMissingMarkersDuplicateIndicesInvalidEndpointsAndMissingWaveRoutes() throws {
        for change in 0..<7 {
            var doc = document(); var features = doc["features"] as! [[String: Any]]
            var props = features[3]["properties"] as! [String: Any]
            switch change {
            case 0: props["entranceID"] = "missing"
            case 1: props["exitID"] = "entry"
            case 2: props["pathIndex"] = 1
            case 3: props["pathIndex"] = 0.5
            case 4: features.append(features[3])
            case 5: features[3]["geometry"] = ["type": "LineString", "coordinates": [[11,50],[80,10],[120,10],[190,50]]]
            default: doc["waves"] = [["lines": [["pathIndex": 1]]]]
            }
            features[3]["properties"] = props; doc["features"] = features
            XCTAssertThrowsError(try LevelGeoJSONDAO.enemyRoutes(from: bytes(doc)), "Case \(change)")
        }
    }

    func testExplicitRoutesAreSortedAndDoNotExpandHeroMovementArea() throws {
        var doc = document(); var features = doc["features"] as! [[String: Any]]
        var second = features[3]; var props = second["properties"] as! [String: Any]
        props["pathIndex"] = 1; second["properties"] = props
        second["geometry"] = ["type": "LineString", "coordinates": [[10,50],[80,90],[120,90],[190,50]]]
        features.insert(second, at: 0); doc["features"] = features
        let routes = try XCTUnwrap(try LevelGeoJSONDAO.enemyRoutes(from: bytes(doc)))
        XCTAssertEqual(routes.map(\.index), [0,1])
        let area = try HeroMovementArea(geoJSON: bytes(doc), defaultPathWidth: 140)
        XCTAssertFalse(area.contains(Point(100,50)))
        // An illegal route crossing the hole cannot enlarge the permitted ground.
        features[0]["geometry"] = ["type": "LineString", "coordinates": [[10,50],[190,50]]]
        doc["features"] = features
        XCTAssertFalse(try HeroMovementArea(geoJSON: bytes(doc), defaultPathWidth: 140).contains(Point(100,50)))
    }

    func testLoaderPrefersGeoJSONAndRefusesInvalidRoutesInsteadOfUsingSQL() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = folder.appendingPathComponent("level.sqlite")
        try FileManager.default.copyItem(at: root.appendingPathComponent("Db/in_defense_of_history.sqlite"), to: database)
        let geo = folder.appendingPathComponent("level_15_charleston.geojson")
        try FileManager.default.copyItem(at: root.appendingPathComponent("Db/level_15_charleston.geojson"), to: geo)
        let levelID = UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &connection), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(connection, "UPDATE level_path_point SET map_position_x = -999 WHERE level_info_id = '\(levelID.uuidString.lowercased())'", nil, nil, nil), SQLITE_OK)
        sqlite3_close(connection)
        let db = Db(dbPath: database.path, fullRefresh: false, levelGeoJSONDao: LevelGeoJSONDAO(directory: folder))
        defer { db.close() }
        let loaded = try db.levelLoader.load(id: levelID)
        let routes = try XCTUnwrap(try LevelGeoJSONDAO.enemyRoutes(from: Data(contentsOf: geo)))
        XCTAssertEqual(loaded.paths, routes.map(\.path))
        var doc = try JSONSerialization.jsonObject(with: Data(contentsOf: geo)) as! [String: Any]
        var features = doc["features"] as! [[String: Any]]
        let index = features.firstIndex { ($0["properties"] as? [String: Any])?["kind"] as? String == "enemy_route" }!
        features[index]["geometry"] = ["type": "LineString", "coordinates": [[0,0],[1,1]]]
        doc["features"] = features; try bytes(doc).write(to: geo)
        XCTAssertThrowsError(try db.levelLoader.load(id: levelID))
    }

    func testEditorRejectsExportAfterErasingAnExplicitEnemyRoute() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("Db/level_15_charleston.geojson")
        let native = try NativeMapFile.read(Data(contentsOf: root.appendingPathComponent("Db/level_15_charleston.tdmap")))
        var draft = try GeoJSONImport.draft(from: Data(contentsOf: file))
        let previousRoutes = draft.enemyRoutes
        let target = try XCTUnwrap(draft.enemyRoutes.first).path.point(atDistance: 300)
        draft.applyErase(.init(points: [target], width: 30, erases: true), mapGeometry: MapGeometry(virtualCanvas: native.canvas))
        XCTAssertEqual(draft.enemyRoutes, previousRoutes)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: native.canvas).data(for: draft))
    }
}
