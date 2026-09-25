import Foundation
import CoreGraphics

/// Authored lane-control tuning; engineers do no direct HP or morale damage.
public struct EngineerObstacleStats: Codable, Sendable, Equatable {
    /// Cross-path width divided by along-path length, authored in SQLite.
    public var widthFraction: Double
    /// Half the length along the road.
    public var radius: Double
    public var slowFraction: Double

    public init(radius: Double, slowFraction: Double, widthFraction: Double) {
        self.radius = radius
        self.widthFraction = widthFraction
        self.slowFraction = slowFraction
    }
}

public struct EngineerObstacleField: Sendable, Equatable, Codable {
    public var position: CGPoint
    public var stats: EngineerObstacleStats
    /// World-space road direction; the map renderer reverses its y axis.
    public var heading: Double

    public init(position: CGPoint, stats: EngineerObstacleStats, heading: Double) {
        self.position = position
        self.stats = stats
        self.heading = heading
    }

    public init(position: CGPoint, stats: EngineerObstacleStats, paths: [Path]) {
        let target = Point(position.x, position.y)
        let candidates = paths.filter { $0.totalLength > 0 }.map { path in
            let distance = path.nearestDistance(to: target)
            return (path: path, distance: distance,
                    gap: path.point(atDistance: distance).distance(to: target))
        }
        guard let nearest = candidates.min(by: { $0.gap < $1.gap }) else {
            preconditionFailure("Engineer abatis at \(position) has no usable enemy path")
        }
        // Span nearby segments so small authored bends do not turn the bed abruptly.
        let before = nearest.path.point(atDistance: nearest.distance - stats.radius / 2)
        let after = nearest.path.point(atDistance: nearest.distance + stats.radius / 2)
        self.init(position: position, stats: stats,
                  heading: atan2(after.y - before.y, after.x - before.x))
    }

    public var size: CGSize {
        CGSize(width: stats.radius * 2, height: stats.radius * 2 * stats.widthFraction)
    }

    /// Maps the authored road polygon into the unrotated image's local box.
    /// Clip there, then rotate/place the image with the normal map projection.
    public func worldToArtwork(scale: CGFloat) -> CGAffineTransform {
        precondition(scale.isFinite && scale > 0, "Invalid abatis artwork scale")
        let c = cos(heading), s = sin(heading)
        return CGAffineTransform(a: c * scale, b: s * scale,
            c: s * scale, d: -c * scale,
            tx: size.width * scale / 2 - (c * position.x + s * position.y) * scale,
            ty: size.height * scale / 2 - (s * position.x - c * position.y) * scale)
    }

    public func contains(_ point: CGPoint) -> Bool {
        let dx = point.x - position.x, dy = point.y - position.y
        let along = dx * cos(heading) + dy * sin(heading)
        let across = -dx * sin(heading) + dy * cos(heading)
        return abs(along) <= stats.radius && abs(across) <= stats.radius * stats.widthFraction
    }

    /// The road-aligned rectangle is shared with the displayed brush bed.
    /// Strongest wins: overlapping engineers cannot immobilize a whole lane.
    public static func movementMultiplier(at point: CGPoint, retreating: Bool,
                                          fields: [EngineerObstacleField]) -> Double {
        guard !retreating else { return 1 }
        let strongest = fields.reduce(0.0) { slow, field in
            guard field.contains(point)
            else { return slow }
            return max(slow, field.stats.slowFraction)
        }
        return 1 - strongest
    }
}
