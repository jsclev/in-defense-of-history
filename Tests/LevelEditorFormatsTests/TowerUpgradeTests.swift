import XCTest
import SQLite3
@testable import LevelEditorFormats

final class TowerUpgradeTests: XCTestCase {
    private func execute(_ sql: String, _ fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    private func fullyUpgrade(_ base: TowerLevel, reverse: Bool = false) -> TowerLevel {
        var state = TowerUpgradeProgress(), gold = 100_000
        let paths = reverse ? Array(base.upgradePaths.reversed()) : base.upgradePaths
        for path in paths {
            for _ in path.ranks { XCTAssertEqual(state.purchase(pathID: path.id, from: base, money: &gold), .ok) }
        }
        return base.upgraded(with: state)
    }

    func testEverySpecializationHasTwoIndependentCompletePathsAndDescriptions() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        var pathCount = 0, rankCount = 0, specialtyCount = 0
        for tower in arsenal.towers {
            for tier in tower.tiers {
                let base = tier.tuning
                if tier.level != 4 { XCTAssertTrue(base.upgradePaths.isEmpty); continue }
                specialtyCount += 1
                XCTAssertEqual(base.upgradePaths.map(\.slot), [1, 2])
                let menu = tier.details.including(upgrades: base.upgradePaths)
                var progress = TowerUpgradeProgress(), money = 100_000
                for path in base.upgradePaths {
                    pathCount += 1
                    XCTAssertGreaterThanOrEqual(path.ranks.count, 2)
                    XCTAssertTrue(menu.description.contains(path.name))
                    XCTAssertFalse(path.historicalBasis.isEmpty)
                    for rank in path.ranks {
                        rankCount += 1
                        XCTAssertTrue(menu.description.contains(rank.description))
                        let before = money, old = base.upgraded(with: progress)
                        XCTAssertEqual(progress.purchase(pathID: path.id, from: base, money: &money), .ok)
                        XCTAssertEqual(before - money, rank.cost)
                        XCTAssertEqual(progress.rank(for: path.id), rank.rank)
                        XCTAssertNotEqual(base.upgraded(with: progress), old, "Inert rank: \(path.id):\(rank.rank)")
                    }
                    let before = money
                    XCTAssertEqual(progress.purchase(pathID: path.id, from: base, money: &money), .invalid)
                    XCTAssertEqual(money, before, "Maxed paths must not spend coins")
                    XCTAssertTrue(path.menuDetails(purchasedRank: path.ranks.count).description.contains("Fully upgraded"))
                }
                XCTAssertEqual(fullyUpgrade(base), fullyUpgrade(base, reverse: true), "Track order changes results")
                XCTAssertEqual(base.upgraded(with: TowerUpgradeProgress()), base, "A new tower inherited upgrades")
            }
        }
        XCTAssertEqual(specialtyCount, 14)
        XCTAssertEqual(pathCount, 28)
        XCTAssertEqual(rankCount, 56)
    }

    func testUnaffordableUnknownAndPreSpecializationPurchasesAreAtomic() throws {
        let base = try AuthoredDatabaseFixture.tower(.ranged, level: 4, branch: 1)
        let path = base.upgradePaths[0]
        var state = TowerUpgradeProgress(), money = path.ranks[0].cost - 1
        let before = money
        XCTAssertEqual(state.purchase(pathID: path.id, from: base, money: &money), .needGold)
        XCTAssertEqual(state.rank(for: path.id), 0)
        XCTAssertEqual(money, before)
        money = path.ranks[0].cost
        XCTAssertEqual(state.purchase(pathID: path.id, from: base, money: &money), .ok)
        XCTAssertEqual(money, 0)
        XCTAssertEqual(state.rank(for: base.upgradePaths[1].id), 0)
        XCTAssertEqual(state.purchase(pathID: "unknown", from: base, money: &money), .invalid)
        let lower = try AuthoredDatabaseFixture.tower(.ranged, level: 3, branch: 1)
        money = 100_000
        XCTAssertEqual(state.purchase(pathID: path.id, from: lower, money: &money), .invalid)
        XCTAssertEqual(money, 100_000)
    }

