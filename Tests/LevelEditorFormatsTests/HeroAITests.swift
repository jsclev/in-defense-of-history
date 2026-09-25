import XCTest
import SQLite3
@testable import LevelEditorFormats

final class HeroAITests: XCTestCase {
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    func testEveryHeroHasADedicatedControllerAndStartsWithManualControl() throws {
        let fixture = try AuthoredDatabaseFixture()
        let heroes = try fixture.db.heroDao.getAll()
        let configs = try fixture.db.heroDao.getAIConfigurations()
        let controls = try fixture.db.playerSettingsDao.getHeroControls()
        XCTAssertEqual(Set(configs.keys), Set(heroes.map(\.id)))
        XCTAssertEqual(Set(controls.map(\.id)), Set(heroes.map(\.id)))
        let washington = try XCTUnwrap(configs.first { $0.value.controller == .georgeWashington }?.key)
        XCTAssertEqual(controls.first { $0.id == washington }?.aiEnabled, false)
        XCTAssertTrue(controls.allSatisfy { !$0.aiEnabled })
        XCTAssertEqual(Set(configs.values.map { String(describing: type(of: $0.controller.makeController())) }).count, heroes.count)
        for config in configs.values {
            XCTAssertFalse(config.controller.makeController() === config.controller.makeController())
        }
    }

    func testSQLChangesPropagateAndMissingOrInvalidContentFails() throws {
        let fixture = try AuthoredDatabaseFixture()
        let id = try XCTUnwrap(fixture.db.heroDao.getAll().first?.id)
        let key = id.uuidString.lowercased()
        try execute("UPDATE hero_ai SET decision_interval = 0.7, retreat_health_fraction = 0.4, resume_health_fraction = 0.9 WHERE hero_id = '\(key)'", in: fixture)
        let config = try XCTUnwrap(fixture.db.heroDao.getAIConfigurations()[id])
        XCTAssertEqual(config.decisionInterval, 0.7)
        XCTAssertEqual(config.retreatHealthFraction, 0.4)
        XCTAssertEqual(config.resumeHealthFraction, 0.9)
        try fixture.db.playerSettingsDao.setHeroAIEnabled(true, heroID: id)
        XCTAssertEqual(try fixture.db.playerSettingsDao.getHeroControls().first { $0.id == id }?.aiEnabled, true)
        // Remove constraints only in disposable memory to exercise DAO validation.
        try execute("CREATE TABLE loose_ai AS SELECT * FROM hero_ai; DROP TABLE hero_ai; ALTER TABLE loose_ai RENAME TO hero_ai; CREATE TABLE loose_control AS SELECT * FROM player_hero_control; DROP TABLE player_hero_control; ALTER TABLE loose_control RENAME TO player_hero_control", in: fixture)
        for (field, value) in [("controller", "'unknown'"), ("controller", "NULL"),
                               ("decision_interval", "NULL"), ("decision_interval", "0"),
                               ("retreat_health_fraction", "NULL"), ("retreat_health_fraction", "1"),
                               ("resume_health_fraction", "NULL"), ("resume_health_fraction", "0.2")] {
            try execute("SAVEPOINT bad; UPDATE hero_ai SET \(field) = \(value) WHERE hero_id = '\(key)'", in: fixture)
            XCTAssertThrowsError(try fixture.db.heroDao.getAIConfigurations()) { error in
                XCTAssertTrue(String(describing: error).lowercased().contains(key))
                XCTAssertTrue(String(describing: error).contains(field == "retreat_health_fraction" && value == "1" ? "resume_health_fraction" : field))
            }
            try execute("ROLLBACK TO bad; RELEASE bad", in: fixture)
        }
        for value in ["NULL", "2", "'yes'"] {
            try execute("UPDATE player_hero_control SET ai_enabled = \(value) WHERE hero_id = '\(key)'", in: fixture)
            XCTAssertThrowsError(try fixture.db.playerSettingsDao.getHeroControls())
        }
        try execute("DELETE FROM hero_ai WHERE hero_id = '\(key)'; DELETE FROM player_hero_control WHERE hero_id = '\(key)'", in: fixture)
        XCTAssertThrowsError(try fixture.db.heroDao.getAIConfigurations())
        XCTAssertThrowsError(try fixture.db.playerSettingsDao.getHeroControls())
        XCTAssertThrowsError(try fixture.db.playerSettingsDao.setHeroAIEnabled(true, heroID: id))
    }

