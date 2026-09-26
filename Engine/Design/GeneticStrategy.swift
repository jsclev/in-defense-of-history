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
    public private(set) var metaProgression: MetaUpgradeProgression
    public var metaUpgrades: [MetaUpgrade] { metaProgression.upgrades }
    public var reinforcements: ReinforcementStrategy
    public var earlyWaves: EarlyWaveStrategy
    public init(decisions: [Decision], metaProgression: MetaUpgradeProgression, reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic) {
        self.decisions = decisions
        self.metaProgression = metaProgression
        self.reinforcements = reinforcements
        self.earlyWaves = earlyWaves
    }
    public init(plan: MoneyStudyPlan, metaProgression: MetaUpgradeProgression, reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic) {
        self.init(decisions: plan.steps.map { Decision(step: $0) }, metaProgression: metaProgression,
                  reinforcements: reinforcements, earlyWaves: earlyWaves)
    }

    private enum CodingKeys: String, CodingKey { case decisions, metaUpgrades, reinforcements, earlyWaves }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let progression = try values.decode(MetaUpgradeProgression.self, forKey: .metaUpgrades)
        self.init(decisions: try values.decode([Decision].self, forKey: .decisions), metaProgression: progression,
                  reinforcements: try values.decode(ReinforcementStrategy.self, forKey: .reinforcements),
                  earlyWaves: try values.decode(EarlyWaveStrategy.self, forKey: .earlyWaves))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(decisions, forKey: .decisions)
        try values.encode(metaProgression, forKey: .metaUpgrades)
        try values.encode(reinforcements, forKey: .reinforcements)
        try values.encode(earlyWaves, forKey: .earlyWaves)
    }

    public func playerState(in content: BattleContent) throws -> PlayerMetaUpgradeState {
        let state = try content.playerUpgrades.selecting(metaProgression.selected)
        guard state.loadout.spentStars == metaProgression.spentStars else {
            throw DbError.Db(message: "genetic strategy: meta progression differs from DAO costs")
        }
        return state
    }

    /// Transfer a battle plan onto a validated progression, retaining its orders.
    public func selectingMetaUpgrades(_ progression: MetaUpgradeProgression, in study: AuthoredMoneyStudy) throws -> Self {
        let result = Self(decisions: decisions, metaProgression: progression, reinforcements: reinforcements, earlyWaves: earlyWaves)
        try result.validate(study: study)
        return result
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
    public static func crossover(_ a: Self, _ b: Self, slots: Int, metaFactory: MetaUpgradesFactory, rng: inout SeededRNG) throws -> Self {
        // Index each parent's chains once, instead of scanning its complete
        // purchase list again for every slot.
        func chains(_ parent: Self) -> [[(Double, Decision)]] {
            var result = Array(repeating: [(Double, Decision)](), count: slots)
            for (index, decision) in parent.decisions.enumerated() {
                let slot = decision.step.action.slot
                guard result.indices.contains(slot) else { continue }
                result[slot].append((Double(index) / Double(max(1, parent.decisions.count)), decision))
            }
            return result
        }
        let left = chains(a), right = chains(b)
        var inherited: [(Double, Int, Decision)] = []
        inherited.reserveCapacity(max(a.decisions.count, b.decisions.count))
        for slot in 0..<slots {
            let chain = Bool.random(using: &rng) ? left[slot] : right[slot]
            for (order, decision) in chain { inherited.append((order, slot, decision)) }
        }
        inherited.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        return Self(decisions: inherited.map { $0.2 },
                    metaProgression: try metaFactory.crossover(a.metaProgression, b.metaProgression, using: &rng),
                    reinforcements: Bool.random(using: &rng) ? a.reinforcements : b.reinforcements,
                    earlyWaves: EarlyWaveStrategy.crossover(a.earlyWaves, b.earlyWaves, rng: &rng))
    }

    public mutating func mutate(study: AuthoredMoneyStudy, metaFactory: MetaUpgradesFactory, rng: inout SeededRNG,
                                earlyWaveCallsEnabled: Bool = true, metaMutationEnabled: Bool = true) throws {
        _ = try metaFactory.loadout(for: metaProgression)
        let operations = (0..<(earlyWaveCallsEnabled ? 10 : 9)).filter { metaMutationEnabled || $0 != 7 }
        let operation = decisions.isEmpty ? 0 : operations[Int.random(in: operations.indices, using: &rng)]
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
            metaProgression = try metaFactory.mutate(metaProgression, using: &rng)
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
    public var runID: UUID? = nil
    public let seed: UInt64
    public let result: SimulationResult
    public let wavesStarted: Int
    public let waveEconomy: [GeneticWaveEconomy]
    public let reinforcementDeployments: [ReinforcementDeployment]
    public let waveCalls: [WaveCallReceipt]
    public static func == (a: Self, b: Self) -> Bool {
        a.seed == b.seed && a.result == b.result && a.wavesStarted == b.wavesStarted
            && a.waveEconomy == b.waveEconomy && a.reinforcementDeployments == b.reinforcementDeployments
            && a.waveCalls == b.waveCalls
    }
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
    private var pending: GeneticPurchaseCursor
    private let expectedMetaUpgrades: MetaUpgradeProgression
    private var checkedMetaUpgrades = false
    // Player policy: after a needGold response, wait for a changed balance or a
    // successful purchase before trying again. Never calculate affordability.
    private var purchases = 0
    private var reinforcements: ReinforcementCommander
    private var earlyWaves: EarlyWaveCommander
    public init(_ strategy: GeneticStrategy) {
        pending = GeneticPurchaseCursor(strategy.decisions)
        expectedMetaUpgrades = strategy.metaProgression
        reinforcements = ReinforcementCommander(strategy.reinforcements)
        earlyWaves = EarlyWaveCommander(strategy.earlyWaves)
    }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        if !checkedMetaUpgrades {
            guard sim.content.playerUpgrades.loadout.selected == expectedMetaUpgrades.selected,
                  sim.content.playerUpgrades.loadout.spentStars == expectedMetaUpgrades.spentStars else {
                throw DbError.Db(message: "genetic commander: battle meta upgrades do not match candidate DNA")
            }
            checkedMetaUpgrades = true
        }
        pending.beginTick()
        while let index = pending.pop() {
            let decision = pending.decisions[index]
            guard decision.step.time <= sim.time, decision.earliestWave <= sim.currentWave else { continue }
            let slot = pending.slots[index]
            let result: BuildResult
            if let waiting = pending.waiting[slot], waiting.money == sim.gold, waiting.purchases == purchases {
                // Reuse the engine's previous needGold response until money or
                // a completed purchase changes. No price rule is duplicated.
                if decision.saveForPurchase { break }
                continue
            } else { result = sim.execute(decision.step.action) }
            switch result {
            case .ok:
                pending.complete(index); purchases += 1
            case .needGold:
                pending.waiting[slot] = (sim.gold, purchases)
            case .invalid:
                throw DbError.Db(message: "Engine rejected genetic command: \(decision.step.action)")
            }
            if result == .needGold && decision.saveForPurchase { break }
        }
        finishInputs(sim: sim)
        try reinforcements.tick(sim: sim)
        try earlyWaves.tick(sim: sim)
    }

    @MainActor private func finishInputs(sim: GameSimulation) {
        for site in sim.readyDemolitionSites { _ = sim.perform(.placeDemolition(slot: site.slot, point: site.point)) }
        if sim.currentWave == 0 { sim.startNextWave() }
    }

    @MainActor public static func evaluate(_ strategy: GeneticStrategy, recording: BattleRecording, content: BattleContent,
        money: Int, seed: UInt64, maxSeconds: Double, heroesEnabled: Bool = true,
        towerObserver: (([BattleTowerSnapshot]) -> Void)? = nil) throws -> GeneticEvaluation {
        let selection = try strategy.playerState(in: content).loadout.selected
        try strategy.reinforcements.validate()
        try strategy.earlyWaves.validate(waveCount: content.level.numWaves)
        let battle = try content.selectingMetaUpgrades(selection)
        let sim = try GameSimulation(recording: recording, content: battle, startingMoney: money, heroesEnabled: heroesEnabled, seed: seed)
        var completed = false
        defer { if !completed { sim.finishRecording(status: .failed) } }
        var commander = Self(strategy), economy: [GeneticWaveEconomy] = []
        var previousWave = 0
        while sim.outcome == nil, sim.time < maxSeconds {
            try commander.tick(sim: sim)
            sim.stepPaced()
            if sim.currentWave != previousWave {
                previousWave = sim.currentWave
                economy.append(GeneticWaveEconomy(wave: previousWave, seconds: sim.time, money: sim.gold, lives: sim.lives))
            }
        }
        let outcome = sim.result()
        towerObserver?(sim.towers)
        sim.finishRecording(status: outcome.outcome == .victory ? .victory : outcome.outcome == .defeat ? .defeat : .timeout)
        var evaluation = GeneticEvaluation(seed: seed, result: outcome, wavesStarted: sim.currentWave, waveEconomy: economy,
                                 reinforcementDeployments: sim.reinforcementDeployments, waveCalls: sim.waveCalls)
        evaluation.runID = sim.runID
        completed = true
        return evaluation
    }
}

