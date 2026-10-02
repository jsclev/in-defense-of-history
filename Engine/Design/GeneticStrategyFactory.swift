import Foundation

/// Independent draws for each search dimension. Generation/offspring indices
/// schedule births only; they never determine a placement heuristic or family.
public enum GeneticStrategyFactory {
    public static func make(study: AuthoredMoneyStudy, selection: MetaUpgradeProgression,
                            towerLimits: GeneticTowerLimits = .init(), earlyWaveCalls: Bool,
                            rng: inout SeededRNG) throws -> GeneticStrategy {
        let kinds = Array(Set(study.towerPaths.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
        let family = Int.random(in: 0...kinds.count, using: &rng)
        let placement = Int.random(in: 0..<4, using: &rng)
        let policy = Int.random(in: 0..<10, using: &rng)
        let opening = Int.random(in: 1...study.level.towerSlots.count, using: &rng)
        let cadence = Int.random(in: 0...5, using: &rng)
        let delays = [0.0, 0.5, 5.0, 15.0]
        let delay = delays[Int.random(in: delays.indices, using: &rng)]
        let plan = try MoneyStudyPlan(study: study, placementIndex: placement, upgradePolicyIndex: policy,
            seed: rng.next(), towerLimits: towerLimits, openingKind: family < kinds.count ? kinds[family] : nil,
            openingCount: opening, upgradesPerBuild: cadence, decisionDelay: delay, partialInvestments: true)
        var strategy = GeneticStrategy(plan: plan, metaProgression: selection,
            reinforcements: Bool.random(using: &rng) ? .immediate : .random(paths: study.level.paths, rng: &rng),
            earlyWaves: earlyWaveCalls ? .random(waveCount: study.level.numWaves, rng: &rng) : .automatic)
        let reserve = Bool.random(using: &rng)
        for index in strategy.decisions.indices { strategy.decisions[index].saveForPurchase = reserve }
        strategy.randomizeTactics(study: study, rng: &rng)
        return strategy
    }
}
