import Foundation

/// Search DNA describes player intent only. No prices, combat estimates, or
/// outcomes are calculated here. Tower IDs and upgrade choices come from DAOs.
public struct GeneticStrategy: Codable, Equatable, Sendable {
    public struct Decision: Codable, Equatable, Sendable {
        public var step: ScriptedBuildOrder.Step
        /// Zero permits opening purchases; otherwise wait until this wave starts.
        public var earliestWave: Int
        /// When the engine returns needGold, reserve future income for this order.
        public var saveForPurchase: Bool

        public init(step: ScriptedBuildOrder.Step, earliestWave: Int = 0, saveForPurchase: Bool = false) {
            self.step = step; self.earliestWave = earliestWave; self.saveForPurchase = saveForPurchase
        }
    }

    public var decisions: [Decision]
    public private(set) var metaUpgrades: [MetaUpgrade]
    public var reinforcements: ReinforcementStrategy
    public var earlyWaves: EarlyWaveStrategy
    public init(decisions: [Decision], metaUpgrades: [MetaUpgrade], reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic) {
        self.decisions = decisions
        self.metaUpgrades = metaUpgrades.sorted { $0.rawValue < $1.rawValue }
        self.reinforcements = reinforcements
        self.earlyWaves = earlyWaves
    }
    public init(plan: MoneyStudyPlan, metaUpgrades: [MetaUpgrade], reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic) {
        self.init(decisions: plan.steps.map { Decision(step: $0) }, metaUpgrades: metaUpgrades,
                  reinforcements: reinforcements, earlyWaves: earlyWaves)
    }

