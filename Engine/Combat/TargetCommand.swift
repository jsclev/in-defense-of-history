import Foundation
import CoreGraphics

public protocol TargetCommand {
    associatedtype Solution
    func execute() -> Solution?
}

public struct TargetCandidate: Sendable, Equatable {
    public let id: Int
    public let position: Point
    public let pathIndex: Int
    public let pathDistance: Double
    public let hp: Double
    public let morale: Double
    public let isBroken: Bool

    public init(id: Int,
                position: Point,
                pathIndex: Int,
                pathDistance: Double,
                hp: Double,
                morale: Double,
                isBroken: Bool) {
        self.id = id
        self.position = position
        self.pathIndex = pathIndex
        self.pathDistance = pathDistance
        self.hp = hp
        self.morale = morale
        self.isBroken = isBroken
    }
}

public struct TowerTargetingContext: Sendable, Equatable {
    public let slotIndex: Int
    public let position: Point
    public let range: Double
    public let verticalFraction: Double
    public let targeting: Targeting
    public var attackRange: TowerAttackRange { TowerAttackRange(range, verticalFraction: verticalFraction) }

    public init(slotIndex: Int, position: Point, range: Double, verticalFraction: Double, targeting: Targeting) {
        self.slotIndex = slotIndex
        self.position = position
        self.range = range
        self.verticalFraction = verticalFraction
        self.targeting = targeting
    }
}

public struct RangedTargetCommand: TargetCommand {
    public let tower: TowerTargetingContext
    public let enemies: [TargetCandidate]
    public let paths: [Path]

    public init(tower: TowerTargetingContext, enemies: [TargetCandidate], paths: [Path]) {
        self.tower = tower
        self.enemies = enemies
        self.paths = paths
    }

    public func execute() -> TargetCandidate? {
        guard tower.range > 0 else { return nil }
        var best: TargetCandidate?
        var bestKey = -Double.infinity
        for enemy in enemies {
            guard isInRange(enemy) else {
                continue
            }
            let key = priority(of: enemy)
            if key > bestKey {
                bestKey = key
                best = enemy
            }
        }
        return best
    }

    public func isInRange(_ enemy: TargetCandidate) -> Bool {
        tower.attackRange.contains(CGPoint(x: enemy.position.x, y: enemy.position.y),
                                   from: CGPoint(x: tower.position.x, y: tower.position.y))
    }

    public func distanceToGoal(of enemy: TargetCandidate) -> Double {
        guard paths.indices.contains(enemy.pathIndex) else { return -enemy.pathDistance }
        return paths[enemy.pathIndex].totalLength - enemy.pathDistance
    }

    public func priority(of enemy: TargetCandidate) -> Double {
        switch tower.targeting {
        case .first: -distanceToGoal(of: enemy)
        case .last: distanceToGoal(of: enemy)
        case .strongest: enemy.hp
        case .shakiest: enemy.isBroken ? -1_000_000 : -enemy.morale
        }
    }
}
