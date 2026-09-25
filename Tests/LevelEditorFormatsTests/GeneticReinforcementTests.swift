import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GeneticReinforcementTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    @MainActor func testGeneticCallsMatchPhoneHandlersIncludingRecoveryExpiryAndNoHeroes() throws {
        let fixture = try fixture()
        try execute("UPDATE reinforcement_config SET cooldown_seconds=1.7,time_to_live_seconds=3.1", fixture)
        try execute("UPDATE combat_rules SET reinforcement_soldier_count=4", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 500, heroesEnabled: false, seed: 1776)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 500, seed: 1776, onVictory: { _, _ in 0 })
        let strategy = GeneticStrategy(decisions: [], metaUpgrades: Array(content.playerUpgrades.loadout.selected),
            reinforcements: .init(priority: .nearestExit, holdSeconds: 0.3))
        var commander = GeneticCommander(strategy)
        player.startNextWave()
        var sawExpiry = false, previousSlots = Set<Int>()
        for _ in 0..<1050 {
            let count = sim.reinforcementDeployments.count
            try commander.tick(sim: sim)
            if let deployment = sim.reinforcementDeployments.dropFirst(count).first {
                XCTAssertTrue(player.canCallReinforcements)
                player.toggleReinforcementPlacement()
                XCTAssertEqual(player.placeReinforcements(at: CGPoint(x: deployment.point.x, y: deployment.point.y)), .ok)
                XCTAssertEqual(sim.engine.garrisonsBySlot[sim.engine.nextReinforcementSlot + 1]?.units.count, 4)
            }
            sim.step()
            player.advance(ticks: 0, interpolation: 0.5)
            player.advance(ticks: 1, interpolation: 0)
            XCTAssertEqual(sim.canCallReinforcements, player.canCallReinforcements)
            XCTAssertEqual(sim.engine.reinforcementCooldown, player.reinforcementCooldown)
            XCTAssertEqual(sim.engine.garrisonsBySlot.keys.sorted(), player.garrisonsBySlot.keys.sorted())
            let slots = Set(sim.engine.garrisonsBySlot.keys)
            sawExpiry = sawExpiry || !previousSlots.subtracting(slots).isEmpty
            previousSlots = slots
        }
        XCTAssertGreaterThan(sim.reinforcementDeployments.count, 3)
        XCTAssertTrue(sawExpiry)
        XCTAssertEqual(sim.result(), player.simulationResult())
        XCTAssertEqual(sim.engine.militia.map(\.hp), player.militia.map(\.hp))
        XCTAssertEqual(sim.engine.militia.map(\.position), player.militia.map(\.position))
        XCTAssertTrue(sim.engine.heroPosts.isEmpty)
        XCTAssertTrue(player.heroPosts.isEmpty)
    }

    @MainActor func testSavedCandidateReplaysDeploymentsAndDatabaseRecoveryChangesPropagate() throws {
        let fixture = try fixture(), content = try BattleTestFixture.authored(db: fixture.db)
        let beforeProfile = try fixture.db.playerMetaUpgradeDao.get()
        let strategy = GeneticStrategy(decisions: [], metaUpgrades: Array(content.playerUpgrades.loadout.selected))
        let copy = try JSONDecoder().decode(GeneticStrategy.self, from: JSONEncoder().encode(strategy))
        let first = try GeneticCommander.evaluate(strategy, recording: .preview, content: content, money: 500, seed: 1776, maxSeconds: 15)
        let replay = try GeneticCommander.evaluate(copy, recording: .preview, content: content, money: 500, seed: 1776, maxSeconds: 15)
        XCTAssertEqual(first, replay)
        XCTAssertFalse(first.reinforcementDeployments.isEmpty)
        try execute("UPDATE reinforcement_config SET cooldown_seconds=2,time_to_live_seconds=3", fixture)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        let after = try GeneticCommander.evaluate(strategy, recording: .preview, content: changed, money: 500, seed: 1776, maxSeconds: 15)
        XCTAssertGreaterThan(after.reinforcementDeployments.count, first.reinforcementDeployments.count)
        XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get(), beforeProfile)
        try execute("DELETE FROM reinforcement_config", fixture)
        XCTAssertThrowsError(try BattleTestFixture.authored(db: fixture.db))
    }

    @MainActor func testSingleCooldownAppliesToEveryLoadoutAndRejectedCallsAreNotRecorded() throws {
        let fixture = try fixture()
        try execute("UPDATE reinforcement_config SET cooldown_seconds=2,time_to_live_seconds=20", fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        for selected in [content.playerUpgrades.loadout.selected, Set<MetaUpgrade>()] {
            let sim = try GameSimulation(recording: .preview, content: content.selectingMetaUpgrades(selected), startingMoney: 500, heroesEnabled: false, seed: 1)
            var commander = ReinforcementCommander(.immediate)
            for _ in 0..<90 { try commander.tick(sim: sim); sim.step() }
            XCTAssertTrue(sim.reinforcementDeployments.isEmpty, "Wait for an enemy rather than wasting an idle charge")
            sim.startNextWave()
            while sim.enemies.isEmpty { sim.step() }
            XCTAssertEqual(sim.perform(.reinforcements(point: Point(-10000, -10000))), .invalid)
            XCTAssertTrue(sim.reinforcementDeployments.isEmpty)
            try commander.tick(sim: sim)
            try commander.tick(sim: sim)
            XCTAssertEqual(sim.reinforcementDeployments.count, 1)
            XCTAssertFalse(sim.canCallReinforcements)
        }
    }

    func testReinforcementGenesAreExplicitAndEvolveWithCandidate() throws {
        let fixture = try fixture()
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: XCTUnwrap(fixture.db.levelInfoDao.getIdBy(levelName: "Charleston")))
        let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 1776)
        let meta = Array(study.battle.playerUpgrades.loadout.selected)
        let a = GeneticStrategy(plan: plan, metaUpgrades: meta)
        let b = GeneticStrategy(plan: plan, metaUpgrades: meta,
            reinforcements: .init(priority: .nearPoint(study.level.paths[0].point(atDistance: 200)), holdSeconds: 3))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertNotEqual(try encoder.encode(a), try encoder.encode(b))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(a)) as? [String: Any])
        json.removeValue(forKey: "reinforcements")
        XCTAssertThrowsError(try JSONDecoder().decode(GeneticStrategy.self, from: JSONSerialization.data(withJSONObject: json)))
        var rng = SeededRNG(seed: 100), mutant = a
        var inheritedA = false, inheritedB = false, mutated = false
        for _ in 0..<120 {
            let child = GeneticStrategy.crossover(a, b, slots: study.level.towerSlots.count, rng: &rng)
            inheritedA = inheritedA || child.reinforcements == a.reinforcements
            inheritedB = inheritedB || child.reinforcements == b.reinforcements
            mutant.mutate(study: study, metaChoices: [meta], rng: &rng)
            try mutant.validate(study: study)
            mutated = mutated || mutant.reinforcements != a.reinforcements
        }
        XCTAssertTrue(inheritedA && inheritedB && mutated)
        for hold in [-1.0, Double.infinity, Double.nan] {
            XCTAssertThrowsError(try ReinforcementStrategy(priority: .nearestExit, holdSeconds: hold).validate())
        }
        XCTAssertThrowsError(try ReinforcementStrategy(priority: .nearPoint(Point(.nan, 1)), holdSeconds: 0).validate())
    }

    @MainActor func testSavingForTowerDoesNotBlockReinforcements() throws {
        let fixture = try fixture(), content = try BattleTestFixture.authored(db: fixture.db)
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: content.level.id)
        let tower = try XCTUnwrap(study.towerPaths.first)
        let strategy = GeneticStrategy(decisions: [.init(step: .init(time: 0, action: .build(slot: 0, towerID: tower.type.id)), saveForPurchase: true)],
            metaUpgrades: Array(content.playerUpgrades.loadout.selected))
        let result = try GeneticCommander.evaluate(strategy, recording: .preview, content: content, money: 1, seed: 1776, maxSeconds: 5)
        XCTAssertFalse(result.reinforcementDeployments.isEmpty)
    }
}
