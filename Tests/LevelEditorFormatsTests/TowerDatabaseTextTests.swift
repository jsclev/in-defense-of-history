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

    func testDesignNamesTrackGameplayDatabaseEditsWithoutChangingKeysOrTuning() throws {
        try withDatabase { db, sql in
            let before = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(sqlite3_exec(sql, "UPDATE tower_type SET tower_type_name = 'Renamed ' || tower_type_category", nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            let gameplay = try db.towerTypeDao.getTowerTypes()
            for tower in after.towers {
                XCTAssertEqual(tower.name, "Renamed \(tower.category)")
                XCTAssertEqual(after.type(tower.kind), gameplay[tower.category])
                XCTAssertEqual(tower.id, before.type(tower.kind).id)
                XCTAssertEqual(tower.type.levels, before.type(tower.kind).levels)
                XCTAssertEqual(after.emplacement(for: tower.kind.rawValue), tower.kind)
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
                XCTAssertEqual(tower.type, gameplay[tower.category])
                for tier in tower.tiers {
                    XCTAssertEqual(tier.tuning, levels[tower.category]?[tier.level]?[tier.branch])
                    XCTAssertEqual(tier.details, details[tower.category]?[tier.level]?[tier.branch])
                }
            }
            let catalog = arsenal.catalog(roster: try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()))
            XCTAssertEqual(Set(catalog.towerTypes.map(\.id)), Set(gameplay.values.map(\.id)))
        }
    }

    func testDatabaseTowerIdentityChangesReachScriptedPlaytests() throws {
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
            let canvas = try db.virtualCanvasDao.get()
            var draft = MapDraft.starter
            draft.startingGold = arsenal.type(.ranged).levels[0].cost
            draft.roads = [.init(name: "Test path", points: [Point(100, 100), Point(600, 100)])]
            draft.slots = [Point(200, 200)]
            draft.intendedSolution = [.init(at: 0, kind: "place", emplacement: TowerKind.ranged.rawValue, slot: 0)]
            let blueprint = try draft.makeBlueprint(virtualCanvas: canvas, arsenal: arsenal)
            let catalog = arsenal.catalog(roster: try DesignRoster(enemyTypes: db.enemyTypeDao.getAll()))
            let simulation = try Simulation(level: blueprint.makeLevel(), catalog: catalog, policy: IdleCommander(), seed: 1)
            var order = blueprint.scriptedSolution(arsenal: arsenal)
            order.tick(time: 0, sim: simulation)
            let built = try XCTUnwrap(simulation.towers[0])
            XCTAssertEqual(catalog.towerTypes[built.typeIndex].id, changed)
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
                    has_demolition_charge = 1, has_engineer_obstacles = 1,
                    demolition_prepare_seconds = 12 + tower_level,
                    obstacle_radius = 70 + tower_level, obstacle_slow_fraction = 0.29;
                UPDATE tower SET tower_range = 2000 WHERE branch > 1;
                """, nil, nil, nil), SQLITE_OK)
            let arsenal = try db.towerTypeDao.getDesignArsenal()
            let gameplay = try db.towerTypeDao.getTowerLevelsByBranch()
            for tower in arsenal.towers {
                for tier in tower.tiers {
                    let value = tier.tuning
                    let level = Double(tier.level)
                    XCTAssertEqual(value, gameplay[tower.category]?[tier.level]?[tier.branch])
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
                    XCTAssertEqual(value.engineerObstacles, .init(radius: 70 + level, slowFraction: 0.29, verticalFraction: arsenal.combatRules.rangeVerticalFraction))
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
                    id, tower_type_id, tower_name, tower_description, tower_level, branch,
                    cost, tower_range, fire_interval, shot_min_damage, shot_max_damage,
                    terror_min, terror_max, aoe_radius, aoe_falloff_exponent,
                    splash_cover_pierce, contagion_chance, targeting, projectile_speed,
                    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction,
                    has_melee_unit, has_demolition_charge, has_engineer_obstacles, attack_mode, turn_rate_degrees)
                SELECT '\(id)', tower_type_id, tower_name, tower_description, tower_level + 1, branch,
                    cost, tower_range, fire_interval, shot_min_damage, shot_max_damage,
                    terror_min, terror_max, aoe_radius, aoe_falloff_exponent,
                    splash_cover_pierce, contagion_chance, targeting, projectile_speed,
                    demolition_prepare_seconds, obstacle_radius, obstacle_slow_fraction,
                    has_melee_unit, has_demolition_charge, has_engineer_obstacles, attack_mode, turn_rate_degrees
                FROM tower WHERE tower_type_id = '\(type.id.uuidString.lowercased())' AND branch = 1
                ORDER BY tower_level DESC LIMIT 1;
                UPDATE tower_type SET level_layout = json_insert(level_layout, '$[#]', json('[1]'))
                WHERE id = '\(type.id.uuidString.lowercased())';
                """, nil, nil, nil), SQLITE_OK)
            let after = try db.towerTypeDao.getDesignArsenal()
            XCTAssertEqual(after.type(.ranged).levels, type.levels + [try XCTUnwrap(type.levels.last)])
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
