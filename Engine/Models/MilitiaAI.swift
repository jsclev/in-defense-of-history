import Foundation

public struct MilitiaUnit: Sendable {
    public enum State: Sendable, Equatable {
        case dead
        case returning
        case holding
        case engaging
        case fighting
    }

    public var position: Point
    public var hp: Double
    public var state: State = .returning
    public var targetSpawnID: Int = -1
    public var respawnTicksLeft: Int = 0
    public var swingTicksLeft: Int = 0
    /// Keep the same side of an opponent throughout a fight.
    public var combatSide: Double = 1

    public init(position: Point, hp: Double) {
        self.position = position
        self.hp = hp
    }
}

public enum MilitiaDecision: Sendable, Equatable {
    case idle
    case countdownRespawn
    case respawn
    case move(toward: Point)
    case heal
    case engage(targetSpawnID: Int)
    case strike(targetSpawnID: Int)
    case disengage
}

public struct MilitiaContext {
    public let rules: CombatRules
    public var freeEnemies: [(spawnID: Int, position: Point)]
    public var targetPosition: Point?
    public var rallyPoint: Point
    public var towerPosition: Point
    public var leashRadius: Double
    public var engageScanRadius: Double
    public var combatPosition: Point? = nil

    public init(rules: CombatRules, freeEnemies: [(spawnID: Int, position: Point)],
                targetPosition: Point?, rallyPoint: Point, towerPosition: Point,
                leashRadius: Double, engageScanRadius: Double) {
        self.rules = rules
        self.freeEnemies = freeEnemies
        self.targetPosition = targetPosition
        self.rallyPoint = rallyPoint
        self.towerPosition = towerPosition
        self.leashRadius = leashRadius
        self.engageScanRadius = engageScanRadius
    }
}

public enum MilitiaAI {
    public static func combatPosition(for unit: MilitiaUnit, target: Point, rules: CombatRules) -> Point {
        Point(target.x + unit.combatSide * rules.meleeCombatSpacing, target.y)
    }

    public static func decide(_ unit: MilitiaUnit, context: MilitiaContext) -> MilitiaDecision {
        switch unit.state {
        case .dead:
            return unit.respawnTicksLeft > 0 ? .countdownRespawn : .respawn

        case .returning:
            if unit.position.distance(to: context.rallyPoint) <= context.rules.arrivalRadius {
                return .idle
            }
            return .move(toward: context.rallyPoint)

        case .holding:
            if let target = nearestFreeEnemy(in: context) {
                return .engage(targetSpawnID: target)
            }
            if unit.position.distance(to: context.rallyPoint) > context.rules.arrivalRadius {
                return .move(toward: context.rallyPoint)
            }
            return .heal

        case .engaging:
            guard let targetPos = context.targetPosition else { return .disengage }
            if targetPos.distance(to: context.rallyPoint) > context.leashRadius {
                return .disengage
            }
            if unit.position.distance(to: targetPos) <= context.rules.meleeReach {
                return .strike(targetSpawnID: unit.targetSpawnID)
            }
            return .move(toward: targetPos)

        case .fighting:
            guard let targetPos = context.targetPosition else { return .disengage }
            if targetPos.distance(to: context.rallyPoint) > context.leashRadius {
                return .disengage
            }
            let position = context.combatPosition ?? combatPosition(for: unit, target: targetPos, rules: context.rules)
            if unit.position.distance(to: position) > context.rules.arrivalRadius { return .move(toward: position) }
            if unit.swingTicksLeft > 0 { return .idle }
            return .strike(targetSpawnID: unit.targetSpawnID)
        }
    }

    private static func nearestFreeEnemy(in context: MilitiaContext) -> Int? {
        var best: Int? = nil
        var bestDist = context.engageScanRadius
        for enemy in context.freeEnemies {
            let d = enemy.position.distance(to: context.rallyPoint)
            if d <= bestDist {
                bestDist = d
                best = enemy.spawnID
            }
        }
        return best
    }
}
