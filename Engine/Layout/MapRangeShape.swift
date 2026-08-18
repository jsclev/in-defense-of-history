import Foundation
import CoreGraphics

public enum MapRangeShape {
    public static let isometricTiltDegrees: CGFloat = 30

    /// A ground-plane circle seen at the map's tilt: full width, height
    /// foreshortened by sin(tilt).
    public static var verticalFraction: CGFloat {
        sin(isometricTiltDegrees * .pi / 180)
    }

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
