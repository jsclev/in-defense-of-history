import XCTest
import SwiftUI
@testable import LevelEditorFormats

final class LevelViewportTests: XCTestCase {
    @MainActor
    func testWaveControlsCannotMoveMapWhenTheyAppearOrDisappear() throws {
        for size in [CGSize(width: 852, height: 393), CGSize(width: 1024, height: 768)] {
            // Exercise both a full-screen and a smaller safe-area proposal.
            // A parent may center a child that requests the physical screen.
            for proposed in [size, CGSize(width: size.width - 118, height: size.height - 34)] {
                let before = try markers(in: render(size: size, proposed: proposed, controls: 1))
                XCTAssertEqual(before.count, 2)
                for controls in [0, 3, 1, 0] {
                    let after = try markers(in: render(size: size, proposed: proposed, controls: controls))
                    XCTAssertEqual(after, before, "Map moved at \(size), proposed \(proposed), controls \(controls)")
                }
            }
        }
    }

    @MainActor
    func testPresentationsAndOversizedHudCannotResizeViewport() throws {
        let size = CGSize(width: 852, height: 393)
        for proposal in [ProposedViewSize.unspecified, .zero,
                         ProposedViewSize(width: 600, height: 300),
                         ProposedViewSize(width: 1200, height: 900)] {
            for controls in [0, 1, 3] {
                let renderer = ImageRenderer(content: scene(size: size, controls: controls))
                renderer.proposedSize = proposal
                let cg = try XCTUnwrap(renderer.cgImage)
                XCTAssertEqual(cg.width, Int(size.width))
                XCTAssertEqual(cg.height, Int(size.height))
            }
        }
    }

    @MainActor
    private func scene(size: CGSize, controls: Int) -> some View {
        LevelViewport(size: size) {
            ZStack(alignment: .topLeading) {
                Color.green
                Color(red: 1, green: 0, blue: 0).frame(width: 12, height: 12)
                    .position(x: 100, y: 100)
                Color(red: 1, green: 0, blue: 1).frame(width: 12, height: 12)
                    .position(x: size.width * 0.7, y: size.height * 0.7)
            }
        } interface: {
            ZStack(alignment: .topLeading) {
                if controls > 0 {
                    // Same full-screen wrapper and absolute positioning as
                    // CallWaveButtonLayer. Its removal used to resize the root.
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<controls, id: \.self) { index in
                            Color.blue.frame(width: 20, height: 20)
                                .position(x: 30 + CGFloat(index) * 25, y: 30)
                        }
                    }
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                }
                if controls > 1 {
                    Color.clear.frame(width: size.width * 3, height: size.height * 4)
                }
            }
        } presentations: {
            if controls > 1 {
                Color.clear.frame(width: size.width * 4, height: size.height * 3)
            }
        }
    }

    @MainActor
    private func render(size: CGSize, proposed: CGSize, controls: Int) throws -> CGImage {
        let renderer = ImageRenderer(content: scene(size: size, controls: controls)
            .frame(width: proposed.width, height: proposed.height))
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage)
    }

    private func markers(in image: CGImage) throws -> [CGRect] {
        // Normalize to known sRGB bytes rather than comparing device-space
        // NSColor components (which vary with the display color profile).
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var bounds: [Int: CGRect] = [:]
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard pixels[offset] > 220, pixels[offset + 1] < 80 else { continue }
                let key = pixels[offset + 2] > 220 ? 1 : 0
                let pixel = CGRect(x: x, y: y, width: 1, height: 1)
                bounds[key] = bounds[key].map { $0.union(pixel) } ?? pixel
            }
        }
        return bounds.keys.sorted().map { bounds[$0]! }
    }
}
