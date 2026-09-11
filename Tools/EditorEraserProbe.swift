// Host-only geometry proof. Compile against the Swift package's debug objects.
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
@testable import LevelEditorFormats

let canvas = VirtualCanvas(size: CGSize(width: 1000, height: 800),
    playAreaRect: CGRect(x: 0, y: 0, width: 1000, height: 800),
    pathWidth: 140, towerSlotSize: CGSize(width: 10, height: 10),
    towerMenuTotalSize: CGSize(width: 50, height: 50),
    statsViewSizeFraction: .zero, masterControlsSizeFraction: .zero,
    heroBarSizeFraction: .zero, miscViewSizeFraction: .zero)
var draft = MapDraft.starter
draft.roads = [.init(name: "Main", points: [Point(100, 200), Point(900, 200)])]
let stroke = MapDraft.PaintStroke(points: [Point(350, 260), Point(550, 260), Point(650, 170)],
                                 width: 60, erases: true)
func area(_ draft: MapDraft, preview: MapDraft.PaintStroke? = nil) -> CGPath {
    BrushGeometry.roadArea(roads: draft.roads, paint: draft.roadPaint,
                          roadHalfWidth: 70, base: draft.flattenedPath, preview: preview)
}
let before = area(draft)
let preview = area(draft, preview: stroke)
draft.applyErase(stroke, mapGeometry: MapGeometry(virtualCanvas: canvas))
let after = area(draft)
let width = 1020, height = 370
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(gray: 0.97, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
func label(_ text: String, x: Double, y: Double, size: CGFloat = 16) {
    let value = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.12, alpha: 1)
    ])
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(value), context)
}
label("Eraser: visible edge, continuous drag and tight turn", x: 22, y: 334, size: 22)
for (index, item) in [("Before", before), ("During drag", preview), ("After release", after)].enumerated() {
    let x = Double(index * 340)
    label(item.0, x: x + 24, y: 288)
    context.saveGState()
    context.translateBy(x: x + 20, y: 220)
    context.scaleBy(x: 0.32, y: 0.32)
    context.translateBy(x: -30, y: -200)
    context.addPath(item.1)
    context.setFillColor(CGColor(red: 0.77, green: 0.62, blue: 0.44, alpha: 1))
    context.fillPath()
    context.addPath(item.1)
    context.setStrokeColor(CGColor(gray: 0.24, alpha: 1))
    context.setLineWidth(3)
    context.strokePath()
    context.addPath(BrushGeometry.strokeArea(points: stroke.points, width: stroke.width))
    context.setStrokeColor(CGColor(red: 0.9, green: 0.05, blue: 0.03, alpha: 0.85))
    context.setLineWidth(3)
    context.setLineDash(phase: 0, lengths: [8, 6])
    context.strokePath()
    context.restoreGState()
}
label("Red outline: 60-unit brush. Road width: 140 units.", x: 22, y: 118)
label("The edge is cut even though the brush misses the centerline.", x: 22, y: 90)
label("Preview and committed shape use the same footprint.", x: 22, y: 62)
label("Geometry proof from editor code; not a capture of the running editor.", x: 22, y: 24, size: 13)
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print(output.path)
