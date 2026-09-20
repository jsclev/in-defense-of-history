import XCTest
import SQLite3
@testable import LevelEditorFormats

final class MetaUpgradeTests: XCTestCase {
    func testLevel15PresetBudgetAndPrerequisites() throws {
        let fixture = try AuthoredDatabaseFixture()
        let loadout = try fixture.db.playerMetaUpgradeDao.get(profile: .level15).loadout
        XCTAssertEqual(MetaUpgrade.allCases.count, 24)
        XCTAssertEqual(loadout.selected.count, 18)
        XCTAssertEqual(loadout.spentStars, 40)
        XCTAssertEqual(loadout.availableStars, 2)
        XCTAssertEqual(try MetaUpgradeLoadout(catalog: loadout.catalog, starBudget: 42, selected: loadout.selected), loadout)
        XCTAssertThrowsError(try MetaUpgradeLoadout(catalog: loadout.catalog, starBudget: -1))
        XCTAssertThrowsError(try MetaUpgradeLoadout(catalog: loadout.catalog, starBudget: 60, selected: [.twoGoodVolleys]))
        XCTAssertThrowsError(try MetaUpgradeLoadout(catalog: loadout.catalog, starBudget: 37, selected: loadout.selected))
        for track in MetaUpgradeTrack.allCases {
            XCTAssertEqual(loadout.catalog.upgrades(in: track).map(\.cost), [1, 2, 3, 4])
        }
    }

    func testPurchaseFailuresAreAtomicAndRespecRefundsDependentNodes() throws {
        let fixture = try AuthoredDatabaseFixture()
        var loadout = try MetaUpgradeLoadout(catalog: fixture.db.metaUpgradeDao.get(), starBudget: 6)
        XCTAssertEqual(loadout.availability(of: .crossfire), .prerequisite(.cartridgeDrill))
        XCTAssertFalse(loadout.purchase(.crossfire))
        XCTAssertEqual(loadout.availableStars, 6)
        for upgrade in [MetaUpgrade.rangeEstimation, .cartridgeDrill, .crossfire] {
            XCTAssertTrue(loadout.purchase(upgrade))
            let previous = loadout
            XCTAssertFalse(loadout.purchase(upgrade))
            XCTAssertEqual(loadout, previous)
        }
        XCTAssertEqual(loadout.availability(of: .twoGoodVolleys), .insufficientStars)
        XCTAssertFalse(loadout.purchase(.twoGoodVolleys))
        XCTAssertEqual(loadout.availableStars, 0)
        loadout.refund(.cartridgeDrill)
        XCTAssertEqual(loadout.selected, [.rangeEstimation])
        XCTAssertEqual(loadout.availableStars, 5)
        loadout.refund(.cartridgeDrill)
        XCTAssertEqual(loadout.availableStars, 5)
        loadout.reset()
        XCTAssertEqual(loadout.availableStars, 6)
        XCTAssertTrue(loadout.selected.isEmpty)
    }

    func testDisabledLoadoutPreservesEveryDatabaseValue() throws {
        let fixture = try AuthoredDatabaseFixture()
        for tower in try fixture.db.towerTypeDao.getDesignArsenal().towers {
            for tier in tower.tiers {
                XCTAssertEqual(MetaUpgradeEffects.none.priced(tier.tuning, kind: tower.kind, level: tier.level), tier.tuning)
                XCTAssertEqual(MetaUpgradeEffects.none.combat(tier.tuning, kind: tower.kind), tier.tuning)
            }
        }
    }

