import XCTest
import SQLite3
@testable import LevelEditorFormats

final class WaveStartTimingTests: XCTestCase {
    private func wave(delay: Double = 15, countdown: Double = 10, bonus: Int = 13) -> Wave {
        Wave(startTime: 0, spawns: [], callButtonDelay: delay, autoStartCountdown: countdown, earlyCallBonus: bonus)
    }

    private func tick(_ seconds: Double) -> Int64 {
        Int64((seconds * Double(SimClock.ticksPerSecond)).rounded())
    }

    func testFirstWaveWaitsIndefinitelyAndSingleWaveFinishesSchedule() throws {
        var schedule = try WaveStartSchedule(waves: [wave()])
        XCTAssertEqual(schedule.state(at: tick(10_000)), .manualFirstWave)
        XCTAssertNil(schedule.startNextWave(at: tick(10_000), manually: false))
        XCTAssertEqual(schedule.startNextWave(at: tick(10_000), manually: true)?.index, 0)
        XCTAssertEqual(schedule.state(at: tick(10_000)), .finished)
        XCTAssertNil(schedule.startNextWave(at: tick(10_000), manually: true))
    }

    func testRevealCountdownAndAutomaticDeadlineUseActualPreviousStart() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave()])
        XCTAssertEqual(schedule.startNextWave(at: tick(100), manually: true)?.index, 0)
        XCTAssertEqual(schedule.state(at: tick(115) - 1), .hidden)
        XCTAssertNil(schedule.startNextWave(at: tick(114), manually: true))
        XCTAssertEqual(schedule.state(at: tick(115)), .countingDown(seconds: 10))
        XCTAssertEqual(schedule.state(at: tick(116)), .countingDown(seconds: 9))
        XCTAssertEqual(schedule.state(at: tick(125) - 1), .countingDown(seconds: 1))
        XCTAssertNil(schedule.startNextWave(at: tick(125) - 1, manually: false))
        XCTAssertEqual(schedule.state(at: tick(125)), .due)
        XCTAssertEqual(schedule.startNextWave(at: tick(125), manually: false)?.index, 1)
        XCTAssertNil(schedule.startNextWave(at: tick(126), manually: false))
        XCTAssertEqual(schedule.state(at: tick(126)), .finished)
    }

    func testEarlyCallReanchorsFollowingWaveAndRejectsRepeatedTap() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave(), wave(delay: 3, countdown: 4)])
        XCTAssertEqual(schedule.startNextWave(at: 0, manually: true)?.index, 0)
        XCTAssertEqual(schedule.startNextWave(at: tick(18), manually: true)?.index, 1)
        XCTAssertNil(schedule.startNextWave(at: tick(18), manually: true))
        XCTAssertEqual(schedule.state(at: tick(21)), .countingDown(seconds: 4))
        XCTAssertEqual(schedule.startNextWave(at: tick(25), manually: false)?.index, 2)
        XCTAssertNil(schedule.startNextWave(at: tick(25), manually: true))
    }

    func testZeroDelayZeroCountdownAndEmptySchedules() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave(delay: 0, countdown: 2),
                                                  wave(delay: 3, countdown: 0)])
        XCTAssertEqual(schedule.startNextWave(at: 0, manually: true)?.index, 0)
        XCTAssertEqual(schedule.state(at: 0), .countingDown(seconds: 2))
        XCTAssertEqual(schedule.startNextWave(at: tick(2), manually: false)?.index, 1)
        XCTAssertEqual(schedule.state(at: tick(5) - 1), .hidden)
        XCTAssertEqual(schedule.state(at: tick(5)), .due)
        XCTAssertEqual(schedule.startNextWave(at: tick(5), manually: false)?.index, 2)
        var empty = try WaveStartSchedule(waves: [])
        XCTAssertTrue(empty.allWavesStarted)
        XCTAssertEqual(empty.state(at: 0), .finished)
        XCTAssertNil(empty.startNextWave(at: 0, manually: true))
    }

    func testFractionalTimingNeverStartsBeforeConfiguredDuration() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave(delay: 0.05, countdown: 0.05)])
        _ = schedule.startNextWave(at: 0, manually: true)
        XCTAssertEqual(schedule.state(at: 1), .hidden)
        XCTAssertEqual(schedule.state(at: 2), .countingDown(seconds: 1))
        XCTAssertEqual(schedule.state(at: 3), .countingDown(seconds: 1))
        XCTAssertEqual(schedule.state(at: 4), .due)
    }

    func testPausedClockDoesNotConsumeCountdown() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave()])
        _ = schedule.startNextWave(at: 0, manually: true)
        let pausedTick = tick(20)
        XCTAssertEqual(schedule.state(at: pausedTick), .countingDown(seconds: 5))
        // Wall time and speed are not inputs: only advancing game ticks counts.
        XCTAssertEqual(schedule.state(at: pausedTick), .countingDown(seconds: 5))
        XCTAssertEqual(schedule.state(at: tick(22)), .countingDown(seconds: 3))
    }

    func testWaveDocumentCompatibilityAndTimingRoundTrip() throws {
        let old = Data(#"{"startTime":5,"spawns":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(Wave.self, from: old)
        XCTAssertEqual(decoded, Wave(startTime: 5, spawns: []))
        XCTAssertNil(decoded.callButtonDelay)
        XCTAssertNil(decoded.autoStartCountdown)
        XCTAssertNil(decoded.earlyCallBonus)
        XCTAssertThrowsError(try WaveStartSchedule(waves: [decoded]))
        let tuned = wave(delay: 4.5, countdown: 7.25)
        XCTAssertEqual(try JSONDecoder().decode(Wave.self, from: JSONEncoder().encode(tuned)), tuned)
    }

    func testScheduleRejectsMissingAndInvalidTimingInsteadOfUsingDefaults() {
        XCTAssertThrowsError(try WaveStartSchedule(waves: [Wave(startTime: 0, spawns: [],
                                                                callButtonDelay: 5)]))
        XCTAssertThrowsError(try WaveStartSchedule(waves: [wave(delay: -1)]))
        XCTAssertThrowsError(try WaveStartSchedule(waves: [wave(countdown: .infinity)]))
    }

    func testConfiguredRevealAndAutomaticStartDeadlines() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave(delay: 27.3, countdown: 13)])
        XCTAssertEqual(schedule.startNextWave(at: 0, manually: true)?.index, 0)
        XCTAssertEqual(schedule.state(at: tick(27.3) - 1), .hidden)
        XCTAssertEqual(schedule.state(at: tick(27.3)), .countingDown(seconds: 13))
        XCTAssertEqual(schedule.state(at: tick(40.3)), .due)
    }

    func testManualEarlyCallAwardsItsDatabaseBonusExactlyOnce() throws {
        var schedule = try WaveStartSchedule(waves: [wave(bonus: 999), wave(bonus: 37), wave(bonus: 9)])
        let first = try XCTUnwrap(schedule.startNextWave(at: 0, manually: true))
        XCTAssertEqual(first.index, 0)
        XCTAssertEqual(first.moneyBonus, 0, "Wave 1 never earns money, even with a nonzero database value.")
        XCTAssertNil(schedule.startNextWave(at: tick(14), manually: true))
        let called = try XCTUnwrap(schedule.startNextWave(at: tick(18), manually: true))
        XCTAssertEqual(called.index, 1)
        XCTAssertEqual(called.moneyBonus, 37)
        XCTAssertNil(schedule.startNextWave(at: tick(18), manually: true), "Repeated taps cannot grant the same bonus again.")
        let automatic = try XCTUnwrap(schedule.startNextWave(at: tick(43), manually: false))
        XCTAssertEqual(automatic.index, 2)
        XCTAssertEqual(automatic.moneyBonus, 0, "Automatic starts never earn the manual-call bonus.")
        XCTAssertNil(schedule.startNextWave(at: tick(44), manually: true))
    }

    func testBonusIsFixedUntilDeadlineAndCanBeConfiguredToZero() throws {
        var schedule = try WaveStartSchedule(waves: [wave(), wave(bonus: 21), wave(bonus: 0)])
        _ = schedule.startNextWave(at: 0, manually: true)
        XCTAssertEqual(schedule.startNextWave(at: tick(25) - 1, manually: true)?.moneyBonus, 21)
        XCTAssertEqual(schedule.startNextWave(at: tick(40), manually: true)?.moneyBonus, 0)

        var expired = try WaveStartSchedule(waves: [wave(), wave(bonus: 21)])
        _ = expired.startNextWave(at: 0, manually: true)
        XCTAssertNil(expired.startNextWave(at: tick(25), manually: true))
        XCTAssertEqual(expired.startNextWave(at: tick(25), manually: false)?.moneyBonus, 0)
    }

    func testInteractiveScheduleRequiresValidBonusData() {
        XCTAssertThrowsError(try WaveStartSchedule(waves: [
            Wave(startTime: 0, spawns: [], callButtonDelay: 15, autoStartCountdown: 10)
        ]))
        XCTAssertThrowsError(try WaveStartSchedule(waves: [wave(bonus: -1)]))
    }

    func testDAOLoadsExplicitTimingAndPreservesSpawnGroups() throws {
        var conn: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &conn), SQLITE_OK)
        defer { sqlite3_close(conn) }
        func sql(_ text: String) throws {
            guard sqlite3_exec(conn, text, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "SQLite", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(conn))])
            }
        }
        let levelID = UUID()
        let enemyID = UUID()
        try sql("""
            CREATE TABLE level_wave (id TEXT PRIMARY KEY, level_info_id TEXT,
                wave_index INTEGER, spawn_time REAL,
                call_button_delay REAL NOT NULL CHECK (call_button_delay >= 0),
                auto_start_countdown REAL NOT NULL CHECK (auto_start_countdown >= 0),
                early_call_bonus INTEGER NOT NULL CHECK (early_call_bonus >= 0));
            CREATE TABLE level_wave_enemy_spawn (level_wave_id TEXT, spawn_index INTEGER,
                enemy_type_id TEXT, num_enemies INTEGER,
                spawn_time_since_previous_spawn REAL, spawn_interval REAL, path_index INTEGER);
            INSERT INTO level_wave VALUES
                ('a', '\(levelID.uuidString.lowercased())', 1, 5, 0, 0, 0),
                ('b', '\(levelID.uuidString.lowercased())', 2, 30, 27.3, 13, 37),
                ('c', '\(levelID.uuidString.lowercased())', 3, 35, 0, 6.5, 9);
            INSERT INTO level_wave_enemy_spawn VALUES
                ('b', 0, '\(enemyID.uuidString)', 2, 1.5, 0.8, 0),
                ('b', 1, '\(enemyID.uuidString)', 3, 2.0, 0.6, 1);
            """)
        let dao = WaveDAO(conn: conn)
        var waves = try dao.getWavesFor(levelInfoId: levelID)
        XCTAssertEqual(waves.count, 3)
        for (wave, expected) in zip(waves, [0.0, 27.3, 0.0]) {
            XCTAssertEqual(try XCTUnwrap(wave.callButtonDelay), expected, accuracy: 1e-9)
        }
        XCTAssertEqual(waves.map(\.autoStartCountdown), [0, 13, 6.5])
        XCTAssertEqual(waves.map(\.earlyCallBonus), [0, 37, 9])
        XCTAssertEqual(waves[1].spawns.map(\.delay), [1.5, 3.5])
        XCTAssertEqual(waves[1].spawns.map(\.pathIndex), [0, 1])
        XCTAssertEqual(waves[1].spawns.map(\.count), [2, 3])
        XCTAssertTrue(waves[0].spawns.isEmpty)
        try sql("UPDATE level_wave SET call_button_delay = 8.5, auto_start_countdown = 3.25 WHERE id = 'b'")
        waves = try dao.getWavesFor(levelInfoId: levelID)
        XCTAssertEqual(waves[1].callButtonDelay, 8.5)
        XCTAssertEqual(waves[1].autoStartCountdown, 3.25)
        XCTAssertThrowsError(try sql("UPDATE level_wave SET call_button_delay = -1"))
        XCTAssertThrowsError(try sql("UPDATE level_wave SET auto_start_countdown = -1"))
        XCTAssertThrowsError(try sql("UPDATE level_wave SET early_call_bonus = -1"))
        XCTAssertThrowsError(try sql("UPDATE level_wave SET early_call_bonus = NULL"))
        try sql("UPDATE level_wave SET early_call_bonus = 'invalid' WHERE id = 'b'")
        XCTAssertThrowsError(try dao.getWavesFor(levelInfoId: levelID))
        try sql("UPDATE level_wave SET early_call_bonus = 37 WHERE id = 'b'")
        try sql("UPDATE level_wave SET call_button_delay = 'invalid' WHERE id = 'b'")
        XCTAssertThrowsError(try dao.getWavesFor(levelInfoId: levelID))
    }
}
