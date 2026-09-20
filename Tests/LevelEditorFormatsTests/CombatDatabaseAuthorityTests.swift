import XCTest
import SQLite3
@testable import LevelEditorFormats

final class CombatDatabaseAuthorityTests: XCTestCase {
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func columns(_ table: String, _ fixture: AuthoredDatabaseFixture) throws -> [String] {
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(fixture.connection, "PRAGMA table_info(\(table))", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var result: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(String(cString: sqlite3_column_text(statement, 1)))
            XCTAssertEqual(sqlite3_column_type(statement, 4), SQLITE_NULL, "Combat columns must not supply defaults")
        }
        return result
    }

    func testEverySharedRuleRequiresAnAuthoredValueAndColumn() throws {
        let fixture = try AuthoredDatabaseFixture()
        let fields = try columns("combat_rules", fixture)
        try execute("CREATE TABLE test_rules AS SELECT * FROM combat_rules; DROP TABLE combat_rules; ALTER TABLE test_rules RENAME TO combat_rules", fixture)
        for field in fields {
            for invalid in ["NULL", "'invalid'", "1e999"] {
                try execute("SAVEPOINT corrupt", fixture)
                try execute("UPDATE combat_rules SET \(field) = \(invalid)", fixture)
                XCTAssertThrowsError(try fixture.db.combatRulesDao.get(), field) {
                    XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
                }
                XCTAssertThrowsError(try fixture.db.towerTypeDao.getTowerLevelsByBranch(), field)
                try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
            }
            try execute("SAVEPOINT corrupt; ALTER TABLE combat_rules DROP COLUMN \(field)", fixture)
            XCTAssertThrowsError(try fixture.db.combatRulesDao.get(), field)
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
        try execute("DELETE FROM combat_rules", fixture)
        XCTAssertThrowsError(try fixture.db.combatRulesDao.get())
        XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal())
    }