    private enum CodingKeys: String, CodingKey { case decisions, metaUpgrades, reinforcements, earlyWaves }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let upgrades = try values.decode([MetaUpgrade].self, forKey: .metaUpgrades)
        guard Set(upgrades).count == upgrades.count else {
            throw DecodingError.dataCorruptedError(forKey: .metaUpgrades, in: values, debugDescription: "Duplicate meta upgrade ID")
        }
        self.init(decisions: try values.decode([Decision].self, forKey: .decisions), metaUpgrades: upgrades,
                  reinforcements: try values.decode(ReinforcementStrategy.self, forKey: .reinforcements),
                  earlyWaves: try values.decode(EarlyWaveStrategy.self, forKey: .earlyWaves))
    }

    public func playerState(in content: BattleContent) throws -> PlayerMetaUpgradeState {
        guard Set(metaUpgrades).count == metaUpgrades.count else {
            throw DbError.Db(message: "genetic strategy: duplicate meta upgrade ID")
        }
        return try content.playerUpgrades.selecting(Set(metaUpgrades))
    }

    /// Structural validation of a player's plan, not a substitute for the
    /// engine's eligibility/affordability checks. Corrupt content is never repaired.
    public func validate(study: AuthoredMoneyStudy) throws {
        _ = try playerState(in: study.battle)
        try reinforcements.validate()
        try earlyWaves.validate(waveCount: study.level.numWaves)
        var built: Set<Int> = []
        for decision in decisions {
            let slot = decision.step.action.slot
            guard study.level.towerSlots.indices.contains(slot), decision.step.time.isFinite,
                  decision.step.time >= 0, (0...study.level.numWaves).contains(decision.earliestWave) else {
                throw DbError.Db(message: "genetic strategy: invalid slot or decision trigger")
            }
            if case let .build(_, id) = decision.step.action {
                guard built.insert(slot).inserted, study.towerPaths.contains(where: { $0.type.id == id }) else {
                    throw DbError.Db(message: "genetic strategy: duplicate slot or unknown database tower ID \(id)")
                }
            } else if !built.contains(slot) {
                throw DbError.Db(message: "genetic strategy: order precedes construction at slot \(slot)")
            }
        }
    }

    /// Inherit a whole construction/upgrade chain for each slot. Interleave those
    /// chains by their parents' relative order, never swapping their predecessors.
    public static func crossover(_ a: Self, _ b: Self, slots: Int, rng: inout SeededRNG) -> Self {
        var inherited: [(Double, Int, Decision)] = []
        for slot in 0..<slots {
            let parent = Bool.random(using: &rng) ? a : b
            for (index, decision) in parent.decisions.enumerated() where decision.step.action.slot == slot {
                inherited.append((Double(index) / Double(max(1, parent.decisions.count)), slot, decision))
            }
        }
        inherited.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        return Self(decisions: inherited.map { $0.2 },
                    metaUpgrades: Bool.random(using: &rng) ? a.metaUpgrades : b.metaUpgrades,
                    reinforcements: Bool.random(using: &rng) ? a.reinforcements : b.reinforcements,
                    earlyWaves: EarlyWaveStrategy.crossover(a.earlyWaves, b.earlyWaves, rng: &rng))
    }

    public mutating func mutate(study: AuthoredMoneyStudy, metaChoices: [[MetaUpgrade]], rng: inout SeededRNG,
                                earlyWaveCallsEnabled: Bool = true) {
        precondition(!metaChoices.isEmpty)
        let operation = decisions.isEmpty ? 0 : Int.random(in: 0..<(earlyWaveCallsEnabled ? 10 : 9), using: &rng)
        switch operation {
        case 0:
            // Replace/add one slot's plan. Partial investments and skipped ability
            // purchases are strategy choices, with all candidates drawn from content.
            let slot = Int.random(in: study.level.towerSlots.indices, using: &rng)
            let path = study.towerPaths[Int.random(in: study.towerPaths.indices, using: &rng)]
            decisions.removeAll { $0.step.action.slot == slot }
            let tierCount = Int.random(in: 1...path.type.levels.count, using: &rng)
            var chain: [ScriptedBuildOrder.Action] = [.build(slot: slot, towerID: path.type.id)]
            for tier in 0..<tierCount {
                if tier > 0 { chain.append(.upgrade(slot: slot)) }
                for upgrade in path.type.levels[tier].upgradePaths.sorted(by: { $0.slot < $1.slot }) {
                    let count = Int.random(in: 0...upgrade.ranks.count, using: &rng)
                    for _ in 0..<count { chain.append(.purchaseUpgrade(slot: slot, pathID: upgrade.id)) }
                }
            }
            var insertion = Int.random(in: 0...decisions.count, using: &rng)
            for action in chain {
                decisions.insert(Decision(step: .init(time: 0, action: action),
                    saveForPurchase: Bool.random(using: &rng)), at: insertion)
                insertion = Int.random(in: (insertion + 1)...decisions.count, using: &rng)
            }
        case 1:
            let a = Int.random(in: study.level.towerSlots.indices, using: &rng)
            let b = Int.random(in: study.level.towerSlots.indices, using: &rng)
            for index in decisions.indices {
                let action = decisions[index].step.action
                let old = action.slot, slot = old == a ? b : old == b ? a : old
                switch action {
                case let .build(_, id): decisions[index].step.action = .build(slot: slot, towerID: id)
                case .upgrade: decisions[index].step.action = .upgrade(slot: slot)
                case let .purchaseUpgrade(_, id): decisions[index].step.action = .purchaseUpgrade(slot: slot, pathID: id)
                }
            }
        case 2:
            let index = Int.random(in: decisions.indices, using: &rng)
            let decision = decisions.remove(at: index), slot = decision.step.action.slot
            let previous = decisions.indices.last(where: { $0 < index && decisions[$0].step.action.slot == slot })
            let next = decisions.indices.first(where: { $0 >= index && decisions[$0].step.action.slot == slot })
            decisions.insert(decision, at: Int.random(in: (previous.map { $0 + 1 } ?? 0)...(next ?? decisions.count), using: &rng))
        case 3:
            let index = Int.random(in: decisions.indices, using: &rng)
            // Timing search resolution, not a game clock or combat constant.
            decisions[index].step.time = max(0, decisions[index].step.time + Double.random(in: -30...30, using: &rng))
        case 4:
            let index = Int.random(in: decisions.indices, using: &rng)
            decisions[index].earliestWave = Int.random(in: 0...study.level.numWaves, using: &rng)
        case 5:
            decisions[Int.random(in: decisions.indices, using: &rng)].saveForPurchase.toggle()
        case 6:
            let index = Int.random(in: decisions.indices, using: &rng)
            let slot = decisions[index].step.action.slot
            decisions = decisions.enumerated().filter { $0.offset < index || $0.element.step.action.slot != slot }.map(\.element)
        case 7:
            metaUpgrades = metaChoices[Int.random(in: metaChoices.indices, using: &rng)]
        case 8:
            reinforcements = .random(paths: study.level.paths, rng: &rng)
        default:
            earlyWaves.mutate(waveCount: study.level.numWaves, rng: &rng)
        }
    }
}

/// A complete battle is the unit of fitness. Earlier wave performance is not
/// discounted or cashed out as a win, and leftover money cannot outweigh victory.
public struct GeneticEvaluation: Codable, Sendable, Equatable {
    public let seed: UInt64
    public let result: SimulationResult
    public let wavesStarted: Int
    public let waveEconomy: [GeneticWaveEconomy]
    public let reinforcementDeployments: [ReinforcementDeployment]
    public let waveCalls: [WaveCallReceipt]
}

public struct GeneticWaveEconomy: Codable, Sendable, Equatable {
    public let wave: Int
    public let seconds: Double
    public let money: Int
    public let lives: Int
}

