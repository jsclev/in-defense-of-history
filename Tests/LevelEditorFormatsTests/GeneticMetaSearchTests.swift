import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticMetaSearchTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func study(_ fixture: AuthoredDatabaseFixture) throws -> AuthoredMoneyStudy {
        try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
    }
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testZeroStarsAndAlternativeAllocationsRespectSharedPrerequisitesAndEarnedBudget() throws {
        let fixture = try fixture(), player = try fixture.db.playerMetaUpgradeDao.get()
        let search = try GeneticMetaSearch(player: player)
        XCTAssertEqual(search.earnedStars, 42)
        XCTAssertEqual(search.choicesByStars[0], [[]])
        XCTAssertTrue(try XCTUnwrap(search.choicesByStars[1]).contains([.rangeEstimation]))
        XCTAssertTrue(try XCTUnwrap(search.choicesByStars[1]).contains([.artificerCorps]))
        XCTAssertNil(search.choicesByStars[43])
        for (stars, choices) in search.choicesByStars {
            for selection in choices {
                let resolved = try player.selecting(Set(selection))
                XCTAssertEqual(resolved.loadout.spentStars, stars)
                XCTAssertEqual(resolved.loadout.availableStars, player.loadout.starBudget - stars)
            }
        }
        // Replay selected purchase sequences through the actual player DAO.
        for stars in [0, 1, 3, 20, 40, 42] {
            let selection = Set(try XCTUnwrap(search.choicesByStars[stars]?.first))
            try fixture.db.playerMetaUpgradeDao.reset()
            for upgrade in player.loadout.catalog.upgrades where selection.contains(upgrade.id) {
                XCTAssertTrue(try fixture.db.playerMetaUpgradeDao.purchase(upgrade.id))
            }
            XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get().loadout.selected, selection)
            XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get().loadout.spentStars, stars)
        }
    }

    func testDatabaseCostsLedgerAndMissingDefinitionsReachMetaSearch() throws {
        let fixture = try fixture()
        try execute("UPDATE meta_upgrade SET star_cost=2 WHERE upgrade_key='rangeEstimation'", fixture)
        var search = try GeneticMetaSearch(player: fixture.db.playerMetaUpgradeDao.get())
        XCTAssertFalse(try XCTUnwrap(search.choicesByStars[1]).contains([.rangeEstimation]))
        XCTAssertTrue(try XCTUnwrap(search.choicesByStars[2]).contains([.rangeEstimation]))
        try fixture.db.playerMetaUpgradeDao.reset()
        try execute("UPDATE player_meta_upgrade_level_stars SET best_stars=0 WHERE profile_key='active'", fixture)
        search = try GeneticMetaSearch(player: fixture.db.playerMetaUpgradeDao.get())
        XCTAssertEqual(search.earnedStars, 0)
        XCTAssertEqual(search.choicesByStars.count, 1)
        XCTAssertEqual(search.choicesByStars[0], [[]])
        try execute("DELETE FROM meta_upgrade WHERE upgrade_key='rangeEstimation'", fixture)
        XCTAssertThrowsError(try GeneticMetaSearch(player: fixture.db.playerMetaUpgradeDao.get()))
    }

    func testMetaGenesAreRequiredCanonicalAndValidateThroughPlayerState() throws {
        let fixture = try fixture(), study = try study(fixture)
        let a = GeneticStrategy(decisions: [], metaUpgrades: [.localSuppliers, .rangeEstimation])
        let b = GeneticStrategy(decisions: [], metaUpgrades: [.rangeEstimation, .localSuppliers])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(a), try encoder.encode(b))
        XCTAssertNotEqual(try encoder.encode(a), try encoder.encode(GeneticStrategy(decisions: [], metaUpgrades: [.artificerCorps, .localSuppliers])))
        XCTAssertEqual(try JSONDecoder().decode(GeneticStrategy.self, from: encoder.encode(a)), a)
        XCTAssertThrowsError(try JSONDecoder().decode(GeneticStrategy.self, from: Data("{\"decisions\":[]}".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(GeneticStrategy.self, from: Data("{\"decisions\":[],\"metaUpgrades\":[\"unknown\"]}".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(GeneticStrategy.self, from: Data("{\"decisions\":[],\"metaUpgrades\":[\"rangeEstimation\",\"rangeEstimation\"]}".utf8)))
        XCTAssertThrowsError(try GeneticStrategy(decisions: [], metaUpgrades: [.twoGoodVolleys]).validate(study: study))
        XCTAssertThrowsError(try GeneticStrategy(decisions: [], metaUpgrades: MetaUpgrade.allCases).validate(study: study))
        XCTAssertNoThrow(try GeneticStrategy(decisions: [], metaUpgrades: []).validate(study: study))
        XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get(), study.battle.playerUpgrades)
    }

    @MainActor func testEachCandidateUsesItsMetaGenesAndMatchesPlayerDAOPurchasesAndBattleHandlers() throws {
        let fixture = try fixture(), source = try study(fixture)
        let path = try XCTUnwrap(source.towerPaths.first { $0.kind == .ranged })
        for selection: [MetaUpgrade] in [[], [.rangeEstimation], [.artificerCorps], [.rangeEstimation, .cartridgeDrill]] {
            let strategy = GeneticStrategy(decisions: [.init(step: .init(time: 0, action: .build(slot: 0, towerID: path.type.id)))], metaUpgrades: selection)
            let before = try fixture.db.playerMetaUpgradeDao.get()
            let actual = try GeneticCommander.evaluate(strategy, recording: .preview, content: source.battle, money: 500, seed: 9001, maxSeconds: 10)
            XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get(), before, "Experiments must not mutate the player's saved progression")
            try fixture.db.playerMetaUpgradeDao.reset()
            for id in selection { XCTAssertTrue(try fixture.db.playerMetaUpgradeDao.purchase(id)) }
            let playerContent = try study(fixture).battle
            XCTAssertEqual(try source.battle.selectingMetaUpgrades(Set(selection)).playerUpgrades, playerContent.playerUpgrades)
            let player = try BattleEngine(recording: .preview, content: playerContent, heroesEnabled: true,
                startingMoneyOverride: 500, seed: 9001, onVictory: { _, _ in 0 })
            player.selectSlot(0); _ = player.tapBuildButton(.ranged); _ = player.tapBuildButton(.ranged)
            player.startNextWave()
            var deployments = ArraySlice(actual.reinforcementDeployments)
            for _ in 0..<300 {
                if let next = deployments.first, next.seconds == player.elapsedTime {
                    player.toggleReinforcementPlacement()
                    XCTAssertEqual(player.placeReinforcements(at: CGPoint(x: next.point.x, y: next.point.y)), .ok)
                    deployments.removeFirst()
                }
                player.advance(ticks: 1, interpolation: 0)
            }
            XCTAssertTrue(deployments.isEmpty)
            XCTAssertEqual(actual.result, player.simulationResult())
        }
        let range = try GameSimulation(recording: .preview, content: source.battle.selectingMetaUpgrades([.rangeEstimation]), startingMoney: 500, heroesEnabled: false, seed: 1)
        let discount = try GameSimulation(recording: .preview, content: source.battle.selectingMetaUpgrades([.artificerCorps]), startingMoney: 500, heroesEnabled: false, seed: 1)
        XCTAssertEqual(try source.battle.playerUpgrades.selecting([.rangeEstimation]).loadout.spentStars,
                       try source.battle.playerUpgrades.selecting([.artificerCorps]).loadout.spentStars)
        XCTAssertGreaterThan(try XCTUnwrap(range.buildOffers.first { $0.kind == .ranged }).cost,
                             try XCTUnwrap(discount.buildOffers.first { $0.kind == .ranged }).cost)
        var mismatched = GeneticCommander(GeneticStrategy(decisions: [], metaUpgrades: []))
        XCTAssertThrowsError(try mismatched.tick(sim: range))
    }

    func testDAOSeparatesExactStarSpendAndTrainingFromValidation() throws {
        let fixture = try fixture(), dao = try MoneyStudyDAO(db: fixture.db)
        let run = try fixture.db.simulatorRunDao.begin(levelName: "Test", focus: "meta", totalIterations: 5, outputPath: ":memory:")
        try dao.begin(runID: run, configuration: "{\"algorithm\":\"genetic-v3\"}", contentSHA256: "test", plans: "{}")
        let result = SimulationResult(outcome: .timeout, seconds: 1, livesRemaining: 20, goldRemaining: 500,
            goldEarned: 0, killed: 0, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: [])
        func row(id: Int, panel: Int, selection: [MetaUpgrade]) throws -> MoneyStudyResultRow {
            let state = try fixture.db.playerMetaUpgradeDao.get().selecting(Set(selection))
            let evidence: [String: Any] = ["starsUsed": state.loadout.spentStars,
                "strategy": ["metaUpgrades": selection.map(\.rawValue).sorted()]]
            return MoneyStudyResultRow(money: 500, placementPlan: id, upgradePolicy: panel, results: [result],
                evidenceJSON: String(decoding: try JSONSerialization.data(withJSONObject: evidence), as: UTF8.self))
        }
        try dao.insert([try row(id: 0, panel: 0, selection: []), try row(id: 1, panel: 0, selection: [.rangeEstimation]),
                        try row(id: 2, panel: 0, selection: [.artificerCorps]), try row(id: 1, panel: 1, selection: [.rangeEstimation])],
                       runID: run, completed: 4, rate: 1)
        let summary = try dao.geneticSummaryByStars(runID: run)
        XCTAssertEqual(summary.count, 3)
        let one = try XCTUnwrap(summary.first { $0["starsUsed"] as? Int == 1 && $0["panel"] as? Int == 0 })
        XCTAssertEqual(one["metaLoadoutsTested"] as? Int, 2)
        XCTAssertEqual(one["engineGames"] as? Int, 2)
        XCTAssertEqual(summary.first?["starsUsed"] as? Int, 0)
        try execute("UPDATE money_study_result SET seed_results_json=json_remove(seed_results_json,'$.starsUsed') WHERE placement_plan=0", fixture)
        XCTAssertThrowsError(try dao.geneticSummaryByStars(runID: run))
    }
}
