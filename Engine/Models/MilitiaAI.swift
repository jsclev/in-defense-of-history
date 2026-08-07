// MilitiaAI.swift
// The behavior of melee garrison units, kept separate from the simulation's
// bookkeeping: this file decides what a soldier WANTS to do each tick; the
// engine executes those decisions (movement, damage, pairing) so combat
// resolution stays in one place.
//
// The unit lifecycle: dead -> (respawn at tower) -> returning to rally ->
// holding (heal, watch for enemies) -> engaging (advance on a free enemy) ->
// fighting (blocked enemy, trade blows) -> holding or dead.
import Foundation

public struct MilitiaUnit: Sendable {
    public enum State: Sendable, Equatable {
        case dead
        case returning     // walking to the rally point
        case holding       // at the rally point: heal, scan
        case engaging      // advancing on a chosen enemy
        case fighting      // in reach, enemy blocked
    }

    public var position: Point
    public var hp: Double
    public var state: State = .returning
    /// spawnID of the enemy this unit is engaging/fighting; -1 == none.
    public var targetSpawnID: Int = -1
    public var respawnTicksLeft: Int = 0
    public var swingTicksLeft: Int = 0

    public init(position: Point, hp: Double) {
        self.position = position
        self.hp = hp
    }
}

public enum MilitiaTunables {
    /// Soldier walk speed, design units/sec.
    public static let moveSpeed: Double = 70
    /// How far from the rally point a soldier will pick a fight.
    public static let engageScanRadius: Double = 80
    /// Melee reach: closer than this and the fight is on.
    public static let meleeReach: Double = 26
    /// A fighting soldier lets go if the fight drifts this far from rally.
    public static let leashRadius: Double = 130
    /// Blocked enemies swing back this often (seconds).
    public static let enemySwingInterval: Double = 1.2
    /// Rally formation ring radius (units stand apart, not stacked).
    public static let rallySpread: Double = 16
}

/// What a unit wants done this tick. The engine applies these.
public enum MilitiaDecision: Sendable, Equatable {
    case idle
    case countdownRespawn
    case respawn                       // timer expired: spawn at tower
    case move(toward: Point)
    case heal
    case engage(targetSpawnID: Int)    // claim this enemy and advance
    case strike(targetSpawnID: Int)    // swing: engine rolls damage
    case disengage                     // target gone/leashed: return to rally
}

/// The engine's view of the battlefield, as the AI needs it.
public struct MilitiaContext {
    /// Free enemies: not blocked by any unit, not broken, not block-immune
    /// (rideDown riders shove past infantry). (spawnID, position).
    public var freeEnemies: [(spawnID: Int, position: Point)]
    /// Position of this unit's current target, nil if gone/removed.
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
    /// One decision per unit per tick. Pure: no engine state is touched here.
    public static func decide(_ unit: MilitiaUnit, context: MilitiaContext) -> MilitiaDecision {
        switch unit.state {
        case .dead:
            return unit.respawnTicksLeft > 0 ? .countdownRespawn : .respawn

        case .returning:
            if unit.position.distance(to: context.rallyPoint) <= 2 {
                return .idle   // arrival; engine flips state to holding
            }
            return .move(toward: context.rallyPoint)

        case .holding:
            // Pick the nearest free enemy inside the scan radius of the POST
            // (soldiers defend their ground; they don't chase across the map).
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
                return .strike(targetSpawnID: unit.targetSpawnID)  // first blow starts the fight
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

    /// Rally formation slot for the k-th of n units around the flag.
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
