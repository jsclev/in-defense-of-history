import Foundation
import CoreGraphics

/// Continuous gun laying, independent of both the reload clock and atlas steps.
public struct ArtilleryAim: Equatable, Sendable {
    public private(set) var heading: Double
    public let firingTolerance: Double

    public init(heading: Double, firingTolerance: Double) {
        precondition(heading.isFinite && firingTolerance.isFinite && firingTolerance > 0)
        self.heading = Self.wrapped(heading)
        self.firingTolerance = firingTolerance
    }

    public var facing: ArtilleryFacing { ArtilleryFacing(heading: heading) }

    /// Returns whether the gun can fire at this target after this tick's turn.
    /// Reloading never prevents tracking. Invalid/coincident targets hold aim.
    @discardableResult
    public mutating func track(from origin: CGPoint, to target: CGPoint,
                               radiansPerSecond: Double, deltaTime: Double) -> Bool {
        let dx = Double(target.x - origin.x), dy = Double(target.y - origin.y)
        guard dx.isFinite, dy.isFinite, hypot(dx, dy) > 0.000_001,
              radiansPerSecond.isFinite, radiansPerSecond >= 0,
              deltaTime.isFinite, deltaTime >= 0 else { return false }
        let desired = atan2(dy, dx)
        let difference = Self.wrapped(desired - heading)
        let step = min(abs(difference), radiansPerSecond * deltaTime)
        heading = Self.wrapped(heading + (difference < 0 ? -step : step))
        return abs(Self.wrapped(desired - heading)) <= firingTolerance
    }

    private static func wrapped(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }
}
