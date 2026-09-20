import Foundation

/// A complete, reproducible decision schedule. The same desired decisions and
/// earliest times are replayed at each budget; lack of money delays an action.
public struct MoneyStudyPlan: Sendable {
    public let placementIndex: Int
    public let upgradePolicyIndex: Int
    public let slotOrder: [Int]
    public let towerIDs: [UUID]
    public let steps: [ScriptedBuildOrder.Step]

    private struct ScoredSlot {
        let slot: Int
        let score: Double
    }

    private static func coverage(slot: Int, tuning: TowerLevel, level: LevelInfo, weights: [Double]) -> Double {
        let origin = level.towerSlots[slot].position
        let center = CGPoint(x: origin.x, y: origin.y)
        var covered = 0.0
        for (index, road) in level.paths.enumerated() where weights[index] > 0 {
            let spacing = road.totalLength / 100
            guard spacing > 0 else { continue }
            for sample in 0..<100 {
                let point = road.point(atDistance: Double(sample) * spacing)
                if tuning.attackRange.contains(CGPoint(x: point.x, y: point.y), from: center) {
                    covered += spacing * weights[index]
                }
            }
        }
        return covered
    }

    public init(study: AuthoredMoneyStudy, placementIndex: Int,
                upgradePolicyIndex: Int, seed: UInt64) throws {
        guard placementIndex >= 0, (0..<10).contains(upgradePolicyIndex) else {
            throw DbError.Db(message: "money study: unsupported placement or upgrade policy index")
        }
        self.placementIndex = placementIndex
        self.upgradePolicyIndex = upgradePolicyIndex
        var rng = SeededRNG(seed: seed &+ UInt64(placementIndex)).fork(stream: 40)
        var slots = Array(study.level.towerSlots.indices)
        slots.shuffle(using: &rng)
        var paths: [AuthoredMoneyStudy.TowerPath] = []
        for index in slots.indices {
            // Opening defenses must be able to fight. Family mix is a strategy
            // choice, never a requirement to buy support before defending.
            let candidates = study.towerPaths.filter { path in
                guard index < 3 else { return true }
                let mode = path.type.levels[0].attackMode
                switch placementIndex % 4 {
                case 0: return mode == .direct
                case 1: return mode == .shell
                default: return mode.firesProjectiles
                }
            }
            guard !candidates.isEmpty else { throw DbError.Db(message: "money study: no unlocked opening defense for plan \(placementIndex)") }
            paths.append(candidates[Int.random(in: candidates.indices, using: &rng)])
        }
        // Score the routes actually used by the opening/upcoming waves; shared
        // stretches on unused alternative routes must not dominate placement.
        // One quarter of plans retain random placements to sample weaker play.
        if placementIndex % 4 != 3 {
            var available = slots
            slots.removeAll(keepingCapacity: true)
            for (index, path) in paths.enumerated() {
                let effects = study.battle.playerUpgrades.loadout.effects
                let tuning = effects.combat(path.type.levels[0], kind: path.kind)
                var weights = Array(repeating: 0.0, count: study.level.paths.count)
                for wave in study.level.waves.prefix(max(1, index)) {
                    for spawn in wave.spawns { weights[spawn.pathIndex] += Double(spawn.count) }
                }
                var scored: [ScoredSlot] = []
                for slot in available {
                    scored.append(ScoredSlot(slot: slot, score: Self.coverage(slot: slot, tuning: tuning, level: study.level, weights: weights)))
                }
                scored.sort { left, right in
                    if left.score == right.score { return left.slot < right.slot }
                    return left.score > right.score
                }
                let choice = placementIndex % 4 == 0 ? 0 : Int.random(in: 0..<min(3, scored.count), using: &rng)
                let slot = scored[choice].slot
                slots.append(slot); available.removeAll { $0 == slot }
            }
        }
        slotOrder = slots
        towerIDs = paths.map { $0.type.id }

        var chains: [[ScriptedBuildOrder.Action]] = []
        for (index, path) in paths.enumerated() {
            var chain: [ScriptedBuildOrder.Action] = [.build(slot: slots[index], towerID: path.type.id)]
            for tier in path.type.levels.indices {
                if tier > 0 { chain.append(.upgrade(slot: slots[index])) }
                for upgrade in path.type.levels[tier].upgradePaths.sorted(by: { $0.slot < $1.slot }) {
                    for _ in upgrade.ranks {
                        chain.append(.purchaseUpgrade(slot: slots[index], pathID: upgrade.id))
                    }
                }
            }
            chains.append(chain)
        }
        // Five different opening sizes, each tested both with quick upgrades
        // and with a longer delay between decisions. These are player policies,
        // not tower tuning, and never alter an authored price or ability.
        let opening = min(slots.count, 2 + upgradePolicyIndex % 5)
        let decisionDelay = upgradePolicyIndex < 5 ? 0.5 : 5.0
        var cursors = Array(repeating: 0, count: slots.count)
        var actions: [ScriptedBuildOrder.Action] = []
        for index in 0..<opening {
            actions.append(chains[index][0])
            cursors[index] = 1
        }
        var built = opening
        var upgradesSinceBuild = 0
        let upgradesPerBuild = 1 + upgradePolicyIndex % 5
        while let unfinished = chains.indices.first(where: { cursors[$0] < chains[$0].count }) {
            if built < slots.count && upgradesSinceBuild >= upgradesPerBuild {
                actions.append(chains[built][0])
                cursors[built] = 1
                built += 1
                upgradesSinceBuild = 0
                continue
            }
            let upgradeCandidates = (0..<built).filter { cursors[$0] < chains[$0].count }
            if let index = upgradePolicyIndex < 5 ? upgradeCandidates.first : upgradeCandidates.last {
                actions.append(chains[index][cursors[index]])
                cursors[index] += 1
                upgradesSinceBuild += 1
            } else {
                actions.append(chains[unfinished][0])
                cursors[unfinished] = 1
                built = max(built, unfinished + 1)
                upgradesSinceBuild = 0
            }
        }
        steps = actions.enumerated().map {
            .init(time: $0.offset < opening ? 0 : Double($0.offset - opening + 1) * decisionDelay, action: $0.element)
        }
    }
}

