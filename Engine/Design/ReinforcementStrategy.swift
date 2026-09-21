import Foundation

/// Player choices only: which visible enemy to reinforce against, and how long
/// to hold an available charge. Readiness and placement belong to BattleEngine.
public struct ReinforcementStrategy: Codable, Equatable, Sendable {
    public enum Priority: Codable, Equatable, Sendable {
        case nearestExit
        case nearPoint(Point)
    }

    public var priority: Priority
    public var holdSeconds: Double

    public init(priority: Priority, holdSeconds: Double) {
        self.priority = priority
        self.holdSeconds = holdSeconds
    }

    /// An explicit automated-player policy, not a gameplay default.
    public static let immediate = Self(priority: .nearestExit, holdSeconds: 0)

    public func validate() throws {
        guard holdSeconds.isFinite, holdSeconds >= 0 else {
            throw DbError.Db(message: "reinforcement strategy: invalid holdSeconds")
        }
        if case let .nearPoint(point) = priority {
            guard point.x.isFinite, point.y.isFinite else {
                throw DbError.Db(message: "reinforcement strategy: invalid priority point")
            }
        }
    }

    public static func random(paths: [Path], rng: inout SeededRNG) -> Self {
        precondition(!paths.isEmpty)
        let path = paths[Int.random(in: paths.indices, using: &rng)]
        let point = path.point(atDistance: path.totalLength * Double.random(in: 0...1, using: &rng))
        // Search choices for a player's deliberate delay, never a cooldown.
        let holds = [0.0, 1, 3, 6, 10]
        return Self(priority: Bool.random(using: &rng) ? .nearestExit : .nearPoint(point),
                    holdSeconds: holds[Int.random(in: holds.indices, using: &rng)])
    }
}

public struct ReinforcementDeployment: Codable, Equatable, Sendable {
    public let seconds: Double
    public let wave: Int
    public let point: Point
}

/// Input driver: no charge counter, recovery schedule, unit stats or combat.
public struct ReinforcementCommander: Sendable {
    public let strategy: ReinforcementStrategy
    private var readySince: Double?

    public init(_ strategy: ReinforcementStrategy) { self.strategy = strategy }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        try strategy.validate()
        guard sim.canCallReinforcements else { readySince = nil; return }
        if readySince == nil { readySince = sim.time }
        guard sim.time - readySince! >= strategy.holdSeconds else { return }
        let enemies = sim.enemies
        guard !enemies.isEmpty else { return }
        let referencePoints: [Point]
        switch strategy.priority {
        case .nearestExit: referencePoints = sim.content.level.paths.map { $0.points.last! }
        case let .nearPoint(point): referencePoints = [point]
        }
        // Spatial preference selects a player input; it predicts no combat.
        func distance(_ enemy: BattleEnemySnapshot) -> Double {
            referencePoints.map { enemy.position.distance(to: $0) }.min()!
        }
        let target = enemies.min {
            let a = distance($0), b = distance($1)
            return a == b ? $0.id < $1.id : a < b
        }!
        guard sim.perform(.reinforcements(point: target.position)) == .ok else {
            throw DbError.Db(message: "Engine rejected reinforcement placement at visible enemy \(target.id)")
        }
        readySince = nil
    }
}
