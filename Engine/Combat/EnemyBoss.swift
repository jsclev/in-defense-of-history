import Foundation
import CoreGraphics

/// Every value is authored in enemy_type.traits. Zero explicitly disables an
/// ability; no boss identity or combat tuning is selected by Swift.
public struct EnemyBossRules: Codable, Equatable, Sendable {
    public let renderScale: Double
    public let rallyRadius: Double
    public let rallyMoralePerSecond: Double
    public let meleeSplashRadius: Double
    public let barrageRange: Double
    public let barrageRadius: Double
    public let barrageInterval: Double
    public let barrageWindup: Double
    public let barrageDamage: Double

    var validationIssue: (field: String, reason: String)? {
        guard renderScale.isFinite, renderScale > 0 else {
            return ("renderScale", "must be finite and positive")
        }
        for (field, value) in [("rallyRadius", rallyRadius), ("rallyMoralePerSecond", rallyMoralePerSecond),
                               ("meleeSplashRadius", meleeSplashRadius), ("barrageRange", barrageRange),
                               ("barrageRadius", barrageRadius), ("barrageInterval", barrageInterval),
                               ("barrageWindup", barrageWindup), ("barrageDamage", barrageDamage)] {
            guard value.isFinite, value >= 0 else { return (field, "must be finite and nonnegative") }
        }
        guard (rallyRadius == 0) == (rallyMoralePerSecond == 0) else {
            return ("rallyRadius", "and rallyMoralePerSecond must both be zero or both be positive")
        }
        let barrage = [barrageRange, barrageRadius, barrageInterval, barrageWindup, barrageDamage]
        guard barrage.allSatisfy({ $0 == 0 }) || barrage.allSatisfy({ $0 > 0 }) else {
            return ("barrageRange", "and all other barrage fields must all be zero or all be positive")
        }
        let maximumSeconds = Double(Int32.max) / Double(SimClock.ticksPerSecond)
        for (field, value) in [("barrageInterval", barrageInterval), ("barrageWindup", barrageWindup)] {
            guard value <= maximumSeconds else { return (field, "must fit the tick clock range") }
        }
        return nil
    }
}

/// Optional Walker state keeps recordings from before bosses readable. Fixed
/// target and tick deadlines are recorded directly; playback does not attack.
struct EnemyBoss: Codable, Equatable {
    let rules: EnemyBossRules
    var meleeReadyAtTick: Int64
    var barrageReadyAtTick: Int64
    var barrageTarget: Point?
    var barrageStartedAtTick: Int64?
    var barrageImpactAtTick: Int64?

    init(rules: EnemyBossRules, spawnTick: Int64, meleeInterval: Double) {
        self.rules = rules
        meleeReadyAtTick = spawnTick + Int64(BattleGeometry.fireTicks(meleeInterval))
        barrageReadyAtTick = spawnTick + Int64(BattleGeometry.fireTicks(rules.barrageInterval))
    }

    mutating func cancelBarrage(at tick: Int64) {
        barrageTarget = nil
        barrageStartedAtTick = nil
        barrageImpactAtTick = nil
        barrageReadyAtTick = tick + Int64(BattleGeometry.fireTicks(rules.barrageInterval))
    }
}

extension EnemyType {
    var bossRules: EnemyBossRules? {
        traits.compactMap { if case let .boss(rules) = $0 { return rules }; return nil }.first
    }
}

extension BattleEngine {
    /// Same phase for live play and the simulator. Corpses never receive rally
    /// or supply bombardment targets; a commander killed this tick cannot act.
    func advanceEnemyBosses() {
        guard walkers.contains(where: { $0.boss != nil }) else { return }
        for index in walkers.indices {
            guard var boss = walkers[index].boss, walkers[index].hp > 0 else { continue }
            let enemy = walkers[index]
            let position = Point(enemy.position.x, enemy.position.y)
            if boss.rules.rallyRadius > 0 {
                for allyIndex in walkers.indices where allyIndex != index && walkers[allyIndex].hp > 0 {
                    let ally = walkers[allyIndex].position
                    if position.distance(to: Point(ally.x, ally.y)) <= boss.rules.rallyRadius {
                        walkers[allyIndex].morale.rally(amount: boss.rules.rallyMoralePerSecond * SimClock.dt)
                    }
                }
            }

            let engaged = blockedWalkerIDs.contains(enemy.id)
            if boss.rules.meleeSplashRadius > 0 {
                if !engaged {
                    // A fresh engagement receives a full, normal melee windup.
                    boss.meleeReadyAtTick = timer.tick + Int64(BattleGeometry.fireTicks(combatRules.enemySwingInterval))
                } else if timer.tick >= boss.meleeReadyAtTick {
                    damageDefenders(from: enemy.id, at: position, radius: boss.rules.meleeSplashRadius,
                        damage: random.double(in: enemy.meleeDamageRange), event: "bossMeleeHit")
                    boss.meleeReadyAtTick = timer.tick + Int64(BattleGeometry.fireTicks(combatRules.enemySwingInterval))
                }
            }

            if boss.rules.barrageRange > 0 {
                if engaged {
                    // Close engagement interrupts an aimed shot and prevents
                    // immediately firing when the defender falls back.
                    boss.cancelBarrage(at: timer.tick)
                } else if let target = boss.barrageTarget, let impactTick = boss.barrageImpactAtTick {
                    if timer.tick >= impactTick {
                        damageDefenders(from: enemy.id, at: target, radius: boss.rules.barrageRadius,
                            damage: boss.rules.barrageDamage, event: "bossBarrageHit")
                        artilleryImpacts.append(ArtilleryImpact(id: nextProjectileID,
                            position: CGPoint(x: target.x, y: target.y), radius: boss.rules.barrageRadius))
                        nextProjectileID += 1
                        boss.cancelBarrage(at: timer.tick)
                    }
                } else if timer.tick >= boss.barrageReadyAtTick,
                          let target = nearestLivingDefender(to: position, within: boss.rules.barrageRange) {
                    boss.barrageTarget = target
                    boss.barrageStartedAtTick = timer.tick
                    boss.barrageImpactAtTick = timer.tick + Int64(BattleGeometry.fireTicks(boss.rules.barrageWindup))
                    recordCombat("bossBarrageAimed", ["enemy": String(enemy.id),
                        "x": String(target.x), "y": String(target.y)])
                }
            }
            walkers[index].boss = boss
        }
    }

