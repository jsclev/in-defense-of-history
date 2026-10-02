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
                upgradePolicyIndex: Int, seed: UInt64,
                towerLimits: GeneticTowerLimits = .init(), openingKind: TowerKind? = nil,
                openingCount: Int? = nil, upgradesPerBuild requestedCadence: Int? = nil,
                decisionDelay requestedDelay: Double? = nil, partialInvestments: Bool = false) throws {
        try towerLimits.validate(study: study)
        guard placementIndex >= 0, (0..<10).contains(upgradePolicyIndex) else {
            throw DbError.Db(message: "money study: unsupported placement or upgrade policy index")
        }
        self.placementIndex = placementIndex
        self.upgradePolicyIndex = upgradePolicyIndex
        var rng = SeededRNG(seed: seed &+ UInt64(placementIndex)).fork(stream: 40)
        var slots = Array(study.level.towerSlots.indices)
        slots.shuffle(using: &rng)
        var paths: [AuthoredMoneyStudy.TowerPath] = []
        var kindCounts: [String: Int] = [:]
        for index in slots.indices {
            // Opening defenses must be able to fight. Family mix is a strategy
            // choice, never a requirement to buy support before defending.
            let mustChooseMajority = towerLimits.majorityKind.map {
                slots.count / 2 + 1 - kindCounts[$0.rawValue, default: 0] >= slots.count - index
            } ?? false
            let available = study.towerPaths.filter { path in
                (partialInvestments || openingKind != nil || index >= 3 || path.type.levels[0].attackMode.firesProjectiles)
                    && kindCounts[path.kind.rawValue, default: 0] < (towerLimits.maximumByKind[path.kind.rawValue] ?? slots.count)
                    && (!mustChooseMajority || path.kind == towerLimits.majorityKind)
            }
            let preferred = available.filter { path in
                if let openingKind, index < (openingCount ?? 4) {
                    // Explicit creative seed families include blockers and supply.
                    // Interleave a fighting tower; the engine still decides costs.
                    return index % 3 == 2 ? path.type.levels[0].attackMode.firesProjectiles : path.kind == openingKind
                }
                guard !partialInvestments, index < 3 else { return true }
                let mode = path.type.levels[0].attackMode
                switch placementIndex % 4 {
                case 0: return mode == .direct
                case 1: return mode == .shell
                default: return mode.firesProjectiles
                }
            }
            // A family preference cannot require a locked tower (for example,
            // Battle Road has no artillery). Choose another authored, unlocked
            // opening defense when that preferred family is unavailable.
            let candidates = preferred.isEmpty ? available : preferred
            guard !candidates.isEmpty else { throw DbError.Db(message: "money study: no unlocked opening defense for plan \(placementIndex)") }
            // A family with more authored branches must not receive more random
            // opening slots merely because it has more catalog rows.
            var choices = candidates
            if partialInvestments {
                let kinds = Array(Set(candidates.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
                let kind = kinds[Int.random(in: kinds.indices, using: &rng)]
                choices = candidates.filter { $0.kind == kind }
            }
            let chosen = choices[Int.random(in: choices.indices, using: &rng)]
            paths.append(chosen)
            kindCounts[chosen.kind.rawValue, default: 0] += 1
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
            let tiers = partialInvestments ? Int.random(in: 1...path.type.levels.count, using: &rng) : path.type.levels.count
            for tier in 0..<tiers {
                if tier > 0 { chain.append(.upgrade(slot: slots[index])) }
                for upgrade in path.type.levels[tier].upgradePaths.sorted(by: { $0.slot < $1.slot }) {
                    let ranks = partialInvestments ? Int.random(in: 0...upgrade.ranks.count, using: &rng) : upgrade.ranks.count
                    for _ in 0..<ranks {
                        chain.append(.purchaseUpgrade(slot: slots[index], pathID: upgrade.id))
                    }
                }
            }
            chains.append(chain)
        }
        // Five different opening sizes, each tested both with quick upgrades
        // and with a longer delay between decisions. These are player policies,
        // not tower tuning, and never alter an authored price or ability.
        let opening = min(slots.count, max(1, openingCount ?? (2 + upgradePolicyIndex % 5)))
        let decisionDelay = requestedDelay ?? (upgradePolicyIndex < 5 ? 0.5 : 5.0)
        var cursors = Array(repeating: 0, count: slots.count)
        var actions: [ScriptedBuildOrder.Action] = []
        for index in 0..<opening {
            actions.append(chains[index][0])
            cursors[index] = 1
        }
        var built = opening
        var upgradesSinceBuild = 0
        let upgradesPerBuild = requestedCadence ?? (1 + upgradePolicyIndex % 5)
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
