// CanvasSpec.swift
// The authoring canvas in native retina pixels, derived from every iPhone
// and iPad shipped 2021-2026 (Retina-class only; SE 3rd gen excluded):
//   max landscape width  2868 px — iPhone 16/17 Pro Max
//   max landscape height 2064 px — iPad Pro 13" (M4/M5)
//   playable rect 1920x1080 — largest 16:9 that fits the most constraining
//   device, the iPhone 13 mini (2340x1080), centered in the canvas.
// Art fills the whole canvas; every device's screen, centered on the
// canvas, is fully covered while showing the entire playable rect.
import Foundation
import CoreGraphics

enum CanvasSpec {
    static let width = 2868.0
    static let height = 2064.0
    static let playable = CGRect(x: 474, y: 492, width: 1920, height: 1080)

    static let size = CGSize(width: width, height: height)

    /// Canvas pixels per engine design unit (1920 / 1600).
    static let designScale = playable.width / LevelBlueprint.designWidth

    static func toDesign(_ p: Point) -> Point {
        Point((p.x - playable.minX) / designScale,
              (p.y - playable.minY) / designScale)
    }

    static func fromDesign(_ p: Point) -> Point {
        Point(p.x * designScale + playable.minX,
              p.y * designScale + playable.minY)
    }
}
