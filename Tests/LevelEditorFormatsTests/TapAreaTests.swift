import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class TapAreaTests: XCTestCase {
    private func canvas(upperLeft: CGSize = CGSize(width: 0.30, height: 0.19),
                        upperRight: CGSize = CGSize(width: 0.15, height: 0.17)) -> VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: upperLeft, masterControlsSizeFraction: upperRight,
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    func testTapAreaRemovesExactlyTheExposedTopStrip() {
        let vc = canvas()
        let tap = vc.tapAreaShape
        let play = vc.playAreaShape
        let excluded = CGRect(x: 1050, y: 1518, width: 1056, height: 54)
        XCTAssertEqual(vc.tapAreaTopExclusionArea, excluded)
        XCTAssertTrue(tap.subtracting(play).isEmpty, "Tap area must be a subset of play area")
        let removed = play.subtracting(tap)
        // CoreGraphics boolean paths have sub-micro-unit rounding at edges.
        let outer = CGPath(rect: excluded.insetBy(dx: -1e-5, dy: -1e-5), transform: nil)
        let inner = CGPath(rect: excluded.insetBy(dx: 1e-5, dy: 1e-5), transform: nil)
        XCTAssertTrue(removed.subtracting(outer).isEmpty)
        XCTAssertTrue(inner.subtracting(removed).isEmpty)
        XCTAssertEqual(tap.boundingBoxOfPath.maxY, 1518, accuracy: 1e-5)
        XCTAssertTrue(play.contains(CGPoint(x: excluded.midX, y: excluded.midY)))
        XCTAssertFalse(tap.contains(CGPoint(x: excluded.midX, y: excluded.midY)))
        XCTAssertTrue(tap.contains(CGPoint(x: excluded.midX, y: excluded.minY - 1)))
        for occlusion in vc.occlusionAreas {
            XCTAssertFalse(tap.contains(CGPoint(x: occlusion.midX, y: occlusion.midY)))
        }
        // The top-facing edges below both corner cutouts stay in place.
        for corner in [vc.upperLeftOcclusionArea, vc.upperRightOcclusionArea] {
            XCTAssertTrue(tap.contains(CGPoint(x: corner.midX, y: corner.minY - 1)))
        }
    }

    func testRuntimeInsetUsesPlayHeightAndFollowsSafeAreaAndCoordinateOrigin() {
        let vc = canvas()
        let fixtures: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 373)),
            (CGRect(x: 0, y: 0, width: 874, height: 402), CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 0, y: 0, width: 604.444444, height: 340), CGRect(x: 0, y: 0, width: 604.444444, height: 340)),
            (CGRect(x: 40, y: 30, width: 1133, height: 744), CGRect(x: 40, y: 54, width: 1133, height: 695))
        ]
        for (physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let play = runtime.playAreaRect
            let top = play.minY + play.height * 0.05
            let gapMidX = play.minX + play.width * 0.575
            XCTAssertEqual(runtime.runtimeTapArea.boundingBoxOfPath.minY, top, accuracy: 1e-5)
            XCTAssertTrue(runtime.runtimeTapArea.subtracting(runtime.runtimePlayArea).isEmpty)
            XCTAssertFalse(runtime.runtimeTapArea.contains(CGPoint(x: gapMidX, y: top - 0.5)))
            XCTAssertTrue(runtime.runtimePlayArea.contains(CGPoint(x: gapMidX, y: top - 0.5)))
            XCTAssertTrue(runtime.runtimeTapArea.contains(CGPoint(x: gapMidX, y: top + 0.5)))
            // Elsewhere, the polygons must have identical membership, including
            // the runtime-width bottom cutout, side edges, and corner shoulders.
            for x in stride(from: play.minX + 0.5, to: play.maxX, by: play.width / 29) {
                for y in stride(from: top + 0.5, to: play.maxY, by: play.height / 29) {
                    let point = CGPoint(x: x, y: y)
                    XCTAssertEqual(runtime.runtimeTapArea.contains(point), runtime.runtimePlayArea.contains(point))
                }
            }
        }
    }

    func testShallowCornerEdgesAreNotMovedDownWithTheExposedTopSegment() {
        let vc = canvas(upperLeft: CGSize(width: 0.3, height: 0.02),
                        upperRight: CGSize(width: 0.15, height: 0.02))
        for corner in [vc.upperLeftOcclusionArea, vc.upperRightOcclusionArea] {
            let point = CGPoint(x: corner.midX, y: corner.minY - 1)
            XCTAssertGreaterThan(point.y, vc.tapAreaTopExclusionArea.minY)
            XCTAssertTrue(vc.tapAreaShape.contains(point), "Only the exposed original top edge moves")
        }
        XCTAssertFalse(vc.tapAreaShape.contains(CGPoint(x: vc.tapAreaTopExclusionArea.midX,
                                                       y: vc.tapAreaTopExclusionArea.midY)))
    }

    func testEmptyTopCornersExposeTheWholeTopEdgeAndOverlappingCornersExposeNone() {
        let empty = canvas(upperLeft: .zero, upperRight: .zero)
        XCTAssertEqual(empty.tapAreaTopExclusionArea.minX, empty.playAreaRect.minX)
        XCTAssertEqual(empty.tapAreaTopExclusionArea.width, empty.playAreaRect.width)
        XCTAssertEqual(empty.tapAreaShape.boundingBoxOfPath.maxY, empty.playAreaRect.maxY - 54, accuracy: 1e-5)
        let covered = canvas(upperLeft: CGSize(width: 0.7, height: 0.19),
                             upperRight: CGSize(width: 0.7, height: 0.17))
        XCTAssertTrue(covered.tapAreaTopExclusionArea.isEmpty)
        XCTAssertTrue(covered.tapAreaShape.subtracting(covered.playAreaShape).isEmpty)
        XCTAssertTrue(covered.playAreaShape.subtracting(covered.tapAreaShape).isEmpty)
    }
}
