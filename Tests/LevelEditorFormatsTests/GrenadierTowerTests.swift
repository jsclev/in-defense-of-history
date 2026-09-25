import XCTest
import SQLite3
@testable import LevelEditorFormats

final class GrenadierTowerTests: XCTestCase {
    private let id = "8de0f7a6-1152-4c49-bf35-623ac190a401"

    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testAuthoredStatsHistoryArtAndUpgradesFillTheFinalRosterSeat() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        XCTAssertEqual(arsenal.towers.flatMap(\.tiers).count, 30)
        XCTAssertTrue(arsenal.towers.allSatisfy { $0.tiers.count == 6 })
        let tier = try XCTUnwrap(arsenal.towers.first { $0.kind == .special }?.tiers.first {
            $0.level == 4 && $0.branch == 1
        })
        XCTAssertEqual(tier.details.name, "Grenadier Redoubt")
        XCTAssertTrue(tier.history.description.contains("fictional composite"))
        XCTAssertEqual(tier.history.sourceURL.host, "americanhistory.si.edu")
        XCTAssertEqual(tier.tuning.attackMode, .shell)
        XCTAssertEqual(tier.tuning.cost, 300)
        XCTAssertEqual(tier.tuning.range, 300)
        XCTAssertEqual(tier.tuning.fireInterval, 2)
        XCTAssertEqual(tier.tuning.shotMinDamage, 22)
        XCTAssertEqual(tier.tuning.shotMaxDamage, 32)
        XCTAssertEqual(tier.tuning.aoeRadius, 100)
        XCTAssertNil(tier.tuning.engineerObstacles)
        XCTAssertNil(tier.tuning.demolitionPreparationSeconds)
        XCTAssertNil(tier.tuning.meleeUnit)
        XCTAssertEqual(tier.tuning.upgradePaths.map(\.id), ["grenadier_grenades", "grenadier_drill"])
        XCTAssertEqual(TowerKind.special.assetName(atLevel: 4, branch: 1), "special_tower_level_4_branch_1")
        XCTAssertEqual(TowerKind.special.specializationMenuIconName(atLevel: 4, branch: 1), "grenadier_grenade")
        XCTAssertEqual(TowerKind.special.projectileAssetName, "grenadier_grenade")
        let stats = Dictionary(uniqueKeysWithValues: TowerEncyclopediaStat.values(for: tier.tuning).map { ($0.label, $0.value) })
        XCTAssertEqual(stats["Damage"], "22–32")
        XCTAssertEqual(stats["Time between shots"], "2 s")
        XCTAssertNotNil(stats["Blast radius"])
    }

    @MainActor func testDatabaseEditsReachCampaignAndEncyclopediaWithoutFallbacks() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        try execute("""
            UPDATE tower SET tower_name='Authored grenadiers', tower_range=333,
                shot_min_damage=41, shot_max_damage=53 WHERE id='\(id)';
            UPDATE tower_upgrade_rank SET cost=137, effects_json='[{"attribute":"damage","delta":17}]'
                WHERE path_id='grenadier_grenades' AND rank=1;
            """, in: fixture)
        let campaign = try BattleTestFixture.authored(db: fixture.db)
        XCTAssertEqual(campaign.unlocks[.special], 4)
        let tier = try XCTUnwrap(campaign.arsenal.towers.first { $0.kind == .special }?.tiers.first {
            $0.level == 4 && $0.branch == 1
        })
        XCTAssertEqual(tier.details.name, "Authored grenadiers")
        XCTAssertEqual(tier.tuning.range, 333)
        XCTAssertEqual(tier.tuning.shotMinDamage, 41)
        XCTAssertEqual(tier.tuning.upgradePaths[0].ranks[0].cost, 137)
        var progress = TowerUpgradeProgress(), money = 137
        XCTAssertEqual(progress.purchase(pathID: "grenadier_grenades", from: tier.tuning, money: &money), .ok)
        XCTAssertEqual(tier.tuning.upgraded(with: progress).shotMinDamage, 58)
        XCTAssertEqual(money, 0)
        let demo = try TowerDemonstration(db: fixture.db, kind: .special, level: 4, branch: 1)
        let effective = campaign.playerUpgrades.loadout.effects.combat(tier.tuning, kind: .special)
        XCTAssertEqual(demo.tower.tuning.range, effective.range)
        XCTAssertEqual(demo.tower.tuning.shotMaxDamage, effective.shotMaxDamage)
    }

    func testMissingAndInvalidGrenadierContentFailsWithDiagnostics() throws {
        let mutations = [
            ("DELETE FROM tower WHERE id='\(id)'", "tower"),
            ("DELETE FROM tower_history WHERE tower_id='\(id)'", "tower_history"),
            ("UPDATE tower SET shot_min_damage='malformed' WHERE id='\(id)'", "shot_min_damage"),
            ("UPDATE tower SET attack_mode='unknown' WHERE id='\(id)'", "attack_mode"),
            ("DELETE FROM tower_upgrade_rank WHERE path_id='grenadier_drill' AND rank=2", "grenadier_drill"),
            ("UPDATE tower_upgrade_rank SET effects_json='[]' WHERE path_id='grenadier_grenades' AND rank=1", "effects_json")
        ]
        for (sql, diagnostic) in mutations {
            let fixture = try AuthoredDatabaseFixture()
            // Bypass only the disposable fixture's SQL CHECKs to exercise DAO diagnostics.
            try execute("PRAGMA ignore_check_constraints=ON", in: fixture)
            try execute(sql, in: fixture)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal()) { error in
                XCTAssertTrue(String(describing: error).contains(diagnostic), "\(error)")
            }
        }
    }

    @MainActor func testPlayerPurchasesReplaceAbatisAndGrenadesDamageGroupsAndMorale() throws {
        let authored = try BattleTestFixture.authored()
        var enemy = try XCTUnwrap(authored.enemies.first { $0.key == "loyalist_militia" })
        enemy.stats.maxHP = 100_000; enemy.stats.speed = 0; enemy.stats.cover = 0
        let level = BattleTestFixture.level(enemy: enemy,
            slots: [Point(0, authored.arsenal.combatRules.enemyBodyOffsetY)],
            starts: [Point(100, 0), Point(110, 0), Point(120, 0)])
        let sim = try GameSimulation(recording: .preview,
            content: BattleTestFixture.content(level: level, enemies: [enemy], base: authored),
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        try BattleTestFixture.build(.special, level: 3, in: sim)
        XCTAssertFalse(sim.engine.engineerObstacleFields.isEmpty)
        XCTAssertFalse(sim.engine.hasAttackRange(try XCTUnwrap(sim.engine.placedTower(atSlot: 0))))
        XCTAssertEqual(sim.engine.upgradeOffers(at: 0).map(\.branch), [1, 2, 3])
        let money = sim.engine.money
        XCTAssertEqual(sim.perform(.upgrade(slot: 0, branch: 1)), .ok)
        XCTAssertEqual(money - sim.engine.money, 300)
        let tower = try XCTUnwrap(sim.engine.placedTower(atSlot: 0))
        XCTAssertNil(tower.engineerObstaclePosition)
        XCTAssertNil(tower.demolitionCharge)
        XCTAssertTrue(sim.engine.engineerObstacleFields.isEmpty)
        XCTAssertTrue(sim.engine.hasAttackRange(tower))
        for path in ["grenadier_grenades", "grenadier_drill"] {
            for _ in 0..<2 { XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: path), .ok) }
            XCTAssertEqual(sim.purchaseUpgrade(slot: 0, pathID: path), .invalid)
        }
        let tuned = try XCTUnwrap(sim.engine.towerLevel(for: try XCTUnwrap(sim.engine.placedTower(atSlot: 0))))
        XCTAssertEqual(tuned.shotMinDamage, 42)
        XCTAssertEqual(tuned.shotMaxDamage, 52)
        XCTAssertEqual(tuned.aoeRadius, 135)
        XCTAssertEqual(tuned.range, 350)
        XCTAssertEqual(tuned.fireInterval, 1.5)
        sim.startNextWave()
        var sawGrenade = false
        for _ in 0..<120 {
            sim.step()
            sawGrenade = sawGrenade || sim.engine.projectiles.contains { $0.kind == .special && $0.impactPoint != nil }
            if sim.enemies.filter({ $0.hp < 100_000 }).count == 3 { break }
        }
        XCTAssertTrue(sawGrenade)
        XCTAssertGreaterThan(sim.shotsByMode[.shell, default: 0], 0)
        XCTAssertEqual(sim.enemies.filter { $0.hp < 100_000 }.count, 3)
        XCTAssertTrue(sim.engine.walkers.contains { $0.morale.remainingFraction < 1 })
    }
}
