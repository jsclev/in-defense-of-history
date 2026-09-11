import CoreGraphics
import XCTest
@testable import LevelEditorFormats

final class EditorEraserTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 1000, height: 800),
                      playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800),
                      pathWidth: 140, towerSlotSize: CGSize(width: 10, height: 10),
                      towerMenuTotalSize: CGSize(width: 50, height: 50),
                      statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
                      heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    private var draft: MapDraft {
        var d = MapDraft.starter
        d.roads = [.init(name: "Main", points: [Point(100, 200), Point(900, 200)])]
        d.entrances = [Point(100, 200)]
        d.exits = [Point(900, 200)]
        d.callWaveButtons = [.init(position: Point(100, 320))]
        return d
    }

    private func area(_ d: MapDraft) -> CGPath {
        BrushGeometry.roadArea(roads: d.roads, paint: d.roadPaint,
                               roadHalfWidth: canvas.pathWidth / 2, base: d.flattenedPath)
    }

    private func erase(_ d: inout MapDraft, at point: Point, width: Double = 60) {
        d.applyErase(.init(points: [point], width: width, erases: true),
                     mapGeometry: MapGeometry(virtualCanvas: canvas))
    }

    func testCircularDabErasesVisibleRoadEdgeWithoutTouchingCenterline() {
        var d = draft
        erase(&d, at: Point(500, 260))
        XCTAssertFalse(area(d).contains(CGPoint(x: 500, y: 250)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 500, y: 220)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 540, y: 250)))
    }

    func testSmallCenterDabDoesNotRemovePathOutsideTheCircle() {
        var d = draft
        erase(&d, at: Point(500, 200))
        XCTAssertFalse(area(d).contains(CGPoint(x: 500, y: 200)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 500, y: 250)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 535, y: 200)))
    }

    func testEraserTrimsPaintedEdgesAndSingleDabs() {
        var d = draft
        d.roads = []
        d.roadPaint = [.init(points: [Point(300, 200)], width: 140, erases: false),
                       .init(points: [Point(500, 200), Point(800, 200)], width: 140, erases: false)]
        erase(&d, at: Point(300, 260))
        erase(&d, at: Point(600, 260))
        XCTAssertFalse(area(d).contains(CGPoint(x: 300, y: 250)))
        XCTAssertFalse(area(d).contains(CGPoint(x: 600, y: 250)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 300, y: 200)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 600, y: 200)))
    }

    func testDraggedPreviewAndCommitMatchTheBrushAcrossOverlappingSurfaces() throws {
        var d = draft
        d.flattenedPath = try PathFlattening.geometry(from: CGPath(
            rect: CGRect(x: 200, y: 140, width: 600, height: 100), transform: nil))
        d.roads.append(.init(name: "Crossing", points: [Point(400, 100), Point(400, 350)]))
        d.roadPaint = [.init(points: [Point(600, 220)], width: 100, erases: false)]
        let eraser = MapDraft.PaintStroke(points: [Point(350, 250), Point(550, 260), Point(650, 170)],
                                         width: 60, erases: true)
        let original = area(d)
        let brush = BrushGeometry.strokeArea(points: eraser.points, width: eraser.width)
        let preview = BrushGeometry.roadArea(roads: d.roads, paint: d.roadPaint,
            roadHalfWidth: 70, base: d.flattenedPath, preview: eraser)
        d.applyErase(eraser, mapGeometry: MapGeometry(virtualCanvas: canvas))
        let committed = area(d)
        for x in stride(from: 200.7, through: 800, by: 11) {
            for y in stride(from: 120.7, through: 340, by: 11) {
                let point = CGPoint(x: x, y: y)
                let expected = original.contains(point) && !brush.contains(point)
                XCTAssertEqual(preview.contains(point), expected, "Preview at \(point)")
                XCTAssertEqual(committed.contains(point), expected, "Commit at \(point)")
            }
        }
    }

    func testErasingKeepsEditableWaypointsAndWaveAssignments() {
        var d = draft
        d.roads.append(.init(name: "Other route", points: [Point(100, 500), Point(900, 500)]))
        d.waves[0].lines[0].road = 1
        let before = d
        erase(&d, at: Point(500, 200), width: 180)
        XCTAssertEqual(d.roads.map(\.points), before.roads.map(\.points))
        XCTAssertEqual(d.roads.map(\.name), before.roads.map(\.name))
        XCTAssertEqual(d.waves, before.waves)
        XCTAssertFalse(area(d).contains(CGPoint(x: 500, y: 200)))
    }

    func testCutsSurviveNativeSaveAndGeoJSONExport() throws {
        var d = draft
        d.roadPaint = [.init(points: [Point(500, 200)], width: 180, erases: false)]
        erase(&d, at: Point(500, 260))
        erase(&d, at: Point(600, 200))
        var restored = try NativeMapFile.read(NativeMapFile(draft: d, canvas: canvas).data()).draft
        restored.normalize(mapGeometry: MapGeometry(virtualCanvas: canvas))
        XCTAssertEqual(restored, d)
        let exported = try GeoJSONExport(virtualCanvas: canvas).document(for: restored)
        let imported = try GeoJSONImport.draft(from: exported.data())
        XCTAssertFalse(area(imported).contains(CGPoint(x: 500, y: 250)))
        XCTAssertFalse(area(imported).contains(CGPoint(x: 600, y: 200)))
        XCTAssertTrue(area(imported).contains(CGPoint(x: 500, y: 200)))
        XCTAssertTrue(area(imported).contains(CGPoint(x: 600, y: 250)))
    }

    func testNewPaintCanRefillACutAndBeErasedAgain() {
        var d = draft
        erase(&d, at: Point(500, 200))
        d.roadPaint.append(.init(points: [Point(500, 200)], width: 20, erases: false))
        XCTAssertTrue(area(d).contains(CGPoint(x: 500, y: 200)))
        XCTAssertFalse(area(d).contains(CGPoint(x: 520, y: 200)))
        erase(&d, at: Point(500, 200), width: 6)
        XCTAssertFalse(area(d).contains(CGPoint(x: 500, y: 200)))
        XCTAssertTrue(area(d).contains(CGPoint(x: 507, y: 200)))
    }

    func testCompleteEraseAndRepaintPreserveImportedRouteIndices() throws {
        var d = draft
        d.roads = []
        d.flattenedPath = try PathFlattening.geometry(from: CGPath(
            rect: CGRect(x: 450, y: 180, width: 100, height: 40), transform: nil))
        d.entrances.append(Point(500, 220))
        d.waves[0].lines[0].road = 1
        erase(&d, at: Point(500, 200), width: 200)
        XCTAssertTrue(area(d).isEmpty)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).document(for: d))
        d.roadPaint.append(.init(points: [Point(400, 200), Point(700, 200)], width: 100, erases: false))
        let result = try GeoJSONExport(virtualCanvas: canvas).document(for: d)
        XCTAssertEqual(result.collection.waves[0].lines[0].pathIndex, 1)
    }

    func testLegacyStoredErasuresPreservePaintOrderAndDoNotCutWaypoints() {
        var d = draft
        let points = d.roads[0].points
        d.roadPaint = [.init(points: [Point(500, 260)], width: 60, erases: true),
                       .init(points: [Point(500, 250)], width: 10, erases: false)]
        d.normalize(mapGeometry: MapGeometry(virtualCanvas: canvas))
        XCTAssertEqual(d.roads[0].points, points)
        XCTAssertFalse(d.roadPaint.contains(where: \.erases))
        XCTAssertTrue(area(d).contains(CGPoint(x: 500, y: 250)))
        XCTAssertFalse(area(d).contains(CGPoint(x: 515, y: 250)))
    }

    func testBrushSizeAndEdgeMatrixMatchesCircularFootprint() {
        let original = area(draft)
        for width in [10.0, 60, 140, 300] {
            for center in [Point(500, 200), Point(500, 265), Point(100, 200), Point(950, 240)] {
                var d = draft
                erase(&d, at: center, width: width)
                let erased = area(d)
                for x in stride(from: 21.3, through: 990, by: 13) {
                    for y in stride(from: 51.7, through: 380, by: 13) {
                        let distance = hypot(x - center.x, y - center.y)
                        // Exported curves are flattened to 0.25 canonical units.
                        guard abs(distance - width / 2) > 0.3 else { continue }
                        let point = CGPoint(x: x, y: y)
                        let expected = original.contains(point) && distance > width / 2
                        XCTAssertEqual(erased.contains(point), expected,
                            "Width \(width), center \(center), sample \(point)")
                    }
                }
            }
        }
    }

    func testRepeatingTheSameEraseDoesNotCreateAnotherEdit() throws {
        var d = draft
        d.roadPaint = [.init(points: [Point(500, 200)], width: 140, erases: false)]
        d.flattenedPath = try PathFlattening.geometry(from: area(d))
        erase(&d, at: Point(500, 260))
        let once = d
        for _ in 0..<5 {
            erase(&d, at: Point(500, 260))
            XCTAssertEqual(d, once)
        }
    }

    func testFastSparseDragErasesContinuouslyLikeDenseSamples() {
        var sparse = draft, dense = draft
        let endpoints = [Point(350, 120), Point(650, 280)]
        let samples = (0...60).map { i in Point(350 + Double(i) * 5, 120 + Double(i) * 160 / 60) }
        sparse.applyErase(.init(points: endpoints, width: 40, erases: true),
                          mapGeometry: MapGeometry(virtualCanvas: canvas))
        dense.applyErase(.init(points: samples, width: 40, erases: true),
                         mapGeometry: MapGeometry(virtualCanvas: canvas))
        let sparseArea = area(sparse), denseArea = area(dense)
        for x in stride(from: 300.7, through: 700, by: 9) {
            for y in stride(from: 100.7, through: 300, by: 9) {
                let p = CGPoint(x: x, y: y)
                XCTAssertEqual(sparseArea.contains(p), denseArea.contains(p), "At \(p)")
            }
        }
        XCTAssertFalse(sparseArea.contains(CGPoint(x: 500, y: 200)))
    }

    func testImportedHolesAndDisconnectedIslandsSurviveAnEdgeCutAndReload() throws {
        let outer = CGPath(rect: CGRect(x: 200, y: 100, width: 400, height: 300), transform: nil)
        let hole = CGPath(rect: CGRect(x: 300, y: 200, width: 150, height: 100), transform: nil)
        let island = CGPath(rect: CGRect(x: 750, y: 500, width: 100, height: 100), transform: nil)
        var d = draft
        d.roads = []
        d.flattenedPath = try PathFlattening.geometry(from: outer.subtracting(hole).union(island))
        erase(&d, at: Point(200, 250))
        let exported = try GeoJSONExport(virtualCanvas: canvas).document(for: d)
        let restored = try GeoJSONImport.draft(from: exported.data())
        XCTAssertFalse(area(restored).contains(CGPoint(x: 210, y: 250)))
        XCTAssertFalse(area(restored).contains(CGPoint(x: 350, y: 250)))
        XCTAssertTrue(area(restored).contains(CGPoint(x: 250, y: 250)))
        XCTAssertTrue(area(restored).contains(CGPoint(x: 800, y: 550)))
        XCTAssertFalse(area(restored).contains(CGPoint(x: 700, y: 450)))
    }

    func testCompleteNativeAndPaintEraseCannotReappearOnSave() throws {
        var d = draft
        d.roadPaint = [.init(points: [Point(500, 300)], width: 40, erases: false)]
        erase(&d, at: Point(500, 200), width: 2000)
        XCTAssertTrue(area(d).isEmpty)
        let restored = try NativeMapFile.read(NativeMapFile(draft: d, canvas: canvas).data()).draft
        XCTAssertTrue(area(restored).isEmpty)
        XCTAssertThrowsError(try GeoJSONExport(virtualCanvas: canvas).document(for: restored))
    }

    func testInvalidEraserDataIsANoOp() {
        let invalid: [MapDraft.PaintStroke] = [
            .init(points: [], width: 60, erases: true),
            .init(points: [Point(500, 200)], width: 0, erases: true),
            .init(points: [Point(500, 200)], width: -10, erases: true),
            .init(points: [Point(500, 200)], width: .infinity, erases: true),
            .init(points: [Point(500, 200)], width: .nan, erases: true),
            .init(points: [Point(.nan, 200)], width: 60, erases: true),
            .init(points: [Point(500, .infinity)], width: 60, erases: true)
        ]
        for stroke in invalid {
            var d = draft
            d.applyErase(stroke, mapGeometry: MapGeometry(virtualCanvas: canvas))
            XCTAssertEqual(d, draft)
        }
    }

    @MainActor
    func testOneDragHasOneUndoAndRedo() {
        let document = MapDocument(canvas: canvas)
        document.draft = draft
        let before = document.draft
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        document.edit(undo) {
            $0.applyErase(.init(points: [Point(400, 260), Point(600, 260)], width: 60, erases: true),
                          mapGeometry: MapGeometry(virtualCanvas: canvas))
        }
        undo.endUndoGrouping()
        let after = document.draft
        XCTAssertFalse(area(after).contains(CGPoint(x: 500, y: 250)))
        undo.undo()
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(undo.canUndo)
        undo.redo()
        XCTAssertEqual(document.draft, after)
    }
}
