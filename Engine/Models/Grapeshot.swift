import Foundation
import CoreGraphics

/// A short-lived, straight shot. A volley can hit several enemies, but each
/// enemy takes at most one pellet's damage from that volley.
public struct GrapeshotFlight: Sendable {
    public let volleyID: Int
    public var remainingDistance: CGFloat

    public init(volleyID: Int, range: CGFloat) {
        self.volleyID = volleyID
        remainingDistance = range
    }

    /// Swept collision prevents fast pellets from tunnelling between ticks.
    /// The returned fraction orders hits along the flight segment.
    public static func hitFraction(from start: CGPoint, to end: CGPoint,
                                   target: CGPoint, radius: CGFloat) -> CGFloat? {
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        let fraction: CGFloat = lengthSquared > 0
            ? max(0, min(1, ((target.x - start.x) * dx + (target.y - start.y) * dy) / lengthSquared))
            : 0
        let x = start.x + fraction * dx, y = start.y + fraction * dy
        return hypot(target.x - x, target.y - y) <= radius ? fraction : nil
    }
}
