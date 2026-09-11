import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class MasterControlsLayoutTests: XCTestCase {
    private func canvas(fraction: CGSize = CGSize(width: 0.15, height: 0.17)) -> VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
                      playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
                      pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
                      towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
                      statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
                      masterControlsSizeFraction: fraction,
                      heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
                      miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    func testPhoneUsesRightGutterAndReachesOcclusionBottom() {
        let runtime = RuntimeCanvas(virtualCanvas: canvas(),
                                    physicalRect: CGRect(x: 0, y: 0, width: 874, height: 402),
                                    safeInsetsRect: CGRect(x: 62, y: 0, width: 750, height: 382))
        let layout = MasterControlsLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize, 50.806, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.maxY, 58.446, accuracy: 1e-8)
        XCTAssertGreaterThan(layout.frame.width, runtime.masterControlsSize.width)
        XCTAssertEqual(layout.frame.maxX, runtime.hudRect.maxX, accuracy: 1e-8)
    }

    func testNarrowLayoutFitsWidthIncludingGapAndHudMargin() {
        let rect = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(), physicalRect: rect, safeInsetsRect: rect)
        let layout = MasterControlsLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize, 37.41798941799, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.minX, runtime.playAreaRect.maxX - runtime.masterControlsSize.width, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.width, layout.buttonSize * 2 + layout.buttonSpacing, accuracy: 1e-8)
    }

    func testSpaceAboveMapCanIncreaseHeightBeyondOcclusion() {
        let runtime = RuntimeCanvas(virtualCanvas: canvas(fraction: CGSize(width: 0.5, height: 0.04)),
                                    physicalRect: CGRect(x: 0, y: 0, width: 1024, height: 768),
                                    safeInsetsRect: CGRect(x: 0, y: 24, width: 1024, height: 724))
        let layout = MasterControlsLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize, 83.216, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.maxY, 118.736, accuracy: 1e-8)
    }

    func testRowStaysInsideHudAndOnlyOverlapsOccludedMap() {
        let fixtures: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340),
             CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)),
            (CGRect(x: 0, y: 0, width: 874, height: 402),
             CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 0, y: 0, width: 1024, height: 768),
             CGRect(x: 0, y: 24, width: 1024, height: 724)),
            (CGRect(x: 0, y: 0, width: 1600, height: 900),
             CGRect(x: 0, y: 0, width: 1600, height: 900))
        ]
        for (physical, safe) in fixtures {
            let vc = canvas()
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let layout = MasterControlsLayout(runtimeCanvas: runtime)
            let occlusion = CGRect(x: runtime.playAreaRect.maxX - vc.upperRightOcclusionArea.width * runtime.scaleFactor,
                                   y: runtime.playAreaRect.minY,
                                   width: vc.upperRightOcclusionArea.width * runtime.scaleFactor,
                                   height: vc.upperRightOcclusionArea.height * runtime.scaleFactor)
            XCTAssertTrue(runtime.hudRect.insetBy(dx: -1e-8, dy: -1e-8).contains(layout.frame))
            XCTAssertTrue(occlusion.insetBy(dx: -1e-8, dy: -1e-8).contains(layout.frame.intersection(runtime.playAreaRect)))
            XCTAssertEqual(layout.frame.minY, runtime.hudRect.minY, accuracy: 1e-8)
            XCTAssertEqual(layout.frame.maxX, runtime.hudRect.maxX, accuracy: 1e-8)
            XCTAssertEqual(layout.buttonSpacing, layout.buttonSize * 0.1, accuracy: 1e-8)
            for index in 0..<2 {
                let center = CGPoint(x: layout.frame.minX + layout.buttonSize / 2
                                        + CGFloat(index) * (layout.buttonSize + layout.buttonSpacing),
                                     y: layout.frame.midY)
                XCTAssertFalse(runtime.runtimePlayArea.contains(center))
            }
        }
    }

    func testNoAvailableSpaceProducesZeroSizedRow() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 450)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(fraction: .zero), physicalRect: rect, safeInsetsRect: rect)
        let layout = MasterControlsLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize, 0)
        XCTAssertEqual(layout.buttonSpacing, 0)
        XCTAssertEqual(layout.frame.size, .zero)
    }
}
