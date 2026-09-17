import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerAttributeAuthorityTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func relaxConstraints(_ table: String, in fixture: AuthoredDatabaseFixture) throws {
        try execute("""
            CREATE TABLE test_rows AS SELECT * FROM \(table);
            DROP TABLE \(table);
            ALTER TABLE test_rows RENAME TO \(table);
            """, in: fixture)
    }

    private func rejects(_ change: String, field: String, in fixture: AuthoredDatabaseFixture,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        try execute("SAVEPOINT corruption", in: fixture)
        defer { try? execute("ROLLBACK TO corruption; RELEASE corruption", in: fixture) }
        try execute(change, in: fixture)
        XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal(), file: file, line: line) {
            XCTAssertTrue(String(describing: $0).contains(field), "\($0)", file: file, line: line)
        }
        XCTAssertThrowsError(try fixture.db.towerTypeDao.validateAuthoredContent(), file: file, line: line) {
            XCTAssertTrue(String(describing: $0).contains(field), "\($0)", file: file, line: line)
        }
    }

    func testMissingAndMalformedScalarAttributesFailForCanonicalCatalog() throws {
        let numeric = ["cost", "tower_range", "fire_interval", "shot_min_damage", "shot_max_damage",
                       "terror_min", "terror_max", "aoe_radius", "aoe_falloff_exponent",
                       "splash_cover_pierce", "contagion_chance", "projectile_speed",
                       "has_melee_unit", "has_demolition_charge", "has_engineer_obstacles", "turn_rate_degrees"]
        for table in ["tower"] {
            let fixture = try AuthoredDatabaseFixture()
            try relaxConstraints(table, in: fixture)
            for field in numeric {
                for value in ["NULL", "'invalid'", "-1", "1e999"] {
                    try rejects("UPDATE \(table) SET \(field) = \(value)", field: field, in: fixture)
                }
            }
            for value in ["NULL", "''", "'unknown'"] {
                try rejects("UPDATE \(table) SET targeting = \(value)", field: "targeting", in: fixture)
            }
            try rejects("UPDATE \(table) SET cost = 1.5", field: "cost", in: fixture)
            try rejects("UPDATE \(table) SET tower_range = 0", field: "tower_range", in: fixture)
            try rejects("UPDATE \(table) SET aoe_falloff_exponent = 0", field: "aoe_falloff_exponent", in: fixture)
            for field in ["splash_cover_pierce", "contagion_chance"] {
                try rejects("UPDATE \(table) SET \(field) = 1.1", field: field, in: fixture)
            }
            try execute("ALTER TABLE \(table) DROP COLUMN projectile_speed", in: fixture)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.validateAuthoredContent())
        }
    }

    func testDeletingAnyAuthoredTowerTierFails() throws {
        let fixture = try AuthoredDatabaseFixture()
        for table in ["tower"] {
            let count = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers).count
            for offset in 0..<count {
                try rejects("DELETE FROM \(table) WHERE rowid = (SELECT rowid FROM \(table) LIMIT 1 OFFSET \(offset))",
                            field: "tower", in: fixture)
            }
        }
        try rejects("DELETE FROM tower_type", field: "tower_type", in: fixture)
        try rejects("DELETE FROM melee_unit", field: "melee_unit", in: fixture)
    }

    func testEveryMeleeAttributeIsRequiredAndValidated() throws {
        let fixture = try AuthoredDatabaseFixture()
        try relaxConstraints("melee_unit", in: fixture)
        for field in ["soldier_count", "attack_rating", "defense_rating", "hp", "rally_point_radius",
                      "attack_interval", "respawn_seconds", "heal_per_second"] {
            for value in ["NULL", "'invalid'", "-1", "1e999"] {
                try rejects("UPDATE melee_unit SET \(field) = \(value)", field: field, in: fixture)
            }
        }
    }

    func testEnabledCapabilitiesCannotLoseAttributesOrBecomeDisabledSilently() throws {
        let fixture = try AuthoredDatabaseFixture()
        try relaxConstraints("tower", in: fixture)
        for field in ["demolition_prepare_seconds", "obstacle_radius", "obstacle_slow_fraction"] {
            for value in ["NULL", "'invalid'", "0", "1e999"] {
                try rejects("UPDATE tower SET \(field) = \(value) WHERE \(field) IS NOT NULL",
                            field: field, in: fixture)
            }
        }
        try rejects("UPDATE tower SET has_melee_unit = 0 WHERE has_melee_unit = 1", field: "melee_unit", in: fixture)
        try rejects("UPDATE tower SET has_demolition_charge = 0 WHERE has_demolition_charge = 1",
                    field: "demolition_prepare_seconds", in: fixture)
        try rejects("UPDATE tower SET has_engineer_obstacles = 0 WHERE has_engineer_obstacles = 1",
                    field: "obstacle_radius", in: fixture)
        try fixture.db.towerTypeDao.validateAuthoredContent()
    }

    func testEveryGameplayAttributeTracksDatabaseEdits() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            UPDATE tower SET cost = 4321, tower_range = 765, fire_interval = 6.5,
                shot_min_damage = 21, shot_max_damage = 43, terror_min = 12, terror_max = 34,
                aoe_radius = 87, aoe_falloff_exponent = 2.3, splash_cover_pierce = 0.42,
                contagion_chance = 0.37, targeting = 'last', projectile_speed = 876;
            UPDATE tower SET demolition_prepare_seconds = 9 WHERE has_demolition_charge = 1;
            UPDATE tower SET obstacle_radius = 123, obstacle_slow_fraction = 0.27 WHERE has_engineer_obstacles = 1;
            UPDATE melee_unit SET soldier_count = 2, attack_rating = 42, defense_rating = 0.23,
                hp = 345, rally_point_radius = 456, attack_interval = 1.7,
                respawn_seconds = 11, heal_per_second = 3.4;
            """, in: fixture)
        let records = try fixture.db.towerTypeDao.getTowerLevelsByBranch()
        var count = 0
        for levels in records.values {
            for branches in levels.values {
                for value in branches.values {
                    XCTAssertEqual(value.cost, 4321)
                    XCTAssertEqual(value.range, 765)
                    XCTAssertEqual(value.fireInterval, 6.5)
                    XCTAssertEqual(value.shotMinDamage, 21)
                    XCTAssertEqual(value.shotMaxDamage, 43)
                    XCTAssertEqual(value.terrorMin, 12)
                    XCTAssertEqual(value.terrorMax, 34)
                    XCTAssertEqual(value.aoeRadius, 87)
                    XCTAssertEqual(value.aoeFalloffExponent, 2.3)
                    XCTAssertEqual(value.splashCoverPierce, 0.42)
                    XCTAssertEqual(value.contagionChance, 0.37)
                    XCTAssertEqual(value.targeting, .last)
                    XCTAssertEqual(value.projectileSpeed, 876)
                    if let charge = value.demolitionPreparationSeconds { XCTAssertEqual(charge, 9) }
                    if let obstacles = value.engineerObstacles {
                        XCTAssertEqual(obstacles, .init(radius: 123, slowFraction: 0.27, verticalFraction: AuthoredDatabaseFixture.combatRules.rangeVerticalFraction))
                    }
                    if let melee = value.meleeUnit {
                        XCTAssertEqual(melee, MeleeUnitStats(combatRules: AuthoredDatabaseFixture.combatRules, soldierCount: 2, attackRating: 42,
                            defenseRating: 0.23, hp: 345, rallyPointRadius: 456,
                            attackInterval: 1.7, respawnSeconds: 11, healPerSecond: 3.4))
                    }
                    count += 1
                }
            }
        }
        XCTAssertEqual(count, 23)
    }

    func testSerializedTuningRequiresEveryKeyIncludingDisabledCapabilities() throws {
        let tuning = try AuthoredDatabaseFixture.tower("Ranged", level: 1, branch: 1)
        let encoded = try JSONEncoder().encode(tuning)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(fields.count, 19)
        for field in fields.keys {
            var incomplete = fields
            incomplete.removeValue(forKey: field)
            let data = try JSONSerialization.data(withJSONObject: incomplete)
            XCTAssertThrowsError(try JSONDecoder().decode(TowerLevel.self, from: data), field)
        }
        XCTAssertEqual(try JSONDecoder().decode(TowerLevel.self, from: encoded), tuning)
    }

    func testSimulatorTowerGridsRequireAllFieldsAndKinds() throws {
        let fixture = try AuthoredDatabaseFixture()
        for profile in ["coarse", "fine"] {
            _ = try fixture.db.simTowerSweepDao.get(profile: profile)
        }
        let paths = ["upgradeGrowth", "falloff", "rof", "splash", "projectileSpeed", "rangeModes"]
            + ["rof.ranged", "splash.areaOfEffect", "projectileSpeed.special", "rangeModes.melee"]
        for path in paths {
            try execute("SAVEPOINT corruption", in: fixture)
            try execute("UPDATE sim_tower_sweep SET tuning = json_remove(tuning, '$.\(path)')", in: fixture)
            XCTAssertThrowsError(try fixture.db.simTowerSweepDao.get(profile: "coarse"), path)
            try execute("ROLLBACK TO corruption; RELEASE corruption", in: fixture)
        }
        for value in ["'[]'", "'[-1]'", "'[1e999]'", "'[null]'", "'[\"invalid\"]'"] {
            try execute("SAVEPOINT corruption", in: fixture)
            try execute("UPDATE sim_tower_sweep SET tuning = json_set(tuning, '$.upgradeGrowth', json(\(value)))", in: fixture)
            XCTAssertThrowsError(try fixture.db.simTowerSweepDao.get(profile: "coarse"), value)
            try execute("ROLLBACK TO corruption; RELEASE corruption", in: fixture)
        }
        try execute("UPDATE sim_tower_sweep SET tuning = json_set(tuning, '$.rof.ranged', json('[9.75]'))", in: fixture)
        XCTAssertEqual(try fixture.db.simTowerSweepDao.get(profile: "coarse").rof["ranged"], [9.75])
        try execute("DELETE FROM sim_tower_sweep", in: fixture)
        XCTAssertThrowsError(try fixture.db.simTowerSweepDao.get(profile: "coarse"))
    }

    func testSimulatorBoundsRejectMissingAndMalformedNumbers() throws {
        let fixture = try AuthoredDatabaseFixture()
        for (table, fields) in [("sim_tower_range", ["min_range", "max_range"]),
                                ("sim_melee_unit", ["min_hp", "max_hp", "min_damage", "max_damage"])] {
            try relaxConstraints(table, in: fixture)
            for field in fields {
                for value in ["NULL", "'invalid'", "-1", "1e999"] {
                    try execute("SAVEPOINT corruption", in: fixture)
                    try execute("UPDATE \(table) SET \(field) = \(value)", in: fixture)
                    if table == "sim_tower_range" {
                        XCTAssertThrowsError(try fixture.db.simBoundsDao.getTowerRanges(), field)
                    } else {
                        XCTAssertThrowsError(try fixture.db.simMeleeUnitDao.getBrackets(), field)
                    }
                    try execute("ROLLBACK TO corruption; RELEASE corruption", in: fixture)
                }
            }
        }
    }

    func testTowerUnlocksRequireExplicitDatabaseValuesIncludingLockedKinds() throws {
        let fixture = try AuthoredDatabaseFixture()
        let ids = try fixture.db.towerTypeDao.authoredRows("SELECT id FROM level_info", entity: "level_info") {
            try $0.uuid("id")
        }
        for id in ids {
            XCTAssertEqual(try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: id).count, TowerKind.allCases.count)
        }
        let id = try XCTUnwrap(ids.first)
        for value in ["NULL", "'invalid'", "-1", "99"] {
            try relaxUnlockAndReject(value, id: id, fixture: fixture)
        }
        try execute("DELETE FROM level_tower_unlock WHERE tower_kind = 'ranged'", in: fixture)
        XCTAssertThrowsError(try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: id))
    }

    private func relaxUnlockAndReject(_ value: String, id: UUID, fixture: AuthoredDatabaseFixture) throws {
        try execute("SAVEPOINT corruption", in: fixture)
        try relaxConstraints("level_tower_unlock", in: fixture)
        try execute("UPDATE level_tower_unlock SET max_tower_level = \(value)", in: fixture)
        XCTAssertThrowsError(try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: id))
        try execute("ROLLBACK TO corruption; RELEASE corruption", in: fixture)
    }

    func testTowerSchemaDoesNotSupplyAttributeDefaults() throws {
        let fixture = try AuthoredDatabaseFixture()
        for table in ["tower", "tower_type", "melee_unit", "level_tower_unlock"] {
            let rows = try fixture.db.towerTypeDao.authoredRows("PRAGMA table_info(\(table))", entity: table) { row in
                try row.requireNull("dflt_value")
            }
            XCTAssertFalse(rows.isEmpty)
        }
    }
}
