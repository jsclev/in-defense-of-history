import XCTest
@testable import LevelEditorFormats

final class CampaignOceanLayoutTests: XCTestCase {
    private func canvas(size: CGSize, safe: CGRect? = nil,
                        virtualOrigin: CGPoint = CGPoint(x: 474, y: 492)) -> RuntimeCanvas {
        let virtual = VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(origin: virtualOrigin, size: CGSize(width: 1920, height: 1080)),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
            masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
        let physical = CGRect(origin: .zero, size: size)
        return RuntimeCanvas(virtualCanvas: virtual, physicalRect: physical,
                             safeInsetsRect: safe ?? physical)
    }

    func testAllThreeRemainInsidePlayAreaAcrossScreenShapesAndInsets() {
        for size in [CGSize(width: 340.0 * 16 / 9, height: 340),
                     CGSize(width: 874, height: 402), CGSize(width: 1024, height: 768),
                     CGSize(width: 1600, height: 900)] {
            let physical = CGRect(origin: .zero, size: size)
            for safe in [physical, physical.insetBy(dx: 62, dy: 20),
                         CGRect(x: 62, y: 10, width: size.width - 82, height: size.height - 30)] {
                let runtime = canvas(size: size, safe: safe)
                let placements = CampaignOceanLayout.placements(runtimeCanvas: runtime)
                XCTAssertEqual(Set(placements.map(\.assetName)), [
                    "main_campaign_map_ship_british", "main_campaign_map_octopus", "main_campaign_map_whale"])
                XCTAssertEqual(placements.count, 3)
                for placement in placements {
                    XCTAssertTrue(runtime.playAreaRect.contains(placement.frame), placement.assetName)
                    XCTAssertTrue(runtime.runtimePlayArea.contains(CGPoint(x: placement.frame.midX,
                                                                          y: placement.frame.midY)))
                }
                for (index, a) in placements.enumerated() {
                    for b in placements.dropFirst(index + 1) {
                        XCTAssertFalse(a.frame.intersects(b.frame))
                    }
                }
            }
        }
    }

    func testOffsetsSizesAndSpacingShareTheRuntimeScale() {
        let reference = canvas(size: CGSize(width: 1920, height: 1080))
        let authored = CampaignOceanLayout.placements(runtimeCanvas: reference)
        for size in [CGSize(width: 340.0 * 16 / 9, height: 340),
                     CGSize(width: 874, height: 402), CGSize(width: 1024, height: 768)] {
            let runtime = canvas(size: size,
                safe: CGRect(x: 59, y: 7, width: size.width - 80, height: size.height - 28))
            let actual = CampaignOceanLayout.placements(runtimeCanvas: runtime)
            for (expected, placement) in zip(authored, actual) {
                XCTAssertEqual(placement.assetName, expected.assetName)
                XCTAssertEqual((placement.frame.minX - runtime.playAreaRect.minX) / runtime.scaleFactor,
                               expected.frame.minX, accuracy: 1e-8)
                XCTAssertEqual((placement.frame.minY - runtime.playAreaRect.minY) / runtime.scaleFactor,
                               expected.frame.minY, accuracy: 1e-8)
                XCTAssertEqual(placement.frame.width / runtime.scaleFactor, expected.frame.width, accuracy: 1e-8)
                XCTAssertEqual(placement.frame.height / runtime.scaleFactor, expected.frame.height, accuracy: 1e-8)
            }
        }
    }

    func testOffsetsAreLocalToPlayAreaRatherThanFullVirtualCanvas() {
        let size = CGSize(width: 874, height: 402)
        let original = CampaignOceanLayout.placements(runtimeCanvas: canvas(size: size))
        let shifted = CampaignOceanLayout.placements(runtimeCanvas:
            canvas(size: size, virtualOrigin: CGPoint(x: 410, y: 450)))
        XCTAssertEqual(original.map(\.frame), shifted.map(\.frame))
    }
}
