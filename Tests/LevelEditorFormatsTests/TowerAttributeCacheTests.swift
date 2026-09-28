import SQLite3
import XCTest
@testable import LevelEditorFormats

final class TowerAttributeCacheTests: XCTestCase {
    @MainActor func testSupportSourcesTrackReplacementPositionsAndReloadedTuning() throws {
        let battle = try engine(BattleTestFixture.authored())
        let tower = PlacedTower(combatRules: battle.combatRules, slotIndex: 0, kind: .supply,
            position: CGPoint(x: 10, y: 20), level: 4, branch: 2)
        battle.placedTowers = [tower]
        let initial = try XCTUnwrap(battle.supportSources.first)
        XCTAssertEqual(initial.tuning, battle.towerLevel(for: tower))
        battle.placedTowers = [PlacedTower(combatRules: battle.combatRules, slotIndex: 0,
            kind: .supply, position: CGPoint(x: 400, y: 500), level: 4, branch: 2)]
        XCTAssertEqual(battle.supportSources.first?.position, CGPoint(x: 400, y: 500))
        var authored = try XCTUnwrap(battle.pricedTowerLevels[.supply]?[4]?[2])
        authored.support.attackSpeedMultiplier += 0.5
        battle.pricedTowerLevels[.supply]![4]![2] = authored
        XCTAssertEqual(battle.supportSources.first?.tuning,
                       battle.towerLevel(for: battle.placedTowers[0]))
        XCTAssertNotEqual(battle.supportSources.first?.tuning, initial.tuning)
        battle.placedTowers = [PlacedTower(combatRules: battle.combatRules, slotIndex: 0,
            kind: .ranged, position: .zero)]
        XCTAssertTrue(battle.supportSources.isEmpty)
    }

