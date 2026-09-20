import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class PathPlayAreaTests: XCTestCase {
    private func canvas(menuSize: CGSize = CGSize(width: 435.9, height: 390.9)) -> VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: menuSize,
            statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
            masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    private func assertSideBoundaries(path: CGPath, slots: CGPath, centres: CGPath,
                                      play: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(path.boundingBoxOfPath.minX, play.minX, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(path.boundingBoxOfPath.maxX, play.maxX, accuracy: 1e-6, file: file, line: line)
        XCTAssertGreaterThan(slots.boundingBoxOfPath.minX, play.minX, file: file, line: line)
        XCTAssertLessThan(slots.boundingBoxOfPath.maxX, play.maxX, file: file, line: line)
        for x in [play.minX + 0.001, play.maxX - 0.001] {
            let point = CGPoint(x: x, y: play.midY)
            XCTAssertTrue(path.contains(point), "Roads may reach the play area's side edges", file: file, line: line)
            XCTAssertFalse(slots.contains(point), "Tower pads need menu clearance", file: file, line: line)
            XCTAssertFalse(centres.contains(point), file: file, line: line)
        }
    }

    func testVirtualPathsReachBothPlayAreaEdgesWhileTowerSlotsStayInset() {
        let vc = canvas()
        assertSideBoundaries(path: vc.playAreaShape, slots: vc.towerSlotValidFootprint,
                             centres: vc.towerSlotValidCentres, play: vc.playAreaRect)
    }

    func testPathTopInsetPreservesReferenceRectangleAndCornerEdges() {
        let vc = canvas()
        XCTAssertEqual(vc.playAreaRect, CGRect(x: 474, y: 492, width: 1920, height: 1080))
        XCTAssertEqual(vc.playAreaShape.boundingBoxOfPath.maxY, 1474.8, accuracy: 1e-5)
        XCTAssertFalse(vc.playAreaShape.contains(CGPoint(x: 1578, y: 1475.8)))
        XCTAssertTrue(vc.playAreaShape.contains(CGPoint(x: 1578, y: 1473.8)))
        for corner in [vc.upperLeftOcclusionArea, vc.upperRightOcclusionArea] {
            XCTAssertFalse(vc.playAreaShape.contains(CGPoint(x: corner.midX, y: corner.minY + 1)))
            XCTAssertTrue(vc.playAreaShape.contains(CGPoint(x: corner.midX, y: corner.minY - 1)))
        }
    }

    func testRuntimePathsUsePlayAreaExtentsAcrossScreenShapesAndOrigins() {
        for (physical, safe) in [
            (CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 373)),
            (CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 40, y: 30, width: 1133, height: 744), CGRect(x: 40, y: 54, width: 1133, height: 695))
        ] {
            let runtime = RuntimeCanvas(virtualCanvas: canvas(), physicalRect: physical, safeInsetsRect: safe)
            assertSideBoundaries(path: runtime.runtimePlayArea, slots: runtime.towerSlotValidArea,
                                 centres: runtime.towerSlotValidCentres, play: runtime.playAreaRect)
            XCTAssertEqual(runtime.runtimePlayArea.boundingBoxOfPath.minY,
                           runtime.playAreaRect.minY + runtime.playAreaRect.height * 0.09, accuracy: 1e-5)
        }
    }

    func testLargerTowerMenusCannotNarrowThePathArea() {
        let original = canvas()
        let largerMenu = canvas(menuSize: CGSize(width: 900, height: 650))
        XCTAssertTrue(original.playAreaShape.subtracting(largerMenu.playAreaShape).isEmpty)
        XCTAssertTrue(largerMenu.playAreaShape.subtracting(original.playAreaShape).isEmpty)
        XCTAssertGreaterThan(largerMenu.towerSlotValidFootprint.boundingBoxOfPath.minX,
                             original.towerSlotValidFootprint.boundingBoxOfPath.minX)
        XCTAssertLessThan(largerMenu.towerSlotValidFootprint.boundingBoxOfPath.maxX,
                          original.towerSlotValidFootprint.boundingBoxOfPath.maxX)
    }
}
