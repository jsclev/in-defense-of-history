import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerEncyclopediaTests: XCTestCase {
    private func stats(_ fixture: AuthoredDatabaseFixture, kind: TowerKind,
                       level: Int = 4, branch: Int = 1) throws -> [String: String] {
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let tier = try XCTUnwrap(arsenal.towers.first { $0.kind == kind }?.tiers.first {
            $0.level == level && $0.branch == branch
        })
        return Dictionary(uniqueKeysWithValues: TowerEncyclopediaStat.values(for: tier.tuning).map {
            ($0.label, $0.value)
        })
    }

    func testCapabilitySpecificStatsDoNotInventAttacksForSupportTowers() throws {
        let fixture = try AuthoredDatabaseFixture()
        let supply = try stats(fixture, kind: .supply, level: 1)
        XCTAssertEqual(supply, ["Income each wave": "15 coins"])
        let hospital = try stats(fixture, kind: .supply, branch: 3)
        XCTAssertEqual(hospital["Nearby healing"], "8 HP/s")
        XCTAssertNotNil(hospital["Support range"])
        XCTAssertNil(hospital["Damage"])
        let engineers = try stats(fixture, kind: .special, level: 1)
        XCTAssertNotNil(engineers["Enemy slowdown"])
        XCTAssertNil(engineers["Damage"])
        let sapper = try stats(fixture, kind: .special, branch: 3)
        XCTAssertNotNil(sapper["Charge preparation"])
        XCTAssertNotNil(sapper["Damage"])
        XCTAssertNil(sapper["Time between shots"])
        let swivel = try stats(fixture, kind: .areaOfEffect, branch: 2)
        XCTAssertNotNil(swivel["Damage per pellet"])
        XCTAssertNil(swivel["Blast radius"])
        let infantry = try stats(fixture, kind: .melee)
        XCTAssertEqual(infantry["Soldiers"], "3")
        XCTAssertNotNil(infantry["Damage per soldier"])
        XCTAssertNotNil(infantry["Rally range"])
        XCTAssertNil(infantry["Time between shots"])
    }

    func testDatabaseEditsReachEncyclopediaStatsAndUpgradeCopy() throws {
        let fixture = try AuthoredDatabaseFixture()
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE tower SET shot_min_damage = 123, shot_max_damage = 145, fire_interval = 2.75
            WHERE attack_mode = 'direct';
            UPDATE tower SET income_per_wave = 73 WHERE attack_mode = 'none';
            UPDATE tower SET support_heal_per_second = 11 WHERE support_heal_per_second > 0;
            UPDATE melee_unit SET hp = 321;
            UPDATE tower_upgrade_path SET path_name = 'Authored path', path_description = 'Authored explanation';
            UPDATE tower_upgrade_rank SET rank_description = 'Authored rank', cost = 231;
            """, nil, nil, nil), SQLITE_OK)
        let ranged = try stats(fixture, kind: .ranged)
        XCTAssertEqual(ranged["Damage"], "123–145")
        XCTAssertEqual(ranged["Time between shots"], "2.75 s")
        XCTAssertEqual(try stats(fixture, kind: .supply)["Income each wave"], "73 coins")
        XCTAssertEqual(try stats(fixture, kind: .supply, branch: 3)["Nearby healing"], "11 HP/s")
        XCTAssertEqual(try stats(fixture, kind: .melee)["Health per soldier"], "321")
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let paths = arsenal.towers.flatMap(\.tiers).flatMap { $0.tuning.upgradePaths }
        XCTAssertFalse(paths.isEmpty)
        for path in paths {
            XCTAssertEqual(path.name, "Authored path")
            XCTAssertEqual(path.description, "Authored explanation")
            XCTAssertTrue(path.ranks.allSatisfy { $0.description == "Authored rank" && $0.cost == 231 })
        }
    }

    func testEveryTowerHistoryAndSourceComeFromTheDatabase() throws {
        let fixture = try AuthoredDatabaseFixture()
        let tiers = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers)
        XCTAssertEqual(tiers.count, 30)
        XCTAssertEqual(Set(tiers.map { $0.history.description }).count, tiers.count)
        for tier in tiers {
            XCTAssertFalse(tier.history.description.isEmpty)
            XCTAssertFalse(tier.history.sourceTitle.isEmpty)
            XCTAssertEqual(tier.history.sourceURL.scheme, "https")
        }
        let selected = try XCTUnwrap(tiers.first)
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE tower_history SET historical_description = 'Changed authored history',
                source_title = 'Changed source', source_url = 'https://www.nps.gov/updated-source'
            WHERE lower(tower_id) = '\(selected.id.uuidString.lowercased())'
            """, nil, nil, nil), SQLITE_OK)
        let updated = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers)
        let history = try XCTUnwrap(updated.first { $0.id == selected.id }).history
        XCTAssertEqual(history.description, "Changed authored history")
        XCTAssertEqual(history.sourceTitle, "Changed source")
        XCTAssertEqual(history.sourceURL.absoluteString, "https://www.nps.gov/updated-source")
        for tier in updated where tier.id != selected.id {
            XCTAssertEqual(tier.history.description, tiers.first { $0.id == tier.id }?.history.description)
        }
    }

    func testMissingOrMalformedHistoryFailsWithRecordAndFieldDiagnostic() throws {
        let id = "0a4b1c62-8f3e-4d97-b120-6e5a9c8d7f01"
        let invalidValues = [
            ("historical_description", "NULL"), ("historical_description", "'   '"),
            ("historical_description", "X'6869'"), ("source_title", "NULL"),
            ("source_title", "''"), ("source_url", "NULL"), ("source_url", "''"),
            ("source_url", "'not a URL'"), ("source_url", "'https://'"),
            ("source_url", "'file:///tmp/source'"), ("tower_id", "'unknown'")
        ]
        let mutations = invalidValues.map { field, value in
            (field, "UPDATE tower_history SET \(field) = \(value) WHERE tower_id = '\(id)'")
        } + [
            ("tower_id", "DELETE FROM tower_history WHERE tower_id = '\(id)'"),
            ("tower_id", "INSERT INTO tower_history SELECT '00000000-0000-0000-0000-000000000000', historical_description, source_title, source_url, presentation_kind, strategy_text, inclusion_reason FROM tower_history LIMIT 1"),
            ("tower_id", "INSERT INTO tower_history SELECT * FROM tower_history WHERE tower_id = '\(id)'")
        ]
        for (field, mutation) in mutations {
            let fixture = try AuthoredDatabaseFixture()
            // Remove SQL constraints only in this disposable in-memory fixture
            // to prove the DAO rejects malformed values before UI rendering.
            XCTAssertEqual(sqlite3_exec(fixture.connection, """
                ALTER TABLE tower_history RENAME TO original_history;
                CREATE TABLE tower_history AS SELECT * FROM original_history;
                DROP TABLE original_history;
                \(mutation);
                """, nil, nil, nil), SQLITE_OK, mutation)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal(), mutation) { error in
                let diagnostic = String(describing: error)
                XCTAssertTrue(diagnostic.contains("tower_history"), diagnostic)
                XCTAssertTrue(diagnostic.contains(field), diagnostic)
                if field != "tower_id" {
                    XCTAssertTrue(diagnostic.lowercased().contains(id), diagnostic)
                }
            }
        }
    }

    func testBatteryGuidesAreAuthoredAndOtherEntriesKeepTheirPresentation() throws {
        let fixture = try AuthoredDatabaseFixture()
        let tiers = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers)
        let mortar = try XCTUnwrap(tiers.first { $0.history.guide?.style == .mortarStudy })
        XCTAssertEqual(tiers.filter { $0.history.guide != nil }.count, 2)
        let siege = try XCTUnwrap(tiers.first { $0.history.guide?.style == .siegeStudy })
        XCTAssertFalse(try XCTUnwrap(siege.history.guide).inclusionReason.isEmpty)
        XCTAssertFalse(try XCTUnwrap(mortar.history.guide).strategy.isEmpty)
        XCTAssertFalse(try XCTUnwrap(mortar.history.guide).inclusionReason.isEmpty)
        XCTAssertEqual(sqlite3_exec(fixture.connection, """
            UPDATE tower_history SET strategy_text = 'Changed tactical guidance',
                inclusion_reason = 'Changed design rationale' WHERE presentation_kind IN ('mortarStudy', 'siegeStudy');
            """, nil, nil, nil), SQLITE_OK)
        let updated = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers)
        let guide = try XCTUnwrap(updated.first { $0.id == mortar.id }?.history.guide)
        XCTAssertEqual(guide.strategy, "Changed tactical guidance")
        XCTAssertEqual(guide.inclusionReason, "Changed design rationale")
        let siegeGuide = try XCTUnwrap(updated.first { $0.id == siege.id }?.history.guide)
        XCTAssertEqual(siegeGuide.strategy, "Changed tactical guidance")
        XCTAssertEqual(siegeGuide.inclusionReason, "Changed design rationale")
        for tier in updated where tier.id != mortar.id && tier.id != siege.id { XCTAssertNil(tier.history.guide) }
    }

    func testMissingOrMalformedBatteryGuideFailsWithRecordAndField() throws {
        for id in ["f614aea2-b5cb-4cd3-a30d-e33a02c27c90", "fa950e72-3c9c-420a-ab60-b40cb41407cf"] {
            for (field, value) in [("presentation_kind", "NULL"), ("presentation_kind", "'unknown'"),
                                   ("presentation_kind", "'standard'"), ("strategy_text", "NULL"),
                                   ("strategy_text", "''"), ("strategy_text", "X'6869'"),
                                   ("inclusion_reason", "NULL"), ("inclusion_reason", "'  '")] {
                let fixture = try AuthoredDatabaseFixture()
                XCTAssertEqual(sqlite3_exec(fixture.connection, """
                    ALTER TABLE tower_history RENAME TO original_history;
                    CREATE TABLE tower_history AS SELECT * FROM original_history;
                    DROP TABLE original_history;
                    UPDATE tower_history SET \(field) = \(value) WHERE tower_id = '\(id)';
                    """, nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal()) { error in
                    let diagnostic = String(describing: error).lowercased()
                    XCTAssertTrue(diagnostic.contains(id), diagnostic)
                    XCTAssertTrue(diagnostic.contains(field == "presentation_kind" && value == "'standard'"
                        ? "strategy_text" : field), diagnostic)
                }
            }
        }
    }

    func testMissingOrInvalidContentFailsBeforeReferenceCanBeDisplayed() throws {
        for mutation in [
            "DELETE FROM tower WHERE tower_level = 2",
            "DELETE FROM tower_upgrade_rank WHERE rank = 2",
            "UPDATE tower SET tower_description = ''",
            "UPDATE tower SET support_heal_per_second = -1",
            "UPDATE tower SET attack_mode = 'invented'"
        ] {
            let fixture = try AuthoredDatabaseFixture()
            XCTAssertEqual(sqlite3_exec(fixture.connection, "PRAGMA ignore_check_constraints = ON; " + mutation,
                                       nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal(), mutation)
        }
    }
}
