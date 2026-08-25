import Foundation
import CoreGraphics

public enum TowerRangeOverlay {
    /// A ground-plane circle foreshortened to Kingdom Rush's range-ring
    /// proportions: 7 units tall for every 10 wide.
    public static let verticalFraction: CGFloat = 0.7

    public static func size(range: CGFloat, pointsPerMapUnit: CGFloat) -> CGSize {
        let width = range * pointsPerMapUnit * 2
        return CGSize(width: width, height: width * verticalFraction)
    }

    public static func rect(center: CGPoint, range: CGFloat,
                            pointsPerMapUnit: CGFloat) -> CGRect {
        let s = size(range: range, pointsPerMapUnit: pointsPerMapUnit)
        return CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2,
                      width: s.width, height: s.height)
    }
}
