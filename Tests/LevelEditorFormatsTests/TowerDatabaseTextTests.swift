import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerDatabaseTextTests: XCTestCase {
    private func withDatabase(_ body: (Db, OpaquePointer) throws -> Void) throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
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
            XCTAssertEqual(count, 29)
        }
    }

    func testDesignNamesTrackGameplayDatabaseEditsWithoutChangingKeysOrTuning() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(sqlite3_exec(sql, "UPDATE tower_type SET tower_type_name = 'Renamed ' || tower_type_category", nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            let gameplay = try db.towerTypeDao.getTowerTypes()
            for tower in after.towers {
                XCTAssertEqual(tower.name, "Renamed \(tower.category)")
                XCTAssertEqual(after.type(tower.kind), gameplay[tower.kind])
                XCTAssertEqual(tower.id, before.type(tower.kind).id)
                XCTAssertEqual(tower.type.levels, before.type(tower.kind).levels)
                XCTAssertEqual(after.emplacement(for: tower.kind.rawValue), tower.kind)
            }
        }
    }

    func testAllFamilyAndCategoryLabelsCanChangeWithoutChangingLookupKeys() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            let ranges = try db.simBoundsDao.getTowerRanges()
            let brackets = try db.simMeleeUnitDao.getBrackets()
            let levelID = try XCTUnwrap(db.levelInfoDao.getCampaignLevels(campaignName: "Main").first?.id)
            let unlocks = try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelID)
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE tower_type SET tower_type_name = 'Display ' || tower_type_key,
                    tower_type_category = 'Category ' || tower_type_key;
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            let labels = try db.towerTypeDao.getDisplayNames()
            for tower in after.towers {
                XCTAssertEqual(tower.name, "Display \(tower.kind.rawValue)")
                XCTAssertEqual(tower.category, "Category \(tower.kind.rawValue)")
                XCTAssertEqual(labels[tower.kind], tower.name)
                XCTAssertEqual(tower.id, before.type(tower.kind).id)
                XCTAssertEqual(tower.type.levels, before.type(tower.kind).levels)
            }
            XCTAssertEqual(try db.towerUnlockDao.getUnlocksFor(levelInfoId: levelID), unlocks)
            let renamedRanges = try db.simBoundsDao.getTowerRanges()
            let renamedBrackets = try db.simMeleeUnitDao.getBrackets()
            XCTAssertEqual(Set(renamedRanges.keys), Set(ranges.keys))
            XCTAssertEqual(Set(renamedBrackets.keys), Set(brackets.keys))
            for (key, levels) in ranges {
                for (level, range) in levels {
                    XCTAssertEqual(renamedRanges[key]?[level]?.values, range.values)
                }
            }
            for (key, levels) in brackets {
                for (level, bracket) in levels {
                    XCTAssertEqual(renamedBrackets[key]?[level]?.hp, bracket.hp)
                    XCTAssertEqual(renamedBrackets[key]?[level]?.averageDamage, bracket.averageDamage)
                }
            }
        }
    }

    func testMatchingDisplayLabelsCannotMergeDistinctTowerIdentities() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getTowerLevelsByBranch()
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE tower_type SET tower_type_category = 'Shared category', tower_type_name = 'Shared label';
                """, nil, nil, nil), SQLITE_OK)
            XCTAssertEqual(try db.towerTypeDao.getTowerLevelsByBranch(), before)
            let labels = try db.towerTypeDao.getDisplayNames()
            XCTAssertEqual(Set(labels.keys), Set(TowerKind.allCases))
            XCTAssertTrue(labels.values.allSatisfy { $0 == "Shared label" })
        }
    }

    func testTowerLabelsAndStableKeysCannotBeMissingOrMalformed() throws {
        try withDatabase { db, sql in
            XCTAssertEqual(sqlite3_exec(sql, """
                CREATE TABLE test_rows AS SELECT * FROM tower_type;
                DROP TABLE tower_type;
                ALTER TABLE test_rows RENAME TO tower_type;
                """, nil, nil, nil), SQLITE_OK)
            for field in ["tower_type_key", "tower_type_name", "tower_type_category"] {
                for value in ["NULL", "''", "'   '", "X'00FF'"] {
                    XCTAssertEqual(sqlite3_exec(sql, "SAVEPOINT invalid_label; UPDATE tower_type SET \(field) = \(value)",
                                               nil, nil, nil), SQLITE_OK)
                    XCTAssertThrowsError(try db.towerTypeDao.getDisplayNames()) {
                        XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
                    }
                    XCTAssertEqual(sqlite3_exec(sql, "ROLLBACK TO invalid_label; RELEASE invalid_label",
                                               nil, nil, nil), SQLITE_OK)
                }
                XCTAssertEqual(sqlite3_exec(sql, "SAVEPOINT missing_column; ALTER TABLE tower_type DROP COLUMN \(field)",
                                           nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDisplayNames())
                XCTAssertEqual(sqlite3_exec(sql, "ROLLBACK TO missing_column; RELEASE missing_column",
                                           nil, nil, nil), SQLITE_OK)
            }
            for value in ["'unknown_tower'", "tower_type_name", "'\(TowerKind.ranged.rawValue)'"] {
                XCTAssertEqual(sqlite3_exec(sql, "SAVEPOINT invalid_key; UPDATE tower_type SET tower_type_key = \(value)",
                                           nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDisplayNames())
                XCTAssertEqual(sqlite3_exec(sql, "ROLLBACK TO invalid_key; RELEASE invalid_key", nil, nil, nil), SQLITE_OK)
            }
        }
    }

    func testEditorUsesStableGameplayKeysAndRejectsUnknownKeys() throws {
        try withDatabase { db, sql in
            XCTAssertEqual(sqlite3_exec(sql, "UPDATE tower_type SET tower_type_name = 'Display ' || tower_type_category", nil, nil, nil), SQLITE_OK)
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            let canvas = try db.virtualCanvasDao.get()
            for kind in arsenal.kinds {
                var draft = MapDraft.starter
                draft.slots = [Point(200, 200)]
                draft.intendedSolution = [.init(at: 1, kind: "place", emplacement: kind.rawValue, slot: 0)]
                let blueprint = try draft.makeBlueprint(virtualCanvas: canvas, arsenal: arsenal)
                guard case let .place(resolved, slot) = try XCTUnwrap(blueprint.intendedSolution.first).order else {
                    return XCTFail("Expected a tower placement")
                }
                XCTAssertEqual(resolved, kind)
                XCTAssertEqual(slot, 0)
                XCTAssertTrue(try SwiftExport.code(for: draft, arsenal: arsenal).contains(".place(.\(kind), slot: 0)"))
                XCTAssertNil(arsenal.emplacement(for: arsenal.type(kind).name))
            }
            var invalid = MapDraft.starter
            invalid.slots = [Point(200, 200)]
            for key in [nil, UUID().uuidString, "removedDesignTower"] as [String?] {
                invalid.intendedSolution = [.init(at: 1, kind: "place", emplacement: key, slot: 0)]
                XCTAssertThrowsError(try invalid.makeBlueprint(virtualCanvas: canvas, arsenal: arsenal))
                XCTAssertThrowsError(try SwiftExport.code(for: invalid, arsenal: arsenal))
            }
        }
    }

    func testDesignAndGameplayUseIdenticalRecordsIncludingEveryBranch() throws {
        try withDatabase { db, _ in
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            let gameplay = try db.towerTypeDao.getTowerTypes()
            let levels = try db.towerTypeDao.getTowerLevelsByBranch()
            let details = try db.towerTypeDao.getMenuDetailsByLevel()
            let rows = try db.towerTypeDao.authoredRows("SELECT id FROM tower", entity: "tower") { try $0.uuid("id") }
            XCTAssertEqual(Set(arsenal.towers.flatMap(\.tiers).map(\.id)), Set(rows))
            for tower in arsenal.towers {
                XCTAssertEqual(tower.type, gameplay[tower.kind])
                for tier in tower.tiers {
                    XCTAssertEqual(tier.tuning, levels[tower.kind]?[tier.level]?[tier.branch])
                    XCTAssertEqual(tier.details, details[tower.kind]?[tier.level]?[tier.branch])
                }
            }
            let catalog = arsenal.catalog(roster: try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()))
            XCTAssertEqual(Set(catalog.towerTypes.map(\.id)), Set(gameplay.values.map(\.id)))
        }
    }

    @MainActor func testDatabaseTowerIdentityChangesReachScriptedPlaytests() throws {
        try withDatabase { db, sql in
            let original = try db.towerTypeDao.getDesignArsenal().type(.ranged).id
            let changed = UUID()
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE tower_type SET id = '\(changed.uuidString.lowercased())' WHERE id = '\(original.uuidString.lowercased())';
                UPDATE tower SET tower_type_id = '\(changed.uuidString.lowercased())' WHERE tower_type_id = '\(original.uuidString.lowercased())';
                """, nil, nil, nil), SQLITE_OK)
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(arsenal.type(.ranged).id, changed)
            XCTAssertEqual(arsenal.kind(forTowerID: changed), .ranged)
            let content = try BattleTestFixture.authored(db: db)
            let simulation = try GameSimulation(content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
            let final = try XCTUnwrap(arsenal.towers.first { $0.id == changed }?.tiers.first { $0.level == 4 })
            var order = ScriptedBuildOrder(steps: [.init(time: 0, action: .build(slot: 0, towerID: final.id))])
            try order.tick(sim: simulation)
            let built = try XCTUnwrap(simulation.towers.first)
            XCTAssertEqual(built.kind, .ranged)
            XCTAssertEqual(content.arsenal.type(built.kind).id, changed)
        }
    }

    func testDesignTuningAndRangePreviewsTrackGameplayEditsForEveryTier() throws {
        try withDatabase { db, sql in
            XCTAssertEqual(sqlite3_exec(sql, """
                UPDATE tower SET
                    cost = 1000 + tower_level, tower_range = 800 + tower_level + branch,
                    fire_interval = 10 + tower_level,
                    shot_min_damage = 20 + tower_level, shot_max_damage = 30 + tower_level,
                    terror_min = 40 + tower_level, terror_max = 50 + tower_level,
                    aoe_radius = 60 + tower_level, aoe_falloff_exponent = 2 + tower_level,
                    splash_cover_pierce = 0.42, contagion_chance = 0.37,
                    targeting = 'last', projectile_speed = 900 + tower_level,
                    attack_mode = CASE WHEN attack_mode = 'none' THEN 'demolition' ELSE attack_mode END,
                    has_demolition_charge = 1, has_engineer_obstacles = 1,
                    demolition_prepare_seconds = 12 + tower_level,
                    obstacle_radius = 70 + tower_level, obstacle_slow_fraction = 0.29, obstacle_width_fraction = 0.61;
                UPDATE tower SET tower_range = 2000 WHERE branch > 1;
                """, nil, nil, nil), SQLITE_OK)
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            let gameplay = try db.towerTypeDao.getTowerLevelsByBranch()
            for tower in arsenal.towers {
                for tier in tower.tiers {
                    let value = tier.tuning
                    let level = Double(tier.level)
                    XCTAssertEqual(value, gameplay[tower.kind]?[tier.level]?[tier.branch])
                    XCTAssertEqual(value.cost, 1000 + tier.level)
                    XCTAssertEqual(value.range, tier.branch > 1 ? 2000 : 800 + level + Double(tier.branch))
                    XCTAssertEqual(value.fireInterval, 10 + level)
                    XCTAssertEqual(value.shotMinDamage, 20 + level)
                    XCTAssertEqual(value.shotMaxDamage, 30 + level)
                    XCTAssertEqual(value.terrorMin, 40 + level)
                    XCTAssertEqual(value.terrorMax, 50 + level)
                    XCTAssertEqual(value.aoeRadius, 60 + level)
                    XCTAssertEqual(value.aoeFalloffExponent, 2 + level)
                    XCTAssertEqual(value.splashCoverPierce, 0.42)
                    XCTAssertEqual(value.contagionChance, 0.37)
                    XCTAssertEqual(value.targeting, .last)
                    XCTAssertEqual(value.projectileSpeed, 900 + level)
                    XCTAssertEqual(value.demolitionPreparationSeconds, 12 + level)
                    XCTAssertEqual(value.engineerObstacles, .init(radius: 70 + level, slowFraction: 0.29, widthFraction: 0.61))
                }
            }
            XCTAssertEqual(arsenal.maximumRange, 2000, "Range previews must include specialization branches")
            XCTAssertEqual(arsenal.rangeRings.count, arsenal.towers.count)
            XCTAssertTrue(arsenal.rangeRings.allSatisfy { $0.range == 802 })
        }
    }

    func testDesignLevelCountAndOrderingComeFromGameplayDatabase() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            let type = before.type(.ranged)
            let id = UUID().uuidString.lowercased()
            XCTAssertEqual(sqlite3_exec(sql, """
                INSERT INTO tower (
                    upgrade_path_count,
                    income_per_wave, support_attack_speed_multiplier, support_heal_per_second,
                    id, tower_type_id, tower_name, tower_description, tower_level, branch,
                    cost, tower_range, fire_interval, shot_min_damage, shot_max_damage,
                    terror_min, terror_max, aoe_radius, aoe_falloff_exponent,
                    splash_cover_pierce, contagion_chance, targeting, projectile_speed,
                    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction, obstacle_width_fraction,
                    has_melee_unit, has_demolition_charge, has_engineer_obstacles, attack_mode, turn_rate_degrees)
                SELECT 0, income_per_wave, support_attack_speed_multiplier, support_heal_per_second,
                    '\(id)', tower_type_id, tower_name, tower_description, tower_level + 1, branch,
                    cost, tower_range, fire_interval, shot_min_damage, shot_max_damage,
                    terror_min, terror_max, aoe_radius, aoe_falloff_exponent,
                    splash_cover_pierce, contagion_chance, targeting, projectile_speed,
                    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction, obstacle_width_fraction,
                    has_melee_unit, has_demolition_charge, has_engineer_obstacles, attack_mode, turn_rate_degrees
                FROM tower WHERE tower_type_id = '\(type.id.uuidString.lowercased())' AND branch = 1
                ORDER BY tower_level DESC LIMIT 1;
                UPDATE tower_type SET level_layout = json_insert(level_layout, '$[#]', json('[1]'))
                WHERE id = '\(type.id.uuidString.lowercased())';
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            var added = try XCTUnwrap(type.levels.last)
            added.upgradePaths = [] // This authored fifth tier has no level-four upgrade paths.
            XCTAssertEqual(after.type(.ranged).levels, type.levels + [added])
        }
    }

    func testMissingGameplayRecordsFailForDesignConsumers() throws {
        for deletion in ["DELETE FROM tower_type", "DELETE FROM tower WHERE tower_level = 2",
                         "DELETE FROM tower WHERE branch > 1", "DELETE FROM tower"] {
            try withDatabase { db, sql in
                XCTAssertEqual(sqlite3_exec(sql, deletion, nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDesignArsenal())
            }
        }
    }

    func testInvalidGameplayTuningOrTextFailsForDesignConsumers() throws {
        for assignment in ["targeting = 'invalid'", "tower_range = -1", "obstacle_radius = 1",
                           "cost = 1.5", "fire_interval = 'invalid'", "demolition_prepare_seconds = 'invalid'",
                           "tower_name = ''", "tower_description = ''"] {
            try withDatabase { db, sql in
                XCTAssertEqual(sqlite3_exec(sql, "PRAGMA ignore_check_constraints = ON", nil, nil, nil), SQLITE_OK)
                XCTAssertEqual(sqlite3_exec(sql, "UPDATE tower SET \(assignment)", nil, nil, nil), SQLITE_OK)
                XCTAssertThrowsError(try db.towerTypeDao.getDesignArsenal())
            }
        }
    }
}