    func testEverySpecialtyProducesItsPromisedFinalStats() throws {
        func maxed(_ kind: TowerKind, _ branch: Int) throws -> TowerLevel {
            fullyUpgrade(try AuthoredDatabaseFixture.tower(kind, level: 4, branch: branch))
        }
        let morgan = try maxed(.ranged, 1)
        XCTAssertEqual(morgan.shotMinDamage, 60)
        XCTAssertEqual(morgan.range, 635.61, accuracy: 1e-8)
        let knowlton = try maxed(.ranged, 2)
        XCTAssertEqual(knowlton.fireInterval, 0.6, accuracy: 1e-8)
        XCTAssertEqual(knowlton.range, 535.83, accuracy: 1e-8)
        let whitcomb = try maxed(.ranged, 3)
        XCTAssertEqual(whitcomb.shotMinDamage, 51)
        XCTAssertEqual(whitcomb.range, 600.02, accuracy: 1e-8)
        let regular = try XCTUnwrap(maxed(.melee, 1).meleeUnit)
        XCTAssertEqual(regular.attackRating, 20)
        XCTAssertEqual(regular.defenseRating, 0.4, accuracy: 1e-8)
        XCTAssertEqual(regular.hp, 290)
        let light = try XCTUnwrap(maxed(.melee, 2).meleeUnit)
        XCTAssertEqual(light.attackInterval, 0.9, accuracy: 1e-8)
        XCTAssertEqual(light.rallyPointRadius, 440.48, accuracy: 1e-8)
        XCTAssertEqual(light.defenseRating, 0.37, accuracy: 1e-8)
        let maryland = try XCTUnwrap(maxed(.melee, 3).meleeUnit)
        XCTAssertEqual(maryland.hp, 360)
        XCTAssertEqual(maryland.respawnSeconds, 6)
        XCTAssertEqual(maryland.healPerSecond, 8)
        let mortar = try maxed(.areaOfEffect, 1)
        XCTAssertEqual(mortar.shotMinDamage, 33.5)
        XCTAssertEqual(mortar.shotMaxDamage, 46.5)
        XCTAssertEqual(mortar.aoeRadius, 163.65, accuracy: 1e-8)
        XCTAssertEqual(mortar.fireInterval, 1.8, accuracy: 1e-8)
        XCTAssertEqual(mortar.terrorMax, 180)
        let swivel = try maxed(.areaOfEffect, 2)
        XCTAssertEqual(swivel.shotMinDamage, 14)
        XCTAssertEqual(swivel.shotMaxDamage, 18)
        XCTAssertEqual(swivel.fireInterval, 0.9, accuracy: 1e-8)
        XCTAssertEqual(swivel.turnRateDegrees, 300)
        let siege = try maxed(.areaOfEffect, 4)
        XCTAssertEqual(siege.shotMinDamage, 80)
        XCTAssertEqual(siege.shotMaxDamage, 100)
        XCTAssertEqual(siege.terrorMax, 200)
        XCTAssertEqual(siege.fireInterval, 3.6, accuracy: 1e-8)
        XCTAssertEqual(siege.turnRateDegrees, 45)
        let fieldworks = try maxed(.special, 2)
        XCTAssertEqual(fieldworks.range, 568.63, accuracy: 1e-8)
        XCTAssertEqual(fieldworks.engineerObstacles?.radius, 293)
        XCTAssertEqual(try XCTUnwrap(fieldworks.engineerObstacles?.slowFraction), 0.9, accuracy: 1e-8)
        let sapper = try maxed(.special, 3)
        XCTAssertEqual(sapper.shotMinDamage, 105)
        XCTAssertEqual(sapper.shotMaxDamage, 125)
        XCTAssertEqual(sapper.aoeRadius, 225)
        XCTAssertEqual(sapper.demolitionPreparationSeconds, 5)
        let quartermaster = try maxed(.supply, 1)
        XCTAssertEqual(quartermaster.support.incomePerWave, 160)
        XCTAssertEqual(quartermaster.support.healPerSecond, 5)
        XCTAssertEqual(quartermaster.range, 300)
        let ordnance = try maxed(.supply, 2)
        XCTAssertEqual(ordnance.support.attackSpeedMultiplier, 1.5, accuracy: 1e-8)
        XCTAssertEqual(ordnance.support.incomePerWave, 75)
        XCTAssertEqual(ordnance.range, 450)
        let hospital = try maxed(.supply, 3)
        XCTAssertEqual(hospital.support.healPerSecond, 18)
        XCTAssertEqual(hospital.range, 450)
    }