    private func nearestLivingDefender(to position: Point, within range: Double) -> Point? {
        var target: Point?
        var nearest = range
        // Stable traversal preserves deterministic ties and random streams.
        for slot in garrisonsBySlot.keys.sorted() {
            for unit in garrisonsBySlot[slot]!.units where unit.state != .dead && unit.hp > 0 {
                let distance = position.distance(to: unit.position)
                if distance <= nearest { nearest = distance; target = unit.position }
            }
        }
        for post in heroPosts where post.unit.state != .dead && post.unit.hp > 0 {
            let distance = position.distance(to: post.unit.position)
            if distance <= nearest { nearest = distance; target = post.unit.position }
        }
        return target
    }

    private func damageDefenders(from enemyID: Int, at point: Point, radius: Double,
                                 damage: Double, event: String) {
        for slot in garrisonsBySlot.keys.sorted() {
            guard var garrison = garrisonsBySlot[slot],
                  let resolved = garrisonMelee(slot: slot, garrison: garrison) else { continue }
            for index in garrison.units.indices {
                var unit = garrison.units[index]
                guard unit.state != .dead, unit.hp > 0, point.distance(to: unit.position) <= radius else { continue }
                let hpBefore = unit.hp
                unit.hp -= damage * (1 - resolved.stats.defenseRating)
                recordCombat(event, ["enemy": String(enemyID), "slot": String(slot), "unit": String(index),
                    "damage": String(min(hpBefore, hpBefore - unit.hp)), "hpAfter": String(unit.hp)])
                if unit.hp <= 0 {
                    garrison.enemySwingTicks[unit.targetSpawnID] = nil
                    unit.state = .dead
                    unit.targetSpawnID = -1
                    unit.respawnTicksLeft = BattleGeometry.fireTicks(resolved.stats.respawnSeconds)
                }
                garrison.units[index] = unit
            }
            garrisonsBySlot[slot] = garrison
        }
        for index in heroPosts.indices {
            var post = heroPosts[index]
            guard post.unit.state != .dead, post.unit.hp > 0,
                  point.distance(to: post.unit.position) <= radius else { continue }
            let hpBefore = post.unit.hp
            post.unit.hp -= damage * (1 - post.combat.defenseRating)
            recordCombat(event, ["enemy": String(enemyID), "heroID": post.hero.id.uuidString,
                "damage": String(min(hpBefore, hpBefore - post.unit.hp)), "hpAfter": String(post.unit.hp)])
            if post.unit.hp <= 0 {
                post.enemySwingTicks[post.unit.targetSpawnID] = nil
                post.unit.state = .dead
                post.unit.targetSpawnID = -1
                post.unit.respawnTicksLeft = BattleGeometry.fireTicks(post.combat.respawnSeconds)
                if selectedHeroIndex == index { selectedHeroIndex = nil }
            }
            heroPosts[index] = post
        }
        // Another soldier can still hold the same enemy after an area strike.
        blockedWalkerIDs.removeAll(keepingCapacity: true)
        for garrison in garrisonsBySlot.values {
            for unit in garrison.units where unit.state == .fighting && unit.hp > 0 && unit.targetSpawnID >= 0 {
                blockedWalkerIDs.insert(unit.targetSpawnID)
            }
        }
        for post in heroPosts where post.unit.state == .fighting && post.unit.hp > 0 && post.unit.targetSpawnID >= 0 {
            blockedWalkerIDs.insert(post.unit.targetSpawnID)
        }
    }
}