    private func context(hp: Double, state: MilitiaUnit.State = .holding) throws -> HeroAIContext {
        let content = try BattleTestFixture.authored()
        let id = try XCTUnwrap(content.deployments.first?.hero.id)
        let area = try HeroMovementArea(geoJSON: Data("""
            {"features":[{"properties":{"category":"gameplay","kind":"enemy_path"},
            "geometry":{"type":"MultiPolygon","coordinates":[
            [[[0,0],[1000,0],[1000,1000],[0,1000],[0,0]]],
            [[[1100,0],[1500,0],[1500,1000],[1100,1000],[1100,0]]]]}}]}
            """.utf8), defaultPathWidth: 100)
        var movement = try HeroMovement(area: area, spawn: Point(100, 100))
        var unit = MilitiaUnit(position: Point(400, 400), hp: hp)
        XCTAssertTrue(movement.command(to: unit.position, unit: &unit))
        unit.state = state
        return HeroAIContext(unit: unit, combat: try XCTUnwrap(content.heroCombat[id]), movement: movement,
            configuration: try XCTUnwrap(content.heroAI[id]), engageScanRadius: content.arsenal.combatRules.heroEngageScanRadius,
            threats: [.init(id: 1, position: Point(1200, 400), secondsToExit: 1),
                      .init(id: 2, position: Point(800, 400), secondsToExit: 2),
                      .init(id: 3, position: Point(700, 400), secondsToExit: 3)])
    }

    func testPoliciesSkipUnreachableThreatsPreserveFightsAndRecoverIndependently() throws {
        for kind in HeroAIKind.allCases {
            let controller = kind.makeController()
            let other = kind.makeController()
            XCTAssertEqual(controller.destination(in: try context(hp: 300)), Point(800, 400))
            XCTAssertNil(controller.destination(in: try context(hp: 300, state: .fighting)))
            XCTAssertEqual(controller.destination(in: try context(hp: 1, state: .fighting)), Point(100, 100))
            XCTAssertTrue(controller.isRecovering)
            XCTAssertFalse(other.isRecovering)
            XCTAssertEqual(controller.destination(in: try context(hp: 150)), Point(100, 100))
            XCTAssertEqual(controller.destination(in: try context(hp: 300)), Point(800, 400))
            XCTAssertFalse(controller.isRecovering)
            _ = controller.destination(in: try context(hp: 1))
            XCTAssertNil(controller.destination(in: try context(hp: 0, state: .dead)))
            XCTAssertFalse(controller.isRecovering)
        }
    }

