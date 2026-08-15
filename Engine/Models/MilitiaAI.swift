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

    public init(position: Point, hp: Double) {
        self.position = position
        self.hp = hp
    }
}

public enum MilitiaTunables {
    /// Swing damage rolls uniformly within ±this fraction of attack_rating.
    public static let attackSpread: Double = 0.25
    public static let moveSpeed: Double = 70
    public static let engageScanRadius: Double = 80
    public static let meleeReach: Double = 26
    public static let leashRadius: Double = 130
    public static let enemySwingInterval: Double = 1.2
    public static let rallySpread: Double = 16
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
    public var freeEnemies: [(spawnID: Int, position: Point)]
    public var targetPosition: Point?
    public var rallyPoint: Point
    public var towerPosition: Point

    public init(freeEnemies: [(spawnID: Int, position: Point)],
                targetPosition: Point?, rallyPoint: Point, towerPosition: Point) {
        self.freeEnemies = freeEnemies
        self.targetPosition = targetPosition
        self.rallyPoint = rallyPoint
        self.towerPosition = towerPosition
    }
}

public enum MilitiaAI {
    public static func decide(_ unit: MilitiaUnit, context: MilitiaContext) -> MilitiaDecision {
        switch unit.state {
        case .dead:
            return unit.respawnTicksLeft > 0 ? .countdownRespawn : .respawn

        case .returning:
            if unit.position.distance(to: context.rallyPoint) <= 2 {
                return .idle
            }
            return .move(toward: context.rallyPoint)

        case .holding:
            if let target = nearestFreeEnemy(in: context) {
                return .engage(targetSpawnID: target)
            }
            return .heal

        case .engaging:
            guard let targetPos = context.targetPosition else { return .disengage }
            if targetPos.distance(to: context.rallyPoint) > MilitiaTunables.leashRadius {
                return .disengage
            }
            if unit.position.distance(to: targetPos) <= MilitiaTunables.meleeReach {
                return .strike(targetSpawnID: unit.targetSpawnID)
            }
            return .move(toward: targetPos)

        case .fighting:
            guard let targetPos = context.targetPosition else { return .disengage }
            if targetPos.distance(to: context.rallyPoint) > MilitiaTunables.leashRadius {
                return .disengage
            }
            if unit.swingTicksLeft > 0 { return .idle }
            return .strike(targetSpawnID: unit.targetSpawnID)
        }
    }

    public static func formationOffset(index: Int, of count: Int) -> Point {
        guard count > 1 else { return .zero }
        let angle = 2.0 * Double.pi * Double(index) / Double(count)
        return Point(MilitiaTunables.rallySpread * cos(angle),
                     MilitiaTunables.rallySpread * sin(angle))
    }

    private static func nearestFreeEnemy(in context: MilitiaContext) -> Int? {
        var best: Int? = nil
        var bestDist = MilitiaTunables.engageScanRadius
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
