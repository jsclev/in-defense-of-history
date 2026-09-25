import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticMetaPopulationTests: XCTestCase {
    private func sample(seed: UInt64 = 1, wins: Bool, lives: Int = 5) -> GeneticEvaluation {
        GeneticEvaluation(seed: seed, result: SimulationResult(outcome: wins ? .victory : .defeat, seconds: 600,
            livesRemaining: wins ? lives : 0, goldRemaining: 0, goldEarned: 0, killed: 10, leaked: 0,
            fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []), wavesStarted: 15,
            waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
    }
    private func candidate(_ id: Int, selection: [MetaUpgrade], wins: Bool) -> GeneticCandidate {
        GeneticCandidate(id: id, generation: 0, starsUsed: 1, strategy: GeneticStrategy(decisions: [], metaUpgrades: selection),
            evaluations: [sample(wins: wins)])
    }

    func testStrongSelectionCannotCrowdOutOtherSelectionsOrTakeAllFinalistSeats() throws {
        var group = try GeneticMetaPopulation(selections: [[.rangeEstimation], [.artificerCorps]], population: 8, minimumCandidates: 4)
        for id in 0..<20 { try group.record(candidate(id, selection: [.rangeEstimation], wins: true)) }
        for id in 20..<24 { try group.record(candidate(id, selection: [.artificerCorps], wins: false)) }
        XCTAssertEqual(group.activeSelections.map { $0.archive.count }, [4, 4])
        XCTAssertEqual(Set(group.finalists(limit: 8).map { $0.strategy.metaUpgrades }), Set([[.rangeEstimation], [.artificerCorps]]))
        XCTAssertEqual(group.finalists(limit: 8, distinctSelections: false).count, 8, "Explicit fixed-meta controls still compare multiple battle plans")
        try group.record(candidate(23, selection: [.artificerCorps], wins: false))
        XCTAssertEqual(group.selections[1].candidateIDs.count, 4, "Cache reuse must not invent additional search effort")
    }

    func testSelectionMustReceiveSeveralPlansAndAdaptationBeforeReplacement() throws {
        var group = try GeneticMetaPopulation(selections: [[.rangeEstimation], [.artificerCorps]], population: 8, minimumCandidates: 4)
        for id in 0..<4 { try group.record(candidate(id, selection: [.rangeEstimation], wins: true)) }
        try group.record(candidate(4, selection: [.artificerCorps], wins: false))
        XCTAssertNil(group.weakestReplaceable(generation: 20, adaptationGenerations: 2))
        XCTAssertEqual(group.finalists(limit: 8).count, 1, "One weak plan cannot qualify a meta selection")
        for id in 5..<8 { try group.record(candidate(id, selection: [.artificerCorps], wins: false)) }
        XCTAssertNil(group.weakestReplaceable(generation: 1, adaptationGenerations: 2))
        let weakest = try XCTUnwrap(group.weakestReplaceable(generation: 2, adaptationGenerations: 2))
        XCTAssertEqual(weakest.upgrades, [.artificerCorps])
        XCTAssertThrowsError(try group.replace(GeneticMetaSearch.key([.rangeEstimation]), with: [.localSuppliers], generation: 2, adaptationGenerations: 2))
        try group.replace(weakest.key, with: [.localSuppliers], generation: 2, adaptationGenerations: 2)
        XCTAssertEqual(group.activeSelections.count, 2)
        XCTAssertEqual(group.selections.count, 3)
        XCTAssertTrue(group.finalists(limit: 8).contains { $0.strategy.metaUpgrades == [.artificerCorps] }, "Retirement must not erase tested evidence")
        XCTAssertThrowsError(try group.record(candidate(9, selection: [.artificerCorps], wins: true)))
        XCTAssertThrowsError(try GeneticMetaPopulation(selections: [[.rangeEstimation], [.rangeEstimation]], population: 8, minimumCandidates: 4))
    }

    func testSmallExchangesUseOnlySharedLegalSelectionsAtExactlyTheSameStarsUsed() throws {
        let fixture = try AuthoredDatabaseFixture()
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let choices = try XCTUnwrap(GeneticMetaSearch(player: player).choicesByStars[5])
        let source = try XCTUnwrap(choices.first)
        let nearby = GeneticMetaSearch.nearestSelections(to: source, among: choices)
        XCTAssertFalse(nearby.isEmpty)
        let distances = choices.filter { $0 != source }.map { Set(source).symmetricDifference(Set($0)).count }
        for selection in nearby {
            XCTAssertEqual(Set(source).symmetricDifference(Set(selection)).count, distances.min())
            XCTAssertEqual(try player.selecting(Set(selection)).loadout.spentStars, 5)
        }
        XCTAssertEqual(GeneticMetaSearch.nearestSelections(to: [], among: [[]]), [])
    }

    func testInnerBattlePlanEvolutionPreservesItsMetaSelectionAndControlledTransferValidates() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        var strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: study.selectingMetaUpgrades([.rangeEstimation]), placementIndex: 7,
            upgradePolicyIndex: 2, seed: 1776), metaUpgrades: [.rangeEstimation])
        let original = strategy
        let changed = try original.selectingMetaUpgrades([.artificerCorps], in: study)
        XCTAssertEqual(changed.decisions, original.decisions)
        XCTAssertEqual(changed.reinforcements, original.reinforcements)
        XCTAssertEqual(changed.earlyWaves, original.earlyWaves)
        XCTAssertThrowsError(try original.selectingMetaUpgrades([.twoGoodVolleys], in: study))
        let choices = try XCTUnwrap(GeneticMetaSearch(player: study.battle.playerUpgrades).choicesByStars[1])
        var rng = SeededRNG(seed: 19)
        for _ in 0..<100 {
            strategy.mutate(study: study, metaChoices: choices, rng: &rng, metaMutationEnabled: false)
            XCTAssertEqual(strategy.metaUpgrades, [.rangeEstimation])
            XCTAssertNoThrow(try strategy.validate(study: study))
        }
    }

    func testPairedComparisonUsesMatchingSeedsAndReportsOpposingOutcomes() throws {
        let baseline = [sample(seed: 1, wins: true, lives: 2), sample(seed: 2, wins: false)]
        let alternative = [sample(seed: 2, wins: true, lives: 8), sample(seed: 1, wins: false)]
        let result = try GeneticPairedComparison(baseline: baseline, alternative: alternative)
        XCTAssertEqual(result.games, 2)
        XCTAssertEqual(result.baselineWins, 1); XCTAssertEqual(result.alternativeWins, 1)
        XCTAssertEqual(result.baselineOnlyWins, 1); XCTAssertEqual(result.alternativeOnlyWins, 1)
        XCTAssertEqual(result.meanLivesDifference, 3)
        XCTAssertThrowsError(try GeneticPairedComparison(baseline: baseline, alternative: [sample(seed: 3, wins: true)]))
        XCTAssertThrowsError(try GeneticPairedComparison(baseline: baseline, alternative: [alternative[0], alternative[0]]))
    }

    func testValidationCheckpointsGrowWithoutDuplicatingBattlesOrChangingCandidateDNA() throws {
        let fixture = try AuthoredDatabaseFixture(), dao = try MoneyStudyDAO(db: fixture.db)
        let run = try fixture.db.simulatorRunDao.begin(levelName: "Test", focus: "meta", totalIterations: 20, outputPath: ":memory:")
        try dao.begin(runID: run, configuration: "{\"algorithm\":\"genetic-v6\"}", contentSHA256: "test", plans: "{}")
        func row(panel: Int, samples: [GeneticEvaluation], selection: [MetaUpgrade] = [.rangeEstimation]) throws -> MoneyStudyResultRow {
            let candidate = GeneticCandidate(id: 1, generation: 0, starsUsed: 1,
                strategy: GeneticStrategy(decisions: [], metaUpgrades: selection), evaluations: samples)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            return MoneyStudyResultRow(money: 660, placementPlan: 1, upgradePolicy: panel, results: samples.map(\.result),
                evidenceJSON: String(decoding: try encoder.encode(candidate), as: UTF8.self))
        }
        let first = [sample(wins: true)], two = first + [sample(seed: 2, wins: false)]
        try dao.insert([row(panel: 0, samples: first)], runID: run, completed: 1, rate: 1)
        try dao.insert([row(panel: 1, samples: first)], runID: run, completed: 2, rate: 1, replacingValidation: true)
        try dao.insert([row(panel: 1, samples: two)], runID: run, completed: 3, rate: 1, replacingValidation: true)
        let summaries = try dao.geneticSummaryByStars(runID: run)
        XCTAssertEqual(summaries.compactMap { $0["engineGames"] as? Int }.reduce(0, +), 3)
        XCTAssertEqual(try fixture.db.simulatorRunDao.get(id: run)?.completedIterations, 3)
        XCTAssertThrowsError(try dao.insert([row(panel: 1, samples: first)], runID: run, completed: 2, rate: 1, replacingValidation: true))
        XCTAssertThrowsError(try dao.insert([row(panel: 1, samples: two, selection: [.artificerCorps])], runID: run, completed: 3, rate: 1, replacingValidation: true))
        let rewritten = [sample(wins: false), sample(seed: 2, wins: false), sample(seed: 3, wins: true)]
        XCTAssertThrowsError(try dao.insert([row(panel: 1, samples: rewritten)], runID: run, completed: 4, rate: 1, replacingValidation: true), "A growing panel must preserve every recorded seed and outcome")
        XCTAssertThrowsError(try dao.insert([row(panel: 0, samples: two)], runID: run, completed: 4, rate: 1, replacingValidation: true))
        XCTAssertEqual(try fixture.db.simulatorRunDao.get(id: run)?.completedIterations, 3)
    }
}
