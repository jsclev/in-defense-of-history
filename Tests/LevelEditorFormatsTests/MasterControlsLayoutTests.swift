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

    func testButtonsFillTheirReservedCornerAcrossScreenSizes() {
        let fixtures: [(CGRect, CGRect)] = [
            (CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340),
             CGRect(x: 0, y: 0, width: 340 * 16.0 / 9, height: 340)),
            (CGRect(x: 0, y: 0, width: 874, height: 402),
             CGRect(x: 62, y: 0, width: 750, height: 382)),
            (CGRect(x: 0, y: 0, width: 1024, height: 768),
             CGRect(x: 0, y: 24, width: 1024, height: 724)),
            (CGRect(x: 30, y: 20, width: 1600, height: 900),
             CGRect(x: 30, y: 20, width: 1600, height: 900))
        ]
        for (physical, safe) in fixtures {
            let runtime = RuntimeCanvas(virtualCanvas: canvas(), physicalRect: physical, safeInsetsRect: safe)
            let layout = MasterControlsLayout(runtimeCanvas: runtime)
            let corner = runtime.hudPlayArea.upperRightOcclusionArea
            XCTAssertTrue(corner.insetBy(dx: -1e-8, dy: -1e-8).contains(layout.frame))
            XCTAssertEqual(layout.frame.width, layout.buttonSize * 2 + layout.buttonSpacing * 1, accuracy: 1e-8)
            XCTAssertTrue(abs(layout.frame.width - corner.width) < 1e-8 ||
                          abs(layout.frame.height - corner.height) < 1e-8,
                          "The row must use all available width or height without distortion")
            for index in 0..<2 {
                let center = CGPoint(x: layout.frame.minX + layout.buttonSize / 2
                                     + CGFloat(index) * (layout.buttonSize + layout.buttonSpacing),
                                     y: layout.frame.midY)
                XCTAssertFalse(runtime.runtimeHUDPlayArea.contains(center))
            }
        }
    }

    func testLayoutFollowsTheConfiguredCorner() {
        let physical = CGRect(x: 0, y: 0, width: 874, height: 402)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(), physicalRect: physical, safeInsetsRect: physical)
        for location in HudLocation.corners {
            let layout = MasterControlsLayout(runtimeCanvas: runtime, location: location)
            XCTAssertTrue(runtime.hudPlayArea.occlusion(at: location)
                .insetBy(dx: -1e-8, dy: -1e-8).contains(layout.frame))
        }
    }

    func testEmptyReservationCannotEnlargeIntoTheMapGutter() {
        let physical = CGRect(x: 0, y: 0, width: 1024, height: 768)
        let runtime = RuntimeCanvas(virtualCanvas: canvas(fraction: .zero),
                                    physicalRect: physical, safeInsetsRect: physical)
        XCTAssertEqual(MasterControlsLayout(runtimeCanvas: runtime).frame.size, .zero)
    }
}