    func testContextualPricesUsePurchaseHistoryAndRoundOnlyOnce() throws {
        let fixture = try AuthoredDatabaseFixture()
        let catalog = try fixture.db.metaUpgradeDao.get()
        let effects = MetaUpgradeEffects(catalog: catalog, selected: Set(MetaUpgrade.allCases))
        var progress = MetaUpgradeBattleProgress()
        var tower = try AuthoredDatabaseFixture.tower(.ranged, level: 2, branch: 1)
        tower.cost = 101
        func price(_ kind: TowerKind, _ level: Int, _ supplied: Bool = false) -> Int {
            effects.priced(tower, kind: kind, level: level,
                context: progress.context(kind: kind, level: level, servedByMagazine: supplied)).cost
        }
        XCTAssertEqual(price(.ranged, 2), 101)
        progress.recordPurchase(kind: .ranged, level: 2)
        XCTAssertEqual(price(.ranged, 2), 86)
        XCTAssertEqual(price(.melee, 2), 101)
        XCTAssertEqual(price(.ranged, 3), 101)
        XCTAssertEqual(price(.ranged, 2, true), 73)
        XCTAssertEqual(price(.ranged, 4), 76)
        progress.recordPurchase(kind: .ranged, level: 4)
        XCTAssertEqual(price(.melee, 4), 101, "The contract is shared across all families")
        XCTAssertEqual(price(.supply, 1), 73)
        let specialized = try AuthoredDatabaseFixture.tower(.ranged, level: 4, branch: 1)
        XCTAssertEqual(effects.priced(specialized, kind: .ranged, level: 4).upgradePaths, specialized.upgradePaths)
    }

    func testMagazinesGiveIncomeOnlySupplyTowersAnAuthoredServiceArea() throws {
        let fixture = try AuthoredDatabaseFixture()
        let catalog = try fixture.db.metaUpgradeDao.get()
        let effects = MetaUpgradeEffects(catalog: catalog, selected: [.forwardMagazines])
        let cart = try AuthoredDatabaseFixture.tower(.supply, level: 1, branch: 1)
        XCTAssertEqual(cart.range, 0)
        XCTAssertEqual(effects.combat(cart, kind: .supply).range, catalog[.forwardMagazines].value(.serviceRange))
        var extendedDepot = try AuthoredDatabaseFixture.tower(.supply, level: 4, branch: 2)
        extendedDepot.range = 450
        XCTAssertEqual(effects.combat(extendedDepot, kind: .supply).range, 450)
    }

    func testPreparedVolleysRequireACompleteQuietPeriodAndConsumeOnlyTwoShots() throws {
        let fixture = try AuthoredDatabaseFixture()
        let effects = try fixture.db.playerMetaUpgradeDao.get().loadout.effects
        var volley = try XCTUnwrap(PreparedMetaVolley(effects: effects))
        XCTAssertTrue(volley.fire()); XCTAssertTrue(volley.fire()); XCTAssertFalse(volley.fire())
        volley.advance(seconds: 7.9, hasTarget: false)
        XCTAssertEqual(volley.shotsRemaining, 0)
        volley.advance(seconds: 0.1, hasTarget: true)
        volley.advance(seconds: 7.9, hasTarget: false)
        XCTAssertEqual(volley.shotsRemaining, 0, "A changed target must not refill the burst")
        volley.advance(seconds: 0.2, hasTarget: false)
        XCTAssertEqual(volley.shotsRemaining, 2)
        volley.advance(seconds: 100, hasTarget: false)
        XCTAssertEqual(volley.shotsRemaining, 2, "Idle time cannot stockpile bursts")
        XCTAssertEqual(effects.rangedDamageMultiplier(kind: .ranged, blocked: true, prepared: true), 1.56, accuracy: 1e-10)
        XCTAssertEqual(effects.rangedDamageMultiplier(kind: .ranged, blocked: false, prepared: false), 1)
        XCTAssertEqual(effects.rangedDamageMultiplier(kind: .areaOfEffect, blocked: true, prepared: true), 1)
        XCTAssertNil(PreparedMetaVolley(effects: .none))
    }

