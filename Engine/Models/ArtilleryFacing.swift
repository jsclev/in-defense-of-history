import Foundation
import CoreGraphics

/// A fixed-camera turnaround: east first, then clockwise through south,
/// west and north. Map coordinates have +y up; atlas rows have +y down.
public struct ArtilleryFacing: Equatable, Sendable {
    public static let frameCount = 32
    public static let columns = 8
    public static let rows = 4
    public static let angleStep = 2 * Double.pi / Double(frameCount)
    public static let initial = ArtilleryFacing(heading: -.pi / 4)

    public let frameIndex: Int

    public init(heading: Double) {
        guard heading.isFinite else {
            frameIndex = 0
            return
        }
        let clockwise = (-heading).truncatingRemainder(dividingBy: 2 * .pi)
        let step = Int((clockwise / Self.angleStep).rounded())
        frameIndex = (step % Self.frameCount + Self.frameCount) % Self.frameCount
    }

    /// Uses the actual launch-to-aim vector, including the projectile's target
    /// body offset. Coincident points preserve the gun's previous direction.
    public static func aiming(from origin: CGPoint, at target: CGPoint,
                              previous: ArtilleryFacing) -> ArtilleryFacing {
        let dx = Double(target.x - origin.x)
        let dy = Double(target.y - origin.y)
        guard dx.isFinite, dy.isFinite, hypot(dx, dy) > 0.000_001 else {
            return previous
        }
        return ArtilleryFacing(heading: atan2(dy, dx))
    }

    public func frameRect(sheetSize: CGSize) -> CGRect {
        let width = sheetSize.width / CGFloat(Self.columns)
        let height = sheetSize.height / CGFloat(Self.rows)
        return CGRect(x: CGFloat(frameIndex % Self.columns) * width,
                      y: CGFloat(frameIndex / Self.columns) * height,
                      width: width, height: height)
    }
}
