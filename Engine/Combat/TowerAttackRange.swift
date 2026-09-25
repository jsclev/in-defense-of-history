import CoreGraphics
import Foundation

/// The firing boundary in map coordinates. Targeting, projectile limits and
/// the range overlay all use this geometry and the same tower_range value.
/// Blast radius is a separate circle around impact and never enters this type.
public struct TowerAttackRange: Equatable, Sendable, Codable {
    public let radius: CGFloat
    public let verticalFraction: CGFloat

    public init(_ radius: Double, verticalFraction: Double) {
        precondition(radius.isFinite && radius >= 0, "Invalid combat range")
        precondition(verticalFraction.isFinite && verticalFraction > 0 && verticalFraction <= 1, "Invalid combat range geometry")
        self.radius = radius
        self.verticalFraction = verticalFraction
    }

    public var size: CGSize {
        CGSize(width: radius * 2, height: radius * 2 * verticalFraction)
    }

    private func distance(_ point: CGPoint, from origin: CGPoint) -> CGFloat {
        hypot(point.x - origin.x, (point.y - origin.y) / verticalFraction)
    }

    public func contains(_ point: CGPoint, from origin: CGPoint) -> Bool {
        radius > 0 && distance(point, from: origin) <= radius
    }

    /// Bounds an aim point (including a sprite's body offset) to this boundary.
    public func clamped(_ point: CGPoint, from origin: CGPoint) -> CGPoint {
        let distance = distance(point, from: origin)
        guard radius > 0, distance.isFinite else { return origin }
        guard distance > radius else { return point }
        let fraction = radius / distance
        return CGPoint(x: origin.x + (point.x - origin.x) * fraction,
                       y: origin.y + (point.y - origin.y) * fraction)
    }

    /// Physical travel distance from the tower to the boundary along a ray.
    /// Each grapeshot pellet uses its own direction, including spread.
    public func travelDistance(heading: CGFloat) -> CGFloat {
        guard heading.isFinite else { return 0 }
        return radius / hypot(cos(heading), sin(heading) / verticalFraction)
    }

    /// Closest point on a lane's centerline inside this exact firing boundary.
    /// Clips every segment before projecting, including long segments whose
    /// endpoints are both outside. Used for automatic and player charge placement.
    public func nearestPathPoint(to requested: CGPoint, from origin: CGPoint,
                                 paths: [Path]) -> CGPoint? {
        guard radius > 0, requested.x.isFinite, requested.y.isFinite else { return nil }
        var best: CGPoint?
        var bestDistance = CGFloat.infinity
        for path in paths {
            for (start, end) in zip(path.points, path.points.dropFirst()) {
                let a = CGPoint(x: start.x, y: start.y)
                let dx = CGFloat(end.x - start.x), dy = CGFloat(end.y - start.y)
                let x = a.x - origin.x, y = (a.y - origin.y) / verticalFraction
                let scaledDY = dy / verticalFraction
                let aa = dx * dx + scaledDY * scaledDY
                let bb = 2 * (x * dx + y * scaledDY)
                let cc = x * x + y * y - radius * radius
                var low: CGFloat = 0, high: CGFloat = 1
                if aa == 0 {
                    guard cc <= 0 else { continue }
                } else {
                    let discriminant = bb * bb - 4 * aa * cc
                    guard discriminant >= 0 else { continue }
                    low = max(0, (-bb - sqrt(discriminant)) / (2 * aa))
                    high = min(1, (-bb + sqrt(discriminant)) / (2 * aa))
                    guard low <= high else { continue }
                }
                let lengthSquared = dx * dx + dy * dy
                let fraction = lengthSquared > 0
                    ? ((requested.x - a.x) * dx + (requested.y - a.y) * dy) / lengthSquared : 0
                let t = min(high, max(low, fraction))
                let point = clamped(CGPoint(x: a.x + dx * t, y: a.y + dy * t), from: origin)
                let gap = hypot(point.x - requested.x, point.y - requested.y)
                if gap < bestDistance { best = point; bestDistance = gap }
            }
        }
        return best
    }
}