    func testCounterstrokeFireLanesAndAllThreeBatteryBranches() throws {
        let fixture = try AuthoredDatabaseFixture()
        let effects = MetaUpgradeEffects(catalog: try fixture.db.metaUpgradeDao.get(), selected: Set(MetaUpgrade.allCases))
        XCTAssertEqual(effects.meleeDamageMultiplier(moraleFraction: 0.5), 1)
        XCTAssertEqual(effects.meleeDamageMultiplier(moraleFraction: 0.499), 1.25)
        XCTAssertEqual(effects.fireLaneMultiplier(kind: .ranged, inAbatis: true), 1.15)
        XCTAssertEqual(effects.fireLaneMultiplier(kind: .areaOfEffect, inAbatis: false), 1)
        XCTAssertEqual(effects.fireLaneMultiplier(kind: .special, inAbatis: true), 1)
        XCTAssertEqual(effects.batteryDamageMultiplier(mode: .solidShot, priorHits: 0, distanceFraction: 0), 1)
        XCTAssertEqual(effects.batteryDamageMultiplier(mode: .solidShot, priorHits: 1, distanceFraction: 0), 1.25)
        XCTAssertEqual(effects.batteryDamageMultiplier(mode: .solidShot, priorHits: 10, distanceFraction: 0), 1.25)
        XCTAssertEqual(effects.batteryDamageMultiplier(mode: .grapeshot, priorHits: 0, distanceFraction: 0.5), 1.25)
        XCTAssertEqual(effects.batteryDamageMultiplier(mode: .grapeshot, priorHits: 0, distanceFraction: 0.501), 1)
        let shell = try AuthoredDatabaseFixture.tower(.areaOfEffect, level: 1, branch: 1)
        XCTAssertEqual(effects.combat(shell, kind: .areaOfEffect).splashCoverPierce,
            shell.splashCoverPierce + (1 - shell.splashCoverPierce) * 0.35, accuracy: 1e-10)
    }

    func testMetaEffectsApplyAfterBattleRanksWithoutInvalidSlowOrDoubleBonuses() throws {
        let fixture = try AuthoredDatabaseFixture()
        let effects = MetaUpgradeEffects(catalog: try fixture.db.metaUpgradeDao.get(), selected: Set(MetaUpgrade.allCases))
        for tower in try fixture.db.towerTypeDao.getDesignArsenal().towers {
            for tier in tower.tiers {
                let priced = effects.priced(tier.tuning, kind: tower.kind, level: tier.level)
                var progress = TowerUpgradeProgress(), money = 100_000
                for path in priced.upgradePaths {
                    for _ in path.ranks { XCTAssertEqual(progress.purchase(pathID: path.id, from: priced, money: &money), .ok) }
                }
                let local = priced.upgraded(with: progress)
                let tuned = effects.combat(local, kind: tower.kind)
                XCTAssertEqual(effects.combat(local, kind: tower.kind), tuned)
                // The input remains authored/priced; repeated resolution is pure.
                XCTAssertEqual(priced.range, tier.tuning.range)
                if let obstacle = tuned.engineerObstacles {
                    XCTAssertGreaterThan(obstacle.slowFraction, 0)
                    XCTAssertLessThan(obstacle.slowFraction, 1)
                    XCTAssertEqual(1 - obstacle.slowFraction, 1 - local.engineerObstacles!.slowFraction, accuracy: 1e-10)
                }
                if let seconds = tuned.demolitionPreparationSeconds {
                    XCTAssertEqual(seconds, local.demolitionPreparationSeconds! * 0.7)
                    XCTAssertTrue(DemolitionCharge(preparationSeconds: seconds).isReady)
                }
                if tower.kind == .ranged { XCTAssertEqual(tuned.range, local.range * 1.15) }
                if tower.kind == .supply {
                    XCTAssertEqual(tuned.support.attackSpeedMultiplier, local.support.attackSpeedMultiplier)
                }
            }
        }
    }

    func testDatabaseEditsStillPropagateAndMissingContentStillFails() throws {
        let fixture = try AuthoredDatabaseFixture()
        let effects = try fixture.db.playerMetaUpgradeDao.get(profile: .level15).loadout.effects
        let before = try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[.ranged]?[1]?[1])
        // Mutate only the disposable in-memory copy, never the authored database.
        XCTAssertEqual(sqlite3_exec(fixture.connection, "UPDATE tower SET tower_range = tower_range + 100 WHERE tower_type_id = (SELECT id FROM tower_type WHERE tower_type_key = 'ranged')", nil, nil, nil), SQLITE_OK)
        let after = try XCTUnwrap(fixture.db.towerTypeDao.getTowerLevelsByBranch()[.ranged]?[1]?[1])
        XCTAssertEqual(effects.combat(after, kind: .ranged).range - effects.combat(before, kind: .ranged).range, 115, accuracy: 1e-8)
        XCTAssertEqual(sqlite3_exec(fixture.connection, "DELETE FROM tower", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try fixture.db.towerTypeDao.getDesignArsenal())
    }