    func testDatabaseUpgradeEditsPropagateToPurchasesTextAndActualTuning() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            UPDATE tower_upgrade_path SET path_name='Authored aim', path_description='Authored practice'
                WHERE id='morgan_aim';
            UPDATE tower_upgrade_rank SET cost=77, rank_description='Authored stronger shot',
                effects_json='[{"attribute":"damage","delta":47}]' WHERE path_id='morgan_aim' AND rank=1;
            """, fixture)
        let base = try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[.ranged]?[4]?[1])
        let path = base.upgradePaths[0]
        XCTAssertEqual(path.name, "Authored aim")
        XCTAssertTrue(path.menuDetails(purchasedRank: 0).description.contains("Authored stronger shot"))
        var state = TowerUpgradeProgress(), money = 77
        XCTAssertEqual(state.purchase(pathID: path.id, from: base, money: &money), .ok)
        XCTAssertEqual(money, 0)
        XCTAssertEqual(base.upgraded(with: state).shotMinDamage, 77)
    }

    func testMissingMalformedAndIncompatibleUpgradeDataFailWithDiagnostics() throws {
        let fixture = try AuthoredDatabaseFixture()
        for table in ["tower_upgrade_path", "tower_upgrade_rank"] {
            try execute("CREATE TABLE relaxed AS SELECT * FROM \(table); DROP TABLE \(table); ALTER TABLE relaxed RENAME TO \(table);", fixture)
        }
        let mutations: [(String, String)] = [
            ("DELETE FROM tower_upgrade_path WHERE id='morgan_aim'", "path_id"),
            ("DELETE FROM tower_upgrade_rank WHERE path_id='morgan_aim' AND rank=2", "rank_count"),
            ("DELETE FROM tower_upgrade_rank WHERE path_id='morgan_aim' AND rank=1", "rank_count"),
            ("UPDATE tower_upgrade_path SET slot=1 WHERE id='morgan_rifle_practice'", "upgrade_path_count"),
            ("UPDATE tower_upgrade_path SET rank_count=1 WHERE id='morgan_aim'", "rank_count"),
            ("UPDATE tower_upgrade_path SET tower_id='unknown' WHERE id='morgan_aim'", "tower_id"),
            ("UPDATE tower_upgrade_path SET path_name=NULL WHERE id='morgan_aim'", "path_name"),
            ("UPDATE tower_upgrade_path SET icon_name='' WHERE id='morgan_aim'", "icon_name"),
            ("UPDATE tower_upgrade_path SET source_url='invalid' WHERE id='morgan_aim'", "source_url"),
            ("UPDATE tower_upgrade_rank SET cost=NULL WHERE path_id='morgan_aim'", "cost"),
            ("UPDATE tower_upgrade_rank SET cost=1.5 WHERE path_id='morgan_aim'", "cost"),
            ("UPDATE tower_upgrade_rank SET rank_description='' WHERE path_id='morgan_aim'", "rank_description"),
            ("UPDATE tower_upgrade_rank SET effects_json=NULL WHERE path_id='morgan_aim'", "effects_json"),
            ("UPDATE tower_upgrade_rank SET effects_json='[]' WHERE path_id='morgan_aim'", "effects_json"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"unknown\",\"delta\":1}]' WHERE path_id='morgan_aim'", "effects_json"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"damage\",\"delta\":0}]' WHERE path_id='morgan_aim'", "damage"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"damage\",\"delta\":1e999}]' WHERE path_id='morgan_aim'", "effects_json"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"obstacleSlow\",\"delta\":0.1}]' WHERE path_id='morgan_aim'", "obstacleSlow"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"fireInterval\",\"delta\":-0.5}]' WHERE path_id='knowlton_fire_discipline'", "fireInterval"),
            ("UPDATE tower_upgrade_rank SET effects_json='[{\"attribute\":\"obstacleSlow\",\"delta\":0.4}]' WHERE path_id='fieldworks_abatis'", "obstacleSlow")
        ]
        for (mutation, field) in mutations {
            try execute("SAVEPOINT corrupt; " + mutation, fixture)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.validateAuthoredContent(), mutation) {
                XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
            }
            try execute("ROLLBACK TO corrupt; RELEASE corrupt", fixture)
        }
        try fixture.db.towerTypeDao.validateAuthoredContent()
    }

    func testUpgradePreservesChargeSiteReadinessAndPreparationProgress() throws {
        let base = try AuthoredDatabaseFixture.tower(.special, level: 4, branch: 3)
        let upgraded = fullyUpgrade(base)
        var charge = DemolitionCharge(preparationSeconds: try XCTUnwrap(base.demolitionPreparationSeconds))
        charge.updatePreparation(seconds: try XCTUnwrap(upgraded.demolitionPreparationSeconds))
        XCTAssertTrue(charge.isReadyForPlacement)
        XCTAssertNil(charge.position)
        charge.place(at: CGPoint(x: 100, y: 0))
        XCTAssertTrue(charge.detonate())
        charge.advance(seconds: 2.5)
        charge.updatePreparation(seconds: 4)
        XCTAssertEqual(charge.progress, 0.5)
        XCTAssertEqual(charge.remainingSeconds, 2)
        XCTAssertEqual(charge.position, CGPoint(x: 100, y: 0))
        XCTAssertFalse(charge.detonate())
        charge.advance(seconds: 2)
        XCTAssertTrue(charge.detonate())
    }

    func testMeleeUpgradesPreserveWoundsDeathsAndTimerProgress() throws {
        let base = try AuthoredDatabaseFixture.tower(.melee, level: 4, branch: 3)
        let old = try XCTUnwrap(base.meleeUnit), new = try XCTUnwrap(fullyUpgrade(base).meleeUnit)
        var living = MilitiaUnit(position: Point(10, 20), hp: 70)
        living.state = .fighting
        living.applyUpgrade(from: old, to: new)
        XCTAssertEqual(living.hp, 210)
        XCTAssertEqual(living.state, .fighting)
        var dead = MilitiaUnit(position: Point(10, 20), hp: 0)
        dead.state = .dead; dead.respawnTicksLeft = 90
        dead.applyUpgrade(from: old, to: new)
        XCTAssertEqual(dead.hp, 0)
        XCTAssertEqual(dead.state, .dead)
        XCTAssertEqual(dead.respawnTicksLeft, 60)
    }

    func testPurchasedObstaclesAndAurasChangeRealSpatialEffects() throws {
        let base = try AuthoredDatabaseFixture.tower(.special, level: 4, branch: 2)
        let works = fullyUpgrade(base)
        let point = CGPoint(x: (try XCTUnwrap(base.engineerObstacles).radius
                                + XCTUnwrap(works.engineerObstacles).radius) / 2, y: 0)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: point, retreating: false,
            fields: [.init(position: .zero, stats: try XCTUnwrap(base.engineerObstacles), heading: 0)]), 1)
        XCTAssertEqual(EngineerObstacleField.movementMultiplier(at: point, retreating: false,
            fields: [.init(position: .zero, stats: try XCTUnwrap(works.engineerObstacles), heading: 0)]), 0.1, accuracy: 1e-8)
        let ordnance = fullyUpgrade(try AuthoredDatabaseFixture.tower(.supply, level: 4, branch: 2))
        let hospital = fullyUpgrade(try AuthoredDatabaseFixture.tower(.supply, level: 4, branch: 3))
        let sources = [ordnance, hospital, hospital].map { TowerSupportSource(position: .zero, tuning: $0) }
        XCTAssertEqual(TowerSupportSource.attackSpeed(at: CGPoint(x: 400, y: 0), for: .direct, sources: sources), 1.5, accuracy: 1e-8)
        var unit = MilitiaUnit(position: Point(400, 0), hp: 10); unit.state = .fighting
        TowerSupportSource.heal(&unit, maximumHP: 100, seconds: 2, sources: sources)
        XCTAssertEqual(unit.hp, 46)
        XCTAssertEqual(TowerSupportSource.healing(at: CGPoint(x: 451, y: 0), sources: sources), 0)
    }

    @MainActor private func simulation(kind: TowerKind, branch: Int, waveTimes: [Double] = [0]) throws -> GameSimulation {
        let content = try BattleTestFixture.authored()
        var enemy = try XCTUnwrap(content.enemies.first { $0.key == "loyalist_militia" })
        enemy.stats.maxHP = 100_000; enemy.stats.speed = 0; enemy.stats.cover = 0
        let level = BattleTestFixture.level(enemy: enemy, slots: [Point(200, 0), Point(220, 0)], waveTimes: waveTimes)
        let sim = try GameSimulation(content: BattleTestFixture.content(level: level, enemies: [enemy], base: content),
                                     startingMoney: nil, heroesEnabled: false, seed: 42)
        try BattleTestFixture.build(kind, level: 4, branch: branch, in: sim)
        sim.startNextWave()
        return sim
    }

    @MainActor func testRealProjectilesKeepOldDamageInFlightThenUsePurchasedDamage() throws {
        let sim = try simulation(kind: .ranged, branch: 1)
        for _ in 0..<60 {
            sim.step()
            if !sim.engine.projectiles.isEmpty { break }
        }
        let projectile = try XCTUnwrap(sim.engine.projectiles.first)
        XCTAssertEqual(projectile.damage, 30)
        XCTAssertEqual(try XCTUnwrap(sim.enemies.first).hp, 100_000)
        XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: "morgan_aim"), .ok)
        XCTAssertEqual(try XCTUnwrap(sim.engine.projectiles.first).damage, 30)
        for _ in 0..<60 {
            sim.step()
            if sim.enemies.first?.hp != 100_000 { break }
        }
        XCTAssertEqual(try XCTUnwrap(sim.enemies.first).hp, 99_970, accuracy: 1e-8)
        for _ in 0..<90 {
            sim.step()
            if sim.enemies.first?.hp != 99_970 { break }
        }
        XCTAssertEqual(try XCTUnwrap(sim.enemies.first).hp, 99_928, accuracy: 1e-8)
        try BattleTestFixture.build(.ranged, level: 4, branch: 1, slot: 1, in: sim)
        XCTAssertEqual(try XCTUnwrap(sim.towers.first { $0.slot == 1 }).tuning.shotMinDamage, 30)
    }

    @MainActor func testPurchasedFireDisciplineIncreasesActualShotCount() throws {
        func count(upgraded: Bool) throws -> Int {
            let sim = try simulation(kind: .ranged, branch: 2)
            if upgraded {
                XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: "knowlton_fire_discipline"), .ok)
                XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: "knowlton_fire_discipline"), .ok)
            }
            while sim.time < 10 { sim.step() }
            return sim.shotsBySlot[0, default: 0]
        }
        XCTAssertGreaterThan(try count(upgraded: true), try count(upgraded: false))
    }

    @MainActor func testPurchasedWagonsPayOnlyOnFutureWaveStarts() throws {
        let sim = try simulation(kind: .supply, branch: 1, waveTimes: [0, 3])
        XCTAssertEqual(sim.result().goldEarned, 100)
        let oldGold = sim.gold
        XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: "quartermaster_wagons"), .ok)
        XCTAssertEqual(sim.gold, oldGold - 150)
        XCTAssertEqual(sim.result().goldEarned, 100)
        while sim.time < 3.1 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 225)
        while sim.time < 4 { sim.step() }
        XCTAssertEqual(sim.result().goldEarned, 225)
    }
}
