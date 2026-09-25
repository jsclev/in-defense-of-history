import XCTest
import SQLite3
@testable import LevelEditorFormats

final class PlaySpeedTests: XCTestCase {
    private func databaseFixture() throws -> AuthoredDatabaseFixture {
        try AuthoredDatabaseFixture(levelGeoJSONDao: LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
    }
    private func execute(_ sql: String, in fixture: AuthoredDatabaseFixture) throws {
        guard sqlite3_exec(fixture.connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw DbError.Db(message: String(cString: sqlite3_errmsg(fixture.connection)))
        }
    }

    @MainActor func testDatabaseRatesPropagateIntoPlayerAndSimulator() throws {
        let fixture = try databaseFixture()
        let authored = try fixture.db.playSpeedDao.get()
        XCTAssertEqual(authored.player.factor, 1)
        XCTAssertEqual(authored.editor.factor, 1)
        XCTAssertEqual(authored.simulator.factor, 1_000_000_000)
        try execute("UPDATE play_speed SET factor=0.5 WHERE source='player'; UPDATE play_speed SET factor=8 WHERE source='simulator'", in: fixture)
        let content = try BattleTestFixture.authored(db: fixture.db)
        let player = try BattleEngine(recording: .preview, content: content, heroesEnabled: false,
            startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
        let simulator = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: false, seed: 1)
        XCTAssertEqual(player.playSpeed.factor, 0.5)
        XCTAssertEqual(player.timer.tickDuration / .seconds(SimClock.dt), 2, accuracy: 1e-8)
        XCTAssertEqual(simulator.playSpeed.factor, 8)
        XCTAssertEqual(simulator.engine.timer.tickDuration / .seconds(SimClock.dt), 0.125, accuracy: 1e-8)
        XCTAssertEqual(try content.selectingMetaUpgrades([]).playSpeeds.simulator.factor, 8)
    }

    func testMissingAndMalformedDatabaseRatesFail() throws {
        let fixture = try databaseFixture()
        try execute("DELETE FROM play_speed WHERE source='player'", in: fixture)
        XCTAssertThrowsError(try fixture.db.playSpeedDao.get()) { error in
            XCTAssertTrue(String(describing: error).contains("play_speed[player].factor"))
        }
        // Malformed content is tested in disposable memory, bypassing DDL
        // constraints only to prove that the DAO also rejects damaged input.
        try execute("DROP TABLE play_speed; CREATE TABLE play_speed(source TEXT, factor);", in: fixture)
        for literal in ["NULL", "'fast'", "0", "-1", "1e999", "0.001", "1000000001"] {
            try execute("DELETE FROM play_speed; INSERT INTO play_speed VALUES('player', \(literal))", in: fixture)
            XCTAssertThrowsError(try fixture.db.playSpeedDao.get(for: .player), literal)
        }
        for invalid in [Double.nan, .infinity, -.infinity, 0, -1, 0.001, 1e10] {
            XCTAssertThrowsError(try PlaySpeed(invalid))
        }
    }

    func testClockPreservesFractionalProgressAndDoesNotSkipCatchUpTicks() throws {
        var now = ContinuousClock().now
        let timer = LevelEditorFormats.Timer(tickDuration: try PlaySpeed(1).tickDuration, now: { now })
        now = now.advanced(by: .seconds(SimClock.dt * 0.5))
        XCTAssertEqual(timer.dueTicks(), 0)
        XCTAssertEqual(timer.interpolationAlpha, 0.5, accuracy: 1e-6)
        timer.setTickDuration(try PlaySpeed(2).tickDuration)
        XCTAssertEqual(timer.interpolationAlpha, 0.5, accuracy: 1e-6)
        now = now.advanced(by: .seconds(SimClock.dt * 0.26))
        XCTAssertEqual(timer.dueTicks(), 1)
        timer.advanceTick()
        timer.setTickDuration(try PlaySpeed(0.5).tickDuration)
        now = now.advanced(by: .seconds(2))
        XCTAssertEqual(timer.dueTicks(), 8)
        for _ in 0..<8 { timer.advanceTick() }
        XCTAssertEqual(timer.dueTicks(), 8, "Catch-up batches retain every pending tick")
        let before = timer.tick
        timer.resync()
        XCTAssertEqual(timer.tick, before)
        XCTAssertEqual(timer.dueTicks(), 0, "Resuming does not replay paused wall time")
        timer.setTickDuration(try PlaySpeed(1e9).tickDuration)
        now = now.advanced(by: .seconds(1_000_000))
        XCTAssertEqual(timer.dueTicks(), 8, "High factors must clamp before integer conversion")
        let completedTick = timer.tick
        timer.setTickDuration(try PlaySpeed(0.5).tickDuration)
        XCTAssertEqual(timer.tick, completedTick, "Changing speed must not skip battle ticks")
        XCTAssertEqual(timer.dueTicks(), 0, "Slowing an overloaded fast run must immediately use the new rate")
        now = now.advanced(by: .seconds(0.07))
        XCTAssertEqual(timer.dueTicks(), 1)
    }

    @MainActor func testRunRecordsInitialAndDynamicSpeedAndReplayOverrideIsReadOnly() throws {
        let fixture = try databaseFixture()
        let content = try BattleTestFixture.authored(db: fixture.db)
        let player = try BattleEngine(recording: .database(fixture.db.levelRunDao, .player), content: content,
            heroesEnabled: false, startingMoneyOverride: nil, seed: 1, onVictory: { _, _ in 0 })
        let id = try XCTUnwrap(player.runID)
        XCTAssertEqual(try fixture.db.levelRunDao.get(id: id).playSpeed.factor, 1)
        player.setPlaySpeed(try PlaySpeed(0.5))
        player.advance(ticks: 1, interpolation: 1)
        player.setPlaySpeed(try PlaySpeed(4))
        player.advance(ticks: 1, interpolation: 1)
        player.finishRecording(status: .abandoned)
        try execute("UPDATE play_speed SET factor=8 WHERE source='player'", in: fixture)
        let writes = sqlite3_total_changes(fixture.connection)
        let replay = try LevelReplayer(dao: fixture.db.levelRunDao, runID: id)
        XCTAssertEqual(replay.playSpeed.factor, 1)
        XCTAssertTrue(try replay.advance())
        XCTAssertEqual(replay.playSpeed.factor, 0.5)
        XCTAssertEqual(replay.frameWallSeconds, SimClock.dt * 2, accuracy: 1e-9)
        XCTAssertTrue(replay.actions.contains { $0.name == "setPlaySpeed" && $0.payloadJSON.contains("0.5") })
        XCTAssertTrue(try replay.advance())
        XCTAssertEqual(replay.playSpeed.factor, 4)
        replay.setPlaySpeedOverride(try PlaySpeed(2))
        XCTAssertEqual(replay.frameWallSeconds, SimClock.dt / 2, accuracy: 1e-9)
        XCTAssertTrue(try replay.advance())
        XCTAssertEqual(replay.playSpeed.factor, 2)
        replay.setPlaySpeedOverride(nil)
        XCTAssertEqual(replay.playSpeed.factor, 4)
        XCTAssertFalse(try replay.advance())
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes)
        XCTAssertEqual(try fixture.db.levelRunDao.get(id: id).playSpeed.factor, 1)
    }

