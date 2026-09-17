import Foundation
import CoreGraphics

public enum TowerRangeOverlay {
    public static func size(range: CGFloat, runtimeCanvas: RuntimeCanvas) -> CGSize {
        let size = TowerAttackRange(Double(range)).size
        return CGSize(width: size.width * runtimeCanvas.scaleFactor,
                      height: size.height * runtimeCanvas.scaleFactor)
    }

    public static func rect(center: CGPoint, range: CGFloat,
                            runtimeCanvas: RuntimeCanvas) -> CGRect {
        let s = size(range: range, runtimeCanvas: runtimeCanvas)
        return CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2,
                      width: s.width, height: s.height)
    }
}
