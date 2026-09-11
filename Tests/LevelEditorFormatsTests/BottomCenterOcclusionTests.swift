import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class BottomCenterOcclusionTests: XCTestCase {
    private let canvas = VirtualCanvas(size: CGSize(width: 2868, height: 2064),
        playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
        pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
        towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
        statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
        masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
        heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
        miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))

    func testAuthoredCutoutIsCenteredFlushWithBottomAndUsesReducedCornerHeight() throws {
        let cutout = canvas.bottomCenterOcclusionArea
        XCTAssertEqual(cutout.midX, canvas.playAreaRect.midX, accuracy: 1e-8)
        XCTAssertEqual(cutout.minY, canvas.playAreaRect.minY)
        XCTAssertEqual(cutout.height, 33.048, accuracy: 1e-8)
        for corner in [canvas.lowerLeftOcclusionArea, canvas.lowerRightOcclusionArea,
                       canvas.upperRightOcclusionArea] {
            XCTAssertEqual(cutout.height, corner.height * 0.2, accuracy: 1e-8)
        }
        XCTAssertEqual(cutout.width, 2868 * 315 / 1133, accuracy: 1e-8)
        XCTAssertEqual(canvas.cornerOcclusionAreas.count, 4)
        XCTAssertEqual(canvas.occlusionAreas.count, 5)
        // Older saved documents have no derived cutout fields.
        let data = try JSONEncoder().encode(canvas)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(fields["bottomCenterOcclusionArea"])
        let restored = try JSONDecoder().decode(VirtualCanvas.self, from: data)
        XCTAssertEqual(restored.bottomCenterOcclusionArea, cutout)
    }

    func testCutoutIsRemovedFromPlayAndTowerPlacementShapes() {
        let cutout = canvas.bottomCenterOcclusionArea
        let shape = canvas.playAreaShape
        XCTAssertFalse(shape.contains(CGPoint(x: cutout.midX, y: cutout.midY)))
        XCTAssertTrue(shape.contains(CGPoint(x: cutout.midX, y: cutout.maxY + 1)))
        XCTAssertTrue(shape.contains(CGPoint(x: cutout.maxX + 1, y: cutout.midY)))
        for corner in canvas.cornerOcclusionAreas {
            XCTAssertFalse(shape.contains(CGPoint(x: corner.midX, y: corner.midY)))
        }
        // The tower menu needs the same clearance above this cut as the corners.
        let centreLimit = cutout.maxY + canvas.towerMenuTotalSize.height / 2
        XCTAssertFalse(canvas.towerSlotValidCentres.contains(CGPoint(x: cutout.midX, y: centreLimit - 1)))
        XCTAssertTrue(canvas.towerSlotValidCentres.contains(CGPoint(x: cutout.midX, y: centreLimit + 1)))
        let footprintLimit = centreLimit - canvas.towerSlotSize.height / 2
        XCTAssertFalse(canvas.towerSlotValidFootprint.contains(CGPoint(x: cutout.midX, y: footprintLimit - 1)))
        XCTAssertTrue(canvas.towerSlotValidFootprint.contains(CGPoint(x: cutout.midX, y: footprintLimit + 1)))
        let layout = TowerMenuLayout(virtualCanvas: canvas)
        let menuLimit = cutout.maxY + layout.slotSafeInset(.bottom)
        XCTAssertFalse(layout.slotMenuSafeShape.contains(CGPoint(x: cutout.midX, y: menuLimit - 1)))
        XCTAssertTrue(layout.slotMenuSafeShape.contains(CGPoint(x: cutout.midX, y: menuLimit + 1)))
    }

    func testRuntimeWidthUsesFullScreenAcrossLandscapeSizesAndSafeInsets() {
        let fixtures: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 0, y: 0, width: 812, height: 375), CGRect(x: 50, y: 0, width: 712, height: 355)),
            (CGRect(x: 0, y: 0, width: 1133, height: 744), CGRect(x: 0, y: 0, width: 1133, height: 719)),
            (CGRect(x: 40, y: 30, width: 1376, height: 1032), CGRect(x: 40, y: 54, width: 1376, height: 988))
        ]
        for (physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: physical, safeInsetsRect: safe)
            let cutout = runtime.bottomCenterOcclusionArea
            XCTAssertEqual(cutout.width / physical.width, 315 / 1133, accuracy: 1e-8)
            XCTAssertEqual(cutout.midX, runtime.playAreaRect.midX, accuracy: 1e-8)
            XCTAssertEqual(cutout.maxY, runtime.playAreaRect.maxY, accuracy: 1e-8)
            XCTAssertEqual(cutout.height, runtime.playAreaRect.height * 0.0306, accuracy: 1e-8)
            XCTAssertTrue(runtime.playAreaRect.insetBy(dx: -1e-8, dy: -1e-8).contains(cutout))
            XCTAssertFalse(runtime.runtimePlayArea.contains(CGPoint(x: cutout.midX, y: cutout.midY)))
            XCTAssertTrue(runtime.runtimePlayArea.contains(CGPoint(x: cutout.midX, y: cutout.minY - 1)))
            let limit = cutout.minY - (canvas.towerMenuTotalSize.height - canvas.towerSlotSize.height)
                / 2 * runtime.scaleFactor
            XCTAssertFalse(runtime.towerSlotValidArea.contains(CGPoint(x: cutout.midX, y: limit + 1)))
            XCTAssertTrue(runtime.towerSlotValidArea.contains(CGPoint(x: cutout.midX, y: limit - 1)))
            XCTAssertEqual(runtime.occlusionAreas.count, 5)
            XCTAssertTrue(runtime.occlusionAreas.contains(cutout))
        }
    }

    func testEditorAndRuntimeUseTheSameAuthoredReferenceAndExtremeWidthsStayInsidePlay() {
        let runtime = RuntimeCanvas(virtualCanvas: canvas,
            physicalRect: CGRect(origin: .zero, size: canvas.size), safeInsetsRect: canvas.playAreaRect)
        XCTAssertEqual(runtime.bottomCenterOcclusionArea.width, canvas.bottomCenterOcclusionArea.width, accuracy: 1e-8)
        XCTAssertEqual(runtime.bottomCenterOcclusionArea.height, canvas.bottomCenterOcclusionArea.height, accuracy: 1e-8)
        for width in [CGFloat(0), -100, 100_000] {
            let cutout = canvas.bottomCenterOcclusionArea(forScreenWidth: width)
            XCTAssertGreaterThanOrEqual(cutout.width, 0)
            XCTAssertLessThanOrEqual(cutout.width, canvas.playAreaRect.width)
            XCTAssertEqual(cutout.midX, canvas.playAreaRect.midX, accuracy: 1e-8)
        }
    }
}
