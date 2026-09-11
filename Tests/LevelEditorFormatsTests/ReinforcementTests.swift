import XCTest
import SQLite3
@testable import LevelEditorFormats

final class ReinforcementTests: XCTestCase {
    private func tick(_ seconds: Double) -> Int64 {
        Int64((seconds * Double(SimClock.ticksPerSecond)).rounded())
    }

    func testRepeatedCallsAreBlockedUntilExactCooldownBoundary() throws {
        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 30, cooldownSeconds: 20))
        XCTAssertTrue(schedule.cooldown(at: tick(100)).isReady)
        XCTAssertTrue(schedule.deploy(slot: -1, at: tick(100)))
        XCTAssertEqual(schedule.cooldown(at: tick(100)).displaySeconds, 20)
        XCTAssertFalse(schedule.deploy(slot: -2, at: tick(100)))
        XCTAssertFalse(schedule.deploy(slot: -2, at: tick(120) - 1))
        XCTAssertEqual(schedule.cooldown(at: tick(120) - 1).displaySeconds, 1)
        XCTAssertTrue(schedule.cooldown(at: tick(120)).isReady)
        XCTAssertTrue(schedule.deploy(slot: -2, at: tick(120)))
        XCTAssertEqual(schedule.cooldown(at: tick(120)).displaySeconds, 20)
        XCTAssertFalse(schedule.deploy(slot: -3, at: tick(120)))
    }

    func testOverlappingGroupsExpireIndependentlyAndOnlyOnce() throws {
        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 30, cooldownSeconds: 20))
        XCTAssertTrue(schedule.deploy(slot: -1, at: tick(100)))
        XCTAssertTrue(schedule.deploy(slot: -2, at: tick(120)))
        XCTAssertEqual(schedule.expire(at: tick(130) - 1), [])
        XCTAssertEqual(schedule.expire(at: tick(130)), [-1])
        XCTAssertEqual(schedule.expire(at: tick(130)), [])
        XCTAssertEqual(schedule.cooldown(at: tick(130)).displaySeconds, 10)
        XCTAssertEqual(schedule.expire(at: tick(150)), [-2])
        XCTAssertEqual(schedule.expire(at: tick(999)), [])
    }

    func testExpirationDoesNotEndLongerCooldown() throws {
        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 5, cooldownSeconds: 20))
        XCTAssertTrue(schedule.deploy(slot: -1, at: 0))
        XCTAssertEqual(schedule.expire(at: tick(5)), [-1])
        XCTAssertFalse(schedule.deploy(slot: -2, at: tick(5)))
        XCTAssertEqual(schedule.cooldown(at: tick(5)).displaySeconds, 15)
        XCTAssertTrue(schedule.deploy(slot: -2, at: tick(20)))
    }

    func testBothTimersFollowGameTicksAcrossPauseAndSpeedChanges() throws {
        let timer = LevelEditorFormats.Timer(tickDuration: .milliseconds(33))
        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 20, cooldownSeconds: 20))
        XCTAssertTrue(schedule.deploy(slot: -1, at: timer.tick))
        for _ in 0..<tick(10) { timer.advanceTick() }
        let paused = schedule.cooldown(at: timer.tick)
        XCTAssertEqual(paused.displaySeconds, 10)
        XCTAssertEqual(paused.remainingFraction, 0.5, accuracy: 1e-9)
        timer.resync()
        timer.setTickDuration(timer.tickDuration / 2)
        XCTAssertEqual(schedule.cooldown(at: timer.tick), paused)
        XCTAssertEqual(schedule.expire(at: timer.tick), [])
        for _ in 0..<tick(10) { timer.advanceTick() }
        XCTAssertEqual(schedule.expire(at: timer.tick), [-1])
        XCTAssertTrue(schedule.cooldown(at: timer.tick).isReady)
    }

    func testFractionalTimesRoundUpToAvoidEarlyExpiryOrReadiness() throws {
        var schedule = ReinforcementSchedule(config: try ReinforcementConfig(timeToLiveSeconds: 0.05, cooldownSeconds: 0.05))
        XCTAssertTrue(schedule.deploy(slot: -1, at: 0))
        XCTAssertFalse(schedule.cooldown(at: 1).isReady)
        XCTAssertEqual(schedule.expire(at: 1), [])
        XCTAssertTrue(schedule.cooldown(at: 2).isReady)
        XCTAssertEqual(schedule.expire(at: 2), [-1])
    }

    func testInvalidConfigurationIsRejected() {
        for value in [0, -1, Double.nan, .infinity, -.infinity, Double.greatestFiniteMagnitude] {
            XCTAssertThrowsError(try ReinforcementConfig(timeToLiveSeconds: value, cooldownSeconds: 20))
            XCTAssertThrowsError(try ReinforcementConfig(timeToLiveSeconds: 20, cooldownSeconds: value))
        }
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }

    func testProductionSchemaSeedAndDAOUseIndependentDatabaseValues() throws {
        var conn: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &conn), SQLITE_OK)
        defer { sqlite3_close(conn) }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(conn, sql, nil, nil, nil) == SQLITE_OK else {
                throw DbError.Db(message: String(cString: sqlite3_errmsg(conn)))
            }
        }
        try execute(String(contentsOf: root.appendingPathComponent("Db/DDL/create_tables.sql"), encoding: .utf8))
        let dao = ReinforcementConfigDAO(conn: conn)
        XCTAssertThrowsError(try dao.get(), "Missing configuration must not silently use hardcoded gameplay timing.")
        try execute(String(contentsOf: root.appendingPathComponent("Db/DML/reinforcement_config.sql"), encoding: .utf8))
        XCTAssertEqual(try dao.get(), try ReinforcementConfig(timeToLiveSeconds: 20, cooldownSeconds: 20))
        try execute("UPDATE reinforcement_config SET time_to_live_seconds = 7.5, cooldown_seconds = 3.25 WHERE id = 1")
        let configured = try dao.get()
        XCTAssertEqual(configured, try ReinforcementConfig(timeToLiveSeconds: 7.5, cooldownSeconds: 3.25))
        var schedule = ReinforcementSchedule(config: configured)
        XCTAssertTrue(schedule.deploy(slot: -1, at: 0))
        XCTAssertFalse(schedule.cooldown(at: 97).isReady)
        XCTAssertTrue(schedule.cooldown(at: 98).isReady)
        XCTAssertEqual(schedule.expire(at: tick(7.5) - 1), [])
        XCTAssertEqual(schedule.expire(at: tick(7.5)), [-1])
        for column in ["time_to_live_seconds", "cooldown_seconds"] {
            for value in ["0", "-1", "NULL", "'invalid'"] {
                XCTAssertThrowsError(try execute("UPDATE reinforcement_config SET \(column) = \(value) WHERE id = 1"))
            }
        }
        XCTAssertThrowsError(try execute("INSERT INTO reinforcement_config VALUES (2, 20, 20)"))
        try execute("UPDATE reinforcement_config SET time_to_live_seconds = 1e999 WHERE id = 1")
        XCTAssertThrowsError(try dao.get())
    }
}