    func testLiveSettingsAreIndependentAndManualOrdersPersistWithoutBeingCancelled() async throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let content = try BattleTestFixture.authored(db: fixture.db)
        try await MainActor.run {
            let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: true, startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
            let settings = try PlayerSettingsStore(dao: fixture.db.playerSettingsDao)
            let binding = settings.bindHeroControls(to: battle)
            defer { binding.cancel() }
            let id = try XCTUnwrap(battle.heroPosts.first?.hero.id)
            let second = try XCTUnwrap(battle.heroPosts.last?.hero.id)
            XCTAssertNotEqual(id, second)
            battle.pause()
            try settings.setHeroAIEnabled(true, heroID: id)
            XCTAssertEqual(battle.heroAIEnabled[id], true)
            XCTAssertEqual(battle.heroAIEnabled[second], false)
            let tick = battle.timer.tick
            battle.advance(ticks: 30, interpolation: 0)
            XCTAssertEqual(battle.timer.tick, tick)
            XCTAssertTrue(battle.nextHeroAIDecisionTick.isEmpty)
            battle.resume()
            XCTAssertEqual(battle.perform(.moveHero(id: id, point: Point(-1, -1))), .invalid)
            XCTAssertEqual(battle.heroAIEnabled[id], true)
            let destination = battle.heroPosts[1].movement.spawn
            XCTAssertEqual(battle.perform(.moveHero(id: id, point: destination)), .ok)
            XCTAssertEqual(battle.heroAIEnabled[id], false)
            XCTAssertEqual(settings.heroControls.first { $0.id == id }?.aiEnabled, false)
            XCTAssertEqual(try fixture.db.playerSettingsDao.getHeroControls().first { $0.id == id }?.aiEnabled, false)
            XCTAssertEqual(battle.heroPosts[0].movement.station, destination, "Two-way settings updates must not cancel the manual order")
            XCTAssertEqual(battle.perform(.setHeroAI(id: second, enabled: true)), .ok)
            battle.isCleared = true
            XCTAssertFalse(battle.setHeroAIEnabled(true, for: id))
            XCTAssertFalse(battle.setHeroAIEnabled(true, for: UUID()))
        }
    }

    func testRetreatAtSpawnDisengagesAndAllowsHealingWithoutReengaging() async throws {
        let content = try BattleTestFixture.authored()
        try await MainActor.run {
            let battle = try BattleEngine(recording: .preview, content: content, heroesEnabled: true, startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
            let post = try XCTUnwrap(battle.heroPosts.first)
            let enemy = try XCTUnwrap(content.enemies.first)
            let stats = enemy.stats
            battle.walkers = [BattleEngine.Walker(id: 99, assetName: enemy.imageName,
                speed: stats.speed, maxHP: stats.maxHP, hp: stats.maxHP, bounty: stats.gold,
                livesCost: stats.livesCost, damageMin: stats.damageMin, damageMax: stats.damageMax,
                cover: stats.cover, blockImmune: false, spawnTick: 0, pathIndex: 0,
                discipline: stats.discipline, moraleResponse: stats.moraleResponse,
                morale: EnemyMorale(rules: battle.combatRules),
                position: CGPoint(x: post.unit.position.x, y: post.unit.position.y))]
            battle.heroPosts[0].unit.hp = 1
            battle.heroPosts[0].unit.state = .fighting
            battle.heroPosts[0].unit.targetSpawnID = 99
            battle.blockedWalkerIDs = [99]
            XCTAssertTrue(battle.setHeroAIEnabled(true, for: post.hero.id))
            battle.stepHeroAI()
            XCTAssertEqual(battle.heroPosts[0].unit.targetSpawnID, -1)
            XCTAssertFalse(battle.blockedWalkerIDs.contains(99))
            XCTAssertTrue(try XCTUnwrap(battle.heroAIControllers[post.hero.id]).isRecovering)
            for _ in 0..<30 { battle.stepMilitiaTick() }
            XCTAssertGreaterThan(battle.heroPosts[0].unit.hp, 1)
            XCTAssertEqual(battle.heroPosts[0].unit.targetSpawnID, -1)
            XCTAssertTrue(battle.setHeroAIEnabled(false, for: post.hero.id))
            battle.stepMilitiaTick()
            XCTAssertEqual(battle.heroPosts[0].unit.targetSpawnID, 99,
                           "Manual mode must restore the ordinary nearby combat behavior")
        }
    }

    func testAIUsesSharedTicksAndDoesNotChangePlayerSelectionOrMenus() async throws {
        let content = try BattleTestFixture.authored()
        try await MainActor.run {
            let sim = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: true, seed: 1776)
            let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: true, startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
            for post in player.heroPosts {
                XCTAssertEqual(sim.perform(.setHeroAI(id: post.hero.id, enabled: true)), .ok)
                XCTAssertTrue(player.setHeroAIEnabled(true, for: post.hero.id))
            }
            sim.startNextWave(); player.startNextWave()
            player.selectHero(0)
            let starts = player.heroPosts.map { $0.unit.position }
            for _ in 0..<300 {
                for _ in 0..<4 { sim.step() }
                player.advance(ticks: 0, interpolation: 0.5)
                player.advance(ticks: 4, interpolation: 0.25)
                XCTAssertEqual(player.heroPosts.map { $0.unit.position }, sim.engine.heroPosts.map { $0.unit.position })
                XCTAssertEqual(player.heroPosts.map { $0.unit.hp }, sim.engine.heroPosts.map { $0.unit.hp })
                XCTAssertEqual(player.heroPosts.map { $0.unit.state }, sim.engine.heroPosts.map { $0.unit.state })
                XCTAssertEqual(player.walkers.map(\.hp), sim.engine.walkers.map(\.hp))
                XCTAssertEqual(player.money, sim.gold)
                XCTAssertEqual(player.lives, sim.lives)
            }
            XCTAssertNotEqual(player.heroPosts.map { $0.unit.position }, starts)
            XCTAssertEqual(player.selectedHeroIndex, 0)
            player.selectSlot(0)
            player.tapBuildButton(.ranged)
            let slot = player.selectedSlotIndex
            let armed = player.armedBuildKind
            player.advance(ticks: 30, interpolation: 0)
            XCTAssertEqual(player.selectedSlotIndex, slot)
            XCTAssertEqual(player.armedBuildKind, armed)
        }
    }
}
