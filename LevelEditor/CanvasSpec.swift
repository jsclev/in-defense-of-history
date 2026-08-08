import Foundation
import CoreGraphics

enum CanvasSpec {
    static let width = 2868.0
    static let height = 2064.0
    static let playable = CGRect(x: 474, y: 492, width: 1920, height: 1080)

    static let size = CGSize(width: width, height: height)

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
