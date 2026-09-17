import XCTest
import SQLite3
@testable import LevelEditorFormats

final class HeroContentAuthorityTests: XCTestCase {
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func relax(_ table: String, _ fixture: AuthoredDatabaseFixture) throws {
        try execute("CREATE TABLE test_rows AS SELECT * FROM \(table); DROP TABLE \(table); ALTER TABLE test_rows RENAME TO \(table)", fixture)
    }

    func testEveryRequiredHeroFieldRejectsNullBlankOrMalformedData() throws {
        let fixture = try AuthoredDatabaseFixture()
        try relax("hero", fixture)
        let textFields = ["id", "short_name", "long_name", "general_description", "historical_description",
                          "historical_text", "primary_image_name", "icon_image_name", "ability_icon_image_name",
                          "unit_image_name", "unlocked_at_level_wave_id"]
        for field in textFields {
            for value in ["NULL", "''", "'  '", "X'00FF'"] {
                try execute("SAVEPOINT corrupt; UPDATE hero SET \(field) = \(value)", fixture)
                XCTAssertThrowsError(try fixture.db.heroDao.getAll(), field) {
                    XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
                }
                try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
            }
        }
        for value in ["NULL", "0", "101", "1.5", "'invalid'", "1e999"] {
            try execute("SAVEPOINT corrupt; UPDATE hero SET ranking = \(value)", fixture)
            XCTAssertThrowsError(try fixture.db.heroDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains("ranking"), "\($0)")
            }
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
    }