    @MainActor func testHeadlessPacingHonorsConfiguredWallRate() throws {
        let fixture = try databaseFixture()
        try execute("UPDATE play_speed SET factor=0.5 WHERE source='simulator'", in: fixture)
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .simulator),
            content: BattleTestFixture.authored(db: fixture.db), startingMoney: nil, heroesEnabled: false, seed: 1)
        let clock = ContinuousClock(), start = ContinuousClock().now
        for _ in 0..<3 { sim.stepPaced() }
        let elapsed = start.duration(to: clock.now) / .seconds(1)
        XCTAssertGreaterThanOrEqual(elapsed, 0.199)
        XCTAssertEqual(sim.time, 0.1, accuracy: 1e-9)
        sim.finishRecording(status: .timeout)
        XCTAssertEqual(try fixture.db.levelRunDao.get(id: XCTUnwrap(sim.runID)).playSpeed.factor, 0.5)
    }

    @MainActor func testSpeedChangesLeaveAllCombatTicksAndResultsIdentical() throws {
        let content = try BattleTestFixture.authored()
        let slow = try GameSimulation(recording: .preview, content: content, playSpeed: PlaySpeed(0.5), startingMoney: nil, heroesEnabled: true, seed: 3)
        let fast = try GameSimulation(recording: .preview, content: content, startingMoney: nil, heroesEnabled: true, seed: 3)
        slow.startNextWave(); fast.startNextWave()
        for tick in 0..<120 {
            if tick == 30 { slow.setPlaySpeed(try PlaySpeed(2)) }
            if tick == 60 { slow.pause(); slow.resume() }
            slow.step(); fast.step()
            XCTAssertEqual(slow.result(), fast.result())
            XCTAssertEqual(slow.enemies.map(\.position), fast.enemies.map(\.position))
            XCTAssertEqual(slow.enemies.map(\.hp), fast.enemies.map(\.hp))
        }
    }

    func testMovieTimingAtFractionalFastAndChangingRates() throws {
        for (factor, expectedFrames) in [(0.5, 60), (1.0, 30), (2.0, 15), (1e9, 1)] {
            var timing = LevelReplayTiming(framesPerSecond: 30)
            var frames: [Int] = []
            for _ in 0..<30 { frames += timing.append(gameSeconds: 1 / 30, speed: try PlaySpeed(factor)) }
            XCTAssertEqual(frames, Array(0..<expectedFrames))
            XCTAssertEqual(timing.wallSeconds, 1 / factor, accuracy: 1e-9)
        }
        var timing = LevelReplayTiming(framesPerSecond: 30)
        for _ in 0..<30 { _ = timing.append(gameSeconds: 1 / 30, speed: try PlaySpeed(1)) }
        for _ in 0..<30 { _ = timing.append(gameSeconds: 1 / 30, speed: try PlaySpeed(2)) }
        XCTAssertEqual(timing.outputFrames, 45)
        XCTAssertEqual(timing.wallSeconds, 1.5, accuracy: 1e-9)
    }

    @MainActor func testEditorUsesAuthoredFractionalRateAndDiscardsPausedWallTime() throws {
        let fixture = try databaseFixture()
        try execute("UPDATE play_speed SET factor=0.5 WHERE source='editor'", in: fixture)
        let file = try NativeMapFile.read(Data(contentsOf: Db.authoredDatabaseURL.deletingLastPathComponent()
            .appendingPathComponent("level_15_charleston.tdmap")))
        let session = try SimSession(draft: file.draft, db: fixture.db, virtualCanvas: file.canvas)
        let date = Date(timeIntervalSince1970: 0)
        session.advance(to: date)
        session.advance(to: date.addingTimeInterval(0.25))
        XCTAssertEqual(session.sim.time, 0.1, accuracy: 1e-9)
        session.speed = 2
        session.advance(to: date.addingTimeInterval(0.5))
        XCTAssertEqual(session.sim.time, 0.6, accuracy: 1e-9)
        session.paused = true; session.paused = false
        session.advance(to: date.addingTimeInterval(100))
        XCTAssertEqual(session.sim.time, 0.6, accuracy: 1e-9)
        let runID = try XCTUnwrap(session.sim.runID)
        session.sim.finishRecording(status: .abandoned)
        XCTAssertEqual(try fixture.db.levelRunDao.get(id: runID).playSpeed.factor, 0.5)
        let replay = try LevelReplayer(dao: fixture.db.levelRunDao, runID: runID)
        while try replay.advance() {}
        XCTAssertEqual(replay.playSpeed.factor, 2)
    }
}
