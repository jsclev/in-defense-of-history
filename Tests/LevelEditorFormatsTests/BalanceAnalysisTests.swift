import XCTest
import SQLite3
@testable import LevelEditorFormats

final class BalanceAnalysisTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func study(_ db: Db) throws -> AuthoredMoneyStudy {
        try AuthoredMoneyStudy(db: db, levelID: XCTUnwrap(db.levelInfoDao.getIdBy(levelName: "Charleston")))
    }
    private func sql(_ text: String, _ f: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(f.connection, text, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(f.connection)))
        }
    }

    func testDamageExperimentReloadsAuthoredValuesAndPreservesOtherContent() throws {
        let f = try fixture()
        try sql("UPDATE tower SET shot_min_damage=shot_min_damage+13,shot_max_damage=shot_max_damage+13 WHERE tower_type_id IN (SELECT id FROM tower_type WHERE tower_type_key='ranged')", f)
        let before = try study(f.db)
        let scenario = BalanceScenario(id: "damage", rangedDamageMultiplier: 0.75, replacementFraction: 0, enemyKeys: [])
        let copy = try BalanceExperimentDAO.contentCopy(of: f.db, levelID: before.level.id, scenario: scenario)
        defer { copy.close() }
        let after = try study(copy)
        for tower in before.arsenal.towers {
            let changed = try XCTUnwrap(after.arsenal.towers.first { $0.id == tower.id })
            for (a, b) in zip(tower.tiers, changed.tiers) {
                XCTAssertEqual(b.tuning.shotMinDamage, a.tuning.shotMinDamage * (tower.kind == .ranged ? 0.75 : 1), accuracy: 1e-9)
                XCTAssertEqual(b.tuning.shotMaxDamage, a.tuning.shotMaxDamage * (tower.kind == .ranged ? 0.75 : 1), accuracy: 1e-9)
                XCTAssertEqual(a.tuning.cost, b.tuning.cost)
                XCTAssertEqual(a.tuning.fireInterval, b.tuning.fireInterval)
            }
        }
        XCTAssertEqual(after.level.startingMoney, before.level.startingMoney)
        XCTAssertEqual(after.level.waves, before.level.waves)
        XCTAssertEqual(after.battle.enemies, before.battle.enemies)
        XCTAssertEqual(after.battle.playerUpgrades, before.battle.playerUpgrades)
        XCTAssertEqual(try study(f.db).arsenal.towers[0].tiers[0].tuning.shotMinDamage,
                       before.arsenal.towers[0].tiers[0].tuning.shotMinDamage)
    }

    func testWaveVariationPreservesEverySpawnTimeRouteAndCount() throws {
        let f = try fixture(), before = try study(f.db)
        let keys = ["hessian_jager", "light_dragoon", "regimental_drummer"]
        let scenario = BalanceScenario(id: "mix", rangedDamageMultiplier: 1, replacementFraction: 0.5, enemyKeys: keys)
        let copy = try BalanceExperimentDAO.contentCopy(of: f.db, levelID: before.level.id, scenario: scenario)
        defer { copy.close() }
        let after = try study(copy)
        func schedule(_ wave: Wave) -> [String] {
            wave.spawns.flatMap { spawn in
                (0..<spawn.count).map { String(format: "%.6f/%d", spawn.delay + Double($0) * spawn.interval, spawn.pathIndex) }
            }.sorted()
        }
        for (a, b) in zip(before.level.waves, after.level.waves) {
            XCTAssertEqual(schedule(a), schedule(b))
            XCTAssertEqual(a.startTime, b.startTime); XCTAssertEqual(a.callButtonDelay, b.callButtonDelay)
            XCTAssertEqual(a.autoStartCountdown, b.autoStartCountdown); XCTAssertEqual(a.earlyCallBonus, b.earlyCallBonus)
        }
        XCTAssertNotEqual(before.level.waves, after.level.waves)
        XCTAssertEqual(before.battle.enemies, after.battle.enemies)
        XCTAssertEqual(before.level.waves, try study(f.db).level.waves)
        let again = try BalanceExperimentDAO.contentCopy(of: f.db, levelID: before.level.id, scenario: scenario)
        defer { again.close() }
        XCTAssertEqual(after.level.waves, try study(again).level.waves)
    }

    func testInvalidContentAndUnknownExperimentValuesFail() throws {
        let f = try fixture(), before = try study(f.db)
        for scenario in [BalanceScenario(id: "bad", rangedDamageMultiplier: .nan, replacementFraction: 0, enemyKeys: []),
                         BalanceScenario(id: "bad", rangedDamageMultiplier: 1, replacementFraction: 0.5, enemyKeys: ["missing"]),
                         BalanceScenario(id: "../bad", rangedDamageMultiplier: 1, replacementFraction: 0, enemyKeys: [])] {
            XCTAssertThrowsError(try BalanceExperimentDAO.contentCopy(of: f.db, levelID: before.level.id, scenario: scenario))
        }
        try sql("UPDATE tower SET shot_min_damage='invalid' WHERE tower_type_id IN (SELECT id FROM tower_type WHERE tower_type_key='ranged')", f)
        XCTAssertThrowsError(try BalanceExperimentDAO.contentCopy(of: f.db, levelID: before.level.id, scenario: .baseline))
        let missing = try fixture()
        try sql("DELETE FROM tower WHERE tower_level=1 AND tower_type_id IN (SELECT id FROM tower_type WHERE tower_type_key='ranged')", missing)
        XCTAssertThrowsError(try BalanceExperimentDAO.contentCopy(of: missing.db, levelID: before.level.id, scenario: .baseline))
    }

    func testRestrictionSurvivesInitializationMutationCrossoverAndMetaSelection() throws {
        let f = try fixture(), original = try study(f.db)
        let maximum = try BalanceAnalysis.maximizingRanged(in: original)
        XCTAssertTrue(maximum.battle.playerUpgrades.loadout.selected.isSuperset(of:
            maximum.battle.playerUpgrades.loadout.catalog.upgrades(in: .marksmanship).map(\.id)))
        let ranged = try maximum.restrictingTowers(to: [.ranged])
        let upgrades = ranged.battle.playerUpgrades.loadout.selected.sorted { $0.rawValue < $1.rawValue }
        XCTAssertEqual(try ranged.selectingMetaUpgrades(Set(upgrades)).allowedTowerKinds, [.ranged])
        var rng = SeededRNG(seed: 15)
        var previous = GeneticStrategy(plan: try MoneyStudyPlan(study: ranged, placementIndex: 0, upgradePolicyIndex: 0, seed: 15), metaProgression: try AuthoredDatabaseFixture.metaProgression(upgrades))
        XCTAssertTrue(try BalanceComposition(strategy: previous, study: ranged).fillsEverySlot)
        for index in 0..<100 {
            var candidate = GeneticStrategy(plan: try MoneyStudyPlan(study: ranged, placementIndex: index, upgradePolicyIndex: index % 10, seed: 15), metaProgression: try AuthoredDatabaseFixture.metaProgression(upgrades))
            try candidate.mutate(study: ranged, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng, metaMutationEnabled: false)
            candidate = try GeneticStrategy.crossover(previous, candidate, slots: ranged.level.towerSlots.count, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng)
            try candidate.validate(study: ranged)
            XCTAssertTrue(try BalanceComposition(strategy: candidate, study: ranged).plannedSlotsByKind.keys.allSatisfy { $0 == "ranged" })
            previous = candidate
        }
        let mixed = GeneticStrategy(plan: try MoneyStudyPlan(study: maximum, placementIndex: 1, upgradePolicyIndex: 0, seed: 15), metaProgression: try AuthoredDatabaseFixture.metaProgression(upgrades))
        XCTAssertThrowsError(try mixed.validate(study: ranged))
        try sql("UPDATE player_meta_upgrade_selection SET is_selected=0; UPDATE player_meta_upgrade_level_stars SET best_stars=0", f)
        XCTAssertThrowsError(try BalanceAnalysis.maximizingRanged(in: study(f.db)))
    }

    @MainActor func testNoHeroEvaluationRecordsNoHeroesAndEngineTowerCounts() throws {
        let f = try fixture(), s = try BalanceAnalysis.maximizingRanged(in: study(f.db)).restrictingTowers(to: [.ranged])
        let strategy = GeneticStrategy(plan: try MoneyStudyPlan(study: s, placementIndex: 0, upgradePolicyIndex: 0, seed: 15),
            metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(s.battle.playerUpgrades.loadout.selected)))
        var towers: [BattleTowerSnapshot] = []
        let result = try GeneticCommander.evaluate(strategy, recording: .database(f.db.levelRunDao, .simulator),
            content: s.battle, money: s.level.startingMoney, seed: 15, maxSeconds: 1,
            heroesEnabled: false, towerObserver: { towers = $0 })
        let record = try f.db.levelRunDao.get(id: XCTUnwrap(result.runID))
        let setup = try LevelRecordingCodec.decode(LevelReplaySetup.self, from: record.setup)
        XCTAssertFalse(setup.heroesEnabled); XCTAssertEqual(setup.startingMoney, s.level.startingMoney)
        let replay = try LevelReplayer(dao: f.db.levelRunDao, runID: record.id)
        XCTAssertTrue(try replay.advance()); XCTAssertEqual(replay.frame?.heroes.count, 0)
        XCTAssertFalse(towers.isEmpty); XCTAssertTrue(towers.allSatisfy { $0.kind == .ranged })
    }

    func testVerdictCannotMistakeTimeoutOrTotalDifficultyForBalance() throws {
        let empty = try AuthoredDatabaseFixture.metaProgression([])
        func panel(_ outcome: Outcome, mixed: Bool = false) -> BalancePanel {
            let evaluation = GeneticEvaluation(seed: 1, result: SimulationResult(outcome: outcome, seconds: 10,
                livesRemaining: outcome == .victory ? 5 : 0, goldRemaining: 0, goldEarned: 0, killed: 0, leaked: 0,
                fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []), wavesStarted: 1,
                waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
            return BalancePanel(candidate: GeneticCandidate(id: 0, generation: 0, strategy: GeneticStrategy(decisions: [], metaProgression: empty), evaluations: [evaluation]),
                builtTowersBySeed: ["1": mixed ? ["ranged": 1, "melee": 1] : ["ranged": 2]])
        }
        func verdict(_ ranged: BalancePanel, _ mixed: BalancePanel, wins: Int = 0) -> String {
            BalanceAnalysis.verdict(baselineWon: true, trainingVictories: wins, ranged: [ranged], mixed: [mixed],
                                    expectedFinalists: 1, expectedSeeds: 1)
        }
        XCTAssertEqual(verdict(panel(.defeat), panel(.victory, mixed: true)), "candidate_for_deeper_validation")
        XCTAssertEqual(verdict(panel(.timeout), panel(.victory, mixed: true)), "inconclusive_incomplete_or_timeout")
        XCTAssertEqual(verdict(panel(.defeat), panel(.defeat)), "inconclusive_no_mixed_win")
        XCTAssertEqual(verdict(panel(.defeat), panel(.victory)), "inconclusive_no_mixed_win")
        XCTAssertEqual(verdict(panel(.defeat), panel(.victory, mixed: true), wins: 1), "ranged_exploit_survives")
        XCTAssertEqual(BalanceAnalysis.verdict(baselineWon: true, trainingVictories: 0,
            ranged: [panel(.defeat)], mixed: [panel(.victory, mixed: true)], expectedFinalists: 1, expectedSeeds: 1,
            frozen: [], expectedFrozen: 1), "inconclusive_incomplete_or_timeout")
        let comparison = BalanceComparison(baseline: panel(.victory).candidate.evaluations,
                                           variant: panel(.defeat).candidate.evaluations)
        XCTAssertEqual(comparison.pairedSeeds, 1); XCTAssertEqual(comparison.baselineOnlyWins, 1)
        XCTAssertEqual(comparison.meanLivesDelta, -5)
    }

    func testPreferredSeedsDoNotCrowdOutDistinctPlansWithDuplicateDNA() throws {
        let preferred = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([]))
        let alternative = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([.rangeEstimation]))
        let old = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression([.campaignVeterans]))
        XCTAssertEqual(try BalanceAnalysis.initialSeeds([preferred, preferred, alternative, old], limit: 2),
                       [preferred, alternative])
        XCTAssertEqual(try BalanceAnalysis.initialSeeds([preferred], limit: 0), [])
    }
}
