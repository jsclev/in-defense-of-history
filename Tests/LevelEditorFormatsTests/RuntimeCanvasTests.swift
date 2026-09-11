import XCTest
import SwiftUI
@testable import LevelEditorFormats

final class RuntimeCanvasTests: XCTestCase {
    private func canvas(_ physical: CGRect, safe: CGRect? = nil) -> RuntimeCanvas {
        let virtual = VirtualCanvas(size: CGSize(width: 2868, height: 2064),
            playAreaRect: CGRect(x: 410, y: 450, width: 1920, height: 1080),
            pathWidth: 140, towerSlotSize: CGSize(width: 176.6, height: 96.55),
            towerMenuTotalSize: CGSize(width: 435.9, height: 390.9),
            statsViewSizeFraction: CGSize(width: 0.30, height: 0.19),
            masterControlsSizeFraction: CGSize(width: 0.15, height: 0.17),
            heroBarSizeFraction: CGSize(width: 0.258, height: 0.17),
            miscViewSizeFraction: CGSize(width: 0.09, height: 0.17))
        return RuntimeCanvas(virtualCanvas: virtual, physicalRect: physical, safeInsetsRect: safe ?? physical)
    }

    func testAllGeometryFitsTheLiveSafeArea() {
        for size in [CGSize(width: 740, height: 360), CGSize(width: 874, height: 402),
                     CGSize(width: 1024, height: 768), CGSize(width: 1600, height: 900)] {
            let physical = CGRect(origin: .zero, size: size)
            for safe in [physical, physical.insetBy(dx: 62, dy: 20),
                         CGRect(x: 62, y: 10, width: size.width - 82, height: size.height - 30)] {
                let runtime = canvas(physical, safe: safe)
                XCTAssertTrue(safe.insetBy(dx: -1e-8, dy: -1e-8).contains(runtime.playAreaRect))
                XCTAssertEqual(runtime.playAreaRect.midX, safe.midX, accuracy: 1e-8)
                XCTAssertEqual(runtime.playAreaRect.midY, safe.midY, accuracy: 1e-8)
                let sprites = MapSpriteScale(runtimeCanvas: runtime)
                XCTAssertEqual(sprites.projectionScale, runtime.scaleFactor)
                XCTAssertEqual(sprites.playableHeightOnScreen, runtime.playAreaRect.height)
                XCTAssertEqual(sprites.mapUnits(100), runtime.rangeRadius(forMapRadius: 100))
                XCTAssertEqual(sprites.points(MapSpriteSizing.hero),
                    MapSpriteSizing.hero.resolved(playableHeightOnScreen: runtime.playAreaRect.height))
                let done = DoneButtonLayout(runtimeCanvas: runtime, aspect: 2.5).frame
                XCTAssertTrue(safe.contains(done), "Done button escapes safe area: \(done), \(safe)")
                let content = MenuContentLayout(runtimeCanvas: runtime, footer: done).frame
                XCTAssertGreaterThan(content.height, 0)
                XCTAssertLessThan(content.maxY, done.minY)
                XCTAssertFalse(content.intersects(done), "Menu art covers its navigation control")
            }
        }
    }

    @MainActor
    func testMenuContentCannotResizeTheRuntimeCanvas() throws {
        let runtime = canvas(CGRect(x: 0, y: 0, width: 874, height: 402))
        for proposal in [ProposedViewSize.zero, .unspecified, ProposedViewSize(width: 300, height: 200)] {
            for child in [CGSize.zero, CGSize(width: 20, height: 30), CGSize(width: 4000, height: 2000)] {
                let renderer = ImageRenderer(content: RuntimeCanvasView(runtimeCanvas: runtime) {
                    Color.red.frame(width: child.width, height: child.height)
                })
                renderer.proposedSize = proposal
                let image = try XCTUnwrap(renderer.cgImage)
                XCTAssertEqual(image.width, 874)
                XCTAssertEqual(image.height, 402)
            }
        }
    }
}
