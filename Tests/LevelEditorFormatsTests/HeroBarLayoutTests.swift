import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class HeroBarLayoutTests: XCTestCase {
    private func canvas(heroFraction: CGSize = CGSize(width: 0.258, height: 0.17)) -> VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
                      playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
                      pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
                      towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
                      statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
                      masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
                      heroBarSizeFraction: heroFraction,
                      miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    func testRowStaysInsideLowerLeftOcclusionAcrossScreenAndSafeAreaSizes() {
        let screens: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340),
             CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)),
            (CGRect(x: 0, y: 0, width: 874, height: 402),
             CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 0, y: 0, width: 1024, height: 768),
             CGRect(x: 0, y: 24, width: 1024, height: 724)),
            (CGRect(x: 0, y: 0, width: 1600, height: 900),
             CGRect(x: 0, y: 0, width: 1600, height: 900))
        ]
        for (physical, safe) in screens {
            let vc = canvas()
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical, safeInsetsRect: safe)
            let layout = HeroBarLayout(runtimeCanvas: runtime)
            let occlusion = vc.lowerLeftOcclusionArea
            let reserved = CGRect(x: runtime.playAreaRect.minX,
                                  y: runtime.playAreaRect.maxY - occlusion.height * runtime.scaleFactor,
                                  width: occlusion.width * runtime.scaleFactor,
                                  height: occlusion.height * runtime.scaleFactor)
            let overlap = layout.frame.intersection(runtime.playAreaRect)
            XCTAssertTrue(reserved.insetBy(dx: -1e-8, dy: -1e-8).contains(overlap))
            XCTAssertGreaterThanOrEqual(layout.buttonSize, TouchTarget.minimum)
            XCTAssertTrue(runtime.hudRect.insetBy(dx: -1e-8, dy: -1e-8).contains(layout.frame))
            XCTAssertEqual(layout.frame.minX, runtime.hudRect.minX, accuracy: 1e-8)
            XCTAssertEqual(layout.frame.maxY, runtime.hudRect.maxY, accuracy: 1e-8)
            XCTAssertEqual(layout.frame.width, layout.buttonSize * 3 + layout.buttonSpacing * 2, accuracy: 1e-8)
            for index in 0..<3 {
                let center = CGPoint(x: layout.frame.minX + layout.buttonSize / 2
                                        + CGFloat(index) * (layout.buttonSize + layout.buttonSpacing),
                                     y: layout.frame.midY)
                XCTAssertFalse(runtime.runtimePlayArea.contains(center),
                               "Map command gestures must leave the HUD buttons tappable.")
            }
        }
    }

    func testHudMarginConsumesTheAvailableOcclusionWidth() {
        let rect = CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(), physicalRect: rect, safeInsetsRect: rect)
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize, 44.9555555556, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.maxX, runtime.playAreaRect.minX + runtime.heroBarSize.width, accuracy: 1e-8)
        XCTAssertLessThan(layout.frame.width, runtime.heroBarSize.width,
                          "Using the full occlusion width after adding HUD padding spills onto the path.")
    }

    func testShortOcclusionLimitsHeightInsteadOfClippingTheButtons() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 450)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(heroFraction: CGSize(width: 0.5, height: 0.04)),
                                    physicalRect: rect, safeInsetsRect: rect)
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        XCTAssertEqual(layout.buttonSize,
                       runtime.virtualCanvas.lowerLeftOcclusionArea.height * runtime.scaleFactor,
                       accuracy: 1e-8)
        XCTAssertEqual(layout.frame.height, 16.2, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.width, 51.84, accuracy: 1e-8)
    }

    func testPhoneUsesSpaceBesideTheMapToReachFullOcclusionHeight() {
        let vc = canvas()
        let runtime = RuntimeCanvas(virtualCanvas: vc,
                                    physicalRect: CGRect(x: 0, y: 0, width: 874, height: 402),
                                    safeInsetsRect: CGRect(x: 62, y: 0, width: 750, height: 382))
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        let occlusionHeight = vc.lowerLeftOcclusionArea.height * runtime.scaleFactor
        XCTAssertEqual(layout.buttonSize, occlusionHeight, accuracy: 1e-8)
        XCTAssertEqual(layout.buttonSize, 58.446, accuracy: 1e-8)
        XCTAssertGreaterThan(layout.frame.width, vc.lowerLeftOcclusionArea.width * runtime.scaleFactor)
        XCTAssertEqual(layout.frame.minY, runtime.playAreaRect.maxY - occlusionHeight, accuracy: 1e-8)
    }

    func testSpaceBelowTheMapCanIncreaseHeightBeyondTheOcclusion() {
        let runtime = RuntimeCanvas(virtualCanvas: canvas(heroFraction: CGSize(width: 0.5, height: 0.04)),
                                    physicalRect: CGRect(x: 0, y: 0, width: 1024, height: 768),
                                    safeInsetsRect: CGRect(x: 0, y: 24, width: 1024, height: 724))
        let layout = HeroBarLayout(runtimeCanvas: runtime)
        // 20.736pt of occlusion plus the 74pt gutter below the play area.
        XCTAssertEqual(layout.buttonSize, 94.736, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.minY, 653.264, accuracy: 1e-8)
        XCTAssertEqual(layout.frame.maxY, runtime.hudRect.maxY, accuracy: 1e-8)
        XCTAssertFalse(runtime.runtimePlayArea.contains(CGPoint(x: layout.frame.midX, y: layout.frame.minY + 1)))
    }
}