    func testMissingHeroColumnsFail() throws {
        let fixture = try AuthoredDatabaseFixture()
        try relax("hero", fixture)
        for field in ["short_name", "long_name", "nickname", "general_description", "historical_description",
                      "historical_text", "primary_image_name", "icon_image_name", "ability_icon_image_name",
                      "unit_image_name", "ranking", "unlocked_at_level_wave_id"] {
            try execute("SAVEPOINT corrupt; ALTER TABLE hero DROP COLUMN \(field)", fixture)
            XCTAssertThrowsError(try fixture.db.heroDao.getAll(), field)
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
    }

    func testMissingHeroOrUnlockRelationshipsCannotDisappearFromTheRoster() throws {
        let fixture = try AuthoredDatabaseFixture()
        let hero = try XCTUnwrap(fixture.db.heroDao.getAll().first)
        for mutation in [
            "DELETE FROM hero",
            "DELETE FROM hero WHERE id = '\(hero.id.uuidString.lowercased())'",
            "DELETE FROM level_wave WHERE id IN (SELECT unlocked_at_level_wave_id FROM hero)",
            "DELETE FROM level_info WHERE id = '\(hero.unlockedAtLevelId.uuidString.lowercased())'",
            "DELETE FROM campaign",
            "UPDATE hero SET unlocked_at_level_wave_id = '\(UUID().uuidString.lowercased())'",
            "DELETE FROM player_selected_hero"
        ] {
            try execute("SAVEPOINT corrupt; \(mutation)", fixture)
            XCTAssertThrowsError(try fixture.db.heroDao.validateAuthoredContent(), mutation)
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
    }

    func testDanglingSelectedHeroIsNotDroppedByAJoin() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("UPDATE player_selected_hero SET hero_id = '\(UUID().uuidString.lowercased())' WHERE selection_slot = 2", fixture)
        XCTAssertThrowsError(try fixture.db.heroDao.getSelectedHeroIds())
        XCTAssertThrowsError(try fixture.db.heroDao.getSelectedHeroes())
    }

    func testAllHeroesRequireCombatEvenWhenNotSelected() throws {
        let fixture = try AuthoredDatabaseFixture()
        let selected = try fixture.db.heroDao.getSelectedHeroIds()
        let hero = try XCTUnwrap(fixture.db.heroDao.getAll().first { !selected.contains($0.id) })
        try execute("DELETE FROM hero_combat WHERE hero_id = '\(hero.id.uuidString.lowercased())'", fixture)
        XCTAssertThrowsError(try fixture.db.heroDao.validateAuthoredContent()) {
            XCTAssertTrue(String(describing: $0).contains(hero.id.uuidString), "\($0)")
        }
    }

    func testHeroCombatLookupRejectsDuplicateRows() throws {
        let fixture = try AuthoredDatabaseFixture()
        let hero = try XCTUnwrap(fixture.db.heroDao.getAll().first)
        try relax("hero_combat", fixture)
        try execute("INSERT INTO hero_combat SELECT * FROM hero_combat", fixture)
        XCTAssertThrowsError(try fixture.db.heroDao.getCombatStats(heroID: hero.id))
    }

    func testMissingArtworkFailsForEveryHeroAndRequiredImageField() throws {
        let fixture = try AuthoredDatabaseFixture()
        for hero in try fixture.db.heroDao.validateAuthoredContent() {
            let images = [("primary_image_name", hero.primaryImageName), ("icon_image_name", hero.iconImageName),
                          ("ability_icon_image_name", hero.abilityIconImageName), ("unit_image_name", hero.unitImageName)]
            let available = Set(images.map { $0.1 })
            XCTAssertNoThrow(try hero.validateArtwork { available.contains($0) })
            for (field, absent) in images {
                XCTAssertThrowsError(try hero.validateArtwork { $0 != absent }, field) {
                    let message = String(describing: $0)
                    XCTAssertTrue(message.contains(hero.id.uuidString), message)
                    XCTAssertTrue(message.contains(field), message)
                    XCTAssertTrue(message.contains(absent), message)
                }
            }
        }
    }

    func testUnknownSpriteProfilesFailInsteadOfReturningGenericDimensions() throws {
        let fixture = try AuthoredDatabaseFixture()
        let unknown = "missing_hero_sprite"
        XCTAssertThrowsError(try HeroSpriteProfile.load(baseAssetName: unknown))
        try execute("UPDATE hero SET unit_image_name = '\(unknown)'", fixture)
        XCTAssertThrowsError(try fixture.db.heroDao.getAll()) {
            XCTAssertTrue(String(describing: $0).contains("unit_image_name"), "\($0)")
        }
    }

    func testAuthoredProfilesPreserveExactSizeAndGroundInset() throws {
        let fixture = try AuthoredDatabaseFixture()
        for hero in try fixture.db.heroDao.getAll() {
            let profile = try HeroSpriteProfile.load(baseAssetName: hero.unitImageName)
            XCTAssertEqual(MapSpriteSizing.hero(baseAssetName: hero.unitImageName), profile.imageHeight)
            XCTAssertEqual(MapSpriteSizing.heroGroundInset(baseAssetName: hero.unitImageName, spriteHeight: 100),
                           profile.groundInsetFraction * 100)
        }
    }

    func testHeroTextAndPortraitReferencesTrackDatabaseEdits() throws {
        let fixture = try AuthoredDatabaseFixture()
        let hero = try XCTUnwrap(fixture.db.heroDao.getAll().first)
        try execute("""
            UPDATE hero SET short_name = 'Changed short name', long_name = 'Changed long name',
                general_description = 'Changed description', historical_description = 'Changed history',
                historical_text = 'Changed historical text', primary_image_name = 'changed_portrait',
                icon_image_name = 'changed_icon', ability_icon_image_name = 'changed_ability'
            WHERE id = '\(hero.id.uuidString.lowercased())';
            """, fixture)
        let changed = try XCTUnwrap(fixture.db.heroDao.getAll().first { $0.id == hero.id })
        XCTAssertEqual(changed.shortName, "Changed short name")
        XCTAssertEqual(changed.longName, "Changed long name")
        XCTAssertEqual(changed.generalDescription, "Changed description")
        XCTAssertEqual(changed.historicalDescription, "Changed history")
        XCTAssertEqual(changed.historicalText, "Changed historical text")
        XCTAssertEqual(changed.primaryImageName, "changed_portrait")
        XCTAssertEqual(changed.iconImageName, "changed_icon")
        XCTAssertEqual(changed.abilityIconImageName, "changed_ability")
    }
}