/// Only the first unfinished order for each tower slot can run. The small heap
/// merges those chains by their original global priority, so later affordable
/// orders, saving barriers, and same-tick purchases behave exactly as before.
/// Completed entries never move and blocked chains are not rescanned each tick.
private struct GeneticPurchaseCursor {
    let decisions: [GeneticStrategy.Decision]
    let slots: [Int]
    private let next: [Int]
    private var heads: [Int]
    var waiting: [(money: Int, purchases: Int)?]
    private var heap: [Int] = []

    init(_ decisions: [GeneticStrategy.Decision]) {
        self.decisions = decisions
        var ordinals: [Int: Int] = [:], last: [Int] = [], heads: [Int] = []
        var slots: [Int] = [], next = Array(repeating: -1, count: decisions.count)
        slots.reserveCapacity(decisions.count)
        for (index, decision) in decisions.enumerated() {
            let key = decision.step.action.slot
            if let ordinal = ordinals[key] {
                next[last[ordinal]] = index; last[ordinal] = index; slots.append(ordinal)
            } else {
                ordinals[key] = heads.count; slots.append(heads.count)
                heads.append(index); last.append(index)
            }
        }
        self.slots = slots; self.next = next; self.heads = heads
        waiting = Array(repeating: nil, count: heads.count)
        heap.reserveCapacity(heads.count)
    }
    mutating func beginTick() {
        heap.removeAll(keepingCapacity: true)
        for head in heads where head >= 0 { push(head) }
    }
    mutating func complete(_ index: Int) {
        let slot = slots[index]
        waiting[slot] = nil; heads[slot] = next[index]
        if next[index] >= 0 { push(next[index]) }
    }
    private mutating func push(_ index: Int) {
        heap.append(index)
        var child = heap.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard heap[parent] > heap[child] else { break }
            heap.swapAt(parent, child); child = parent
        }
    }
    mutating func pop() -> Int? {
        guard !heap.isEmpty else { return nil }
        let result = heap[0], last = heap.removeLast()
        if !heap.isEmpty {
            heap[0] = last
            var parent = 0
            while parent * 2 + 1 < heap.count {
                var child = parent * 2 + 1
                if child + 1 < heap.count, heap[child + 1] < heap[child] { child += 1 }
                guard heap[child] < heap[parent] else { break }
                heap.swapAt(parent, child); parent = child
            }
        }
        return result
    }
}
