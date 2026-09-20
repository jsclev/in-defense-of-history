import XCTest
import SQLite3
@testable import LevelEditorFormats

final class PlayerMetaUpgradeDAOTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testAuthoredProfilesHaveCompleteExplicitSelectionsAndLevelResults() throws {
        let fixture = try AuthoredDatabaseFixture()
        let profiles = try fixture.db.playerMetaUpgradeDao.getAll()
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[.active], profiles[.level15])
        let active = try XCTUnwrap(profiles[.active])
        XCTAssertEqual(active.loadout.selected.count, 18)
        XCTAssertEqual(active.loadout.starBudget, 42)
        XCTAssertEqual(active.loadout.availableStars, 2)
        XCTAssertEqual(active.bestStarsByLevel.count, 41)
        XCTAssertEqual(active.bestStarsByLevel.values.filter { $0 == 3 }.count, 14)
    }

    @MainActor func testSqlEditsReachStoreAndBattleEffectsWithoutSwiftPreset() throws {
        let fixture = try AuthoredDatabaseFixture()
        let store = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        let tower = try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[.supply]?[1]?[1])
        let discounted = store.loadout.effects.priced(tower, kind: .supply, level: 1).cost
        try execute("UPDATE player_meta_upgrade_selection SET is_selected = 0 WHERE profile_key = 'active' AND upgrade_key IN ('artificerCorps', 'modelCompany', 'frenchContracts', 'alarmRiders')", in: fixture)
        try store.reload()
        XCTAssertEqual(store.loadout.selected.count, 14)
        XCTAssertEqual(store.loadout.availableStars, 12)
        XCTAssertGreaterThan(store.loadout.effects.priced(tower, kind: .supply, level: 1).cost, discounted)
        let recreated = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        XCTAssertEqual(recreated.loadout, store.loadout)
    }

    func testPresetRestoreReadsEditedSqlAndDoesNotInventASeed() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        try execute("UPDATE player_meta_upgrade_selection SET is_selected = 0 WHERE profile_key = 'level15' AND upgrade_key = 'twoGoodVolleys'", in: fixture)
        let preset = try dao.get(profile: .level15)
        XCTAssertEqual(preset.loadout.selected.count, 17)
        XCTAssertEqual(try dao.get().loadout.selected.count, 18)
        try dao.restoreLevel15()
        XCTAssertEqual(try dao.get(), preset)
        try dao.reset()
        try execute("DELETE FROM player_meta_upgrade_selection WHERE profile_key = 'level15' AND upgrade_key = 'rangeEstimation'", in: fixture)
        XCTAssertThrowsError(try dao.restoreLevel15()) { XCTAssertTrue(String(describing: $0).contains("rangeEstimation")) }
        XCTAssertTrue(try dao.get().loadout.selected.isEmpty)
    }

    @MainActor func testStaleStoresUseFreshDatabaseStateAndReplaysCannotFarmStars() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        let first = try MetaUpgradeStore(dao: dao), second = try MetaUpgradeStore(dao: dao)
        try first.reset()
        XCTAssertTrue(try second.purchase(.rangeEstimation), "A stale selected flag must not suppress a valid purchase")
        XCTAssertTrue(try first.purchase(.cartridgeDrill), "A stale prerequisite view must not reject a valid purchase")
        XCTAssertEqual(try dao.get().loadout.selected, [.rangeEstimation, .cartridgeDrill])
        let level = try XCTUnwrap(dao.get().bestStarsByLevel.first { $0.value == 0 }?.key)
        XCTAssertEqual(try first.recordVictory(levelID: level, lives: 20, startingLives: 20), 3)
        XCTAssertEqual(try second.recordVictory(levelID: level, lives: 20, startingLives: 20), 0)
        XCTAssertEqual(try dao.get().loadout.starBudget, 45)
        XCTAssertEqual(second.loadout.starBudget, 45)
        try first.refund(.rangeEstimation)
        XCTAssertEqual(try dao.get().loadout.availableStars, 45)
        XCTAssertTrue(try dao.get().loadout.selected.isEmpty)
    }

    @MainActor func testFailedLedgerWriteRollsBackSelectionsAndDoesNotPublish() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        let store = try MetaUpgradeStore(dao: dao)
        let before = try dao.get()
        try execute("""
            CREATE TRIGGER reject_meta_ledger BEFORE UPDATE ON player_meta_upgrade_level_stars
            WHEN OLD.profile_key = 'active' BEGIN SELECT RAISE(ABORT, 'forced ledger write failure'); END;
            """, in: fixture)
        XCTAssertThrowsError(try store.reset()) { XCTAssertTrue(String(describing: $0).contains("forced ledger write failure")) }
        XCTAssertEqual(try dao.get(), before)
        XCTAssertEqual(store.loadout, before.loadout)
        try execute("DROP TRIGGER reject_meta_ledger", in: fixture)
        try store.reset()
        XCTAssertEqual(try dao.get().loadout.availableStars, 42)
    }

    func testInvalidPurchaseAndUnknownVictoryLeaveDatabaseUnchanged() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        try dao.reset()
        let before = try dao.get()
        XCTAssertFalse(try dao.purchase(.twoGoodVolleys))
        XCTAssertThrowsError(try dao.setSelectedUpgrades([.twoGoodVolleys]))
        XCTAssertThrowsError(try dao.recordVictory(levelID: UUID(), lives: 20, startingLives: 20))
        XCTAssertThrowsError(try dao.recordVictory(levelID: before.bestStarsByLevel.keys.first!, lives: 21, startingLives: 20))
        XCTAssertEqual(try dao.get(), before)
        try dao.restoreLevel15()
        XCTAssertTrue(try dao.purchase(.thunderousReport))
        let spent = try dao.get()
        XCTAssertEqual(spent.loadout.availableStars, 0)
        XCTAssertFalse(try dao.purchase(.ammunitionWagons))
        XCTAssertEqual(try dao.get(), spent)
    }

    func testMissingUnknownAndMalformedRowsFailWithRecordAndFieldDiagnostics() throws {
        let cases: [(String, String)] = [
            ("DELETE FROM player_meta_upgrade_selection WHERE profile_key = 'active' AND upgrade_key = 'alarmRiders'", "alarmRiders"),
            ("PRAGMA foreign_keys=OFF; UPDATE player_meta_upgrade_selection SET upgrade_key = 'unknownUpgrade' WHERE profile_key = 'active' AND upgrade_key = 'alarmRiders'", "upgrade_key"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE player_meta_upgrade_selection SET is_selected = 2 WHERE profile_key = 'active' AND upgrade_key = 'alarmRiders'", "is_selected"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE player_meta_upgrade_level_stars SET best_stars = 4 WHERE profile_key = 'active'", "best_stars"),
            ("DELETE FROM player_meta_upgrade_level_stars WHERE profile_key = 'active'", "best_stars"),
            ("UPDATE player_meta_upgrade_selection SET is_selected = 0 WHERE profile_key = 'active' AND upgrade_key = 'cartridgeDrill'", "is_selected"),
            ("UPDATE player_meta_upgrade_level_stars SET best_stars = 0 WHERE profile_key = 'active'", "is_selected"),
            ("PRAGMA foreign_keys=OFF; DELETE FROM player_meta_upgrade_profile WHERE profile_key = 'active'", "profile_key"),
            ("PRAGMA foreign_keys=OFF; UPDATE player_meta_upgrade_level_stars SET level_info_id = '00000000-0000-0000-0000-000000000000' WHERE profile_key='active' AND level_info_id=(SELECT level_info_id FROM player_meta_upgrade_level_stars WHERE profile_key='active' LIMIT 1)", "resolved_level_id")
        ]
        for (sql, field) in cases {
            let fixture = try AuthoredDatabaseFixture()
            try execute(sql, in: fixture)
            XCTAssertThrowsError(try fixture.db.playerMetaUpgradeDao.get(), sql) {
                let diagnostic = String(describing: $0)
                XCTAssertTrue(diagnostic.contains("player_meta_upgrade"), diagnostic)
                XCTAssertTrue(diagnostic.contains(field), diagnostic)
            }
        }
    }

    func testNullRequiredFlagFailsEvenWhenConstraintsWereRemoved() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            ALTER TABLE player_meta_upgrade_selection RENAME TO old_selection;
            CREATE TABLE player_meta_upgrade_selection AS SELECT * FROM old_selection;
            UPDATE player_meta_upgrade_selection SET is_selected = NULL
            WHERE profile_key='active' AND upgrade_key='rangeEstimation';
            """, in: fixture)
        XCTAssertThrowsError(try fixture.db.playerMetaUpgradeDao.get()) {
            XCTAssertTrue(String(describing: $0).contains("rangeEstimation"))
            XCTAssertTrue(String(describing: $0).contains("is_selected"))
        }
    }

    func testSchemaRejectsInvalidFlagsStarsDuplicatesAndForeignKeys() throws {
        let fixture = try AuthoredDatabaseFixture()
        for sql in [
            "UPDATE player_meta_upgrade_selection SET is_selected=NULL",
            "UPDATE player_meta_upgrade_selection SET is_selected=2",
            "UPDATE player_meta_upgrade_level_stars SET best_stars=-1",
            "UPDATE player_meta_upgrade_level_stars SET best_stars=1.5",
            "UPDATE player_meta_upgrade_level_stars SET best_stars=4",
            "UPDATE player_meta_upgrade_selection SET profile_key='missing'",
            "UPDATE player_meta_upgrade_level_stars SET level_info_id='00000000-0000-0000-0000-000000000000'",
            "INSERT INTO player_meta_upgrade_selection VALUES ('active','rangeEstimation',1)"
        ] { XCTAssertNotEqual(sqlite3_exec(fixture.connection, sql, nil, nil, nil), SQLITE_OK, sql) }
        XCTAssertEqual(try fixture.db.playerMetaUpgradeDao.get().loadout.selected.count, 18)
    }
}
