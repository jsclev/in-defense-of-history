import Foundation
import CoreGraphics

/// Continuous gun laying, independent of both the reload clock and atlas steps.
public struct ArtilleryAim: Equatable, Sendable {
    public private(set) var heading: Double
    public static let firingTolerance = Double.pi / 90 // Two degrees.

    public init(heading: Double = -.pi / 4) {
        self.heading = heading.isFinite ? Self.wrapped(heading) : -.pi / 4
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
        return abs(Self.wrapped(desired - heading)) <= Self.firingTolerance
    }

    private static func wrapped(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }
}

/// Initial gameplay balance, in degrees/second; not historical measurements.
public enum ArtilleryHandling {
    public static func isSwivel(level: Int, branch: Int) -> Bool {
        level == 4 && branch == 2
    }

    public static func turnRate(level: Int, branch: Int) -> Double {
        let degrees: Double
        switch (level, branch) {
        case (4, 2): degrees = 240
        case (4, 3): degrees = 35
        case (4, _): degrees = 45
        case (3, _): degrees = 65
        case (2, _): degrees = 85
        default: degrees = 100
        }
        return degrees * .pi / 180
    }
}
