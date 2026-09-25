import XCTest
import SQLite3
@testable import LevelEditorFormats

final class SupplyTowerContentTests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testCompleteSupplyProgressionAndExplicitUnlocks() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let supply = try XCTUnwrap(arsenal.towers.first { $0.kind == .supply })
        XCTAssertEqual(supply.name, "Supply Camp")
        XCTAssertEqual(supply.tiers.map { "\($0.level):\($0.branch)" }, ["1:1", "2:1", "3:1", "4:1", "4:2", "4:3"])
        XCTAssertEqual(supply.tiers.map(\.details.name), ["Supply Cart", "Supply Post", "Supply Camp",
            "Quartermaster's Depot", "Ordnance Depot", "Field Hospital"])
        for level in try fixture.db.levelInfoDao.getCampaignLevels(campaignName: "Main") {
            let unlocks = try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: level.id)
            XCTAssertEqual(unlocks["supply"], level.name == "Charleston" ? 4 : 0)
        }
        for profile in ["coarse", "fine"] {
            let tuning = try fixture.db.simTowerSweepDao.get(profile: profile)
            XCTAssertEqual(tuning.rof["supply"], [0])
            XCTAssertEqual(tuning.splash["supply"], [0])
            XCTAssertEqual(tuning.projectileSpeed["supply"], [0])
            XCTAssertEqual(tuning.rangeModes["supply"], "authored")
        }
    }

    func testSupplyContentEditsPropagateThroughExistingDAOs() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            UPDATE tower SET tower_name = 'Provision Wagon', tower_description = 'Authored description', cost = 175
            WHERE id = 'e6a89c04-b291-4f37-8ad2-0196f75c4301';
            UPDATE level_tower_unlock SET max_tower_level = 2 WHERE tower_kind = 'supply';
            """, in: fixture)
        let details = try fixture.db.towerTypeDao.getMenuDetailsByLevel()
        XCTAssertEqual(details[.supply]?[1]?[1]?.name, "Provision Wagon")
        XCTAssertEqual(details[.supply]?[1]?[1]?.description, "Authored description")
        XCTAssertEqual(try fixture.db.towerTypeDao.getCostsByLevel()[.supply]?[1]?[1], 175)
        for level in try fixture.db.levelInfoDao.getCampaignLevels(campaignName: "Main") {
            XCTAssertEqual(try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: level.id)["supply"], 2)
        }
    }

    func testMissingAndInvalidSupplyContentFail() throws {
        let fixture = try AuthoredDatabaseFixture()
        try execute("""
            CREATE TABLE relaxed_tower AS SELECT * FROM tower;
            DROP TABLE tower;
            ALTER TABLE relaxed_tower RENAME TO tower;
            """, in: fixture)
        let id = "e6a89c04-b291-4f37-8ad2-0196f75c4403"
        for (mutation, field) in [
            ("DELETE FROM tower WHERE id = '\(id)'", "tower_id"),
            ("UPDATE tower SET tower_name = NULL WHERE id = '\(id)'", "tower_name"),
            ("UPDATE tower SET attack_mode = 'unknown' WHERE id = '\(id)'", "attack_mode"),
            ("UPDATE tower SET tower_range = -1 WHERE id = '\(id)'", "tower_range"),
            ("UPDATE tower SET has_demolition_charge = 1 WHERE id = '\(id)'", "attack_mode")
        ] {
            try execute("SAVEPOINT invalid_supply; \(mutation)", in: fixture)
            XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal()) {
                XCTAssertTrue(String(describing: $0).contains(field), "\($0)")
            }
            try execute("ROLLBACK TO invalid_supply; RELEASE invalid_supply", in: fixture)
        }
        try execute("DELETE FROM level_tower_unlock WHERE tower_kind = 'supply'", in: fixture)
        let level = try XCTUnwrap(fixture.db.levelInfoDao.getCampaignLevels(campaignName: "Main").first)
        XCTAssertThrowsError(try fixture.db.towerUnlockDao.getUnlocksFor(levelInfoId: level.id))
    }

    @MainActor func testEverySupplyTierPaysIncomeWithoutAttacking() throws {
        let fixture = try AuthoredDatabaseFixture()
        let arsenal = try fixture.db.towerTypeDao.getDesignArsenal()
        let supply = try XCTUnwrap(arsenal.towers.first { $0.kind == .supply })
        let enemy = try DesignRoster(enemyTypes: fixture.db.enemyTypeDao.getAll()).type(.loyalistMilitia)
        for tier in supply.tiers {
            let tuning = tier.tuning
            XCTAssertEqual(tuning.attackMode, .none)
            XCTAssertFalse(tuning.attackMode.firesProjectiles)
            XCTAssertEqual(tuning.range, tuning.support.hasAura ? 300 : 0)
            XCTAssertEqual(tuning.fireInterval, 0)
            XCTAssertEqual(tuning.shotMaxDamage, 0)
            XCTAssertEqual(tuning.terrorMax, 0)
            XCTAssertEqual(tuning.contagionChance, 0)
            XCTAssertNil(tuning.meleeUnit)
            XCTAssertNil(tuning.engineerObstacles)
            XCTAssertNil(tuning.demolitionPreparationSeconds)
            let level = BattleTestFixture.level(enemy: enemy, slots: [Point(0, 0)])
            let content = try BattleTestFixture.content(level: level, enemies: [enemy])
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
            let control = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
            try BattleTestFixture.build(.supply, level: tier.level, branch: tier.branch, in: sim)
            let paid = sim.gold
            sim.startNextWave(); control.startNextWave()
            for _ in 0..<120 { sim.step(); control.step() }
            XCTAssertEqual(sim.gold, paid + tuning.support.incomePerWave)
            XCTAssertEqual(sim.result().goldEarned, tuning.support.incomePerWave)
            XCTAssertTrue(sim.shotsByMode.isEmpty)
            XCTAssertTrue(sim.engine.garrisonsBySlot.isEmpty)
            XCTAssertTrue(sim.engine.engineerObstacleFields.isEmpty)
            let actual = try XCTUnwrap(sim.enemies.first), expected = try XCTUnwrap(control.enemies.first)
            XCTAssertEqual(actual.hp, expected.hp)
            XCTAssertEqual(actual.morale, expected.morale)
            XCTAssertEqual(actual.position, expected.position)
        }
    }

    func testFiveBuildButtonsHaveSeparatePriceAndTouchFrames() throws {
        let fixture = try AuthoredDatabaseFixture()
        let canvas = try fixture.db.virtualCanvasDao.get()
        let layout = TowerMenuLayout(virtualCanvas: canvas)
        XCTAssertEqual(TowerKind.allCases.count, 5)
        for height: CGFloat in [340, 400, 900] {
            let scale = height / canvas.playAreaRect.height
            let size = layout.getTowerButtonSize(playAreaScalingFactor: scale)
            XCTAssertGreaterThanOrEqual(size.width, 44)
            let centers = TowerKind.allCases.map {
                layout.getTowerButtonCenterPoint(towerKind: $0, menuCenterPoint: .zero,
                    playAreaScalingFactor: scale, towerButtonSize: size.width)
            }
            let frames = centers.map { CGRect(x: $0.x - size.width / 2,
                y: $0.y - size.height / 2, width: size.width, height: size.height * 1.15) }
            for i in frames.indices {
                for j in frames.indices where j > i { XCTAssertFalse(frames[i].intersects(frames[j])) }
            }
            let angles = centers.map { atan2($0.y, $0.x) }.sorted()
            for i in angles.indices {
                let next = i + 1 < angles.count ? angles[i + 1] : angles[0] + 2 * .pi
                XCTAssertEqual(next - angles[i], 2 * .pi / 5, accuracy: 1e-8)
            }
        }
    }
}
