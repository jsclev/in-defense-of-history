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
    /// Empty in historical DNA: preserve the historical automatic sites.
    public var tactics: [GeneticTacticalOrder]
    public init(decisions: [Decision], metaProgression: MetaUpgradeProgression, reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic, tactics: [GeneticTacticalOrder] = []) {
        self.decisions = decisions
        self.metaProgression = metaProgression
        self.reinforcements = reinforcements
        self.earlyWaves = earlyWaves
        self.tactics = tactics
    }
    public init(plan: MoneyStudyPlan, metaProgression: MetaUpgradeProgression, reinforcements: ReinforcementStrategy = .immediate,
                earlyWaves: EarlyWaveStrategy = .automatic) {
        self.init(decisions: plan.steps.map { Decision(step: $0) }, metaProgression: metaProgression,
                  reinforcements: reinforcements, earlyWaves: earlyWaves)
    }

    private enum CodingKeys: String, CodingKey { case decisions, metaUpgrades, reinforcements, earlyWaves, tactics }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let progression = try values.decode(MetaUpgradeProgression.self, forKey: .metaUpgrades)
        self.init(decisions: try values.decode([Decision].self, forKey: .decisions), metaProgression: progression,
                  reinforcements: try values.decode(ReinforcementStrategy.self, forKey: .reinforcements),
                  earlyWaves: try values.decode(EarlyWaveStrategy.self, forKey: .earlyWaves),
                  tactics: try values.decodeIfPresent([GeneticTacticalOrder].self, forKey: .tactics) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(decisions, forKey: .decisions)
        try values.encode(metaProgression, forKey: .metaUpgrades)
        try values.encode(reinforcements, forKey: .reinforcements)
        try values.encode(earlyWaves, forKey: .earlyWaves)
        if !tactics.isEmpty { try values.encode(tactics, forKey: .tactics) }
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
        let result = Self(decisions: decisions, metaProgression: progression, reinforcements: reinforcements, earlyWaves: earlyWaves, tactics: tactics)
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
        try validateTactics(study: study)
    }

    /// Inherit a whole construction/upgrade chain for each slot. Interleave those
    /// chains by their parents' relative order, never swapping their predecessors.
    public static func crossover(_ a: Self, _ b: Self, slots: Int, metaFactory: MetaUpgradesFactory, rng: inout SeededRNG,
                                 preservingOpening: Set<Int> = []) throws -> Self {
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
        var tactics: [GeneticTacticalOrder] = []
        let openingFromLeft = Bool.random(using: &rng)
        inherited.reserveCapacity(max(a.decisions.count, b.decisions.count))
        for slot in 0..<slots {
            let useLeft = preservingOpening.contains(slot) ? openingFromLeft : Bool.random(using: &rng)
            let chain = useLeft ? left[slot] : right[slot]
            tactics += (useLeft ? a.tactics : b.tactics).filter { $0.slot == slot }
            for (order, decision) in chain { inherited.append((order, slot, decision)) }
        }
        inherited.sort { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
        return Self(decisions: inherited.map { $0.2 },
                    metaProgression: try metaFactory.crossover(a.metaProgression, b.metaProgression, using: &rng),
                    reinforcements: Bool.random(using: &rng) ? a.reinforcements : b.reinforcements,
                    earlyWaves: EarlyWaveStrategy.crossover(a.earlyWaves, b.earlyWaves, rng: &rng), tactics: tactics)
    }

    public enum Mutation: CaseIterable, Sendable {
        case replaceTower, swapSlots, movePurchase, timing, wave, saving, truncate
        case meta, reinforcements, earlyWaves, opening, tactics
    }

    /// Original successful purchases identify the effective genome. Retain a
    /// quarter of unrestricted mutations to explore currently unexecuted DNA.
    public func executedDecisionIndices(evidence: [GeneticEvaluation], study: AuthoredMoneyStudy) -> [Int] {
        var observed: Set<Int> = []
        let families = Dictionary(uniqueKeysWithValues: decisions.compactMap { decision -> (Int, UUID)? in
            guard case let .build(slot, id) = decision.step.action,
                  let path = study.towerPaths.first(where: { $0.type.id == id }) else { return nil }
            return (slot, path.tierIDs[0])
        })
        for evaluation in evidence {
            guard let profile = evaluation.placementPlan?.playstyle else { continue }
            var pending = Array(decisions.indices)
            for purchase in profile.purchases {
                guard families[purchase.slot] == purchase.familyID else { continue }
                if let i = pending.firstIndex(where: { index in
                    let action = decisions[index].step.action
                    guard action.slot == purchase.slot else { return false }
                    switch action {
                    case .build: return purchase.action == "build"
                    case .upgrade: return purchase.action == "upgrade"
                    case let .purchaseUpgrade(_, path): return purchase.action == "ability" && purchase.pathID == path
                    }
                }) { observed.insert(pending.remove(at: i)) }
            }
        }
        return observed.sorted()
    }

    public mutating func mutate(study: AuthoredMoneyStudy, metaFactory: MetaUpgradesFactory, rng: inout SeededRNG,
                                earlyWaveCallsEnabled: Bool = true, metaMutationEnabled: Bool = true,
                                evidence: [GeneticEvaluation] = [], operation requested: Mutation? = nil) throws {
        _ = try metaFactory.loadout(for: metaProgression)
        let operations = Mutation.allCases.filter { (earlyWaveCallsEnabled || $0 != .earlyWaves) && (metaMutationEnabled || $0 != .meta) }
        let operation = decisions.isEmpty ? .replaceTower : requested ?? operations[Int.random(in: operations.indices, using: &rng)]
        let active = executedDecisionIndices(evidence: evidence, study: study)
        func target(_ rng: inout SeededRNG) -> Int {
            let pool = !active.isEmpty && Int.random(in: 0..<4, using: &rng) != 0 ? active : Array(decisions.indices)
            return pool[Int.random(in: pool.indices, using: &rng)]
        }
        switch operation {
        case .replaceTower:
            let slot = !active.isEmpty && Int.random(in: 0..<4, using: &rng) != 0
                ? decisions[active[Int.random(in: active.indices, using: &rng)]].step.action.slot
                : Int.random(in: study.level.towerSlots.indices, using: &rng)
            let kinds = Array(Set(study.towerPaths.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
            let kind = kinds[Int.random(in: kinds.indices, using: &rng)]
            let paths = study.towerPaths.filter { $0.kind == kind }
            replace(slot: slot, path: paths[Int.random(in: paths.indices, using: &rng)], rng: &rng, pathCount: study.level.paths.count)
        case .swapSlots:
            let a = decisions[target(&rng)].step.action.slot
            let alternatives = study.level.towerSlots.indices.filter { $0 != a }
            guard !alternatives.isEmpty else { return }
            let b = alternatives[Int.random(in: alternatives.indices, using: &rng)]
            for index in decisions.indices {
                let action = decisions[index].step.action
                let old = action.slot, slot = old == a ? b : old == b ? a : old
                switch action {
                case let .build(_, id): decisions[index].step.action = .build(slot: slot, towerID: id)
                case .upgrade: decisions[index].step.action = .upgrade(slot: slot)
                case let .purchaseUpgrade(_, id): decisions[index].step.action = .purchaseUpgrade(slot: slot, pathID: id)
                }
            }
            for index in tactics.indices {
                tactics[index].slot = tactics[index].slot == a ? b : tactics[index].slot == b ? a : tactics[index].slot
            }
        case .movePurchase:
            let index = target(&rng)
            let decision = decisions.remove(at: index), slot = decision.step.action.slot
            let previous = decisions.indices.last(where: { $0 < index && decisions[$0].step.action.slot == slot })
            let next = decisions.indices.first(where: { $0 >= index && decisions[$0].step.action.slot == slot })
            decisions.insert(decision, at: Int.random(in: (previous.map { $0 + 1 } ?? 0)...(next ?? decisions.count), using: &rng))
        case .timing:
            let index = target(&rng)
            decisions[index].step.time = max(0, decisions[index].step.time + Double.random(in: -30...30, using: &rng))
        case .wave:
            let index = target(&rng)
            decisions[index].earliestWave = Int.random(in: 0...study.level.numWaves, using: &rng)
        case .saving:
            decisions[target(&rng)].saveForPurchase.toggle()
        case .truncate:
            let index = target(&rng), slot = decisions[index].step.action.slot
            decisions = decisions.enumerated().filter { $0.offset < index || $0.element.step.action.slot != slot }.map(\.element)
            if !decisions.contains(where: { $0.step.action.slot == slot }) { tactics.removeAll { $0.slot == slot } }
        case .meta:
            metaProgression = try metaFactory.mutate(metaProgression, using: &rng)
        case .reinforcements:
            reinforcements = .random(paths: study.level.paths, rng: &rng)
        case .earlyWaves:
            earlyWaves.mutate(waveCount: study.level.numWaves, rng: &rng)
        case .opening:
            // Move a coordinated group across a fitness valley; retain purchase
            // priorities and time/wave gates rather than burying replacements.
            var slots = Array(Set(evidence.flatMap { $0.placementPlan?.initial.map(\.slot) ?? [] })).sorted()
            if slots.isEmpty { slots = decisions.filter { $0.step.time == 0 && $0.earliestWave == 0 }.map { $0.step.action.slot } }
            slots = Array(Set(slots)).sorted(); slots.shuffle(using: &rng)
            guard !slots.isEmpty else { return }
            let kinds = Array(Set(study.towerPaths.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
            let kind = kinds[Int.random(in: kinds.indices, using: &rng)]
            let paths = study.towerPaths.filter { $0.kind == kind }
            let count = Int.random(in: min(2, slots.count)...slots.count, using: &rng)
            for slot in slots.prefix(count) { replace(slot: slot, path: paths[Int.random(in: paths.indices, using: &rng)], rng: &rng, pathCount: study.level.paths.count) }
        case .tactics:
            mutateTactics(study: study, rng: &rng)
        }
    }

    private mutating func replace(slot: Int, path: AuthoredMoneyStudy.TowerPath, rng: inout SeededRNG, pathCount: Int) {
        let previous = decisions.enumerated().filter { $0.element.step.action.slot == slot }
        let tiers = Int.random(in: 1...path.type.levels.count, using: &rng)
        var chain: [ScriptedBuildOrder.Action] = [.build(slot: slot, towerID: path.type.id)]
        for tier in 0..<tiers {
            if tier > 0 { chain.append(.upgrade(slot: slot)) }
            for upgrade in path.type.levels[tier].upgradePaths.sorted(by: { $0.slot < $1.slot }) {
                for _ in 0..<Int.random(in: 0...upgrade.ranks.count, using: &rng) {
                    chain.append(.purchaseUpgrade(slot: slot, pathID: upgrade.id))
                }
            }
        }
        // Reuse the old chain's global positions and triggers. Extra genes sit
        // after its last order. New slots may explore any purchase priority.
        var replacement: [Decision] = [], cursor = 0
        for decision in decisions {
            if decision.step.action.slot != slot { replacement.append(decision); continue }
            if cursor < chain.count {
                var next = decision; next.step.action = chain[cursor]
                replacement.append(next); cursor += 1
                if cursor == previous.count {
                    while cursor < chain.count {
                        var extra = decision; extra.step.action = chain[cursor]
                        replacement.append(extra); cursor += 1
                    }
                }
            }
        }
        if previous.isEmpty {
            let position = Int.random(in: 0...replacement.count, using: &rng)
            replacement.insert(contentsOf: chain.map { Decision(step: .init(time: 0, action: $0)) }, at: position)
        }
        decisions = replacement
        tactics.removeAll { $0.slot == slot && !path.type.levels.contains(where: $0.supported) }
        for kind in GeneticTacticalOrder.Kind.allCases {
            var order = GeneticTacticalOrder(slot: slot, kind: kind, pathIndex: 0, progress: 0)
            guard path.type.levels.contains(where: order.supported),
                  !tactics.contains(where: { $0.slot == slot && $0.kind == kind }) else { continue }
            order.pathIndex = Int.random(in: 0..<pathCount, using: &rng)
            order.progress = Double.random(in: 0...1, using: &rng)
            tactics.append(order)
        }
    }

}

/// A complete battle is the unit of fitness. Earlier wave performance is not
/// discounted or cashed out as a win, and leftover money cannot outweigh victory.
public struct GeneticEvaluation: Codable, Sendable, Equatable {
    public var runID: UUID? = nil
    /// Engine-observed final purchases. Nil identifies older recorded evidence.
    public var builtTowersByKind: [String: Int]? = nil
    /// Nil means legacy evidence did not capture placements, not an empty opening.
    public var placementPlan: GeneticPlacementPlan? = nil
    /// Nil is historical unknown, [] is an observed battle with no such commands.
    public var tacticalActions: [GeneticTacticalReceipt]? = nil
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
    private var initialPlacements: [GeneticPlacementPlan.Placement] = []
    private var subsequentPlacements: [GeneticPlacementPlan.Placement] = []
    private var placementTowerIDs: [UUID: UUID] = [:]
    private var observedPurchases: [GeneticPlaystyle.Purchase] = []
    private var observedTowers: [GeneticPlaystyle.Tower] = []
    private var observedPhases: Set<Int> = []
    private var spentBySlot: [Int: Int] = [:]
    private var demolitionActions = 0
    private var capturePlaystyle = true
    private var tactics: GeneticTacticalCommander
    // Player policy: after a needGold response, wait for a changed balance or a
    // successful purchase before trying again. Never calculate affordability.
    private var purchases = 0
    private var purchaseMoney: Int?
    private var purchaseWave: Int?
    private var nextPurchaseTime = -Double.infinity
    private var reinforcements: ReinforcementCommander
    private var earlyWaves: EarlyWaveCommander
    public init(_ strategy: GeneticStrategy) {
        pending = GeneticPurchaseCursor(strategy.decisions)
        expectedMetaUpgrades = strategy.metaProgression
        reinforcements = ReinforcementCommander(strategy.reinforcements)
        earlyWaves = EarlyWaveCommander(strategy.earlyWaves)
        tactics = GeneticTacticalCommander(strategy.tactics)
    }

    @MainActor public mutating func tick(sim: GameSimulation) throws {
        if !checkedMetaUpgrades {
            guard sim.content.playerUpgrades.loadout.selected == expectedMetaUpgrades.selected,
                  sim.content.playerUpgrades.loadout.spentStars == expectedMetaUpgrades.spentStars else {
                throw DbError.Db(message: "genetic commander: battle meta upgrades do not match candidate DNA")
            }
            for definition in sim.content.arsenal.towers {
                guard let base = definition.tiers.first(where: { $0.level == 1 && $0.branch == 1 }) else {
                    throw DbError.Db(message: "tower_type[\(definition.id)]: missing initial tower tier")
                }
                for tier in definition.tiers { placementTowerIDs[tier.id] = base.id }
            }
            checkedMetaUpgrades = true
        }
        if purchaseMoney != sim.gold || purchaseWave != sim.currentWave || sim.time >= nextPurchaseTime {
            let previousPurchases = purchases
            pending.beginTick()
            while let index = pending.pop() {
                let decision = pending.decisions[index]
                guard decision.step.time <= sim.time, decision.earliestWave <= sim.currentWave else { continue }
                let slot = pending.slots[index]
                let result: BuildResult
                let moneyBefore = sim.gold
                if let waiting = pending.waiting[slot], waiting.money == sim.gold, waiting.purchases == purchases {
                    // Reuse the engine's previous needGold response until money or
                    // a completed purchase changes. No price rule is duplicated.
                    if decision.saveForPurchase { break }
                    continue
                } else { result = sim.execute(decision.step.action) }
                switch result {
                case .ok:
                    if capturePlaystyle {
                        try observePurchase(decision.step.action, moneyBefore: moneyBefore, sim: sim)
                    }
                    if case let .build(slot, intendedID) = decision.step.action {
                        guard let baseID = placementTowerIDs[intendedID] else {
                            throw DbError.Db(message: "genetic placement: unknown tower \(intendedID)")
                        }
                        let placement = GeneticPlacementPlan.Placement(slot: slot, towerID: baseID)
                        if sim.currentWave == 0 { initialPlacements.append(placement) }
                        else if subsequentPlacements.count < 5 { subsequentPlacements.append(placement) }
                    }
                    pending.complete(index); purchases += 1
                case .needGold:
                    pending.waiting[slot] = (sim.gold, purchases)
                case .invalid:
                    throw DbError.Db(message: "Engine rejected genetic command: \(decision.step.action)")
                }
                if result == .needGold && decision.saveForPurchase { break }
            }
            // A later purchase may unblock an earlier order on the next tick,
            // even when its price was zero. Otherwise only observed money,
            // wave and time gates can change the pending commands' eligibility.
            purchaseMoney = sim.gold; purchaseWave = sim.currentWave
            nextPurchaseTime = purchases == previousPurchases ? pending.nextTime(after: sim.time) : -.infinity
        }
        if capturePlaystyle {
            let phase = sim.currentWave == 0 ? 0 : sim.currentWave >= (sim.content.level.numWaves * 2 + 2) / 3 ? 2
                : sim.currentWave >= (sim.content.level.numWaves + 2) / 3 ? 1 : -1
            if phase >= 0, observedPhases.insert(phase).inserted { try observeTowers(phase: phase, sim: sim) }
        }
        try tactics.tick(sim: sim, purchases: purchases)
        finishInputs(sim: sim)
        try reinforcements.tick(sim: sim)
        try earlyWaves.tick(sim: sim)
    }

    @MainActor private mutating func finishInputs(sim: GameSimulation) {
        for site in sim.readyDemolitionSites {
            if tactics.controlsDemolition(slot: site.slot) { continue }
            if sim.perform(.placeDemolition(slot: site.slot, point: site.point)) == .ok { demolitionActions += 1 }
        }
        if sim.currentWave == 0 { sim.startNextWave() }
    }

    @MainActor public static func evaluate(_ strategy: GeneticStrategy, recording: BattleRecording, content: BattleContent,
        money: Int, seed: UInt64, maxSeconds: Double, heroesEnabled: Bool = true,
        capturePlaystyle: Bool = true,
        towerObserver: (([BattleTowerSnapshot]) -> Void)? = nil) throws -> GeneticEvaluation {
        let selection = try strategy.playerState(in: content).loadout.selected
        try strategy.reinforcements.validate()
        try strategy.earlyWaves.validate(waveCount: content.level.numWaves)
        let battle = try content.selectingMetaUpgrades(selection)
        let sim = try GameSimulation(recording: recording, content: battle, startingMoney: money, heroesEnabled: heroesEnabled, seed: seed)
        var completed = false
        defer { if !completed { sim.finishRecording(status: .failed) } }
        var commander = Self(strategy), economy: [GeneticWaveEconomy] = []
        commander.capturePlaystyle = capturePlaystyle
        let startingLives = sim.lives
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
        evaluation.placementPlan = GeneticPlacementPlan(initial: commander.initialPlacements, subsequent: commander.subsequentPlacements)
        if capturePlaystyle {
            try commander.observeTowers(phase: 3, sim: sim)
            evaluation.placementPlan?.playstyle = GeneticPlaystyle(duration: sim.time, purchases: commander.observedPurchases,
                towers: commander.observedTowers, reinforcementActions: sim.reinforcementDeployments.count,
                earlyWaveActions: sim.waveCalls.filter { ($0.countdownSeconds ?? 0) > 0 }.count,
                demolitionActions: commander.demolitionActions + commander.tactics.receipts.filter { $0.kind == .demolition }.count, startingLives: startingLives,
                minimumLives: min(sim.lives, economy.map(\.lives).min() ?? startingLives))
        }
        evaluation.runID = sim.runID
        evaluation.tacticalActions = commander.tactics.receipts
        evaluation.builtTowersByKind = Dictionary(grouping: sim.towers, by: { $0.kind.rawValue }).mapValues(\.count)
        completed = true
        return evaluation
    }

    @MainActor private func identity(_ tower: BattleTowerSnapshot, sim: GameSimulation) throws -> (UUID, UUID) {
        guard let family = sim.content.arsenal.towers.first(where: { $0.kind == tower.kind }),
              let base = family.tiers.first(where: { $0.level == 1 && $0.branch == 1 }),
              let tier = family.tiers.first(where: { $0.level == tower.level && $0.branch == tower.branch }) else {
            throw DbError.Db(message: "genetic playstyle: missing authored tower identity at slot \(tower.slot)")
        }
        return (base.id, tier.id)
    }
    @MainActor private mutating func observePurchase(_ action: ScriptedBuildOrder.Action, moneyBefore: Int, sim: GameSimulation) throws {
        guard let tower = sim.towers.first(where: { $0.slot == action.slot }) else {
            throw DbError.Db(message: "genetic playstyle: successful purchase has no tower at slot \(action.slot)")
        }
        let ids = try identity(tower, sim: sim)
        let name: String, path: String?
        switch action {
        case .build: name = "build"; path = nil
        case .upgrade: name = "upgrade"; path = nil
        case let .purchaseUpgrade(_, id): name = "ability"; path = id
        }
        let cost = moneyBefore - sim.gold
        guard cost >= 0 else { throw DbError.Db(message: "genetic playstyle: negative observed purchase cost") }
        spentBySlot[action.slot, default: 0] += cost
        observedPurchases.append(.init(seconds: sim.time, wave: sim.currentWave, slot: action.slot,
            familyID: ids.0, tierID: ids.1, action: name, pathID: path, cost: cost))
    }
    @MainActor private mutating func observeTowers(phase: Int, sim: GameSimulation) throws {
        for tower in sim.towers {
            let ids = try identity(tower, sim: sim)
            let routes = sim.content.level.paths.enumerated().compactMap { index, path -> GeneticPlaystyle.Tower.Route? in
                let distance = path.nearestDistance(to: tower.position)
                let nearest = path.point(atDistance: distance)
                guard tower.tuning.attackRange.contains(CGPoint(x: nearest.x, y: nearest.y),
                    from: CGPoint(x: tower.position.x, y: tower.position.y)) else { return nil }
                return .init(index: index, progress: distance / max(0.001, path.totalLength))
            }
            observedTowers.append(.init(phase: phase, seconds: sim.time, slot: tower.slot, familyID: ids.0,
                tierID: ids.1, level: tower.level, branch: tower.branch, attackMode: tower.tuning.attackMode.rawValue,
                spent: spentBySlot[tower.slot, default: 0], damage: tower.damage, shots: tower.shots,
                blockingSeconds: tower.blockingSeconds, income: tower.income, detonations: tower.detonations, routes: routes))
            observedTowers[observedTowers.count - 1].slowingSeconds = tower.slowingSeconds
        }
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
    func nextTime(after time: Double) -> Double {
        var result = Double.infinity
        for head in heads where head >= 0 {
            let scheduled = decisions[head].step.time
            if scheduled > time { result = min(result, scheduled) }
        }
        return result
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