    func testDatabaseEditsReachSharedCombatConsumers() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            UPDATE combat_rules SET morale_max=200, base_morale_regen_per_second=4,
                morale_recovery_delay=2, morale_visibility_threshold=180,
                morale_display_duration=0.5, morale_response_duration=2,
                range_vertical_fraction=0.4, melee_attack_spread=0.1,
                melee_post_spread=60, melee_spawn_spread=12,
                melee_engage_scan_radius_fraction=0.2, melee_leash_radius_fraction=0.8,
                melee_combat_spacing=55, arrival_radius=5, melee_reach=15,
                grapeshot_spread_degrees='[-20,0,20]', grapeshot_hit_radius=4,
                solid_shot_hit_radius=5, firing_tolerance_degrees=8,
                initial_heading_degrees=30, reinforcement_soldier_count=4;
            """, fixture)
        let rules = try fixture.db.combatRulesDao.get()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        XCTAssertEqual(arsenal.combatRules, rules)
        XCTAssertEqual(arsenal.catalog(roster: try DesignRoster(enemyTypes: fixture.db.enemyTypeDao.getAll())).combatRules, rules)
        let towers = try fixture.db.towerTypeDao.getTowerLevelsByBranch()
        let melee = try XCTUnwrap(towers[.melee]?[1]?[1]?.meleeUnit)
        XCTAssertEqual(melee.combatRules, rules)
        XCTAssertEqual(melee.damageRange.lowerBound, melee.attackRating * 0.9, accuracy: 1e-10)
        XCTAssertEqual(melee.engageScanRadius, melee.rallyPointRadius * 0.2)
        XCTAssertEqual(melee.leashRadius, melee.rallyPointRadius * 0.8)
        let ranged = try XCTUnwrap(towers[.ranged]?[1]?[1])
        XCTAssertEqual(ranged.attackRange.size.height, ranged.range * 0.8)
        XCTAssertEqual(MeleeFormation(rules: rules).postSpread, 60)
        XCTAssertEqual(MeleeFormation(rules: rules).spawnSpread, 12)
        var unit = MilitiaUnit(position: .zero, hp: 10)
        unit.combatSide = -1
        XCTAssertEqual(MilitiaAI.combatPosition(for: unit, target: Point(100, 0), rules: rules), Point(45, 0))
        var morale = EnemyMorale(rules: rules)
        XCTAssertEqual(morale.value, 200)
        morale.apply(loss: 40, direction: 1)
        XCTAssertTrue(morale.isVisible)
        morale.advance(seconds: 3)
        XCTAssertEqual(morale.value, 164)
        XCTAssertEqual(rules.grapeshotSpread, [-20 * .pi / 180, 0, 20 * .pi / 180])
        XCTAssertNil(GrapeshotFlight.hitFraction(from: .zero, to: CGPoint(x: 100, y: 0),
            target: CGPoint(x: 50, y: 5), radius: rules.grapeshotHitRadius))
        var shot = SolidShotFlight(range: 100, hitRadius: rules.solidShotHitRadius)
        XCTAssertEqual(shot.contacts(from: .zero, to: CGPoint(x: 100, y: 0),
            targets: [(1, CGPoint(x: 50, y: 5)), (2, CGPoint(x: 50, y: 6))]), [1])
        let aim = ArtilleryAim(heading: rules.initialHeading, firingTolerance: rules.firingTolerance)
        XCTAssertEqual(aim.heading, .pi / 6, accuracy: 1e-10)
        XCTAssertEqual(aim.firingTolerance, 8 * .pi / 180)
        XCTAssertEqual(rules.reinforcementSoldierCount, 4)
    }

    func testEverySharedNumberTracksItsOwnSQLColumn() throws {
        let fixture = try AuthoredDatabaseFixture()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        func values() throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(fixture.db.combatRulesDao.get())) as? [String: Any])
        }
        let before = try values()
        let fields = try columns("combat_rules", fixture).filter { $0 != "id" }
        XCTAssertEqual(Set(fields), Set(before.keys))
        for field in fields where field != "grapeshot_spread_degrees" {
            let old = try XCTUnwrap(before[field] as? NSNumber).doubleValue
            let updated: Double
            if field == "reinforcement_soldier_count" { updated = 7 }
            else if field == "morale_max" { updated = old * 1.5 }
            else { updated = old == 0 ? 0.125 : old * 0.75 }
            try execute("SAVEPOINT authored; UPDATE combat_rules SET \(field)=\(updated)", fixture)
            XCTAssertEqual(try XCTUnwrap(values()[field] as? NSNumber).doubleValue, updated, field)
            try execute("ROLLBACK TO authored; RELEASE authored", fixture)
        }
    }

    func testInvalidSharedRuleCombinationsAndAnglesFail() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("CREATE TABLE test_rules AS SELECT * FROM combat_rules; DROP TABLE combat_rules; ALTER TABLE test_rules RENAME TO combat_rules", fixture)
        for change in ["morale_max=0", "morale_visibility_threshold=morale_max+1",
                       "range_vertical_fraction=0", "range_vertical_fraction=1.1",
                       "melee_attack_spread=1.1", "enemy_swing_interval=0",
                       "projectile_hit_radius=0", "reinforcement_soldier_count=0",
                       "reinforcement_soldier_count=1.5", "base_morale_regen_per_second=0",
                       "grapeshot_spread_degrees='[]'", "grapeshot_spread_degrees='[0,0]'",
                       "grapeshot_spread_degrees='[181]'", "grapeshot_spread_degrees='[null]'",
                       "grapeshot_spread_degrees='[1e999]'", "grapeshot_spread_degrees='{}'"] {
            try execute("SAVEPOINT corrupt; UPDATE combat_rules SET \(change)", fixture)
            XCTAssertThrowsError(try fixture.db.combatRulesDao.get(), change)
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
        try execute("INSERT INTO combat_rules SELECT * FROM combat_rules", fixture)
        XCTAssertThrowsError(try fixture.db.combatRulesDao.get())
    }

    func testTowerAttackBehaviorAndTurnRateComeFromEachDatabaseRow() throws {
        let fixture = try AuthoredDatabaseFixture()
        for table in ["tower"] {
            try execute("SAVEPOINT authored", fixture)
            // A mode change must also author compatible service upgrades.
            try execute("""
                UPDATE \(table) SET attack_mode='solidShot', turn_rate_degrees=17, tower_range=300, fire_interval=1;
                UPDATE tower_upgrade_rank SET effects_json='[{"attribute":"turnRate","delta":1}]';
                """, fixture)
            let values = try fixture.db.towerTypeDao.getDesignArsenal().towers.flatMap(\.tiers).map(\.tuning)
            XCTAssertFalse(values.isEmpty)
            for value in values {
                XCTAssertEqual(value.attackMode, .solidShot)
                XCTAssertEqual(value.turnRate, 17 * .pi / 180)
            }
            try execute("ROLLBACK TO authored; RELEASE authored", fixture)
            try execute("CREATE TABLE test_towers AS SELECT * FROM \(table); DROP TABLE \(table); ALTER TABLE test_towers RENAME TO \(table)", fixture)
            for field in ["attack_mode", "turn_rate_degrees"] {
                for invalid in ["NULL", "'unknown'", "-1", "1e999"] {
                    try execute("SAVEPOINT corrupt; UPDATE \(table) SET \(field)=\(invalid)", fixture)
                    XCTAssertThrowsError(try fixture.db.towerTypeDao.validateAuthoredContent(), field)
                    try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
                }
            }
        }
    }

    func testPositiveFalloffIsNeverReplacedWithAMinimum() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("UPDATE tower SET aoe_falloff_exponent=0.005", fixture)
        let tuning = try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[.areaOfEffect]?[1]?[1])
        XCTAssertEqual(ArtilleryMoraleStrike(tuning: tuning).falloffExponent, 0.005)
    }

    func testEnemyAndHeroCombatAttributesCannotBeMissingOrMalformed() throws {
        for (table, fields) in [
            ("enemy_type", ["max_hp", "speed", "cover", "discipline", "hardiness", "damage_min", "damage_max",
                            "bounty", "lives_cost", "break_band_lo", "break_band_hi", "traits", "morale_speed_threshold",
                            "morale_attack_threshold", "morale_speed_multiplier", "morale_attack_multiplier"]),
            ("hero_combat", ["attack_rating", "defense_rating", "hp", "attack_interval", "respawn_seconds", "heal_per_second", "move_speed"])
        ] {
            let fixture = try AuthoredDatabaseFixture()
            let hero = try XCTUnwrap(fixture.db.heroDao.getAll().first)
            try execute("CREATE TABLE test_combat AS SELECT * FROM \(table); DROP TABLE \(table); ALTER TABLE test_combat RENAME TO \(table)", fixture)
            for field in fields {
                for invalid in ["NULL", "'invalid'", "-1", "1e999"] {
                    try execute("SAVEPOINT corrupt; UPDATE \(table) SET \(field)=\(invalid)", fixture)
                    if table == "enemy_type" { XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll(), field) }
                    else { XCTAssertThrowsError(try fixture.db.heroDao.getCombatStats(heroID: hero.id), field) }
                    try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
                }
            }
        }
        XCTAssertThrowsError(try JSONDecoder().decode(Trait.self,
            from: Data(#"{"type":"commandAura","radius":120,"disciplineBonus":0.25}"#.utf8)))
    }

    func testTraitTuningAndDifficultyNeverSupplyReplacements() throws {
        let fixture = try AuthoredDatabaseFixture()
        for json in [#"[{"type":"unknown"}]"#,
                     #"[{"type":"commandAura","radius":12,"disciplineBonus":0.2}]"#,
                     #"[{"type":"commandAura","radius":12,"disciplineBonus":0.2,"deathShock":-1}]"#,
                     #"[{"type":"rallyBeat","radius":-1,"moralePerSecond":2}]"#,
                     #"[{"type":"rallyBeat","radius":12,"moralePerSecond":null}]"#] {
            try execute("SAVEPOINT corrupt; UPDATE enemy_type SET traits='\(json)'", fixture)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll(), json)
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
        try execute("CREATE TABLE test_difficulty AS SELECT * FROM difficulty; DROP TABLE difficulty; ALTER TABLE test_difficulty RENAME TO difficulty", fixture)
        for invalid in ["NULL", "'invalid'", "-1", "0", "1e999"] {
            try execute("SAVEPOINT corrupt; UPDATE difficulty SET enemy_hp_multiplier=\(invalid)", fixture)
            XCTAssertThrowsError(try fixture.db.difficultyDao.getAll())
            XCTAssertThrowsError(try fixture.db.difficultyDao.requireSelected())
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
        try execute("UPDATE difficulty SET enemy_hp_multiplier=1.75", fixture)
        XCTAssertEqual(try fixture.db.difficultyDao.requireSelected().enemyHPMultiplier, 1.75)
        try execute("DELETE FROM player_selected_difficulty", fixture)
        XCTAssertThrowsError(try fixture.db.difficultyDao.requireSelected())
        _ = try columns("enemy_type", fixture)
        _ = try columns("hero_combat", fixture)
    }
}
