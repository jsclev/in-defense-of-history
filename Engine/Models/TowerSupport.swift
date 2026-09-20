import Foundation
import CoreGraphics

/// Every value, including disabled capabilities, is authored on the tower row.
public struct TowerSupportStats: Codable, Sendable, Equatable {
    public var incomePerWave: Int
    public var attackSpeedMultiplier: Double
    public var healPerSecond: Double

    public init(incomePerWave: Int, attackSpeedMultiplier: Double, healPerSecond: Double) {
        self.incomePerWave = incomePerWave
        self.attackSpeedMultiplier = attackSpeedMultiplier
        self.healPerSecond = healPerSecond
    }

    public var hasAura: Bool { attackSpeedMultiplier > 1 || healPerSecond > 0 }
}

/// Shared spatial rules for the live game and CPU simulation. The strongest
/// nearby aura wins; income from separate supply towers is additive.
public struct TowerSupportSource: Sendable {
    public let position: CGPoint
    public let tuning: TowerLevel

    public init(position: CGPoint, tuning: TowerLevel) {
        self.position = position
        self.tuning = tuning
    }

    public static func income(_ sources: [Self]) -> Int {
        sources.reduce(0) { $0 + $1.tuning.support.incomePerWave }
    }

    public static func attackSpeed(at point: CGPoint, for mode: TowerAttackMode,
                                   sources: [Self]) -> Double {
        guard mode.firesProjectiles else { return 1 }
        return sources.reduce(1) { result, source in
            guard source.tuning.attackRange.contains(point, from: source.position) else { return result }
            return max(result, source.tuning.support.attackSpeedMultiplier)
        }
    }

    public static func healing(at point: CGPoint, sources: [Self]) -> Double {
        sources.reduce(0) { result, source in
            guard source.tuning.attackRange.contains(point, from: source.position) else { return result }
            return max(result, source.tuning.support.healPerSecond)
        }
    }

    public static func heal(_ unit: inout MilitiaUnit, maximumHP: Double,
                            seconds: Double, sources: [Self]) {
        guard unit.state != .dead, unit.hp > 0, unit.hp < maximumHP else { return }
        let rate = healing(at: CGPoint(x: unit.position.x, y: unit.position.y), sources: sources)
        unit.hp = min(maximumHP, unit.hp + rate * max(0, seconds))
    }
}
