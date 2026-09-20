import CoreGraphics
import XCTest
@testable import LevelEditorFormats

final class EditorRouteEndpointTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 1000, height: 800),
            playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800), pathWidth: 20,
            towerSlotSize: CGSize(width: 10, height: 10), towerMenuTotalSize: CGSize(width: 50, height: 50),
            statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
            heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    private var draft: MapDraft {
        var d = MapDraft.starter
        d.flattenedPath = .polygon([[[20, 20], [900, 20], [900, 700], [20, 700], [20, 20]]])
        d.entrances = [Point(100, 100), Point(100, 500)]
        d.exits = [Point(800, 100), Point(800, 500)]
        d.enemyRoutes = [(0, 1), (1, 0), (0, 0), (1, 1)].enumerated().map { index, pair in
            EnemyRoute(index: index, name: "Hidden authored name \(index)",
                entranceID: "gameplay.entry.\(pair.0)", exitID: "gameplay.exit.\(pair.1)",
                points: [d.entrances[pair.0], Point(300, 300), Point(600, 300), d.exits[pair.1]])
        }
        d.waves[0].lines = d.enemyRoutes.map {
            .init(foe: Foe.loyalistMilitia.rawValue, count: 6, every: 2.2, delay: 0, road: $0.index)
        }
        d.callWaveButtons = [.init(position: Point(100, 200), pathIndices: [0, 2]),
                             .init(position: Point(100, 600), pathIndices: [1, 3])]
        return d
    }

    func testMarkerMovesUpdateOnlyAttachedEndpointsAndPreserveAssignments() throws {
        var moved = draft
        let before = moved
        moved.moveEntrance(at: 0, to: Point(120, 110))
        moved.moveExit(at: 1, to: Point(820, 510))
        for index in moved.enemyRoutes.indices {
            let route = moved.enemyRoutes[index], original = before.enemyRoutes[index]
            XCTAssertEqual(route.points.first, [0, 2].contains(index) ? Point(120, 110) : original.points.first)
            XCTAssertEqual(route.points.last, [0, 3].contains(index) ? Point(820, 510) : original.points.last)
            XCTAssertEqual(Array(route.points.dropFirst().dropLast()), Array(original.points.dropFirst().dropLast()))
            XCTAssertEqual(route.entranceID, original.entranceID)
            XCTAssertEqual(route.exitID, original.exitID)
            XCTAssertEqual(route.index, original.index)
        }
        XCTAssertEqual(moved.waves, before.waves)
        XCTAssertEqual(moved.callWaveButtons, before.callWaveButtons)
        let data = try GeoJSONExport(virtualCanvas: canvas).data(for: moved)
        XCTAssertEqual(try LevelGeoJSONDAO.enemyRoutes(from: data), moved.enemyRoutes)
    }

    func testOpenAndExportRepairPreviouslySavedStaleEndpointsWithoutChangingSource() throws {
        var stale = draft
        stale.entrances[0] = Point(120, 110)
        stale.exits[1] = Point(820, 510)
        let data = try NativeMapFile(draft: stale, canvas: canvas).data()
        let file = try NativeMapFile.read(data)
        let exported = try GeoJSONExport(virtualCanvas: file.canvas).data(for: file.draft)
        let routes = try XCTUnwrap(LevelGeoJSONDAO.enemyRoutes(from: exported))
        XCTAssertEqual(file.draft, stale)
        var opened = file.draft
        opened.normalize(mapGeometry: MapGeometry(virtualCanvas: file.canvas))
        XCTAssertEqual(opened.enemyRoutes, routes)
        XCTAssertEqual(routes[0].points.first, stale.entrances[0])
        XCTAssertEqual(routes[0].points.last, stale.exits[1])
        XCTAssertEqual(opened.waves, stale.waves)
        let once = opened
        opened.normalize(mapGeometry: MapGeometry(virtualCanvas: file.canvas))
        XCTAssertEqual(opened, once, "Opening or exporting again must not shift the route")
    }

    @MainActor
    func testMarkerDragUndoRedoRestoresEndpointsTogether() {
        let document = MapDocument(canvas: canvas)
        document.draft = draft
        let before = document.draft
        let undo = UndoManager()
        undo.groupsByEvent = false
        // The canvas applies live drag samples, then registers one undo on release.
        document.draft.moveEntrance(at: 0, to: Point(110, 100))
        document.draft.moveEntrance(at: 0, to: Point(120, 110))
        let after = document.draft
        undo.beginUndoGrouping()
        document.registerUndo(from: before, undo)
        undo.endUndoGrouping()
        undo.undo()
        XCTAssertEqual(document.draft, before)
        undo.redo()
        XCTAssertEqual(document.draft, after)
    }

    @MainActor
    func testMarkerNudgeUndoRedoRestoresEndpointsTogether() {
        let document = MapDocument(canvas: canvas)
        document.draft = draft
        let before = document.draft
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        document.edit(undo) { d in
            let p = d.exits[1]
            d.moveExit(at: 1, to: Point(p.x + 1, p.y))
        }
        undo.endUndoGrouping()
        let after = document.draft
        XCTAssertEqual(after.enemyRoutes[0].points.last, Point(801, 500))
        XCTAssertEqual(after.enemyRoutes[3].points.last, Point(801, 500))
        undo.undo()
        XCTAssertEqual(document.draft, before)
        undo.redo()
        XCTAssertEqual(document.draft, after)
    }

    func testUnknownMarkersAndMalformedRoutesAreNotInventedOrRepaired() throws {
        var invalid = draft
        invalid.enemyRoutes[0].entranceID = "missing"
        invalid.enemyRoutes[1].points = [Point(100, 500)]
        let before = invalid
        invalid.moveEntrance(at: -1, to: .zero)
        invalid.moveExit(at: invalid.exits.count, to: .zero)
        XCTAssertEqual(invalid, before)
        invalid.normalize(mapGeometry: MapGeometry(virtualCanvas: canvas))
        XCTAssertEqual(invalid.enemyRoutes, before.enemyRoutes)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).data(for: invalid))
    }

    func testMovingMarkerOffRoadStillFailsWithVisibleMarkerNames() throws {
        var invalid = draft
        invalid.moveEntrance(at: 0, to: Point(10, 100))
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).data(for: invalid)) { error in
            XCTAssertTrue(error is LevelGeoJSONError)
            XCTAssertTrue(error.localizedDescription.contains("Entrance 0 to Exit 1"), error.localizedDescription)
            XCTAssertTrue(error.localizedDescription.contains("leaves the painted road"), error.localizedDescription)
            XCTAssertFalse(error.localizedDescription.contains("Hidden authored name"))
        }
    }

    func testDirectGeoJSONValidationIdentifiesDisconnectedMarkerWithoutHiddenRouteName() throws {
        let valid = try GeoJSONExport(virtualCanvas: canvas).document(for: draft)
        for (kind, message) in [(LevelGeoJSON.Kind.entrance, "Entrance 0 does not start"),
                                (LevelGeoJSON.Kind.exit, "Exit 0 does not end")] {
            var collection = valid.collection
            let index = try XCTUnwrap(collection.features.firstIndex { $0.properties.kind == kind })
            collection.features[index].geometry = .point([150, 150])
            XCTAssertThrowsError(try LevelGeoJSON(collection: collection)) { error in
                XCTAssertTrue(error.localizedDescription.contains(message), error.localizedDescription)
                XCTAssertFalse(error.localizedDescription.contains("Hidden authored name"))
            }
        }
    }
}
