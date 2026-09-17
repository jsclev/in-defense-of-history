import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Export the generated art without independently resizing or trimming frames.
// The source has unequal row gutters; align each row's authored ignition line
// to one common 480px canvas and retain the same scale through the sequence.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Usage: build_demolition_explosion_atlas SOURCE.png OUTPUT.imageset")
}
let sourceURL = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 1448, image.height == 1086 else {
    fatalError("Expected the approved 1448×1086 source atlas")
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let rowBounds = [0, 410, 750, 1086]
let groundLines = [372, 714, 1056]
let cellSide = 480
var renditions: [[String: String]] = []
for density in 1...3 {
    let side = cellSide * density / 3
    let width = side * 4, height = side * 3
    guard let context = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Bitmap allocation failed") }
    context.interpolationQuality = .high
    let scale = CGFloat(density) / 3
    for index in 0..<12 {
        let column = index % 4, row = index / 4
        let cropHeight = rowBounds[row + 1] - rowBounds[row]
        guard let frame = image.cropping(to: CGRect(x: column * 362, y: rowBounds[row],
            width: 362, height: cropHeight)) else { fatalError("Missing frame \(index)") }
        let left = CGFloat(column * cellSide + 59) * scale
        let top = CGFloat(row * cellSide + 384 - (groundLines[row] - rowBounds[row])) * scale
        let frameHeight = CGFloat(cropHeight) * scale
        context.draw(frame, in: CGRect(x: left, y: CGFloat(height) - top - frameHeight,
            width: 362 * scale, height: frameHeight))
    }
    let suffix = density == 1 ? "" : "@\(density)x"
    let filename = "demolition_explosion\(suffix).png"
    guard let atlas = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL,
            UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot create PNG") }
    CGImageDestinationAddImage(destination, atlas, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save PNG") }
    renditions.append(["idiom": "universal", "scale": "\(density)x", "filename": filename])
}
let contents: [String: Any] = ["images": renditions, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Exported 12 aligned frames at 1x/2x/3x, ground anchor (0.5, 0.8).")
