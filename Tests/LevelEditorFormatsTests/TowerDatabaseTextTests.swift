import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerDatabaseTextTests: XCTestCase {
    private func withDatabase(_ body: (Db, OpaquePointer) throws -> Void) throws {
        let fixture = try AuthoredDatabaseFixture()
        try body(fixture.db, fixture.connection)
    }

    func testEveryMenuNameAndDescriptionTracksDatabaseEdits() throws {
        try withDatabase { db, sql in
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE tower SET tower_name = 'Renamed ' || tower_level || ':' || branch,
                    tower_description = 'Rewritten ' || tower_level || ':' || branch;
                """, nil, nil, nil), SQLITE_OK)
            let names = try db.towerTypeDao.getNamesByLevel()
            let details = try db.towerTypeDao.getMenuDetailsByLevel()
            var count = 0
            for (category, levels) in details {
                for (level, branches) in levels {
                    for (branch, text) in branches {
                        XCTAssertEqual(text.name, "Renamed \(level):\(branch)")
                        XCTAssertEqual(text.description, "Rewritten \(level):\(branch)")
                        XCTAssertEqual(names[category]?[level]?[branch], text.name)
                        count += 1
                    }
                }
            }
            XCTAssertEqual(count, 23)
        }
    }

    func testDesignNamesTrackDatabaseEditsWithoutChangingKeysOrTuning() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE design_emplacement SET tower_name = 'Renamed ' || emplacement_key,
                    short_name = 'Short ' || emplacement_key;
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            for e in Emplacement.allCases {
                XCTAssertEqual(after.type(e).name, "Renamed \(e.rawValue)")
                XCTAssertEqual(after.shortName(e), "Short \(e.rawValue)")
                XCTAssertEqual(after.type(e).id, before.type(e).id)
                XCTAssertEqual(after.type(e).levels, before.type(e).levels)
                XCTAssertEqual(after.emplacement(for: e.rawValue), e)
            }
        }
    }

    func testEditorAcceptsExistingDisplayValuesAndStableKeys() throws {
        try withDatabase { db, _ in
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            let canvas = try db.virtualCanvasDao.get()
            for e in Emplacement.allCases {
                for value in [e.rawValue, arsenal.type(e).name] {
                    var draft = MapDraft.starter
                    draft.slots = [Point(200, 200)]
                    draft.intendedSolution = [.init(at: 1, kind: "place", emplacement: value, slot: 0)]
                    let blueprint = try draft.makeBlueprint(virtualCanvas: canvas, arsenal: arsenal)
                    guard case let .place(resolved, slot) = try XCTUnwrap(blueprint.intendedSolution.first).order else {
                        return XCTFail("Expected a tower placement")
                    }
                    XCTAssertEqual(resolved, e)
                    XCTAssertEqual(slot, 0)
                    XCTAssertTrue(try SwiftExport.code(for: draft, arsenal: arsenal).contains(".place(.\(e), slot: 0)"))
                }
            }
            var invalid = MapDraft.starter
            invalid.slots = [Point(200, 200)]
            invalid.intendedSolution = [.init(at: 1, kind: "place", emplacement: UUID().uuidString, slot: 0)]
            XCTAssertThrowsError(try invalid.makeBlueprint(virtualCanvas: canvas, arsenal: arsenal))
            XCTAssertThrowsError(try SwiftExport.code(for: invalid, arsenal: arsenal))
        }
    }

    func testMissingDesignTextFailsInsteadOfInventingNames() throws {
        try withDatabase { db, sql in
            XCTAssertEqual(sqlite3_exec(sql, "DELETE FROM design_emplacement", nil, nil, nil), SQLITE_OK)
            XCTAssertThrowsError(try db.towerTypeDao.getDesignArsenal())
        }
    }

    func testDesignTuningTracksDatabaseEditsForEveryTier() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE design_emplacement_level SET
                    cost = 1000 + tower_level, tower_range = 800 + tower_level,
                    fire_interval = 10 + tower_level,
                    shot_min_damage = 20 + tower_level, shot_max_damage = 30 + tower_level,
                    terror_min = 40 + tower_level, terror_max = 50 + tower_level,
                    aoe_radius = 60 + tower_level, aoe_falloff_exponent = 2 + tower_level,
                    splash_cover_pierce = 0.42, contagion_chance = 0.37,
                    targeting = 'last', projectile_speed = 900 + tower_level,
                    has_demolition_charge = 1, has_engineer_obstacles = 1,
                    demolition_prepare_seconds = 12 + tower_level,
                    obstacle_radius = 70 + tower_level, obstacle_slow_fraction = 0.29;
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            for emplacement in Emplacement.allCases {
                let original = before.type(emplacement)
                let updated = after.type(emplacement)
                XCTAssertEqual(updated.id, original.id)
                XCTAssertEqual(updated.name, original.name)
                XCTAssertEqual(updated.levels.count, original.levels.count)
                for (index, level) in updated.levels.enumerated() {
                    let tier = Double(index + 1)
                    XCTAssertEqual(level.cost, 1000 + index + 1)
                    XCTAssertEqual(level.range, 800 + tier)
                    XCTAssertEqual(level.fireInterval, 10 + tier)
                    XCTAssertEqual(level.shotMinDamage, 20 + tier)
                    XCTAssertEqual(level.shotMaxDamage, 30 + tier)
                    XCTAssertEqual(level.terrorMin, 40 + tier)
                    XCTAssertEqual(level.terrorMax, 50 + tier)
                    XCTAssertEqual(level.aoeRadius, 60 + tier)
                    XCTAssertEqual(level.aoeFalloffExponent, 2 + tier)
                    XCTAssertEqual(level.splashCoverPierce, 0.42)
                    XCTAssertEqual(level.contagionChance, 0.37)
                    XCTAssertEqual(level.targeting, .last)
                    XCTAssertEqual(level.projectileSpeed, 900 + tier)
                    XCTAssertEqual(level.demolitionPreparationSeconds, 12 + tier)
                    XCTAssertEqual(level.engineerObstacles, .init(radius: 70 + tier, slowFraction: 0.29))
                }
            }
        }
    }

    func testDesignLevelCountAndOrderingComeFromDatabase() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(sqlite3_exec(sql, """
                INSERT INTO design_emplacement_level (
                    emplacement_key, tower_level, cost, tower_range, fire_interval,
                    shot_min_damage, shot_max_damage, terror_min, terror_max,
                    aoe_radius, aoe_falloff_exponent, splash_cover_pierce,
                    contagion_chance, targeting, projectile_speed,
                    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction,
                    has_melee_unit, has_demolition_charge, has_engineer_obstacles)
                SELECT emplacement_key, tower_level + 1, cost, tower_range, fire_interval,
                       shot_min_damage, shot_max_damage, terror_min, terror_max,
                       aoe_radius, aoe_falloff_exponent, splash_cover_pierce,
                       contagion_chance, targeting, projectile_speed,
                       demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction,
                       has_melee_unit, has_demolition_charge, has_engineer_obstacles
                FROM design_emplacement_level AS source
                WHERE tower_level = (SELECT MAX(tower_level) FROM design_emplacement_level
                    WHERE emplacement_key = source.emplacement_key);
                UPDATE design_emplacement SET level_count = level_count + 1;
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            for emplacement in Emplacement.allCases {
                let original = before.type(emplacement).levels
                XCTAssertEqual(after.type(emplacement).levels, original + [try XCTUnwrap(original.last)])
            }
        }
    }

    func testMissingDesignTiersFailInsteadOfFallingBackToSwift() throws {
        for deletion in [
            "DELETE FROM design_emplacement_level WHERE tower_level = 2",
            "DELETE FROM design_emplacement_level"
        ] {
            try withDatabase { db, sql in
                XCTAssertEqual(sqlite3_exec(sql, deletion, nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDesignArsenal())
            }
        }
    }

    func testInvalidDesignTuningFailsInsteadOfSupplyingDefaults() throws {
        for assignment in ["targeting = 'invalid'", "tower_range = -1", "obstacle_radius = 1",
                           "cost = 1.5", "fire_interval = 'invalid'", "demolition_prepare_seconds = 'invalid'"] {
            try withDatabase { db, sql in
                XCTAssertEqual(sqlite3_exec(sql, "PRAGMA ignore_check_constraints = ON", nil, nil, nil), SQLITE_OK)
                XCTAssertEqual(sqlite3_exec(sql, "UPDATE design_emplacement_level SET \(assignment)", nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDesignArsenal())
            }
        }
    }
}
