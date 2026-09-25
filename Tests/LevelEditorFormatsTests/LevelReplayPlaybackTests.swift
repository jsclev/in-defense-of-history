import XCTest
import SQLite3
@testable import LevelEditorFormats

final class LevelReplayPlaybackTests: XCTestCase {
    @MainActor private func recording() throws -> (AuthoredDatabaseFixture, UUID, [LevelReplayFrame]) {
        let fixture = try AuthoredDatabaseFixture(levelGeoJSONDao:
            LevelGeoJSONDAO(directory: Db.authoredDatabaseURL.deletingLastPathComponent()))
        let sim = try GameSimulation(recording: .database(fixture.db.levelRunDao, .player),
            content: BattleTestFixture.authored(db: fixture.db), startingMoney: nil, heroesEnabled: true, seed: 1776)
        sim.startNextWave()
        var frames = [LevelReplayFrame(sim.engine)]
        for _ in 0..<90 { sim.step(); frames.append(LevelReplayFrame(sim.engine)) }
        sim.finishRecording(status: .abandoned)
        return (fixture, try XCTUnwrap(sim.runID), frames)
    }

    private func encoded(_ frame: LevelReplayFrame) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(frame)
    }

    @MainActor func testPlaybackRatesPreserveEveryRecordedPoseAndNeverWrite() throws {
        let (fixture, id, frames) = try recording()
        let writes = sqlite3_total_changes(fixture.connection)
        for factor in [0.5, 1, 2] {
            let playback = try LevelReplayPlayback(dao: fixture.db.levelRunDao, runID: id, speed: PlaySpeed(factor))
            XCTAssertEqual(try encoded(playback.frame), try encoded(frames[0]))
            for expected in frames.dropFirst() {
                try playback.advance(wallSeconds: SimClock.dt / factor)
                XCTAssertEqual(try encoded(playback.frame), try encoded(expected))
            }
            XCTAssertTrue(playback.isFinished)
            try playback.advance(wallSeconds: 1_000)
            playback.togglePause()
            XCTAssertFalse(playback.isPaused)
            XCTAssertEqual(playback.frame.tick, 90)
        }
        XCTAssertEqual(sqlite3_total_changes(fixture.connection), writes)
    }

    @MainActor func testPauseFreezesPlaybackAndResumePreservesFractionalTick() throws {
        let (fixture, id, _) = try recording()
        let playback = try LevelReplayPlayback(dao: fixture.db.levelRunDao, runID: id, speed: PlaySpeed(1))
        try playback.advance(wallSeconds: SimClock.dt * 1.5)
        XCTAssertEqual(playback.frame.tick, 1)
        playback.togglePause()
        try playback.advance(wallSeconds: 300)
        XCTAssertEqual(playback.frame.tick, 1)
        playback.togglePause()
        try playback.advance(wallSeconds: SimClock.dt * 0.5)
        XCTAssertEqual(playback.frame.tick, 2)
    }

    @MainActor func testReopeningStartsAtBeginningAndCatchUpEndsAtSavedFinalPose() throws {
        let (fixture, id, frames) = try recording()
        let first = try LevelReplayPlayback(dao: fixture.db.levelRunDao, runID: id, speed: PlaySpeed(1))
        try first.advance(wallSeconds: 20)
        XCTAssertTrue(first.isFinished)
        XCTAssertEqual(try encoded(first.frame), try encoded(XCTUnwrap(frames.last)))
        let reopened = try LevelReplayPlayback(dao: fixture.db.levelRunDao, runID: id, speed: PlaySpeed(1))
        XCTAssertEqual(reopened.frame.tick, 0)
        XCTAssertFalse(reopened.isFinished)
        XCTAssertFalse(reopened.isPaused)
    }
}
