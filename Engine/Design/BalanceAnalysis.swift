import Foundation

/// Experiment inputs, not a second combat catalog. Multipliers apply to the
/// current DAO values; enemy keys must resolve in the authored roster.
public struct BalanceScenario: Codable, Equatable {
    public let id: String
    public let rangedDamageMultiplier: Double
    public let replacementFraction: Double
    public let enemyKeys: [String]

    public static let baseline = BalanceScenario(id: "baseline", rangedDamageMultiplier: 1,
                                                  replacementFraction: 0, enemyKeys: [])
    public init(id: String, rangedDamageMultiplier: Double, replacementFraction: Double, enemyKeys: [String]) {
        self.id = id; self.rangedDamageMultiplier = rangedDamageMultiplier
        self.replacementFraction = replacementFraction; self.enemyKeys = enemyKeys
    }
    public func validate() throws {
        guard !id.isEmpty, id.count <= 80,
              id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              rangedDamageMultiplier.isFinite, rangedDamageMultiplier > 0, rangedDamageMultiplier <= 2,
              replacementFraction.isFinite, (0...1).contains(replacementFraction),
              (replacementFraction == 0) == enemyKeys.isEmpty,
              Set(enemyKeys).count == enemyKeys.count else {
            throw DbError.Db(message: "balance scenario[\(id)]: invalid multiplier, replacement fraction or enemy keys")
        }
    }
}

public struct BalanceComposition: Codable, Equatable {
    public let plannedSlotsByKind: [String: Int]
    public let availableSlots: Int
    public var singleKind: String? { plannedSlotsByKind.count == 1 ? plannedSlotsByKind.keys.first : nil }
    public var fillsEverySlot: Bool { plannedSlotsByKind.values.reduce(0, +) == availableSlots }

    public init(strategy: GeneticStrategy, study: AuthoredMoneyStudy) throws {
        var slots: Set<Int> = [], counts: [String: Int] = [:]
        for decision in strategy.decisions {
            if case let .build(slot, id) = decision.step.action {
                guard study.level.towerSlots.indices.contains(slot), slots.insert(slot).inserted,
                      let path = study.towerPaths.first(where: { $0.type.id == id }) else {
                    throw DbError.Db(message: "balance composition: unknown tower \(id) or duplicate/invalid slot \(slot)")
                }
                counts[path.kind.rawValue, default: 0] += 1
            }
        }
        plannedSlotsByKind = counts; availableSlots = study.level.towerSlots.count
    }
}

public struct BalancePanel: Codable {
    public let candidate: GeneticCandidate
    /// Read from the engine after each battle, not inferred from purchase DNA.
    public let builtTowersBySeed: [String: [String: Int]]
    public let summary: Summary
    public struct Summary: Codable {
        public let samples: Int
        public let victories: Int
        public let defeats: Int
        public let timeouts: Int
        public let mixedVictories: Int
        public let winRate: Double
        public let meanLives: Double
    }
    public init(candidate: GeneticCandidate, builtTowersBySeed: [String: [String: Int]]) {
        self.candidate = candidate; self.builtTowersBySeed = builtTowersBySeed
        let values = candidate.evaluations
        summary = Summary(samples: values.count, victories: values.filter { $0.result.outcome == .victory }.count,
            defeats: values.filter { $0.result.outcome == .defeat }.count,
            timeouts: values.filter { $0.result.outcome == .timeout }.count,
            mixedVictories: values.filter { $0.result.outcome == .victory && (builtTowersBySeed[String($0.seed)]?.count ?? 0) > 1 }.count,
            winRate: candidate.fitness.winRate,
            meanLives: values.reduce(0) { $0 + Double($1.result.livesRemaining) } / Double(values.count))
    }
    public var victories: Int { candidate.evaluations.filter { $0.result.outcome == .victory }.count }
    public var timeouts: Int { candidate.evaluations.filter { $0.result.outcome == .timeout }.count }
    public var mixedVictories: Int {
        candidate.evaluations.filter {
            $0.result.outcome == .victory && (builtTowersBySeed[String($0.seed)]?.count ?? 0) > 1
        }.count
    }
}

public struct BalanceComparison: Codable {
    public let pairedSeeds: Int
    public let baselineOnlyWins: Int
    public let variantOnlyWins: Int
    public let meanLivesDelta: Double?
    public init(baseline: [GeneticEvaluation], variant: [GeneticEvaluation]) {
        let originals = Dictionary(uniqueKeysWithValues: baseline.map { ($0.seed, $0) })
        let pairs = variant.compactMap { value in originals[value.seed].map { ($0, value) } }
        pairedSeeds = pairs.count
        baselineOnlyWins = pairs.filter { $0.0.result.outcome == .victory && $0.1.result.outcome != .victory }.count
        variantOnlyWins = pairs.filter { $0.0.result.outcome != .victory && $0.1.result.outcome == .victory }.count
        meanLivesDelta = pairs.isEmpty ? nil : pairs.reduce(0) {
            $0 + Double($1.1.result.livesRemaining - $1.0.result.livesRemaining)
        } / Double(pairs.count)
    }
}

public enum BalanceAnalysis {
    /// Retain preferred plans first without spending multiple seed seats on
    /// identical DNA from historical, training and validation records.
    public static func initialSeeds(_ strategies: [GeneticStrategy], limit: Int) throws -> [GeneticStrategy] {
        guard limit >= 0 else { throw DbError.Db(message: "balance search: negative seed capacity") }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var seen: Set<Data> = [], result: [GeneticStrategy] = []
        for strategy in strategies {
            if result.count == limit { break }
            if try seen.insert(encoder.encode(strategy)).inserted { result.append(strategy) }
        }
        return result
    }

    /// Preserve all other selected upgrades. Never invent stars or silently
    /// remove another track to make the maximized ranged selection affordable.
    public static func maximizingRanged(in study: AuthoredMoneyStudy) throws -> AuthoredMoneyStudy {
        let current = study.battle.playerUpgrades.loadout
        let ranged = current.catalog.upgrades(in: .marksmanship)
        guard !ranged.isEmpty else { throw DbError.Db(message: "meta_upgrade: missing marksmanship track") }
        return try study.selectingMetaUpgrades(current.selected.union(ranged.map(\.id)))
    }

    public static func verdict(baselineWon: Bool, trainingVictories: Int, ranged: [BalancePanel],
                               mixed: [BalancePanel], expectedFinalists: Int, expectedSeeds: Int,
                               frozen: [BalancePanel] = [], expectedFrozen: Int = 0) -> String {
        guard baselineWon else { return "baseline_not_established" }
        if trainingVictories > 0 || (ranged + frozen).contains(where: { $0.victories > 0 }) { return "ranged_exploit_survives" }
        guard ranged.count == expectedFinalists,
              ranged.allSatisfy({ $0.candidate.evaluations.count == expectedSeeds && $0.timeouts == 0 }),
              mixed.count == expectedFinalists,
              mixed.allSatisfy({ $0.candidate.evaluations.count == expectedSeeds && $0.timeouts == 0 }),
              frozen.count == expectedFrozen,
              frozen.allSatisfy({ $0.candidate.evaluations.count == expectedSeeds && $0.timeouts == 0 }) else {
            return "inconclusive_incomplete_or_timeout"
        }
        return mixed.contains(where: { $0.mixedVictories > 0 })
            ? "candidate_for_deeper_validation" : "inconclusive_no_mixed_win"
    }
}
