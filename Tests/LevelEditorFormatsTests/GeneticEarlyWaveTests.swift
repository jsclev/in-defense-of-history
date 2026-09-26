import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticEarlyWaveTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    @MainActor func testEarlyCallsMatchPhoneConfirmationAndCatchUpTicksWithLiveEnemies() throws {
        let fixture = try fixture()
        try execute("UPDATE level_wave SET call_button_delay=0.6,auto_start_countdown=0.5,early_call_bonus=19", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 660, heroesEnabled: false, seed: 1776)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 660, seed: 1776, onVictory: { _, _ in 0 })
        let policy = EarlyWaveStrategy(decisions: [
            .init(wave: 2, policy: .afterVisible(seconds: 0.1)),
            .init(wave: 4, policy: .whenEnemiesAtMost(count: 100, holdSeconds: 0))])
        var commander = GeneticCommander(GeneticStrategy(decisions: [],
            metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(content.playerUpgrades.loadout.selected)), earlyWaves: policy))
        var selection = CallWaveButtonSelection(), sawOverlap = false
        for _ in 0..<130 {
            let previousCalls = sim.waveCalls.count, previousDeployments = sim.reinforcementDeployments.count
            try commander.tick(sim: sim)
            // Purchases/first wave precede reinforcements; later calls follow them.
            func callLikePhone() throws {
                XCTAssertTrue(player.awaitingWaveStart)
                let point = try XCTUnwrap(player.callWaveButtonPositions.first)
                XCTAssertFalse(selection.tap(point, for: player.nextWaveNumber))
                XCTAssertTrue(selection.tap(point, for: player.nextWaveNumber))
                XCTAssertEqual(player.startNextWave(), .ok)
            }
            let calls = sim.waveCalls.dropFirst(previousCalls)
            for call in calls where call.wave == 1 { try callLikePhone() }
            for deployment in sim.reinforcementDeployments.dropFirst(previousDeployments) {
                player.toggleReinforcementPlacement()
                XCTAssertEqual(player.placeReinforcements(at: CGPoint(x: deployment.point.x, y: deployment.point.y)), .ok)
            }
            for call in calls where call.wave > 1 {
                sawOverlap = sawOverlap || !player.walkers.isEmpty
                try callLikePhone()
                XCTAssertEqual(call.earlyCallBonus, 19)
            }
            // Driver idle ticks exercise the same catch-up batch as the phone.
            sim.step(); sim.step()
            player.advance(ticks: 0, interpolation: 0.4)
            player.advance(ticks: 2, interpolation: 0.25)
            XCTAssertEqual(sim.result(), player.simulationResult())
            XCTAssertEqual(sim.waveCalls, player.waveCallReceipts)
            XCTAssertEqual(sim.canStartWave, player.awaitingWaveStart)
        }
        XCTAssertEqual(sim.waveCalls.map(\.wave), [1, 2, 4])
        XCTAssertEqual(sim.waveCalls.first?.earlyCallBonus, 0)
        XCTAssertTrue(sawOverlap)
        XCTAssertTrue(sim.engine.heroPosts.isEmpty && player.heroPosts.isEmpty)
        XCTAssertEqual(sim.engine.militia.map(\.position), player.militia.map(\.position))
    }

    @MainActor func testDatabaseTimingAndRewardsPropagateAndMissingWaveFails() throws {
        let fixture = try fixture()
        try execute("UPDATE level_wave SET call_button_delay=0.4,auto_start_countdown=0.8,early_call_bonus=23", fixture)
        let first = try BattleTestFixture.authored(db: fixture.db)
        let strategy = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(first.playerUpgrades.loadout.selected)),
            earlyWaves: .init(decisions: [.init(wave: 2, policy: .afterVisible(seconds: 0.1))]))
        let before = try GeneticCommander.evaluate(strategy, recording: .preview, content: first, money: 660, seed: 1776, maxSeconds: 1)
        let firstCall = try XCTUnwrap(before.waveCalls.first { $0.wave == 2 })
        XCTAssertEqual(firstCall.earlyCallBonus, 23)
        try execute("UPDATE level_wave SET call_button_delay=0.7,early_call_bonus=41", fixture)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        let after = try GeneticCommander.evaluate(strategy, recording: .preview, content: changed, money: 660, seed: 1776, maxSeconds: 1.1)
        let secondCall = try XCTUnwrap(after.waveCalls.first { $0.wave == 2 })
        XCTAssertEqual(secondCall.earlyCallBonus, 41)
        XCTAssertGreaterThan(secondCall.seconds, firstCall.seconds)
        let copy = try AuthoredDatabaseFixture.metaDecoder.decode(GeneticStrategy.self, from: JSONEncoder().encode(strategy))
        XCTAssertEqual(after, try GeneticCommander.evaluate(copy, recording: .preview, content: changed, money: 660, seed: 1776, maxSeconds: 1.1))
        // Deletion is only in this disposable fixture; the DAO must reject it.
        try execute("PRAGMA foreign_keys=OFF; DELETE FROM level_wave WHERE level_info_id='\(changed.level.id.uuidString.lowercased())' AND wave_index=2", fixture)
        XCTAssertThrowsError(try BattleTestFixture.authored(db: fixture.db))
    }

    @MainActor func testAutomaticAndMissedCallWindowsAwardNoManualBonus() throws {
        let fixture = try fixture()
        try execute("UPDATE level_wave SET call_button_delay=0.2,auto_start_countdown=0.3,early_call_bonus=23", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let meta = Array(content.playerUpgrades.loadout.selected)
        for policy in [EarlyWaveStrategy.automatic,
                       .init(decisions: [.init(wave: 2, policy: .afterVisible(seconds: 5))]),
                       .init(decisions: [.init(wave: 2, policy: .whenEnemiesAtMost(count: 0, holdSeconds: 0))])] {
            let result = try GeneticCommander.evaluate(GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(meta),
                earlyWaves: policy), recording: .preview, content: content, money: 660, seed: 1776, maxSeconds: 1.2)
            XCTAssertEqual(result.waveCalls.map(\.wave), [1])
            XCTAssertEqual(result.waveCalls[0].earlyCallBonus, 0)
            XCTAssertGreaterThanOrEqual(result.wavesStarted, 3)
        }
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 660, heroesEnabled: false, seed: 1)
        XCTAssertEqual(sim.perform(.startWave), .ok)
        let money = sim.gold
        XCTAssertEqual(sim.perform(.startWave), .invalid)
        XCTAssertEqual(sim.waveCalls.count, 1)
        XCTAssertEqual(sim.gold, money)
    }

    @MainActor func testLateCallUsesVisibleEngineCountdownAndChangedTiming() throws {
        let fixture = try fixture()
        try execute("UPDATE level_wave SET call_button_delay=0.2,auto_start_countdown=3.4,early_call_bonus=31", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let strategy = GeneticStrategy(decisions: [], metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(content.playerUpgrades.loadout.selected)),
            earlyWaves: .init(decisions: [.init(wave: 2, policy: .whenCountdownAtMost(seconds: 1))]))
        let before = try GeneticCommander.evaluate(strategy, recording: .preview, content: content, money: 660, seed: 1776, maxSeconds: 4)
        let call = try XCTUnwrap(before.waveCalls.first { $0.wave == 2 })
        XCTAssertEqual(call.countdownSeconds, 1)
        XCTAssertEqual(call.earlyCallBonus, 31)
        try execute("UPDATE level_wave SET auto_start_countdown=0.6", fixture)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        let after = try GeneticCommander.evaluate(strategy, recording: .preview, content: changed, money: 660, seed: 1776, maxSeconds: 1)
        let earlier = try XCTUnwrap(after.waveCalls.first { $0.wave == 2 })
        XCTAssertEqual(earlier.countdownSeconds, 1)
        XCTAssertEqual(earlier.earlyCallBonus, 31)
        XCTAssertLessThan(earlier.seconds, call.seconds)
    }

    func testEarlyCallGenesAreRequiredValidatedAndEvolvedPerWave() throws {
        let fixture = try fixture(), content = try BattleTestFixture.authored(db: fixture.db)
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: content.level.id)
        let meta = Array(content.playerUpgrades.loadout.selected)
        let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 1776)
        let a = GeneticStrategy(plan: plan, metaProgression: try AuthoredDatabaseFixture.metaProgression(meta))
        let b = GeneticStrategy(plan: plan, metaProgression: try AuthoredDatabaseFixture.metaProgression(meta),
            earlyWaves: .init(decisions: [.init(wave: 2, policy: .afterVisible(seconds: 0)),
                                        .init(wave: 3, policy: .whenEnemiesAtMost(count: 2, holdSeconds: 3))]))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertNotEqual(try encoder.encode(a), try encoder.encode(b))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(a)) as? [String: Any])
        json.removeValue(forKey: "earlyWaves")
        XCTAssertThrowsError(try AuthoredDatabaseFixture.metaDecoder.decode(GeneticStrategy.self, from: JSONSerialization.data(withJSONObject: json)))
        var rng = SeededRNG(seed: 100), mutant = a, sawEarly = false, sawAutomatic = false
        for _ in 0..<120 {
            let child = try GeneticStrategy.crossover(a, b, slots: study.level.towerSlots.count, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng)
            try child.validate(study: study)
            sawEarly = sawEarly || child.earlyWaves.policy(for: 2) == b.earlyWaves.policy(for: 2)
            sawAutomatic = sawAutomatic || child.earlyWaves.policy(for: 2) == .automatic
            try mutant.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng)
        }
        XCTAssertTrue(sawEarly && sawAutomatic)
        XCTAssertNotEqual(mutant.earlyWaves, .automatic)
        mutant = a
        for _ in 0..<120 { try mutant.mutate(study: study, metaFactory: AuthoredDatabaseFixture.metaUpgradesFactory, rng: &rng, earlyWaveCallsEnabled: false) }
        XCTAssertEqual(mutant.earlyWaves, .automatic)
        for policy in [EarlyWaveStrategy.Policy.afterVisible(seconds: -1), .afterVisible(seconds: .infinity),
                       .whenEnemiesAtMost(count: -1, holdSeconds: 0)] {
            XCTAssertThrowsError(try EarlyWaveStrategy(decisions: [.init(wave: 2, policy: policy)]).validate(waveCount: 15))
        }
        XCTAssertThrowsError(try EarlyWaveStrategy(decisions: [.init(wave: 1, policy: .automatic)]).validate(waveCount: 15))
        XCTAssertThrowsError(try EarlyWaveStrategy(decisions: [.init(wave: 2, policy: .automatic), .init(wave: 2, policy: .automatic)]).validate(waveCount: 15))
    }

    @MainActor func testSavingForTowerDoesNotBlockWaveCallsAndDAOKeepsV5Evidence() throws {
        let fixture = try fixture()
        try execute("UPDATE level_wave SET call_button_delay=0.2,auto_start_countdown=1,early_call_bonus=29", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: content.level.id)
        let tower = try XCTUnwrap(study.towerPaths.first)
        let strategy = GeneticStrategy(decisions: [.init(step: .init(time: 0, action: .build(slot: 0, towerID: tower.type.id)), saveForPurchase: true)],
            metaProgression: try AuthoredDatabaseFixture.metaProgression(Array(content.playerUpgrades.loadout.selected)),
            earlyWaves: .init(decisions: [.init(wave: 2, policy: .afterVisible(seconds: 0))]))
        let evaluation = try GeneticCommander.evaluate(strategy, recording: .preview, content: content, money: 1, seed: 1776, maxSeconds: 0.5)
        XCTAssertEqual(evaluation.waveCalls.map(\.wave), [1, 2])
        let dao = try MoneyStudyDAO(db: fixture.db)
        let run = try fixture.db.simulatorRunDao.begin(levelName: "Test", focus: "early calls", totalIterations: 1, outputPath: ":memory:")
        try dao.begin(runID: run, configuration: "{\"algorithm\":\"genetic-v5\"}", contentSHA256: "test", plans: "{}")
        let encoder = JSONEncoder()
        let evidence: [String: Any] = ["starsUsed": content.playerUpgrades.loadout.spentStars,
            "strategy": try JSONSerialization.jsonObject(with: encoder.encode(strategy)),
            "evaluations": [try JSONSerialization.jsonObject(with: encoder.encode(evaluation))]]
        try dao.insert([MoneyStudyResultRow(money: 1, placementPlan: 0, upgradePolicy: 0, results: [evaluation.result],
            evidenceJSON: String(decoding: try JSONSerialization.data(withJSONObject: evidence), as: UTF8.self))], runID: run, completed: 1, rate: 1)
        XCTAssertEqual(try dao.geneticSummaryByStars(runID: run).first?["engineGames"] as? Int, 1)
    }
}