public struct GeneticFitness: Codable, Equatable, Comparable {
    public let winRate: Double
    public let meanVictoryLives: Double
    public let meanWavesStarted: Double
    public let meanSurvivalSeconds: Double
    public init(_ evaluations: [GeneticEvaluation]) {
        precondition(!evaluations.isEmpty)
        let count = Double(evaluations.count)
        winRate = Double(evaluations.filter { $0.result.outcome == .victory }.count) / count
        meanVictoryLives = evaluations.reduce(0) { $0 + ($1.result.outcome == .victory ? Double($1.result.livesRemaining) : 0) } / count
        meanWavesStarted = evaluations.reduce(0) { $0 + Double($1.wavesStarted) } / count
        meanSurvivalSeconds = evaluations.reduce(0) { $0 + ($1.result.outcome == .defeat ? $1.result.seconds : 0) } / count
    }
    public static func < (a: Self, b: Self) -> Bool {
        if a.winRate != b.winRate { return a.winRate < b.winRate }
        if a.meanVictoryLives != b.meanVictoryLives { return a.meanVictoryLives < b.meanVictoryLives }
        if a.meanWavesStarted != b.meanWavesStarted { return a.meanWavesStarted < b.meanWavesStarted }
        return a.meanSurvivalSeconds < b.meanSurvivalSeconds
    }
}

/// The automated player retains only pending inputs. Every purchase, charge,
/// wave transition, balance, tick and result belongs to GameSimulation/BattleEngine.
public struct GeneticCommander {
    private var pending: [(offset: Int, element: GeneticStrategy.Decision)]
    private let expectedMetaUpgrades: Set<MetaUpgrade>
    private var checkedMetaUpgrades = false
    // Player policy: after a needGold response, wait for a changed balance or a
    // successful purchase before trying again. Never calculate affordability.
    private var waitingForIncome: [Int: (money: Int, purchases: Int)] = [:]
    private var purchases = 0
    private var reinforcements: ReinforcementCommander
    private var earlyWaves: EarlyWaveCommander
    public init(_ strategy: GeneticStrategy) {
        pending = Array(strategy.decisions.enumerated())
        expectedMetaUpgrades = Set(strategy.metaUpgrades)
        reinforcements = ReinforcementCommander(strategy.reinforcements)
        earlyWaves = EarlyWaveCommander(strategy.earlyWaves)
    }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        if !checkedMetaUpgrades {
            guard sim.content.playerUpgrades.loadout.selected == expectedMetaUpgrades else {
                throw DbError.Db(message: "genetic commander: battle meta upgrades do not match candidate DNA")
            }
            checkedMetaUpgrades = true
        }
        var blockedSlots: Set<Int> = [], done: Set<Int> = []
        for (index, decision) in pending {
            let slot = decision.step.action.slot
            guard !blockedSlots.contains(slot), decision.step.time <= sim.time,
                  decision.earliestWave <= sim.currentWave else {
                blockedSlots.insert(slot); continue
            }
            let result: BuildResult
            if let waiting = waitingForIncome[index], waiting.money == sim.gold, waiting.purchases == purchases {
                // This is the previous engine response, not a computed price or
                // new eligibility verdict. The player chooses to keep waiting.
                blockedSlots.insert(slot)
                if decision.saveForPurchase { break }
                continue
            } else { result = sim.execute(decision.step.action) }
            switch result {
            case .ok:
                done.insert(index); waitingForIncome.removeValue(forKey: index); purchases += 1
            case .needGold:
                waitingForIncome[index] = (sim.gold, purchases)
                blockedSlots.insert(slot)
            case .invalid:
                throw DbError.Db(message: "Engine rejected genetic command: \(decision.step.action)")
            }
            if result == .needGold && decision.saveForPurchase { break }
        }
        if !done.isEmpty { pending.removeAll { done.contains($0.offset) } }
        finishInputs(sim: sim)
        try reinforcements.tick(sim: sim)
        try earlyWaves.tick(sim: sim)
    }

    @MainActor private func finishInputs(sim: GameSimulation) {
        for site in sim.readyDemolitionSites { _ = sim.perform(.placeDemolition(slot: site.slot, point: site.point)) }
        if sim.currentWave == 0 { sim.startNextWave() }
    }

    @MainActor public static func evaluate(_ strategy: GeneticStrategy, content: BattleContent,
        money: Int, seed: UInt64, maxSeconds: Double) throws -> GeneticEvaluation {
        _ = try strategy.playerState(in: content)
        try strategy.reinforcements.validate()
        try strategy.earlyWaves.validate(waveCount: content.level.numWaves)
        let battle = try content.selectingMetaUpgrades(Set(strategy.metaUpgrades))
        let sim = try GameSimulation(content: battle, startingMoney: money, heroesEnabled: false, seed: seed)
        var commander = Self(strategy), economy: [GeneticWaveEconomy] = []
        var previousWave = 0
        while sim.outcome == nil, sim.time < maxSeconds {
            try commander.tick(sim: sim)
            sim.step()
            if sim.currentWave != previousWave {
                previousWave = sim.currentWave
                economy.append(GeneticWaveEconomy(wave: previousWave, seconds: sim.time, money: sim.gold, lives: sim.lives))
            }
        }
        return GeneticEvaluation(seed: seed, result: sim.result(), wavesStarted: sim.currentWave, waveEconomy: economy,
                                 reinforcementDeployments: sim.reinforcementDeployments, waveCalls: sim.waveCalls)
    }
}
