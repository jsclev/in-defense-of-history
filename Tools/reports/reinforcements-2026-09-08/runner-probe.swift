
import Foundation
import Combine
import LevelEditorFormats

final class RunnerProbe {
    struct Clock { var tick: Int64 = 0 }
    var timer = Clock()
    var isReady = true
    var isDefeated = false
    var isCleared = false
    var money = 123
    private let meleeFormation = MeleeFormation()
    private static let reinforcementCount = 2
    private var nextReinforcementSlot = -1
    private var reinforcementSchedule: ReinforcementSchedule?
    private var reinforcementCooldown: ReinforcementCooldown = .ready
    private var garrisonsBySlot: [Int: MilitiaGarrison] = [:]
    private var militia: [MilitiaSoldier] = []
    private var militiaPrevPositions: [Int: CGPoint] = [:]
    private var militiaPoses: [Int: WalkPose] = [:]
    private var militiaRespawnedIDs: Set<Int> = []
    private var blockedWalkerIDs: Set<Int> = []
    private var damageTotalBySlot: [Int: Double] = [:]
    struct HeroFixture { var unit: MilitiaUnit }
    private var heroPosts: [HeroFixture] = []
    struct TowerFixture { var position: CGPoint = .zero }
    func placedTower(atSlot slot: Int) -> TowerFixture? { slot >= 0 ? TowerFixture() : nil }
    func towerLevel(for tower: TowerFixture) -> TowerLevel? { towerLevels[.melee]?[1]?[1] }
    var towerLevels: [TowerKind: [Int: [Int: TowerLevel]]] = [.melee: [1: [1:
        TowerLevel(cost: 100, range: 100, fireInterval: 1,
            meleeUnit: MeleeUnitStats(soldierCount: 2, attackRating: 5,
                defenseRating: 0, hp: 50, rallyPointRadius: 100, attackInterval: 1,
                respawnSeconds: 5, healPerSecond: 0))]]]

    init(lifetime: Double = 20, cooldown: Double = 20) throws {
        reinforcementSchedule = ReinforcementSchedule(config:
            try ReinforcementConfig(timeToLiveSeconds: lifetime, cooldownSeconds: cooldown))
    }
    func advance(to seconds: Int) {
        timer.tick = Int64(seconds * SimClock.ticksPerSecond)
        advanceReinforcements()
    }
    struct MilitiaSoldier: Identifiable {
        let id: Int
        let assetName: String
        var position: CGPoint
        var hp: Double
        var maxHP: Double
    }
private struct MilitiaGarrison {
        var rallyPoint: Point
        var units: [MilitiaUnit]
        var enemySwingTicks: [Int: Int] = [:]
        var stats: MeleeUnitStats? = nil
        var anchor: Point? = nil
    }
private struct WalkPose {
        var facing: UnitFacing
        var walkPhase: Double
        var isWalking: Bool
    }
var canCallReinforcements: Bool {
        isReady && !isDefeated && !isCleared && reinforcementStats != nil
            && reinforcementSchedule?.cooldown(at: timer.tick).isReady == true
    }
private var reinforcementStats: MeleeUnitStats? {
        guard let levels = towerLevels[.melee] else { return nil }
        for level in levels.keys.sorted() {
            guard let branches = levels[level] else { continue }
            for branch in branches.keys.sorted() {
                if let melee = branches[branch]?.meleeUnit { return melee }
            }
        }
        return nil
    }
private func garrisonMelee(slot: Int,
                               garrison: MilitiaGarrison) -> (stats: MeleeUnitStats,
                                                              anchor: Point)? {
        if let stats = garrison.stats, let anchor = garrison.anchor {
            return (stats, anchor)
        }
        guard let tower = placedTower(atSlot: slot),
              let stats = towerLevel(for: tower)?.meleeUnit else { return nil }
        return (stats, Point(Double(tower.position.x), Double(tower.position.y)))
    }
func callReinforcements(at point: CGPoint) -> Bool {
        guard canCallReinforcements, let melee = reinforcementStats,
              reinforcementSchedule?.deploy(slot: nextReinforcementSlot, at: timer.tick) == true
        else { return false }
        let anchor = Point(Double(point.x), Double(point.y))
        garrisonsBySlot[nextReinforcementSlot] = MilitiaGarrison(
            rallyPoint: anchor,
            units: (0..<Self.reinforcementCount).map { index in
                MilitiaUnit(position: meleeFormation.spawnPoint(
                    index: index, of: Self.reinforcementCount, building: anchor),
                            hp: melee.hp)
            },
            stats: melee,
            anchor: anchor)
        nextReinforcementSlot -= 1
        reinforcementCooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        publishMilitia()
        return true
    }
private func advanceReinforcements() {
        guard let expired = reinforcementSchedule?.expire(at: timer.tick) else { return }
        let cooldown = reinforcementSchedule!.cooldown(at: timer.tick)
        if reinforcementCooldown != cooldown { reinforcementCooldown = cooldown }
        guard !expired.isEmpty else { return }
        for slot in expired {
            guard let garrison = garrisonsBySlot.removeValue(forKey: slot) else { continue }
            for index in garrison.units.indices {
                let id = slot * 8 + index
                militiaPrevPositions[id] = nil
                militiaPoses[id] = nil
                militiaRespawnedIDs.remove(id)
            }
            damageTotalBySlot[slot] = nil
        }
        // Release expired soldiers' targets before walkers move this frame.
        // Preserve any blocks still held by a tower soldier or hero.
        let fightingUnits = garrisonsBySlot.values.flatMap(\.units) + heroPosts.map(\.unit)
        blockedWalkerIDs = Set(fightingUnits.filter { $0.state == .fighting && $0.targetSpawnID >= 0 }
            .map(\.targetSpawnID))
        // Publish even when the last garrison expired, clearing its sprites.
        publishMilitia()
    }
private func publishMilitia(alpha: Double = 1) {
        var out: [MilitiaSoldier] = []
        for slot in garrisonsBySlot.keys.sorted() {
            guard let g = garrisonsBySlot[slot],
                  let resolved = garrisonMelee(slot: slot, garrison: g)
            else { continue }
            let melee = resolved.stats
            for (i, u) in g.units.enumerated() where u.state != .dead {
                let id = slot * 8 + i
                let cur = CGPoint(x: u.position.x, y: u.position.y)
                let prev = militiaPrevPositions[id] ?? cur
                let pose = militiaPoses[id]
                    ?? WalkPose(facing: .south, walkPhase: 0, isWalking: false)
                let stepDistance = hypot(Double(cur.x - prev.x),
                                         Double(cur.y - prev.y))
                let renderedPhase = MeleeWalkCycle.interpolatedPhase(
                    currentPhase: pose.walkPhase,
                    stepDistance: stepDistance,
                    alpha: alpha,
                    cycleDistance: MeleeWalkCycle.cycleDistance)
                out.append(MilitiaSoldier(
                    id: id,
                    assetName: MeleeWalkCycle.assetName(facing: pose.facing,
                                                        walkPhase: renderedPhase,
                                                        isWalking: pose.isWalking),
                    position: CGPoint(x: prev.x + (cur.x - prev.x) * alpha,
                                      y: prev.y + (cur.y - prev.y) * alpha),
                    hp: u.hp,
                    maxHP: melee.hp))
            }
        }
        militia = out
    }

