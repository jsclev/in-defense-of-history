import XCTest
import CoreGraphics
import UniformTypeIdentifiers
@testable import LevelEditorFormats

final class LevelGeoJSONTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 1000, height: 800),
                      playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800),
                      pathWidth: 20, towerSlotSize: CGSize(width: 10, height: 10),
                      towerMenuTotalSize: CGSize(width: 50, height: 50),
                      statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
                      heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    private var draft: MapDraft {
        var d = MapDraft.starter
        d.name = "Test level"
        d.roads = [.init(name: "Main", points: [Point(100, 100), Point(400, 100)])]
        d.entrances = [Point(100, 100)]
        d.exits = [Point(400, 100)]
        d.slots = [Point(200, 200)]
        d.callWaveButtons = [.init(position: Point(140.25, 180.75))]
        return d
    }

    private func export(_ draft: MapDraft) throws -> LevelGeoJSON {
        try GeoJSONExport(virtualCanvas: canvas).document(for: draft)
    }

    private func valid() throws -> LevelGeoJSON.Collection { try export(draft).collection }

    private func rejects(_ change: (inout LevelGeoJSON.Collection) -> Void,
                         containing message: String, file: StaticString = #filePath, line: UInt = #line) throws {
        var c = try valid()
        change(&c)
        XCTAssertThrowsError(try LevelGeoJSON(collection: c), file: file, line: line) { error in
            XCTAssertTrue(error.localizedDescription.contains(message), error.localizedDescription,
                          file: file, line: line)
        }
    }

    func testValidModelRoundTripsAndDumpsAFile() throws {
        let model = try export(draft)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".geojson")
        defer { try? FileManager.default.removeItem(at: url) }
        try model.dump(to: url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(try LevelGeoJSON(data: data).collection, model.collection)
        XCTAssertEqual(try JSONDecoder().decode(LevelGeoJSON.self, from: data).collection, model.collection)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "FeatureCollection")
        let features = try XCTUnwrap(json["features"] as? [[String: Any]])
        XCTAssertEqual(features.count, 5)
        XCTAssertEqual((features[0]["geometry"] as? [String: Any])?["type"] as? String, "Polygon")
    }

    func testDumpPropagatesWriteFailure() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing-parent.geojson")
        XCTAssertThrowsError(try export(draft).dump(to: url))
    }

    func testRequiresExactlyOnePath() throws {
        try rejects({ $0.features.removeAll { $0.properties.kind == .path } }, containing: "exactly one")
        try rejects({ $0.features.append($0.features[0]) }, containing: "exactly one")
    }

    func testRequiresEntranceAndExit() throws {
        try rejects({ $0.features.removeAll { $0.properties.kind == .entrance } }, containing: "at least one entrance")
        try rejects({ $0.features.removeAll { $0.properties.kind == .exit } }, containing: "at least one exit")
    }

    func testMissingHeroAssignmentReportsReadableValidationError() throws {
        try rejects({ $0.heroCount = 2 }, containing: "Place each available hero")
    }

    func testDecodingCannotBypassValidation() throws {
        var c = try valid()
        c.features.append(c.features[0])
        let bytes = try JSONEncoder().encode(c)
        XCTAssertThrowsError(try LevelGeoJSON(data: bytes))
        XCTAssertThrowsError(try JSONDecoder().decode(LevelGeoJSON.self, from: bytes))
    }

    func testRejectsDuplicateOrMismatchedIDs() throws {
        try rejects({ $0.features[2].id = $0.features[1].id
            $0.features[2].properties.id = $0.features[1].id }, containing: "unique, matching ID")
        try rejects({ $0.features[0].properties.id = "different" }, containing: "unique, matching ID")
    }

    func testRejectsNonfiniteAndMalformedCoordinates() throws {
        for p in [[Double.nan, 100], [100, .infinity], [100], [100, 200, 300]] {
            try rejects({ $0.features[1].geometry = .point(p) }, containing: "finite [x, y]")
        }
    }

    func testRejectsEmptyOpenAndDegenerateRings() throws {
        let invalid: [LevelGeoJSON.Geometry] = [
            .multiPolygon([]), .polygon([]), .multiPolygon([[], [[[0, 0], [10, 0], [0, 10], [0, 0]]]]),
            .polygon([[[0, 0], [10, 0], [0, 10]]]),
            .polygon([[[0, 0], [10, 0], [20, 0], [0, 0]]])
        ]
        for geometry in invalid {
            var c = try valid()
            c.features[0].geometry = geometry
            XCTAssertThrowsError(try LevelGeoJSON(collection: c))
        }
    }

    func testEnforcesFeatureGeometryAndPathReferences() throws {
        try rejects({ $0.features[0].geometry = .point([1, 2]) }, containing: "Polygon or MultiPolygon")
        try rejects({ $0.features[1].geometry = $0.features[0].geometry }, containing: "must be Points")
        try rejects({ $0.features[0].properties.pathIndex = 1 }, containing: "pathIndex 0")
        try rejects({ $0.features[1].properties.pathIndex = 9 }, containing: "pathIndex 0")
        try rejects({ $0.features[2].properties.pathIndex = nil }, containing: "pathIndex 0")
    }

    func testRejectsUnsupportedTypesAndVersions() throws {
        try rejects({ $0.type = "Feature" }, containing: "Unsupported")
        try rejects({ $0.formatVersion = 999 }, containing: "Unsupported")
        try rejects({ $0.features[0].type = "SomethingElse" }, containing: "unique, matching ID")
        try rejects({ $0.features[0].properties.category = "other" }, containing: "gameplay")
        XCTAssertThrowsError(try JSONDecoder().decode(LevelGeoJSON.Geometry.self,
            from: Data(#"{"type":"MultiLineString","coordinates":[[[0,0],[1,1]]]}"#.utf8)))
    }

    func testValidatesCanvasAndLevelSettings() throws {
        try rejects({ $0.coordinateReferenceSystem.canvas.width = .infinity }, containing: "Canvas")
        try rejects({ $0.coordinateReferenceSystem.playArea.width = 2000 }, containing: "Canvas")
        try rejects({ $0.coordinateReferenceSystem.playArea.x = -1 }, containing: "Canvas")
        try rejects({ $0.coordinateReferenceSystem.type = "WGS84" }, containing: "Canvas")
        try rejects({ $0.name = "  " }, containing: "name")
        try rejects({ $0.startingGold = -1 }, containing: "gold")
        try rejects({ $0.lives = 0 }, containing: "lives")
    }

    func testValidatesSlotNumbering() throws {
        try rejects({ $0.features[3].properties.slotIndex = -1 }, containing: "slot indices")
        try rejects({ $0.features[3].properties.slotNumber = 2 }, containing: "slot numbers")
        try rejects({ $0.features[3].properties.slotIndex = 2
            $0.features[3].properties.slotNumber = 3 }, containing: "contiguous")
    }

    func testValidatesWaves() throws {
        try rejects({ $0.waves[0].breather = -.infinity }, containing: "breathers")
        try rejects({ $0.waves[0].lines[0].pathIndex = 1 }, containing: "Spawn lines")
        try rejects({ $0.waves[0].lines[0].count = 0 }, containing: "Spawn lines")
        try rejects({ $0.waves[0].lines[0].every = 0 }, containing: "Spawn lines")
        try rejects({ $0.waves[0].lines[0].delay = -1 }, containing: "Spawn lines")
        try rejects({ $0.waves[0].lines[0].foe = " " }, containing: "Spawn lines")
    }

    func testExportsUnionOfRoadsAndPaintWithoutChangingDraft() throws {
        var d = draft
        d.roads.append(.init(name: "Branch", points: [Point(250, 200), Point(250, 100), Point(400, 100)]))
        d.roadPaint = [.init(points: [Point(200, 100), Point(200, 150)], width: 40, erases: false)]
        d.waves[0].lines[0].road = 1
        let before = d
        let result = try export(d)
        XCTAssertEqual(d, before)
        let paths = result.collection.features.filter { $0.properties.kind == .path }
        XCTAssertEqual(paths.count, 1)
        XCTAssertEqual(paths[0].geometry.polygons.count, 1)
        let area = PathFlattening.area(for: paths[0].geometry)
        XCTAssertTrue(area.contains(CGPoint(x: 250, y: 180)))
        XCTAssertTrue(area.contains(CGPoint(x: 215, y: 130)))
        XCTAssertTrue(area.contains(CGPoint(x: 390, y: 100)))
        XCTAssertFalse(area.contains(CGPoint(x: 350, y: 180)))
        XCTAssertEqual(result.collection.waves[0].lines[0].pathIndex, 0)
        XCTAssertNil(try result.data().range(of: Data("road_paint".utf8)))
        XCTAssertNil(try result.data().range(of: Data("enemy_path_edge".utf8)))
    }

    func testDisconnectedRoadsStayDisconnectedInOneFeature() throws {
        var d = draft
        d.roads.append(.init(name: "Island", points: [Point(600, 500), Point(900, 500)]))
        let path = try export(d).collection.features[0].geometry
        guard case let .multiPolygon(polygons) = path else { return XCTFail("Expected MultiPolygon") }
        XCTAssertEqual(polygons.count, 2)
        let area = PathFlattening.area(for: path)
        XCTAssertTrue(area.contains(CGPoint(x: 750, y: 500)))
        XCTAssertFalse(area.contains(CGPoint(x: 500, y: 300)), "Export must never draw a bridge between paths")
    }

    func testFlatteningPreservesHolesAndNestedIslands() throws {
        let outer = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
        let hole = CGPath(rect: CGRect(x: 20, y: 20, width: 60, height: 60), transform: nil)
        let island = CGPath(rect: CGRect(x: 40, y: 40, width: 20, height: 20), transform: nil)
        let original = outer.subtracting(hole).union(island)
        let geometry = try PathFlattening.geometry(from: original)
        XCTAssertEqual(geometry.polygons.count, 2)
        XCTAssertEqual(geometry.polygons[0].count, 2)
        XCTAssertGreaterThan(LevelGeoJSON.Geometry.signedArea(geometry.polygons[0][0]), 0)
        XCTAssertLessThan(LevelGeoJSON.Geometry.signedArea(geometry.polygons[0][1]), 0)
        let area = PathFlattening.area(for: geometry)
        XCTAssertTrue(area.contains(CGPoint(x: 10, y: 10)))
        XCTAssertFalse(area.contains(CGPoint(x: 30, y: 30)))
        XCTAssertTrue(area.contains(CGPoint(x: 50, y: 50)))
    }

    func testSinglePaintDabIsExported() throws {
        var d = draft
        d.roads = []
        d.roadPaint = [.init(points: [Point(300, 300)], width: 50, erases: false)]
        let area = PathFlattening.area(for: try export(d).collection.features[0].geometry)
        XCTAssertTrue(area.contains(CGPoint(x: 300, y: 300)))
    }

    func testExporterDoesNotInventMarkersOrSilentlyDropBrokenRoads() throws {
        var d = draft
        d.entrances = []
        XCTAssertThrowsError(try export(d))
        d = draft; d.exits = []
        XCTAssertThrowsError(try export(d))
        d = draft; d.callWaveButtons = []
        XCTAssertThrowsError(try export(d))
        d = draft; d.roads = []
        XCTAssertThrowsError(try export(d))
        d = draft; d.roads.append(.init(name: "Unfinished", points: [Point(0, 0)]))
        XCTAssertThrowsError(try export(d))
        d = draft; d.roadPaint = [.init(points: [Point(1, 1)], width: -10, erases: false)]
        XCTAssertThrowsError(try export(d))
    }

    func testFlattenedImportCanBeSavedAndExportedAgain() throws {
        let original = try export(draft)
        let imported = try GeoJSONImport.draft(from: original.data())
        XCTAssertTrue(imported.roads.isEmpty)
        XCTAssertNotNil(imported.flattenedPath)
        XCTAssertEqual(imported.entrances, draft.entrances)
        XCTAssertEqual(imported.slots, draft.slots)
        XCTAssertEqual(imported.callWaveButtons, draft.callWaveButtons)
        XCTAssertEqual(try export(imported).collection, original.collection)
    }

    func testEraserRemovesImportedPathArea() throws {
        var imported = try GeoJSONImport.draft(from: export(draft).data())
        imported.applyErase(.init(points: [Point(250, 50), Point(250, 150)], width: 40, erases: true),
                            mapGeometry: MapGeometry(virtualCanvas: canvas))
        let area = PathFlattening.area(for: try export(imported).collection.features[0].geometry)
        XCTAssertFalse(area.contains(CGPoint(x: 250, y: 100)))
        XCTAssertTrue(area.contains(CGPoint(x: 150, y: 100)))
    }

    func testNativeFormatPreservesEditableDataImagesAndCanvas() throws {
        var d = draft
        d.roads.append(.init(name: "Separate editable road", points: [Point(1, 2), Point(30, 40)]))
        d.roadPaint = [.init(points: [Point(20, 20)], width: 30, erases: false)]
        d.backgroundImagePath = "/unavailable/on/another/device/map.png"
        d.backgroundImageData = Data([1, 2, 3, 4])
        d.guideImagePath = "guide.png"; d.guideImageData = Data([5, 6])
        d.overlayImagePath = "overlay.png"; d.overlayImageData = Data([7, 8])
        d.intendedSolution = [.init(at: 2, kind: "place", emplacement: "Minuteman Post", slot: 0)]
        d.hiddenLayers = ["background", "slots"]
        d.waves[0].lines[0].road = 1
        let file = NativeMapFile(draft: d, canvas: canvas)
        let restored = try NativeMapFile.read(file.data())
        XCTAssertEqual(restored.draft, d)
        XCTAssertEqual(restored.canvas, canvas)
        let document = MapDocument(canvas: canvas)
        document.draft = restored.draft
        XCTAssertEqual(try document.snapshot(contentType: .tdmap).draft, d)
        XCTAssertEqual(MapDocument.readableContentTypes, [.tdmap])
        XCTAssertEqual(MapDocument.writableContentTypes, [.tdmap])
    }

    func testNativeSnapshotEmbedsLegacyImagesAndRejectsMissingFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bytes = Data([1, 2, 3])
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let document = MapDocument(canvas: canvas)
        document.draft = draft
        document.draft.backgroundImagePath = url.path
        XCTAssertEqual(try document.snapshot(contentType: .tdmap).draft.backgroundImageData, bytes)
        document.draft.backgroundImagePath = url.path + ".missing"
        XCTAssertThrowsError(try document.snapshot(contentType: .tdmap))
    }

    func testNativeRejectsFutureVersionsAndLegacyDraftStillDecodes() throws {
        var file = NativeMapFile(draft: draft, canvas: canvas)
        file.version = 999
        XCTAssertThrowsError(try NativeMapFile.read(file.data()))
        let old = Data(#"{"name":"Old map","roads":[],"coordinateSpace":"canonical2868x2064"}"#.utf8)
        let restored = try JSONDecoder().decode(MapDraft.self, from: old)
        XCTAssertEqual(restored.name, "Old map")
        XCTAssertNil(restored.backgroundImageData)
        XCTAssertNil(restored.flattenedPath)
    }

    func testLegacyGeoJSONImportsSeparateRoads() throws {
        let bytes = Data(#"{"name":"Legacy","features":[{"geometry":{"type":"LineString","coordinates":[[100,100],[400,100]]},"properties":{"category":"gameplay","kind":"enemy_path","name":"Main"}},{"geometry":{"type":"LineString","coordinates":[[200,300],[400,100]]},"properties":{"category":"gameplay","kind":"enemy_path","name":"Branch"}},{"geometry":{"type":"Point","coordinates":[100,100]},"properties":{"category":"gameplay","kind":"spawn_point"}},{"geometry":{"type":"Point","coordinates":[400,100]},"properties":{"category":"gameplay","kind":"goal_point"}}]}"#.utf8)
        var imported = try GeoJSONImport.draft(from: bytes)
        XCTAssertEqual(imported.roads.map(\.name), ["Main", "Branch"])
        XCTAssertNil(imported.flattenedPath)
        XCTAssertTrue(imported.callWaveButtons.isEmpty)
        XCTAssertThrowsError(try export(imported))
        imported.callWaveButtons = [.init(position: Point(150, 150))]
        XCTAssertEqual(try export(imported).collection.features.filter { $0.properties.kind == .path }.count, 1)
    }
}
