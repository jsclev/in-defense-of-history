import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerSupportTests: XCTestCase {
    private func tier(_ level: Int, _ branch: Int = 1) throws -> TowerLevel {
        try AuthoredDatabaseFixture.tower(.supply, level: level, branch: branch)
    }

    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testSupportTuningIsRequiredAndDatabaseEditsPropagate() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            UPDATE tower SET income_per_wave = 123, support_attack_speed_multiplier = 1.8,
                support_heal_per_second = 17, tower_range = 321;
            """, fixture)
        for definition in try fixture.db.towerTypeDao.getDesignArsenal().towers {
            for value in definition.tiers.map(\.tuning) {
                XCTAssertEqual(value.support.incomePerWave, 123)
                XCTAssertEqual(value.support.attackSpeedMultiplier, 1.8)
                XCTAssertEqual(value.support.healPerSecond, 17)
                XCTAssertEqual(value.range, 321)
            }
        }
        try execute("""
            CREATE TABLE relaxed_tower AS SELECT * FROM tower;
            DROP TABLE tower;
            ALTER TABLE relaxed_tower RENAME TO tower;
            """, fixture)
        for (field, invalid) in [
            ("income_per_wave", "NULL"), ("income_per_wave", "-1"),
            ("support_attack_speed_multiplier", "NULL"),
            ("support_attack_speed_multiplier", "0.9"),
            ("support_heal_per_second", "NULL"), ("support_heal_per_second", "-1"),
            ("tower_range", "0")
        ] {
            try execute("SAVEPOINT invalid; UPDATE tower SET \(field) = \(invalid);", fixture)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal()) {
                XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
            }
            try execute("ROLLBACK TO invalid; RELEASE invalid", fixture)
        }
    }

    func testAurasUseTheDisplayedEllipseAndStrongestSource() throws {
        let ordnance = try tier(4, 2), hospital = try tier(4, 3)
        let sources = [ordnance, ordnance, hospital, hospital].map {
            TowerSupportSource(position: .zero, tuning: $0)
        }
        for point in [CGPoint.zero, CGPoint(x: ordnance.range, y: 0),
                      CGPoint(x: 0, y: hospital.range * hospital.combatRules.rangeVerticalFraction)] {
            XCTAssertEqual(TowerSupportSource.attackSpeed(at: point, for: .direct, sources: sources), 1.25)
            XCTAssertEqual(TowerSupportSource.healing(at: point, sources: sources), 8)
        }
        let outside = CGPoint(x: 0, y: hospital.range * hospital.combatRules.rangeVerticalFraction + 1)
        XCTAssertEqual(TowerSupportSource.attackSpeed(at: outside, for: .shell, sources: sources), 1)
        XCTAssertEqual(TowerSupportSource.healing(at: outside, sources: sources), 0)
        for mode in [TowerAttackMode.melee, .demolition, .obstacles, .none] {
            XCTAssertEqual(TowerSupportSource.attackSpeed(at: .zero, for: mode, sources: sources), 1)
        }
        var stronger = ordnance
        stronger.support.attackSpeedMultiplier = 1.5
        XCTAssertEqual(TowerSupportSource.attackSpeed(at: .zero, for: .solidShot,
            sources: sources + [.init(position: .zero, tuning: stronger)]), 1.5)
        XCTAssertEqual(TowerSupportSource.attackSpeed(at: .zero, for: .direct, sources: []), 1)
    }

    func testHealingWorksInCombatClampsAndNeverRevives() throws {
        let source = TowerSupportSource(position: .zero, tuning: try tier(4, 3))
        var unit = MilitiaUnit(position: Point(0, 0), hp: 10)
        unit.state = .fighting
        TowerSupportSource.heal(&unit, maximumHP: 50, seconds: 2, sources: [source, source])
        XCTAssertEqual(unit.hp, 26)
        TowerSupportSource.heal(&unit, maximumHP: 50, seconds: 100, sources: [source])
        XCTAssertEqual(unit.hp, 50)
        unit.hp = 10; unit.position = Point(1000, 0)
        TowerSupportSource.heal(&unit, maximumHP: 50, seconds: 2, sources: [source])
        XCTAssertEqual(unit.hp, 10)
        unit.position = Point(0, 0); unit.hp = 0; unit.state = .dead
        unit.respawnTicksLeft = 100
        TowerSupportSource.heal(&unit, maximumHP: 50, seconds: 100, sources: [source])
        XCTAssertEqual(unit.hp, 0)
        XCTAssertEqual(unit.respawnTicksLeft, 100)
    }

    @MainActor private func simulation(slots: [Point], waveTimes: [Double] = [0]) throws -> GameSimulation {
        let content = try BattleTestFixture.authored()
        var enemy = try XCTUnwrap(content.enemies.first { $0.key == "loyalist_militia" })
        enemy.stats.maxHP = 100_000; enemy.stats.speed = 0
        enemy.stats.damageMin = 5; enemy.stats.damageMax = 5
        let level = BattleTestFixture.level(enemy: enemy, slots: slots, waveTimes: waveTimes)
        return try GameSimulation(content: BattleTestFixture.content(level: level, enemies: [enemy], base: content),
                                  startingMoney: nil, heroesEnabled: false, seed: 42)
    }

    @MainActor func testIncomePaysAtWaveStartOnceAndUsesThePurchasedTier() throws {
        let sim = try simulation(slots: [Point(0, 100), Point(100, 100)], waveTimes: [0, 3, 5])
        try BattleTestFixture.build(.supply, in: sim)
        XCTAssertEqual(sim.result().goldEarned, 0)
        sim.startNextWave()
        XCTAssertEqual(sim.result().goldEarned, 15)
        XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok)
        try BattleTestFixture.build(.supply, slot: 1, in: sim)
        while sim.time < 2.5 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 15, "Purchases must not replay income")
        while sim.time < 3.1 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 60)
        XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok)
        XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok)
        while sim.time < 5.1 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 175)
        XCTAssertEqual(sim.gold, 100_000 - 100 - 150 - 100 - 220 - 300 + 175)
        while sim.time < 30 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 175)
    }

    @MainActor func testOrdnanceSpeedsRealShotsOnlyWithinRange() throws {
        func shots(depots: [Point]) throws -> Int {
            let sim = try simulation(slots: [Point(0, 20)] + depots)
            try BattleTestFixture.build(.ranged, in: sim)
            for index in depots.indices {
                try BattleTestFixture.build(.supply, level: 4, branch: 2, slot: index + 1, in: sim)
            }
            sim.startNextWave()
            for _ in 0..<630 { sim.step() }
            return sim.shotsBySlot[0, default: 0]
        }
        let baseline = try shots(depots: [])
        let boosted = try shots(depots: [Point(0, 40)])
        XCTAssertGreaterThan(boosted, baseline)
        XCTAssertEqual(try shots(depots: [Point(0, 40), Point(0, 60)]), boosted)
        XCTAssertEqual(try shots(depots: [Point(1000, 40)]), baseline)
    }

    @MainActor func testHospitalHealsActualFightingGarrisons() throws {
        func health(hospitalPoint: Point) throws -> Double {
            let sim = try simulation(slots: [Point(0, 0), hospitalPoint])
            try BattleTestFixture.build(.melee, in: sim)
            try BattleTestFixture.build(.supply, level: 4, branch: 3, slot: 1, in: sim)
            sim.startNextWave()
            for _ in 0..<480 { sim.step() }
            let soldiers = try XCTUnwrap(sim.engine.garrisonsBySlot[0]).units
            XCTAssertTrue(soldiers.contains { $0.state == .fighting })
            return soldiers.reduce(0) { $0 + $1.hp }
        }
        XCTAssertGreaterThan(try health(hospitalPoint: Point(0, 20)),
                             try health(hospitalPoint: Point(1000, 20)))
    }
}