    static func run() throws {
        let point = CGPoint(x: 120, y: 180)
        let single = try RunnerProbe()
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2)
        precondition(single.militia.allSatisfy { $0.position == point })
        for _ in 0..<20 { precondition(!single.callReinforcements(at: .zero)) }
        precondition(single.garrisonsBySlot.count == 1 && single.nextReinforcementSlot == -2)
        single.garrisonsBySlot[-1]!.units[0].state = .fighting
        single.garrisonsBySlot[-1]!.units[0].targetSpawnID = 99
        single.blockedWalkerIDs = [99]
        single.militiaPrevPositions[-8] = point
        single.militiaPoses[-8] = WalkPose(facing: .south, walkPhase: 0, isWalking: false)
        single.militiaRespawnedIDs = [-8]
        single.damageTotalBySlot[-1] = 10
        single.advance(to: 19)
        precondition(single.militia.count == 2 && !single.canCallReinforcements)
        single.advance(to: 20)
        precondition(single.militia.isEmpty && single.garrisonsBySlot.isEmpty)
        precondition(single.blockedWalkerIDs.isEmpty && single.militiaPrevPositions.isEmpty)
        precondition(single.militiaPoses.isEmpty && single.militiaRespawnedIDs.isEmpty)
        precondition(single.damageTotalBySlot.isEmpty && single.money == 123)
        precondition(single.canCallReinforcements && single.reinforcementCooldown.isReady)
        precondition(single.callReinforcements(at: point))
        precondition(single.militia.count == 2 && !single.canCallReinforcements)

        let overlap = try RunnerProbe(lifetime: 30, cooldown: 20)
        precondition(overlap.callReinforcements(at: point))
        overlap.advance(to: 20)
        precondition(overlap.callReinforcements(at: .zero))
        precondition(overlap.militia.count == 4)
        var towerUnit = MilitiaUnit(position: Point(5, 5), hp: 50)
        towerUnit.state = .fighting
        towerUnit.targetSpawnID = 100
        overlap.garrisonsBySlot[0] = MilitiaGarrison(rallyPoint: Point(5, 5), units: [towerUnit])
        var heroUnit = towerUnit
        heroUnit.targetSpawnID = 101
        overlap.heroPosts = [HeroFixture(unit: heroUnit)]
        overlap.blockedWalkerIDs = [99, 100, 101]
        overlap.advance(to: 30)
        precondition(overlap.garrisonsBySlot[-1] == nil && overlap.garrisonsBySlot[-2] != nil)
        precondition(overlap.militia.count == 3 && overlap.blockedWalkerIDs == [100, 101])
        overlap.advance(to: 50)
        precondition(overlap.militia.map(\.id) == [0] && overlap.garrisonsBySlot.count == 1)
        precondition(overlap.heroPosts.count == 1 && overlap.blockedWalkerIDs == [100, 101])

        let dead = try RunnerProbe(lifetime: 5, cooldown: 20)
        precondition(dead.callReinforcements(at: point))
        for i in 0..<2 {
            dead.garrisonsBySlot[-1]!.units[i].state = .dead
            dead.garrisonsBySlot[-1]!.units[i].respawnTicksLeft = 100
        }
        dead.advance(to: 5)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)
        precondition(!dead.canCallReinforcements)
        dead.advance(to: 200)
        precondition(dead.garrisonsBySlot.isEmpty && dead.militia.isEmpty)

        for state in 0..<4 {
            let unavailable = try RunnerProbe()
            if state == 0 { unavailable.isReady = false }
            if state == 1 { unavailable.isDefeated = true }
            if state == 2 { unavailable.isCleared = true }
            if state == 3 { unavailable.towerLevels = [:] }
            precondition(!unavailable.callReinforcements(at: point))
            precondition(unavailable.garrisonsBySlot.isEmpty && unavailable.reinforcementCooldown.isReady)
        }
        print("PASS: runner deployment, repeated taps, expiry cleanup, dead groups, overlapping groups, tower/hero preservation, unavailable states")
    }
}
@main struct Probe { static func main() throws { try RunnerProbe.run() } }
