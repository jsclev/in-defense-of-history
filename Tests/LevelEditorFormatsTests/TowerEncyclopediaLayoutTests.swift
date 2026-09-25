import XCTest
@testable import LevelEditorFormats

final class TowerEncyclopediaLayoutTests: XCTestCase {
    func testArtworkUsesTheAuthoredCanvasAndEveryControlFitsThePlayArea() throws {
        let fixture = try AuthoredDatabaseFixture()
        let canvas = try fixture.db.virtualCanvasDao.get()
        for (physical, safe) in [
            (CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 372)),
            (CGRect(x: 0, y: 0, width: 740, height: 360), CGRect(x: 20, y: 0, width: 700, height: 340)),
            (CGRect(x: 0, y: 0, width: 1194, height: 834), CGRect(x: 0, y: 24, width: 1194, height: 790))
        ] {
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: physical, safeInsetsRect: safe)
            let layout = TowerEncyclopediaLayout(runtimeCanvas: runtime, doneAspect: 2.5)
            let play = runtime.playAreaRect
            XCTAssertTrue(play.contains(layout.scrollFrame))
            XCTAssertTrue(layout.scrollFrame.contains(layout.contentFrame))
            for margin in [layout.scrollFrame.minX - play.minX, play.maxX - layout.scrollFrame.maxX,
                           layout.scrollFrame.minY - play.minY, play.maxY - layout.scrollFrame.maxY] {
                XCTAssertGreaterThan(margin, 0, "Every scroll edge must be fully inside the play area")
                XCTAssertLessThan(margin, play.height * 0.01, "Keep the scroll close to the play-area edges")
            }
            for frame in [layout.contentFrame, layout.gridFrame, layout.detailFrame, layout.doneFrame] {
                XCTAssertTrue(play.contains(frame), "Control frame \(frame) escapes play area \(play)")
            }
            XCTAssertGreaterThanOrEqual(layout.cellSide, TouchTarget.minimum)
            XCTAssertEqual(layout.gridGap, 0, "Tower cells meet at shared dividers")
            XCTAssertGreaterThanOrEqual(layout.doneFrame.height, TouchTarget.minimum)
            XCTAssertFalse(layout.gridFrame.intersects(layout.detailFrame))
            XCTAssertFalse(layout.gridFrame.intersects(layout.doneFrame))
            XCTAssertFalse(layout.detailFrame.intersects(layout.doneFrame))
            XCTAssertEqual(layout.backgroundFrame.width / layout.backgroundFrame.height,
                           canvas.size.width / canvas.size.height, accuracy: 1e-9)
            XCTAssertEqual(layout.backgroundFrame.width, canvas.size.width * runtime.scaleFactor, accuracy: 1e-9)
            XCTAssertEqual(layout.gridFrame.width, layout.cellSide * 5 + layout.gridGap * 4, accuracy: 1e-9)
            XCTAssertEqual(layout.gridFrame.height, layout.cellSide * 6 + layout.gridGap * 5, accuracy: 1e-9)
            XCTAssertEqual(layout.gridFrame.height, layout.contentFrame.height, accuracy: 1e-9,
                           "The six-row grid must use the space released by removing the heading")
            // The full painted wood canvas covers the device, while the scroll
            // and buttons retain the exact same map-to-view transform.
            XCTAssertTrue(layout.backgroundFrame.contains(physical))
            let projectedPlay = CGRect(
                x: layout.backgroundFrame.minX + canvas.playAreaRect.minX * runtime.scaleFactor,
                y: layout.backgroundFrame.minY + (canvas.size.height - canvas.playAreaRect.maxY) * runtime.scaleFactor,
                width: canvas.playAreaRect.width * runtime.scaleFactor,
                height: canvas.playAreaRect.height * runtime.scaleFactor)
            XCTAssertEqual(projectedPlay.minX, play.minX, accuracy: 1e-9)
            XCTAssertEqual(projectedPlay.minY, play.minY, accuracy: 1e-9)
            XCTAssertEqual(projectedPlay.size, play.size)
        }
    }
}
