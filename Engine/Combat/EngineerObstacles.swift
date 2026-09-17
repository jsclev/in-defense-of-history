import Foundation
import CoreGraphics

/// Authored lane-control tuning; engineers do no direct HP or morale damage.
public struct EngineerObstacleStats: Codable, Sendable, Equatable {
    public var radius: Double
    public var slowFraction: Double

    public init(radius: Double, slowFraction: Double) {
        self.radius = radius
        self.slowFraction = slowFraction
    }
}

public struct EngineerObstacleField: Sendable, Equatable {
    public var position: CGPoint
    public var stats: EngineerObstacleStats

    public init(position: CGPoint, stats: EngineerObstacleStats) {
        self.position = position
        self.stats = stats
    }

    /// Fields use the same ground-plane ellipse as their displayed footprint.
    /// Strongest wins: overlapping engineers cannot immobilize a whole lane.
    public static func movementMultiplier(at point: CGPoint, retreating: Bool,
                                          fields: [EngineerObstacleField]) -> Double {
        guard !retreating else { return 1 }
        let strongest = fields.reduce(0.0) { slow, field in
            guard TowerAttackRange(field.stats.radius).contains(point, from: field.position)
            else { return slow }
            return max(slow, field.stats.slowFraction)
        }
        return 1 - strongest
    }
}
