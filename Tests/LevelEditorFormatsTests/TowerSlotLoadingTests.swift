import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerSlotLoadingTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }
    private let mapName = "level_15_charleston"
    private let levelID = UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!

    private func feature(_ index: Int, _ xy: [Double]) -> [String: Any] {
        ["properties": ["category": "gameplay", "kind": "tower_slot", "slotIndex": index, "slotNumber": index + 1],
         "geometry": ["type": "Point", "coordinates": xy]]
    }
    private func data(_ features: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["features": features])
    }

    func testAuthoredOrderCoordinatesAndStableIdentities() throws {
        let bytes = try data([feature(1, [2234.125, 655.875]), feature(0, [774.5, 1124.25])])
        let slots = try LevelGeoJSONDAO.towerSlots(from: bytes, mapImageName: mapName)
        XCTAssertEqual(slots.map(\.position), [Point(774.5, 1124.25), Point(2234.125, 655.875)])
        XCTAssertEqual(try LevelGeoJSONDAO.towerSlots(from: bytes, mapImageName: mapName), slots)
        XCTAssertNotEqual(try LevelGeoJSONDAO.towerSlots(from: bytes, mapImageName: "another").map(\.id), slots.map(\.id))
        XCTAssertEqual(Set(slots.map(\.id)).count, 2)
    }

    func testRejectsMalformedCoordinatesAndNumbering() throws {
        for coordinates in [[Double](), [1], [1, 2, 3]] {
            XCTAssertThrowsError(try LevelGeoJSONDAO.towerSlots(from: data([feature(0, coordinates)]), mapImageName: mapName))
        }
        for indices in [[-1], [1], [0, 0], [0, 2]] {
            XCTAssertThrowsError(try LevelGeoJSONDAO.towerSlots(from: data(indices.map { feature($0, [1, 2]) }), mapImageName: mapName))
        }
        for bad in ["-1", "1", "0.5", "true", "\"0\""] {
            let json = """
            {"features":[{"properties":{"category":"gameplay","kind":"tower_slot","slotIndex":\(bad),"slotNumber":1},
            "geometry":{"type":"Point","coordinates":[1,2]}}]}
            """
            XCTAssertThrowsError(try LevelGeoJSONDAO.towerSlots(from: Data(json.utf8), mapImageName: mapName))
        }
        for json in ["{}", #"{"features":null}"#,
                     #"{"features":[{"properties":{"category":"gameplay","kind":"tower_slot"},"geometry":{"type":"Point","coordinates":[1,2]}}]}"#] {
            XCTAssertThrowsError(try LevelGeoJSONDAO.towerSlots(from: Data(json.utf8), mapImageName: mapName))
        }
    }

    func testLegacyNumberOnlySlotsAndExplicitlyEmptyMap() throws {
        var slot = feature(0, [123.5, 678.25])
        slot["properties"] = ["category": "gameplay", "kind": "tower_slot", "slotNumber": 1]
        XCTAssertEqual(try LevelGeoJSONDAO.towerSlots(from: data([slot]), mapImageName: mapName).map(\.position), [Point(123.5, 678.25)])
        XCTAssertTrue(try LevelGeoJSONDAO.towerSlots(from: data([]), mapImageName: mapName).isEmpty)
    }

    func testEveryBundledMapMatchesEditorSlots() throws {
        let directory = root.appendingPathComponent("Db")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "geojson" }
        XCTAssertEqual(files.count, 15)
        for file in files {
            let bytes = try Data(contentsOf: file)
            let loaded = try LevelGeoJSONDAO(directory: directory).getTowerSlots(mapImageName: file.deletingPathExtension().lastPathComponent)
            XCTAssertEqual(loaded.map(\.position), try GeoJSONImport.draft(from: bytes).slots, file.lastPathComponent)
        }
    }

    func testSharedLoaderWorksWithoutSQLSlotsAndImmediatelyUsesReexports() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = directory.appendingPathComponent("test.sqlite")
        try FileManager.default.copyItem(at: root.appendingPathComponent("Db/in_defense_of_history.sqlite"), to: database)
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &connection), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(connection, "DROP TABLE IF EXISTS tower_slot", nil, nil, nil), SQLITE_OK)
        sqlite3_close(connection)
        let file = directory.appendingPathComponent(mapName + ".geojson")
        let db = Db(dbPath: database.path, fullRefresh: false, levelGeoJSONDao: LevelGeoJSONDAO(directory: directory))
        defer { db.close() }

        // A missing export must fail even though the rest of the level is in SQLite.
        XCTAssertThrowsError(try db.levelLoader.load(id: levelID))
        let native = try NativeMapFile.read(Data(contentsOf: root.appendingPathComponent("Db/\(mapName).tdmap")))
        var draft = native.draft
        draft.slots = [Point(774.5, 1124.25), Point(2234.125, 655.875)]
        try GeoJSONExport(virtualCanvas: native.canvas).data(for: draft).write(to: file)
        let first = try db.levelLoader.load(id: levelID)
        XCTAssertEqual(first.towerSlots.map(\.position), draft.slots)
        XCTAssertFalse(first.paths.isEmpty)
        XCTAssertFalse(first.waves.isEmpty)

        draft.slots = [Point(781.25, 1100.75), Point(1412.5, 844.125), Point(2010, 750)]
        try GeoJSONExport(virtualCanvas: native.canvas).data(for: draft).write(to: file)
        let second = try db.levelLoader.load(id: levelID)
        XCTAssertEqual(second.towerSlots.map(\.position), draft.slots)
        XCTAssertEqual(second.towerSlots[0].id, first.towerSlots[0].id)
        try Data("{}".utf8).write(to: file)
        XCTAssertThrowsError(try db.levelLoader.load(id: levelID))
    }
}
