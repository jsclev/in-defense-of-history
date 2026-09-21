import XCTest
import SwiftUI
import CooldownPresentation

final class ReinforcementSliderTests: XCTestCase {
    /// Render the production SwiftUI shading, not a second geometry model.
    @MainActor private func darkRows(size: CGFloat, scale: CGFloat,
                                      remainingFraction: Double) throws -> [Int] {
        let renderer = ImageRenderer(content: Color.white
            .frame(width: size, height: size)
            .overlay { ReinforcementCooldownOverlay(buttonSize: CGSize(width: size, height: size), remainingFraction: remainingFraction) })
        renderer.scale = scale
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.width, Int(size * scale))
        XCTAssertEqual(image.height, Int(size * scale))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress,
                width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return (0..<image.height).filter { y in
            pixels[(y * image.width + image.width / 2) * 4] < 220
        }
    }

    @MainActor func testActualSliderRevealsExactlyTheElapsedFractionAndKeepsItsBottomFixed() throws {
        // 44 pt is the minimum button; 52 pt is representative of phone HUDs.
        for size: CGFloat in [44, 52, 80] {
            for scale: CGFloat in [1, 3] {
                let full = try darkRows(size: size, scale: scale, remainingFraction: 1)
                let bottom = try XCTUnwrap(full.last)
                for remainingFraction in [1.0, 0.75, 0.5, 0.25, 0.1] {
                    let rows = try darkRows(size: size, scale: scale, remainingFraction: remainingFraction)
                    XCTAssertFalse(rows.isEmpty, "The slider must remain visible while reinforcements are unavailable")
                    XCTAssertEqual(Double(rows.count), Double(full.count) * remainingFraction, accuracy: 2,
                                   "\(size) pt @\(scale)x, \(remainingFraction) remaining: clipped or incorrectly positioned shading")
                    XCTAssertEqual(rows.last, bottom, "The lower edge must stay anchored while the upper edge slides down")
                    if let first = rows.first, let last = rows.last {
                        XCTAssertEqual(rows.count, last - first + 1, "The shade must remain continuous")
                    }
                }
                XCTAssertTrue(try darkRows(size: size, scale: scale, remainingFraction: 0).isEmpty)
            }
        }
    }
}
