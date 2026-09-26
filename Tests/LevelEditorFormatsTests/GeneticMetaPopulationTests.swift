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
    private func candidate(_ id: Int, selection: [MetaUpgrade], wins: Bool) throws -> GeneticCandidate {
        GeneticCandidate(id: id, generation: 0, strategy: GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(selection)),
            evaluations: [sample(wins: wins)])
    }

    func testStrongSelectionCannotCrowdOutOtherSelectionsOrTakeAllFinalistSeats() throws {
        var group = try GeneticMetaPopulation(selections: try [[MetaUpgrade.rangeEstimation], [.artificerCorps]].map(AuthoredDatabaseFixture.metaProgression), population: 8, minimumCandidates: 4)
        for id in 0..<20 { try group.record(candidate(id, selection: [.rangeEstimation], wins: true)) }
        for id in 20..<24 { try group.record(candidate(id, selection: [.artificerCorps], wins: false)) }
        XCTAssertEqual(group.activeSelections.map { $0.archive.count }, [4, 4])
        XCTAssertEqual(Set(group.finalists(limit: 8).map { $0.strategy.metaUpgrades }), Set([[.rangeEstimation], [.artificerCorps]]))
        XCTAssertEqual(group.finalists(limit: 8, distinctSelections: false).count, 8, "Explicit fixed-meta controls still compare multiple battle plans")
        try group.record(candidate(23, selection: [.artificerCorps], wins: false))
        XCTAssertEqual(group.selections[1].candidateIDs.count, 4, "Cache reuse must not invent additional search effort")
    }

    func testSelectionMustReceiveSeveralPlansAndAdaptationBeforeReplacement() throws {
        var group = try GeneticMetaPopulation(selections: try [[MetaUpgrade.rangeEstimation], [.artificerCorps]].map(AuthoredDatabaseFixture.metaProgression), population: 8, minimumCandidates: 4)
        for id in 0..<4 { try group.record(candidate(id, selection: [.rangeEstimation], wins: true)) }
        try group.record(candidate(4, selection: [.artificerCorps], wins: false))
        XCTAssertNil(group.weakestReplaceable(generation: 20, adaptationGenerations: 2))
        XCTAssertEqual(group.finalists(limit: 8).count, 1, "One weak plan cannot qualify a meta selection")
        for id in 5..<8 { try group.record(candidate(id, selection: [.artificerCorps], wins: false)) }
        XCTAssertNil(group.weakestReplaceable(generation: 1, adaptationGenerations: 2))
        let weakest = try XCTUnwrap(group.weakestReplaceable(generation: 2, adaptationGenerations: 2))
        XCTAssertEqual(weakest.upgrades.selected, [.artificerCorps])
        XCTAssertThrowsError(try group.replace(GeneticMetaSearch.key(try AuthoredDatabaseFixture.metaProgression([.rangeEstimation])), with: try AuthoredDatabaseFixture.metaProgression([.localSuppliers]), generation: 2, adaptationGenerations: 2))
        try group.replace(weakest.key, with: try AuthoredDatabaseFixture.metaProgression([.localSuppliers]), generation: 2, adaptationGenerations: 2)
        XCTAssertEqual(group.activeSelections.count, 2)
        XCTAssertEqual(group.selections.count, 3)
        XCTAssertTrue(group.finalists(limit: 8).contains { $0.strategy.metaUpgrades == [.artificerCorps] }, "Retirement must not erase tested evidence")
        XCTAssertThrowsError(try group.record(candidate(9, selection: [.artificerCorps], wins: true)))
        XCTAssertThrowsError(try GeneticMetaPopulation(selections: try [[MetaUpgrade.rangeEstimation], [.rangeEstimation]].map(AuthoredDatabaseFixture.metaProgression), population: 8, minimumCandidates: 4))
    }

    func testSmallExchangesUseOnlySharedLegalSelectionsAtExactlyTheSameStarsUsed() throws {
        let fixture = try AuthoredDatabaseFixture()
        let player = try fixture.db.playerMetaUpgradeDao.get()
        let choices = try XCTUnwrap(GeneticMetaSearch(player: player).choicesByStars[5])
        let source = try XCTUnwrap(choices.first)
        let nearby = GeneticMetaSearch.nearestSelections(to: source, among: choices)
        XCTAssertFalse(nearby.isEmpty)
        let distances = choices.filter { $0 != source }.map { source.selected.symmetricDifference($0.selected).count }
        for selection in nearby {
            XCTAssertEqual(source.selected.symmetricDifference(selection.selected).count, distances.min())
            XCTAssertEqual(try player.selecting(selection.selected).loadout.spentStars, 5)
        }
        XCTAssertEqual(GeneticMetaSearch.nearestSelections(to: try AuthoredDatabaseFixture.metaProgression([]), among: [try AuthoredDatabaseFixture.metaProgression([])]), [])
    }

    func testInnerBattlePlanEvolutionPreservesItsMetaSelectionAndControlledTransferValidates() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        var strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: study.selectingMetaUpgrades([.rangeEstimation]), placementIndex: 7,
            upgradePolicyIndex: 2, seed: 1776), metaProgression: try AuthoredDatabaseFixture.metaProgression([.rangeEstimation]))
        let original = strategy
        let changed = try original.selectingMetaUpgrades(try AuthoredDatabaseFixture.metaProgression([.artificerCorps]), in: study)
        XCTAssertEqual(changed.decisions, original.decisions)
        XCTAssertEqual(changed.reinforcements, original.reinforcements)
        XCTAssertEqual(changed.earlyWaves, original.earlyWaves)
        XCTAssertThrowsError(try original.selectingMetaUpgrades(try AuthoredDatabaseFixture.metaProgression([.twoGoodVolleys]), in: study))
        var rng = SeededRNG(seed: 19)
        for _ in 0..<100 {
            try strategy.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng, metaMutationEnabled: false)
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
        try dao.begin(runID: run, configuration: "{\"algorithm\":\"genetic-v8\"}", contentSHA256: "test", plans: "{}")
        func row(panel: Int, samples: [GeneticEvaluation], selection: [MetaUpgrade] = [.rangeEstimation]) throws -> MoneyStudyResultRow {
            let candidate = GeneticCandidate(id: 1, generation: 0, strategy: GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(selection)), evaluations: samples)
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

    func testCandidateIdentityAndPersistedCostComeFromChosenUpgrades() throws {
        let fixture = try AuthoredDatabaseFixture()
        let factory = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        var rng = SeededRNG(seed: 671)
        let first = try factory.make(stars: 1, using: &rng)
        let second = try factory.make(stars: 1, excluding: [first], using: &rng)
        let a = GeneticCandidate(id: 0, generation: 0,
            strategy: GeneticStrategy(decisions: [], metaProgression: first), evaluations: [sample(wins: true)])
        let b = GeneticCandidate(id: 1, generation: 0,
            strategy: GeneticStrategy(decisions: [], metaProgression: second), evaluations: [sample(wins: true)])
        XCTAssertEqual(a.starsUsed, b.starsUsed)
        XCTAssertNotEqual(a.metaUpgrades.rawValue, b.metaUpgrades.rawValue)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertNotEqual(try encoder.encode(a.strategy), try encoder.encode(b.strategy), "Cache keys must include the actual choices")
        let decoder = MetaUpgradesFactory.decoder(catalog: factory.catalog)
        let restored = try decoder.decode(GeneticCandidate.self, from: encoder.encode(a))
        XCTAssertEqual(restored.metaUpgrades, a.metaUpgrades)
        XCTAssertEqual(restored.strategy, a.strategy)
        XCTAssertEqual(restored.starsUsed, a.starsUsed)
        XCTAssertThrowsError(try JSONDecoder().decode(GeneticCandidate.self, from: encoder.encode(a)), "A DAO catalog is required")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(a)) as? [String: Any])
        json["starsUsed"] = a.starsUsed + 1
        XCTAssertThrowsError(try decoder.decode(GeneticCandidate.self, from: JSONSerialization.data(withJSONObject: json)))
        json["starsUsed"] = a.starsUsed
        var strategy = try XCTUnwrap(json["strategy"] as? [String: Any])
        strategy.removeValue(forKey: "metaUpgrades"); json["strategy"] = strategy
        XCTAssertThrowsError(try decoder.decode(GeneticCandidate.self, from: JSONSerialization.data(withJSONObject: json)), "Stars alone cannot recreate DNA")
        strategy["metaUpgrades"] = ["twoGoodVolleys"]; json["strategy"] = strategy
        XCTAssertThrowsError(try decoder.decode(GeneticCandidate.self, from: JSONSerialization.data(withJSONObject: json)))

        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE meta_upgrade SET star_cost=2*star_cost", nil, nil, nil), SQLITE_OK)
        let changed = try MetaUpgradesFactory(catalog: fixture.db.metaUpgradeDao.get())
        let updated = GeneticCandidate(id: 2, generation: 0,
            strategy: GeneticStrategy(decisions: [], metaProgression: try changed.make(selected: first.selected)),
            evaluations: [sample(wins: true)])
        XCTAssertEqual(updated.starsUsed, 2)
        XCTAssertThrowsError(try MetaUpgradesFactory.decoder(catalog: changed.catalog).decode(GeneticCandidate.self, from: encoder.encode(a)))
        var group = try GeneticMetaPopulation(selections: [first, second], population: 8, minimumCandidates: 4)
        XCTAssertThrowsError(try group.record(updated), "Equal bits from a different cost snapshot cannot enter the population")
        XCTAssertThrowsError(try GeneticMetaPopulation(selections: [first, factory.make(stars: 0)], population: 8, minimumCandidates: 4))
    }

    func testGAOperatorsVaryExplicitDNAAndPreserveAuthoredCostAndPrerequisites() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        let factory = try MetaUpgradesFactory(catalog: study.battle.playerUpgrades.loadout.catalog)
        let a = try factory.make(selected: [.rangeEstimation, .cartridgeDrill, .gunCarriages])
        let b = try factory.make(selected: [.campaignVeterans, .reliefCompanies, .localSuppliers])
        let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 45)
        let left = GeneticStrategy(plan: plan, metaProgression: a), right = GeneticStrategy(plan: plan, metaProgression: b)
        var mutant = left, rng = SeededRNG(seed: 119), sawNewChild = false, sawMutation = false
        for _ in 0..<120 {
            let child = try GeneticStrategy.crossover(left, right, slots: study.level.towerSlots.count, metaFactory: factory, rng: &rng)
            try child.validate(study: study)
            XCTAssertEqual(child.metaProgression.spentStars, 4)
            sawNewChild = sawNewChild || (child.metaProgression != a && child.metaProgression != b)
            try mutant.mutate(study: study, metaFactory: factory, rng: &rng)
            try mutant.validate(study: study)
            XCTAssertEqual(mutant.metaProgression.spentStars, 4)
            sawMutation = sawMutation || mutant.metaProgression != a
        }
        XCTAssertTrue(sawNewChild, "Crossover must combine explicit choices, rather than only pick a whole parent")
        XCTAssertTrue(sawMutation)
        XCTAssertEqual(left.metaProgression, a)
        XCTAssertEqual(right.metaProgression, b)
    }
}