    @MainActor private func engine(_ content: BattleContent) throws -> BattleEngine {
        try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: 100_000, seed: 1776, onVictory: { _, _ in 0 })
    }

    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    @MainActor func testEveryTierBranchAndRankCombinationMatchesAuthoredResolutionAcrossLoadouts() throws {
        let content = try BattleTestFixture.authored()
        let engines = try [engine(content), engine(content.selectingMetaUpgrades([]))]
        XCTAssertNotEqual(engines[0].metaUpgrades.selected, engines[1].metaUpgrades.selected)
        // Reuse the same slot across kinds, branches, and temporary copies.
        // Interleave battles so a cache shared across loadouts would fail.
        for family in content.arsenal.towers {
            for tier in family.tiers {
                var states = [TowerUpgradeProgress()]
                for path in tier.tuning.upgradePaths {
                    states = states.flatMap { initial in
                        var progress = initial, money = 100_000
                        var ranks = [initial]
                        for _ in path.ranks {
                            XCTAssertEqual(progress.purchase(pathID: path.id, from: tier.tuning, money: &money), .ok)
                            ranks.append(progress)
                        }
                        return ranks
                    }
                }
                // Returning to old snapshots must also resolve the old ranks.
                for state in states + states.reversed() {
                    for battle in engines {
                        var tower = PlacedTower(combatRules: battle.combatRules, slotIndex: 0,
                            kind: family.kind, position: .zero, level: tier.level, branch: tier.branch)
                        tower.upgrades = state
                        let priced = battle.metaUpgrades.priced(tier.tuning, kind: family.kind, level: tier.level)
                        let expected = battle.metaUpgrades.combat(priced.upgraded(with: state), kind: family.kind)
                        XCTAssertEqual(battle.towerLevel(for: tower), expected)
                        XCTAssertEqual(battle.towerLevel(for: tower), expected, "Warm-cache lookup changed attributes")
                    }
                }
            }
        }
    }

    @MainActor func testDatabaseEditsReachNewBattlesAndReplacingLoadedTuningInvalidatesWarmEntries() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let original = try BattleTestFixture.authored(db: fixture.db)
        let battle = try engine(original)
        let tower = PlacedTower(combatRules: battle.combatRules, slotIndex: 0, kind: .ranged, position: .zero)
        let before = try XCTUnwrap(battle.towerLevel(for: tower))
        try execute("UPDATE tower SET tower_range = tower_range + 37, shot_min_damage = shot_min_damage + 11, shot_max_damage = shot_max_damage + 11", in: fixture)
        let changed = try BattleTestFixture.authored(db: fixture.db)
        let nextBattle = try engine(changed)
        let after = try XCTUnwrap(nextBattle.towerLevel(for: tower))
        XCTAssertGreaterThan(after.range, before.range)
        XCTAssertEqual(after.shotMinDamage, before.shotMinDamage + 11)
        XCTAssertEqual(battle.towerLevel(for: tower), before, "Existing battles own an immutable content snapshot")

        let originalPriced = try XCTUnwrap(battle.pricedTowerLevels[.ranged]?[1]?[1])
        battle.pricedTowerLevels[.ranged]?[1]?[1] = try XCTUnwrap(nextBattle.pricedTowerLevels[.ranged]?[1]?[1])
        XCTAssertEqual(battle.towerLevel(for: tower), after, "Nested tuning edits must invalidate a warm entry")
        battle.pricedTowerLevels[.ranged]?[1]?[1] = originalPriced
        XCTAssertEqual(battle.towerLevel(for: tower), before)
    }

    @MainActor func testWarmCacheCannotHideMissingOrInvalidDatabaseContentInANewBattle() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let battle = try engine(BattleTestFixture.authored(db: fixture.db))
        let tower = PlacedTower(combatRules: battle.combatRules, slotIndex: 0, kind: .ranged, position: .zero)
        XCTAssertNotNil(battle.towerLevel(for: tower))
        try execute("CREATE TABLE relaxed AS SELECT * FROM tower; DROP TABLE tower; ALTER TABLE relaxed RENAME TO tower", in: fixture)
        for mutation in ["UPDATE tower SET tower_range = NULL", "UPDATE tower SET tower_range = 'invalid'", "DELETE FROM tower"] {
            try execute("SAVEPOINT invalid; " + mutation, in: fixture)
            XCTAssertThrowsError(try engine(BattleTestFixture.authored(db: fixture.db))) {
                XCTAssertTrue(String(describing: $0).contains("tower"), "\($0)")
            }
            try execute("ROLLBACK TO invalid; RELEASE invalid", in: fixture)
        }
    }

    @MainActor func testSupportAuraStillRespondsToPurchasesRanksAndRemovalWithAWarmAttackCache() throws {
        let source = try BattleTestFixture.authored()
        let enemy = try XCTUnwrap(source.enemies.first)
        let content = try BattleTestFixture.content(level: BattleTestFixture.level(enemy: enemy,
            slots: [Point(0, 20), Point(0, 40)]), enemies: [enemy], base: source)
        let sim = try GameSimulation(recording: .preview, content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        try BattleTestFixture.build(.ranged, in: sim)
        let attacker = try XCTUnwrap(sim.engine.placedTower(atSlot: 0))
        let before = sim.engine.rateOfFire(for: attacker)
        try BattleTestFixture.build(.supply, level: 4, branch: 2, slot: 1, in: sim)
        let boosted = sim.engine.rateOfFire(for: attacker)
        XCTAssertGreaterThan(boosted, before)
        let depot = try XCTUnwrap(sim.engine.placedTower(atSlot: 1))
        let path = try XCTUnwrap(sim.engine.towerLevel(for: depot)?.upgradePaths.first {
            $0.ranks.contains { $0.effects.contains { $0.attribute == .supportSpeed } }
        })
        XCTAssertEqual(sim.perform(.purchaseUpgrade(slot: 1, pathID: path.id)), .ok)
        XCTAssertGreaterThan(sim.engine.rateOfFire(for: attacker), boosted)
        sim.engine.placedTowers.removeAll { $0.kind == .supply }
        XCTAssertEqual(sim.engine.rateOfFire(for: attacker), before)
    }
}
