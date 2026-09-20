import XCTest
import SQLite3
@testable import LevelEditorFormats

final class AuthoredMoneyStudyTests: XCTestCase {
    private let charleston = UUID(uuidString: "4ca73a47-98f6-41b6-815d-c2c797aa746e")!

    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(
            directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testMoneyChangesPreserveEntireAuthoredLevelAndEveryBranch() throws {
        let fixture = try fixture()
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: charleston)
        let original = try fixture.db.levelLoader.load(id: charleston)
        XCTAssertEqual(study.level, original)
        XCTAssertEqual(study.level.towerSlots.count, 19)
        XCTAssertEqual(study.level.paths.count, 6)
        XCTAssertEqual(study.level.waves.count, 15)
        let expected = Set(study.arsenal.towers.flatMap(\.tiers).map(\.id))
        XCTAssertEqual(Set(study.towerPaths.flatMap(\.tierIDs)), expected)
        XCTAssertEqual(expected.count, 29)
        XCTAssertEqual(study.towerPaths.count, 14)
        XCTAssertEqual(Set(study.towerPaths.map(\.kind)), Set(TowerKind.allCases))
        for money in [100, 450, 800] {
            let trial = study.level(startingMoney: money)
            XCTAssertEqual(trial.startingMoney, money)
            XCTAssertEqual(trial.paths, original.paths)
            XCTAssertEqual(trial.towerSlots, original.towerSlots)
            XCTAssertEqual(trial.waves, original.waves)
            XCTAssertEqual(trial.playArea, original.playArea)
            XCTAssertEqual(trial.mapImageName, original.mapImageName)
            XCTAssertEqual(trial.numStartingLives, original.numStartingLives)
        }
        XCTAssertEqual(try fixture.db.levelLoader.load(id: charleston), original)
    }

