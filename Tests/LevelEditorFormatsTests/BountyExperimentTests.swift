import XCTest
import SQLite3
@testable import LevelEditorFormats

final class BountyExperimentTests: XCTestCase {
    private func fixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }

    func testDiskContentCopyKeepsPricesPlayerStateAndAllOtherRules() throws {
        let source = Db(dbPath: Db.authoredDatabaseURL.path, fullRefresh: false,
            levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        defer { source.close() }
        let copy = try BountyExperimentDAO.contentCopy(of: source, fraction: 0.5)
        defer { copy.close() }
        XCTAssertEqual(copy.path, ":memory:")
        XCTAssertEqual(try copy.combatRulesDao.get().killBountyMultiplier, try source.combatRulesDao.get().killBountyMultiplier * 0.5)
        XCTAssertEqual(try copy.playerMetaUpgradeDao.get(), try source.playerMetaUpgradeDao.get())
        let a = try BattleTestFixture.authored(db: source), b = try BattleTestFixture.authored(db: copy)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(a.level), try encoder.encode(b.level))
        XCTAssertEqual(try encoder.encode(a.enemies), try encoder.encode(b.enemies))
        func removeBounty(_ value: Any) -> Any {
            if let dictionary = value as? [String: Any] {
                return dictionary.filter { $0.key != "killBountyMultiplier" }.mapValues(removeBounty)
            }
            if let array = value as? [Any] { return array.map(removeBounty) }
            return value
        }
        let original = try removeBounty(JSONSerialization.jsonObject(with: encoder.encode(a.arsenal.towers.flatMap(\.tiers).map(\.tuning))))
        let changed = try removeBounty(JSONSerialization.jsonObject(with: encoder.encode(b.arsenal.towers.flatMap(\.tiers).map(\.tuning))))
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: original, options: .sortedKeys),
                       try JSONSerialization.data(withJSONObject: changed, options: .sortedKeys))
        XCTAssertTrue(try copy.simulatorRunDao.recent(limit: 1).isEmpty)
    }

    func testExperimentUsesCurrentDatabaseRuleAndCannotWriteBackToSource() throws {
        let source = try fixture()
        XCTAssertEqual(sqlite3_exec(source.connection, "UPDATE combat_rules SET kill_bounty_multiplier=1.5", nil, nil, nil), SQLITE_OK)
        let copy = try BountyExperimentDAO.contentCopy(of: source.db, fraction: 0.5)
        defer { copy.close() }
        XCTAssertEqual(try copy.combatRulesDao.get().killBountyMultiplier, 0.75)
        XCTAssertEqual(try source.db.combatRulesDao.get().killBountyMultiplier, 1.5)
        XCTAssertEqual(sqlite3_exec(copy.conn, "UPDATE tower SET cost=cost+100", nil, nil, nil), SQLITE_OK)
        XCTAssertNotEqual(try copy.towerTypeDao.getDesignArsenal().towerTypes[0].levels[0].cost,
                          try source.db.towerTypeDao.getDesignArsenal().towerTypes[0].levels[0].cost)
        for fraction in [-1.0, 1.1, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try BountyExperimentDAO.contentCopy(of: source.db, fraction: fraction))
        }
        XCTAssertEqual(sqlite3_exec(source.connection, "DELETE FROM combat_rules", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try BountyExperimentDAO.contentCopy(of: source.db, fraction: 0.5))
    }

    @MainActor func testBountyIsPaidByTheSameEngineUsingDAOLoadedRule() throws {
        let source = try fixture()
        let low = try BountyExperimentDAO.contentCopy(of: source.db, fraction: 0.5)
        defer { low.close() }
        let baseline = try GameSimulation(content: BattleTestFixture.authored(db: source.db), startingMoney: 500, heroesEnabled: false, seed: 7)
        let reduced = try GameSimulation(content: BattleTestFixture.authored(db: low), startingMoney: 500, heroesEnabled: false, seed: 7)
        baseline.startNextWave(); reduced.startNextWave()
        baseline.step(); reduced.step()
        let a = try XCTUnwrap(baseline.engine.walkers.first), b = try XCTUnwrap(reduced.engine.walkers.first)
        XCTAssertEqual(a.hp, b.hp); XCTAssertEqual(a.position, b.position); XCTAssertEqual(a.bounty, b.bounty)
        // Exercise the real reward handler; the experiment never computes a payout.
        baseline.engine.creditKill(a); reduced.engine.creditKill(b)
        XCTAssertGreaterThan(baseline.gold, reduced.gold)
        XCTAssertGreaterThan(reduced.gold, 500)
        XCTAssertEqual(baseline.result().killed, reduced.result().killed)
    }
}
