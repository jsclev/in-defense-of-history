import XCTest
@testable import LevelEditorFormats

final class SharedBattleEngineTests: XCTestCase {
    private func content() throws -> BattleContent {
        let url = Db.authoredDatabaseURL
        let db = Db(dbPath: url.path, fullRefresh: false,
                    levelGeoJSONDao: LevelGeoJSONDAO(directory: url.deletingLastPathComponent()))
        defer { db.close() }
        return try BattleContent(db: db, levelID: XCTUnwrap(db.levelInfoDao.getIdBy(levelName: "Charleston")))
    }

    @MainActor private func walker(_ game: BattleEngine, id: Int = 0, position: CGPoint = .zero) throws -> BattleEngine.Walker {
        let enemy = try XCTUnwrap(game.content.enemies.first { $0.key == "loyalist_militia" })
        let stats = enemy.stats
        return BattleEngine.Walker(id: id, assetName: enemy.imageName, speed: stats.speed,
            maxHP: 1000, hp: 1000, bounty: stats.gold, livesCost: stats.livesCost,
            damageMin: stats.damageMin, damageMax: stats.damageMax, cover: stats.cover,
            blockImmune: false, spawnTick: 0, pathIndex: 0, discipline: stats.discipline,
            moraleResponse: stats.moraleResponse, morale: EnemyMorale(rules: game.combatRules), position: position)
    }

    func testDirectHitsUseGameDamageAndExplosionsUseAuthoredCoverPiercing() async throws {
        let content = try content()
        try await MainActor.run {
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1776)
            let game = sim.engine
            let enemy = try walker(game)
            game.walkers = [enemy]
            let bullet = BattleEngine.Projectile(id: 0, kind: .ranged, position: .zero,
                heading: 0, damage: 12, targetID: enemy.id, slotIndex: 0, speed: 550, splashRadius: 0)
            game.applyImpact(bullet, at: game.bodyPoint(enemy))
            XCTAssertEqual(game.walkers[0].hp, 988, accuracy: 1e-9,
                           "A rifle must not acquire simulator-only cover reduction")
            game.walkers = [enemy]
            let tuning = try XCTUnwrap(game.towerLevels[.areaOfEffect]?[1]?[1])
            let shell = BattleEngine.Projectile(id: 1, kind: .areaOfEffect, position: .zero,
                heading: 0, damage: 12, targetID: enemy.id, slotIndex: 0, speed: 320,
                splashRadius: tuning.aoeRadius, impactPoint: game.bodyPoint(enemy),
                splashCoverPierce: tuning.splashCoverPierce, moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
            game.applyImpact(shell, at: game.bodyPoint(enemy))
            XCTAssertEqual(game.walkers[0].hp, 1000 - 12 * (1 - enemy.cover * (1 - tuning.splashCoverPierce)), accuracy: 1e-9)
            XCTAssertLessThan(game.walkers[0].morale.value, game.combatRules.moraleMax)
        }
    }

