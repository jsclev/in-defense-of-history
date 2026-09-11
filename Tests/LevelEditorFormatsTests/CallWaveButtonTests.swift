import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class CallWaveButtonTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
                      playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
                      pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
                      towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
                      statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
                      heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    func testExactCentersSurviveNativeGeoJSONAndRuntimeLoading() throws {
        var draft = MapDraft.starter
        draft.roads = [.init(name: "Road", points: [Point(500, 700), Point(900, 700)])]
        draft.entrances = [Point(500, 700)]
        draft.exits = [Point(900, 700)]
        draft.callWaveButtons = [.init(position: Point(543.125, 789.875), pathIndices: [0]),
                                 .init(position: Point(2154.5, 1050.25), pathIndices: [1, 2])]
        let native = try NativeMapFile.read(NativeMapFile(draft: draft, canvas: canvas).data())
        let geo = try GeoJSONExport(virtualCanvas: canvas).document(for: native.draft)
        let data = try geo.data()
        XCTAssertEqual(try GeoJSONImport.draft(from: data).callWaveButtons, draft.callWaveButtons)
        XCTAssertEqual(try LevelGeoJSONDAO.callWaveButtons(from: data), draft.callWaveButtons)
        let markers = geo.collection.features.filter { $0.properties.kind == .callWaveButton }
        XCTAssertEqual(markers.count, 2)
        XCTAssertTrue(markers.allSatisfy { $0.properties.pathIndex == nil && $0.properties.layer == 100 })
    }

    func testLegacyDocumentsOpenWithoutInventingButtonPositions() throws {
        let draft = try JSONDecoder().decode(MapDraft.self, from: Data("{}".utf8))
        XCTAssertTrue(draft.callWaveButtons.isEmpty)
        let data = Data(#"{"features":[{"geometry":{"type":"LineString","coordinates":[[500,700],[900,700]]},"properties":{"category":"gameplay","kind":"enemy_path"}},{"geometry":{"type":"Point","coordinates":[612.25,888.5]},"properties":{"category":"gameplay","kind":"call_wave_button"}}]}"#.utf8)
        XCTAssertEqual(try GeoJSONImport.draft(from: data).callWaveButtons.map(\.position), [Point(612.25, 888.5)])
        XCTAssertEqual(try LevelGeoJSONDAO.callWaveButtonPositions(from: data), [Point(612.25, 888.5)])
    }

    func testRuntimeRejectsMissingAndMalformedButtons() {
        for json in [#"{"features":[]}"#,
                     #"{"features":[{"properties":{"kind":"call_wave_button"},"geometry":{"type":"Point","coordinates":[1]}}]}"#,
                     #"{"features":[{"properties":{"kind":"call_wave_button"},"geometry":{"type":"LineString","coordinates":[[1,2],[3,4]]}}]}"#] {
            XCTAssertThrowsError(try LevelGeoJSONDAO.callWaveButtonPositions(from: Data(json.utf8)))
        }
    }

    func testOnlyUpcomingRoutesShowButtonsAndSharedEntrancesAppearOnce() {
        let left = Point(614, 1214), top = Point(1146, 1432), right = Point(2254, 1265)
        let markers: [CallWaveButtonPosition] = [
            .init(position: left, pathIndices: [0, 1]),
            .init(position: top, pathIndices: [2]),
            .init(position: right, pathIndices: [3]),
            .init(position: left, pathIndices: [4])
        ]
        XCTAssertEqual(CallWaveButtonPosition.visiblePositions(markers, forPathIndices: [0]), [left])
        XCTAssertEqual(CallWaveButtonPosition.visiblePositions(markers, forPathIndices: [3]), [right])
        XCTAssertEqual(CallWaveButtonPosition.visiblePositions(markers, forPathIndices: [1, 2, 3]), [left, top, right])
        XCTAssertEqual(CallWaveButtonPosition.visiblePositions(markers, forPathIndices: [0, 1, 4]), [left])
        XCTAssertTrue(CallWaveButtonPosition.visiblePositions(markers, forPathIndices: [5]).isEmpty)
        XCTAssertEqual(CallWaveButtonPosition.visiblePositions([.init(position: top)], forPathIndices: [5]), [top])
    }

    func testCharlestonUsesTheCurrentAuthoredButtonCoordinates() throws {
        let db = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Db")
        let data = try Data(contentsOf: db.appendingPathComponent("level_15_charleston.geojson"))
        let buttons = try LevelGeoJSONDAO.callWaveButtons(from: data)
        let source = try LevelGeoJSON(data: data).collection.features.filter { $0.properties.kind == .callWaveButton }
        XCTAssertEqual(buttons.count, source.count)
        for (button, feature) in zip(buttons, source) {
            guard case let .point(xy) = feature.geometry else { return XCTFail("Expected an authored Point") }
            XCTAssertEqual(button.position, Point(xy[0], xy[1]))
            XCTAssertEqual(button.pathIndices, feature.properties.pathIndices)
        }
        XCTAssertEqual(try GeoJSONImport.draft(from: data).callWaveButtons, buttons)
    }

    func testInvalidRouteAssignmentsAreRejected() {
        for routes in ["[]", "[-1]", "[0,0]", "[0.5]", "[true]", "[\"0\"]", "\"0\"", "0"] {
            let json = """
            {"features":[{"properties":{"kind":"call_wave_button","pathIndices":\(routes)},
                          "geometry":{"type":"Point","coordinates":[614,1214]}}]}
            """
            XCTAssertThrowsError(try LevelGeoJSONDAO.callWaveButtons(from: Data(json.utf8)))
        }
    }

    func testLayoutProjectsExactCoordinatesAcrossRuntimeCanvases() {
        for safe in [CGRect(x: 59, y: 0, width: 734, height: 372),
                     CGRect(x: 0, y: 24, width: 1366, height: 980),
                     CGRect(x: 0, y: 59, width: 393, height: 759)] {
            let runtime = RuntimeCanvas(virtualCanvas: canvas,
                                        physicalRect: CGRect(x: 0, y: 0, width: safe.maxX + 20, height: safe.maxY + 20),
                                        safeInsetsRect: safe)
            for p in [Point(474, 1572), Point(1434, 1032), Point(2394, 492), Point(400, 1650)] {
                let layout = CallWaveButtonLayout(position: p, runtimeCanvas: runtime)
                let play = runtime.playAreaRect
                XCTAssertEqual(layout.frame.midX, play.minX + (p.x - 474) / 1920 * play.width, accuracy: 0.000001)
                XCTAssertEqual(layout.frame.midY, play.minY + (1572 - p.y) / 1080 * play.height, accuracy: 0.000001)
                XCTAssertGreaterThanOrEqual(layout.frame.width, TouchTarget.minimum)
            }
        }
    }

    func testSizingUsesRuntimeHUDScaleAndReadableMinimum() {
        for (height, side) in [(200.0, 44.0), (680.625, 70.0), (1080.0, 84.0)] {
            let rect = CGRect(x: 0, y: 0, width: height * 16 / 9, height: height)
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: rect, safeInsetsRect: rect)
            let layout = CallWaveButtonLayout(position: Point(1434, 1032), runtimeCanvas: runtime)
            XCTAssertEqual(layout.frame.width, side, accuracy: 0.000001)
            XCTAssertEqual(layout.frame.height, side, accuracy: 0.000001)
            XCTAssertGreaterThanOrEqual(layout.countdownFontSize, Typography.minimumFontSize)
        }
    }

    func testBundledMapsProvideEditableRuntimeButtonCenters() throws {
        let db = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Db")
        let files = try FileManager.default.contentsOfDirectory(at: db, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "geojson" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let data = try Data(contentsOf: file)
            let runtimeCenters = try LevelGeoJSONDAO.callWaveButtonPositions(from: data)
            XCTAssertEqual(try GeoJSONImport.draft(from: data).callWaveButtons.map(\.position), runtimeCenters,
                           file.lastPathComponent)
        }
    }
}