    func testAlarmRidersRefillSeriallyAndGroupsKeepIndependentLifetimes() throws {
        let fixture = try AuthoredDatabaseFixture()
        let effects = try fixture.db.playerMetaUpgradeDao.get().loadout.effects
        let base = try ReinforcementConfig(timeToLiveSeconds: 20, cooldownSeconds: 16)
        let second = Int64(SimClock.ticksPerSecond)
        var schedule = ReinforcementSchedule(config: base, capacity: effects.reinforcementCapacity)
        XCTAssertEqual(schedule.availableDeployments(at: 0), 1)
        XCTAssertEqual(schedule.availableDeployments(at: 16 * second), 2)
        XCTAssertTrue(schedule.deploy(slot: -1, at: 16 * second))
        XCTAssertTrue(schedule.deploy(slot: -2, at: 16 * second))
        XCTAssertFalse(schedule.deploy(slot: -3, at: 16 * second))
        XCTAssertEqual(schedule.availableDeployments(at: 31 * second), 0)
        XCTAssertEqual(schedule.availableDeployments(at: 32 * second), 1)
        XCTAssertFalse(schedule.cooldown(at: 32 * second).isReady, "At most two reserve groups may be active")
        XCTAssertEqual(schedule.expire(at: 36 * second), [-2, -1])
        XCTAssertTrue(schedule.deploy(slot: -3, at: 36 * second))
        XCTAssertEqual(schedule.availableDeployments(at: 48 * second), 1, "Spending one reserve must not restart the other recharge")
        XCTAssertEqual(schedule.expire(at: 56 * second), [-3])
        XCTAssertEqual(schedule.availableDeployments(at: 1000 * second), 2)
    }

    @MainActor func testVictoriesAwardOnlyImprovementsAndPresetClearsEarnedProgress() throws {
        let fixture = try AuthoredDatabaseFixture()
        let dao = fixture.db.playerMetaUpgradeDao
        let initial = try dao.get()
        let simulated = try XCTUnwrap(initial.bestStarsByLevel.first { $0.value == 3 }?.key)
        let fresh = try XCTUnwrap(initial.bestStarsByLevel.first { $0.value == 0 }?.key)
        let store = try MetaUpgradeStore(dao: dao)
        XCTAssertEqual(try store.recordVictory(levelID: simulated, lives: 20, startingLives: 20), 0)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 0, startingLives: 20), 0)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 5, startingLives: 20), 1)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 6, startingLives: 20), 1)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 17, startingLives: 20), 0)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 18, startingLives: 20), 1)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 20, startingLives: 20), 0)
        XCTAssertEqual(store.loadout.starBudget, 45)
        try store.reset()
        XCTAssertEqual(store.loadout.availableStars, 45)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 20, startingLives: 20), 0)
        try store.restoreLevel15()
        XCTAssertEqual(store.loadout.starBudget, 42)
        XCTAssertEqual(try store.recordVictory(levelID: simulated, lives: 20, startingLives: 20), 0)
        XCTAssertEqual(try store.recordVictory(levelID: fresh, lives: 20, startingLives: 20), 3)
    }

    @MainActor func testDatabaseSelectionSurvivesStoreRecreationAndSnapshotsStayFixed() throws {
        let fixture = try AuthoredDatabaseFixture()
        let store = try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao)
        let snapshot = store.loadout.effects
        try store.reset()
        XCTAssertEqual(snapshot.selected.count, 18)
        XCTAssertTrue(store.loadout.selected.isEmpty)
        XCTAssertTrue(try store.purchase(.rangeEstimation))
        XCTAssertEqual(store.loadout.selected, [.rangeEstimation])
        XCTAssertEqual(try MetaUpgradeStore(dao: fixture.db.playerMetaUpgradeDao).loadout.selected, [.rangeEstimation])
        try store.restoreLevel15()
        XCTAssertEqual(store.loadout, try fixture.db.playerMetaUpgradeDao.get(profile: .level15).loadout)
    }
}