    func testAuthoredChangesPropagateIntoStudy() throws {
        let fixture = try fixture()
        try execute("""
            UPDATE level_info SET starting_money=515 WHERE id='\(charleston.uuidString.lowercased())';
            UPDATE tower SET cost=cost+7 WHERE tower_level=1;
            UPDATE difficulty SET enemy_hp_multiplier=1.75
              WHERE id IN (SELECT difficulty_id FROM player_selected_difficulty);
            """, fixture)
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: charleston)
        XCTAssertEqual(study.level.startingMoney, 515)
        XCTAssertEqual(study.battle.difficulty.enemyHPMultiplier, 1.75)
        let authoredEnemies = try fixture.db.enemyTypeDao.getAll()
        for enemy in study.catalog.enemyTypes {
            let source = try XCTUnwrap(authoredEnemies.first { $0.id == enemy.id })
            XCTAssertEqual(enemy.stats.maxHP, source.stats.maxHP)
            XCTAssertEqual(enemy.stats.speed, source.stats.speed)
            XCTAssertEqual(enemy.stats.gold, source.stats.gold)
        }
        let levels = try fixture.db.towerTypeDao.getTowerLevelsByBranch()
        for path in study.towerPaths {
            XCTAssertEqual(path.type.levels.first, levels[path.kind]?[1]?[1])
        }
    }

    func testMissingSelectionsUnlocksAndTowerBranchesFail() throws {
        let fixture = try fixture()
        for sql in [
            "DELETE FROM player_selected_difficulty",
            "DELETE FROM level_tower_unlock WHERE tower_kind='supply'",
            "DELETE FROM tower WHERE attack_mode='demolition'",
            "UPDATE level_info SET num_waves=14 WHERE id='\(charleston.uuidString.lowercased())'"
        ] {
            try execute("SAVEPOINT invalid_study; \(sql)", fixture)
            XCTAssertThrowsError(try AuthoredMoneyStudy(db: fixture.db, levelID: charleston), sql)
            try execute("ROLLBACK TO invalid_study; RELEASE invalid_study", fixture)
        }
    }

    func testApprovedGridHasNoMissingEndpointsOrHiddenBaselineRuns() throws {
        let grid = try MoneyStudyGrid(minimum: 100, maximum: 800, step: 5,
            placementPlans: 100, upgradePolicies: 10, combatSeeds: 20)
        XCTAssertEqual(grid.money, Array(stride(from: 100, through: 800, by: 5)))
        XCTAssertEqual(grid.money.count, 141)
        XCTAssertEqual(grid.strategyCount, 1_000)
        XCTAssertEqual(grid.runCount, 2_820_000)
        XCTAssertThrowsError(try MoneyStudyGrid(minimum: 100, maximum: 801, step: 5,
            placementPlans: 100, upgradePolicies: 10, combatSeeds: 20))
    }

    func testPlansArePairedAndOnlyScheduleLegalTowerUpgradeChains() throws {
        let fixture = try fixture()
        let study = try AuthoredMoneyStudy(db: fixture.db, levelID: charleston)
        let first = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 0, seed: 1776)
        let repeated = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 0, seed: 1776)
        let delayed = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 5, seed: 1776)
        let different = try MoneyStudyPlan(study: study, placementIndex: 8, upgradePolicyIndex: 0, seed: 1776)
        XCTAssertEqual(first.slotOrder, repeated.slotOrder)
        XCTAssertEqual(first.towerIDs, repeated.towerIDs)
        XCTAssertEqual(first.steps.map(\.action), repeated.steps.map(\.action))
        XCTAssertEqual(first.slotOrder, delayed.slotOrder)
        XCTAssertEqual(first.towerIDs, delayed.towerIDs)
        XCTAssertNotEqual(first.slotOrder, different.slotOrder)
        XCTAssertNotEqual(first.steps.map(\.time), delayed.steps.map(\.time))
        for policy in 0..<10 {
            let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: policy, seed: 1776)
            XCTAssertEqual(Set(plan.slotOrder), Set(study.level.towerSlots.indices))
            var built: [Int: (type: TowerType, level: Int, ranks: [String: Int])] = [:]
            for step in plan.steps {
                switch step.action {
                case let .build(slot, id):
                    XCTAssertNil(built[slot])
                    built[slot] = (try XCTUnwrap(study.catalog.towerTypes.first { $0.id == id }), 0, [:])
                case let .upgrade(slot):
                    var tower = try XCTUnwrap(built[slot])
                    tower.level += 1
                    tower.ranks = [:]
                    XCTAssertTrue(tower.type.levels.indices.contains(tower.level))
                    built[slot] = tower
                case let .purchaseUpgrade(slot, pathID):
                    var tower = try XCTUnwrap(built[slot])
                    let path = try XCTUnwrap(tower.type.levels[tower.level].upgradePaths.first { $0.id == pathID })
                    tower.ranks[pathID, default: 0] += 1
                    XCTAssertLessThanOrEqual(tower.ranks[pathID]!, path.ranks.count)
                    built[slot] = tower
                }
            }
            XCTAssertEqual(built.count, study.level.towerSlots.count)
            for tower in built.values { XCTAssertEqual(tower.level, tower.type.levels.count - 1) }
        }
    }

    func testStudyPersistenceRollsBackDuplicateAndInactiveRunWrites() throws {
        let fixture = try fixture()
        let dao = try MoneyStudyDAO(db: fixture.db)
        let id = try fixture.db.simulatorRunDao.begin(levelName: "Charleston", focus: "test", totalIterations: 2, outputPath: ":memory:")
        try dao.begin(runID: id, configuration: "{}", contentSHA256: "test", plans: "[]")
        let sample = SimulationResult(outcome: .defeat, seconds: 100, livesRemaining: 0,
            goldRemaining: 5, goldEarned: 10, killed: 2, routed: 0, captured: 0, leaked: 20,
            fatesByTypeID: [:], waveMaxProgress: [], leaksByWave: [])
        let row = MoneyStudyResultRow(money: 100, placementPlan: 0, upgradePolicy: 0, results: [sample, sample])
        try dao.insert([row], runID: id, completed: 2, rate: 10)
        XCTAssertEqual(try fixture.db.simulatorRunDao.get(id: id)?.completedIterations, 2)
        XCTAssertEqual(try dao.summary(runID: id).first?["runs"] as? Int, 2)
        XCTAssertThrowsError(try dao.insert([row], runID: id, completed: 4, rate: 10))
        XCTAssertEqual(try fixture.db.simulatorRunDao.get(id: id)?.completedIterations, 2)
        fixture.db.simulatorRunDao.finish(id: id, status: .failed)
        let other = MoneyStudyResultRow(money: 105, placementPlan: 0, upgradePolicy: 0, results: [sample])
        XCTAssertThrowsError(try dao.insert([other], runID: id, completed: 3, rate: 10))
        XCTAssertEqual(try dao.summary(runID: id).count, 1)
    }
}
