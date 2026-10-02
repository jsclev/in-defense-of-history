import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyBossTests: XCTestCase {
    private func content(_ key: String, base: BattleContent? = nil) throws -> BattleContent {
        let source = try base ?? BattleTestFixture.authored()
        let boss = try XCTUnwrap(source.enemies.first { $0.key == key })
        return try BattleTestFixture.content(
            level: BattleTestFixture.level(enemy: boss, slots: [Point(200, 90)]),
            enemies: source.enemies, base: source)
    }

    @MainActor private func simulation(_ key: String) throws -> GameSimulation {
        let sim = try GameSimulation(recording: .preview, content: content(key),
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave(); sim.step()
        XCTAssertEqual(sim.engine.walkers.count, 1)
        return sim
    }

    @MainActor private func advanceClock(_ game: BattleEngine, to tick: Int64) {
        while game.timer.tick < tick { game.timer.advanceTick() }
    }

    @MainActor private func defenders(in sim: GameSimulation, at point: Point) throws {
        try BattleTestFixture.build(.melee, in: sim)
        for index in sim.engine.garrisonsBySlot[0]!.units.indices {
            sim.engine.garrisonsBySlot[0]!.units[index].position = point
            sim.engine.garrisonsBySlot[0]!.units[index].state = .holding
            sim.engine.garrisonsBySlot[0]!.units[index].hp = 1000
        }
    }

    @MainActor private func addHeroes(to game: BattleEngine, at point: Point) throws {
        let source = try BattleEngine(recording: .preview, content: BattleTestFixture.authored(),
            heroesEnabled: true, startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        game.heroPosts = source.heroPosts
        XCTAssertFalse(game.heroPosts.isEmpty)
        let area = try HeroMovementArea(geoJSON: Data("""
            {"type":"FeatureCollection","features":[{"type":"Feature",
              "properties":{"category":"gameplay","kind":"road"},
              "geometry":{"type":"Polygon","coordinates":[[[-1000,-1000],[5000,-1000],
                [5000,1000],[-1000,1000],[-1000,-1000]]]}}]}
            """.utf8), defaultPathWidth: game.virtualCanvas.pathWidth)
        for index in game.heroPosts.indices {
            game.heroPosts[index].movement = try HeroMovement(area: area, spawn: point)
            game.heroPosts[index].unit.position = point
            game.heroPosts[index].unit.hp = 1000
            game.heroPosts[index].unit.state = .holding
        }
    }

    @MainActor func testRallyRestoresOnlyLivingNearbyAlliesAndStopsWhenCommanderDies() throws {
        let game = try simulation("howe_assault").engine
        let commander = game.walkers[0], rules = try XCTUnwrap(commander.boss?.rules)
        let type = try XCTUnwrap(game.content.enemies.first { $0.key == "redcoat_regular" })
        for distance in [0, rules.rallyRadius + 1, 0] {
            game.spawnEnemy(type: type, pathIndex: 0, wave: 0, spawnTick: game.timer.tick,
                pathDistance: commander.pathDistance + distance)
        }
        for index in game.walkers.indices {
            game.walkers[index].morale.apply(loss: game.combatRules.moraleMax, direction: 1)
        }
        game.walkers[3].hp = 0
        game.advanceEnemyBosses()
        XCTAssertEqual(game.walkers[0].morale.value, 0, "The commander does not rally himself")
        XCTAssertEqual(game.walkers[1].morale.value, rules.rallyMoralePerSecond * SimClock.dt, accuracy: 1e-10)
        XCTAssertEqual(game.walkers[2].morale.value, 0)
        XCTAssertEqual(game.walkers[3].morale.value, 0, "A corpse is not a rally recipient")
        game.damageWalker(id: commander.id, damage: commander.hp, slotIndex: 0)
        let values = game.walkers.map { $0.morale.value }
        game.advanceEnemyBosses()
        XCTAssertEqual(game.walkers.map { $0.morale.value }, values)
    }

    @MainActor func testAreaMeleeHitsTroopsAndHeroesOncePerSwingRegardlessOfBlockerCount() throws {
        let sim = try simulation("hill_rearguard"), game = sim.engine
        game.walkers[0].pathDistance = 200
        game.walkers[0].position = CGPoint(x: 200, y: 0)
        let enemy = game.walkers[0]
        let rules = try XCTUnwrap(enemy.boss?.rules)
        XCTAssertGreaterThanOrEqual(rules.meleeSplashRadius, game.combatRules.meleeCombatSpacing,
            "The authored radius must reach the real defender fighting stance")
        let point = Point(enemy.position.x + game.combatRules.meleeCombatSpacing, enemy.position.y)
        try defenders(in: sim, at: point)
        try addHeroes(to: game, at: point)
        for index in game.garrisonsBySlot[0]!.units.indices {
            game.garrisonsBySlot[0]!.units[index].state = .fighting
            game.garrisonsBySlot[0]!.units[index].targetSpawnID = enemy.id
            game.garrisonsBySlot[0]!.units[index].swingTicksLeft = 1000
        }
        for index in game.heroPosts.indices {
            game.heroPosts[index].unit.state = .fighting
            game.heroPosts[index].unit.targetSpawnID = enemy.id
            game.heroPosts[index].unit.swingTicksLeft = 1000
            game.heroPosts[index].enemySwingTicks[enemy.id] = 0
        }
        game.garrisonsBySlot[0]!.enemySwingTicks[enemy.id] = 0
        game.stepMilitiaTick()
        XCTAssertTrue(game.garrisonsBySlot[0]!.units.allSatisfy { $0.hp == 1000 },
            "The ordinary one-defender attack must not stack with the area attack")
        XCTAssertTrue(game.heroPosts.allSatisfy { $0.unit.hp == 1000 })
        game.walkers[0].boss?.meleeReadyAtTick = game.timer.tick
        game.advanceEnemyBosses()
        let units = game.garrisonsBySlot[0]!.units
        let melee = try XCTUnwrap(game.garrisonMelee(slot: 0, garrison: game.garrisonsBySlot[0]!)).stats
        let rolledDamage = (1000 - units[0].hp) / (1 - melee.defenseRating)
        XCTAssertGreaterThanOrEqual(rolledDamage, enemy.meleeDamageRange.lowerBound - 1e-9)
        XCTAssertLessThanOrEqual(rolledDamage, enemy.meleeDamageRange.upperBound + 1e-9)
        for unit in units { XCTAssertEqual(unit.hp, units[0].hp, accuracy: 1e-9) }
        for hero in game.heroPosts {
            XCTAssertEqual(hero.unit.hp, 1000 - rolledDamage * (1 - hero.combat.defenseRating), accuracy: 1e-9)
        }
        let heroHP = game.heroPosts.map { $0.unit.hp }
        game.advanceEnemyBosses()
        XCTAssertEqual(game.garrisonsBySlot[0]!.units.map(\.hp), units.map(\.hp))
        XCTAssertEqual(game.heroPosts.map { $0.unit.hp }, heroHP,
            "Adding blockers must not grant the boss another swing in the same tick")
    }

    @MainActor func testBarrageLocksItsTargetAndDefendersCanLeaveTheBlastArea() throws {
        let sim = try simulation("clinton_siege"), game = sim.engine
        let rules = try XCTUnwrap(game.walkers[0].boss?.rules)
        let target = Point(rules.barrageRange / 2, 0)
        try defenders(in: sim, at: target)
        game.walkers[0].boss?.barrageReadyAtTick = game.timer.tick
        game.advanceEnemyBosses()
        XCTAssertEqual(game.walkers[0].boss?.barrageTarget, target)
        let impactTick = try XCTUnwrap(game.walkers[0].boss?.barrageImpactAtTick)
        for index in game.garrisonsBySlot[0]!.units.indices {
            game.garrisonsBySlot[0]!.units[index].position = Point(target.x + rules.barrageRadius + 1, 0)
        }
        advanceClock(game, to: impactTick - 1)
        game.advanceEnemyBosses()
        XCTAssertEqual(game.walkers[0].boss?.barrageTarget, target)
        XCTAssertTrue(game.artilleryImpacts.isEmpty)
        advanceClock(game, to: impactTick)
        game.advanceEnemyBosses()
        XCTAssertTrue(game.garrisonsBySlot[0]!.units.allSatisfy { $0.hp == 1000 })
        XCTAssertEqual(game.artilleryImpacts.count, 1)
        XCTAssertEqual(game.artilleryImpacts[0].position, CGPoint(x: target.x, y: target.y))
        XCTAssertNil(game.walkers[0].boss?.barrageTarget)
    }

    @MainActor func testBarrageDamagesAllLivingDefendersInsideRadiusAndHandlesDeaths() throws {
        let sim = try simulation("clinton_siege"), game = sim.engine
        let rules = try XCTUnwrap(game.walkers[0].boss?.rules)
        let target = Point(rules.barrageRange / 2, 0)
        try defenders(in: sim, at: target)
        try addHeroes(to: game, at: target)
        game.garrisonsBySlot[0]!.units[0].hp = 1
        game.heroPosts[0].unit.hp = 1
        game.selectedHeroIndex = 0
        game.walkers[0].boss?.barrageReadyAtTick = game.timer.tick
        game.advanceEnemyBosses()
        advanceClock(game, to: try XCTUnwrap(game.walkers[0].boss?.barrageImpactAtTick))
        game.advanceEnemyBosses()
        let garrison = try XCTUnwrap(game.garrisonsBySlot[0])
        let melee = try XCTUnwrap(game.garrisonMelee(slot: 0, garrison: garrison)).stats
        XCTAssertEqual(garrison.units[0].state, .dead)
        XCTAssertEqual(garrison.units[0].respawnTicksLeft, BattleGeometry.fireTicks(melee.respawnSeconds))
        for unit in garrison.units.dropFirst() {
            XCTAssertEqual(unit.hp, 1000 - rules.barrageDamage * (1 - melee.defenseRating), accuracy: 1e-9)
        }
        XCTAssertEqual(game.heroPosts[0].unit.state, .dead)
        XCTAssertNil(game.selectedHeroIndex)
        for post in game.heroPosts.dropFirst() {
            XCTAssertEqual(post.unit.hp, 1000 - rules.barrageDamage * (1 - post.combat.defenseRating), accuracy: 1e-9)
        }
    }

    @MainActor func testEngagementInterruptsBarrageAndKillingBossCancelsPendingBlast() throws {
        let sim = try simulation("clinton_siege"), game = sim.engine
        let enemy = game.walkers[0], rules = try XCTUnwrap(enemy.boss?.rules)
        try defenders(in: sim, at: Point(rules.barrageRange / 2, 0))
        game.walkers[0].boss?.barrageReadyAtTick = game.timer.tick
        game.advanceEnemyBosses()
        XCTAssertNotNil(game.walkers[0].boss?.barrageTarget)
        game.blockedWalkerIDs.insert(enemy.id)
        game.advanceEnemyBosses()
        XCTAssertNil(game.walkers[0].boss?.barrageTarget)
        game.blockedWalkerIDs.remove(enemy.id)
        game.advanceEnemyBosses()
        XCTAssertNil(game.walkers[0].boss?.barrageTarget, "Interrupting imposes the authored reload interval")
        advanceClock(game, to: try XCTUnwrap(game.walkers[0].boss?.barrageReadyAtTick))
        game.advanceEnemyBosses()
        let impactTick = try XCTUnwrap(game.walkers[0].boss?.barrageImpactAtTick)
        game.damageWalker(id: enemy.id, damage: enemy.hp, slotIndex: 0)
        XCTAssertTrue(game.walkers.isEmpty)
        advanceClock(game, to: impactTick)
        game.advanceEnemyBosses()
        XCTAssertTrue(game.artilleryImpacts.isEmpty)
        XCTAssertTrue(game.garrisonsBySlot[0]!.units.allSatisfy { $0.hp == 1000 })
    }

    @MainActor func testOldWalkerDecodesAndNewWalkerRetainsBossScaleAndBarrage() throws {
        let sim = try simulation("clinton_siege"), game = sim.engine
        let rules = try XCTUnwrap(game.walkers[0].boss?.rules)
        try defenders(in: sim, at: Point(rules.barrageRange / 2, 0))
        game.walkers[0].boss?.barrageReadyAtTick = game.timer.tick
        game.advanceEnemyBosses()
        let walker = game.walkers[0]
        XCTAssertEqual(walker.presentationScale, rules.renderScale)
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try encoder.encode(walker)
        XCTAssertEqual(try decoder.decode(BattleEngine.Walker.self, from: data), walker)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "boss"); old.removeValue(forKey: "reinforcementCall")
        let restored = try decoder.decode(BattleEngine.Walker.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.boss)
        XCTAssertEqual(restored.presentationScale, 1)
    }

    @MainActor func testPlayerAndEvaluationUseIdenticalBossCombatAcrossTickPartitions() throws {
        for key in ["howe_assault", "hill_rearguard", "clinton_siege"] {
            let battle = try content(key)
            let sim = try GameSimulation(recording: .evaluation, content: battle,
                startingMoney: nil, heroesEnabled: false, seed: 1776)
            let player = try BattleEngine(recording: .preview, content: battle, heroesEnabled: false,
                startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
            player.publishesPresentation = true
            XCTAssertEqual(sim.perform(.build(slot: 0, kind: .melee)), .ok)
            XCTAssertEqual(player.perform(.build(slot: 0, kind: .melee)), .ok)
            sim.startNextWave(); player.startNextWave()
            for _ in 0..<180 {
                for _ in 0..<5 { sim.step() }
                player.advance(ticks: 5, interpolation: 0.4)
                XCTAssertEqual(sim.engine.walkers, player.walkers, key)
                XCTAssertEqual(sim.engine.garrisonsBySlot[0]!.units.map(\.hp), player.garrisonsBySlot[0]!.units.map(\.hp), key)
                XCTAssertEqual(sim.gold, player.money, key)
                XCTAssertEqual(sim.lives, player.lives, key)
            }
        }
    }

    @MainActor func testDatabaseBossChangesPropagateAndMissingOrInvalidFieldsFail() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let original = try XCTUnwrap(fixture.db.enemyTypeDao.getAll().first { $0.key == "clinton_siege" })
        let rules = try XCTUnwrap(original.bossRules)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(rules)) as? [String: Any])
        func write(_ fields: [String: Any]) throws {
            var trait = fields; trait["type"] = "boss"
            let json = String(decoding: try JSONSerialization.data(withJSONObject: [trait]), as: UTF8.self)
            XCTAssertEqual(sqlite3_exec(fixture.connection,
                "UPDATE enemy_type SET traits='\(json)' WHERE enemy_type_key='clinton_siege'", nil, nil, nil), SQLITE_OK)
        }
        var changed = fields
        changed["renderScale"] = rules.renderScale * 2
        changed["barrageDamage"] = rules.barrageDamage * 2
        try write(changed)
        let base = try BattleTestFixture.authored(db: fixture.db)
        let sim = try GameSimulation(recording: .preview, content: content("clinton_siege", base: base),
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave(); sim.step()
        XCTAssertEqual(sim.engine.walkers[0].presentationScale, rules.renderScale * 2)
        XCTAssertEqual(sim.engine.walkers[0].boss?.rules.barrageDamage, rules.barrageDamage * 2)
        for field in fields.keys {
            var missing = fields; missing.removeValue(forKey: field)
            try write(missing)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains(field))
                XCTAssertTrue(String(describing: $0).lowercased().contains(original.id.uuidString.lowercased()))
            }
            var invalid = fields; invalid[field] = -1
            try write(invalid)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains(field))
            }
        }
        var partial = fields; partial["barrageDamage"] = 0
        try write(partial)
        XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll())
    }
}
