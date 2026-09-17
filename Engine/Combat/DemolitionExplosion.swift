import Foundation
import CoreGraphics

/// A single, game-time-driven burst. Never wraps: completed effects are removed.
public enum DemolitionExplosion {
    public static let assetName = "demolition_explosion"
    public static let columns = 4
    public static let rows = 3
    public static let frameCount = columns * rows
    public static let groundAnchorY: CGFloat = 0.8
    public static let frameEnds: [Double] = [0.05, 0.10, 0.16, 0.24, 0.34, 0.46,
                                          0.60, 0.74, 0.88, 1.02, 1.16, 1.30]
    public static var duration: Double { frameEnds.last! }

    public static func frame(at age: Double) -> Int? {
        guard age.isFinite, age >= 0 else { return nil }
        return frameEnds.firstIndex { age < $0 }
    }

    public static func opacity(at age: Double) -> Double {
        guard frame(at: age) != nil else { return 0 }
        return age < 0.24 ? 1 : pow(max(0, (duration - age) / (duration - 0.24)), 0.75)
    }

    public static func frameRect(index: Int, sheetSize: CGSize) -> CGRect? {
        guard (0..<frameCount).contains(index), sheetSize.width > 0, sheetSize.height > 0 else { return nil }
        let width = sheetSize.width / CGFloat(columns), height = sheetSize.height / CGFloat(rows)
        return CGRect(x: CGFloat(index % columns) * width, y: CGFloat(index / columns) * height,
                      width: width, height: height)
    }
}