    func testZeroMoraleKeepsEnemyMarchingAndHonorsRecoveryDelay() async throws {
        let content = try content()
        try await MainActor.run {
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1776)
            let game = sim.engine
            var enemy = try walker(game)
            enemy.morale.apply(loss: game.combatRules.moraleMax, direction: 1)
            let start = content.level.paths[0].point(atDistance: 0)
            enemy.position = CGPoint(x: start.x, y: start.y)
            game.walkers = [enemy]
            let money = game.money
            game.advanceWalkers(seconds: 1, nowTicks: Double(SimClock.ticksPerSecond))
            XCTAssertEqual(game.walkers.count, 1)
            XCTAssertGreaterThan(game.walkers[0].pathDistance, 0)
            XCTAssertEqual(game.walkers[0].pathDistance, enemy.speed * enemy.moraleResponse.speedMultiplier, accuracy: 1e-8)
            XCTAssertEqual(game.walkers[0].morale.value, 0, accuracy: 1e-9)
            XCTAssertEqual(game.money, money, "Zero morale must not invent a routing bounty")
        }
    }

    func testEveryBranchAndAbilityUsesThePlayerPurchaseHandlersAndDatabaseBonuses() async throws {
        let content = try content()
        try await MainActor.run {
            for definition in content.arsenal.towers {
                for final in definition.tiers where final.level == content.unlocks[definition.kind] {
                    let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 100_000, heroesEnabled: false, seed: 1776)
                    let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
                        startingMoneyOverride: 100_000, seed: 1776, onVictory: { _, _ in 0 })
                    let slot = try XCTUnwrap(content.level.towerSlots.indices.first { index in
                        let p = content.level.towerSlots[index].position
                        let origin = CGPoint(x: p.x, y: p.y)
                        return final.tuning.demolitionPreparationSeconds == nil ||
                            final.tuning.attackRange.nearestPathPoint(to: origin, from: origin, paths: content.level.paths) != nil
                    })
                    XCTAssertEqual(sim.build(slot: slot, towerID: final.id), .ok)
                    player.selectSlot(slot); player.tapBuildButton(definition.kind); player.tapBuildButton(definition.kind)
                    for level in 2...final.level {
                        XCTAssertEqual(sim.upgrade(slot: slot), .ok)
                        let tier = try XCTUnwrap(definition.tiers.first { $0.level == level && (level != final.level || $0.id == final.id) })
                        player.dismissMenu(); player.selectPlacedTower(atSlot: slot)
                        player.tapUpgradeButton(branch: tier.branch); player.tapUpgradeButton(branch: tier.branch)
                        XCTAssertEqual(sim.gold, player.money)
                        XCTAssertEqual(sim.engine.towerLevel(for: try XCTUnwrap(sim.engine.placedTower(atSlot: slot))),
                                       player.towerLevel(for: try XCTUnwrap(player.placedTower(atSlot: slot))))
                    }
                    for path in final.tuning.upgradePaths {
                        for rank in path.ranks {
                            XCTAssertEqual(sim.purchaseUpgrade(slot: slot, pathID: path.id), .ok)
                            player.dismissMenu(); player.selectPlacedTower(atSlot: slot)
                            player.tapUpgradePath(path.id); player.tapUpgradePath(path.id)
                            XCTAssertEqual(player.placedTower(atSlot: slot)?.upgrades.rank(for: path.id), rank.rank)
                            XCTAssertEqual(sim.engine.placedTower(atSlot: slot)?.upgrades.rank(for: path.id), rank.rank)
                            XCTAssertEqual(sim.gold, player.money)
                            XCTAssertEqual(sim.engine.towerLevel(for: try XCTUnwrap(sim.engine.placedTower(atSlot: slot))),
                                           player.towerLevel(for: try XCTUnwrap(player.placedTower(atSlot: slot))))
                        }
                    }
                }
            }
        }
    }

    func testPlayerAndHeadlessEntryProduceIdenticalSeededBattlesWithHeroesAndSupply() async throws {
        let content = try content()
        try await MainActor.run {
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 1000, heroesEnabled: true, seed: 1776)
            let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: true,
                startingMoneyOverride: 1000, seed: 1776, onVictory: { _, _ in 0 })
            XCTAssertEqual(sim.engine.metaUpgrades.selected, content.playerUpgrades.loadout.selected)
            XCTAssertFalse(sim.engine.metaUpgrades.selected.isEmpty)
            for (slot, definition) in content.arsenal.towers.enumerated() {
                let final = try XCTUnwrap(definition.tiers.first { $0.level == content.unlocks[definition.kind] })
                XCTAssertEqual(sim.build(slot: slot, towerID: final.id), .ok)
                player.selectSlot(slot); player.buildTower(definition.kind)
            }
            let before = sim.gold
            sim.startNextWave(); player.startNextWave()
            XCTAssertGreaterThan(sim.gold, before, "Supply built before wave one must get its income")
            for _ in 0..<3600 {
                sim.step(); player.advance(ticks: 1, interpolation: 0)
                XCTAssertEqual(sim.gold, player.money)
                XCTAssertEqual(sim.lives, player.lives)
                XCTAssertEqual(sim.engine.walkers.map(\.hp), player.walkers.map(\.hp))
                XCTAssertEqual(sim.engine.walkers.map(\.pathDistance), player.walkers.map(\.pathDistance))
                XCTAssertEqual(sim.engine.walkers.map { $0.morale.value }, player.walkers.map { $0.morale.value })
                if sim.outcome != nil { break }
            }
            XCTAssertEqual(sim.engine.shotsByMode, player.shotsByMode)
            XCTAssertEqual(sim.engine.goldEarned, player.goldEarned)
            XCTAssertEqual(sim.engine.escapedEnemyCount, player.escapedEnemyCount)
            XCTAssertEqual(sim.engine.killedCount, player.killedCount)
        }
    }

    func testUnaffordableUpgradeDoesNotPreventIndependentAffordableDefense() async throws {
        let content = try content()
        try await MainActor.run {
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: 130, heroesEnabled: false, seed: 1776)
            let ranged = try XCTUnwrap(content.arsenal.towers.first { $0.kind == .ranged })
            let final = try XCTUnwrap(ranged.tiers.first { $0.level == 4 })
            let first = try XCTUnwrap(ranged.tiers.first { $0.level == 1 })
            let price = content.playerUpgrades.loadout.effects.priced(first.tuning, kind: .ranged, level: 1).cost
            // The next desired upgrade costs more than the remaining coins,
            // but another base tower is affordable.
            let steps: [ScriptedBuildOrder.Step] = [
                .init(time: 0, action: .build(slot: 0, towerID: final.id)),
                .init(time: 0, action: .upgrade(slot: 0)),
                .init(time: 0, action: .build(slot: 1, towerID: final.id))]
            _ = try sim.run(steps: steps, maxSeconds: SimClock.dt)
            XCTAssertEqual(sim.engine.placedTowers.count, 2)
            XCTAssertEqual(sim.gold, 130 - 2 * price)
        }
    }

    func testCharlestonReplayUsesAuthored670CoinsAndReducedBountyWithoutHeroes() async throws {
        let url = Db.authoredDatabaseURL
        let db = Db(dbPath: url.path, fullRefresh: false,
                    levelGeoJSONDao: LevelGeoJSONDAO(directory: url.deletingLastPathComponent()))
        defer { db.close() }
        let study = try AuthoredMoneyStudy(db: db, levelID: XCTUnwrap(db.levelInfoDao.getIdBy(levelName: "Charleston")))
        let plan = try MoneyStudyPlan(study: study, placementIndex: 7, upgradePolicyIndex: 2, seed: 1776)
        try await MainActor.run {
            XCTAssertEqual(study.level.startingMoney, 670)
            XCTAssertEqual(study.arsenal.combatRules.killBountyMultiplier, 0.30)
            let sim = try GameSimulation(recording: .preview, content: study.battle, startingMoney: nil, heroesEnabled: false, seed: 1776)
            XCTAssertEqual(sim.gold, 670)
            XCTAssertTrue(sim.engine.heroPosts.isEmpty)
            let result = try sim.run(steps: plan.steps, maxSeconds: 1500)
            // This recorded plan won under the former 1.0 bounty multiplier.
            // With the reduced authored bounty and 670 starting coins it exhausts its lives on wave 6.
            XCTAssertEqual(result.outcome, .defeat)
            XCTAssertEqual(result.livesRemaining, 0)
            XCTAssertEqual(sim.engine.waveSchedule.nextWaveIndex, 6)
            let data = try JSONEncoder().encode(result)
            let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(Set(report.keys), Set(["outcome", "seconds", "livesRemaining", "goldRemaining",
                "goldEarned", "killed", "leaked", "fatesByTypeID", "waveMaxProgress", "leaksByWave"]))
            XCTAssertFalse(result.fatesByTypeID.isEmpty)
            for fates in result.fatesByTypeID.values {
                let data = try JSONEncoder().encode(fates)
                let counts = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Int])
                XCTAssertEqual(Set(counts.keys), Set(["killed", "leaked"]))
            }
        }
    }
}
