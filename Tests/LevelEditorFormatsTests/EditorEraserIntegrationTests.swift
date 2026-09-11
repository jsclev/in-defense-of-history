import CoreGraphics
import XCTest
@testable import LevelEditorFormats

/// Exercises the gesture handler used by EditorCanvas, real document edits and
/// UndoManager, and the native/GeoJSON persistence code. No user files or UI.
@MainActor
final class EditorEraserIntegrationTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 1000, height: 800),
                      playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800),
                      pathWidth: 140, towerSlotSize: CGSize(width: 10, height: 10),
                      towerMenuTotalSize: CGSize(width: 50, height: 50),
                      statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
                      heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }
    private var geometry: MapGeometry { MapGeometry(virtualCanvas: canvas) }
    private var transform: DesignTransform { DesignTransform(scale: 1, space: canvas.size) }

    private func document() -> MapDocument {
        let document = MapDocument(canvas: canvas)
        document.draft.roads = [.init(name: "Main", points: [Point(100, 200), Point(900, 200)])]
        document.draft.entrances = [Point(100, 200)]
        document.draft.exits = [Point(900, 200)]
        document.draft.callWaveButtons = [.init(position: Point(150, 320))]
        return document
    }

    private func area(_ document: MapDocument, preview: MapDraft.PaintStroke? = nil) -> CGPath {
        let d = document.draft
        return BrushGeometry.roadArea(roads: d.roads, paint: d.roadPaint,
                                     roadHalfWidth: 70, base: d.flattenedPath, preview: preview)
    }

    private func undoManager() -> UndoManager {
        let undo = UndoManager()
        undo.groupsByEvent = false
        return undo
    }

    private func commit(_ gesture: inout EditorPaintGesture, to document: MapDocument,
                        undo: UndoManager, at end: CGPoint? = nil) {
        undo.beginUndoGrouping()
        gesture.commit(at: end, to: document, mapGeometry: geometry, undoManager: undo)
        undo.endUndoGrouping()
    }

    func testCanvasCoordinatesAtDifferentZoomsAndPanOffsetsEraseUnderTheCursor() throws {
        let cases: [(CGFloat, CGPoint, CGPoint)] = [
            (0.125, CGPoint(x: 15, y: 25), CGPoint(x: 77.5, y: 92.5)),
            (0.5, CGPoint(x: 10, y: 70), CGPoint(x: 260, y: 340)),
            (1, .zero, CGPoint(x: 500, y: 540)),
            (3, CGPoint(x: -800, y: -400), CGPoint(x: 700, y: 1220))
        ]
        for (scale, offset, input) in cases {
            let document = document()
            var t = DesignTransform(scale: scale, space: canvas.size)
            t.offset = offset
            var gesture = EditorPaintGesture()
            gesture.begin(at: input, transform: t, width: 60, erases: true)
            XCTAssertEqual(gesture.cursor, Point(500, 260), "Scale \(scale)")
            XCTAssertEqual(try XCTUnwrap(gesture.preview).width * scale, 60 * scale)
            gesture.commit(to: document, mapGeometry: geometry, undoManager: nil)
            XCTAssertFalse(area(document).contains(CGPoint(x: 500, y: 250)))
            XCTAssertTrue(area(document).contains(CGPoint(x: 500, y: 220)))
        }
    }

    func testDragPreviewDoesNotChangeDocumentOrUndoUntilRelease() {
        let document = document(), undo = undoManager()
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 400, y: 540), transform: transform, width: 60, erases: true)
        for x in stride(from: 410.0, through: 600, by: 10) {
            gesture.append(CGPoint(x: x, y: 540))
            XCTAssertEqual(document.draft, before)
            XCTAssertFalse(undo.canUndo)
            XCTAssertFalse(area(document, preview: gesture.preview).contains(CGPoint(x: x, y: 250)))
        }
        let live = area(document, preview: gesture.preview)
        commit(&gesture, to: document, undo: undo)
        XCTAssertNil(gesture.preview)
        XCTAssertNil(gesture.cursor)
        for point in [CGPoint(x: 400, y: 250), CGPoint(x: 500, y: 200), CGPoint(x: 600, y: 250)] {
            XCTAssertEqual(area(document).contains(point), live.contains(point))
        }
        undo.undo()
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(undo.canUndo, "One drag must create only one undo step")
        undo.redo()
        XCTAssertFalse(area(document).contains(CGPoint(x: 500, y: 250)))
    }

    func testMouseUpIncludesFinalSampleEvenBelowPreviewSamplingDistance() throws {
        let document = document()
        var gesture = EditorPaintGesture()
        let t = DesignTransform(scale: 0.125, space: canvas.size)
        gesture.begin(at: CGPoint(x: 37.5, y: 75), transform: t, width: 60, erases: true)
        // Six canonical units is less than the eight-unit preview spacing.
        gesture.append(CGPoint(x: 38.25, y: 75))
        XCTAssertEqual(gesture.preview?.points.count, 1)
        let stroke = try XCTUnwrap(gesture.commit(at: CGPoint(x: 38.25, y: 75), to: document,
                                                mapGeometry: geometry, undoManager: nil))
        XCTAssertEqual(stroke.points.last, Point(306, 200))
        XCTAssertFalse(area(document).contains(CGPoint(x: 335, y: 200)))
    }

    func testCancelDiscardsPreviewAndIgnoresLateMoveAndRelease() {
        let document = document(), undo = undoManager()
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 400, y: 540), transform: transform, width: 60, erases: true)
        gesture.append(CGPoint(x: 600, y: 540))
        gesture.cancel() // Same handler called for cancelled touch/pinch input.
        gesture.append(CGPoint(x: 800, y: 540))
        XCTAssertNil(gesture.commit(at: CGPoint(x: 850, y: 540), to: document,
                                    mapGeometry: geometry, undoManager: undo))
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(gesture.isActive)
        XCTAssertFalse(undo.canUndo)

        gesture.begin(at: CGPoint(x: 700, y: 540), transform: transform, width: 20, erases: true)
        commit(&gesture, to: document, undo: undo)
        XCTAssertTrue(area(document).contains(CGPoint(x: 500, y: 250)))
        XCTAssertFalse(area(document).contains(CGPoint(x: 700, y: 260)))
    }

    func testDuplicateReleaseCannotCommitTwice() {
        let document = document(), undo = undoManager()
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 500, y: 540), transform: transform, width: 60, erases: true)
        commit(&gesture, to: document, undo: undo)
        let after = document.draft
        XCTAssertNil(gesture.commit(at: CGPoint(x: 600, y: 540), to: document,
                                    mapGeometry: geometry, undoManager: undo))
        XCTAssertEqual(document.draft, after)
        undo.undo()
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(undo.canUndo)
    }

    func testClickWithoutDraggingErasesACircularDab() {
        let document = document()
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 500, y: 600), transform: transform, width: 60, erases: true)
        gesture.commit(to: document, mapGeometry: geometry, undoManager: nil)
        XCTAssertFalse(area(document).contains(CGPoint(x: 500, y: 200)))
        XCTAssertTrue(area(document).contains(CGPoint(x: 500, y: 240)))
        XCTAssertTrue(area(document).contains(CGPoint(x: 540, y: 200)))
    }

    func testMissDoesNotDirtyDocumentOrAddUndo() {
        let document = document(), undo = undoManager()
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 500, y: 300), transform: transform, width: 60, erases: true)
        gesture.commit(to: document, mapGeometry: geometry, undoManager: undo)
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(undo.canUndo)
    }

    func testErasingLeavesTowersHeroesMarkersImagesAndWaveDataIntact() {
        let document = document()
        document.draft.slots = [Point(500, 260)]
        document.draft.placeHero(.primary, at: Point(500, 260))
        document.draft.placeHero(.secondary, at: Point(520, 260))
        document.draft.callWaveButtons = [.init(position: Point(500, 260), pathIndices: [0])]
        document.draft.intendedSolution = [.init(at: 3, kind: "place", emplacement: "Minuteman Post", slot: 0)]
        document.draft.backgroundImagePath = "map.png"
        document.draft.backgroundImageData = Data([1, 2, 3])
        document.draft.overlayImagePath = "trees.png"
        document.draft.overlayImageData = Data([4, 5, 6])
        document.draft.hiddenLayers = ["grid"]
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 500, y: 540), transform: transform, width: 180, erases: true)
        gesture.commit(to: document, mapGeometry: geometry, undoManager: nil)
        var expected = before
        expected.roads[0].erasedArea = document.draft.roads[0].erasedArea
        XCTAssertNotNil(expected.roads[0].erasedArea)
        XCTAssertEqual(document.draft, expected, "Only the road cutout may change")
    }

    func testGestureCutSurvivesActualNativeFileAndGeoJSONFileRoundTrips() throws {
        let document = document()
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 400, y: 540), transform: transform, width: 60, erases: true)
        gesture.commit(at: CGPoint(x: 650, y: 540), to: document, mapGeometry: geometry, undoManager: nil)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let nativeURL = directory.appendingPathComponent("eraser.tdmap")
        let snapshot = try document.snapshot(contentType: .tdmap)
        try snapshot.data().write(to: nativeURL, options: .atomic)
        let saved = try NativeMapFile.read(Data(contentsOf: nativeURL))
        XCTAssertEqual(saved.draft, document.draft)
        let geoURL = directory.appendingPathComponent("eraser.geojson")
        try GeoJSONExport(virtualCanvas: saved.canvas).document(for: saved.draft).dump(to: geoURL)
        let imported = try GeoJSONImport.draft(from: Data(contentsOf: geoURL))
        let surface = BrushGeometry.roadArea(roads: imported.roads, paint: imported.roadPaint,
                                            roadHalfWidth: 70, base: imported.flattenedPath)
        XCTAssertFalse(surface.contains(CGPoint(x: 500, y: 250)))
        XCTAssertTrue(surface.contains(CGPoint(x: 500, y: 220)))
        XCTAssertEqual(imported.entrances, saved.draft.entrances)
        XCTAssertEqual(imported.exits, saved.draft.exits)
    }

    func testEraserThenPainterUseSeparateStrokesAndUndoSeparately() {
        let document = document(), undo = undoManager()
        let before = document.draft
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: 500, y: 600), transform: transform, width: 60, erases: true)
        commit(&gesture, to: document, undo: undo)
        let erased = document.draft
        gesture.begin(at: CGPoint(x: 500, y: 600), transform: transform, width: 20, erases: false)
        XCTAssertTrue(area(document, preview: gesture.preview).contains(CGPoint(x: 500, y: 200)))
        commit(&gesture, to: document, undo: undo)
        XCTAssertTrue(area(document).contains(CGPoint(x: 500, y: 200)))
        XCTAssertFalse(area(document).contains(CGPoint(x: 520, y: 200)))
        undo.undo()
        XCTAssertEqual(document.draft, erased)
        undo.undo()
        XCTAssertEqual(document.draft, before)
        XCTAssertFalse(undo.canUndo)
        undo.redo()
        undo.redo()
        XCTAssertTrue(area(document).contains(CGPoint(x: 500, y: 200)))
    }

    func testSeparateDocumentsHaveIndependentPreviewsAndUndo() {
        let first = document(), second = document(), undo = undoManager()
        let original = second.draft
        var firstGesture = EditorPaintGesture(), secondGesture = EditorPaintGesture()
        firstGesture.begin(at: CGPoint(x: 400, y: 600), transform: transform, width: 60, erases: true)
        secondGesture.begin(at: CGPoint(x: 700, y: 600), transform: transform, width: 60, erases: true)
        commit(&firstGesture, to: first, undo: undo)
        secondGesture.cancel()
        XCTAssertEqual(second.draft, original)
        XCTAssertFalse(area(first).contains(CGPoint(x: 400, y: 200)))
        XCTAssertTrue(area(first).contains(CGPoint(x: 700, y: 200)))
        undo.undo()
        XCTAssertEqual(first.draft, original)
        XCTAssertEqual(second.draft, original)
    }

    func testCoordinatesClampToCanvasAndInvalidInputCannotCommit() {
        let document = document()
        var gesture = EditorPaintGesture()
        gesture.begin(at: CGPoint(x: -50, y: -100), transform: transform, width: 60, erases: true)
        gesture.append(CGPoint(x: 1100, y: 1000))
        XCTAssertEqual(gesture.preview?.points, [Point(0, 800), Point(1000, 0)])
        gesture.cancel()
        for width in [0.0, -10, .nan, .infinity] {
            gesture.begin(at: CGPoint(x: 500, y: 600), transform: transform, width: width, erases: true)
            XCTAssertNil(gesture.commit(to: document, mapGeometry: geometry, undoManager: nil))
        }
        gesture.begin(at: CGPoint(x: CGFloat.nan, y: 600), transform: transform, width: 60, erases: true)
        XCTAssertFalse(gesture.isActive)
        XCTAssertNil(document.draft.roads[0].erasedArea)
    }
}
