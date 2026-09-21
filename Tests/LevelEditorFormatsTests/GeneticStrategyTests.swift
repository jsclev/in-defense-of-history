import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticStrategyTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func study(_ fixture: AuthoredDatabaseFixture) throws -> AuthoredMoneyStudy {
        try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
    }

    @MainActor func testAuthoredReplayIsUnchangedByGeneticDriver() throws {
        let fixture = try fixture(), study = try study(fixture)
        let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 1776)
        let old = try GameSimulation(content: study.battle, startingMoney: 500, heroesEnabled: false, seed: 1776)
        let expected = try old.run(steps: plan.steps, maxSeconds: 1800)
        let actual = try GeneticCommander.evaluate(GeneticStrategy(plan: plan, metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected)), content: study.battle,
            money: 500, seed: 1776, maxSeconds: 1800)
        // Balance edits may change the outcome of this old plan; they must
        // never make the two input drivers apply different engine behavior.
        XCTAssertNotEqual(actual.result.outcome, .timeout)
        XCTAssertEqual(actual.result, expected)
        XCTAssertEqual(actual.wavesStarted, old.currentWave)
        XCTAssertEqual(actual.waveEconomy.map(\.wave), Array(1...old.currentWave))
        XCTAssertEqual(actual.waveCalls, old.waveCalls)
        XCTAssertEqual(actual.reinforcementDeployments, old.reinforcementDeployments)
        let copy = try JSONDecoder().decode(GeneticStrategy.self, from: JSONEncoder().encode(GeneticStrategy(plan: plan, metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected))))
        XCTAssertEqual(copy, GeneticStrategy(plan: plan, metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected)))
    }

    @MainActor func testSavingDoesNotSpendReservedIncomeOnOtherSlots() throws {
        let fixture = try fixture(), study = try study(fixture)
        let path = try XCTUnwrap(study.towerPaths.first { $0.kind == .ranged })
        let probe = try GameSimulation(content: study.battle, startingMoney: 100_000, heroesEnabled: false, seed: 1)
        let cost = try XCTUnwrap(probe.buildOffers.first { $0.kind == path.kind }).cost
        XCTAssertEqual(probe.build(slot: 0, towerID: path.type.id), .ok)
        XCTAssertGreaterThan(try XCTUnwrap(probe.upgradeOffers(at: 0).first).cost, cost)
        for saving in [true, false] {
            let strategy = GeneticStrategy(decisions: [
                .init(step: .init(time: 0, action: .build(slot: 0, towerID: path.type.id))),
                .init(step: .init(time: 0, action: .upgrade(slot: 0)), saveForPurchase: saving),
                .init(step: .init(time: 0, action: .build(slot: 1, towerID: path.type.id)))], metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected))
            let sim = try GameSimulation(content: study.battle, startingMoney: cost * 2, heroesEnabled: false, seed: 1)
            var commander = GeneticCommander(strategy)
            try commander.tick(sim: sim)
            XCTAssertEqual(sim.towers.count, saving ? 1 : 2)
            XCTAssertEqual(sim.gold, saving ? cost : 0)
            XCTAssertEqual(sim.currentWave, 1, "Saving must not prevent the first wave from starting")
        }
    }

    @MainActor func testMutationAndCrossoverPreserveRealEnginePurchaseLegality() throws {
        let fixture = try fixture(), study = try study(fixture)
        var rng = SeededRNG(seed: 42)
        var a = GeneticStrategy(plan: try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 1776), metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected))
        var b = GeneticStrategy(plan: try MoneyStudyPlan(study: study, placementIndex: 12, upgradePolicyIndex: 6, seed: 1776), metaUpgrades: Array(study.battle.playerUpgrades.loadout.selected))
        let choices = try XCTUnwrap(GeneticMetaSearch(player: study.battle.playerUpgrades).choicesByStars[study.battle.playerUpgrades.loadout.spentStars])
        for iteration in 0..<160 {
            a.mutate(study: study, metaChoices: choices, rng: &rng)
            b = GeneticStrategy.crossover(a, b, slots: study.level.towerSlots.count, rng: &rng)
            try a.validate(study: study); try b.validate(study: study)
            var executable = iteration % 2 == 0 ? a : b
            for index in executable.decisions.indices {
                executable.decisions[index].step.time = 0
                executable.decisions[index].earliestWave = 0
            }
            let selectedContent = try study.battle.selectingMetaUpgrades(Set(executable.metaUpgrades))
            let sim = try GameSimulation(content: selectedContent, startingMoney: 1_000_000, heroesEnabled: false, seed: UInt64(iteration))
            var commander = GeneticCommander(executable)
            XCTAssertNoThrow(try commander.tick(sim: sim), "Mutation \(iteration) must remain legal in the actual engine")
        }
    }

    func testWholeLevelVictoryOutranksShortTermRewardAndLateDefeat() {
        func sample(_ outcome: Outcome, waves: Int, lives: Int, gold: Int, seconds: Double) -> GeneticEvaluation {
            GeneticEvaluation(seed: 1, result: SimulationResult(outcome: outcome, seconds: seconds,
                livesRemaining: lives, goldRemaining: gold, goldEarned: gold, killed: 1000,
                leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: []),
                wavesStarted: waves, waveEconomy: [], reinforcementDeployments: [], waveCalls: [])
        }
        let win = sample(.victory, waves: 15, lives: 1, gold: 0, seconds: 600)
        let early = sample(.defeat, waves: 2, lives: 0, gold: 100_000, seconds: 60)
        let late = sample(.defeat, waves: 15, lives: 0, gold: 100_000, seconds: 1000)
        let timeout = sample(.timeout, waves: 15, lives: 100, gold: 100_000, seconds: 1800)
        XCTAssertGreaterThan(GeneticFitness([win]), GeneticFitness([early]))
        XCTAssertGreaterThan(GeneticFitness([win]), GeneticFitness([late]))
        XCTAssertGreaterThan(GeneticFitness([win]), GeneticFitness([timeout]))
        XCTAssertGreaterThan(GeneticFitness([late]), GeneticFitness([early]))
    }

    @MainActor func testDatabasePriceEditsPropagateAndMissingTowerFails() throws {
        let fixture = try fixture(), original = try study(fixture)
        let path = try XCTUnwrap(original.towerPaths.first { $0.kind == .ranged })
        let genome = GeneticStrategy(decisions: [.init(step: .init(time: 0, action: .build(slot: 0, towerID: path.type.id)))], metaUpgrades: Array(original.battle.playerUpgrades.loadout.selected))
        let before = try GameSimulation(content: original.battle, startingMoney: 1000, heroesEnabled: false, seed: 1)
        var commander = GeneticCommander(genome); try commander.tick(sim: before)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE tower SET cost=cost+100 WHERE tower_level=1", nil, nil, nil), SQLITE_OK)
        let changed = try study(fixture)
        let after = try GameSimulation(content: changed.battle, startingMoney: 1000, heroesEnabled: false, seed: 1)
        commander = GeneticCommander(genome); try commander.tick(sim: after)
        XCTAssertLessThan(after.gold, before.gold)
        let quote = try XCTUnwrap(after.buildOffers.first { $0.kind == .ranged }).cost
        XCTAssertEqual(after.gold, 1000 - quote)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "DELETE FROM tower WHERE tower_level=1 AND attack_mode='direct'", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try study(fixture))
    }

    func testAdaptiveRecordsKeepRealCountsAndExplicitGenome() throws {
        let fixture = try fixture(), dao = try MoneyStudyDAO(db: fixture.db)
        let run = try fixture.db.simulatorRunDao.begin(levelName: "Test", focus: "genetic", totalIterations: 50000, outputPath: ":memory:")
        try dao.begin(runID: run, configuration: "{}", contentSHA256: "test", plans: "{\"candidates\":{}}")
        let result = SimulationResult(outcome: .timeout, seconds: 1, livesRemaining: 20, goldRemaining: 500,
            goldEarned: 0, killed: 0, leaked: 0, fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: [])
        try dao.insert([MoneyStudyResultRow(money: 500, placementPlan: 5, upgradePolicy: 0, results: [result],
            evidenceJSON: "{\"evaluations\":[{\"seed\":1776}],\"strategy\":{\"decisions\":[]}}")], runID: run, completed: 1, rate: 1)
        try dao.recordAdaptiveCheckpoint(runID: run, json: "[5]")
        XCTAssertThrowsError(try dao.finishAdaptive(runID: run, completed: 2, reportPath: "test.json"))
        try dao.finishAdaptive(runID: run, completed: 1, reportPath: "test.json")
        let stored = try XCTUnwrap(fixture.db.simulatorRunDao.get(id: run))
        XCTAssertEqual(stored.totalIterations, 1)
        XCTAssertEqual(stored.completedIterations, 1)
        XCTAssertEqual(stored.status, "completed")
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(fixture.connection,
            "SELECT json_extract(seed_results_json,'$.evaluations[0].seed') FROM money_study_result", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(stmt, 0), 1776)
    }
}
