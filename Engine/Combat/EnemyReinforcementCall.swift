import Foundation

/// A signal to a finite reserve. Troops arrive through the caller's entrance;
/// neither fallen soldiers nor already removed enemies are resurrected.
public struct EnemyReinforcementCallRules: Codable, Equatable, Sendable {
    public let enemyTypeKey: String
    public let initialDelay: Double
    public let interval: Double
    public let windup: Double
    public let count: Int
    public let maxCalls: Int
    public let spawnInterval: Double

    var invalidField: String? {
        guard !enemyTypeKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "enemyTypeKey" }
        for (field, value) in [("initialDelay", initialDelay), ("interval", interval),
                               ("windup", windup), ("spawnInterval", spawnInterval)] {
            guard value.isFinite, value > 0,
                  value <= Double(Int32.max) / Double(SimClock.ticksPerSecond) else { return field }
        }
        guard count > 0, count <= Int(Int32.max),
              Double(count) * spawnInterval <= Double(Int32.max) / Double(SimClock.ticksPerSecond) else { return "count" }
        guard maxCalls > 0, maxCalls <= Int(Int32.max) else { return "maxCalls" }
        return nil
    }

    static func validateReferences(in enemies: [EnemyType]) throws {
        for enemy in enemies {
            guard let call = enemy.reinforcementCallRules else { continue }
            let prefix = "enemy_type[\(enemy.key)].traits.reinforcementCall"
            if let field = call.invalidField {
                throw DbError.Db(message: "\(prefix).\(field): invalid authored reserve call")
            }
            let matches = enemies.filter { $0.key == call.enemyTypeKey }
            guard matches.count == 1, let reserve = matches.first else {
                throw DbError.Db(message: "\(prefix).enemyTypeKey: missing or ambiguous '\(call.enemyTypeKey)'")
            }
            guard reserve.reinforcementCallRules == nil else {
                throw DbError.Db(message: "\(prefix).enemyTypeKey: reserve troops must not call further reserves")
            }
        }
    }
}

public struct EnemyReinforcementCall: Codable, Equatable, Sendable {
    public let rules: EnemyReinforcementCallRules
    public private(set) var callsMade = 0
    public private(set) var nextCallTick: Int64
    public private(set) var signalStartTick: Int64?
    public private(set) var signalProgress: Double = 0

    public init(rules: EnemyReinforcementCallRules, spawnTick: Int64) {
        self.rules = rules
        nextCallTick = spawnTick + Int64(BattleGeometry.fireTicks(rules.initialDelay))
    }

    /// Returns true exactly once for each completed signal. Close combat
    /// interrupts a signal and gives defenders a full interval before retry.
    mutating func advance(tick: Int64, blocked: Bool) -> Bool {
        guard callsMade < rules.maxCalls else { return false }
        if blocked {
            signalStartTick = nil
            signalProgress = 0
            nextCallTick = tick + Int64(BattleGeometry.fireTicks(rules.interval))
            return false
        }
        guard tick >= nextCallTick else { return false }
        if signalStartTick == nil { signalStartTick = tick }
        let duration = Int64(BattleGeometry.fireTicks(rules.windup))
        signalProgress = min(1, Double(tick - signalStartTick!) / Double(duration))
        guard signalProgress >= 1 else { return false }
        callsMade += 1
        signalStartTick = nil
        signalProgress = 0
        nextCallTick = tick + Int64(BattleGeometry.fireTicks(rules.interval))
        return true
    }
}

extension EnemyType {
    public var reinforcementCallRules: EnemyReinforcementCallRules? {
        traits.compactMap { if case let .reinforcementCall(rules) = $0 { return rules }; return nil }.first
    }
}

extension BattleEngine {
    func advanceEnemyReinforcementCalls() {
        var dispatched: [ScheduledSpawn] = []
        for index in walkers.indices {
            guard var call = walkers[index].reinforcementCall else { continue }
            let caller = walkers[index]
            let completed = call.advance(tick: timer.tick, blocked: blockedWalkerIDs.contains(caller.id))
            walkers[index].reinforcementCall = call
            guard completed else { continue }
            guard let type = enemyTypesByID.values.first(where: { $0.key == call.rules.enemyTypeKey }),
                  let origin = spawnOrigins[caller.id] else {
                fatalError("enemy_type[\(caller.assetName)].traits.reinforcementCall.enemyTypeKey: missing validated reserve")
            }
            for member in 0..<call.rules.count {
                dispatched.append(ScheduledSpawn(wave: origin.1,
                    tick: timer.tick + 1 + Int64((Double(member) * call.rules.spawnInterval / SimClock.dt).rounded()),
                    enemyTypeID: type.id, pathIndex: caller.pathIndex))
            }
            recordCombat("enemyReserveDispatched", ["enemy": String(caller.id), "type": type.key,
                "count": String(call.rules.count), "call": String(call.callsMade)])
        }
        if !dispatched.isEmpty {
            pendingSpawns.append(contentsOf: dispatched)
            pendingSpawns.sort { $0.tick < $1.tick }
        }
    }
}
