import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyConcealmentTests: XCTestCase {
    private func content(starts: [Point] = [.zero]) throws -> BattleContent {
        let base = try BattleTestFixture.authored()
        let ranger = try XCTUnwrap(base.enemies.first { $0.id == Foe.queensRanger.id })
        let level = BattleTestFixture.level(enemy: ranger, slots: [Point(200, 90)], starts: starts)
        return try BattleTestFixture.content(level: level, enemies: base.enemies, base: base)
    }

    @MainActor private func simulation(_ content: BattleContent) throws -> GameSimulation {
        let sim = try GameSimulation(recording: .preview, content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave(); sim.step()
        XCTAssertFalse(sim.engine.walkers.isEmpty)
        return sim
    }

    private func ticks(_ seconds: Double) -> Int { BattleGeometry.fireTicks(seconds) }

    @MainActor func testGeneticEvaluationAppliesHidingWithoutAPlaybackRecording() throws {
        let battle = try content()
        let strategy = GeneticStrategy(decisions: [],
            metaProgression: try AuthoredDatabaseFixture.metaProgression([]),
            reinforcements: .init(priority: .nearestExit, holdSeconds: 1000))
        let sim = try GameSimulation(recording: .evaluation, content: battle,
            startingMoney: battle.level.startingMoney, heroesEnabled: false, seed: 1776)
        var commander = GeneticCommander(strategy)
        var hiddenTicks = 0, visibleTicks = 0
        while sim.time < 15 {
            try commander.tick(sim: sim)
            sim.step()
            let ranger = try XCTUnwrap(sim.engine.walkers.first)
            XCTAssertEqual(sim.enemies.first?.typeID, Foe.queensRanger.id)
            if ranger.isConcealed {
                hiddenTicks += 1
                XCTAssertTrue(sim.engine.targetCandidates().isEmpty)
            } else {
                visibleTicks += 1
                XCTAssertEqual(sim.engine.targetCandidates().count, 1)
            }
        }
        XCTAssertGreaterThan(hiddenTicks, 0)
        XCTAssertGreaterThan(visibleTicks, hiddenTicks)
        XCTAssertNil(sim.runID, "Ordinary GA evaluation must not require a movie")
        let evaluation = try GeneticCommander.evaluate(strategy, recording: .evaluation,
            content: battle, money: battle.level.startingMoney, seed: 1776,
            maxSeconds: 15, heroesEnabled: false)
        XCTAssertEqual(evaluation.result, sim.result())
    }

    @MainActor func testUnattendedPathCyclesAndKeepsWalkingWhileInvulnerable() throws {
        let sim = try simulation(content()), game = sim.engine
        let rules = try XCTUnwrap(game.walkers[0].concealment?.rules)
        XCTAssertFalse(game.walkers[0].isConcealed)
        for _ in 0..<ticks(rules.visibleInterval) { sim.step() }
        XCTAssertTrue(game.walkers[0].isConcealed)
        XCTAssertEqual(game.walkers[0].presentationOpacity, rules.opacity)
        XCTAssertTrue(game.targetCandidates().isEmpty)
        let before = game.walkers[0]
        game.damageWalker(id: before.id, damage: before.hp * 2, slotIndex: 0)
        sim.step()
        XCTAssertEqual(game.walkers[0].hp, before.hp)
        XCTAssertGreaterThan(game.walkers[0].pathDistance, before.pathDistance)
        for _ in 1..<ticks(rules.duration) { sim.step() }
        XCTAssertFalse(game.walkers[0].isConcealed)
        XCTAssertEqual(game.walkers[0].presentationOpacity, 1)
        XCTAssertEqual(game.targetCandidates().count, 1)
        for _ in 0..<ticks(rules.visibleInterval) { sim.step() }
        XCTAssertTrue(game.walkers[0].isConcealed, "The unattended-path cycle repeats")
    }

    @MainActor func testMeleeContactHidesImmediatelyAndReleasesExistingBlock() throws {
        let sim = try simulation(content()), game = sim.engine
        try BattleTestFixture.build(.melee, in: sim)
        let enemy = game.walkers[0], point = Point(enemy.position.x, enemy.position.y)
        for i in game.garrisonsBySlot[0]!.units.indices {
            game.garrisonsBySlot[0]!.units[i].position = point
            game.garrisonsBySlot[0]!.units[i].state = .fighting
            game.garrisonsBySlot[0]!.units[i].targetSpawnID = enemy.id
        }
        game.blockedWalkerIDs.insert(enemy.id)
        game.advanceEnemyConcealment()
        XCTAssertTrue(game.walkers[0].isConcealed)
        XCTAssertFalse(game.blockedWalkerIDs.contains(enemy.id))
        game.stepMilitiaTick()
        XCTAssertEqual(game.walkers[0].hp, enemy.hp)
        XCTAssertTrue(game.garrisonsBySlot[0]!.units.allSatisfy { $0.targetSpawnID < 0 })
        XCTAssertFalse(game.blockedWalkerIDs.contains(enemy.id))
        game.advanceWalkers(seconds: SimClock.dt, nowTicks: Double(game.timer.tick))
        XCTAssertGreaterThan(game.walkers[0].pathDistance, enemy.pathDistance)
    }

    @MainActor func testDistantTroopsSuppressTimerOnlyOnTheirOwnPathAndDeadTroopsDoNot() throws {
        let sim = try simulation(content(starts: [.zero, Point(0, 1000)])), game = sim.engine
        try BattleTestFixture.build(.melee, in: sim)
        let rules = try XCTUnwrap(game.walkers.first?.concealment?.rules)
        for i in game.garrisonsBySlot[0]!.units.indices {
            game.garrisonsBySlot[0]!.units[i].position = Point(2500, 0)
            game.garrisonsBySlot[0]!.units[i].state = .holding
        }
        // Advance the clock without militia orders moving these controlled patrols.
        for _ in 0..<ticks(rules.visibleInterval) { game.timer.advanceTick() }
        game.advanceEnemyConcealment()
        XCTAssertFalse(try XCTUnwrap(game.walkers.first { $0.pathIndex == 0 }).isConcealed)
        XCTAssertTrue(try XCTUnwrap(game.walkers.first { $0.pathIndex == 1 }).isConcealed)
        for i in game.garrisonsBySlot[0]!.units.indices {
            game.garrisonsBySlot[0]!.units[i].hp = 0
            game.garrisonsBySlot[0]!.units[i].state = .dead
        }
        game.advanceEnemyConcealment()
        XCTAssertTrue(game.walkers.allSatisfy(\.isConcealed))
    }

    @MainActor func testHeroesRevealForEveryDefenderAndDeadHeroesCannotReveal() throws {
        let source = try BattleTestFixture.authored()
        let game = try BattleEngine(recording: .preview, content: source, heroesEnabled: true,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        let sim = try simulation(content())
        var enemy = sim.engine.walkers[0]
        enemy.concealment = EnemyConcealment(rules: try XCTUnwrap(enemy.concealment?.rules), spawnTick: game.timer.tick)
        enemy.concealment?.advance(at: game.timer.tick, heroNearby: false,
            hasTroopsOnPath: true, troopNearby: true)
        XCTAssertTrue(enemy.isConcealed)
        game.walkers = [enemy]
        XCTAssertFalse(game.heroPosts.isEmpty)
        for i in game.heroPosts.indices {
            game.heroPosts[i].unit.position = Point(enemy.position.x, enemy.position.y)
            game.heroPosts[i].unit.hp = 0
            game.heroPosts[i].unit.state = .dead
        }
        game.revealEnemiesNearHeroes()
        XCTAssertTrue(game.walkers[0].isConcealed)
        game.heroPosts[0].unit.hp = game.heroPosts[0].combat.hp
        game.heroPosts[0].unit.state = .holding
        game.revealEnemiesNearHeroes()
        XCTAssertFalse(game.walkers[0].isConcealed)
        XCTAssertEqual(game.targetCandidates().count, 1)
        game.damageWalker(id: enemy.id, damage: 1, slotIndex: 0)
        XCTAssertEqual(game.walkers[0].hp, enemy.hp - 1)
        let rules = try XCTUnwrap(enemy.concealment?.rules)
        for _ in 0..<ticks(rules.visibleInterval) + 1 { game.timer.advanceTick() }
        game.advanceEnemyConcealment()
        XCTAssertFalse(game.walkers[0].isConcealed, "A living nearby hero prevents re-hiding")
    }

    @MainActor func testHidingStopsBulletsExplosionsDemolitionAndBothSweptArtilleryModes() throws {
        let game = try simulation(content()).engine
        var hidden = game.walkers[0]
        hidden.concealment?.advance(at: game.timer.tick, heroNearby: false,
            hasTroopsOnPath: true, troopNearby: true)
        let tuning = try XCTUnwrap(game.towerLevels[.areaOfEffect]?[1]?[1])
        let point = game.bodyPoint(hidden)
        let bullet = BattleEngine.Projectile(id: 1, kind: .ranged,
            position: point, heading: 0, damage: 1, targetID: hidden.id,
            slotIndex: 0, speed: 550, splashRadius: 0)
        let shell = BattleEngine.Projectile(id: 2, kind: .areaOfEffect,
            position: point, heading: 0, damage: 1, targetID: hidden.id,
            slotIndex: 0, speed: 320, splashRadius: tuning.aoeRadius,
            impactPoint: point, splashCoverPierce: tuning.splashCoverPierce,
            moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
        for projectile in [bullet, shell] {
            for demolition in [false, true] {
                game.walkers = [hidden]
                game.applyImpact(projectile, at: point, isDemolition: demolition)
                XCTAssertEqual(game.walkers[0], hidden)
                game.walkers[0].concealment?.reveal(at: game.timer.tick)
                game.applyImpact(projectile, at: point, isDemolition: demolition)
                XCTAssertLessThan(game.walkers[0].hp, hidden.hp)
            }
        }
        game.walkers = [hidden]; game.projectiles = [bullet, shell]
        game.updateProjectiles(gameDt: SimClock.dt)
        XCTAssertEqual(game.walkers[0], hidden, "Shots already in flight must not bypass cover")
        XCTAssertTrue(game.projectiles.isEmpty)
        for solid in [false, true] {
            let start = CGPoint(x: point.x - 20, y: point.y)
            var projectile = BattleEngine.Projectile(id: 3, kind: .areaOfEffect,
                position: start, heading: 0, damage: 1, targetID: hidden.id,
                slotIndex: 0, speed: 100, splashRadius: 0,
                firingBoundary: tuning.attackRange, firingOrigin: start,
                moraleStrike: ArtilleryMoraleStrike(tuning: tuning))
            if solid { projectile.solidShot = SolidShotFlight(range: 1000, hitRadius: 20) }
            else { projectile.grapeshot = GrapeshotFlight(volleyID: 3, range: 1000) }
            game.walkers = [hidden]; game.projectiles = [projectile]
            game.updateProjectiles(gameDt: 0.5)
            XCTAssertEqual(game.walkers[0], hidden)
            game.walkers[0].concealment?.reveal(at: game.timer.tick)
            game.projectiles = [projectile]
            game.updateProjectiles(gameDt: 0.5)
            XCTAssertLessThan(game.walkers[0].hp, hidden.hp)
            XCTAssertLessThan(game.walkers[0].morale.value, hidden.morale.value)
        }
    }

    @MainActor func testOldWalkerRecordingDecodesAndNewRecordingRetainsCover() throws {
        let game = try simulation(content()).engine
        var walker = game.walkers[0]
        walker.concealment?.advance(at: game.timer.tick, heroNearby: false, hasTroopsOnPath: true, troopNearby: true)
        XCTAssertTrue(walker.isConcealed)
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        let data = try encoder.encode(walker)
        XCTAssertEqual(try decoder.decode(BattleEngine.Walker.self, from: data), walker)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "concealment")
        let old = try decoder.decode(BattleEngine.Walker.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.concealment)
        XCTAssertFalse(old.isConcealed)
        XCTAssertEqual(old.presentationOpacity, 1)
    }

    @MainActor func testRecordedPlaybackPreservesEveryHideAndRevealTransition() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .simulator),
            content: content(), startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave()
        var expected: [Int64: [EnemyConcealment?]] = [:]
        for _ in 0..<SimClock.ticksPerSecond * 15 {
            sim.step()
            expected[sim.engine.timer.tick] = sim.engine.walkers.map(\.concealment)
        }
        sim.finishRecording(status: .timeout)
        let movie = try LevelReplayer(dao: fixture.db.levelRunDao, runID: XCTUnwrap(sim.runID))
        var hiddenFrames = 0, visibleFrames = 0
        while try movie.advance() {
            let frame = try XCTUnwrap(movie.frame)
            guard let state = expected[frame.tick] else { continue }
            XCTAssertEqual(frame.presentation.walkers.map(\.concealment), state)
            if frame.presentation.walkers.contains(where: \.isConcealed) { hiddenFrames += 1 }
            else { visibleFrames += 1 }
        }
        XCTAssertGreaterThan(hiddenFrames, 0)
        XCTAssertGreaterThan(visibleFrames, hiddenFrames)
    }

    @MainActor func testDatabaseTuningPropagatesAndInvalidConcealmentFails() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let id = Foe.queensRanger.id.uuidString.lowercased()
        let original = try XCTUnwrap(fixture.db.enemyTypeDao.getAll().first { $0.id == Foe.queensRanger.id })
        let rules = try XCTUnwrap(original.concealmentRules)
        let authored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(rules)) as? [String: Any])
        func write(_ fields: [String: Any]) throws {
            var trait = fields; trait["type"] = "concealment"
            let json = String(decoding: try JSONSerialization.data(withJSONObject: [trait]), as: UTF8.self)
            XCTAssertEqual(sqlite3_exec(fixture.connection,
                "UPDATE enemy_type SET traits='\(json)' WHERE id='\(id)'", nil, nil, nil), SQLITE_OK)
        }
        var changed = authored
        changed["duration"] = rules.duration * 2
        changed["opacity"] = 0.5
        try write(changed)
        let base = try BattleTestFixture.authored(db: fixture.db)
        let updated = try XCTUnwrap(base.enemies.first { $0.id == original.id })
        let custom = try BattleTestFixture.content(level: BattleTestFixture.level(enemy: updated, slots: []), enemies: base.enemies, base: base)
        let spawned = try simulation(custom).engine.walkers[0]
        XCTAssertEqual(spawned.concealment?.rules.duration, rules.duration * 2)
        XCTAssertEqual(spawned.concealment?.rules.opacity, 0.5)
        for field in authored.keys {
            var missing = authored; missing.removeValue(forKey: field)
            try write(missing)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains("traits"))
                XCTAssertTrue(String(describing: $0).lowercased().contains(id))
            }
            var invalid = authored; invalid[field] = -1
            try write(invalid)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains(field))
            }
        }
        var invisible = authored; invisible["opacity"] = 0
        try write(invisible)
        XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll())
    }
}
