import XCTest
import SQLite3
@testable import LevelEditorFormats

final class MetaUpgradeDAOTests: XCTestCase {
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testCompleteCatalogHasHistorySourcesAndExplicitEffects() throws {
        let fixture = try AuthoredDatabaseFixture()
        let catalog = try fixture.db.metaUpgradeDao.get()
        XCTAssertEqual(catalog.upgrades.count, 23)
        XCTAssertEqual(catalog.tracks.count, 6)
        XCTAssertEqual(Set(catalog.upgrades.map(\.iconAssetName)).count, 23)
        for node in catalog.upgrades {
            XCTAssertFalse(node.title.isEmpty)
            XCTAssertFalse(node.detail.isEmpty)
            XCTAssertTrue(node.iconAssetName.hasPrefix("meta_"))
            XCTAssertFalse(node.historicalInformation.isEmpty)
            XCTAssertFalse(node.sourceTitle.isEmpty)
            XCTAssertEqual(node.sourceURL.scheme, "https")
            XCTAssertEqual(Set(node.parameters.keys), node.id.requiredParameters)
        }
        let preset = try fixture.db.playerMetaUpgradeDao.get(profile: .level15).loadout
        for key in [MetaUpgrade.modelCompany, .twoGoodVolleys, .bayonetCounterstroke,
                    .preparedFireLanes, .forwardMagazines, .frenchContracts] {
            XCTAssertTrue(preset.selected.contains(key), "Preset must demonstrate \(key)")
        }
    }

