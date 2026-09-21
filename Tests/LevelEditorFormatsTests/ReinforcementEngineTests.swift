import XCTest
import SQLite3
@testable import LevelEditorFormats

/// These tests drive the production engine without a HUD or display clock.
final class ReinforcementEngineTests: XCTestCase {
    private func ticks(_ seconds: Double) -> Int {
        Int((seconds * Double(SimClock.ticksPerSecond)).rounded(.up))
    }

    @MainActor private func engine(db: Db? = nil) throws -> BattleEngine {
        try BattleEngine(content: BattleTestFixture.authored(db: db), heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
    }

    @MainActor private func destination(_ engine: BattleEngine) -> Point {
        let path = engine.content.level.paths[0]
        return path.point(atDistance: path.totalLength / 2)
    }

    @MainActor private func assertFullCooldown(_ engine: BattleEngine,
                                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(engine.canCallReinforcements, file: file, line: line)
        XCTAssertEqual(engine.reinforcementCooldown.remainingSeconds,
            Double(ticks(engine.content.reinforcementConfig.cooldownSeconds)) / Double(SimClock.ticksPerSecond),
            accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(engine.reinforcementCooldown.remainingFraction, 1, file: file, line: line)
    }

    @MainActor func testWaitingBeforeFirstDeploymentDoesNotPrechargeItsCooldown() throws {
        let battle = try engine()
        let duration = ticks(battle.content.reinforcementConfig.cooldownSeconds)
        battle.advance(ticks: duration - ticks(1), interpolation: 0)
        XCTAssertTrue(battle.canCallReinforcements)
        XCTAssertEqual(battle.reinforcementCooldown, .ready)
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .ok)
        assertFullCooldown(battle)
        battle.advance(ticks: ticks(1), interpolation: 0)
        XCTAssertFalse(battle.canCallReinforcements, "Battle-entry time must not replenish a deployment")
    }

    @MainActor func testLongIdleCannotStoreAnExtraDeployment() throws {
        let battle = try engine()
        battle.advance(ticks: ticks(battle.content.reinforcementConfig.cooldownSeconds * 3), interpolation: 0)
        let point = destination(battle)
        XCTAssertEqual(battle.perform(.reinforcements(point: point)), .ok)
        assertFullCooldown(battle)
        XCTAssertEqual(battle.perform(.reinforcements(point: point)), .invalid)
        XCTAssertEqual(battle.garrisonsBySlot.keys.filter { $0 < 0 }.count, 1)
    }

    @MainActor func testEveryDeploymentHasOneFullCooldownWithAnExactReadyBoundary() throws {
        let battle = try engine()
        let duration = ticks(battle.content.reinforcementConfig.cooldownSeconds)
        let point = destination(battle)
        for idle in [ticks(7), ticks(35), 0] {
            battle.advance(ticks: idle, interpolation: 0)
            XCTAssertEqual(battle.perform(.reinforcements(point: point)), .ok)
            assertFullCooldown(battle)
            battle.advance(ticks: duration / 2, interpolation: 0.9)
            XCTAssertEqual(battle.reinforcementCooldown.remainingFraction, 0.5, accuracy: 1e-9)
            let halfway = battle.reinforcementCooldown
            XCTAssertEqual(battle.perform(.reinforcements(point: point)), .invalid)
            XCTAssertEqual(battle.reinforcementCooldown, halfway)
            battle.advance(ticks: duration - duration / 2 - 1, interpolation: 0)
            XCTAssertFalse(battle.canCallReinforcements)
            XCTAssertEqual(battle.reinforcementCooldown.remainingSeconds, SimClock.dt, accuracy: 1e-9)
            battle.advance(ticks: 1, interpolation: 0)
            XCTAssertTrue(battle.canCallReinforcements)
            XCTAssertEqual(battle.reinforcementCooldown, .ready)
        }
    }

    @MainActor func testSelectionCancellationAndInvalidPlacementDoNotSpendOrResetCooldown() throws {
        let battle = try engine()
        battle.toggleReinforcementPlacement()
        XCTAssertTrue(battle.isPlacingReinforcements)
        battle.advance(ticks: ticks(6), interpolation: 0)
        XCTAssertEqual(battle.reinforcementCooldown, .ready)
        battle.toggleReinforcementPlacement()
        XCTAssertFalse(battle.isPlacingReinforcements)
        XCTAssertEqual(battle.perform(.reinforcements(point: Point(-100_000, -100_000))), .invalid)
        XCTAssertEqual(battle.reinforcementCooldown, .ready)
        XCTAssertTrue(battle.garrisonsBySlot.isEmpty)
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .ok)
        assertFullCooldown(battle)
        battle.advance(ticks: ticks(3), interpolation: 0)
        let prior = battle.reinforcementCooldown
        battle.toggleReinforcementPlacement()
        XCTAssertFalse(battle.isPlacingReinforcements)
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .invalid)
        XCTAssertEqual(battle.reinforcementCooldown, prior)
    }

    @MainActor func testSelectingReinforcementsReplacesTowerMenusAndRallyPlacementWithoutSpendingCooldown() throws {
        let battle = try engine()
        battle.selectSlot(0)
        battle.toggleReinforcementPlacement()
        XCTAssertTrue(battle.isPlacingReinforcements)
        XCTAssertNil(battle.selectedSlotIndex)
        XCTAssertEqual(battle.reinforcementCooldown, .ready)
        battle.toggleReinforcementPlacement()

        XCTAssertEqual(battle.perform(.build(slot: 0, kind: .melee)), .ok)
        for placingRally in [false, true] {
            battle.selectPlacedTower(atSlot: 0)
            if placingRally { battle.toggleRallyPlacement() }
            XCTAssertEqual(battle.selectedTowerSlotIndex, 0)
            battle.toggleReinforcementPlacement()
            XCTAssertTrue(battle.isPlacingReinforcements)
            XCTAssertNil(battle.selectedTowerSlotIndex)
            XCTAssertFalse(battle.isPlacingRallyPoint)
            XCTAssertEqual(battle.reinforcementCooldown, .ready)
            battle.toggleReinforcementPlacement()
        }
    }

    @MainActor func testPauseInterpolationAndSpeedChangesCannotAdvanceOrResetCooldown() throws {
        let battle = try engine()
        battle.pause()
        XCTAssertFalse(battle.canCallReinforcements)
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .invalid)
        battle.resume()
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .ok)
        battle.advance(ticks: ticks(4), interpolation: 0)
        let before = battle.reinforcementCooldown
        let tick = battle.timer.tick
        battle.pause()
        battle.advance(ticks: ticks(100), interpolation: 0.75)
        battle.speedUp()
        XCTAssertEqual(battle.timer.tick, tick)
        XCTAssertEqual(battle.reinforcementCooldown, before)
        battle.resume()
        battle.advance(ticks: 0, interpolation: 0.95)
        XCTAssertEqual(battle.reinforcementCooldown, before)
        battle.advance(ticks: ticks(1), interpolation: 0)
        XCTAssertEqual(battle.reinforcementCooldown.remainingSeconds, before.remainingSeconds - 1, accuracy: 1e-9)
    }

    @MainActor func testLiveAndExpiredGroupsNeverGateOrResetTheCooldown() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        defer { fixture.db.close() }
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE reinforcement_config SET cooldown_seconds=3.25, time_to_live_seconds=30 WHERE id=1",
            nil, nil, nil), SQLITE_OK)
        let battle = try engine(db: fixture.db)
        let point = destination(battle)
        for _ in 0..<4 {
            XCTAssertEqual(battle.perform(.reinforcements(point: point)), .ok)
            assertFullCooldown(battle)
            battle.advance(ticks: 97, interpolation: 0)
            XCTAssertFalse(battle.canCallReinforcements)
            battle.advance(ticks: 1, interpolation: 0)
            XCTAssertTrue(battle.canCallReinforcements, "Only the cooldown deadline controls readiness, even with several groups alive")
        }
        XCTAssertEqual(battle.garrisonsBySlot.keys.filter { $0 < 0 }.count, 4)
        battle.advance(ticks: ticks(30) - Int(battle.timer.tick), interpolation: 0)
        XCTAssertNil(battle.garrisonsBySlot[-1])
        XCTAssertNotNil(battle.garrisonsBySlot[-2], "Each deployment keeps its own lifetime")
        XCTAssertEqual(battle.reinforcementCooldown, .ready)
        XCTAssertEqual(battle.perform(.reinforcements(point: point)), .ok)
        assertFullCooldown(battle)
    }

    @MainActor func testExpiredTroopsDoNotFinishTheCooldownAndRestartStartsReady() throws {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        defer { fixture.db.close() }
        XCTAssertEqual(sqlite3_exec(fixture.connection,
            "UPDATE reinforcement_config SET cooldown_seconds=20, time_to_live_seconds=2 WHERE id=1",
            nil, nil, nil), SQLITE_OK)
        let battle = try engine(db: fixture.db)
        XCTAssertEqual(battle.perform(.reinforcements(point: destination(battle))), .ok)
        battle.advance(ticks: ticks(2), interpolation: 0)
        XCTAssertTrue(battle.garrisonsBySlot.isEmpty)
        XCTAssertFalse(battle.canCallReinforcements)
        XCTAssertEqual(battle.reinforcementCooldown.remainingSeconds, 18)
        let restarted = try engine(db: fixture.db)
        XCTAssertEqual(restarted.reinforcementCooldown, .ready)
        XCTAssertTrue(restarted.canCallReinforcements)
        XCTAssertEqual(restarted.perform(.reinforcements(point: destination(restarted))), .ok)
        assertFullCooldown(restarted)
    }

    func testIndividualAndBatchedTicksPublishTheSameEngineCooldown() async throws {
        let content = try BattleTestFixture.authored()
        try await MainActor.run {
            let single = try GameSimulation(content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
            let batched = try GameSimulation(content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
            let point = content.level.paths[0].point(atDistance: content.level.paths[0].totalLength / 2)
            for sim in [single, batched] {
                XCTAssertEqual(sim.perform(.reinforcements(point: Point(-100_000, -100_000))), .invalid)
                XCTAssertTrue(sim.engine.reinforcementCooldown.isReady)
                XCTAssertEqual(sim.perform(.reinforcements(point: point)), .ok)
                XCTAssertFalse(sim.engine.reinforcementCooldown.isReady)
                XCTAssertEqual(sim.engine.reinforcementCooldown.remainingFraction, 1)
                let cooldown = sim.engine.reinforcementCooldown
                sim.engine.pause()
                sim.engine.advance(ticks: 120, interpolation: 0.5)
                XCTAssertEqual(sim.engine.reinforcementCooldown, cooldown)
                XCTAssertEqual(sim.perform(.reinforcements(point: point)), .invalid)
                sim.engine.resume()
                sim.engine.speedUp()
                XCTAssertEqual(sim.engine.reinforcementCooldown, cooldown)
            }
            let ticks = Int64(ticks(content.reinforcementConfig.cooldownSeconds))
            for _ in 0..<(ticks / 4) {
                for _ in 0..<4 { single.step() }
                batched.engine.advance(ticks: 0, interpolation: 0.9)
                batched.engine.advance(ticks: 4, interpolation: 0.25)
                XCTAssertEqual(single.engine.reinforcementCooldown, batched.engine.reinforcementCooldown)
                XCTAssertEqual(single.engine.reinforcementCooldown.isReady, single.canCallReinforcements)
                XCTAssertEqual(batched.engine.reinforcementCooldown.isReady, batched.canCallReinforcements)
            }
            for _ in 0..<(ticks % 4) { single.step(); batched.step() }
            XCTAssertTrue(single.engine.reinforcementCooldown.isReady)
            XCTAssertEqual(single.engine.reinforcementCooldown.remainingFraction, 0)
            XCTAssertTrue(single.canCallReinforcements)
        }
    }
}
