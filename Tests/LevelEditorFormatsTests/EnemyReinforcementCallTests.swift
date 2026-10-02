import XCTest
import SQLite3
@testable import LevelEditorFormats

final class EnemyReinforcementCallTests: XCTestCase {
    private func content(starts: [Point] = [.zero], base: BattleContent? = nil) throws -> BattleContent {
        let source = try base ?? BattleTestFixture.authored()
        let officer = try XCTUnwrap(source.enemies.first { $0.id == Foe.mountedOfficer.id })
        let level = BattleTestFixture.level(enemy: officer, slots: [], starts: starts)
        return try BattleTestFixture.content(level: level, enemies: source.enemies, base: source)
    }

    @MainActor private func simulation(_ content: BattleContent) throws -> GameSimulation {
        let sim = try GameSimulation(recording: .evaluation, content: content,
            startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave(); sim.step()
        return sim
    }

    @MainActor func testFiniteReservesEnterThroughCallersOwnRoadAndKeepWaveOrigin() throws {
        let battle = try content(starts: [.zero, Point(0, 1000)])
        let sim = try simulation(battle), game = sim.engine
        let rule = try XCTUnwrap(game.walkers.first?.reinforcementCall?.rules)
        var seen = Set(game.walkers.map(\.id)), reserveCount = 0
        for _ in 0..<(SimClock.ticksPerSecond * 40) {
            sim.step()
            for walker in game.walkers where seen.insert(walker.id).inserted {
                reserveCount += 1
                XCTAssertLessThan(walker.pathDistance, 10, "Reserve troops enter at the entrance, not at their caller")
                XCTAssertEqual(walker.position.y, Double(walker.pathIndex) * 1000, accuracy: 0.001)
                XCTAssertEqual(game.spawnOrigins[walker.id]?.type, Foe.redcoatRegular.id)
                XCTAssertEqual(game.spawnOrigins[walker.id]?.wave, 0)
                XCTAssertNil(walker.reinforcementCall, "A reserve must not recursively generate troops")
            }
        }
        XCTAssertEqual(reserveCount, 2 * rule.count * rule.maxCalls)
        XCTAssertTrue(game.walkers.filter { $0.reinforcementCall != nil }.allSatisfy {
            $0.reinforcementCall!.callsMade == rule.maxCalls
        })
        XCTAssertTrue(game.pendingSpawns.isEmpty)
        XCTAssertNil(sim.runID, "Combat works without a replay recording")
    }

    @MainActor func testEngagementInterruptsSignalAndKillingCallerPreventsFutureReserves() throws {
        let sim = try simulation(content()), game = sim.engine
        let id = try XCTUnwrap(game.walkers.first?.id)
        let rule = try XCTUnwrap(game.walkers.first?.reinforcementCall?.rules)
        for _ in 0..<(BattleGeometry.fireTicks(rule.initialDelay) + 2) { sim.step() }
        XCTAssertNotNil(game.walkers.first?.reinforcementCall?.signalStartTick)
        game.blockedWalkerIDs.insert(id)
        game.advanceEnemyReinforcementCalls()
        XCTAssertNil(game.walkers.first?.reinforcementCall?.signalStartTick)
        XCTAssertEqual(game.walkers.first?.reinforcementCall?.callsMade, 0)
        XCTAssertTrue(game.pendingSpawns.isEmpty)
        game.damageWalker(id: id, damage: 100_000, slotIndex: 0)
        sim.step()
        XCTAssertEqual(game.outcome, .victory)
        XCTAssertTrue(game.walkers.isEmpty)
        XCTAssertTrue(game.pendingSpawns.isEmpty)
    }

    @MainActor func testDispatchedTroopsSurviveCallerDeathAndPreventPrematureVictory() throws {
        let sim = try simulation(content()), game = sim.engine
        let id = try XCTUnwrap(game.walkers.first?.id)
        let rule = try XCTUnwrap(game.walkers.first?.reinforcementCall?.rules)
        for _ in 0..<(BattleGeometry.fireTicks(rule.initialDelay + rule.windup) + 2) { sim.step() }
        XCTAssertFalse(game.pendingSpawns.isEmpty)
        XCTAssertEqual(game.walkers.first { $0.id == id }?.reinforcementCall?.callsMade, 1)
        game.damageWalker(id: id, damage: 100_000, slotIndex: 0)
        sim.step()
        XCTAssertNil(game.outcome)
        for _ in 0..<BattleGeometry.fireTicks(Double(rule.count) * rule.spawnInterval + 1) { sim.step() }
        XCTAssertEqual(game.walkers.count, rule.count)
        for walker in game.walkers { game.damageWalker(id: walker.id, damage: 100_000, slotIndex: 0) }
        sim.step()
        XCTAssertEqual(game.outcome, .victory)
        XCTAssertEqual(game.killedCount, 1 + rule.count)
    }

    @MainActor func testDisplayCatchUpAndHeadlessTicksDispatchTheSameTroops() throws {
        let battle = try content()
        let sim = try simulation(battle)
        let player = try BattleEngine(recording: .preview, content: battle, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1776, onVictory: { _, _ in 0 })
        player.publishesPresentation = true
        player.startNextWave(); player.advance(ticks: 1, interpolation: 0)
        for _ in 0..<(SimClock.ticksPerSecond * 35 / 5) {
            player.advance(ticks: 0, interpolation: 0.5)
            player.advance(ticks: 5, interpolation: 0)
            for _ in 0..<5 { sim.step() }
        }
        XCTAssertEqual(player.walkers, sim.engine.walkers)
        XCTAssertEqual(player.money, sim.gold)
        XCTAssertEqual(player.lives, sim.lives)
        XCTAssertEqual(player.nextWalkerID, sim.engine.nextWalkerID)
    }

    @MainActor func testDatabaseEditsChangeDispatchAndMissingInvalidReferencesFail() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let original = try XCTUnwrap(fixture.db.enemyTypeDao.getAll().first { $0.id == Foe.mountedOfficer.id })
        let rules = try XCTUnwrap(original.reinforcementCallRules)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(rules)) as? [String: Any])
        func write(_ content: [String: Any]) throws {
            var trait = content; trait["type"] = "reinforcementCall"
            let json = String(decoding: try JSONSerialization.data(withJSONObject: [trait]), as: UTF8.self)
                .replacingOccurrences(of: "'", with: "''")
            XCTAssertEqual(sqlite3_exec(fixture.connection,
                "UPDATE enemy_type SET traits='\(json)' WHERE enemy_type_key='mounted_officer'", nil, nil, nil), SQLITE_OK)
        }
        var changed = fields
        changed["count"] = rules.count + 1
        changed["maxCalls"] = 1
        try write(changed)
        let base = try BattleTestFixture.authored(db: fixture.db)
        let sim = try simulation(content(base: base))
        for _ in 0..<(SimClock.ticksPerSecond * 20) { sim.step() }
        XCTAssertEqual(sim.engine.walkers.count, 1 + rules.count + 1)
        for field in fields.keys {
            var missing = fields; missing.removeValue(forKey: field)
            try write(missing)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains(field))
            }
        }
        for (field, invalid) in [("count", 0 as Any), ("windup", -1 as Any),
                                 ("enemyTypeKey", "missing_reserve" as Any),
                                 ("enemyTypeKey", "mounted_officer" as Any)] {
            var bad = fields; bad[field] = invalid
            try write(bad)
            XCTAssertThrowsError(try fixture.db.enemyTypeDao.getAll()) {
                XCTAssertTrue(String(describing: $0).contains(field))
            }
        }
    }

    @MainActor func testRecordingPreservesSignalsAndDynamicallySpawnedTroops() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .simulator),
            content: content(), startingMoney: nil, heroesEnabled: false, seed: 1776)
        sim.startNextWave()
        var expected: [Int64: [EnemyReinforcementCall?]] = [:]
        for _ in 0..<(SimClock.ticksPerSecond * 13) {
            sim.step()
            expected[sim.engine.timer.tick] = sim.engine.walkers.map(\.reinforcementCall)
        }
        sim.finishRecording(status: .timeout)
        let movie = try LevelReplayer(dao: fixture.db.levelRunDao, runID: XCTUnwrap(sim.runID))
        var sawSignal = false, sawReserve = false
        while try movie.advance() {
            let frame = try XCTUnwrap(movie.frame)
            guard let calls = expected[frame.tick] else { continue }
            XCTAssertEqual(frame.presentation.walkers.map(\.reinforcementCall), calls)
            sawSignal = sawSignal || calls.contains { $0?.signalStartTick != nil }
            sawReserve = sawReserve || frame.presentation.walkers.count > 1
        }
        XCTAssertTrue(sawSignal)
        XCTAssertTrue(sawReserve)
    }
}
