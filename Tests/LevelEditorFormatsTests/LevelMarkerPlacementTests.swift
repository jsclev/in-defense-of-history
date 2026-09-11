import XCTest
import CoreGraphics
@testable import LevelEditorFormats

final class LevelMarkerPlacementTests: XCTestCase {
    private var canvas: VirtualCanvas {
        VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 474, y: 492, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
            heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
    }

    func testBothMarkersUseTheSameExactProjectionAsPathPixels() {
        for (physical, safe) in [
            (CGRect(x: 0, y: 0, width: 604.444, height: 340), CGRect(x: 0, y: 0, width: 604.444, height: 340)),
            (CGRect(x: 0, y: 0, width: 852, height: 393), CGRect(x: 59, y: 0, width: 734, height: 372)),
            (CGRect(x: 0, y: 0, width: 1366, height: 1024), CGRect(x: 0, y: 24, width: 1366, height: 980)),
            (CGRect(x: 0, y: 0, width: 393, height: 852), CGRect(x: 0, y: 59, width: 393, height: 759))
        ] {
            let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: physical, safeInsetsRect: safe)
            let projection = LevelMapProjection(playArea: canvas.playAreaRect,
                fitRect: runtime.playAreaRect, virtualCanvas: canvas)
            let size = MapSpriteScale(runtimeCanvas: runtime).points(MapSpriteSizing.exitMarker)
            for point in [CGPoint(x: 538, y: 1280), CGPoint(x: 1218, y: 1460),
                          CGPoint(x: 2366, y: 1304), CGPoint(x: 1634, y: 552),
                          CGPoint(x: 500.125, y: 800.875), CGPoint(x: 400, y: 1650)] {
                let expected = CGPoint(
                    x: runtime.playAreaRect.minX + (point.x - 474) / 1920 * runtime.playAreaRect.width,
                    y: runtime.playAreaRect.minY + (1572 - point.y) / 1080 * runtime.playAreaRect.height)
                let wave = CallWaveButtonLayout(position: Point(point.x, point.y), runtimeCanvas: runtime).frame
                let exit = ExitMarkerLayout(position: point, projection: projection, spriteSize: size).frame
                for frame in [wave, exit] {
                    XCTAssertEqual(frame.midX, expected.x, accuracy: 1e-9)
                    XCTAssertEqual(frame.midY, expected.y, accuracy: 1e-9)
                }
                let imageOrigin = CGPoint(x: projection.imageCenter.x - projection.imageFrameSize.width / 2,
                                          y: projection.imageCenter.y - projection.imageFrameSize.height / 2)
                let pathPixel = CGPoint(x: imageOrigin.x + point.x / 2868 * projection.imageFrameSize.width,
                    y: imageOrigin.y + (2064 - point.y) / 2064 * projection.imageFrameSize.height)
                XCTAssertEqual(pathPixel.x, expected.x, accuracy: 1e-9)
                XCTAssertEqual(pathPixel.y, expected.y, accuracy: 1e-9)
            }
        }
    }

    func testCroppedCrownKeepsItsApprovedSizeWithoutMovingTheCenter() {
        let rect = CGRect(x: 0, y: 0, width: 340 * 16 / 9, height: 340)
        let runtime = RuntimeCanvas(virtualCanvas: canvas, physicalRect: rect, safeInsetsRect: rect)
        let projection = LevelMapProjection(playArea: canvas.playAreaRect, fitRect: runtime.playAreaRect,
                                             virtualCanvas: canvas)
        let point = CGPoint(x: 1434, y: 1032)
        let layout = ExitMarkerLayout(position: point, projection: projection,
            spriteSize: MapSpriteScale(runtimeCanvas: runtime).points(MapSpriteSizing.exitMarker))
        XCTAssertEqual(layout.frame.width, 23.73333333333333, accuracy: 1e-9)
        XCTAssertEqual(layout.frame.height, 24.53333333333333, accuracy: 1e-9)
        XCTAssertEqual(layout.frame.midX, rect.midX, accuracy: 1e-9)
        XCTAssertEqual(layout.frame.midY, rect.midY, accuracy: 1e-9)
    }
}
