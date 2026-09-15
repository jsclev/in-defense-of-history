import XCTest
@testable import LevelEditorFormats

final class CallWaveButtonSelectionTests: XCTestCase {
    private let entrance = Point(600, 900)

    func testFirstTapSelectsAndLaterTapCallsEarlyExactlyOnce() throws {
        let wave = Wave(startTime: 0, spawns: [], callButtonDelay: 15,
                        autoStartCountdown: 10, earlyCallBonus: 13)
        var schedule = try WaveStartSchedule(waves: [wave, wave, wave])
        _ = schedule.startNextWave(at: 0, manually: true)
        var selection = CallWaveButtonSelection()
        let revealTick = Int64(15 * SimClock.ticksPerSecond)
        XCTAssertTrue(schedule.state(at: revealTick).canCall)
        XCTAssertFalse(selection.tap(entrance, for: 2))
        XCTAssertEqual(schedule.nextWaveIndex, 1)
        XCTAssertTrue(selection.isSelected(entrance, for: 2))
        XCTAssertTrue(selection.isVisible(for: 2))

        // Five seconds between taps is deliberately outside a double-tap gesture.
        let confirmTick = Int64(20 * SimClock.ticksPerSecond)
        XCTAssertEqual(schedule.state(at: confirmTick), .countingDown(seconds: 5))
        XCTAssertTrue(selection.tap(entrance, for: 2))
        let started = try XCTUnwrap(schedule.startNextWave(at: confirmTick, manually: true))
        XCTAssertEqual(started.index, 1)
        XCTAssertEqual(started.moneyBonus, 13)
        XCTAssertFalse(selection.isVisible(for: 2))
        XCTAssertFalse(selection.tap(entrance, for: 2))
        XCTAssertEqual(schedule.state(at: confirmTick), .hidden)
    }

    func testAnotherEntranceSelectsItInsteadOfCallingTheWave() {
        let other = Point(1000, 1200)
        var selection = CallWaveButtonSelection()
        XCTAssertFalse(selection.tap(entrance, for: 1))
        XCTAssertFalse(selection.tap(other, for: 1))
        XCTAssertFalse(selection.isSelected(entrance, for: 1))
        XCTAssertTrue(selection.isSelected(other, for: 1))
        XCTAssertTrue(selection.tap(other, for: 1))
        XCTAssertFalse(selection.tap(entrance, for: 1))
    }

    func testAutomaticStartCannotCarrySelectionIntoTheNextWave() throws {
        let wave = Wave(startTime: 0, spawns: [], callButtonDelay: 0,
                        autoStartCountdown: 10, earlyCallBonus: 13)
        var schedule = try WaveStartSchedule(waves: [wave, wave, wave])
        _ = schedule.startNextWave(at: 0, manually: true)
        var selection = CallWaveButtonSelection()
        XCTAssertFalse(selection.tap(entrance, for: 2))
        _ = try XCTUnwrap(schedule.startNextWave(at: Int64(10 * SimClock.ticksPerSecond), manually: false))
        let nextWave = schedule.nextWaveIndex + 1
        XCTAssertEqual(nextWave, 3)
        XCTAssertFalse(selection.isSelected(entrance, for: nextWave))
        XCTAssertTrue(selection.isVisible(for: nextWave))
        XCTAssertFalse(selection.tap(entrance, for: nextWave))
        XCTAssertTrue(selection.isSelected(entrance, for: nextWave))
        XCTAssertTrue(selection.tap(entrance, for: nextWave))
    }

    func testConfirmedWaveDoesNotHideOrPreselectFollowingWave() {
        var selection = CallWaveButtonSelection()
        XCTAssertFalse(selection.tap(entrance, for: 1))
        XCTAssertTrue(selection.tap(entrance, for: 1))
        XCTAssertTrue(selection.isVisible(for: 2))
        XCTAssertFalse(selection.isSelected(entrance, for: 2))
        XCTAssertFalse(selection.tap(entrance, for: 2))
        XCTAssertTrue(selection.tap(entrance, for: 2))
    }
}