    @MainActor func testSqlEditsReachDisplayProgressionAndBattleSnapshots() throws {
        let fixture = try AuthoredDatabaseFixture()
        let store = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        let snapshot = store.loadout.effects
        try execute("""
            UPDATE meta_upgrade SET title='Surveyed Ground', description='Changed authored effect copy',
                historical_information='Changed historical information', source_title='Changed source title',
                source_url='https://www.nps.gov/vafo/', icon_name='meta_surveyed_ground', star_cost=2
            WHERE upgrade_key='rangeEstimation';
            UPDATE meta_upgrade_effect SET value=1.4 WHERE upgrade_key='rangeEstimation' AND parameter='rangeMultiplier';
            UPDATE meta_upgrade_track SET title='Rifle Doctrine', short_title='Rifles' WHERE track_key='marksmanship';
            """, fixture)
        try store.reload()
        let node = store.loadout.catalog[.rangeEstimation]
        XCTAssertEqual(node.title, "Surveyed Ground")
        XCTAssertEqual(node.detail, "Changed authored effect copy")
        XCTAssertEqual(node.historicalInformation, "Changed historical information")
        XCTAssertEqual(node.sourceTitle, "Changed source title")
        XCTAssertEqual(node.sourceURL.absoluteString, "https://www.nps.gov/vafo/")
        XCTAssertEqual(node.iconAssetName, "meta_surveyed_ground")
        XCTAssertEqual(store.loadout.catalog[MetaUpgradeTrack.marksmanship].shortTitle, "Rifles")
        XCTAssertEqual(store.loadout.availableStars, 5)
        let base = try AuthoredDatabaseFixture.tower(.ranged, level: 1, branch: 1)
        XCTAssertEqual(store.loadout.effects.combat(base, kind: .ranged).range, base.range * 1.4)
        XCTAssertEqual(snapshot.combat(base, kind: .ranged).range, base.range * 1.15, "An ongoing battle keeps its snapshot")
        XCTAssertEqual(try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao).loadout, store.loadout)
    }

    func testPrerequisiteEditsControlPurchaseAndTransitiveRefunds() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        try dao.reset()
        try execute("UPDATE meta_upgrade SET prerequisite_key='rangeEstimation' WHERE upgrade_key='crossfire'", fixture)
        XCTAssertTrue(try dao.purchase(.rangeEstimation))
        XCTAssertTrue(try dao.purchase(.crossfire), "The SQL prerequisite overrides the former linear tree")
        XCTAssertTrue(try dao.purchase(.twoGoodVolleys))
        try dao.refund(.rangeEstimation)
        XCTAssertTrue(try dao.get().loadout.selected.isEmpty)
    }

    func testMissingAndMalformedCatalogContentFailsEvenForUnselectedNodes() throws {
        let cases: [(String, String)] = [
            ("PRAGMA foreign_keys=OFF; DELETE FROM meta_upgrade WHERE upgrade_key='powderWorks'", "powderWorks"),
            ("PRAGMA foreign_keys=OFF; DELETE FROM meta_upgrade_track WHERE track_key='artillery'", "artillery"),
            ("PRAGMA foreign_keys=OFF; UPDATE meta_upgrade SET upgrade_key='unknown' WHERE upgrade_key='powderWorks'", "upgrade_key"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET title='' WHERE upgrade_key='powderWorks'", "title"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET icon_name=' ' WHERE upgrade_key='powderWorks'", "icon_name"),
            ("UPDATE meta_upgrade SET icon_name='flame.fill' WHERE upgrade_key='powderWorks'", "icon_name"),
            ("UPDATE meta_upgrade SET icon_name='../alternate' WHERE upgrade_key='powderWorks'", "icon_name"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET historical_information=' ' WHERE upgrade_key='powderWorks'", "historical_information"),
            ("UPDATE meta_upgrade SET source_url='javascript:alert(1)' WHERE upgrade_key='powderWorks'", "source_url"),
            ("PRAGMA ignore_check_constraints=ON; UPDATE meta_upgrade SET star_cost=0 WHERE upgrade_key='powderWorks'", "star_cost"),
            ("UPDATE meta_upgrade SET display_order=9 WHERE upgrade_key='powderWorks'", "display_order"),
            ("UPDATE meta_upgrade SET prerequisite_key='frenchContracts' WHERE upgrade_key='powderWorks'", "prerequisite_key"),
            ("UPDATE meta_upgrade SET prerequisite_key='twoGoodVolleys' WHERE upgrade_key='rangeEstimation'", "prerequisite_key"),
            ("DELETE FROM meta_upgrade_effect WHERE upgrade_key='powderWorks' AND parameter='moraleMultiplier'", "moraleMultiplier"),
            ("UPDATE meta_upgrade_effect SET parameter='unsupported' WHERE upgrade_key='powderWorks' AND parameter='moraleMultiplier'", "parameter"),
            ("UPDATE meta_upgrade_effect SET value=1 WHERE upgrade_key='powderWorks' AND parameter='moraleMultiplier'", "value"),
            ("UPDATE meta_upgrade_effect SET value=1e999 WHERE upgrade_key='powderWorks' AND parameter='moraleMultiplier'", "value"),
            ("UPDATE meta_upgrade_effect SET value=2.5 WHERE upgrade_key='twoGoodVolleys' AND parameter='shotCount'", "value"),
            ("UPDATE meta_upgrade_effect SET value=3 WHERE upgrade_key='forwardMagazines'", "value")
        ]
        for (sql, field) in cases {
            let fixture = try AuthoredDatabaseFixture()
            try execute(sql, fixture)
            XCTAssertThrowsError(try fixture.db.playerMetaUpgradeDao.get(), sql) {
                let diagnostic = String(describing: $0)
                XCTAssertTrue(diagnostic.contains("meta_upgrade"), diagnostic)
                XCTAssertTrue(diagnostic.contains(field), diagnostic)
            }
        }
    }

    func testNullRequiredFieldsFailWhenSchemaConstraintsAreRemoved() throws {
        for field in ["title", "description", "historical_information", "icon_name", "source_title", "source_url", "star_cost", "track_key", "display_order"] {
            let fixture = try AuthoredDatabaseFixture()
            try execute("""
                PRAGMA foreign_keys=OFF;
                ALTER TABLE meta_upgrade RENAME TO original_catalog;
                CREATE TABLE meta_upgrade AS SELECT * FROM original_catalog;
                UPDATE meta_upgrade SET \(field)=NULL WHERE upgrade_key='rangeEstimation';
                """, fixture)
            XCTAssertThrowsError(try fixture.db.metaUpgradeDao.get()) {
                let diagnostic = String(describing: $0)
                XCTAssertTrue(diagnostic.contains("rangeEstimation"), diagnostic)
                XCTAssertTrue(diagnostic.contains(field), diagnostic)
            }
        }
    }

    func testSelectionsReferenceCatalogAndSchemaRejectsInvalidContent() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("PRAGMA foreign_keys=ON", fixture)
        for sql in [
            "UPDATE player_meta_upgrade_selection SET upgrade_key='unknown'",
            "DELETE FROM meta_upgrade WHERE upgrade_key='powderWorks'",
            "UPDATE meta_upgrade SET historical_information=NULL",
            "UPDATE meta_upgrade SET description=''",
            "UPDATE meta_upgrade SET star_cost=1.5",
            "UPDATE meta_upgrade_effect SET value=0",
            "UPDATE meta_upgrade_effect SET value=NULL"
        ] { XCTAssertNotEqual(sqlite3_exec(fixture.connection, sql, nil, nil, nil), SQLITE_OK, sql) }
    }
}
