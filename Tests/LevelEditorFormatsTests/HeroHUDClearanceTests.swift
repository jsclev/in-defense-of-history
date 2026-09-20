import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class HeroHUDClearanceTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
            masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
    }

    func testExtraHeightExcludesTheNewStripFromVirtualAndRuntimePlacement() {
        let vc = canvas
        XCTAssertEqual(vc.lowerLeftOcclusionArea.height, 214.812, accuracy: 1e-8)
        XCTAssertEqual(vc.lowerLeftOcclusionArea.width, 495.36, accuracy: 1e-8)
        XCTAssertEqual(vc.lowerLeftOcclusionArea.minY, 492)
        XCTAssertEqual(vc.heroBarLayoutArea.height, 165.24, accuracy: 1e-8)
        XCTAssertEqual(vc.bottomCenterOcclusionArea.height, 33.048, accuracy: 1e-8)
        let blocked = CGPoint(x: 774, y: 680)
        let clear = CGPoint(x: 774, y: 716)
        XCTAssertFalse(vc.playAreaShape.contains(blocked))
        XCTAssertTrue(vc.playAreaShape.contains(clear))
        XCTAssertFalse(vc.tapAreaShape.contains(blocked))
        XCTAssertFalse(vc.towerSlotValidCentres.contains(CGPoint(x: 774, y: 900)))
        XCTAssertTrue(vc.towerSlotValidCentres.contains(CGPoint(x: 774, y: 920)))
        for physical in [CGRect(x: 0, y: 0, width: 874, height: 402),
                         CGRect(x: 30, y: 20, width: 1133, height: 744)] {
            let runtime = RuntimeCanvas(virtualCanvas: vc, physicalRect: physical,
                                        safeInsetsRect: physical.insetBy(dx: 50, dy: 20))
            func projected(_ p: CGPoint) -> CGPoint {
                CGPoint(x: runtime.playAreaRect.minX + (p.x - vc.playAreaRect.minX) * runtime.scaleFactor,
                        y: runtime.playAreaRect.maxY - (p.y - vc.playAreaRect.minY) * runtime.scaleFactor)
            }
            XCTAssertFalse(runtime.runtimePlayArea.contains(projected(blocked)))
            XCTAssertFalse(runtime.runtimeTapArea.contains(projected(blocked)))
            XCTAssertTrue(runtime.runtimePlayArea.contains(projected(clear)))
            XCTAssertEqual(runtime.occlusionAreas[0].height, 214.812 * runtime.scaleFactor, accuracy: 1e-8)
        }
    }

    func testSavedLegacyCutoutCannotOverrideCurrentDerivedHeight() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(canvas)) as? [String: Any])
        json["lowerLeftOcclusionArea"] = [[474, 492], [495.36, 165.24]]
        let restored = try JSONDecoder().decode(VirtualCanvas.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.lowerLeftOcclusionArea.height, 214.812, accuracy: 1e-8)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        XCTAssertNil(encoded["lowerLeftOcclusionArea"])
    }

}
